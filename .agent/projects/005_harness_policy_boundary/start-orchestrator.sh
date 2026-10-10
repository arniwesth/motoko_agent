#!/usr/bin/env bash
# Start Motoko as the orchestrator of PLAN-finalize-policy-migration.
#
# Run it in the herdr pane Motoko is to run in, in place of `make motoko`:
#
#   bash .agent/projects/005_harness_policy_boundary/start-orchestrator.sh [make arguments]
#
# It does two things:
#   1. writes .dagr/run-005-finalize-policy-migration.json: the committed plan graph plus
#      this pane's id, which is what turns orchestrator mode on. The herdr extension reads
#      that once, when Motoko starts, so the file has to exist first.
#   2. runs `make motoko`, passing its arguments on (for example PROFILE=dogfood).
#
# Then paste the prompt from PROMPT-motoko-finalize-policy-migration-start.md.
#
#   --no-start   write the run file and stop
#   MERGED="WI-7 WI-8 ..."   task ids whose pull request has merged, for a later session:
#                            they are seeded as done, so the tasks behind them are ready
set -euo pipefail

start=1
if [ "${1:-}" = "--no-start" ]; then start=0; shift; fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
graph=".agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.dagr.json"
run=".dagr/run-005-finalize-policy-migration.json"

if [ ! -d "$root/.git" ]; then
  echo "start-orchestrator: $root is a worktree, not the shared checkout." >&2
  echo "Motoko orchestrates from the shared checkout. Run the copy of this script there." >&2
  exit 1
fi
if [ -z "${HERDR_PANE_ID:-}" ]; then
  echo "start-orchestrator: HERDR_PANE_ID is empty. Run this in a herdr pane." >&2
  exit 1
fi
command -v dagr >/dev/null || { echo "start-orchestrator: dagr is not on PATH." >&2; exit 1; }

cd "$root"
mkdir -p .dagr
RUN_FILE="$run" GRAPH="$graph" python3 - <<'EOF'
import glob, json, os, sys

pane = os.environ["HERDR_PANE_ID"]
graph, out = os.environ["GRAPH"], os.environ["RUN_FILE"]
merged = os.environ.get("MERGED", "").split()

d = json.load(open(graph, encoding="utf-8"))
d["run"]["orchestrator"] = {
    "pane": pane, "mode": "delegate", "max_in_flight": 1,
    # The default guards src/, scripts/, packages/ and tools/. The rest are the other places
    # this plan's tasks edit: Motoko's file tools are rooted at the shared checkout.
    "guarded_paths": ["src/", "scripts/", "packages/", "tools/", ".agent/", ".github/",
                      ".motoko/config/", "Makefile", "SYSTEM.md", "AGENTS.md"]}

unknown = [i for i in merged if i not in {t["id"] for t in d["tasks"]}]
if unknown:
    sys.exit("start-orchestrator: MERGED names no such task: " + " ".join(unknown))
for t in d["tasks"]:
    if t["id"] in merged:
        # A done task needs an attempt, or dagr rejects the document.
        t["state"] = "done"
        t["attempts"] = [{"id": t["id"] + "·a1", "n": 1, "cause": {"type": "initial"},
                          "actor": "operator", "state": "done",
                          "started_at": d["generated_at"], "ended_at": d["generated_at"],
                          "outcome": {"result": "done", "evidence": "reported",
                                      "reason": "merged; declared done by the operator for this session"}}]
json.dump(d, open(out + ".tmp", "w", encoding="utf-8"), indent=2, ensure_ascii=False)

# Another run file that names this pane makes Motoko the orchestrator of that run as well.
others = []
for path in sorted(glob.glob(".dagr/*.json")):
    if path == out:
        continue
    try:
        o = (json.load(open(path, encoding="utf-8")).get("run") or {}).get("orchestrator") or {}
    except Exception:
        continue
    if o.get("pane") == pane and str(o.get("mode", "")).strip().lower() == "delegate":
        others.append(path)
if others:
    print("start-orchestrator: WARNING: these run files name this pane too, so Motoko will be the",
          "orchestrator of them as well:", " ".join(others), file=sys.stderr)

# Delegates are started with no flags, so this setting decides whether they stop to ask.
try:
    mode = (json.load(open(os.path.expanduser("~/.claude/settings.json"), encoding="utf-8"))
            .get("permissions") or {}).get("defaultMode")
except Exception:
    mode = None
if not mode:
    print("start-orchestrator: WARNING: ~/.claude/settings.json sets no permissions.defaultMode.",
          "A Claude delegate will stop at its first shell command.", file=sys.stderr)

print("start-orchestrator: pane", pane, "| merged:", " ".join(merged) or "none",
      "| delegates' permission mode:", mode or "not set")
EOF

if [ "$(dagr check "$run.tmp" --strict --json)" != "[]" ]; then
  echo "start-orchestrator: $run.tmp does not pass dagr check --strict. Nothing was started." >&2
  dagr check "$run.tmp" --strict >&2 || true
  exit 1
fi
mv "$run.tmp" "$run"
echo "start-orchestrator: wrote $run"

if [ "$start" = 0 ]; then exit 0; fi
echo "start-orchestrator: starting Motoko. Paste the prompt when it is up."
exec make motoko "$@"
