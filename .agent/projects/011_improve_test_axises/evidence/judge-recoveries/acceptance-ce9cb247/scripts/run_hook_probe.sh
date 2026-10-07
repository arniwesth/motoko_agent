#!/usr/bin/env bash
# Acceptance of ADR-003's rules (011 WI-4), precondition 4: the model-calling-hook probe.
# Copies ../hook-probe/hook_calls_model_probe.ail into the scratch worktree's scripts/dst/, runs
# it once with the gate recipe's capability list, keeps the non-wire output, and removes the copy.
set -u
S=${ACCEPT_SCRATCH:-/workspaces/motoko_agent-011-accept-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail src/core/dst_invariants.ail"
P=scripts/dst/hook_calls_model_probe.ail
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ]; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
intact || { note "P4 ABORT: scratch worktree is not at baseline"; exit 8; }
cp "$E/hook-probe/hook_calls_model_probe.ail" "$P"
w0=$(date +%s); u0=$(up)
timeout 900 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
  --entry main "$P" < /dev/null > "$E/hook-probe/probe.full" 2>&1
rc=$?
grep -v '^{' "$E/hook-probe/probe.full" > "$E/hook-probe/probe.out"; rm -f "$E/hook-probe/probe.full"
echo "rc=$rc wall_secs=$(( $(date +%s) - w0 )) uptime_secs=$(( $(up) - u0 ))" > "$E/hook-probe/rc"
rm -f "$P"
note "P4 hook probe: $(cat "$E/hook-probe/rc"); $(grep -c '^HOOKPROBE ' "$E/hook-probe/probe.out") HOOKPROBE row(s)"
note "run_hook_probe.sh done; $(intact && echo 'INTEGRITY: the five files at baseline, scratch worktree clean' || echo 'INTEGRITY: FAIL')"
