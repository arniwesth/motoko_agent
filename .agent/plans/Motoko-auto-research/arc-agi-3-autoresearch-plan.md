# Plan: Autoresearch-driven optimization of an ARC-AGI-3 agent

**Status:** Draft / design. Phase 0 spike partially run (see "Spike findings").
**Author handoff date:** 2026-05-30
**Owner branch:** `autoresearch-research`
**Supersedes nothing.** Companion to `implementation-plan.md` (Appendix A = the
self-bootstrap benchmark) and `next-session-ambitious-test-handoff.md` (the
"design a more ambitious test" handoff this plan answers).

---

## 1. Goal

Use the `motoko-ext-autoresearch` extension as the **research/optimization loop**
that iteratively improves a **local, code-based ARC-AGI-3 agent**, with two
explicit objectives:

1. **Primary (the real goal): a competitive ARC-AGI-3 submission.** ARC Prize 2026
   is live (>$2M pool, open-source MIT/CC0 required). Checkpoints **Jun 30** and
   **Sep 30 2026**; submissions close **Nov 2 2026**. We are "all in" — the agent we
   produce should be aimed at the leaderboard, not just a demo.
2. **Secondary (still important): an ambitious test of autoresearch.** This target
   finally exercises everything the self-bootstrap test left asleep — open search
   space, no known optimum, a **genuinely noisy** primary metric (so MAD /
   confidence / patience actually drive keep/discard), long horizon, multi-segment,
   and real anti-cheat (train/test generalization).

These objectives mostly align: a disciplined optimize→measure→keep/discard loop
with held-out validation is exactly how you build a non-overfit submission.

---

## 2. What ARC-AGI-3 is (verified 2026-05-30)

- Launched 2026-03-25 by the ARC Prize Foundation (Chollet, Knoop).
- **Interactive** reasoning benchmark: **135 turn-based game environments**
  (public / semi-private / fully-private splits), handcrafted, **no instructions,
  no stated goals, no rules**. The agent must discover mechanics by interacting.
  Measures skill-acquisition efficiency / fluid intelligence, not recall.
- Difficulty: at release frontier LLMs scored **<1%** (humans 100%). Naive
  frontier-LLM-in-the-loop cost **$5k–9k per task**. A symbolic agent (Symbolica)
  reportedly reached ~36% for ~$1k.
- **Toolkit:** `arc-agi` (PyPI, `>=0.9.1`), plus the harness repo
  `arcprize/ARC-AGI-3-Agents` (`main.py`, `uv run main.py --agent=random --game=ls20`).
  - Actions: `GameAction.ACTION1..ACTION7` + `RESET`. Simple actions are
    parameterless; **complex** actions (e.g. `ACTION6`) carry `{x, y}` (0–63).
  - Observations: `FrameData` with `frame` (grid), `state` (`GameState`:
    `NOT_PLAYED`, `NOT_FINISHED`, `WIN`, `GAME_OVER`, ...), `levels_completed`
    (was `score` pre-0.9.3), `win_levels`, `available_actions`, `guid`.
  - Imports: `from arc_agi import EnvironmentWrapper, Arcade, OperationMode`;
    `from arcengine import FrameData, GameAction, GameState`.
  - Agent ABC (`agents/agent.py`): implement `choose_action(frames, latest_frame)`
    and `is_done(frames, latest_frame)`. Default `MAX_ACTIONS = 80` per game.
  - As of harness 0.9.3 the new `arc-agi` tool **allows local execution of
    environments** (`ONLINE_ONLY=False`, `ENVIRONMENTS_DIR=environment_files`); the
    online API/replay path needs `ARC_API_KEY`.
