; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/play.x -- a game played a line at a time
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The dice are rolled for each turn.  A play is typed the way it is
; written, 24/18 13/11; anything else is a command, `help` lists them.
; The engine plays the sides no one else does, and a roll with only one
; play is played without asking.
;
; IO is (read say): read takes the prompt and answers the line, or ()
; at the end of the input; say writes text.

(module backgammon/play)

(import x/type/vector)
(import x/sys/gc)
(import x/core/doors int+ int- int< int= io-display-to-str str-byte-len str-byte-ref str-byte-sub)
(import backgammon/board WHITE BLACK pos-turn pos-me-pips pos-opp-pips play-text play-find)
(import backgammon/eval eval-ranked eval-best eval-contact?)
(import backgammon/bearoff bearoff-due? bearoff-solve!)
(import backgammon/game game-new game-pos game-dice game-result game-over? game-turn game-throw
  game-set-dice! game-play! game-undo! game-plays)
(import backgammon/show board-text)

(def %help
  (Str8 join "\n"
    (list "Type a play the way it is written: 24/18 13/11, 8/5(2), bar/22, 6/off, 24/18*/13."
          "Points are counted from your own home board."
          "Commands:"
          "  board          show the board"
          "  hint           the engine's best plays of your roll"
          "  moves          every legal play of your roll"
          "  pips           both pip counts"
          "  dice DD        set your dice by hand (31, 66)"
          "  undo           take back your last play"
          "  new            a new game"
          "  white, black   play that side against the engine"
          "  both, none     play both sides, or watch the engine play both"
          "  help, quit"
          "")))

; The session: a Vector of the game, the dice's source, and who the
; people play: white, black, both or none.
(def %s-game 0)
(def %s-rnd 1)
(def %s-human 2)

(def %get (fn (_ st i) (Vector ref i st)))
(def %put! (fn (_ st i v) (Vector set! i v st)))

(def %read (fn (_ io prompt) ((first io) prompt)))
(def %say (fn (_ io text) ((first (rest io)) text)))

(def %name (fn (_ side) (if (int= side WHITE) "White" "Black")))
(def %dice-text
  (fn (_ d) (Str8 append (io-display-to-str (first d)) "-" (io-display-to-str (first (rest d))))))

