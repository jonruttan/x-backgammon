; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/coach.x -- a play judged against the engine's
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; After a play the coach says whether the engine would have made it, and
; when it would not, the play it prefers, by how many pips, and why: the
; part of the evaluation (backgammon/eval's eval-parts) where the two
; plays differ most.

(module backgammon/coach)

(import backgammon/board pos-key play-text)
(import backgammon/eval eval-ranked eval-parts eval-fine)
(import x/core/doors int- int< io-display-to-str)

; Why a play better by DIFF in the part NAME is better.
(def %why
  (fn (_ name)
    (match
      ((eq? name (lit points)) "it makes a better point")
      ((eq? name (lit prime)) "it builds a longer prime")
      ((eq? name (lit hit)) "it puts a checker on the bar")
      ((eq? name (lit bar)) "it leaves fewer of yours on the bar")
      ((eq? name (lit risk)) "it leaves fewer shots at your blots")
      (#t "it gains more in the race"))))

; The part of the evaluation where BEST's position beats PLAYED's most.
(def %reason
  (fn (_ best played)
    (first
      (List fold (fn (_ acc x) (if (int< (rest acc) (rest x)) x acc))
        (pair (lit race) -1000000)
        (List map (fn (_ b) (pair (first b) (int- (rest b) (rest (List find (fn (_ x) (eq? (first x) (first b))) played)))))
          best)))))

; What the coach says of PLAY made from P with D1 D2: (LOSS . TEXT),
; LOSS the pips the engine's play scores above it, 0 when it is the
; engine's play or one as good, and "a little better" when the engine's
; is ahead by less than a pip.  () when the roll has one play.
(def coach-judge
  (fn (_ p d1 d2 play)
    (def ranked (eval-ranked p d1 d2))
    (def key (pos-key (rest play)))
    (def mine (List find (fn (_ r) (str=? (pos-key (rest (rest r))) key)) ranked))
    (if (if (null? (rest ranked)) #t (null? mine)) ()
      ((fn (_ best loss)
         (if (not (int< (eval-fine (rest play)) (eval-fine (rest (rest best))))) (pair 0 "Coach: the engine plays that too.")
           (pair loss
             (Str8 append "Coach: " (play-text (rest best))
               (if (int< loss 1) " is a little better: " (Str8 append " is better by " (io-display-to-str loss) ": "))
               (%why (%reason (eval-parts (rest (rest best))) (eval-parts (rest play)))) "."))))
       (first ranked) (int- (first (first ranked)) (first mine))))))

(provide backgammon/coach coach-judge)
