# ADR-004: Long Qwen compaction-session DST

Date: 2026-07-08
Status: Proposed
As-built: the implemented DST framework is documented in `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`
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
3. Add deterministic scenarios that drive production loop/extension transition code with scripted
   model/tool/summarizer ports, then assert over `LedgerTrace` and direct extension outputs.
4. Treat "several compactions triggered by `compaction_ai`" as a structural ledger invariant:
   repeated in-memory `CompactionStageRecord` entries with `ext_id == "compaction_ai"` and
   `TraceStageApplied`, followed by valid `provider_call_prepared` sends and no transcript-gate
   failures.
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

1. **The phase-core ledger already records the needed send boundary.** `ProviderCallInfo` carries
   `step`, `msg_count`, `system_prefix_count`, `system_prefix_chars`, `payload_digest`, and `model`
   (`src/core/phase_vocab.ail:414`); `ProviderCallPrepared(ProviderCallInfo)` is the event
   constructor (`:514`) and projects to schema-v1 `provider_call_prepared`
   (`src/core/phase_vocab.ail:587`). This is the oracle for "the send gate accepted this compacted
   payload and prepared a provider call."

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

5. **Scripted model ports exist, but the long-session scenario needs a custom routed provider.**
   `scripted_ports_from_steps` produces a port-backed deterministic model from a step script
   (`src/core/test/stub_step.ail:157-168`), and `run_v2_session_traced` returns the in-memory
   trace (`src/core/session.ail:1727-1743`). Existing helpers such as
   `run_v2_with_scripted_ports` return only the final result (`src/core/test/scripted_ports.ail:83-100`);
   the new scenario should call the traced session path directly or add a traced helper. However,
   plain scripted ports are not enough for two reasons. First, extension `ai_step` is built from the
   same `Ports.model_step` (`src/core/session.ail:445-462`) that drives the main agent provider. If
   the test reuses `scripted_ports_from_steps` directly, `compaction_ai` summarizer calls can consume
   the main agent script. Second, the existing scripted-port index is derived from the message payload
   shape; compaction deliberately changes that payload, so assistant-count indexing is not a stable
   clock for a long compaction replay. This ADR chooses a custom `Ported(Ports)` provider with
   stateless marker routing: summarization prompts (one user message from `compaction_ai`, no system
   prefix) return a stable fake summary, while normal agent calls derive the next scripted step from
   visible markers in retained recent messages.

6. **The wire ledger does not contain full provider payloads.** `provider_call_prepared` carries
   counts and a `payload_digest`, not the payload body. Full-loop invariants can prove that the
   send gate accepted a payload and that compaction stages applied/rejected in order; they cannot
   re-inspect every sent message or tool id from the ledger alone. Payload-shape claims therefore
   need either (a) direct assertions over `compaction_ai` / compactor-chain outputs before sealing,
   or (b) a deliberate new bounded trace projection. This ADR chooses direct extension/chain
   assertions for now; it does not add a new payload recorder.

7. **OpenRouter Qwen3.6 uses a runtime model string absent from the local catalog.** The catalog has
   `ollama/qwen3.6:35b-a3b-mxfp8` -> `262144`, but does not include
   `openrouter/qwen/qwen3.6-35b-a3b` (`.motoko/model-catalog.json`). Since unknown models have no
   known context limit and compaction can be skipped rather than guessed, the live calibration profile
   needs an explicit catalog entry for the OpenRouter model string.

8. **The deterministic scenario needs a test catalog override, not the production 262K limit.** The
   live profile should bind Qwen to `262144`, but the fast DST should run with a small limit. The
   supported mechanism is `MOTOKO_MODELS_FILE` (`src/core/context_usage.ail:25,50`), so the plan
   should run the deterministic script with a fixture catalog mapping
   `openrouter/qwen/qwen3.6-35b-a3b` to a tractable limit. This preserves the Qwen runtime model
   label without generating a 262K-token fixture.

