# Handoff: implement observable pre-step pass-through decisions

Date: 2026-07-11 (written after four iterative review passes over the ABI note)
Audience: a fresh implementation session.

## Mission

Implement `NOTE-abi-pre-step-observability.md` in this directory. **The reviewed note is the normative
spec.** Do not re-derive the design from the qwen log or widen it into a general diagnostics framework.

The deliverable is an atomic ABI **3.0 -> 4.0** rollout adding bounded, structured
`PassThroughObserved(code, fields)` to `PreStepDecision`, transporting it through runtime and in-memory
stage outcomes, and emitting a counter-neutral `extension_diagnostic` ledger event. Then instrument the
diagnostically meaningful terminal `compaction_ai` pass-through paths and add deterministic conformance
and qwen36 DST coverage.

This is an ABI/core change authorized as an ABI note under `ADR-001-phase-oriented-core.md` D9. It does
not move compaction policy into core and does not alter ephemeral history.

## Current state: verify, do not trust

- Branch: `arniwesth/mot-39-rederivation-context-strategy`.
- HEAD when this handoff was written: `204c8e9` (`Added note`).
- The initial note is committed at HEAD, but its four-pass review corrections are currently an
  **uncommitted modification** to `NOTE-abi-pre-step-observability.md`. Commit that file docs-only before
  source edits so the reviewed contract is frozen separately.
- Pre-existing unrelated dirty files at handoff time:
  `.motoko/config/hunyuan3-free-compaction-live/compaction_ai.json`,
  `.motoko/config/hunyuan3-free-compaction-live/config.json`, `.motoko/config/local/config.json`,
  `Makefile`, and `ailang.lock`. Leave them intact. The implementation legitimately needs Makefile/lock
  changes later; read and preserve the user's existing hunks rather than replacing the files wholesale.
- ABI package version is `3.0` (`packages/motoko-ext-abi/ailang.toml:3`); conformance is `3.0.0`
  (`packages/motoko_ext_conformance/ailang.toml:3`) and reports `3.0` from
  `packages/motoko_ext_conformance/invariants.ail:6`.
- Current source anchors at handoff HEAD: `PreStepDecision` `packages/motoko-ext-abi/types.ail:143`,
  `StageOutcome` `src/core/ext/runtime.ail:30`, chain fold `runtime.ail:152`, in-memory outcome
  `src/core/phase_vocab.ail:544`, ledger event union `phase_vocab.ail:593`, schema projection
  `phase_vocab.ail:666`, stage mapping `src/core/hook_phase.ail:14`, and wire emission
  `src/core/session.ail:296`. Re-grep after the docs commit and before every WI; line numbers will drift.

## Why this work exists

The completed 100-step run
`.motoko/logfile/session_2026-07-11T10-20-34-975Z.jsonl` recorded 64 structural compactions and **zero**
AI fold/cache events. It billed 4,869,616 input tokens and peaked at 169,948 input tokens on step 35.
The current ABI reduces every returned AI failure/no-op to silent `PassThrough`, so the log cannot
distinguish no trigger, insufficient relief, summarizer failure, or rejected summary output.

Do not use identity `Compacted(msgs, note, artifacts)` as diagnostics: it falsely increments applied
compaction telemetry. The new observed pass-through must preserve the exact message/artifact flow and be
neither applied nor rejected.

## Reading order

1. `NOTE-abi-pre-step-observability.md` — the spec. Read all of it, especially ABI shape, runtime
   normalization, malformed-cache recovery, migration, and acceptance.
2. `ADR-001-phase-oriented-core.md` D9 (`:181` at handoff HEAD) — ownership and chain semantics. Do not
   reopen D9.
3. `NOTE-rederivation-implementation-findings.md` in `../006_compactor_strategy/` — current Engine A and
   WS4a state.
4. `PLAN-rederivation-context-strategy.md` in `../006_compactor_strategy/` — only its pre-step chain and
   artifacts sections. The observability change must not mutate `st.msgs` or compaction policy.
5. The 100-step log analysis facts above; do not survey unrelated agent harnesses.

## Pre-flight

Run before editing source:

```bash
git rev-parse --short HEAD
git status --short
git diff --check -- .agent/projects/004_phase_core_refactor/NOTE-abi-pre-step-observability.md
git log --oneline -10 -- packages/motoko-ext-abi packages/motoko_ext_conformance src/core packages/motoko-ext-compaction-ai
rg -n "PassThrough|Compacted\(" packages src scripts --glob '*.ail'
rg -n "StageApplied|StageRejected|StagePassed|TraceStageApplied|TraceStageRejected|TraceStagePassed" src scripts packages --glob '*.ail'
make compaction_dst
make conformance
AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail
MOTOKO_CONFIG=qwen36-compaction-live make verify_extensions
```

Commit only the reviewed note before source work. If a baseline is red, record the exact pre-existing
failure before proceeding; do not repair unrelated dirty-tree changes as part of this rollout.

## Execution order

Keep each step check-green before continuing. Because the registry cannot safely mix ABI majors, the
final source/manifest/lock rollout is atomic even if intermediate local commits are used.

1. **ABI 4.0 types.** Add exported `DiagnosticField = {key, value}` and
   `PassThroughObserved(code, fields)`. Bump the ABI manifest. Preserve `Compacted` and all other ABI
   shapes exactly.
