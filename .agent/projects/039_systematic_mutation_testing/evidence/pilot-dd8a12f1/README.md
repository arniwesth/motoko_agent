# Random-mutant pilot on the session driver, at `dd8a12f1`

Run on 2026-11-17 for [RESEARCH §8.1](../../RESEARCH-systematic-mutation-testing.md), by a
session that wrote none of the code under test. Base: `origin/main` = `dd8a12f1`, AILANG v0.60.4
(`563c6c9`), 8 cores shared with other sessions (load 6 to 15 throughout). No test, rule or
production source was changed; every mutant was applied in a scratch worktree, one at a time, and
the tree was hash-checked against `base.sha256` before and after each run.

**What is tested is the checks, not the driver.** Each mutant is a small bug planted in the
driver's recovery code by a seeded draw, so nobody chose it. It is killed when a check about the
broken behaviour fails. A check that goes red for another reason (a count pin kept for something
else, a vacuity guard, a crash) is recorded and not counted. The pilot was built to grade one gate,
`corpus_judge`, which holds ADR-003's stated rules against 18 recorded runs. Follow-ups F1 to F3
(2026-11-19 and 20) ran every mutant that any run reaches through the whole of `make dst`. Since
amendment A8 this page leads with that suite-wide result. The pilot's `corpus_judge` result
follows it, unchanged.

## The result across the suite

- **30 mutants nobody chose**, drawn from 399 candidate edits in 31 driver functions. Walking the
  seeded order took 38 sites: 8 drawn edits did not type-check and were replaced by the next site.
- **22 of the 30 are killed** by a check about the broken behaviour, somewhere in `make dst`.
- **5 are run, and no check names them.**
  - **m11 is an oracle gap.** The retry record leaves the returned trace and stays on the wire. No
    check about that fails; a vacuity guard, a control and an unrelated record-count pin go red.
  - **m02** marks the intercept arm's journal record as replacing the previous entry. Five targets
    run it and none goes red. Its twin one function over, m22, is killed by `corpus_judge`'s
    journal fold.
  - **m03** makes `AllowAfterTimeout` mean deny. It differs only when an approval read hits EOF or
    gets an unparseable or unknown reply, and by my reading no run that reaches it produces one.
    The fault catalogue's `approval_deadline_exceeded` class already says the class is not
    exercised.
  - **m05 and m18** change nothing any run observes. I judge both equivalent on every walked path;
    m18 differs only when an exit manifest is published, which no run does.
- **3 are run by no `make dst` target**: m15, on the extension-handled tool path ADR-003 D6 names,
  and m08 and m26, which I judge to be dead code.
- **Kills at tiers 1 and 3 count across the suite** because `make dst` runs the same make targets
  (`corpus_judge`, `strict_replay`, `discovery`, `ledger_parity`, `corpus_pr`). Those 13 mutants
  were not re-run in a full sweep. `check_core`, the one tier-3 target outside `make dst`, killed
  nothing.

Where the 30 were caught:

| caught by | mutants |
|---|---|
| a `corpus_judge` rule, on a bank member (tier 1) | m06, m07, m22, m24, m25 |
| a `corpus_judge` rule, on one of its controls (F3) | m14 |
| `ledger_parity`'s wire-against-trace counts (tier 3, F2, F3) | m16, m20, m21, m27, m12, m19, m09 |
| `discovery` and `strict_replay`'s source-derived env count (tier 3) | m01, m28, m29 |
| `discovery`'s handle scenario: a dropped hook successor (tier 3) | m04 |
| the parking targets: `world_framed_wire`, `park_wake`, `park_resume` (F2) | m17, m23, m30 |
| `journal_resume`'s journal fold refuses the journal (F2) | m13 |
| the approval protocol, `tool_phase`'s inline test, `world_state` (tier 4) | m10 |
| run, and no check names it | m02, m03, m11; m05, m18 (judged equivalent) |
| run by no target | m15; m08, m26 (judged dead code) |

m21 is also named by `strict_replay` and `discovery`'s wire witness, and m29 by `corpus_pr`.
`ledger_parity`, which compares what reaches the wire with what the run returns, killed the most.

**Counts with and without the judgements.** 22 of 30 are killed. Of the 8 not killed, 4 rest on my
judgement (m05, m18 equivalent; m08, m26 dead code). Set those aside and 22 of 26 are killed, and
the 4 measured survivors are m02, m03 and m11, run and unnoticed, and m15, run by nothing.

## The result within `corpus_judge`, the gate the pilot was built to grade

- **14 of the 30 were killed by a named check in the pilot's four tiers**: 5 by a `corpus_judge`
  rule, 8 more by the tier-3 gates, 1 more by the full `make dst`. Tiers 2 to 4 ran only on mutants
  a bank member reaches.
- **17 of the 30 are run by a bank member**, and `corpus_judge`'s rules name 5 of them.
- **13 of the 30 sit on code no bank member runs.** 11 are run by none of `corpus_judge`'s members
  or controls, two of them dead code (my judgement), and 2 only by one of its controls. The rest of
  `make dst` runs 10 of the 13 and kills 8 of those (F1 to F3).
