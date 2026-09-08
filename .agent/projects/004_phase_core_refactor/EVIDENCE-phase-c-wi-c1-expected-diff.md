# Phase C WI-C1 expected diff: real payload digests

Date: 2026-07-03

WI-C1 intentionally replaces the Phase B interim provider-payload digest
(`pd-<message-count>-<byte-count>`) with the canonical payload digest
(`sha256:<64 lowercase hex>`). This is the only expected production byte change
before blessing `/tmp/phase_c_blessed`.

The digest canonicalizer applies the same `make[N] -> make[0]` normalization
that `scripts/phase_a_event_parity.sh` already applies to JSONL captures. This
keeps DP7 verifier feedback reproducible across direct and nested `make`
captures without changing emitted event bytes or provider messages.

## Expected-Diff Table

| Capture | Changed `provider_call_prepared` lines | Allowed change |
|---|---:|---|
| `smoke_phase_a_tool_parity.jsonl` | 2 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_compaction_chain.jsonl` | 1 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_compaction_full_loop.jsonl` | 4 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_cost_budget_full_loop.jsonl` | 23 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_dp7_gate.jsonl` | 6 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_ext_fixture_parity.jsonl` | 4 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_pending_full_loop.jsonl` | 4 | `payload_digest` value only: `pd-*` -> `sha256:*` |
| `smoke_v2_stream_parity.jsonl` | 1 | `payload_digest` value only: `pd-*` -> `sha256:*` |

No `provider_call_prepared` lines appear in `smoke_v2_handle.jsonl` or
`smoke_v2_hybrid.jsonl`.

## Verification

Candidate capture:

```bash
./scripts/phase_a_event_parity.sh /tmp/phase_c_digest_candidate
diff -ru /tmp/phase_b_blessed /tmp/phase_c_digest_candidate > /tmp/phase_c_wi_c1.diff
```

Guards:

```bash
rg 'provider_call_prepared.*payload_digest|payload_digest.*provider_call_prepared' /tmp/phase_c_wi_c1.diff
awk '/^[-+][{]/ && $0 !~ /"type":"provider_call_prepared"/ { print; bad=1 } END { exit bad }' /tmp/phase_c_wi_c1.diff
```

Additional normalization check:

```bash
perl -pe 's/"payload_digest":"[^"]+"/"payload_digest":"<digest>"/g'
diff -ru /tmp/phase_b_norm /tmp/phase_c_norm
```

The normalized directory diff is empty, proving event type, field set, field
order, model, counts, and line order are unchanged after replacing only
`payload_digest` values.
