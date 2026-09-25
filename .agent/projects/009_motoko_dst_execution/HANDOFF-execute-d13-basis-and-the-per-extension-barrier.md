# Handoff: WI-D13 — land `basis`, re-shape the barrier derivation, and decide what `compaction_structural` earns

Audience: a fresh session grounded against HEAD. Source-heavy work in `dst_profile.ail` and
`check_fixtures.py`, plus one criterion reading that is the item's real output.

**WI-D12 built classifier 3** — `make ext_ambient_inventory` and its selftest, both green, both in
`make dst`, `RESOLUTION 19/19`, **`PORT-MEDIATED (4 of 15)`** including `compaction_structural`.
Verified at review. **Zero AILANG source files changed; the barrier count is still three.**

**Read first:** `NOTE-d12-build-classifier-3.md` §8, then Amendment A's fail-closed default
(`ADR:1539`), then the acceptance reviewers' admission note §1 — the condition this item discharges.

## The finding: classifier 3's answer has nowhere to go

**The instrument now produces a per-extension verdict, and no artifact in this tree can hold one.**
Measured at review:

| Artifact | Shape | Consequence |
|---|---|---|
| `HookClassificationEntry` (`dst_profile.ail:207`) | `extension_id`, `hook_id`, `classification` — **three fields, no `basis`** | A *measured* `WorldMediated` and a *read* one are indistinguishable in the record |
| `check_barrier_count` (`check_fixtures.py:205`) | *"a slot is a BARRIER when it is unconditionally dispatched AND declares a non-empty effect row"* — reads the ABI row and the dispatch table, **nothing per-extension** | A barrier is a property of a **slot**, shared by all fifteen extensions alike |
| `compaction_structural`'s `pre_step` (`register.ail:23`) | declares `! {AI, IO, Trace}` | **Forced** — a named binding cannot declare narrower than its closed ABI slot |

So classifier 3 says `compaction_structural`'s closure is ambient-free, its hooks declare non-empty
rows because the ABI forces them to, and the count that decides installability cannot tell one
extension from another. **The measurement exists; the vocabulary to record it does not.**

## Mission

**Three things, in this order.**

1. **Land `basis` on `HookClassificationEntry`** — the producer that established the classification
   and the artifact revision it ran at. **This is the acceptance reviewers' explicit condition on
   classifier 3's admission**: it is due *"with or before any change that lowers the barrier count,
   whichever comes first."* It is owed regardless of what this item decides.
2. **Re-shape `check_barrier_count` to the `(extension, slot)` pair.** Amendment A names this as one
   of the three things that change when classifier 3 exists, and it is a change to the **derivation**,
   not to a number.
3. **Decide what `compaction_structural` earns, and on which criterion.** This is the item's durable
   output and it is a reading, not a build.

## The rule you will break by accident

**Criterion 1 was withheld from the amendment's scope, and `compaction_structural` most naturally
earns criterion 1.**

The acceptance reviewers recorded this in A-4's discussion and it is the trap: *"the classification it
would earn is criterion **1** in substance — effect-free by measurement, vacuously satisfying
criterion 2 — and the draft explicitly withholds criterion 1 from scope."*

- **Criterion 1** is *"deterministic and effect-free for its explicit inputs"*. Classifier 3 measures
  exactly that. **But criterion 1's basis is still the declared row**, which `ADR:1415` already calls
  an assumption, and `pre_step`'s declared row is non-empty and cannot be narrowed.
- **Criterion 2** is *"effectful only through D1 world-mediated ports, with explicit world state
  returned"*. An extension that performs **nothing** satisfies it vacuously, and
  `PreStepOutcome.next_state` is returned. **Amendment A's fail-closed default is discharged for this
  extension** — classifier 3 exists and reports it clean.

**So the honest answer may be "criterion 2, vacuously" — and a vacuous satisfaction is exactly the
thing this project has spent eleven items marking as vacuous rather than banking.** Four acceptance
rows already lean on an empty install list; **an installed extension whose coverage is vacuous
satisfaction of the wrong criterion would be a fifth**, and harder to see because it comes with a
non-zero number attached.

