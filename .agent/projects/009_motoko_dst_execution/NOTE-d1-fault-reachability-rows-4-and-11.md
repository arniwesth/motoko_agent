# WI-D1 — fault reachability. **Rows 4 and 11 CLOSE. The register is empty.**

Twenty-fifth calibration run, and the first item of the post-gate work list. Written against HEAD
`6e9848f`, branch `arniwesth/mot-64-close-acceptance-rows-4-and-11`.

## Window

**~2h05m** wall-clock: `2026-08-05T14:16Z` → `2026-08-05T16:21Z`. Grounding was clean: `git status`
clean at `6e9848f`, and the handoff's branch name matches the branch for the first time in three
items.

## THE ANSWER

**All four unreached classes are reached by search. The unreachable register is EMPTY.**
`make corpus_pr` is green **on the wider expected set** — nine expected classes, nothing subtracted —
and every one of them is OBSERVED rather than declared.

| Class | Seeds of 260 reaching it | Bank witnesses |
|---|---|---|
| `provider_error_retryable` | 18 | 17, 20 |
| `provider_error_non_retryable` | 23 | 3, 36 |
| `provider_partial_stream_then_error` | 91 | 5, 9 |
| `provider_protocol_inconsistent_result` | 49 | 14, 17 |

## The `retryable` binding — DECIDED, and it is the item's durable output

**Derived from `error_code`, not carried beside it.** The vocabulary and the derivation live in
`dst_fault_catalogue` (`provider_error_codes_retryable` / `_non_retryable`,
`provider_error_is_retryable`, `provider_fault_class_id`), and `dst_generator` **imports** them
rather than restating them — the one non-std import that module has ever taken.

**Why not the fifth `ScriptedStep` field.** Not the ~22 literal sites; those are cheap. It is that
`retryable` would then have to travel in `encode_provider_outcome` / `decode_provider_outcome` — a
field a replay cannot restore is a fault that replays as a *different* fault while every count still
balances — and that codec is **D8's persisted artifact surface**, which the handoff reserves as a
stop-and-report. `error_code` already round-trips through both codecs and through `ext_world`'s world
token, so the distinction between the two classes survives replay with **no codec change and no
compatibility surface touched.** Row 9 stays green.

**The objection the handoff raised — "a derivation puts the truth in a second place" — is answered by
where the derivation lives, not waved away.** There is exactly one list of codes. The version of the
derivation the objection is actually about is one where the generator invents its own code strings,
and that is not the version built. It is also the more faithful model: `recovery.ail` already says
retryability *is* a function of what went wrong, and a separate bool would let a scripted world serve
`E_PROVIDER_CONTEXT_LENGTH` marked retryable, which no provider can do and nothing would catch.

Unrecognised codes classify **non-retryable**, deliberately: a world that does not know whether an
error is transient must not manufacture a retry, and that is also the direction a gate can see — the
class then goes unreached and `corpus_pr` reddens.

### Do the two classes reach different production branches? **YES, and it is gated.**

```
✓ the two provider error classes reach DIFFERENT branches:
    retryable→stream_error_retry×4, non-retryable→provider_failure_finalize×7,
    and NO retry carries a non-retryable code
```

Both halves are read off the **wire**, out of the recorder's reach, and the non-retryable side is
discriminated by the error message rather than by `finish_reason` alone. The code lists are read out
of `dst_fault_catalogue` by `awk` rather than restated in the Makefile, and an unreadable list is a
red rather than an empty pattern that matches everything — proven (M6 below).

## THE FINDING: a production defect, and it is S12's exact shape

**`session.c2_loop`'s unretried-provider-failure branch finalized from `st.world_state` — the world
the STEP WAS ENTERED with — rather than from `exchange.next_state`.** The provider call happened; the
recording adapter appended an interaction for it and advanced the script cursor past the entry it
served. Finalizing from the entered world discarded both, so **a run ended having recorded one fewer
request than it made** — under-recording, on the one path where the run is over and nothing
downstream can notice.

This is the defect **WI-B2b named and could not instrument** — *the decision falls back; the world
must not.* B2b said plainly that a real instrument "needs a counter the token does not carry". The
instrument turned out to be a fault class.

