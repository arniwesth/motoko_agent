# ADR-003 v3 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; unchanged since the v1 and v2 reviews and the HEAD the ADR names at `ADR-003-session-snapshot-and-resume.md:19`)
Subject: `ADR-003-session-snapshot-and-resume.md` v3
Prior reviews: `REVIEW-adr003-verdicts-fable.md` (v1), `REVIEW-adr003-v2-verdicts-fable.md` (v2; ten required changes)

Every coordinate v3 cites was checked at this HEAD; the ones carried from v1/v2 against those audits, the new ones read. §6 is the audit.

## Overall verdict

**Accept with corrections. PLAN-003 is blocked by one design gap, not by the four v2 items, which are now decided coherently.** All ten v2 changes are folded; two are mis-folded in a way that matters:

1. **The loop cannot know a snapshot's generation.** D5 threads `run_ordinal` through the conversation loop and resets it "by every snapshot write" (`ADR-003:482–486`); D3 has the child write the `Restart` update from a generation it "holds in memory" (`:421`); D5 says the resumed run's first write is `generation + 1` (`:492–493`). But snapshot writes happen *inside* the traced run (`c2_suspend`, the success arm at `session.ail:2486`), and the only thing the run returns about them is `suspended: Option[Snapshot]`, set on budget exhaustion alone (`ADR-003:333–334`). After a successful turn the conversation loop sees `Ok(history)` (`session.ail:3419`) and nothing else, so it cannot reset `run_ordinal`, cannot learn the `TurnEnd` generation, and cannot write a `Restart` update at `generation + 1`. `TracedSessionResult` needs a second additive field, `written: Option[{ generation, reason, published }]`, or `suspended` must become `snapshot: Option[Snapshot]` set on every write. This is D5's and D3's mechanism and must be decided in the ADR.
2. **`final` "read from the ledger's frame record" does not exist.** ADR-001's frames are two lines the *DST script* prints from `run.world.ordinal` (`ADR-001:415–419`); the ledger carries `WorldRequest` witnesses, not frame records (`:396–398`), and a live run prints no frame at all. The resumed child holds the snapshot, not the previous run's ledger. So D3 (`ADR-003:413–415`) and D5 (`:527–528`) name a read that no process can perform. The fix is the one the ADR almost says: the resumed frame opens at `snapshot.world.ordinal`, `SessionResumed` records it, and step 2's gate asserts the previous frame's `final == that + 2`. ADR-001 already permits equal or lower ordinals across frames (`:426–427`), so this is a new cross-frame assertion, not a violation.

One host-side residual that is not a design question: the lease removal rides on "the same process-exit hook that releases the reporter" (`ADR-003:501–503`), but `initHerdrReporter` returns before registering any hook when Motoko is not in a herdr pane (`src/tui/src/herdr-agent-state.ts:278–280`, hooks at `:295–301`). The lease needs its own unconditional `exit`/`SIGINT`/`SIGTERM` registration, on the pattern of `initExitActions` (`src/tui/src/exit-actions.ts:425–428`).

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT** | Boot record, cumulative-at-capture, `totals` reset and the profile-switch `ext_artifacts` rule are all consistent with the constructor and the loop. |
| D2 | **ACCEPT WITH CORRECTIONS** | Wire table, enum growth and herdr `blocked` are right; the additive field must also report non-suspension writes (item 1). |
| D3 | **ACCEPT WITH CORRECTIONS** | Class, module, row, `+2` and the writer rule are sound; "`final` from the ledger" must become "the resumed frame opens at `snapshot.world.ordinal`" (item 2); the `Restart` update needs the generation from item 1 and a rule for "no snapshot yet". |
| D4 | **ACCEPT** | Unchanged from v2 apart from the enum, which is now consistent with D5. |
| D5 | **ACCEPT WITH CORRECTIONS** | `run_id` and the narrowed generation are coherent; the `run_ordinal` reset and the lease hook are mis-folded (items 1 and the hook). |
| D6 | **ACCEPT** | Bare-flag arm, `run_model`, whole-prefix replacement, digest-before-replace, respawn path: all verified against `config.ail`, `rpc.ail`, `runtime-process.ts`. |
| D7 | **ACCEPT** | Named bindings, recording, `Lost`/`Aborted` exits and the `WakeGeneration` check are consistent with ADR-002 D2; unscheduled. |
| D8 | **ACCEPT WITH CORRECTIONS** | Step 1's headless-only `error` is coherent; step 1's envelope codec needs a stated world codec until step 2; step 2's gate should assert `+2` against the resumed frame's opening ordinal, not a ledger read. |

