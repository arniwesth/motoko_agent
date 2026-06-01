# Autoresearch Method Ledger

## 2026-06-01 - SIMD-scan fixture - literature-as-starting-point (IMPROVEMENT OVER PAPER, autonomous, N=4)

- Setup: "arm C" exploration variant. Unlike the 2026-05-31 fetch run (which was
  POINTED at arXiv:1902.08318 and told to reproduce it), this prompt
  (`benchmarks/prompts/simdscan_autonomy_scout_task.md`) gave the agent NEITHER the
  technique nor the paper — only the objective, an optional `exa_search` scout, and
  the instruction to treat any published method as evidence and keep whatever the
  metric says is fastest for THIS workload. Deliberately non-leaky: it never names a
  technique, never states the workload is sparse, never hints the paper is suboptimal.
- Model: DeepSeek V4 Pro. (Flash was provider-degraded — empty completion after a
  tool result; MiniMax-M3 was flaky in this harness — reasoning truncation +
  malformed tool args. Pro was the only reliable multi-turn tool driver this session.)
- Measured, 4 seeds, best-kept candidate graded on held-out TEST (logs
  `.motoko/ar_bench_scratch/scout_pro_{run1,seed2,seed3,seed4}.jsonl`; baseline
  scalar ~610-623 MB/s; correctness is a hard gate, all winners exact on all 9 TEST
  files, no overfit; seed-4 number re-graded x3 + independent compile, stable):
  - seed1: per-target `vceqq_u8` compare + empty-block skip + 8x unroll -> TEST
    11519 MB/s (~18.5x)
  - seed2: nibble-lookup + `vshrn` bitmask + ctz (closest to the literal paper) ->
    TEST 13060 MB/s (~21x)
  - seed3: `vqtbl4q_u8` table classify + fast no-match path -> TEST 24809 MB/s (~40x)
  - seed4: `vqtbl1q_u8` two-nibble-table classify + empty-block early-out + 64B
    unroll -> TEST 25803 MB/s (~42x)
