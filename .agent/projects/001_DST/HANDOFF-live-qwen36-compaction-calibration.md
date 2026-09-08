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
- Post-compaction `provider_call_prepared.system_prefix_digest` stability.

Provider availability, prose quality, routing, pricing, and network behavior are calibration
evidence only. They must not become the CI oracle.

System-prefix digest check for logs produced after 2026-07-08:

```bash
latest=$(ls -t .motoko/logfile/*.jsonl | head -1)
jq -r '
  select(.type=="provider_call_prepared") |
  [.step, .system_prefix_count, .system_prefix_chars, .system_prefix_digest] | @tsv
' "$latest"
```

Post-compaction stability:

```bash
latest=$(ls -t .motoko/logfile/*.jsonl | head -1)
first=$(jq -r 'select(.type=="provider_call_prepared" and .step==0) | .system_prefix_digest' "$latest")
first_compaction_step=$(jq -r 'select(.type=="compaction_extension") | .step' "$latest" | head -1)

test -n "$first"
test -n "$first_compaction_step"

jq -s -e --arg first "$first" --argjson first_step "$first_compaction_step" '
  [
    .[]
    | select(.type=="provider_call_prepared" and .step >= $first_step)
    | select(.system_prefix_digest != $first)
  ] | length == 0
' "$latest"
```
