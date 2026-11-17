# Random-mutant pilot on the session driver, at `dd8a12f1`

Run on 2026-11-17 for [RESEARCH §8.1](../../RESEARCH-systematic-mutation-testing.md), by a
session that wrote none of the code under test. Base: `origin/main` = `dd8a12f1`, AILANG v0.60.4
(`563c6c9`), 8 cores shared with other sessions (load 6 to 15 throughout). No test, rule or
production source was changed; every mutant was applied in a scratch worktree, one at a time, and
the tree was hash-checked against `base.sha256` before and after each run.

## The result

- **30 mutants nobody chose**, drawn from 399 candidate edits in 31 driver functions. Walking the
  seeded order took 38 sites: 8 drawn edits did not type-check and were replaced by the next site.
- **14 of the 30 were killed by a named check**: 5 by a `corpus_judge` rule, 8 more by the
  tier-3 gates, 1 more by the full `make dst`.
- **13 of the 30 sit on code no bank member runs.** 11 are run by nothing at all, two of them dead
  code (my judgement). 2 are run only by one of `corpus_judge`'s controls.
- **3 were run by a member and killed by no rule at any tier.** Two of them (m05, m18) change
  nothing that any run here observes, and I judge them equivalent on every path a run here walks.
  The third, **m11, is the one measured gap**: the retry record leaves the returned trace and
  stays on the wire. No rule names it. A vacuity guard, a control and an unrelated record-count
  pin go red.
- **Yield: 3 by measurement (m05, m11, m18), none on ADR-003's "Known, and not seen" list. After
  my judgements, 2 new gaps**: m11 (an oracle gap) and m18 (a reach gap: it differs only on a
  configuration no run uses); m05 differs only on a path ADR-003 D6 already names. The rule fixed
  in the brief says **draw again** on the measured count and **the operator decides** on the judged
  one. The difference is one judgement of mine, on m05 (§ Recommendation).
- **Predictions held at tier 1 (30 of 30) and missed 7 of 30 final verdicts.** Four (m01, m04,
  m28, m29) were predicted unkilled with `discovery` named only as a "maybe"; m10, m11 and m20 were
  wrong outright.

Where the 17 mutants a member reaches were caught:

| caught by | mutants |
|---|---|
| a `corpus_judge` rule (tier 1) | m06, m07, m22, m24, m25 |
| `discovery` / `strict_replay`'s source-derived env count (tier 3) | m01, m28, m29 |
| `discovery`'s handle scenario: a dropped hook successor (tier 3) | m04 |
| `ledger_parity`'s wire-against-trace counts (tier 3) | m16, m20, m21, m27 |
| `make dst`: the approval protocol scenario, `tool_phase`'s inline test, `world_state` (tier 4) | m10 |
| no rule at any tier | m05, m18 (judged equivalent), **m11** |

`corpus_judge` alone, the gate this pilot was built around, named 5 of the 17. Three of the eight
tier-3 kills (m01, m04, m29) changed the trajectory of many bank members, in m04's case flipping
six outcomes between `Ok` and `Err`, with every `corpus_judge` rule clean: each run stayed
internally consistent because the dropped reads left the log and the ordinals together. That is
D9's stated blind spot and ADR-003's *Not decided* item 1, measured.

## The verdicts

One row per drawn site, in draw order. Rule ids are the gate's. "Killed" means a named check
about the broken behaviour went red; everything else that went red is in `mutants.tsv`'s
`tier1_also`, `tier3` and `tier4` columns. Judgements are marked as such.