- **3 were run by a member and killed by no rule at any tier**: m05, m11 and m18, as above.
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

`corpus_judge` alone named 5 of the 17. Three of the eight tier-3 kills (m01, m04, m29) changed the
trajectory of many bank members, in m04's case flipping six outcomes between `Ok` and `Err`, with
every `corpus_judge` rule clean: each run stayed internally consistent because the dropped reads
left the log and the ordinals together. That is D9's stated blind spot and ADR-003's *Not decided*
item 1, measured.

## The verdicts

One row per drawn site, in draw order. The column *across `make dst`* is the headline: **killed**
means a check about the broken behaviour failed somewhere in `make dst`, run on its own at tier 1
or 3, or in a full sweep at tier 4, F2 or F3. The next two columns are the pilot's, defined on reach
by a `corpus_judge` bank member. Everything else that went red is in `mutants.tsv`'s `tier1_also`,
`tier3` and `tier4` columns and in `mutants-dst-new-rows.txt` and `mutants-dst-f3-new-rows.txt`.
Judgements are marked as such.

| rank | mutant | site | function | operator | the edit | across `make dst` | `corpus_judge` pilot | named by, or why not |
|---|---|---|---|---|---|---|---|---|
| 1 | m01 | `session:3834` | `run_v2_traced_from_seed` | SR.world | boot clock read starts from `provider.world`, not the session-id read's successor | **killed**: strict_replay, discovery (tier 3) | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_SESSION_ID) |
| 2 | m02 | `session:3616` | `c2_loop` | BF.literal | intercept arm journals its messages as replacing the previous entry | not killed: run by 5 targets, no check names it (F2) | not killed: not reached | no member, no control |
| 3 | m03 | `tool_phase:188` | `policy_default_allow` | BF.literal | `AllowAfterTimeout` means deny | not killed: run by 2 targets, no check names it (F2) | not killed: not reached | no member, no control |
| 4 | m04 | `tool_phase:500` | `execute_allowed_tool_call` | SR.world | tool timeout env read from `world`: the hook's and the clock read's successors dropped | **killed**: discovery (tier 3) | **killed**, tier 3 | discovery: handle scenario, a dropped successor |
| 5 | m05 | `session:3243` | `c2_loop` | SR.world | approval arm's ExtCtx world token is the pre-approval world | not killed: run, no observable difference (judgement: equivalent) | not killed: reached, no observable difference | judgement: equivalent on every walked path |
| 6 | m06 | `session:3668` | `c2_loop` | SR.record | tool-calling step's `state_delta` not journaled | **killed**: corpus_judge (tier 1) | **killed**, tier 1 | journal-fold-disagrees on 5 |
| 7 | m07 | `session:3258` | `c2_loop` | SR.world | approved tool runs from the pre-approval world | **killed**: corpus_judge (tier 1) | **killed**, tier 1 | request-ordinals-not-contiguous on 12 |
| 8 | m08 | `session:3213` | `c2_loop` | BF.literal | dead `None` arm reports `retryable: true` | not killed: run by no target (judgement: dead code) | not killed: not reached (judgement: dead code) | no member, no control |
| 9 | m09 | `tool_phase:515` | `execute_allowed_tool_call` | SR.stmt | `tool_arguments_invalid` not emitted to the wire | **killed**: ledger_parity (F3) | not killed: no member reaches it | reached by the invalid-request control, which stayed green |
| 10 | m10 | `tool_phase:91` | `parse_approval_command` | CF.negate | a deny reason is replaced by "denied by operator" (`==` becomes `!=`) | **killed**: phase_c_l1, test_coverage, world_state (tier 4) | **killed**, tier 4 | phase_c_l1 (approval protocol), test_coverage (inline test), world_state |
| 11 | m11 | `session:3523` | `c2_loop` | SR.record | `stream_error_retry` not appended to the returned trace | not killed: run, difference not revealed by a check (tier 4) | not killed by a rule: reached, difference not revealed by a rule | only a vacuity guard, control a2 and depth_canary's count pin went red |
| 12 | m12 | `tool_phase:476` | `execute_allowed_tool_call` | SR.stmt | delegated tool's event not emitted | **killed**: ledger_parity (F2) | not killed: not reached | no member, no control |
| 13 | m13 | `tool_phase:637` | `dispatch_tool_entries_with_builtin` | SR.record | policy-denied call's denial message dropped | **killed**: journal_resume's fold, `pairing` (F2) | not killed: not reached | no member, no control |
| 14 | m14 | `session:3052` | `c2_loop` | SR.record | injected user message journaled but not added to the history | **killed**: corpus_judge's solver-feedback control (F3) | not killed: no member reaches it | CONTROL solver-feedback journal-fold-disagrees RED |
| 15 | m15 | `tool_phase:420` | `execute_allowed_tool_call` | SR.stmt | scratchpad tool's handled event not emitted | not killed: run by no target (F1) | not killed: not reached | no member, no control |
| 16 | m16 | `tool_phase:662` | `dispatch_tool_entries_with_builtin` | SR.record | `tool_pending` dropped from the fold's emitted log | **killed**: ledger_parity (tier 3) | **killed**, tier 3 | ledger_parity: ToolPending projected 1, returned 0 |
| 17 | m17 | `session:2760` | `c2_await_wake_state` | SR.world | await-wake state keeps the pre-step world | **killed**: world_framed_wire, park_wake (F2) | not killed: not reached | no member, no control |
| 18 | - | `session:3670` | `c2_loop` | SR.stmt | drop `let next_state = …` (bound only in a sibling arm) | did not type-check | did not type-check | undefined variable `next_state` |
| 19 | - | `session:3169` | `c2_loop` | MAS.swap | swap the `Park` and `AwaitApproval` arm bodies | did not type-check | did not type-check | undefined variable `waits` |
| 20 | m18 | `session:4574` | `publish_turn_exit_manifest` | SR.world | exit render's ports open on the pre-read world | not killed: run, no observable difference (judgement: equivalent) | not killed: reached, no observable difference | judgement: equivalent on every walked path |
| 21 | m19 | `tool_phase:635` | `dispatch_tool_entries_with_builtin` | SR.stmt | policy-denied call's event not emitted | **killed**: ledger_parity (F2) | not killed: not reached | no member, no control |
| 22 | - | `session:3601` | `c2_loop` | SR.stmt | drop `let event = ExtInterceptHandled(…)` | did not type-check | did not type-check | undefined variable `event` |
| 23 | m20 | `tool_phase:491` | `execute_allowed_tool_call` | MAS.swap | `invalid_resolution` match arms swapped | **killed**: ledger_parity (tier 3) | **killed**, tier 3 | ledger_parity: census row `invalid` |
| 24 | - | `tool_phase:627` | `dispatch_tool_entries_with_builtin` | MAS.swap | swap the policy `Deny` and `Pending` arm bodies | did not type-check | did not type-check | undefined variable `default` |
| 25 | m21 | `session:3458` | `c2_loop` | SR.stmt | `provider_call_prepared` not emitted to the wire | **killed**: strict_replay, discovery, ledger_parity (tier 3) | **killed**, tier 3 | strict_replay, discovery wire witness; ledger_parity ProviderCallPrepared 0 vs 18 |
| 26 | m22 | `session:2710` | `c2_candidate_approved_state` | BF.literal | approved answer journaled as replacing the previous entry | **killed**: corpus_judge (tier 1) | **killed**, tier 1 | journal-fold-disagrees on 10 |
| 27 | m23 | `session:2809` | `wake_matches` | BF.literal | a wake reply with OperatorInput/HostError/Aborted is dropped | **killed**: park_wake, park_resume (F2) | not killed: not reached | no member, no control |
| 28 | - | `session:3211` | `c2_loop` | MAS.swap | swap the approval `None` and `Some` arm bodies | did not type-check | did not type-check | undefined variable `req` |
| 29 | - | `session:3437` | `c2_loop` | SR.stmt | drop `let event = CompactionExhausted(…)` | did not type-check | did not type-check | undefined variable `event` |
| 30 | m24 | `session:2711` | `c2_candidate_approved_state` | SR.record | approved answer's `history_appended` neither journaled nor emitted | **killed**: corpus_judge (tier 1) | **killed**, tier 1 | journal-fold-disagrees on 10 |
| 31 | m25 | `session:3519` | `c2_loop` | SR.world | terminal capture env read from the pre-step world | **killed**: corpus_judge (tier 1) | **killed**, tier 1 | provider-calls-unbalanced, request-ordinals-not-contiguous on 6 |
| 32 | - | `session:3666` | `c2_loop` | SR.stmt | drop `let appended = …` | did not type-check | did not type-check | undefined variable `appended` |
| 33 | m26 | `step_machine:54` | `await_approval_from_calls` | BF.literal | dead `[]` arm reports `retryable: true` | not killed: run by no target (judgement: dead code) | not killed: not reached (judgement: dead code) | no member, no control |
| 34 | m27 | `session:3506` | `c2_loop` | SR.stmt | errored `thinking_stream_end` not emitted to the wire | **killed**: ledger_parity (tier 3) | **killed**, tier 3 | ledger_parity: ThinkingStreamEnd 17 vs 18 |
| 35 | m28 | `session:4552` | `publish_turn_exit_manifest` | SR.world | manifest-name env read's successor dropped | **killed**: strict_replay, discovery (tier 3) | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_EXIT_MANIFEST) |
| 36 | m29 | `session:3835` | `run_v2_traced_from_seed` | SR.world | boot witness drains `provider.world`: every pre-loop read dropped | **killed**: strict_replay, discovery, corpus_pr (tier 3) | **killed**, tier 3 | strict_replay, discovery: env-read-under-recorded (MOTOKO_SESSION_ID); corpus_pr required-class-not-covered |
| 37 | - | `session:3711` | `c2_loop` | SR.stmt | drop `let appended = …` | did not type-check | did not type-check | undefined variable `appended` |
| 38 | m30 | `session:2805` | `wake_matches` | BF.connective | wake match: `&&` becomes `||` | **killed**: park_resume, park_wake (F2) | not killed: not reached | no member, no control |

