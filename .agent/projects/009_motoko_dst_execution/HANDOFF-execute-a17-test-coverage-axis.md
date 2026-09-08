# Handoff: execute WI-A17 — close the `ailang test` coverage axis

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**Cluster 10, and the actual last item in Milestone A.** WI-A15 landed 2026-08-04; `make dst` is exit
0 at **700 checks**. A15 was the last item on the *critical path* — A17 is off it, which is why it
went unassigned for ten clusters (cluster 14's correction 0). **When this lands, Milestone A is
complete** and the project is externally blocked on the upstream recorded-stream API.

**Read first:** the plan's `## Standing rules` — **S7 and S8 are the whole risk here**, and S8's
complement in particular. Then `NOTE-cluster-14-…`'s correction 0 for why this item exists at all.

## Mission

Close the second coverage axis. **`ailang check` coverage and `ailang test` coverage are separate
axes and only the first has a target.** `make check_core` type-checks `src/core/*.ail` and never runs
their inline tests.

The deliverable is **an inventory that fails when a file carrying inline tests is not run by any
CI-invoked target** — derived, not hand-maintained. A list of filenames is the defect, not the fix:
it goes stale the first time a file gains tests and nobody edits it, and it goes stale silently.

## The measured gap, taken at HEAD while writing this

**38 files under `src/core` carry inline tests. 25 are named by a `make` target. 14 are in none:**

| File | Tests |
|---|---|
| `step_machine.ail` | **17** |
| `tool_runtime.ail` | 12 |
| `ext/runtime.ail` | 8 |
| `tool_phase.ail` | 7 |
| `compaction.ail`, `recovery.ail` | 6 each |
| `config.ail` | 5 |
| `cost_phase.ail`, `tool_catalog.ail` | 4 each |
| `compress.ail`, `context_usage.ail`, `context_usage_test.ail` | 3 each |
| `model_phase.ail`, `tool_contract.ail` | 1 each |

Reproduce with:

```bash
grep -rlE "^\s+tests \[" src/core --include=*.ail | sort > /tmp/has_tests.txt
grep -oE "ailang test [^ ]+\.ail" Makefile | awk '{print $3}' | sort -u > /tmp/covered.txt
comm -23 /tmp/has_tests.txt /tmp/covered.txt
```

**All fourteen pass today** — I ran each one. So this is coverage that *exists and is not wired*,
not coverage that is broken. `step_machine.ail` is the one to note: 17 tests, and it is where the
max-steps discrimination lives that cluster 4 filed as an issue.

## The rule you will break by accident

**`scripts/probe_phase_vocab_sealed.ail` is a probe whose FAILURE is its PASS, and this plan tells
you to fix it.**

WI-A17's text says: *"Also fix or retire `scripts/dst/probe_phase_vocab_sealed.ail`, which fails at
baseline (`IMP010: symbol 'MkHistory' not exported`) and stayed broken precisely because it is in no
target."* **Two things wrong, and the second is dangerous:**

1. The path is `scripts/probe_phase_vocab_sealed.ail`, not `scripts/dst/`.
2. **It is not broken.** Its first line reads: *"This probe is expected to FAIL with IMP010:
   phase_vocab's sealed constructors must not be importable outside
   `src/core/phase_vocab.ail`."* It imports `MkHistory` and `MkPayload` deliberately, and the
   compiler refusing that import **is the sealing assertion holding.** Project 004's plan says so in
   as many words: *"`ailang check scripts/probe_phase_vocab_sealed.ail` still fails `IMP010`"* is
   recorded there as the pass condition.

Six cluster reports have carried it in their Traps sections as "pre-existing, unrelated, in no
target, WI-A17 owns it", and none checked what it asserts. **Making it compile inverts a sealing
invariant that has held since project 004.** Wire it in with its polarity inverted — the target
requires the check to **fail with `IMP010`**, and a *successful* compile is the failure.

That is also the shape to look for elsewhere: an item that sweeps "everything that isn't run" will
meet other artifacts whose contract is not "exit 0".

## Two traps specific to this axis

**`ailang test` exits 0 on a file with zero tests.** Verified: `ailang test src/core/version.ail`
prints a results banner and exits 0. So a target that runs `ailang test` over a file whose tests were
later deleted is **green and certifies nothing** — the vacuity shape D11's zero-window rule guards
against, arriving here. Assert the *count*, not the exit status.

**Cluster 13 moved an assertion OUT of `tests` deliberately, and your inventory must not punish it.**
`fb_2ad074d754cd2c25` — `ailang test`'s cluster harness fails non-deterministically at ~6/10 in large
modules — was worked around by moving a flaky assertion into an acceptance script under `ailang run`.
That is the correct response to a flaky gate, and it means **"fewer tests than expected" is sometimes
right.** An inventory that flags it produces a false positive, false positives get relaxed, and a
relaxed inventory is the hand-maintained list this item exists to avoid. Decide how the inventory
expresses a *deliberate* absence without becoming a list of exceptions.

## The decision this item owns

**How the inventory derives "carries inline tests" — because that derivation is the mechanism, and
S8's complement applies to it directly.**

The grep above (`^\s+tests \[`) is *a* derivation, not *the* derivation. A file whose tests use a
form the pattern misses **drops out of the inventory silently**, and a file that has dropped out
reads identically to a file that never had tests. That is the same failure as a pinned digest
certifying only the paths its trajectory walks.

So: whatever derivation you choose, **assert that it finds what you believe it finds** — cross-check
the derived count against something independent (the number `ailang test` itself reports per file is
the obvious candidate, and it is authoritative in a way a grep is not). Per S7, the fixture that
proves the inventory works is one that must **survive**: a file with tests, in a target, correctly
not flagged.

## Definition of done

**Every file carrying inline tests is run by a target CI invokes**, and the target **fails when one
of those tests fails** — demonstrated by breaking one, per S7, not asserted.

**The inventory fails closed on an unreferenced file**, demonstrated by adding a test to a file in no
target and watching it go red. This is the direction that matters: it is what stops the axis
re-opening the day someone adds a module.

**Test counts asserted, not exit statuses**, per the vacuity trap above.

**`probe_phase_vocab_sealed.ail` wired with inverted polarity** — the target requires `IMP010`.

**Every structural guard mutation-tested** (C5), each row asserting **its own rule** — cluster 14's
third mutant is the reason: dropping a member was caught by a length check, while *sampling one twice
and omitting another* kept the length identical and was caught only by membership-by-name. **A count
is satisfied by sampling one constructor twice.**

**Any grep-based Makefile guard anchored to a syntactic form** — cluster 14's site 31 is the fourth
item reminded: a guard greping `MOTOKO_DST_SCALE.*demo` matched the workflow's own comment explaining
that the string must not appear.

**`make dst` exit 0**, read as an exit status.

## Out of scope

- **Fixing any test this exposes.** If wiring a file in turns a target red, that is a finding to
  report, not to repair inside this item — all fourteen pass today, so a red one means something
  moved.
- **`src/tui`, `packages/**`, and scripts other than the sealing probe.** This item is the `src/core`
  axis; a wider sweep is a separate decision with its own cost.
- **Everything in Milestones B and C**, which are externally blocked.
- **The deferred items with named owners** — `max_resource_size` (a one-draw item), `seed_state`'s
  version axis, and the two `ScriptedStep` widenings. All belong to the Milestone B wave; see
  `HANDOFF-post-upstream-recorded-stream-landing.md`'s current section.

## Stop and report rather than deciding inline

- **If a file's tests fail once wired in**, stop and report which and why. That is a live defect that
  has been invisible, and it is worth more than this item's completion.
- **If the inventory cannot express a deliberate absence** without a list of exceptions, say so — the
  alternative may be to record the reason *in the file* and have the inventory read it, but that is a
  design decision this handoff is not making for you.

## Traps

**Run `make dst` and read `$?`** — seventh consecutive item. **Do not run other `make` targets
concurrently with it.** The single `✗` in a green log is the `✗ Failed: 0` summary label of a passing
`ailang test` run.

**A5 anchors: `stub_step.ail:161`, `session.ail`'s 948/1053/2290/2400; `driver_only` is v3.** Six
consecutive items have paid zero, and the cascade correlates with adding a **`StepProvider` variant**,
not with editing near an anchor. This item should touch neither file.

**Three filed AILANG defects with workarounds**, all in `.agent/issues/`: `fb_e44ba922db1c42be` (a
call in the field-value position of a record update is not a dependency — `let`-bind it; it has a
sibling in the head position of a cons), `fb_b39697480a4e8bbc` (an out-of-scope constructor name in
a pattern binds as a fresh variable), and `fb_2ad074d754cd2c25` (the flaky cluster harness, above).

Clear `.ailang/cache` before believing a contradicting type error. Never probe from `/tmp`. Pin is
v0.26.0.

## Report back

Fifteenth calibration run, and **the last of Milestone A**.

- **The git wall-clock window**, not a felt ratio.
- **Recorded bindings, split decided versus discovered.** The discovered count has predicted cost
  better than the total for four consecutive measurements.
- **Judgement ratio, split** machinery versus content.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Thirty-one across fourteen clusters; **determinism has caught none.**
- **Confirm Milestone A complete**, or say precisely what remains — cluster 14 found the milestone
  was one item short because a spawned item never acquired a cluster, and the completion sentence was
  inherited across three handoffs without anyone re-reading the map. **Check the cluster map's rows
  rather than the previous document's prose.**
