# Note: what the ADR-001 review loop cost, and where it actually stands

Date: 2026-08-02
Status: Retrospective, written at commit `d439c2d` (ninth correction pass)
Companion: `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`

This note exists so a future session does not restart the loop without knowing what it is joining.
The generalisable lessons are in the meta-decision; this is the project-specific record and the
recommendation for what to do next.

## Where the ADR actually stands

**The architecture is settled and has been for most of the loop.** D1–D11 — the driver-owned
state-threaded world, seed-driven discovery with resolved-program replay, logical faults as modeled
outcomes, one virtual clock, the real traced driver under a named profile, one terminal trace,
whole-execution invariants, program-not-seed replay, sequential-until-contract-changes, the naming
gate, and search-as-a-gate — have been re-derived and confirmed by every round since the F1–F6
verifications. **No review in the last eight rounds has reopened them.**

What has churned is a layer below the architecture: the gate *mechanisms*. Classifier 1 (the
ambient-effect module inventory), classifier 2 (the `ExtPorts` typed-call inventory), the site-to-hook
attribution table, and the coverage floor. Those are implementation-plan concerns that were being
specified to buildability in an ADR, which is why they never settled.

## The measurements

At `d439c2d`, over 2026-07-26 → 2026-08-02:

- Nineteen `## Review Comments` sections, **154 findings**
- Nine correction passes, 24 commits
- **78% of the file is review commentary** — 7,640 review lines against 2,127 body lines
- **Zero source changed**: `git diff --stat 99749c7d..HEAD -- src packages scripts Makefile .github`
  is empty
- 42 self-correction markers in the body ("an earlier revision…", "was false", "is retracted")

Findings per delta-review round: **15, 12, 16, 16, 17, 19, 20.** Rising since round two. The loop was
diverging for six rounds before anyone counted.

## What is genuinely blocked, and by what

**External, untouchable from here, and the real critical path:** the upstream recorded-stream API
(`sunholo-data/ailang#546`) must land in a *released* AILANG, this repo must repin to it, and D1's
positive integration probe must pass. It is parked upstream with the design agreed and the
`{chunks, outcome}` shape settled. Nine correction passes and nineteen reviews moved it exactly zero.
The fork's `stepWithStreamRecorded` on the `v0.31.0` tag is a prototype and clears none of the three
conditions.

**Internal, and self-regenerating:** "this correction pass has not been independently verified." Every
pass ends in that state by construction. It is not a blocker being worked down; it is a fixed point.
Treating it as equivalent to the external blocker is what made the ADR un-acceptable in principle.

## What repeatedly failed, in this document specifically

- **Classifier 1** — four revisions, each found fail-open on a new declaration form, glob gap, or
  field semantics. Current state: union of the builtin projection and a stdlib source scan, with
  `ailang iface` as preferred parsed input and four named repairs. Unverified.
- **Classifier 2's matcher** — three revisions: reachability → textual reference → typed call site.
  The textual version selected five packages including both guards the ADR names as its first interim
  profile.
- **The attribution table** — three revisions: intention → D6-style artifact → source-global with a
  profile-held reference. Its correctness condition (necessity) is still manual-only.
- **The coverage floor** — three dispositions: floor → disclosure-only → floor plus validated
  carve-out. Ended approximately where it began, having proven along the way that the intermediate
  deletion rested on a false premise.
- **Anchors** — errors in five consecutive passes, then three clean.

Every one of those corrections was justified by the finding that prompted it. The problem was never
any single pass; it was that the artifact could not answer the question being asked of it.

## Recommendation for the next session

**Do not run a tenth round as-is.** It will find roughly twenty more findings, all real, and the
document will be worse.

In preference order:

1. **Build classifier 1.** It is ~40 lines of Python over `ailang iface --json` across the pinned
   stdlib plus `ailang builtins list -json`, reconciled against the repo's actual `std/*` imports.
   Running it settles four rounds of argument and produces a checkable artifact. The known traps are
   already documented in D5 obligation 2: use `effects` and ignore `pure`; absolute-path invocation;
   scan-root-relative module ids; handle `std/secret`'s `MOD010` failure; and **do not run it from a
   temp directory**, where AILANG auto-relaxes `MOD010` and the failure disappears.
2. **Accept the ADR with the gate mechanisms explicitly deferred.** Mark classifiers 1 and 2, the
   attribution table, and the coverage floor as implementation-plan obligations behind a named
   acceptance gate. The ADR's job — the effect boundary, the world protocol, the profile contract — has
   held under nineteen reviews.
3. **If another review round happens, scope it to the architecture only**, and say so in the handoff.
   "Is every mechanism buildable" is a question for whoever builds them.
4. **Track the external blocker separately from ADR work.** It is the only thing on the acceptance
   critical path that this project can neither fix nor route around.

## What was actually good here

Worth recording so the retrospective is not read as an argument against review:

- The **paired independent reviewers** caught things a single reviewer did not, repeatedly, and
  disagreed productively twice — including one case where the disagreement itself was the finding
  (the `ailang iface` temp-directory auto-relax).
- **Committing reviews verbatim before any response** made every subsequent round diffable and
  eliminated a whole class of provenance findings after it was adopted.
- The **author-adjudicates / reviewer-verifies** split held. It is not what failed.
- The reviews found **real defects every single round**, including several the author introduced. Review
  quality was never the problem.