## The survivors, rule against checker

Every mutant not killed anywhere in the suite, with what the stated rule says and what the checker
reports. A drawn mutant has no stated rule behind it, so the "stated rule" column names the nearest
one a decision document or a code comment states, or says there is none. Each goes to the operator
for a ruling; no test was written for any of them.

| mutant | stated rule says | the checker reports | stopped at |
|---|---|---|---|
| **m11** | 009 ADR-001 D6.4: a Logical event is on the wire and in the returned trace. ADR-003 D4's `retry-at-budget-edge` reads the trace's retries | no rule fires: `retry-at-budget-edge` is held against no retry. `corpus_judge`'s vacuity guard ("a member recorded a retry (0 of 18)") and its control `retry-with-two-steps-left` go red. `ledger_parity` is green and lists `StreamErrorRetry` among the events none of its eight subjects witnesses. `make dst` adds `depth_canary`, a record-count pin kept for a recursion-depth measurement | reached by the four members that retry (seeds 8, 18, 31, 109; every one loses its retry records, so the guard counts 0 of 18); the difference is observable and no rule reveals it. A weak oracle: the one gate built for wire-against-trace parity never meets this event |
| **m02** | ADR-003 D2 and D4: the journal's fold reproduces the history (m22, the same edit one function over, is killed by `journal-fold-disagrees`) | nothing red beyond the base sweep under `make dst` (F2) | run by `discovery`, `driver_plus_compose`, `smoke_driver`, `smoke_parity` and `strict_replay` (F1); the flipped flag sits in a journal record none of them is seen to check. Whether they fold that run's journal at all was not checked |
| **m03** | none in ADR-003. The fault catalogue's `approval_deadline_exceeded` class (`dst_fault_catalogue.ail:467`): "with default_allow true the same input resolves to ApprovalAllowed and the class is not exercised" | nothing red beyond the base sweep (F2) | run by `smoke_driver` and `smoke_parity` (F1). *Reading of the source*: `default_allow` decides an approval only when the read hits EOF or the reply is unparseable or an unknown command (`resolve_approval`, `tool_phase.ail:98`), and no run that reaches the line produces one |
| m05 | no ADR-003 rule; WI-D20's comment (`tool_phase.ail:424-452`) says the hook's world must be re-seated from the live world | nothing differs on any row, target or sweep | reached (seed 1), no observable difference. *Judgement*: equivalent on every walked path; differs only on the scratchpad path, "a tool an extension handles", which D6 names as not shown |
| m18 | `publish_turn_exit_manifest`'s comment: the render sees the turn's successor | nothing differs | reached (seed 1), no observable difference. *Judgement*: equivalent while `MOTOKO_EXIT_MANIFEST` is unset (`ext/exit_manifest.ail:203` returns before the ports are used); a run that publishes a manifest would hand its exit intents a world one env read behind |
| m15 | 009 ADR-001 D6.4 | not evaluated | run by no target, under `corpus_judge` (tier 2) or `make dst` (F1): the scratchpad tool, "a tool an extension handles" (D6, known) |
| m08, m26 | none | not evaluated | run by no target. *Judgement*: dead code. m08's `None` arm needs `await_approval` without a pending approval, and the only producer of that reason (`session.ail:3353`) sets one; m26's `[]` arm is called only with pending calls (`step_machine.ail:112-114`). No `make dst` target reaches either (F1), which fits the judgement and does not prove it |

