# GNU TeXmacs → Typst Accessibility Exporter

A **GNU TeXmacs** plugin (written in Guile Scheme) that exports TeXmacs documents (`.tm`) to clean, semantic **Typst** (`.typ`) markup so you can compile archival and accessible **PDF/A-2b** and **PDF/UA-1** documents with `typst compile`.

## Features

- **Accessibility-first (PDF/A-2b & PDF/UA-1):**
  - Extracts document title, subtitle, authors, date, language (`lang: "de"`, `"en"`, …), paper size, and OpenType fonts into `#set document(...)`, `#set text(...)`, and `#set page(...)`.
  - Preserves semantic heading structure (`=`, `==`, `===`, …) and automatically clamps skipped heading levels (e.g., level 2 → 4) to satisfy PDF/UA-1 consecutive heading rules.
  - Translates TeXmacs tables (`tabular`, `block`, `tformat`, `table`) into real Typst `#table(...)` elements with `table.header(...)`, column alignments, and `colspan`/`rowspan`.
- **Interactive Image Alt-Text Assistant (TeXmacs Tools Menu):**
  - Accessible directly from **Tools → Barrierefreiheit (Typst)** inside GNU TeXmacs.
  - Walks through images in the open document, jumps to each image, lets you enter an alternative text or mark it as decorative (`#pdf.artifact(...)`), and stores the metadata permanently in the `.tm` file via the `alt-text` stylesheet package.
- **Comprehensive Math Exporter:**
  - Dedicated `tmtypst-math` module supporting inline and display math, numbered equations with cross-references, `eqnarray`/`align`/`alignat`, fractions, square & n-th roots, scripts, big operators, accents, Greek & mathematical symbols, matrices, piecewise `cases`, German open intervals (`]0; 1[`), and automatic `alt` texts on every `#math.equation(...)` for PDF/UA-1 compliance.
- **Master Documents, Slides & Embedded Media:**
  - Recursively resolves `<include|...>` master documents (including book-mode heading levels and `#outline()`).
  - Extracts embedded `raw-data` images alongside the `.typ` file, renders TeXmacs vector `<graphics>`/`<plot-output>` and embedded PDF/EPS figures to PNG via `print-snippet`, and supports Beamer `<screens>` slides.
- **Automated Verification Pipeline:**
  - Includes a headless CLI test script (`xvfb-run` + `texmacs -c` + `typst compile --pdf-standard a-2b,ua-1` + `veraPDF`, supporting both native `verapdf` and the `org.verapdf.veraPDF` Flatpak).

## Quick Start

For detailed setup instructions (including manual installation and troubleshooting), see [INSTALLATION.md](INSTALLATION.md).

```bash
# 1. Link the plugin and accessibility package into ~/.TeXmacs/
./scripts/setup.sh

# 2. Run the end-to-end export, compilation, and veraPDF validation pipeline
./scripts/test-pipeline.sh tests/fixtures/sample.tm
```

Then restart GNU TeXmacs to use:
- **File → Export → Typst...** to export `.typ` files.
- **Tools → Barrierefreiheit (Typst)** to add or edit persistent image alt texts.

## Repository Structure

```text
├── plugin/
│   ├── packages/accessibility/alt-text.ts       # TeXmacs macros for alt-text & decorative images
│   └── progs/
│       ├── init-typst-export.scm                # Format, converter, and Tools menu registration
│       └── convert/typst/
│           ├── tmtypst.scm                      # Main AST -> Typst exporter (text, tables, figures, includes)
│           ├── tmtypst-math.scm                 # Recursive math exporter with PDF/UA-1 alt texts
│           └── alt-text-dialog.scm              # Interactive Tools menu dialog for image alt texts
├── scripts/
│   ├── setup.sh                                 # Local user installation via symlinks in ~/.TeXmacs/
│   └── test-pipeline.sh                         # Headless TeXmacs -> Typst -> veraPDF test pipeline
├── tests/fixtures/                              # Public test documents (text, lists, math, tables, figures)
├── INSTALLATION.md                              # Detailed local user installation guide
├── CONTRIBUTING.md                              # Contribution guidelines
├── AUTHORS.md                                   # Project authors
└── LICENSE                                      # GNU General Public License v2.0 or later
```

## Testing

Run all bundled test fixtures through TeXmacs, Typst (`a-2b,ua-1`), and veraPDF:

```bash
for f in tests/fixtures/*.tm; do
  ./scripts/test-pipeline.sh "$f"
done
```

## Authors

- **Ingolf Schäfer**
- **Gemini 4 Neon**

See [AUTHORS.md](AUTHORS.md) for details.

## License

This project is free software; you can redistribute it and/or modify it under the terms of the **GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version** — matching the licensing spirit of GNU TeXmacs.

See the [LICENSE](LICENSE) file for the full license text.
