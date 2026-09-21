# PLAN-001 P2B — answer (P2 Part 2: one effectful witness, in `session.ail`)

Branch `arniwesth/013-plan003-and-herdr`, parent `bd0eac7` (P2A). One commit, not pushed.

**Commit hash:** this file is inside the commit, so it cannot quote its own hash. Run
`git log -1 --format=%H -- .motoko/ab/answer-p2b.md`; the orchestrator's reply also gives it.

The working tree also holds other authors' uncommitted edits (`.devcontainer/agent_confined/docker-compose.yml`,
`ailang.lock`, several untracked paths). **They are left out of the commit.**

## 1. The staging choice: a real `WorldRequest` variant, so the vocabulary is now 43

The brief allowed either P1B's event-then-wire pattern or a minimal staging. **I followed P1B's pattern.** The vocabulary
goes 42 → 43 here, not in Part 4.

**Why a variant was needed.** `ledger_emit` takes a `LedgerEvent` and `WireRecord` wraps one, so the plan's shape needs
a variant to compile. The two alternatives were both worse:
- **No variant, drain only.** This clears `pending` without emitting anything. That is exactly the plan's rule against
  a "silent drain" (Part 1: a non-empty `pending` at a frame boundary is a red, not a silent drain).
- **Reuse an existing variant** such as `ExtensionDiagnostic`. This would misclassify the record. P2G's gate would
  also have no `world_request` lines to partition.

**How it matches P1B (`ad558d0`).** Everything landed in one commit:
- the variant and its info type;
- the projection;
- a golden;
- the vocabulary row, classified Logical with `reaches_trace_today: true`;
- the round-trip sample;
- the count pins moved 42 → 43;
- the pinned-order literals in `ledger_parity`, re-pinned.

**Left open, as P1B left it:** the `event_vocabulary_version` string was not bumped.

| Piece | Where | Shape |
|---|---|---|
| `WorldRequestInfo` | `phase_vocab.ail`, below `ContextLimitResolvedInfo` | `{ ordinal: int, request_class: string }`. The string is `world_ordinal.request_class_id`'s id, so the class has one spelling on both wires |
| `WorldRequest(WorldRequestInfo)` | `LedgerEvent`, after `ContextLimitResolved` | wire `{"type":"world_request","ordinal":N,"class":"env_read"}`. The wire key is `class` (the same key the world token uses); the field is `request_class` because `class` is reserved |
| golden | `phase_vocab` golden test | `WorldRequest({ ordinal: 264, request_class: "env_read" })` |
| row | `dst_event_vocabulary.event_vocabulary()` | payload `ordinal`, `class`; Logical, because the frame gate reads presence, order and content |
| the two total arms | `event_variant_id`, `event_wire_name` | `WorldRequest`, `world_request` |
| sample + counts | `scripts/dst/event_vocabulary_dst.ail`, `dst_event_vocabulary` tests and header | 43 rows; 37 Logical rows, of which 35 reach the trace |

## 2. What landed in `session.ail`

**`witness(session_id, trace, w) -> { trace, world } ! {IO, Trace}`** and its helper **`witness_drain`** are defined
**below `run_v2`**, under every anchor. The drain works head-first. For each `RequestWitness` it:
1. builds `WorldRequest({ ordinal, request_class: request_class_id(class) })`;
2. calls `ledger_emit` (the wire);
3. calls `ledger_append(trace, WireRecord(e))` (the returned trace).

It then returns `{ w | pending: [] }`. `ledger_emit` stays private.

It is written as an effectful recursive `func`, not a `pure func` helper. That keeps it outside
`new_contract_policy`'s diff rule, and it is the plan's literal shape: emit and append for each record.

### Call sites (every one is witnessed before the successor enters any driver record)