**Measured, not argued.** Over a 260-seed sweep the wire carried **75** provider-failure finalizes
and the interaction logs carried **zero** `provider_error_non_retryable` records. The retry branch
immediately above — same fault, same recorder, threading `exchange.next_state` — recorded its own
class on 6 seeds of the same sweep. **Two arms of one match, differing in this expression and in
nothing else.** After the fix: 0 → 23 seeds, and three other classes rose as their truncated logs
came back (partial-stream 31 → 91, malformed-args 42 → 49, approval_denied 82 → 111).

**Two sibling sites are NOT fixed and are reported instead.** `SealSystemPromptEmpty` and
`SealExhausted` discard `chain.next_state` the same way, ~100 lines above, and violate a rule this
same file states twenty lines below them (*"WI-B2b: `chain.next_state`, not `st.world_state`"*). No
profile in this tree reaches either branch, so the edit would be unexercised by every gate here.
Named in `ports.ail` beside the mapping and owed.

**The edit is line-count-neutral on purpose (S18).** The four routed clock anchors sit below it;
`make anchors` is green and **no `driver_only` re-issue was needed.** The reasoning that would have
moved them lives in `ports.provider_outcome_record`'s note instead. This is the first item in four to
avoid the cascade rather than pay it.

## Two artifacts fired that had never fired before

**1. D8's generator canary — its first real firing.** Built at WI-C5 and never red on a change it was
not shown deliberately. It reported
`generator-trajectory-reshaped-without-a-version-bump` and
`generator-choices-remapped-without-a-version-bump` at all three seeds at both versions — **six
findings — and NOT `generator-seed-remapped`**, which is exactly right: `seed_state` was untouched, so
only the layers above it moved. **The three quantities said WHICH layer moved without anyone having to
guess.** Re-swept (942678 qualifying triples of 260 seeds) and re-pinned by hand to seeds 1/5/7, with
the trajectory-coverage preference re-applied: seed 1 draws 97 (max), seed 5 draws 22 (min), seed 7
draws 50. No regeneration path was added; the sweep script was deleted.

**2. `seeded_generator`'s S7 obligations, on both halves at once.** Axis H went red because seed 94's
surviving fixture no longer reached `tool_ok` at all and its quantities collapsed; axis E/F/G went red
on seed 9 with three witnesses at zero. Re-swept and re-pinned to **77** (richest of four survivors)
and the pair **132/176**. **The new pair is strictly better than the old**: 21 interactions against
14, with non-zero tool dispatches, approval reads and served approvals on both halves, so the
anti-count control now stands on a pair that exercises every class rather than on the smallest pair
that happened to tie.

**And the bank moved entirely — not one of the twelve seeds survived.** That is the two-witnesses rule
earning itself: WI-D1 is precisely the generator drift it was written for, and a single-witness bank
would have lost classes silently.

## Mutation results — six, and the fifth is the one that matters

Restored by `cp` throughout (S17); tree verified green after each.

| # | Mutant | Result |
|---|---|---|
| M1 | `provider_error_is_retryable := true` | RED — `provider_error_non_retryable` never observed |
| M2 | `provider_error_is_retryable := false` | RED — `provider_error_retryable` never observed |
| M3 | revert the world threading to `st.world_state` | RED — *"declared but never observed: provider_error_non_retryable"*, and **only** that |
| M4 | recorder writes `OutcomeOk` / blank class on a fault | RED — three classes unobserved |
| M5 | **driver ignores `e.retryable`** | **in-process suite COMPLETELY GREEN; wire gate RED at 10 leaked retries** |
| M6 | the code vocabulary becomes unreadable | RED, fail-closed |

**M5 is S16's shape and it is why the wire gate is not redundant.** With the driver reading `true`
instead of `e.retryable`, every class-reached counter still reads 9 of 9, every in-process row is
green, and the two error classes are **one scenario recorded under two names** — because the recorder
derives the class from the code it served, not from the branch the driver took. The two producers are
genuinely different only across the process boundary. **This is exactly the failure the handoff
predicted — "if both scenarios reach the same branch, the classes are not distinguished however the
counters read" — reproduced deliberately, and it is caught.**

## Rows 4 and 11, re-answered against the ADR's text

**Row 4 — "Do injected faults reach production recovery code?" PASS.**

