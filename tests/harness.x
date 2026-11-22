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
(import x/type/vector)
(import x/num/random)
(import backgammon/board BAR CHECKERS WHITE BLACK pos-me pos-opp pos-turn pos-make pos-start
  pos-swap pos-me-off pos-opp-off pos-me-pips pos-opp-pips pos-over? plays rolls perft play-text play-find)
(import backgammon/show board-lines board-text)
(import backgammon/eval evaluate eval-contact? eval-ranked eval-best)
(import backgammon/game game-new game-pos game-dice game-result game-over? game-turn game-play! game-undo! game-plays)
(import backgammon/play play-run)

; The texts of the plays of D1 D2 from P, in the order made.
(def spec-plays (fn (_ p d1 d2) (List map play-text (plays p d1 d2))))

; How many plays D1 D2 has from P.
(def spec-count (fn (_ p d1 d2) (List length (plays p d1 d2))))

; What play-find makes of TEXT: the play's text, or why there is none.
(def spec-find
  (fn (_ p d1 d2 text) ((fn (_ r) (if (str? r) r (play-text r))) (play-find p d1 d2 text))))

; The engine's play of D1 D2 from P, as text.
(def spec-best (fn (_ p d1 d2) (play-text (eval-best p d1 d2))))

; A session fed LINES, its dice from SEED, the people playing HUMAN:
; (STATUS . OUTPUT), the output the session wrote, prompts and all.
(def spec-session
  (fn (_ lines seed human)
    (def in (Vector of lines))
    (def out (Vector of ()))
    (def io
      (list (fn (_ prompt)
              (Vector set! 0 (pair prompt (Vector ref 0 out)) out)
              ((fn (_ ls) (if (null? ls) () (do (Vector set! 0 (rest ls) in) (first ls)))) (Vector ref 0 in)))
            (fn (_ text) (Vector set! 0 (pair text (Vector ref 0 out)) out))))
    ((fn (_ status) (pair status (Str8 join "" (List reverse (Vector ref 0 out)))))
     (play-run io (Random sw seed) human))))

; #t when NEEDLE is in TEXT.
(def spec-has? (fn (_ needle text) (not (null? (Str8 index-of needle text)))))
