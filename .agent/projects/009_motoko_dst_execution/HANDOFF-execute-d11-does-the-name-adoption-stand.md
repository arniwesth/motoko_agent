# Handoff: WI-D11 — does the name adoption stand?

Audience: a fresh session grounded against HEAD. **This is a determination, not a build.** It should
touch almost no source. Its output is an answer with its evidence, and — if the answer is no — a
remedy proposal rather than a remedy.

**Read first:** `NOTE-acceptance-reviewers-classifier-3-admission.md`, then
`NOTE-d5-acceptance-table-rerun-and-name-decision.md` (the adoption itself), then **`ADR:2463-2469`**
and **`ADR:20-26`** — the two passages this item is about.

## The question

**The ADR now says the name turns on five mechanisms, four unbuilt and one failing. The name was
adopted on 2026-08-06.** Both statements are in the same document.

`ADR:2463-2465`:

> **None of the four deferred mechanisms blocks acceptance of this ADR.** They block the *name*: D5's
> routing audit is not citable as name-adoption gate evidence until each is built and passes its
> criterion above. **Classifier 1 blocks the name too** … so the name turns on five mechanisms, of
> which four are unbuilt and one is built and failing.

And `m-motoko-dst-framework.md` records, publicly: *"The unqualified 'DST' / 'simulation' label is
**ADOPTED** for the generated axis as of 2026-08-06."*

**Determine which is right.**

## The finding that makes this urgent rather than pedantic: it predates the governance act

**Verified at review: this contradiction is not new.** At the ADR state WI-D5 read (`5ecd858`), the
same sentence already stood with "three" in place of "four":

> None of the **three** deferred mechanisms blocks acceptance of this ADR. They block the *name*: D5's
> routing audit is not citable as name-adoption gate evidence until each is built and passes its
> criterion above.

**WI-D5 adopted the name anyway.** Its verdict section checks D10's two conditions — the acceptance
table, and project-007's ADR being accepted — and **does not mention this sentence at all.** Neither
did this reviewer's handoff, which named the two conditions and called the second "already satisfied".

**So the question is not whether the governance act broke something. It is whether the adoption was
sound when it was made**, and nobody has asked.

## What to determine, in order

**1. Are D10's conditions two or three?** D10's text names two — the acceptance test for a documented
baseline profile, and 007's ADR. The gate-mechanism sentence is elsewhere in the document and says
something narrower: that the **routing audit** is not citable as name-adoption gate evidence. **Decide
whether that is a third condition on the name, or a constraint on one class of evidence.** The whole
answer turns on this and it is a reading of the ADR, so read it rather than inferring it.

**2. If it is a constraint on evidence: do any of the eleven acceptance rows rest on that evidence?**
This is the substantive half and it is checkable. **Row 3** requires *"every profile-reachable hook is
effect-free, world-mediated, or explicitly excluded"* and **row 5** requires *"every time-bearing read
reachable in the profile is routed through the world clock — no residual direct `std/clock` read
survives the routing audit."* **Row 5 names the routing audit in its own text.** Work out, per row,
whether its evidence is the audit or a gate that stands independently of it.

**3. Note that `driver_only`'s own reasoning cites classifier 1 by name.**
`dst_driver_only.ail:597` argues `compaction_ai` reaches effects only through `ExtPorts.ai_step`
because its imports are *"every one of which classifier 1 derives as proven effect-free."* **That is
a live conformance claim resting on the mechanism now recorded as failing.**

## The rule you will break by accident

**"Classifier 1 is failing" is not a stable fact, and any determination resting on it inherits the
instability.**

Measured at review, and this is the sharpest thing to carry into the item: **three sessions ran
`make effect_inventory_selftest` on the same tree on 2026-08-06 and got three different answers** —
`agree=0`, `agree=1`, `agree=45`. The variable is a compile cache at
**`/home/motoko/.local/share/ailang/std/.ailang/cache/`**, which held 230 files written that day and
which **S9's sweep cannot reach**, because the sweep runs from the repository root and that path is
under `~/.local/share`. **Demonstrated two-sided:** clearing it takes the selftest `45 → 1`; restoring
the 230 files takes it back to `45`.

So **the gate measures the cache, not the tree** — and the reviewers' amended ≥90% criterion inherits
the defect, because its numerator is *modules `ailang iface` can resolve*, which is exactly what the
cache decides. **Before concluding anything about classifier 1's status, fix or bound the
measurement.** A determination about the project's headline claim must not rest on a number that
moved three times in one day.

## The reading to guard against, in both directions

**Do not conclude the name stands because it was already announced.** The as-built document is a
public record and its being written does not make it true. This project has corrected exactly that
shape twice — D6's "an extension is now installable" and D5's own superseded naming claim.

**And do not conclude it falls because a sentence says "blocks the name".** D5's verdict was reached
against the eleven-row table with every figure re-derived, and it was independently re-verified. **If
the answer is that the name does not stand, the reasoning must say precisely which row's evidence is
not citable and why** — a general appeal to the gate-mechanism sentence is the same move as reading
"blocks acceptance" onto acceptance, which the sentence explicitly disclaims.

## Definition of done

**An answer: the name stands, or it does not, or it stands qualified** — with the reasoning tied to
specific rows and specific evidence, not to the sentence in the abstract.

**Classifier 1's status measured under a stated cache precondition**, or the measurement declared
unbounded and the determination made without it.

**If the name does not stand:** a **proposal**, not an edit. `m-motoko-dst-framework.md` is the public
record and D5's supersession discipline applies — a withdrawal is dated, not deleted. **Whose pen it
is, is part of the proposal**; D10 was adopted by an execution item on a review's sign-off, and an
unwinding may need the acceptance reviewers.

**Per S15 — WI-D5's report is a historical record and is not to be re-dated.** If it was wrong, it was
wrong on 2026-08-06 and says so with that date.

**Per S13/S9 — sweep cache-cold with `AILANG_RELAX_MODULES=1`, and include the stdlib-adjacent cache
this time**, since S9's own sweep misses it. Run `make dst` in full; run `make sync_packages` first
(six consecutive items).

## Out of scope

- **Building classifier 3**, now admitted. The next execution item, and this determination does not
  block it.
- **Repairing classifier 1**, amending `derive.py`'s guard to a coverage check, and the `MOD010`
  addendum — all newly owed by the governance act and none of them this item's.
- **Wiring `effect_inventory` into `make dst`** — owed, and it is why the degradation was invisible.
- **The `basis` field on `HookClassificationEntry`** — the acceptance reviewers' condition on classifier
  3's admission, due with or before any change that lowers the barrier count.
- Route B; WI-C5; the fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.

## Stop and report rather than deciding inline

- **If the answer is that the adoption was unsound**, stop before touching the public record. That is a
  larger act than an execution item and the ownership question is real.
- **If a row's evidence turns out to rest on a mechanism nobody has connected to it**, report the
  dependency rather than resolving it — that is a finding about the acceptance table's structure.
- **If classifier 1's measurement cannot be bounded**, say so and make the determination without it,
  stating what that costs.

## Report back

Thirty-fifth calibration run.

- **The git wall-clock window.**
- **The answer, with per-row reasoning.** The item's durable output.
- **Whether D10 states two conditions or three**, quoted.
- **Classifier 1's status under a stated cache precondition**, or the reason none could be stated.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **66 across
  thirty-four runs; determinism has caught none.** This item writes almost no code; the last four
  came from claims and citations, which is what this one is made of.
- **Whether the barrier count is still three and the deferred count still four.** Neither is this
  item's to move.
