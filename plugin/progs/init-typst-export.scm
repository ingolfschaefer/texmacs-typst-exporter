;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : init-typst-export.scm
;; DESCRIPTION : Initialization of the TeXmacs -> Typst Accessibility Exporter
;; COPYRIGHT   : (C) 2026  Ingolf Schäfer, Gemini 4 Neon
;;
;; This software falls under the GNU General Public License version 2 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(plugin-configure typst-export)

(texmacs-module (init-typst-export)
  (:use (convert typst tmtypst)
        (convert typst alt-text-dialog)))

;; 1. Typst-Dateiformat registrieren (erscheint automatisch unter Datei -> Exportieren)
(define-format typst
  (:name "Typst")
  (:suffix "typ"))

;; 2. Converter von TeXmacs-Tree nach Typst registrieren
(converter texmacs-tree typst-document
  (:function-with-options texmacs->typst-document)
  (:option "texmacs->typst:pdf-standard" "a-2b"))

;; 3. Menü-Eintrag unter Werkzeuge (Tools) -> Barrierefreiheit (Typst)
;;    Verzögert mit lazy-define-force, damit tools-menu nicht später überschrieben wird.
(delayed (:idle 1000)
  (lazy-define-force tools-menu)
  (menu-bind tools-menu
    (former)
    ---
    (-> "Barrierefreiheit (Typst)"
        ("Alternativtexte fuer alle Bilder bearbeiten..."
         (typst-edit-all-alt-texts))
        ("Fehlende Bild-Alternativtexte ergaenzen..."
         (typst-edit-missing-alt-texts)))))
