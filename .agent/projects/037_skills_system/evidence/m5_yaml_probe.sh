#!/usr/bin/env bash
# What std/yaml.decode does with SKILL.md frontmatter: the five skills in
# .claude/skills, and the edge cases the reviews of ADR-001 asked about
# (comments, colons, block scalars, duplicate keys, non-string values, CRLF,
# BOM, anchors, non-ASCII). Evidence for ADR-001 D9. Not a gate.
#
#   bash .agent/projects/037_skills_system/evidence/m5_yaml_probe.sh
#
# Run from the repo root (it reads .claude/skills). Works in a temp dir and
# touches nothing in the repo. Needs `ailang` on PATH.
set -u

ROOT=$(git rev-parse --show-toplevel) || exit 1
D=$(mktemp -d)
mkdir -p "$D/cases"

# The frontmatter block of a SKILL.md: the lines between the first two `---`.
front() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f {print}' "$1"; }

i=0
add() { i=$((i + 1)); printf '%s' "$2" > "$D/cases/$(printf '%02d' "$i")_$1.yaml"; }

for s in ailang-feedback dagr-producer herdr observer pr-review-loop; do
  add "real_$s" "$(front "$ROOT/.claude/skills/$s/SKILL.md")"
done
add plain              $'name: observer\ndescription: Supervise a run.\n'
add trailing_comment   $'name: observer # a comment\ndescription: Supervise a run.\n'
add hash_no_space      $'name: observer\ndescription: Issue#12 is the reference.\n'
add colon_space_plain  $'name: observer\ndescription: Use when: the user asks.\n'
add single_quoted      $'name: observer\ndescription: \'It\'\'s quoted: yes # still text\'\n'
add double_quoted      $'name: observer\ndescription: "Tab\\there: yes # still text"\n'
add folded             $'name: observer\ndescription: >\n  line one\n  line two\n'
add folded_strip       $'name: observer\ndescription: >-\n  line one\n  line two\n'
add literal            $'name: observer\ndescription: |\n  line one\n  line two\n'
add plain_continuation $'name: observer\ndescription: line one\n  line two\n'
add duplicate_name     $'name: observer\nname: other\ndescription: d\n'
add name_number        $'name: 123\ndescription: d\n'
add name_bool          $'name: true\ndescription: d\n'
add description_null   $'name: observer\ndescription:\n'
add description_spaces $'name: observer\ndescription: "   "\n'
add metadata_map       $'name: observer\ndescription: d\nmetadata:\n  author: someone\n  version: "1.0"\n'
add allowed_tools_list $'name: observer\ndescription: d\nallowed-tools:\n  - Bash\n  - Read\n'
add crlf               $'name: observer\r\ndescription: d\r\n'
add bom                $'\xef\xbb\xbfname: observer\ndescription: d\n'
add anchor_alias       $'name: &n observer\ndescription: *n\n'
add tag                $'name: !!str observer\ndescription: d\n'
add flow_map_value     $'name: observer\ndescription: {a: b}\n'
add tab_indent         $'name: observer\nmetadata:\n\tauthor: x\ndescription: d\n'
add non_ascii_name     $'name: caf\xc3\xa9\ndescription: d\n'
add empty              ''
add not_a_map          $'- a\n- b\n'

cd "$D" || exit 1
cat > probe.ail <<'EOF'
module probe

import std/io (println)
import std/fs (readFile, listDir)
import std/yaml (decode)
import std/json (Json, encode, getString)
import std/option (Option, Some, None)
import std/result (Result, Ok, Err)
import std/string (length, substring)

func clip(s: string, n: int) -> string {
  if length(s) <= n then s else "${substring(s, 0, n)}…"
}

func field(j: Json, k: string) -> string {
  match getString(j, k) {
    Some(v) => "${k}=string(${show(length(v))}) \"${clip(v, 44)}\"",
    None => "${k}=NOT-A-STRING"
  }
}

func one(name: string) -> () ! {IO, FS} {
  let text = readFile("cases/${name}");
  let line = match decode(text) {
    Ok(j) => "Ok   ${field(j, "name")} | ${field(j, "description")}",
    Err(e) => "Err  ${clip(e, 110)}"
  };
  println("${name}\n    ${line}")
}

func each(names: [string]) -> () ! {IO, FS} {
  match names {
    [] => (),
    n :: rest => { let _ = one(n); each(rest) }
  }
}

export func main() -> () ! {IO, FS} {
  each(listDir("cases"))
}
EOF

echo "ailang: $(ailang --version | head -1)"
AILANG_FS_SANDBOX="$D" ailang run --caps IO,FS --entry main probe.ail 2>&1 | grep -v '^→\|^✓'
rm -rf "$D"
