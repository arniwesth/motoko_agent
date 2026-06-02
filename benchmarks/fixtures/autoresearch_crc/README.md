# Autoresearch checksum fixture

A controlled planted-lever fixture for the autoresearch loop: a real, large
throughput headroom behind a sharp exact-match correctness gate.

**Deliberately non-leaky**: this README, `manifest.txt`, and `candidate/crc.c`
do not name the fast method or explain why the baseline is slow. The operator-side
design notes (method, expected numbers, which lever is which) live in the handoff
under `.agent/plans/Motoko-auto-research/`.

## Task

`candidate/crc.c` implements `uint32_t crc_fast(const uint8_t *data, size_t len)`,
which must equal a trusted reference for every input — a reflected 32-bit CRC
with a fixed custom polynomial (`0xB2A8D703`), init `0xFFFFFFFF`, final xor
`0xFFFFFFFF` (the bit-by-bit reference is in `harness/main.c`). The objective is
to **maximize throughput** on large buffers. Baseline is a correct table CRC; a
materially faster correct implementation exists and transfers.

## Metric & gate

`throughput_mbps` (primary, **maximize**, noisy) = bytes/sec of CPU time, median
over rounds; `wall_ms` (secondary). **Correctness is a hard gate**: any buffer
whose `crc_fast` differs from the reference prints `CORRECTNESS_FAIL` and emits no
METRIC.

## Run

```bash
bash benchmarks/fixtures/autoresearch_crc/bench/benchmark.sh    # TRAIN (ar_run)
bash benchmarks/fixtures/autoresearch_crc/bench/grade_test.sh   # held-out TEST (operator-only)
bash benchmarks/fixtures/autoresearch_crc/bench/checks.sh       # build + canary + anti-cheat + immutable
```

Point `CRC_CANDIDATE=<path>` to grade a specific candidate file. Build is
`gcc -O2 -march=armv8-a+crypto`.

## Phase-1 hand-written levers (`levers/`, off-limits)

For the model-free discipline test (keep/discard/transfer/correctness decisions).
The mapping of each lever to the technique it embodies is in the operator handoff.
Measured here (throughput is noisy):

| File | TRAIN | Correct | Expected loop decision |
|------|-------|---------|------------------------|
| (baseline `candidate/crc.c`) | ~0.38 GB/s | yes | reference |
| `noise.c` | ≈baseline | yes | discard (within MAD) |
| `slice8.c` | ~0.9–1.8 GB/s | yes | **keep + transfers** (a strong plateau, not the ceiling) |
| `decoy_wrong.c` | fast | **no** | correctness gate blocks keep |

The true ceiling is several× above `slice8.c`; it is intentionally not shipped as
a lever (the ceiling technique is documented only in the operator notes). The
experiment measures the reachable ceiling.

## Regenerate corpora / hashes

```bash
cd benchmarks/fixtures/autoresearch_crc
python3 harness/gen_corpus.py corpus/train 1337 "1048576,524288,262144,131072,65537,32768,4096,1023,127,17,1"
python3 harness/gen_corpus.py corpus/test  9001 "786433,393217,196609,98304,49999,16385,4095,1000,63,15,7"
find harness corpus bench levers manifest.txt README.md -type f | sort | xargs sha256sum > immutable.sha256
```
