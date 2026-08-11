# ABI note: observable pre-step pass-through decisions

**Status:** Implemented 2026-07-12 (rollout `e90ded1`; live acceptance and scope partition recorded
in `NOTE-abi-pre-step-observability-closeout.md`)
**Date:** 2026-07-11
**Governed by:** `ADR-001-phase-oriented-core.md` D9
**Trigger:** A 100-step qwen36 stress run completed with 64 structural compactions and zero observable
AI compactions, but the current ABI erased every `compaction_ai` terminal `PassThrough` reason
(`.motoko/logfile/session_2026-07-11T10-20-34-975Z.jsonl`).

## TL;DR

`compaction_ai` currently loses every reason attached to a returned `PassThrough`, so a completed live
run can show zero AI compactions without revealing whether the threshold was missed, relief was too small,
the summarizer failed, or the summary output was rejected. Add ABI 4.0
`PassThroughObserved(code, fields)` with bounded scalar fields. Core transports it exactly like ordinary
pass-through, records one ordered `extension_diagnostic` event, and changes no messages, artifacts, or
compaction counters. Instrument only terminal over-threshold AI exits; below-threshold stays silent.

This is an atomic ABI/conformance major rollout, not a compaction-policy change. Raw `Json` diagnostics,
identity `Compacted` diagnostics, in-flight callbacks, persistent history, and cache-policy changes are
out of scope. Malformed cache state attempts a fresh fold and is replaced rather than becoming a recurring
diagnostic pass.

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
export type DiagnosticField = { key: string, value: string }

export type PreStepDecision
  = PassThrough
  | PassThroughObserved(code: string, fields: [DiagnosticField])
  | Compacted(msgs: [Msg], note: string, artifacts: Json)
  deriving (Eq)
```

`PassThrough` stays available for the normal, uninteresting case. `PassThroughObserved` is for a terminal
decision that an operator must be able to distinguish from other pass-through paths. It carries no
artifact update; state mutation remains exclusive to a valid `Compacted` result.

The initial producer is `compaction_ai`, with these stable codes:

| Code | Meaning | Required fields |
|---|---|---|
| `compaction_ai.no_foldable_prefix` | Threshold crossed, but no complete prefix can be folded | `pct`, `tail_tokens`, `tail_budget` |
| `compaction_ai.insufficient_relief` | A fold would not meet configured minimum relief | `pct`, `projected_pct`, `min_relief_pct` |
| `compaction_ai.summarizer_failed` | All returned summarizer attempts failed or were empty | `pct`, `attempts`, `reason_class` |
| `compaction_ai.output_not_relieving` | A returned summary made measured usage worse | `pct`, `new_pct`, `boundary_marker` |

Successful cache reuse and refresh remain `Compacted` with their existing `AI-cache-reused` and
`AI-folded` notes. A malformed cache is not a terminal pass-through reason: the extension ignores it,
performs a fresh fold, and replaces it through the returned `Compacted` artifacts. If that recovery fails,
the emitted observation is the actual terminal reason (`no_foldable_prefix`, `insufficient_relief`,
`summarizer_failed`, or `output_not_relieving`). This avoids preserving a poison cache indefinitely.
Do not emit observations for `below_threshold`: that is routine and would add one event per extension per
step without diagnostic value.

## Runtime semantics

Add `StageObserved(code: string, fields: [DiagnosticField])` beside the existing outcomes in
`src/core/ext/runtime.ail:30`. In `fold_pre_step_chain_rec` (`src/core/ext/runtime.ail:152-184`), handle
`PassThroughObserved` identically to `PassThrough`:

- pass the same `msgs` to the next hook;
- pass the accumulated `artifacts` argument unchanged;
- do not run `validate_compactor_output`;
- normalize the observation to the ABI limits below and append one `StageObserved` record for the
  producing extension;
- preserve registry order.

An observation is neither an applied nor a rejected stage. It must not increment
`stage_applied_total`, `stage_rejected_total`, or an extension's applied-compaction counter. This prevents
the identity-`Compacted` workaround from contaminating telemetry.

The runtime must also update the test-dummy decision match at `src/core/ext/runtime.ail:158-161` so ABI
4 exhaustive matching remains enforced.

## Ledger and trace

Add `TraceStageObserved(code: string, fields: [DiagnosticField])` to the in-memory stage outcome beside
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
  "fields": [
    { "key": "attempts", "value": "2" },
    { "key": "pct", "value": "81" },
    { "key": "reason_class", "value": "provider_error" }
  ]
}
```

