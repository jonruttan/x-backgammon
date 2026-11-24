# The board on a whole terminal
# @weight 2

backgammon/tui: the state the board interface keeps, what a key does to
it, and what is drawn.  Each case presses keys or clicks, draws on a
screen of a given size and reads rows of it back.  `spec-tui` starts a
game at the starting position with white to play the dice given.

On 80 columns each place is 5 wide and the board starts at column 4:
slot S at column 5 + 5S, its checkers in the middle of it; the bottom
row's edge is row 12, the top's row 2.


## a play a step at a time

### the start's 3-1: every checker that can move, by either die

```backgammon
(write (spec-next (pos-start) 3 1 ()))
```
---
    ((23 20) (12 9) (7 4) (5 2) (23 22) (7 6) (5 4))

### after 8/5 the 1 is left, and the play is complete after one more

```backgammon
(write (list (spec-next (pos-start) 3 1 '((7 4 #f))) (spec-next (pos-start) 3 1 '((7 4 #f) (5 4 #f)))))
```
---
    (((23 22) (7 6) (5 4) (4 3)) ())

### a step that would leave the larger die unplayed is not offered

```backgammon
(write (spec-next (pos-make WHITE '((13 . 1)) '((23 . 2) (6 . 13))) 6 5 ()))
```
---
    ((12 6))


## drawing

### the start on 80 by 24: the points' numbers, the checkers, the dice on white's half

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(List for-each (fn (_ i) (write (Str8 trim-right (Screen row-text s i)))) '(0 2 7 12 14 16))
```
---
    "      13   14   15   16   17   18        19   20   21   22   23   24""       ●                   ●              ●                        ●""                                                    3   1""       ●                   ●              ●                        ●""      12   11   10    9    8    7         6    5    4    3    2    1    off""    ▶ ● White (you)  167 pips     ● Black (engine)  167 pips  points 0-0  cube 1"

### each side's checkers in its own colour

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(write (list (Style fg (Screen style-at s 12 42)) (Style fg (Screen style-at s 12 67))))
```
---
    (231 16)

### on 60 columns the places are 3 wide

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 20 60))
(spec-draw! st s)
(write (Str8 trim-right (Screen row-text s 14)))
```
---
    "         12 11 10  9  8  7     6  5  4  3  2  1  off"

### too small a terminal says so

```backgammon
(def s (Screen make 15 40))
(spec-draw! (spec-tui 'white 3 1) s)
(write (Screen row-text s 0))
```
---
    "Too small: x-backgammon needs 46 by 20. "

### playing black, the board is turned: black's home at the bottom right

```backgammon
(def st (spec-tui 'black 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(write (list (Style fg (Screen style-at s 12 42)) (Str8 trim-right (Screen row-text s 7))))
```
---
    (16 "                 3   1")


## making a play

### a click on the 8 picks it, and the places it can go are marked

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(spec-click! st 12 27)
(spec-draw! st s)
(write (List map (fn (_ x) (Style bg (Screen style-at s 14 x))) '(27 32 42 47 52)))
```
---
    (() 220 () 220 220)

### a click on the 8, then the 5, then the 6 and the 5, plays 8/5 6/5

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(spec-click! st 12 27)
(spec-click! st 12 47)
(spec-click! st 12 42)
(spec-click! st 12 47)
(write (list (tui-last st) (game-turn (tui-game st))))
```
---
    ("White rolled 3-1 and played 8/5 6/5." 1)

### a click past both dice moves the checker by both: 24/20

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(spec-click! st 2 67)
(spec-click! st 2 47)
(write (tui-last st))
```
---
    "White rolled 3-1 and played 24/20."

### Enter on the 6, and again, moves it by the larger die; Backspace takes it back

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '(enter enter))
(def made (tui-done st))
(spec-keys! st '(backspace))
(write (list made (tui-done st)))
```
---
    (((5 2 #f)) ())

### the arrows move the cursor: left from the 6 is the bar, then the 7 and the 8

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '(left left left enter enter))
(write (tui-done st))
```
---
    ((7 4 #f))

### a play typed is played

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("1" "3" "/" "1" "0" " " "6" "/" "5" enter))
(write (tui-last st))
```
---
    "White rolled 3-1 and played 13/10 6/5."

### a play typed that is not legal says so

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("2" "4" "/" "1" "8" enter))
(write (tui-message st))
```
---
    "that is not a legal play of the roll: 24/18"

### h gives the engine's best plays

```backgammon
(def st (spec-tui 'white 3 1))
(tui-key! st "h")
(write (Str8 starts? "Hint: 8/5 6/5  ·  " (tui-message st)))
```
---
    #t

### u takes back the last play

```backgammon
(def st (spec-tui 'both 3 1))
(spec-keys! st '("8" "/" "5" " " "6" "/" "5" enter "u"))
(write (list (tui-last st) (game-turn (tui-game st)) (game-dice (tui-game st))))
```
---
    ("Your last play is taken back." 0 (3 1))


## the engine

### the engine plays the side no one does

```backgammon
(def st (spec-tui 'black 3 1))
(write (tui-engine-to-move? st))
(tui-auto-play! st)
(write (tui-last st))
```
---
    #t"White rolled 3-1 and played 8/5 6/5."

### a roll with one play is played for a person: 6-6 from the bar against a closed board

```backgammon
(def st (spec-tui 'white 6 6))
(tui-game! st (game-at (pos-make WHITE '((25 . 1) (6 . 14)) '((1 . 2) (2 . 2) (3 . 2) (4 . 2) (5 . 2) (6 . 2))) '(6 6) (Random sw 1)))
(write (tui-engine-to-move? st))
(tui-auto-play! st)
(write (tui-last st))
```
---
    #t"White rolled 6-6 and cannot move."


## keys

### ? shows the keys, any key closes them, and q quits

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(tui-key! st "?")
(spec-draw! st s)
(def shown (spec-has? "Click a checker, then the place it goes:" (Screen row-text s 2)))
(tui-key! st "x")
(tui-key! st "q")
(write (list shown (tui-quit? st)))
```
---
    (#t #t)

### the mouse on the board is a place, off it nothing

```backgammon
(def st (spec-tui 'white 3 1))
(def s (Screen make 24 80))
(spec-draw! st s)
(spec-click! st 7 10)
(spec-click! st 20 10)
(write (list (tui-message st) (tui-done st)))
```
---
    ("" ())
