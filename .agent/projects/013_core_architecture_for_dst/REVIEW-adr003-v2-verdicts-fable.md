# ADR-003 v2 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; unchanged since the v1 review, and the HEAD the ADR names at `ADR-003-session-snapshot-and-resume.md:14`)
Subject: `ADR-003-session-snapshot-and-resume.md` v2
Prior review: `REVIEW-adr003-verdicts-fable.md` (v1; nine required changes)

Every coordinate v2 cites was re-read at this HEAD. Coordinates unchanged from v1 were re-checked against the v1 audit; new ones were read. §5 is the audit.

## Overall verdict

**Accept with corrections; PLAN-003 can be written after the four items in §4 are settled.** All nine v1 changes are folded, and the two owner decisions (additive `suspended` field; restart-into-profile accepted and recorded) are consistent with the code and with each other. The residuals are smaller than v1's but three of them would still make PLAN-003 decide design while implementing:

1. **D8's step order opens a regression window.** Step 1 stops emitting `error` on max-steps (the outer `Err` arms are silent when `suspended` is `Some`, `ADR-003:272–274`), but the TUI's `run_suspended` case is step 3 (`:545–546`). Between the two, the only thing that unlocks plain input after a max-steps run is the `error` case (`src/tui/src/ui.ts:2752–2761` sets `taskDone = true`; `shouldLockPlainInput`, `:1790–1795`, `:4046–4049`), so a max-steps run would lock the operator out until the next process. Either the UI case lands in step 1 or step 1 keeps emitting `error` beside `run_suspended` until step 3.
2. **The ordinal arithmetic is off by one.** `c2_finalize` reads the clock through the port after everything else (`src/core/session.ail:1550`), and `ports.clock_now` is a helped `ClockRead` (`tools/driver_leaf_inventory/derive.py:96–97`) whose successor is threaded into the returned world (`:1554`). With the snapshot written before `c2_finalize` (`ADR-003:338–339`), the frame's `final` is `snapshot.world.ordinal + 2`, not `+ 1` (`:340–341`, `:436`).
3. **Two writers after all.** D3 makes the abort/restart rows host-written metadata updates (`ADR-003:353–355`) while D5 says "the child is the only snapshot writer while the host holds the lease" (`:418`). The TUI sends `abort` to a *running* child (`src/tui/src/index.ts:1006–1008`) and `restart` at any time (`:1017–1019`), so a host-side write can race a child that is about to write its own `TurnEnd` snapshot at the same generation.
4. **Generation lost its mechanism.** v1 had a write-time compare-and-swap; v2 keeps `Refusal::Generation` but describes only a host read before spawning (`ADR-003:408–411`), which compares the file with itself. Either state that the lease is the single-writer guarantee and `Generation` guards only the wake file (D7), or restore the read-compare-write and say which port performs it.

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT WITH CORRECTIONS** | Boot record and cumulative-at-capture are correct against `c2_loop` and `runtime_status_json`; `Refusal::Profile` in D4 contradicts D5's acceptance; `ext_artifacts` across a profile switch is undefined. |
| D2 | **ACCEPT WITH CORRECTIONS** | Additive field verified against the bridge and both agreement invariants; record order is now right; the herdr row of the wire table should be `blocked`, not `idle`; the only full literal (`session.ail:1554`) is unlisted. |
| D3 | **ACCEPT WITH CORRECTIONS** | `FileReplace`, `fs_atomic.ail` and the effect-row rule are sound; `+1` must be `+2`; the metadata-update rows need a writer rule that does not contradict D5 and cannot race a running child. |
| D4 | **ACCEPT** | Whole-history digest, head prefix and transcript validity are the right checks and the chain is correctly retired; one enum member to remove. |
| D5 | **ACCEPT WITH CORRECTIONS** | Host-owned lease and clock-free `run_id` are sound; the run-ordinal counter has no named home; `Generation` needs a mechanism; hostless resume is unaddressed. |
| D6 | **ACCEPT WITH CORRECTIONS** | Five-step order matches `rpc.ail`; head-prefix replacement is sound given the digest runs first; the flag path to the child is miscited and `--resume-force` needs a bare-flag arm; `run_model` source unstated. |
| D7 | **ACCEPT WITH CORRECTIONS** | Seeded cursor through `wake_read` closes the witness gap; the served wake must also be *recorded* under the recording adapter, and the live binding becomes a hybrid that reads a world cursor, which should be said. |
| D8 | **ACCEPT WITH CORRECTIONS** | The `error`-retirement window (item 1 above); `world_of_json_strict` in step 1 is rewritten by P2's fields in step 2. |

