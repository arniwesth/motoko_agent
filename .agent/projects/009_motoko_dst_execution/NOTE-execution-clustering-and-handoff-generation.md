# Note: how Milestone A is clustered into sessions, and how to generate the next handoff

Date: 2026-08-02. Status: active execution map.
Companion discipline: `.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`.
Source of truth for *what* to build: `PLAN-implementation-deterministic-test-world.md`. This note is
only about *how the work is cut into sessions*.

It exists so a session that picks this up cold can generate the next handoff without re-deriving the
clustering argument.

## The question this answers

Milestone A is 24 work items and six-plus weeks. Two obvious approaches were considered and both
rejected:

- **One session for all of Milestone A.** Rejected: implementation is source-heavy work, and each
  landed item invalidates the file:line anchors the next one cites. A session running A1→A15 would
  spend its back half building on line numbers it had itself moved — the defect class
  `re-ground-inherited-anchors-before-building.md` exists to prevent.
- **One handoff per work item (23 of them).** Rejected: the plan already carries each item's
  dependencies, contents, and acceptance evidence, so per-item handoffs would mostly restate it.
  This project's measured pathology is documentation growing faster than code (78% of ADR-001 was
  review commentary across 24 commits that changed no source). A handoff's genuine value-add is
  narrow — current grounding, traps, scope fence, green state — and that is a page.

**The cut that works is by shared source surface**: a cluster is a set of items that touch the same
files and can end in one green state.

**Cluster 13 sharpened this into the sizing rule as well: grounding is paid PER SESSION, not per
piece.** WI-A14's three pieces measured 56 / 12 / 10 minutes, and piece 3 — a new module, a new
acceptance script, a new make target with three guards and thirteen mutation rows — came in at twelve
because **piece 1 had already read every input artifact piece 3 needed.** That is S6's *first* term,
paid once for the session rather than once per piece. So an item whose pieces share inputs is
markedly cheaper than the same obligations split across sessions, and **cutting by shared inputs
beats cutting by obligation** — the same shape as cluster 12's finding that A13's stage 6 was two
pieces sized as one.

## The cluster map

Dependencies are from the plan; clusters inherit them. Nothing here overrides the plan — if they
disagree, the plan wins and this note is stale.

| # | Items | Surface | Depends on | Status |
|---|---|---|---|---|
| 1 | **A1 + P6 + A2** | `ports.ail`, `stub_step.ail`, `session.ail`, `scripted_ports.ail` | — | **DONE 2026-08-02** — `e59acaa`, `4ad2c7a`, `6dd1bbe`. Report: `NOTE-cluster-1-execution-report-and-plan-corrections.md` |
| 2 | **A4 + A5 + A11** | `tools/`, Python; scans the tree, edits none of it | — | **DONE 2026-08-03** — `5ad3433`, `24ed3ea`, `08b7a75`; five ADR amendments. Report: `NOTE-cluster-2-execution-report-and-plan-corrections.md`. The classifier derived the corrected three-member set on its own |
| 3 | **A6 + A7 + A8** | new artifacts + fail-closed validators | — | **DONE 2026-08-02** — `935bd46`, `a7d70b5`, `c873002`; 264 sites, 30% judgement, 108 checks green. Report: `NOTE-cluster-3-execution-report-and-plan-corrections.md`. Found the ADR's seven-not-six dispatch undercount (C1) |
| 4 | **A16 + A9** | `Makefile`/CI, then `session.ail`, `phase_vocab.ail` | 1 (landed) | **DONE 2026-08-02** — `61f38db`, `ff8d8e5`. Report: `NOTE-cluster-4-execution-report-and-plan-corrections.md`. Spawned **WI-A17** (the `ailang test` coverage axis), unassigned to a cluster |
| 5 | **A10** | profile/manifest machinery | 2, 3 (both landed) | **DONE 2026-08-03** — `fd4f4bd`, `dafe898`. `driver_only` v1 loads and is conformant at HEAD. Report: `NOTE-cluster-5-execution-report-and-plan-corrections.md`. Both decisions resolved; added standing rule S6 |
| 6 | **A12** | driver, all effect classes; internally staged one PR per class | 1, 4 (both landed) | **DONE 2026-08-02** — `2b938e1`…`3c2f4ab`, all six classes plus the typed tool contract, ~92 min against "several days". Report: `NOTE-cluster-6-execution-report-and-plan-corrections.md` |
| 7 | **A13** | discovery/replay | 3, 4, 5, 6 (all landed) | **DONE 2026-08-03 — all six stages.** `9c4d724`, `8b0d605`, `2d752da`, `f77adf1`, `177d0cb`+`be8393c`, `6c4894e`+`e01a978`. Reports: `NOTE-cluster-7-…` through `NOTE-cluster-12-…`. `make dst` exit 0 at **466 checks**, from 0 at the item's start. **A14 and A15 unblocked** |
| 8 | **A14** | invariants, latency pair, D11 reporting | 7 (landed) | **DONE 2026-08-04** — `00dbdb4`, `ea81e66`, `3dd8a82`. Report: `NOTE-cluster-13-…`. 78 min on the clock, split 56/12/10 across three pieces. `DoneEvent` resolved; the coordinate anchor decided *not to build* |
| 9 | **A15** | the two corpora and their CI jobs | 8 (landed) | **DONE 2026-08-04** — `ff54c0f`, `ee4311c`. Report: `NOTE-cluster-14-…`. 58 min on the clock, split 43/16. `make dst` exit 0 at **700 checks**. The `max_resource_size` bump was **NOT** taken: deferred as a one-draw item with the reasoning recorded, because a version bump serializes in front of the corpus sweep rather than sharing work with it |
| **10** | **A17** | `Makefile`/CI; the `ailang test` coverage axis | — | **DONE 2026-08-04 — AND WITH IT, MILESTONE A.** Report: `NOTE-cluster-15-…`, `26f2a4d`. 54 min on the clock against "under a day". The handoff's measured gap was itself short by a file, and low on two more, because its grep sees neither `test "..."` blocks nor `requires`-derived properties: **39 files, 370 tests**, now all run by `make test_coverage`, which walks `src/core` recursively rather than naming files. Found **ten tests that were skipped and green**, in three classes, two of them upstream limitations. Sites 32–34 |

