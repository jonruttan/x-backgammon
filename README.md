# x-backgammon

Backgammon on x-lang: a game against the engine a line at a time, the
board as text, the legal plays of a roll, and a count of plays over
turns that checks the move generator as perft checks a chess engine's.

## Run

```sh
x -l backgammon -- play
x -l backgammon -- play --side black --seed 7
x -l backgammon -- play --window
x -l backgammon -- play --tutorial
x -l backgammon -- play --xgid XGID=-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:0:6
x -l backgammon -- play --gnubg 127.0.0.1:4321
x -l backgammon -- --board
x -l backgammon -- --roll 31
x -l backgammon -- --perft 1
```

`play` is a game against the engine: on the board when run on a
terminal, or in a window with `--window` or `--web` (below).  `--side`
is the side you play, white (the default), black, both, or none to
watch the engine play itself.  The dice are drawn from a seed, printed
at the start when `--seed N` does not give one, so a game can be
played again.  `--tutorial` starts with the lessons, `--xgid ID` from
a position, and `--gnubg ADDRESS` has GNU Backgammon play in place of
the engine (all below).
`--board` prints the starting board.  `--roll DD` prints every legal
play of the roll from the start, one a line, and how many on standard
error.  `--perft N` counts the plays over N turns, each of the 21 rolls
once a turn.

## Playing

Each side rolls one die to start; the higher moves first and plays
both.  After that the dice are rolled for each turn.  A line at a time
the board is shown before each play of yours, with your roll:

```
White to play 6-5> 24/13
White plays 24/13.
Black rolls 3-1.
Black plays 8/5 6/5.
```

A play is typed the way it is written (below); points are counted from
your own home board.  A checker's moves can be typed whole or a die at
a time, `24/13` or `24/18 18/13`, and a blot where a move ends is hit
without a `*`.  A roll with only one legal play is played for you.
Anything else is a command:

    board          show the board
    hint           the engine's best plays of your roll, with how far
                   each falls behind the best
    moves          every legal play of your roll
    pips           both pip counts
    dice DD        set your dice by hand, for a game on a real board
    roll, double   before your roll, when the cube is yours or in the
                   middle; Enter alone rolls
    take, pass     when you are doubled
    undo           take back your last play
    new            a new game
    white, black   play that side against the engine
    both, none     play both sides, or watch the engine play both
    tutorial       the lessons, then a game as white
    xgid [ID]      the position as an XGID, or play from one
    save FILE      the session's games as a .mat file
    help, quit

A game won with the loser having borne off none is a gammon, 2 points;
with a loser's checker also still on the bar or in the winner's home
board, a backgammon, 3 points.

## The cube

Play is for money, with the doubling cube: a game is worth its points
times the cube.  The cube starts in the middle at 1.  Before a roll, a
side may double while the cube is in the middle or its own.  The other
side takes, and owns the cube at twice the value, so only it may double
next; or passes, and loses the game at the value the cube had.  The
cube goes no higher than 64.  There is no Jacoby rule and there are no
beavers.

The engine judges the cube only in a race.  While the sides still meet
it never doubles and always takes.  In a bear-off the table gives the
chance the side to roll wins: the engine doubles from 68%, or from over
even when the other side is sure to be off next roll, and takes while it
keeps 22%, or 25% against a side sure to be off.  In a longer race it
goes by the Keith count: the pips, plus 2 for each checker past the
first on the 1-point, 1 for each past the first on the 2-point, 1 for
each past the third on the 3-point, and 1 for each of the 4-, 5- and
6-points empty; the side to roll adds a seventh of its count.  It
doubles when its count is at most 4 ahead of the other's (3 to
redouble), and takes when the doubler's count is at least 2 ahead.
`h` before a roll, or when doubled, says what the engine would do.

## The tutorial

Eight lessons, played as white: moving, hitting, the bar, making
points, blots and safety, primes, bearing off, and the cube.  Each sets
up a position and a roll, says the idea in a few lines, and asks for a
play, or in the last a take or a pass of a double.  The engine judges
the answer as the coach does: its own play is right, and so is one it
prefers by less than a pip; any other is taken back, with the play the
engine prefers and why, to try again.

On the board the lesson's card is shown first, any key closing it; `?`
shows it again, `h` gives the best plays, and `n` goes to the next
lesson, or after the last to a game against the engine.  The command
`tutorial N` starts at lesson N; `new` leaves the tutorial.  A line at
a time, the card is printed and the answer read; `hint`, `lesson` (the
card again), `next` and `quit` work there.

## Positions and records

A position is written as an XGID, the form eXtreme Gammon and GNU
Backgammon read: `xgid` shows the one on the board, `xgid ID` plays on
from one, and `--xgid ID` starts there.  White is the player at the
bottom.  The cube, its owner, the side to move and a double waiting
are read and written; only money positions are played, so the match
length must be 0.

`save FILE` writes the session's games as a .mat file, a money
session's games laid out as GNU Backgammon exports them, for it or
another program to replay and analyse: each game numbered, the points
before it, the rolls and plays a pair of turns a line, white's on the
left, and the cube's doubles, takes and drops.  Only games played from
the start are written; a lesson or a position set by hand is not.

## On the board

On a terminal `play` fills it with the board: the points in two rows of
twelve with the bar between them, the tray for the checkers borne off
at the right, and the dice of the side to move on its own half.  The
board is drawn from your side, your home board at the bottom right; it
takes 46 columns by 20 rows, and is drawn larger from 72 columns.
`--line` plays a line at a time instead, as when the input is not a
terminal.

