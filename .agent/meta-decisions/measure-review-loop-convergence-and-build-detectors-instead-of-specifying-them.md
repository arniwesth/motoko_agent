# Meta-decision: measure movement, not comfort

*A review loop is a control system; a detector must be built, not specified; and an assertion that
tests only one direction is blind in the other.*

Date: 2026-08-02
Status: Standing discipline
Scope: any session running iterative adversarial review over a durable doc (ADR, plan, spec); any
session writing a decision doc that names a gate, detector, classifier, or validator; and any session
choosing which assertion guards a migration.

Amended 2026-08-02 with rule 3, after WI-A12's execution confirmed the same shape one layer down, and
sharpened 2026-08-03 after WI-A13 produced its mirror image. See
`NOTE-cluster-6-execution-report-and-plan-corrections.md` and
`NOTE-cluster-7-execution-report-and-plan-corrections.md` under
`.agent/projects/009_motoko_dst_execution/`.

## The principle

Three rules, all learned the expensive way on project 009. They are the same rule at three scales:
**a measurement that can only come out one way is not a measurement.** A findings count that only
ever rises, a specification that only ever gets more precise, an assertion that only tests one
direction — each feels like evidence and none of them can fail informatively.

**1. An adversarial review loop can diverge, and nobody notices unless someone counts.** Each round
feels productive — the reviews are sharp, the findings are real, the corrections land. But if each
correction pass introduces defects at roughly the rate the reviews retire them, the loop has no fixed
point and will run forever. **Count findings per round. If the count is not falling, the loop is not
converging, and more rounds will not fix it.**

**2. You cannot specify a detector to buildability in prose.** A gate that scans, classifies, or
validates is only sound if it runs. Prose review will correctly find each specification unsound, the
next pass will specify harder, and the cycle repeats indefinitely. **Build the smallest working
version instead. The specification questions dissolve on contact with the artifact.**

**3. A one-sided assertion set cannot see failures in the other direction.** Reproducibility,
type-checking, mutation coverage, and "the round found real defects" all feel like correctness. Each
tests one direction and is silent in the other: determinism tests *sameness*, so it cannot see that
nothing moved; mutation tests *rejection*, so it cannot see that something valid was also rejected.
**For every assertion, name the direction it tests and add its opposite** — pair sameness with
movement, pair rejection with survival. The pairing is what discriminates; either half alone is a
true statement that rules almost nothing out.

## The instance that motivates it

Project 009's `ADR-001-deterministic-test-world-architecture.md`, 2026-07-26 → 2026-08-02: two full
reviews, three verifications, and **eight rounds of paired delta review** — nineteen review sections,
**154 findings**, nine correction passes, 24 commits.

Measured at the end:

| Delta-review round | Findings |
|---|---|
| 2nd correction pass | 15 |
| 3rd | 12 |
| 4th | 16 |
| 5th | 16 |
| 6th | 17 |
| 7th | 19 |
| 8th | 20 |

**Findings bottomed out at round two and rose monotonically thereafter.** Nobody noticed for six
rounds, because every individual round looked like progress: real defects found, real corrections
made, a clean commit. The trend was only visible by counting.

Two other measurements from the same document:

- **78% of the file was review commentary** — 7,640 lines of review against 2,127 lines of body.
- **Zero source changed.** `git diff --stat 99749c7d..HEAD -- src packages scripts Makefile .github`
  was empty across all 24 commits. Nine correction passes moved no code.

## Why it diverged: four sub-patterns

### Specifying detectors without building them

The rewrite counts tell the story. **Classifier 1 (an ambient-effect module scan): four revisions,
each found fail-open by the next review.** Classifier 2's matcher: three. The site-to-hook attribution
table: three. The coverage floor: three dispositions, ending approximately where it started.

Each round the ADR specified more precisely; each round a reviewer ran a probe and found the
specification unsound in a new way — a declaration form the pattern missed, an effect variable
counted as an effect, a glob that missed a subdirectory, a field whose value contradicts its sibling.
Every one of those findings was correct. None of them was findable by writing more prose, and all of
them would have surfaced in an hour of writing the scanner.

**The tell:** a mechanism whose specification has been rewritten twice and is still being found
unsound is not under-specified. It is in the wrong artifact.

### Propagation failure

Fix a claim in one place; miss the two-to-four other places it is load-bearing. This occurred in
nearly every pass, and twice the pass *asserted* successful propagation in the same edit that failed
to propagate ("stated once" — false at two sites; "six sites, same words" — false at three, one of
which stated the retired rule normatively).

