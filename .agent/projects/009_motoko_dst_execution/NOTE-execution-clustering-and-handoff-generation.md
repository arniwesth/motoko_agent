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

**MILESTONE B IS OPEN.** The upstream gate cleared 2026-08-04 (v0.33.0 ships
`stepWithStreamRecorded`, verified against the tag). **Cluster 11 = WI-B1: DONE 2026-08-04**, 33m25s — pin at v0.33.0, zero effect-row failures
reachable, tree 130/105. Report: `NOTE-b1-execution-report-and-plan-corrections.md`; earned standing
rule **S9**. **Cluster 12 = WI-B3: DONE 2026-08-04**, 48m40s — zero `images` failures, tree 161/74, earned
standing rule **S10**. **Cluster 13 = WI-B2a: DONE 2026-08-04**, 2h13m — ABI answer two rows not four, `check_core`
GREEN, tree 218/17 above the v0.26.0 baseline; rewrote **S9** and earned **S11**.
**Cluster 14 = WI-B2b: DONE 2026-08-04**, ~2h05m — opaque `ExtWorld` token, `ai_step` left the
classifier-2 set, `check_core` green at 52; earned **S12** and S11's second clause.
**Cluster 15 = WI-B4: DONE 2026-08-04 — MILESTONE B COMPLETE.** ~2h05m; sweep 219/17,
`check_core` green, `driver_only` v4, `compaction_ai` stays omitted and the empty install list is
proved *forced*. Earned **S13** and refuted B2a's closed-row argument for function-typed parameters.
Handoff: `HANDOFF-execute-b4-close-the-repin-wave.md` — the wave's
green gate and the last of Milestone B. Original B2b handoff:
`HANDOFF-execute-b2b-world-token-widening.md` — the last of
Milestone B's content, and the change that is *supposed* to move classifier 2's pinned membership.
**MILESTONE C IS OPEN. Cluster 16 = WI-C1 + WI-C2: DONE 2026-08-05**, ~57 min — `c0fbf10`,
`12577c2`, report `NOTE-c1-c2-execution-report-and-plan-corrections.md`. Handoff:
`HANDOFF-execute-c1-c2-recorded-stream-adoption.md`. D1's five clauses answered in **23 rows across
two subjects and two outcomes**, against a pinned release for the first time; `driver_only` v4 → v5;
earned **S14** and **S15**.

**The two items were clustered on a measurement, and the measurement was the right one.** C1's edit is
two lines plus an import, and with it applied `ailang check`, `make check_core` (52/52) and
`make driver_only` (exit 0) are byte-identical to their values without it — C1 alone is a commit that
provably certifies nothing. **Execution then made the case stronger than the prediction:** the natural
wrong adoption is green under all three of those gates *and* under **every substrate row of C2's own
probe**, going red only on C2's *adoption* rows in partial-stream-then-error. So C1 shipped alone would
not merely have been unverified — it would have been unverifiable by the probe D1's own wording most
naturally describes. **The generalised rule is S14.**

**The clustering rule this earns, and it is narrower than "pair items with their gates":** when an
item's whole deliverable is invisible to every existing gate, it does not ship as its own cluster —
**and the gate it ships with must drive the item's own closure, not the dependency it adopts.**

**Cluster 17 = WI-C3: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-c3-streaming-trace-parity.md`. **Grounding resized the item before it started.** The
plan reads C3 as *build the parity invariant*; the invariant already exists, is already keyed on
content, and is already proven red against omission, duplication and reordering mutants. What does
not exist is a **bridge from a run to an `ExecutionUnderTest`** — measured at HEAD, that type has
**exactly one construction site in the tree**, a hand-authored fixture in `invariants_dst.ail`, and no
seeded runner imports `dst_invariants` at all. **So the whole D7 suite, not just the emission log, has
no real-run consumer.** The handoff makes the scope call explicit rather than letting a green
`make dst` settle it, because the two readings differ in whether D6.4 is discharged and C4 reads that
answer directly.

**Cluster 17 outcome: WI-C3 DONE 2026-08-05**, ~72 min, `b145eef` — **BRIDGE taken**. All sixteen D7
families now evaluate over a real run; `d64_gap_register` 14 → 13; earned **S16** and **S17**. The
resizing finding was one level deeper than the handoff predicted: `ledger_emit` never calls
`ledger_append`, so the returned trace held **zero** `StreamDelta` records — **both parity sides were
empty, and two empty sides are green.**

**Cluster 18 = WI-C5: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-c5-compose-bearing-profile.md`. **C5 is sequenced before C4**, and the plan settles it
rather than preference: Milestone A's boundary says it delivered everything the name gate needs
*except streaming parity and extension-model coverage*; C3 supplied the first, C5 owns the second, and
C4 "runs the gate; it builds no evidence."