The row asks the corpus to reach every required class the profile does not waive. It reaches **nine of
nine**, with the two waived classes named with their conditions. And the row's own word is *recovery
code*, not *class*: the wire carries `stream_error_retry`, `provider_failure_finalize` and the
degraded-arguments dispatch alongside the five branches already counted, each from production code
that knows nothing about the interaction log. **The two provider error classes are gated to reach
different branches**, which is the clause a counter cannot answer.

**One qualification, stated rather than absorbed:** `provider_empty_terminal_response` is reached by a
CONSTRUCTED member, not by a seed — re-measured at 0 of 260 under the new generator, so the
construction's justification holds unchanged. The row does not require every class to be seed-reached
and this is recorded in both directions, but a reader should not take "nine of nine" as "nine by
search". It is eight by search and one by construction.

**Row 11 — "Is there actual search?" PASS.**

The one clause it failed was *"the fixed bank reaches every required non-waived fault class"*. It now
does. Everything else the row asks was already holding at C4 and still holds: declared minimums
accepted from measured cost (21 s against a 45 s ceiling), rotating windows proven non-frozen and
disjoint, class- and branch-reached counters kept separate, counterexamples retained with manifests.

**And one thing about the bank got strictly better, which the row is really about.** The previous bank
had a member (seed 195) that reached **every** sweep-reachable class by itself. The new one does not:
the most any single trajectory of 260 reaches is **five of eight**, and three seeds tie at it. **A bank
whose collective coverage exceeds any single member's is the shape D11 asks for**, and the previous
bank did not have it.

**Neither row was closed by narrowing anything.** The register went to zero *before* the work started
(S1), and it went to zero by classes being reached, not by classes being reclassified or waived.

## The rule the handoff warned about, and how it was handled

**Shrink the register FIRST.** The asymmetry is real: removing an entry is red at
`List.length(unreachable_by_search()) == 4`, but *adding reachability without removing the entry goes
nowhere* — the class stays out of `expected_bank_coverage()`, the bank is never asked to reach it, and
`corpus_pr` stays green over a red row. So the register was emptied and the pin moved to `== 0` as the
first edit of the item, `make corpus_pr` was confirmed red on exactly the four classes, and every
subsequent change was driven by that red. **The row that would have fired on a late register update
(`no member reaches a class the register calls unreachable`) never fired — because it could not, and
that is the point of doing it in this order.** It is now vacuous, kept, and says so.

## Stale recorded reasons: **SEVEN, not five**

The handoff named five and said the pattern predicts more. It does.

| # | Site | Named by handoff? |
|---|---|---|
| 1 | `dst_corpus.ail` — `provider_error_retryable`'s entry | yes |
| 2 | `dst_corpus.ail` — `provider_error_non_retryable`'s entry | yes |
| 3 | `dst_corpus.ail` — `provider_partial_stream_then_error`'s entry | yes |
| 4 | `dst_generator.ail` — "NO PROVIDER FAULT" | yes |
| 5 | `dst_generator.ail` — "NO PROVIDER LATENCY" | yes |
| 6 | **`dst_fault_catalogue.catalogue_coverage_gaps()`** — the partial-stream gap | **no** |
| 7 | **`dst_run_report.ail:45`** — "`ScriptedStep` has no latency or error channel" | **no** |

**All seven carry the same false clause and all seven are corrected.** Six say a field does not exist;
both fields have existed since WI-B2b. The seventh is the same claim about the latency field.

**Two of the seven were only HALF stale, and both halves are now restated in terms of what is actually
missing** rather than deleted:

- **The latency notes (5 and 7).** `advance_ms` exists, so the field was never the obstacle. What is
  missing is the **recorder**: a generated provider latency needs a recorder that can see it, and
  `check_discovery`'s clock balance is right to refuse one that cannot. WI-D1 therefore leaves every
  generated entry at `advance_ms: 0`, faulted or not — the fault needed no clock advance, and giving
  it one would have coupled this item to D4's latency pair through a gate that is red for a good
  reason. **`clock-balance` never went red; the trap was avoided rather than survived.**