This is not carelessness. It is what happens when a document grows to where one idea lives at six
sites. The growth causes the defect class.

### Unverified generalization

Three times, a pass asserted a property of a category without checking the artifact:

- "no behaviour-carrying extension hook is coverable" — false; three ABI slots carry no effect row
- "the only two `ai_step` references" — counted *calls*, wrote *references*, then built a rule on the
  word rather than the count, and the rule selected five packages including the two the ADR depended on
- "a rowless hook cannot reach `ai_step`, by type" — the probe tested a direct builtin call, which
  *is* caught; the field-mediated call, which is the only shape that matters, is not

Each was caught by a reviewer building the probe the author should have built. **The pattern: the
author probes the case they already believe, and generalises from it.**

### Self-referential claims

Counts of the document's own review sections, claims about how many sites state a rule, claims about
how many prior rounds spent findings on anchors. These go stale the instant the document is edited,
and were wrong repeatedly — including once where the correcting pass applied a count correction
relative to the commit being *answered* rather than the commit being *written*, immediately after a
review action said in as many words not to do that.

**A document should avoid asserting facts about itself that an edit invalidates.** Where it must,
state the derivation (`sections − 5`) rather than the result, and assign the check to a tool.

## Two instances one layer down, in code

Rule 3 was added after the ADR's own migration was executed, because the same shape appeared in code —
then confirmed again, rotated, on the next work item. The two together are what give the rule its
final form.

### WI-A12: sameness without movement

WI-A12 threaded world state through the driver across six effect classes — 119 sites — guarded by
three assertion axes: **determinism** (same seed twice → identical output), **trace completeness**,
and **advancement** (did the cursor actually move).

Four defects were caught before they shipped. **Determinism caught none of them.**

| Defect | Type-checks | Determinism | Caught by |
|---|---|---|---|
| Initial world read off `provider` instead of `started.next_state` | clean | **green** | advancement (`duration_ms: -1`) |
| Approval state carried forward instead of `input.next_state` | clean | **green** | advancement |
| One env read reverted to ambient `getEnvOr` | clean | **green** | provenance |
| Batch recursion passed `world` instead of `executed.next_state` | clean | **green** | 3 of 4 contract assertions |

The first is the instructive one: reading the initial world off `provider` is **the more natural thing
to write** — the constructor already receives `provider`, so it needs no new parameter. It is
type-clean, trace-complete, and *perfectly reproducible*. It freezes the world, and the only signal is
that a duration came back negative.

The env case shows why: **an un-routed ambient read is also perfectly reproducible** when the variable
is unset in both runs. Determinism cannot distinguish "correctly isolated" from "identically broken."

This is rule 1 at a different scale. "Same seed twice → identical output" is to a migration what "this
round found real defects" is to a review loop: a true statement, satisfying to produce, that
discriminates almost nothing. D7 asks for the determinism invariant explicitly, so it will keep being
reached for — it is necessary and it is not sufficient.

### WI-A13: rejection without survival

The next item built a **validator** for the execution-program artifact, with a mutation suite: one
valid base program and 18 mutant rows, each expected to be rejected. The specification clause it
implements admits two readings — reject a repeated *encounter ordinal*, or reject a repeated
*identity body* — and the second is both the more obvious reading and wrong, because it makes a
production retry (same tool, same call id, second attempt) undecodable.

**The wrong reading passes all 18 mutants.** Every mutant still produces its own rejection, so the
suite is fully green. It is deterministic and trace-complete. It shows up only as a *valid* program
being rejected — and a suite made entirely of fixtures that must fail never presents one.

What caught it was the **negative control**, and only because the base fixture deliberately contains
two interactions carrying a byte-identical tool identity at different ordinals. Remove that one row
and the negative control passes under both readings.

The generalisation: **a validator's failure mode is not "it did nothing" but "it did too much", and
only a fixture that must SURVIVE can see that.** Mutation testing is the rejection half; the negative
control is the survival half. A standing rule follows, and it is the discovery-side twin of "land the
movement assertion first":

> **A rejecting artifact needs a fixture that must survive, and that fixture must contain every shape
> the specification explicitly protects.**

The two instances rotate the same defect. A12's assertion set tested sameness and was blind to
frozenness; A13's tested rejection and was blind to over-rejection. Neither was under-tested — both
were **one-sidedly** tested, which is why more of the same assertion would not have helped.

## The two-blocker illusion

The ADR carried two acceptance blockers throughout. They behaved completely differently and conflating
them hid the divergence:

