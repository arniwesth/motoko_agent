# PLAN-002 v1 adversarial review verdicts

Date: 2026-09-13
Reviewed HEAD: `d888585749c4c1b6244b91a9f7dcfdbf548b8548` (`git rev-parse HEAD`, branch
`arniwesth/013-plan003-and-herdr` per `git branch --show-current`).
Subject: `PLAN-002-implement-adr-002.md` v1. The file is **untracked**, so the `plan:NNN`
line numbers below are the working-tree file as read at review time (843 lines by `wc -l`).
Against:
- `ADR-002-park-and-wake.md` v4.2 (the governing ADR);
- `REVIEW-adr002-v4-verdicts-fable.md` (the standard this review follows);
- `REVIEW-adr002-v4.1-v4.2-delta-verdicts-claude.md` (its five required changes).

**Drift.** None. The plan is grounded at `d888585` and HEAD *is* `d888585`. P3ORD is that
commit, not a later one, so the brief's premise that "P3ORD landed after the plan's
grounding" does not hold. The only dirty tracked file is `ailang.lock`, which nothing here
cites. Every code coordinate was read with `git show HEAD:<path>`. No sweep, no DST target and
no test was run. No live measurement was re-derived.

## Overall verdict

**ACCEPT WITH CORRECTIONS. W1a may start now. Every other item has corrections to apply before
it starts. W4 is rejected as written.**

The plan does what the delta review asked:
- All five of the delta review's required changes are applied in the work items, not just in
  §1 (§1 of this review).
- All 14 of §1's "ADR text residual" rows hold at HEAD source.
- 159 of the 166 load-bearing coordinates checked are exact.

The defects are in the **mechanics and gates the plan adds**, and six are serious:

1. **W4's `decide` design and W4's own `decide` tests contradict each other.** Part 1 adds one
   arm, `"await_wake" → Park`. It also requires "each stop-class reason × open waits → `Park`"
   and "empty × waits → `Park`". `decide` dispatches on `last_finish_reason` alone
   (`step_machine.ail:116–141`), so a state with reason `stop` and open waits still hits
   `:130–131` → `Finalize`. W4 gate 1 cannot pass as written.
2. **The mismatch rule drops the unbound default's own reply, and Q3 then loops forever.**
   - W4 Part 2 drops any reply whose `request_id` **or `wait_id`** does not match.
   - W3 Part 3's `wake_read_unbound` returns `wait_id: ""`.
   - `HostError`, `OperatorInput` and `Aborted` name no wait either.

   So the missing-wake control's `HostError` gets dropped. Q3 then re-issues the same request
   against an empty queue, which returns the same `HostError`, and so on.
3. **Q3's "bounded by the step cap" is not a bound.** The step cap is checked only inside
   `call_model_or_fail` (`step_machine.ail:96–105`). A re-issued park goes from `Park` straight
   to `wake_read`, never passes through it, and does not increment `step_idx`.
4. **Q4 plus `park_ordinal = 0` produces duplicate request ids.** Under Q4 the between-turn park
   is `<next run_id>.p0`. W4 Part 2 starts `park_ordinal` at zero in every constructor, so that
   run's first in-turn park is also `<run_id>.p0`. ADR-002's uniqueness claim
   (`ADR-002:373–375`) and ADR-003 D7's exactly-once rule both key on this id.
5. **W5 gate 2 fails even if W5(c) is implemented exactly.** In the live probe, the first
   `user_message` is consumed by `await_first_task` (`rpc.ail:250`, `:335`). It then runs as
   the *initial* turn of `run_v2_with_conversation` (`rpc.ail:434` → `session.ail:4722`). That
   turn's manifest successor is dropped at **`:4723`**, a second `let _ =` the plan does not
   name. The loop is then entered with the pre-turn world (`:4759`) or even the pre-init world
   (`:4755`, `:4766`). W5 gate 2 also asserts "frames" on a live wire that has no frame
   records.
6. **W2's `ExtCtx.open_waits` changes the extension ABI, and the plan prices it as core-only.**
   - `packages/motoko-ext-abi/types.ail` imports only `std` (`:12–13`), so it cannot name
     `phase_vocab`'s `WaitDescriptor`.
   - `ExtCtx` has full literals in **29 files** (`state_key:` grep): extension packages,
     harness scripts, `rpc.ail`, `session.ail` and `ext/runtime.ail`.
   - W2's gate runs no package test.

Owner decisions: Q1 and Q2 are carried into the work items faithfully. Q5 is carried only in
part (W4 has no retirement step). **Q3 and Q4 are not**: W4 Part 2 and W5(b) each point to §8
and give no mechanics, and the mechanics the pointers imply are broken (items 2–4 above).

