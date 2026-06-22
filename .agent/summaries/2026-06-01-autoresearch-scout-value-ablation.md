# 2026-06-01 — Autoresearch scout-value experiment (arm C vs arm A) on SIMD-scan

## Goal
Continue the SIMD-scan autoresearch warm-up from
`handoff-simdscan-paper-vs-best-method.md`. The open question was whether the loop,
given the literature as a *starting point* (not a prescription), discovers that a
published method is suboptimal for the task and beats/adapts it. Mid-session this
broadened into the sharper question (the user's "direction 3"): **does the
literature scout phase add any value at all, given the model is likely already
trained on these papers?**

## Headline outcome
1. **Arm C (literature-as-starting-point), N=4, robust:** the loop reproduces ->
   adapts -> beats. Held-out TEST ~18x-42x (mean ~30x), all exact, no overfit.
   Beats both the paper anchor (~6.3x) and the prior best autonomy run (~14.65x).
2. **Arm A (no-scout) ablation, N=4:** **the scout phase adds nothing.** Arm A
   (~19x-33x) vs arm C (~19x-42x) are statistically indistinguishable
   (Mann-Whitney U=7; critical 0 at N=4,4). Decisive: arm-A seed4 hit ~33x with NO
   scout tool loaded — the simdjson-class technique came purely from the model's
   pretraining.
3. **Corrected the prior hypothesis:** the handoff claimed the paper's nibble method
   is "~2x slower for this task." False — the two fastest arm-C seeds *used* the
   simdjson `vqtbl` nibble classification and won (~40-42x). The original fetch-run's
   ~6.3x was slow only because it omitted the empty-block skip + unroll. The dominant
   optimization (discovered empirically by every seed via ~0.5% match density) is the
   **empty-block early-out**.
4. **The "scout" was theater here:** seeds called `exa_search` but the query already
   named the technique ("simdjson ... uint8x16_t"), the result was a Lemire *blog*,
   and the arXiv paper was never fetched. Recall, not retrieval.

## Per-seed results (held-out TEST, MB/s; baseline ~610-626)
| seed | Arm C (scout) | Arm A (no scout) |
|------|---------------|------------------|
| 1 | 11519 (~18.5x) | 11600 (~18.6x) |
| 2 | 13060 (~21x)   | 14768 (~24x)   |
| 3 | 24809 (~40x)   | 16932 (~27x)   |
| 4 | 25803 (~42x)   | 20480 (~33x)   |
| mean | 18798 | 15945 |

Winning techniques varied by seed: per-target `vceqq` compare + block-skip + unroll
(seeds C1, A4) vs simdjson `vqtbl` nibble-table + block-skip + unroll (C3, C4). The
block-skip short-circuit mattered far more than the classification method. All
winners exact on 9 TEST files; seed-4 (arm C) re-graded x3 + independent compile,
stable (~25 GB/s real, not noise).

## Models — what works in this harness
- **DeepSeek V4 Pro:** reliable multi-turn tool driver. Used for all real runs.
- **DeepSeek V4 Flash:** provider-degraded — empty completion after a tool result,
  duds at step 2. A standalone 2-message tool-probe passed (routed to GMICloud) but
  did NOT predict the harness run (OpenRouter load-balances providers per request).
- **MiniMax-M3:** flaky here — reasoning truncated at `finish_reason=length` (stopped
  at step 6, no optimization) and emitted malformed/duplicated tool args
  (" bash -lc" spliced onto commands). Cheaper on input than pro but not usable.

## Infra bugs found & fixed
- **duckdb missing on fresh worktrees.** Autoresearch `ar_init` shells out to
  `duckdb`; it wasn't installed, so the first minimax run burned its whole budget
  installing it by hand. `scripts/install-prerequisites.sh` had a Debian no-op (apt
  has no duckdb package); rewrote it to download the official CLI release (v1.1.3) by
  arch into ~/.local/bin + added `unzip`. Verified end-to-end in a sandboxed HOME/PATH.
- **Config-profile misunderstanding (important).** The agent loads
  `config_profile=default` from the **WORKTREE** `.motoko/config/default`, selected
  because `MOTOKO_CONFIG` is unset — `MODEL=openrouter/...` only sets the model
  string. So earlier edits to the openrouter profile (max_steps 50->90, and an
  exa_search removal) had NO effect; all runs ran at max_steps=50. Reverted the
  openrouter profile and corrected the ledger.
- **exa_search can't be disabled via `CORE_EXT_ORDER`** (which only ADDS). It's in
  the worktree default profile's `extensions.order`; the arm-A driver strips it after
  each `git reset` and verifies absence via `session_start.loaded_extensions`.
- **Seed-driver `git reset --hard` between seeds wipes keep-commits.** To inspect a
  non-last seed's winner, reconstruct from JSONL `WriteFile` calls
  (`tc['tool']=='WriteFile'`, `tc['arguments']['content']`). Done for seeds 2 & 3.

## Artifacts produced
- Prompts: `benchmarks/prompts/simdscan_autonomy_scout_task.md` (arm C, non-leaky
  optional-scout), `..._noscout_task.md` (arm A control).
- Drivers/logs: `.motoko/ar_bench_scratch/arm_{c,a}_seeds.sh`,
  `scout_pro_*.jsonl`, `noscout_pro_seed*.jsonl` (gitignored scratch).
- Ledger: three new `papers/ledger.md` 2026-06-01 entries (arm C N=4 + correction,
  recall-not-paper clarification, arm-A ablation).
- `.gitignore`: excludes `.motoko/ar_bench_scratch/`, `.motoko/autoresearch*/`,
  `.emsdk/`.
- Handoff: `.agent/plans/Motoko-auto-research/handoff-pretraining-novel-fixture.md`.
- Commits on `autoresearch-loop`: 9ac9e03 (scout prompt + duckdb + ledger), 8ba64d3
  (gitignore), b0171a1 (arm-C N=4), 7fe2d55 (recall clarification), cbe41c8 (config
  correction), 7603474 (arm-A ablation), 2f28dcf (handoff).

## Methodological lessons
- **Non-leaky prompt design is essential and easy to break.** Caught a leak where the
  whole prompt file (incl. the `<!-- -->` design comment naming sparsity + "paper is
  suboptimal") was passed to the agent; fixed by stripping the comment
  (`awk 'f{print} /^-->/{f=1}'`). Re-ran.
- **Sequential, not parallel, seeds** — parallel benchmarks contend for CPU and
  corrupt the throughput metric.
- **N=4 per arm is low power.** We can claim no large effect / no significant
  difference, not "identical." Verifying numbers (re-grade x3, independent compile,
  JSONL reconstruction) caught nothing wrong but is the right discipline.

## Open / next
- **`ailang.lock`** is dirty (working copy v0.19.1 regenerated; committed v0.22.0) —
  an undecided call; left for the user.
- **Next experiment (handoff written):** a **pretraining-novel fixture** — the only
  regime where the scout *could* show value (technique not derivable cold, but
  fetchable). Framed as a design discussion (planted-novel vs post-cutoff paper, how
  to prove novelty, statistical bar).
- This closes the scout-value question for techniques the model already knows: for
  famous methods, retrieval is theater.
