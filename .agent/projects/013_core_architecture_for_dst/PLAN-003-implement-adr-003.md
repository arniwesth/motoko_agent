# PLAN-003: implement ADR-003 v6.1 — session journal and resume

Date: 2026-09-07. Status: **proposed (v3.1), P1 ready to start.** v3 was reviewed by Claude
Fable (`REVIEW-plan003-v3-verdicts-fable.md`, HEAD `97827bf`): *accept with corrections; P1 can
start after two line edits; P3 cannot start until its part order is repaired*; fidelity to
ADR-003 v6.1 accepted in full. v3.1 applies its six changes, unreviewed (§6). v1 and v2 of this plan implemented
ADR-003 v4.1's checkpoint design and were reviewed twice (`REVIEW-plan003-verdicts-fable.md`,
`REVIEW-plan003-v2-verdicts-fable.md`); v2.1 was ready to start. ADR-003 then went to v5 and
v6.1, journal-only (`REVIEW-adr003-v5-verdicts-fable.md`, `REVIEW-adr003-v6-verdicts-fable.md`),
and v3 of this plan follows its D8: **P1 kept with four parts changed by deletion, P2 deleted,
P3 reshaped, P4 as D7.** §6 lists the deltas. Everything §0 decided and everything §5 measured
stands.
Grounded at: HEAD `97827bf` on branch `arniwesth/013-dst-architecture-adr`.
Governing decision: `ADR-003-session-journal-and-resume.md` version 6.1, which its last review
says PLAN-003 v3 may be written against.

**Thesis.** A run that reaches its step budget stops being an internal error whose history
dies in the driver's `Fail` arm, and becomes a typed suspension that carries the loop state out
of the run, first in memory and then onto a journal the host writes from the wire it already
receives. Every entry of that journal carries an id and a parent id; the child performs no file
IO; resume is a pure fold of the journal, and the same fold over a run's own trace is an
invariant on every fixture the harness already has. A durable park (ADR-002's `Park` exiting the
runtime) is two more entry types, later.

**The numbers this plan is judged on** (ADR-003 TL;DR): after a run reaches its step budget,
the operator's next `continue` produces a first provider payload that contains the exhausted
turn's history, and the step count continues; and **a run that dies at step N resumes with N
steps of history**. Today the payload contains the pre-turn history (`session.ail:3605–3611`),
and a crash loses the run.

---

## 0. Preconditions and standing rules

1. **The sweep.** ADR-001 D6 makes `make dst DST_JOBS=1` a workflow precondition before any
   boundary edit, disclosed per PLAN-001 §1. **Run for this plan on 2026-09-06 at `97827bf`;
   results in §5.** Known red at `97827bf`: `make anchors` fails on all eight pinned anchors —
   `session.ail:1164`, `:1423`, `:1529`, `:3016`, `:3126` and `tool_phase.ail:317`, `:318`,
   `:413` (`anchors.sh:384–387`; `:1529` is now `func c2_finalize(`, not a clock read). The
   script's footer says a re-baseline is a D4 judgement — which site is "the" attributed one —
   that re-issues three profiles (`driver_only_version`, `no_ops_version`,
   `compose_profile_version`, `anchors.sh:379–381`). The disposition lands once, with P1 Part 4
   (item 2), and is priced in P1 (one day, §7). The depth canary's disposition is the owner's
   (§5).
