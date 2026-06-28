#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

STRUCTURAL_ONLY=0
FORCE=0
PROFILE=core
INCLUDE_TESTS=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --structural-only) STRUCTURAL_ONLY=1 ;;
    --force) FORCE=1 ;;
    --include-tests) INCLUDE_TESTS=1 ;;
    --profile=*) PROFILE="${arg#--profile=}" ;;
    --profile) echo "--profile requires --profile=<core|all|smoke>" >&2; exit 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: tools/code-graph/extract.sh [--profile=<core|all|smoke>] [--include-tests] [--structural-only --force]

Default: run the full extractor for the core profile, including iface typed data
and effects. Core excludes smoke scripts, examples, *_test.ail, and src/core/test.

--profile=core     Core source only (default).
--profile=all      Old broad graph: src, scripts, and examples.
--profile=smoke    Smoke/example entry points only.
--include-tests    Include core test modules in the core profile.
--structural-only  Diagnostic mode. Skips iface and overwrites typed/effect CSVs.
                   Requires --force if a full cache already exists.
--force            Confirm structural-only cache downgrade.
EOF
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

ARGS+=(--profile "$PROFILE")
if [[ "$INCLUDE_TESTS" == "1" ]]; then
  ARGS+=(--include-tests)
fi

export PYTHONPATH="$ROOT/tools/code-graph:${PYTHONPATH:-}"

if [[ "$STRUCTURAL_ONLY" == "1" ]]; then
  if [[ "$FORCE" != "1" ]]; then
    python3 tools/code-graph/extractor/emit.py "${ARGS[@]}" --structural-only
  else
    python3 tools/code-graph/extractor/emit.py "${ARGS[@]}" --structural-only --force
  fi
else
  python3 tools/code-graph/extractor/emit.py "${ARGS[@]}"
fi

python3 tools/code-graph/viz/visualize.py --module-deps || true
