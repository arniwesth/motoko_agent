# PLAN-003 v2 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; unchanged; the plan grounds at it, `PLAN-003-implement-adr-003.md:7`)
Subject: `PLAN-003-implement-adr-003.md` v2
Prior review: `REVIEW-plan003-verdicts-fable.md` (v1; six required changes)

Every new coordinate and claim was checked at this HEAD; claims carried from v1 stand on that audit. §8 lists what is new.

## Overall verdict

**Accept with corrections. P1 can start, with the sweep and anchor disposition of §0.1 as its first act, after three line edits.** All six required changes are folded. The rebuilt fixture is buildable and red-first; the rebuilt probe works on the mechanism the plan names, with two setup facts it does not state; the type move is clean; the lease-hook test mechanism is sound. The one framing that is still wrong is the anchor count: P1 has three anchor-moving commits, not one, so "two re-issues versus one" (`PLAN-003:50–53`) understates the choice and the cost.

| area | verdict | short reason |
|---|---|---|
| Six changes (§1) | **folded** | Three small residuals: one import, one line range, one profile-directory fact. |
| P1 Part 1 fixture (§2) | **accept** | Buildable from `stub_step.ail:771–781`; red today by code and by shape; the eight-message count is the right expectation and the first green run pins it. |
| Live probe (§3) | **accept with corrections** | Works as designed; `max_steps: 5` needs a probe profile; `msg_count` is the compacted length and is a valid substitute only under the conditions stated below. |
| `RuntimeStatusCounts` move (§4) | **accept** | No cycle; the cited range includes `zero_totals`, which must stay. |
| Anchor disposition (§5) | **accept with corrections** | Four re-issues or one, not two or one. |
| Lease-hook test (§6) | **accept** | Fake-emitter test is the right shape; name the registration point. |
| Can P1 start (§7) | **yes** | Nothing blocks beyond §0.1's own precondition. |

## 1. Disposition of the six required changes

| # | v1 change | Disposition | Residual |
|---|---|---|---|
| 1 | Rebuild the fixture on continuing tool-call steps; eight messages; no stderr line on `published: false`; run-derived id on `RunSuspended` | **Folded** (`PLAN-003:113–133`) | `continuing_token_step` is exported from `src/core/test/stub_step.ail:771–781` and the wiring file imports `stub_step` (`scripts/dst/phase_c2_wiring_scenarios.ail:33`) but not that name; add it to the import list. `terminal_trace_dst.ail:77–80` is a wrapper, not the definition; cite `stub_step.ail:771`. |
| 2 | Move `RuntimeStatusCounts` and its helpers to a leaf | **Folded** (`:182–186`) | The cited range `:438–446` spans `zero_totals` (`session.ail:439–441`), which returns `RuntimeLoopTotals` and stays; `zero_runtime_status_counts` starts at `:443`. |
| 3 | Freeze the exported traced entries' signatures | **Folded** (`:75–80`, `:216–221`) | None. The three entries and their line numbers are right (`session.ail:3148`, `:3170`, `:3619`). |
| 4 | Rebuild the probe on `rpc.main`, read stdout, name the wire substitutes | **Folded** (`:63–74`, `:138–150`, `:294–297`) | §3: the profile directory for `max_steps: 5`, and the condition under which `msg_count` equals the retained history plus one. |
| 5 | Record the red anchors and price the disposition | **Folded** (`:38–53`, `:548–550`, `:572`) | The count (§5). |
| 6 | Golden citation, script registration, lease-test mechanism, Parts 5/6 order, `c2_finalize` | **Folded** (`:231–233`, `:369–378`, `:413–417`, `:273–277`, `:209–215`) | None. The seven `c2_finalize` call sites are exactly the seven the plan lists (`session.ail:2206`, `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`); the golden helper is `phase_vocab.ail:1221–1229`. |

## 2. The rebuilt P1 Part 1 fixture