- Verdict: **IMPROVEMENT OVER PAPER, robust across seeds.** 4/4 seeds beat both the
  paper technique (~6.3x in the 2026-06-01 fetch run) and the prior best autonomy run
  (14.65x, below). Magnitude varies widely (~18x-42x, mean ~30x): the loop reliably
  beats the literature, but *how much* depends on the trajectory — single-seed point
  estimates undersell it (seed1's 18.5x was the floor, not the typical case). In
  practice, run multiple seeds and keep the best.
- **Correction to the prior hypothesis.** The handoff claimed the paper's nibble
  method is "~2x slower for this task." Not so: the two fastest seeds (3,4 at ~40-42x)
  ADAPTED the paper's `vqtbl` nibble/table classification and won. The original
  fetch-run's ~6.3x was slow only because it omitted the empty-block short-circuit and
  unrolling, not because the classification is bad. The dominant optimization (which
  all 4 seeds discovered empirically by characterizing the corpus at ~0.5% match
  density) is the **empty-block early-out** — skip the expensive mask-extraction/ctz on
  the ~99.5% of 16B blocks with no specials. It composes with the paper's efficient
  classification to give the best result. So the real behavior is reproduce -> ADAPT
  (add the workload-specific optimization the paper omits for this regime) -> beat.
- Caveats (do not over-claim): **Weak literature use** — seeds referenced `exa_search`
  but never fetched the paper (no curl/arXiv); grounding was their own training
  knowledge of simdjson/NEON. This *supports* the open hypothesis that the scout phase
  adds little when the model already knows the literature — worth a direct arm-A
  (no-scout) ablation. **Budget asymmetry** — arm C had 50-90 steps / up to 10
  iterations vs the fetch run's 6, so some of the gain is simply more room to
  unroll/tune; not a clean A/B vs the anchoring run.

## 2026-05-31 - SIMD-scan fixture - SIMD structural-character classification (REPRODUCED + TRANSFERS)

- Paper: "Parsing Gigabytes of JSON per Second", Langdale & Lemire, arXiv:1902.08318
  (simdjson); applied via the HTML-scan blog post
  https://lemire.me/blog/2024/07/05/scan-html-faster-with-simd-instructions-net-c-edition/
- Lever: vectorized classification — load a block of bytes, compare in parallel
  against the target bytes, reduce to a bitmask, enumerate matches; scalar tail.
- Fixture: `benchmarks/fixtures/autoresearch_simdscan/` — candidate `scan.c` finds
  HTML special bytes; primary `throughput_mbps` (maximize, CPU-time, noisy);
  correctness vs a reference is a hard gate; held-out TEST corpus grades transfer.
- Measured (DeepSeek V4 Flash optimizer):
  - Phase 2(b), flash as generator: correct NEON scan first try, TRAIN 7457 / TEST
    7449 MB/s (~11.7x baseline ~635). Kept, transfers. $0.0013.
  - Phase 2(a), full autonomy (flash drove ar_init/ar_run/ar_log): kept progressive
    correct gains 635 -> 3463 -> 7389 -> 9305 MB/s (14.65x); discarded a
    correctness-failing 4x-unroll and a correct-but-slower fix; best v3 TRAIN 9305
    / held-out TEST 9225 (~14.4x). Transfers. ~$0.035 total.
- Verdict: **REPRODUCED and TRANSFERS** — the literature lever was discovered,
  implemented correctly under the correctness gate, kept by the noisy keep/discard
  test, and confirmed on held-out. First clean positive in this ledger; contrast
  with the Polyglot ReAct non-reproduction below (no real lever on a strong model).

## 2026-05-31 - Polyglot 0.5a (Pro rebalanced split) - segment 1

Model: `openrouter/deepseek/deepseek-v4-pro`. Split rebalanced for Pro (TRAIN:
pov, connect, alphametics, food-chain, grep, poker; TEST: dominoes, ledger,
change, minesweeper, satellite, bowling). Baseline (minimal prompt) TRAIN median
`pass_rate=0.75` (samples `[0.833, 0.667]`, within-run MAD `0.083`); baseline TEST
`pass_rate=0.500` (single pass). Two literature/heuristic candidates were tested
through the live `ar_init`/`ar_run`/`ar_log` FSM and **both discarded** on TRAIN.

### Candidate 1 - ReAct + Plan-and-Solve + Reflexion (deliberation)
- Papers:
  - ReAct: Synergizing Reasoning and Acting in LMs, Yao et al., arXiv:2210.03629.
  - Plan-and-Solve Prompting, Wang et al., arXiv:2305.04091.
  - Reflexion: Language Agents with Verbal Reinforcement Learning, Shinn et al.,
    arXiv:2303.11366.
- Claim used: interleaving explicit reasoning, up-front planning, edge-case
  enumeration, and root-cause reflection on test failures improves solve rate on
  reasoning-heavy tasks.
- Candidate change: `benchmarks/prompts/polyglot_system.md` rewritten as an
  explicit reason -> plan -> implement -> test -> reflect loop.
- TRAIN measured: median `pass_rate=0.583` (samples `[0.667, 0.5]`), **worse** than
  baseline 0.75; wall went **up** (median 805s/sample vs 632s). The extra
  deliberation pushed borderline exercises past the 180s cap (`grep` newly timed
  out) and induced a correctness regression (`alphametics`). Improvement test
  `0.583 > 0.75 + 0.083` is false -> **discarded** (reverted).
- TEST measured (out-of-loop, single pass): `pass_rate=0.667`, **higher** than
  baseline 0.500, and **faster** (556s vs 678s); it rescued `ledger` from timeout.
- Verdict: **non-reproduction on TRAIN, but the TRAIN discard did NOT hold on
  held-out TEST.** The cross-split disagreement (one timeout-flip on `ledger`) is
  within the metric's noise. Net: no reliable, transferable effect; the binding
  constraint is the noisy primary, not the method.

### Candidate 2 - efficiency / step-budget (decisiveness)
- Basis: empirical observation that timeout-driven failures (connect/ledger/
  bowling exceed the 180s per-exercise cap) dominate the noisy primary; an
  efficiency heuristic (single-edit, run-once, minimal exploration) was tested as
  the opposite lever to candidate 1.
- Claim used: cutting exploratory steps reduces wall-time, rescuing exercises that
  otherwise time out.
- Candidate change: `polyglot_system.md` rewritten to push decisiveness and a
  one-pass solve under a limited step budget.
- TRAIN measured: median `pass_rate=0.5` (samples `[0.5, 0.5]`), **worse** than
  baseline; `grep` and `poker` (reliable passers at baseline) newly timed out.
  Improvement test false -> **discarded** (reverted).
- Verdict: **non-reproduction.** Constraining the agent's process hurt; the
  minimal baseline prompt is a strong local optimum for this model.

### Segment conclusion
Loop machinery fully validated (noisy median+MAD keep/discard, scope/off-limits
gating, selective commit/revert, stall/patience stop at stall=2, oracle-vs-no-op +
cheat + immutable gates). **No scaffolding change beat the baseline.** Held-out
grading exposed R-noise as binding: at `samples=2` over 6 exercises the primary's
timeout-driven variance (~one exercise = 0.167) is comparable to candidate effect
sizes, so keep/discard decisions do not reliably transfer. Closing DoD #3 (a kept
change that transfers) needs either a larger noise budget (more samples / a less
timeout-bound metric) or a candidate surface with real, low-variance headroom for
a strong model.

## 2026-05-31 - Polyglot 0.5a - ReAct-style action loop

- Paper: ReAct: Synergizing Reasoning and Acting in Language Models, Yao et al., arXiv:2210.03629, https://arxiv.org/abs/2210.03629
- Claim used: interleave brief reasoning with task-specific actions so the agent can update plans from observations and recover from tool/environment issues.
- Candidate change: `benchmarks/prompts/polyglot_system.md` added an explicit inspect -> edit -> test loop and told the model to continue with direct file reads if `Search`/`rg` is unavailable.
- TRAIN measurement: baseline segment 2 run #1 median `pass_rate=0.5833335`, candidate run #2 median `pass_rate=0.75`; within-run MAD for candidate `pass_rate=0.083333`, so `ar_log keep` committed the prompt change.
- Held-out TEST measurement: `grade_test.sh` on the disjoint TEST split scored `pass_rate=0.000000`; all six exercises timed out or errored under `openrouter/deepseek/deepseek-v4-flash`.
- Follow-up: next segment should retry the same held-out transfer check with `openrouter/deepseek/deepseek-v4-pro`.
- Verdict: positive TRAIN result, no held-out transfer under the current DeepSeek-only route; count this as a non-reproduction for exit-gate purposes.
- Pro route follow-up: with `openrouter/deepseek/deepseek-v4-pro`, the default prompt scored `pass_rate=1.000000` on both TRAIN and held-out TEST. This isolates the Flash result as route/capability limited, but it does not validate the ReAct candidate as the causal improvement.
