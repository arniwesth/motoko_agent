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
| P4 | step 4 | durable park as entries (D7): park/wake entries, cursor-first live wake_read, resumer, suspended-child host state | 8–12 days, core + host; gated on P4-Q1; planned v1 reviewed R1–R8 |

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
- **As landed (2026-09-12):** QEVAL found the harness DOES key on `error`
  (`benchmarks/motoko_rpc.py:213–216`), so by this part's own rule (Open question 7) **the
  removal did not land**: the headless `error` stays as a compatibility surface, the loggers
  exit non-zero on `run_suspended` beside it, and both render `session_resume_view` /
  `session_resume_refused`. §5 has the finding and the live readings.

**Done when.** The issue file is closed with the P3 hash; ADR-003's Consequences "unverified"
line is replaced by the §5 finding; both judging numbers are green.

**Do not:** let a profile mismatch refuse; let the child write anything; compute
`ext_set_digest` from the `session_start` event; re-raise from the lease's signal handler;
land the events without the digest rule; put the host's digest computation anywhere (it
compares child-computed digests only).

---

### P4 — D7: durable park as entries (planned, first draft; 8–12 days, core + host)

**Status.** v1 reviewed (REVIEW-plan003-p4-v1-verdicts-motoko.md, ACCEPT WITH CORRECTIONS), R1–R8 applied 2026-09-14. Written by the P4 planning pass (`P4·a1`,
`.dagr/run-plan003.json`). Grounded at HEAD `d5edebf` on `arniwesth/013-plan003-and-herdr`.
Every code coordinate in this section was read at `d5edebf` (`git show d5edebf:<path>`).
This section **replaces** v3.1's twelve-line sketch, which is quoted verbatim at the end of
the Background as the scope it was planned against. The governing decision is ADR-003 v6.1
D7, plus D1, D4 rule 6, D5 and D6 step 5 where D7 leans on them.

The park mechanics are PLAN-002 v3's, **transcribed, not re-decided**: W4 Parts 1–7, W5(b),
§6, and the owner decisions §8.3–8.4. Where ADR text is stale against HEAD, the row says **ADR
text residual, plan pins HEAD behavior**. Where the texts leave a choice open, it is an owner
question (P4-Q*n*), not a decision.

#### Background: the two gates, and the tier they were met at

The sketch named two gates, both external to this plan. Both hold **on code** at HEAD:

| gate | landed | what P4 consumes, at HEAD | verified at |
|---|---|---|---|
| ADR-002 D2 activated (PLAN-002 W4) | `85ce0c7` | the `Park` arm `session.ail:3527–3564`; `ParkRequest { request_id, step, waits, attempt }` `ports.ail:779`; `park_request_id` `session.ail:3091–3093`; `wake_matches` `:3121–3129`; `apply_wake` `:3149–3159`; `wake_message` `:3168–3179`; `ParkEntered`/`WakeReceived` `phase_vocab.ail:1320–1321` (payloads `:1015`, `:1020`; wire `:1503–1504`); the `wakes` cursor `ports.ail:211–221`, of `WakeObservation` `:792`; `scripted_wake` `:1157–1163`; `recording_wake` `:1174–1199`; the live wake `stub_step.ail:214–222` and `live_wake_await` `:294–319`; the host protocol `runtime-process.ts:137–142`, `:737–746`, `:985–1040`; the waiter factory `wake-waiter.ts:108`, `:479` | **T2**: `park_wake` (17 fixtures, `park_wake_dst.ail:725–752`), metric `== 4` on each channel. **T4 not recorded** (below) |
| ADR-001's between-turn frame, the D4 subset (PLAN-002 W5) | `8004874` | `initial_park_ordinal` `session.ail:602–604`; `between_turn_request_id` `:4723–4725`; `next_turn_world` `:4736–4738`; `loop_run_identity` `:4683–4689` | **T4**: the three-turn probe, 6/6; captures tracked at `.agent/projects/013_core_architecture_for_dst/evidence/plan002-w5-probe/` (repo-root path, added by `8004874`): `w5-tree/judge.log` ends "probe: 6/6 assertions green"; `redfirst-85ce0c7/judge.log` is the 4/6 red-first control |

**The sweep.** The confirmation sweep for `d5edebf` is `.ailang/post-pindh-sweep.out`: 748 s,
exit 2, `FAILED (1)`, and the failure is `depth_canary`. Its `NOTE` lines report
`driver_plus_herdr` and `herdr_graded` PASSED while still listed. So the board is green except
`depth_canary`.

**Two discrepancies, reported, not repaired.** Neither is P4's to fix.
1. **W4's live gates are open.** The brief for this pass said the 4-call metric was measured
   live. The record says otherwise:
   - `85ce0c7`'s gate 8: "full LIVE herdr delegation NOT run in this attempt — precondition for
     W5 recorded open". Its gate 7 is the fixture metric only.
   - The W4 node of `.dagr/run-plan002.json`: "OPEN for W5: live measurement + live parked run".
   - PLAN-002 §7 has no W4 entry.

   So W4 gates 7 and 8 are met at T2, not T4. See P4-Q1.
2. **`Makefile:672` still reads `DST_KNOWN_RED := depth_canary driver_plus_herdr herdr_graded`.**
   `d5edebf` ("Drop driver_plus_herdr + herdr_graded from DST_KNOWN_RED") rewrote the comment
   above the assignment (`:653–671`) but not the assignment itself. This is PINDH's, owned by
   the operator, and P4 does not touch it. Sweep gates below read "green, with `depth_canary`
   reported as known red", which this does not affect.

**The sketch this section replaces** (v3.1, verbatim):

> Gates before it can be scheduled, all external to this plan: ADR-002 D2 activated (the
> `ParkRequest`, `wake_read`, the host protocol, the `wakes` cursor, `ParkEntered` and
> `WakeReceived` appended and emitted) under ADR-002's step 4; ADR-001's between-turn frame
> (ADR-002 D4) exists. When both hold, P4 is: the `park` and `wake` entry types and their
> decoders; the `suspended-child` branch in the exit handler before `restartPending`; the host
> writing the `wake` entry as a child of the `park` entry on the answer; the resumer seeding the
> `wakes` cursor from it with the `request_id` rewritten to the re-issued request; the live
> `wake_read` that reads the cursor first (the one named exception to `live_ports`' ambient
> overrides, `ports.ail:2568–2570`) and the recording binding that records the served wake
> (`:1718–1747` pattern); the named states with `Lost`/`Aborted` exits. No wake file, no
> generation check: a consumed wake is followed by a `run_started` and the fold offers it once.
> `--park-exits` stays off until one live parked session has resumed through the cursor.

#### Coordinate drift from the sketch (`97827bf` → `d5edebf`)

| sketch cites (`97827bf`) | HEAD `d5edebf` |
|---|---|
| `ports.ail:2568–2570`: "the one named exception to `live_ports`' ambient overrides", which is the WI-D24 comment | The comment is now `ports.ail:2830–2832`, inside `ports_shape_probe` (`:2809–2835`), which binds `wake_read: scripted_wake` (`:2820`). **`live_ports` has left `ports.ail`.** It is `src/core/test/stub_step.ail:186–262`, and the binding P4 changes is its `wake_read` (`:214–222`). The rule P4 makes the exception to is stated at the live approval: "a live run's approvals are not a replayable cursor" (`:205–208`). |
| `ports.ail:1718–1747`: `recording_approval`, the pattern to copy | `recording_approval` is at `:1974` (confirm at run time). Its wake twin **already exists**: `recording_wake` (`:1174–1199`), from W4 Part 4. |
| "the exit handler before `restartPending`"; §0 cites `index.ts:922–985` | The TTY child-exit callback is `index.ts:1132–1185`: `pendingRestart` read at `:1138`, one-shot branch `:1142–1153`, `writeExit` `:1160`, respawn `:1161–1185`. The non-TTY child-exit callback is `:1048–1060`, with `writeExit("child_exit")` at `:1052`. The `restartPending` getter is `runtime-process.ts:1067–1069`. |

#### ADR text vs HEAD: what P4 pins

| # | ADR says | HEAD / plan pins |
|---|---|---|
| 1 | D7: the resumer rewrites the wake's `request_id` "to the re-issued request (`run_id + park ordinal 0`)" (`ADR-003:546–547`) | **Agreement, stated.** PLAN-002 §8.4 (decided) gives the request that opens a run's waiting the id `<run_id>.p0`, and starts every run opened by a consumed wake at `initial_park_ordinal(true) == 1` (`session.ail:602–604`). It names P4's resumer as a site the rule was written for (W4 Part 2 R9; W5(b); the comment at `session.ail:4713–4722`). The two texts say one thing: **`.p0` is the re-issued request that the consumed wake answers, and the resumed run's own parks begin at `.p1`**. The resumer's `run_id` is the identity `run_v2_resume_with_conversation` already builds, `loop_run_identity(session_id, profile, resume_count, 0)` (`session.ail:5318–5319`). So the rewritten id is exactly `between_turn_request_id(session_id, profile, resume_count, 0)` (`:4723–4725`), and W5's test pins the pairing (`:5867–5893`). **Residual**: D7's "the first `decide` parks and `wake_read` serves it" puts the consumption *inside* the resumed run. §8.4/R9 put it *before* the run ("a site that opens a run from a consumed between-turn wake applies … before the run's first decision"). The ids agree either way. The call-site count, the journal order and the `Aborted` path do not. Part 3 is drafted to §8.4; the choice is P4-Q2. |
| 2 | D7: the `park` entry carries "`open_waits` and the `ParkRequest`" | **ADR text residual, plan pins HEAD behavior.** `Park` carries only the waits (PLAN-002 §1 row 3), so those waits are the request's. `ParkEntered` is emitted only when `park_attempt == 0` (`session.ail:3530`), so its `attempt` is always 0. The entry payload is therefore `ParkEnteredInfo` as it stands: `{ request_id, step, waits }` (`phase_vocab.ail:1015`). No payload change and no golden move (`:1962–1963`). |
| 3 | D7: "the live and recording `wake_read` bindings are v4.1's" | **Residual: half landed.** The recording binding already serves the cursor: `recording_wake` wraps `scripted_wake`, which serves the head of `wakes` (`ports.ail:1157–1163`, `:1181–1199`). P4 adds only the live cursor-first read (Part 2) and an *assertion* on the recording binding. |
| 4 | D7: "The states, their `Lost`/`Aborted` exits … are v4.1's" | **Residual: v4.1's D7 is not in the tree.** ADR-003 enters git at v6.1 (`bbe28dd`); `git log -S'suspended-child'` finds only `bbe28dd` and `3ee3d03`. What survives of v4.1 D7 is in its reviews. `REVIEW-adr003-verdicts-fable.md` §8 (`:220–228`): test the branch before `restartPending`, because a restart during a park is a cancel; quitting the TUI during a durable park runs the exit actions and kills the delegates, so the resume then wakes `Lost`; "name the states". `REVIEW-adr003-v3-verdicts-fable.md:94–96`: `Aborted` on `restart` while suspended cancels the request and leaves the session resumable. Part 6 names the states from those sources and from W4 Part 5's command table. See P4-Q5. |
| 5 | D4 rule 6: "the last entry's type decides how the loop re-enters"; D7: `last = Parked(request, wake?)` | **Residual: the two ADRs disagree.** ADR-002 D4 (`ADR-002:499–500`) says "the host writes the `exit` entry; a park entry with no wake child is then re-observed on resume". So a path `park → exit` must fold to `Parked(req, None)`, not to `Exit`. Part 1 pins ADR-002 D4's reading. An `exit` after a park keeps `Parked`. Only `run_started`, a history entry, `state_delta`, `run_finished` or `suspended` ends it. See P4-Q4. |
| 6 | D7: the host writes the `wake` entry "as a child of the `park` entry" | **Pinned, with no branch operation.** D1's `parent_id` is the leaf, and the leaf is the last entry, since no operation moves it. So the `wake` is a child of the `park` only if nothing is appended between them. Therefore the suspended-child branch (Part 4) writes **no** `exit` entry. A host that dies during suspended-child writes its `exit` through the lease hook (`session-lease.ts:236`, `:240`), and the park is re-observed on resume (row 5). Part 5's test asserts `wake.parent_id == park.id`. |
| 7 | D7: "No wake file, no `WakeGeneration`" | Holds at HEAD, and is P4's closing invariant (Part 7): the only files under `.motoko/sessions/<id>/` stay `journal.jsonl` and `lease`. |
| 8 | (code comment, not ADR) `session-journal.ts:36–46` and its test `session-journal.test.ts:484–490` say `park_entered`/`wake_received` "DO NOT EXIST — … ADR-002 D2 is not activated" | **Stale since `85ce0c7`.** Both exist (`phase_vocab.ail:1320–1321`; host types `runtime-process.ts:141–142`). The test is flipped red first in Part 1. |
| 9 | (code) the twin, `journal_lines_of_records` | Its `twin_event` (`journal.ail:1873`) ends in `_ => acc` (`:1989`). A parked trace's journal therefore silently has no `park` and no `wake`, so `JournalFold` folds a parked run blind to the park and stays green. Part 1 turns this into a red-first row. |
| 10 | D5: `from_ordinal` is "the last `run_finished.world_ordinal` … the previous frame's `final`" | **Residual for a park exit.** A run that exits while parked writes no `run_summary`. So `SessionState.world_ordinal` (`journal.ail:1251–1256`) and `SessionResumed.from_ordinal` (`:2169`) name the *previous* run's final ordinal, not the parked run's last one. At HEAD the resumed world restarts its ordinals anyway (`journal_resume_dst.ail:30–34`). See P4-Q6. |

#### Work items, in dependency order

The order differs from the sketch's list: core comes before host. That way the host's respawn
(Part 5) hands the journal to a resumer that already exists (Part 3), and every core part is
visible to DST before any live part runs (§0.6).

