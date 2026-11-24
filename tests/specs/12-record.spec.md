# Positions as XGID, games as a .mat file
# @weight 2

An XGID is a position as eXtreme Gammon and GNU Backgammon read it; a
.mat file is a session's games as GNU Backgammon exports them.


## XGID

### the start, white to roll, is the usual XGID

```backgammon
(write (xgid-text (game-at (pos-start) () (Random sw 1))))
```
---
    "XGID=-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:0:6"


### a position read and written again is the same

```backgammon
(def rc-ids
  (list "XGID=-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:0:6"
        "XGID=a-B--BCBB---b-A---ccd-bB-A:1:1:-1:31:0:0:0:0:6"
        "XGID=-a--aBCBB---------bcbA-bA-:2:-1:-1:D:0:0:0:0:6"))
(write (List map (fn (_ id) (xgid-text (xgid-game id (Random sw 1)))) rc-ids))
```
---
    ("XGID=-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:0:6" "XGID=a-B--BCBB---b-A---ccd-bB-A:1:1:-1:31:0:0:0:0:6" "XGID=-a--aBCBB---------bcbA-bA-:2:-1:-1:D:0:0:0:0:6")


### the fields read: the side to move, the dice, the cube and a double

```backgammon
(def rc-g (xgid-game "a-B--BCBB---b-A---ccd-bB-A:1:1:-1:31:0:0:0:0:6" (Random sw 1)))
(def rc-d (xgid-game "-a--aBCBB---------bcbA-bA-:2:-1:-1:D:0:0:0:0:6" (Random sw 1)))
(write (list (game-turn rc-g) (game-dice rc-g) (game-cube rc-g) (game-owner rc-g)
             (game-offered? rc-d) (game-turn rc-d) (game-cube rc-d) (game-owner rc-d)
             (pos-me (game-pos rc-g) BAR) (pos-opp (game-pos rc-g) BAR)))
```
---
    (1 (3 1) 2 0 #t 1 4 1 1 1)


### a side to roll that may not double has its dice thrown

```backgammon
(def rc-g (xgid-game "-b----E-C---eE---c-e----B-:1:-1:1:00:0:0:0:0:6" (Random sw 1)))
(write (list (pair? (game-dice rc-g)) (game-to-roll? rc-g)))
```
---
    (#t #f)


### what is not an XGID says why

```backgammon
(write (List map (fn (_ id) (xgid-game id (Random sw 1)))
  (list "XGID=-b----E-C" "-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:7:6" "-b----E-C---eE---c-e----Z-:0:0:1:00:0:0:0:0:6"
        "-b----E-C---eE---c-e----B-:0:0:1:71:0:0:0:0:6" "-b----E-C---eE---c-e----B-:7:0:1:00:0:0:0:0:6")))
```
---
    ("an XGID has a position and nine fields after it, apart by colons" "only money games are played: the match length is 0" "a character of the position is not -, A to P or a to p" "the dice are 00, D or a roll such as 31" "the cube is a power of two from 0 to 6")


## the .mat file

### a game doubled, taken, redoubled and dropped, laid out as GNU Backgammon lays it

```backgammon
(def rc-g (game-at (pos-start) (list 3 1) (Random sw 1)))
(game-play! rc-g (play-find (game-pos rc-g) 3 1 "8/5 6/5"))
(game-double! rc-g)
(game-take! rc-g)
(game-set-dice! rc-g 6 4)
(game-play! rc-g (play-find (game-pos rc-g) 6 4 "24/18 13/9"))
(game-double! rc-g)
(game-pass! rc-g)
(write (mat-text (list rc-g)))
```
---
    " 0 point match\n\n Game 1\n White : 0                      Black : 0\n  1) 31: 8/5 6/5                  Doubles => 2\n  2)  Takes                      64: 24/18 13/9 \n  3)  Doubles => 4                Drops\n      Wins 2 points\n\n"


### black moving first starts in the right column, a hit marked

```backgammon
(def rc-g (game-at (pos-swap (pos-start)) (list 6 4) (Random sw 1)))
(game-play! rc-g (play-find (game-pos rc-g) 6 4 "24/14"))
(game-roll! rc-g)
(game-set-dice! rc-g 6 4)
(game-play! rc-g (play-find (game-pos rc-g) 6 4 "24/18 13/9"))
(game-roll! rc-g)
(game-set-dice! rc-g 6 5)
(game-play! rc-g (play-find (game-pos rc-g) 6 5 "13/7 8/3"))
(def rc-mat (mat-text (list rc-g)))
(write (list (spec-has? (Str8 append "\n  1)" (Str8 join "" (List repeat 29 " ")) "64: 24/") rc-mat) (spec-has? "*" rc-mat)))
```
---
    (#t #t)


### the board keeps the session's games and saves them

```backgammon
(def st (spec-tui 'white 3 1))
(spec-keys! st (list "8" "/" "5" " " "6" "/" "5" 'enter))
(tui-command! st "new")
(def rc-games (tui-games st))
(tui-command! st "save /nonexistent-dir/x.mat")
(write (list (List length rc-games) (spec-note st)))
```
---
    (1 "Cannot write /nonexistent-dir/x.mat.")


### a line at a time the position is shown as an XGID and set from one

```backgammon
(def r (spec-session '("xgid" "xgid -b----E-C---eE---c-e----B-:0:0:-1:31:0:0:0:0:6" "quit") 7 'both))
(write (list (spec-has? "XGID=-b----E-C---eE---c-e----B-:0:0:1:" (rest r)) (spec-has? "Black to play 3-1> " (rest r))))
```
---
    (#t #t)
