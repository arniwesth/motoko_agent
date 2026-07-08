# Plan: ADR-004 long Qwen compaction-session DST

Date: 2026-07-08
Implements: `001_DST/ADR-004-long-qwen-compaction-session-dst.md`
Branch: `arniwesth/mot-32-qwen36-larger-scale-dst`
Grounding HEAD: `de3c348`
Toolchain: AILANG **v0.26.0** (`3b52a24`) verified with `ailang --version`.
Live calibration source: OpenRouter model page `https://openrouter.ai/qwen/qwen3.6-35b-a3b`, checked 2026-07-08; it exposes model id `qwen/qwen3.6-35b-a3b` with `262K` context. Motoko's runtime label remains `openrouter/qwen/qwen3.6-35b-a3b`.

---

## Goal

Land ADR-004 as a deterministic, offline, Qwen-labeled long-session DST plus direct `compaction_ai`
scenarios. The standing gate must never depend on live OpenRouter/Qwen behavior. The live Qwen run is
optional calibration evidence only.

Canonical standing scenario ids:

- `compaction.long_qwen_ai_multiple_compactions`
- `compaction.long_qwen_ai_replay_deterministic`
- `compaction.compaction_ai_output_shape_valid`
- `compaction.compaction_ai_artifact_cache_stable`

Optional evidence-only id:

- `compaction.live_qwen36_multiple_compactions`

## Reverified Anchors

- `make compaction_dst` currently runs only `scripts/compaction_policy_dst.ail` and
  `scripts/compaction_catalog_dst.ail`; both are green at this HEAD.
- `.motoko/model-catalog.json` still maps `ollama/qwen3.6:35b-a3b-mxfp8` to `262144` and still has no
  `openrouter/qwen/qwen3.6-35b-a3b` entry.
- `src/core/session.ail` exposes `TracedSessionResult`, routes extension `ai_step` through the same
  `Ported(Ports)` model port, builds `mk_v2_ext_ctx`, and in the `CallModel` arm runs
  `split_for_compaction -> dispatch_pre_step_chain -> emit_pre_step_stages -> seal_compacted_payload
  -> ProviderCallPrepared -> dispatch_step`. `run_v2_session_traced` returns the in-memory trace.
- `src/core/test/stub_step.ail` confirms `Ported(Ports)` does not thread state: `dispatch_step`
  returns `next_provider: Ported(ports)` unchanged. `scripted_ports_from_steps` indexes by assistant
  count, so it is not a valid script clock after compaction changes payload shape.
- `src/core/test/scripted_ports.ail` confirms `run_v2_with_scripted_ports` returns only final result,
  not `LedgerTrace`.
- `src/core/phase_vocab.ail` confirms `ProviderCallInfo` fields, `ProviderCallPrepared`, `ProviderResult`,
  `LedgerTrace`, `CompactionStageRecord`, `TraceStageApplied`, `TraceStageRejected`, and schema-v1
  `provider_call_prepared`.