2. **The anchor cascade.** Every edit to `session.ail`, `tool_phase.ail` or `stub_step.ail`
   above the pinned anchors is followed by `make anchors`
   (`tools/predicate-anchors/anchors.sh:22`). P1 edits `session.ail` at `:175–180`, `:1554`,
   `:2164–2169`, `:2437`, `:3330–3346`, `:3418–3427`, `:3561`, `:3603–3612`, and removes
   lines at `:431–437`, `:443–`, `:545–553`. **Three P1 commits move anchors**: Part 2
   (`:2164–2169`, moves `3016` and `3126`), Part 3 (the removals, moves all five), Part 4
   (`:175–180`, the split at `:2437`, the `c2_finalize` parameter, moves all five). Each
   re-baseline re-issues the three profiles, so the choice is **four re-issues or one**.
   **This plan takes the one-re-issue path:** the disposition of the eight stale anchors is
   deferred to land with P1 Part 4's commit, and for P1 only, this rule is relaxed to "`make
   anchors` green at the end of the phase" — Parts 2 and 3 record their expected anchor drift
   in their commit messages and do not re-baseline. **P3 moves no anchors for a writer**: there
   is no writer in the child. P3's `session.ail` edits are the event emits at the history sites
   and the seed at the traced entry, plus the `history_digest` field in the loop state at
   `:383–429`, so P3 Part 3 (the emits) is one more re-baseline, priced there.
3. **The vocabulary gate.** `make event_vocabulary` (`Makefile:1283`) requires one vocabulary
   row and one golden per `LedgerEvent` variant. Each new variant lands with its row and its
   golden in the same commit. P3 Part 1 adds five variants and two fields at once, in one
   commit, for that reason.
4. **Tests.** Core: `ailang test src/core/<module>.ail` per module touched (`session.ail`,
   `phase_vocab.ail`, `step_machine.ail`, `dst_invariants.ail`, `dst_execution.ail`, the new
   `journal.ail`); DST scripts by their Make targets. Host: `bun run test` in `src/tui`
   (jest, `src/tui/package.json:9`) and `tsc`.
5. **One commit per part**, on top of `97827bf`, each naming the ADR decision it lands
   (`ADR-003 D2: …`). Nothing is pushed by this plan.
6. **What the deterministic harness cannot see.** Deterministic runs drive the traced entry
   directly and never reach the conversation loop (`session.ail:3359–3366`). The in-process
   `continue` is therefore verified three ways, stated per gate: a DST fixture for the
   suspension inside the traced run; pure unit tests for the loop rule and the resume
   constructor, which P1 factors out as pure functions for that reason; and one live probe
   that **drives the runtime directly**, not the TUI. The TUI cannot be the probe's driver: a
   non-TTY stdin forces `MOTOKO_HEADLESS=1` (`runtime-process.ts:355–357`), under which the
   conversation loop returns before reading anything (`session.ail:3357`), and the plain
   logger does no stdin handling (`index.ts:415`, `:1063`). The probe runs `rpc.main`
   (`rpc.ail:355–359`) with `MOTOKO_HEADLESS` unset and a stdin pipe held open, and reads the
   child's **stdout**, which is the same wire the logger would have written
   (`session.ail:335–341`). The cross-process resume, by contrast, **is** visible to the
   harness: P3's resume fixture folds a journal built from a traced run's own records.
7. **Exported entries keep their signatures.** `run_v2_session_traced` (`session.ail:3148`),
   `run_v2_session_traced_with_persist_retries` (`:3170`) and `run_v2_with_stub` (`:3619`)
   have call sites in twenty files under `scripts/dst` and `src/core/test`. Nothing in this
   plan changes their signatures: they build a default `RunIdentity` (`r0.0`, profile `""`),
   and only the conversation loop's path passes an explicit one through a new
   `run_v2_from_continuation_traced` / `_with_identity` sibling (P1 Part 4).
8. **The child writes no file, in any phase.** `Ports` gains no field; `derive.py`'s `HELPED`,
   `CALL_RE` and `REQUEST_CLASS` (`tools/driver_leaf_inventory/derive.py:94–105`, `:142`,
   `:151–155`) are untouched; the resume-time read of the journal is the ambient `readFile`
   `run_with_config` already uses for the prompt file (`rpc.ail:266–267`), outside the traced
   surface (`rpc.ail` is not in `SCAN_FILES`, `derive.py:144–149`). **Nor a new helped leaf:**
   every `ports.env_get` is a helped `EnvRead` (`derive.py:95`) and five fixtures pin the exact
   key set the policy init reads (`seeded_generator_dst.ail:415–421`; `run_report_dst.ail:173–178`;
   `strict_replay_dst.ail:400`; `discovery_dst.ail:665`; `driver_plus_compose_dst.ail:990`), so
   `MOTOKO_RESUME_COUNT` is read **ambiently** in `rpc.run_with_config`, as `headless_mode()`
   reads its variable (`rpc.ail:189–192`), and passed down. Any part that finds itself adding a
   `Ports` field or a `ports.env_get` key has left the ADR.

---

## Phases (ADR-003 D8 order)

| phase | ADR-003 D8 | scope | estimate |
|---|---|---|---|
| P1 | step 1 | typed suspension, `suspended` and `final`, the `[Message]` codec, in-process resume, the host's `run_suspended` case | 6–9 days, core + host |
| P2 | — | **deleted** (v4.1's ported writer, its class, its leaf module, the strict world decoder, the child-written restart update) | 0 |
| P3 | step 3 | the journal-class vocabulary, then the fold and its invariant family (red), then the emits (green); the host's journal writer, identity and lease; `--resume`; the rest of the wire | 9–12 days, core + host |
| P4 | step 4 | durable park as entries (D7) | unscheduled; gates named |

P1 depends on nothing outside this plan. P3 depends on P1 and on nothing from PLAN-001 P2
except one field: `run_finished.world_ordinal` is added when P2's `ordinal` exists
(`ports.ail:183–196` has none at `97827bf`), and the fold ignores it until then. P3's parts are
ordered so the invariant is written first and is red until the events land.

---

### P1 — D8 step 1: the typed suspension and the in-process resume (6–9 days)

**Dependencies.** §0.1 sweep, done; the anchor disposition lands with Part 4.

**What lands.** ADR-003 D2's suspension, D1's `Continuation` and `RunIdentity` types and the
`[Message]` codec, D4's `final` projection, D5's in-loop identity, D6's in-process half, and
the host side of D2 that keeps the operator unlocked. **Four parts changed from v2.1 by
deletion** (§6): no `written`, no `Snapshot`, no world decoding, no generation reset.

#### Part 1 — the acceptance test, red first (½ day)

1. **DST fixture, traced run.** In `scripts/dst/phase_c2_wiring_scenarios.ail`, a third
   runner beside `run_scripted` (which hardcodes `step_budget` 8, `:120–122`) with
   `step_budget: 3`, driving **continuing tool-call steps**: `continuing_token_step`, defined
   in `src/core/test/stub_step.ail:771–781` (one `BashExec` call, `finish_reason:
   "tool_calls"`), which the wiring file's `stub_step` import (`:33`) must add;
   `terminal_trace_dst.ail:77–80` wraps it and `scenario_max_steps` at `:127–134` is the
   precedent with a budget of 2. A plain assistant reply would finalise at the first step —
   a `stop` finish reason goes straight to `Finalize` (`step_machine.ail:128–129`) — and each
   tool-call step appends an assistant message *and* a tool result. Assert today: `result`
   is `Err` with code `Internal`, `finish_reason` `max_steps` (`session.ail:2205`, `:3697`),
   and the returned value carries no history. After Part 4: `suspended` is `Some(s)` with
   `List.length(s.history) == 8` — the seed is system and user (`:66–68`), then three
   assistant and three tool results; **expected 8, pinned at first green**, since no existing
   scenario asserts a history length — `s.cumulative.provider_calls_completed == 3`,
   `s.step_idx == 3`, and `final.history == s.history`. **Asserted directly on the value**, not
   through a fold: the fold and its events are P3's, and this fixture stays the in-memory
   half's. `RunSuspended.session_id` carries the **run's derived id** (`:3137–3139`), the one
   every other event of the run is stamped with (`:335–341`), until P3 forwards the session
   id. The ledger has `RunSuspended` immediately before `RunSummary` and nothing after it
   (`RecordAfterTerminal`, `dst_invariants.ail:788–796`); `RunSummary.error` is non-empty and
   `outcome_agreement` is green (`:1385–1388`); no `ErrorEvent` in `emissions`. The file runs
   under `phase_c_l1` (`Makefile:342–345`), already in `DST_TARGETS` (`:436–441`).
2. **Pure unit tests** (stubs now, filled in Part 5): `c2_state_from_continuation(c,
   provider)` and the loop's `run_ordinal` rule in `session.ail` `tests [...]` blocks,
   following `test_decision_fail_reason_mapping` (`:3705–3712`). The stubs assert the
   post-change values, so they are red now.
3. **Live probe script** (`scripts/probe_budget_continue.sh`, new), the §0.6 shape: run
   `rpc.main` with `MOTOKO_HEADLESS` unset, `--no-backend` (`config.ail:235`; native tools
   do not use the env server, `tool_phase.ail:452–453`), a live provider key, and a stdin
   pipe that carries the first task, then `{"type":"user_message","content":"continue"}`,
   then `{"type":"exit"}` — `await_first_task` reads the task (`rpc.ail:277–296`), the loop
   reads the next lines (`session.ail:3367`), `exit` returns (`:3373`), and the pipe stays
   open until then because the AILANG `readLine` blocks rather than returning EOF on a
   non-TTY (`:3352–3353`). **The budget is a profile setting**: `max_steps` is read from the
   profile's agent JSON (`config.ail:313`) under `<workdir>/.motoko/config/<profile>`
   (`:186–187`), and the loop's `step_budget` is `budget.total`, which
   `default_budget_plan(max_steps, …)` sets to `max_steps` (`rpc.ail:88–94`, `:116–118`,
   `:351`) unless an extension's budget hook patches it. The probe ships a `probe-budget`
   profile directory with `max_steps: 5` and **no budget-patching extension**, passed as
   `--profile`. Read the child's stdout. The judging number's `steps_executed_so_far` is a
   **tool output** (`runtime_status_json` is produced only when the model calls
   `MotokoRuntimeStatus`, `session.ail:2658`), so the probe asserts the wire-visible
   equivalents, each with its condition: the resumed run's first
   `provider_call_prepared.msg_count` (`:2773–2775`) equals the exhausted history plus one —
   `msg_count` is the **compacted payload's** length (`List.length(compacted_msgs)`, `:2768`),
   so this holds only while no compaction stage rewrote the payload
   (`compaction_ai_applied == 0`) and nothing was injected before the call, which five steps
   guarantee; each `run_summary.steps_executed` (`st.step_idx` at finalize, `:1535`;
   projected at `phase_vocab.ail:791`) is per run, 5 for the exhausted run and the resumed
   run's own — and this agrees with `provider_calls_completed` (`:576`), the judging number's
   field, only when every step's provider call completed, which a probe without stream
   errors satisfies; the resumed run's stdout shows `run_suspended` before `run_summary` and
   no `error` (the D2 wire contract in live form); after P3, one `session_id` across both
   runs. Red today: `msg_count` is 2. This is the first judging number's live form, and the
   plan states the substitution and its conditions.

**Gate.** All three red at `97827bf`, checked in red.

#### Part 2 — D2 item 1: the code (½ day)

- `step_machine.ail:93–103`: `Fail({ code: "StepBudgetExhausted", message: "step budget
  exhausted", retryable: false })`.
- `session.ail:2164–2169`: `decision_fail_reason` maps the code; the message clause goes.
- Delete `max_steps_discriminator_message()` (`dst_fault_catalogue.ail:210`), its test
  (`:825–829`), its header rationale (`:50–59`); rewrite `test_decision_fail_reason_mapping`
  (`session.ail:3705–3712`); trim the comments at `session.ail:2155–2160` and
  `dst_fault_catalogue.ail:50–53` that call the code a TUI compatibility surface (the TUI's
  `error` type has no `code`, `runtime-process.ts:96`).
- Close `.agent/issues/max-steps-termination-discriminated-by-error-message-string.md` with
  the commit hash.

**Gate.** `ailang test src/core/session.ail`, `step_machine.ail`, `dst_fault_catalogue.ail`
green; `make fault_catalogue` (`Makefile:1221`) green;
`finish_reason_wire(TermMaxSteps) == "max_steps"` still asserted (`:3697`).

#### Part 3 — D1: `journal.ail`, the types and the codec (1 day)

New leaf module `src/core/journal.ail`, importing `phase_vocab` (`Message`,
`RuntimeStatusCounts` after the move below, `history_from_seed`, `history_valid_transcript`,
and four helpers that are **private at HEAD and must be exported** in this part —
`system_is_head_prefix` (`phase_vocab.ail:75`), `take_system_prefix` (`:85`),
`canonical_messages_raw` (`:237`), `digest_messages` (`:245`); `History` itself (`:26`) stays
private and is reached through `history_from_seed` (`:28–31`)), the ABI (`BudgetPlan`,
`packages/motoko-ext-abi/types.ail:61`), `config` (`CostRates`, `config.ail:30`), `std/json`.
It must not import `session` (cycle) and, in P1, imports neither `ports` nor `ext_world`: the
journal carries no `WorldState`. Contents in P1:

- `Continuation` — ADR-003 v4.1's `ContinuationBody` lifted: `history`, `step_idx`,
  `cumulative`, `telemetry`, `ext_artifacts`, `nudges_used`, `model`, `profile`, `task`, the
  boot inputs — the in-memory value `suspended` carries. `RunIdentity { session_id, run_id,
  profile }`. `FinalState { history, cumulative, telemetry, ext_artifacts }`. **No `Snapshot`,
  no `Refusal`, no entry types yet** — those are P3 Part 2's.
- **One type move.** `RuntimeStatusCounts` is declared without `export` in `session.ail`
  (`:431–437`) and `Continuation.cumulative` needs it. The type, `zero_runtime_status_counts`
  (from `:443`) and `runtime_status_counts_add` (`:545–553`) move to `phase_vocab.ail`, which
  `session.ail` already imports; `session.ail` re-imports them. `zero_totals` (`:439–441`)
  returns `RuntimeLoopTotals` and **stays**; `runtime_status_counts(trace)` (`:541–543`) stays.
  No behaviour change; this is the second of P1's three anchor-moving commits and records its
  drift without re-baselining (§0.2).
- **Import graph, checked.** `phase_vocab.ail` imports `compaction`, `tool_contract`, `types`
  (`:17–19`); `config.ail` imports no `src/core` module; the ABI is a package. None imports
  `session`, so `journal.ail` is acyclic and `session.ail` importing it closes no cycle.
- `message_json` / `message_of_json` (`[Message]` codec) covering `role`, `content`,
  `tool_calls`, `tool_call_id`, `images` — new work, since the ABI's `Msg` has no `images`
  (`packages/motoko-ext-abi/types.ail:547`; `session.ail:3402–3408`).
- Tests: round trip of every `Message` role and a message with two images; a `Continuation`
  built from a three-step history whose `cumulative` equals `runtime_status_counts_add` of
  its parts.

**Gate.** `ailang test src/core/journal.ail` green; `ailang check` on the tree; no new import
edge into `session.ail`.

#### Part 4 — D2 items 2–4 and D4's projection: the fields, the capture, the arm (1–2 days)

- `TracedSessionResult` gains `suspended: Option[Continuation]` and `final: FinalState`
  (`session.ail:175–180`). `c2_finalize` gains a `final: FinalState` parameter, set at **all
  seven** callers (`:2206` via `c2_fail`, `:2429`, `:2482`, `:2551`, `:2758`, `:2765`,
  `:2873`), each with `st` in scope; `c2_fail`'s one caller (`:2437`) hands it `st`. The
  literal at `:1554` copies `final` and sets `suspended: None`. (PLAN-003 v2.1 settled this as
  a record update at two sites; with seven arms the parameter is the smaller edit, ADR-003
  v6.1.)
- `c2_loop` gains `identity: RunIdentity` (`:2407–2421`). The internal
  `run_v2_from_messages_traced_with_policy_and_counts` threads it; the **exported** entries
  (§0.7) keep their signatures and build the default identity; the conversation loop's path
  gets a `_with_identity` sibling. The per-run `derive_session_id` at `:3137–3139` stays (the
  DST env-read counts depend on it) and `identity.session_id` is what it returns once P3
  forwards the id.
- The `Fail` arm at `:2437` splits: `StepBudgetExhausted` → `c2_suspend(rt, task, …, st,
  identity, trace_with_decision)`, which builds the `Continuation` from `st`
  (`cumulative = runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))`,
  `:545–553`, `:559`), appends and emits `RunSuspended({ session_id, run_id, reason:
  budget_exhausted, step })`, and finalises with `TermMaxSteps`, `result: Err`, `suspended:
  Some`, `final` from `st`. Its effect row is the loop's (`:2422`). Every other code goes to
  `c2_fail` as today.
- `RunSuspended` joins `LedgerEvent` (`phase_vocab.ail`) with its vocabulary row in
  `dst_event_vocabulary.ail` and its golden in `phase_vocab.ail` (`golden` helper and table,
  `:1221–1229`); `run_suspended` joins the TUI's `AgentEvent` (`runtime-process.ts:58–103`).
- The outer loops (`:3418–3427`, `:3603–3612`): match `traced.suspended` first; when `Some`,
  emit no `ErrorEvent` **unless `policy.headless`** (read at `:2044–2053`), in which case
  `error` is emitted after `run_suspended` so the headless loggers still exit non-zero
  (`index.ts:517–519`, `:572–575`) until P3 removes it. Only the initial-turn arm (`:3606`)
  needs the conditional: under headless the conversation loop returns immediately (`:3357`),
  so the follow-up arm (`:3421`) is never reached in headless. The wire order in headless is
  `run_suspended`, `run_summary`, `error`, the same shape as today's `run_summary`, `error`.
- The DST bridge: `execution_of` (`dst_execution.ail:110–118`) copies `final` into
  `ExecutionUnderTest` (`dst_invariants.ail:553–556`), which gains the field; the one fixture
  literal and one record update that build that type (`scripts/dst/invariants_dst.ail:385`,
  `:1008`) gain it. No family reads it yet.

**Gate.** Part 1 fixture 1 green; `make event_vocabulary` green; `make anchors`
re-baselined and the three profiles re-issued **once**, here (§0.1, §0.2); `ailang test
src/core/session.ail`, `phase_vocab.ail`, `dst_invariants.ail` green; every DST target that
runs a traced entry still green (the additive fields touch no match site —
`REVIEW-adr003-verdicts-fable.md` §3 lists the thirty sites that must not need edits; if any
does, stop and re-read ADR-003 D2).

#### Part 5 — D5's loop identity and D6's in-process resume (1–2 days)

- `conversation_loop_v2_with_policy` (`:3330–3346`) gains `suspended: Option[Continuation]`,
  `run_ordinal: int`, `task: string`, `profile: string`, `resume_count: int`.
  `run_v2_with_conversation` (`:3561`) has `task`; `rpc.run_with_config` passes `cfg.profile`
  (`rpc.ail:257`) and `resume_count` down one level. `resume_count` is read **ambiently** in
  `rpc.run_with_config` from `MOTOKO_RESUME_COUNT` (`0` when unset, which is every run before
  P3), on the `headless_mode()` pattern (`rpc.ail:189–192`) — **not** through `ports.env_get`
  beside the policy-init reads (`session.ail:2041–2044`), which would be a new helped `EnvRead`
  and re-pin the five fixtures §0.8 names.
- **The loop's rule**, pure: `run_ordinal + 1` per traced run in this process, both `Ok` and
  `Err` arms of both outer loops; the `model_change` and discard arms (`:3374–3390`, `:3430`)
  recurse unchanged. The next traced run receives `RunIdentity { session_id, run_id:
  "<session_id>.r<resume_count>.<run_ordinal>", profile }`. No reset rule: nothing is written.
- **Pure** `c2_state_from_continuation(c, provider) -> C2LoopState`: `msgs` from `c.history`,
  `step_idx 0`, `totals: zero_totals()`, `prior_counts: c.cumulative`, `ext_artifacts`,
  `telemetry`, `nudges_used` from `c`, pending fields empty, `trace` empty, `emissions`
  empty. The only constructor beside `c2_initial_state_with_counts`.
- On `user_message` with `suspended: Some(c)`: append the operator's message to `c.history`,
  run the traced entry from `c2_state_from_continuation` (a new traced entry
  `run_v2_from_continuation_traced` beside `:3137`, sharing everything after the constructor),
  then `suspended: None`. `model_change` while suspended rewrites `c.model` in the held
  continuation. `restart`, `abort`, `exit` while suspended: return as today.

**Gate.** Part 1 unit tests green: the ordinal rule over the path table in
`REVIEW-adr003-v4-verdicts-fable.md` §3 minus its write-dependent rows; `c2_state_from_continuation`
resets and carries exactly ADR-003 D6's list. The live probe is Part 6's gate.

#### Part 6 — the host's `run_suspended` case, and the first judging number (1 day)

- `MotokoRunState` (`herdr-agent-state.ts:43`), `RunState` (`ui.ts:790`), `TranscriptState`
  (`session-logger.ts:5`) gain `suspended`. `mapRunState` (`herdr-agent-state.ts:81–91`) maps
  it to `{ state: "blocked", message: "suspended: step budget — send continue" }`; the
  exhaustive-list test at `herdr-agent-state.test.ts:49–55` gains the row.
- `ui.ts`: a `run_suspended` case beside `:2752–2761` that sets `runState` to `suspended`,
  prints the reason, sets `taskDone = true` and refocuses input, so `shouldLockPlainInput`
  (`:1790–1795`) admits the next line. `index.ts:918` does not set `errorOccurred` on
  `run_suspended`.
- `session-logger.ts:343–346`: a transcript line for `run_suspended`.
- `index.ts:877–882`: drain on `run_suspended` as on `done`/`error` in the non-TTY path.
- The plain and JSON loggers (`index.ts:517–519`, `:572–575`) are unchanged in P1: headless
  still receives `error` (Part 4).

**Gate.** `bun run test` and `tsc` green in `src/tui`. **The live probe** (Part 1 item 3)
green: the resumed run's first `provider_call_prepared.msg_count` equals the exhausted
history plus one, and the two `run_summary.steps_executed` values are 5 and the resumed run's
own count. A manual TTY check that the TUI accepts `continue` after a budget run without a
restart. The herdr measurement — `agent get` on the pane during suspension shows `blocked`
with the message — is taken **inside a herdr pane** and skipped elsewhere
(`initHerdrReporter` returns early outside one, `herdr-agent-state.ts:278–280`); the
exhaustive-list test is the compile-time half and runs everywhere. One measured line in §5.

**Done when.** The first judging number is green in the live probe; the issue file
`step-budget-exhaustion-starts-a-fresh-session.md` gets a "repaired in memory at `<hash>`;
on the journal at P3" status line.

**Do not:** write any file in P1; touch `world_of_json`; add any journal-class event or
`session_resumed` to the vocabulary before P3; change any DST match site of
`TracedSessionResult`; change the signature of any exported traced entry (§0.7); add a
`Ports` field (§0.8).

---

### P2 — deleted

v2.1's P2 built ADR-003 v4.1's writer: `fs_atomic.ail`, the `file_replace` port and its
`FileReplace` class, the writer at the P2 seam, the outer-backstop skip, the child-written
`Restart` update, `world_of_json_strict`, and the `snapshot_resume_dst.ail` gate with its
`+2` assertion. ADR-003 v5 retracted all of it (retractions 2–4). Nothing in this plan waits
for PLAN-001 P2 any more except one field (§Phases).

---

### P3 — D8 step 3: the journal, the fold, the writer, the resume (9–12 days)

**Dependencies.** P1. Nothing from PLAN-001 P2 (one field waits for its `ordinal`). Parts are
ordered so the invariant exists before the emits that satisfy it — and so it can compile: a
family that names `HistorySeeded` cannot exist before the variant does, so the variants come
first **without emits**, the family second and red, the emits third and green.

#### Part 1 — the vocabulary: variants, rows, goldens, no emits (½ day, core)

One commit (§0.3): `HistorySeeded`, `HistoryAppended`, `HistoryReplaced`, `StateDelta`,
`SessionResumed` join `LedgerEvent` (`phase_vocab.ail`) with their payload types; `RunSummary`
gains `cumulative` and `SessionStart` gains `run_id`; each variant gets its row in
`event_vocabulary()` (`dst_event_vocabulary.ail:241–246` pattern) and its golden
(`phase_vocab.ail:1221–1229`); the two moved goldens (`:593`, `:791`) are re-pinned. Nothing
emits them yet, so `parity_findings` (`dst_invariants.ail:946`) is untouched and every fixture
stays green. `make event_vocabulary` counts variants against rows against goldens
(`Makefile:1257–1262`) and is the gate.

**Gate.** `make event_vocabulary` green; `make dst` unchanged.

#### Part 2 — the fold and its family, red (2–3 days, core)

In `journal.ail`:

- The entry types of ADR-003 D1 (`header`, `history_appended`, `history_replaced`,
  `state_delta`, `run_started`, `run_finished`, `settings`, `suspended`, `resumed`, `exit`;
  `park` and `wake` wait for P4) with strict decoders returning `Result[_, Refusal]`,
  `Refusal = Header | Entry(seq, field) | Digest(seq) | HeadPrefix | Transcript(string) |
  Pairing(seq) | Workdir | ExtSet | Prompt | Leased | Schema`.
- **The chain's canonical form, settled** (Open question 8): a per-message frame
  `canonical_message_frame(m)` in `phase_vocab.ail`, exported, which is
  `canonical_messages_raw([m])`'s frame (`:237–243`: role, raw content, `tool_call_id`,
  `tool_calls`) **plus an `images` frame** — both existing canonical forms omit `images`
  (`:233`, `:241`), and a chain blind to an image change would accept a history that differs
  from what the provider saw. `digest_after = sha256(previous_digest ++ canonical_message_frame(m))`,
  the seed's `digest = digest_messages(messages)` (`:245–247`) as base. The fold and the child
  share the one function; `journal.ail`'s tests pin it.
- `fold_journal(entries, leaf) -> Result[SessionState, Refusal]`, ADR-003 D4's six rules: path
  by `parent_id` with a seen-set; strict decode per entry; history from the seed through the
  latest `history_replaced`, honouring `replaces_previous` and `first_kept`; the chain digest
  recomputed and checked at every history entry; `system_is_head_prefix`,
  `history_valid_transcript` (`phase_vocab.ail:40`, `:71–73`) and the fold's own **pairing
  check** — every tool result answers a call in the assistant before it, every call but a
  trailing one is answered (`history_valid_transcript` does not check pairing, `:106–112`);
  the trailing unpaired calls stripped and recorded as `dangling`; counts, telemetry and
  artifacts from the last `state_delta`; `model` and `profile` from the last `settings`; the
  boundary from the last entry's type.
- **The family.** `JournalFold` joins `InvariantFamily` (`dst_invariants.ail:205–216`),
  `all_families()` (`:273–277`), `family_id` (`:219`), `violation_family` (`:334`), with
  `journal_fold_findings(x: ExecutionUnderTest)` on the pattern of `checkpoint_findings`
  (`:1319`): take the journal-class `WireRecord`s from the trace, the `HistorySeeded` first,
  assign sequential ids and parents as the host would, fold, compare with `x.final` field by
  field; a mismatch is a `JournalFoldDisagrees(field)` violation. The id-assignment is one
  function, shared with Part 5's resume script.

**Gate, red.** The family compiles against Part 1's variants and P1's `final`, and is red on
**every** fixture in `make dst`, because a fold over no journal-class records yields an empty
history against a non-empty `final.history` (every terminal arm has at least the seed). That
red is the check that the family reads the trace at all. Fixtures in `journal.ail`'s tests,
green now: one per `Refusal` variant by mutating a good entry list; the hybrid replacement (a
plain assistant entry followed by a `replaces_previous` augmented one) folding to the augmented
message with the chain intact, and the same list with the flag cleared refused at that entry's
digest; a trailing unpaired call stripped and reported; a checkpoint entry with `first_kept:
None` folding to prefix, summary, then the later entries; an image-bearing message whose image
change breaks the chain.

#### Part 3 — the emits, green (2 days, core)

All in `session.ail`, one commit:

- **`HistorySeeded`** once per traced run, at the traced entry before `c2_loop`
  (`session.ail:3143`), with the run's starting history and its digest: `[system, task]` for a
  fresh session (`rpc.ail:344–345`), the loop's history for a follow-up turn, the folded
  history for a resumed run. Appended to the initial state's trace (the constructor starts it
  empty, `:728`) so it is the first journal-class record of every run.