- **Submission constraint (load-bearing for objective #1):** Kaggle evaluation is
  **offline — no internet, no external inference / API calls during scoring.**
  Therefore a *submittable* candidate may use **pure code** and/or a **local model
  (weights on the eval box)**, but **NOT** any hosted API model (OpenAI, DeepSeek
  API, etc.) at play-time.

Sources: arcprize.org/blog/arc-agi-3-launch, docs.arcprize.org/agents-quickstart,
github.com/arcprize/ARC-AGI-3-Agents, github.com/arcprize/arc-agi,
arcprize.org/competitions/2026/arc-agi-3.

---

## 3. The key reframe: optimizer ≠ player

The naive framing ("autoresearch's LLM plays the games") is the $5k/task trap and
makes every `ar_run` slow and expensive. We separate the two intelligences:

| Role | Who | LLM? | Cost | Submittable? |
|------|-----|------|------|--------------|
| **Optimizer** (research loop) | the autoresearch agent | cheap **API** model (DeepSeek-V4-Flash/Pro) — fine | per-iteration, modest | N/A (dev-time only) |
| **Candidate / player** (what runs the games) | the code we edit | **pure code now**; optional **small local** model later | ~free, runs at toolkit speed | **YES** (no API at play-time) |

The intelligence that matters for *research* lives in the loop (hypothesize → edit →
measure → keep/discard). The candidate that plays is cheap, fast, deterministic-ish,
and — crucially — Kaggle-legal. The extension is language-agnostic about the
candidate (benchmark/checks are bash; scope is paths), so a **Python** candidate is
fine even though the self-bootstrap candidate was AILANG.

---

## 4. Locked design decisions

From the design discussion (2026-05-30):

1. **Start on a deliberately EASY public subset** to guarantee a gradient. If a
   code agent can't get off zero, the loop has nothing to climb. Headroom is the #1
   risk; we confirm it empirically in Phase 0 before building anything.
2. **Real submission is the actual goal** — design for the leaderboard, keep the
   candidate Kaggle-legal (offline) from day one.
3. **Noisy primary metric.** Give the candidate a **stochastic policy** (sampled
   tie-breaks / randomized exploration) so score varies across `samples` and
   median + MAD + confidence + patience are genuinely load-bearing.
4. **Local-only execution to start** (`ONLINE_ONLY=False`). Sidesteps the
   sandboxed-exec network question, API secrets, and rate limits; keeps `ar_run`
   cheap and fast. Online/API is a later option only if local games are
   insufficient.
5. **Play-time models:** pure code first. Later, *local* models with no token cost
   (or genuinely cheap local inference) may be considered — but **API models are
   barred at play-time** because they'd disqualify a Kaggle submission. (Cheap API
   models remain fine for the optimizer loop.)
6. **Phased build** (Section 7), gated on a Phase-0 go/no-go.

---

## 5. Mapping onto the autoresearch primitives

| autoresearch primitive | ARC-AGI-3 instantiation |
|---|---|
| candidate (`scope_paths`) | `experiments/arc_candidate/agent/` — the editable policy code |
| `benchmark_script` | run candidate over the fixed **train** game subset; print `METRIC ...` lines |
| primary metric | `score` — normalized levels completed across the train set (maximize) |
| noisy secondary | `wall_ms` and/or score variance from the stochastic policy |
| tie-breaker metric | `actions_used` (efficiency) and/or candidate LOC |
| `checks_script` | candidate imports + runs without crashing; respects `MAX_ACTIONS`/step budget; honors the `Agent` ABC contract; **anti-cheat: no game-id hardcoding / no peeking at hidden state**; train/test isolation intact |
| `off_limits` | the `arc-agi`/`arcengine` toolkit, the game/environment files, the scorer/harness, and the **held-out TEST game set** |
| held-out grading | a TEST subset of games **never** referenced in the loop; the true generalization measure and the submission proxy |
| `new_segment` | one segment per lever family: exploration → memory/world-model → action/coord selection → search/planning |
| patience / max_iterations | real stall dynamics; stop a segment when held-out-correlated train score plateaus |

### Metric definitions (draft)
- `METRIC score=<float>` — primary. Sum (or mean) of `levels_completed` over the
  train games, normalized to [0,1] by `win_levels`. **Maximize.**
- `METRIC wall_ms=<int>` — noisy secondary, real wall-clock. **Minimize.**
- `METRIC actions_used=<int>` — efficiency tie-breaker. **Minimize.**
- (Optional) `ASI` lines for per-game breakdowns for debugging.

> Note: the extension's primary path historically assumed `minimize`. Confirm the
> `direction: maximize` path is exercised/correct in `metrics.ail` (improvement
> test, stall count, confidence). If maximize is weak, define the primary as
> `levels_remaining` (minimize) instead. **TODO — verify in code during Phase 1.**

---

## 6. Anti-cheat / research integrity (the hard part)

The whole point of ARC-AGI-3 is "learn, don't memorize." Our loop must not
accidentally reward memorization, and the optimizer LLM must not be able to game
the metric:

1. **Train/test split.** Optimize only on the TRAIN subset; the TEST subset is
   `off_limits` and is used solely for an out-of-loop **grading** run. Improvement
   on TRAIN that doesn't transfer to TEST = overfitting, and is the headline thing
   we measure about autoresearch's discipline.
2. **No game-id branching.** `checks.sh` greps the candidate for hardcoded game ids
   / level-specific constants and fails if found. (Prefix/exact scope matching only
   — keep paths simple.)
3. **No hidden-state peeking.** Candidate may only use `FrameData` fields the real
   eval exposes; `checks.sh` forbids reaching into environment internals.
4. **Budget honesty.** `MAX_ACTIONS` and any timeout are enforced by the harness,
   not the candidate; candidate cannot raise its own budget.
