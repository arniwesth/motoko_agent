# Handoff: implement the long Qwen compaction-session DST

Date: 2026-07-08 (written by the ADR-004 plan-authoring/review session)
Audience: a fresh agent session that will **implement** `PLAN-long-qwen-compaction-session-dst.md`.

## Mission

Implement `PLAN-long-qwen-compaction-session-dst.md` in this directory. The work lands ADR-004:
a deterministic, offline, Qwen-labeled long-session DST that triggers several `compaction_ai`
applications, plus direct `compaction_ai` scenarios for output-shape validity and artifact-cache
reuse. It also adds a live OpenRouter/Qwen profile, but that profile is calibration evidence only and
must not become the CI oracle.

The plan is the normative spec. It has already been reviewed iteratively, and the current plan fixes
the ADR review traps around `Ported(Ports)`, prompt-shape routing, in-memory stage records, provider
dispatch success, `MOTOKO_MODELS_FILE`, and paired tool-result retention. Follow it WI by WI
(`WI-0` through `WI-7`).

## Reading order

1. `PLAN-long-qwen-compaction-session-dst.md` — the spec. Read it whole before editing. Its
   "Plan-Level Decisions", work items, and final acceptance checklist are what you execute.
2. Diagrams in `mmd/`:
   - `long-qwen-compaction-session-dst-plan.mmd` / `.svg` — implementation work-item flow.
   - `long-qwen-compaction-session-dst-end-state.mmd` / `.svg` — expected runtime/dataflow end state.
   - `adr-004-long-qwen-compaction-dst.mmd` / `.svg` — ADR-level architecture.
3. `ADR-004-long-qwen-compaction-session-dst.md` — read the whole file, including both
   `## Review Comments` sections and `Review disposition`. The plan incorporates those reviews; do
   not re-open closed decisions without new source evidence.
4. `ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` and
   `PLAN-compaction-dst-scenarios.md` — local DST harness/reporting style and now-vs-gated discipline.
5. Phase-core context only:
   `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` and
   `../004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md`.

## Ground truth to re-establish before touching code

The plan was grounded at branch `arniwesth/mot-32-qwen36-larger-scale-dst`, HEAD `de3c348`.
Re-verify at implementation HEAD:

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
ailang --version                         # must be v0.26.0 / commit 3b52a24, or call out drift
make compaction_dst                       # current baseline should be green
rg -n '"openrouter/qwen/qwen3\.6-35b-a3b"|"ollama/qwen3\.6:35b-a3b-mxfp8"' .motoko/model-catalog.json
```

Expected current facts at plan time:

- `make compaction_dst` runs only `scripts/compaction_policy_dst.ail` and
  `scripts/compaction_catalog_dst.ail`.
- `.motoko/model-catalog.json` has `ollama/qwen3.6:35b-a3b-mxfp8: 262144`.
- `.motoko/model-catalog.json` lacks `openrouter/qwen/qwen3.6-35b-a3b`.
- OpenRouter's live page for `qwen/qwen3.6-35b-a3b` reports a 262K context window. Treat this as
  calibration evidence only; do not build a fast-gate dependency on browsing or OpenRouter.

## Source anchors to re-ground

Before implementing, re-check the anchors named in the plan:

- `src/core/session.ail`: `TracedSessionResult`, `ext_ai_step`, `ext_ports_of`, `mk_v2_ext_ctx`,
  `CallModel` arm, trace threading, `run_v2_session_traced`.
- `src/core/test/stub_step.ail`: `StepProvider`, `dispatch_step`, `Ported(Ports)` no-state behavior,
  and why `scripted_ports_from_steps` assistant-count indexing is invalid after compaction.
- `src/core/test/scripted_ports.ail`: `run_v2_with_scripted_ports` returns only the final result.
- `src/core/phase_vocab.ail`: `LedgerTrace`, `CompactionStageRecord`, `TraceStageApplied`,
  `TraceStageRejected`, `ProviderCallInfo`, `ProviderCallPrepared`, `ProviderResult`.
- `src/core/ext/runtime.ail` and `src/core/tool_phase.ail`: pre-step chain, stage records, artifacts,
  and production `on_tool_handle`.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail`: summarizer prompt shape, threshold/keep
  behavior, `old_turns == 0`, `pct >= 90`, digest artifact cache, summary message.
- `packages/motoko_ext_conformance/invariants.ail`: `validate_compactor_output`.
- `src/core/context_usage.ail`: `MOTOKO_MODELS_FILE` and `catalog_context_limit_for`.
- `.motoko/config/default/config.json` and `.motoko/config/*/compaction_ai.json`: extension order and
  current default summarizer model.

## Hard constraints

Do not violate these:

- Standing DST is deterministic/offline. No real OpenRouter/Qwen call in `make compaction_dst`.
- Runtime model label for deterministic and live profile work is
  `openrouter/qwen/qwen3.6-35b-a3b`.
- Production catalog gets `openrouter/qwen/qwen3.6-35b-a3b: 262144`.
- Deterministic runs use `MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json`.
- Use custom marker-routed `Ported(Ports)`. Do not use assistant-count indexing, mutable call
  counters, or `scripted_ports_from_steps` as the script clock.
- Summarizer calls are routed by prompt shape: exactly one user message, no system role, no tool
  messages. Do not route by model string; live profile uses Qwen for both agent and summarizer.
- Count compactions from in-memory `CompactionStageRecord` with `ext_id == "compaction_ai"` and
  `TraceStageApplied`.
- Negative rejection is in-memory `TraceStageRejected` absence, not wire `ext_compaction_rejected`
  absence.