- **`HistoryAppended`, one message per event**, at every site where `st.msgs` grows or its
  tail is replaced — the table is ADR-003 D2's, verified by its review:

  | site | what enters | events |
  |---|---|---|
  | `:2944`, `:2989`, `:3025`, `:3057` | the assistant message after a model call | one |
  | `:2356`, `:2381` (`c2_after_dp7`, called at `:3020`, `:3080`) | the assistant on the DP7 paths | one |
  | `:2907` | the intercept-handled assistant and its tool message | two |
  | `:2494` | the injected user message | one |
  | `:2251` | the tool-batch finish, `c2_pending_prefix(st) ++ tool_msgs` (`:2213–2215`) | one per result; on the hybrid path the first carries the augmented assistant (`:2998`) with `replaces_previous: true` |
  | `:3409` | the operator's message, emitted by the conversation loop | one |

  `:2298`, `:2675`, `:2849` carry `st.msgs` unchanged and emit nothing. Each event carries
  `digest_after`, the incremental chain digest of Part 2's `canonical_message_frame`, with the
  seed's digest as base; the loop threads the running digest in `C2LoopState` as one new
  field, `history_digest`, which **every full loop literal sets** — the fifteen in the loop
  (`:2250`, `:2297`, `:2355`, `:2380`, `:2493`, `:2520`, `:2568`, `:2602`, `:2674`, `:2848`,
  `:2906`, `:2943`, `:2988`, `:3024`, `:3056`), the constructor (`:709–730`), P1's
  `c2_state_from_continuation`, and the two test literals (`:3804`, `:3856`). The field is
  declared at `:383–429`, above all five anchors, so this commit moves them; it is the one P3
  re-baseline (§0.2). An append costs one message's frame.
