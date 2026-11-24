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
(import backgammon/eval evaluate eval-parts eval-fine eval-contact? eval-ranked eval-best)
(import backgammon/coach coach-judge)
(import backgammon/bearoff BEAROFF-ONE BEAROFF-ROLL bearoff-make bearoff-rank bearoff-size bearoff-mean bearoff-chance bearoff-win
  bearoff-write! bearoff-read bearoff-use! bearoff-due? bearoff-table bearoff-solve! bearoff-path)
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

; --- the board on a terminal ----------------------------------------------------
;
; ROWS of SCREEN as text, right-trimmed and joined by newlines; a board
; interface for HUMAN at the start with white to play D1 D2; ST drawn on
; SCREEN, the heap collected first, as the loop does; KEYS pressed; and
; a left click at SCREEN ROW and COL, counted from 0.
(import x/sys/gc)
(import x/tui/screen)
(import x/tui/style)
(import backgammon/board play-next play-after play-done step-die)
(import backgammon/game game-at)
(import backgammon/tui tui-make tui-game tui-game! tui-quit? tui-message tui-last tui-done tui-score
  tui-engine-to-move? tui-auto-play! tui-key! tui-draw! tui-events! tui-view tui-counts)

(def spec-rows
  (fn (_ screen rows)
    (Str8 join "\n" (List map (fn (_ i) (Str8 trim-right (Screen row-text screen i))) rows))))

(def spec-tui
  (fn (_ human d1 d2)
    (def st (tui-make (Random sw 1) human))
    (tui-events! st)
    (tui-game! st (game-at (pos-start) (list d1 d2) (Random sw 1)))))

(def spec-draw! (fn (_ st screen) (Heap collect) (tui-draw! st screen)))

(def spec-keys! (fn (_ st keys) (List for-each (fn (_ k) (tui-key! st k)) keys)))

(def spec-click! (fn (_ st row col) (tui-key! st (list (lit mouse) 0 (+ col 1) (+ row 1) #t))))

; The next steps of D1 D2 from P after DONE, as (FROM TO) indices.
(def spec-next
  (fn (_ p d1 d2 done) (List map (fn (_ s) (list (first s) (first (rest s)))) (play-next p d1 d2 done))))

; --- the board in a window ------------------------------------------------------
;
; The kinds of the events ST has had since last asked; a picture's pixel
; at X Y; and the board drawn from ST's view, the gui answered.
(import x/gfx/canvas)
(import backgammon/gui gui-make gui-draw! gui-at gui-spot gui-dice-x gui-canvas)
(import backgammon/sound sound-render)

(def spec-event-kinds (fn (_ st) (List map first (tui-events! st))))

(def spec-pixel (fn (_ g x y) (Canvas pixel (gui-canvas g) x y)))

(def spec-gui (fn (_ st) ((fn (_ g) (gui-draw! g (tui-view st) ()) g) (gui-make))))

; --- the coach --------------------------------------------------------------------
;
; What ST's view says under the last play: what was said, or the coach's
; word; and what the view holds at KEY.
(def spec-view (fn (_ st key) (rest (Assoc find key (tui-view st)))))
(def spec-note (fn (_ st) (spec-view st (lit msg))))

; --- the bear-off -----------------------------------------------------------------
;
; Specs go without this machine's table, a race counted in pips, unless
; a case puts one in use.
(bearoff-use! ())
;
; The rank in T of the position whose counts, from the 1-point up, are CS.
(def spec-rank (fn (_ t cs) (bearoff-rank t (fn (_ k) (List ref k cs)))))