**Buildable.** `continuing_token_step(input, output, id)` returns a `ScriptedStep` with one `BashExec` tool call and `finish_reason: "tool_calls"` (`src/core/test/stub_step.ail:771–781`). Under the wiring runner's `hybrid_tools: false` (`phase_c2_wiring_scenarios.ail:121`) the call takes the native path (`src/core/tool_phase.ail:452–453`), and `scenario_max_steps` proves the loop keeps calling the model on these steps until the budget fails, with an empty scripted tool queue and a budget of 2 (`scripts/dst/terminal_trace_dst.ail:127–134`). A third runner with `step_budget: 3` is a copy of `run_scripted` (`phase_c2_wiring_scenarios.ail:120–122`) with `3` in place of `8`.

**Red first, as stated.** At HEAD the run's `result` is `Err({ code: "Internal", … })` (`session.ail:2205`) with `finish_reason_wire(TermMaxSteps) == "max_steps"` (`:3697`), and `TracedSessionResult` has no `suspended` field (`:175–180`), so the post-Part-4 assertions do not compile and the pre-Part-4 assertions pass. Genuinely red for the right reason.

**Eight messages.** The wiring seed is `[system "s", user "u"]` (`:66–68`); each model call appends the assistant message (`session.ail:2887`) and the native tool phase appends its results; `step_idx` increments once per model call (`:2850`, `:2908`, `:2945`, `:2990`), so after three calls `step_idx == 3` and `call_model_or_fail` fails at `3 >= 3` (`step_machine.ail:93–94`). `2 + 3 × (1 + 1) = 8` holds if the native path appends exactly one tool message per call; `terminal_trace_dst.ail` does not assert a history length, so the first green run of this fixture is what pins `8`. The plan should say "expected 8; pinned at first green" rather than assert it from reasoning alone.

**`RunSuspended.session_id`** as the run's derived id (`:3137–3139`) is consistent with every other record of the run (`:335–341`) ✓. **No stderr line in P1** ✓ and the "Do not" row enforces it (`PLAN-003:310`).

## 3. The rebuilt live probe

**The mechanism works.** With `MOTOKO_HEADLESS` unset, `headless_mode()` is false (`src/core/rpc.ail:189–192`); with no task in argv, `run_with_config` calls `await_first_task`, which reads JSON `user_message` lines from stdin (`:277–296`, `:231–235`); after the run the conversation loop reads the next line (`session.ail:3367`), and `exit` returns from the loop (`:3373`), so `main` returns (`rpc.ail:355–359`) and the process exits 0. The comment at `session.ail:3352–3353` says `readLine` blocks on a non-TTY rather than returning `""` at EOF, which is why the pipe must stay open until `exit`; with data on the pipe it returns lines. Correct as the plan states it.

**`--no-backend`** sets `backend.mode` to `"none"` and `auto_start` to `false` (`src/core/config.ail:497–500`); `start_or_connect_backend` then returns a handle with no process (`src/core/backend.ail:27–33`). Native tools do not go through the env server (`tool_phase.ail:452–453`), so a tool-looping task still loops. Fine.

**Two facts the plan does not state:**

1. **`max_steps: 5` has no environment override on the AILANG side.** It is read from the profile's agent JSON (`config.ail:313`), and the profile directory is `<workdir>/.motoko/config/<profile>` (`:186–187`); the TS `AI_MAX_STEPS` mapping (`src/tui/src/config.ts:25`) is the TUI's, which the probe does not run. The probe needs a probe profile directory with `max_steps: 5` and `--profile <name>` on the child's argv. The loop's `step_budget` is then `budget.total`, which `default_budget_plan(max_steps, …)` sets to `max_steps` (`rpc.ail:88–94`, `:116–118`, `:351`), unless an extension's budget hook patches it, so the probe profile should load no budget-patching extension.
2. **`msg_count` is the compacted payload's length**, `List.length(compacted_msgs)` (`session.ail:2768`, `:2775`), not the retained history's. It equals the retained history plus the operator message only when no compaction stage rewrote the payload (`compaction_ai_applied == 0`) and no message was injected before the call. Five steps will not trip compaction, and the assertion is right for this probe; the plan should state the condition so a future reader does not treat `msg_count` as the history length.

