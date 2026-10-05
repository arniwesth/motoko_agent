#!/usr/bin/env bash
# verify_skills_refusal — 037 ADR-001 acceptance A3 (every rule refuses), A1
# (one tool, one index) and A2 (digests), through the registration path the
# runtime starts on, with AILANG_FS_SANDBOX set to each fixture workdir.
#
#   make verify_skills_refusal        (or: bash scripts/verify_skills_refusal.sh)
#
# One `ailang run` per case: the sandbox root belongs to the process, and a
# refused startup ends the process. Each case runs
# scripts/verify_skills_startup.ail, which makes the two calls the runtime
# makes before `session_start` and prints nothing on the refusal path, so the
# event and the exit status are the host's (the generated registry's).
#
# A REFUSAL passes when the process exits 2, its stdout carries EXACTLY ONE
# JSONL `error` event, that event is the host's `[registration-refused]`
# naming the skills extension, and its message lists exactly the expected
# violations, each by rule and path, and no further one. A CONTROL passes when
# the process exits 0 with no `error` event and exactly one `Skill` schema.
#
# The fixtures are built here and not committed: they need symlinks with
# absolute targets and targets outside the workdir, an unreadable file, empty
# directories and a 61,000-byte file. They are the workdirs of P4's discovery
# probe (.agent/projects/037_skills_system/evidence/p4/probe/), each given a
# profile that names `skills`. V3's messages carry the workdir's absolute path
# (std/fs writes it), so no message is compared whole.
#
# Keep a failing run's fixtures with KEEP=1; the path is printed.
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1
command -v jq > /dev/null || { echo "FAIL verify_skills_refusal: jq is not on PATH"; exit 1; }

# The physical path: the sandbox compares resolved paths, and /tmp is a symlink
# on some hosts.
B=$(cd "$(mktemp -d)" && pwd -P)
cleanup() {
  if [ "${KEEP:-0}" = 1 ]; then echo "fixtures kept at $B"; return; fi
  chmod -R u+rwx "$B" 2> /dev/null; rm -rf "$B"
}
trap cleanup EXIT

CAPS=Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace,Rand
PROBE='{"agent":{"model":"stub"},"extensions":{"order":["skills"],"strict":false}}'
PROBE_STRICT='{"agent":{"model":"stub"},"extensions":{"order":["skills"],"strict":true}}'
# The tree's named profile, copied into two fixtures as it is committed.
NAMED_ORDER=$(jq -r '.extensions.order | join(",")' .motoko/config/skills/config.json)
NAMED_ID="skills#$(jq -r '.extensions.order | index("skills")' .motoko/config/skills/config.json)"

pass=0; fail=0
ok() { echo "OK $1"; pass=$((pass + 1)); }
bad() { # label, why, then the run's output is shown
  echo "FAIL $1:$2"
  printf '%s\n' "$OUT" | grep -v '^→\|^✓' | cut -c1-600 | tail -6 | sed 's/^/     /'
  [ -s "$B/_stderr" ] && tail -3 "$B/_stderr" | cut -c1-300 | sed 's/^/     stderr: /'
  fail=$((fail + 1))
}

# ---- fixtures ---------------------------------------------------------------

OUTSIDE="$B/_outside"       # a sibling of every workdir: outside each sandbox
mkdir -p "$OUTSIDE/skills/far" "$OUTSIDE/far"
printf -- '---\nname: far\ndescription: outside the workdir\n---\nbody\n' > "$OUTSIDE/skills/far/SKILL.md"
printf -- '---\nname: far\ndescription: outside the workdir\n---\nbody\n' > "$OUTSIDE/far/SKILL.md"

