; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/gui.x -- the board drawn as a picture, for a window
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Draws what tui-view says on an RGBA canvas (x/gfx/canvas) of %width by
; %height: the board in its wooden frame on the left, the felt in two
; halves with the bar between, the points, the tray for the checkers
; borne off at the right; the players and the buttons in a panel beside
; it; and the play's texts under it.  It also says what a point of the
; picture is: a place, a button's key, or nothing.  The window
; (backgammon/window) owns the loop and the animation, and hands over
; what is moving.
;
; The board is drawn from the viewer's side as the terminal's is, the
; places in the same fourteen slots a row: slot 6 the bar, 13 the tray.
; What never changes, the frame, the felt, the points and their numbers,
; the panel and its buttons, is drawn once and copied under each frame.
; A checker is discs stamped from masks made once: its rim, its face, a
; groove and a light; a die at rest the same.  A die turning is filled
; afresh each frame.
;
; Lengths are pixels; points handed to x/gfx/shape are in 256ths of a
; pixel.  An angle is a step of 32 to the turn.

(module backgammon/gui)

(import x/gfx/canvas)
(import x/gfx/shape)
(import x/gfx/font)
(import x/type/vector)
(import x/core/doors int+ int- int* int/ int% int< int= char->int io-display-to-str str-byte-len str-byte-ref)
(import backgammon/board WHITE BLACK pos-me-pips pos-opp-pips pos-turn)
(import backgammon/tui tui-counts)

; --- the layout ---------------------------------------------------------------------

(def %width 1180)
(def %height 800)
(def %fx 20)           ; the frame's left and top, width and height
(def %fy 20)
(def %fw 920)
(def %fh 680)
(def %left 44)         ; the first slot's left, a slot's width
(def %pw 60)
(def %top 44)          ; the felt's top and bottom
(def %bottom 676)
(def %ph 260)          ; a point's length
(def %mid 360)         ; the middle of the band between the rows
(def %tray-x 848)
(def %tray-w 68)
(def %r 26)            ; a checker's radius
(def %die 26)          ; half a die's side
(def %px 960)          ; the panel's left and width
(def %pw2 200)
(def %button-h 40)
(def %buttons-y 300)

(def %buttons
  (list (list "New game" "n") (list "Take back" "u") (list "Hint" "h") (list "Coach" "c")
        (list "Turn board" "v") (list "Keys" "?") (list "Quit" "q")))

(def gui-width (fn (_) %width))
(def gui-height (fn (_) %height))

; --- colours ------------------------------------------------------------------------

(def %c-back (list 28 24 22))
(def %c-wood (list 112 72 40))
(def %c-wood-edge (list 78 48 26))
(def %c-felt (list 34 92 58))
(def %c-felt-edge (list 26 72 45))
(def %c-light (list 226 200 152))
(def %c-dark (list 156 44 38))
(def %c-tray (list 58 38 22))
(def %c-number (list 232 212 172))
(def %c-text (list 236 230 220))
(def %c-dim (list 150 142 132))
(def %c-gold (list 250 208 70))
(def %c-card (list 48 42 38))
(def %c-button (list 70 60 52))

; A side's checker colours: (RIM FACE GROOVE), and its dice's (FACE PIP).
(def %checker-colours
  (fn (_ side) (if (int= side WHITE) (list (list 168 156 136) (list 240 232 214) (list 214 204 184))
                 (list (list 14 12 12) (list 52 46 46) (list 34 30 30)))))
(def %dice-colours
  (fn (_ side) (if (int= side WHITE) (list (list 246 242 232) (list 30 26 26)) (list (list 150 32 30) (list 246 240 230)))))

; --- geometry -----------------------------------------------------------------------