**The `steps_executed` substitute.** `run_summary.steps_executed` is `st.step_idx` at finalize (`session.ail:1535`, `:2437`; projected at `phase_vocab.ail:791`), so the exhausted run reports 5 and the resumed run its own. "The two sum to the total" is right for `steps_executed`; the judging number's `steps_executed_so_far` is `provider_calls_completed` (`:576`), which equals the sum only when every step's provider call completed. For a probe without stream errors they agree; say so.

**Reading stdout.** Every ledger event is `emit_json` on stdout with `session_id` (`:335–341`) ✓. The probe should also assert the ordering `run_suspended`, `run_summary` and the absence of `error` in the non-headless run, which is the D2 wire contract in its live form.

## 4. The `RuntimeStatusCounts` move

**No cycle.** `phase_vocab.ail` imports `compaction`, `tool_contract`, `types` (`phase_vocab.ail:17–19`); `session.ail` imports `phase_vocab`; the three moved definitions are a record type and two pure record functions with no dependency on anything in `session.ail`. `runtime_status_counts(trace)` (`session.ail:541–543`) folds over `LedgerTrace`, which `phase_vocab` owns, so it may move too, but the plan leaves it and that is fine.

**Anchor consequence: right, but it is a third moving commit.** Removing lines at `:431–437`, `:443–` and `:545–553` moves all five `session.ail` anchors (`1164`, `1423`, `1529`, `3016`, `3126`; `anchors.sh:385`), as the plan says (`PLAN-003:186`). See §5 for what that does to the count.

**One correction:** the cited range `:438–446` (`PLAN-003:184`) includes `zero_totals` (`session.ail:439–441`), which is `RuntimeLoopTotals` and must stay.

## 5. The anchor disposition

**The framing is right in kind and wrong in count.** `make anchors` runs `anchors.sh` (`Makefile:2770–2771`), which checks the five `session.ail` lines and three `tool_phase.ail` lines (`anchors.sh:384–387`) and exits 1 on any miss (its last lines). All eight miss at HEAD (§5 of the plan records it; measured again for this review). A re-baseline is an edit to that list and to `dst_attribution_table.ail`, which the three profiles pin, so each re-baseline re-issues `driver_only_version`, `no_ops_version` and `compose_profile_version` (`anchors.sh:379–381` and the footer). `check.py` is a different tool, hash-based over ADR passages, wired at `Makefile:2762` and not part of `make anchors`; the plan does not confuse them.

**The count.** With one commit per part (`PLAN-003:61–62`) and `make anchors` after every edit above an anchor (`:45–47`), P1 moves anchors in three commits, not one:

| P1 part | edit | anchors moved |
|---|---|---|
| Part 2 | `decision_fail_reason` at `session.ail:2164–2169` (message clause removed) | `3016`, `3126` |
| Part 3 | removal at `:431–437`, `:443–`, `:545–553` | all five |
| Part 4 | insertion at `:175–180`, the split at `:2437`, `c2_suspend` | all five |

So the choice is **four re-issues (sweep, Parts 2, 3, 4) or one**, not "two or one" (`:50–53`). The one-re-issue path is: defer the disposition of the eight stale anchors to P1 Part 4's commit, and relax §0.2 for P1 to "`make anchors` green at the end of the phase", with Parts 2 and 3 recording their expected drift in their commit messages. Alternatively, order P1 so the three anchor-moving edits share one commit (Parts 2–4 squashed), which contradicts §0.5. State the choice; the estimate line "up to two profile re-issues" (`:572`) then reads "one, or four".

## 6. The P3 lease-hook test

**Sound.** `registerLeaseHooks(proc: { on(event, fn) }, lease)` with a fake emitter that records registration order and calls the `SIGINT` handler to assert it returns without `kill` (`PLAN-003:413–417`) tests the two properties ADR-003 v4.1 edit 5 requires, and the fake sidesteps Node's real signal semantics, which no jest test in the suite exercises (`exit-actions.test.ts:43–115` is all manifest parsing). Two additions: name the registration point in `index.ts` — between `initExitActions()` (`:825`) and `initHerdrReporter()` (`:827`), so that the `exit` listener order is exit actions, lease, reporter — and assert in the fake that the `exit` handler performs no asynchronous work, since Node does not await `exit` listeners.