wd() { # name -> the workdir, holding the two throwaway profiles
  mkdir -p "$B/$1/.motoko/config/probe" "$B/$1/.motoko/config/probe_strict"
  printf '%s\n' "$PROBE" > "$B/$1/.motoko/config/probe/config.json"
  printf '%s\n' "$PROBE_STRICT" > "$B/$1/.motoko/config/probe_strict/config.json"
  printf '%s' "$B/$1"
}
skill() { # workdir, name, the whole SKILL.md as a printf format
  mkdir -p "$1/.motoko/skills/$2"; printf -- "$3" > "$1/.motoko/skills/$2/SKILL.md"
}
good() { skill "$1" good '---\nname: good\ndescription: A valid skill beside the case.\n---\n# Good\n'; }
named() { cp -R "$ROOT/.motoko/config/skills" "$1/.motoko/config/skills"; }

# Controls. `c2` is one skill per scalar style ADR D9 lists, created out of
# name order so that the order seen is listDir's; `quoted` carries the
# malformed optional fields; the two regular files are not entries.
W=$(wd c0-no-root)
W=$(wd c1-empty-root); mkdir -p "$W/.motoko/skills"
W=$(wd c2-valid-set)
skill "$W" workdir-stamp '---\nname: workdir-stamp\ndescription: >\n  Stamp the working directory with a marker file.\n  Use when the user asks to stamp, mark or tag the\n  working directory.\n---\n# Workdir stamp\n\nRead `stamp-format.txt` in this skill'"'"'s directory.\n'
printf 'motoko-skill-stamp-7f3a :: <reason>\n' > "$W/.motoko/skills/workdir-stamp/stamp-format.txt"
skill "$W" single-q "---\nname: single-q\ndescription: 'It''s quoted: yes # still text'\n---\nbody\n"
skill "$W" quoted '---\nname: quoted\ndescription: "Tab\\there: yes # still text"\nmetadata:\n  author: someone\nallowed-tools:\n  - Bash\ncompatibility: 12\n---\nbody\n'
skill "$W" multi-line '---\nname: multi-line\ndescription: line one\n  line two\n---\nbody\n'
skill "$W" folded-strip '---\nname: folded-strip\ndescription: >-\n  folded and\n  stripped\n---\nbody\n'
skill "$W" b-literal '---\nname: b-literal\ndescription: |\n  first line\n  second line\n---\nbody\n'
skill "$W" anchored '---\nname: &n anchored\ndescription: !!str An anchored name and a tagged description.\nalias: *n\n---\nbody\n'
skill "$W" alpha '---\nname: alpha\ndescription: A plain scalar. # a comment\n---\nbody\n'
mkdir -p "$W/.motoko/skills/crlf-bom"; printf '\xef\xbb\xbf---\r\nname: crlf-bom\r\ndescription: CRLF and a byte-order mark.\r\n---\r\nbody\r\n' > "$W/.motoko/skills/crlf-bom/SKILL.md"
printf 'not a skill\n' > "$W/.motoko/skills/README.md"; printf 'x' > "$W/.motoko/skills/.DS_Store"
W=$(wd c3-relative-symlink-inside); good "$W"
mkdir -p "$W/shared/inlink"; printf -- '---\nname: inlink\ndescription: Reached by a relative symlink inside the workdir.\n---\nbody\n' > "$W/shared/inlink/SKILL.md"
ln -s ../../shared/inlink "$W/.motoko/skills/inlink"

# R1: the root. The ADR's three, and a dangling symlink, which reads the same.
W=$(wd r1a-root-is-file); printf 'not a directory\n' > "$W/.motoko/skills"
W=$(wd r1b-root-symlink-out); ln -s "../../_outside/skills" "$W/.motoko/skills"
W=$(wd r1c-root-symlink-absolute); mkdir -p "$W/elsewhere/skills/good"
printf -- '---\nname: good\ndescription: d\n---\n' > "$W/elsewhere/skills/good/SKILL.md"; ln -s "$W/elsewhere/skills" "$W/.motoko/skills"
W=$(wd r1d-root-symlink-dangling); ln -s nowhere "$W/.motoko/skills"

# V1..V8: one broken entry each, beside a valid skill.
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