## 1. Disposition of the ten required changes

| # | v2 change | Disposition | Residual |
|---|---|---|---|
| 1 | Land the UI case, `AgentEvent` member and transcript row in step 1, or keep emitting `error` until step 3 | **Folded** (`ADR-003:651–661`) | Coherent (§3.1). Step 1's envelope codec has no world decoder until step 2 (§2 D8). |
| 2 | `final = snapshot.world.ordinal + 2` or read from the ledger | **Mis-folded** (`:410–415`, `:527–528`) | There is no ledger frame record and the child cannot read the host's JSONL; the `+2` reasoning is right and should be the rule (§3.3, §4.3). |
| 3 | Child writes `Restart`, host writes `Abort` after child exit | **Folded** (`:421–422`, `:425–433`) | The child's generation source is unstated (item 1); "no snapshot yet" case unstated (§4.2). |
| 4 | `Generation`'s mechanism or scope | **Folded** (`:492–496`) | Coherent (§3.3). |
| 5 | Reset `ext_artifacts` on a profile switch; remove `Refusal::Profile` | **Folded** (`:285–287`, `:449–453`, `:571`) | None. |
| 6 | Flag path citations, bare-flag arm, `run_model`, `system_prefix_digest_for` | **Folded** (`:549–556`, `:561–567`) | None. |
| 7 | Herdr row `blocked`; `suspended` in three enums; the literal at `:1554` | **Folded** (`:359`, `:362–369`, `:331–333`) | None. |
| 8 | Run-ordinal home; hostless resume | **Partly folded** (`:482–486`, `:504–507`) | The home is named but the reset signal does not reach it (item 1). Hostless is addressed; the lease hook it depends on is conditional (§4.2). |
| 9 | Record served wake; name the hybrid live binding; `Lost`/`Aborted` exits | **Folded** (`:600–607`, `:627–636`) | None. |
| 10 | Move `world_of_json_strict` after P2's fields | **Folded** (`:653`, `:664–668`) | Step 1's envelope round trip must say which world codec it uses meanwhile (§2 D8). |

The ADR's references into the v2 review are right: "§2 D3 the `+2` and writer arguments, §2 D5 the generation argument, §5 the coordinate audit" (`ADR-003:728–729`) name the sections that carry those arguments.

## 2. Per-decision verdicts

### D1 — accept

Verified: the constructor's resets and derived `nudges_used` (`session.ail:709–730`, `:726`); `ext_artifacts: jo([])` at `:713`; `c2_loop`'s inputs (`:2407–2421`); `step_budget` as the conversation loop's parameter (`:3339`) fed from `budget.total` (`rpc.ail:351`); `runtime_status_counts_add` and the `prior_counts + trace` sum (`session.ail:545–553`, `:559`); `totals` per run (`:712`, `step_machine.ail:104`, `session.ail:1552`); `Msg` without `images` (`packages/motoko-ext-abi/types.ail:547`) vs `Message` with (`session.ail:3402–3408`). The "stored vs recomputed `budget`" rule (`ADR-003:281–284`) is now explicit and consistent with D6 step 4. Nothing to correct.

### D2 — accept with corrections

Verified again: `Fail` with `Internal` (`step_machine.ail:93–103`); the catalogue constant, test and header (`dst_fault_catalogue.ail:210`, `:825–829`, `:50–59`); the mapping test (`session.ail:3705–3712`); `finish_reason_wire(TermMaxSteps)` (`:3697`); the `error` event type (`runtime-process.ts:96`); `outcome_agreement_findings` (`dst_invariants.ail:1385–1388`) and `done_agreement` (`:1416–1424`); the bridge (`dst_execution.ail:121–130`); the one literal (`session.ail:1554`); `c2_suspend`'s row against `c2_fail`'s (`:2422`, `:2185`, `:3501`); the seven consumers and the three enums (`index.ts:517–519`, `:572–575`, `:877–882`, `:918`, `:959–970`, `:885–889`; `ui.ts:2752–2761`, `:2282`, `:790`; `herdr-agent-state.ts:43`, `:63`, `:73–74`, `:81–91`, `:89–90`; `session-logger.ts:5`, `:343–346`).

