# ADR-003 v1 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; matches the HEAD the ADR names at `ADR-003-session-snapshot-and-resume.md:11–12`)
Subject: `ADR-003-session-snapshot-and-resume.md` v1 (unreviewed)
Inputs read first: `REVIEW-adr002-v2.1-verdicts-codex.md` §3.1–3.5 and §5 items 4–8; `ADR-002-park-and-wake.md` D2 (`:202–291`), D4 (`:316–327`), D6 (`:329–385`); `ADR-001-sequencing-the-dst-architecture-caps.md` D2 (`:371–429`) and P2 item 5(a) (`:439–445`); `PLAN-001-implement-adr-001.md` P2 Part 1 (`:360–400`); both issues.

Every coordinate the ADR cites was re-read at this HEAD. §10 is the coordinate audit; the body cites only what was verified.

## Overall verdict

**Accept the direction; return for a v2 before PLAN-003.** ADR-003 answers all five rejection grounds *in structure*: it splits the object (D1), moves capture to the `Fail` arm where `st` is in scope (D2), replaces the total decoder with a `Result` decoder (D4), adds identity, generation, lease and compatibility rules (D5), and names an owner for a durable park (D7). Four of the five grounds carry residuals that a PLAN-003 would otherwise have to decide while implementing, which is the class of defect the v2.1 review rejected D6 for:

1. **The envelope omits the per-run boot inputs the review asked it to name** (`REVIEW-adr002-v2.1-verdicts-codex.md:106–108`). `c2_loop` takes `task`, `env_url`, `hybrid_tools`, `budget: BudgetPlan`, `ohmy_pi`, `max_cost_millicents`, `cost_rates`, `workdir` (`src/core/session.ail:2407–2421`); the D1 envelope carries `compat.workdir`, `compat.model`, `compat.profile` and nothing else of these (`ADR-003:124–139`). `task` in particular is neither restored nor recomputable, and `rpc.run_with_config` builds the budget plan and the system prompt *from* the first task, after `await_first_task` (`src/core/rpc.ail:275–296`, `:300–342`), which D6 says happens *before* it (`ADR-003:305–308`).
2. **The three-way `RunOutcome` is not the minimal safe type change.** `TracedSessionResult.result` is matched as a `Result` at about thirty sites outside `session.ail` (§3), and the DST bridge hands it to `completed_run(outcome: Result[[Message], AIError], …)` (`src/core/dst_execution.ail:128–130`; `src/core/dst_result.ail:130–137`), whose `Ok`/`Err` is what `outcome_agreement_findings` decides on (`src/core/dst_invariants.ail:1375–1394`). The ADR lists two session sites and "the DST bridge" (`ADR-003:374–377`).
3. **The checkpoint-chain reuse in D4 refuses the ADR's own fixture.** `history_from_resume` validates `last after_digest == digest(whole history)` (`src/core/phase_vocab.ail:39–48`, `:690–698`); any message appended after the last checkpoint breaks it, and the loop appends after every checkpoint (`src/core/session.ail:2887`). No chain is retained across runs anyway (`:2519`, `:2539`, `:728`).
4. **D5 and D6 contradict each other on restart.** D6 makes `restart` respawn with `--resume` "which is how a profile switch keeps its history" (`ADR-003:309–311`); D5 makes a profile mismatch a refusal that "needs a new session" (`:272–274`, `:276–277`). `restart` exists to switch profile (`src/tui/src/runtime-process.ts:776–780`; `src/tui/src/index.ts:931–934`).
5. **D3's "helped leaf … no new ordinal class" contradicts P2.** `FileMutation` is a return record (`src/core/ports.ail:630–634`), not a `RequestClass`; the class enum is frozen at five with file mutations exempt (`tools/driver_leaf_inventory/derive.py:124–142`; `PLAN-001:376–381`). A helped leaf that advances needs a class.

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT WITH CORRECTIONS** | Two objects under one envelope is the right split and matches `C2LoopState` (`session.ail:383–429`); the envelope must add the per-run boot inputs, define `cumulative` at capture, and say what `totals` means after a resume. |
| D2 | **ACCEPT WITH CORRECTIONS** | Capture at the `Fail` arm is sound (§3); the result-type change must become additive or enumerate every match site and the bridge mapping; the record order and the deleted test/catalogue sites need naming. |
| D3 | **ACCEPT WITH CORRECTIONS** | A ported atomic replace at the P2 seam is consistent with ADR-001 D2 and P2 5(a); the request class, the module layering, the outer-backstop manifest on suspended turns and the world at the abort/restart rows are unspecified or wrong (§4). |
| D4 | **ACCEPT WITH CORRECTIONS** | Retained-history rule is correct and the strict decoder is right; the checkpoint-chain clause is rejected as specified and must be replaced by the whole-history digest (§5). |
| D5 | **ACCEPT WITH CORRECTIONS** | Lease + generation CAS is the right shape; the per-run id site (`session.ail:3137–3139`) is not named, `run_id` uniqueness is not established, the extension digest source is misdescribed, and the restart contradiction must be resolved (§6). |
| D6 | **ACCEPT WITH CORRECTIONS** | The in-process half repairs the issue; the cross-process/restart half is not implementable as written because the prompt and budget are task-conditional and profile switch is refused by D5 (§7). |
| D7 | **ACCEPT WITH CORRECTIONS** | One-owner rule is coherent with ADR-002 D2 and the TUI exit handler; the exactly-once consumption must go *through* `wake_read` and the retired request id must be reconciled with ADR-002's drop rule (§8). |
| D8 | **ACCEPT WITH CORRECTIONS** | Order is right; step 1 cannot carry `open_waits`/`park` types that do not exist, step 2 needs the class, and the DST env-read fixtures move under D5 (§9). |