; A cosine table, 1024ths, for the 32 steps of a turn.
(def %cos-table (list 1024 1004 946 851 724 569 392 200 0))
(def %cos
  (fn (_ k)
    ((fn (_ k)
       (match ((int< k 9) (List ref k %cos-table))
              ((int< k 17) (int- 0 (List ref (int- 16 k) %cos-table)))
              ((int< k 25) (int- 0 (List ref (int- k 16) %cos-table)))
              (#t (List ref (int- 32 k) %cos-table))))
     (int% (int+ (int% k 32) 32) 32))))
(def %sin (fn (_ k) (%cos (int- k 8))))

; A circle about X Y, radius R, as a contour of 32 points.
(def %circle
  (fn (_ x y r)
    (List map (fn (_ k) (pair (int+ (int* x 256) (int/ (int* r (%cos k)) 4)) (int+ (int* y 256) (int/ (int* r (%sin k)) 4))))
      (List range 0 32))))

(def %rect
  (fn (_ x y w h)
    (list (pair (int* x 256) (int* y 256)) (pair (int* (int+ x w) 256) (int* y 256))
          (pair (int* (int+ x w) 256) (int* (int+ y h) 256)) (pair (int* x 256) (int* (int+ y h) 256)))))

; The x of slot S's left edge, and its width.
(def %slot-x (fn (_ s) (if (int= s 13) %tray-x (int+ %left (int* s %pw)))))
(def %slot-w (fn (_ s) (if (int= s 13) %tray-w %pw)))

; Place N's slot, (TOP . SLOT), as the terminal lays them out.
(def %place-slot
  (fn (_ n)
    (match ((int< 18 n) (pair #t (int- n 12)))
           ((int< 12 n) (pair #t (int- n 13)))
           ((int< 6 n) (pair #f (int- 12 n)))
           (#t (pair #f (int- 13 n))))))

(def %slot-place
  (fn (_ top slot)
    (match ((int= slot 6) 25)
           ((int= slot 13) 0)
           (top (if (int< slot 6) (int+ 13 slot) (int+ 12 slot)))
           ((int< slot 6) (int- 12 slot))
           (#t (int- 13 slot)))))

; The gap between checkers in a stack of N, the length of a point
; holding them all.
(def %gap (fn (_ n) (if (int< n 6) (int* 2 %r) (int/ (int- %ph (int* 2 %r)) (int- n 1)))))

; The middle of the Kth checker from the edge of a stack of N on place
; PLACE, MINE whether it is the viewer's: (X . Y).  On the bar the
; viewer's rise from the middle in its top half, the other's go down in
; the bottom; in the tray they lie edge on, the viewer's from the
; bottom.
(def gui-spot
  (fn (_ place mine k n)
    (match
      ((int= place 25)
        (pair (int+ (%slot-x 6) (int/ %pw 2))
          (if mine (int- (int- %mid 56) (int+ %r (int* k (%gap n)))) (int+ (int+ %mid 56) (int+ %r (int* k (%gap n)))))))
      ((int= place 0)
        (pair (int+ %tray-x (int/ %tray-w 2)) (if mine (int- %bottom (int+ 9 (int* 16 k))) (int+ %top (int+ 9 (int* 16 k))))))
      (#t ((fn (_ at)
             (pair (int+ (%slot-x (rest at)) (int/ %pw 2))
               (if (first at) (int+ %top (int+ %r (int* k (%gap n)))) (int- %bottom (int+ %r (int* k (%gap n)))))))
           (%place-slot place))))))

; What is at X Y: (place N), (key K) for a button, or ().
(def gui-at
  (fn (_ x y)
    (def slot
      (match ((int< x %left) ())
             ((int< x (int+ %left (int* 13 %pw))) (int/ (int- x %left) %pw))
             ((int< x %tray-x) ())
             ((int< x (int+ %tray-x %tray-w)) 13)
             (#t ())))
    (def half (match ((int< y %top) ()) ((int< y (int+ %top %ph)) (lit top))
                     ((int< y (int- %bottom %ph)) ()) ((int< y %bottom) (lit bottom)) (#t ())))
    (def button
      (if (if (int< (int- %px 1) x) (int< x (int+ %px %pw2)) #f)
        ((fn (_ i) (if (if (int< -1 i) (int< i (List length %buttons)) #f)
                     (if (int< (int% (int- y %buttons-y) (int+ %button-h 10)) %button-h) (List ref i %buttons) ()) ()))
         (if (int< y %buttons-y) -1 (int/ (int- y %buttons-y) (int+ %button-h 10))))
        ()))
    (match ((not (null? button)) (list (lit key) (%2nd button)))
           ((if (null? slot) #t (null? half)) ())
           (#t (list (lit place) (%slot-place (eq? half (lit top)) slot))))))

(def %2nd (fn (_ l) (first (rest l))))

; --- text ---------------------------------------------------------------------------
;
; x/gfx/font's strokes, a string drawn once as a mask, white on clear, and
; kept, then stamped in its colour wherever it is wanted.  The middle dot
; is a dot, the minus sign a hyphen; any other character past ASCII a
; space.

(def %codes
  (fn (_ text)
    (def n (str-byte-len text))
    (def b (fn (_ i) (if (int< i n) (char->int (str-byte-ref text i)) 0)))
    ((fn (self i acc)
       (match
         ((not (int< i n)) (List reverse acc))
         ((int< (b i) 128) (self (int+ i 1) (pair (b i) acc)))
         ((if (int= (b i) 194) (int= (b (int+ i 1)) 183) #f) (self (int+ i 2) (pair 183 acc)))
         ((if (int= (b i) 226) (if (int= (b (int+ i 1)) 136) (int= (b (int+ i 2)) 146) #f) #f) (self (int+ i 3) (pair 45 acc)))
         ((int< (b i) 192) (self (int+ i 1) acc))
         (#t (self (int+ i 1) (pair 32 acc)))))
     0 ())))

(def %strokes-of (fn (_ code) (if (int= code 183) (list (list (pair 2 3))) (Font glyph code))))

; TEXT's width in pixels, its capitals H high.
(def gui-text-w (fn (_ text h) (int/ (int* (List length (%codes text)) (int* 6 h)) 6)))

; TEXT as a mask: (CANVAS PAD), its capitals H high, the capitals' top
; PAD pixels down and the first character PAD pixels in.
(def %text-mask
  (fn (_ text h)
    (def codes (%codes text))
    (def u (int/ (int* h 256) 6))
    (def w (if (int< (int* h 26) 300) 300 (int* h 26)))
    (def pad (int+ 2 (int/ w 256)))
    (def c (Canvas make (int+ (gui-text-w text h) (int+ (int* 2 pad) 1)) (int+ (int/ (int* h 4) 3) (int+ (int* 2 pad) 1))))
    (def at (fn (_ i p) (pair (int+ (int* pad 256) (int+ (int* i (int* 6 u)) (int* (first p) u)))
                               (int+ (int* pad 256) (int* (int- 6 (rest p)) u)))))
    (def lines
      ((fn (self i cs acc)
         (if (null? cs) acc
           (self (int+ i 1) (rest cs)
             (List append (List map (fn (_ st) (pair #f (List map (fn (_ p) (at i p)) (if (null? (rest st)) (list (first st) (first st)) st))))
                            (%strokes-of (first cs)))
               acc))))
       0 codes ()))
    (unless (null? lines) (Shape strokes! c lines w (list 255 255 255)))
    (list c pad)))

(def %mask-of
  (fn (_ g text h)
    (def cache (Vector ref %g-texts g))
    (def key (Str8 append (io-display-to-str h) "|" text))
    (if (cache has? key) (cache get key)
      ((fn (_ m) (cache set! key m) m) (%text-mask text h)))))

; TEXT drawn on C with its capitals' top left at X Y, H high, in COLOUR.
(def %text!
  (fn (_ g c x y text h colour)
    (unless (str=? text "")
      ((fn (_ m)
         (def mc (first m))
         (Canvas stamp! c (int- x (%2nd m)) (int- y (%2nd m)) mc 0 0 (first mc) (%2nd mc) colour))
       (%mask-of g text h)))))

(def %text-mid!
  (fn (_ g c x y text h colour) (%text! g c (int- x (int/ (gui-text-w text h) 2)) y text h colour)))

; --- the gui ------------------------------------------------------------------------
;
; A Vector: the canvas drawn on, the board's background, the text masks
; made, and the masks of a checker, (RIM FACE GROOVE INNER LIGHT MARK
; DEST), each (X Y CANVAS) about the checker's middle.

(def %g-canvas 0)
(def %g-back 1)
(def %g-texts 2)
(def %g-checker 3)

(def gui-canvas (fn (_ g) (Vector ref %g-canvas g)))

(def %disc (fn (_ x y r) (Shape mask (list (%circle x y r)))))

(def gui-make
  (fn (_)
    (def g (Vector make 4 ()))
    (Vector set! %g-canvas (Canvas make %width %height) g)
    (Vector set! %g-texts (Dict make) g)
    (Vector set! %g-checker
      (list (%disc 0 0 %r) (%disc 0 0 (int- %r 2)) (%disc 0 0 (int- %r 8)) (%disc 0 0 (int- %r 10))
            (%disc -8 -9 7) (%disc 0 0 (int+ %r 4)) (%disc 0 0 (int- %r 6)))
      g)
    (Vector set! %g-back (%background g) g)
    g))

(def %stamp!
  (fn (_ c m x y colour)
    (unless (null? m)
      ((fn (_ mc) (Canvas stamp! c (int+ x (first m)) (int+ y (%2nd m)) mc 0 0 (first mc) (%2nd mc) colour))
       (List ref 2 m)))))

; The frame, the felt, the points and their numbers, the panel and the
; buttons: drawn once.
(def %background
  (fn (_ g)
    (def c (Canvas make %width %height))
    (Canvas fill! c 0 0 %width %height %c-back)
    (Canvas fill! c %fx %fy %fw %fh %c-wood-edge)
    (Canvas fill! c (int+ %fx 3) (int+ %fy 3) (int- %fw 6) (int- %fh 6) %c-wood)
    (List for-each
      (fn (_ x)
        (Canvas fill! c (int- x 2) (int- %top 2) (int+ (int* 6 %pw) 4) (int+ (int- %bottom %top) 4) %c-felt-edge)
        (Canvas fill! c x %top (int* 6 %pw) (int- %bottom %top) %c-felt))
      (list %left (%slot-x 7)))
    (Canvas fill! c (int+ (%slot-x 6) 4) %top (int- %pw 8) (int- %bottom %top) %c-wood-edge)
    (Canvas fill! c (int- %tray-x 2) (int- %top 2) (int+ %tray-w 4) (int+ (int- %bottom %top) 4) %c-wood-edge)
    (Canvas fill! c %tray-x %top %tray-w (int- %bottom %top) %c-tray)
    (Canvas fill! c %tray-x (int- %mid 3) %tray-w 6 %c-wood-edge)
    (List for-each
      (fn (_ n)
        ((fn (_ at)
           (def x (%slot-x (rest at)))
           (def top (first at))
           (def colour (if (int= 0 (int% (int+ (rest at) (if top 1 0)) 2)) %c-dark %c-light))
           (def edge (if top %top %bottom))
           (def tip (if top (int+ %top %ph) (int- %bottom %ph)))
           (Shape fill! c (list (list (pair (int* (int+ x 3) 256) (int* edge 256)) (pair (int* (int+ x (int- %pw 3)) 256) (int* edge 256))
                                      (pair (int* (int+ x (int/ %pw 2)) 256) (int* tip 256))))
             colour)
           (%text-mid! g c (int+ x (int/ %pw 2)) (if top (int+ %fy 7) (int+ %bottom 8)) (io-display-to-str n) 10 %c-number))
         (%place-slot n)))
      (List range 1 25))
    (%text! g c %px 34 "x-backgammon" 18 %c-text)
    (List for-each
      (fn (_ i)
        ((fn (_ b y)
           (Canvas fill! c %px y %pw2 %button-h %c-wood-edge)
           (Canvas fill! c (int+ %px 2) (int+ y 2) (int- %pw2 4) (int- %button-h 4) %c-button)
           (%text-mid! g c (int+ %px (int/ %pw2 2)) (int+ y 14) (first b) 12 %c-text))
         (List ref i %buttons) (int+ %buttons-y (int* i (int+ %button-h 10)))))
      (List range 0 (List length %buttons)))
    c))

; --- drawing ------------------------------------------------------------------------

(def %get (fn (_ v k) (rest (Assoc find k v))))

; A checker of SIDE with its middle at X Y; MARK is #t when it is picked.
(def %checker!
  (fn (_ g c x y side mark)
    (def ms (Vector ref %g-checker g))
    (def cs (%checker-colours side))
    (when mark (%stamp! c (List ref 5 ms) x y %c-gold))
    (%stamp! c (List ref 0 ms) x y (first cs))
    (%stamp! c (List ref 1 ms) x y (%2nd cs))
    (%stamp! c (List ref 2 ms) x y (List ref 2 cs))
    (%stamp! c (List ref 3 ms) x y (%2nd cs))
    (%stamp! c (List ref 4 ms) x y (list 255 255 255 (if (int= side WHITE) 90 40)))))

; A checker borne off, edge on, its middle at X Y.
(def %edge!
  (fn (_ c x y side)
    (def cs (%checker-colours side))
    (Canvas fill! c (int- x 30) (int- y 7) 60 14 (first cs))
    (Canvas fill! c (int- x 28) (int- y 5) 56 10 (%2nd cs))))

; Every checker of P on the board from VIEW's side, HIDE's place (or ())
; one fewer for the one moving from it.
(def %checkers!
  (fn (_ g c p view sel hide)
    (List for-each
      (fn (_ n)
        (def counts (tui-counts p view n))
        (def mine (int< 0 (first counts)))
        (def side (if mine view (int- 1 view)))
        (def stack!
          (fn (_ n-place count side mine)
            (def shown (if (if (null? hide) #f (if (int= (first hide) n-place) (int= (rest hide) side) #f)) (int- count 1) count))
            (List for-each
              (fn (_ k)
                ((fn (_ at)
                   (if (int= n-place 0) (%edge! c (first at) (rest at) side)
                     (%checker! g c (first at) (rest at) side
                       (if (null? sel) #f (if (int= sel n-place) (if mine (int= k (int- shown 1)) #f) #f)))))
                 (gui-spot n-place mine k shown)))
              (List range 0 shown))))
        (if (if (int= n 25) #t (int= n 0))
          (do (stack! n (first counts) view #t) (stack! n (rest counts) (int- 1 view) #f))
          (stack! n (if mine (first counts) (rest counts)) side mine)))
      (List range 0 26))))

; The places the checker picked can go, marked where it would land.
(def %dests!
  (fn (_ g c p view dests)
    (def ms (Vector ref %g-checker g))
    (List for-each
      (fn (_ n)
        (def counts (tui-counts p view n))
        (if (int= n 0)
          (Canvas fill! c (int+ %tray-x 4) (int- (rest (gui-spot 0 #t (first counts) 15)) 7) (int- %tray-w 8) 14 (list 250 208 70))
          ((fn (_ at) (%stamp! c (List ref 6 ms) (first at) (rest at) (list 250 208 70 170)))
           (gui-spot n #t (if (int< 0 (rest counts)) 0 (first counts)) (int+ (first counts) 1)))))
      dests)))

; The play hinted, each step (FROM TO) a gold line from the checker that
; moves to a ring where it lands, the steps made one after another.
(def %hint-marks!
  (fn (_ c p view hint)
    (def moved (Vector make 26 0))
    (def own (fn (_ n) (int+ (first (tui-counts p view n)) (Vector ref n moved))))
    (def add! (fn (_ n d) (Vector set! n (int+ (Vector ref n moved) d) moved)))
    (def wide (int* 4 256))
    (List for-each
      (fn (_ s)
        (def from (first s))
        (def to (%2nd s))
        (def a (gui-spot from #t (int- (own from) 1) (own from)))
        (add! from -1)
        (def b (if (int= to 0) (gui-spot 0 #t (own 0) 15)
                 (gui-spot to #t (if (int< 0 (rest (tui-counts p view to))) 0 (own to)) (int+ (own to) 1))))
        (add! to 1)
        (Shape strokes! c (list (pair #f (list (pair (int* (first a) 256) (int* (rest a) 256)) (pair (int* (first b) 256) (int* (rest b) 256)))))
          wide %c-gold)
        (if (int= to 0)
          (Canvas fill! c (int+ %tray-x 4) (int- (rest b) 7) (int- %tray-w 8) 14 %c-gold)
          (Shape strokes! c (list (pair #t (%circle (first b) (rest b) (int- %r 3)))) wide %c-gold)))
      hint)))

; The coach's button marked while the coach is on.
(def %coach-mark!
  (fn (_ c on)
    (when on
      ((fn (_ y) (Shape fill! c (list (%circle (int+ %px (int- %pw2 20)) (int+ y (int/ %button-h 2)) 5)) %c-gold))
       (int+ %buttons-y (int* 3 (int+ %button-h 10)))))))

; A die showing FACE, its middle at X Y, turned by step A; DIM when used.
(def %pips
  (list (list (pair 0 0)) (list (pair -1 -1) (pair 1 1)) (list (pair -1 -1) (pair 0 0) (pair 1 1))
        (list (pair -1 -1) (pair 1 -1) (pair -1 1) (pair 1 1)) (list (pair -1 -1) (pair 1 -1) (pair 0 0) (pair -1 1) (pair 1 1))
        (list (pair -1 -1) (pair 1 -1) (pair -1 0) (pair 1 0) (pair -1 1) (pair 1 1))))

; Point DX DY from X Y turned by step A, in 256ths.
(def %turned
  (fn (_ x y dx dy a)
    (pair (int+ (int* x 256) (int/ (int* 256 (int- (int* dx (%cos a)) (int* dy (%sin a)))) 1024))
          (int+ (int* y 256) (int/ (int* 256 (int+ (int* dx (%sin a)) (int* dy (%cos a)))) 1024)))))

(def %die!
  (fn (_ c x y face a side dim)
    (def cs (%dice-colours side))
    (def h %die)
    (def k 7)
    ; a quarter circle of radius K round each corner's centre, clockwise
    ; on the screen from the bottom right, steps 0 to 8 of each quarter
    (def arc
      (fn (_ sx sy start)
        (List map (fn (_ j) (%turned x y (int+ (int* sx (int- h k)) (int/ (int* k (%cos (int+ start j))) 1024))
                                         (int+ (int* sy (int- h k)) (int/ (int* k (%sin (int+ start j))) 1024)) a))
          (List range 0 9))))
    (def outline (List append (arc 1 1 0) (arc -1 1 8) (arc -1 -1 16) (arc 1 -1 24)))
    (Shape fill! c (list (List map (fn (_ p) (pair (int+ (first p) 768) (int+ (rest p) 1024))) outline)) (list 0 0 0 90))
    (Shape fill! c (list outline) (if dim (%dimmed (first cs)) (first cs)))
    (Shape fill! c
      (List map (fn (_ q) ((fn (_ ctr) (%circle-at ctr 5)) (%turned x y (int* 13 (first q)) (int* 13 (rest q)) a)))
        (List ref (int- face 1) %pips))
      (if dim (%dimmed (%2nd cs)) (%2nd cs)))))

(def %circle-at
  (fn (_ ctr r) (List map (fn (_ k) (pair (int+ (first ctr) (int/ (int* r (%cos (int* 2 k))) 4)) (int+ (rest ctr) (int/ (int* r (%sin (int* 2 k))) 4)))) (List range 0 16))))

(def %dimmed (fn (_ col) (List map (fn (_ v) (int/ (int+ v (int* 2 90)) 3)) col)))

; The dice at rest: on the half of the side to move, four for a double,
; those used dim.
(def %dice!
  (fn (_ c view turn dice used)
    (unless (if (null? turn) #t (null? dice))
      (do
        (def faces (if (int= (first dice) (%2nd dice)) (List repeat 4 (first dice)) dice))
        (def cx (gui-dice-x view turn))
        (def n (List length faces))
        (def marked
          ((fn (self fs us)
             (if (null? fs) ()
               (if (List includes? (first fs) us) (pair (pair (first fs) #t) (self (rest fs) (%drop (first fs) us)))
                 (pair (pair (first fs) #f) (self (rest fs) us)))))
           faces used))
        (List for-each
          (fn (_ i)
            ((fn (_ f) (%die! c (int+ (int- cx (int* 33 (int- n 1))) (int* 66 i)) %mid (first f) 0 turn (rest f)))
             (List ref i marked)))
          (List range 0 n))))))

(def %drop (fn (self d l) (match ((null? l) ()) ((int= (first l) d) (rest l)) (#t (pair (first l) (self d (rest l)))))))

; The middle of the dice's place when TURN is to move: the viewer's on
; the right half, the other's on the left.
(def gui-dice-x
  (fn (_ view turn) (int+ (%slot-x (if (int= turn view) 7 0)) (int* 3 %pw))))

; A side's card in the panel: its checker, its name and who plays it,
; its pips, a gold edge when it is to move.
(def %card!
  (fn (_ g c y side p turn human)
    (def x %px)
    (Canvas fill! c x y %pw2 64 (if (eq? side turn) %c-gold %c-card))
    (Canvas fill! c (int+ x 2) (int+ y 2) (int- %pw2 4) 60 %c-card)
    (%checker! g c (int+ x 32) (int+ y 32) side #f)
    (%text! g c (int+ x 64) (int+ y 14) (if (int= side WHITE) "White" "Black") 13 %c-text)
    ((fn (_ who) (%text! g c (int- (int+ x (int- %pw2 10)) (gui-text-w who 9)) (int+ y 17) who 9 %c-dim))
     (if (%plays? human side) "you" "engine"))
    (%text! g c (int+ x 64) (int+ y 40)
      (Str8 append (io-display-to-str (if (int= (pos-turn p) side) (pos-me-pips p) (pos-opp-pips p))) " pips")
      11 %c-dim)))

(def %plays?
  (fn (_ human side)
    (match ((eq? human (lit both)) #t) ((eq? human (lit none)) #f)
           ((eq? human (lit white)) (int= side WHITE)) (#t (int= side BLACK)))))

; The keys, over the board.
(def %help!
  (fn (_ g c lines)
    (def x 150)
    (def y 110)
    (def w 640)
    (def h (int+ 40 (int* 26 (List length lines))))
    (Canvas fill! c (int- x 3) (int- y 3) (int+ w 6) (int+ h 6) %c-gold)
    (Canvas fill! c x y w h (list 32 28 26))
    (List for-each (fn (_ i) (%text! g c (int+ x 30) (int+ y (int+ 24 (int* 26 i))) (List ref i lines) 12 %c-text))
      (List range 0 (List length lines)))))

; The cursor's slot, outlined.
(def %cursor!
  (fn (_ c cur)
    (def x (%slot-x (rest cur)))
    (def w (%slot-w (rest cur)))
    (def y (if (first cur) %top (int- %bottom %ph)))
    (Canvas fill! c x y w 2 %c-gold)
    (Canvas fill! c x (int+ y (int- %ph 2)) w 2 %c-gold)
    (Canvas fill! c x y 2 %ph %c-gold)
    (Canvas fill! c (int+ x (int- w 2)) y 2 %ph %c-gold)))

; VIEW drawn on G's canvas, as tui-view says it, with ANIM, an alist of
; what is moving: moving, (SIDE X Y), a checker drawn over the rest;
; hide, (PLACE . SIDE), a place one of SIDE's checkers is drawn missing
; from; dice, the dice turning, each (FACE X Y STEP), in place of the
; dice at rest.
(def gui-draw!
  (fn (_ g view anim)
    (def c (Vector ref %g-canvas g))
    (def p (%get view (lit pos)))
    (def side (%get view (lit view)))
    (def turn (%get view (lit turn)))
    (def found (fn (_ k) ((fn (_ e) (if (null? e) () (rest e))) (Assoc find k anim))))
    (Canvas copy! c 0 0 (Vector ref %g-back g) 0 0 %width %height)
    (%cursor! c (%get view (lit cursor)))
    (%checkers! g c p side (%get view (lit sel)) (found (lit hide)))
    (%dests! g c p side (%get view (lit dests)))
    (%hint-marks! c p side (%get view (lit hint)))
    (%coach-mark! c (%get view (lit coaching)))
    (if (null? (found (lit dice)))
      (%dice! c side turn (%get view (lit dice)) (%get view (lit used)))
      (List for-each (fn (_ d) (%die! c (List ref 1 d) (List ref 2 d) (first d) (List ref 3 d) (found (lit roller)) #f)) (found (lit dice))))
    ((fn (_ m) (unless (null? m) (%checker! g c (List ref 1 m) (List ref 2 m) (first m) #f))) (found (lit moving)))
    (def human (%get view (lit human)))
    (%card! g c 90 WHITE p turn human)
    (%card! g c 166 BLACK p turn human)
    ((fn (_ s) (%text! g c %px 252 (Str8 append "Games  " (io-display-to-str (first s)) " - " (io-display-to-str (rest s))) 12 %c-text))
     (%get view (lit score)))
    (%text! g c %fx 718 (%get view (lit last)) 14 %c-text)
    (%text! g c %fx 746 (%get view (lit msg)) 14 %c-gold)
    (%text! g c %fx 774 (%get view (lit line)) 10 %c-dim)
    ((fn (_ h) (unless (null? h) (%help! g c h))) (%get view (lit help)))
    c))

(provide backgammon/gui gui-make gui-draw! gui-at gui-spot gui-dice-x gui-canvas gui-width gui-height gui-text-w)
