; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/met-convert.x -- a match equity table from gnubg's XML
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; GNU Backgammon keeps its match equity tables as XML (met/met.dtd in its
; data): a comment holding the table's notice, an info block with the
; name and the match length, a pre-crawford-table of rows of <me> values,
; and a post-crawford-table of one row.  met-convert reads the explicit
; form of that, a post-Crawford row for both players, and writes it as an
; x module (backgammon/met-xg2 is its output for Kazaross-XG2.xml); any
; other form is refused, not guessed at.
;
; In gnubg's matchequity.c (1.08.003) a pre-Crawford value goes to
; `aarMET[parser->j][parser->i]`, j counting the rows and i the values in
; a row, and is looked up as `aafMET[n0][n1]`, n0 and n1 each side's
; points to go less one: row R, value C is the chance of winning the
; match for the side R + 1 away against a side C + 1 away.  A post-Crawford
; value goes to `aarMETPostCrawford[0][parser->i]` and `[1]` alike for
; "both": value K is the trailer's chance K + 1 away, the leader 1 away.
;
; Each value, a decimal of at most six places from 0 to 1, is written as a
; whole number of millionths: 0.67736 as 677360.

(module backgammon/met-convert)

(import x/core/doors int+ int- int* int< int= io-display-to-str str-byte-len str-byte-ref str-byte-sub)

(def %fail (fn (_ why) (Err raise (lit met) (Str8 append "met-convert: " why) ())))

(def %sub (fn (_ s start end) (str-byte-sub s start (int- end start))))

; The index of NEEDLE in S at FROM or after, or ().
(def %find
  (fn (_ s from needle)
    ((fn (_ i) (if (null? i) () (int+ from i)))
     (Str8 index-of needle (str-byte-sub s from (int- (str-byte-len s) from))))))

; The text of S between OPEN at FROM or after and the CLOSE after it, and
; the index past CLOSE, as (TEXT . NEXT), or () when OPEN is not there.
(def %between
  (fn (_ s from open close)
    (def a (%find s from open))
    (if (null? a) ()
      ((fn (_ b) (if (null? b) (%fail (Str8 append "no " close " after " open))
                   (pair (%sub s (int+ a (str-byte-len open)) b) (int+ b (str-byte-len close)))))
       (%find s (int+ a (str-byte-len open)) close)))))

