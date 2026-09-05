# DRAFT amendment to ADR-001 D5 — criterion 2's evidentiary basis, and the record-field mechanism

**STATUS: DRAFTED, NOT APPLIED.** D5 is Accepted; per this project's mandate a correction to an
accepted decision goes through a normal amendment with named reviewers rather than an inline edit.
Written at WI-D9 against HEAD `995a6d6`. Nothing in this file has been written into
`ADR-001-deterministic-test-world-architecture.md`, and the barrier count is unmoved at **three**.

Two amendments. **A** is the item's question. **B** is a factual correction to the paragraph **A**
rests on, discovered while grounding **A**, and it changes no conclusion anywhere in the ADR — only
the mechanism the ADR gives for them. They are separable and can be reviewed separately; **B** should
land first, because **A** cites it.

---

## Amendment A — criterion 2 admits measured mediation, and no producer supplies it

*Proposed insertion point: `ADR-001` immediately after `:1396`, i.e. after the paragraph beginning
"**Per-hook classification reads *declared* effect rows in the interim**".*

> **Amendment, DRAFT (WI-D9 measured; not applied). Criterion 2 is a claim about behaviour and its
> text admits evidence other than a declared row. The declared-row rule is nonetheless RETAINED, and
> the reason is not the criterion's wording — it is that no producer in this tree can supply criterion
> 2's evidence, and the successor detector named above cannot supply it in principle.**
>
> Criterion 2 reads: *"effectful only through D1 world-mediated ports, with origin tagged by extension
> id and explicit world state returned to the host."* Nothing in that sentence names a declared row.
> The declared-row reading is a separate, explicitly **interim** classification rule stated in the
> paragraph above, adopted when no other instrument existed and pending obligation 2's successor
> detector. Eleven work items have evaluated criterion 2 against declared rows on that basis and each
> was right to. This amendment records that the basis was tested, and what the test found.
>
> **1. The successor detector is the wrong instrument for criterion 2, and no narrowing of it will
> help.** The detector this ADR defers is a *declared-versus-performed reconciler* — it lets a profile
> claim a hook performs less than it declares. That reconciles the **set of effect labels**. Criterion
> 2 is not a claim about labels; it is a claim about the **call path**. Measured at WI-D9 against the
> shipped ABI, with a two-sided control:
>
> ```text
> mediated(ctx, …) -> AiStepOutcome ! {AI, IO, Trace}   -- body: ctx.ports.ai_step(…)      ACCEPTED
> ambient (ctx, …) -> AiStepOutcome ! {AI, IO, Trace}   -- body: println + trace + ai.call ACCEPTED
>
> control: each of the two, declared one effect short   -> BOTH REJECTED, "Missing effects: Trace"
> ```
>
> The controls establish that the effect checker is running on both bodies and is sensitive to
> labels. It assigns the identical verdict to a fully port-mediated body and a fully ambient one.
> **A declared row cannot distinguish mediation from ambience, at any width, and a reconciled
> performed row cannot either — both are label sets.**
>
> **2. On fourteen of the fifteen registrable extensions, the slot's row constrains the binding in
> neither direction.** Derived from `src/core/ext/registry_generated.ail` at WI-D9, one binding site
> per extension, residue empty: **fourteen bind `on_pre_step` as an inline function expression in
> record-field position; one (`compaction_structural`) binds a named top-level function.** Measured on
> the shipped ABI record, an inline record-field binding's declared row is **inert** — it neither
> catches an effect the body performs and the row omits, nor discharges one the row names (see
> Amendment B). For those fourteen the operative constraint is `register_with_config`'s row, and `Env`
> is admitted by 14 of the 14 registration rows that exist (WI-D8).
>
> **Therefore criterion 2 may be established by measurement only by a producer with all four of the
> following properties, and no such producer exists at HEAD:**
>
> - **Provenance, not labels.** It must decide, for each effect a hook can perform, whether the call
>   that performs it is a field call on an `ExtPorts`-typed value. Per plan rule S16 it must not
>   derive from the declaration being tested, which rules out every row-reading instrument.
> - **Total over the extension, not over one file.** Criterion 2 quantifies over every hook an
>   installed extension registers, so the unit is the extension's transitive module closure — not the
>   module that happens to hold the hook's chain. (The claim currently recorded for `compaction_ai` at
>   `src/core/dst_driver_only.ail:597` is scoped to `compaction_ai.ail`; the hook is bound in
>   `register.ail`, which imports `std/env` and `std/fs`.)
> - **Symbol-granular.** Classifier 1 partitions **modules**, so `import std/ai (Message)` — a type
>   import — reads as effect-bearing. Criterion 2 needs the imported *symbol*, or every extension
>   touching a type from an effect-bearing module fails.
> - **Fail-closed on what it cannot resolve**, on classifier 2's discipline: every alias, wrapper,
>   re-export and computed access it cannot resolve to a typed receiver is a rejection, not a pass.
>
> **The producer this describes is not the successor detector and is not blocked by the record-field
> limitation**, because it is structural — an import-and-call-name closure — rather than type-based.
> It is most of obligation 2 clause 2, which this ADR specifies ("a conservative textual inventory of
> ambient-effect imports and call names, per in-profile module, at *site* granularity") and which is
> **built only in its module-classification half**: `tools/effect-inventory/derive.py` emits module
> sets repo-wide and no per-module site enumeration. Call it **classifier 3** and give it the same
> status row the other three carry.
>
> **Until classifier 3 exists and reports clean for an extension, criterion 2 is evaluated on declared
> rows and no profile may record `WorldMediated` on any other basis.** That is the fail-closed
> default and it is what keeps this amendment from licensing a claim its evidence cannot support.
>
> **When it exists, three things change and each must be decided rather than inherited:**
>
> - `HookClassificationEntry` (`src/core/dst_profile.ail:207`) gains a **basis** — the producer that
>   established the classification and the artifact revision it ran at. A measured `WorldMediated` and
>   a read one are different claims and today the record cannot tell them apart.
> - The **barrier count changes shape.** `check_barrier_count`
>   (`tools/profile_definition/check_fixtures.py:205`) derives barriers from the ABI row alone, which
>   is a per-**slot** fact shared by all fifteen extensions; criterion 2 is per-hook-of-an-installed-
>   extension. A measured basis makes a barrier a property of the **(extension, slot)** pair. The
>   count is derived, so this is a change to the derivation, not to a number.
> - **Route B becomes sufficient rather than merely necessary.** With `compose`'s `FS`/`Process` and
>   `context_mode`'s `Process` routed through world-mediated `ExtPorts` seams, classifier 3 would
>   report those extensions ambient-free and the remaining two barriers would clear on the same basis
>   as `on_pre_step`. **Without this amendment Route B clears no barrier**, because the routed rows
>   would read `{Process, FS}` and be refused for exactly the reason `on_pre_step` is refused now.

---

## Amendment B — the record-field paragraph's repro does not reproduce on the ABI

*Proposed replacement for `ADR-001:1398-1418`. **Every conclusion in that passage survives.** What
changes is the mechanism, and the mechanism is load-bearing for three separate decisions.*

The passage states that the effect checker "is **not** transitive through a call on a
function-valued record field", gives this repro, and concludes "`ExtCtx.ports: ExtPorts` is exactly
that shape, and a field call is the only way an extension reaches a port at all":

```text
type Ports = { ai_step: (string) -> string ! {AI, IO, …} }
func rowless_hook(p: Ports) -> string { p.ai_step("…") }   -- declares no row
$ ailang check → ✓ No errors found!
```

**Measured at WI-D9: the repro reproduces, and its stated consequence for the ABI is false. The
non-transitivity is a property of a LOCALLY DECLARED record type. Through an IMPORTED one it does not
hold.**

```text
local  `type Ports = { ai_step: … ! {AI, IO, Trace} }`,  rowless caller  -> ACCEPTED
import `pkg/sunholo/motoko_ext_abi/types (ExtPorts)`,    rowless caller  -> REJECTED
                                          Effect checking failed for function 'rowless_calls_ai_step'
                                          Missing effects: AI, IO, Trace
```

Bisected to one variable: an imported `ExtPorts` nested in a locally declared record still propagates;
a local copy of `ExtPorts`' `ai_step` field with the identical imported result type does not.

**What actually bites this tree is a different gap, and it is the one WI-D8 measured: a lambda bound
into a record field has an INERT declared row.** Confirmed at WI-D9 on the shipped `ExtPorts` record,
both directions:

```text
inline `ai_step: func(…) -> AiStepOutcome ! {AI, IO, Trace} { … getEnvOr(…) … }`
  -> Env escapes past the row to the enclosing builder      (the row catches nothing)
inline `ai_step: func(…) -> AiStepOutcome ! {AI, IO, Trace} { … println(…) … }`
  -> IO ALSO escapes, though the row DECLARES it            (the row discharges nothing)
control: the identical body as a NAMED top-level function
  -> REJECTED at the function itself, "Missing effects: Env"
```

**Consequences of the correction, and none of them reverses a decision:**

- **`ADR:1415`'s "a rowless ABI slot is not provably effect-free" STANDS**, by the inert-row
  mechanism rather than by call non-transitivity: an inline binding in a rowless slot can call
  `ctx.ports.ai_step` and the demand escapes to `register_with_config`. A *named* binding in a rowless
  slot cannot — it is rejected.
- **`ADR:1419-1425`'s rejection of the narrowing to five non-rowless hooks STANDS**, and its premise
  needs one qualifier: "a rowless hook *can* call `ai_step`" is true of an inline binding and false of
  a named one. Fourteen of fifteen extensions bind inline, so the coarse rule is still the right one.
- **WI-D8's chain measurement STANDS and is stronger than it looked.** `summarize_attempt`'s
  `! {AI, IO, Trace}` is a genuine body verdict: its only effectful call is `ctx.ports.ai_step` on the
  imported ABI, and that call does propagate. A first draft of this amendment claimed the chain's
  fixpoint was an unchecked annotation; the imported-versus-local distinction refuted it.
- **The upstream filing `fb_74f53de3ae65854c` is VALID and NARROWER than the ADR applies it.** The
  local-type repro is a real unsoundness and stays filed. What is not covered by it is the inert
  inline row, which is the gap that reaches every hook in this tree. **Not filed here — WI-D9's scope
  excludes filing — and recorded as owed.**

---

## Reviewers this needs

Named by role, because the amendment's risk is concentrated in three places and each has a different
owner:

1. **Both ADR-001 acceptance reviewers**, for Amendment A's status-table row. Adding classifier 3 to
   *Gate mechanisms: built, and deferred* adds a **fourth** deferred mechanism to a list both
   reviewers signed off as finite, and both applied the test *"if this mechanism turned out
   unbuildable, would D1–D11 still be the right architecture?"* That test must be applied to
   classifier 3 before the row is added, not after.
2. **The owner of WI-C5**, for whom Amendment A is the precondition and whose cost estimate changes
   in both directions: Route B alone buys nothing, and Route B plus classifier 3 buys all three
   barriers.
3. **One reviewer independent of WI-D6/D7/D8**, for Amendment B. Those three items each banked the
   prize "a binding that starts reading `Env` in this slot now fails to build", and B says that prize
   is real at **1 of 15** `on_pre_step` bindings rather than at 7 of 15 as WI-D8 recorded. The
   reviewer should re-derive the binding-form split independently rather than read it here.

## What is deliberately NOT in this draft

- **Any change to criterion 1.** The ADR already records criterion 1's declared-row basis as an
  assumption; Amendment B supplies the correct mechanism for that assumption but does not widen it.
  Widening is an ADR-scope decision and WI-D9's handoff withholds it.
- **Any change to classifier 2's rule.** Checked: its predicate is derived from typed field *calls*
  by `tools/ext_call_inventory/derive.py`, not from declared rows, so it does not lean on the reading
  Amendment A tests. It is also the natural host for classifier 3 — same matcher, same fail-closed
  discipline, ambient symbols instead of `ExtPorts` fields.
- **Building classifier 3.** Named and specified here; building it is its own work item, and it is
  ordered *before* Route B rather than after.
- **The fourteen `register_with_config` rows.** They are where enforcement lives for inline bindings
  and they will matter to any measured classification. Measuring them remains its own item.
