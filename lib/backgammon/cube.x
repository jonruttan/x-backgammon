; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/cube.x -- the engine's cube: when it doubles, when it takes
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The engine handles the cube in a race, where the sides have passed
; each other, and leaves it alone while they still meet: in contact it
; never doubles and always takes.
;
; When both sides have only their home boards left and the bear-off
; table (backgammon/bearoff) holds them, the chance the side to roll
; wins is known: it doubles from 68%, or from just over even when the
; other side is sure to be off in its next roll, and a double is taken
; while the taker keeps 22%, 25% when the doubler is sure to be off.
;
; A longer race is judged by the Keith count: each side's pips, and 2
; for each checker past the first on its 1-point, 1 for each past the
; first on its 2-point, 1 for each past the third on its 3-point, and 1
; for each of its 4-, 5- and 6-points empty.  The side to roll adds a
; seventh to its count.  It doubles when that exceeds the other's count
; by 4 or less, redoubles by 3 or less, and a double is taken when it
; exceeds the other's by 2 or more.

(module backgammon/cube)

(import backgammon/board pos-me pos-opp pos-me-pips pos-opp-pips)
(import backgammon/eval eval-contact? eval-home)
(import backgammon/bearoff BEAROFF-ONE bearoff-table bearoff-max bearoff-rank bearoff-win bearoff-chance)
(import backgammon/game game-pos game-turn game-owner)
(import x/core/doors int+ int- int* int/ int< int=)

; The checkers past N on a point holding C.
(def %past (fn (_ c n) (if (int< n c) (int- c n) 0)))

; The Keith count of the side COUNT reads, PIPS its pips.
(def %keith
  (fn (_ count pips)
    (int+ pips
      (int+ (int* 2 (%past (count 0) 1))
        (int+ (%past (count 1) 1)
          (int+ (%past (count 2) 3)
            (int+ (if (int= (count 3) 0) 1 0) (int+ (if (int= (count 4) 0) 1 0) (if (int= (count 5) 0) 1 0)))))))))

; Eight times the side to roll's count, a seventh added, less seven
; times the other's: 7 times by how much the first exceeds the second.
(def %keith-lead
  (fn (_ p)
    (int- (int* 8 (%keith (fn (_ i) (pos-me p i)) (pos-me-pips p)))
          (int* 7 (%keith (fn (_ j) (pos-opp p j)) (pos-opp-pips p))))))

; The table, when it holds both sides of P: both home, neither with more
; checkers than it was solved for.  () otherwise.
(def %table-for
  (fn (_ p)
    ((fn (_ t mine theirs)
       (if (null? t) ()
         (if (if (int< mine 0) #t (if (int< theirs 0) #t (if (int< (bearoff-max t) mine) #t (int< (bearoff-max t) theirs)))) ()
           t)))
     (bearoff-table) (eval-home (fn (_ i) (pos-me p i))) (eval-home (fn (_ j) (pos-opp p j))))))

(def %rank-me (fn (_ t p) (bearoff-rank t (fn (_ i) (pos-me p i)))))
(def %rank-opp (fn (_ t p) (bearoff-rank t (fn (_ j) (pos-opp p j)))))

; #t when the side COUNT reads is sure to be off in its next roll.
(def %sure? (fn (_ t r) (int= (bearoff-chance t r 1) BEAROFF-ONE)))

; Whether the side to move in G, still to roll, doubles.
(def cube-double?
  (fn (_ g)
    (def p (game-pos g))
    (def t (%table-for p))
    (match
      ((eval-contact? p) #f)
      ((null? t)
        (not (int< (if (null? (game-owner g)) 28 21) (%keith-lead p))))
      (#t ((fn (_ win last)
             (if last (int< (int/ BEAROFF-ONE 2) win) (not (int< win (int/ (int* 68 BEAROFF-ONE) 100)))))
           (bearoff-win t (%rank-me t p) (%rank-opp t p)) (%sure? t (%rank-opp t p)))))))

; Whether the other side takes the double of the side to move in G.
(def cube-take?
  (fn (_ g)
    (def p (game-pos g))
    (def t (%table-for p))
    (match
      ((eval-contact? p) #t)
      ((null? t) (not (int< (%keith-lead p) 14)))
      (#t ((fn (_ keep sure)
             (not (int< keep (int/ (int* (if sure 25 22) BEAROFF-ONE) 100))))
           (int- BEAROFF-ONE (bearoff-win t (%rank-me t p) (%rank-opp t p))) (%sure? t (%rank-me t p)))))))

(provide backgammon/cube cube-double? cube-take?)
