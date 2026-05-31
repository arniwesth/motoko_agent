# Handoff: implement the autoresearch loop warm-up (Phase 0.5a — Polyglot)

Paste this into a fresh session to start building. Your job: **stand up and run the
autoresearch loop on the Polyglot benchmark** — the first concrete step of
`.agent/plans/Motoko-auto-research/autoresearch-loop.md`. This proves the
optimize→measure→keep/discard machinery (under held-out discipline + literature
ideation) on infrastructure that **already works in this repo**, before any bespoke
ARC build.

---

## 0. Read these first (in order)

1. `.agent/plans/Motoko-auto-research/autoresearch-loop.md` — **the plan you are
   implementing.** Phase 0.5a (§5a) is your scope. §1–§4 are the *why* and the rules
   (success criteria, primitive mapping, integrity gates, literature ideation).
2. `packages/motoko-ext-autoresearch/README.md` — the extension you're driving:
   `ar_init`/`ar_run`/`ar_log`/`ar_notes`, the `Setup→Ready→AwaitingLog→Done` FSM,
   config, persistence, the `cwd` arg, the git-worktree model.
3. `next-session-ambitious-test-handoff.md` §"Operational playbook" — run mechanics
   (worktree cleanup, `MODEL=` override, monitor via the JSONL session log **not** the
   DB, between-run cleanup). Reuse verbatim.
