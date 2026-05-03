# 2026-04-14 Compose Regression Investigation And Hardening

## Context
This session focused on diagnosing severe Compose subagent degradation (frequent AILANG syntax/type failures, 50-attempt exhaustion, and weak/partial "success" outcomes) and implementing targeted hardening in the compose extension.

Primary concerns raised:
- potential regression in AILANG system prompt usage
- snippet archival regressions (`.motoko-store` writes and `.meta.json` sidecars)
- metadata quality regression (`task` and `prompt` accidentally identical)
- repeated retry loops with near-identical failures
- weak successful runs being accepted despite shallow analysis output

## Key Findings During Investigation

1. Prompt usage path was confirmed:
- The subagent prompt sent to model comes directly from `build_author_prompt(...)` + `callStreamResult(...)`.
- `.meta.json` `prompt` is archival/debug and is not read back into generation.

2. Regression confirmed in metadata:
- `task` and `prompt` had become identical (both using intent text), reducing observability and making it harder to inspect true author conditioning.

3. Major loop characteristics observed in metadata:
- Earlier run: heavy parse-loop (`PAR_UNEXPECTED_TOKEN`, `PAR_NO_PREFIX_PARSE`) with huge prompt growth across attempts.
- Prompt bloat was caused by unbounded accumulation of prior error text.
- Later run: transformed into persistent type-loop (effect-row mismatch), still repetitive.

4. Success-gating gap identified:
- Compose could accept a syntactically valid run that produced only shallow/progress-like output for analysis tasks.
- With free-text `expected_output`, validator stayed inconclusive and did not force retries.

## Implementations Completed

### A) Snippet archival and sidecar metadata persistence
Files:
- `src/core/ext/compose/store.ail`
- `src/core/ext/compose/compose.ail`

Changes:
- Added snippet persistence in `.motoko-store/snippets` for attempts.
- Added sidecar `.meta.json` writing alongside `.ail` snippets.
- Ensured sidecar JSON writing keeps one field per line (readable multiline format).

### B) Metadata schema restoration and readability
File:
- `src/core/ext/compose/compose.ail`

Changes:
- Restored meaningful separation:
  - `task` = task-level objective
  - `prompt` = full generated author prompt (system rules + objective + guidance + retry context)
- Updated metadata generation to include both legacy and compose context fields:
  - `timestamp`, `model`, `task`, `prompt`, `caps`, `outcome`, `check_errors`, `exit_code`
  - `compose_id`, `attempt`, `step`, `intent`, `intent_kind`, `saved_at_unix_ms`

### C) Prompt compaction to prevent retry-context bloat
File:
- `src/core/ext/compose/prompts.ail`

Changes:
- Added compaction pipeline for prior errors used in author prompt:
  - keep only recent slice
  - dedupe by signature
  - cap count of unique error blocks
  - truncate each block
- Result: prompt length growth became bounded and significantly smaller across retries.

### D) Parse-loop reset strategy
File:
- `src/core/ext/compose/compose.ail`

Changes:
- Added retry signature classification for parse failures.
- Added streak detection on repeated parse signatures.
- On parse-stuck conditions:
  - reset retry context to minimal corrective packet
  - clear targeted repair snippet for a clean skeleton regeneration
  - emit reset telemetry event (`compose_retry_reset`)

### E) Per-invocation snippet archive key (avoid cross-run overwrite)
File:
- `src/core/ext/compose/compose.ail`

Changes:
- Introduced per-invocation archive key (`req.id + now`) and threaded it through storage calls.
- This avoids collisions when compose IDs repeat across sessions (e.g., repeated `c1`).

### F) Metadata diagnostics tooling
File:
- `scripts/analyze_compose_meta.py`

Added a script to inspect `.meta.json` attempts and surface:
- outcome distribution
- error-class distribution (parse/type/runtime/guard/none)
- prompt-size and prompt-feature trends
- per-compose attempt progression
- common parse markers and hint signatures

This script was used repeatedly in-session to quantify regressions and validate hardening impact.

### G) Substantive-output gate for analyze/summarize completion
File:
- `src/core/ext/compose/compose.ail`

Changes:
- Added post-run quality gate before finalization for `analyze`/`summarize` intents.
- Uses normalized observed output length to prevent accepting shallow/progress-only stdout.
- New env knob:
  - `AILANG_COMPOSE_MIN_OBSERVED_CHARS` (default 180)
- If insufficient:
  - mark attempt metadata as `insufficient_output`
  - force retry with explicit corrective guidance

### H) Targeted-edit retry mode (instead of full rewrites)
Files:
- `src/core/ext/compose/prompts.ail`
- `src/core/ext/compose/author_loop.ail`
- `src/core/ext/compose/compose.ail`

Changes:
- Added repair-mode prompt fields:
  - `previous_snippet`
  - `prefer_edit_fix`
- Retry pipeline now carries `last_snippet` in `NeedRetry` state.
- Subsequent retries can instruct subagent to apply minimal local edits to the previous snippet.
- Parse/type resets can intentionally clear snippet context for fresh skeleton fallback.
- Added telemetry signal for retry mode (`compose_retry_mode` with targeted-edit true/false).

### I) Type-loop breaker (effect-row mismatch)
File:
- `src/core/ext/compose/compose.ail`

Changes:
- Extended retry signature detection for effect-row mismatch:
  - `type:effect_row_io_fs`
  - `type:effect_row`
- Added type-stuck streak handling analogous to parse resets.
- Added type-specific corrective hint focused on effect-row alignment and placement of effectful calls.
- Added telemetry event:
  - `compose_retry_type_reset`

## Validation Performed

Repeatedly executed and passed after each patch cluster:
- `ailang check src/core/ext/compose/prompts.ail`
- `ailang check src/core/ext/compose/author_loop.ail`
- `ailang check src/core/ext/compose/compose.ail`
- `ailang test src/core/ext/compose/compose_test.ail`
- `ailang test src/core/ext/compose/validator_test.ail`

## Measured Impact (from analyzer runs)

Observed improvements after hardening:
- Prompt-size explosion was significantly reduced (bounded growth instead of runaway accumulation).
- Repeated parse signature dominance decreased in later runs.
- Archive naming changed to per-invocation hash key, reducing overwrite ambiguity.

Remaining issue observed later:
- Some sessions still fall into repeated type failures (now explicitly targeted by type-loop reset patch).
- In at least one later run, output quality improved materially but remained partial due to vague task + free-text validator constraints.

## Operational Notes

- The metadata `prompt` now reflects the composed author prompt template, improving debugging quality.
- With author tools enabled, runtime prompt can still include turn transcript dynamics not fully represented in sidecar snapshot.
- Free-text `expected_output` allows inconclusive validation; stronger structured validators (`kind: contains_all` / `kind: certificate`) remain recommended for stricter completion control.

## Follow-up Candidates

1. Add explicit deterministic validator generation for common analysis intents.
2. Add snippet similarity telemetry to detect "same code over and over" directly.
3. Consider optional language backend flag (`ailang|python`) as a future separate implementation track (not implemented here).

