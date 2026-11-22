; # x-backgammon -- backgammon on x-lang
;
; ## lib/backgammon/run.x -- the entry
;
; @description `x -l backgammon -- [OPTIONS]`.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module backgammon/run)
(import backgammon/cli backgammon-main)

(set! %lang-name "backgammon")
(set! %repl-prompt "backgammon> ")

; The operands: what follows the "--" after the launcher's own options.
; A launcher that passes the engine's own flags ahead of them, with no
; "--" between, has them left out.
(def %engine-flag?
  (fn (_ a) (List any? (fn (_ f) (str=? a f)) (list "--batch" "--quiet" "--no-color"))))
(def %operands
  (fn (self l) (if (if (null? l) #f (%engine-flag? (first l))) (self (rest l)) l)))

; With no operands the session goes on to the REPL.
(def main
  (fn (_)
    (let ((ops (%operands (rest (Sys args (lit program))))))
      (unless (null? ops) (Sys exit (backgammon-main ops))))))

(provide backgammon/run main)