**Clusters 1, 2 and 3 are mutually independent and can run in parallel** across sessions or agents.
Cluster 2 in particular is anchor-independent of the driver work — it inventories source rather than
editing it — which is why its handoff is safe to write before cluster 1 lands.

**The critical path is 1 → 6 → 7 → 8 → 9** (A1 → A2 → A12 → A13 → A14 → A15). Clusters 2–5 feed it
but do not lengthen it. A13 and B2 are the two 1–2 week items and dominate the schedule.

**MILESTONE A COMPLETED 2026-08-04 with A17 (cluster 10).** All ten rows are DONE and all seventeen
work items are closed — sixteen through these clusters, plus **WI-A3, which has no row here and never
needed one**: it is "file the two upstream reports", done 2026-08-02 with the plan itself, with no
source surface. Cluster 15 checked that by reading the rows and running down the one item they do not
carry, which is the discipline the paragraph below asks for.

**The critical path completed 2026-08-04 with A15. MILESTONE A DID NOT.** Cluster 10 (A17) was the
remaining item and it is off the critical path, which is exactly why it was missed: **A17 was
SPAWNED by cluster 4 rather than planned, and a spawned item does not acquire a cluster.** Three
successive handoffs and the plan itself carried "A15 is the last item in Milestone A" while this
table's own last row said A17 was unassigned. **The completion sentence did not read the cluster
map.** If another item is ever spawned mid-milestone, give it a cluster number in this table on the
day it is spawned — an unnumbered row is invisible to every reader who is looking for what is left.

## The rule that governs handoff *timing*

**Write the handoff for the next cluster you can ground honestly, and no further.**

Handoffs for clusters 4, 6, 7 and 8 must not be written yet. They would cite anchors into
`ports.ail`, `stub_step.ail` and `session.ail` that cluster 1 is about to move, so writing them now
guarantees the staleness the whole discipline exists to prevent. Clusters 2 and 3 are the exception
and may be written at any time.

The corollary is that this note is **not** a licence to batch-generate the remaining handoffs.
Generate one when its cluster becomes groundable.

**Cluster 4 is the evidence this rule is worth its cost.** Its handoff was written after cluster 1
landed, and re-grounding found that *every* WI-A9 anchor had moved: `emit_run_summary` 833→858, all
five of its call sites shifted, `finish_reason_str` 820→845. A handoff written before cluster 1
would have shipped five wrong line numbers into the session least able to notice — one working in a
file it had never read.

## Generating the next handoff

Use `HANDOFF-execute-a1-a2-port-widenings.md` as the template. Do not restate the plan; carry the
four things it cannot:

1. **Current grounding** — a table of the anchors the cluster will touch, re-verified at HEAD, gated
   behind `git diff --stat <last-known-good>..HEAD -- src packages scripts` with the instruction to
   re-measure everything if it is non-empty.

   **A recommendation inherited from a prior cluster is a claim, and stage 5 found one that
   contradicted the same handoff's own prohibition.** Cluster 10 recommended attaching D8's canary to
   `check_seed_sensitivity`'s `versioned` row; the stage-5 handoff repeated it verbatim without
   testing it. It was wrong, and wrong *by the handoff's own argument two paragraphs earlier*: the
   `versioned` row is a **real driver run**, so a canary attached to it goes red whenever the driver's
   control flow moves or a request-projection string is edited — and a driver change is not a seed
   remap. **A canary that cries wolf acquires a regeneration target**, which is precisely what that
   handoff forbade in bold. The prohibition would have failed not because anyone disagreed with it but
   because the artifact made itself unusable. The executing session attached the canary to nothing —
   it consults no driver at all, calling the choice functions directly under constant salts.

   **The general form: when a handoff carries a recommendation forward, check it against the
   handoff's own constraints before repeating it.** A prior cluster's advice was written before the
   constraint existed; inheriting it unexamined is how a document ends up arguing with itself.

   **A stage boundary is a claim too, and stage 4's grounding found one wrong.** WI-A13's five-stage
   split described stage 2 as "discovery — record what the driver requests"; D2's discovery is a
   generator that **chooses** plus a world that **records**, and the choosing half was in no stage.
   It survived three stages because the program carries `generator_id`, `generator_version` and
   `seed` as validated non-blank fields, so hand-authored scenarios writing `seed: 0` looked
   complete. **When a stage's name paraphrases a specification, check the paraphrase against the
   specification's own words** — "record what the driver requests" and "seed-driven discovery" are
   not the same sentence, and only one of them is D2.

   **A count in an upstream doc is a claim, not a warrant — and cluster 3 found the ADR wrong by
   one.** D5 said six of eight hook slots are unconditionally dispatched and named one as gated;
   six plus one is seven, and the eighth went unnamed. The missing slot was unconditional and lived
   in a file the ADR's survey never opened. **When a handoff carries a count from an upstream
   document, check it sums** — and note where the source looked, because a survey scoped to one file
   will miss a dispatch in another. The same session's C7 is the mirror image: an "obvious" recount
   of goldens by `grep` returned the wrong number because the first entry lacked a leading `&&`. Both
   directions are cheap to check and expensive to inherit.

   **The anchor table is itself a source of defects, and cluster 6 proved it.** The A12 handoff's
   table named *three* dispatch carry sites; there are **six**, and **cluster 1's report had said six
   all along** — the handoff lost three in transcription from the report it was built on. It changed
   nothing only because the class turned out to be a uniform rename; a session hand-threading from
   that list would have frozen three sites, which is precisely the defect cluster 1 filed,
   reintroduced by the artifact meant to prevent it. **Derive every count in the table from a command
   you run while writing it, paste the command, and never carry a number across from prose** —
   including prose you wrote yourself.
2. **The rule the session will break by accident** — every cluster has one. Cluster 1's is that A1
   and A2 are two commits because one is behaviour-preserving and the other is not. Find the
   equivalent before writing: it is usually a distinction the plan states once and a builder would
   naturally collapse.
3. **Definition of done, per commit**, with a runnable check and — where a defect is being fixed —
   the current failing output verbatim, so a real regression is distinguishable from the
   pre-existing state.
