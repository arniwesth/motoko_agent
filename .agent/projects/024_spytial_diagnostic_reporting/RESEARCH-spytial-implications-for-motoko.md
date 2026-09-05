# Research: Spytial (PLDI 2026) and its implications for Motoko's failure reporting

Date: 2026-08-23. Status: research note, no code changes proposed beyond the ranked
follow-ups at the bottom and the companion ADR addendum. Source paper: `papers/3808275.pdf`
— Prasad, Tu, Kashyap, Nelson, Krishnamurthi, *Diagramming Program Values by Spatial
Refinement*, Proc. ACM Program. Lang. 10 (PLDI), Article 197, June 2026.
doi:10.1145/3808275. Artifact: doi:10.5281/zenodo.19401958 (supplement: 19520876).

Companion to: `ADR-001-addendum-proposal.md` in this directory (the two amendments this
note derives), `.agent/projects/011_improve_test_axises/ADR-001-adopt-program-shrinking.md`
(the adopted-but-unimplemented ddmin design the amendments target),
`src/core/dst_invariants.ail`, `src/core/dst_run_report.ail`,
`.agent/projects/023_hybrid_verification_cris/` (same reading pattern, previous paper).

_Written because the obvious reading — "a diagramming DSL for teaching data structures,
nothing for a headless agent harness" — is wrong in an instructive way: the diagramming
machinery does not transfer, but the paper's **diagnostic-reporting discipline for minimal
infeasible cores** lands directly on an ADR this repo adopted one week before the paper was
read, and has not yet implemented. The useful output is two concrete amendments to that ADR,
one reporting-layer gap with a study behind it, and three existing design decisions the
paper retroactively justifies._

## 1. What the paper is

Spytial is a small declarative DSL for diagramming **runtime program values**. A
specification is a set of rules, each made of a *selector* (an Alloy-style relational query
over the object graph — "all pairs x,y where y = x.left"), either a *constraint* (a hard
spatial requirement: orientation, alignment, grouping, cyclic placement, hiding) or a
*directive* (appearance only: color, icon, label). Rules compile to linear inequalities over
box coordinates; grouping/cyclic constraints add small structured disjunctions, solved by
bounded backtracking over an incremental linear solver. Embedded in Python (decorators +
reflection), Rust (serde interposition + proc macros), and Pyret (`_output` hook + YAML
strings) without modifying any language implementation. Semantics mechanized in Lean.

Three design pillars carry the paper, and all three matter here:

- **Semantics by conjunction, no variable bindings** (§3): every rule is independent of
  every other; any rule can be toggled off without cascading effects, and rule order never
  matters.
- **Constraints are hard, never best-effort** (§4–5): the explicit anti-Penrose position.
  Soft constraints "silently weaken or drop" violated relationships, absorbing them as
  visual imperfections — the reader cannot tell a satisfied diagram from a lying one.
- **Unsatisfiability gets a minimal core and a three-level connected report** (§5): a
  *quasi-IIS* (irreducible infeasible subsystem) is extracted by **iterative deletion** —
  remove constraints while infeasibility persists — yielding a subset-minimal, and by fixed
  iteration order **deterministic**, conflict set. The report then connects three levels:
  *constraint level* (which authored rules conflict), *element level* (which concrete
  atom-pair relations conflict), and *layout level* (a counterfactual diagram: the layout
  produced by relaxing exactly the IIS, with the involved boxes highlighted).

§7.3 evaluates the report with a between-subjects study (N=45, Prolific); §7.4 reports
deployment in a first-year data-structures course (median value size 16 atoms, median
render 130 ms). §8 shows the same constraints driving interactive value *construction*:
every rule that says how a structure must look also says which edits are valid.

## 2. Verdict

**Near-zero direct adoptability, high structural relevance — and this time the relevance is
convergent evolution, not analogy.** Spytial renders SVG in browsers/notebooks at
teaching-scale (16 atoms); Motoko is a TUI harness whose traces run to hundreds of records
and whose primary reader of failure output is an agent. There is no "integrate Spytial"
story.

