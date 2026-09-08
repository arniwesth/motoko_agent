# Review — ADR-001 D5 amendment, criterion 2's evidentiary basis

**Reviewer:** independent of WI-D6/D7/D8/D9 authorship. First review round since the scoped
architecture-acceptance review of 2026-08-02.
**Subject:** `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md`, drafted at WI-D9 against
`995a6d6`. Reviewed against HEAD `1f0a78c`.
**Nothing was applied.** No source file changed. Tree clean at exit; barrier count verified **3**.

## Dispositions

| | Disposition | Conditions |
|---|---|---|
| **Amendment B** — the record-field mechanism correction | **ACCEPT with conditions** | 2 |
| **Amendment A** — criterion 2's evidentiary basis | **ACCEPT with conditions** | 4 |

Neither is Revise. **Amendment A's argument survives every re-derivation and its fail-closed default
is correctly drafted** — so, per the handoff's question, the revision is to *neither* the argument nor
the default. All four conditions on A are additions: one unnamed dependency, and three scope claims
that are wrong in the *permissive* direction about what classifier 3 buys. One of those three is a
defect in the clause WI-C5's owner will read.

B should land first, as the draft says.

---

## The four re-derivations, with my numbers

### 1. The binding-form split — **14 inline / 1 named. D9 is right; D8's 8/7 is wrong, and I can show the arithmetic.**

Derived from `src/core/ext/registry_generated.ail`'s fifteen `register_with_config` imports, with
S22's falsifier: **exactly one `on_pre_step:` site per package, all fifteen package directories
resolved, residue accounted for.**

```
INLINE function expression in record-field position (14):
  test_dummy(register.ail:80)  omnigraph(register.ail:48)  context_mode(register.ail:69)
  mcp(mcp.ail:180)  exa_search(exa_search.ail:76)  ailang_docs(ailang_docs.ail:65)
  compose(compose.ail:830)  a2a(a2a.ail:184)  decision_framework(register.ail:166)
  microrag(register.ail:185)  compaction_ai(register.ail:109)  scratchpad(scratchpad.ail:107)
  empty_stop_guard(register.ail:30)  progress_contract_guard(register.ail:30)

NAMED top-level function (1):
  compaction_structural  register.ail:34 -> pre_step, defined register.ail:23
```

**Falsifier discharged.** 15 sites, 15 packages, one each. Residue is `packages/motoko-ext-abi`
(the type declaration) and `packages/motoko_ext_conformance` (a reject fixture plus the harness's six
call sites) — neither is a registrable extension. Sites under `scripts/` are test fixtures, outside
the derivation's set by construction.

**One strengthening of D9's falsifier that D9 did not record.** `scratchpad`'s directory is
`packages/motoko_scratchpad`, *not* `packages/motoko-ext-scratchpad`. A derivation resolving package
directories by name convention silently resolves **14 of 15**, and 14 is exactly the answer being
claimed — a wrong derivation and the right number, indistinguishable. The mapping must be read from
`ailang.toml:24`. I resolved it that way.

**D8's 8/7 reconstructed exactly, which D9 could not do.** Sites where `on_pre_step:` and its `func`
keyword share a line: **8** — progress_contract_guard, compaction_ai, a2a, context_mode, exa_search,
empty_stop_guard, mcp, scratchpad. Sites with `on_pre_step:` alone on its line: **6**. Named: **1**.
`8 + 6 + 1 = 15`, and `6 + 1 = 7`. **D8's table is a line-keyed count reported as a binding-form
count.** All six of the "alone on its line" sites carry a `func(...)` expression on the following
line — I read every one. D9's diagnosis is confirmed arithmetically, not just asserted.

Worth recording against D8 specifically: D8's *prose* got this right — "the gap is **positional**", a
lambda in record-field position — while D8's own per-slot table keyed on the line. **The table
contradicted the mechanism stated four paragraphs above it and nothing went red.**

**Verdict: Amendment A clause 2's figure is correct as drafted. 14 of 15.**

### 2. Provenance blindness — **confirmed, two-sided, against the imported ABI.**

Per S16's fourth extension, both arms exercise `ExtCtx`/`ExtPorts`/`AiStepOutcome` **imported from
`pkg/sunholo/motoko_ext_abi/types`**, not a local copy.