| Item | Verdict | Short reason |
|---|---|---|
| W1a | **ACCEPT** | A probe that decides nothing. Procedure and gate match ADR D1.1's "Not decided". |
| W1b | **ACCEPT WITH CORRECTIONS** | The `settled` producer cannot ride `meta_timed` on the lost and error-only branches, which return `err_result` with no metadata (`herdr.ail:1476`, `:244`). There is no key to match a check to its wait. The answer writer is placed on the non-TTY path only, but the gate also tests the interactive one-shot. |
| W2 | **ACCEPT WITH CORRECTIONS** | Stage 3 being inert while registration is live is sound. But the `ExtCtx` field is an unpriced ABI change. Gate 3 cannot see an ordering bug by construction. Gate 2's harness needs solver guards and a verifier it does not have today. |
| W3 | **ACCEPT WITH CORRECTIONS** | "No session call site" holds. But once Part 5 puts `st.provider.wake_read` in `HELPED`, the mutant cannot come out "unresolved" (`derive.py:192–200`), and the mutant harness only does same-line anchor edits. |
| W4 | **REJECT (as written)** | The `decide` gate contradicts the design (item 1). The mismatch rule plus Q3 loops (items 2–3). Request ids collide (item 4). Mid-park `abort`/`exit`/`restart` have no target in core, the input-route coordinate is wrong, and the metric mixes two channels. No ADR decision needs reopening, but the bound mechanism behind Q3 needs the owner's confirmation. |
| W5 | **ACCEPT WITH CORRECTIONS** | Gate 2 fails as written (item 5). (b) has no gate and no Q4 mechanics. The 2–4 day price leaves out the initial-turn successor and a live frame representation. It cannot start before W4's live gate anyway. |
| W-O5 | **ACCEPT WITH CORRECTIONS** | The trigger transcribes Q2 faithfully. Q5's retirement has no step in W4. |

## 1. Did the plan apply the delta review's five required changes?

| # | delta required | applied where | verified at HEAD |
|---|---|---|---|
| 1 | default is `advance` only; flip `world_ordinal.ail:112` and `ext_world.ail:811–823`; edit `derive.py:21`/`:164`; step 4 owes a witness | §1 row 1 (plan:100); W3 Part 2 flips (plan:354–359), Part 5 (plan:389–394), Part 3 default (plan:364–368); W4 Part 2 witness (plan:456–458) | ✓ `advance` `world_ordinal.ail:33–36`; negative test `:112`; forged `"wake_read"` `ext_world.ail:815`; freeze note `derive.py:21`; `REQUEST_CLASS` `:164`; `witness` `session.ail:4163` |
| 2 | name `ledger_parity` dp7 and `smoke_v2_dp7_gate` as step 2's gate; define blank | §1 row 2 (plan:101), §0.2 rule 6 (plan:78–81), W2 gate 3 (plan:318–321); stage-2 world question W2 Part 4 (plan:294–300) | ✓ `ledger_parity_dst.ail:260–263` (`exit 3`, empty registry), scenario `:493–500`; `smoke_v2_dp7_gate.ail:38–41`; `is_blank` `empty_stop_guard.ail:8–10`; `progress_contract_guard.ail:204`; floor `session.ail:3058` |
| 3 | `Park` carries only waits; the driver builds `ParkRequest` | §1 row 3 (plan:102); W4 Part 2 (plan:451–453) | ✓ `StepState` `phase_vocab.ail:424–434` has neither `run_id` nor an ordinal |
| 4 | 45 s; `herdr_graded` known red | §1 row 4 (plan:103); §0.2 rule 1 (plan:58–64); W-O5 (plan:627) | ✓ `register.ail:173`; `DST_KNOWN_RED` `Makefile:655` |
| 5 | cite HEAD | §9 (plan:782–824) | ✓ 159/166 exact (§9 below) |

**All five applied.**

## 2. §1's fourteen rows, verified at HEAD source

| row | claim | verdict | evidence |
|---|---|---|---|
| 1 | P2 landed; `advance` only | ✓ | `ports.ail:493–494`; `world_ordinal.ail:33–36` |
| 2 | two verifier-enabled fixtures, empty registries | ✓ | as §1 row 2 above |
| 3 | `Park` carries waits only | ✓ | `phase_vocab.ail:424–434` |
| 4 | 45 s | ✓ | `register.ail:173` |
| 5 | HEAD coordinates | ✓ with 7 exceptions | §9 |
| 6 | blank = `trim == ""` at three sites | ✓ | the three sites agree |
| 7 | a blank candidate that clears stage 4 is still verified, as at HEAD | ✓ | `NoDecision` with no nudge → `c2_after_dp7` `session.ail:3794`; verifier call `:2922` |
| 8 | `WorldState ∋ [WakeInput] ∋ WorldState` contradicts "observations, never whole worlds" | ✓ | `ADR-002:427`, `:371`. This is a type decision the plan makes; it is defensible as following the ADR's prose, but see §4 W3. |
| 9 | `meta_timed` has seven keys | ✓ | `herdr.ail:199–206`; `elapsed_is_exact` `:205`; no `settled` |
| 10 | `suspended` already in both unions | ✓ | `ui.ts:798`; `herdr-agent-state.ts:43`, `:100–101` |
| 11 | the loop holds a world slot; `:4463` drops it; three recursions | ✓ **but incomplete** | `:4307`, `:4371`, `:4463`, `:4484`, `:4491`, `:4498` are all right. The row misses the initial turn's identical drop at `:4723` and the entry arms `:4755`/`:4759`/`:4766` (§4 W5). |
| 12 | the TL;DR puts D3's producer in step 1 | ✓ | `ADR-002:205` vs `:542` |
| 13 | "always empty" read as "inert" | ✓ | the only reading consistent with `ADR-002:543–546` |
| 14 | O5's literal trigger has fired | ✓ | `ADR-002:273`; P2 landed |

"Also carried": `dp7_fail_open` has no producer (`step_machine.ail:130`; test `:374–381`) ✓.