9. **Current `compaction_ai` profiles summarize with DeepSeek by default.** The shipped
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
  but small enough to run in a fast gate by using a test catalog override.
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
- Model label: `openrouter/qwen/qwen3.6-35b-a3b`.
- Context limit: a test-only `MOTOKO_MODELS_FILE` fixture that maps that model label to a small
  limit. The production `.motoko/model-catalog.json` remains the 262144 binding.
- Runtime: production `session` loop via `run_v2_session_traced` or a small traced helper.
- Provider: custom routed `Ported(Ports)` provider. Normal agent calls must derive the next step
  from visible markers in retained recent messages; they must not rely on raw assistant-count
  indexing after compaction. Summarizer-shaped calls return stable fake summaries without advancing
  the agent script.
- Summarizer: fake summary branch selected by prompt shape: exactly one user message and no system
  prefix. Do not branch by model string, because the live calibration profile may use Qwen for both
  the agent and summarizer.
- Tools: deterministic handled tool results from a test extension `on_tool_handle`, large enough to
  create pressure while preserving assistant/tool pairing.
- Oracle: in-memory `LedgerTrace`, returned history, and direct extension/chain assertions for
  payload-shape details that the ledger intentionally does not store.

### 2. Canonical scenario ids

Land now:

- `compaction.long_qwen_ai_multiple_compactions`
- `compaction.long_qwen_ai_replay_deterministic`
- `compaction.compaction_ai_artifact_cache_stable`
- `compaction.compaction_ai_output_shape_valid`

Optional live evidence:

- `compaction.live_qwen36_multiple_compactions`

The live id is a smoke/evidence label only. It must not be wired into the fast gate.

### 3. Core invariants

The long-session DST must assert:

- At least three `compaction_ai` compactions occur.
- Each counted compaction is an in-memory `CompactionStageRecord` with `ext_id == "compaction_ai"`
  and `TraceStageApplied`.
- Every applied `compaction_ai` stage is followed by `provider_call_prepared`, proving
  `seal_compacted_payload` accepted the compacted payload.
- Every prepared call in the happy-path fixture is followed by `ProviderResult`, not
  `StreamErrorRetry` or a terminal provider error, before the next compaction stage.
- Every proceeded provider call has `system_prefix_count >= 1` and `system_prefix_chars > 0`.
- No in-memory `CompactionStageRecord` has `TraceStageRejected`; no `compaction_exhausted` or
  `SystemPromptEmpty` error occurs.
- The returned persisted history still contains the un-compacted session growth expected from the
  scripted tool loop; compaction remains provider-payload-local except for explicit artifact
  threading.
- Replaying the same long scenario twice yields the same ordered trace projection after normalizing
  volatile session/time fields.

The direct `compaction_ai` / chain scenarios must assert:

- Tool-call and tool-result IDs remain paired in compacted outputs.
- `validate_compactor_output` accepts the `compaction_ai` output for representative tool-paired
  inputs.
- Replaying with a prior `compaction_ai` artifact for the same old segment digest reuses the cached
  summary. The feasible oracle is a second run whose fake `ai_step` would return a sentinel failure
  or different summary if called; the compacted output must still contain the cached summary.

### 4. Fixture shape

The implementation plan should choose the smallest fixture that still behaves like a real long
session:

- A non-empty system prefix.
- Alternating assistant tool calls and tool results.
- Large deterministic tool outputs to push usage over the `compaction_ai.threshold_pct`.
- Test `compaction_ai` config values pinned in the fixture, including `threshold_pct` and
  `keep_recent`, so the small catalog limit reliably yields at least three applications.
- Scripted model steps that continue the loop with tool calls for enough turns to trigger repeated
  pre-step compaction.
- Step markers in retained tool-call ids or tool-result content so the marker-routed fake agent can
  continue after compaction removes older transcript turns.
- A final scripted prose step to terminate.
- `compaction_ai` registered before the structural compactor, matching shipped profiles.
- A test-only model catalog file selected by `MOTOKO_MODELS_FILE` so the Qwen model label has a
  small limit during the deterministic run.
