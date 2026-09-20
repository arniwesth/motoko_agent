#!/usr/bin/env bash
# apply-grant.sh <run.json> <grant.json>
#
# Write `run.observer` into a dagr run file through the producer transaction:
# candidate → `dagr check --strict` → rename only on `[]`. Records the grant as a
# `directive` event `by: operator` (a human decision is an event, not an inference)
# and refreshes `generated_at`. Refuses to write while the orchestrator pane is
# mid-turn, because the run file has one writer and that writer load-modify-dumps.
set -euo pipefail

run=${1:-}; grant=${2:-}
[ -f "$run" ] && [ -f "$grant" ] || { echo "usage: apply-grant.sh <run.json> <grant.json>" >&2; exit 2; }
command -v dagr >/dev/null || { echo "no dagr validator on PATH; refusing to write" >&2; exit 2; }

# The orchestrator pane: `run.orchestrator.pane` when the producer wrote it, else
# derived from the filename — the extension keys its run file by its own pane
# (`.dagr/run-<HERDR_PANE_ID>-<ts>.json`, DESIGN-dagr-as-delegation-view §5), and
# the live file measured 2026-09-19 carried no `run.orchestrator` block at all.
orch=$(python3 - "$run" <<'PY'
import json, os, re, sys
run = sys.argv[1]
pane = json.load(open(run))["run"].get("orchestrator", {}).get("pane", "")
if not pane:
    m = re.match(r"run-(w\d+)-(p[0-9A-Za-z]+)-\d+\.json$", os.path.basename(run))
    pane = f"{m.group(1)}:{m.group(2)}" if m else ""
print(pane)
PY
)
if [ "${HERDR_ENV:-}" = 1 ]; then
  if [ -z "$orch" ]; then
    if [ "${OBSERVER_FORCE:-}" = 1 ]; then
      echo "cannot determine the orchestrator pane; OBSERVER_FORCE=1 set, writing anyway" >&2
    else
      echo "cannot determine the orchestrator pane (no run.orchestrator, filename not run-<w>-<p>-<ts>.json); refusing to write a file whose writer may be mid-turn. Set OBSERVER_FORCE=1 to override." >&2
      exit 1
    fi
  else
    status=$(herdr agent get "$orch" 2>/dev/null | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["result"]["agent"].get("agent_status",""))
except Exception: print("")' || true)
    if [ "$status" = working ] && [ "${OBSERVER_FORCE:-}" != 1 ]; then
      echo "orchestrator $orch is working; refusing to write its run file mid-turn (retry when idle/parked, or OBSERVER_FORCE=1)" >&2
      exit 1
    fi
    echo "orchestrator $orch status: ${status:-unknown}" >&2
  fi
fi

tmp="$run.tmp"
python3 - "$run" "$grant" "$tmp" <<'PY'
import json, sys, datetime
run, grant, tmp = sys.argv[1:4]
g = json.load(open(run)); o = json.load(open(grant))
o = o.get("observer", o)                         # accept a bare object or a {"observer": …} wrapper
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
o.setdefault("granted_at", now)
g["run"]["observer"] = o
g["generated_at"] = now
g.setdefault("events", []).append({
    "at": now, "type": "directive", "verb": "rule", "by": o.get("granted_by", "operator"),
    "detail": "observer grant: pane %s (agent %s), authority %s, %d scope items, %d return items"
              % (o.get("pane"), o.get("agent"), o.get("authority"), len(o.get("scope", [])), len(o.get("return", [])))
})
json.dump(g, open(tmp, "w"), indent=1); open(tmp, "a").write("\n")
PY

if out=$(dagr check "$tmp" --strict --json) && [ "$out" = "[]" ]; then
  mv "$tmp" "$run"
  echo "applied: run.observer written to $run"
else
  rc=$?
  echo "dagr check refused the candidate (exit $rc); live file untouched:" >&2
  echo "$out" >&2
  rm -f "$tmp"
  exit 1
fi
