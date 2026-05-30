# Plan: Autoresearch-driven optimization of an ARC-AGI-3 agent

**Status:** Draft / design (v2 — incorporates Symbolica/Arcgentica study).
**Author handoff date:** 2026-05-30
**Owner branch:** `autoresearch-research`
**Companion docs:** `implementation-plan.md` (Appendix A = self-bootstrap benchmark),
`next-session-ambitious-test-handoff.md` (the "design a more ambitious test" handoff
this plan answers).

---

## 1. Goal

Use the `motoko-ext-autoresearch` extension as the **research/optimization loop**
that iteratively improves an ARC-AGI-3 **agent**, with two explicit objectives:

1. **Primary (the real goal): a competitive ARC-AGI-3 submission.** ARC Prize 2026
   is live (>$2M pool, open-source MIT/CC0 required). Checkpoints **Jun 30** and
   **Sep 30 2026**; submissions close **Nov 2 2026**.
2. **Secondary (still important): an ambitious test of autoresearch.** This target
   finally exercises everything the self-bootstrap test left asleep — open search,
   no known optimum, a **genuinely noisy** primary metric (so MAD / confidence /
   patience drive keep/discard), long horizon, multi-segment, real anti-cheat
   (train/test generalization).

These align: a disciplined optimize→measure→keep/discard loop with held-out
validation is how you build a non-overfit submission.

---

## 2. What ARC-AGI-3 is (verified 2026-05-30)

- Launched 2026-03-25 by the ARC Prize Foundation (Chollet, Knoop).
- **Interactive** benchmark: **135 turn-based game environments**
  (public / semi-private / fully-private), handcrafted, **no instructions, no goals,
  no rules**. The agent discovers mechanics by interacting. Measures
  skill-acquisition efficiency / fluid intelligence.
- Difficulty: at release frontier LLMs scored **<1%** (humans 100%). Naive
  frontier-LLM-in-the-loop cost **$5k–9k per task**.
- **Symbolica's Arcgentica** is the strongest public result: **36.08%** on the 25
  public games (113/182 levels, 7/25 games complete) for **~$1,005** — vs Opus 4.6
  at 0.25% for $8,900. ~120× cost-efficiency. See Section 3.
- **Toolkit:** `arc-agi` (PyPI, `>=0.9.1`) + harness `arcprize/ARC-AGI-3-Agents`
  (`uv run main.py --agent=random --game=ls20`).
  - Actions: `GameAction.ACTION1..ACTION7` + `RESET`. `ACTION6` is "click" and
    carries `{x,y}` (0–63). `available_actions` varies per level.
  - Observations: `FrameData` — `frame` (grid of ints 0–15), `state` (`GameState`:
    `NOT_PLAYED`/`NOT_FINISHED`/`WIN`/`GAME_OVER`), `levels_completed` (was `score`
    pre-0.9.3), `win_levels`, `available_actions`, `guid`.
  - Agent ABC (`agents/agent.py`): implement `choose_action` + `is_done`
    (or override `main()`). Default `MAX_ACTIONS=80` (a safety ceiling, not the real
    budget — see Section 3).
  - Harness 0.9.3 supports **local execution** of environments
    (`ONLINE_ONLY=False`, `ENVIRONMENTS_DIR=environment_files`); online API/replay
    needs `ARC_API_KEY`.
- **Submission constraint (load-bearing):** Kaggle eval is **offline — no internet,
  no external inference during scoring.** A submittable candidate may use **pure
  code** and/or a **local model (weights on the eval box)**, but **NOT** a hosted
  API model at play-time.

Sources: arcprize.org/blog/arc-agi-3-launch, docs.arcprize.org/agents-quickstart,
github.com/arcprize/ARC-AGI-3-Agents, github.com/arcprize/arc-agi,
symbolica.ai/blog/arc-agi-3, github.com/symbolica-ai/ARC-AGI-3-Agents (branch
`symbolica/arcgentica`), github.com/symbolica-ai/agentica-server.

---

## 3. What we learned from Symbolica's Arcgentica (the SOTA)

Read the actual source (MIT), not the blog. Arcgentica is a **"reasoning-as-code"
(RLM) multi-agent system**, not an LLM picking actions from prose:

- **The reasoner reasons by writing & running Python in a REPL.** `agentica.spawn(
  model, premise, scope=...)` hands an LLM a sandbox with injected objects (`numpy`,
  the `Frame` helpers, `submit_action`, `Memories`). It diffs frames, tests
  hypotheses, and executes action sequences **in code**. This is the "program
  synthesis" behind the 120× efficiency — and it *is* our "LLM-as-policy-synthesizer"
  idea. Proven, SOTA.
- **Orchestrator + specialized subagents** (`explorer → theorist → tester →
  solver`). The orchestrator **never touches the game** (looking at grids fills its
  context with pixels and kills strategic thinking). Theorists are **denied
  `submit_action`** so they can't waste moves. **Context hygiene is a first-class
  strategy.**
- **Shared `memories` DB** with an LLM-backed natural-language `query`, persisting
  knowledge across agent lifetimes (retire a context-saturated agent, spawn a fresh
  one, keep the knowledge).
- **Spatial toolkit** (`Frame`): `render`, `diff` (clustered `DiffRegion`s),
  `render_diff`, `change_summary`, `find`, `bounding_box`, `color_counts`. "Compute
  over frames, don't eyeball them."
- **Action budgets** via `make_bounded_submit_action(limit)`; the *real* budget is
  **~800 actions across levels** (the `MAX_ACTIONS=10_000` override is just a ceiling).
  RESET/NOOP are free. Heavy discipline prompting.
- **A long, game-agnostic `GAME_REFERENCE`/premise** encoding ARC meta-strategy:
  hypotheses must be **relational, not coordinate-based**; reproduce-before-trust;
  `history()` post-mortems when reality diverges; when (not) to RESET; when to stop
  and hand off. Months of prompt engineering, MIT-licensed.
- **Models used: Opus 4.6 / GPT-5.2**, high reasoning effort, 200–400k context.
  Frontier and expensive.

**The swappable seam (corrected):** it's not an HTTP shim — it's the **REPL `scope`
+ `ModelConfig`**. The reasoner is "an LLM that executes Python over an injected
scope." Two consequences: (a) the closed `agentica` runtime is conceptually "a
code-executing agent loop," and `symbolica-ai/agentica-server` is itself
**open-source** (self-hostable, point it at any provider incl. a local model);
(b) **Motoko slots in exactly here** — give Motoko a sandboxed Python-exec tool +
the `Frame` scope and it *becomes* an Arcgentica-class RLM.

**Sobering truth for the prize:** 36% used *frontier* models. A small offline-legal
local model in the same scaffold will score far lower — the model gap is the real
mountain (see R-cost / R-modelgap).

---

## 4. The unified architecture

The earlier "tracks A/B/C" framing was misleading. There is **one stack** with
**swappable parts**:

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

- **Submittability depends only on the backend** (none/local = ✅; API = ❌). Not on
  the architecture.
- **"Synthesize-then-run"** (right column) = have the reasoner emit a reusable
  program per level so play needs few/zero model calls. It's the key lever for both
  **loop cost** and **offline viability**.

**What autoresearch optimizes (the candidate-under-edit):** the **scaffolding** —
premise/`GAME_REFERENCE` wording, subagent topology, per-role action budgets, memory
policy, frame-rendering choices, model/sampling config, and the synthesize-then-run
structure. The scaffolding work transfers across models; only the backend changes
between dev and submission.

**Headline path:** **Motoko-as-RLM, built on Symbolica's MIT scaffolding,
autoresearched against a local model, aimed at an offline submission.** This unifies
"Motoko plays" + "autoresearch optimizes" + "real submission."

### Reuse vs. build
- **Reuse (MIT, adapt directly — keep attribution):** `Frame` + helpers, the
  orchestrator/subagent prompts, the `Memories` pattern, the budget wrapper, and the
  agent.py bookkeeping (reset guards, level-transition detection via
  `levels_completed`, `history`).
- **Build or host (the hard core — the RLM runtime), three options:**
  1. **Self-host `agentica-server`** pointed at a local model (fastest to a working
     RLM; least "ours").
  2. **Reimplement a minimal write-and-run-Python agent loop** (full control;
     real work).
  3. **Make Motoko the RLM** — give Motoko code-exec + the `Frame` scope (most
     on-brand, most ambitious; this is "Motoko plays").

---

## 5. Locked design decisions

1. **Phase 0 spike = pure-code headroom FIRST** (cheapest possible signal). Confirm a
   gradient exists before standing up any RLM/model machinery.
