# Session findings: does the literature scout add value? (pretraining-novel fixtures)

Date: 2026-06-02 → 2026-06-03. Continues the autoresearch "does the literature
scout add value?" thread from `handoff-pretraining-novel-fixture.md`.

## TL;DR

- Prior result (simdscan): the scout was **theater** because the winning technique
  (simdjson SIMD classification) was already in the model's weights. Open question:
  does the scout help when the technique is genuinely NOT in pretraining?
- Built a cheap **novelty cold-screen** and used it to triage candidate techniques
  *before* building fixtures. It killed one candidate (Stream VByte — also in
  weights) and green-lit another (custom-polynomial CRC folding).
- Built the **`autoresearch_crc`** fixture (custom reflected polynomial 0xB2A8D703;
  baseline byte-table; ceiling = PMULL carry-less-multiply folding) and ran the
  arm-A (no scout) vs arm-C (scout) experiment.
- **Result: a third null, but via a new mechanism.** Unlike the prior two, here the
  scout *succeeded at retrieval* (found the right reference, verified the fold
  invariant) — yet the outcome didn't change, because the agent **could not
  correctly implement** the reflected custom-poly fold (specifically the Barrett
  reduction). Confirmed it's a **capability ceiling, not a budget limit**.
- **Thread-level synthesis:** across all three fixtures the scout never improved the
  outcome. The binding constraint for this autonomous-optimization loop is the
  model's **implementation capability**, not its access to literature.

## Method: the cold-screen as a novelty gate

A fixture only tests the scout if its winning technique is NOT already derivable by
the model cold. Previously this was discovered *after* building (wasteful). This
session established a cheap gate: a one-shot OpenRouter completion
(`deepseek/deepseek-v4-pro`, no tools, no fixture context) posing the bare problem,
then compile-verifying the model's answer against a reference. ~$0.01–0.13/query.
Run it on a candidate technique **before** building a fixture.

Tools: `.motoko/ar_bench_scratch/{intcodec_coldcheck.py, crc_coldcheck.py,
crc_verify*.c, fold_dev.c}`.

## Candidate 1 — Stream VByte (`autoresearch_intcodec`): CONTAMINATED

- Built a full, validated, non-leaky integer-codec fixture (decode-throughput
  objective, round-trip + ⅞-compression gates, levers, immutable hashing).
- Cold screen: deepseek-v4-pro **reconstructed Stream VByte verbatim** (control/data
  split, 256-entry shuffle table, `vqtbl`), and on a clean re-prompt produced a
  decoder *faster than the reference lever* (`vqtbl4q_u8` + `vst4q_u8`, 16 values/
  iter). ~$0.13. → In-weights; foregone null; **not run**.
- Lesson: "niche 2017 paper" ≠ pretraining-novel. The fixture skeleton is sound and
  reusable; it's parked (uncommitted) for possible reuse.

## Candidate 2 — custom-polynomial CRC folding (`autoresearch_crc`): VIABLE → built → run

- Cold screen (3/3 samples, compile-verified): the model **knows** PMULL folding is
  the ceiling (even names the Intel generic-poly PCLMULQDQ paper) but **cannot
  implement it cold** for a custom polynomial — fabricated/garbled folding
  constants, and even its fallback table was wrong (0 correct). First candidate to
  survive the screen. Non-hardware polynomial chosen so the ARMv8 `crc32`
  instruction can't shortcut it.
- Fixture: candidate `crc.c` (must match a bit-by-bit reference CRC, reflected poly
  0xB2A8D703); sharp exact-match gate; large-buffer TRAIN/TEST corpora; build
  `gcc -O2 -march=armv8-a+crypto` (so `vmull_p64` compiles). Verified levers:
  baseline byte-table (~0.38 GB/s), slice8 (keep+transfers), noise (discard),
  decoy_wrong (correctness-blocked). Folding ceiling intentionally NOT shipped as a
  lever (deriving the reflected fold correctly is the hard step under test — the
  operator hit the same wall).

### Experiment runs (single seed each; deepseek-v4-pro)

| Run | Arm | Budget | Kept technique | TEST MB/s | Folding? |
|-----|-----|--------|----------------|-----------|----------|
| `crc_noscout_seed1` | A (no scout) | 40 min | slicing-by-16 | **4512** | attempted, failed ("fold formula is wrong"), fell back |
| `crc_scout_seed1` | C (scout) | 40 min | — (timeout) | baseline | found `corsix/fast-crc32`, computing constants when it timed out |
| `crc_scout_seed1_t5400` | C (scout) | 90 min | slicing-by-32 + NEON | **5572** | built+tested fold → MISMATCH every length; reverted under step cap (stopped at max_steps=50, 36 min) |
| `crc_scout_seed1_steps100` | C (scout) | max_steps=100 | slicing-by-32 unrolled | **5495** | 3 PMULL impls → CORRECTNESS_FAIL on the **Barrett reduction**; **stopped voluntarily at step 82** |

(Logs in `.motoko/ar_bench_scratch/`.)

### Why arm C never landed folding (deep-dive)

Direct evidence from the logs, culminating in the agent's own final account:
- **Retrieval succeeded:** fetched `corsix/fast-crc32` + `mattsta/crcspeed` (real
  reflected PMULL CRC references), and explicitly reasoned "for a reflected CRC32
  the folding is different from the non-reflected case."
- **Implementation failed:** it derived constant sets (values shifting between
  attempts — unsure of the reflected convention), verified the fold *invariant*
  (mid-run side-tests printed `correct!`/`PASS`), but the **final Barrett reduction
  from the 64-bit folded state to the 32-bit CRC could not be derived correctly for
  the custom polynomial**. Three PMULL implementations → CORRECTNESS_FAIL.
