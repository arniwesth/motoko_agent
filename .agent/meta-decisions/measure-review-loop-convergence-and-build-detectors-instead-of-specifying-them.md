# Meta-decision: measure movement, not comfort

*A review loop is a control system; a detector must be built, not specified; and the metric that feels
like proof is rarely the one that discriminates.*

Date: 2026-08-02
Status: Standing discipline
Scope: any session running iterative adversarial review over a durable doc (ADR, plan, spec); any
session writing a decision doc that names a gate, detector, classifier, or validator; and any session
choosing which assertion guards a migration.

Amended 2026-08-02 with rule 3, after WI-A12's execution confirmed the same shape one layer down —
see `.agent/projects/009_motoko_dst_execution/NOTE-cluster-6-execution-report-and-plan-corrections.md`.

## The principle

Three rules, all learned the expensive way on project 009. They are the same rule at three scales:
**prefer the measurement that detects movement over the one that feels like proof.**

**1. An adversarial review loop can diverge, and nobody notices unless someone counts.** Each round
feels productive — the reviews are sharp, the findings are real, the corrections land. But if each
correction pass introduces defects at roughly the rate the reviews retire them, the loop has no fixed
point and will run forever. **Count findings per round. If the count is not falling, the loop is not
converging, and more rounds will not fix it.**

**2. You cannot specify a detector to buildability in prose.** A gate that scans, classifies, or
validates is only sound if it runs. Prose review will correctly find each specification unsound, the
next pass will specify harder, and the cycle repeats indefinitely. **Build the smallest working
version instead. The specification questions dissolve on contact with the artifact.**

**3. The metric that feels most like proof is rarely the one that discriminates.** Reproducibility,
type-checking, and "the round found real defects" all feel like correctness. They are true statements
that rule almost nothing out. **Pair every such metric with one that measures *movement* — did the
cursor advance, did the count fall, did the value change — because that is the one that fails when
something is wrong.**

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

## The second instance, one layer down: WI-A12's three assertion axes

Rule 3 was added after the ADR's own migration was executed, because the same shape appeared in code.
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

**When choosing what guards a migration:**

5. **Never let reproducibility be the only axis.** Pair it with an assertion that something *moved* —
   a cursor advanced, a queue drained, a value differs from its predecessor. Reproducibility is the
   axis that feels most like a proof of correctness and it is the weakest of the three measured on 009.
6. **Land the movement assertion first, before the migration it guards.** Confirmed four times in one
   run and three times across runs. A defect that is reproducible and trace-complete is invisible to
   everything else.
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

## Honest note on authorship

The correcting side of the 009 loop — me — was a major contributor to the divergence, not a neutral
scribe. Passes introduced defects at roughly the rate reviews retired them, and the author's own
next-round handoffs caught defects in the author's own work **five rounds running**. That last fact is
the sharpest available signal: if scoping the next review reliably finds defects in the pass you just
committed, the pass was under-verified before it was committed. The fix is fewer, slower, probe-backed
changes — not more rounds.
