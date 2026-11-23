; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
(module backgammon/cli)

(import x/sys/posix)
(import x/type/vector)
(import x/sys/opts)
(import x/sys/file)
(import x/repl/term)
(import x/repl/line)
(import x/num/random)
(import x/core/doors int< int- int+ int= str-make str-byte-len str-byte-ref str-byte-sub io-display-to-str)
(import backgammon/board pos-start plays play-text perft)
(import backgammon/show board-text)
(import backgammon/play play-run side-word)
(import backgammon/app app-run)

(def backgammon-version "0.1.0")

(def backgammon-options
  (Opts declare "x -l backgammon --" "[OPTIONS] [play]"
    "Backgammon against the engine: on the board, filling the terminal, or a\nline at a time; the legal plays of a roll, and counts of them."
    (list (Opts arg "-s" "--side" "SIDE" "The side you play: white (the default), black, both or none")
          (Opts arg "-S" "--seed" "N" "Roll the dice from seed N; the seed is printed when none is given")
          (Opts flag "-L" "--line" "Play a line at a time, not on the board")
          (Opts flag "-b" "--board" "Print the starting board")
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

; --- input --------------------------------------------------------------------
;
; On a terminal a line is read with the line editor; otherwise fd 0 is
; read in blocks and cut at newlines, the prompt written first.

(def %in (Vector of "" #f))

(def %newline-at
  (fn (_ s)
    (def n (str-byte-len s))
    ((fn (self i) (if (int< i n) (if (int= (str-byte-ref s i) 10) i (self (int+ i 1))) -1)) 0)))

(def %fill!
  (fn (_)
    (def buf (str-make 4096))
    (def n (File read 0 buf 4096))
    (if (if (number? n) (int< 0 n) #f)
      (Vector set! 0 (Str8 append (Vector ref 0 %in) (str-byte-sub buf 0 n)) %in)
      (Vector set! 1 #t %in))))

(def %strip-cr
  (fn (_ s)
    (def n (str-byte-len s))
    (if (if (int< 0 n) (= (str-byte-ref s (int- n 1)) 13) #f) (str-byte-sub s 0 (int- n 1)) s)))

(def %pipe-line
  (fn (self)
    (def s (Vector ref 0 %in))
    (def nl (%newline-at s))
    (match
      ((int< -1 nl)
        (do (Vector set! 0 (str-byte-sub s (int+ nl 1) (int- (str-byte-len s) (int+ nl 1))) %in)
            (%strip-cr (str-byte-sub s 0 nl))))
      ((Vector ref 1 %in)
        (if (= (str-byte-len s) 0) () (do (Vector set! 0 "" %in) (%strip-cr s))))
      (#t (do (%fill!) (self))))))

(def %tty-line
  (fn (_ prompt)
    (def r (Line read prompt))
    (match ((str? r) r) ((eq? r (lit eof)) ()) (#t ""))))

(def %io
  (fn (_ tty)
    (list (if tty %tty-line (fn (_ prompt) (%say 1 (Str8 append prompt "\n")) (%pipe-line)))
          (fn (_ text) (%say 1 text)))))

(def %play
  (fn (_ opts)
    (def side (side-word (Opts value opts "-s" "white")))
    (def given (Opts value opts "-S"))
    (def seed (if (null? given) (first (Sys time-of-day)) (%to-int given)))
    (match
      ((null? side) (do (%say 2 "x-backgammon: --side takes white, black, both or none\n") 2))
      ((null? seed) (do (%say 2 "x-backgammon: --seed takes a number\n") 2))
      (#t
        (do (when (null? given) (%say 2 (Str8 append "x-backgammon: seed " (io-display-to-str seed) "\n")))
            ; the launcher parks the caller's stdin on fd 3 while its boot
            ; stream holds fd 0; it is taken back, as x-chess and x-grep do
            (guard (e ()) (do (Sys dup2 3 0) (Sys close 3)))
            ((fn (_ tty rnd)
               (if (if tty (not (Opts on? opts "-L")) #f) (app-run rnd side) (play-run (%io tty) rnd side)))
             (if (Term tty? 0) (Sys isatty 1) #f) (Random sw seed)))))))

; ARGS, the command line after the launcher's options: the exit status.
(def backgammon-main
  (fn (_ args)
    (def opts (Opts parse backgammon-options args))
    (def words (Opts operands opts))
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
      ((null? words) (%play opts))
      ((str=? (first words) "play") (%play opts))
      (#t (do (%say 2 (Str8 append "x-backgammon: no such command: " (first words) "\n" (Opts usage backgammon-options))) 2)))))

(provide backgammon/cli backgammon-main backgammon-version)
