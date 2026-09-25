#!/usr/bin/env bash
# ============================================================================
# probe_between_turn_frame.sh — the LIVE half of PLAN-002 W5's gate (gate 2).
#
# ADR-002 D4's framing subset (D5 step 5): after a conversation-loop turn's
# `run_summary`, the exit manifest's witnessed `env_read` opens a BETWEEN-TURN
# FRAME at that run's `final` (`run_summary.world_ordinal`), and W5(c) threads
# the manifest's successor world into the next turn, so the next turn opens at
# the between-turn frame's LAST ordinal rather than restarting from the world
# the loop was entered with.
#
# WHY LIVE (PLAN-002 §0.2 rule 7). A deterministic run drives the traced entry
# directly and never reaches `conversation_loop_v2_with_policy`, so the
# between-turn frame has no DST fixture. The probe runs `rpc.main` with
# MOTOKO_HEADLESS UNSET and a held-open stdin, exactly as
# `probe_budget_continue.sh` (PLAN-003 P1 Part 6) does, and reads stdout.
#
# THE FRAME HAS NO WIRE RECORD (W5(a)). `WORLD_RUN_BEGIN/END` are DST-script
# printlns only. What stdout carries, and all this probe reads:
#   * `world_request` records (`witness_drain`), each with its `ordinal`;
#   * `run_summary.world_ordinal` (P3ORD), the run's final ordinal;
#   * `session_start` WITH a `run_id` — the conversation loop's per-run banner,
#     emitted before the run starts (R10's delimiter).
#
# WHY THREE TURNS. The first message is consumed by `await_first_task` and runs
# as the INITIAL turn (`run_v2_with_conversation`), whose successor world is
# NOT threaded (W5(c) "Not in (c)"; §3). So turn 1 -> turn 2 contiguity is
# reported, not asserted; the assertions are over turns 2 -> 3, both run by the
# `user_message` arm (c) threads.
#
# ASSERTIONS
#   B1  the first `world_request` after turn 2's `run_summary` has ordinal
#       run_summary2.world_ordinal + 1 (the frame opens at turn 2's final);
#   B2  there is at least one between-turn `world_request`, and none lies
#       after turn 3's `session_start` that belongs to the frame — i.e. every
#       request with ordinal in (final2, turn3-first) sits strictly after
#       run_summary2 and strictly before session_start3 on stdout;
#   B3  turn 3's first `world_request` (first after session_start3) has the
#       last between-turn ordinal + 1 (turn 3 opens at the frame's last
#       ordinal, not at turn 2's final and not at the loop's entry world);
#   B4  `world_request` ordinals from turn 2's first request to
#       run_summary3.world_ordinal are contiguous: no gap, no repeat, and the
#       last one before run_summary3 equals its world_ordinal;
#   C1  EXIT control: the three-turn child, sent `{"type":"exit"}` after turn
#       3, exits 0 with exactly three runs and no `error` event;
#   C2  EOF control: a second child sent two turns and then stdin CLOSED exits
#       0 with exactly two runs and no `error` event.
#
# USAGE
#   scripts/probe_between_turn_frame.sh [--keep] [--model M] [--out DIR]
#   scripts/probe_between_turn_frame.sh --replay FILE [--replay-eof FILE]
# Exit: 0 all green, 1 an assertion red, 2 could not run.
# ============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="probe-between-turn"
MODEL="${MOTOKO_PROBE_MODEL:-openrouter/anthropic/claude-haiku-4.5}"
KEEP=0
OUT=""
REPLAY=""
REPLAY_EOF=""

while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --replay) REPLAY="${2:-}"; shift 2 ;;
    --replay-eof) REPLAY_EOF="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,60p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "probe: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# judge MAIN_STDOUT MAIN_RC EOF_STDOUT EOF_RC  (EOF_* may be empty: C2 skipped)
