# ADR-003 v5 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; the HEAD the ADR names, `ADR-003-session-snapshot-and-resume.md:12`)
Subject: `ADR-003-session-snapshot-and-resume.md` v5 (journal-only; unreviewed)
Also reviewed against: oh-my-pi 18.1.11 at `~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/src/` (`package.json` version `18.1.11`)
Prior: v1–v4 reviews; PLAN-003 v2.1 (`PLAN-003-implement-adr-003.md:3`) and its two reviews

Every coordinate v5 cites was checked at this HEAD, and every oh-my-pi citation was read. §8 and §11 are the audits.

## Overall verdict

**Accept the direction; return for a v6 before PLAN-003 v3.** The journal-written-by-the-host design is right for the reasons v5 gives, and the six retractions are factually right in substance. Four things the fold depends on are not in the ADR, and each would be decided by the plan otherwise:

1. **The journal never receives the system prompt or the initial history.** D4 rule 3 says "emit the header's system prefix" (`ADR-003:289–290`), but the header carries `system_prefix_digest`, not the prefix (`:175`). The initial `[system, task]` is built in `rpc.run_with_config` (`src/core/rpc.ail:344–345`) and handed to the run as `history`; nothing in D2's `HistoryAppended` list (`ADR-003:215–218`) emits it. A fold over the journal starts with no messages; a fold over a traced run's own trace (D4's invariant) starts without the run's `history` argument. Decide: `HistoryAppended(initial)` emitted at the traced entry before `c2_loop` (`session.ail:3143`), which seeds both the journal and the invariant, or a header that carries the system message and a first `history_appended` for the task.
2. **The tool-phase end replaces, it does not append.** `c2_finish_tool_batch` sets `msgs: c2_pending_prefix(st) ++ tool_msgs` (`session.ail:2251`), where the prefix is `pending_tool_prefix` when set (`:2213–2215`). On the hybrid-bash path the prefix is `st.msgs ++ [augmented_assistant_msg]` (`:2998`) while `st.msgs` holds the *un-augmented* assistant (`:2989`, `:2981–2987`): the last message is swapped for one carrying the synthesized tool call. An append-only `HistoryAppended` emitted at `:2989` leaves the fold with a plain assistant followed by a tool result, which `history_valid_transcript` refuses — on every hybrid run. The ADR's site list also omits `:2251` (where tool results actually enter) and the DP7 path's `:2356`, `:2381`, and mislabels `:2907` (the intercept-handled tool message). D2 needs the true site list and a rule for `:2251`: either the assistant's `HistoryAppended` is emitted at tool-phase end with the prefix's version, or the event carries `replace_tail: int`.
3. **`first_kept_id` cannot address a message inside a multi-message entry.** Entries at `:2251` carry every tool result of a batch, `:2907` two messages, and the initial entry (item 1) two; the checkpoint's first kept message may sit inside one. oh-my-pi has no such problem because each message is its own entry (`session-entries.ts:73–76`). Add `first_kept_offset`, or make every `HistoryAppended` carry one message.
4. **The invariant's comparands are not in `ExecutionUnderTest`.** Families take `ExecutionUnderTest` (`src/core/dst_invariants.ail:798`, `:946`, …), which holds `result: DstResult` and `world` (`:553–563`); `SystemRun` holds `outcome` and the trace (`src/core/dst_result.ail:93–98`). Neither carries the run's final `telemetry`, `ext_artifacts`, `suspended.history`, nor the initial history. D4's "compare with the run's final state" (`ADR-003:303–307`) needs `TracedSessionResult` to return a final-state projection and `execution_of` (`src/core/dst_execution.ail:100–119`) to carry it.

Smaller but load-bearing: `SessionLogger` is constructed per spawn (`src/tui/src/index.ts:903`), so the journal's leaf and `seq` cannot live in it across a `restart` respawn; the TUI already logs unknown event types verbatim (`runtime-process.unknown-events.test.ts:36`), so D3's digest rule is new logic that must land with the events or the JSONL doubles in content; and D4 rule 5 reconstructs counts from assistant appends where the exact quantity is one line away (`session.ail:559`).

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT WITH CORRECTIONS** | Envelope, tree and leaf are right and match the precedent; the header lacks the system prompt; entries need one message or an offset. |
| D2 | **ACCEPT WITH CORRECTIONS** | Suspension unchanged and sound; the `HistoryAppended` site list is wrong at four sites and has no rule for the tool-phase replacement. |
| D3 | **ACCEPT WITH CORRECTIONS** | Host-as-writer is right and untangles the ordinal gate; the writer's lifetime must be the host's, not the per-spawn logger's; the digest rule is new code. |
| D4 | **ACCEPT WITH CORRECTIONS** | Path, strict decode, dangling rule and boundary are sound; history seeding, `first_kept` addressing and the invariant's inputs are missing; counts should be carried. |
| D5 | **ACCEPT** | `resume_count`/`run_id` are simpler than v4.1's and correct; `from_ordinal == final` holds at `session.ail:1550–1554`. |
| D6 | **ACCEPT WITH CORRECTIONS** | Order is right; the crash case depends on items 1–2. |
| D7 | **ACCEPT** | Park and wake as entries, exactly-once by the following `run_started`, is coherent with ADR-002 D2. |
| D8 | **ACCEPT WITH CORRECTIONS** | "P1 unchanged" is not true: four P1 parts change (§9). |

## 1. The six retractions

| # | claim | verdict | evidence |
|---|---|---|---|
| 1 | The log is lossy as it is | **right** | provider calls logged as digests (`session.ail:2773–2781`); compaction as a note (`:350`; `CompactionInfo = { step, note }`, `phase_vocab.ail:581`); tool results capped for display (`cap_tool_message_content`, `:866`); stream text as deltas (`:823`). |
| 2 | Journal beside checkpoint is a second mechanism | conceded | no code claim. |
| 3 | The child's writer sits on the witnessed path | **right** | v4.1's `file_replace` was a helped leaf under ADR-001 D2 (`ADR-001:373–374`, `:386–389`); v5 adds no `Ports` field, so `derive.py`'s `CALL_RE` (`tools/driver_leaf_inventory/derive.py:151–155`) matches nothing new (§5). |
| 4 | Compaction never replaces `st.msgs`; only the checkpoint does | **right for compaction, wrong for the tool phase** | pre-step compaction builds `compacted_msgs` for one call (`session.ail:2741–2749`, `:2768`, `:2790`) and the assistant is appended to `st.msgs` (`:2887`); `apply_state_delta` never touches `history` (`phase_vocab.ail:335–347`, `:338`); the checkpoint replaces (`session.ail:2521`). But `:2251` rebuilds `msgs` from `pending_tool_prefix`, which on the hybrid path differs from `st.msgs` in its last message (`:2989` vs `:2998`). |
| 5 | 37 emits, 23 appends; append-and-emit closes it | **right** | `grep -c "ledger_emit("` = 37 (36 call sites plus the definition at `:335`); `grep -c "WireRecord("` = 23. The trace type is `WireRecord | CompactionStageRecord | DecisionRecord` (`phase_vocab.ail:602–606`). The citation for "variant-name comparison is not enough" (`ADR-003:213`, `dst_invariants.ail:1742–1769`) is `trace_positions`, the two-run determinism check, not the emission-parity family (`parity_findings`, `:946`); the point stands, the pointer is off. |
| 6 | Entries are a tree with a leaf | **right** | `SessionEntryBase { id, parentId, timestamp, type }` (`session-entries.ts:66–71`); `SessionEntryIndex` with `#leaf` and `pathTo` walking `parentId` with a seen-set (`session-manager.ts:250–255`, `:330–341`); `branch` moves the leaf (`:2658–2661`); `turn-recovery.ts:1103`, `:1144`, `:2749` and `agent-session.ts:8072` are branch calls. |

**Can `SessionLogger` carry the writer?** Its `log` writes `JSON.stringify(event)` to the JSONL stream and a transcript line (`src/tui/src/session-logger.ts:355–359`); adding a third stream is mechanical. Two things the ADR does not say: the logger is created per child spawn (`index.ts:903`) and closed at child exit (`:925`), so across a `restart` respawn the journal's `leaf`, `seq` and file handle must live in the host process, not in the logger — a `SessionJournal` owned beside `sessionStartMs()` that the logger is handed; and the "payload replaced by a digest" rule (`ADR-003:241–242`) is new: today every parsed event with a `type` string is passed through (`runtime-process.ts:105–117`) and logged verbatim, including unknown types (`runtime-process.unknown-events.test.ts:36`).

## 2. Per-decision verdicts

### D1 — accept with corrections

Verified: `[Message]` codec is new work (`Msg` has no `images`, `packages/motoko-ext-abi/types.ail:547`; `Message` does, `session.ail:3402–3408`); the `RuntimeStatusCounts` move (`:431–437`, `:443`, `:545–553`; `zero_totals` at `:439–441` stays, as the ADR says, `ADR-003:191`); `totals` per run (`:712`; `step_machine.ail:104`).

Corrections: the header must carry the system message text, or the first entry after the header must be the initial history (overall item 1); `history_appended` entries carry one message each, or an offset joins `first_kept_id` (item 3); the `exit` entry's `pending_tool_calls` is computed by the host "from the journal (the fold's dangling-call rule)" (`:251–253`), so the host needs a TypeScript fold of the tool-pairing rule or the child must emit it — say which.

