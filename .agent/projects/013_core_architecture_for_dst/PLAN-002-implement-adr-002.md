# PLAN-002: implement ADR-002 v4.2 — park and wake

Date: 2026-09-13. Status: **third draft (v3), against REVIEW-plan002-v2 (R1-R11 applied)**,
2026-09-13. Reviews: `REVIEW-plan002-v1-verdicts-claude.md` (*accept with corrections; W4
rejected as written*) and `REVIEW-plan002-v2-verdicts-claude.md` (*accept with corrections*).
Changes 12–14 were applied before v2. v2 applies 1–11 and 15–24; each is cited in place as
"review change N". v3 applies the v2 re-review's R1–R11, each cited in place as "R*N*".
Grounded at: HEAD `d888585749c4c1b6244b91a9f7dcfdbf548b8548` on branch
`arniwesth/013-plan003-and-herdr`. Every code coordinate below is HEAD's unless marked `3ee3d03`.
Governing decision: `ADR-002-park-and-wake.md` v4.2 (Proposed). Its code coordinates are pinned
at `3ee3d03`.
Review basis:
- `REVIEW-adr002-v4-verdicts-fable.md` (v4, HEAD `3ee3d03`): *accept with corrections*.
- `REVIEW-adr002-v4.1-v4.2-delta-verdicts-claude.md` (delta, HEAD `d888585`): *accept with
  corrections; steps 1–5 writable*.

This plan applies the delta review's five required changes as ground truth (§1). It
re-decides nothing in the ADR. Where the ADR text is stale against HEAD, or silent on
something, the row is marked **ADR text residual, plan pins HEAD behavior**.

**Thesis.** An orchestrator that waits on a delegate today pays one provider call per look,
which is the `DelegateCheck` heartbeat. DST cannot see that cost, because DST erases duration.
After this plan:
- Waiting is a step-machine state. `open_waits` sits in the loop state, and `decide` returns
  `Park` when a stop-class candidate arrives while waits are open.
- A port serves the wait: `wake_read`, with the same replay set approval has.
- Completion is a runtime act. A `done` run state, host-owned answer publication, and a
  one-shot exit.

The polling cost becomes a count of discrete transitions, which a fixture can assert.

**The number this plan is judged on** (ADR TL;DR, Consequences): the specified success path
costs **exactly 4 provider calls**, verification excluded:
1. `Delegate`
2. the stop-class response that elects `Park`
3. `DelegateCheck` after the wake
4. the final answer

A verified path costs **at least 5** and is reported separately. Step 4 asserts this in the
success fixture and measures it once live. The measured turn behind the ADR cost 195.

---

## 0. Preconditions, sequencing and standing rules

### 0.1 Sequencing dependencies (state at `d888585`)

| dependency | state at HEAD | evidence | consumed by |
|---|---|---|---|
| PLAN-003 P1 `RunIdentity` | **landed; consumed, not built** | `journal.ail:80–84` (`RunIdentity { session_id, run_id, profile }`); imported `session.ail:173–174`; threaded as `c2_loop(…, identity: RunIdentity, …)` `session.ail:2985`, param `:2998`; `run_id_for` builds `<session_id>.r<resume_count>.<run_ordinal>` `:4269–4271`; `loop_run_identity` defined at `:4274`, called in the `user_message` arm at `:4404` | step 4 (`request_id`), step 5 (between-turn `run_id`) |
| PLAN-001 P2 (world ordinal, witness, framed wire) | **landed and green** | `WorldState.ordinal`/`pending` `ports.ail:493–494`; `advance` `world_ordinal.ail:33–36`; five classes `:41–61`; `witness` `session.ail:4163`; `make world_framed_wire` `Makefile:361–364`, in `DST_TARGETS` `:491` | step 3 (default is `advance` only), step 4 (the call site owes a witness) |
| PLAN-003 P3ORD (cross-run ordinal continuity on resume) | landed (`d888585`) | `run_summary.world_ordinal`; `BEGIN₂.ordinal₀ == END₁.final` in `journal_resume_dst` (`Makefile:307–318`) | step 5 (the frame-identity rule has an implemented precedent) |
| step 4's gate held for **one live parked run** | not yet | — | step 5 starts after it |
| step 5 | not yet | — | **ADR-003 D7** (PLAN-003 P4) starts after it; `--park-exits` stays off until one live parked session has resumed |

Step order is D5's and no other: 1 → 2 → 3 → 4 → 5, then ADR-003 D7. Step 1 (host and
extension) shares no files with step 2 (core plus the `ExtCtx` literal sweep, which does not
touch `motoko-ext-herdr` or `src/tui`; W2 Part 1), so the two may run in parallel. They share
one test, W2 gate 6. Step 3 needs
step 2's `WaitDescriptor` type. Step 4 needs 2 and 3.

### 0.2 Standing rules

1. **The sweep (ADR-001 D6).** Run `make dst DST_JOBS=1` at the branch point before each
   boundary-editing step (2, 3, 4, 5), and disclose it per PLAN-001 §1. Known red at HEAD:
   `DST_KNOWN_RED := depth_canary driver_plus_herdr herdr_graded` (`Makefile:655`).
   `herdr_graded` is the only DST script that reaches the extension. Its run clauses are
   green and its "profile record loads clean" clause is red (delta review §2). Steps 1 and 4
   read its run clauses as their extension gate and do not claim the target green. **This
   draft ran no sweep.**
2. **The anchor cascade.** Every edit to `session.ail`, `tool_phase.ail` or `stub_step.ail`
   above the pinned anchors is followed by `make anchors`, re-baselined in the same commit.
   Steps 2, 4 and 5 move anchors.
3. **The vocabulary gate.** `make event_vocabulary` (`Makefile:1473`) needs one row and one
   golden per `LedgerEvent` variant, landed in the same commit as the variant. HEAD has 43
   variants (`dst_event_vocabulary.ail:9`). Only step 4 adds variants (two).
4. **Tests.**
   - Core: `ailang test <module>` for each module touched.
   - DST: the named Make targets.
   - Host: `bun run test` and `tsc` in `src/tui`.
   - Extension: `ailang test packages/motoko-ext-herdr/herdr.ail`.
5. **One commit per work item**, each naming the ADR decision it lands (`ADR-002 D2: …`).
   Nothing is pushed by this plan.
6. **Blank means `trim(candidate) == ""`.** Every site that owns blank already agrees:
   - `empty_stop_guard.ail:8–10` (`is_blank`)
   - `progress_contract_guard.ail:204`
   - the core floor at `session.ail:3058`