- `ProviderCallPrepared` means seal acceptance. Require subsequent `ProviderResult` for scripted
  dispatch success.
- Full provider payloads are not in the ledger. Payload-shape claims belong in direct
  `compaction_ai` scenarios.

## Hazards that will waste time if missed

1. **`Ported(Ports)` does not thread state.** `dispatch_step` returns the same `Ported(ports)`.
   The long-session provider must derive the next scripted step from retained markers in the payload,
   not from hidden mutable counters or assistant counts.
2. **Agent and summarizer share `Ports.model_step`.** A naïve scripted provider will let
   `compaction_ai` summarization consume agent steps. The discriminator is prompt shape, not model.
3. **`compaction_ai.split_body` preserves completed tool pairs in recent context.** This is good for
   provider validity, but it means large paired tool results may stay in the provider payload after
   `compaction_ai` applies. Keep `compaction_structural` after `compaction_ai` as the backstop unless
   tuning proves it unnecessary.
4. **Three `compaction_ai` applications require re-growth.** After an application, the payload becomes
   `prefix ++ [summary] ++ recent`. Use enough large deterministic tool-result turns to cross pressure
   repeatedly. Tune tool-result size / small catalog limit / `keep_recent` together.
5. **The artifact cache is single-slot by digest.** Do not assert cross-turn cache hits in the
   long-session scenario. Cache reuse is a direct same-segment replay scenario.
6. **`MOTOKO_MODELS_FILE` is read via `std/env`, not `Ports.env_get`.** Set it on the shell command.
7. **The direct output-shape scenario must use `validate_compactor_output`.** Do not duplicate the
   conformance law.
8. **Keep live calibration out of Make.** A profile, catalog entry, and optional handoff are fine;
   no `OPENROUTER_API_KEY` or live profile invocation in the fast gate.

## Execution order

Follow the plan's WI order:

1. **WI-0 baseline/reverification.** Re-run toolchain, HEAD, catalog, `make compaction_dst`, and anchor
   checks. Stop on baseline red.
2. **WI-1 catalog + live calibration profile.** Add the production catalog entry and
   `.motoko/config/qwen36-compaction-live/` with both agent and `compaction_ai` model set to Qwen.
3. **WI-2 test catalog fixture.** Add `scripts/fixtures/qwen36-small-model-catalog.json` and
   `scripts/long_qwen_catalog_fixture_probe.ail`.
4. **WI-3 traced deterministic harness.** Add `scripts/long_qwen_compaction_dst.ail`; call
   `Session.run_v2_session_traced` directly; build local runtime, marker-routed ports, fake
   summarizer branch, and deterministic `LongResult` tool handler.
5. **WI-4 long-session scenarios.** Implement:
   - `compaction.long_qwen_ai_multiple_compactions`
   - `compaction.long_qwen_ai_replay_deterministic`
6. **WI-5 direct `compaction_ai` scenarios.** Implement:
   - `compaction.compaction_ai_output_shape_valid`
   - `compaction.compaction_ai_artifact_cache_stable`
7. **WI-6 Make wiring.** Add the deterministic command to `make compaction_dst` with the fixture
   `MOTOKO_MODELS_FILE`.
8. **WI-7 optional live calibration instructions.** Add the evidence-only handoff/note if still in
   scope.

Each WI should leave the tree with the relevant check green before moving on.

## Verification commands

Core commands from the plan:

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS --entry main scripts/long_qwen_catalog_fixture_probe.ail

MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang check scripts/long_qwen_compaction_dst.ail

MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
  scripts/long_qwen_compaction_dst.ail

make compaction_dst
```

Expected scenario output includes:

```text
scenario=compaction.long_qwen_ai_multiple_compactions ok
scenario=compaction.long_qwen_ai_replay_deterministic ok
scenario=compaction.compaction_ai_output_shape_valid ok
scenario=compaction.compaction_ai_artifact_cache_stable ok
```

## Definition of done

Done means all of the following are true:

- Live profile selects `openrouter/qwen/qwen3.6-35b-a3b`.
- Production catalog maps `openrouter/qwen/qwen3.6-35b-a3b` to `262144`.
- Deterministic scenario runs offline with the test `MOTOKO_MODELS_FILE` fixture.
- Long-session scenario observes at least three in-memory `compaction_ai` `TraceStageApplied`
  records.
- Long-session scenario observes zero in-memory `TraceStageRejected` records.
- Every counted compaction has `ProviderCallPrepared` as seal acceptance and `ProviderResult` as
  scripted dispatch success.
- Replay determinism is asserted over a bounded normalized trace projection.
- Direct output-shape and artifact-cache scenarios are green.
- `make compaction_dst` includes the new standing scenarios and stays green.
- Live Qwen calibration remains optional/manual and is documented as evidence only.

## If the plan is wrong

Line numbers may drift. Re-grounding is normal. If a source contract contradicts the plan, stop and
record a short finding before inventing policy. Examples worth stopping for: `Ported(Ports)` starts
threading state, `compaction_ai` prompt shape changes, `LedgerTrace` stops carrying the required
records, or `MOTOKO_MODELS_FILE` no longer reaches `catalog_context_limit_for`.

Report back with the exact failing evidence and the smallest recommended amendment.

## Report back

Include:

- `make compaction_dst` output summary.
- The long-session scenario counts: applied `compaction_ai` stages, rejected stages, prepared calls,
  provider results.
- Replay determinism result and normalized projection shape.
- Direct output-shape/cache scenario results.
- Confirmation that no live Qwen/OpenRouter call is in the fast gate.