- **`HistoryReplaced`** at the checkpoint (`:2521`), carrying the summary message `checkpoint`
  produced (`phase_vocab.ail:263–281`) and `first_kept: None` — `apply_checkpoint` keeps no
  tail at HEAD (`:349–366`). Its `digest_after` is the chain's new base.
- **`StateDelta`** at the end of every step (`:2911`, `:2947–2948`, `:2992–2993`) and at the
  checkpoint arm (`:2524–2525`), with `cumulative` (exactly `:559`), `telemetry`,
  `ext_artifacts_digest`, and `ext_artifacts` inline only when the digest changed.
- `RunSummary.cumulative` and `SessionStart.run_id` are now set at their emit sites.
  `world_ordinal` on `RunSummary` is added when PLAN-001 P2's `ordinal` exists, in P2's
  window.
- **Payload-equality** assertions for the journal-class events join `parity_findings`
  (`dst_invariants.ail:946`), which today compares presence, not payload.

**Gate, green.** `JournalFold` green on **every** fixture in `make dst` — the red of Part 2
turned by this commit and nothing else; `parity_findings` green with the payload assertions;
`make anchors` re-baselined once (§0.2); every other DST target green — the events are
additive and no consumer changes yet. **The digest chain checked in the wiring fixture**:
recompute the incremental chain over `suspended.history` with `canonical_message_frame`
from the seed's `digest_messages` base and confirm it equals the run's last `digest_after`.
(Comparing with `digest_messages(suspended.history)` would never pass: that is a whole-list
hash of a different canonical form, `phase_vocab.ail:229–233`, `:245–247`.)

