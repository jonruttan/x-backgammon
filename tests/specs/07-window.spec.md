# The board in a window
# @weight 3

backgammon/gui draws the board as a picture and says what a point of it
is; backgammon/tui tells the window what has happened, for it to show
in turn.  The window is 1180 by 800: each place 60 wide from x 44, the
felt from y 44 to 676, a point 260 long, the bar slot 6 and the tray at
x 848.


## what happened, for the window to show

### a game set up says the board jumped, then the dice thrown

```backgammon
(def st (spec-tui 'white 3 1))
(write (tui-events! st))
```
---
    (('jump) ('roll 0 3 1))

### a play made a checker at a time: a step each, the other side then to roll

```backgammon
(def st (spec-tui 'white 3 1))
(tui-events! st)
(spec-keys! st (list (list 'place 8) (list 'place 5) (list 'place 6) (list 'place 5)))
(def es (tui-events! st))
(write (list (List map first es) (List ref 2 (first es)) (List ref 4 (first (rest es)))))
```
---
    (('step 'step) (7 4 #f) (3))

### the engine's play is shown a step at a time too

```backgammon
(def st (spec-tui 'black 3 1))
(tui-events! st)
(tui-auto-play! st)
(write (spec-event-kinds st))
```
---
    ('step 'step)

### taking a play back jumps

```backgammon
(def st (spec-tui 'both 3 1))
(spec-keys! st '("8" "/" "5" " " "6" "/" "5" enter "u"))
(write (List last (spec-event-kinds st)))
```
---
    'jump


## what a point of the window is

### the places, the bar, the tray and a button; the band between the rows is nothing

```backgammon
(write (List map (fn (_ p) (gui-at (first p) (rest p)))
  (list (pair 74 300) (pair 74 500) (pair 430 100) (pair 880 600) (pair 794 650) (pair 1000 310) (pair 1000 365) (pair 300 360))))
```
---
    (('place 13) ('place 12) ('place 25) ('place 0) ('place 1) ('key "n") ('key "u") ())

### a checker's middle: up from the bottom edge, and closer together past five

```backgammon
(write (list (gui-spot 6 #t 0 5) (gui-spot 6 #t 4 5) (gui-spot 6 #t 4 9) (gui-spot 13 #t 0 5) (gui-spot 25 #t 0 1)))
```
---
    ((494 . 650) (494 . 442) (494 . 546) (74 . 70) (434 . 278))

### the dice of the side to move lie on its own half

```backgammon
(write (list (gui-dice-x 0 0) (gui-dice-x 0 1)))
```
---
    (644 224)


## the picture

### the start drawn: white's checker on the 6, black's on the 1, an empty point's colour

```backgammon
(def g (spec-gui (spec-tui 'white 3 1)))
(write (list (spec-pixel g 494 650) (spec-pixel g 794 650) (spec-pixel g 674 670)))
```
---
    ((240 232 214 255) (52 46 46 255) (156 44 38 255))

### a checker picked is ringed in gold

```backgammon
(def st (spec-tui 'white 3 1))
(tui-key! st (list 'place 8))
(def g (spec-gui st))
(write (spec-pixel g 314 (- 676 (+ 26 (* 2 52)) 28)))
```
---
    (250 208 70 255)


## the sounds

### a checker put down is rendered once, frames of it

```backgammon
(write (< 1000 (rest (sound-render 'place))))
```
---
    #t
