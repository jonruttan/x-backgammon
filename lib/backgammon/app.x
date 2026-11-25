; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/app.x -- the board on the terminal
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Takes the terminal as x-chess does: raw, on the alternate screen, the
; cursor hidden and the mouse reported; all given back as they were on
; the way out.  The size is asked again whenever no key comes for a
; quarter of a second.  A play made for a side waits a moment first, so
; it can be watched; a key pressed meanwhile is acted on first.

(module backgammon/app)

(import x/sys/posix)
(import x/sys/gc)
(import x/type/vector)
(import x/repl/term)
(import x/tui/screen)
(import x/core/doors io-display-to-str)
(import backgammon/tui tui-make tui-command! tui-quit? tui-engine-to-move? tui-auto-play! tui-solve-due? tui-solve-note! tui-solve! tui-key! tui-draw! tui-events!)

(def %esc (fn (_ text) (Str8 append "\x1b" text)))

; How long a play made for a side waits, in milliseconds.
(def %pause 800)

; --- keys --------------------------------------------------------------------------

; A byte reader over standard input, 64 bytes read at a time, with bytes
; that can be put back: (reader) a byte or () at the end, (reader #t)
; whether there are bytes read and not taken, (reader (lit back) BYTES)
; puts BYTES back in front.
(def %reader
  (fn (_)
    (def box (Vector of ()))
    (fn (self . ask)
      (match
        ((null? ask)
          (do (when (null? (Vector ref 0 box)) (Vector set! 0 (Sys fd-read 0 64) box))
              (if (null? (Vector ref 0 box)) ()
                ((fn (_ b) (Vector set! 0 (rest (Vector ref 0 box)) box) b) (first (Vector ref 0 box))))))
        ((eq? (first ask) (lit back)) (Vector set! 0 (List append (first (rest ask)) (Vector ref 0 box)) box))
        (#t (not (null? (Vector ref 0 box))))))))

; Whether a byte will come within MS milliseconds.
(def %waiting? (fn (_ reader ms) (if (reader #t) #t (not (null? (Sys poll (list (pair 0 (list (lit in)))) ms))))))

; The next key: Term's, but a lone escape is the escape key once 30 ms
; pass with nothing after it, and a mouse report, ESC [ < B ; X ; Y M
; (or m on release), is (mouse B X Y PRESS?).
(def %key
  (fn (_ reader)
    (def b (reader))
    (match
      ((null? b) ())
      ((not (= b 27)) (do (reader (lit back) (list b)) (Term key reader)))
      ((not (%waiting? reader 30)) (lit escape))
      (#t ((fn (_ c)
             (match
               ((null? c) (lit escape))
               ((not (= c 91)) (do (reader (lit back) (list 27 c)) (Term key reader)))
               (#t ((fn (_ d)
                      (if (if (null? d) #f (= d 60)) (%mouse reader 0 ())
                        (do (reader (lit back) (if (null? d) (list 27 91) (list 27 91 d))) (Term key reader))))
                    (reader)))))
           (reader))))))

; The rest of an SGR mouse report: numbers apart at ;, ended by M or m.
(def %mouse
  (fn (self reader n acc)
    (def b (reader))
    (match
      ((null? b) (lit escape))
      ((if (< 47 b) (< b 58) #f) (self reader (+ (* n 10) (- b 48)) acc))
      ((= b 59) (self reader 0 (pair n acc)))
      (#t ((fn (_ ns) (list (lit mouse) (List ref 0 ns) (List ref 1 ns) (List ref 2 ns) (= b 77)))
           (List reverse (pair n acc)))))))

; --- the loop ----------------------------------------------------------------------

(def %show!
  (fn (_ st screen)
    (tui-draw! st screen)
    (Term emit 1 (Screen render screen))))

; The next key, the screen kept the terminal's size while it waits.
(def %wait-key
  (fn (self st screen reader)
    (if (%waiting? reader 250) (%key reader)
      (do ((fn (_ size)
             (unless (if (= (first size) (Screen cols screen)) (= (rest size) (Screen rows screen)) #f)
               (do (Screen resize screen (rest size) (first size))
                   (%show! st screen))))
           (Term window 0))
          (self st screen reader)))))

; KEY acted on: the end of the input quits.
(def %act! (fn (_ st key) (tui-key! st (if (null? key) "q" key))))

; The window's events, which the terminal does not show, taken so they
; do not pile up.
(def %drop-events! (fn (_ st) (tui-events! st)))

(def %loop
  (fn (self st screen reader)
    (%drop-events! st)
    (%show! st screen)
    (Heap collect)
    (match
      ((tui-quit? st) ())
      ((tui-solve-due? st)
        (do (tui-solve-note! st) (%show! st screen) (tui-solve! st) (self st screen reader)))
      ((tui-engine-to-move? st)
        (do (if (%waiting? reader %pause) (%act! st (%key reader)) (tui-auto-play! st))
            (self st screen reader)))
      (#t (do (%act! st (%wait-key st screen reader)) (self st screen reader))))))

; Play on the terminal, the dice from RND, the people playing HUMAN and
; the opponent OPP the other sides, the command START run first when it
; is not "": the exit status.
(def app-run
  (fn (_ rnd human start opp)
    (def size (Term window 0))
    (def st (tui-make rnd human opp))
    (unless (str=? start "") (tui-command! st start))
    (def screen (Screen make (rest size) (first size)))
    (def token (Term raw! 0))
    (Term emit 1 (Str8 append (%esc "[?1049h") (%esc "[?25l") (%esc "[?1000h") (%esc "[?1006h")))
    (def failed (guard (e e) (do (%loop st screen (%reader)) ())))
    (Term emit 1 (Str8 append (%esc "[?1006l") (%esc "[?1000l") (%esc "[0m") (%esc "[?25h") (%esc "[?1049l")))
    (Term restore! 0 token)
    (if (null? failed) 0
      (do (Sys fd-write 2 (Str8 append "x-backgammon: " (if (Err err? failed) (failed msg) (io-display-to-str failed)) "\n")) 1))))

(provide backgammon/app app-run)