### Not seen by `corpus_judge`, killed elsewhere in the suite

| mutant | stated rule | what `corpus_judge` reports | killed by |
|---|---|---|---|
| m09 | 009 ADR-001 D6.4 parity | its `invalid-request` control reaches the line and stays green: the gate reads only the trace | `ledger_parity`: `ToolArgumentsInvalid: projected 0, returned 1` (F3) |
| m14 | ADR-003 D4: the journal's fold reproduces the final history | `journal-fold-disagrees` on the `solver-feedback` CONTROL row; tier 1 counts JUDGE rows only | the same control row, red again under `make dst`, which runs `corpus_judge` with its controls (F3) |
| m12, m19 | 009 ADR-001 D6.4 | not reached | `ledger_parity`: `DelegatedToolDeferred: projected 0, returned 1` (m12); `NativeToolDenied: projected 1, returned 3` (m19) (F2) |
| m13 | none in ADR-003 | not reached | `journal_resume`: the journal fold refuses with `pairing`, a tool call left unanswered (F2) |
| m17, m23, m30 | D9 (m17); ADR-002 D2's wake match (m23, m30) | not reached: "The corpus never parks" (D6's list) | the stale-world rows of `world_framed_wire` and `park_wake` (m17); `park_wake`'s and `park_resume`'s wake rows (m23, m30) (F2) |