- **The partial-stream gap (6).** The class is reached now, but a *genuine* residue remains and it is
  narrower again: the generated partial stream is a **prefix of a well-formed one**, so the driver
  consumes chunks it would have consumed anyway. An adversarial partial stream — emissions the error
  then contradicts — has no generator. That is the streaming form of the inconsistency the
  `provider_protocol_inconsistent_result` gap already describes for a completed result, and the entry
  now says so.

**And the eighth reason was accurate.** "The generator's `tool_args` are always well-formed JSON,
measured 0 of 260" was true, and it is the one entry of the four whose text named what was actually
missing. Worth recording: the entry written from a **measurement** survived; the three written from an
**inspection** did not.

## Sites where two answers type-checked and one was silently wrong

**This item wrote production code and authored none.** Every alternative that type-checked was caught
by a gate landed before the change (S1) or by a gate that already existed.

**It FOUND one, pre-existing, and it is the largest single one this project has recorded:**
`c2_finalize(st.provider, st.world_state, ...)` on the unretried-failure path. Both `st.world_state`
and `exchange.next_state` type-check, both run, both keep every existing count balanced, and the wrong
one silently truncates the recorded program on a terminal path. **It had been wrong since WI-B2b and
was invisible to every gate in the tree until a fault class needed that log entry.**

**The counter is 52**, from C4's 51, attributed to WI-B2b and recorded at WI-D1 because that is when it
became visible — the same convention C4 used. **Determinism has still caught none of the fifty-two.**
Nor did any mutation gate catch this one on its own: it was caught by a *class census reading zero*
where it should have read a number, which is C4's absent-tick rule (S19) in a new medium — **an absent
count is a signal exactly as an absent tick is.**

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 225 pass / 17 fail of 242.** Failing set
  matches the expected seventeen **member for member**: 7 `TC_ARITY_001` smoke scripts, the
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable
  across B4, C1, C3, C5, C4 and now D1. Count is unchanged at 242 because the three sweep scripts this
  item wrote were deleted.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4, C1, C3, C4 and C5:** `test_coverage` and
  `test_coverage_selftest`, both pre-existing, attributed by B2a to module resolution in `ailang test`
  (`prompts_test.ail: 0/6` and the `stale_skip_record`). Every other target passes. **809 ✓ rows**
  against C4's 805 — comparable, because the methodology is unchanged between the two.
- **`make corpus_pr` — exit 0 at 21000 ms against a 45000 ms ceiling**, on the wider expected set.
- **`make anchors` — 10/10, unmoved.** No profile re-issue.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **`session.c2_loop`'s unretried-failure branch discarded the world the provider call advanced.**
   75 finalizes on the wire against 0 recorded classes, with the retry branch as the control. S12's
   named class, instrumented for the first time.
2. **`provider_error_non_retryable` was unreachable for that reason and no other**, and no recorded
   reason named it. Confirmed by M3: reverting the one expression leaves exactly that class
   unobserved.
3. **The wire gate is not redundant with the in-process suite** — M5 leaves the whole AILANG suite
   green while the wire goes red at 10 leaked retries.
4. **Seven stale reasons, not five**, and the two the handoff did not name were in the catalogue's own
   coverage-gap register and in `run_report`'s header.
5. **The entry written from a measurement survived; the three written from an inspection did not.**
6. **The canary's three-quantity design paid off on its first real firing** — it named the two layers
   that moved and excluded the one that did not.
7. **The old S7 pair (9, 13) was the weakest qualifying pair**, not the best: the re-sweep found one
   with non-zero dispatches, reads and served approvals on both halves.
8. **My first two class censuses were wrong because of a bad shell regex**, not because of the code —
   `(^|,)$c(,|$)` against `classes=ToolFailed,…` never matches a leading member. It reported
   `ToolFailed` at 0 of 260 and sent me looking for a defect in `world_tool` that was not there. Caught
   by instrumenting occurrence counts and finding 34 where the census said 0. **A measurement
   disagreeing with a plausible story is worth more than the story.**

**Decided — a human chose:**

1. **`retryable` is DERIVED from `error_code`, with the vocabulary in the catalogue and the generator
   importing it.** The codec change was the deciding factor, not the literal-site count.
2. **The partial-stream class falls out of two existing draws rather than a third of its own.** A
   dedicated draw could emit a chunked step whose recorded class disagreed with its own chunk list.
