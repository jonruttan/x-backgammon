# The doubling cube
# @weight 2

Money play: a side may double before it rolls while the cube is in the
middle or its own; the other side takes, owning the cube at twice the
value, or passes and loses the game at the value it had.  A game won is
worth its kind, 1, 2 for a gammon or 3 for a backgammon, times the cube.


## the game

### after a play the other side is to roll, and may double first

```backgammon
(def cb-g (game-at (pos-start) '(3 1) (Random sw 1)))
(game-play! cb-g (first (game-plays cb-g)))
(write (list (game-dice cb-g) (game-to-roll? cb-g) (game-may-double? cb-g (game-turn cb-g)) (game-cube cb-g)))
```
---
    (() #t #t 1)


### a double taken doubles the cube, the taker owns it, and the doubler rolls

```backgammon
(def cb-g (game-at (pos-start) '(3 1) (Random sw 1)))
(game-play! cb-g (first (game-plays cb-g)))
(game-double! cb-g)
(def cb-offered (game-offered? cb-g))
(game-take! cb-g)
(write (list cb-offered (game-cube cb-g) (game-owner cb-g) (game-turn cb-g) (pair? (game-dice cb-g)) (game-may-double? cb-g (game-turn cb-g))))
```
---
    (#t 2 0 1 #t #f)


### the owner may double next; the side without the cube rolls at once

```backgammon
(def cb-g (game-at (pos-start) '(3 1) (Random sw 1)))
(game-play! cb-g (first (game-plays cb-g)))
(game-double! cb-g)
(game-take! cb-g)
(game-play! cb-g (first (game-plays cb-g)))
(def cb-white (game-to-roll? cb-g))
(game-roll! cb-g)
(game-play! cb-g (first (game-plays cb-g)))
(write (list cb-white (game-to-roll? cb-g) (pair? (game-dice cb-g))))
```
---
    (#t #f #t)


### a double passed loses the game at the cube's value

```backgammon
(def cb-g (game-at (pos-start) '(3 1) (Random sw 1)))
(game-play! cb-g (first (game-plays cb-g)))
(game-double! cb-g)
(game-pass! cb-g)
(write (list (game-over? cb-g) (game-result cb-g)))
```
---
    (#t (1 1 0))


### taking back a play puts the cube back as it was

```backgammon
(def cb-g (game-at (pos-start) '(3 1) (Random sw 1)))
(game-play! cb-g (first (game-plays cb-g)))
(game-double! cb-g)
(game-take! cb-g)
(game-undo! cb-g (fn (_ side) (= side WHITE)))
(write (list (game-cube cb-g) (game-owner cb-g) (game-offered? cb-g) (game-dice cb-g)))
```
---
    (1 () #f (3 1))


## the engine's cube

### in contact the engine never doubles and always takes

```backgammon
(def cb-g (game-at (pos-start) () (Random sw 1)))
(write (list (cube-double? cb-g) (cube-take? cb-g)))
```
---
    (#f #t)


### in a race it doubles by the Keith count, and takes or passes by it

The side to roll has 75 pips and a Keith count of 75.  Against 81 the
lead is too small to double; against 83 it doubles and the double is
taken; against 85, a count of 86, it doubles and the double is passed.

```backgammon
(def cb-me '((6 . 5) (5 . 5) (4 . 5)))
(def cb-at (fn (_ opp) ((fn (_ g) (list (cube-double? g) (cube-take? g))) (game-at (pos-make WHITE cb-me opp) () (Random sw 1)))))
(write (list (cb-at '((6 . 11) (5 . 2) (4 . 1) (1 . 1)))
             (cb-at '((6 . 12) (5 . 1) (4 . 1) (2 . 1)))
             (cb-at '((6 . 10) (5 . 5)))))
```
---
    ((#f #t) (#t #t) (#t #f))


## at the board

### before a person's roll the choices are roll or double; doubled, the engine takes

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "8" "/" "5" " " "6" "/" "5" 'enter))
(tui-auto-play! st)
(tui-auto-play! st)
(def cb-choices (spec-view st 'choices))
(tui-events! st)
(tui-key! st "d")
(def cb-engine (tui-engine-to-move? st))
(tui-auto-play! st)
(write (list cb-choices cb-engine (spec-view st 'cube) (tui-last st) (spec-event-kinds st)))
```
---
    (("Roll" "Double") #t (2 . 1) "Black takes: the cube is at 2." ('roll))


### Enter rolls when a roll waits

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "8" "/" "5" " " "6" "/" "5" 'enter))
(tui-auto-play! st)
(tui-auto-play! st)
(tui-events! st)
(tui-key! st 'enter)
(write (list (spec-view st 'choices) (spec-event-kinds st)))
```
---
    (() ('roll))


### a picked checker waits for the roll

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "8" "/" "5" " " "6" "/" "5" 'enter))
(tui-auto-play! st)
(tui-auto-play! st)
(tui-key! st (list 'place 6))
(write (spec-note st))
```
---
    "Roll or double first: r rolls, d doubles."


### the window draws the cube and the choices, and a click picks one

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "8" "/" "5" " " "6" "/" "5" 'enter))
(tui-auto-play! st)
(tui-auto-play! st)
(def g (spec-gui st))
(write (list (spec-pixel g 868 350) (spec-pixel g 960 660) (gui-at 1000 680) (gui-at 1120 680)))
```
---
    ((226 200 152 255) (250 208 70 255) ('key ('choice 0)) ('key ('choice 1)))


## a line at a time

### a double offered and taken

```backgammon
(def r (spec-session '("dice 65" "24/13" "double" "take" "quit") 7 'both))
(write (list (spec-has? "roll or double> " (rest r)) (spec-has? " doubles to 2." (rest r)) (spec-has? " takes: the cube is at 2." (rest r))))
```
---
    (#t #t #t)


### a double passed ends the game

```backgammon
(def r (spec-session '("dice 65" "24/13" "double" "pass" "quit") 7 'both))
(write (list (spec-has? " passes." (rest r)) (spec-has? " wins 1 point: " (rest r)) (spec-has? " passed the double." (rest r))))
```
---
    (#t #t #t)
