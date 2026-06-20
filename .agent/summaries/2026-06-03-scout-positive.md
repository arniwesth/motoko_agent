# Session findings: the FIRST genuine scout-value positive (regime b)

Date: 2026-06-03. Continues `handoff-crc-stronger-model.md` and
`session-summary-2026-06-03-stronger-model.md`. Where the earlier part of the day
found a robust *capability ceiling* (no model landed the custom-poly PMULL fold),
this part **broke the ceiling** and **proved scout value** via a behavioral nudge
+ controlled A/B.

## TL;DR

- **deepseek-v4-pro, scout arm + a general "compute-and-verify / commit-and-iterate"
  nudge, LANDED a correct custom-poly PMULL fold: 47,061 MB/s on held-out TEST
  (~122× baseline, ~8.5× the slicing plateau), CORRECTNESS_OK.** First time the fold
  was implemented in this loop, by any model, in any arm.
- **Controlled attribution (same model, same nudge, only the scout differs):**
  - **Arm C (scout + nudge): FOLD, 47 GB/s.**
  - **Arm A (no scout + nudge): NO FOLD — slicing 4.3 GB/s.** Persisted on the fold
    (5 committed failed attempts) but could not derive the reflected-CRC
    constant-transform formula from its own weights; settled for slicing.
- **→ Genuine regime (b): the scout is the differentiator.** Retrieval converted an
  un-implementable technique into an implemented one. Sharper than hoped: scout
  value is **real but conditional** — it only pays off once the model is scaffolded
  (the nudge) to actually act on what it retrieves.

## The 2×2 (complementary necessity)

| Run | Scout | Nudge | Outcome |
|---|---|---|---|
| Original deepseek (prior session) | ✓ | ✗ | reasoned about Barrett 262×, committed 0 folds, **gave up → slicing ~5.5 GB/s** |
| Arm A (this session) | ✗ | ✓ | derived constants programmatically, committed 5 folds, **couldn't crack the transform → slicing 4.3 GB/s** |
| Arm C (this session) | ✓ | ✓ | **landed the fold → 47 GB/s** |

Neither scout-alone nor nudge-alone landed the fold; only both together did.

## The nudge (leak-clean, applied to BOTH arms)

A general methodology + behavior hint added to the task body (no mention of
folding/PMULL/Barrett/constants — verified leak-clean). Two targeted levers, aimed
at deepseek's two observed failures from the prior run:
1. **"Compute exact values, verify against the reference oracle, don't hand-derive."**
   (Prior run: it hand-derived constants, distrusted them, retreated. Quote, s63:
   *"the PMULL approach is clearly correct in theory but I can't get the constants
   right."*)
2. **"Commit candidates even when unsure; debug against the oracle instead of
   retreating to a safe approach."** (Prior run: 0 fold submissions; it kept folds
   "in its head" and shipped slicing.)

Prompt files: `benchmarks/prompts/crc_autonomy_{scout,noscout}_nudge_task.md`.
The nudge mentioned AILANG *and* Python as the scratch tool; deepseek chose Python
by free choice (it doesn't know AILANG syntax — see open follow-up).

## What the nudge changed (behavior), what the scout changed (knowledge)

- **Nudge → engagement.** Both nudged arms immediately wrote scripts to compute
  `x^k mod P` and committed fold candidates, debugging CORRECTNESS_FAIL → OK. The
  un-nudged prior run never committed a single fold.
- **Scout → the specific missing derivation.** The hard part of a *custom*-poly fold
  is the **constant-transform** (mapping `x^k mod P` → the usable reflected fold
  constant: the `<<1`, bit-reversal, `<<32` placement, plus the Barrett μ). Arm C's
  scout retrieved AOSP's `crc32_simd.c`, whose comment encodes the transform
  (`k = (x^N mod P << 32)' << 1`); deepseek validated its constants against the
  *known* zlib constants, then applied the method to `0xB2A8D703`. Arm A had the
  correct `x^k mod P` values but spent ~40 steps guessing the transform and every
  variant mismatched (`"Match: False"`), so it never folded.

## Verified result detail (arm C)

- Stopped voluntarily step 62. 12 committed CORRECTNESS_FAIL → 13 OK.
- Best keep #10 = real PMULL fold: inline `pmull`/`pmull2` asm, 4-way 64-byte
  parallel folding, custom-poly constants K(544/480/160/96/64) + **Barrett constant
  `0x98B320DB`** (the specific named barrier from the handoff), slice-by-8 tail.
- Independent TEST grade (worktree untouched, via `git show` → temp): **47,061
  MB/s, CORRECTNESS_OK.**

## Caveats / threats to validity

- **N=1 per arm.** The contrast is stark (fold vs slicing; 47 vs 4.3 GB/s; cracked
  vs couldn't-crack the transform) and the mechanism is legible, but a statistical
  claim needs N≥4–6 seeds/arm.
- **Reference specificity.** Arm C succeeded with AOSP zlib's transform comment;
  whether *any* good retrieval suffices, or this specific page was needed, is
  untested.
- **It's deepseek-specific so far.** glm-5/kimi/mimo truncate before they could
  benefit (registry/max_tokens issue — see
  `autoresearch-model-registry-maxtokens.md`). The scout-value claim is demonstrated
  for the one model that runs the loop stably.

## Open follow-ups

- **AILANG-teacher variant (built, not yet run):**
  `benchmarks/prompts/crc_autonomy_{scout,noscout}_ailang_task.md` embed a verified
  AILANG primer (bitwise builtins under std/math; a tested example) + `ailang prompt`
  pointer, to test whether deepseek can dogfood **AILANG** (not Python) for the
  constant derivation. On-brand for the project; orthogonal to the scout result.
- **Seeds for statistics** on the arm A vs arm C contrast.
- **Generality**: does a weaker/looser retrieval (only "the technique exists",
  not the transform) still flip arm C? Tests the resolution of scout value.

## Artifacts

- Logs: `.motoko/ar_bench_scratch/crc_deepseek_{scout,noscout}_nudge_seed1.jsonl`.
- Prompts: `crc_autonomy_{scout,noscout}_{nudge,ailang}_task.md`.
- Worktree `/workspaces/motoko_agent_crc_wt` holds arm A keep-commits; reset to
  `dcaf70d` before any reuse.
- Verified fold lives in arm C keep #10 (graded 47 GB/s); extract via `git show`.