# The committed profile `skills`, on a valid tree and on a broken one.
W=$(wd n0-named-profile-valid); named "$W"; good "$W"
W=$(wd n1-named-profile-broken); named "$W"; good "$W"; mkdir -p "$W/.motoko/skills/empty"

# ADR D1, "what the guarantee does not cover": a directory that cannot be listed.
W=$(wd x1-unlistable-skill-dir); good "$W"; skill "$W" sealed '---\nname: sealed\ndescription: d\n---\n'; chmod 000 "$W/.motoko/skills/sealed"

# A2: two valid skills, edited between runs below.
W=$(wd a2-digests)
skill "$W" alpha '---\nname: alpha\ndescription: The first skill.\n---\n# Alpha\n\nThe body.\n'
skill "$W" beta '---\nname: beta\ndescription: The second skill.\n---\n# Beta\n'

# ---- running a case ---------------------------------------------------------

# workdir name, profile, then optionally the two digests of an earlier run.
# Sets OUT (stdout), RC, ERRORS (the JSONL `error` events) and NERR.
start() {
  local wdir="$B/$1"; shift
  OUT=$(env -u MOTOKO_CONFIG -u MOTOKO_PROFILE_DIR -u MOTOKO_WORKDIR -u MOTOKO_REPO \
        AILANG_FS_SANDBOX="$wdir" AILANG_RELAX_MODULES=1 \
        ailang run --caps "$CAPS" --ai-stub --entry main \
        scripts/verify_skills_startup.ail -- "$wdir" "$@" 2> "$B/_stderr" < /dev/null)
  RC=$?
  ERRORS=$(printf '%s\n' "$OUT" | jq -cR 'fromjson? | select(type == "object" and .type == "error")')
  NERR=$(printf '%s' "$ERRORS" | grep -c .)
}
field() { printf '%s\n' "$OUT" | sed -n "s/^$1 //p" | head -1; }
schema() { field SKILL_SCHEMA; }
index_lines() { schema | jq -r '.description' | awk 'seen { print } /^Available skills:$/ { seen = 1 }'; }
enum_names() { schema | jq -r '.parameters | fromjson | .properties.name.enum // [] | .[]'; }
has_enum() { schema | jq -e '.parameters | fromjson | .properties.name | has("enum")' > /dev/null; }

# label, workdir, profile, the refusing extension's id, then one "RULE: path"
# per expected violation, in the order the message lists them.
refuses() {
  local label=$1 wdir=$2 profile=$3 id=$4; shift 4
  local n=$# why="" i=1 v msg count
  start "$wdir" "$profile"
  msg=$(printf '%s\n' "$ERRORS" | head -1 | jq -r '.message // ""' 2> /dev/null)
  count="$n violations"; [ "$n" -ne 1 ] || count="1 violation"
  [ "$RC" -eq 2 ] || why="$why exit $RC, expected 2;"
  [ "$NERR" -eq 1 ] || why="$why $NERR JSONL error events, expected exactly 1;"
  case "$msg" in
    "extension registry rejected: [registration-refused] extension '$id' refuses its own registration through the config key 'registration_refusal' "*) ;;
    *) why="$why the event is not the host's [registration-refused] for '$id';" ;;
  esac
  case "$msg" in *"skills: $count under .motoko/skills;"*) ;; *) why="$why the message does not say '$count';" ;; esac
  for v in "$@"; do
    case "$msg" in *"[$i] $v: "*) ;; *) why="$why violation $i is not '$v';" ;; esac
    i=$((i + 1))
  done
  case "$msg" in *"[$i] "*) why="$why the message names a violation beyond the $n expected;" ;; esac
  if printf '%s\n' "$OUT" | grep -q '^OK started'; then why="$why startup continued;"; fi
  if [ -z "$why" ]; then ok "refused  $label -- exit 2, one error event naming $(printf '%s, ' "$@" | sed 's/, $//')"
  else bad "refused  $label" "$why"; fi
}

