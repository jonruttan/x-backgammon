# x-backgammon

Backgammon on x-lang.  This is the start: the position, the legal plays
of a roll, the board as text, and a count of plays over turns that
checks the move generator as perft checks a chess engine's.

## Run

```sh
x -l backgammon -- --board
x -l backgammon -- --roll 31
x -l backgammon -- --perft 1
```

`--board` prints the starting board.  `--roll DD` prints every legal
play of the roll from the start, one a line, and how many on standard
error.  `--perft N` counts the plays over N turns, each of the 21 rolls
once a turn.

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