Correction: item 1 of the overall verdict. `suspended: Option[Snapshot]` is the right shape for the in-process resume; D3 and D5 additionally need every write's `{ generation, reason, published }` back in the loop. Add `written: Option[SnapshotWritten]` beside it (additive, `None` in the `:1554` literal), set by the success arm and by `c2_suspend`. The `RunSuspended` record already carries the same three fields (`ADR-003:345`); the loop needs them as a value, not as a wire event.

One observation in the ADR's favour that it does not state: no DST fixture sees the retired `error` event. The outer `ErrorEvent` emits are outside the traced entry point (`session.ail:3421–3425`, `:3606–3610`), and deterministic runs drive the traced entry directly and never reach the conversation loop (`:3359–3366`). The parity and vocabulary gates move only for the two new variants.

### D3 — accept with corrections

Verified: `Ports.file_write` row (`ports.ail:826`); `FileMutation` (`:630–634`); scripted and recording writes (`:1135–1143`, `:1629–1645`); `ports.ail` imports (`:32–34`); `exit_manifest.ail` imports the runtime (`:66`) and does temp-then-`mv` (`:193–204`); `RequestClass` and exempt fields (`derive.py:124–142`); growth rule (`PLAN-001:378–380`); three literals (`ports.ail:2556–2572`; `long_qwen_compaction_dst.ail:383–403`, `:513–533`); `c2_finalize`'s clock read and threaded successor (`session.ail:1550`, `:1554`); `ports.clock_now` is helped (`derive.py:96–97`); the outer publishes (`:3416`, `:3601`); the loop threads no world (`:3380–3386`); `restart` at `:3391–3399` with `SessionSuspend` at `:3394–3397`; the between-turn `abort` at `:3373` behind the read at `:3367`; the host's `abort()` targeting a running child (`index.ts:1006–1008`) and `restart()` (`:1017–1019`).

**Writer rule: coherent.** The child at `:3391–3399` is between turns, so no `TurnEnd` write is in flight; the host's `Abort` write happens in the exit handler after the child is gone, on both the `else` and the `interrupted` paths (`index.ts:953–958`, `:980–985`). The restart write is direct file IO from the conversation loop, whose row has `FS` and `Process` (`:3346`), and `CALL_RE` matches only `receiver.method(` forms (`derive.py:151–155`), so a plain `replace_atomic(...)` call is invisible to the scanner as the ADR says (`ADR-003:431–433`). Two gaps:

1. The child "holds the last snapshot's generation in memory" (`:421`) only if the traced run returns it (overall item 1).
2. If no snapshot has been written yet (first turn fails with a non-budget error, then `restart`), there is no file to update. Say the child writes a fresh `TurnSnapshot` from the loop's `history` and `provider.world` (the pre-turn world, which is all it has), or writes nothing and the respawn starts clean.

**`final`: mis-folded** (overall item 2). Restate D3's paragraph (`:409–415`) and D5's seam (`:527–528`): the snapshot's `world.ordinal` is the value before its own write; the resumed frame *opens* at that value and `SessionResumed` records it as `from_ordinal`; step 2's gate asserts, for a run that snapshots then finalises, `final == from_ordinal + 2`. No ledger read, no fixture constant elsewhere.

### D4 — accept

Verified: `history_digest` is `digest_messages` (`phase_vocab.ail:63–65`); `system_is_head_prefix` (`:40`); `history_valid_transcript` (`:71–73`); the chain's base case (`:692–694`); the appends (`session.ail:2887`, `:3409`); total accessors (`ext_world.ail:543–553`). The `Refusal` enum (`ADR-003:450–452`) now lists `Leased`, `Workdir`, `ExtSet`, `Prompt`, `WakeGeneration` and no `Profile`, matching D5's table. Note only that `Leased` is decided by the host before spawning (`:558`) and by the child in the hostless case; keeping it in the child's enum is fine because the child is the one that refuses in that case.

### D5 — accept with corrections

