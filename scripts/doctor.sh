#!/usr/bin/env bash
set -euo pipefail

DATA_FILE="${1:-cv.md}"
TEMPLATE_FILE="${2:-templates/CV.template.tex}"

for file in "$DATA_FILE" "$TEMPLATE_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: required file not found: $file" >&2
    exit 1
  fi
done

missing=0
for cmd in bash awk cksum lualatex pdfinfo pdftotext fc-match inkscape; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Install bash, awk, coreutils, LuaLaTeX, fontconfig, JetBrains Mono, poppler-utils, and Inkscape, then rerun." >&2
  exit 1
fi

if ! fc-match 'JetBrains Mono' >/dev/null 2>&1; then
  echo "ERROR: JetBrains Mono font is not available to fontconfig." >&2
  exit 1
fi

echo "Source: $DATA_FILE"
echo "Template: $TEMPLATE_FILE"
echo "bash: $(command -v bash)"
echo "awk: $(command -v awk)"
echo "cksum: $(command -v cksum)"
echo "lualatex: $(command -v lualatex)"
echo "pdfinfo: $(command -v pdfinfo)"
echo "pdftotext: $(command -v pdftotext)"
echo "inkscape: $(command -v inkscape)"
echo "jetbrains-mono: $(fc-match 'JetBrains Mono' | head -n 1)"
