# 2026-05-31 Autoresearch Polyglot Phase 0.5a

- Polyglot testing is pinned to `openrouter/deepseek/deepseek-v4-flash` in `benchmarks/fixtures/autoresearch_polyglot/bench/lib.sh`; any other `POLYGLOT_MODEL` fails before runner startup.
- The autoresearch extension noisy-primary path was fixed locally: `ar_log` now computes primary MAD from pending `samples_json` when the primary metric is noisy and passes it to `Metrics.improved`.
- Direct DeepSeek optimizer attempts loaded `autoresearch` but did not call `ar_init`; `scripts/ar_polyglot_harness.ail` was added to drive the real `ar_init`/`ar_run`/`ar_log` hooks without relying on model tool-following.
- Live segment 2 proof with `samples=2`: baseline TRAIN median `pass_rate=0.5833335`, candidate ReAct-style prompt median `pass_rate=0.75`, candidate MAD `0.083333`, checks passed, and `ar_log keep` committed `f3efa47446c5af9a7515e7191e0b87d06b90383a` in `/workspaces/motoko_agent_polyglot_wt`.
- Held-out TEST did not transfer under the DeepSeek-only route: `grade_test.sh` returned `pass_rate=0.000000`, with all TEST exercises timing out or erroring. Phase 0.5a exit is therefore not achieved yet.
- Fixture infra now has per-exercise timeout/error JSON handling and `aider_polyglot.py --skip-preflight` to prevent repeated model preflight hangs during subset loops.