## 1. Disposition of the nine required changes

| # | v1 change | Disposition | Residual |
|---|---|---|---|
| 1 | Additive `suspended: Option[Snapshot]` or enumerate thirty sites | **Folded** (`ADR-003:267–274`, O6 `:186–188`) | `TracedSessionResult` is built as a full literal at `session.ail:1554`; it gains `suspended: None` there and in `c2_suspend`. "No match site changes" (`:558`) is right; "no literal changes" would not be. |
| 2 | `task` and boot inputs in the envelope; `cumulative` at capture; reset `totals` | **Folded** (`:208–209`, `:228–240`) | `boot` covers every `c2_loop` input not elsewhere (`session.ail:2407–2421`: `task`, `env_url`, `hybrid_tools`, `budget`, `ohmy_pi`, `max_cost_millicents`, `cost_rates`; `workdir` and `model` are in `compat`). `step_budget` is the conversation loop's parameter (`:3339`), fed from `budget.total` at `rpc.ail:351`; storing it is right. `cumulative` matches `:559`. |
| 3 | Resume order against the task-conditional build | **Folded** (`:461–477`) | The flags reach the child through `buildSupervisorArgs` (`runtime-process.ts:482–505`) and `apply_flag_value` (`config.ail:222–230`), not through `index.ts:587–622`, which is the TUI's *inbound* parser. `--resume-force` is a bare flag and the child's parser treats an unknown `--x` as `--x <value>` (`config.ail:236–239`); it needs the `--no-backend` arm (`:235`). `run_model` on a resume (`compat.model` vs `--model`) is not stated. |
| 4 | Restart into another profile: refusal or accepted switch | **Folded** as accepted (`:38–41`, `:425`, `:470–472`, `:478–480`) | D4's `Refusal` still lists `Profile(string)` (`:373–374`). A `ContinuationSnapshot` resumed into a new profile carries `ext_artifacts` and `telemetry` produced by the old extension set (`:219–220`); say they are reset on a profile switch. |
| 5 | Whole-history digest instead of the chain | **Folded** (`:381–388`) | None. The order (digest check, then head replacement on a profile switch) is implied by steps 2 and 4 of D6; make it explicit. |
| 6 | `RequestClass` for `file_replace`; leaf module; outer manifest on suspended turns; world at abort/restart | **Folded** (`:319–336`, `:346–355`) | The `+1` rule (§3.3). The metadata-update writer (§3.3). |
| 7 | Per-run id site; `run_id` uniqueness; lease owner; `rpc.ail:260`; seven consumers and `AgentEvent` | **Folded** (`:118–123`, `:396–418`, `:430–432`, `:287–304`) | The run ordinal "counts traced runs since the last snapshot" (`:402–403`) but no state holds that count: the conversation loop's parameters are `:3330–3345` and none is a counter. Herdr row (§3.2). `Generation` (§3.5). |
| 8 | Persisted wake through `wake_read`; `request_id` reconciliation | **Folded** (`:517–526`) | Recording under the recording adapter and the hybrid live binding (§3.7). |
| 9 | Coordinates `:389`, `:3373`, `:3391–3399`, `:260` | **Folded** (`:62–65`) | Two new miscitations (§5). |

The v1 review's own line references in the ADR are right: `REVIEW-adr003:105` is the "`Fail` arm has the loop state" paragraph (it starts at `:104`), `:111–120` is the match-site table, `:197–202` is §7.1's bullets.

## 2. Per-decision verdicts

### D1 — accept with corrections