- `src/core/ext/runtime.ail` records `PreStepStage` in registry order, validates compactor output, and
  threads artifacts. `on_tool_handle` dispatch is production-path via `dispatch_tool_handle`.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail` confirms one-user-message summarizer prompts,
  `threshold_pct`, `keep_recent`, `old_turns == 0` pass-through, `pct >= 90` keep-recent halving, digest,
  single-slot artifact cache, and summary message shape.
- `packages/motoko_ext_conformance/invariants.ail` exports pure `validate_compactor_output`.
- `src/core/context_usage.ail` confirms `MOTOKO_MODELS_FILE` is honored and `openrouter/` labels also
  resolve against stripped keys.
- Shipped profiles register `compaction_ai` before structural compaction where structural is present,
  and current `compaction_ai.json` defaults to `openrouter/deepseek/deepseek-v4-flash`.

## Plan-Level Decisions

- The deterministic provider is a custom stateless marker-routed `Ported(Ports)` provider. Do not use
  assistant-count indexing, mutable call counters, or `scripted_ports_from_steps` as the script clock.
- Agent calls and summarizer calls share `Ports.model_step`; route the summarizer branch by prompt
  shape: exactly one user message, no system role, no tool messages. Do not branch by model string.
- Count compactions from in-memory `CompactionStageRecord` where `ext_id == "compaction_ai"` and
  `outcome == TraceStageApplied`.
- Negative rejection is in-memory `TraceStageRejected` absence. Do not assert wire
  `ext_compaction_rejected` absence.
- `ProviderCallPrepared` proves seal acceptance only. Dispatch success requires the subsequent
  `ProviderResult` before the next compaction stage or terminal failure.
- Payload-shape details are direct `compaction_ai` / chain scenarios because the ledger carries
  counts and `payload_digest`, not full provider payload bodies.

---

## WI-0 — Baseline / Reverification

**Purpose.** Start implementation from a known green baseline and catch source drift before changing
catalog, profiles, or scripts.

**Exact files.** Read-only:

- `.agent/projects/001_DST/ADR-004-long-qwen-compaction-session-dst.md`
- `.agent/projects/001_DST/mmd/adr-004-long-qwen-compaction-dst.mmd`
- `.agent/projects/001_DST/mmd/adr-004-long-qwen-compaction-dst.svg`
- `Makefile`
- `.motoko/model-catalog.json`
- all source anchors listed in this plan's Reverified Anchors section

**Implementation notes.**

- Re-run the same checks from this plan header: branch, HEAD, `ailang --version`.
- Confirm the Mermaid and rendered SVG still show: live calibration separate from standing DST,
  marker-routed `Ported(Ports)`, `TraceStageRejected` absence, direct output-shape/cache scenarios,
  and fast-gate wiring.
- Confirm `make compaction_dst` is green before adding new scenarios.

**Verification.**

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
ailang --version
make compaction_dst
rg -n '"openrouter/qwen/qwen3\.6-35b-a3b"|"ollama/qwen3\.6:35b-a3b-mxfp8"' .motoko/model-catalog.json
```

**Teeth check.** If `make compaction_dst` is red before edits, stop and fix or document that baseline
first; do not add ADR-004 failures on top of an existing gate failure.

**Rollback.** None; read-only.

## WI-1 — Catalog + Live Calibration Profile

**Purpose.** Make the live profile selectable and make the production catalog know the OpenRouter
Qwen runtime label. This is calibration infrastructure, not CI oracle work.

**Exact files.**

- `.motoko/model-catalog.json`
- `.motoko/config/qwen36-compaction-live/config.json`
- `.motoko/config/qwen36-compaction-live/compaction_ai.json`

**Implementation notes.**

- Add `"openrouter/qwen/qwen3.6-35b-a3b": 262144` under `context_limits`. Do not replace the existing
  `ollama/qwen3.6:35b-a3b-mxfp8` entry.
- Create `qwen36-compaction-live` by copying the closest OpenRouter/default profile shape, then set:
  `agent.model = "openrouter/qwen/qwen3.6-35b-a3b"`.
- In the profile's `compaction_ai.json`, set:
  `model = "openrouter/qwen/qwen3.6-35b-a3b"`, with default threshold/keep settings unless calibration
  work later justifies a profile-local override.
- Keep extension order consistent with shipped compaction profiles: `compaction_ai` before
  `compaction_structural` if both are present.
- Do not add this profile to `make compaction_dst` or any fast gate.

**Verification.**

```bash
rg -n '"openrouter/qwen/qwen3\.6-35b-a3b": 262144' .motoko/model-catalog.json
rg -n 'openrouter/qwen/qwen3\.6-35b-a3b' .motoko/config/qwen36-compaction-live
```

**Teeth check.** Temporarily query the catalog through a probe and change the new value to a wrong
number; the probe must fail. Revert the bad value.

**Rollback.** Remove the new catalog entry and delete `.motoko/config/qwen36-compaction-live/`.

## WI-2 — Test Catalog Fixture

**Purpose.** Let the deterministic run use the Qwen label while forcing tractable compaction pressure.

**Exact files.**

- New: `scripts/fixtures/qwen36-small-model-catalog.json`
- New or extended probe: prefer adding a scenario to the ADR-004 script from WI-3 if it already has
  a harness; otherwise add `scripts/long_qwen_catalog_fixture_probe.ail`.

**Implementation notes.**

- Fixture shape:
  ```json
  {
    "context_limits": {
      "openrouter/qwen/qwen3.6-35b-a3b": 1200
    }
  }
  ```