7. **What the deterministic harness cannot see.** Deterministic runs drive the traced entry
   directly and never reach `conversation_loop_v2_with_policy` (`session.ail:4294–4507`;
   PLAN-003 §0.6). So:
   - the between-turn work in step 5 is gated by pure unit tests plus a live probe that
     drives `rpc.main` with a held-open stdin and reads stdout (PLAN-003 P1 Part 6's shape);
   - herdr state observations in step 4 are gated live;
   - DST gains no wall clock. What becomes checkable is the **count and order** of provider
     calls across a park (ADR Consequences, "What still is not testable").

---

## 1. ADR text vs HEAD: what this plan pins

Rows 1–5 are the delta review's required changes, applied as plan-time ground truth. Rows
6–14 were found while drafting. None reopens a decision.

| # | ADR says | HEAD / plan pins | source |
|---|---|---|---|
| 1 | D5 step 3: before P2 the unbound default returns the world unchanged; with or after P2 it returns `advance(world, WakeRead)`; "no `ordinal` on `WorldState` at HEAD" (`:553–563`, TL;DR `:205`, history `:149–152`) | **ADR text residual, plan pins HEAD behavior.** P2 has landed (`ports.ail:493–494`, `world_ordinal.ail:33–36`). The default is the **`advance` variant only**. Step 3 also flips the two landed negative tests (`world_ordinal.ail:112`; `ext_world.ail:811–823`) and edits `derive.py:21` (freeze note) and `:164` (`REQUEST_CLASS`). | delta req. 1 |
| 2 | D2: "no fixture that reaches this arm enables a verifier" (`:355–357`, history `:158–160`) | **ADR text residual.** Two fixtures do: `ledger_parity_dst.ail:260–263` (`dp7_rt`, `exit 3`) with scenario `:493–500`, and `smoke_v2_dp7_gate.ail:38–41` (`enabled_rt`). Both have `registry: { entries: [] }`, so their decision sequences are order-invariant. They are **step 2's regression gate**. "Fixtures do not move" still holds. | delta req. 2 |
| 3 | v4.2 Consequences: "`Park` with a request id out of `decide`" (`:627–628`) | **ADR text residual.** `Park` carries **only the waits**. The driver builds the `ParkRequest` from `RunIdentity` plus a per-run `park_ordinal` in `C2LoopState` (`:376–380`). `StepState` (`phase_vocab.ail:424–434`) gains no `run_id` and no ordinal. | delta req. 3 |
| 4 | Context and v4.2: `HERDR_CHECK_WAIT_MS` is 20 s, "N x 20 s" (`:230`, `:614`, `:623`) | **ADR text residual.** Default **45 s** since `5f73d8f`: `register.ail:173`, `parse_int_or(getEnvOr("HERDR_CHECK_WAIT_MS", "45000"), 45000)`. The argument is unaffected. | delta req. 4 |
| 5 | Coordinates at `3ee3d03` (`:25–26`, `:692–708`) | **Plan cites HEAD.** Map in §9. | delta req. 5 |
| 6 | "blank" undefined (`:340–342`) | Plan pins `trim(candidate) == ""` (§0.2 rule 6). | delta §2 D2 |
| 7 | Stage 5 routes a candidate with no waits and silent policy to `dp7_approved`/`dp7_fail_open` → `Finalize`. The ADR does not say whether a **blank** candidate that clears stage 4 is verified. | **ADR text residual, plan pins HEAD behavior.** The ADR's "a blank one goes to stage 3 or 4 **as today**" (`:156–158`) is read literally. A blank candidate that clears stage 4 still enters `c2_after_dp7` (`session.ail:2883`, verifier call `:2922`), as it does at HEAD through `:3794`. Only non-blank candidates skip it, because stage 2 already judged them. The verifier runs **at most once per candidate** either way. Decided by the owner 2026-09-13 (§8.1: verify). | drafting |
| 8 | D2's table: `WorldState.wakes: [WakeInput]`, but "successor built by the adapter (a fixture supplies observations, never whole worlds)" (`:427`). `WakeInput` carries `next_state: WorldState`. | **ADR text residual.** Taken literally the type is recursive (`WorldState ∋ [WakeInput] ∋ WorldState`) and contradicts the prose. The plan pins the prose: the cursor element is `WakeObservation = { request_id, wait_id, outcome }`, and the adapter builds `WakeInput` with `next_state`. **This is a type decision, not only a residual.** It changes the element type of a cursor the ADR declares, decided by the owner 2026-09-13 (§8.6), before W3 Part 1 lands (review change 10). | drafting |
| 9 | D3 lists `meta_timed` as six keys (`:166–167`, `:478`) | **ADR text residual.** HEAD `herdr.ail:199–206` has seven, adding `elapsed_is_exact` (`:205`). `settled` is still absent, so "new" is still true. | delta §1 row 4 |
| 10 | D1.1: "ADR-003 D2 adds a sibling `suspended` state" (`:286`) | **ADR text residual (landed).** `suspended` is already in `RunState` (`ui.ts:798`) and `MotokoRunState` (`herdr-agent-state.ts:43`), mapped to herdr `blocked` (`:100–101`). `done` joins six-member unions. | drafting |
| 11 | D4/D5 step 5: threading `traced.world` into the loop is "the largest single piece of the debt" (`:519–520`) | **ADR text residual.** The loop already holds a world slot: `provider: PortedProvider` (`session.ail:4307`), whose `provider.world` is read at `:4371` and seeded at `:4638`, `:4674`, `:4830`. The `user_message` arm drops `traced.world` after `publish_turn_exit_manifest` (`let _ =` at `:4463`) and recurses on the pre-turn `provider` (`:4484`, `:4491`, `:4498`). The initial turn drops its successor the same way: `let _ = publish_turn_exit_manifest(…)` at `:4723`, after which the loop is entered with `started_provider` (`:4759`, the world before turn 1) or `live_provider` (`:4755`, `:4766`, the world before policy init). Step 5 prices this at HEAD (W5(c), W5 gate 2). | delta §1 row 5; review §2 row 11 |
| 12 | D5 lists steps 1–5; TL;DR D5 says "D1 **and D3's producer** now" (`:205`); step 1's text says only D1 (`:542`) | **ADR text residual (internal).** The plan puts D3's producer (`wait` on `Delegate`'s metadata, `settled` on `DelegateCheck`'s) in step 1's extension commit, per the TL;DR. The consumer lands in step 2. | drafting |
| 13 | D5 step 2: registration **and** "`classify_candidate` … with `open_waits` always empty" (`:543–546`) | **ADR text residual (internal).** If registration is live, `open_waits` is not empty. The plan reads "always empty" as "stage 3 is inert". Step 2 registers waits, carries them, and projects them to `StepState` and `ExtCtx`. `classify_candidate` treats them as empty, and the guard does not read the field, until step 4. | drafting |
| 14 | O5 is the fallback "if D2's surface slips past P2" (`:273`, `:668–669`) | **ADR text residual.** P2 landed before step 3 began, so the literal trigger has already fired. The plan does not start O5 on that. It names O5 ready to schedule, on the trigger in W-O5, decided by the owner 2026-09-13 (§8.2). | drafting |

Also carried, not residuals:
- `dp7_fail_open` still has **no producer**. Its only occurrences are the class at
  `step_machine.ail:130` and the test at `:374–381`. It stays in the stop class for that test.
- The v4.2 paragraph's `herdr_graded` is `DST_KNOWN_RED` at HEAD.
- The ADR's handoff precondition, "PLAN-003 P1 must land first", is met (§0.1).

---

## 2. Work items, in D5 order

| item | D5 step | scope | estimate (plan's split of the ADR's prices) |
|---|---|---|---|
| W1a | 1 | herdr `--message` on an idle row: the probe | ½ day, live |
| W1b | 1 | D1 host + extension; D3's producer (§1 row 12) | 2–3 days, host + extension |
| W2 | 2 | D3 consumer and registration; `open_waits` in loop, step state and `ExtCtx` (an extension ABI change, 7.3 → 7.4); the `classify_candidate` refactor with stage 3 inert | 5–7 days, core + extension ABI (37 `ExtCtx` literals in 28 files; review change 4) |
| W3 | 3 | the `Ports` field and unbound default; wake types; `wakes` cursor and codec; three literals; scanner recognition and mutant; two negative-test flips | 2–3 days, core + tools |
| W4 | 4 | activation: stage 3, `Park`, host protocol, adapters, identity, two events, fixtures, live 4-call measurement | 8–11 days, core + host |
| W5 | 5 | D4's framing and identity subset | 3–4 days (re-priced at HEAD after review changes 19–21, §1 row 11; W5 "Price") |
| W-O5 | fallback | `DelegateAwait` | 1–2 days, extension |

ADR prices: D1 is 2–3 days, D2 is 9–13 days after the surface exists, D3 is 3–4 days. W2–W4
together are the plan's split of D2 plus D3's core share.

---

### W1a — Step 1, first item: the herdr message probe (½ day)

**Question** (ADR D1.1, "Not decided"): does herdr display `--message "done"` on an `idle`
agent row?

**Procedure.**
1. In a herdr pane, issue the report the reporter would issue, built by `buildReportArgs`
   (`herdr-agent-state.ts:321`) for `{ state: "idle", message: "done" }`.
2. Read the row back three ways: `herdr agent get <pane>`, the list view, and the pane
   decoration.
3. Repeat with `state: "blocked"` plus a message, as the positive control. `suspended`
   already uses that shape (`:100–101`).
4. Record the herdr version and binary path (`HERDR_BIN_PATH`).

**Gate.** A §7 results entry with the raw `agent get` output for both reports.
- If herdr shows the idle message, D1.1 is observable from outside.
- If it drops it, D1.1 is unchanged: `done` still exists "so Motoko's own display stops
  conflating" (`:284–286`). The result is recorded against ADR "Not decided".

The probe decides nothing in the ADR.

### W1b — Step 1, second item: D1 host + extension, and D3's producer (2–3 days)

**D1.1 `done` run state** (host).
- Add `"done"` to `RunState` (`ui.ts:798`) and `MotokoRunState` (`herdr-agent-state.ts:43`).
- Enter it on the runtime's `done` event (`ui.ts:2744`). Leave it on the next input.
- `mapRunState` (`herdr-agent-state.ts:90–103`) maps it to `{ state: "idle", message: "done" }`.

**D1.2 `--answer-file <path>`** (host).
- Flag parsing sits beside `--headless` (`index.ts:613–632`).
- The writer is one host function, called from **both** runtime callbacks before `done` is
  forwarded (review change 3):
  - **plain/JSONL (non-TTY) path:** inside the terminal-event branch, after `logger.close()`
    resolves and before `ui.handleEvent(event)` (`src/tui/src/index.ts:979–984`);
  - **interactive one-shot (TTY) path:** in `spawnRuntimeProcess`'s event callback
    (`index.ts:1017–1054`), after `logger.log(event)` and before `ui.handleEvent(event)`
    (`:1052–1053`), taken only when the run is an `--answer-file` one-shot. At HEAD the TTY
    path never exits on `done`: `ui.ts:2744–2765` sets `taskDone` and returns focus to input.
    So the one-shot exit is taken at this site (D1.3's `--oneshot`), **only after publication
    and after `logger.close()` resolves** (R4). This mirrors the non-TTY forward
    (`index.ts:979–983`: `void logger.close().then(() => { ui.handleEvent(event); })`), whose
    comment (`:974–978`) records that `process.exit` otherwise drops the buffered tail
    (`run_summary`, `done`), and `ADR-002:288` ("awaits logger closure before forwarding
    terminal events"). The synchronous `logger.log(event)` at `:1052` is not a drain.

  Both run before exit actions and before reporter release (`herdr-agent-state.ts:306–309`,
  `:338`).
  **Re-locate before editing:** the ADR's `index.ts:820–827` (exit-action registration) and
  `:870–883` (callback) are `3ee3d03` coordinates and have moved.
- Atomic write: temp file, then rename.
- Rules, verbatim from the ADR:
  - an existing non-empty file wins;
  - a non-empty `done` output is written otherwise;
  - an empty `done`, a runtime `error`, an `abort`, or a publication failure writes nothing;
  - in an `--answer-file` one-shot, those four cases exit non-zero with the reason on stderr.
- Interactive turn errors keep re-entering the loop. At HEAD that is `ui.ts:2770` `case "error"`
  and the `Err(e)` arm at `session.ail:4492–4499`.
- Neither order changes: trace `DoneEvent` (`session.ail:3069–3070`) before `RunSummary`
  (`c2_finalize` `:3075`); stdout emit `done` at `:3076`.

**D1.3 one-shot** (host + extension).
- `--headless` (`index.ts:598` exits on `done`) is the plain/JSONL one-shot path. `--oneshot`
  is added as the **interactive** one-shot: TTY display, exit after `done`'s publication and
  the logger's drain at the TTY callback site (D1.2; R4). The gate's interactive one-shot case needs this entry (ADR D1 tests,
  `ADR-002:312–314`; review change 3).
- The extension's motoko launch passes `--answer-file` (`do_delegate`, `herdr.ail:1151`;
  motoko metadata site `:1322`). The task text that asks the model to write the answer file
  (ADR `types.ail:706–718`, re-locate) stays, since the host's rule is "existing non-empty
  file wins".

**D1.4 re-read before `lost`** (extension). `do_check_motoko` (`herdr.ail:1432`), the
`agent get` failure branch (`:1466–1478`), today settles `lost` under `means_agent_gone`
(`:1470–1474`) with no second read.
- Add one `p.file_read` of the answer path before `dagr_settle(… "lost" …)`.
- If the re-read finds content, take the answer branch's close-and-settle `done`, the shape
  of `:1441–1463`.
- The non-gone error branch (`:1475–1476`) is unchanged: it writes nothing and returns
  `err_result`.

**D3 producer** (extension, §1 row 12).
- `Delegate`'s success metadata (`meta_kind`, `herdr.ail:191–195`; call sites `:1322`,
  `:1403`) gains `wait`, a JSON `DelegateWait { id, delegate_kind, locator: { pane },
  answer_path, run_key }`. `run_key` names a retry when `retry_of` is linked (`dagr_open`
  `:698`).
- **The matching key (review change 2).** `DelegateWait.id` is the delegate **handle**. That is
  the string `meta_kind` already writes as `delegate`:
  - for motoko, the handle `h` from `motoko_handle` (`:1310`), passed at `:1322`;
  - for claude/codex, `name`, passed at `:1403`.

  It is also the string the model passes back as `DelegateCheck`'s `name` (`:1540`). A check is
  matched to its wait by `metadata.delegate` (`meta_timed`, `:201`) `== DelegateWait.id`. No
  separate `wait_id` key is added to the check's metadata. W2 Part 3's lifecycle rows use this
  key.
- `DelegateCheck`'s metadata gains `settled: bool`. It is `true` exactly on the `dagr_settle`
  paths and `false` on every other return.
  - **Returns that already carry `meta_timed`** (`:199–206`) gain the key:

    | return | lines | `settled` |
    |---|---|---|
    | early answer | `:1441–1463` | `true` |
    | post-wait answer | `:1489–1500` | `true` |
    | post-wait lost | `:1505–1517` | `true` |
    | not yet | `:1518–1532` | `false` |
  - **The `agent get` failure branch gains metadata (review change 1).** In `do_check_motoko`'s
    branch (`:1466–1478`), two arms return `err_result(call.id, "DelegateCheck", …)` (`:1476`):
    - the gone-and-lost arm, which settles first (`dagr_settle … "lost"`, `:1470–1474`);
    - the error-only arm (`:1475`).

    `err_result` (`:244–247`) sets `metadata: jo([])`. Both arms instead return the same envelope
    with `meta_timed(handle, pane, t0.now_ms, 0)` plus `settled`: `true` on the gone arm, `false`
    on the error-only arm. That means a metadata-taking variant of `err_result`, or a record
    update of its result. The exit code, stderr and settle are unchanged.
  - **`do_check`'s claude/codex branches get the same treatment** (found while applying
    change 1). They have the same shape: `dagr_settle` then `err_result` at `:1605–1610` and
    `:1621–1626`, plus argument errors at `:1543` and `:1549`. `settled` is `true` where the
    branch settled and `false` otherwise.
    - **Arms with no pane in scope (R11).** The two argument-error arms (`:1543`, empty `name`;
      `:1549`, `owns_name(name) == false`) and the wait-failure arm (`:1610`) have no pane
      bound. There `meta_timed`'s `pane` argument is `""`, and its `delegate` is the raw `name`
      argument.
      - At `:1543` that `name` is `""`, and at `:1549` it is a string this extension never
        returned from `Delegate`. No registered `DelegateWait.id` equals either, so W2 Part 3's
        lifecycle never matches them, and both arms carry `settled: false`.
      - At `:1610` the raw `name` is a claude/codex handle, so it can equal a wait's id. The
        rule above still decides: `settled: true` when the arm settled `lost` (`:1605`) and
        `false` otherwise, so the lifecycle removes or keeps the wait accordingly.
- Both are additive to the Json envelope (`tool_contract.ail:13–20`), with no ABI sum change.
  Nothing reads them until W2.

**Gate (W1b).**
- Host (`bun run test`, `tsc`). The ADR's D1 test list:
  - publication before exit actions and before release, with an existing report and with an
    unwritable destination;
  - empty `done` and error produce no file, and a non-zero exit in one-shot only;
  - an interactive turn error still re-enters the loop;
  - both the plain/JSONL and interactive one-shot paths;
  - **the interactive one-shot exits only after the logger drains** (R4): `run_summary` and
    `done` are both present in the session log file when the process exits, on the TTY
    `--oneshot --answer-file` path as on the non-TTY one;
  - `mapRunState("done")`.
- Extension (`ailang test packages/motoko-ext-herdr/herdr.ail`):
  - the re-read settles `done` when the answer appears between the two reads, and `lost`
    when it does not;
  - `settled` is present on **every** `DelegateCheck` return, in both `do_check_motoko` and
    `do_check`. It is `true` on each settle path, including the gone-and-lost `err_result`
    branch, which now carries metadata. It is `false` on the error-only and not-yet paths
    (review change 1);
  - a check's `metadata.delegate` equals the `wait.id` of the `Delegate` that returned that
    handle (review change 2);
  - `wait` is present on a successful `Delegate` and absent on a failed launch;
  - the argument-error arms (`:1543`, `:1549`) carry `pane_id: ""`, `delegate` equal to the raw
    `name`, and `settled: false` (R11).
- `herdr_graded`'s run clauses stay green. If the extra `file_read` shifts its scripted
  effect queue, it is re-scripted in the same commit with the reason.
- W2 gate 6's JSON fixtures are captured and committed under `packages/motoko-ext-herdr/`.
- No core file is touched, **without exception** (R7): W1b ships only the gate-6 JSON fixtures,
  and the core test that decodes them is not W1b's (W2 gate 6).

---

### W2 — Step 2: consumer, registration, and the `classify_candidate` refactor (5–7 days, core + extension ABI)

**Part 1: the descriptor type and state fields.**
- `WaitDescriptor = DelegateWait({ id, delegate_kind, locator: { pane }, answer_path,
  run_key }) | OperatorWait({ id }) | TimerWait({ id, deadline_ms })` goes in
  `phase_vocab.ail`, beside `StepState`. `ports.ail` already imports `phase_vocab`
  (`ports.ail:44`), so W3's `ParkRequest` can use it without a cycle.
