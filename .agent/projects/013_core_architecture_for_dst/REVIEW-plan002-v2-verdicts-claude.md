# PLAN-002 v2 focused re-review verdicts

Date: 2026-09-13
Reviewed HEAD: `d888585` (`git rev-parse --short HEAD`), branch `arniwesth/013-plan003-and-herdr`
(`git branch --show-current`).
Subject: `PLAN-002-implement-adr-002.md` v2, untracked, 1231 lines by `wc -l`. `plan:NNN` is that
working-tree file.
Checklist: the 24 required changes in `REVIEW-plan002-v1-verdicts-claude.md` (`review1:417–533`).

**Method.** Every code coordinate below was read with `git show HEAD:<path>`, and ADR text was
read from the working tree. No sweep, no DST target and no test was run. HEAD has not moved since
v1 was grounded, so no coordinate has drifted.

## Overall verdict

**ACCEPT WITH CORRECTIONS.**

| item | may start? | why |
|---|---|---|
| W1a | **now** | unchanged |
| W2 | **now** | R6 and R7 are text fixes that change no design |
| W3 | **now** | R8 is a one-value fixture pin |
| W1b | **after R4** | one sentence plus one gate bullet: the TTY one-shot exit must drain the logger |
| W4 | **after R1, R2, R3, R5** | R1 is substantive: the Q3 re-issue bound in v2 is still unreachable |
| W5 | after W4's live gate, as before | R9 and R10 are minor |

- **Counts.** 21 of 24 changes are fully applied and 3 are partial (13, 3, 15). There are **11
  required changes**:
  - 4 are substantive: R1–R4;
  - 7 are minor: R5–R11.
- **Decisions.** No ADR-002 decision is reopened. The seven owner decisions (§8.1–§8.7) are
  transcribed faithfully into the work items.
- **Blocks released.** Both sign-off blocks are released in the text:
  - §8.6: plan:1153, "W3 Part 1 is unblocked";
  - §8.7: plan:1165, "W4 Part 5 is unblocked";
  - handoff: plan:1071, "no item waits on §8".
- **R1 needs the owner.** It corrects the *mechanism* under §8.3 without changing its intent (a
  step charge bounded by the existing budget). The owner should still note it, because §8.3's text
  names a check the re-issue path never reaches.

## Per-change table