- Start with `1200` as the small limit. It is high enough for a non-empty system prefix plus retained
  recent tool pairs, but low enough that deterministic 1-2 KB tool outputs and `threshold_pct: 60`
  can cross pressure repeatedly without huge fixtures.
- If tuning shows `pct >= 90` halves `keep_recent` too aggressively, prefer increasing the limit to
  `1600` or reducing per-turn tool output before changing the scenario's core invariants.
- Add a probe that asserts both labels resolve as expected:
  `catalog_context_limit_for("openrouter/qwen/qwen3.6-35b-a3b") == 1200` and, because
  `context_usage.ail` strips `openrouter/`, optionally
  `catalog_context_limit_for("qwen/qwen3.6-35b-a3b") == 1200` if the fixture also includes the stripped
  key. If only one key is present, assert only the runtime label to avoid obscuring the contract.

**Verification.**

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS --entry main scripts/long_qwen_catalog_fixture_probe.ail
```

**Teeth check.** Point `MOTOKO_MODELS_FILE` at a missing file or change the fixture value; the probe
must fail with the actual resolved limit.

**Rollback.** Delete the fixture and probe, or remove the probe scenario from the ADR-004 script.

## WI-3 — Traced Deterministic Harness

**Purpose.** Drive the production session loop and extension chain while keeping every external
contract deterministic and offline.

**Exact files.**

- New: `scripts/long_qwen_compaction_dst.ail`
- Optional only if duplication becomes unreasonable: `src/core/test/long_qwen_ports.ail`

**Implementation notes.**

- Prefer calling `Session.run_v2_session_traced` directly from `scripts/long_qwen_compaction_dst.ail`.
  Do not extend `run_v2_with_scripted_ports`; it returns only final result and uses the invalid
  assistant-count helper.
- Build `ExtRuntime` locally with hooks:
  `compaction_ai` registered under exact id `"compaction_ai"` first, then `compaction_structural`, plus
  a test tool extension that handles one tool name such as `LongResult`.
- For deterministic `compaction_ai` config in the script, prefer direct hook construction around
  `compact_with_ai` with config `{ model: "openrouter/qwen/qwen3.6-35b-a3b", threshold_pct: 60,
  keep_recent: 8 }` instead of relying on `MOTOKO_PROFILE_DIR`. This keeps the standing DST local to
  the script and avoids global profile state.
- Build custom `Ports`:
  - `model_step`: if prompt shape is exactly one user message and no system/tool messages, return a
    stable fake summary such as `summary:${digest_or_marker}` with no tool calls.
  - Otherwise derive the next agent step from retained markers in the current payload. Use markers in
    the most recent tool result content and/or tool call ids, for example `long-qwen-step-04`.
  - Return a tool-call step until the final marker, then return a terminal prose step.
  - Emit deterministic chunks or no chunks; keep the normalized projection stable either way.
  - `clock_now`: fixed integer.
  - `env_get`: fixed values, except allow `MOTOKO_MODELS_FILE` to be read by the actual environment
    through `catalog_context_limit_for`.
  - `proc_exec`: deterministic inert value; the production tool path should be through `on_tool_handle`,
    not process execution.
- The test `on_tool_handle` extension must return `Handled(ToolResultEnvelope)` with the incoming
  `tool_call_id`, tool name, exit code `0`, large deterministic `stdout`, empty `stderr`, and stable
  metadata. Include the next step marker in `stdout`.
- Keep large output paired: every assistant `tool_calls[].id` must have a following tool message with
  matching `tool_call_id`.
- Pin or normalize volatile fields narrowly. The happy path should not need broad normalization; if
  `RunSummaryInfo.duration_ms` enters the trace on an error path, normalize only that field in failure
  projections.

**Verification.**

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang check scripts/long_qwen_compaction_dst.ail
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
  scripts/long_qwen_compaction_dst.ail
```

**Teeth check.** Break the summarizer discriminator so one summarizer call consumes an agent step; the
long scenario must fail by missing markers or losing replay determinism. Revert.

**Rollback.** Delete `scripts/long_qwen_compaction_dst.ail` and optional helper module.

## WI-4 — Long-Session Scenarios

**Purpose.** Prove the long Qwen-labeled session applies `compaction_ai` several times, sends valid
sealed payloads after each application, and replays deterministically.

