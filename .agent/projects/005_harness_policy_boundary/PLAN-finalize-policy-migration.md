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
Diagrams: [the pipeline as built](mmd/dp7-finalize-gate.svg), with the verifier, and
[the pipeline after W1](mmd/dp7-finalize-gate-end-state.svg). Sources are beside them.

---

## TL;DR

Two workstreams. W1 does not wait for W2.

1. **W1 removes the DP7 verifier from core.** Nothing replaces it. Nine work items, one pull
   request. It is ready to start.
2. **W2 removes the persist nudge completely**, its environment read included, and builds no
   guard in its place. The operator decided that on 2026-10-09. It follows W1, because both edit
   `classify_candidate` and `decide`.

### The operator's decisions

All five were answered on 2026-10-09. Nothing in this plan waits on a decision.

| # | Question | The operator's answer |
|---|---|---|
| 1 | 011 ADR-003's `verifier-rejection` control run exists to walk the DP7 branch. Replace it with a control on the solver-feedback branch, or drop it? | Replace it with the solver-feedback control. |
| 2 | A profile that still sets `verification.enabled: true`: refuse to start, or warn? | Neither, here. Profile config entries the host does not use are dealt with in a separate pull request. WI-6 is withdrawn. |
| 3 | Build a persist-nudge guard extension (ADR-001 D4), or delete the persist nudge? | Delete it. It is off by default, so it has not run for a long time. |
| 4 | Keep reading `MOTOKO_PERSIST_RETRIES` as a dead value, or remove the read too? | Remove it in full, the read included. The operator confirmed that after seeing what the read touches. |
| 5 | Deleting a wire event changes the vocabulary's version (review finding 4). For old traces: pin a runner, build a decoder, or keep the event as an entry nothing emits? | Pin a runner. |

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
- **Nothing reads an old wire log against the vocabulary.** `event_vocabulary()` is called from
  `src/core/dst_invariants.ail` and from five scripts under `scripts/dst/`
  (`event_vocabulary_dst.ail`, `export_vocabulary.ail`, `invariants_dst.ail`,
  `ledger_parity_dst.ail`, `run_ledger_parity_wire.sh`). Each works on the live sum or on a trace
  made in the same run.
- **But the vocabulary is versioned, and deleting a variant is a version change.**
  `event_vocabulary_version()` is `event-vocabulary/1` (`dst_event_vocabulary.ail:121`). 009
  ADR-001 D6 makes a change to any variant a version change, and says of old traces: preserve
  decoding or pin a runner, never reinterpret silently. The version is checked against execution
  manifests (`dst_profile.ail:1568`) and written out in six places in five DST scripts.
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

### WI-4 — the wire event goes, and the vocabulary's version moves

`src/core/phase_vocab.ail`, `src/core/dst_event_vocabulary.ail`, `src/core/dst_invariants.ail`,
`src/core/dst_interaction.ail`, eight DST scripts, `tools/code-graph`.

- Delete `Dp7RejectedInfo`, the `Dp7VerifierRejected` variant, its encoding and its golden line.
  Remove the name from the comment list at `phase_vocab.ail:860`.
- `dst_event_vocabulary.ail`: delete its four mentions (`:105`, `:163`, `:223`, `:325`), and
  change the two inline tests that count rows from 45 to 44 (`:863`, `:929`).
- **The version.** `event_vocabulary_version()` becomes `event-vocabulary/2`. Six places write
  `/1` and change with it: `driver_only_dst.ail:262`, `driver_plus_compose_dst.ail:1105`,
  `driver_plus_no_ops_dst.ail:469`, `hook_guard_dst.ail:132`, and `profile_definition_dst.ail:171`
  and `:536`. So does the comment at `dst_interaction.ail:105`.