## The yield, read two ways

The brief's yield is the number of new gaps: mutants that are run, that no check names, and that
are not on ADR-003's "Known, and not seen" list. The brief fixed it on reach by a `corpus_judge`
bank member, before any run. The suite-wide reading counts reach by any `make dst` target. It was
not fixed in advance, so it is given beside the brief's reading, not in place of it.

| | as the brief fixed it: reach by a bank member | suite-wide: reach by any `make dst` target |
|---|---|---|
| run, killed by no check: measured | 3: m05, m11, m18 | 5: m02, m03, m05, m11, m18 |
| of these, on ADR-003's "Known, and not seen" list | 0 | 0. m03's class is noted in the fault catalogue, which is not that list |
| after my judgements | **2**: m11, an oracle gap; m18, a reach gap. m05 is not counted: judged to differ only on the extension-handled tool path, which D6's paragraph after the list already names | **4**: m02, m03, m11, m18 |
| the brief's rule says | measured: draw again; after judgement: the operator decides | draw again, on both counts |

**Under the ordinary reading**, where any target red under the mutant and green at base counts,
m11 is caught at tier 4 (`corpus_judge`'s guard and `depth_canary`'s pin), and each count falls by
one. I report the rule reading as the headline because §5.1 and the spike's `M2` make exactly this
distinction: a pin kept for something else, red by accident, is not the property seen.

### Within `corpus_judge`, reach is the larger finding

13 of 30 drawn mutants sit where no bank member runs. Four are on branches ADR-003 already records
as unwalked (parking: m17, m23, m30; an extension-handled tool: m15). Two are dead code by my
judgement (m08, m26). Two are walked only by the gate's own controls (m09, m14). The other five sit
on four branches ADR-003 does not record as unwalked: the response-intercept arm (m02), an approval
timeout that allows (m03), the delegated backend (m12) and a policy that denies (m13, m19).

Reach was probed under `corpus_judge` only: tier 2 ran each probe through `make corpus_judge`, so
"not reached" means not reached by its 18 members and 5 controls, not by the DST suite (amendment
A5). F1 to F3 measured the rest of the suite.

### Follow-up F1: the same probes under `make dst`

Run on 2026-11-19 at the operator's request (`reach-dst-plan.md`, `reach-dst-results.md`). The 11
probes not reached by `corpus_judge`, plus the positive control, each ran through a full `make
dst`. A site counts as reached only when the probe's own runtime error appears at its file and
line. The scorer and its reading rules were fixed and hashed before the sweeps produced any result.

| site | the branch | under `make dst` | targets that printed the probe's error |
|---|---|---|---|
| m02 | the response-intercept arm | **reached** | discovery, driver_plus_compose, smoke_driver, smoke_parity, strict_replay |
| m03 | an approval timeout that allows | **reached** | smoke_driver, smoke_parity |
| m12 | the delegated backend | **reached** | ledger_parity, world_framed_wire (read by hand: both hide the error) |
| m13, m19 | a policy that denies | **reached** | compaction_dst, journal_resume, smoke_driver, smoke_parity, terminal_trace, world_state |
| m17, m23, m30 | open waits and wakes | **reached** | park_resume (all three); driver_plus_herdr and herdr_graded (m17, m30) |
| m15 | the scratchpad tool | not reached | none |
| m08, m26 | judged dead code | not reached | none |

So **"not reached" was a `corpus_judge` finding, not a suite-wide one.** Across the suite, the
one reach gap among these sites is m15, which ADR-003 D6 already names. The predictions came from
a text search of `scripts/dst/` and held for 8 of 12: m02, m03 and m12 were predicted unreached, and
m15 was predicted reached. Two side observations. `ledger_parity` and `world_framed_wire` print only
a failed program's `✗` rows and delete the rest, so m12's probe crash showed only as a missing frame
end; `scripts/run_program.sh` re-ran that one program with its output kept to read it, by a rule
logged before it ran. And the targets listed are those that *printed* the error, a lower bound:
under F2, `park_wake` and `world_framed_wire` went red on m17's mutant, so they run its line too.

### Follow-ups F2 and F3: every reached mutant under `make dst`

F2 ran the 8 mutants at F1's reached sites on 2026-11-19 (`mutants-dst-plan.md`,
`mutants-dst-results.md`). F3 ran m09 and m14, reached only by `corpus_judge`'s controls, on
2026-11-20 (`mutants-dst-f3-plan.md`, `mutants-dst-f3-results.md`). Each mutant ran through a full
`make dst`, by the unchanged `run_gate.sh` and `score_dst.py`, with its plan and predictions hashed
before the first sweep. Every red target's output was read by hand, and a red counts only if a
failing check is about the broken behaviour, as at tier 4 (deviation 1). F3's plan fixed one more
reading before its sweeps: at the suite level a `corpus_judge` CONTROL row red on the broken rule
counts, since `make dst` runs `corpus_judge` with its controls. The tier-1 verdicts, which count
JUDGE rows only, are unchanged.