`emit_pre_step_stages` currently emits only applied and rejected outcomes
(`src/core/session.ail:296-311`); it gains the observed case. Do not overload
`compaction_extension`, whose meaning remains "a validated compaction stage changed or reconstructed the
send payload." `extension_diagnostic` is general to extension observations even though the first producer
is a compactor.

Wire projection and replay retain the observation in order. Deterministic replay compares `extension`,
`code`, and the normalized ordered `fields`, just as it compares applied/rejected stage records; observations never
affect the provider payload digest.

## Determinism and data limits

- `code` is a stable dotted identifier, not provider prose, and is limited to 96 ASCII characters.
- `fields` is limited to 16 entries. Each key is limited to 64 ASCII characters and each value to 256
  ASCII characters. Values are strings so the ABI does not admit recursive or unbounded diagnostic data.
- Producers supply fields in ascending key order with unique keys. The runtime ASCII-sanitizes code,
  keys, and values; drops empty keys; keeps the first occurrence of a duplicate key; sorts the result by
  key; and retains the first 16 sorted entries after truncating key/value lengths. A nonconforming code is
  replaced with `extension.invalid_diagnostic`. This normalization is pure and cannot reject or abort the
  stage.
- Fields contain bounded scalars and short classifications, not message content, prompts, summaries,
  stack traces, request IDs, timestamps, or raw provider errors.
- Provider failures map to stable `reason_class` values such as `provider_error`, `empty_response`, and
  `attempts_exhausted`. Raw error text stays out of the event.
- One invocation returns at most one terminal observation. Internal retries do not each create a ledger
  record.
- When several internal conditions occur, report the condition that directly determines the returned
  pass-through. Earlier context may be included only as a bounded classification field; it must not
  replace the terminal code. This makes code selection deterministic.

The runtime-enforced shape bounds the event below 6 KiB even for a buggy producer. Semantic restrictions
(for example, not placing prompt text in a value) remain producer obligations and receive conformance
tests in bundled extensions. These rules keep the event replay-stable and avoid copying sensitive context
into the audit log.

## In-flight diagnostics are deferred

This change diagnoses every pre-step invocation that returns. It cannot prove that `ai_step` started when
the call never returns. A future `ExtPorts.emit_diagnostic` callback could emit
`compaction_ai.summarizer_started` before `ai_step`, but that broadens the effects and re-entrancy surface
of every extension port record. The completed 100-step run needs terminal reasons, not in-flight events,
so that addition is deliberately excluded. Revisit it with the summarizer-hang issue if returned
diagnostics still leave an actual stalled call ambiguous.

## Blast radius

The implementation is cross-cutting because the new ABI constructor and stage outcomes require exhaustive
match updates. Re-grep at implementation HEAD; this table records ownership and expected change, not a
frozen site count.

| Area | Files / packages | Required change |
|---|---|---|
| ABI surface | `packages/motoko-ext-abi/types.ail`, `packages/motoko-ext-abi/ailang.toml` | Add `DiagnosticField` and `PassThroughObserved`; bump ABI to 4.0. |
| Runtime chain | `src/core/ext/runtime.ail` | Normalize observations, add `StageObserved`, preserve message/artifact flow, update test-dummy and unit matches. |
| Typed trace and wire vocabulary | `src/core/phase_vocab.ail` | Add `TraceStageObserved`, diagnostic info/event, record name, schema-v1 projection, and goldens. |
| Stage mapping | `src/core/hook_phase.ail` | Map normalized runtime observations into the in-memory trace. |
| Session emission and counters | `src/core/session.ail` | Emit `extension_diagnostic`; update exhaustive trace/status aggregation while keeping counters neutral. |
| Initial producer | `packages/motoko-ext-compaction-ai/compaction_ai.ail` | Return stable observed codes on four terminal over-threshold paths; distinguish malformed cache and recover through a fresh fold. |
| Conformance 4.0 | `packages/motoko_ext_conformance/{ailang.toml,invariants.ail,harness.ail,fixtures/*}` | Bump kit/banner; certify identity, normalization bounds, ordering, replay, and counter neutrality. |
| Core/DST scripts | `scripts/long_qwen_compaction_dst.ail`, `scripts/smoke_v2_compaction_chain.ail`, `scripts/phase_c2_wiring_scenarios.ail`, `scripts/phase_c_l1_scenarios.ail`, phase event-parity scripts | Update exhaustive outcomes and add deterministic terminal-code/event scenarios. |
| Extension consumers | Every package importing `sunholo/motoko_ext_abi`, plus generated registry inputs | Resolve ABI 4.0 atomically; hook literals returning plain `PassThrough` generally recompile without logic edits, but exhaustive matches must change. |
| Hydration and gates | `ailang.lock`, affected package manifests, generated registry/cache state, `Makefile` only where a missing authoritative gate must be added | Prevent mixed ABI 3/4 hydration and run the complete gate set. Preserve unrelated existing hunks. |
| Documentation | This note and `HANDOFF-implement-abi-pre-step-observability.md` | Freeze the reviewed contract and implementation discipline before source work. |

