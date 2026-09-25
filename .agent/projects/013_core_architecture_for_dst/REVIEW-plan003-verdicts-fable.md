# PLAN-003 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; the HEAD the plan grounds at, `PLAN-003-implement-adr-003.md:4`)
Subject: `PLAN-003-implement-adr-003.md` (proposed, not started)
Governing ADR: `ADR-003-session-snapshot-and-resume.md` v4.1 (`:3–4`, `:148–166`); ADR-002 is at v3 (`ADR-002-park-and-wake.md:3–4`)

Every coordinate and claim was checked at this HEAD; the ADR's own coordinates were verified across the four ADR reviews and are not re-audited here. §9 lists what the plan cites that is new.

## Overall verdict

**Accept with corrections; do not start P1 Part 1 as written.** The phase map is faithful to ADR-003 D8, nothing is re-decided, and the sequencing against PLAN-001 P2 is right. Four things a first implementer would hit on day one are wrong or missing, and one precondition the plan assumes green is red at HEAD:

1. **The P1 acceptance fixture cannot be built as described.** "A scripted provider that returns three assistant messages" (`PLAN-003:88`) finalises at the first: a plain assistant reply sets `last_finish_reason` to `stop` and `decide` returns `Finalize` (`src/core/step_machine.ail:128–129`). The harness's only continuing step is a tool-call step (`scripts/dst/terminal_trace_dst.ail:77–80`, used by `scenario_max_steps` at `:127–134` with a budget of 2), and each such step appends an assistant message *and* a tool result, so a 3-step budget leaves `2 + 3 × 2 = 8` messages, not `3 + 2` (`PLAN-003:91`).
2. **`RuntimeStatusCounts` is private to `session.ail`.** It is declared without `export` (`src/core/session.ail:431–437`) and has no user outside the file, yet `snapshot.ail` needs it for `Snapshot.cumulative` (`ADR-003:265`; `PLAN-003:132–133`). The plan says "no type move" only about `BudgetPlan` and `CostRates` (`:134–135`); this type, `zero_runtime_status_counts` and `runtime_status_counts_add` (`:545–553`) must move to a leaf (`phase_vocab.ail` or `snapshot.ail`) or `snapshot.ail` cannot be a leaf.
3. **The live probe's primary shape does not exist.** The non-TTY TUI path uses `PlainLogger`, which does "no stdin manipulation" (`src/tui/src/index.ts:415`, `:418–428`); the only stdin read is `promptForTask`'s single `once("data")` (`:1063`); and a non-TTY stdin forces `MOTOKO_HEADLESS=1` (`src/tui/src/runtime-process.ts:355–357`), which makes the conversation loop return before reading anything (`src/core/session.ail:3357`). Nothing can deliver `continue`. The plan's fallback (Open question 5, `PLAN-003:434–437`) is the only shape, and it changes what the probe reads (§6).
4. **`steps_executed_so_far` is not on the wire.** `runtime_status_json` is produced only when the model calls the `MotokoRuntimeStatus` tool (`src/core/session.ail:2658`) and in two tests (`:3847`, `:3899`). A probe that "reads the JSONL for … `MotokoRuntimeStatus.steps_executed_so_far`" (`PLAN-003:102–103`) sees it only if the model happens to call the tool.
5. **`make anchors` is red at HEAD.** All five `session.ail` anchors (`1164`, `1423`, `1529`, `3016`, `3126`) and all three `tool_phase.ail` anchors (`317`, `318`, `413`) fail today (`tools/predicate-anchors/anchors.sh:384–387`; run output: eight `✗`; `session.ail:1529` is `func c2_finalize(`, not a clock read). §0.2's "expect a re-baseline … recorded in the same commit" (`PLAN-003:36–40`) assumes a green baseline that does not exist, and the script's own footer says a re-baseline is a D4 judgement that re-issues three profiles. That is a disposition the sweep (§0.1) must record before P1 lands, and it is unpriced.

