# 2026-07-02 CSP run_tool_select implementation, revert, and architecture decision

## Context

This session started from the handoff to implement Phase-1 `run_tool_select` from
`.agent/projects/003_CSP_core_refactor/PLAN-phase1-run-tool-select.md`. The target was a
flag-gated replacement for `dispatch_calls` in `src/core/agent_loop_v2.ail`, backed by
`std/stream.selectEvents`, while preserving the old path until parity passed.

The work was done on branch `arniwesth/mot-26-csp-initial-research`, using AILANG v0.26.0 commit
`3b52a24`.

## Implementation work that happened

The initial implementation sequence landed as separate commits:

- `02b7b00 Retire asyncExecProcess substrate risks`
  - Added smokes for `asyncExecProcess` source-name routing and stderr/exit-code behavior.
  - Confirmed `SourceBytes(name, bytes)` is keyed by the supplied source `name`.
  - Confirmed exit code surfaces as `Closed(code, reason)`.
  - Confirmed stderr does not surface as a stream event.
- `c4fc649 Scaffold run_tool_select flag path`
  - Added a flag-gated `run_tool_select` path and wired both tool call sites.
- `b83725a Preflight tool policy before select path`
  - Added batch policy preflight before the new path.
- `04089e1 Add parallel_safe tool capability flag`
  - Added the `parallel_safe` tool capability flag.
- `1e42776 Add tool select frame protocol validator`
  - Added `src/core/tool_select_frames.ail`.
- `aa4ae96 Synthesize provider-valid cancelled tool results`
  - Added cancelled-result synthesis behavior.
- `88dc252 Add adjusted phase1 parity smoke runner`
  - Added a Phase-1 parity runner.
- `d0017f7 Route live process tools through stream wrapper`
  - Added `scripts/tool_stream_wrapper.py` and wrapper smoke.
  - Worked around stderr loss by wrapping process execution and writing stdout/stderr/exit files.

The implementation was verified at the time with focused `ailang check` commands and the Phase-1
parity runner. It restored final transcript/TUI-result fidelity for wrapped process tools, but it
did not make the tool phase a full CSP multiplexer.

## Code-graph refresh

The code graph was refreshed per `tools/code-graph/AGENTS.md`:

```bash
tools/code-graph/extract.sh
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/query/cgq.py sql "SELECT * FROM extraction_status"
```

Result: core profile extracted successfully, 25/25 modules OK, graph/source index not stale.

## Diagrams and Phase-1b plan

After reviewing the implementation, we noted that the code changes were smaller than a true CSP
architecture would imply. A code-graph-grounded diagram was written:

- `.agent/projects/003_CSP_core_refactor/DIAGRAM-phase1-run-tool-select-codegraph.md`

The diagram describes the actual implemented shape: a CSP-shaped seam inside the existing sequential
core, with the old `dispatch_calls` fallback still present.

A follow-up delta plan was written:

- `.agent/projects/003_CSP_core_refactor/PLAN-phase1b-real-tool-select.md`

That plan describes what would be required to make `run_tool_select` a real event-driven tool phase:
wrapper frames as production input, batch partition/state, native multi-source `selectEvents`,
control/cancellation source, separate deferred stage, final assembly in `run_tool_select`, live TUI
output, and a Phase-1b parity suite.

## Architectural reassessment

We then stepped back and asked whether CSP was the right architecture at all, especially given the
project goal of moving functionality from TypeScript into AILANG core.

Conclusion:

- A host-runtime CSP kernel in TypeScript/Bun would be technically attractive, but is a no-go because
  the long-term direction is to move functionality into AILANG.
- A true CSP architecture inside AILANG v0.26.0 is not currently the best fit because:
  - `std/ai` model calls remain blocking.
  - raw `asyncExecProcess` is stdout-only for stream data.
  - handler-side effects are possible in smokes but risky for production core dispatch.
  - process-source cancellation is coarse.
  - deferred extension/scratchpad tools remain sequential.

The recommended direction became a phase-oriented AILANG core:

- deterministic turn/step state machine;
- explicit phase contracts;
- strict transcript builder;
- append-only event ledger;
- normalized provider/tool/hook envelopes;
- `std/stream` only as contained stream islands where the substrate fits.

The rationale was written to:

- `.agent/projects/003_CSP_core_refactor/NOTE-why-not-csp-now.md`

That note was reviewed iteratively and tightened to avoid major inconsistencies with the retained
research:

- It now clarifies that handler-side effects are possible but risky.
- It clarifies that raw streaming HTTP exists, but preserving `std/ai` keeps the model phase blocking.
- It scopes stream islands to stdout-safe tools or explicitly wrapped/tested stderr protocols.
- It states the note supersedes the current implementation direction for the branch, not the
  historical ADR/plan text.

## Revert

The production CSP implementation was reverted with one normal revert commit:

- `d5bb7cc Revert Phase 1 run_tool_select implementation`

This reverted the production implementation commits from `c4fc649` through `d0017f7`, while
preserving the earlier substrate-smoke/research commit `02b7b00`.

The revert removed:

- `run_tool_select` production wiring and helper logic from `src/core/agent_loop_v2.ail`;
- `parallel_safe` type/runtime changes;
- `src/core/tool_select_frames.ail`;
- `scripts/tool_stream_wrapper.py`;
- `scripts/smoke_run_tool_select_wrapper.ail`;
- `.agent/projects/003_CSP_core_refactor/smoke/run_phase1_parity.sh`;
- wrapper references in the CSP docs/smoke README.

Post-revert verification:

```bash
ailang check src/core/agent_loop_v2.ail
ailang check src/core/tool_runtime.ail
ailang check src/core/types.ail
rg "run_tool_select|MOTOKO_RUN_TOOL_SELECT|tool_select_frames|parallel_safe|tool_stream_wrapper" src scripts
```

The checks passed and no production references remained in `src` or `scripts`.

## Current branch state at summary time

Recent commits:

- `55c8ac1 Iterative review`
- `2124489 Added note on CSP deferred`
- `71b0118 Post implentation docs`
- `d5bb7cc Revert Phase 1 run_tool_select implementation`

Worktree status at the end of the session:

- only unrelated untracked `oh-my-pi/` remained.

## Practical takeaway

Do not continue the reverted Phase-1 `run_tool_select` implementation as the next architecture.
Keep the CSP research and smokes as evidence. For a core rewrite on AILANG v0.26.0, start from the
phase-oriented architecture described in `NOTE-why-not-csp-now.md`, with transcript validity and
phase boundaries as the first-class concerns.