## 1. Does ADR-003 answer the five grounds?

| Ground (v2.1 review) | Where ADR-003 answers it | Answered? | Residual |
|---|---|---|---|
| 3.1 Boot tuple is a new-turn initializer, not a continuation | D1 `ContinuationBody` = `C2LoopState` minus `provider`, `trace`, `emissions` (`ADR-003:141–156`); `c2_initial_state_with_counts` resets verified (`session.ail:709–730`) | Yes, in structure | `task` and the other `c2_loop` inputs (`session.ail:2407–2421`) are absent; `nudges_used` is derived from history, not reset (`:726`); `totals` carried across a resume changes the cost cap from per-turn to cumulative (§7). |
| 3.2 Named snapshot sites cannot see a failed turn's state | D2 item 3 captures at `:2437` inside `c2_loop` where `st` is in scope (`session.ail:2407–2437`) | Yes for budget exhaustion | The abort/restart rows of the D3 table have no turn world in hand (`:3373`, `:3391–3399`; the loop threads none, `:3380–3386`); the outer backstops still publish the manifest for non-success turns (`:3416`, `:3601`) and the ADR does not say whether that continues on `Suspended`. |
| 3.3 Decoder is total | D4 `snapshot_of_json: Json -> Result[Snapshot, Refusal]` (`ADR-003:233–242`) | Yes | The chain check is wrong (§5); the strict `world_of_json` variant is a parallel decoder for every nested accessor (`ext_world.ail:543–553`), under-priced. |
| 3.3 Identity and single-writer rules absent | D5 (`ADR-003:247–280`) | Yes | Per-run id is minted at `session.ail:3137–3139`, not named; `run_id` from a clock read is not unique within a millisecond; `rpc.ail:260` emits names, not ABI versions; profile-refusal vs restart. |
| 3.4 Stage 2 has no owner once the child exits | D7 `suspended-child` TUI state (`ADR-003:335–343`); exit handler verified (`index.ts:922–985`) | Yes | How the persisted wake is consumed relative to the `wake_read` leaf and the `request_id` drop rule (`ADR-002:239–240`) is not defined. |
| 3.5 Does not repair the issue | D2 + D6 (`ADR-003:284–320`) | In-process yes; restart no | See §7. |

## 2. Per-decision verdicts

### D1 — accept with corrections

Verified: `C2LoopState` fields (`session.ail:383–429`; `provider: Ports` is at `:389`, not `:398` as the ADR says at `ADR-003:105`); the four-argument constructor and what it resets (`:709–730`). Messages cross the extension ABI as `history_slice: [Msg]` (`packages/motoko-ext-abi/types.ail:547`); `Msg` has no `images` field while core `Message` does (`session.ail:3402–3408`), so the `[Message]` codec is new work, not a port of the ABI one; the round-trip test should name `images`.

Corrections:

1. Add to the envelope, or state as recomputed with the rule: `task`, `env_url`, `hybrid_tools`, `budget: BudgetPlan`, `step_budget`, `ohmy_pi`, `max_cost_millicents`, `cost_rates` (`session.ail:2407–2421`; `:3330–3345`). `task` cannot be recomputed and is what `mk_v2_ext_ctx` and `publish_turn_exit_manifest` receive (`:2745`, `:3486`).
2. Define `cumulative` at capture as `runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))` (`:545–553`, `:559`), since the trace is not in the snapshot and the resumed run starts with an empty one (`:728`).
3. `open_waits: [WaitDescriptor]` and `park: Option[ParkRequest]` name types that do not exist at HEAD (no `wake_read`/`ParkRequest` in `src/core`), so D8 step 1's "D1 types and codecs now" cannot include them without stubs. Say so.
4. `nudges_used` is `count_persist_nudges(history)` in the constructor (`:726`); the ADR's "resets everything else" (`ADR-003:40–43`) is inexact and the continuation body's `nudges_used` should be documented as authoritative over the derived value.

### D2 — accept with corrections

Verified: budget check and `Internal` code (`step_machine.ail:93–103`); `decision_fail_reason` (`session.ail:2164–2169`); `c2_fail` signature without `msgs` (`:2171–2185`); the `Fail` arm in `c2_loop` with `st` in scope (`:2431–2437`); the outer `Err` arms emit `ErrorEvent` and recurse with the pre-turn history (`:3420–3426`, `:3605–3611`); `finish_reason_wire(TermMaxSteps) == "max_steps"` (`:3697`).

Corrections:

1. **Result shape.** Replace the three-way sum with an additive field, or enumerate every site (§3). This is the ADR's own "Not decided: whether `Suspended` should carry the `AIError` too" (`ADR-003:400`); it is a design input, not an implementation detail.
2. **Record order.** D2 item 3 says `c2_suspend` "appends a `RunSuspended` record, publishes the snapshot (D3), and finalises" (`ADR-003:179–181`); D3 says a write failure is "a `RunSuspended` with `published: false`" (`:222–223`). The record cannot carry the write's outcome if it is appended before the write. Fix the order: publish manifest, write snapshot, append `RunSuspended{published}`, finalise.
3. **Deleted sites.** Deleting `max_steps_discriminator_message()` also deletes `dst_fault_catalogue.ail:210`, its test `:825–829`, the header rationale `:50–59`, and rewrites `test_decision_fail_reason_mapping` (`session.ail:3705–3712`). List them.
4. **The `code` change is not TUI-visible.** The TUI's `error` event type is `{ type: "error"; message: string }` (`runtime-process.ts:96`); nothing in `src/tui/src` reads `code`. The comments at `session.ail:2155–2160` and `dst_fault_catalogue.ail:50–53` overstate the compatibility surface; the ADR can say so and close the sibling issue on that ground.
5. **Consumers of the retired `error` event** are more than the two headless loggers (§6.3).

