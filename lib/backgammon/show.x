; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/show.x -- the board as text
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The board is drawn from white's side whichever colour moves: white's
; home board at the bottom right, its points numbered 1 to 24 from
; there, black's home board at the top right.  White's checkers are O,
; black's X.  A point shows up to five checkers; past five the fifth is
; the count.  The bar is the middle column, black's checkers on it in
; the top half, white's in the bottom.

(module backgammon/show)

(import backgammon/board BAR WHITE pos-me pos-opp pos-turn pos-swap
  pos-me-off pos-me-pips)
(import x/core/doors int+ int- int< int= str-byte-len io-display-to-str)

; P as seen by white.
(def %white (fn (_ p) (if (int= (pos-turn p) WHITE) p (pos-swap p))))

; What stands on white's index W of the white-side position Q: (MARK .
; COUNT), or () when nothing.
(def %at
  (fn (_ q w)
    (match
      ((int< 0 (pos-me q w)) (pair "O" (pos-me q w)))
      ((int< 0 (pos-opp q (int- 23 w))) (pair "X" (pos-opp q (int- 23 w))))
      (#t ()))))

(def %pad3
  (fn (_ s) (match ((int= (str-byte-len s) 1) (Str8 append " " s " ")) ((int= (str-byte-len s) 2) (Str8 append s " ")) (#t s))))

; Row R, 0 at the edge, of a stack AT.
(def %cell
  (fn (_ at r)
    (match
      ((null? at) "   ")
      ((int< r (rest at))
        (if (if (int= r 4) (int< 5 (rest at)) #f) (%pad3 (io-display-to-str (rest at))) (%pad3 (first at))))
      (#t "   "))))

(def %cells (fn (_ q ws r) (Str8 join "" (List map (fn (_ w) (%cell (%at q w) r)) ws))))

(def %bar-at (fn (_ mark n) (if (int= n 0) () (pair mark n))))

(def %row
  (fn (_ q left bar right r)
    (Str8 append " |" (%cells q left r) "|" (%cell bar r) "|" (%cells q right r) "|")))

(def %numbers (fn (_ ws) (Str8 join "" (List map (fn (_ w) (%pad3 (io-display-to-str (int+ w 1)))) ws))))

(def %side-line
  (fn (_ q mark name)
    (Str8 append " " mark " " name "  pips " (io-display-to-str (pos-me-pips q)) "  off " (io-display-to-str (pos-me-off q)))))

; The board of P as lines of text.
(def board-lines
  (fn (_ p)
    (def q (%white p))
    (def top-l (list 12 13 14 15 16 17))
    (def top-r (list 18 19 20 21 22 23))
    (def bot-l (list 11 10 9 8 7 6))
    (def bot-r (list 5 4 3 2 1 0))
    (def x-bar (%bar-at "X" (pos-opp q BAR)))
    (def o-bar (%bar-at "O" (pos-me q BAR)))
    (def rule " +------------------+---+------------------+")
    (List flatten
      (list
        (list (Str8 append "  " (%numbers top-l) "     " (%numbers top-r)) rule)
        (List map (fn (_ r) (%row q top-l x-bar top-r r)) (list 0 1 2 3 4))
        (list " |                  |BAR|                  |")
        (List map (fn (_ r) (%row q bot-l o-bar bot-r r)) (list 4 3 2 1 0))
        (list rule (Str8 append "  " (%numbers bot-l) "     " (%numbers bot-r))
              (%side-line q "O" "white")
              (%side-line (pos-swap q) "X" "black")
              (if (int= (pos-turn p) WHITE) " white to move" " black to move"))))))

(def board-text (fn (_ p) (Str8 append (Str8 join "\n" (board-lines p)) "\n")))

(provide backgammon/show board-lines board-text)