| rank | mutant | site | function | operator | the edit | verdict | named by, or why not |
|---|---|---|---|---|---|---|---|
| 1 | m01 | `session:3834` | `run_v2_traced_from_seed` | SR.world | boot clock read starts from `provider.world`, not the session-id read's successor | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_SESSION_ID) |
| 2 | m02 | `session:3616` | `c2_loop` | BF.literal | intercept arm journals its messages as replacing the previous entry | not killed: not reached | no member, no control |
| 3 | m03 | `tool_phase:188` | `policy_default_allow` | BF.literal | `AllowAfterTimeout` means deny | not killed: not reached | no member, no control |
| 4 | m04 | `tool_phase:500` | `execute_allowed_tool_call` | SR.world | tool timeout env read from `world`: the hook's and the clock read's successors dropped | **killed**, tier 3 | discovery: handle scenario, a dropped successor |
| 5 | m05 | `session:3243` | `c2_loop` | SR.world | approval arm's ExtCtx world token is the pre-approval world | not killed: reached, no observable difference | judgement: equivalent on every walked path |
| 6 | m06 | `session:3668` | `c2_loop` | SR.record | tool-calling step's `state_delta` not journaled | **killed**, tier 1 | journal-fold-disagrees on 5 |
| 7 | m07 | `session:3258` | `c2_loop` | SR.world | approved tool runs from the pre-approval world | **killed**, tier 1 | request-ordinals-not-contiguous on 12 |
| 8 | m08 | `session:3213` | `c2_loop` | BF.literal | dead `None` arm reports `retryable: true` | not killed: not reached (judgement: dead code) | no member, no control |
| 9 | m09 | `tool_phase:515` | `execute_allowed_tool_call` | SR.stmt | `tool_arguments_invalid` not emitted to the wire | not killed: no member reaches it | reached by the invalid-request control, which stayed green |
| 10 | m10 | `tool_phase:91` | `parse_approval_command` | CF.negate | a deny reason is replaced by "denied by operator" (`==` becomes `!=`) | **killed**, tier 4 | phase_c_l1 (approval protocol), test_coverage (inline test), world_state |
| 11 | m11 | `session:3523` | `c2_loop` | SR.record | `stream_error_retry` not appended to the returned trace | not killed by a rule: reached, difference not revealed by a rule | only a vacuity guard, control a2 and depth_canary's count pin went red |
| 12 | m12 | `tool_phase:476` | `execute_allowed_tool_call` | SR.stmt | delegated tool's event not emitted | not killed: not reached | no member, no control |
| 13 | m13 | `tool_phase:637` | `dispatch_tool_entries_with_builtin` | SR.record | policy-denied call's denial message dropped | not killed: not reached | no member, no control |
| 14 | m14 | `session:3052` | `c2_loop` | SR.record | injected user message journaled but not added to the history | not killed: no member reaches it | CONTROL solver-feedback journal-fold-disagrees RED |
| 15 | m15 | `tool_phase:420` | `execute_allowed_tool_call` | SR.stmt | scratchpad tool's handled event not emitted | not killed: not reached | no member, no control |
| 16 | m16 | `tool_phase:662` | `dispatch_tool_entries_with_builtin` | SR.record | `tool_pending` dropped from the fold's emitted log | **killed**, tier 3 | ledger_parity: ToolPending projected 1, returned 0 |
| 17 | m17 | `session:2760` | `c2_await_wake_state` | SR.world | await-wake state keeps the pre-step world | not killed: not reached | no member, no control |
| 18 | - | `session:3670` | `c2_loop` | SR.stmt | drop `let next_state = …` (bound only in a sibling arm) | did not type-check | undefined variable `next_state` |
| 19 | - | `session:3169` | `c2_loop` | MAS.swap | swap the `Park` and `AwaitApproval` arm bodies | did not type-check | undefined variable `waits` |
| 20 | m18 | `session:4574` | `publish_turn_exit_manifest` | SR.world | exit render's ports open on the pre-read world | not killed: reached, no observable difference | judgement: equivalent on every walked path |
| 21 | m19 | `tool_phase:635` | `dispatch_tool_entries_with_builtin` | SR.stmt | policy-denied call's event not emitted | not killed: not reached | no member, no control |
| 22 | - | `session:3601` | `c2_loop` | SR.stmt | drop `let event = ExtInterceptHandled(…)` | did not type-check | undefined variable `event` |
| 23 | m20 | `tool_phase:491` | `execute_allowed_tool_call` | MAS.swap | `invalid_resolution` match arms swapped | **killed**, tier 3 | ledger_parity: census row `invalid` |
| 24 | - | `tool_phase:627` | `dispatch_tool_entries_with_builtin` | MAS.swap | swap the policy `Deny` and `Pending` arm bodies | did not type-check | undefined variable `default` |
| 25 | m21 | `session:3458` | `c2_loop` | SR.stmt | `provider_call_prepared` not emitted to the wire | **killed**, tier 3 | strict_replay, discovery wire witness; ledger_parity ProviderCallPrepared 0 vs 18 |
| 26 | m22 | `session:2710` | `c2_candidate_approved_state` | BF.literal | approved answer journaled as replacing the previous entry | **killed**, tier 1 | journal-fold-disagrees on 10 |
| 27 | m23 | `session:2809` | `wake_matches` | BF.literal | a wake reply with OperatorInput/HostError/Aborted is dropped | not killed: not reached | no member, no control |
| 28 | - | `session:3211` | `c2_loop` | MAS.swap | swap the approval `None` and `Some` arm bodies | did not type-check | undefined variable `req` |
| 29 | - | `session:3437` | `c2_loop` | SR.stmt | drop `let event = CompactionExhausted(…)` | did not type-check | undefined variable `event` |
| 30 | m24 | `session:2711` | `c2_candidate_approved_state` | SR.record | approved answer's `history_appended` neither journaled nor emitted | **killed**, tier 1 | journal-fold-disagrees on 10 |
| 31 | m25 | `session:3519` | `c2_loop` | SR.world | terminal capture env read from the pre-step world | **killed**, tier 1 | provider-calls-unbalanced, request-ordinals-not-contiguous on 6 |
| 32 | - | `session:3666` | `c2_loop` | SR.stmt | drop `let appended = …` | did not type-check | undefined variable `appended` |
| 33 | m26 | `step_machine:54` | `await_approval_from_calls` | BF.literal | dead `[]` arm reports `retryable: true` | not killed: not reached (judgement: dead code) | no member, no control |
| 34 | m27 | `session:3506` | `c2_loop` | SR.stmt | errored `thinking_stream_end` not emitted to the wire | **killed**, tier 3 | ledger_parity: ThinkingStreamEnd 17 vs 18 |
| 35 | m28 | `session:4552` | `publish_turn_exit_manifest` | SR.world | manifest-name env read's successor dropped | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_EXIT_MANIFEST) |
| 36 | m29 | `session:3835` | `run_v2_traced_from_seed` | SR.world | boot witness drains `provider.world`: every pre-loop read dropped | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_SESSION_ID); corpus_pr required-class-not-covered |
| 37 | - | `session:3711` | `c2_loop` | SR.stmt | drop `let appended = …` | did not type-check | undefined variable `appended` |
| 38 | m30 | `session:2805` | `wake_matches` | BF.connective | wake match: `&&` becomes `||` | not killed: not reached | no member, no control |

