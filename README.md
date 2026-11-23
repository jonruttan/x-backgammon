# x-backgammon

Backgammon on x-lang: a game against the engine a line at a time, the
board as text, the legal plays of a roll, and a count of plays over
turns that checks the move generator as perft checks a chess engine's.

## Run

```sh
x -l backgammon -- play
x -l backgammon -- play --side black --seed 7
x -l backgammon -- --board
x -l backgammon -- --roll 31
x -l backgammon -- --perft 1
```

`play` is a game against the engine, on the board when run on a
terminal (below); `--side` is the side you play,
white (the default), black, both, or none to watch the engine play
itself.  The dice are drawn from a seed, printed at the start when
`--seed N` does not give one, so a game can be played again.
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
    undo           take back your last play
    new            a new game
    white, black   play that side against the engine
    both, none     play both sides, or watch the engine play both
    help, quit

A game won with the loser having borne off none is a gammon, 2 points;
with a loser's checker also still on the bar or in the winner's home
board, a backgammon, 3 points.  There is no doubling cube yet.

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
    n              a new game; the games won are counted
    v              turn the board
    :              a command: white, black, both, none, dice DD, new,
                   hint, quit
    ?              the keys
    q              quit

## The engine

The engine looks one play ahead: of a roll's plays it takes the one
whose position scores best, the other side to roll.  The score is
counted in pips.  Once the sides have passed each other it is the pip
counts' difference; before that it adds what the points held are worth
(the home board's and the bar point most), the longest run of them,
checkers on the bar, and the risk to each blot: the rolls out of 36
that hit it, times the pips a hit costs.

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