| part | scope | estimate |
|---|---|---|
| 1 | `park`/`wake` entry types, their decoders, `BoundaryParked`, the twin's lines, the host's routing; red first | 1½–2 days, core + host |
| 2 | the live `wake_read` reads the cursor first; the recording binding asserted | ½–1 day, core |
| 3 | the resumer: fold `Parked` → seed the re-issued `<R'>.p0` into `wakes` → consume it → open the run at `initial_park_ordinal(true)`; the `park_resume` DST target, red first | 2–3 days, core |
| 4 | the suspended-child branch in the exit handler, before `restartPending`; `--park-exits` parsed, default off | 1–1½ days, host |
| 5 | on the answer, the host writes the `wake` entry as the `park`'s child, then respawns with `--resume` | 1 day, host |
| 6 | the named states and their `Lost`/`Aborted` exits | 1–1½ days, host |
| 7 | the no-wake-file / no-generation invariant, exactly-once across two resumes, and the live gate | ½ day, plus ½–1 day live |

**Estimate: 8–12 days** (core 4–6, host 3–4, the live gate and invariant 1–1½). Priced on Part
3 as drafted (P4-Q2 option (a)); option (b) falls within the same band.

##### Part 1 — the entries, red first (1½–2 days, core + host)

**Red-first commit** (tests only). Each is red at `d5edebf` and is recorded in §5 at T1:
1. `journal.ail:2739` asserts `List.length(all_entry_types()) == 10`. It becomes `== 12`, with
   `park` and `wake` in the list (`:1173–1176`).
2. `journal.ail:3136–3141` mutates entry 6 to `type: "park"` and expects `Entry(6,
   "type=park")`. Flip it on W3 flip 2's pattern: mutate to a genuinely unknown type
   (`"not_an_entry"`) and keep the refusal. A **new** test folds a journal that ends in a
   `park` to `BoundaryParked`; today that journal is refused at `:1496–1499`, so the test is red.
3. A twin test: `journal_lines_of_records` over records holding `ParkEntered` then
   `WakeReceived` yields a `park` line, then a `wake` line. Red, because `:1989` drops both.
4. `session-journal.test.ts:484–490`, flipped: `park_entered` and `wake_received` **are**
   journal-class. A new case records both and asserts two entries with `wake.parent_id ==
   park.id`.

**Green** (one commit):
- **Entry decoders** in `journal.ail`, beside the envelope (`:658–731`) and the entry-type set
  (`:1173–1176`):
  - `park` is `{ request_id, step, waits }`. `waits` is decoded through
    `phase_vocab.wait_descriptor_from_json` (`phase_vocab.ail:539`).
  - `wake` is `{ request_id, wait_id, outcome, detail }`. `outcome` must be one of the six ids
    the vocabulary names, the same set `dst_invariants.ail:1242–1243` checks.
  - **No new import.** `journal.ail` does not import `ports` (`:39–65`), and `ports.ail`
    imports `dst_interaction`, `dst_generator` and more (`ports.ail:44–88`). So the conversion
    from string to `WakeOutcome` (`wake_outcome_of`, `ports.ail:1140`) stays in `session.ail`,
    which already imports that module (`session.ail:201`).
  - Decoding is strict per field and refuses with `Refusal::Entry(seq, field)` (`:579–590`).
- **`Boundary`** (`:1226–1239`) gains `BoundaryParked(ParkEntry, Option[WakeEntry])`, with
  `boundary_id` `"parked"`.
- **`fold_entry`** (`:1438–1501`) gains two arms:
  - `park` sets `last: BoundaryParked(p, None)`.
  - `wake` requires `last` to be `BoundaryParked(p, None)` with `p.request_id ==
    w.request_id`, and otherwise refuses with `Entry(seq, "request_id")`. It then sets
    `BoundaryParked(p, Some(w))`.
  - The `exit` arm (`:1491–1494`) keeps a `last` that is `BoundaryParked` (row 5, P4-Q4).
  - Every other arm already moves `last` off a park. That is D7's exactly-once rule inside the
    fold: a consumed wake is followed by `run_started` (`:1461–1463`), so it is not offered
    again.
  - **One more closure (P4-Q2, P4-Q4).** A `wake` whose outcome is `aborted` folds to
    `BoundaryOpen("wake:aborted")`, so a cancelled park is not re-offered on a resume that
    opens no run.
- `plan_resume` (`:2110–2187`) keeps its shape. `suspended` stays `None` for `Parked`
  (`:2141–2156`), and `plan.last` (`:2180`) carries the park to the resumer.
- **The twin** (`twin_event`, `:1873`): `ParkEntered` becomes a `park` line and `WakeReceived`
  a `wake` line, both handled before the `_ => acc` arm.
- **The host.** `JOURNAL_CLASS` (`session-journal.ts:47–57`) gains both event types. `record`
  (`:482–529`) gains `case "park_entered"` → `append("park", …)` and `case "wake_received"` →
  `append("wake", …)`. The stale comment at `:36–46` is rewritten to say what landed.

**Gate.**
- The four reds are green.
- `ailang test src/core/journal.ail` is green, including fold fixtures for:
  - `park` alone → `Parked(p, None)`;
  - `park, wake` → `Parked(p, Some(w))`;
  - `park, wake, run_started` → not `Parked`;
  - `park, exit` → `Parked(p, None)`;
  - `park, wake(aborted)` → `Open("wake:aborted")`;
  - a `wake` for another `request_id` → refused at that entry with `Entry(seq, "request_id")`;
  - a `waits` element that is not a descriptor → refused at `waits`.
- `bun run test` and `tsc` green in `src/tui`.
- Unchanged and green: `make journal_resume` (13/13 at W5, and `rows=13` in the `d5edebf`
  sweep; confirm the count at run time), `make stream_parity` (runs `JournalFold`,
  `dst_invariants.ail:1991`), `make park_wake`.
- `make event_vocabulary` unchanged (45 rows in the `d5edebf` sweep; confirm the count at run
  time). **No `LedgerEvent` variant is added**, so `event_vocabulary_version()` does not
  move (Do not touch, below).
- No `session.ail` edit, so no anchor moves.

##### Part 2 — the live `wake_read` reads the cursor first (½–1 day, core)

- **Factor the cursor read.** In `ports.ail`, pull `scripted_wake`'s head arm (`:1160–1161`)
  out into `cursor_wake(state, req) -> Option[WakeInput]`. It returns the head of `wakes` as
  `Some`, with `next_state = advance_ordinal({ state | wakes: rest }, WakeRead)`.
  `scripted_wake` becomes `match cursor_wake(…) { Some(w) => w, None => wake_read_unbound(…)
  }`, with byte-identical behaviour.
- **The live binding.** `live_ports`' `wake_read` (`stub_step.ail:218–222`) becomes `match
  cursor_wake(state, req) { Some(w) => w, None => { println(wake_request_json(req));
  live_wake_await(state, req) } }`. A wake served from the cursor emits **no** `wake_request`
  and reads no stdin, because the host has already answered it (Part 5).
- **The named exception, written where the rule is stated.** Two comments each gain one
  sentence saying that `wake_read` is the one live binding that consults a world cursor,
  because a durable park's answer arrives through the journal (ADR-003 D7):
  - the live approval's comment (`stub_step.ail:205–208`), "a live run's approvals are not a
    replayable cursor";
  - the WI-D24 comment (`ports.ail:2830–2832`).
- **Recording: asserted, not changed.** Over a world seeded with `<R'>.p0`, `recording_wake`
  records one `WakeIdentity("loop_v2", "<R'>.p0", wait_id)` with `OutcomeOk`
  (`ports.ail:1188–1197`). If it does not, stop: the fault is W4 Part 4's, not P4's.

**Gate, red first.**
- **The red row.** A row in Part 3's `park_resume_dst.ail`, run by its Make target with stdin
  from `/dev/null`: on a world seeded with one `Settled` observation, `live_ports(rt).wake_read`
  returns that observation. At `d5edebf` it prints a `wake_request`, `readLine` returns `""`,
  and the reply is `Aborted` with `wait_id "eof"` (`stub_step.ail:296`). So the row is red and
  cannot hang. It is green after this part.
- `ailang test src/core/ports.ail` green, with the wake tests at `:1207`, `:1217` and `:1233`
  unchanged.
- `make park_wake` unchanged.
- `make driver_leaf_inventory` unchanged: `live_ports` is not a driver call site.
- `make anchors` run, since `stub_step.ail` is in the §0.2 cascade. If an anchor moves, it is
  re-baselined in this commit.

##### Part 3 — the resumer (2–3 days, core)

Drafted to PLAN-002 §8.4, R9 and W5(b): P4-Q2's option (a). When `plan.last` is
`BoundaryParked(p, wake?)`, `run_v2_resume_with_conversation` (`session.ail:5299–5333`) does
the following before it enters the conversation loop at `:5332`:

1. **Build the re-issued request.** `R'` is the identity the function already builds
   (`:5318–5319`, `initial_ordinal = 0`). The request is `{ request_id:
   between_turn_request_id(session_id, profile, resume_count, initial_ordinal), step: 0,
   waits: p.waits, attempt: 0 }`, which is `<R'>.p0` (row 1).
2. **Seed the cursor.**
   - With a `wake` child: `{ started_provider.world | wakes: [{ request_id: req.request_id,
     wait_id: w.wait_id, outcome: wake_outcome_of(w.outcome, w.detail) }] }`. Only the
     `request_id` is rewritten.
   - Without one: nothing is seeded. The live read (Part 2) asks the host, whose waiter
     performs ADR-002 D2's initial read, i.e. the re-observation. A gone pane is `Lost` (D7).
3. **Consume the wake in the resumed frame.**
   - Emit `ParkEntered(req)`, then call `wake = provider.ports.wake_read(world, req)`. This
     `ParkEntered` belongs to the **resumed** frame's trace (the prior frame already
     journaled its own `park`), so the twin's exactly-once argument (`run_started` after the
     `wake`) reads over the resumed journal, not as a duplicate of the prior frame's entry.
   - Witness the successor into the resumed frame via `witness` (def `session.ail:4572`).
   - Check `wake_matches(req, wake)` (`:3121–3129`). A mismatch is dropped with
     `park_drop_warning` (`:3183–3186`), and the resumer enters between turns with the folded
     history. There is no re-issue loop outside a run, because no step budget exists there to
     bound one.
   - A match emits `WakeReceived`.
4. **Open the run from the consumed wake.**
   - **`Aborted` opens no run.** The conversation loop is entered between turns, just as W4
     Part 5's `abort` returns from the read loop (`session.ail:4809–4815`), and the host is
     idle.
   - **Any other outcome opens one:**
     - Build the resumed state as `c2_state_from_continuation` does (`:2644–2685`), from the
       folded history plus `wake_message(wake)` (`:3168–3179`). The loop emits that message as
       `HistoryAppended`, on the operator message's pattern.
     - Apply `{ st | open_waits: apply_wake(p.waits, wake), park_ordinal:
       initial_park_ordinal(true), last_finish_reason: "user_injected" }`. This is the one
       site W5(b) names.
     - Run it through a new traced sibling of `run_v2_from_continuation_traced` (`:4378`). A
       sibling is needed because `Continuation` carries no waits (`journal.ail:135`;
       `session.ail:2675–2683`).
   - The run's `run_started` follows the consumed wake in the journal, which is D7's
     exactly-once order. After the run, the loop is entered with `run_ordinal` 1.
5. **The harness entry.** A new export (§0.7), `run_v2_session_park_resumed_traced`, beside
   `run_v2_session_resumed_traced` (`:5346–5361`) and on its pattern. It performs steps 1–4
   over a `ResumePlan` and returns the traced run with `SessionResumed`, `ParkEntered`, the
   witness and `WakeReceived` prepended.

**The DST script.**
- New file `scripts/dst/park_resume_dst.ail`, with a Make target `park_resume` beside
  `park_wake` (`Makefile:366–368`) and a row in `DST_TARGETS` (`:489–500`).
- It reuses the scripted runner shape of `park_wake_dst.ail` (`run_scripted` `:389`,
  `run_recorded` `:397`).
- It runs a delegate run that parks, builds the run's journal with `journal_lines_of_records`,
  and makes three truncations: after `park_entered`, after `wake_received`, and with an
  `exit` appended.
- Each journal is folded, planned, and resumed through the harness entry.

**Gate, red first.** The script lands before steps 1–5, and every resume row is red.
- `plan.last` is `Parked` for the three truncations, and not `Parked` for the untruncated
  journal.
- The resumed frame's `WakeIdentity` names `<R'>.p0` (recording ports, `stub_step.ail:626`,
  `:723`; confirm the sites at run time) and is served from the cursor (`OutcomeOk`).
- There is exactly one `WakeReceived` for `<R'>.p0`, and the resumed run's next park is `<R'>.p1`
  (the script parks twice).
- **Exactly once.** In the resumed run's journal (from the twin), `run_started(R')` comes after
  the `wake` for `<R'>.p0`, and folding it again gives a `last` that is not `Parked`.
- **Re-observation, T2.** `park, exit` with no wake child resumes to `HostError("wake_read
  unbound")` in DST (the unbound fall-through, `ports.ail:1109–1112`), with the waits kept.
  `Lost` is only visible at T4 (Part 7).
- A consumed `Aborted` opens no run, and the journal folds to `Open("wake:aborted")`.
- Part 2's `/dev/null` row.

Also green:
- `ailang test src/core/session.ail`, with W5's tests at `:5867–5893` unchanged (confirm the
  range at run time).
- `make park_wake`, `make journal_resume`, `make ledger_parity`, `make world_framed_wire`, as
  regression.
- `make driver_leaf_inventory`: under option (a), **26 sites, including one new `.wake_read(`
  site, witnessed**. The 25 baseline is confirmed from `make driver_leaf_inventory`'s output at
  the branch point before the 26 is asserted: the `d5edebf` sweep reads `driver leaf
  inventory (25 sites, 0 unresolved, 0 out of order)`, with the one `wake_read` site at
  `session.ail:3531` (`c2_loop`, clean). `make driver_leaf_inventory_selftest` gains a
  `TREE_MUTANTS` entry for the new site on the pattern of `derive.py:640–644` (the existing
  `wake_read successor not witnessed` mutant: `("leaf", "st.provider.wake_read", …)`).
- `make anchors` re-baselined.
- The sweep at the branch point, disclosed (§0.1).

##### Part 4 — the suspended-child branch (1–1½ days, host)

