# 2026-08-06 Cluster 34: review of the ADR-001 D5 amendment — criterion 2's evidentiary basis

## Context

Branch: `arniwesth/mot-72-review-the-adr-001-d5-amendment`.

Session span: `1f0a78c` → **uncommitted**. **No source file changed.** One new document. Input was
`HANDOFF-review-adr-001-criterion-2-amendment.md` (`f81d892`), reviewed against HEAD `1f0a78c`. Pin
**v0.33.0**.

**A REVIEW, not an execution** — the first review round in project 009 since the scoped
architecture-acceptance review that accepted ADR-001 on 2026-08-02, and a different genre from the
thirty-three execution items between. Subject:
`DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md`, drafted at WI-D9 against `995a6d6`, two
separable amendments. **Producing source changes here would have been a symptom; none were produced.**
Output is a disposition and its reasoning:
`.agent/projects/009_motoko_dst_execution/REVIEW-adr-001-criterion-2-amendment.md`.

**Why a reviewer rather than another execution item.** D5 is Accepted, so a correction goes through a
normal amendment with named reviewers rather than an inline edit; WI-D9 drafted and deliberately did
not apply. And the author was not independent — the D7, D8 and D9 handoffs were written by the same
reviewer, and one of them carried a wrong figure into the item that corrected it.

**Grounding.** `git status` empty at start and at exit. Pre-mutation `tar` of
`packages src scripts Makefile tools ailang.toml ailang.lock` taken before any probe, per S17; two
source mutations each reverted and verified by `md5sum` against their pre-mutation hashes. Eight probe
modules written **under the repo**, not the scratchpad, so MOD010 was never auto-relaxed on a decisive
probe — the trap D9 recorded — and all deleted. Long runs captured to files and read as artifacts per
S19; `$?` never read after a pipe.

| Definition-of-done item | State |
|---|---|
| Separate dispositions for A and B, with reasoning | **met** — B **Accept with conditions** (2), A **Accept with conditions** (4) |
| Each condition tied to the clause it lands on | **met** — 6 conditions, each anchored to a clause or ADR line range |
| The four re-derivations, with my numbers not the draft's | **met** — all four re-derived; all four confirm the draft |
| The architecture test applied to classifier 3, as the acceptance reviewers stated it | **met** — **passes**; the escalation branch does not fire |
| Whether A could license `WorldMediated` at HEAD | **met** — **No**, checked on the enforcement path, not only the prose |
| Whether anything moved the barrier count | **met** — **three**, verified after the tree was restored |
| If Revise on A: argument or fail-closed default? | **not triggered** — Accept with conditions; stated explicitly that it is neither |
| If Accept: what applying it consists of, and who holds the pen | **met** — three edits, three owners, an order, and one blocking condition |
| Do not apply the amendment (out of scope) | **respected** — nothing written into the ADR |
| Building classifier 3 (out of scope) | **respected** — authorized by the architecture test, not built |
| Route B, WI-C5, the barrier count (out of scope) | **respected** — all untouched |
| Criterion 1 (out of scope) | **respected** — untouched; its consequence stated, not widened |
| Re-filing `fb_74f53de3ae65854c` (out of scope) | **respected** — the owed *correction* re-recorded, not filed |

## The four re-derivations

**1. The binding-form split: 14 inline / 1 named.** Derived from `registry_generated.ail`'s fifteen
imports with S22's falsifier — one `on_pre_step:` site per package, fifteen package directories
resolved, residue accounted for (`motoko-ext-abi`'s type declaration and `motoko_ext_conformance`'s
fixture plus harness call sites; `scripts/` sites are fixtures, outside the set by construction).

**D8's 8/7 reconstructed exactly, which D9 could not do:** 8 sites share a line with `func`, 6 put
`on_pre_step:` alone on its line, 1 is named — `8 + 6 + 1 = 15`, and `6 + 1 = 7`. **D8's table is a
line-keyed count reported as a binding-form count.** All six "alone on its line" sites carry a
`func(...)` expression on the following line; each was read. Recorded against D8: its *prose* had the
mechanism right — "the gap is **positional**" — while its own table four paragraphs below keyed on the
line, and nothing went red.

**One strengthening of D9's falsifier that D9 did not record.** `scratchpad`'s directory is
`packages/motoko_scratchpad`, not `motoko-ext-scratchpad`. A derivation resolving package directories
by name convention resolves **14 of 15** — a wrong derivation and the right number, indistinguishable.
The mapping must be read from `ailang.toml:24`.

