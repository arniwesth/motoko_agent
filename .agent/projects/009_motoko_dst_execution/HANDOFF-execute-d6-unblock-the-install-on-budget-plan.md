# Handoff: WI-D6 — unblock the install, and the one item that makes the name transfer

Audience: a fresh session grounded against HEAD. Source-heavy ABI work; you are that session.

**WI-D5 adopted the name on 2026-08-06.** Eleven of eleven acceptance rows hold for `driver_only/10`,
and the unqualified "DST"/"simulation" label is earned for the generated axis. **It rests on a
baseline that covers no extension**, and this is the item that changes that — D5 names it in as many
words as *"the one item that would make the name transfer."*

**Read first:** `NOTE-d5-acceptance-table-rerun-and-name-decision.md` — its *"What the label does NOT
assert"* and *"The one item that would make the name transfer"* sections are your brief. Then
`NOTE-c5-execution-report-and-plan-corrections.md`, whose detector is your instrument. Then the plan's
`## Standing rules`; **S21 is new and this item is the first that must apply it deliberately.**

## Mission

**Make an extension installable in a conformant profile.** Today none is, and that is *forced* rather
than chosen:

```ailang
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},   -- types.ail:326
  export type BudgetPatch = { requested_total, requested_solver, requested_verifier }
```

Under D5 the slot is coverable under **neither** criterion — criterion 1 fails on the closed declared
row naming `Env` and `FS`, criterion 2 fails because `BudgetPatch` carries **no successor field at
all** — and the slot is **unconditionally dispatched**, so it cannot be excluded either. Every
extension in the tree binds it.

## The finding that makes this smaller than "an ABI major"

**There are two routes, and WI-C5 already measured the evidence for the cheap one.**

| Route | Satisfies | Cost |
|---|---|---|
| **A — narrow the declared row to what is performed** | **criterion 1** (deterministic and effect-free) | one ABI row; every binding must match exactly |
| **B — world-mediate the effects and add a successor** | criterion 2 | a result-type change across every binding, plus port work |

**C5's declared-versus-performed detector exists precisely to license Route A, and its headline
measurement is this slot:**

```
DECLARED  on_budget_plan : ! {Env, FS}   (ABI row, static, authored)
PERFORMED on_budget_plan : ! {}          (runtime, out of process, witnessed)
```

`make declared_vs_performed` is green at 10 rows and compares two genuinely independent producers — a
static row grepped from source against the AILANG interpreter's capability trap observed out of
process. **D5's verdict says the barrier is "the rule, not the behaviour."** Route A is acting on
that.

**Route A is also structurally safe in the direction that matters.** I measured at C5 that narrowing a
**record field's** effect row is *rejected* by the compiler — `incompatible closed rows: r2 has extra
labels [AI Env Net SharedMem Stream]` — so once the ABI row narrows, **every binding that still
performs more will fail to compile.** B4's refutation is about function-typed *parameters*, not record
fields, and the plan scopes it correctly. **The compiler is on your side here; it is not on your side
for Route B.**

## The rule you will break by accident

**C5's detector measured COMPOSE. Eight other extensions bind this slot.**

`progress-contract-guard`, `omnigraph`, `compaction-ai`, `exa-search`, `motoko_scratchpad`, `microrag`,
`test-dummy`, `a2a` — each binds `on_budget_plan`, most with a trivial no-op body, **and none has been
measured.** A single binding that genuinely performs `Env` or `FS` blocks Route A for the shared row.

**Measure every binding before narrowing anything, with C5's instrument rather than by reading the
bodies.** Reading them is how the seven stale "structural cause" reasons in D1 and D2 got written; the
detector's whole point is that declared rows are unreliable in both directions. **And per S16, name
the two producers for each subject** — the detector's design already does, and a new subject that
quietly derives "performed" from the declaration would report agreement by construction.

**If one binding does perform an effect**, that extension is the exception and the honest answers are
narrowing the row to what the *widest* honest binding performs, or Route B for that slot. **Report
which, rather than narrowing to the convenient value.**

## This item FALSIFIES a caveat that was written yesterday, and owns updating it

**D5 made one sentence mandatory in every report**, and put it in a design document that outlives this
project:

> **The axis's extension-model coverage is ZERO, and that is structural rather than incidental.**
> `driver_only` installs no extension, and the empty install list is **forced**: while
> `ExtensionHooks.on_budget_plan` declares the ABI's closed row `! {Env, FS}` and returns a
> `BudgetPatch` with no successor field, no extension in the tree is installable in a conformant
> profile.

**The moment you narrow that row, the sentence is false.** It appears in
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` and in D5's note. **This item must
update it** — per S15, by restating with its date rather than deleting, exactly as D5 restated the
2026-07-24 naming claim it superseded.