- **Old traces: a pinned runner (decision 5).** 009 ADR-001 D6 offers two ways: keep decoding
  old traces, or pin a runner. The tree has no decoder for wire events. So a trace recorded
  under `/1` is read by a build that still has `/1`, and the new build refuses it: a manifest
  whose vocabulary version differs is already rejected with `ManifestVersionDrifted`
  (`dst_profile.ail:1525-1527`).
  - Record the pin in the comment above `event_vocabulary_version()` and in the commit message:
    `event-vocabulary/1` is read by the commit this branch is cut from, named by its hash. Any
    later commit that still has `/1` reads it too.
  - Nothing is built. What the pin covers in practice is the corpus artifacts CI keeps for 14
    days (`.github/workflows/dst-corpora.yml:168-176`) and anything on a developer's disk. No
    recorded trace is committed.
- `dst_invariants.ail:753` names the variant in a comment about the final-record rule. Reword it.
- `scripts/dst/event_vocabulary_dst.ail`: remove it from the import and the sample (`:39`, `:96`),
  and change the row count at `:367` from 45 to 44.
- `scripts/dst/invariants_dst.ail:824` asserts it is a logical variant. Delete that conjunct.
- `scripts/phase_b_inventory_baseline.txt:14` lists the wire name. Delete the line.
- `tools/code-graph`: delete the rule at `overlay/event_subjects.py:110-112`, and move the pins
  that count rules: 30 to 29 in `tests/test_event_subjects.py:38`, fixed rules 19 to 18 in
  `overlay/validate_overlay.py:45`, and the tests' count of rules with several subjects, 15 to 14.
- Two more scripts import the variant: `phase_c2_wiring_scenarios.ail:20` and
  `corpus_judge_dst.ail:114`. Their imports go in the same commit (see *Sequencing*).

**Gate:** `make event_vocabulary invariants test_coverage`, and
`python3 -m pytest tools/code-graph/tests/test_event_subjects.py -q`. No `make` target and no CI
job runs that test file, so it has to be run by hand.

### WI-5 — the system prompt says what is true

`SYSTEM.md:128`.

Replace the last sentence of the section with one that states the fact: the runtime does not
check this, so the check is the model's to run. Keep the rest of the section. It is the right
home for this rule: it applies only when the session modified AILANG source, which is the
condition DP7 never had.

**Gate:** none mechanical. Read the section once it is edited.

### WI-6 — withdrawn

This item made a profile that still sets `verification.enabled: true` refuse to start. The
operator decided on 2026-10-09 that W1 does not handle the key: what the host does with a profile
config entry it does not use is a question about every such entry, and gets its own pull
request. The number is kept so the other items do not move.

