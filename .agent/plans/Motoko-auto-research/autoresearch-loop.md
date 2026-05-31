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

**Goal:** prove optimize→measure→keep/discard + held-out discipline + §4 literature
ideation on a benchmark Motoko already runs, with *no* bespoke player to build. The
candidate-under-edit is **Motoko's own scaffolding** (system prompt, tool/skill config,
agent strategy); the metric is **task pass-rate**.

> **Why warm up first.** The ARC application is a *heavy bespoke build* (RLM runtime,
> Frame player, interactive eval). Proving the loop machinery on easy, already-wired
> ground de-risks Objective #2 cheaply. Two steps, cheapest first.

### 5a — Polyglot (the first target; turnkey, offline, NO Docker)
- [ ] Smoke `benchmarks/aider_polyglot.py` on a couple of Python exercises (local
      endpoint or cheap API) to confirm the runner works as documented.
- [ ] Define a **TRAIN** exercise subset + a disjoint held-out **TEST** subset (the
      `polyglot_logs/python/` corpus already lists the exercise set).
- [ ] Wire `aider_polyglot.py` over TRAIN as the `benchmark_script` (emit
      `METRIC pass_rate=…`, `wall_ms`); baseline = current Motoko scaffolding.
- [ ] Apply the §3/§3a integrity gates: out-of-loop TEST grading, oracle-vs-no-op
      (current scaffolding passes; an empty/broken scaffolding fails), one cheat trial,
      canary on the split definition.
- [ ] Run a short autonomous autoresearch loop: optimizer edits Motoko scaffolding,
      `ar_run` measures Polyglot pass-rate over TRAIN, `ar_log` keep/discard; grade on
      TEST between segments. Confirm kept gains transfer to held-out.
- [ ] Exercise §4: optimizer scouts one prompting/agent method from a paper, records it
      via the ledger/`ar_scout`, validates it on the metric.

**5a Exit:** a clean multi-iteration Polyglot loop where a kept scaffolding change
transfers to held-out TEST, the integrity gates hold under a cheat trial, and one
literature method was recorded + validated. **This alone validates the core machinery
the ARC phases depend on.**

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
- **R-metrics (`metrics.ail` assumptions):** the `maximize` direction *and* — more
  importantly — whether a **noisy primary** is supported (MAD/confidence/improvement-
  test on the primary under `samples>1`). The crux of Objective #2; if unsupported,
  top-priority extension change. (See §2 TODO.)
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
