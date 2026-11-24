; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/eval.x -- a hand-written evaluation, and the play it picks
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A position is scored for the side that has just played, with the other
; side to roll: a larger score is better for the side that played.  The
; score is in pips, so a race is the pip counts' difference and the rest
; are pips' worth of position.
;
; The engine looks one play ahead: of a roll's plays it picks the one
; whose position scores highest.

(module backgammon/eval)

(import backgammon/board BAR pos-me pos-opp pos-me-pips pos-opp-pips plays)
(import backgammon/bearoff BEAROFF-ROLL bearoff-table bearoff-max bearoff-rank bearoff-mean)
(import x/core/doors int+ int- int* int/ int< int=)

; The other side's index J, as a place on this side's board: K = 23 - J,
; and its bar, -1, behind every point.
(def %opp-at (fn (_ p k) (if (int< k 0) (pos-opp p BAR) (pos-opp p (int- 23 k)))))

; The highest index this side has a checker on, or -1.
(def %my-back
  (fn (_ p) ((fn (self i) (if (int< i 0) -1 (if (int< 0 (pos-me p i)) i (self (int- i 1))))) 24)))

; The lowest place on this side's board the other side has a checker
; on, -1 for its bar, or 24 when it has none left.
(def %opp-back
  (fn (_ p) ((fn (self k) (if (int< 23 k) 24 (if (int< 0 (%opp-at p k)) k (self (int+ k 1))))) -1)))

; #t while the sides have checkers still to pass each other.
(def eval-contact? (fn (_ p) (int< (%opp-back p) (%my-back p))))