- Add a strict JSON decoder returning `Result`.
- `C2LoopState` (`session.ail:509–569`) gains `open_waits: [WaitDescriptor]`.
- `StepState` (`phase_vocab.ail:424–434`) gains `open_waits`.
- `c2_step_state` (`session.ail:926–940`) projects it.
- **Literal counts at HEAD (review change 5).** Every full literal gains the field. Record
  updates (`{ st | … }`) inherit it and are not edited.
  - **`C2LoopState`: 17 full literals.** The type's own comment (`session.ail:558–559`) counts
    "the fifteen in the loop, the two constructors and the two test literals".
    - Of the fifteen, 13 are full `let next_state: C2LoopState = {` literals: `:2804`, `:2853`,
      `:2928`, `:2957`, `:3088`, `:3148`, `:3303`, `:3490`, `:3582`, `:3630`, `:3691`, `:3732`,
      `:3769`. The other 2 are record updates (`:3197`, `:3231`).
    - Constructors: `c2_initial_state_with_counts` (`:951`) and `c2_state_from_continuation`
      (`:2591`).
    - Test literals: `:5067`, `:5120`.
  - **`StepState`: 10 full literals.**
    - Core: `mk_state_with_messages` (`step_machine.ail:173`, literal `:176`), `c2_step_state`
      (`session.ail:926–940`), and the `phase_vocab.ail` test at `:1595`.
    - Scripts: `scripts/dst/phase_c_l1_scenarios.ail:148`, `:297`, `:329`, `:451`;
      `scripts/dst/phase_c_seeded_dst.ail:158`; `scripts/phase_f_pipeline_wiring.ail:65`; and
      the tracked `scratchpad/verify_guard.ail:40`.
    - The `decide` tests build `StepState` through `mk_state` (`:190`), which delegates to
      `mk_state_with_messages`. Both sit outside `:258–408`, so the fifteen test bodies do not
      change (gate 1).

  The type checker gives the final count. A literal it finds that this list misses is named in
  the commit message.
- **`ExtCtx.open_waits` is an extension ABI change**, declared here in W2 rather than moved to
  W4 (review change 4). `ExtCtx` (`packages/motoko-ext-abi/types.ail:536`) gains `open_waits`
  beside `work_in_flight` (`:587`), the ABI 7.3 precedent (`:580`).
  - **Type: `Json`.** The ABI module imports only `std/option` and `std/json`
    (`types.ail:12–13`), so it cannot name `phase_vocab`'s `WaitDescriptor`.
    - The field is a JSON array of the D3 wire objects W1b produces, encoded by the core from the
      typed `open_waits`. An empty array means no open waits.
    - No ABI-local mirror type is added. The wire shape keeps one owner, the core's strict
      decoder (Part 1).
  - **Version bump:** `packages/motoko-ext-abi/ailang.toml` goes from `version = "7.3"` to
    `"7.4"`, with a `7.4:` comment at the field in the style of `:580`. The bump **relocks
    `ailang.lock`** in the same commit: its `sunholo/motoko_ext_abi` entry pins
    `"version": "7.3"` (`ailang.lock:75–77` at HEAD), which becomes `"7.4"` with the new
    content and interface hashes (R6).
  - **Filled** where `work_in_flight` is (`session.ail:1883`, `:1907`). No guard reads it until
    W4.
  - **Every full `ExtCtx` literal gains the field.** A `state_key:` grep finds 38 lines in 29
    files. Minus the type declaration (`types.ail:548`), that is 37 literals in 28 files:

    | where | files | literals | files named |
    |---|---|---|---|
    | packages | 7 | 12 | `motoko-ext-compaction-ai/_smoke.ail`; `motoko-ext-compaction-ai/compaction_ai.ail`; `motoko-ext-compaction-structural/compaction_structural.ail`; `motoko-ext-context-mode/context_mode.ail` (6); `motoko-ext-empty-stop-guard/empty_stop_guard.ail`; `motoko-ext-progress-contract-guard/progress_contract_guard.ail`; `motoko_ext_conformance/harness.ail` |
    | `scripts/dst/` | 6 | 7 | `compaction_policy_dst`; `compaction_seeded_dst`; `compose_live_exec`; `declared_vs_performed`; `hook_guard_dst`; `long_qwen_compaction_dst` (2) |
    | `scripts/` | 12 | 12 | `smoke_v2_compaction_chain`; `smoke_v2_handle`; `smoke_v2_pending`; `smoke_v2_policy_denial`; `verify_delegate_kind_required`; `verify_exit_intent`; `verify_herdr_orchestrator`; `verify_mot131_early_answer`; `verify_mot133_owner_tag`; `verify_mot136_dagr_producer`; `verify_mot137_dagr_pane`; `verify_repetition_guard` |
    | core | 3 | 6 | `src/core/ext/runtime.ail`; `src/core/rpc.ail` (3); `src/core/session.ail` (2, including `publish_turn_exit_manifest` `:4584–4606`) |
  - W1b's files (`packages/motoko-ext-herdr`, `src/tui`) are not in this list, so W1b and W2
    still share no file (§0.1).
  - **Re-priced:** +1 day over v1 for the literal sweep, the bump and the package tests. W2 is
    5–7 days (§2).

**Part 2: consumer.**
- `execute_allowed_tool_call`'s `Handled` arm (`tool_phase.ail:439–449`) validates and
  extracts `metadata.wait` from `result_env` **before** `handled_tool_message` (`:449`;
  `phase_vocab.ail:1344–1352` → `result_env_model_content` `:1309–1311` → cap
  `cap_tool_message_content` `:1274–1283`).
- The typed result rides the tool fold into `open_waits`. The model message is never
  re-decoded.
- An invalid `wait` registers nothing and leaves a diagnostic in the tool result's trace
  event.

**Part 3: the lifecycle rows that need no wake** (ADR D3 table):

