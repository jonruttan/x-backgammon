; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/window.x -- the board in a window or a browser tab
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The loop backgammon/app runs on a terminal, run over a window's events:
; FRONT is Sdl, or Web for a browser tab, which answer the same messages.
; backgammon/tui keeps the game and says what a key does; backgammon/gui
; draws it; backgammon/sound is heard.
;
; A checker is moved by clicking it and then where it goes, or by
; dragging it there.  Every key the terminal takes works the same, and
; the buttons beside the board press them.
;
; What tui-events! tells is shown in turn, each a moment long: the dice
; tumble onto the felt and land, a checker slides from its place to the
; next, a hit checker is knocked to the bar.  While they play the board
; is drawn as it was before each one.  The engine plays once they are
; done and a moment more has passed, so its plays can be followed.

(module backgammon/window)

(import x/sys/sdl)
(import x/sys/web)
(import x/sys/posix)
(import x/sys/gc)
(import x/type/vector)
(import x/core/doors int& int+ int- int* int/ int% int< int=)
(import backgammon/board BAR pos-me pos-me-off pos-turn)
(import backgammon/tui tui-make tui-command! tui-quit? tui-engine-to-move? tui-auto-play! tui-solve-due? tui-solve-note! tui-solve! tui-key! tui-events! tui-view tui-counts)
(import backgammon/gui gui-make gui-draw! gui-at gui-spot gui-dice-x gui-canvas gui-width gui-height)
(import backgammon/sound sound-make sound-play! sound-close!)

; --- the window's state ------------------------------------------------------------

(def %front 0)
(def %win 1)
(def %st 2)
(def %gui 3)
(def %queue 4)    ; what to act on, oldest first: a key, (place N), or (release N)
(def %shows 5)    ; the events still to show, oldest first
(def %showing 6)  ; the one being shown, (EVENT . START-MS), or ()
(def %dirty 7)    ; whether the picture is out of date
(def %drawn 8)    ; the clock when it was last drawn
(def %pressed 9)  ; the place a press of the button was on, or ()
(def %sound 10)
(def %quiet 11)   ; the clock when the last event finished showing
(def %collected 12)
(def %slots 13)

(def %get (fn (_ w i) (Vector ref i w)))
(def %put! (fn (_ w i v) (Vector set! i v w)))
(def %2nd (fn (_ l) (first (rest l))))

(def %ms (fn (_) ((fn (_ t) (int+ (int* 1000 (first t)) (int/ (rest t) 1000))) (Sys time-of-day))))

(def %frame-ms 16)
(def %roll-ms 760)     ; the dice tumbling
(def %land-ms 560)     ; when in it they land
(def %step-ms 280)     ; a checker sliding
(def %over-ms 900)
(def %engine-wait 450) ; the moment before the engine plays

; --- keys ---------------------------------------------------------------------------

(def %named
  (list (pair 27 (lit escape)) (pair 13 (lit enter)) (pair 8 (lit backspace)) (pair 127 (lit backspace))
        (pair 1073741906 (lit up)) (pair 1073741905 (lit down)) (pair 1073741904 (lit left)) (pair 1073741903 (lit right))))

(def %printable " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")
(def %plain "1234567890-=[]\\;',./`")
(def %shifted "!@#$%^&*()_+{}|:\"<>?~")

(def %char (fn (_ code) (Str8 slice (- code 32) (- code 31) %printable)))

