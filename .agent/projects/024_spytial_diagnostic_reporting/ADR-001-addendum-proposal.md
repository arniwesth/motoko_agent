# Proposed addendum to 011/ADR-001 (program shrinking): two amendments from Spytial

**Status:** Proposed
**Date:** 2026-08-23
**Target:** `.agent/projects/011_improve_test_axises/ADR-001-adopt-program-shrinking.md`
(status Proposed, 2026-08-16 — amendable without a superseding ADR)

Relates to:
- `RESEARCH-spytial-implications-for-motoko.md` (this directory) — the derivation. Source:
  Prasad et al., *Diagramming Program Values by Spatial Refinement*, PLDI 2026,
  doi:10.1145/3808275, §5.1 (deterministic quasi-IIS by iterative deletion) and §5.2/§7.3
  (three-level reporting and its evaluation).
- `src/core/dst_run_report.ail` — where amendment B's report shape lands (D8 rules apply).
- `src/core/dst_corpus.ail` — where amendment A's stability matters (dedup, provenance).

The base ADR's decision — ddmin over the serialized `ExecutionProgram`, strict replay as
oracle, keep iff same violation constructor V — is unchanged. Both amendments constrain the
*implementation* the ADR already calls for; neither adds a new mechanism.

---

## Amendment A: determinism of the reduction is a requirement, not an emergent property

**Add to the Decision section:**

> ddmin's own iteration order — the order in which step subsets are attempted, and the
> order in which secondary per-field reduction runs — is **fixed and documented**. Given
> the same failing program P and the same violation constructor V, shrinking MUST produce
> the same minimized P\* and the same discard log, across runs and across machines.

**Why.** The base ADR inherits determinism from the pinned world, which makes each *replay*
deterministic — but says nothing about the search over candidates. An implementation that
iterates subsets in hash order, or races candidates, is replay-deterministic and still
produces different P\* for the same failure on different nights. Everything downstream
assumes stability: corpus dedup treats P\* as the identity of a failure class, provenance
records original/minimized step counts, and "same failure → same report" is what makes a
report trustworthy to a reader who saw it yesterday. Spytial names the same property for
its quasi-IIS ("the same invalid input produces the same quasi-IIS across runs") and the
same purpose: predictability when debugging. The house has already paid for this lesson
once — the discovery contract is an invariant over a *pair* of executions precisely because
determinism claims must be checked, not assumed (`dst_invariants.ail`,
`DeterminismFinding`). The natural check here is the same shape: shrink twice, compare P\*.

**Cost.** None at runtime beyond forgoing candidate-level parallelism inside one shrink run
(parallelism across seeds is unaffected). One paragraph of documented iteration order.

## Amendment B: the discard log is the report, not the accounting

**Add to the Decision section (extending step 3, auto-promotion):**

> The keeper's record of discarded candidates is promoted into the failure report, not only
> retained for over-firing accounting. For each surviving step k of P\*, the report carries
> a counterfactual annotation derived from the shrink search:
>
> - `removal-breaks-repro`: removing step k made violation V disappear — k is load-bearing.
> - `removal-changes-violation(V′)`: removing step k produced constructor V′ instead — k is
>   the boundary between failure classes, and the (P′, V′) pair is retained as a secondary
>   finding exactly as the base ADR requires.
> - `never-attempted-alone`: ddmin eliminated k only inside a larger chunk; no single-step
>   evidence exists. Stated explicitly so absence of an annotation is never read as
>   evidence of anything (the same no-silent-caps rule `ReachStatus` follows in
>   `dst_run_report.ail`).
>
> The report artifact obeys D8: retained bytes for P\* and for each cited P′, not digests
> alone, and a copy-pasteable strict-replay command per cited program.

**Why.** The base ADR computes this information and drops it into a side log. Spytial's
§5.2 is the argument for surfacing it: a minimal core alone ("half the battle") tells the
reader *what* conflicts but not *where it lives in the artifact*; the situated view — the
minimized program with the load-bearing steps marked — is what connects the rule to the
data. Their §7.3 study bounds the claim honestly: the situated artifact tripled
comprehension speed (112s → 35s, p=0.005) at equal accuracy, and helped nobody synthesize
a fix. For Motoko's primary reader — an agent triaging a nightly failure — comprehension
speed is tokens and tool calls spent localizing before the real work starts. The
annotations are causal statements ddmin has already paid for; the amendment is recognizing
them as report content.

**Cost.** A record shape in the report (the base ADR already budgets "the
kept/discarded same-vs-different-V accounting is a new record shape" — this fixes what that
shape must carry). Zero additional replay probes: annotations are derived from the search
ddmin performs anyway. Report size grows by the cited P′ programs; bounded by citing only
single-step-removal candidates, which is also the only granularity at which the causal
reading is valid.

## Explicitly out of scope

Repair suggestions (the study's Q3 null result says reporting does not buy them); any
rendering beyond the textual report (no diagram surface exists and none is proposed);
changes to the keep rule, oracle, or promotion policy of the base ADR.
