# Autoresearch SIMD-scan fixture

A controlled planted-lever fixture for testing the autoresearch loop as a
*disciplined researcher* — it has a real, literature-discoverable optimization
lever, a sharp correctness oracle, and an informatively noisy primary metric.

It replaces the Polyglot warm-up's weakness: optimizing Motoko's own scaffolding
(prompt / deprecated tools) had no reliable headroom on a strong model, so no
candidate ever beat the baseline and the noise was degenerate timeout flicker.

## Task

`candidate/scan.c` records the indices of the four "special" HTML bytes
(`<`, `&`, `\r`, `\0`) in a buffer. Baseline is a scalar loop (~0.6 GB/s here).
The lever is a NEON/SWAR vectorized scan (~7-9 GB/s, ~10-14x), the simdjson
technique (arXiv:1902.08318) the Lemire blog post is based on.

## Metric

`throughput_mbps` (primary, **maximize**, noisy); `wall_ms` (secondary, minimize).
Correctness is a hard gate: the harness compares the candidate to a trusted
reference on every input and refuses to emit a metric on any mismatch.

## Run

```bash
# TRAIN (what ar_run measures)
bash benchmarks/fixtures/autoresearch_simdscan/bench/benchmark.sh
# held-out TEST (operator-only, out of loop)
bash benchmarks/fixtures/autoresearch_simdscan/bench/grade_test.sh
# gate (build + canary correctness + anti-cheat + immutable)
bash benchmarks/fixtures/autoresearch_simdscan/bench/checks.sh
```

Point `SIMDSCAN_CANDIDATE=<path>` to grade a specific candidate file (the
autoresearch harness points it at the linked worktree).

## Phase-1 hand-written levers (`levers/`, off-limits)

Used by the model-free discipline test to drive known candidates through the
loop and assert correct keep/discard/transfer decisions:

| File | TRAIN | TEST | Correct | Expected loop decision |
|------|-------|------|---------|------------------------|
| (baseline `candidate/scan.c`) | ~0.6 GB/s | ~0.6 GB/s | yes | reference |
| `noise.c` | ~baseline | ~baseline | yes | discard (within MAD) |
| `real_neon.c` | ~7 GB/s | ~9 GB/s | yes | **keep + transfers** |
| `decoy_overfit.c` | ~6 GB/s | ~baseline | yes | TRAIN-only; held-out exposes no transfer |
| `decoy_tailbug.c` | fast | fast | **no** | correctness gate blocks keep |

## Regenerate corpora / hashes

```bash
python3 harness/gen_corpus.py corpus/train 1337 "7,13,61,1024,4099,8192,16001,32768,49153,65521"
python3 harness/gen_corpus.py corpus/test  9001 "3,15,17,500,4096,9999,20011,40960,57343"
( cd benchmarks/fixtures/autoresearch_simdscan && \
  find harness corpus bench levers manifest.txt README.md -type f | sort | xargs sha256sum > immutable.sha256 )
```
