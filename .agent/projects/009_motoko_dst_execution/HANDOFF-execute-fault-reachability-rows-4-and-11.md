# Handoff: close acceptance rows 4 and 11 — provider fault reachability

Audience: a fresh session grounded against HEAD. Source-heavy work; you are that session.

**This is not a plan item.** WI-C4 ran the name gate on 2026-08-05 and returned **NO** with a work
list, and the plan records three planning defects behind that — the largest being that **the row
blocking the name had no scheduled producer.** This handoff schedules the cheapest piece of that list.
Milestone C's five items (C1–C5) are complete; nothing after them was ever planned.

**Verified at review of C4:** whole-tree sweep **225 pass / 17 fail** cache-cold with
`AILANG_RELAX_MODULES=1`, failing set matching the expected seventeen member for member; `make dst`
exit 2 with the same two red targets since B4. **Confirm tree state with `git status`.**

**Read first:** `NOTE-c4-name-adoption-gate-verdict.md` — rows 4 and 11 in particular — then the
plan's `## Standing rules`. **S19 is new and this item will be tempted to violate it.**

## Mission

**Make the four unreached fault classes reachable by search, and close acceptance rows 4 and 11.**

Both rows fail on the same clause: the bank reaches **5 of 9** required non-waived classes. The four
gaps are `provider_error_retryable`, `provider_error_non_retryable`,
`provider_partial_stream_then_error`, and `provider_protocol_inconsistent_result`. **Two of eleven
acceptance rows turn on this one item** — the best ratio left on the list.

## The finding that resizes the item: five recorded reasons outlived their cause

**Every recorded reason for these gaps says a field does not exist. Both fields have existed since
WI-B2b.** `ScriptedStep` at `ports.ail:81-110` carries `error_code`, `error_message` **and**
`advance_ms`. Meanwhile:

| Site | Still says |
|---|---|
| `dst_corpus.ail:975-977` | "`ScriptedStep` has no error channel, so a generated AIError has nowhere to be chosen into" |
| `dst_corpus.ail:979-980` | "the same missing `ScriptedStep` error case" |
| `dst_corpus.ail:984-986` | "ScriptedStep has no error channel, so no seed can produce a stream that fails part-way" |
| `dst_generator.ail:456-458` | "**NO PROVIDER FAULT** … `ScriptedStep` … has no error case" |
| `dst_generator.ail:460-462` | "**NO PROVIDER LATENCY** … `ScriptedStep` has no counterpart" |

**Five reasons, all false as written, and none of them gates anything** — the same class B4 found in
four artifacts and C1 found in seven prose records. **Correct all five as part of this item**, and do
not read them as the specification of what is missing.

**What IS missing is narrower and NO recorded reason names it:**

1. **`ScriptedStep` has no `retryable` signal**, and `AIError = { code, message, retryable }`. **The
   two error classes differ by exactly that bool** — `session.ail` branches on it through
   `should_retry_stream_error`, and the retry branch is the production recovery code row 4 demands be
   reached. **Without it, `provider_error_retryable` and `provider_error_non_retryable` are the same
   scenario twice.** This is the item's central binding: a field, or a derivation from `error_code`.
   A derivation puts the truth in a second place; a field is a `ScriptedStep` widening the generator's
   own note sizes at "roughly thirty literal sites". **Choose and record why.**
2. **Neither scripted `model_step` branches on `error_code`.** `stub_step.ail:247` and `:321` both
   wrap unconditionally in `Ok(scripted_to_step_result(s))`. **B2b wired the fault through the
   EXTENSION seam only** (`ext_world.ail`, which returns `Result[string,string]` and so never needed
   `retryable`). The core `Ports.model_step` path is untouched.
3. **`ProviderDecision` chooses the response only** (`dst_generator.ail:478+`), so there is nowhere in
   the generator for a fault to be selected even once the world can serve one.
4. **`tool_args` are always well-formed JSON** — measured 0 of 260 — which is the whole of
   `provider_protocol_inconsistent_result`.

## The rule you will break by accident

**Making a class reachable without shrinking the register is SILENT, and the register is what makes
the gate green.**

```ailang
expected_bank_coverage() = drop_ids(required_non_waived(fault_catalogue()), unreachable_class_ids())
```

`make corpus_pr` holds the bank to `expected_bank_coverage()` — required-non-waived **minus** the
registered-unreachable set. So today it is **green while row 4 is red**, and C4 established that is a
stricter-ADR finding rather than a gate defect.

