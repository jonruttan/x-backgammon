# The engine's choices
# @weight 1

The engine looks one play ahead and picks the play whose position
scores best for it.  These are opening rolls whose best play is not in
doubt, and a race, which is scored by the pip counts alone.


## openings

### 3-1 makes the five point

```backgammon
(write (spec-best (pos-start) 3 1))
```
---
    "8/5 6/5"


### 4-2 makes the four point

```backgammon
(write (spec-best (pos-start) 4 2))
```
---
    "8/4 6/4"


### 6-1 makes the bar point

```backgammon
(write (spec-best (pos-start) 6 1))
```
---
    "13/7 8/7"


## races

### with no contact the score is the pip difference

```backgammon
(def p (pos-make WHITE '((6 . 5) (5 . 5)) '((3 . 10))))
(write (list (eval-contact? p) (evaluate p) (- (pos-opp-pips p) (pos-me-pips p))))
```
---
    (#f -25 -25)


### with checkers still to pass there is contact

```backgammon
(write (eval-contact? (pos-start)))
```
---
    #t
