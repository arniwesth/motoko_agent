# Session findings: re-run the CRC scout experiment with STRONGER models

Date: 2026-06-03. Continues `handoff-crc-stronger-model.md` — does the
implementation ceiling that produced the deepseek-v4-pro null generalize to
stronger models, or does a more capable model clear it (and does the scout then
help)? Builds on `session-summary-2026-06-03-scout-value.md`.

## TL;DR

- **No model landed the custom-poly PMULL fold in any arm. Zero scout positives
  (no regime b). The capability ceiling is robust across 4 frontier models
  (deepseek-v4-pro, mimo-v2.5-pro, glm-5, kimi-k2.6) → regime (c), strongly.**
- **New mechanism discovered:** in this harness the ceiling manifests as
  **length-truncation**. Models that *attempt* the reflected custom-poly fold
  spiral into runaway reasoning (thousands of reasoning-deltas in one step), hit
  the per-completion `max_tokens` cap (`finish_reason=length`), and the agent loop
  dies. deepseek-v4-pro only survived (82 steps last session) because it *gave up*
  on folding and did concise slicing.
- **Harness constraint found:** the `ailang` runtime sets per-model
  `max_output_tokens` from a **compiled-in registry**. `xiaomi/mimo-v2.5-pro` and
  `qwen3-max` are NOT in v0.19.1's registry → low default cap → they truncate even
  faster. Registry-known reasoners (glm-5, kimi-k2.6, deepseek-v4-pro,
  minimax-m2.7) get generous caps but the *verbose* ones (glm-5, kimi) still
  truncate when they spiral on the fold. (Saved to memory:
  `autoresearch-model-registry-maxtokens.md`.)
- **One genuine scout side-effect (not a positive, but real):** for kimi the scout
  **extended its lifespan ~4×** (died step 17 with scout vs step 4 without) by
  giving it retrieved content to read instead of immediately spiraling. It still
  truncated and never landed folding. For glm-5 the scout made *no* difference
  (died step 18 in both arms).

## Pre-flight gates (all worked as designed)

1. **Model availability** — `xiaomi/mimo-v2.5-pro` confirmed on OpenRouter (tools,
   reasoning, 1M ctx). Cheap ($0.44/$0.87 per Mtok).
2. **Cold-screen (the novelty gate)** — reused `crc_coldcheck.py` with
   `COLDCHECK_MODEL`. All three new models **fail the fold cold** (the gate said
   "experiment is meaningful, proceed"):
   - **mimo**: clever runtime-derived-constant fold, but the 64→32 reduction is
     wrong (1000/2800 = only the `<16` delegate cases pass; every fold-path case
     wrong) + a non-compiling intrinsic typo (`vreinterpretq_u32_u128`).
   - **glm-5**: incoherent — two duplicate `crc_fast` defs, `return 0;` placeholders,
     admitted-guess hardcoded `k1=0x59515A80`, double-read data bug; doesn't compile.
   - **kimi**: burned its **entire 32768-token hard output cap on reasoning, emitted
     zero code** (a cold-screen preview of the harness truncation problem).
3. **Multi-turn tool-loop smoke test (mimo)** — passed (well-formed `BashExec`,
   survived tool result, correct answer). **But the trivial 1-step smoke test did
   NOT catch the length-truncation problem** — that only appears once reasoning
   grows multi-step on the hard task.

## Results matrix (N=1 per cell; mechanism readable at N=1)

| Model | ARM A (no scout) | ARM C (scout) |
|---|---|---|
| **deepseek-v4-pro** (prior) | slicing plateau ~5.5 GB/s, no fold | retrieval OK, couldn't implement fold |
| **mimo-v2.5-pro** | step 35: slicing **4.35 GB/s** on TEST (correct), no fold; died on a truncated/malformed tool call | step 4: `length`, nothing produced |
| **glm-5** | step 18: `length`, **0 keeps**, baseline 386 MB/s, no fold (spiral: 4096 reasoning-deltas) | step 18: `length`, scout fired (1 exa) but spiraled anyway (1514 deltas), no fold |
| **kimi-k2.6** | step 4: `length`, 0 benchmarks, baseline, no fold | step 17: `length`, scout (5 exa) extended life 4×, still spiraled (4094 deltas), no fold |