#### Part 4 — the host's journal, identity and lease (2 days, host + core)

- **`SessionJournal`**, host-lifetime, created once per session beside `sessionStartMs()`
  (`session-identity.ts:37`): the file `.motoko/sessions/<session_id>/journal.jsonl` (`0700`),
  the leaf, the `seq` counter, the running message count for `first_kept` resolution. Each
  per-spawn `SessionLogger` (`index.ts:903`) is handed it; `log(event)`
  (`session-logger.ts:355–359`) routes journal-class events to it — `history_seeded` under
  ADR-003 D1's three arms (first run: N `history_appended` entries; after a `resumed` entry
  with a changed prompt digest: a `history_replaced`; otherwise: compare the seed's `digest`
  with the last history entry's `digest_after`, both child-computed, and drop) — and writes
  every event to the JSONL log **with journal-class payloads replaced by a digest**. That
  digest rule is new code (`parseAgentEventLine` accepts any typed object,
  `runtime-process.ts:105–117`; unknown types are logged verbatim,
  `runtime-process.unknown-events.test.ts:36`) and lands in **this commit with the routing**,
  or the JSONL doubles in content.
- **The header**, written before the first spawn from the values the host has
  (`buildSupervisorArgs`, `runtime-process.ts:482–505`) and completed on the first
  `session_start` with the child's prompt and extension-set digests — the one in-place
  rewrite, atomic via rename. A header never completed is refused by the fold.
- **The `exit` entry** from the exit handler (`index.ts:922–985`) and the process-exit hooks,
  with the reason and `pending_tool_calls` from a three-line TypeScript twin of the
  trailing-pair rule; the hook's append is **`fs.appendFileSync`** — an async write in an
  `exit` listener never runs (`herdr-agent-state.ts:346–351` is the precedent).
- **One session id.** `buildChildEnv` (`runtime-process.ts:337–389`) forwards
  `MOTOKO_SESSION_ID`, minted once per session; `SessionLogger` is constructed after it is set
  (`session-logger.ts:233–238`). Every wire event of a follow-up turn now carries the session's
  id (`session.ail:335–341`); the P1 probe shows one id across both runs.
- **`MOTOKO_RESUME_COUNT`** forwarded: `0` on a fresh spawn, incremented on every `--resume`
  spawn.
- **The lease** (`.motoko/sessions/<id>/lease`, `{ owner_pid, session_id, acquired_at_ms }`,
  atomic rename), held across respawns (`index.ts:901–907`), released in **its own**
  `exit`/`SIGINT`/`SIGTERM` listeners registered between `initExitActions()` and
  `initHerdrReporter()` (`index.ts:825–827`; `exit-actions.ts:422–428`) and not re-raising.
  **Test mechanism**: export `registerLeaseHooks(proc: { on(event, fn) }, lease)` and test it
  with a fake emitter that records registration order, asserts the `SIGINT` handler returns
  without calling `kill`, and asserts the `exit` handler performs no asynchronous work
  (`exit-actions.test.ts:43–115` has no such precedent, so the fake is new). The child never
  touches the lease.

