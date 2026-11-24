; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/record.x -- positions as XGID, games as a .mat file
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; An XGID is a position as eXtreme Gammon and GNU Backgammon read it:
;
;   XGID=-b----E-C---eE---c-e----B-:0:0:1:00:0:0:0:0:6
;
; The 26 characters are black's bar, white's points 1 to 24, and
; white's bar: "-" for none, A to P for 1 to 16 of white's, a to p for
; black's.  Then the cube as a power of two; its owner, 1 white, -1
; black, 0 the middle; the side to move, 1 white or -1 black (the doubler
; while a double waits); the dice, 00 to roll, D doubled, else the roll;
; the two scores; the rules, 0 for none; the match length, 0 for money;
; and the highest cube as a power of two.  White is the player at the
; bottom, X in GNU Backgammon's terms.
;
; A .mat file is a session's games as Jellyfish wrote them and GNU
; Backgammon reads and writes them, laid out column for column as GNU
; Backgammon's export lays them: " 0 point match" for money, each game
; numbered, the players and their points, then a line a pair of turns,
; white's on the left, each a roll and its moves ("31: 8/5 6/5 ", the
; bar 25 and off 0) or the cube's "Doubles => 2", "Takes" or "Drops".

(module backgammon/record)

(import x/type/vector)
(import x/sys/file)
(import x/core/doors int+ int- int* int/ int% int< int= io-display-to-str str-byte-len str-byte-ref str-byte-sub)
(import backgammon/board WHITE BLACK CHECKERS BAR pos-make pos-start pos-turn pos-me pos-opp pos-key)
(import backgammon/game CUBE-MAX game-at game-pos game-dice game-past game-result game-over? game-turn game-cube
  game-owner game-offered? game-may-double? game-throw game-set-dice! game-set-cube!)

(def %num (fn (_ n) (io-display-to-str n)))
(def %2nd (fn (_ l) (first (rest l))))
(def %spaces (fn (_ n) (Str8 join "" (List repeat n " "))))
(def %pad-right (fn (_ s w) (if (int< (str-byte-len s) w) (Str8 append s (%spaces (int- w (str-byte-len s)))) s)))
(def %pad-left (fn (_ s w) (if (int< (str-byte-len s) w) (Str8 append (%spaces (int- w (str-byte-len s))) s) s)))

; The power of two N is, for N a power of two.
(def %log2 (fn (self n) (if (int< n 2) 0 (int+ 1 (self (int/ n 2))))))
(def %pow2 (fn (self k) (if (int< k 1) 1 (int* 2 (self (int- k 1))))))

; The checkers of SIDE in P at its own index I, BAR the bar.
(def %of (fn (_ p side i) (if (int= (pos-turn p) side) (pos-me p i) (pos-opp p i))))

; --- XGID -------------------------------------------------------------------------

(def %upper "ABCDEFGHIJKLMNOP")
(def %lower "abcdefghijklmnop")

(def %letter (fn (_ n upper) (if (int= n 0) "-" (str-byte-sub (if upper %upper %lower) (int- n 1) 1))))