### D3 — accept with corrections

Verified: `Ports.file_write/file_remove` rows and `FileMutation` (`ports.ail:630–634`, `:826`, `:850`); `scripted_file_write` consumes the `files` cursor (`:1135–1143`; the ADR cites the binding at `:2562`); the recording adapter records `FileWriteIdentity` (`:1629–1645`); the manifest's temp-then-`mv` (`ext/exit_manifest.ail:44–56`, `:182–205`); three `Ports` literals (`ports.ail:2556–2572`; `long_qwen_compaction_dst.ail:383–403`, `:513–533`); P2 5(a) (`ADR-001:439–445`).

Corrections (§4 has the argument):

1. Name a `RequestClass` for `file_replace` (a seventh, after ADR-002's `WakeRead`), or make it exempt and drop "one `advance`". "No new ordinal class" cannot stand.
2. The shared function cannot live in `ports.ail` and be imported by `exit_manifest.ail` if it needs `exec`: `ports.ail` imports no `std/process` (`ports.ail:32–34`) and `exit_manifest.ail` imports `src/core/ext/runtime` (`:66`). Name the leaf module.
3. State that on a `Suspended` turn `c2_suspend` publishes the manifest itself (as the success arm does at `:2486`) and the outer backstops skip it; otherwise the outer publish at `:3416`/`:3601` advances the world *after* the snapshot and after `RunSummary`, which is the "out of reach" live-loop publish ADR-001 records (`ADR-001:448–449`), and the snapshot's `world` is not "the last world of the run".
4. The abort/exit and restart rows write a `TurnSnapshot` whose `world` the conversation loop does not hold: it recurses with the pre-turn `provider` (`session.ail:3419`, `:3426`, and `live_provider` at `:3611`) and drops successors by design (`:3380–3386`). Either retain `traced.world` in the loop (part of ADR-002 D4's debt) or say the between-turn `TurnSnapshot` reuses the `TurnEnd` snapshot's world and is a metadata update only.
5. The between-turn `abort` (`:3373`) is only reachable while the loop is reading (`:3367`); an abort during a run does not pass through it. The Abort row therefore never sees new history since `TurnEnd`; say what it adds.

### D4 — accept with corrections

Verified: retained history is `st.msgs`; compaction builds `compacted_msgs` for the call (`session.ail:2741–2749`, `:2768`, `:2790`) and the assistant reply appends to `st.msgs` (`:2887`); `world_of_json` is total (`ext_world.ail:543–553`); `history_from_resume` and the chain validator (`phase_vocab.ail:39–48`, `:690–703`); only caller is the test (`:1155–1170`).

Corrections: replace the chain clause (§5). Keep `history_digest` over the decoded messages and `system_is_head_prefix` (`phase_vocab.ail:40`); carry `CheckpointInfo` records as informational.

### D5 — accept with corrections

Verified: `derive_session_id` prefers `MOTOKO_SESSION_ID` and falls back to the clock (`session.ail:1440–1447`); every traced run derives its own id (`:3137–3139`) while the outer loop derives another (`:3586`); every wire event is stamped with `session_id` (`:335–341`); the child env has `MOTOKO_SESSION_MS` and no `MOTOKO_SESSION_ID` (`runtime-process.ts:372`, `:337–389`); logger stem from the env var (`session-logger.ts:233–238`); reporter release hooks (`herdr-agent-state.ts:295–301`, `:330–355`); `run_with_config` emits `loaded_extensions` as names (`rpc.ail:260`); profile is bound before any session (`:241–247`, `:302–342`).

Corrections (§6 has the argument): name `:3137–3139` as the site that becomes `run_id`; establish `run_id` uniqueness by `session_id + generation + run ordinal`, not a clock read; say the lease is written and removed by which process; fix the `rpc.ail:250–260` claim; resolve the restart contradiction; price the DST fixtures that pin `MOTOKO_SESSION_ID` env-read counts.

### D6 — accept with corrections

In-process half: accepted (§7.1). Cross-process/restart half: rejected as written (§7.2); the decision that replaces it must state where the system prompt and budget plan of a resumed session come from and what a profile switch does to a snapshot.

### D7 — accept with corrections

See §8. The ownership rule is coherent; two mechanisms are missing: consumption through the `wake_read` leaf and the request-id reconciliation.

### D8 — accept with corrections

See §9.

## 3. The capture point and the result type

**The `Fail` arm has the loop state.** `c2_loop(…, st: C2LoopState)` (`session.ail:2407–2422`) computes `decide(step_state, policy.step)` (`:2432`) and matches; the `Fail(info)` arm at `:2437` passes fields of `st` to `c2_fail` and is lexically inside the function that owns `st`. So `st.msgs`, `st.totals`, `st.ext_artifacts`, `st.telemetry`, `st.world_state`, the pending fields and `st.prior_counts` are all available there. The decision record is already appended (`:2433`), so `c2_suspend` inherits `trace_with_decision` as `c2_fail` does. The ADR's claim (`ADR-003:178–179`) holds.

**No pending tools at a budget suspension.** `decide` handles `pending_tool_calls` before anything else (`step_machine.ail:114–121`) and reaches `call_model_or_fail` only on the finish-reason arms (`:130–138`); `call_model_or_fail` checks the budget first (`:93–94`). The ADR's citation for this is `step_machine.ail:93` (`ADR-003:297`); the evidence is `:114–138`. The claim is correct.

**Which state is captured.** `Fail` is produced *before* the model call that would have exceeded the budget, so the snapshot holds `step_idx == step_budget` and the history up to the last completed step. Resuming with `step_idx := 0` (D6) is right; restoring it would fail again at `:94`, which the v2.1 review already noted (`REVIEW-adr002-v2.1-verdicts-codex.md:110`).

**Three-way `RunOutcome` is not minimal.** Sites that match `TracedSessionResult.result` as a `Result` at HEAD, beyond the two the ADR names:

| file | lines |
|---|---|
| `scripts/dst/corpus_pr_dst.ail` | `:668`, `:688` |
| `scripts/dst/driver_plus_compose_dst.ail` | `:668`, `:799` |
| `scripts/dst/discovery_dst.ail` | `:619`, `:877`, `:900`, `:1041`, `:1228`, `:1337–1338`, `:1516`, `:1547`, `:1741`, `:1892`, `:1935`, `:1940` |
| `scripts/dst/phase_c2_wiring_scenarios.ail` | `:132`, `:144`, `:160`, `:187`, `:374`, `:466`, `:481`, `:521`, `:533` |
| `scripts/dst/long_qwen_compaction_dst.ail` | `:815–819` |
| `src/core/dst_execution.ail` | `:128–130` → `completed_run(outcome: Result[[Message], AIError], …)` (`dst_result.ail:130–137`) |

The bridge is *already* always `RunCompleted` (`dst_execution.ail:121–127`), so "classes `Suspended` as `RunCompleted`" (`ADR-003:375–376`) decides nothing; the decision is whether `SystemRun.outcome` is `Ok` or `Err` for a suspension, because `outcome_agreement_findings` requires `Ok` with `RunSummary.error == ""` and `Err` with a non-empty error (`dst_invariants.ail:1385–1388`), and `mk_run_summary` writes `error_msg` (`session.ail:1537`, `:1552`).

**Recommendation.** Keep `result: Result[[Message], AIError]` and add `suspended: Option[Snapshot]` to `TracedSessionResult` (`session.ail:175–180`). On suspension `result` is `Err({ code: "StepBudgetExhausted", … })` and `RunSummary.error` is non-empty, so every existing match site compiles unchanged, `outcome_agreement_findings` holds without a bridge change, and the two outer loops check `traced.suspended` before matching `result`. The `Err` arm still must not emit `ErrorEvent` when `suspended` is `Some`. This is the minimal safe change; the sum is the cleaner one only if the ADR is willing to touch the thirty sites and re-specify the agreement invariant for a third case.

## 4. `file_replace` at the P2 terminal seam

**Consistency with ADR-001 D2.** A helped leaf is "a direct call of a `Ports` field by driver-side code" that calls `advance` on the successor and is witnessed before any record is built (`ADR-001:373–374`, `:386–389`, `:396–404`). Writing the snapshot through a `Ports` field from `c2_suspend`/the success arm is exactly that shape, and putting it after the publish returns `{ world, trace }` and before `c2_finalize` (`ADR-001:440–444`) keeps `RunSummary` last. The placement is consistent.

**The class.** `RequestClass` is `EnvRead | FileRead | ClockRead | ToolExec | ModelStep`, frozen (`derive.py:142`; `PLAN-001:376–381`), and today's file mutations are *exempt* fields with `{FS}` rows (`derive.py:124–140`): no driver-side write is a helped leaf at HEAD. `FileMutation` is the port's return record (`ports.ail:630–634`). So D3's "its request class is `FileMutation`, no new ordinal class … a helped leaf … with one `advance`" (`ADR-003:199–200`) is self-contradictory: a helped leaf pushes a `RequestWitness{ordinal, class}` and there is no class to push. PLAN-001 allows the enum to grow ("if P-INV finds an additional helped kind, the enum gains a variant", `PLAN-001:378–380`) and ADR-002 already adds `WakeRead` as the sixth (`ADR-002:288–291`). D3 should add `FileReplace` as the seventh and extend `CALL_RE` (`derive.py:151–155`), which D8 step 2 half-says (`ADR-003:360–361`).

**The effect row.** `file_write` is `! {FS}` (`ports.ail:826`); the proposed field is `! {FS, Process}` because the live binding shells out to `mv` (`exit_manifest.ail:200`). `c2_loop` and the conversation loop already carry `Process` (`session.ail:2422`, `:3346`). Whether a `{FS}`-only scripted binding may be assigned to a `{FS, Process}` field under the pinned AILANG is not established anywhere in the tree; the ADR should state it or bind the scripted adapter with the wider row.

**The shared function.** `ports.ail` imports `std/fs` and `std/env`, not `std/process` (`ports.ail:32–34`), and `exit_manifest.ail` imports `src/core/ext/runtime` (`:66`), which imports `ext_world`, `config` and the ABI types (`ext/runtime.ail:9–38`). "Lifted … into one shared function that the manifest also uses" (`ADR-003:196–198`) needs a leaf module that imports only `std/fs` and `std/process`; say which. Note P2 5(a) already changes `publish_exit_manifest` to return the rendered world instead of `bool` (`ADR-001:442–443`), so the manifest's write is being touched by P2 in any case.

**The world in the snapshot.** A snapshot cannot contain its own write's witness; its `world.ordinal` is the ordinal *before* `file_replace` advances. Under ADR-001 D2 part 3 the frame's `final` then equals `snapshot.world.ordinal + 1`, and a resumed frame "cites the snapshot's final ordinal" (`ADR-003:280`) must mean that value. State it, or the resume fixture will be written against the wrong number.

**Suspended turns and the outer backstops.** See D3 correction 3. Today a non-success run reaches `c2_finalize` without publishing (`session.ail:2429`, `:2437`, `:2758`, `:2765`, `:2873`) and the outer loops publish afterwards (`:3416`, `:3601`). The ADR removes the outer *snapshot* writes (`ADR-003:216–217`) but is silent on the outer *manifest* publish on a `Suspended` turn.

## 5. Strict decode, history digest, checkpoint chain, retained history

**Retained history: correct.** `split_for_compaction(st.msgs)` and the pre-step chain produce the payload (`session.ail:2741–2749`); `compacted_msgs = payload_messages(payload)` is what `dispatch_step` sends (`:2768`, `:2790`); the assistant reply is appended to `st.msgs` (`:2887`). ADR-002 D6's "compacted form" is retracted (`ADR-003:229–231`), matching §5 item 5 of the v2.1 review.

**Strict decoder: sound in principle.** `world_of_json` defaults every field (`ext_world.ail:543–553`, `:556–557`); a `Result` variant that refuses a missing field is the right instrument. Note that every nested accessor (`scripted_steps_of`, `env_of`, `files_of`, `scripted_tools_of`, `interactions_of`, `generator_of`) is total too, so the strict variant is a second decoder tree, not a wrapper.

**Checkpoint-chain reuse: unsound as specified.** `history_from_resume(msgs, chain)` computes `final_digest = history_digest(MkHistory(msgs))` over *all* of `msgs` and calls `validate_checkpoint_chain(chain.initial_digest, chain.checkpoints, final_digest)` (`phase_vocab.ail:42–47`), whose base case is `prev_digest == final_digest` (`:692–694`). So a snapshot passes only if the last checkpoint's `after_digest` (or `initial_digest`, with no checkpoints) equals the digest of the entire retained history. The loop appends the assistant reply after every step (`session.ail:2887`), the tool results after every tool phase, and the operator message at every turn (`:3409`); a `CheckpointTaken` at `:2517–2543` is followed by further appends before any snapshot could be written. The D4 fixture "a compacted-then-continued history whose chain has two checkpoints" (`ADR-003:244–245`) is therefore refused by construction. The only caller at HEAD resumes exactly the post-checkpoint history (`phase_vocab.ail:1161–1168`).

Independently, nothing retains a chain: `TakeCheckpoint` puts the event into `st.trace` (`session.ail:2519`, `:2539`); the trace is per run and reset by the constructor (`:728`); `prior_counts` carries five integers (`:431–437`). Across turns the checkpoints are on the JSONL wire only, which O1 rules out as a source (`ADR-003:90–92`).

**Replacement.** The envelope's `history_digest` over the decoded messages already detects corruption and truncation; a chain adds nothing for a value whose whole content is digested. Drop `history_from_resume` from the resume path; keep `system_is_head_prefix` (`phase_vocab.ail:40`) and add a transcript-validity check (`history_valid_transcript`, `:71–73`); carry `[CheckpointInfo]` as informational. If the ADR wants chain continuity, `CheckpointInfo` must gain the history length at the checkpoint and the validator must digest prefixes, which is a new contract, not reuse.

## 6. Identity, generation, lease, compatibility, and the wire

### 6.1 Identity

The ADR says `session_id` is kept and `run_id` is minted per traced run "a `derive_session_id`-style read of the world clock, `session.ail:3582–3586`" (`ADR-003:249–252`). Two corrections:

- The per-run id at HEAD is minted at `:3137–3139` (`derive_session_id(provider.ports, provider.world)` inside `run_v2_from_messages_traced_with_policy_and_counts`) and is what `ledger_emit` stamps on every event of that run (`:335–341`). `:3586` is the outer loop's id, used only for the conversation-level events (`:3394`, `:3410`, `:3421`). This is the mechanism behind the issue's "two `session_id`s in one file"; the ADR's Consequences claim it "cannot recur" (`ADR-003:382–383`) without naming the site that changes. Forwarding `MOTOKO_SESSION_ID` makes `:1441–1442` return the same id at both sites, which is the actual fix and should be cited.
- `derive_session_id` yields `session_${now_ms}` (`:1445`); a `run_id` derived the same way is unique only if two runs never start in the same millisecond, which the clock does not promise. Use `session_id + generation + run ordinal`, which D5 already uses for the park request id (`ADR-003:252–254`).

### 6.2 Generation, lease

Generation-as-CAS is sound if the lease is the single writer's authority. Two gaps: who writes and removes the lease is not said (the child through `file_replace`, but the exit paths cited are the *host's* process hooks, `herdr-agent-state.ts:295–301`; the child is respawned per task, `index.ts:901–907`, so a child pid in the lease dies at every respawn and every `--resume` would find a dead pid); and a `SIGKILL`ed host leaves a lease that only `--resume-force` clears, which the ADR says (`:262–263`). State that the *host* owns the lease for the session's lifetime and the child inherits it, or that the lease pid is the host's.

### 6.3 Compatibility and the resume ordering

`compat.ext_set_digest` is described as "the loaded extension names and ABI versions, which `run_with_config` already emits at `rpc.ail:250–260`" (`ADR-003:270–271`); `:260` emits `loaded_extension_names(ext_runtime)` only. The digest must come from the registry or the runtime, not from that event.

The resume ordering in D6 is wrong against `rpc.ail`: "reads and strictly decodes the snapshot **before** `await_first_task`, builds the runtime and the system prompt" (`ADR-003:305–308`). At HEAD everything task-dependent, including `compute_budget_plan` and `dispatch_build_system_prompt`, runs *after* the first task arrives (`rpc.ail:275–276`, `:296`, `:319`, `:342`), and the system message is placed at the head of the initial history (`:344–345`). A resumed session already has its system message as the history's head (`phase_vocab.ail:40`); D5's `system_prefix_digest` check "against the prompt about to be sent" (`ADR-003:269`) therefore has nothing to compare against unless the prompt is rebuilt with the *snapshot's* task, which the envelope does not carry. Decide: the resumed session's prompt is the snapshot's (no rebuild, digest recorded for the record), or the prompt is rebuilt from the stored task and compared.

### 6.4 The wire

**`error` on max-steps.** Consumers at HEAD, all of which the ADR must name (it names the first two):

| consumer | effect today |
|---|---|
| `index.ts:517–519` | PlainLogger exits 1 |
| `index.ts:572–575` | JsonLogger exits 1 |
| `index.ts:877–882` | non-TTY path drains the log before exiting on `done`/`error` |
| `index.ts:918` → `:959–970` | `errorOccurred` decides the exit-handler branch if the child later exits |
| `ui.ts:2752–2761` | sets `taskDone = true` and refocuses input; this is what unlocks plain input after max-steps (`shouldLockPlainInput`, `:1790–1795`, `:4046–4049`) |
| `ui.ts:2282` → `herdr-agent-state.ts:89–90` | herdr sees `blocked` |
| `session-logger.ts:343–346` | transcript state and line |

A `run_suspended` handler that only "marks the session suspended and re-enables input" (`ADR-003:185–186`) leaves the transcript, the herdr state and the non-TTY drain undefined. `run_summary` and `session_suspend` are not in `AgentEvent` (`runtime-process.ts:58–103`), so the union needs both new events or they are silently dropped by the switch.

**External consumers.** The AILANG eval-harness adapter reads the JSONL for `run_summary` (`env-server.ts:415–420`); whether it keys on `error` is outside this tree and unverified. Say so in the ADR rather than "the wire loses the `error` event".

**Event vocabulary.** `make event_vocabulary` (`Makefile:1282–1285`) and the goldens (`phase_vocab.ail:1264` pattern) are the right gates; two new variants plus a version bump.

**`session_id` on every event.** Keeping one id across turns changes the value on every wire event of a follow-up turn relative to today (`session.ail:335–341`, `:3137–3139`). That is the intended repair, but it is a wire-visible change and belongs in Consequences.

## 7. Does D6 repair the issue?

The issue asks for three things: the exhausted turn's history survives, `continue` resumes the same session at the budget boundary, and `MotokoRuntimeStatus` reports carried counts (`.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md:63–68`).

### 7.1 In-process: yes

- History: `st.msgs` at `:2437` holds every message of the exhausted turn, including the operator's (`:3409`) and the tool results; the snapshot carries it; the next `user_message` appends to it (`ADR-003:287–289`). The outer `Err` arm's recursion with `history` (`:3426`) is bypassed by the `Suspended` outcome.
- Budget boundary: every traced run starts at `step_idx: 0` (`:711`) and the wire `current_step` is the per-turn index (`:573`), so "reset to 0, budget unchanged" matches today's per-turn allowance.
- Counts: `steps_executed_so_far` is `counts.provider_calls_completed` (`:576`) computed from `prior_counts + trace` (`:559`); `prior_counts` is already threaded across turns (`:3417`, `:3419`). Carrying `cumulative` into the resumed run's `prior_counts` continues it.
- Same session: with `MOTOKO_SESSION_ID` forwarded, `:1441–1442` returns the same id for every run.

One semantic defect: D6 carries `totals` (`ADR-003:294`). `totals` is per-run at HEAD (`:712`) and is what the cost cap compares (`step_machine.ail:104`) and what `RunSummary` reports (`session.ail:1552`). Carrying it makes the cost cap cumulative and the next summary double-count the exhausted run's tokens, only on resumed continuations. Reset `totals` as `step_idx` is reset, and carry a separate cumulative total if the status needs one.

### 7.2 Cross-process and restart: not as written

`restart` emits `SessionSuspend` and returns (`session.ail:3391–3399`); the TUI respawns with an empty task (`index.ts:951`) and `rpc.run_with_config` waits for the first task, then builds prompt and history from it (`rpc.ail:296`, `:342–345`). ADR-003 replaces the empty task with `--resume <id>` (`ADR-003:309–311`). Three things block that text:

1. The task-conditional build order (§6.3): the ADR's "before `await_first_task`" cannot build the prompt without a task.
2. `restart`'s purpose is a profile switch (`runtime-process.ts:776–780`; `index.ts:931–934`), and D5 refuses a profile mismatch outright (`ADR-003:272–274`, `:276–277`). As written, every profile-switch restart writes a `Restart` snapshot that the respawn is then refused from resuming.
3. `InvocationConfig` (`config.ail:133–138`) gains fields, but the TUI's flag parser strips only its own flags (`index.ts:587–622`) and passes the task as `argv[2]`; the child's `load_invocation_config` must learn `--resume`. Small, but it is host + core, not "core + TUI" as costed.

What the decision must say: a `Restart` snapshot is a `TurnSnapshot` whose resume rebuilds the extension runtime and system prompt for the *new* profile from the stored task, accepts the profile change explicitly (recording old and new in `SessionResumed`), and re-derives `ext_set_digest`; or a profile switch is a new session that *imports* the history. Either is defensible; the ADR must pick one and D5's refusal table must match it.

### 7.3 Headless

`MOTOKO_HEADLESS` makes the conversation loop return (`session.ail:3357`) and `main` returns normally (`rpc.ail:355–359`), so the child exits 0 today and the non-zero exit comes from the TUI's `error` handler. The ADR's headless rule (`ADR-003:186–188`) preserves the exit code. Fine.

## 8. D7 against ADR-002 D2 and the TUI exit handler

**One owner, verified against the exit handler.** `index.ts:922–985` branches on `restartPending`, `interrupted`, `errorOccurred`, `preWarmIdle`, else stops and exits. Exit actions and the reporter release are *process*-exit hooks (`exit-actions.ts:425–426`; `herdr-agent-state.ts:295–301`), not child-exit hooks, so a `suspended-child` branch that keeps the process alive runs neither. That is exactly what the v2.1 review asked for (`REVIEW-adr002-v2.1-verdicts-codex.md:149–150`). Two things to add: the branch must be tested *before* `restartPending` (a restart during a park is a cancel, `ADR-002:262`), and quitting the TUI during a durable park runs the exit actions and kills the delegates the park waits on, after which the snapshot resumes `Lost`; say so.

**Coherence with `wake_read`.** ADR-002 D2's `wake_read` is a synchronous helped leaf that records one interaction and advances once (`ADR-002:233–240`, `:288–291`), with `ParkEntered`/`WakeReceived` appended and emitted (`:279–281`). D7 path 2 says the resumer "finds a resolved outcome … consumes it exactly once … and does not re-observe" (`ADR-003:340–343`) without saying whether the consumption goes through the leaf. If it bypasses the port, the resumed frame has a `WakeReceived` with no `WorldRequest` witness and no interaction, which the ADR-001 D2 gate reads as a gap (`ADR-001:422–425`). The fix is already in ADR-002: seed the resumed `WorldState.wakes` cursor with the decoded `WakeInput` and let the first `decide` after resume `Park` and call `wake_read`, which the scripted binding serves from the cursor (`ADR-002:272–276`). Then the leaf records, advances and is witnessed, and "exactly once" is the cursor being consumed.

**The request id.** That path re-issues a `ParkRequest` whose id is `session_id + generation + ordinal` (new generation), while the persisted `WakeInput.request_id` names the retired one; ADR-002 drops a reply whose `request_id` does not match (`ADR-002:239–240`). D7 says the stale request "is never re-issued; its `request_id` is retired" (`ADR-003:333–334`). Reconcile: the wake file is keyed by generation (the ADR says so, `:341–342`) and the resumer rewrites `request_id` to the re-issued request's id when it seeds the cursor, or the drop rule matches on `(session_id, wait_id)` for a resumed frame. Decide one.

**State machine.** The review asked for named states (`REVIEW-adr002-v2.1-verdicts-codex.md:153`); D7 describes them in prose. Name them.

## 9. Not decided: what must move before PLAN-003

Must be decided in v2 (PLAN-003 cannot be written without them):

1. **`Suspended` shape** (§3). Blocks D8 step 1.
2. **Per-run boot inputs in the envelope**, `task` first (§1, D1 correction 1). Blocks both halves of D6.
3. **Resume build order and the prompt source** (§6.3). Blocks D6 cross-process and the D5 digest check.
4. **Restart into another profile: refusal or accepted switch** (§7.2). Blocks the restart half of the issue and D8 step 3.
5. **Chain rule** (§5). Blocks D4's fixtures in step 1.
6. **`RequestClass` for `file_replace`** and the leaf module (§4). Blocks step 2.
7. **Outer manifest publish on a `Suspended` turn** (§4). Blocks step 2.
8. **`totals` after a resume** (§7.1). Blocks step 1's acceptance test if the status is asserted.

May stay open through PLAN-003 (D7 is unscheduled): cost/context exhaustion as suspensions; abort mid-provider-call; retention beyond three; the wake-consumption path and request-id rule (must be fixed before D7 is scheduled); the `ExecutionProgram` adapter; initial input under the suspended-child state (shared with ADR-002 D4).

Two bookkeeping items: ADR-002 is still v2.1 with D6 in its TL;DR (`ADR-002:4`, `:110`); the v3 edit ADR-003 describes (`ADR-003:368–369`) has not been made. And the D5 change to `run_id` adds a per-run clock read that the DST fixtures pinning `MOTOKO_SESSION_ID` env-read counts will see (`scripts/dst/seeded_generator_dst.ail:420`; `run_report_dst.ail:174`; `strict_replay_dst.ail:400`; `discovery_dst.ail:665`; `driver_plus_compose_dst.ail:990`; `program_persistence_dst.ail:147`, `:214–215`, `:650`); D8 should price the re-roll.

## 10. Coordinate audit

Every coordinate in the ADR's cross-reference list (`ADR-003:422–431`) and body, checked at `97827bf`.

| cited | verified | note |
|---|---|---|
| `session.ail:175–180` | yes | `TracedSessionResult` |
| `:383–429` | yes | `C2LoopState`; `provider: Ports` is `:389` |
| `:398` (ADR `:105`, "holds the live `Ports`") | **no** | `:398` is a comment line; the field is `:389` |
| `:709–730` | yes | note `nudges_used` derived at `:726` |
| `:2164–2168`, `:2171–2206` | yes | |
| `:2437`, `:2486` | yes | |
| `:2768`, `:2790`, `:2884–2888` | yes | append is `:2887` |
| `:3372` (abort/exit) | off by one | `:3373` |
| `:3387–3394` (restart, ADR `:63`, `:213`, `:299`) | **no** | `:3387–3389` is `model_change`; `restart` is `:3391–3399` |
| `:3416`, `:3418–3426` | yes | |
| `:3419–3423` (ErrorEvent) | approx | `:3421–3425` |
| `:3484–3532` | yes | ends `:3533` |
| `:3582–3586` | yes | but this is the outer id; the per-run id is `:3137–3139` |
| `:3597–3612`, `:3600` | yes | publish is `:3601` |
| `:350` (O1) | yes | `CompactionApplied` note |
| `:2706–2790` | yes | |
| `step_machine.ail:93–104` | yes | budget arm `:93–103` |
| `step_machine.ail:93` for "only reached with none" | weak | evidence is `decide` `:114–138` |
| `phase_vocab.ail:34–49`, `:690–704`, `:1155–1168` | yes | |
| `ext_world.ail:515`, `:543–553` | yes | |
| `ports.ail:806`, `:826`, `:850`, `:2556–2572` | yes | |
| `ports.ail:2562` for `scripted_file_write` | binding site | definition is `:1135–1143` |
| `ext/exit_manifest.ail:44–56`, `:182–205` | yes | |
| `config.ail:133–138` | yes | |
| `rpc.ail:218–237`, `:241–262`, `:302–342` | yes | |
| `rpc.ail:250–260` "names and ABI versions" | **no** | names only, `:260` |
| `dst_program.ail:227–237` | approx | type is `:229–238` |
| `dst_replay.ail:793–833` | yes | |
| `dst_invariants.ail:788–806` | yes | |
| `packages/motoko-ext-abi/types.ail:547` | yes | `[Msg]`, no `images` |
| `runtime-process.ts:337–389` | yes | `MOTOKO_SESSION_MS` at `:372` |
| `runtime-process.ts:754–760` | weak | that is `abort()`/`kill()`; it shows abort is a stdin message, not that the loop is not reading |
| `session-logger.ts:233–240` | yes | |
| `session-identity.ts:23–27` | yes | |
| `index.ts:513–519`, `:572–575`, `:820–827`, `:922–984`, `:938` | yes | respawn is `:951`; missing `:877–882`, `:918` |
| `herdr-agent-state.ts:295–301`, `:330–351` | yes | ends `:355` |
| `long_qwen_compaction_dst.ail:383–402`, `:513–532` | yes | |
| `ADR-001:439–445` | yes | |
| `derive.py` `HELPED`, `CALL_RE` | yes | `:94–105`, `:151–155`; `REQUEST_CLASS` at `:142` contradicts D3 |

Factual claims checked and found correct that are not coordinate-bound: the exit manifest is written temp-then-`mv` through `std/process` because `std/fs` has no rename at the pin (`exit_manifest.ail:44–46`, `:56–58`); `history_from_resume` has no caller but its test; the TUI ignores `run_summary` and `session_suspend` (not in `AgentEvent`); P2 has not landed (`WorldState` has no `ordinal`, `ports.ail:183–196`; `PLAN-001:360`).

## Required changes before PLAN-003

1. Replace the three-way `RunOutcome` with an additive `suspended: Option[Snapshot]` on `TracedSessionResult`, or enumerate the thirty match sites and define the bridge's `Ok`/`Err` mapping and `RunSummary.error` for a suspension against `outcome_agreement_findings` (`dst_invariants.ail:1375–1394`).
2. Add `task` and the other `c2_loop` inputs to the envelope (`session.ail:2407–2421`), define `cumulative` at capture, and reset `totals` on resume.
3. Rewrite the resume ordering against `rpc.ail:275–345`: where the prompt and budget of a resumed session come from, and what the digest check compares.
4. Resolve restart-into-profile against D5's refusal table (`runtime-process.ts:776–780`; `index.ts:931–934`).
5. Replace the checkpoint-chain clause with the whole-history digest (`phase_vocab.ail:39–48`, `:690–698`; `session.ail:2519`, `:2539`, `:2887`).
6. Give `file_replace` a `RequestClass` and a leaf module (`derive.py:124–142`; `ports.ail:32–34`; `exit_manifest.ail:66`); state the outer manifest behaviour on suspended turns (`session.ail:3416`, `:3601`) and the world at the abort/restart rows (`:3373`, `:3391–3399`, `:3419`, `:3611`).
7. Name `session.ail:3137–3139` as the per-run id site, fix `run_id` uniqueness, name the lease owner, correct the `rpc.ail:260` claim, and add the seven `error` consumers and the `AgentEvent` union to D2's wire list.
8. In D7, route the persisted wake through `wake_read` via the `wakes` cursor and reconcile the retired `request_id` with ADR-002's drop rule (`ADR-002:239–240`, `:272–276`).
9. Fix the coordinates in §10 (`:389`, `:3373`, `:3391–3399`, `:260`).