## 3. Owner decisions Q1–Q5 in the work items

| Q | §8 text | in the work items? | verdict |
|---|---|---|---|
| Q1 verify blanks | plan:758–761 | W2 Part 4 stage 5 (plan:289–291); gate 2(d) (plan:314–315) | ✓ faithful |
| Q2 O5 trigger | plan:762–765 | W-O5 trigger (plan:616–619) | ✓ faithful |
| Q3 re-issue | plan:766–770 | W4 Part 2 says only "What the loop does next is decided: re-issue, §8.3" (plan:460–461). Part 6's "wrong handle" (plan:529) does not say it asserts a re-issue. | **✗ pointer only, and the mechanics are broken.** (a) No bound: `Park` never passes through `call_model_or_fail`, the only step-cap check (`step_machine.ail:96–105`). (b) Unstated: whether `ParkEntered` is emitted again, which would duplicate D7's `park` entry. (c) A re-issued request records two interactions with equal `WakeIdentity(origin, request_id, wait_id)`, which `dst_interaction` equality (`:177–183` pattern) cannot tell apart. (d) With the `wait_id` rule, the unbound default's own reply is a "mismatch" (§0 item 2). |
| Q4 next run's identity | plan:771–775 | W5(b) says only "The plan's proposal is decided, §8.4" (plan:582–584). No gate. | **✗ pointer only.** The collision with `park_ordinal = 0` (plan:449–450) is unaddressed. ADR-003 D7 uses "park ordinal 0" for the resumed run's re-issued request (`ADR-003:546–547`); that is consistent only because the resumed run's first park *is* that request. |
| Q5 retire `DelegateAwait` | plan:776–778 | W-O5 (plan:634) | **partial.** W4 has no retirement step or gate (removing the tool, its tests, and the graded clauses). |

## 4. Per-section findings

### §0 Preconditions and standing rules

- §0.1 rows verified. `RunIdentity` import `session.ail:173–174`; `c2_loop` `:2985`/`:2998`;
  `run_id_for` `:4269–4271`; P3ORD `journal_resume` `Makefile:307–318`.
- One imprecision: `loop_run_identity` "at `:4404`" (plan:46) is the **call**. The definition is
  `session.ail:4274`.
- Rule 3: 43 variants is exact (`dst_event_vocabulary.ail:9`, and the `Makefile:1476` awk count
  over `phase_vocab.ail` gives 43).
- Rule 7 is right, and it matters more than the plan uses it for (W5 below).

### W1a — ACCEPT

`buildReportArgs` at `herdr-agent-state.ts:321` is the call inside `reportRunState`, not the
definition. That is harmless for a probe. The two readbacks and the `blocked` control are
enough to settle ADR "Not decided".

### W1b — ACCEPT WITH CORRECTIONS

- **`settled` cannot ride `meta_timed` on two of its four settle paths.**
  - The gone-and-lost branch settles `lost` (`herdr.ail:1470–1474`) and then returns
    `err_result(call.id, "DelegateCheck", …)` (`:1476`).
  - `err_result(call_id, tool, msg)` (`:244`) takes no metadata.
  - The error-only branch returns the same `err_result`.

  So "`settled` is present and correct on every settle path and `false` on the error-only
  path" (plan:225) is untestable unless those branches gain metadata. The plan says only
  "`meta_timed` … gains `settled`" (plan:208).
- **No matching key.** W2's lifecycle row "`settled: true` → remove the *matching* wait"
  (plan:267) needs the check's metadata to name the wait. `meta_timed` carries `delegate` (the
  handle) and `pane_id` (`:201`). The plan never says that `DelegateWait.id` is the handle, or
  which field matches.
- **Answer-writer placement.** D1.2 places the writer "in the non-TTY path" (plan:170–171); the
  forward is `index.ts:979–984`. The gate (plan:220) also requires "the interactive one-shot
  path", which has no named site.
- **`herdr_graded` coverage.** Gate "run clauses stay green" is right, since the target is known
  red. But it reaches only the claude/codex graded script. `do_check_motoko`'s re-read is
  covered by extension L1 tests alone. Say so in §5.

### W2 — ACCEPT WITH CORRECTIONS

- **Sequencing: sound.** While stage 3 is inert:
  - `decide` is unchanged (gate 1);
  - the guard does not read `open_waits`;
  - waits die with the run.

  Registration being live therefore changes no decision. What it does change is every literal
  that must carry the field.
- **`ExtCtx` is ABI.**
  - `types.ail:536` has `work_in_flight`, which is the ABI 7.3 precedent (`:580`).
  - The ABI module cannot import `src/core/phase_vocab`: it imports `std/option` and `std/json`
    only (`:12–13`).
  - A `state_key:` grep finds full `ExtCtx` literals in 29 files: 8 in packages or the
    conformance harness, 14 scripts, `rpc.ail` (3), `session.ail` (2, including
    `publish_turn_exit_manifest` `:4584–4606`), and `ext/runtime.ail`.

  The plan prices W2 as "core" (plan:129) and gates no package. Either:
  - specify an ABI-local type or `Json`, the ABI bump, and per-package tests; or
  - move the field to W4, where the guard first reads it (plan:445–446).