**Grounding again resized the item before it started, and this is now the pattern for Milestone C —
three items running, three preconditions discovered at grounding rather than at planning.** C5's own
text says compose is un-installable *"until B2's world-token/coverage widening lands"*; B2 landed and
compose is still un-installable, because B4 found a **different** blocker one item later —
`on_budget_plan`'s closed ABI row `! {Env, FS}` on an unconditionally-dispatched slot that compose
binds. **A work item's stated precondition can be satisfied while the thing it gates stays blocked**,
and nothing goes red when that happens: the plan text still reads as current.

**Cluster 18 outcome: WI-C5 DONE 2026-08-05**, ~95 min, `05275ab` — clock seam routed,
`routing_violation_at` given a production call site, **D5's declared-versus-performed detector built**,
and **the install REFUSED**. Earned **S18** and sharpened S16 twice.

**Cluster 19 = WI-C4: HANDED OFF 2026-08-05**, handoff `HANDOFF-execute-c4-name-adoption-gate.md`.
**Grounding reframed this one too — four for four in Milestone C — and this time it moved the
blocker.** Since B4 the project has tracked *"can any extension be installed?"* as what stands between
`driver_only` and the name. Reading the ADR's acceptance table row by row says otherwise: the
boundary-honesty row's final clause (*"so a profile covering only ABI-pure no-op slots is visible as
such"*) **anticipates a weak profile and asks that it be visible, not strong**, so an empty install
list is arguably compliant. **The row that fails is the ORACLE row** — *all logical ledger emissions
appear in the returned trace* — against `d64_gap_register`'s **thirteen** Logical variants that do not,
all of them tool-dispatch and terminal-path events reachable in `driver_only`. C3 discharged D6.4's
named stream exception and said the general obligation was not discharged; **that sentence is what
gates the name.**

**The pattern is now stable enough to state as clustering guidance: in Milestone C, grounding has
changed the item's shape every single time, and three of four times it changed which thing was
blocking.** Budget the first twenty minutes of any C-item handoff for reading the ADR clause the item
answers to, not the plan's summary of it.

**Cluster 19 outcome: WI-C4 DONE 2026-08-05**, ~40 min, `183fbbb`. **VERDICT: NO** — seven of eleven
rows hold, two of them vacuously. Earned **S19** and found a sixth instrument certifying nothing:
`make event_vocabulary` exited 0 over a unit test that had been red since C3, because
`cmd > /dev/null && echo "✓"` in non-terminal position swallows the status under `set -e`.

---

## THE PLAN IS EXHAUSTED. Clusters from here are scheduled from C4's work list.

**C1–C5 are complete and no item after them was ever planned** — that is C4's planning defect 1, and
it is why five consecutive items tracked the extension install as the blocker while the row that
actually blocks the name had no owner. **Sequence the remaining work by acceptance row**, not by plan
order, because the plan has nothing left to order.

| Next | Rows closed | Why this position |
|---|---|---|
| **Fault reachability** (handed off) | **4 and 11** | Two rows, one producer set, no external dependency. The cheapest ratio left |
| **Close `d64_gap_register`** | **7** | The largest single blocker. Eleven `driver_only`-reachable variants; mechanical but with its own red surface |
| **A filesystem world class** | **10** | Needs a new world class so `resolve_context_limit`'s `Env` and `FS` halves route together. Routing env alone is refused on record |

**Cluster 20 = fault reachability: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-fault-reachability-rows-4-and-11.md`. **Grounding resized it for the fifth item
running, and this time the direction reversed: the work is SMALLER than recorded, not larger.** Every
recorded reason for these four gaps says `ScriptedStep` has no error channel and no latency channel;
**B2b added both fields** and five reasons across `dst_corpus` and `dst_generator` still say
otherwise. What is genuinely missing is named by none of them — **`ScriptedStep` carries no
`retryable`**, and that bool is the entire distinction between two of the four classes.

**Cluster 20 outcome: WI-D1 DONE 2026-08-05**, ~2h05m, `27951e7` — **rows 4 and 11 CLOSE**, the
corpus's unreachable register is empty, and it found a production defect on the way: `c2_loop`'s
unretried-failure branch finalized from the pre-call world, discarding the interaction that recorded
the fault. **S12's named class, instrumented for the first time, and the instrument was a fault
class.** Seven stale reasons, not the five the handoff named.

**Cluster 21 = row 7, close `d64_gap_register`: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-d2-close-the-parity-register-row-7.md`. **Grounding resized it for the seventh item
running — and this time it found the work is a shape the project has already solved twice.**
`tool_phase.ail` has **zero** references to `LedgerTrace`, and `dispatch_tool_entries` takes
`emit: (LedgerEvent) -> () ! {IO, Trace}` over a `ToolDispatchOutcome` that returns messages and world
but no event log. **That is `on_chunk` over a pre-A1 `ProviderExchange`** — WI-A1's loss channel,
second instance. The three-step move is already validated: A1 widened the channel, C1 filled it, C3
gave it a reader, and `c2_trace_wire_events` already does the appending for stream deltas.

