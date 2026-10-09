# PLAN: finalize policy leaves core — remove the DP7 verifier, then the persist nudge

Implements **Amendment 1** to [ADR-001](ADR-001-harness-policy-boundary.md) (this dir): A1, A4 and
A6 in workstream W1, A5 in workstream W2.

Status: Proposed
Written against: Amendment 1 as proposed in #249. The amendment is not accepted yet. W1 follows the
operator's ruling of 2026-10-09 that it records.
Pinned toolchain: AILANG **v0.52.5** (`ailang.lock`)
Grounded at: `origin/main` **`36a96b1e`**. Every `file:line` below was read at that commit.
`session.ail` drifts quickly, so re-anchor before editing. `main` has since moved to `38068013`
(#247, #250, #251). Of the files cited by line here, only the `Makefile` changed, by five lines
after `:2819`.

---

## TL;DR

Two workstreams. They share no code and W1 does not wait for W2.

1. **W1 removes the DP7 verifier from core.** Nothing replaces it. Ten work items, one pull
   request. It is ready to start.
2. **W2 removes the persist nudge completely**, its environment read included, and builds no
   guard in its place. The operator decided that on 2026-10-09. It follows W1, because both edit
   `classify_candidate` and `decide`.

### Decisions this plan needs from the operator

| # | Blocks | Question | This plan's recommendation |
|---|---|---|---|
| 1 | W1, WI-8 | 011 ADR-003's `verifier-rejection` control run exists to walk the DP7 branch. Replace it with a control on the solver-feedback branch, or drop it? | Replace. The gate keeps a control for "a final answer is bounced and the model is called again". |
| 2 | W1, WI-6 | A profile that still sets `verification.enabled: true`: refuse to start, or start with a warning? | Refuse. Someone who believes a gate runs has to find out that it does not. |

Decided on 2026-10-09:

| # | Question | The operator's answer |
|---|---|---|
| 3 | Build a persist-nudge guard extension (ADR-001 D4), or delete the persist nudge? | Delete it. It is off by default, so it has not run for a long time. |
| 4 | Keep reading `MOTOKO_PERSIST_RETRIES` as a dead value, or remove the read too? | Remove it in full, the read included. The operator confirmed that after seeing what the read touches. |

---

## Verified state at `36a96b1e`

**The verifier.**

- The whole of DP7's logic is `session.ail:2218-2299`: `FinalizeVerification`,
  `is_missing_infrastructure` (`:2231`), `run_dp7_verifier` (`:2241`), `dp7_gate` (`:2257`, no
  caller), `Dp7Rejection` (`:2285`) and `dp7_rejection_errors` (`:2287`).
- `classify_candidate` (`session.ail:3255-3310`) calls it twice: stage 2 for a non-blank candidate
  (`:3268-3271`) and stage 5 for a blank one the judges approved (`:3298-3305`).
- A rejection becomes `CandidateRejected` (`:3219`), is handled at `:4133-4134`, and builds its
  next state in `c2_dp7_rejected_state` (`:2964`), which sets `last_finish_reason:
  "dp7_rejected"` (`:2997`). An approval goes through `c2_dp7_approved_state` (`:3011`), which
  sets `"dp7_approved"` (`:3045`).
- `decide` reads three reasons: `dp7_rejected` injects `dp7_rejection_message`
  (`step_machine.ail:53-61`, `:130-131`); `dp7_approved` and `dp7_fail_open` finalize or park
  (`:143`, `:149`). `dp7_fail_open` has no producer.
- The reason strings appear nowhere outside `session.ail`, `step_machine.ail` and one scenario
  label in `scripts/dst/park_wake_dst.ail:645`. They are not on the wire: the terminal reason
  table has no DP7 entry (`session.ail:5706-5710`, `phase_vocab.ail:943-946`).
- The wire event is `Dp7VerifierRejected` (`phase_vocab.ail:997`, `:1298`, `:1481`, golden at
  `:1937`), listed in the event vocabulary (`dst_event_vocabulary.ail:105`, `:163`, `:223`,
  `:325`).

**What a removal cannot break.**

- **The session journal never held a rejection.** The journal of the 2026-10-09 session has six
  record kinds: `header`, `run_started`, `history_appended`, `state_delta`, `exit` and `resumed`.
  `dp7_verifier_rejected` is a wire-log event only. Resume is unaffected.
- **The verifier's process call was never recorded.** `run_dp7_verifier` calls `exec` directly,
  not through a port. The 2026-10-09 log has no `world_request` between a final answer and its
  rejection. No recorded run depends on it.
- **Nothing reads an old wire log against the vocabulary.** `event_vocabulary()` has four
  consumers, all DST scripts that check the live sum
  (`scripts/dst/{event_vocabulary,export_vocabulary,fault_catalogue,invariants}_dst.ail`).
- **The contract register has no entry** for any function this plan removes
  (`tools/verify_classify/contracts.register`).

**What stays, on purpose.**

- **`ExtRuntime.verification` and `VerificationConfig` stay in the ABI package**
  (`packages/motoko-ext-abi/types.ail:89`, `:2033-2037`). The package is frozen at 8.0, and a
  changed export at the same version gives two different packages one number. The field is also
  written in a literal in more than forty files. After W1 nothing reads it. Dropping it belongs to
  the next ABI major.
- **The `verification` config block stays.** It also carries `semi_formal`
  (`config.ail:347`, `src/tui/src/config.ts:54`), which is unrelated.
- **The ABI package's comment that lists `dp7_rejected`** (`types.ail:733`) stays for the same
  reason. It goes stale and is noted for the next major.

**The system prompt already asks the model to do the check itself.** `SYSTEM.md:119-128` tells
the model to run `make check_core` before a final answer *if it modified AILANG source in the
session*. Its last sentence says the runtime "will not catch this for you — that gate is on the
roadmap". That has been wrong since May and becomes right again with W1.

---

## W1 — remove the DP7 verifier

Each item names the files, the change, and the `make` target that proves it.

### WI-1 — `classify_candidate` loses its verification stages

`src/core/session.ail`.

- Delete stage 2 (`:3268-3271`) and the verifier run in stage 5 (`:3298-3305`). The function
  becomes: open waits park; otherwise `dispatch_solver_candidate`, then the persist nudge as today,
  then approve.
- Delete `CandidateRejected` (`:3219`) and its arm (`:4133-4134`).
- Drop the parameters only DP7 used. `workdir` is one; check `blank` after the edit.
- Rewrite the stage comment (`:3227-3254`) to the new order. Do not leave "stage 2" numbering
  with a hole in it.

**Gate:** `make check_core`.

### WI-2 — delete the verifier

`src/core/session.ail`.

- Delete `:2218-2299` whole, and `c2_dp7_rejected_state` (`:2964-3010`). The comment above it
  (`:2951`) describes both state builders; keep the half about the approved one.
- Remove `Dp7VerifierRejected` from the import at `:100`. Remove `exec` and `toString` from the
  imports if nothing else in the file uses them.
- `session.ail`'s import region is a protected span of the evaluation's manifest. See *Blast
  radius*, last row.

**Gate:** `make check_core`.

### WI-3 — one neutral name for "the candidate was approved"

`src/core/session.ail`, `src/core/step_machine.ail`.

- Rename `c2_dp7_approved_state` to `c2_candidate_approved_state` and its reason from
  `"dp7_approved"` to `"candidate_approved"`.
- In `decide`: delete `dp7_rejection_message` and the `dp7_rejected` arm; replace
  `dp7_approved` with `candidate_approved` at `:143` and `:149`; delete `dp7_fail_open` from both.
- Tests in `step_machine.ail`: delete `test_decide_dp7_reject_injects_user_message` (`:345`) and
  `test_decide_dp7_fail_open_finalizes` (`:394`); rename the approve test (`:385`); update the
  four table tests at `:534`, `:565`, `:598` and `:610`.

**Gate:** `make test_coverage` (runs every inline test under `src/core`).

### WI-4 — the wire event goes

`src/core/phase_vocab.ail`, `src/core/dst_event_vocabulary.ail`, `src/core/dst_invariants.ail`.

- Delete `Dp7RejectedInfo`, the `Dp7VerifierRejected` variant, its encoding and its golden line.
  Remove the name from the comment list at `phase_vocab.ail:860`.
- Delete its four mentions in `dst_event_vocabulary.ail`.
- `dst_invariants.ail:753` names it in a comment about the final-record rule. Reword the comment.
- `scripts/dst/event_vocabulary_dst.ail`: remove it from the import and the sample (`:39`, `:96`),
  and change the row count at `:367` from 45 to 44.
- `scripts/dst/invariants_dst.ail:824` asserts it is a logical variant. Delete that conjunct.
- `scripts/phase_b_inventory_baseline.txt:14` lists the wire name. Delete the line.
- `tools/code-graph/overlay/event_subjects.py:110-112` has a rule for it. Delete the rule.

**Gate:** `make event_vocabulary invariants`.

### WI-5 — the system prompt says what is true

`SYSTEM.md:128`.

Replace the last sentence of the section with one that states the fact: the runtime does not
check this, so the check is the model's to run. Keep the rest of the section. It is the right
home for this rule: it applies only when the session modified AILANG source, which is the
condition DP7 never had.

**Gate:** none mechanical. Read the section once it is edited.

### WI-6 — a profile that still asks for the gate does not start

`src/core/rpc.ail`, `Makefile`, `docs/configuration.md`.

- At host startup, if the loaded profile has `verification.enabled` true, emit a
  `session_start_error` with its own `error_code` and exit 2, as the `ohmy_pi_unsupported`
  refusal does (`rpc.ail:175-182`). The message names the key, says the gate was removed, and
  says what to delete.
- It is unconditional. It does not depend on `extensions.strict`.
- New target `verify_no_finalize_verifier`, modelled on `verify_strict_context_limit`
  (`Makefile:2746-2770`): one temporary profile with the key set exits 2 with the message; one
  with `"verification": {}` starts. **Clear `AILANG_FS_SANDBOX` in its recipe**, as its siblings
  do. Add it to `check_core`'s prerequisites.
- `docs/configuration.md` gains two sentences: the key is refused, and why.

**Gate:** `make verify_no_finalize_verifier check_core`.

**Depended on #251**, which merged on 2026-10-09. Before it, this refusal would have stopped all
eight tracked profiles that set the key.

### WI-7 — delete the tests that test only DP7

- `scripts/smoke_v2_dp7_gate.ail` and `scripts/setup_dp7_smoke_workdirs.sh`: delete both.
- `Makefile` `smoke_driver` (`:2455-2490`): remove the setup line, the list entry, and the two
  comment paragraphs about DP7's workdirs.
- `scripts/dst/phase_a_event_parity.sh`: remove the setup call (`:173`) and the smoke's run
  (`:178`). This is what `smoke_parity` runs.
- `scripts/dst/ledger_parity_dst.ail`: delete `dp7_rt` (`:295-297`) and frame 6 (`:529-535`).
  Eight frames remain.
- `scripts/dst/park_wake_dst.ail`: delete `fixture_dp7_rejected` (`:643-654`) and its entry at
  `:743`. `w4_rt` loses its verifier-command parameter (`:346`).
- `scripts/dst/phase_c2_wiring_scenarios.ail`: delete the four `w2_dp7_*` scenarios and their
  helpers (`:1141-1360`) and their four list entries (`:1386-1388`, `:1391`).

**Gate:** `make smoke_driver smoke_parity ledger_parity park_wake phase_c_l1`.

### WI-8 — the corpus gate's `verifier-rejection` control (decision 1)

`scripts/dst/corpus_judge_dst.ail`, `scripts/dst/corpus_pr_dst.ail`,
`.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`.

011 ADR-003 ruling 18 gave the gate a control run named `verifier-rejection`
(`corpus_judge_dst.ail:881-990`). It runs the rig with a verifier that rejects
(`run_recording_verified_at`, `corpus_pr_dst.ail:410-415`) and checks that the rejection branch
was walked. That branch will not exist.

Recommended, if decision 1 is "replace":

- Give the rig a `SolverJudge` that returns `ContinueWithFeedback` for the first two candidates
  and replace `run_recording_verified_at` with a function that uses it.
- Rename the control `solver-feedback`. It asserts the same shape through the surviving branch:
  the answer is bounced, the model is called again under the same step, and the run ends on
  `max_steps`.
- Re-run the control's mutant from ruling 18 against the new control and record whether it is
  still killed. If the mutated line was DP7's own, name the equivalent line on the feedback path.
- Add a ruling to 011 ADR-003 that records the swap and why.

If decision 1 is "drop": delete the control and `run_recording_verified_at`, and record that in
the same place.

**Gate:** `make corpus_judge corpus_pr`. Run `corpus_pr` by itself.

### WI-9 — records

- [013 ADR-002](../013_core_architecture_for_dst/ADR-002-park-and-wake.md) D2: mark stage 2 and
  the DP7 cross-product cases superseded, with a pointer to Amendment 1.
- [028 ADR-001](../028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md)
  and item 1 of its PLAN-001: mark the finalization item superseded.
- [031 ADR-001](../031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md):
  a numbered amendment for the sentence at `:628-629` and freeze-evidence item 6.
- `design_docs/planned/m-motoko-dp7-verifier-gate.md`: status line to "Removed", with the pointer.
- `tools/predicate-anchors/anchors.sh`: its `session.ail` anchors move with this change.
  Re-baseline them as the comment at `:572-580` describes.

**Gate:** `make anchors`.

### WI-10 — the full gate, and one live check

- `make check_core`, `make test_coverage_selftest test_coverage`, `make smoke_parity`.
- `make dst`. On v0.52.5 the sweep is about 20 minutes cold.
- `make verify_core verify_mutations verify_classify_check`, then commit, then
  `make new_contract_policy BASE=origin/main`. That last gate reads commits only. This plan adds
  no `pure func` to `src/core` unless WI-6 needs one; if it does, give it a contract or a checked
  `-- contracts:` line.
- **One live session.** Start a session on the `default` profile, ask a question that needs no
  tool call, and confirm the log has a `done` event and no `dp7_verifier_rejected`. This is the
  one thing the gates cannot show.

### Sequencing

1. #250 (the Makefile target) and #251 (profiles) merged on 2026-10-09. Nothing else has to land
   first.
2. WI-1, WI-2 and WI-3 are one commit. The tree does not type-check between them.
3. WI-4, then WI-7 and WI-8, which need the variant gone to compile.
4. WI-6 and WI-5 are independent of the rest and of each other.
5. WI-9 last, when line numbers have stopped moving. WI-10 before the pull request.

---

## Blast radius (W1)

| Area | Files | Kind of change |
|---|---|---|
| Driver | `src/core/session.ail`, `src/core/step_machine.ail` | Logic removed, one rename |
| Vocabulary | `src/core/phase_vocab.ail`, `src/core/dst_event_vocabulary.ail`, `src/core/dst_invariants.ail` | One variant removed |
| Host startup | `src/core/rpc.ail` | One refusal added |
| Prompt and docs | `SYSTEM.md`, `docs/configuration.md` | Text |
| Build | `Makefile` | One target added, `smoke_driver` trimmed |
| Smokes | `scripts/smoke_v2_dp7_gate.ail`, `scripts/setup_dp7_smoke_workdirs.sh` | Deleted |
| DST scripts | `ledger_parity_dst`, `park_wake_dst`, `phase_c2_wiring_scenarios`, `event_vocabulary_dst`, `invariants_dst`, `corpus_judge_dst`, `corpus_pr_dst` | Scenarios removed or replaced |
| Tools | `tools/code-graph/overlay/event_subjects.py`, `tools/predicate-anchors/anchors.sh` | One rule removed, anchors re-baselined |
| Records | 011 ADR-003, 013 ADR-002, 028 ADR-001, 031 ADR-001, the DP7 design doc | Marked or amended |
| Evaluation manifest | `tools/eval_protected/manifest-A.json` | **Not edited.** See below. |

**The evaluation's protected manifest.** `session.ail`'s import region is a protected span
(`manifest-A.json`, generated at `65003110`). WI-2 changes it. The manifest already refuses
`main`: `protected.py check --manifest tools/eval_protected/manifest-A.json --tree HEAD` reports
two findings at `36a96b1e`, one of them this span. So W1 adds to an existing drift and creates no
new kind of problem. Regenerating the manifest is the evaluator's task under 013 ADR-004 D5 and is
not part of this plan.

**Not touched:** the ABI package, the session journal format, the execution-program format, any
extension package, any profile.

---

## W2 — remove the persist nudge

### What the research found

Amendment 1's first draft said the persist nudge "moves in the same plan". It is a wider thing
than DP7, in a different way.

- **The nudge itself is dead code in practice.** No `Makefile` target, CI job, profile or
  evaluation script sets `MOTOKO_PERSIST_RETRIES`. The default is `0`, which is off. The only
  setters are DST scripts that test it.
- **Its budget read is not dead.** `session_policy_init` reads `MOTOKO_PERSIST_RETRIES` in every
  session, first of four reads (`session.ail:2352`), and each later read is threaded from the one
  before. The key is one of the driver's eleven (`dst_discovery.ail:229`).
- **Tests count that read.** Six DST scripts carry a table with
  `{ key: "MOTOKO_PERSIST_RETRIES", count: 1 }` (`discovery_dst`, `driver_plus_compose_dst`,
  `herdr_graded_dst`, `run_report_dst`, `seeded_generator_dst`, `strict_replay_dst`), and
  `program_persistence_dst.ail:154` serves it a value.
- **The evaluation names it.** `src/eval/journal/configuration.ail:186` serves it as `"0"`,
  `stopping.ail:1089` checks that, `witness.ail` classifies it in three tables, and three fixture
  files name it 70 times between them.
- **Its counter is threaded through the loop and resume.** `nudges_used` is a field of
  `StepState` and `StepDelta` (`phase_vocab.ail:692`, `:705`), of every `C2LoopState` literal, and
  of the journal's `Continuation` (`journal.ail:143`).
- **Nothing stored depends on any of it.** The session journal records no environment read and
  no nudge count; resume recomputes the count from history (`journal.ail:2288-2290`), and the
  header of the 2026-10-09 journal has no such field. No stored execution program is committed.
  The key also appears in six evidence logs under `.agent/projects/*/evidence` and `evidence/`,
  which are records and are not replayed.

So the operator's reasoning holds for the nudge. The read is the part that still runs, and
removing it is safe for stored data and wide in tests.

### The decisions, as made

- **Delete, do not migrate.** ADR-001 D4 said the nudge "migrates to this seam", and the handoff
  `HANDOFF-write-persist-nudge-migration-plan.md` asked for a behaviour-preserving move. Both are
  superseded. No guard is built. If a coding profile wants the nudge later, it is a small guard on
  the existing seam, bounded as Amendment A2 requires.
- **The read goes too.** The driver's key set goes from eleven to ten. The tables and fixtures
  above change with it.

### Work items

- **W2-1 — confirm before the wide edit.** In a scratch tree, remove only the read (W2-4's first
  line) and run `make discovery strict_replay program_persistence run_report seeded_generator
  driver_plus_compose herdr_graded eval_matrix`. List every red target and the file behind it.
  That list is W2-4's checklist. If anything is red that this plan does not name, stop and report
  it before going on.
- **W2-2 — the policy.** Remove the nudge arm in `classify_candidate` (`session.ail:3288-3296`),
  `CandidateNudge`, the `persist_nudge` arm of `decide` (`step_machine.ail:134-135`),
  `PersistNudge` (`phase_vocab.ail:1004`, `:1315`, `:1498`, `:1956`),
  `StepPolicy.persist_retries` (`phase_vocab.ail:414`), and `should_inject_persist_nudge`,
  `persist_nudge_message` and `any_writefile_attempt` in `recovery.ail`. After it, a silent
  merge of the judges finalizes. The row count in `event_vocabulary_dst.ail:367` drops by one
  more, and `dst_event_vocabulary.ail` loses its four mentions (`:109`, `:180`, `:240`, `:430`).
- **W2-3 — the counter.** Remove `nudges_used` from `StepState`, `StepDelta`, `C2LoopState` and
  `Continuation`, and `count_persist_nudges` with it (`journal.ail:65`, `:143`, `:1758-1765`,
  `:2290`, `:2585`, `:2619`; `model_phase.ail:21`). This is the wide edit: every loop literal.
- **W2-4 — the read.**
  - `session_policy_init` (`session.ail:2352`): drop the read and re-thread the three that follow.
  - `dst_discovery.ail:229` and its comment at `:168`: ten keys. `dst_secrets.ail:32`: the comment.
  - The six count tables, and `program_persistence_dst.ail:154`.
  - The evaluator: `configuration.ail:28`, `:186`, `:296`; `stopping.ail:1089`; `witness.ail:32`,
    `:124`, `:362-370`, `:391`; `witness_live_test.ail:171`. Regenerate the three fixture files
    with `src/eval/journal/testdata/gen_fixtures.py` (`:1835`). These are evaluator paths under
    013 ADR-004 D5, so this part is an evaluator change and is reviewed as one.
  - `scripts/dst/phase_c2_wiring_scenarios.ail`, `phase_c_l1_scenarios.ail`,
    `phase_c_seeded_dst.ail` and `scripts/phase_f_pipeline_wiring.ail` name the nudge in
    scenarios. Delete or rewrite each.
- **W2-5 — the host.** `src/tui/src/runtime-process.ts:550` stops passing the variable.
- **W2-6 — records.** Mark ADR-001 D4 and the handoff superseded, with a pointer to Amendment A5.

**Gate:** W1's WI-10 in full, plus `make eval_matrix` and the targets named in W2-1.

W2 is its own pull request, after W1 has merged.

---

## Corrections to Amendment 1 found while planning

Fixed in the amendment in the same change as this plan:

- **"Old journals still carry `dp7_verifier_rejected`" was wrong.** The session journal never
  held it. Only wire logs do, and nothing reads an old wire log against the vocabulary.
- **A5 understated the persist nudge.** Its budget read runs in every session and is counted by
  DST tables and the evaluation's fixtures. A5 now says so, and records the operator's decision
  to delete it.
- **Two records were missing from the superseded list:** 011 ADR-003 ruling 18 (the
  `verifier-rejection` control) and `SYSTEM.md:128`.

## Out of scope

- The TUI shows no guard feedback at all (`src/tui/src` has no handler for `ext_solver_feedback`).
- Near-duplicate matching in the repetition guard.
- Removing `ExtRuntime.verification` and `VerificationConfig` from the ABI package.
- Regenerating the evaluation's protected manifest.