**Gate.** `bun run test` and `tsc` green; the fake-emitter test green; a live run leaves a
journal whose entries the core's `fold_journal` accepts (a small AILANG script reads the file
and prints the folded history length and counts); the JSONL for the same run carries digests
where the journal carries messages; the P1 probe shows one `session_id`. Manual, priced (§7):
two TUIs on one session, the second refused with `Leased`; kill -9 the first, the second
resumes with `--resume-force`.

#### Part 5 — `--resume` (2 days, core + host)

- `InvocationConfig` gains `resume: string` (the journal path) and `resume_force: bool`
  (`config.ail:133–138`); `apply_flag_value` takes `--resume <path>` (`:222–230`); a bare-flag
  arm for `--resume-force` beside `--no-backend` (`:235`; the `flag :: value` arm would eat
  the task, `:236–239`); `buildSupervisorArgs` emits both.
- `run_with_config` resume order, ADR-003 D6: lease (host) → the child reads the journal with
  the ambient `readFile` (`rpc.ail:266–267`; §0.8) and folds from the leaf; refuse on
  `Refusal` → build the runtime for the invoked profile (`rpc.ail:241–247`), compute
  `ext_set_digest` from the registry (not `:260`'s names), apply the compatibility rows →
  `compute_budget_plan` and `dispatch_build_system_prompt` from `header.boot.task` (`:319`,
  `:342`); compare `system_prefix_digest_for([system_msg])` (`phase_vocab.ail:253–255`) with
  the header's; same profile and different: refuse unless forced; different profile: replace
  the whole head prefix (`take_system_prefix`, `:85–90`) with the one new message and reset
  `ext_artifacts`; `run_model` is `--model` else the folded model → emit `SessionResumed` →
  enter the loop: `last = Suspended` → `suspended: Some(continuation from the fold)`; `last =
  RunFinished | Exit` → between turns with the folded history; wait for input
  (`session.ail:3597–3598`). `await_first_task` is bypassed.
- `SessionResumed({ resume_count, from_id, from_ordinal, profile_from, profile_to,
  prompt_digest_from, prompt_digest_to, forced })` joins `LedgerEvent`, the vocabulary, the
  goldens and `AgentEvent`; appended as the first record of the resumed frame; `from_ordinal`
  is the last `run_finished.world_ordinal`, the previous frame's `final` itself
  (`session.ail:1550–1554`), so the resumed frame opens exactly there.
- The resumed run's `HistorySeeded` carries the folded history; after a profile switch the
  host journals it as a `history_replaced` (Part 4's second arm).
- The TUI's restart respawn passes `--resume <journal>` instead of an empty task
  (`index.ts:951`); `--profile` already flows (`:931–934`). The resumed TUI prints the folded
  history with a marker line (resume count, the last boundary's reason, both profiles on a
  switch, any dangling calls stripped).

**Gate.** A DST script (new, `scripts/dst/journal_resume_dst.ail`, with its Make target and
`DST_TARGETS` row, `Makefile:436–441`) that runs a traced entry to a 3-step budget, builds a
journal from its trace with the family's shared id-assignment (Part 2), folds it, resumes through
`c2_state_from_continuation` in a second traced run, and asserts the second run's
`HistorySeeded.digest` equals the first run's last `digest_after` and, once PLAN-001 P2 has
landed, `BEGIN₂.ordinal₀ == END₁.final`. A same-profile resume against an edited prompt refused
then forced. Manual, priced (§7): one resume across a TUI respawn with history on screen; one
`restart` into a second profile with history intact, `ext_artifacts` empty and
`SessionResumed` naming both profiles; **one kill -9 of the child mid tool-phase followed by a
resume that shows the dangling call stripped and the step count carried** — the second judging
number.

#### Part 6 — the rest of the wire (½ day, host)

- Remove the headless-only `error` from P1 Part 4; the plain and JSON loggers exit non-zero on
  `run_suspended` with the reason on stderr (`index.ts:517–519`, `:572–575`).
- **First item of this part:** check the eval-harness adapter for a dependency on the wire
  `error` event. Inside this tree, `env-server.ts` reads `run_summary` and has no wire
  `error` consumer (the only `"error"` matches are a comment at `:420` and a child-process
  listener at `:1109`); the external AILANG adapter is **unverified** and the finding is
  recorded in §5 either way before the removal lands.

**Done when.** The issue file is closed with the P3 hash; ADR-003's Consequences "unverified"
line is replaced by the §5 finding; both judging numbers are green.

**Do not:** let a profile mismatch refuse; let the child write anything; compute
`ext_set_digest` from the `session_start` event; re-raise from the lease's signal handler;
land the events without the digest rule; put the host's digest computation anywhere (it
compares child-computed digests only).

---

### P4 — D7: durable park as entries (unscheduled)

Gates before it can be scheduled, all external to this plan: ADR-002 D2 activated (the
`ParkRequest`, `wake_read`, the host protocol, the `wakes` cursor, `ParkEntered` and
`WakeReceived` appended and emitted) under ADR-002's step 4; ADR-001's between-turn frame
(ADR-002 D4) exists. When both hold, P4 is: the `park` and `wake` entry types and their
decoders; the `suspended-child` branch in the exit handler before `restartPending`; the host
writing the `wake` entry as a child of the `park` entry on the answer; the resumer seeding the
`wakes` cursor from it with the `request_id` rewritten to the re-issued request; the live
`wake_read` that reads the cursor first (the one named exception to `live_ports`' ambient
overrides, `ports.ail:2568–2570`) and the recording binding that records the served wake
(`:1718–1747` pattern); the named states with `Lost`/`Aborted` exits. No wake file, no
generation check: a consumed wake is followed by a `run_started` and the fold offers it once.
`--park-exits` stays off until one live parked session has resumed through the cursor.

---

## Non-goals

- **Journal pruning**, **branching features** (rewind to a checkpoint with a summary entry,
  sibling branches for retried turns, `/fork`), **cost and context exhaustion as suspensions**,
  **hostless durability**, **`--resume` of a headless one-shot**, **artifacts inline versus by
  digest** — all ADR-003 v6.1 "Not decided". The format is branch-ready; nothing here branches.
- **ADR-002's outstanding v2.1 corrections** (D2 precedence, D3 descriptor sum, D5 safe default,
  the call arithmetic). ADR-002 v4 first; PLAN-002 after it. **What PLAN-002 consumes from
  here is `RunIdentity` from P1 Part 5** (ADR-002 D2's request id is `run_id` plus a park
  ordinal) and the `park`/`wake` entries from P4, nothing else.
