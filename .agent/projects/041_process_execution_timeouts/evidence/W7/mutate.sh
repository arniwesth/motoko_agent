#!/usr/bin/env bash
# 041 W7: run e1-e8 and six more the plan does not name, one at a time.
# Run from the worktree root on a commit whose src, packages and scripts are clean:
#   mutate.sh <log directory>. Writes mutants.tsv and commit there, with each mutant's raw output.
#
# Each row names what must notice, written before the run:
#   test:<name>        that inline row of the mutated module fails on its assertion
#   sr:<text>          `strict_replay_dst`'s main prints a `✗` line containing <text>
#   cj:<text>          `corpus_judge_dst`'s main prints a `✗` line containing <text>
#   iv:<text>          `invariants_dst`'s main prints a `✗` line containing <text>
#   lp:<text>          `run_ledger_parity_wire.sh` prints a `✗` line containing <text>
# A compile error, or a suite that did not finish, is recorded as what it is and is not a kill. Any
# other failure is listed in `observed` and changes nothing.
#
# e1 IS TWO ROWS BECAUSE THE FIRST RUN SHOWED IT MUST BE. As first written, e1 emitted Start on the wire
# and not in the returned `emitted`, and it SURVIVED: the judge reads the trace. `e1` is now the defect the
# judge can see, on both channels, and `e1w` the wire-only one, which `ledger_parity`'s subject 10 was added for.
#
# x1-x7 are not in the plan. They break the caller at `session.ail:1382`, H1's rule on each path, the
# message's echo bound, the rules that keep `refused_call_ids` and the deadline's `detail` honest, and
# the event's arrival on the trace.
set -u
OUT=${1:?log directory}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
CAPS=IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace
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

script_run() { # id script
  ailang run --caps $CAPS --ai-stub --entry main "$2" </dev/null >"$OUT/$1.dst" 2>&1
  echo $? >"$OUT/$1.dst.rc"
}

