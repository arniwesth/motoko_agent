# ADR-002 review verdicts and independent re-measurement

Date: 2026-09-06. Overall verdict: **reject as written; retain the owner's park-and-wake direction**.
Reviewed HEAD: `407d673acb94ef9af9611e3daa7ae6d322dc48e1`, branch `arniwesth/013-dst-architecture-adr`.
Reviewer: **Codex, independent**. No authorship of the ADR; no delegated review.

Method: read `REVIEW-adr001-v2-verdicts-codex.md` first; read every input named in the brief;
inspect committed source with `git show <HEAD>:<path>`, with numbered lines; independently parse
the named JSONL logs; inspect the two CLI help surfaces; execute the inventory's Python functions
against Git blobs, including an in-memory missing-wake mutant; and model the proposed decision
precedence. No verdict rests on the ADR's description of its own implementation.

The initial HEAD was `75ab53251c397709d6cd9d412729f5c51a9a71fb`. Two commits landed during
review: `650f0e0` changed session hybrid extraction, and `407d673` changed native argument-error
handling. I inspected both committed diffs, re-read the affected session/tool/vocabulary code,
and re-ran the inventory at **407d673**. All current code coordinates below use that revision.
The earlier decoder is explicitly cited at its earlier commit where needed. No assertion concerns
another worker's uncommitted changes. The supplied 013 review/design documents and live-run
measurement are reviewed as supplied documents, separately from the committed implementation.

`wc -l AGENTS.md` returned `0`. I wrote only this review file. No commit, full `make dst` sweep,
AILANG build/test run, live delegation, pane mutation, lifecycle report, message-visibility probe,
or provider call was performed. The executable probes below ran in memory and wrote no temporary
files. They are not tests of an implemented Park or proof that the existing DST gates pass.

Reference shorthand: **ADR** means `ADR-002-park-and-wake.md`; **ADR1**, **PLAN**, and **STANDARD**
mean the sibling ADR-001, PLAN-001, and `REVIEW-adr001-v2-verdicts-codex.md`. **MEAS** means
`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`.
**LOG** means `.motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl`; worker log names below are
relative to `.motoko/logfile/`. Other source paths are repository-relative. Coordinates are
one-based, including JSONL lines. Recommendations and counterexamples are identified as such.

## 1. Verdicts

| Decision | Verdict | Reason |
|---|---|---|
| D1 | ACCEPT WITH CORRECTIONS | Runtime publication is useful and the early-answer branch really settles `done` after disappearance (`herdr.ail:1066–1087`). Reuse the existing headless exit path, define empty/error/publication-failure behavior, and preserve exit-action ordering (`index.ts:513–519, :820–827, :877–880`). Non-empty turn output alone is not evidence that the delegated task succeeded (LOG:3637). |
| D2 | **REJECT** | The specified `stop` predicate misses normal `dp7_approved` finalization and the prior guard/persist paths (`session.ail:2394, :3017–3080`). Production approval is raw stdin, not an existing host approval RPC (`stub_step.ail:205–213`). The proposed host race and scripted helper do not yet specify a replayable wake boundary (`dst_replay.ail:793–824`). |
| D3 | ACCEPT WITH CORRECTIONS | Structured metadata fits the existing envelope (`tool_contract.ail:13–20, :60–68`). It needs a lossless core consumer before message capping, sufficient descriptor fields, and lifecycle updates for manual checks as well as wakes (`tool_phase.ail:435–445`; `phase_vocab.ail:901–902`; ADR:120–132, :170–176). |
| D4 | ACCEPT WITH CORRECTIONS | Sharing the wake primitive is reasonable, but replacing stdin alone does not thread the model-switch or completed-turn worlds, nor frame between-turn events (`session.ail:3387–3389, :3415–3426`; `dst_invariants.ail:788–806`). Keep it unscheduled until those obligations are specified. |
| D5 | **REJECT** | Full D3 includes core work, contrary to “host and extension only.” The Ports field has three full literals to update and can be prepared before P2; the existing fixture has no five-class expectation to turn into six (`ports.ail:2556`; `long_qwen_compaction_dst.ail:383, :513`; `fixtures/expected.json:13–30`). Preserve D6 and gate activation, but revise the dependency claim. |

## 2. D1 — Runtime completion, answer publication, and exit

**What stands.** The authority and reporting funnel are established decisions, not new runtime
requirements: 020's `ADR-001-herdr-agent-integration.md:120–141` selects lifecycle authority and
`setRunState`; its :143–158 explains the `error`→`blocked` mapping. The current unions are
`MotokoRunState = idle | thinking | tools_wait | tools_run | error` and
`HerdrState = idle | working | blocked | unknown` (`src/tui/src/herdr-agent-state.ts:43–46`).
An internal `done` state mapped to `idle` plus a message is compatible with those distinct
vocabularies. It must also update `RunState` in `src/tui/src/ui.ts:790`, not only the reporter union.

The runtime already emits a typed completion event: the Finalize arm constructs `DoneEvent`,
appends it before `RunSummary`, publishes the exit manifest, and then emits `done`
(`src/core/session.ail:2480–2487`). The new act is **host-owned answer publication and a more
precise host state**, not inventing the runtime's first completion signal. A non-empty answer
file currently yields `done/reported`, not verified success; the governing dagr design explicitly
allows the file itself to report failure (`DESIGN-dagr-as-delegation-view.md:208–215`).

