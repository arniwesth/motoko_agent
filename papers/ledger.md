# Autoresearch Method Ledger

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