### D2 — accept with corrections

The suspension is v4.1's and stands on its four reviews. The journal-class events:

**The true `st.msgs` growth sites at HEAD** (every `msgs:` in a `C2LoopState` literal that is not `st.msgs`):

| site | what enters | ADR lists it? |
|---|---|---|
| `session.ail:2251` | `pending_tool_prefix ++ tool_msgs` — the tool results, and on the hybrid path a replaced last assistant | **no** |
| `:2356`, `:2381` | `msgs_with_assistant` via `c2_after_dp7` (called at `:3020`, `:3080`) | **no** |
| `:2494` | the injected user message | yes |
| `:2521` | the checkpoint's rebuilt history | yes |
| `:2907` | `msgs_with_assistant ++ [tool_msg]` — the intercept-handled tool message, two messages | listed as a tool-results site; it is the intercept site |
| `:2944`, `:2989`, `:3025`, `:3057` | `msgs_with_assistant` | yes |
| `:3409` | the operator's message, outside the traced run | yes |

`:2298`, `:2675`, `:2849` carry `st.msgs` unchanged. Fix the list, add the `:2251` rule (overall item 2), and add the initial history (item 1). `StateDelta` at the end of every step is fine; note the loop's telemetry and artifacts change at `:2911`, `:2947–2948`, `:2992–2993` and at the checkpoint (`:2524–2525`), so "end of every step" must include the checkpoint arm.