Verified: `derive_session_id` (`session.ail:1440–1447`); per-run and outer id sites (`:3137–3139`, `:3586`); stamping (`:335–341`); child env (`runtime-process.ts:337–389`, `:372`); the TUI outlives its children (`:362–371`); one logger and process per spawn (`index.ts:901–907`); `rpc.main` (`rpc.ail:355–359`); the DST fixtures pinning the env read (`seeded_generator_dst.ail:420`; `run_report_dst.ail:174`; `strict_replay_dst.ail:400`; `discovery_dst.ail:665`; `driver_plus_compose_dst.ail:990`; `program_persistence_dst.ail:147`, `:214–215`, `:650`); `rpc.ail:260` emits names.

**`run_id` as an argument: sound.** The traced run derives nothing new; `derive_session_id` still runs at `:3137` (so the DST env-read counts hold) and returns the forwarded id. `<session_id>.g<generation>.r<ordinal>` is unique as long as the ordinal resets on every write and the loop knows when a write happened, which is overall item 1.

**Narrowed generation: coherent.** With one lease holder and one child at a time, the file has one writer; a stale wake from an earlier park is the only cross-generation hazard, and `WakeGeneration` guards it (`ADR-003:495–496`, `:622–623`).

**Lease: sound in shape, mis-cited in mechanism.** `initHerdrReporter` returns at `herdr-agent-state.ts:280` when not in a herdr pane; the `exit`/`SIGINT`/`SIGTERM` hooks at `:295–301` exist only inside one. Outside herdr, no hook releases anything, so "the same process-exit hook" (`ADR-003:501–503`) would leave the lease behind on every plain exit. Register the lease removal unconditionally, with its own signal handlers that re-raise as the reporter's do (`:297–301`); `initExitActions` is the unconditional precedent (`exit-actions.ts:425–428`). `MOTOKO_LEASE_HELD` is a new key in the `buildChildEnv` allowlist (`runtime-process.ts:343–389`); say so.

**Hostless: coherent.** A direct `rpc.main` with `--resume` and no `MOTOKO_LEASE_HELD` takes the lease with its own pid and removes it on return (`ADR-003:504–507`); without `--resume` it takes none, as today. The one case the text does not cover: a hostless resume that crashes leaves a dead-pid lease, which `--resume-force` clears (`:508–509`). Fine.

### D6 — accept

Verified: `buildSupervisorArgs` builds the child argv (`runtime-process.ts:482–505`); `parse_cli_args_rec`'s `--no-backend` bare arm and `flag :: value` arm (`config.ail:235`, `:236–239`); `apply_flag_value` (`:222–230`); the task-independent warming and task-conditional build (`rpc.ail:275–276`, `:296`, `:319`, `:342–345`); runtime built at `:247`; `system_prefix_digest_for` over the pinned prefix (`phase_vocab.ail:253–255`; `take_system_prefix`, `:85–90`; `split_for_compaction`, `:135–137`); one system message initially (`rpc.ail:344–345`); the exit handler sets `profile` before respawning (`index.ts:931–934`, `:951`); per-turn `step_idx` and wire `current_step` (`session.ail:711`, `:573`); `steps_executed_so_far` (`:576`); the empty-task guard (`:3597–3598`).

The five-step order, `run_model`, the whole-prefix replacement after the digest check (D4, `ADR-003:462–463`) and `ext_artifacts` reset on the switch (`:571`) are consistent with each other and with the code. Nothing to correct.

### D7 — accept

Verified: `wake_read` and the drop rule (`ADR-002:233–240`); the replay table's `scripted_wake` and cursor (`:272–276`); `recording_approval` wrapping `scripted_approval` (`ports.ail:1718–1747`); `live_ports` overriding world-served defaults (`:2568–2570`); the exit handler order (`index.ts:928–985`); herdr restart (`session-identity.ts:23–27`). The two named bindings, the recorded `WakeInteraction`, the `WakeGeneration` check and the `Lost`/`Aborted` exits (`ADR-003:600–607`, `:622–636`) close the v2 items. `Aborted` on `restart` while suspended cancelling the request and leaving the snapshot resumable is consistent with ADR-002's "`restart`/`exit` cancel the request" (`ADR-002:262`). Unscheduled; nothing to correct.

### D8 — accept with corrections

