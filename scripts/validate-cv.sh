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
function fail(msg, line_no,   prefix, count, lines, i) {
  fatal = 1
  prefix = (line_no > 0 ? "Line " line_no ": " : "")
  count = split(msg, lines, /\n/)
  for (i = 1; i <= count; i++) {
    if (i == 1) print "CV VALIDATION FAILED: " prefix lines[i] > "/dev/stderr"
    else print "CV VALIDATION FAILED: " lines[i] > "/dev/stderr"
  }
  exit 1
}
function bt(s) {
  return "`" s "`"
}
function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}
function looks_like_url(v) {
  return v ~ /^(https?:\/\/|mailto:|tel:)/
}
function current_section_order(delim,   seq, i) {
  if (delim == "") delim = " -> "
  seq = ""
  for (i = 1; i <= section_count; i++) seq = seq (i > 1 ? delim : "") sections[i]
  return seq == "" ? "(none)" : seq
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
  seq = current_section_order("|")
  for (i = 1; i <= allowed_order_count; i++) if (seq == allowed_order[i]) return 1
  return 0
}
function unknown_header_key_message(key,   lowered, msg) {
  lowered = tolower(key)
  msg = "unknown header key " bt(key) "."
  msg = msg "\nAllowed header keys before the first " bt("##") " section: " header_keys_list "."
  if (index(lowered, "handle") > 0 || index(lowered, "username") > 0) {
    msg = msg "\nHandles/usernames are not supported as standalone header fields; move them to " bt("## Structured summary") " or express them via a supported contact key such as " bt("Telegram") "."
  } else if (index(lowered, "status") > 0 || index(lowered, "evidence") > 0 || index(lowered, "note") > 0) {
    msg = msg "\nNarrative notes belong in " bt("## Structured summary") ", not in the header."
  } else {
    msg = msg "\nOnly rendered header metadata is allowed before the first section; move free-form notes into " bt("## Structured summary") "."
  }
  return msg
}
function unknown_service_key_message(section_name, key, allowed_list,   msg) {
  msg = "unknown " section_name " key " bt(key) "."
  msg = msg "\nAllowed keys in " bt(section_name) ": " allowed_list "."
  msg = msg "\nArbitrary services are allowed only when the value is a URL, for example " bt("- YouTube: https://...") "."
  return msg
}
function unknown_experience_key_message(key,   msg) {
  msg = "unknown experience key " bt(key) "."
  msg = msg "\nAllowed experience keys: " exp_keys_list "."
  msg = msg "\nPut extra links, metrics, timestamps, or public-source notes into " bt("Summary:") ", " bt("Delivery:") ", or " bt("Constraint:") "."
  return msg
}
function unknown_project_key_message(key,   msg) {
  msg = "unknown project key " bt(key) "."
  msg = msg "\nAllowed project keys: " project_keys_list "."
  msg = msg "\nPut extra facts into " bt("Summary:") ", " bt("Scope:") ", or " bt("Constraint:") "."
  return msg
}
function unknown_education_key_message(key,   msg) {
  msg = "unknown Education key " bt(key) "."
  msg = msg "\nAllowed Education keys: " education_keys_list "."
  msg = msg "\nKeep unsupported details as plain bullets under the education entry."
  return msg
}
function invalid_employment_message(value,   msg) {
  msg = "invalid " bt("Employment:") " value " bt(value) "."
  msg = msg "\nAllowed values: " bt("Full-time") ", " bt("Part-time") "."
  msg = msg "\nFor contest, freelance, contract, or public-source notes, keep the detail in " bt("Summary:") " or " bt("Constraint:") " instead."
  return msg
}
function unknown_section_message(name,   lowered, msg) {
  lowered = tolower(name)
  msg = "unsupported top-level section " bt(name) "."
  msg = msg "\nAllowed top-level sections: " allowed_sections_list "."
  msg = msg "\nAllowed section orders: " allowed_section_orders_list "."
  if (lowered == "awards and recognition") {
    msg = msg "\nMove awards into " bt("#### Public highlights") " under a relevant experience entry, or summarize them in " bt("## Structured summary") "."
  } else if (lowered == "public evidence limitations") {
    msg = msg "\nMove source limitations into " bt("## Structured summary") " or into a " bt("Constraint:") " bullet inside an experience/project block."
  } else {
    msg = msg "\nIf this is supporting context rather than a renderable block, move it into " bt("## Structured summary") " or an experience bullet."
  }
  return msg
}
function missing_section_message(name,   msg) {
  msg = "missing required section " bt("## " name) "."
  if (name == "Structured summary") {
    msg = msg "\nAdd at least one bullet such as " bt("- Short factual summary.") "."
  } else if (name == "Skills inventory") {
    msg = msg "\nAdd at least one category such as " bt("### Category") " followed by bullet items."
  } else if (name == "Professional experience") {
    msg = msg "\nAdd at least one entry like " bt("### Date | Company | Role") "."
  } else if (name == "Education") {
    msg = msg "\nMinimal placeholder example: " bt("## Education") ", " bt("### Not publicly listed - Public information only") ", " bt("- Degree: Not publicly listed") "."
  }
  return msg
}
BEGIN {
  header_keys_list = bt("Headline") ", " bt("Location")
  basics_keys_list = bt("Headline") ", " bt("Email") ", " bt("Location") ", " bt("Phone") ", " bt("Telegram") ", " bt("LinkedIn") ", " bt("GitHub") ", " bt("Booking") ", " bt("Calendly")
  contact_keys_list = bt("Email") ", " bt("Location") ", " bt("Phone") ", " bt("Telegram") ", " bt("Booking") ", " bt("Calendly")
  profile_keys_list = bt("LinkedIn") ", " bt("GitHub")
  exp_keys_list = bt("Employment") ", " bt("Summary") ", " bt("Responsibilities") ", " bt("Scope") ", " bt("Delivery") ", " bt("Stack") ", " bt("Domain") ", " bt("Product stage") ", " bt("Tooling") ", " bt("Report artifacts") ", " bt("Constraint") ", " bt("Desktop") ", " bt("Mobile app")
  project_keys_list = bt("Status") ", " bt("Summary") ", " bt("Scope") ", " bt("Frontend") ", " bt("Backend") ", " bt("Mobile app") ", " bt("Desktop") ", " bt("Constraint")
  education_keys_list = bt("Degree") ", " bt("Area of knowledge") ", " bt("Direction of preparation") ", " bt("Specialty") ", " bt("Qualification level")
  allowed_sections_list = bt("Basics") ", " bt("Contact") ", " bt("Profile") ", " bt("Structured summary") ", " bt("Skills inventory") ", " bt("Professional experience") ", " bt("Education")
  allowed_section_orders_list = bt("Structured summary -> Skills inventory -> Professional experience -> Education") ", " \
                                bt("Profile -> Structured summary -> Skills inventory -> Professional experience -> Education") ", " \
                                bt("Contact -> Structured summary -> Skills inventory -> Professional experience -> Education") ", " \
                                bt("Contact -> Profile -> Structured summary -> Skills inventory -> Professional experience -> Education") ", " \
                                bt("Basics -> Structured summary -> Skills inventory -> Professional experience -> Education")

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

  allowed_sections["Basics"] = 1
  allowed_sections["Contact"] = 1
  allowed_sections["Profile"] = 1
  allowed_sections["Structured summary"] = 1
  allowed_sections["Skills inventory"] = 1
  allowed_sections["Professional experience"] = 1
  allowed_sections["Education"] = 1

  allowed_order[++allowed_order_count] = "Basics|Structured summary|Skills inventory|Professional experience|Education"
  allowed_order[++allowed_order_count] = "Structured summary|Skills inventory|Professional experience|Education"
  allowed_order[++allowed_order_count] = "Profile|Structured summary|Skills inventory|Professional experience|Education"
  allowed_order[++allowed_order_count] = "Contact|Structured summary|Skills inventory|Professional experience|Education"
  allowed_order[++allowed_order_count] = "Contact|Profile|Structured summary|Skills inventory|Professional experience|Education"
}
{
  raw = $0
  sub(/\r$/, "", raw)
  trimmed = trim(raw)
  if (trimmed == "") next

  if (first_nonempty == 0) {
    first_nonempty = NR
    if (trimmed !~ /^#[[:space:]]+.+$/) fail("first non-empty line must be " bt("# Name") ".", NR)
    next
  }

  if (trimmed ~ /^##[[:space:]]+.+$/) {
    section = trimmed
    sub(/^##[[:space:]]+/, "", section)
    section = trim(section)
    if (!(section in allowed_sections)) fail(unknown_section_message(section), NR)
    if (section in seen_sections) fail("duplicate top-level section " bt(section) ".\nEach supported top-level section may appear at most once.", NR)
    sections[++section_count] = section
    seen_sections[section] = 1
    current_skill = ""
    in_experience = 0
    current_subsection = ""
    in_highlights = 0
    project_plain_count = 0
    exp_plain_count = 0
    next
  }

  if (section == "") {
    if (trimmed !~ /^-[[:space:]]+/) fail("content before the first " bt("##") " section must be header bullets like " bt("- Headline: ...") ".\nAllowed header keys: " header_keys_list ".", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("header bullet must be " bt("- Key: value") ".", NR)
    if (!(pair_key in header_keys)) fail(unknown_header_key_message(pair_key), NR)
    if (pair_value == "") fail("header value is empty for key " bt(pair_key) ".", NR)
    next
  }

  if (section == "Basics") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Basics must contain only " bt("- Key: value") " bullets.", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Basics bullet must be " bt("- Key: value") ".", NR)
    if (!(pair_key in basics_keys) && !looks_like_url(pair_value)) fail(unknown_service_key_message("Basics", pair_key, basics_keys_list), NR)
    if (pair_value == "") fail("Basics value is empty for key " bt(pair_key) ".", NR)
    next
  }

  if (section == "Contact") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Contact must contain only " bt("- Key: value") " bullets.", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Contact bullet must be " bt("- Key: value") ".", NR)
    if (!(pair_key in contact_keys) && !looks_like_url(pair_value)) fail(unknown_service_key_message("Contact", pair_key, contact_keys_list), NR)
    if (pair_value == "") fail("Contact value is empty for key " bt(pair_key) ".", NR)
    next
  }

  if (section == "Profile") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Profile must contain only " bt("- Key: value") " bullets.", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text)) fail("Profile bullet must be " bt("- Key: value") ".", NR)
    if (!(pair_key in profile_keys) && !looks_like_url(pair_value)) fail(unknown_service_key_message("Profile", pair_key, profile_keys_list), NR)
    if (pair_value == "") fail("Profile value is empty for key " bt(pair_key) ".", NR)
    next
  }

  if (section == "Structured summary") {
    if (trimmed !~ /^-[[:space:]]+/) fail("Structured summary must contain only bullet lines like " bt("- Short factual summary.") ".", NR)
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
    if (current_skill == "") fail("skill items must be inside a " bt("### Category") " block.", NR)
    if (trimmed !~ /^-[[:space:]]+/) fail("Skills inventory supports only " bt("### Category") " and " bt("- item") " lines.", NR)
    next
  }

  if (section == "Professional experience") {
    if (trimmed ~ /^###[[:space:]]+/) {
      if (trimmed !~ /^###[[:space:]]+.+[[:space:]]+\|[[:space:]]+.+[[:space:]]+\|[[:space:]]+.+$/) fail("experience heading must be " bt("### Date | Company | Role") ".", NR)
      in_experience = 1
      current_subsection = ""
      in_highlights = 0
      project_plain_count = 0
      exp_plain_count = 0
      experience_count++
      next
    }

    if (trimmed ~ /^####[[:space:]]+/) {
      if (!in_experience) fail("project/highlight subsection must be inside an experience entry.", NR)
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
        if (!pair_ok) fail("nested highlight item must be " bt("- Key: value") ".", NR)
        if (pair_key != "submission" && pair_key != "reddit demo" && pair_key != "demo") fail("unsupported nested highlight key " bt(pair_key) ".\nAllowed nested highlight keys: " bt("Submission") ", " bt("Demo") ", " bt("Reddit demo") ".", NR)
        if (pair_value == "") fail("empty nested highlight value for key " bt(pair_key) ".", NR)
        next
      }

      if (in_highlights) {
        lowered = tolower(text)
        if (lowered ~ /^(submission|reddit demo|demo)[[:space:]]*:/) fail("top-level highlight line must be plain text like " bt("- Label - note") ".\nAttach URLs as nested bullets such as " bt("  - Submission: https://...") ".", NR)
        next
      }

      if (current_subsection != "") {
        if (pair_ok) {
          if (!(pair_key in project_keys)) fail(unknown_project_key_message(pair_key), NR)
          if (pair_value == "") fail("empty project value for key " bt(pair_key) ".", NR)
        } else {
          project_plain_count++
          if (project_plain_count > 2) fail("project supports at most 2 plain description bullets.\nUse " bt("Summary:") " or " bt("Scope:") " for more structure.", NR)
        }
        next
      }

      if (!in_experience) fail("experience bullet must be inside an experience heading.", NR)
      if (pair_ok) {
        if (!(pair_key in exp_keys)) fail(unknown_experience_key_message(pair_key), NR)
        if (pair_value == "") fail("empty experience value for key " bt(pair_key) ".", NR)
        if (pair_key == "employment") {
          clean = pair_value
          sub(/\.$/, "", clean)
          if (clean != "Full-time" && clean != "Part-time") fail(invalid_employment_message(clean), NR)
        }
      } else {
        exp_plain_count++
        if (exp_plain_count > 1) fail("experience supports at most 1 plain description bullet.\nUse " bt("Summary:") " for more structure.", NR)
      }
      next
    }

    fail("Professional experience supports only headings and bullet lines.", NR)
  }

  if (section == "Education") {
    if (trimmed ~ /^###[[:space:]]+/) {
      if (trimmed !~ /^###[[:space:]]+.+[[:space:]]+-[[:space:]]+.+$/) fail("Education heading must be " bt("### Date - Institution") ".", NR)
      next
    }
    if (trimmed !~ /^-[[:space:]]+/) fail("Education supports only " bt("### Date - Institution") " and bullet lines.", NR)
    text = trimmed
    sub(/^-[[:space:]]+/, "", text)
    if (parse_pair(text)) {
      if (!(pair_key in education_keys)) fail(unknown_education_key_message(pair_key), NR)
      if (pair_value == "") fail("empty Education value for key " bt(pair_key) ".", NR)
      if (pair_key == "degree") education_has_degree = 1
    }
    next
  }

  fail("internal validator error: reached unsupported section state " bt(section) ".", NR)
}
END {
  if (fatal) exit 1

  if (!("Structured summary" in seen_sections)) fail(missing_section_message("Structured summary"))
  if (!("Skills inventory" in seen_sections)) fail(missing_section_message("Skills inventory"))
  if (!("Professional experience" in seen_sections)) fail(missing_section_message("Professional experience"))
  if (!("Education" in seen_sections)) fail(missing_section_message("Education"))
  if (!section_order_ok()) fail("invalid section order " bt(current_section_order()) ".\nAllowed section orders: " allowed_section_orders_list ".")
  if (summary_count < 1) fail(bt("## Structured summary") " must contain at least one bullet like " bt("- Short factual summary.") ".")
  if (skill_category_count < 1) fail(bt("## Skills inventory") " must contain at least one " bt("### Category") ".")
  if (experience_count < 1) fail(bt("## Professional experience") " must contain at least one experience entry like " bt("### Date | Company | Role") ".")
  if (!education_has_degree) fail("Education must contain a " bt("Degree:") " bullet.\nMinimal placeholder example: " bt("- Degree: Not publicly listed") ".")
  print "Validated " INPUT_NAME
}
' "$input"