```
ARM 1  mediated(ctx, w, m, msgs) -> AiStepOutcome ! {AI, IO, Trace}
       body: ctx.ports.ai_step(w, m, msgs)                    -> ✓ No errors found!
ARM 2  ambient (ctx, w, m, msgs) -> AiStepOutcome ! {AI, IO, Trace}
       body: println(m); Trace.event(...); Ai.call(m)          -> ✓ No errors found!
       (no port touched at all)

CONTROL, each arm with Trace withheld from the row:
  mediated ! {AI, IO}  -> REJECTED  "Missing effects: Trace"
  ambient  ! {AI, IO}  -> REJECTED  "Missing effects: Trace"
```

Identical signature, identical row, identical verdict for a fully port-mediated body and a fully
ambient one. Both controls reject, so the checker is running on both files and is label-sensitive.
**The effect checker is blind to provenance by construction.** A declared row cannot express
mediation, and neither can a reconciled performed row — both are label sets.

**This is Amendment A's whole argument and it holds.**

### 3. B's local-versus-imported distinction — **confirmed, and I extended the bisection to four arms.**

The draft claims two probes. I ran four, because the two-probe version does not isolate the variable.

```
(a) LOCAL  type PortsL = { ai_step: (...) -> ... ! {AI, IO, Trace} },  rowless caller  -> ✓ ACCEPTED
(b) IMPORT pkg/.../types (ExtPorts),                                  rowless caller  -> REJECTED
                                     "Missing effects: AI, IO, Trace"
(c) LOCAL record NESTING the imported ExtPorts (type CtxL = { ports: ExtPorts })       -> REJECTED
                                     "Missing effects: AI, IO, Trace"
(d) LOCAL copy of the field, using the IMPORTED ExtWorld/Msg/AiStepOutcome verbatim     -> ✓ ACCEPTED
```

(c) and (d) are the bisection and they land where B says: the variable is **whether the record type
carrying the function-valued field is imported or locally declared**, not the types inside the field.
`ADR:1412`'s stated consequence — *"`ExtCtx.ports: ExtPorts` is exactly that shape"* — **is false of
the ABI**, exactly as B reports. Four lines of probe, three ADR conclusions re-founded.

### 4. The fail-closure mutation — **confirmed uncaught, and byte-identically so.**

One line added inside `packages/motoko-ext-compaction-ai/register.ail:109`'s inline `on_pre_step`
lambda, under a declared row of `! {AI, IO, Trace}` that does **not** name `Env`:

```
  on_pre_step: func(ctx: ExtCtx, msgs) -> PreStepOutcome ! {AI, IO, Trace} {
+   let _ = getEnvOr("MOTOKO_REVIEW_MUTANT", "");
    compact_with_ai(ctx, msgs, compaction_cfg)
  },

  ailang check               -> ✓ No errors found!
  make profile_definition    -> EXIT 0,  "barrier count DERIVED ... : 3"
  make declared_vs_performed -> EXIT 0,  37 passed / 0 failed, 44 ✓ rows
```

I went one step past D9 and diffed both gate transcripts against a re-run on the restored tree:
**byte-identical, both targets.** An ambient environment read in the most scrutinised hook in this
tree produces literally zero observable difference in the gate output.

Mutation reverted by extraction from the pre-mutation tar; `md5sum` matches
`9d79c9aef1f3b38ebe6411b771e9ba55`. Tree clean.

**Verdict: the narrower amendment is correctly refused, and A's safety argument stands.** Nothing
catches it, so it does not become available.

---

## The architecture test, applied to classifier 3 before the row is added

Stated as the acceptance reviewers stated it (`ADR:34-37`): *"if all three deferred mechanisms turned
out unbuildable, would D1–D11 still be the right architecture?"* — answered yes by both, **"because
each mechanism's absence degrades conservatively."** The draft's §Reviewers restates it in the
singular. I apply both.

**Answer: YES. The row may be added.** Classifier 3's absence degrades to exactly HEAD — criterion 2
evaluated on declared rows, three barriers, zero extension coverage. D1–D11 are untouched: D5's
contract, its criteria wording, its floor and its disclosure all stand unchanged whether or not the
instrument is ever built. The absence costs *coverage*, not correctness, which is the same
conservative-degradation shape the other three carry. **This mechanism passes the test the other
three passed, on the same ground.**

**And the handoff's escalation branch does NOT fire.** The handoff says: if classifier 3 is not
buildable, "criterion 2 has no evidentiary path at all… the extension model is uncoverable by
construction," which would be a D5-level finding rather than a D5 amendment. **That is not what the
measurements support, because there is a second, non-instrument path to coverage that the draft never
names.**