| Site | Before | After |
|---|---|---|
| **Bootstrap**, both entries (`run_v2_traced_from_seed`, `run_v2`) | `let started_world = advance(started.next_state, ClockRead)` | `let booted = witness(session_id, empty_ledger_trace(), advance(…)); let started_world = booted.world`, joined onto the same line. The seeded state's trace becomes `{ records: booted.trace.records ++ seeded.trace.records }`, and likewise `initial.trace` at `run_v2`, ahead of `HistorySeeded` and `ContextLimitResolved`. Concatenating instead of replacing makes no assumption that the constructors return an empty trace. **This one call witnesses `session_policy_init`'s 4 env reads and 8 limit reads, `derive_session_id`'s env and clock reads, and the start clock**, because they all ride in on the provider's world. `SeedContinuation` takes `booted.world` too |
| **`dispatch_step`** | `let trace_after_call = c2_trace_wire_events(…start, prepared…, stream_events)` | `let stepped = witness(session_id, <that trace>, exchange.next_state); let trace_after_call = stepped.trace`. Only comments and pure `let`s stand between `dispatch_step` and this line. The wire already holds the deltas, so the wire order and the trace order agree. The three later uses of `exchange.next_state` take `stepped.world`: the retry literal, the `TermProviderFailure` finalize, and `boot_ctx`'s token |
| **Approval (the `:3197` hoist)** | `let post = { st \| world_state: advance(input.next_state, ToolExec) }` | `let approved = witness(session_id, trace_with_decision, advance(…)); let post = { st \| world_state: approved.world }`. Both arms continue from `approved.trace` |
| **`execute_allowed_tool_call`** (ApprovalAllowed arm) | `{ post \| world_state: executed.next_state }` | `let executed_w = witness(session_id, c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state)`, then `after` uses `executed_w.world` and `executed_w.trace` |
| **RunTools arm, `ToolDispatchDone`** | `{ st \| world_state: done.world }` | `{ let tooled = witness(session_id, c2_trace_wire_events(trace_with_calls, done.emitted), done.world); c2_finish_tool_batch(…tooled.world…, tooled.trace, …) }` |
| **RunTools arm, `ToolDispatchPending`** | `world_state: pending.world`, `trace: c2_trace_wire_events(…pending.emitted)` | `let paused = witness(…)` on the arm's `{` line; the literal takes `paused.world` and `paused.trace` |
| **`c2_finalize` (the `:1811` hoist)** | `world: advance(reading.next_state, ClockRead)` inside the terminal literal | `let clocked = witness(session_id, trace, advance(reading.next_state, ClockRead))`, joined onto the `now_ms` line, **before `mk_run_summary` is emitted**. The literal then takes `ledger_append(clocked.trace, WireRecord(summary))` and `world: clocked.world`. **`RunSummary` stays the final record.** `make terminal_trace` still counts exactly one `{ result:` literal |

**Line accounting.** Every edit above line 4114 is joined onto an existing line.
- `anchors.sh` passes 10/10, and the anchored lines 1431/1690/1802/3893/4114 are byte-identical.
- No cascade, no profile re-issue, and `driver_plus_herdr` is not needed.
- `derive.py` still reports 24 sites and 0 unresolved, and its self-test has 0 failures.

**Out of Part 2 (the emissions channel).** `WorldRequest` is not added to `C2LoopState.emissions`. This follows the
per-run precedent: neither `HistorySeeded` nor `ContextLimitResolved` enters `emissions` at the entry.

### Not witnessed, deliberately (with the handoff)

- **`:3483`, the provider-error env read, which is Part 5(b).** It is advanced, and its successor is still discarded
  inside `let _ = if …`. Witnessing it is the first half of P2T's red-first run: instrument, leave the discard, run, and
  see `final` behind. Doing that here would have made P2B's own gates depend on a Part 5 red.
- **`:4535`, the exit manifest's env read, which is Part 5(a).** `publish_turn_exit_manifest` returns `()` and holds no
  trace. Part 5(a) reshapes it to return `{ world, trace }`, and that is where `witness` belongs.
- **The multi-turn conversation loop (a Non-goal).**
  - `session_policy_with_model`'s successor at the `/model` switch is dropped.
  - `derive_session_id(…).id` at the two conversation entries drops its successor.

  Both are the ":3265 class": no deterministic run enters them, and the loop threads no world. **Consequence:** the
  loop's `provider.world` still carries policy init's 12 pending witnesses. Every traced turn re-witnesses them at
  bootstrap, which gives equal ordinals in different frames. That is valid under Part 3, and the queue stays bounded
  because the loop never writes the world back.

