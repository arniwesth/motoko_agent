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
# Locally-built AILANG binary, used only when AILANG_BIN is not already set so
# an explicit override always wins. The repo's build emits it under
# ailang/.bin/ailang (this is where the patched Bedrock OPENAI_BASE_URL
# fallback binary lands); ailang/bin/ailang is kept as a historical fallback.
LOCAL_AILANG_BIN=""
for candidate in "${PROJECT_ROOT}/ailang/.bin/ailang" "${PROJECT_ROOT}/ailang/bin/ailang"; do
  if [[ -x "$candidate" ]]; then
    LOCAL_AILANG_BIN="$candidate"
    break
  fi
done

if [[ ! -f "$ENTRY" ]]; then
  echo "Error: src/tui/src/index.ts not found." >&2
  echo "Build it first:" >&2
  echo "  cd ${PROJECT_ROOT}/src/tui && bun install && bun run build" >&2
  echo "Or run: ./scripts/install-prerequisites.sh" >&2
  exit 1
fi

if [[ -z "${AILANG_BIN:-}" && -n "$LOCAL_AILANG_BIN" ]]; then
  export AILANG_BIN="$LOCAL_AILANG_BIN"
fi

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

exec bun "$ENTRY" "$@"