## The survivors, rule against checker

Every mutant not killed, with what the stated rule says and what the checker reports. A drawn
mutant has no stated rule behind it, so the "stated rule" column names the nearest one a decision
document or a code comment states, or says there is none. Each goes to the operator for a ruling;
no test was written for any of them.

| mutant | stated rule says | the checker reports | stopped at |
|---|---|---|---|
| **m11** | 009 ADR-001 D6.4: a Logical event is on the wire and in the returned trace. ADR-003 D4's `retry-at-budget-edge` reads the trace's retries | no rule fires: `retry-at-budget-edge` is held against no retry. `corpus_judge`'s vacuity guard ("a member recorded a retry (0 of 18)") and its control `retry-with-two-steps-left` go red. `ledger_parity` is green and lists `StreamErrorRetry` among the events none of its eight subjects witnesses. `make dst` adds `depth_canary`, a record-count pin kept for a recursion-depth measurement | reached by the four members that retry (seeds 8, 18, 31, 109; every one loses its retry records, so the guard counts 0 of 18); the difference is observable and no rule reveals it. A weak oracle: the one gate built for wire-against-trace parity never meets this event |
| m05 | no ADR-003 rule; WI-D20's comment (`tool_phase.ail:424-452`) says the hook's world must be re-seated from the live world | nothing differs on any row, target or sweep | reached (seed 1), no observable difference. *Judgement*: equivalent on every walked path; differs only on the scratchpad path, "a tool an extension handles", which D6 names as not shown |
| m18 | `publish_turn_exit_manifest`'s comment: the render sees the turn's successor | nothing differs | reached (seed 1), no observable difference. *Judgement*: equivalent while `MOTOKO_EXIT_MANIFEST` is unset (`ext/exit_manifest.ail:203` returns before the ports are used); a run that publishes a manifest would hand its exit intents a world one env read behind |
| m14 | D4: the journal's fold reproduces the final history | `journal-fold-disagrees` on the `solver-feedback` CONTROL row; the brief counts JUDGE rows only | no member reaches it; the gate's control does and names the rule |
| m09 | 009 ADR-001 D6.4 parity | the invalid-request control reaches it and stays green: the gate reads only the trace | no member reaches it |
| m02, m03, m12, m13, m19 | m02: ADR-003 D2 and D4 (m22, the same edit one function over, was killed by `journal-fold-disagrees`). m03, m13: none in ADR-003. m12, m19: 009 ADR-001 D6.4 | not evaluated | **not reached**: the response-intercept arm (m02), an approval timeout that allows (m03), the delegated backend (m12), a policy that denies (m13, m19). No run here walks any of them |
| m15 | 009 ADR-001 D6.4 | not evaluated | not reached: the scratchpad tool, "a tool an extension handles" (D6, known) |
| m17, m23, m30 | D9 (m17); ADR-002 D2's wake match (m23, m30) | not evaluated | not reached: open waits and wakes. Known: "The corpus never parks" (D6's list) |
| m08, m26 | none | not evaluated | not reached. *Judgement*: dead code. m08's `None` arm needs `await_approval` without a pending approval, and the only producer of that reason (`session.ail:3353`) sets one; m26's `[]` arm is called only with pending calls (`step_machine.ail:112-114`) |

