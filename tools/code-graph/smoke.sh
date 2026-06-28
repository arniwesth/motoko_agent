#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

tools/code-graph/extract.sh
python3 tools/code-graph/query/cgq.py --no-banner status >/dev/null
python3 tools/code-graph/query/cgq.py --no-banner --limit 5 q callers dispatch_step >/dev/null
python3 tools/code-graph/query/cgq.py --no-banner --limit 5 q reaches Net >/dev/null
python3 tools/code-graph/query/cgq.py --no-banner q failures >/dev/null
python3 tools/code-graph/viz/visualize.py --core-extensions >/dev/null

echo "code-graph smoke ok"
