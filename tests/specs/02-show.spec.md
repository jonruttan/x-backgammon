# The board as text
# @weight 1

The board is drawn from white's side: white's checkers are O, black's
X, white's home board at the bottom right.


## the start

### the top row holds each side's back and mid checkers

```backgammon
(write (List ref 2 (board-lines (pos-start))))
```
---
    " | O           X    |   | X              O |"


### the same board shows when black is to move

```backgammon
(def w (board-lines (pos-start)))
(def b (board-lines (pos-swap (pos-start))))
(write (list (List all? (fn (_ i) (str=? (List ref i w) (List ref i b))) '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)) (List ref 17 b)))
```
---
    (#t " black to move")
