#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="${1:-$REPO_ROOT/benchmarks/results/polyglot_results.json}"
LIVE="${REPO_ROOT}/benchmarks/results/polyglot_live.json"

if [ ! -f "$RESULTS" ] && [ ! -f "$LIVE" ]; then
  echo "results file not found: $RESULTS" >&2
  echo "live file not found: $LIVE" >&2
  exit 1
fi

python3 - "$RESULTS" "$LIVE" <<'PY'
import json
import os
import subprocess
import sys
import datetime
from statistics import mean

res_path = sys.argv[1]
live_path = sys.argv[2]

data = {"exercises": {}, "meta": {}}
if res_path and __import__("os").path.exists(res_path):
    data = json.load(open(res_path))
ex = data.get("exercises", {})
meta = data.get("meta", {})
live = None
if live_path and __import__("os").path.exists(live_path):
    live = json.load(open(live_path))

def has_runner():
    try:
        # Match both relative and absolute invocation forms:
        #   python benchmarks/aider_polyglot.py
        #   python /abs/path/benchmarks/aider_polyglot.py
        # and python3 variants.
        out = subprocess.check_output(
            ["pgrep", "-af", r"(python|python3).*(^|/)benchmarks/aider_polyglot.py"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        return bool(out)
    except Exception:
        return False

def age_seconds(ts: str) -> int | None:
    if not ts:
        return None
    try:
        t = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return max(0, int((datetime.datetime.now(datetime.timezone.utc) - t).total_seconds()))
    except Exception:
        return None

def fmt_duration(sec: float | int | None) -> str:
    if sec is None:
        return "-"
    s = int(max(0, sec))
    h, rem = divmod(s, 3600)
    m, ss = divmod(rem, 60)
    if h > 0:
        return f"{h}h{m:02d}m{ss:02d}s"
    return f"{m}m{ss:02d}s"

statuses = {"pass_1": 0, "pass_2": 0, "fail": 0, "error": 0}
elapsed = []
steps = []
for v in ex.values():
    s = v.get("status", "error")
    if s not in statuses:
        statuses["error"] += 1
    else:
        statuses[s] += 1
    if isinstance(v.get("elapsed_s"), (int, float)):
        elapsed.append(float(v["elapsed_s"]))
    if isinstance(v.get("step_count"), (int, float)):
        steps.append(float(v["step_count"]))

total = len(ex)
passed = statuses["pass_1"] + statuses["pass_2"]
pass_rate = (passed / total * 100.0) if total else 0.0

model = meta.get("model", (live.get("model") if isinstance(live, dict) else "unknown-model"))
print(f"Motoko Polyglot Status ({model})")
print("-" * 54)
if live:
    phase = live.get("phase", "unknown")
    running = has_runner()
    age = age_seconds(str(live.get("updated_at", "")))
    print(f"  run_id: {live.get('run_id', '-')}")
    print(f"  phase: {phase}")
    print(f"  updated: {live.get('updated_at', '-')}")
    print(f"  runner process: {'alive' if running else 'not found'}")
    if age is not None:
        print(f"  live age: {age}s")
    # Only flag stale after a short grace period to avoid transient race windows.
    if phase == "running" and not running and (age is None or age >= 30):
        print("  note: live state is stale (phase=running but no active benchmark process)")
    cur = live.get("current")
    if isinstance(cur, dict):
        print(
            f"  current: {cur.get('exercise','-')} "
            f"(attempt={cur.get('attempt','-')} step={cur.get('step','-')} last={cur.get('last_event_type','-')})"
        )
    last = live.get("last_completed")
    if isinstance(last, dict):
        r = last.get("result", {})
        print(
            f"  last done: {last.get('exercise','-')} "
            f"=> {r.get('status','-')} in {r.get('elapsed_s','-')}s"
        )
    print(f"  progress: {live.get('completed_exercises',0)}/{live.get('total_exercises',0)}")

remaining = None
completed = None
if isinstance(live, dict):
    total_live = int(live.get("total_exercises", total or 0) or 0)
    completed_live = int(live.get("completed_exercises", len(ex)) or 0)
    completed = completed_live
    remaining = max(0, total_live - completed_live)
else:
    completed = total
    remaining = 0

avg_elapsed = (mean(elapsed) if elapsed else None)
if avg_elapsed is not None and remaining is not None:
    eta_s = avg_elapsed * remaining
    print(f"  pace: {avg_elapsed:.1f}s/ex")
    print(f"  eta: {fmt_duration(eta_s)} ({remaining} remaining)")
else:
    print("  pace: -")
    print("  eta: -")
for k in ("pass_1", "pass_2", "fail", "error"):
    n = statuses[k]
    pct = (n / total * 100.0) if total else 0.0
    print(f"  {k:6}: {n:4d} / {total:<4d} ({pct:5.1f}%)")
print(f"  total pass rate: {pass_rate:5.1f}%")
print(f"  avg elapsed: {(mean(elapsed) if elapsed else 0.0):.1f}s")
print(f"  avg steps:   {(mean(steps) if steps else 0.0):.1f}")
PY