(def %space? (fn (_ c) (if (int= c 32) #t (if (int= c 10) #t (if (int= c 13) #t (int= c 9))))))

; S without the spaces and line ends at either end.
(def %trim
  (fn (_ s)
    (def n (str-byte-len s))
    (def a ((fn (self i) (if (if (int< i n) (%space? (str-byte-ref s i)) #f) (self (int+ i 1)) i)) 0))
    (def b ((fn (self i) (if (if (int< a i) (%space? (str-byte-ref s (int- i 1))) #f) (self (int- i 1)) i)) n))
    (%sub s a b)))

(def %digit (fn (_ c) (if (if (int< 47 c) (int< c 58) #f) (int- c 48) ())))

; The digits T as a number, or () when T is empty or holds another byte.
(def %whole
  (fn (_ t)
    (if (int= (str-byte-len t) 0) ()
      ((fn (self i acc)
         (if (int= i (str-byte-len t)) acc
           ((fn (_ d) (if (null? d) () (self (int+ i 1) (int+ (int* acc 10) d)))) (%digit (str-byte-ref t i)))))
       0 0))))

; The decimal TEXT, "0.67736" or "1", as millionths: 677360, 1000000.
(def %millionths
  (fn (_ text)
    (def s (%trim text))
    (def n (str-byte-len s))
    (def dot (%find s 0 "."))
    (def whole (if (null? dot) s (%sub s 0 dot)))
    (def places (if (null? dot) "" (%sub s (int+ dot 1) n)))
    (def w (if (int= (str-byte-len whole) 1) (%whole whole) ()))
    (def f (match ((int= (str-byte-len places) 0) (if (null? dot) 0 ()))
                  ((int< 6 (str-byte-len places)) ())
                  (#t ((fn (_ v) (if (null? v) () ((fn (self v k) (if (int= k 6) v (self (int* v 10) (int+ k 1)))) v (str-byte-len places))))
                       (%whole places)))))
    (def v (if (if (null? w) #t (null? f)) () (int+ (int* w 1000000) f)))
    (if (if (null? v) #t (int< 1000000 v)) (%fail (Str8 append "not a chance from 0 to 1: " s)) v)))

; The rows of the table TEXT, each a list of millionths.
(def %rows
  (fn (_ text)
    ((fn (self from acc)
       ((fn (_ r)
          (if (null? r) (List reverse acc)
            (self (rest r) (pair ((fn (_ vals) (vals 0 ()))
                                  (fn (vals at got)
                                    ((fn (_ m) (if (null? m) (List reverse got) (vals (rest m) (pair (%millionths (first m)) got))))
                                     (%between (first r) at "<me>" "</me>"))))
                                 acc))))
        (%between text from "<row>" "</row>")))
     0 ())))

; The table named OPEN in XML: its opening tag's attributes and its body,
; as (TAG . BODY).
(def %table
  (fn (_ xml open)
    (def a (%find xml 0 (Str8 append "<" open)))
    (when (null? a) (%fail (Str8 append "no " open)))
    (def tag-end (%find xml a ">"))
    (def close (%find xml tag-end (Str8 append "</" open ">")))
    (when (null? close) (%fail (Str8 append "no </" open ">")))
    (pair (%sub xml a tag-end) (%sub xml (int+ tag-end 1) close))))

(def %has? (fn (_ s needle) (not (null? (%find s 0 needle)))))

; The comment's lines, each trimmed, the empty ones at either end dropped.
(def %notice-lines
  (fn (_ text)
    (def lines
      ((fn (self from acc)
         ((fn (_ nl) (if (null? nl) (List reverse (pair (%trim (%sub text from (str-byte-len text))) acc))
                       (self (int+ nl 1) (pair (%trim (%sub text from nl)) acc))))
          (%find text from "\n")))
       0 ()))
    (def drop (fn (self ls) (if (if (pair? ls) (int= (str-byte-len (first ls)) 0) #f) (self (rest ls)) ls)))
    (List reverse (drop (List reverse (drop lines))))))

(def %n (fn (_ v) (io-display-to-str v)))

(def %row-text (fn (_ row) (Str8 append "(list " (Str8 join " " (List map %n row)) ")")))

; The x module, named MODULE, defining PREFIX-name, PREFIX-pre and
; PREFIX-post, for gnubg's match equity table XML read from SOURCE.
(def met-convert
  (fn (_ xml source module prefix)
    (def notice (%between xml 0 "<!--" "-->"))
    (when (null? notice) (%fail "no notice comment"))
    (def name ((fn (_ b) (if (null? b) (%fail "no <name>") (%trim (first b)))) (%between xml 0 "<name>" "</name>")))
    (def len ((fn (_ b) (if (null? b) (%fail "no <length>") (%trim (first b)))) (%between xml 0 "<length>" "</length>")))
    (def length ((fn (_ m) (if (if (null? m) #t (int< m 1)) (%fail (Str8 append "the length is not a number of points: " len)) m)) (%whole len)))
    (def pre (%table xml "pre-crawford-table"))
    (def post (%table xml "post-crawford-table"))
    (unless (%has? (first pre) "type=\"explicit\"") (%fail "the pre-crawford-table is not explicit"))
    (unless (%has? (first post) "type=\"explicit\"") (%fail "the post-crawford-table is not explicit"))
    (unless (%has? (first post) "player=\"both\"") (%fail "the post-crawford-table is not for both players"))
    (def pre-rows (%rows (rest pre)))
    (def post-rows (%rows (rest post)))
    (unless (int= (List length pre-rows) length) (%fail "the pre-crawford-table's rows are not the length"))
    (unless (List all? (fn (_ r) (int= (List length r) length)) pre-rows) (%fail "a pre-crawford row is not the length"))
    (unless (int= (List length post-rows) 1) (%fail "the post-crawford-table is not one row"))
    (unless (int= (List length (first post-rows)) length) (%fail "the post-crawford row is not the length"))
    (Str8 append
      "; # x-backgammon -- backgammon on x-lang\n"
      ";\n"
      "; ## " module ".x -- " name "\n"
      ";\n"
      "; Written by backgammon/met-convert from " source ",\n"
      "; as GNU Backgammon ships it; not edited by hand.  Each value is the\n"
      "; chance of winning the match in millionths.  " prefix "-pre's row R,\n"
      "; value C: the side R + 1 points away against the side C + 1 away.\n"
      "; " prefix "-post's value K: after the Crawford game, the trailer K + 1\n"
      "; away, the leader 1 away.\n"
      ";\n"
      "; The table's notice, as it stands in " source ":\n"
      ";\n"
      (Str8 join "" (List map (fn (_ l) (if (int= (str-byte-len l) 0) ";\n" (Str8 append ";   " l "\n"))) (%notice-lines (first notice))))
      "\n(module " module ")\n\n"
      "(def " prefix "-name \"" name "\")\n\n"
      "(def " prefix "-pre\n  (list\n"
      (Str8 join "" (List map (fn (_ r) (Str8 append "    " (%row-text r) "\n")) pre-rows))
      "  ))\n\n"
      "(def " prefix "-post\n  " (%row-text (first post-rows)) ")\n\n"
      "(provide " module " " prefix "-name " prefix "-pre " prefix "-post)\n")))

(provide backgammon/met-convert met-convert)
