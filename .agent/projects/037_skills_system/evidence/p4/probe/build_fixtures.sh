#!/usr/bin/env bash
# 037 P4 evidence: fixture workdirs for the discovery probe. One workdir per
# case under $1; each violates one rule of ADR-001 D1 (or none, for controls).
# Touches nothing outside $1.
#
#   bash build_fixtures.sh <empty dir> <repo root, for the five real skills>
set -eu
B=${1:?fixture base directory}
REPO=${2:?repo root}
mkdir -p "$B"
[ -z "$(ls -A "$B")" ] || { echo "fixture base $B is not empty" >&2; exit 1; }
OUT="$B/_outside"          # a sibling of every workdir: outside each sandbox
mkdir -p "$OUT/skills/far" "$OUT/far"
printf -- '---\nname: far\ndescription: outside the workdir\n---\nbody\n' > "$OUT/skills/far/SKILL.md"
printf -- '---\nname: far\ndescription: outside the workdir\n---\nbody\n' > "$OUT/far/SKILL.md"

wd() { mkdir -p "$B/$1"; printf '%s' "$B/$1"; }
skill() { # workdir, name, frontmatter-and-body
  mkdir -p "$1/.motoko/skills/$2"; printf -- "$3" > "$1/.motoko/skills/$2/SKILL.md"
}
good() { skill "$1" good '---\nname: good\ndescription: A valid skill beside the case.\n---\n# Good\n'; }