; "white", "black", "both" or "none" as the symbol, else ().
(def side-word
  (fn (_ s)
    (match ((str=? s "white") (lit white)) ((str=? s "black") (lit black))
           ((str=? s "both") (lit both)) ((str=? s "none") (lit none)) (#t ()))))

(def %human?
  (fn (_ st side)
    ((fn (_ h) (match ((eq? h (lit both)) #t) ((eq? h (lit none)) #f) ((eq? h (lit white)) (int= side WHITE)) (#t (int= side BLACK))))
     (%get st %s-human))))

(def %new-game!
  (fn (_ io st)
    (def g (game-new (%get st %s-rnd)))
    (%put! st %s-game g)
    (%say io (Str8 append "White rolls " (io-display-to-str (first (game-dice g)))
               ", Black rolls " (io-display-to-str (first (rest (game-dice g))))
               ": " (%name (game-turn g)) " moves first.\n"))))

; A score as text, its sign shown.
(def %score-text (fn (_ s) (Str8 append (if (int< s 0) "" "+") (io-display-to-str s))))

(def %hint-text
  (fn (_ ranked)
    (def best (first (first ranked)))
    (Str8 join ""
      (List map
        (fn (_ r) (Str8 append "  " (play-text (rest r)) "   " (%score-text (int- (first r) best)) "\n"))
        (List take 3 ranked)))))

(def %result-text
  (fn (_ r)
    (Str8 append (%name (first r)) " wins "
      (match ((int= (first (rest r)) 3) "a backgammon, 3 points")
             ((int= (first (rest r)) 2) "a gammon, 2 points")
             (#t "1 point"))
      ".\n")))

; The side to move's play PL made, and said.
(def %play!
  (fn (_ io st pl how)
    (def g (%get st %s-game))
    (%say io (Str8 append (%name (game-turn g)) " " how " " (play-text pl) ".\n"))
    (game-play! g pl)
    (when (game-over? g) (%say io (%result-text (game-result g))))
    (Heap collect)))

; The two-digit dice of S, (D1 D2), or ().
(def %dice-word
  (fn (_ s)
    (def die (fn (_ i) ((fn (_ d) (if (if (int< 0 d) (int< d 7) #f) d ())) (int- (str-byte-ref s i) 48))))
    (if (int= (str-byte-len s) 2)
      ((fn (_ a b) (if (if (null? a) #t (null? b)) () (list a b))) (die 0) (die 1))
      ())))

; S without its leading and trailing spaces.
(def %trim
  (fn (_ s)
    (def n (str-byte-len s))
    (def sp? (fn (_ i) (int= (str-byte-ref s i) 32)))
    (def a ((fn (self i) (if (if (int< i n) (sp? i) #f) (self (int+ i 1)) i)) 0))
    (def b ((fn (self i) (if (if (int< a i) (sp? (int- i 1)) #f) (self (int- i 1)) i)) n))
    (str-byte-sub s a (int- b a))))

(def %starts?
  (fn (_ s w) (if (int< (str-byte-len s) (str-byte-len w)) #f (str=? (str-byte-sub s 0 (str-byte-len w)) w))))

; Act on LINE, typed by the side to move: #f to quit, else #t.
(def %command
  (fn (_ io st line)
    (def g (%get st %s-game))
    (def d (game-dice g))
    (match
      ((if (str=? line "quit") #t (str=? line "exit")) #f)
      ((str=? line "help") (do (%say io %help) #t))
      ((str=? line "board") (do (%say io (board-text (game-pos g))) #t))
      ((str=? line "hint") (do (%say io (%hint-text (eval-ranked (game-pos g) (first d) (first (rest d))))) #t))
      ((str=? line "moves")
        (do (List for-each (fn (_ pl) (%say io (Str8 append "  " (play-text pl) "\n"))) (game-plays g)) #t))
      ((str=? line "pips")
        (do (%say io (Str8 append (%name (game-turn g)) " " (io-display-to-str (pos-me-pips (game-pos g)))
                       ", the other side " (io-display-to-str (pos-opp-pips (game-pos g))) "\n")) #t))
      ((%starts? line "dice ")
        ((fn (_ r)
           (if (null? r) (do (%say io "dice takes two dice: dice 31\n") #t)
             (do (game-set-dice! g (first r) (first (rest r))) #t)))
         (%dice-word (%trim (str-byte-sub line 5 (int- (str-byte-len line) 5))))))
      ((str=? line "undo")
        (do (unless (game-undo! g (fn (_ side) (%human? st side))) (%say io "nothing of yours to take back\n")) #t))
      ((str=? line "new") (do (%new-game! io st) #t))
      ((List includes? line (list "white" "black" "both" "none"))
        (do (%put! st %s-human (side-word line)) #t))
      (#t
        ((fn (_ found)
           (if (str? found) (do (%say io (Str8 append found ": " line "\n")) #t)
             (do (%play! io st found "plays") #t)))
         (play-find (game-pos g) (first d) (first (rest d)) line))))))

; One step of the session: #f when it is over.
(def %step
  (fn (_ io st)
    (def g (%get st %s-game))
    (match
      ((game-over? g)
        (if (eq? (%get st %s-human) (lit none)) #f
          ((fn (_ line)
             (match ((null? line) #f)
                    ((str=? (%trim line) "new") (do (%new-game! io st) #t))
                    ((str=? (%trim line) "quit") #f)
                    (#t (do (%say io "new or quit\n") #t))))
           (%read io "new or quit> "))))
      ((if (eval-contact? (game-pos g)) #f (bearoff-due?))
        (do (%say io "Solving the bear-off for this machine: about a minute, once.\n")
            (bearoff-solve!)
            #t))
      ((not (%human? st (game-turn g)))
        (do (%say io (Str8 append (%name (game-turn g)) " rolls " (%dice-text (game-dice g)) ".\n"))
            (%play! io st (eval-best (game-pos g) (first (game-dice g)) (first (rest (game-dice g)))) "plays")
            #t))
      ((int= (List length (game-plays g)) 1)
        (do (%say io (Str8 append (%name (game-turn g)) " rolls " (%dice-text (game-dice g)) ".\n"))
            (%play! io st (first (game-plays g)) "must play")
            #t))
      (#t
        ((fn (_ line) (if (null? line) #f (%command io st (%trim line))))
         (%read io (Str8 append (board-text (game-pos g))
                     (%name (game-turn g)) " to play " (%dice-text (game-dice g)) "> ")))))))

; A session on IO with the dice from RND, the people playing HUMAN.
(def play-run
  (fn (_ io rnd human)
    (def st (Vector of () rnd human))
    (%new-game! io st)
    ((fn (self) (when (%step io st) (self))))
    0))

(provide backgammon/play play-run side-word)