; The key a key-down event E is, as backgammon/tui takes keys: a string
; for a character, a name for the others, or () for none.  The keycode is
; the key's own character, so a shifted one is worked out from the
; modifiers.
(def %key-of
  (fn (_ e)
    (def code (List ref 1 e))
    (def mod (List ref 2 e))
    (def shift (not (= 0 (int& mod 3))))
    (def ctrl (not (= 0 (int& mod 192))))
    (def cmd (not (= 0 (int& mod 3072))))
    (def named (List find (fn (_ p) (= (first p) code)) %named))
    (match
      ((not (null? named)) (rest named))
      ((if ctrl (= code 99) #f) (lit interrupt))
      ((if cmd (= code 113) #f) "q")
      (ctrl ())
      (cmd ())
      ((if (< 96 code) (< code 123) #f) (%char (if shift (- code 32) code)))
      ((if (< 31 code) (< code 127) #f)
        ((fn (_ s) ((fn (_ i) (if (if shift (not (null? i)) #f) (Str8 slice i (+ i 1) %shifted) s)) (Str8 index-of s %plain)))
         (%char code)))
      (#t ()))))

; --- events -------------------------------------------------------------------------

(def %next-event
  (fn (_ w) (if (eq? (%get w %front) Sdl) (Sdl poll (%get w %win)) (Web poll))))

(def %queue! (fn (_ w item) (%put! w %queue (List append (%get w %queue) (list item)))))

; Event E taken: a key, a click or a press queued.
(def %event!
  (fn (_ w e)
    (def kind (first e))
    (match
      ((eq? kind (lit quit)) (%queue! w "q"))
      ((eq? kind (lit close)) (%queue! w "q"))
      ((eq? kind (lit key-down)) ((fn (_ k) (unless (null? k) (%queue! w k))) (%key-of e)))
      ((if (eq? kind (lit mouse-down)) (eq? (List ref 1 e) (lit left)) #f)
        ((fn (_ hit)
           (match ((null? hit) ())
                  ((eq? (first hit) (lit key)) (%queue! w (%2nd hit)))
                  (#t (do (%put! w %pressed (%2nd hit)) (%queue! w hit)))))
         (gui-at (List ref 2 e) (List ref 3 e))))
      ((if (eq? kind (lit mouse-up)) (eq? (List ref 1 e) (lit left)) #f)
        ((fn (_ hit pressed)
           (%put! w %pressed ())
           (when (if (null? pressed) #f (if (null? hit) #f (if (eq? (first hit) (lit place)) (not (= (%2nd hit) pressed)) #f)))
             (%queue! w (list (lit release) (%2nd hit)))))
         (gui-at (List ref 2 e) (List ref 3 e)) (%get w %pressed)))
      (#t ()))))

(def %pump!
  (fn (self w) ((fn (_ e) (unless (null? e) (do (%event! w e) (self w)))) (%next-event w))))

; ITEM acted on: a click on a place picks it; a button let go on another
; place than it was pressed on drops the checker picked there.
(def %act!
  (fn (_ w item)
    (def st (%get w %st))
    (%put! w %dirty #t)
    (match
      ((if (pair? item) (eq? (first item) (lit release)) #f)
        (unless (null? (rest (Assoc find (lit sel) (tui-view st)))) (tui-key! st (list (lit place) (%2nd item)))))
      (#t (tui-key! st item)))
    (Heap collect)))

; --- what happened, shown ----------------------------------------------------------

; The events tui has, put after those still to show; a jump drops those
; not shown yet, as the board has moved on without them.
(def %take-events!
  (fn (_ w)
    (List for-each
      (fn (_ e)
        (if (eq? (first e) (lit jump))
          (do (%put! w %shows ()) (%put! w %showing ()) (%put! w %dirty #t))
          (%put! w %shows (List append (%get w %shows) (list e)))))
      (tui-events! (%get w %st)))))

(def %length
  (fn (_ e) (match ((eq? (first e) (lit roll)) %roll-ms) ((eq? (first e) (lit step)) %step-ms) ((eq? (first e) (lit over)) %over-ms) (#t 0))))

; The next event begun, its sound started.
(def %begin!
  (fn (_ w now)
    (def e (first (%get w %shows)))
    (%put! w %shows (rest (%get w %shows)))
    (%put! w %showing (pair e now))
    (match ((eq? (first e) (lit roll)) (sound-play! (%get w %sound) (lit rattle)))
           ((eq? (first e) (lit over)) (sound-play! (%get w %sound) (lit win)))
           (#t ()))))

; The event being shown ended at NOW, its last sound heard.
(def %end!
  (fn (_ w now)
    (def e (first (%get w %showing)))
    (when (eq? (first e) (lit step))
      ((fn (_ s) (sound-play! (%get w %sound) (match ((List ref 2 s) (lit hit)) ((int< (%2nd s) 0) (lit off)) (#t (lit place)))))
       (List ref 2 e)))
    (%put! w %showing ())
    (%put! w %quiet now)))

; Progress T, 0 to 1000, eased out.
(def %ease (fn (_ t) (int- 1000 (int/ (int* (int- 1000 t) (int- 1000 t)) 1000))))

; The viewer's place of mover's index I in P, as VIEW sees the board.
(def %place-of
  (fn (_ p view i)
    (match ((int< i 0) 0) ((int= i BAR) 25) ((int= (pos-turn p) view) (int+ i 1)) (#t (int- 24 i)))))

; VIEW, the alist tui-view gives, with KVS put over it.
(def %over (fn (_ view kvs) (List append kvs view)))

; What to draw while event E is shown at progress T: (VIEW . ANIM).
(def %scene
  (fn (_ w e t now)
    (def st (%get w %st))
    (def view (tui-view st))
    (def side (rest (Assoc find (lit view) view)))
    (match
      ((eq? (first e) (lit step))
        ((fn (_ p s dice used)
           (def mover (pos-turn p))
           (def mine (int= mover side))
           (def from (%place-of p side (first s)))
           (def to (%place-of p side (%2nd s)))
           (def own (fn (_ n) ((fn (_ c) (if mine (first c) (rest c))) (tui-counts p side n))))
           (def a (gui-spot from mine (int- (own from) 1) (own from)))
           (def b (if (int= to 0) (gui-spot 0 mine (own 0) 15) (gui-spot to mine (own to) (int+ (own to) 1))))
           (def u (%ease t))
           (pair (%over view (list (pair (lit pos) p) (pair (lit turn) mover) (pair (lit dice) dice) (pair (lit used) used)
                                   (pair (lit sel) ()) (pair (lit dests) ()) (pair (lit hint) ())))
                 (list (pair (lit hide) (pair from mover))
                       (pair (lit moving) (list mover (int+ (first a) (int/ (int* (int- (first b) (first a)) u) 1000))
                                                (int+ (rest a) (int/ (int* (int- (rest b) (rest a)) u) 1000)))))))
         (List ref 1 e) (List ref 2 e) (List ref 3 e) (List ref 4 e)))
      ((eq? (first e) (lit roll))
        ((fn (_ roller d1 d2)
           (def rest-x (gui-dice-x side roller))
           (def from-x (if (int= roller side) (int+ rest-x 300) (int- rest-x 300)))
           (def u (%ease (if (int< t %land-ms) (int/ (int* t 1000) %land-ms) 1000)))
           (def tumbling (int< t %land-ms))
           (def face
             (fn (_ i d) (if tumbling (int+ 1 (int% (int+ (int/ now 70) (int* 4 i)) 6)) d)))
           (def die
             (fn (_ i d)
               (list (face i d)
                     (int+ (int+ from-x (int/ (int* (int- rest-x from-x) u) 1000)) (if (int= i 0) -33 33))
                     (int- 360 (int/ (int* (if (int= i 0) 50 80) (int- 1000 u)) 1000))
                     (int/ (int* (if (int= i 0) 70 -90) (int- 1000 u)) 1000))))
           (pair (%over view (list (pair (lit turn) roller)))
                 (list (pair (lit roller) roller) (pair (lit dice) (list (die 0 d1) (die 1 d2))))))
         (List ref 1 e) (List ref 2 e) (List ref 3 e)))
      (#t (pair view ())))))

; --- drawing ------------------------------------------------------------------------

; The garbage of drawing and of polling the front, collected at most
; every 250 ms: waiting on a move polls a hundred times a second.
(def %collect!
  (fn (_ w now)
    (when (int< 250 (int- now (%get w %collected))) (do (Heap collect) (%put! w %collected (%ms))))))

(def %frame!
  (fn (_ w now)
    (def s (%get w %showing))
    (def scene
      (if (null? s) (pair (tui-view (%get w %st)) ())
        (%scene w (first s) (if (int< 0 (%length (first s))) (int/ (int* (int- now (rest s)) 1000) (%length (first s))) 1000) now)))
    (when (if (null? s) #f (eq? (first (first s)) (lit roll)))
      (when (if (int< (int- %land-ms 17) (int- now (rest s))) (int< (int- now (rest s)) (int+ %land-ms 1)) #f)
        (sound-play! (%get w %sound) (lit land))))
    (gui-draw! (%get w %gui) (first scene) (rest scene))
    ((%get w %front) show! (%get w %win) (List ref 2 (gui-canvas (%get w %gui))))
    (%put! w %drawn now)
    (%put! w %dirty #f)
    (%collect! w now)))

; The event shown moved on: ended when its time is up, the next begun.
(def %advance!
  (fn (_ w now)
    (def s (%get w %showing))
    (when (if (null? s) #f (int< (%length (first s)) (int- now (rest s)))) (%end! w now))
    (when (if (null? (%get w %showing)) (not (null? (%get w %shows))) #f) (%begin! w now))))

(def %showing? (fn (_ w) (if (null? (%get w %showing)) (not (null? (%get w %shows))) #t)))

(def %loop
  (fn (self w)
    (def st (%get w %st))
    (def now (%ms))
    (%pump! w)
    (%take-events! w)
    (%advance! w now)
    (match
      ((tui-quit? st) ())
      ((not (null? (%get w %queue)))
        ((fn (_ item) (%put! w %queue (rest (%get w %queue))) (%act! w item) (self w)) (first (%get w %queue))))
      ((if (%get w %dirty) #t (%showing? w))
        (do ((fn (_ left) (when (int< 0 left) (Sys usleep (int* 1000 left)))) (int- %frame-ms (int- now (%get w %drawn))))
            (%frame! w (%ms))
            (self w)))
      ((tui-solve-due? st)
        (do (tui-solve-note! st) (%frame! w (%ms)) (tui-solve! st) (Heap collect) (%put! w %dirty #t) (self w)))
      ((if (tui-engine-to-move? st) (int< %engine-wait (int- now (%get w %quiet))) #f)
        (do (tui-auto-play! st) (Heap collect) (%put! w %dirty #t) (self w)))
      (#t (do (%collect! w now) (Sys usleep 8000) (self w))))))

; Play in a window drawn through FRONT, Sdl or Web, the dice from RND,
; the people playing HUMAN and the opponent OPP the other sides, the
; command START run first when it is not "": () when it was left, or
; what went wrong.
(def window-run
  (fn (_ front rnd human start opp)
    (when (eq? front Sdl) (Sdl hint! "SDL_VIDEO_MAC_FULLSCREEN_SPACES" "0"))
    (def w (Vector make %slots ()))
    (%put! w %front front)
    (%put! w %st ((fn (_ st) (unless (str=? start "") (tui-command! st start)) st) (tui-make rnd human opp)))
    (%put! w %gui (gui-make))
    (%put! w %dirty #t)
    (%put! w %drawn 0)
    (%put! w %quiet 0)
    (%put! w %collected 0)
    (%put! w %win (front scaling! (front open "x-backgammon" (gui-width) (gui-height) 1) (lit fit)))
    ; a window opened from a terminal leaves the keyboard with the
    ; terminal; a browser tab's focus is the browser's to give
    (when (eq? front Sdl) (Sdl raise! (%get w %win)))
    (%put! w %sound (sound-make front))
    (def failed (guard (e e) (do (%loop w) ())))
    (sound-close! (%get w %sound))
    (front close (%get w %win))
    failed))

(provide backgammon/window window-run)