5. **Immutability hashing** (as in self-bootstrap): hash the benchmark, checks,
   toolkit, and game files into `immutable.sha256`; both scripts verify it before
   running. Any drift = hard fail.
6. **Kaggle-legality check.** `checks.sh` fails if the candidate imports an API
   client (openai, requests-to-external, etc.) on the play path.

---

## 7. Phasing

### Phase 0 — Headroom spike (GO/NO-GO) — *in progress*
**Question:** can a cheap local code agent score >0 on some public subset, and is
that score improvable? If no, redesign before building anything.
- [x] Clone `arcprize/ARC-AGI-3-Agents`; confirm env (Python 3.12, `uv` present).
- [ ] `uv sync` the harness; resolve `arc-agi` toolkit.
- [ ] Determine whether **local** (offline, no API key) play works
      (`ONLINE_ONLY=False`) and which games ship locally vs. need a key.
- [ ] Run `--agent=random` on a few games (ls20, ft09, ...); record
      `levels_completed` distribution and per-game time.
- [ ] Write a trivial **heuristic** baseline (e.g. avoid no-ops, prefer actions
      that changed the frame last time, simple BFS over coords) and confirm it
      beats random on ≥1 game → proves a gradient exists.
- [ ] Pick the **easy TRAIN subset** (gradient present) and a disjoint **TEST
      subset**. Record baseline scores for both.
**Exit criteria:** documented baseline >0 with visible headroom on a named subset,
and a decision on local-vs-online.

### Phase 1 — Fixture harness (mirrors self-bootstrap fixtures)
Build, under `benchmarks/fixtures/arc_agi3/` (checked-in, immutable) +
`experiments/arc_candidate/` (the editable copy at run time):
- [ ] Vendored toolkit + chosen game files (pinned versions, hashed).
- [ ] Baseline candidate agent (`agent/` package) implementing the `Agent` ABC with
      a **stochastic** policy.
- [ ] `benchmark.sh` — runs candidate over TRAIN subset, prints the `METRIC` lines;
      scratch/recordings outside scoped paths (echo `AR_BENCH_SCRATCH` pattern).
- [ ] `checks.sh` — Section 6 anti-cheat + "runs without crashing" + ABC contract.
- [ ] `immutable.sha256` over benchmark/checks/toolkit/games/TEST set.
- [ ] Verify the autoresearch `maximize` metric path (Section 5 note).
**Exit criteria:** `benchmark.sh` and `checks.sh` run green by hand against the
baseline; metrics are stable across repeated runs within expected MAD.

### Phase 2 — Loop validation (cheap, short)
- [ ] Prompt + worktree scaffolding analogous to
      `benchmarks/prompts/autoresearch_self_bootstrap.md`, but with the **lever
      hidden** (objective + metric + guards only; no "here's the fix").
- [ ] A short autonomous run on a *tiny* TRAIN subset with a cheap optimizer model,
      to validate end-to-end: FSM gating, keep/discard under noise, commit/revert,
      worktree isolation, held-out grading step.
- [ ] Confirm: optimizer never edits `off_limits`; TEST set untouched; decisions
      are statistically sound (not keeping noise).
**Exit criteria:** a clean multi-iteration run with at least one *kept* improvement
that also moves the held-out TEST score.

### Phase 3 — The real run(s) (the ambitious test + submission build)
- [ ] Multi-segment, long-horizon run(s) over the full easy TRAIN subset with a
      capable optimizer model (DeepSeek-V4-Pro or better).
- [ ] Periodic held-out TEST grading; track train-vs-test gap (overfit detector).
- [ ] Expand subset difficulty as the agent improves.
- [ ] Package the best candidate as a Kaggle-legal submission (offline; MIT/CC0).
- [ ] Write up: autoresearch behavior (discovery, stats, patience) + absolute
      ARC-AGI-3 result.
**Exit criteria:** a submittable agent + a documented, reproducible research run.

---

## 8. Proposed layout

```
benchmarks/
  prompts/
    autoresearch_arc_agi3.md            # the (lever-hidden) optimization prompt
  fixtures/
    arc_agi3/
      bench/
        benchmark.sh                    # run candidate over TRAIN, emit METRIC
        checks.sh                       # anti-cheat + contract + no-crash
        immutable.sha256
      toolkit/                          # pinned arc-agi/arcengine (off-limits)
      games/
        train/                          # easy subset, in-loop (off-limits content)
        test/                           # held-out, grading only (off-limits)
experiments/
  arc_candidate/                        # created per run in the worktree
    agent/                              # THE EDITABLE CANDIDATE (scope_paths)
```