- Explicit run caps for the deterministic script. The exact command belongs in the implementation
  plan, but it must cover the session loop's effect row plus `Env`/`FS` for
  `catalog_context_limit_for` and `MOTOKO_MODELS_FILE`.

Use a small test context limit for the deterministic scenario. The Qwen 262144 binding is guarded in
the production catalog/profile path; the long-session fixture should not generate hundreds of
thousands of tokens just to cross a percentage threshold.

### 5. Reporting contract

The scenario should reuse the `phase_c_l1` reporting shape:

- print `scenario=<id>`
- print `invariant=<first failed invariant>`
- print a bounded normalized trace on failure
- return non-zero on failure

If the trace is too large, the failure output should include counts, ordered event names, payload
digests, compaction notes, and direct-scenario summary/cache observations rather than full message
contents.

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
3. The deterministic long-session scenario runs with a test `MOTOKO_MODELS_FILE` override, without
   network and without real provider calls.
4. The deterministic long-session scenario observes at least three in-memory `compaction_ai`
   `TraceStageApplied` records and zero `TraceStageRejected` records.
5. The deterministic long-session scenario proves replay determinism over a normalized trace
   projection.
6. Direct `compaction_ai` scenarios prove output-shape validity and artifact-cache reuse for
   repeated segment digests.
7. `make compaction_dst` or a successor target wires the new standing scenarios into the fast gate,
   including the test catalog override.
8. Any live Qwen run is documented as calibration evidence only, with date, profile, model string,
   and log path.

## Consequences

Positive: this closes the gap between small compaction unit/scenario coverage and a realistic
multi-step agent session. It exercises the exact extension mechanism intended to prevent long-session
context failure while remaining deterministic enough for CI.

Negative / accepted: building a realistic long fixture will require some local harness work around
trace normalization and fake summarizer observability. The live Qwen run may still fail for provider
availability or routing reasons; that is acceptable because it is not the oracle.

## Review disposition

The iterative review resolved four plan-blocking issues:

- The oracle counts in-memory `CompactionStageRecord` / `TraceStageApplied` entries, not wire
  `compaction_extension` events, because the wire event lacks `ext_id`.
- Provider-payload shape is checked through direct extension/chain scenarios, not by pretending the
  ledger contains full payloads.
- The deterministic Qwen-labeled run uses `MOTOKO_MODELS_FILE` for a small test limit; the production
  catalog still guards the real 262144 limit.
- The fake provider must route summarizer prompts separately and must not use assistant-count
  indexing as its only script clock after compaction changes the payload.
- The two independent ADR reviews are folded into the normative sections: the provider is now
  marker-routed `Ported(Ports)` only; negative compaction rejection checks use
  `TraceStageRejected`; `provider_call_prepared` is treated as seal acceptance, with
  `ProviderResult` proving dispatch success; and the fixture must pin caps plus
  `compaction_ai` threshold/keep settings.

## Plan handoff notes

The follow-up plan should:

1. Re-verify source anchors before editing.
2. Decide whether to add a traced helper beside `run_v2_with_scripted_ports` or call
   `Session.run_v2_session_traced` directly from the scenario.
3. Add the OpenRouter Qwen catalog entry and dedicated profile.
4. Build the marker-routed model port and fake summarizer branch. Do not use assistant-count
   indexing or mutable call counters as the script clock after compaction; use retained step
   markers. The cache oracle should be feasible: first run produces a cached summary; second run
   would visibly differ or fail if the cache were not used.
5. Implement the four standing scenario ids above.
6. Wire the deterministic scenario into the compaction DST Make target.
7. Add a short handoff for the optional live calibration run.

---

## Review Comments

Reviewer model: Claude Opus 4.8. Date: 2026-07-08. Independent session, no context from the
authoring session. Method: citation audit, feasibility attack, oracle-consistency pass, scope and
diagram attack, all grounded against HEAD `3cbe898`.

### R1. The diagram and Decision-detail §1 attribute a "state-threaded script" to a `Ported(Ports)` provider, which the seam cannot thread

