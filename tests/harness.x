; # x-backgammon -- backgammon on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The bundle kit's generator writes tests/lib/harness.gen.x: the dialect
; bundle.xon declares, the bundle's lib/ on the import path, then this
; file.  Nothing is read at load.
(import backgammon/board BAR CHECKERS WHITE BLACK pos-me pos-opp pos-turn pos-make pos-start
  pos-swap pos-me-off pos-opp-off pos-me-pips pos-opp-pips pos-over? plays rolls perft play-text)
(import backgammon/show board-lines board-text)

; The texts of the plays of D1 D2 from P, in the order made.
(def spec-plays (fn (_ p d1 d2) (List map play-text (plays p d1 d2))))

; How many plays D1 D2 has from P.
(def spec-count (fn (_ p d1 d2) (List length (plays p d1 d2))))
