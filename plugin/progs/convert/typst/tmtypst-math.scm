;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : tmtypst-math.scm
;; DESCRIPTION : Conversion of TeXmacs math trees into Typst math with alt text
;; COPYRIGHT   : (C) 2026  Ingolf Schäfer, Gemini 4 Neon
;;
;; This software falls under the GNU General Public License version 2 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (convert typst tmtypst-math)
  (:use (convert tools tmconcat)
        (convert tools tmtable)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; String-Hilfsfunktionen für Mathe-Export
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (math-string-replace-all str old new)
  (let ((old-len (string-length old)))
    (if (= old-len 0)
        str
        (let loop ((s str) (acc ""))
          (let ((idx (string-contains s old)))
            (if idx
                (loop (substring s (+ idx old-len))
                      (string-append acc (substring s 0 idx) new))
                (string-append acc s)))))))

(define (math-escape-string s)
  (let* ((s1 (math-string-replace-all s "\\" "\\\\"))
         (s2 (math-string-replace-all s1 "\"" "\\\"")))
    s2))

(define (math-plain-text t)
  (cond
    ((string? t) (cork->utf8 t))
    ((pair? t)
     (let ((tag (car t))
           (args (cdr t)))
       (cond
         ((in? tag '(concat document para))
          (string-join (map math-plain-text args) ""))
         ((== tag 'with)
          (if (pair? args) (math-plain-text (cAr args)) ""))
         (else (string-join (map math-plain-text args) "")))))
    (else "")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Symbol- & Token-Mapping (TeXmacs -> Typst Math)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define tmtypst-math-symbols
  '(;; Griechische Kleinbuchstaben
    ("<alpha>"      . "alpha")
    ("<beta>"       . "beta")
    ("<gamma>"      . "gamma")
    ("<delta>"      . "delta")
    ("<epsilon>"    . "epsilon")
    ("<varepsilon>" . "epsilon.alt")
    ("<zeta>"       . "zeta")
    ("<eta>"        . "eta")
    ("<theta>"      . "theta")
    ("<vartheta>"   . "theta.alt")
    ("<iota>"       . "iota")
    ("<kappa>"      . "kappa")
    ("<lambda>"     . "lambda")
    ("<mu>"         . "mu")
    ("<nu>"         . "nu")
    ("<xi>"         . "xi")
    ("<omicron>"    . "omicron")
    ("<pi>"         . "pi")
    ("<varpi>"      . "pi.alt")
    ("<rho>"        . "rho")
    ("<varrho>"     . "rho.alt")
    ("<sigma>"      . "sigma")
    ("<varsigma>"   . "sigma.alt")
    ("<tau>"        . "tau")
    ("<upsilon>"    . "upsilon")
    ("<phi>"        . "phi.alt")
    ("<varphi>"     . "phi")
    ("<chi>"        . "chi")
    ("<psi>"        . "psi")
    ("<omega>"      . "omega")
    ;; Griechische Großbuchstaben
    ("<Gamma>"      . "Gamma")
    ("<Delta>"      . "Delta")
    ("<Theta>"      . "Theta")
    ("<Lambda>"     . "Lambda")
    ("<Xi>"         . "Xi")
    ("<Pi>"         . "Pi")
    ("<Sigma>"      . "Sigma")
    ("<Upsilon>"    . "Upsilon")
    ("<Phi>"        . "Phi")
    ("<Psi>"        . "Psi")
    ("<Omega>"      . "Omega")
    ;; Operatoren & Relationen
    ("<cdot>"       . "dot.c")
    ("<times>"      . "times")
    ("<div>"        . "div")
    ("<pm>"         . "plus.minus")
    ("<mp>"         . "minus.plus")
    ("<leq>"        . "<=")
    ("<leqslant>"   . "<=")
    ("<geq>"        . ">=")
    ("<geqslant>"   . ">=")
    ("<neq>"        . "!=")
    ("<approx>"     . "approx")
    ("<equiv>"      . "equiv")
    ("<sim>"        . "tilde.op")
    ("<simeq>"      . "tilde.eq")
    ("<cong>"       . "tilde.equiv")
    ("<propto>"     . "prop")
    ("<ll>"         . "lt.double")
    ("<gg>"         . "gt.double")
    ;; Mengenlehre & Logik
    ("<in>"         . "in")
    ("<notin>"      . "in.not")
    ("<ni>"         . "in.rev")
    ("<subset>"     . "subset")
    ("<subseteq>"   . "subset.eq")
    ("<supset>"     . "supset")
    ("<supseteq>"   . "supset.eq")
    ("<cup>"        . "union")
    ("<cap>"        . "inter")
    ("<setminus>"   . "without")
    ("<emptyset>"   . "emptyset")
    ("<varnothing>" . "emptyset")
    ("<forall>"     . "forall")
    ("<exists>"     . "exists")
    ("<nexists>"    . "exists.not")
    ("<neg>"        . "not")
    ("<lnot>"       . "not")
    ("<wedge>"      . "and")
    ("<land>"       . "and")
    ("<vee>"        . "or")
    ("<lor>"        . "or")
    ("<top>"        . "top")
    ("<bot>"        . "bot")
    ("<vdash>"      . "tack.r")
    ("<models>"     . "models")
    ;; Pfeile
    ("<rightarrow>"     . "->")
    ("<to>"             . "->")
    ("<leftarrow>"      . "<-")
    ("<leftrightarrow>" . "<->")
    ("<Rightarrow>"     . "=>")
    ("<implies>"        . "==>")
    ("<Leftarrow>"      . "<=")
    ("<Leftrightarrow>" . "<=>")
    ("<iff>"            . "<==>")
    ("<mapsto>"         . "|->")
    ("<uparrow>"        . "arrow.t")
    ("<downarrow>"      . "arrow.b")
    ("<longrightarrow>" . "-->")
    ("<longleftarrow>"  . "<--")
    ;; Analysis & Sonderzeichen
    ("<infty>"      . "oo")
    ("<partial>"    . "partial")
    ("<nabla>"      . "nabla")
    ("<ldots>"      . "dots.h")
    ("<cdots>"      . "dots.c")
    ("<vdots>"      . "dots.v")
    ("<ddots>"      . "dots.down")
    ("<circ>"       . "circle.small")
    ("<bullet>"     . "bullet")
    ("<star>"       . "star")
    ("<ast>"        . "ast")
    ("<oplus>"      . "plus.circle")
    ("<otimes>"     . "times.circle")
    ("<perp>"       . "perp")
    ("<parallel>"   . "parallel")
    ("<angle>"      . "angle")
    ("<ell>"        . "ell")
    ("<hbar>"       . "planck")
    ("<Re>"         . "Re")
    ("<Im>"         . "Im")
    ("<aleph>"      . "aleph")
    ("<dagger>"     . "dagger")
    ("<ddagger>"    . "dagger.double")
    ("<mid>"        . "mid")
    ("<nmid>"       . "divides.not")
    ("<comma>"      . ",")
    ("<nobracket>"  . "")
    ("<nosymbol>"   . "")))

;; Standard-Mathe-Funktionsnamen (werden in Typst aufrecht gesetzt)
(define tmtypst-math-functions
  '("sin" "cos" "tan" "cot" "sec" "csc"
    "arcsin" "arccos" "arctan"
    "sinh" "cosh" "tanh" "coth"
    "exp" "log" "ln" "lg"
    "lim" "limsup" "liminf"
    "sup" "inf" "max" "min" "arg"
    "det" "dim" "ker" "deg" "gcd" "hom" "Pr" "mod" "sgn" "tr"))

;; Einzelnes Math-Token übersetzen
(define (tmtypst-math-token tok)
  (cond
    ((== tok "") "")
    ;; Unsichtbare Multiplikation in TeXmacs -> Leerzeichen in Typst
    ((== tok "*") " ")
    ;; Funktionsanwendung (z. B. f<apply>(x)) -> nichts
    ((== tok "<apply>") "")
    ;; Bekannte Symbol-Tabelle
    ((assoc-ref tmtypst-math-symbols tok) => (lambda (v) v))
    ;; Blackboard-Bold <bbb-R> -> bb(R)
    ((and (string-starts? tok "<bbb-") (string-ends? tok ">"))
     (string-append "bb(" (substring tok 5 (- (string-length tok) 1)) ")"))
    ;; Kalligrafisch <cal-A> -> cal(A)
    ((and (string-starts? tok "<cal-") (string-ends? tok ">"))
     (string-append "cal(" (substring tok 5 (- (string-length tok) 1)) ")"))
    ;; Fraktur <frak-g> -> frak(g)
    ((and (string-starts? tok "<frak-") (string-ends? tok ">"))
     (string-append "frak(" (substring tok 6 (- (string-length tok) 1)) ")"))
    ;; Aufrecht fett <b-up-x> -> bold(upright(x))
    ((and (string-starts? tok "<b-up-") (string-ends? tok ">"))
     (string-append "bold(upright(" (substring tok 6 (- (string-length tok) 1)) "))"))
    ;; Aufrecht <up-d> -> upright(d)
    ((and (string-starts? tok "<up-") (string-ends? tok ">"))
     (string-append "upright(" (substring tok 4 (- (string-length tok) 1)) ")"))
    ;; Fett <b-x> -> bold(x)
    ((and (string-starts? tok "<b-") (string-ends? tok ">"))
     (let ((inner (substring tok 3 (- (string-length tok) 1))))
       (string-append "bold(" (tmtypst-math-token
                                (if (> (string-length inner) 1)
                                    (string-append "<" inner ">")
                                    inner)) ")")))
    ;; Unbekanntes <symbol> -> über cork->utf8 versuchen
    ((and (string-starts? tok "<") (string-ends? tok ">"))
     (let ((u (cork->utf8 tok)))
       (if (== u tok)
           (string-append "\"" (math-escape-string (substring tok 1 (- (string-length tok) 1))) "\"")
           u)))
    ;; Bekannte Funktionsnamen
    ((in? tok tmtypst-math-functions) tok)
    ;; Mehrstellige Buchstabenfolgen, die keine bekannte Funktion sind: in Typst als Text/Ident
    ((and (> (string-length tok) 1)
          (char-alphabetic? (string-ref tok 0)))
     (string-append "\"" (math-escape-string (cork->utf8 tok)) "\""))
    ;; Einzelne Zeichen / Zahlen / Operatoren
    ((== tok "'") "'")
    ((== tok "_") "\\_")
    ((== tok "^") "\\^")
    ((== tok "\\") "backslash")
    ((in? tok '("+" "-" "=" "<" ">" "," ";" ":" "!" "(" ")" "[" "]" "{" "}" "|" "/"))
     tok)
    (else (cork->utf8 tok))))

;; Große Operatoren (<big|sum>, <big|int>, ...)
(define (tmtypst-math-big op)
  (cond
    ((== op ".")      "")
    ((== op "sum")    "sum")
    ((== op "prod")   "product")
    ((== op "coprod") "product.co")
    ((== op "int")    "integral")
    ((== op "oint")   "integral.cont")
    ((== op "iint")   "integral.double")
    ((== op "iiint")  "integral.triple")
    ((== op "cup")    "union.big")
    ((== op "cap")    "inter.big")
    ((== op "vee")    "or.big")
    ((== op "wedge")  "and.big")
    ((== op "oplus")  "plus.circle.big")
    ((== op "otimes") "times.circle.big")
    ((== op "odot")   "dot.circle.big")
    ((== op "sqcap")  "inter.sq.big")
    ((== op "sqcup")  "union.sq.big")
    (else             op)))

;; Kommas und Semikolons innerhalb von Typst-Mathe-Funktionsargumenten idempotent escapen
(define (tmtypst-math-escape-arg s)
  (let* ((s0 (math-string-replace-all s "\\," ","))
         (s1 (math-string-replace-all s0 "\\;" ";"))
         (s2 (math-string-replace-all s1 "," "\\,")))
    (math-string-replace-all s2 ";" "\\;")))

;; Akzente (<wide|x|^>, <wide|x|<vect>>, ...)
(define (tmtypst-math-wide base acc)
  (let ((b (tmtypst-math-escape-arg (tmtypst-math-serialize base))))
    (cond
      ((== acc "^")           (string-append "hat(" b ")"))
      ((== acc "~")           (string-append "tilde(" b ")"))
      ((== acc "<bar>")       (string-append "overline(" b ")"))
      ((== acc "<vect>")      (string-append "arrow(" b ")"))
      ((== acc "<dot>")       (string-append "dot(" b ")"))
      ((== acc "<ddot>")      (string-append "dot.double(" b ")"))
      ((== acc "<dddot>")     (string-append "dot.triple(" b ")"))
      ((== acc "<check>")     (string-append "caron(" b ")"))
      ((== acc "<breve>")     (string-append "breve(" b ")"))
      ((== acc "<acute>")     (string-append "acute(" b ")"))
      ((== acc "<grave>")     (string-append "grave(" b ")"))
      ((== acc "<overbrace>") (string-append "overbrace(" b ")"))
      ((== acc "<underbrace>")(string-append "underbrace(" b ")"))
      (else                   (string-append "accent(" b ", " (tmtypst-math-token acc) ")")))))

(define (tmtypst-math-wide* base acc)
  (let ((b (tmtypst-math-escape-arg (tmtypst-math-serialize base))))
    (cond
      ((== acc "<underbrace>") (string-append "underbrace(" b ")"))
      ((== acc "<bar>")        (string-append "underline(" b ")"))
      (else                    (string-append "underline(" b ")")))))

;; Klammern für <left|...>, <right|...>, <around|l|body|r>
;; Verwende Typst-Symbolnamen (bracket.l/r, paren.l/r, brace.l/r), damit auch
;; deutsche offene Intervalle wie ]0; 1[ oder [a; b[ nie "unclosed delimiter" erzeugen!
(define (tmtypst-math-delim d)
  (cond
    ((== d ".")         "")
    ((== d "(")         "paren.l")
    ((== d ")")         "paren.r")
    ((== d "[")         "bracket.l")
    ((== d "]")         "bracket.r")
    ((== d "{")         "brace.l")
    ((== d "}")         "brace.r")
    ((== d "|")         "bar.v")
    ((== d "<langle>")  "chevron.l")
    ((== d "<rangle>")  "chevron.r")
    ((== d "<lfloor>")  "floor.l")
    ((== d "<rfloor>")  "floor.r")
    ((== d "<lceil>")   "ceil.l")
    ((== d "<rceil>")   "ceil.r")
    ((== d "<||>")      "bar.v.double")
    (else               (tmtypst-math-token d))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hilfsfunktionen für Matrizen, Fallunterscheidungen und Gleichungssysteme
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Tabellenknoten in Zeilen von Zellen zerlegen
(define (tmtypst-math-extract-rows t)
  (cond
    ((not (pair? t)) '())
    ((== (car t) 'tformat)
     (if (pair? (cdr t)) (tmtypst-math-extract-rows (cAr t)) '()))
    ((== (car t) 'table)
     (map (lambda (row)
            (if (and (pair? row) (== (car row) 'row))
                (map (lambda (cell)
                       (if (and (pair? cell) (== (car cell) 'cell) (pair? (cdr cell)))
                           (cadr cell)
                           cell))
                     (cdr row))
                (list row)))
          (cdr t)))
    ((== (car t) 'document)
     (if (and (pair? (cdr t)) (= (length (cdr t)) 1))
         (tmtypst-math-extract-rows (cadr t))
         (map list (cdr t))))
    (else '())))

;; Matrix in Typst-Syntax: mat(delim: ..., a, b; c, d)
(define (tmtypst-math-matrix delim arg)
  (let* ((rows (tmtypst-math-extract-rows arg))
         (row-strs
          (map (lambda (cells)
                 (string-join (map tmtypst-math-serialize cells) ", "))
               rows))
         (delim-arg (if (== delim "(")
                        ""
                        (string-append "delim: \"" (math-escape-string delim) "\", "))))
    (string-append "mat(" delim-arg (string-join row-strs "; ") ")")))

;; Fallunterscheidung (<choice|...>) -> cases(a & b, c & d)
(define (tmtypst-math-choice arg)
  (let* ((rows (tmtypst-math-extract-rows arg))
         (row-strs
          (map (lambda (cells)
                 (string-join (map tmtypst-math-serialize cells) " & "))
               rows)))
    (string-append "cases(" (string-join row-strs ", ") ")")))

;; Gleichungssystem (eqnarray / align) -> Typst Display-Math mit & und \
(define (tmtypst-math-eqnarray arg)
  (let* ((rows (tmtypst-math-extract-rows arg))
         (row-strs
          (map (lambda (cells)
                 (let ((serialized (map tmtypst-math-serialize cells)))
                   (cond
                     ((= (length serialized) 3)
                      (string-append (car serialized) " &" (cadr serialized) " " (caddr serialized)))
                     ((= (length serialized) 2)
                      (let ((rhs (string-trim (cadr serialized))))
                        (if (or (string-starts? rhs "=") (string-starts? rhs "<") (string-starts? rhs ">"))
                            (string-append (car serialized) " &" rhs)
                            (string-append (car serialized) " &= " rhs))))
                     (else
                      (string-join serialized " & ")))))
               rows)))
    (string-join row-strs " \\\n  ")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Concat-Verarbeitung (Tokenisierung + Skript-Bindung)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tmtypst-math-explode x)
  (if (string? x)
      (tmconcat-tokenize-math x)
      (list x)))

;; Token-Liste aus concat verarbeiten und rsub/rsup sauber anhängen
(define (tmtypst-math-concat args)
  (let* ((exploded (apply append (map tmtypst-math-explode args)))
         (structured (tmconcat-structure-scripts exploded)))
    (let loop ((items structured) (acc ""))
      (if (null? items)
          acc
          (let* ((it (car items))
                 (s  (if (string? it)
                         (tmtypst-math-token it)
                         (tmtypst-math-serialize it)))
                 (sep (if (or (== acc "") (== s "")
                              (string-ends? acc " ") (string-starts? s " ")
                              (string-ends? acc "(") (string-starts? s ")")
                              (string-ends? acc "[") (string-starts? s "]")
                              (string-starts? s ",") (string-starts? s ";")
                              (string-starts? s "'") (string-starts? s "_")
                              (string-starts? s "^"))
                          ""
                          " ")))
            (loop (cdr items) (string-append acc sep s)))))))

;; Basis-Ausdruck für Skripte ggf. in Klammern setzen
(define (tmtypst-math-script-arg expr)
  (let ((s (tmtypst-math-serialize expr)))
    (if (<= (string-length s) 1)
        s
        (string-append "(" s ")"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Rekursiver Mathe-AST-Walker
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (tmtypst-math-serialize t)
  (cond
    ((string? t) (tmtypst-math-concat (list t)))
    ((pair? t)
     (let ((tag  (car t))
           (args (cdr t)))
       (case tag
         ;; Sequenzen
         ((concat)   (tmtypst-math-concat args))
         ((document para)
          (string-join (map tmtypst-math-serialize args) " "))
         ((rigid syntax move resize)
          (if (pair? args) (tmtypst-math-serialize (car args)) ""))

         ;; Brüche
         ((frac tfrac dfrac cfrac)
          (if (>= (length args) 2)
              (string-append "(" (tmtypst-math-serialize (car args)) ")/("
                             (tmtypst-math-serialize (cadr args)) ")")
              ""))

         ;; Wurzeln: (sqrt x) oder (sqrt x n)
         ((sqrt)
          (cond
            ((= (length args) 1)
             (string-append "sqrt(" (tmtypst-math-escape-arg (tmtypst-math-serialize (car args))) ")"))
            ((>= (length args) 2)
             (string-append "root(" (tmtypst-math-escape-arg (tmtypst-math-serialize (cadr args))) ", "
                            (tmtypst-math-escape-arg (tmtypst-math-serialize (car args))) ")"))
            (else "")))

         ;; Strukturierte Indizes & Exponenten (von tmconcat-structure-scripts)
         ((rsub!)
          (let ((b (tmtypst-math-serialize (car args)))
                (s (tmtypst-math-serialize (cadr args))))
            (cond
              ((== s "") b)
              ((== b "") (string-append "\"\"_(" s ")"))
              (else (string-append b "_" (if (<= (string-length s) 1) s (string-append "(" s ")")))))))
         ((rsup!)
          (let ((b (tmtypst-math-serialize (car args)))
                (p (tmtypst-math-serialize (cadr args))))
            (cond
              ((== p "") b)
              ((== b "") (string-append "\"\"^(" p ")"))
              (else (string-append b "^" (if (<= (string-length p) 1) p (string-append "(" p ")")))))))
         ((rsubsup!)
          (let* ((b-raw (tmtypst-math-serialize (car args)))
                 (s (tmtypst-math-serialize (cadr args)))
                 (p (tmtypst-math-serialize (caddr args)))
                 (b (if (and (== b-raw "") (or (not (== s "")) (not (== p "")))) "\"\"" b-raw)))
            (string-append
              b
              (if (== s "") "" (string-append "_" (if (<= (string-length s) 1) s (string-append "(" s ")"))))
              (if (== p "") "" (string-append "^" (if (<= (string-length p) 1) p (string-append "(" p ")")))))))
         ((lsub!)
          (string-append "attach(" (tmtypst-math-serialize (car args)) ", bl: "
                         (tmtypst-math-serialize (cadr args)) ")"))
         ((lsup!)
          (string-append "attach(" (tmtypst-math-serialize (car args)) ", tl: "
                         (tmtypst-math-serialize (cadr args)) ")"))
         ((lsubsup!)
          (string-append "attach(" (tmtypst-math-serialize (car args)) ", bl: "
                         (tmtypst-math-serialize (cadr args)) ", tl: "
                         (tmtypst-math-serialize (caddr args)) ")"))

         ;; Ungebundene Indizes/Exponenten (Fallback ohne Basis -> leere Basis "")
         ((rsub)
          (let ((s (tmtypst-math-serialize (car args))))
            (if (== s "") "" (string-append "\"\"_(" s ")"))))
         ((rsup)
          (let ((p (tmtypst-math-serialize (car args))))
            (if (== p "") "" (string-append "\"\"^(" p ")"))))
         ((math)   (if (pair? args) (tmtypst-math-serialize (car args)) ""))
         ((rprime) (math-plain-text (car args)))
         ((lprime) (math-plain-text (car args)))

         ;; Über-/Unterstellung
         ((above)
          (string-append "limits(" (tmtypst-math-serialize (car args)) ")^("
                         (tmtypst-math-serialize (cadr args)) ")"))
         ((below)
          (string-append "limits(" (tmtypst-math-serialize (car args)) ")_("
                         (tmtypst-math-serialize (cadr args)) ")"))

         ;; Große Operatoren
         ((big)
          (if (pair? args) (tmtypst-math-big (car args)) ""))

         ;; Klammerungen
         ((around around*)
          (if (>= (length args) 3)
              (let ((l (tmtypst-math-delim (car args)))
                    (b (tmtypst-math-escape-arg (tmtypst-math-serialize (cadr args))))
                    (r (tmtypst-math-delim (caddr args))))
                (string-append "lr(" l " " b " " r ")"))
              (tmtypst-math-concat args)))
         ((big-around)
          (if (>= (length args) 2)
              (string-append (tmtypst-math-serialize (car args)) " "
                             (tmtypst-math-serialize (cadr args)))
              (tmtypst-math-concat args)))
         ((left mid right)
          (if (pair? args) (tmtypst-math-delim (car args)) ""))

         ;; Akzente & Durchstreichung
         ((wide)  (if (>= (length args) 2)
                      (tmtypst-math-wide (car args) (cadr args))
                      ""))
         ((wide*) (if (>= (length args) 2)
                      (tmtypst-math-wide* (car args) (cadr args))
                      ""))
         ((neg)   (string-append "cancel(" (tmtypst-math-serialize (car args)) ")"))

         ;; Binomialkoeffizienten
         ((binom)
          (if (>= (length args) 2)
              (string-append "binom(" (tmtypst-math-escape-arg (tmtypst-math-serialize (car args))) ", "
                             (tmtypst-math-escape-arg (tmtypst-math-serialize (cadr args))) ")")
              ""))

         ;; Lange Pfeile mit Beschriftung (<long-arrow|arr|above|below>)
         ((long-arrow)
          (let* ((arr-raw (if (pair? args) (car args) "<rightarrow>"))
                 (arr-clean (if (and (string? arr-raw) (string-starts? arr-raw "<rubber-"))
                                (string-append "<" (substring arr-raw 8 (string-length arr-raw)))
                                arr-raw))
                 (arr-sym (if (string? arr-clean) (tmtypst-math-token arr-clean) "->"))
                 (above (if (>= (length args) 2) (tmtypst-math-serialize (cadr args)) ""))
                 (below (if (>= (length args) 3) (tmtypst-math-serialize (caddr args)) "")))
            (cond
              ((and (not (== above "")) (not (== below "")))
               (string-append "limits(" arr-sym ")^(" above ")_(" below ")"))
              ((not (== above ""))
               (string-append "limits(" arr-sym ")^(" above ")"))
              ((not (== below ""))
               (string-append "limits(" arr-sym ")_(" below ")"))
              (else arr-sym))))

         ;; Matrizen & Fallunterscheidungen
         ((matrix pmatrix) (tmtypst-math-matrix "(" (car args)))
         ((bmatrix)        (tmtypst-math-matrix "[" (car args)))
         ((Bmatrix)        (tmtypst-math-matrix "{" (car args)))
         ((det vmatrix)    (tmtypst-math-matrix "|" (car args)))
         ((Vmatrix)        (tmtypst-math-matrix "‖" (car args)))
         ((choice)         (tmtypst-math-choice (car args)))
         ((tabular tabular*) (tmtypst-math-matrix "(" (car args)))
         ((tformat table)  (tmtypst-math-matrix "(" t))

         ;; Text & Schriftstile im Mathemodus
         ((text)
          (string-append "\"" (math-escape-string (math-plain-text (car args))) "\""))
         ((math-up)   (string-append "upright(" (tmtypst-math-serialize (car args)) ")"))
         ((math-bf)   (string-append "bold(" (tmtypst-math-serialize (car args)) ")"))
         ((math-it)   (string-append "italic(" (tmtypst-math-serialize (car args)) ")"))
         ((math-tt)   (string-append "mono(" (tmtypst-math-serialize (car args)) ")"))
         ((math-ss)   (string-append "sans(" (tmtypst-math-serialize (car args)) ")"))
         ((math-cal)  (string-append "cal(" (tmtypst-math-serialize (car args)) ")"))
         ((math-frak) (string-append "frak(" (tmtypst-math-serialize (car args)) ")"))
         ((math-bbb)  (string-append "bb(" (tmtypst-math-serialize (car args)) ")"))

         ;; Abstände im Mathemodus
         ((space hspace) "quad")
         ((label) "")

         ;; <with|...|body> im Mathemodus
         ((with)
          (if (null? args)
              ""
              (let ((body (cAr args))
                    (pairs (cDr args)))
                (let loop ((p pairs))
                  (cond
                    ((or (null? p) (null? (cdr p)))
                     (tmtypst-math-serialize body))
                    ((and (== (car p) "mode") (== (cadr p) "text"))
                     (string-append "\"" (math-escape-string (math-plain-text body)) "\""))
                    ((and (== (car p) "math-font-series") (== (cadr p) "bold"))
                     (string-append "bold(" (tmtypst-math-serialize body) ")"))
                    ((and (== (car p) "math-font") (== (cadr p) "cal"))
                     (string-append "cal(" (tmtypst-math-serialize body) ")"))
                    ((and (== (car p) "math-font") (== (cadr p) "Bbb*"))
                     (string-append "bb(" (tmtypst-math-serialize body) ")"))
                    ((and (== (car p) "math-font") (== (cadr p) "Euler"))
                     (string-append "frak(" (tmtypst-math-serialize body) ")"))
                    (else (loop (cddr p))))))))

         ;; Fallback
         (else
          (string-append "/* TODO-MATH: " (symbol->string tag) " */ "
                         (string-join (map tmtypst-math-serialize args) " "))))))
    (else "")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Einstiegspunkte für Inline- und Display-Mathe (PDF/UA-1 alt-Texte)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Bereinigten Alternativtext für Screenreader / PDF/UA-1 aus Typst-Mathe erzeugen
(define (tmtypst-math-make-alt expr)
  (let* ((s1 (math-string-replace-all expr "\n" " "))
         (s2 (math-string-replace-all s1 "  " " "))
         (s3 (string-trim-right (string-trim s2))))
    (math-escape-string s3)))

(tm-define (tmtypst-inline-math t)
  (let* ((inner (string-trim-right (string-trim (tmtypst-math-serialize t))))
         (alt   (tmtypst-math-make-alt inner)))
    (if (== inner "")
        ""
        (string-append "#math.equation(alt: \"" alt "\", $" inner "$);"))))

(tm-define (tmtypst-display-math t numbered? label-id)
  (let* ((inner (string-trim-right (string-trim (tmtypst-math-serialize t))))
         (alt   (tmtypst-math-make-alt inner))
         (lbl   (if label-id (string-append " <" label-id ">") "")))
    (cond
      ((== inner "") "")
      (numbered?
       (string-append "#math.equation(block: true, numbering: \"(1)\", alt: \"" alt "\", $ " inner " $)" lbl))
      (else
       (string-append "#math.equation(block: true, alt: \"" alt "\", $ " inner " $)" lbl)))))

(tm-define (tmtypst-eqnarray-math t numbered? label-id)
  (let* ((inner (string-trim-right (string-trim (tmtypst-math-eqnarray t))))
         (alt   (tmtypst-math-make-alt inner))
         (lbl   (if label-id (string-append " <" label-id ">") "")))
    (cond
      ((== inner "") "")
      (numbered?
       (string-append "#math.equation(block: true, numbering: \"(1)\", alt: \"" alt "\", $ " inner " $)" lbl))
      (else
       (string-append "#math.equation(block: true, alt: \"" alt "\", $ " inner " $)" lbl)))))