- **`--park-exits`**: a bare TTY flag parsed beside `--oneshot` (`index.ts:658`), default
  **off**. With the flag off, nothing in this part runs.
- **Entering suspended-child** (P4-Q3). In `RuntimeProcess.onWakeRequest`
  (`runtime-process.ts:985–999`), a first issue under `--park-exits` ends the child with
  `kill()`. By then the `park` entry is on disk: the child emits `park_entered` before
  `wake_request` (`session.ail:3530`, then `stub_step.ail:220`), and the host appends it
  synchronously. `kill()` sets `killRequested`, which suppresses the synthesized `error`
  (`:775`).
- **The exit branch, before `restartPending`.**
  - Today `proc.on("exit")` (`:764–780`) calls `resolvePark()` (`:769`), which cancels the
    waiter (`:1028–1032`). Under suspended-child it instead hands the outstanding request and
    the running waiter to a host-lifetime `SuspendedChild` owner.
  - The TTY child-exit callback (`index.ts:1132–1185`) gains a first branch, **above** `const
    pendingRestart` (`:1138`). On suspended-child it writes no `exit` (row 6), skips the
    one-shot branch, shows the operator a parked status while keeping input open for the
    parked input route, and returns.
  - The non-TTY callback (`:1048–1060`) does not take the flag (P4-Q3).
- The lease stays held (`index.ts:906–928`).
- **The race, named.** A waiter reply that arrives between `kill()` and the child's exit
  writes **no** `wake` entry and starts **no** respawn: the request died with the child, and
  the park is re-observed on the next resume (row 5). Only a reply the `SuspendedChild`
  owner receives, after the exit branch has taken the request, is Part 5's.

**Gate, red first.**
- A `runtime-process` test with a fake child, using the `runtime-process.wake.test.ts`
  harness: `wake_request` under `--park-exits` → `kill` → exit.
  - The waiter is **still running**.
  - No `error` reaches `onEvent`.
  - The journal's leaf is the `park` entry.
  - Kill-then-reply writes nothing: a reply delivered between `kill()` and the exit leaves
    the leaf at the `park` entry and requests no respawn.
- The test is red at `d5edebf`, where the waiter is cancelled at `:769`.
- `bun run test` and `tsc` green.

##### Part 5 — the `wake` entry and the respawn (1 day, host)

- **On the waiter's reply** in suspended-child:
  1. `journal.record({ type: "wake_received", request_id, wait_id, outcome, detail })`. Part
     1's routing appends a `wake` whose `parent_id` is the leaf, i.e. the `park` (row 6).
  2. `respawnForRestart()` (`index.ts:1244–1254`), which checks `canResume`
     (`session-journal.ts:258`), bumps the resume count, and passes `--resume <journal>`.
- Late and duplicate replies are dropped by `request_id`. That is `sendWakeReply`'s rule
  (`runtime-process.ts:1005–1019`), which moves with the request to the new owner.

**Gate.** Host tests:
- exactly one `wake` entry, with `wake.parent_id == park.id`;
- a second reply writes nothing;
- the respawn's argv carries `--resume`, asserted as `harness-dst.test.ts:132–145` does;
- the written file folds to `Parked(p, Some(w))`, checked by a small AILANG script (P3 Part 4's
  gate shape).

`bun run test` and `tsc` green.

##### Part 6 — the named states and their exits (1–1½ days, host)

Transcribed from row 4's sources and W4 Part 5's command table (§8.7). The rows that v4.1
settled are for P4-Q5 to confirm.

| state | entered on | left on | journal | then |
|---|---|---|---|---|
| `parked` (W4; exists) | `wake_request` while the child is alive (`runtime-process.ts:985–999`) | `wake_received`; a park-ending event (`:184`); child exit | the child's events | — |
| `suspended-child` | Part 4 | a waiter reply; operator input; ESC; `restart`; quit; host death | nothing on entry | per row below |
| `resuming` | a `wake` entry is written | the resumed child's `session_resumed` | `wake` | `--resume` |

| while `suspended-child` | wake written | then |
|---|---|---|
| the waiter replies `Settled` / `Lost` / `TimedOut` / `HostError` | that outcome | respawn (Part 5) |
| operator input (the parked input route) | `OperatorInput(content)` | respawn |
| ESC (`interruptRuntime`, `runtime-process.ts:187–197`) | `Aborted`, `wait_id "abort"` | no respawn; the TUI awaits a task, and the next prompt resumes through `onInitialTask` (`index.ts:1313–1326`) into `Open("wake:aborted")` |
| `restart` (profile p) | `Aborted`, `wait_id "restart:<p>"` | respawn with the new profile (`index.ts:1161–1166`) |
| quit | **none**; the lease hook writes `exit` (`session-lease.ts:236`) | the exit actions run; a later resume re-observes, and wakes `Lost` if the delegates were reaped (REVIEW §8) |
| host death (signal) | none; the lease hook writes `exit`, reason `abort` or `host_exit` (`session-lease.ts:240`) | as quit |

The two operator-input rows differ by entry condition alone: text **typed at the parked
prompt** takes the parked input route (`OperatorInput(content)`, then respawn), while
**ESC** goes through `interruptRuntime` (`Aborted`, `wait_id "abort"`, no respawn).

**Gate.**
- One host test per row, with a fake waiter and a fake child.
- The ESC row asserts no respawn and exactly one `wake(aborted)`.
- The quit row asserts no `wake`, and an `exit` entry after the `park`.
- `bun run test` and `tsc` green.

##### Part 7 — the invariant, and the live gate (½ day, plus ½–1 day live)

- **No wake file, no generation.**
  - T0: after Part 5's host test, the session directory contains only `journal.jsonl` and
    `lease`, and `git grep -n -i -E 'WakeGeneration|wake_generation|wake-file'` over `src/core`
    and `src/tui/src` finds nothing.
  - T2: Part 3's exactly-once rows, extended to a **second** resume of the resumed journal. No
    cursor is seeded and no `WakeIdentity` is recorded.
- **The live gate** (T4; recorded in §5 with log paths). In a herdr pane, with `--park-exits`
  passed explicitly, run one delegation:
  1. `Delegate`, then the run parks.
  2. The child exits, with no `error`, and the journal's leaf is the `park`.
  3. The delegate answers, and exactly one `wake` entry is written as the `park`'s child.
  4. The host respawns with `--resume`, and the resumed frame serves `<R'>.p0` from the cursor:
     no `wake_request` appears on the resumed child's stdout before its `wake_received`.
  5. `DelegateCheck`, then the final answer.

  Record the provider-call count across both processes; the success path is 4. Add one `Lost`
  control: kill the delegate pane while the host is in suspended-child.
- **`--park-exits` stays off** in every default after this gate. Turning it on is an owner
  act, taken after the §5 entry exists.

**Done when.** Parts 1–7 are green at their tiers, and §5 carries the red-first records (Parts
1–4), the sweep disclosure, and the live gate.

#### Do not touch

- **W-O5** (`DelegateAwait`): it never landed (`85ce0c7` gate 9). P4 adds no fallback tool.
- **QCANARY**: the `depth_canary` pin (`run_depth_canary.sh`) and its `DST_KNOWN_RED` entry.
  Operator-owned.
- **PINDH-owned files**: `src/core/dst_driver_plus_herdr.ail` and
  `scripts/dst/herdr_graded_dst.ail` (`eba309c`, `9ad4d2b`), and the `DST_KNOWN_RED` block
  `Makefile:653–672`. That includes its assignment line, which was not dropped; this is
  reported above and left alone.
- **`event_vocabulary_version()`** (`dst_event_vocabulary.ail:121`, `"event-vocabulary/1"`).
  The version changes only on a change to a variant, a wire name, a payload schema or a
  classification (`:80–85`). P4 makes none of these: the `park` and `wake` entries are
  projections of W4's two existing variants. A part that finds it needs such a change has left
  this plan.
- **`--park-exits` on by default**, before Part 7's live gate.
- **Also unchanged:**
  - `ParkEnteredInfo` and `WakeReceivedInfo`, and their goldens (`phase_vocab.ail:1015–1020`,
    `:1962–1963`);
  - `decide`;
  - the body of the `Park` arm (`session.ail:3527–3564`);
  - the `Ports` field set (`ports.ail:896`, §0.8);
  - `world_of_json`;
  - the headless `error` (P3 Part 6);
  - the signatures of the exported traced entries (§0.7).

#### Evidence tiers

PLAN-002 §5's tiers: T0 static; T1 unit; T2 DST target; T3 wire-framed; T4 live.

