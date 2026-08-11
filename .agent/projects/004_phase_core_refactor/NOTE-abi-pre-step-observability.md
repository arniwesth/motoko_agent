# ABI note: observable pre-step pass-through decisions

**Status:** Proposed
**Date:** 2026-07-11
**Governed by:** `ADR-001-phase-oriented-core.md` D9
**Trigger:** A 100-step qwen36 stress run completed with 64 structural compactions and zero observable
AI compactions, but the current ABI erased every `compaction_ai` terminal `PassThrough` reason
(`.motoko/logfile/session_2026-07-11T10-20-34-975Z.jsonl`).

## Decision

Add a first-class, structured, observable pass-through decision to the pre-step ABI and carry it through
the runtime stage trace to a dedicated ledger event. It behaves exactly like `PassThrough` for messages,
artifacts, chain order, validation, and counters; its only effect is deterministic observability.

This is an ABI-major change because adding a constructor breaks exhaustive matches over
`PreStepDecision` (`packages/motoko-ext-abi/types.ail:143`). The rollout is ABI **4.0** and conformance-kit
**4.0** in lockstep. This note does not change D9 ownership: compaction policy remains extension-resident;
core only transports and records the extension's observation.

## ABI shape

Extend `PreStepDecision` from its current two constructors (`packages/motoko-ext-abi/types.ail:143-146`):

```ailang
export type PreStepDecision
  = PassThrough
  | PassThroughObserved(code: string, detail: Json)
  | Compacted(msgs: [Msg], note: string, artifacts: Json)
  deriving (Eq)
```

`PassThrough` stays available for the normal, uninteresting case. `PassThroughObserved` is for a terminal
decision that an operator must be able to distinguish from other pass-through paths. It carries no
artifact update; state mutation remains exclusive to a valid `Compacted` result.

The initial producer is `compaction_ai`, with these stable codes:

| Code | Meaning | Required detail |
|---|---|---|
| `compaction_ai.no_foldable_prefix` | Threshold crossed, but no complete prefix can be folded | `pct`, `tail_tokens`, `tail_budget` |
| `compaction_ai.insufficient_relief` | A fold would not meet configured minimum relief | `pct`, `projected_pct`, `min_relief_pct` |
| `compaction_ai.summarizer_failed` | All returned summarizer attempts failed or were empty | `pct`, `attempts`, `reason_class` |
| `compaction_ai.output_not_relieving` | A returned summary made measured usage worse | `pct`, `new_pct`, `boundary_marker` |
| `compaction_ai.cache_invalid` | Cached boundary is absent or outside the append-only body | `boundary_marker`, `body_messages` |

Successful cache reuse and refresh remain `Compacted` with their existing `AI-cache-reused` and
`AI-folded` notes. Do not emit observations for `below_threshold`: that is routine and would add one event
per extension per step without diagnostic value.

## Runtime semantics

Add `StageObserved(code: string, detail: Json)` beside the existing outcomes in
`src/core/ext/runtime.ail:30`. In `fold_pre_step_chain_rec` (`src/core/ext/runtime.ail:152-184`), handle
`PassThroughObserved` identically to `PassThrough`:

- pass the same `msgs` to the next hook;
- pass the accumulated `artifacts` argument unchanged;
- do not run `validate_compactor_output`;
- append one `StageObserved` record for the producing extension;
- preserve registry order.

An observation is neither an applied nor a rejected stage. It must not increment
`stage_applied_total`, `stage_rejected_total`, or an extension's applied-compaction counter. This prevents
the identity-`Compacted` workaround from contaminating telemetry.

The runtime must also update the test-dummy decision match at `src/core/ext/runtime.ail:158-161` so ABI
4 exhaustive matching remains enforced.

## Ledger and trace

Add `TraceStageObserved(code: string, detail: Json)` to the in-memory stage outcome beside
`TraceStageApplied`, `TraceStageRejected`, and `TraceStagePassed`
(`src/core/phase_vocab.ail:544`). `hook_phase.stage_record` (`src/core/hook_phase.ail:14-18`) maps the
runtime outcome without changing messages or artifacts.

Admit a dedicated wire event named `extension_diagnostic`:

```json
{
  "schema_version": "1",
  "session_id": "...",
  "type": "extension_diagnostic",
  "step": 36,
  "extension": "compaction_ai",
  "code": "compaction_ai.summarizer_failed",
  "detail": {
    "pct": 81,
    "attempts": 2,
    "reason_class": "provider_error"
  }
}
```