`RunSummary` gaining `cumulative` and `SessionStart` gaining `run_id` (`ADR-003:226`) move two goldens (`phase_vocab.ail:791`, `:593`, `:1221–1229` pattern) and the wire; say so in Consequences (it does, `:421`).

### D3 — accept with corrections

Right in shape. Corrections: the writer's lifetime (§1); the digest rule as new code; the header "rewritten in place" on the first `session_start` (`ADR-003:246–247`) is the one non-append write and should be the only in-place write the design admits — say what a reader does with a header missing the child-reported digests (a session that died before `session_start`).

### D4 — accept with corrections

See §3.

### D5 — accept

`resume_count` from the host replaces a counter of writes that no longer exist; `run_id = <session_id>.r<resume_count>.<run_ordinal>` is unique without any reset rule; `RunIdentity` as an argument with default `r0.0` keeps the exported entries' signatures (PLAN-003 §0.7, `PLAN-003:75–80`). See §6 for `from_ordinal`.

### D6 — accept with corrections

The five-step order matches `rpc.ail` (`:241–247`, `:275–296`, `:319`, `:342`); the `Continuation` for `last = Suspended` is v4.1's; the crash case is the second judging number and depends on items 1–2. One addition: the child reads the journal with the ambient `readFile` (`ports.ail:32` is the import in `ports.ail`; `rpc.ail:266–267` is the precedent for an ambient read before the driver starts), which is outside the traced surface and therefore invisible to `make world_state`; say so, since a reader of ADR-001 D2 will ask.