**Decide it explicitly against both criteria, record which and why, and if the answer is criterion 1,
stop** — criterion 1's basis was not reviewed and amending it is an ADR-scope decision the draft
deliberately withheld.

## The trigger, and it is armed

`check_barrier_count` **goes red at zero deliberately**, with the message *"the barrier count has
reached ZERO … That is WI-C5's trigger and it must be DECIDED, not inherited as a side effect of an
ABI edit."* Re-shaping the derivation to `(extension, slot)` can take the count to zero **for one
extension** without touching the ABI.

**That is the case the trigger was written for.** If the re-shaped derivation reports zero barriers for
`compaction_structural`, **stop and report** — installing it is a coverage claim with a profile
version bump and it is not this item's.

## What `basis` has to carry, and why prose will not do

**D11 measured that the fail-closed default is unenforced.** `classification_agrees`
(`dst_profile.ail:893-910`) validates a `WorldMediated` entry against the disclosure's excluded-id
list **and nothing else** — there is no check anywhere that a classification has an evidentiary basis.
**A profile author could write `WorldMediated` today and pass the gate**; what keeps it unreachable is
the barrier count, not the rule.

So `basis` is not bookkeeping. **It is the enforcement Amendment A's default currently lacks**, and it
should be validated: a `WorldMediated` entry without a recognised producer and revision is a
rejection, on classifier 2's fail-closed discipline.

## Definition of done

**`basis` landed and validated**, with a rejecting fixture and a resolving control — a validation that
only ever accepts cannot be told from one that does not run.

**`check_barrier_count` per `(extension, slot)`**, with its output naming the extension when a barrier
is cleared for one and not another. The global count stays derived and stays printed.

**A decision on `compaction_structural`, against both criteria**, with the reading recorded and the
vacuity named if it is vacuous. **If it earns criterion 1, stop and report** — that is out of the
amendment's scope.

**A profile version bump if any recorded claim changes**, per the precedent D2/D3/D4/D6/D7 set: a
claim change is a bump even when no anchor moves.

**Per S13 — both new behaviours inside `make dst`.** **Per S9 — sweep cache-cold with
`AILANG_RELAX_MODULES=1`, and clear the stdlib-adjacent cache too**, which S9's own sweep misses. Run
`make sync_packages` first — nine consecutive items. **Per S16 as WI-D12 extended it** — if you add
any scan, enumerate the ways a subject can reach what you are scanning for before choosing the unit.

## Out of scope

- **Installing `compaction_structural`, and the profile that would do it.** The next item, and the
  trigger above exists to stop this one taking it.
- **Criterion 1's basis.** The ADR records it as an assumption and the amendment withheld it.
- **Repairing classifier 1**, its zero-check, the `MOD010` addendum, and the unidentified producer of
  the stdlib-adjacent cache — which D12 made stranger rather than clearer.
- **The gate-table State column** — three of five rows say "Deferred" for built, green mechanisms.
  The acceptance reviewers'.
- **The ADR's "1 of 15" parenthetical**, which D12 measured as 0 of 15. Theirs too.
- **F3** (`head_inventory()` feeding `validate_completeness` its own output); Route B; WI-C5; the
  fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.

## Stop and report rather than deciding inline

- **If the re-shaped count reaches zero for any extension**, stop. See the trigger.
- **If `compaction_structural` earns criterion 1 rather than criterion 2**, stop — the amendment does
  not cover it and the reviewers withheld it deliberately.
- **If `basis` cannot be validated without a producer this tree does not have**, report which. Three
  producers exist now; a fourth requirement is a finding.

## Report back

Thirty-seventh calibration run.

- **The git wall-clock window.**
- **The criterion decision**, with both criteria addressed and any vacuity named. The item's durable
  output.
- **The re-shaped derivation's output**, per extension and globally.
- **`basis`'s validation**, and what it rejects.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **69 across
  thirty-six runs; determinism has caught none.** This item changes a record type and a derivation —
  the first source-shaped item in five — so the population is different from the last seven, which
  were claims and instruments.
- **Whether the global barrier count is still three.** If it is not, say what moved it and whether a
  profile acted.
