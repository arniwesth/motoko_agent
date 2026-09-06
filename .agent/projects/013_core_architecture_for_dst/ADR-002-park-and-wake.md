# ADR-002: Waiting is a step-machine state served by a port, and task completion is a runtime act

Date: 2026-09-06 (v1, v2 and v2.1 the same day)
Status: **Proposed (v2.1 — v2 supersedes v1 after an adversarial review; v2.1 adds D6 at the owner's request, unreviewed).** v1 was reviewed by Codex
([`REVIEW-adr002-verdicts-codex.md`](REVIEW-adr002-verdicts-codex.md), reviewed HEAD `407d673`):
overall *reject as written; retain the owner's park-and-wake direction*. D1, D3, D4 accepted with
corrections; D2 and D5 rejected. v2 folds all 26 corrections. The direction is unchanged and is
the owner's ("a parked state in the step machine that awaits on a port … is my preferred
direction"; "the motoko runtime has to emit an explicit task complete signal").
Provenance: measurements are the review's own re-derivation (§7.6 there) and
[`../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md)
as corrected below. Code coordinates were re-read at HEAD `8980ba6`, which differs from the
reviewed `407d673` by ten inserted lines in two files; every coordinate below was checked at
`8980ba6`.

---

## Version history and retractions

**v1 → v2.** What v1 got wrong, in the order the review found it, so a reader of v1 knows what
not to carry forward:

1. *"193 model steps."* The turn made **195** provider calls (195 `thinking`, 195
   `provider_call_prepared`, `steps_executed: 195`). v1 subtracted the two guard-rejected
   candidates, which were provider calls too.
2. *"55 checks with empty arguments, all seeing `working`."* All 55 carried a name. 50 saw
   `working` with no answer, three saw herdr `done` with no answer, one saw `idle` with no
   answer, one collected the answer. The breakdown was ~52 pane reads (not 60), four `send-text`
   nudges (not two), one `sleep 90` inside a compound command, two `Delegate` launches, and the
   takeover.
3. *"`approval_read` is served by the TUI's approval UI."* Production approval **ignores the
   request and calls `readLine()`** (`src/core/test/stub_step.ail:205–213`); the TUI has no
   approval handler and its output dispatch services `tool_calls`, not approval requests
   (`runtime-process.ts:592–600`). The port *shape* is the template; the host service is new.
4. *"DST scripts approvals with `scripted_approval_next`."* That is a test-state helper. The
   driver binds `ports.scripted_approval` consuming `WorldState.approvals`
   (`ports.ail:979–983`, `:2558`). A wake needs the same set approval has: adapter, cursor in
   `WorldState`, `ext_world` codec, recording adapter, interaction identity and outcome,
   reconstruction. A `RequestClass` is an ordinal witness, not a replay identity.
5. *"The motoko runtime never exits."* `--headless` runs one task and exits on `done`
   (`index.ts:605–606`, `:513–519`, `:572–575`; `session.ail:3357`). The runtime already emits a
   typed `DoneEvent` before `RunSummary` (`session.ail:2480–2487`). D1 adds host-owned answer
   publication and a finer host state, not the first completion signal.
6. *"Park on `finish_reason == "stop"` makes Finalize-with-open-waits unreachable."* Ordinary
   completed candidates arrive as `dp7_approved` (`session.ail:2394`;
   `step_machine.ail:128`), and solver guards and the persist nudge run in the driver before
   `decide` sees any of them (`session.ail:3017–3080`). Empty stops are a further path
   (`empty_stop_guard.ail:20–37`, `session.ail:2468–2482`). The guarantee is narrowed and the
   insertion moved upstream (D2).
7. *"`herdr agent wait <pane>` is the exit waiter."* Its default matches `idle`, `done` or
   `blocked`, indefinitely, which includes startup idle; and `Delegate` returns before the
   agent row exists (`herdr.ail:935–943`; `types.ail:749–758`). D2 names an actual observation
   protocol.
8. *"Liveness ages during a park."* The extension never writes `last_output_at`; it writes only
   `prompt_acknowledged` (`packages/motoko-ext-herdr/dagr.ail:40–42`, `:386–392`). Nothing ages.
   Retracted; observation-on-wake stays a proposal.
9. *"A five-class fixture becomes six."* `fixtures/expected.json:13–30` holds four shape
   verdicts and no class count. The freeze is Python data (`derive.py:14–22`, `:142`) and prose.
   The real hazard is that `CALL_RE` (`derive.py:151–154`) cannot see `wake_read`: the review's
   in-memory mutant appended an unhelped wake call to `session.ail` and the inventory stayed at
   24 sites, zero unresolved.
10. *"After P2 is cheaper."* There are **three** full `Ports` literals (`ports.ail:2556–2572`;
    `scripts/dst/long_qwen_compaction_dst.ail:383–402`, `:513–532`); the other providers
    inherit by record update (`stub_step.ail:221–224`, `:554–575`, `:648–667`). A field addition
    costs the same before or after P2; after P2 it additionally reopens P2's codecs. D5 is
    re-sequenced.
11. *"D3 is host and extension only."* The consumer that lifts the descriptor out of the tool
    envelope before `handled_tool_message` caps it (`tool_phase.ail:435–445`;
    `phase_vocab.ail:867`) is core work.
12. *"`DelegateCheck` is unchanged."* It settles and closes on its own (`herdr.ail:1066–1087`,
    `:1113–1124`); if only wakes drain waits, a manual check leaves a stale wait. And nothing
    writes the run file except `DelegateCheck` (`herdr.ail:112`), so delivering an answer to the
    model does not settle the attempt.
13. *"The guard fix is belt."* The retained guard is a last-signal prose recogniser
    (`progress_contract_guard.ail:141–191`): launch A, launch B, collect B, and A is invisible.
14. *"D4 closes multi-turn world-threading."* The debt also includes the model-change successor
    discard (`session.ail:3387–3389`), turn recursion on the stale provider (`:3415–3426`), the
    initial identity read (`:3582–3586`), `rpc.await_first_task` (`rpc.ail:218–237`), and a
    between-turn frame that `RecordAfterTerminal` will accept (`dst_invariants.ail:788–806`).
15. *"O1 is not replayable."* Extension effects already pass through `Ports.ext_effect_exec` and
    have a script and reconstruction path (`session.ail:1078–1106`; `dst_replay.ail:805–825`).
    O1 is still rejected, for the reasons that remain.
16. *"The truncated-arguments diagnosis is established."* It is inferred from a normalised `{}`
    and an output-token count; the old decoder kept no raw string. It is a diagnosis that needs
    raw provider evidence, and D1 does not repair a worker that never made its edit.
17. The 869 ms startup idle is `DESIGN-motoko-as-delegate.md:49–53`'s measurement, not this
    log's. The measurement snapshot was 300/16/65 through `LOG:4282`; the file has grown since.

**v2 → v2.1.** D6 (session snapshot and resume) added at the owner's request ("it would be a
very big advantage if Motoko could load an old session and run from the same state"). Nothing
else changed. D6 has not been reviewed.

Not retracted: the direction; the answer-first branch of `do_check_motoko` really does settle
`done` when the agent is already gone (`herdr.ail:1066–1087`, `agent get` confined to the
no-answer `else` at `:1089–1090`); the four-circumstances-one-report ambiguity of motoko's `idle`
(`herdr-agent-state.ts:278–286`; `ui.ts:2726–2745`); the ≥100-call excess of the measured turn.

---

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | A `done` run state; host-owned answer publication in the terminal path, before exit actions and authority release; one-shot reuses `--headless`; defined outcomes for empty, error, cancel and write failure | 2–3 days, host |
| D2 | Waits carried in `StepState`; a "waiting" candidate class decided in the driver *before* guards and persist policy and *after* pending tools, approvals and DP7 rejection; `Park` in `decide`; `wake_read` on `Ports` with a named host protocol and the full replay set approval has | 8–12 days after the surface exists |
| D3 | One `WaitDescriptor` type; producer in the `Delegate` envelope; core consumer lifts it before capping; register/update/remove semantics named; settlement stays with `DelegateCheck`, called once after the wake | 3–4 days, split host / extension / core |
| D4 | The multi-turn wait is the same park; closes ADR-001's threading debt only when its plan carries every listed successor and a between-turn frame | unscheduled, unpriced |
| D5 | D1, D3's producer and D6 stage 1 now; the `Ports` field, wake types, safe default and scanner recognition **before or with** PLAN-001 P2; activation after P2 is green, under ADR-001 D6 | — |
| D6 | A session snapshot is the tuple the loop already boots from — history, `WorldState`, prior counts, extension artifacts, model, profile, system-prefix digest — written at every turn end and at every park, read back by `--resume`. Stage 1 needs no D2; stage 2 makes a park durable | 3–4 days stage 1; 1–2 days stage 2 |

The number this ADR is judged on: the specified successful path — `Delegate`, park and wake,
`DelegateCheck`, final — must cost **≤ 4 provider calls**, verification excluded and said so.
The measured turn cost 195, of which two were launches and the rest a check-read-nudge loop
followed by a takeover.

---

## Context / the question

Motoko can delegate to another pane and cannot wait for it without paying a model step per
look. Two idle shapes exist and neither is choosable by the model:

- **Between turns**: `conversation_loop_v2_with_policy` blocks on the command channel
  (`session.ail:3367`–`3430`: EOF, malformed, `abort`, `exit`, `model_change`, `restart`,
  `user_message`). No model call. The model cannot elect this: a turn ends when the model
  stops, the progress guard reads "I'll settle it when the answer lands" as unfinished, and the
  next step is a `DelegateCheck`. Remove the guard and the session sleeps until a person types.
- **Inside a turn**: the one blocking read is `approval_read` (`ports.ail:789`). Its shape is
  right: synchronous, one request one reply, successor world returned, scripted in DST. Its
  production binding is `readLine()` with the request ignored.

`DelegateCheck` is the workaround: a bounded server-side wait (`HERDR_CHECK_WAIT_MS`, 20 s) then
a full model step. On the other side, a motoko delegate cannot say it is done in a way a waiter
can hear: Motoko reports its own lifecycle (020 ADR-001 D1) and herdr accepts `idle`, `working`,
`blocked`, `unknown` (`herdr-agent-state.ts:46`; `pane report-agent --help`). One report,
`idle`, covers startup, a turn end with work outstanding, an empty stop, and a finished task.
The extension therefore trusts only the answer file (021 dagr design §3.3), and the answer file
is written by the model because the task text asked (`types.ail:706–718`).

## Options considered

**O1 — Raise `HERDR_CHECK_WAIT_MS`.** One check blocks for minutes inside `run_herdr`. Rejected:
the operator cannot type, a second delegate cannot be checked, and the wait is a wall-clock
sleep inside a tool call — replayable as an extension effect, but as one opaque interaction with
no wire trace of what was waited for.

**O2 — The TUI owns the waiter and posts a `user_message`.** Works for claude/codex kinds today.
Rejected as the end state: invisible to the ledger and DST, indistinguishable from an operator,
no in-turn case. Retained as the `Operator` wake source under D4.

**O3 — `Park` served by `wake_read`.** Chosen. Same mechanism as `approval_read`, generalised
from "the operator must answer" to "the world must change", with the replay set approval has.

**O4 — Motoko delegates exit on completion.** Part of D1. A one-shot exit is the clearest signal
a lifecycle authority can give herdr, and the extension's answer-first branch already reads it
correctly. Not sufficient alone: the answer must exist before the exit.

**O5 — `DelegateAwait` (the review's comparator).** A tool that blocks inside the extension on the
*completion condition* (answer present, or a classified terminal condition), served through
`ext_effect_exec` and scripted through the existing extension-effect cursor. Provider calls:
`Delegate`, `DelegateAwait`, optional verify, final — meets the ≤4 number and is replayable
today. Priced at 1–2 days. **Not adopted, kept as the fallback**: it does not give operator
interruption, multi-wait arbitration, a wire record of the wait, or D4's unification, which are
the reasons for O3; if D2's surface slips past P2, O5 is the interim.

## Decision

### D1 — Task completion is a runtime act

All host-side. The reporter funnel stays 020 D2's single mutator.

1. **A `done` run state.** Both unions gain it: `RunState` (`ui.ts:790`) and `MotokoRunState`
   (`herdr-agent-state.ts:43`). Entered on the runtime's `done` event, left on the next input.
   Reported as herdr `idle` with `--message "done"`. Whether herdr shows the message on an idle
   row is **unmeasured**; the plan's first probe. External `idle` remains ambiguous until the
   answer/exit protocol below is used; `done` exists so Motoko's own display stops conflating.
2. **Host-owned answer publication.** New flag `--answer-file <path>`. In the common terminal
   path — where the non-TTY callback awaits logger closure before forwarding terminal events
   (`index.ts:870–883`), and *before* exit actions (registered at `:820–827`) and reporter
   release (`herdr-agent-state.ts:295–301`, `:330–351`) — the host publishes the answer
   atomically (write temp, rename). Rules: an existing non-empty file at the path wins; a
   non-empty `done` output is written otherwise; an **empty `done`**, a runtime `error`, an
   `abort`, or a **publication failure** writes nothing and exits non-zero with the reason on
   stderr. Evidence stays `reported`; a non-empty file is not verified success and the dagr
   design already allows the file to report failure (§4.2 there).
3. **One-shot reuses `--headless`.** The one-task path exists; `--oneshot` is added only if the
   interactive display is wanted while ending after one task, otherwise it aliases. Motoko
   delegates run one-shot with `--answer-file`. Extension-side: when the negative early read is
   followed by a failing `agent get`, **re-read the answer before publishing `lost`**
   (`herdr.ail:1089–1102` today settles `lost` without a second read; the post-wait branch at
   `:1113–1132` already reads first). Pane close on the answer branch is unchanged (`:1068`);
   exit and close are different acts and both happen.

Tests: publication before exit actions and before release, with an existing report and with an
unwritable destination; empty-done and error paths produce no file and a non-zero exit; both the
plain/JSONL and interactive one-shot paths.

What D1 does not claim: that stalled workers now produce answers. The INV write worker's
`empty_stop_finalize` followed by an empty `done` (`session_2026-09-05T19-43-24-730Z.jsonl:217–219`)
produces no file under these rules, correctly.

### D2 — Waits in the step state, a "waiting" class in the driver, `Park` in `decide`, `wake_read` on `Ports`

**Vocabulary.** A *wait* is an open handle on something outside the session that will change.
A *park* is the loop's decision to block on its open waits instead of calling the model. A
*wake* is the port's answer.

**State.** `C2LoopState` gains `open_waits: [WaitDescriptor]` (type in D3) and the projection
to `StepState` (`session.ail:684–697`) carries it; `decide` cannot see what `StepState` does not
hold.

**Classification, upstream of `decide`.** The driver already classifies candidates before
`decide`: solver extensions, then persist policy, then `c2_after_dp7` sets `dp7_approved`
(`session.ail:3017–3080`, `:2394`). A new class is inserted at a fixed point in that order:

| precedence | outcome |
|---|---|
| pending tool calls or approval | unchanged (`RunTools` / `AwaitApproval`) |
| DP7 rejection of the candidate | unchanged (`InjectUserMessage`) |
| **open waits non-empty and the candidate is stop-class** (`stop`, `dp7_approved`, `dp7_fail_open`) | `last_finish_reason: "await_wake"` → `Park` |
| solver feedback, persist nudge | unchanged, reached only with no open waits |
| stop-class with no open waits | `Finalize`, unchanged |

Empty candidates: with open waits, an empty stop **parks** — the model stopped with work
outstanding, and there is nothing to nudge it about; the empty-stop guard is not consulted on
that path and is consulted as today when no waits are open. This is the narrowed guarantee:
*with open waits, no stop-class candidate finalizes*. With no waits every existing `decide`
test (`step_machine.ail:279–377`) is preserved unchanged, which the review's control model
confirms for all eight reason strings. New cross-product cases: each stop-class reason × open
waits → `Park`; empty × open waits → `Park`; solver feedback and DP7 rejection × open waits →
`InjectUserMessage`; pending tools × open waits → `RunTools`; two open waits.

**The port.** `Ports` gains
`wake_read: (WorldState, ParkRequest) -> WakeInput ! {IO}`,
`ParkRequest = { request_id: string, step: int, waits: [WaitDescriptor] }`,
`WakeInput = { request_id: string, wait_id: string, outcome: WakeOutcome, next_state: WorldState }`,
`WakeOutcome = Settled(string) | Lost(string) | OperatorInput(string) | TimedOut | HostError(string) | Aborted`.
`request_id` is `session_id` plus a per-run park ordinal; a reply whose `request_id` or
`wait_id` does not match the outstanding request is dropped and logged, never applied to a
different pending wait.

**The host protocol (new; nothing existing serves it).** The runtime emits a `wake_request`
event on stdout carrying the `ParkRequest`; the TUI replies with a `wake_reply` command on
stdin, demultiplexed alongside `abort`, `exit`, `model_change`, `restart`, `user_message`
(`runtime-process.ts:754–778`; `session.ail:3372–3398`). While a request is outstanding:

- `DelegateAnswer` waits are **file observations**: initial read, subscribe, re-read (an answer
  present before subscription cannot be missed); first non-empty content counts only because
  D1 publishes atomically.
- `DelegateState` waits are a **registered-start observation**: wait for the agent row to exist
  (the extension returns before it does), then `agent wait --until idle,done,blocked` for
  claude/codex kinds only; a motoko one-shot's state change is its exit, observed as the row
  disappearing *after* it was seen, then the answer re-read. A default-wait success is never
  equated with an answer.
- A herdr transport failure is `HostError`, never `Lost` (the extension separates these at
  `herdr.ail:1091–1100`; the host must too).
- Operator input during a park is `OperatorInput`; this needs a **parked input route** in the
  TUI, which today rejects input while a task runs (`ui.ts:4046–4049`). `abort` is `Aborted`
  and takes the existing abort path. `restart`/`exit` cancel the request.
- Losing waiters and subscriptions are cancelled on wake, abort and runtime exit; late replies
  are dropped by `request_id`; two handles ready at once are reported in `waits` order, the
  rest remain open.
- `ParkEntered` is emitted **before** blocking, so a wait that never returns is visible.

**After the wake.** A pure function turns the `WakeInput` into a message tagged as loop-authored
(distinct from an operator's), the wait is removed from `open_waits` (or all delegate waits are
left in place on `OperatorInput`), and the next decision goes through `call_model_or_fail`
(`step_machine.ail:93–111`) — step and cost caps, checkpoint and context-pressure checks apply
as they do to every injected message. A `Settled` wake tells the model the answer is available
and to call `DelegateCheck`, which now finds it on the first, early read and performs the
extension's idempotent settle (D3). The model's first step after waking is the settle.

**DST and replay — the full set, not a helper.** Following approval item for item:

| approval has | wake gets |
|---|---|
| `ports.scripted_approval` bound in `fake_ports`, cursor `WorldState.approvals` (`ports.ail:979–983`, `:2558`; `scripted_ports.ail:74–76`) | `ports.scripted_wake`, cursor `WorldState.wakes: [WakeInput]`, successor built by the adapter (a fixture supplies observations, never whole worlds) |
| recording adapter (`ports.ail:1718–1745`) | `recording_wake` |
| interaction identity and outcome (`dst_interaction.ail:59–66`; `dst_replay.ail:707–718`, `:793–824`) | a `WakeInteraction` identity and outcome encoding; `WakeRead` the **ordinal** class is not this |
| world-token codec (`ext_world.ail:515–553`) | the `wakes` cursor round-trips; an extension round trip that rebuilds only the enumerated fields would otherwise drop it before the first park |
| parity witnesses | `ParkEntered` and `WakeReceived` appended **and** emitted, with payload assertions (`dst_invariants.ail:1742–1769` compares variant names only; wake payload equality is asserted explicitly) |

Fixtures: success (`Settled`), `Lost`, `OperatorInput` leaving the delegate pending, two
delegates with one wake, and controls: wrong handle, duplicate/late wake, missing wake (queue
exhaustion), stale world, empty stop with open waits. Two runs from the same script are a
determinism check; the saved-program replay is the recording adapter's fixture.

**World ordinal.** `wake_read` is a helped leaf under ADR-001 D2: one `advance` when the leaf
returns, witnessed before the successor enters any record. Its class is `WakeRead`, the sixth.
`approval_read` maps to `ToolExec` because it classes the dispatch it guards; a wake guards
nothing.

### D3 — One descriptor, produced by the extension, lifted by the core, settled by `DelegateCheck`

`WaitDescriptor = { id, delegate_kind, wait_kind: DelegateAnswer | DelegateState | Operator | Timer(int), locator: { pane }, answer_path, run_key }`.
v1's two sketches disagreed; this is the one type.

- **Producer.** `Delegate`'s `metadata` (`herdr.ail:164–167`) gains `wait`. Additive to the Json
  envelope (`tool_contract.ail:13–20`); no ABI sum change.
- **Consumer, core.** `execute_allowed_tool_call`'s Handled arm validates and extracts `wait`
  from the *successful extension envelope* **before** `handled_tool_message` caps the encoded
  message (`tool_phase.ail:435–445`; cap at `phase_vocab.ail:867`), and the typed result rides
  the tool fold into `open_waits`. Re-decoding a possibly truncated model message is not a
  registration protocol.
- **Lifecycle.** Register on `Delegate` success (a failed launch registers nothing). Remove on a
  matching wake; on a `DelegateCheck` that settles (the extension marks `settled: true` in its
  metadata and the core removes the wait — a manual check must not leave a stale wait);
  on `Timer` expiry. `OperatorInput` removes nothing.
- **Settlement.** Stays in `DelegateCheck` (`herdr.ail:112` is the only run-file writer). The
  wake message directs the model to call it once. Run-file truth is not moved into the core.
- **Guard.** When D2 is active, the progress guard's input is the validated wait state through
  an additive `ExtCtx` field (`open_waits`), and the prose recogniser landed as the live-run fix
  (`progress_contract_guard.ail:179–188`) becomes an explicitly limited fallback — it cannot see
  A when B was launched and collected after A.

### D4 — The multi-turn wait is the same park

The blocking read (`session.ail:3367`) becomes a park with `waits = [Operator]`; `user_message`
becomes an `OperatorInput` wake. **Scope in or out, explicitly:** `rpc.await_first_task`
(`rpc.ail:218–237`) is a second unported input wait; decide whether initial input is in.
**What closing ADR-001's threading debt actually requires**, all of it: the model-change
successor (`session.ail:3387–3389`), the stale provider across turns (`:3415–3426`), the initial
identity read (`:3582–3586`), the publish successors, and a **between-turn frame**
(`RecordAfterTerminal`, `dst_invariants.ail:788–806`; ADR-001 D2 part 3 keeps frames separate
from `done`/`RunSummary`) in which `Operator` `ParkEntered`/`WakeReceived` and the cross-turn
ordinal live. `restart`'s effect on a pending request is left open. Gate: a two-turn replay with
an intervening model change and a restart-or-EOF control. Unscheduled.

### D6 — A session snapshot at every boundary, and `--resume`

**The object.** The loop boots from exactly one tuple: `c2_initial_state_with_counts(history,
provider, world, prior_counts)` (`session.ail:709`), plus the model, the profile and the
extension artifacts the driver threads beside it. A *snapshot* is that tuple serialised:
`{ session_id, model, profile, system_prefix_digest, history: [Message], world: WorldState,
prior_counts, ext_artifacts, step_counts, written_at, reason }`. `WorldState` already has its
codec (`world_json` / `world_of_json`, `ext_world.ail:515`, `:543`) and after PLAN-001 P2 it
carries the ordinal; messages already cross the extension ABI as JSON (`history_slice`,
`packages/motoko-ext-abi/types.ail:547`); core gains a `[Message]` codec of its own, with a
round-trip test. Extension state that lives on disk under `.motoko` is already durable and is
not in the snapshot.

**Not the log.** The JSONL log records payload digests, not payloads, and compaction rewrites
history without logging the rewritten form (`session.ail:350` emits the fact, not the messages).
Reconstructing a session from the log is lossy; D6 does not attempt it.

**Stage 1 — turn boundary, needs nothing from D2.** The snapshot is written where the turn's
exit manifest is published (`session.ail:2486` inside a run; `:3416` in the multi-turn loop),
atomically (temp then rename), to `.motoko/sessions/<session_id>/snapshot.json`, replacing the
previous one. `reason` is `turn_end`, `budget_exhausted`, `abort`, `error` or `suspend`. The
step-budget termination and the `restart`/`SessionSuspend` path both write one before exiting,
which is the repair the open issue
[`../../issues/step-budget-exhaustion-starts-a-fresh-session.md`](../../issues/step-budget-exhaustion-starts-a-fresh-session.md)
asks for: reaching the budget becomes a snapshot followed by a wait for the operator, not a
fresh session. `--resume <session_id>` (an `InvocationConfig` field beside `task`,
`model_override`, `workdir_override`, `rpc.ail:245`) reads the snapshot, checks its
`system_prefix_digest` against the prompt about to be sent, and seeds
`conversation_loop_v2_with_policy` with the history, world and counts. The TUI's respawn
already carries an empty task and waits for input (`index.ts:938`); a resumed runtime does the
same, with the history on screen.

**Stage 2 — park boundary, with D2.** `ParkEntered` is followed by a snapshot with `reason:
"park"` carrying `open_waits` and the outstanding `ParkRequest`. A parked session may then
**exit** instead of blocking (`--park-exits`, off by default), and the host waiter resumes it
with `--resume` on the wake, delivering the `WakeInput` as the first command. That is a durable
wait: the process and the pane are not held for the duration, which removes the cost §Consequences
names for D2, and a wait can outlive a container restart. On resume every open wait is
re-observed before anything else (D2's file observation with initial read); a wait whose pane is
gone and whose answer is absent wakes `Lost`.

**Why the snapshot is a DST object.** The tuple is the same thing the recording adapter persists
for replay: a world and the interactions that produced it. One format means resume is a
fixture — run to a boundary, snapshot, reload into a fresh driver, continue — with the ordinal
asserted to continue from the snapshot's value, not from zero, and the `RecordAfterTerminal`
frame rule (`dst_invariants.ail:788–806`) satisfied by a resumed run opening a new frame that
cites the snapshot's final ordinal. A snapshot written at a park and one written at a turn end
replay through the same path.

**Identity.** A resumed run keeps the old `session_id` and appends to its log and its
`.motoko/sessions/<id>/` directory; the resume is itself a ledger event
(`SessionResumed({ from_snapshot, reason, written_at })`) so the wire shows the seam. A resume
into a different profile or model is a `model_change` on the resumed session, not a new one.

**Refusals.** A snapshot whose `system_prefix_digest` differs from the live prompt is refused by
default and accepted with `--resume-force`, which writes the mismatch into `SessionResumed`.
A snapshot from an older schema version is refused; there is no migration in v1 of this.

### D5 — Sequencing

1. **Now, host + extension + core:** D1; D3's producer; **D6 stage 1** (snapshot writer at the
   two publish sites, the `[Message]` codec, `--resume`, the refusal rules, the resume fixture).
2. **Now, core, priced as core:** D3's consumer and registration; `open_waits` in loop and step
   state; the guard's `ExtCtx` field.
3. **Before or with PLAN-001 P2:** the `Ports` field with a safe unbound default, the wake types,
   the `wakes` cursor and its `ext_world` codec, the three literal entries
   (`ports.ail:2556–2572`; `long_qwen_compaction_dst.ail:383–402`, `:513–532`), and scanner
   recognition — `HELPED`, `REQUEST_CLASS`, `CALL_RE` in `derive.py`, with the review's
   missing-wake mutant as a gate that must go red. No session call site yet.
4. **After P2 is green, under ADR-001 D6:** activation — the driver classification, `Park`,
   the host protocol, the recording and scripted adapters, the interaction identity, the two
   events, the fixtures, and the live measurement.
5. **D6 stage 2** lands with 4 (it is a snapshot inside `Park`), and `--park-exits` stays off
   until one live run has resumed a parked session.
6. **D4:** when 4's gate has held for one live run.

The freeze note in `derive.py` cites this ADR as the reason a sixth class exists.

## Consequences

**Gates that move.** D2 edits `phase_vocab` and `session.ail` above its pins (anchor cascade,
`make event_vocabulary`, goldens, as for ADR-001). `Ports` gains a field: three literals and the
probe default. `driver_leaf_inventory` gains recognition and a mutant gate. New DST fixtures as
listed. Host tests for `done`, publication ordering, and the parked input route.

**The metric, stated precisely.** Live and in the success fixture: `Delegate` (1), park and
wake (0), `DelegateCheck` (2), final (3), with an optional verification call (4). Verification
is reported separately. This measures the specified path; it does not replay the failed-worker
and takeover history, which is not a path this ADR makes cheap.

**D6 adds** a `[Message]` codec and its round-trip test, a snapshot schema version, one
ledger event, two publish-site edits above `session.ail`'s pins, and the resume fixture. It
removes the fresh-session-on-budget behaviour the open issue records.

**What gets simpler.** The orchestrator stops polling. `DelegateCheck` is called when there is
something to collect. The guard stops refereeing waiting once it reads wait state.

**What does not.** Motoko's external `idle` stays ambiguous for interactive panes. The dagr
run file is still written only by the extension, on the settle call. A parked session holds a
pane and a process for the duration unless D6 stage 2's `--park-exits` is on; only `Timer`
bounds it. The host runs child waiters on the
model's behalf and must reap them on every exit path 020's reporter already handles.

## Not decided

- **herdr `--message` on an idle row.** Measure first.
- **Timeouts.** Whether a park without `Timer` is unbounded; what `TimedOut` tells the model.
- **Observation while parked.** The host could `pane read` on a timer and the extension refresh
  liveness on wake; nothing today writes `last_output_at`, so this is new, not repair.
- **`restart` under D4**, and whether initial input is in D4's scope.
- **Nested delegation.** A parked delegate waiting on its own delegate is two parks on two panes;
  `depth` in `register.ail` bounds recursion and nothing here changes it.
- **Whether `InjectUserMessage` and the wake message share a decision variant.**
- **D6: open waits across a resume.** Re-observed on resume is the rule; whether a delegate
  pane that survived the gap can still be waited on by state, or only by answer file, is not
  decided.
- **D6: what the resumed TUI shows.** The full history, or the last turn plus a marker; and
  whether a snapshot's `history` should be the compacted form the provider saw (it is, in this
  design) or the pre-compaction transcript as well.
- **D6: snapshot retention.** One per session, replaced in place, is the v1 rule; whether to
  keep the park-boundary snapshots for post-mortem is open.
- **Whether the truncated-arguments diagnosis is right.** It needs raw provider evidence; the
  live-run fix now preserves the raw length for the next occurrence.

## Implementation handoff

A PLAN-002 in this directory carries D5's steps 1–5 in order, each with its gate; D4 gets an
explicitly unscheduled section. D6 stage 1 is the second item after the herdr probe, because
it pays off on its own and its fixture is the template for D2's. Its first item is the herdr message probe. Its step-4 section is
written against P2's landed shape. O5 is its fallback item if step 3 slips past P2.

## Cross-references

- [`REVIEW-adr002-verdicts-codex.md`](REVIEW-adr002-verdicts-codex.md) — the v1 review; §7.2 has the executable precedence model, §7.3 the scanner mutant, §7.6 the raw re-measurement.
- [`ADR-001-sequencing-the-dst-architecture-caps.md`](ADR-001-sequencing-the-dst-architecture-caps.md) D2, D6, "Not decided".
- [`PLAN-001-implement-adr-001.md`](PLAN-001-implement-adr-001.md) §2.1.
- [`../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md`](../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md) D1–D3.
- [`../021_herdr_delegation/DESIGN-motoko-as-delegate.md`](../021_herdr_delegation/DESIGN-motoko-as-delegate.md) §3; [`../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`](../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md) §3.3, §4.2.
- [`../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md), as corrected by the review.
- [`../../issues/step-budget-exhaustion-starts-a-fresh-session.md`](../../issues/step-budget-exhaustion-starts-a-fresh-session.md) — the failure D6 stage 1 repairs; its sibling abort/error findings are the same class.
- Code at `8980ba6`: `phase_vocab.ail:449` (`StepDecision`), `:867` (message cap); `step_machine.ail:93`, `:114`, `:128`, `:279–377`; `session.ail:350`, `:684–697`, `:709`, `:2394`, `:2486`, `:3416`, `:2438–2487`, `:3017–3080`, `:3367–3430`, `:3387`, `:3415–3426`, `:3582–3586`; `ports.ail:789`, `:979–983`, `:1718–1745`, `:2556–2572`; `tool_phase.ail:435–445`; `stub_step.ail:205–213`; `dst_interaction.ail:59–66`; `dst_replay.ail:707–718`, `:793–824`; `ext_world.ail:515`, `:543`, `:515–553`; `rpc.ail:245`; `packages/motoko-ext-abi/types.ail:547`; `index.ts:938`; `dst_invariants.ail:788–806`, `:1742–1769`; `rpc.ail:218–237`; `herdr.ail:112`, `:164–167`, `:935–943`, `:1057–1132`; `types.ail:706–718`, `:749–758`; `dagr.ail:40–42`, `:386–392`; `derive.py:14–22`, `:151–154`; `herdr-agent-state.ts:43`, `:46`, `:278–286`, `:295–301`, `:330–351`; `ui.ts:790`, `:2726–2745`, `:4046–4049`; `index.ts:513–519`, `:572–575`, `:605–606`, `:820–827`, `:870–883`; `runtime-process.ts:592–600`, `:754–778`.
