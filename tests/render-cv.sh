#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "TEST FAILED: $1" >&2
  exit 1
}

expect_contains() {
  local needle="$1"
  local file="$2"

  if ! grep -F -- "$needle" "$file" >/dev/null; then
    echo "Expected to find: $needle" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    fail "missing expected text"
  fi
}

expect_invalid() {
  local input="$1"
  local stderr_file="$2"

  if "$ROOT_DIR/scripts/validate-cv.sh" --input "$input" >"$TMP_DIR/stdout.txt" 2>"$stderr_file"; then
    fail "validator unexpectedly accepted $input"
  fi
}

cat >"$TMP_DIR/invalid-header.md" <<'EOF'
# Jane Doe
- Headline: Motion Designer
- Public handle: @janedoe

## Structured summary

- Public profile visible on Telegram.

## Skills inventory

### Design

- Motion design

## Professional experience

### 2026 | Example Studio | Motion Designer

- Summary: Produced explainer videos.

## Education

### Not publicly listed - Public information only

- Degree: Not publicly listed
EOF

expect_invalid "$TMP_DIR/invalid-header.md" "$TMP_DIR/invalid-header.err"
expect_contains 'CV VALIDATION FAILED: Line 3: unknown header key `public handle`.' "$TMP_DIR/invalid-header.err"
expect_contains 'Allowed header keys before the first `##` section: `Headline`, `Location`.' "$TMP_DIR/invalid-header.err"
expect_contains 'Handles/usernames are not supported as standalone header fields; move them to `## Structured summary` or express them via a supported contact key such as `Telegram`.' "$TMP_DIR/invalid-header.err"

cat >"$TMP_DIR/invalid-section.md" <<'EOF'
# Jane Doe
- Headline: Motion Designer

## Structured summary

- Public profile visible on Telegram.

## Skills inventory

### Design

- Motion design

## Professional experience

### 2026 | Example Studio | Motion Designer

- Summary: Produced explainer videos.

## Awards and recognition

- Prize finalist

## Education

### Not publicly listed - Public information only

- Degree: Not publicly listed
EOF

expect_invalid "$TMP_DIR/invalid-section.md" "$TMP_DIR/invalid-section.err"
expect_contains 'unsupported top-level section `Awards and recognition`.' "$TMP_DIR/invalid-section.err"
expect_contains 'Allowed top-level sections: `Basics`, `Contact`, `Profile`, `Structured summary`, `Skills inventory`, `Professional experience`, `Education`.' "$TMP_DIR/invalid-section.err"
expect_contains 'Move awards into `#### Public highlights` under a relevant experience entry, or summarize them in `## Structured summary`.' "$TMP_DIR/invalid-section.err"

cat >"$TMP_DIR/missing-education.md" <<'EOF'
# Jane Doe
- Headline: Motion Designer

## Structured summary

- Public profile visible on Telegram.

## Skills inventory

### Design

- Motion design

## Professional experience

### 2026 | Example Studio | Motion Designer

- Summary: Produced explainer videos.
EOF

expect_invalid "$TMP_DIR/missing-education.md" "$TMP_DIR/missing-education.err"
expect_contains 'CV VALIDATION FAILED: missing required section `## Education`.' "$TMP_DIR/missing-education.err"
expect_contains 'Minimal placeholder example: `## Education`, `### Not publicly listed - Public information only`, `- Degree: Not publicly listed`.' "$TMP_DIR/missing-education.err"

cat >"$TMP_DIR/valid-cv.md" <<'EOF'
# Jane Doe
- Headline: Motion Designer

## Contact

- Telegram: https://t.me/janedoe

## Profile

- YouTube: https://www.youtube.com/@janedoe

## Structured summary

- Motion designer focused on short-form product storytelling.

## Skills inventory

### Design

- Motion design
- Storyboarding

## Professional experience

### 2026 | Example Studio | Motion Designer

- Summary: Produced explainer videos for developer tools.
- Delivery: Demo: https://youtu.be/example

#### Public highlights

- [Template repository](https://github.com/ever-guild/cv-template) - Product launch motion piece.
  - Demo: https://www.youtube.com/watch?v=yhTHQ_-prEM
- [Ever Guild Telegram](https://t.me/everguild) - Public release channel.

### 2025 | Second Studio | Product Designer

- Summary: Designed product pages.

#### Public highlights

- [Second project](https://devpost.com/software/second-project) - Second public highlight.

## Education

### 2020 - Example University

- Degree: BA in Design
EOF

"$ROOT_DIR/scripts/validate-cv.sh" --input "$TMP_DIR/valid-cv.md" >"$TMP_DIR/valid.out"
expect_contains "Validated $TMP_DIR/valid-cv.md" "$TMP_DIR/valid.out"

"$ROOT_DIR/scripts/render-cv.sh" --input "$TMP_DIR/valid-cv.md" --output "$TMP_DIR/cv.tex" --detailed-count 4
[[ -s "$TMP_DIR/cv.tex" ]] || fail "rendered TeX output is empty"
expect_contains '\sectiontitle{Experience}' "$TMP_DIR/cv.tex"
expect_contains '\sectiontitle{Education}' "$TMP_DIR/cv.tex"
expect_contains '\href{\detokenize{https://github.com/ever-guild/cv-template}}' "$TMP_DIR/cv.tex"
expect_contains '\href{\detokenize{https://www.youtube.com/watch?v=yhTHQ_-prEM}}' "$TMP_DIR/cv.tex"
expect_contains '\href{\detokenize{https://t.me/everguild}}' "$TMP_DIR/cv.tex"
expect_contains '\href{\detokenize{https://devpost.com/software/second-project}}' "$TMP_DIR/cv.tex"
expect_contains '/icons/pdf/github.pdf' "$TMP_DIR/cv.tex"
expect_contains '/icons/pdf/youtube.pdf' "$TMP_DIR/cv.tex"
expect_contains '/icons/pdf/telegram.pdf' "$TMP_DIR/cv.tex"
expect_contains '/icons/pdf/devpost.pdf' "$TMP_DIR/cv.tex"
expect_contains '\nobreak\hspace{0.18em}Template repository' "$TMP_DIR/cv.tex"
expect_contains '\nobreak\hspace{0.18em}Ever Guild Telegram' "$TMP_DIR/cv.tex"
expect_contains '\nobreak\hspace{0.18em}Second project' "$TMP_DIR/cv.tex"

echo "tests passed"