### D7 — accept

The `wake` entry as a child of the `park` entry, consumed once because a `run_started` follows it (`ADR-003:387–392`), is a cleaner exactly-once than v4.1's generation-keyed file, and the seeded-cursor path through `wake_read` is v4.1's, already reviewed. Unscheduled.

### D8 — accept with corrections

§9.

## 3. The fold rules

1. **Path.** Leaf to root by `parent_id`, stop at a repeated id, reverse: exactly `pathTo` (`session-manager.ts:330–341`). Sound.
2. **Strict decode per entry.** Sound; `Refusal::Entry(seq, field)` is the right shape. The journal carrying `world_ordinal` and no `WorldState` (`ADR-003:288`) is what lets the total `world_of_json` stay untouched (`ext_world.ail:543–553`).
3. **History.** The latest `history_replaced` on the path, then its messages, then `history_appended` from `first_kept_id`: this is `buildSessionContext`'s shape (`session-context.ts:180–190`, `:340–347`). Two gaps: the seed (overall item 1) and the `:2251` replacement (item 2). With those fixed, the checkpoint pointer is right: `apply_checkpoint` folds a prefix into summary messages and keeps a tail (`phase_vocab.ail:349`; `session.ail:2517–2521`), so `first_kept` is the tail's first index in the pre-checkpoint history, and the host maps it to an entry (item 3).
4. **Dangling tool calls.** The ADR strips only from a *trailing* assistant (`ADR-003:293–296`); oh-my-pi strips from *any* assistant on the path (`session-context.ts:501–507`), because a branch point can leave a middle turn's results on a sibling. On v5's single path only the trailing case arises; the narrower rule is right for v5 and should say it widens when branching lands. The crash-mid-tool-phase shape works: the assistant with its `tool_calls` is journaled at `:2944` before the tool phase runs, so the fold sees an unpaired call ✓. On the hybrid path the journaled assistant has no `tool_calls` (`:2989`), so a crash there strips nothing and the fold is a plain assistant — acceptable, and the `:2251` rule must produce the augmented one on success.
5. **Counts.** `provider_calls_started` and `provider_calls_completed` are counted from `ProviderCallPrepared` and `ProviderResult` records (`session.ail:483–497`), and `stage_*`/`compaction_ai_applied` from stage events. Reconstructing `completed` from assistant appends is approximate (a retried stream error appends nothing and completes nothing, `:2849`; a stage count is not derivable at all). The exact quantity is `runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))` (`:559`), which the loop can put in every `StateDelta`; then rule 5 reads the last delta and needs no reconstruction.
6. **Boundary.** Sound.

**`history_digest_after`** (`ADR-003:311–314`): a per-entry digest of the fold's history through that entry, computed by the child from `st.msgs`, is exactly the chain v4.1 could not have; it also pins item 2, because the child's digest at `:2251` is over the *replaced* history and a fold that appended would fail it.

**Is `journal_fold_findings` implementable as a family?** Mechanically yes: a 13th variant in `InvariantFamily` (`dst_invariants.ail:205–216`), `all_families()` (`:273–277`), `family_id` (`:219`), `violation_family` (`:334`), and a `_findings(x: ExecutionUnderTest) -> [Violation]` on the pattern of `checkpoint_findings` (`:1319`). Semantically not yet: `ExecutionUnderTest` has `result: DstResult` and `world` (`:553–563`); `SystemRun` has `outcome`, `ledger_trace`, `interaction_log`, `replay_metadata` (`dst_result.ail:93–98`); the bridge copies `run.result`, `run.trace`, `run.world`, `run.emissions` (`dst_execution.ail:110–118`). The fold can be compared with `outcome`'s `Ok(history)` for a completed run; for a suspended run and for `telemetry`/`ext_artifacts` there is nothing to compare against, and the fold has no seed. Add to `TracedSessionResult` a `final: { history, telemetry, ext_artifacts, cumulative }` projection (or return the `Continuation` for every run), carry it through `execution_of` into `ExecutionUnderTest`, and emit the initial history as the first record of every run's trace (item 1). Then the family runs on every existing fixture, as the ADR wants (`ADR-003:307–309`).