| event | effect |
|---|---|
| `Delegate` succeeds | register |
| `Delegate` fails | nothing |
| re-delegation | new wait with a new id; the old one stays |
| `DelegateCheck` with `settled: true` | remove the wait whose `id == metadata.delegate` (W1b's matching key, review change 2) |
| check that returns an error without settling | keep |
| check that settles an already-removed wait | idempotent |
| gone, then second read fails | `lost`, settles, remove |
| run ends | cleared |

Implement as a pure `apply_tool_lifecycle(open_waits, call, result_env) -> [WaitDescriptor]`
with unit tests per row. The wake rows are W4's.

**Part 4: `classify_candidate`.**
- Refactor the `CallModel` arm's no-tool-calls branch (`session.ail:3716–3797`) into one
  effectful function, `classify_candidate` (`{Process, IO, Clock, Trace}`, the union of
  `dispatch_solver_candidate` `ext/runtime.ail:721` and `dp7_rejection_errors`
  `session.ail:2243`).
- Stages, in this order and no other:
  1. **pending**: unchanged upstream (tool calls or pending approval never reach this branch).
  2. **DP7**: if `trim(candidate) != ""`, call `dp7_rejection_errors` (`:2243–2255`).
     `Some(rejection)` builds the `dp7_rejected` state, identical in content to today's
     `c2_after_dp7` rejection arm (`:2922–2950`), and returns **before** any solver dispatch.
  3. **waits**: **inert in W2** (§1 row 13).
  4. **completion policy**: `dispatch_solver_candidate` (`:3721`), then `solver_feedback`
     (`:3725–3756`), then the persist nudge (`:3758–3792`), as today.
  5. **finalize**: a non-blank candidate goes to the approved half of `c2_after_dp7`
     without re-running the verifier. A **blank** candidate goes through `c2_after_dp7`
     whole, as at HEAD (§1 row 7).
- `c2_after_dp7` (`session.ail:2883`) is split into its verifier call and its approved-state
  builder so stage 2 and stage 5 share the builders.
- **The world the stage-2 rejection arm carries.** Today it is
  `token_to_world(finalized.next_state)`, the solver's successor after `clear_holder`
  (`ext/runtime.ail:727`). Under stage 2 the solver has not run. The arm must carry what
  HEAD's empty-registry path carries, whether or not that needs `clear_holder`.
  `ledger_parity` frames its runs on the wire (P2G `c1bc518`), so any difference shows red
  there. At HEAD the rejection arm's world is `token_to_world(clear_holder(collected.next_state))`
  (`ext/runtime.ail:722`, `:727`; `session.ail:3724`/`:3794`). The implementer confirms which
  expression reproduces it, and records it in the commit message **and as a §7 entry at T3**
  (delta review §1 residual 2; review change 23).

**Gate (W2)**, all of it:
1. **The fifteen `decide` tests are unchanged.** `ailang test src/core/step_machine.ail` is
   green, and `git diff` shows no change to the test bodies in `step_machine.ail:258–408`
   (tests at `:258`, `:268`, `:280`, `:292`, `:302`, `:316`, `:325`, `:334`, `:347`, `:356`,
   `:365`, `:374`, `:383`, `:392`, `:401`). `decide` (`:116–141`) itself is unchanged in W2.
2. **DP7-before-solver cases**, driver-level (since `classify_candidate` is effectful).
   - **Where:** `scripts/dst/phase_c2_wiring_scenarios.ail`, run by the host target
     `make phase_c_l1` (`Makefile:386–389`, in `DST_TARGETS` at `:483`), or a sibling script
     added to that target's recipe.
   - **Why each case names its setup:** today that script runs only `empty_rt()` or
     verification-disabled runtimes (review change 6).

   | case | scenario | expected | registers / settings | verifier |
   |---|---|---|---|---|
   | (a) | a candidate the solver would bounce **and** DP7 rejects (the ADR's named case) | the next injection is the DP7 rejection; no `ExtSolverFeedback` recorded | a `ContinueWithFeedback` solver: a test extension whose completion decision is feedback on every candidate | `exit 3` |
   | (b) | DP7 approves, then the solver gives feedback | feedback as today | the same feedback solver | `true` |
   | (c) | a persist-nudge candidate DP7 rejects | rejection; no `PersistNudge` | persist nudge **enabled**: `persist_retries > 0` (off by default, `MOTOKO_PERSIST_RETRIES=0`, `session.ail:2262–2263`); no solver | `exit 3` |
   | (d) | a blank candidate | the empty-stop guard's feedback; no `Dp7VerifierRejected` at stage 2 | **`empty_stop_guard` registered** (`packages/motoko-ext-empty-stop-guard`) | `exit 3` |
   | (e) | a multi-step run | at most one `Dp7VerifierRejected` per model step | the feedback solver for the first step, accepting after it | `exit 3` |

   Every case uses a verifier-enabled runtime (`enabled: true`, with the command shown).
3. **Regression only, not proof of order** (review change 6). Both fixtures have empty
   registries, so their decision sequences are order-invariant *by construction*. They cannot
   go red on a DP7/solver ordering bug; only gate 2 proves the order. `make ledger_parity` (`ledger_parity_dst.ail:260–263`,
   scenario `:493–500`, wire-framed) and `make smoke_driver` (`smoke_v2_dp7_gate.ail:38–41`,
   run by `Makefile:2314–2317`) are both green with **unchanged decision sequences** and
   unchanged wire frames. The world question in Part 4 is read off `ledger_parity`'s frames.
4. `phase_c2_wiring_scenarios` decision sequences are unchanged (verification disabled,
   `stub_step.ail:788–791`).
5. **Registration.**
   - A `Handled` envelope with a valid `wait` and content over 65 536 bytes registers the
     wait even though the model message is truncated.
   - A malformed `wait` registers nothing.
   - `settled: true` removes the matching wait; the error-only check keeps it.
   - The Part 3 table is unit-tested row by row.
6. **Cross-producer check** (review change 7; R7). W1b and W2 may run in parallel, so they share
   this one test. W1b's commit captures, as JSON fixtures under `packages/motoko-ext-herdr/`,
   envelopes built by `herdr.ail`'s own tests:
   - a successful `Delegate` envelope, one for a motoko kind and one for claude;
   - a `DelegateCheck` envelope.

   A core test decodes them:
   - `metadata.wait` goes through W2's strict `WaitDescriptor` decoder to `DelegateWait` with
     `id == metadata.delegate`;
   - the check's `settled` and `delegate` read as Part 3 reads them.

   **Who adds the core test (R7).** W1b ships only the JSON fixtures and never the core test,
   so W1b touches no core file. If W1b lands first, the core test lands in W2's commit. If W2
   lands first, W2's gate 6 is recorded as open, and a follow-up core commit adds the test once
   W1b's fixtures exist. Gate 6 closes with whichever commit lands second.
7. **The ABI change** (review change 4):
   - `ailang test packages/motoko-ext-abi/types.ail`;
   - `ailang test` for each package in Part 1's `ExtCtx` list (compaction-ai,
     compaction-structural, context-mode, empty-stop-guard, progress-contract-guard);
   - `make conformance` for the harness;
   - every listed script compiles (`ailang check`).
8. `make anchors` re-baselined; `make event_vocabulary` unchanged (43, no variant);
   `make world_framed_wire` and `make driver_leaf_inventory` unchanged (no new leaf);
   `make check_core`.
9. The sweep at the branch point (§0.2 rule 1), disclosed.

---

### W3 — Step 3: the surface, no call site (2–3 days, core + tools)

Everything here lands **after P2**, so the only default is the `advance` variant (§1 row 1).

**Part 1: types** (`ports.ail`, beside `ApprovalRequest`/`ApprovalInput`):
- `ParkRequest = { request_id: string, step: int, waits: [WaitDescriptor], attempt: int }`.
  `attempt` is 0 on a park's first issue and counts W4's re-issues of the same `request_id`
  (§8.3; R2). The unbound default ignores it.
- `WakeOutcome = Settled(string) | Lost(string) | OperatorInput(string) | TimedOut |
  HostError(string) | Aborted`
- `WakeObservation = { request_id: string, wait_id: string, outcome: WakeOutcome }`
  (§1 row 8)
- `WakeInput = { request_id: string, wait_id: string, outcome: WakeOutcome, next_state:
  WorldState }`

**Part 2: the class.**
- `RequestClass` (`ports.ail:497–`) gains `WakeRead`, the sixth.
- `request_class_id` (`world_ordinal.ail:41–51`) gains `WakeRead => "wake_read"`, and
  `request_class_of_id` (`:53–61`) gains the inverse.
- **Flip 1:** `world_ordinal.ail:112` now asserts
  `request_class_of_id("wake_read") == Some(WakeRead)`. `back(WakeRead)` joins the
  round-trip conjunction at `:106`, and a distinctness conjunct is added.
- **Flip 2:** `ext_world.ail:811–823`, `test_an_unknown_witness_class_is_dropped_and_the_ordinal_kept`,
  forges a genuinely unknown id (e.g. `"not_a_class"`) in place of `"wake_read"` and keeps
  its assertion. A new test pins that a `"wake_read"` witness survives the token round trip.

**Part 3: the field and its default.**
- `Ports` (`ports.ail:829` region, beside `approval_read`) gains
  `wake_read: (WorldState, ParkRequest) -> WakeInput ! {IO}`.
- ```
  wake_read_unbound(world, req) =
    { request_id: req.request_id, wait_id: "", outcome: HostError("wake_read unbound"),
      next_state: advance(world, WakeRead) }
  ```
  It never blocks.
- Bound in **all three full literals**, and nowhere else:
  - `ports_shape_probe` (`ports.ail:2596–2612`)
  - `scripts/dst/long_qwen_compaction_dst.ail:385–405`
  - `scripts/dst/long_qwen_compaction_dst.ail:515–535`
- Other providers inherit by record update. The live (`stub_step.ail:186`, `:209–223`),
  recording (`:557`) and generating (`:651`) constructions are checked to compile unchanged.

**Part 4: the cursor and codec.**
- `WorldState` (`ports.ail:183`, beside `approvals` at `:208`) gains
  `wakes: [WakeObservation]`.
- Every full `WorldState` literal gains it. There are three at HEAD (review change 9):
  - `empty_world_state` (`ports.ail:763–767`, literal `:764`);
  - `ext_world.world_of_json` (`ext_world.ail:584–597`);
  - `ext_world.codec_fixture_world` (`ext_world.ail:693–`).

  Every other world in the tree is a record update of `empty_world_state()`
  (`{ empty_world_state() | … }`) and inherits the field. That includes the `dst_replay.ail:1170`
  test world the review names.
- `ext_world.world_json`/`world_of_json` carry `wakes`, next to `approvals` (`:554`, `:587`).
  `world_of_json` reads lists leniently (`json_array`), so a token written before W3, with no
  `wakes` key, decodes to `wakes: []`. That is intended: an old token has no outstanding wake.
  Otherwise an extension round trip that rebuilds only the enumerated fields would drop the
  cursor before the first park.
- The codec fixture (`ext_world.ail:687–774` pattern) gains a non-empty `wakes` queue, one of
  each `WakeOutcome` arm, asserted by value.

**Part 5: scanner recognition** (`tools/driver_leaf_inventory/derive.py`).
- Docstring freeze note (`:10–30`, the "no sixth variant" at `:21`) → six classes, citing
  ADR-002 D2 as the reason the sixth exists.
- `HELPED` (`:94–105`) gains `"ports.wake_read": "WakeRead"` and
  `"st.provider.wake_read": "WakeRead"`.
- `REQUEST_CLASS` (`:164`) gains `"WakeRead"`.
- `CALL_RE` (`:173–177`) method alternation gains `wake_read`.

**Part 6: the missing-witness scanner case** (the v1 review's §7.3; rewritten by review
change 8).
- **Why v1's version cannot work.** After Part 5, `st.provider.wake_read` is in `HELPED`, so
  `scan_leaves` marks any call through that receiver `status: "helped"`. `UNRESOLVED-RECEIVER`
  is emitted only when `HELPED.get(key) is None` (`derive.py:192–200`). v1's "must report it
  unresolved" is therefore unreachable.
- **Forbidden: an unhelped-receiver mutant** (for example `p.wake_read(…)`). It goes
  `UNRESOLVED-RECEIVER` and passes the self-test while proving nothing about witness order. It
  is a false green.
- **The red is an order-of-witness verdict**, in the harness's own shape. `TREE_MUTANTS`
  (`derive.py:580–610`, run by `tree_mutants` at `:613–640`) takes a same-line replacement of
  anchor text that occurs exactly once in a real tree file. It expects the named leaf's `order`
  verdict to fall outside `CLEAN_VERDICTS = ("clean", "returned")` (`:286`). W3 has no session
  call site and therefore no anchor, so the work splits:
  - **W3 ships a fixture-directory case.** `tools/driver_leaf_inventory/fixtures/` gains two
    fixtures, both declared in `fixtures/expected.json`:
    - `form_wake_read_unwitnessed.ail`: a helped `st.provider.wake_read(st.world_state, req)`
      whose successor is advanced and put into a record with **no** `witness` anywhere in the
      function, and the function is not in `RETURNING`. `classify_fixture` (`:557–`) gives
      that shape `advanced-unwitnessed` (`derive.py:228–230`, returned at `:370`). It is
      **not** the `witnessed-after-construction` family of `form_witnessed_after_record.ail`,
      which needs a later `witness(` (`:364`, `:366–367`). `expected.json` pins
      `"verdict": "advanced-unwitnessed"` for it (R8);
    - `control_wake_read_witnessed.ail`: the same call, witnessed before construction, declared
      clean.
  - **W4 ships the tree mutant** against the real `Park`-arm call site (W4 gate 4). It is a
    `TREE_MUTANTS` entry named "wake_read successor not witnessed", on `src/core/session.ail`.
    It replaces the exact witness line with the same line minus `witness`, and expects
    `("leaf", "st.provider.wake_read", {"advanced-unwitnessed", "witnessed-after-construction"})`,
    in the style of the "exit-publish read never witnessed" entry (`:604–609`).
- **Red first** (kept). Run the W3 fixture against the pre-Part-5 `CALL_RE` and record that it
  is invisible there: the leaf is not found, so the fixture does not classify non-clean. The
  record goes in the commit message **and in §7 at T2** (review change 23).

**Gate (W3).**
1. The unbound default, unit-tested (`ailang test src/core/ports.ail`):
   - `request_id` is echoed, `wait_id == ""`, `outcome == HostError("wake_read unbound")`;
   - `next_state.ordinal == world.ordinal + 1`;
   - `next_state.pending` ends with exactly one `{ ordinal: world.ordinal + 1, class: WakeRead }`;
   - **T0, not a unit test** (review change 9): the body of `wake_read_unbound` calls no port
     and no `readLine`. This is a `grep` over the function's span in `ports.ail`, so it cannot
     block.
2. `ailang test src/core/world_ordinal.ail` green with **flip 1**; `ailang test
   src/core/ext_world.ail` green with **flip 2**, the new witness test and the `wakes`
   round trip.
3. `make driver_leaf_inventory` green with the **site count unchanged**, since there is no
   session call site. `make driver_leaf_inventory_selftest` green: inside it, Part 6's
   `form_wake_read_unwitnessed` fixture reports `advanced-unwitnessed` (R8) and the control is
   clean.
   No unhelped-receiver mutant exists anywhere, and the tree mutant is W4's (review change 8).
4. `make world_state`, `make strict_replay`, `make program_persistence`,
   `make world_framed_wire`, `make ledger_parity` green; `make event_vocabulary` unchanged;
   the `long_qwen_compaction` target and `make check_core` compile the three literals.
5. No `session.ail` edit, so no anchor move. The sweep, disclosed.

---

### W4 — Step 4: activation (8–11 days, core + host)

**Dependencies.** P2 green (it is, §0.1); W2 and W3 landed; the sweep under ADR-001 D6. This
section is written against P2's landed shape: `advance`/`witness`, frame-boundary rule,
`world_framed_wire`.

**Part 1: stage 3 and `Park`** (core).
- `classify_candidate`'s stage 3 goes live: `open_waits` non-empty → the state's
  `last_finish_reason = "await_wake"`, whatever the candidate says, blank included.
- `StepDecision` (`phase_vocab.ail:564`) gains `Park([WaitDescriptor])`.
- `decide` (`step_machine.ail:116–141`) gains **one arm, and the arm reads `open_waits`**
  (review change 11; the chosen option is "the arm reads the field", not "the tests use reason
  `await_wake`"):
  ```
  else if List.length(s.open_waits) > 0
       && (s.last_finish_reason == "await_wake" || s.last_finish_reason == "stop"
           || s.last_finish_reason == "dp7_approved" || s.last_finish_reason == "dp7_fail_open")
  then {
    if pol.step_budget > 0 && s.step_idx >= pol.step_budget
    then Fail({ code: "StepBudgetExhausted", message: "step budget exhausted", retryable: false })
    else Park(s.open_waits)
  }
  ```
  - **The budget guard (R1).** This arm is the path a re-issue takes (Part 2), and it precedes
    and bypasses `call_model_or_fail` (`step_machine.ail:96–105`), the only budget test at HEAD.
    So the arm carries the same predicate and the same `Fail` record `call_model_or_fail`
    builds (`:97`, `:105`). Chosen over a driver-side check before `wake_read`, so the bound
    stays in `decide`, where it is unit-testable. A first park reached with `step_idx` already
    at the budget also suspends rather than parks.
  - **What exhaustion does.** `Fail(StepBudgetExhausted)` reaches the driver's `Fail` arm, which
    routes that code to `c2_suspend` (`session.ail:3024–3025`): the run **suspends**, as any
    budget exhaustion does, and does not fail. `c2_suspend` may still route back to `c2_fail`
    when the history is not resumable (`:3020–3022`). The continuation clears `open_waits`
    (`c2_state_from_continuation`, Part 2).
  - **Placement.** The arm goes after the pending-tools arms (`:117–123`) and the three inject
    arms (`dp7_rejected` `:124–125`, `solver_feedback` `:126–127`, `persist_nudge` `:128–129`),
    and immediately **before** the stop-class `Finalize` arm (`:130–131`). A stop-class state
    with open waits therefore never reaches `Finalize`, and an inject reason with open waits
    still injects.
  - **What this buys.** `decide` holds the narrowed guarantee on its own: no stop-class reason,
    blank `stop` included, finalizes while waits are open, whatever stage 3 did. Stage 3's
    `await_wake` is one of the reasons the arm accepts, not the only route to `Park`.
  - **`await_wake` with no waits** is never produced, since stage 3 sets it only when waits are
    non-empty. If it were, it would fall through to the default `call_model_or_fail` (`:140`). A
    test pins this.
  - Nothing else in `decide` changes.
- The decision-name projection (`session.ail:744–746`) gains `"Park"`.
- New `decide` tests, the ADR's cross product:
  - each stop-class reason (`stop`, `dp7_approved`, `dp7_fail_open`) × open waits → `Park`;
  - empty (reason `stop`, `last_response_text == ""`) × waits → `Park`;
  - `await_wake` × waits → `Park`; `await_wake` × no waits → not `Park`;
  - `dp7_rejected`, `solver_feedback`, `persist_nudge` × waits → `InjectUserMessage`;
  - pending tools × waits → `RunTools`;
  - two open waits → `Park` carrying both, in order;
  - **the budget guard (R1):** each stop-class reason (`stop`, `dp7_approved`,
    `dp7_fail_open`, `await_wake`) × open waits × `pol.step_budget > 0` and
    `step_idx >= pol.step_budget` → **not** `Park`, and exactly
    `Fail({ code: "StepBudgetExhausted", … })`; the same with `step_budget == 0` (unlimited) →
    `Park`.
  The fifteen existing tests stay untouched.
- **ADR D3's "the model is told both are open"** (re-delegation row, `ADR-002:473`) is produced
  here, in W4 (review change 18). W2 changes no model message: its Part 2 extracts `wait`
  before `handled_tool_message` and never re-decodes the message. W2 has no gate on message
  bytes, and its gate 4 is about decision sequences (R5).
  - **Where.** The append happens in the **loop's tool fold**, the site where W2 Part 2's typed
    result is folded into `open_waits` by `apply_tool_lifecycle` (the `RunTools` arm,
    `session.ail:3238`). It does not happen in `tool_phase.ail`'s `Handled` arm (`:439–449`),
    which has `call`, `result_env` and `handle_world` in scope but not `open_waits` (R5).
  - **What.** From W4 on, when `apply_tool_lifecycle` leaves two or more waits open after a
    `Delegate`, the fold appends one loop-authored sentence to that call's tool message, naming
    every open wait `id`. The message is already capped, and the wait was already extracted
    (W2 Part 2).
  - A Part 6 re-delegation fixture asserts the sentence.
- The guard (`progress_contract_guard.ail:199–208`) reads `ctx.open_waits`: W2's `Json` array,
  where non-empty means a wait is open. `has_open_delegate`,
  the prose recogniser, remains as the explicitly limited fallback (ADR D3 "Guard").

**Part 2: the driver's `Park` arm** (core, beside `AwaitApproval` at `session.ail:3173`).
- `C2LoopState` gains `park_ordinal: int` and `park_attempt: int`. Both are zero at every
  constructor, including `c2_state_from_continuation`. The one exception is W5(b)'s rule for a
  run opened by a consumed between-turn wake (R9).
- Build `ParkRequest { request_id: "${identity.run_id}.p${show(park_ordinal)}", step:
  st.step_idx - st.park_attempt, waits: st.open_waits, attempt: st.park_attempt }`.
  `identity` is `c2_loop`'s parameter (`:2998`); nothing is added to `StepState` (§1 row 3).
  - **`step` stays at the original `step_idx` on every re-issue (R2).** Each re-issue charges
    exactly `step_idx + 1` and `park_attempt + 1` together, so `step_idx - park_attempt` is the
    step at which the park was entered. A re-issued request equals the first issue in
    `request_id`, `step` and `waits`, and differs only in `attempt`.
- Emit **and** append `ParkEntered { request_id, step, waits }` **before** calling the port,
  on the first issue only (`park_attempt == 0`).
- `st.provider.wake_read(st.world_state, req)`.
- **Witness** the successor (`witness`, `session.ail:4163`) before it enters any record.
  This applies to every reply, including one that is then dropped, since the port has advanced
  the world either way. Under P2's frame-boundary rule, no `END` may print with `pending`
  non-empty, so a missed witness is a gate red, as intended (delta review §2 D5).
- **Match.** A reply whose `request_id` does not match is dropped and logged, never applied to
  a different wait. `wait_id` is matched only for `Settled`/`Lost`/`TimedOut`: the unbound
  default returns `wait_id: ""`, and `HostError`/`OperatorInput`/`Aborted` name no wait, so
  matching on `wait_id` for those would drop the unbound default's own reply (review change 12).
- **Only a matching reply emits and appends `WakeReceived { request_id, wait_id, outcome }`**
  (R2). A dropped reply appends **nothing** to the ledger. It emits one `warning` event naming
  the expected and received `request_id`/`wait_id`, and it is logged. So every
  `WakeReceived` is a wake the loop applied, and ADR-003 D7's `wake` child of a park (§6) is
  never a reply that was dropped.
- What the loop does next on a dropped reply is decided: re-issue, §8.3. The re-issue
  mechanics (decided by the owner 2026-09-13, review change 13; mechanism corrected by R1):
  - **What is re-issued.** The same park, with the same `request_id` (no ordinal increment),
    from the single `wake_read` call site.
  - **How.** The `Park` arm recurses into `c2_loop` with `{ st | step_idx: st.step_idx + 1,
    park_attempt: st.park_attempt + 1, world_state: <witnessed successor> }`.
    `last_finish_reason`, `open_waits` and `park_ordinal` are unchanged, so `decide` is
    consulted again and returns to the same `Park` arm.
  - **The bound.** That arm's budget guard (Part 1, R1) turns the re-issue into
    `Fail(StepBudgetExhausted)` once `step_idx >= pol.step_budget`. The run then suspends
    (`session.ail:3024–3025`), and the continuation clears `open_waits`. A re-issue never
    calls the model: the `user_injected → call_model_or_fail` route belongs to the
    **accepted** wake's continuation (below), not to a re-issue.
  - From W4 on, the step budget reads as driver steps, not model steps.
  - `ParkEntered` is NOT re-emitted, since the re-issue retries the same park and re-emitting
    would duplicate D7's `park` entry.
  - **`attempt`'s source (R2)** is the `C2LoopState.park_attempt` counter, carried in
    `ParkRequest.attempt`. It is reset to 0 whenever `park_ordinal` increments (the accepted
    wake's next state, below) and is 0 at every constructor. It is not a count of prior
    `WakeIdentity` interactions. `recording_wake` records it as a payload field, and
    `WakeIdentity` equality is unchanged.
  - **The Part 6 wrong-handle fixture** asserts, with a finite `step_budget` and a script that
    replies only with mismatched `request_id`s:
    - the bound: the run's terminal decision is `Fail` with code `StepBudgetExhausted`, and the
      run is suspended rather than failed;
    - exactly one `ParkEntered`;
    - no `WakeReceived` and one `warning` per dropped reply;
    - attempt ordinals `0, 1, …` with `request_id` and `step` equal across them.
- Pure `apply_wake(open_waits, wake) -> [WaitDescriptor]`, per the ADR's outcome table:

  | outcome | the wait |
  |---|---|
  | `Settled` / `Lost` | remove the match |
  | `OperatorInput` | keep all |
  | `TimedOut` | remove the timer only |
  | `HostError` | **keep** |
  | `Aborted` | the abort path; cleared with the run |

- Pure `wake_message(wake) -> Message`, tagged loop-authored (distinct from an operator
  message). `Settled` says "the answer is available; call `DelegateCheck` once".
- The next state after a **matching** wake is `park_ordinal + 1`, `park_attempt: 0`, with
  `last_finish_reason = "user_injected"`, so
  `decide`'s existing arm (`step_machine.ail:138–139`) routes it through `call_model_or_fail`
  (`:96–114`). Step and cost caps, checkpoint and context pressure apply as they do to any
  injected message. No decision variant is shared or added, so the ADR's "Not decided:
  whether `InjectUserMessage` and the wake message share a decision variant" stays open.
- `derive.py` then sees one new helped site (`st.provider.wake_read`), and the inventory count
  rises by exactly one. **This holds only because the re-issue reuses the single `wake_read` call
  site** (review change 17). A re-issue re-enters the same `Park` arm; it is not a second
  `.wake_read(` expression. No other `.wake_read(` appears in `session.ail`, `tool_phase.ail` or
  `stub_step.ail`, which gate 4's "+1" checks.
- **`open_waits` across the in-process continuation** (review change 18).
  `c2_state_from_continuation` (`session.ail:2591`) sets `open_waits: []`, `park_ordinal: 0` and
  `park_attempt: 0`, per ADR D3's "run ends (… suspend) → cleared" (`ADR-002:482`).
  - The delegate keeps running, and the resumed run's model is **not told**. That is a stated
    limit, not a gap closed here.
  - ADR-003 D7's `park` entry is what carries waits across a durable park (§4).
  - **The one exception (§8.4; R9).** Every run opened by a consumed between-turn wake starts at
    `park_ordinal == 1`. That covers a run resumed by P4's resumer and a run opened in-process by
    §3's future between-turn park alike. W5(b) names the function that yields it.

**Part 3: events** (core).
- `ParkEntered` and `WakeReceived` become `LedgerEvent` variants, both **logical** (PLAN-001
  §2.2 criterion), appended and emitted.
- Vocabulary rows and goldens in the same commit: `make event_vocabulary` 43 → 45.
- `parity_findings` (`dst_invariants.ail:1180`) gains **payload** assertions for both, not
  presence only.
- `ledger_parity_dst.ail` gains the required rows; the exporter learns the wire names.

**Part 4: DST adapters** (core, the approval set item for item):

| approval has (HEAD) | wake gets |
|---|---|
| `scripted_approval` `ports.ail:1019–1024`, bound at `:2598` | `scripted_wake`. Head of `WorldState.wakes` → `WakeInput` with `next_state = advance({ w \| wakes: rest }, WakeRead)`. **An empty queue falls through to `wake_read_unbound`.** |
| `recording_approval` `ports.ail:1758–1786` (records `OutcomeMissing` on EOF) | `recording_wake`. `record_interaction` with a new identity; an unbound fall-through is recorded as missing. |
| `ApprovalIdentity` `dst_interaction.ail:62` (kind `:125`, equality `:180–181`, render `:206`, counted `:303`, `:383`) | `WakeIdentity(origin, request_id, wait_id)` and its outcome encoding. Not `WakeRead`, which is the ordinal class. |
| `approvals_of` / `queue_balance` `dst_replay.ail:707–718`, `:582` | `wakes_of` and a `wakes` queue balance for reconstruction. |
| world-token codec (W3 Part 4) | already landed |

Bound in `fake_ports` / `scripted_ports`, and the recording and generating providers in
`stub_step.ail` (`:557`, `:651`).

**Part 5: the live binding and host protocol** (core + host).
- **Core.** The live `wake_read` in `live_ports` (`stub_step.ail:186`, beside the live
  approval at `:209–223`) emits a `wake_request` event carrying the `ParkRequest`, then
  reads stdin until a matching `wake_reply` or a command. `advance` applies as for every helped
  leaf.
- **Commands received while parked** (review change 15). At HEAD, `session.ail` has no in-turn
  abort path: `"abort"` is read only between turns, where it returns exactly as `exit` does
  (`:4357`). The TUI's ESC kills the runtime mid-task (`ui.ts:2147–2157` → `onInterrupt` →
  `kill()`, `index.ts:1190`). ADR D2 says `abort` is `Aborted` and takes the existing abort path,
  and `restart`/`exit` cancel the request (D4, `ADR-002:397–399`, `:497–500`).
  `WakeOutcome` has no cancel arm and gains none. The plan pins the following, decided by the owner 2026-09-13 (§8.7):

  | stdin line while parked | live `wake_read` returns | `Park` arm | `SessionSuspend` | `c2_loop` returns | conversation loop, after the run |
  |---|---|---|---|---|---|
  | `wake_reply` (matching) | its outcome | Part 2 as written | no | continues | — |
  | `user_message` (a client with no parked route) | `OperatorInput(content)` | as `OperatorInput` | no | continues | — |
  | `abort` | `Aborted`, `wait_id: "abort"` | witness; emit and append `WakeReceived(Aborted)`; `open_waits` cleared; `Fail({ code: "ParkCancelled", message: "abort", retryable: false })` through the existing `Fail` arm (`session.ail:3023`), so `RunSummary` is written as for any `Fail` | no | `Err`, code `ParkCancelled` | returns `()`, as between-turn `abort` does (`:4357`); no `error` event |
  | `exit` | `Aborted`, `wait_id: "exit"` | as `abort`, `message: "exit"` | no | `Err`, `ParkCancelled` | returns `()` (`:4357`); no `error` event |
  | `restart` (`profile` p) | `Aborted`, `wait_id: "restart:<p>"` | as `abort`, `message: "restart:<p>"` | **yes**, emitted by the conversation loop | `Err`, `ParkCancelled` | emits `SessionSuspend { target_profile: p }` and returns, as `:4378–4390` does |
  | EOF (`""`) | `Aborted`, `wait_id: "eof"` | as `abort`, `message: "eof"` | no | `Err`, `ParkCancelled` | returns `()`, as `:4352` does |
  | `model_change` | not a wake: dropped, with a `warning` event naming it; reading continues | — | no | — | the host defers `model_change` while a request is outstanding (below), so only a non-TUI client reaches this row |
  | anything else | reading continues (malformed lines are dropped, as at `:4354`) | — | no | — | — |

  - **Where `wait_id` is read.** `Aborted` names no wait, so `wait_id` is not matched for it
    (review change 12). The cancelling command rides in that free field, and nothing is added
    to `WakeInput`.
  - **Which arms dispatch.** The conversation loop's `Err` arms (`:4492–4499` in the
    `user_message` arm; `:4760–4767` on the initial turn) match `ParkCancelled` before the
    generic `ErrorEvent` and dispatch on `e.message`.
  - **`WakeReceived(Aborted)` is logical.** It is recorded before any exit, so ADR-003 D7 sees a
    park with a wake child and does not re-observe it.
- **Host side of the same commands.** ESC during a park calls `runtimeProcess.abort()`
  (`runtime-process.ts:861–863`) instead of `kill()`, and sets `interrupted = true` so the exit
  handler journals `abort` (`index.ts:1068`). The run's end is then on the wire as
  `WakeReceived(Aborted)`. Quit and `restart` send `exit`/`restart` down stdin. `setModel` is
  queued until the request resolves.
  - **The exit is marked as requested (R3).**
    - **Why.** `abort()` only sends `{type:"abort"}` (`:862`); `killRequested` is set only by
      `kill()` (`:870–873`). A `ParkCancelled` run emits neither `done` nor `error` (Part 5's
      table), so the child's last event is not in `EXIT_EXPLAINING_EVENTS` (`:162`, `:691`).
    - **The failure.** At `:716` the exit is then unexplained. Whenever the child exits by
      signal or with a non-zero code, `describeUnexplainedExit` (`:150–158`) returns a message
      and `:717` synthesizes an `error`. A clean code-0 exit returns `null` today (`:157–158`),
      but the plan does not depend on that.
    - **The fix.** `RuntimeProcess` gains a sibling flag, `cancelRequested`, set by `abort()`,
      and by the `exit`/`restart` sends, while a `wake_request` is outstanding. `:716` reads it
      beside `killRequested`: `this.exitExplained || this.killRequested || this.cancelRequested`.
      A mid-park cancel is then an exit the host asked for, and no `error` is synthesized.
- **Host** (`src/tui`):
  - `runtime-process.ts` handles `wake_request` and gains `sendWakeReply`, beside `send`
    (`:842`) and the other commands (`:862–891`).
  - The waiter implements the ADR's observations exactly:
    - `DelegateWait` answer: initial read, subscribe, re-read.
    - `DelegateWait` state: wait for the agent row to exist, then
      `agent wait --until idle,done,blocked` for claude/codex. For a motoko one-shot, the row
      disappearing **after it was seen**, then an answer re-read. A default-wait success is
      never an answer.
  - A herdr transport failure is `HostError`, never `Lost`.
  - **Parked input route.** The TUI accepts operator input while a request is outstanding and
    replies `OperatorInput`. Today plain input is refused while a task runs. The ADR's
    `ui.ts:4046–4049` is `shouldLockPlainInput` at HEAD (`ui.ts:1798–1804`, keyed on
    `taskDone`); `:2218` is the status-bar spinner tick, not a guard (review change 15). While a
    `wake_request` is outstanding, plain input bypasses that lock and goes to
    `sendWakeReply({ request_id, outcome: OperatorInput(content) })`.
  - Losing waiters are cancelled on wake, abort and runtime exit. Late replies are dropped by
    `request_id`. Simultaneous readiness is reported in `waits` order.
  - Child waiters are reaped on every exit path 020's reporter handles.

**Part 6: fixtures** (DST), exactly the ADR's list:
- success (`Settled`); `Lost`; `OperatorInput` leaving the delegate pending; two delegates
  with one wake; `HostError` leaving the wait open, then a second park succeeding;
  `TimedOut` removing only the timer. **`TimerWait` has no producer in this plan** (review
  change 18): ADR D3 names the model's `Delegate` or policy (`ADR-002:460–461`), and timeouts
  are "Not decided" (§4). The `TimedOut` fixture therefore constructs the `TimerWait` directly in
  its state. A re-delegation fixture asserts the "both are open" sentence (Part 1). A mid-park
  command fixture covers `abort` and `restart` per Part 5's table;
- controls: wrong handle; duplicate or late wake; **missing wake**; stale world; empty stop
  with open waits; the DP7-rejected solver candidate with open waits;
- **missing wake** asserts `WakeReceived(HostError("wake_read unbound"))` **directly** at the
  exhaustion point, not the later script mismatch;
- two runs from one script (determinism); the saved-program replay through `recording_wake`.

**Part 7: the metric.**
- **Fixture.** Every assertion reads **one channel** (review change 16):
  - **Trace channel:**
    - exactly 4 `ProviderCallPrepared` events (`phase_vocab.ail:1008`);
    - **zero** `ProviderCallPrepared` between `ParkEntered` and `WakeReceived`.
  - **Program channel**, checked separately:
    - exactly 4 `ProviderIdentity` interactions (`dst_interaction.ail:60`);
    - exactly one `WakeIdentity` interaction, which sits between the 2nd and 3rd
      `ProviderIdentity`.
  - Neither assertion relates a trace event to a program interaction.
  - A verified variant (one verification tool after the check) asserts ≥ 5 on each channel and
    is reported separately.
- **Live.** One delegation run with a real delegate in herdr: count `provider_call_prepared`
  on the orchestrator's session log from `Delegate` to `done`. The result goes in §7 with the
  log path. Success path `== 4`. If the path deviates, record the actual sequence; the gate
  is not waived.

**Gate (W4).**
1. `ailang test` green for `step_machine.ail` (new cross-product tests, including the
   `await_wake` × no-waits case; the fifteen unchanged), `phase_vocab.ail`, `ports.ail`,
   `session.ail` (including `c2_state_from_continuation` → `open_waits == []`,
   `park_ordinal == 0`), `dst_interaction.ail`, `dst_replay.ail`, `dst_invariants.ail`, and the
   guard package.
2. Every Part 6 fixture green in its Make target, wired into `DST_TARGETS`; the missing-wake
   control asserts `HostError` at exhaustion.
3. `make world_framed_wire` green, with the `wake_read` ordinal inside the frame at strict
   +1. A mutant that skips `witness` after `wake_read` goes red.
4. `make event_vocabulary` (45), `make ledger_parity` (payload rows), `make strict_replay`,
   `make program_persistence`, `make driver_leaf_inventory` (count +1, zero unresolved, one
   `.wake_read(` call site), `make driver_leaf_inventory_selftest` with the `TREE_MUTANTS` entry
   "wake_read successor not witnessed" red against the `Park` arm (W3 Part 6) and W3's fixture
   case still red, `make anchors` re-baselined.
5. W2's gate items 1–4 still green.
6. Host `bun run test` and `tsc`, with tests for:
   - the `wake_request`/`wake_reply` round trip;
   - late reply dropped;
   - `HostError` versus `Lost`;
   - the parked input route bypassing `shouldLockPlainInput`;
   - ESC during a park sending `abort`, not killing;
   - **ESC during a park, then the child exits (R3)**, both with code 0 and with a non-zero
     code: no synthesized `error` event reaches `onEvent` (beside
     `runtime-process.unexplained-exit.test.ts`), and the journal's exit entry reason is
     `abort` (`index.ts:1068`);
   - `setModel` deferred while parked;
   - waiter cancellation on abort and exit;
   - readiness order.
7. **The metric:** fixture `== 4` on each channel separately (verified ≥ 5), and **one live
   measurement recorded**.
8. **One live parked run** end to end (park, wake, `DelegateCheck`, final) recorded in §7.
   This is the precondition W5 waits on.
9. **Statements checked in the activation commit** (review change 18):
   - **Q5 (§8.5).** If W-O5 has landed, this commit removes `DelegateAwait`: the tool, its L1
     tests, and any `herdr_graded` clauses. `git grep DelegateAwait` then finds nothing outside
     `.agent/`. If W-O5 has not landed, this item is vacuous and says so.
   - **`TimerWait`.** It has no producer. Only fixtures construct it (Part 6).
   - **Continuation.** `open_waits` is cleared by `c2_state_from_continuation`
     (`session.ail:2591`), and the model is not told (Part 2).
   - **"Both are open".** ADR D3's re-delegation message is produced by W4 Part 1 and asserted
     by the re-delegation fixture.
   - **Mid-park commands.** Part 5's table is covered by the mid-park command fixture (`abort`,
     `restart`) and by host tests (gate 6), per the §8.7 decision (owner 2026-09-13).