**Counts with and without the judgements.** Of the 30: 14 killed. Of the 16 not killed, 4 rest on
my judgement (m05, m18 equivalent on walked paths; m08, m26 dead code). Without them, 12 not
killed: 1 reached and unrevealed (m11), 2 reached only by a control, 9 not reached. The killed
share is 14 of 30 with them and 14 of 26 without.

## The yield

The brief's yield: reached (by a bank member) and killed by no tier.

| | measured | after my judgements |
|---|---|---|
| reached by a member, killed by no rule at any tier | 3: m05, m11, m18 | the same 3 |
| of these, on ADR-003's "Known, and not seen" list | 0 | 0 |
| of these, a new gap | 3 | **2**: m11, an oracle gap (the difference is observable and no rule reads it); m18, a reach gap (judged to differ only when an exit manifest is published, which no run does and nothing records). m05 is not counted: judged to differ only on the extension-handled tool path, which D6's paragraph after the list already names as not shown |

**Under the ordinary reading**, where any target red under the mutant and green at base counts,
m11 is caught at tier 4 (`corpus_judge`'s guard and `depth_canary`'s pin), and the counts fall by
one: 2 measured, 1 after judgement. I report the rule reading as the headline because §5.1 and the
spike's `M2` make exactly this distinction: a pin kept for something else, red by accident, is not
the property seen.

**Reach is the larger finding.** 13 of 30 drawn mutants sit where no bank member runs. Four are
on branches ADR-003 already records as unwalked (parking: m17, m23, m30; an extension-handled
tool: m15). Two are dead code by my judgement (m08, m26). Two are walked only by the gate's own
controls (m09, m14). The other five sit on four branches I found recorded nowhere as unwalked: the
response-intercept arm (m02), an approval timeout that allows (m03), the delegated backend (m12)
and a policy that denies (m13, m19).

