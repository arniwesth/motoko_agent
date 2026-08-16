# Probabilistic Symbolic Execution for Motoko

**Paper:** "Probabilistic Symbolic Execution" — Jaco Geldenhuys, Matthew B. Dwyer, Willem Visser (Stellenbosch / U. Nebraska-Lincoln), ISSTA 2012, 11 pp.
**Source:** https://praveenabt.github.io/teaching/2021-TN-resources/probsymex.pdf
**Implementation:** ~1000-line Symbolic PathFinder (JPF) listener calling the LattE model counter; part of the standard SPF release. Java-only.
**Analyzed:** 2026-08-15

## Why this paper matters to Motoko

Ordinary symbolic execution answers a 0/1 question per path: satisfiable or not. The paper refines that to a *probability*: model-count the solutions to each path condition, divide by the input domain size, and every path — and every branch, decision arm, and fault-recovery site — gets a number instead of a bit.

Motoko already makes path-probability arguments constantly; it just makes them **by hand, in prose**. The DST generator's fault rates (`src/core/dst_generator.ail:590-720`) are hand-tuned integer-modulo draws justified by inline comments like *"a uniform-over-three fault choice would have killed a third of every sweep at step 0"* — that is exactly the quantity PSE computes. The fault catalogue's waiver evidence is *"measured: 0 of 260 seeds produced one"* — which cannot distinguish "unreachable" from "needs ~10,000 seeds." And [011 §3.7](../../projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md) already proposes symbolic execution over `decide` to turn the two waived fault classes into proofs or bugs; PSE is the quantitative upgrade of that exact idea.

The framing that survives scrutiny: **PSE is the natural third stage of a pipeline Motoko is already building.** Stage 1 (exists): sampled DST with hand-tuned rates. Stage 2 (planned, 011 §3.7): exhaustive/symbolic reachability over `decide` and the waived fault classes. Stage 3 (this paper): attach probabilities to what stage 2 enumerates.

## Paper summary

Symbolic execution describes each path by a path condition (PC) — a conjunction of constraints over symbolic inputs. Satisfiability checking gives 0/1; the paper computes the real value in between:

> prob(path) = count(solutions of PC) / product(input domain sizes)

assuming inputs are **uniformly distributed over bounded domains**. Contributions:

- **Model counting via LattE** (lattice-point enumeration over convex polytopes), restricted to **linear integer arithmetic** — exact counts, cost independent of domain size.
- **Two optimizations** that make it scale: *PC slicing* (count only the constraint slice relevant to the current branch — reuses the independence structure the solver already exploits) and *count memoization* (canonicalize sliced PCs; the hit rate is high because programs re-issue structurally identical constraints).
- **Precise vs. Sum**: exact probability of *reaching a location* requires the disjunction over all PCs reaching it (2ⁿ LattE calls); the sum of per-path probabilities is cheap and empirically ≈ exact whenever slicing works (paths differing on irrelevant conditions are disjoint events).
- **Applications demonstrated**: (a) *bug finding via most-unlikely paths* — ranking paths by improbability surfaced a previously unknown bug in BinomialHeap that needs a 14-call API sequence to trigger; (b) probabilistic branch-coverage profiles for container libraries (BinaryTree, TreeMap, BinomialHeap); (c) the future-work list: probability-*guided* symbolic search, biasing test generation toward rare paths, prioritizing differential analysis by execution likelihood, and statistical sampling as fallback where counting fails.

Sequences of operations are handled by encoding each call's choice and argument as fresh symbolic variables (`c_i ∈ [1,2]`, `v_i ∈ [0,n]`) — the drivers in the paper's Figure 3 are structurally the same shape as a DST `ExecutionProgram`: a bounded sequence of (choice, value) draws.

## The modeling trick that makes this apply to Motoko

Do **not** reason symbolically about the Lehmer PRNG (`x' = 48271·x mod 2³¹−1` in `dst_generator.ail`) — intractable and pointless. Instead, treat each `draw(g, salt, bound)` as a **fresh symbolic variable uniform over `[0, bound)`** — which is precisely the paper's uniform-input assumption, and precisely what the PRNG is engineered to approximate. Under that lift:

- The hand-tuned non-uniform rates fall out as branch conditions over uniform draws (`draw mod 12 == 0` → non-retryable provider fault). No distribution machinery beyond uniform is needed — Motoko's generator *already* factors every distribution through bounded uniform draws.
- Everything is linear integer arithmetic over small bounded domains — the exact fragment LattE and the paper handle, and comfortably within AILANG's Z3 fragment for non-higher-order code.
- The reproduction key is untouched: this is offline analysis over the generator's *choice structure*, not a change to how draws are made. The RNG canary (`dst_generator.ail:950-1050`) and D1 (no ambient RNG in `src/core`) are irrelevant to it and unviolated by it.

**Enumeration-as-model-counting (the pragmatic entry point):** for the domains involved here, no LattE port is needed. 011 §3.7 already plans small-scope exhaustive enumeration over bounded projections of `StepState`. During enumeration, model counting collapses to *counting*: tally which concrete draw-vectors reach which decision arm / fault class / invariant family, divide by the space size, done. Exact probabilities as a free by-product of a gate that is already on the roadmap. Symbolic PCs + a counter only become necessary when the bounded space outgrows enumeration (longer trajectories, larger payload domains) — and by then the enumeration results are the ground truth to validate the symbolic implementation against.

## Where it plugs in (descending order of fit)

### 1. Derived, not hand-argued, generator rates

PSE over the generator + driver composition computes, per seed: P(trajectory reaches fault class C), P(recovery branch B executes), expected invariant-family coverage. That replaces the prose arguments at `dst_generator.ail:590-720` with derived numbers, and answers the operational question the sweeps currently answer empirically: **how many seeds buy coverage target X?** PR sweeps run `DST_SEEDS=5`, nightly `DST_SEEDS=500` (`.github/workflows/verify-extensions.yml:101-103`) — both numbers are folklore. A computed coverage-per-seed-budget table makes them engineering.

Second-order use: *invert* the analysis. Given a target coverage profile (every fault class reached with P ≥ p within N seeds), solve for the rates — the generator's 1/4, 1/12, 1/8 constants become outputs of a stated objective instead of inputs defended by comments.

### 2. Waived fault classes: from "unreached in 260 seeds" to a number

011 §3.7 verbatim: symbolic execution *"could settle whether the 2 waived fault classes are truly unreachable or merely unreached — turning waivers into either proofs or bugs."* PSE adds the third, most useful outcome for the *reachable-but-rare* case: **P(reach) = 1/2¹⁸ ⇒ expected seeds ≈ 260,000 ⇒ the 260-seed waiver evidence was never going to see it.** A waiver backed by a computed probability is a different epistemic object than one backed by an absence. This directly answers the DST report's own §8 self-criticism (*"Reachability is not oracle strength"*) — coverage claims become "reached with this probability under this budget," not "reached at least once."

### 3. Per-arm probabilities for `decide`

`decide` in `src/core/step_machine.ail` (436 lines) is pure, total, ~50 branches over `StepState` — the repo's single most SE-tractable function, already the named target of 011 §3.7. PSE over it (with `StepState` fields given the distribution the generator induces) yields a probability per `StepDecision` arm: which arms the sweeps exercise constantly, which are one-in-a-million. The paper's headline application — **ranking by improbability to find bugs** (that is how they found the 14-call BinomialHeap bug) — applies verbatim: the least-likely reachable arms and recovery branches are exactly where sampled DST provides the least evidence and where scrutiny should concentrate.

### 4. Shrinking: path conditions answer 011's open question

011 §3.2's open design question: what counts as "the same failure" for ddmin over `ExecutionProgram`? (Same violation constructor is both too coarse and too fine.) PCs give a principled middle: **two failing programs are the same failure iff their sliced path conditions match** — finer than constructor identity, coarser than trace identity, and computed rather than declared. Additionally, PSE-guided shrinking can prefer the *most probable* minimal reproducer, i.e. the one future sweeps are likeliest to re-encounter.

### 5. Later: probability-guided generation

The paper's future work — biasing search toward rare paths — is, in DST terms, an importance-sampling generator: boost draws whose PCs lead toward under-covered fault classes. Deferred: it changes the generator (version bump, program-schema implications) and should wait until the offline analyses (1–4) have proven the probability model against enumeration ground truth.

