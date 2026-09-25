# Handoff: write the plan for ADR-004 long Qwen compaction-session DST

Audience: a fresh agent session that will write the implementation plan, not implement code yet.
You are deliberately fresh. Your job is to turn the reviewed ADR into a concrete, sequenced plan
that another agent can execute without rediscovering the same constraints.

## Mission

Write `PLAN-long-qwen-compaction-session-dst.md` in `.agent/projects/001_DST/`.

The plan implements `.agent/projects/001_DST/ADR-004-long-qwen-compaction-session-dst.md`: a
deterministic, Qwen-labeled long-session DST that triggers several `compaction_ai` applications,
plus direct `compaction_ai` scenarios for output-shape validity and artifact-cache reuse. The live
OpenRouter/Qwen run is calibration evidence only and must not become the CI oracle.

## Inputs (read in this order)

1. `ADR-004-long-qwen-compaction-session-dst.md` — read the whole file, including both appended
   `## Review Comments` sections and the `Review disposition`.
2. `mmd/adr-004-long-qwen-compaction-dst.mmd` and the rendered `.svg` — keep the plan consistent
   with the diagram.
3. `ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` and
   `PLAN-compaction-dst-scenarios.md` — use their WI structure, verification style, and
   now-vs-gated discipline as the local template.
4. `004_phase_core_refactor/ADR-001-phase-oriented-core.md` and
   `004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — only for
   the phase-core and send-gate context the ADR cites.
5. Source anchors listed below. Re-verify them at current HEAD before trusting any line numbers.

## Ground truth to re-establish before writing

- `ailang --version` must be v0.26.0 / commit `3b52a24`, or the plan must call out the drift.
- Record `git rev-parse --short HEAD` and branch in the plan header.
- Confirm the OpenRouter Qwen model string used by the ADR remains
  `openrouter/qwen/qwen3.6-35b-a3b`; if you browse, cite the OpenRouter model page as live
  calibration evidence only.
- Confirm `.motoko/model-catalog.json` still lacks `openrouter/qwen/qwen3.6-35b-a3b` and still has
  `ollama/qwen3.6:35b-a3b-mxfp8: 262144`.
- Confirm `make compaction_dst` currently runs only the existing compaction DST scripts, then plan
  the new wiring.

## Mandatory source anchors

Re-verify these before planning work items:

- `src/core/session.ail`
  - `TracedSessionResult`
  - `ext_ai_step` / `ext_ports_of`
  - `mk_v2_ext_ctx`
  - the `CallModel` arm: `split_for_compaction`, `dispatch_pre_step_chain`,
    `emit_pre_step_stages`, `seal_compacted_payload`, `ProviderCallPrepared`, `dispatch_step`
  - trace threading and `run_v2_session_traced`
- `src/core/test/stub_step.ail`
  - `StepProvider`
  - `dispatch_step`
  - why `Ported(Ports)` does not thread state
  - why `scripted_ports_from_steps` assistant-count indexing is not valid after compaction
- `src/core/test/scripted_ports.ail`
  - `run_v2_with_scripted_ports` returns only final result, not trace
- `src/core/phase_vocab.ail`
  - `LedgerTrace`, `CompactionStageRecord`, `TraceStageApplied`, `TraceStageRejected`
  - `ProviderCallInfo`, `ProviderCallPrepared`, `ProviderResult`
  - schema-v1 projection for `provider_call_prepared`
- `src/core/ext/runtime.ail`
  - `dispatch_pre_step_chain`
  - `PreStepStage`, `StageApplied`, `StageRejected`, `StagePassed`
  - artifact threading
- `src/core/tool_phase.ail` and `src/core/ext/runtime.ail`
  - production `on_tool_handle` path for deterministic large tool results
- `packages/motoko-ext-compaction-ai/compaction_ai.ail`
  - summarizer prompt shape: one user message
  - `threshold_pct`, `keep_recent`, `old_turns == 0` pass-through, `pct >= 90` keep-recent halving
  - digest, artifact cache, summary message
- `packages/motoko-ext-abi/types.ail`
  - `ExtCtx`, `ExtPorts`, `ToolHandleDecision`, `PreStepDecision`
- `packages/motoko_ext_conformance/invariants.ail`
  - `validate_compactor_output`
- `src/core/context_usage.ail`
  - `MOTOKO_MODELS_FILE`
  - `catalog_context_limit_for`
- `.motoko/config/default/config.json` and `.motoko/config/*/compaction_ai.json`
  - existing extension order and default summarizer model

## Non-negotiable plan decisions

Carry these into the plan; do not reopen without new source evidence:

- Standing DST is deterministic/offline. No real OpenRouter/Qwen call belongs in the fast gate.
- The live Qwen run is calibration evidence only.
- The deterministic long-session model label is `openrouter/qwen/qwen3.6-35b-a3b`.
- Production catalog gets `openrouter/qwen/qwen3.6-35b-a3b: 262144`.
- Deterministic test uses a test `MOTOKO_MODELS_FILE` fixture that maps the same model label to a
  small limit.
- The provider is marker-routed `Ported(Ports)`. Do **not** use assistant-count indexing or mutable
  call counters as the only script clock after compaction.
- Summarizer calls are routed by prompt shape: exactly one user message and no system prefix, not by
  model string.
- Count compactions from in-memory `CompactionStageRecord` with `ext_id == "compaction_ai"` and
  `TraceStageApplied`.
- Negative compaction rejection is in-memory `TraceStageRejected` absence, not wire
  `ext_compaction_rejected` absence.
- `provider_call_prepared` proves seal acceptance; `ProviderResult` proves the scripted dispatch
  succeeded.
- Payload-shape details are direct `compaction_ai` / chain scenarios; the ledger does not contain
  full provider payloads.

## Required plan shape

Use work items with purpose, exact files, implementation notes, verification commands, teeth checks,
and rollback notes. At minimum include:

1. **WI-0: baseline/reverification**
   - toolchain, HEAD, existing `make compaction_dst`
   - existing compaction scripts still green
   - anchors checked

2. **WI-1: catalog + live calibration profile**
   - add OpenRouter Qwen context limit to `.motoko/model-catalog.json`
   - add dedicated profile, likely `.motoko/config/qwen36-compaction-live/`
   - set agent model and `compaction_ai` model to Qwen by default
   - keep this profile out of CI

3. **WI-2: test catalog fixture**
   - add a small model-catalog fixture for `MOTOKO_MODELS_FILE`
   - pick a tractable limit and justify it relative to fixture sizes
   - verification command proving `catalog_context_limit_for` sees it

4. **WI-3: traced deterministic harness**
   - decide direct `Session.run_v2_session_traced` vs helper beside `run_v2_with_scripted_ports`
   - build marker-routed `Ported(Ports)`
   - fake summarizer branch by prompt shape
   - deterministic `on_tool_handle` extension with large tool outputs
   - pin fake clock/env behavior or normalize trace fields narrowly

5. **WI-4: long-session scenarios**
   - `compaction.long_qwen_ai_multiple_compactions`
   - `compaction.long_qwen_ai_replay_deterministic`
   - assert at least three `TraceStageApplied` records for `compaction_ai`
   - assert zero `TraceStageRejected`
   - assert `provider_call_prepared` followed by `ProviderResult`
   - assert system-prefix fields
   - assert persisted history remains uncompacted enough to show session growth

6. **WI-5: direct `compaction_ai` scenarios**
   - `compaction.compaction_ai_output_shape_valid`
   - `compaction.compaction_ai_artifact_cache_stable`
   - use `validate_compactor_output`
   - cache oracle: first run writes artifact; second same-segment run would visibly differ/fail if
     cache missed

7. **WI-6: Make/gate wiring**
   - wire into `make compaction_dst` or a clearly named successor
   - include `MOTOKO_MODELS_FILE=<fixture>` in the deterministic run command
   - do not wire live Qwen calibration into the fast gate

8. **WI-7: optional live calibration instructions**
   - command/profile to run manually
   - expected evidence fields: date, profile, model string, log path
   - warning that provider/network/model behavior is not the oracle

## Acceptance criteria to preserve

The plan is not done unless it gives another agent enough detail to satisfy ADR-004:

- Live profile selects `openrouter/qwen/qwen3.6-35b-a3b`.
- Production catalog maps that model to `262144`.
- Deterministic scenario runs offline with test `MOTOKO_MODELS_FILE`.
- At least three in-memory `compaction_ai` `TraceStageApplied` records.
- Zero in-memory `TraceStageRejected` records.
- `provider_call_prepared` and `ProviderResult` relationship asserted.
- Replay determinism asserted over normalized trace projection.
- Direct `compaction_ai` output-shape and cache-reuse scenarios asserted.
- Fast gate wiring included.

## Traps called out by review

- Do not count wire `compaction_extension`; it has no `ext_id`.
- Do not assert absence of wire `ext_compaction_rejected` from `LedgerTrace`; use
  `TraceStageRejected`.
- Do not call `provider_call_prepared` "successful dispatch"; it is seal acceptance.
- Do not rely on full provider payloads in the ledger.
- Do not use `scripted_ports_from_steps` as-is for this long compaction replay.
- Do not expect cross-turn cache hits in the long-session scenario; cache reuse is a direct
  same-segment replay scenario because the cache is single-slot by digest.
- Tune around `old_turns == 0` pass-through and `pct >= 90` keep-recent halving in
  `compaction_ai`.

## Output contract

Create `PLAN-long-qwen-compaction-session-dst.md`.

Do not edit source code, configs, catalog, or scripts while writing the plan. If you discover ADR
drift or an impossible acceptance criterion, stop and append a short `Plan-authoring findings`
section to the plan with the blocking evidence and recommended ADR amendment.