4. **Scope fence and traps.** What the cluster must *not* do (usually: the next cluster's work), plus
   the standing traps below.

Also carry, every time: **stop-and-report triggers** rather than inline judgement calls. Cluster 1's
is P2's reopening condition. Anything the plan names as a decision belongs to the plan, not to the
building session.

## Verify the aggregate gate by its EXIT STATUS, not by a selection of targets

**`make dst` was red for two clusters and nobody noticed, including the sessions that verified each
cluster's work.** A12 (cluster 6) added a randomness guard that greps for `std/rand`; A10 (cluster 5)
landed on top of it with a profile field whose *prose named the thing the guard forbids*. The artifact
documenting the guard tripped the guard. `make world_state` exited 1, `make dst` exited 2, and under
`--keep-going` that was one red line among 233 green ones.

Two habits follow, and both are corrections to how this project has been verifying:

1. **Run the aggregate and read `$?`.** Not a scan of its output, not a selection of the targets a
   cluster happened to touch. Every cluster verification up to this point ran individual targets —
   which is exactly why a break introduced by one cluster and invisible to the next survived two.
2. **Anchor every grep-based guard to a syntactic form.** A guard matching a bare token will
   eventually fire on the artifact documenting it, because these items are *required* to write prose
   naming what they forbid. Cluster 8 audited all nine: seven were already anchored, one was fixed
   (`terminal_trace`'s `{ result:` counted comment lines, so `session.ail` carried a standing
   obligation to circumlocute around its own guard), one — `fault_catalogue`'s physical-fault
   tripwire — is *correctly* prose-based because it watches intent rather than syntax, at the cost of
   an exclusion list that grows with every artifact documenting the exclusion.

## What to ask back, every cluster

**Ask for the git wall-clock window, not a felt ratio — cluster 12 measured both for all six A13
stages and they disagree by two to three times.** Reading handoff-commit → last `feat`-commit off git
gave 34/43/35/60/36/41 minutes, against contemporaneous reports of ~3×, ~1×, ~1.5×, ~0.9×. Stage 2's
"~3×" is **1.26×** on the clock. The two agree closely only for stage 4, whose cost was dominated by
*running* things — sweeps and re-pins — rather than deciding them. **Where a stage's cost is
deliberation, the felt ratio over-reports it**, because forty minutes on three hard decisions feels
like three times thirty-four minutes on one. Request the window, which is checkable; a felt ratio may
sit beside it, labelled as such.

Each handoff should also request actual time, **sites touched** and the
**judgement-versus-mechanical ratio**. Cluster 1 established why all three matter and corrected the
model: file-count sizing was wrong by two orders of magnitude, **sites** is the right driver for
widen-and-converge work, and the judgement ratio for contract-changing work is **~19%**, not M1's
10%. Neither correction reaches new-artifact work (A13, A14, A15, B2), whose estimates remain
unmeasured.

**Ask for the judgement ratio split when an item ships both machinery and an instance** (cluster 5).
A10 came in at 34% combined against a predicted ~16%, and the split explains it entirely: the
machinery half was **14%** — below A6's 16%, exactly as predicted — while the `driver_only` half was
**95%**, because *which* adapter boundaries and resource models a profile has is a fact about the
driver, not about D5. No amendment could have reduced it. A combined number reads as "the
specification was vague" when the truth is "half of this item was content, and content is never in
the specification."

Ask also for the *kind* of judgement, not only the count. This has now paid twice, and it is the
single highest-value question in the report-back:

- **Cluster 1**: two of nine judgement sites admitted two type-checking answers with a silent wrong
  one — wrong successor literals that froze a cursor. That finding added A12's advancement-assertion
  requirement.
- **Cluster 4**: four of ten, and *worse in kind* — trace arguments where the wrong value yields a
  trace that **still passes its own invariant**. That finding forced A12's assertion to cover trace
  completeness, not just cursor advancement.

A count alone would have hidden both. **Ask what could have been wrong silently, and what caught
it** — in cluster 4's case, one of the four was caught only by reading emitted JSONL, because
`smoke_parity` diffs a build against itself and a consistent reordering is consistent.

**Write acceptance clauses that must be *demonstrated*, not asserted.** Cluster 4's C1 is the
evidence: "verified by breaking one deliberately" could not be satisfied, because four of the eight
scripts exited 0 on a failed assertion. An assertable clause would have shipped the illusion of
coverage.

Plan defects found while building get filed as plan corrections. Never silently reconciled: executing
finds what reading does not, and that is the point of building cluster 1 first.

## Standing traps for any execution session

Clear `.ailang/cache` before believing a contradicting type error; the compiler reports one
record-field mismatch at a time, so write the fix-loop tooling before the edits; never probe from
`/tmp` (`MOD010` auto-relaxes); PR #103 must not be merged; the spike branch is not HEAD state; pin
is v0.26.0, Makefile-guarded.

## What invalidates this note

- The plan changing its dependency graph — the plan is authoritative, this map is derived.
- ~~Cluster 1 landing~~ — **landed 2026-08-02. Clusters 4 and 6 are now groundable and their handoffs
  writable.** Both must re-ground first: cluster 1 moved `ScriptedStep` to `ports.ail`, widened
  `Ports.model_step` in both directions, removed `Ports.hooks_runtime`, and added
  `C2LoopState.provider_state`, so every anchor into those three files has shifted.

**One correction this map owed and now carries (C3).** Cluster 1's row said "A1 + A2". P6 is a plan
*decision* rather than a work item, so it appeared in no row, yet the plan sequences it into A1's
edit wave because both touch every construction site. A session working from this map alone would
have skipped it and a later one would have paid a third full pass. **When generating a handoff, sweep
the plan's decisions for ones that name an edit wave, not just its work items.**
- Any cluster proving to be the wrong cut. That is expected for the later ones: the clustering past
  cluster 5 is reasoned rather than measured, and the first two or three executions are what turn it
  into something known.
