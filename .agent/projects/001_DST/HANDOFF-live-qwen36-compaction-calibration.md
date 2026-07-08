# Live Qwen3.6 Compaction Calibration Handoff

Date: 2026-07-08

This is optional calibration evidence only. The standing oracle is
`scripts/long_qwen_compaction_dst.ail`, run offline by `make compaction_dst` with
`MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json`.

Manual command:

```bash
make live_qwen36_compaction_calibration
```

Override the task text with `QWEN36_COMPACTION_LIVE_TASK="..."`.

Evidence to archive:

- UTC timestamp of the run.
- Profile: `qwen36-compaction-live`.
- Agent model: `openrouter/qwen/qwen3.6-35b-a3b`.
- `compaction_ai` model: `openrouter/qwen/qwen3.6-35b-a3b`.
- Log path under `.motoko/logfile/` or an archived evidence path.
- Summary counts of observed compaction-related events.

Provider availability, prose quality, routing, pricing, and network behavior are calibration
evidence only. They must not become the CI oracle.