## Per operator

| operator | drawn | did not type-check | killed T1 | killed T3 | killed T4 | reached, no rule | control only | not reached |
|---|---|---|---|---|---|---|---|---|
| SR.world (keep the predecessor) | 9 | 0 | 2 | 4 | 0 | 2 (m05, m18, both judged equivalent) | 0 | 1 |
| SR.record (dropped record) | 6 | 0 | 2 | 1 | 0 | 1 (m11) | 1 | 1 |
| SR.stmt (statement removed) | 11 | 5 | 0 | 2 | 0 | 0 | 1 | 3 |
| BF (boolean flip) | 7 | 0 | 1 | 0 | 0 | 0 | 0 | 6 |
| CF (comparison flip) | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| MAS (match-arm swap) | 4 | 3 | 0 | 1 | 0 | 0 | 0 | 0 |
| OBO (off-by-one) | 0 | - | - | - | - | - | - | - |
| **all** | **38** | **8** | **5** | **8** | **1** | **3** | **2** | **11** |

- **Keep-the-predecessor paid best**: 6 of 9 killed, and all three tier-3 kills that changed whole
  trajectories (m01, m04, m29) came from it.
- **Statement removal of a named `let` produced only noise.** Its definition took a name bound
  earlier in the text as a shadow, and five of five such draws were names bound only in a sibling
  match arm. **Match-arm swap** mostly fails on pattern variables (3 of 4).
- **Boolean flips mostly landed on unwalked branches** (6 of 7).
- **Off-by-one was never drawn**: 17 of 311 site-operator pairs, none in the first 38 ranks. The
  pilot says nothing about it, or about comparison flips beyond one mutant.

## Predictions against outcomes

Written and hashed before any gate ran (`predictions.tsv`, sequence.log `STEP6`). Per mutant in
`mutants.tsv`'s last two columns.

| | right | wrong |
|---|---|---|
| tier-1 state (kill, red without a kill, green) | 30 | 0 |
| reached by a member or not (the 25 probed) | 24 | 1: m20, predicted unreached by members; every native dispatch evaluates the statement, and it cannot differ there only because the bank runs in `Legacy`. (m05's predicted member set, "members that run an approved tool", was also too narrow: every approval read reaches it) |
| final verdict | 23 | 7: **m01, m04, m28, m29** predicted unkilled, with `discovery` named only as a "maybe" in the namer column (m04's for another reason than the one given: the hook's successor, not the clock read's); **m10** predicted unkilled (tiers 1-3 were green; `make dst` has three checks that read deny reasons); **m11** predicted a `ledger_parity` kill (it does not witness retries); **m20** predicted unkilled and unreached by members (killed at tier 3 by `ledger_parity`'s Limits subject) |

The misses lean one way: six of the seven predicted a survivor where a tier-3 or tier-4 check
killed it. I underrated the scripted gates outside `corpus_judge`.

## Time

Machine time, from each run's own wall clock (`runs/*/*/rc`):

| stage | runs | seconds |
|---|---|---|
| the draw's type checks | 38 `ailang check` | 782 |
| calibration | 5 `corpus_judge` | 201 |
| tier 1 | 30 `corpus_judge` | 919 (7 to 45 each) |
| tier 2 | 26 reach probes | 656 |
| tier 3 | 6 targets on base, then 6 targets on 12 mutants | 371 + 3,951 (`check_core` is 2,026 of it) |
| tier 4 | 1 sweep on base, 4 on mutants | 612 + 2,180 (531 to 612 each) |
| **total** | | **9,672, about 2.7 hours** |

A full `make dst` took 9 to 10 minutes here, not the half hour §6 carries from the spike. Elapsed
time from the base commit's record to the last sweep: 18:43 to 21:50 UTC. Triage (reading each
red, writing `triage.tsv` and this page) was about an hour and a half, interleaved with the runs
and not clocked separately.