# ---- controls: must be accepted ---------------------------------------------
W=$(wd c01-no-motoko)
W=$(wd c02-no-root); mkdir -p "$W/.motoko/config"
W=$(wd c03-empty-root); mkdir -p "$W/.motoko/skills"
W=$(wd c04-valid-set)
# created out of name order, so the order seen is listDir's and not creation's
skill "$W" workdir-stamp '---\nname: workdir-stamp\ndescription: >\n  Stamp the working directory with a marker file.\n  Use when the user asks to stamp, mark or tag the\n  working directory.\n---\n# Workdir stamp\n\nRead `stamp-format.txt` in this skill'"'"'s directory.\n'
printf 'motoko-skill-stamp-7f3a :: <reason>\n' > "$W/.motoko/skills/workdir-stamp/stamp-format.txt"
mkdir -p "$W/.motoko/skills/workdir-stamp/examples"; printf 'x\n' > "$W/.motoko/skills/workdir-stamp/examples/a.txt"
skill "$W" single-q "---\nname: single-q\ndescription: 'It''s quoted: yes # still text'\n---\nbody\n"
skill "$W" quoted '---\nname: quoted\ndescription: "Tab\\there: yes # still text"\nmetadata:\n  author: someone\nallowed-tools:\n  - Bash\ncompatibility: 12\n---\nbody\n'
skill "$W" multi-line '---\nname: multi-line\ndescription: line one\n  line two\n---\nbody\n'
skill "$W" b-literal '---\nname: b-literal\ndescription: |\n  first line\n  second line\n---\nbody\n'
skill "$W" alpha '---\nname: alpha\ndescription: A plain scalar. # a comment\n---\nbody\n'
mkdir -p "$W/.motoko/skills/crlf-bom"; printf '\xef\xbb\xbf---\r\nname: crlf-bom\r\ndescription: CRLF and a byte-order mark.\r\n---\r\nbody\r\n' > "$W/.motoko/skills/crlf-bom/SKILL.md"
printf 'not a skill\n' > "$W/.motoko/skills/README.md"; printf 'x' > "$W/.motoko/skills/.DS_Store"
W=$(wd c05-relative-symlink-inside); good "$W"
mkdir -p "$W/shared/inlink"; printf -- '---\nname: inlink\ndescription: Reached by a relative symlink inside the workdir.\n---\nbody\n' > "$W/shared/inlink/SKILL.md"
ln -s ../../shared/inlink "$W/.motoko/skills/inlink"
W=$(wd c06-real-skills); mkdir -p "$W/.motoko/skills"
for s in "$REPO"/.claude/skills/*/; do cp -R "$s" "$W/.motoko/skills/$(basename "$s")"; done

# ---- R1: the root ------------------------------------------------------------
W=$(wd r1a-root-is-file); mkdir -p "$W/.motoko"; printf 'not a directory\n' > "$W/.motoko/skills"
W=$(wd r1b-root-symlink-out); mkdir -p "$W/.motoko"; ln -s "../../_outside/skills" "$W/.motoko/skills"
W=$(wd r1c-root-symlink-absolute-inside); mkdir -p "$W/.motoko" "$W/elsewhere/skills/good"
printf -- '---\nname: good\ndescription: d\n---\n' > "$W/elsewhere/skills/good/SKILL.md"; ln -s "$W/elsewhere/skills" "$W/.motoko/skills"
W=$(wd r1d-root-symlink-dangling); mkdir -p "$W/.motoko"; ln -s nowhere "$W/.motoko/skills"

# ---- V1..V8: one entry each, beside a valid skill ----------------------------
W=$(wd v1a-dir-without-skill-md); good "$W"; mkdir -p "$W/.motoko/skills/empty"; printf 'x\n' > "$W/.motoko/skills/empty/notes.txt"
W=$(wd v1b-wrong-case); good "$W"; mkdir -p "$W/.motoko/skills/lower"; printf -- '---\nname: lower\ndescription: d\n---\n' > "$W/.motoko/skills/lower/skill.md"
W=$(wd v2-entry-symlink-out); good "$W"; ln -s "../../../_outside/far" "$W/.motoko/skills/far"
W=$(wd v3a-skill-md-unreadable); good "$W"; skill "$W" locked '---\nname: locked\ndescription: d\n---\n'; chmod 000 "$W/.motoko/skills/locked/SKILL.md"
W=$(wd v3b-skill-md-is-directory); good "$W"; mkdir -p "$W/.motoko/skills/dirmd/SKILL.md"
W=$(wd v3c-skill-md-symlink-out); good "$W"; mkdir -p "$W/.motoko/skills/far"; ln -s "../../../../_outside/far/SKILL.md" "$W/.motoko/skills/far/SKILL.md"
W=$(wd v4a-no-frontmatter); good "$W"; skill "$W" nofm '# no frontmatter here\n'
W=$(wd v4b-unterminated); good "$W"; skill "$W" open '---\nname: open\ndescription: d\n\nbody\n'
W=$(wd v4c-bad-yaml); good "$W"; skill "$W" badyaml '---\nname: badyaml\ndescription: Use when: the user asks.\n---\n'
W=$(wd v4d-not-a-mapping); good "$W"; skill "$W" seq '---\n- a\n- b\n---\n'
W=$(wd v5-name-differs); good "$W"; skill "$W" renamed '---\nname: other-name\ndescription: d\n---\n'
W=$(wd v6-empty-description); good "$W"; skill "$W" blank '---\nname: blank\ndescription: "   "\n---\n'
W=$(wd v7-too-large); good "$W"; skill "$W" huge '---\nname: huge\ndescription: d\n---\n'
head -c 61000 /dev/zero | tr '\0' 'x' >> "$W/.motoko/skills/huge/SKILL.md"
W=$(wd v8-index-over-budget)
D=$(head -c 1000 /dev/zero | tr '\0' 'd')
for i in $(seq -w 1 17); do skill "$W" "s$i" "---\nname: s$i\ndescription: $D\n---\n"; done
W=$(wd two-violations); good "$W"; mkdir -p "$W/.motoko/skills/empty"; skill "$W" renamed '---\nname: other-name\ndescription: d\n---\n'

# ---- D1, "what the guarantee does not cover" ---------------------------------
W=$(wd x1-unlistable-skill-dir); good "$W"; skill "$W" sealed '---\nname: sealed\ndescription: d\n---\n'; chmod 000 "$W/.motoko/skills/sealed"
echo "built $(ls "$B" | grep -vc '^_outside$') fixture workdirs under $B"