Verified: the four-argument constructor and what it resets and derives (`session.ail:709–730`, `nudges_used` at `:726`); `provider: Ports` at `:389`; `c2_loop`'s inputs (`:2407–2421`); `RuntimeStatusCounts` and `runtime_status_counts_add` (`:431–437`, `:545–553`); the `prior_counts + trace` sum (`:559`); `totals` reset per run (`:712`), compared by the cost cap (`step_machine.ail:104`) and reported by `mk_run_summary` (`session.ail:1552`); `Msg` has no `images` (`packages/motoko-ext-abi/types.ail:547`) and `Message` does (`session.ail:3402–3408`).

Corrections:

1. Remove `Profile(string)` from D4's `Refusal` (`ADR-003:373–374`) or say what it refuses now that D5 accepts a profile change (`:425`).
2. On a profile switch, `ContinuationBody.ext_artifacts` and `telemetry` are the old runtime's (`:219–220`); state that a resume into a different profile resets `ext_artifacts` to `jo([])` as the constructor does (`session.ail:713`) and keeps `telemetry` (it is provider-side, not extension-side).
3. `boot.budget` is "stored *and* recomputed" (`:229–231`); say which the cross-process continuation runs under when they differ (the recomputed one, since the runtime and prompt are the recomputed ones).

### D2 — accept with corrections

Verified: `Fail` with `Internal` (`step_machine.ail:93–103`); `decision_fail_reason` (`session.ail:2164–2169`); the catalogue constant, test and header (`dst_fault_catalogue.ail:210`, `:825–829`, `:50–59`); `test_decision_fail_reason_mapping` (`session.ail:3705–3712`); `finish_reason_wire(TermMaxSteps) == "max_steps"` (`:3697`); the `error` event type carries only `message` (`runtime-process.ts:96`); `st` in scope at `:2437` inside `c2_loop` (`:2407–2437`), `trace_with_decision` at `:2433`; `decide`'s pending-tool arms precede `call_model_or_fail` (`step_machine.ail:114–138`).

**The additive field is sound.** `c2_fail` builds `Err({ code, message, retryable })` (`session.ail:2205`) and `c2_finalize` writes `error_msg` into the summary (`:1537`, `:1552`); `outcome_agreement_findings` needs `Err` with a non-empty `error` (`dst_invariants.ail:1385–1388`) and `done_agreement` fires only when a `DoneEvent` exists (`:1416–1424`), which a suspension has none of. The bridge is always `RunCompleted` (`dst_execution.ail:121–130`) and `completed_run` takes the `Result` unchanged (`dst_result.ail:130–137`). `RunSuspended` before `RunSummary` satisfies `after_summary` (`dst_invariants.ail:788–796`).

**The record order is right** (`ADR-003:283–286`): manifest, write, `RunSuspended{published}`, `c2_finalize`. Under P2 the publish returns `{ world, trace }` (`ADR-001:440–444`); `file_replace` takes that world; `RunSuspended` is appended to the returned trace; `c2_finalize` takes the write's successor. The row `c2_suspend` needs is the loop's (`session.ail:2422`), wider than `c2_fail`'s `{IO, Clock, Trace}` (`:2185`); say so, since `publish_turn_exit_manifest` needs `{AI, …, Trace}` (`:3501`).

**The seven-consumer table** (`:290–298`) matches the code at every row (`index.ts:517–519`, `:572–575`, `:877–882`, `:918` → `:959–970`; `ui.ts:2752–2761`; `ui.ts:2282` → `herdr-agent-state.ts:89–90`; `session-logger.ts:343–346`). Two corrections:

1. **Herdr row.** `HerdrReport.message` is shown "beside a blocked row" (`herdr-agent-state.ts:63`), and `blocked` is the state that turns the row red and satisfies `herdr agent wait --until blocked` (`:73–74`), which is exactly what a parent delegating to a Motoko child wants when that child is waiting for its operator. "`idle` with message" (`ADR-003:297`) drops the message and the wait signal. Map a suspension to `blocked` with the message. Either way `mapRunState` is an exhaustive switch over `MotokoRunState` (`:43`, `:81–91`, and the comment at `:40–41`), so a `suspended` member must be added to `MotokoRunState`, `RunState` (`ui.ts:790`) and `TranscriptState` (`session-logger.ts:5`).
2. **Headless exit.** In non-TTY mode the child-exit callback only closes the logger and stops the UI (`index.ts:885–889`); the non-zero code comes from the logger's event handler, so the plain/JSON rows are the whole story. Correct as written; note it so the plan does not add a second exit.

