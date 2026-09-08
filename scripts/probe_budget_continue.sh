#!/usr/bin/env bash
# ============================================================================
# probe_budget_continue.sh — the LIVE half of PLAN-003 P1's acceptance test.
#
# ADR-003's first judging number: after a run reaches its step budget, the
# operator's next `continue` produces a first provider payload that CONTAINS
# THE EXHAUSTED TURN'S HISTORY, and the step count continues. Today the payload
# contains the pre-turn history (`session.ail:3418-3427` recurses with the
# history the turn started from) and the run's messages are lost with the
# driver's `Fail` arm.
#
# WHY A SHELL SCRIPT AND NOT A FIXTURE (PLAN-003 §0.6). A deterministic run
# drives the traced entry directly and NEVER reaches the conversation loop
# (`session.ail:3359-3366`), so the in-process `continue` has no DST fixture and
# cannot be given one. It is verified three ways instead: the DST fixture for
# the suspension inside the traced run
# (`scripts/dst/phase_c2_wiring_scenarios.ail`, scenario
# `phase_c.c2.step_budget_suspends_with_history`), two pure unit tests for the
# loop rule and the resume constructor (`session.ail`, `test_run_ordinal_rule`
# and `test_c2_state_from_continuation_resets_and_carries`), and this probe.
#
# WHY IT DRIVES THE RUNTIME AND NOT THE TUI. A non-TTY stdin makes the TUI set
# `MOTOKO_HEADLESS=1` (`src/tui/src/runtime-process.ts:355-357`), and under
# headless the conversation loop returns before reading anything
# (`session.ail:3357`) — there is no `continue` to send. The plain logger does
# no stdin handling either (`src/tui/src/index.ts:415`, `:1063`). So the probe
# runs `rpc.main` (`src/core/rpc.ail:355-359`) itself with MOTOKO_HEADLESS
# UNSET, holds a stdin pipe open, and reads the child's STDOUT — the same wire
# the logger would have written (`session.ail:335-341`).
#
# THE STDIN PIPE carries three lines and is held open by fd 3 until the child
# exits: the first task (`await_first_task`, `rpc.ail:277-296`), then
# `{"type":"user_message","content":"continue"}` (the loop's next read,
# `session.ail:3367`), then `{"type":"exit"}` (`:3373`). The AILANG `readLine`
# builtin BLOCKS on a non-TTY rather than returning EOF (`:3352-3353`), which is
# why the pipe must stay open and why headless exists at all.
#
# THE BUDGET IS A PROFILE SETTING, not a flag. `max_steps` is read from the
# profile's `config.json` `agent` object (`config.ail:313`) under
# `<workdir>/.motoko/config/<profile>` (`config.ail:186-187`), and the loop's
# `step_budget` is `budget.total`, which `default_budget_plan(max_steps, …)`
# sets to `max_steps` (`rpc.ail:88-94`, `:116-118`, `:351`) unless an
# extension's budget hook patches it. The probe therefore WRITES its own
# `probe-budget` profile with `max_steps: 5` and an EMPTY extension order — no
# budget-patching extension, and no tool-policy extension that could return
# `Pending` and make the driver read the operator's `continue` line as an
# approval answer (`session.ail:2553-2560`).
#
# ---------------------------------------------------------------------------
# THE SUBSTITUTION, AND ITS CONDITIONS.
#
# The judging number itself — `steps_executed_so_far` — is a TOOL OUTPUT:
# `runtime_status_json` is produced only when the model calls
# `MotokoRuntimeStatus` (`session.ail:2658`), so it is not on the wire unless
# the model happens to ask. The probe asserts the wire-visible equivalents
# instead, each with the condition that makes it equivalent:
#
#  A1  The resumed run's FIRST `provider_call_prepared.msg_count`
#      (`session.ail:2773-2775`) equals the exhausted run's history plus one
#      (the operator's `continue` message).
#      `msg_count` is the length of the COMPACTED payload
#      (`List.length(compacted_msgs)`, `:2768`), so this holds only while no
#      compaction stage rewrote it (`compaction_ai_applied == 0`) and nothing
#      was injected before the call — five steps and an empty extension order
#      guarantee both. CONDITION CHECKED: no `compaction_extension`,
#      `ext_compaction_rejected`, `compaction_exhausted` or `persist_nudge`
#      event in either run.
#      The exhausted history is not itself on the wire, so it is DERIVED: the
#      payload grows by a fixed `d` per step (assistant + its tool results), so
#      history = last payload + d. CONDITION CHECKED: every consecutive delta
#      in the exhausted run is the same positive `d`. When a step's tool batch
#      is a different size the deltas differ, the condition fails, and the probe
#      reports UNMEASURABLE rather than a number — a failed condition is not a
#      failed assertion.
#
#  A2  Each `run_summary.steps_executed` (`st.step_idx` at finalize,
#      `session.ail:1535`; projected at `phase_vocab.ail:791`) is PER RUN: 5 for
#      the exhausted run, and the resumed run's own count. It agrees with
#      `provider_calls_completed` (`:576`) — the judging number's field — only
#      when every step's provider call completed. CONDITION CHECKED: no
#      `stream_error_retry` event in either run.
#
#  A3  The EXHAUSTED run's stdout shows `run_suspended` immediately before
#      `run_summary`, and neither run emits an `error` event: the D2 wire
#      contract in live form.
#
#      RE-TARGETED BY P1 PART 6, and the reason is worth stating because P1
#      Part 1 wrote its assertions as the specification and Part 2's precedent
#      is that a later part EDITS a named clause rather than relaxing an
#      unnamed one. This clause originally asked the RESUMED run for the
#      suspension record, which is not a property of the code under test: the
#      exhausted run suspends because `max_steps` says so, while the resumed
#      run suspends only if the model happens to need five more steps. With
#      this file's own default task — eight commands, five of them consumed by
#      the exhausted run — it never does; it finishes the remaining three and
#      stops. Measured after P1 Parts 4-6: the exhausted run pairs
#      `run_suspended` with `run_summary` exactly as D2 requires, and the
#      resumed run ended `finish_reason=stop steps_executed=4`. Asserting a
#      suspension there would have made the gate a question about the model.
#      The re-target is to the run the contract is about; the pairing is still
#      asserted on the resumed run whenever it DID reach the budget.
#
#  A4  (P3, informational only) one `session_id` across both runs. In P1 each
#      traced run derives its own (`session.ail:3137-3139`), so this is expected
#      to differ and is REPORTED, not asserted.
#
# ---------------------------------------------------------------------------
# RED TODAY, and that is the point: this lands with PLAN-003 P1 Part 1, before
# the code. At HEAD the resumed run's first `msg_count` is the PRE-TURN history
# plus the operator's line — 3 for a `[system, user]` seed, against the ~12+1
# a five-step run should produce — A3 finds no `run_suspended` at all and an
# `error` event on the exhausted run, and A2's resumed count restarts from a
# fresh payload. It goes green with P1 Parts 4-6 (P1 Part 6's gate), and did:
# 6/6 at P1 Part 6 against openrouter/anthropic/claude-haiku-4.5.
#
# USAGE
#   scripts/probe_budget_continue.sh                 # live run, then judge
#   scripts/probe_budget_continue.sh --keep          # keep the run directory
#   scripts/probe_budget_continue.sh --replay FILE   # judge a captured stdout
#                                                    # (no provider call, no key)
#   MOTOKO_PROBE_MODEL=openrouter/…  overrides the model
#   MOTOKO_PROBE_TASK=…              overrides the task
# Exit: 0 all assertions green, 1 an assertion red, 2 the probe could not run.
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="probe-budget"
MAX_STEPS=5
MODEL="${MOTOKO_PROBE_MODEL:-openrouter/anthropic/claude-haiku-4.5}"
# A task that keeps asking for one tool call at a time, so every one of the five
# steps is a CONTINUING step and the budget — not the model deciding it is done
# — is what ends the run. A plain answer would finalize at step 0 (a `stop`
# finish reason goes straight to `Finalize`, `step_machine.ail:128-129`).
DEFAULT_TASK='Run these shell commands ONE PER TURN, never two in the same message, and do not summarise until all of them are done: (1) echo probe-1, (2) echo probe-2, (3) echo probe-3, (4) echo probe-4, (5) echo probe-5, (6) echo probe-6, (7) echo probe-7, (8) echo probe-8.'
TASK="${MOTOKO_PROBE_TASK:-$DEFAULT_TASK}"
KEEP=0
REPLAY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --replay) REPLAY="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,110p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "probe: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# The judge. Reads one captured stdout stream and applies A1-A4.
# It is a separate function so `--replay` judges a stored run with the same code
# that judges a live one — the assertions are the artifact, the run is not.
# ---------------------------------------------------------------------------
judge() {
  MAX_STEPS="$MAX_STEPS" python3 - "$1" <<'PYEOF'
import json, os, sys

path = sys.argv[1]
max_steps = int(os.environ.get("MAX_STEPS", "5"))

events = []
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        events.append(json.loads(line))
    except ValueError:
        continue

# Split into runs on `session_start`: rpc emits one before the first task
# (rpc.ail:250) and the conversation loop emits one per follow-up turn
# (session.ail:3410). Anything before the first is boot noise.
runs, cur = [], None
for e in events:
    if e.get("type") == "session_start":
        cur = []
        runs.append(cur)
    elif cur is not None:
        cur.append(e)

print("probe: runs seen = %d" % len(runs))
if len(runs) < 2:
    print("probe: UNMEASURABLE — expected two runs (the exhausted one and the "
          "resumed one); the child stopped early. See the captured stdout.")
    sys.exit(1)

exhausted, resumed = runs[0], runs[1]

def of_type(run, t):
    return [e for e in run if e.get("type") == t]

def summary(run):
    s = of_type(run, "run_summary")
    return s[-1] if s else None

def payloads(run):
    return [e["msg_count"] for e in of_type(run, "provider_call_prepared")]

ex_pay, re_pay = payloads(exhausted), payloads(resumed)
ex_sum, re_sum = summary(exhausted), summary(resumed)

print("probe: exhausted run payloads = %s" % ex_pay)
print("probe: resumed   run payloads = %s" % re_pay)
print("probe: exhausted run_summary  = %s" % (
    "finish_reason=%s steps_executed=%s error=%r" % (
        ex_sum["finish_reason"], ex_sum["steps_executed"], ex_sum["error"]) if ex_sum else "<none>"))
print("probe: resumed   run_summary  = %s" % (
    "finish_reason=%s steps_executed=%s error=%r" % (
        re_sum["finish_reason"], re_sum["steps_executed"], re_sum["error"]) if re_sum else "<none>"))

results = []   # (name, ok, detail)
def check(name, ok, detail):
    results.append((name, ok, detail))

# --- conditions, checked before the assertions that depend on them -----------
compaction_types = {"compaction_extension", "ext_compaction_rejected",
                    "compaction_exhausted", "persist_nudge"}
rewrote = [e for e in exhausted + resumed if e.get("type") in compaction_types]
cond_no_rewrite = not rewrote
retries = [e for e in exhausted + resumed if e.get("type") == "stream_error_retry"]
cond_no_retry = not retries

deltas = [b - a for a, b in zip(ex_pay, ex_pay[1:])]
cond_uniform = len(deltas) > 0 and len(set(deltas)) == 1 and deltas[0] > 0
d = deltas[0] if cond_uniform else None

print("probe: condition payload untouched by compaction/injection = %s%s" % (
    cond_no_rewrite, "" if cond_no_rewrite else " (%d events)" % len(rewrote)))
print("probe: condition every provider call completed (no retries)  = %s%s" % (
    cond_no_retry, "" if cond_no_retry else " (%d retries)" % len(retries)))
print("probe: condition uniform payload growth per step             = %s (deltas=%s)" % (
    cond_uniform, deltas))

# --- A1: the first judging number -------------------------------------------
if not (cond_no_rewrite and cond_uniform and ex_pay and re_pay):
    check("A1 resumed payload carries the exhausted history + 1", False,
          "UNMEASURABLE — a condition failed or a run made no provider call")
else:
    exhausted_history = ex_pay[-1] + d
    expected = exhausted_history + 1
    check("A1 resumed payload carries the exhausted history + 1",
          re_pay[0] == expected,
          "resumed first msg_count=%d, expected %d (exhausted history %d = last payload %d + %d per step, plus the operator's message)"
          % (re_pay[0], expected, exhausted_history, ex_pay[-1], d))

# --- A2: the step counts are per run and continue ---------------------------
if ex_sum is None or re_sum is None:
    check("A2 steps_executed is per run", False, "a run produced no run_summary")
else:
    check("A2 exhausted run executed the profile's %d steps" % max_steps,
          ex_sum["steps_executed"] == max_steps,
          "steps_executed=%s (profile max_steps=%d)" % (ex_sum["steps_executed"], max_steps))
    check("A2 resumed run_summary counts its own steps",
          re_sum["steps_executed"] == len(re_pay),
          "steps_executed=%s, provider calls prepared=%d%s"
          % (re_sum["steps_executed"], len(re_pay),
             "" if cond_no_retry else " (condition failed: stream retries present)"))
    check("A2 exhausted run finished on the step budget",
          ex_sum["finish_reason"] == "max_steps",
          "finish_reason=%s" % ex_sum["finish_reason"])

# --- A3: the D2 wire contract in live form ----------------------------------
# ASSERTED ON THE RUN THAT SUSPENDED, which is the EXHAUSTED one. P1 Part 6
# re-targeted this from `resumed`; see the A3 note in the header for why that
# was a slip and not a specification.
def record_before_summary(run):
    names = [e.get("type") for e in run]
    if "run_summary" not in names:
        return "<no summary>"
    i = names.index("run_summary")
    return names[i - 1] if i > 0 else "<first record>"

check("A3 exhausted run emits run_suspended immediately before run_summary",
      record_before_summary(exhausted) == "run_suspended",
      "record before run_summary = %s" % record_before_summary(exhausted))

# The resumed run is held to the SAME rule, but only when it reached the budget
# too — whether it does is the model's business (with the default eight-command
# task it has three commands left and finishes inside five steps), so this is a
# conditional assertion and not a coin toss dressed as one.
if re_sum is not None and re_sum.get("finish_reason") == "max_steps":
    check("A3 resumed run also suspended, and emits run_suspended before its run_summary",
          record_before_summary(resumed) == "run_suspended",
          "record before run_summary = %s" % record_before_summary(resumed))
else:
    print("probe: A3 resumed-run pairing NOT APPLICABLE — the resumed run finished "
          "on finish_reason=%s, so it had no suspension to emit"
          % (re_sum.get("finish_reason") if re_sum else "<no summary>"))

# No `error` event on EITHER run. Outside headless the outer loops match
# `suspended` before `result` and emit no ErrorEvent for a suspension
# (session.ail; ADR-003 v6.1 D2), and the probe runs with MOTOKO_HEADLESS unset.
errors = of_type(exhausted, "error") + of_type(resumed, "error")
check("A3 neither run emits an error event",
      not errors,
      "error events = %d%s" % (len(errors),
                               "" if not errors else " (%s)" % [e.get("message") for e in errors]))

# --- A4: P3, reported and not asserted --------------------------------------
ids = sorted({e["session_id"] for e in exhausted + resumed if "session_id" in e})
print("probe: session ids across both runs = %s  (P3 makes this one; in P1 each "
      "traced run derives its own, session.ail:3137-3139)" % ids)

print("")
failed = 0
for name, ok, detail in results:
    print("  %s %s — %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        failed += 1
print("")
print("probe: %d/%d assertions green" % (len(results) - failed, len(results)))
sys.exit(0 if failed == 0 else 1)
PYEOF
}

if [ -n "$REPLAY" ]; then
  [ -r "$REPLAY" ] || { echo "probe: cannot read replay file '$REPLAY'" >&2; exit 2; }
  echo "probe: judging captured stdout $REPLAY (no provider call)"
  judge "$REPLAY"
  exit $?
fi

# ---------------------------------------------------------------------------
# Preflight. Every one of these is a reason the run would produce a misleading
# result rather than a wrong one, so each is a hard stop.
# ---------------------------------------------------------------------------
command -v ailang >/dev/null 2>&1 || { echo "probe: no 'ailang' on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "probe: no 'python3' on PATH" >&2; exit 2; }
if [ "${MOTOKO_HEADLESS:-}" != "" ]; then
  echo "probe: MOTOKO_HEADLESS is set to '${MOTOKO_HEADLESS}'. Under headless the" >&2
  echo "       conversation loop returns before reading stdin (session.ail:3357)," >&2
  echo "       so there is no 'continue' to send. Unset it and re-run." >&2
  exit 2
fi
case "$MODEL" in
  openrouter/*) KEY_NAME=OPENROUTER_API_KEY ;;
  anthropic/*)  KEY_NAME=ANTHROPIC_API_KEY ;;
  openai/*)     KEY_NAME=OPENAI_API_KEY ;;
  google/*)     KEY_NAME=GOOGLE_API_KEY ;;
  *)            KEY_NAME="" ;;
esac
if [ -n "$KEY_NAME" ] && [ -z "${!KEY_NAME:-}" ]; then
  echo "probe: model $MODEL needs $KEY_NAME, which is empty or unset." >&2
  echo "       This probe is LIVE by design — the behaviour it measures is in the" >&2
  echo "       conversation loop, which no scripted provider reaches. Use" >&2
  echo "       --replay to re-judge a captured run without a key." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# The run directory: a scratch workdir with the probe-budget profile in it.
# NOT the repo — the child runs native tools with a live model.
# ---------------------------------------------------------------------------
RUNDIR="$(mktemp -d "${TMPDIR:-/tmp}/motoko-probe-budget.XXXXXX")"
cleanup() {
  if [ "$KEEP" = "1" ]; then
    echo "probe: run directory kept at $RUNDIR"
  else
    rm -rf "$RUNDIR"
  fi
}
trap cleanup EXIT

PROFILE_DIR="$RUNDIR/.motoko/config/$PROFILE"
mkdir -p "$PROFILE_DIR"
# max_steps 5 and NOTHING ELSE that could move the budget: the extension order
# is empty, so no `on_budget_plan` hook patches `budget.total` and no tool
# policy returns `Pending`. `backend.auto_start` is false to match --no-backend;
# native tools do not use the env server (`tool_phase.ail:452-453`).
cat > "$PROFILE_DIR/config.json" <<JSONEOF
{
  "agent": {
    "model": "$MODEL",
    "workdir": "$RUNDIR",
    "max_steps": $MAX_STEPS,
    "step_delay_ms": 0,
    "max_retries": 3,
    "retry_base_ms": 1000,
    "retry_cap_ms": 30000,
    "semi_formal_verifier_mode": false,
    "system_prompt": "$RUNDIR/system.md",
    "openai_base_url": "",
    "ai_options_json": ""
  },
  "backend": { "mode": "external_http", "auto_start": false },
  "tools": { "hybrid": false, "ohmy_pi": false, "snippet_caps": ["IO", "FS", "Process"] },
  "extensions": { "order": [], "strict": false },
  "verification": { "enabled": false, "command": "true" }
}
JSONEOF

# A system prompt is REQUIRED, not decoration: `seal_compacted_payload` refuses
# a payload whose system prefix is empty and the run finalizes as
# `SystemPromptEmpty` before the first provider call
# (`session.ail:2754-2760`) — which is what a probe with `system_prompt: ""`
# measures instead of the budget. It lives in the run directory so the child's
# FS sandbox can read it.
cat > "$RUNDIR/system.md" <<'MDEOF'
You are a shell-running assistant driving a terminal in a scratch directory.
Work through the user's numbered list one command at a time. Call the BashExec
tool with exactly ONE command per turn, wait for its result, and only then move
on to the next. Do not batch commands, do not combine them with && or ;, and do
not summarise until every command in the list has been run and its output seen.
MDEOF

STDOUT="$RUNDIR/stdout.jsonl"
STDERR="$RUNDIR/stderr.log"
FIFO="$RUNDIR/stdin.fifo"
mkfifo "$FIFO"

# AILANG's --ai provider selection: `openrouter/…` goes through as-is, the
# direct-provider prefixes are Motoko routing syntax and are stripped, exactly
# as `providerSelectionModel` does for the TUI (runtime-process.ts:119-146).
case "$MODEL" in
  openrouter/*|ollama/*|ollama:*) AI_ARG="$MODEL" ;;
  openai/*|anthropic/*|google/*)  AI_ARG="${MODEL#*/}" ;;
  *)                              AI_ARG="$MODEL" ;;
