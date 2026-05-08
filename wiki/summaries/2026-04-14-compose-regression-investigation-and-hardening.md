---
doc_type: short
full_text: sources/2026-04-14-compose-regression-investigation-and-hardening.md
---

This session diagnosed and hardened the Compose subagent against severe regressions manifesting as [[concepts/parse-loop]] and [[concepts/type-loop]] failures, 50-attempt exhaustion, and acceptance of shallow outputs. Key findings included: the author prompt path uses `build_author_prompt` + `callStreamResult`; `.meta.json` `prompt` is archival only, but had become identical to `task`, degrading observability; retry loop characteristics shifted from parse failures (prompt bloat from unbounded error accumulation) to type mismatches (effect-row issues). The primary hardening implementations were:

- **Snippet archival and sidecar metadata:** `.motoko-store/snippets` persistence and `.meta.json` per attempt, with clean field separation.
- **Metadata schema restoration:** `task` and `prompt` now hold distinct content; added compose-specific fields like `compose_id`, `attempt`, `intent`, `saved_at_unix_ms`.
- **Prompt compaction:** [[concepts/prompt-compaction]] via dedup-by-signature, recent-slice truncation, and per-block caps to prevent runaway growth.
- **Parse-loop reset strategy:** streak detection on parse signatures triggers context reset and skeleton regeneration, emitting `compose_retry_reset` telemetry.
- **Per-invocation archive key:** `req.id + now` avoids cross-run overwrite collisions.
- **Metadata diagnostic tool:** `scripts/analyze_compose_meta.py` to surface error-class distribution, prompt-size trends, and attempt progression.
- **Substantive-output gate:** [[concepts/output-quality-gate]] for `analyze`/`summarize` intents rejects shallow output below `AILANG_COMPOSE_MIN_OBSERVED_CHARS` and forces retries.
- **Targeted-edit retry mode:** retries can carry `previous_snippet` and `prefer_edit_fix` to minimize rewrites; reset conditions clear snippet for fresh skeleton.
- **Type-loop breaker:** added effect-row mismatch signatures (`type:effect_row_io_fs`, `type:effect_row`) with streak handling and corrective hints, plus `compose_retry_type_reset` telemetry.

Validation included repeated `ailang check` and `ailang test`. Measured impact: prompt size explosion reduced, parse signature dominance lowered, archive naming clarified. Remaining issues include occasional persistent type loops now targeted by the breaker, and free-text validators allowing weak output.

Follow-up candidates: deterministic validator generation for analysis intents, snippet similarity telemetry, and optional language‑backend flag. See also [[concepts/compose-subagent]], [[concepts/retry-loop]], [[concepts/metadata-sidecar]].