| part | closes at |
|---|---|
| 1 | T1 (journal and host unit tests) + T2 (`journal_resume`, `stream_parity`, `park_wake`, as regression) |
| 2 | T2 (`park_resume`'s `/dev/null` row) + T1 |
| 3 | T2 (`park_resume`; the inventory); T3 as regression (`world_framed_wire`, `ledger_parity`) |
| 4–6 | T1 (host tests). Nothing in these parts is visible to DST (§0.6) |
| 7 | T0 + T2 + **T4** |

A claim is reported at the tier it was verified at, never above it.

#### Owner questions (§8-style; none reopens an ADR decision)

1. **P4-Q1. Can P4 start on W4's T2 evidence? DECIDED (owner 2026-09-14) — Parts 1–3 may
   start; Parts 4–7 wait for W4 gate 8's live parked run.** W4 gates 7 and 8 are open at T4
   (Background). Parts 1–3 are pure core, DST-visible; Parts 4–7 are a strict superset of
   the live run.
2. **P4-Q2. Where is the re-issued `<R'>.p0` consumed?**
   - **(a) In the resumed frame, before the run** (drafted in Part 3).
     - For: it transcribes §8.4, R9 and W5(b), and D7's exactly-once order (`run_started`
       after the wake).
     - Against: it adds a second witnessed `.wake_read(` site. The inventory goes from 25 to
       26 with a new tree mutant, and W4's "one call site" statement becomes "one per frame
       kind". It also needs a mismatch path with no budget, and the `Aborted`-closure fold
       rule.
   - **(b) In the resumed run's first `decide`** (D7's literal text). The run opens at
     `park_ordinal` 0 with the waits; the existing `Park` arm serves `.p0` and increments to 1.
     - For: one call site, and `Aborted` ends in `c2_fail` → `run_finished` with no new fold
       rule.
     - Against: `run_started` comes before the consumed wake, and `initial_park_ordinal(true)`
       is not applied at the resumer (the arm's increment reaches 1 instead), which contradicts
       R9's wording.

   Recommended: (a). §8.4 is decided, and (b) would re-read it.

   **DECIDED (owner 2026-09-14) — option (a): consume `<R'>.p0` in the resumed frame,
   before the run.** Accept the costs: 25→26 driver sites with one new witnessed
   `.wake_read(` + tree mutant, a droppable mismatch path with no budget
   (`park_drop_warning`), and the `Aborted`-closure fold rule.
3. **P4-Q3. How does the child exit under `--park-exits`, and which parks exit?** Drafted: the
   host calls `kill()` once the `park` entry is on disk; every first-issue park exits; TTY
   only. The alternative on scope is that only parks whose waits are all `DelegateWait` exit,
   so an `OperatorWait` or `TimerWait` park stays live. A core-side exit is not offered: it
   would write `run_summary` and fold to `RunFinished`.

   **DECIDED (owner 2026-09-14) — as drafted:** host `kill()` once the `park` entry is on
   disk; every first-issue park exits; TTY only; non-TTY callback unchanged; no core-side
   exit.
4. **P4-Q4. The fold's boundary rules** (row 5, and the `Aborted` closure). Confirm that `park
   → exit` folds to `Parked` (ADR-002 D4 over the literal text of ADR-003 D4 rule 6), and that
   `wake(aborted)` closes the park.

   **DECIDED (owner 2026-09-14) — confirm both rules:** `park → exit` folds to
   `Parked(req, None)` per ADR-002 D4 (over literal ADR-003 D4 rule 6); `wake(aborted)`
   closes the park (→ `Open("wake:aborted")`).
5. **P4-Q5. The suspended-child command table** (Part 6). It needs sign-off because v4.1's D7
   is not in the tree. In particular, quit writes **no** `wake` and the park is re-observed on
   resume (REVIEW §8), whereas W4 Part 5 makes `exit` sent to a live child an `Aborted` cancel.

   **DECIDED (owner 2026-09-14) — sign off the Part 6 table as written, including the
   dead-child vs live-child distinction:** quit / host death while suspended writes **no**
   `wake` (lease hook writes `exit`; later resume re-observes, `Lost` if delegates were
   reaped); `exit` sent to a *live* child is an `Aborted` cancel per W4 Part 5. ESC → one
   `wake(aborted)`, no respawn, TUI awaits task → `Open("wake:aborted")`; `restart` →
   `Aborted` with `wait_id "restart:<p>"` + respawn on the new profile.
6. **P4-Q6. `from_ordinal` after a park exit** (row 10). Either accept it as a stated limit,
   or add the parked run's last ordinal to the `park` entry. The second option would change
   `ParkEnteredInfo` and its golden, and would move `event_vocabulary_version()` under the
   `:80–85` rule.

   **DECIDED (owner 2026-09-14) — accept as a stated limit.** `from_ordinal` after a park
   exit names the previous run's final; the resumed world restarts ordinals anyway. Do not
   extend `ParkEnteredInfo` (no golden move, no vocab-bump).
7. **P4-Q7. The live gate's operator, and the flag's future.** Who runs Part 7's herdr session
   (it needs a real delegate)? Is `--park-exits` ever defaulted on, or does it stay opt-in?

   **DECIDED (owner 2026-09-14) — operator runs the Part 7 herdr session;
   `--park-exits` stays default-off.** Turning it on is a later, explicit owner act after
   the §5 entry with log paths exists.

#### Handoff (§7-ready)

- **Row for the §7 estimates table:** `| P4 | v3 | 8–12 | entries and fold (1½–2); live cursor-first read (½–1); resumer and park_resume target (2–3); suspended-child branch (1–1½); wake-as-child and respawn (1); named states (1–1½); invariant and live gate (1–1½) — planned v1 reviewed, R1–R8 applied, grounded d5edebf; Parts 1–3 startable on T2, 4–7 gated on W4-live |
  live cursor-first read (½–1); resumer and park_resume target (2–3); suspended-child branch
  (1–1½); wake-as-child and respawn (1); named states (1–1½); invariant and live gate (1–1½)
  |`.
- **Row for the Phases table:** `| P4 | step 4 | durable park as entries (D7): park/wake
  entries, cursor-first live wake_read, resumer, suspended-child host state | 8–12 days, core
  + host; gated on P4-Q1 |`.
- Neither row is applied by this pass, which edits one section only.
- **Commits:** one per part, titled `ADR-003 D7: P4 Part N — …`, with the red-first record in
  the commit message and in §5.
- **dagr:** `P4` in `.dagr/run-plan003.json` splits into `P4.1`–`P4.7`.
  - Dependencies run in order: 1 → 2 → 3 → 4 → 5 → 6 → 7.
  - Parts 4–7 are also gated on P4-Q1.
  - Part 3 is gated on P4-Q2.
  - Parts 4 and 6 are gated on P4-Q3 and P4-Q5.
  - Part 1's fold rules are gated on P4-Q4.
- **§5 entries to fill:**
  - Part 1's four reds;
  - Part 2's `/dev/null` red;
  - Part 3's red resume rows;
  - Part 4's waiter-cancel red;
  - the sweep at the branch point;
  - Part 7's live session, with log paths.
- **Review.** Review this section (v1, against HEAD) before Part 1 starts, and apply the §7 and
  Phases rows in the same pass.

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
7. **The external eval-harness adapter — resolved 2026-09-12 (QEVAL): it keys on `error`.**
   The headless-only emission stays, ADR-003's Consequences carries the line, and P3 Part 6
   switched the loggers without removing it (§5, "P3 Part 6: the eval-harness finding").
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

### P4 Part 7, 2026-09-15: the invariant, exactly once across two resumes, and the live gate

Base `44c7a3a` (P4 Part 6). One commit `298bec5` on `arniwesth/013-plan003-and-herdr`, not pushed.
P4-Q1 as decided: Parts 4–7 ran after W4 gate 8's live parked run (the 2026-09-14 session
`session_1789402741851`, 4 provider calls, in `.motoko/logfile`). P4-Q7 as decided: the worker ran
the herdr session as the operator's delegate, in its own pane; `--park-exits` was passed explicitly
on each launch and stays default-off. Part 7 has no red-first record: its rows are the invariant's,
not a behaviour's, and the plan asks for none. Its commit holds the two T2 rows' files, the T0 test,
and the live captures; this record stays in the working tree, on Parts 1–6's pattern.

**T0, the invariant.** `git grep -n -i -E 'WakeGeneration|wake_generation|wake-file' -- src/core
src/tui/src` exits 1 with no line, at `44c7a3a` and at `298bec5` (the new test's comment
describes the grep without spelling its names, since a first draft of it was the grep's one hit).
The host test (`runtime-process.wake.test.ts`, the Part 7 block): Part 5's flow — the park, the
waiter's reply, the `wake` as the park's child, the `--resume` respawn — run under the lease the host
takes (`acquireLease(journal.dir, sessionId)`, as index.ts does), with `readdirSync` of the session
directory asserted at four points: `["journal.jsonl"]` before the lease (the harness takes none),
`["journal.jsonl", "lease"]` while suspended, after the wake and after the respawn, and
`["journal.jsonl"]` after `release()`; the whole `.motoko/sessions` tree under the test's workdir is
that one session with those two names, and no name matches `/wake|generation/i`. `jest
src/runtime-process.wake.test.ts` 27/27 (26 + 1). `tsc --noEmit -p src/tui` clean. `bun run test` in
`src/tui`: 420/420 tests, 41/46 suites; the five that fail to LOAD are Part 1's five
(`compose-output-validator`, `compose_guard_semiformal`, `env-server`, `scratchpad/loopback`,
`test/path-guard`), as Parts 5 and 6 recorded. Live (below): every session directory held
`journal.jsonl` and `lease` while its host ran, in suspended-child included, and `journal.jsonl`
alone after the host quit; nothing else was ever written there.

**T2, exactly once across two resumes.** `make park_resume` PASS: **11 rows** (7 + 4), every
assertion, every shell check, 10.4 s. The resumed journal — frame 1 cut after `wake_received`, then
a resumed frame shaped as `resume_after_wake`'s, re-run under its own label `resume_twice_base` so
Part 3's row is untouched — is resumed a second time, cut three ways, through the same harness entry
(`run_v2_session_park_resumed_traced`, resume_count 2, recording ports):

| row | cut | what it pins |
|---|---|---|
| `resume_twice_base` | — | Part 3's claims hold in the input: one `WakeReceived` for `w4.r1.0.p0` with the first wake's detail; `run_started(w4.r1.0)` after the `wake` for `w4.r1.0.p0`; each consumed wake's line (`w4.r0.0.p0`, `w4.r1.0.p0`) exactly once |
| `resume_twice_started` | right after `run_started(w4.r1.0)` — the child died the instant the run opened | `last` is `open:run_started`, not Parked; the second frame is `SessionResumed` alone (no `ParkEntered`, `WakeReceived`, `SessionStart`, `ProviderCallPrepared`); **no `WakeIdentity`, no `wake_read` witness**; a decoy cursor element for `w4.r2.0.p0` is still the world's head, nothing seeded ahead of it; the frame returns the folded history between turns; the three-frame journal refolds to not Parked and holds each consumed wake's line once |
| `resume_twice_finished` | the whole two-frame journal | `last` is `run_finished`; the same second frame and the same assertions |
| `resume_twice_parked` | after the resumed run's OWN park `w4.r1.0.p1` on [h2], no wake child | the re-issue is `w4.r2.0.p0` at step 0 on [h2]; exactly one `WakeReceived`, for `w4.r2.0.p0`, settled on h2 with the world's detail (`a2`) — none for `w4.r1.0.p0`, none with the first wake's detail; the only `WakeIdentity` names `w4.r2.0.p0` on h2; the run opens once (`w4.r2.0`) and ends Ok; the three-frame journal has `run_started(w4.r2.0)` after the `wake` for `w4.r2.0.p0`, each consumed wake's line once, refolds to not Parked and to the run's final history |
| wire (shell) | | the two no-run frames: no `wake_request`, `wake_received`, `park_entered` or `session_start`, exactly one `session_resumed`, no `error`; the re-parked frame: exactly one `wake_received`, for `w4.r2.0.p0` on h2, one `session_start` for `w4.r2.0`, **in that order**, none for `w4.r1.0.p0`, no `wake_request`, no `error` |

The discriminating control is Part 3's own `resume_after_wake`: the same journal cut one entry
earlier (after the `wake`, before `run_started`) DOES seed and consume. What separates "offered
once" from "offered again" is the `run_started` that follows the consumed wake, and nothing else —
no wake file, no generation. `ailang check scripts/dst/park_resume_dst.ail` clean.

**T4, the live gate** (captures tracked at
`.agent/projects/013_core_architecture_for_dst/evidence/plan003-p4-live-gate/`, repo-root path,
added by `298bec5`; per capture `wire.jsonl` is the SessionLogger's copy of both children's
stdout in order, `journal.jsonl` the session's journal after the host quit, `timeline.txt` the
journal's entries with UTC times, `judge.log` the output of the directory's `judge.sh` over the
capture). Herdr pane `w1:p3M` in its own tab, TTY, `HERDR_DELEGATE_DEPTH=0` (the worker's own pane
carries depth 1, which is the extension's default limit and would have refused the delegation),
profile `default`, `MODEL=openrouter/anthropic/claude-haiku-4.5`, delegate kind `claude`,
`./scripts/run-agent.sh --park-exits`, the task typed at the prompt (the awaiting-task path). The
task is the 2026-09-14 gate-8 task: Delegate once, end the turn waiting, on the wake call
`DelegateCheck` once and answer with the delegate's number; the delegate counts the `test_`
functions in `src/core/step_machine.ail` (25).

*The success path* — `success/`, session `session_1789481992510-a735568fbeff5102`, the delegate
told to sleep 75 s first (finding 1 below is why):

| gate item | observed |
|---|---|
| 1. Delegate, then the run parks | wire: `native_tool_calls` (`Delegate`) at line 74, `park_entered` at 89, `wake_request` at 90 (attempt 0), 2 `provider_call_prepared` before it; journal `0009 park r0.0.p0` at 14:21:24.807, `step 2`, one `DelegateWait` (`mot-dlg-1789482044663`, pane `w1:p3R`) |
| 2. The child exits, no `error`, the leaf is the `park` | no `error` and no `wake_received` from the first child; at 14:21:46 the host's only child process was the waiter's `herdr agent wait w1:p3R --until idle --until done --until blocked` (`host-children-while-suspended.txt`; no `ailang`), herdr reported the pane `blocked`, the footer read `suspended_child`, the session directory held `journal.jsonl lease` |
| 3. The delegate answers; exactly one `wake` as the park's child | answer file at 14:23:02.265; journal `0010 wake` at 14:23:02.365, `parent_id 0009`, `settled`, `wait_id mot-dlg-1789482044663`, `detail "25\n"`; one `wake` for `r0.0.p0` in the file; no `exit` between them |
| 4. The host respawns with `--resume`; the resumed frame serves `<R'>.p0` from the cursor | `ps` at 14:23:02: `ailang run … supervisor.ail -- --profile default … --resume /workspaces/motoko_agent/.motoko/sessions/session_1789481992510-a735568fbeff5102/journal.jsonl`, no `--resume-force` (`resumed-child-argv.txt`); journal `0011 resumed` (`resume_count 1`, `from_id 0010`), `0012 park r1.0.p0` (step 0, the same wait), `0013 wake r1.0.p0` settled `"25\n"`, `0014 run_started r1.0`, all at 14:23:52.466–.473; wire after `session_resumed` (line 95): `park_entered` 98, `wake_received` 109 for `r1.0.p0` with the journal's outcome and detail, `session_start(r1.0)` 110 — **no `wake_request` on the resumed child's stdout before its `wake_received`**, and none after |
| 5. `DelegateCheck`, then the final answer | wire: `native_tool_calls` (`DelegateCheck`) at 138, `done` at 174 (`"… contains **25** functions …"`); journal `0021 run_finished r1.0`, `cumulative.provider_calls_completed 4`; no `error` |

**Provider-call count across both processes: 4** — `provider_call_prepared` 2 in the first child
(lines 21, 79) and 2 in the resumed child (117, 143); the journal's `run_finished.cumulative`
carries the same 4 across the process boundary. `judge.log`: 15/15, PASS. Quit (Ctrl+C) wrote
`0022 exit child_exit`; the session directory then held `journal.jsonl` alone.

*The `Lost` control* — `lost/`, session `session_1789482343611-ea7db6272bf89647`, the delegate
told to sleep 300 s: at 14:27:13, with the park journaled (`0009`, 14:27:13.292), the host's runtime
child gone and its only child the waiter's `herdr agent wait w1:p3T …`, the worker ran `herdr pane
close w1:p3T`. The waiter replied within a second: journal `0010 wake` at 14:27:14.231, the park's
child — **outcome `host_error`, not `lost`** (finding 2 below), `wait_id ""`, detail `herdr agent
wait w1:p3T --until idle --until done --until blocked failed (exit 1, code agent_not_running)`. The
rest is the success path's shape: the respawn with `--resume <journal>` (14:27:14), `resumed`,
`park r1.0.p0` with the wait KEPT (a `HostError` wake keeps its waits, Part 3's `resume_park_exit`
row), `wake r1.0.p0 host_error` served from the cursor with no `wake_request` before it (wire 101 →
104 → 115), `run_started r1.0`; the model was told the host could not observe the waits, called
`DelegateCheck` (wire 183), which reported `agent_not_found`, and answered "DelegateCheck reported:
agent `mot-dlg-1789482392903` was not found — the delegate pane is no longer live …" (`done`, 217);
`run_finished` with `provider_calls_completed 4` (2 + 2). `judge.log` with expected outcome
`host_error`: 15/15, PASS. The session resumed through the cursor and finished on the wake the
host wrote; what the wake was called is finding 2.

**`--park-exits` stays off in every default.** `parseMotokoFlags` initialises `parkExits: false`
(`index.ts:656`) and only the literal `--park-exits` sets it (`:666–671`); `RuntimeProcess`'s
constructor defaults `parkExits = false` (`runtime-process.ts:883`); `git grep -- '--park-exits'`
over `Makefile`, `scripts`, `.motoko/config` and `docs` finds only the fold script's comment, and no
`parkExits: true` exists outside the tests. Part 4's control test ("with --park-exits off nothing
here runs") is green in the 27. The recovery run below ran without the flag and its runtime child
answered its own `wake_request` over stdin, as before P4. Turning the flag on remains an owner act.

**Two findings, reported, not repaired** (both outside Part 7's files; Parts 3–6's internals and
the herdr extension are not this part's to change).

1. **R5's window swallows an answer that is already on disk at the park** —
   `attempt1-r5-window/`, session `session_1789481624070-4283dd460d10de91`, the first success-path
   attempt, whose delegate was given the gate-8 task unchanged. The delegate answered in 27 s: its
   answer file landed at 14:15:00.220; the model's second turn was slower and the park was journaled
   at 14:15:13.480 (`timeline.txt`). At the `wake_request` the waiter's initial answer read found the
   file and queued `settled` (`wake-waiter.ts`, `observeAnswer` → `ready` → `deps.defer(flush)`);
   `onWakeRequest` had already called `kill()` synchronously, so the deferred reply reached
   `onWaiterReply` with `suspending !== null` and Part 4's R5 rule dropped it ("between kill() and
   the exit … nothing is sent and nothing is written"), with the waiter `finished` by its own
   `flush`. The exit then handed the owner a request whose waiter would never report again. The host
   sat in `suspended_child` for 3½ minutes with the answer on disk and no `wake`; the worker quit it
   (Ctrl+C, Part 6 row 5: `0010 exit host_exit`, the park's child, no `wake`, the lease released).
   **Recovery, measured** (`recovery-*` in the same directory): the session restarted WITHOUT
   `--park-exits` (`MOTOKO_SESSION_ID=<id> ./scripts/run-agent.sh`) adopted the journal, folded
   `Parked(p, None)`, re-observed the park through a live `wake_request` (`r1.0.p0`, the wait kept),
   and the new waiter's initial read found the answer: `0013 wake r1.0.p0 settled "25\n"` 9 ms
   after the re-issued park, `run_started r1.0`, `DelegateCheck`, `done` with 25, `run_finished`
   with `provider_calls_completed 4` (2 + 2 across the session's two runs). Under the flag the same
   restart would lose the race again, deterministically: the answer is on disk before every
   `wake_request`. So: **a delegate that finishes before the run parks is never woken under
   `--park-exits`**; the session is not lost, but the automatic wake is, and the owner should
   weigh this before turning the flag on. The repair is small and in Part 4's file: hold the reply
   that arrives while `suspending !== null` and hand it to the `SuspendedChild` at construction (it
   already accepts a held reply, Part 5's "a reply held before install"), which flips Part 4's
   "kill-then-reply writes nothing" row to "kill-then-reply is held for the owner". Owner's call.
2. **Closing a delegate's pane wakes `host_error`, not `lost`.** `herdr agent wait <pane>` blocked
   on a pane that is closed under it exits 1 with code `agent_not_running`, a code neither twin
   classifies as the agent being gone (`herdrMeansAgentGone`, `wake-waiter.ts:128–130`; the
   extension's `means_agent_gone`, `types.ail:1012–1021`, whose own comment says the enumeration is
   measured, not exhaustive). Only `agent_not_found` — what `agent get` returns afterwards, and what
   `DelegateCheck` saw — means gone. So the outcome the plan calls `Lost` reached the journal and
   the resumed run as `HostError` with the waits kept, and the session finished only because the
   model called `DelegateCheck`, which settled it. The mapping is W4 Part 5's file and the
   extension's; adding `agent_not_running` to both twins, with a fixture, is a one-line change each
   and an owner decision. The DST row for the `lost` wake (Part 6 row 1's `lost`, `park_wake`'s
   fixtures) is unaffected: it tests the outcome, not herdr's code for it.

**Anchors at `298bec5`.** `park_resume_dst.ail`: the ids `twice_run_id` / `rp2`, the helpers
`records_through_nth`, `count_lines`, `twice_script`, the `Twice` record and `twice(f)`, the rows
`row_resume_twice_base`, `row_resume_twice_no_run` (shared by `_started` and `_finished`),
`row_resume_twice_parked`, and `main`'s `twice_results`; `run_park_resume.sh`: rows 11, the four
frame labels, the Part 7 checks after "abort/dropped". `runtime-process.wake.test.ts`: the Part 7
block at the end of the file (`walk`, the one test). The captures' directory: `README.md`,
`judge.sh`, `success/`, `lost/`, `attempt1-r5-window/`.

**The sweep at the branch point (§0.1), disclosed.** Not run for this part (foreground `make dst`
is outside the worker's scope, and this part touches no `src/core` file; the DST target it extends
was run alone). The standing record is Part 3's.

**Judgment calls, stated.**
1. **The second-resume rows re-run the resumed frame under their own label** rather than returning
   it from Part 3's row: Part 3's row keeps its signature and its frame, one scripted frame is
   cheap, and `resume_twice_base` asserts the input's exactly-once claims itself, so the rows are
   self-validating.
2. **Three cuts, not one.** The plan's sentence names the resumed journal; "after `run_started`" is
   the tightest reading (a death the instant the run opened), "finished" is the ordinary one, and
   "after the run's own park" is the case where the second resume is itself a park resume, which is
   where a re-offer would do the most damage (a stale wake answering the wrong delegate). All three
   assert the consumed wake's line appears once in the three-frame file.
3. **T0's host test takes the lease as index.ts does**, since the plan's sentence names `lease`
   and the harness's `suspend` takes none; the four listings pin that nothing but the journal and
   the lease is ever created, including by the respawn.
4. **The gate's delegate was slowed, not the host.** After finding 1 the success path needs the
   answer to land after the park; a 75 s `time.sleep` in the delegate's task does that without
   touching any file. Finding 1's attempt is kept as a capture, not discarded: it is the gate's
   most useful output.
5. **The `Lost` control closes the pane** (`herdr pane close`), the plan's words, rather than
   killing the delegate's process, which would have left the pane and its row.
6. **Default-off is verified in three places** — the parse default, the constructor default and
   the grep over build and config files — plus Part 4's control test and a live run without the
   flag; no one place proves it alone.
7. **The judge is a script beside the captures**, so the owner can re-run it on the same files (or
   on a later run) rather than trust this record's reading of them. Its two tool-call lookups were
   wrong on the first run (`"name"` for `"tool"`) and were corrected before the numbers above; the
   captures did not change.

### P4 Part 6, 2026-09-15: the named states and their exits — red first, then green

Base `ab9c47e` (P4 Part 5). One commit `44c7a3a` on `arniwesth/013-plan003-and-herdr`, not pushed.
P4-Q5 as decided (owner 2026-09-14): the Part 6 table as written, including the dead-child vs
live-child distinction. Input as Part 5 left it: the owner's one reply consumed by
`installSuspendedWake` (the `wake`, the `--resume` respawn), with "how that reply's waiter is
ended" on the `restart`/quit rows, and the parked/resuming footer state, left to this part. The
red-first record is here and in the commit message, on Parts 2–5's pattern: the reds were taken in
the working tree.

**T1, red at `ab9c47e`** (only `runtime-process.wake.test.ts` and `herdr-agent-state.test.ts`
changed: six tests under `the named states and their exits`, two extended): both suites fail to
compile. The wake suite: `TS2724: '"./runtime-process.js"' has no exported member named
'abortSuspendedChild'`, `TS2339: Property 'isClosed' does not exist on type 'SuspendedChild'` (×4),
`TS2339 … 'close'`, and `TS2554: Expected 1 arguments, but got 2` (×3, `interruptRuntime`'s second
parameter). The herdr suite: `TS2322`/`TS2345: Type '"parked"' is not assignable to type
'MotokoRunState'` and the same for `"suspended_child"` and `"resuming"`. 0 tests run.

**T1′, red in the harness shape** — the surface exported but inert (`close()` returns true and ends
nothing; `abortSuspendedChild` closes and writes nothing; `interruptRuntime` therefore answers
`"none"`): 3 of the 6 red, 3 green. The reds, from node's jest: row 3 (ESC) `Expected: "wake_aborted"
Received: "none"`; row 4 (`restart`) `Expected: true Received: false`; row 5 (quit) `Expected: 1
Received: 0` (the waiter's cancel count). The three green are rows 1, 2 and 6: they pin what Part 5's
consumer and the lease hook already do, and are the table's controls.

**Green at `44c7a3a`.** `jest src/runtime-process.wake.test.ts` 26/26 (20 + 6 new);
`jest src/herdr-agent-state.test.ts` 16/16. `tsc --noEmit -p src/tui` clean. `bun run test` in
`src/tui`: 419/419 tests, 41/46 suites; the five that fail to LOAD are Part 1's five
(`compose-output-validator`, `compose_guard_semiformal`, `env-server`, `scratchpad/loopback`: depd
`callSite.getFileName is not a function` under bun; `test/path-guard`: the jest worker), none of
which imports this part's files. One disclosure: a verbose run of the wake suite started
CONCURRENTLY with the full suite, seconds after the test file was edited, showed two failures — Part
4's flag-off control and Part 5's first test, both fast (3–5 ms), neither Part 6's. Five subsequent
runs (three bun and one node alone, two node processes concurrently on the file) were 26/26, and the
full suite's own run of the file passed. The likeliest cause is two jest processes re-transforming
the same changed file into one shared cache at the same moment; not verified.

**The fold gate** (Part 5's `scripts/fold_parked_journal.ail`, on the files rows 3 and 5 write when
`MOTOKO_P4_JOURNAL_OUT_ESC` / `MOTOKO_P4_JOURNAL_OUT_QUIT` are set):

```
MOTOKO_P4_JOURNAL_OUT_ESC=$S/p4-part6-esc.jsonl MOTOKO_P4_JOURNAL_OUT_QUIT=$S/p4-part6-quit.jsonl \
  bun node_modules/.bin/jest src/runtime-process.wake.test.ts                         # src/tui
ailang run --caps IO,FS,Env --entry main scripts/fold_parked_journal.ail -- $S/p4-part6-esc.jsonl
  3 entr(ies), 0 undecodable line(s)
  leaf                 0002
NOT PARKED  last=open:wake:aborted
ailang run --caps IO,FS,Env --entry main scripts/fold_parked_journal.ail -- $S/p4-part6-quit.jsonl
  3 entr(ies), 0 undecodable line(s)
  leaf                 0002
  last                 parked
  park.request_id      s.r0.1.p1        park.step 3        park.waits 1
PARKED(p, None)      -- no wake: re-observed on resume
```

The ESC file is `header` (`0000`), `park` (`0001`), `wake` (`0002`, parent `0001`, `wait_id "abort"`,
`outcome "aborted"`, `detail ""`): the fold CLOSES the park (P4-Q4), so the next prompt's `--resume`
opens no run and reads the prompt as the next turn. The quit file is `header`, `park`, `exit`
(`0002`, parent `0001`, reason `host_exit`): row 5's shape, `Parked(p, None)`, re-observed on resume.

| test (one per row of the Part 6 table) | what it pins |
|---|---|
| row 1: the waiter replies `settled` / `lost` / `timed_out` / `host_error` | four suspensions, one per outcome: `header, park, wake` with `wake == { request_id, wait_id, outcome, detail }` and `parent_id == park.id`; one respawn with `--resume <journal>` and `canResume` true; the waiter cancelled once; afterwards `isClosed` false and `abortSuspendedChild(…, "abort")` → false, nothing written (the park is answered, not cancelled) |
| row 2: a line at the parked prompt | `deliver(operator_input)` → `wake(operator_input, "go on")`, the park's child, one respawn, one cancel; then `interruptRuntime(rp, { owner, journal })` → `"none"`, `isClosed` false, `header, park, wake` unchanged — the two typed-input rows differ by entry condition alone |
| row 3: ESC | the owner cleared first (`stillCurrent` false), then `interruptRuntime(rp, { owner, journal })` → `"wake_aborted"`; `header, park, wake`, `wake == { request_id: RID, wait_id: "abort", outcome: "aborted", detail: "" }`, `parent_id == park.id`, `currentLeaf == wake.id`; `isClosed` true, one cancel, `waiter.finished`; **0 respawns**; a second ESC → `"none"`, the waiter's late reply and a typed line dropped (`reply` null), nothing written; `interruptRuntime(rp)` with no owner → `"kill"` (a dead child ignores it), nothing written; `canResume` true and the host's respawn, called as `onInitialTask` calls it, carries `--resume <journal>` with `header, park, wake` on disk |
| row 4: `restart` to profile `q` | `abortSuspendedChild(owner, journal, "restart:q")` → true; `wake == { wait_id: "restart:q", outcome: "aborted", detail: "" }`, the park's child; `isClosed`, one cancel; Part 5's consumer's respawn **never** called; the host's respawn on the new profile carries `--profile q` and `--resume <journal>`, no `--resume-force`, with `header, park, wake` on disk; the delegate settling afterwards is dropped |
| row 5: quit | `close()` → true, one cancel, `header, park` unchanged; then the lease hook's `exit` listener (`registerLeaseHooks` against a fake emitter, a real lease on the journal's dir): `header, park, exit`, `exit.reason == "host_exit"`, `exit.parent_id == park.id`; **no `wake`**; 0 respawns; `canResume` true; a waiter reply and a typed line afterwards write nothing |
| row 6: host death | SIGINT → `exit(abort)`, SIGTERM → `exit(host_exit)`, each after the park, a consecutive `exit` suppressed; no `wake`; 0 respawns; `canResume` true |
| `herdr-agent-state.test.ts` | the exhaustive map: `parked` and `suspended_child` → `blocked`, `resuming` → `working`; both parks carry a message beginning `parked`, only the dead-child one says the runtime exited, and they differ; `resuming` carries none |

**Anchors at `44c7a3a`.** `runtime-process.ts`: `interruptRuntime` `:197` (the suspended-child case
first); `SuspendedChild` `:671`, the `closed` guard in `deliver` `:693`, `isClosed` `:700`, `close`
`:712`; the state table `:799–828`; `SuspendedChildAbort` `:830`; `abortSuspendedChild` `:850`.
`ui.ts`: `RunState` `:807`; `isWaitingState` `:1803`; the ESC guard `:2200`; `session_resumed`
leaving `resuming` `:2853`; `wake_request` / `wake_received` `:2895` / `:2899`; `showSuspendedChild`'s
state `:4149`; `showResuming` `:4165`; the footer colours `:4441`. `index.ts`: the import `:26`;
`ui.showResuming()` in Part 5's `notify` `:1193`; quit's `suspendedChild?.close()` `:1350`;
`onInterrupt` `:1365` (the wake `:1370`); `onRestart` `:1385` (the wake `:1399`).
`herdr-agent-state.ts`: `MotokoRunState` `:43`; the three cases `:118–123`. The test: the shared
harness `runtime-process.wake.test.ts:415–503` (`suspend(sessionId)` `:442`, `resumeRespawn(journal,
profile)` `:480`), the Part 6 block `:635–842` (`installAsHost` `:637`, `FakeProc` `:645`,
`leaseHooks` `:659`, the rows `:668`, `:694`, `:716`, `:763`, `:792`, `:821`).

**The sweep at the branch point (§0.1), disclosed.** Not run for this part (foreground `make dst`
is outside the worker's scope, and this part touches no `src/core` file). The standing record is
Part 3's.

**Judgment calls, stated.**
1. **The three states are `RunState` members, not a separate type.** `parked`, `suspended_child`
   (the plan's `suspended-child`, in the union's spelling) and `resuming` join the one union ui.ts
   and `herdr-agent-state.ts` share, so herdr's exhaustive `mapRunState` makes an omitted mapping a
   compile error, as it did for `suspended` and `done`. They are distinct from `suspended` (ADR-003
   D2's step budget): a parked run holds nothing exhausted, and its next line answers the park, not
   the run. The table itself lives in `runtime-process.ts` as the Part 6 block's header.
2. **Both parks report `blocked` to herdr, `resuming` reports `working`.** The reason `suspended`
   is `blocked`: the run is stopped and waiting on something outside this process (its delegates,
   or a line at the parked prompt), and no model call is in flight — `working` would be a lie and
   `idle` would say nothing is held. The two messages differ in the one fact herdr cannot see,
   whether the runtime child is alive. `resuming` spins: a respawned child is folding the journal.
3. **`SuspendedChild.close()` is how the waiter ends on the cancelling rows**, the item Part 5's
   judgment call 3 left here. It refuses — and does nothing — when the owner already accepted a
   reply: the park is answered and Part 5's consumer owns what follows, so a cancel after a reply
   cannot write a second wake behind the first. Quit closes the owner too: the journal sees nothing
   of it (the row's "none"), but without it a herdr poll would outlive the process. Host death by a
   signal cannot close anything, and the row does not ask it to.
4. **ESC stays one decision.** `interruptRuntime` takes the suspended-child as its first case, so
   the three things ESC can do — cancel a suspended park in the journal, abort a live park over
   stdin, kill anything else — are one function the test drives, and index.ts's handler is a guard
   around it. `interrupted` is not set on the suspended-child row: no child exits on it, and the
   flag would have mislabelled the next real exit's `journalExitReason`.
5. **The owner is cleared BEFORE the cancel, on both rows.** Part 5's consumer is guarded on
   `stillCurrent`, so clearing `suspendedChild` first means a reply racing the cancel can neither
   write a wake nor respawn; `close()` then refuses it at the owner as well. Clearing
   `ui.suspendedChild` closes the parked input route, so the line typed after ESC is a task
   (`initial_task` → `onInitialTask` → `--resume`), not an answer to a park that no longer exists.
6. **The `restart` row's `wait_id` names the profile the respawn runs on** (`restart:<newProfile ??
   profile>`), so the entry is self-describing; the respawn is `respawnForRestart` called at once,
   not after the live restart's 100 ms window, since the child is already dead and no prompt can
   race it. `/restart` on a dead child that is NOT a suspended-child stays Part 4's finding (a),
   reported there and outside this row: unchanged.
7. **`resuming` is one added line in Part 5's `notify`**, before the respawn, rather than a change to
   `installSuspendedWake`: the consumer stays as Part 5 left it, and the state is left on the
   resumed child's `session_resumed` (the table's exit), after which the child's own events —
   `session_resume_view`, `session_start`, the wake's `wake_received` — drive the footer as before.
8. **A live `wake_received(aborted)` leaves the state where it was.** The run ends with neither
   `done` nor `error` and the child's exit follows; the exit handler's `interrupted` branch then
   puts the TUI into awaiting a task. Every other outcome goes to `thinking`: the run continues on
   the wake's message.
9. **What the tests cannot reach**, as Part 5 recorded: index.ts's closures (`onInterrupt`,
   `onRestart`, `onAbort`) and ui.ts's transitions. The rows are pinned through the functions those
   closures call, in the order they call them, and the respawn is asserted on the argv a real child
   received. The quit and host-death rows use `registerLeaseHooks` against a fake emitter and a
   real lease, session-lease.test.ts's mechanism.

### P4 Part 5, 2026-09-15: the wake entry as the park's child, and the respawn — red first, then green

Base `b660b55` (P4 Part 4). One commit `ab9c47e` on `arniwesth/013-plan003-and-herdr`, not pushed.
Input as Part 4 left it: the `SuspendedChild` owner holding one reply by `request_id`, with
`onReply` as the attachment point. The red-first record is here and in the commit message, on
Parts 2–4's pattern: the reds were taken in the working tree.

**T1, red at `b660b55`** (only `runtime-process.wake.test.ts` changed: four tests under `the wake
entry and the respawn`): the suite fails to compile — `TS2305: Module './runtime-process.js' has no
exported member 'installSuspendedWake'`, and two `TS7006` that follow from it (the `notify`
callback's parameters). 0 tests run.

**T1′, red in the harness shape** — the surface exported (`WakeJournal`, `SuspendedWakeDeps`,
`installSuspendedWake`) and the consumer installed but doing nothing: 3 of the 4 red, 1 green (the
late-reply control, which pins that nothing happens without a consumer acting). The reds, from
node's jest: journal entry types Expected `["header","park","wake"]`, Received `["header","park"]`,
at each of the three (test `:529`, `:571`, `:594`).

**Green at `ab9c47e`.** `jest src/runtime-process.wake.test.ts` 20/20 (16 + 4 new). `tsc --noEmit
-p src/tui` clean. `bun run test` in `src/tui`: 413/413 tests, 41/46 suites; the five that fail to
LOAD are Part 1's five (`compose-output-validator`, `compose_guard_semiformal`, `env-server`,
`scratchpad/loopback`: depd `callSite.getFileName is not a function` under bun; `test/path-guard`:
the jest worker), and none of them imports this part's files (checked by grep).

**The fold gate** (the plan's fourth gate line; P3 Part 4's shape). `scripts/fold_parked_journal.ail`
(new) reads a journal with the resume path's ambient `readFile`, folds it from its leaf, and prints
the park and the wake that answered it. Run on the file the host test writes when
`MOTOKO_P4_JOURNAL_OUT` is set:

```
MOTOKO_P4_JOURNAL_OUT=$S/p4-part5.jsonl bun node_modules/.bin/jest src/runtime-process.wake.test.ts   # src/tui
ailang run --caps IO,FS,Env --entry main scripts/fold_parked_journal.ail -- $S/p4-part5.jsonl
  3 entr(ies), 0 undecodable line(s)
  leaf                 0002
  last                 parked
  park.request_id      s.r0.1.p1        park.step 3        park.waits 1
  wake.request_id      s.r0.1.p1        wake.wait_id h1    wake.outcome settled    wake.detail answer
PARKED(p, Some(w))   -- the wake answers the park; the resumer consumes it as <R'>.p0
```

The file is `header` (`0000`), `park` (`0001`, parent `0000`), `wake` (`0002`, parent `0001`).
Control, the same file cut to Part 4's shape (`header, park`): `PARKED(p, None) -- no wake:
re-observed on resume`. The header is `writeHeader`'s (empty digests, zeroed `boot`) and the
history is empty — an empty seed is what the test uses to make `canResume` hold — and the fold
accepts both, since `finish_fold` has no empty-history refusal and `system_is_head_prefix([])` is
true; a live journal carries a real chain and folds the same way.

| test | what it pins |
|---|---|
| the waiter's reply | install writes nothing (no reply held); on the reply: journal `header, park, wake`, `wake.parent_id == park.id`, `wake == { request_id: RID, wait_id: h1, outcome: settled, detail: answer }`, `currentLeaf == wake.id`; `notify` called once with `written: true`; the waiter cancelled **once** and `finished`; the respawn called **once**, with `canResume` true and `header, park, wake` on disk at the call; the resumed child's argv (a real second `RuntimeProcess` with `{ journalPath }`, its child a script that writes `"$@"`) carries `--resume` followed by `journal.filePath`, no `--resume-force`, the empty task last; afterwards a second waiter reply, `deliver(settled)` and `deliver(operator_input)` all write nothing and respawn nothing — `deliver` returns false, the leaf stays the wake |
| the operator's line | `deliver(operator_input)` → true; `wake` with `wait_id ""`, `outcome operator_input`, the park's child; respawn once with `--resume`; the delegate's waiter cancelled once; the delegate settling afterwards is dropped, nothing written |
| a reply held before install | Part 4 wrote nothing on it (`header, park`); at install it is consumed once: `wake(settled, early)` as the park's child, one respawn with `--resume <journal>` |
| a reply after a later spawn (`stillCurrent` false) | the owner holds it (`reply` equals it); `header, park` unchanged; no respawn |

**Anchors at `ab9c47e`.** `runtime-process.ts`: `WakeJournal` `:693`; `SuspendedWakeDeps` `:698`;
`installSuspendedWake` `:743` (the `stillCurrent` return `:745`, the cancel `:746`, the record
`:747–754`, the respawn `:756`). `index.ts`: the import `:26`; the install in the first branch
`:1180–1194` (`stillCurrent: () => suspendedChild === suspended` `:1181`, `respawn:
respawnForRestart` `:1183`); `respawnForRestart` `:1305`. The test block:
`runtime-process.wake.test.ts:415–614` (`suspend` `:445`, `resumeRespawn` `:482`, the four tests
`:511`, `:563`, `:584`, `:601`). The script: `scripts/fold_parked_journal.ail` (126 lines).

**The sweep at the branch point (§0.1), disclosed.** Not run for this part (foreground `make dst`
is outside the worker's scope, and this part touches no `src/core` file; the new script is under
`scripts/`, not a DST target). The standing record is Part 3's.

**Judgment calls, stated.**
1. **The consumer is a free function beside the owner, not a method on it.** `installSuspendedWake`
   takes the owner and what the host lends it (`stillCurrent`, the journal narrowed to `record`,
   `respawn`, `notify`), so Part 4's `SuspendedChild` is unchanged and the test drives the same
   function index.ts calls, with a real respawn in place of `respawnForRestart`. What the test
   cannot reach is `respawnForRestart` itself (a closure in `main`); it is P3 Part 5's function,
   called by name, and the test's stand-in does what it does on the resume path (checks
   `canResume`, spawns with `{ journalPath }`), asserted on the argv the child received rather
   than on `buildSupervisorArgs` alone.
2. **The waiter is cancelled on consumption.** The plan's Part 5 lists the record and the respawn;
   `sendWakeReply`'s rule, which the plan says moves with the request, includes `stopWaiter()`
   after accepting a reply. Without it an operator-input wake leaves a herdr-polling waiter alive
   for a request the journal has answered, and the resumed run parks on the same delegates with a
   waiter of its own. Cancel is idempotent on a waiter that already delivered (`flush` cancels
   before `onReady`), so the "waiter replies" row costs nothing. Pinned by the first two tests
   (`cancels() == 1`).
3. **`stillCurrent`, a guard the plan does not name.** The owner outlives the `RuntimeProcess` and
   the consumer closure outlives the suspended-child: every spawn clears `suspendedChild`. A reply
   reaching the old owner after that would, without the guard, append a `wake` behind the new
   child's entries — a wake answering no open park, which the fold refuses at `request_id` — and
   make the session unresumable by typing. So index.ts passes "this owner is still
   `suspendedChild`", and a late reply writes nothing and respawns nothing. Pinned by the fourth
   test. How that reply's waiter is ended is Part 6's (the `restart`/quit rows).
4. **A wake the journal could not append still respawns.** `record` returns 0 and `onError` has
   reported it; the child then folds `Parked(p, None)` and re-observes the park (row 5) — the
   reply is lost, the session is not. `notify` says so in red. Not tested: `SessionJournal`'s
   append failure is a filesystem fault the harness would have to inject.
5. **No UI state beyond one history line.** `awaitingTask` is not set (the restart path sets it
   because a restarted child idles on stdin; a wake-resumed child runs the wake's turn, and its
   `session_resumed`/`session_start` drive the status). A parked or resuming footer state is Part
   6's, as Part 4 recorded.
6. **The fold gate runs by hand, as P3 Part 4's did.** The host test copies its journal to
   `MOTOKO_P4_JOURNAL_OUT` when set, and the script folds it; the numbers above are from that run.
   Wiring `ailang` into jest would make the unit suite depend on the toolchain, which no other TUI
   test does.

**Part 7's T0, observed in passing.** The test's session directory holds `journal.jsonl` only
(the harness takes no lease); `git grep -n -i -E 'WakeGeneration|wake_generation|wake-file'` over
`src/core` and `src/tui/src` finds nothing. Part 7 records it.

### P4 Part 4, 2026-09-15: the suspended-child branch — red first, then green

Base `2c0fa52` (P4 Part 3). One commit `b660b55` on `arniwesth/013-plan003-and-herdr`, not pushed.
P4-Q3 as decided: host `kill()` once the `park` entry is on disk; every first-issue park exits; TTY
only; the non-TTY callback unchanged; no core-side exit. P4-Q1: Parts 4–7 proceed on W4 gate 8's
live parked run. The red-first record is here and in the commit message, on Parts 2 and 3's
pattern: the reds were taken in the working tree.

**T1, red at `2c0fa52`** (only `runtime-process.wake.test.ts` changed: five tests under
`suspended-child under --park-exits`): the suite fails to compile — `TS2305: Module
'./runtime-process.js' has no exported member 'SuspendedChild'`; `TS2339: Property
'suspendedChild' does not exist on type 'RuntimeProcess'`; `TS2554: Expected 11-13 arguments, but
got 14` (the trailing `parkExits`). 0 tests run.

**T1′, red in the harness shape** — the flag reaching `RuntimeProcess`, the kill on a first issue,
the `SuspendedChild` owner and the R5 drop rule in place, the exit handler still `resolvePark()`
(the plan's `:769`): 3 of the 5 red, 2 green (the abort-inside-onEvent guard and the flag-off
control, which pin HEAD's behaviour). The reds, from node's jest (bun's swallows the diffs):
`expect(rec.cancels()).toBe(0)` — Expected 0, Received 1 (the waiter cancelled at the exit
handler; test `:324`); journal entry types Expected `["header","park"]`, Received
`["header","park","exit"]` (the mirrored TTY callback wrote `exit` after the park; `:363`);
`TypeError: Cannot read properties of null (reading 'deliver')` (no owner; `:374`).

**Green at `b660b55`.** `jest src/runtime-process.wake.test.ts` 16/16 (11 + 5 new). `tsc --noEmit
-p src/tui` clean. `bun run test` in `src/tui`: 409/409 tests, 41/46 suites; the five that fail to
LOAD are Part 1's five (`compose-output-validator`, `compose_guard_semiformal`, `env-server`,
`scratchpad/loopback`: express → body-parser → depd `callSite.getFileName is not a function` under
bun 1.4.2; `test/path-guard`: a jest worker crash). Their imports are `env-server.js`,
`loopback.js`, `node:path` and `express`; none reaches this part's files.

| test | what it pins |
|---|---|
| first issue → kill → exit | events `park_entered, wake_request`, no `error`; `isParked` true inside onEvent (forwarded before the kill); stdin log empty (the child read nothing); one waiter started, **0 cancels**, `waiter.finished` false; `suspendedChild.request.request_id == RID`, its `reply` null; `wakeRequest` null, `isParked` false, `restartPending` undefined; journal `header, park`, the park's `id == currentLeaf` |
| kill-then-reply (R5) | a reply delivered in a microtask after `onWakeRequest` returned — `isDead` still false — through the waiter's callback and through `sendWakeReply` (→ false): stdin empty, journal `header, park`, the owner's `reply` null, no restart pending, 0 cancels |
| post-exit reply | a stale id → false; the waiter's callback reaches the owner (`reply` equals it); a second → false; `sendWakeReply` on the dead process → false; `onReply` installed afterwards receives the held reply once; journal still `header, park` |
| abort from inside onEvent, flag on | `interruptRuntime` → `abort` down stdin, the child exits itself; 1 cancel; `suspendedChild` null; journal `header, park, exit` |
| control, flag off | 1 cancel; `suspendedChild` null; `header, park, exit` with reason `child_exit` |

**Anchors at `b660b55`.** `runtime-process.ts`: `SuspendedChild` `:657`; the exit branch
`:811–829` (`if (this.suspending !== null && this.waiter !== null)` at `:814`); the
`suspendedChild` getter `:1053`; `onWakeRequest` `:1067` (the kill at its end); `onWaiterReply`
`:1094`; the R5 rule in `sendWakeReply` `:1111`. `index.ts`: `--park-exits` `:666`; `let
suspendedChild` `:896`; the non-TTY notice `:982`; the first branch `:1168–1173`; the TTY spawn's
flag `:1264`. `ui.ts`: `showSuspendedChild` `:4117`; the route's request id `:4144`; the owner
delivery `:4154`. The test block: `runtime-process.wake.test.ts:249–413`.

**The sweep at the branch point (§0.1), disclosed.** Not run for this part (foreground `make dst`
is outside the worker's scope, and this part touches no `src/core` file). The standing record is
Part 3's.

**Judgment calls, stated.**
1. The kill comes AFTER the `wake_request` is forwarded, and is guarded on the park still being
   tracked (`outstandingWake === req`, a live waiter): a consumer that aborts from inside `onEvent`
   (ESC) has cancelled the park, and that exit stays the ordinary one. Pinned by the fourth test.
2. The R5 window DROPS the reply rather than holding it for the owner, as the plan states it ("the
   request died with the child"). With the real waiter a reply also finishes the handle
   (`startWakeWaiter`'s `flush` cancels before `onReady`), so the owner then holds a finished
   waiter and no reply; the park is re-observed on the next resume, which is Part 5's respawn or
   the operator's line or restart. A delegate's answer landing in that window is therefore not
   acted on until then. The plan's decision, recorded.
3. `SuspendedChild` holds one reply by `request_id` and takes a consumer through `onReply`, handing
   over a reply held before the consumer was installed. That is the surface Part 5 attaches to
   (write the `wake`, respawn). Part 4 installs no consumer, so under the flag an answer or a typed
   line is held and nothing else happens; the flag is off by default and Part 7's live gate is what
   turns it on.
4. The UI's run state is left where the park left it: a live park shows the same today, and the
   two existing alternatives reach herdr with the wrong meaning (`suspended` maps to `blocked` with
   the step-budget message; `idle` says nothing is held). A parked footer state, live or suspended,
   is a UI item for Part 6 or later, not this branch's.
5. The parked input route stays open by reading the owner's request id when no child holds one;
   with no child the line is delivered to the owner (`operator_input`, once). `awaitingTask` is
   not set, so a plain line is not a new task, which would have resumed through `onInitialTask`
   and re-observed the park instead of answering it.
6. A `kill()`ed child that manages to emit a park-ending event (`error`, `done`) before it dies
   resolves the park in the line handler as today; at exit the waiter is gone, the branch is not
   taken, and the exit is the ordinary explained one. Not tested: the AILANG runtime does not do
   this on SIGTERM in the ESC path today.

**Two findings, reported, not repaired.** (a) `/restart` on a dead child is a no-op:
`RuntimeProcess.restart()` returns on `dead`, and `ui.onRestart` only falls back to
`respawnForRestart()` when `runtimeProcess` is undefined, which it never is after a spawn. Under
suspended-child that is Part 6's `restart` row; it also holds for any exited child at HEAD.
(b) bun's jest prints no `expect` diff for a failing assertion (`@ processTicksAndRejections@`);
node's jest under `--experimental-vm-modules` prints them, and T1′'s numbers come from there.

### P4 Part 3, 2026-09-15: the resumer — red first, then green

Base `97265c2` (P4 Part 2). One commit `2c0fa52` on `arniwesth/013-plan003-and-herdr`, not pushed.
P4-Q2 **option (a)**, as decided: `<R'>.p0` is consumed in the resumed frame, before the run
(§8.4, R9, W5(b)). The red-first record is here and in the commit message, on Part 2's pattern:
the reds were taken in the working tree with the gate files present and `session.ail` at the
stated state, not as separate commits.

**T1, red at `97265c2`** (`park_resume_dst.ail` and `run_park_resume.sh` landed, `session.ail`
untouched): `make park_resume` fails to compile the script — `Error: type error in
scripts/dst/park_resume_dst (decl 44): undefined variable: Session at
scripts/dst/park_resume_dst.ail:375:11`, the harness entry's call — exit 1, no frames, 52 s, did
not hang.

**T1′, red against HEAD's behaviour in the harness shape.** A stub
`run_v2_session_park_resumed_traced` that emits `SessionResumed` and returns the folded history
between turns — exactly what `run_v2_resume_with_conversation` did for a `Parked` boundary at
`97265c2` — makes 20 of the 25 resume assertions red across the five resume rows: `parks=`,
`wakes=` and `seen=` (no `WakeIdentity`) empty; `order=SessionResumed|`; `drops=1 warnings=0`;
and the two-frame journal folding to **`open:resumed`** — the `resumed` entry moves `last` off
the park, so at HEAD a resume of a parked journal silently dropped the park. The fold/plan rows
(three truncations → `parked`; the untruncated control → `run_finished`) and Part 2's row are
green at both reds, as designed: they are Part 1's fold, the precondition.

**Green at `2c0fa52`.** `make park_resume` PASS: 7 rows, every assertion, every shell check.

| row | what it pins |
|---|---|
| fold/plan | after `park_entered` → `Parked(w4.r0.0.p0 [h1], None)`; after `wake_received` → `Parked(p, Some(w))`; `park, exit` (host-shaped `exit`, reason `child_exit`) → `Parked(p, None)`; untruncated → `run_finished` |
| `resume_after_wake` (recording ports) | `SessionResumed` first and once; `ParkEntered w4.r1.0.p0` at step 0 on [h1] before any run; exactly one `WakeReceived` for `w4.r1.0.p0`, settled on h1 with the child's detail; `WakeIdentity("loop_v2", "w4.r1.0.p0", "h1")` **`ok`** (served from the cursor), then `w4.r1.0.p1`; the run's own park `w4.r1.0.p1` on [h2] (`initial_park_ordinal(true)`); the model told to call `DelegateCheck` once, run Ok, `done=final answer`; one `SessionStart`, two `wake_read` witnesses; two-frame journal: `run_started(w4.r1.0)` **after** `wake(w4.r1.0.p0)`, refolds to `run_finished` and plans, folded history == the run's final history |
| `resume_after_park` (scripted) | no wake child → nothing seeded → the world's cursor answers the re-observation (`settled`, `late answer`); run opens, parks at `w4.r1.0.p1`, ends Ok; refold not `Parked` |
| `resume_park_exit` (scripted, empty cursor) | T2's re-observation: `WakeReceived w4.r1.0.p0 host_error "wake_read unbound"` with `wait_id ""`; waits **kept** — next park `w4.r1.0.p1` still on [h1]; the model told the host could not observe; refold not `Parked` |
| `resume_aborted` | `WakeReceived(aborted, "abort")`, **no run** (no `SessionStart`, `HistorySeeded`, `ProviderCallPrepared`, `RunSummary`; one `wake_read` witness); the frame returns the folded history, not suspended; two-frame journal folds to `open:wake:aborted` |
| `resume_dropped` | one `ParkEntered w4.r1.0.p0`, no `WakeReceived`, no run, the cursor element consumed; folded history returned; two-frame journal keeps `Parked(w4.r1.0.p0, None)` for the next resume; shell: `drops=1 warnings=1`, no `wake_received` on the wire |
| wire (shell) | `live_cursor`: 0 `wake_request` lines (Part 2); `resume_after_wake`: exactly one `wake_received` for `w4.r1.0.p0` and one `session_start` for `w4.r1.0`, **in that order**; `resume_aborted`: no `session_start`; no `error` event in the abort/dropped frames |

**Also green at `2c0fa52`.** `ailang test src/core/session.ail` 40/40 (38 + 2 new:
`test_p4_parked_cursor_rewrites_only_the_request_id_at_the_head`,
`test_p4_state_from_parked_applies_the_wake_and_parks_at_p1`); W5's tests byte-identical (`git
diff` touches no `test_w5_` line), moved `:5867–5897` → `:6141–6171` by the resumer block above
them. `make park_wake` PASS, 17 fixtures. `make journal_resume` PASS rows=13. `make ledger_parity`
wire gate PASS. `make world_framed_wire` selftest + gate PASS. `make driver_leaf_inventory`: **26
sites** (25 + `session.ail:5514 ports.wake_read WakeRead clean [consume_parked_wake]`), WakeRead=2,
0 unresolved, 0 out of order. `make driver_leaf_inventory_selftest`: 0 failures, with the new
`TREE_MUTANTS` entry `resumer wake_read successor not witnessed` → `advanced-unwitnessed` and the
unmutated tree 26 leaves clean. `make anchors` 10/10, **no move and no re-baseline**: every edit
above `:4523` is line-neutral (three names joined onto the journal import line, `wake_outcome_of`
onto the ports import line, `initial_park_ordinal`'s two comment lines re-tensed, `C2Seed`'s third
variant and its match arm on their existing lines); everything else sits below
`run_v2_session_resumed_traced`. `ailang check src/core/rpc.ail` clean. The recording sites the
plan said to confirm at run time are `stub_step.ail:635–640` (`recording_ports`, `wake_read:
recording_wake`) and `:737` (`generating_ports`).

**The sweep at the branch point (§0.1), disclosed.** Not run for this part (foreground `make dst`
is outside the worker's scope). The standing record is `.ailang/post-pindh-sweep.out` at `d5edebf`
(2026-09-14 17:45 UTC): exit 2, `FAILED (1): depth_canary` known-red, `NOTE` lines that
`driver_plus_herdr` and `herdr_graded` PASSED while listed, `driver leaf inventory (25 sites…)`,
`journal_resume PASS rows=13`. Between `d5edebf` and `2c0fa52` only P4 Parts 1–3 landed, each with
its own gates.

**Judgment calls, stated.**
1. The harness entry takes `session_id: string`, not a `RunIdentity`: `<R'>.p0` and `R'` must be
   one construction, so both are built from `(session_id, plan.profile, plan.info.resume_count,
   0)` — `between_turn_request_id` and `loop_run_identity` over the same four inputs.
2. The rewritten observation goes to the **head** of `wakes` (`seeded :: world.wakes`) rather
   than replacing the list: identical for the live world (empty cursor); a DST world keeps the
   observations for the resumed run's own parks (`resume_after_wake` serves `w4.r1.0.p1` from it).
3. The no-run arms (`Aborted`, dropped) return the frame alone as a `TracedSessionResult`:
   `Ok(plan.history)`, `suspended: None`, `final` the folded state. The live entry enters the loop
   between turns with `suspended: None` and `run_ordinal` 0 — no traced run happened (D5).
4. `SessionStart(R')` is emitted **and appended** by the run-opening path: it is the `run_started`
   the `user_message` arm emits for every other run, and without it the fold would re-offer the
   wake on the next resume. Journal order: `park, wake, run_started, history_appended(wake
   message)`, then the run's seed, dropped by D1's arm 3.
5. `nudges_used` is re-derived with `count_persist_nudges(plan.history)`, as `plan_resume` does for
   a suspended boundary.
6. `wake_outcome_of`'s `None` arm (unreachable past the fold, which refuses an outcome outside the
   six) seeds nothing — the re-observation path — rather than a fabricated outcome.

**Two findings, reported, not repaired.** (a) The fold's `resumed` arm moves `last` off a
`Parked` boundary (`journal.ail`, `BoundaryOpen("resumed")`). A child that writes `resumed` and
dies before `park(<R'>.p0)` — two consecutive emits in `run_v2_resume_with_conversation` — leaves
a journal that folds to `open:resumed`, and the prior park with its wake is not re-offered. Same
class as P4-Q4's `exit` rule; it is a fold rule of Part 1, not Part 3's. (b) Every `ailang`
invocation warns `dependency sunholo/motoko_ext_progress_contract_guard content changed … Run
'ailang lock'`; not run, the lock is not Part 3's.

### P4 Part 1, 2026-09-14: the park and wake entries — red first, then green

Base `6e2e13c` (= `d5edebf` + one docs-only commit, `RESEARCH-harness-playbook-implications.md`;
nothing under `src/` differs, and every Part 1 anchor holds verbatim). Red commit `3e9b8e3`
(tests only), green commit `686da16`, both on `arniwesth/013-plan003-and-herdr`, neither pushed.

**T1, red at `6e2e13c`.** `ailang test src/core/journal.ail`: 32 tests, 29 passed, 3 failed.
jest `src/session-journal.test.ts`: 44 tests, 42 passed, 2 failed.

| # | test | red because |
|---|---|---|
| 1 | `test_the_twin_writes_one_entry_per_message`: `List.length(all_entry_types()) == 12` | the set held ten |
| 2 | `test_a_journal_ending_in_a_park_folds_to_parked` (new; a host-shaped `park` line, built as `t_exit_line` is) | refused `Entry(seq, "type=park")` at the unknown-type arm. The old unknown-type row's mutation moved to `not_an_entry` and stayed green (W3 flip 2's pattern) |
| 3 | `test_the_twin_writes_park_then_wake` (new) | `twin_event`'s `_ => acc` dropped both lines |
| 4 | `session-journal.test.ts` "knows exactly which events are journal-class" (flipped) and "journals a park and its wake, the wake as the park's child" (new; asserts `wake.parent_id == park.id`) | `record()` returned 0 for both types |