### D3 — accept with corrections

Verified: `Ports.file_write` row `{FS}` (`ports.ail:826`); `FileMutation` (`:630–634`); `scripted_file_write` (`:1135–1143`); `recording_file_write` and `FileWriteIdentity` (`:1629–1645`); `ports.ail` imports `std/fs` and `std/env` and not `std/process` (`:32–34`); `exit_manifest.ail` imports the extension runtime (`:66`) and does temp-then-`mv` at `:193–204`; `RequestClass` frozen at five with file mutations exempt (`derive.py:124–142`); growth rule (`PLAN-001:378–380`); three `Ports` literals (`ports.ail:2556–2572`; `long_qwen_compaction_dst.ail:383–403`, `:513–533`); loop rows carry `Process` (`session.ail:2422`, `:3346`); non-success runs reach `c2_finalize` without publishing (`:2429`, `:2437`, `:2758`, `:2765`, `:2873`) and the outer loops publish after (`:3416`, `:3601`); the conversation loop threads no world (`:3380–3386`, `:3419`, `:3426`, `:3611`); the between-turn `abort` is reachable only from the read at `:3367`.

**`FileReplace`, `fs_atomic.ail`, effect row.** Sound. A seventh variant follows PLAN-001's rule; `fs_atomic.ail` importing only `std/fs` and `std/process` breaks the cycle (`ports.ail` imports it for the production binding; `exit_manifest.ail` imports it for the manifest). Declaring the scripted adapter with the wide row (`ADR-003:315–317`) is the safe choice given nothing in the tree establishes narrowing.

**Ordinal-before-write: wrong by one.** The write is "before `c2_finalize` writes `RunSummary`" (`:338–339`), and `c2_finalize` then performs `ports.clock_now(world)` (`session.ail:1550`), a helped `ClockRead` (`derive.py:96–97`) whose successor becomes the returned world (`:1554`). So the frame's `final` is the snapshot's ordinal plus **two** (the write, then the clock). D3 (`:340–341`) and D5 (`:436`) say plus one. The resumed frame should cite `final` by reading it from the ledger, not by arithmetic on the snapshot; then the constant does not matter, but the ADR must not pin the wrong one in a fixture.

**Metadata-update rows.** The reasoning (no turn world in the conversation loop, so no fresh snapshot) is right. The mechanism is not:

- D3 says the update "goes through the host" (`ADR-003:353–355`); D5 says "the child is the only snapshot writer while the host holds the lease" (`:418`). One of them has to give.
- The host's `abort()` is sent to a *running* child (`index.ts:1006–1008`, guarded by `!preWarmIdle`), and `restart()` at any moment (`:1017–1019`; `runtime-process.ts:776–780` sets `restartPending` before sending). A host write at that moment can race the child's `TurnEnd` write at the same generation. The child-side `abort`/`exit` arm at `session.ail:3373` is reached only when the abort lands between turns.
- The D3 table says the restart update is "written before `SessionSuspend`" (`:348`); `SessionSuspend` is emitted by the child (`:3394–3397`), so "before" can only mean "at `restart()` time on the host", which is the racing case.