## 4. `first_kept_id` resolution

The mechanism — the child emits the history index of the first kept message, the host maps it to an entry id because it assigned every `history_appended` id and knows each entry's message count (`ADR-003:219–223`) — is sound as far as it goes: the host sees every `HistoryAppended` in order, including the conversation loop's at `:3409` and (after item 1) the initial one, so its running message count equals the child's `st.msgs` length as long as every change to `st.msgs` is journaled. Two conditions: the `:2251` replacement keeps the count (it swaps the last message, so indices are unchanged, but the host must apply the swap); and the index must be resolvable *within* an entry (item 3). With one message per entry the resolution is a lookup; with batched entries it is `(entry_id, offset)`.

## 5. What removing the child-side writer leaves untouched

**The ordinal gate and `derive.py`: untouched, verified.** No `Ports` field is added; `CALL_RE` matches only `receiver.(env_get|file_read|clock_now|tool_exec|model_step|approval_read)(` (`derive.py:151–155`) and `SCAN_FILES` does not include `rpc.ail` (`:144–149`), so the child's ambient `readFile` of the journal in `run_with_config` is neither a helped leaf nor scanned. `ledger_emit` is not a port. The frame gate counts `world_request` lines (`ADR-001:415–427`); journal-class events add none.

**`HistoryAppended` on stdout.** The TUI's stdout is a `readline` interface over `proc.stdout` (`runtime-process.ts:588`) with no line cap, and `parseAgentEventLine` accepts any JSON object with a string `type` (`:105–117`), so the events reach `logger.log` and `ui.handleEvent` (`index.ts:917–921`), where the UI's switch ignores unknown types and the logger writes them verbatim (`unknown-events.test.ts:28`, `:36`). Consequences: the digest rule (D3) must land in the same change as the events, or the JSONL carries full tool output, which `cap_tool_message_content` (`phase_vocab.ail:866`) exists to prevent for `native_tool_results`; and the eval harness, which reads the JSONL for `run_summary` (`env-server.ts:415–420`), sees digests only once that rule exists. The pipe itself carries the content either way (`ADR-003:434–435` says so). One more consumer: the `EmissionParity` family compares wire and trace (`parity_findings`, `dst_invariants.ail:946`); appended-and-emitted events satisfy it by construction, and the ADR's payload-equality assertion belongs beside it.

## 6. D5's ids and `from_ordinal`

`c2_finalize` reads the clock through the port (`session.ail:1550`), builds the summary (`:1552`), and returns `world: reading.next_state` (`:1554`). Under PLAN-001 P2 the read's `advance` is witnessed before the summary is appended (ADR-001 P2 5(a), `ADR-001:439–444`), so `reading.next_state.ordinal` is the frame's `final` and is in scope when `mk_run_summary` is built. `RunSummary.world_ordinal := reading.next_state.ordinal` and `from_ordinal := last run_finished.world_ordinal` gives `END₁.final == BEGIN₂.ordinal₀` with no constant (`ADR-003:336–340`). Sound. It moves the `RunSummary` golden and adds a field to the wire, which Consequences records.

## 7. D7

Coherent (§2 D7). One note: "a wake delivered while the runtime is alive is consumed by `wake_read` … and recorded as a `wake` entry" (`ADR-003:383–384`) relies on ADR-002's `WakeReceived` being appended and emitted (`ADR-002:279–281`), which is where the host gets the entry from; say so, since D7's entries are the only ones whose producer is an ADR-002 event.

## 8. oh-my-pi citations

