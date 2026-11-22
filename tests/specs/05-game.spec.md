# A game a line at a time
# @weight 2

`spec-session` feeds a session lines and answers its exit status and
everything it wrote.  The dice come from a seed, so a session plays
the same way each time.


## the engine against itself

### a game is played to its end

```backgammon
(def r (spec-session () 7 'none))
(write (list (first r) (spec-has? " wins " (rest r))))
```
---
    (0 #t)


## a person at the board

### help lists the commands, and quit leaves

```backgammon
(def r (spec-session '("help" "quit") 7 'both))
(write (list (first r) (spec-has? "dice DD" (rest r)) (spec-has? " to play " (rest r))))
```
---
    (0 #t #t)


### a play that is not legal is refused and asked for again

```backgammon
(def r (spec-session '("dice 65" "24/20" "24/13" "quit") 7 'both))
(write (list (spec-has? "that is not a legal play of the roll: 24/20" (rest r)) (spec-has? " plays 24/13." (rest r))))
```
---
    (#t #t)


### undo takes back the last play

```backgammon
(def r (spec-session '("dice 65" "24/13" "undo" "board" "quit") 7 'both))
(write (spec-has? " plays 24/13." (rest r)))
```
---
    #t
