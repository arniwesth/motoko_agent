# Plan: A bounded Gödel Machine for Motoko (Tiers 0–4)

**Status:** Draft / design (v2 — AILANG-grounded via the `ailang-docs` MCP).
**Author handoff date:** 2026-06-21
**Owner branch:** `arniwesth/mot-10-merge-main-into-latest-auto-research-branch`
**AILANG grounding:** repo `ailang.lock` pins **v0.24.2**; toolchain capabilities below were
confirmed against the `ailang-docs` MCP (`.mcp.json`) — effects catalog and devtools
reference served for **0.25.0** (devtools prompt v0.8.0), the closest available to 0.24.2.
Tool/flag names (`ailang check`, `ailang verify`, `ailang iface`, `AILANG_FS_SANDBOX`,
`--verify-contracts`, `[effects] max`, `@limit=N`) are MCP-verified, not assumed.
**Recommendation: bump Motoko to AILANG 0.25.0** (latest, and the exact version this plan is
grounded against) before starting Tier 1 — this eliminates the 0.24.2↔0.25.0 skew so the
toolchain behaviour the verifier depends on matches the documented surface. See open
decision #3 / next action #0.
**Companion docs:**
- `.agent/research/Motoko-auto-research/05-darwin-godel-machine.md` — DGM: empirical
  validation + open-ended archive + the evaluator-boundary rule (Appendix H).
- `.agent/research/Motoko-auto-research/07-huxley-godel-machine.md` — HGM: non-greedy
  clade-pooled Beta-Bernoulli selection; the minimal-adoption steps this plan adopts.
- `autoresearch-loop.md` — the loop this plan evolves (it *is* the search substrate).
- `handoff-autoresearch-loop-phase0.5a-continuation-2.md` — the open **DoD #3 / R-noise**
  constraint Tier 4 targets.
- `known-issues.md` — KI-1 (`max_output_tokens` cap) still applies to every tier.

> **Scope of this file.** A staged build that grows the `motoko-ext-autoresearch`
> package from a linear, greedy, prompt-tuning loop into a **bounded Gödel Machine**:
> a self-modifying loop over the agent's own AILANG extension hooks, where a class of
> safety/correctness properties is a *provable precondition* of self-modification and
> utility improvement stays *empirical* (DGM-style). Tiers 0–2 yield a working
> DGM-for-Motoko; Tiers 3–4 are what make it *Gödel* (proof tier) and *non-greedy*
> (HGM tier).

---

## TL;DR

**What.** Turn the existing autoresearch loop into a *bounded Gödel Machine*: the agent
self-modifies its own compiled AILANG hooks, where AILANG **statically guarantees** a class
of safety invariants (the "proof") and the **benchmark measures** whether the change is
actually better (the "utility"). Schmidhuber's proof-of-utility is undecidable; we keep only
the decidable half (invariants) and measure the rest — strictly stronger than DGM/HGM
(which prove nothing), strictly weaker than the ideal.

**Why Motoko can do this and DGM/HGM can't.** AILANG's **effect/type system** makes whole
classes of reward-hacking *not compile* (a hook that gains a `Net`/`AI` effect fails
`ailang check` against its frozen signature — the exfiltrating mutation *cannot exist*). Z3
(`ailang verify`) adds a narrow bonus; the effect system, not Z3, is the workhorse.

**The five tiers** (Tiers 0–2 = DGM-for-Motoko; 3–4 = the Gödel + Huxley-Gödel additions):

| Tier | One line | Headline risk |
|---|---|---|
| **0** | Rebuild-and-run-*candidate* plumbing so a compiled-hook edit actually moves a benchmark (the loop today only tunes a runtime-read prompt). | Isolated build must not disturb the loop's own agent — prove first. |
| **1** | Pre-benchmark verifier (`verify.ail`): `ailang check` + frozen signature reject illegal candidates *for free*, attributably. | Toolchain surface stability. |
| **2** | Archive + `parent_run` tree: keep every compiled candidate, branch-from-parent (don't revert). DGM stepping-stones; rollback for free. | Working-tree hygiene; storage. |
| **3** | Enforce evaluator-boundary + purity (import-parse + effect system; `ailang verify`/`--verify-contracts`/budgets where bounds matter). | Don't overclaim Z3 reach. |
| **4** | Non-greedy clade-pooled Beta-Bernoulli selection (HGM) on the binary Polyglot path — attacks the open **DoD #3 / R-noise** wall. | Research-risk tier; Polyglot-only. |

**Key constraints.** It's *bounded*: the mutation operator (baseline loop agent) is **fixed**
— coding behaviour accumulates down the tree, but the proposer never self-improves (safer,
out-of-scope to lift). Tier 4 is **Polyglot/binary-only** (the estimator dissolves on
continuous fixtures). The evaluator (grader/sensors) stays **immutable and invisible** to the
optimizer at three levels: static, OS (`AILANG_FS_SANDBOX`), and runtime budgets.

**Beyond (Tier 5+).** Tiers 0–4 alter *hook bodies* behind a frozen ABI seam. Rewriting
Motoko's *core runtime* itself (supervisor/RPC/parser, and eventually the proposer loop →
true Gödel recursion) is the natural next frontier — recorded as a future direction, not
committed: same machine, but the frozen ABI and the evaluator boundary both get materially
harder. See *Future direction — altering Motoko's core itself*.