- **Capability, not budget:** at max_steps=100 it used only 82 and **stopped
  voluntarily**, judging further folding attempts a dead end. More steps would not
  help; only handing it the reduction would (which defeats the experiment).

**Folding scoreboard: correct PMULL folding landed in 0 of 6 conditions**
(cold 0/3, arm A 0/1, arm C 50-steps 0/1, arm C 100-steps 0/1). Every run instead
climbed the slicing-table ladder (8 → 16 → 32 + NEON unroll), ~0.38 → ~5.6 GB/s.

### Was the model under-thinking? (reasoning-level check)

Investigated whether the folding failure was a throttled-reasoning artifact. It was
not — the model was reasoning at its (heavy) adaptive default:
- **No reasoning effort is set anywhere** in the stack (Motoko config, env,
  `run-agent.sh`, ailang model registry). ailang exposes a `think` control
  ("high"/"medium"/"low"/true/false → OpenRouter `reasoning.effort`) but it was
  unset → `reasoning.effort` omitted → OpenRouter **provider default**. The harness
  does send `"include_reasoning":true` (hence the `reasoning_delta` log events).
- **DeepSeek V4 Pro is an adaptive (o1/o3-style) reasoner** and the effort knob has
  weak effect: a direct probe gave reasoning_tokens ≈ 322 default / 200 low / 206
  high — forcing "high" barely changes it; it self-scales by difficulty.
- **It reasoned hard on the folding work at the default**: cold screens spent
  11k–42k reasoning tokens (one truncated at the cap); agent runs streamed ~24.5k
  reasoning deltas. So on the reflected-Barrett problem it was already near maximal
  adaptive reasoning and still failed → reinforces *capability*, not budget/effort.
  Forcing `think:"high"` would very likely not change the outcome.
- (Observability gap: the harness `run_summary` tracks total/output tokens but not
  `reasoning_tokens` separately.)

## Thread-level synthesis

Across three fixtures the literature scout never improved the outcome — for three
distinct reasons:

| Fixture | Winning technique | Why the scout didn't help |
|---|---|---|
| `autoresearch_simdscan` | simdjson SIMD classify | already in weights (theater) |
| `autoresearch_intcodec` | Stream VByte | already in weights (theater) |
| `autoresearch_crc` | PMULL carry-less folding | **findable (scout found it) but not implementable by the model** |

The CRC case is the most informative: it is the one regime where retrieval genuinely
worked, and the outcome was *still* a null. So the binding constraint for this
autonomous-optimization loop is **the model's implementation capability** (here,
deriving a correct reflected custom-polynomial Barrett reduction), not access to or
knowledge of the literature.

## Methodology notes / hard-won gotchas

- **Cold-screen before building.** Cheap, decisive; saved ~10h of agent runs that
  would have produced a third "in-weights" null on Stream VByte.
- **Leak discipline (the agent can read everything, off_limits blocks edits not
  reads):** name fixtures for the PROBLEM not the SOLUTION (`svbyte`→`intcodec`,
  `crcfold`→`crc`); strip the technique name/mechanism from README/manifest/harness
  comments/lever filenames; keep technique-naming operator notes + the
  design-comment-bearing prompts OUT of the run worktree. An auto-commit had tracked
  the CRC operator notes into the worktree's base commit — caught and removed before
  the no-scout run. See [[autoresearch-fixture-leak-discipline]].
- **The governing budget is `max_steps`** in the worktree `default`
  `config.json` (was 50), NOT wall-clock and NOT `AI_MAX_STEPS` env. The 90-min run
  stopped at the 50-step cap in 36 min; only editing `max_steps` changed behavior.
- **Disable `exa_search` for the no-scout arm** by stripping it from the worktree
  profile's `extensions.order` (CORE_EXT_ORDER only ADDS); verify via the
  `session_start` `loaded_extensions`.
- Parse run logs as JSONL with Python — grepping the raw file gives false positives
  from the prompt text echoed in `session_start`.

## Artifacts

- Committed (branch `autoresearch-loop`, commit `2a75e85`): `benchmarks/fixtures/
  autoresearch_crc/` (the fixture only).
- Uncommitted in main working tree: `benchmarks/fixtures/autoresearch_intcodec/`,
  `benchmarks/prompts/{intcodec,crc}_autonomy_{scout,noscout}_task.md`, the two
  operator-notes files, and this summary.
- Run worktree: `/workspaces/motoko_agent_crc_wt` (branch `autoresearch/crc-noscout`,
  baseline `dcaf70d` with operator notes stripped); holds experiment keep-commits.
- Operator notes: `crc-fixture-operator-notes.md`, `intcodec-fixture-operator-notes.md`.
- Memory: `autoresearch-novelty-cold-check.md`, `autoresearch-fixture-leak-discipline.md`.

## Recommended next steps (not done this session)

1. **Statistical confirmation (optional):** the mechanism is established by direct
   evidence at N=1, but a formal claim needs equal-budget (same `max_steps`) N-seed
   runs of arm A vs arm C, then the pre-registered one-sided Mann-Whitney. Given the
   0/6 folding result, expect a null on "scout > no-scout" with high probability.
2. **If a positive scout result is still wanted:** the binding constraint is
   implementation, not retrieval — so a fixture whose ceiling technique is *easy to
   implement once known but hard to know* (e.g., a single non-obvious constant or
   formula the model would copy correctly) is more likely to show scout value than
   one gated behind hard math like reflected folding.
3. Decide whether to commit the intcodec fixture + prompts + operator notes, or
   leave them parked. `ailang.lock` (v0.19.1 vs committed v0.22.0) remains an open
   pre-existing decision, untouched this session.