| # | item | verdict | evidence (plan line → HEAD) |
|---|---|---|---|
| 1 | W1b: `err_result` branches gain `settled` metadata | **applied** | plan:243–251. Both arms of `do_check_motoko`'s failure branch are named: gone `:1470–1474`, error-only `:1475`, shared return `:1476`. `err_result` sets `metadata: jo([])` (`herdr.ail:244–247`) ✓. Extended to `do_check`'s arms at `:1605–1610`, `:1621–1626`, `:1543`, `:1549` (plan:252–255), all ✓ at HEAD. Gate plan:270–273 ✓. Nit: R11. |
| 2 | W1b: `DelegateWait.id` = handle matching key | **applied** | plan:224–232, W2 row plan:360, gate plan:274–275. `meta_kind` writes `delegate` = name (`herdr.ail:192`), and `meta_timed` does too (`:201`). `motoko_handle` `:1310` passed at `:1322` ✓. claude/codex `name` at `:1403` ✓. `DelegateCheck` `name` at `:1540` ✓. |
| 3 | W1b: interactive one-shot writer site | **partial** | Site named (plan:179–183): `spawnRuntimeProcess` `index.ts:1017`, callback `:1033`, `logger.log` then `ui.handleEvent` at `:1052–1053` ✓. `taskDone` at `ui.ts:2761` ✓. **New defect N2:** the one-shot exit taken "at this site" does not await `logger.close()` (R4). |
| 4 | W2: `ExtCtx` ABI change (Json, 7.4, package tests, literal list, re-price) | **applied** (minor residual) | plan:316–341 and gate 7 plan:444–449. `types.ail:12–13` imports only `std` ✓. `state_key:` grep = 38 lines in 29 files ✓; minus `types.ail:548` gives 37 in 28 ✓. The per-directory split is exact: packages 7/12, `scripts/dst` 6/7, `scripts` 12/12, core 3/6. `ailang.toml` `version = "7.3"` ✓. Residuals (R6): the W2 heading still says "4–6 days, core" (plan:283), and `ailang.lock:75–77` pins `"version": "7.3"`, which the plan does not name. |
| 5 | W2: literal counts and `C2LoopState` range | **applied** | plan:294–315. Type `:509–569` ✓. 13 full `let next_state: C2LoopState = {` literals at exactly the 13 cited lines ✓. Record updates `:3197`, `:3231` ✓. Constructors `:951`, `:2591` ✓. Tests `:5067`, `:5120` ✓. `StepState` has 10 literals: `step_machine.ail:176`, `c2_step_state`, `phase_vocab.ail:1595`; scripts `phase_c_l1_scenarios.ail:148/:297/:329/:451`, `phase_c_seeded_dst.ail:158`, `phase_f_pipeline_wiring.ail:65`, `scratchpad/verify_guard.ail:40`. All ✓, and the `nudges_used: 0` grep finds no others. |
| 6 | W2: gate 2 host target, per-case setup, gate 3 label | **applied** | plan:402–423. `phase_c_l1` `Makefile:386–389` ✓, in `DST_TARGETS` `:483` ✓. Persist nudge off by default at `session.ail:2262–2263` ✓. `phase_c2_wiring_scenarios.ail:73` already imports `empty_stop_guard`, so case (d) is feasible ✓. Gate 3 is labelled "Regression only, not proof of order" ✓. |
| 7 | W2: cross-producer gate | **applied** (minor residual) | Gate 6 plan:432–443. Residual R7: plan:443 "added with W1b" contradicts plan:279 "No core file is touched". |
| 8 | W3: mutant rewrite | **applied** (minor residual) | plan:524–553 and gate plan:566–569. "Must report unresolved" is removed, and the reason is cited (`derive.py:192–200` ✓). The unhelped-receiver mutant is forbidden (plan:530–532). W3 ships a fixture-directory case (`fixtures/expected.json` exists with that shape ✓). W4 ships the `TREE_MUTANTS` entry (`derive.py:585–610`, runner `:613–640`, exit-publish precedent `:604–609` ✓, verdict names exist `:364–370` ✓). Red-first is kept. Residual R8: wrong verdict family named. |
| 9 | W3: T0 check, `WorldState` literals, lenient decode | **applied** | T0 at plan:560–562. Three full literals: `ports.ail:763–767` ✓, `ext_world.ail:584–597` ✓, `:693` ✓. `dst_replay.ail:1170` is a record update (`{ empty_world_state() \| …`, `:1169`) ✓. Every script world found by an `approvals:` grep is a record update too (`discovery_dst` `:284`/`:1497`, `driver_plus_compose` `:641`, `herdr_graded` `:219`, `latency_pair` `:217`, `ledger_parity` `:316`, `world_state_probe` `:857`) ✓. Lenient decode is stated as intended (plan:509–512) ✓. |
| 10 | W3: `WakeObservation` flagged, now §8.6 | **applied** | §1 row 8 plan:112; §8.6 plan:1146–1153 "SIGNED OFF … W3 Part 1 is unblocked"; handoff plan:1071 ✓. |
| 11 | W4: arm reads `open_waits`, placement | **applied** | plan:587–616. The arm sits before `:130–131` and after the inject arms `:124–129` ✓ (`step_machine.ail`). Tests now match the design, including `await_wake` × no waits → `call_model_or_fail` `:140` ✓. |
| 12 | W4: `wait_id` matching rule (v1, intact) | **applied** | plan:639–643 ✓. Reused consistently in Part 5's `Aborted` rows (plan:731–733). |
| 13 | W4: Q3 mechanics (bound, no re-emit, attempt, fixture) | **partial: deficient** | plan:644–656 and §8.3 plan:1118–1127. "No re-emit" ✓, "attempt field" ✓ and the fixture assertions ✓ are stated. **The bound is still not a bound (N1):** `step_idx + 1` is charged, but the re-issue re-enters the `Park` arm (plan:676). That arm (plan:591–594) precedes and bypasses `call_model_or_fail` (`step_machine.ail:96–105`), the only budget check. The "`user_injected → call_model_or_fail` route" is the *accepted*-wake continuation (plan:669–671), not the re-issue. Also unstated: whether a dropped reply emits `WakeReceived`, and where `attempt` comes from (R2). |
| 14 | W4/W5: `.p0` collision (v1, intact) | **applied** (minor residual) | plan:685, :885–892, §8.4 plan:1128–1137, W5 gate 1 plan:923–924. Consistent with `ADR-003:545–547` ✓. Residual R9: no constructor is named for `park_ordinal = 1`, and the rule is scoped to "the resumer path" only. |
| 15 | W4: mid-park table, input-guard re-cite, §8.7 | **partial** | Table plan:720–729 has every column the review asked for. Guard re-cited as `shouldLockPlainInput` `ui.ts:1798–1804` ✓; `:2218` confirmed as the spinner tick ✓. Coordinates ✓: `:4357`, `:4378–4390`, `:4352`, `:4354`, `:3023` (non-budget codes → `c2_fail`, which emits no `error` `:2625–2662`), `ui.ts:2147–2157`, `index.ts:1190`. §8.7 signed off, W4 Part 5 unblocked (plan:1165) ✓. **New defect N3** in the host row (plan:739–743), R3. |
| 16 | W4: single-channel metric | **applied** | plan:779–789, gate 7 plan:820. `ProviderCallPrepared` `phase_vocab.ail:1008` ✓; `ProviderIdentity` `dst_interaction.ail:60` ✓. No cross-channel assertion remains. |
| 17 | W4: coordinate fixes, single-site pin | **applied** | `user_injected` `:138–139` (plan:670) ✓; stop class `:130–131`, pending arms `:117–123` (plan:596–598, §9 plan:1186) ✓; single-site pin plan:675–678 and gate 4 plan:806–807 ✓. |
| 18 | W4: gate 9 statements | **applied** (minor residual) | plan:824–834. Q5 retirement ✓, `TimerWait` no producer ✓ (`ADR-002:460–461` ✓), continuation clears waits ✓ (`:2591` ✓; `ADR-002:482` ✓), "both open" producer named ✓ (`ADR-002:473` ✓). Residual R5: that producer is placed at a site with no `open_waits` in scope. |
| 19 | W5: three-turn probe; `:4723`/entry arms in §3 | **applied** | Three turns plan:929–934. §1 row 11 plan:115, W5(c) "Not in (c)" plan:903–909, §3 bullet plan:1003–1007. `session.ail:4722–4723`, `:4755`, `:4759`, `:4766` ✓; `rpc.ail:250`, `:335`, `:434` ✓. |
| 20 | W5: wire-record restatement, turn-opening correction | **applied** (minor residual) | plan:851–865 and gate plan:935–945. `ledger_parity_dst.ail:405–406` (`println`) ✓; `witness_drain` `:4167–4176` ✓; `journal.ail:1036` `world_ordinal` ✓; manifest `env_read` + `witness` `:4582–4583` ✓. Residual R10: the turn-3 delimiter is not named. |
| 21 | W5: Q4 construction and unit test | **applied** | plan:870–879, gate plan:925–927. `run_id_for` `:4269–4271` gives `"s.r0.3"`, so `"s.r0.3.p0"` ✓. `:4404` passes `run_ordinal` ✓. Definition `:4274` ✓. |
| 22 | W5: re-price | **applied** | plan:137, :911–918 (3–4 days, with the declined options stated). |
| 23 | Tiers and §7 entries | **applied** | §5 plan:1056–1061: W5 T1–T4 ✓; W1b/W-O5 T2 as known-red run clauses (`Makefile:655`) ✓. §7 plan:1096–1099 has W2 T3 and W3 T2 ✓. |
| 24 | Cite fixes | **applied** | `C2LoopState :509–569` (plan:291, :1184) ✓; `loop_run_identity` def `:4274` (plan:49, :869, :1184) ✓; `approvals_of :707–718` (plan:702, :1196) ✓. Cosmetic: see N8. |

