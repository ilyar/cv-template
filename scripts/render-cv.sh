#!/usr/bin/env bash
set -euo pipefail

input='cv.md'
output='cv.tex'
detailed_count='4'
show_all='0'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input="${2:-cv.md}"
      shift 2
      ;;
    --output)
      output="${2:-cv.tex}"
      shift 2
      ;;
    --detailed-count)
      raw="${2:-4}"
      if [[ "${raw,,}" == "full" ]]; then
        show_all='1'
        detailed_count='0'
      else
        detailed_count="$raw"
      fi
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

cwd="$(pwd -P)"
template="$cwd/templates/CV.template.tex"
identicon_script="$cwd/scripts/identicon.sh"
if [[ "$input" = /* ]]; then
  input_path="$input"
else
  input_path="$cwd/$input"
fi
if [[ "$output" = /* ]]; then
  output_path="$output"
else
  output_path="$cwd/$output"
fi
name_for_avatar="$(awk '/^# /{sub(/^# /, ""); print; exit}' "$input_path")"

render_avatar() {
  local candidate abs
  for candidate in cv.png cv.jpg; do
    if [[ -f "$cwd/$candidate" ]]; then
      abs="$cwd/$candidate"
      printf '\\photocircle{\\detokenize{%s}}' "$abs"
      return
    fi
  done

  "$identicon_script" --seed "${name_for_avatar:-CV Template}"
}

avatar_tex="$(render_avatar)"
avatar_tex_awk="${avatar_tex//\\/\\\\}"

awk -v TEMPLATE_FILE="$template" \
    -v OUTPUT_FILE="$output_path" \
    -v CWD="$cwd" \
    -v DETAILED_COUNT="$detailed_count" \
    -v SHOW_ALL="$show_all" \
    -v AVATAR_TEX="$avatar_tex_awk" '
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
function lower(s) { return tolower(s) }
function normalize_key(s) { return lower(trim(s)) }
function normalize_service_kind(s) { s = lower(s); gsub(/[^a-z0-9]+/, "", s); return s }
function append_val(curr, val, sep) { return curr == "" ? val : curr sep val }
function escape_latex(s,    t, bs, tl, cr) {
  t = s
  bs = "\034LATEXBS\034"
  tl = "\034LATEXTL\034"
  cr = "\034LATEXCR\034"
  gsub(/\\/, bs, t)
  gsub(/~/, tl, t)
  gsub(/\^/, cr, t)
  gsub(/\{/, "\\{", t)
  gsub(/\}/, "\\}", t)
  gsub(/#/, "\\#", t)
  gsub(/\$/, "\\$", t)
  gsub(/%/, "\\%", t)
  gsub(/&/, "\\\\&", t)
  gsub(/_/, "\\_", t)
  gsub(bs, "\\textbackslash{}", t)
  gsub(tl, "\\textasciitilde{}", t)
  gsub(cr, "\\textasciicircum{}", t)
  return t
}
function replace_all(str, token, val,   pos, out) {
  out = ""
  while ((pos = index(str, token)) > 0) {
    out = out substr(str, 1, pos - 1) val
    str = substr(str, pos + length(token))
  }
  return out str
}
function parse_pair(text, arr,   pos) {
  delete arr
  pos = index(text, ":")
  if (pos <= 0) return 0
  arr["key"] = normalize_key(substr(text, 1, pos - 1))
  arr["value"] = trim(substr(text, pos + 1))
  return 1
}
function split_list(s, arr,    n, i, tmp) {
  delete arr
  s = trim(s)
  if (s == "") return 0
  n = split(s, tmp, /,[[:space:]]*/)
  count = 0
  for (i = 1; i <= n; i++) {
    if (trim(tmp[i]) != "") arr[++count] = trim(tmp[i])
  }
  return count
}
function push_service(key, value) {
  if (trim(value) == "") return
  service_count++
  service[service_count, "label"] = trim(key)
  service[service_count, "url"] = trim(value)
  service[service_count, "kind"] = normalize_key(key)
}
function is_url_like(v) { return v ~ /^(https?:\/\/|mailto:|tel:)/ }
function display_url(v,   t) {
  t = trim(v)
  sub(/^https?:\/\//, "", t)
  sub(/^www\./, "", t)
  sub(/\/$/, "", t)
  return t
}
function detect_domain(url,   raw, host) {
  raw = trim(url)
  if (raw == "") return ""
  if (raw ~ /^mailto:/) return "email"
  if (raw ~ /^tel:/) return "phone"
  host = raw
  sub(/^https?:\/\//, "", host)
  sub(/[\/?#].*$/, "", host)
  sub(/^www\./, "", host)
  return lower(host)
}
function matches_domain(domain, suffix,   dl, sl) {
  dl = length(domain)
  sl = length(suffix)
  if (domain == suffix) return 1
  if (dl <= sl) return 0
  return substr(domain, dl - sl, sl + 1) == "." suffix
}
function icon_pdf_path(name) { return "\\detokenize{" CWD "/icons/pdf/" name ".pdf}" }
function icon_name_for_link(url, kind,   k, d) {
  k = normalize_service_kind(kind)
  if (k == "location" || k == "lo") return "location"
  if (k == "email") return "email"
  if (k == "phone" || k == "ph") return "phone"
  if (k == "booking" || k == "cal" || k == "calendly" || k == "schedule" || k == "meeting") return "booking"
  if (k == "telegram" || k == "tg") return "telegram"
  if (k == "linkedin" || k == "in") return "linkedin"
  if (k == "github" || k == "gh") return "github"
  if (k == "gitlab" || k == "gl") return "gitlab"
  if (k == "reddit") return "reddit"
  if (k == "x" || k == "twitter") return "x"
  if (k == "youtube") return "youtube"
  if (k == "medium") return "medium"
  if (k == "stackoverflow" || k == "stackexchange") return "stackoverflow"
  if (k == "website" || k == "site" || k == "portfolio" || k == "blog" || k == "homepage") return "world"
  if (k == "devpost" || k == "dorahacks") return "external"

  d = detect_domain(url)
  if (d == "email") return "email"
  if (d == "phone") return "phone"
  if (matches_domain(d, "linkedin.com")) return "linkedin"
  if (matches_domain(d, "github.com")) return "github"
  if (matches_domain(d, "gitlab.com")) return "gitlab"
  if (matches_domain(d, "t.me") || matches_domain(d, "telegram.me") || matches_domain(d, "telegram.org")) return "telegram"
  if (matches_domain(d, "calendly.com") || matches_domain(d, "cal.com")) return "booking"
  if (matches_domain(d, "reddit.com")) return "reddit"
  if (matches_domain(d, "x.com") || matches_domain(d, "twitter.com")) return "x"
  if (matches_domain(d, "youtube.com") || matches_domain(d, "youtu.be")) return "youtube"
  if (matches_domain(d, "medium.com")) return "medium"
  if (matches_domain(d, "stackoverflow.com") || matches_domain(d, "stackexchange.com")) return "stackoverflow"
  if (matches_domain(d, "devpost.com") || matches_domain(d, "dorahacks.io")) return "external"
  if (d != "") return "external"
  return "external"
}
function prettify_service_label(label, url,   k, raw) {
  k = normalize_service_kind(label)
  if (k == "linkedin") return "LinkedIn"
  if (k == "github") return "GitHub"
  if (k == "gitlab") return "GitLab"
  if (k == "reddit") return "Reddit"
  if (k == "telegram") return "Telegram"
  if (k == "booking" || k == "calendly") return "Booking"
  if (k == "x" || k == "twitter") return "X"
  if (k == "youtube") return "YouTube"
  if (k == "medium") return "Medium"
  if (k == "stackoverflow") return "Stack Overflow"
  if (k == "devpost") return "Devpost"
  if (k == "dorahacks") return "DoraHacks"
  if (k == "website") return "Website"
  if (k == "portfolio") return "Portfolio"
  if (k == "blog") return "Blog"
  raw = trim(label)
  return raw != "" ? raw : display_url(url)
}
function render_href(url, label) { return trim(url) == "" ? label : "\\href{\\detokenize{" trim(url) "}}{" label "}" }
function render_linked_label(url, label, kind,   icon) {
  icon = icon_pdf_path(icon_name_for_link(url, kind))
  return "\\inlineicon{" icon "}\\hspace{0.18em}" label
}
function linkify_latex_text(text,   rest, out, prefix, rawurl, clean, trailing, punct) {
  rest = text
  out = ""
  while (match(rest, /https?:\/\/[^[:space:]]+/)) {
    prefix = substr(rest, 1, RSTART - 1)
    rawurl = substr(rest, RSTART, RLENGTH)
    clean = rawurl
    trailing = ""
    while (clean ~ /[.,;:!?]$/) {
      punct = substr(clean, length(clean), 1)
      trailing = punct trailing
      clean = substr(clean, 1, length(clean) - 1)
    }
    out = out escape_latex(prefix)
    out = out render_href(clean, render_linked_label(clean, "\\nolinkurl{" display_url(clean) "}"))
    out = out escape_latex(trailing)
    rest = substr(rest, RSTART + RLENGTH)
  }
  out = out escape_latex(rest)
  return out
}
function first_sentence(v,   t) {
  t = trim(v)
  if (t == "") return ""
  if (match(t, /^.*[.!?]([[:space:]]|$)/)) return trim(substr(t, 1, RLENGTH))
  return (t ~ /[.!?]$/ ? t : t ".")
}
function shorten_sentence(v, max_len,   t, cut) {
  t = trim(v)
  if (t == "" || length(t) <= max_len) return t
  t = substr(t, 1, max_len - 3)
  cut = match(t, / [^ ]*$/)
  if (cut > 24) t = substr(t, 1, cut - 1)
  return trim(t) "..."
}
function render_highlights(e,   i, label, url, note, item, out) {
  out = ""
  for (i = 1; i <= hl_count[e]; i++) {
    label = escape_latex(hl[e, i, "label"])
    url = hl[e, i, "url"]
    note = hl[e, i, "note"]
    item = (url != "" ? render_href(url, render_linked_label(url, label)) : label)
    if (note != "") item = item " (" linkify_latex_text(note) ")"
    out = out (out != "" ? "; " : "") item
  }
  return out
}
function project_names_text(e, max_n,   i, names, used, name) {
  names = ""
  used = 0
  for (i = 1; i <= proj_count[e] && used < max_n; i++) {
    name = proj[e, i, "name"]
    if (name == "") continue
    names = names (names != "" ? "; " : "") escape_latex(name)
    used++
  }
  return names
}
function technologies_text(e, max_n,   vals, n, i, p, arr, out, seen_count) {
  out = ""
  seen_count = 0
  n = split(entry[e, "technologies"], vals, SUBSEP_LIST)
  for (i = 1; i <= n && seen_count < max_n; i++) {
    if (vals[i] == "") continue
    if (!(vals[i] in seen)) {
      seen[vals[i]] = 1
      out = out (out != "" ? ", " : "") escape_latex(vals[i])
      seen_count++
    }
  }
  if (out != "") { delete seen; return out }
  for (p = 1; p <= proj_count[e] && seen_count < max_n; p++) {
    n = split(proj[e, p, "frontend"], vals, SUBSEP_LIST)
    for (i = 1; i <= n && seen_count < max_n; i++) if (vals[i] != "" && !(vals[i] in seen)) { seen[vals[i]] = 1; out = out (out != "" ? ", " : "") escape_latex(vals[i]); seen_count++ }
    n = split(proj[e, p, "backend"], vals, SUBSEP_LIST)
    for (i = 1; i <= n && seen_count < max_n; i++) if (vals[i] != "" && !(vals[i] in seen)) { seen[vals[i]] = 1; out = out (out != "" ? ", " : "") escape_latex(vals[i]); seen_count++ }
    n = split(proj[e, p, "desktop"], vals, SUBSEP_LIST)
    for (i = 1; i <= n && seen_count < max_n; i++) if (vals[i] != "" && !(vals[i] in seen)) { seen[vals[i]] = 1; out = out (out != "" ? ", " : "") escape_latex(vals[i]); seen_count++ }
    n = split(proj[e, p, "mobile"], vals, SUBSEP_LIST)
    for (i = 1; i <= n && seen_count < max_n; i++) if (vals[i] != "" && !(vals[i] in seen)) { seen[vals[i]] = 1; out = out (out != "" ? ", " : "") escape_latex(vals[i]); seen_count++ }
  }
  delete seen
  return out
}
function primary_scope_line(e) {
  if (entry[e, "scope"] != "") return linkify_latex_text(entry[e, "scope"])
  if (entry[e, "summary"] != "") return linkify_latex_text(entry[e, "summary"])
  if (entry[e, "description"] != "") return linkify_latex_text(entry[e, "description"])
  if (entry[e, "domain"] != "") return linkify_latex_text(entry[e, "domain"])
  return ""
}
function project_line(e,   names) {
  names = project_names_text(e, 2)
  return names != "" ? "Projects: " names "." : ""
}
function stack_line(e,   tech) {
  tech = technologies_text(e, 8)
  return tech != "" ? "Stack: " tech "." : ""
}
function highlights_line(e,   hltext) {
  hltext = render_highlights(e)
  return hltext != "" ? "Highlights: " hltext "." : ""
}
function compact_summary(e,   names, first, suffix) {
  if (entry[e, "summary"] != "") return linkify_latex_text(entry[e, "summary"])
  if (entry[e, "scope"] != "") return escape_latex(shorten_sentence(first_sentence(entry[e, "scope"]), 62))
  if (entry[e, "description"] != "") return escape_latex(shorten_sentence(first_sentence(entry[e, "description"]), 62))
  if (entry[e, "domain"] != "") return escape_latex(shorten_sentence(entry[e, "role"] " for " entry[e, "domain"] ".", 62))
  names = project_names_text(e, 1)
  if (names != "") return escape_latex(shorten_sentence("Projects: " proj[e, 1, "name"] (proj_count[e] > 1 ? " + more." : "."), 62))
  return ""
}
function earlier_summary_text(e, density,   max_len, primary, names, tech, used_names, suffix, parts) {
  max_len = (density == "roomy" ? 180 : density == "balanced" ? 120 : 72)
  if (entry[e, "summary"] != "") return linkify_latex_text(entry[e, "summary"])
  parts = ""
  if (entry[e, "scope"] != "") primary = first_sentence(entry[e, "scope"])
  else if (entry[e, "description"] != "") primary = first_sentence(entry[e, "description"])
  else if (entry[e, "domain"] != "") primary = entry[e, "role"] " for " entry[e, "domain"] "."
  else primary = ""
  if (primary != "") parts = primary
  if (density != "dense" && proj_count[e] > 0) {
    used_names = (density == "roomy" ? 2 : 1)
    names = project_names_text(e, used_names)
    suffix = (proj_count[e] > used_names ? " + more" : "")
    parts = append_val(parts, "Projects: " names suffix ".", " ")
  }
  if (density != "dense") {
    tech = technologies_text(e, density == "roomy" ? 5 : 4)
    if (tech != "") parts = append_val(parts, "Stack: " tech ".", " ")
  }
  if (parts == "" && proj_count[e] > 0) parts = "Projects: " project_names_text(e, 2) (proj_count[e] > 2 ? " + more" : "") "."
  return linkify_latex_text(shorten_sentence(parts, max_len))
}
function render_experience_body(e, show_all_bullets,   out, i, visible, line, count) {
  count = exp_bullet_count[e]
  if (count > 0) {
    visible = show_all_bullets ? count : (count < 3 ? count : 3)
    out = "\\begin{resumebullets}"
    for (i = 1; i <= visible; i++) {
      line = linkify_latex_text(exp_bullet[e, i])
      if (line != "") out = out "\n\\item " line
    }
    out = out "\n\\end{resumebullets}"
    return out
  }
  count = 0
  if ((line = primary_scope_line(e)) != "") lines[++count] = line
  if ((line = highlights_line(e)) != "") lines[++count] = line
  if ((line = stack_line(e)) != "") lines[++count] = line
  if ((line = project_line(e)) != "") lines[++count] = line
  if (count == 0) return ""
  visible = show_all_bullets ? count : (count < 3 ? count : 3)
  out = "\\begin{resumebullets}"
  for (i = 1; i <= visible; i++) out = out "\n\\item " lines[i]
  out = out "\n\\end{resumebullets}"
  delete lines
  return out
}
function render_meta(e,   meta) {
  meta = entry[e, "date"]
  if (entry[e, "employment"] != "") meta = meta (meta != "" ? " • " : "") entry[e, "employment"]
  return escape_latex(meta)
}
function render_experience_entries(   detailed_limit, compact_total, dense, macro, out, i) {
  detailed_limit = (SHOW_ALL == 1 ? exp_count : DETAILED_COUNT + 0)
  if (detailed_limit < 0) detailed_limit = 0
  out = ""
  for (i = 1; i <= exp_count && (SHOW_ALL == 1 || i <= detailed_limit); i++) {
    out = out (out != "" ? "\n" : "") "\\experienceentry{" escape_latex(entry[i, "role"]) "}{" escape_latex(entry[i, "company"]) "}{" render_meta(i) "}{" render_experience_body(i, SHOW_ALL == 1) "}"
  }
  if (SHOW_ALL == 1 || detailed_limit >= exp_count) return out
  compact_total = exp_count - detailed_limit
  dense = (compact_total <= 2 ? "roomy" : compact_total <= 4 ? "balanced" : "dense")
  macro = (dense == "dense" ? "compactentry" : "compactentrywide")
  if (out != "") out = out "\n"
  out = out "\\vspace{0.2em}{\\fontsize{8.0}{8.8}\\selectfont\\bfseries Earlier Experience}\\par\\vspace{0.18em}"
  for (i = detailed_limit + 1; i <= exp_count; i++) {
    out = out "\n\\" macro "{" escape_latex(entry[i, "role"]) "}{" escape_latex(entry[i, "company"]) "}{" render_meta(i) "}{" (dense == "dense" ? compact_summary(i) : earlier_summary_text(i, dense)) "}"
  }
  return out
}
function render_skills_compact(   out, i, j) {
  out = ""
  for (i = 1; i <= skill_count; i++) {
    block = "{\\fontsize{7.0}{8.1}\\selectfont\\textbf{" escape_latex(skill_cat[i]) "} "
    for (j = 1; j <= skill_item_count[i]; j++) block = block (j > 1 ? ", " : "") escape_latex(skill_item[i, j])
    block = block "}"
    out = out (out != "" ? "\\par\\vspace{0.18em}" : "") block
  }
  return out
}
function render_education(   details, i) {
  details = ""
  for (i = 1; i <= edu_detail_count; i++) details = details (details != "" ? " " : "") linkify_latex_text(edu_detail[i])
  return "\\educationentry{Education}{" escape_latex(education["institution"]) "}{" escape_latex(education["date"]) "}{" escape_latex(education["degree"]) (details != "" ? " " details : "") "}"
}
function render_achievements(   source, i, out, title, desc) {
  source = 0
  for (i = 1; i <= exp_count; i++) if (hl_count[i] > 0) { source = i; break }
  if (source == 0) return "{\\fontsize{8.2}{10.1}\\selectfont No public achievements listed.}"
  out = ""
  for (i = 1; i <= hl_count[source] && i <= 3; i++) {
    title = escape_latex(hl[source, i, "label"])
    desc = linkify_latex_text(hl[source, i, "note"])
    out = out (out != "" ? "\n" : "") "\\achievemententry{" title "}{" desc "}"
  }
  return out
}
function render_plain_contact(icon, label) {
  return label != "" ? "\\contactplain{" icon_pdf_path(icon_name_for_link("", icon)) "}{" escape_latex(label) "}" : ""
}
function render_link_contact(icon, url, label,   ipath) {
  if (trim(url) == "") return ""
  ipath = icon_pdf_path(icon_name_for_link(url, icon))
  return "\\contactitem{" ipath "}{\\detokenize{" trim(url) "}}{" escape_latex(label) "}"
}
function render_booking_contact(url) {
  return trim(url) == "" ? "" : "\\bookingitem{" icon_pdf_path("booking") "}{\\detokenize{" trim(url) "}}{Booking meet}"
}
function render_telegram_contact(value) {
  value = trim(value)
  if (value == "") return ""
  if (value ~ /^https?:\/\//) return render_link_contact("tg", value, display_url(value))
  if (substr(value, 1, 1) == "@") return render_link_contact("tg", "https://t.me/" substr(value, 2), value)
  return render_plain_contact("tg", value)
}
function render_phone_contact(value,   raw, tel) {
  raw = trim(value)
  if (raw == "") return ""
  tel = raw
  gsub(/[^+0-9]/, "", tel)
  return tel != "" ? render_link_contact("ph", "tel:" tel, raw) : render_plain_contact("ph", raw)
}
function render_service_contact(idx,   href) {
  href = service[idx, "url"]
  if (trim(href) == "") return ""
  return render_link_contact(service[idx, "kind"], href, prettify_service_label(service[idx, "label"], href))
}
function render_contact_row(left, right,   row) {
  row = ""
  if (left != "") row = left
  if (right != "") row = row (row != "" ? "\\hspace{0.92em}" : "") right
  return row
}
function render_contact_line(   row_count, extra_count, i, row, booking, out, left, right) {
  row_count = 0
  extra_count = 0

  left = (basics["location"] != "" ? render_plain_contact("lo", basics["location"]) : "")
  right = (basics["phone"] != "" ? render_phone_contact(basics["phone"]) : "")
  row = render_contact_row(left, right)
  if (row != "") rows[++row_count] = row

  left = (basics["email"] != "" ? render_link_contact("@", "mailto:" basics["email"], basics["email"]) : "")
  right = (basics["telegram"] != "" ? render_telegram_contact(basics["telegram"]) : "")
  row = render_contact_row(left, right)
  if (row != "") rows[++row_count] = row

  left = (basics["linkedin"] != "" ? render_link_contact("in", basics["linkedin"], display_url(basics["linkedin"])) : "")
  right = (basics["github"] != "" ? render_link_contact("gh", basics["github"], display_url(basics["github"])) : "")
  row = render_contact_row(left, right)
  if (row != "") rows[++row_count] = row

  for (i = 1; i <= service_count; i++) {
    row = render_service_contact(i)
    if (row != "") extras[++extra_count] = row
  }
  for (i = 1; i <= extra_count; i += 2) {
    row = render_contact_row(extras[i], extras[i + 1])
    if (row != "") rows[++row_count] = row
  }

  booking = render_booking_contact(basics["booking"])
  out = ""
  for (i = 1; i <= row_count; i++) out = out (out != "" ? "\\\\[0.20em]\n" : "") rows[i]
  if (booking != "") out = out (out != "" ? "\\\\[0.82em]\n\\mbox{}\\\\[0.82em]\n" : "") booking
  delete rows
  delete extras
  return out
}
function render_left_column() {
  return "\\sectiontitle{Experience}\n\n" render_experience_entries() "\n\n\\sectiontitle{Education}\n\n" render_education()
}
function render_right_column() {
  summary_text = ""
  for (i = 1; i <= summary_count; i++) summary_text = summary_text (summary_text != "" ? " " : "") linkify_latex_text(summary[i])
  return "\\sectiontitle{Summary}\n\n{\\fontsize{7.2}{8.5}\\selectfont " summary_text "}\n\n\\sectiontitle{Key Achievements}\n\n" render_achievements() "\n\n\\sectiontitle{Skills}\n\n" render_skills_compact()
}
function render_two_column_body() {
  return "\\columnratio{0.63,0.37}\n\\setlength{\\columnsep}{0.045\\textwidth}\n\\begin{paracol}{2}\n\\RaggedRight\n" render_left_column() "\n\\switchcolumn\n\\RaggedRight\n" render_right_column() "\n\\end{paracol}"
}
function render_full_body(   summary_text, i) {
  summary_text = ""
  for (i = 1; i <= summary_count; i++) summary_text = summary_text (summary_text != "" ? " " : "") linkify_latex_text(summary[i])
  return "\\sectiontitle{Summary}\n\n{\\fontsize{8.0}{9.4}\\selectfont " summary_text "}\n\n\\sectiontitle{Key Achievements}\n\n" render_achievements() "\n\n\\sectiontitle{Skills}\n\n" render_skills_compact() "\n\n\\sectiontitle{Experience}\n\n" render_experience_entries() "\n\n\\sectiontitle{Education}\n\n" render_education()
}
BEGIN {
  SUBSEP_LIST = "\034"
  while ((getline line < TEMPLATE_FILE) > 0) template = template line "\n"
  close(TEMPLATE_FILE)
}
{
  raw = $0
  sub(/\r$/, "", raw)
  trimmed = trim(raw)
  if (trimmed == "") next

  if (trimmed ~ /^#[[:space:]]+/ && trimmed !~ /^##/) {
    basics["name"] = trimmed
    sub(/^#[[:space:]]+/, "", basics["name"])
    basics["name"] = trim(basics["name"])
    next
  }

  if (trimmed ~ /^##[[:space:]]+/) {
    section = trimmed
    sub(/^##[[:space:]]+/, "", section)
    section = trim(section)
    current_skill = 0
    current_exp = 0 + current_exp
    current_proj = 0
    current_highlight = 0
    current_subsection = ""
    next
  }

  if (section == "") {
    if (trimmed ~ /^-[[:space:]]+/) {
      text = trimmed; sub(/^-[[:space:]]+/, "", text)
      if (parse_pair(text, kv)) {
        if (kv["key"] == "headline") basics["title"] = kv["value"]
        else if (kv["key"] == "location") basics["location"] = kv["value"]
        else if (kv["key"] == "email") basics["email"] = kv["value"]
        else if (kv["key"] == "phone") basics["phone"] = kv["value"]
        else if (kv["key"] == "telegram") basics["telegram"] = kv["value"]
        else if (kv["key"] == "linkedin") basics["linkedin"] = kv["value"]
        else if (kv["key"] == "github") basics["github"] = kv["value"]
        else if (kv["key"] == "booking" || kv["key"] == "calendly") basics["booking"] = kv["value"]
      }
    }
    next
  }

  if (section == "Structured summary") {
    text = trimmed; sub(/^-[[:space:]]+/, "", text)
    summary[++summary_count] = text
    next
  }

  if (section == "Skills inventory") {
    if (trimmed ~ /^###[[:space:]]+/) {
      current_skill = ++skill_count
      skill_cat[current_skill] = trimmed
      sub(/^###[[:space:]]+/, "", skill_cat[current_skill])
      skill_cat[current_skill] = trim(skill_cat[current_skill])
      next
    }
    text = trimmed; sub(/^-[[:space:]]+/, "", text)
    skill_item[current_skill, ++skill_item_count[current_skill]] = text
    next
  }

  if (section == "Professional experience") {
    if (trimmed ~ /^###[[:space:]]+/) {
      text = trimmed
      sub(/^###[[:space:]]+/, "", text)
      delete parts
      n = split(text, parts, /[[:space:]]*\|[[:space:]]*/)
      if (n == 3) {
      current_exp = ++exp_count
        entry[current_exp, "date"] = trim(parts[1])
        gsub(/[[:space:]]+-[[:space:]]+/, " -- ", entry[current_exp, "date"])
        entry[current_exp, "company"] = trim(parts[2])
        entry[current_exp, "role"] = trim(parts[3])
        current_proj = 0
        current_highlight = 0
        current_subsection = ""
        next
      }
    }
    if (trimmed ~ /^####[[:space:]]+/) {
      current_subsection = trimmed
      sub(/^####[[:space:]]+/, "", current_subsection)
      current_subsection = trim(current_subsection)
      current_highlight = 0
      if (current_subsection != "Public highlights") {
        current_proj = ++proj_count[current_exp]
        proj[current_exp, current_proj, "name"] = current_subsection
      } else current_proj = 0
      next
    }
    if (raw ~ /^[ \t]*-[[:space:]]+/) {
      text = raw
      sub(/^[ \t]*/, "", text)
      indent = length(raw) - length(text)
      sub(/^-[[:space:]]+/, "", text)
      text = trim(text)
      if (current_subsection == "Public highlights") {
        if (indent == 0) {
          current_highlight = ++hl_count[current_exp]
          split_pos = index(text, " - ")
          if (split_pos > 0) {
            hl[current_exp, current_highlight, "label"] = trim(substr(text, 1, split_pos - 1))
            hl[current_exp, current_highlight, "note"] = trim(substr(text, split_pos + 3))
          } else {
            hl[current_exp, current_highlight, "label"] = text
            hl[current_exp, current_highlight, "note"] = ""
          }
        } else if (current_highlight > 0) {
          if (text ~ /^Submission:[[:space:]]+/) {
            sub(/^Submission:[[:space:]]+/, "", text)
            hl[current_exp, current_highlight, "url"] = trim(text)
          } else {
            sub(/^Reddit demo:[[:space:]]*/, "Reddit demo: ", text)
            hl[current_exp, current_highlight, "note"] = append_val(hl[current_exp, current_highlight, "note"], text, "; ")
          }
        }
        next
      }
      if (current_proj > 0) {
        if (parse_pair(text, kv)) {
          if (kv["key"] == "status") proj[current_exp, current_proj, "status"] = kv["value"]
          else if (kv["key"] == "summary") { proj[current_exp, current_proj, "summary"] = kv["value"]; proj[current_exp, current_proj, "notes"] = append_val(proj[current_exp, current_proj, "notes"], kv["value"], SUBSEP_LIST) }
          else if (kv["key"] == "scope") { proj[current_exp, current_proj, "scope"] = kv["value"]; proj[current_exp, current_proj, "notes"] = append_val(proj[current_exp, current_proj, "notes"], text, SUBSEP_LIST) }
          else if (kv["key"] == "frontend") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) proj[current_exp, current_proj, "frontend"] = append_val(proj[current_exp, current_proj, "frontend"], vals[i], SUBSEP_LIST) }
          else if (kv["key"] == "backend") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) proj[current_exp, current_proj, "backend"] = append_val(proj[current_exp, current_proj, "backend"], vals[i], SUBSEP_LIST) }
          else if (kv["key"] == "mobile app") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) proj[current_exp, current_proj, "mobile"] = append_val(proj[current_exp, current_proj, "mobile"], vals[i], SUBSEP_LIST) }
          else if (kv["key"] == "desktop") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) proj[current_exp, current_proj, "desktop"] = append_val(proj[current_exp, current_proj, "desktop"], vals[i], SUBSEP_LIST) }
          else proj[current_exp, current_proj, "notes"] = append_val(proj[current_exp, current_proj, "notes"], text, SUBSEP_LIST)
        } else proj[current_exp, current_proj, "notes"] = append_val(proj[current_exp, current_proj, "notes"], text, SUBSEP_LIST)
        next
      }
      if (!parse_pair(text, kv)) {
        if (entry[current_exp, "description"] == "") entry[current_exp, "description"] = text
        exp_bullet[current_exp, ++exp_bullet_count[current_exp]] = text
        next
      }
      if (kv["key"] == "employment") {
        val = kv["value"]; sub(/\.$/, "", val)
        entry[current_exp, "employment"] = val
        next
      }
      rendered = text
      if (kv["key"] == "summary") { entry[current_exp, "summary"] = kv["value"]; rendered = kv["value"] }
      else if (kv["key"] == "scope") entry[current_exp, "scope"] = kv["value"]
      else if (kv["key"] == "delivery") entry[current_exp, "delivery"] = kv["value"]
      else if (kv["key"] == "domain") entry[current_exp, "domain"] = kv["value"]
      else if (kv["key"] == "product stage") entry[current_exp, "product stage"] = kv["value"]
      else if (kv["key"] == "stack") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) entry[current_exp, "technologies"] = append_val(entry[current_exp, "technologies"], vals[i], SUBSEP_LIST) }
      else if (kv["key"] == "responsibilities") { n = split_list(kv["value"], vals); for (i = 1; i <= n; i++) entry[current_exp, "responsibilities"] = append_val(entry[current_exp, "responsibilities"], vals[i], SUBSEP_LIST) }
      else if (entry[current_exp, "description"] == "") entry[current_exp, "description"] = text
      exp_bullet[current_exp, ++exp_bullet_count[current_exp]] = rendered
      next
    }
    next
  }

  if (section == "Education") {
    if (trimmed ~ /^###[[:space:]]+/) {
      text = trimmed
      sub(/^###[[:space:]]+/, "", text)
      if (match(text, /[[:space:]]+-[[:space:]]+/)) {
        education["date"] = trim(substr(text, 1, RSTART - 1))
        education["institution"] = trim(substr(text, RSTART + RLENGTH))
        next
      }
    }
    text = trimmed; sub(/^-[[:space:]]+/, "", text)
    if (parse_pair(text, kv) && kv["key"] == "degree") education["degree"] = kv["value"]
    else edu_detail[++edu_detail_count] = text
    next
  }

  if (section == "Basics" || section == "Contact" || section == "Profile") {
    text = trimmed; sub(/^-[[:space:]]+/, "", text)
    if (!parse_pair(text, kv)) next
    if (kv["key"] == "name") basics["name"] = kv["value"]
    else if (kv["key"] == "headline") basics["title"] = kv["value"]
    else if (kv["key"] == "email") basics["email"] = kv["value"]
    else if (kv["key"] == "location") basics["location"] = kv["value"]
    else if (kv["key"] == "phone") basics["phone"] = kv["value"]
    else if (kv["key"] == "telegram") basics["telegram"] = kv["value"]
    else if (kv["key"] == "linkedin") basics["linkedin"] = kv["value"]
    else if (kv["key"] == "github") basics["github"] = kv["value"]
    else if (kv["key"] == "booking" || kv["key"] == "calendly") basics["booking"] = kv["value"]
    else if (is_url_like(kv["value"])) push_service(kv["key"], kv["value"])
  }
}
END {
  if (basics["title"] == "") basics["title"] = "Full-Stack Software Engineer"
  basics["pdfAuthor"] = basics["name"]
  basics["pdfTitle"] = basics["name"] " CV"

  body = (SHOW_ALL == 1 ? render_full_body() : render_two_column_body())
  output = template
  output = replace_all(output, "[[PDF_AUTHOR]]", escape_latex(basics["pdfAuthor"]))
  output = replace_all(output, "[[PDF_TITLE]]", escape_latex(basics["pdfTitle"]))
  output = replace_all(output, "[[NAME]]", escape_latex(basics["name"]))
  output = replace_all(output, "[[TITLE]]", escape_latex(basics["title"]))
  output = replace_all(output, "[[CONTACT_LINE]]", render_contact_line())
  output = replace_all(output, "[[AVATAR]]", AVATAR_TEX)
  output = replace_all(output, "[[BODY_LAYOUT]]", body)
  print output > OUTPUT_FILE
}
' "$input_path"