2. Start on a deliberately **easy public game subset** (guarantee a gradient).
3. Real **submission is the actual goal**; keep the play path **offline-legal**.
4. **Noisy primary metric** (LLM stochasticity once a model is in the loop; before
   that, a stochastic code policy) so MAD/confidence/patience are load-bearing.
5. **Local-only execution** of games to start (`ONLINE_ONLY=False`).
6. **Optimizer ≠ player.** Optimizer = autoresearch's cheap **API** model
   (DeepSeek-V4 Flash/Pro) — dev-time only, fine. Player/reasoner backend = pure
   code, then **local** model. **No API model at play-time** (would break
   submittability).
7. **Optimize against the model we'll ship** (local), for both cost and transfer.
8. **Train/test split** anti-cheat: optimize on TRAIN, grade on held-out TEST
   (`off_limits`); the train-vs-test gap is the overfit/discipline measure.
9. **Phased build**, gated on the Phase-0 go/no-go.

---

## 6. Mapping onto the autoresearch primitives

| autoresearch primitive | ARC-AGI-3 instantiation |
|---|---|
| candidate (`scope_paths`) | the editable **scaffolding** (prompts, orchestration, budgets, frame-rendering, model config) — `experiments/arc_candidate/agent/` |
| `benchmark_script` | run candidate over the fixed **TRAIN** subset; print `METRIC` lines |
| primary metric | `score` — normalized levels completed across TRAIN (maximize) |
| noisy secondary | `wall_ms` and/or score variance (stochastic policy / LLM sampling) |
| tie-breakers | `actions_used` (efficiency), token cost, candidate LOC |
| `checks_script` | candidate runs without crashing; honors the `Agent` ABC + action budget; **anti-cheat** (no game-id hardcoding, no hidden-state peeking); **Kaggle-legality** (no API client on the play path); train/test isolation |
| `off_limits` | the `arc-agi`/`arcengine` toolkit, the game/environment files, the scorer/harness, the reused MIT `Frame`/runtime code, and the **held-out TEST set** |
| held-out grading | TEST subset never referenced in the loop; the true generalization measure + submission proxy |
| `new_segment` | one segment per lever family: exploration prompts → world-model/memory → subagent topology/budgets → action/coord selection → synthesize-then-run |
| patience / max_iterations | real stall dynamics; stop a segment when TRAIN score plateaus |

### Metric definitions (draft)
- `METRIC score=<float>` — primary. Mean `levels_completed / win_levels` over TRAIN
  games, in [0,1]. **Maximize.**
- `METRIC wall_ms=<int>` — noisy secondary. **Minimize.**
- `METRIC actions_used=<int>` — efficiency tie-breaker. **Minimize.**
- (Optional) `ASI` lines for per-game breakdowns.

> **TODO (Phase 1):** verify the `direction: maximize` path in `metrics.ail`
> (improvement test, stall count, confidence) — self-bootstrap only exercised
> `minimize`. If maximize is weak, define the primary as `levels_remaining`
> (minimize).

---

## 7. Anti-cheat / research integrity

1. **Train/test split.** Optimize only on TRAIN; TEST is `off_limits`, used solely
   for out-of-loop grading. TRAIN gains that don't transfer to TEST = overfitting —
   the headline thing we measure about autoresearch's discipline.
2. **No game-id branching / level-specific constants.** `checks.sh` greps and fails.
3. **No hidden-state peeking** — only `FrameData` fields the real eval exposes.
4. **Budget honesty** — `MAX_ACTIONS`/timeout enforced by the harness, not the
   candidate.
5. **Immutability hashing** — hash benchmark, checks, toolkit, game files, TEST set
   into `immutable.sha256`; both scripts verify before running.
6. **Kaggle-legality** — `checks.sh` fails if the candidate imports an API client on
   the play path.

---

## 8. Phasing

### Phase 0 — Pure-code headroom spike (GO/NO-GO) — *in progress*
**Scope: pure code only. No model, no RLM runtime yet.** Cheapest signal first.
**Question:** can a cheap *code* agent score >0 on some easy public subset, and is
that score improvable?
- [x] Clone `arcprize/ARC-AGI-3-Agents`; env confirmed (Python 3.12, `uv`, net OK,
      no GPU).