**Tally: 21 fully applied (7 of them with minor residuals listed as R5–R11); 3 partial (3, 13,
15).**

## New defects introduced by v2

**N1 — the Q3 bound is unreachable** (change 13; plan:644–656, §8.3 plan:1118–1127). Blocks W4.
- Re-issue charges `step_idx + 1` and "re-enters the same `Park` arm" (plan:676).
- `decide`'s new arm (plan:591–594) returns `Park` with no budget test.
- The budget test lives only in `call_model_or_fail` (`step_machine.ail:96–105`), which `Park`
  never reaches.
- **Result:** a host that keeps sending mismatched replies re-issues forever, exactly the v1
  defect.
- The sentence "bounds re-issues through the normal `user_injected → call_model_or_fail` route"
  confuses the re-issue with the accepted-wake continuation (plan:669–671). Taking that route
  literally would cost a provider call per re-issue, and the model's next stop would open a new
  park with a new ordinal. That contradicts "same `request_id`, no ordinal increment".

**N2 — the TTY one-shot exit drops the logger tail** (change 3; plan:179–183, :201–203). Blocks
W1b.
- The non-TTY forward exits only after `logger.close()` resolves (`index.ts:979–983`). The comment
  at `:975–978` records that `process.exit` otherwise drops `run_summary` and `done`.
