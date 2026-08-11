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
- Use a dedicated raw-content canonicalizer for the system-prefix digest. Do not reuse
  `payload_digest([Message])`: at current HEAD it normalizes message content through
  `digest_content` by replacing `make[1]`...`make[20]` with `make[0]`, which is useful for replay
  stability but is not byte-for-byte prompt integrity.
- Digest only the pinned system prefix, not the whole provider payload.
- Keep the field additive in schema-v1 JSON. Existing consumers should tolerate unknown fields.
- Assert digest stability in deterministic DST; use live logs as calibration evidence only.

## Non-Goals

- Do not log the full system prompt.
- Do not change compaction policy or hook behavior.
- Do not make live Qwen/OpenRouter calls part of CI.
- Do not replace `payload_digest`; it remains useful for whole-payload identity.
- Do not claim cryptographic impossibility of equality failure. The digest is practical live
  observability, with the normal SHA-256 collision caveat.

## Work Items

### WI-0 Re-ground

Read and confirm current contracts:

- `src/core/phase_vocab.ail`
  - `ProviderCallInfo`
  - `ProviderCallPrepared`
  - `to_schema_v1`
  - `payload_digest` and its canonicalization helpers, especially the current `digest_content`
    normalization
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

Add an exported pure helper for byte-level prefix hashing:

```ail
export pure func system_prefix_digest_for(msgs: [Message]) -> string
```

The helper should hash the messages it is handed using raw `content`, not `digest_content`.
Use length-framed fields like existing `frame(...)` to avoid ambiguous concatenation.

The canonical form should include:

- `role`
- raw `content`
- `tool_call_id`
- `tool_calls` count and call fields (`id`, `name`, `arguments`)

Do not strip or normalize substrings such as `make[12]`.

Update every construction site found by:

```bash
rg -n 'ProviderCallPrepared\\(|ProviderCallInfo|system_prefix_chars:' \
  src scripts packages .agent/projects/001_DST \
  --glob '!**/.ailang/**' --glob '!**/node_modules/**'
```

This includes golden tests/literals in `src/core/phase_vocab.ail` and any scripts that
construct or pattern-match the record.

Update `to_schema_v1(ProviderCallPrepared(...))` to emit:

```json
"system_prefix_digest": "sha256:..."
```

Verification:

```bash
ailang check src/core/phase_vocab.ail
ailang test src/core/phase_vocab.ail
```

Add or extend pure tests so:

- `system_prefix_digest_for([mk_msg("system", "make[1]")]) != system_prefix_digest_for([mk_msg("system", "make[2]")])`
- the digest has the `sha256:` shape
- the same input returns the same digest

### WI-2 Compute the digest at the send gate

File: `src/core/session.ail`

At the existing `ProviderCallPrepared` emit site, compute the digest from `split.pinned`.

Use the new raw-content helper from `phase_vocab`, not `payload_digest`.

Then store:

```ail
system_prefix_digest: system_prefix_digest_for(split.pinned)
```

Do not compute this from `compacted_msgs` unless source review shows `split.pinned` is unavailable.
The point is to fingerprint the pinned prefix that `seal_compacted_payload` reattaches after the
compactor chain.

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
- fail if any `ProviderCallPrepared` has an empty or malformed `system_prefix_digest`

Keep existing assertions:

- `system_prefix_count >= 1`
- `system_prefix_chars > 0`
- `payload_digest` non-empty
- `system_prefix_digest` non-empty and shaped like `sha256:<hex>`
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

If the file has no `compaction_extension` events, the run did not exercise post-compaction digest
stability; treat it as profile/provider evidence only. If `system_prefix_digest` is missing, the
log was produced before this observability change and cannot answer the digest question.

## Acceptance Criteria

- `provider_call_prepared` includes `system_prefix_digest`.
- The digest is stable for unchanged system-prefix bytes and changes when raw system-prefix content
  changes, including content that `payload_digest` currently normalizes.
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
