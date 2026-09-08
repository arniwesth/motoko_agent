# ADR-002 v4 adversarial review verdicts

Date: 2026-09-07
Reviewed HEAD: `3ee3d03025c7666e71a39e1106599803907e1892` (`git rev-parse HEAD`); `git diff --stat 97827bf 3ee3d03 -- src/ packages/` is empty, so every `src/` and `packages/` coordinate below is also valid at `97827bf`
Subject: `ADR-002-park-and-wake.md` v4
Against: `REVIEW-adr002-v2.1-verdicts-codex.md` (the v2.1 review; §1 dispositions, §2 D1–D5, §4 metric, "Required ADR changes"), and `ADR-003-session-journal-and-resume.md` v6.1 (the file was renamed from `-snapshot-` in v5; ADR-002's links at `:10`, `:158`, `:456`, `:566` resolve)

Every coordinate v4 cites was checked at this HEAD. §9 is the audit.

## Overall verdict

**Accept with corrections. PLAN-002 can be written for D5 steps 1–2 now; steps 3–5 need four things settled first.** The v2.1 review's corrections are folded: the D2 pipeline is explicit and implementable at the sites it names, the request id is ADR-003's `run_id`, `HostError` leaves the wait open, the descriptor is a sum with a lifecycle table, D1 is scoped and its two orders are right, D4's three decisions are taken, the unbound default is defined, and the metric is exactly four. The residuals are real but small:

1. **The unbound default advances a world that has no `advance` before PLAN-001 P2.** D5 step 3 lands the `Ports` field and `wake_read_unbound` "before or with PLAN-001 P2" (`ADR-002:478–490`), and the default's successor is `advance(world, WakeRead)` (`:486`). `advance`, `ordinal` and `pending` are PLAN-001 P2 Part 1's (`PLAN-001:370–375`; no `ordinal` on `WorldState` at HEAD, `src/core/ports.ail:183–196`). Either step 3 is "with P2", or the pre-P2 default returns the world unchanged and gains its advance when P2 lands.
2. **DP7 first has a cost the ADR does not price.** `dp7_rejection_errors` calls `run_dp7_verifier` (`src/core/session.ail:1976–1988`), which shells out to `rt.verification.command` when verification is enabled (`:1930–1944`, the `exec` at `:1933`). Today it runs only on candidates that reach `c2_after_dp7` (`:3020`, `:3080`); under stage 2 it runs on every complete candidate, including the blank ones the empty-stop guard would have bounced and the ones the persist nudge would have re-prompted. In the harness `empty_rt()` disables verification (`src/core/test/stub_step.ail:786`), so fixtures will not show it; live sessions with a verifier will. State it, or gate stage 2 on a non-blank candidate.
3. **`Park` needs a request id `StepState` cannot supply.** `decide` is a pure projection of `StepState` (`src/core/step_machine.ail:114–138`; `StepState` at `src/core/phase_vocab.ail:308–318`), and D2 says `decide` changes by one arm, `await_wake` → `Park` (`ADR-002:304–305`). `ParkRequest` carries `request_id = <run_id>.p<park ordinal>` (`:312`, `:315–317`); neither `run_id` nor a park ordinal is in `StepState`. Either `Park` carries only the waits and the driver builds the request from `RunIdentity` and its own counter, or `StepState` gains both. Say which; the first keeps `decide`'s tests untouched.
4. **`settled: true` in `DelegateCheck`'s metadata does not exist.** The lifecycle table keys a row on it (`:415`); the check's metadata is `meta_timed` — delegate, pane, channel, started, elapsed, waited (`packages/motoko-ext-herdr/herdr.ail:172–177`). It is a new extension field the core will read; name it as new, beside D3's `wait` on `Delegate`'s metadata (`:164–167`).

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT** | Scope, both orders and the extension split are right against `session.ail:1550–1554`, `:2473–2488`, `:3418–3426`, `ui.ts:2752–2755`, `herdr.ail:1089–1102`. |
| D2 | **ACCEPT WITH CORRECTIONS** | Pipeline implementable at `:3012–3082` and `:2352–2403`; items 2 and 3; "their fixtures move" is not true at HEAD (§3). |
| D3 | **ACCEPT WITH CORRECTIONS** | Sum and table are right; item 4; one missing row (§4). |
| D4 | **ACCEPT WITH CORRECTIONS** | Three decisions taken and consistent with ADR-003 D5; the framing subset needs a world in the loop (§7); one coordinate. |
| D5 | **ACCEPT WITH CORRECTIONS** | Sequence is right; item 1. |
| D6 | **ACCEPT** | A pointer to ADR-003 D7, stated in both directions. |

## 1. Disposition of the v2.1 corrections

**"Required ADR changes" (the review's closing list):**

| # | required | disposition | evidence |
|---|---|---|---|
| 1 | D2 as `DP7 → wait classification → completion-only solver/persist`, session-global request id | **Folded** (`ADR-002:283–319`) | Residuals: items 2 and 3. |
| 2 | Metric exactly four, verified path separate | **Folded** (`:509–523`) | §6. |
| 3–5 | Split D6; capture before discard; strict decode, identity, publication failure | **Folded by v3** into ADR-003, now v6.1 | `:453–469`. |
| 6 | D4's framing/identity subset before stage 2; a durable waiter | **Folded** (`:440–451`, `:494–497`; ADR-003 D7) | §7. |
| 7 | Executable acceptance test for continuity | **Folded** in PLAN-003 P1 (its judging number) | `:556–557` names the dependency. |

**Per-decision corrections (§2 of the review):**

- **D1** (three): non-zero exit scoped to `--answer-file` one-shots — **folded** (`:245–250`; the interactive re-entry at `session.ail:3418–3426` and `ui.ts:2752–2761` is unchanged); both orders — **folded** (`:251–254`; trace `DoneEvent` then `RunSummary` at `session.ail:2480–2482`, stdout `run_summary` at `:1553` then `done` at `:2487`); re-read as extension work — **folded** (`:258–262`; `herdr.ail:1089–1102`).
- **D2** (three): pipeline — **folded**; identity — **folded** (`:315–317`, matching ADR-003 v6.1 D5's `<session_id>.r<resume_count>.<run_ordinal>`); `HostError` — **folded** (`:355`, `:412`).
- **D3** (three): sum — **folded** (`:386–391`); lifecycle deltas including `HostError`, retry, duplicate settle, failed second read — **folded** (`:404–418`); "only settlement path" wording — **folded** (`:420–422`; `Delegate` opens through `dagr_open`, `herdr.ail:947–949`).
- **D4** (three decisions) — **folded** (`:433–444`). One coordinate: EOF returns at `session.ail:3368` (`if raw == "" then ()`); `:3372` is `let cmd_type` (`:434`).
- **D5** (three): unbound default — **folded** (`:484–490`), item 1; D6 stage 1 before P2 — moot, D6 is ADR-003's; D4's subset before stage 2 — **folded** (`:494–497`).
- **#26 coordinates** — re-issued at `3ee3d03` (`:575–588`); §9 finds two wrong.

## 2. Per-decision verdicts

### D1 — accept

Verified: `--headless` exits on `done` in both non-TTY loggers (`src/tui/src/index.ts:513–519`, `:572–575`; flag at `:605–606`); the non-TTY callback drains the logger before forwarding terminal events (`:870–884`); exit actions register before the reporter (`:820–827`; `herdr-agent-state.ts:295–301`, `:330–351`); the interactive `error` case keeps the loop alive (`ui.ts:2752–2761`; `session.ail:3418–3426`); the extension settles `lost` without a second read on the agent-gone branch (`herdr.ail:1089–1102`, settle at `:1095–1099`) and reads first on the post-wait branch (`:1113–1114`). Nothing to correct.

### D2 — accept with corrections

§3. Corrections: items 2 and 3; "their fixtures move" (`:507`).

### D3 — accept with corrections

§4. Corrections: item 4; the missing "check failed, nothing settled" row.

### D4 — accept with corrections

§7. Corrections: the EOF coordinate; the world the between-turn frame needs.

### D5 — accept with corrections

Sequence verified against what exists: the three `Ports` literals (`ports.ail:2556–2572`; `scripts/dst/long_qwen_compaction_dst.ail:383–403`, `:513–533`); `derive.py`'s `HELPED`, `REQUEST_CLASS`, `CALL_RE` (`tools/driver_leaf_inventory/derive.py:94–105`, `:142`, `:151–155`); PLAN-003 P1 supplying `RunIdentity` (`PLAN-003:275–286`). Correction: item 1.

### D6 — accept

`ParkEntered` and `WakeReceived` appended and emitted (`:459–462`) are what ADR-003 v6.1 D7 consumes; `--park-exits`, the seeded cursor and the exactly-once rule are ADR-003's (`:463–468`). Consistent both ways.

## 3. The D2 pipeline in depth

**Implementable at the named sites.** The classification is one block: the `CallModel` arm's `None =>` branch (`session.ail:3012–3082`) calls `dispatch_solver_candidate` (`:3017`; `src/core/ext/runtime.ail:676–683`, row `{Process, IO, Clock}`), then `Accept` → `c2_after_dp7` (`:3019–3020`), `ContinueWithFeedback` → `solver_feedback` state (`:3021–3046`), `NoDecision` → persist nudge (`:3048–3078`) or `c2_after_dp7` (`:3079–3080`); `c2_after_dp7` runs the verifier (`:2352`) and sets `dp7_rejected` (`:2369`) or `dp7_approved` (`:2394`). `dp7_rejection_errors` takes no world (`:1976`), so DP7 can move ahead of solver dispatch without a threading change; the solver's successor (`token_to_world(finalized.next_state)`, `:3031`, `:3063`, and the one `c2_after_dp7` receives at `:3020`) then threads exactly as today, one stage later. `classify_candidate` is therefore an effectful function (`{Process, IO, Clock, Trace}`), not a pure one; the ADR's "one function, applied in this order" (`:284`) is right, but PLAN-002 should not expect a pure unit test of it — the pure part is `decide`.

**What changes for the solver extensions.** Both solver-role extensions decide on `(ctx, candidate)` alone: `empty_stop_guard.decide_with_budget` bounces a blank candidate under budget (`packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:34–37`); `progress_contract_guard.decide_with_budget` bounces a self-reported incomplete one unless a delegate is open (`packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:183–188`, `has_open_delegate` at `:179–181` over the prose recogniser at `:141–145`). Under stage 2 a DP7-rejected candidate never reaches them; under stage 3 neither runs while waits are open. Their own tests are pure over `(ctx, candidate)` and do not move. The wiring scenarios import both guards (`scripts/dst/phase_c2_wiring_scenarios.ail:59–60`) and assert decision sequences (`:112–118`), but run with `empty_rt()`, whose verification is disabled (`stub_step.ail:786`), so DP7 approves and the sequences are unchanged. "Their fixtures move" (`ADR-002:507`) is not true at HEAD; what moves is live behaviour under a verifier (item 2) and any fixture that enables verification, of which the tree has none that reach this arm. Say that.

**Stage 3 against the empty-stop guard and the persist nudge.** Safe. With open waits, stage 3 sets `await_wake` before stage 4 runs, so neither the guard's `ContinueWithFeedback` nor `should_inject_persist_nudge` (`session.ail:3049`) is consulted; the core's own `EmptyStopFinalize` floor lives inside the `Finalize` arm (`:2462–2472`), which stage 3 pre-empts. After the wake the candidate is a new one and stage 4 runs on it with `nudges_used` untouched. The narrowed guarantee "with open waits, no stop-class candidate finalizes" (`:302`) holds by construction.

**The one-arm change to `decide`.** Sufficient for the projection: `decide` dispatches on `last_finish_reason` (`step_machine.ail:114–138`) and an `await_wake` arm returning `Park` is one line, with the fifteen existing `decide` tests (`:246–396`, not `:279–377` as cited) untouched. Not sufficient for the payload: item 3. Note also that `dp7_fail_open`, listed in stage 5 (`ADR-002:292`) and in `decide`'s stop class (`step_machine.ail:128`, test `:361`), has no producer in `session.ail` at HEAD; it is a reason string only the test sets.

**Identity.** `request_id = <run_id>.p<park ordinal>` (`:315`) is unique across turns and resumes because `run_id` is (ADR-003 v6.1 D5). Correct, given item 3's source for the ordinal.

## 4. The D3 lifecycle table against `herdr.ail:1057–1132`

`do_check` routes motoko handles to `do_check_motoko` (`herdr.ail:1162–1175`). Its branches and the table's rows:

| branch | code | table row |
|---|---|---|
| answer present on the early read → close pane, settle `done` | `:1066–1087` | "`DelegateCheck` that settles" ✓ (once `settled` exists, item 4) |
| `agent get` fails and the agent is gone → settle `lost` without a second read | `:1090–1099` | "second answer read fails after the agent is gone" ✓ under D1's re-read rule (`ADR-002:258–262`) |
| `agent get` fails otherwise → error result, **nothing settled** | `:1100–1102` | **no row**: the wait must stay open, as for `HostError`; add "check returns an error without settling → keep" |
| wait-until, then answer → settle `done` | `:1108–1124` | ✓ |
| wait-until, agent gone, no answer → settle `lost` | `:1130–1132` | ✓ |
| `Delegate` succeeds → `dagr_open` with `retry_of` | `:947–949` | "register"; the re-delegation row's "old stays until settled or lost" is consistent with `retry_of` linking the records, and the table should say the new wait's `run_key` names the retry |

The idempotent-settle row (`:416`) cites `:1066–1087`; the idempotence is `dagr_settle`'s, which the ADR states elsewhere; fine. The table is complete once the error-without-settle row is added.

## 5. The unbound default

`wake_read_unbound` returning `HostError("wake_read unbound")` with one `advance(world, WakeRead)` (`ADR-002:484–490`) satisfies ADR-001 D2 once `advance` exists: a helped leaf advances once and is witnessed before any record (`ADR-001:386–389`, `:396–404`); the scanner sees it through `HELPED` (`ports.wake_read` / `st.provider.wake_read` → `WakeRead`), `REQUEST_CLASS` and `CALL_RE` (`derive.py:94–105`, `:142`, `:151–155`), and the missing-wake mutant of the v1 review goes red. Item 1 is the timing.

**Queue exhaustion observable: yes.** `scripted_approval` reports `eof: true` on an empty queue (`ports.ail:979–983`) and `recording_approval` records it as `OutcomeMissing` (`:1741–1744`); the ADR's scripted `wake_read` instead falls through to the unbound default (`:487–489`), so exhaustion reaches the model as a `HostError` message with the wait open, reaches the ledger as `WakeReceived(HostError)`, and reaches the recording adapter as an interaction it can mark missing. That is more observable than a hang or a fabricated wake, and it is the same shape a live run hits if the real binding is not installed. One consequence to state: a fixture whose `wakes` queue is short by one will not fail at the exhaustion point; it will fail when the model's next candidate, told of a `HostError`, does not match the script. The "missing wake" control fixture (`:374–375`) should assert the `HostError` outcome directly.

## 6. The metric against `step_machine.ail:114–138`

| call | driver state after | `decide` |
|---|---|---|
| 1 | assistant with `Delegate` tool call | pending tools → `RunTools` (`:117–120`) |
| — | tool result; `tools_complete` (`session.ail:2264`) | `call_model_or_fail` (`step_machine.ail:134–135`) |
| 2 | stop-class candidate with the wait open | stage 3 → `Park` (today `:128–129` → `Finalize`) |
| — | wake → loop-authored message; `user_injected` | `call_model_or_fail` (`:136–137`) |
| 3 | `DelegateCheck` tool call | `RunTools` |
| — | `tools_complete` | `call_model_or_fail` |
| 4 | final answer | `Finalize` |

Exactly four on the success path (`ADR-002:509–521`); a verification tool after the check adds one call to emit it and one to consume it, so at least five (`:519–521`). Both statements hold.

## 7. D4 against `session.ail:3367–3430` and `rpc.ail:218–237`

- **`restart` cancels and takes today's exit**: `SessionSuspend` then return (`session.ail:3391–3399`) ✓. **EOF cancels and returns**: `:3368` ✓ (the ADR says `:3372`). Both leave the host to cancel its waiters, which D2 lists (`:339–340`).
- **Initial input out of scope**: `await_first_task` runs before any runtime or world exists (`rpc.ail:218–239`; the build starts at `:298`) ✓.
- **Frame identity**: the between-turn frame opens after `RunSummary` at the previous frame's `final` (`ADR-002:440–444`) — the same value ADR-003 v6.1 D5 makes `from_ordinal` (`c2_finalize` returns the world after its clock read, `session.ail:1550–1554`). Consistent: a resumed frame and a between-turn frame open at the same number by the same rule.

**One gap the subset must name.** A between-turn `wake_read` is a helped leaf and must be called with a world; the conversation loop holds none — it recurses with the pre-turn `provider` and drops every successor by design (`:3380–3386`, `:3419`, `:3426`, `:3611`), which ADR-001 records as "out of reach" for the frame gate (`ADR-001:448–449`). "D4's framing and identity subset" (`ADR-002:450–451`, `:494–496`) therefore includes threading `traced.world` into the loop's parameters — the largest single piece of the debt D4 lists (`:446–448`). Say so, because ADR-003 D7 waits on it.

## 8. Can PLAN-002 be written?

**Steps 1–2: yes, now.** D1 is host and extension work with no core dependency; step 2's `classify_candidate` refactor with `open_waits` always empty (`ADR-002:474–477`) is a `session.ail` change gated by the existing `decide` tests (`step_machine.ail:246–396`) and the DP7-before-solver cases, and it depends on nothing outside HEAD except PLAN-003 P1's `RunIdentity` if the plan wants the request id in the same commit (it need not: step 2 parks nothing).

**Steps 3–5: after four line decisions** — item 1 (the default's advance timing), item 2 (DP7's cost, or a non-blank gate), item 3 (where the request id is built), item 4 (the `settled` field). None changes the direction; each would otherwise be decided by the plan.

## 9. Coordinate audit

| cited | verified | note |
|---|---|---|
| `session.ail:684–697`, `:1550–1554`, `:2352–2403`, `:2394`, `:2468–2488`, `:3017–3080`, `:3020`, `:3080`, `:3367–3430`, `:3387–3389`, `:3391–3399`, `:3415–3426`, `:3418–3426`, `:3582–3586` | yes | |
| `session.ail:3372` as EOF (`:434`) | **no** | EOF returns at `:3368`; `:3372` is `let cmd_type` |
| `session.ail:1078–1106` | yes | extension-effect bridge (v1 retraction) |
| `step_machine.ail:93–111`, `:114–138`, `:134–135` | yes | |
| `step_machine.ail:279–377` "every existing `decide` test" | **partly** | the `decide` tests span `:246–396` (fifteen); the cited range omits four |
| `phase_vocab.ail:449`, `:901–902` | yes | `StepDecision`; the cap; `StepState` at `:308–318` |
| `ports.ail:789`, `:979–983`, `:1718–1745`, `:2556–2572` | yes | |
| `tool_phase.ail:436–449` | yes | `Handled` arm with `result_env` before `handled_tool_message` |
| `stub_step.ail:205–213` | v1 | not re-read |
| `dst_interaction.ail:59–66`; `dst_replay.ail:707–718`, `:793–824`, `:805–825` | yes | no wake identity today |
| `ext_world.ail:515–553`; `dst_invariants.ail:788–806`, `:946`; `rpc.ail:218–237` | yes | `await_first_task` runs to `:239` |
| `tool_contract.ail:13–20`; `derive.py:14–22`, `:142`, `:151–154` | yes | `CALL_RE` runs to `:155` |
| `herdr.ail:112`, `:164–167`, `:935–943`, `:947–955`, `:1057–1132` | yes | `meta_timed` at `:172–177` has no `settled`; `do_check` dispatch at `:1162–1175` |
| `herdr.ail:1091–1100` for the `HostError`/`Lost` split | yes | the split is `:1095–1100` |
| `types.ail:706–718`, `:749–758`; `dagr.ail:40–42`, `:386–392` | yes / v1 | |
| `progress_contract_guard.ail:141–191`, `:179–188`; `empty_stop_guard.ail:20–37` | yes | |
| `herdr-agent-state.ts:43`, `:46`, `:278–286`, `:295–301`, `:330–351` | yes | |
| `ui.ts:790`, `:2726–2745`, `:2752–2755`, `:4046–4049` | yes | |
| `index.ts:513–519`, `:572–575`, `:605–606`, `:820–827`, `:870–883` | yes | the callback runs to `:884` |
| `runtime-process.ts:592–600`, `:754–778` | yes | |
| `ADR-003-session-journal-and-resume.md` links | yes | the file was renamed in ADR-003 v5 |
| not cited, load-bearing | — | `session.ail:1930–1944` (the verifier's `exec`), `:1976–1988`; `ext/runtime.ail:676–683`; `stub_step.ail:786` (verification off in fixtures); `PLAN-001:370–375` (`advance` is P2's) |

## Required changes before PLAN-002 steps 3–5

1. D5 step 3: "with PLAN-001 P2" for `wake_read_unbound`'s `advance`, or a pre-P2 default that returns the world unchanged (`PLAN-001:370–375`; `ports.ail:183–196`).
2. D2 stage 2: price the verifier on every complete candidate (`session.ail:1930–1944`, `:1976–1988`) or gate it on a non-blank candidate; replace "their fixtures move" with "live behaviour under a verifier changes; fixtures with `empty_rt()` do not" (`stub_step.ail:786`).
3. D2: say where `ParkRequest.request_id` is built — the driver from `RunIdentity` and a per-run park counter, with `Park` carrying only the waits — so `decide` stays a pure projection (`step_machine.ail:114–138`; `phase_vocab.ail:308–318`).
4. D3: name `settled` as a new field of `DelegateCheck`'s metadata (`herdr.ail:172–177`) and add the "check returns an error without settling → keep" row (`:1100–1102`).
5. D4: the framing subset includes threading `traced.world` into the conversation loop (`session.ail:3380–3386`, `:3419`, `:3426`, `:3611`; `ADR-001:448–449`).
6. Coordinates: EOF at `session.ail:3368`; the `decide` tests at `step_machine.ail:246–396`; note that `dp7_fail_open` has no producer at HEAD.