`emit_pre_step_stages` currently emits only applied and rejected outcomes
(`src/core/session.ail:296-311`); it gains the observed case. Do not overload
`compaction_extension`, whose meaning remains "a validated compaction stage changed or reconstructed the
send payload." `extension_diagnostic` is general to extension observations even though the first producer
is a compactor.

Wire projection and replay retain the observation in order. Deterministic replay compares `extension`,
`code`, and canonical `detail`, just as it compares applied/rejected stage records; observations never
affect the provider payload digest.

## Determinism and data limits

- `code` is a stable dotted identifier, not provider prose.
- `detail` contains bounded scalars and short classifications, not message content, prompts, summaries,
  stack traces, request IDs, timestamps, or raw provider errors.
- Provider failures map to stable `reason_class` values such as `provider_error`, `empty_response`, and
  `attempts_exhausted`. Raw error text stays out of the event.
- Encoded `detail` is capped at 2 KiB at the producer. Oversized detail is replaced with
  `{ "detail_truncated": true }`; it must not make the pre-step hook fail.
- One invocation returns at most one terminal observation. Internal retries do not each create a ledger
  record.

These rules keep the event replay-stable and avoid copying sensitive context into the audit log.

## In-flight diagnostics are deferred

This change diagnoses every pre-step invocation that returns. It cannot prove that `ai_step` started when
the call never returns. A future `ExtPorts.emit_diagnostic` callback could emit
`compaction_ai.summarizer_started` before `ai_step`, but that broadens the effects and re-entrancy surface
of every extension port record. The completed 100-step run needs terminal reasons, not in-flight events,
so that addition is deliberately excluded. Revisit it with the summarizer-hang issue if returned
diagnostics still leave an actual stalled call ambiguous.

## Migration

1. Bump `motoko-ext-abi` and `motoko_ext_conformance` majors to 4.0 and update package locks/manifests.
2. Add the ABI constructor and update every exhaustive `PreStepDecision` match. Hook record literals that
   only return `PassThrough` require no source change beyond recompilation.
3. Add runtime `StageObserved`, trace `TraceStageObserved`, and the `extension_diagnostic` ledger event.
4. Update trace projection, replay comparison, status aggregation, event golden tests, phase parity tests,
   and scripts that exhaustively match stage outcomes.
5. Change only diagnostically meaningful `compaction_ai` pass-through exits to
   `PassThroughObserved`; leave below-threshold and ordinary no-op paths as `PassThrough`.
6. Add the qwen36 DST scenario before enabling a new live run.

Known exhaustive-match surfaces at this working HEAD include `src/core/ext/runtime.ail`,
`src/core/hook_phase.ail`, `src/core/session.ail`, `scripts/smoke_v2_compaction_chain.ail`,
`scripts/long_qwen_compaction_dst.ail`, `scripts/phase_c2_wiring_scenarios.ail`, and
`scripts/phase_c_l1_scenarios.ail`. Re-run `rg "PassThrough|StageApplied|TraceStageApplied"` during
implementation; this list is an anchor, not a substitute for migration discovery.

## Acceptance

- A `PassThroughObserved` stage leaves messages and artifacts byte-for-byte equivalent to `PassThrough`.
- It produces exactly one ordered `extension_diagnostic` event and one `TraceStageObserved` record.
- It increments neither applied nor rejected compaction counters.
- Existing unobserved pass-through produces no wire event.
- Applied and rejected compaction event shapes remain unchanged.
- Conformance verifies message/artifact identity, stage ordering, deterministic replay, and counter
  neutrality for the new constructor.
- `scripts/long_qwen_compaction_dst.ail` covers each `compaction_ai` terminal code without network access.
- Re-running the 100-step qwen36 stress profile yields either `AI-folded`/`AI-cache-reused` events or a
  terminal diagnostic explaining every over-threshold AI pass-through.

Required gates: `make compaction_dst`, `make conformance`, phase event-parity/DST gates affected by the
new event, package tests for `compaction_ai`, and `MOTOKO_CONFIG=qwen36-compaction-live make
verify_extensions`.

## Non-goals

- No change to ephemeral compaction or `st.msgs`.
- No compaction threshold, calibration, cache, or summarizer policy in core.
- No artifact mutation from a pass-through decision.
- No raw prompt, summary, message, or provider-error logging.
- No in-flight diagnostic callback in this ABI addition.
- No reinterpretation of `compaction_extension` or existing telemetry counters.
