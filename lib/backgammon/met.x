; # x-backgammon -- backgammon on x-lang
;
; ## backgammon/met.x -- the chance of winning a match, by the score
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The match equity table is Neil Kazaross's XG2 table as GNU Backgammon
; ships it (backgammon/met-xg2, written by backgammon/met-convert).  A
; score is read as the points each side still needs, its "away"; a chance
; is in millionths, 500000 an even match.

(module backgammon/met)

(import x/core/doors int- int<)
(import backgammon/met-xg2 met-xg2-name met-xg2-pre met-xg2-post)

; The table's name, and the longest match it holds: its rows.
(def MET-NAME met-xg2-name)
(def MET-LENGTH (List length met-xg2-pre))

; The chance the side ME away wins the match against the side OPP away,
; the Crawford game not yet played: 1000000 when ME is 0 or less, 0 when
; OPP is, () when either is past MET-LENGTH.
(def met-equity
  (fn (_ me opp)
    (match ((int< me 1) 1000000)
           ((int< opp 1) 0)
           ((int< MET-LENGTH me) ())
           ((int< MET-LENGTH opp) ())
           (#t (List ref (int- opp 1) (List ref (int- me 1) met-xg2-pre))))))

; After the Crawford game, the leader 1 away: the chance the trailer,
; TRAILER away, wins the match; 1000000 when TRAILER is 0 or less, ()
; past MET-LENGTH.
(def met-post-crawford
  (fn (_ trailer)
    (match ((int< trailer 1) 1000000)
           ((int< MET-LENGTH trailer) ())
           (#t (List ref (int- trailer 1) met-xg2-post)))))

(provide backgammon/met MET-NAME MET-LENGTH met-equity met-post-crawford)
