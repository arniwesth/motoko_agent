# ADR-002 v2.1 adversarial review verdicts

Date: 2026-09-06  
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`)  
Subject: `ADR-002-park-and-wake.md` v2.1  
Prior review: `REVIEW-adr002-verdicts-codex.md`

## Overall verdict

**Reject v2.1 as written; retain the park-and-wake direction and D1/D3/D4 with the corrections below.** v2 did incorporate most of the prior review's 26 requested corrections, but the claim that it folded all 26 is too strong: corrections 4, 5, 14, 16, 19, 25, and 26 are incomplete or mis-folded. The most consequential defects are the still-impossible D2 precedence, a colliding park-request identity, and the provider-call count (`ADR-002-park-and-wake.md:7, :212–231, :233–240, :414–417`).

D6 is not ready to plan. It does not identify the actual resumable state, its two alleged snapshot sites neither cover all turn boundaries nor retain a failed turn, its refusal/identity rules permit unsafe resumes, and stage 2 has no coherent owner for the wait after the TUI exits. It therefore does not yet repair the reported budget-exhaustion behavior (`ADR-002-park-and-wake.md:329–385`; `.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:13–21, :61–68`).

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT WITH CORRECTIONS** | Host-owned atomic answer publication and one-shot reuse are sound, but error/abort exit behavior must be scoped to answer-file one-shot runs, and the ADR must distinguish returned-trace order from stdout order (`ADR-002-park-and-wake.md:168–200`; `src/core/session.ail:2473–2488, :3418–3426`; `src/tui/src/index.ts:513–519, :572–575`). |
| D2 | **REJECT** | Its stated ordering cannot preserve DP7 rejection while parking before solver/persist policy without moving DP7, and `session_id + per-run ordinal` is not unique once D6 deliberately reuses the session id across runs/resumes (`ADR-002-park-and-wake.md:212–240, :378–381`; `src/core/session.ail:2352–2403, :3017–3080`). |
| D3 | **ACCEPT WITH CORRECTIONS** | Extracting typed wait metadata before message capping is correct; the descriptor should be a sum, and lifecycle semantics for host error, retry, and failed/manual settlement must be completed (`ADR-002-park-and-wake.md:293–314`; `src/core/tool_phase.ail:436–449`; `src/core/phase_vocab.ail:901–902`). |
| D4 | **ACCEPT WITH CORRECTIONS** | v2 now names the real multi-turn debt and leaves it unscheduled, but restart/EOF, frame identity, and initial-input scope must be decided before anything—especially D6 stage 2—claims durable cross-process park/resume (`ADR-002-park-and-wake.md:316–327`; `src/core/session.ail:3367–3430`). |
| D5 | **REJECT** | Preparing the wake surface before/with P2 is right, but landing D6 stage 1 before P2 creates known rework, stage 2 is ordered before the framing it needs, and the stated call arithmetic omits the model step that elects Park (`ADR-002-park-and-wake.md:387–405, :414–417`; `ADR-001-sequencing-the-dst-architecture-caps.md:439–450`). |
| D6 | **REJECT** | The proposed snapshot is neither the turn-boundary boot state nor the in-turn Park continuation; publication, strict decode, single-writer identity, policy compatibility, and the actual continuation protocol are unspecified (`ADR-002-park-and-wake.md:329–385`; `src/core/session.ail:383–429, :709–730, :3330–3346`). |

## 1. Disposition of all 26 v1 corrections

The numbered source of truth for the requested corrections is the prior review (`REVIEW-adr002-verdicts-codex.md:546–634`). “Folded” below means the textual obligation appears in v2.1; it does not mean the new design is independently correct.

| # | Result | Audit |
|---:|---|---|
| 1 | **Folded** | The ADR now says 195 provider calls and includes the two guard-rejected calls (`ADR-002-park-and-wake.md:23–25, :111–114`). |
| 2 | **Folded** | It gives 55 checks, about 52 pane reads, four nudges, one sleep-containing command, two launches, and the takeover (`ADR-002-park-and-wake.md:26–30`). |
| 3 | **Folded** | It retracts empty arguments/all-working and gives the 50/3/1/1 outcome split (`ADR-002-park-and-wake.md:26–30`). |
| 4 | **Partly folded** | It attributes 869 ms correctly and labels 300/16/65 as a snapshot, but omits the requested then-current 310/18/67 totals (`ADR-002-park-and-wake.md:86–87`; `REVIEW-adr002-verdicts-codex.md:558–560`). |
| 5 | **Partly folded** | It correctly demotes truncation to an unproved diagnosis, but never supplies the requested corrected decoder attribution: native calls decode at `tool_dispatch_adapter`, while the extension bridge decodes separately (`ADR-002-park-and-wake.md:83–85`; `src/core/tool_dispatch_adapter.ail:36–55`; `src/core/session.ail:1078–1108`). |
| 6 | **Folded** | The approval-UI claim is retracted and the host protocol/parked-input route are explicitly new (`ADR-002-park-and-wake.md:31–34, :242–259`; `src/core/test/stub_step.ail:205–213`; `src/tui/src/runtime-process.ts:592–600`). |
| 7 | **Folded** | The correct `ports.scripted_approval` analogy and the complete wake replay set are named (`ADR-002-park-and-wake.md:35–39, :273–286`; `src/core/ports.ail:975–983, :1718–1745`). |
| 8 | **Folded** | `unknown` is included and idle-message visibility is expressly unmeasured (`ADR-002-park-and-wake.md:132–136, :172–176`; `src/tui/src/herdr-agent-state.ts:43–46`). |
| 9 | **Folded, with one wording error** | Headless one-task exit and the existing typed `DoneEvent` are recognized (`ADR-002-park-and-wake.md:40–43, :186–188`). However, stdout emits `RunSummary` before `DoneEvent`; only the returned trace appends `DoneEvent` before `RunSummary` (`src/core/session.ail:1550–1554, :2473–2488`). |
| 10 | **Folded** | D1 no longer equates a non-empty report with verified success and defines empty/error/cancel/write-failure outcomes (`ADR-002-park-and-wake.md:181–200`). |
| 11 | **Folded** | Publication is placed in terminal orchestration before exit actions/release and both output modes are in acceptance (`ADR-002-park-and-wake.md:177–196`; `src/tui/src/index.ts:820–827, :870–883`). |
| 12 | **Folded** | The answer-first behavior, negative-read/get race, and unchanged pane close are all retained (`ADR-002-park-and-wake.md:188–192`; `packages/motoko-ext-herdr/herdr.ail:1064–1102, :1113–1124`). |
| 13 | **Folded** | The ADR replaces default `agent wait` with registered-start plus answer/terminal observation and distinguishes Motoko from Claude/Codex (`ADR-002-park-and-wake.md:247–256`; `packages/motoko-ext-herdr/herdr.ail:935–955`). |
| 14 | **Mis-folded** | State projection, all stop classes, empty stops, and no-wait controls are named, but the proposed order is not implementable as stated: DP7 currently runs only after solver/persist, while the table requires DP7 rejection before Park and solver/persist after Park (`ADR-002-park-and-wake.md:208–231`; `src/core/session.ail:2352–2403, :3017–3080`). |
| 15 | **Folded** | The post-wake continuation explicitly goes through `call_model_or_fail` and retains its caps/checkpoint/context checks (`ADR-002-park-and-wake.md:265–271`; `src/core/step_machine.ail:93–111`). |
| 16 | **Folded, but defective** | Routing, host failure, startup/answer races, late replies, simultaneous readiness, and cleanup are covered (`ADR-002-park-and-wake.md:233–263`). The identity chosen to support those rules can collide because its ordinal is per-run while D6 deliberately preserves the session id across resume (`ADR-002-park-and-wake.md:238–240, :378–381`). |
| 17 | **Folded** | The cursor, codec, recorder, causal identity/outcome, reconstruction, payload assertions, and append/emit parity are all listed (`ADR-002-park-and-wake.md:273–291`). |
| 18 | **Folded** | One descriptor carries answer path, delegate kind, locator, wait policy, and run key; core extracts it from the successful envelope before capping (`ADR-002-park-and-wake.md:293–304`; `src/core/tool_phase.ail:436–449`; `src/core/phase_vocab.ail:901–902`). |
| 19 | **Partly folded** | Failed launch, wake, manual settlement, timer, operator input, retained `DelegateCheck`, and guard input are covered, but retry and `HostError` lifecycle are not; “remove on a matching wake” would also remove a still-live wait on transport failure (`ADR-002-park-and-wake.md:305–314`; `ADR-002-park-and-wake.md:236–237, :255–256`). |
| 20 | **Folded** | Liveness aging is retracted and observation-on-wake remains explicitly new work (`ADR-002-park-and-wake.md:54–56, :436–437`; `packages/motoko-ext-herdr/dagr.ail:386–392`). |
| 21 | **Folded** | D4 now names model-change, provider/world, identity, publish-successor, initial-input, and frame/terminal obligations, and does not claim they are already closed (`ADR-002-park-and-wake.md:316–327`). |
| 22 | **Folded** | D3 core work, the three full `Ports` literals, early surface preparation, and gated activation are reflected in sequencing (`ADR-002-park-and-wake.md:62–69, :389–402`; `src/core/ports.ail:2553–2572`; `scripts/dst/long_qwen_compaction_dst.ail:383–402, :513–532`). |
| 23 | **Folded** | The nonexistent fixture-count migration is retracted and `HELPED`, `REQUEST_CLASS`, `CALL_RE`, and a red missing-wake mutant are specified (`ADR-002-park-and-wake.md:57–61, :393–397`; `tools/driver_leaf_inventory/derive.py:94–105, :142–154`). |
| 24 | **Folded** | O1's existing replayability is acknowledged and `DelegateAwait` is retained as the cheaper fallback/comparator (`ADR-002-park-and-wake.md:80–82, :142–164`). |
| 25 | **Mis-folded** | External idle, guard, and dagr settlement are narrowed correctly, but the provider-call accounting is still wrong: the displayed three-call success path omits the stop-producing call required to enter Park (`ADR-002-park-and-wake.md:111–114, :265–271, :414–417`; `src/core/session.ail:2217–2272`; `src/core/step_machine.ail:128–138`). |
| 26 | **Partly folded** | The ADR reissued a coordinate catalogue for `8980ba6`, not current HEAD, and several citations are semantically or numerically wrong: the core `Handled` return is now `tool_phase.ail:436–449`, `herdr.ail:112` lists tool names rather than being a writer, `InvocationConfig` is in `config.ail:133–138`, and the third manifest publish is omitted (`ADR-002-park-and-wake.md:12–14, :309, :354–355, :469`; `src/core/tool_phase.ail:436–449`; `packages/motoko-ext-herdr/herdr.ail:112`; `src/core/config.ail:133–138`; `src/core/session.ail:3600–3602`). |

## 2. Decision verdicts D1–D5

### D1 — accept with corrections

The core direction is sound. `--headless` already supplies one-task execution; plain and JSONL hosts exit on `done`, and the host registers exit actions before reporter release (`src/core/session.ail:3347–3357`; `src/tui/src/index.ts:513–519, :572–575, :820–827`). Publishing a non-empty answer atomically before forwarding the terminal event gives the waiter a much stronger completion signal than the shared external `idle` state (`ADR-002-park-and-wake.md:172–192`; `src/tui/src/ui.ts:2726–2745`).

Required corrections:

1. Scope “error/abort/publication failure exits non-zero” to `--answer-file` one-shot/headless operation. An interactive turn currently emits an error and deliberately re-enters the conversation loop; turning every turn error into process death is a behavior change unrelated to answer publication (`ADR-002-park-and-wake.md:181–196`; `src/core/session.ail:3418–3426`; `src/tui/src/ui.ts:2752–2755`).
2. State both orders accurately: returned trace is `DoneEvent` then final `RunSummary`, while stdout is `RunSummary` then `done` (`src/core/session.ail:1550–1554, :2473–2488`). D1's answer writer belongs in the host callback before it forwards `done`; it should not be described as changing the core ledger order (`src/tui/src/index.ts:870–883`).
3. Correct “all host-side”: the re-read-before-`lost` change is extension work (`ADR-002-park-and-wake.md:170, :188–192`; `packages/motoko-ext-herdr/herdr.ail:1089–1102`).

### D2 — reject

The abstraction remains viable, but the decision is not implementable from the written precedence. Today a candidate goes through `dispatch_solver_candidate`; only `Accept` or `NoDecision` without a persist nudge reaches `c2_after_dp7`, where DP7 is actually checked (`src/core/session.ail:3017–3080, :2352–2403`). D2 simultaneously requires DP7 rejection to outrank Park and Park to outrank solver feedback/persist (`ADR-002-park-and-wake.md:212–222`). Those requirements need an explicit refactor—normally DP7 first, then wait classification, then completion-only solver/persist policy—not “a fixed point in that order” (`ADR-002-park-and-wake.md:212–220`).

The request identity is also unsafe. The conversation loop can execute repeated traced runs, D6 deliberately preserves the session id on resume, and D2 combines that id with a **per-run** park ordinal; ordinal zero can therefore recur once another run starts under the preserved identity (`src/core/session.ail:3330–3346, :3415–3419`; `ADR-002-park-and-wake.md:238–240, :378–381`). Use a session-global monotonic request ordinal stored in `WorldState`, or an unguessable request nonce persisted in the Park snapshot; validate both request and wait generation.

Finally, `HostError` is not a settlement. D3 says every matching wake removes the wait, but D2 correctly says a herdr transport fault is not `Lost`; those statements conflict (`ADR-002-park-and-wake.md:255–256, :265–267, :305–308`). The decision must say whether `HostError` retries, fails the run while preserving the wait, or wakes the model with the wait still open.

### D3 — accept with corrections

The producer/consumer boundary is now correctly located. The extension has the structured result envelope in hand, and core still has `result_env` before it serializes and caps the model-visible message (`packages/motoko-ext-herdr/herdr.ail:952–957`; `src/core/tool_phase.ail:436–449`; `src/core/phase_vocab.ail:901–902`). Registering from that typed side channel is the right design.

Before planning, replace the single record containing delegate-only fields plus `Operator | Timer` with a sum such as `DelegateWait(...) | OperatorWait(...) | TimerWait(...)`; the current record admits nonsensical combinations such as a Timer with `answer_path` and `delegate_kind` (`ADR-002-park-and-wake.md:293–296`). Also define typed wait deltas from both `Delegate` and `DelegateCheck`, including `HostError`, retry/re-delegation, duplicate settlement, and a failed second answer read (`ADR-002-park-and-wake.md:305–314`; `packages/motoko-ext-herdr/herdr.ail:1064–1141`).

The sentence “`herdr.ail:112` is the only run-file writer” should become “`DelegateCheck` remains the only settlement path.” Line 112 merely shows that the extension exposes only `Delegate` and `DelegateCheck`, and `Delegate` itself also writes/open records through `dagr_open` (`packages/motoko-ext-herdr/herdr.ail:112, :947–955`).

### D4 — accept with corrections

v2 repaired the central overclaim: replacing the between-turn `readLine` is not world-threading. The current loop drops the model-change successor, recurses with the old provider after a traced turn, and handles restart outside a framed driver run (`src/core/session.ail:3367–3399, :3415–3426`). D4 now names those debts and a separate between-turn frame (`ADR-002-park-and-wake.md:316–327`).

Acceptance is conditional on deciding restart/EOF, the initial-input boundary, and frame identity before implementation. D4 may remain unscheduled, but D6 stage 2 may not ship before those pieces: a process-resume seam is itself a multi-turn/frame seam (`ADR-002-park-and-wake.md:319–327, :361–380`).

### D5 — reject

The P2-facing part is corrected: adding the `Ports` field and scanner vocabulary before/with P2 avoids reopening P2's new ordinal codecs, and there are three full `Ports` literals rather than the six once claimed (`ADR-002-park-and-wake.md:393–400`; `src/core/ports.ail:2553–2572`; `scripts/dst/long_qwen_compaction_dst.ail:383–402, :513–532`).

The rest of the sequence is not safe:

- ADR-001 P2 is already specified to move exit publication before finalization and make it return the successor world; D5 nevertheless lands D6's snapshot writer at today's publish sites first, guaranteeing a second rewrite of exactly that boundary (`ADR-002-park-and-wake.md:389–390`; `ADR-001-sequencing-the-dst-architecture-caps.md:439–445`; `src/core/session.ail:3484–3532`). Land the corrected snapshot terminal seam with P2, or design it against P2's final signature now.
- D6 stage 2 is ordered before D4 even though it requires a new cross-process frame, stable session/run identity, and restart semantics (`ADR-002-park-and-wake.md:401–403`; `ADR-002-park-and-wake.md:316–327, :370–380`). Move D4's required framing/identity subset before stage 2.
- A “safe unbound default” is not defined. The default must fail closed without blocking, leave the world unchanged except for the required witness, and make queue exhaustion observable; otherwise the three literal edits are not a plan-ready contract (`ADR-002-park-and-wake.md:283–291, :393–397`).

## 3. D6 in depth

### 3.1 The boot tuple is not correctly identified

`c2_initial_state_with_counts` has four inputs—history, `PortedProvider`, world, and prior status counts—and resets `step_idx`, totals, extension artifacts, telemetry, pending tool state, last finish state, trace, and emissions (`src/core/session.ail:709–730`). By contrast, the running loop state contains all of those fields (`src/core/session.ail:383–429`). Therefore `{history, world, prior_counts}` is enough only to start a **new turn** with reconstructed ports; it is not enough to resume an in-turn Park continuation (`ADR-002-park-and-wake.md:331–340, :361–368`).

The surrounding boot inputs are also wider than model/profile. A turn receives task, environment URL, tool mode, budget plan, session policy, model, workdir, cost policy, provider, session id, start clock, and loop state (`src/core/session.ail:2407–2422, :3330–3346`). Some can be recomputed, but the snapshot must state which are restored, which are recomputed, and which mismatches are refused.

Two specific fields in the proposed object are wrong or undefined:

- `ext_artifacts` are not threaded “beside” the multi-turn loop. They live inside `C2LoopState`, are reset to `{}` at every `c2_initial_state_with_counts`, and are not returned by `TracedSessionResult` (`src/core/session.ail:175–180, :383–388, :709–715`). They are required for a Park snapshot but unavailable at either outer publish backstop without widening the terminal result.
- `step_counts` has no defined mapping. Per-turn `step_idx` drives the budget guard, cumulative `prior_counts` drives status, and total token/cost counters are a third state (`src/core/session.ail:374–411, :545–560`; `src/core/step_machine.ail:93–105`). Restoring `step_idx == step_budget` would immediately fail again; resetting it while retaining cumulative counts is a new-turn resume. D6 must choose and test one rule.

The history rule is also backwards. Pre-step compaction creates `compacted_msgs` for one provider call, while retained loop history remains `st.msgs` and the assistant response appends to that unmodified history (`src/core/session.ail:2741–2749, :2767–2790, :2884–2888`). A snapshot used to continue the loop must store the authoritative retained history, not “the compacted form the provider saw” (`ADR-002-park-and-wake.md:445–447`). The last provider payload may be stored separately for diagnostics, but substituting it for retained history permanently discards context and changes future compaction.

There is already a resume-specific history constructor that requires a `CheckpointChain` and validates its final digest (`src/core/phase_vocab.ail:34–49, :690–702`). D6 proposes only `[Message]` plus a system-prefix digest, so it neither uses nor supersedes that integrity contract (`ADR-002-park-and-wake.md:334–339, :383–385`). The snapshot schema must carry the checkpoint chain/history digest or explicitly replace that existing resume contract.

### 3.2 The proposed snapshot sites are unsound

There are **three**, not two, calls to `publish_turn_exit_manifest`: the inner success arm, the follow-up-turn backstop, and the initial-turn backstop (`src/core/session.ail:2482–2488, :3415–3417, :3600–3602`). The inner site is success-only; max-steps, provider failure, cost failure, and other errors reach `c2_finalize` without it, relying on an outer backstop (`src/core/session.ail:2423–2438, :2171–2206, :2871–2874`).

Those outer sites cannot write a resumable failed-turn snapshot. `TracedSessionResult` returns `result`, trace, world, and emissions—but not the failed turn's history, totals, telemetry, extension artifacts, or loop state—and the error branch deliberately recurses with the **pre-turn** `history` (`src/core/session.ail:175–180, :3415–3426`). That is the same context-loss shape D6 claims to repair.

Abort/suspend are not at either named site. Conversation-loop `abort`/`exit` returns directly, and `restart` emits `SessionSuspend` then returns directly (`src/core/session.ail:3367–3399`). A snapshot design promising reasons `abort` and `suspend` needs explicit calls on those branches; a mid-provider process kill needs a different checkpoint policy because the AILANG loop is not reading commands there (`src/tui/src/runtime-process.ts:754–760`; `src/core/session.ail:2706–2790`).

The manifest call itself advances state and discards it. It reads an env value through `Ports`, builds an extension context from that successor, calls the extension publisher, and returns `()` (`src/core/session.ail:3484–3532`). A snapshot written before it is not the final world; a snapshot written after it cannot currently obtain the publisher's successor. ADR-001 P2 already requires this function to return the successor world before finalization (`ADR-001-sequencing-the-dst-architecture-caps.md:439–445`).

Atomic persistence is also underspecified at the driver boundary. `Ports` has file write/remove and directory creation but no rename operation (`src/core/ports.ail:806–850, :861–917`). Existing atomic manifest publication has to use a temporary file plus a process-mediated `mv` because the pinned standard library has no rename (`src/core/ext/exit_manifest.ail:44–56, :182–205`). D6 must choose a host-owned atomic writer or add a routed atomic-replace request with recording/replay semantics; “temp then rename” is not an implementation available from the stated tuple alone.

D6 also conflates a resume snapshot with a DST execution program. An `ExecutionProgram` stores an **initial** world, bounds, manifest, and interactions (`src/core/dst_program.ail:215–237`); replay reconstructs fresh queues from those interactions and deliberately starts with an empty interaction log (`src/core/dst_replay.ail:793–833`). A boundary snapshot instead stores the **current**, partly consumed world and its accumulated log (`src/core/ext_world.ail:515–553`). One can be converted into a fixture with a specified adapter, but they are not “the same thing” or automatically one format (`ADR-002-park-and-wake.md:370–376`).

### 3.3 Refusal and identity rules are insufficient

The existing `world_of_json` decoder is total and fills missing or malformed fields with defaults, which is suitable for an extension token but unsafe for a resumable checkpoint (`src/core/ext_world.ail:543–557`). Resume needs a strict `Result[Snapshot, Refusal]` decoder that rejects missing fields, invalid message roles/tool correlations, corrupt counts, invalid ordinals, malformed wait descriptors, and a snapshot whose declared digest does not match its bytes.

`system_prefix_digest` and schema version are necessary but not sufficient. The boot behavior also depends on canonical workdir, profile configuration, loaded extension set/ABI, budget/cost policy, tool mode, and runtime build (`src/core/rpc.ail:241–260, :300–351`; `src/core/session.ail:2407–2422`). At minimum, canonical workdir and a configuration/extension digest must be in the snapshot and refused by default on mismatch. A different profile cannot safely be treated as an ordinary `model_change`, because profile selection constructs the extension runtime and policy before the session starts (`ADR-002-park-and-wake.md:378–385`; `src/core/rpc.ail:241–260, :302–342`).

Keeping the logical session id is right, but it is not enough. Interactive respawn currently creates a new `SessionLogger`; log append uses a host environment id only when one is supplied, while the runtime-child environment allowlist does not forward `MOTOKO_SESSION_ID` (`src/tui/src/index.ts:901–905, :928–952`; `src/tui/src/session-logger.ts:221–240`; `src/tui/src/runtime-process.ts:337–389`). D6 must explicitly pass the restored id to both logger and child, add a new run/frame/resume-attempt id, and use a session-global park request id.

Concurrent resume must be refused. Two processes appending one log, replacing one snapshot, or consuming one wake violate the claimed identity even if they share a session id; the current logger opens in append mode and snapshot replacement is single-path state (`src/tui/src/session-logger.ts:233–240`; `ADR-002-park-and-wake.md:346–349, :378–380`). Require a single-writer lease plus a monotonically increasing snapshot generation/CAS, and record snapshot digest, generation, old run id, and new run id in `SessionResumed`.

The snapshot contains conversation/tool content and potentially synthetic world values, so retention and filesystem permissions are part of the persistence contract, not merely UI polish (`ADR-002-park-and-wake.md:334–340, :448–449`; `src/core/ext_world.ail:515–540`). PLAN-002 should require a private session directory, explicit secret policy, maximum snapshot size, write-failure behavior, and cleanup/retention behavior.

### 3.4 Stage 2 does not safely compose with D2 Park

D2 defines a synchronous `wake_read` leaf: Park issues a request and receives one `WakeInput` successor (`ADR-002-park-and-wake.md:233–240, :288–291`). D6 stage 2 instead exits after `ParkEntered`, lets a host waiter resolve the request, restarts the runtime, delivers that `WakeInput` as the first command, **and** says every wait is re-observed before anything else (`ADR-002-park-and-wake.md:361–368`). These are competing continuations. If resume consumes the supplied wake directly, no `wake_read` leaf records/advances; if it calls `wake_read` again, it creates a duplicate request after the host already resolved the old one.

The host lifetime is also missing. On an ordinary runtime-child exit with no restart/interruption/error/prewarm flag, the TUI stops and exits; its process-exit hooks then run exit actions and release the herdr reporter (`src/tui/src/index.ts:820–827, :922–984`). Therefore the named TUI cannot both disappear with the pane/process and remain alive as “the host waiter.” A durable park needs an explicitly durable supervisor outside the pane, or a new suspended-child state in which the TUI and waiter remain alive and the parent does **not** execute session exit actions.

The “outlive a container restart” claim is overstated. The measured herdr contract says a herdr server restart kills its delegates and their pane tokens do not survive (`src/tui/src/session-identity.ts:23–27`). A persisted Park can survive only as a resumable record that may observe `Lost`; it cannot promise continued delegate work across that restart without another durable execution service.

The safe state machine must distinguish at least `Running`, `ParkRequested`, `SuspendedWaiting`, `WakeResolved`, and `Resuming(generation)`. Exactly one of two paths should apply: either the runtime remains alive and `wake_read` returns, or a durable supervisor owns the outstanding request and resume validates/consumes its persisted outcome exactly once. Re-observation is the recovery path only when no resolved outcome exists, and it must preserve the original request generation (`ADR-002-park-and-wake.md:238–240, :260–267, :361–380`).

Stage 2 also needs the exact Park continuation, not the stage-1 turn tuple: current `C2LoopState` includes response text/reason, totals, telemetry, artifacts, nudges, trace/emissions, and pending state beyond history/world (`src/core/session.ail:383–429`). Because a resumed trace must open a new frame after the prior terminal boundary, the frame rule D4 leaves open must precede stage 2 (`ADR-002-park-and-wake.md:323–327, :370–376`).

### 3.5 D6 does not yet repair step-budget exhaustion

The issue asks for the 100-step context and counts to survive and for the user's next `continue` to resume that same session (`.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:13–21, :61–68`). At HEAD, max steps becomes `Fail`, is mapped by message text to `TermMaxSteps`, and returns an error result (`src/core/step_machine.ail:93–104`; `src/core/session.ail:2164–2206`). The outer loop then retains the pre-turn history rather than the failed turn's accumulated state (`src/core/session.ail:3415–3426`).

D6 says the budget path writes a snapshot “before exiting” and exposes `--resume`, but it does not specify how the ordinary `continue` input selects that snapshot, whether the current runtime exits, or whether a resumed turn resets/refills the per-turn budget (`ADR-002-park-and-wake.md:346–359`). Since the named publish backstops no longer possess the failed loop state, the proposed implementation cannot save the 100-step context there (`src/core/session.ail:175–180, :2171–2206`).

To repair the issue, max steps must become a typed resumable suspension, not merely an `Internal` error plus a side file. Capture the exact state before `c2_fail` loses it; publish a successful snapshot (or surface a hard non-resumable error if publication fails); then either continue in the same process from that state on the next operator input or have the TUI automatically respawn with the snapshot generation. The continuation must reset a newly defined per-turn allowance while retaining cumulative provider/status/cost counts, and the acceptance test must reproduce “100 steps → continue → first new provider payload contains prior context and status counts do not reset” (`.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:30–48, :63–68`; `src/core/session.ail:545–560`).

The sibling message-string defect remains separate: max steps is still discriminated by the literal `"v2 loop: step budget exhausted"` rather than a distinct error code (`.agent/issues/max-steps-termination-discriminated-by-error-message-string.md:11–30`; `src/core/session.ail:2164–2168`). PLAN-002 should either give resumable budget suspension a typed code/variant or explicitly preserve and test that compatibility debt.

## 4. Provider-call metric and D5 sequencing

The top-line **≤4 successful-path target remains achievable only with verification excluded**, but the ADR's enumeration is off by one (`ADR-002-park-and-wake.md:111–114, :414–417`). The actual minimum path under D2 is:

| Provider call | Required response |
|---:|---|
| 1 | Emit `Delegate`; core registers the wait. |
| 2 | After the Delegate tool result, emit a stop-class response; only this response can elect Park. |
| — | Park/wake; no provider call. |
| 3 | Emit `DelegateCheck`, as D2 requires the first post-wake step to do. |
| 4 | After the check result, emit the final answer. |

This follows from tool completion setting `last_finish_reason: "tools_complete"`, which calls the model rather than parking, and from Park being limited to a stop-class candidate (`src/core/session.ail:2217–2272`; `src/core/step_machine.ail:128–138`; `ADR-002-park-and-wake.md:218–231, :265–271`). Thus “Delegate (1), … DelegateCheck (2), final (3)” is false (`ADR-002-park-and-wake.md:414–416`).

An optional verification **after collecting the delegate** makes the ordinary sequential path at least five provider calls: call 4 emits the verification tool and call 5 consumes its result and finalizes. It fits four only if “verification” is not a provider-mediated tool after `DelegateCheck`, or if the protocol changes so collection/verification can be issued without a dependent model round trip (`ADR-002-park-and-wake.md:111–112, :414–417`). The acceptance gate should therefore report two numbers: required success path `== 4`, and verified path separately with its explicitly defined call sequence.

For sequencing, retain early wake-surface/scanner preparation, but move corrected D6 stage 1 to the P2 terminal-world change (or deliberately budget the rewrite), require D4's frame/identity subset before D6 stage 2, and do not activate Park until the precedence and globally unique request identity are fixed (`ADR-002-park-and-wake.md:389–403`; `ADR-001-sequencing-the-dst-architecture-caps.md:439–450`).

## 5. “Not decided” items that must move before PLAN-002

The following are design inputs, not implementation details:

1. **Timeout ownership and semantics.** Decide whether a delegate-only Park may be unbounded, whether every Park gets an implicit host timeout, and whether timeout removes only its Timer or also changes delegate state. `TimedOut` already exists in the public outcome sum, so leaving its meaning open makes the D2 adapter and fixtures ambiguous (`ADR-002-park-and-wake.md:233–237, :283–286, :434–435`).
2. **Restart/EOF and initial input.** These define whether D4 owns all command-channel waits and how a pending request is cancelled/framed; D6 stage 1 also promises a restart snapshot, so restart cannot remain open for this plan (`ADR-002-park-and-wake.md:318–327, :349–350, :438`).
3. **Wake versus injected-message vocabulary.** Decide whether wake is a distinct `StepDecision` and ledger event before editing `phase_vocab`, inventory classes, and parity fixtures (`ADR-002-park-and-wake.md:265–281, :409–412, :441`).
4. **Open waits on resume.** Choose the one-owner/exactly-once state machine, state-wait versus answer-only recovery, and whether a resolved wake or re-observation wins. Stage 2 cannot be planned while its central continuation is open (`ADR-002-park-and-wake.md:361–380, :442–444`).
5. **Authoritative history.** Store retained loop history; decide separately whether the TUI displays all of it or a projection. The current “compacted form” choice contradicts the implementation and would alter continuation semantics (`ADR-002-park-and-wake.md:445–447`; `src/core/session.ail:2741–2749, :2884–2888`).
6. **Snapshot validation, ownership, and failure policy.** Decide strict decoding, workdir/config/profile/build compatibility, single-writer lease/generation, permissions/size, and what max-steps does if snapshot publication fails (`ADR-002-park-and-wake.md:346–385`; `src/core/ext_world.ail:543–557`).
7. **Session/run/frame identity.** Keep the logical session id, but define a new run/frame/resume-attempt id and a session-global park-request id; also specify how the TUI logger and child receive the restored id (`ADR-002-park-and-wake.md:238–240, :370–381`; `src/tui/src/session-logger.ts:221–240`; `src/tui/src/runtime-process.ts:337–389`).
8. **Budget continuation semantics and trigger.** Decide whether `continue` resumes in-process or causes an automatic `--resume`, and define the new allowance versus cumulative counts. Without this, D6 cannot claim the issue is repaired (`ADR-002-park-and-wake.md:346–359`; `.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:61–68`).

The herdr idle-message probe may remain PLAN-002's first measurement, observation/liveness while parked may remain optional, nested delegation can use the same corrected one-owner rule, and retaining extra historical snapshots may remain a later operational choice (`ADR-002-park-and-wake.md:434, :436–440, :448–449`). The raw-provider truncation diagnosis is unrelated to park/resume and may also remain open (`ADR-002-park-and-wake.md:450–451`).

## Required ADR changes before PLAN-002

1. Rewrite D2 around an explicit `DP7 → wait classification → completion-only solver/persist` pipeline and a session-global request identity (`src/core/session.ail:2352–2403, :3017–3080`).
2. Correct the success metric to exactly four provider calls without verification and state the verified-path number separately (`src/core/session.ail:2217–2272`; `src/core/step_machine.ail:128–138`).
3. Split D6 into a strict turn-suspension snapshot and an exact Park-continuation snapshot; neither should be described as the current four-argument initializer tuple (`src/core/session.ail:383–429, :709–730`).
4. Put snapshot capture before terminal state is discarded, cover all three turn publish paths plus direct suspend/abort, and integrate with P2's successor-returning terminal seam (`src/core/session.ail:2171–2206, :2482–2488, :3367–3399, :3415–3426, :3600–3602`; `ADR-001-sequencing-the-dst-architecture-caps.md:439–445`).
5. Define strict decode, compatibility/refusal, single-writer identity, and snapshot publication failure behavior (`src/core/ext_world.ail:543–557`; `src/tui/src/session-logger.ts:233–240`).
6. Move D4's framing/identity subset before D6 stage 2 and name the durable waiter that survives the runtime child without terminating the TUI/session (`src/tui/src/index.ts:922–984`; `ADR-002-park-and-wake.md:316–327, :361–380`).
7. Replace the D6 issue claim with an executable acceptance test for context and count continuity across the 100-step boundary and ordinary `continue` (`.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:30–48, :61–68`).

Until these changes are made, PLAN-002 would be forced to decide core persistence, identity, and continuation semantics while implementing them—the exact class of architectural choice the ADR is supposed to settle first.
