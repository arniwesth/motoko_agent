#!/usr/bin/env bash
# Wrapper for the D9 ledger-trace exporter (project 010, plan task 3.1).
#
# Supplies the three things the exporter cannot get for itself: the capability
# set, the AI stub, and run identity (AILANG version + motoko commit) injected
# through Env so the output header is joinable to a run without parsing
# filenames.
#
# CAPS ARE COPIED FROM THE MAKEFILE'S `discovery` TARGET VERBATIM (Makefile:391).
# This is deliberate and was budgeted, not inherited: several older targets still
# show `--caps IO` alone, which is stale — a DST run needs `Trace` regardless of
# `--emit-trace`, because the wire emission path IS an AILANG Trace effect.
#
# ONE PROFILE + ONE SEED PER INVOCATION (D9, from the Q3 topology probe). Many
# seeds means many invocations; that is embarrassingly parallel by construction,
# which is exactly why the topology decision went this way.
#
# Usage:
#   scripts/dst/run_export_trace.sh --seed 7
#   scripts/dst/run_export_trace.sh --seed 7 --profile driver_only --out-dir tools/code-graph/.out
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CAPS="IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace"
SEED=""
PROFILE="driver_only"
OUT_DIR="tools/code-graph/.out"
QUIET=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed) SEED="${2:-}"; shift 2 ;;
    --seed=*) SEED="${1#--seed=}"; shift ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --out-dir=*) OUT_DIR="${1#--out-dir=}"; shift ;;
    --show-wire) QUIET=0; shift ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      echo "  --show-wire   do not filter the driver's stdout wire stream"
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$SEED" ]] || { echo "--seed is required" >&2; exit 2; }
[[ "$SEED" =~ ^-?[0-9]+$ ]] || { echo "--seed must be an integer, got '$SEED'" >&2; exit 2; }

# Run identity. Both are recorded in the trace header; neither is a wall clock,
# because re-running the same seed must be byte-identical and a timestamp would
# destroy that silently.
export CG_EXPORT_SEED="$SEED"
export CG_EXPORT_PROFILE="$PROFILE"
export CG_OUT_DIR="$OUT_DIR"
export CG_AILANG_VERSION="$(ailang --version 2>/dev/null | head -1 || echo unknown)"
export CG_MOTOKO_COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

# The driver streams its wire projection to stdout during the run (an AILANG
# Trace effect). Filtering it here is cosmetic only: the exporter writes its
# output through the FS effect and never reads this stream — that is D9's
# rejected alternative, not its input.
if [[ "$QUIET" == "1" ]]; then
  ailang run --caps "$CAPS" --ai-stub --entry main scripts/dst/export_trace.ail < /dev/null \
    | grep -v '^{' || true
else
  ailang run --caps "$CAPS" --ai-stub --entry main scripts/dst/export_trace.ail < /dev/null
fi

DEST="$OUT_DIR/traces/$PROFILE/$SEED.jsonl"
[[ -f "$DEST" ]] || { echo "export_trace: expected $DEST to exist; the run did not write it" >&2; exit 1; }
echo "export_trace: $DEST ($(wc -l < "$DEST") lines)"
