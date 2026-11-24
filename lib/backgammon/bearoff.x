; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/bearoff.x -- the bear-off, solved
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Every way of setting up to N checkers on the six home points, each with
; the chances of bearing them all off in exactly 0, 1, 2 ... rolls, the
; play of each roll taken that leaves the fewest rolls to come.  One side
; is counted alone, as if the other were not there: once both sides have
; only their home boards left, nothing one does touches the other, and
; the side to roll wins when it is off in fewer rolls than the other.
;
; A table is built from the smallest pip count up, since every play
; leaves fewer pips: for each die and each of one, two and three steps
; of it, the position played to that leaves the fewest rolls is kept,
; so a roll's best play is a few lookups, a double's four steps among
; them.
;
; A position is a key, four bits a point from the 1-point up, and is
; ranked among the table's positions by the ways skipped past.  Chances
; are counted in units of 1/1048576, rolls in units of 1/4096.  The
; build runs on the engine's doors: 54,264 positions with 21 rolls each.

(module backgammon/bearoff)

(import x/type/vector)
(import x/sys/file)
(import x/sys/posix)
(import x/sys/gc)
(import x/core/doors int+ int- int* int/ int< int= int& int<< int>> obj-ref obj-set! str-make str->ptr ptr-set! str-byte-ref str-byte-len str-byte-sub heap-collect)

(def BEAROFF-ONE 1048576)  ; a certainty
(def BEAROFF-ROLL 4096)    ; one roll
(def %kept 32)             ; the rolls a distribution reaches

; Slot I of the vector V, read and written.
(def %at (fn (_ v i) (obj-ref v (int+ i 1))))
(def %put! (fn (_ v i x) (obj-set! v (int+ i 1) x)))

; The checkers KEY holds on point index I (0 the 1-point).
(def %count (fn (_ key i) (int& (int>> key (int* 4 i)) 15)))

; The ways of setting up to M checkers on J points: C(M + J, J).
(def %ways
  (fn (_ j m) ((fn (self k acc) (if (int< j k) acc (self (int+ k 1) (int/ (int* acc (int+ m k)) k)))) 1 1)))

; A table's fields.
(def %t-max 0)    ; N, the most checkers
(def %t-size 1)   ; how many positions
(def %t-skip 2)   ; (point, checkers left, count) -> ways skipped past
(def %t-bytes 3)  ; the entries, packed
(def %t-offsets 4) ; where each rank's entry starts

; The rank steps for N checkers: the ways skipped past by C checkers on
; point J with R checkers still to place, the points above J placed.
(def %skips
  (fn (_ n)
    (def v (Vector make (int* 6 256) 0))
    ((fn (self j r c acc)
       (match
         ((int< 5 j) v)
         ((int< n r) (self (int+ j 1) 0 0 0))
         ((int< r c) (self j (int+ r 1) 0 0))
         (#t (do (%put! v (int+ (int* j 256) (int+ (int* r 16) c)) acc)
                 (self j r (int+ c 1) (int+ acc (%ways j (int- r c))))))))
     0 0 0 0)))

(def %rank
  (fn (_ skip n key)
    ((fn (self j r acc)
       (if (int< j 0) acc
         ((fn (_ c) (self (int- j 1) (int- r c) (int+ acc (%at skip (int+ (int* j 256) (int+ (int* r 16) c))))))
          (%count key j))))
     5 n 0)))

; The rank in table T of the position whose point index I holds (COUNT I)
; checkers.
(def bearoff-rank
  (fn (_ t count)
    ((fn (self i key) (if (int< 5 i) (%rank (%at t %t-skip) (%at t %t-max) key) (self (int+ i 1) (int+ key (int<< (count i) (int* 4 i))))))
     0 0)))

; Every key with up to N checkers, with each pip count's keys apart:
; a vector by pips of lists of keys.
(def %by-pips
  (fn (_ n)
    (def v (Vector make (int+ (int* 6 n) 1) ()))
    ((fn (self j left key pips)
       (if (int< j 0) (%put! v pips (pair key (%at v pips)))
         ((fn (loop c)
            (if (int< left c) ()
              (do (self (int- j 1) (int- left c) (int+ key (int<< c (int* 4 j))) (int+ pips (int* c (int+ j 1))))
                  (loop (int+ c 1)))))
          0)))
     5 n 0 0)
    v))

