# PLAN-001 P2A — answer (P2 Part 1: one pure writer)

Branch `arniwesth/013-plan003-and-herdr`, parent `379d806` (P1C). One commit, not pushed.

**Commit hash:** this file is part of the commit, so it cannot quote its own hash. To get it, run
`git log -1 --format=%H -- .motoko/ab/answer-p2a.md`. The orchestrator's reply also gives it.

The working tree also holds other authors' uncommitted edits: `.devcontainer/agent_confined/docker-compose.yml`,
`ailang.lock`, and several untracked paths. **I left them out of the commit.**

## 1. What landed

| Piece | Where | Shape |
|---|---|---|
| `RequestClass` | `src/core/ports.ail`, below `WorldState` | a closed sum with five variants: `EnvRead \| FileRead \| ClockRead \| ToolExec \| ModelStep`. These are P-INV's frozen names (`derive.py`'s `REQUEST_CLASS`) |
| `RequestWitness` | `src/core/ports.ail` | `{ ordinal: int, request_class: RequestClass }` |
| `WorldState` fields | `src/core/ports.ail` | `ordinal: int`, `pending: [RequestWitness]`, appended after `gen` |
| `advance(w, c)` | **new** `src/core/world_ordinal.ail` | pure. Returns `{ w \| ordinal: w.ordinal + 1, pending: w.pending ++ [{ ordinal: w.ordinal + 1, request_class: c }] }`, so the witness goes at the **tail** (request order, which is the order `witness` will drain). The module imports `src/core/ports` and std only. It also owns `request_class_id` / `request_class_of_id`: the ids are `env_read`, `file_read`, `clock_read`, `tool_exec`, `model_step` |
| Three full literals | `empty_world_state` (`ports.ail`), `world_of_json` and `codec_fixture_world` (`ext_world.ail`) | all three carry the two fields. `grep -rn 'holder_ext_id:' --include=*.ail src scripts packages` finds no other full literal; every other construction is a `{ empty_world_state() \| … }` update. The leaf module's tests use `empty_world_state()` rather than a fourth literal |
| Codec | `ext_world.world_json` / `world_of_json` | the `"ordinal"` int and `"pending"` as `[{ordinal, class}]`. **A witness whose class id is unknown is dropped, and the ordinal is kept.** There is no catch-all variant to default it to, and a token that loses a witness this way reads *ahead* of its witnesses, which is Part 3's final-mismatch red |

**Writers, measured.** I grepped for `pending: ` and `ordinal: ` in `src/core` and `scripts/dst`, filtering out
interaction identities, `pending_tool_*` and signatures. The two fields are set only in these places:
- `world_ordinal.ail:35`, which is `advance`, the one production writer.
- The three literals: `ports.ail:766` (`empty_world_state`), `ext_world.ail:595–596` (the decode) and
  `ext_world.ail:756–757` (the codec fixture).
- Test and probe seeds: `world_ordinal.ail:71/:84` (unit tests) and `world_state_probe.ail:799–800` (the seeded world
  for the ordinal row).

### Every helped leaf advances: 24 sites, the inventory unchanged

`python3 tools/driver_leaf_inventory/derive.py` gives the same result before and after: **24 sites, 0 unresolved,
EnvRead=13 FileRead=3 ClockRead=5 ToolExec=2 ModelStep=1**, with the same line numbers in every anchored file.
`advance` runs on the successor the port returned, before that successor reaches anything else.

