; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module backgammon/cli)

(import x/sys/posix)
(import x/sys/opts)
(import x/core/doors int< int- str-byte-len str-byte-ref io-display-to-str)
(import backgammon/board pos-start plays play-text perft)
(import backgammon/show board-text)

(def backgammon-version "0.1.0")

(def backgammon-options
  (Opts declare "x -l backgammon --" "[OPTIONS]"
    "Backgammon: the board, the legal plays of a roll, and counts of them."
    (list (Opts flag "-b" "--board" "Print the starting board")
          (Opts arg "-r" "--roll" "DD" "Print every legal play of the roll DD (31, 66) from the start")
          (Opts arg "-p" "--perft" "N" "Count the plays over N turns from the start, each of the 21 rolls a turn")
          (Opts flag "-V" "--version" "Print the version and exit")
          (Opts flag "-h" "--help" "Print this help and exit"))
    (pair (lit help) #f)))

(def %say (fn (_ fd text) (Sys fd-write fd text)))

(def %to-int
  (fn (_ s) (guard (e ()) ((prim-ref (lit convert) (lit to)) s (Type named INTEGER) 10))))

; The die at byte I of S, 1 to 6, or ().
(def %die
  (fn (_ s i) ((fn (_ d) (if (if (int< 0 d) (int< d 7) #f) d ())) (int- (str-byte-ref s i) 48))))

; "31" as (3 1), or ().
(def %roll
  (fn (_ s)
    (if (int< (str-byte-len s) 2) ()
      (if (int< 2 (str-byte-len s)) ()
        ((fn (_ a b) (if (if (null? a) #t (null? b)) () (list a b))) (%die s 0) (%die s 1))))))

(def %print-plays
  (fn (_ r)
    (def ps (plays (pos-start) (first r) (first (rest r))))
    (List for-each (fn (_ pl) (%say 1 (Str8 append (play-text pl) "\n"))) ps)
    (%say 2 (Str8 append (io-display-to-str (List length ps)) " plays\n"))
    0))

; ARGS, the command line after the launcher's options: the exit status.
(def backgammon-main
  (fn (_ args)
    (def opts (Opts parse backgammon-options args))
    (def roll (Opts value opts "-r"))
    (def depth (Opts value opts "-p"))
    (match
      ((not (null? (Opts unknown opts)))
        (do (%say 2 (Str8 append "x-backgammon: no such option: " (Opts unknown opts) "\n" (Opts usage backgammon-options))) 2))
      ((Opts on? opts "-h") (do (%say 1 (Opts usage backgammon-options)) 0))
      ((Opts on? opts "-V") (do (%say 1 (Str8 append "x-backgammon " backgammon-version "\n")) 0))
      ((Opts on? opts "-b") (do (%say 1 (board-text (pos-start))) 0))
      ((not (null? roll))
        (if (null? (%roll roll)) (do (%say 2 "x-backgammon: --roll takes two dice, 31 or 66\n") 2)
          (%print-plays (%roll roll))))
      ((not (null? depth))
        (if (null? (%to-int depth)) (do (%say 2 "x-backgammon: --perft takes a number\n") 2)
          (do (%say 1 (Str8 append (io-display-to-str (perft (pos-start) (%to-int depth))) "\n")) 0)))
      (#t (do (%say 1 (Opts usage backgammon-options)) 0)))))

(provide backgammon/cli backgammon-main backgammon-version)