| mutant | the edit | under `make dst` | the check about the broken behaviour |
|---|---|---|---|
| m12 | delegated tool's event not emitted | **killed** | `ledger_parity`: `DelegatedToolDeferred: projected 0, returned 1` |
| m19 | policy-denied call's event not emitted | **killed** | `ledger_parity`: `NativeToolDenied: projected 1, returned 3` |
| m13 | policy-denied call's denial message dropped | **killed** | `journal_resume`: the journal fold refuses with `pairing`, a tool call left unanswered |
| m17 | await-wake state keeps the pre-step world | **killed** | `world_framed_wire`: ordinal 15 repeated (stale-world re-request); `park_wake`: stale world |
| m23 | a wake reply with OperatorInput/HostError/Aborted is dropped | **killed** | `park_wake`'s `operator_input`, `host_error` and `abort` rows; `park_resume`'s `resume_aborted` |
| m30 | wake match: `&&` becomes `\|\|` | **killed** | `park_resume`'s `resume_dropped`; `park_wake`'s `wrong_handle` rows |
| m02 | intercept arm journals its messages as replacing the previous entry | not killed | none: nothing red beyond C-base |
| m03 | `AllowAfterTimeout` means deny | not killed | none: nothing red beyond C-base |
| m09 | `tool_arguments_invalid` not emitted to the wire | **killed** | `ledger_parity`: `ToolArgumentsInvalid: projected 0, returned 1` |
| m14 | injected user message journaled but not added to the history | **killed** | `corpus_judge`: `CONTROL solver-feedback journal-fold-disagrees RED` |

The other reds under m13, m17, m23 and m30 (count pins, a census row, the herdr discovery grade,
`test_coverage`) are listed in `mutants-dst-results.md` and not counted. Under m14, `phase_c_l1` also fails two decision-sequence pins for the guards that inject a
message; they are listed in `mutants-dst-f3-results.md` and not counted.

The predictions held for 7 of F2's 8 (m03 was predicted killed) and both of F3's, with the check named. Every sweep
restored the tree to `base.sha256`.

## Per operator

Across the suite. The pilot's version of this table, by tier, is in `README-pre-a8.md`.

| operator | drawn | did not type-check | killed | of these, by a `corpus_judge` rule on a member | run, no check | run by no target |
|---|---|---|---|---|---|---|
| SR.world (keep the predecessor) | 9 | 0 | 7 | 2 | 2 (m05, m18, both judged equivalent) | 0 |
| SR.record (dropped record) | 6 | 0 | 5 | 2 | 1 (m11) | 0 |
| SR.stmt (statement removed) | 11 | 5 | 5 | 0 | 0 | 1 (m15) |
| BF (boolean flip) | 7 | 0 | 3 | 1 | 2 (m02, m03) | 2 (m08, m26, judged dead code) |
| CF (comparison flip) | 1 | 0 | 1 | 0 | 0 | 0 |
| MAS (match-arm swap) | 4 | 3 | 1 | 0 | 0 | 0 |
| OBO (off-by-one) | 0 | - | - | - | - | - |
| **all** | **38** | **8** | **22** | **5** | **5** | **3** |

- **Keep-the-predecessor paid best**: 7 of 9 killed, and all three tier-3 kills that changed whole
  trajectories (m01, m04, m29) came from it.
- **Statement removal of a named `let` produced only noise.** Its definition took a name bound
  earlier in the text as a shadow, and five of five such draws were names bound only in a sibling
  match arm. **Match-arm swap** mostly fails on pattern variables (3 of 4).
- **Boolean flips mostly landed where `corpus_judge` does not run** (6 of 7). Across the suite 3 of
  the 7 are killed, and boolean flips gave both reached survivors (m02, m03) and both dead-code
  sites.
- **Off-by-one was never drawn**: 17 of 311 site-operator pairs, none in the first 38 ranks. The
  pilot says nothing about it, or about comparison flips beyond one mutant.

## Predictions against outcomes

The pilot's were written and hashed before any gate ran (`predictions.tsv`, sequence.log `STEP6`),
per mutant in `mutants.tsv`'s last two columns. Each follow-up's were hashed before its own runs.