finish() { # id rule what expected module
  local id=$1 rule=$2 what=$3 expected=$4 module=$5
  local failed="not-run" verdict script finished xlines observed
  case "$expected" in
    test:*) failed=$(tests_failed "$module" "$id");;
  esac
  case "$expected" in
    cj:*) script=scripts/dst/corpus_judge_dst.ail; finished='corpus_judge';;
    iv:*) script=scripts/dst/invariants_dst.ail; finished='invariants';;
    *)    script=scripts/dst/strict_replay_dst.ail; finished='strict_replay_dst \(PASS\|FAIL\)';;
  esac
  if [ "${expected%%:*}" = lp ]; then
    ./scripts/dst/run_ledger_parity_wire.sh >"$OUT/$id.dst" 2>&1; finished='ledger_parity wire gate'
  else
    script_run "$id" "$script"
  fi
  xlines=$(grep -c '✗' "$OUT/$id.dst")
  local crash=""
  # `✗ corpus_judge FAILED` and `strict_replay_dst FAIL` are a finish. A type error prints neither.
  grep -q "$finished" "$OUT/$id.dst" || crash=" did-not-finish"
  observed="inline=[${failed}] x_lines=${xlines}${crash}"
  case "$expected" in
    test:*)
      local want=${expected#test:}
      if [ "$failed" = "compile-error" ]; then verdict="compile-error (not a kill)"
      elif echo " $failed " | grep -q " ${want}_test_[0-9]* "; then verdict=killed
      elif echo " $failed " | grep -q " ${want}_test_[0-9]*! "; then verdict="panic (not a kill)"
      else verdict=SURVIVED; fi ;;
    *)
      local want=${expected#*:}
      if [ -n "$crash" ]; then verdict="did not finish (not a kill)"
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

script_run baseline_sr scripts/dst/strict_replay_dst.ail
grep -q '^strict_replay_dst PASS' "$OUT/baseline_sr.dst" || { echo "strict_replay red on the unmutated source"; exit 2; }
script_run baseline_cj scripts/dst/corpus_judge_dst.ail
[ "$(cat "$OUT/baseline_cj.dst.rc")" = 0 ] || { echo "corpus_judge red on the unmutated source"; exit 2; }
script_run baseline_iv scripts/dst/invariants_dst.ail
[ "$(cat "$OUT/baseline_iv.dst.rc")" = 0 ] || { echo "invariants red on the unmutated source"; exit 2; }

T=src/core/tool_phase.ail; S=src/core/session.ail; L=src/core/process_limits.ail; I=src/core/dst_invariants.ail

edit "$T" 'let _ = match invalid_resolution { Some(_) => (), None => emit(start_event) };' \
          'let _ = emit(start_event);' || exit 2
mutant e1 "D7: an invalid request has no dispatch start" \
  "the native arm emits and returns Start on an invalid request too" \
  "cj:A14b: the tool-dispatches-unbalanced rule" "$T" \
  'emitted: [invalid_event],' 'emitted: [start_event, invalid_event],'

mutant e1w "D7: an invalid request has no dispatch start, on the wire either" \
  "the native arm emits Start on an invalid request, and does not return it" \
  "lp:V2ToolDispatchStart: projected" "$T" \
  'let _ = match invalid_resolution { Some(_) => (), None => emit(start_event) };' \
  'let _ = emit(start_event);'

edit "$T" 'let _ = emit(invalid_event);' \
          'let _ = emit(invalid_event); let served = ports.tool_exec(advance(budget.next_state, EnvRead), { call: envelope, workdir: workdir, timeout_ms: 0, started_at_ms: started.now_ms, process: None });' || exit 2
mutant e2 "D7: an invalid request never reaches the port" \
  "the invalid arm calls the port and keeps its successor" \
  "sr:invalid: the queue is untouched" "$T" \
  'msg: invalid_request_message(call, invalid, rejected_request_text(envelope.arguments)),
                  next_state: advance(budget.next_state, EnvRead),' \
  'msg: invalid_request_message(call, invalid, rejected_request_text(envelope.arguments)),
                  next_state: advance(served.next_state, ToolExec),'

mutant e3 "D4: a scripted completion is served as written" \
  "ToolCompleted renders the limit fields ahead of its content" \
  "test:test_w7_completed_is_served_byte_for_byte" "$T" \
  'ToolCompleted(c) => tool_result_message(call, c.content),' \
  'ToolCompleted(c) => tool_result_message(call, "${encode(jo(carrier_limit_fields(process, true)))}${c.content}"),'

mutant e4 "D4: Legacy renders no fields" \
  "no carrier renders a max_timeout_ms of null" \
  "sr:v5 replay: Legacy faults render today" "$L" \
  '  match carrier {
    None => [],
    Some(resolved) => resolved_limit_fields(resolved, attempted)' \
  '  match carrier {
    None => [{key: "max_timeout_ms", value: JNull}],
    Some(resolved) => resolved_limit_fields(resolved, attempted)'

edit "$T" 'let _ = emit(invalid_event);' 'let _ = ();' || exit 2
mutant e5 "D7: the event is how the invariants see the refusal" \
  "the invalid arm neither emits nor returns ToolArgumentsInvalid" \
  "cj:P1 presence: the run's ToolArgumentsInvalid" "$T" \
  'emitted: [invalid_event],' 'emitted: [],'

mutant e6 "D4 and D2: an invalid request discloses effects none" \
  "the invalid message uses an after-dispatch fault, so effects unknown" \
  "sr:invalid disclosure: the fault is refused, effects none" "$T" \
  'kv(fault_key(), fault_to_json(refused_fault()))
  ] ++ process_limit_fields(invalid, false) ++ [' \
  'kv(fault_key(), fault_to_json(failed_fault(true)))
  ] ++ process_limit_fields(invalid, false) ++ ['

mutant e7 "D4: the deadline's timeout_ms is replaced, not written twice" \
  "tool_outcome_text keeps its own timeout_ms beside the carrier's" \
  "test:test_w7_outcome_text_deadline_reports_timeout_ms_once" "$S" \
  '[kv("tool_call_id", js(d.tool_call_id)), kv("elapsed_ms", jnum(_int_to_float(d.elapsed_ms)))] ++ (match process { Some(_) => [], None => [kv("timeout_ms", jnum(_int_to_float(d.timeout_ms)))] })))' \
  '[kv("tool_call_id", js(d.tool_call_id)), kv("elapsed_ms", jnum(_int_to_float(d.elapsed_ms))), kv("timeout_ms", jnum(_int_to_float(d.timeout_ms)))]))'

mutant e8 "D4: tool_outcome_text's ToolFailed has the fields" \
  "tool_outcome_text's ToolFailed renders no fields" \
  "test:test_w7_outcome_text_failed_reports_the_limit" "$S" \
  'kv("code", js(f.code))] ++ carrier_limit_fields(process, f.after_dispatch) ++ [kv("message"' \
  'kv("code", js(f.code))] ++ [kv("message"'

mutant x1 "D4: the bridge passes the carrier" \
  "the caller at session.ail:1382 passes None" \
  "sr:A16: an extension ToolFailed reports" "$S" \
  '{ output: tool_outcome_text(inv.process, execution.outcome),' \
  '{ output: tool_outcome_text(None, execution.outcome),'

mutant x2 "H1: attempted follows after_dispatch for ToolFailed" \
  "tool_outcome_message reports a ToolFailed as attempted whatever it says" \
  "sr:H1: a fault before dispatch reports no applied limit" "$T" \
  'failed_fault(f.after_dispatch), carrier_limit_fields(process, f.after_dispatch), encode(jo([' \
  'failed_fault(f.after_dispatch), carrier_limit_fields(process, true), encode(jo(['

mutant x3 "H1, on the bridge" \
  "tool_outcome_text reports a ToolFailed as attempted whatever it says" \
  "test:test_w7_outcome_text_failed_before_dispatch_reports_no_applied_limit" "$S" \
  'kv("code", js(f.code))] ++ carrier_limit_fields(process, f.after_dispatch) ++ [kv("message"' \
  'kv("code", js(f.code))] ++ carrier_limit_fields(process, true) ++ [kv("message"'

mutant x4 "A17: a rejected value is echoed bounded" \
  "the echo has no bound" \
  "sr:A17: a 70,000-character timeout_secs is echoed bounded" "$L" \
  'let echo = if length(shown) <= rejected_echo_limit() then shown' \
  'let echo = if true then shown'

mutant x5 "034 W2.1: refused_call_ids names the new builder's event" \
  "refused_call_ids drops ToolArgumentsInvalid" \
  "iv:an invalid request without fault" "$I" \
  '        WireRecord(ToolArgumentsInvalid(i)) => i.id :: refused_call_ids(rest),
' ''

mutant x6 "D4: tool_outcome_message's deadline has timeout_ms once" \
  "detail keeps timeout_ms beside the carrier's" \
  "test:test_w7_deadline_reports_timeout_ms_once" "$T" \
  '] ++ (match process { Some(_) => [], -- D4: the carrier'"'"'s `timeout_ms` replaces this one, and is not written twice' \
  '] ++ (match process { Some(_) => [kv("timeout_ms", jnum(_int_to_float(d.timeout_ms)))], -- D4: the carrier'"'"'s `timeout_ms` replaces this one, and is not written twice'

mutant x7 "D6.4: the event reaches the trace as well as the wire" \
  "the invalid arm emits ToolArgumentsInvalid and does not return it" \
  "lp:ToolArgumentsInvalid: projected" "$T" \
  'emitted: [invalid_event],' 'emitted: [],'

echo; column -t -s$'\t' "$TSV" | cut -c1-200
