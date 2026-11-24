; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/game.x -- a game: the position, the dice, the cube, what was played
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A game is a Vector: the position, seen from the side to move; the dice
; it is to play, (D1 D2), or () while it has still to roll; what came
; before, a list of (POSITION DICE PLAY CUBE OWNER) the latest first;
; the dice's source; the result once the game is over, (WINNER POINTS
; KIND), else (); the cube's value; its owner, the side that may double
; next, or () while it is in the middle; and whether the side to move
; has doubled and the other is to take or pass.
;
; The first roll is one die each, rolled again while they match; the
; higher die moves first and plays both.  After that a side that may
; double chooses before it rolls: to roll, or to double.  A double
; taken doubles the cube, which the taker then owns; a double passed
; loses the game at the cube's value.  The cube goes no higher than 64.
; A game won is worth KIND times the cube, KIND 1 for a single game, 2
; for a gammon and 3 for a backgammon; KIND is 0 for a double passed.

(module backgammon/game)

(import x/type/vector)
(import x/num/random)
(import backgammon/board WHITE BLACK CHECKERS BAR pos-make pos-start pos-swap pos-turn pos-me pos-opp
  pos-me-off pos-opp-off plays)
(import x/core/doors int+ int- int* int< int=)

(def %g-pos 0)
(def %g-dice 1)
(def %g-past 2)
(def %g-rnd 3)
(def %g-result 4)
(def %g-cube 5)
(def %g-owner 6)
(def %g-offered 7)

(def CUBE-MAX 64)

(def game-pos (fn (_ g) (Vector ref %g-pos g)))
(def game-dice (fn (_ g) (Vector ref %g-dice g)))
(def game-past (fn (_ g) (Vector ref %g-past g)))
(def game-result (fn (_ g) (Vector ref %g-result g)))
(def game-over? (fn (_ g) (not (null? (game-result g)))))
(def game-turn (fn (_ g) (pos-turn (game-pos g))))
(def game-cube (fn (_ g) (Vector ref %g-cube g)))
(def game-owner (fn (_ g) (Vector ref %g-owner g)))
(def game-offered? (fn (_ g) (Vector ref %g-offered g)))