**And per S21, updating it is not enough.** D5 measured that **four** acceptance rows lean on the
empty install list — row 3 vacuously, row 4's `extension_effect_fault` waiver, row 5's
transferability, row 7's `ScratchpadResult` exemption. **Unblocking the install does not close any of
them**, because `driver_only` still installs nothing by its own definition. What changes is that the
emptiness stops being *forced* and becomes *chosen*, which is a different claim and a weaker one.
**Re-ask, of each of those four, what its reason becomes.** S21 exists because that count moved from
two to four without any item noticing.

## What this item does NOT deliver

**It does not make any row non-vacuous.** That needs a profile that actually installs something —
**WI-C5, the `compose`-bearing second profile**, which is the plan's last unbuilt work item and is the
next item after this one. This item removes the blocker; C5 spends it.

**Say so plainly in the report.** A green `make driver_only` after this change still covers nothing,
and the temptation to report "extensions are now installable" as though coverage had moved is exactly
the shape D5's mandatory caveat exists to prevent.

## Definition of done

**Every `on_budget_plan` binding measured**, not read — with the detector's subject list extended and
each new subject's two producers named.

**The row narrowed to what is honestly performed**, or Route B taken with its reason, or the blocker
reported as standing with the binding that blocks it named.

**`make declared_vs_performed` extended and green**, including a control that must die, per C5's
discipline — a subject whose completion is not paired with a control that fails on the named
capability establishes nothing.

**D5's caveat updated wherever it appears**, dated rather than deleted, and **the four leaning rows
re-examined per S21** with what each reason becomes.

**The owed `motoko-ext-abi` major addressed.** Four rows have changed across B1/B2a/B2b/C5 and this is
the fifth; D3 recorded that the lock file has already moved. **If this item does not cut it, say why
and what the count now stands at.**

**Per S13 — sweep cache-cold with `AILANG_RELAX_MODULES=1`, failing set member-for-member, and run
`make dst` in full.** D3's regression was invisible to everything smaller. **Per S9 — clear every live
`.ailang/cache`, leave `~/.ailang/cache/registry` alone, and check no other session is running a
gate.** **Per S17 — mutants restore by `cp`.**

## Out of scope

- **WI-C5, the `compose`-bearing profile.** The next item, and the one that turns this into coverage.
- **Re-running the acceptance table.** D5 ran it; nothing here changes a row's answer, and if you
  believe it does, that is a stop-and-report.
- **The two sibling `st.world_state` finalize sites**; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds;
  `test_coverage` and `test_coverage_selftest`, red since B2a.

## Stop and report rather than deciding inline

- **If any binding genuinely performs `Env` or `FS`**, report it before choosing a row. That is a
  conformance fact about a real extension and it decides the route.
- **If narrowing the row breaks a package that is not in `make dst`'s reach**, that is S13's lesson
  again — three targets went red at D3 and one was found only by a full sweep.
- **If this change makes an extension installable and something then installs one**, stop. A profile
  that installs an extension is WI-C5, it carries a coverage claim and a version bump, and it is not
  a side effect of an ABI edit.

## Report back

Thirtieth calibration run.

- **The git wall-clock window.**
- **The measurement table: every binding, declared against performed.** The item's durable output, and
  the first time this slot has been measured beyond compose.
- **Which route was taken and why**, or the blocker with the binding that causes it.
- **What D5's caveat now says**, and what each of the four leaning rows' reasons became per S21.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **55 across
  twenty-nine runs; determinism has caught none.** This item narrows a closed record row, where the
  compiler rejects the wrong answer — so a silent site here would have to be somewhere else, and per
  S20 the place to look is anything that reads a *declared* row as evidence of behaviour.
- **Whether coverage moved.** It should not. Say so.