**The asymmetry is the trap.** There is a pinned `List.length(unreachable_by_search()) == 4`
(`dst_corpus.ail:1228`), so *removing* an entry goes red and forces you to update. But **adding
reachability without removing the entry goes nowhere**: the class stays out of the expected bank, the
bank is never required to reach it, `corpus_pr` stays green, and **row 4 stays red with nothing saying
so.** You can do the entire generator change correctly and finish with no signal that it worked.

**So the order is: shrink the register FIRST and let the red drive the work** (S1 — land the
executable assertion before the change it guards). A class that leaves `unreachable_by_search()` must
land in `expected_bank_coverage()` and be *observed*, and the gate already asserts
`every expected class was OBSERVED (declared ⊆ observed)`.

## Two further traps, both already documented in the tree

**Clock balance will go red if a fault advances time the recorder cannot see.** `dst_generator.ail`
warns about exactly this for latency: *"a generated provider latency would have to be advanced by the
generating adapter and recorded by a recorder that cannot see it, which `check_discovery`'s clock
balance turns red immediately — correctly, since the log would then account for less time than the
world spent."* The same applies to a fault carrying `advance_ms`. C5 measured that the scripted
adapter **already** trips `clock-balance` on the real-run bridge, so this surface is live.

**Replay must restore the fault, or discovery and replay diverge** — and row 9 currently passes, so
breaking it costs a green you already have. `advance_ms` is restored on replay from
`TimedOutcome.advance_ms` with no codec change; the fault needs the equivalent treatment, and
`dst_replay.ail`'s fixtures already carry `error_code` at `:949`, `:1021-1022`, `:1052`.

**Per S19 — the new rows must not report by `cmd && echo "✓"` in non-terminal position.** That form
swallows the status under `set -e` and printed a false green over a red test for two items. Use
checked commands.

## Definition of done

**All four classes reached by search**, with the register shrunk to match and the bank observing each
one. `make corpus_pr` green **on the wider expected set**, not on a narrowed one.

**The `retryable` binding chosen and recorded**, with the two error classes producing genuinely
different production paths — one reaching the retry branch and one not. **If both scenarios reach the
same branch, the classes are not distinguished and the row is not closed**, however the counters read.

**All five stale reasons corrected**, and any that remain true restated in terms of what is actually
missing rather than what has since been built.

**Rows 4 and 11 re-answered against the ADR's text**, not against the gate's narrower contract — the
distinction C4 drew, and the reason the gate was green over a red row.

**Per S13 — a whole-tree sweep cache-cold with `AILANG_RELAX_MODULES=1`**, failing set confirmed
member-for-member. **Per S9 — clear EVERY live `.ailang/cache`, and leave `~/.ailang/cache/registry`
alone**; it holds installed registry packages. **Per S17 — mutation loops restore by `cp`, never
`git checkout`.**

## Out of scope

- **Row 7, the oracle row** — closing `d64_gap_register`'s thirteen. The largest remaining blocker and
  the next item after this one. Do not append trace records here.
- **Row 10, hermeticity** — the filesystem world class for `resolve_context_limit`.
- **The `on_budget_plan` ABI change** and everything gated on it: compose's install, its eight clock
  reads, `proc_exec`/`env_get` widening, and three of the thirteen register variants.
- **THE NAME.** Rows 4 and 11 are two of four. **No target adopts "DST" or "simulation"** — eight
  consecutive items have declined it and this one closes at most half the remaining gap.
- The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If adding `retryable` to `ScriptedStep` cascades past the ~30 literal sites the generator's note
  predicts**, report the real number before continuing — that note is itself from the era whose other
  claims turned out stale, so treat its sizing as unverified.
- **If a fault cannot be replayed without a codec change**, that touches D8's compatibility surface
  and is a stop-and-report, not an inline decision.
- **If making a class reachable turns `clock-balance` red**, report the sequence before repairing it.
  C5 measured that finding as an adapter property rather than a driver defect, and the same
  distinction may apply here.

## Report back

Twenty-fifth calibration run, and the first item of the post-gate work list.

- **The git wall-clock window.**
- **The `retryable` binding**, and whether the two error classes reach different production branches.
  This is the item's durable output; the counters are downstream of it.
- **Rows 4 and 11 re-answered**, against the ADR's text.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **51 across
  twenty-four runs; determinism has caught none**, and C4's was found by an *absent* success line
  rather than by a red one.
- **How many recorded reasons you found stale.** Five are named above; the pattern says look for more,
  and the count is itself a measurement this project now tracks.
