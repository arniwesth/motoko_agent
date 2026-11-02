#!/usr/bin/env bash
# 041 W5: run p1-p8 (nine mutants, p5 is two) one at a time.
# Run from the worktree root on a commit whose src, packages and scripts are clean:
#   mutate.sh <log directory>. Writes mutants.tsv and commit there, with each mutant's raw output
#   beside them.
#
# Each row names what must notice, written before the run, in one of two forms:
#   test:<name>       that inline row of the mutated module fails on its assertion
#   dst:<text>        `make program_persistence`'s suite prints a `✗` line containing <text>
#   c2:<text>         `world_state_probe`'s c2_guard entry prints a `✗` line containing <text>
# A mutant is killed only when the thing it names happens, as the plan's table says. A compile
# error, or a test failing with an evaluation error or a panic, is recorded as what it is and is
# not a kill. Any other failure is listed in `observed` and changes nothing.
#
# p1-p8 are the plan's. c2.* are three more, not in the plan, because a guard is a detector and has
# to be shown to change on a broken source.
set -u
OUT=${1:?log directory}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
DST=scripts/dst/program_persistence_dst.ail
clean() { [ -z "$(git status --porcelain -- src packages scripts)" ]; }
clean || { echo "src, packages or scripts dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
git rev-parse HEAD >"$OUT/commit"
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

edit() { python3 - "$1" "$2" "$3" <<'PY' || exit 2
import sys
f, old, new = sys.argv[1:]
s = open(f).read()
if s.count(old) != 1: sys.exit("edit matches %d times: %s" % (s.count(old), old))
open(f, 'w').write(s.replace(old, new))
PY
}

restore() {
  git checkout -q -- src scripts
  clean || { echo "did not restore"; exit 2; }
}

# Assertion failures as `name`, anything else as `name!`, and `compile-error` when it did not build.
tests_failed() { # module id
  ailang test --format json "$1" >"$OUT/$2.json" 2>"$OUT/$2.err"
  python3 - "$OUT/$2.json" <<'PY'
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("compile-error"); sys.exit()
rows = d.get("tests", []) + d.get("properties", [])
bad = [t for t in rows if t.get("status") == "fail"]
if any("failed to extract" in t.get("error", "") or "type error" in t.get("error", "") for t in bad):
    print("compile-error"); sys.exit()
def name(t):
    e = t.get("error", "")
    return t["name"] + ("!" if re.search(r"panic|failed to evaluate|runtime error", e) else "")
print(" ".join(name(t) for t in bad))
PY
}

# The suite's `✗` lines. An empty log with no summary line is a crash, and is not a kill.
dst_run() { # id
  ailang run --caps IO,FS --entry main "$DST" </dev/null >"$OUT/$1.dst" 2>&1
  grep -q 'program_persistence_dst \(PASS\|FAIL\)' "$OUT/$1.dst" || echo "dst-did-not-finish" >"$OUT/$1.dst.crash"
}

baseline() {
  dst_run baseline
  grep -q '^program_persistence_dst PASS' "$OUT/baseline.dst" || { echo "suite red on the unmutated source"; exit 2; }
  for m in src/core/ext_world.ail src/core/dst_persistence.ail; do
    [ -z "$(tests_failed "$m" baseline)" ] || { echo "$m red on the unmutated source"; exit 2; }
  done
}

mutant() { # id rule edit-text expected file old new
  local id=$1 rule=$2 what=$3 expected=$4 f=$5 old=$6 new=$7
  edit "$f" "$old" "$new"
  local failed verdict observed crash=""
  failed=$(tests_failed "$f" "$id")
  dst_run "$id"
  [ -f "$OUT/$id.dst.crash" ] && crash=" dst-did-not-finish"
  local xlines; xlines=$(grep -c '✗' "$OUT/$id.dst")
  observed="inline=[${failed}] dst_x_lines=${xlines}${crash}"
  case "$expected" in
    test:*)
      local want=${expected#test:}
      if [ "$failed" = "compile-error" ]; then verdict="compile-error (not a kill)"
      elif echo " $failed " | grep -q " ${want}_test_1 "; then verdict=killed
      elif echo " $failed " | grep -q " ${want}_test_1! "; then verdict="panic (not a kill)"
      else verdict=SURVIVED; fi ;;
    dst:*)
      local want=${expected#dst:}
      if [ -n "$crash" ]; then verdict="dst crash (not a kill)"
      elif grep '✗' "$OUT/$id.dst" | grep -qF "$want"; then verdict=killed
      else verdict=SURVIVED; fi ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rule" "$what" "$expected" "${COMMIT:0:8}" "$observed" "$verdict" >>"$TSV"
  echo "$id: $verdict ($observed)"
  restore
}

P=src/core/dst_persistence.ail
R=src/core/dst_replay.ail
E=src/core/ext_world.ail
G=src/core/dst_program.ail
LIMITS='Limits({ default: NoDeadline, ceiling: SameAsDefault })'

baseline

mutant p1 "D7: the mode is the field, never the version" \
  "from v6 process_limits_at reads the version and answers Limits" \
  "dst:THE TRANSCODE CHANGED THE MODE" "$P" \
  '  else match find_tag(hs, "process_limits") {
    [] => Legacy,' \
  "  else if true then $LIMITS else match find_tag(hs, \"process_limits\") {
    [] => Legacy,"

mutant p2 "D7: decoding v1-v5 yields Legacy" \
  "absent before v6 decodes as Limits" \
  "dst:the frozen v5 specimen decodes to a DIFFERENT program" "$P" \
  'if not version_has_process_limits(version) then Legacy' \
  "if not version_has_process_limits(version) then $LIMITS"

mutant p3 "C5: the line is required at v6, and a missing one is refused" \
  "check_required lets process_limits be absent" \
  "dst:the execution-program/6 mode line (process_limits) deleted" "$P" \
  '(if n == 0 then [MissingSection(t.tag)]' \
  '(if n == 0 then (if t.tag == "process_limits" then [] else [MissingSection(t.tag)])'

mutant p4 "D7: world_state_of copies the mode, unflagged by the compiler" \
  "the copy deleted from world_state_of's record update" \
  "dst:world_state_of DROPPED THE MODE" "$R" \
  '                   process_limits: p.initial_world.process_limits,
' ''

mutant p5a "D7: the token carries the mode, decoder half" \
  "world_of_json answers Legacy instead of reading the key" \
  "test:test_a_limits_value_round_trips_through_the_token" "$E" \
  '    process_limits: limit_mode_of(j),' \
  '    process_limits: Legacy,'

mutant p5b "D7: the token carries the mode, encoder half" \
  "world_json drops the key" \
  "test:test_a_limits_value_round_trips_through_the_token" "$E" \
  '    kv("process_limits", limit_mode_json(w.process_limits)),
' ''

mutant p6 "D7: adopt_world re-seats the mode from pre" \
  "the re-seat deleted from adopt_world" \
  "test:test_adoption_re_seats_the_mode_from_the_pre_hook_world" "$E" \
  'effect_log: pre.effect_log, process_limits: pre.process_limits }' \
  'effect_log: pre.effect_log }'

mutant p7 "D7: the decoder refuses a ceiling below a finite default" \
  "ceiling_ms_defect accepts a ceiling below the default" \
  "dst:a ceiling below a finite default" "$G" \
  'Finite(d) => if ms * 1000000 < d then Some(CeilingBelowDefault) else None' \
  'Finite(_) => None'

mutant p8 "D7: a token without the field decodes as Legacy" \
  "an absent key decodes as Limits" \
  "test:test_a_token_without_the_mode_decodes_as_legacy" "$E" \
  '    None => Legacy,
    Some(v) =>
      if str_field(v, "mode", "") != "limits" then Legacy' \
  "    None => $LIMITS,
    Some(v) =>
      if str_field(v, \"mode\", \"\") != \"limits\" then Legacy"

c2mutant() { # id rule edit-text expected file old new [file2 old2 new2]
  local id=$1 rule=$2 what=$3 expected=$4 f=$5 old=$6 new=$7
  edit "$f" "$old" "$new"
  [ $# -ge 10 ] && edit "$8" "$9" "${10}"
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry c2_guard \
    scripts/dst/world_state_probe.ail </dev/null >"$OUT/$id.c2" 2>&1
  local verdict want=${expected#c2:}
  if grep -q 'c2_guard \(PASS\|FAIL\)' "$OUT/$id.c2"; then
    if grep '✗' "$OUT/$id.c2" | grep -qF "$want"; then verdict=killed; else verdict=SURVIVED; fi
  else
    verdict="compile-error or crash (not a kill)"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rule" "$what" "$expected" "${COMMIT:0:8}" "x_lines=$(grep -c '✗' "$OUT/$id.c2")" "$verdict" >>"$TSV"
  echo "$id: $verdict"
  restore
}

c2mutant c2.world "C2: empty_world_state is Legacy" \
  "empty_world_state stamps Limits" \
  "c2:empty_world_state, the world LiveAI reads, is Legacy" src/core/ports.ail \
  'effect_log: [], process_limits: Legacy,' "effect_log: [], process_limits: $LIMITS," \
  src/core/ports.ail 'import src/core/process_limits (LimitMode, Legacy)' 'import src/core/process_limits (LimitMode, Legacy, Limits, NoDeadline, SameAsDefault)'

c2mutant c2.switch "C2: LiveAI is the one switch, and it reads empty_world_state" \
  "the LiveAI arm builds its world another way" \
  "c2:LiveAI still reads empty_world_state" src/core/session.ail \
  'LiveAI => { ports: live_ports(rt), world: empty_world_state() },' \
  'LiveAI => { ports: live_ports(rt), world: { empty_world_state() | clock_ms: 0 } },'

c2mutant c2.schema "C2: the schema has no timeout_secs" \
  "BashExec advertises timeout_secs" \
  "c2:the schema offered to a live run has no timeout_secs" src/core/tool_catalog.ail \
  '{\"cmd\":{\"type\":\"string\"},' \
  '{\"timeout_secs\":{\"type\":\"number\"},\"cmd\":{\"type\":\"string\"},'