**Cluster 21 outcome: WI-D2 DONE 2026-08-05**, ~46 min, `def464e` — **row 7 CLOSES**, the register
goes 13 → **2**, and `make ledger_parity` compares 17 variants wire-against-trace. The A1-shaped
prediction held exactly. **The handoff was wrong about `ExtToolHandled`** — reserved as needing an
installed extension, it needs neither, and was already on the wire **47 times a run** in a `make dst`
log captured three items earlier. Found only because S15 forced the survivors' reasons to be
measurements. **Anchor cascade paid ONCE** — the first item to manage it, by tensing comments before
deriving anchors.

**Cluster 22 = row 10, the filesystem world class: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-d3-filesystem-world-class-row-10.md`. **The last red row.** Grounding found most of
the design already written down: `Makefile:1392-1416` records why the env poison pair was deferred and
why routing the env half alone is refused — *"a world-supplied path to an ambient file … a green check
implying absent coverage"*, cluster 4's C1b defect. The driver's own env reads are **all routed
already**; what fails is `context_usage.resolve_context_limit`, which takes only a model, is called at
eight sites, and reads four env vars **to compute file paths it then reads**.

**Also surfaced and worth carrying: D10 has a SECOND condition nobody has mentioned in a long time** —
the name needs the acceptance table *and* project-007's taxonomy ADR accepted. **Checked: 007 is
`Accepted 2026-07-26`**, so the table is the only thing outstanding, and re-running it is its own item
after this one.

**Cluster 22 outcome: WI-D3 DONE 2026-08-05**, ~2h05m, `14ba6f9` — **row 10 CLOSES and C4's table is
GREEN, eleven of eleven.** Five two-sided poison pairs, `resolve_context_limit` threaded at eight
sites (the deferral note said six), and a filesystem POINT READ class. Its central finding extends S16
a third time: **a poison pair is silent on whether the world is read at all** — reproduced at review,
with the deterministic runs producing no capability error and failing only the provenance assertion.

**AND THE FIRST REGRESSION IN THE SERIES: `seeded_generator` and `corpus_pr` went red and were
reported rather than repaired.** One cause — routing `context_usage` put the driver's config reads
into the recorded interaction log, and `seeded_generator`'s `3 * max_interactions` bound had been
absorbing driver overhead the generator never authored. **The repair is named and measured (read the
policy instead of re-resolving; zero mismatches across four suites) and deliberately deferred to the
next item's first move.**

**Clustering consequence, and it is the first time this has applied: the next item is NOT the obvious
one.** The acceptance-table re-run is what everything has been pointing at, but it must not run first
— the deferred repair moves the env census numbers D3 just pinned, and re-running the gate on numbers
about to change would produce a verdict with a shelf life of one item. **Sequence the repair, then the
re-run.**

**Verified at review, and it is worse than the report states: `make dst` has FIVE red targets, not
two.** `smoke_parity` also went red and D3's report does not mention it — zero occurrences. ✓ rows
fall **831 → 701**, because an aborting target stops *producing* rows rather than reporting failures.
**And C4's table is not green:** `corpus_pr` aborts before printing the class-coverage rows that are
rows 4 and 11's evidence, so those rows did not fail — they went missing. Rows 7 and 10 are genuinely
green; the table was green at D2.

**Cluster 23 = WI-D4, restore the three red targets: HANDED OFF 2026-08-05**, handoff
`HANDOFF-execute-d4-restore-the-three-red-targets.md`. **Two clustering lessons, both new:**

**A regression's blast radius is not the set the item verified.** D3 ran `world_state`, `discovery`,
`strict_replay` and `compaction_dst` — all pass, all relevant, and the target that broke is covered by
none of them. **Only a full `make dst` surfaced the third.** Where an item changes a seam every run
touches, the verification set is `make dst`, not the targets whose names match the change.

**A deferred repair needs its blast radius re-measured, not inherited.** D3 named a repair and
measured it at one site. The handoff carries that measurement forward as a *condition* rather than a
result, because the item that takes it will delete four world-successor threadings — the same
population D1's production defect came from.

**Cluster 23 outcome: WI-D4 DONE 2026-08-05**, ~3h25m — **all three targets restored**, `make dst`
back to its two pre-existing reds, ✓ rows 745 → **845**, `corpus_pr`'s class rows green and printed,
`resolve_context_limit` 8 sites → **1**. Verified at review. Earned **S20**, extended S19 and S9, and
corrected this reviewer twice: `corpus_pr`'s rows were **red, not missing** (the recipe truncates on
failure), and the conflation had **three channels** where the handoff named one — the *salt*, not the
budget, was the deep one.

**Cluster 24 = WI-D5, re-run the acceptance table: HANDED OFF 2026-08-06**, handoff
`HANDOFF-execute-d5-rerun-the-acceptance-table.md`. **This is the one the project has been walking
toward**, and grounding made it smaller than expected rather than larger — the first time in
Milestones C and D that has happened.

**There is no rename cascade.** 007 grandfathers every existing `dst` identifier and says the
exception *"does not confer the new meaning"*; every target project 009 added already uses a
non-simulation working name. **D10's adoption permits the label, it does not require renaming
anything.** The public record is one document —
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`, which states the distinction in
three places.

