# The plays of a roll
# @weight 1

A position is made with `pos-make`: the colour to move, then each
side's checkers as `(POINT . COUNT)`, points counted from that side's
own home board, 25 its bar; a checker not listed is borne off.  A play
is written the usual way, the highest checker first.


## the start

### each side has 167 pips and none off

```backgammon
(def p (pos-start))
(write (list (pos-me-pips p) (pos-opp-pips p) (pos-me-off p) (pos-opp-off p)))
```
---
    (167 167 0 0)


### there are 21 rolls

```backgammon
(write (List length rolls))
```
---
    21


### 6-5 runs a back checker to the midpoint

```backgammon
(write (List includes? "24/13" (spec-plays (pos-start) 6 5)))
```
---
    #t


### 3-1 makes the five point

```backgammon
(write (List includes? "8/5 6/5" (spec-plays (pos-start) 3 1)))
```
---
    #t


## both dice, or the larger

### a closed board leaves a checker on the bar no move

```backgammon
(def p (pos-make WHITE '((25 . 1) (6 . 14)) '((1 . 2) (2 . 2) (3 . 2) (4 . 2) (5 . 2) (6 . 2) (12 . 3))))
(write (spec-plays p 6 6))
```
---
    ("no move")


### when either die alone can be played, the larger is

```backgammon
(def p (pos-make WHITE '((24 . 1)) '((12 . 2) (2 . 13))))
(write (spec-plays p 6 5))
```
---
    ("24/18")


### a lone checker plays both dice through a hit

```backgammon
(def p (pos-make WHITE '((8 . 1)) '((20 . 1) (1 . 14))))
(write (spec-plays p 2 1))
```
---
    ("8/5*")


## doubles

### two checkers share four ones three ways

```backgammon
(def p (pos-make WHITE '((24 . 2)) '((1 . 15))))
(write (spec-count p 1 1))
```
---
    3


## bearing off

### a die larger than any point bears off from the highest

```backgammon
(def p (pos-make WHITE '((5 . 1) (2 . 1)) '((1 . 15))))
(write (spec-plays p 6 1))
```
---
    ("5/off 2/1" "5/off")


### four fours bear off the last two and end the game

```backgammon
(def p (pos-make WHITE '((6 . 1) (3 . 1)) '((24 . 15))))
(def ps (plays p 4 4))
(write (list (List map play-text ps) (pos-over? (rest (first ps)))))
```
---
    (("6/off 3/off") #t)


## counting

### no turns is one position

```backgammon
(write (perft (pos-start) 0))
```
---
    1