- **World-threading the conversation loop** (ADR-002 D4's debt). P1 gives the loop
  `run_ordinal`, not a world.
- **Abort mid-provider-call** semantics beyond today's.
- **The extension token's total codec.** `world_of_json` is never touched; the journal carries
  no `WorldState`.
- **A child-written journal**, oh-my-pi's shape. Rejected by ADR-003 O4 for the witnessed-path
  write; §0.8 is the rule.

---

## Open questions

1. **State of `make dst` at HEAD — resolved, see §5.** Four reds: two are the anchors (deferred
   to P1 Part 4 by §0.2), one re-pinned and green, one — the depth canary — the owner's call.
2. **Whether PLAN-001 P2 has started.** No `ordinal` on `WorldState` at `97827bf`
   (`ports.ail:183–196`). Only `run_finished.world_ordinal` and the resume script's ordinal
   assertion wait for it; nothing else in this plan does.
3. **The seed's size on the wire.** Every traced run's `HistorySeeded` carries its whole
   starting history on stdout, and for a follow-up turn that is the whole conversation, which
   the host then drops after a digest check. That is the same order of bytes the provider call
   itself sends each step, so it is bounded by what the session already costs, but it is
   stdout traffic the pipe did not carry before. If it matters, the host can tell the child
   through the environment whether it needs the messages (first run) or the digest alone; the
   trace must always carry the messages for the invariant. Decide at P3 Part 3; default is
   "always carry", and §5 records one measurement of bytes per turn from the probe.
4. **Where `BudgetPlan` and `CostRates` are declared — resolved.** `BudgetPlan` is the ABI's
   (`packages/motoko-ext-abi/types.ail:61`), `CostRates` is `config.ail:30`; both are leaves
   `journal.ail` can import without a cycle.
5. **The live probe's shape — resolved.** The non-TTY TUI cannot deliver `continue` (§0.6);
   the probe drives `rpc.main` directly and reads stdout (P1 Part 1 item 3).
6. **`c2_finalize` — resolved.** A `final` parameter at all seven callers (P1 Part 4; ADR-003
   v6.1).
7. **The external eval-harness adapter** (P3 Part 6). Answered before the `error` removal
   lands; if it keys on `error`, the headless-only emission stays and ADR-003's Consequences
   gains a line.
8. **The canonical form for the incremental digest — resolved.** A per-message
   `canonical_message_frame(m)`: `canonical_messages_raw`'s frame (`phase_vocab.ail:237–243`)
   plus an `images` frame, since both existing forms omit images (`:233`, `:241`). The chain is
   `sha256(previous ++ frame)` from the seed's `digest_messages` base; the fold and the child
   share the one exported function, pinned by `journal.ail`'s tests (P3 Part 2).
9. **The canary under `DST_KNOWN_RED` — resolved 2026-09-07.** Listed on the owner's
   instruction, with the bisection and the pending re-measure as the Makefile comment
   (`Makefile:493`, the entry above `DST_KNOWN_RED := depth_canary`). The sweep still exits 2
   while it is red — the list is disclosure, not a waiver (PLAN-001 §1) — and the summary
   prints a NOTE the day it passes, which is the signal to drop it. Sweep gates in this plan
   read "green, with `depth_canary` reported as known red".

---

## 5. Results

Filled in as parts land: the sweep and its dispositions (below); anchor re-baseline commits
and the single profile re-issue at P1 Part 4 and the one at P3 Part 1; the herdr `blocked`
message measurement (P1 Part 6); the first judging number's live reading before and after P1,
in the wire form Part 1 item 3 names; the `JournalFold` family's red sweep (P3 Part 2) and first
green sweep (P3 Part 3); bytes of `history_seeded` per turn in the probe (Open question 3);
the crash-resume reading (P3 Part 5); the eval-harness finding (P3 Part 6).

Measured for v2 at `97827bf`: `make anchors` exits 1 with eight `✗` lines; `session.ail:1529`
reads `func c2_finalize(`, `:3126` reads `ohmy_pi: bool,`, `tool_phase.ail:413` reads a
comment.

### The sweep at `97827bf` (§0.1), run 2026-09-06 18:42–18:59 UTC

`make dst DST_JOBS=1`: **1007 s wall, exit 2, four reds**, zero listed-and-passing
(`DST_KNOWN_RED` is empty, `Makefile:493`). Log at `.ailang/dst-last.log`. Run with the
working tree's uncommitted `ailang.lock` (three extension content hashes regenerated on
2026-09-06; shown irrelevant below). PLAN-001's sweep at `3fe71b0` had one red; three of
these four are new since then.

| Red target | Cause, verified | Disposition |
|---|---|---|
| `anchors` | The eight stale pins §0.1 already records. | **Known red, deferred**: lands once with P1 Part 4 (§0.2, the one-re-issue path). |
| `attribution_table` | Not a second failure: its recipe runs `make anchors` after the table script (`Makefile:2776`), and the table script and its module test both passed. | Same as `anchors`; goes green with it. |
| `ext_ambient_inventory_selftest` | `FAIL YIELD: expected 17 registrable extensions … got 18`. The stale pin PLAN-001 §1 recorded at `3fe71b0` and recommended re-pinning: `tools/ext_ambient_inventory/fixtures/expected.json:84` still says `17` and its `package_dirs` still lacks `repetition_guard`, while the sibling `fixtures/hook_scope/expected.json:197` already says `18`. Never re-pinned. | **Re-pinned and green** (2026-09-06, uncommitted): `extensions: 18`, `repetition_guard` added to `package_dirs`, and a dated note in the fixture's prose; `make ext_ambient_inventory_selftest` alone reports `resolution asserted 18 package directories, member by member`, `yield 4 of 18`, `0 failure(s)`. Not a behaviour change. |
| `depth_canary` | Tier 1, seed 23 only: `exceeded depth 90 (was 96 records …)`; seeds 7 and 11 and tier 0 pass. **Bisected in throwaway worktrees**: green at `562f821` and at `650f0e0` (the "prose is prose" commit, whose `session_emitted_native_tool_call` walks the history but is gated on `hybrid_tools`, `session.ail:2973`, and did not move the pin); **red at `8980ba6`**, its direct child, PLAN-001 live-run fix 1; red again in the working tree, so the lockfile is not the cause. Fix 1 added no traversal of accumulated state: it added `arguments_undecodable`, a `decode` of each tool call's raw arguments before dispatch (`tool_phase.ail`, in `execute_allowed_tool_call`'s path), plus a `ToolArgumentsUndecodable` event. That is the canary header's **second** case, "a change in c2_loop's per-step frame cost", not its first: the extra frames sit on the tool-phase path at the deepest step, and seed 23's margin (floor 75, ceiling 90) was the tightest of the three. | **Owner's call, per the canary's own rule** (`run_depth_canary.sh:53–58`): re-measure seed 23's floor by the header's tolerance-1 bisection with fix 1 in place, then bump the pin with the reason recorded — or move the decode out of the per-step frame. Not bumped here. Until decided, list under `DST_KNOWN_RED` with `# PLAN-003 §5: fix 1's per-call argument decode raised seed 23's frame cost; re-measure pending`. |

Every other target passed. The ambient-inventory re-pin was applied on the owner's
instruction and is green. The canary pin was not touched; on 2026-09-07 the owner had
`depth_canary` listed under `DST_KNOWN_RED` (`Makefile:493`) with the bisection above as its
reason, pending the re-measure; the summary script's reverse check reports it the day it
passes (Open question 9).

---

## 6. What changed, by version

**v1 → v2 → v2.1** (checkpoint design, ADR-003 v4.1): recorded in
`REVIEW-plan003-verdicts-fable.md` and `REVIEW-plan003-v2-verdicts-fable.md`; the P1 fixture
on continuing tool-call steps, the type move, the probe on `rpc.main`, the anchor count and the
one-re-issue path, the frozen exported signatures, the profile directory for the probe, the
`msg_count` and `steps_executed` conditions. All still stand.

**v2.1 → v3** (journal design, ADR-003 v6.1):

- **P1, four parts changed by deletion.** Part 1 asserts `suspended.history` directly and no
  `written`; Part 3's module is `journal.ail` with `Continuation`, `RunIdentity`,
  `FinalState` and the `[Message]` codec, and no `Snapshot`, no `Refusal`, no world decoding;
  Part 4 adds `suspended` and `final` — `final` as a `c2_finalize` parameter at seven
  callers, carried by `execution_of` into `ExecutionUnderTest` — and `RunSuspended` carries
  no `generation` or `published`; Part 5's rule is `run_ordinal + 1` per traced run with
  `resume_count` from the environment, and `generation` is gone. Parts 2 and 6 unchanged.
