# RESEARCH: The idea factory — how Motoko generates, evaluates, and kills ideas

Date: 2026-08-13
Status: Research — **opening draft**. §1 is measured at HEAD; §2–§5 are analysis; §6–§7 are
open threads, not conclusions.
Pinned binary: AILANG **v0.33.0** (`ailang.lock`)
Relates to:
- `.agent/projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md`
  — the mutation layer this note generalizes; its §3.4 oracle-governance rule is load-bearing here
- `.agent/projects/012_continuous_ailang_adoption/RESEARCH-continuous-ailang-feature-adoption.md`
  — pull-driven adoption; the registry it proposes is one view of §5's ledger
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md`
  — leverage-per-effort triage in practice; also the class of idea no existing oracle can score (§3.2)
- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  ("measure movement, not comfort") — the divergence evidence behind §4
- `.agent/meta-decisions/compare-speculated-end-state-to-actual.md` — the prediction-settlement
  discipline behind §3.5
- `NOTE-idea-creation-and-combination.md` — generation operators and combination
  schema that §2's join rule under-specified; does not reopen §3–§5

---

## 0. The question

Motoko's stated purpose is self-evolving software. Project 014 maps the machinery for evolving
the *harness source*: archive, selection, mutation operators, admission gate. But source
mutation is the last stage of a longer pipeline that begins with an **idea** — "adopt MGM's
comparative operators," "industrialize the shrinking seam," "make AILANG adoption pull-driven."
That upstream pipeline — signal → candidate idea → triage → grounding → staged commitment →
execution → measurement → feedback — is the **idea factory**, and Motoko already runs one,
manually.

Three questions, in order:

1. **What does the existing factory look like, measured?** (§1)
2. **How does it relate to auto-research and the recursive self-improvement loop of 014?** (§2)
3. **By what criteria is a new idea judged "good" — and can those criteria survive the
   transition from human selection to automated selection?** (§3–§4)

The third question is the point of the note. Every layer of 014's machinery assumes an answer
to it: DGM's novelty term, HGM's clade-metaproductivity, MGM's comparative eligibility, and
RQGM's epoch rule are all partial answers to "which change is worth attempting next, and how
would we know it was good?" — asked at the source level. This note asks it one level up, where
the candidates are research directions rather than diffs.

---

## 1. The factory that already exists, measured at HEAD

| Factory stage | Artifact | Count at HEAD | Evidence |
|---|---|---|---|
| Idea intake / grounding | `.agent/research/` | 26 entries | `ls .agent/research` |
| Staged commitment | `.agent/projects/` (RESEARCH → ADR → NOTE) | 14 numbered projects | `ls .agent/projects` |
| Design commitment | `design_docs/planned/` | 24 docs | `ls design_docs/planned` |
| Landed | `design_docs/implemented/motoko_agent/` | 4 docs | `ls design_docs/implemented/motoko_agent` |
| Second-order (ideas about the factory) | `.agent/meta-decisions/` | 5 standing disciplines | `ls .agent/meta-decisions` |
| Post-mortem feedback | `.agent/learnings/` | 6 entries | `ls .agent/learnings` |

Observations the table supports:

1. **The pipeline stages are real and enforced by convention.** Research notes carry explicit
   epistemic status lines ("Research — opening draft… §6–§7 are open threads, not
   conclusions"), staged proposals carry per-step decision points (014 §7 Q6's WI-1/WI-2 cut),
   and `planned/` vs `implemented/` separates commitment from delivery.

2. **The factory generates ~6× faster than it lands.** 24 planned design docs against 4
   implemented ones. Some of that is healthy queueing; some is the staleness 012 §4 documented
   (a `planned/` doc whose blocking capability shipped, was adopted, and nobody closed the
   loop). Nothing currently measures which.

3. **Selection is entirely human/Claude-session judgment.** In 014 §2's own terms, the WI
   project stream is "structurally Φ_CM with a human doing selection." There is no explicit
   record of ideas that were *considered and rejected*, so the factory's kill decisions —
   the most informative ones — leave no trace except scattered "not worth investing in"
   paragraphs (011 TL;DR names two).

4. **The second-order layer exists and has teeth.** The meta-decisions are not aspirational:
   `measure-movement-not-comfort` carries a findings-per-round table measured on project 009,
   and `compare-speculated-end-state-to-actual` carries a landed plan-vs-actual diff. The
   factory already improves itself; it just doesn't know its own throughput.

---

## 2. Idea factory, auto-research, and the 014 loop

The three concepts are one loop at increasing degrees of closure:

| Degree | Name | What is automated | Motoko instance |
|---|---|---|---|
| 0 | Idea factory | Nothing; conventions structure human work | `.agent/` tree (§1) |
| 1 | Auto-research | Grounding: read the paper/changelog, map onto the codebase, run the cheap probe | 014 itself — paper published 2026-08-07, mapped onto Motoko with a gap table by 2026-08-13 |
| 2 | Recursive self-improvement | Generation + selection + admission | none (014 is the design space map for it) |

Two structural points fall out of placing 014 inside this frame:

**The idea factory is the general case of the mutation operator.** 014 §3.3 already notices
the rhyme: 012's pull-driven adoption is "join registered debt × changelog delta"; Φ_RM is
"join failure clusters × mutation surface." Both are instances of the same generation rule —
**an idea is a join between a recorded weakness and a newly available capability** — applied
at different layers (research direction vs source diff). The factory's generation step and
MGM's comparative operators differ in granularity, not in kind.

That join is one operator, not the generation step. Import/blend, inversion, dual,
residual, unification, and layer are also in the corpus; combination well-typedness
and the mapping-table schema are in `NOTE-idea-creation-and-combination.md`.

**Degree 2 does not replace degrees 0–1; it nests inside them.** Even a running 014-style loop
only automates mutation *within* an epoch and a frozen mutation surface. Deciding to change
the oracle, widen the surface, adopt a new benchmark, or pursue a new research direction
remains factory work at degree 0–1. The RQGM epoch rule (014 §3.4) is precisely the statement
that this nesting is mandatory: the loop must not be allowed to do the factory's job on the
evaluator. So the idea factory is not a transitional scaffold to be discarded at degree 2 —
it is the permanent outer loop.

---

## 3. What makes an idea "good": five criteria, each with an on-disk precedent

None of these is "the idea sounds valuable." Each is stated as a testable property of the
idea's *artifact*, because that is what survives the transition to automated selection.

### 3.1 Provenance: it joins against recorded evidence of a weakness

An idea grounded in a recorded failure ("the census misses 3-of-12 port classes,
`test/stub_step.ail:508–512`") arrives with a testable claim attached; an idea from open
search arrives with a narrative. 012 made the economic argument (a join is cheap and
low-false-positive; a 49-kloc scan is neither); 014 §3.3 generalized it. For the factory this
is both a generation strategy and an admission criterion: **an idea that cannot name the
recorded evidence it joins against is not rejected, but it is queued behind those that can.**

### 3.2 …with a bounded exception for oracle-creating ideas

A factory that *only* admits evidence-joined ideas has a ceiling: the ledger only records
weaknesses the current oracles can measure. Project 011 is the counterexample that proves the
need — its payoff is a *better oracle* (mutation kill-rates per invariant family), which no
existing oracle could have scored. HGM's CMP faces the same problem at the source level (a
variant's value may be invisible to its own score and visible only to its clade). The factory
needs an explicit exploration budget — some fraction of throughput reserved for ideas whose
claimed payoff is a **new measurement axis** — evaluated at portfolio level, not per-idea.
What fraction is an open question (§6 Q2).

### 3.3 Cheap falsification with independent residual value

The best structural feature of the recent research notes is staging where each step is a
decision point and each step pays for itself even if the next never happens: 014 §4's "G1+G2
are the cheap 80%" (a keyed matrix is useful for regression attribution regardless of whether
any loop is built), and its §7 Q6 WI cut (report-only advisor before any automation). The
criterion: **a good idea decomposes into a cheap experiment whose failure kills it early, and
whose completed stages retain value after a kill.** An idea that pays off only if everything
downstream also happens is a bad idea regardless of how good it sounds — it is a commitment
wearing the costume of an experiment.

### 3.4 Gate-then-score acceptance, against an oracle whose strength is measured

Two halves, both already argued elsewhere and adopted here as factory policy:

- **Lexicographic, not scalar.** Correctness gates (typecheck, DST, replay-identity,
  contracts) are admissibility conditions, not terms in a weighted utility. 014 §3.1 applies
  this to mutants; the factory applies it to ideas: an idea whose acceptance criterion cannot
  be stated as gate-then-score is not yet a proposal, it is a sentiment.
- **The oracle must be measured before optimization pressure is applied.** 011's ranked item
  #3 (systematic SUT mutation, kill-rate per invariant family) is the measurement; running any
  selection loop against an unmeasured gate is an adversarial search against an unknown.
  And per `measure-movement-not-comfort` rule 3, the measurement must be two-sided: mutation
  coverage (rejection) paired with a survival fixture, sameness paired with movement. An
  idea-evaluation gate built only of must-fail checks cannot see that it also kills good ideas.

### 3.5 A settled prediction

`compare-speculated-end-state-to-actual` already mandates this for architecture: the planned
artifact is a hypothesis; after landing, produce the actual and classify the diff. The factory
generalization: **every admitted idea states its predicted outcome in the research note, and
the project is not closed until predicted-vs-actual is recorded.** Without this the factory
never learns whether its triage was any good — idea evaluation stays a priori forever. With
it, the factory accumulates a calibration record per idea-source (paper-driven, failure-driven,
exploration), which is exactly the signal a future automated generator would be weighted by.

---

## 4. Factory health is measured by kill rate and convergence, not output volume

Project 009 is the cautionary instance, and it is already written up: 154 findings across
eight delta-review rounds, findings-per-round *rising* after round two, nine correction
passes, **zero source changed** — a pipeline that looked productive at every step and was
diverging as a whole. The meta-decision's rule ("count findings per round; if the count is
not falling, the loop is not converging") is a factory-level health metric discovered the
expensive way.

The generalization, as candidate factory metrics — all computable from the `.agent/` tree
once ideas leave a trace when killed (§1 obs. 3):

| Metric | Healthy direction | Currently measurable? |
|---|---|---|
| Kill rate (ideas rejected / considered) | well above zero — a factory that never kills isn't evaluating | no — kills leave no artifact |
| Planned → implemented conversion, and age of `planned/` queue | conversion up, stale entries near zero | partially — 012 §4 found one stale by hand |
| Findings-per-round on review loops | falling | yes — but only 009 ever counted |
| Prediction calibration (§3.5) | improving per idea-source | no — predictions not yet mandatory |
| Cost of falsification per idea (tokens/hours to the 1-bit test) | falling | partially — eval instrumentation exists for benchmark runs only |

None of these needs new machinery; they need a **keying discipline** on existing artifacts —
which is the same conclusion 014 §3.1 reached about the benchmark archive (G1 is "a schema
field + a derived index," not a system). The rhyme is §5.

---

## 5. One ledger, three views

Three current proposals are converging on the same underlying object:

- 012 proposes a **debt registry**: where Motoko is compromised, keyed by missing capability.
- 014 (G1/G2) proposes a **variant × task × outcome matrix with lineage**: where Motoko is
  weak, keyed by variant and task.
- This note proposes an **idea queue with provenance, predictions, and kill records**: what
  Motoko intends to do about its weaknesses, keyed by the evidence joined against.

These are three views of one thing — a durable, queryable record of *where this system is
known to be weak and what is being done about it*. They should not be built three times.
The factory's input queue is the ledger's weakness rows; its generation rule is the join of
§3.1; its output feeds back as new rows (predictions settled, kills recorded, oracles
strengthened). Concretely, the cheapest unification is probably: 014's WI-1 index carries the
evidence keys, 012's registry entries and factory idea records reference those keys, and
nothing new is invented for this note at all.

---

## 6. Open questions

1. **Where do kill records live?** A `REJECTED-` prefix in the project dir, a section in the
   research note, or rows in the §5 ledger? The requirement is only that a kill leaves a
   trace with a reason, so the kill rate becomes computable and the same idea isn't re-litigated.
2. **What is the exploration budget** (§3.2), and who spends it? A fixed fraction of WI slots
   is the simple answer; HGM's answer (let clade statistics decide) needs the very lineage
   data the exploration would create.
3. **Should predictions (§3.5) be structured?** Prose predictions are cheap but hard to score;
   a `predicted:`/`actual:` field pair per research note is the minimal structured form.
4. **Does the factory itself fall under the RQGM epoch rule?** The evaluation criteria in §3
   are an oracle; a future automated generator optimizing against them will Goodhart them
   (e.g., manufacturing "recorded evidence" to join against). At degree 0–1 this is
   theoretical; before degree 2 it is not. Where is the line?
5. **Calibration bootstrapping.** The 14 existing projects are a retrospective calibration
   corpus — most stated intents and have measurable outcomes. Is a one-time retrospective
   scoring worth doing, or is it exactly the kind of self-referential accounting
   `measure-movement-not-comfort` warns goes stale?

---

## 7. Explicitly out of scope for now

- **Automating idea generation or selection.** This note is about making the manual factory
  measurable and its criteria explicit. Automation decisions belong after 014's WI-1/WI-2
  produce data, per its §7 Q6 ordering.
- **New tooling.** Every §4 metric is computable from artifact conventions; building a
  dashboard before the conventions exist would violate §3.3.
- **Re-ranking the current project queue.** The criteria in §3 are proposed for future
  admissions; retroactively scoring 001–014 is §6 Q5, not a commitment.