Run isolation reuses the self-bootstrap **git-worktree** model
(`/workspaces/motoko_agent_autoresearch_wt`, branch `autoresearch/arc-agi3-...`),
with the session DB kept in the main checkout via `ar_init(cwd=...)`.

---

## 9. Open questions / risks (to resolve as we build)

- **R1 Headroom (highest):** does a pure-code agent score >0 on *any* public game?
  Mitigated by Phase 0 + easy-subset + deliberately-improvable baseline.
- **R2 Local offline availability:** do public games run with `ONLINE_ONLY=False`
  and no API key, or is a key required to download environments? Affects "local
  only." *Verify in Phase 0.*
- **R3 Noise budget vs cost:** how many `samples` × games to make MAD meaningful
  without making `ar_run` slow? Stochastic policy helps create noise cheaply.
- **R4 `maximize` metric path** correctness in `metrics.ail` (Section 5 note).
- **R5 Determinism of games:** are games seeded/deterministic? If so, noise must
  come from the policy, not the env. *Verify in Phase 0.*
- **R6 Toolkit weight in sandbox:** `arc-agi` pulls numpy/langchain/etc.; ensure
  the benchmark sandbox can import it (or trim to a minimal play-time dep set —
  good for Kaggle anyway).
- **R7 Local model later (revised):** this container is a Linux Docker VM on a Mac
  **M1** — no NVIDIA GPU and **no direct Metal access** from the container. But the
  M1 GPU is reachable by serving the model on the **Mac host** (Ollama / llama.cpp /
  LM Studio, Metal-accelerated) and calling it from the container over
  `host.docker.internal`/localhost (a *local* socket, not a hosted API).
  - **Dev/optimization time:** fine to use the Metal-served model for fast iteration.
  - **Submission time:** must run **offline on Kaggle's NVIDIA GPUs** — the model we
    *ship* must fit that constraint.
  - **Transfer requirement:** to keep the research signal valid for the leaderboard,
    optimize against the **same model + inference path we intend to submit** (don't
    tune against a Mac-served model we won't ship). Until we commit to a model, stay
    **pure-code** so this is moot.
- **R8 Optimizer cost over a long horizon:** many iterations × a capable API model.
  Budget and consider DeepSeek-V4-Flash for exploration, Pro for hard segments.

---

## 10. Spike findings (2026-05-30, partial)

Environment:
- Python 3.12.3 at `/usr/bin/python3`; **no `pip` module**, but **`uv` 0.11.17**
  present (use `uv`). Net egress works (GitHub 200). **No NVIDIA GPU** (CPU only —
  matters for R7). ~55G free on `/`.
- Cloned harness to `/workspaces/arc_spike/ARC-AGI-3-Agents`.
- Harness deps (`pyproject.toml`): `arc-agi>=0.9.1`, langchain[openai], langgraph,
  openai==1.72.0, numpy, pillow, pydantic, smolagents, requests, dotenv.
- Agent ABC confirmed: `MAX_ACTIONS=80`, loop calls `choose_action`/`is_done`;
  `GameAction`/`GameState`/`FrameData` from `arcengine`; `EnvironmentWrapper`,
  `Arcade`, `OperationMode` from `arc_agi`.
- Templates available to crib from: `random_agent.py`, `llm_agents.py`,
  `reasoning_agent.py`, `langgraph_*`, `smolagents.py`, `multimodal.py`,
  `openclaw_agent`. Random agent reads `latest_frame.state`, RESETs on
  `NOT_PLAYED`/`GAME_OVER`, else random non-RESET action; complex actions get
  random `{x,y}` in 0–63.
- `.env.example`: default `OPERATION_MODE=online`, `ARC_BASE_URL=three.arcprize.org`,
  `ONLINE_ONLY` toggle mentioned, `ENVIRONMENTS_DIR=environment_files`. **Whether
  offline play needs a key is still UNVERIFIED (R2).**

**Spike scratch dir:** `/workspaces/arc_spike/` (outside the repo; safe to delete).

---

## 11. Next actions (resume here)

1. Finish Phase 0: `uv sync` the harness, try `uv run main.py --agent=random
   --game=ls20` offline (no key) and online (anon key), record scores + whether
   local works (R2/R5).
2. Write the deliberately-improvable heuristic baseline; confirm it beats random on
   ≥1 game → gradient proven.
3. Choose TRAIN/TEST subsets; record baselines.
4. Get the GO/NO-GO, then start Phase 1 fixtures.

> Operational playbook for runs (worktree cleanup, model override, monitoring via
> JSONL not the DB, between-run cleanup) is in
> `next-session-ambitious-test-handoff.md` §"Operational playbook" — reuse it
> verbatim, swapping `self-bootstrap` for `arc-agi3` branch/path names.
