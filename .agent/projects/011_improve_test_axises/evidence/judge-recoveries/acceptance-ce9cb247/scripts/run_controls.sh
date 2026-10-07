#!/usr/bin/env bash
# Acceptance of ADR-003's rules (011 WI-4): the unmutated controls that are not the gate itself.
# `make invariants`, `make stream_parity` and the invariant module's inline tests, each at the
# commit handed in, on the unedited scratch worktree. The gate's own unmutated run and the
# comment-only control K0 are `run_row.sh C-gate` and `run_row.sh K0`.
set -u
S=${ACCEPT_SCRATCH:-/workspaces/motoko_agent-011-accept-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail src/core/dst_invariants.ail"
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ]; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
intact || { note "controls ABORT: scratch worktree is not at baseline"; exit 8; }
one() { # $1 = id, rest = command
  local id=$1; shift
  local d="$E/runs/$id"; rm -rf "$d"; mkdir -p "$d"
  local w0=$(date +%s) u0=$(up)
  timeout 1200 "$@" > "$d/out.txt" 2>&1 < /dev/null; local rc=$?
  echo "rc=$rc wall_secs=$(( $(date +%s) - w0 )) uptime_secs=$(( $(up) - u0 )) load=$(cut -d' ' -f1-3 /proc/loadavg)" > "$d/rc"
  note "$id ($*): $(cat "$d/rc")"
}
one C-invariants make invariants
one C-stream-parity make stream_parity
one C-inline-tests ailang test src/core/dst_invariants.ail
note "run_controls.sh done; $(intact && echo 'INTEGRITY: the five files at baseline, scratch worktree clean' || echo 'INTEGRITY: FAIL')"
