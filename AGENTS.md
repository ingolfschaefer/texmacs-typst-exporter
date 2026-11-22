# Projekt-Instruktionen: GNU TeXmacs -> Typst Accessibility Exporter

## Zielsetzung
Entwickle einen vollständigen, wartbaren Exporter für GNU TeXmacs (in Guile Scheme), der TeXmacs-Dokumente (`.tm`) in sauberen Typst-Code (`.typ`) übersetzt, sodass daraus über `typst compile` barrierefreie, PDF/A- und PDF/UA-konforme PDF-Dateien erstellt werden können.

## Architektur & Dateistruktur
- `plugin/progs/init-typst-export.scm`: Registrierung des Formats (`typst`), des Converters (`texmacs-tree` -> `typst-document`) und der Menüpunkte.
- `plugin/progs/convert/typst/tmtypst.scm`: Hauptlogik für die rekursive AST-Übersetzung (`tm->stree` -> Typst-Markup).
- `plugin/packages/accessibility/alt-text.ts`: TeXmacs-Stylesheet-Paket für barrierefreie Makros (z. B. `<alt-image|src|alt-text>`, `<decorative-image|src>`).
- `scripts/test-pipeline.sh`: Headless-CLI-Pipeline für Linux/Wayland (`xvfb-run` + `texmacs -c` + `typst compile` + optional `verapdf`).
- `tests/fixtures/`: Test-`.tm`-Dateien für verschiedene Dokumenttypen (Text, Mathe, Tabellen, Bilder mit Alt-Texten).

## Wichtige Entwicklungsregeln für den Agenten
1. **Keine Halluzinationen bei TeXmacs-Scheme-APIs:**
   - Nutze die lokal installierten TeXmacs-Exporter als Referenz! Suche auf dem System nach `/usr/share/TeXmacs/progs/convert/` (oder `~/.TeXmacs` / `/usr/local/share/TeXmacs/progs/convert/`), insbesondere `latex/` und `html/`, um die exakten Tag-Namen und Scheme-Hilfsfunktionen (`tm->stree`, `select`, `tree-inner`, `with`, `math`, `frac`, `sqrt`, `big-figure`, `itemize`, `enumerate`, `tabular`) nachzuschlagen.
2. **Test-Driven Vibe Coding:**
   - Nach JEDER Änderung am Scheme-Code muss `./scripts/test-pipeline.sh tests/fixtures/sample.tm` ausgeführt werden.
   - Prüfe die generierte `.typ`-Datei auf `/* TODO-TAG: ... */` Kommentare und implementiere fehlende Tags systematisch.
   - Prüfe, dass `typst compile --pdf-standard a-2b` fehlerfrei durchläuft.
3. **Barrierefreiheit (PDF/UA & WCAG) als oberste Priorität:**
   - **Bilder:** Übersetze `<alt-image|pfad|alt>` zu `#image("pfad", alt: "alt")`. Normale `<image|...>` ohne Alt-Text sollen eine Warnung im Kommentar erzeugen oder auf leeren Alt-Text fallbacken, falls dekorativ.
   - **Struktur:** Übersetze `section`, `subsection`, `subsubsection` konsequent in Typst-Überschriften (`=`, `==`, `===`), damit PDF-Lesezeichen und der Tag-Tree korrekt aufgebaut werden.
   - **Metadaten & Sprache:** Extrahiere Dokumenttitel, Autor und Sprache (`<language|german>` -> `lang: "de"`) aus dem TeXmacs-Dokumentenbaum und schreibe sie in `#set document(...)` und `#set text(...)`.
   - **Tabellen:** Übersetze TeXmacs-Tabellen (`tabular`, `tformat`, `table`, `row`, `cell`) in echte Typst `#table(...)`-Strukturen (mit `table.header(...)` für Kopfzeilen), niemals als ASCII-Art oder manuelle Linien.
   - **Mathematik:** Übersetze TeXmacs-Mathe-Bäume (`math`, `around`, `frac`, `sqrt`, `rsup`, `rsub`, griechische Symbole wie `<alpha>`) sauber in Typst-Mathe-Syntax (`$ ... $`), da Typst diese automatisch im Tagged-PDF zugänglich macht.
4. **Sonderzeichen-Escaping:**
   - Stelle sicher, dass Typst-Steuerzeichen (`#`, `$`, `*`, `_`, `<`, `>`, `@`, `\`, `[`, `]`) im normalen Fließtext sauber escaped werden (`\#`, `\$`, etc.), ohne dabei generierten Typst-Code zu zerstören.

## Empfohlene Reihenfolge der nächsten Aufgaben (Roadmap)
1. **Setup prüfen:** `./scripts/setup.sh` ausführen (legt Symlink nach `~/.TeXmacs/plugins/typst-export` an) und `./scripts/test-pipeline.sh` testen.
2. **Escaping & Basis-Tags vervollständigen:** `escape-typst-text`, Absätze, Listen (`itemize`, `enumerate`, `description`), Zitate, Code-Blöcke und Hyperlinks (`hlink`) implementieren.
3. **Font- & Metadaten-Extraktion:** `<with|font|...>` und `<with|language|...>` aus dem Dokument-Header auslesen und auf OpenType-Fonts (`New Computer Modern`, `STIX Two Text`, `TeX Gyre Pagella`, etc.) mappen.
4. **Mathe-Exporter bauen:** Eigenes Modul `plugin/progs/convert/typst/tmtypst-math.scm` anlegen und rekursive Mathe-Übersetzung implementieren.
5. **Tabellen & Abbildungen (`big-figure`, `small-figure`):** Figuren mit Captions (`#figure(..., caption: [...])`) und echte Typst-Tabellen unterstützen.
6. **Erweiterte Test-Fixtures:** Komplexe `.tm`-Testdateien für Mathe, Tabellen und Abbildungen anlegen und gegen `typst compile` sowie `verapdf` (falls vorhanden) validieren.
