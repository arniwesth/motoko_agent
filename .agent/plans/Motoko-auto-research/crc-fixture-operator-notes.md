# Operator notes: autoresearch_crc (pretraining-novel fixture)

**Operator-only. Do NOT copy any of this into the fixture tree** — the fixture
(`benchmarks/fixtures/autoresearch_crc/`) is deliberately non-leaky: nothing
in-tree names the fast method or explains why the baseline is slow. This file
holds the answer. See also [[autoresearch-novelty-cold-check]] and
[[autoresearch-fixture-leak-discipline]] in memory.

## What this fixture tests

Third probe of "does the literature scout add value when the winning technique is
NOT in the model's weights?" simdscan (simdjson) and intcodec (Stream VByte) both
failed novelty — the model produced the winner cold, so the scout was theater.
This is the **first candidate to survive the cold screen.**

## The method (the answer)

- **Winner: carry-less-multiply ("folding") CRC** via the ARMv8 PMULL intrinsics
  (`vmull_p64` / `vmull_high_p64`), à la Intel "Fast CRC Computation Using
  PCLMULQDQ" (generic-polynomial variant) — adapted to the CUSTOM reflected
  polynomial `0xB2A8D703`. The fold reduces 16+-byte blocks with two carry-less
  multiplies by precomputed constants `k = x^n mod P` (in the reflected domain),
  then a final Barrett reduction to 32 bits.
- **Why it's the barrier**: the technique is well-known, but the **folding
  constants must be derived for the custom polynomial** (`x^n mod P` over GF(2),
  with the reflected-domain bit-shift correction) — they cannot be copied from
  zlib (which hardcodes them for the standard polynomial). The hardware `crc32`
  instruction is useless here (it only supports the standard CRC-32/CRC-32C
  polynomials), so there is no one-instruction shortcut.
- **Model-known plateau**: slicing-by-8 (8 tables, branchless 8-byte step). A
  frontier model produces this readily; it is correct and ~3–6× the byte-table
  baseline, but well below folding.

## Cold-screen evidence (the reason we built this)

`.motoko/ar_bench_scratch/crc_coldcheck.py` (+ `crc_verify*.c`). 3/3 cold samples
(1×temp0.2, 2×temp0.7), each compile-verified against the reference — ALL WRONG:
- always reaches for PMULL folding (even names the Intel generic-poly paper);
- always fails the custom-poly folding constants (fabricates them, or botches a
  programmatic derivation: folding path wrong on every ≥16-byte buffer);
- when it retreats to a table, it fabricates the table wrong too (0 matches).
This is the "knows OF the method, can't DO it cold" regime — exactly where a
scout that fetches the constant-derivation method could add value.

## Measured numbers (pre-registration baseline)

`gcc -O2 -march=armv8-a+crypto`, this aarch64 core, bytes/sec CPU time, median:

| Lever (`levers/…`) | TRAIN | TEST | meaning |
|---|---|---|---|
| baseline `candidate/crc.c` (byte table) | ~0.38 GB/s | ~0.38 GB/s | reference / starting point |
| `noise.c` | ≈baseline | — | within MAD → discard |
| `slice8.c` (slicing-by-8) | ~0.9–2.1 GB/s | ~2.1 GB/s | **model-known plateau, keep+transfers** |
| `decoy_wrong.c` (corrupted slice table) | fast | — | CORRECTNESS_FAIL → blocked |
| carry-less-multiply folding (NOT shipped) | — | — | the ceiling, several× above slice8 (polynomial-independent; ~5–15 GB/s typical for PMULL CRC) |

Note: throughput is the noisy primary — slice8 swung 0.9–2.1 GB/s across runs.

**Why no folding lever is shipped:** hand-deriving a *correct* reflected-domain
fold for the custom polynomial is precisely the hard step under test — I hit the
same constant-derivation wall the model did. Shipping a possibly-buggy folding
lever would be worse than none. The experiment MEASURES the reachable ceiling;
the headroom (folding ≫ slice8) is well established for PMULL CRC and is
polynomial-independent. If a verified folding reference is wanted later, derive
constants programmatically (`x^n mod P` via the reflected `mulx` step — see
`.motoko/ar_bench_scratch/fold_dev.c`, layer-1 verified) and validate end-to-end
against `crc_ref`.

## Pre-registered experiment

- **Run arm A first** (`crc_autonomy_noscout_task.md`). Decision rule
  (pre-register before peeking): "scout adds value" iff arm-C median TEST
  throughput exceeds arm-A median by more than the within-arm spread, one-sided
  Mann-Whitney α=0.05.
- **The key open question / caveat:** the cold screen is one-shot, but arm A is
  ITERATIVE (≤10 iters + the sharp exact-CRC gate). Realistically arm A will:
  (a) reach the slice-by-8 plateau easily (once a hardcoded table fails the gate
  it will generate the table in code — trivial and correct), and (b) MAYBE grind
  to folding through gate-feedback iteration, or maybe not. If arm A plateaus at
  slice-by-8 and arm C (scout) breaks through to folding, that is the positive
  result. If arm A reaches folding cold, report the null. This uncertainty is
  why it is worth running — unlike the two foregone nulls.
- **Seeds/power:** N=4 had ~zero power on simdscan. If the effect is large (arm A
  stuck at slice8, arm C at folding) N≈6 suffices; if arm A sometimes reaches
  folding, plan N≈10. ~40 min/seed × 2 arms × N.

## Residual leak surface (decide before running)

Non-leaky in names/prose, BUT `levers/slice8.c` is a working ~5× plateau and
`levers/` is readable in-worktree (the prompt invites reading harness/corpus). It
does NOT reveal the folding ceiling, so the scout-relevant gap is protected — but
for zero residual leak, delete/relocate `levers/` from the agent's run worktree
and re-hash `immutable.sha256` there (levers are only needed for the operator-side
Phase-1 discipline test, not the agent run).

## Run mechanics (carried from prior sessions)

- Model `openrouter/deepseek/deepseek-v4-pro`; worktree `default` profile
  governs (max_steps=50), `MODEL=` only sets the string.
- Build is `gcc -O2 -march=armv8-a+crypto` (in `bench/lib.sh`) so the candidate
  can use `vmull_p64`; plain `-O2` would NOT compile the carry-less-multiply
  intrinsics. `+crypto` does not enable the hardware `crc32` instruction's
  polynomials (and those are useless for the custom polynomial regardless).
- Disable `exa_search` for arm A by stripping it from the worktree default
  profile's `extensions.order` (CORE_EXT_ORDER only adds); verify via
  `session_start` `loaded_extensions`.
- `duckdb` required by `ar_init`; confirm `which duckdb` on a fresh worktree.
- Strip the design comment before passing a prompt:
  `awk 'f{print} /^-->/{f=1}' <prompt>.md`.
- Grade kept candidate on held-out TEST:
  `CRC_CANDIDATE=<WT>/…/candidate/crc.c bash …/bench/grade_test.sh`.
