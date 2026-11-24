; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/tui.x -- the board on a whole terminal
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The state the board interface keeps, what a key does to it, and what is
; drawn: kept apart from the terminal (backgammon/app) so a spec can press
; keys and read the screen back.
;
; A play is made a checker at a time: a checker clicked, or picked with
; the arrows and Enter, then the place it goes, by one die or several;
; the play is made once the dice are used.  Picking the same checker
; again moves it by the larger die.  A play can be typed as well, the way
; it is written.  The engine plays the sides no one else does, and a roll
; with one play is played for the side whose roll it is.
;
; A key is a string for a character, or enter, backspace, escape, up,
; down, left, right or interrupt; a mouse press is (mouse BUTTON COL ROW
; PRESS?), the columns and rows counted from 1 as a terminal reports them.
;
; The board is drawn from one side, the viewer's, its home board at the
; bottom right: the points in two rows of twelve with the bar between,
; the tray for the checkers borne off at the right, and the dice of the
; side to move in the middle row, on its own half.

(module backgammon/tui)

(import x/type/vector)
(import x/sys/gc)
(import x/tui/screen)
(import x/tui/style)
(import x/core/doors int+ int- int* int/ int% int< int= io-display-to-str str-byte-len str-byte-ref str-byte-sub)
(import backgammon/board WHITE BLACK BAR pos-me pos-opp pos-turn pos-me-off pos-opp-off pos-me-pips pos-opp-pips
  step-die play-text play-find play-after play-next play-done)
(import backgammon/eval eval-ranked eval-best eval-contact?)
(import backgammon/bearoff bearoff-due? bearoff-solve!)
(import backgammon/coach coach-judge)
(import backgammon/game game-new game-pos game-dice game-result game-over? game-turn game-set-dice!
  game-play! game-undo! game-plays)
(import backgammon/play side-word)

; --- the state --------------------------------------------------------------------
;
; A Vector: the game; the dice's source; who the people play, white,
; black, both or none; the side drawn at the bottom; the cursor, (TOP .
; SLOT); the checker picked, a mover's index or (); the steps made of the
; play so far; where the checker picked can go, a list of (TO . STEPS);
; the message; the play being typed; the command being typed, or (); the
; keys shown; quit; what was last played; the layout last drawn, (WIDTH
; X0); the games won, (WHITE . BLACK); the result counted in them; and
; what has happened since it was last asked, for a window to show: see
; tui-events!.

(def %game 0)
(def %rnd 1)
(def %human 2)
(def %view 3)
(def %cursor 4)
(def %sel 5)
(def %done 6)
(def %dests 7)
(def %msg 8)
(def %input 9)
(def %command 10)
(def %help 11)
(def %quit 12)
(def %last 13)
(def %layout 14)
(def %score 15)
(def %scored 16)
(def %events 17)
(def %coach 18)
(def %coaching 19)
(def %hinted 20)

(def %get (fn (_ st i) (Vector ref i st)))
(def %put! (fn (_ st i v) (Vector set! i v st)))
(def %2nd (fn (_ l) (first (rest l))))
(def %num (fn (_ n) (io-display-to-str n)))

(def %name (fn (_ side) (if (int= side WHITE) "White" "Black")))
(def %dice-text (fn (_ d) (Str8 append (%num (first d)) "-" (%num (%2nd d)))))

