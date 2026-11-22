; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/game.x -- a game: the position, the dice, what was played
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A game is a Vector: the position, seen from the side to move; the dice
; it is to play, (D1 D2); what came before, a list of (POSITION DICE
; PLAY) the latest first; the dice's source; and the result once the game
; is over, (WINNER POINTS), else ().
;
; The first roll is one die each, rolled again while they match; the
; higher die moves first and plays both.

(module backgammon/game)

(import x/type/vector)
(import x/num/random)
(import backgammon/board WHITE BLACK CHECKERS BAR pos-make pos-start pos-swap pos-turn pos-me pos-opp
  pos-me-off pos-opp-off plays)
(import x/core/doors int+ int- int< int=)

(def %g-pos 0)
(def %g-dice 1)
(def %g-past 2)
(def %g-rnd 3)
(def %g-result 4)

(def game-pos (fn (_ g) (Vector ref %g-pos g)))
(def game-dice (fn (_ g) (Vector ref %g-dice g)))
(def game-past (fn (_ g) (Vector ref %g-past g)))
(def game-result (fn (_ g) (Vector ref %g-result g)))
(def game-over? (fn (_ g) (not (null? (game-result g)))))
(def game-turn (fn (_ g) (pos-turn (game-pos g))))

(def %die (fn (_ rnd) (int+ 1 (rnd int 6))))

; Two dice from G's source.
(def game-throw (fn (_ g) ((fn (_ rnd) (list (%die rnd) (%die rnd))) (Vector ref %g-rnd g))))

; A new game drawing its dice from RND, its first roll made.
(def game-new
  (fn (_ rnd)
    (def first-roll
      (fn (self) ((fn (_ w b) (if (int= w b) (self) (list w b))) (%die rnd) (%die rnd))))
    (def r (first-roll))
    (def turn (if (int< (%2nd r) (first r)) WHITE BLACK))
    (Vector of (pos-make turn (%start-men) (%start-men)) r () rnd ())))

(def %2nd (fn (_ l) (first (rest l))))
(def %start-men (fn (_) (list (pair 24 2) (pair 13 5) (pair 8 3) (pair 6 5))))

; G's dice replaced by D1 D2, as when they are set by hand.
(def game-set-dice! (fn (_ g d1 d2) (Vector set! %g-dice (list d1 d2) g) g))

; The points a game won by the side that has just borne off its last
; checker in P is worth: 3 when the loser has none off and a checker on
; the bar or in the winner's home board, 2 when it has none off, else 1.
(def %points
  (fn (_ p)
    (match
      ((int< 0 (pos-opp-off p)) 1)
      ((int< 0 ((fn (self i n) (if (int< 24 i) n (self (int+ i 1) (int+ n (pos-opp p i))))) 18 0)) 3)
      (#t 2))))

; G with the side to move's play PL made: the other side to roll next, or
; the game over.
(def game-play!
  (fn (_ g pl)
    (def p (game-pos g))
    (def after (rest pl))
    (Vector set! %g-past (pair (list p (game-dice g) pl) (game-past g)) g)
    (if (int= (pos-me-off after) CHECKERS)
      (do (Vector set! %g-pos after g)
          (Vector set! %g-dice () g)
          (Vector set! %g-result (list (pos-turn p) (%points after)) g))
      (do (Vector set! %g-pos (pos-swap after) g)
          (Vector set! %g-dice (game-throw g) g)))
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
      (do (Vector set! %g-pos (first (first past)) g)
          (Vector set! %g-dice (%2nd (first past)) g)
          (Vector set! %g-past (rest past) g)
          (Vector set! %g-result () g)
          g))))

; The plays of the dice G is to play.
(def game-plays (fn (_ g) ((fn (_ d) (plays (game-pos g) (first d) (%2nd d))) (game-dice g))))

(provide backgammon/game
  game-pos game-dice game-past game-result game-over? game-turn game-throw game-new
  game-set-dice! game-play! game-undo! game-plays)
