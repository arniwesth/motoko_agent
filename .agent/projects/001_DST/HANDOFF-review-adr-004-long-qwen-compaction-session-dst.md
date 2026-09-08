# Handoff: independently review ADR-004-long-qwen-compaction-session-dst.md

Audience: a fresh agent session with no context from the authoring session. Your distance from
the author is the point — you are the check the author cannot perform on themselves.

## Mission

Adversarially review `.agent/projects/001_DST/ADR-004-long-qwen-compaction-session-dst.md`
and its diagram `.agent/projects/001_DST/mmd/adr-004-long-qwen-compaction-dst.mmd`.

The ADR scopes deterministic testing for a long, Qwen-labeled session that triggers several
`compaction_ai` compactions. Your job is to find stale anchors, untestable claims, hidden
nondeterminism, and any design choice that would make the follow-up plan fail or drift into a
live-provider benchmark.

## Inputs (read in this order)

1. `.agent/projects/001_DST/ADR-004-long-qwen-compaction-session-dst.md` — the ADR under review.
2. `.agent/projects/001_DST/mmd/adr-004-long-qwen-compaction-dst.mmd` and the rendered `.svg`.
3. `.agent/projects/001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` — current
   compaction DST split and ledger-as-recorder decision.
4. `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md`, especially
   the Review Comments section — this is the output quality bar.
5. `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md` and
   `.agent/projects/004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md`.
6. Source as needed, with these anchors mandatory:
   - `src/core/session.ail` — `ext_ai_step`, `ext_ports_of`, `mk_v2_ext_ctx`,
     `CallModel` arm, trace threading, `run_v2_session_traced`.
   - `src/core/test/stub_step.ail` — `scripted_ports_from_steps`, `dispatch_step`.
   - `src/core/test/scripted_ports.ail` — `run_v2_with_scripted_ports` and what it does not expose.
   - `src/core/phase_vocab.ail` — `LedgerTrace`, `CompactionStageRecord`,
     `ProviderCallPrepared`, schema-v1 projection.
   - `src/core/ext/runtime.ail` — `dispatch_pre_step_chain`, stage outcomes, artifact threading.
   - `packages/motoko-ext-compaction-ai/compaction_ai.ail` — `ai_step`, summary prompt,
     digest/cache, returned artifacts.
   - `packages/motoko-ext-abi/types.ail` — `ExtCtx`, `ExtPorts`, `PreStepDecision`.
   - `packages/motoko_ext_conformance/invariants.ail` — compactor-output law.
   - `src/core/context_usage.ail` and `.motoko/model-catalog.json` — catalog lookup and Qwen limits.

## Review method (all four passes required)

1. **Citation audit.** Verify every `file:line` reference in ADR-004 and every source-grounded
   claim in the Mermaid diagram against current source. Wrong line numbers, stale filenames,
   paraphrases that misstate behavior, and claims the source does not support are findings.

2. **Feasibility attack.** Try to implement the ADR mentally against the current seams:
   - Can a routed `Ported(Ports)` provider distinguish normal agent calls from `compaction_ai`
     summarizer calls without relying on model string?
   - Does the ADR correctly avoid `scripted_ports_from_steps` assistant-count indexing after
     compaction changes payload shape?
   - Can test `on_tool_handle` produce large deterministic tool results on the production
     `dispatch_tool_entries` path?
   - Can the cache-reuse oracle be expressed without mutable call counters, or is the proposed
     sentinel-summary approach sufficient?
   - Does the test catalog override via `MOTOKO_MODELS_FILE` actually affect
     `catalog_context_limit_for` in the session path?

3. **Oracle consistency pass.** Check that every invariant is observable from the proposed oracle:
   - `CompactionStageRecord` / `TraceStageApplied` count from in-memory trace, not wire
     `compaction_extension`.
   - `provider_call_prepared` fields for system-prefix presence and payload digest only, not full
     payload body.
   - Direct `compaction_ai` / chain scenarios for tool-pairing and `validate_compactor_output`.
   - Replay determinism over a normalized trace with volatile session/time fields removed.
   Flag any invariant that still depends on hidden provider payloads, live model prose, timing, or
   network availability.

4. **Scope and diagram attack.** Check the ADR and Mermaid diagram for drift:
   - Live Qwen/OpenRouter must remain calibration evidence only, never a CI oracle.
   - The diagram must match the ADR's split: live calibration, deterministic replay, production path,
     ledger oracle, direct extension scenarios, fast gate.
   - The diagram should not imply the ledger contains full payloads or that wire events include
     `ext_id`.
   - The acceptance criteria must be plan-ready: each item maps to an implementable artifact or gate.

## Output contract

Append a `## Review Comments` section to ADR-004 itself. Do not rewrite the ADR body unless the
user explicitly asks you to revise after review.

Number findings `R1..Rn`, most severe first. Each finding must include:

- The defect in one sentence.
- Grounding: file/line reference or reproduced command output.
- Concrete **Action:**.

Close with:

- `What is accurate` — short paragraph naming the claims that held up.
- `Recommended pre-implementation actions` — short list ordered by dependency.

State your model/date at the top of the section.

## Constraints

- Do not modify source code, plans, profiles, catalog, or the Mermaid diagram during review.
  Findings only.
- Do not re-litigate the settled DST principle that real providers are supplemental smokes. Attack
  only claims that conflict with source, observability, determinism, or acceptance criteria.
- If you run commands, report exact commands for any failing or surprising result.
- If no major findings remain, say that clearly and still record residual risks or test gaps.