- **Literal counts are not given.**
  - `C2LoopState` has 15 loop literals, 2 constructors and 2 test literals (the comment at
    `session.ail:558–559`). Its range is `:509–569`, not `:509–545`.
  - `StepState` literals are built by `mk_state_with_messages` (`step_machine.ail:173`; `mk_state`
    `:190` sits outside `:258–408`, so gate 1's diff check is sound).
  - `StepState` literals also appear in scripts; recount them.
- **Gate 2's harness.**
  - `phase_c2_wiring_scenarios` runs under `make phase_c_l1` (`Makefile:386–389`) with
    `empty_rt()` or verification-disabled runtimes.
  - Cases (a)–(e) need a verifier-enabled runtime (named in the plan). They also need:
    - (a) a registered feedback solver;
    - (c) the persist nudge enabled (off by default, `session.ail:2262` comment);
    - (d) `empty_stop_guard` registered.

  None of that is stated.
- **Gate 3 is regression-only.** Both fixtures have empty registries, so their decision
  sequences are order-invariant *by construction* (that is why the delta review chose them).
  They cannot go red on a DP7/solver ordering bug. Only gate 2 proves the ordering. Label gate 3
  "regression, not proof".
- **The stage-2 world.** At HEAD the rejection arm's world is
  `token_to_world(clear_holder(collected.next_state))` (`ext/runtime.ail:722`, `:727`;
  `session.ail:3724`/`:3794`). Leaving it to the implementer with `ledger_parity`'s frames as
  the detector (plan:294–300) is acceptable. Record the result in §7, not only in the commit
  message.
- **Missing cross-check.** W1b and W2 may run in parallel (plan:52–53) and share no test. Add a
  gate that a real `Delegate` envelope's `metadata.wait` from `herdr.ail`'s tests decodes
  through W2's strict decoder.

### W3 — ACCEPT WITH CORRECTIONS

- **"No session call site" holds.** W2's consumer is `tool_phase.ail`'s `Handled` arm
  (`:439–449`) and calls no `.wake_read(`. `SCAN_FILES` (`derive.py:166–171`) includes
  `tool_phase.ail` and `stub_step.ail` but not `ports.ail`, so adapters bound by record field
  add no site. Gate 3's "site count unchanged" is right.
- **The mutant cannot produce the verdict the plan asks for.** Part 5 adds
  `"st.provider.wake_read": "WakeRead"` to `HELPED`. `scan_leaves` then marks that receiver
  `status: "helped"`; `UNRESOLVED-RECEIVER` is emitted only when `HELPED.get(key) is None`
  (`derive.py:192–200`). So "the inventory **must report it unresolved**" (plan:399–400) is
  unreachable after Part 5.

  The red has to be an order-of-witness verdict, and the tree-mutant harness takes one
  specific shape: `TREE_MUTANTS`, a same-line replacement of anchor text that occurs exactly
  once (`derive.py:580–637`), checked against `CLEAN_VERDICTS = ("clean", "returned")` (`:286`).
  "Appends a call to an in-memory copy" is not that harness, and in W3 there is no anchor.

  **False-green risk:** a mutant written with an unhelped receiver (say `p.wake_read`) goes
  `UNRESOLVED`, passes the self-test, and proves nothing about witness order.

  Fix, either:
  - ship the order-verdict mutant with W4 against the real call site; or
  - add a fixture-directory case in W3.

  Keep "red first" against the pre-Part-5 `CALL_RE`, which is correct: the site is invisible
  there.
- **Gate 1's "returns without reading stdin"** (plan:410) is not a unit-test property. Make it a
  T0 check: the body calls no port and no `readLine`.
- **`WorldState` literals** (plan:380–381): by grep, `ports.ail:764` and a test literal at
  `dst_replay.ail:1170`, plus `ext_world.world_of_json` `:584–`. Name them. `world_of_json` reads
  lists leniently (`json_array`), so old tokens without `wakes` decode to `[]`. State that this is
  intended.
- **Row 8's `WakeObservation`** changes the type of a cursor the ADR declares. The plan is right
  to follow the ADR's prose, but it is a type decision. Flag it as one for the owner, next to
  §8, rather than only as a residual row.

### W4 — REJECT (as written)

1. **`decide` versus its tests** (§0 item 1).
   - Resolve in one of two ways:
     - the arm reads "stop-class reason (including a blank `stop`) and `open_waits ≠ []` →
       `Park`", which is still one arm and leaves `decide` holding the narrowed guarantee; or
     - the cross-product tests use reason `await_wake`.
   - Placement also matters: the arm must precede `:130–131`. "After the pending-tools arms
     `:117–122`" is `:117–123`.
2. **The mismatch rule** (plan:460–461) must match on `request_id` always, and on `wait_id` only
   for `Settled`/`Lost`/`TimedOut`. Otherwise the unbound default (plan:365–368), `HostError`,
   `OperatorInput` and `Aborted` are all dropped. The missing-wake control (plan:531–532) then
   never observes `HostError`, and Q3 re-issues without end.
3. **Q3 mechanics** (§3 above). This needs a real bound. Charging each re-issue to `step_idx`,
   or a re-issue counter checked against `pol.step_budget`, would work. This is a mechanism
   under an owner decision, so confirm it with the owner. The plan also has to state whether
   `ParkEntered` is emitted again and how `recording_wake` distinguishes attempts. The
   wrong-handle fixture must assert all of this.
4. **The request-id collision** with Q4 (§3 above).
5. **`user_injected` coordinate.** "`decide`'s existing arm (`step_machine.ail:136–137`)"
   (plan:474–475) is `tools_complete`. `user_injected` is `:138–139`. The routing still works,
   but the citation is wrong.
6. **Mid-park `abort`, `exit`, `restart`, `model_change`.** `session.ail` has no in-turn abort
   path. `"abort"` is read only between turns (`:4357`). The TUI's ESC kills the runtime
   mid-task (`ui.ts:2147–2153`). "`abort` → `Aborted`. `exit`/`restart` cancel" (plan:506) has
   no target. `WakeOutcome` has no cancel arm, and `model_change` during a park is unspecified.

   State, for each command received by the live `wake_read`'s stdin loop:
   - the terminal code or suspension;
   - whether `SessionSuspend` is emitted;
   - what `c2_loop` returns.
7. **The parked input route** (plan:519–520). `ui.ts:2218` is the status-bar spinner tick
   (`setInterval` → `isWaitingState`). The guard that refuses input is `shouldLockPlainInput`
   (`ui.ts:1798–1804`, keyed on `taskDone`).
8. **The metric fixture mixes channels** (plan:536–538). `ParkEntered`/`WakeReceived` are trace
   events; `ModelStep` interactions live in the recorded program. Assert over one channel:
   - no `ProviderCallPrepared` (`phase_vocab.ail:1008`) between `ParkEntered` and `WakeReceived`
     in the trace; or
   - no `ProviderIdentity` between the `WakeIdentity` interaction and the one before it in the
     program.
9. **Scanner count.** "Count rises by exactly one" (plan:479–480) holds only if the re-issue
   path reuses the one call site. Pin that.
10. **Q5.** If W-O5 has landed, W4's activation commit removes `DelegateAwait`. Add that to the
    W4 gate.
11. **Missing from the ADR's list, silently.**
    - `TimerWait` has no producer; ADR D3 names the model's `Delegate` or policy. The `TimedOut`
      fixture (plan:528) must construct it directly; say so, since timeouts are "Not decided".
    - `open_waits` on the in-process continuation constructor (`c2_state_from_continuation`,
      `session.ail:2591`) is cleared per ADR D3's "suspend → cleared". The delegate keeps
      running, and the resumed run is not told. State it.
    - ADR D3's re-delegation row says "the model is told both are open". No work item produces
      that message.

### W5 — ACCEPT WITH CORRECTIONS

1. **Gate 2's turn-1 → turn-2 contiguity cannot hold with (c) as scoped.**
   - `rpc.main` waits in `await_first_task` (`rpc.ail:250`, `:335`).
   - The first `user_message` then runs as the opening task (`rpc.ail:434` →
     `session.ail:4722`).
   - That turn's `publish_turn_exit_manifest` result is dropped at **`:4723`**.
   - The loop is entered with `started_provider` (`:4759`, the world *before* turn 1) or
     `live_provider` (`:4755`, `:4766`, the world before policy init).

   W5(c) threads only `:4463`. §3 files `:4755–4766` under "the initial identity read"
   (plan:660–661), but they are the same successor drop. Either:
   - add `:4723` and the entry arms to W5(c), a real scope change to state rather than absorb
     silently; or
   - make the probe send three turns and assert contiguity from turn 2 to turn 3.
2. **The live wire has no frames.**
   - `WORLD_RUN_BEGIN`/`END` are `println`s in `ledger_parity_dst.ail:406` (DST only), checked
     by `run_world_framed_wire.sh`.
   - Live stdout carries `world_request` (`witness_drain`, `session.ail:4167–4176`) and
     `run_summary.world_ordinal` (journal side `journal.ail:1036`).

   "Turn 2's frame opens at turn 1's `final`" and "the between-turn frame lies strictly after
   turn 1's `run_summary`" (plan:603–604) therefore have no observable. W5(a) (plan:571–577)
   emits nothing. Specify the between-turn frame's wire record, or restate the gate over
   `run_summary.world_ordinal` and `world_request` ordinals.
3. **Gate 2 contradicts (a).** The manifest publication at `:4463` does a witnessed `env_read`
   after the run returns (`session.ail:4582–4583`), so its `world_request` carries turn 1's
   `final + 1`. Threading that world means turn 2 starts after the between-turn frame's last
   ordinal, not at turn 1's `final`. (a)'s rule, "opens at the previous frame's `final`",
   applies to the between-turn frame, not to turn 2.
4. **(b) has no mechanics and no gate** (§3 Q4). Add:
   - the construction: `loop_run_identity(session_id, profile, resume_count, next_ordinal)`
     (definition `session.ail:4274`), built at the `readLine` site `:4351`;
   - a pure unit test;
   - the collision fix.
5. **Price.** 2–4 days (plan:132) covers the three recursions and the pure factor. It does not
   cover the initial-turn successor (item 1), a live frame representation (item 2), or the
   probe harness. Re-price after items 1–4; 3–5 days is more credible.
6. **Evidence tier.** Gate 3 runs `world_framed_wire`, `journal_resume` and `ledger_parity`
   (T2/T3), but §5 lists W5 at "T1 + T4" (plan:714).

### W-O5 — ACCEPT WITH CORRECTIONS

- The trigger is Q2 verbatim, the scope is ADR O5, and the 45 s bound is cited at HEAD.
- The retirement (Q5) needs its step in W4 (W4 item 10).
- The second trigger clause ("before the next measured delegation run the owner schedules") is
  an owner judgement, not a checkable gate. Say so.
- §5 omits `herdr_graded`'s T2 run clauses.

### §3 Unscheduled D4 debt

Faithful to `ADR-002:510–520` and `:569–570`, with one misfiling. The "initial identity read"
bullet (plan:660–661) lists the entry arms `:4755–4766`, which carry a dropped turn successor.
That drop is W5(c)'s concern (W5 item 1), not identity. The new "blocking read as a park"
bullet (plan:649–652) is correctly marked as a residual.

### §4 Non-goals

Consistent with ADR "Not decided". Nothing re-decided. W4 Part 2's use of `user_injected`
leaves "whether `InjectUserMessage` and the wake message share a decision variant" open, as
claimed.

### §5 Tiers and §7 Results

- **The tier ladder is right; the per-item rows understate three items:**
  - W5 is missing T2/T3;
  - W1b and W-O5 claim T2 only through `herdr_graded` run clauses, while the target is known red;
  - W4 T2 needs the single-channel metric (W4 item 8).
- **§7 records only T4 results.** Two load-bearing results currently go only to commit messages
  and belong in §7:
  - W3's red-first mutant record (T2);
  - W2's stage-2 world expression (T3).

## 9. Coordinate audit

Every coordinate below was read at HEAD with `git show HEAD:<path>`. There is no drift since
grounding (HEAD = `d888585`).

| plan cites | HEAD verified | note |
|---|---|---|
| `session.ail:173–174`, `:2985`, `:2998`, `:4269–4271`, `:926–940`, `:744–746`, `:1883`, `:1907`, `:2243–2255`, `:2883`, `:2922`, `:2942`, `:2971`, `:3027`, `:3057–3061`, `:3058`, `:3069–3070`, `:3075`, `:3076`, `:3079`, `:3173`, `:3238`, `:3338`, `:3716–3797`, `:3721`, `:3724`, `:3758`, `:3794`, `:4163`, `:4294`, `:4307`, `:4351`, `:4352`, `:4354`, `:4356`, `:4371`, `:4376`, `:4378–4390`, `:4463`, `:4484`, `:4491`, `:4492–4499`, `:4498`, `:4503`, `:4638`, `:4674`, `:4697`, `:4755–4766`, `:4830`, `:4846` (50) | ✓ | |
| `session.ail:509–545` `C2LoopState` | **✗** | the type runs to `:569` (`history_digest`) |
| `session.ail:4404` `loop_run_identity` | **imprecise** | `:4404` is the call; definition `:4274` |
| — not cited, load-bearing | — | `:4723` (initial turn's dropped manifest successor); `:4759` (`started_provider`); `:4582–4583` (manifest `env_read` witnessed after the run); `:4167–4176` `witness_drain`; `:2591` `c2_state_from_continuation`; `:4357` the only `abort` read |
| `step_machine.ail:96–114`, `:116–141`, `:258–408` with the 15 test lines, `:374–381`, `:130` (5) | ✓ | tests at `:258 :268 :280 :292 :302 :316 :325 :334 :347 :356 :365 :374 :383 :392 :401` |
| `step_machine.ail:136–137` as `user_injected` (W4 Part 2) | **✗** | `:136–137` is `tools_complete`; `user_injected` is `:138–139` |
| `step_machine.ail:129–130` stop class (§9) | **✗ off by one** | `:130–131` (`:129` is the persist-nudge inject) |
| `step_machine.ail:117–122` pending-tools arms | **✗ off by one** | `:117–123` |
| `phase_vocab.ail:424–434`, `:564`, `:1274–1283`, `:1309–1311`, `:1344–1352` (5) | ✓ | |
| `tool_phase.ail:439–449`, `:449` (2) | ✓ | |
| `ext/runtime.ail:721`, `:721–728`, `:727` (3) | ✓ | |
| `ports.ail:44`, `:183`, `:208`, `:493–494`, `:497–` (type at `:506`), `:764`, `:829`, `:1019–1024`, `:1758–1786`, `:2596–2612`, `:2598` (11) | ✓ | |
| `world_ordinal.ail:33–36`, `:41–51`, `:53–61`, `:41–61`, `:106`, `:112` (6) | ✓ | |
| `ext_world.ail:554`, `:587`, `:687–774`, `:811–823` (4) | ✓ | |
| `derive.py:21`, `:10–30`, `:94–105`, `:164`, `:173–177` (5) | ✓ | not cited, load-bearing: `:166–171` `SCAN_FILES`; `:192–200` unresolved rule; `:286` `CLEAN_VERDICTS`; `:580–637` `TREE_MUTANTS` |
| `Makefile:307–318`, `:349–351`, `:361–364`, `:480–491`, `:491`, `:655`, `:1473`, `:2314–2317`, `:2999`, `:3023–3027`, `:3026–3027` (11) | ✓ | `phase_c2_wiring_scenarios` runs under `phase_c_l1` `:386–389` |
| `dst_event_vocabulary.ail:9` (43) | ✓ | the awk count agrees |
| `ledger_parity_dst.ail:260–263`, `:493–500`; `smoke_v2_dp7_gate.ail:38–41`; `long_qwen_compaction_dst.ail:385–405`, `:515–535` (5) | ✓ | |
| `stub_step.ail:186`, `:209–223`, `:557`, `:651`, `:788–791` (5) | ✓ | |
| `dst_interaction.ail:62`, `:125`, `:180–181`, `:206`, `:303`, `:383` (6) | ✓ | |
| `dst_replay.ail:582` | ✓ | |
| `dst_replay.ail:703–716` `approvals_of` | **✗ off by four** | the comment starts at `:703`; the function is `:707–718` |
| `dst_invariants.ail:330`, `:891`, `:1180` (3) | ✓ | |
| `herdr.ail:191–195`, `:199–206`, `:205`, `:698`, `:1151`, `:1322`, `:1403`, `:1432`, `:1441–1463`, `:1466–1478`, `:1470–1474`, `:1475–1476`, `:1537` (13) | ✓ | not cited, load-bearing: `err_result` `:244` (no metadata), returned at `:1476` on both failure branches |
| `register.ail:173` | ✓ | |
| `progress_contract_guard.ail:199`, `:203–208`, `:204`; `empty_stop_guard.ail:8–10`, `:62–66` (5) | ✓ | |
| `tool_contract.ail:13–20`; `herdr_graded_dst.ail:151–155`; `types.ail:536`; `rpc.ail:250` (4) | ✓ | not cited: `types.ail:12–13` (ABI imports only `std`); `rpc.ail:335`, `:434` (first task → `run_v2_with_conversation`) |
| `ui.ts:798`, `:2744`, `:2770` (3) | ✓ | |
| `ui.ts:2218` "waiting-state guard" | **✗** | spinner tick; the input guard is `shouldLockPlainInput` `:1798–1804` |
| `herdr-agent-state.ts:43`, `:90–103`, `:100–101`, `:306–309`, `:338`, `:321` (6) | ✓ | `:321` is the `buildReportArgs` call, not its definition |
| `index.ts:598`, `:613–632`, `:979–1000` (3) | ✓ | the forward itself is `:979–984` |
| `runtime-process.ts:842`, `:862–891` (2) | ✓ | |

**Total: 166 coordinates checked, 159 exact, 7 wrong or imprecise.**
- Load-bearing (3): `step_machine.ail:136–137`, `ui.ts:2218`, `session.ail:509–545`.
- Minor (4): `:129–130`, `:117–122`, `dst_replay.ail:703–716`, `loop_run_identity :4404`.
- Zero drifted.

## Required changes before the named items start

**Before W1b:**
1. **W1b D3 producer (plan:208–211) and gate (plan:225).** Say that the gone-and-lost and
   error-only branches of `do_check_motoko` (`herdr.ail:1470–1476`, `err_result` `:244`) gain
   metadata carrying `settled: true` and `settled: false` respectively. Otherwise the gate is
   untestable.
2. **W1b D3 producer (plan:204–207) and W2 Part 3 row (plan:267).** Pin the matching key: set
   `DelegateWait.id` to the delegate handle and match it against `DelegateCheck`'s
   `metadata.delegate` (`herdr.ail:201`), or add an explicit `wait_id` to the check's metadata.
3. **W1b D1.2 (plan:169–172).** Name the answer-writer site for the interactive one-shot path
   that the gate (plan:220) tests. Only the non-TTY forward (`index.ts:979–984`) is placed today.

**Before W2:**
4. **W2 Part 1 (plan:247–248), estimate (plan:129), gate 6 (plan:330–332).**
   - Declare `ExtCtx.open_waits` an ABI change: an ABI-local type or `Json` (the ABI imports
     only `std`, `types.ail:12–13`), an ABI version bump, and `ailang test` for every touched
     package.
   - List the 29 files with `ExtCtx` literals and re-price.
   - Alternatively, move the field to W4 Part 1 (plan:445), where the guard first reads it.
5. **W2 Part 1 (plan:244–246).** Enumerate the literal counts: `C2LoopState` has 15 loop
   literals, 2 constructors and 2 test literals (`session.ail:558–559`), and its range is
   `:509–569`. Recount the `StepState` literals, including scripts.
6. **W2 gate 2 (plan:307–317).**
   - Name the host target: `phase_c_l1`, `Makefile:386–389`.
   - For each case, name the registered solver and the settings it needs: (a) a feedback
     solver; (c) the persist nudge enabled; (d) `empty_stop_guard`.
   - Label gate 3 (plan:318–321) as regression-only: order-invariant by construction, so it
     cannot detect an ordering bug.
7. **W2 gate (new item after plan:329).** Add a cross-producer check: a `Delegate` envelope from
   `herdr.ail`'s tests decodes through the core `WaitDescriptor` decoder.

**Before W3:**
8. **W3 Part 6 (plan:396–403) and gate 3 (plan:414–416).**
   - Replace "must report it unresolved": after Part 5, `st.provider.wake_read` is `helped`
     (`derive.py:192–200`).
   - Specify an order-verdict mutant in `TREE_MUTANTS` form (`derive.py:580–637`), shipped with
     W4 against the real site, or a fixture-directory case in W3.
   - Forbid an unhelped-receiver mutant, which would be a false green.
9. **W3 gate 1 (plan:410) and Part 4 (plan:380–381).**
   - Replace "returns without reading stdin" with a T0 check that the body calls no port and
     no `readLine`.
   - Name the `WorldState` full literals found at HEAD (`ports.ail:764`, `dst_replay.ail:1170`,
     `ext_world.ail:584–`).
   - State that tokens without `wakes` decode to `[]`.
10. **§1 row 8 (plan:107).** Flag `WakeObservation` as a type decision for owner sign-off,
    alongside §8.

**Before W4:**
11. **W4 Part 1 (plan:433–444) and gate 1 (plan:545).** Reconcile the one `await_wake` arm with
    the "stop-class × waits → `Park`" and "empty × waits → `Park`" tests (`step_machine.ail:130–131`).
    Either the arm reads `open_waits`, or the tests use reason `await_wake`.
12. **W4 Part 2 (plan:460–461).** Match on `request_id` always, and on `wait_id` only for
    `Settled`/`Lost`/`TimedOut`. This lets the unbound default's `wait_id: ""` (plan:365–368)
    and `HostError`/`OperatorInput`/`Aborted` through. The missing-wake control (plan:531–532)
    depends on it.
13. **W4 Part 2 (plan:460–461), Part 6 wrong-handle (plan:529), §8.3 (plan:766–770).**
    Transcribe Q3's mechanics:
    - a real bound, e.g. each re-issue charged to `step_idx` or counted against
      `pol.step_budget`, since `Park` bypasses `call_model_or_fail`
      (`step_machine.ail:96–105`); **the owner confirms the mechanism**;
    - whether `ParkEntered` is emitted again;
    - how `recording_wake` distinguishes attempts under equal `WakeIdentity`;
    - the fixture's assertions of all three.
14. **W4 Part 2 (plan:449–450), W5(b) (plan:579–584), §8.4 (plan:771–775).** Resolve the `.p0`
    collision between Q4's between-turn park and the first in-turn park of the same run. For
    example: the run opened by a consumed between-turn wake starts `park_ordinal` at 1, or the
    between-turn id takes a distinct suffix. Check the fix against ADR-003 D7's "park ordinal
    0" (`ADR-003:546–547`).
15. **W4 Part 5 (plan:506, plan:518–520) and §9 row (plan:817).**
    - Specify what `abort`, `exit`, `restart` and `model_change` received during a park do.
      There is no in-turn abort path (`session.ail:4357` is between turns only), and ESC kills
      the runtime (`ui.ts:2147–2153`).
    - Re-cite the parked input guard as `shouldLockPlainInput` (`ui.ts:1798–1804`), not `:2218`.
16. **W4 Part 7 (plan:536–538) and gate 7 (plan:559).** Assert "no provider call between park
    and wake" over one channel: trace `ProviderCallPrepared` between `ParkEntered` and
    `WakeReceived`, or program `ProviderIdentity` around the `WakeIdentity` interaction.
17. **W4 Part 2 coordinates and scanner claims (plan:474–475, plan:479–480; §9 plan:798).**
    - `user_injected` is `:138–139`, the stop class `:130–131`, the pending-tools arms `:117–123`.
    - Pin that the re-issue reuses the single `wake_read` call site, so "+1" holds.
18. **W4 gate (new item after plan:561).**
    - Q5: remove `DelegateAwait` in the activation commit if W-O5 landed.
    - State that `TimerWait` has no producer (fixtures construct it).
    - State that `open_waits` is cleared on `c2_state_from_continuation` (`session.ail:2591`)
      with the model not told.
    - Say which item produces ADR D3's "the model is told both are open" message.

**Before W5:**
19. **W5(c) (plan:586–594), gate 2 (plan:600–607), §3 (plan:660–661).** Either:
    - add the initial turn's dropped successor (`session.ail:4723`) and the entry arms
      (`:4755`, `:4759`, `:4766`) to W5(c), moving them out of §3's "initial identity read"; or
    - make the live probe send three turns and assert contiguity from turn 2 to turn 3.
20. **W5(a) (plan:571–577) and gate 2 (plan:603–605).**
    - Specify the between-turn frame's live wire record. `WORLD_RUN_BEGIN`/`END` exist only in
      `ledger_parity_dst.ail:406`.
    - Or restate the gate over `run_summary.world_ordinal` and `world_request` ordinals.
    - Correct "turn 2's frame opens at turn 1's `final`": the manifest's witnessed `env_read`
      (`session.ail:4582–4583`) sits in the between-turn frame, so turn 2 opens at that frame's
      last ordinal.
21. **W5(b) (plan:579–584) and gate 1 (plan:597–599).**
    - Transcribe Q4: `request_id` =
      `loop_run_identity(session_id, profile, resume_count, next_ordinal).run_id` + `.p0`,
      built at `session.ail:4351`. The definition is `:4274`, not `:4404`.
    - Add a pure unit test for it.
22. **W5 estimate (plan:132, plan:565).** Re-price after changes 19–21.

**Plan-wide:**
23. **§5 tier table (plan:707–715) and §7 (plan:745–750).**
    - Add T2/T3 to W5.
    - Mark W1b and W-O5's T2 as `herdr_graded` run clauses of a known-red target.
    - Add §7 entries for W3's red-first mutant record and W2's stage-2 world expression.
24. **§0.1 (plan:46) and §9 (plan:797, plan:804, plan:808).** Correct `C2LoopState :509–569`,
    `loop_run_identity` definition `:4274`, and `approvals_of :707–718`.

**Required changes: 24.** None reopens an ADR-002 decision. One (change 13) needs the owner to
confirm the bound mechanism under Q3, and one (change 14) needs the owner to confirm the id rule
under Q4.