**Exact files.**

- `scripts/long_qwen_compaction_dst.ail`

**Implementation notes.**

- Implement `compaction.long_qwen_ai_multiple_compactions`.
- Implement `compaction.long_qwen_ai_replay_deterministic` by running the same fixture twice and
  comparing a normalized projection.
- Fixture shape:
  - Initial history has at least one non-empty system message and one user task.
  - Agent step `N` calls `LongResult` with id/arguments containing marker `long-qwen-step-N`.
  - Tool handler returns 1-2 KB deterministic content containing `long-qwen-step-(N+1)`.
  - Use enough tool turns to re-grow after each compaction. Start with 10-12 tool turns and tune down
    only after `>= 3` applications is stable.
  - End with a final prose step so `result` is `Ok`.
- Invariants:
  - `result` is `Ok`.
  - Count of `CompactionStageRecord({ ext_id: "compaction_ai", outcome: TraceStageApplied(_) }) >= 3`.
  - No `CompactionStageRecord` has `TraceStageRejected`; fail on any rejection, not only
    `compaction_ai`.
  - No in-memory `WireRecord(CompactionExhausted(_))` and no `WireRecord(ErrorEvent({ code:
    "SystemPromptEmpty", ... }))`.
  - For every applied `compaction_ai` stage, the next provider call for that step includes
    `WireRecord(ProviderCallPrepared(info))` with `info.model == "openrouter/qwen/qwen3.6-35b-a3b"`,
    `info.system_prefix_count >= 1`, `info.system_prefix_chars > 0`, and non-empty `payload_digest`.
  - That prepared call is followed by `WireRecord(ProviderResult(_))` before the next compaction stage
    or terminal result. Treat `ProviderCallPrepared` as seal acceptance, not dispatch success.
  - Returned persisted history length grows with the scripted tool loop and still includes the final
    tool-result markers; do not expect provider-payload compaction to mutate persisted `st.msgs`.
- Normalized replay projection should include ordered record names, step, `ext_id`, applied/rejected
  outcome tag, provider-prepared model/counts/digest, provider-result finish reason/tool call count,
  and final persisted-history digest/count. Exclude full large tool contents.

**Verification.**

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
  scripts/long_qwen_compaction_dst.ail
```

Expected output should include:

```text
scenario=compaction.long_qwen_ai_multiple_compactions ok
scenario=compaction.long_qwen_ai_replay_deterministic ok
```

**Teeth checks.**

- Change the `compaction_ai` hook id to a different string; the applied-count assertion must fail.
- Reduce tool output or turn count enough to get only two applications; the count assertion must fail.
- Return an empty system message in initial history; the system-prefix invariant must fail.

**Rollback.** Remove the two scenario registrations and helper functions from the ADR-004 script.

## WI-5 — Direct `compaction_ai` Scenarios

**Purpose.** Assert payload-shape validity and artifact-cache reuse where the ledger cannot show full
provider payload bodies.

**Exact files.**

- `scripts/long_qwen_compaction_dst.ail`
- Imports from:
  `pkg/sunholo/motoko_ext_compaction_ai/compaction_ai`
  `pkg/sunholo/motoko_ext_compaction_ai/types`
  `pkg/sunholo/motoko_ext_abi/types`
  `pkg/sunholo/motoko_ext_conformance/invariants`

**Implementation notes.**

- Implement `compaction.compaction_ai_output_shape_valid`:
  - Build representative `Msg` input with plain messages, assistant tool calls, matching tool results,
    and enough old turns to avoid `old_turns == 0`.
  - Use an `ExtCtx` with small `context_limit`, deterministic fake ports, empty artifacts, and config
    that forces `compact_with_ai` to return `Compacted`.
  - Assert the output contains a `[CONTEXT SUMMARY]` assistant message.
  - Assert tool-call/tool-result ids that survive in recent context remain paired.
  - Assert `validate_compactor_output(input, output)` returns `Ok`.
- Implement `compaction.compaction_ai_artifact_cache_stable`:
  - First run: fake summarizer returns `CACHED-SUMMARY-A`; capture returned artifacts and compacted
    output.
  - Second run: same old segment and same artifacts, but fake summarizer would return
    `CACHE-MISS-FAIL` or fail visibly if called.
  - Assert second output still contains `CACHED-SUMMARY-A` and not the miss sentinel.
  - Do not expect cross-turn cache hits in the long-session scenario; `compaction_ai` cache is a
    single-slot digest artifact.

**Verification.**

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
  scripts/long_qwen_compaction_dst.ail
```