## 3. Gate evidence (only gates that ran, tiered)

| Gate | Tier | Result |
|---|---|---|
| `ailang check`: session, phase_vocab, dst_event_vocabulary, scripts/dst/event_vocabulary_dst, scripts/dst/ledger_parity_dst | type/effect | ✓ all 5 |
| `make check_core` | type/effect + boot | ✓ `src/core/ type-check: 60 passed, 0 failed`; `verify_extensions (default): 9 booted, 0 failed` |
| `ailang test`: phase_vocab 28/28 (includes the new golden), dst_event_vocabulary 13/13 (counts 43), session 27/27 | unit | ✓ |
| `make event_vocabulary` | DST | ✓ `vocabulary validates: 43 rows, 43 variants sampled`; `all 43 variants round-trip`; `43 LedgerEvent variants == 43 vocabulary rows == 43 golden-pinned variants` |
| `make terminal_trace` | DST | ✓ `terminal_trace_dst PASS`; `all terminal returns route through c2_finalize` (one `{ result:` literal); capability bypass stays non-zero. Run after every `session.ail` edit |
| `make ledger_parity` | DST (wire vs trace, out of process) | **Red first, then re-pinned.** At the first run the wire side was already green and only the in-process order row failed. Re-pinned to the measured sequences (below). ✓ `ledger_parity wire gate PASS`; **`WorldRequest: projected 148, returned 148`** over the 8 subjects. The census run directly shows both order rows ✓ |
| mutant: RunTools `Done` arm not witnessed | DST (can the gate go red) | **red** (exit 1): the three tool witnesses drain late, at the next step's `witness`, after its `ProviderCallPrepared`; the native order row ✗. Reverted (grep: witness line 1, mutant line 0), re-run ✓, anchors 10/10 |
| `make world_state` | DST | ✓ `world_state_probe PASS`, `exit_code_witness PASS` |
| `make strict_replay` | DST | ✓ `strict_replay_dst PASS`; `discovery and replay agree with the driver's own wire emissions (provider=10, tool=4 over the pair)` |
| `make stream_parity` | DST | ✓ `stream_parity_dst PASS`, `stream_parity wire gate PASS`, including "reordering two real emissions is caught, with the count UNCHANGED". The scripted arm reports `1 finding(s) — clock-balance`. **That finding is pre-existing**: the same script at HEAD `bd0eac7`, in a detached scratch worktree since removed, prints the same line |
| `make journal_resume` | DST | ✓ `journal_resume PASS rows=13`. Includes "SessionResumed is the FIRST record of the resumed frame" (it is still prepended ahead of the frame's bootstrap witnesses) and the digest gate |
| `tools/predicate-anchors/anchors.sh` | anchors | ✓ 10/10 |
| `derive.py` / `--self-test` | inventory | ✓ 24 sites, 0 unresolved, class counts unchanged / ✓ 0 failures |

**Measured order in `native`, re-pinned in `ledger_parity_dst.ail`.** There are 21 `WorldRequest` records:
- 15 bootstrap witnesses (policy init 4 env + 8 limit, then derive env, derive clock, start clock);
- `HistorySeeded`, `ContextLimitResolved`, `ThinkingStreamStart`, `ProviderCallPrepared`;
- 1 witness (model step), then `ThinkingStreamEnd` … `NativeToolCalls`, `V2ToolDispatchStart`,
  `V2ToolDispatchComplete`;
- 3 witnesses (clock, env, tool), then `NativeToolResults` … `ProviderCallPrepared`;
- 1 witness, then … `DoneEvent`;
- 1 witness (the finalize clock), then `RunSummary`.

`capped` has 17: the same 15, one for the model step, **none after `NativeToolDenied`** (nothing ran), then
`CostExhausted`, the finalize clock's witness, and `RunSummary`.

**`HistorySeeded` is now the first journal-class record, not the first record.** ADR-003 D2 requires the former, and
the pin's comment says so.

## 4. Gates NOT run, and why

- **`make dst`: NOT RUN, per the brief (memory ceiling).**
- **`make program_persistence`: NOT RUN.** The token codec and program schema are untouched.
- **Not run, and every traced run now carries more records.** These targets pin trace or wire content and could move:
  `compaction_dst` (includes `runtime_status_tool_dst`), `smoke_parity`, `declared_vs_performed`,
  `driver_only` / `driver_plus_no_ops` / `driver_plus_compose`, `attribution_table`, the phase_c scenario goldens, and
  discovery and corpus.
  - **This is the main unmeasured risk.** Any gate that counts all trace records, compares whole wire lines against a
    golden, or folds the trace into counts would see 15 or more new records per run.
  - The anchors did not move and the table is untouched, so no profile re-issue is due on the anchor axis. A profile
    that pins record counts, though, is not covered by that argument.
- **TypeScript host tests: NOT RUN.** `world_request` is a new wire type for the host. P1B added
  `context_limit_resolved` with no TS change, which suggests unknown types are tolerated. That is argued from precedent,
  not measured.
- **`verify_core` / `verify_classify_check`: NOT RUN.** No new `pure func` was added (`witness` and `witness_drain` are
  effectful), so `new_contract_policy` has nothing to key on. That is argued, not run.
- **The Part 5 red-first runs: NOT RUN.** They are not P2B's work (§2).

## 5. What P2G and P2T consume

1. **The wire line:** `{"type":"world_request","ordinal":N,"class":"<id>"}`, emitted only by `session.witness`, always
   appended alongside. The ids are `env_read`, `file_read`, `clock_read`, `tool_exec` and `model_step`.
2. **Where the frame goes (P2G).** The bootstrap witnesses cover requests made in the **outer** entry functions
   (`run_v2_session_traced` and its siblings), whose `session_policy_init` runs before `run_v2_traced_from_seed`.
   - They are emitted at the inner bootstrap, before `history_seeded`.
   - So `WORLD_RUN_BEGIN` must be printed before the outer entry call.
   - `ordinal0` is the world handed to that call, not the one seen at `HistorySeeded`.
3. **Expected counts for Part 3's fixtures.**
   - Per the census above: native 21, capped 17, and 148 across the 8 `ledger_parity` subjects.
   - The bootstrap alone is 15 on an empty scripted table, and it is data-dependent. P2A §6.7 applies:
     `MOTOKO_PROFILE_DIR` short-circuits two env reads, and `Disabled` skips the catalogue half. A set
     `MOTOKO_SESSION_ID` skips the derive clock.
4. **The END check (P2G).** Every `TracedSessionResult` built by `c2_finalize` has `world.pending == []` (`clocked.world`).
   `c2_suspend` and the resumed entry go through it too. A non-empty `pending` at END therefore means a new unwitnessed
   arrival, which is the red Part 3 wants.
5. **The two red-first sites (P2T/P2D).**
   - **`:3483` (5b).** Call `witness` in the `Err` arm on `capture.next_state`'s advance, threading `trace_after_end`.
     Keep the successor discarded for the red run, then feed it to the `TermProviderFailure` finalize in place of
     `stepped.world`.
   - **`:4535` (5a).** `publish_turn_exit_manifest` needs `session_id` and a trace. Once it returns `{ world, trace }`,
     witness `named_world` there. Also move the publish ahead of `c2_finalize`'s clock, as the plan says.
6. **Part 4's remainder.**
   - Bump the `event_vocabulary_version` string. This is still open, as it was since P1B.
   - `WorldRequest` is already in `ledger_parity`'s required set, because it is Logical and absent from the register.
     "Row 7" is therefore live at 148/148. A dedicated named row is optional.
   - The ADR's "36" is stale; the count is now 43.
7. **Part 6 (P2D).** `derive.py`'s tree scan still does not check witnessed-in-order at the 24 sites. §2's table maps
   each site to its `witness` call. The two hoists removed the only `advance`-inside-a-driver-literal shapes.
8. **Anchor cost is still zero.** All pins are unmoved, and `witness` sits below `:4114`. A Part 5 edit that adds lines
   above `:3893`/`:4114`, which 5(a)'s reordering in `c2_finalize` would, triggers the cascade P2A §6.5 describes.
9. **P2A §5's unbounded-`pending` hazard is closed on traced paths.** `pending` is drained at every arrival. On the
   conversation loop's un-threaded world it is bounded, as §2 explains.
