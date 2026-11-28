# The match equity table
# @weight 2

The chance of winning a match at each score is Kazaross-XG2, as GNU
Backgammon ships it: tests/fixtures/Kazaross-XG2.xml, converted by
backgammon/met-convert into backgammon/met-xg2.


## The conversion

### gnubg's XML converted again is the table shipped

```backgammon
(def met-src "tests/fixtures/Kazaross-XG2.xml")
(write (str=? (met-convert (File read-all (spec-bundle-file met-src)) met-src "backgammon/met-xg2" "met-xg2")
              (File read-all (spec-bundle-file "lib/backgammon/met-xg2.x"))))
```
---
    #t


### a table given by parameters, or a value past six places, is refused

```backgammon
(def met-why (fn (_ xml) (guard (e (if (Err err? e) (e msg) e)) (met-convert xml "t.xml" "t" "t"))))
(def met-head "<!-- n --><met><info><name>t</name><length>1</length></info>")
(write (list (met-why (Str8 append met-head "<pre-crawford-table type=\"zadeh\"><parameters></parameters></pre-crawford-table><post-crawford-table type=\"zadeh\" player=\"both\"></post-crawford-table></met>"))
             (met-why (Str8 append met-head "<pre-crawford-table type=\"explicit\"><row><me>0.1234567</me></row></pre-crawford-table><post-crawford-table type=\"explicit\" player=\"both\"><row><me>0.5</me></row></post-crawford-table></met>"))))
```
---
    ("met-convert: the pre-crawford-table is not explicit" "met-convert: not a chance from 0 to 1: 0.1234567")


## The table

### its name and length, and the chances before the Crawford game

```backgammon
(write (list MET-NAME MET-LENGTH (met-equity 1 1) (met-equity 1 2) (met-equity 2 1) (met-equity 25 25)
             (met-equity 0 3) (met-equity 3 0) (met-equity 26 1)))
```
---
    ("Kazaross XG2 25 point MET" 25 500000 677360 322640 500000 1000000 0 ())


### the trailer's chance after the Crawford game

```backgammon
(write (list (met-post-crawford 1) (met-post-crawford 2) (met-post-crawford 3) (met-post-crawford 25) (met-post-crawford 26)))
```
---
    (500000 488030 322640 1230 ())