# label, workdir, profile, the expected `loaded=` list.
starts() {
  local label=$1 wdir=$2 profile=$3 loaded=$4 why=""
  start "$wdir" "$profile"
  [ "$RC" -eq 0 ] || why="$why exit $RC, expected 0;"
  [ "$NERR" -eq 0 ] || why="$why $NERR JSONL error events, expected none;"
  printf '%s\n' "$OUT" | grep -q "^OK started: .* loaded=$loaded\$" || why="$why no 'OK started' line with loaded=$loaded;"
  [ "$(field SKILL_SCHEMAS)" = 1 ] || why="$why $(field SKILL_SCHEMAS) Skill schemas, expected exactly 1;"
  if [ -z "$why" ]; then ok "started  $label -- exit 0, no error event, one Skill schema"
  else bad "started  $label" "$why"; fi
}

# A check on the run `starts` just made. label, then a command that succeeds.
also() {
  local label=$1; shift
  if "$@"; then ok "         $label"; else bad "         $label" " the check did not hold"; fi
}

# ---- A3 and A1: the controls that must start ---------------------------------

NO_SKILLS='Load a skill by name. No skills are installed in this workspace (.motoko/skills holds none), so there is nothing to load. Do not call this tool.'
says_none() { [ "$(schema | jq -r '.description')" = "$NO_SKILLS" ] && ! has_enum; }

starts "no root at all" c0-no-root probe skills
also "A1: with none, the description says so and \`name\` has no enum" says_none
starts "an empty root" c1-empty-root probe skills
also "A1: with none, the description says so and \`name\` has no enum" says_none

WANT_INDEX='- alpha: A plain scalar.
- anchored: An anchored name and a tagged description.
- b-literal: first line second line
- crlf-bom: CRLF and a byte-order mark.
- folded-strip: folded and stripped
- multi-line: line one line two
- quoted: Tab here: yes # still text
- single-q: It'"'"'s quoted: yes # still text
- workdir-stamp: Stamp the working directory with a marker file. Use when the user asks to stamp, mark or tag the working directory.'
WANT_NAMES='alpha
anchored
b-literal
crlf-bom
folded-strip
multi-line
quoted
single-q
workdir-stamp'
index_is_whole() { [ "$(index_lines)" = "$WANT_INDEX" ]; }
enum_is_names() { [ "$(enum_names)" = "$WANT_NAMES" ] && enum_names | LC_ALL=C sort -c; }
# The description is the instruction, a blank line, `Available skills:`, the index.
index_follows_instruction() {
  [ "$(schema | jq -r '.description' | sed -n '2,3p')" = "$(printf '\nAvailable skills:')" ] \
    && [ "$(schema | jq -r '.description' | wc -l)" -eq $((3 + $(printf '%s\n' "$WANT_INDEX" | wc -l))) ]
}
starts "nine valid skills, one per scalar style, one with malformed optional fields" c2-valid-set probe skills
also "A1: the description names all nine in name order, one line each" index_is_whole
also "A1: the description is the instruction, then the index, and nothing else" index_follows_instruction
also "A1: the enum is the nine names, in name order" enum_is_names
starts "a skill behind a relative symlink inside the workdir" c3-relative-symlink-inside probe skills

# ---- A3: every rule refuses --------------------------------------------------

