#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

STRUCTURAL_ONLY=0
if [[ "${1:-}" == "--structural-only" ]]; then
  STRUCTURAL_ONLY=1
fi

export PYTHONPATH="$ROOT/tools/code-graph:${PYTHONPATH:-}"

if [[ "$STRUCTURAL_ONLY" == "1" ]]; then
  python3 tools/code-graph/extractor/emit.py --structural-only
else
  python3 tools/code-graph/extractor/emit.py
fi

python3 tools/code-graph/viz/visualize.py --module-deps || true
