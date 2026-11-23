; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/sound.x -- the game heard in a window
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The sounds of the board, made by x/audio/mixer from the voices below:
; the dice rattling in the cup and landing, a checker put down, a
; checker hit, one borne off, and a game won.  Each is rendered once when
; the window opens, and queued whole on a stream of its own kind when it
; is heard: the dice on one, the checkers on another, the rest on a
; third, so a checker put down never waits behind the dice.
;
; There is no sound when the mixer's compiled loops cannot be built:
; without them rendering is far too slow to keep up.

(module backgammon/sound)

(import x/audio/mixer)
(import x/type/vector)
(import x/core/doors int+ int*)

(def %rate 44100)

; A knock of wood: a tone at HZ falling away in MS, under a short burst
; of noise through a band at CUT hertz, from AT, at GAIN percent.
(def %knock
  (fn (_ hz ms cut at gain)
    (list (list (list (lit wave) (lit triangle)) (list (lit hz) hz) (list (lit env) (list 0 0) (list 1 70) (list ms 0))
                (list (lit at) at) (list (lit gain) gain))
          (list (list (lit wave) (lit noise)) (list (lit env) (list 0 0) (list 1 80) (list 28 0))
                (list (lit cutoff) (list 0 cut)) (list (lit res) 35) (list (lit pass) (lit band))
                (list (lit at) at) (list (lit gain) gain)))))

(def %voices
  (fn (_ name)
    (match
      ((eq? name (lit rattle))
        (List fold (fn (_ acc k) (List append acc (%knock (int+ 700 (int* 60 k)) 22 (int+ 2400 (int* 300 k)) (int* 62 k) (int+ 30 (int* 5 k)))))
          () (List range 0 7)))
      ((eq? name (lit land)) (List append (%knock 420 60 1900 0 90) (%knock 520 45 2300 85 60)))
      ((eq? name (lit place)) (%knock 300 80 1500 0 85))
      ((eq? name (lit hit))
        (List append (%knock 240 140 1200 0 100)
          (list (list (list (lit wave) (lit triangle)) (list (lit hz) 160) (list (lit bend) (list 0 0) (list 160 -900))
                      (list (lit env) (list 0 0) (list 3 80) (list 200 0))))))
      ((eq? name (lit off))
        (list (list (list (lit hz) 880) (list (lit env) (list 0 0) (list 4 40) (list 160 0)))
              (list (list (lit hz) 1320) (list (lit env) (list 0 0) (list 4 20) (list 120 0)) (list (lit at) 40))))
      ((eq? name (lit win))
        (List map
          (fn (_ n) (list (list (lit wave) (lit triangle)) (list (lit note) (first n))
                          (list (lit env) (list 0 0) (list 12 60) (list 900 0)) (list (lit at) (rest n))))
          (list (pair "C5" 0) (pair "E5" 130) (pair "G5" 260) (pair "C6" 390))))
      (#t ()))))

(def %names (list (lit rattle) (lit land) (lit place) (lit hit) (lit off) (lit win)))

; NAME's sound rendered: (REGION . BYTES).
(def sound-render (fn (_ name) (Mixer render %rate (%voices name) ())))

; The stream a sound of NAME is heard on: 0 the dice, 1 the checkers, 2
; the rest.
(def %stream-of
  (fn (_ name) (match ((if (eq? name (lit rattle)) #t (eq? name (lit land))) 0)
                      ((eq? name (lit win)) 2) (#t 1))))

; The sounds for FRONT, Sdl or Web: (FRONT STREAMS SOUNDS), SOUNDS an
; alist of each name's rendered frames; () when there is no sound.
(def sound-make
  (fn (_ front)
    (guard (e ())
      (if (not (Mixer jit!)) ()
        (list front
              (List map (fn (_ i) (front audio-open %rate 2)) (List range 0 3))
              (List map (fn (_ n) (pair n (sound-render n))) %names))))))

; NAME heard: the dice's rattle drops what the dice stream had left.
(def sound-play!
  (fn (_ s name)
    (unless (null? s)
      ((fn (_ front stream r)
         (when (eq? name (lit rattle)) (front audio-clear! stream))
         (unless (null? r) (front audio-put! stream (first (rest r)) (rest (rest r)))))
       (first s) (List ref (%stream-of name) (first (rest s))) (List find (fn (_ x) (eq? (first x) name)) (List ref 2 s))))))

(def sound-close!
  (fn (_ s) (unless (null? s) (List for-each (fn (_ st) ((first s) audio-close st)) (first (rest s))))))

(provide backgammon/sound sound-make sound-play! sound-close! sound-render)