**The item's real difficulty is a reading, not a build.** D10 adopts the label **for the axis**, gated
on **one documented baseline profile** — and `driver_only` passes two of its eleven rows *vacuously*,
because it installs nothing, which B4 proved is forced rather than chosen. **So the question is
whether a baseline covering no extension earns an axis-wide name**, and the handoff requires it
answered out loud with the zero-coverage fact stated either way.

**Cluster 24 outcome: WI-D5 DONE 2026-08-06**, ~25 min — **VERDICT YES. THE NAME IS ADOPTED** for the
generated axis, on `driver_only/10`, with the zero-extension-coverage caveat made mandatory. Thirteen
items: twelve declined, the thirteenth adopted. Earned **S21**, and its analytic result was that the
rows leaning on the empty install list are **four, not two** — row 7's `ScratchpadResult` exemption
joined them **because D2 succeeded**, leaving a residue in which one of two survivors is purchased by
that emptiness. **Closing a row can concentrate a vacuity rather than remove it.**

**Cluster 25 = WI-D6, unblock the install: HANDED OFF 2026-08-06**, handoff
`HANDOFF-execute-d6-unblock-the-install-on-budget-plan.md`. **Grounding found a route that is one ABI
row rather than an ABI major**, and C5 already measured the evidence for it: the detector's headline
is `DECLARED on_budget_plan : ! {Env, FS}` against `PERFORMED : ! {}`. Narrowing the declared row
satisfies D5 criterion 1 outright, needs no successor, and is **structurally safe** — narrowing a
record field's row is *rejected* by the compiler, so any binding that still performs more fails to
build. B4's refutation is about function-typed parameters and does not apply.

**Two sequencing facts worth carrying, both new in kind:**

**An item can falsify a caveat written the day before, and must own updating it.** D5 put "the empty
install list is **forced**" into a design document that outlives this project. D6 makes it false — the
emptiness becomes *chosen* rather than forced, which is a weaker claim, not an absent one.

**S21's first deliberate application is this item.** Unblocking the install closes none of the four
leaning rows, because `driver_only` still installs nothing by its own definition. What changes is
every reason's *content*, and S21 exists because that set grew from two to four unnoticed.

**Worth recording as clustering guidance in its own right: the seven-for-seven grounding record in
Milestones C and D is not a run of luck, it is a property of this plan.** Items were sized from the
ADR's decisions, and the ADR describes *what must be true*, not *what the tree currently does*. Every
item's real shape has come from reading HEAD. **Budget for it, and expect the resize to change the
blocker about half the time.** Original B2a handoff:
`HANDOFF-execute-b2a-abi-rows-and-cascade.md` — B2 split in two, only the row-and-cascade half
forced. Original B3 handoff: `HANDOFF-execute-b3-message-migration.md` —
**B3 before B2, because B2's scope is unmeasurable until the `images` wall clears** (B1 could see only
one of M2's three predicted ABI changes; the rest sit behind it, and absent reads identically to
unchanged). B1–B3 are one inseparable wave and **B4 is its green gate**,
so the map's usual "one cluster, one green state" rule does not hold across them — that is stated in
the handoff rather than left to be discovered.

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

   **NEVER restate commit state in a handoff — say "confirm with `git status`". Four handoffs, four
   errors, and the file count was right every single time.** B1's handoff was wrong about B1, B3's
   about B3, B2a's about B3, and B2b's about B2a — the last one *in a paragraph explicitly warning
   about this mistake*, quoting the previous report as "stating it plainly". The reports were accurate
   when written; the work was committed afterwards. **Commit state is the one anchor that changes
   between writing a handoff and reading it, by definition**, and the next session must run
   `git status` anyway. Describe the *contents* — file counts, which files — and let the reader
   establish the state.

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


---

## Cluster 26 = the amendment REVIEW. Handed off 2026-08-06.

`HANDOFF-review-adr-001-criterion-2-amendment.md`. **The first review round since ADR-001's
acceptance on 2026-08-02, and a different genre from the thirty-three execution items between it and
here.** Producing source changes in it is a symptom.

**Why a review rather than another execution item:** D5 is Accepted, and this project's founding
mandate routes corrections to accepted decisions through a normal amendment with named reviewers.
WI-D9 drafted two and deliberately did not apply them.

**And the handoff author is not independent, which the handoff says in its own text.** The D7, D8 and
D9 handoffs share an author with this one, and one of them carried D8's binding-form split of 8/7
into the item that corrected it to 14/1 — a figure Amendment A's second clause rests on. **Four things
must be re-derived rather than read**, and that is the first of them.

**Clustering note, and it is new in kind: an execution item can produce a REVIEW as its successor.**
Every prior cluster produced another build. D9's output was an argument and a draft, and the next
thing the project needs is a disposition on them — from someone who did not write them. **Sequence a
review when the deliverable is a claim about an accepted decision rather than a change to the tree.**

**After the disposition, the order D9 established stands:** classifier 3 → Route B → WI-C5. Route B
alone clears zero barriers, and the review is what authorises classifier 3.