What that leaves, stated plainly: after W1 the key is read into the config and then ignored. A
profile that sets it starts as usual and nothing is verified. No tracked profile sets it (#251).

### WI-7 — delete the tests that test only DP7

- `scripts/smoke_v2_dp7_gate.ail` and `scripts/setup_dp7_smoke_workdirs.sh`: delete both.
- `Makefile` `smoke_driver` (`:2455-2490`): remove the setup line, the list entry, and the two
  comment paragraphs about DP7's workdirs.
- `scripts/dst/phase_a_event_parity.sh`: remove the setup call (`:173`) and the smoke's run
  (`:178`). This is what `smoke_parity` runs.
- `scripts/dst/ledger_parity_dst.ail`: delete `dp7_rt` (`:295-297`) and frame 6 (`:529-535`).
  Take `f6` and `r6` out of the final checks (`:636-638`). The two printed counts go from 9 to 8
  (`:634-635`). Two wrapper scripts pin nine and change with it:
  `run_ledger_parity_wire.sh:99` and `run_world_framed_wire.sh` (`:54` and its expected count).
- `scripts/dst/park_wake_dst.ail`: delete `fixture_dp7_rejected` (`:643-654`) and its entry at
  `:743`. `w4_rt` loses its verifier-command parameter (`:346`).
- `scripts/dst/phase_c2_wiring_scenarios.ail`. The block `:1141-1360` holds **six** scenarios.
  - Delete five: the four `w2_dp7_*`, and `w2_blank_candidate_still_verified_at_finalize`
    (`:1325-1340`), which tests the verifier's stage 5.
  - Keep `w2_blank_candidate_goes_to_empty_stop_guard` (`:1304-1323`). Drop its two verifier
    checks. It still shows that a blank answer gets the guard's feedback.
  - Keep the helpers it uses (`w2_rt`, `w2_run`, `w2_prefix`, `w2_feedback_at_step`,
    `w2_checks`, `w2_count_event`). Delete the verifier's: `w2_dp7_count_path`,
    `w2_verifier_runs`, `w2_dp7_at_step`, and the verifier half of `w2_rt`.
  - Remove five list entries (`:1386-1388`, `:1390`, `:1391`). Keep `:1389`.

**Gate:** `make smoke_driver smoke_parity ledger_parity world_framed_wire park_wake phase_c_l1`.

### WI-8 — the corpus gate's control moves to the solver-feedback branch

`scripts/dst/corpus_judge_dst.ail`, `scripts/dst/corpus_pr_dst.ail`,
`.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`.

**What is there.** 011 ADR-003 ruling 18 gave the gate a control run named `verifier-rejection`
(`corpus_judge_dst.ail:876-990`). It exists because a reviewer's mutant survived the gate: in
the state built after a DP7 rejection, `step_idx + 1` changed to `step_idx`
(`session.ail:2985`). No bank member ran with verification on, so none walked that branch. The
control runs the rig with a verifier that always rejects (`run_recording_verified_at`,
`corpus_pr_dst.ail:410-415`), and under the mutant `driver-step-repeated` and
`steps-not-contiguous` go red.

**Why it cannot stay.** W1 deletes the branch and the mutated line with it.

**What replaces it (decided 2026-10-09).** A control named `solver-feedback`, on the branch that
survives: when a judge returns `ContinueWithFeedback`, the loop also resumes with `step_idx + 1`
(`session.ail:4146`). No bank member or control uses a judge that continues, so this branch is
not walked by the gate today. After W1 and W2 it is the only way a final answer is sent back.

- `corpus_pr_dst.ail`: replace `run_recording_verified_at` with a function that runs the rig with
  one `SolverJudge` atom that returns `ContinueWithFeedback` for every candidate. The judge is
  pure and takes no input from the world.
- `corpus_judge_dst.ail`: rename the control. It asserts what the old one did, through the new
  branch: the run ends `Err` on `max_steps` with a step budget of 2; `ext_solver_feedback` at
  steps 0 and 1; prepared steps 0 and 1; two provider interactions logged; the third scripted
  entry never asked for. Delete `rejected_steps` and `rejecting_verifier`.
- Keep the script's last entry a provider error that is not retried. The old control needed it
  so that a defect ends as a red row and not as a hang, and the same holds here.
- **Run the mutant.** Change `step_idx + 1` to `step_idx` at `session.ail:4146` and confirm the
  control is red on `driver-step-repeated` and `steps-not-contiguous`. Then run the unmutated
  gate without the new control and confirm the same mutant is green there. That second run is
  the evidence that the control is what catches it.
- **Check ruling 18's premise.** It rests on the control being the bank's rig with one part
  changed, so that D5's three premises hold. A continuing judge takes the place of a neutral
  hook. Confirm the recording adapter and the delta over the starting log are untouched.
- Add ruling 19 to 011 ADR-003: the control changed branch, why, and the two mutant runs.

**Tried once already, in review.** The reviewer built a temporary version of this control. It
passed `make corpus_judge`. The mutant at `session.ail:4146` was red on both named rules and on
`provider-calls-exceed-budget`. With the control removed the same mutant passed. The reviewer
also read 011 ADR-003 D5 and found its three premises hold for a judge that returns feedback
without calling the model. The implementer repeats both runs on the real change.

**Gate:** `make corpus_judge corpus_pr`. Run `corpus_pr` by itself.

### WI-9 — records

- [013 ADR-002](../013_core_architecture_for_dst/ADR-002-park-and-wake.md) D2: mark stage 2 and
  the DP7 cross-product cases superseded, with a pointer to Amendment 1.
- [028 ADR-001](../028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md)
  and item 1 of its PLAN-001: mark the finalization item superseded.
- [031 ADR-001](../031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md):
  a numbered amendment for the sentence at `:628-629` and freeze-evidence item 6.
- [013 ADR-004](../013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md)
  (`:604-610`), Accepted: its T0 settings table pins `rt.verification` to `{ enabled: false }`
  and explains the row by `run_dp7_verifier`. Mark the row as no longer needed, by a numbered
  change in that record.
- `design_docs/planned/m-motoko-dp7-verifier-gate.md`: status line to "Removed", with the pointer.
- **The attribution anchors.** W1 moves every `session.ail` anchor. A re-baseline is the
  six-file form the comment in `tools/predicate-anchors/anchors.sh` describes (`:572-600`): that
  file, `src/core/dst_attribution_table.ail`, `scripts/dst/attribution_table_dst.ail`, and a
  re-issue of three DST profiles (`driver_only`, `driver_plus_no_ops`, `driver_plus_compose`),
  each with its version moved.

**Gate:** `make anchors attribution_table`.

### WI-10 — the full gate, and one live check

- `make check_core`, `make test_coverage_selftest test_coverage`, `make smoke_parity`.
- `make dst`. On v0.52.5 the sweep is about 20 minutes cold.
- `make verify_core verify_mutations verify_classify_check`, then commit, then
  `make new_contract_policy BASE=origin/main`. That last gate reads commits only. This plan adds
  no `pure func` to `src/core`.
- What CI runs and the lines above do not: `make verify_skills_tests verify_skills_refusal
  smoke_no_delegated_storm verify_profile_dir_agreement tui_context_limit dst_l2`.
- `python3 -m pytest tools/code-graph/tests/test_event_subjects.py -q`, which nothing else runs.
- **One live session.** Start a session on the `default` profile, ask a question that needs no
  tool call, and confirm the log has a `done` event and no `dp7_verifier_rejected`. This is the
  one thing the gates cannot show.

### Sequencing

1. #250 (the Makefile target) and #251 (profiles) merged on 2026-10-09. Nothing else has to land
   first.
2. WI-1, WI-2 and WI-3 are one commit. The tree does not type-check between them.
3. WI-4's deletion of the variant lands in one commit with the script edits in WI-7 and WI-8
   that stop importing it. The scripts' imports need the variant until they are removed, so
   neither side compiles alone.
4. WI-5 is independent of the rest.
5. WI-9 last, when line numbers have stopped moving. WI-10 before the pull request.

---

## Blast radius (W1)

| Area | Files | Kind of change |
|---|---|---|
| Driver | `src/core/session.ail`, `src/core/step_machine.ail` | Logic removed, one rename |
| Vocabulary | `src/core/phase_vocab.ail`, `src/core/dst_event_vocabulary.ail`, `src/core/dst_invariants.ail`, `src/core/dst_interaction.ail` | One variant removed; version to `event-vocabulary/2` |
| Prompt | `SYSTEM.md` | One sentence |
| Build | `Makefile` | `smoke_driver` trimmed |
| Smokes | `scripts/smoke_v2_dp7_gate.ail`, `scripts/setup_dp7_smoke_workdirs.sh` | Deleted |
| DST scripts | `ledger_parity_dst`, `park_wake_dst`, `phase_c2_wiring_scenarios`, `event_vocabulary_dst`, `invariants_dst`, `corpus_judge_dst`, `corpus_pr_dst` | Scenarios removed or replaced |
| DST wrappers | `run_ledger_parity_wire.sh`, `run_world_framed_wire.sh`, `phase_a_event_parity.sh` | Pinned counts and one smoke's run |
| Version string | `driver_only_dst`, `driver_plus_compose_dst`, `driver_plus_no_ops_dst`, `hook_guard_dst`, `profile_definition_dst` | `event-vocabulary/1` to `/2` |
| Code graph | `tools/code-graph/overlay/event_subjects.py`, `overlay/validate_overlay.py`, `tests/test_event_subjects.py` | One rule removed, three pinned counts |
| Attribution | `tools/predicate-anchors/anchors.sh`, `src/core/dst_attribution_table.ail`, `scripts/dst/attribution_table_dst.ail`, three DST profiles | Anchors re-baselined, profiles re-issued |
| Records | 011 ADR-003, 013 ADR-002, 013 ADR-004, 028 ADR-001, 031 ADR-001, the DP7 design doc | Marked or amended |
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
  before. The key is one of the driver's twelve (`dst_discovery.ail:224-236`).
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
- **The read goes too.** The driver's key set goes from twelve to eleven. The tables and
  fixtures above change with it.

### Work items

- **W2-1 — confirm before the wide edit.** In a scratch tree, remove only the read (W2-4's first
  line) and run `make discovery strict_replay program_persistence run_report seeded_generator
  driver_plus_compose herdr_graded ledger_parity depth_canary eval_matrix`. List every red target
  and the file behind it. That list is W2-4's checklist. If anything is red that this plan does
  not name, stop and report it before going on. The review already ran this for two targets:
  `ledger_parity` and `depth_canary` both go red, for the reasons W2-4 lists.
- **W2-2 — the policy.** Remove the nudge arm in `classify_candidate` (`session.ail:3288-3296`),
  `CandidateNudge`, the `persist_nudge` arm of `decide` (`step_machine.ail:134-135`),
  `PersistNudge` (`phase_vocab.ail:1004`, `:1315`, `:1498`, `:1956`),
  `StepPolicy.persist_retries` (`phase_vocab.ail:414`), and `should_inject_persist_nudge`,
  `persist_nudge_message` and `any_writefile_attempt` in `recovery.ail`. After it, a silent
  merge of the judges finalizes. Also, so that "in full" is true:
  - In `session.ail`: the `CandidateNudge` arm (`:4172`), the exported
    `run_v2_session_traced_with_persist_retries` (`:4445`) with its two callers in
    `phase_c2_wiring_scenarios.ail` (`:193`, `:1197`), and the local helpers
    `persist_nudge_marker` (`:2311`), `parse_persist_retries_budget` (`:2315`) and
    `count_persist_nudges` (`:2425-2452`).
  - Inline tests: `recovery.ail:86-118` and `test_decide_persist_nudge` (`step_machine.ail:403`).
  - The vocabulary: `dst_event_vocabulary.ail` loses its four mentions (`:109`, `:180`, `:240`,
    `:430`), its two counting tests go from 44 to 43, and the version moves again, to
    `event-vocabulary/3`, by the same rule as WI-4, with a second pin for `/2`.
  - `event_vocabulary_dst.ail`: the import and sample (`:43`, `:118`) and the count at `:367`.
  - `scripts/phase_b_inventory_baseline.txt:23`, and the rule at
    `tools/code-graph/overlay/event_subjects.py:135-136` with its three pinned counts again.
- **W2-3 — the counter.** Remove `nudges_used` from `StepState`, `StepDelta`, `C2LoopState` and
  `Continuation`, and `count_persist_nudges` with it (`journal.ail:65`, `:143`, `:1758-1765`,
  `:2290`, `:2585`, `:2619`; `model_phase.ail:21`). This is the wide edit: every loop literal.
- **W2-4 — the read.**
  - `session_policy_init` (`session.ail:2352`): drop the read and re-thread the three that follow.
  - `dst_discovery.ail:229` and its comment at `:168`: eleven keys. `dst_secrets.ail:32`: the
    comment.
  - The six count tables, and `program_persistence_dst.ail:154`.
  - Two pins on bootstrap records, found in review: the order strings in
    `ledger_parity_dst.ail:616` and `:619` lose one `WorldRequest`, and the record counts in
    `scripts/dst/run_depth_canary.sh:172` go from 123, 191 and 217 to 122, 190 and 216.
  - The evaluator: `configuration.ail:28`, `:186`, `:296`; `stopping.ail:1089`; `witness.ail:32`,
    `:124`, `:362-370`, `:391`; `witness_live_test.ail:171`. Regenerate the three fixture files
    with `src/eval/journal/testdata/gen_fixtures.py` (`:1835`). These are evaluator paths under
    013 ADR-004 D5, so this part is an evaluator change and is reviewed as one.
  - `scripts/dst/phase_c2_wiring_scenarios.ail`, `phase_c_l1_scenarios.ail`,
    `phase_c_seeded_dst.ail` and `scripts/phase_f_pipeline_wiring.ail` name the nudge in
    scenarios. Delete or rewrite each.
- **W2-5 — the host.** `src/tui/src/runtime-process.ts:550` stops passing the variable.
- **W2-6 — records.** Mark ADR-001 D4 and the handoff superseded, with a pointer to Amendment A5.
  013 ADR-004 serves `MOTOKO_PERSIST_RETRIES` as `"0"` in its T0 settings (`:611`) and counts one
  read of it (`:966`). Both rows go, by a numbered change in that record.

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

## Review

Codex Sol (GPT-6.1-Sol) reviewed this plan on 2026-10-09 at `f9a7c89c`, from the brief in
`tmp/review-249/BRIEF-sol.md`. Its verdict: revise before implementing. It reported eight
findings. Each was reproduced against the code before this plan was changed, and all eight are
folded in above.

| # | Finding | Where it is fixed |
|---|---|---|
| 1 | WI-7 left scenario list entries, `f6`/`r6` and two imports behind | WI-7, WI-4 |
| 2 | Two inline tests in `dst_event_vocabulary.ail` still asserted 45 rows | WI-4 |
| 3 | W2's checklist missed the `ledger_parity` order strings and the depth canary's pins | W2-1, W2-4 |
| 4 | Deleting a wire variant is a vocabulary version change (009 ADR-001 D6) | *Verified state*, WI-4, W2-2 |
| 5 | Deleting the code-graph rule breaks three pinned counts that no gate runs | WI-4, WI-10 |
| 6 | W2 did not name several persist-nudge leftovers | W2-2 |
| 7 | 013 ADR-004's settings and read-count tables were missing from the records | WI-9, W2-6, Amendment 1 |
| 8 | The driver has twelve environment keys, not eleven; the vocabulary's callers were misnamed | *Verified state*, W2 |

It also offered four opinions, all taken: land the variant's deletion with the script edits, drop
"they share no code", make the attribution re-baseline explicit, and add the targets only CI
runs.

One choice in the fixes was not the reviewer's: for old traces, **pin a runner** and do not
build a decoder (WI-4). The operator confirmed it on 2026-10-09, as decision 5.

Not reviewed: neither workstream was implemented in full, and `make dst`, `eval_matrix`,
`check_core`, the contract gates, `corpus_pr` and a live session were not run.

## Out of scope

- What the host does with a profile config entry it does not use, `verification.enabled` among
  them. The operator's decision 2: a separate pull request.
- The TUI shows no guard feedback at all (`src/tui/src` has no handler for `ext_solver_feedback`).
- Near-duplicate matching in the repetition guard.
- Removing `ExtRuntime.verification` and `VerificationConfig` from the ABI package.
- Regenerating the evaluation's protected manifest.
