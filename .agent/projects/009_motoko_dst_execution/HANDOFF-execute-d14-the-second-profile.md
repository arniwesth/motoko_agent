# Handoff: WI-D14 — the second profile, and the first time the conformance machinery binds

Audience: a fresh session grounded against HEAD. Profile-machinery work; it should touch little
outside `dst_profile.ail`'s consumers and a new profile definition.

**WI-D13 landed `basis`, re-shaped the barrier derivation to `(extension, slot)`, and found FOUR
extensions at zero barriers** — `compaction_structural`, `decision_framework`, `empty_stop_guard`,
`progress_contract_guard`. Verified at review: `33 of 45 pairs stand`, slot-level count still 3,
`driver_only` v13 installing nothing, `basis` rejecting three ways with a loading control.

**D13 declined to install them**, on the ground that two of criterion 2's three clauses hold
vacuously and the coverage would be "a fifth vacuity with a number attached". **That pause was right
and the ADR has already ruled on what to do about it.**

**Read first:** `NOTE-d13-basis-and-the-per-extension-barrier.md` §2, then **`ADR:2545`** — the
acceptance table's row 3, whose final clause is this item's warrant.

## The finding: the ADR anticipated this exact profile and specified the remedy

Row 3's own text ends:

> …and the result reports per-extension covered/excluded hook **ids**, **so a profile covering only
> ABI-pure no-op slots is visible as such**.

**The ADR contemplates a profile whose coverage is entirely no-ops, and its answer is disclosure, not
refusal.** It was raised in review as R5 — *"the general floor can be satisfied by ABI-pure no-op
slots without covering extension behavior"* (`ADR:8819`) — and the disposition was that clause.

**So the question is not whether such a profile may exist. It is whether this one discloses honestly
enough that a reader cannot mistake it for extension-model coverage.**

## Mission

**Build the second profile: install the four cleared extensions, and make the no-op nature visible in
the result.**

**And the number is the least interesting part of it.** The reason to do this is:

> **Every clause of row 3 that quantifies over installed extensions has been VACUOUS for the entire
> project.** The coverage floor, the unconditional-hook rule, the classifier-2 rule and the
> per-extension id disclosure have never once bound over a non-empty set. **This is the first profile
> that would make them bind.**

Measured at review, all four should hold **non-vacuously** for these extensions — the floor (they
cover every slot), the unconditional-hook rule (they exclude nothing), the classifier-2 rule
(classifier 3 reports **zero** `ExtPorts` field calls for each), and the disclosure. **If any of them
does not, that is the finding and it is worth more than the profile.**

## The rule you will break by accident

**Per D10, additional profiles earn coverage separately — this profile earns all eleven acceptance
rows itself, from scratch, and inherits none of `driver_only`'s.**

`driver_only`'s eleven-row verdict is `driver_only`'s. Four of its rows lean on an empty install list
and **those four are exactly the ones that change here**. So:

- **Rows 3, 4, 5 and 7 must be re-earned**, and the reasons D5 recorded for them do not transfer.
  Row 4's `extension_effect_fault` waiver was *"waived by construction because driver_only installs
  none"* — this profile installs four. Row 5's transferability caveat named compose's unrouted clock
  reads as outside reach *only because nothing is installed*.
- **Do not run the whole table.** That is WI-C4's shape and it is a separate item. **Run the four rows
  that change**, report what they say, and say plainly that the other seven have not been re-earned
  for this profile.

**And the mandatory caveat still applies, with its wording adjusted rather than dropped.** D5's
sentence — *"the axis's extension-model coverage is ZERO"* — becomes false for this profile and must
not simply be deleted. **The honest successor is that the coverage is non-zero and entirely of
no-ops**, which is a weaker claim than a bare number implies and a stronger one than zero.

## What the disclosure has to achieve

Row 3 asks that a no-op-covering profile be **visible as such**. That is a property of the *result*,
not of a comment. So:

- **Per-extension covered/excluded hook ids**, which the row names explicitly.
- **`basis` on every classification entry** — landed at D13, validated three ways, and this is the
  first profile that will carry entries at all. `driver_only` has **zero** classification entries; this
  one has four extensions' worth.
- **The vacuity of criterion 2's clauses 1 and 2 recorded per entry**, not in prose beside the
  profile. D13 measured that both hold because nothing happens; a reader of the result should be able
  to see that without reading D13.

**Per S21 as D13 extended it: a vacuity with a number attached is the hard case.** The disclosure is
what makes this profile honest rather than a fifth place the emptiness hides.

## Definition of done

**The profile defined, loading, and validating** — with `make profile_definition` and its own
acceptance script green, and the four extensions installed with `basis` recorded per entry.

**The four changed rows re-earned or reported**, and the other seven explicitly not claimed.

**A statement of what the coverage number means**, in the result and not only in a note: non-zero,
entirely no-ops, and exercising none of the world-mediation machinery.

**The barrier count unchanged at the slot level.** This profile installs extensions that have zero
barriers; it does not clear a barrier for anything else. If the slot-level count moves, something was
edited that should not have been.

**Per S13 — the new profile's targets inside `make dst`.** **Per S9 — sweep cache-cold with
`AILANG_RELAX_MODULES=1` including the stdlib-adjacent cache**, and run `make sync_packages` first
(eleventh consecutive item). **Per S16 as D12 extended it** — if you add a scan, enumerate the ways a
subject can reach what you scan for before choosing the unit.

## Out of scope

- **WI-C5, the compose-bearing profile.** Compose has real effects, three barriers stand for it, and
  it needs Route B. **This item is not that**, and calling this profile the second profile does not
  discharge C5.
- **Route B** — world-mediated process and file seams on `ExtPorts`.
- **Re-running the full eleven-row table** for either profile. WI-C4's shape.
- **Criterion 1's basis** — the ADR records it as an assumption and the amendment withheld it. D13 hit
  that wall from the measurement side; it is still not this item's.
- Repairing classifier 1 and its zero-check; the `MOD010` addendum; the unidentified producer of the
  stdlib-adjacent cache; the gate-table State column; the ADR's "1 of 15" parenthetical; F3; the
  fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.

## Stop and report rather than deciding inline

- **If any of row 3's four installed-extension clauses fails for these extensions**, stop and report.
  Those clauses have never bound; the first thing they say is worth more than the profile.
- **If the coverage floor cannot be satisfied without claiming a hook covers something it does not**,
  stop. That is the floor doing its job.
- **If re-earning row 4 or row 5 for this profile changes an answer `driver_only` recorded**, report
  it — `driver_only`'s verdict is its own and must not move, but a disagreement between two profiles
  over the same evidence is a finding.

## Report back

Thirty-eighth calibration run.

- **The git wall-clock window.**
- **Whether row 3's four installed-extension clauses bound, and what they said.** The item's durable
  output — more so than the profile itself.
- **The four changed rows' answers for this profile**, with the seven unclaimed named as unclaimed.
- **What the coverage number means**, in the result's own words.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **69 across
  thirty-seven runs; determinism has caught none.** D13 was the first source-shaped item in five and
  found none; this one is source-shaped too, and its near-miss population is profile records and
  validation rules.
- **Whether the slot-level barrier count is still three.** It should be.
