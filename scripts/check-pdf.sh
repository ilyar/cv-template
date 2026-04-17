#!/usr/bin/env bash
set -euo pipefail

PDF_FILE="${1:?PDF path is required}"
TEXT_FILE="${2:?Text output path is required}"
ALLOW_MULTIPAGE="${ALLOW_MULTIPAGE:-0}"

if [[ ! -f "$PDF_FILE" ]]; then
  echo "ERROR: PDF not found: $PDF_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$TEXT_FILE")"
pdftotext "$PDF_FILE" "$TEXT_FILE"

if [[ ! -s "$TEXT_FILE" ]]; then
  echo "ERROR: extracted text is empty: $TEXT_FILE" >&2
  exit 1
fi

pages=$(pdfinfo "$PDF_FILE" | awk '/^Pages:/ {print $2}')
if [[ -z "$pages" ]]; then
  echo "ERROR: could not determine page count for $PDF_FILE" >&2
  exit 1
fi

if [[ "$ALLOW_MULTIPAGE" != "1" && "$pages" != "1" ]]; then
  echo "ERROR: expected a one-page CV, got $pages pages." >&2
  exit 1
fi

for section in Summary Skills Experience Education; do
  if ! grep -qi "$section" "$TEXT_FILE"; then
    echo "ERROR: extracted text is missing expected section: $section" >&2
    exit 1
  fi
done

chars=$(wc -c < "$TEXT_FILE")
if [[ "$chars" -lt 400 ]]; then
  echo "ERROR: extracted text is unexpectedly short ($chars chars)." >&2
  exit 1
fi

if [[ "$ALLOW_MULTIPAGE" = "1" ]]; then
  echo "PDF checks passed: $pages pages, text layer OK"
else
  echo "PDF checks passed: 1 page, text layer OK"
fi
