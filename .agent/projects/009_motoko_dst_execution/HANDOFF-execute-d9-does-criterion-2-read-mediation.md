# Handoff: WI-D9 — does D5 criterion 2 read mediation from evidence, or only from a row?

Audience: a fresh session grounded against HEAD. **This is a decision item.** It builds an argument
and, if the argument holds, an ADR amendment. It should touch very little source.

**I am revising the recommendation I gave after WI-D8.** I said Route B — world-mediating the process
and file effects on the extension surface — was next, because two of the three barriers are genuine
behaviour. **Grounding says Route B alone cannot clear a single barrier**, and the reason is the same
wall `on_pre_step` hit. This item settles whether that wall can be moved, because if it cannot, Route
B is a large build that ends where D6, D7 and D8 each ended: effects correctly handled, barrier count
unchanged.

**Read first:** `NOTE-d8-measure-ai-step-row.md`, then **`ADR-001:1284-1296`** (criteria 1 and 2
verbatim) and **`ADR-001:1396-1422`**, which is the paragraph this whole item turns on and which
nobody has cited since B4.

## The observation

**Criterion 2 is a claim about behaviour, and its text says nothing about declared rows:**

> 2. effectful only through D1 world-mediated ports, with origin tagged by extension id and explicit
>    world state returned to the host.

**The project has evaluated it against declared rows for eleven items.** That was correct while no
other instrument existed — and **the ADR says so itself**, at `:1398-1417`:

> **A declared row bounds performed effects in one direction only, and on the pin it does not bound
> them through function-valued record fields at all.** … **A rowless ABI slot is not provably
> effect-free.** Classifying `on_describe_tools`, `on_build_system_prompt`, and `on_tool_policy` as
> coverable is an **assumption**, resting on the runtime hermeticity probe rather than on the type
> system.

**So the ADR already records that criterion 1's declared-row basis is an assumption rather than a
proof — and it records it with D8's exact repro.** D8 met that gap fresh and called it the item's
biggest finding; it is in the ADR, and it was filed upstream at WI-A3 as `fb_74f53de3ae65854c`.

## The question this item answers

**Does criterion 2 admit a hook whose mediation is established by MEASUREMENT rather than by its
declared row?**

The instrument did not exist when D5 was written. **It exists now**, built across four items:

| Producer | Built at | Reach |
|---|---|---|
| Runtime capability trap, out of process | C5 | 7/15 on `on_budget_plan`; **0/15** on the three barrier slots |
| Effect checker over bodies | D6 | total over inputs, for **named-function** bindings |
| Per-step chain measurement to a fixpoint | D8 | `compaction_ai`'s whole chain: every step demands exactly `{AI, IO, Trace}` |

**And D8's measurement is the concrete case.** `on_pre_step`'s one performing binding reaches every
declared effect through a single call to `ctx.ports.ai_step` — a D1 world-mediated port — and returns
`PreStepOutcome.next_state`. **Criterion 2's substance is satisfied and measured.** What refuses it is
a row that cannot say *"these arrive through a port."*

## Why this must come before Route B, which is the revision

**Route B routes compose's `FS`/`Process` and `context_mode`'s `Process` through world-mediated
`ExtPorts` seams. Their declared rows would then say `{Process, FS}` — and be refused for exactly the
reason `on_pre_step` is refused now.**

So under the current reading, **Route B clears no barrier.** It is necessary — the effects must
actually be mediated before any criterion can admit them — but it is not sufficient, and doing it
first means paying the largest build in the project to arrive at an unchanged count.

**Under the alternative reading, Route B becomes the thing that finishes the job**, and
`on_pre_step` clears immediately and for free. **The reading is worth settling first either way.**

## The rule you will break by accident

**The instrument has the same gap the criterion does, and it is the reason this cannot be a blanket
amendment.**

D8 measured that AILANG **does not effect-check a record-field lambda's declared row** — reproduced
independently at review: a field declaring `! {IO}`, bound to a lambda performing `Env` and `IO`,
type-checks clean when the enclosing row absorbs both, while the *identical body* bound as a named
function is rejected. **Eight of fifteen `on_pre_step` bindings are inline lambdas.**

