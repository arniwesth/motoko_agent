# ADR-004: Long Qwen compaction-session DST

Date: 2026-07-08
Status: Draft
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` -> `ailang_version: "v0.26.0"`
Grounded at: branch `arniwesth/mot-31-checkpoint-trigger`, HEAD `3cbe898`

Relates to:
- `001_DST/ADR-001-deterministic-simulation-testing-architecture.md` - the DST layer model,
  scenario-id discipline, normalized traces, and "real-provider calls are supplemental smokes"
  principle.
- `001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` - the current compaction
  split: core owns the scaffold and send gate; compaction policy lives in extensions; the ledger is
  the recorder.
- `004_phase_core_refactor/ADR-001-phase-oriented-core.md` - the phase-oriented core and
  compactor-chain architecture.
- `004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` - the
  single send gate and `provider_call_prepared` observability.
- OpenRouter model page for `qwen/qwen3.6-35b-a3b` - live calibration target. As of 2026-07-08,
  OpenRouter describes it as Qwen3.6 35B A3B with a 262K context window and function-calling
  support.

---

## TL;DR

We need a long, realistic session that crosses compaction pressure repeatedly and proves that
`compaction_ai` remains deterministic, structurally valid, and replayable across several
compactions. The standing test must **not** use Qwen's prose or OpenRouter availability as its
oracle. A live Qwen3.6 run is valuable as **calibration evidence**; the DST gate is a scripted
long-session replay over the phase-core ledger.

**Decision:**

1. Scope this under `001_DST` as a new long-session scenario family, not a new project.
2. Add a live calibration profile for `openrouter/qwen/qwen3.6-35b-a3b`, including a catalog limit
   entry for that runtime model string.
3. Add a deterministic long-session scenario that drives production loop/extension transition code
   with scripted model/tool/summarizer ports, then asserts over `LedgerTrace`.
4. Treat "several compactions triggered by `compaction_ai`" as a structural ledger invariant:
   repeated `compaction_extension` records whose notes come from `compaction_ai`, followed by valid
   `provider_call_prepared` sends and no transcript-gate failures.
5. Do not make real OpenRouter/Qwen a CI oracle. Keep live-provider runs opt-in and evidence-only.

## Context

ADR-002 already landed fast compaction DST for the shipped estimate-path and core scaffold. That is
not enough to validate a realistic long agent session because those scenarios are intentionally
small: they prove tier constants, segment construction, and send-gate behavior. They do not prove
that the full loop can accumulate history, trigger AI summarization repeatedly, carry artifacts
between turns, and continue making valid provider calls after several compactions.

The new requirement is narrower than a benchmark suite and broader than a unit test:

- **Narrower than benchmarking:** no scoreboards, dashboards, live-provider campaigns, or model
  quality claims.
- **Broader than existing compaction DST:** multi-step loop, tool-call/result traffic, repeated
  compaction pressure, artifact cache behavior, and provider-payload observability.

This belongs in `001_DST` because the durable artifact is a deterministic simulation scenario, not
a new evaluation program.

## Investigation findings

1. **The phase-core ledger already records the needed send boundary.** `ProviderCallPrepared`
   carries `step`, `msg_count`, `system_prefix_count`, `system_prefix_chars`, `payload_digest`, and
   `model` (`src/core/phase_vocab.ail:414`), and projects to schema-v1
   `provider_call_prepared` (`src/core/phase_vocab.ail:587`). This is the oracle for "a provider
   call would have been made with this compacted payload."

2. **The loop emits compaction stages before every model call.** The live `CallModel` arm runs
   `split_for_compaction`, builds a pre-step `ExtCtx`, dispatches the pre-step chain, emits stage
   events, then seals and dispatches the compacted payload (`src/core/session.ail:1450-1491`).
   This is the exact path the long-session DST should drive; a separate recorder would be redundant.

3. **`compaction_ai` is already ports-native and artifact-cached.** It calls `ctx.ports.ai_step`
   for summarization (`packages/motoko-ext-compaction-ai/compaction_ai.ail:62-67`), checks
   `ctx.artifacts` for a cached digest (`:136-147`), writes a `compaction_ai` artifact (`:150-156`),
   and returns `Compacted(..., "AI-summarized ...", artifact)` when pressure crosses its threshold
   (`:159-177`). This means the deterministic test can use a fake summarizer port today.

4. **ABI support for this scenario exists at HEAD.** `ExtCtx` already carries `context_limit`,
   `ports`, `artifacts`, and `telemetry` (`packages/motoko-ext-abi/types.ail:74-95`), and
   `ExtPorts.ai_step` is part of the ABI (`:62-67`). This ADR must not incorrectly gate the basic
   `compaction_ai` long-session scenario on a future ABI v3. Future ABI work may improve
   conformance coverage, but it is not a blocker for the replay scenario.

5. **Scripted model ports already exist, but the long-session scenario needs the traced entrypoint.**
   `scripted_ports_from_steps` produces a port-backed deterministic model from a step script
   (`src/core/test/stub_step.ail:157-168`), and `run_v2_session_traced` returns the in-memory
   trace (`src/core/session.ail:1727-1743`). Existing helpers such as
   `run_v2_with_scripted_ports` return only the final result (`src/core/test/scripted_ports.ail:83-100`);
   the new scenario should call the traced session path directly or add a traced helper.

6. **OpenRouter Qwen3.6 uses a runtime model string absent from the local catalog.** The catalog has
   `ollama/qwen3.6:35b-a3b-mxfp8` -> `262144`, but does not include
   `openrouter/qwen/qwen3.6-35b-a3b` (`.motoko/model-catalog.json`). Since unknown models have no
   known context limit and compaction can be skipped rather than guessed, the live calibration profile
   needs an explicit catalog entry for the OpenRouter model string.

7. **Current `compaction_ai` profiles summarize with DeepSeek by default.** The shipped
   `compaction_ai.json` files use `openrouter/deepseek/deepseek-v4-flash`. A Qwen live calibration
   needs to state whether Qwen is only the main agent model or also the summarizer model. This ADR
   chooses a dedicated calibration profile where both are Qwen unless the operator intentionally
   overrides the summarizer.

## Decision drivers

- The standing test must be deterministic, offline, and replayable.
- The scenario must drive production transition code, especially `dispatch_pre_step_chain`,
  `seal_compacted_payload`, artifact threading, and the typed ledger.
- The oracle should assert structural invariants, not final model prose.
- The fixture must be long and realistic enough to trigger multiple `compaction_ai` applications,
  but small enough to run in a fast gate by using a small injected context limit.
- Live Qwen/OpenRouter should validate that the configured model string and profile behave in the
  real harness, but should not block CI.

## Decision detail

### 1. Scenario split: calibration vs standing DST

**Live calibration, opt-in:**

- Profile: `qwen36-compaction-live` (name final in the implementation plan).
- Agent model: `openrouter/qwen/qwen3.6-35b-a3b`.
- `compaction_ai` summarizer model: same Qwen model by default.
- Catalog: add `openrouter/qwen/qwen3.6-35b-a3b: 262144`.
- Goal: run a long realistic task and archive the JSONL/markdown session as evidence that the live
  profile reaches multiple `compaction_ai` compactions.
- Not CI, not the oracle.

**Standing DST, required gate:**

- Script: new AILANG scenario, tentatively `scripts/long_qwen_compaction_dst.ail`.
- Model label: `openrouter/qwen/qwen3.6-35b-a3b`, but with an injected small context limit or test
  catalog override so fixtures stay tractable.
- Runtime: production `session` loop via `run_v2_session_traced` or a small traced helper.
- Provider: scripted model steps.
- Summarizer: fake `ExtPorts.ai_step` returning stable summaries.
- Tools: deterministic tool results, ideally large enough to create realistic pressure and preserve
  assistant/tool pairing.
- Oracle: in-memory `LedgerTrace` plus returned history.

### 2. Canonical scenario ids

Land now:

- `compaction.long_qwen_ai_multiple_compactions`
- `compaction.long_qwen_ai_replay_deterministic`
- `compaction.long_qwen_ai_artifact_cache_stable`
- `compaction.long_qwen_ai_payloads_remain_valid`

Optional live evidence:

- `compaction.live_qwen36_multiple_compactions`

The live id is a smoke/evidence label only. It must not be wired into the fast gate.

### 3. Core invariants

The long-session DST must assert:

- At least N `compaction_ai` compactions occur; N should be 3 in the plan unless fixture size forces
  a lower number.
- Every compaction is followed by a successful `provider_call_prepared` before the next provider
  result or terminal event.
- Every proceeded provider call has `system_prefix_count >= 1` and `system_prefix_chars > 0`.
- No `ext_compaction_rejected`, `compaction_exhausted`, or `SystemPromptEmpty` error occurs.
- Tool-call and tool-result IDs remain paired after every compaction.
- The persisted history is not replaced by compacted provider payloads; compaction remains
  provider-payload-local except for explicit artifact threading.
- Replaying the same scenario twice yields the same ordered trace projection after normalizing
  volatile session/time fields.
- Replaying with the same old segment digest uses the cached `compaction_ai` summary and does not
  call the fake summarizer again for that digest.

### 4. Fixture shape

The implementation plan should choose the smallest fixture that still behaves like a real long
session:

- A non-empty system prefix.
- Alternating assistant tool calls and tool results.
- Large deterministic tool outputs to push usage over the `compaction_ai.threshold_pct`.
- Scripted model steps that continue the loop with tool calls for enough turns to trigger repeated
  pre-step compaction.
- A final scripted prose step to terminate.
- `compaction_ai` registered before the structural compactor, matching shipped profiles.

Use a small test context limit for the deterministic scenario. The Qwen 262144 binding is guarded in
the catalog/profile path; the long-session fixture should not generate hundreds of thousands of
tokens just to cross a percentage threshold.

### 5. Reporting contract

The scenario should reuse the `phase_c_l1` reporting shape:

- print `scenario=<id>`
- print `invariant=<first failed invariant>`
- print a bounded normalized trace on failure
- return non-zero on failure

If the trace is too large, the failure output should include counts, ordered event names, payload
digests, compaction notes, and summary-call records rather than full message contents.

## Out of scope

- Benchmarking Qwen quality or comparing models.
- Making OpenRouter/Qwen part of the PR gate.
- Testing provider-specific multimodal behavior.
- Replacing ADR-002's small compaction-policy DST.
- Rewriting `compaction_ai` policy unless the implementation plan finds a defect while building the
  scenario.
- Building dashboards, score aggregation, or long-running live campaigns.

## Acceptance criteria

1. A dedicated live calibration profile exists and selects `openrouter/qwen/qwen3.6-35b-a3b`.
2. The catalog has a context limit for `openrouter/qwen/qwen3.6-35b-a3b` equal to `262144`.
3. The deterministic long-session scenario runs without network and without real provider calls.
4. The deterministic scenario observes at least three `compaction_ai` compactions.
5. The deterministic scenario proves replay determinism over a normalized trace projection.
6. The deterministic scenario proves artifact-cache stability for repeated segment digests.
7. `make compaction_dst` or a successor target wires the new standing scenario into the fast gate.
8. Any live Qwen run is documented as calibration evidence only, with date, profile, model string,
   and log path.

## Consequences

Positive: this closes the gap between small compaction unit/scenario coverage and a realistic
multi-step agent session. It exercises the exact extension mechanism intended to prevent long-session
context failure while remaining deterministic enough for CI.

Negative / accepted: building a realistic long fixture will require some local harness work around
trace normalization and fake summarizer observability. The live Qwen run may still fail for provider
availability or routing reasons; that is acceptable because it is not the oracle.

## Plan handoff notes

The follow-up plan should:

1. Re-verify source anchors before editing.
2. Decide whether to add a traced helper beside `run_v2_with_scripted_ports` or call
   `Session.run_v2_session_traced` directly from the scenario.
3. Add the OpenRouter Qwen catalog entry and dedicated profile.
4. Build the fake summarizer port with a call log or equivalent observable.
5. Implement the four standing scenario ids above.
6. Wire the deterministic scenario into the compaction DST Make target.
7. Add a short handoff for the optional live calibration run.
