# PR: CSP initial research

## Summary

Base branch: `arniwesth/mot-25-code-graph-poc`.

This branch adds CSP-core feasibility research grounded with the existing code-graph tooling from the
base branch. A `run_tool_select` implementation spike was attempted and then reverted; the retained
outcome is research, smokes, diagrams, handoff docs, and a direction note recommending a
phase-oriented AILANG core over CSP-first architecture on AILANG v0.26.0.

## Changes

- Add `.agent/projects/003_CSP_core_refactor/` with feasibility research, ADR, implementation plans,
  handoff docs, and architecture diagrams for a possible CSP tool-phase refactor.
- Add substrate smokes proving `std/stream` behavior: handler-side `Net`/stubbed `AI`,
  source-name routing, process exit-code surfacing, and raw `asyncExecProcess` not streaming stderr.
- Document the reverted `run_tool_select` spike and why it only produced a CSP-shaped seam rather
  than a true CSP tool phase.
- Add `NOTE-why-not-csp-now.md`, documenting why CSP is not the right primary core architecture on
  AILANG v0.26.0 and recommending a phase-oriented core with strict transcript boundaries.
- Add a session summary for the implementation/revert/architecture decision.

## Verification

- `ailang check src/core/agent_loop_v2.ail`
- `ailang check src/core/tool_runtime.ail`
- `ailang check src/core/types.ail`
- Production scan confirmed no remaining `run_tool_select` / wrapper / `parallel_safe` references in
  `src` or `scripts` after the revert.