| cited | verified | note |
|---|---|---|
| `session-entries.ts:66–71` | yes | `SessionEntryBase { type, id, parentId, timestamp }` |
| `:73–76` | yes | `SessionMessageEntry { type: "message", message }` — one message per entry |
| `:118–143` | yes | `CompactionEntry` with `firstKeptEntryId` at `:122` |
| `:232–262` | yes | `SessionInitEntry` with `systemPrompt` and `task` (`:235–237`) — the precedent for item 1 |
| `session-manager.ts:246–341` | yes | `SessionEntryIndex`, `#leaf`, `pathTo` |
| `:326` | yes | `usageSnapshot()` returns the running `#usage` |
| `:1176–1182` | yes | `#freshEntryFields`: id, `parentId = leafId()`, timestamp |
| `:1303` | yes | `captureState()` in-memory snapshot |
| `:1405–1484` | yes | `setSessionFile`, `newSession` |
| `:2658–2710` | yes | `branch`, `branch_summary` entry |
| `session-context.ts:180–345` | yes | `buildSessionContext` |
| `:501–507` | yes | dangling stripping from *any* assistant turn |
| `agent-session.ts:1649–1658` | yes | postmortem `#recordSessionExit`; `resumeCommand(sessionId)` |
| `:2276–2300` | yes | `collectPendingToolCalls(getBranch())` |
| `:8072` | yes | `branchWithSummary` |
| `exit-diagnostics.ts:272` | yes | `collectPendingToolCalls` |
| `turn-recovery.ts:1103`, `:1144`, `:2749` | yes | three `sessionManager.branch(...)` calls |
| `utils/resume-command.ts` | path off | it is `src/utils/resume-command.ts`, not under `src/session/` |

## 9. PLAN-003 v3, and whether P1 is untouched

**P1 is not untouched.** Against PLAN-003 v2.1:

- Part 1 item 1 asserts `written` is `Some({ generation: 1, … })` (`PLAN-003:124–125`); `written` is gone (`ADR-003:208`). The assertion becomes: `suspended` is `Some`, `RunSuspended` before `RunSummary`, and — new — the `HistoryAppended` records in the trace fold to `suspended.history` (the invariant's first red).
- Part 3 builds `snapshot.ail` with `Snapshot`, `Compat`, `Boot`, `SnapshotWritten`, `Refusal` including `Size`, and `snapshot_of_json` decoding `world` with the total codec (`:171–202`); v5 renames the module `journal.ail` (`ADR-003:191`), keeps `Continuation`, `RunIdentity` and the `[Message]` codec, and drops `Snapshot`, `SnapshotWritten` and every world-decoding path. The entry types and their codecs move to P3.
- Part 4 adds `written` to `TracedSessionResult` and sets it in `c2_suspend` (`:209–228`); v5 has only `suspended`. `RunSuspended` loses `generation` and `published`.
- Part 5's `loop_identity_step` resets on `written` (`:256–261`); v5's rule is "increment per traced run" with `resume_count` from the environment. `generation` leaves the loop's parameters.
- Part 6 is unchanged.

P2 is deleted, as the ADR says. P3 becomes: the initial-history event and the true site list (items 1–2), the entry codecs, `StateDelta` with `cumulative`, the fold with `first_kept_offset` (item 3), the final-state projection through `execution_of` (item 4), the family, the host journal object with the digest rule and the header rewrite, the lease, `resume_count`, `--resume`, the three live gates. P1's §0 rules stand.

## 10. Not decided: what must be decided first

Must move into a v6 before PLAN-003 v3:

1. How the system prompt and the initial history enter the journal and the trace (overall item 1).
2. The `:2251` rule and the corrected site list (item 2).
3. One message per `history_appended`, or `first_kept_offset` (item 3).
4. The final-state projection on `TracedSessionResult` and `ExecutionUnderTest` (item 4).
5. The journal writer's home in the host across respawns, and the digest rule landing with the events (§1, §5).
6. Counts carried in `StateDelta` versus reconstructed (§3 rule 5).

May stay open: pruning, branching features, cost/context exhaustion, hostless durability, headless one-shot resume, and whether `state_delta` carries artifacts inline (`ADR-003:437–448`).

## 11. Code coordinate audit (new in v5)

| cited | verified | note |
|---|---|---|
| `session.ail:350`, `:2773–2781` | yes | compaction note; payload digest |
| `:431–446`, `:545–553`, `:712` | yes | `zero_totals` `:439–441` stays |
| `:1441–1442`, `:1550`, `:1554`, `:2164–2169`, `:2171–2185`, `:2407–2437` | yes | |
| `:2494`, `:2521`, `:2741–2790` | yes | |
| `:2907`, `:2944`, `:2989`, `:3025`, `:3057` as "tool results after a tool phase" | **partly** | `:2907` is the intercept tool message; the others are assistant appends; tool results enter at `:2251`; `:2356`, `:2381` missing |
| `:3137–3139`, `:3330–3345`, `:3391–3399`, `:3402–3408`, `:3409`, `:3421–3426`, `:3586`, `:3597–3598`, `:3606–3611` | yes | |
| `step_machine.ail:93–104` | yes | |
| `phase_vocab.ail:40`, `:42–47`, `:71–73`, `:85–90`, `:253–255`, `:580–598`, `:602–606`, `:823`, `:866`, `:1221–1229` | yes | `:580` `ToolBatchInfo`, `:581` `CompactionInfo`, `:586` `CheckpointInfo`, `:593` `SessionStartInfo` |
| `ext_world.ail:543–553`; `ports.ail:32`, `:2568–2570` | yes | |
| `dst_fault_catalogue.ail:210`, `:825–829`; `dst_invariants.ail:1385–1388` | yes | |
| `dst_invariants.ail:1742–1769` | **misattributed** | `trace_positions`/`discovery_contract_findings`, the two-run determinism check; emission parity is `parity_findings` at `:946` |
| `dst_program.ail:229–238`; `dst_replay.ail:793–833` | yes | |
| `config.ail:133–138`, `:235–239`; `rpc.ail:241–262`, `:260`, `:296–345`, `:355–359` | yes | |
| `packages/motoko-ext-abi/types.ail:547` | yes | |
| `runtime-process.ts:58–103`, `:337–389`, `:482–505` | yes | stdout reader `:588`; parser `:105–117` |
| `session-logger.ts:221–240`, `:343–346` | yes | `log` is `:355–359`; constructed per spawn at `index.ts:903` |
| `herdr-agent-state.ts:63`, `:73–74`, `:81–91`; `exit-actions.ts:422–428` | yes | |
| `ui.ts:2282`, `:2752–2761`; `index.ts:517–519`, `:572–575`, `:825–827`, `:877–882`, `:918`, `:922–985`, `:931–934`, `:951` | yes | drain is `:922–926` |
| "37 `ledger_emit` sites and 23 `WireRecord` appends" | yes | 37 includes the definition at `:335` |

## Required changes before PLAN-003 v3

1. D1/D2: journal the initial history and the system prompt — `HistoryAppended(initial)` at the traced entry (`session.ail:3143`) or a header that carries the system message plus a first task entry (`rpc.ail:344–345`; `session-entries.ts:232–237`).
2. D2: replace the site list with the table in §2 D2 and define the `:2251` rule so the hybrid path's augmented assistant (`:2981–2998`) reaches the fold.
3. D1/D4: one message per `history_appended`, or `first_kept_offset` beside `first_kept_id`.
4. D4: add a final-state projection to `TracedSessionResult`, carry it through `execution_of` into `ExecutionUnderTest` (`dst_execution.ail:110–118`; `dst_invariants.ail:553–563`), and seed the fold with the initial history, so `journal_fold_findings` has its comparands.
5. D3: name the host-lifetime journal object (beside `sessionStartMs()`) that survives `index.ts:903`'s per-spawn logger, and land the digest rule with the events (`unknown-events.test.ts:36`).
6. D4 rule 5: carry `cumulative` in `StateDelta` from `session.ail:559`; drop the reconstruction.
7. D8: state that P1 Parts 1, 3, 4, 5 change, and list the deltas (§9).
8. Citations: `dst_invariants.ail:946` for emission parity; `src/utils/resume-command.ts`.