## How it was run

Every step is in `sequence.log` with its time and the SHA-256 of what it fixed, in this order:

1. **Base** (`base.txt`): `origin/main` and the toolchain.
2. **Population** (`population.md`, `population.tsv`, `population-accounting.tsv`): the call
   graph from `run_v2_traced_from_seed`, every traced run's shared entry, over the four files (133
   functions); 31 kept by a structural rule (hands a world on, or chooses a recovery), every other
   one excluded under a named class. `scripts/population.py` recomputes it and fails on anything
   unaccounted for.
3. **Operators** (`operators.md`, `scripts/mutator.py`, self-tested on planted cases).
4. **Enumeration** (`enumeration/`, then `enumeration-a1/` after amendment A1): 399 candidates,
   311 site-operator pairs, 265 sites (a site is a source line).
5. **Draw** (`scripts/draw.py`, `draw-order.tsv`, `draw-checked.tsv`): seeded with the base SHA;
   every choice is `sha256(seed|label)`, so the order can be recomputed by hand. `ailang check` was
   calibrated first (`typecheck-calibration.txt`).
6. **Predictions** (`predictions.tsv`).

Then: calibration (the unmutated gate green with 18 members; a comment-only edit green, its 190
rows identical; acceptance's rows r01, r07 and r12, re-anchored by text, each red on the rule it
names); tier 1; tier 2 (a probe that makes the site fail with an integer division by zero, and a
positive control that failed on its own line on seed 3); tier 3 (the six targets, green on base
first); tier 4 (a base sweep, then the four tier-3 survivors). The scorers read rows and summary
blocks, never exit status alone, and each was self-tested on planted cases before it read a real
result (`score-selftest-a2.txt`, `scripts/score_target.py selftest`, `scripts/score_dst.py
selftest`).

## Deviations from the brief

1. **The kill rule was applied literally.** At tier 1 only `JUDGE <member> <rule id> RED`
   counts; CONTROL rows, guards and not-evaluated rows are recorded beside it. At tiers 3 and 4 a
   kill is a failing check about the broken behaviour; m11's tier-4 reds (a vacuity guard and a
   count pin) are recorded and not counted, and the yield is given under both readings.
2. **Tier 3 ran only on mutants a bank member reaches**, as the brief words it. m09 and m14,
   reached only by a `corpus_judge` control, stopped at tier 2.
3. **Two baselines added**: the six tier-3 targets on the unmutated tree, and a tier-4 sweep on
   it (confirmed by the operator mid-run). Both were green apart from the known-red
   `declared_vs_performed`.
4. **A site is a source line**, and after drawing the operator the draw also picks one candidate
   of that operator on that line, with the same generator. The brief says one operator per site;
   several candidates of one operator can share a line.
5. **Reach probes insert a failing statement** before the drawn statement (or wrap the drawn
   expression) instead of replacing it, so that each probe type-checks. A run that never evaluates
   the site cannot fail on either.
6. **Whole functions are the population**, so normal-path statements inside `c2_loop` are sites
   too (m21, for one).
