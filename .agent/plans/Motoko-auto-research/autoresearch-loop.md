# Plan: Autoresearch as a disciplined research loop (method + warm-up)

**Status:** Draft / design (v1 — split out of the combined ARC plan, v5).
**Author handoff date:** 2026-05-31
**Owner branch:** `autoresearch-research`
**Companion docs:**
- `arc-agi-3-application.md` — the ARC-AGI-3 application that *depends on* this doc
  (the North Star: a competitive 2026 prize submission).
- `implementation-plan.md` (Appendix A = self-bootstrap benchmark);
  `next-session-ambitious-test-handoff.md` (the "design a more ambitious test"
  handoff this whole effort answers).

> **Scope of this file.** Everything here is **benchmark-agnostic**: the thesis, the
> primitive-mapping *pattern*, the anti-cheat/integrity methodology, the
> literature-grounded ideation machinery + `ar_scout`, and the Polyglot→Terminal-Bench
> **warm-up** that validates the loop before any heavy bespoke build. The ARC-specific
> instantiation (architecture, RLM runtime, game fixtures, prize) lives in
> `arc-agi-3-application.md`. Dependency points one way only: ARC → this doc.

---

## 1. Goal (Objective #2: autoresearch as a research engine)

Use the `motoko-ext-autoresearch` extension as a **research/optimization loop** that
iteratively improves an *agent* against a benchmark, with real research discipline.
This is the ambitious successor to the self-bootstrap test, which validated the
*plumbing* (FSM, scope gating, worktree isolation, commit/revert) but left the
*research behavior* asleep. An ambitious target must re-introduce the four things the
self-bootstrap test removed:

1. **An unknown lever** (discovery, not transcription).
2. **A genuinely noisy primary metric** (so MAD / confidence / patience actually
   decide keep/discard).
3. **An expensive, rich correctness oracle** (so behavior preservation is non-trivial
   and gaming is tempting).
4. **A horizon long enough for multi-segment dynamics** (regressions, recoveries,
   stall-driven stopping).

### Success criteria (definition of done for the *loop*)
Evidence the loop did *disciplined research*:
- (a) keep/discard was **sound under noise** — kept gains survive on **held-out TEST**,
  not just TRAIN;
- (b) a measured **reproduction rate** over literature methods (§4);
- (c) a small **TRAIN-vs-TEST gap** (no overfit);
- (d) discovery/adaptation that was **not hand-fed** in the prompt (lever-hidden).

**The Polyglot → Terminal-Bench warm-up (§5) is where this is first proven cheaply**,
before the ARC build consumes it.

---

## 2. Mapping onto the autoresearch primitives (the general pattern)

The extension is benchmark-agnostic: benchmark/checks are bash, scope is paths, the
candidate can be in any language. The reusable pattern:

| autoresearch primitive | general role |
|---|---|
| candidate (`scope_paths`) | the editable artifact under optimization (agent scaffolding, policy code, prompts, config) |
| `benchmark_script` | run the candidate over the fixed **TRAIN** set; print `METRIC <name>=<number>` lines |
| primary metric | the headline quantity (often **noisy** — see the `metrics.ail` note) |
| noisy secondary | wall-clock or other genuinely-noisy signal; don't double-count primary noise here |
| tie-breakers | efficiency, cost. **Avoid a size/LOC penalty** when the candidate is prompt/scaffolding-heavy — it pressures the optimizer to delete useful text |
| `checks_script` | runs-without-crashing + contract + **anti-cheat** (§3); gates `keep` |
| `off_limits` | the harness/toolkit/scorer, and the **held-out TEST set** |
| held-out grading | TEST set never referenced in the loop; the true generalization measure |
| `new_segment` | one segment per lever family; real stall/patience dynamics |
| patience / max_iterations | stop a segment when the TRAIN metric plateaus |