Fix: the child writes the `Restart` update itself at `:3391–3399` before `SessionSuspend` (it has the current snapshot's generation and reason in memory and the loop is between turns there), and the host writes the `Abort` update only from its exit handler, after the child has exited. That keeps one writer at a time and matches D5.

### D4 — accept

Verified: `history_digest` is `digest_messages` over the whole history (`phase_vocab.ail:63–65`); `system_is_head_prefix` (`:40`, `:75`); `history_valid_transcript` (`:71–73`); the chain's base case (`:692–694`) and the appends after every checkpoint (`session.ail:2887`, `:3409`); `world_of_json` and its nested accessors are total (`ext_world.ail:543–553`). Carrying `[CheckpointInfo]` as information is the right retirement. The only correction is the `Profile(string)` member (D1 correction 1).

### D5 — accept with corrections

Verified: `derive_session_id` prefers `MOTOKO_SESSION_ID` (`session.ail:1441–1442`); per-run site `:3137–3139`; outer site `:3586`; every event stamped (`:335–341`); child env lacks the id (`runtime-process.ts:337–389`, `:372`); logger stem (`session-logger.ts:233–238`); one `SessionLogger` and one `RuntimeProcess` per spawn (`index.ts:901–907`); process-exit hooks (`exit-actions.ts:425–426`; `herdr-agent-state.ts:295–301`); the DST fixtures that pin the env read (`seeded_generator_dst.ail:420`; `run_report_dst.ail:174`; `strict_replay_dst.ail:400`; `discovery_dst.ail:665`; `driver_plus_compose_dst.ail:990`; `program_persistence_dst.ail:147`, `:214–215`, `:650`); `rpc.ail:260` emits names.

**Host-owned lease: sound.** The TUI outlives every child (`runtime-process.ts:362–371` says so for `MOTOKO_SESSION_MS`), it already owns the session clock, and its exit hooks already run on every normal exit and on `SIGINT`/`SIGTERM` (`herdr-agent-state.ts:292–302`). A `SIGKILL` leaves a stale lease; the dead-pid rule covers it.

**`run_id`: sound**, and clock-free keeps the DST env-read counts. Correction: the run ordinal needs a home. The conversation loop threads `prior_counts` (`session.ail:3345`) and nothing else that survives a turn; the counter is a new parameter beside `suspended` (D6), and the ADR should say the traced run receives `run_id` as an argument rather than deriving anything.

**Generation.** v1 asked for a compare-and-swap at the write; v2's text (`ADR-003:408–411`) is a host read of the on-disk generation before spawning a child that will decode the same file, which cannot mismatch except under a concurrent writer that the lease already excludes. Decide: with a host-owned lease the CAS is redundant and `Refusal::Generation` guards the wake file only (D7, `:518`), or keep a read-compare-write in `file_replace`'s caller and name it. The first is simpler and is what the rest of D5 already implies.

**Hostless resume.** `rpc.main` can be run without the TUI (`rpc.ail:355–359`); step 1 of D6 is host-only (`:464`). Say whether a child started with `--resume` and no lease refuses, proceeds without a lease, or writes one itself.

### D6 — accept with corrections

Verified: the empty-task guard (`session.ail:3597–3598`); `await_first_task` (`rpc.ail:218–239`); the task-independent warming and the task-conditional build (`:275–276`, `:296`, `:319`, `:342–345`); runtime built before any task (`:247`); `InvocationConfig` (`config.ail:133–138`); the TUI's inbound parser (`index.ts:587–622`); per-turn `step_idx` and the wire `current_step` (`session.ail:711`, `:573`); `steps_executed_so_far` (`:576`); respawn (`index.ts:951`); `restart(newProfile)` (`runtime-process.ts:776–780`; `index.ts:931–934`).

**The five-step order is consistent with `rpc.ail`.** Steps 3–4 reuse `init_runtime_with_config` (`:247`), `compute_budget_plan` (`:319`) and `dispatch_build_system_prompt` (`:342`) with `snapshot.boot.task` in place of `first.task`; `await_first_task` is bypassed. The digest compared is `system_prefix_digest_for` over the pinned system prefix (`phase_vocab.ail:253–255`; pinned = `take_system_prefix`, `:85–90`, `:135–137`), so the resumed prompt's digest must be computed over `[system_msg]` the same way; the ADR should name the function.

**Head-prefix replacement on a profile switch: sound**, provided the whole-history digest is checked in step 2 before the replacement in step 4 (the order the steps give). `system_is_head_prefix` admits several system messages at the head (`phase_vocab.ail:85–90`); the initial history has one (`rpc.ail:344–345`); say the replacement replaces the *whole* prefix with the one new message.

Corrections:

1. The flags reach the child via `buildSupervisorArgs` (`runtime-process.ts:482–505`) and are parsed by `apply_flag_value` (`config.ail:222–230`); `index.ts:587–622` is the wrong citation. `--resume-force` needs a bare-flag arm like `--no-backend` (`config.ail:235`), or the parser will consume the task as its value (`:236–239`).
2. State `run_model` on a resume: `--model` override if present, else `compat.model` (which then triggers no `model_change`).
3. `ext_artifacts` on a profile switch (D1 correction 2).
4. The restart respawn "passes `--resume <session_id>` and the new profile" (`:478–479`); the exit handler already sets `profile` from `pendingRestart` before respawning (`index.ts:931–934`), so `--profile` flows through `buildSupervisorArgs` unchanged; only `--resume` is new there.

### D7 — accept with corrections

Verified: exit-handler branch order (`index.ts:928–985`); exit actions and reporter release are process-exit hooks (`exit-actions.ts:425–426`; `herdr-agent-state.ts:295–301`); herdr server restart kills delegates (`session-identity.ts:23–27`); ADR-002's `wake_read` leaf, drop rule and `wakes` cursor (`ADR-002:233–240`, `:272–276`, `:288–291`); no `wake_read`/`ParkRequest` at HEAD.

**Seeded cursor with `request_id` rewrite: sound.** The resumed run parks under `run_id + park ordinal 0`, the seeded `WakeInput` carries that id, `wake_read` serves it from the cursor, records, advances, is witnessed, and the drop rule is untouched (`ADR-003:519–526`). Path 1 (crash resume, re-park with a new request, re-observe) is the recovery path and is consistent with the one-owner rule.

Corrections:

1. **Recording.** Under the recording adapter the served wake must be recorded as a `WakeInteraction` (`ADR-002:274`) so a replay of the resumed run reproduces it; say the recording binding wraps the cursor read as `recording_approval` wraps `scripted_approval` (`ports.ail:1718–1747`).
2. **Hybrid live binding.** "The production binding serves from the `wakes` cursor when it is non-empty before emitting a `wake_request`" (`:521–522`) is a live binding that consults a world queue, which no live binding does today (`live_ports` overrides the world-served defaults with ambient ones, `ports.ail:2568–2570`). It is the right design for exactly-once; name it as a deliberate exception so the scanner's live/deterministic split is not surprised.
3. The state list (`:500–503`) has no `Lost`/`Aborted` exits from `SuspendedWaiting`; add them (TUI quit, herdr restart, `abort` while suspended).

### D8 — accept with corrections

1. **The `error` window** (overall item 1). Move the `ui.ts` `run_suspended` case, the `AgentEvent` member and the transcript row into step 1, or emit both `error` and `run_suspended` until step 3. The headless loggers can wait for step 3 only if `error` is still emitted, since they exit on it (`index.ts:517–519`, `:572–575`).
2. **`world_of_json_strict` in step 1** (`:539`) is written against a `WorldState` that P2 Part 1 then extends with `ordinal` and `pending` (`PLAN-001:370–375`; no `ordinal` at HEAD, `ports.ail:183–196`). It is not needed until a snapshot is read from disk (step 3). Move the world decoder to step 2 or 3; keep the `[Message]` and envelope codecs in step 1.
3. Step 2's gate ("a mutant that drops its witness goes red", `:543–544`) is the right gate; add the `+2` frame check as its second assertion.

## 3. Soundness of the new pieces

### 3.1 D1: boot record and cumulative-at-capture

Sound. Every `c2_loop` input (`session.ail:2407–2421`) is either in `boot`, in `compat` (`workdir`, `model`), or in the body. `cumulative = runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))` is the exact expression `runtime_status_json` evaluates (`:559`), so the resumed run's `steps_executed_so_far` (`:576`) continues without a trace. Resetting `totals` restores per-run cost-cap semantics (`step_machine.ail:104`) and keeps `RunSummary.input_tokens` per run (`session.ail:1552`).

### 3.2 D2: record order and wire table

Record order: sound (D2 above). Wire table: complete, with the herdr row to be changed to `blocked` and three state enums to grow (D2 corrections). One consumer the table can drop: `index.ts:918`'s flag is set on `error` and read only when the child exits (`:959`); with the child alive after a suspension the row's "not set" is right, but a *headless* child does exit after the run (`session.ail:3357`; `rpc.ail:355–359`) and reaches the non-TTY callback (`index.ts:885–889`), which has no branch on it. Correct as stated; the note is that headless never reaches `:959`.

### 3.3 D3: class, module, row, ordinal, metadata rows

`FileReplace`: sound. `fs_atomic.ail`: sound. Row: sound. Ordinal-before-write: the *rule* (the snapshot cannot hold its own witness) is right; the *constant* is wrong (`+2`). Metadata rows: the reasoning is right, the writer is wrong (D3 corrections).

### 3.4 D4: whole-history digest

Sound. `digest_messages` over the retained messages detects any change to the file's history bytes; `system_is_head_prefix` and `history_valid_transcript` cover shape. The chain is correctly retired with the reason (`phase_vocab.ail:692–694`; `session.ail:2887`).

### 3.5 D5: host-owned lease and `run_id`

Lease: sound. `run_id`: sound but homeless (D5 corrections). `Generation`: needs a mechanism or a narrower claim (D5 corrections).

### 3.6 D6: five-step order and head-prefix replacement

Sound against `rpc.ail`, with the citation and bare-flag corrections. One ordering note: step 3 builds the runtime for the *invoked* profile before step 4 compares prompt digests; on a same-profile resume with a changed `ext_set_digest` (refused, `ADR-003:426`) the runtime has already been built. That is today's shape too (`rpc.ail:247` runs before the task) and costs nothing but a refused exit.

### 3.7 D7: seeded cursor

Sound (D7 above), with recording and the hybrid-binding note.

## 4. Not decided: what must still move before PLAN-003

Must be decided in the ADR (each would otherwise be decided by the plan):

1. **D8 step 1's wire behaviour** on max-steps before step 3 lands (§2 D8.1).
2. **The metadata-update writer**: child at `session.ail:3391–3399` for `Restart`, host after child exit for `Abort` (§2 D3).
3. **`Generation`'s mechanism or scope** (§2 D5).
4. **`ext_artifacts` on a profile switch** (§2 D1.2).

Small enough to fix in place without a decision: `+2`; `Refusal::Profile`; the flag citations and the bare-flag arm; `run_model`; the herdr row; the run-ordinal home; hostless resume; the recording of a served wake. None of the items the ADR leaves in "Not decided" (`ADR-003:576–588`) blocks PLAN-003.

Bookkeeping unchanged from v1: ADR-002 is still v2.1 with D6 in its TL;DR (`ADR-002:4`, `:110`); the v3 edit (`ADR-003:552–553`) has not been made.

## 5. Coordinate audit

All coordinates in the cross-reference list (`ADR-003:611–627`) and the body, at `97827bf`.

| cited | verified | note |
|---|---|---|
| `session.ail:175–180`, `:335–341`, `:383–429`, `:389` | yes | |
| `:545–560`, `:573`, `:576` | yes | `runtime_status_counts_add` `:545–553`; `runtime_status_json` from `:556` |
| `:709–730`, `:711–712`, `:726`, `:728` | yes | |
| `:1440–1447`, `:1441–1442` | yes | |
| `:1537`, `:1552` | yes | `c2_finalize`'s `error_msg` and `mk_run_summary`; the clock read the ADR does not cite is `:1550` |
| `:2155–2169`, `:2171–2185`, `:2407–2437`, `:2429`, `:2486` | yes | |
| `:2741–2749`, `:2758`, `:2765`, `:2768`, `:2790`, `:2873`, `:2887` | yes | |
| `:3137–3139` | yes | |
| `:3330–3346`, `:3367`, `:3373`, `:3380–3386`, `:3391–3399` | yes | |
| `:3402–3408`, `:3409`, `:3416`, `:3419–3426`, `:3421–3426` | yes | |
| `:3484–3533`, `:3586`, `:3597–3611`, `:3606–3611`, `:3697`, `:3705–3712` | yes | |
| `:350`, `:2706–2790`, `:2768–2780` | yes | |
| `step_machine.ail:93–103`, `:93–104`, `:104`, `:114–138` | yes | |
| `phase_vocab.ail:39–48`, `:40`, `:42–47`, `:71–73`, `:690–703`, `:692–694`, `:1155–1170` | yes | |
| `ext_world.ail:515`, `:543–553` | yes | |
| `ports.ail:32–34`, `:630–634`, `:826`, `:850`, `:1135–1143`, `:1629–1645`, `:2556–2572` | yes | |
| `ext/exit_manifest.ail:44–56`, `:66`, `:182–205`, `:196–204` | yes | the `mv` is `:200–203`; the tmp write `:193–196` |
| `dst_fault_catalogue.ail:50–59`, `:210`, `:825–829` | yes | |
| `dst_execution.ail:121–130`, `:128–130` | yes | |
| `dst_result.ail:130–137` | yes | |
| `dst_invariants.ail:788–806`, `:1385–1388` | yes | |
| `dst_program.ail:229–238`, `dst_replay.ail:793–833` | yes | |
| `config.ail:133–138` | yes | the parser the ADR needs is `:222–247` |
| `rpc.ail:218–237`, `:241–247`, `:241–262`, `:260`, `:275–276`, `:296`, `:296–345`, `:319`, `:342–345` | yes | |
| `derive.py:94–105`, `:124–142`, `:142`, `:151–155` | yes | |
| `packages/motoko-ext-abi/types.ail:547` | yes | |
| `runtime-process.ts:58–103`, `:96`, `:337–389`, `:372`, `:776–780` | yes | |
| `session-logger.ts:233–238`, `:343–346` | yes | |
| `session-identity.ts:23–27` | yes | |
| `exit-actions.ts:425–426` | yes | |
| `herdr-agent-state.ts:89–90`, `:295–301` | yes | `HerdrReport.message` at `:63` contradicts the `idle`-with-message row |
| `ui.ts:2282`, `:2752–2761` | yes | |
| `index.ts:517–519`, `:572–575`, `:877–882`, `:901–907`, `:918`, `:922–985`, `:931–934`, `:951`, `:959–970` | yes | |
| `index.ts:587–622` as "passes them through to the child" (`ADR-003:459–460`) | **no** | that is the TUI's inbound flag parser; the child's argv is built at `runtime-process.ts:482–505` |
| `env-server.ts` (no line, `ADR-003:303`) | approx | the note is at `env-server.ts:415–420` |
| `ADR-001:373–374`, `:386–389`, `:396–404`, `:422–425`, `:439–445`, `:442–443` | yes | |
| `PLAN-001:376–381`, `:378–380` | yes | |
| `REVIEW-adr003:105`, `:111–120`, `:197–202` | yes | `:105` is `:104` |

Claims checked that are not coordinate-bound: `--resume-force` would be mis-parsed by the child's `flag :: value` arm (`config.ail:236–239`) without a bare-flag case; the TUI's `abort()` targets a running child (`index.ts:1006–1008`); the non-TTY child-exit callback does not exit the process (`index.ts:885–889`); `HerdrState` is `idle | working | blocked | unknown` (`herdr-agent-state.ts:46`).

## Required changes before PLAN-003

1. D8: land the `run_suspended` UI case, the `AgentEvent` member and the transcript row in step 1, or keep emitting `error` beside `run_suspended` until step 3 (`ui.ts:2752–2761`; `index.ts:517–519`, `:572–575`).
2. D3/D5: correct `final` to `snapshot.world.ordinal + 2` or define it as read from the ledger (`session.ail:1550`, `:1554`; `derive.py:96–97`).
3. D3/D5: one writer at a time — child writes `Restart` at `session.ail:3391–3399`, host writes `Abort` from the exit handler after child exit; delete "goes through the host" for restart (`ADR-003:353–355`) and reconcile with `:418` (`index.ts:1006–1008`, `:1017–1019`).
4. D5: state `Generation`'s mechanism or narrow it to the wake file.
5. D1/D6: reset `ext_artifacts` on a profile switch; remove `Refusal::Profile`.
6. D6: cite `runtime-process.ts:482–505` and `config.ail:222–247` for the flag path; add a bare-flag arm for `--resume-force`; state `run_model`; name `system_prefix_digest_for` as the compared digest.
7. D2: change the herdr row to `blocked` with the message and add `suspended` to the three state enums (`herdr-agent-state.ts:43`, `:63`, `:73–74`; `ui.ts:790`; `session-logger.ts:5`); list the literal at `session.ail:1554`.
8. D5: give the run ordinal a home and say what a hostless `--resume` does.
9. D7: record the served wake under the recording adapter; name the hybrid live binding; add `Lost`/`Aborted` exits to the state list.
10. D8: move `world_of_json_strict` after P2's fields land.