**One-shot execution already exists.** `--headless` sets the headless flag (`src/tui/src/index.ts:605–606`),
the non-TTY path runs one task (:829–859), both loggers exit on `done` (:513–519, :572–575), and
the core skips the conversation loop when `policy.headless` is true (`src/core/session.ail:3357`).
The existing exit hooks release authority (`herdr-agent-state.ts:295–301, :330–351`). An additional
`--oneshot` can be justified if it preserves the interactive display while ending after one task;
otherwise it can alias/reuse this implementation. ADR:51's unqualified “never exits” is false.

**The answer-first claim is correct at reviewed HEAD.** `do_check_motoko` reads the file at
`packages/motoko-ext-herdr/herdr.ail:1066`. If present and non-empty, it attempts pane close
(:1068), calls `dagr_settle(..., "done", "done", "reported", ...)` even when close fails
(:1079–1081), and returns success with the answer (:1082–1087). `agent get` occurs only in the
opposite branch (:1090). Therefore an already-gone agent does not prevent an early answer read
from settling `done`. The brief's approximate :996–1065 must not be used instead of these lines.

Two qualifications matter. First, **the close still happens**; process exit and pane close are
different operations, and unchanged `DelegateCheck` still reaps on the answer-file branch
(:1068, :1115). Second, an answer can appear between a negative early read and a failing
`agent get`; the latter's `agent_not_found` branch settles `lost` without another file read
(:1090–1102). Recommendation: check the answer again before publishing loss. The post-wait
branch already reads before classifying disappearance (:1113–1132).

**Publication needs a terminal contract.** Specify a completed write before loggers can call
`process.exit`, and before extension exit actions and authority release. The current shared
non-TTY event callback awaits logger closure before forwarding terminal events
(`index.ts:870–883`); exit actions are registered before the reporter (:820–827). Put the answer
publication in that common terminal path, with corresponding interactive one-shot handling,
not in the state-mapping function. Preserve an existing non-empty report as proposed, and make
write failure observable with a non-success exit. Test answer publication before both exit
actions and release, including an existing report and an unwritable destination. These are
acceptance recommendations derived from the actual terminal ordering, not implemented behavior.

**D1 cannot promise that every stalled worker now produces an answer.** The INV write worker
has `empty_stop_finalize` followed by `done` with empty output at
`session_2026-09-05T19-43-24-730Z.jsonl:217–219, :252–254, :265–267`. Copying that output writes
no usable answer. Conversely, the orchestrator's non-empty `done` at LOG:3637 says a new P1A
worker was delegated; it is a completed turn, not a completed P1A task. Recommendation: name
the one-shot invocation contract, retain `reported` evidence, and define explicit empty-output,
runtime-error, cancellation, and publication-failure outcomes. Do not label all non-empty
interactive turn ends as proof of task completion (ADR:93–110).

## 3. D2 — The direction is viable; the proposed insertion and boundary are incomplete

**The insertion misses the branch that matters.** `decide` receives `StepState`, not
`C2LoopState` (`src/core/step_machine.ail:114`; `src/core/session.ail:684–697`). Neither existing
projection supplies `open_waits`. After a no-tool model response the driver runs the solver
extensions; `Accept` or `NoDecision` without a persist nudge reaches `c2_after_dp7`
(`session.ail:3017–3080`). Its successful branch sets `last_finish_reason: "dp7_approved"`
(:2394). `decide` finalizes `stop`, `dp7_approved`, and `dp7_fail_open`
(`step_machine.ail:128–129`). Inserting only ADR:123–125's `== "stop"` condition leaves the
ordinary completed-candidate path finalizing with open waits.

The guards are earlier extension decisions. Progress guard may return `ContinueWithFeedback`
(`packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:183–191`), which the
driver turns into `solver_feedback` (`session.ail:3021–3046`). The current open-delegate fix
returns **NoDecision**, not Park or Accept (guard :483–493); NoDecision can still encounter the
persist check (`session.ail:3049`). Thus treating the guard change as optional “belt” is not
enough. A later Park arm cannot undo a feedback/nudge that was already selected.

The empty-stop exclusion also contradicts the unconditional unreachable claim. The empty-stop
guard gives two feedback messages, then NoDecision (`empty_stop_guard.ail:20–37`), and the
Finalize arm explicitly handles empty output (`session.ail:2468–2482`). A non-empty-output
requirement leaves that route available. Either narrow the guarantee to eligible non-empty
candidates or define how an empty stop with pending work terminates or parks. Do not silently
override the empty-stop guard or DP7 rejection to obtain a superficially working Park.

**Required precedence correction.** Preserve pending tool/approval work and DP7 rejection;
classify “waiting” before completion-only progress/persist obligations are applied, while
retaining verification obligations at actual completion. Carry waits into `StepState` and make
the approved-candidate states participate. Add open-wait controls for the existing tests at
`step_machine.ail:279–318, :321–331, :352–377`, plus empty output and two delegates. The
executable counterexample and exact no-wait preservation limits are in §7.2. This is a design
correction, not an assertion that the unimplemented change already passes those tests.

**The host service must be designed, not copied from an approval UI.** Live approval is
`readLine()` and an identity world transition (`src/core/test/stub_step.ail:205–213`). Its
request is ignored. The host writes JSON command lines (`runtime-process.ts:740–742`) and has
no approval handler: `git grep -n -i approval 407d673 -- src/tui/src` finds only the reporter's
comments that Motoko has no approval UI. The existing output dispatch specially services
`tool_calls`, not approval requests (`runtime-process.ts:592–600`). The synchronous port shape
can support a long wait, but its proposed host implementation is new (§7.1).