> **TODO (load-bearing) — verify two assumptions in `metrics.ail`:**
> 1. **`direction: maximize`** path (improvement test, stall count, confidence) —
>    self-bootstrap only exercised `minimize`. If weak, frame the primary as a
>    minimized quantity instead.
> 2. **Noisy *primary* (the crux of Objective #2).** The extension's model is
>    "deterministic primary + noisy secondaries." An ambitious test needs a *noisy
>    primary*: median + MAD + confidence + improvement-test must apply to the
>    **primary** under `samples>1`. If unsupported, this is the **highest-priority
>    extension change** — it's the whole point of the noisy-metric test.

---

## 3. Anti-cheat / research integrity (adopted from Harbor / Terminal-Bench)

The optimizer is **rewarded for moving the metric**, so it *will* game any weak
verifier. We adopt Harbor / Terminal-Bench's hard-won benchmark-integrity practices
(§3a) rather than hand-rolling. (Harbor is the harness behind Terminal-Bench 2.0 +
TB-Science; its 27-criteria task rubric is effectively a checklist for non-gameable
agent benchmarks.)

1. **Train/test split (the load-bearing guard).** Optimize only on TRAIN; TEST is
   `off_limits`, used solely for out-of-loop grading. TRAIN gains that don't transfer
   to TEST = overfitting — the **behavioral** anti-overfit signal and the headline
   measure of the loop's discipline.
2. **Behavioral verification, not grep.** Per Harbor's `functional_verification`
   criterion, source-string matching is brittle and trivially gamed (insert the
   keyword without the behavior). Greps are a **weak smell-test only**; the real
   signal is held-out TEST transfer (#1).
3. **Budget honesty** — action/step/timeout budgets enforced by the harness, not the
   candidate.
4. **Immutability hashing + canary** — hash benchmark, checks, grader, toolkit, and
   the TEST set into `immutable.sha256`; both scripts verify before running. Mark
   benchmark/TEST files with a **canary GUID** (Harbor convention) as a contamination
   tripwire.
5. **Out-of-loop TEST grading via a *separate verifier*.** Adopt Harbor's
   `environment_mode="separate"`: grading runs in a **fresh container that reads only
   declared `artifacts`** (the candidate's emitted scores/logs), with the candidate's
   working dir torn down first. Stronger than a same-tree grader — it can't be
   influenced by monkey-patched libs, leftover state, or a tampered test framework.
   Operator-invoked, *between* segments, **never** wired into `benchmark_script`; the
   optimizer never sees TEST scores mid-loop.

### 3a. Borrowed Harbor / Terminal-Bench QA gates (apply when building any fixture)
- **Oracle-vs-no-op discrimination.** A reference/decent baseline must **pass** the
  verifier *and* a **no-op (empty) candidate must fail** it. Canonical "does the
  metric measure the thing" check — a sharp fixture exit gate.
- **Cheat trials.** Run *adversarial* candidates (fake tool wrappers, monkey-patched
  toolkit, cached/hardcoded answers, reading TEST files, editing the verifier — the
  optimizer runs with full FS access) and require the guards to block them. If a cheat
  trial "wins," the verifier is broken, not the agent.
- **Stochastic validation = 100+ trials.** A noisy primary needs the verifier proven
  stable over many runs ("an oracle that fails 28/1000 is unacceptable"). Feeds the
  `samples` budget.
- **Pinned deps, no live services** at eval-time (reproducibility + offline wall).
- **"Hard for the agent, not the computer."** Declare modest CPU/mem; difficulty must
  come from reasoning, not brute compute.

---

## 4. Literature-grounded ideation (search → reproduce → validate)

The optimizer is not pure self-play: it reads the field, adapts published methods, and
lets the keep/discard loop decide what survives. This changes how hypotheses are
*generated*, not how they're *judged* — a method earns its keep on the metric like any
other change.

### Pipeline (a funnel feeding the existing loop)
1. **Scout** — from the objective + what's stalled, search arXiv/web for methods.
2. **Triage** — score by relevance to our levers, claimed impact, implementation cost,
   **offline-legality** (training-free / no-API > train-a-model), and **code released?**.
   *Triage is the point: most papers are not reproducible levers.*
3. **Extract → method card** — distill into the structured fields below.
4. **Cache + provenance** — snapshot the paper (PDF/text) and released code into the
   session; record source + retrieval date + content hash (reproducibility + any
   open-source-credit requirement).
5. **Implement** — one candidate change, respecting `scope_paths`/`off_limits`.
6. **Measure + keep/discard** — unchanged discipline; `ar_log.learnings` records
   *claim vs. measured* (did it reproduce?).
7. **Backlog** — untried methods → ideas; failed ones recorded with *why* (don't retry).

### The hard boundary: ideation online, experiment offline
- Fetching happens **only in the optimizer's context** — never inside
  `benchmark.sh`/`checks.sh`, which stay fully offline (reproducibility + matches any
  offline eval). Any paper method must be re-implemented as **offline-legal** code.
- Cached papers/code give reproducible provenance even though retrieval was online.

### Integrity reframe
This shifts Objective #2 from *"did the agent invent the lever?"* to *"can it search,
adapt, and **validate** a literature method?"* — more realistic for real work. Guards:
- **Reproduction is measured, not asserted** — a citation never justifies a keep; the
  metric does. Report a **reproduction success rate** in two flavors: *kept-on-TRAIN*
  (in-loop) and *confirmed-on-TEST* (after held-out grading). The second is the
  headline result.
- **Provenance required** on every kept change (paper id in `learnings`/`method_ids`).
- **Anti-rabbit-hole budget** (R-scout): cap papers per segment; require the cheap impl
  sketch before committing an iteration; prefer training-free / code-released methods.
  Patience already kills dead segments.

### Method card / ledger fields (used by both the markdown convention and the tool)
`source_id` (arxiv/url), `title`, `lever` (which lever it maps to), `claim` (claimed
result), `hypothesis` (why it'd help us), `impl_sketch`, `est_cost`, `code_url`,
`offline_legal` (bool), `status` (`backlog`|`tried`|`kept`|`discarded`), `cache_path`,
`sha256`, `retrieved_at`.

### Two implementations, same fields (start light, promote later)

**Now — prompt + convention only (zero extension code):**
- `papers/` cache under the session (`{arxiv_id}.pdf/.txt/.card.md`).
- A `papers/ledger.md` table using exactly the fields above (so promotion is
  mechanical). Agent fetches with `WebSearch`/`WebFetch`/`Bash(curl+pdftotext)`.

**Later — promote the ledger to a dedicated `ar_scout` tool** (a *recorder*, not a
fetcher — no network I/O in the extension; keeps the `{Process}` effect model and the
online/offline wall intact):

| Tool | Required | Optional |
|------|----------|----------|
| `ar_scout` | `source`, `title`, `lever` | `claim`, `hypothesis`, `impl_sketch`, `est_cost`, `cache_path`, `code_url`, `offline_legal`, `status`, `method_id` (update) |

- The register form returns a `method_id`; a no-arg form lists the segment's method
  ledger (like `ar_notes` reading).
- `ar_log` gains optional **`method_ids: [string]`** to link a run to the method(s) it
  tested.
- **DB (`db.ail`):** a `methods` table (the fields above) + run linkage
  (`run_methods(run_number, method_id)` or a column on `runs`); the extension derives
  the **reproduction report** (tried/kept/rate) from the join.
- **FSM (`state.ail`):** add `scout_tool(name)=="ar_scout"`, allowed in **all four
  states** (read-only ideation; also closes the `Setup`/`Done` `else→reject` gap noted
  below). Separately decide whether raw `Web*` tools are allowed in all states or
  funneled through `ar_scout`+bash.
- **Prompt (`prompts.ail`):** when a segment starts or patience nears exhaustion,
  *consult the literature via `ar_scout` before proposing the next change*.
- **Footprint:** ~6 modules (`tools`, `autoresearch`, `types`, `state`, `db`,
  `prompts`) + `ar_log` `method_ids` + `_smoke`/tests. ~1 day.

> **`legal()` gating gap (verify before relying on web tools).** `state.ail`'s
> `legal()` only names mutator/readonly/`ar_*`/`RunTests` tools; `Setup` and `Done`
> fall through to `else → reject`, and `BashExec` (curl) is a mutator blocked in
> `AwaitingLog`/`Done`. If the harness routes `Web*`/bash through the extension during
> an active session, scouting is blocked in those states — add the `scout_tool` allow
> in all four states.

---

## 5. Phase 0.5 — Warm-up: validate the loop end-to-end (before any bespoke build)

> **RESOLVED (2026-05-31): warm-up validated via the SIMD-scan planted-lever fixture.**
> Optimizing **Motoko's own scaffolding** (§5a, Polyglot) proved a dead end as a
> *research* test: on a strong model the prompt is flat and the tool/extension
> surface is deprecated/broken (omnigraph, ohmy_pi), so there is no discoverable
> lever, and the timeout-driven metric noise is degenerate. Polyglot validated only
> the loop *plumbing*. We instead built a **controlled planted-lever fixture**
> (`benchmarks/fixtures/autoresearch_simdscan/`) whose candidate is a self-contained
> C scan function with a real, literature-discoverable lever (SIMD vectorized
> classification, simdjson / arXiv:1902.08318), a sharp correctness oracle, and an
> informative noisy primary (CPU-time throughput). On it the loop was validated
> end-to-end — model-free (Phase 1: real lever kept+transfers, overfit decoy
> indistinguishable on TRAIN but exposed on held-out, correctness/cheat gates hold)
> and with a live cheap model (Phase 2: DeepSeek V4 Flash discovered, implemented,
> and iteratively refined a correct ~14.6x NEON scan that transfers to held-out, for
> ~$0.04 — both as a candidate generator and in full autonomy driving
> ar_init/ar_run/ar_log itself). See
> `.agent/summaries/2026-05-31-autoresearch-simdscan-validated.md` and `papers/ledger.md`.
> **Takeaway for ARC:** the candidate must be an artifact with real headroom (the
> bespoke player), NOT Motoko's scaffolding.

**Goal:** prove optimize→measure→keep/discard + held-out discipline + §4 literature
ideation on a benchmark Motoko already runs, with *no* bespoke player to build. The
candidate-under-edit is **Motoko's own scaffolding** (system prompt, tool/skill config,
agent strategy); the metric is **task pass-rate**.

> **Why warm up first.** The ARC application is a *heavy bespoke build* (RLM runtime,
> Frame player, interactive eval). Proving the loop machinery on easy, already-wired
> ground de-risks Objective #2 cheaply. Two steps, cheapest first.

### 5a — Polyglot (the first target; turnkey, offline, NO Docker)
- [x] Smoke `benchmarks/aider_polyglot.py` on a couple of Python exercises (local
      endpoint or cheap API) to confirm the runner works as documented.
- [x] Define a **TRAIN** exercise subset + a disjoint held-out **TEST** subset (the
      `polyglot_logs/python/` corpus already lists the exercise set).
- [x] Wire `aider_polyglot.py` over TRAIN as the `benchmark_script` (emit
      `METRIC pass_rate=…`, `wall_ms`); baseline = current Motoko scaffolding.
- [x] Apply the §3/§3a integrity gates: out-of-loop TEST grading, oracle-vs-no-op
      (current scaffolding passes; an empty/broken scaffolding fails), one cheat trial,
      canary on the split definition.
- [~] Run a short autonomous autoresearch loop: optimizer edits Motoko scaffolding,
      `ar_run` measures Polyglot pass-rate over TRAIN, `ar_log` keep/discard; grade on
      TEST between segments. **Loop ran (3 iterations, baseline kept, 2 candidates
      discarded), but no kept gain transferred — see 0.5a findings below; noise budget
      is the binding constraint.**
- [x] Exercise §4: optimizer scouts one prompting/agent method from a paper, records it
      via the ledger/`ar_scout`, validates it on the metric.

**5a Exit:** a clean multi-iteration Polyglot loop where a kept scaffolding change
transfers to held-out TEST, the integrity gates hold under a cheat trial, and one
literature method was recorded + validated. **This alone validates the core machinery
the ARC phases depend on.**

**5a Exit status (2026-05-31, Pro rebalanced split):** machinery validated, exit NOT
yet reached. Met: harder hashed split, full `ar_init`/`ar_run`/`ar_log` loop, integrity
gates (oracle-vs-no-op + cheat + immutable), literature methods recorded with measured
outcomes. **Unmet: a kept scaffolding change that transfers to held-out TEST** — both
candidates were soundly discarded on TRAIN and none beat the baseline (minimal prompt,
TRAIN median 0.75 / TEST 0.500). The discarded ReAct candidate scored *higher* on TEST
(0.667) than its TRAIN regression, so the in-loop decision did not transfer: at
`samples=2` over 6 exercises the timeout-driven primary variance (~0.167/exercise) is
comparable to candidate effect sizes (R-noise). Next: raise the noise budget (more
samples and/or a less timeout-bound primary such as a non-timeout correctness metric)
or broaden the candidate surface beyond the system prompt, then re-run for a kept
transfer. See `.agent/summaries/2026-05-31-autoresearch-polyglot-phase0_5a.md` and
`papers/ledger.md`.

**0.5a findings (2026-05-31):**
- The default `../polyglot-benchmark` checkout was absent. For non-Docker execution,
  `/workspaces/polyglot-benchmark/python` was restored from `exercism/python`; the
  runner now sees 140 Python practice exercises.
- System Python lacked `pytest`; the non-Docker verifier uses a uv venv at
  `.motoko/ar_polyglot_py` and prepends it to `PATH`, so the runner's existing
  `python3 -m pytest -x -q` command works without changing `aider_polyglot.py`.
- Smoke commands with `POLYGLOT_MODEL=anthropic/claude-haiku-4-5` passed
  `hello-world` and `two-fer`; stdout ended as flat maps such as
  `{"python/hello-world": "pass_1"}` and result JSON had the documented
  `{"exercises": ..., "meta": ...}` shape.
- After the OpenRouter budget concern, the fixture was locked to
  `POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-flash`; the retry is now locked to
  `POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-pro`, and any other model now fails
  fast in `bench/lib.sh` before runner startup.
- Fixture added at `benchmarks/fixtures/autoresearch_polyglot/`: TRAIN/TEST split
  files, canary manifest, `immutable.sha256`, TRAIN `benchmark.sh`, held-out
  `grade_test.sh`, `checks.sh`, and a README. The fixture loops `aider_polyglot.py`
  once per exercise rather than adding a subset flag to the runner. It explicitly
  sets `SYSTEM_MD=benchmarks/prompts/polyglot_system.md`, making that prompt the live
  initial candidate surface.
- Metric definition is documented as
  `pass_rate = (count(pass_1) + count(pass_2)) / total`, maximize. `wall_ms` is a
  noisy secondary, minimize.
- Docker is unavailable. The TEST grader therefore uses a fresh process and clean
  scratch directory plus immutable hashes and `off_limits`, not a fresh container.
  This is weaker than Harbor's container separation but preserves the important
  non-Docker boundary: TEST is never referenced by `benchmark.sh`.
- First six-exercise TRAIN smoke scored `pass_rate=1.000000`, `wall_ms=117993`, so
  that initial split is too easy for an improvement loop and should be rebalanced
  once model access is restored. A harder `forth` probe then hit the external model
  route's `403 Key limit exceeded`, so further model-backed runs stopped.
- Load-bearing verdict: `maximize` is implemented and covered by
  `metrics_test.ail`, and `ar_run` aggregates noisy metrics with median/MAD. However
  `ar_log` improvement/stall uses `Metrics.improved(direction, prev, cur, 0.0)`,
  ignoring noisy-primary MAD/confidence. Noisy primary is therefore **not yet
  supported for keep/discard discipline**. Per §2/§3.6, do not run the real loop
  until this is fixed, or reframe the primary as a deterministic/minimized fallback
  such as `fail_rate`.
- Follow-up fix: `packages/motoko-ext-autoresearch/autoresearch.ail` now computes
  the pending run's primary MAD from `samples_json` when the primary metric is marked
  noisy and passes that noise into `Metrics.improved`. Focused verification:
  `AILANG_RELAX_MODULES=1 ailang check packages/motoko-ext-autoresearch/autoresearch.ail`,
  `ailang test packages/motoko-ext-autoresearch/metrics_test.ail`, and the
  DeepSeek-locked Polyglot `checks.sh` all pass.
- The direct DeepSeek optimizer did not reliably call `ar_init`/`ar_run`/`ar_log`
  even though the autoresearch extension loaded. To prove the extension FSM anyway,
  `scripts/ar_polyglot_harness.ail` now drives the real hooks directly while the
  benchmark itself remains locked to the configured DeepSeek-only route.
- Segment 2 baseline used `samples=2`: TRAIN median `pass_rate=0.5833335`,
  samples `[0.666667, 0.5]`, primary MAD `0.0833335`, checks passed, logged keep.
  This is the live proof that the noisy maximize primary path executes under
  `samples>1`.
- Literature trial used ReAct-style reasoning/action prompting
  (Yao et al., arXiv:2210.03629) and added an explicit inspect→edit→test loop plus
  a fallback away from `Search` when `rg` is unavailable. The candidate scored TRAIN
  median `pass_rate=0.75`, samples `[0.666667, 0.833333]`, primary MAD `0.083333`,
  checks passed, and `ar_log keep` committed `f3efa47446c5af9a7515e7191e0b87d06b90383a`
  in the linked worktree.
- Held-out TEST did **not** transfer: `grade_test.sh` on the disjoint TEST split
  scored `pass_rate=0.000000`, `wall_ms=720385`; all six TEST exercises errored or
  timed out under the DeepSeek-only route. The 0.5a exit gate therefore remains
  open despite the kept TRAIN improvement.
- Benchmark-infra follow-up: the subset fixture now bounds each exercise with
  `POLYGLOT_EXERCISE_TIMEOUT_SECS` and records timed-out exercises as `error` JSON.
  `aider_polyglot.py` also has `--skip-preflight` so per-exercise subset loops do not
  repeatedly burn or hang on the model preflight. This is infra, not candidate scope.
- DeepSeek V4 Pro retry: the fixture pin was switched to
  `openrouter/deepseek/deepseek-v4-pro` after verifying the OpenRouter route. With the
  default Polyglot prompt and bounded subset runner, TRAIN scored `pass_rate=1.000000`
  (`wall_ms=138656`) and held-out TEST scored `pass_rate=1.000000` (`wall_ms=103285`),
  all first-try passes. This confirms the Flash failure was model-route/capability
  limited, but it is not itself a 0.5a exit because no optimizer-kept scaffolding
  change was tested for transfer in this Pro run.

### 5b — Terminal-Bench (richer second target; needs Docker — R9)
- [ ] `uv tool install harbor`; **verify Docker** (cheap check). If unavailable, run
      Harbor on the Mac host or stay on Polyglot — 5a already proves the loop.
- [ ] Wire a small TB / TB-Science TRAIN+TEST subset via the existing
      `benchmarks/tb_adapter/` + `benchmarks/harbor_adapter/`.
- [ ] Repeat the 5a loop on TB; §4 ideation in its natural home (TB-Science tasks
      literally are "reproduce this paper's method" / pull from the Harbor `skills`
      catalog). TB is on the Opus/GPT/Gemini model cards.
- [ ] (Optional, real deliverable) contribute a Motoko/AILANG-flavored task to
      TB-Science (co-authorship; merge window ~Aug 17 2026) — only if cheap.

**5b Exit:** the same loop holds on TB. Optional; 5a is the gate to the ARC build.

### Existing infrastructure to reuse — verified present in `benchmarks/`
- `aider_polyglot.py` — a **working** Exercism/Polyglot runner: `pass_1/pass_2/fail/
  error` scoring, structured JSONL events, retries, live status, **local
  OpenAI-compatible endpoint** support (`OPENAI_BASE_URL=…`). The 5a target.
- `polyglot_logs/python/` — a large existing per-exercise corpus (defines the exercise
  set to split TRAIN/TEST from).
- `tb_adapter/` — Terminal-Bench adapter + shell sidecar (no turnkey runner yet) — 5b.
- `harbor_adapter/motoko_agent.py` — Harbor↔Motoko adapter (README: placeholder) — 5b.
- `motoko_rpc.py` (JSONL subprocess client), `smoke.py`, `prompts/`, `fixtures/` (incl.
  the `autoresearch_self_bootstrap` example).

(README note: `benchmarks/README.md` has one stale path — a live-status command still
says `/workspaces/ailang_agent/...` from before the repo rename; harmless.)

---

## 6. Shared risks (machinery-level; ARC-specific risks live in the ARC doc)

- **R-scout (rabbit-holing):** literature ideation can burn the optimizer's budget on
  complex methods that don't pan out. Guard: cap papers per segment, require a cheap
  impl sketch before committing an iteration, prefer training-free / code-released
  methods, let patience kill dead segments. Keep fetching out of the benchmark sandbox.
- **R-noise (noise budget vs cost):** samples × tasks needed for meaningful MAD without
  making `ar_run` slow.
- **R-metrics (`metrics.ail` assumptions):** `maximize` is implemented. The
  2026-05-31 Polyglot warm-up found that noisy-primary support was incomplete:
  `ar_run` reported median/MAD, while `ar_log` keep/improvement compared with
  `noise=0.0`. A local follow-up now applies pending-run primary MAD to the
  keep/improvement test; the remaining risk is proving it through a live
  `samples>1` autoresearch run. (See §2 TODO and §5a findings.)
- **R9 Harbor needs Docker (5b only):** Harbor/TB run tasks in Docker; may be
  unavailable/heavy here. Mitigation: **5a (Polyglot) needs no Docker** and already
  proves the loop; for 5b, run Harbor on the Mac host or skip it.
- **R10 Warm-up scope creep:** the warm-up must *validate the loop*, not become its own
  project. Time-box it; 5b and the TB-Science contribution are nice-to-haves, not
  gates. Once 5a shows the machinery is sound, move to ARC.

---

## 7. Next actions (resume here)

**Recommended next build: Phase 0.5a (Polyglot warm-up)** — turnkey, offline,
validates the loop machinery the ARC application depends on.
1. Smoke `benchmarks/aider_polyglot.py` on a couple of Python exercises (local endpoint
   or cheap API) — confirm the runner works.
2. Split the `polyglot_logs/python/` exercise set into TRAIN + disjoint TEST; wire
   `aider_polyglot.py` over TRAIN as the `benchmark_script` (emit `METRIC pass_rate`).
3. Apply §3/§3a gates (out-of-loop TEST grading, oracle-vs-nop, one cheat trial); run a
   short autoresearch loop editing Motoko scaffolding; confirm held-out transfer + one
   §4 literature method recorded/validated.

Then: 5b (TB) optional → hand off to `arc-agi-3-application.md` Phase 0 (ARC headroom),
which runs in parallel and consumes this machinery.

> Operational playbook for runs (worktree cleanup, model override, monitoring via the
> JSONL session log not the DB, between-run cleanup) is in
> `next-session-ambitious-test-handoff.md` §"Operational playbook" — reuse verbatim.