## 7. Can P1 start?

**Yes.** The only precondition is the plan's own §0.1: run the sweep and dispose of the eight stale anchors, and decide the re-issue count (§5). Nothing else blocks Part 1. Three line edits to fold before Part 1's commit:

1. Import `continuing_token_step` in `phase_c2_wiring_scenarios.ail:33` and cite `stub_step.ail:771–781`.
2. Add the probe profile directory with `max_steps: 5` and no budget-patching extension to Part 1 item 3 (`config.ail:186–187`, `:313`; `rpc.ail:88–94`, `:116–118`).
3. Fix `:438–446` to `:443–` and state the `msg_count` condition (§3).

## 8. Coordinate audit (new in v2)

| cited | verified | note |
|---|---|---|
| `session.ail:431–446` | partly | the type is `:431–437`; `zero_totals` `:439–441` is not part of the move; `zero_runtime_status_counts` starts at `:443` |
| `:2205–2206`, `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873` | yes | the seven `c2_finalize` call sites, exactly |
| `:2658`, `:2773–2775` | yes | tool-produced status; `msg_count` is `List.length(compacted_msgs)` |
| `:3148`, `:3170`, `:3619` | yes | the three exported entries |
| `:3352–3357` | yes | the `readLine` non-TTY comment and the headless return |
| `step_machine.ail:128–129` | yes | |
| `phase_vocab.ail:17–19`, `:791`, `:1221–1229` | yes | |
| `terminal_trace_dst.ail:77–80`, `:127–134` | yes | the helper it wraps is `stub_step.ail:771–781` |
| `phase_c2_wiring_scenarios.ail:120–122` | yes | the seed history is `:66–68`; imports at `:33` lack `continuing_token_step` |
| `anchors.sh:22`, `:379–387` | yes | the list is `:384–386`; the script exits 1 on a miss |
| `Makefile:342–345`, `:436–441`, `:1221`, `:1283` | yes | `make anchors` is `:2770–2771`; `check.py` at `:2762` is separate |
| `runtime-process.ts:355–357` | yes | |
| `herdr-agent-state.ts:278–280`, `:296–301`; `herdr-agent-state.test.ts:49–55` | yes | |
| `exit-actions.test.ts:43–115` | yes | |
| `index.ts:415`, `:1063` | yes | |
| `config.ail:235`; `rpc.ail:355–359` | yes | `--no-backend` takes effect at `config.ail:497–500`, `backend.ail:27–33` |
| `dst_invariants.ail:788–796` | yes | |
| "`max_steps: 5`" (`PLAN-003:140`) | **incomplete** | profile JSON only (`config.ail:313`; directory `:186–187`); `step_budget = budget.total = max_steps` via `rpc.ail:88–94`, `:116–118`, `:351` |
| "two re-issues, not one" (`:52`) | **no** | four or one (§5) |

## Required changes before P1 Part 1's commit

1. §0.2 and §7: restate the anchor choice as four re-issues or one, and pick the one-re-issue path with §0.2 relaxed to phase-end for P1 (`anchors.sh:379–387`; `session.ail:2164–2169`, `:431–`, `:545–553`, `:175–180`).
2. P1 Part 1 item 1: import `continuing_token_step` (`phase_c2_wiring_scenarios.ail:33`; `stub_step.ail:771–781`); say `8` is pinned at first green.
3. P1 Part 1 item 3: add the probe profile directory and the no-budget-extension rule; state that `msg_count` is the compacted length and the condition under which it is the substitute (`session.ail:2768`, `:2775`); state that `steps_executed` and `provider_calls_completed` agree only without stream errors.
4. P1 Part 3: `:438–446` → `:443–`, leaving `zero_totals` in place.
5. P3 Part 2: name the registration point (`index.ts:825–827`) and the synchronous-`exit`-handler assertion.