7. **Four amendments**, each dated, hashed and kept beside what it replaced (`AMENDMENTS.md`):
   A1, before the draw, the enumerator against `operators.md` (409 candidates became 399); A2 and
   A3, the scorer (v0.60.4's runtime-error wording; members counted once); A4, the runner keeps
   `corpus_pr`'s whole output.
8. **The machine was shared.** Load stayed between 6 and 15 from other sessions. `corpus_pr`
   never failed on its ceiling, so the brief's single re-run was never needed.

## What was not verified

- **The four judgements** (m05, m18 equivalent on walked paths; m08, m26 dead code) rest on
  reading the source, not on a run that could tell them apart.
- **Why `ledger_parity`'s census row `order` goes red under m01, m04 and m29.** Probably the
  trajectory change; not traced. Those three are killed by other checks either way.
- **m20's `strict_replay` run ends on a recursion-depth runtime error** after its Limits rows go
  red. Recorded as a panic, not a kill; the cause was not traced.
- **m01's failing `corpus_pr` row is not recorded.** The recipe shows only its last 40 lines, and
  the full output was overwritten before amendment A4.
- **Reach was measured to the first member that reaches a site**, not per member.
- **`corpus_pr` writes a fixed `/tmp/corpus_pr.out`.** A concurrent `corpus_pr` from another
  session would have overwritten the file A4 copies; none was seen, and it cannot be excluded.
- **Whether one mutant per line is enough** (the Google result) under property verdicts. Not
  tested; one candidate was drawn per line.

## Recommendation

By the rule fixed in the brief the result is **"three or more: draw again" on the measured count
(m05, m11, m18) and "one or two: the operator decides" once my judgements are applied (m11, m18)**.
The two readings differ by one judgement: that m05 changes nothing except on the extension-handled
tool path, which ADR-003 D6 already names. I think that judgement is sound (`tool_phase.ail:451`
re-seats the world before the only reader on every other path), so I apply the rule as "the
operator decides"; if the operator does not accept it, the rule says draw again. My recommendation
is **not to draw a second batch from this population yet.** Of the
17 mutants a member reaches, 14 were named by a check, so a second draw of the same shape buys
mainly more of what this one found most of: 13 of 30 landed on branches no bank member walks, five
of them on four branches nothing records as unwalked. Those branches (the intercept arm, an allowing
timeout, the delegated backend, a denying policy) need a ruling first: whether each should be
walked by a member or a control, or recorded as known and unseen. m11 needs its own ruling on
whether the retry record's parity should be witnessed, and m18 on whether an exit-manifest
publication should be walked. After those rulings, a second batch would
measure the gate that results rather than re-measure the reach gaps this one already shows. If the
operator wants a second batch now, the same population, operators and seed scheme apply unchanged,
with the next 30 type-checking sites taken from `draw-order.tsv` after rank 38.

## Files

| file | what |
|---|---|
| `sequence.log` | every step, in order, with times and hashes, and every run's integrity check |
| `base.txt`, `base.sha256` | the base commit and toolchain; the four files' hashes |
| `population.md`, `population.tsv`, `population-accounting.tsv` | the rule, the 31 functions, all 133 reachable with their verdict |
| `operators.md`, `AMENDMENTS.md` | the five operators; A1 to A4 |
| `enumeration/`, `enumeration-a1/` | STEP4's enumeration as first run; the amended one the draw used |
| `draw-order.tsv`, `draw-checked.tsv`, `draw-check.log` | the seeded order of all 265 sites; the 38 walked with their type check |
| `predictions.tsv` | the predictions, hashed before any gate ran |
| `typecheck-calibration.txt`, `calibration-scores.tsv` | the type-check filter's calibration; the gate's |
| `tier1-scores.tsv`, `reach-probes.tsv`, `tier4-scores.txt` | each tier as its scorer read it |
| `triage.tsv` | the judgement per mutant: verdict, stated rule, checker, known list, prediction outcome |
| `mutants.tsv` | everything per drawn site, assembled by `scripts/assemble.py` from the above |
| `runs/<target>/<id>/` | each run: `out.txt` (non-wire lines), `mutant.diff`, `apply.log`, `rc`; `corpus_pr` runs after A4 also keep `full.txt` |
| `scripts/` | `ailsrc.py` (tokenizer), `population.py`, `mutator.py`, `draw.py`, `fixed_edits.py` (controls and probes), `run_gate.sh`, `run_tier3.sh`, `run_tier4.sh`, the scorers and their self-tests, `assemble.py`; `*-step3.py`, `*-pre-a*.*` are the versions amendments replaced |

The scratch worktree, `/workspaces/motoko_agent-039-pilot-scratch`, is left clean at `dd8a12f1`.