**Do first.** (0) **Bump Motoko to AILANG 0.25.0** (the grounded version) + `make
check_core`; (1) prove candidate isolation in `experiments/ar_candidate/`; (2) pick the
first target hook. Tiers 2 & 4's selection math can be prototyped in parallel on the cheap
Polyglot *prompt* fixture, off the critical path.

---

## 0. Thesis: decompose the proof obligation

Schmidhuber's 2007 Gödel Machine rewrites itself only after *proving* the rewrite
improves expected utility — undecidable in general, which is why DGM dropped it for
empirical benchmarking (`05` lines 22-27). But "prove utility improves" welds together
two obligations, and only one is undecidable:

- **Provable part (keep it):** the rewrite *preserves the harness's invariants* —
  type-correct, effect-bounded, evaluator-non-tampering, scope-confined. AILANG discharges
  these statically via the **type and effect system** (the workhorse) plus a static import
  check; Z3 contracts add only the narrow first-order fragment (termination/bounds stay
  mostly empirical — §2). Strictly weaker than "prove utility improves," but real.
- **Empirical part (relax it, DGM-style):** the rewrite *actually performs better* —
  measured on the benchmark, never proven.

The Motoko Gödel Machine is the loop that makes the provable part a **hard precondition
of self-modification** and the empirical part the **fitness signal**. This is strictly
stronger than DGM/HGM (which prove nothing) and strictly weaker than Schmidhuber's ideal
(which is intractable). The design effort lives in the **invariant set** (§2), not the
search: anything not encoded as an invariant, the optimizer is free to exploit — exactly
the DGM Appendix H attack (`05` lines 110-127).

---

## 1. Placement decision (settled)

**Core search/archive/selection upgrades evolve `motoko-ext-autoresearch` in place;
the formal verifier is a separable module.** Rationale:

- The Gödel Machine *is* the loop maturing, not a parallel system — HGM forked DGM and
  swapped one rule rather than rebuilding (`07` lines 11-14).
- Tiers 2 & 4 are **in-place surgery** on package internals (the `runs` schema in
  `db.ail`, `best_metric_value` at `db.ail:458`, the keep/discard at
  `autoresearch.ail:962-973`). A sibling extension could only do this by duplicating or
  reaching into non-public internals.
- The **evaluator boundary is already drawn around this package**: the polyglot config's
  `off_limits` lists `packages/motoko-ext-autoresearch/` and `scope.ail:43-59` enforces
  it. Keeping the selector/archive/verifier inside the package means they are
  automatically outside the agent's mutation scope (DGM's hard requirement, `05`
  lines 121-131) — for free.

New behavior lands as **new modules** (`archive.ail`, `select.ail`, `verify.ail`), not a
new extension — the package already decomposes into ~12 focused modules.

**The one carve-out — the verifier (`verify.ail`).** Interface:
`verify(candidate_path, scope_paths, off_limits) -> { ok: bool, reject_reason: string }`
(see §2 for the invariants it checks). It is *verification, not search*, with standalone
value. Start it as a module inside
autoresearch; promote it to its own extension **only if a second caller appears** (e.g.
a user-invocable `verify-extension` tool). Cheaper to promote later than to maintain a
cross-extension dependency nobody needed.

**Naming.** As Tiers 2+ land, "autoresearch" stops describing what the package does
(it becomes a self-modifying machine). Defer the rename until Tiers 0–2 prove out — it
is churn, not a blocker.

---

## 1a. What gets modified, and how the benchmark sees it (the architectural crux)

Two facts about the current loop reshape the whole plan and must be settled before any
tier:

**(1) The target is hooks the agent *uses*, not autoresearch's own hooks.** The
`motoko-ext-autoresearch` package's hooks (`on_build_system_prompt`, etc., wired in
`register.ail` / `autoresearch.ail:1158`) **are the machine** — they are off-limits and
must stay so. The Gödel Machine's self-modification target is the agent's *coding
behavior*: hooks in the **core runtime** (`src/core/`) or in **another extension** (e.g.
`context_mode`). "Pick the target hook" (open decision #1) means a hook in *that* set,
never autoresearch's own.

**(2) A compiled-hook edit only shows up if the benchmark runs the *candidate build*.**
This is the load-bearing difference from the current loop, and the real Tier 0 work.
`ar_run` does not build or run the agent — it executes an operator-supplied
**`benchmark_script`** in the worktree (`autoresearch.ail:861`). The existing prompt-tuning
loop works *only because* the prompt is a file read at runtime: edit the file, the
already-built agent picks it up, no rebuild. A hook is **compiled** AILANG. So for hook
self-modification the `benchmark_script` itself must, per candidate:

1. rebuild the runtime/TUI from the edited source **in isolation** (the worktree, so the
   baseline agent driving the loop is never disturbed), failing closed if the build fails;
2. spawn the benchmark against *that* candidate build (not the prebuilt `TUI_ENTRY` that
   `motoko_rpc.py` defaults to);
3. emit the same metric JSON the loop already parses.

This rebuild-and-run-candidate plumbing — not the hook edit — is the substance of Tier 0.
The `experiments/ar_candidate/` worktree (already present, with its own `.ailang` cache)
is the natural isolation boundary. Until this exists, "self-modification" is not actually
wired, no matter what scope_paths say.

**(3) The recursion is bounded: the mutation operator is fixed.** In DGM/HGM the *improved*
agent proposes its own next self-modification, so self-improvement compounds at *two*
levels (coding ability *and* the ability to self-improve). Motoko's loop is weaker by
design: the **baseline loop agent is the fixed proposer** of every candidate edit; the
candidate is a passive artifact that gets benchmarked, not a new proposer. This means:
- **What accumulates down the tree** is the agent's *coding behavior* — a child inherits
  its parent's accumulated hook edits and adds one (Tier 2's branch-from-parent). HGM's
  **clade pooling stays valid** on this tree: descendants are genuine variants of one
  lineage, so their pooled outcomes inform the ancestor's promise.
- **What does *not* happen** is recursive improvement of the *proposer*. The hand that
  writes the patches never gets better. This is the honest sense in which this is a
  *bounded* Gödel Machine — and it is the safer choice (a fixed, auditable mutation
  operator). Lifting it (letting a kept candidate *become* the proposer) is a deliberate
  future step, explicitly **out of scope** here.

---

## 2. The invariant set (the real design work)

These are the properties a candidate hook must satisfy *before* any benchmark spend. The
**effect system and `ailang check` are the workhorse** (statically decidable, always
applicable); the static import-graph check is cheap; **Z3 contributes only on the narrow
fragment it supports** (first-order arithmetic/boolean — it is *SKIPPED* on the
foldl/map-heavy code real hooks are, see `src/core/compaction.ail:33`). Do not treat Z3
as the primary mechanism. The set is the security boundary — treat additions to it as the
primary ongoing design task.

| # | Invariant | Enforced by (MCP-grounded, §AILANG grounding) | Tier |
|---|---|---|---|
| I1 | Candidate type-checks | `ailang check` (recursive: `ailang check src/`) | 1 |
| I2 | Candidate gains no new effect (no new `Net`/`AI`, etc.) | **frozen signature + `ailang check`**; belt-and-braces `[effects] max=[…]` in the target package's `ailang.toml` + `ailang iface` diff | 1 |
| I3 | Candidate writes only within `scope_paths`; touches nothing in `off_limits` | `scope.ail` (path-list) **+ `AILANG_FS_SANDBOX=<dir>`** (OS-level FS confinement of the candidate run) | 1 |
| I4 | Candidate module has **no import edge** to the grader / metric-collector / task-runner | parse of the module's `import` lines (not Z3) | 3 |
| I5 | Metric-collection path remains pure & deterministic | **effect system** (`pure func` / `! {}`); determinism testable via `--seed`/`--virtual-time` + `ailang replay` (exit 0 = match) — not Z3 | 3 |
| I6 | Candidate respects declared step/effect bounds | `ailang verify` (static, *only* the decidable fragment) **else** runtime `--verify-contracts` + effect budgets `@limit=N` (`--budget-report`) | 3 |

**I2 needs no separate hand-rolled effect-row diff — freeze the signature.** Keep each
target hook's *type signature* in `off_limits` and put only the *body* in `scope_paths`.
A candidate body that needs a new effect simply **won't compile** against the frozen row,
so `ailang check` (I1) enforces I2 for free. `ailang iface <module>` gives the normalized
JSON signature to diff if you want an explicit cross-check, and `[effects] max=[…]` in the
package manifest caps the whole package's effect set as a second wall (the toolchain even
emits an `effect-widening-warning` on publish). This is the distinctive AILANG guarantee
DGM/HGM cannot get: the exfiltrating mutation *cannot exist*, not "is penalized."

**Honest coverage note (MCP-confirmed fragment).** I1–I5 are statically guaranteed
(type/effect system + an `ailang iface` parse of imports). I6 is the weak one: `ailang
verify`'s decidable fragment is **pure (`! {}`), int/bool/enum params, arithmetic/
comparison/logical, `if`/`let`/`match` — non-recursive (named recursion only via
`--verify-recursive-depth N`), non-higher-order**, and it returns `SKIPPED` (with a reason)
on anything else. The autoresearch code is string- and foldl-heavy (`compaction.ail:33`
already records "SKIPPED — foldl"), so for most real hooks bounds stay **empirical** —
enforced *dynamically* at benchmark time via `--verify-contracts` + effect budgets, not
proven. Tier 3 must label each invariant "proven by X" or "empirical-only because Y" with
no silent gaps.