(def %human?
  (fn (_ st side)
    ((fn (_ h) (match ((eq? h (lit both)) #t) ((eq? h (lit none)) #f) ((eq? h (lit white)) (int= side WHITE)) (#t (int= side BLACK))))
     (%get st %human))))

(def %clear-play! (fn (_ st) (%put! st %sel ()) (%put! st %done ()) (%put! st %dests ()) (%put! st %hinted ())))

(def %new-game!
  (fn (_ st)
    (def g (game-new (%get st %rnd)))
    (%put! st %game g)
    (%clear-play! st)
    (%put! st %coach "")
    (%put! st %scored ())
    (%put! st %msg "")
    (%put! st %last
      (Str8 append "White rolls " (%num (first (game-dice g))) ", Black rolls " (%num (%2nd (game-dice g)))
        ": " (%name (game-turn g)) " moves first."))
    (%event! st (list (lit jump)))
    (%roll-event! st)))

; The board interface's state, the dice from RND, the people playing
; HUMAN: white, black, both or none.
(def tui-make
  (fn (_ rnd human)
    (def st (Vector make 21 ()))
    (%put! st %rnd rnd)
    (%put! st %human human)
    (%put! st %view (if (eq? human (lit black)) BLACK WHITE))
    (%put! st %cursor (pair #f 7))
    (%put! st %input "")
    (%put! st %help #f)
    (%put! st %quit #f)
    (%put! st %score (pair 0 0))
    (%put! st %coaching #t)
    (%new-game! st)
    st))

(def tui-game (fn (_ st) (%get st %game)))
(def tui-quit? (fn (_ st) (%get st %quit)))
(def tui-message (fn (_ st) (%get st %msg)))
(def tui-last (fn (_ st) (%get st %last)))
(def tui-done (fn (_ st) (%get st %done)))
(def tui-score (fn (_ st) (%get st %score)))

; ST playing game G from here: for a position set up by hand.
(def tui-game! (fn (_ st g) (%put! st %game g) (%clear-play! st) (%put! st %scored ()) (%put! st %last "") (%put! st %msg "") (%put! st %coach "") (%event! st (list (lit jump))) (%roll-event! st) st))

; --- plays ------------------------------------------------------------------------

(def %result-text
  (fn (_ r)
    (Str8 append (%name (first r)) " wins "
      (match ((int= (%2nd r) 3) "a backgammon, 3 points") ((int= (%2nd r) 2) "a gammon, 2 points") (#t "1 point"))
      ".  n starts the next game.")))

; The result R counted in the games won, by SIGN: 1 to count it, -1 to
; take it back.
(def %count!
  (fn (_ st r sign)
    (def s (%get st %score))
    (def n (int* sign (%2nd r)))
    (%put! st %score (if (int= (first r) WHITE) (pair (int+ (first s) n) (rest s)) (pair (first s) (int+ (rest s) n))))))

; The side to move's play PL made; HOW says how, "played", "had to play"
; or "cannot move".  SHOWN is #t when its steps were made one at a time,
; each already an event.
(def %commit!
  (fn (_ st pl how shown)
    (def g (%get st %game))
    (def text
      (Str8 append (%name (game-turn g)) " rolled " (%dice-text (game-dice g)) " and " how
        (if (null? (first pl)) "" (Str8 append " " (play-text pl))) "."))
    (unless shown (%step-events! st (game-pos g) (game-dice g) (first pl) ()))
    (when (if (%get st %coaching) (%human? st (game-turn g)) #f)
      ((fn (_ j) (%put! st %coach (if (null? j) "" (rest j))))
       (coach-judge (game-pos g) (first (game-dice g)) (%2nd (game-dice g)) pl)))
    (game-play! g pl)
    (%clear-play! st)
    (%put! st %last text)
    (%put! st %msg "")
    (if (game-over? g)
      (do (%count! st (game-result g) 1)
          (%put! st %scored (game-result g))
          (%put! st %msg (%result-text (game-result g)))
          (%event! st (pair (lit over) (game-result g))))
      (%roll-event! st))
    (Heap collect)))

; --- events -----------------------------------------------------------------------
;
; What has happened, oldest first, as a window shows it:
;   (roll SIDE D1 D2)            SIDE's dice thrown, D1 D2 to play
;   (step POS STEP DICE USED)    a checker moved: STEP, (FROM TO HIT), made
;                                in POS, seen from the side to move, which
;                                is playing DICE and has used the dice
;                                USED before it
;   (over WINNER POINTS)         the game won
;   (jump)                       the board changed without a play: taken
;                                back, set up, or a new game coming
; The terminal shows none of them, and takes them to keep the list short.

(def %event! (fn (_ st e) (%put! st %events (List append (%get st %events) (list e)))))

(def %roll-event!
  (fn (_ st) ((fn (_ g) (%event! st (list (lit roll) (game-turn g) (first (game-dice g)) (%2nd (game-dice g))))) (%get st %game))))

; A step event for each of STEPS made from P in turn, the dice USED before
; them.
(def %step-events!
  (fn (self st p dice steps used)
    (unless (null? steps)
      (do (%event! st (list (lit step) p (first steps) dice used))
          (self st (play-after p (list (first steps))) dice (rest steps) (List append used (list (step-die (first steps)))))))))

; The events since the last time, oldest first; the list emptied.
(def tui-events! (fn (_ st) ((fn (_ es) (%put! st %events ()) es) (%get st %events))))

; Whether the side to move is played without a person: the engine's
; side, or a roll with one play.
(def tui-engine-to-move?
  (fn (_ st)
    (def g (%get st %game))
    (match
      ((game-over? g) #f)
      ((not (%human? st (game-turn g))) #t)
      ((null? (%get st %done)) (int< (List length (game-plays g)) 2))
      (#t #f))))

; The side to move's play made for it: the engine's choice, or the only
; play there is.
(def tui-auto-play!
  (fn (_ st)
    (def g (%get st %game))
    (def d (game-dice g))
    (if (%human? st (game-turn g))
      ((fn (_ pl) (%commit! st pl (if (null? (first pl)) "cannot move" "had to play") #f)) (first (game-plays g)))
      (%commit! st (eval-best (game-pos g) (first d) (%2nd d)) "played" #f))))

; The bear-off is solved once on a machine, when a game first gets to a
; race: due while there is no table and the sides are past each other.
; The front shows the note, then solves.
(def tui-solve-due?
  (fn (_ st)
    (def g (%get st %game))
    (if (game-over? g) #f (if (eval-contact? (game-pos g)) #f (bearoff-due?)))))

(def tui-solve-note! (fn (_ st) (%put! st %msg "Solving the bear-off for this machine: about a minute, once.")))

(def tui-solve! (fn (_ st) (bearoff-solve!) (%put! st %msg "The bear-off is solved: the engine bears off by the table.")))

; The places, as the viewer counts them: 1 to 24 its points, 25 the bar
; and 0 the tray.  As the side to move's index: BAR, -1 for off, or the
; point's.
(def %mover-index
  (fn (_ st place)
    (match ((int= place 0) -1)
           ((int= place 25) BAR)
           ((int= (game-turn (%get st %game)) (%get st %view)) (int- place 1))
           (#t (int- 24 place)))))

(def %viewer-place
  (fn (_ st i)
    (match ((int< i 0) 0)
           ((int= i BAR) 25)
           ((int= (game-turn (%get st %game)) (%get st %view)) (int+ i 1))
           (#t (int- 24 i)))))

(def %next-steps
  (fn (_ st done)
    (def g (%get st %game))
    (play-next (game-pos g) (first (game-dice g)) (%2nd (game-dice g)) done)))

; Every place the checker at index FROM can go from the steps made, each
; as (TO . STEPS): TO -1 for off, STEPS the steps that take it, in order.
(def %chains
  (fn (_ st from)
    (def walk
      (fn (self from done path acc)
        (List fold
          (fn (_ acc s)
            (if (not (int= (first s) from)) acc
              ((fn (_ path)
                 ((fn (_ acc) (if (int< (%2nd s) 0) acc (self (%2nd s) (List append done (list s)) path acc)))
                  (List append acc (list (pair (if (int< (%2nd s) 0) -1 (%2nd s)) path)))))
               (List append path (list s)))))
          acc (%next-steps st done))))
    (walk from (%get st %done) () ())))

; Of CHAINS, the shortest to TO, or ().
(def %chain-to
  (fn (_ chains to)
    (List fold
      (fn (_ best c)
        (if (not (int= (first c) to)) best
          (if (null? best) c (if (int< (List length (rest c)) (List length (rest best))) c best))))
      () chains)))

; STEPS made: the play made too once they use the dice.
(def %make!
  (fn (_ st steps)
    (def g (%get st %game))
    (%step-events! st (%shown st) (game-dice g) steps (List map step-die (%get st %done)))
    (def done (List append (%get st %done) steps))
    (%put! st %done done)
    (%put! st %hinted ())
    (%put! st %sel ())
    (%put! st %dests ())
    (%put! st %msg "")
    (when (null? (%next-steps st done))
      (%commit! st (play-done (game-pos g) (first (game-dice g)) (%2nd (game-dice g)) done) "played" #t))))

(def %select!
  (fn (_ st i)
    (def chains (if (int< i 0) () (%chains st i)))
    (if (null? chains)
      (%put! st %msg (if (int< i 0) "Pick a checker first." "No checker of yours there can move."))
      (do (%put! st %sel i) (%put! st %dests chains) (%put! st %msg "")))))

; The checker picked moved by one die, the larger it can.
(def %by-larger!
  (fn (_ st)
    ((fn (_ c) (if (null? c) (%put! st %msg "That checker cannot move one die.") (%make! st (rest c))))
     (List fold
       (fn (_ best c)
         (if (not (int= (List length (rest c)) 1)) best
           (if (null? best) c (if (int< (step-die (first (rest best))) (step-die (first (rest c)))) c best))))
       () (%get st %dests)))))

; PLACE chosen, by a click or Enter.
(def %pick!
  (fn (_ st place)
    (def g (%get st %game))
    (match
      ((game-over? g) (%put! st %msg "The game is over: n starts the next one."))
      ((not (%human? st (game-turn g))) (%put! st %msg "It is not your turn."))
      (#t
        ((fn (_ i sel)
           (match
             ((null? sel) (%select! st i))
             ((int= i sel) (%by-larger! st))
             (#t ((fn (_ c)
                    (match
                      ((not (null? c)) (%make! st (rest c)))
                      ((null? (if (int< i 0) () (%chains st i))) (%put! st %msg "That checker cannot go there."))
                      (#t (%select! st i))))
                  (%chain-to (%get st %dests) i)))))
         (%mover-index st place) (%get st %sel))))))

; The last step taken back, or the last play of a person's when none is
; made yet.
(def %back!
  (fn (_ st)
    (def g (%get st %game))
    (match
      ((not (null? (%get st %done)))
        (do (%put! st %done (List init (%get st %done))) (%put! st %sel ()) (%put! st %dests ()) (%put! st %msg "") (%event! st (list (lit jump)))))
      ((game-undo! g (fn (_ side) (%human? st side)))
        (do (unless (null? (%get st %scored)) (%count! st (%get st %scored) -1))
            (%clear-play! st)
            (%put! st %scored ())
            (%put! st %last "Your last play is taken back.")
            (%event! st (list (lit jump)))
            (%put! st %msg "")))
      (#t (%put! st %msg "There is nothing of yours to take back.")))))

(def %typed!
  (fn (_ st text)
    (def g (%get st %game))
    (%put! st %input "")
    (match
      ((game-over? g) (%put! st %msg "The game is over: n starts the next one."))
      ((not (%human? st (game-turn g))) (%put! st %msg "It is not your turn."))
      (#t ((fn (_ found)
             (if (str? found) (%put! st %msg (Str8 append found ": " text))
               (%commit! st found "played" #f)))
           (play-find (game-pos g) (first (game-dice g)) (%2nd (game-dice g)) text))))))

(def %score-text (fn (_ s) (if (int< s 0) (Str8 append "−" (%num (int- 0 s))) (Str8 append "+" (%num s)))))

(def %hint!
  (fn (_ st)
    (def g (%get st %game))
    (if (game-over? g) (%put! st %msg "The game is over.")
      ((fn (_ ranked)
         (def best (first (first ranked)))
         (%put! st %hinted (first (rest (first ranked))))
         (%put! st %msg
           (Str8 append "Hint: "
             (Str8 join "  ·  "
               (List map (fn (_ r) (if (eq? r (first ranked)) (play-text (rest r))
                                     (Str8 append (play-text (rest r)) " " (%score-text (int- (first r) best)))))
                 (List take 3 ranked))))))
       (eval-ranked (game-pos g) (first (game-dice g)) (%2nd (game-dice g)))))))

(def %coach-toggle!
  (fn (_ st)
    (%put! st %coaching (not (%get st %coaching)))
    (%put! st %coach "")
    (%put! st %msg (if (%get st %coaching) "The coach is on: each play of yours is judged." "The coach is off."))))

; The message shown: what was last said, or else the coach's word on
; the last play of yours.
(def %note (fn (_ st) (if (str=? (%get st %msg) "") (%get st %coach) (%get st %msg))))

; --- keys -------------------------------------------------------------------------

(def %is? (fn (_ key s) (if (str? key) (str=? key s) #f)))

(def %digit? (fn (_ key) (if (str? key) (if (int= (str-byte-len key) 1) ((fn (_ b) (if (int< 47 b) (int< b 58) #f)) (str-byte-ref key 0)) #f) #f)))

; A cursor step: the slots run 0 to 13 along a row, 6 the bar and 13 the
; tray; up and down go between the rows.
(def %cursor-step!
  (fn (_ st dx top)
    (def c (%get st %cursor))
    (def s (int+ (rest c) dx))
    (%put! st %cursor (pair (if (null? top) (first c) (eq? top (lit top))) (if (int< s 0) 0 (if (int< 13 s) 13 s))))))

; The viewer's place at slot SLOT of the top row (TOP) or the bottom.
(def %slot-place
  (fn (_ top slot)
    (match ((int= slot 6) 25)
           ((int= slot 13) 0)
           (top (if (int< slot 6) (int+ 13 slot) (int+ 12 slot)))
           ((int< slot 6) (int- 12 slot))
           (#t (int- 13 slot)))))

; The slot and row of viewer's place N, 1 to 24: (TOP . SLOT).
(def %place-slot
  (fn (_ n)
    (match ((int< 18 n) (pair #t (int- n 12)))
           ((int< 12 n) (pair #t (int- n 13)))
           ((int< 6 n) (pair #f (int- 12 n)))
           (#t (pair #f (int- 13 n))))))

(def %erase (fn (_ s) (if (int= (str-byte-len s) 0) s (str-byte-sub s 0 (int- (str-byte-len s) 1)))))

(def %command-key!
  (fn (_ st key)
    (def text (%get st %command))
    (match
      ((eq? key (lit enter)) (do (%put! st %command ()) (%run-command! st text)))
      ((eq? key (lit escape)) (%put! st %command ()))
      ((eq? key (lit backspace)) (%put! st %command (if (str=? text "") () (%erase text))))
      ((str? key) (%put! st %command (Str8 append text key)))
      (#t ()))))

(def %input-key!
  (fn (_ st key)
    (def text (%get st %input))
    (match
      ((eq? key (lit enter)) (%typed! st text))
      ((eq? key (lit escape)) (%put! st %input ""))
      ((eq? key (lit backspace)) (%put! st %input (%erase text)))
      ((str? key) (%put! st %input (Str8 append text key)))
      (#t ()))))

(def %words (fn (_ line) (List reject (fn (_ w) (str=? w "")) (Str8 split " " line))))

(def %run-command!
  (fn (_ st line)
    (def words (%words line))
    (def cmd (if (null? words) "" (first words)))
    (match
      ((str=? cmd "") ())
      ((if (str=? cmd "q") #t (str=? cmd "quit")) (%put! st %quit #t))
      ((str=? cmd "new") (%new-game! st))
      ((str=? cmd "hint") (%hint! st))
      ((str=? cmd "coach") (%coach-toggle! st))
      ((str=? cmd "help") (%put! st %help #t))
      ((not (null? (side-word cmd)))
        (do (%put! st %human (side-word cmd))
            (when (str=? cmd "black") (%put! st %view BLACK))
            (when (str=? cmd "white") (%put! st %view WHITE))
            (%clear-play! st)
            (%put! st %msg (match ((str=? cmd "both") "You play both sides.")
                                  ((str=? cmd "none") "The engine plays both sides.")
                                  (#t (Str8 append "You play " cmd "."))))))
      ((str=? cmd "dice")
        ((fn (_ d)
           (if (null? d) (%put! st %msg "dice takes two dice: dice 31")
             (do (game-set-dice! (%get st %game) (first d) (%2nd d)) (%clear-play! st) (%put! st %msg "") (%event! st (list (lit jump))) (%roll-event! st))))
         (if (null? (rest words)) () (%dice-word (%2nd words)))))
      (#t (%put! st %msg (Str8 append "No such command: " cmd ".  ? lists them."))))))

(def %dice-word
  (fn (_ s)
    (def die (fn (_ i) ((fn (_ d) (if (if (int< 0 d) (int< d 7) #f) d ())) (int- (str-byte-ref s i) 48))))
    (if (int= (str-byte-len s) 2)
      ((fn (_ a b) (if (if (null? a) #t (null? b)) () (list a b))) (die 0) (die 1))
      ())))

; A mouse press of the left button on a place.
(def %mouse!
  (fn (_ st key)
    (def place (%place-at st (int- (List ref 3 key) 1) (int- (List ref 2 key) 1)))
    (when (if (int= (List ref 1 key) 0) (if (List ref 4 key) (not (null? place)) #f) #f)
      (do (%put! st %cursor (rest place)) (%pick! st (first place))))))

; Place N chosen by a window: the cursor put on it, and picked.
(def %place-key!
  (fn (_ st n)
    (match ((int= n 0) (%put! st %cursor (pair #f 13)))
           ((int= n 25) (%put! st %cursor (pair (first (%get st %cursor)) 6)))
           (#t (%put! st %cursor (%place-slot n))))
    (%pick! st n)))

; KEY pressed: a string for a character, a key's name, a terminal's
; (mouse BUTTON COL ROW PRESS?), or a window's (place N).
(def tui-key!
  (fn (_ st key)
    (match
      ((not (null? (%get st %command))) (%command-key! st key))
      ((%get st %help) (%put! st %help #f))
      ((if (pair? key) (eq? (first key) (lit mouse)) #f) (%mouse! st key))
      ((if (pair? key) (eq? (first key) (lit place)) #f) (%place-key! st (%2nd key)))
      ((not (str=? (%get st %input) "")) (%input-key! st key))
      ((%digit? key) (%put! st %input key))
      ((if (eq? key (lit enter)) #t (%is? key " "))
        ((fn (_ c) (%pick! st (%slot-place (first c) (rest c)))) (%get st %cursor)))
      ((eq? key (lit escape)) (do (%put! st %sel ()) (%put! st %dests ()) (%put! st %msg "")))
      ((eq? key (lit backspace)) (%back! st))
      ((eq? key (lit left)) (%cursor-step! st -1 ()))
      ((eq? key (lit right)) (%cursor-step! st 1 ()))
      ((eq? key (lit up)) (%cursor-step! st 0 (lit top)))
      ((eq? key (lit down)) (%cursor-step! st 0 (lit bottom)))
      ((if (%is? key "q") #t (eq? key (lit interrupt))) (%put! st %quit #t))
      ((%is? key "?") (%put! st %help #t))
      ((%is? key "u") (%back! st))
      ((%is? key "h") (%hint! st))
      ((%is? key "c") (%coach-toggle! st))
      ((%is? key "n") (%new-game! st))
      ((%is? key "v") (%put! st %view (int- 1 (%get st %view))))
      ((%is? key ":") (%put! st %command ""))
      (#t ()))))

; --- drawing ----------------------------------------------------------------------
;
; Colours of the 256-colour palette: the felt, the frame and bar, the
; points dark and light, the tray, the checkers white and black, and the
; marks of the checker picked and where it can go.

(def %felt 22)
(def %frame 94)
(def %dark 160)
(def %light 137)
(def %tray 236)
(def %white 231)
(def %black 16)
(def %mark 220)

(def %bg (fn (_ c) (Style make () () c)))
(def %side-fg (fn (_ side) (if (int= side WHITE) %white %black)))

; The layout for a screen COLS wide: (WIDTH X0), each slot WIDTH cells,
; the board from column X0: the frame, slots 0 to 12, the frame, the
; tray.
(def %layout-for
  (fn (_ cols) ((fn (_ w) (list w (int/ (int- cols (int+ 2 (int* 14 w))) 2))) (if (int< cols 72) 3 5))))

(def %slot-x (fn (_ lay slot) (if (int= slot 13) (int+ (%2nd lay) (int+ 2 (int* 13 (first lay)))) (int+ (%2nd lay) (int+ 1 (int* slot (first lay)))))))

; The place at screen ROW and COL with its slot, (PLACE TOP . SLOT), or ().
(def %place-at
  (fn (_ st row col)
    (def lay (%get st %layout))
    (if (null? lay) ()
      ((fn (_ w x)
         (def slot
           (match ((int< x 0) ())
                  ((int< x (int* 13 w)) (int/ x w))
                  ((int< x (int+ 1 (int* 13 w))) ())
                  ((int< x (int+ 1 (int* 14 w))) 13)
                  (#t ())))
         (def half (match ((int< row 7) (lit top)) ((int< row 8) ()) ((int< row 15) (lit bottom)) (#t ())))
         (if (if (null? slot) #t (null? half)) ()
           ((fn (_ top) (pair (%slot-place top slot) (pair top slot))) (eq? half (lit top)))))
       (first lay) (int- col (int+ (%2nd lay) 1))))))

; The checkers of each side on the viewer's place N: (VIEWER . OTHER).
; The checkers of each side on place N as VIEW counts the places, in P:
; (VIEW'S . THE OTHER'S).
(def tui-counts
  (fn (_ p view n)
    (def mine (int= (pos-turn p) view))
    (match
      ((int= n 25) (if mine (pair (pos-me p BAR) (pos-opp p BAR)) (pair (pos-opp p BAR) (pos-me p BAR))))
      ((int= n 0) (if mine (pair (pos-me-off p) (pos-opp-off p)) (pair (pos-opp-off p) (pos-me-off p))))
      (mine (pair (pos-me p (int- n 1)) (pos-opp p (int- 24 n))))
      (#t (pair (pos-opp p (int- n 1)) (pos-me p (int- 24 n)))))))

(def %counts (fn (_ st p n) (tui-counts p (%get st %view) n)))

; The position shown: the game's with the steps made so far.
(def %shown (fn (_ st) (play-after (game-pos (%get st %game)) (%get st %done))))

(def %other (fn (_ side) (int- 1 side)))

; Row Y0 + K of a stack, K from the edge: down from row 2 at the top, up
; from row 12 at the bottom.
(def %stack-row (fn (_ top k) (if top (int+ 2 k) (int- 12 k))))

; N checkers of SIDE stacked from the edge in slot X, WIDTH W, on BG; the
; fifth shows the count when there are more.  MARK, when not (), is the
; style of the top one.
(def %stack!
  (fn (_ screen x w top n side bg mark)
    (def cx (int+ x (int/ (int- w 1) 2)))
    (def shown (if (int< 5 n) 5 n))
    (List for-each
      (fn (_ k)
        (def style (if (if (int= k (int- shown 1)) (not (null? mark)) #f) mark
                     (Style make (list (lit bold)) (%side-fg side) bg)))
        (if (if (int= k 4) (int< 5 n) #f)
          (Screen put screen (%stack-row top k) (if (int< 9 n) (int- cx 1) cx) (%num n) style)
          (Screen put screen (%stack-row top k) cx "●" style)))
      (List range 0 shown))))

(def %point!
  (fn (_ st screen lay p n)
    (def w (first lay))
    (def at (%place-slot n))
    (def top (first at))
    (def x (%slot-x lay (rest at)))
    (def colour (if (int= 0 (int% (int+ (rest at) (if top 1 0)) 2)) %dark %light))
    (def half (int/ (int- w 1) 2))
    (List for-each
      (fn (_ k)
        ((fn (_ inset) (Screen fill screen (%stack-row top k) (int+ x inset) (int- w (int* 2 inset)) (%bg colour)))
         ((fn (_ i) (if (int< half i) half i)) (int/ (int* k (int+ half 1)) 5))))
      (List range 0 5))
    (def c (%counts st p n))
    (def side (if (int< 0 (first c)) (%get st %view) (%other (%get st %view))))
    (def count (if (int< 0 (first c)) (first c) (rest c)))
    (def picked (if (null? (%get st %sel)) #f (int= (%viewer-place st (%get st %sel)) n)))
    (%stack! screen x w top count side colour (if picked (Style make (list (lit bold)) (%side-fg side) %mark) ()))
    (when (%dest? st n)
      ((fn (_ k)
         (Screen put screen (%stack-row top k) (int+ x half) (if (int< 0 (rest c)) "●" "•")
           (if (int< 0 (rest c)) (Style make (list (lit bold)) (%side-fg (%other (%get st %view))) %mark)
             (Style make (list (lit bold)) %mark colour))))
       (if (int< 0 (first c)) (if (int< 4 (first c)) 4 (first c)) 0)))))

; Whether the checker picked can go to the viewer's place N.
(def %dest? (fn (_ st n) (List any? (fn (_ c) (int= (%viewer-place st (first c)) n)) (%get st %dests))))

(def %frame!
  (fn (_ screen lay)
    (def w (first lay))
    (def x0 (%2nd lay))
    (List for-each (fn (_ r) (Screen fill screen r x0 (int+ 2 (int* 13 w)) (%bg %frame))) (List range 1 14))
    (List for-each
      (fn (_ r)
        (Screen fill screen r (int+ x0 1) (int* 6 w) (%bg %felt))
        (Screen fill screen r (%slot-x lay 7) (int* 6 w) (%bg %felt)))
      (List range 2 13))
    (List for-each (fn (_ r) (Screen fill screen r (%slot-x lay 13) w (%bg (if (if (int< 1 r) (int< r 13) #f) %tray %frame)))) (List range 1 14))))

; The bar and the tray: the viewer's checkers on the bar in its top half,
; going up from the middle, as they come in at the top; the other's in
; the bottom half; the viewer's borne off in the tray's bottom half, three
; a row, the other's in the top.
(def %bar-tray!
  (fn (_ st screen lay p)
    (def w (first lay))
    (def view (%get st %view))
    (def bar (%counts st p 25))
    (def off (%counts st p 0))
    (def bx (int+ (%slot-x lay 6) (int/ (int- w 1) 2)))
    (def bar-stack
      (fn (_ n side up)
        (List for-each
          (fn (_ k)
            (def r (if up (int- 6 k) (int+ 8 k)))
            (def style (Style make (list (lit bold)) (%side-fg side) %frame))
            (if (if (int= k 4) (int< 5 n) #f) (Screen put screen r bx (%num n) style) (Screen put screen r bx "●" style)))
          (List range 0 (if (int< 5 n) 5 n)))))
    (bar-stack (first bar) view #t)
    (bar-stack (rest bar) (%other view) #f)
    (def tx (int+ (%slot-x lay 13) (int/ (int- w 3) 2)))
    (def tray-stack
      (fn (_ n side top)
        (List for-each
          (fn (_ k)
            ((fn (_ m) (Screen put screen (%stack-row top k) tx (Str8 join "" (List repeat m "▬")) (Style make (list (lit bold)) (%side-fg side) %tray)))
             ((fn (_ m) (if (int< 3 m) 3 m)) (int- n (int* 3 k)))))
          (List range 0 (int/ (int+ n 2) 3)))))
    (tray-stack (first off) view #f)
    (tray-stack (rest off) (%other view) #t)
    (when (%dest? st 0)
      (Screen put screen (%stack-row #f (int/ (int+ (first off) 2) 3)) tx "•••" (Style make (list (lit bold)) %mark %tray)))))

; The points' numbers above and below, the cursor's place reversed and
; the places the checker picked can go marked.
(def %numbers!
  (fn (_ st screen lay)
    (def w (first lay))
    (def c (%get st %cursor))
    (def label
      (fn (_ n top slot text)
        (def x (%slot-x lay slot))
        (def here (if (eq? (first c) top) (int= (rest c) slot) #f))
        (def style (match (here (Style make (list (lit bold) (lit reverse)) () ()))
                          ((%dest? st n) (Style make (list (lit bold)) %black %mark))
                          (#t (Style make (list (lit dim)) () ()))))
        (Screen fill screen (if top 0 14) x w (if here style (if (%dest? st n) style 0)))
        (Screen put screen (if top 0 14) (int+ x (int/ (int- w (str-byte-len text)) 2)) text style)))
    (List for-each
      (fn (_ n) ((fn (_ at) (label n (first at) (rest at) (%num n))) (%place-slot n)))
      (List range 1 25))
    (label 25 #t 6 "")
    (label 25 #f 6 "")
    (label 0 #t 13 "")
    (label 0 #f 13 "off")))

; The dice of the side to move in the middle row, on its half: four for
; a double, those used drawn dim.
(def %dice!
  (fn (_ st screen lay)
    (def g (%get st %game))
    (unless (game-over? g)
      (do
        (def d (game-dice g))
        (def side (game-turn g))
        (def dice (if (int= (first d) (%2nd d)) (List repeat 4 (first d)) d))
        (def used (List map step-die (%get st %done)))
        (def faces
          ((fn (self dice used)
             (if (null? dice) ()
               (if (List includes? (first dice) used)
                 (pair (pair (first dice) #t) (self (rest dice) (%drop (first dice) used)))
                 (pair (pair (first dice) #f) (self (rest dice) used)))))
           dice used))
        (def n (List length faces))
        (def width (int- (int* 4 n) 1))
        (def x (int+ (%slot-x lay (if (int= side (%get st %view)) 7 0)) (int/ (int- (int* 6 (first lay)) width) 2)))
        (List for-each
          (fn (_ i)
            ((fn (_ f)
               (Screen put screen 7 (int+ x (int* 4 i)) (Str8 append " " (%num (first f)) " ")
                 (if (rest f) (Style make (list (lit dim)) 244 (if (int= side WHITE) 252 238))
                   (Style make (list (lit bold)) (if (int= side WHITE) %black %white) (if (int= side WHITE) %white 234)))))
             (List ref i faces)))
          (List range 0 n))))))

(def %drop (fn (self d l) (match ((null? l) ()) ((int= (first l) d) (rest l)) (#t (pair (first l) (self d (rest l)))))))

; A side's line: whose it is, its pip count and checkers off, the side
; to move marked.
(def %side-text
  (fn (_ st p side)
    (def mine (int= (pos-turn p) side))
    (Str8 append (%name side) (if (%human? st side) " (you)" " (engine)") "  "
      (%num (if mine (pos-me-pips p) (pos-opp-pips p))) " pips")))

(def %status!
  (fn (_ st screen rows x)
    (def g (%get st %game))
    (def p (%shown st))
    (def to-move (if (game-over? g) () (game-turn g)))
    (def side!
      (fn (_ side x)
        (Screen put screen 16 x (if (eq? side to-move) "▶ " "  ") (Style make (list (lit bold)) () ()))
        (Screen put screen 16 (int+ x 2) "●" (Style make (list (lit bold)) (%side-fg side) %felt))
        (Screen put screen 16 (int+ x 4) (%side-text st p side) (Style make (if (eq? side to-move) (list (lit bold)) ()) () ()))))
    (def end (side! BLACK (int+ 3 (side! WHITE x))))
    (def s (%get st %score))
    (Screen put screen 16 (int+ end 2) (Str8 append "games " (%num (first s)) "-" (%num (rest s))) (Style make (list (lit dim)) () ()))
    (Screen put screen 17 x (%get st %last) 0)
    (Screen put screen 18 x (%note st) (Style make (list (lit bold)) () ()))
    (Screen put screen (int- rows 1) x (%line-text st)
      (Style make (if (if (null? (%get st %command)) (str=? (%get st %input) "") #f) (list (lit dim)) ()) () ()))))

; The bottom line: the command or the play being typed, the steps made,
; or the keys.
(def %line-text
  (fn (_ st)
    (match ((not (null? (%get st %command))) (Str8 append ":" (%get st %command) "▏"))
           ((not (str=? (%get st %input) "")) (Str8 append "Play: " (%get st %input) "▏   Enter plays it, Esc clears"))
           ((not (null? (%get st %done))) (Str8 append "Made: " (Str8 join " " (List map %step-text (%get st %done))) "   ⌫ takes a step back"))
           (#t %keys-line))))

(def %step-text
  (fn (_ s)
    (Str8 append (if (int= (first s) BAR) "bar" (%num (int+ (first s) 1))) "/"
      (if (int< (%2nd s) 0) "off" (%num (int+ (%2nd s) 1))) (if (List ref 2 s) "*" ""))))

(def %keys-line "click a checker, then where it goes · type a play · u back · h hint · n new · ? keys · q quit")

(def %help-lines
  (list "Click a checker, then the place it goes:"
        "by one die, or by both to go further."
        "Or move with the arrows and pick with Enter."
        "Picking the same checker again moves it"
        "by the larger die."
        ""
        "Type a play the way it is written, then Enter:"
        "24/18 13/11, 8/5(2), bar/22, 6/off."
        ""
        "Backspace, u  take back a step, or your play"
        "h  hint       n  new game     v  turn board"
        "c  the coach on or off"
        ":  a command: white, black, both, none,"
        "   dice 31, new, hint, coach, quit"
        "?  these keys q  quit"
        ""
        "Any key closes this."))

(def %help!
  (fn (_ st screen rows cols)
    (def w 50)
    (def h (int+ 2 (List length %help-lines)))
    (def x (int/ (int- cols w) 2))
    (def y (if (int< rows (int+ h 1)) 0 1))
    (def style (Style make () %black 230))
    (List for-each (fn (_ k) (Screen fill screen (int+ y k) x w style)) (List range 0 h))
    (List for-each
      (fn (_ i) (Screen put screen (int+ y (int+ 1 i)) (int+ x 3) (List ref i %help-lines) style))
      (List range 0 (List length %help-lines)))))

; ST drawn on SCREEN.
(def tui-draw!
  (fn (_ st screen)
    (def rows (Screen rows screen))
    (def cols (Screen cols screen))
    (Screen clear screen)
    (if (if (int< rows 20) #t (int< cols 46))
      (do (%put! st %layout ()) (Screen put screen 0 0 "Too small: x-backgammon needs 46 by 20." 0))
      (do
        (def lay (%layout-for cols))
        (%put! st %layout lay)
        (def p (%shown st))
        (%frame! screen lay)
        (List for-each (fn (_ n) (%point! st screen lay p n)) (List range 1 25))
        (%bar-tray! st screen lay p)
        (%numbers! st screen lay)
        (%dice! st screen lay)
        (%status! st screen rows (if (int< (%2nd lay) 0) 0 (%2nd lay)))
        (when (%get st %help) (%help! st screen rows cols))))))

; --- for a window -----------------------------------------------------------------

; What a window draws, as an alist: pos, the position shown, seen from
; the side to move; view, the side drawn at the bottom; turn, the side
; to move, () once the game is over; dice, the side to move's (D1 D2) or
; (); used, the dice its steps so far have used; sel, the viewer's place
; of the checker picked, or (); dests, the places it can go; cursor,
; (TOP . SLOT); human, white, black, both or none; last, msg and line,
; the texts; help, the lines of the keys while they are shown, else ();
; and score, the games won, (WHITE . BLACK).
(def tui-view
  (fn (_ st)
    (def g (%get st %game))
    (def over (game-over? g))
    (list (pair (lit pos) (%shown st))
          (pair (lit view) (%get st %view))
          (pair (lit turn) (if over () (game-turn g)))
          (pair (lit dice) (if over () (game-dice g)))
          (pair (lit used) (List map step-die (%get st %done)))
          (pair (lit sel) (if (null? (%get st %sel)) () (%viewer-place st (%get st %sel))))
          (pair (lit dests) (List map (fn (_ c) (%viewer-place st (first c))) (%get st %dests)))
          (pair (lit cursor) (%get st %cursor))
          (pair (lit human) (%get st %human))
          (pair (lit last) (%get st %last))
          (pair (lit msg) (%note st))
          (pair (lit hint) (List map (fn (_ s) (list (%viewer-place st (first s)) (%viewer-place st (%2nd s)))) (%get st %hinted)))
          (pair (lit coaching) (%get st %coaching))
          (pair (lit line) (%line-text st))
          (pair (lit help) (if (%get st %help) %help-lines ()))
          (pair (lit score) (%get st %score)))))

; Whether a person plays SIDE in ST.
(def tui-human? (fn (_ st side) (%human? st side)))

(provide backgammon/tui
  tui-make tui-game tui-game! tui-quit? tui-message tui-last tui-done tui-score
  tui-engine-to-move? tui-auto-play! tui-solve-due? tui-solve-note! tui-solve! tui-key! tui-draw! tui-events! tui-view tui-counts tui-human?)