| File | Sites | How |
|---|---|---|
| `context_usage.ail` | 60, 65, 70, 110, 140, 145, 146, 180 (all 8) | a successor is bound once per read (`explicit_world`, `probe_world`, `read_world`) and used on every branch. No anchor in this file, so the edit is not line-neutral (+8 lines) |
| `tool_phase.ail` | 484 clock, 485 env, 492 tool | `advance` wraps the successor argument of the next port call, and the returned `next_state`. **Line-neutral:** the imports are joined onto line 45, so :388/:389/:484 do not move |
| `test/stub_step.ail` | 712 `dispatch_step` | `{ exchange \| next_state: advance(exchange.next_state, ModelStep) }`. The exchange is still propagated whole. The import is joined onto line 44, so :203 does not move; the 3 added lines are below it |
| `session.ail` | 1687 env, 1690 clock (`derive_session_id`) | 1687 is shadowed on its own line (`let env_id = { env_id \| next_state: advance(…) }`), so the anchored 1690 is **byte-identical**. The clock's successor is advanced in the returned record |
| | 1802 clock (`c2_finalize`) | advanced in the terminal record's `world:` field. The anchored line is untouched |
| | 2308–2311 env ×4 (`session_policy_init`) | each successor is advanced as it is handed to the next read, the fourth as it is handed to `resolve_context_limit_sum` |
| | 3188 approval (`ToolExec`) | `post: { st \| world_state: advance(input.next_state, ToolExec) }` |
| | 3483, the plan's `:2730` | `if not e.retryable then { let capture = env_get(…); …; advance(capture.next_state, EnvRead) } else st.world_state`. **The same conditional request**: the old `&&` short-circuit read the env only on a non-retryable error, and so does this. **The successor is still discarded** (`let _`). This is Part 5(b)'s red-first state, deliberately left for Part 5 |
| | 3893, 4114 clock (both entries) | `let started_world = advance(started.next_state, ClockRead)` joined onto the `session_id` line, and both seed constructors take `started_world`. The anchored lines are untouched |
| | 4535, the plan's `:3385` | `let named_world = advance(named.next_state, EnvRead)` on the same line. The ctx's ports and token take it. **It is still discarded at the function's `()` return**, which is Part 5(a)'s shape, left for Part 5 |

**`session.ail` diff is 18 insertions and 18 deletions.** The imports are joined onto line 200. The bridge span
`1045–1434` that `derive.py` pins is untouched.

## 2. Drift resolved by reading (never stopped)

1. **`class` is a reserved word in AILANG.** `type W = { ordinal: int, class: int }` is a parse error, measured with a probe
   module. The field is therefore **`request_class`**, and the wire key inside the token is still `"class"`.
   - The plan and ADR spell the field `class`. Part 2's `WorldRequest({ ordinal, class })` payload has to take the new
     spelling.
2. **`EnvRead` and `FileRead` share their spellings with the port result records** (`type EnvRead = {…}`,
   `type FileRead = {…}`). A probe measured that the type and the constructor coexist: both `ailang check` clean, both
   import under the one name, and `EnvRead` works as a type and as a value in the same importer. So P-INV's names are
   kept.
3. **"8 in context_usage, 3 in tool_phase, :2730, :3385, dispatch_step" is the plan's "including" list, not the whole
   set.** Both the brief and the plan say "every helped leaf". P-INV's inventory has 10 more in `session.ail`
   (derive_session_id ×2, c2_finalize, session_policy_init ×4, approval, and the two entry clocks). **All 24 advance.**
   - Doing only the listed 14 would have left Part 3's strict +1 gate with gaps by construction.
4. **Line references at `3fe71b0` versus now:**

   | Plan reference | Now |
   |---|---|
   | tool_phase `:413/:414/:421` | 484/485/492 |
   | stub_step `:705–713` | 705–713, the leaf at 712 |
   | session `:2730` | 3483 |
   | session `:3385` | 4535 |
   | `ports.ail:725` | `empty_world_state` at 763, literal ending at 766, after the insertion |
   | `ext_world.ail:544/:651` | `world_of_json` / `codec_fixture_world` |

   The inventory reports "22 direct Ports calls" in `session.ail`. That is 12 helped sites plus the bridge span.
5. **Vocabulary stays at 42.** P2A adds no `LedgerEvent` variant, and `event_vocabulary.ail` was not edited.
6. **011 WI-1's three-commit route does not apply.** Neither field enters the program schema:
   - `dst_program.ail` does not import `ports`, and `InitialWorld` gains nothing.
   - `dst_replay.world_state_of` builds from `{ empty_world_state() | … }`, so a replay starts at ordinal 0 with nothing
     pending.
   - `world_json` is the extension **token** codec. Its consumers are the `ext_ports_of` bridges and `tool_phase`'s
     `on_tool_handle` seam, and no persisted format uses it (`journal.ail` only mentions it in a comment).
   - The plan's "program bytes change, manifest version moves" is Part 4's vocabulary-version bump. Nothing in Part 1
     causes it.
7. **Known reds.** Nothing here reissues a profile or needs `driver_plus_herdr` green:
   - The anchors did not move, and `dst_attribution_table.ail` is untouched.
   - `DST_KNOWN_RED` is untouched.

