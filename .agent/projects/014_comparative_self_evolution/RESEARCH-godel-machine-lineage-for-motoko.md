# RESEARCH: How should Motoko utilize the Gödel-Machine lineage of self-improving agents?

Date: 2026-08-13
Status: Research — **opening draft**. §1 is a literature survey (external claims marked by
verification level); §2 is measured at HEAD; §3–§5 are analysis; §6–§7 are open threads, not
conclusions.
Pinned binary: AILANG **v0.33.0** (`ailang.lock`)
Relates to:
- `.agent/projects/005_harness_policy_boundary/` (what a mutation operator may touch — §3.6)
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md` (the acceptance oracle — §3.4)
- `.agent/projects/012_continuous_ailang_adoption/RESEARCH-continuous-ailang-feature-adoption.md`
  (pull-driven adoption is itself a Φ_RM-shaped operator — §3.3)
- `.agent/projects/013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md`
  (§2.A unified `WorldRequest` vocabulary is a hard prerequisite for §3.3's Φ_CH)
- `papers/motoko-dst-report/DRAFT.md` (replay-identity and interaction-log census — §3.3, §5)

---

## 0. The question

Motoko's stated purpose is self-evolving, self-verifying software. Between 2025 and 2026 a
family of papers — the "X Gödel Machine" lineage — converged on concrete machinery for exactly
this: an archive of agent variants, an empirical admission gate, a selection policy over the
lineage, and mutation operators that decide *what to change next*. Motoko has grown by a
different process (directed WI projects), and has never had an explicit evolution loop.

Two questions, in order:

1. **Which components of the lineage transfer to Motoko, and in what adoption order?** (§3)
2. **Where does Motoko's existing substrate — DST, replay artifacts, AILANG contracts — let it
   implement a *stronger* version than any published system?** (§5)

This note deliberately does not propose an implementation plan. It maps the design space and
names the prerequisites, so a later WI can be scoped against measured gaps rather than paper
abstracts.

---

## TL;DR

1. **The lineage is layered, not competing.** DGM contributes the archive + empirical
   admission skeleton; HGM the selection policy (clade-metaproductivity); MGM the mutation
   operators (comparative diagnostics); RQGM the governance rule for evolving the evaluator
   itself. Motoko would adopt them as layers in that order. (§1, §3)

2. **Motoko's benchmark archive cannot support any of this today.** Results are timestamped
   JSONL event streams with no harness-variant key — there is no (variant × task × outcome)
   matrix, so no comparative operator has anything to query. This is the single cheapest,
   highest-leverage gap. (§2, §4)

3. **DST inverts the lineage's cost structure.** Every paper spends benchmark evaluations to
   score mutants. Motoko can pre-filter with the DST profile suite — deterministic, fast,
   invariant-checking — so benchmark budget is spent only on mutants that provably still
   replay. No published system has an equivalent gate. (§3.1, §5)

4. **DST upgrades MGM's cross-lineage operator from correlational to causal.** MGM compares
   variants on shared tasks and asks an LLM to infer why one won. Motoko can replay two
   variants against the *identical world* and diff interaction logs member-for-member to the
   first divergent world request. This depends on 013 §2.A (unified request vocabulary) to be
   total rather than 9-of-12 port classes. (§3.3, §5)

5. **The Goodhart hazard is already live.** Motoko evolves its own oracle (011/013 are the
   agent redesigning its test system). RQGM's epoch discipline — freeze the evaluator within
   an epoch, update it only at boundaries under its own acceptance gate — should be adopted as
   a constitutional rule *before* any automated loop exists, not after. (§3.4)

6. **Honest blocker for headline comparability:** Motoko's Polyglot runner implements the
   `python` descriptor only (`benchmarks/README.md`), while MGM/HGM/DGM report on the full
   multi-language suite. Any "Motoko vs paper" number is not comparable until Go/Rust/JS/Java
   descriptors are wired. (§6)

---

## 1. The lineage, surveyed

| Paper | Year | Core contribution | Selection signal | Mutation trigger | Verification level |
|---|---|---|---|---|---|
| Gödel Machine (Schmidhuber) | 2003 | Self-rewrite only under a *proof* of improvement | formal proof | proof search (intractable) | classic; theoretical only |
| Gödel Agent (arXiv 2410.04444) | 2024 | Runtime in-memory self-patching via LLM | task feedback | free-form self-inspection | abstract read |
| **Darwin GM** (arXiv 2505.22954, ICLR'26) | 2025 | Replace proofs with empirical validation; **archive** of all variants, branch from any ancestor | benchmark score + novelty | single failure trajectory ("clonal") | paper + [open-source repo](https://github.com/jennyzzt/dgm) |
| **Huxley GM** (arXiv 2510.21614) | 2025 | Fixes DGM's *metaproductivity–performance mismatch*: expand the variant whose **descendants** performed best (CMP), not the best-scoring one; async tree search decouples creation from evaluation | clade-metaproductivity | still clonal | abstract + [repo exists](https://github.com/metauto-ai/HGM) |
| **Mendel GM** (HF papers 2608.07645) | 2026 | Comparative mutation operators mined from the archive at zero extra eval cost: Φ_RM (one variant across tasks → recurring-defect hypothesis), Φ_CH (two variants on shared tasks → behavior transfer). Thesis: comparative evidence shrinks the candidate-defect set | CMP-style + comparative evidence | comparative | **HF abstract only — headline numbers (78.3% SWE-bench Verified, 93.2% Polyglot) unverified against the PDF** |
| **Red Queen GM** (arXiv 2606.26294) | 2026 | Co-evolve agent **and evaluator**; utilities frozen within an epoch, updated at epoch boundaries ("controlled utility evolution") | non-stationary, agent-as-judge | adversarial / co-evolutionary | abstract read; paper self-describes as **preliminary** |

Reported trajectories, for scale (from the papers' own claims, same caveats as above): DGM
evolved a scaffold from 20.0%→50.0% SWE-bench and 14.2%→30.7% Polyglot; HGM reached
human-engineered-agent parity on SWE-bench Lite; MGM claims 78.3% SWE-bench Verified vs HGM's
73.3% at equal budget, and cross-model scaffold transfer (evolved on Qwen, run on
DeepSeek-V4-Pro).

The arc: **proofs → free-form self-patching → archives → lineage statistics → comparative
diagnostics → co-evolving judges.** Each paper repairs the previous one's dominant failure
mode. Two observations matter for Motoko:

- The components are **orthogonal layers** (archive / selection / mutation / oracle
  governance), so adoption can be incremental, and each layer is testable on its own.
- DGM's evolved improvements — patch validation, better editing tools, failure-history in
  context — are things Motoko already grew *by hand* through WI projects. The loop, where
  published, converges on real harness improvements; the question is mechanism, not
  plausibility.

Adjacent non-Gödel work (Escher-Loop 2604.23472, DARWIN 2602.05848, Group-Evolving Agents
2602.04837, DemoEvolve 2605.24539) is out of scope for this note; DemoEvolve's
sparse-feedback framing may become relevant to §3.3 if Φ_RM's failure clusters prove too
sparse to act on.

---

## 2. Baseline: what Motoko already has, measured at HEAD

| Lineage component | Motoko's nearest artifact | State | Source |
|---|---|---|---|
| Variant archive | git history; `experiments/ar_candidate/bench/` | branch history exists; `ar_candidate/bench` is **empty** — embryonic at best | `ls experiments/ar_candidate/bench` |
| Eval matrix (variant × task × outcome) | `benchmarks/results/` — 5 hashline dirs + ~20 `polyglot_events_run-*.jsonl` | **absent as a matrix.** Event streams are keyed by timestamp + model; no harness-variant/commit key appears in the event header | `benchmarks/results/`, header of `polyglot_events_run-20260531T105149Z.jsonl` |
| Fitness benchmark | Polyglot/Exercism runner, `pass_1`/`pass_2`/`fail`/`error` schema | actively supported, **`python` descriptor only**; TB adapter partial, Harbor placeholder | `benchmarks/README.md`, `benchmarks/aider_polyglot.py` |
| Φ_RM raw material | cross-task failure aggregation | exists as scripts, unconnected to any mutation step | `benchmarks/error_breakdown.py`, `benchmarks/tool_failures.py` |
| Φ_CH raw material | deterministic replay + interaction-log census | exists and strong, but census ranges over 9-of-12 port classes; unified vocabulary is 013 §2.A | `src/core/dst_replay.ail`, `src/core/dst_interaction.ail`, 013 §A2 |
| Admission gate | DST profile suite: 3 profiles, 11 fault classes, invariants | exists, 20,037 lines of `src/core/dst_*.ail` | `wc -l src/core/dst_*.ail`; `dst_fault_catalogue.ail` |
| Proof-adjacent gate | AILANG Z3 `requires` contracts | **used at exactly 2 sites in core** (`compress.ail:57`, `compress.ail:69`) — a proof of concept, not a gate | `grep -n requires src/core/compress.ail` |
| Mutation operator | WI projects (001–013) | manual, human/Claude-directed — structurally Φ_CM (single-concern clonal mutation) with a human doing selection | `.agent/projects/` |
| Oracle governance | none — 011/013 evolve the oracle in the same stream as the core | the Goodhart-relevant gap | — |

Reading the table: Motoko has the **strongest admission substrate** in the field and the
**weakest archive**. The lineage papers are the mirror image — rich archives, weak (purely
benchmark-score) admission. That asymmetry drives the whole adoption order in §3.

---

## 3. The mapping, layer by layer

### 3.1 Archive & admission — DGM's skeleton, DST as the gate

DGM's loop: maintain an archive of variants; sample a parent (score + novelty); mutate;
evaluate on the benchmark; admit to the archive if functional. Its cost center is evaluation —
every mutant, including junk, spends benchmark budget.

Motoko inverts this. A candidate self-modification can be required to pass, **before any
benchmark run**:

1. AILANG typecheck + contract check (`requires` clauses where present),
2. the DST profile suite — deterministic, seeded, minutes-scale,
3. replay-identity against recorded artifacts where the change claims behavior preservation.

Only survivors spend Polyglot budget. This converts DGM's dominant cost from
O(mutants × benchmark) to O(mutants × DST) + O(survivors × benchmark). No published system in
the lineage has a deterministic pre-admission gate; their only filter is "did the agent still
run."

**Gap to close:** the archive itself. Minimum viable representation is not new machinery — it
is a keying discipline: every benchmark event stream must carry the harness commit (and
profile) it ran under, and a small index must join (variant, task) → outcome. The results
schema change is a one-line addition to `aider_polyglot.py`'s event header; the index is a
derived file. Everything in §3.2–§3.3 queries this matrix.

### 3.2 Selection — HGM's CMP, and why it matters more for Motoko than for HGM

HGM's finding: a variant's *own* benchmark score is a poor predictor of its descendants'
quality (the metaproductivity–performance mismatch). Expand the lineage whose **clade** has
been productive.

Motoko's exposure to the mismatch is arguably worse than HGM's, for a specific reason: a
Motoko variant can raise its benchmark score by overfitting harness behavior to the task
format (e.g., Exercism-shaped edit loops) while making the core *harder to evolve* — and
"harder to evolve" is invisible to a score but visible to a clade. CMP is the correct signal
precisely when the mutation surface is a 49-kloc runtime rather than a thin scaffold.

HGM's second idea — asynchronous decoupling of creation from evaluation — maps cleanly onto
the two-tier gate of §3.1: DST-validate mutants eagerly (cheap, deterministic), benchmark them
lazily as budget allows, and let CMP consume whatever the matrix has so far.

### 3.3 Mutation — MGM's comparative operators, upgraded by determinism

MGM's thesis: comparative evidence improves self-modification **by shrinking the candidate
defect set**, not by making the editor smarter. Its two operators, in Motoko terms:

**Φ_RM (reaction-norm): one variant, many tasks.**
`error_breakdown.py` and `tool_failures.py` already compute the input — per-task failure
modes and tool-failure clusters for a run. The missing 20% is: cluster over the *matrix*
(not a single run), emit a defect hypothesis as prose, and feed it as a self-modification
task (`make run TASK=...`). Note the structural rhyme with 012: pull-driven AILANG adoption
is "join registered debt × changelog delta"; Φ_RM is "join failure clusters × mutation
surface." Both are cheap joins over registries Motoko already half-maintains, and both beat
their push-driven alternative (scan everything, guess what to improve) for the same reason.

**Φ_CH (cross-lineage): two variants, shared tasks.**
This is where Motoko can exceed the paper rather than replicate it. MGM's comparison is
*correlational*: variant B beat variant A on shared tasks; an LLM reads both trajectories and
infers what mattered. Motoko can make it *causal*: replay A and B against the **identical
world** (same seed, same scripted ports) and diff the interaction logs member-for-member to
the **first divergent world request**. The defect hypothesis is not "B tends to win" but "the
lineages diverge at exactly this tool call, with this request delta."

Two prerequisites, both already argued for on independent grounds in 013:

- **§2.A unified `WorldRequest`/`WorldResponse` vocabulary** — today the census ranges over
  9-of-12 port classes (`file_read`, `path_stat`, `dir_list` deliberately unrecorded,
  `test/stub_step.ail:508–512`), so a divergence in an unrecorded class is invisible to the
  diff. Φ_CH adds a second consumer to 013's case for making the log total.
- **Shrinking (011 §3.2)** — once a divergence point is found, shrinking the world script
  around it is the natural second stage; 013 already notes shrinking gets cheaper after §2.A.

Caveat that keeps this honest: benchmark tasks run against the *real* world (actual model,
actual sandbox), not scripted ports. Φ_CH-via-replay therefore applies directly where
failures reproduce under DST worlds (harness-logic divergences), and only indirectly where
the divergence is model-behavior-dependent. Expect a triage split: replay-diffable failures
get the causal treatment; the rest fall back to MGM's correlational reading. What fraction of
benchmark failures reproduce under scripted worlds is an empirical question — and a good
early measurement for this project (§7 Q3).

### 3.4 Oracle governance — RQGM's epoch rule as a constitution

RQGM co-evolves agents and evaluators, with utilities frozen within an epoch and updated only
at boundaries. Motoko should adopt the **discipline** without the adversarial machinery,
because Motoko's exposure is not hypothetical: projects 011 and 013 *are* the agent
redesigning its own oracle, in the same work stream that will be judged by that oracle. An
automated loop inheriting this arrangement can trivially Goodhart — mutate a DST invariant or
profile validator to admit its own descendant.

Proposed constitutional rule (to be ratified in a later ADR, stated here for discussion):

1. Within an evolution epoch, `src/core/dst_*.ail`, profile definitions, the fault catalogue,
   and invariants are **frozen** — no mutation operator may touch them (this is a
   policy-boundary entry in 005's terms).
2. Oracle changes happen only at epoch boundaries, as their own reviewed change, gated by the
   *previous* oracle plus replay-identity over the recorded artifact corpus.
3. The lineage records which oracle epoch each admission ran under, so CMP comparisons never
   silently span an oracle change.

RQGM is preliminary work; the epoch rule is the part that is load-bearing regardless of
whether its co-evolution results hold up.

### 3.5 The proof layer — partially reclaiming Schmidhuber

The entire lineage abandoned "provably beneficial" as intractable and substituted benchmark
scores. Motoko's substrate supports a middle tier no paper occupies: **verified-property
admission**. AILANG's Z3-checked `requires` contracts exist and run in core today — at
exactly two sites (`compress.ail:57,69`). Widening contract coverage along the mutation
surface (the policy boundary of 005) would let the admission gate check not just "still
replays" but "still satisfies stated properties," which is strictly stronger than any
published gate and strictly weaker than Schmidhuber's full proof — likely the right point on
the curve. Whether contract-widening is worth its annotation cost is an open question (§7 Q5),
and 012's registry gives the mechanism for tracking which AILANG verification features could
lower that cost.

### 3.6 What is explicitly rejected

**Gödel Agent-style runtime self-patching.** In-memory mutation with no artifact trail is
strictly dominated by source mutation under git + deterministic replay. Recorded here only so
a future reader knows it was considered.

**Unconstrained mutation surface.** MGM mutates a thin scaffold; Motoko's naive equivalent is
"anything in 49 kloc," including the oracle (§3.4) and the policy gate itself. The 005
policy-boundary work is therefore not adjacent to this project — it is a prerequisite: the
mutation operator's write-set must be an explicit allowlist, with `dst_*`, profile
definitions, and the boundary itself excluded within an epoch.

---

## 4. Gap table

| # | Gap | Blocks | Cost shape | Depends on |
|---|---|---|---|---|
| G1 | Benchmark events carry no harness-variant key; no (variant × task × outcome) matrix | everything in §3 | small — schema field + derived index | — |
| G2 | No lineage representation (parent links between variants) | §3.2 CMP, §3.3 Φ_CH pairing | small — metadata over git refs | G1 |
| G3 | Polyglot `python`-only | comparability with published numbers; fitness-signal breadth | medium — wire Go/Rust/JS/Java descriptors in `aider_polyglot.py` | — |
| G4 | Interaction-log census 9-of-12 classes | Φ_CH totality | large — 013 §2.A, argued there on independent grounds | 013 |
| G5 | No mutation-surface allowlist | safe automation of any operator | medium — 005 scope | 005 |
| G6 | No oracle-epoch discipline | Goodhart resistance | small (a rule) + ADR | §3.4 |
| G7 | Contracts at 2 sites | verified-property admission (§3.5) | open-ended; optional tier | 012 registry |

G1 + G2 are the cheap 80%: with a keyed matrix and parent links, Φ_RM is a script over
existing breakdown tools, and CMP is a fold over the tree — both computable before any
automation of the mutation step is attempted. G3 is independent and mechanical. G4–G7 gate
the strong versions, not the first versions.

---

## 5. Where Motoko exceeds the published systems

Stated as claims a future paper/report could defend, each with its dependency:

1. **Near-free admission.** Deterministic DST gating rejects broken mutants before benchmark
   spend; the lineage's per-mutant cost floor drops by the benchmark/DST cost ratio.
   (Depends: G1; strengthened by G5.)
2. **Causal cross-lineage diagnosis.** First-divergent-world-request localization replaces
   LLM-inferred trajectory comparison, for the replay-reproducible failure class.
   (Depends: G4 for totality; works partially today.)
3. **Verified-property evolution.** Contract + invariant gates as a tier between empirical
   validation and proof — a position no system in the lineage occupies. (Depends: G7.)
4. **Auditable lineage.** Every admission is a commit with a replayable artifact; the entire
   evolution history is re-checkable offline. DGM's archive stores scaffolds; Motoko's would
   store *proof-carrying* runs. (Depends: G1, G6.)

Claim 2 is the novel one; claims 1 and 4 are engineering leverage; claim 3 is the speculative
differentiator.

---

## 6. Honest caveats

- **MGM's numbers are abstract-level.** The 2608.07645 PDF has not been read end-to-end;
  78.3%/93.2% and the ~117×-fewer-parameters claim are quoted, not verified. Read before
  citing in any external document.
- **RQGM self-describes as preliminary.** Adopt the epoch rule on its own merits, not on
  RQGM's empirical results.
- **Polyglot comparability is currently impossible** (G3): `python`-only vs the papers' full
  suite. Any internal fitness trend is fine; any "vs paper" number is not.
- **The benchmark fitness signal measures the harness + model jointly.** Cross-model scaffold
  transfer (MGM's Qwen→DeepSeek result) suggests this is workable, and Motoko's
  provider-native tool protocol (post M-MOTOKO-RPC-LOOP-FULL-MIGRATION) makes
  evolve-on-cheap / run-on-strong natural — but fitness attribution between scaffold and
  model is unsolved in the papers too.
- **Compute reality.** DGM-class runs are thousands of agent-executions. Motoko's loop must
  be designed to produce value at *tens* of evaluations (CMP over a shallow tree, Φ_RM over a
  small matrix), or it will never run at all. This favors the archive-first, automation-last
  order of §4.

---

## 7. Open questions

1. **Fitness definition.** Polyglot pass-rate alone, or a composite including DST coverage /
   hermeticity metrics? (A composite re-introduces the oracle into the utility — interacts
   with §3.4.)
2. **Variant granularity.** Is a variant a commit, a branch, or a (commit × profile) pair?
   CMP semantics differ across these.
3. **What fraction of benchmark failures reproduce under scripted DST worlds?** This single
   measurement decides how much of Φ_CH gets the causal treatment vs the correlational
   fallback (§3.3). Cheap to measure once G1 exists.
4. **Who runs the mutation editor?** The papers use the subject model to edit itself; Motoko's
   Phoenix arrangement (Claude sessions author changes) blurs subject and editor. Does the
   loop's editor run *inside* Motoko (`make run TASK=...`) or remain an external session? The
   former is the pure Gödel-machine reading; the latter is what exists.
5. **Contract-widening ROI** (§3.5): which mutation-surface modules repay `requires`
   annotations first? Candidates: `compress.ail` (already started), `compaction.ail`,
   `step_machine.ail` (pure decide).
6. **Naming/scoping of the first WI.** Candidate cut: WI-1 = G1+G2 (keyed matrix + lineage
   index, no automation); WI-2 = Φ_RM as a report-only advisor (emits hypotheses, humans
   dispatch); automation decisions deferred until both have produced data.
