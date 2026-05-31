# Handoff: design a more ambitious autoresearch test (2026-05-30)

Paste this into a new session to continue. Goal of the **next** session: **discuss
and design a much more ambitious test of the autoresearch extension** — then
(optionally) build and run it. Start by discussing direction; don't jump to code.

---

## What you're working with

`packages/motoko-ext-autoresearch/` is a Motoko agent extension that turns the agent
into a disciplined optimize→measure→keep/discard loop. Tools: `ar_init`, `ar_run`,
`ar_log`, `ar_notes`. FSM: `Setup → Ready → AwaitingLog → Done`. State is in a DuckDB
session DB. Read `packages/motoko-ext-autoresearch/README.md` first — it documents
the tools, FSM, config, persistence, module map, and the git-worktree model.

The existing test is the **self-bootstrap benchmark** ("optimizer ≠ optimized"):
- Prompt: `benchmarks/prompts/autoresearch_self_bootstrap.md`
- Fixtures: `benchmarks/fixtures/autoresearch_self_bootstrap/bench/`
  (`exercise_derive_state.ail`, `benchmark.sh`, `checks.sh`, `shim/duckdb`)
- It has the live extension optimize a *copy of itself* (`derive_state`'s duckdb
  spawn count) in a throwaway git worktree, with `checks.sh` guarding behavior.

## What's already proven (don't re-litigate)

A full clean run completed end-to-end: **302 → 102 duckdb spawns (−66%)**, hitting the
theoretical floor (1 spawn/`derive_state` call + 2 setup), behavior-preserved on every
kept run, live extension provably untouched. The machinery works. Four bugs were found
and fixed along the way (all committed on branch `autoresearch-research`):

- `061b6c1` real-code `.ail` harness + sandbox-writable scratch (`AR_BENCH_SCRATCH`)
- `bd32aa9` arg parser handles escaped quotes (`raw_str_field` was truncating at `\"`)
- `9fb33e2` absolute benchmark/checks script path (relative `ctx.workdir="."` broke exec from the worktree)
- `20bebbc` `checks.sh` keys off the test summary, not `ailang test`'s (noisy) exit code

Also see `.agent/learnings/2026-05-30-ailang-syntax-gotchas.md` and the
`ailang-syntax-gotchas` memory (AILANG: `--` comments, `++` is list-only, no `let`
tuple-destructure, `MOD010`/`--relax-modules`).

## Why the current test is "easy" — what an ambitious test should push past

The self-bootstrap test is a great **machinery validation** but a weak **research
challenge**:

1. **The answer is handed to the agent.** Step 9 of the prompt literally names the
   optimization (collapse `current_session_row`). An ambitious test should make the
   agent *discover* the lever.
2. **Tiny, closed search space** with a known floor (102). Real research has an open
   space and no known optimum.
3. **The primary metric is deterministic and trivially coupled.** The noisy metric
   (`overhead_ms`) and the whole MAD/confidence/patience apparatus are barely
   exercised — patience just trips when the deterministic metric plateaus.
4. **Behavior preservation is cheap** (a few small modules, fast tests). Harder when
   the candidate is large with a slow/rich test suite and real invariants.
5. **Single segment, ~6 iterations.** Multi-segment (`new_segment`), long horizons,
   and real stall/patience dynamics are untested.
6. **Self-referential.** Optimizing a copy of the extension is cute but small.

## Springboard directions (for the discussion — pick/combine)

- **Optimize a real, non-self target**: a Motoko core module, a parser, a hot path in
  `src/core/`, or an external program/algorithm with real inputs.
- **Genuine tradeoff curve**: speed vs. memory, latency vs. accuracy — forces the
  primary/secondary-metric machinery to matter.
- **Make noise real**: a wall-clock or statistical metric where samples + MAD +
  confidence + patience actually drive keep/discard decisions (test the stats).
- **Hide the lever**: a prompt that states only the objective + metric + guards, not
  the fix — measure whether the agent finds optimizations autonomously.
- **Adversarial / anti-cheat**: can the optimizer game the metric? Stress the
  `checks.sh` and scope/off-limits guards; verify they actually block cheating.
- **Bigger candidate + richer invariants**: behavior preservation that's non-trivial.
- **Long horizon / multi-segment**: many iterations, `new_segment`, regressions and
  recoveries, stall-driven stopping.

Good discussion questions to open with: *What's the optimization target? What metric is
both meaningful and gaming-resistant? How do we guarantee behavior preservation? How do
we know the agent "discovered" rather than was "told"? How long/expensive a run?*

## Operational playbook (so a run actually works)

- **Launch**: `make run_autoresearch_self` (uses the prompt + profile config), or
  `make run` and paste a prompt. The agent runs **headless/non-TTY** under the harness.
- **Model**: the default profile model is `openrouter/deepseek/deepseek-v4-flash`
  (weak — it thrashed). Override with `MODEL=openrouter/deepseek/deepseek-v4-pro`
  (this is what produced the clean 302→102 run). A capable model matters a lot.
- **Pitfalls learned the hard way**:
  - Each run creates a worktree at `/workspaces/motoko_agent_autoresearch_wt` and a
    branch `autoresearch/self-bootstrap-YYYYMMDD-N`. A **leftover worktree blocks the
    next run** — `git worktree remove --force <path> && git worktree prune` first.
    Branches accumulate (`-2`, `-3`, …); prune with
    `git branch -D $(git branch --list 'autoresearch/self-bootstrap-*')`.
  - **Don't run the benchmark wrapper manually while a run is live** — it shares the
    fixed `AR_BENCH_SCRATCH` and the session DB; concurrent access corrupts both.
  - **Don't hold the session DB open** in a DuckDB browser (e.g. `harlequin`) during a
    run — it takes a lock that conflicts with the extension's writes.
  - **Monitor via the JSONL session log** (`.motoko/logfile/session_*.jsonl`,
    `native_tool_results[].payload.metadata`), not by querying the DB, to avoid lock
    collisions. Background bash loops that `pgrep index.ts` work well; note `pgrep -f`
    self-matches your own command line.
  - Between runs, clean: `rm -rf .motoko/autoresearch .motoko/ar_bench_scratch`.
- **Verify outcomes against reality**, not just the agent's final report: check
  `git diff -- packages/motoko-ext-autoresearch/` is empty (optimizer ≠ optimized),
  `sha256sum -c immutable.sha256`, and the kept-run metric trajectory in the DB/log.

## Current repo state
- Branch: `autoresearch-research` (not pushed). Main branch: `main`.
- Uncommitted at handoff time: `ailang.toml` description may still be in the
  working tree — check `git status` and commit if desired.
- The autoresearch design docs live in `.agent/plans/Motoko-auto-research/`
  (`implementation-plan.md` = Appendix A source; `self-bootstrap-fixes.md` = the
  superseded shell-sim plan, with an "implemented" note).