## 3. Gate evidence (only what ran, tiered)

| Gate | Tier | Result |
|---|---|---|
| `ailang check`, every modified `.ail` (ports, world_ordinal, ext_world, context_usage, tool_phase, test/stub_step, session, scripts/dst/world_state_probe) | type/effect | ✓ all 8 |
| `make check_core` | type/effect + boot probes | ✓ `src/core/ type-check: 60 passed, 0 failed` (59 → 60, the new module); `verify_extensions (default): 9 booted, 0 failed` |
| `ailang test src/core/world_ordinal.ail` | unit | ✓ 3/3: advance +1 with one witness; tail push in request order behind an existing witness; ids round-trip, are distinct, and an unknown id is `None` |
| `ailang test src/core/ext_world.ail` | unit | ✓ 14/14, **2 new**: (a) round trip of ordinal 263 with witnesses `[262 tool_exec, 263 model_step]`, followed by `advance`, must give 264 behind both in order; (b) an unknown class id is dropped and the ordinal kept |
| `ailang test` on context_usage 3/3, tool_phase 12/12, ports 5/5, session 27/27 | unit | ✓ all pass |
| `ailang test src/core/test/stub_step.ail` | unit | exit 1, "No tests found". **The same exit 1 at HEAD `379d806`**, measured in a throwaway worktree. The module has no tests, so this is not a failure |
| `make world_state` | DST | ✓ `world_state_probe PASS`, `exit_code_witness PASS`, AI-withheld poison pair green. It gained one row, `assert_ordinal_class`, detailed below. Re-run after the mutant revert: ✓ |
| `make strict_replay` | DST | ✓ `strict_replay_dst PASS`, and "discovery and replay agree with the driver's own wire emissions (provider=10, tool=4 over the pair)" |
| `make program_persistence` | DST | ✓ `program_persistence_dst PASS` |
| `tools/predicate-anchors/anchors.sh` | anchor check | ✓ all 10 (ext/runtime 199, tool_phase 388/389/484, stub_step 203, session 1431/1690/1802/3893/4114) |
| `derive.py` / `derive.py --self-test` | inventory | ✓ 24 sites, 0 unresolved, class counts unchanged / ✓ 4 fixtures, 0 failures |

**The real-port row, `world_state_probe.assert_ordinal_class`:**
- **Subject.** A world with ordinal 263 and two witnesses goes through `world_to_token` → `token_to_world`, then
  `resolve_context_limit_sum` runs through `scripted_ports()` on an empty table.
  Measured result: `subject=271 [262:tool_exec,263:model_step,264:env_read,265:env_read,266:env_read,267:file_read,268:env_read,269:file_read,270:env_read,271:file_read]`.
- **Control.** The same resolve on a fresh world gives `control=8 [1:env_read … 8:file_read]`, with the same class
  order.

**The mutant can go red.** I set `world_of_json`'s `ordinal:` to the literal `0`:
- The probe went **red**, exit 1: `subject=8 [262:tool_exec,263:model_step,1:env_read,…,8:file_read]`, so the codec
  reset shows as the new reads numbering from 1 behind stale witnesses.
- The control stayed ✓.
- Both new `ext_world` unit rows went ✗ (12/14).
- The mutant was reverted with `grep` evidence, and `make world_state` plus the `ext_world` tests re-ran green.
- Outputs are at `.ailang/p2a-*.out`, which is gitignored.

## 4. Gates NOT run, and why

- **`make dst` (full sweep): NOT RUN, by the brief (memory ceiling).** This means nothing outside the targets above has
  run against this change.
- **`make event_vocabulary`, `make ledger_parity`: NOT RUN.** No `LedgerEvent` variant and no emit were added, so the
  wire and the returned trace are unchanged in kind. That part is argued, not measured. `strict_replay`'s wire-parity
  line is the only wire measurement here.
- **`make compaction_dst` (includes `runtime_status_tool_dst`), `make driver_only` / `driver_plus_no_ops` /
  `driver_plus_compose`, `make attribution_table`: NOT RUN.** They are outside the named set.
  - The anchors are green and the table is untouched, so no profile re-issue is due.
  - **One byte-level risk is unmeasured.** The world **token** now has two more keys, so any fixture that pins
    `ExtCtx.world` token bytes, or a digest over them, would go red. That covers extension token tests and
    declared-vs-performed. I found no such pin by grep (`encode(world_json` / `encode(world_to_token` give no hits), but
    I did not sweep for one.
