#!/usr/bin/env bash
# run-agent.sh
#
# Run Motoko from any working directory.
# Resolves src/tui/src/index.ts relative to this script's project root,
# so the path is always correct regardless of where the command is invoked.
#
# Usage:
#   ./scripts/run-agent.sh [task]
#   ./scripts/run-agent.sh "Fix the off-by-one in parse_config"
#
# Environment variables (all optional):
#   MODEL    - model to use (default: anthropic/claude-sonnet-4-6)
#   WORKDIR  - repo to operate on (default: current directory)
#   ENV_PORT - port for the embedded environment server (default: 8080)
#   TASK     - task text; overridden by the first positional argument
#
# Examples:
#   MODEL=openai/gpt-4o WORKDIR=/path/to/repo ./scripts/run-agent.sh
#   ./scripts/run-agent.sh "Add unit tests for the parser"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENTRY="${PROJECT_ROOT}/src/tui/src/index.ts"
LOCAL_AILANG_BIN="${PROJECT_ROOT}/ailang/bin/ailang"

if [[ ! -f "$ENTRY" ]]; then
  echo "Error: src/tui/src/index.ts not found." >&2
  echo "Build it first:" >&2
  echo "  cd ${PROJECT_ROOT}/src/tui && bun install && bun run build" >&2
  echo "Or run: ./scripts/install-prerequisites.sh" >&2
  exit 1
fi

if [[ -x "$LOCAL_AILANG_BIN" ]]; then
  export AILANG_BIN="$LOCAL_AILANG_BIN"
fi

# Restore registry dependencies the AILANG cache has lost.
#
# Registry packages in ailang.lock (sunholo/logging) are read from
# ~/.ailang/cache/registry/<vendor>/<name>/<version>, outside the repo. A
# fresh container or a wiped home leaves that empty, and the runtime then
# exits 1 during package resolution, before it emits a single event, so the
# TUI shows only "The AILANG runtime exited with code 1 before it reported
# done or an error". `ailang lock --check` fetches whatever is missing and
# writes nothing to the repo. It runs only when a package is missing: with
# the cache warm it would add nothing, and it also fails on a merely stale
# lock, which is not this script's business. (AILANG_CACHE_DIR does not move
# the registry cache, so the path is fixed.)
ensure_registry_cache() {
  local lock="${PROJECT_ROOT}/ailang.lock"
  local cache="${HOME}/.ailang/cache/registry"
  [[ -f "$lock" ]] || return 0
  local missing
  missing="$(LOCK="$lock" CACHE="$cache" bun -e '
    const fs = require("fs");
    const lock = JSON.parse(fs.readFileSync(process.env.LOCK, "utf8"));
    for (const p of lock.packages ?? []) {
      if (p.source !== "registry") continue;
      const dir = `${process.env.CACHE}/${p.name}/${p.version}`;
      if (!fs.existsSync(dir)) console.log(`${p.name}@${p.version}`);
    }
  ' 2>/dev/null)" || return 0
  [[ -n "$missing" ]] || return 0
  echo "AILANG registry cache is missing: $(echo "$missing" | tr '\n' ' ')- fetching." >&2
  local out
  if ! out="$("${AILANG_BIN:-ailang}" lock --check 2>&1)"; then
    echo "Warning: could not restore the registry cache; the runtime may fail to start:" >&2
    echo "$out" >&2
  fi
}

# cd into PROJECT_ROOT before exec'ing bun. motoko_agent's runtime reads its
# own `src/core/*.ail` source files via paths relative to CWD (supervisor.ail,
# agent_loop_v2.ail, ext/*.ail, etc. are loaded dynamically by the TS host).
# Without this cd, invoking `motoko` from a foreign directory — e.g. the
# AILANG eval-harness's per-benchmark tmpdir, or a Docker container where the
# binary is symlinked to /usr/local/bin/motoko — fails on the first runtime
# file-read with `cannot read file 'src/core/supervisor.ail'`. The motoko TUI
# silently hangs in that path because the read error isn't surfaced to stderr
# before the agent loop initialises.
#
# The task workspace (where solution.{ail,py} lives) is decoupled via the
# WORKDIR env var — motoko reads/writes WORKDIR for task I/O, never CWD.
cd "$PROJECT_ROOT"
ensure_registry_cache

exec bun "$ENTRY" "$@"