; The 26 characters of P.
(def %xg-position
  (fn (_ p)
    (Str8 join ""
      (List map
        (fn (_ k)
          (match ((int= k 0) (%letter (%of p BLACK BAR) #f))
                 ((int= k 25) (%letter (%of p WHITE BAR) #t))
                 ((int< 0 (%of p WHITE (int- k 1))) (%letter (%of p WHITE (int- k 1)) #t))
                 (#t (%letter (%of p BLACK (int- 24 k)) #f))))
        (List range 0 26)))))

(def %side-sign (fn (_ side) (if (int= side WHITE) "1" "-1")))

; G's position as an XGID.
(def xgid-text
  (fn (_ g)
    (def d (game-dice g))
    (Str8 join ":"
      (list (Str8 append "XGID=" (%xg-position (game-pos g)))
            (%num (%log2 (game-cube g)))
            (if (null? (game-owner g)) "0" (%side-sign (game-owner g)))
            (%side-sign (game-turn g))
            (match ((game-offered? g) "D") ((null? d) "00") (#t (Str8 append (%num (first d)) (%num (%2nd d)))))
            "0" "0" "0" "0" (%num (%log2 CUBE-MAX))))))

; S as a whole number, an optional "-" first: the number, or ().
(def %int
  (fn (_ s)
    (def n (str-byte-len s))
    (def neg (if (int< 0 n) (int= (str-byte-ref s 0) 45) #f))
    (def digits
      (fn (self i acc)
        (if (int< i n)
          ((fn (_ b) (if (if (int< 47 b) (int< b 58) #f) (self (int+ i 1) (int+ (int* 10 acc) (int- b 48))) ()))
           (str-byte-ref s i))
          acc)))
    (if (int< (if neg 1 0) n) ((fn (_ v) (if (null? v) () (if neg (int- 0 v) v))) (digits (if neg 1 0) 0)) ())))

; The character at I of a position: (COUNT . WHITE?), WHITE? () for "-";
; () when it is no count.
(def %count-at
  (fn (_ s i)
    ((fn (_ b)
       (match ((int= b 45) (pair 0 ()))
              ((if (int< 64 b) (int< b 81) #f) (pair (int- b 64) #t))
              ((if (int< 96 b) (int< b 113) #f) (pair (int- b 96) #f))
              (#t ())))
     (str-byte-ref s i))))

; The 26 characters S read: (WHITE BLACK), each a Vector of 25 counts
; by the side's own index, 24 the bar; or why they cannot be.
(def %read-position
  (fn (_ s)
    (def w (Vector make 25 0))
    (def b (Vector make 25 0))
    (def put
      (fn (_ k c)
        (match ((null? c) "a character of the position is not -, A to P or a to p")
               ((int= (first c) 0) ())
               ((int= k 0) (if (rest c) "white's checkers cannot be on black's bar" (Vector set! 24 (first c) b)))
               ((int= k 25) (if (rest c) (Vector set! 24 (first c) w) "black's checkers cannot be on white's bar"))
               ((rest c) (Vector set! (int- k 1) (first c) w))
               (#t (Vector set! (int- 24 k) (first c) b)))))
    (def bad
      (List fold (fn (_ acc k) (if (str? acc) acc ((fn (_ r) (if (str? r) r ())) (put k (%count-at s k))))) () (List range 0 26)))
    (if (str? bad) bad (list w b))))

(def %sum (fn (_ v) (List fold int+ 0 (List map (fn (_ i) (Vector ref i v)) (List range 0 25)))))

; A side's counts V as (POINT . COUNT) for pos-make, 25 the bar.
(def %men (fn (_ v) (List reject (fn (_ c) (int= (rest c) 0)) (List map (fn (_ i) (pair (int+ i 1) (Vector ref i v))) (List range 0 25)))))

; The dice field S: (D1 D2), () to roll, D for a double, or ().
(def %dice
  (fn (_ s)
    (match ((str=? s "D") (lit doubled))
           ((str=? s "00") ())
           ((int= (str-byte-len s) 2)
             ((fn (_ a b) (if (if (if (int< 0 a) (int< a 7) #f) (if (int< 0 b) (int< b 7) #f) #f) (list a b) (lit bad)))
              (int- (str-byte-ref s 0) 48) (int- (str-byte-ref s 1) 48)))
           (#t (lit bad)))))

; TEXT, an XGID with or without "XGID=", read as a game with its dice
; from RND: the game, or why it cannot be read.
(def xgid-game
  (fn (_ text rnd)
    (def s (if (if (int< 5 (str-byte-len text)) (str=? (str-byte-sub text 0 5) "XGID=") #f) (str-byte-sub text 5 (int- (str-byte-len text) 5)) text))
    (def fields (if (null? (Str8 index-of ":" s)) (list s) (Str8 split ":" s)))
    (if (not (int= (List length fields) 10)) "an XGID has a position and nine fields after it, apart by colons"
      (do
        (def at (fn (_ i) (List ref i fields)))
        (def cube (%int (at 1)))
        (def owner (%int (at 2)))
        (def turn (%int (at 3)))
        (def dice (%dice (at 4)))
        (def match-length (%int (at 8)))
        (def sides (if (int= (str-byte-len (at 0)) 26) (%read-position (at 0)) "the position has 26 characters"))
        (match
          ((str? sides) sides)
          ((if (null? cube) #t (if (int< cube 0) #t (int< (%log2 CUBE-MAX) cube))) (Str8 append "the cube is a power of two from 0 to " (%num (%log2 CUBE-MAX))))
          ((if (null? owner) #t (if (int< owner -1) #t (int< 1 owner))) "the cube's owner is 1, -1 or 0")
          ((if (null? turn) #t (if (int= turn 1) #f (not (int= turn -1)))) "the side to move is 1 or -1")
          ((eq? dice (lit bad)) "the dice are 00, D or a roll such as 31")
          ((if (null? match-length) #t (not (int= match-length 0))) "only money games are played: the match length is 0")
          ((if (int< CHECKERS (%sum (first sides))) #t (int< CHECKERS (%sum (%2nd sides)))) "a side has more than 15 checkers")
          ((if (int= 0 (%sum (first sides))) #t (int= 0 (%sum (%2nd sides)))) "a side has borne off every checker: the game is over")
          (#t
            (do
              (def side (if (int= turn 1) WHITE BLACK))
              (def mine (if (int= side WHITE) (first sides) (%2nd sides)))
              (def theirs (if (int= side WHITE) (%2nd sides) (first sides)))
              (def g (game-at (pos-make side (%men mine) (%men theirs)) (if (pair? dice) dice ()) rnd))
              (game-set-cube! g (%pow2 cube) (match ((int= owner 0) ()) ((int= owner 1) WHITE) (#t BLACK)) (eq? dice (lit doubled)))
              (match
                ((if (eq? dice (lit doubled)) (not (game-may-double? g side)) #f) "the side to move may not double: the cube is the other side's")
                ((if (null? dice) (not (game-may-double? g side)) #f) ((fn (_ d) (game-set-dice! g (first d) (%2nd d))) (game-throw g)))
                (#t g))))))))))

; --- the .mat file ----------------------------------------------------------------

; #t when G was played from the start: only such a game can be written.
(def %from-start?
  (fn (_ g)
    ((fn (_ past) (if (null? past) #f (str=? (pos-key (first (List ref (int- (List length past) 1) past))) (pos-key (pos-start)))))
     (game-past g))))

; STEPS as GNU Backgammon writes them plainly: each FROM/TO counted
; from 1, the bar 25 and off 0, a hit marked, and a space after each of
; the first three.
(def %plain
  (fn (_ steps)
    (Str8 join ""
      (List map
        (fn (_ k)
          ((fn (_ s)
             (Str8 append (%num (int+ 1 (first s))) "/" (%num (int+ 1 (%2nd s))) (if (List ref 2 s) "*" "") (if (int< k 3) " " "")))
           (List ref k steps)))
        (List range 0 (List length steps))))))

(def %player (fn (_ side) (if (int= side WHITE) 0 1)))

; G's turns and cube actions, oldest first, each (KIND PLAYER TEXT
; POINTS): KIND move, double, take or drop; POINTS, for the move or the
; drop that ends the game, the points won, else ().
(def %records
  (fn (_ g)
    (def entries (List reverse (game-past g)))
    (def r (game-result g))
    (def last (if (null? entries) () (List ref (int- (List length entries) 1) entries)))
    (def double (fn (_ side value) (list (lit double) (%player side) (Str8 append " Doubles => " (%num value)) ())))
    (def answer (fn (_ side kind points) (list kind (%player side) (if (eq? kind (lit take)) " Takes" " Drops") points)))
    (def moves
      (List fold
        (fn (_ acc e)
          (def mover (pos-turn (first e)))
          (def cube (List ref 3 e))
          (def d (%2nd e))
          (def won (if (if (same? e last) (if (null? r) #f (int< 0 (List ref 2 r))) #f) (%2nd r) ()))
          (def move (list (lit move) (%player mover) (Str8 append (%num (first d)) (%num (%2nd d)) ": " (%plain (first (List ref 2 e)))) won))
          (pair cube
            (List append (rest acc)
              (if (int= cube (int* 2 (first acc)))
                (list (double mover cube) (answer (int- 1 mover) (lit take) ()) move)
                (list move)))))
        (pair 1 ()) entries))
    (def cube (first moves))
    (List append (rest moves)
      (match
        ((if (null? r) #f (int= (List ref 2 r) 0))
          (list (double (game-turn g) (int* 2 (game-cube g))) (answer (int- 1 (game-turn g)) (lit drop) (%2nd r))))
        ((not (null? r)) ())
        ((game-offered? g) (list (double (game-turn g) (int* 2 (game-cube g)))))
        ((int= (game-cube g) (int* 2 cube)) (list (double (game-turn g) (game-cube g)) (answer (int- 1 (game-turn g)) (lit take) ())))
        (#t ())))))

(def %wins (fn (_ n) (Str8 append "Wins " (%num n) " point" (if (int= n 1) "" "s"))))

; Game G's lines, numbered N, the points SCORE (WHITE . BLACK) before it.
(def %game-text
  (fn (_ g n score)
    (def out
      (List fold
        (fn (_ acc rec)
          (def i (first acc))
          (def kind (first rec))
          (def text
            (if (eq? kind (lit drop))
              (Str8 append (List ref 2 rec) (if (int= 1 (int% i 2)) "\n      " (%spaces 23)) (%wins (List ref 3 rec)))
              (List ref 2 rec)))
          (def lead (if (if (int= i 0) (if (eq? kind (lit move)) (int= (%2nd rec) 1) #f) #f) (Str8 append "  1)" (%spaces 29)) ""))
          (def j (if (str=? lead "") i 1))
          (def odd (int= 1 (int% j 2)))
          (pair (int+ j 1)
            (Str8 append (rest acc) lead
              (if odd (Str8 append text "\n") (Str8 append (%pad-left (%num (int+ 1 (int/ j 2))) 3) ") " (%pad-right text 27) " "))
              (if (eq? kind (lit drop)) (if odd "\n" "\n\n") "")
              (if (if (eq? kind (lit move)) (not (null? (List ref 3 rec))) #f)
                (Str8 append (if odd (%spaces 34) "\n      ") (%wins (List ref 3 rec)) "\n\n")
                ""))))
        (pair 0 "") (%records g)))
    (Str8 append " Game " (%num n) "\n"
      " " (%pad-right (Str8 append "White : " (%num (first score))) 31) "Black : " (%num (rest score)) "\n"
      (rest out)
      (if (game-over? g) "" (if (int= 1 (int% (first out) 2)) "\n\n" "\n")))))

; The games GAMES, oldest first, as a money session's .mat file; games
; not played from the start are left out.
(def mat-text
  (fn (_ games)
    (List ref 2
      (List fold
        (fn (_ acc g)
          (def score (first acc))
          (def n (%2nd acc))
          (def r (game-result g))
          (list (if (null? r) score
                  (if (int= (first r) WHITE) (pair (int+ (first score) (%2nd r)) (rest score)) (pair (first score) (int+ (rest score) (%2nd r)))))
                (int+ n 1)
                (Str8 append (List ref 2 acc) (%game-text g n score))))
        (list (pair 0 0) 1 " 0 point match\n\n") (List filter %from-start? games)))))

; GAMES written to PATH as a .mat file: what to say of it.
(def record-save!
  (fn (_ path games)
    (def kept (List filter %from-start? games))
    (if (null? kept) "There is no game played from the start to save."
      ((fn (_ s)
         (guard (e (Str8 append "Cannot write " path "."))
           (do
             (def fd (File open path (list (lit wronly) (lit creat) (lit trunc)) 420))
             (if (int< fd 0) (Str8 append "Cannot write " path ".")
               (do (File write fd s (str-byte-len s))
                   (File close fd)
                   (Str8 append "Saved " (%num (List length kept)) (if (int= 1 (List length kept)) " game" " games") " to " path "."))))))
       (mat-text kept)))))

(provide backgammon/record xgid-text xgid-game mat-text record-save!)