---

### W5 — Step 5: D4's framing and identity subset (3–4 days, core; ADR-003 D7's prerequisite)

**Dependencies.** W4's gate has held for **one live parked run** (W4 gate 8).

The subset is three things, and only these (ADR D4 and D5 step 5):

**(a) The between-turn frame.**
- It opens **after** `RunSummary`, at the previous frame's `final`. That is the rule ADR-003
  D5 uses for a resumed frame, and P3ORD implements it on the resume path
  (`run_summary.world_ordinal`; `BEGIN₂.ordinal₀ == END₁.final`).
- It is separate from `done`/`RunSummary`, so `RecordAfterTerminal` (`dst_invariants.ail:891`)
  is not tripped.
- The cross-turn ordinal and any between-turn `ParkEntered`/`WakeReceived` live in it.
- **Where the next turn opens** (review change 20). The rule "opens at the previous frame's
  `final`" applies to the **between-turn frame**, not to the next turn.
  - The exit manifest's witnessed `env_read` (`session.ail:4582–4583`) runs after turn N's run
    returns, so it sits in the between-turn frame. Its `world_request` carries turn N's
    `final + 1`.
  - Threading that world (c) means turn N+1 opens at the **between-turn frame's last ordinal**,
    not at turn N's `final`.
- **What the frame is on the live wire** (review change 20). W5 adds **no wire record** for the
  frame. `WORLD_RUN_BEGIN`/`END` are `println`s in the DST script only
  (`ledger_parity_dst.ail:405–406`, checked by `run_world_framed_wire.sh`). Live stdout carries:
  - `world_request` records (`witness_drain`, `session.ail:4167–4176`);
  - `run_summary` with `world_ordinal` (P3ORD; journal type `journal.ail:1036`).

  The between-turn frame is observable only as the `world_request` ordinals that lie after one
  `run_summary` and before the next run's first request. Gate 2 is stated over exactly those.
  - **The delimiter is `session_start` (R10).** The `user_message` arm emits it
    (`ledger_emit(session_id, SessionStart({ task, model, mode, run_id }))`,
    `session.ail:4405–4410`; wire name `session_start`) after building the run's identity
    (`:4404`) and before the run starts. On stdout, the between-turn `world_request`s are the ones
    after turn N's `run_summary` and before turn N+1's `session_start`. Turn N+1's first request
    is the first `world_request` after that `session_start`.

