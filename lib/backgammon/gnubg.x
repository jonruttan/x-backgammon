; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/gnubg.x -- GNU Backgammon as the opponent
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; GNU Backgammon answers as an external player once told `external :PORT`
; at its command line: it listens on PORT, and to each line of a position
; in the board format of FIBS, the First Internet Backgammon Server, it
; answers one line.  With dice in the position the answer is its play,
; "24/18 13/11", the bar 25 and off 0, a hit marked "*", nothing when
; there is no play; with none it is "double" or "roll"; with the double
; offered, the position seen from the doubler, it is "take", "beaver" or
; "drop".  `version` answers four lines, "Interface: 2" first.
;
; The board line is the side to move's: "board:You:gnubg:" and then match
; length, the scores, 26 places, the turn, both sides' dice, the cube, who
; may double, whether a double is offered, colour, direction, home, bar,
; the checkers off and on the bar of each side, and four flags.  Places 1
; to 24 are the side to move's points, its checkers counted up and the
; other side's down; place 25 is its bar and place 0 the other's.  A game
; is a money game, of match length 0.
;
; When gnubg cannot be reached, gives no answer in the wait, or answers
; what is not a choice of the position, the engine makes that choice, and
; the opponent's note says so.

(module backgammon/gnubg)

(import x/type/vector)
(import x/sys/socket)
(import x/sys/posix)
(import x/core/doors int+ int- int* int/ int< int= io-display-to-str str-byte-len str-byte-ref str-byte-sub)
(import backgammon/board BAR pos-me pos-opp pos-me-off pos-opp-off play-find)
(import backgammon/game game-pos game-dice game-cube game-turn game-offered? game-may-double?)
(import backgammon/opponent opponent-make opponent-engine opponent-play opponent-double? opponent-take?)

(def %n io-display-to-str)
(def %flag (fn (_ b) (if b "1" "0")))

; The places of the board line for P, 0 to 25.
(def %places
  (fn (_ p)
    (def at (fn (_ k) (int- (pos-me p (int- k 1)) (pos-opp p (int- 24 k)))))
    (List append (list (int- 0 (pos-opp p BAR))) (List map at (List range 1 25)) (list (pos-me p BAR)))))

; G as a board line, seen from the side to move.
(def gnubg-board
  (fn (_ g)
    (def p (game-pos g))
    (def d (if (null? (game-dice g)) (list 0 0) (game-dice g)))
    (def me (game-turn g))
    (Str8 append "board:You:gnubg:"
      (Str8 join ":"
        (List append
          (list "0" "0" "0")
          (List map %n (%places p))
          (list "1" (%n (first d)) (%n (first (rest d))) "0" "0" (%n (game-cube g))
                (%flag (game-may-double? g me)) (%flag (game-may-double? g (int- 1 me))) (%flag (game-offered? g))
                "1" "-1" "0" "25" (%n (pos-me-off p)) (%n (pos-opp-off p)) (%n (pos-me p BAR)) (%n (pos-opp p BAR))
                "2" "0" "0" "0"))))))

