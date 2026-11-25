; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/opponent.x -- who plays the sides no person does
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; An opponent makes the three choices of a side: its play of the dice,
; whether to double, and whether to take a double.  Each is asked of a
; game G with the side to move the one choosing, except the take, asked
; while the side to move has doubled.  The engine is one opponent; a
; program reached over a socket is another, its note saying why the
; engine took over a choice from it.

(module backgammon/opponent)

(import x/type/vector)
(import backgammon/eval eval-best)
(import backgammon/cube cube-double? cube-take?)
(import backgammon/game game-pos game-dice)

; An opponent: a Vector of its name, its PLAY, DOUBLE? and TAKE? choices
; of a game, and NOTE!, which answers the message waiting to be said, or
; (), and clears it.
(def opponent-make (fn (_ name play double? take? note!) (Vector of name play double? take? note!)))

(def opponent-name (fn (_ o) (Vector ref 0 o)))
(def opponent-play (fn (_ o g) ((Vector ref 1 o) g)))
(def opponent-double? (fn (_ o g) ((Vector ref 2 o) g)))
(def opponent-take? (fn (_ o g) ((Vector ref 3 o) g)))
(def opponent-note! (fn (_ o) ((Vector ref 4 o))))

(def %engine-play (fn (_ g) ((fn (_ d) (eval-best (game-pos g) (first d) (first (rest d)))) (game-dice g))))

; The engine: its best play by its evaluation, and the cube by its
; bear-off table.
(def opponent-engine (fn (_) (opponent-make "the engine" %engine-play cube-double? cube-take? (fn (_) ()))))

(provide backgammon/opponent
  opponent-make opponent-engine opponent-name opponent-play opponent-double? opponent-take? opponent-note!)
