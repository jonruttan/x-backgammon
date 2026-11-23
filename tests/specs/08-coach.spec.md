# Hints and the coach
# @weight 3

backgammon/coach judges a person's play against the engine's: the play
the engine prefers, by how many pips, and why, from the part of the
evaluation where the two differ most.  The coach is on until c turns it
off; its word stays under the board until the person's next play.  A
hint keeps the play it gives, for the window to draw.


## the evaluation in parts

### the parts add up to the score

```backgammon
(def p (rest (eval-best (pos-start) 3 1)))
(write (list (List map first (eval-parts p)) (= (evaluate p) (List fold + 0 (List map rest (eval-parts p))))))
```
---
    (('race 'points 'prime 'hit 'bar 'risk) #t)


## the coach

### the engine's own play is praised

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("8" "/" "5" " " "6" "/" "5" enter))
(write (spec-note st))
```
---
    "Coach: the engine plays that too."

### a weaker play is told the better one, by how much, and why

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("2" "4" "/" "2" "1" " " "2" "4" "/" "2" "3" enter))
(write (spec-note st))
```
---
    "Coach: 8/5 6/5 is better by 40: it leaves fewer shots at your blots."

### the word stays under the board through the engine's reply

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("2" "4" "/" "2" "1" " " "2" "4" "/" "2" "3" enter))
(def said (spec-note st))
(tui-auto-play! st)
(write (list (str=? said (spec-note st)) (str=? (tui-last st) "")))
```
---
    (#t #f)

### c turns the coach off, and a play is then not judged

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("c"))
(def said (spec-note st))
(spec-keys! st '("2" "4" "/" "2" "1" " " "2" "4" "/" "2" "3" enter))
(write (list said (spec-note st) (spec-view st 'coaching)))
```
---
    ("The coach is off." "" #f)

### the coach judges only a choice: a roll with one play says nothing

```backgammon
(def p (rest (eval-best (pos-start) 6 6)))
(write (coach-judge (pos-start) 6 6 (eval-best (pos-start) 6 6)))
```
---
    (0 . "Coach: the engine plays that too.")


## the hint

### a hint keeps its play as steps between the viewer's places

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("h"))
(write (spec-view st 'hint))
```
---
    ((8 5) (6 5))

### a step made clears the hint

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "h" (list 'place 8) (list 'place 5)))
(write (spec-view st 'hint))
```
---
    ()

### the window draws the hint in gold, and marks the coach's button while it is on

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st '("h"))
(def g (spec-gui st))
(write (list (spec-pixel g 1140 470) (spec-pixel g 314 546)))
```
---
    ((250 208 70 255) (250 208 70 255))
