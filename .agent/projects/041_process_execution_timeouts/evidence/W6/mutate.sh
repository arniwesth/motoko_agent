#!/usr/bin/env bash
# 041 W6: run s1-s5, and five more the plan does not name, one at a time.
# Run from the worktree root on a commit whose src, packages and scripts are clean:
#   mutate.sh <log directory>. Writes mutants.tsv and commit there, with each mutant's raw output.
#
# Each row names what must notice, written before the run:
#   test:<name>   that inline row of the mutated module fails on its assertion (ports and process_limits only)
#   dst:<text>    `strict_replay_dst`'s main prints a `✗` line containing <text>
# A compile error, or a suite that did not finish, is recorded as what it is and is not a kill. Any
# other failure is listed in `observed` and changes nothing.
#
# l1, l2, d1, p1 and i1 are not in the plan. They break the live-arm refusal, its boundary, the
# deadline's display, the projection and the invalid stand-in, each of which W6 states as a rule.
set -u
OUT=${1:?log directory}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
DST=scripts/dst/strict_replay_dst.ail
clean() { [ -z "$(git status --porcelain -- src packages scripts)" ]; }
clean || { echo "src, packages or scripts dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
echo "$COMMIT" >"$OUT/commit"
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

edit() { python3 - "$1" "$2" "$3" <<'PY' || return 2
import sys
f, old, new = sys.argv[1:]
s = open(f).read()
if s.count(old) != 1: sys.exit("edit matches %d times: %s" % (s.count(old), old))
open(f, 'w').write(s.replace(old, new))
PY
}

restore() { git checkout -q -- src scripts; clean || { echo "did not restore"; exit 2; }; }

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
    return t["name"] + ("!" if re.search(r"panic|failed to evaluate|runtime error", t.get("error", "")) else "")
print(" ".join(name(t) for t in bad))
PY
}

dst_run() { # id
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main "$DST" </dev/null >"$OUT/$1.dst" 2>&1
  rm -f "$OUT/$1.dst.crash"
  grep -q '^strict_replay_dst \(PASS\|FAIL\)' "$OUT/$1.dst" || echo "dst-did-not-finish" >"$OUT/$1.dst.crash"
}

