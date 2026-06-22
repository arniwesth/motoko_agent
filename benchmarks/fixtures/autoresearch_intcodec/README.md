# Autoresearch integer-codec fixture

A controlled planted-lever fixture for the autoresearch loop. **Deliberately
non-leaky**: this README, `manifest.txt`, and `candidate/codec.c` do not name the
winning technique or explain why the baseline is slow, so an agent optimizing the
candidate cannot read the answer out of the tree. The operator-side design notes
(technique name, citation, expected numbers, which lever is which) live in the
autoresearch handoff under `.agent/plans/Motoko-auto-research/`, not here.

## Task

`candidate/codec.c` implements an integer-array codec — `codec_encode` and
`codec_decode` — and may choose any on-wire byte format. The objective is to
**maximize decode throughput**. The shipped baseline is a straightforward
variable-length byte encoding; a materially faster decode strategy exists, beats
the baseline by a large factor, and transfers to the held-out corpus.

## Metric & gates

`throughput_mbps` (primary, **maximize**, noisy) = decoded payload (4 B/value)
MB/s of CPU time; `wall_ms` (secondary). Two hard gates, checked before any
METRIC is emitted:

- **Correctness**: `decode(encode(x))` must round-trip `x` exactly.
- **Compression**: total encoded size ≤ ⅞ of raw `4·n` (blocks raw-uint32
  storage and fixed-width-with-exceptions).

## Run

```bash
# TRAIN (what ar_run measures)
bash benchmarks/fixtures/autoresearch_intcodec/bench/benchmark.sh
# held-out TEST (operator-only, out of loop)
bash benchmarks/fixtures/autoresearch_intcodec/bench/grade_test.sh
# gate (build + canary correctness + anti-cheat + immutable)
bash benchmarks/fixtures/autoresearch_intcodec/bench/checks.sh
```

Point `INTCODEC_CANDIDATE=<path>` to grade a specific candidate file (the
autoresearch harness points it at the linked worktree).

## Phase-1 hand-written levers (`levers/`, off-limits)

Used by the model-free discipline test to drive known candidates through the
loop and assert correct keep/discard/transfer decisions. The mapping of each
lever to the technique it embodies is in the operator handoff (kept out of this
README so the answer is not readable in-tree). Expected loop decisions:

| File | TRAIN | TEST | Correct | Expected loop decision |
|------|-------|------|---------|------------------------|
| (baseline `candidate/codec.c`) | ~0.68 GB/s | ~0.68 GB/s | yes | reference |
| `noise.c` | ≈baseline | ≈baseline | yes | discard (within MAD) |
| `fast_decode.c` | ~23 GB/s | ~24 GB/s | yes | **keep + transfers** |
| `decoy_overfit.c` | ~23 GB/s | ≈baseline | yes | TRAIN-only; held-out exposes no transfer |
| `decoy_tailbug.c` | CORRECTNESS_FAIL | CORRECTNESS_FAIL | **no** | correctness gate blocks keep |

## Regenerate corpora / hashes

```bash
cd benchmarks/fixtures/autoresearch_intcodec
python3 harness/gen_corpus.py corpus/train 1337 "40000,30000,20000,16384,12000,8000,4096,2000,1000,257,63,7,3"
python3 harness/gen_corpus.py corpus/test  9001 "37501,25003,18001,13333,9001,5005,3003,1501,511,129,17,5,1"
find harness corpus bench levers manifest.txt README.md -type f | sort | xargs sha256sum > immutable.sha256
```
