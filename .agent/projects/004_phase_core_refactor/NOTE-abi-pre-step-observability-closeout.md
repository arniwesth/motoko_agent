# Closeout: ABI 4.0 observable pre-step pass-through

**Status:** Closed 2026-07-12
**Closes:** `NOTE-abi-pre-step-observability.md` (the contract) and
`HANDOFF-implement-abi-pre-step-observability.md` (the implementation discipline)
**Governed by:** `ADR-001-phase-oriented-core.md` D9 (compaction policy stays extension-resident;
core transports and records)

## Verdict

Accepted. Every over-threshold `compaction_ai` outcome in the post-fix qwen36 stress rerun is a
successful `AI-folded`/`AI-cache-reused` compaction event; zero terminal diagnostics were needed
because zero invocations failed. The ambiguity that triggered the work item — a completed 100-step
run with 64 structural compactions and no way to tell why AI compaction never fired — can no longer
occur: a silent outcome is now either below-threshold (by design) or a bug.

The instrumentation also already did its diagnostic job before the rerun: it found the two live
summarizer failures described under "Diagnostic value demonstrated" below.

## Gates (all green, run 2026-07-12 at branch HEAD)

- `make compaction_dst` — includes `long_qwen_compaction_dst` PASS count=8 with the
  `compaction.compaction_ai_terminal_observations` scenario covering all four terminal codes offline.
- `make conformance` — kit 4.0 / ABI 4.0; four compactor scenarios plus the registry probe
  (single ABI major hydrated).
- `phase_c_l1_scenarios` PASS count=15; `phase_c2_wiring_scenarios` PASS count=18
  (includes the `TraceStageObserved` mapping).
- `AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail` — 11/11,
  including per-terminal-code tests and `test_ai_malformed_cache_recovers_with_fresh_fold`.
- `MOTOKO_CONFIG=qwen36-compaction-live make verify_extensions` — 6 booted, 0 failed.

## Live rerun vs. the trigger baseline

Baseline is the run that triggered the work item
(`.motoko/logfile/session_2026-07-11T10-20-34-975Z.jsonl`, pre-instrumentation). Rerun is the
post-fix 100-step qwen36 stress profile
(`.motoko/logfile/session_2026-07-12T08-25-25-542Z.jsonl`).

| Metric | Baseline 2026-07-11 | Rerun 2026-07-12 |
|---|---|---|
| Steps executed | 100 (`max_steps` exhausted) | 49 (`stop`: model emitted final summary) |
| AI folds | 0 | 15 |
| AI cache reuses | 0 | 11 |
| Structural compactions | 64 | 1 (tier1, step 22) |
| Terminal diagnostics | 0 (constructor did not exist) | 0 (no over-threshold failure) |
| First compaction | step 36 (structural tier1) | step 22 structural; step 23 first AI fold (79% → 21%) |
| First over-threshold AI invocation | unknowable (the trigger defect) | step 23, folded |
| Total input tokens | 4,869,616 | 2,807,104 |
| Peak / median input tokens per step | 169,948 / 32,725 | 176,199 / 43,825 |
| Productive steps (`finish_reason:"tool_calls"`) | 100/100 | 48/49 (49th is the final answer) |
| Duration | 454s | 1,061s |

Read the token numbers as context, not as a cost claim (per the handoff: the instrumentation does
not itself fix cost). The runs are not step-count-comparable — the rerun concluded naturally at 49
steps — and per-step medians are higher in the rerun while AI folds cut usage far deeper per event
(79% → 21% vs. structural `keep_last` trims). The load-bearing comparison is the explainability
column: baseline had zero AI compactions with zero evidence; the rerun's AI outcomes are fully
accounted for. Added wall-clock time is the expected price of live summarizer calls.

## Diagnostic value demonstrated (pre-fix runs, 2026-07-11)

The first instrumented runs immediately converted the silent failure into root causes:

- `session_2026-07-11T12-11-11-674Z`: 75 × `compaction_ai.summarizer_failed` /
  `reason_class=provider_error` — led directly to the root cause (the extension's `ai_step` sent the
  un-stripped `openrouter/` model prefix, a 400 invalid-model error), fixed in `592d116` by applying
  `provider_api_model` at the seam.
- `session_2026-07-11T16-32-32-351Z`: 12 × `compaction_ai.summarizer_failed` /
  `reason_class=empty_response` — motivated the fail-fast-on-non-retryable-errors work (`2df3312`).

Both fixes were made as separate commits from the observability rollout, per the handoff guardrail.

## Branch scope partition (for PR framing)

The branch `arniwesth/mot-40-observable-pre-step-pass-through` contains three distinguishable
tracks; the observability WI proper is track 1.

1. **ABI 4.0 observability rollout** (this WI): `a6f7efc`/`bd32ad1` (docs), `e90ded1`
   (implementation: ABI types, runtime normalization, vocab/session wiring, conformance 4.0,
   `compaction_ai` terminal codes), `7eebea7` (long_qwen terminal-observations DST scenario),
   `194fbd6`/`e89ce7a` (stub_step + phase_c2 tests), `6448190` (lock).
2. **Policy fixes the diagnostics revealed** (evidence-backed, separate WIs per the guardrail):
   `592d116` (summarizer `provider_api_model` seam fix), `2df3312` (fail fast on non-retryable
   model errors; enable hy3:free compaction), `d6dbda6` (persist-nudge fix; follow-up issue
   `.agent/issues/persist-nudge-should-be-extension.md`).
3. **Calibration/simulation additions:** `e8808a3` (deepseek-v4-flash 256k live profile +
   Makefile targets).

## Residuals

- The in-flight diagnostic callback (`ExtPorts.emit_diagnostic`) remains deferred, as decided in
  the note; the rerun did not exhibit a stalled summarizer call, so no new evidence forces it.
- The contract was implemented as specified; no deviations from the note's ABI shape, runtime
  semantics, or data limits were needed.
