# 2026-08-05 Cluster 25: WI-D1 — the four fault classes reached, and the world a terminal branch was throwing away

## Context

Branch: `arniwesth/mot-64-close-acceptance-rows-4-and-11`.

Session span: `6e9848f` → **`27951e7`, one commit, working tree clean**. (`54265aa`, cluster 24's
summary, landed between grounding and commit; it touches only `.agent/summaries/` and is unrelated to
this item's diff.) Input was `HANDOFF-execute-fault-reachability-rows-4-and-11.md`, executed cold
against HEAD. Twenty-fifth code session of project 009, and **the first item of the post-gate work
list — nothing after Milestone C was ever planned.** Pin **v0.33.0**.

**Window: ~2h05m**, `14:16Z` → `16:21Z`. Two long poles, both waiting: the S13 whole-tree sweep and
`make dst` (run twice). The single largest *unbudgeted* cost was the five-artifact cascade a generator
edit sets off — see "What resized the item" below.

**This is the mirror image of cluster 24.** C4 produced a verdict and no code; D1 produced 865 lines
of diff across eleven files and closes two of the four rows C4's verdict turned on.

| Definition-of-done item | State |
|---|---|
| All four classes reached by search, register shrunk to match | **met** — register EMPTY, 8 of 9 by search + 1 by construction |
| `make corpus_pr` green on the WIDER expected set | **met** — 9 expected classes, nothing subtracted, all OBSERVED |
| The `retryable` binding chosen and recorded | **met** — derived from `error_code`; recorded with the codec argument that decided it |
| The two error classes reach genuinely different branches | **met, and GATED** — retry vs finalize, read off the wire, with a leak check |
| All five stale reasons corrected | **exceeded** — **seven**, two of which the handoff did not name |
| Rows 4 and 11 re-answered against the ADR's text | **met** — both PASS, with the by-search/by-construction split stated |
| S13 sweep, cache-cold, `AILANG_RELAX_MODULES=1` | **met** — 225/17 of 242, member-for-member |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** — registry intact, no reinstall |
| S17: mutation loops restore by `cp` | **met** — six mutants, `cp` throughout, green after each |
| S19: no `cmd && echo "✓"` in non-terminal position | **met** — every new gate is a checked command |

## Grounding

HEAD `6e9848f`, tree clean, and **the handoff's branch name matches the branch for the first time in
three items.** Baseline captured before the first edit: `make corpus_pr` green at 31 s of a 45 s
ceiling.

## The result

**Rows 4 and 11 close. The unreachable register is empty.**

| Class | Seeds of 260 | Bank witnesses |
|---|---|---|
| `provider_error_retryable` | 18 | 17, 20 |
| `provider_error_non_retryable` | 23 | 3, 36 |
| `provider_partial_stream_then_error` | 91 | 5, 9 |
| `provider_protocol_inconsistent_result` | 49 | 14, 17 |

Full row-by-row evidence in `NOTE-d1-fault-reachability-rows-4-and-11.md`.

## The binding the item existed to choose

**`retryable` is DERIVED from `error_code`, not carried beside it.** The vocabulary and the derivation
live in `dst_fault_catalogue`; `dst_generator` **imports** them — the one non-std import that module
has ever taken — so there is exactly one list.

**The deciding factor was not the ~22 literal sites.** It is that a fifth `ScriptedStep` field would
have had to travel in `encode_provider_outcome` / `decode_provider_outcome`, because a field a replay
cannot restore is a fault that replays as a *different* fault while every count still balances. That
codec is **D8's persisted artifact surface**, which the handoff reserves as a stop-and-report.
`error_code` already round-trips, so the class distinction survives replay with **no codec change**
and row 9 stays green.

**The handoff's objection — "a derivation puts the truth in a second place" — is answered by where the
derivation lives, not waved away.** The version of the derivation the objection is about is one where
the generator invents its own code strings; that is not the version built. It is also the more
faithful model: `recovery.ail` already says retryability *is* a function of what went wrong, and a
separate bool would let a scripted world serve `E_PROVIDER_CONTEXT_LENGTH` marked retryable — which no
provider can do and nothing would catch.

## THE FINDING: a production defect, and S12 finally has an instrument

**`session.c2_loop`'s unretried-provider-failure branch finalized from `st.world_state` — the world the
step was ENTERED with — rather than `exchange.next_state`.** The provider call happened; the recording
adapter appended an interaction and advanced the script cursor. Finalizing from the entered world
discarded both, so **a run ended having recorded one fewer request than it made** — under-recording,
on the one path where the run is over and nothing downstream can notice.

This is the defect **WI-B2b named and could not instrument**: *the decision falls back; the world must
not.* B2b said plainly that a real instrument "needs a counter the token does not carry."

**The counter turned out to be a fault class.** Measured over a 260-seed sweep: **75 provider-failure
finalizes on the wire against ZERO recorded `provider_error_non_retryable` records**, with the retry
branch immediately above — same fault, same recorder, threading `exchange.next_state` — recording its
own class on 6 seeds of the same sweep. **Two arms of one match, differing in this expression and in
nothing else.** After the fix: 0 → 23 seeds, and three other classes rose as their truncated logs came
back (partial-stream 31 → 91, malformed-args 42 → 49, approval_denied 82 → 111).

**Two sibling sites were reported, not fixed.** `SealSystemPromptEmpty` and `SealExhausted` discard
`chain.next_state` the same way and violate a rule the same file states twenty lines below them. No
profile in this tree reaches either, so the edit would be unexercised by every gate here.

**The cascade was avoided rather than paid.** The edit is line-count-neutral (S18) and the reasoning
lives in `ports.provider_outcome_record`'s note; `make anchors` is 10/10 unmoved and **no
`driver_only` re-issue was needed.** First item in four to dodge it.

## The mutant that matters

Six mutants, restored by `cp` (S17), tree verified green after each. Five behave as expected. **M5 is
the one worth carrying:**

> Make the driver read `should_retry_stream_error(true, …)` instead of `e.retryable`.
> **The entire in-process AILANG suite stays GREEN — every class-reached counter still reads 9 of
> 9 — while the wire gate reddens at 10 leaked retries.**

Because the recorder derives the class from the code it *served*, not from the branch the driver
*took*, the two error classes become **one scenario recorded under two names** and no in-process check
can see it. **This is S16's shape and it is exactly the failure the handoff predicted** — "if both
scenarios reach the same branch, the classes are not distinguished however the counters read" —
reproduced deliberately, and caught only by the out-of-process gate.

## What resized the item: a generator edit is a five-artifact cascade

Adding two draws to `choose_provider` re-dated every choice after them, because `draw` threads
`g.rng`. Five artifacts went red, **each naming itself correctly**:

1. **The corpus bank** — all twelve seeds. Re-swept and re-derived; **not one survived.**
2. **`seeded_generator`'s S7 fixture and equal-census pair** — both obligations at once.
3. **D8's generator canary**, at both versions.
4. **`run_report`'s declared coverage register.**
5. **One mutation row** (`required-class-not-covered`), which named a class this item made reachable.

**Two of these had never fired before.** The canary reported six findings — trajectory-reshaped and
choices-remapped at all three seeds, and **not** seed-remapped, which is exactly right since
`seed_state` was untouched. **Its three-quantity design paid off on its first real firing: it named
which layer moved without anyone having to guess.** Both it and the S7 fixtures were re-derived by
sweep and re-pinned by hand; no regeneration path was added and the three sweep scripts were deleted.

**The bank moving entirely is the two-witnesses rule earning itself** — WI-D1 is precisely the drift it
was written for, and a single-witness bank would have lost classes silently.

## Stale recorded reasons: SEVEN, not five

The handoff named five and predicted more.

| # | Site | Named by handoff? |
|---|---|---|
| 1–3 | `dst_corpus.unreachable_by_search()` — three entries | yes |
| 4–5 | `dst_generator` — "NO PROVIDER FAULT" / "NO PROVIDER LATENCY" | yes |
| 6 | **`dst_fault_catalogue.catalogue_coverage_gaps()`** — the partial-stream gap | **no** |
| 7 | **`dst_run_report.ail:45`** — "`ScriptedStep` has no latency or error channel" | **no** |

All seven carried the same false clause; both fields have existed since WI-B2b. **Two were only half
stale and are restated in terms of what is actually missing:**

- **The latency notes.** `advance_ms` exists, so the field was never the obstacle. What is missing is
  the **recorder**. WI-D1 therefore leaves every generated entry at `advance_ms: 0` — **`clock-balance`
  never went red; the trap the handoff warned about was avoided rather than survived.**
- **The partial-stream gap.** The class is reached, but a genuine residue remains: the generated
  partial stream is a **prefix of a well-formed one**. An adversarial partial stream has no generator.

**And the eighth reason was accurate.** "The generator's `tool_args` are always well-formed JSON,
measured 0 of 260" was still true four items later. **The entry written from a MEASUREMENT survived;
the three written from an INSPECTION did not.**

## The rule the handoff warned about, handled in order

**Shrink the register FIRST (S1).** The asymmetry is real: *removing* an entry is red at the pinned
`== 4`, but *adding reachability without removing the entry goes nowhere* — the class stays out of
`expected_bank_coverage()`, the bank is never asked to reach it, and `corpus_pr` stays green over a red
row. So the register was emptied as the **first edit of the item**, `make corpus_pr` was confirmed red
on exactly the four classes, and everything after was driven by that red.

**The row that would have fired on a late register update never fired — because it could not.** It is
now vacuous, kept, and says so.

## Rows 4 and 11, re-answered against the ADR's text

**Row 4 — PASS.** Nine of nine required non-waived classes, both waived classes named with their
conditions, and the row's own word is *recovery code*: the wire carries `stream_error_retry`,
`provider_failure_finalize` and the degraded-arguments dispatch alongside the five branches already
counted. **The two provider error classes are gated to reach different branches** — the clause a
counter cannot answer.

**One qualification stated rather than absorbed:** it is **eight by search and one by construction**.
`provider_empty_terminal_response` was re-measured at 0 of 260 under the new generator, so the
construction's justification holds — but "nine of nine" must not be read as "nine by search."

**Row 11 — PASS.** The one clause it failed was *"the fixed bank reaches every required non-waived
fault class."* It now does. **And one thing got strictly better:** the previous bank had a member
(seed 195) reaching *every* sweep-reachable class alone; the new one's best single trajectory reaches
five of eight, with three seeds tied. **A bank whose collective coverage exceeds any single member's is
the shape D11 asks for**, and the previous bank did not have it.

**Neither row closed by narrowing anything.** The register went to zero by classes being reached, not
reclassified or waived.

## Sites where two answers type-checked and one was silently wrong: 52

**Authored none.** Every alternative that type-checked was caught by a gate landed before the change
(S1) or by one that already existed.

**Found one pre-existing, and it is the largest single one this project has recorded:**
`c2_finalize(st.provider, st.world_state, …)`. Both expressions type-check, both run, both keep every
existing count balanced, and the wrong one silently truncates the recorded program on a terminal path.
**Wrong since WI-B2b and invisible to every gate until a fault class needed that log entry.**

Counted as **52** from C4's 51, attributed to B2b and recorded here, per C4's convention. **Determinism
has caught none of the fifty-two.** Nor did any mutation gate catch this one on its own — it was found
by **a class census reading zero where the wire read 75**, which is S19's absent-tick rule in a new
medium.

## Corrections owed to the plan

1. **S12 now has an instrument, and it is a fault class.** Any S12-shaped site can be instrumented the
   same way: give the discarded world something to carry that a gate demands.
2. **S19 generalises from an absent TICK to an absent COUNT.** *"A zero in a census is a claim, and a
   census with an independent producer is where you check it."*
3. **A stale reason from a MEASUREMENT outlives one from an INSPECTION.** S15's practical form: when
   recording why something is unreachable, record the measurement, not the diagnosis.
4. **The plan has no item after Milestone C.** WI-D1 was scheduled by handoff. Three entries of C4's
   work list remain unplanned.
5. **A generator change is a five-artifact cascade and the plan does not say so.** An item that budgets
   for "add a draw" budgets wrong by about an hour.
6. **`ToolFailed` and `ToolCorrelationMismatch` wire counts are now 6 and 3.** Above zero, but thin
   enough that a future generator change could zero one — the loop would say so.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 225 pass / 17 fail of 242.** Failing set
  matches the expected seventeen **member for member**. Stable across B4, C1, C3, C5, C4 and now D1.
  **Count unchanged at 242** because the three sweep scripts written here were deleted.
- **`make dst` — exit 2, the SAME TWO red targets as B4/C1/C3/C4/C5:** `test_coverage` and
  `test_coverage_selftest` (`prompts_test.ail: 0/6`, `stale_skip_record`), attributed by B2a to module
  resolution in `ailang test`. **809 ✓ rows** against C4's 805 — comparable, methodology unchanged.
- **`make corpus_pr` — exit 0 at 21 s against a 45 s ceiling**, on the wider expected set.
- **`make anchors` — 10/10, unmoved. No profile re-issue.**

## Traps avoided, worth carrying

- **The clock-balance trap did not fire**, because the fault was given no `advance_ms`. Coupling to
  D4's latency pair here would have reddened a gate that is red for a good reason.
- **The codec trap did not fire**, because the binding was chosen to avoid it rather than to survive
  it. No stop-and-report was needed.
- **The anchor cascade did not fire**, because the one production edit was made line-count-neutral.
- **A bad shell regex cost ~15 minutes and is worth recording.** `(^|,)$c(,|$)` against
  `classes=ToolFailed,…` never matches a leading member, so my first two class censuses reported
  `ToolFailed` at 0 of 260 and sent me hunting a defect in `world_tool` that did not exist. Caught by
  instrumenting occurrence counts and finding 34 where the census said 0. **A measurement that
  disagrees with a plausible story is worth more than the story** — the same lesson as the real
  finding, one level out.

## Deliberately not done

Row 7's oracle register (the next item, and the largest remaining blocker); row 10's filesystem world
class; D4's provider latency pair; the two sibling `st.world_state` finalize sites; the adversarial
partial stream; the `on_budget_plan` ABI change and everything gated on it; the `motoko-ext-abi` major;
the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

**And the name.** Rows 4 and 11 close; **rows 7 and 10 remain RED, so `driver_only` still does not
adopt the "DST" or "simulation" name.** Nine consecutive items have declined it. Two of the four
failing rows are now closed and the verdict is unchanged — which is what a four-row gate means.
