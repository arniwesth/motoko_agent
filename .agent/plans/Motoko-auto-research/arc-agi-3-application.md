# Plan: ARC-AGI-3 application (the North Star — a 2026 prize submission)

**Status:** Draft / design (v1 — split out of the combined plan, v5).
**Author handoff date:** 2026-05-31
**Owner branch:** `autoresearch-research`
**Companion docs:**
- **`autoresearch-loop.md` — REQUIRED READING; this doc depends on it.** The
  autoresearch loop thesis, the primitive-mapping pattern, the anti-cheat/integrity
  methodology, literature-grounded ideation + `ar_scout`, and the Polyglot→TB warm-up
  all live there and are **not repeated here**.
- `implementation-plan.md` (Appendix A = self-bootstrap benchmark);
  `next-session-ambitious-test-handoff.md`.

> **Scope of this file.** The ARC-AGI-3 *application* of the autoresearch loop: what
> ARC-AGI-3 is, the Symbolica/Arcgentica study, the unified agent architecture, the
> ARC-specific instantiation of the primitive mapping, the ARC build phases, and the
> ARC-specific risks. For *how the loop itself works* (keep/discard discipline,
> integrity gates, literature ideation), see `autoresearch-loop.md`.

---

## 1. Goal (Objective #1: a competitive ARC-AGI-3 submission)

Use the autoresearch loop (see `autoresearch-loop.md`) to iteratively build an
ARC-AGI-3 agent aimed at the **ARC Prize 2026** (>$2M pool, open-source MIT/CC0
required). Checkpoints **Jun 30** and **Sep 30 2026**; submissions close **Nov 2 2026**.
We are "all in" — the agent should be aimed at the leaderboard.

This and Objective #2 (the loop itself) align: a disciplined optimize→measure→keep/
discard loop with held-out validation is how you build a non-overfit submission.

### Success criterion (this doc)
A Kaggle-legal (offline, MIT/CC0) agent whose held-out TEST score is materially above
the random/heuristic baseline; ideally an actual 2026 submission. (The loop-quality
criteria — sound keep/discard under noise, reproduction rate, small TRAIN/TEST gap,
lever-hidden discovery — are in `autoresearch-loop.md` §1 and first proven in the
warm-up.)

---

## 2. What ARC-AGI-3 is (verified 2026-05-30)

- Launched 2026-03-25 by the ARC Prize Foundation (Chollet, Knoop).
- **Interactive** benchmark: **135 turn-based game environments**
  (public / semi-private / fully-private), handcrafted, **no instructions, no goals,
  no rules**. The agent discovers mechanics by interacting. Measures
  skill-acquisition efficiency / fluid intelligence.
- Difficulty: at release frontier LLMs scored **<1%** (humans 100%). Naive
  frontier-LLM-in-the-loop cost **$5k–9k per task**.
- **Two leading documented results we studied** (neither is the outright SOTA — the
  private leaderboard has higher — but both are reproducible starting points):
  - **Symbolica's Arcgentica**: **36.08%** on the 25 public games (113/182 levels,
    7/25 complete) for **~$1,005** — vs Opus 4.6 at 0.25% for $8,900 (~120×
    cost-efficiency). See §3.
  - **Training-free graph-exploration** (arXiv:2512.24156): median 30/52 levels,
    **3rd on the private leaderboard**, beating LLM agents, **code released**
    (`arc-agi-3-just-explore`). A strong, offline-legal, no-model lever — try early.
- **Toolkit:** `arc-agi` (PyPI, `>=0.9.1`) + harness `arcprize/ARC-AGI-3-Agents`
  (`uv run main.py --agent=random --game=ls20`).
  - Actions: `GameAction.ACTION1..ACTION7` + `RESET`. `ACTION6` is "click" and carries
    `{x,y}` (0–63). `available_actions` varies per level.
  - Observations: `FrameData` — `frame` (grid of ints 0–15), `state` (`GameState`:
    `NOT_PLAYED`/`NOT_FINISHED`/`WIN`/`GAME_OVER`), `levels_completed` (was `score`
    pre-0.9.3), `win_levels`, `available_actions`, `guid`.
  - Agent ABC (`agents/agent.py`): implement `choose_action` + `is_done` (or override
    `main()`). Base-class default `MAX_ACTIONS=80`; agents raise it (Arcgentica →
    10,000). The game's own limit (**~800 actions across levels**) is the real budget.
  - Harness 0.9.3 supports **local execution** of environments (`ONLINE_ONLY=False`,
    `ENVIRONMENTS_DIR=environment_files`); online API/replay needs `ARC_API_KEY`.
