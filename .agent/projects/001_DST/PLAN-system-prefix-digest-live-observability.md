# Plan: system-prefix digest for live compaction observability

Date: 2026-07-08
Scope: `001_DST`
Status: Proposed

## Goal

Add a stable `system_prefix_digest` field to `provider_call_prepared` so live logs can prove the
system prompt bytes remain unchanged across compaction. This is an observability enhancement to the
existing send-gate event, not a new compaction policy.

The motivating live calibration run showed compaction on steps 34-49 and stable
`system_prefix_count=1` / `system_prefix_chars=16229`. That proves a non-empty prefix of the same
size survived, but not byte-for-byte identity. A digest over the pinned system-prefix messages closes
that gap without logging prompt contents.

## Decisions

- Add `system_prefix_digest` to `ProviderCallInfo`.
- Compute it from the pinned system-prefix messages at the existing `ProviderCallPrepared` emit site.
- Use the same digest style as existing payload digests: `sha256:<hex>`.
- Digest only the pinned system prefix, not the whole provider payload.
- Keep the field additive in schema-v1 JSON. Existing consumers should tolerate unknown fields.
- Assert digest stability in deterministic DST; use live logs as calibration evidence only.

## Non-Goals

- Do not log the full system prompt.
- Do not change compaction policy or hook behavior.
- Do not make live Qwen/OpenRouter calls part of CI.
- Do not replace `payload_digest`; it remains useful for whole-payload identity.

## Work Items

### WI-0 Re-ground

Read and confirm current contracts:

- `src/core/phase_vocab.ail`
  - `ProviderCallInfo`
  - `ProviderCallPrepared`
  - `to_schema_v1`
  - existing golden tests/literals
- `src/core/session.ail`
  - `CallModel` arm
  - `split_for_compaction`
  - `ProviderCallPrepared` construction
  - current `payload_digest` helper/use
- `scripts/long_qwen_compaction_dst.ail`
  - normalized projection for `ProviderCallPrepared`
  - post-compaction provider-call assertions

Baseline checks:

```bash
ailang --version
make compaction_dst
```

Stop if baseline is red.

### WI-1 Add the schema field

File: `src/core/phase_vocab.ail`

Add `system_prefix_digest: string` to `ProviderCallInfo`.

Update every local literal construction in tests/goldens.

Update `to_schema_v1(ProviderCallPrepared(...))` to emit:

```json
"system_prefix_digest": "sha256:..."
```

Verification:

```bash
ailang check src/core/phase_vocab.ail
ailang test src/core/phase_vocab.ail
```

### WI-2 Compute the digest at the send gate

File: `src/core/session.ail`

At the existing `ProviderCallPrepared` emit site, compute the digest from `split.pinned`.

Use a canonical serialization that is stable and role/content-aware. It should include at least:

- `role`
- `content`
- `tool_call_id`
- `tool_calls` count or full call fields

System-prefix messages should not normally contain tool calls, but the digest helper should be
structurally honest rather than assuming that forever.

Example shape:

```text
role|tool_call_id|tool_call_count|content\n...
```

Then store:

```ail
system_prefix_digest: digest_messages(split.pinned)
```

Verification:

```bash
ailang check src/core/session.ail
```

### WI-3 Strengthen deterministic DST

File: `scripts/long_qwen_compaction_dst.ail`

Update the normalized replay projection to include `system_prefix_digest`.

Add an invariant:

- capture the first `provider_call_prepared.system_prefix_digest`
- every later `provider_call_prepared` has the same digest
- this must hold across all steps, including after `compaction_ai` stages apply

Keep existing assertions:

- `system_prefix_count >= 1`
- `system_prefix_chars > 0`
- `payload_digest` non-empty
- Qwen model label
- applied compaction followed by prepared call and provider result

Verification:

```bash
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang check scripts/long_qwen_compaction_dst.ail

MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
  scripts/long_qwen_compaction_dst.ail
```

### WI-4 Gate verification

Run:

```bash
make compaction_dst
```

Expected:

- all existing compaction scenarios stay green
- long Qwen deterministic scenario reports the same normalized projection on replay
- no live provider call is made

### WI-5 Live-log check recipe

Update `.agent/projects/001_DST/HANDOFF-live-qwen36-compaction-calibration.md` with a log check:

```bash
latest=$(ls -t .motoko/logfile/*.jsonl | head -1)

jq -r '
  select(.type=="provider_call_prepared") |
  [.step, .system_prefix_count, .system_prefix_chars, .system_prefix_digest] | @tsv
' "$latest"
```

Post-compaction stability check:

```bash
latest=$(ls -t .motoko/logfile/*.jsonl | head -1)
first=$(jq -r 'select(.type=="provider_call_prepared" and .step==0) | .system_prefix_digest' "$latest")

jq -e --arg first "$first" '
  [
    select(.type=="provider_call_prepared" and .step >= 34)
    | select(.system_prefix_digest != $first)
  ] | length == 0
' "$latest"
```

Use the actual first compaction step from the log when it is not 34:

```bash
jq -r 'select(.type=="compaction_extension") | .step' "$latest" | head -1
```

## Acceptance Criteria

- `provider_call_prepared` includes `system_prefix_digest`.
- The digest is stable for unchanged system-prefix bytes.
- Deterministic long Qwen DST asserts digest stability across compactions.
- `make compaction_dst` remains green.
- Live calibration logs can be checked for post-compaction digest stability with `jq`.
- No full system prompt content is logged.
- No live provider call is added to CI.

## Rollback

- Remove `system_prefix_digest` from `ProviderCallInfo`.
- Remove schema-v1 projection field and updated goldens.
- Remove session-side digest computation.
- Remove deterministic DST digest assertions.
- Remove live-log recipe additions.
