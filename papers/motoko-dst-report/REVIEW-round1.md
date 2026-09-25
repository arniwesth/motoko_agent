# Review round 1 — 2026-08-10

Protocol: three independent reviewer personas (fresh contexts; one on a different model),
per the freeze checklist in SCOPE.md (adopted from Deli Chen's paper-writing skill).
Calibration: 6.0 workshop · 7.0 main-conference · 8.0 strong accept · 9.0 oral.

## Scores

| Reviewer | Lens | Score | Recommendation |
|---|---|---|---|
| R1 | DST practitioner (repo fact-check allowed) | 7.5 | Accept |
| R2 | Skeptical epistemologist (record-fidelity audit) | 6.5 | Weak Accept |
| R3 | Newcomer, different model (paper-as-standalone) | 7.0 | Weak Accept |

**Median: 7.0. First-round cap: 7.0. Round-1 score: 7.0.**

R1 and R2 independently re-verified the §6 arithmetic (40/19/18/21/1, 32/16, 7+1, 15m27s,
0-of-260, 13-vs-12) against the D28 note: all match.

## Weaknesses and disposition

| # | Reviewer | Severity | Finding | Disposition |
|---|---|---|---|---|
| 1 | R2 | MAJOR | §6.3 inverted a register defect into a virtue: `driver_only` emitting no STATEMENT line is D28 finding §4.3 / register entry 16, not "having nothing to state is itself stated" | **FIXED** — §6.3 bullet rewritten to report the open defect and the "one piece of mechanisation worth building" quote |
| 2 | R2 | MAJOR | Abstract: "a number the system prints and guards" — no standing aggregator exists (D28 §2.1/§7); fold is one-shot | **FIXED** — abstract now "derived by a documented fold over classification lines the profiles print"; no-aggregator fact added to §8 and the compliance note |
| 3 | R2 | MAJOR | §8 omitted D28's mandatory successor sentence (one hook deep; 10/15 no profile; 14/15 no dynamic evidence) | **FIXED** — carried near-verbatim in §8; compliance note updated |
| 4 | R1 | MAJOR | No bug-yield evaluation: paper never reports what the system has found | **PARTIALLY ADDRESSED** — honest §7 paragraph (no cumulative ledger; promoted-regression members + retained counterexamples exist; report declines to assert an underivable number) + §8 limitation. A true yield study remains UNRESOLVED future work |
| 5 | R1 | MAJOR | Reachability ≠ oracle strength; no systematic mutation study over the 12 invariant families / 37 violation constructors | **PARTIALLY ADDRESSED** — §8 limitation added, existing mutant checks enumerated. The mutation study itself remains UNRESOLVED future work |
| 6 | R3 | MAJOR | §2.3 vocabulary dump — hooks/ABI/kit terms unillustrated | **FIXED** — worked examples for `on_pre_step`/`on_response_intercept`; Figure 1 referenced in-line; paragraph split |
| 7 | R3 | MAJOR | §6.3's headline numbers stacked in prose; deserves a table | **FIXED** — Table 4 (vacuity register breakdown per profile) |
| 8 | R1 | MINOR | §2.1 mischaracterized FDB fault injection (elided Buggify); divergence undefended | **FIXED** — §2.1 corrected; modeled-outcomes-vs-Buggify divergence defended in §5.2 |
| 9 | R1 | MINOR | Replay normalization rules unstated; residual nondeterminism risk unaddressed | **PARTIALLY ADDRESSED** — §5.2 states per-record normalization + member-for-member census comparison + every-sweep enforcement; full enumeration deferred, noted in §8 |
| 10 | R1 | MINOR | Criterion 1/2, clause 3, "D1 port", "producer vacuity" undefined for external readers | **FIXED** — criteria defined at first use in §6.3; producer vacuity explained in §6.2; "D1 port" tied to §5.2's world protocol |
| 11 | R2 | MINOR | §5.2 "nine required classes" vs 11-row Table 3; "every … routes through the world clock" vs 7/6/1 | **FIXED** — "eleven classes, nine required-and-reached, two waived"; "all but one routed, the one declared and instrumented"; Table 3 caption now states the finding |
| 12 | R2 | MINOR | §3.3 sole-emitter claim overbroad given registration gap; "deliberately empty" retrojection; novelty claims uncited | **FIXED** — §3.3 scoped to the driven session with explicit registration exception; "deliberately" dropped; novelty hedged ("to our knowledge", "we are aware of no comparable published treatment") |
| 13 | R3 | MINOR | §6.2 row discussion far from Appendix A | **FIXED** — "(Appendix A, row N)" pointers added |
| 14 | R3 | MINOR | Abstract term-density | **PARTIALLY ADDRESSED** — "prints and guards" fix simplified the tail; full density trim not performed (the remaining terms are each load-bearing). May revisit |
| 15 | R3 | MINOR | §4.2/App B duplicated listing unexplained | **FIXED** — App B notes the repetition |

## Unresolved (persisting per anti-inflation rule — at least one must)

1. **Bug-yield evaluation** (#4): now disclosed as a limitation; an actual yield study (mine
   the git/issue record for DST-caught regressions, or run the nightly search against known
   past defects) is future work.
2. **Oracle-strength mutation study** (#5): disclosed as a limitation; the study itself
   (seed known-bad compactions/pairings, record which invariant families trip) is future work.
3. **Abstract density** (#14): partially addressed only.

## Regression-check list for round 2

Re-verify on any re-review: #1 (defect reported as defect, not virtue), #2 (no
"prints/guards" language anywhere), #3 (mandatory sentence present in §8), #11 (9-vs-11
consistency), #12 (sole-emitter scope qualifier intact).