; How many of the 36 rolls hit a blot at index I from the other side's
; checkers behind it: a die, the two dice together, or three or four of
; a double, counting no point in between as blocked.
(def %shots
  (fn (_ p i)
    (def near?
      (fn (_ d) (if (int< d 1) #f (if (int< (int- i d) -1) #f (int< 0 (%opp-at p (int- i d)))))))
    (def hits?
      (fn (_ a b)
        (match
          ((near? a) #t)
          ((near? b) #t)
          ((near? (int+ a b)) #t)
          ((int= a b) (if (near? (int* 3 a)) #t (near? (int* 4 a))))
          (#t #f))))
    ((fn (self a b n)
       (match
         ((int< 6 a) n)
         ((int< 6 b) (self (int+ a 1) 1 n))
         (#t (self a (int+ b 1) (if (hits? a b) (int+ n 1) n)))))
     1 1 0)))

; What a made point is worth at index I, on this side's board.
(def %point-worth
  (fn (_ i)
    (match
      ((int< i 6) (List ref i (list 3 5 7 9 12 11)))
      ((int= i 6) 9)
      ((int= i 7) 6)
      ((int< i 18) 2)
      ((int= i 19) 5)
      ((int= i 20) 6)
      (#t 3))))

; The made points of the side whose counts COUNT reads, and the longest
; run of them, as (WORTH . RUN).
(def %points
  (fn (_ count)
    ((fn (self i worth run best)
       (if (int< 23 i) (pair worth (if (int< best run) run best))
         (if (int< 1 (count i))
           (self (int+ i 1) (int+ worth (%point-worth i)) (int+ run 1) best)
           (self (int+ i 1) worth 0 (if (int< best run) run best)))))
     0 0 0 0)))

; The risk to this side's blots: each blot's shots over 36 times the
; pips a hit costs, which is its distance from the bar and some.
(def %risk
  (fn (_ p)
    ((fn (self i n)
       (if (int< 23 i) n
         (self (int+ i 1)
           (if (int= (pos-me p i) 1)
             (int+ n (int/ (int* (%shots p i) (int+ (int- 24 i) 8)) 36))
             n))))
     0 0)))

; The home board points this side holds, out of six.
(def %home-made
  (fn (_ count) ((fn (self i n) (if (int< 5 i) n (self (int+ i 1) (if (int< 1 (count i)) (int+ n 1) n)))) 0 0)))

(def %total (fn (_ ns) (List fold (fn (_ a b) (int+ a b)) 0 ns)))

; --- the race ------------------------------------------------------------------------

; The race is counted in 1/64 pips.  A side with only its home board left
; counts its rolls to come from the bear-off table (backgammon/bearoff)
; at 49/6 pips a roll, the pips an average roll moves; a side with
; checkers further out, or with no table on this machine, counts its pips.
(def %fine 64)

; The checkers on the side's home board that COUNT reads, or -1 when it
; has one further out.
(def %home
  (fn (_ count)
    ((fn (self i n) (if (int< i 0) n (if (int< i 6) (self (int- i 1) (int+ n (count i))) (if (int< 0 (count i)) -1 (self (int- i 1) n)))))
     BAR 0)))

; The side's race in 1/64 pips: COUNT reads its checkers, PIPS its pips.
(def %race-of
  (fn (_ count pips)
    ((fn (_ t n)
       (if (if (null? t) #t (if (int< n 0) #t (int< (bearoff-max t) n))) (int* pips %fine)
         (int/ (int* (bearoff-mean t (bearoff-rank t count)) 49) (int/ (int* 6 BEAROFF-ROLL) %fine))))
     (bearoff-table) (%home count))))

; P's race in 1/64 pips for the side that has just played.
(def %race
  (fn (_ p)
    (int- (%race-of (fn (_ j) (pos-opp p j)) (pos-opp-pips p))
          (%race-of (fn (_ i) (pos-me p i)) (pos-me-pips p)))))

; P's score for the side that has just played, in its parts, as
; ((NAME . PIPS) ...): race the pip counts' difference; points the made
; points' worth against the other side's; prime the longest runs of made
; points; hit the other side's checkers on the bar; bar this side's on
; the bar; risk the shots at this side's blots.  Out of contact there is
; only the race, a bear-off's counted from the table.
(def eval-parts
  (fn (_ p)
    (def race (int- (pos-opp-pips p) (pos-me-pips p)))
    (if (not (eval-contact? p)) (list (pair (lit race) (int/ (%race p) %fine)))
      ((fn (_ mine theirs)
         (list (pair (lit race) race)
               (pair (lit points) (int- (first mine) (first theirs)))
               (pair (lit prime) (int* 3 (int- (int* (rest mine) (rest mine)) (int* (rest theirs) (rest theirs)))))
               (pair (lit hit) (int* (pos-opp p BAR) (int+ 6 (int* 3 (%home-made (fn (_ i) (pos-me p i)))))))
               (pair (lit bar) (int- 0 (int* (pos-me p BAR) (int+ 6 (int* 3 (%home-made (fn (_ j) (pos-opp p j))))))))
               (pair (lit risk) (int- 0 (%risk p)))))
       (%points (fn (_ i) (pos-me p i)))
       (%points (fn (_ j) (pos-opp p j)))))))

; P scored for the side that has just played: its parts' sum.
(def evaluate (fn (_ p) (%total (List map rest (eval-parts p)))))

; P's score in 1/64 pips, what plays are ranked by: in contact its
; score, out of contact its race, a bear-off's rolls told apart to a
; fraction of a pip.
(def eval-fine
  (fn (_ p) (if (eval-contact? p) (int* (evaluate p) %fine) (%race p))))

; The plays of D1 D2 from P, each as (SCORE . PLAY), the best first by
; eval-fine.
(def eval-ranked
  (fn (_ p d1 d2)
    (List map rest
      (List sort (fn (_ a b) (int< (first b) (first a)))
        (List map (fn (_ pl) (pair (eval-fine (rest pl)) (pair (evaluate (rest pl)) pl))) (plays p d1 d2))))))

; The play the engine picks for D1 D2 from P.
(def eval-best (fn (_ p d1 d2) (rest (first (eval-ranked p d1 d2)))))

(provide backgammon/eval evaluate eval-parts eval-fine eval-contact? eval-ranked eval-best)