; A place as gnubg writes it, "25", "0", "13" or "20*", as the bundle
; reads it: "bar", "off", "13", "20*".
(def %place-word
  (fn (_ s)
    (def n (str-byte-len s))
    (def hit (if (int< 0 n) (int= (str-byte-ref s (int- n 1)) 42) #f))
    (def w (if hit (str-byte-sub s 0 (int- n 1)) s))
    (Str8 append (match ((str=? w "25") "bar") ((str=? w "0") "off") (#t w)) (if hit "*" ""))))

; gnubg's play TEXT as the bundle writes a play.
(def gnubg-play-text
  (fn (_ text)
    (Str8 join " "
      (List map (fn (_ mv) (Str8 join "/" (List map %place-word (Str8 split "/" mv))))
        (List filter (fn (_ w) (int< 0 (str-byte-len w))) (Str8 split " " text))))))

; --- the connection -----------------------------------------------------------------
;
; A connection is a Vector of the socket, the bytes read past the last
; line, whether it has failed, the note waiting, the milliseconds a read
; waits for bytes, and whether the last read ran out of that time.

(def %c-fd 0)
(def %c-rest 1)
(def %c-failed 2)
(def %c-note 3)
(def %c-wait 4)
(def %c-late 5)

; How long gnubg is waited for, each time bytes are read, when no wait is
; given: 60 seconds.  Five games of gnubg against itself at its default
; strength, on an Apple M2 Pro, gave 377 answers, the slowest in 726 ms.
(def GNUBG-WAIT 60000)

(def %get (fn (_ c i) (Vector ref i c)))
(def %put! (fn (_ c i v) (Vector set! i v c)))

; The milliseconds since the clock read START, (SECONDS . MICROSECONDS).
(def %since
  (fn (_ start)
    ((fn (_ now) (int+ (int* (int- (first now) (first start)) 1000) (int/ (int- (rest now) (rest start)) 1000)))
     (Sys time-of-day))))

; #t once C's socket has bytes to read, #f when C's wait passes first.  A
; signal ends a poll early, so it is asked again for the time left.
(def %ready?
  (fn (_ c)
    (def start (Sys time-of-day))
    ((fn (self)
       ((fn (_ left)
          (match ((int< left 1) #f)
                 ((null? (Sys poll (list (pair (%get c %c-fd) (list (lit in)))) left)) (self))
                 (#t #t)))
        (int- (%get c %c-wait) (%since start)))))))

; The next line from C, without its newline.  Raises at the end of the
; input, and when no bytes come in C's wait.
(def %read-line
  (fn (self c)
    (def s (%get c %c-rest))
    (def i (Str8 index-of "\n" s))
    (if (null? i)
      (do (unless (%ready? c)
            (%put! c %c-late #t)
            (Err raise (lit io) "gnubg did not answer in time" ()))
          ((fn (_ more)
             (when (null? more) (Err raise (lit io) "gnubg closed the connection" ()))
             (%put! c %c-rest (Str8 append s more))
             (self c))
           (Socket recv (%get c %c-fd) 4096)))
      (do (%put! c %c-rest (str-byte-sub s (int+ i 1) (int- (str-byte-len s) (int+ i 1))))
          (str-byte-sub s 0 i)))))

; C's wait as text, "60 seconds" or "1 second".
(def %wait-text
  (fn (_ c) ((fn (_ s) (Str8 append (%n s) (if (int= s 1) " second" " seconds"))) (int/ (%get c %c-wait) 1000))))

; LINE sent on C and the line answered, or () when the connection fails.
; A late answer would be taken for the next one, so after a read runs out
; of time the connection is not asked again.
(def %ask
  (fn (_ c line)
    (if (%get c %c-failed) ()
      ((fn (_ r)
         (when (null? r)
           (%put! c %c-failed #t)
           (%put! c %c-note
             (if (%get c %c-late)
               (Str8 append "gnubg gave no answer in " (%wait-text c) ": the engine plays on.")
               "gnubg stopped answering: the engine plays on.")))
         r)
       (guard (e ()) (do (Socket send (%get c %c-fd) (Str8 append line "\n")) (%read-line c)))))))

; ANSWER read as a choice by READ, else the engine's choice by FALLBACK,
; the note saying why.
(def %choose
  (fn (_ c answer read fallback what)
    (def r (if (null? answer) () (read answer)))
    (if (null? r)
      (do (unless (%get c %c-failed)
            (%put! c %c-note (Str8 append "gnubg answered \"" answer "\" to " what ": the engine chose.")))
          (fallback))
      (first r))))

; The word W as (#t) or (#f) when it is one of YES or NO, else ().
(def %word
  (fn (_ yes no)
    (fn (_ w)
      ((fn (_ t) (match ((List includes? t yes) (list #t)) ((List includes? t no) (list #f)) (#t ())))
       (gnubg-play-text w)))))

; The opponent gnubg plays through the connection C, named NAME.
(def %opponent
  (fn (_ c name)
    (def engine (opponent-engine))
    (opponent-make name
      (fn (_ g)
        (def d (game-dice g))
        (%choose c (%ask c (gnubg-board g))
          (fn (_ text)
            ((fn (_ pl) (if (str? pl) () (list pl)))
             (play-find (game-pos g) (first d) (first (rest d)) (gnubg-play-text text))))
          (fn (_) (opponent-play engine g)) "its roll"))
      (fn (_ g) (%choose c (%ask c (gnubg-board g)) (%word (list "double") (list "roll")) (fn (_) (opponent-double? engine g)) "the cube"))
      (fn (_ g) (%choose c (%ask c (gnubg-board g)) (%word (list "take" "beaver") (list "drop")) (fn (_) (opponent-take? engine g)) "the double"))
      (fn (_) ((fn (_ n) (%put! c %c-note ()) n) (%get c %c-note))))))

; ADDRESS, "HOST:PORT", ":PORT" or "PORT", as (HOST PORT), the host
; 127.0.0.1 when none is given; () when the port is not a number.
(def %address
  (fn (_ address)
    (def i (Str8 index-of ":" address))
    (def host (if (null? i) "" (str-byte-sub address 0 i)))
    (def port-text (if (null? i) address (str-byte-sub address (int+ i 1) (int- (str-byte-len address) (int+ i 1)))))
    (def port (guard (e ()) ((prim-ref (lit convert) (lit to)) port-text (Type named INTEGER) 10)))
    (if (if (number? port) (if (int< 0 port) (int< port 65536) #f) #f)
      (list (if (str=? host "") "127.0.0.1" host) port)
      ())))

; The line of the version lines from C that starts with "Software: ",
; its version; () when the lines are not gnubg's.
(def %version
  (fn (_ c)
    (def first-line (%ask c "version"))
    (if (if (null? first-line) #t (not (str=? first-line "Interface: 2"))) ()
      ((fn (self k)
         (if (int= k 0) ()
           ((fn (_ line)
              (match ((null? line) ())
                     ((null? (Str8 index-of "Software: " line)) (self (int- k 1)))
                     (#t (str-byte-sub line 10 (int- (str-byte-len line) 10)))))
            (guard (e ()) (%read-line c)))))
       3))))

; The opponent gnubg plays over the connected socket FD, each read
; waiting WAIT milliseconds for it, or () when what answers there is not
; gnubg's external player, or does not answer in time, the socket then
; closed.
(def gnubg-on
  (fn (_ fd wait)
    ((fn (_ c)
       ((fn (_ v)
          (if (null? v) (do (guard (e ()) (Socket close fd)) ())
            (%opponent c (Str8 append "gnubg " v))))
        (%version c)))
     (Vector of fd "" #f () wait #f))))

; The opponent gnubg plays, listening at ADDRESS and waited for WAIT
; milliseconds each time bytes are read, or a string saying why
; it cannot be.
(def gnubg-opponent
  (fn (_ address wait)
    (def hp (%address address))
    (def where (if (null? hp) "" (Str8 append (first hp) ":" (%n (first (rest hp))))))
    (if (null? hp) "the address is HOST:PORT, :PORT or PORT"
      ((fn (_ host)
         ((fn (_ fd)
            (if (null? fd)
              (Str8 append "nothing answers at " where ": is gnubg listening, told `external :" (%n (first (rest hp))) "`?")
              ((fn (_ o) (if (null? o) (Str8 append where " does not answer as gnubg's external player") o)) (gnubg-on fd wait))))
          (if (null? host) () (guard (e ()) (Socket tcp-connect host (first (rest hp)))))))
       (guard (e ()) (Socket resolve (first hp)))))))

(provide backgammon/gnubg GNUBG-WAIT gnubg-board gnubg-play-text gnubg-on gnubg-opponent)