P=probe; ID='skills#0'
refuses "R1 the root is a regular file" r1a-root-is-file $P "$ID" "R1: .motoko/skills"
refuses "R1 the root is a symlink leaving the workdir" r1b-root-symlink-out $P "$ID" "R1: .motoko/skills"
refuses "R1 the root is an absolute-target symlink" r1c-root-symlink-absolute $P "$ID" "R1: .motoko/skills"
refuses "R1 the root is a dangling symlink (not one of the ADR's three)" r1d-root-symlink-dangling $P "$ID" "R1: .motoko/skills"
refuses "V1 a directory with no SKILL.md" v1a-dir-without-skill-md $P "$ID" "V1: .motoko/skills/empty"
refuses "V1 skill.md is not SKILL.md" v1b-wrong-case $P "$ID" "V1: .motoko/skills/lower"
refuses "V2 an entry that is neither a file nor a directory" v2-entry-symlink-out $P "$ID" "V2: .motoko/skills/far"
if [ "$(id -u)" -eq 0 ]; then echo "SKIP refused  V3 SKILL.md has no read permission: running as root, which reads it anyway"
else refuses "V3 SKILL.md has no read permission" v3a-skill-md-unreadable $P "$ID" "V3: .motoko/skills/locked/SKILL.md"; fi
refuses "V3 SKILL.md is a directory" v3b-skill-md-is-directory $P "$ID" "V3: .motoko/skills/dirmd/SKILL.md"
refuses "V3 SKILL.md is a symlink leaving the workdir" v3c-skill-md-symlink-out $P "$ID" "V3: .motoko/skills/far/SKILL.md"
refuses "V4 no frontmatter block" v4a-no-frontmatter $P "$ID" "V4: .motoko/skills/nofm/SKILL.md"
refuses "V4 the block is not terminated" v4b-unterminated $P "$ID" "V4: .motoko/skills/open/SKILL.md"
refuses "V4 the block does not decode as YAML" v4c-bad-yaml $P "$ID" "V4: .motoko/skills/badyaml/SKILL.md"
refuses "V4 the block decodes to something other than a mapping" v4d-not-a-mapping $P "$ID" "V4: .motoko/skills/seq/SKILL.md"
refuses "V5 name differs from the directory name" v5-name-differs $P "$ID" "V5: .motoko/skills/renamed/SKILL.md"
refuses "V6 description is empty after trimming" v6-empty-description $P "$ID" "V6: .motoko/skills/blank/SKILL.md"
refuses "V7 SKILL.md is too large to deliver whole" v7-too-large $P "$ID" "V7: .motoko/skills/huge/SKILL.md"
refuses "V8 the index is over budget" v8-index-over-budget $P "$ID" "V8: .motoko/skills"
refuses "two violations, both named" two-violations $P "$ID" "V1: .motoko/skills/empty" "V5: .motoko/skills/renamed/SKILL.md"
# ADR D1: the refusal does not depend on extensions.strict.
refuses "the same two under extensions.strict = true" two-violations probe_strict "$ID" "V1: .motoko/skills/empty" "V5: .motoko/skills/renamed/SKILL.md"

# ---- the committed profile `skills` ------------------------------------------

starts "profile skills (.motoko/config/skills) on a valid tree" n0-named-profile-valid skills "$NAMED_ORDER"
refuses "profile skills on a broken tree" n1-named-profile-broken skills "$NAMED_ID" "V1: .motoko/skills/empty"

# ---- A2: digests -------------------------------------------------------------

A2="$B/a2-digests/.motoko/skills"
digests() { printf '%s %s %s' "$(field EXT_SET_DIGEST)" "$(field EXT_CONFIG_DIGEST)" "$(field SYSTEM_PREFIX_DIGEST)"; }
# label, what the config digest must do ("moves" or "same"). Runs the fixture
# as it is now, as the resume of a session whose header recorded the base run.
a2() {
  local label=$1 want=$2 why="" set_d cfg_d pre_d
  start a2-digests probe "$BASE_SET" "$BASE_PREFIX"
  set_d=$(field EXT_SET_DIGEST); cfg_d=$(field EXT_CONFIG_DIGEST); pre_d=$(field SYSTEM_PREFIX_DIGEST)
  [ "$RC" -eq 0 ] || why="$why exit $RC, expected 0;"
  case "$set_d$cfg_d$pre_d" in sha256:*sha256:*sha256:*) ;; *) why="$why a digest is missing;" ;; esac
  [ "$set_d" = "$BASE_SET" ] || why="$why ext_set_digest moved;"
  [ "$pre_d" = "$BASE_PREFIX" ] || why="$why system_prefix_digest moved;"
  if [ "$want" = moves ]; then [ "$cfg_d" != "$BASE_CONFIG" ] || why="$why ext_config_digest did not move;"
  else [ "$cfg_d" = "$BASE_CONFIG" ] || why="$why ext_config_digest moved;"; fi
  printf '%s\n' "$OUT" | grep -qx 'RESUME continues' || why="$why the resume row is '$(printf '%s\n' "$OUT" | grep '^RESUME')';"
  if [ -z "$why" ]; then ok "A2       $label -- ext_set_digest and system_prefix_digest unchanged, ext_config_digest $want, resume continues"
  else bad "A2       $label" "$why"; fi
}

