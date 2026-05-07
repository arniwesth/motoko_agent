#!/usr/bin/env bash
# setup_dp7_smoke_workdirs.sh — prepare /tmp dirs for smoke_v2_dp7_gate.ail
set -euo pipefail

# Broken workdir: check_core always fails so DP7 must reject.
mkdir -p /tmp/dp7-smoke
cat > /tmp/dp7-smoke/Makefile <<'MK'
check_core:
	@echo "Error: simulated type failure for DP7 smoke at src/core/fake.ail:1:1" >&2
	@exit 1
MK

# Passing workdir: check_core always succeeds so DP7 must approve.
mkdir -p /tmp/dp7-smoke-pass
cat > /tmp/dp7-smoke-pass/Makefile <<'MK'
check_core:
	@echo "src/core/ type-check: 0 passed, 0 failed (mock pass)"
	@exit 0
MK

# Empty workdir: exists but has no Makefile. make emits "No targets specified
# and no makefile found" — the canonical infrastructure-missing signal that
# DP7's is_missing_infrastructure() should match for fail-open behaviour.
# (We previously used a non-existent dir, but bash's cd error went to stderr
# unredirected by the verifier's `2>&1`; an existing-but-empty dir gives a
# fairer test of the fail-open detection.)
mkdir -p /tmp/dp7-smoke-empty

echo "DP7 smoke workdirs ready:"
echo "  /tmp/dp7-smoke       (always-fail check_core — DP7 should reject)"
echo "  /tmp/dp7-smoke-pass  (always-pass check_core — DP7 should approve)"
echo "  /tmp/dp7-smoke-empty (no Makefile at all — DP7 should fail-open)"