## Cluster 26 outcome, and cluster 27 = land the amendment

**The review returned BOTH AMENDMENTS ACCEPT WITH CONDITIONS** (B: 2, A: 4, neither Revise), all four
re-derivations confirming D9, and two findings beyond its scope — that classifier 1 does not meet its
recorded acceptance criterion, and that `compaction_structural` is the cheapest path to a non-zero
coverage number.

**Cluster 27 = WI-D10, land Amendments B and A: HANDED OFF 2026-08-06**,
`HANDOFF-execute-d10-land-the-amendment.md`. **The first item in this project to edit the ADR's
body** — every prior amendment appended a review section.

**Grounding found a cascade nobody had named, and its shape decides the work.** Inserting at
`ADR:1396` moves every line citation below it. Measured: **551 ADR citations across the project docs,
91 below the insertion point, 0 in source.** The split is what makes it tractable —
**76 are the ADR's own self-citations and 1 is the plan (live, must be re-derived); 14 are in notes,
reviews and handoffs (historical, must NOT be touched).**

**That 77/14 split is S15 applied to line references, and it is the trap.** A note citing `ADR:1412`
was true when written; re-dating it in place makes the note claim something it never claimed. **The
handoff also raises the structural fix — named anchors on the amended paragraphs — as a decision to
record rather than a change to slip in**, because this cascade will otherwise recur on every future
amendment.

**Clustering note: a documentation cascade is real work and this project has only ever sized the
source-anchor kind.** Four items paid the `make anchors` version. This is the same shape in a
different medium, it is cheaper (no profile re-issue, no content hash), and it was invisible until
someone counted.


## Cluster 28 = the acceptance reviewers' admission. Handed off 2026-08-06.

`HANDOFF-acceptance-reviewers-admit-classifier-3.md`. **Addressed to both ADR-001 acceptance
reviewers jointly — the second non-execution handoff in this project, and a different kind again from
the amendment review.** That one asked for a disposition on a draft; this asks for a **governance
act**: changing a count two people signed as finite.

**The ADR says in its own text that this is not the amendment's to make** (`:1493-1496`), which is why
WI-D10 landed both amendments and stopped one edit short.

**Grounding found the act is not the count — it is a ruling nobody has made.** WI-D10 annotated
classifier 1's row to *"Built; its acceptance criterion is NOT met at HEAD"* and flagged the cell edit
rather than burying it. **So the table now asks a question its own shape cannot express: is a
mechanism whose acceptance criterion is unmet still "Built"?** Three readings are available and they
give three different counts — four, or five, or a state the table has no vocabulary for. **The count
being changed from three depends on which is taken**, which is why the ruling and the admission are
one handoff rather than two.

**Clustering note: a handoff can be addressed to a ROLE rather than to a session.** Every prior one
assumed whoever picks it up executes it. This one cannot be executed by a session that is not those
two people, and saying so is the deliverable — an item that could be picked up and done by anyone
would be the wrong artifact here.


## Cluster 28 outcome, and cluster 29 = does the name adoption stand?

**The governance act landed: classifier 3 ADMITTED (deferred 3 → 4, table 4 → 5), with a condition of
the reviewers' own** — the admission holds only while the barrier count is *derived*, so `basis` must
reach `HookClassificationEntry` with or before any change that lowers it. They applied the architecture
test on two arms rather than inheriting it, took a **third reading** on classifier 1 that is neither
"Built" nor "Deferred", **revised** WI-D10's cell edit rather than ratifying it, and found **two live
count sites beyond the two the handoff named**.

**And a measurement in it does not reproduce, which is how cluster 29 was found.** Three sessions ran
`make effect_inventory_selftest` on the same tree on 2026-08-06 and got `agree=0`, `agree=1` and
`agree=45`. The variable is a compile cache at `/home/motoko/.local/share/ailang/std/.ailang/cache/`
that **S9's sweep cannot reach** — the sweep runs from the repo root, that path is under
`~/.local/share`. Two-sided: clearing it gives `45 → 1`, restoring gives `1 → 45`. **Both competing
findings about classifier 1 were readings of cache warmth.**

