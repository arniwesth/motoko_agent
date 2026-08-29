# PLAN-001 — Closing the loop: work items from the 2026-08-29 assessment

Ordered by leverage. Items 1-2 are small and close the two loudest gaps.

## 1. Flip the DP7 gate to fail-closed

- File: `src/core/session.ail` (funcs `run_dp7_verifier` ~L1800, `dp7_gate` ~L1816)
- Change `Err(_) => Approve` → `Err(_) => Reject(infra-error-reason)`; thread
  the error text into the `Dp7VerifierRejected` feedback message so the agent
  sees WHY (e.g. "verifier could not run: <err>"), distinguishing infra
  failure from check failure.
- Update the DP7 design doc (`design_docs/planned/m-motoko-dp7-verifier-gate.md`
  — stale filename reference noted in prior session logs).
- Add regression: simulated verifier failure (missing make / bad command) must
  produce a rejection event, not approval.

## 2. Fix scratchpad batch semantics

- File: `src/tui/src/env-server.ts` (`runScratchpadCells` ~L874)
- Replace the three availability vetoes (py / ail / lean) with per-cell
  skipping: run available cells, emit skipped-cell results with the notice,
  batch exit non-zero only when ALL cells were skipped or a run failed.
- Pin with tests in `env-server.test.ts`: mixed batch + missing lean must run
  the py cell AND mark the lean cell skipped (currently zero coverage).

## 3. Close the doc drift

- Create `ailang/FORK.md` or update the references to it (SYSTEM.md and the
  agent instructions cite it; it does not exist). Content per the original
  intent: rebase-forward policy + fork surface inventory; candidate sources:
  `ailang/ARCHITECTURE.md`, `ailang/MOTOKO.md`.

## 4. Environment preflight (optional-backend honesty)

- Startup (or first-use) check that reports missing optional backends
  (lake, rg) once, loudly — instead of per-call notices or inert tools.
- Complements (does not replace) item 2's per-cell semantics.

## 5. Claim provenance (design, larger)

- Extend the verification vocabulary to final answers: cite tool-call IDs /
  artifacts for factual claims; flag unbacked claims. Design doc first, then
  a DP-style gate. Ties into `025_envharness_contracts` thinking.

## Non-goals

- No new autonomy features, no model changes. This plan only closes
  enforcement gaps that already have working machinery one semantic flip away.