| | right | wrong |
|---|---|---|
| tier-1 state (kill, red without a kill, green) | 30 | 0 |
| reached by a member or not (the 25 probed) | 24 | 1: m20, predicted unreached by members; every native dispatch evaluates the statement, and it cannot differ there only because the bank runs in `Legacy`. (m05's predicted member set, "members that run an approved tool", was also too narrow: every approval read reaches it) |
| final verdict | 23 | 7: **m01, m04, m28, m29** predicted unkilled, with `discovery` named only as a "maybe" in the namer column (m04's for another reason than the one given: the hook's successor, not the clock read's); **m10** predicted unkilled (tiers 1-3 were green; `make dst` has three checks that read deny reasons); **m11** predicted a `ledger_parity` kill (it does not witness retries); **m20** predicted unkilled and unreached by members (killed at tier 3 by `ledger_parity`'s Limits subject) |
| reached under `make dst` (F1: 11 probes and the control) | 8 | 4: m02, m03 and m12 predicted unreached; m15 predicted reached |
| killed under `make dst` (F2 and F3: 10 mutants) | 9 | 1: m03, predicted killed by `smoke_driver` |

The pilot's misses lean one way: six of the seven predicted a survivor where a tier-3 or tier-4
check killed it. I underrated the scripted gates outside `corpus_judge`. F2's one miss went the
other way.

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
and not clocked separately. Follow-ups F1, F2 and F3 added 12, 8 and 2 `make dst` sweeps, taking
6,952 s, 5,537 s and 1,622 s.

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
selftest`). Follow-ups F1 to F3 used the same runner, scorer and integrity check, and each fixed
its plan, predictions and reading rules in `sequence.log` before its first run.

## Deviations from the brief

1. **The kill rule was applied literally.** At tier 1 only `JUDGE <member> <rule id> RED`
   counts; CONTROL rows, guards and not-evaluated rows are recorded beside it. At tiers 3 and 4 a
   kill is a failing check about the broken behaviour; m11's tier-4 reds (a vacuity guard and a
   count pin) are recorded and not counted, and the yield is given under both readings.
2. **Tier 3 ran only on mutants a bank member reaches**, as the brief words it. m09 and m14,
   reached only by a `corpus_judge` control, stopped at tier 2; F3 ran them under `make dst`.
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
7. **Eight amendments**, each dated, hashed and kept beside what it replaced (`AMENDMENTS.md`):
   A1, before the draw, the enumerator against `operators.md` (409 candidates became 399); A2 and
   A3, the scorer (v0.60.4's runtime-error wording; members counted once); A4, the runner keeps
   `corpus_pr`'s whole output. A5 to A8 came after the pilot was committed: the reach wording,
   F1's results, F2's, and F3's with the suite-wide reframing.
8. **The machine was shared.** Load stayed between 6 and 15 from other sessions. `corpus_pr`
   never failed on its ceiling, so the brief's single re-run was never needed.
9. **The headline was reframed after the runs (A8).** The brief graded `corpus_judge`. The operator
   asked for the whole suite to lead. The suite-wide verdicts rest on runs and reading rules each
   fixed before its runs (the pilot's tiers, F1 to F3), but the framing and the suite-wide yield were
   not fixed before the pilot. The pilot's verdicts, counts and yield are unchanged and given beside
   them.

## What was not verified

- **The four judgements** (m05, m18 equivalent on walked paths; m08, m26 dead code) rest on
  reading the source, not on a run that could tell them apart.
- **Kills at tiers 1 and 3 were not re-run in a full `make dst` sweep.** They count across the
  suite because `make dst` runs the same make target with the same recipe.
- **Why `ledger_parity`'s census row `order` goes red under m01, m04 and m29.** Probably the
  trajectory change; not traced. Those three are killed by other checks either way.
- **m20's `strict_replay` run ends on a recursion-depth runtime error** after its Limits rows go
  red. Recorded as a panic, not a kill; the cause was not traced.
- **m01's failing `corpus_pr` row is not recorded.** The recipe shows only its last 40 lines, and
  the full output was overwritten before amendment A4.
- **Reach was measured to the first member that reaches a site**, not per member, and F1's lists
  of reaching targets are a lower bound (only targets that printed the probe's error).
- **F2 and F3 ran one sweep per mutant.** Their own lists of what was not verified are in
  `mutants-dst-results.md` and `mutants-dst-f3-results.md`. They include why m02 survives (whether
  the targets that run the intercept arm fold that run's journal).
- **`corpus_pr` writes a fixed `/tmp/corpus_pr.out`.** A concurrent `corpus_pr` from another
  session would have overwritten the file A4 copies; none was seen, and it cannot be excluded.
- **Whether one mutant per line is enough** (the Google result) under property verdicts. Not
  tested; one candidate was drawn per line.

## Recommendation

**By the rule as the brief fixed it** (reach by a bank member), the result is **"three or more:
draw again" on the measured count (m05, m11, m18) and "one or two: the operator decides" once my
judgements are applied (m11, m18)**. The two readings differ by one judgement: that m05 changes
nothing except on the extension-handled tool path, which ADR-003 D6 already names. I think that
judgement is sound (`tool_phase.ail:451` re-seats the world before the only reader on every other
path). **Read suite-wide**, the rule says "draw again" on both counts: 5 measured, 4 after
judgement (m02, m03, m11, m18).

**My recommendation changes with A8: draw a second batch, and run it straight through `make dst`.**
Before F1 to F3 I recommended waiting, because 13 of 30 draws had landed where `corpus_judge` does
not run, so a second draw of the same shape would mostly re-measure that. Across the suite only 3
of 30 sit where no target runs, and two of those are dead code by my judgement. A second batch would
measure what the suite kills at the sites it runs, which this batch measured once: 22 of the 27
mutants it runs. Run each new mutant through a full `make dst` with the rule reading, and keep
`corpus_judge` as a cheap first pass only to fill its column. At 5 to 16 minutes a sweep here, 30
mutants are about 6 hours of machine time, plus triage. The same population, operators and seed
scheme apply unchanged, with the next 30 type-checking sites taken from `draw-order.tsv` after rank
38.

**Alongside it, four rulings**, each either a check that notices the mutant or a place on the known
list:

- **m02**: should a target that runs the intercept arm fold its journal against the history, as
  `corpus_judge`'s rule does for its members?
- **m03**: should a run resolve an approval by EOF or an unparseable reply with `default_allow`
  true? The fault catalogue already records that none does.
- **m11**: should the retry record's wire-against-trace parity be witnessed? `ledger_parity` does
  this for other events and never meets this one.
- **m18**: should an exit-manifest publication be walked?

For `corpus_judge` itself, one question remains: whether its bank should walk the four branches the
rest of `make dst` already walks (the intercept arm, an allowing timeout, the delegated backend, a
denying policy).

## Files

| file | what |
|---|---|
| `sequence.log` | every step, in order, with times and hashes, and every run's integrity check |
| `base.txt`, `base.sha256` | the base commit and toolchain; the four files' hashes |
| `population.md`, `population.tsv`, `population-accounting.tsv` | the rule, the 31 functions, all 133 reachable with their verdict |
| `operators.md`, `AMENDMENTS.md` | the five operators; A1 to A8 |
| `README-pre-a5.md` | this page as first committed in `94b0f678`, kept beside it by A5 |
| `README-pre-a6.md` | this page after A5 (`fb1f9779`), kept beside it by A6 |
| `README-pre-a7.md` | this page after A6 (`2d16ada5`), kept beside it by A7 |
| `README-pre-a8.md` | this page after A7 (`9c519862`), kept beside it by A8: the last version that led with the `corpus_judge` result |
| `reach-dst-plan.md`, `reach-dst-scores.tsv`, `reach-dst-results.md` | follow-up F1: the plan and predictions, the scorer's readings, the write-up |
| `runs/program/ledger_parity_dst/X-m12/` | F1's one hand-reading run, with the program's output kept |
| `mutants-dst-plan.md`, `score-dst-selftest-f2.txt`, `mutants-dst-scores.txt`, `mutants-dst-new-rows.txt`, `mutants-dst-results.md` | follow-up F2: the plan and predictions, the scorer's self-test before F2, its readings, each sweep's failing rows not in C-base, the write-up |
| `mutants-dst-f3-plan.md`, `score-dst-selftest-f3.txt`, `mutants-dst-f3-scores.txt`, `mutants-dst-f3-new-rows.txt`, `mutants-dst-f3-results.md` | follow-up F3, the same for m09 and m14 |
| `enumeration/`, `enumeration-a1/` | STEP4's enumeration as first run; the amended one the draw used |
| `draw-order.tsv`, `draw-checked.tsv`, `draw-check.log` | the seeded order of all 265 sites; the 38 walked with their type check |
| `predictions.tsv` | the predictions, hashed before any gate ran |
| `typecheck-calibration.txt`, `calibration-scores.tsv` | the type-check filter's calibration; the gate's |
| `tier1-scores.tsv`, `reach-probes.tsv`, `tier4-scores.txt` | each tier as its scorer read it |
| `triage.tsv` | the judgement per mutant: verdict, stated rule, checker, known list, prediction outcome |
| `mutants.tsv` | everything per drawn site, assembled by `scripts/assemble.py` from the above (the pilot's tiers only) |
| `runs/<target>/<id>/` | each run: `out.txt` (non-wire lines), `mutant.diff`, `apply.log`, `rc`; `corpus_pr` runs after A4 also keep `full.txt` |
| `scripts/` | `ailsrc.py` (tokenizer), `population.py`, `mutator.py`, `draw.py`, `fixed_edits.py` (controls and probes), `run_gate.sh`, `run_tier3.sh`, `run_tier4.sh`, the scorers and their self-tests, `assemble.py`, F1's `score_reach_dst.py` and `run_program.sh`, and `new_rows_dst.py` (a reading aid written after F2's sweeps, used again for F3); `*-step3.py`, `*-pre-a*.*` are the versions amendments replaced |

Every run used the scratch worktree `/workspaces/motoko_agent-039-pilot-scratch`. It was removed on
2026-11-20 after F2, added again at `dd8a12f1` for F3, and removed again after F3, clean at
`dd8a12f1` each time (`sequence.log`). To re-run a step, add a detached worktree at `dd8a12f1` and
point `PILOT_SCRATCH` at it.