**T1, green at `686da16`.** `ailang test src/core/journal.ail` 32/32; jest 44/44; `tsc --noEmit`
clean. Fold fixtures, all in `test_a_journal_ending_in_a_park_folds_to_parked`: park →
`Parked(p, None)` with the waits read back `h1,op`; park,wake → `Parked(p, Some(w))`;
park,wake,run_started → `open:run_started`; park,exit → `Parked(p, None)`; park,wake,exit →
`Parked(p, Some(w))`; park,wake(aborted) → `open:wake:aborted`; a wake for another request, a
wake with no park, a second wake → `Entry(seq, "request_id")`; a non-descriptor `waits` element
and an empty `waits` → `Entry(seq, "waits")`; an outcome outside the six → `Entry(seq, "outcome")`;
a missing `step` → `Entry(seq, "step")`; `plan_resume` of a parked session: `suspended` `None`,
`boundary` `"parked"` in `resume_view_json`. The twin test also pins the twin's `waits` bytes equal
to the host-shaped bytes, and folds the twin's journal to the answered park.

**T2, unchanged and green at `686da16`.** `make journal_resume` PASS rows=13, `SessionResumed`
projected 2 == returned 2. `make stream_parity` PASS, the `JournalFold` family clean over the
real run, wire 14 == trace 14. `make park_wake` PASS, 17 fixtures. `make event_vocabulary`:
45 `LedgerEvent` variants == 45 rows == 45 goldens, unchanged — no new `LedgerEvent`, so
`event_vocabulary_version()` does not move. `ailang check` on `rpc.ail`, `dst_invariants.ail`
and `scripts/fold_live_journal.ail` clean. No `session.ail` edit; `ParkEnteredInfo` and its
golden untouched (P4-Q6).