**(b) `run_id` from ADR-003 D5.**
- The loop's identity is `loop_run_identity(session_id, profile, resume_count, run_ordinal)`
  (defined `session.ail:4274`, called in the `user_message` arm at `:4404`), landed.
- **Construction of the between-turn id** (review change 21), transcribing §8.4:
  ```
  pure func between_turn_request_id(session_id, profile, resume_count, next_ordinal) -> string =
    "${loop_run_identity(session_id, profile, resume_count, next_ordinal).run_id}.p0"
  ```
  - It is built at the blocking read, the `readLine` site `session.ail:4351`.
  - There, §8.4's `next_ordinal` is the conversation loop's `run_ordinal` parameter: the value
    `:4404` passes for the run the operator's input opens.
  - W5 lands the function and its pure unit test only (gate 1). No park calls it until the
    unscheduled "blocking read as a park" (§3).
- A between-turn request id needs a `run_id` for a frame that is not a run. Decided
  (§8.4, review change 14): the between-turn park uses the identity of the run the
  operator's input will open, `loop_run_identity(session_id, profile, resume_count,
  next_ordinal)` (definition `session.ail:4274`), so `request_id = <next run_id>.p0`.
  That run's `run_started` then follows the consumed wake, which is the shape ADR-003
  D7's exactly-once rule reads. One grammar is kept: `.p0` always means the park that
  opened the run's waiting, whether between turns or in-turn — which agrees with ADR-003
  D7's "rewritten to the re-issued request (`run_id` + park ordinal 0)
  (`ADR-003:546–547`), the case where the resumed run's first park *is* that request.
  To keep `.p0` unique, **every run opened by a consumed between-turn wake** initializes its
  `park_ordinal` to 1 instead of 0, so the run's first in-turn park is `<run_id>.p1` (R9).
  - **Scope.** This covers P4's resumer, which seeds `wakes` from a consumed between-turn wake,
    **and** the in-process case: a run opened by §3's future between-turn park, whose wake the
    conversation loop consumed without an exit. Neither is left at `.p0`.
  - **The function (R9).** W5 lands:
    ```
    pure func initial_park_ordinal(opened_by_consumed_wake: bool) -> int =
      if opened_by_consumed_wake then 1 else 0
    ```
    - W4 Part 2's two constructors (`c2_initial_state_with_counts` `:951`,
      `c2_state_from_continuation` `:2591`) write `park_ordinal: initial_park_ordinal(false)` in
      place of the literal `0`. No signature changes.
    - A site that opens a run from a consumed between-turn wake applies
      `{ st | park_ordinal: initial_park_ordinal(true) }` to the constructed state before the
      run's first decision. Those sites are P4's resumer and §3's park, and neither is in W5.
  - Nothing in W5 emits a between-turn park, since that is the unscheduled remainder, but the
    frame's identity and this rule are fixed here, and gate 1 calls the function.

**(c) A world threaded into the conversation loop** (priced at HEAD, §1 row 11).
- In the `user_message` arm, `publish_turn_exit_manifest`'s result (at `:4463`, today
  `let _ =`) is kept.
- Its world, which P2 Part 5(a) made the function return, becomes the next turn's world:
  `{ provider | world: <that world> }` at the three recursions `:4484`, `:4491`, `:4498`.
- The `model_change` successor at `:4371`, where `switched.world` is dropped, stays in the
  unscheduled remainder: the ADR lists it under "the rest of D4".
- The pure part is factored out for unit tests: which world the next turn starts from, given
  the traced and published results.
- **Not in (c)** (review change 19; the chosen option is the three-turn probe, not widening
  (c)). The **initial** turn drops its successor the same way:
  - `let _ = publish_turn_exit_manifest(…)` at `:4723`;
  - the loop is then entered with `started_provider` (`:4759`) or `live_provider` (`:4755`,
    `:4766`).

  That drop stays in §3's unscheduled remainder, and gate 2 is shaped around it.

**Price** (review change 22): **3–4 days**, up from v1's 2–4. v1's figure covered the three
recursions and the pure factor. v2 adds:
- the three-turn live probe harness and its ordinal reader (+½–1 day);
- `between_turn_request_id` and its test (+¼ day).

The two larger options the review offered are declined: threading the initial-turn successor
(change 19's first option) and a live frame record (change 20's first option). So the upper
bound stays at 4.

**Gate (W5).**
1. Pure unit tests (`ailang test src/core/session.ail`): the next-turn world is the published
   successor on the `Ok`, `Err` and suspended arms; the frame-open ordinal equals the
   previous `final`; and a run seeded from a consumed between-turn wake starts with
   `park_ordinal == 1`, so its first in-turn park is `<run_id>.p1` (review change 14). Gate 1
   calls R9's function: `initial_park_ordinal(true) == 1` and `initial_park_ordinal(false) == 0`;
   `c2_initial_state_with_counts(…)` and `c2_state_from_continuation(…)` give
   `park_ordinal == 0`; and after `{ st | park_ordinal: initial_park_ordinal(true) }`, the
   `ParkRequest.request_id` the `Park` arm would build ends in `.p1`. Also
   (review change 21): `between_turn_request_id("s", "p", 0, 3) == "s.r0.3.p0"`, and for any
   arguments it equals `loop_run_identity(…).run_id ++ ".p0"` built from the same arguments
   `:4404` passes.
2. **Live probe** (§0.2 rule 7; PLAN-003 P1 Part 6's shape; review changes 19–20).
   - **Setup:** drive `rpc.main` with `MOTOKO_HEADLESS` unset and stdin held open, send
     **three** `user_message` turns, and read stdout.
   - **Why three turns.** The first message is consumed by `await_first_task` (`rpc.ail:250`,
     `:335`) and runs as the initial turn (`rpc.ail:434` → `session.ail:4722`). Its successor is
     not threaded (W5(c) "Not in (c)"). So turn 1 → turn 2 contiguity is **not** asserted, and
     the assertions are over turns 2 → 3, both run by the `user_message` arm that (c) threads.
   - **Observables:** `world_request` ordinals and `run_summary.world_ordinal` only. Live stdout
     has no frame records (W5(a)).
   - Assert:
     - the first `world_request` after turn 2's `run_summary` (the manifest's witnessed
       `env_read`, `session.ail:4582–4583`) has ordinal `run_summary₂.world_ordinal + 1`, so
       the between-turn frame opens at turn 2's `final`;
     - every between-turn `world_request` lies strictly after turn 2's `run_summary` and
       strictly before turn 3's `session_start` on stdout (`session.ail:4405–4410`, the
       delimiter; R10);
     - turn 3's first `world_request`, the first one after turn 3's `session_start`, has the
       last between-turn ordinal + 1, so turn 3 opens at the between-turn frame's last ordinal,
       not at turn 2's `final`;
     - `world_request` ordinals are contiguous, with no gap and no repeat, from turn 2's first
       request to `run_summary₃.world_ordinal`.
   - Include an `exit` control and an EOF control: both return exactly as today (`:4352`,
     `:4356–4357`).
3. `make world_framed_wire` and `make ledger_parity` (T3), `make journal_resume` (T2; P3ORD not
   regressed), `make anchors` re-baselined; the sweep, disclosed. These are regression gates: the
   harness cannot reach the conversation loop (§0.2 rule 7).
4. The result is recorded in §7 and handed to PLAN-003 P4 (§6).

---

### W-O5 — Fallback: `DelegateAwait` (1–2 days, extension; not scheduled)

**Trigger** (§1 row 14; decided by the owner 2026-09-13, §8.2). The trigger is: W3's gate is not green
within its estimate after W2's gate is, **or** W4 cannot be activated before the next measured
delegation run the owner schedules. Starting O5 on the ADR's literal trigger is ruled out,
since that trigger fired the day P2 landed.

**Scope** (ADR O5).
- A `DelegateAwait` tool in `motoko-ext-herdr` blocks inside the extension on the
  **completion condition**: answer present, or a classified terminal condition (agent gone,
  checked with W1b's re-read).
- It is served through `ext_effect_exec` and scripted through the existing extension-effect
  cursor (`herdr_graded_dst.ail`'s `eff(…)` queue, `:151–155`).
- Its wait is bounded by `check_wait_ms` iterations (default 45 s, `register.ail:173`) up to
  a total the tool call names.
- It settles through the same `dagr_settle` paths `DelegateCheck` uses; D3's "`DelegateCheck`
  remains the only settlement path" is not modified.
- Provider calls: `Delegate`, `DelegateAwait`, optional verify, final.

**What it does not give** (ADR O5; reasons O3 was chosen): operator interruption, multi-wait
arbitration, a wire record of the wait, D4's unification. It is retired when W4 activates, per the owner decision 2026-09-13 (§8.5).

**Gate (W-O5).**
- Extension L1 tests over a scripted herdr: answer present, agent gone, transport error
  (→ error, not `lost`).
- `herdr_graded` run clauses stay green.
- One live measurement: `Delegate` → final in ≤ 4 provider calls, recorded in §7.

---

## 3. D4's debt: explicitly unscheduled

Unscheduled and unpriced (ADR TL;DR D4). None of it is in W5. Closing ADR-001's threading
debt requires **all** of it, plus W5:

- **The blocking read as a park.** `readLine()` at `session.ail:4351` becomes a park with
  `waits = [OperatorWait]`, and `user_message` becomes an `OperatorInput` wake. **ADR text
  residual:** D5 step 5's "rest of D4" list (`:569–570`) does not name this conversion
  itself, so the plan puts it here.
- **`restart` and EOF cancel** the outstanding request and take today's exits: `SessionSuspend`
  and return (`:4378–4390`); EOF (`:4352`). This is decided in D4 and needed once the read is
  a park.
- **The model-change successor**: `session_policy_with_model(provider.ports, provider.world, …)`
  at `:4371`, whose world is dropped.
- **The stale provider across turns.** Whatever W5(c) does not cover: the discard and malformed
  arms at `:4354`, `:4376`, `:4503` recurse with the pre-command `provider`.
- **The initial identity read** (ADR `3ee3d03` `:3582–3586`). At HEAD, re-locate among the
  entry calls `:4638`, `:4697`, `:4846`.
- **The initial turn's dropped successor** (moved here from the identity bullet; review change
  19). `let _ = publish_turn_exit_manifest(…)` at `:4723` drops the initial turn's world. The loop
  entry arms then pass the pre-turn `started_provider` (`:4759`) or the pre-init
  `live_provider` (`:4755`, `:4766`). This is a turn successor, not identity. W5 does not thread
  it; W5 gate 2's three-turn probe is shaped around it.
- **The publish successors** of the live-loop publish calls.
- **Out of scope permanently** (D4): `rpc.await_first_task` (`rpc.ail:250`), which runs before
  any session, world, run or frame exists.

**Gate when scheduled** (ADR D4): a two-turn replay with an intervening model change, plus a
restart-or-EOF control.

---

## 4. Non-goals

- **ADR-003 D7, the durable park** (PLAN-003 P4): `park`/`wake` journal entries,
  `--park-exits`, the suspended-child host state, the seeded `wakes` cursor on resume. This
  plan supplies its inputs (§6) and schedules none of it.
- **Anything in ADR-002 "Not decided":**
  - timeouts, including whether a park without a `TimerWait` is unbounded;
  - observation while parked (nothing writes `last_output_at`);
  - nested delegation;
  - whether `InjectUserMessage` and the wake message share a decision variant;
  - waiting by state after a gap;
  - the truncated-arguments diagnosis.
- **O1** (raising `HERDR_CHECK_WAIT_MS` as the solution) and **O2** as the end state.
- **A DST wall clock.** `TimerWait` bounds, real latency and park duration stay live-only.
- **Resolving external `idle` ambiguity for interactive panes** (ADR Consequences, "What does
  not").
- **Moving run-file truth into the core.** The extension still writes the dagr run file, on
  settle.
- **Re-deciding any ADR-002 decision.** Every divergence is a §1 row or a §8 question.

---

## 5. Evidence tiers and handoff

**Tiers**, weakest to strongest:

| tier | what it is |
|---|---|
| T0 | static: coordinates, `grep`, `git diff` shape |
| T1 | unit: `ailang test`, `bun run test` |
| T2 | DST target: `make <target>` |
| T3 | wire-framed: `make world_framed_wire`, `make ledger_parity`'s wire half |
| T4 | live: herdr probe, live runs, live `rpc.main` probe |

**What closes each item:**

| item | closes at | notes |
|---|---|---|
| W1a | T4 | measurement only |
| W1b | T1 + T2 | host and extension units. **T2 is `herdr_graded`'s run clauses only**, a target that is `DST_KNOWN_RED` (`Makefile:655`), and it reaches only the claude/codex graded script. `do_check_motoko`'s re-read and the `settled` metadata close at T1 (extension L1 tests) alone. |
| W2 | T1 + T2 + T3 | the fifteen tests at T0 + T1; ABI package tests at T1; DP7-before-solver at T2 (`phase_c_l1`); `ledger_parity` frames at T3 (regression, and the stage-2 world expression in §7) |
| W3 | T0 + T1 + T2 | unbound default "calls no port" at T0; the scanner fixture case and its red-first record are T2 (selftest; §7) |
| W4 | T1–T4 | 4-call fixture at T2, on each channel separately; witness and tree mutant at T3/T2; live metric and live parked run at T4 |
| W5 | T1 + T2 + T3 + T4 | pure units at T1; `journal_resume` at T2; `world_framed_wire` and `ledger_parity` at T3, as regression only, since the harness cannot reach the loop (§0.2 rule 7); the three-turn live probe at T4 |
| W-O5 | T1 + T2 + T4 | T2 is `herdr_graded`'s run clauses of a known-red target, as for W1b |

A claim is reported at the tier it was verified at, never above it.

**Handoff.**
- Each work item's commit names the ADR decision and cites its gate results.
- §7 holds every T4 result with log paths.
- v1 was reviewed (`REVIEW-plan002-v1-verdicts-claude.md`), and v2 applies its 24 changes.
  v2 was re-reviewed (`REVIEW-plan002-v2-verdicts-claude.md`), and v3 applies its R1–R11.
  - W1a may start. W1b may start on v3 (R4 applied), since it touches no core file (R7).
  - W2 and W3 start on v3. W4 starts on v3 (R1, R2, R3, R5 applied), with the owner noting
    §8.3's mechanism note. W5 still waits on W4's live gate.
  - W3 Part 1 had waited on §8.6's sign-off and W4 Part 5 on §8.7's; both are signed off (owner 2026-09-13), so no item waits on §8.

---

## 6. What PLAN-003 P4 (ADR-003 D7) consumes from here

From W4:
- `ParkRequest` with `request_id = <run_id>.p<park_ordinal>`;
- `Ports.wake_read` and its live binding, which P4 extends to read the seeded cursor first;
- the `WorldState.wakes` cursor and its codec (W3);
- `ParkEntered` and `WakeReceived`, appended and emitted, which become P4's `park` and `wake`
  entries. A dropped (mismatched) reply appends no `WakeReceived` (W4 Part 2, R2), so every
  `wake` entry is a wake the loop applied. A re-issue appends no second `ParkEntered`;
- the host `wake_request`/`wake_reply` protocol, which P4's suspended-child state owns across
  an exit;
- `recording_wake` (P4's recording binding pattern).

From W5: the between-turn frame and its identity rule. P4 does not start before W5's gate.

---

## 7. Results

*Empty in this draft.* Each entry records: date, HEAD, command or procedure, raw output or log
path, and tier.
- W1a: herdr message probe (T4).
- W2: the stage-2 rejection arm's world expression, and the `ledger_parity` frames that confirm
  it (T3) (review change 23; not commit-message-only).
  - **Entry (2026-09-13, W2 commit on `957c91e`, T3).** Expression chosen:
    `token_to_world(clear_holder(ctx.world))`, where `ctx` is the `classify_candidate` context,
    `{ post_ctx | world: intercepted.next_state }` (`session.ail` `classify_candidate`, stage 2).
    Reasoning: HEAD's rejection arm carried `token_to_world(finalized.next_state)` =
    `token_to_world(clear_holder(collected.next_state))` (`ext/runtime.ail:722`, `:727`); with an
    empty registry `collect_finalize_decisions` returns its input world, so that is
    `clear_holder(ctx.world)`. `ctx.world` is the intercept's successor and is already
    holder-cleared (`dispatch_response_intercept`, `ext/runtime.ail:531`); `clear_holder` is
    idempotent on it (`put_key` drops and re-appends the key, `ext_world.ail:653–659`). The
    candidate `token_to_world(finalized.next_state)` does not exist at stage 2 (no solver ran).
  - **Confirmation, procedure.** `ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand
    --entry main scripts/dst/ledger_parity_dst.ail` at `957c91e` (raw stdout, all eight
    `WORLD_RUN_BEGIN/END` frames and every wire line) and on the W2 tree: **byte-identical**
    after dropping the lock-staleness warning lines. Same for `scripts/smoke_v2_dp7_gate.ail`
    (`--ai-stub`). `make ledger_parity`: `ledger_parity wire gate PASS`; `make world_framed_wire`:
    `frame dp7: ordinal0=0 requests=20 strict +1 to final=20`, 154 `world_request` lines, PASS.
    **Regression only** (both fixtures register no extension, so order-invariant by
    construction); the order itself is W2 gate 2 (`phase_c2_wiring_scenarios`, six `w2_*` cases).
- W3: the red-first record, meaning Part 6's fixture is invisible under the pre-Part-5
  `CALL_RE` (T2) (review change 23; not commit-message-only).
  - **Entry (2026-09-14, W3 tree on `a2113e8`, T2).** Procedure: load `derive.py` at
    `a2113e8` (`git show a2113e8:tools/driver_leaf_inventory/derive.py`) and the W3
    `derive.py`, and call `classify_fixture(strip_noise(src))` on both W3 fixtures, three ways.
    Raw output:
    ```
    form_wake_read_unwitnessed.ail:
      (a) a2113e8 derive.py (pre-Part-5 CALL_RE+HELPED): no-helped-leaf
      (b) W3 derive.py, CALL_RE reverted only (HELPED has wake_read): no-helped-leaf
      (c) W3 derive.py as landed: advanced-unwitnessed
    control_wake_read_witnessed.ail:
      (a) a2113e8 derive.py (pre-Part-5 CALL_RE+HELPED): no-helped-leaf
      (b) W3 derive.py, CALL_RE reverted only (HELPED has wake_read): no-helped-leaf
      (c) W3 derive.py as landed: clean
    ```
    (b) isolates `CALL_RE` as the part that blinds the scanner: adding the `HELPED` keys
    without the method alternation still finds no leaf. With Part 5 applied,
    `make driver_leaf_inventory_selftest` reports `form_wake_read_unwitnessed.ail
    [advanced-unwitnessed]` and `control_wake_read_witnessed.ail [clean]`, with 0 failures.
    `make driver_leaf_inventory` still reports 24 sites, 0 unresolved and 0 out of order,
    the same count as the `a2113e8` scanner on the same tree, and `WakeRead=0`.
- W4: live 4-call measurement; live parked run (T4).
- W5: live three-turn probe (T4).
- Each step: the sweep disclosure.

---

## 8. Owner decisions (decided 2026-09-13; none reopens an ADR decision)

All seven items below are **decided as written** (owner, 2026-09-13).

1. **Blank candidates and DP7 (§1 row 7): DECIDED — verify.** A blank candidate that
   clears the empty-stop guard is still verified in `c2_after_dp7`, per HEAD behavior.
   The alternative (blank finalizes unverified) is rejected as an unpriced live behavior
   change under a verifier.
2. **O5's trigger (§1 row 14, W-O5): DECIDED — plan's trigger.** O5 becomes schedulable when
   W3's gate is not green within its estimate after W2's gate is, **or** W4 cannot be
   activated before the next measured delegation run the owner schedules. The ADR's literal
   trigger (fired when P2 landed) is not used.
3. **A mismatched wake reply in core** (W4 Part 2): DECIDED — re-issue with step-charge bound
   (owner 2026-09-13, review change 13). The ADR's "dropped
   and logged, never applied to a different pending wait" stands; what the loop does next is:
   re-issue the same `ParkRequest`, same `request_id`, no ordinal increment, from the single
   `wake_read` call site, charging `step_idx + 1` per re-issue so the existing step budget
   (`pol.step_budget`, the predicate `call_model_or_fail` applies) bounds re-issues (the step
   budget reads as driver steps from W4 on). `ParkEntered` is NOT re-emitted; `recording_wake`
   carries an `attempt: int` per re-issue of the same `request_id`. The "wrong handle" fixture
   asserts the bound, the single `ParkEntered`, and the attempt ordinals.
   Decided before W4 Part 2 (now).
   - **Mechanism note (v3, R1; noted by the owner 2026-09-13; the intent is unchanged).** v2 said the
     `call_model_or_fail` check bounds re-issues "through the normal `user_injected →
     call_model_or_fail` route". A re-issue never reaches that function: it re-enters
     `decide`'s `Park` arm, which precedes it. That route belongs to the accepted wake's
     continuation.
     - **The corrected path.** The same predicate (`pol.step_budget > 0 && step_idx >=
       pol.step_budget`) guards `decide`'s `Park` arm (W4 Part 1). Exhaustion is
       `Fail(StepBudgetExhausted)`, which suspends the run (`session.ail:3024–3025`), and the
       continuation clears `open_waits`.
     - **What still holds.** A step charge bounded by the existing budget, the same
       `request_id`, no ordinal increment, and one `ParkEntered`.
     - **Pinned by R2.** A dropped reply appends no `WakeReceived`, `attempt` is
       `C2LoopState.park_attempt`, and `ParkRequest.step` stays at the park's original step.
4. **The between-turn frame's `request_id` base (W5(b)): DECIDED — next run's identity, seeded
   runs start at ordinal 1** (owner 2026-09-13, review change 14).
   The between-turn park uses the identity of the run the operator's input will open,
   `loop_run_identity(session_id, profile, resume_count, next_ordinal)` (definition
   `session.ail:4274`), so `request_id = <next run_id>.p0`. That run's
   `run_started` then follows the consumed wake, which is the shape ADR-003 D7's
   exactly-once rule reads — agreeing with D7's "rewritten to the re-issued request (`run_id`
   + park ordinal 0)" for the case where the resumed run's first park *is* that request.
   To keep `.p0` unique, a run seeded from a consumed between-turn wake starts with
   `park_ordinal == 1` (first in-turn park `<run_id>.p1`). Decided before W5 (now).
5. **`DelegateAwait` after activation** (W-O5): DECIDED — retire. When W4 activates,
   `DelegateAwait` is retired (not kept as a plain tool), leaving the port-served park as
   the single wait mechanism.

### Decided in v2 review (owner 2026-09-13; signed off, gating v2 items)

Neither item reopens an ADR-002 decision. Each is a type or mechanism the plan pins under one.

6. **`WakeObservation` as the `wakes` cursor element (§1 row 8; review change 10): SIGNED OFF.**
   - ADR D2's table types the cursor `WorldState.wakes: [WakeInput]`, and `WakeInput` carries
     `next_state: WorldState`, which makes the type recursive. The ADR's prose says "a fixture
     supplies observations, never whole worlds" (`ADR-002:427`).
   - The plan follows the prose: the element is `WakeObservation = { request_id, wait_id,
     outcome }`, and adapters build `WakeInput`.
   - This changes the declared element type of a cursor ADR-003 D7 also seeds.
   - Signed off; W3 Part 1 is unblocked on this item.
7. **Commands received during an in-turn park (W4 Part 5's table; review change 15): SIGNED OFF.**
   - **What the ADR fixes.** `abort` is `Aborted`; `restart`/`exit`/EOF cancel and take today's
     exits. `WakeOutcome` has no cancel arm.
   - **What the plan pins:**
     - all four return `Aborted`, with the command carried in `wait_id`, which is unmatched for
       `Aborted` (change 12);
     - the run ends `Fail(ParkCancelled)` with no `error` event;
     - the conversation loop then takes today's exit for that command (`SessionSuspend` for
       `restart` only);
     - `model_change` is deferred by the host while parked;
     - ESC during a park sends `abort` rather than killing the runtime.
   - Signed off; W4 Part 5 is unblocked on this item.

---

## 9. Coordinate map, `3ee3d03` → `d888585`

The delta review's §3 map, extended with the coordinates this plan added and verified at HEAD.

| ADR cites (`3ee3d03`) | HEAD `d888585` |
|---|---|
| `session.ail:684–697` `c2_step_state` | `:926–940` |
| `session.ail:1930–1934` verifier / `:1933` exec | `:2197–2211` / `:2200` |
| `session.ail:1976–1978` `dp7_rejection_errors` | `:2243–2255` |
| `session.ail:2352` / `:2394` | `c2_after_dp7` def `:2883`; verifier call `:2922`; `dp7_rejected` `:2942`; `dp7_approved` `:2971` |
| `session.ail:3012–3082`, `:3017`, `:3020`, `:3080` | `None =>` `:3716–3797`; dispatch `:3721`; `Accept` → `c2_after_dp7` `:3724`; nudge test `:3758`; else `:3794` |
| `session.ail:2468–2488` | empty floor `:3057–3061`; `DoneEvent` `:3069–3070`; `c2_finalize` `:3075`; emit `done` `:3076` |
| — decision arms | `Finalize` `:3027`; `InjectUserMessage` `:3079`; `AwaitApproval` `:3173`; `RunTools` `:3238`; `CallModel` `:3338`; names `:744–746` |
| `session.ail:3367–3430`, `:3368`, `:3372`, `:3391–3399` | loop `:4294–4507`; `readLine` `:4351`; EOF `:4352`; `cmd_type` `:4356`; restart `:4378–4390` |
| `session.ail:3380–3386`, `:3419`, `:3426`, `:3611` | `provider` param `:4307`; model-change world `:4371`; dropped `traced.world` `:4463`; recursions `:4484`, `:4491`, `:4498`; entries `:4638`, `:4697`, `:4755–4766`, `:4846` |
| — `C2LoopState`, identity | `:509–569`; `c2_loop` `:2985`/`:2998`; `run_id_for` `:4269–4271`; `loop_run_identity` definition `:4274` (call `:4404`); `witness` `:4163`, `witness_drain` `:4167–4176`; `work_in_flight` `:1883`, `:1907`; `c2_state_from_continuation` `:2591` |
| — added in v2 (review §9 "not cited, load-bearing") | initial turn's dropped manifest successor `:4723`; `started_provider` entry `:4759`; manifest's witnessed `env_read` `:4582–4583`; the only `abort` read `:4357`; `Fail` arm `:3023` |
| `step_machine.ail:93–111` / `:114–138` / `:134–135` / `:246–396` | `:96–114` / `:116–141` / `:136–137` (`tools_complete`; `user_injected` is `:138–139`) / `:258–408`; pending-tools arms `:117–123`; stop class `:130–131`; `dp7_fail_open` test `:374–381` |
| `phase_vocab.ail:308–318` / `:449` / `:901–902` | `StepState` `:424–434` / `StepDecision` `:564` / cap `:1274–1283`, `result_env_model_content` `:1309–1311`, `handled_tool_message` `:1344–1352` |
| `tool_phase.ail:436–449` | `Handled` arm `:439–449` |
| `ext/runtime.ail:676–677` | `dispatch_solver_candidate` `:721–728` (`clear_holder` `:727`) |
| `ports.ail:183–196` (no ordinal) | `WorldState` `:183`, `approvals` `:208`, `ordinal`/`pending` `:493–494`; empty world `:764`; `Ports.approval_read` `:829` |
| `ports.ail:979–983` / `:1718–1745` / `:2556–2572` / `:2558` | `scripted_approval` `:1019–1024` / `recording_approval` `:1758–1786` / `ports_shape_probe` `:2596–2612` / `:2598` |
| — | `world_ordinal.ail` `advance` `:33–36`, ids `:41–61`, negative test `:112`; `ext_world.ail` negative test `:811–823`, `approvals` codec `:554`/`:587`, fixture `:687–774` |
| `long_qwen_compaction_dst.ail:383–402`, `:513–532` | `:385–405`, `:515–535` |
| `stub_step.ail:205–213` / `:786` | live approval `:209–223` (`live_ports` `:186`) / `empty_rt` `:788–791`; recording `:557`; generating `:651` |
| `dst_interaction.ail:59–66` | `ApprovalIdentity` `:62` |
| `dst_replay.ail:707–718` | `approvals_of` `:707–718` (its comment starts at `:703`); queue balance `:582` |
| `dst_invariants.ail:788–806` / `:946` | `RecordAfterTerminal` `:330`, `:891` / `parity_findings` `:1180` |
| `rpc.ail:218–237` | `await_first_task` `:250` |
| `derive.py:14–22` / `:142` / `:151–155` | freeze note `:10–30` (`:21`) / `REQUEST_CLASS` `:164` / `CALL_RE` `:173–177`; `HELPED` `:94–105` |
| `herdr.ail:164–167` / `:172–177` / `:1057–1132` / `:1100–1102` / `:947–955` / `:1162–1175` | `meta_kind` `:191–195` / `meta_timed` `:199–206` / `do_check_motoko` `:1432–` / error branch `:1466–1478` / `dagr_open` `:698` / `do_check` `:1537`; `do_delegate` `:1151` |
| `register.ail:142` (20000) | `register.ail:173` (45000) |
| `progress_contract_guard.ail:141–191` | `has_open_delegate` `:199`; `decide_with_budget` `:203–208` |
| `empty_stop_guard.ail:20–37` | `is_blank` `:8–10`; `decide_with_budget` `:62–66` |
| `herdr-agent-state.ts:43` / `ui.ts:790` | `:43` (with `suspended`), `mapRunState` `:90–103`, release `:306–309`, `:338` / `RunState` `ui.ts:798` |
| `ui.ts:2752–2755` / `:4046–4049` | `case "error"` `:2770` / `shouldLockPlainInput` `:1798–1804` (`:2218` is the spinner tick, not a guard); ESC → `onInterrupt` `:2147–2157` |
| `index.ts:605–606` / `:820–827` / `:870–883` | `--headless` `:613–632`, exit on `done` `:598` / re-locate / non-TTY terminal forward `:979–984`; TTY event callback `:1033–1054`; `onInterrupt` → `kill()` `:1190` |
| `runtime-process.ts:754–778` | `send` `:842`; commands `:862–891` |
| — Makefile | `DST_TARGETS` `:480–491`; `DST_KNOWN_RED` `:655`; `ledger_parity` `:349–351`; `world_framed_wire` `:361–364`; `journal_resume` `:307`; `event_vocabulary` `:1473`; `smoke_driver` `:2314`; `anchors` `:2999`; `driver_leaf_inventory` `:3023–3027` |

Not re-verified at HEAD, and re-located by the implementer before editing: the ADR's
`herdr.ail:935–943` and `types.ail:749–758` (`Delegate` returns before the agent row exists),
`types.ail:706–718` (task text), `index.ts:820–827` and `ui.ts:4046–4049`.

---

## Cross-references

- `ADR-002-park-and-wake.md` v4.2: D1–D5, Consequences, Implementation handoff (`:663–670`).
- `REVIEW-adr002-v4.1-v4.2-delta-verdicts-claude.md`: "Required changes" 1–5 (§1 rows 1–5
  here), §3 coordinate map (§9 here).
- `REVIEW-adr002-v4-verdicts-fable.md`: §3 the pipeline, §4 the lifecycle table, §5 the
  unbound default, §6 the metric, §7 D4's world.
- `REVIEW-adr002-verdicts-codex.md`: §7.2 the precedence model, §7.3 the scanner mutant.
- `PLAN-001-implement-adr-001.md`: §1 the sweep; §2.1 the derivation script and the
  five-class freeze; §2.2 event classification; P2 Parts 1–3 (`advance`, `witness`, framed
  wire).
- `PLAN-003-implement-adr-003.md`: §0.6 what the harness cannot see; P1 Part 5
  (`RunIdentity`, loop identity); P1 Part 6 (live probe shape); P4 (D7, the consumer of §6).
- `ADR-003-session-journal-and-resume.md` v6.1: D5 (`run_id`), D7 (durable park).
- `ADR-001-sequencing-the-dst-architecture-caps.md`: D2, D6; `:448` (loop out of the frame
  gate's reach).
