# Installation Guide (Local User Setup)

This guide explains how to install the **GNU TeXmacs → Typst Accessibility Exporter** plugin locally for your user account (no root/administrator privileges required).

## Prerequisites

- **GNU TeXmacs** (2.1 or newer)
- **Typst** (0.14 or newer; 0.15+ recommended for built-in PDF/A-2b and PDF/UA-1 support)
- **OpenType Fonts** (recommended: *New Computer Modern*; optionally *STIX Two Text*, *TeX Gyre Pagella*, *Linux Libertine*)
- **Optional — veraPDF** (native `verapdf` or Flatpak `org.verapdf.veraPDF`) for automated PDF/A-2b and PDF/UA-1 compliance checks
- **Optional — `xvfb-run`** (Linux) for running headless CLI exports and test scripts

---

## Option 1: Quick Installation (Recommended on Linux / macOS)

From the root directory of this repository, run the included setup script:

```bash
./scripts/setup.sh
```

This creates two symbolic links in your personal TeXmacs configuration directory (`~/.TeXmacs`):

| Target in `~/.TeXmacs` | Source in Repository | Purpose |
| --- | --- | --- |
| `~/.TeXmacs/plugins/typst-export` | `plugin/` | Registers the `typst` export format, converter, and Tools menu assistant |
| `~/.TeXmacs/packages/accessibility` | `plugin/packages/accessibility/` | Provides the `alt-text` stylesheet package (`alt-image`, `decorative-image`, `alt-image-wrap`, `decorative-image-wrap`) |

Because symlinks are used, any `git pull` or local edits to the repository take effect immediately after restarting TeXmacs.

---

## Option 2: Manual Local Installation

If you prefer to copy the files instead of using symlinks (or are installing on a system without Bash):

1. Locate your personal TeXmacs user directory:
   - **Linux / macOS:** `~/.TeXmacs/`
   - **Windows:** `%APPDATA%\TeXmacs\`

2. Create the target directories if they do not exist:
   ```bash
   mkdir -p ~/.TeXmacs/plugins ~/.TeXmacs/packages
   ```

3. Copy (or symlink) the plugin and accessibility package:
   ```bash
   cp -r plugin ~/.TeXmacs/plugins/typst-export
   cp -r plugin/packages/accessibility ~/.TeXmacs/packages/accessibility
   ```

---

## Activating & Verifying the Plugin in TeXmacs

1. **Restart GNU TeXmacs** (if it is already running).
   - If you previously installed plugins, you can also refresh caches via **Tools → Update → Plugins** and **Tools → Update → Styles**, then restart TeXmacs.
2. **Check the Export menu:**
   - Open any `.tm` document and go to **File → Export → Typst...** to export a `.typ` file.
3. **Check the Image Alt-Text Assistant:**
   - Open **Tools → Barrierefreiheit (Typst)** (at the bottom of the **Tools** / **Werkzeuge** menu; wait ~1 second after startup for deferred menu registration):
     - *Alternativtexte fuer alle Bilder bearbeiten...* — walks through all images in the document, pre-filling existing alt texts.
     - *Fehlende Bild-Alternativtexte ergaenzen...* — visits only images that do not yet have an alt text or decorative flag.
   - Click **Speichern** to write the alt text directly into the document tree (the `alt-text` style package is added automatically), then save your `.tm` file (`Ctrl+S`).

---

## Verifying the CLI & PDF/UA Pipeline

You can test the complete export, compilation, and accessibility validation pipeline from the command line:

```bash
./scripts/test-pipeline.sh tests/fixtures/sample.tm
./scripts/test-pipeline.sh tests/fixtures/metadata-lists.tm
./scripts/test-pipeline.sh tests/fixtures/math.tm
./scripts/test-pipeline.sh tests/fixtures/tables-figures.tm
```

Each run performs:
1. Headless TeXmacs export (`texmacs -c input.tm output.typ -q`, via `xvfb-run` if available)
2. Typst compilation (`typst compile --pdf-standard a-2b,ua-1`)
3. PDF/A-2b and PDF/UA-1 validation via `verapdf` (automatically detects both native `verapdf` and the `org.verapdf.veraPDF` Flatpak)

---

## Compiling Exported `.typ` Files Manually

To compile an exported `.typ` file into an accessible, archival PDF:

```bash
typst compile --pdf-standard a-2b,ua-1 document.typ document.pdf
```

To validate the resulting PDF with veraPDF:

```bash
# Native veraPDF
verapdf --format text document.pdf

# Flatpak veraPDF
flatpak run --command=verapdf org.verapdf.veraPDF --format text document.pdf
```

---

## Troubleshooting

- **Menu entry does not appear under Tools:** Restart TeXmacs and wait ~1 second after launch (the menu hook runs on idle so it is not overwritten by TeXmacs's lazy-loaded Tools menu). Verify that `~/.TeXmacs/plugins/typst-export/progs/init-typst-export.scm` exists.
- **`alt-image` or `alt-image-wrap` renders as unknown macro:** Ensure `~/.TeXmacs/packages/accessibility/alt-text.ts` is present, then run **Tools → Update → Styles** and restart TeXmacs.
- **Missing font warnings in Typst:** Install *New Computer Modern* (or check available fonts with `typst fonts`). The exporter automatically falls back to `"New Computer Modern"` if a mapped document font is not installed.

---

## Uninstallation

Remove the local plugin and stylesheet links/directories and restart TeXmacs:

```bash
rm -rf ~/.TeXmacs/plugins/typst-export ~/.TeXmacs/packages/accessibility
```
