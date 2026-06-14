# 2026-05-31 Autoresearch Polyglot Phase 0.5a

- Polyglot testing was initially pinned to `openrouter/deepseek/deepseek-v4-flash`; the next retry is pinned to `openrouter/deepseek/deepseek-v4-pro` in `benchmarks/fixtures/autoresearch_polyglot/bench/lib.sh`.
- The autoresearch extension noisy-primary path was fixed locally: `ar_log` now computes primary MAD from pending `samples_json` when the primary metric is noisy and passes it to `Metrics.improved`.
- Direct DeepSeek optimizer attempts loaded `autoresearch` but did not call `ar_init`; `scripts/ar_polyglot_harness.ail` was added to drive the real `ar_init`/`ar_run`/`ar_log` hooks without relying on model tool-following.
- Live segment 2 proof with `samples=2`: baseline TRAIN median `pass_rate=0.5833335`, candidate ReAct-style prompt median `pass_rate=0.75`, candidate MAD `0.083333`, checks passed, and `ar_log keep` committed `f3efa47446c5af9a7515e7191e0b87d06b90383a` in `/workspaces/motoko_agent_polyglot_wt`.
- Held-out TEST did not transfer under the DeepSeek-only route: `grade_test.sh` returned `pass_rate=0.000000`, with all TEST exercises timing out or erroring. Phase 0.5a exit is therefore not achieved yet.
- Fixture infra now has per-exercise timeout/error JSON handling and `aider_polyglot.py --skip-preflight` to prevent repeated model preflight hangs during subset loops.
- Follow-up with `openrouter/deepseek/deepseek-v4-pro`: the default Polyglot prompt scored TRAIN `pass_rate=1.000000` and held-out TEST `pass_rate=1.000000`, all first-try passes. Treat this as a model-route retry result, not a kept-scaffolding-transfer result.

## 2026-05-31 (continuation) - Pro rebalanced split + full loop + held-out grade

- **Split rebalanced for Pro** (commits `cdd1caa`, `96a901e`). Probed ~26 Python
  exercises with Pro; stable correctness-failures are rare (only `pov`, `dominoes`).
  - TRAIN: `pov, connect, alphametics, food-chain, grep, poker`
  - TEST:  `dominoes, ledger, change, minesweeper, satellite, bowling`
  - Each split = 1 stable correctness-failer + 1 borderline-timeout exercise
    (`connect`/`ledger`, ~180-240s vs the 180s cap) + 4 reliable fast passers, giving
    a baseline well below 1.0 and a deliberately noisy primary. New canary GUID;
    `immutable.sha256` regenerated; `checks.sh` anti-cheat grep now inspects the
    actually-used `$SYSTEM_MD`.
- **Harness rewired** (`scripts/ar_polyglot_harness.ail`): `ar_init` enforces
  worktree-first, but the built TUI/runner + splits must come from main, so the
  candidate prompt is pointed at the worktree via `POLYGLOT_SYSTEM_MD` while
  `cwd=worktree` handles git ops. Measured == grepped == committed prompt.
  `timeout_ms` 240s -> 1200s to cover the worst-case 6x180s serial benchmark wall.
- **Loop ran 3 iterations through the live FSM** (session `.motoko/autoresearch_polyglot`,
  branch `autoresearch/polyglot-pro`, baseline `cdd1caa`):
  - run 1 baseline: TRAIN median `pass_rate=0.75`, samples `[0.833333, 0.666667]`,
    within-run MAD `0.083`, checks passed -> **kept** (reference).
  - run 2 candidate ReAct+Plan+Reflexion: TRAIN median `0.583` (samples `[0.667, 0.5]`),
    slower (805s vs 632s/sample) -> improvement test false -> **discarded** (reverted).
  - run 3 candidate efficiency/step-budget: TRAIN median `0.5` (samples `[0.5, 0.5]`)
    -> **discarded** (reverted). Patience exhausted (stall=2), `ar_state=Done`.
- **Held-out TEST (out-of-loop, single pass each):**
  - baseline: `pass_rate=0.500` (`change, minesweeper, satellite` pass; `dominoes`
    fail; `bowling, ledger` timeout), wall 677915.
  - discarded ReAct candidate: `pass_rate=0.667` (`ledger` rescued), wall 555989 -
    i.e. **higher than baseline on TEST**, the opposite of its TRAIN regression.
- **Integrity gates (all block, exit 1):** empty prompt fails checks
  (oracle-vs-no-op, paired with baseline `checks_passed=true`); prompt naming TEST
  exercises blocked by the anti-cheat grep; tampered TEST split caught by
  `sha256sum -c immutable.sha256`.
- **DoD status: 6 of 7 met. NOT complete.** Met: harder split hashed; baseline +
  candidates through `ar_init`/`ar_run`/`ar_log`; oracle-vs-no-op; cheat trial;
  literature ledger (claim vs measured). **Unmet (#3): no kept scaffolding change
  transfers** - both candidates were soundly discarded and nothing beat the baseline.
- **Headline finding: R-noise is the binding constraint.** The discarded ReAct
  candidate scored *higher* on TEST than on TRAIN; at `samples=2` over 6 exercises
  the timeout-driven primary variance (~0.167/exercise) is comparable to candidate
  effect sizes, so keep/discard does not reliably transfer. The loop machinery is
  fully validated; closing #3 needs a larger noise budget (more samples / a less
  timeout-bound metric) or a lower-variance candidate surface. No runs were repeated
  to chase a favorable keep (that would be the p-hacking the loop is meant to prevent).