- [ ] `uv sync` the harness; resolve the `arc-agi` toolkit.
- [ ] Determine whether **local** offline play works (no API key) and which games
      ship locally vs. need a key (R2).
- [ ] Run `--agent=random` on a few games (ls20, ft09, vc33, ...); record
      `levels_completed` distribution + per-game time; check determinism (R5).
- [ ] Write a deliberately-improvable **heuristic** code agent (e.g. avoid no-ops,
      prefer actions that changed the frame last time, simple BFS over click coords)
      and confirm it beats random on ≥1 game → gradient proven.
- [ ] Pick the **easy TRAIN subset** + a disjoint **TEST subset**; record baselines.
**Exit:** documented baseline >0 with visible headroom on a named subset, plus a
local-vs-online decision.

### Phase 1 — Fixture harness + reused scaffolding
- [ ] Adapt Symbolica's MIT `Frame` helpers into the candidate (attribution kept).
- [ ] Baseline candidate package implementing the `Agent` ABC with a **stochastic**
      policy.
- [ ] `benchmark.sh` (runs candidate over TRAIN, emits `METRIC` lines; scratch
      outside scoped paths, per `AR_BENCH_SCRATCH` pattern) + `checks.sh` (Section 7).
- [ ] `immutable.sha256` over benchmark/checks/toolkit/games/TEST.
- [ ] Verify the autoresearch `maximize` metric path (Section 6 TODO).
**Exit:** both scripts green by hand against the baseline; metrics stable within
expected MAD across repeats.

### Phase 2 — Stand up the RLM runtime (local model) + loop validation
- [ ] Choose a runtime option (Section 4): self-host `agentica-server` w/ local
      model, minimal reimpl, or Motoko-as-RLM. **Measure real per-step latency/cost**
      on this hardware (M1 GPU via host-served inference).
- [ ] Lever-hidden optimization prompt (objective + metric + guards only).
- [ ] Short autonomous run on a *tiny* TRAIN subset with a cheap optimizer model:
      validate FSM gating, keep/discard under noise, commit/revert, worktree
      isolation, held-out grading.
**Exit:** a clean multi-iteration run with ≥1 kept improvement that also moves the
held-out TEST score.

### Phase 3 — The real run(s) + submission build
- [ ] Multi-segment, long-horizon run(s) over the easy TRAIN subset; expand
      difficulty as the agent improves.
- [ ] Periodic held-out TEST grading; track train-vs-test gap (overfit detector).
- [ ] Lean on **synthesize-then-run** to cut play-time model calls (cost + offline).
- [ ] Package the best candidate as a Kaggle-legal (offline, MIT/CC0) submission.
- [ ] Write-up: autoresearch behavior (discovery, stats, patience) + absolute score.
**Exit:** a submittable agent + a documented, reproducible research run.

---

## 9. Proposed layout

```
benchmarks/
  prompts/
    autoresearch_arc_agi3.md            # lever-hidden optimization prompt
  fixtures/
    arc_agi3/
      bench/
        benchmark.sh                    # run candidate over TRAIN, emit METRIC
        checks.sh                       # anti-cheat + contract + no-crash + legality
        immutable.sha256
      toolkit/                          # pinned arc-agi/arcengine + reused MIT runtime (off-limits)
      games/
        train/                          # easy subset, in-loop (off-limits content)
        test/                           # held-out, grading only (off-limits)
experiments/
  arc_candidate/                        # created per run in the worktree
    agent/                              # THE EDITABLE SCAFFOLDING (scope_paths)
```

Run isolation reuses the self-bootstrap **git-worktree** model
(`/workspaces/motoko_agent_autoresearch_wt`, branch `autoresearch/arc-agi3-...`),
session DB in the main checkout via `ar_init(cwd=...)`.

---

## 10. Open questions / risks

- **R1 Headroom (highest):** does a pure-*code* agent score >0 on any easy game?
  Mitigated by Phase 0 + easy subset + deliberately-improvable baseline.
- **R2 Local offline availability:** do public games run with `ONLINE_ONLY=False`
  and no API key, or is a key required to fetch environments? *Verify in Phase 0.*
- **R-cost Binding constraint:** an agentic eval ≈ Symbolica's ~$40/game with
  frontier models × ~800 actions × multi-agent — far too costly for hundreds of
  optimization iterations. The loop **must** drive a cheap/local reasoner; restrict
  to a tiny TRAIN subset + few samples early; lean on synthesize-then-run.
