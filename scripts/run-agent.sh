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

exec bun "$ENTRY" "$@"