start a2-digests probe
BASE_SET=$(field EXT_SET_DIGEST); BASE_CONFIG=$(field EXT_CONFIG_DIGEST); BASE_PREFIX=$(field SYSTEM_PREFIX_DIGEST)
a2 "nothing changed" same
skill "$B/a2-digests" gamma '---\nname: gamma\ndescription: A third skill.\n---\n# Gamma\n'
a2 "a valid skill added" moves
rm -rf "$A2/gamma"
a2 "and removed again" same
rm -rf "$A2/beta"
a2 "a valid skill removed" moves
skill "$B/a2-digests" beta '---\nname: beta\ndescription: The second skill.\n---\n# Beta\n'
skill "$B/a2-digests" alpha '---\nname: alpha\ndescription: The first skill, reworded.\n---\n# Alpha\n\nThe body.\n'
a2 "a description reworded" moves
skill "$B/a2-digests" alpha '---\nname: alpha\ndescription: The first skill.\n---\n# Alpha\n\nThe body, rewritten: three more lines.\n\n1. One.\n2. Two.\n'
a2 "only a body reworded" same
rm -rf "$A2/alpha" "$A2/beta"
# ADR D12: between no skill and some, the capability kinds do not change.
a2 "every skill removed (none left)" moves

# The two controls that make "unchanged" and "continues" mean something: the
# resume row refuses a header whose extension-set digest differs, and that
# digest does differ once the profile's extension set does.
start a2-digests probe sha256:another-extension-set "$BASE_PREFIX"
if printf '%s\n' "$OUT" | grep -qx 'RESUME refused: ext-set'; then ok "A2       control: the resume row refuses a header with another ext_set_digest"
else bad "A2       control: the resume row refuses a header with another ext_set_digest" " got '$(printf '%s\n' "$OUT" | grep '^RESUME')'"; fi
mkdir -p "$B/a2-digests/.motoko/config/probe_two"
printf '%s\n' '{"agent":{"model":"stub"},"extensions":{"order":["empty_stop_guard","skills"],"strict":false}}' > "$B/a2-digests/.motoko/config/probe_two/config.json"
start a2-digests probe_two
if [ "$RC" -eq 0 ] && [ -n "$(field EXT_SET_DIGEST)" ] && [ "$(field EXT_SET_DIGEST)" != "$BASE_SET" ]; then ok "A2       control: ext_set_digest differs under a profile with another extension set"
else bad "A2       control: ext_set_digest differs under a profile with another extension set" " exit $RC, digest '$(field EXT_SET_DIGEST)'"; fi

# An invalid change refuses startup whatever the digests say.
skill "$B/a2-digests" alpha '---\nname: not-alpha\ndescription: The first skill.\n---\n# Alpha\n'
refuses "A2 an invalid change refuses startup" a2-digests $P "$ID" "V5: .motoko/skills/alpha/SKILL.md"

# ---- the stated limit, reported and not gated --------------------------------

if [ "$(id -u)" -ne 0 ]; then
  start x1-unlistable-skill-dir probe
  echo "NOTE a skill directory that cannot be listed (ADR D1, not covered by the guarantee): exit $RC, $NERR error events; $(tail -1 "$B/_stderr" | cut -c1-160)"
fi

echo "verify_skills_refusal: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