**Two findings, reported, not repaired.** (a) `bun run test` in `src/tui`: 404/404 tests pass,
but five suites fail to LOAD, identically with Part 1's files reverted to base:
`compose-output-validator`, `compose_guard_semiformal`, `env-server` and `scratchpad/loopback`
die in express → body-parser → depd with `callSite.getFileName is not a function` under bun
1.4.2; `test/path-guard` is a jest worker crash. None imports the journal, the logger or
`runtime-process`. (b) Every `ailang` invocation warns `dependency
sunholo/motoko_ext_progress_contract_guard content changed … Run 'ailang lock'`; not run, the
lock is not Part 1's.

**One judgment call, stated.** An empty `waits` list is refused at `waits`, beside the
non-descriptor element the plan named: ADR-002 D2 makes the park the request's open waits, and
`dst_invariants.park_payload_step` refuses an empty list on the wire, so the fold agrees with the
wire rather than accepting a park with nothing to wait for.

### P3 Part 6, 2026-09-12: the eval-harness finding, and the loggers' exit

**The finding (QEVAL, answered by code reading and re-read for this part): the external eval
harness KEYS ON THE WIRE `error`.** `benchmarks/motoko_rpc.py:213–216` ends
`MotokoRpc.run_and_collect`'s drain on `t == "error"` and sets `terminal_event = "error"`
(the other terminal is `done`, `:207–212`); `benchmarks/tb_adapter/motoko_agent.py:217` maps that
to `FailureMode.UNKNOWN_AGENT_ERROR`; `benchmarks/aider_polyglot.py:229`, `:274`, `:380` and
`benchmarks/smoke.py:58` branch on `terminal_event == "error"`. The harness launches the TUI in
non-TTY JSONL mode (`MOTOKO_JSONL_OUTPUT=1`, `node src/tui/dist/index.js`, `motoko_rpc.py:66–91`),
which is exactly the headless path whose `error` Part 6 was to remove. Without it, a
budget-exhausted benchmark run would emit `run_suspended`, `run_summary` and nothing the drain
ends on, and would fall through to process exit with `terminal_event = ""`: neither done nor
error, a silent misclassification. (`env-server.ts`, the in-tree consumer the plan checked, still
has no wire `error` consumer. The finding is the external one.)

