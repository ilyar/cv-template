#!/usr/bin/env bash
set -euo pipefail

input='cv.md'
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input="${2:-cv.md}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

awk -v INPUT_NAME="$input" '
function fail(msg, line_no) {
  prefix = (line_no > 0 ? "Line " line_no ": " : "")
  print "CV VALIDATION FAILED: " prefix msg > "/dev/stderr"
  exit 1
}
function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}
function looks_like_url(v) {
  return v ~ /^(https?:\/\/|mailto:|tel:)/
}
function parse_pair(text, pos) {
  pair_key = ""
  pair_value = ""
  pos = index(text, ":")
  if (pos <= 0) return 0
  pair_key = tolower(trim(substr(text, 1, pos - 1)))
  pair_value = trim(substr(text, pos + 1))
  return 1
}
function section_order_ok(seq, i) {
  seq = ""
  for (i = 1; i <= section_count; i++) seq = seq (i > 1 ? "|" : "") sections[i]
  return seq == "Basics|Structured summary|Skills inventory|Professional experience|Education" || \
         seq == "Structured summary|Skills inventory|Professional experience|Education" || \
         seq == "Profile|Structured summary|Skills inventory|Professional experience|Education" || \
         seq == "Contact|Structured summary|Skills inventory|Professional experience|Education" || \
         seq == "Contact|Profile|Structured summary|Skills inventory|Professional experience|Education"
}
BEGIN {
  header_keys["headline"] = 1
  header_keys["location"] = 1

  basics_keys["headline"] = 1
  basics_keys["email"] = 1
  basics_keys["location"] = 1
  basics_keys["phone"] = 1
  basics_keys["telegram"] = 1
  basics_keys["linkedin"] = 1
  basics_keys["github"] = 1
  basics_keys["booking"] = 1
  basics_keys["calendly"] = 1

  contact_keys["email"] = 1
  contact_keys["location"] = 1
  contact_keys["phone"] = 1
  contact_keys["telegram"] = 1
  contact_keys["booking"] = 1
  contact_keys["calendly"] = 1

  profile_keys["linkedin"] = 1
  profile_keys["github"] = 1

  exp_keys["employment"] = 1
  exp_keys["summary"] = 1
  exp_keys["responsibilities"] = 1
  exp_keys["scope"] = 1
  exp_keys["delivery"] = 1
  exp_keys["stack"] = 1
  exp_keys["domain"] = 1
  exp_keys["product stage"] = 1
  exp_keys["tooling"] = 1
  exp_keys["report artifacts"] = 1
  exp_keys["constraint"] = 1
  exp_keys["desktop"] = 1
  exp_keys["mobile app"] = 1

  project_keys["status"] = 1
  project_keys["summary"] = 1
  project_keys["scope"] = 1
  project_keys["frontend"] = 1
  project_keys["backend"] = 1
  project_keys["mobile app"] = 1
  project_keys["desktop"] = 1
  project_keys["constraint"] = 1

  education_keys["degree"] = 1
  education_keys["area of knowledge"] = 1
  education_keys["direction of preparation"] = 1
  education_keys["specialty"] = 1
  education_keys["qualification level"] = 1
}
{
  raw = $0
  sub(/\r$/, "", raw)
  trimmed = trim(raw)
  if (trimmed == "") next

  if (first_nonempty == 0) {
    first_nonempty = NR
    if (trimmed !~ /^#[[:space:]]+.+$/) fail("first non-empty line must be `# Name`", NR)
    next
  }

  if (trimmed ~ /^##[[:space:]]+.+$/) {
    section = trimmed
    sub(/^##[[:space:]]+/, "", section)
    section = trim(section)
    sections[++section_count] = section
    current_skill = ""
    in_experience = 0
    current_subsection = ""
    in_highlights = 0
    project_plain_count = 0
    exp_plain_count = 0
    next
  }

  if (section == "") {
    if (trimmed !~ /^-[[:space:]]+/) fail("content before first `##` section must be header bullets like `- Headline: ...`", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("header bullet must be `- Key: value`", NR)
    if (!(pair_key in header_keys)) fail("unknown header key: " pair_key, NR)
    if (pair_value == "") fail("header value is empty for key: " pair_key, NR)
    next
  }

  if (section == "Basics") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Basics must contain only `- Key: value` bullets", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Basics bullet must be `- Key: value`", NR)
    if (!(pair_key in basics_keys) && !looks_like_url(pair_value)) fail("unknown Basics key: " pair_key "; arbitrary service links must use URL values", NR)
    if (pair_value == "") fail("Basics value is empty for key: " pair_key, NR)
    next
  }

  if (section == "Contact") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Contact must contain only `- Key: value` bullets", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Contact bullet must be `- Key: value`", NR)
    if (!(pair_key in contact_keys) && !looks_like_url(pair_value)) fail("unknown Contact key: " pair_key "; arbitrary service links must use URL values", NR)
    if (pair_value == "") fail("Contact value is empty for key: " pair_key, NR)
    next
  }

  if (section == "Profile") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Profile must contain only `- Key: value` bullets", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Profile bullet must be `- Key: value`", NR)
    if (!(pair_key in profile_keys) && !looks_like_url(pair_value)) fail("unknown Profile key: " pair_key "; arbitrary service links must use URL values", NR)
    if (pair_value == "") fail("Profile value is empty for key: " pair_key, NR)
    next
  }

  if (section == "Structured summary") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Structured summary must contain only bullet lines", NR)
    summary_count++
    next
  }

  if (section == "Skills inventory") {
    if (trimmed ~ /^###[[:space:]]+/) {
      current_skill = trimmed
      sub(/^###[[:space:]]+/, "", current_skill)
      skill_category_count++
      next
    }
    if (current_skill == "") fail("skill items must be inside a `### Category` block", NR)
    if (trimmed !~ /^-[[:space:]]+/) fail("Skills inventory supports only `### Category` and `- item` lines", NR)
    next
  }

  if (section == "Professional experience") {
    if (trimmed ~ /^###[[:space:]]+/) {
      if (trimmed !~ /^###[[:space:]]+.+[[:space:]]+\|[[:space:]]+.+[[:space:]]+\|[[:space:]]+.+$/) fail("experience heading must be `### Date | Company | Role`", NR)
      in_experience = 1
      current_subsection = ""
      in_highlights = 0
      project_plain_count = 0
      exp_plain_count = 0
      experience_count++
      next
    }

    if (trimmed ~ /^####[[:space:]]+/) {
      if (!in_experience) fail("project/highlight subsection must be inside an experience entry", NR)
      current_subsection = trimmed
      sub(/^####[[:space:]]+/, "", current_subsection)
      in_highlights = (current_subsection == "Public highlights")
      project_plain_count = 0
      next
    }

    if (match(raw, /^[ 	]*-[[:space:]]+/)) {
      bullet_line = raw
      sub(/^[ 	]*/, "", bullet_line)
      indent = length(raw) - length(bullet_line)
      sub(/^-[[:space:]]+/, "", bullet_line)
      text = trim(bullet_line)
      pair_ok = parse_pair(text)

      if (in_highlights && indent > 0) {
        if (!pair_ok) fail("nested highlight item must be `- Key: value`", NR)
        if (pair_key != "submission" && pair_key != "reddit demo" && pair_key != "demo") fail("unsupported nested highlight key: " pair_key, NR)
        if (pair_value == "") fail("empty nested highlight value for key: " pair_key, NR)
        next
      }

      if (in_highlights) {
        lowered = tolower(text)
        if (lowered ~ /^(submission|reddit demo|demo)[[:space:]]*:/) fail("top-level highlight line must be plain text like `- Label — note`", NR)
        next
      }

      if (current_subsection != "") {
        if (pair_ok) {
          if (!(pair_key in project_keys)) fail("unknown project key: " pair_key, NR)
          if (pair_value == "") fail("empty project value for key: " pair_key, NR)
        } else {
          project_plain_count++
          if (project_plain_count > 2) fail("project supports at most 2 plain description bullets", NR)
        }
        next
      }

      if (!in_experience) fail("experience bullet must be inside an experience heading", NR)
      if (pair_ok) {
        if (!(pair_key in exp_keys)) fail("unknown experience key: " pair_key, NR)
        if (pair_value == "") fail("empty experience value for key: " pair_key, NR)
        if (pair_key == "employment") {
          clean = pair_value
          sub(/\.$/, "", clean)
          if (clean != "Full-time" && clean != "Part-time") fail("Employment must be `Full-time` or `Part-time`", NR)
        }
      } else {
        exp_plain_count++
        if (exp_plain_count > 1) fail("experience supports at most 1 plain description bullet; use `Summary:` for more structure", NR)
      }
      next
    }

    fail("Professional experience supports only headings and bullet lines", NR)
  }

  if (section == "Education") {
    if (trimmed ~ /^###[[:space:]]+/) {
      if (trimmed !~ /^###[[:space:]]+.+[[:space:]]+-[[:space:]]+.+$/) fail("Education heading must be `### Date - Institution`", NR)
      next
    }
    if (trimmed !~ /^-[[:space:]]+/) fail("Education supports only `### Date - Institution` and bullet lines", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (parse_pair(text)) {
      if (!(pair_key in education_keys)) fail("unknown Education key: " pair_key, NR)
      if (pair_value == "") fail("empty Education value for key: " pair_key, NR)
      if (pair_key == "degree") education_has_degree = 1
    }
    next
  }

  fail("unknown section: " section, NR)
}
END {
  if (!section_order_ok()) fail("invalid section order")
  if (summary_count < 1) fail("`## Structured summary` must contain at least one bullet")
  if (skill_category_count < 1) fail("`## Skills inventory` must contain at least one `### Category`")
  if (experience_count < 1) fail("`## Professional experience` must contain at least one experience entry")
  if (!education_has_degree) fail("Education must contain a `Degree:` bullet")
  print "Validated " INPUT_NAME
}
' "$input"