4. The `ailang-syntax-gotchas` memory — only relevant if you touch extension `.ail`
   code (you mostly won't in 0.5a).

**Do not** start the ARC work (`arc-agi-3-application.md`); that's downstream and
depends on this. Stay in the Polyglot lane.

---

## 1. The one-paragraph mental model

The autoresearch extension makes an agent run a disciplined research loop: `ar_init`
declares an objective + metrics + a `benchmark_script` + `scope_paths`/`off_limits`;
`ar_run` executes the benchmark, parses `METRIC <name>=<number>` lines from stdout,
aggregates, and stores a *pending* run; `ar_log` records keep (commit in-scope edits)
or discard (revert). For 0.5a the **candidate-under-edit is Motoko's own scaffolding**
(system prompt / tool / skill / agent-strategy config — see §2 below), and the
**metric is Polyglot pass-rate**. The optimizer (a cheap API model driving the
autoresearch agent) edits scaffolding, measures, keeps/discards. A held-out TEST
subset, graded out-of-loop, tells us whether gains are real or overfit.

---

## 2. Facts already verified (build on these; don't re-derive)

- **The Polyglot runner works and is the eval.** `benchmarks/aider_polyglot.py`
  (473 lines, read it — these are confirmed from source, not assumed):
  - **Actual args:** `--model` (default `anthropic/claude-sonnet-4-6`), `--language`
    (default `python`), `--exercise <name>` (run *one*), `--exercises <int>` (run the
    *first N*; 0 = all), `--results <path>` (default `benchmarks/results/
    polyglot_results.json`), `--openai-base-url` (or `OPENAI_BASE_URL` env),
    `--heartbeat-secs`, `--resume`, `--no-retry`, `--verbose`, `--thinking
    on|off|auto`.
  - ⚠️ **There is NO `--exercises-file`, `--limit`, `--jobs`, or `--results-dir`.**
    The only subset controls are `--exercise <name>` (single) and `--exercises <N>`
    (first N). **To run an arbitrary TRAIN/TEST subset you must either** (a) loop the
    runner per-exercise over your list, or (b) add a small subset flag to the runner.
    Decide this in §3.2 — it's the main wiring decision.
  - **Output:** writes `benchmarks/results/polyglot_results.json` with shape
    `{"exercises": {<name>: {"status": ...}}, "meta": {...}}`, and at the end **prints
    to stdout** `json.dumps({name: status})` (a flat name→status map). Statuses:
    `pass_1` (passed first try), `pass_2` (passed on retry), `fail`, `error`. **There
    is no built-in pass_rate** — you compute it from these statuses.
  - Exercises come from a **`polyglot-benchmark/` checkout** (env
    `MOTOKO_BENCHMARK_ROOT`, default `<repo>/../polyglot-benchmark`,
    `python/exercises/practice/<name>`). **Confirm this checkout exists** — if absent,
    every exercise returns `status=error: exercise not found`. (`polyglot_logs/python/`
    is the *log/results* corpus, 140 entries — a good source for the exercise *names*
    to split, but not the exercise *content*.)
  - Per-attempt local test run: `python -m pytest -x -q` in a temp dir (90s timeout).
    So the runner itself needs no network at eval-time; only model inference does
    (point it at a local endpoint to stay offline/cheap).
  - Supports extension selection via `CORE_EXT_ORDER=…`. See `benchmarks/README.md`.
- **Launch plumbing exists:** `Makefile` `run`/`build`/`run_autoresearch_self`
  (the latter: `TASK="$(cat benchmarks/prompts/autoresearch_self_bootstrap.md)"
  ./scripts/run-agent.sh`). System prompts already present:
  `benchmarks/prompts/{autoresearch_self_bootstrap,polyglot_system,tb_system}.md`.
- **The worktree/run model** (from the self-bootstrap work) is documented and reusable.

**Still verify yourself before building:**
- Run `aider_polyglot.py --exercise hello-world` once and read the printed map +
  `polyglot_results.json` so the metric extractor matches reality.
- Confirm the `polyglot-benchmark/` checkout exists (or get it) — gates everything.
- Pick the pass_rate definition (e.g. `(pass_1+pass_2)/total`) and **document it**.

---

## 3. Your deliverables (Phase 0.5a checklist)

Work in this order; each step gates the next.

### 3.1 Smoke the runner (prove the eval before wiring it)
- Run `aider_polyglot.py` on 1–2 Python exercises with a cheap/local model. Confirm it
  produces a summary JSON and sane pass/fail. Record the invocation + output shape.
- Decide the play-time model: **prefer a local endpoint** (`OPENAI_BASE_URL`) to avoid
  spend; a cheap API model is fine for the smoke.

### 3.2 Define the TRAIN/TEST split (the integrity backbone — `autoresearch-loop.md` §3)
- Choose a **TRAIN** exercise-name subset (in-loop) and a **disjoint TEST** subset
  (held-out, never referenced by `benchmark.sh`). Source the names from
  `polyglot_logs/python/` (or the `polyglot-benchmark` practice dir). Keep TRAIN small
  at first (loop speed) but big enough that pass-rate isn't all-or-nothing noise.
- Materialize the split as two plain name lists (one per line). **Note:** the runner
  has no `--exercises-file`, so `benchmark.sh`/`grade_test.sh` must **loop the runner
  per exercise** (`--exercise <name>` each) and aggregate, *or* you add a small
  `--exercises-file` flag to `aider_polyglot.py` (cleaner; ~10 lines — acceptable, it's
  benchmark infra not candidate scope). Pick one and note it.
- **Hash the split lists** into `immutable.sha256`; add a **canary GUID** marker to the
  split definition.
- One-line rationale for the split sizes (feeds the §3a noise / 100+-trial discussion).

### 3.3 Write `benchmark.sh` (TRAIN) and the metric contract
- `benchmark.sh` runs `aider_polyglot.py` over the **TRAIN** names (per §3.2) and prints
  exactly the `METRIC` lines the extension parses (compute pass_rate from the
  name→status map / `polyglot_results.json`):
  - `METRIC pass_rate=<float in [0,1]>` (primary, **maximize**) — derive from the
    summary JSON (pass_1+pass_2 over total, or your chosen definition — document it).
  - `METRIC wall_ms=<int>` (noisy secondary, minimize).
  - keep scratch/results **outside** `scope_paths` (mirror the `AR_BENCH_SCRATCH`
    pattern from self-bootstrap so candidate paths don't get dirtied).
- **No network/fetch inside `benchmark.sh`** — the offline-experiment wall
  (`autoresearch-loop.md` §3, §4). Anything online (literature scouting) happens only
  in the optimizer's own context.

### 3.4 Write `checks.sh` + `grade_test.sh`
- `checks.sh`: candidate runs without crashing; honors the contract; **Kaggle-legality
  style** import guard if relevant. Greps are a *weak smell-test only* — don't lean on
  them (§3 item 2).
- `grade_test.sh`: **operator-invoked**, runs the candidate over the **TEST** names
  (same per-exercise loop / subset mechanism as §3.2), emits the same `METRIC` lines. Follow the **separate-verifier** spirit
  (`autoresearch-loop.md` §3.5): grade in a fresh invocation that reads only the
  candidate's emitted output, **never** wired into `benchmark.sh`. The optimizer must
  not see TEST scores mid-loop.

### 3.5 Apply the §3a QA gates (do this before the real loop)
- **Oracle-vs-no-op:** current Motoko scaffolding (the "oracle") must score clearly
  above an **empty/broken scaffolding** (the "no-op"). If they're indistinguishable,
  the metric or split is wrong — fix before proceeding. This is your hard gate.
- **One cheat trial:** hand the loop an adversarial candidate (e.g. one that tries to
  read the TEST file, hardcode answers, or edit the grader) and confirm the guards/
  `off_limits` block it. If a cheat "wins," the verifier is broken, not the agent.
- **Noise check:** run `benchmark.sh` several times on a fixed candidate; record the
  pass_rate spread to size `samples` (the noisy-primary handling — see §3.6).

### 3.6 Decide the candidate surface + metric direction (two known unknowns)
- **What exactly is `scope_paths`?** Pick the concrete Motoko scaffolding files the
  optimizer may edit (system prompt, tool/skill config, agent-strategy params). Make
  `off_limits` cover the runner, the splits, `grade_test.sh`, the TEST list, and the
  extension package itself. Write these down in the `ar_init` call.
- **Verify the `metrics.ail` maximize + noisy-primary path** (`autoresearch-loop.md` §2
  TODO — this is load-bearing). `pass_rate` is **maximize** and **noisy**; the
  self-bootstrap test only exercised a *deterministic minimize* primary. Confirm
  median/MAD/confidence/improvement-test actually apply to a noisy *primary* under
  `samples>1`. **If they don't, stop and report** — it's the top-priority extension
  change and changes the whole 0.5a design (fallback: frame the primary as a minimized
  quantity like `fail_rate`, but the noisy-primary support is the real goal).

### 3.7 Run the loop
- `ar_init` (objective + the two metrics + `benchmark.sh` + `checks.sh` +
  `scope_paths`/`off_limits` + `samples` from §3.5). Capture a **baseline** run, log it.
- Run a short multi-iteration loop: optimizer edits scaffolding → `ar_run` →
  inspect metrics/MAD/checks → `ar_log` keep|discard. Use the JSONL session log to
  monitor (not the DB — lock collisions).
- **Grade on TEST between segments** via `grade_test.sh`; record TRAIN vs TEST.

### 3.8 Exercise literature ideation once (`autoresearch-loop.md` §4)
- Have the optimizer scout **one** prompting/agent method from a paper, record a method
  card in `papers/ledger.md` (the prompt+convention form — no `ar_scout` tool needed
  yet), implement it as one candidate change, and let the loop keep/discard it.
- Record *claim vs. measured*. This is the seed of the reproduction-rate metric.

---

## 4. Definition of done (0.5a exit — from the plan)

A clean multi-iteration Polyglot loop where:
- a **kept scaffolding change transfers to held-out TEST** (not just TRAIN),
- the **oracle-vs-no-op** gate passed and a **cheat trial was blocked**,
- **one literature method** was recorded + validated (claim vs. measured),
- and you can state the **noisy-primary verdict** (does `metrics.ail` handle it?).

Write the outcome into `autoresearch-loop.md` (check the §5a boxes, add a short
"0.5a findings" note) and update the `arc-agi-3-autoresearch` memory. **This validates
the core machinery the ARC phases depend on** — then 0.5b (Terminal-Bench, needs
Docker) is optional and the ARC Phase 0 (`arc-agi-3-application.md`) can proceed.

---

## 5. Guardrails / don'ts

- **Don't** wire any network or TEST access into `benchmark.sh`/`checks.sh`.
- **Don't** let the optimizer see or touch the TEST split (`off_limits` + separate
  grader).
- **Don't** add a candidate **size/LOC penalty** — it pressures deleting useful prompt
  text (`autoresearch-loop.md` §2).
- **Don't** trust greps to catch overfitting — held-out TEST transfer is the signal.
- **Don't** scope-creep into Terminal-Bench/Harbor (Docker) or ARC. 0.5a is the gate.
- **Do** keep TRAIN small and runs cheap early; scale once the loop is proven.
- **Do** verify-then-build the three "known unknowns" in §2/§3.6 before writing code
  against assumptions.

---

## 6. Current repo state (at handoff, 2026-05-31)

- Branch `autoresearch-research` (not pushed). Main branch `main`.
- Plan split into `autoresearch-loop.md` (this work) + `arc-agi-3-application.md`
  (downstream). Old combined `arc-agi-3-autoresearch-plan.md` was deleted.
- Spike scratch (safe to ignore/delete): `/workspaces/arc_spike/{ARC-AGI-3-Agents,
  symbolica-arc,tbs}` — ARC/Symbolica/TB-Science clones used only for study.
- Self-bootstrap fixtures (`benchmarks/fixtures/autoresearch_self_bootstrap/`) are the
  closest worked example of the `benchmark.sh`/`checks.sh`/`immutable.sha256`/scope
  pattern — copy its shape.
- Uncommitted working-tree changes exist (config/lock/plan files); check `git status`
  and commit deliberately. Commit your 0.5a fixtures on `autoresearch-research`.

Start with §3.1 (smoke the runner). Report the three "verify yourself" facts from §2
before building the benchmark wiring.