**Cluster 29 = WI-D11, does the name adoption stand: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d11-does-the-name-adoption-stand.md`.

**Grounding found a contradiction that predates the governance act by a full item.** The ADR says the
gate mechanisms *"block the name: D5's routing audit is not citable as name-adoption gate evidence
until each is built and passes its criterion"* — and it said so, with "three", **at the ADR state
WI-D5 read**. WI-D5 adopted the name anyway, checking D10's two conditions and never mentioning that
sentence. **Neither did this reviewer's handoff.** So the question is not whether the governance act
broke something; it is whether the adoption was sound when it was made, and nobody asked.

**Clustering note: a determination is a third genre, distinct from both execution and review.** A
review dispositions someone else's draft; this asks whether a decision already taken was correct, on
evidence anyone can re-derive. **It is the first item in this project pointed backwards at the
project's own headline claim**, and the handoff's hardest instruction is the symmetric one — do not
conclude the name stands because it was announced, and do not conclude it falls because a sentence
says "blocks".


## Cluster 29 outcome, and cluster 30 = build classifier 3

**WI-D11 answered: the name STANDS, qualified.** The sentence that appeared to unseat it has a **false
antecedent** — `ADR:2038` says *"Classifier 2 is not built"*, and classifier 2 was built at WI-A4 on
2026-08-03 and passes its criterion (verified: `ext_call_inventory_selftest` exit 0, zero failures).
**So the routing audit's stated blocker was discharged three days before D5 adopted the name.** D5 was
right without checking, and neither D5 nor this reviewer's handoff checked.

**Two findings left for other pens, both verified at review:** the gate table records three built,
green mechanisms as *"Deferred"* (`ext_call_inventory`, `attribution_table`, `profile_coverage` all
exit 0), and `head_inventory()` feeds `validate_completeness` **its own output** at the only live call
— which `dst_attribution_table.ail:446-448` forbids in as many words, one file over.

**Cluster 30 = WI-D12, build classifier 3: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d12-build-classifier-3.md`.

**Grounding settled the producer question, and the answer is neither candidate the review proposed.**
The textual parse fails open on 44 of 465 symbols; `ailang iface`'s stdout needs a stdlib cache no
project operation produces. **The compiler's own cached `iface.json` covers 21 of the 21 std modules
the repo imports — zero missing — is keyed by symbol, and distinguishes a CLOSED EMPTY ROW from an
EFFECT VARIABLE**, which is the distinction the whole yield turns on: `std/json`'s 38 exports carry no
textual row, so the textual route reports all 38 unresolved including `jo`, and three of the four clean
extensions import it. **That is what makes the yield 4 of 15 rather than 1.**

**Clustering note: three consecutive clusters have been decided by a measurement taken at review of the
previous one**, not by the plan and not by the handoff. D10's producer probe, D11's cache bound, and
now D12's producer choice. **Grounding is no longer resizing items — it is choosing between designs**,
and the handoff's job has shifted accordingly: carry the measurement, not the instruction.


## Cluster 30 outcome, and cluster 31 = `basis` and the per-extension barrier

**WI-D12: classifier 3 BUILT, GREEN, and IN `make dst`** — `RESOLUTION 19/19`, **`PORT-MEDIATED
(4 of 15)`**, `UNRESOLVED (0)`, selftest zero failures, verified at review. **Third independent
derivation of 4 of 15, from a producer neither prior derivation used.** It found the **builtin door**
nobody had named — `compaction_structural.ail:251` calls `_list_length` directly and no import would
flag it — and corrected the ADR's textual-route figure from **1 of 15 to 0 of 15**, because the
criterion's unit is the closure and `motoko-ext-abi/types.ail` imports `std/json (jo)` into all
fifteen.

**Cluster 31 = WI-D13: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d13-basis-and-the-per-extension-barrier.md`.

**Grounding found the shape of the item, and it is not the obvious one.** The obvious next step is
"install `compaction_structural` and get a non-zero coverage number". **It cannot be taken, because no
artifact in this tree can hold classifier 3's answer:** `HookClassificationEntry` has three fields and
no `basis`, and `check_barrier_count` derives a barrier as a property of a **slot** — reading the ABI
row and the dispatch table, nothing per-extension. **The measurement exists and the vocabulary to
record it does not.**

**Clustering note: an instrument's first real output can be un-recordable, and that is a work item
rather than a defect.** Four clusters built toward classifier 3 on the assumption that its verdict was
the hard part. The verdict took one item; **making the tree able to say it is a separate one**, and it
was invisible until the verdict existed. **Where a new producer is scheduled, schedule the artifact
that carries its answer in the same breath.**

**And the trigger is armed.** `check_barrier_count` goes red at zero deliberately. Re-shaping its
derivation to `(extension, slot)` can take the count to zero for one extension **without touching the
ABI** — which is exactly the case that message was written for, and the handoff scopes the install out
on that ground.


## Cluster 31 outcome, and cluster 32 = the second profile

**WI-D13: `basis` landed, the barrier derivation re-shaped to `(extension, slot)`, and FOUR extensions
clear — not the one the handoff anticipated.** Verified: `33 of 45 pairs stand`, slot-level count
still 3, `driver_only` v13 installing nothing, `basis` rejecting three ways with a loading control.
**The criterion decision: criterion 2, two of three clauses vacuous — and criterion 1 is UNAVAILABLE
rather than unearned**, so the handoff's stop rule did not fire for a reason it had not imagined.
**D13 declined to install**, on the ground that the coverage would be a fifth vacuity *with a number
attached*. Earned S21's and S15's newest extensions.

**Cluster 32 = WI-D14, the second profile: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d14-the-second-profile.md`.

**Grounding found that the ADR had already ruled on D13's dilemma, and nobody had looked.** Row 3's
own final clause reads *"the result reports per-extension covered/excluded hook **ids**, so a profile
covering only ABI-pure no-op slots is visible as such"* — and `ADR:8819` shows it was raised in review
as **R5** with that clause as the disposition. **The ADR contemplates a no-op-covering profile and
answers it with disclosure, not refusal.** D13's pause was right; the remedy was already specified.