- `ADR-002:288` describes the terminal path the same way.
- The v2 TTY site sits after a synchronous `logger.log(event)` (`:1052`) and says the one-shot
  exit is "taken at this site, after publication", with no drain.

**N3 — ESC-as-`abort` during a park makes the host synthesize an `error`** (change 15; plan:739–743,
table plan:724). Blocks W4 Part 5.
- `runtimeProcess.abort()` only sends `{type:"abort"}` (`runtime-process.ts:861–863`).
  `killRequested` is set only by `kill()` (`:870–873`).
- The core's `ParkCancelled` path emits neither `done` nor `error` (plan:724; `c2_fail`
  `session.ail:2625–2662`).
- So the child's last event is not in `EXIT_EXPLAINING_EVENTS = {done, error,
  session_resume_refused}` (`:162`, `:691`). The exit handler then emits a synthesized
  unexplained-exit `error` (`:716–717`).
- `index.ts:1095` (`interrupted`) still recovers, but a spurious error is rendered and logged, and
  the headless loggers exit 1. This defeats the plan's own "no `error` event" column.

**N4 — the dropped-reply wake and the `attempt` source are unstated** (change 13; plan:633–656).
- Part 2 orders "witness → emit and append `WakeReceived`" (plan:635–638) *before* the mismatch
  rule (plan:639). Read in order, a dropped reply is recorded as `WakeReceived`, and §6 (plan:1081)
  hands those to ADR-003 D7 as `wake` entries. A resumed run would then see a park with a wake
  child for a reply that was never applied.
- `attempt: int` has no source. `ParkRequest` has no attempt field (plan:462) and `C2LoopState`
  gains no counter. "Re-issue the same `ParkRequest`" (plan:646) also leaves `step` ambiguous once
  `step_idx` is charged.

**N5 — the "both are open" sentence is placed at a site that cannot compute it** (change 18;
plan:617–622). Minor.
- `tool_phase.ail`'s `Handled` arm (`:439–449`) has `call`, `result_env` and `handle_world` in
  scope, not `open_waits`. `open_waits` is folded in the loop (W2 Part 2, plan:348).
- plan:618 calls "model messages byte-identical" W2's gate 4. Gate 4 (plan:424–425) is about
  decision sequences.

**N6 — the W2 heading keeps v1's price** (change 4). Minor. plan:283 reads "4–6 days, core",
against plan:134 and plan:340–341 ("5–7 days", core + extension ABI). The 7.4 bump also relocks
`ailang.lock` (`:75–77`), which is not named.

**N7 — the W1b/W2 file-sharing claim** (change 7). Minor. plan:443 lets W1b add a core test, but
plan:279 says W1b touches no core file.

**N8 — cosmetic, no change required.** §9 plan:1196 puts HEAD's `dst_replay.ail:707–718` in the
"ADR cites (`3ee3d03`)" column. The ADR does not cite `approvals_of`.

**Observation, not a defect.** §8.3's "step budget reads as driver steps" (plan:650–651) makes
`step_idx` non-contiguous across model calls whenever a re-issue happens. `ProviderIdentity`
carries `step` (`dst_interaction.ail:60`). A grep of `dst_invariants.ail` finds no step-contiguity
invariant, so nothing at HEAD goes red. The implementer should still check the step-keyed
consumers.

## Coordinate spot-check (changed or added in v2, re-read at HEAD)

| # | plan cites | HEAD | ✓/✗ |
|---|---|---|---|
| 1 | `herdr.ail:244–247` `err_result`, `metadata: jo([])` | exact | ✓ |
| 2 | `herdr.ail:1470–1476` gone / error-only / shared return | exact | ✓ |
| 3 | `herdr.ail:1489–1500`, `:1505–1517`, `:1518–1532` `meta_timed` returns | exact | ✓ |
| 4 | `herdr.ail:1605–1610`, `:1621–1626`, `:1543`, `:1549` | exact | ✓ |
| 5 | `herdr.ail:1310` `motoko_handle`; `:1540` `name` | exact | ✓ |
| 6 | `index.ts:1017–1054`, `:1052–1053`; `ui.ts:2744–2765` | exact | ✓ |
| 7 | `types.ail:548` `state_key`; `:580` 7.3 note; `:587` `work_in_flight` | exact | ✓ |
| 8 | `session.ail:558–559` count comment; 13 literal lines; `:5067`, `:5120` | exact | ✓ |
| 9 | `phase_c_l1_scenarios.ail:148/:297/:329/:451`; `phase_c_seeded_dst.ail:158`; `phase_f_pipeline_wiring.ail:65`; `verify_guard.ail:40`; `phase_vocab.ail:1595` | exact | ✓ |
| 10 | `Makefile:386–389`, `:483` | exact | ✓ |
| 11 | `session.ail:2262–2263` persist nudge off | exact | ✓ |
| 12 | `ports.ail:763–767`; `ext_world.ail:584–597`, `:693`; `dst_replay.ail:1170` (record update) | exact | ✓ |
| 13 | `derive.py:557` `classify_fixture`; `:580–610`; `:613–640`; `:604–609`; `:286` | `TREE_MUTANTS` list opens `:585` (its comment `:580`) | ✓ |
| 14 | `step_machine.ail:124–129` inject arms; `:130–131`; `:138–139`; `:140` | exact | ✓ |
| 15 | `session.ail:3023` `Fail` arm | exact (`StepBudgetExhausted` → `c2_suspend`, else `c2_fail`) | ✓ |
| 16 | `session.ail:4357`, `:4352`, `:4354`, `:4378–4390` | exact | ✓ |
| 17 | `session.ail:4492–4499`, `:4760–4767` `Err` arms | exact | ✓ |
| 18 | `ui.ts:1798–1804`; `:2147–2157`; `:2218` spinner | exact | ✓ |
| 19 | `index.ts:1068` `writeExit`; `:1190` `onInterrupt` → `kill()` | exact | ✓ |
| 20 | `runtime-process.ts:861–863` `abort`; `:842`; `:862–891` | exact | ✓ |
| 21 | `session.ail:4582–4583`; `:4167–4176`; `:4722–4723`; `:4755`/`:4759`/`:4766` | exact | ✓ |
| 22 | `session.ail:4274`, `:4404`, `:4269–4271` | exact | ✓ |
| 23 | `rpc.ail:250`, `:335`, `:434`; `journal.ail:1036`; `ledger_parity_dst.ail:405–406` | exact | ✓ |
| 24 | `phase_vocab.ail:1008`; `dst_interaction.ail:60` | exact | ✓ |
| 25 | `ADR-002:312–314`, `:397–399`, `:427`, `:460–461`, `:473`, `:482`, `:497–500`; `ADR-003:546–547` | exact | ✓ |

25 rows (about 70 coordinates), with no drift and no wrong coordinate.

## Required changes

**Substantive** (each blocks the item named):

1. **R1 — W4, Q3 bound** (plan:590–595, plan:644–656, §8.3 plan:1118–1127; N1).
   - Put the budget test on the path a re-issue actually takes. Either:
     - `decide`'s arm is guarded:
       `if pol.step_budget > 0 && s.step_idx >= pol.step_budget then Fail({ code:
       "StepBudgetExhausted", … }) else Park(s.open_waits)`; or
     - the driver's re-issue checks the same predicate before calling `wake_read` again.
   - Delete "through the normal `user_injected → call_model_or_fail` route". That route is the
     accepted-wake continuation (plan:669–671).
   - State that exhaustion *suspends* (`session.ail:3024–3025`), with `open_waits` cleared per
     plan:680.
   - Add a `decide` test: stop-class × waits × `step_idx ≥ budget` → not `Park`.
   - The wrong-handle fixture asserts the terminal code.
   - The owner notes the corrected mechanism under §8.3.
2. **R2 — W4, dropped reply and `attempt`** (plan:633–656, §6 plan:1081; N4).
   - Say whether a dropped reply emits or appends `WakeReceived`. Recommended: it does not; it
     is a `warning` plus a log only. Otherwise say that D7 takes only the matching wake as the
     park's child.
   - Name the source of `attempt`: a `C2LoopState` counter reset per `park_ordinal`, or a count of
     prior `WakeIdentity` interactions with equal identity.
   - Say whether `ParkRequest.step` stays at the original `step_idx`.
3. **R3 — W4 host, ESC-as-abort** (plan:739–743; gate 6 plan:816; N3).
   - Abort-during-park must mark the exit as requested: set `killRequested`, or a sibling flag read
     at `runtime-process.ts:716`. Otherwise the exit handler synthesizes an `error`.
   - Add a host test: ESC during a park → no synthesized `error`, and journal `abort`
     (`index.ts:1068`).
4. **R4 — W1b, TTY one-shot exit** (plan:179–183, plan:201–203; gate plan:265; N2).
   - The `--answer-file` one-shot exit at the TTY site runs only after publication **and** after
     `logger.close()` resolves, mirroring `index.ts:979–983` and `ADR-002:288`.
   - Add a gate bullet asserting that `run_summary` and `done` reach the session log before exit.

**Minor** (fix in the item's commit):

5. **R5 — W4 Part 1** (plan:617–622; N5).
   - Move the "both are open" append to the loop's tool fold, where `apply_tool_lifecycle` runs,
     not `tool_phase.ail`'s `Handled` arm (`:439–449`).
   - Replace "which is its gate 4" with an accurate reference: W2 changes no model message, and
     W2 has no gate for message bytes.
6. **R6 — W2 price and lock** (plan:283; plan:325–326; N6).
   - Heading → "5–7 days, core + extension ABI".
   - Add `ailang.lock` (`:75–77`, `"version": "7.3"`) to the bump's relock.
7. **R7 — W1b/W2 shared test** (plan:279, plan:443; N7). State that the one exception to "no core
   file" is the gate-6 test when W2 lands first. Alternatively, W1b ships only the JSON fixtures
   and W2 or a follow-up adds the core test.
8. **R8 — W3 Part 6 fixture verdict** (plan:540–543). An advanced successor with **no** witness
   classifies `advanced-unwitnessed` (`derive.py:228–230`, `:370`), not the
   `witnessed-after-construction` family of `form_witnessed_after_record.ail` (`expected.json`).
   Pin that one value in `expected.json`.
9. **R9 — `park_ordinal = 1`** (plan:685, plan:889–891, W5 gate 1 plan:923–924).
   - Name the pure function or constructor parameter that yields 1. W5 lands no seeded path, so
     gate 1 currently has nothing to call.
   - State the rule for **every** run opened by a consumed between-turn wake: in-process (§3's
     future park) as well as resumed. plan:889 says "the resumer path" only, which leaves the
     in-process case at `.p0`.
10. **R10 — W5 gate 2 delimiter** (plan:864–865, plan:942–943). Name `session_start`, emitted by
    the `user_message` arm (`session.ail:4405–4410`) before the run, as the stdout record that
    separates between-turn `world_request`s from turn 3's first request.
11. **R11 — W1b `settled` on argument errors** (plan:252–255). `do_check`'s argument-error arms
    (`herdr.ail:1543`, `:1549`) and its wait-failure arm (`:1610`) have no pane in scope. Say what
    `meta_timed`'s `pane` is there (`""`), and that `delegate` there is the raw `name`, so W2's
    lifecycle never matches it (`settled: false`).

**Required changes: 11** (4 substantive, 7 minor). None reopens an ADR-002 decision. R1 corrects
the mechanism under owner decision §8.3 and should be noted by the owner. W1a, W2 and W3 may start
now.