But on inspection the DST framework has already independently built two of the paper's
three pillars, stated in almost the same words, and the third pillar — minimal-core
extraction by iterative deletion — **is** ddmin, which
`011_improve_test_axises/ADR-001-adopt-program-shrinking.md` adopted on 2026-08-16 and
nobody has implemented. The paper is therefore two things at once: external validation of
the DST reporting architecture, and a worked example of the one layer Motoko has not built.
Its §5.2 sentence names that layer: *"identifying an IIS is only half the battle."*

## 3. The mapping: convergent evolution, pillar by pillar

| Spytial concept | Motoko artifact |
|---|---|
| Semantics by conjunction; every rule independently removable | "Every rule is its own constructor, and that is load-bearing" — `dst_invariants.ail:19-28`; `violation_rule` total over ~36 constructors in 12 families |
| Its justification (argued in the paper) | *Measured* here: cluster 12's thirteen decode-mutation rows survived because each asserted its specific rule, not `length(findings) > 0` |
| Hard constraints; no silent best-effort (anti-Penrose) | D6.7: "a setup failure must not be dressed up as a successful empty trace" — `dst_result.ail:100-105`; disjoint `RunCompleted`/`RunFailed` classes rather than one class with a flag |
| Quasi-IIS by iterative deletion, subset-minimal | ddmin over `ExecutionProgram` steps, strict replay as oracle — ADR-001 (011), **adopted, unimplemented** |
| Conservative deletion near group constraints (don't prune essential members) | ADR-001's keep rule: candidate kept iff the violation is the *same constructor V*, atomic call+result removal preserving pairing |
| Deterministic quasi-IIS: "the same invalid input produces the same quasi-IIS across runs" | **Unstated in ADR-001** — amendment A, see §4 |
| Constraint level of the report (authored rule + intent) | `violation_rule` + `family_obligation` carried as data; every message leads with its bracketed rule id, *checked* at `dst_invariants.ail:1949` |
| Element level (concrete conflicting relations) | The violation constructors' payloads: positions, names, counts |
| Layout level (situated counterfactual artifact) | **Missing** — amendment B and follow-up 2, see §§4–5 |
| "Representative branch" pragmatics (report the final failing branch, already in hand) | First-violation reporting (`dst_invariants.ail:1646`) — same class of pragmatic pick, same admitted open question of which representative is most informative |

The two convergences in rows 1–3 are worth a sentence each in the ADR record because they
are *independent* arrivals at the same design under different pressures: Spytial got there
from human factors (users toggling rules while debugging specs), Motoko from mutation
testing (rules that survive corruption only if asserted specifically). When two pressures
select the same structure, the structure is probably right.

## 4. The sharp implication: ADR-001's discard log is a counterfactual report nobody has recognized

ADR-001 already requires the ddmin keeper to record shrink candidates discarded because the
violation *changed constructor* — framed as accounting ("so the over-firing direction stays
visible"). Spytial's §5.2 reframes that byproduct as the centerpiece: every discarded
candidate is a causal statement about the failure.

- Candidate P′ = P\* minus step k, and the violation **disappears** → step k is
  load-bearing for V.
- Candidate P′ = P\* minus step k, and the violation **becomes V′** → step k is what
  distinguishes V from V′ — the boundary of the failure class.

Rendering the minimized program P\* with each surviving step annotated by what its removal
did during shrinking **is** the DST analogue of Spytial's best-effort diagram with the IIS
boxes highlighted: a situated artifact in which the failure is visible *in context*, built
entirely from data ddmin already computed on its way to P\* and was going to drop into a
side log. No new search, no new oracle runs.

Two amendments to ADR-001 fall out, written as adoptable text in
`ADR-001-addendum-proposal.md`:

- **Amendment A — determinism of the reduction is a requirement, not a hope.** ADR-001
  gets *replay* determinism from the pinned world, but never states that ddmin's own
  iteration order must be fixed. Without it, the same nightly failure can minimize to
  different P\* on different runs, and corpus dedup, provenance, and "same failure →
  same report" all churn. Spytial names the property and its purpose: predictability when
  debugging, and a stable artifact for the same failure.
- **Amendment B — promote the discard log from accounting to the failure report.** Keep the
  over-firing accounting; additionally emit, per surviving step of P\*, the counterfactual
  annotation derived from the discard log, as part of the run report artifact
  (`dst_run_report.ail`'s D8 rules apply: bytes retained, not just digests; copy-pasteable
  replay command per candidate).

## 5. What the §7.3 study actually licenses

The study is easy to over-read (first pass here did). Precisely: accuracy did **not**
differ across text-only / diagram-only / both conditions on any question. What differed,
and what failed everywhere:

1. **Rule identification failed in all conditions** (6–7% success): shown element-level
   conflicts, readers could not recover which authored rules caused them. This is the trap
   Motoko already guards against — every violation message leads with its rule id and
   `family_obligation` carries the intent as data, with an invariant checking the prefix.
   The paper retroactively justifies that guard; do not weaken it for terseness.
2. **The situated artifact tripled comprehension speed** (112s → 35s, p=0.005) at
   equal-or-better accuracy. This is the evidence for follow-up 2: today a violation
   carries `position: int` and the reader must separately fetch the trace and index into
   it. For an agent reader, comprehension speed is tokens and tool calls spent localizing;
   an inline minimized-trace excerpt around each violating position is the cheap version
   of the best-effort diagram.
3. **Nothing helped the "how would you modify the data to fix it" question** (~50%, no
   condition effect). Tempering for amendment B: counterfactual annotations aid
   *localization*, not *repair synthesis*. The report tells the agent where the failure
   lives and which steps are load-bearing; it does not and should not claim to say how to
   fix the harness.

## 6. Omnigraph and mermaid: recorded so it is not re-litigated

The paper's related-work critique of mermaid/DOT — spatial intent is a hint the layout
engine may ignore; a diagram that misrepresents structure fails silently — applies in
principle to `omnigraph/extractions/decision_graph.mmd` (201 nodes, 12 subgraphs). It does
not currently matter in practice: subgraph grouping is the one spatial constraint mermaid
honors, these diagrams are human-facing documentation, and no agent or check consumes them
as data. Constraint-checked diagram specs become worth revisiting only if an omnigraph
visualization ever becomes load-bearing (e.g., an agent reads a rendered graph back as
evidence). Until then: no action.

## 7. An AILANG embedding is feasible by the Pyret route, and premature

§6 is a deliberate recipe for embedding without touching the language implementation. Of
the three embeddings, Pyret is AILANG's twin: no annotations, no macros, no runtime
reflection. Pyret attached specs as YAML strings through the `_output` hook and recovered
structure by recursive descent over the value skeleton; AILANG could do the same through a
show-style hook over typed values. Feasible — but with no consumer today, and a scale
mismatch worth pinning before anyone dreams of "rendering DST traces": Spytial's real-use
median was 16 atoms and 130 ms; a `LedgerTrace` runs to hundreds of records. If this is
ever wanted, it is an `ailang-feedback` upstream idea (a value-skeleton/`_output` analogue
in the runtime), not Motoko work.

## 8. Ranked follow-ups

1. **Implement ADR-001 ddmin with the two amendments** (`ADR-001-addendum-proposal.md`):
   fixed iteration order stated as a determinism requirement; discard log promoted into
   per-step counterfactual annotations in the failure report. The expensive half (strict
   replay oracle) exists; the amendments cost design discipline, not compute.
2. **Situate violations in the run report**: alongside each violation's rule id and
   payload, include a minimized-trace excerpt around the violating position(s) instead of
   bare integers. Licensed by the study's one significant result (§5, point 2).
3. **Recorded options, no action**: omnigraph constraint checking (§6) and the AILANG
   Spytial embedding (§7).

None of this requires SVG rendering, browsers, a solver, or new AILANG features. It is all
expressible in the existing DST idiom, and 1–2 largely *reinterpret* work already adopted.

## 9. What deliberately does not transfer

Recorded so it is not re-litigated: the spatial constraint language itself (selectors,
orientation/alignment/grouping — Motoko has no diagram surface and its reader is an agent);
the linear-solver machinery and Lean mechanization; SVG/browser rendering and the TUI
mismatch; interactive value construction (§8 of the paper — the "spec doubles as edit
validity" idea rhymes with generator-constraint sharing but earns no work item); the
cognitive-science grounding (informative, actionless here). The paper's artifact is worth a
skim only for the quasi-IIS extraction code as a reference implementation of deterministic
iterative deletion — the exact loop ADR-001's implementer is about to write.