The suggested `herdr agent wait <pane>` is **not an exit waiter**. The inspected help says its
default matches `idle`, `done`, or `blocked`, indefinitely without a timeout (§7.1). That includes
Motoko's startup idle and ordinary stops. Worse, the extension returns before the agent row
exists (`herdr.ail:935–943`; `types.ail:749–758`), so an immediate waiter can see
`agent_not_found` before startup. D1 does not change those startup facts. Recommendation:
give the host a registered-start/answer/terminal observation protocol; classify disappearance
only after handling the startup interval and checking the answer; never equate a default wait
success with an answer. File observation must include an initial read and recheck around
subscription, so an answer already present cannot be missed. Require an atomic publication
contract if first non-empty file content is to mean a complete answer (ADR:98–102, :136–142).

**One reply needs an identity and lifecycle.** ADR:120–132 has no per-park request identifier,
no host/channel-error outcome, and no specified cancellation of losing waiters. The real channel
also transports `abort`, `exit`, `model_change`, and `restart`
(`runtime-process.ts:754–778`; `session.ail:3372–3398`). Recommendation: correlate each reply
with its run and park attempt; keep unmatched commands out of the wake decoder; cancel/reap
losing child processes and subscriptions on wake, abort, and runtime exit; define late replies
and simultaneous ready handles. A herdr transport failure must not become `Lost(delegate)`:
the current extension deliberately separates those cases (`herdr.ail:1091–1100`).

**The script and ledger are not yet replay integration.** The actual DST approval adapter is
`ports.scripted_approval`, consuming `WorldState.approvals` (:979–983); the helper in
`scripted_ports.ail:50` consumes a different test state of resolved approvals. A new helper
beside the latter does not bind the production driver. Use a scripted wake payload/cursor in
WorldState, with a successor constructed by the adapter; do not make a fixture supply arbitrary
whole `next_state` worlds as its observations (ADR:130–142).

To claim persisted DST replay, name the recording adapter, interaction identity/projection,
outcome encoding, script reconstruction, and world-token codec. Approval has all of these:
`ports.ail:1718–1745`, `dst_interaction.ail:59–66`, `dst_replay.ail:707–718, :793–824`,
`ext_world.ail:515–553`. `WakeRead` as a **RequestClass** only identifies an ordinal witness;
it does not add a wake to the replay interaction vocabulary. An extension round trip currently
rebuilds only the enumerated world fields (`ext_world.ail:543–553`), so a wake queue omitted
there would be lost before the proposed delegate fixture ever parked.

Keep the proposed logical ParkEntered/WakeReceived events, but explicitly append as well as
emit them, give them parity witnesses, and assert payloads. Two runs with the same script are
not a saved-program replay; the existing discovery trace comparison checks variant names,
not wake payload equality (`dst_invariants.ail:1742–1769`). Add wrong-handle, duplicate/late
wake, missing wake, queue exhaustion, stale-world, and “operator input leaves delegate pending”
controls alongside ADR:206–208's success/lost/operator subjects. The ordinal advances once
when the leaf returns, consistent with ADR1:386–404; ParkEntered must be emitted before
blocking so a never-returning wait is observable.

Finally, “the next decision is CallModel” needs the existing policy qualification. The analogous
injected-message continuation enters `call_model_or_fail`, which can fail a step/cost cap,
checkpoint, or reject context pressure (`step_machine.ail:93–111, :136–137`). Preserve those
checks after a wake instead of bypassing them to satisfy ADR:144–147 literally.

## 4. D3 — Keep structured descriptors; carry them through the actual boundary

`Delegate` already returns structured metadata with delegate handle, pane, channel, and kind
(`packages/motoko-ext-herdr/herdr.ail:164–167, :952–955, :1022–1029`). Adding a `wait` field
is additive to a Json envelope (`src/core/tool_contract.ail:13–20`); no new extension ABI sum
is inherently needed for the producer alone.

