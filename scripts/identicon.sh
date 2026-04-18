#!/usr/bin/env bash
set -euo pipefail

seed='CV Template'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed)
      seed="${2:-CV Template}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${seed//[[:space:]]/}" ]]; then
  seed='CV Template'
fi

state="$(printf '%s' "$seed" | cksum | awk '{print $1}')"
if [[ -z "$state" || "$state" -eq 0 ]]; then
  state=1
fi

next_rand() {
  state=$(( (state * 1103515245 + 12345) % 2147483647 ))
  if [[ "$state" -le 0 ]]; then
    state=1
  fi
}

fg_palette=(
  '47,128,237'
  '35,111,219'
  '62,145,243'
  '29,98,194'
  '54,121,214'
  '73,152,245'
)
bg_palette=(
  '239,246,255'
  '233,241,255'
  '236,245,255'
  '230,239,252'
  '234,243,255'
  '241,247,255'
)
accent_palette=(
  '154,196,255'
  '137,184,247'
  '167,210,255'
  '122,171,236'
  '146,190,250'
  '176,214,255'
)

next_rand
palette_index=$(( state % ${#fg_palette[@]} ))
fg_rgb="${fg_palette[$palette_index]}"
bg_rgb="${bg_palette[$palette_index]}"
accent_rgb="${accent_palette[$palette_index]}"

coords=(-1.75 -1.05 -0.35 0.35 1.05)
cell_size='0.70'
pattern=()
filled=0

for row in 0 1 2 3 4; do
  for col in 0 1 2; do
    next_rand
    threshold=46
    if [[ "$col" -eq 1 ]]; then
      threshold=62
    fi
    if (( state % 100 < threshold )); then
      pattern+=('1')
      filled=$((filled + 1))
    else
      pattern+=('0')
    fi
  done
done

if [[ "$filled" -lt 5 ]]; then
  pattern[1]='1'
  pattern[4]='1'
  pattern[7]='1'
  pattern[10]='1'
  pattern[13]='1'
fi

printf '\\begingroup\n'
printf '\\definecolor{avatarfg}{RGB}{%s}\n' "$fg_rgb"
printf '\\definecolor{avatarbg}{RGB}{%s}\n' "$bg_rgb"
printf '\\definecolor{avataraccent}{RGB}{%s}\n' "$accent_rgb"
printf '\\begin{tikzpicture}[baseline=(current bounding box.center)]\n'
printf '  \\clip (0,0) circle (2.25cm);\n'
printf '  \\fill[avatarbg] (-2.25,-2.25) rectangle (2.25,2.25);\n'
printf '  \\fill[avataraccent,opacity=0.18] (0,0) circle (1.55cm);\n'

for row in 0 1 2 3 4; do
  y="${coords[$row]}"
  for col in 0 1 2; do
    idx=$((row * 3 + col))
    if [[ "${pattern[$idx]}" != '1' ]]; then
      continue
    fi

    x="${coords[$col]}"
    printf '  \\fill[avatarfg,rounded corners=0.08cm] (%s,%s) rectangle (%s,%s);\n' \
      "$x" "$y" "$(awk -v base="$x" -v size="$cell_size" 'BEGIN { printf "%.2f", base + size }')" \
      "$(awk -v base="$y" -v size="$cell_size" 'BEGIN { printf "%.2f", base + size }')"

    if [[ "$col" -lt 2 ]]; then
      mirror_col=$((4 - col))
      mirror_x="${coords[$mirror_col]}"
      printf '  \\fill[avatarfg,rounded corners=0.08cm] (%s,%s) rectangle (%s,%s);\n' \
        "$mirror_x" "$y" "$(awk -v base="$mirror_x" -v size="$cell_size" 'BEGIN { printf "%.2f", base + size }')" \
        "$(awk -v base="$y" -v size="$cell_size" 'BEGIN { printf "%.2f", base + size }')"
    fi
  done
done

printf '  \\draw[avataraccent,line width=0.08cm,opacity=0.35] (0,0) circle (1.55cm);\n'
printf '  \\fill[avataraccent] (0,0) circle (0.13cm);\n'
printf '  \\draw[accent!55,line width=0.8pt] (0,0) circle (2.25cm);\n'
printf '\\end{tikzpicture}\n'
printf '\\endgroup\n'