**So by Open question 7's own rule the removal did not land.** The headless `error` after
`run_suspended` (`session.ail`, the initial-run arm of the conversation entry) is kept as a
compatibility surface, and its comment now says why. ADR-003's Consequences carries the line. What
Part 6 did land:

- `headless-outcome.ts` (`HeadlessOutcome`, tested): the plain and JSON loggers put
  `run_suspended`'s reason on stderr and record a non-zero exit (1). They do NOT exit on the
  record itself, because `run_summary` and the kept `error` follow it on the same stdout. The
  `error` arm exits 1 as before, and `stop()`, called after the session log drains on runtime
  exit, exits non-zero if the run suspended or was refused a resume with no `error` to exit on.
- `session_resume_view` is rendered by the plain logger as D6's marker line.
  `session_resume_refused` goes to stderr in both loggers, beside exit 3.
- The non-TTY path no longer defers `run_suspended` behind `logger.flush()`. P1 Part 6 drained it
  against a `process.exit` that no logger takes on that record, and the deferral let the
  synchronous `run_summary` reach the JSON logger's stdout before it. The record now goes over
  synchronously, and the runtime-exit callback calls `ui.stop()` after `logger.close()` resolves.

**Live readings, through the harness's own entry point** (`node src/tui/dist/index.js`, non-TTY,
`MOTOKO_JSONL_OUTPUT=1`, `openrouter/anthropic/claude-haiku-4.5`, a scratch profile):

    budget (max_steps 3): exit=1  stdout order = run_suspended, run_summary, error
      run_suspended(….r0.0, budget_exhausted, step 3)  run_summary(max_steps, 3)  error(StepBudgetExhausted)
      stderr: [suspended] budget_exhausted at step 3 (run ….r0.0): headless has no operator to continue it, …
    normal (max_steps 10): exit=0  stdout order = run_summary, done   error events = 0   stderr reason lines = 0
    MotokoRpc.run_and_collect on the budget run: terminal_event='error' error_message='step budget exhausted'