- **Submission constraint (load-bearing):** Kaggle eval is **offline — no internet, no
  external inference during scoring.** A submittable candidate may use **pure code**
  and/or a **local model (weights on the eval box)**, but **NOT** a hosted API model at
  play-time.

Sources: arcprize.org/blog/arc-agi-3-launch, docs.arcprize.org/agents-quickstart,
github.com/arcprize/ARC-AGI-3-Agents, github.com/arcprize/arc-agi,
symbolica.ai/blog/arc-agi-3, github.com/symbolica-ai/ARC-AGI-3-Agents (branch
`symbolica/arcgentica`), github.com/symbolica-ai/agentica-server, arXiv:2512.24156,
arXiv:2603.24621 (the ARC-AGI-3 benchmark paper).

---

## 3. What we learned from Symbolica's Arcgentica (a leading documented agent)

Read the actual source (MIT), not the blog. Arcgentica is a **"reasoning-as-code"
(RLM) multi-agent system**, not an LLM picking actions from prose:

- **The reasoner reasons by writing & running Python in a REPL.** `agentica.spawn(
  model, premise, scope=...)` hands an LLM a sandbox with injected objects (`numpy`,
  the `Frame` helpers, `submit_action`, `Memories`). It diffs frames, tests hypotheses,
  and executes action sequences **in code**. This is the "program synthesis" behind the
  120× efficiency — and it *is* the "LLM-as-policy-synthesizer" idea. Proven, and among
  the strongest documented approaches (see §2 for leaderboard context).
- **Orchestrator + specialized subagents** (`explorer → theorist → tester → solver`).
  The orchestrator **never touches the game** (looking at grids fills its context with
  pixels and kills strategic thinking). Theorists are **denied `submit_action`** so
  they can't waste moves. **Context hygiene is a first-class strategy.**
- **Shared `memories` DB** with an LLM-backed natural-language `query`, persisting
  knowledge across agent lifetimes (retire a context-saturated agent, spawn a fresh
  one, keep the knowledge).
- **Spatial toolkit** (`Frame`): `render`, `diff` (clustered `DiffRegion`s),
  `render_diff`, `change_summary`, `find`, `bounding_box`, `color_counts`. "Compute over
  frames, don't eyeball them."
- **Action budgets** via `make_bounded_submit_action(limit)`; the *real* budget is
  **~800 actions across levels** (the `MAX_ACTIONS=10_000` override is just a ceiling).
  RESET/NOOP are free. Heavy discipline prompting.
- **A long, game-agnostic `GAME_REFERENCE`/premise** encoding ARC meta-strategy:
  hypotheses must be **relational, not coordinate-based**; reproduce-before-trust;
  `history()` post-mortems when reality diverges; when (not) to RESET; when to stop and
  hand off. Months of prompt engineering, MIT-licensed.
- **Models used: Opus 4.6 / GPT-5.2**, high reasoning effort, 200–400k context.
  Frontier and expensive.

**The swappable seam:** not an HTTP shim — the **REPL `scope` + `ModelConfig`**. The
reasoner is "an LLM that executes Python over an injected scope." Two consequences:
(a) the closed `agentica` runtime is conceptually "a code-executing agent loop," and
`symbolica-ai/agentica-server` is itself **open-source** (self-hostable, point at any
provider incl. a local model); (b) **Motoko slots in exactly here** — give Motoko a
sandboxed Python-exec tool + the `Frame` scope and it *becomes* an Arcgentica-class RLM.

**Sobering truth for the prize:** 36% used *frontier* models. A small offline-legal
local model in the same scaffold will score far lower — the model gap is the real
mountain (R-cost / R-modelgap).

---