2. **Runtime transport and normalization.** Add `StageObserved`; implement pure normalization exactly as
   specified: ASCII sanitize, drop empty keys, first duplicate wins, sort by key, truncate, retain 16,
   replace invalid code. Observed flow passes the accumulated `msgs` and `artifacts` unchanged and skips
   compactor validation.
3. **Trace and ledger.** Add `TraceStageObserved`, `ExtensionDiagnostic` info/event, schema-v1
   `extension_diagnostic`, `ledger_record_name`, ordered trace projection/replay, and session emission.
   Update every exhaustive match. Existing applied/rejected wire shapes remain byte-for-byte unchanged.
4. **Counters/status.** Prove observed stages increment neither applied nor rejected totals and do not
   count as `compaction_ai_applied`. Update exhaustive status aggregation without creating a new
   compaction counter unless the note is amended first.
5. **Conformance 4.0.** Bump package/version banner and add identity, ordering, bounds, replay, and counter
   neutrality scenarios. Update fixtures and registry probe expectations.
6. **Instrument `compaction_ai`.** Only terminal over-threshold pass-throughs become observed:
   `no_foldable_prefix`, `insufficient_relief`, `summarizer_failed`, and `output_not_relieving`.
   Below-threshold remains silent `PassThrough`. Split cache parsing into absent/valid/malformed;
   malformed cache attempts a fresh fold and is replaced by valid `Compacted` artifacts rather than
   becoming a recurring observed pass.
7. **Migrate all packages and hydration.** Update every ABI dependency, generated registry inputs,
   manifests, and the root lock while preserving existing user changes. The hydrated runtime must contain
   one ABI major only.
8. **DST and live corroboration.** Add offline scenarios for every terminal code and successful
   fold/cache reuse. Only after all offline gates pass, re-run the qwen36 100-step profile and confirm each
   over-threshold AI pass produces either `AI-folded`/`AI-cache-reused` or exactly one terminal
   `extension_diagnostic`.

## Expensive traps

1. **Raw `Json` diagnostics are rejected by the reviewed note.** They cannot enforce bounds, scalar-only
   content, or canonical ordering. Use `[DiagnosticField]` and core normalization.
2. **Observed is pass-through, not identity compaction.** Do not validate it, change artifacts/messages,
   emit `compaction_extension`, or increment applied/rejected counters.
3. **Normalize before both trace and wire emission.** If trace stores raw fields while wire stores
   normalized fields, deterministic replay will diverge.
4. **Malformed cache must recover.** Treating it as terminal observed pass preserves poison state forever.
   Attempt a fresh fold; report the actual terminal reason only if recovery fails.
5. **One terminal observation per invocation.** Internal retries are not separate returned decisions.
   Report the condition that directly caused the final pass-through.
6. **Returned observations cannot diagnose an in-flight hang.** Do not add `ExtPorts.emit_diagnostic` in
   this rollout. It is explicitly deferred in the note.
7. **ABI constructor addition breaks exhaustive matches.** The handoff's grep is mandatory. Known areas
   include runtime, hook/session/phase vocabulary, phase C scenarios, compaction DST, conformance
   fixtures/harness, and package tests; do not trust this list as complete.
8. **Preserve chain artifacts.** Observed uses the fold's accumulated `artifacts` argument, not a freshly
   constructed object and not a stale per-hook replacement.
9. **Do not bump ledger schema solely for the additive event.** The note admits
   `extension_diagnostic` within schema v1, consistent with existing additive event names.

## Gates

At minimum, all of these must be green before closeout:

```bash
make compaction_dst
make conformance
AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail
MOTOKO_CONFIG=qwen36-compaction-live make verify_extensions
```

Also run every phase event-parity/DST target touched by new `LedgerEvent` and stage constructors. Discover
the authoritative Make targets at implementation HEAD rather than copying stale names. Add focused ABI
and runtime tests proving normalization, unchanged message/artifact flow, one ordered event, and counter
neutrality.

For live closeout, report separately:

- AI fold count and cache-reuse count;
- terminal diagnostic counts grouped by code;
- structural compaction count;
- total/peak/median input tokens;
- first over-threshold and first compaction/diagnostic step;
- whether the model stayed productive (`finish_reason:"tool_calls"`).

## Guardrails

- Do not mutate `st.msgs` or persistent history.
- Do not change token calibration, thresholds, tail budgets, summarizer prompts, or Engine A policy while
  adding observability. A diagnostic may reveal a policy bug; fix it in a separate, evidence-backed WI.
- Do not add the deferred in-flight callback, tool-result hook, tool-hook artifact writes, evidence store,
  or persistent compaction.
- Do not log raw prompts, messages, summaries, provider errors, paths from message content, timestamps, or
  request IDs in diagnostic fields.
- Do not revert or absorb unrelated dirty-tree changes.

## Definition of done

- The reviewed note is committed docs-only before implementation commits.
- ABI/conformance 4.0 hydrate atomically with no ABI 3 package in the active registry.
- All exhaustive matches compile and all gates above pass.
- Observed pass-through is payload/artifact identical, ordered, bounded, replay-stable, and counter-neutral.
- Every specified `compaction_ai` terminal path has an offline deterministic scenario.
- The live 100-step rerun is explainable: every over-threshold AI outcome is a successful compact/cache
  event or one terminal diagnostic.
- Closeout records the live comparison against the 4,869,616-input-token baseline without claiming the
  instrumentation itself fixes cost.
