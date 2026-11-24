# The tutorial
# @weight 2

Eight lessons, each a position, a roll and one idea; the play asked for
is judged by the engine, as the coach judges, before it is made.  The
last is a double to take or pass.


## the lessons

### each lesson's position has the play it teaches as the engine's best

```backgammon
(def tu-best
  (fn (_ i)
    ((fn (_ g) (if (lesson-cube? i) (cube-take? g) (play-text (eval-best (game-pos g) (first (game-dice g)) (first (rest (game-dice g)))))))
     (lesson-game i (Random sw 1)))))
(write (list lesson-count (List map tu-best (List range 0 lesson-count))))
```
---
    (8 ("24/13" "24/18*/14" "bar/16" "8/5 6/5" "13/10 13/7" "9/4 8/4" "5/off 3/off" #t))


### a lesson's title is counted, and its lines fit the card

```backgammon
(write (list (lesson-title 2)
             (List all? (fn (_ i) (List all? (fn (_ l) (< (Str8 length l) 47)) (lesson-lines i))) (List range 0 lesson-count))
             (List all? (fn (_ i) (< (Str8 length (lesson-ask i)) 47)) (List range 0 lesson-count))))
```
---
    ("Lesson 3 of 8: The bar" #t #t)


### the engine's play is right; another is judged as the coach judges it

```backgammon
(def tu-g (lesson-game 3 (Random sw 1)))
(def tu-right (lesson-judge tu-g (play-find (game-pos tu-g) 3 1 "8/5 6/5")))
(def tu-wrong (lesson-judge tu-g (play-find (game-pos tu-g) 3 1 "13/9")))
(write (list tu-right (first tu-wrong) (spec-has? "Not the best: 8/5 6/5 is better by 25: " (rest tu-wrong))))
```
---
    ((#t . "Right: that is the engine's play.") #f #t)


### the cube's lesson is a double offered, and taking it is right

```backgammon
(def tu-g (lesson-game 7 (Random sw 1)))
(write (list (game-offered? tu-g) (game-turn tu-g) (first (lesson-judge-cube tu-g #t)) (first (lesson-judge-cube tu-g #f))))
```
---
    (#t 1 #t #f)


## at the board

### a lesson shows its card, takes back a wrong play, and makes a right one

```backgammon
(def st (tui-make (Random sw 1) 'white))
(tui-lesson! st 0)
(def tu-card (first (spec-view st 'help)))
(spec-keys! st (list 'escape "1" "3" "/" "8" " " "1" "3" "/" "7" 'enter))
(def tu-wrong (list (spec-note st) (game-dice (tui-game st)) (game-turn (tui-game st))))
(spec-keys! st (list "2" "4" "/" "1" "3" 'enter))
(write (list tu-card (spec-has? "Not the best: 24/13 is better by " (first tu-wrong)) (rest tu-wrong)
             (spec-note st) (game-turn (tui-game st)) (tui-engine-to-move? st)))
```
---
    ("Lesson 1 of 8: Moving" #t ((6 5) 0) "Right: that is the engine's play.  n goes on." 1 #f)


### n goes to the next lesson, its card shown

```backgammon
(def st (tui-make (Random sw 1) 'white))
(tui-lesson! st 0)
(spec-keys! st (list 'escape "n"))
(write (list (spec-view st 'lesson) (first (spec-view st 'help)) (tui-last st)))
```
---
    (1 "Lesson 2 of 8: Hitting" "White to play 6-4: hit, and keep going.")


### doubled in the cube's lesson, a pass is wrong and a take is right

```backgammon
(def st (tui-make (Random sw 1) 'white))
(tui-lesson! st 7)
(tui-key! st 'escape)
(def tu-choices (spec-view st 'choices))
(tui-key! st "p")
(def tu-pass (list (spec-note st) (game-offered? (tui-game st))))
(tui-key! st "t")
(write (list tu-choices tu-pass (spec-note st) (spec-view st 'cube)))
```
---
    (("Take" "Pass") ("Not the best: take.  You win more than one game in four from here, so a take loses less.  Try again: h shows the best." #t) "Right: take.  You win more than one game in four from here.  n goes on." (2 . 0))


### after the last lesson a game starts

```backgammon
(def st (tui-make (Random sw 1) 'white))
(tui-lesson! st 7)
(spec-keys! st (list 'escape "n"))
(write (list (spec-view st 'lesson) (spec-note st) (game-cube (tui-game st))))
```
---
    (() "That is the tutorial.  A game against the engine is on." 1)


### the command starts a lesson

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list ":" "t" "u" "t" "o" "r" "i" "a" "l" " " "5" 'enter))
(write (list (spec-view st 'lesson) (tui-last st)))
```
---
    (4 "White to play 6-3: cover it, leave few shots.")


## a line at a time

### a wrong play is tried again, and a right one goes on

```backgammon
(def r (spec-session '("13/8 13/7" "24/13" "quit") 7 'tutorial))
(write (list (spec-has? "Lesson 1 of 8: Moving" (rest r)) (spec-has? "  Try again.\n" (rest r))
             (spec-has? "Right: that is the engine's play.\n" (rest r)) (spec-has? "Lesson 2 of 8: Hitting" (rest r))))
```
---
    (#t #t #t #t)


### the lessons gone through, a game follows

```backgammon
(def r (spec-session '("next" "next" "next" "next" "next" "next" "next" "t" "quit") 7 'tutorial))
(write (list (spec-has? "Black doubles to 2.  White: take or pass> " (rest r)) (spec-has? "Right: take." (rest r))
             (spec-has? "That is the tutorial.  A game against the engine follows.\n" (rest r)) (spec-has? " moves first.\n" (rest r))))
```
---
    (#t #t #t #t)