**2. Provenance blindness: confirmed, two-sided, against the imported ABI** (S16's fourth extension —
`ExtCtx`/`ExtPorts`/`AiStepOutcome` imported, not copied). A fully port-mediated body and a fully
ambient one, identical signature and identical row, both `✓ No errors found!`; each control with
`Trace` withheld rejected on `Missing effects: Trace`. **The effect checker is blind to provenance by
construction.** This is A's whole argument and it holds.

**3. B's local-versus-imported distinction: confirmed in four arms, not two.** Local type → accepted;
imported `ExtPorts` → rejected `Missing effects: AI, IO, Trace`; a local record **nesting** the
imported `ExtPorts` → rejected; a local **copy** of the field using the imported `ExtWorld`/`Msg`/
`AiStepOutcome` verbatim → accepted. The bisection isolates to the type *declaration*. `ADR:1412`'s
stated mechanism is false of the ABI.

**4. The fail-closure mutation: uncaught.** One `getEnvOr` inside `compaction-ai/register.ail:109`'s
inline lambda under a row that does not name `Env` — `ailang check` green, `make profile_definition`
EXIT 0 at barrier count 3, `make declared_vs_performed` EXIT 0 / 37 passed / 44 ✓ rows. **Went one step
past D9: both gate transcripts diffed against a re-run on the restored tree and are byte-identical.**
The narrower amendment stays refused.

## The architecture test on classifier 3

Stated as the acceptance reviewers stated it (`ADR:34-37`) — *"if all three deferred mechanisms turned
out unbuildable, would D1–D11 still be the right architecture?"*, answered yes because each
mechanism's absence **degrades conservatively**.

**Classifier 3 passes on the same ground.** Its absence degrades to exactly HEAD: criterion 2 on
declared rows, three barriers, zero coverage. D1–D11 untouched. The row may be added.

**And the handoff's D5-level escalation does NOT fire.** `compaction_structural`'s three barrier-slot
hook bodies are **measurably effect-free** (two-sided control; its `compact_for_pre_step` is
`export pure func`). What forces the wide row is the **ABI record's closed row** — narrowing
`pre_step` to no row fails with *"incompatible closed rows: r1 has extra labels [], r2 has extra
labels [AI IO Trace]"*. **A named binding cannot declare narrower than its slot.** So a
measurably-clean hook is blocked by the type system, not by the classifier layer, and the route around
it is an ABI change already sitting in the deferred `motoko-ext-abi` major. **The extension model is
uncovered, not uncoverable by construction.**

**Buildability, property by property:** provenance (classifier 2 already is this instrument — green,
selftest 0 failures, fail-closed on wrappers/aliases) **buildable**; transitive closure **buildable and
cheaper than expected** — every extension's closure measured at **2–17 modules**, none reaching
`src/core/session.ail`; fail-closed **buildable**; **symbol granularity is the gap** — its data source
is `ailang iface`, which supplies nothing at HEAD.

## Conditions

**On A** — all four are additions. **Neither the argument nor the fail-closed default needs revision**,
stated explicitly for WI-C5's ordering.

- **A-1** — name property 3's dependency and stop citing classifier 1's built half unqualified.
- **A-2, the defect that matters** — A's Route B clause is wrong in the permissive direction. A
  fail-closed closure classifier reports `compose` (17 modules; `std/ai clock env fs io process`) and
  `context_mode` (`std/env fs process sem`) **dirty**: Route B routes *calls*, not *imports*. "Route B
  plus classifier 3 buys all three barriers" is false for the two extensions the clause names, and
  this is the clause WI-C5's owner will read.
- **A-3** — state the honest yield: **4 of 15** ambient-free closures (`decision_framework`,
  `compaction_structural`, `empty_stop_guard`, `progress_contract_guard`), independently reproducing
  D9's figure.
- **A-4** — the draft undersells in the direction that changes ordering: **classifier 3 alone, zero
  Route B, clears all three barriers for `compaction_structural`**, the tree's first installable
  extension. The draft corrects WI-C5's cost "in both directions"; there is a third, and it is the
  cheapest path to a non-zero coverage number. Its classification would be criterion **1** in
  substance — the first hook cleared performs nothing rather than mediating.

**On B** — both are additions; everything else in B is confirmed as drafted.

- **B-1** — decide the D6/D7/D8 question instead of asserting it, and **the honest number is smaller
  than B's 1 of 15**. The enforcement moved to `register_with_config`'s row, and `Env` is admitted by
  14 of the 14 rows that exist — confirmed end to end by re-derivation 4. So for `Env`, the effect all
  three items used as their example, total enforcement is **one binding at the slot and zero at the
  backstop**. The narrowings were still worth taking, on a ground the draft does not give: they cost
  nothing and they are the precondition for the register-row work, where essentially all enforcement
  actually lives.