Click a checker, then the place it goes: one die away, or both dice
away to move it by both.  The places it can go are marked.  The arrows
and Enter do the same as the mouse, and picking the same checker again
moves it by the larger die.  The play is made once the dice are used.
A play can be typed too, the way it is written, starting with its first
digit.  A play made for a side, the engine's or a roll with only one
play, waits a moment so it can be watched.

    Backspace, u   take back a step, or your last play
    h              the engine's best plays of your roll
    c              the coach on or off
    r, Enter       roll, when you may double first
    d              double
    t, p           take or pass a double
    n              a new game; the points won are counted
    v              turn the board
    :              a command: white, black, both, none, dice DD, new,
                   hint, coach, roll, double, take, pass, tutorial,
                   xgid [ID], save FILE, quit
    ?              the keys
    q              quit

## In a window

```sh
x -l backgammon -- play --window
x -l backgammon -- play --web
```

`--window` plays on a board drawn in a window through SDL3: the wooden
frame, the felt in two halves with the bar between, the points, the
tray at the right, the players and the buttons beside it.  `--web`
draws the same board in a browser tab instead, its address printed,
for when SDL3 is not there; `--listen ADDRESS` is where it listens
(127.0.0.1).  A checker is moved by clicking it and then where it goes,
or by dragging it there; the keys and the buttons do what the
terminal's keys do.  The cube sits in the tray between the rows, moved
toward its owner's side once owned; while you may roll or double, or
are doubled, two buttons below the others give the choice.

The dice tumble onto the felt and land, each checker slides to its
place, and the engine's plays are shown a checker at a time.  The dice
rattle and clack, a checker knocks down, a hit lands harder, and a game
won has its chord.  The sounds are made by x-lang's mixer, and are
heard only where its compiled loops can be built.

## Hints and the coach

`h` (or the Hint button) gives the engine's three best plays of your
roll, each with the pips it scores below the best; in a window the best
is drawn on the board, a gold line from each checker it moves to a ring
where it lands.

The coach judges each play of yours against the engine's.  When the
engine would have played it too it says so; when not, it gives the play
the engine prefers, by how many pips, and why: the part of the score
where the two differ most, whether that is a better point made, a
longer prime, a checker hit, fewer of yours on the bar, fewer shots at
your blots, or the race.  Its word stays under the board until your
next play.  A roll with one play is not judged.  `c` (the Coach button,
marked while it is on, or the command `coach`) turns it off and on.

## The engine

The engine looks one play ahead: of a roll's plays it takes the one
whose position scores best, the other side to roll.  The score is
counted in pips.  Once the sides have passed each other it is the pip
counts' difference; before that it adds what the points held are worth
(the home board's and the bar point most), the longest run of them,
checkers on the bar, and the risk to each blot: the rolls out of 36
that hit it, times the pips a hit costs.

A side with only its home board left counts its race from the
bear-off table: for every way of setting up to 15 checkers on the six
home points, the chances of bearing them all off in each number of
rolls, the best play of every roll taken.  Its rolls to come count at
49/6 pips a roll, to a fraction of a pip, so the engine bears off the
way that leaves the fewest rolls.  The table is solved once on a
machine, the first time a game gets to a race, which takes about a
minute and says so, and is kept in `$XDG_CACHE_HOME/x-backgammon/`
(`~/.cache/x-backgammon/` without it).  Until then a race is counted in
pips.

## Playing GNU Backgammon

`--gnubg ADDRESS` has GNU Backgammon play the sides you do not, in
place of the engine, on the board, in a window or a line at a time.
It runs on its own and is not part of the bundle: started with `gnubg
-t`, the command `external :PORT` has it listen on PORT as an external
player, and the address is `HOST:PORT`, `:PORT` or `PORT` (the host
127.0.0.1 when none is given).  Each choice is asked of it as a FIBS
board line, and it answers its play, whether to double, or whether to
take; how strongly it plays is its own setting.  Hints, the coach and
the lessons are still the engine's.

When nothing answers at the address, or what answers is not gnubg,
`play` stops with a message.  When gnubg stops answering in a game, or
answers what is not a choice of the position, the engine makes that
choice and the message says so.

## The rules played

Every roll is played with as many dice as can be used.  When only one
of two dice can be used, it is the larger if the larger can be.  A
checker on the bar enters before any other moves.  A checker bears off
by its exact number, or by a larger number from the highest point
held, once every checker is in the home board.  A roll that cannot be
played at all is no move.

## Plays

A play is written the usual way: the checkers' moves highest first,
`bar` and `off` for the bar and the tray, `*` after a point where a
blot was hit, and `(2)` after a move made twice: `24/13`, `8/5 6/5`,
`bar/22* 13/9`, `6/off(2)`.  Two plays that leave the same position are
one play.

## The board

```
  13 14 15 16 17 18      19 20 21 22 23 24
 +------------------+---+------------------+
 | O           X    |   | X              O |
 | O           X    |   | X              O |
 | O           X    |   | X                |
 | O                |   | X                |
 | O                |   | X                |
 |                  |BAR|                  |
 | X                |   | O                |
 | X                |   | O                |
 | X           O    |   | O                |
 | X           O    |   | O              X |
 | X           O    |   | O              X |
 +------------------+---+------------------+
  12 11 10  9  8  7       6  5  4  3  2  1
 O white  pips 167  off 0
 X black  pips 167  off 0
 white to move
```

The board is drawn from white's side: white's checkers are `O`, its
home board at the bottom right; black's are `X`.  A point shows five
checkers at most, the fifth replaced by the count past five.