`compaction_structural`'s three barrier-slot hook bodies are **measurably effect-free**, with a
two-sided control:

```
pre_step's body verbatim, declared with NO effect row, outside the ABI record   -> ✓ ACCEPTED
  (its only call is compact_for_pre_step, which is `export pure func`)
on_response_intercept's body verbatim, no row                                  -> ✓ ACCEPTED
on_solver_candidate's body verbatim, no row                                    -> ✓ ACCEPTED
CONTROL: pre_step's body plus one getEnvOr, no row  -> REJECTED "Missing effects: Env"
```

And what actually stops that hook from *declaring* what it performs is not the classifier layer at
all — it is the **ABI record's closed row**:

```
narrow pre_step from ! {AI, IO, Trace} to no row, keep the binding:
  -> type error: failed to unify record field 'on_pre_step': failed to unify effect rows:
     incompatible closed rows: r1 has extra labels [], r2 has extra labels [AI IO Trace]
```

A named binding **cannot** declare narrower than its slot. So a measurably-effect-free hook is forced
to carry a row that fails criterion 1, by the type system, with no classifier involved. **The route
to coverage that does not need classifier 3 is an ABI change** — narrowing or splitting those slot
rows — and it already sits inside the deferred `motoko-ext-abi` major (eight changed rows). The
extension model is therefore *uncovered*, not *uncoverable by construction*. **No D5-level finding.**

### Is classifier 3 buildable? Attacking the draft's argument, property by property

The draft argues classifier 3 is buildable because it is structural, an import-and-call-name closure,
not blocked by the record-field limitation, and most of obligation 2 clause 2. **Three of the four
properties survive the attack; one has an unnamed dependency that is broken at HEAD.**

| Property | Verdict | Evidence |
|---|---|---|
| **1. Provenance, not labels** | **Buildable** | Classifier 2 already is this instrument in the positive direction: green, `ext_call_inventory_selftest` 0 failures, fail-closed on wrappers/aliases/values-not-called, scan roots `src,packages`. The draft's "classifier 2 is the natural host" is correct and is the strongest part of the argument. |
| **2. Total over the extension's transitive closure** | **Buildable, and cheaper than it sounds** | I derived every closure. **2–17 modules per extension**, and none reaches `src/core/session.ail`. This was the property I expected to sink the argument and it does not. |
| **3. Symbol-granular** | **Buildable, but the draft's cited source is 100% broken at HEAD** | See below. |
| **4. Fail-closed on the unresolvable** | **Buildable** | Classifier 2's existing discipline, already fixture-tested. |

**Property 3 is the finding.** Symbol granularity means knowing that `std/ai`'s `Message` is a type
while `call` is `! {AI}`. That data comes from `ailang iface`. At HEAD:

```
make effect_inventory           -> EXIT 0 (green), 46 of 46 modules report INTERFACE FAILURE
                                   every classification comes from the textual fallback
make effect_inventory_selftest  -> EXIT 1, FAIL:
   "the self-test compared ZERO modules, so it certified nothing. `ailang iface` produced no
    parseable interface for any stdlib module, which means the textual fallback is the only
    derivation in play AND is now completely unvalidated. This is a pass-shaped absence, not a pass."
```

The fallback, `textual_scan`, returns a **bool per file** — it is module-granular by construction. So
the draft's "classifier 1 … built only in its module-classification half" is true only in a degraded
sense: at HEAD that half runs entirely on an unvalidated approximation, and the per-symbol layer
classifier 3 needs has no working source. It is still buildable — `textual_scan` already locates each
declaration and its row and merely collapses them to a bool, so returning a dict is a small change
— but **the draft cites a built mechanism as evidence of buildability, and that mechanism does not
currently meet its own ADR acceptance criterion.**

**That is a standalone finding beyond this amendment, and it is why nobody noticed:** `ADR:2108`
records classifier 1 as *"Built and independently verified … Met at `a0d4edb`"*, and its criterion has
two clauses — zero unresolved modules **and** `effect_inventory_selftest` reports zero disagreements.
The second clause is failing. **Neither `effect_inventory` nor `effect_inventory_selftest` is in
`make dst`** (`Makefile:198`), so thirty-three items ran without seeing it, and `Makefile:1886`
explicitly says "Run it after any toolchain repin" — the toolchain has been repinned to v0.33.0 since.
The tool fails closed correctly and says so in plain words; nothing was listening.