**The first judging number, re-read at this part: `scripts/probe_budget_continue.sh` 7/7**
(exhausted payloads `[2, 4, 6, 8, 10]`, resumed `[13, 15, 17, 19]`, first resumed
`msg_count` 13 == 12 + 1, one session id). Its first run at this tree read **3/6, and that was
the judge, not the product**. P3 Part 5 made the conversation loop emit the first run's
`SessionStart` with its `run_id` beside `rpc.ail`'s banner, which has none, and the judge split
runs on every `session_start`. It therefore saw three runs, the first of them empty. The judge
now splits only on a `session_start` that names a run, which is the host journal's rule. The same
kept capture replays 3/6 through HEAD's judge and 7/7 through the fixed one. P3 Part 5 did not
run the probe, so it did not see this.

**The sweep before P3G, run to completion: `make dst DST_JOBS=4`, 725 s, exit 2, three reds.**
P3 Part 5's sweep died before its summary, so this is the first full reading since Part 3.
`depth_canary` is the known red (Open question 9). `herdr_graded` and `driver_plus_herdr`
(one script, `herdr_graded_dst.ail`) are red for two reasons, and neither is Part 6's.
(i) **Ambient:** run inside a herdr delegate pane, the unset `HERDR_DELEGATE_DEPTH` made the
scripted Delegate refuse, so the run recorded 1 extension effect of 9. With every `HERDR_*`
unset, the run's eight clauses are green. (ii) **A stale profile pin:** `driver_plus_herdr`
records attribution table `(c0fbf10, sha256:eba3f47…)` against a live `sha256:2c86584…`, with
`tool_phase.ail:318` unaccounted. A clean worktree at `845239c` reads the identical pair, so the
pin predates this part. Its disposition is a D4 profile re-issue and is the owner's call; it is
not taken here. Every other target passed.

### P3 Part 3, 2026-09-12: Open question 3's bytes-per-turn, and the `JournalFold` first green

**Open question 3 is decided "always carry" and the bill is measured, not estimated.**
`HistorySeeded` carries the run's whole starting history on stdout, once per traced run. The
probe (§0.6, `scripts/probe_budget_continue.sh`) is the plan's instrument for this and it was
NOT RUN at this part — it needs a live provider key and this commit changes nothing the probe
asserts — so the number below is measured from the DST wire instead, which is the same
`ledger_emit` writing the same line to the same stdout, and the substitution is stated here
rather than in a footnote.

| fixture | traced runs | `history_seeded` bytes | mean/run | max/run | share of the run's whole wire |
|---|---|---|---|---|---|
| `ledger_parity_dst` (short histories, 2–6 messages) | 8 | 2 384 | 298 | 298 | 5.7 % |
| `long_qwen_compaction_dst` (compaction fixture, long histories) | 11 | 2 301 545 | **209 231** | **1 050 218** | **87.3 %** |

`history_appended` for comparison: 112 events, 99 978 bytes, **mean 892 bytes per message** on
the same long fixture. So the steady-state cost of the journal is ~0.9 KB per message and the
seed is ~200 KB per turn at that history length, because each turn re-sends the whole
conversation. **That 87 % is the price of "always carry", and it is the number the env-gated
digest-only variant has to be argued against** — the trace must always carry the messages or
`JournalFold` has nothing to fold, so the variant can only ever drop them from *stdout*, and
the host would then be unable to journal a session's first run at all without them. Not this
part's, and now priced.

Two consequences the host side inherits, recorded here because they are P3 Part 4's inputs:
the JSONL log under `.motoko/logfile/` carries these payloads verbatim until Part 4 lands D3's
digest-substitution rule (the logger writes unknown types verbatim,
`runtime-process.unknown-events.test.ts`), so a live session's log grows by the same ~87 %
in the interval; and the seed line itself is a single ~1 MB stdout write at the top end,
which the host's line reader has never had to hold before.

**`JournalFold` is green on every fixture `make dst` reaches it on**, which is P3 Part 2's red
closed by the emits and nothing else — `expected_family_rules` in `stream_parity_dst.ail` is
untouched. The caveat Part 2 recorded stands and is repeated rather than quietly dropped: the
ADR says "every fixture in `make dst`", and `dst_execution.execution_of` has exactly ONE call
site in the tree (`stream_parity_dst.ail`, reached twice), so "every fixture" is still two
executions in one target. Nothing was widened to manufacture a bigger green.

### P1 Part 6, 2026-09-08: the first judging number, and the herdr `blocked` measurement

**The first judging number is GREEN, twice over, in two independent drivers.**

`scripts/probe_budget_continue.sh` against `openrouter/anthropic/claude-haiku-4.5`, profile
`max_steps` 5, two consecutive live runs with identical readings — **6/6 assertions, exit 0**:

    probe: exhausted run payloads = [2, 4, 6, 8, 10]
    probe: resumed   run payloads = [13, 15, 17, 19]
    probe: exhausted run_summary  = finish_reason=max_steps steps_executed=5 error='step budget exhausted'
    probe: resumed   run_summary  = finish_reason=stop steps_executed=4 error=''
      PASS A1 resumed payload carries the exhausted history + 1 — resumed first msg_count=13, expected 13
      PASS A2 exhausted run executed the profile's 5 steps — steps_executed=5
      PASS A2 resumed run_summary counts its own steps — steps_executed=4, provider calls prepared=4
      PASS A2 exhausted run finished on the step budget — finish_reason=max_steps
      PASS A3 exhausted run emits run_suspended immediately before run_summary
      PASS A3 neither run emits an error event — error events = 0

**Before P1** the same probe read `resumed run payloads = [3, 5, 7, 9, 11]` and `FAIL A1 …
resumed first msg_count=3, expected 13` (P1 Part 1's commit message, measured at `cbf50f3`).
The turn's twelve messages died in the driver's `Fail` arm and the operator's `continue`
re-opened the pre-turn history plus one line. They now cross.

**The same number, measured a second way, through the TUI in a real TTY** — the manual check
the Part 6 gate names, taken in a herdr pane (`herdr pane split`, `bun src/tui/src/index.ts`,
profile `max_steps` 3). Three chained runs in ONE session log, from the JSONL the host wrote:

    run 0: payloads=[2, 4, 6]    run_suspended=(…r0.0, budget_exhausted, 3)  summary=(max_steps, 3)  errors=0
    run 1: payloads=[9, 11, 13]  run_suspended=(…r0.1, budget_exhausted, 3)  summary=(max_steps, 3)  errors=0
    run 2: payloads=[16, 18, 20] run_suspended=none                          summary=(stop, 3)       errors=0

Each resume opens on the exhausted history plus one — 8+1 = 9, then 15+1 = 16 — the ordinal
advances `r0.0 → r0.1` (D5's rule, live), `steps_executed` is per run, and no `error` event is
emitted on any of the three. The operator typed `continue` twice as plain input with **no
`/restart`**, and the model's closing summary names `probe-1 through probe-8`: the eight
commands span three runs and it saw all of them.

**The herdr `blocked` measurement**, taken inside the pane during the suspension:

    $ herdr agent get w1:p1G
    {"result":{"agent":{"agent":"motoko","agent_status":"blocked", … "pane_id":"w1:p1G"}}}

with the TUI's own status line reading `[λ] state: suspended | step 2` and, after the last
`continue`, `agent_status` returning to `done` (herdr's name for the idle it reaches after
unseen work). **The message half is NOT readable back over the CLI**: `--message` is accepted
by `herdr pane report-agent` but `agent get`, `agent list` and `pane list` all omit it from
their JSON — it is a display field of herdr's sidebar. The text is therefore pinned by the
exhaustive-list test and by a new assertion on the exact string
(`herdr-agent-state.test.ts`), which is the compile-time half the gate names, and the live
half measured here is the `blocked` state.

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