**And the reframing is the handoff's main work: the number is the least interesting part.** Every
clause of row 3 that quantifies over installed extensions — the coverage floor, the unconditional-hook
rule, the classifier-2 rule, the per-extension id disclosure — **has been vacuous for the entire
project**. This is the first profile that would make them *bind*. **If any of them fails, that is
worth more than the profile.**

**Clustering note: when an item declines something on judgement, check whether the governing document
already decided it.** D13's decline was sound reasoning that duplicated a review round from before the
ADR was accepted. **A decision recorded in an artifact nobody re-reads is indistinguishable from a
decision never taken** — the same shape as D11's false antecedent, one document over.


## Cluster 32 outcome, and cluster 33 = registration versus hooks

**WI-D14: the second profile exists and ALL FOUR of row 3's installed-extension clauses BOUND and
held.** `driver_plus_no_ops/1` — four extensions, 32 hooks, **zero mediating**. Row 3's fifth clause
("visible as such") needed a FIELD rather than the ids, because a no-op hook and a mediating one
disclose the same eight names. The coverage statement is computed, and the guard **fails** a profile
reporting non-zero coverage without saying none of it mediates — the fifth vacuity made into a
rejection rather than a resolution.

**And it produced the first LIVE instance of the counted failure mode in thirty-eight runs**: the ABI
version pinned at `4.0` while the package declares `5.0`, silent for eleven items, in the artifact
whose job is exact reproducibility. **Earned S23** — a transcribed constant becomes checkable the
moment a second consumer has to state it. **What found it was writing the second profile's boundary
note**, not any instrument.

**Corrected at review: the stdlib-adjacent cache's producer is STILL unidentified.** D14 identified
`~/.ailang`'s 4 files; the open question is `~/.local/share/ailang/std/.ailang`'s 52. Different
directories.

**Cluster 33 = WI-D15: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d15-registration-versus-hooks.md`.

**Grounding found that Route B is not the blocker and never was the next thing to price.** Classifier
3 reports `compaction_ai` **AMBIENT because of its REGISTRATION** — `register.ail` imports `std/env`
and `std/fs`, while `compaction_ai.ail`, where the hooks live, imports seven modules every one of
which is proven effect-free. **The tree holds both the verdict and its refutation**
(`dst_driver_only.ail:597` argues the hooks are clean) **and nothing compares them.**

**So the amendment's two properties pull opposite ways** — property 1 is call-granular, property 2 is
closure-granular, classifier 3 implements 2 and coarsens 1 away on the record — and **D5's own text
quantifies over hooks, which registration is not.** The reading decides whether Route B is tractable
or larger than anyone has said.

**Clustering note: a coarsening recorded as a decision can silently become a bound on what the system
can ever achieve.** D12 recorded "an import alone is a rejection" as a conservative choice, correctly
and in the open. Three items later it is the reason no mediating extension can ever be cleared. **When
an item records a deliberate coarsening, the next item to depend on that instrument should re-ask what
the coarsening now costs** — it is S21's shape applied to a design decision rather than to a vacuity.


## Cluster 33 outcome, and cluster 34 = ROUTE B STARTS

**WI-D15: criterion 2 quantifies over HOOKS.** The reading rests on two sentences already in the ADR,
and Amendment A's own property 2 opens by agreeing before deriving the closure from it — *"criterion 2
quantifies over every hook … **so** the unit is the closure."* **A coarsening is not a definition.**
Yield 4 → 5, sets not nested; found **door 3** (`show`, a non-underscore language builtin, live in the
extension `driver_plus_no_ops` rests on) and earned **S24** after two of its own four slips were
fail-open and its fixture suite caught neither.

**Cluster 34 = WI-D16, Route B part 1: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d16-route-b-the-extports-surface.md`. **Route B was named and deferred in NINE
consecutive reports. This starts it.**

