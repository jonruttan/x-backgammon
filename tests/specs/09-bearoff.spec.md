# The bear-off, solved
# @weight 3

backgammon/bearoff counts, for every way of setting up to N checkers on
the home points, the chances of bearing them off in each number of
rolls, playing each roll to leave the fewest rolls to come.  Chances are
in units of 1/1048576, rolls in units of 1/4096.

### the table holds every way of setting the checkers, each once

```backgammon
(def bo-t (bearoff-make 3))
(def bo-ranks (List map (fn (_ cs) (spec-rank bo-t cs)) (list '(0 0 0 0 0 0) '(3 0 0 0 0 0) '(0 0 0 0 0 3) '(1 1 1 0 0 0))))
(write (list (bearoff-size bo-t) (List all? (fn (_ r) (< r (bearoff-size bo-t))) bo-ranks)))
```
---
    (84 #t)

### one checker on the 1-point is off in one roll, for certain

```backgammon
(def bo-t (bearoff-make 2))
(def bo-on-1 (spec-rank bo-t '(1 0 0 0 0 0)))
(write (list (bearoff-mean bo-t bo-on-1) (bearoff-chance bo-t bo-on-1 1)))
```
---
    (4096 1048576)

### two on the 6-point are off in one roll only with 3-3, 4-4, 5-5 or 6-6

```backgammon
(def bo-t (bearoff-make 2))
(write (bearoff-chance bo-t (spec-rank bo-t '(0 0 0 0 0 2)) 1))
```
---
    116508

### the side to roll from one checker on the 1-point always wins

```backgammon
(def bo-t (bearoff-make 2))
(write (bearoff-win bo-t (spec-rank bo-t '(1 0 0 0 0 0)) (spec-rank bo-t '(0 0 0 0 0 2))))
```
---
    1048576

### a table written to a file reads back the same

```backgammon
(def bo-t (bearoff-make 3))
(def bo-path "/tmp/x-backgammon-spec-bearoff.xbo")
(bearoff-write! bo-t bo-path)
(def bo-back (bearoff-read bo-path))
(File unlink bo-path)
(def bo-r (spec-rank bo-t '(0 1 0 0 0 2)))
(write (list (bearoff-size bo-back) (= (bearoff-mean bo-t bo-r) (bearoff-mean bo-back bo-r))
             (= (bearoff-chance bo-t bo-r 2) (bearoff-chance bo-back bo-r 2)) (bearoff-read "/tmp/no-such-x-backgammon.xbo")))
```
---
    (84 #t #t ())


## the engine's bear-off

### without a table a bear-off is counted in pips, and no solve is due

```backgammon
(def bo-p (pos-make WHITE '((6 . 1) (5 . 1) (4 . 1) (2 . 1)) '((6 . 2))))
(write (list (evaluate bo-p) (bearoff-due?)))
```
---
    (-5 #f)


### with a table the engine plays to be off soonest

```backgammon
(def bo-p (pos-make WHITE '((6 . 1) (5 . 1) (4 . 1) (2 . 1)) '((6 . 2))))
(bearoff-use! (bearoff-make 4))
(def bo-best (eval-best bo-p 2 1))
(def bo-other (List find (fn (_ pl) (str=? (play-text pl) "6/5 2/off")) (plays bo-p 2 1)))
(write (list (play-text bo-best) (< (eval-fine (rest bo-other)) (eval-fine (rest bo-best))) (coach-judge bo-p 2 1 bo-other)))
(bearoff-use! ())
```
---
    ("4/3 2/off" #t (0 . "Coach: 4/3 2/off is a little better: it gains more in the race."))