## 4. The unified architecture

There is **one stack** with **swappable parts**:

```
ARC-AGI-3 toolkit  ─▶  thin player / scaffolding  ─▶  reasoner  ─▶  model backend
(games, FrameData)     (Frame helpers, prompts,       (RLM loop:    (none / local /
                        memories, budgets,             write+run      API)
                        orchestration)                 Python)
```

Two independent axes (not three tracks):

| | **Heavy reasoning at play-time (agentic RLM)** | **Heavy reasoning at dev-time (synthesize-then-run)** |
|---|---|---|
| **No model at play** | — | model writes a per-level program; code plays |
| **Local model at play** | Motoko-as-RLM w/ local model ✅ submittable | tune a small-local-model policy |
| **API model at play** | Arcgentica-style (showcase) ❌ not submittable | dev-only |

- **Submittability depends only on the backend** (none/local = ✅; API = ❌). Not on the
  architecture.
- **"Synthesize-then-run"** (right column) = the reasoner emits a reusable program per
  level so play needs few/zero model calls. The key lever for both **loop cost** and
  **offline viability**.

**What autoresearch optimizes (the candidate-under-edit):** the **scaffolding** —
premise/`GAME_REFERENCE` wording, subagent topology, per-role action budgets, memory
policy, frame-rendering choices, model/sampling config, and the synthesize-then-run
structure. The scaffolding transfers across models; only the backend changes between
dev and submission.

**Headline path:** **Motoko-as-RLM, built on Symbolica's MIT scaffolding,
autoresearched against a local model, aimed at an offline submission.** This unifies
"Motoko plays" + "autoresearch optimizes" + "real submission."

### Reuse vs. build
- **Reuse (MIT, adapt directly — keep attribution):** `Frame` + helpers, the
  orchestrator/subagent prompts, the `Memories` pattern, the budget wrapper, the
  agent.py bookkeeping (reset guards, level-transition detection via `levels_completed`,
  `history`).
- **Build or host (the hard core — the RLM runtime), three options:**
  1. **Self-host `agentica-server`** pointed at a local model (fastest to a working
     RLM; least "ours").
  2. **Reimplement a minimal write-and-run-Python agent loop** (full control; real
     work).
  3. **Make Motoko the RLM** — give Motoko code-exec + the `Frame` scope (most on-brand,
     most ambitious; this is "Motoko plays").

---

## 5. ARC-specific design decisions

(General loop decisions — optimizer≠player, train/test split, literature ideation — are
in `autoresearch-loop.md`. These are the ARC-specific ones.)

1. **Phase 0 spike = pure-code headroom FIRST** (cheapest signal). Confirm a gradient
   exists before standing up any RLM/model machinery.
2. Start on a deliberately **easy public game subset** (guarantee a gradient).
3. Real **submission is the actual goal**; keep the play path **offline-legal**.
4. **Noisy primary metric** (LLM stochasticity once a model is in the loop; before that,
   a stochastic code policy) — see the `metrics.ail` crux in `autoresearch-loop.md` §2.
5. **Local-only execution** of games to start (`ONLINE_ONLY=False`) — *contingent on
   R2*: verify offline play works without an API key; fall back to anon/keyed online
   if not.
6. **Optimizer ≠ player.** Optimizer = cheap **API** model (DeepSeek-V4 Flash/Pro),
   dev-time only. Player/reasoner backend = pure code, then **local** model. **No API
   model at play-time** (would break submittability).
7. **Optimize against the model we'll ship** (local), for both cost and transfer.

---

## 6. ARC instantiation of the primitive mapping