So "measured mediation" is:

- **strong** for a binding written as a named function — the effect checker reads the body, totally,
  over all inputs;
- **weak** for an inline lambda — its own row is unchecked, and the only constraint is
  `register_with_config`'s row, which admits `Env` in **14 of 14** cases.

**An amendment that says "criterion 2 may be established by measurement" without saying *by which
producer, over which binding forms* would license exactly the claims the instrument cannot support.**
That is the shape of every failure this project has counted: a rule whose evidence is weaker than its
wording.

## What a defensible amendment would have to say

Not for you to pre-agree, but the shape is constrained by the measurements already taken:

- **which producer establishes mediation** — and per S16, one that does not derive from the
  declaration being tested;
- **which binding forms it covers**, given the record-field gap, and what happens to the rest;
- **what a profile records**, since D5 already requires per-hook classification in the result and a
  measured classification is a different artifact from a read one;
- **how it fails closed** — the whole point of the declared-row rule was that it cannot be argued
  around, and any replacement inherits that burden.

## Definition of done

**The question answered, with the argument recorded either way.** A reasoned NO is a complete outcome
and it makes Route B's cost explicit before anyone pays it.

**If YES: an ADR amendment DRAFTED, not applied.** D5 is Accepted; per this project's own mandate,
corrections go through a normal amendment rather than an inline edit. **Draft it, name the reviewers
it needs, and stop.**

**If NO: say what that costs**, in one paragraph — Route B becomes necessary-but-insufficient, WI-C5
cannot complete, and the axis's extension-model coverage stays structurally zero until the ABI's
effect vocabulary can express mediation.

**Either way, do not touch the barrier count.** `make profile_definition` derives it and goes red at
zero; if this item moves it, something was edited that should not have been.

**Per S22 — derive any set you quantify over.** The binding-form split (named vs inline, per slot)
is a claim this item rests on, and D8 derived it: `on_pre_step` 7 named / 8 inline. Re-derive it;
do not take it from this handoff.

**Per S13/S9/S17/S19** — sweep cache-cold with `AILANG_RELAX_MODULES=1`; run `make dst` in full; clear
every live `.ailang/cache` and leave `~/.ailang/cache/registry` alone; check no other session is
running a gate; restore by `cp` or `tar`; read artifacts, not transcripts, and never `$?` after a pipe.

## Out of scope

- **Route B itself.** Whatever this item concludes, the build is a separate one.
- **Applying an amendment.** Draft only.
- **Filing the record-field gap upstream** — **already filed at WI-A3 as `fb_74f53de3ae65854c`**, with
  the repro in the ADR at `:1404-1410`. **Do not file it again**; D8 listed it as owed and it is not.
- **The fourteen `register_with_config` rows** — the sharpest un-owned item, and it is where
  enforcement lives for inline bindings. It will matter to any amendment, but measuring it is its own
  item.
- **The `motoko-ext-abi` major** — eight changed rows, deferred by D6, D7 and D8 on the correct ground
  that a lockstep re-release is a release act. **State the count; do not cut it.**
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds;
  `.packages/` staleness, which has now cost three consecutive items and deserves a gate.

## Stop and report rather than deciding inline

- **If the answer requires changing criterion 1 as well**, stop and report. The ADR already calls
  criterion 1's basis an assumption; widening that conversation is an ADR-scope decision, not this
  item's.
- **If a defensible amendment cannot be written without the `register_with_config` measurement**, say
  so and stop — that ordering is a finding, not an obstacle to work around.
- **If drafting the amendment reveals that D5's classifier-2 rule leans on the same reading**, report
  it. That rule is load-bearing for `driver_only`'s conformance and has never been re-examined.

## Report back

Thirty-third calibration run.

- **The git wall-clock window.**
- **The answer, with its argument.** The item's durable output, and WI-C5's precondition.
- **The amendment draft, or the reasoned refusal.**
- **The binding-form split, re-derived.**
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **62 across
  thirty-two runs; determinism has caught none.** This item writes little code; if it counts one, it
  will be in an argument rather than an expression, and saying so is more useful than a number.
- **Whether the barrier count is still three.** It should be. If it is not, say what moved it.