| area | verdict | short reason |
|---|---|---|
| Fidelity (§1) | **accept with corrections** | D1–D8 each land once; two ADR-mandated items are under-specified in the plan (the identity parameter's blast radius, the `RuntimeStatusCounts` move). |
| Sequencing (§2) | **accept** | P1 needs neither a file write nor an ordinal; P2's seam dependency is right; P3's host items can precede P2. |
| Gates (§3) | **accept with corrections** | Fixture arithmetic, the status-JSON read, the probe shape, the golden's location, and the already-red anchors. |
| Headless `error` (§4) | **accept** | Every consumer is covered; one simplification available. |
| `snapshot.ail` and `c2_finalize` (§5) | **accept with corrections** | No cycle; one private type must move; record update is the right answer to Open question 6. |
| Live probe (§6) | **reject as written** | See item 3; the fallback works and should be the plan. |
| Estimates (§7) | **accept with corrections** | P1 is under by the profile re-issue and the fixture rework; P3's live gates are unpriced. |
| Open questions / Non-goals (§8) | **accept with corrections** | Two questions must be settled before P1; one non-goal is missing. |

## 1. Fidelity: every ADR-003 decision, once

| ADR-003 | plan | verified against | note |
|---|---|---|---|
| D1 envelope, body, boot, cumulative, codecs | P1 Part 3 (`PLAN-003:125–149`); `ext_artifacts` reset on profile switch in P3 Part 3 (`:354`) | `ADR-003:246–308` | `RuntimeStatusCounts` move missing (item 2). |
| D2 item 1, the code | P1 Part 2 (`:108–123`) | `step_machine.ail:93–103`; `session.ail:2164–2169`, `:3705–3712`; `dst_fault_catalogue.ail:50–59`, `:210`, `:825–829` | Faithful. The catalogue's `test_required_ids_are_distinct` (`:831`) is unaffected. |
| D2 items 2–4, `suspended`, `written`, capture, record order | P1 Part 4 (`:151–184`); manifest publish and the write in P2 Part 3 (`:281–282`) | `session.ail:175–180`, `:1554`, `:2407–2437`, `:2433`, `:2486` | Faithful; `written: Some({…, published: false})` in P1 without any write attempted is a plan invention the ADR did not make (§3.1). |
| D2 item 5, the wire | P1 Part 6 (host) and P3 Part 4 (`:216–233`, `:374–382`) | `index.ts:517–519`, `:572–575`, `:877–882`, `:918`; `ui.ts:2752–2761`, `:2282`; `herdr-agent-state.ts:43`, `:81–91`; `session-logger.ts:5`, `:343–346`; `runtime-process.ts:58–103` | Faithful to ADR-003 D8 step 1's "core + host" split. |
| D3 `fs_atomic.ail`, `file_replace`, `FileReplace`, writer at the seam, `Restart` update, outer-backstop skip, `+2` gate | P2 Parts 1–3 (`:250–307`) | `exit_manifest.ail:193–204`; `ports.ail:826`, `:1135–1143`, `:1629–1645`, `:2556–2572`; `long_qwen_compaction_dst.ail:383–403`, `:513–533`; `derive.py:142`, `:151–155`; `session.ail:3391–3399`, `:3416`, `:3601` | Faithful. |
| D3 host `Abort` update | P3 Part 3 (`:365–367`) | `index.ts:922–985` | Faithful (ADR-003 v3 writer rule). |
| D4 strict decoder, whole-history digest | P1 Part 3 (envelope, total world) and P2 Part 3 (`world_of_json_strict`, `WorldField("pending")`) (`:139–146`, `:293–295`) | `ext_world.ail:543–553` | Faithful to D8 step 1's total-codec rule and v4.1 edit 4. |
| D5 id forwarding, `run_id`, loop rule, lease, compatibility, `SessionResumed` | P1 Part 5 (loop rule, `RunIdentity`) and P3 Parts 1–3 (`:186–197`, `:316–361`) | `session.ail:3137–3139`, `:3330–3346`, `:3418–3427`, `:3603–3612`; `runtime-process.ts:337–389`; `session-logger.ts:233–238`; `exit-actions.ts:422–428`; `herdr-agent-state.ts:296–301` | Faithful, including v4.1 edits 1–3 and 5. |
| D6 in-process, cross-process, restart respawn | P1 Part 5 and P3 Part 3 (`:198–207`, `:342–364`) | `config.ail:222–239`; `runtime-process.ts:482–505`; `rpc.ail:241–262`, `:296–345`; `index.ts:931–934`, `:951` | Faithful, including the bare-flag arm and `run_model`. |
| D7 | P4 (`:392–403`) | ADR-003 D7 | Unscheduled, gates named. |
| D8 order | phase table (`:62–73`) | ADR-003 D8 | Faithful. |

**Nothing is re-decided.** The one place the plan chooses is Open question 6 (`c2_finalize` parameters vs record update), which the ADR leaves to it.

**Two things the ADR requires that the plan under-specifies:**

- **The identity parameter's blast radius.** `c2_loop` gaining `identity: RunIdentity` and "`run_v2_from_messages_traced_with_policy_and_counts` and its siblings thread it" (`PLAN-003:157–158`) must not reach the exported entries. `run_v2_session_traced` (`session.ail:3148–3161`), `run_v2_session_traced_with_persist_retries` (`:3170–3185`) and `run_v2_with_stub` (`:3619–3632`) have 47 call sites in 20 files under `scripts/dst` and `src/core/test`. The plan's "Do not: change any DST match site" (`:239–240`) covers matches, not signatures. Say that the exported entries keep their signatures and build a default `RunIdentity` (`g0.r0`, profile `""`), and that only the conversation loop's path passes an explicit one through a new `_with_identity` sibling.
- **`RuntimeStatusCounts`** (item 2).

## 2. Sequencing

**P1 needs no file write and no ordinal.** Every P1 part is in memory: `c2_suspend` builds the snapshot and returns it in `suspended` (`PLAN-003:161–167`); the resume constructor consumes the in-memory value (`:198–201`); `snapshot_of_json` exists for its fixtures only and decodes `world` with the total codec (`:139–141`), so it needs neither `ordinal` nor `pending`. `WorldState` has no `ordinal` at HEAD (`ports.ail:183–196`), and nothing in P1 reads one. Correct.

**P2 against PLAN-001 P2.** The writer sits after the publish returns `{ world, trace }` (PLAN-001 P2 Part 5(a); `ADR-001:439–445`) and the leaf calls `advance(w, FileReplace)` (PLAN-001 P2 Part 1's writer, `PLAN-001:386–389`). Both are prerequisites, and the plan says so (`PLAN-003:246–248`). `RequestClass` "after ADR-002's `WakeRead` if it has landed, else sixth" (`:266–267`) is the right hedge: ADR-002 v3 is unimplemented and `wake_read` does not exist at HEAD.

**P3 after P1, with P2 only for the on-disk `--resume`.** Right: id forwarding (`runtime-process.ts:337–389`), the lease (host-side files, no `Ports`), and the enums are independent of the writer. One ordering inside P3 is missing: Part 3's `--resume` decodes strictly, which needs P2's `world_of_json_strict`; Part 1 and Part 2 do not. State that Part 3 waits for P2 and Parts 1–2 do not.

**P1 Part 5 before Part 6.** The live probe gate in Part 5 (`:211–214`) needs the host's `run_suspended` case from Part 6 to accept `continue` without a restart; as ordered, Part 5's gate cannot go green until Part 6 lands. Either swap the parts or move the probe gate to Part 6 (where the plan already repeats it, `:231–233`).

## 3. Gates

### 3.1 The P1 fixture in `phase_c2_wiring_scenarios.ail`

- **Runner.** `run_scripted` hardcodes `8` as `step_budget` (`scripts/dst/phase_c2_wiring_scenarios.ail:120–122`), so the fixture needs a third runner with `3`. Feasible; `terminal_trace_dst.ail:129–134` is the precedent with `2`.
- **Steps.** Item 1 above: use `continuing_token_step`-style tool-call steps (or a `hybrid_bash` step, `step_machine.ail:115–116`), and fix the count. With tool-call steps and one tool result per call, `List.length(s.history) == 8` and `s.body.step_idx == 3` (each model call increments the index, `session.ail:2850`, `:2908`, `:2945`, `:2990`).
- **Red today.** "`result` is `Err` with code `Internal`, `finish_reason` `max_steps`, and the returned value carries no history" is checkable now (`session.ail:2205`, `:3697`); after Part 2 the code is `StepBudgetExhausted`, after Part 4 `suspended` is `Some`. Genuinely red-first.
- **`written` in P1.** `Some({ generation: 1, …, published: false })` (`PLAN-003:92–93`) is coherent with v4.1 edit 3 (the loop's generation advances on any `Some`), but ADR-003 D3 makes `published: false` mean a failed write and prints "the session cannot be resumed across a process" (`ADR-003:475–479`). In P1 that line would print on every suspension. Say P1 prints nothing on `published: false` and P2 adds the line, or carry `published` as `None` until P2.
- **`RunSuspended.session_id` in P1.** The record carries `identity.session_id` (`PLAN-003:165`), the outer loop's id (`session.ail:3586`), while every other event of that run is stamped with the per-run derived id (`:3137–3139`, `:335–341`) until P3 forwards `MOTOKO_SESSION_ID`. Use the run's derived id for the record in P1, or the fixture's parity checks will see two ids in one run.
- **Ledger assertions.** `RecordAfterTerminal` (`dst_invariants.ail:788–796`) and `outcome_agreement` (`:1385–1388`) are exported invariants the script can call. Executable.
- **Make target.** The file runs under `phase_c_l1` (`Makefile:342–345`), which is in `DST_TARGETS` (`:436–441`). Executable.

### 3.2 The pure unit tests

`loop_identity_step` and `c2_state_from_continuation` as `tests [...]` blocks following `test_decision_fail_reason_mapping` (`session.ail:3705–3712`) are executable with `ailang test src/core/session.ail`. The "eight-row path table" (`PLAN-003:209–210`) is `REVIEW-adr003-v4-verdicts-fable.md` §3; two of its rows (`restart` with and without a snapshot) are P2 behaviour, so the P1 test covers six rows and says so. Red-first as stubs: yes, if the stubs assert the post-change values.

### 3.3 The live probe

See §6. As written it is not executable; the fallback is.

### 3.4 `snapshot_resume_dst.ail`

- The written snapshot lands in `WorldState.files` under the scripted `file_replace` (`ports.ail:1135–1143` pattern), so "decodes the written snapshot strictly" reads it from `run.world.files`. Executable.
- Frames are lines the script prints from `run.world.ordinal` (`ADR-001:415–419`); the in-script assertion `END_1.final == BEGIN_2.ordinal0 + 2` is a comparison of two integers the script holds. Executable once PLAN-001 P2 Part 1 lands (`ordinal` on `WorldState`).
- The resume needs the continuation traced entry from P1 Part 5 (`PLAN-003:203–204`). Executable.
- **Not registered.** A new DST script needs a Make target and a `DST_TARGETS` row (`Makefile:436–441`); the plan does not say so. Add it to P2 Part 3.
- Red-first: the script cannot run before P2 (no `file_replace`), so "red" means "does not compile"; say that.

### 3.5 The herdr `blocked` measurement

`herdr agent get` on the pane during suspension (`PLAN-003:232–233`) is executable only inside a herdr pane (`initHerdrReporter` returns early otherwise, `herdr-agent-state.ts:278–280`). The exhaustive-list test at `herdr-agent-state.test.ts:49–51` is the compile-time half and is executable everywhere. Say the live half is measured in a herdr pane and skipped elsewhere.

### 3.6 The lease tests

"Two TUIs on one session; kill -9 the first; `--resume-force`" (`PLAN-003:339–340`) is a manual live gate; fine. "Test in `exit-actions.test.ts` style: registration order and no re-raise" (`:334`): that file tests manifest parsing and proof checking (`exit-actions.test.ts:43–115`), not listener registration; there is no precedent for asserting `process.on` order in the suite. Name the mechanism (a spy on `process.on` with a fake `process`, or an exported `registerLeaseHooks(proc)` that takes the emitter) or drop "style".

### 3.7 The golden

"golden (`:1225` pattern)" in `dst_event_vocabulary.ail` (`PLAN-003:171`) is miscited: that file is 902 lines; the `golden` helper and its table are `phase_vocab.ail:1221–1229`. The vocabulary row is in `dst_event_vocabulary.ail`; the golden is in `phase_vocab.ail`. `make event_vocabulary` (`Makefile:1282–1285`) checks both counts.

### 3.8 Anchors

Item 5. The plan's §0.2 must start from the sweep's disposition of the eight stale anchors, and P1's commit that inserts lines at `session.ail:175–180` moves all five `session.ail` anchors again (all are below `:180`), re-issuing `driver_only_version`, `no_ops_version` and `compose_profile_version` per the script's footer (`anchors.sh:379–381` and the run output's last paragraph). Price it.

## 4. The headless-only `error`

**P1 Part 4.** `policy.headless` is read once at `session_policy_init` (`session.ail:2044`, `:2053`) and is in scope at both outer emit sites (`:3421`, `:3606`) through the `policy` parameter. Under headless the conversation loop returns immediately (`:3357`), so the follow-up loop's arm (`:3421`) is never reached in headless; only the initial-turn arm (`:3606`) needs the conditional. Correct as written; simpler if stated.

**Consumers in headless at HEAD**, and what P1 leaves them with: PlainLogger exits 1 on `error` (`index.ts:517–519`); JsonlLogger exits 1 (`:572–575`); the drain (`:877–882`) already covers `error` and gains `run_suspended` in Part 6; the transcript (`session-logger.ts:343–346`) still gets `error`; `errorOccurred` (`:918`) is TTY-only and irrelevant; herdr reporting comes from `ui.ts:2282` only, so the non-TTY path reports nothing per state. Nothing is left without a signal.

**P3 Part 4.** The loggers switch to exiting on `run_suspended` (`PLAN-003:376–377`) and the headless `error` goes; the drain and transcript already handle `run_suspended` from P1 Part 6. The inside-tree claim about `env-server.ts` is right: `:420` is a comment and `:1109` is a `child.on("error")` listener. The external adapter stays unverified and is gated (`:378–382`). Sound.

## 5. `snapshot.ail` imports and `c2_finalize`

**Imports.** `phase_vocab.ail` imports `compaction`, `tool_contract`, `types` (`phase_vocab.ail:17–19`); `ports.ail` imports `phase_vocab`, `tool_contract`, `tool_dispatch_adapter`, `fs_node`, `dst_interaction`, `dst_generator`, `dst_fault_catalogue` (`ports.ail:44–88`); `ext_world.ail` imports `ports`, `fs_node`, `dst_interaction`, `dst_generator` (`ext_world.ail:41–61`); `config.ail` imports no `src/core` module; the ABI types are a package. None imports `session`, so `snapshot.ail` importing `phase_vocab`, `ports`, `ext_world`, `config` and the ABI is acyclic, and `session.ail` importing `snapshot.ail` closes no cycle. The plan's "must not import `session`" (`PLAN-003:129–130`) is the right rule; item 2 (`RuntimeStatusCounts`) is the one type that breaks it today.

**`c2_finalize`.** It is called from `c2_fail` (`session.ail:2206`) and at least six arms (`:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`). Adding two parameters touches every call; a record update `{ finalized | suspended: Some(s), written: Some(w) }` at the two producing sites (`c2_suspend`, and the success arm in P2) touches only those, and the literal at `:1554` sets both `None`. Anchor movement is identical either way (all five anchors are below the `:175–180` insertion). Settle Open question 6 now: record update.

## 6. The live probe

Item 3 above: the non-TTY TUI cannot deliver `continue`. The fallback in Open question 5 is the workable design, with these corrections to what the plan says it reads:

- Drive `rpc.main` (`rpc.ail:355–359`) with `MOTOKO_HEADLESS` unset, `--no-backend` (`config.ail:235`) or a running env server, a live provider key, and a stdin pipe carrying the first task, then `{"type":"user_message","content":"continue"}`, then `{"type":"exit"}`. The conversation loop reads lines (`session.ail:3367`); the AILANG `readLine` blocks on a non-TTY only at EOF (`:3352–3353`), so a pipe that stays open until `exit` works.
- There is no `SessionLogger` in that shape, so there is no `.motoko/logfile/*.jsonl` to read; the probe reads the child's stdout, which is the same wire (`session.ail:335–341`).
- `steps_executed_so_far` (item 4): the task must instruct the model to call `MotokoRuntimeStatus` after `continue`, or the probe asserts the wire-visible equivalents: `provider_call_prepared.msg_count` for the payload (`session.ail:2773–2775`) and `run_summary.steps_executed` per run (`:1552`; `phase_vocab.ail:791`) for continuity, with `session_id` agreement once P3 lands. The judging number's `steps_executed_so_far` is a tool output; the plan should say which form the gate asserts.
- Alternatively run the TUI under a pseudo-terminal (`script -q`) so `isTTY` is true and the UI's input path handles `continue`; that is closer to the operator's experience but harder to script. Either is acceptable; the plan must pick one and drop the non-TTY-TUI shape.

## 7. Estimates

- **P1 6–8 days** (`PLAN-003:64`) against ADR-003's D1 1–2, D2 2–3, D4 1–2, D6 2–3 (partly): plausible for the core, but it omits the anchor disposition and the three-profile re-issue (§3.8), the fixture rework (§3.1), the `RuntimeStatusCounts` move, and the probe rebuild (§6). Add one to two days.
- **P2 2–3 days** (`:65`): consistent with ADR-003 D3's 2 days plus the strict world decoder, which ADR-003 D4 prices "as a decoder, not a wrapper" (`ADR-003:457–458`); three days is the floor, not the ceiling.
- **P3 4–6 days** (`:66`): the two live gates (TUI respawn resume; restart into a second profile) and the two-TUI lease test are manual and unpriced; add a day.

## 8. Open questions and Non-goals

**Settle before P1 starts:**

- **Question 1 (the sweep)** must also dispose of the eight stale anchors (item 5), because P1's first `session.ail` edit re-moves them.
- **Question 5 (the probe)**: decide the shape (§6) before Part 1, since Part 1 checks the probe in red.
- **Question 6 (`c2_finalize`)**: record update (§5).
- **New:** where `RuntimeStatusCounts` lives (item 2).
- **New:** whether the exported traced entries keep their signatures (§1).

**Can stay open:** question 2 (PLAN-001 P2's state; P1 does not need it), question 3 (row narrowing; the wide declaration is the rule either way), question 4 (resolved), question 7 (gated in P3 Part 4).

**Missing from Non-goals:**

- **The ADR-002 v3 edit is done** (`ADR-002:3–4`), so the cross-reference is right; but ADR-002's remaining v2.1 corrections are listed as a non-goal (`PLAN-003:412–413`) while ADR-002 D2's request id now depends on ADR-003 D5's `run_id` (`ADR-003:532–533`). Say that PLAN-002 consumes `RunIdentity` from P1 Part 5 and nothing else here.
- **`--resume` for headless one-shots.** ADR-003 D2 makes a headless `run_suspended` a non-zero exit; whether a harness may later `--resume` that session is not in scope and should be a stated non-goal.
- **The extension token's total codec** stays total (ADR-003 D4); the plan's P1 "Do not: touch `world_of_json`" (`:239`) covers it for P1 only; P2 adds a sibling and must not change the total one either.

## 9. Coordinate audit (what the plan cites beyond the ADR)

| cited | verified | note |
|---|---|---|
| `tools/predicate-anchors/anchors.sh:22` | yes | the "run it after any mechanical edit" line; the check list is `:384–387`; **red at HEAD** (eight anchors) |
| `Makefile:1221` (`fault_catalogue`), `:1283` (`event_vocabulary`) | yes | `:1221` and `:1282–1285` |
| `src/tui/package.json:9` | yes | `bun node_modules/.bin/jest …` |
| `packages/motoko-ext-abi/types.ail:61` (`BudgetPlan`) | yes | |
| `config.ail:30` (`CostRates`), `:133–138`, `:222–239` | yes | `CostRates` at `:30–33` |
| `dst_event_vocabulary.ail` "`:1225` pattern" | **no** | the file is 902 lines; the golden helper is `phase_vocab.ail:1221–1229` |
| `session.ail:2044–2053` (`policy.headless`) | yes | |
| `session.ail:3359–3366`, `:3374–3390`, `:3430`, `:3561`, `:3597–3612` | yes | |
| `session.ail:545–560` (`runtime_status_counts_add`) | yes | the type it returns is private (`:431`) |
| `herdr-agent-state.test.ts:49–51` | yes | the exhaustive array is `:49`, the expectation `:50–55` |
| `exit-actions.test.ts` "style" | **partly** | the file exists; it has no listener-registration test (`:43–115`) |
| `env-server.ts:420`, `:1109` | yes | comment; `child.on("error")` |
| `index.ts:415`/`:418–428` (PlainLogger, no stdin), `:1063` (`promptForTask`) | yes | the reason the probe's primary shape fails |
| `runtime-process.ts:355–357` (`MOTOKO_HEADLESS` on non-TTY) | yes | |
| `phase_c2_wiring_scenarios.ail:120–128` (`run_scripted`, budget `8`) | yes | |
| `terminal_trace_dst.ail:77–80`, `:127–134` | yes | the continuing-step precedent the plan should cite |
| `session.ail:2658`, `:3847`, `:3899` (`runtime_status_json` callers) | yes | tool-produced only |
| `step_machine.ail:128–129` | yes | plain `stop` finalises |
| `Makefile:342–345`, `:436–441` | yes | wiring scenarios under `phase_c_l1`; `DST_TARGETS` |

## Required changes before P1 starts

1. Rewrite P1 Part 1's fixture: a third runner with `step_budget: 3`, tool-call continuing steps on the `terminal_trace_dst.ail:77–80` pattern, `List.length(s.history) == 8`, and no "cannot be resumed" line on `published: false` in P1.
2. Move `RuntimeStatusCounts`, `zero_runtime_status_counts` and `runtime_status_counts_add` to a leaf module in P1 Part 3, and say so.
3. State that the exported traced entries keep their signatures and build a default `RunIdentity`; add the identity-taking sibling for the conversation loop only.
4. Replace the probe's non-TTY-TUI shape with the direct `rpc.main` shape (or a pty), read the child's stdout, and name which wire field stands in for `steps_executed_so_far`.
5. Record in §0.1 that `make anchors` is red at HEAD with eight stale anchors, and price the disposition and the three-profile re-issue in P1.
6. Fix the golden citation to `phase_vocab.ail:1221–1229`; register `snapshot_resume_dst.ail` in `DST_TARGETS`; name the lease-hook test mechanism; swap P1 Parts 5 and 6 or move the probe gate to Part 6; settle Open question 6 as a record update.
