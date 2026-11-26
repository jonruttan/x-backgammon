# GNU Backgammon as the opponent
# @weight 2

gnubg's external player answers a position, written as a FIBS board
line, with its play or its cube choice.  A stand-in on this machine
answers as it does.


## The board line

### the start, white to play 6-2, as gnubg was asked it

```backgammon
(write (gnubg-board (game-at (pos-start) (list 6 2) (Random sw 1))))
```
---
    "board:You:gnubg:0:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0:2:0:1:6:2:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0"


### the bar, the checkers off, the cube owned and a double offered

```backgammon
(def gb-g (xgid-game "a-B--BCBB---b-A---ccd-bB-A:1:1:-1:31:0:0:0:0:6" (Random sw 1)))
(def gb-d (xgid-game "-a--aBCBB---------bcbA-bA-:2:-1:-1:D:0:0:0:0:6" (Random sw 1)))
(write (list (gnubg-board gb-g) (gnubg-board gb-d)))
```
---
    ("board:You:gnubg:0:0:0:-1:0:-2:2:0:4:3:3:0:0:0:-1:0:2:0:0:0:-2:-2:-3:-2:0:0:-2:0:1:1:3:1:0:0:2:0:1:0:1:-1:0:25:0:0:1:1:2:0:0:0" "board:You:gnubg:0:0:0:0:-1:2:0:-1:2:3:2:0:0:0:0:0:0:0:0:0:-2:-2:-3:-2:1:0:0:1:0:1:0:0:0:0:4:1:0:1:1:-1:0:25:4:4:0:0:2:0:0:0")


## gnubg's plays read

### the bar is 25, off is 0, and a hit keeps its mark

```backgammon
(write (List map gnubg-play-text (list "24/18 13/11" "25/22 22/21 " "6/0 5/0" "24/20* 24/23" "")))
```
---
    ("24/18 13/11" "bar/22 22/21" "6/off 5/off" "24/20* 24/23" "")


## Against a stand-in

### its name, its play, and what it was asked

```backgammon
(def gb-s (spec-stand-in (list "24/18 13/11") #f))
(def gb-g (game-at (pos-start) (list 6 2) (Random sw 1)))
(def gb-pl (opponent-play (first gb-s) gb-g))
(write (list (opponent-name (first gb-s)) (play-text gb-pl) (opponent-note! (first gb-s))
             (str=? (spec-asked (rest gb-s)) (Str8 append "version\n" (gnubg-board gb-g) "\n"))))
```
---
    ("gnubg stand-in" "24/18 13/11" () #t)


### its cube choices: double, roll, take, beaver and drop

```backgammon
(def gb-s (spec-stand-in (list "double" "roll" "take" "beaver" "drop") #f))
(def gb-g (game-at (pos-start) () (Random sw 1)))
(def gb-o (first gb-s))
(write (list (opponent-double? gb-o gb-g) (opponent-double? gb-o gb-g)
             (opponent-take? gb-o gb-g) (opponent-take? gb-o gb-g) (opponent-take? gb-o gb-g)
             (opponent-note! gb-o)))
```
---
    (#t #f #t #t #f ())


### a play that is not legal: the engine plays, and the note says why

```backgammon
(def gb-s (spec-stand-in (list "24/14 13/11") #f))
(def gb-g (game-at (pos-start) (list 6 2) (Random sw 1)))
(def gb-pl (opponent-play (first gb-s) gb-g))
(write (list (play-text gb-pl) (spec-best (pos-start) 6 2) (opponent-note! (first gb-s)) (opponent-note! (first gb-s))))
```
---
    ("13/11 8/2" "13/11 8/2" "gnubg answered \"24/14 13/11\" to its roll: the engine chose." ())


### gone: the engine plays on, said once

```backgammon
(def gb-s (spec-stand-in () #t))
(def gb-o (first gb-s))
(def gb-g (game-at (pos-start) (list 6 2) (Random sw 1)))
(def gb-a (play-text (opponent-play gb-o gb-g)))
(def gb-n (opponent-note! gb-o))
(def gb-b (opponent-double? gb-o (game-at (pos-start) () (Random sw 1))))
(write (list gb-a gb-n gb-b (opponent-note! gb-o)))
```
---
    ("13/11 8/2" "gnubg stopped answering: the engine plays on." #f ())


### silent: after its wait the engine plays, and it is not asked again

```backgammon
(def gb-s (spec-stand-in () #f))
(def gb-o (first gb-s))
(def gb-g (game-at (pos-start) (list 6 2) (Random sw 1)))
(def gb-a (play-text (opponent-play gb-o gb-g)))
(def gb-n (opponent-note! gb-o))
(def gb-t (Sys time-of-day))
(def gb-b (opponent-double? gb-o (game-at (pos-start) () (Random sw 1))))
(def gb-quick (< (- (first (Sys time-of-day)) (first gb-t)) 1))
(write (list gb-a gb-n gb-b gb-quick
             (str=? (spec-asked (rest gb-s)) (Str8 append "version\n" (gnubg-board gb-g) "\n"))))
```
---
    ("13/11 8/2" "gnubg gave no answer in 1 second: the engine plays on." #f #t #t)


### on the board, the stand-in plays white and its play is shown

```backgammon
(def gb-s (spec-stand-in (list "24/18 13/11") #f))
(def st (tui-make (Random sw 1) 'black (first gb-s)))
(tui-game! st (game-at (pos-start) (list 6 2) (Random sw 1)))
(def gb-due (tui-engine-to-move? st))
(tui-auto-play! st)
(write (list gb-due (tui-last st)))
```
---
    (#t "White rolled 6-2 and played 24/18 13/11.")


## Reaching it

### nothing listening, a bad address, what is not gnubg, and what is silent

```backgammon
(def gb-p (spec-free-address))
(def gb-l (Socket tcp-listen-on "127.0.0.1" 0))
(def gb-fd (Socket tcp-connect "127.0.0.1" (Socket local-port gb-l)))
(def gb-peer (Socket accept gb-l))
(Socket send gb-peer "hello\n")
(def gb-fd2 (Socket tcp-connect "127.0.0.1" (Socket local-port gb-l)))
(def gb-peer2 (Socket accept gb-l))
(write (list (spec-has? "nothing answers at 127.0.0.1:" (gnubg-opponent gb-p))
             (gnubg-opponent "host:port")
             (gnubg-on gb-fd 1000)
             (gnubg-on gb-fd2 200)
             GNUBG-WAIT))
```
---
    (#t "the address is HOST:PORT, :PORT or PORT" () () 60000)