(def %member? (fn (self x l) (if (null? l) #f (if (int= x (first l)) #t (self x (rest l))))))

; The ranks one step of die D from KEY: a checker moved down D points,
; or borne off from point D, or from below D when no checker is above it.
(def %steps
  (fn (_ skip n key d)
    (def top ((fn (self i) (if (int< i 0) -1 (if (int< 0 (%count key i)) i (self (int- i 1))))) 5))
    ((fn (self i acc)
       (if (int< 5 i) acc
         (self (int+ i 1)
           (if (if (int< 0 (%count key i)) (if (int< i (int- d 1)) (int= i top) #t) #f)
             ((fn (_ r) (if (%member? r acc) acc (pair r acc)))
              (%rank skip n (int+ (int- key (int<< 1 (int* 4 i))) (if (int< i d) 0 (int<< 1 (int* 4 (int- i d)))))))
             acc))))
     0 ())))

; Of AFTER's entries for the ranks RS, the one with the fewest rolls.
(def %fewest
  (fn (_ mean after rs)
    ((fn (self best l)
       (if (null? l) best
         ((fn (_ x) (self (if (int< (%at mean x) (%at mean best)) x best) (rest l))) (%at after (first l)))))
     (%at after (first rs)) (rest rs))))

(def %fewer (fn (_ mean a b) (if (int< (%at mean b) (%at mean a)) b a)))

; Rank R's rolls to come and their chances, from each roll's best end:
; ONES holds each die's steps from R, (AFTER D K) each rank's best after
; K steps of D.
(def %last (int- %kept 1))
(def %cap (fn (_ k) (match ((int< %last k) %last) (#t k))))

(def %rolls!
  (fn (_ mean dist after ones r)
    (def sum (Vector make %kept 0))
    ; The first and last rolls summed, and the rolls to come summed.
    (def span (Vector make 3 0))
    (%put! span 0 %kept)
    (%put! span 1 -1)
    ; End E of a roll with W chances in 36: its rolls, one more, added in.
    ; A distribution is its first roll, then each roll's chance from it.
    (def add!
      (fn (_ w e)
        (def d (obj-ref dist (int+ e 1)))
        (def lo (obj-ref d 1))
        (def n (int- (obj-ref d 0) 1))
        (def step
          (fn (_ j)
            ((fn (_ at) (obj-set! sum at (int+ (obj-ref sum at) (int* w (obj-ref d (int+ j 2))))))
             (int+ (%cap (int+ lo (int+ j 1))) 1))
            (int+ j 1)))
        ((fn (self j) (match ((int< j n) (self (step j))) (#t ()))) 0)
        (match ((int< (int+ lo 1) (obj-ref span 1)) (obj-set! span 1 (int+ lo 1))) (#t ()))
        (match ((int< (obj-ref span 2) (%cap (int+ lo n))) (obj-set! span 2 (%cap (int+ lo n)))) (#t ()))
        (obj-set! span 3 (int+ (obj-ref span 3) (int* w (obj-ref mean (int+ e 1)))))))
    ((fn (self a b)
       (match
         ((int< 6 a) ())
         ((int< 6 b) (self (int+ a 1) (int+ a 1)))
         ((int= a b) (do (add! 1 (%fewest mean (after a 3) (%at ones (int- a 1)))) (self a (int+ b 1))))
         (#t (do (add! 2 (%fewer mean (%fewest mean (after b 1) (%at ones (int- a 1)))
                                      (%fewest mean (after a 1) (%at ones (int- b 1)))))
                 (self a (int+ b 1))))))
     1 1)
    ((fn (_ lo hi)
       (def v (Vector make (int+ (int- hi lo) 2) 0))
       (%put! v 0 lo)
       (def step (fn (_ k) (%put! v (int+ (int- k lo) 1) (int/ (%at sum k) 36)) (int+ k 1)))
       ((fn (self k) (match ((int< hi k) ()) (#t (self (step k))))) lo)
       (%put! dist r v))
     (%at span 0) (%at span 1))
    (%put! mean r (int+ BEAROFF-ROLL (int/ (%at span 2) 36)))))

; The table for up to N checkers solved: (MEAN . DIST), by rank.
(def %solve
  (fn (_ n)
    (def size (%ways 6 n))
    (def skip (%skips n))
    (def mean (Vector make size 0))
    (def dist (Vector make size ()))
    ; (after D K): each rank's best after K steps of die D.
    (def afters (Vector make 24 ()))
    ((fn (self k) (if (int< k 24) (do (%put! afters k (Vector make size 0)) (self (int+ k 1))) ())) 0)
    (def after (fn (_ d k) (%at afters (int+ (int* 4 (int- d 1)) k))))
    (def ones (Vector make 6 ()))
    (def solve!
      (fn (_ key)
        (def r (%rank skip n key))
        ; The steps of each die, and the best after one, two, three of them.
        ((fn (self d)
           (if (int< 6 d) ()
             (do ((fn (_ one)
                    (%put! ones (int- d 1) one)
                    (%put! (after d 0) r r)
                    ((fn (more k) (if (int< 3 k) ()
                                    (do (%put! (after d k) r (if (null? one) r (%fewest mean (after d (int- k 1)) one)))
                                        (more (int+ k 1)))))
                     1))
                  (if (int= key 0) () (%steps skip n key d)))
                 (self (int+ d 1)))))
         1)
        (if (int= key 0)
          (do (%put! mean r 0)
              (%put! dist r (Vector of 0 BEAROFF-ONE)))
          (%rolls! mean dist after ones r))))
    (def keys (%by-pips n))
    ; Each pip count's positions in turn, the garbage collected every 256.
    (def done (Vector make 1 0))
    (def solved!
      (fn (_ key)
        (solve! key)
        (obj-set! done 1 (int+ (obj-ref done 1) 1))
        (match ((int= 0 (int& (obj-ref done 1) 255)) (heap-collect)) (#t ()))))
    ((fn (self p)
       (if (int< (int* 6 n) p) ()
         (do ((fn (each l) (if (null? l) () (do (solved! (first l)) (each (rest l))))) (%at keys p))
             (self (int+ p 1)))))
     0)
    (heap-collect)
    (pair mean dist)))

; --- the table packed ---------------------------------------------------------------
;
; A solved table is kept as bytes, each rank's entry its rolls to come
; (three bytes), its first roll and how many rolls have chances (a byte
; each), then those chances (three bytes each); and where each rank's
; entry starts.  A file holds "XBO1", N, then the entries.  Each byte
; carries seven bits, low first, with its top bit set: no byte is NUL,
; so the table is a string every string door reads to its end.

(def %magic "XBO1")

(def %byte (fn (_ s i) (int& (str-byte-ref s i) 127)))
(def %u21 (fn (_ s i) (int+ (%byte s i) (int+ (int<< (%byte s (int+ i 1)) 7) (int<< (%byte s (int+ i 2)) 14)))))

(def %put-byte! (fn (_ a i x) (ptr-set! a i (int+ 128 (int& x 127)) 1)))
(def %put-u21!
  (fn (_ a i x)
    (%put-byte! a i x)
    (%put-byte! a (int+ i 1) (int>> x 7))
    (%put-byte! a (int+ i 2) (int>> x 14))))
; Where each of SIZE entries starts in the bytes S, from byte AT.
(def %offsets
  (fn (_ s at size)
    (def v (Vector make size 0))
    ((fn (self r i) (match ((int< r size) (do (%put! v r i) (self (int+ r 1) (int+ i (int+ 5 (int* 3 (%byte s (int+ i 4)))))))) (#t v)))
     0 at)))

(def %table (fn (_ n s at) ((fn (_ size) (Vector of n size (%skips n) s (%offsets s at size))) (%ways 6 n))))

; The table for up to N checkers, solved and packed.
(def bearoff-make
  (fn (_ n)
    (def solved (%solve n))
    (def mean (first solved))
    (def dist (rest solved))
    (def size (%ways 6 n))
    (def bytes
      ((fn (self r acc) (if (int< r size) (self (int+ r 1) (int+ acc (int+ 5 (int* 3 (int- (obj-ref (%at dist r) 0) 1))))) acc))
       0 5))
    (def s (str-make bytes))
    (def a (str->ptr s))
    ((fn (self i) (if (int< i 4) (do (ptr-set! a i (str-byte-ref %magic i) 1) (self (int+ i 1))) ())) 0)
    (%put-byte! a 4 n)
    ((fn (self r i)
       (if (int< r size)
         ((fn (_ d)
            (def k (int- (obj-ref d 0) 1))
            (%put-u21! a i (%at mean r))
            (%put-byte! a (int+ i 3) (%at d 0))
            (%put-byte! a (int+ i 4) k)
            ((fn (each j) (if (int< j k) (do (%put-u21! a (int+ i (int+ 5 (int* 3 j))) (%at d (int+ j 1))) (each (int+ j 1))) ())) 0)
            (match ((int= 0 (int& r 1023)) (heap-collect)) (#t ()))
            (self (int+ r 1) (int+ i (int+ 5 (int* 3 k)))))
          (%at dist r))
         ()))
     0 5)
    (%table n s 5)))

(def bearoff-size (fn (_ t) (%at t %t-size)))
(def bearoff-max (fn (_ t) (%at t %t-max)))

(def %entry (fn (_ t r) (%at (%at t %t-offsets) r)))

; The rolls to come, in BEAROFF-ROLL units, of the position ranked R.
(def bearoff-mean (fn (_ t r) (%u21 (%at t %t-bytes) (%entry t r))))

; The chance, in BEAROFF-ONE units, of bearing off the position ranked R
; in exactly K rolls.
(def bearoff-chance
  (fn (_ t r k)
    (def s (%at t %t-bytes))
    (def i (%entry t r))
    ((fn (_ j) (match ((int< j 0) 0) ((int< j (%byte s (int+ i 4))) (%u21 s (int+ i (int+ 5 (int* 3 j))))) (#t 0)))
     (int- k (%byte s (int+ i 3))))))

; The chance, in BEAROFF-ONE units, that the side to roll from rank ME
; is off before the other side from rank THEM: off in K rolls while the
; other is not off in K - 1.
(def bearoff-win
  (fn (_ t me them)
    ((fn (self k left acc)
       (if (int< %last k) acc
         ((fn (_ left) (self (int+ k 1) left (int+ acc (int/ (int* (bearoff-chance t me k) (int/ left 1024)) 1024))))
          (if (int= k 0) left (int- left (bearoff-chance t them (int- k 1)))))))
     0 BEAROFF-ONE 0)))

; T written to the file PATH, and the table a file holds: () when it
; cannot be read or is not a table.
(def bearoff-write!
  (fn (_ t path)
    (def s (%at t %t-bytes))
    (def fd (File open path (list (lit wronly) (lit creat) (lit trunc)) 420))
    (when (int< fd 0) (Err raise (lit io) (Str8 append "cannot write " path) ()))
    (File write fd s (str-byte-len s))
    (File close fd)))

(def bearoff-read
  (fn (_ path)
    (guard (e ())
      ((fn (_ s)
         (if (if (int< 5 (str-byte-len s)) (str=? (str-byte-sub s 0 4) %magic) #f)
           (%table (%byte s 4) s 5)
           ()))
       (File read-all path)))))

; --- the table this machine has ------------------------------------------------------
;
; Solved once on a machine and kept in its cache, $XDG_CACHE_HOME or
; ~/.cache, under x-backgammon/: a minute's work where the engine can
; compile the build, much longer where it cannot.

(def BEAROFF-CHECKERS 15)

(def %current (Vector make 3 ()))  ; the table in use; whether the file was looked for; whether it was set

(def bearoff-path
  (fn (_)
    (def xdg (Sys getenv "XDG_CACHE_HOME"))
    (Str8 append (if (if (str? xdg) (int< 0 (str-byte-len xdg)) #f) xdg (Str8 append (Sys getenv "HOME") "/.cache"))
      "/x-backgammon/bearoff-15.xbo")))

; The table in use: the one set, or the machine's, read once; () when
; the bear-off has not been solved on this machine.
(def bearoff-table
  (fn (_)
    (when (null? (%at %current 1))
      (do (%put! %current 1 #t)
          (when (null? (%at %current 0)) (%put! %current 0 (bearoff-read (bearoff-path))))))
    (%at %current 0)))

; T put in use, () to go without one: either way no solve is due.
(def bearoff-use! (fn (_ t) (%put! %current 0 t) (%put! %current 1 #t) (%put! %current 2 #t) t))

; #t when this machine has no table and none was set.
(def bearoff-due? (fn (_) (if (null? (bearoff-table)) (null? (%at %current 2)) #f)))

; The build's loops compiled, where the engine can: each stays as written
; where it cannot.
(def %compile!
  (fn (_)
    (guard (e (list (lit refused) e))
      (import x/tool/fn-compile compile-fn!)
      (def one (fn (_ name) (guard (e (pair name e)) (pair name ((compile-fn! name (eval name (module backgammon/bearoff))) (lit state))))))
      (def made
        (list (one (lit %at)) (one (lit %put!)) (one (lit %count)) (one (lit %cap)) (one (lit %ways))
              (one (lit %rank)) (one (lit %member?)) (one (lit %steps)) (one (lit %fewest)) (one (lit %fewer))
              (one (lit %rolls!))))
      (Heap collect)
      made)))

; The directory DIR made, and each directory above it that is missing.
(def %mkdirs!
  (fn (_ dir)
    ((fn (self i)
       (when (int< i (str-byte-len dir))
         (do (when (if (int= (str-byte-ref dir i) 47) (int< 0 i) #f) (guard (e ()) (File mkdir (str-byte-sub dir 0 i))))
             (self (int+ i 1)))))
     0)
    (guard (e ()) (File mkdir dir))))

; The bear-off solved for this machine, kept in its cache, and put in use.
(def bearoff-solve!
  (fn (_)
    (%compile!)
    (def t (bearoff-make BEAROFF-CHECKERS))
    (guard (e ())
      ((fn (_ path)
         (%mkdirs! (Str8 sub 0 (int- (str-byte-len path) (str-byte-len "/bearoff-15.xbo")) path))
         (bearoff-write! t path))
       (bearoff-path)))
    (Heap collect)
    (bearoff-use! t)))

(provide backgammon/bearoff
  BEAROFF-ONE BEAROFF-ROLL BEAROFF-CHECKERS bearoff-make bearoff-rank bearoff-size bearoff-max bearoff-mean bearoff-chance bearoff-win
  bearoff-write! bearoff-read bearoff-path bearoff-table bearoff-use! bearoff-due? bearoff-solve!)
