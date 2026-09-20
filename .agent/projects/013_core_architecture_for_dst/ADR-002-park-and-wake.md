# ADR-002: Waiting is a step-machine state served by a port, and task completion is a runtime act

Date: 2026-09-06 (v1 through v3), 2026-09-07 (v4, v4.1)
Status: **Proposed (v4.1 — v4 folds the v2.1 review's outstanding corrections to D1–D5; v4.1
applies the v4 review's six line edits, unreviewed. PLAN-002 may be written against this
version.)** v4 was reviewed by Claude Fable
([`REVIEW-adr002-v4-verdicts-fable.md`](REVIEW-adr002-v4-verdicts-fable.md), HEAD `3ee3d03`):
*accept with corrections; PLAN-002 steps 1–2 writable now, steps 3–5 after four line decisions*;
D1 and D6 accepted clean; every v2.1 correction judged folded.
v1 was reviewed by Codex ([`REVIEW-adr002-verdicts-codex.md`](REVIEW-adr002-verdicts-codex.md),
reviewed HEAD `407d673`): *reject as written; retain the owner's park-and-wake direction*; v2
folded its 26 corrections. v2.1 added D6 (session snapshot) at the owner's request and was
reviewed by Codex ([`REVIEW-adr002-v2.1-verdicts-codex.md`](REVIEW-adr002-v2.1-verdicts-codex.md),
reviewed HEAD `97827bf`): *reject as written*; D1, D3, D4 accepted with corrections; D2, D5, D6
rejected. v3 lifted D6 out into [`ADR-003`](ADR-003-session-journal-and-resume.md) and re-cited
D2's request id from it; **v4 folds everything else that review required**: D2 rewritten as an
explicit pipeline, D3's descriptor as a sum with a complete lifecycle, D1's exit rule scoped and
its event order stated correctly, D4's open decisions taken, D5's unbound default defined and
its sequence repaired, and the provider-call metric corrected to four. The direction is
unchanged and is the owner's ("a parked state in the step machine that awaits on a port … is
my preferred direction"; "the motoko runtime has to emit an explicit task complete signal").
Provenance: measurements are the v1 review's re-derivation (§7.6 there) and
[`../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md)
as corrected. Code coordinates are at HEAD `3ee3d03`, whose `src/` and `packages/` are
byte-identical to the reviewed `97827bf` (only a fixture under `tools/` changed between them).

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
    envelope before `handled_tool_message` caps it (`tool_phase.ail:436–449`;
    `phase_vocab.ail:901–902`) is core work.
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

**v2 → v2.1.** D6 (session snapshot and resume) added at the owner's request. Not reviewed
until v2.1's review, which rejected it.

**v2.1 → v3.** D6 lifted out into ADR-003, which answers the five grounds it was rejected on
and has since gone through six reviews to a journal-only design (v6.1). D2's request id
re-cited from ADR-003 D5. Nothing else.

**v3 → v4.** The v2.1 review's corrections to D1–D5, in the order it made them:

1. *"D2's precedence table has a fixed point in the existing order."* It does not: a candidate
   goes through `dispatch_solver_candidate` first (`session.ail:3017`), and only `Accept` or
   `NoDecision` without a persist nudge reaches `c2_after_dp7`, where DP7 is actually checked
   (`:3020`, `:3080`, `:2352`). v2.1 required DP7 rejection to outrank `Park` and `Park` to
   outrank solver feedback and the persist nudge, which the existing order cannot give. v4
   rewrites D2 as an **explicit pipeline** — DP7 first, then wait classification, then
   completion-only solver and persist policy — and names the refactor.
2. *"`session_id` plus a per-run park ordinal."* Collides across resumes; v3 re-cited it, v4
   states it: `request_id = run_id + park ordinal`, with `run_id` from ADR-003 D5.
3. *"`HostError` is removed like any matching wake."* It is not a settlement. v4: a `HostError`
   wake reaches the model with the wait **still open**, and only a `Settled` or `Lost` wake, a
   settling `DelegateCheck`, or a `Timer` expiry removes a wait (D2, D3).
4. *"D3's descriptor is one record with delegate-only fields plus `Operator | Timer`."* It
   admits a `Timer` with an `answer_path`. v4: a **sum**, `DelegateWait | OperatorWait |
   TimerWait`, and a lifecycle table that covers `HostError`, retry and re-delegation,
   duplicate settlement and a failed second answer read.
5. *"`herdr.ail:112` is the only run-file writer."* Line 112 lists the two tool names;
   `Delegate` itself opens records through `dagr_open` (`herdr.ail:947–955`). v4:
   "`DelegateCheck` remains the only **settlement** path".
6. *"D1: error, abort and publication failure exit non-zero."* Scoped in v4 to `--answer-file`
   one-shot runs; an interactive turn's error deliberately re-enters the loop
   (`session.ail:3418–3426`; `ui.ts:2752–2755`). And the two orders stated correctly: the
   returned trace has `DoneEvent` then `RunSummary`; stdout has `run_summary` then `done`
   (`session.ail:1550–1554`, `:2473–2488`). The answer writer is in the host callback before it
   forwards `done`; it changes no core order. The re-read-before-`lost` change is extension
   work, not "all host-side".
7. *"D5's safe unbound default is not defined."* v4 defines it: fail closed without blocking,
   world unchanged but for the witness, queue exhaustion observable.
8. *"The metric is off by one."* After the `Delegate` tool result the finish reason is
   `tools_complete`, which calls the model (`step_machine.ail:134–135`); only that second,
   stop-class response can elect `Park`. The success path is **four** provider calls, not
   three, and a verified path is at least five. Both numbers stated.
9. *"D4 must decide restart/EOF, initial input and frame identity before ADR-003's durable
   park."* v4 decides all three.
10. D5 re-sequenced without D6: the `Ports` field before or with PLAN-001 P2; activation after
    P2; **D4's framing and identity subset before ADR-003 D7**; O5 the fallback.

**v4 → v4.1.** Six line edits from the v4 review, four of them the decisions it asked for:

1. *"The unbound default advances the world."* `advance`, `ordinal` and `pending` are PLAN-001
   P2 Part 1's (`PLAN-001:370–375`; no `ordinal` at HEAD, `ports.ail:183–196`), and D5 step 3
   may land before P2. v4.1: the pre-P2 default returns the world **unchanged** and gains its
   `advance` when P2 lands; the scanner recognises the field either way (D5).
2. *"DP7 first runs the verifier on every complete candidate."* `dp7_rejection_errors` calls
   `run_dp7_verifier`, which shells out to the configured command when verification is enabled
   (`session.ail:1930–1934`, `:1976–1978`); today it runs only on candidates that reach
   `c2_after_dp7`. v4.1 **gates stage 2 on a non-blank candidate** — a blank one goes to stage 3
   or 4 as today, where the empty-stop guard owns it — and prices the rest: live sessions with
   a verifier run it on every non-blank complete candidate. Fixtures do not move: `empty_rt()`
   disables verification (`stub_step.ail:786`) and no fixture that reaches this arm enables it;
   v4's "their fixtures move" was wrong (D2, Consequences).
3. *"`Park` needs a request id `StepState` cannot supply."* `decide` is a pure projection of
   `StepState` (`step_machine.ail:114–138`; `phase_vocab.ail:308–318`), which holds neither
   `run_id` nor a park ordinal. v4.1: **`Park` carries only the waits**; the driver builds the
   `ParkRequest` from its `RunIdentity` and a per-run park counter in `C2LoopState`. `decide`'s
   fifteen tests (`step_machine.ail:246–396`, not `:279–377`) stay untouched (D2).
4. *"`settled: true` does not exist."* `DelegateCheck`'s metadata is `meta_timed` — delegate,
   pane, channel, started, elapsed, waited (`herdr.ail:172–177`). v4.1 names `settled` as a
   **new** field there, beside D3's `wait` on `Delegate`'s, and adds the row the table missed:
   a check that returns an error without settling (`:1100–1102`) keeps the wait (D3).
5. *"D4's framing subset."* A between-turn `wake_read` is a helped leaf and needs a world; the
   conversation loop holds none (`session.ail:3380–3386`, `:3419`, `:3426`, `:3611`; ADR-001
   records it as out of reach, `ADR-001:448–449`). v4.1 says so: the subset **includes
   threading `traced.world` into the loop's parameters**, the largest piece of the debt (D4).
6. Coordinates and one fact: EOF returns at `session.ail:3368`; the `decide` tests span
   `:246–396`; `dp7_fail_open` is a stop-class reason string with **no producer** in
   `session.ail` at HEAD — only a test sets it. `classify_candidate` is effectful
   (`{Process, IO, Clock, Trace}`), since solver dispatch is (`ext/runtime.ail:676–677`); the
   pure part is `decide`.

Not retracted: the direction; the answer-first branch of `do_check_motoko` really does settle
`done` when the agent is already gone (`herdr.ail:1066–1087`, `agent get` confined to the
no-answer `else` at `:1089–1090`); the four-circumstances-one-report ambiguity of motoko's
`idle` (`herdr-agent-state.ts:278–286`; `ui.ts:2726–2745`); the ≥100-call excess of the
measured turn.

---

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | A `done` run state; host-owned answer publication in the terminal path, before exit actions and authority release; one-shot reuses `--headless`; defined outcomes for empty, error, cancel and write failure, **scoped to answer-file one-shots**; the extension re-reads the answer before publishing `lost` | 2–3 days, host + extension |
| D2 | Waits carried in `StepState`; an **explicit classification pipeline** in the driver — pending tools and approvals · DP7 on a non-blank candidate · wait classification · completion-only solver and persist policy · finalize — which moves DP7 ahead of solver dispatch; `Park` in `decide` carrying only the waits, the driver building the request from `RunIdentity` and a park counter; `wake_read` on `Ports` with a named host protocol and the full replay set approval has; `request_id = run_id + park ordinal`; `HostError` leaves the wait open | 9–13 days after the surface exists |
| D3 | `WaitDescriptor` a **sum**: `DelegateWait \| OperatorWait \| TimerWait`; producer in the `Delegate` envelope; core consumer lifts it before capping; a complete lifecycle table; settlement stays with `DelegateCheck`, called once after the wake | 3–4 days, split host / extension / core |
| D4 | The multi-turn wait is the same park; `restart` and EOF **cancel** the outstanding request and take today's exits; initial input is **out** of scope; the between-turn frame opens after `RunSummary` at the previous frame's `final`, the rule ADR-003 D5 already uses. Closes ADR-001's threading debt only when its plan carries every listed successor; its framing subset is a **prerequisite of ADR-003 D7** | unscheduled, unpriced |
| D5 | D1 and D3's producer now; the `Ports` field with a **fail-closed unbound default** (world unchanged before P2, one `advance` once P2 lands), wake types, cursor, codec and scanner recognition **before or with** PLAN-001 P2; activation after P2 is green, under ADR-001 D6; D4's subset, including a world in the loop, before ADR-003 D7 | — |
| D6 | **Durable park is ADR-003 D7.** Session journal and resume are decided in [`ADR-003`](ADR-003-session-journal-and-resume.md); this ADR's `ParkEntered` becomes a `park` entry there and a resolved wake a `wake` entry | priced in ADR-003 |

The number this ADR is judged on: the specified successful path — `Delegate`, the stop-class
response that elects `Park`, the wake, `DelegateCheck`, final — costs **exactly 4 provider
calls**, verification excluded; a verified path is **at least 5** and is reported separately.
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

**How a candidate is classified today**, which D2 changes. After a model call with no tool
calls, the driver hands the candidate to `dispatch_solver_candidate` (`session.ail:3017`);
`Accept` goes to `c2_after_dp7` (`:3020`), `ContinueWithFeedback` injects the feedback
(`:3021–3047`), `NoDecision` either injects a persist nudge (`:3048–3079`) or goes to
`c2_after_dp7` (`:3080`); and DP7's verifier is consulted only inside `c2_after_dp7`
(`:2352–2403`), setting `dp7_rejected` or `dp7_approved`. `decide` then sees those finish
reasons (`step_machine.ail:114–138`): pending tools first, then `dp7_rejected`,
`solver_feedback` and `persist_nudge` as injections, then the stop-class reasons as `Finalize`.
So solver policy runs on a candidate DP7 has not yet judged, and DP7 runs only on candidates
solver policy let through.

## Options considered

**O1 — Raise `HERDR_CHECK_WAIT_MS`.** One check blocks for minutes inside `run_herdr`. Rejected:
the operator cannot type, a second delegate cannot be checked, and the wait is a wall-clock
sleep inside a tool call — replayable as an extension effect, but as one opaque interaction with
no wire trace of what was waited for.

**O2 — The TUI owns the waiter and posts a `user_message`.** Works for claude/codex kinds today.
Rejected as the end state: invisible to the ledger and DST, indistinguishable from an operator,
no in-turn case. Retained as the `OperatorWait` source under D4.

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

The reporter funnel stays 020 D2's single mutator. Host and extension work, split as stated.

1. **A `done` run state** (host). Both unions gain it: `RunState` (`ui.ts:790`) and
   `MotokoRunState` (`herdr-agent-state.ts:43`). Entered on the runtime's `done` event, left on
   the next input. Reported as herdr `idle` with `--message "done"`. Whether herdr shows the
   message on an idle row is **unmeasured**; the plan's first probe. External `idle` remains
   ambiguous until the answer/exit protocol below is used; `done` exists so Motoko's own
   display stops conflating. (ADR-003 D2 adds a sibling `suspended` state to the same unions.)
2. **Host-owned answer publication** (host). New flag `--answer-file <path>`. In the common
   terminal path — the non-TTY callback awaits logger closure before forwarding terminal
   events (`index.ts:870–883`) — and *before* exit actions (registered at `:820–827`) and
   reporter release (`herdr-agent-state.ts:295–301`, `:330–351`), the host publishes the answer
   atomically (write temp, rename). Rules: an existing non-empty file at the path wins; a
   non-empty `done` output is written otherwise; an **empty `done`**, a runtime `error`, an
   `abort`, or a **publication failure** writes nothing. **Scope of the non-zero exit:** in an
   `--answer-file` one-shot (`--headless` or `--oneshot`) those four cases exit non-zero with
   the reason on stderr. In an interactive session they do not: a turn error is rendered and
   the runtime re-enters the conversation loop (`session.ail:3418–3426`; `ui.ts:2752–2755`), and
   that behaviour is unchanged. Evidence stays `reported`; a non-empty file is not verified
   success and the dagr design already allows the file to report failure (§4.2 there).
   **Order, stated precisely:** the returned trace appends `DoneEvent` before `RunSummary`
   (`session.ail:2473–2488`), and stdout emits `run_summary` before `done` (`:1550–1554`, then
   `:2487`). The answer writer sits in the host callback before it forwards `done`; it does not
   change either order.
3. **One-shot reuses `--headless`** (host). The one-task path exists; `--oneshot` is added only
   if the interactive display is wanted while ending after one task, otherwise it aliases.
   Motoko delegates run one-shot with `--answer-file`.
4. **Re-read before `lost`** (extension). When the negative early read is followed by a failing
   `agent get`, the extension **re-reads the answer before publishing `lost`**
   (`herdr.ail:1089–1102` today settles `lost` without a second read; the post-wait branch at
   `:1113–1132` already reads first). Pane close on the answer branch is unchanged (`:1068`);
   exit and close are different acts and both happen.

Tests: publication before exit actions and before release, with an existing report and with an
unwritable destination; empty-done and error paths produce no file and, in one-shot only, a
non-zero exit; an interactive turn error still re-enters the loop; both the plain/JSONL and
interactive one-shot paths; the extension's second read.

What D1 does not claim: that stalled workers now produce answers. The INV write worker's
`empty_stop_finalize` followed by an empty `done` (`session_2026-09-05T19-43-24-730Z.jsonl:217–219`)
produces no file under these rules, correctly.

### D2 — Waits in the step state, an explicit pipeline in the driver, `Park` in `decide`, `wake_read` on `Ports`

**Vocabulary.** A *wait* is an open handle on something outside the session that will change.
A *park* is the loop's decision to block on its open waits instead of calling the model. A
*wake* is the port's answer.

**State.** `C2LoopState` gains `open_waits: [WaitDescriptor]` (type in D3) and the projection
to `StepState` (`session.ail:684–697`) carries it; `decide` cannot see what `StepState` does not
hold.

**The pipeline, explicit.** The driver's candidate classification — the `CallModel` arm's
no-tool-calls branch, `session.ail:3012–3082` — is refactored into one function,
`classify_candidate`, applied in this order and no other. It is **effectful**
(`{Process, IO, Clock, Trace}`): solver dispatch is (`ext/runtime.ail:676–677`) and the
verifier shells out (`session.ail:1930–1934`); the pure part of D2 is `decide`.

| stage | input | outcome |
|---|---|---|
| 1 pending | the candidate carries tool calls, or an approval is pending | unchanged: `RunTools` / `AwaitApproval` |
| 2 DP7 | the candidate is complete **and non-blank** | `dp7_rejection_errors` (`:2352`, `:1976–1978`) → `dp7_rejected` → `InjectUserMessage`, **before** any solver policy sees it |
| 3 waits | `open_waits` non-empty | `await_wake` → `Park`, whatever the candidate says, including a blank one |
| 4 completion policy | no open waits | `dispatch_solver_candidate` → `solver_feedback` (this is where a blank candidate meets the empty-stop guard, as today), then the persist nudge → `persist_nudge`, each `InjectUserMessage` |
| 5 finalize | no open waits, policy silent | `dp7_approved` / `dp7_fail_open` → `Finalize` |

This **moves DP7 ahead of solver dispatch**. Today solver policy judges a candidate DP7 has not
seen; under D2 a DP7-rejected candidate never reaches solver policy, and solver policy runs
only on candidates DP7 approved or failed open. That is a behaviour change for the solver
extensions (`decision_framework`, `progress_contract_guard`, `empty_stop_guard` in their solver
roles): they see fewer candidates, never a rejected one. Stated as intended: a rejection is a
verdict on the candidate, and feedback on a rejected candidate is feedback the model will not
act on because it is about to be told to redo the work. **The cost, priced:** with verification
enabled, `run_dp7_verifier` runs its command (`session.ail:1930–1934`) on every non-blank
complete candidate, where today it runs only on the ones solver policy let through to
`c2_after_dp7` (`:3020`, `:3080`); the non-blank gate keeps it off the blanks the empty-stop
guard bounces. Fixtures do not move: `empty_rt()` disables verification (`stub_step.ail:786`),
the two guards decide on `(ctx, candidate)` alone and their own tests are pure, and no fixture
that reaches this arm enables a verifier; what changes is live behaviour under one. The
narrowed guarantee: *with open waits, no stop-class candidate finalizes*. With no waits every
existing `decide` test — fifteen, `step_machine.ail:246–396` — is preserved unchanged, which the
v1 review's control model confirms for all eight reason strings, and `decide` itself changes by
one arm: `await_wake` → `Park`. (`dp7_fail_open` is in that stop class and has **no producer**
in `session.ail` at HEAD; only a test sets it. It stays in the class for that test.) New
cross-product cases: each stop-class reason × open waits →
`Park`; empty × open waits → `Park`; DP7 rejection × open waits → `InjectUserMessage`; pending
tools × open waits → `RunTools`; two open waits; a solver-feedback candidate that DP7 rejects,
which today would have received feedback and under D2 receives the rejection.

**The port.** `Ports` gains
`wake_read: (WorldState, ParkRequest) -> WakeInput ! {IO}`,
`ParkRequest = { request_id: string, step: int, waits: [WaitDescriptor] }`,
`WakeInput = { request_id: string, wait_id: string, outcome: WakeOutcome, next_state: WorldState }`,
`WakeOutcome = Settled(string) | Lost(string) | OperatorInput(string) | TimedOut | HostError(string) | Aborted`.
**`request_id = <run_id>.p<park ordinal>`**, where `run_id` is the identity ADR-003 D5 hands
every traced run (`<session_id>.r<resume_count>.<run_ordinal>`) and the park ordinal counts
parks within the run. It is unique across turns and across resumes, because `run_id` is.
**Who builds it:** `decide` is a pure projection of `StepState` (`step_machine.ail:114–138`;
`phase_vocab.ail:308–318`), which holds neither, so `Park` carries **only the waits**, and the
driver builds the `ParkRequest` from its `RunIdentity` argument and a `park_ordinal` counter in
`C2LoopState`, incremented per park. A reply whose `request_id` or `wait_id` does not match the
outstanding request is dropped and logged, never applied to a different pending wait.

**The host protocol (new; nothing existing serves it).** The runtime emits a `wake_request`
event on stdout carrying the `ParkRequest`; the TUI replies with a `wake_reply` command on
stdin, demultiplexed alongside `abort`, `exit`, `model_change`, `restart`, `user_message`
(`runtime-process.ts:754–778`; `session.ail:3372–3398`). While a request is outstanding:

- `DelegateWait` answer observations are **file observations**: initial read, subscribe,
  re-read (an answer present before subscription cannot be missed); first non-empty content
  counts only because D1 publishes atomically.
- `DelegateWait` state observations are a **registered-start observation**: wait for the agent
  row to exist (the extension returns before it does), then `agent wait --until
  idle,done,blocked` for claude/codex kinds only; a motoko one-shot's state change is its exit,
  observed as the row disappearing *after* it was seen, then the answer re-read. A default-wait
  success is never equated with an answer.
- A herdr transport failure is `HostError`, never `Lost` (the extension separates these at
  `herdr.ail:1091–1100`; the host must too).
- Operator input during a park is `OperatorInput`; this needs a **parked input route** in the
  TUI, which today rejects input while a task runs (`ui.ts:4046–4049`). `abort` is `Aborted`
  and takes the existing abort path. `restart`/`exit` cancel the request (D4).
- Losing waiters and subscriptions are cancelled on wake, abort and runtime exit; late replies
  are dropped by `request_id`; two handles ready at once are reported in `waits` order, the
  rest remain open.
- `ParkEntered` is emitted **before** blocking, so a wait that never returns is visible.

**After the wake.** A pure function turns the `WakeInput` into a message tagged as loop-authored
(distinct from an operator's), the wait set is updated by D3's lifecycle table, and the next
decision goes through `call_model_or_fail` (`step_machine.ail:93–111`) — step and cost caps,
checkpoint and context-pressure checks apply as they do to every injected message. Per outcome:

| outcome | the message says | the wait |
|---|---|---|
| `Settled` | the answer is available; call `DelegateCheck` once | removed |
| `Lost` | the delegate is gone with no answer | removed |
| `OperatorInput` | the operator's text | all waits stay open |
| `TimedOut` | the `TimerWait` fired | the timer removed; delegate waits stay open |
| `HostError` | the host could not observe (transport), with the reason | **stays open**; the model may re-park or `DelegateCheck` |
| `Aborted` | — | the abort path; waits cleared with the run |

A `Settled` wake tells the model the answer is available and to call `DelegateCheck`, which
now finds it on the first, early read and performs the extension's idempotent settle (D3). The
model's first step after waking is the settle.

**DST and replay — the full set, not a helper.** Following approval item for item:

| approval has | wake gets |
|---|---|
| `ports.scripted_approval` bound in `fake_ports`, cursor `WorldState.approvals` (`ports.ail:979–983`, `:2558`; `scripted_ports.ail:74–76`) | `ports.scripted_wake`, cursor `WorldState.wakes: [WakeInput]`, successor built by the adapter (a fixture supplies observations, never whole worlds) |
| recording adapter (`ports.ail:1718–1745`) | `recording_wake` |
| interaction identity and outcome (`dst_interaction.ail:59–66`; `dst_replay.ail:707–718`, `:793–824`) | a `WakeInteraction` identity and outcome encoding; `WakeRead` the **ordinal** class is not this |
| world-token codec (`ext_world.ail:515–553`) | the `wakes` cursor round-trips; an extension round trip that rebuilds only the enumerated fields would otherwise drop it before the first park |
| parity witnesses | `ParkEntered` and `WakeReceived` appended **and** emitted, with payload assertions in `parity_findings` (`dst_invariants.ail:946`, which compares presence today) |

Fixtures: success (`Settled`), `Lost`, `OperatorInput` leaving the delegate pending, two
delegates with one wake, `HostError` leaving the wait open and a second park succeeding,
`TimedOut` removing only the timer, and controls: wrong handle, duplicate/late wake, missing wake
— queue exhaustion, which the scripted adapter turns into the unbound default's `HostError`,
and the fixture asserts **that outcome directly**, because a queue short by one otherwise fails
only later, when the model's next candidate does not match the script — stale world, empty stop
with open waits, the DP7-rejected solver candidate. Two runs from the same script are a determinism
check; the saved-program replay is the recording adapter's fixture.

**World ordinal.** `wake_read` is a helped leaf under ADR-001 D2: one `advance` when the leaf
returns, witnessed before the successor enters any record. Its class is `WakeRead`, the sixth
(`derive.py:142` freezes five). `approval_read` maps to `ToolExec` because it classes the
dispatch it guards; a wake guards nothing.

### D3 — One descriptor as a sum, produced by the extension, lifted by the core, settled by `DelegateCheck`

```
WaitDescriptor
  = DelegateWait({ id, delegate_kind, locator: { pane }, answer_path, run_key })
  | OperatorWait({ id })
  | TimerWait({ id, deadline_ms })
```

v2's record admitted a timer with an answer path; the sum does not.

- **Producer.** `Delegate`'s `metadata` (`herdr.ail:164–167`) gains `wait`, a `DelegateWait`.
  Additive to the Json envelope (`tool_contract.ail:13–20`); no ABI sum change. `OperatorWait`
  is produced by the conversation loop under D4; `TimerWait` by the model's `Delegate` call
  when it asks for a bound, or by policy.
- **Consumer, core.** `execute_allowed_tool_call`'s `Handled` arm validates and extracts `wait`
  from the *successful extension envelope* **before** `handled_tool_message` caps the encoded
  message (`tool_phase.ail:436–449`; the cap at `phase_vocab.ail:901–902`), and the typed result
  rides the tool fold into `open_waits`. Re-decoding a possibly truncated model message is not a
  registration protocol.
- **Lifecycle**, the complete table:

  | event | effect on `open_waits` |
  |---|---|
  | `Delegate` succeeds | register the `DelegateWait` |
  | `Delegate` fails to launch | nothing registered |
  | re-delegation (a second `Delegate` for the same task) | a new wait with a new id whose `run_key` names the retry (the extension already links the records by `retry_of`, `herdr.ail:947–949`); the old one stays until settled or lost — the model is told both are open |
  | `Settled` / `Lost` wake | remove the matching wait |
  | `HostError` wake | keep; the wait is not settled by a transport fault |
  | `OperatorInput` wake | keep all |
  | `TimedOut` | remove the `TimerWait` only |
  | `DelegateCheck` that settles — `settled: true` in its metadata, a **new** field beside `meta_timed`'s delegate, pane, channel, started, elapsed and waited (`herdr.ail:172–177`), the check's twin of `Delegate`'s new `wait` | remove the matching wait — a manual check must not leave a stale wait |
  | `DelegateCheck` that returns an error without settling (`agent get` fails while the agent is not known to be gone, `herdr.ail:1100–1102`) | keep, as for `HostError` |
  | `DelegateCheck` that settles an already-removed wait | idempotent; nothing to remove, the extension's settle is already idempotent (`herdr.ail:1066–1087`) |
  | `DelegateCheck` whose second answer read fails after the agent is gone | the extension publishes `lost` (D1's re-read rule) and the check settles; remove |
  | run ends (`Finalize`, `Fail`, suspend) | cleared with the run; ADR-003's `park` entry carries them across a durable park |

- **Settlement.** `DelegateCheck` remains the only **settlement** path (`Delegate` opens records
  through `dagr_open`, `herdr.ail:947–955`; only `DelegateCheck` settles them). The wake message
  directs the model to call it once. Run-file truth is not moved into the core.
- **Guard.** When D2 is active, the progress guard's input is the validated wait state through
  an additive `ExtCtx` field (`open_waits`), and the prose recogniser landed as the live-run fix
  (`progress_contract_guard.ail:179–188`) becomes an explicitly limited fallback — it cannot see
  A when B was launched and collected after A.

### D4 — The multi-turn wait is the same park

The blocking read (`session.ail:3367`) becomes a park with `waits = [OperatorWait]`;
`user_message` becomes an `OperatorInput` wake. Decided, since ADR-003 D7 depends on them:

- **`restart` and EOF.** Both **cancel** the outstanding request: `restart` emits
  `SessionSuspend` and returns (`:3391–3399`), EOF returns (`:3368`), exactly as today; the
  host's losing waiters are cancelled with the request (D2). Under ADR-003 the host writes the
  `exit` entry; a park entry with no wake child is then re-observed on resume.
- **Initial input is out of scope.** `rpc.await_first_task` (`rpc.ail:218–237`) runs before any
  session exists — no world, no run, no frame — and stays as it is. D4 begins at the first
  between-turn read.
- **Frame identity.** The between-turn frame opens **after** `RunSummary` (ADR-001 D2 part 3
  keeps frames separate from `done`/`RunSummary`; `RecordAfterTerminal`,
  `dst_invariants.ail:788–806`) at the previous frame's `final`, the rule ADR-003 D5 already
  uses for a resumed frame. `OperatorWait`'s `ParkEntered`/`WakeReceived` and the cross-turn
  ordinal live in it.

**What closing ADR-001's threading debt actually requires**, all of it: the model-change
successor (`session.ail:3387–3389`), the stale provider across turns (`:3415–3426`), the initial
identity read (`:3582–3586`), the publish successors, and the between-turn frame above. Gate: a
two-turn replay with an intervening model change and a restart-or-EOF control. **Unscheduled,
but its framing and identity subset is a prerequisite of ADR-003 D7**, and that subset is
three things, not two: the between-turn frame; `run_id`, which ADR-003 D5 supplies; and **a
world in the loop** — a between-turn `wake_read` is a helped leaf and must be called with a
world, and the conversation loop holds none, recursing with the pre-turn `provider` and
dropping every successor by design (`:3380–3386`, `:3419`, `:3426`, `:3611`; ADR-001 records
the loop as out of the frame gate's reach, `ADR-001:448–449`). Threading `traced.world` into
the loop's parameters is the largest single piece of the debt above and is in the subset.

### D6 — Durable park: ADR-003 D7

Superseded. v2.1's D6 (session snapshot and `--resume`) was rejected on five grounds by the
v2.1 review and is decided in [`ADR-003`](ADR-003-session-journal-and-resume.md), now a
journal-only design at v6.1. What this ADR keeps from it is one dependency, in both directions:

- **`Park` is an entry.** `ParkEntered`, appended and emitted, becomes ADR-003's `park` entry
  carrying `open_waits` and the outstanding `ParkRequest`; `WakeReceived`, appended and
  emitted, becomes a `wake` entry, a child of the park entry. Path 1 of ADR-003 D7 — runtime
  alive, `wake_read` returns — is this ADR's default and costs nothing beyond those events.
- **`--park-exits` is ADR-003's.** A park that exits the runtime, a host that owns the
  outstanding request through the suspended-child state, the persisted wake consumed exactly
  once through `wake_read` from a seeded `wakes` cursor (no wake file, no generation counter:
  a `run_started` follows a consumed wake and the fold offers it no more), and the
  `Lost`/`Aborted` exits are ADR-003 D7, unscheduled there until this ADR's D2 activates and
  D4's frame exists.
- **Identity is ADR-003's.** `request_id` is built on ADR-003 D5's `run_id`.

### D5 — Sequencing

1. **Now, host + extension:** D1.
2. **Now, core, priced as core:** D3's consumer and registration; `open_waits` in loop and step
   state; the guard's `ExtCtx` field; the `classify_candidate` refactor of `:3017–3080` **with
   `open_waits` always empty**, so that DP7-before-solver lands and is measured on its own
   before any park exists.
3. **Before or with PLAN-001 P2:** the `Ports` field with its **unbound default**, the wake
   types, the `wakes` cursor and its `ext_world` codec, the three literal entries
   (`ports.ail:2556–2572`; `long_qwen_compaction_dst.ail:383–402`, `:513–532`), and scanner
   recognition — `HELPED`, `REQUEST_CLASS`, `CALL_RE` in `derive.py`, with the review's
   missing-wake mutant as a gate that must go red. No session call site yet.

   **The unbound default, defined.** `wake_read_unbound(world, req)` returns
   `{ request_id: req.request_id, wait_id: "", outcome: HostError("wake_read unbound"),
   next_state: world' }` — it never blocks and is what a scripted fixture observes when its
   `wakes` queue is exhausted (the scripted adapter falls through to it), so queue exhaustion
   is a `HostError` with a distinct message rather than a hang or a fabricated wake. **`world'`
   depends on when step 3 lands:** `advance` is PLAN-001 P2 Part 1's (`PLAN-001:370–375`;
   no `ordinal` on `WorldState` at HEAD, `ports.ail:183–196`), so before P2 the default returns
   the world **unchanged**, and with or after P2 it returns `advance(world, WakeRead)`, the one
   witness every helped leaf owes. The scanner recognises the field in both cases; only the
   witness gate (P2's) sees the difference. It is the binding in all three literals until step 4
   binds the real ones.
4. **After P2 is green, under ADR-001 D6:** activation — stage 3 of the pipeline, `Park`, the
   host protocol, the recording and scripted adapters, the interaction identity, the two
   events, the fixtures, and the live measurement.
5. **D4's framing and identity subset** — the between-turn frame, `run_id` (from ADR-003 D5)
   and a world threaded into the conversation loop — after 4's gate has held for one live run;
   it is ADR-003 D7's prerequisite. The rest of D4 (the model-change successor, the stale
   provider, the initial identity read, the publish successors) stays unscheduled.
6. **ADR-003 D7** after 5; `--park-exits` stays off until one live parked session has resumed.

The freeze note in `derive.py` cites this ADR as the reason a sixth class exists.

## Consequences

**Gates that move.** D2 edits `phase_vocab` and `session.ail` above its pins (anchor cascade,
`make event_vocabulary`, goldens, as for ADR-001). `Ports` gains a field: three literals and
the unbound default. `driver_leaf_inventory` gains recognition and a mutant gate. New DST
fixtures as listed. Host tests for `done`, publication ordering, and the parked input route.
The `classify_candidate` refactor changes what solver extensions see (D2): live behaviour under
a verifier changes; fixtures under `empty_rt()` (`stub_step.ail:786`) do not.

**The metric, stated precisely.** Live and in the success fixture:

| provider call | response |
|---|---|
| 1 | emits `Delegate`; the core registers the wait |
| 2 | after the `Delegate` tool result (`tools_complete`, `step_machine.ail:134–135`), a stop-class response — the only thing that can elect `Park` |
| — | park and wake, no provider call |
| 3 | emits `DelegateCheck` |
| 4 | after the check result, the final answer |

**Exactly 4** on the success path. An optional verification tool after collecting the delegate
makes it **at least 5** (call 4 emits the verification, call 5 consumes its result and
finalizes). The gate reports both numbers; the success path is `== 4`. This measures the
specified path; it does not replay the failed-worker and takeover history, which is not a path
this ADR makes cheap.

**What gets simpler.** The orchestrator stops polling. `DelegateCheck` is called when there is
something to collect. The guard stops refereeing waiting once it reads wait state. DP7 judges
every complete candidate, not only the ones solver policy let through.

**What does not.** Motoko's external `idle` stays ambiguous for interactive panes. The dagr
run file is still written only by the extension, on the settle call. A parked session holds a
pane and a process for the duration unless ADR-003 D7's `--park-exits` is on; only `TimerWait`
bounds it. The host runs child waiters on the model's behalf and must reap them on every exit
path 020's reporter already handles.

## Not decided

- **herdr `--message` on an idle row.** Measure first.
- **Timeouts.** Whether a park without a `TimerWait` is unbounded; whether policy adds one.
- **Observation while parked.** The host could `pane read` on a timer and the extension refresh
  liveness on wake; nothing today writes `last_output_at`, so this is new, not repair.
- **Nested delegation.** A parked delegate waiting on its own delegate is two parks on two panes;
  `depth` in `register.ail` bounds recursion and nothing here changes it.
- **Whether `InjectUserMessage` and the wake message share a decision variant.**
- **Waiting on a delegate by state after a gap** (shared with ADR-003): re-observation on resume
  is the rule; whether a surviving pane can still be waited on by state, or only by answer
  file, is open.
- **Whether the truncated-arguments diagnosis is right.** It needs raw provider evidence; the
  live-run fix now preserves the raw length for the next occurrence.

## Implementation handoff

A PLAN-002 in this directory carries D5's steps 1–5 in order, each with its gate; D4's debt
gets an explicitly unscheduled section. Its first item is the herdr message probe; its second is
step 2's `classify_candidate` refactor, whose gate is the existing `decide` tests unchanged plus
the DP7-before-solver cases. Its step-4 section is written against P2's landed shape. O5 is its
fallback item if step 3 slips past P2. PLAN-003 P1 must land first: PLAN-002 consumes
`RunIdentity` from it.

## Cross-references

- [`REVIEW-adr002-v4-verdicts-fable.md`](REVIEW-adr002-v4-verdicts-fable.md) — the v4 review;
  §3 the pipeline in depth (the verifier's cost, the solver extensions, the `decide` payload),
  §4 the lifecycle table against `do_check_motoko`, §5 the unbound default, §7 the world the
  between-turn frame needs; "Required changes" the six v4.1 folds.
- [`REVIEW-adr002-v2.1-verdicts-codex.md`](REVIEW-adr002-v2.1-verdicts-codex.md) — the v2.1
  review; §2 D2 the precedence and identity defects, §4 the metric, "Required ADR changes" the
  list v4 folds.
- [`REVIEW-adr002-verdicts-codex.md`](REVIEW-adr002-verdicts-codex.md) — the v1 review; §7.2 has
  the executable precedence model, §7.3 the scanner mutant, §7.6 the raw re-measurement.
- [`ADR-003-session-journal-and-resume.md`](ADR-003-session-journal-and-resume.md) v6.1 —
  supersedes v2.1's D6; D5 there (`run_id`) is what D2's `request_id` is built on; D7 there is
  the durable park.
- [`ADR-001-sequencing-the-dst-architecture-caps.md`](ADR-001-sequencing-the-dst-architecture-caps.md) D2, D6, "Not decided".
- [`PLAN-001-implement-adr-001.md`](PLAN-001-implement-adr-001.md) §2.1;
  [`PLAN-003-implement-adr-003.md`](PLAN-003-implement-adr-003.md) P1 (`RunIdentity`).
- [`../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md`](../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md) D1–D3.
- [`../021_herdr_delegation/DESIGN-motoko-as-delegate.md`](../021_herdr_delegation/DESIGN-motoko-as-delegate.md) §3; [`../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`](../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md) §3.3, §4.2.
- [`../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`](../021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md), as corrected by the v1 review.
- Code at `3ee3d03` (`src/`, `packages/` identical to `97827bf`): `phase_vocab.ail:308–318`
  (`StepState`), `:449` (`StepDecision`), `:901–902` (message cap); `step_machine.ail:93–111`,
  `:114–138`, `:134–135`, `:246–396`; `session.ail:684–697`, `:1078–1106`, `:1550–1554`,
  `:1930–1934`, `:1976–1978`, `:2352–2403`, `:2394`, `:2468–2488`, `:3012–3082`, `:3017`,
  `:3020`, `:3080`, `:3367–3430`, `:3368`, `:3380–3386`, `:3387–3389`, `:3391–3399`,
  `:3415–3426`, `:3418–3426`, `:3419`, `:3426`, `:3582–3586`, `:3611`; `ext/runtime.ail:676–677`;
  `ports.ail:183–196`, `:789`, `:979–983`, `:1718–1745`, `:2556–2572`; `tool_phase.ail:436–449`;
  `stub_step.ail:205–213`, `:786`; `PLAN-001:370–375`;
  `dst_interaction.ail:59–66`; `dst_replay.ail:707–718`, `:793–824`, `:805–825`;
  `ext_world.ail:515–553`; `dst_invariants.ail:788–806`, `:946`; `rpc.ail:218–237`;
  `tool_contract.ail:13–20`; `derive.py:14–22`, `:142`, `:151–154`; `herdr.ail:112`,
  `:164–167`, `:172–177`, `:935–943`, `:947–955`, `:1057–1132`, `:1100–1102`, `:1162–1175`;
  `types.ail:706–718`, `:749–758`;
  `dagr.ail:40–42`, `:386–392`; `progress_contract_guard.ail:141–191`;
  `empty_stop_guard.ail:20–37`; `herdr-agent-state.ts:43`, `:46`, `:278–286`, `:295–301`,
  `:330–351`; `ui.ts:790`, `:2726–2745`, `:2752–2755`, `:4046–4049`; `index.ts:513–519`,
  `:572–575`, `:605–606`, `:820–827`, `:870–883`; `runtime-process.ts:592–600`, `:754–778`.