Notes:
- "fold landed" tell = kept candidate using `vmull/pmull` AND grading >> slicing
  plateau (~10–30 GB/s). **No cell reached it.** Only mimo ARM A produced a real
  optimization at all (slicing) — ironically *because* its low token cap forced
  concise steps, so it took the easy slicing keeps instead of spiraling on the fold.
- All runs at `max_steps=100`; exa presence/absence verified per arm via
  `session_start.loaded_extensions`. Worktree reset to `dcaf70d` between every run;
  operator notes confirmed absent (leak discipline held).

## Interpretation

The handoff's three regimes resolve as:
- **(a) implements cold** → NO (all fail cold).
- **(b) scout converts un-implementable → implementable** → NO (no model landed
  folding with the scout; the one we were hunting did not appear).
- **(c) ceiling generalizes across frontier models** → **YES, strongly.** Four
  frontier models, two arms each, zero folds.

The deeper finding is *why* it generalizes here: the binding constraint is
**implementation capability surfacing as a reasoning-runaway failure**. The fold
requires deriving reflected custom-poly reduction constants; models that engage
that derivation generate unbounded reasoning and truncate before producing working
code. The scout supplies the *technique* and even a *reference*, but cannot supply
the *derivation*, so it neither prevents the spiral (glm-5) nor changes the outcome
(kimi survived longer but still failed). This is consistent with, and strengthens,
the thread-level synthesis: **the autonomous-optimization loop is bottlenecked by
implementation capability, not literature access.**

## Caveats / threats to validity

- **Truncation confounds "no-scout fails to fold" for glm-5/kimi**: their ARM A
  runs died from `length` before exhausting the step budget, so we can't claim
  "full budget, still no fold." But the trajectory (spiraling on the derivation,
  never approaching a correct fold) and the cold-screen both point the same way.
- **"Stronger model" is constrained**: harness-stable ⇒ registry-known, which
  excludes mimo/qwen3-max. Whether a model that is *both* genuinely stronger than
  deepseek *and* registry-known exists is unresolved. The registry-known frontier
  reasoners we could run (glm-5, kimi) looked, if anything, weaker than deepseek on
  this task.
- N=1 per cell. The mechanism (truncation, no fold) is robust and repeated, but a
  statistical throughput claim would need N≥4–6 seeds/arm.

## Open follow-ups (not done this session)

- **Raise the cap to give the verbose models a fair shot.** The cleanest test of
  "can a stronger model clear the ceiling" needs `max_output_tokens` large enough
  that glm-5/kimi don't truncate mid-derivation. The cap is compiled into `ailang`
  v0.19.1; options: upgrade to v0.22.0 (may also add mimo/qwen3-max to the
  registry — unverified) or patch the registry. Decision left to the user
  (relates to the open `ailang.lock` v0.19.1 vs v0.22.0 item).
- If the cap is raised, the priority re-run is **mimo or qwen3-max ARM C** — the
  genuinely-stronger models the handoff wanted, with the scout, at full budget.

## Artifacts (this session)

- Logs: `.motoko/ar_bench_scratch/crc_{mimo,glm5,kimi}_{noscout,scout}_seed1.jsonl`.
- Cold screens: `crc_coldcheck_{mimo,glm5,kimi}.out`; verify harnesses
  `crc_verify_mimo.c`, `glm5_verify.c`; parameterized `crc_coldcheck_mimo.py`
  (`COLDCHECK_MODEL` env).
- Memory: added `autoresearch-model-registry-maxtokens.md`.
- Worktree `/workspaces/motoko_agent_crc_wt` reset clean to `dcaf70d`.