**The fork was resolved by measurement rather than by preference.** Compose's one registration-only
ambient source is `register.ail:3 — `import std/env (getEnvOr)`, and **registration runs before the
world exists**, so no amount of routing clears compose under the closure unit. The promotion is
genuinely required — **but it blocks the VERDICT, not the BUILD.** Every line of Route B is needed
under either unit, so the review can run in parallel and does not gate the work.

**Clustering note, and it is the one to carry: a blocked verdict is not a blocked build, and this
project conflated them for nine items.** Each deferral had a real reason — D9's was outright
vindicated — but the reasons were about whether the work would *count*, not about whether it could
*start*. **When an item is deferred on a decision, ask which half the decision actually gates.** Here
it gates the last step of three.

**And the build is CUT, because "Route B" was never one item.** D9 called it larger than D6 and D7
combined; D15 priced compose at 6 modules holding ~23 hook-reachable sources, a lower bound. Part 1 is
the `ExtPorts` surface — world-thread `proc_exec`, add a file seam — which discharges the long-owed
classifier-2 widening and is the precondition for routing anything. Part 2 routes compose. Part 3
removes the imports.

**Cluster 35 = WI-D17, the core filesystem WRITE class: HANDED OFF 2026-08-07**,
`HANDOFF-execute-d17-the-file-write-world-class.md`. **The half D16 decided and deliberately did not
build**, and the first of part 2's three blockers to become buildable.

**The clustering choice: build the blocker whose SHAPE is already decided.** Part 2 is blocked on this
class, a directory seam, and door 3's producer. The other two still need a decision; this one needs
only code, because D16 settled it on a measurement — writes in the world, `println` out, split by
whether the session ever observes the result.

**And the item carries a real design first, which is why it is an item and not plumbing.** Every
adapter in `Ports` today consumes from the world (`approvals: rest`, `tools: rest`), advances a scalar
(`clock_ms + 1`), or passes state through unchanged — `scripted_file`, `ambient_file`, `scripted_env`
and `ambient_env` all return `next_state: state` verbatim. **A write is the first class where the
driver puts something INTO the world**, and `state.files` stops being seeded-and-read-only.

**Which makes this project's counted failure mode structural rather than incidental.** A write adapter
that forgets its update leaves the next `file_read` returning `present: false` — **byte-identical to
what it returns if the write was never routed at all.** Absent reads identically to unchanged, and here
the two branches are the *same observation*, so only a write-then-read-back fixture asserting content
can tell them apart.

**Two established rules disagree inside this item and the handoff refuses to resolve it quietly.** D3's
rule is narrowness — *"a path in, existence and contents out"*, and D16's handoff said copy it, do not
generalise. D16's rule is two-homes — anything that changes what a mediated read returns must be
mediated. **Compose's write side is three builtins, not one: `writeFile` 7, `mkdirAll` 6, `removeFile`
5, and `removeFile` changes exactly what compose's `fileExists` branch reads.** So narrowness alone
leaves the defect standing on 5 of 18 sites. The item must answer out loud.

**Clustering note to carry: when a decision is inherited, check what the PRECEDENT actually did rather
than what it was described as doing.** D16 chose "world-mediated and recorded" for writes on the
strength of D3's read class — and D3's read class **is not recorded**. There is no `FileReadIdentity`
and no `recording_file`; the four recording adapters are clock, env, approval and tool, and
`EnvironmentReadIdentity` exists. So the precedent being copied contains an asymmetry nobody has
re-asked, and copying it silently would propagate one.

**Cluster 36 = WI-D18, the directory seam and the world's path key: HANDED OFF 2026-08-08**,
`HANDOFF-execute-d18-the-directory-seam-and-the-path-key.md`. **The last of part 2's build blockers**,
chosen over door 3 on D16's rule: a blocked verdict is not a blocked build, and door 3 gates whether
compose's coverage *counts* while this gates whether compose can be *routed at all*.

**The clustering note is that the named work was not the biggest thing in it.** The item was scoped as
"add the directory class" — three call sites, all in `author_tools.ail`, plus the six `mkdirAll` sites
D17 deferred. Grounding it turned up **two things that are not about directories**:

**A gap in what D3 built.** `list_dir_impl` guards `fileExists(path)` **then** `isDir(path)`, so
`author_tools.ail:189` asks `fileExists` about a **directory** — and routing that through
`Ports.file_read` gives **two adapters with two different wrong answers**: `scripted_file` finds no
flat entry and says `present: false`, `ambient_file` says true and proceeds to `readFile` a directory.
`normalize_type:140` needs three values where `FileRead.present` has two. **Part 2 would have hit this
whether or not anyone built a directory seam.**

**And a live two-homes defect with a producer no rule covers.** `lookup_file` and `remove_path` are
exact string equality and nothing normalizes, while the real filesystem does — so `tmp/x`, `./tmp/x`
and `/w/tmp/x` are three world entries and one file on disk. **The two-homes shape produced by the
world's KEY rather than by an unmediated effect**, and it is already reachable: `compose.ail:769`
creates `"${ctx.workdir}/tmp"` and `:771` writes `"tmp/${name}.ail"`. Absolute mkdir, relative write;
on disk they agree when cwd is workdir, in a world keyed on strings they never do. **The symptom is a
read returning `present: false` for a path just written — indistinguishable from a write that was
never routed**, which is D17's mutant 1 arriving from a different direction.

**Clustering rule to carry: when the seam count is small, ground the CALLERS before pricing the item.**
Three call sites read like plumbing. The callers said otherwise, and both findings are about classes
that already shipped.

**S25 applied to this handoff, which is the rule's first use by its author.** The measurement that
"no compose session can observe a created-but-empty directory" — all six `mkdirAll` sites write into
the directory immediately, verified line by line — is stated **with its condition**: it holds for
compose as written today and is falsified by a create-then-list site or by a future
`InitialWorld.files` that seeds an empty directory. The handoff asks the item to decide whether it is
buying that permanently or buying it with a guard.
