;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : tmtypst.scm
;; DESCRIPTION : Conversion of TeXmacs trees into accessible Typst documents
;; COPYRIGHT   : (C) 2026  Ingolf Schäfer, Gemini 4 Neon
;;
;; This software falls under the GNU General Public License version 2 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (convert typst tmtypst)
  (:use (convert tools tmpre)
        (convert tools output)
        (convert tools tmtable)
        (convert typst tmtypst-math)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Export-Zustand für eingebettete Bilder & Benutzer-Makros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define tmtypst-image-serial 0)
(define tmtypst-image-root-url (unix->url "image"))
(define tmtypst-image-root-string "image")
(define tmtypst-user-vars (make-ahash-table))
(define tmtypst-is-book? #f)
(define tmtypst-last-heading-level 0)
(define tmtypst-current-image-alt #f)

(define (tmtypst-init-state!)
  (set! tmtypst-image-serial 0)
  (set! tmtypst-user-vars (make-ahash-table))
  (set! tmtypst-is-book? #f)
  (set! tmtypst-last-heading-level 0)
  (set! tmtypst-current-image-alt #f)
  (let* ((suffix (url-suffix current-save-target))
         (n (+ (string-length suffix) 1)))
    (if (in? suffix '("typ"))
        (begin
          (set! tmtypst-image-root-url (url-unglue current-save-target n))
          (set! tmtypst-image-root-string
                (url->unix (url-tail tmtypst-image-root-url))))
        (begin
          (set! tmtypst-image-root-url (unix->url "image"))
          (set! tmtypst-image-root-string "image")))))

(define (tmtypst-next-image-names ext)
  (set! tmtypst-image-serial (+ tmtypst-image-serial 1))
  (let* ((clean-ext (if (or (not (string? ext)) (== ext "")) "png" ext))
         (postfix (string-append "-" (number->string tmtypst-image-serial) "." clean-ext))
         (name-url (url-glue tmtypst-image-root-url postfix))
         (name-string (string-append tmtypst-image-root-string postfix)))
    (values name-url name-string)))

;; Sucht in einer <with>-Paarliste nach dem Wert eines Schlüssels (z. B. "image-alt")
(define (tmtypst-extract-with-var pairs key)
  (let loop ((p pairs) (res #f))
    (if (or (null? p) (null? (cdr p)))
        res
        (loop (cddr p)
              (if (== (car p) key) (cadr p) res)))))

;; Sucht rekursiv nach einem eingebetteten <alt-image-wrap|img|alt>, <alt-image|src|alt>
;; oder nativem TeXmacs <with|image-alt|alt|...>
(define (tmtypst-find-alt-text t)
  (cond
    ((not (pair? t)) #f)
    ((and (in? (car t) '(alt-image-wrap alt-image)) (>= (length t) 3))
     (tmtypst-plain-text (caddr t)))
    ((and (== (car t) 'with) (>= (length t) 4))
     (let ((val (tmtypst-extract-with-var (cDr (cdr t)) "image-alt")))
       (if val
           (tmtypst-plain-text val)
           (tmtypst-find-alt-text (cAr (cdr t))))))
    (else
     (let loop ((items (cdr t)))
       (if (null? items)
           #f
           (let ((found (tmtypst-find-alt-text (car items))))
             (if found found (loop (cdr items)))))))))

;; TeXmacs-Vektorgrafik (<graphics|...>, <plot-output|...>) als PNG rendern
(define (tmtypst-render-snippet-png t alt-fallback)
  (receive (name-url name-string) (tmtypst-next-image-names "png")
    (print-snippet name-url t #t)
    (if (url-exists? name-url)
        (string-append "#image(\"" (escape-typst-string name-string) "\", alt: \"" (escape-typst-string alt-fallback) "\")")
        (string-append "/* WARNUNG: Grafik konnte nicht gerendert werden */"))))

(define tmtypst-supported-image-formats '("png" "jpg" "jpeg" "gif" "svg" "webp"))

;; Bildquelle auflösen: eingebettete (tuple (raw-data ...) ext) als Datei neben .typ speichern;
;; nicht direkt von Typst unterstützte Formate (z. B. PDF/EPS) via print-snippet nach PNG rendern
(define (tmtypst-resolve-image-src src-node)
  (cond
    ;; Eingebettetes Bild: (tuple (raw-data <bytes>) <format>)
    ((and (pair? src-node) (== (car src-node) 'tuple) (>= (length src-node) 3)
          (pair? (cadr src-node)) (== (caadr src-node) 'raw-data)
          (>= (length (cadr src-node)) 2)
          (string? (cadadr src-node))
          (string? (caddr src-node)))
     (let* ((raw-bytes (cadadr src-node))
            (fmt-raw (string-downcase (cork->utf8 (caddr src-node))))
            (suf (url-suffix fmt-raw))
            (ext (if (== suf "") fmt-raw suf)))
       (if (in? ext tmtypst-supported-image-formats)
           (receive (name-url name-string) (tmtypst-next-image-names ext)
             (string-save raw-bytes name-url)
             name-string)
           (receive (name-url name-string) (tmtypst-next-image-names "png")
             (print-snippet name-url `(image ,src-node "" "" "" "") #t)
             name-string))))
    ;; Verlinkter Dateipfad
    (else
     (let ((path (tmtypst-plain-text src-node)))
       (if (== path "")
           ""
           (let* ((un (unix->url path))
                  (ext (string-downcase (url-suffix un)))
                  (u-target (url-relative current-save-target un)))
             (if (not (in? ext tmtypst-supported-image-formats))
                 ;; z. B. verlinkte PDF/EPS-Datei -> über TeXmacs als PNG rendern
                 (receive (name-url name-string) (tmtypst-next-image-names "png")
                   (print-snippet name-url `(image ,src-node "" "" "" "") #t)
                   name-string)
                 (if (url-exists? u-target)
                     path
                     (let* ((u-src (url-relative current-save-source un))
                            (u-buf (url-relative (current-buffer-url) un))
                            (u-found (cond ((url-exists? u-src) u-src)
                                           ((url-exists? u-buf) u-buf)
                                           (else #f))))
                       (if u-found
                           (receive (name-url name-string) (tmtypst-next-image-names ext)
                             (system-copy u-found name-url)
                             name-string)
                           path))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Font-, Sprach- & Seiten-Mappings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Font-Mapping von TeXmacs-Schriftarten auf OpenType-Fonts für Typst
(define (map-font-to-typst tm-font)
  (cond
    ((== tm-font "roman")     "New Computer Modern")
    ((== tm-font "modern")    "New Computer Modern")
    ((== tm-font "concrete")  "New Computer Modern")
    ((== tm-font "stix")      "STIX Two Text")
    ((== tm-font "pagella")   "TeX Gyre Pagella")
    ((== tm-font "palatino")  "TeX Gyre Pagella")
    ((== tm-font "termes")    "TeX Gyre Termes")
    ((== tm-font "times")     "TeX Gyre Termes")
    ((== tm-font "bonum")     "TeX Gyre Bonum")
    ((== tm-font "schola")    "TeX Gyre Schola")
    ((== tm-font "libertine") "Linux Libertine")
    ((== tm-font "dejavu")    "DejaVu Serif")
    ((== tm-font "heros")     "TeX Gyre Heros")
    ((== tm-font "helvetica") "TeX Gyre Heros")
    (else                     "New Computer Modern")))

;; Typst-Font-Ausdruck mit Fallback auf "New Computer Modern"
(define (typst-font-expr tm-font)
  (let ((mapped (map-font-to-typst tm-font)))
    (if (== mapped "New Computer Modern")
        "\"New Computer Modern\""
        (string-append "(\"" (escape-typst-string mapped) "\", \"New Computer Modern\")"))))

;; Sprach-Mapping für Barrierefreiheit (Screenreader / PDF/UA)
(define (map-lang-to-typst tm-lang)
  (cond
    ((== tm-lang "german")     "de")
    ((== tm-lang "austrian")   "de")
    ((== tm-lang "swiss")      "de")
    ((== tm-lang "english")    "en")
    ((== tm-lang "american")   "en")
    ((== tm-lang "british")    "en")
    ((== tm-lang "french")     "fr")
    ((== tm-lang "spanish")    "es")
    ((== tm-lang "italian")    "it")
    ((== tm-lang "dutch")      "nl")
    ((== tm-lang "portuguese") "pt")
    ((== tm-lang "polish")     "pl")
    ((== tm-lang "russian")    "ru")
    ((== tm-lang "swedish")    "sv")
    ((== tm-lang "danish")     "da")
    ((== tm-lang "norwegian")  "nb")
    ((== tm-lang "finnish")    "fi")
    ((== tm-lang "czech")      "cs")
    (else                      "de")))

;; Seitenformat-Mapping
(define (map-paper-to-typst tm-paper)
  (cond
    ((== tm-paper "a3")      "a3")
    ((== tm-paper "a4")      "a4")
    ((== tm-paper "a5")      "a5")
    ((== tm-paper "letter")  "us-letter")
    ((== tm-paper "legal")   "us-legal")
    ((== tm-paper "16:9")    "presentation-16-9")
    ((== tm-paper "4:3")     "presentation-4-3")
    (else                    "a4")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Escaping & String-Hilfsfunktionen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Einfaches String-Replace in Guile Scheme
(define (string-replace-all str old new)
  (let ((old-len (string-length old)))
    (if (= old-len 0)
        str
        (let loop ((s str) (acc ""))
          (let ((idx (string-contains s old)))
            (if idx
                (loop (substring s (+ idx old-len))
                      (string-append acc (substring s 0 idx) new))
                (string-append acc s)))))))

;; Strings innerhalb von Typst-Anführungszeichen "..." escapen
(define (escape-typst-string s)
  (let* ((s1 (string-replace-all s "\\" "\\\\"))
         (s2 (string-replace-all s1 "\"" "\\\""))
         (s3 (string-replace-all s2 "\n" "\\n")))
    s3))

;; Label-IDs für Typst bereinigen (nur A-Z, a-z, 0-9, _, -, :, .)
(define (sanitize-typst-label s)
  (let* ((u (cork->utf8 s))
         (len (string-length u)))
    (let loop ((i 0) (acc ""))
      (if (>= i len)
          (if (== acc "") "lbl" acc)
          (let ((c (string-ref u i)))
            (if (or (char-alphabetic? c) (char-numeric? c)
                    (== c #\_) (== c #\-) (== c #\:) (== c #\.))
                (loop (+ i 1) (string-append acc (string c)))
                (loop (+ i 1) (string-append acc "-"))))))))

;; Sonderzeichen im Typst-Fließtext maskieren (nach Cork->UTF-8 Konvertierung)
(define (escape-typst-text s)
  (let* ((u   (cork->utf8 s))
         (s1  (string-replace-all u   "\\" "\\\\"))
         (s2  (string-replace-all s1  "#"  "\\#"))
         (s3  (string-replace-all s2  "$"  "\\$"))
         (s4  (string-replace-all s3  "*"  "\\*"))
         (s5  (string-replace-all s4  "_"  "\\_"))
         (s6  (string-replace-all s5  "@"  "\\@"))
         (s7  (string-replace-all s6  "<"  "\\<"))
         (s8  (string-replace-all s7  ">"  "\\>"))
         (s9  (string-replace-all s8  "["  "\\["))
         (s10 (string-replace-all s9  "]"  "\\]"))
         (s11 (string-replace-all s10 "`"  "\\`"))
         (s12 (string-replace-all s11 "~"  "\\~")))
    s12))

;; Reinen Text ohne Markup-Escaping extrahieren (für URLs, Pfade, Metadaten, Code)
(define (tmtypst-plain-text t)
  (cond
    ((string? t) (cork->utf8 t))
    ((pair? t)
     (let ((tag (car t))
           (args (cdr t)))
       (cond
         ((in? tag '(document para))
          (string-join (map tmtypst-plain-text args) "\n"))
         ((== tag 'concat)
          (string-join (map tmtypst-plain-text args) ""))
         ((== tag 'with)
          (if (pair? args) (tmtypst-plain-text (cAr args)) ""))
         ((in? tag '(label))
          "")
         (else
          (string-join (map tmtypst-plain-text args) "")))))
    (else "")))

;; Jede Zeile eines Strings einrücken (für verschachtelte Listen)
(define (indent-lines str prefix)
  (let ((lines (string-split str #\newline)))
    (string-join
      (map (lambda (line)
             (if (== line "") "" (string-append prefix line)))
           lines)
      "\n")))

;; Führende/abschließende Leerzeichen entfernen
(define (string-trim-both s)
  (string-trim-right (string-trim s)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Metadaten- & Initial-Extraktion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Wert aus der <initial><collection>...</collection></initial> Liste auslesen
(define (tmtypst-initial-ref init-tree key default-val)
  (let ((found #f))
    (define (walk t)
      (cond
        ((not (pair? t)) #f)
        ((and (== (car t) 'associate)
              (>= (length t) 3)
              (== (cadr t) key))
         (set! found (caddr t)))
        (else (for-each walk (cdr t)))))
    (walk init-tree)
    (if (string? found) found default-val)))

;; Wert aus einem äußeren <with|key|val|...> im Body extrahieren
(define (tmtypst-body-with-ref body-tree key)
  (cond
    ((and (pair? body-tree) (== (car body-tree) 'with) (>= (length body-tree) 4))
     (let loop ((args (cdr body-tree)))
       (cond
         ((or (null? args) (null? (cdr args)))
          (tmtypst-body-with-ref (cAr body-tree) key))
         ((== (car args) key)
          (cadr args))
         (else (loop (cddr args))))))
    ((and (pair? body-tree) (== (car body-tree) 'document) (= (length body-tree) 2))
     (tmtypst-body-with-ref (cadr body-tree) key))
    (else #f)))

;; Erstes Vorkommen eines bestimmten Tags im Baum finden
(define (tmtypst-find-first t target-tag)
  (cond
    ((not (pair? t)) #f)
    ((== (car t) target-tag) t)
    (else
     (let loop ((rest (cdr t)))
       (if (null? rest)
           #f
           (let ((res (tmtypst-find-first (car rest) target-tag)))
             (if res res (loop (cdr rest)))))))))

;; Alle Vorkommen eines bestimmten Tags im Baum sammeln
(define (tmtypst-find-all t target-tag)
  (cond
    ((not (pair? t)) '())
    ((== (car t) target-tag) (list t))
    (else (append-map (lambda (x) (tmtypst-find-all x target-tag)) (cdr t)))))

;; Autorennamen aus doc-data extrahieren
(define (tmtypst-extract-authors doc-data)
  (let* ((author-nodes (tmtypst-find-all doc-data 'author-name))
         (names (map (lambda (n) (string-trim-both (tmtypst-plain-text (cadr n))))
                     (list-filter author-nodes (lambda (n) (>= (length n) 2))))))
    (list-filter names (lambda (s) (not (== s ""))))))

;; Titel aus doc-data (oder hidden-title) extrahieren
(define (tmtypst-extract-title body-tree)
  (let ((t-node (or (tmtypst-find-first body-tree 'doc-title)
                    (tmtypst-find-first body-tree 'hidden-title))))
    (if (and t-node (>= (length t-node) 2))
        (string-trim-both (tmtypst-plain-text (cadr t-node)))
        "TeXmacs Dokument")))

;; #set document(...) Zeile erzeugen
(define (tmtypst-build-document-header title authors)
  (let* ((title-part (string-append "title: \"" (escape-typst-string title) "\""))
         (author-part
          (cond
            ((null? authors) "")
            ((= (length authors) 1)
             (string-append ", author: \"" (escape-typst-string (car authors)) "\""))
            (else
             (string-append ", author: ("
                            (string-join
                              (map (lambda (a)
                                     (string-append "\"" (escape-typst-string a) "\""))
                                   authors)
                              ", ")
                            ")")))))
    (string-append "#set document(" title-part author-part ")\n")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Einstiegspunkt für den Converter
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (texmacs->typst-document doc opts)
  (tmtypst-init-state!)
  (let* ((stree      (tm->stree doc))
         (is-file    (tmfile? stree))
         (body-tree  (if is-file (tmfile-extract stree 'body) stree))
         (style-tree (if is-file (tmfile-extract stree 'style) '()))
         (init-tree  (if is-file (tmfile-extract stree 'initial) '()))
         (_book      (set! tmtypst-is-book?
                           (or (== style-tree "book")
                               (and (pair? style-tree) (in? "book" style-tree))
                               (if (tmtypst-find-first body-tree 'chapter) #t #f))))
         ;; Sprache: initial -> body <with|language|...> -> tmfile-language -> german
         (lang-init  (tmtypst-initial-ref init-tree "language" #f))
         (lang-with  (tmtypst-body-with-ref body-tree "language"))
         (lang-file  (if is-file (tmfile-language stree) #f))
         (lang-raw   (or lang-with lang-init (if (string? lang-file) lang-file #f) "german"))
         (lang       (map-lang-to-typst lang-raw))
         ;; Font & Schriftgröße & Seitenformat
         (font-init  (tmtypst-initial-ref init-tree "font" #f))
         (font-with  (tmtypst-body-with-ref body-tree "font"))
         (font-raw   (or font-with font-init "roman"))
         (font-expr  (typst-font-expr font-raw))
         (is-beamer? (or (== style-tree "beamer")
                         (and (pair? style-tree) (in? "beamer" style-tree))
                         (if (tmtypst-find-first body-tree 'screens) #t #f)))
         (size-raw   (tmtypst-initial-ref init-tree "font-base-size" "10"))
         (paper-raw  (tmtypst-initial-ref init-tree "page-type" "a4"))
         (paper      (map-paper-to-typst paper-raw))
         (orient-raw (tmtypst-initial-ref init-tree "page-orientation" #f))
         (is-pres-paper? (in? paper '("presentation-16-9" "presentation-4-3")))
         (flipped?   (cond
                       ((== orient-raw "landscape") (not is-pres-paper?))
                       ((== orient-raw "portrait")  #f)
                       (is-beamer?                  (not is-pres-paper?))
                       (else                        #f)))
         (page-opts  (string-append "paper: \"" paper "\""
                                    (if flipped? ", flipped: true" "")))
         ;; Titel & Autoren
         (doc-data   (tmtypst-find-first body-tree 'doc-data))
         (title      (tmtypst-extract-title body-tree))
         (authors    (if doc-data (tmtypst-extract-authors doc-data) '()))
         ;; Body serialisieren
         (body       (tmtypst-serialize body-tree)))
    (string-append
      "// Auto-generated by TeXmacs Typst Accessibility Exporter\n"
      (tmtypst-build-document-header title authors)
      "#set page(" page-opts ")\n"
      "#set text(font: " font-expr ", size: " size-raw "pt, lang: \"" lang "\")\n"
      "#set heading(numbering: \"1.1\")\n"
      "#let tmref(lbl) = context { let els = query(lbl); if els.len() == 0 { [?] } else if els.first().func() in (heading, figure, math.equation, footnote) { ref(lbl) } else { link(lbl)[§] } }\n\n"
      body "\n")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hilfsfunktionen für Listen (itemize / enumerate / description)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tmtypst-item? x)
  (and (pair? x) (in? (car x) '(item item*))))

;; TeXmacs-Listenbaum in logische (!item <tag> <content-doc>) Einträge zerlegen
(define (tmtypst-transform-item-post l)
  (if (not (and (pair? (car l)) (== (caar l) '!item)))
      `(document ,@l)
      `(!item ,(cadar l) (document ,(caddar l) ,@(cdr l)))))

(define (tmtypst-transform-items x)
  (cond
    ((and (pair? x) (== (car x) 'concat) (pair? (cdr x))
          (tmtypst-item? (cadr x)))
     `(!item ,(cadr x) (concat ,@(cddr x))))
    ((and (pair? x) (== (car x) 'concat) (pair? (cdr x)) (pair? (cddr x))
          (pair? (cadr x)) (== (caadr x) 'assign) (tmtypst-item? (caddr x)))
     `(!item ,(caddr x) (concat ,@(cdddr x))))
    ((tmtypst-item? x)
     `(!item ,x ""))
    ((and (pair? x) (== (car x) 'with) (>= (length x) 4))
     `(,@(cDr x) ,(tmtypst-transform-items (cAr x))))
    ((and (pair? x) (== (car x) 'document))
     (let* ((r  (map tmtypst-transform-items (cdr x)))
            (p? (lambda (i) (and (pair? i) (== (car i) '!item))))
            (sr (list-scatter r p? #t))
            (fr (list-filter sr nnull?)))
       `(document ,@(map tmtypst-transform-item-post fr))))
    (else x)))

;; Ein einzelnes Listenelement serialisieren
(define (tmtypst-serialize-list-item marker item-node)
  (if (and (pair? item-node) (== (car item-node) '!item))
      (let* ((itag (cadr item-node))
             (body (caddr item-node))
             (rendered (string-trim-both (tmtypst-serialize body)))
             (lines (string-split rendered #\newline))
             (first-line (if (pair? lines) (car lines) ""))
             (rest-lines (if (and (pair? lines) (pair? (cdr lines))) (cdr lines) '()))
             (prefix
              (if (and (== marker "/") (pair? itag) (== (car itag) 'item*) (>= (length itag) 2))
                  (string-append "/ " (string-trim-both (tmtypst-serialize (cadr itag))) ": ")
                  (string-append marker " "))))
        (if (null? rest-lines)
            (string-append prefix first-line)
            (string-append prefix first-line "\n"
                           (indent-lines (string-join rest-lines "\n") "  "))))
      (tmtypst-serialize item-node)))

(define (tmtypst-serialize-list marker body-arg)
  (let* ((transformed (tmtypst-transform-items body-arg))
         (items (if (and (pair? transformed) (== (car transformed) 'document))
                    (cdr transformed)
                    (list transformed))))
    (string-join
      (map (lambda (it) (tmtypst-serialize-list-item marker it)) items)
      "\n")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hilfsfunktionen für Überschriften, Titelblock, Code, Environment
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Label aus einer Überschrift extrahieren, damit <id> in Typst HINTER der Zeile steht
(define (tmtypst-strip-labels t)
  (cond
    ((not (pair? t)) (cons t '()))
    ((and (== (car t) 'label) (>= (length t) 2))
     (cons "" (list (sanitize-typst-label (tmtypst-plain-text (cadr t))))))
    (else
     (let* ((parts (map tmtypst-strip-labels (cdr t)))
            (clean-args (map car parts))
            (labels (append-map cdr parts)))
       (cons (cons (car t) clean-args) labels)))))

(define (tmtypst-serialize-heading prefix arg numbered?)
  (let* ((raw-lvl (string-length prefix))
         ;; PDF/UA-1 erfordert lückenlose Überschriften-Hierarchie (max. +1 pro Schritt)
         (eff-lvl (max 1 (min raw-lvl (+ tmtypst-last-heading-level 1))))
         (_upd    (set! tmtypst-last-heading-level eff-lvl))
         (eff-prefix (make-string eff-lvl #\=))
         (res (tmtypst-strip-labels arg))
         (clean-arg (car res))
         (labels (cdr res))
         (text (string-trim-both (tmtypst-serialize clean-arg)))
         (lbl-suffix (if (pair? labels)
                         (string-append " <" (car labels) ">")
                         "")))
    (if numbered?
        (string-append eff-prefix " " text lbl-suffix)
        (let ((lvl (number->string eff-lvl)))
          (string-append "#heading(level: " lvl ", numbering: none)[" text "]" lbl-suffix)))))

;; Titelblock aus <doc-data|...> serialisieren
(define (tmtypst-serialize-doc-data args)
  (let* ((doc-node (cons 'doc-data args))
         (subtitle-node (tmtypst-find-first doc-node 'doc-subtitle))
         (date-node (tmtypst-find-first doc-node 'doc-date))
         (authors (tmtypst-extract-authors doc-node))
         (parts (list "#title()")))
    (if (and subtitle-node (>= (length subtitle-node) 2))
        (set! parts (append parts
                            (list (string-append "#text(size: 1.2em, style: \"italic\")["
                                                 (tmtypst-serialize (cadr subtitle-node)) "]")))))
    (if (pair? authors)
        (set! parts (append parts
                            (list (string-append "#text(size: 1.05em)["
                                                 (escape-typst-text (string-join authors ", ")) "]")))))
    (if (and date-node (>= (length date-node) 2))
        (set! parts (append parts
                            (list (string-append "#text(size: 0.95em)["
                                                 (tmtypst-serialize (cadr date-node)) "]")))))
    (string-append "#align(center)[\n  "
                   (string-join parts " \\\n  ")
                   "\n]\n#v(1em)")))

;; Prüfen, ob ein AST-Knoten Block-Struktur hat (für verbatim / code)
(define (tmtypst-block-node? t)
  (and (pair? t) (in? (car t) '(document para))))

;; Code-Block mit Sprach-Tag ausgeben
(define (tmtypst-serialize-code-block lang arg)
  (let ((code (tmtypst-plain-text arg)))
    (string-append "```" lang "\n" code "\n```")))

;; <with|k1|v1|k2|v2|...|body> auswerten
(define (tmtypst-serialize-with args)
  (if (null? args)
      ""
      (if (= (length args) 1)
          (tmtypst-serialize (car args))
          (let* ((body (cAr args))
                 (pairs (cDr args))
                 (alt-val (tmtypst-extract-with-var pairs "image-alt"))
                 (prev-alt tmtypst-current-image-alt)
                 (body-content
                  (begin
                    (when alt-val
                      (set! tmtypst-current-image-alt (tmtypst-plain-text alt-val)))
                    (let ((res (tmtypst-serialize body)))
                      (set! tmtypst-current-image-alt prev-alt)
                      res))))
            (let loop ((p pairs) (content body-content))
              (if (or (null? p) (null? (cdr p)))
                  content
                  (let ((k (car p))
                        (v (cadr p))
                        (rest (cddr p)))
                    (cond
                      ((and (== k "font-series") (== v "bold"))
                       (loop rest (string-append "*" content "*")))
                      ((and (== k "font-shape") (== v "italic"))
                       (loop rest (string-append "_" content "_")))
                      ((and (== k "font-shape") (== v "small-caps"))
                       (loop rest (string-append "#smallcaps[" content "]")))
                      ((and (== k "font-family") (== v "tt"))
                       (loop rest (string-append "`" (tmtypst-plain-text body) "`")))
                      ((and (== k "color") (string? v))
                       (loop rest (string-append "#text(fill: " (tmtypst-map-color v) ")[" content "]")))
                      ((and (== k "mode") (== v "math"))
                       (loop rest (tmtypst-inline-math body)))
                      (else
                       (loop rest content))))))))))

;; Farbnamen auf Typst-Farben mappen
(define (tmtypst-map-color c)
  (cond
    ((string-starts? c "#") (string-append "rgb(\"" (escape-typst-string c) "\")"))
    ((in? c '("black" "white" "red" "green" "blue" "yellow" "orange" "purple" "gray" "navy" "teal" "olive" "maroon" "silver"))
     c)
    ((== c "dark grey")  "luma(80)")
    ((== c "light grey") "luma(200)")
    ((== c "dark blue")  "navy")
    ((== c "dark red")   "maroon")
    ((== c "dark green") "rgb(\"#006400\")")
    (else "black")))

;; Theorem-Umgebung formatieren
(define (tmtypst-serialize-theorem title-label arg)
  (string-append "#block(inset: (left: 1em, y: 0.5em), stroke: (left: 2pt + luma(160)))[\n"
                 "  *" title-label ":* " (tmtypst-serialize arg) "\n]"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hilfsfunktionen für Bilder, Abbildungen und Tabellen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TeXmacs-Länge (z. B. "0.6par", "5cm", "120pt") in Typst-Länge umwandeln
(define (tmtypst-map-length s)
  (cond
    ((or (not (string? s)) (== s "")) #f)
    ((string-ends? s "par")
     (let ((num (string->number (substring s 0 (- (string-length s) 3)))))
       (if num
           (string-append (number->string (inexact->exact (round (* num 100)))) "%")
           #f)))
    ((or (string-ends? s "cm") (string-ends? s "mm")
         (string-ends? s "in") (string-ends? s "pt")
         (string-ends? s "em") (string-ends? s "%"))
     s)
    (else #f)))

;; Bild-Dimensionen (width / height) aus <image|src|w|h|...> formatieren
(define (tmtypst-image-dim-args w-raw h-raw)
  (let* ((w-str (tmtypst-map-length w-raw))
         (h-str (tmtypst-map-length h-raw))
         (w-part (if w-str (string-append ", width: " w-str) ""))
         (h-part (if h-str (string-append ", height: " h-str) "")))
    (string-append w-part h-part)))

;; Eigenschaft aus einer Liste von (key val) Paaren lesen (letzter Wert gewinnt)
(define (tmtypst-prop-ref props key default-val)
  (let loop ((p props) (res default-val))
    (if (null? p)
        res
        (let ((entry (car p)))
          (if (and (pair? entry) (pair? (cdr entry)) (== (car entry) key))
              (loop (cdr p) (cadr entry))
              (loop (cdr p) res))))))

;; TeXmacs cell-halign auf Typst align mappen
(define (tmtypst-map-halign h)
  (cond
    ((== h "l") "left")
    ((== h "c") "center")
    ((== h "r") "right")
    (else       "auto")))

;; Prüfen, ob eine Zelle fett formatiert ist (Heuristik für Kopfzeile)
(define (tmtypst-cell-bold? cell-tree cell-props)
  (or (== (tmtypst-prop-ref cell-props "font-series" "") "bold")
      (and (pair? cell-tree)
           (or (== (car cell-tree) 'strong)
               (and (== (car cell-tree) 'cell)
                    (pair? (cdr cell-tree))
                    (pair? (cadr cell-tree))
                    (== (caadr cell-tree) 'strong))))))

;; Prüfen, ob Zeile 1 eine Kopfzeile ist
(define (tmtypst-header-row? row-cells row-props force-header?)
  (or force-header?
      (let loop ((cells row-cells) (props row-props))
        (if (or (null? cells) (null? props))
            #f
            (let* ((cp (car props))
                   (bb (tmtypst-prop-ref cp "cell-bborder" ""))
                   (bg (tmtypst-prop-ref cp "cell-background" "")))
              (if (or (and (not (== bb "")) (not (== bb "0ln")))
                      (not (== bg ""))
                      (tmtypst-cell-bold? (car cells) cp))
                  #t
                  (loop (cdr cells) (cdr props))))))))

;; Tabelle (tformat / table) in echtes Typst #table(...) serialisieren
(define (tmtypst-serialize-table t bordered? force-header?)
  (let* ((norm  (tmtable-complete (tmtable-format-up (tmtable-normalize t))))
         (nrows (tmtable-rows norm))
         (ncols (tmtable-cols norm))
         (tbl   (if (and (pair? norm) (== (car norm) 'tformat)) (cAr norm) norm))
         (rows  (if (and (pair? tbl) (== (car tbl) 'table)) (cdr tbl) '())))
    (if (or (= nrows 0) (= ncols 0) (null? rows))
        ""
        (receive (tablef colf rowf cellf) (tmtable-properties* norm)
          (let* ((first-row-props (if (pair? cellf) (car cellf) '()))
                 (aligns (map (lambda (cp) (tmtypst-map-halign (tmtypst-prop-ref cp "cell-halign" "")))
                              first-row-props))
                 (has-explicit-align (let loop ((a aligns))
                                       (cond ((null? a) #f)
                                             ((not (== (car a) "auto")) #t)
                                             (else (loop (cdr a))))))
                 (align-str (if has-explicit-align
                                (string-append "  align: (" (string-join aligns ", ") "),\n")
                                ""))
                 (stroke-str (if bordered?
                                 "  stroke: 0.5pt + luma(140),\n"
                                 "  stroke: (x, y) => if y == 0 { (bottom: 0.8pt + black) } else { (bottom: 0.4pt + luma(200)) },\n"))
                 (covered (make-ahash-table))
                 (use-header? (and (>= nrows 2)
                                   (tmtypst-header-row? (cdar rows) first-row-props force-header?))))
            ;; Einzelne Zeile serialisieren
            (define (serialize-row r-idx row-node r-props)
              (let ((cells (if (and (pair? row-node) (== (car row-node) 'row)) (cdr row-node) '())))
                (let loop ((c-idx 1) (cs cells) (ps r-props) (acc '()))
                  (if (or (null? cs) (null? ps))
                      (reverse acc)
                      (if (ahash-ref covered (cons r-idx c-idx))
                          (loop (+ c-idx 1) (cdr cs) (cdr ps) acc)
                          (let* ((cell-node (car cs))
                                 (cp (car ps))
                                 (body-node (if (and (pair? cell-node) (== (car cell-node) 'cell) (pair? (cdr cell-node)))
                                                (cadr cell-node)
                                                cell-node))
                                 (cspan-s (tmtypst-prop-ref cp "cell-col-span" "1"))
                                 (rspan-s (tmtypst-prop-ref cp "cell-row-span" "1"))
                                 (cspan (or (string->number cspan-s) 1))
                                 (rspan (or (string->number rspan-s) 1))
                                 (halign (tmtypst-map-halign (tmtypst-prop-ref cp "cell-halign" "")))
                                 (content (string-trim-both (tmtypst-serialize body-node))))
                            ;; Überdeckte Zellen markieren
                            (when (or (> cspan 1) (> rspan 1))
                              (let rloop ((dr 0))
                                (when (< dr rspan)
                                  (let cloop ((dc 0))
                                    (when (< dc cspan)
                                      (when (not (and (= dr 0) (= dc 0)))
                                        (ahash-set! covered (cons (+ r-idx dr) (+ c-idx dc)) #t))
                                      (cloop (+ dc 1))))
                                  (rloop (+ dr 1)))))
                            (let ((cell-str
                                   (if (or (> cspan 1) (> rspan 1))
                                       (let ((opts '()))
                                         (when (> cspan 1)
                                           (set! opts (append opts (list (string-append "colspan: " (number->string cspan))))))
                                         (when (> rspan 1)
                                           (set! opts (append opts (list (string-append "rowspan: " (number->string rspan))))))
                                         (when (not (== halign "auto"))
                                           (set! opts (append opts (list (string-append "align: " halign)))))
                                         (string-append "table.cell(" (string-join opts ", ") ")[" content "]"))
                                       (string-append "[" content "]"))))
                              (loop (+ c-idx 1) (cdr cs) (cdr ps) (cons cell-str acc)))))))))
            ;; Alle Zeilen zusammensetzen
            (let* ((row-entries
                    (let loop ((r-idx 1) (rs rows) (ps cellf) (acc '()))
                      (if (or (null? rs) (null? ps))
                          (reverse acc)
                          (loop (+ r-idx 1) (cdr rs) (cdr ps)
                                (cons (serialize-row r-idx (car rs) (car ps)) acc)))))
                   (header-str
                    (if (and use-header? (pair? row-entries))
                        (string-append "  table.header(" (string-join (car row-entries) ", ") "),\n")
                        ""))
                   (body-rows
                    (if (and use-header? (pair? row-entries))
                        (cdr row-entries)
                        row-entries))
                   (body-str
                    (string-join
                      (map (lambda (cells)
                             (string-append "  " (string-join cells ", ") ","))
                           body-rows)
                      "\n")))
              (string-append
                "#table(\n"
                "  columns: " (number->string ncols) ",\n"
                align-str
                stroke-str
                header-str
                body-str "\n)")))))))

;; Prüft, ob ein Figure-Body ein einzelner Bild-/Tabellen-/Plot-Knoten ist (auch in <with|...>)
(define (tmtypst-single-figure-node? node)
  (and (pair? node)
       (cond
         ((== (car node) 'with)
          (and (>= (length node) 2)
               (tmtypst-single-figure-node? (cAr (cdr node)))))
         (else
          (in? (car node)
               '(image alt-image alt-image-wrap decorative-image decorative-image-wrap
                 tabular tabular* wide-tabular block block* wide-block tformat table
                 graphics draw-over draw-under plot-output))))))

;; Abbildung oder Tabelle mit Caption (<big-figure>, <small-figure>, <big-table>, <small-table>)
(define (tmtypst-serialize-figure body-arg caption-arg is-table?)
  (let* ((cap-res (tmtypst-strip-labels caption-arg))
         (clean-cap (car cap-res))
         (cap-labels (cdr cap-res))
         (body-res (tmtypst-strip-labels body-arg))
         (clean-body (car body-res))
         (body-labels (cdr body-res))
         (all-labels (append cap-labels body-labels))
         (lbl-suffix (if (pair? all-labels)
                         (string-append " <" (car all-labels) ">")
                         ""))
         (rendered-body
          (if (and is-table? (pair? clean-body) (in? (car clean-body) '(tabular tabular* wide-tabular block block* wide-block tformat table)))
              (let ((bordered? (in? (car clean-body) '(block block* wide-block)))
                    (inner (if (in? (car clean-body) '(tformat table)) clean-body (cadr clean-body))))
                (tmtypst-serialize-table inner bordered? #t))
              (tmtypst-serialize clean-body)))
         (single-code-node? (tmtypst-single-figure-node? clean-body))
         (body-expr
          (cond
            ((and single-code-node?
                  (or (string-starts? rendered-body "#image(")
                      (string-starts? rendered-body "#table(")
                      (string-starts? rendered-body "#pdf.artifact(")))
             (substring rendered-body 1 (string-length rendered-body)))
            (else
             (string-append "[" rendered-body "]"))))
         (rendered-cap (string-trim-both (tmtypst-serialize clean-cap)))
         (kind-part (if is-table? "  kind: table,\n" "")))
    (string-append
      "#figure(\n"
      kind-part
      "  " body-expr ",\n"
      "  caption: [" rendered-cap "],\n"
      ")" lbl-suffix)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Rekursiver AST-Walker (S-Expression -> Typst String)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tmtypst-serialize t)
  (cond
    ;; Basisfall: Roher Text
    ((string? t) (escape-typst-text t))

    ;; Zusammengesetzter Knoten: (tag arg1 arg2 ...)
    ((pair? t)
     (let ((tag  (car t))
           (args (cdr t)))
       (case tag
         ;; Dokument-Container & Absätze
         ((document) (string-join (list-filter (map tmtypst-serialize args) (lambda (s) (not (== s "")))) "\n\n"))
         ((concat)   (string-join (map tmtypst-serialize args) ""))
         ((para)     (string-join (map tmtypst-serialize args) "\n\n"))

         ;; Metadaten / Titelblock / Abstract
         ((doc-data)       (tmtypst-serialize-doc-data args))
         ((hidden-title)   "")
         ((abstract-data)  (string-join (map tmtypst-serialize args) "\n\n"))
         ((abstract)
          (string-append "#block(inset: 1em, fill: luma(245), radius: 3pt)[\n"
                         "  *Abstract*\n\n  " (tmtypst-serialize (car args)) "\n]"))

         ;; Struktur & Überschriften (wichtig für PDF/UA Lesezeichen & Tag-Tree)
         ((part)           (tmtypst-serialize-heading "=" (car args) #t))
         ((chapter)        (tmtypst-serialize-heading "=" (car args) #t))
         ((section)        (tmtypst-serialize-heading (if tmtypst-is-book? "==" "=") (car args) #t))
         ((subsection)     (tmtypst-serialize-heading (if tmtypst-is-book? "===" "==") (car args) #t))
         ((subsubsection)  (tmtypst-serialize-heading (if tmtypst-is-book? "====" "===") (car args) #t))
         ((paragraph)      (tmtypst-serialize-heading (if tmtypst-is-book? "=====" "====") (car args) #t))
         ((subparagraph)   (tmtypst-serialize-heading (if tmtypst-is-book? "======" "=====") (car args) #t))
         ((part*)          (tmtypst-serialize-heading "=" (car args) #f))
         ((chapter*)       (tmtypst-serialize-heading "=" (car args) #f))
         ((section*)       (tmtypst-serialize-heading (if tmtypst-is-book? "==" "=") (car args) #f))
         ((subsection*)    (tmtypst-serialize-heading (if tmtypst-is-book? "===" "==") (car args) #f))
         ((subsubsection*) (tmtypst-serialize-heading (if tmtypst-is-book? "====" "===") (car args) #f))
         ((paragraph*)     (tmtypst-serialize-heading (if tmtypst-is-book? "=====" "====") (car args) #f))
         ((subparagraph*)  (tmtypst-serialize-heading (if tmtypst-is-book? "======" "=====") (car args) #f))

         ;; Master-Dokumente: <include|datei.tm> & Inhaltsverzeichnis
         ((include)
          (if (or (null? args) (not (string? (car args))))
              ""
              (let* ((rel-path (cork->utf8 (car args)))
                     (base (if (and (defined? 'current-save-source)
                                    (not (== (url->string current-save-source) "")))
                               current-save-source
                               (current-buffer-url)))
                     (u (url-relative base (unix->url rel-path))))
                (if (not (url-exists? u))
                    (string-append "/* WARNUNG: Eingebundene Datei nicht gefunden: " rel-path " */")
                    (with-global current-save-source u
                      (let* ((inc-tree (tree-inclusion u))
                             (inc-st   (tm->stree inc-tree))
                             (inc-body (if (tmfile? inc-st) (tmfile-extract inc-st 'body) inc-st)))
                        (tmtypst-serialize inc-body)))))))
         ((table-of-contents) "#outline()")

         ;; Listen (inkl. Verschachtelung)
         ((itemize itemize-minus itemize-dot itemize-arrow)
          (tmtypst-serialize-list "-" (car args)))
         ((enumerate enumerate-numeric enumerate-roman enumerate-Roman enumerate-alpha enumerate-Alpha)
          (tmtypst-serialize-list "+" (car args)))
         ((description description-compact description-aligned description-dash description-long)
          (tmtypst-serialize-list "/" (car args)))

         ;; Zitate & Blöcke
         ((quotation quote-env)
          (string-append "#quote(block: true)[\n" (tmtypst-serialize (car args)) "\n]"))
         ((verse)
          (string-append "#quote(block: true)[\n" (tmtypst-serialize (car args)) "\n]"))
         ((center)
          (string-append "#align(center)[\n" (tmtypst-serialize (car args)) "\n]"))
         ((indent)
          (string-append "#pad(left: 1.5em)[\n" (tmtypst-serialize (car args)) "\n]"))

         ;; Code-Blöcke & Verbatim
         ((verbatim)
          (if (tmtypst-block-node? (car args))
              (tmtypst-serialize-code-block "" (car args))
              (string-append "`" (tmtypst-plain-text (car args)) "`")))
         ((verbatim-code code) (tmtypst-serialize-code-block "" (car args)))
         ((python-code)        (tmtypst-serialize-code-block "python" (car args)))
         ((cpp-code)           (tmtypst-serialize-code-block "cpp" (car args)))
         ((scheme-code)        (tmtypst-serialize-code-block "scheme" (car args)))
         ((shell-code)         (tmtypst-serialize-code-block "bash" (car args)))
         ((java-code)          (tmtypst-serialize-code-block "java" (car args)))

         ;; Inline-Formatierung (explizite Typst-Funktionen funktionieren auch mitten im Wort, z.B. s#strong[tetig])
         ((strong)         (string-append "#strong[" (tmtypst-serialize (car args)) "]"))
         ((em dfn var)     (string-append "#emph[" (tmtypst-serialize (car args)) "]"))
         ((samp kbd tt)    (string-append "`" (tmtypst-plain-text (car args)) "`"))
         ((abbr acronym)   (tmtypst-serialize (car args)))
         ((name sc)        (string-append "#smallcaps[" (tmtypst-serialize (car args)) "]"))
         ((sf)             (string-append "#text(font: \"DejaVu Sans\")[" (tmtypst-serialize (car args)) "]"))
         ((strike-through) (string-append "#strike[" (tmtypst-serialize (car args)) "]"))
         ((underline)      (string-append "#underline[" (tmtypst-serialize (car args)) "]"))
         ((sup)            (string-append "#super[" (tmtypst-serialize (car args)) "]"))
         ((sub)            (string-append "#sub[" (tmtypst-serialize (car args)) "]"))

         ;; Hyperlinks, Labels, Referenzen, Fußnoten
         ((hlink)
          (if (>= (length args) 2)
              (string-append "#link(\"" (escape-typst-string (tmtypst-plain-text (cadr args))) "\")["
                             (tmtypst-serialize (car args)) "]")
              (tmtypst-serialize (car args))))
         ((slink)
          (let ((url (tmtypst-plain-text (car args))))
            (string-append "#link(\"" (escape-typst-string url) "\")")))
         ((label)
          (string-append "#[] <" (sanitize-typst-label (tmtypst-plain-text (car args))) ">"))
         ((reference)
          (string-append "#tmref(<" (sanitize-typst-label (tmtypst-plain-text (car args))) ">)"))
         ((pageref)
          (string-append "#locate(loc => counter(page).at(<"
                         (sanitize-typst-label (tmtypst-plain-text (car args))) ">).first())"))
         ((footnote)
          (string-append "#footnote[" (tmtypst-serialize (car args)) "]"))

         ;; Umbrüche, Abstände, Linien
         ((next-line new-line) " \\\n")
         ((new-page page-break) "#pagebreak()")
         ((hrule) "#line(length: 100%)")
         ((nbsp) "~")
         ((hspace) " ")
         ((vspace) "#v(1em)")

         ;; Theorem-Umgebungen
         ((theorem theorem*)         (tmtypst-serialize-theorem "Theorem" (car args)))
         ((lemma lemma*)             (tmtypst-serialize-theorem "Lemma" (car args)))
         ((proposition proposition*) (tmtypst-serialize-theorem "Proposition" (car args)))
         ((corollary corollary*)     (tmtypst-serialize-theorem "Korollar" (car args)))
         ((axiom axiom*)             (tmtypst-serialize-theorem "Axiom" (car args)))
         ((definition definition*)   (tmtypst-serialize-theorem "Definition" (car args)))
         ((remark remark*)           (tmtypst-serialize-theorem "Bemerkung" (car args)))
         ((note note*)               (tmtypst-serialize-theorem "Hinweis" (car args)))
         ((example example*)         (tmtypst-serialize-theorem "Beispiel" (car args)))
         ((warning warning*)         (tmtypst-serialize-theorem "Warnung" (car args)))
         ((exercise exercise*)       (tmtypst-serialize-theorem "Übung" (car args)))
         ((proof)
          (string-append "#emph[Beweis.] " (tmtypst-serialize (car args)) " #h(1fr) #sym.qed"))

         ;; Tabellen & Abbildungen
         ((tabular tabular* wide-tabular)
          (tmtypst-serialize-table (car args) #f #f))
         ((block block* wide-block)
          (tmtypst-serialize-table (car args) #t #f))
         ((tformat table)
          (tmtypst-serialize-table t #f #f))
         ((big-figure small-figure)
          (if (>= (length args) 2)
              (tmtypst-serialize-figure (car args) (cadr args) #f)
              (tmtypst-serialize (car args))))
         ((big-table small-table)
          (if (>= (length args) 2)
              (tmtypst-serialize-figure (car args) (cadr args) #t)
              (tmtypst-serialize (car args))))

         ;; Custom-Tag für barrierefreie Bilder: <alt-image|pfad|alt-text>
         ((alt-image)
          (let* ((src (tmtypst-resolve-image-src (car args)))
                 (alt (if (pair? (cdr args)) (tmtypst-plain-text (cadr args)) ""))
                 (w-raw (if (>= (length args) 3) (tmtypst-plain-text (caddr args)) #f))
                 (h-raw (if (>= (length args) 4) (tmtypst-plain-text (cadddr args)) #f))
                 (dims (tmtypst-image-dim-args w-raw h-raw)))
            (string-append "#image(\"" (escape-typst-string src) "\", alt: \"" (escape-typst-string alt) "\"" dims ")")))

         ;; Dekoratives Bild (PDF/UA Artifact)
         ((decorative-image)
          (let ((src (tmtypst-resolve-image-src (car args))))
            (string-append "#pdf.artifact(image(\"" (escape-typst-string src) "\"))")))

         ;; Gewrapptes Bild mit Alt-Text: <alt-image-wrap|<image|src|w|h|x|y>|alt>
         ((alt-image-wrap)
          (let* ((img-node (car args))
                 (alt (if (pair? (cdr args)) (tmtypst-plain-text (cadr args)) ""))
                 (img-args (if (and (pair? img-node) (== (car img-node) 'image)) (cdr img-node) (list img-node)))
                 (src (if (pair? img-args) (tmtypst-resolve-image-src (car img-args)) ""))
                 (w-raw (if (>= (length img-args) 2) (tmtypst-plain-text (cadr img-args)) #f))
                 (h-raw (if (>= (length img-args) 3) (tmtypst-plain-text (caddr img-args)) #f))
                 (dims (tmtypst-image-dim-args w-raw h-raw)))
            (string-append "#image(\"" (escape-typst-string src) "\", alt: \"" (escape-typst-string alt) "\"" dims ")")))

         ;; Gewrapptes dekoratives Bild: <decorative-image-wrap|<image|src|w|h|x|y>>
         ((decorative-image-wrap)
          (let* ((img-node (car args))
                 (img-args (if (and (pair? img-node) (== (car img-node) 'image)) (cdr img-node) (list img-node)))
                 (src (if (pair? img-args) (tmtypst-resolve-image-src (car img-args)) ""))
                 (w-raw (if (>= (length img-args) 2) (tmtypst-plain-text (cadr img-args)) #f))
                 (h-raw (if (>= (length img-args) 3) (tmtypst-plain-text (caddr img-args)) #f))
                 (dims (tmtypst-image-dim-args w-raw h-raw)))
            (string-append "#pdf.artifact(image(\"" (escape-typst-string src) "\"" dims "))")))

         ;; Standard-Bild (nutzt ggf. natives TeXmacs <with|image-alt|...|...>)
         ((image)
          (let* ((src (tmtypst-resolve-image-src (car args)))
                 (w-raw (if (>= (length args) 2) (tmtypst-plain-text (cadr args)) #f))
                 (h-raw (if (>= (length args) 3) (tmtypst-plain-text (caddr args)) #f))
                 (dims (tmtypst-image-dim-args w-raw h-raw)))
            (if (and (string? tmtypst-current-image-alt) (!= tmtypst-current-image-alt ""))
                (string-append "#image(\"" (escape-typst-string src) "\", alt: \"" (escape-typst-string tmtypst-current-image-alt) "\"" dims ")")
                (string-append "/* WARNUNG: Bild ohne Alt-Text */ #image(\"" (escape-typst-string src) "\"" dims ")"))))

         ;; Mathematik (Inline & Display)
         ((math) (tmtypst-inline-math (car args)))
         ((equation)
          (let* ((res (tmtypst-strip-labels (car args)))
                 (clean (car res))
                 (lbl (if (pair? (cdr res)) (cadr res) #f)))
            (tmtypst-display-math clean #t lbl)))
         ((equation*)
          (let* ((res (tmtypst-strip-labels (car args)))
                 (clean (car res))
                 (lbl (if (pair? (cdr res)) (cadr res) #f)))
            (tmtypst-display-math clean #f lbl)))
         ((eqnarray align alignat)
          (let* ((res (tmtypst-strip-labels (car args)))
                 (clean (car res))
                 (lbl (if (pair? (cdr res)) (cadr res) #f)))
            (tmtypst-eqnarray-math clean #t lbl)))
         ((eqnarray* align* alignat*)
          (let* ((res (tmtypst-strip-labels (car args)))
                 (clean (car res))
                 (lbl (if (pair? (cdr res)) (cadr res) #f)))
            (tmtypst-eqnarray-math clean #f lbl)))

         ;; Vektorgrafiken & Plots (als PNG-Snippet gerendert)
         ((graphics draw-over draw-under)
          (tmtypst-render-snippet-png t (or (and (string? tmtypst-current-image-alt) (!= tmtypst-current-image-alt "") tmtypst-current-image-alt)
                                            (tmtypst-find-alt-text t)
                                            "TeXmacs Grafik")))
         ((plot-output)
          (tmtypst-render-snippet-png t (or (and (string? tmtypst-current-image-alt) (!= tmtypst-current-image-alt "") tmtypst-current-image-alt)
                                            (tmtypst-find-alt-text t)
                                            "Mathematischer Funktionsplot")))

         ;; Sonderzeichen, Einrückung & verirrte Mathe-Tags im Textmodus
         ((degreesign) "°")
         ((no-indent no-indent*) "")
         ((rsup) (string-append "#super[" (tmtypst-serialize (car args)) "]"))
         ((rsub) (string-append "#sub[" (tmtypst-serialize (car args)) "]"))
         ((frac around around*) (tmtypst-inline-math t))

         ;; Beamer / Präsentations- & Layout-Tags
         ((screens)
          (string-join (list-filter (map tmtypst-serialize args) (lambda (s) (not (== s ""))))
                       "\n\n#pagebreak()\n\n"))
         ((hidden shown)
          (if (pair? args) (tmtypst-serialize (car args)) ""))
         ((tit)
          (string-append "#text(size: 0.9em, fill: luma(90))[" (tmtypst-serialize (car args)) "]\n#line(length: 100%, stroke: 0.4pt + luma(180))"))
         ((padded-center)
          (string-append "#align(center)[\n" (tmtypst-serialize (car args)) "\n]"))
         ((dueto)
          (string-append "(_" (tmtypst-serialize (car args)) "_) "))
         ((quote)
          (string-append "#quote[" (tmtypst-serialize (car args)) "]"))
         ((no-break)
          (if (pair? args) (tmtypst-serialize (car args)) ""))
         ((space) " ")
         ((vspace*) "#v(1em)")
         ((htab) "#h(1fr)")
         ((datoms repeat)
          (if (pair? args) (tmtypst-serialize (cAr args)) ""))

         ;; Environment-Wrapper (<with|key|val|body>)
         ((with) (tmtypst-serialize-with args))

         ;; Benutzer-Zuweisungen (<assign|name|val>) merken (sofern kein Makro)
         ((assign)
          (when (and (>= (length args) 2) (string? (car args))
                     (not (and (pair? (cadr args)) (== (caadr args) 'macro))))
            (ahash-set! tmtypst-user-vars (string->symbol (car args)) (cadr args)))
          "")

         ;; Interne/unsichtbare TeXmacs-Tags ignorieren
         ((style initial TeXmacs collection associate references auxiliary tmdummy project hide-preamble) "")

         ;; Fallback: Prüfen ob benutzerdefinierte Variable (<myheader>), sonst TODO-TAG
         (else
          (let ((user-val (ahash-ref tmtypst-user-vars tag)))
            (if user-val
                (tmtypst-serialize user-val)
                (string-append "/* TODO-TAG: " (symbol->string tag) " */ "
                               (string-join (map tmtypst-serialize args) " "))))))))
    (else "")))
