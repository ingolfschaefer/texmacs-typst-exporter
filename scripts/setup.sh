#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_TARGET="$HOME/.TeXmacs/plugins/typst-export"
PACKAGES_TARGET="$HOME/.TeXmacs/packages/accessibility"

mkdir -p "$HOME/.TeXmacs/plugins"
mkdir -p "$HOME/.TeXmacs/packages"

# Symlink für das Plugin anlegen
if [ -L "$PLUGIN_TARGET" ] || [ -e "$PLUGIN_TARGET" ]; then
    rm -rf "$PLUGIN_TARGET"
fi
ln -s "$PROJECT_ROOT/plugin" "$PLUGIN_TARGET"
echo "Plugin verlinkt: $PLUGIN_TARGET -> $PROJECT_ROOT/plugin"

# Symlink für das Alt-Text Stylesheet-Paket anlegen
if [ -L "$PACKAGES_TARGET" ] || [ -e "$PACKAGES_TARGET" ]; then
    rm -rf "$PACKAGES_TARGET"
fi
ln -s "$PROJECT_ROOT/plugin/packages/accessibility" "$PACKAGES_TARGET"
echo "Stylesheet-Paket verlinkt: $PACKAGES_TARGET -> $PROJECT_ROOT/plugin/packages/accessibility"

echo "Setup abgeschlossen! Du kannst jetzt ./scripts/test-pipeline.sh ausführen."