- **P2 deleted.**
- **P3 reshaped** into five parts: the events (with the corrected site table,
  `replaces_previous`, the incremental digest, `first_kept: None`, `cumulative` in
  `StateDelta`), the fold and the `JournalFold` family written red first, the host's
  `SessionJournal` with the three-arm seed rule and the digest rule in one commit plus
  identity and lease, `--resume` with the `journal_resume_dst.ail` gate and the crash-resume
  live gate, the rest of the wire.
- **§0.8** added: no child file IO, `Ports` and `derive.py` untouched, the resume read ambient.
- **A second judging number**: a run that dies at step N resumes with N steps.
- Non-goals and open questions rewritten for the journal; §5 unchanged.

**v3 → v3.1**, from `REVIEW-plan003-v3-verdicts-fable.md`: P3 reordered into vocabulary
(variants, rows, goldens, no emits) → fold and family (red) → emits (green), since a family
that names a variant cannot compile before it exists, and Parts 4–6 renumbered; the wiring
fixture's digest-chain gate recomputes the incremental chain rather than comparing with the
whole-list `digest_messages`, whose canonical form differs; Open question 8 settled on a
per-message frame that includes `images`; `MOTOKO_RESUME_COUNT` read ambiently in
`rpc.run_with_config`, not through the port, because every `ports.env_get` is a helped
`EnvRead` pinned by five fixtures (§0.8); the four `phase_vocab` helpers `journal.ail` needs
are private at HEAD and are exported in P1 Part 3, with `History` reached through
`history_from_seed`; the `history_digest` field's eighteen literal sites named; the canary's
`DST_KNOWN_RED` question carried as Open question 9.

---

## 7. Estimates

| phase | v2.1 | v3 | why |
|---|---|---|---|
| P1 | 7–10 | 6–9 | no `written`, no snapshot codec, no refusal fixtures, no world decoding; the anchor disposition (1), fixture rework, type move and probe profile unchanged |
| P2 | 3–4 | 0 | deleted |
| P3 | 5–7 | 9–12 | five new events at nine sites with the digest thread (2–3); the fold, its refusals and the family (2–3); the host journal, digest rule, header, exit entry, ids and lease (2); `--resume`, its DST gate and three manual live gates including the crash resume (2); the wire (½); one anchor re-baseline (½) |
| total | 15–21 | 15–21 | the same envelope; the work moved from a child-side writer and a strict world decoder to events, a fold and an invariant that runs on every fixture |

---

## Cross-references

- The ADR: `ADR-003-session-journal-and-resume.md` v6.1, with its six reviews; v6.1's D8 is
  this plan's phase order.
- This plan's reviews: `REVIEW-plan003-verdicts-fable.md` (v1) and
  `REVIEW-plan003-v2-verdicts-fable.md` (v2), whose gate audits P1 still relies on;
  `REVIEW-plan003-v3-verdicts-fable.md` (v3; §2 the part order, §3 the digest gate, §4 the
  literal count, §8 "P1 can start").
- The precedent: oh-my-pi 18.1.11, `@oh-my-pi/pi-coding-agent/src/session/` — cited in the
  ADR; this plan builds the host-written variant of its format.
- The predecessor: `ADR-002-park-and-wake.md` v3, D6 ("Durable park: ADR-003 D7") and D2's
  request id.
- The sequencing precedent: `PLAN-001-implement-adr-001.md` §1 (the sweep); its P2 Part 1 is
  what `run_finished.world_ordinal` waits for.
- The issues: `.agent/issues/step-budget-exhaustion-starts-a-fresh-session.md` (repaired by P1
  in memory, P3 on the journal); `.agent/issues/max-steps-termination-discriminated-by-error-message-string.md`
  (closed by P1 Part 2).
- Code at `97827bf`: `session.ail:175–180`, `:335–341`, `:383–429`, `:431–446`, `:483–497`,
  `:541–560`, `:709–730`, `:728`, `:1529`, `:1535`, `:1550–1554`, `:2044–2053`, `:2155–2169`,
  `:2205–2206`, `:2213–2215`, `:2251`, `:2298`, `:2356`, `:2381`, `:2407–2437`, `:2429`,
  `:2482`, `:2486`, `:2494`, `:2517–2525`, `:2551`, `:2658`, `:2675`, `:2758`, `:2765`,
  `:2768`, `:2773–2775`, `:2849`, `:2873`, `:2907`, `:2911`, `:2944`, `:2947–2948`,
  `:2981–2998`, `:2992–2993`, `:3020`, `:3025`, `:3057`, `:3080`, `:3137–3148`, `:3170`,
  `:3330–3346`, `:3352–3357`, `:3359–3366`, `:3367`, `:3374–3390`, `:3391–3399`,
  `:3402–3409`, `:3416`, `:3418–3427`, `:3561`, `:3597–3612`, `:3619`, `:3697`, `:3705–3712`,
  `:2041–2044`, `:2568`, `:2602`, `:3804`, `:3856`; `step_machine.ail:93–103`, `:128–129`;
  `tool_phase.ail:452–453`; `phase_vocab.ail:17–19`, `:26–31`, `:40`, `:71–73`, `:75`, `:85–90`,
  `:106–112`, `:229–247`, `:253–255`, `:263–281`, `:349–366`, `:593`, `:791`, `:1221–1229`;
  `src/core/test/stub_step.ail:771–781`; `scripts/dst/seeded_generator_dst.ail:415–421`;
  `scripts/dst/run_report_dst.ail:173–178`;
  `scripts/dst/terminal_trace_dst.ail:77–80`, `:127–134`;
  `scripts/dst/phase_c2_wiring_scenarios.ail:33`, `:66–68`, `:120–122`;
  `scripts/dst/invariants_dst.ail:385`, `:1008`; `ports.ail:183–196`, `:1718–1747`,
  `:2568–2570`; `dst_fault_catalogue.ail:50–59`, `:210`, `:825–829`;
  `dst_invariants.ail:205–216`, `:219`, `:273–277`, `:334`, `:553–556`, `:788–796`, `:946`,
  `:1131`, `:1319`, `:1385–1388`; `dst_execution.ail:110–118`; `config.ail:30`, `:133–138`,
  `:186–187`, `:222–239`, `:313`; `rpc.ail:88–94`, `:116–118`, `:189–192`, `:241–247`, `:257`,
  `:260`, `:266–267`, `:277–296`, `:319`, `:342–345`, `:351`, `:355–359`;
  `tools/driver_leaf_inventory/derive.py:94–105`, `:95`, `:142`, `:144–155`;
  `tools/predicate-anchors/anchors.sh:22`, `:379–387`; `Makefile:342–345`, `:436–441`,
  `:1221`, `:1257–1262`, `:1283`; `dst_event_vocabulary.ail:241–246`; `packages/motoko-ext-abi/types.ail:61`, `:547`;
  `runtime-process.ts:58–103`, `:96`, `:105–117`, `:337–389`, `:355–357`, `:482–505`;
  `runtime-process.unknown-events.test.ts:36`; `session-logger.ts:5`, `:233–238`,
  `:343–346`, `:355–359`; `session-identity.ts:37`; `herdr-agent-state.ts:43`, `:81–91`,
  `:278–280`, `:296–301`, `:346–351`; `herdr-agent-state.test.ts:49–55`;
  `exit-actions.ts:422–428`; `exit-actions.test.ts:43–115`; `env-server.ts:420`, `:1109`;
  `ui.ts:790`, `:1790–1795`, `:2752–2761`; `index.ts:415`, `:517–519`, `:572–575`,
  `:825–827`, `:877–882`, `:901–907`, `:903`, `:918`, `:922–985`, `:931–934`, `:951`,
  `:1063`; `src/tui/package.json:9`.