Expected output should include:

```text
scenario=compaction.compaction_ai_output_shape_valid ok
scenario=compaction.compaction_ai_artifact_cache_stable ok
```

**Teeth checks.**

- Corrupt a surviving tool `tool_call_id`; `validate_compactor_output` must reject.
- Remove artifacts before the second cache run; the sentinel must appear or the scenario must fail.

**Rollback.** Remove direct scenarios and related imports from the ADR-004 script.

## WI-6 — Make / Gate Wiring

**Purpose.** Add the standing ADR-004 scenarios to the fast compaction gate with the test catalog
override, while keeping live Qwen out of CI.

**Exact files.**

- `Makefile`

**Implementation notes.**

- Extend `compaction_dst` unless the command becomes too slow; if it does, add a clearly named
  successor such as `compaction_long_dst` and make `compaction_dst` depend on it.
- Wire the deterministic run with the fixture:
  ```make
  MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
    ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
    scripts/long_qwen_compaction_dst.ail
  ```
- Do not wire `PROFILE=qwen36-compaction-live`, `OPENROUTER_API_KEY`, or any live run into this target.

**Verification.**

```bash
make compaction_dst
```

**Teeth check.** Temporarily unset or typo the fixture path in the Make target; the long scenario must
fail because the Qwen model limit resolves to `0` or the production 262K value.

**Rollback.** Remove only the ADR-004 command/dependency from `Makefile`; leave existing ADR-002
commands intact.

## WI-7 — Optional Live Calibration Instructions

**Purpose.** Give operators a repeatable way to gather live Qwen evidence without turning provider
behavior into a test oracle.

**Exact files.**

- New: `.agent/projects/001_DST/HANDOFF-live-qwen36-compaction-calibration.md`
  or a short section appended to this plan's implementation PR notes.

**Implementation notes.**

- Document a manual command using the dedicated profile, for example:
  ```bash
  PROFILE=qwen36-compaction-live make run TASK="Run a long tool-heavy compaction calibration task ..."
  ```
- Required evidence fields:
  - date, absolute UTC timestamp
  - profile `qwen36-compaction-live`
  - model string `openrouter/qwen/qwen3.6-35b-a3b`
  - `compaction_ai` model string
  - log path under `.motoko/logfile/` or archived evidence path
  - summary counts of observed compaction-related events
- State clearly that provider availability, prose quality, routing, pricing, and network behavior are
  calibration evidence only. The standing oracle is the offline DST.

**Verification.**

```bash
rg -n 'qwen36-compaction-live|openrouter/qwen/qwen3\.6-35b-a3b|calibration evidence only' \
  .agent/projects/001_DST/HANDOFF-live-qwen36-compaction-calibration.md
```

**Teeth check.** Ensure no Make target invokes the live profile:

```bash
rg -n 'qwen36-compaction-live|OPENROUTER_API_KEY' Makefile scripts
```

This should produce no fast-gate invocation.

**Rollback.** Delete the handoff/evidence note only.

---

## Final Acceptance Checklist

- Live profile selects `openrouter/qwen/qwen3.6-35b-a3b`.
- Production catalog maps `openrouter/qwen/qwen3.6-35b-a3b` to `262144`.
- Deterministic scenario runs offline with `MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json`.
- Long-session trace observes at least three in-memory `compaction_ai` `TraceStageApplied` records.
- Long-session trace observes zero in-memory `TraceStageRejected` records.
- Every counted compaction is followed by `ProviderCallPrepared` as seal acceptance and then
  `ProviderResult` as scripted dispatch success.
- Replay determinism is asserted over a bounded normalized trace projection.
- Direct `compaction_ai` output-shape scenario uses `validate_compactor_output`.
- Direct artifact-cache scenario proves same-segment cache reuse without relying on cross-turn hits.
- `make compaction_dst` runs the new standing scenarios with the test catalog override.
- Live Qwen calibration is documented as opt-in evidence only and is not in the fast gate.