- **An external one** — an upstream API needing to ship in a release. Genuinely unchanged across all
  nine passes, because nothing in the loop could touch it. It was correctly identified at the start.
- **An internal one** — "this correction pass has not been independently verified."

**The internal blocker is self-regenerating by construction.** Every pass ends unverified, so every
pass requires another review, which produces findings, which requires another pass. It clears only if
some round draws zero findings — and findings were rising. This is a fixed point wearing the costume
of progress, and it is invisible if you only ever look at the current round.

## How to apply

**When running an adversarial review loop:**

1. **Keep a findings-per-round count from round one.** Falling is healthy. Flat is a warning. Rising
   means stop and change something structural — more rounds are actively making the artifact worse.
2. **Track what fraction of each round's findings are defects the previous correction introduced.**
   When that fraction approaches half, the corrections are the problem, not the artifact.
3. **Distinguish external blockers from self-regenerating internal ones** in the status block. Never
   let "unverified" count as a blocker of the same kind as a real external dependency, or the document
   can never be accepted by construction.
4. **Cap review scope explicitly.** "Does the architecture hold" and "is every mechanism buildable" are
   different questions. The second one belongs to whoever builds it.

**When choosing what guards a migration or a validator:**

5. **Name the direction each assertion tests, and add its opposite.** Reproducibility → pair with
   movement (a cursor advanced, a queue drained, a value differs). Mutation coverage → pair with
   survival (a valid artifact that must not be rejected). Reproducibility and mutation coverage are
   the two axes that feel most like proofs of correctness, and each was blind on 009.
6. **Land the opposite-direction assertion first, before the thing it guards.** Confirmed four times
   in one run and three across runs for movement. A defect that is reproducible and trace-complete is
   invisible to everything else; so is a validator that rejects too much.

   For a survival fixture this has a content requirement, not just a scheduling one: **it must contain
   every shape the specification explicitly protects.** On 009 the entire finding rested on one row —
   a retry with a repeated identity at a different ordinal — deliberately placed in the base program.
7. **Prefer the un-routed option that fails loudly over the one that fails silently.** Where a seam
   cannot yet be routed, bind it to something a poison probe turns red rather than to a frozen
   snapshot that serves a stale value forever.

**When writing a decision doc that names a gate:**

8. **Name the detector, its inputs, its soundness boundary, and its fail direction — then stop.** Do
   not iterate on its implementation in prose. If reviewers keep finding it unsound, that is the signal
   to build it, not to rewrite it.
9. **Prefer one working 40-line script to a fourth specification.** On 009, `ailang iface` over the
   pinned stdlib would have settled four rounds of classifier argument in an afternoon, and the answer
   would have been checkable rather than reviewable.
10. **When you assert a property of a category, probe the case you do *not* already believe.** The three
   false generalisations above all came from probing the confirming case.

## Related

- [[re-ground-inherited-anchors-before-building]] — the anchor-decay discipline. 009 also shipped
  anchor errors in five consecutive passes before three clean ones, which is the same failure at a
  finer grain.
- [[author-each-artifact-in-the-session-whose-assets-it-consumes]] — adjudication belongs to the
  author, verification never does. That split held up well on 009 and is not what failed; what failed
  was letting the author adjudicate the *same question* three times in three passes without ever
  building the thing that would settle it.
- `.agent/projects/009_motoko_dst_execution/NOTE-cluster-6-execution-report-and-plan-corrections.md`
  — the WI-A12 execution report, where rule 3's evidence was measured. Also the source of a sizing
  rule worth carrying: for a return-type change, **count the destructuring sites, not the conceptual
  blast radius**. One grep, ~90 seconds, and it was the only over-estimate in three calibration runs.
- `NOTE-cluster-7-execution-report-and-plan-corrections.md` — the WI-A13 execution report and rule 3's
  mirror image. Also carries a guard-design finding of the same family: **a structural guard that
  greps a bare token will eventually fire on the artifact documenting it**, because such items are
  required to write prose naming what they forbid. Anchor guards to a syntactic form. It had held an
  aggregate gate red across two clusters, hidden by `--keep-going`; report a gate's **exit status**,
  not a scan of its output.

## Honest note on authorship

The correcting side of the 009 loop — me — was a major contributor to the divergence, not a neutral
scribe. Passes introduced defects at roughly the rate reviews retired them, and the author's own
next-round handoffs caught defects in the author's own work **five rounds running**. That last fact is
the sharpest available signal: if scoping the next review reliably finds defects in the pass you just
committed, the pass was under-verified before it was committed. The fix is fewer, slower, probe-backed
changes — not more rounds.