**Defect.** The diagram `routed` node reads "custom routed Ported(Ports) / normal agent calls:
state-threaded script", and Decision detail §1 says agent calls "must advance from a state-threaded
script or from visible step markers". But `Ported(Ports)` carries no state across steps:
`dispatch_step` returns `next_provider: Ported(ports)` unchanged, whereas only `Scripted` threads by
returning its tail — and `Scripted` is built from `scripted_ports_from_steps`, whose index is exactly
the assistant-count clock this ADR rejects, and which also routes the summarizer through the same
script. So "state-threaded script" is not a drop-in option for the `Ported(Ports)` design the diagram
names; it silently requires a different provider.

**Grounding.**
- `src/core/test/stub_step.ail:186-206` — `Ported(ports) => { ... next_provider: Ported(ports) }`
  (no threading) vs `Scripted(script) => ... next_provider: Scripted(rest)` (threads via tail).
- `src/core/test/stub_step.ail:157-168` — `scripted_ports_from_steps` indexes by
  `assistant_count(msgs) - base_assistant_count`; this is the clock the ADR says is unstable after
  compaction changes payload shape.
- `src/core/session.ail:453-469` — for `Ported(p)`, both the agent call (`dispatch_step`) and the
  extension summarizer (`ext_ports_of` → `ext_ai_step` → `p.model_step`) run through the same
  `Ports.model_step`, so a stateless routed provider must disambiguate by prompt shape, which it can.