---

## Tier 0 — Rebuild-and-run-candidate plumbing (the thing that makes it self-modification)

**Goal.** Make a compiled-hook edit actually change what the benchmark measures. Per §1a,
this is the load-bearing tier: the work is the **candidate `benchmark_script`**, not the
hook edit. Target a hook in `src/core/` or another extension (never autoresearch's own
hooks — those are the machine, §1a(1)).

**Changes.**
- Pick the **first target hook** (open decision #1) — small blast radius, with a plausible,
  measurable effect on a benchmark. Set `scope_paths` to that hook's **body** and keep its
  **type signature off-limits** (enables the I2-for-free property, §2). `off_limits` keeps
  the whole `motoko-ext-autoresearch/` package and the grader.
- **Author the candidate `benchmark_script`** so that, per run, it: (a) builds the runtime
  from the worktree source **in isolation** (use the existing `experiments/ar_candidate/`
  worktree + its own `.ailang` cache so the baseline loop agent is untouched); (b) **fails
  closed** if `ailang check`/build fails — no benchmark run, automatic discard; (c) spawns
  the benchmark against the *candidate* build, overriding the prebuilt `TUI_ENTRY`
  `motoko_rpc.py` defaults to, ideally under **`AILANG_FS_SANDBOX=<candidate-dir>`** (MCP:
  confines *all* FS/zip/process-cwd operations to a directory — a hard OS-level scope wall
  beneath `scope.ail`) and a `--process-allowlist` so a candidate cannot escape its
  sandbox during the run; (d) emits the metric JSON the loop already parses.
- Confirm `git_ops.ail` commit/revert and `scope.ail` deviation detection behave on `.ail`
  source as on markdown (they are path-agnostic; verify, don't assume).

**No schema or selection changes** — Tier 0 reuses `ar_init`/`ar_run`/`ar_log` as-is; all
new behavior lives in the script.

**De-risking note.** The search-structure tiers (2 & 4) are *orthogonal* to whether the
artifact is a prompt or a hook — they can be built and validated on the existing cheap
Polyglot **prompt** fixture in parallel, then combined with hook-editing once Tier 0's
plumbing is solid. Tier 0 is the long pole; don't serialize everything behind it.

**Definition of done.**
- A hook **body** edit, rebuilt in isolation, demonstrably changes a benchmark metric
  through a full `ar_init → ar_run → ar_log(keep|discard)` cycle.
- A build failure yields automatic discard with **no** benchmark run (fail-closed proven).
- A scoped commit contains only the hook-body edit; a discard reverts it cleanly; the
  baseline loop agent is never rebuilt out from under itself.

**Risks.** Build time per candidate adds latency (each sample may rebuild) — cache
aggressively and rebuild once per candidate, not per sample. If the isolated build can't
be made to not disturb the running loop agent, this whole approach stalls — prove the
isolation first, before any hook-quality work.

---

## Tier 1 — Formal pre-filter gate (the cheap, distinctive AILANG guard)

**Goal.** Insert `verify.ail` between candidate proposal and benchmark eval. Reject I1–I3
(static subset) for free, before spending a benchmark run.

**Changes.**
- New module `verify.ail` exporting
  `verify(candidate_path, scope_paths, off_limits) -> VerifyResult`.
- **I1 + I2 together:** shell to `ailang check` on the candidate (`--json` for a
  machine-readable verdict); non-zero → reject with the compiler message as `reject_reason`.
  Because the hook *signature* is off-limits (§2), a body that needs a new effect fails this
  check automatically — no separate effect-row diff to write or maintain. Optional
  belt-and-braces: diff `ailang iface <module>` before/after for an explicit signature/effect
  delta, and set `[effects] max=[…]` in the target package's `ailang.toml` so the package's
  effect ceiling is enforced by the toolchain too.
- **I3:** reuse `scope.ail:compute_scope_deviations` to reject candidates whose writes fall
  outside scope (this is already the runtime gate; verify it also runs as a *pre*-benchmark
  filter, not only post-hoc). At *run* time the candidate is additionally boxed by
  `AILANG_FS_SANDBOX` (Tier 0), so I3 is enforced both statically (pre-benchmark) and at the
  OS level (during the run).
- Wire the gate into the eval pipeline so a failing candidate is logged as
  `decision=discard, flagged=true, flagged_reason="verify:<I#>"` and **never reaches
  `ar_run`'s benchmark step**.
- This is largely a re-ordering: Tier 0 already fails closed on build failure (`ailang
  check` is part of the build). Tier 1's value is making the rejection **explicit,
  attributable, and pre-benchmark** rather than an opaque build error — and recording it
  so the archive (Tier 2) can distinguish "illegal" from "worse".

**Definition of done.**
- A candidate whose body needs a new effect is rejected by `ailang check` (against the
  frozen signature) **without** a benchmark run, with a legible reason.
- A scope-violating candidate is rejected pre-benchmark by I3.
- Verify-rejected candidates are recorded distinctly from benchmark-discarded ones
  (so the archive can tell "illegal" from "worse").

**Risks.** Depends on `ailang check` exit codes / message stability — pin the `ailang`
version (ties to the open `ailang.lock` decision in KI-1). Add a `metrics_test`-style unit
test that a new-effect candidate is rejected and a benign body edit passes.

---

## Tier 2 — Archive + tree (DGM stepping-stones; rollback for free)

**Goal.** Replace the linear, forget-on-discard chain with an archive that keeps every
compiled candidate and forms a tree. This is the **enabling prerequisite** both research
docs flag (`07` line 197; `05` lines 98-106) — without a tree there is no clade to pool
over in Tier 4.

**Changes — `db.ail`.**
- Add `parent_run INTEGER` to the `runs` table (`db.ail:136`). A run's parent is the
  candidate it branched from (not necessarily the previous `run_number`).
- **Replace revert-on-discard with branch-from-parent.** Today `commit_or_revert`
  (`autoresearch.ail:975-986`) keeps (commit) or reverts (discard, killing it) — and the
  revert is what keeps the working tree clean for the next candidate. Don't just drop it:
  **commit every *compiled* candidate to its own ref/patch** (keep *and* discard), then
  start each new candidate by **checking out its selected parent** rather than reverting
  the previous one. This keeps the working tree clean (the reason revert existed) *and*
  retains discarded-but-valid nodes as branchable ancestors. The archive *is* the rollback
  mechanism (`05` lines 98-106). Caution: this interacts with the `AwaitingLog` state
  machine (`state.ail:65`) — the parent-checkout must happen at branch time, not log time.
- Add archive-read helpers: `children_of(run)`, `node_by_id(run)`, `archive_nodes(segment)`.

**Changes — `select.ail` (new, greedy for now).**
- Move parent selection out of the implicit "best kept ancestor" rule
  (`best_metric_value`, `db.ail:458`) into an explicit policy. Tier 2 ships the **greedy**
  policy (pick best node to expand) but behind the `select.ail` seam, so Tier 4 only
  swaps the policy, not the wiring.

**Definition of done.**
- `runs` rows carry a valid `parent_run`; `children_of` reconstructs the tree.
- A discarded-but-compiling candidate can be selected as a parent in a later iteration
  (demonstrable: branch from a node that lost its own keep/discard test).
- Rollback works via the archive (no dedicated revert step remains).

**Risks.** Storage growth (every candidate retained) — store patches/refs, not full
worktrees. Concurrency is **not** in scope (the loop is single-process, unlike HGM's
20-worker pool, `07` line 44); do not import HGM's async design.

---

## Tier 3 — Evaluator-boundary + purity enforcement (the Gödel tier)

**Goal.** Promote the evaluator-boundary and purity invariants (I4–I5) from convention to
*statically enforced preconditions* of self-modification — making the proof-before-rewrite
half of the thesis real. The workhorse is the **import graph and effect system**, not Z3;
Z3 contributes only on I6's narrow fragment.

**Changes — `verify.ail`.**
- **I4 (import-line parse, not Z3):** reject any candidate hook module whose `import`
  statements reference the grader, metric-collector, or task-runner. (DGM's ablation: hiding
  the checker from the optimizer measurably lowered hacking; `05` lines 121-127 — this makes
  "invisible" structural, not just "immutable.") AILANG imports are explicit top-of-file
  `import …` lines, so this is a cheap, total source parse — no `iface` needed. (`ailang
  iface` is used on the *export/signature* side for the I2 cross-check, not here.)
- **I5 (effect system, not Z3):** the metric-collection path must be `pure func` / `! {}`.
  Enforced by `ailang check` against frozen signatures (same mechanism as I2) — a metric
  path that acquires an effect won't compile. *Determinism* (beyond purity) is testable, not
  provable: run the path under `--seed`/`--virtual-time`, capture a trace, and `ailang
  replay` it (exit 0 = deterministic). No contract needed.
- **I6 (static where it fits, else *runtime* — never silently "proven"):** AILANG's static
  prover is **`ailang verify`** (Z3-backed; needs Z3 installed). Its **decidable fragment**
  (MCP-confirmed): pure `! {}`, int/bool/enum params, arithmetic/comparison/logical,
  `if`/`let`/`match`, **non-recursive** (named recursion only via `--verify-recursive-depth
  N`), **non-higher-order**. Per-function it returns `VERIFIED` / `VIOLATION` (with a
  counterexample) / `SKIPPED` (with reason) / `ERROR`; gate CI with `--strict` (exit 1 if
  any function can't be verified) and `--json`. For the foldl/map/string-heavy majority it
  returns `SKIPPED` (`compaction.ail:33` already records this) — for those, fall back to
  **runtime** enforcement during the benchmark: `ailang run --verify-contracts` checks
  `requires`/`ensures` dynamically, and **effect budgets** (`@limit=N` on effect types,
  `--budget-report`) bound how much FS/Net/Process a candidate may consume. Static-proven
  vs runtime-enforced must be recorded distinctly; do **not** label a runtime-checked
  invariant "proven."
- The gate now rejects I1–I6 before benchmark spend (static layers) and during the run
  (FS sandbox, budgets, runtime contracts); failures log `flagged_reason="verify:I4"` etc.

**Definition of done.**
- A candidate that imports the grader is rejected by I4 (`ailang iface`) with no benchmark
  run.
- A candidate that makes the metric path effectful is rejected by I5 (`ailang check`).
- At least one numeric bound is `VERIFIED` by `ailang verify`, and a deliberately-violating
  one yields a `VIOLATION` counterexample — demonstrating the static path works on the
  fragment it covers.
- The invariant set (§2) is documented with, for each row, "proven by X (static)",
  "enforced at runtime by Y", or "empirical-only because Z" — no silent gaps, and no runtime
  check mislabelled as a proof.

**Risks.** The temptation is to overclaim Z3 reach. The honest framing: Motoko's
Gödel-ish guarantees come from the **effect/type system** (strong, total) plus a **static
import check** (strong, total); Z3 is a narrow bonus. Anything not covered by those, the
optimizer can exploit (§0) — enumerate the gap, don't paper over it.

---

## Tier 4 — Clade-pooled non-greedy selection (the HGM tier; attacks R-noise)

**Goal.** Replace greedy `select.ail` with HGM's clade-pooled Beta-Bernoulli Thompson
selection on the **binary** benchmark path (Polyglot). Directly targets the open
**DoD #3 / R-noise** wall: at `samples=2` over 6 exercises, per-candidate variance ≈
candidate effect size, so keep/discard does not transfer to held-out TEST
(`handoff-...-continuation-2.md`; `07` lines 83-104).

**Changes.**
- **`db.ail` — per-exercise 0/1 outcomes.** Today `samples_json` stores per-sample
  *continuous* values and `metrics_json` a median aggregate (verified); there is no
  per-exercise Bernoulli breakdown. Store the per-exercise pass/fail vector so the clade
  can pool 0/1 outcomes.
- **Eval unit.** Make the atomic step one `(candidate, exercise)` eval rather than the
  whole TRAIN set × `samples` (`07` lines 96-104).
- **`select.ail` — Beta-Thompson over clade-pooled counts.** `alpha = 1 + Σ clade passes`,
  `beta = 1 + Σ clade fails`, sample + argmax (`07` lines 38-46). Replaces median+MAD as
  the *selection* signal on the Bernoulli path. Posterior width auto-encodes sample count,
  removing the hand-tuned MAD threshold (`07` lines 130-138).
- **UCB-Air expand-vs-evaluate** decoupled from expansion (`07` lines 48-54), optional —
  ship Thompson selection first, add UCB-Air only if the budget split needs it.

**Validate the algorithm cheaply first.** The selection policy is artifact-agnostic, so
debug it on the existing Polyglot **prompt** fixture (fast, no per-candidate rebuild)
*before* combining it with Tier 0's hook-editing. Note the metaproductivity framing only
holds because the artifact governs *agent* behavior (`07` lines 171-176) — a hook that
shapes coding behavior qualifies (it *is* scaffolding); a prompt does too. Both are valid
testbeds for the selection math.

**Scope guard (do not over-port).** This is a **Polyglot/binary-benchmark technique only**.
For continuous-throughput fixtures (simdscan/crc/intcodec) the Beta-Bernoulli estimator
*dissolves* — there is no success count and nothing coherent to pool (`07` lines 140-186).
Those fixtures keep the median+MAD path (or, if a tree is wanted there, a Gaussian bandit —
but that buys ordinary noisy tree-search, **not** Huxley-Gödel metaproductivity).
Demote annealing (`cool_down=false` by default) and "best-belief" final selection
(unconfirmed in HGM's code) — do not build on them (`07` lines 57-67, 198-200).

**Definition of done.**
- Per-exercise 0/1 outcomes are stored and pooled across a clade.
- Selection is Beta-Thompson over clade counts on the Polyglot path; the continuous
  fixtures are untouched.
- **DoD #3 met:** a kept change (prompt *or* hook body) transfers to held-out TEST, graded
  out-of-loop (TEST scores never visible to the optimizer mid-loop —
  `handoff-...-continuation-2.md`).

**Risks.** Highest-cost, highest-uncertainty tier, and the one with the live research
question. Depends on Tier 2's tree (no tree → no clade). Land Tiers 0–3 and confirm
DGM-for-Motoko works before committing here.

---

## Cross-cutting invariants (hold across all tiers)

- **Evaluator boundary** (DGM Appendix H, `05` lines 129-137): the grader, metric
  collector, task runner, and `verify.ail` itself stay in `off_limits` and — per I4 —
  structurally unreachable from candidate hooks. Clade pooling (Tier 4) adds samples, not
  integrity (`07` lines 201-203).
- **Defence in depth (MCP-grounded):** the candidate is boxed at three levels —
  *static* (`ailang check`/`verify`/`iface` pre-benchmark), *OS* (`AILANG_FS_SANDBOX` +
  `--process-allowlist`/`--process-timeout`/`--process-max-output` during the run), and
  *runtime contract/budget* (`--verify-contracts`, `@limit=N` effect budgets). No single
  layer is trusted alone.
- **TEST discipline:** TEST is graded out-of-loop only; TEST scores never enter optimizer
  context mid-loop (carried over from Phase 0.5a).
- **KI-1** (`max_output_tokens` cap) still gates which models can run a tier stably —
  `deepseek-v4-pro` is the one model that runs the loop without truncation; budget every
  tier's experiments accordingly.
- **Fail closed:** a candidate that fails to compile, verify, or rebuild is *always* an
  automatic reject, never a silent benchmark run.

---

## Build order & gating

| Tier | Yields | Depends on | Land before next if |
|---|---|---|---|
| 0 | Rebuild-and-run-candidate plumbing (a hook edit changes a metric) | — | isolated build proven not to disturb the loop agent; fail-closed on build failure |
| 1 | Explicit pre-benchmark filter (I1–I3) | 0 | new-effect candidate rejected by `ailang check`, attributably, pre-benchmark |
| 2 | Archive/tree, rollback-for-free | 1 | discarded-but-valid node is branchable |
| 3 | Evaluator-boundary + purity enforcement (I4–I6) | **1** | grader-import candidate rejected pre-benchmark |
| 4 | Clade-pooled non-greedy selection | 2, 3 | DoD #3 transfers to TEST |

This is the **integration** order. Two things can be prototyped *in parallel* off the
critical path: Tier 0's isolated-build plumbing is the long pole, while Tiers 2 & 4's
search/selection math is artifact-agnostic and can be debugged on the cheap existing
Polyglot **prompt** fixture meanwhile (§Tier 0 de-risking note, §Tier 4 validation note).
Tier 3 depends only on Tier 1's `verify.ail` module, **not** on the archive.

Tiers 0–2 = **DGM-for-Motoko** (working evolutionary self-improver). Tiers 3–4 = the
*Gödel* (proof) and *Huxley-Gödel* (non-greedy) additions. Do not start Tier 4 integration
until 0–3 demonstrably work — it is the research-risk tier.

---

## Future direction — altering Motoko's core itself (beyond the hook ABI)

**The boundary Tiers 0–4 deliberately stop at.** Everything above modifies *hook bodies* —
functions the runtime invokes through a typed seam (`ExtensionHooks`), whether the hook
lives in an extension or in `src/core/`. The seam is what makes the safety story cheap: the
hook's *signature* is frozen and off-limits, so `ailang check` enforces the effect-subset
guarantee for free (§2, I2). The runtime *itself* — the supervisor loop, the RPC
TUI↔runtime protocol, the parser, the prompt-construction pipeline, tool dispatch — is **not**
behind such a seam, and Tiers 0–4 never touch it. This is the natural next frontier, and it
is closer to true DGM (which rewrites its *whole* codebase, not a fixed hook set, `05`
line 32). It is **out of scope here** because the guarantees and the evaluator boundary both
get materially harder; this section records *what would have to change*, not a committed plan.

**What gets harder, concretely:**

1. **No free frozen ABI → invariant contracts must be authored for core.** A hook inherits
   I1/I2 from its frozen signature. The supervisor/RPC/parser have only *implicit* contracts
   (e.g. `register.ail:5`: "DO NOT rename `register_with_config` — it's the contract"). Before
   the agent may safely edit around them, those load-bearing contracts — the RPC JSON
   protocol, the step-budget/abort semantics, the tool-dispatch shape — must be made
   **explicit, frozen invariants** (typed signatures the candidate cannot edit, plus
   `requires`/`ensures` where the fragment allows). The invariant set (§2) grows from ~6 to
   a real surface; that authoring *is* the work.

2. **The evaluator boundary inverts: the loop runs *on* the code it edits.** With extensions,
   the whole `motoko-ext-autoresearch/` package + grader sits cleanly off-limits. Edit the
   core and the meta-loop (proposer agent + grader + `verify.ail`) is running on the very
   runtime under mutation. The hard requirement becomes a **pinned, immutable meta-loop
   build** (DGM's two-version / bootstrap pattern): the driver executes from a frozen copy of
   core, while the candidate core is built and benchmarked in full isolation
   (`experiments/ar_candidate/` + `AILANG_FS_SANDBOX`, exactly Tier 0's mechanism but now
   load-bearing, not a convenience). Without this, a candidate can corrupt the hand that
   grades it.

3. **Scope narrows to AILANG core; the TS TUI is excluded (at first).** The effect/type
   guarantee only covers AILANG (`src/core/`). The TypeScript TUI (`src/tui/`) has **no
   static effect guarantee** — editing it forfeits the whole proof half of the thesis. Core
   alteration should mean **AILANG core only**, with the TUI immutable, until/unless an
   equivalent guard exists for the TS side. Rebuild cost also rises to full `make build`
   (sync + check + build_tui), so cache and isolate aggressively.

4. **This is where the *fixed-proposer* boundary could be lifted — the highest-risk step.**
   §1a(3) keeps the mutation operator fixed: the baseline agent proposes every edit and never
   self-improves. If core alteration includes the autoresearch loop *itself*, a kept candidate
   could **become the proposer** — genuine Gödel-machine recursion (the proposer improves the
   proposer). That is the largest potential payoff and the largest risk in the entire
   programme; it must stay gated behind a working, audited core-alteration machine and an
   explicit human decision, never reached by default.

**Prerequisite.** None of this is reachable until the extension-scoped machine (Tiers 0–4) is
proven: core alteration *reuses every part of it* — the verifier, the archive/tree, the
selection policy, the three-level boxing — and only swaps "hook body behind a frozen seam"
for "core module behind an authored invariant contract." Treat it as **Tier 5+**: same
machine, larger and unbounded surface, with (1)–(2) as its entry gate.

---

## Open decisions (for the operator)

1. **First Tier-0 target hook** — which `src/core/` or non-autoresearch extension hook is
   the smallest blast-radius, most-measurable target, *and* affects a benchmark the loop
   already runs? (Drives Tier 0 entirely; not autoresearch's own hooks — §1a.)
2. **Isolated-build mechanism** — how the candidate `benchmark_script` rebuilds the runtime
   in `experiments/ar_candidate/` and points the benchmark at that build without disturbing
   the loop's own agent. The make-or-break feasibility question; settle before hook-quality
   work.
3. **`ailang` version — recommend bumping v0.24.2 → 0.25.0.** Repo is on **v0.24.2**
   (`ailang.lock`); KI-1's v0.19.1↔v0.22.0 framing is stale. **Bump to 0.25.0** (the version
   this plan is grounded against, and the latest the MCP serves) before Tier 1, so the
   `check`/`verify`/`iface` behaviour the verifier relies on is exactly the documented
   surface — not a patch line below it. The bump is a normal `ailang.lock` re-resolve +
   `make check_core` across all `.ail` modules to confirm nothing regressed; treat any new
   type/effect errors as part of the bump, not the Gödel work. Tier 3 additionally needs
   **Z3 installed** (`ailang verify` errors/skips without it). Re-confirm KI-1's
   `max_output_tokens` status post-bump — it may already be resolved at 0.25.0.
4. **Archive storage form** (Tier 2) — per-candidate git refs vs. stored patches vs.
   worktrees. Recommend patches/refs for storage economy.
5. **Verifier as module vs. extension** — keep `verify.ail` in-package until a second
   caller appears (§1).

---

## Next actions (resume here)

0. **Bump Motoko to AILANG 0.25.0** (decision #3): update `ailang.lock` (re-resolve), run
   `make check_core` across all `.ail` modules, fix any regressions, and confirm Z3 is
   installed. Do this before Tier 1 so the verifier targets the grounded toolchain surface.
1. Settle the **isolated-build** feasibility (decision #2): can a candidate be built in
   `experiments/ar_candidate/` and benchmarked without rebuilding the loop's own agent?
   Everything downstream assumes yes — prove it first.
2. Choose the Tier-0 target hook (decision #1) and a benchmark where editing its body moves
   the metric.
3. Verify `git_ops.ail` / `scope.ail` behave on `.ail` source as on markdown (Tier 0).
4. Author the candidate `benchmark_script`: isolated rebuild → fail-closed-on-non-compile →
   benchmark the candidate build → emit metric JSON (Tier 0).
5. Scaffold `verify.ail` with the I1/I2 (`ailang check` against frozen signature) gate only;
   add I3 once wired (Tier 1).
6. In parallel (off the critical path): prototype `select.ail` archive + Beta-Thompson math
   on the existing Polyglot prompt fixture (Tiers 2 & 4 algorithm).
7. Before Tier 3: confirm **Z3 is installed** in the loop environment (`ailang verify`
   needs it) and re-check KI-1's `max_output_tokens` status at the repo's pinned
   **v0.24.2** — it may already be resolved.