---

## Conditions on Amendment A

Every one is an addition. **None revises the argument and none revises the fail-closed default.**

**A-1 — Name property 3's dependency, and stop citing classifier 1's built half as unqualified
support.** *(lands on the fourth producer bullet and on the "most of obligation 2 clause 2"
paragraph.)* Classifier 3's symbol granularity depends on per-symbol effect data that `ailang iface`
does not currently supply for any stdlib module. State the dependency, state the fallback route
(per-declaration textual parse), and record that classifier 1's module half is running unvalidated at
HEAD. **The status row for classifier 3 should not be added to *Gate mechanisms: built, and deferred*
in the same pass that leaves classifier 1's row saying "Built and independently verified" without a
note that its selftest is red.**

**A-2 — The Route B clause is wrong in the permissive direction, and it is the clause WI-C5's owner
will read.** *(lands on A's third change-bullet, "Route B becomes sufficient rather than merely
necessary.")* The draft says that with `compose`'s `FS`/`Process` and `context_mode`'s `Process`
routed through `ExtPorts` seams, "classifier 3 would report those extensions ambient-free and the
remaining two barriers would clear." **A fail-closed closure-based classifier 3 would report both
DIRTY.** Measured over every extension's transitive closure, effect-bearing std imports:

```
compose        (17 modules)  std/ai std/clock std/env std/fs std/io std/process
context_mode   ( 7 modules)  std/env std/fs std/process std/sem
```

Route B routes *calls* through seams; a closure classifier fails closed on the *imports*. Unless
Route B also removes every effect-bearing std import from a 17-module closure — which is materially
more work than routing the calls — **"Route B plus classifier 3 buys all three barriers" is false for
the two extensions the clause names.** Either the clause states the import-removal requirement, or it
drops the sufficiency claim.

**A-3 — State classifier 3's honest yield, which is 4 of 15, not fifteen.** *(lands on the
"Therefore criterion 2 may be established by measurement only by…" paragraph.)* Derived
independently, extensions whose transitive closure imports **no** effect-bearing std module:

```
AMBIENT-FREE CLOSURES: 4 / 15
  decision_framework   compaction_structural   empty_stop_guard   progress_contract_guard
```