3. **No `retryable` field on `ProviderDecision` and no fault-choice constructor** — both would be a
   second representation of one fact, which is the same reason this module already gives for not
   returning `terminate` separately.
4. **Unknown codes are non-retryable** (fail-safe, and the direction a gate can see).
5. **Every generated entry stays at `advance_ms: 0`.** The latency pair is D4's and is still owed;
   coupling to it here would have reddened `clock-balance` for a good reason.
6. **The two sibling `st.world_state` finalize sites were reported, not fixed** — no gate here can
   exercise them.
7. **The `run_report` cluster-12 row now asserts distinct REASONS rather than distinct STATUS IDS.**
   Both surviving gaps are waived, so the status id no longer carries the difference and asserting on
   it would pass by being uniform. Same obligation, stated on the field that still carries it.
8. **The `required-class-not-covered` mutant was re-pointed at `approval_deadline_exceeded`.** It named
   `provider_error_retryable`, which WI-D1 made reachable, so the mutant stopped producing a rejection
   and the row went red saying so. **A mutation row that names a specific unreached class is
   self-reporting when that class closes** — that property is worth keeping, so it was re-pointed
   rather than replaced with something permanently unreachable.
9. **The empty register is kept as a function, not deleted.** The partition row still holds it against
   the catalogue in both directions, so a class added to D3's table lands in the expected bank
   immediately.

## Corrections owed to the plan

1. **S12 now has an instrument, and it is a fault class.** B2b shipped a comment-level mitigation and
   said so — *"a real instrument is an assertion that a component which performed a call did not return
   the state it was given, which needs a counter the token does not carry."* The counter it needs is a
   **recorded fault class that only exists if the world was threaded**. Any future S12-shaped site can
   be instrumented the same way: give the discarded world something to carry that a gate demands.
2. **S19 generalises from an absent TICK to an absent COUNT.** C4's rule reads a gate's success markers
   as an inventory. This item's central finding was a **class census reading zero** where the wire read
   75. Nothing was red; a number was absent. Suggested extension: *"a zero in a census is a claim, and a
   census with an independent producer is where you check it."*
3. **A stale reason written from a MEASUREMENT outlives one written from an INSPECTION.** Of the four
   register entries, the three that named a structural cause were all false within one item of being
   written; the one that quoted a number ("0 of 260") was still true four items later. **S15's
   practical form: when recording why something is unreachable, record the measurement, not the
   diagnosis.**
4. **The plan has no item after Milestone C.** WI-D1 is the first of C4's work list and was scheduled by
   handoff, not by plan. The list has three more entries (row 7's four pieces, row 10's filesystem
   class, and the `on_budget_plan` ABI change) and none is in the plan.
5. **A generator change is a five-artifact cascade and the plan does not say so.** Editing
   `choose_provider` re-dated: the corpus bank (12 seeds), the seeded-generator S7 fixture and pair, D8's
   canary at both versions, `run_report`'s declared register, and one mutation row. Every one of them
   went red and named itself, which is the system working — but an item that budgets for "add a draw"
   budgets wrong by about an hour.
6. **`ToolFailed`'s wire count is 6 and `ToolCorrelationMismatch`'s is 3** under the new bank. Both are
   above zero and both are lower than before. Not a defect — the bank is smaller per class because
   more classes share it — but the branch-witness counts are now thin enough that a future generator
   change could zero one, and the loop would then say so.

## Out of scope, unchanged and still owed

- **Row 7, the oracle row** — `d64_gap_register`'s thirteen. The largest remaining blocker, and the
  next item. Untouched here.
- **Row 10, hermeticity** — the filesystem world class for `resolve_context_limit`.
- **D4's provider latency pair** — the recorder half, restated above.
- **The two sibling `st.world_state` finalize sites.**
- **The adversarial partial stream** — the narrowed residue of gap 6.
- **The `on_budget_plan` ABI change** and everything gated on it.
- **THE NAME.** Rows 4 and 11 close; **rows 7 and 10 remain RED, so `driver_only` still does not adopt
  the "DST" or "simulation" name.** Nine consecutive items have declined it. Two of the four failing
  rows are closed and the gate's verdict is unchanged — which is what a four-row gate means.
