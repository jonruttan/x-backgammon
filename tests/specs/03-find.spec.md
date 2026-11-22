# Reading a play
# @weight 1

`play-find` reads a play as it is written and answers the legal play
it names, or why there is none.  The moves are made on a copy of the
position and matched by the position they leave, so a checker's moves
may be written whole or step by step.


## whole or by steps

### a back checker run whole

```backgammon
(write (spec-find (pos-start) 6 5 "24/13"))
```
---
    "24/13"


### the same run die by die

```backgammon
(write (spec-find (pos-start) 6 5 "24/18 18/13"))
```
---
    "24/13"


### two checkers from one point

```backgammon
(write (spec-find (pos-start) 5 2 "13/8 13/11"))
```
---
    "13/11 13/8"


### doubles with counts

```backgammon
(write (spec-find (pos-start) 3 3 "8/5(2) 6/3(2)"))
```
---
    "8/5(2) 6/3(2)"


## hits

### a hit marked

```backgammon
(def p (pos-make WHITE '((8 . 1)) '((20 . 1) (1 . 14))))
(write (spec-find p 2 1 "8/5*"))
```
---
    "8/5*"


### a hit at the end of a move is made unmarked

```backgammon
(def p (pos-make WHITE '((8 . 1)) '((20 . 1) (1 . 14))))
(write (list (spec-find p 2 1 "8/6 6/5") (spec-find p 2 1 "8/5")))
```
---
    ("8/5*" "8/5*")


## refused

### a move the dice do not make

```backgammon
(write (spec-find (pos-start) 6 5 "24/20"))
```
---
    "that is not a legal play of the roll"


### a checker that is not there

```backgammon
(write (spec-find (pos-start) 6 5 "23/12"))
```
---
    "those checkers cannot move that way"


### words that are not a play

```backgammon
(write (spec-find (pos-start) 6 5 "hello"))
```
---
    "a move is written 24/18, 13/11(2), bar/22, 6/off or 24/18*/13"
