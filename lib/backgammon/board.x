; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/board.x -- the position and its plays
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A position is seen from the side to move.  Each side has 25 places:
; index 0 to 23 are its points 1 to 24, counted from its own home board,
; and index 24 is its bar.  A checker borne off is in none of them.  The
; other side's index I is this side's index 23 - I.
;
; A position is one Vector whose raw slots are read with the obj doors:
; slot I + 1 holds the mover's checkers at index I, slot I + 26 the
; other side's, and slot 51 the colour that moves, 0 white or 1 black.
;
; A step is (FROM TO HIT): one checker moved one die from index FROM to
; FROM less the die, so TO below 0 is borne off (and the die is always
; FROM - TO); HIT is #t when it hit a blot.  A play is (STEPS . POS),
; the steps in the order played and the position they leave, still seen
; from the side that played them.

(module backgammon/board)

(import x/type/vector)
(import x/type/dict)
(import x/core/doors int+ int- int* int< int= obj-ref obj-set! str-make str->ptr ptr-set! str-byte-len str-byte-ref str-byte-sub
  io-display-to-str)

(def BAR 24)
(def CHECKERS 15)
(def WHITE 0)
(def BLACK 1)

(def %slots 51)
(def %turn 51)

(def %2nd (fn (_ l) (first (rest l))))
(def %3rd (fn (_ l) (first (rest (rest l)))))

; --- places ------------------------------------------------------------------

(def pos-me (fn (_ p i) (obj-ref p (int+ i 1))))
(def pos-opp (fn (_ p i) (obj-ref p (int+ i 26))))
(def pos-turn (fn (_ p) (obj-ref p %turn)))
(def %me! (fn (_ p i n) (obj-set! p (int+ i 1) n)))
(def %opp! (fn (_ p i n) (obj-set! p (int+ i 26) n)))

; The sum of P's raw slots from FIRST up to, not including, LAST.
(def %sum
  (fn (_ p first last)
    (def go (fn (self i n) (if (int< i last) (self (int+ i 1) (int+ n (obj-ref p i))) n)))
    (go first 0)))

(def pos-copy
  (fn (_ p)
    (def q (Vector make %slots 0))
    (def go (fn (self i) (when (int< i (int+ %slots 1)) (obj-set! q i (obj-ref p i)) (self (int+ i 1)))))
    (go 1)
    q))

; The position TURN moves in: ME and OPP are each side's checkers as a
; list of (POINT . COUNT), points 1 to 24 counted from that side's home,
; 25 its bar.
(def pos-make
  (fn (_ turn me opp)
    (def p (Vector make %slots 0))
    (List for-each (fn (_ c) (%me! p (int- (first c) 1) (rest c))) me)
    (List for-each (fn (_ c) (%opp! p (int- (first c) 1) (rest c))) opp)
    (obj-set! p %turn turn)
    p))

(def %start-men (list (pair 24 2) (pair 13 5) (pair 8 3) (pair 6 5)))

; The game's first position, white to move.
(def pos-start (fn (_) (pos-make WHITE %start-men %start-men)))

; P seen from the other side: its turn.
(def pos-swap
  (fn (_ p)
    (def q (Vector make %slots 0))
    (def go
      (fn (self i)
        (when (int< i 25)
          (%me! q i (pos-opp p i))
          (%opp! q i (pos-me p i))
          (self (int+ i 1)))))
    (go 0)
    (obj-set! q %turn (int- 1 (pos-turn p)))
    q))

(def pos-me-off (fn (_ p) (int- CHECKERS (%sum p 1 26))))
(def pos-opp-off (fn (_ p) (int- CHECKERS (%sum p 26 51))))

; The pips each side has still to move: a checker on index I has I + 1.
(def %pips
  (fn (_ p base)
    (def go (fn (self i n) (if (int< i 25) (self (int+ i 1) (int+ n (int* (int+ i 1) (obj-ref p (int+ base i))))) n)))
    (go 0 0)))
(def pos-me-pips (fn (_ p) (%pips p 1)))
(def pos-opp-pips (fn (_ p) (%pips p 26)))