- **R-modelgap (prize-critical):** 36% used frontier models; a small offline-legal
  local model will score far lower. The scaffolding transfers; the model gap is the
  mountain. Synthesize-then-run partly mitigates.
- **R-runtime:** standing up/reimplementing an RLM runtime (or Motoko-as-RLM) is
  real work. Self-hosting `agentica-server` is the fast path to a working baseline.
- **R3 Noise budget vs cost:** samples × games needed for meaningful MAD without
  making `ar_run` slow.
- **R4 `maximize` metric path** correctness in `metrics.ail` (Section 6 TODO).
- **R5 Game determinism:** if games are seeded/deterministic, noise must come from
  the policy/model, not the env. *Verify in Phase 0.*
- **R6 Toolkit weight in sandbox:** `arc-agi` pulls numpy/langchain/etc.; ensure the
  benchmark sandbox can import it (or trim to a minimal play-time dep set — good for
  Kaggle anyway).
- **R7 Local model on M1 (revised):** container is a Linux VM on a Mac **M1** — no
  NVIDIA GPU, no direct Metal. Reach the M1 GPU by serving the model on the **Mac
  host** (Ollama / llama.cpp / vLLM, Metal) and calling it over
  `host.docker.internal`/localhost (local socket, not a hosted API).
  - Dev/optimization: Metal-served model is fine for speed.
  - Submission: must run **offline on Kaggle's NVIDIA GPUs**; the shipped model must
    fit that envelope.
  - **Transfer:** optimize against the **same model + path** we intend to submit.
    Until we commit to a model, stay pure-code so this is moot.
- **R8 Optimizer cost over long horizon:** DeepSeek-V4-Flash for exploration, Pro
  for hard segments.

---

## 11. Spike findings (2026-05-30, partial)

Environment:
- Python 3.12.3 at `/usr/bin/python3`; **no `pip` module**, but **`uv` 0.11.17**
  present (use `uv`). Net egress works. **No NVIDIA GPU** (CPU only — see R7).
  ~55G free on `/`.
- Cloned harness to `/workspaces/arc_spike/ARC-AGI-3-Agents`.
- Symbolica fork cloned to `/workspaces/arc_spike/symbolica-arc` (branch
  `symbolica/arcgentica`). Studied: `agents/templates/agentica/{agent,prompts,model,
  scope/frame,scope/memories}.py` + `IDEA.md` + `SYMBOLICA_README.md` (Section 3).
- Harness deps (`pyproject.toml`): `arc-agi>=0.9.1`, langchain[openai], langgraph,
  openai==1.72.0, numpy, pillow, pydantic, smolagents, requests, dotenv.
- Agent ABC confirmed: `MAX_ACTIONS=80` default, loop calls `choose_action`/
  `is_done`; `GameAction`/`GameState`/`FrameData` from `arcengine`;
  `EnvironmentWrapper`/`Arcade`/`OperationMode` from `arc_agi`.
- `.env.example`: default `OPERATION_MODE=online`, `ONLINE_ONLY` toggle,
  `ENVIRONMENTS_DIR=environment_files`. **Offline-no-key play still UNVERIFIED (R2).**
- `agentica-server` is open-source (self-hostable, multi-provider) — relevant to
  the Phase-2 runtime decision.

**Spike scratch dir:** `/workspaces/arc_spike/` (outside the repo; safe to delete).

---

## 12. Next actions (resume here)

1. Finish **Phase 0 (pure-code)**: `uv sync`; try `uv run main.py --agent=random
   --game=ls20` offline (no key) then online (anon key); record scores + whether
   local works (R2/R5).
2. Write the deliberately-improvable heuristic *code* baseline; confirm it beats
   random on ≥1 game → gradient proven.
3. Choose TRAIN/TEST subsets; record baselines. **GO/NO-GO.**
4. Then Phase 1 fixtures (adapt MIT `Frame` helpers) → Phase 2 RLM runtime.

> Operational playbook for runs (worktree cleanup, model override, monitoring via
> JSONL not the DB, between-run cleanup) is in
> `next-session-ambitious-test-handoff.md` §"Operational playbook" — reuse verbatim,
> swapping `self-bootstrap` for `arc-agi3` branch/path names.