- **B-2** — add the closed-row mechanism to the passage B is already replacing: the five non-rowless
  slots are excludable-only **by the type system**, not merely by the declared-row convention.

## Could Amendment A license `WorldMediated` at HEAD? **NO**

Its operative sentence forbids it, and the enforcement path was checked rather than only the prose:
barrier count **3**; `HookClassificationEntry` (`dst_profile.ail:207`) has three fields and no
`basis`; no `world_mediated` string in any checked-in profile or fixture; `driver_only` installs
nothing, so **zero** classification entries exist.

**One observation the draft should absorb.** The prohibition is *prose only* —
`classification_agrees` (`dst_profile.ail:893-910`) validates a `WorldMediated` entry against the
disclosure's excluded-id list and against nothing else. A profile author could write it today and pass
the gate. **True before this amendment and not worsened by it**; what keeps it unreachable is the
barrier count, not the rule. A's own `basis`-field bullet already anticipates the fix.

## Applying it: three edits, three owners

1. **B's replacement of `ADR:1398-1418`** plus B-2 — mechanism correction, no decision change. Pen:
   the ADR author on this review plus one reviewer independent of D6/D7/D8, which this review is. **B
   needs no acceptance-reviewer involvement**, which is why it lands first and alone.
2. **A's insertion after `ADR:1396`** with A-1…A-4 applied. Same ownership, plus **WI-C5's owner** must
   sign A-2's corrected cost claim.
3. **The `Gate mechanisms` table and the Status block.** `ADR:20-22` ("Three deferred gate
   mechanisms") and `ADR:2113` both move to four. **Pen: both ADR-001 acceptance reviewers, jointly** —
   they signed a finite list of three and the count is theirs to change. **A-1 blocks this edit
   specifically.**

Nothing is installable at any point in that sequence and the barrier count does not move.

## Out-of-scope finding that should not wait

**Classifier 1 — the ADR's one *built* mechanism — does not meet its recorded acceptance criterion at
HEAD.** `ADR:2108` says *"Built and independently verified … Met at `a0d4edb`"* and the criterion has
two clauses. The second is failing:

```
make effect_inventory          -> EXIT 0 (green), 46 of 46 modules INTERFACE FAILURE
                                  every classification from the textual fallback
make effect_inventory_selftest -> EXIT 1: "compared ZERO modules, so it certified nothing …
                                  the textual fallback is the only derivation in play AND is now
                                  completely unvalidated. This is a pass-shaped absence, not a pass."
```

`textual_scan` returns a **bool per file** — module-granular by construction — so the per-symbol layer
classifier 3 needs has no working source. **Neither target is in `make dst`** (`Makefile:198`), and
`Makefile:1886` explicitly says "Run it after any toolchain repin" — the toolchain has since been
repinned to v0.33.0. The degradation has been invisible for thirty-three items. **The tool failed
closed correctly and said so in plain words; nothing was listening.** Not a new defect and not this
amendment's — it is the existing `ailang iface` MOD010 filing arriving where it now blocks something.

## Operational debts, confirmed from the review side

- **`.packages/` staleness recurred for the FIFTH consecutive item.** `make sync_packages` was needed
  before any gate read source-consistent state, and it moved `ailang.lock`'s `generated_at` again —
  reverted at exit. D6, D7, D8 and D9 each recorded it. **A review needed the same two commands nothing
  enforces.**
- **`corpus_pr` deliberately not run.** Its ceiling gate measures the box as much as the tree (D9: 11×
  swing, 273 s → 25 s against an 80 s ceiling, tree unchanged). A red from a loaded machine would be
  reporting an instrument reading as a finding — the error D9 nearly made. Untouched and unclaimed.
- **The `motoko-ext-abi` major stands at eight changed rows**, and this review raises its stakes: it is
  now the *only* route to coverage that does not require classifier 3, because the closed row is what
  blocks a measurably-clean hook.

## DID COVERAGE MOVE? **NO.**

Nothing was installed, nothing was applied, `driver_only` still installs nothing. **Extension-model
coverage is ZERO.** Barrier count verified **three** after the tree was restored — `on_pre_step`,
`on_response_intercept`, `on_solver_candidate`; `on_budget_plan` coverable, `on_tool_handle` gated.

**D9 measured the criterion and found the criterion was never the obstacle. This review re-derived all
four of D9's load-bearing measurements and confirmed every one — including against its own author's
wrong figure — then found that the draft's remaining errors all run in the *permissive* direction about
what classifier 3 buys.** The amendment is sound; three of its scope claims are too generous, and one
of them is the sentence WI-C5's owner would have planned against.