judge() {
  python3 - "$@" <<'PYEOF'
import json, sys

main_path, main_rc = sys.argv[1], sys.argv[2]
eof_path = sys.argv[3] if len(sys.argv) > 3 else ""
eof_rc = sys.argv[4] if len(sys.argv) > 4 else ""

def load(path):
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            pass
    return out

def is_run_start(e):
    return e.get("type") == "session_start" and str(e.get("run_id") or "") != ""

ev = load(main_path)
starts = [i for i, e in enumerate(ev) if is_run_start(e)]
summaries = [i for i, e in enumerate(ev) if e.get("type") == "run_summary"]
reqs = [(i, e["ordinal"]) for i, e in enumerate(ev) if e.get("type") == "world_request"]
errors = [e for e in ev if e.get("type") == "error"]

print("probe: runs (session_start with run_id) = %d at stdout records %s" % (len(starts), starts))
print("probe: run_summary records = %s" % summaries)

results = []
def check(name, ok, detail):
    results.append((name, bool(ok), detail))

def summary_of_run(k):
    lo = starts[k]
    hi = starts[k + 1] if k + 1 < len(starts) else len(ev)
    s = [i for i in summaries if lo < i < hi]
    return s[-1] if s else None

def reqs_in(lo, hi):
    return [(i, o) for (i, o) in reqs if lo < i < hi]

if len(starts) != 3:
    print("probe: UNMEASURABLE — expected three runs; see %s" % main_path)
    check("C1 exit control: exactly three runs", False, "runs=%d" % len(starts))
else:
    runs = []
    for k in range(3):
        si = summary_of_run(k)
        wo = ev[si]["world_ordinal"] if si is not None else None
        hi = starts[k + 1] if k + 1 < 3 else len(ev)
        in_run = reqs_in(starts[k], si if si is not None else hi)
        after = reqs_in(si, hi) if si is not None else []
        runs.append({"start": starts[k], "summary": si, "final": wo, "in_run": in_run, "between_after": after})
        print("probe: turn %d  run_id=%s  first_req=%s  last_req=%s  requests=%d  run_summary.world_ordinal=%s  between-turn after it=%s"
              % (k + 1, ev[starts[k]].get("run_id"),
                 in_run[0][1] if in_run else None, in_run[-1][1] if in_run else None,
                 len(in_run), wo, [o for _, o in after]))

    t1, t2, t3 = runs
    # informational: turn 1 -> turn 2 is NOT asserted (initial-turn drop, :4723/§3)
    if t1["between_after"] and t2["in_run"]:
        print("probe: INFO turn1->turn2 (not asserted, §3 initial-turn drop): last between-turn=%d turn2 first=%d"
              % (t1["between_after"][-1][1], t2["in_run"][0][1]))

    if t2["summary"] is None or t3["summary"] is None:
        check("B* turn 2 and turn 3 each emit run_summary", False, "missing run_summary")
    else:
        between = t2["between_after"]
        final2, final3 = t2["final"], t3["final"]
        check("B1 first world_request after run_summary2 == world_ordinal2 + 1",
              bool(between) and between[0][1] == final2 + 1,
              "first between-turn ordinal=%s, run_summary2.world_ordinal=%s"
              % (between[0][1] if between else None, final2))
        # B2: the frame's requests are exactly those in (run_summary2, session_start3);
        # none of turn 3's in-run requests carries a frame ordinal.
        frame_ords = set(o for _, o in between)
        stray = [o for _, o in t3["in_run"] if between and final2 < o <= between[-1][1]]
        check("B2 every between-turn world_request lies after run_summary2 and before session_start3",
              bool(between) and all(t2["summary"] < i < t3["start"] for i, _ in between) and not stray,
              "between-turn records=%s ordinals=%s (run_summary2 @%d, session_start3 @%d), frame ordinals after session_start3=%s"
              % ([i for i, _ in between], sorted(frame_ords), t2["summary"], t3["start"], stray))
        first3 = t3["in_run"][0][1] if t3["in_run"] else None
        check("B3 turn 3 first world_request == last between-turn ordinal + 1",
              bool(between) and first3 == between[-1][1] + 1,
              "turn3 first=%s, last between-turn=%s, run_summary2.world_ordinal=%s"
              % (first3, between[-1][1] if between else None, final2))
        seq = [o for i, o in reqs if t2["start"] < i < t3["summary"]]
        bad = [(a, b) for a, b in zip(seq, seq[1:]) if b != a + 1]
        check("B4 contiguous turn2-first .. run_summary3.world_ordinal, no gap/repeat",
              bool(seq) and not bad and seq[-1] == final3,
              "sequence %s..%s (%d requests), breaks=%s, run_summary3.world_ordinal=%s"
              % (seq[0] if seq else None, seq[-1] if seq else None, len(seq), bad[:5], final3))
    check("C1 exit control: rc 0, three runs, no error event",
          main_rc == "0" and not errors,
          "rc=%s runs=3 error events=%d" % (main_rc, len(errors)))

if eof_path:
    eev = load(eof_path)
    estarts = [i for i, e in enumerate(eev) if is_run_start(e)]
    eerr = [e for e in eev if e.get("type") == "error"]
    check("C2 EOF control: rc 0, two runs, no error event",
          eof_rc == "0" and len(estarts) == 2 and not eerr,
          "rc=%s runs=%d error events=%d" % (eof_rc, len(estarts), len(eerr)))

print("")
failed = 0
for name, ok, detail in results:
    print("  %s %s — %s" % ("PASS" if ok else "FAIL", name, detail))
    failed += 0 if ok else 1
print("")
print("probe: %d/%d assertions green" % (len(results) - failed, len(results)))
sys.exit(0 if failed == 0 else 1)
PYEOF
}

if [ -n "$REPLAY" ]; then
  judge "$REPLAY" 0 ${REPLAY_EOF:+"$REPLAY_EOF" 0}
  exit $?
fi

command -v ailang >/dev/null 2>&1 || { echo "probe: no 'ailang' on PATH" >&2; exit 2; }
if [ "${MOTOKO_HEADLESS:-}" != "" ]; then
  echo "probe: MOTOKO_HEADLESS is set; unset it (the loop would not read stdin)" >&2
  exit 2