- **`make verify_core` / `verify_classify_check`: NOT RUN.** `world_ordinal.ail` states no contracts and so counts as
  bare. `context_limit.ail`, the only registered module near this change, is untouched.
- **The Part 5 red-first runs: NOT RUN, not in P2A.** The :3483 and :4535 successors are advanced and still dropped, as
  §1 records.

## 5. Interim hazard, until P2B

**`pending` grows unbounded.** Nothing drains it until Part 2's `witness` lands.
- It grows by one per helped request for the whole run: 8 per context-limit resolve, 3 per native tool call, 1 per
  model step, plus bootstrap.
- It rides in the world token, so every `world_to_token` in a long run encodes O(requests so far) witnesses. The DST
  targets ran in 18–40 s (`world_state`) and 48 s (`strict_replay`). **I have no pre-change baseline**, so this is not
  a no-regression claim.
- It is quadratic over a very long live session. **P2B should land soon after P2A**, or it should be priced if P2B
  slips.

## 6. What P2B consumes

1. **The writer and the ids.**
   - `import src/core/world_ordinal (advance, request_class_id)`, and the constructors from `src/core/ports`.
   - `witness` maps `request_class_id(w.request_class)` into `WorldRequest`, so the class has one spelling on both
     wires.
   - The payload field is `request_class`, not `class`.
2. **The queue contract.** `pending` is in request order (head is the oldest). Every witness's ordinal is its
   predecessor's plus one. The last witness's ordinal equals `ordinal`. `witness` drains head-first and sets
   `pending: []`.
3. **Two advances sit INSIDE a driver record literal today, and `witness` must precede the record (Part 2's rule):**
   - **`session.ail:3197`**: `let post: C2LoopState = { st | world_state: advance(input.next_state, ToolExec) }`. Hoist
     it to `let w = advance(…)`, then witness, then `post`.
   - **`session.ail:1811`**: `c2_finalize`'s terminal `{ result:, …, world: advance(reading.next_state, ClockRead) }`.
     Witness the clock's successor before the literal. Also check `make terminal_trace`'s count of `{ result:`
     literals.
   - Every other `session.ail` advance feeds either a port call or a non-driver return record (`derive_session_id`'s
     `{ id, next_state }`, or the resolvers). `derive.py --self-test`'s `witnessed-after-construction` form is exactly
     this shape.
   - **The tree scan does not yet check advanced-and-witnessed order.** `classify_fixture` runs on fixtures only.
     Part 6 must extend it to the 24 tree sites.
4. **Where successors arrive in `session.ail` with pending witnesses:**
   - `derive_session_id` and the entry clock: `started_world` at 3894 and 4115, the bootstrap chain.
   - `session_policy_init`'s `r_limit.next_state` (4 env + the resolver's reads).
   - `session_policy_with_model`'s resolve.
   - `execute_allowed_tool_call` / `dispatch_tool_entries_with_builtin` returns (the `RunTools` arm).
   - `dispatch_step`'s `exchange.next_state`, at 3429.
   - The approval at 3197, and the finalize clock at 1811.
5. **Anchor cost.** Every `witness` call that adds a line above `session.ail:3893` or `:4114` moves the anchors. That
   means the six-file cascade and a re-issue of the three profiles, and `driver_plus_herdr` is still not re-issued.
   Sequence P2B so that one commit lands the final positions. P2B should not need to touch `tool_phase.ail`, whose
   leaves are already advanced.
6. **Vocabulary 42 → 43** when `WorldRequest` lands. The `event_vocabulary_version` string bump is still open, as P1C
   recorded.
7. **Frame counts for Part 3.** On an empty scripted table one `resolve_context_limit_sum` is **8** requests, in class
   order `env,env,env,file,env,file,env,file`. That is measured by the probe's control row, which is a ready-made
   expected-count witness. The count is data-dependent: `MOTOKO_PROFILE_DIR` short-circuits two env reads, and
   `Disabled` skips the catalogue half.
8. **Two production drops are pre-instrumented for Part 5.**
   - At :3483 the read advances inside a discarded `if`.
   - At :4535 `named_world` is built and discarded at the `()` return.
   - Once P2B's `witness` exists, these are the red-first states the plan asks for. They need no further
     instrumentation.
