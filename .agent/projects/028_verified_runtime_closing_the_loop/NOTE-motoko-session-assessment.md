# NOTE — Motoko session assessment (2026-08-29)

Assessment of Motoko by a full working session: demo build-out, deliberate-bug
Z3 test, gate runs, bug reproduction, and source archaeology. Every claim below
is backed by a tool result from that session.

## What was verified

| Item | Result |
|---|---|
| `make check_core` | 56 passed, 0 failed (incl. WIP files) |
| `make verify_core` | 0 failed; 2 files with contracts, 51 without (`tool_runtime.ail` 4 proven) |
| Z3 commit gate | Planted bug (`buggyMax`) → `check: passed \| verify: failed \| committed: no`; fixed version → `verify: verified \| committed: yes` |
| Runtime telemetry | Stable system-prefix digest, cache-read attribution, compaction stats — live and honest |
| Architecture | `rpc.ail` thin entry → `agent_loop_v2` typed tool-use loop (legacy text parser deleted at M10b) |

## Defects found (all reproduced, not hypothesized)

1. **Scratchpad batch short-circuit** (`src/tui/src/env-server.ts` ~L874):
   any cell requesting an unavailable backend voids the WHOLE batch — returned
   as `exit_code: 0` with a one-line notice and empty `cells` payload. Zero
   tests pin this path (`env-server.test.ts` has nothing on "were skipped").
   Same veto pattern exists for python3 and the ailang CLI.
2. **DP7 finalization gate is fail-open** (`src/core/session.ail:1804`):
   `Err(_) => Approve` — if the verifier itself cannot run, the gate approves.
   Also gated behind `rt.verification.enabled` (config-switchable).
   The gate EXISTS (runs `make check_core` pre-finalize, injects rejection
   feedback) but its default inverts its own philosophy.
3. **Documentation drift**: project instructions reference `ailang/FORK.md`,
   which does not exist in this checkout. Real fork docs: `ARCHITECTURE.md`,
   `MOTOKO.md`.
4. **Optional-backend fragility**: Lean/Lake and ripgrep both missing in the
   demo container; ripgrep absence makes the `Search` tool itself inert.

## Structural observation

Verification discipline lives in 66 AILANG files (~35K lines); 1,175 TS files
run outside any verifier — including the tool-execution layer the verified core
must trust. The `ohmy_pi` token-storm fix (CHANGELOG, M-MOTOKO-OHMY-PI-DEFAULT-FLIP)
shows the right improvement loop: agent finds bug → A/B repro → fail-fast guard
→ pinned regression smoke. That loop is the model for closing everything above.

## Verdict

Concept 9/10, execution 7/10, current usability 6/10.
See ADR-001 for what earns the 10th point; PLAN-001 for the work items.
