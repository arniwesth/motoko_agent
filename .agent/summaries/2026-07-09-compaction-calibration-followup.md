# Compaction Calibration Follow-up

Date: 2026-07-09

## Context

Followed up on `.agent/projects/001_DST/NOTE-compaction-stress-calibration-findings.md`, specifically the first three gaps from the live Qwen compaction stress calibration:

1. AI compaction appeared not to run.
2. Cache utilization was reported as zero.
3. Token estimate accuracy was unverified.

## Findings

### AI compaction was live, but runtime status undercounted it

The live profile had `compaction_ai` enabled and ordered before `compaction_structural`. The runtime pre-step chain does not short-circuit; later hooks see the prior hook's output.

The bug was in runtime status counting:

- Generated registry IDs are suffixed, for example `compaction_ai#0`.
- `runtime_status_counts_rec` only counted exact `stage.ext_id == "compaction_ai"`.
- Raw JSONL showed AI compaction events, but `MotokoRuntimeStatus` reported `compaction_ai_applied: 0`.

Fixed in `src/core/session.ail` by adding `is_compaction_ai_ext_id`, matching both `compaction_ai` and `compaction_ai#...`.

Added regression test:

- `test_runtime_status_counts_generated_compaction_ai_id`

### Cache reporting is provider/model dependent

The original Qwen calibration had zero cache read/create tokens. A later OpenRouter DeepSeek log showed cache-read tokens in the millions, so the cache telemetry path is not globally broken.

The latest Qwen heavy run still showed:

- `cache_read_input_tokens: 0`
- `cache_creation_input_tokens: 0`

This remains a provider/model behavior to confirm separately.

### Token estimation is now observable and undercounts Qwen/OpenRouter

Added `estimated_input_tokens` to `ProviderCallInfo` and the `provider_call_prepared` JSONL event. It is computed from the exact compacted payload with the existing `estimate_tokens_messages(compacted_msgs)` heuristic.

This lets live logs join:

- `provider_call_prepared.estimated_input_tokens`
- `thinking.input_tokens`

by `session_id` and `step`.

The latest Qwen heavy run, `.motoko/logfile/session_2026-07-09T07-49-32-948Z.jsonl`, showed systematic undercounting:

| Slice | Calls | Avg estimate / actual | Avg absolute error |
|-------|-------|-----------------------|--------------------|
| Before compaction | 42 | 0.776 | 22.4% |
| Compaction/retry window | 3 | 0.431 | 56.9% |
| After compaction | 5 | 0.533 | 46.7% |
| Overall | 50 | 0.731 | 26.9% |

Examples:

| Step | Estimated | Actual | Ratio |
|------|-----------|--------|-------|
| 41 | 184,083 | 228,616 | 0.805 |
| 42 | 37,085 | 82,541 | 0.449 |
| 54 | 18,604 | 32,390 | 0.574 |

Likely causes: provider chat serialization, role/tool-call structure, and non-content message overhead are not included in `content_chars / 4`.

## Code Changes

- `src/core/session.ail`
  - Count suffixed AI compaction extension IDs in runtime status.
  - Emit `estimated_input_tokens` in `ProviderCallPrepared`.
  - Add regression coverage for generated `compaction_ai#0` IDs.

- `src/core/phase_vocab.ail`
  - Add `estimated_input_tokens` to `ProviderCallInfo`.
  - Project it into schema-v1 `provider_call_prepared`.
  - Update golden tests and typed construction sites.

- `scripts/long_qwen_compaction_dst.ail`
  - Include estimate in projection strings.
  - Assert prepared calls include positive estimate telemetry.

- `.agent/projects/001_DST/NOTE-compaction-stress-calibration-findings.md`
  - Added 2026-07-09 follow-up section.
  - Corrected stale statements about AI compaction being disabled.
  - Documented tested fixes and the Qwen/OpenRouter estimator undercount.

## Verification

Ran and passed:

```sh
ailang check src/core/session.ail
ailang test src/core/session.ail
ailang check src/core/phase_vocab.ail
ailang test src/core/phase_vocab.ail
ailang check scripts/long_qwen_compaction_dst.ail
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
  --entry main scripts/long_qwen_compaction_dst.ail
```

The deterministic DST now emits `estimated_input_tokens` and reports nonzero `compaction_ai_applied` in runtime status.

## Latest Live Run Summary

Latest reviewed log:

- `.motoko/logfile/session_2026-07-09T07-49-32-948Z.jsonl`

Run summary:

- Steps executed: 55
- Final step: 54
- Input tokens: 5,046,227
- Output tokens: 18,428
- Raw compaction events: 26
- AI compaction events: 13
- Structural compaction events: 13
- Stage rejections: 0
- System prefix stable: count 1, chars 9,817, digest `sha256:4d5d9ec8ab4afddfa5406f5523e76e9d03a1618f5ea4744553a6f7d444440a6c`

Runtime-status snapshots can underrepresent raw compaction events if retry errors happen after the last status poll. The latest run had retry errors at steps 43-46 and 51 from OpenRouter upstream/provider issues.

## Remaining Work

- Calibrate token estimation for Qwen/OpenRouter. Current heuristic undercounts by about 27% overall and much more after compaction.
- Decide whether to use a provider/model-specific multiplier, structural overhead term, or a more faithful tokenizer-backed estimator.
- Confirm whether Qwen/OpenRouter can surface prompt cache tokens for this model, or document zero cache reads as expected behavior for this route.
- Run longer stress sessions if prefix stability beyond 55 steps still matters.