; #t when the side to move has still to roll, and may double first.
(def game-to-roll? (fn (_ g) (if (game-over? g) #f (if (game-offered? g) #f (null? (game-dice g))))))

; #t when SIDE may double G's cube: it is in the middle or SIDE's, and
; below its highest.
(def game-may-double?
  (fn (_ g side)
    (if (int< (game-cube g) CUBE-MAX) ((fn (_ o) (if (null? o) #t (int= o side))) (game-owner g)) #f)))

(def %die (fn (_ rnd) (int+ 1 (rnd int 6))))

; Two dice from G's source.
(def game-throw (fn (_ g) ((fn (_ rnd) (list (%die rnd) (%die rnd))) (Vector ref %g-rnd g))))

(def %game (fn (_ p dice rnd) (Vector of p dice () rnd () 1 () #f)))

; A new game drawing its dice from RND, its first roll made.
(def game-new
  (fn (_ rnd)
    (def first-roll
      (fn (self) ((fn (_ w b) (if (int= w b) (self) (list w b))) (%die rnd) (%die rnd))))
    (def r (first-roll))
    (def turn (if (int< (%2nd r) (first r)) WHITE BLACK))
    (%game (pos-make turn (%start-men) (%start-men)) r rnd)))

(def %2nd (fn (_ l) (first (rest l))))
(def %start-men (fn (_) (list (pair 24 2) (pair 13 5) (pair 8 3) (pair 6 5))))

; A game from position P, the side to move to play DICE, (D1 D2), or to
; roll when DICE is (), the dice after drawn from RND: a position set up
; by hand.
(def game-at (fn (_ p dice rnd) (%game p dice rnd)))

; G's dice replaced by D1 D2, as when they are set by hand.
(def game-set-dice! (fn (_ g d1 d2) (Vector set! %g-dice (list d1 d2) g) g))

; The kind of game won by the side that has just borne off its last
; checker in P: 3, a backgammon, when the loser has none off and a
; checker on the bar or in the winner's home board, 2, a gammon, when it
; has none off, else 1.
(def %kind
  (fn (_ p)
    (match
      ((int< 0 (pos-opp-off p)) 1)
      ((int< 0 ((fn (self i n) (if (int< 24 i) n (self (int+ i 1) (int+ n (pos-opp p i))))) 18 0)) 3)
      (#t 2))))

(def %over! (fn (_ g winner kind) (Vector set! %g-result (list winner (int* (if (int= kind 0) 1 kind) (game-cube g)) kind) g)))

; G with the side to move's play PL made: the other side to roll, or to
; play a roll already thrown when it may not double; or the game over.
(def game-play!
  (fn (_ g pl)
    (def p (game-pos g))
    (def after (rest pl))
    (Vector set! %g-past (pair (list p (game-dice g) pl (game-cube g) (game-owner g)) (game-past g)) g)
    (if (int= (pos-me-off after) CHECKERS)
      (do (Vector set! %g-pos after g)
          (Vector set! %g-dice () g)
          (%over! g (pos-turn p) (%kind after)))
      (do (Vector set! %g-pos (pos-swap after) g)
          (Vector set! %g-dice (if (game-may-double? g (pos-turn (pos-swap after))) () (game-throw g)) g)))
    g))

; G's cube set: its VALUE, its OWNER, () for the middle, and whether a
; double is OFFERED, as when a position is read.
(def game-set-cube!
  (fn (_ g value owner offered)
    (Vector set! %g-cube value g)
    (Vector set! %g-owner owner g)
    (Vector set! %g-offered offered g)
    g))

; G with the side to move's dice thrown.
(def game-roll! (fn (_ g) (Vector set! %g-dice (game-throw g) g) g))

; G with the side to move doubling: the other side to take or pass.
(def game-double! (fn (_ g) (Vector set! %g-offered #t g) g))

; G with the double taken: the cube doubled and the taker's, the doubler
; to roll.
(def game-take!
  (fn (_ g)
    (Vector set! %g-cube (int* 2 (game-cube g)) g)
    (Vector set! %g-owner (int- 1 (game-turn g)) g)
    (Vector set! %g-offered #f g)
    (game-roll! g)))

; G with the double passed: the game the doubler's at the cube's value.
(def game-pass!
  (fn (_ g)
    (Vector set! %g-offered #f g)
    (%over! g (game-turn g) 0)
    g))

; G as it was before the last play by a side that SIDE? is true of: #f
; when there is none.
(def game-undo!
  (fn (_ g side?)
    (def back
      (fn (self past)
        (match
          ((null? past) ())
          ((side? (pos-turn (first (first past)))) past)
          (#t (self (rest past))))))
    (def past (back (game-past g)))
    (if (null? past) #f
      ((fn (_ e)
         (Vector set! %g-pos (first e) g)
         (Vector set! %g-dice (%2nd e) g)
         (Vector set! %g-cube (List ref 3 e) g)
         (Vector set! %g-owner (List ref 4 e) g)
         (Vector set! %g-offered #f g)
         (Vector set! %g-past (rest past) g)
         (Vector set! %g-result () g)
         g)
       (first past)))))

; The plays of the dice G is to play.
(def game-plays (fn (_ g) ((fn (_ d) (plays (game-pos g) (first d) (%2nd d))) (game-dice g))))

(provide backgammon/game
  CUBE-MAX game-pos game-dice game-past game-result game-over? game-turn game-cube game-owner game-offered?
  game-to-roll? game-may-double? game-throw game-new game-at game-set-dice! game-set-cube! game-play! game-roll! game-double!
  game-take! game-pass! game-undo! game-plays)