| autoresearch primitive | ARC-AGI-3 instantiation |
|---|---|
| candidate (`scope_paths`) | the editable **scaffolding** (prompts, orchestration, budgets, frame-rendering, model config) — `experiments/arc_candidate/agent/` |
| `benchmark_script` | run candidate over the fixed **TRAIN** subset; print `METRIC` lines |
| primary metric | `score` — normalized levels completed across TRAIN (**maximize, noisy**) |
| noisy secondary | `wall_ms` (real wall-clock). Score noise lives in the *primary* |
| tie-breakers | `actions_used` (efficiency), token/inference cost. **NOT LOC** — a size penalty would pressure the optimizer to delete useful prompt/scaffolding (Arcgentica's edge is a *long* `GAME_REFERENCE`) |
| `checks_script` | runs without crashing; honors the `Agent` ABC + action budget; anti-cheat (no hidden-state peeking); **Kaggle-legality** (no API client on the play path); train/test isolation |
| `off_limits` | the `arc-agi`/`arcengine` toolkit, the game/environment files, the scorer/harness, the reused MIT `Frame`/runtime code, and the **held-out TEST set** |
| held-out grading | TEST subset never referenced in the loop; the generalization measure + submission proxy |
| `new_segment` | one segment per lever family: exploration prompts → world-model/memory → subagent topology/budgets → action/coord selection → synthesize-then-run |
| patience / max_iterations | stop a segment when TRAIN score plateaus |

### Metric definitions (draft)
- `METRIC score=<float>` — primary. Mean `levels_completed / win_levels` over TRAIN
  games, in [0,1]. **Maximize; noisy** (stochastic policy) — capture with `samples>1`.
- `METRIC wall_ms=<int>` — noisy secondary. **Minimize.**
- `METRIC actions_used=<int>` — efficiency tie-breaker. **Minimize.**
- (Optional) `ASI` lines for per-game breakdowns.

> See `autoresearch-loop.md` §2 TODO for the `metrics.ail` maximize/noisy-primary
> verification — load-bearing for this metric design. If maximize is weak, define the
> primary as `levels_remaining` (minimize).

ARC-specific anti-cheat: no game-id branching / level-specific constants (a **weak
smell-test** grep only — held-out TEST transfer is the real signal); candidate may only
use `FrameData` fields the real eval exposes. General integrity gates (separate
verifier, oracle-vs-nop, cheat trials, canary, 100+ trials) are in `autoresearch-loop.md`
§3/§3a.

---

## 7. ARC build phases

> Prerequisite: the loop machinery is validated by the **Polyglot→TB warm-up**
> (`autoresearch-loop.md` §5). Phase 0 below can run in parallel with the warm-up
> (it's just measurement), but Phases 1–3 assume the machinery works.

### Phase 0 — Pure-code ARC headroom spike (GO/NO-GO) — *in progress*
**Scope: pure code only. No model, no RLM runtime yet.** Cheapest signal first.
**Question:** can a cheap *code* agent score >0 on some easy public subset, and is that
score improvable?
- [x] Clone `arcprize/ARC-AGI-3-Agents`; env confirmed (Python 3.12, `uv`, net OK, no
      GPU).
- [ ] `uv sync` the harness; resolve the `arc-agi` toolkit.
- [ ] Determine whether **local** offline play works (no API key) and which games ship
      locally vs. need a key (R2).
- [ ] Run `--agent=random` on a few games (ls20, ft09, vc33, ...); record
      `levels_completed` distribution + per-game time; check determinism (R5).
- [ ] Write a deliberately-improvable **heuristic** code agent (e.g. avoid no-ops,
      prefer actions that changed the frame last time, simple BFS over click coords) and
      confirm it beats random on ≥1 game → gradient proven.
- [ ] Pick the **easy TRAIN subset** + a disjoint **TEST subset**; record baselines.
**Exit:** documented baseline >0 with visible headroom on a named subset, plus a
local-vs-online decision.
**If NO-GO** (no pure-code agent beats random on any reasonable subset): pick an easier
subset, or accept that pure code lacks headroom and move the model into the play loop
earlier (run Phase 2's runtime standup before fixtures). The literature signal
(training-free graph-exploration scored well *without* a model) argues a code gradient
should exist — but confirm, don't assume.

### Phase 1 — ARC fixture harness + reused scaffolding
- [ ] Adapt Symbolica's MIT `Frame` helpers into the candidate (attribution kept).
- [ ] Baseline candidate package implementing the `Agent` ABC with a **stochastic**
      policy.
- [ ] `benchmark.sh` (runs candidate over TRAIN, emits `METRIC` lines; scratch outside
      scoped paths, per `AR_BENCH_SCRATCH` pattern) + `checks.sh` (§6 + the integrity
      gates from `autoresearch-loop.md` §3).
- [ ] `grade_test.sh` — operator-only held-out grader over the TEST subset
      (separate-verifier model, `autoresearch-loop.md` §3.5); **not** referenced by
      `benchmark.sh`/`checks.sh`.
- [ ] `immutable.sha256` over benchmark/checks/grader/toolkit/games/TEST.
- [ ] Apply §3a QA gates: oracle-vs-no-op, a cheat trial, 100+-trial stability.
- [ ] Verify the `metrics.ail` maximize/noisy-primary path (`autoresearch-loop.md` §2).
**Exit:** scripts green by hand against the baseline; oracle passes & no-op fails;
metrics stable within expected MAD across repeats.

### Phase 2 — Stand up the RLM runtime (local model) + loop validation
- [ ] Choose a runtime option (§4): self-host `agentica-server` w/ local model, minimal
      reimpl, or Motoko-as-RLM. **Measure per-step latency/cost** on this hardware (M1
      GPU via host-served inference) — a rough *dev-cost* proxy only; Kaggle NVIDIA
      latency differs and bounds the submission model separately.
- [ ] Lever-hidden optimization prompt (objective + metric + guards only).
- [ ] Short autonomous run on a *tiny* TRAIN subset with a cheap optimizer model:
      validate FSM gating, keep/discard under noise, commit/revert, worktree isolation,
      held-out grading.
**Exit:** a clean multi-iteration run with ≥1 kept improvement that also moves the
held-out TEST score.

### Phase 3 — The real run(s) + submission build
- [ ] Multi-segment, long-horizon run(s) over the easy TRAIN subset; expand difficulty
      as the agent improves.
- [ ] Periodic held-out TEST grading; track train-vs-test gap (overfit detector).
- [ ] Lean on **synthesize-then-run** to cut play-time model calls (cost + offline).
- [ ] Package the best candidate as a Kaggle-legal (offline, MIT/CC0) submission.
- [ ] Write-up: autoresearch behavior (discovery, stats, patience) + absolute score.
**Exit:** a submittable agent + a documented, reproducible research run.

---

## 8. Proposed layout (ARC fixtures)

```
benchmarks/
  prompts/
    autoresearch_arc_agi3.md            # lever-hidden optimization prompt
  fixtures/
    arc_agi3/
      bench/
        benchmark.sh                    # run candidate over TRAIN, emit METRIC
        checks.sh                       # anti-cheat + contract + no-crash + legality
        grade_test.sh                   # operator-only held-out grader (NOT wired into benchmark)
        immutable.sha256
      toolkit/                          # pinned arc-agi/arcengine + reused MIT runtime (off-limits)
      games/
        train/                          # easy subset, in-loop (off-limits content)
        test/                           # held-out, grading only (off-limits)
experiments/
  arc_candidate/                        # created per run in the worktree
    agent/                              # THE EDITABLE SCAFFOLDING (scope_paths)
.motoko/autoresearch/                   # session DB (main checkout, survives worktree)
  papers/                               # cached papers/code + ledger.md (provenance)
```

Run isolation reuses the self-bootstrap **git-worktree** model
(`/workspaces/motoko_agent_autoresearch_wt`, branch `autoresearch/arc-agi3-...`),
session DB in the main checkout via `ar_init(cwd=...)`.

---

## 9. ARC-specific risks

(Machinery-level risks — R-scout, noise budget, `metrics.ail`, Docker, scope creep —
are in `autoresearch-loop.md` §6.)

- **R1 Headroom (highest):** does a pure-*code* agent score >0 on any easy game?
  Mitigated by Phase 0 + easy subset + deliberately-improvable baseline.
- **R2 Local offline availability:** do public games run with `ONLINE_ONLY=False` and no
  API key, or is a key required to fetch environments? *Verify in Phase 0.*
- **R-cost (binding constraint):** an agentic eval ≈ Symbolica's ~$40/game with frontier
  models × ~800 actions × multi-agent — far too costly for hundreds of optimization
  iterations. The loop **must** drive a cheap/local reasoner; restrict to a tiny TRAIN
  subset + few samples early; lean on synthesize-then-run.
- **R-modelgap (prize-critical):** 36% used frontier models; a small offline-legal local
  model will score far lower. The scaffolding transfers; the model gap is the mountain.
  Synthesize-then-run partly mitigates.
- **R-runtime:** standing up/reimplementing an RLM runtime (or Motoko-as-RLM) is real
  work. Self-hosting `agentica-server` is the fast path to a working baseline.
- **R5 Game determinism:** if games are seeded/deterministic, noise must come from the
  policy/model, not the env. *Verify in Phase 0.*
- **R6 Toolkit weight in sandbox:** `arc-agi` pulls numpy/langchain/etc.; ensure the
  benchmark sandbox can import it (or trim to a minimal play-time dep set — good for
  Kaggle anyway).
- **R7 Local model on M1:** container is a Linux VM on a Mac **M1** — no NVIDIA GPU, no
  direct Metal. Reach the M1 GPU by serving the model on the **Mac host** (Ollama /
  llama.cpp / vLLM, Metal) and calling over `host.docker.internal`/localhost (local
  socket, not a hosted API).
  - Dev/optimization: Metal-served model is fine for speed.
  - Submission: must run **offline on Kaggle's NVIDIA GPUs**; the shipped model must fit
    that envelope.
  - **Transfer:** optimize against the **same model + path** we intend to submit. Until
    we commit to a model, stay pure-code so this is moot.
- **R8 Optimizer cost over long horizon:** DeepSeek-V4-Flash for exploration, Pro for
  hard segments.

---

## 10. Spike findings (2026-05-30, partial)

Environment:
- Python 3.12.3 at `/usr/bin/python3`; **no `pip` module**, but **`uv` 0.11.17** present
  (use `uv`). Net egress works. **No NVIDIA GPU** (CPU only — see R7). ~55G free on `/`.
- Cloned harness to `/workspaces/arc_spike/ARC-AGI-3-Agents`.
- Symbolica fork cloned to `/workspaces/arc_spike/symbolica-arc` (branch
  `symbolica/arcgentica`). Studied: `agents/templates/agentica/{agent,prompts,model,
  scope/frame,scope/memories}.py` + `IDEA.md` + `SYMBOLICA_README.md` (§3).
- Harness deps (`pyproject.toml`): `arc-agi>=0.9.1`, langchain[openai], langgraph,
  openai==1.72.0, numpy, pillow, pydantic, smolagents, requests, dotenv.
- Agent ABC confirmed: `MAX_ACTIONS=80` default, loop calls `choose_action`/`is_done`;
  `GameAction`/`GameState`/`FrameData` from `arcengine`; `EnvironmentWrapper`/`Arcade`/
  `OperationMode` from `arc_agi`.
- `.env.example`: default `OPERATION_MODE=online`, `ONLINE_ONLY` toggle,
  `ENVIRONMENTS_DIR=environment_files`. **Offline-no-key play still UNVERIFIED (R2).**
- `agentica-server` is open-source (self-hostable, multi-provider) — relevant to the
  Phase-2 runtime decision.
- Terminal-Bench-Science cloned to `/workspaces/arc_spike/tbs` (methodology study →
  fed `autoresearch-loop.md` §3).

**Spike scratch dir:** `/workspaces/arc_spike/` (outside the repo; safe to delete).

---

## 11. Next actions (resume here)

**Track B — ARC pure-code headroom (Phase 0, in progress; runs parallel to the warm-up
in `autoresearch-loop.md`):**
1. `uv sync` the harness; `uv run main.py --agent=random --game=ls20` offline (no key)
   then online (anon key); record scores + whether local works (R2/R5).
2. Deliberately-improvable heuristic *code* baseline; confirm it beats random on ≥1
   game → gradient proven.
3. Choose TRAIN/TEST subsets; record baselines. **GO/NO-GO**, then Phase 1.

The loop machinery these phases depend on is validated first in `autoresearch-loop.md`
§5 (the Polyglot warm-up). Operational playbook (worktree cleanup, model override,
JSONL monitoring) is in `next-session-ambitious-test-handoff.md`.