1. Step 1 lists "D4's envelope decoder and its refusal fixtures" with the strict world decoder in step 2 (`ADR-003:651–653`). The envelope contains `world` (`:264`); a step-1 round trip must decode it with something. Say step 1 uses the total `world_of_json` (`ext_world.ail:543–553`) for the round trip and step 2 swaps in `world_of_json_strict` and adds the `WorldField` fixtures. The in-process resume needs no decoder at all, so this is only about the fixtures' honesty.
2. Step 2's gate "the frame's `final` equal to the snapshot's ordinal plus two" (`:667–668`) is right; make it the assertion that D3 and D5 cite instead of a ledger read (overall item 2).
3. Step 1 must also add the `written` field (or generalise `suspended`) so that step 3's `run_ordinal` and step 2's `Restart` update have their input (overall item 1).

## 3. The four v2 items: decided coherently?

### 3.1 Step-1 wire behaviour with headless-only `error`

**Coherent.** The decision is keyed on `policy.headless`, which is read through the port from `MOTOKO_HEADLESS` at `session_policy_init` (`session.ail:2044`, `:2053`, `:156`) and is in scope at both outer emit sites (`:3421`, `:3606`), so "emit `error` beside `run_suspended` in headless only" is one predicate the code already has. In headless the child exits after the run (`:3357`; `rpc.ail:355–359`) and the non-TTY loggers exit on `error` (`index.ts:517–519`, `:572–575`), which step 1 preserves; in TTY mode the `run_suspended` case unlocks input (`ui.ts:2752–2761` pattern; `:1790–1795`). Step 3 removes the headless `error` together with the logger rows and the drain (`ADR-003:669–670`). The eval-harness question stays where the ADR put it (`:372–374`, `:672`). The order on the wire in headless is `run_suspended`, `run_summary`, then `error`, same as today's `run_summary` then `error`, since the outer emit follows the traced run.

### 3.2 Child-writes-`Restart`, host-writes-`Abort`

**Coherent as a rule; incomplete as a mechanism.** The rule removes the race (D3 above). The child needs the current generation, which the traced run does not return after a successful turn (overall item 1), and the "no snapshot yet" case needs one sentence (D3 correction 2).

### 3.3 Narrowed generation check

**Coherent.** See D5. The only place `generation` is compared is the wake file (`ADR-003:495–496`, `:622–623`); the lease is the writer guarantee (`:497–510`); `Refusal::Generation` is gone from D4 and D6 step 2 (`:450–452`, `:560`).

### 3.4 `ext_artifacts` reset on a profile switch

**Coherent.** Stated in D1 (`:285–287`), applied in D6 step 4 (`:571`), gated in step 3 (`:673–674`), and consistent with the constructor (`session.ail:713`) and with keeping provider-side `telemetry`.

## 4. Soundness of the new pieces

### 4.1 `run_ordinal` parameter and `run_id` as argument

Sound in intent; the reset has no signal (overall item 1). Once `written` exists, the loop's rule is: `run_ordinal := 0` and `generation := written.generation` when `written` is `Some`, else `run_ordinal + 1`; the next traced run receives `run_id = "<session_id>.g<generation>.r<run_ordinal>"`. Both the `Ok` and `Err` arms of both outer loops (`session.ail:3418–3427`, `:3603–3612`) thread the pair.

### 4.2 Outermost-process lease, `MOTOKO_LEASE_HELD`, hostless

Sound, with the hook correction (D5). Two small additions: the lease file is written by the host with Node's atomic rename (the "TypeScript twin", `ADR-003:426`), and the child's `Refusal::Leased` in the hostless case reads the same file format, so the format belongs in D5's text, which it does (`:497–498`).

### 4.3 Ledger-read `final` and the `+2` gate

The `+2` is right (`session.ail:1550`, `:1554`; `derive.py:96–97`). The ledger read is not (overall item 2). The corrected rule: the resumed frame opens at `snapshot.world.ordinal`; `SessionResumed.from_ordinal` records it; step 2's gate asserts `final == from_ordinal + 2` for a snapshot-then-finalise run. ADR-001's per-frame gate is otherwise untouched (`ADR-001:419–427`).

### 4.4 Bare-flag arm and `run_model`