fi
case "$MODEL" in
  openrouter/*) KEY_NAME=OPENROUTER_API_KEY ;;
  anthropic/*)  KEY_NAME=ANTHROPIC_API_KEY ;;
  openai/*)     KEY_NAME=OPENAI_API_KEY ;;
  *)            KEY_NAME="" ;;
esac
if [ -n "$KEY_NAME" ] && [ -z "${!KEY_NAME:-}" ]; then
  echo "probe: model $MODEL needs $KEY_NAME" >&2; exit 2
fi

RUNDIR="$(mktemp -d "${TMPDIR:-/tmp}/motoko-probe-btf.XXXXXX")"
cleanup() { if [ "$KEEP" = "1" ]; then echo "probe: run directory kept at $RUNDIR"; else rm -rf "$RUNDIR"; fi; }
trap cleanup EXIT

PROFILE_DIR="$RUNDIR/.motoko/config/$PROFILE"
mkdir -p "$PROFILE_DIR"
# Empty extension order: no tool policy can return Pending and read a turn as
# an approval answer; no budget hook. Tools are irrelevant — each turn asks for
# a one-word reply.
cat > "$PROFILE_DIR/config.json" <<JSONEOF
{
  "agent": {
    "model": "$MODEL", "workdir": "$RUNDIR", "max_steps": 4, "step_delay_ms": 0,
    "max_retries": 3, "retry_base_ms": 1000, "retry_cap_ms": 30000,
    "semi_formal_verifier_mode": false, "system_prompt": "$RUNDIR/system.md",
    "openai_base_url": "", "ai_options_json": ""
  },
  "backend": { "mode": "external_http", "auto_start": false },
  "tools": { "hybrid": false, "ohmy_pi": false, "snippet_caps": ["IO", "FS", "Process"] },
  "extensions": { "order": [], "strict": false },
  "verification": { "enabled": false, "command": "true" }
}
JSONEOF
cat > "$RUNDIR/system.md" <<'MDEOF'
You are a terse assistant. Answer every user message with exactly the single word
the user asks for, and nothing else. Never call a tool.
MDEOF

case "$MODEL" in
  openrouter/*|ollama/*|ollama:*) AI_ARG="$MODEL" ;;
  openai/*|anthropic/*|google/*)  AI_ARG="${MODEL#*/}" ;;
  *)                              AI_ARG="$MODEL" ;;
esac
turn() { printf '{"type":"user_message","content":"Reply with exactly the word %s."}\n' "$1"; }

# run_child NAME NTURNS MODE(exit|eof) -> sets CHILD_RC; stdout at $RUNDIR/NAME.jsonl
run_child() {
  local name="$1" nturns="$2" mode="$3" fifo="$RUNDIR/$1.fifo" k
  mkfifo "$fifo"
  cd "$REPO_ROOT" || exit 2
  env -u MOTOKO_HEADLESS \
      AILANG_FS_SANDBOX="$RUNDIR" AILANG_NO_VERSION_WARNINGS=1 MOTOKO_STREAM_EVENTS=1 \
      MOTOKO_SESSION_ID="probe_btf_$$_$name" MOTOKO_RESUME_COUNT=0 MOTOKO_PROFILE_DIR="$PROFILE_DIR" \
    timeout 900 ailang run \
      --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace \
      --ai "$AI_ARG" --entry main \
      --net-allow-http --net-allow-localhost --stream-allow-http --stream-allow-localhost \
      src/core/rpc.ail -- --profile "$PROFILE" --workdir "$RUNDIR" --no-backend \
    < "$fifo" > "$RUNDIR/$name.jsonl" 2> "$RUNDIR/$name.stderr" &
  local child=$!
  # fd 4 holds the write end open: readLine blocks on a non-TTY instead of EOF.
  exec 4>"$fifo"
  for k in $(seq 1 "$nturns"); do turn "turn$k" >&4; done
  if [ "$mode" = "exit" ]; then
    printf '%s\n' '{"type":"exit"}' >&4
    wait "$child"; CHILD_RC=$?
    exec 4>&-
  else
    exec 4>&-           # EOF: the loop's next readLine returns ""
    wait "$child"; CHILD_RC=$?
  fi
  echo "probe: child '$name' ($nturns turns, $mode) rc=$CHILD_RC, $(wc -l < "$RUNDIR/$name.jsonl") stdout lines"
}

echo "probe: model=$MODEL workdir=$RUNDIR (MOTOKO_HEADLESS unset)"
# The EOF control's two messages are written before the close, but the loop
# reads them one at a time AFTER each run finishes, so the close is only seen
# once both turns have run.
run_child main 3 exit; MAIN_RC=$CHILD_RC
run_child eof 2 eof;   EOF_RC=$CHILD_RC

if [ -n "$OUT" ]; then
  mkdir -p "$OUT"
  cp "$RUNDIR/main.jsonl" "$OUT/main.jsonl"; cp "$RUNDIR/eof.jsonl" "$OUT/eof.jsonl"
  cp "$RUNDIR/main.stderr" "$OUT/main.stderr"; cp "$RUNDIR/eof.stderr" "$OUT/eof.stderr"
  echo "probe: captures copied to $OUT"
fi
judge "$RUNDIR/main.jsonl" "$MAIN_RC" "$RUNDIR/eof.jsonl" "$EOF_RC"
