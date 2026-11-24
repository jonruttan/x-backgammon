; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/lesson.x -- the tutorial's lessons
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Each lesson sets up a position and a roll, says one idea in a few
; lines, and asks for a play; the engine judges it, as the coach does.
; The last lesson is a double to take or pass.  The fronts, the board
; (backgammon/tui) and the line session (backgammon/play), show them.
;
; A lesson is (TITLE LINES ASK TURN ME OPP DICE): the side to move and
; its checkers and the other side's, each as (POINT . COUNT) counted from
; its own home board, 25 the bar; DICE () for the double, the side to
; move having doubled.

(module backgammon/lesson)

(import x/core/doors int+ int< int= io-display-to-str str-byte-len str-byte-sub)
(import backgammon/board WHITE BLACK pos-make play-text)
(import backgammon/coach coach-judge)
(import backgammon/cube cube-take?)
(import backgammon/game game-at game-pos game-dice game-double!)

; XS, POINT COUNT ..., as a list of (POINT . COUNT).
(def %men (fn (self xs) (if (null? xs) () (pair (pair (first xs) (first (rest xs))) (self (rest (rest xs)))))))

(def %start (%men (list 24 2 13 5 8 3 6 5)))

(def %lessons
  (list
    (list "Moving"
      (list "Each side moves its 15 checkers around the"
            "board to its home board, then bears them"
            "off.  You are white: you move from 24 down"
            "to 1, your home board 1 to 6, bottom right."
            "Each die moves a checker that many points,"
            "to a point the other side does not hold"
            "with two or more.  One checker may take"
            "both dice.")
      "White to play 6-5: get a back checker safe."
      WHITE %start %start (list 6 5))
    (list "Hitting"
      (list "A single checker on a point is a blot.  A"
            "checker landing on the other side's blot"
            "hits it: the blot goes to the bar, to come"
            "in again from the start of the board."
            "Black has left a blot on your 18-point.")
      "White to play 6-4: hit, and keep going."
      WHITE %start (%men (list 24 2 13 4 8 3 7 1 6 5)) (list 6 4))
    (list "The bar"
      (list "A checker on the bar comes in before any"
            "other moves, on the point of black's home"
            "board its die names: a 3 enters on your"
            "22-point.  Black holds your 19, 20 and 21,"
            "so a 6, a 5 or a 4 cannot enter.")
      "White to play 6-3 from the bar."
      WHITE (%men (list 25 1 24 1 13 5 8 3 6 5)) (%men (list 24 2 13 3 8 2 6 4 5 2 4 2)) (list 6 3))
    (list "Making points"
      (list "Two or more checkers on a point hold it:"
            "the other side cannot land there.  Points"
            "in your home board are worth the most, as"
            "they keep a checker on the bar from coming"
            "in.  Bring two checkers to one point to"
            "make it.")
      "White to play 3-1: make a point at home."
      WHITE %start %start (list 3 1))
    (list "Blots and safety"
      (list "A blot can be hit by any checker of the"
            "other side's that a roll takes there."
            "Black's back checkers on your 1-point are"
            "six away from your blot on the 7-point."
            "A second checker on a blot makes it safe.")
      "White to play 6-3: cover it, leave few shots."
      WHITE (%men (list 24 2 13 4 8 3 7 1 6 5)) %start (list 6 3))
    (list "Primes"
      (list "Points made in a row are a prime.  A"
            "checker behind a prime of six cannot get"
            "past it, and the longer the prime the"
            "harder it is to get out.  Black has a"
            "checker on your 1-point behind your 8, 7,"
            "6 and 5.")
      "White to play 5-4: make the prime longer."
      WHITE (%men (list 13 4 9 1 8 3 7 2 6 3 5 2)) (%men (list 24 1 13 5 8 3 6 4 5 2)) (list 5 4))
    (list "Bearing off"
      (list "Once all your checkers are in your home"
            "board they are borne off: a die takes off"
            "a checker on the point it names.  A die"
            "larger than your highest point takes one"
            "off the highest; otherwise a die with"
            "nothing to take off moves a checker on.")
      "White to play 6-4: bear off all you can."
      WHITE (%men (list 5 1 3 1 2 1 1 1)) (%men (list 6 5 5 5 4 5)) (list 6 4))
    (list "The cube"
      (list "A game is played for points, times the"
            "doubling cube.  Before its roll a side may"
            "double.  The other side takes, and owns"
            "the cube, so only it may double next; or"
            "passes, and loses at the value before the"
            "double.  Take when you win at least one"
            "game in four.  Black leads the race by 9.")
      "Black doubles to 2: take or pass."
      BLACK (%men (list 8 3 6 4 5 4 4 4)) (%men (list 9 3 7 3 6 3 5 3 4 3)) ())))

(def %ref (fn (_ i) (List ref i %lessons)))

; How many lessons there are.
(def lesson-count (List length %lessons))

; Lesson I's title, counted: "Lesson 3 of 8: The bar".
(def lesson-title
  (fn (_ i) (Str8 append "Lesson " (io-display-to-str (int+ i 1)) " of " (io-display-to-str lesson-count) ": " (first (%ref i)))))

; Lesson I's lines: what it says, and what it asks.
(def lesson-lines (fn (_ i) (List ref 1 (%ref i))))
(def lesson-ask (fn (_ i) (List ref 2 (%ref i))))

; #t when lesson I is a double to take or pass.
(def lesson-cube? (fn (_ i) (null? (List ref 6 (%ref i)))))

; Lesson I's game, its dice from RND after the lesson's roll: the double
; offered for the cube's lesson.
(def lesson-game
  (fn (_ i rnd)
    (def l (%ref i))
    (def g (game-at (pos-make (List ref 3 l) (List ref 4 l) (List ref 5 l)) (List ref 6 l) rnd))
    (when (lesson-cube? i) (game-double! g))
    g))

; PLAY of G's dice judged: (RIGHT . TEXT).  A play the engine's beats by
; less than a pip is right.
(def lesson-judge
  (fn (_ g play)
    (def d (game-dice g))
    (def j (coach-judge (game-pos g) (first d) (first (rest d)) play))
    (def said (fn (_ t) (str-byte-sub t 7 (int+ -7 (str-byte-len t)))))
    (match
      ((null? j) (pair #t "Right: it is the only play."))
      ((int= (first j) 0) (pair #t "Right: that is the engine's play."))
      ((int< (first j) 1) (pair #t (Str8 append "Right, nearly: " (said (rest j)))))
      (#t (pair #f (Str8 append "Not the best: " (said (rest j))))))))

; TAKE, #t for a take and #f for a pass, of the double offered in G
; judged: (RIGHT . TEXT).
(def lesson-judge-cube
  (fn (_ g take)
    (def best (cube-take? g))
    (pair (eq? take best)
      (match
        ((if take best #f) "Right: take.  You win more than one game in four from here.")
        (best "Not the best: take.  You win more than one game in four from here, so a take loses less.")
        (take "Not the best: pass.  You win less than one game in four from here.")
        (#t "Right: pass.  You win less than one game in four from here.")))))

(provide backgammon/lesson
  lesson-count lesson-title lesson-lines lesson-ask lesson-cube? lesson-game lesson-judge lesson-judge-cube)
