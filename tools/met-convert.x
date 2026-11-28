; # x-backgammon -- backgammon on x-lang
;
; ## tools/met-convert.x -- write backgammon/met-xg2 from gnubg's table
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; From the bundle's directory:
;
;   x -f tools/met-convert.x -- tests/fixtures/Kazaross-XG2.xml lib/backgammon/met-xg2.x
;
; The XML is GNU Backgammon's met/Kazaross-XG2.xml (gnubg-data 1.08.003),
; kept as it ships; 14-met.spec.md converts it again and compares.

(import-path! "lib")
(import x/sys/file)
(import x/sys/posix)
(import x/core/doors str-byte-len)
(import backgammon/met-convert met-convert)

(def %args (rest (Sys args (lit program))))
(if (not (if (pair? %args) (pair? (rest %args)) #f))
  (Sys fd-write 2 "usage: x -f tools/met-convert.x -- TABLE.xml MODULE.x\n")
  ((fn (_ in out)
     ((fn (_ text)
        (def fd (File open out (list (lit wronly) (lit creat) (lit trunc)) 420))
        (File write fd text (str-byte-len text))
        (File close fd)
        (Sys fd-write 1 (Str8 append "wrote " out "\n")))
      (met-convert (File read-all in) in "backgammon/met-xg2" "met-xg2")))
   (first %args) (first (rest %args))))