## Blockers and honest caveats

- **No off-the-shelf tooling.** SPF+LattE is Java. For AILANG this is built, not installed. Mitigation: the enumeration-as-counting entry point needs zero new solver infrastructure, and AILANG already ships Z3 4.15.4 (`ailang verify`) for the symbolic stage.
- **AILANG's Z3 fragment is non-higher-order.** Folds are out (`compaction.ail:16` — "contracts: SKIPPED — uses foldl"); only 6 contracts exist tree-wide; `--verify-recursive-depth` interaction with deep ledger folds is an open question (011 §3.1). `decide` itself is first-order and fits; the driver composition largely does not, *yet*.
- **`c2_loop` is not symbolically executable today.** 662 effectful lines (`session.ail:2240-2902`). The [013 §2.D](../../projects/013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md) "commands + interpreter" refactor is the enabler: a reified command language is exactly the substrate a symbolic interpreter wants. PSE strengthens the case for 013.D but should not wait for it — targets 1–3 need only the generator's choice structure and `decide`.
- **Sum vs. Precise:** adopt the paper's position — report per-path sums, rely on slicing/disjointness for accuracy, and validate against enumeration counts where the space permits. Do not attempt exact disjunction probabilities (2ⁿ blowup).
- **The uniform-draw lift is a model, and models drift.** The analysis is sound only while every stochastic choice factors through `draw`/`draw_between`/`bounded_draw`. That is currently enforced culturally and by D1; a structural gate ("all randomness flows through the draw API") would make the PSE precondition mechanical. Cheap, and worth doing first.
- **House rules are satisfied but must stay satisfied.** No in-code fault points are added (faults remain outcomes at the typed boundary — PSE only *analyzes* the existing choice structure); and per the mutation-testing rule, any claim "the analysis would detect a mis-tuned rate" needs a surviving control fixture (a rate change the analysis correctly leaves unflagged), same as every other guard.
- **Scope limit:** this analyzes the harness, never the LLM. Path probabilities say nothing about model behavior. That is not a compromise — it is the same line the DST report already draws (invariants over the typed ledger, never over model prose). PSE respects the boundary rather than fighting it.

## Relation to existing threads

- **[011 test axes](../../projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md)** — PSE is not a ninth axis; it is the quantitative completion of axis §3.7 (small-scope enumeration / symbolic execution) and supplies the missing failure-equivalence for axis §3.2 (shrinking). It also sharpens §3.3's kill matrix: cells become "killable with probability p per seed" instead of boolean.
- **[013 core architecture](../../projects/013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md)** — the commands+interpreter refactor (§2.D) is the long-run enabler for symbolic execution past `decide`; PSE adds a concrete consumer to that refactor's cost-benefit case.
- **[014 Gödel-machine lineage](../../projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md)** — §3.5's proof layer gets a quantitative tier: between "DST sampled it" and "Z3 proved it" sits "computed probability under the generator's measure." For DST-as-admission-gate, a self-modification's evidence can state the probability the gate *would have* caught a given fault class — oracle strength as a number.
- **Tsetlin Machine notes** ([synthesis](../Tsetlin_Machines_AILANG_Synthesis.md), evidence gates) — complementary, not overlapping: TMs *learn* probabilistic classifiers from data; PSE *computes* probabilities from code structure. Both feed the same evidence-gate vocabulary.
- **DST technical report** (`papers/motoko-dst-report/DRAFT.md`) — targets 1–2 are a natural lineage section: the report's §8 concedes reachability ≠ oracle strength, and PSE is the established technique that quantifies exactly that gap, with an ISSTA-2012-vintage citation trail (SPF, LattE, and the later statistical/sampling follow-ups) already mapped.

## Suggested first move

Fold a counting pass into the 011 §3.7 enumeration gate when it is built: same bounded projection of `StepState`, same exhaustive walk, plus a tally per `StepDecision` arm and per fault class, emitting a probability table as a build artifact. Zero new solver infrastructure, immediately falsifiable against sweep frequencies (nightly `DST_SEEDS=500` gives an empirical histogram to compare), and it produces the ground truth any later symbolic implementation must reproduce. The structural "all randomness through the draw API" gate is the one-afternoon prerequisite worth doing regardless.