- Note: Investigation finding 5 already gets this right ("either a *new* traced/state-threaded
  scripted provider *or* a custom `Ported(Ports)` provider … routes normal agent calls from visible
  step markers"). The diagram and §1/Fixture/Plan-handoff #4 lost that pairing and present the two
  mechanisms as interchangeable for one provider.

**Action.** Make §1, §4 Fixture, Plan-handoff note #4, and the diagram `routed` node consistent with
finding 5. For the existing `Ported(Ports)` seam, specify **stateless marker-based routing only**
(next step derived from a marker in the last retained tool-result/tool-call id, which always survives
recent-context retention). If "state-threaded" is kept as an option, label it explicitly as a **new
`StepProvider` variant** — not `Ported(Ports)` — that also routes the summarizer separately, or drop
it. Threading state through `SharedMem` inside a `Ported` closure is possible but reintroduces mutable
call-counter nondeterminism and should be ruled out in the plan, not left implicit.

### R2. Minor citation imprecision: `ProviderCallPrepared` fields cited at the record-type line

**Defect.** Investigation finding 1 says "`ProviderCallPrepared` carries `step`, `msg_count`, … 
(`src/core/phase_vocab.ail:414`)", but line 414 defines the payload record `ProviderCallInfo`. The
`ProviderCallPrepared(ProviderCallInfo)` constructor is at `:514`; the schema-v1 projection is at
`:587`. The field list is correct; only the name/line pairing is loose.

**Grounding.** `src/core/phase_vocab.ail:414` (`export type ProviderCallInfo = { … }`), `:514`
(`ProviderCallPrepared(ProviderCallInfo)`), `:587` (projection).

**Action.** Cite `:414` for the `ProviderCallInfo` fields and `:514` for the constructor, or reword.
Non-blocking.

### Residual risks / test gaps (not plan-blocking, but assert or note them)

- **≥3 compaction_ai applications needs deliberate re-inflation.** After each application the payload
  collapses to `prefix ++ [summary] ++ recent` (`compaction_ai.ail:175`); to cross `threshold_pct`
  again the fixture must re-grow. `compact_with_ai` returns `PassThrough` when `old_turns == 0`
  (`:168`), and `split_body` locks unresolved tool-call/result pairs into `recent` (`:106`). The plan
  should assert the count of three and be ready to add turns / enlarge tool outputs, especially since
  `keep_recent` halves at `pct >= 90` (`:163`), shifting the split boundary.
- **The artifact cache is single-slot.** `cache_artifact` writes one `compaction_ai` key holding one
  `segment_digest` + `summary` (`compaction_ai.ail:150-156`); within a growing session each
  compaction's `old_turns` differ, so no cross-turn cache hit occurs. The cache oracle is only
  meaningful as a **direct, same-segment replay** — which §3 correctly scopes. Do not add a cross-turn
  cache assertion to the long-session scenario.
- **Fake ports must pin time.** The custom `Ported(Ports)` must supply a fixed `clock_now`/`env_get`,
  or replay determinism depends entirely on the trace normalizer stripping every time field. §3's
  "normalize volatile session/time fields" covers this only if the normalizer is exhaustive.
- **Negative-event invariant.** "No `ext_compaction_rejected`" assumes a rejected stage surfaces as
  that wire event; confirm the emission path for `StageRejected` before relying on its absence as an
  oracle signal (the in-memory `TraceStageRejected` is the more direct observable).

### What is accurate

The core observability design holds. `ProviderCallPrepared` is threaded into the in-memory
`LedgerTrace` as a `WireRecord` (`session.ail:1517,1522,1538`), so `system_prefix_count`,
`system_prefix_chars`, and `payload_digest` are readable from the in-memory trace, not just the wire
— the oracle is observable. `CompactionStageRecord` carries `ext_id` + `TraceStageApplied`
(`phase_vocab.ail:464-467`) while the wire `compaction_extension` event lacks `ext_id`
(`phase_vocab.ail:598`), so the decision to count in-memory records (Review disposition, §3) is
correct. The `MOTOKO_MODELS_FILE` override genuinely reaches the session path:
`CallModel` calls `catalog_context_limit_for(model)` (`session.ail:1452`), which reads
`catalog_path()` honoring the env var (`context_usage.ail:24-32,50`), and the `openrouter/` stripping
(`:39-45`) makes either label form resolve. Catalog claims check out: `.motoko/model-catalog.json`
maps `ollama/qwen3.6:35b-a3b-mxfp8 → 262144` with no OpenRouter Qwen3.6 entry. The `compaction_ai`
anchors are correct (`summarize_with_ai:62-67`, `cached_summary:136-147`, `cache_artifact:150-156`,
`compact_with_ai:159-177`), and the cache path is gated so `summarize_with_ai` runs only on a miss
(`:171-173`) — the counter-free sentinel-summary oracle is sound. The production tool path is real:
`on_tool_handle` → `dispatch_tool_handle` → `dispatch_tool_entries` (`tool_phase.ail:242,244,288`;
`runtime.ail:245-261`) returns `Handled(ToolResultEnvelope)` with arbitrary deterministic content, so
large deterministic tool results on the production path are feasible. Registry order
`compaction_ai → structural` is confirmed in shipped config (`.motoko/config/default/config.json`
`order` array), so `compaction_ai` sees full pressure first; the DeepSeek default summarizer is
confirmed (`compaction_ai.json` `model = openrouter/deepseek/deepseek-v4-flash`). `validate_compactor_output`
is exported and pure (`invariants.ail:133`), usable directly. Live Qwen stays evidence-only: the
diagram's dashed "calibrates fixture realism only" edge and gate wiring keep it out of the fast gate.

### Recommended pre-implementation actions (dependency-ordered)

1. Resolve R1: commit the standing DST to stateless marker routing on `Ported(Ports)`, and rewrite
   §1, §4, Plan-handoff #4, and the diagram `routed` node to match finding 5. (Blocks provider work.)
2. Choose the traced entry point: call `run_v2_session_traced` directly (`session.ail:1727`) or add a
   thin traced helper beside `run_v2_with_scripted_ports`.
3. Add the OpenRouter Qwen catalog entry + `qwen36-compaction-live` profile, plus the test
   `MOTOKO_MODELS_FILE` fixture binding the same label to a small limit.
4. Build the routed provider (prompt-shape summarizer branch = single user message) and the test
   `on_tool_handle` extension emitting large deterministic results; register `compaction_ai` before
   `compaction_structural`.
5. Tune the fixture to guarantee ≥3 `compaction_ai` `TraceStageApplied` records; assert the count and
   pin/normalize volatile clock/session/time fields for replay determinism.
6. Implement the four standing scenario ids and wire them into the fast gate; fold R2 into a citation
   cleanup while editing.

## Review Comments — Second independent audit

Reviewer model: openrouter/z-ai/glm-5.2. Date: 2026-07-08. Independent session; no context from the
authoring session or from the first `## Review Comments` section below. Method: citation audit,
feasibility attack, oracle-consistency pass, and scope/diagram attack, all grounded against HEAD
`3cbe898` (branch `arniwesth/mot-31-checkpoint-trigger`). The first review (R1–R2 + residuals) was
audited as part of this pass and is confirmed against source unless stated.

### Prior-review verification

- Prior R1 (state-threaded script vs `Ported(Ports)`) holds. `dispatch_step` returns
  `next_provider: Ported(ports)` unchanged (`src/core/test/stub_step.ail:188-190`); only `Scripted`
  threads via its tail (`:194-204`), and `Scripted` is built from `scripted_ports_from_steps`, whose
  index is `assistant_count(msgs) - base_assistant_count` (`:157-168`) — the clock the ADR rejects —
  and which routes the summarizer through the same `Ports.model_step` (`session.ail:453-471`). The
  inconsistent sites are the diagram `routed` node, Decision-detail §1, §4 Fixture, and Plan-handoff #4.
- Prior R2 (citation at `phase_vocab.ail:414`) holds: `:414` is `ProviderCallInfo`; the
  `ProviderCallPrepared(ProviderCallInfo)` constructor is `:514`; the schema-v1 projection is `:587`.
  The field list is correct.

### R1. "No `ext_compaction_rejected`" is not observable from the in-memory `LedgerTrace` oracle and would silently pass

**Defect.** §3 lists "No `ext_compaction_rejected`, `compaction_exhausted`, or `SystemPromptEmpty`
error occurs" as a core invariant over the in-memory `LedgerTrace` oracle, but `ext_compaction_rejected`
is a *wire* event that is never appended to the in-memory trace, so an assertion over its absence is
trivially true and gives no signal.

**Grounding.**
- `emit_pre_step_stages` emits `ExtCompactionRejected({step, note})` only via `ledger_emit` (the wire
  journal): `src/core/session.ail:298-301`. It is never wrapped in `WireRecord(...)`.
- The in-memory stage path instead appends `CompactionStageRecord({step, ext_id, outcome})` with
  `TraceStageRejected(reason)` via `stage_record`/`c2_trace_stage_records`:
  `src/core/hook_phase.ail:14-20`, `src/core/session.ail:361-365`.
- `c2_trace_wire_events` appends only `phase.events` (provider-result phase), not pre-step stage wire
  events: `src/core/session.ail:368-373,1538`. So no `WireRecord(ExtCompactionRejected)` ever enters
  `TracedSessionResult.trace` (`session.ail:135-138`).
- By contrast `compaction_exhausted` and `SystemPromptEmpty` *are* in-memory `WireRecord`s on their
  paths: `session.ail:1467,1474`. Only the `ext_compaction_rejected` member of the triple is
  mis-anchored.
- The diagram `clean` node ("ext_compaction_rejected … absent") inherits the same defect and is
  internally inconsistent with the `stage` node, which correctly uses the in-memory
  `CompactionStageRecord`/`TraceStageApplied`.

**Action.** Reword the invariant to the in-memory observable: "no `CompactionStageRecord` with
`outcome == TraceStageRejected` (any `ext_id`)" — or scoped to the compactor under test, "no
`CompactionStageRecord` with `ext_id == "compaction_ai"` and `TraceStageRejected`." Update the diagram
`clean` node to match (e.g. "`TraceStageRejected` absent"). Leave `compaction_exhausted` and
`SystemPromptEmpty` as-is (they are real in-memory `WireRecord`s).

### R2. §3's "successful `provider_call_prepared`" conflates payload-acceptance with dispatch success

**Defect.** §3 requires every applied `compaction_ai` stage to be "followed by a successful
`provider_call_prepared` before the next provider result," but `provider_call_prepared` is emitted
*before* `dispatch_step` and encodes only that `seal_compacted_payload` accepted the payload — not
that the provider call succeeded.

**Grounding.** `session.ail:1482-1491` emits `ProviderCallPrepared`, then runs `dispatch_step`; on a
stream error the trace gets `WireRecord(prepared_event)` followed by `StreamErrorRetry`
(`:1498-1517`) or a terminal error (`:1521-1522`), with no `ProviderResult`. Success is observable
only via the subsequent `ProviderResult(ThinkingInfo)` (`:1538`; `phase_vocab.ail:531`).

**Action.** Split the invariant: (a) "every applied `compaction_ai` stage is followed by a
`provider_call_prepared` (seal accepted the compacted payload)"; (b) "that call is followed by a
`ProviderResult`, not a `StreamErrorRetry`/terminal error, before the next compaction stage." Since
the fixture scripts the provider to succeed, (b) is implicit, but stating it prevents a future
scripted-error case from passing the oracle. Non-blocking.

### Residual risks / test gaps

- **Replay normalization is lighter than the ADR implies.** The in-memory `LedgerTrace` records carry
  no `session_id` or wall-clock in the per-step events (`ProviderCallPrepared`, `CompactionStageRecord`,
  `ThinkingStream*`, `ProviderResult` — `phase_vocab.ail:414,467,531`), so the multi-compaction happy
  path is deterministic *without* trace normalization once the fake provider/summarizer are fixed. The
  only volatile in-memory field to confirm is `RunSummaryInfo.duration_ms` (`phase_vocab.ail:437`) on
  the terminal/error path. Pin fakes and normalize only that field if it appears, rather than assuming
  a broad volatile-field scrub. This refines the first review's "Fake ports must pin time" residual:
  the risk is real but narrower than stated.
- **Scenario caps and `compaction_ai` config are unspecified.** `catalog_context_limit_for` has effect
  row `{Env, FS}` (`context_usage.ail:50`) and `run_v2_session_traced` carries
  `{AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}` (`session.ail:1741`), so the
  scenario needs `--caps` covering Env/FS (ADR-002 was explicit; ADR-004 is not). The deterministic run
  must also pick a `compaction_ai` config (`threshold_pct`, `keep_recent`) consistent with the small
  test limit and the ≥3-compaction goal; the shipped default (`threshold_pct: 75`, `keep_recent: 10`,
  `compaction_ai.json`) plus `keep_recent` halving at `pct >= 90` (`compaction_ai.ail:163`) sets the
  minimum old-turns needed per application.
- **Summarizer routing discriminator is underspecified in the ADR body.** §1 says "selected by prompt
  shape" without naming the shape. Source fixes it: the summarizer call is exactly one `role: "user"`
  message with no tool results (`compaction_ai.ail:63`), while every agent call carries the pinned
  system prefix (≥1 message) — so "single user message, no system role" is the stable discriminator.
  The first review's Plan-handoff action already states this; the ADR body should too.
- **`ext_id` source is the registered hook id string, not a type.** `dispatch_pre_step_chain` builds
  `{ ext_id: h.id, … }` (`runtime.ail:166-177`), so the oracle's `ext_id == "compaction_ai"` filter
  depends on the registered hook id. The test must register the compaction_ai hook under that exact id
  (the shipped config order does: `config.json:37`). Worth pinning in the fixture.

### What is accurate

The observability spine holds. `TracedSessionResult = { result, trace: LedgerTrace }`
(`session.ail:135-138`) exposes both the in-memory trace and the returned history, so every positive
invariant is observable: ≥3 `CompactionStageRecord` with `ext_id == "compaction_ai"` and
`TraceStageApplied` (`phase_vocab.ail:464-467`; `hook_phase.ail:16-20`); `provider_call_prepared`
fields `system_prefix_count`/`system_prefix_chars`/`payload_digest` as in-memory `WireRecord`s
(`session.ail:1482-1490,1517,1538`); and uncompacted persisted history (`st.msgs ++ [assistant_msg]`,
`session.ail:1536`, never replaced by the compacted payload). The wire `compaction_extension` event
indeed lacks `ext_id` (`phase_vocab.ail:598`), so counting in-memory records is the correct choice
(Review disposition; diagram `stage` node). `MOTOKO_MODELS_FILE` genuinely reaches the session path:
`CallModel` calls `catalog_context_limit_for(model)` (`session.ail:1452`) → `catalog_path()` honors the
env var (`context_usage.ail:24-32`), and the `openrouter/` stripping (`:39-45`) makes either label form
resolve, so a test fixture mapping `openrouter/qwen/qwen3.6-35b-a3b` to a small limit works. Catalog
claims check out: `.motoko/model-catalog.json` has `ollama/qwen3.6:35b-a3b-mxfp8 → 262144` (`:43`) and
no OpenRouter Qwen3.6 entry. The `compaction_ai` anchors are correct (`summarize_with_ai:62-67`,
`cached_summary:136-147`, `cache_artifact:150-156`, `compact_with_ai:159-177`) and the cache is gated so
`summarize_with_ai` runs only on a miss (`:171-173`) — the counter-free sentinel-summary oracle is sound
as a direct, same-segment replay. The production tool path is real: `on_tool_handle` →
`dispatch_tool_handle` → `first_handle` returns `Handled(ToolResultEnvelope)` with arbitrary
deterministic `stdout` (`runtime.ail:245-261`; `tool_phase.ail:242-253,288`; `types.ail:48-55`), so
large deterministic tool results on the production path are feasible. Registry order
`compaction_ai → … → compaction_structural` is confirmed (`config.json:37`) and the DeepSeek default
summarizer is confirmed (`compaction_ai.json:2`). `validate_compactor_output` is exported and pure
(`invariants.ail:133`), usable directly. The ABI-no-gate conclusion (finding 4) is correct: `ExtCtx`
carries `context_limit`/`ports`/`artifacts` (`types.ail:74-95`) and `compaction_ai` gates on
`usage_percent(msgs, ctx.context_limit)` (`compaction_ai.ail:160`) — note `telemetry` is present in the
type but unused by `compaction_ai`, so it is not the enabler. Prompt-shape routing is feasible:
summarizer calls are a single user message (`compaction_ai.ail:63`); agent calls carry the system
prefix. Live Qwen stays evidence-only: the diagram's dashed "calibrates fixture realism only" edge and
the gate wiring keep it out of the fast gate, and AC8 requires date/profile/model/log path. The diagram
does not imply the ledger holds full payloads (`prepared` shows `payload_digest`, not body) and does not
imply wire events carry `ext_id` (`stage` attributes it to `CompactionStageRecord`).

### Recommended pre-implementation actions (dependency-ordered)

1. Fix R1: reword the negative invariant to `CompactionStageRecord`/`TraceStageRejected` (in-memory) in
   §3 and the diagram `clean` node; drop the `ext_compaction_rejected` wire-event name.
2. Adopt prior R1: commit the standing DST to stateless marker routing on `Ported(Ports)`; align §1,
   §4 Fixture, Plan-handoff #4, and the diagram `routed` node. Fold R2's "successful" split into §3.
3. State the scenario `--caps` (Env/FS for the catalog, plus the loop effect row) and the test
   `compaction_ai` config (threshold/keep_recent) in §4.
4. Pin fakes (provider, summarizer, clock, env) and normalize only `RunSummaryInfo.duration_ms` if it
   reaches the in-memory trace; do not assume a broad volatile-field scrub.
5. Build the routed provider (single-user-message summarizer branch) and the test `on_tool_handle`
   large-result extension; register `compaction_ai` under id `"compaction_ai"` before
   `compaction_structural`.
6. Tune the fixture to guarantee ≥3 `compaction_ai` `TraceStageApplied` records (mind the
   `old_turns == 0` short-circuit at `compaction_ai.ail:168` and `keep_recent` halving at `:163`);
   assert the count.
7. Implement the four standing scenario ids and wire them into the fast gate; fold prior R2 into a
   citation cleanup (`ProviderCallInfo` at `:414`, constructor at `:514`, projection at `:587`).
