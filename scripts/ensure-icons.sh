#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ICONS_DIR="$ROOT_DIR/icons"
PDF_DIR="$ICONS_DIR/pdf"

if [[ ! -d "$ICONS_DIR" ]]; then
  echo "ERROR: icons directory not found: $ICONS_DIR" >&2
  exit 1
fi

shopt -s nullglob
svgs=("$ICONS_DIR"/*.svg)
shopt -u nullglob

if [[ ${#svgs[@]} -eq 0 ]]; then
  echo "ERROR: no SVG icons found in $ICONS_DIR" >&2
  exit 1
fi

mkdir -p "$PDF_DIR"

if ! command -v inkscape >/dev/null 2>&1; then
  echo "ERROR: inkscape is required to generate PDF icons into $PDF_DIR" >&2
  exit 1
fi

for svg in "${svgs[@]}"; do
  base="$(basename "$svg" .svg)"
  pdf="$PDF_DIR/$base.pdf"
  if [[ ! -f "$pdf" || "$svg" -nt "$pdf" ]]; then
    inkscape "$svg" --export-type=pdf --export-filename="$pdf" >/dev/null 2>&1
  fi
  if [[ ! -f "$pdf" ]]; then
    echo "ERROR: failed to generate $pdf" >&2
    exit 1
  fi
done