; #t when either side has borne off every checker.
(def pos-over?
  (fn (_ p) (if (int= (pos-me-off p) CHECKERS) #t (int= (pos-opp-off p) CHECKERS))))

; Fifty bytes, one a place, the same for two positions exactly when
; their checkers stand alike.
(def pos-key
  (fn (_ p)
    (def s (str-make 50))
    (def a (str->ptr s))
    (def go (fn (self i) (when (int< i 50) (ptr-set! a i (int+ 65 (obj-ref p (int+ i 1))) 1) (self (int+ i 1)))))
    (go 0)
    s))

; --- steps -------------------------------------------------------------------

; #t when the mover has every checker in its home board, index 0 to 5.
(def %home? (fn (_ p) (int= (%sum p 7 26) 0)))

; #t when the mover's checker at FROM may move DIE pips: onto a point the
; other side holds by fewer than two, or off when every checker is home,
; by exactly the die or, from the highest point held, by less.
(def %can?
  (fn (_ p from die)
    (def to (int- from die))
    (match
      ((int< -1 to) (int< (pos-opp p (int- 23 to)) 2))
      ((%home? p) (if (int= to -1) #t (int= (%sum p (int+ from 2) 7) 0)))
      (#t #f))))

; The mover's checker at FROM moved DIE pips in P itself: the step.
(def %step!
  (fn (_ p from die)
    (def to (int- from die))
    (%me! p from (int- (pos-me p from) 1))
    (if (int< to 0) (list from to #f)
      (do
        (%me! p to (int+ (pos-me p to) 1))
        ((fn (_ o)
           (if (int= (pos-opp p o) 1)
             (do (%opp! p o 0) (%opp! p BAR (int+ (pos-opp p BAR) 1)) (list from to #t))
             (list from to #f)))
         (int- 23 to))))))

; The places a checker may start from: the bar while one is on it,
; otherwise every point held, highest first, none above BOUND.
(def %origins
  (fn (_ p bound)
    (if (int< 0 (pos-me p BAR)) (list BAR)
      ((fn (self i acc)
         (match
           ((int< bound i) (self (int- i 1) acc))
           ((int< i 0) (List reverse acc))
           ((int< 0 (pos-me p i)) (self (int- i 1) (pair i acc)))
           (#t (self (int- i 1) acc))))
       23 ()))))

; --- plays -------------------------------------------------------------------

; Every way of playing DICE in order from P, as leaves (USED STEPS . POS)
; pushed onto ACC, STEPS latest first.  With doubles a checker never
; starts above the one before it: the same steps in any other order leave
; the same position, so each is made once.
(def %leaves
  (fn (self p dice steps used bound same acc)
    (def leaf (fn (_) (pair (pair used (pair steps p)) acc)))
    (if (null? dice) (leaf)
      ((fn (_ die)
         ((fn (_ froms)
            (if (null? froms) (leaf)
              (List fold
                (fn (_ acc from)
                  (def q (pos-copy p))
                  (def s (%step! q from die))
                  (self q (rest dice) (pair s steps) (int+ used 1) (if same from 24) same acc))
                acc froms)))
          (List filter (fn (_ from) (%can? p from die)) (%origins p bound))))
       (first dice)))))

(def step-die (fn (_ s) (int- (first s) (%2nd s))))

; The leaves of LEAVES with distinct positions, the first of each, as plays.
(def %distinct
  (fn (_ leaves)
    (def seen (Dict make))
    (List reverse
      (List fold
        (fn (_ acc l)
          (def pl (rest l))
          (def k (pos-key (rest pl)))
          (if (seen has? k) acc
            (do (seen set! k #t) (pair (pair (List reverse (first pl)) (rest pl)) acc))))
        () leaves))))

; The legal plays of the roll D1 D2 from P, each leaving a different
; position.  As many dice are used as can be; when only one of two can
; be, the larger when it can.  A roll that cannot be played at all has
; one play, of no steps.
(def plays
  (fn (_ p d1 d2)
    (def same (int= d1 d2))
    (def orders (if same (list (list d1 d1 d1 d1)) (list (list d1 d2) (list d2 d1))))
    (def leaves
      (List reverse (List fold (fn (_ acc dice) (%leaves p dice () 0 24 same acc)) () orders)))
    (def most (List fold (fn (_ m l) (if (int< m (first l)) (first l) m)) 0 leaves))
    (def full (List filter (fn (_ l) (int= (first l) most)) leaves))
    (def big (if (int< d1 d2) d2 d1))
    (def bigs
      (if (if same #t (int< 1 most)) full
        (List filter (fn (_ l) (List all? (fn (_ s) (int= (step-die s) big)) (first (rest l)))) full)))
    (%distinct (if (null? bigs) full bigs))))

; --- counting ----------------------------------------------------------------

; The 21 rolls, larger die first.
(def rolls
  ((fn (self a b acc)
     (match
       ((int< 6 a) (List reverse acc))
       ((int< a b) (self (int+ a 1) 1 acc))
       (#t (self a (int+ b 1) (pair (list a b) acc)))))
   1 1 ()))

; The plays from P over N turns, each of the 21 rolls once a turn: 1 when
; N is 0 or the game is over.  It is to move generation what perft is to
; a chess engine's.
(def perft
  (fn (self p n)
    (if (if (int= n 0) #t (pos-over? p)) 1
      (List fold
        (fn (_ acc r)
          (List fold
            (fn (_ acc pl) (int+ acc (self (pos-swap (rest pl)) (int- n 1))))
            acc (plays p (first r) (%2nd r))))
        0 rolls))))

; --- text --------------------------------------------------------------------

(def %place-name
  (fn (_ i) (match ((int= i BAR) "bar") ((int< i 0) "off") (#t (io-display-to-str (int+ i 1))))))

(def %step-before?
  (fn (_ a b)
    (match
      ((int< (first b) (first a)) #t)
      ((int< (first a) (first b)) #f)
      (#t (int< (%2nd b) (%2nd a))))))

; CHAINS with step S added: onto the first chain whose checker S moves
; on, or as a chain of its own at the end.  A chain is its steps, the
; latest first.
(def %chain-on
  (fn (self chains s)
    (match
      ((null? chains) (list (list s)))
      ((if (int< -1 (%2nd (first (first chains)))) (int= (%2nd (first (first chains))) (first s)) #f)
        (pair (pair s (first chains)) (rest chains)))
      (#t (pair (first chains) (self (rest chains) s))))))

; One checker's steps, the latest first, as "24/13": the points it
; passes are named only where it hit, "24/18*/13".
(def %chain-text
  (fn (_ chain)
    (def ss (List reverse chain))
    (def last (first chain))
    (List fold
      (fn (_ t s)
        (match
          ((%3rd s) (Str8 append t "/" (%place-name (%2nd s)) "*"))
          ((same? s last) (Str8 append t "/" (%place-name (%2nd s))))
          (#t t)))
      (%place-name (first (first ss))) ss)))

; STEPS as a move is written: "24/13 13/11", the highest first, "bar" and
; "off" for the bar and the tray, "*" where a blot is hit, and "(N)" after
; a move made N times.
(def steps-text
  (fn (_ steps)
    (if (null? steps) "no move"
      ((fn (_ runs)
         (Str8 join " "
           (List map
             (fn (_ r) (if (int= (rest r) 1) (first r) (Str8 append (first r) "(" (io-display-to-str (rest r)) ")")))
             runs)))
       (List reverse
         (List fold
           (fn (_ acc t)
             (if (if (null? acc) #f (str=? (first (first acc)) t))
               (pair (pair t (int+ 1 (rest (first acc)))) (rest acc))
               (pair (pair t 1) acc)))
           ()
           (List map %chain-text
             (List fold %chain-on () (List sort %step-before? steps)))))))))

(def play-text (fn (_ pl) (steps-text (first pl))))

; --- reading a play ------------------------------------------------------------
;
; A play is read the way it is written: moves apart by spaces, each the
; places a checker goes through, "13/11", "24/18*/13", "bar/22", "6/off",
; and "(N)" after one made N times.  Points are the mover's own.  The
; moves are made on a copy of the position, a blot hit where a checker
; ends its move or where a "*" marks it on the way, and the play is the
; legal one that leaves the same position: so "24/18 18/13" and "24/13"
; are read alike, and no order of the dice need be given.

(def %blank? (fn (_ b) (if (int= b 32) #t (if (int= b 9) #t (int= b 10)))))

; The words of S apart by spaces.
(def %words
  (fn (_ s)
    (def n (str-byte-len s))
    ((fn (self i start acc)
       (match
         ((int= i n) (List reverse (if (int< start i) (pair (str-byte-sub s start (int- i start)) acc) acc)))
         ((%blank? (str-byte-ref s i))
           (self (int+ i 1) (int+ i 1) (if (int< start i) (pair (str-byte-sub s start (int- i start)) acc) acc)))
         (#t (self (int+ i 1) start acc))))
     0 0 ())))

; S cut at each byte B.
(def %cut
  (fn (_ s b)
    (def n (str-byte-len s))
    ((fn (self i start acc)
       (match
         ((int= i n) (List reverse (pair (str-byte-sub s start (int- i start)) acc)))
         ((int= (str-byte-ref s i) b) (self (int+ i 1) (int+ i 1) (pair (str-byte-sub s start (int- i start)) acc)))
         (#t (self (int+ i 1) start acc))))
     0 0 ())))

; The number S spells in decimal, or () when it is not one.
(def %number
  (fn (_ s)
    (def n (str-byte-len s))
    (if (int= n 0) ()
      ((fn (self i v)
         (if (int= i n) v
           ((fn (_ d) (if (if (int< d 0) #t (int< 9 d)) () (self (int+ i 1) (int+ (int* v 10) d))))
            (int- (str-byte-ref s i) 48))))
       0 0))))

; A place as written, "bar", "off" or a point, as (INDEX . HIT): BAR, -1
; for off, or the point's index; HIT #t for a trailing "*".  () when not
; a place.
(def %place
  (fn (_ s)
    (def n (str-byte-len s))
    (def hit (if (int< 0 n) (int= (str-byte-ref s (int- n 1)) 42) #f))
    (def w (if hit (str-byte-sub s 0 (int- n 1)) s))
    (match
      ((str=? w "bar") (pair BAR hit))
      ((str=? w "off") (pair -1 hit))
      (#t ((fn (_ v) (if (if (null? v) #t (if (int< v 1) #t (int< 24 v))) () (pair (int- v 1) hit))) (%number w))))))

; A word as (COUNT . PLACES), or ().
(def %move-word
  (fn (_ s)
    (def n (str-byte-len s))
    (def open
      ((fn (self i) (if (int< i 0) -1 (if (int= (str-byte-ref s i) 40) i (self (int- i 1))))) (int- n 1)))
    (def count
      (if (if (int< 0 open) (int= (str-byte-ref s (int- n 1)) 41) #f)
        (%number (str-byte-sub s (int+ open 1) (int- n (int+ open 2))))
        1))
    (def body (if (if (int< 0 open) (int= (str-byte-ref s (int- n 1)) 41) #f) (str-byte-sub s 0 open) s))
    (def places (List map %place (%cut body 47)))
    (if (if (null? count) #t (List any? (fn (_ x) (null? x)) places)) ()
      (if (int< (List length places) 2) () (pair count places)))))

; The other side's blot at the mover's index I sent to its bar: #f when
; it holds the point.
(def %hit!
  (fn (_ p i)
    ((fn (_ o)
       (match
         ((int= (pos-opp p o) 0) #t)
         ((int= (pos-opp p o) 1) (do (%opp! p o 0) (%opp! p BAR (int+ (pos-opp p BAR) 1)) #t))
         (#t #f)))
     (int- 23 i))))

; One checker moved through PLACES in P itself: #f when it cannot be.
(def %move!
  (fn (_ p places)
    (def from (first (first places)))
    (def to (first (List last places)))
    (def between (List init (rest places)))
    (match
      ((int< from 0) #f)
      ((int< (pos-me p from) 1) #f)
      ((int= to BAR) #f)
      ((not (List all? (fn (_ pl) (if (int< (first pl) 0) #f (if (int= (first pl) BAR) #f (if (rest pl) (%hit! p (first pl)) #t)))) between)) #f)
      ((int< to 0) (do (%me! p from (int- (pos-me p from) 1)) #t))
      ((not (%hit! p to)) #f)
      (#t (do (%me! p from (int- (pos-me p from) 1)) (%me! p to (int+ (pos-me p to) 1)) #t)))))

; The legal play of D1 D2 from P that TEXT writes, or a string saying
; why there is none.
(def play-find
  (fn (_ p d1 d2 text)
    (def ps (plays p d1 d2))
    (def words (%words text))
    (def moves (List map %move-word words))
    (match
      ((if (null? words) #t (if (int= (List length words) 2) (if (str=? (first words) "no") (str=? (%2nd words) "move") #f) #f))
        (if (null? (first (first ps))) (first ps) "there is a move to play"))
      ((List any? (fn (_ x) (null? x)) moves) "a move is written 24/18, 13/11(2), bar/22, 6/off or 24/18*/13")
      (#t
        ((fn (_ q)
           (if (not (List all? (fn (_ m) (List all? (fn (_ k) (%move! q (rest m))) (List range 0 (first m)))) moves))
             "those checkers cannot move that way"
             ((fn (_ k)
                ((fn (_ found) (if (null? found) "that is not a legal play of the roll" found))
                 (List find (fn (_ pl) (str=? (pos-key (rest pl)) k)) ps)))
              (pos-key q))))
         (pos-copy p))))))

(provide backgammon/board
  BAR CHECKERS WHITE BLACK
  pos-me pos-opp pos-turn pos-copy pos-make pos-start pos-swap
  pos-me-off pos-opp-off pos-me-pips pos-opp-pips pos-over? pos-key
  step-die plays rolls perft steps-text play-text play-find)