Sound. `--resume-force` gets an arm like `:235`; `--resume <id>` goes through `apply_flag_value` (`config.ail:222–230`); `run_model` is the `--model` override else `compat.model` (`ADR-003:562–563`), consistent with `rpc.ail:245`.

### 4.5 Whole-prefix replacement

Sound. `take_system_prefix` returns every leading system message (`phase_vocab.ail:85–90`); replacing the whole prefix with one new system message keeps `system_is_head_prefix` true and the digest comparison well-defined; the check runs before the replacement (D4, `ADR-003:462–463`).

### 4.6 Named live and recording `wake_read` bindings

Sound. The live binding is the one deliberate world-cursor read among live bindings (`ports.ail:2568–2570` is the precedent for overriding); the recording binding mirrors `recording_approval` (`:1718–1747`) and records a `WakeInteraction`, so replay of a resumed run reproduces the served wake. Both wait on ADR-002 D2's types.

### 4.7 `Lost`/`Aborted` exits

Sound and consistent with ADR-002 D2's cancel rule and the herdr contract (`session-identity.ts:23–27`).

## 5. Can PLAN-003 be written?

**Not yet; one gap blocks it, and one textual fix should land with it.**

Blocking: **the write signal back to the loop** (overall item 1). Without it, step 3's `run_ordinal` reset, step 2's child-written `Restart` update and D5's "first write is `generation + 1`" have no input, and the plan would have to invent the field. The fix is one additive field on `TracedSessionResult` and two sentences in D2, D3 and D5.

To fix in place, not blocking: restate `final` as the resumed frame's opening ordinal with the `+2` gate (D3 `:409–415`, D5 `:527–528`, D8 `:667–668`); register the lease hooks unconditionally (D5 `:501–503`); name `MOTOKO_LEASE_HELD` in the `buildChildEnv` allowlist; say what `restart` writes when no snapshot exists; say which world codec step 1's round trip uses.

Nothing in "Not decided" (`ADR-003:703–715`) blocks PLAN-003. ADR-002 is still v2.1 with D6 in its TL;DR (`ADR-002:4`, `:110`); the v3 edit (`ADR-003:678–679`) remains to be made.

## 6. Coordinate audit

All coordinates in the cross-reference list (`ADR-003:740–760`) and the body, at `97827bf`. Rows marked "v2" were verified in the v2 audit and are unchanged.

