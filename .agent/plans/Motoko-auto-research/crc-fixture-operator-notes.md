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

## Results

### Arm A (no scout) — seed 1 (2026-06-02)
- Log `.motoko/ar_bench_scratch/crc_noscout_seed1.jsonl`; worktree
  `/workspaces/motoko_agent_crc_wt` (branch autoresearch/crc-noscout, baseline
  dcaf70d); `loaded_extensions` confirms exa_search ABSENT.
- **Kept: slicing-by-16** (32 bytes/iter, 16 tables). Held-out TEST
  **4512 MB/s** (~12× baseline 385, ~2.4× slice-by-8), exact on all 11 TEST
  buffers, transfers. ar_run trajectory: 386 → 2132 → 4512 → (4579, 4549, 2249
  discarded).
- **Did NOT reach the folding ceiling**, but DID attempt it hard: 207
  PMULL/Barrett mentions, 8 CORRECTNESS_FAILs, 11 compile errors. It even got the
  Barrett *constant* right (self-checked "direct = Barrett, match=YES") but stalled
  on the reflected fold *formula*: its own note — "Barrett == longdiv but both !=
  ref, the fold formula is wrong." Discarded all folding attempts, settled on a
  table method. This is exactly the predicted "knows folding, can't land it cold"
  behavior, and matches the cold screen (and the operator's own difficulty).
- **Interpretation:** arm A's plateau ≈ 4512 MB/s (slice-16), folding ceiling
  still open → genuine room for the scout (arm C) to demonstrate value by
  fetching the reflected-fold derivation / a working reference. N=1 so far;
  need the arm-A distribution + arm C to conclude.

### Arm C (scout) — seed 1 (2026-06-02) — TIMED OUT, but highly informative
- Log `.motoko/ar_bench_scratch/crc_scout_seed1.jsonl`; same worktree reset to
  baseline dcaf70d; `loaded_extensions` confirms exa_search PRESENT.
- **rc=124 (timeout at 2400s). No keep-commit; candidate left at baseline (379
  MB/s).** It NEVER entered the autoresearch FSM (no real ar_init/ar_run) — it
  spent the entire 40 min in the scout + manual implement/test phase (only
  BashExec ×14 + ReadFile ×10 dispatched; reached step 12).
- **The scout found the exact missing piece.** It fetched `corsix/fast-crc32` (a
  generator that emits ARM PMULL *folding* CRC for arbitrary polynomials) and
  `mattsta/crcspeed`, generated `crc_simd.c` from it, and its last command was a
  Python script "compute PMULL folding constants for reflected CRC" — deriving
  the custom-poly constants arm A could not. It timed out mid-implementation.
- **Binding constraint = wall-clock budget, not capability.** The scout supplied
  the resource (a folding-constant generator for arbitrary polys) that arm A
  lacked; fetch+adapt+codegen just didn't fit in 40 min. **Methodological fix:**
  the scout arm legitimately needs a larger timeout (>= 3600s) to fetch, adapt,
  and still run the benchmark loop. For a fair comparison both arms must share
  the same (larger) budget across N seeds — and note arm A, given more time,
  might also push past slice-16 toward folding, so re-run BOTH at the new budget.
- Also observed: the agent took "scout first, then ar_init" very literally and
  over-invested in research before any measurement. Consider a prompt nudge to
  get a baseline ar_run in early, then scout — without leaking the method.

### Arm C (scout) — seed 1 RERUN at 5400s (2026-06-03) — the key result
- Log `.motoko/ar_bench_scratch/crc_scout_seed1_t5400.jsonl`. rc=0 (hit
  max_steps=50, not timeout). This time it fully ran the loop: 3 ar_init, 30
  ar_run, 30 ar_log, 9 ar_notes; throughput trajectory 383 → 2137 → 3687 → 5195
  → 5363 → 5582.
- **Kept run #10: "Slicing-by-32 with NEON loads" (a TABLE method, NOT folding).**
  Held-out TEST **5572 MB/s** (~14.5× baseline, ~1.24× arm A's slice-16), exact,
  transfers. Kept candidate has ZERO vmull/pmull/fold.
- **Did NOT land folding, despite the scout doing its job.** It fetched the exact
  right resource (`corsix/fast-crc32`, a PMULL-folding generator for arbitrary
  polys), computed folding constants, wrote test_pmull3.c — 66 vmull mentions —
  but no folding candidate ever passed correctness (no ar_run exceeded ~5.6 GB/s;
  folding would be >10). It discarded all folding attempts and kept a wider NEON
  slicing table.
- **Headline interpretation (refines the thread).** For simdjson/Stream VByte the
  scout was theater because the technique was IN-WEIGHTS. For CRC folding the
  scout is NOT theater — it surfaced a genuinely-needed external resource arm A
  never had — yet it STILL did not change the outcome, because the binding
  constraint was **correctly IMPLEMENTING reflected custom-poly folding**, not
  knowing about / finding it. Both arms fell back to wide-slicing tables. So this
  is trending to a THIRD null on "does the scout reach an otherwise-unreachable
  ceiling," via a NEW mechanism: retrieval succeeded, application failed.
- **Caveats / not yet conclusive:** N=1 per arm and UNEQUAL budgets (arm A 40 min
  → slice-16 4512; arm C 90 min → slice-32 5572). The 5572-vs-4512 gap is plausibly
  table-tuning + extra time, not a scout effect. For a rigorous verdict, run BOTH
  arms at the SAME budget (>= 5400s) across N seeds and compare; also note the
  agent could not land folding even WITH the reference, so the fixture's ceiling
  may be effectively unreachable by this model in this harness — which itself is
  the finding.

### WHY arm C didn't land folding (deep-dive into the 5400s log)
Decisive evidence that the binding constraint is *implementation correctness*, not
retrieval or knowledge:
- **Retrieval fully succeeded.** It fetched `corsix/fast-crc32` + `mattsta/crcspeed`
  (real PMULL/PCLMULQDQ reflected-CRC references) and its reasoning explicitly
  states "for a reflected CRC32, the folding is different from the non-reflected
  case" — it understood the subtlety.
- **It built and TESTED a real PMULL fold** (`test_pmull2.c`/`test_pmull3.c`),
  derived constant sets (k1/k2/Barrett mu — recomputed several times, values shifting
  between attempts → unsure of the convention), compiled, and ran vs the reference.
- **The fold produced WRONG output:** `test_pmull3.c` → `MISMATCH len=16 ref=80f6f3e4
  cand=99298b3f` (and every length; grossly wrong, not near-misses). Its own summary:
  "PMULL folding: Constants derived but folding logic was incorrect; needs more
  iterations to tune."
- **It consciously reverted under budget pressure:** "given time constraints, let me
  revert to slice-32 which is known-correct," hedging keeps on the slicing ladder.
- **The cap was STEPS, not time:** finish_reason=stop, steps_executed=50,
  duration 35.9 min (timeout was 90 min). So more wall-clock would NOT have helped;
  the lever is `max_steps` (worktree default = 50) and/or the agent choosing to spend
  steps debugging folding rather than consolidating slicing.
- Independent check (verified GF(2) mulx ladder): the agent's x^64=0x86850938,
  x^128=0xA65887D1 do not sit on the straightforward x^n mod P ladder — suggesting
  the reflected-clmul constant *representation* was itself part of the error
  (confounded by clmul <<1/bit-reversal conventions, so the empirical MISMATCH is the
  decisive proof, not this).

**Refined conclusion.** Across all conditions — cold screen (3/3), arm A (no scout,
40 min), arm C (scout + reference + 50 steps) — **no run produced a correct reflected
custom-poly fold (0/5).** Retrieval removed the "what/where" barrier but NOT the
"get the finicky reflected fold exactly right" barrier. Whether this is a hard STEP-
budget limit (agent claims "needs more iterations") or a capability ceiling is the
open question — testable by raising `max_steps` (e.g. 100) and re-running, ideally
with a prompt nudge to spend steps on the fold rather than hedging on slicing.

### Arm C (scout) at max_steps=100 (2026-06-03) — VERDICT: capability, not budget
- Log `.motoko/ar_bench_scratch/crc_scout_seed1_steps100.jsonl`. finish=stop,
  **steps_executed=82 (cap 100 — it stopped VOLUNTARILY with 18 steps to spare)**,
  78 min. Kept run #10 = slicing-by-32, 64B-unrolled, `__builtin_memcpy` loads.
  TEST **5495 MB/s** (~14.5×). Folding count in kept candidate = 0. 13
  CORRECTNESS_FAILs during the run.
- **The agent's own final account is decisive:** "PMULL/CLMUL folding: the
  polynomial fold invariant was mathematically verified, but the **Barrett
  reduction from the 64-bit folded state to the final 32-bit CRC could not be
  correctly derived for this custom polynomial (0xB2A8D703). Three separate PMULL
  implementations resulted in CORRECTNESS_FAIL.**" (The mid-run "correct!"/"PASS"
  side-tests were the fold *invariant*/constants — not the full CRC, which the
  final Barrett reduction broke.)
- **This falsifies the "needs more iterations / step budget" hypothesis.** Given
  2× the steps AND the right reference (corsix) AND explicit understanding of the
  reflected case, it STILL could not implement the reflected custom-poly fold —
  and stopped voluntarily rather than spend its remaining budget, having judged 3
  failed Barrett-reduction attempts as a dead end. The binding constraint is
  **implementation capability** (correctly deriving the reflected Barrett
  reduction), which retrieval + budget did not overcome. More `max_steps` will not
  help (it didn't use what it had); only changing the task (handing it the
  reduction) would — which defeats the experiment.

### Folding scoreboard (the headline)
Correct PMULL folding landed in **0 of 6** conditions: cold screen (0/3), arm A
no-scout 50-steps (0/1), arm C scout 50-steps (0/1), arm C scout 100-steps (0/1).
Every run instead climbed the slicing-table ladder. The scout reliably FOUND the
technique + a reference and even verified the fold invariant; the residual,
unbreached wall is the reflected custom-poly Barrett reduction.

### DeepSeek V4 Pro thinking level in this setup (investigated 2026-06-03)
Confirms the capability-ceiling verdict is not a throttled-reasoning artifact:
- **No explicit reasoning effort is set anywhere** — not Motoko config
  (`.motoko/config/**`), not env, not `run-agent.sh`, not the ailang model registry
  (deepseek-v4-pro isn't even a full registry entry; it's used via the raw
  `openrouter/deepseek/deepseek-v4-pro` string). ailang exposes a `think` control
  ("high"/"medium"/"low"/true/false → OpenRouter `reasoning.effort`) but it was
  unset, so `reasoning.effort` is omitted (omitempty) → **OpenRouter provider
  default**. The harness does send `"include_reasoning":true` (why logs carry
  `reasoning_delta`/`thinking_delta`).
- **DeepSeek V4 Pro uses ADAPTIVE (o1/o3-style) reasoning** — it scales thinking to
  problem difficulty, and the explicit effort knob has weak effect. Direct probe
  (same prompt): default reasoning_tokens≈322, effort=low≈200, effort=high≈206 —
  i.e. forcing "high" barely changes it; the model self-throttles by difficulty.
- **Empirically it reasoned HARD on the folding work** at the default setting: the
  cold screens spent 11k–42k reasoning tokens (one even truncated at the cap), and
  the agent runs streamed ~24.5k reasoning deltas. So on the reflected-Barrett
  problem the model was already near its maximal adaptive reasoning and STILL failed
  — reinforcing capability, not budget/effort. Forcing `think:"high"` would very
  likely not change the outcome (adaptive model, weak knob).
- Observability gap: the harness `run_summary` does not surface `reasoning_tokens`
  separately (only total/output) — worth adding if reasoning cost matters.

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
