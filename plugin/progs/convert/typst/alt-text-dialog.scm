;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : alt-text-dialog.scm
;; DESCRIPTION : Interactive TeXmacs Tools menu dialog for image alt texts
;; COPYRIGHT   : (C) 2026  Ingolf Schäfer, Gemini 4 Neon
;;
;; This software falls under the GNU General Public License version 2 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (convert typst alt-text-dialog))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Zustand des interaktiven Alternativtext-Assistenten
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define alt-assistant-nodes '())
(define alt-assistant-index 0)
(define alt-assistant-current-alt "")
(define alt-assistant-current-dec #f)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bild-Knoten im aktuellen Dokument suchen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tmtypst-image-tag? t)
  (and (tree-compound? t)
       (in? (tree-label t)
            '(image alt-image decorative-image alt-image-wrap decorative-image-wrap))))

(define (string-trim-both s)
  (if (string? s)
      (string-trim-right (string-trim s))
      ""))

(define (tmtypst-node-missing-alt? t)
  (let ((lbl (tree-label t)))
    (cond
      ((== lbl 'image) #t)
      ((in? lbl '(alt-image alt-image-wrap))
       (or (< (tree-arity t) 2)
           (== (string-trim-both (tm->string (tree-ref t 1))) "")))
      (else #f))))

;; Rekursiv alle relevanten Bildknoten im Dokument sammeln (ohne Doppelzählung)
(define (tmtypst-collect-image-nodes t only-missing?)
  (cond
    ((not (tree-compound? t)) '())
    ((tmtypst-image-tag? t)
     (if (or (not only-missing?) (tmtypst-node-missing-alt? t))
         (list t)
         '()))
    (else
     (append-map (lambda (c) (tmtypst-collect-image-nodes c only-missing?))
                 (tree-children t)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bild-Informationen lesen & in den Dokumentbaum zurückschreiben
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tmtypst-describe-src src-tree)
  (cond
    ((not src-tree) "[Unbekanntes Bild]")
    ((tree-atomic? src-tree)
     (let ((s (tree->string src-tree)))
       (if (== s "") "[Eingebettetes Bild]" s)))
    ((and (tree-compound? src-tree) (== (tree-label src-tree) 'tuple))
     "[Eingebettetes Bild]")
    (else "[Bild]")))

(define (tmtypst-read-node-state node)
  (let ((lbl (tree-label node)))
    (cond
      ((== lbl 'alt-image)
       (list (tmtypst-describe-src (and (> (tree-arity node) 0) (tree-ref node 0)))
             (if (> (tree-arity node) 1) (tm->string (tree-ref node 1)) "")
             #f))
      ((== lbl 'decorative-image)
       (list (tmtypst-describe-src (and (> (tree-arity node) 0) (tree-ref node 0)))
             ""
             #t))
      ((== lbl 'alt-image-wrap)
       (let* ((inner (and (> (tree-arity node) 0) (tree-ref node 0)))
              (src   (and inner (tree-compound? inner) (> (tree-arity inner) 0)
                          (tree-ref inner 0))))
         (list (tmtypst-describe-src src)
               (if (> (tree-arity node) 1) (tm->string (tree-ref node 1)) "")
               #f)))
      ((== lbl 'decorative-image-wrap)
       (let* ((inner (and (> (tree-arity node) 0) (tree-ref node 0)))
              (src   (and inner (tree-compound? inner) (> (tree-arity inner) 0)
                          (tree-ref inner 0))))
         (list (tmtypst-describe-src src)
               ""
               #t)))
      ((== lbl 'image)
       (list (tmtypst-describe-src (and (> (tree-arity node) 0) (tree-ref node 0)))
             ""
             #f))
      (else (list "[Bild]" "" #f)))))

;; Sicherstellen, dass das Stylesheet-Paket "alt-text" aktiv ist
(define (tmtypst-ensure-alt-package!)
  (when (not (has-style-package? "alt-text"))
    (add-style-package "alt-text")))

;; Alternativtext bzw. Dekorativ-Flag dauerhaft im TeXmacs-Dokumentbaum speichern
(define (tmtypst-save-current-node! form-vals)
  (when (and (pair? alt-assistant-nodes)
             (>= alt-assistant-index 0)
             (< alt-assistant-index (length alt-assistant-nodes)))
    (let* ((node (list-ref alt-assistant-nodes alt-assistant-index))
           (lbl  (tree-label node))
           (raw-alt (if (and (pair? form-vals) (string? (car form-vals)))
                        (car form-vals)
                        alt-assistant-current-alt))
           (alt  (string-trim-both raw-alt))
           (dec? alt-assistant-current-dec))
      (set! alt-assistant-current-alt alt)
      (when (or dec? (not (== alt "")))
        (tmtypst-ensure-alt-package!)
        (cond
          ;; 2-arg <alt-image> oder 1-arg <decorative-image>
          ((in? lbl '(alt-image decorative-image))
           (let ((src-stree (tree->stree (tree-ref node 0))))
             (if dec?
                 (tree-set node `(decorative-image ,src-stree))
                 (tree-set node `(alt-image ,src-stree ,alt)))))
          ;; Bereits gewrapptes <image>
          ((in? lbl '(alt-image-wrap decorative-image-wrap))
           (let ((img-stree (tree->stree (tree-ref node 0))))
             (if dec?
                 (tree-set node `(decorative-image-wrap ,img-stree))
                 (tree-set node `(alt-image-wrap ,img-stree ,alt)))))
          ;; Rohes <image|src|w|h|x|y> -> mit alt-image-wrap / decorative-image-wrap umhüllen
          ((== lbl 'image)
           (let ((img-stree (tree->stree node)))
             (if dec?
                 (tree-set node `(decorative-image-wrap ,img-stree))
                 (tree-set node `(alt-image-wrap ,img-stree ,alt))))))))))

;; Zum aktuellen Bild springen und Zustand für den Dialog laden
(define (alt-assistant-load-index! idx)
  (set! alt-assistant-index idx)
  (when (and (pair? alt-assistant-nodes)
             (>= idx 0)
             (< idx (length alt-assistant-nodes)))
    (let* ((node (list-ref alt-assistant-nodes idx))
           (info (tmtypst-read-node-state node)))
      (set! alt-assistant-current-alt (cadr info))
      (set! alt-assistant-current-dec (caddr info))
      (tree-go-to node :start))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dialog-Widgets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-widget ((alt-text-info-widget msg) quit)
  (padded
    (centered (text msg))
    ======
    (bottom-buttons
      >> ("OK" (quit)) >>)))

(tm-widget (alt-text-assistant-widget quit)
  (refreshable "alt-text-assistant"
    (let* ((total (length alt-assistant-nodes))
           (pos   (+ alt-assistant-index 1))
           (node  (list-ref alt-assistant-nodes alt-assistant-index))
           (info  (tmtypst-read-node-state node))
           (src   (car info))
           (title (string-append "Bild " (number->string pos)
                                 " von " (number->string total))))
      (padded
        (form "alt-text-form"
          (bold (text title))
          ===
          (aligned
            (item (text "Bildquelle:")
              (hlist // (text src)))
            (item (text "Alternativtext:")
              (form-input "alt" "string" (list alt-assistant-current-alt) "36em")))
          ===
          (aligned
            (meti (hlist // (text "Dekoratives Bild (PDF/UA-Artefakt, kein Alt-Text)"))
              (toggle (begin
                        (set! alt-assistant-current-dec answer)
                        (refresh-now "alt-text-assistant"))
                      alt-assistant-current-dec)))
          ======
          (bottom-buttons
            (when (> alt-assistant-index 0)
              ("Zurück"
               (begin
                 (tmtypst-save-current-node! (form-values))
                 (alt-assistant-load-index! (- alt-assistant-index 1))
                 (refresh-now "alt-text-assistant"))))
            >>
            ("Abbrechen" (quit))
            // //
            ("Überspringen"
             (if (< (+ alt-assistant-index 1) total)
                 (begin
                   (alt-assistant-load-index! (+ alt-assistant-index 1))
                   (refresh-now "alt-text-assistant"))
                 (quit)))
            // //
            ("Speichern"
             (begin
               (tmtypst-save-current-node! (form-values))
               (if (< (+ alt-assistant-index 1) total)
                   (begin
                     (alt-assistant-load-index! (+ alt-assistant-index 1))
                     (refresh-now "alt-text-assistant"))
                   (quit))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Öffentliche Einstiegspunkte für das Extras-Menü (tools-menu)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (typst-run-alt-assistant only-missing?)
  (let ((nodes (tmtypst-collect-image-nodes (buffer-tree) only-missing?)))
    (if (null? nodes)
        (dialogue-window
          (alt-text-info-widget
            (if only-missing?
                "Alle Bilder in diesem Dokument haben bereits einen Alternativtext."
                "In diesem Dokument wurden keine Bilder gefunden."))
          noop "Bild-Alternativtexte")
        (begin
          (set! alt-assistant-nodes nodes)
          (alt-assistant-load-index! 0)
          (dialogue-window alt-text-assistant-widget noop
                           "Bild-Alternativtexte bearbeiten")))))

(tm-define (typst-edit-all-alt-texts)
  (:interactive #t)
  (typst-run-alt-assistant #f))

(tm-define (typst-edit-missing-alt-texts)
  (:interactive #t)
  (typst-run-alt-assistant #t))