Explicitly untouched: persistent session history and `st.msgs`, token calibration, compaction thresholds,
tail budgets, prompts, tool-hook ABI, evidence storage, and `ExtPorts`.

## Migration

1. Bump `sunholo/motoko_ext_abi` (`packages/motoko-ext-abi/ailang.toml`, currently `3.0`) and
   `sunholo/motoko_ext_conformance` (`packages/motoko_ext_conformance/ailang.toml`, currently `3.0.0`)
   to 4.0 and update `conformance_abi_version()` (`packages/motoko_ext_conformance/invariants.ail:6`).
   Update every extension package dependency resolution, the root lock, and generated registry inputs;
   there must be no mixed ABI 3/4 extension registry.
2. Add the ABI constructor and update every exhaustive `PreStepDecision` match. Hook record literals that
   only return `PassThrough` require no source change beyond recompilation.
3. Add runtime normalization and `StageObserved`, then add `TraceStageObserved`, an
   `ExtensionDiagnostic` ledger constructor/info record, and the `extension_diagnostic` schema-v1
   projection in `src/core/phase_vocab.ail`. The event is additive within schema v1, matching the repo's
   existing treatment of newly admitted event names; it does not change existing event shapes.
4. Update `ledger_record_name`, trace projection, replay comparison, status aggregation, event golden
   tests, phase parity tests, and every script that exhaustively matches runtime, trace, or wire outcomes.
5. Change only diagnostically meaningful `compaction_ai` pass-through exits to
   `PassThroughObserved`; leave below-threshold and ordinary no-op paths as `PassThrough`. Split cache
   parsing into absent, valid, and malformed states so malformed state takes the fresh-fold recovery path
   rather than becoming indistinguishable from a normal first fold.
6. Add the qwen36 DST scenario before enabling a new live run.

Known exhaustive-match surfaces at this working HEAD include `src/core/ext/runtime.ail`,
`src/core/hook_phase.ail`, `src/core/phase_vocab.ail`, `src/core/session.ail`,
`scripts/smoke_v2_compaction_chain.ail`,
`scripts/long_qwen_compaction_dst.ail`, `scripts/phase_c2_wiring_scenarios.ail`, and
`scripts/phase_c_l1_scenarios.ail`. Re-run `rg "PassThrough|StageApplied|TraceStageApplied"` during
implementation; this list is an anchor, not a substitute for migration discovery.

Rollout order is atomic: ABI types and all exhaustive consumers, conformance 4.0, bundled extensions,
generated registry/lock state, then runtime profiles. `make verify_extensions` must reject any stale
package that still resolves ABI 3.0; do not publish or hydrate a partial registry.

## Acceptance

- A `PassThroughObserved` stage leaves messages and artifacts byte-for-byte equivalent to `PassThrough`,
  including when its code or fields require normalization.
- It produces exactly one ordered `extension_diagnostic` event and one `TraceStageObserved` record.
- It increments neither applied nor rejected compaction counters.
- Existing unobserved pass-through produces no wire event.
- Applied and rejected compaction event shapes remain unchanged.
- Registry hydration contains one ABI major only, and the conformance banner reports kit 4.0 / ABI 4.0.
- Conformance verifies message/artifact identity, stage ordering, deterministic replay, counter
  neutrality, field ordering, and runtime bounds for the new constructor.
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
