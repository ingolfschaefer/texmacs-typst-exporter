#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

INPUT_TM="${1:-tests/fixtures/sample.tm}"
BASENAME=$(basename "$INPUT_TM" .tm)
OUT_TYP="tests/out/${BASENAME}.typ"
OUT_PDF="tests/out/${BASENAME}.pdf"

mkdir -p tests/out

if ! command -v texmacs &> /dev/null; then
    echo "FEHLER: 'texmacs' wurde nicht im PATH gefunden."
    exit 1
fi

if ! command -v typst &> /dev/null; then
    echo "FEHLER: 'typst' wurde nicht im PATH gefunden."
    exit 1
fi

echo "=== 1. TeXmacs CLI Export ($INPUT_TM -> $OUT_TYP) ==="
if command -v xvfb-run &> /dev/null; then
    xvfb-run -a texmacs -c "$INPUT_TM" "$OUT_TYP" -q
else
    echo "Warnung: xvfb-run nicht gefunden, starte texmacs direkt..."
    texmacs -c "$INPUT_TM" "$OUT_TYP" -q
fi

if [ ! -f "$OUT_TYP" ]; then
    echo "FEHLER: $OUT_TYP wurde nicht erzeugt!"
    exit 1
fi

echo "=== 2. Generierter Typst-Code ==="
cat "$OUT_TYP"
echo "=================================="

echo "=== 3. Typst Kompilierung ($OUT_TYP -> $OUT_PDF) ==="
typst compile --root "$PROJECT_ROOT" --pdf-standard a-2b,ua-1 "$OUT_TYP" "$OUT_PDF"

echo "=== 4. PDF/A-2b & PDF/UA-1 Barrierefreiheits-Check ==="
VERAPDF_CMD=()
if command -v verapdf &> /dev/null; then
    VERAPDF_CMD=(verapdf)
elif command -v flatpak &> /dev/null && flatpak info org.verapdf.veraPDF &> /dev/null; then
    VERAPDF_CMD=(flatpak run --command=verapdf org.verapdf.veraPDF)
fi

if [ ${#VERAPDF_CMD[@]} -gt 0 ]; then
    "${VERAPDF_CMD[@]}" --format text "$OUT_PDF"
else
    echo "Info: 'verapdf' nicht installiert (weder nativ noch als Flatpak). Überspringe PDF/A- & PDF/UA-Validierung."
fi

echo "FERTIG: $OUT_PDF erfolgreich erstellt."