finish() { # id rule what expected inline-module
  local id=$1 rule=$2 what=$3 expected=$4 module=$5
  local failed="not-run" verdict crash="" xlines observed
  case "$module" in src/core/ports.ail|src/core/process_limits.ail) failed=$(tests_failed "$module" "$id");; esac
  dst_run "$id"
  [ -f "$OUT/$id.dst.crash" ] && crash=" dst-did-not-finish"
  xlines=$(grep -c '✗' "$OUT/$id.dst")
  observed="inline=[${failed}] dst_x_lines=${xlines}${crash}"
  case "$expected" in
    test:*)
      local want=${expected#test:}
      if [ "$failed" = "compile-error" ]; then verdict="compile-error (not a kill)"
      elif echo " $failed " | grep -q " ${want}_test_[0-9]* "; then verdict=killed
      elif echo " $failed " | grep -q " ${want}_test_[0-9]*! "; then verdict="panic (not a kill)"
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

mutant() { # id rule what expected file old new
  edit "$5" "$6" "$7" || { echo "$1: the edit did not apply"; exit 2; }
  finish "$1" "$2" "$3" "$4" "$5"
}

dst_run baseline
grep -q '^strict_replay_dst PASS' "$OUT/baseline.dst" || { echo "suite red on the unmutated source"; exit 2; }

P=src/core/ports.ail; L=src/core/process_limits.ail; T=src/core/tool_phase.ail; S=src/core/session.ail

mutant s1 "D7: enforcement of a carried process tool never reads timeout_ms" \
  "scripted_tool_outcome reads inv.timeout_ms for a carried process tool" \
  "test:row_1000_3000_2000" "$P" \
  'else if process_deadline_expires(inv.process, t.duration_ms, inv.timeout_ms) then' \
  'else if inv.timeout_ms > 0 && t.duration_ms > inv.timeout_ms then'

mutant s2 "D7: ReadFile has no carrier and keeps today's deadline" \
  "is_process_tool answers true for ReadFile, so ReadFile gets a carrier" \
  "dst:A10 ReadFile keeps today's deadline" "$L" \
  'tool == "BashExec" || tool == "RunTests"' \
  'tool == "BashExec" || tool == "RunTests" || tool == "ReadFile"'

edit "$S" 'import src/core/process_limits (extension_tool_process)' \
          'import src/core/process_limits (dispatch_resolution, ProcessResolved)' || exit 2
mutant s3 "R8: an extension effect's timeout_secs is not read" \
  "the bridge resolves the effect's arguments, so timeout_secs decides" \
  "dst:R8 (timeout_secs 2): an extension BashExec expires" "$S" \
  'process: extension_tool_process(tool, w0.process_limits),' \
  'process: match dispatch_resolution(w0.process_limits, tool, args) { Some(ProcessResolved(r)) => Some(r), _ => None },'

edit "$T" 'import src/core/process_limits (ProcessResolved,' \
          'import src/core/process_limits (Legacy, ProcessResolved,' || exit 2
mutant s4 "D7: the env read stays once per dispatch in both modes" \
  "tool_phase skips the env read outside Legacy" \
  "dst:limits: the REPLAYED run's log accounts for it" "$T" \
  'let budget = ports.env_get(advance(started.next_state, ClockRead), "MOTOKO_TOOL_TIMEOUT_MS", "0");' \
  'let budget = match started.next_state.process_limits { Legacy => ports.env_get(advance(started.next_state, ClockRead), "MOTOKO_TOOL_TIMEOUT_MS", "0"), _ => { value: "0", next_state: advance(started.next_state, ClockRead) } };'

mutant s5 "D7: SessionDefault projects today's value, which strict replay compares" \
  "projected_timeout_ms answers 30000 for SessionDefault" \
  "dst:strict replay: a Legacy recording of a call with no request" "$L" \
  '      ExplicitMs(m) => m,
      SessionDefault => legacy_timeout_ms' \
  '      ExplicitMs(m) => m,
      SessionDefault => 30000'

mutant l1 "§6 step 3: live_tool_outcome refuses ExplicitMs before dispatch" \
  "the refusal is removed, so the live arm runs a plain exec under a limit it cannot apply" \
  "dst:live arm: world_tool refuses BashExec" "$P" \
  'if needs_process_primitive(inv.process) then' \
  'if false && needs_process_primitive(inv.process) then'

mutant l2 "D7: SessionDefault is a plain exec and is not refused" \
  "the refusal also takes SessionDefault" \
  "dst:live arm control: SessionDefault is a plain exec" "$L" \
  '      ExplicitMs(_) => true,
      SessionDefault => false' \
  '      ExplicitMs(_) => true,
      SessionDefault => true'

mutant d1 "D7: ToolDeadlineExceeded.timeout_ms carries the display value" \
  "the deadline reports inv.timeout_ms" \
  "dst:A9: no request stops at the default" "$P" \
  'timeout_ms: deadline_display_ms(inv.process, inv.timeout_ms) })' \
  'timeout_ms: inv.timeout_ms })'

mutant p1 "D7: ExplicitMs records its value in timeout_ms" \
  "tool_phase records the env's value for a carried call" \
  "dst:A9 1000/3000/2000: a request stops at itself" "$T" \
  'timeout_ms: projected_timeout_ms(carrier, parse_timeout_ms(budget.value)),' \
  'timeout_ms: parse_timeout_ms(budget.value),'

mutant i1 "D7: an invalid request never reaches the port" \
  "tool_phase sends an invalid request to the port with no carrier" \
  "dst:invalid: the queue is untouched" "$T" \
  'if invalid then {' \
  'if false && invalid then {'