| cited | verified | note |
|---|---|---|
| `session.ail:175–180`, `:335–341`, `:383–429`, `:389`, `:545–560`, `:573`, `:576` | v2 | |
| `:709–730`, `:711–713`, `:726`, `:728` | yes | `:713` is `ext_artifacts: jo([])` |
| `:1440–1447`, `:1441–1442`, `:1445` | v2 | |
| `:1537`, `:1550`, `:1552`, `:1554` | yes | clock read `:1550`; literal `:1554` |
| `:2155–2169`, `:2171–2185`, `:2185`, `:2407–2437`, `:2422`, `:2429`, `:2433`, `:2437`, `:2486` | v2 | |
| `:2741–2749`, `:2758`, `:2765`, `:2768`, `:2790`, `:2873`, `:2887` | v2 | |
| `:3137–3139`, `:3330–3346`, `:3339`, `:3346`, `:3367`, `:3373`, `:3380–3386`, `:3391–3399`, `:3394–3397` | yes | |
| `:3402–3408`, `:3409`, `:3416`, `:3419–3426`, `:3421–3426`, `:3484–3533`, `:3501`, `:3586`, `:3597–3611`, `:3606–3611`, `:3697`, `:3705–3712` | v2 | `:3501` is `publish_turn_exit_manifest`'s row |
| `:350`, `:2706–2790`, `:2768–2780` | v2 | |
| `step_machine.ail:93–103`, `:93–104`, `:104`, `:114–138` | v2 | |
| `phase_vocab.ail:39–48`, `:40`, `:42–47`, `:63–65`, `:71–73`, `:85–90`, `:253–255`, `:690–703`, `:692–694`, `:1155–1170`, `:1264` | yes | |
| `ext_world.ail:515`, `:543–553` | v2 | |
| `ports.ail:32–34`, `:183–196`, `:630–634`, `:826`, `:850`, `:1135–1143`, `:1629–1645`, `:1718–1747`, `:2556–2572`, `:2568–2570` | yes | |
| `ext/exit_manifest.ail:44–56`, `:66`, `:182–205`, `:196–204` | v2 | |
| `dst_fault_catalogue.ail:50–59`, `:50–53`, `:210`, `:825–829` | v2 | |
| `dst_execution.ail:121–130`, `:128–130`; `dst_result.ail:130–137` | v2 | |
| `dst_invariants.ail:788–806`, `:1385–1388`, `:1416–1424` | yes | |
| `dst_program.ail:229–238`; `dst_replay.ail:793–833` | v2 | |
| `config.ail:133–138`, `:222–247`, `:222–230`, `:235`, `:236–239` | yes | |
| `rpc.ail:218–237`, `:241–247`, `:241–262`, `:245`, `:260`, `:275–276`, `:296`, `:296–345`, `:319`, `:342–345`, `:344–345`, `:351`, `:355–359` | yes | |
| `derive.py:94–105`, `:96–97`, `:124–142`, `:142`, `:151–155` | yes | |
| `PLAN-001:370–375`, `:376–381`, `:378–380` | yes | |
| `packages/motoko-ext-abi/types.ail:547` | v2 | |
| `runtime-process.ts:58–103`, `:96`, `:337–389`, `:362–371`, `:372`, `:482–505`, `:776–780` | yes | |
| `session-logger.ts:5`, `:233–238`, `:343–346` | yes | |
| `session-identity.ts:23–27` | v2 | |
| `exit-actions.ts:425–426` | yes | the body runs to `:428` |
| `herdr-agent-state.ts:43`, `:63`, `:73–74`, `:81–91`, `:89–90`, `:292–302`, `:295–301` | yes | hooks are registered only after the `:280` early return (§2 D5) |
| `ui.ts:790`, `:1790–1795`, `:2282`, `:2752–2761` | yes | |
| `index.ts:517–519`, `:572–575`, `:877–882`, `:885–889`, `:901–907`, `:918`, `:922–985`, `:931–934`, `:951`, `:959–970`, `:1006–1008`, `:1017–1019` | yes | |
| `ADR-001:373–374`, `:386–389`, `:396–404`, `:422–425`, `:439–445`, `:442–443` | v2 | `:415–419` defines frames as script-printed lines, which contradicts "the ledger's frame record" (`ADR-003:413–415`) |
| `ADR-002:262`, `:272–276`, `:233–240` | yes | |
| `REVIEW-adr003:105`, `:111–120`, `:197–202`; `REVIEW-adr003-v2` §2 D3, §2 D5, §5 | yes | |
| "the ledger's frame record" (`ADR-003:413–415`, `:527–528`) | **no** | no such record exists at HEAD or in ADR-001 D2; see overall item 2 |
| "the same process-exit hook that releases the reporter" (`ADR-003:501–503`) | **conditional** | registered only inside a herdr pane (`herdr-agent-state.ts:278–280`, `:295–301`) |

## Required changes before PLAN-003

1. Add `written: Option[{ generation: int, reason: SuspendReason, published: bool }]` to `TracedSessionResult` (set by the success arm and `c2_suspend`; `None` at `session.ail:1554`), and state the loop's rule: on `Some`, `generation := written.generation` and `run_ordinal := 0`; otherwise `run_ordinal + 1`. Cite it from D2, D3's `Restart` row and D5's `run_id` (`ADR-003:331–334`, `:421`, `:482–486`, `:492–493`).
2. Replace "read from the ledger's frame record" (`:413–415`, `:527–528`) with: the resumed frame opens at `snapshot.world.ordinal`, recorded as `SessionResumed.from_ordinal`; step 2's gate asserts `final == from_ordinal + 2` (`ADR-001:415–419`, `:426–427`).
3. Register the lease removal as its own unconditional `exit`/`SIGINT`/`SIGTERM` hook (`herdr-agent-state.ts:278–280`, `:295–301`; `exit-actions.ts:425–428`), and add `MOTOKO_LEASE_HELD` to the `buildChildEnv` allowlist (`runtime-process.ts:343–389`).
4. Say what the child's `Restart` arm writes when no snapshot exists yet.
5. Say that step 1's envelope round trip uses the total `world_of_json` until step 2 (`ext_world.ail:543–553`).