(Independently reproduces WI-D9's per-extension figure.) Because the unit is the extension's closure
and the discipline is fail-closed, classifier 3 can never clear a single hook of an extension whose
closure is dirty — `compaction_ai` included, via `register.ail`'s `std/env` and `std/fs`. The
coarsening is *conservative*, so it is the right direction, but it caps the instrument's reach at four
extensions. That belongs in the specification, because it is what the instrument is worth.

**A-4 — The draft undersells classifier 3 in the one direction that changes WI-C5's ordering, and the
omission is material.** *(lands on the second and third change-bullets.)* The draft's cost claim is
"Route B alone buys nothing, and Route B plus classifier 3 buys all three barriers." It never says
what I measured above: **classifier 3 alone, with zero Route B work, would clear all three barriers
for `compaction_structural`** — all three of its barrier-slot bodies are measurably effect-free, and
its closure is ambient-free. That would make it the tree's **first installable extension** and the
first non-zero extension-model coverage in the project. The draft is correcting WI-C5's cost estimate
"in both directions"; there is a third direction and it is the cheapest path to a non-zero number.

Note the classification it would earn is criterion **1** in substance — effect-free by measurement,
vacuously satisfying criterion 2 — and the draft explicitly withholds criterion 1 from scope. That
withholding is right for an amendment about criterion 2, but the *consequence* should be stated: the
first hook classifier 3 clears will be one that performs nothing, not one that mediates.

### On the reading the handoff asked me to guard against

**Could Amendment A, as drafted, license a `WorldMediated` classification at HEAD? No — and I checked
the enforcement path rather than only the prose.**

A's operative sentence is unambiguous: *until classifier 3 exists and reports clean for an extension,
criterion 2 is evaluated on declared rows and no profile may record `WorldMediated` on any other
basis.* That is a fail-closed default, correctly drafted, and it forbids exactly the reading the
handoff feared. **Verified independently:** barrier count still **3** after this review;
`HookClassificationEntry` (`src/core/dst_profile.ail:207`) has three fields and no `basis`, so the
record could not carry a measured claim even if one existed; no `world_mediated` string appears in any
checked-in profile or fixture; and `driver_only` installs nothing, so **zero** classification entries
exist in this tree.

**One observation the draft should absorb, because it is not a defect in A but it changes why A is
safe.** The prohibition is *prose only*. `classification_agrees`
(`src/core/dst_profile.ail:893-910`) validates a `WorldMediated` entry against the disclosure's
excluded-id list and against **nothing else** — there is no check anywhere that a `WorldMediated`
classification has an evidentiary basis. So a profile author could write `WorldMediated` today and
pass the gate. **That was already true before this amendment and A does not worsen it**; what keeps it
unreachable is the barrier count, not the rule. A's own second change-bullet already anticipates the
fix (a `basis` field). Worth one sentence saying that the fail-closed default is unenforced and that
the barrier count is currently carrying it.

---

## Conditions on Amendment B

**B-1 — Decide the D6/D7/D8 question instead of asserting it, and the honest number is smaller than
1 of 15.** *(lands on B's second and third consequence bullets.)* The handoff asks whether those three
items' narrowings were still worth taking on the corrected number; the draft asserts they were and
does not argue it. **My answer: yes, and on a ground the draft does not give — but the prize as those
items stated it is worth even less than B says.**

D6, D7 and D8 each banked *"a binding that starts reading `Env` in this slot now fails to build."* B
correctly reduces that from 7 of 15 to **1 of 15**. But the enforcement did not vanish, it *moved* to
`register_with_config`'s row — D8 measured that itself — and D8 also measured that `Env` is admitted
by **14 of the 14 registration rows that exist**. My mutation in re-derivation 4 confirms it end to
end: `getEnvOr` inside `compaction_ai`'s inline `on_pre_step`, three gates green, gate output
byte-identical. **So for `Env` specifically — the effect all three items used as their example — the
total enforcement in this tree is one binding at the slot and zero at the backstop.**

The narrowings were nonetheless worth taking, for two reasons the draft should state rather than
assume: they cost nothing and are not reversible into a defect; and they are the **precondition** for
the register-row work, which is where essentially all enforcement for the other fourteen actually
lives. That makes "the fourteen `register_with_config` rows" the sharpest un-owned item in the
project, not merely a deferred one — and this review raises its stakes the same way D9 did.

**B-2 — Add the closed-row mechanism to the passage B is rewriting.** *(lands on B's first consequence
bullet, `ADR:1415`.)* B's replacement explains why a *rowless* slot is not provably effect-free. It
does not record the converse, which I measured and which is load-bearing for the same passage and for
A's yield: **a named binding cannot declare narrower than its slot, because the ABI record's rows are
closed.** So the five non-rowless slots are excludable-only *by the type system*, not merely by the
declared-row convention — and no amount of classifier work changes that without an ABI change. Since B
is already replacing `:1398-1418` and its whole purpose is to put the correct mechanism under three
existing conclusions, this is the passage where that belongs.

Everything else in B is confirmed and accepted as drafted: the repro reproduces on a local type, fails
on the imported one, the bisection isolates to the type declaration, the inert inline row is real in
both directions, WI-D8's chain measurement stands, and the upstream filing `fb_74f53de3ae65854c` is
valid and narrower than the ADR applies it.

---

## If the disposition is accepted: what applying it consists of, and who holds the pen

**Not this reviewer's to apply, and not the draft author's either.** Three edits, three different
owners:

1. **Amendment B's replacement of `ADR:1398-1418`**, plus condition B-2's closed-row paragraph. This
   is a mechanism correction inside an Accepted decision with no decision change. **Pen: the ADR
   author, on this review plus one reviewer independent of D6/D7/D8** — which this review is. B needs
   no acceptance-reviewer involvement, which is why it can land first and alone.
2. **Amendment A's insertion after `ADR:1396`**, with conditions A-1 through A-4 applied. Same
   ownership as B, plus A-2's Route B clause needs **WI-C5's owner** to sign the corrected cost claim,
   since it is their estimate being revised in three directions.
3. **The `Gate mechanisms: built, and deferred` table and the Status block.** The table gains
   classifier 3 as a **fourth** deferred mechanism; `ADR:20-22` says "Three deferred gate mechanisms"
   and `ADR:2113` says "None of the three deferred mechanisms blocks acceptance", and both move to
   four. **Pen: both ADR-001 acceptance reviewers, jointly.** They signed off a finite list of three;
   this review's architecture test clears classifier 3 for admission, but the count they signed is
   theirs to change, not the author's and not mine. **Condition A-1 blocks this third edit
   specifically** — classifier 1's row must not keep reading "Built and independently verified" in the
   pass that adds a fourth row beneath it.

Order: B, then A's insertion, then the table and Status. Nothing is installable at any point in that
sequence and the barrier count does not move.

---

## Answers to the handoff's report-back list

- **Disposition:** B **Accept with conditions** (2). A **Accept with conditions** (4). Separate, and B
  first.
- **Binding-form split:** **14 inline / 1 named**, falsifier discharged, and D8's 8/7 reconstructed
  exactly as a line-keyed count (8 same-line + 6 alone-on-line + 1 named = 15). D9's figure is right;
  A clause 2 stands as drafted.
- **Provenance blindness:** confirmed, two-sided control, against the imported ABI. Identical verdict
  for mediated and ambient at the identical row; both controls reject on `Trace`.
- **B's local-versus-imported distinction:** confirmed in four arms, not two. `ADR:1412`'s stated
  mechanism is false of the ABI. Every conclusion survives.
- **Fail-closure mutation:** confirmed uncaught, and the gate transcripts are byte-identical to the
  unmutated tree. The narrower amendment stays refused.
- **Architecture test on classifier 3:** *"if this mechanism turned out unbuildable, would D1–D11
  still be the right architecture?"* — **Yes**, and its absence degrades conservatively to exactly
  HEAD, which is the ground both acceptance reviewers used for the other three. **The handoff's
  D5-level escalation does not fire:** the extension model is uncovered, not uncoverable by
  construction, because a measurably-effect-free hook is blocked by the ABI's *closed row* rather than
  by the classifier layer, and that is an ABI change already sitting in the deferred `motoko-ext-abi`
  major.
- **Could A license a `WorldMediated` classification at HEAD?** **No.** Its operative sentence forbids
  it, and independently: barrier count 3, `HookClassificationEntry` has no `basis` field, no
  `world_mediated` in any profile or fixture, zero classification entries in the tree. The one thing
  worth adding is that the prohibition is unenforced prose and the barrier count is what carries it —
  true before the amendment, not worsened by it.
- **Did anything move the barrier count?** **No. It is three**, verified from `make profile_definition`
  after the tree was restored: `on_pre_step`, `on_response_intercept`, `on_solver_candidate`;
  `on_budget_plan` coverable, `on_tool_handle` gated. Route B, WI-C5 and criterion 1 untouched.

## Grounding and hygiene

Reviewed against HEAD `1f0a78c`, clean at start and clean at exit (`git status` empty both times).
Pre-mutation `tar` of `packages src scripts Makefile tools ailang.toml ailang.lock` taken before any
probe, per S17; the two source mutations (`compaction-ai/register.ail`, then
`compaction-structural/register.ail`) were each reverted and verified by `md5sum` against their
pre-mutation hashes. Eight probe modules were written under the repo — **not** the scratchpad, so
MOD010 was never auto-relaxed on a decisive probe — and deleted. Long runs captured to files and read
as artifacts, per S19; `$?` never read after a pipe.

**`.packages/` staleness recurred for the FIFTH consecutive item.** `make sync_packages` was needed
before any gate read source-consistent state, and it moved `ailang.lock`'s `generated_at` timestamp
again — reverted at exit. D6, D7, D8 and D9 each recorded this. **The operational debt list in the
handoff is confirmed on its first item by this review, from the review side rather than the execution
side, and the review needed the same two commands nothing enforces.**

**`corpus_pr` was deliberately not run.** Per the handoff's second operational debt, its ceiling gate
measures the box as much as the tree, and a review that produced a red from a loaded machine would be
reporting an instrument reading as a finding — which is exactly the error D9 nearly made. It is
untouched and unclaimed here.

## What this review found that was not in its scope but should not wait

**Classifier 1 — the ADR's one *built* mechanism — does not meet its recorded acceptance criterion at
HEAD.** `make effect_inventory_selftest` fails closed with "a pass-shaped absence, not a pass"; all 46
`ailang iface` calls fail MOD010; every module classification comes from an unvalidated textual
fallback; and neither target is in `make dst`, so the degradation has been invisible for thirty-three
items across a toolchain repin the Makefile explicitly warns about. The tool behaved correctly. **This
is not a new defect and it is not this amendment's — it is the existing `ailang iface` MOD010 filing
arriving at a place where it now blocks something.** It is condition A-1's substance and it should be
folded into whatever runs next, together with the three operational debts the handoff names.