The consumer is core work. `execute_allowed_tool_call` returns a **Message**, successor world,
and emitted events, and its Handled arm converts the envelope before returning
(`src/core/tool_phase.ail:364, :435–445`). The conversion retains ordinary metadata
(`tool_contract.ail:49–68`), but then caps the encoded message (`phase_vocab.ail:901–902`;
the cap's 65,536-character assertion is :883–898). Recommendation: validate and extract
the descriptor from the successful extension envelope before truncation, and carry the
typed result through the tool fold into loop state. Re-decoding a potentially truncated
model message is not a reliable runtime wait registration protocol.

The two descriptor sketches also disagree. D3 has `answer_path`; D2's `WaitHandle` does not
(ADR:120–122, :170–171). `WaitKind` identifies delegate answer/state versus operator/timer,
while the host additionally needs delegate implementation kind and completion policy. The
existing metadata's `kind` is the delegate kind, not one of those WaitKind constructors
(`herdr.ail:164–167`). Define how answer path, pane/agent locator, kind, identity, and per-park
correlation survive normalization. Validate a returned wait against the registered handle;
do not let an unknown handle silently drain a different pending wait (ADR:125, :131–147).

Manual `DelegateCheck` cannot be entirely unchanged at its integration boundary. It can
already settle and close a delegate (`herdr.ail:1066–1087, :1113–1124`). If only wake results
drain `open_waits`, a successful manual check leaves a stale wait. Define register/update/remove
semantics for failed launches, manual completion, loss, retries, operator wakes, and timers.
Settlement in the dagr file still occurs through `DelegateCheck`; there is no separate settle
tool (`herdr.ail:112`). ADR:146–149 must either retain that collection call after wake, or
name a deterministic runtime/extension callback that consumes the observation and performs
the existing idempotent settle. Merely delivering the answer to the model does not write the
extension's run file.

The retained progress guard is a last-signal prose recognizer, not an authoritative set of
open delegates (`progress_contract_guard.ail:141–180`). Launch A, launch B, then collect B:
its final signal is settled although A is still open. Recommendation: make validated runtime
wait state the guard's input when D2 activates; keep the heuristic only as an explicitly
limited fallback. D3's metadata-only producer can land independently, but full registration
and guard adoption cannot honestly be priced as host/extension-only (ADR:170–176, :190–192).

## 5. D4 — A shared primitive does not by itself close multi-turn threading

The blocking read is now `src/core/session.ail:3367`, not :3270. The command loop handles
EOF, malformed input, abort/exit, model changes, restart, and user messages (:3367–3430).
`rpc.await_first_task` is another unported input wait (:218–237). Recommendation: explicitly
scope initial-input waiting in or out; leave restart policy open if necessary, but specify
what happens to pending requests when restart exits the runtime.

The named ADR1 debt includes more than that read (ADR1:623–624). Model changes discard
`switched.next_state` (`session.ail:3387–3389`). Subsequent turns recurse with the old
`provider` after receiving `traced.world` (:3415–3426); the first-turn wrapper likewise keeps
`started_provider` after `initial_traced` (:3600–3604). It also discards the outer identity
read's successor (:3582–3586). Routing one read through wake_read leaves these separate
threading obligations outstanding. D4 closes the debt only when its plan carries the world
through the whole conversation lifecycle, including publish successors, success, and errors.

Between-turn events need a frame distinct from an already-terminated per-turn trace.
`RecordAfterTerminal` rejects records after RunSummary (`dst_invariants.ail:788–806`), and
ADR1:415–428 explicitly makes frames separate from done/RunSummary. Define the placement of
Operator ParkEntered/WakeReceived and the initial/final ordinal across turns. A two-turn replay
with an intervening model change and a restart/EOF control should establish this closure;
one successful live D2 run does not exercise those paths (ADR:180–196).

## 6. D5 — Prepare the interface early; gate activation and price the real work

The five-class freeze exists in `tools/driver_leaf_inventory/derive.py:14–22, :94–105, :142–154`.
The inventory probe at reviewed HEAD returns **24 sites, zero unresolved**:
EnvRead=13, FileRead=3, ClockRead=5, ToolExec=2, ModelStep=1. The four fixture classifications
match their expectations. It is still a census plus isolated fixture classifier: the real
scan assigns `status: "helped"` from receiver/method recognition (:158–177), while
advance/witness ordering classification is called only for fixture sources (:257–314).
Do not describe that current output as proof that production leaves are instrumented.

**Measured construction cost.** `git grep -n 'approval_read:' 407d673 -- '*.ail'`, followed
by comment/string-aware brace inspection, finds **three full Ports value literals**:

| Construction | Actual addition obligation |
|---|---|
| `src/core/ports.ail:2556–2572` | Add the deterministic default once in `ports_shape_probe`. |
| `scripts/dst/long_qwen_compaction_dst.ail:383–402` | Forward the new base field. |
| `scripts/dst/long_qwen_compaction_dst.ail:513–532` | Forward the new base field. |

`scripted_ports.fake_ports` calls that constructor (`scripted_ports.ail:74–76`), and live,
recording, and generating providers use record updates (`stub_step.ail:221–224, :554–575,
:648–667`). They inherit a field; they are not three more full literals. Semantic overrides
still need deliberate bindings, especially the live host implementation and recorder.

Before P2, the interface-only work is one field declaration, three literal entries, wake
types and a safe unbound/scripted default, plus scanner recognition. If a real scripted
cursor is added, also pay its world constructors and `ext_world` codec once
(`ports.ail:183–208`; `ext_world.ail:515–553`). This can avoid any new session call site until
activation. After P2 the same field/bindings still cost the same, with the additional need
to extend the newly landed RequestClass/witness codecs and checks. P2's planned ordinal,
pending-witness codec, and vocabulary work are enumerated in ADR1:386–438. No source evidence
makes waiting for P2 a cheaper **field addition**; coordinating its sixth class before its
first writer/codec landing avoids a second migration of those surfaces.

There is a concrete scanner hazard, not just a freeze-note edit. `CALL_RE` excludes `wake_read`
(`derive.py:151–154`). Appending an unhelped wake call to session source **in memory** leaves
the inventory unchanged at 24 sites and zero unresolved (§7.3). Update HELPED, REQUEST_CLASS,
and CALL_RE, and require a missing-wake mutant to be detected. `fixtures/expected.json:13–30`
contains four shape verdicts, **no five-class count**; ADR:194, :205 names a nonexistent
five-to-six fixture transition.

Recommended sequencing: land the corrected D1 and additive D3 producer; agree D2's wake schema,
precedence, and transport; prepare the Ports/scanner surface before or with P2; activate the
helped wake leaf only with the ordinal witness, replay adapters, and distinguishing gates.
Keep the D6 baseline/disclosure requirement (ADR1:539–546; PLAN:20–68) wherever a boundary is
changed. Deferring activation until P2 is green is defensible as integration risk management;
requiring the Ports field itself to wait is not supported by the edit census. D4 remains
separate. These are dependency/cost findings, not a claim about other workers' current work.

## 7. Answers to the six requested questions

### 7.1 Is approval_read the right template, including the production RPC path?

**Yes for the synchronous, successor-returning port abstraction; no for the claimed existing
host service.** Production binds an ignored request plus raw `readLine()`
(`stub_step.ail:209–213`); the driver resolves the answer itself (`session.ail:2559–2568`).
DST binds `ports.scripted_approval`, not `scripted_approval_next`
(`ports.ail:979–983, :2558`; `scripted_ports.ail:50–59`).

The TUI/RPC transport is newline JSON on the runtime's stdin and event lines on stdout
(`runtime-process.ts:592–600, :740–742`). A blocking AILANG read can last minutes while the
TypeScript process services child waiters asynchronously; that channel need not become a
different transport merely because the wait is long. But it needs a request event, reply
schema/decoder, correlation, command demultiplexing, lifecycle cleanup, and a headless service
path. None is supplied by the live approval binding. The TUI also explicitly rejects ordinary
input while a task runs (`ui.ts:4046–4049`), so “typing is a wake” requires a new parked input
route and state. A local port signature alone does not unlock it.

Read-only CLI commands actually run, using the injected binary:

```text
"$HERDR_BIN_PATH" pane report-agent --help
  --state <STATUS>  [possible values: idle, working, blocked, unknown]
  --message <TEXT>

"$HERDR_BIN_PATH" agent wait --help
  --until <STATUS>  [possible values: idle, working, blocked, done, unknown]
  --timeout <MS>    Fail after this many milliseconds
  Without --until, matches idle, done, or blocked.
  Without --timeout, waits indefinitely.
```

Both commands exited 0. These establish accepted arguments/defaults, not idle-message display
or exit-race behavior. No report was sent to probe visibility; retain that explicit unmeasured
item. Specify a completion predicate rather than describing the default wait as exit-only
(§3; `types.ail:749–758`).

### 7.2 Can Park be inserted without breaking existing decision tests?

The precise `decide` order is: pending hybrid/tools/approval; DP7 rejection; solver feedback;
persist nudge; stop/DP7-approved/fail-open finalization; then model continuation policy
(`step_machine.ail:114–138`). The driver has already run solver guards and persist policy
before those reason strings arrive (`session.ail:3017–3080`).

I executed this small Python control-flow model of those branches; it is not an AILANG test:

```python
def decision(reason, pending=False, text="done", waits=False, modes=()):
    if pending:
        return "AwaitApproval" if reason == "await_approval" else "RunTools"
    if reason in ("dp7_rejected", "solver_feedback", "persist_nudge"):
        return "InjectUserMessage"
    if waits and text.strip() and reason in modes:
        return "Park"
    if reason in ("stop", "dp7_approved", "dp7_fail_open"):
        return "Finalize"
    return "call_model_or_fail"
```

Observed with open waits:

| Input | ADR's stop-only insertion | Insertion covering all three finalization reasons |
|---|---|---|
| non-empty `stop` | Park | Park |
| non-empty `dp7_approved` | Finalize | Park |
| non-empty `dp7_fail_open` | Finalize | Park |
| `solver_feedback`, `persist_nudge`, `dp7_rejected` | InjectUserMessage | InjectUserMessage |
| empty `dp7_approved` | Finalize | Finalize |
| stop with pending tool calls | RunTools | RunTools |

The no-wait control comparison returned `True` for all eight tested reason strings. Thus an
open-wait-qualified change can preserve the old no-wait tests, including
`test_decide_model_stop_finalize`, both DP7-finalization tests, and the nudge tests
(`step_machine.ail:303–377`). That does **not** show it handles the production wait path:
the old fixtures have no waits. A broad “waits first” insertion would instead suppress
pending tools or DP7/solver feedback. Specify the upstream candidate-classification change
and new cross-product cases; the ADR's stated insertion alone does not establish its claim.

### 7.3 Is after-P2 sequencing actually cheaper?

**No for the field/interface; potentially useful for activation.** The three-literal census
and one constructor-default pattern are in §6. There is no production RequestClass sum at
this HEAD: `git grep -n -E 'RequestClass|WorldRequest|func witness\(' 407d673 -- src/core`
returns no matches. The five-class freeze is Python data and documentation today
(`derive.py:14–22, :142`).

For reproducibility, the following read-only probe loads the actual scanner from the reviewed
commit and gives it Git-backed paths. The mutation affects a string, never the working tree:

```python
import subprocess, collections
H = "407d673acb94ef9af9611e3daa7ae6d322dc48e1"
def source(path):
    return subprocess.check_output(["git", "show", H + ":" + path], text=True)
ns = {"__name__": "review"}
exec(compile(source("tools/driver_leaf_inventory/derive.py"), "HEAD:derive.py", "exec"), ns)
class GitPath:
    def __init__(self, path="", changes=None):
        self.path, self.changes = path, changes or {}
    def __truediv__(self, tail):
        return GitPath((self.path + "/" + tail).lstrip("/"), self.changes)
    def read_text(self):
        return self.changes[self.path] if self.path in self.changes else source(self.path)
base = ns["scan_leaves"](GitPath())
p = "src/core/session.ail"
mutant = source(p) + "\nfunc wake_probe() { st.provider.wake_read(st.world_state, req) }\n"
changed = ns["scan_leaves"](GitPath(changes={p: mutant}))
print(len(base), dict(collections.Counter(x["class"] for x in base)))
print(ns["check_helpers"](GitPath()), base == changed,
      sum(x["class"] is None for x in changed))
```

Output:

```text
24 {'EnvRead': 13, 'FileRead': 3, 'ClockRead': 5, 'ToolExec': 2, 'ModelStep': 1}
[] True 0
```

Separately applying `classify_fixture(strip_noise(source(...)))` to every fixture in
`fixtures/expected.json` returned **4/4 matching**. The mutant proves that changing only
the frozen class list or fixture expectations cannot make the current regex see a wake.
Prepare the field/recognition early; add its real request witness when the leaf activates.

### 7.4 Does the early answer read settle done if the agent is gone?

**Yes, on that branch.** Answer read at `herdr.ail:1066–1067` → close attempt at :1068 →
`done/done/reported` at :1079–1081 → successful answer at :1082–1087. `agent get` is confined
to the no-answer `else` at :1089–1090. The close error is passed as a note condition, not used
to replace `done` with `lost`. The negative-read/get race and unchanged pane close are the
separate corrections described in §2; they do not refute the early-read branch.

### 7.5 Is there a cheaper DST-replayable design meeting the same model-step target?

Yes, for the stated **single successful delegate/collect/settle** target; the following is a
design alternative, not a live measurement (basis: `herdr.ail:112, :1066–1124`;
`session.ail:1078–1106`; `ports.ail:917–938`; `dst_replay.ail:805–825`):

1. Add `DelegateAwait`, which waits for an answer or a classified terminal condition inside the tool.
2. Reuse answer-first collection and the extension's idempotent dagr settlement on completion.
3. Serve the wait through existing ExtPorts/tool dispatch, scripted via the extension-effect cursor.
4. Record/replay the existing interaction outcome; perform any host polling without model calls.
5. Provider calls: Delegate (1), DelegateAwait (2), optional verification/tool action (3), final (4).
6. This buys the count and replayability; general operator interruption/multi-wait arbitration is additional work.

Unlike just raising HERDR_CHECK_WAIT_MS, this tool waits on a **completion condition**, not
one idle/working transition. O1's assertion that the current extension wait makes “nothing
replayable” is incorrect: extension dispatch already passes through `Ports.ext_effect_exec`
and has a script/reconstitution path (`session.ail:1078–1106`; `dst_replay.ail:805–825`).
This alternative does not supersede the owner's broader Park preference; it is a missing
cost comparator for the metric the ADR chose.

### 7.6 What is factually wrong about the code or measurements?

The complete correction list is §8. The raw measurement reconstruction, which changes the
load-bearing number, follows here.

At read time LOG was **2,172,950 bytes**, SHA-256
`2e3b8a4060d13525e4382331bf468ca95c26fb2a3f65b5adb366cb598bb9dcd1`.
This Python selection avoids double-counting the multiple event types emitted for each call:

```python
import json, collections
from pathlib import Path
p = Path(".motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl")
rows = [(i, json.loads(s)) for i, s in enumerate(p.read_text().splitlines(), 1) if s.strip()]
turn = [(i, r) for i, r in rows if r.get("session_id") == "session_1788636426215"]
thinking = [(i, r) for i, r in turn if r["type"] == "thinking"]
calls = [(i, r["step"], c) for i, r in turn if r["type"] == "native_tool_calls"
         for c in r["tool_calls"]]
print(len(thinking), len({r["step"] for _, r in thinking}),
      min(r["step"] for _, r in thinking), max(r["step"] for _, r in thinking))
print(dict(collections.Counter(r["finish_reason"] for _, r in thinking)))
print(dict(collections.Counter(c["tool"] for _, _, c in calls)))
print(collections.Counter(json.dumps(c["arguments"], sort_keys=True)
      for _, _, c in calls if c["tool"] == "DelegateCheck"))
```

Observed:

```text
thinking=195; distinct steps=195; min=0; max=194
finish reasons: tool_calls=192, stop=3
tools: ReadFile=7, Delegate=2, BashExec=110, DelegateCheck=55, WriteFile=10, EditFile=8
DelegateCheck arguments:
  {"name": "mot-dlg-1788636442445@w3:pM"}: 33
  {"name": "mot-dlg-1788637404283@w3:pN"}: 22
```

There are independently 195 `thinking_stream_start` and 195 `provider_call_prepared` records
in the same turn, and LOG:3415 reports `steps_executed: 195`; the terminal event at :3416
has `step: 194`. **193 is not the model-call count.** Subtracting the two guard-rejected
stop calls at :1786 and :2415 yields 193 arithmetically, but those were provider calls too.
The guard feedback events at :1787 and :2416 reproduce steps 6 and 76.

Further re-derivations:

| Claim | Raw result and coordinates |
|---|---|
| 55 checks, all empty arguments, all still working | Count 55 is correct; all have names. Joining results by tool_call_id gives 50 `working`/no-answer, three herdr `done`/no-answer (:2032, :2090, :2659), one `idle`/no-answer (:2253), and one finished answer (:2312, step 74). |
| Approximately 60 pane reads, two send-text nudges | 52 actual `herdr pane read wN:...` invocations in 52 BashExec calls. Four actual send-text invocations at :2140, :2287, :2696, :2804 (steps 52, 71, 113, 127); the extra occurrence at :2131 is help, not a nudge. |
| One bare sleep 90 | One `sleep 90` at :1845, step 14, followed in that same BashExec command by a pane read; not a separate model-only sleep operation. |
| One delegate/wait before takeover | Two Delegate calls at :1716 (step 2) and :2423 (step 77). The research attempt returns an answer at :2312; the write attempt later fails. Last DelegateCheck is step 132 (:2844); steps 134 onward include diagnostics and takeover, with plan mutation at step 136 (:2875). The 195 calls are the whole turn, including implementation, not waiting alone. |
| 300 model steps, 16 turns, 65 checks in the session | Exactly reproduced through LOG:4282. The file now ends at :4472 with 310 thinking records, 18 session_start records, and 67 checks. All 65 historical and all 67 current checks have non-empty name arguments. This is a snapshot boundary, not evidence the older totals were fabricated. |

The pane-read and send-text counts above inspect `native_tool_calls[*].arguments.cmd`, matching
actual `herdr pane read w\d+:` / `herdr pane send-text w\d+:` commands; they do not count
quoted pane contents, help output, or duplicate result events. The ≥100-call excess remains
substantial after correcting the number, but a ≤4 success-path measurement should separately
state whether verification and takeover are included (ADR:211–212; LOG:2875–3416).

**The four idle meanings: a real ambiguity, not four independently logged state transitions.**

| Situation | Evidence re-read |
|---|---|
| Startup before task completion | `herdr-agent-state.ts:278–286` unconditionally reports idle. The 869 ms measurement is in `DESIGN-motoko-as-delegate.md:49–53`, not a timestamped report in these JSONL files. |
| Between turns with delegated work outstanding | LOG:3637 ends with P1A delegated; :3638 is the next “Check up” input. The done handler maps this turn end to idle (`ui.ts:2726–2745`). No completion of the delegated task follows from that state. |
| Empty stop with no result | INV-write worker JSONL:217–219 and P1A worker `session_2026-09-05T20-13-14-952Z.jsonl:352–354` emit empty_stop_finalize then empty done. The same UI handler idles regardless of output. LOG:2253 also directly contains an idle/no-answer check result. |
| A completed answer-bearing turn | D6/P0 worker logs `session_2026-09-05T16-33-31-824Z.jsonl:143` and `session_2026-09-05T16-33-37-788Z.jsonl:571` contain non-empty done events reporting written answers; `ui.ts:2741` maps these to idle too. This is reported completion, not independent verification of their work. |

The current LOG event-type census contains no lifecycle `report-agent` events. Therefore the
logs plus the committed mapping establish **four circumstances sharing one report**, while
the startup delay remains attributed to the prior design's measurement. “Every turn end”
already includes successful and empty stops; these are overlapping meanings, not four
mutually exclusive machine states. D1 maps internal done back to herdr idle, so external idle
does not cease to be ambiguous unless the answer/exit protocol is used (ADR:95–97, :214–216).

One inherited diagnosis also needs correction before it is used to price D1. MEAS:45–49
attributes native WriteFile's empty arguments to `session.decode_or_empty`. At the earlier
reviewed commit **650f0e0**, that function's only consumer was the extension subprocess bridge
(`src/core/session.ail:900–901, :1070–1084` at 650f0e0); native model calls used
`tool_dispatch_adapter.tool_call_to_envelope:46–55`. At final reviewed HEAD **407d673**, the
bridge explicitly rejects non-blank invalid JSON (`session.ail:1078–1109`) and native execution
checks `arguments_undecodable` before dispatch (`tool_phase.ail:326–336, :365–382`). The old
function is gone, with its former role documented at `session.ail:900–910`.

These committed repairs do not retroactively establish what the provider originally sent in
those historical worker calls. Normalized `{}` and an output-token count alone cannot distinguish
truncated JSON from a literal empty object; the old decoder did not preserve the raw failing
string. Keep truncation as a diagnosis requiring raw provider evidence. D1's answer publisher
cannot repair a failed source edit regardless of which upstream cause produced it (MEAS:38–49).

## 8. Corrections to the ADR

1. **Replace 193 model steps with 195 for the named turn** (ADR:25, :212). Count provider calls,
   including the two guard-rejected candidates; LOG:3415 independently reports 195. Retain
   the corrected raw reconstruction in §7.6.
2. **Correct the activity breakdown** (ADR:25, :44–45): 55 checks, 52 pane-read commands,
   four actual send-text nudges, and one sleep-containing command. The whole turn also
   contains two launches and the takeover; every step was not a bounded DelegateCheck
   (LOG:1716, :1845, :2140, :2287, :2423, :2696, :2804, :2875; §7.6).
3. **Correct the inherited empty-argument/all-working claim**: all 55 checks have names;
   one collects an answer, four others observe idle/herdr-done without an answer. MEAS:119–125
   is not reproduced as written (LOG:2032, :2090, :2253, :2312, :2659; §7.6).
4. **Label the measurement snapshot.** The 300/16/65 totals reproduce through LOG:4282;
   current totals are 310/18/67. Attribute 869 ms startup idle to the historical measurement,
   rather than claiming this log independently times it (`DESIGN-motoko-as-delegate.md:49–53`).
5. **Correct the input's decoder attribution**, separately from the ADR's own new design:
   native WriteFile uses `tool_dispatch_adapter.ail:46–55`, now guarded at `tool_phase.ail:371`;
   the extension bridge is `session.ail:1078–1109`. Treat historical argument truncation as a diagnosis needing raw provider evidence,
   not something proved by normalized `{}` (MEAS:45–49; §7.6).
6. **Remove the existing approval-UI/RPC assertion** (ADR:40–42, :77–78, :133–142).
   Production approval ignores the request and calls readLine (`stub_step.ail:209–213`);
   the TUI has no approval handler. Name the new host protocol and parked-input route (§7.1).
7. **Name the correct DST adapter.** `scripted_approval_next` is a test-state helper;
   the driver's bound adapter is `ports.scripted_approval` (:979–983, :2558). A sibling helper
   alone does not make wake_read scripted (ADR:141–142).
8. **State the full herdr vocabulary accurately** (ADR:48–50): reportable states include
   `unknown`, as both the inspected help and `herdr-agent-state.ts:46` show. Keep idle-message
   visibility explicitly unmeasured; no such report was sent in this review.
9. **Recognize existing headless/one-task exit and the existing DoneEvent** (ADR:18, :47–54,
   :103–106). Narrow “never exits”; reuse or distinguish `--oneshot` from `--headless`
   (`index.ts:513–519, :572–575, :605–606`; `session.ail:2480–2487, :3357`).
10. **Do not equate non-empty done with verified task success.** Define one-shot completion,
    empty/error/cancel/write-failure behavior and reported evidence; answer publication cannot
    fix a worker that emits empty done or never performs its edit (ADR:93–110; §2).
11. **Locate answer publication in terminal orchestration, not all in setRunState.** Await it
    before exit actions and release and preserve richer reports (`index.ts:820–827, :877–880`).
    Include both plain/JSONL and interactive one-shot paths in D1's acceptance.
12. **Keep D1's correct early-answer branch claim**, with current coordinates
    `herdr.ail:1066–1087`; add the no-answer/get race control. Do not claim unchanged code
    replaces reap-on-answer with reap-on-exit: it still calls pane close (:1068, :1115).
13. **Replace “agent wait is the exit state change” with an actual completion protocol**
    (ADR:80–84, :136–139). Default wait matches idle/done/blocked; a just-launched Motoko
    may have no row yet (`types.ail:749–758`). D1 does not remove startup idle or make the
    first 20-second check necessarily find an answer (ADR:190–192; LOG:1794).
14. **Repair Park's precedence and state projection** (ADR:123–127). Normal candidates arrive
    as dp7_approved; guards and persist policy run earlier. Narrow or implement the empty-stop
    guarantee. Preserve no-wait behavior and add open-wait controls (§3, §7.2).
15. **Qualify CallModel after wake** (ADR:144–147): continuation still honors step/cost limits,
    checkpoints, and context checks (`step_machine.ail:93–111, :136–137`).
16. **Complete the wake transport contract** (ADR:129–142): request identity, command routing,
    operator handling, host failure, startup/answer races, late replies, and losing-waiter
    cleanup. Distinguish transport error from lost delegate (`herdr.ail:1091–1100`; §3).
17. **Specify recording/replay, not only a scripted list and two events** (ADR:141–158,
    :206–208): cursor, world-token codec, interaction identity/outcome, persisted reconstruction,
    payload assertions, and append/emit parity. RequestClass is not InteractionIdentity
    (`dst_interaction.ail:59–66`; `dst_replay.ail:793–824`; §3).
18. **Unify the descriptor types and preserve metadata before truncation** (ADR:120–132,
    :170–172). Carry answer path, agent kind, identity and completion policy into the waiter;
    lift the envelope before `handled_tool_message` caps it (`tool_phase.ail:435–445`).
19. **Define wait lifecycle updates beyond wakes** (ADR:125, :147–149, :173–176). Manual checks
    can already settle; operator input need not remove a delegate; the existing guard tracks
    only the last textual signal. Name the settlement callback or retain DelegateCheck
    (`herdr.ail:112, :1079–1087`; `progress_contract_guard.ail:164–191`; §4).
20. **Correct liveness aging** (ADR:162–166): the extension omits last_output_at; it emits
    only prompt_acknowledged. The extension-owned view cannot age an output timestamp it
    never received (`packages/motoko-ext-herdr/dagr.ail:40–42, :386–392`;
    `DESIGN-dagr-as-delegation-view.md:149–173`). Keep observation-on-wake as a proposed change.
21. **Do not declare multi-turn threading closed by replacing stdin** (ADR:180–185).
    Include model-change, turn-result, initial identity and publish successors, initial-input
    scope, and frame/terminal ordering (`session.ail:3387–3426, :3582–3611`; §5).
22. **Correct the construction census and sequencing premise** (ADR:190–205). Full D3 has a
    core consumer; there are three full Ports value literals, and scripted/live/recording
    providers mostly inherit through record updates. Prepare the surface before/with P2 if
    useful, gate activation, and preserve D6 (§6).
23. **Replace the nonexistent five-to-six expected-fixture edit** with actual scanner and
    regression work. CALL_RE currently cannot recognize wake_read and the four shape fixtures
    contain no class-count pin (`derive.py:151–154`; `fixtures/expected.json:13–30`; §7.3).
24. **Correct O1's replayability dismissal and add the cheaper completion-tool comparator**
    (ADR:62–65). Existing extension effects are scripted and reconstructed; the broader
    operator/multi-wait behavior can still justify Park (§7.5).
25. **Narrow the promised simplifications and metric** (ADR:211–216). The guard does not
    become irrelevant merely from a new decision; dagr still needs a producer settlement;
    external idle remains shared; and ≤4 measures a specified successful path, not replay of
    the entire failed-worker/takeover history (§§3–4, §7.6).
26. **Reissue coordinates at the reviewed revision.** In particular the blocking conversation
    read is `session.ail:3367`, the native-argument decoder is `tool_dispatch_adapter.ail:46` (guarded at `tool_phase.ail:371`),
    the motoko answer-first branch is `herdr.ail:1066`, and answer-path prose is
    `types.ail:706–718`. Preserve historical coordinates only when explicitly describing
    the historical revision (ADR:9–10, :252).

The blocking issues are the specified insertion's actual reachability, the unnamed host/replay
contract, and the incorrect dependency rationale. The owner's chosen runtime wait abstraction
remains implementable once those obligations are made concrete (§§3, 6–7).