esac

task_line() { python3 -c 'import json,sys; print(json.dumps({"type":"user_message","content":sys.argv[1]}))' "$1"; }

echo "probe: model=$MODEL  profile=$PROFILE  max_steps=$MAX_STEPS"
echo "probe: workdir=$RUNDIR"
echo "probe: MOTOKO_HEADLESS is unset — the conversation loop will read stdin"

# MOTOKO_HEADLESS is deliberately absent from this env: `env -u` removes it even
# if the caller exported an empty one, which `headless_mode()` would read as
# false anyway (`rpc.ail:189-192`) but which would be a silent dependency.
# The child runs FROM THE REPO ROOT and is given the module's repo-relative
# path: AILANG matches the `module src/core/rpc` declaration against the file
# path it was invoked with (MOD010), so an absolute path fails to load. The TUI
# spawns `src/core/supervisor.ail` the same way (runtime-process.ts:563-582).
cd "$REPO_ROOT" || exit 2
env -u MOTOKO_HEADLESS \
    AILANG_FS_SANDBOX="$RUNDIR" \
    AILANG_NO_VERSION_WARNINGS=1 \
    MOTOKO_STREAM_EVENTS=1 \
    MOTOKO_PROFILE_DIR="$PROFILE_DIR" \
  ailang run \
    --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace \
    --ai "$AI_ARG" \
    --entry main \
    --net-allow-http --net-allow-localhost \
    --stream-allow-http --stream-allow-localhost \
    src/core/rpc.ail \
    -- --profile "$PROFILE" --workdir "$RUNDIR" --no-backend \
  < "$FIFO" > "$STDOUT" 2> "$STDERR" &
CHILD=$!

# fd 3 is the write end and it STAYS OPEN until the child exits: the AILANG
# readLine blocks on a non-TTY rather than returning EOF, and a closed pipe
# would end the conversation loop before the `continue` was ever read.
exec 3>"$FIFO"
task_line "$TASK" >&3
printf '%s\n' '{"type":"user_message","content":"continue"}' >&3
printf '%s\n' '{"type":"exit"}' >&3

wait "$CHILD"
CHILD_RC=$?
exec 3>&-

echo "probe: child exited rc=$CHILD_RC, $(wc -l < "$STDOUT") stdout lines"
if [ ! -s "$STDOUT" ]; then
  echo "probe: the child wrote nothing to stdout. stderr:" >&2
  tail -20 "$STDERR" >&2
  exit 2
fi

cp "$STDOUT" "$RUNDIR/stdout.capture.jsonl"
judge "$STDOUT"
RC=$?
echo "probe: stdout capture at $RUNDIR/stdout.jsonl (re-judge with --replay)"
[ "$KEEP" = "1" ] || echo "probe: pass --keep to preserve it"
exit $RC
