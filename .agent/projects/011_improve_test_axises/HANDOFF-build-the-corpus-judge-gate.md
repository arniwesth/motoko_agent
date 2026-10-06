# Handoff: build the corpus judge gate (cluster 1 of ADR-003's plan)

Date: 2026-10-06, revised the same day after `REVIEW-001-plan-judge-recoveries-claude-opus-5.5.md`
From: the session that wrote `PLAN-judge-recoveries-on-real-runs.md`
For: a fresh session, in its own worktree and branch
Deliverable: one branch, two commits, and a cost report at the end

1. **The bank is shared.** `scripts/dst/corpus_pr_dst.ail` exports its bank, states its step
   budget once and its run recipe once. No behaviour changes. This is the plan's WI-1.
2. **The gate.** `scripts/dst/corpus_judge_dst.ail`, a `corpus_judge` target in `DST_TARGETS`, and
   one step in `.github/workflows/dst-corpora.yml`. This is the plan's WI-3.

**Build these two. Do not build WI-2,** the two invariant rules: another session has them, in
other files. **Do not run WI-4,** acceptance.

The plan is the specification. This handoff adds what a plan cannot hold: the grounding as of
today, the rules you would break by accident, a runnable definition of done for each commit, and
where to stop. Where the two disagree the plan wins, and where the plan and ADR-003 disagree the
ADR wins.

## First: is this still the tree it was grounded on?

Grounded at `59d5cbb9`, AILANG v0.47.2.

    git diff --stat 59d5cbb9 HEAD -- scripts/dst/corpus_pr_dst.ail scripts/dst/export_trace.ail \
      src/core/session.ail src/core/tool_phase.ail src/core/dst_execution.ail \
      src/core/dst_discovery.ail src/core/dst_persistence.ail src/core/phase_vocab.ail \
      src/core/test/stub_step.ail Makefile .github/workflows/dst-corpora.yml

- **Empty:** the anchors below hold.
- **Not empty:** re-observe every anchor in a file that changed before you use it.
- **For the baseline,** run the check in `evidence/judge-recoveries/baseline-59d5cbb9/README.md`.
  It names the files the other cluster may have changed and says what that does to each
  comparison.
- **If the other cluster merged first,** `src/core/dst_invariants.ail` has two new rules and your
  gate evaluates them. Every member should still be clean. A red one is a stop-and-report.

## Read first

1. `PLAN-judge-recoveries-on-real-runs.md`: §2 F1, F2 and F4.3; in §4, *Rules that hold for every
   item*, *Names this plan fixes*, WI-1 and WI-3; §5.
2. `ADR-003-judge-recoveries-on-real-runs.md`: D1, D3's gate half, D4, D5, D9, D10, the scope
   paragraph after D10, rulings 13 to 16.
3. `evidence/mutation-spike/scripts/spike_families_on_bank.diff`, the function `spk_row3`: the
   bridge call and the six checks as a prototype. A sketch. See *What you would break by accident*.
4. `scripts/dst/corpus_pr_dst.ail` `:286` to `:400`, `:540` to `:690`, `:1190` to `:1232`, and the
   `corpus_pr` recipe at `Makefile:1846`.
5. `scripts/dst/stream_parity_dst.ail`, for the house shape of a gate script: rows that name their
   rule, fixture adequacy asserted, and a "does not trip the other rule" row (`:308`).
6. `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` `:2272` to
   `:2300`: D8, which the failure record answers to.

## Anchors, observed at `59d5cbb9`

| what | where |
|---|---|
| the bank and the rig, all private | `fixed_bank` `:573`, `generated_world` `:310`, `empty_terminal_world` `:604`, `approval_rt` `:337`, `run_generated` `:354`, `run_recording` `:361`; `BankEntry` `:548` and `main` `:1205` are the only exports |
| the budget literal | `12` at `:358` and `:365`, the ninth argument of `run_v2_session_traced` (`session.ail:4423`) |
| a member's run recipe, which lives only here | `build_seed` `:664`: `generated_world(seed)`, `run_generated("corpus_<seed>", initial)`, `program_of`, label `seed-<n>`. `build_constructed` `:684`: `empty_terminal_world()`, `run_recording("corpus_constructed", initial)`, `constructed_program` (`:617`), label `constructed-empty-terminal` |
| a member's program and where it is persisted | `program_of` `:373`; `store_root` `:394`; `build` `:637` calls `persist_program(store_root(), p)` and `artifact_path(store_root(), p)` (`dst_persistence.ail:1254`) |
| the corpus store | `corpus_pr`'s recipe starts with `rm -rf .ailang/dst-corpus` |
| what `corpus_pr` prints per member | `CORPUSROW <label> kind=… seed=… n=<log length> ended=<Ok or Err> …`, `emit_rows` `:1190` |
| the rig's copy | `scripts/dst/export_trace.ail:97` to `:112`, pinned by `make depth_canary` |
| the bridge | `execution_of`, `dst_execution.ail:100`, eight parameters; it stays at eight (ruling 13) |
| the trace records the checks read | `ProviderCallPrepared` (`.step`; appended at `session.ail:3861`), `StreamErrorRetry` (`.step`; `:3880`), `WorldRequest` (`.ordinal`; `witness`, `:4572`), `V2ToolDispatchStart` (built at `tool_phase.ail:470`, returned in `emitted` at `:505`); declared at `phase_vocab.ail:1296`, `:1306`, `:1341` |
| a result with a terminal summary | `run_summary_finish_reason`, `phase_vocab.ail:1266` |
| families not evaluated | `family_evidence`, `dst_invariants.ail:2045`; the journal bridge prints them as `unevaluated=…` |
| the balance, both directions from one comparison | `class_balance(kind, witnessed, logged)`, `dst_discovery.ail:374`; log kinds are `expect_provider` and `expect_tool` |
| identities for the failure record | `driver_only_version()` `dst_driver_only.ail:528`; `event_vocabulary_version()` `dst_event_vocabulary.ail:121`; `first_failed_invariant` `dst_invariants.ail:2032` |
| a scripted provider fault | a `ScriptedStep` with `error_code: "E_PROVIDER_TIMEOUT"`; `prose_step` and `scripted_world_state` are in `src/core/test/stub_step.ail` (`:806`, `:764`) |
| the sweep's lists | `DST_TARGETS` `Makefile:507`; `DST_TIMED_TARGETS` `:632`, which stays `corpus_pr` alone; untimed targets get a cache lane by `:646` |
| the workflow step | `dst-corpora.yml:98`, "D11's blocking PR corpus", in job `pr-corpus` (`:64`, fifteen-minute limit) |

Measured, so you do not re-derive it:

- **The sharing route works end to end.** The plan's reviewer exported the helpers, imported them
  from a sibling script and ran all sixteen members and both controls in 51 s. Its probe is not
  in the repository.
- **Nothing else imports the corpus script.** Only the `corpus_pr` recipe runs it (`Makefile:1851`).
- **`corpus_pr` alone took 82 s** at this commit against its 180 s ceiling. Its output with
  `duration_ms` masked hashes to the value in
  `evidence/judge-recoveries/baseline-59d5cbb9/corpus_pr.wire.sha256`, and has on three checkouts.
- **Every member is clean today on what the six checks read** (the reviewer's run): steps
  contiguous from 0, provider and tool counts balanced, ordinals contiguous. Retries are at steps
  1, 8, 1 and 1, on seeds 9, 19, 32 and 141. Ten members dispatch tools. Seeds 19 and 244 make 12
  calls on 12.
- **The two budget controls behave as the plan says**, on `stream_parity`'s rig and on the bank's.
  Budget 2, script of a timeout step then a prose stop: `Ok` on `stop`, prepared steps `[0, 1]`,
  retries `[0]`, two provider interactions logged. Budget 1, the timeout step alone: `Err` with
  `E_PROVIDER_TIMEOUT` on `error`, prepared steps `[0]`, no retry.
- **The sweep is red before you touch it:** four targets, one cause, none yours. The names are in
  the baseline's README.

## Commit 1: the bank is shared

The plan's WI-1 lists the edit: about twenty-five lines in one file.

**Done, in this order.**

    # before editing, alone, twice. Keep both hashes and both times.
    make corpus_pr
    sed -E 's/"duration_ms":[0-9]+/"duration_ms":0/g' /tmp/corpus_pr.out | sha256sum
    # edit, then the same two lines, twice.
    git diff --stat        # one file

- All four hashes are equal, and equal to the baseline's.
- No run after is slower than the slower run before by more than 15 percent, with nothing else
  running. Faster is not a finding. The recipe prints the time:
  `measured CI cost, WHOLE TARGET: <ms>`.
- **No sweep for this commit.** Nothing else can move, and commit 2's sweep covers both.
- `/tmp/corpus_pr.out` is one path for the whole container. If another session may run
  `corpus_pr`, give yours a private path first (rule 7 of the plan).

## Commit 2: the gate

The plan's WI-3 says what the script does, in nine steps, and fixes its six rule ids.

**Done.**

    make corpus_judge   # passes
    make corpus_pr      # alone: the same hash, and the time within commit 1's tolerance
    make dst            # the baseline's four red, corpus_judge among the passing

`make corpus_judge` passing means all of:

- sixteen members bridged, each with no finding from `evaluate` and none from the six checks;
- each member's `n=` and `ended=` equal to its `CORPUSROW` line from `make corpus_pr`;
- every rule id fired by its constructed input and by nothing else, with one input for each
  direction of the two balances, and silent on its good one;
- both budget controls as measured above, with no finding;
- the undeclared-budget row printed as not evaluated;
- the families that were not evaluated printed in one line;
- the anti-vacuity conditions of step 7 met.

Two more, which a green run does not show:

- **The failure record, seen once.** Make one real member red by a temporary edit, read the
  record against step 9's table, confirm the output file was kept and its path printed, and
  restore. `git status` is clean afterwards.
- **The pull request's `pr-corpus` job** is green with the new step in it.

## What you would break by accident

- **Writing `12` in the gate.** The gate's declared budget and the run's are one value,
  `bank_step_budget()`. Two literals that agree today are the defect this item removes.
- **Restating a member's run.** The id string, the world, the label and the program come from the
  helper WI-1 exports, which `build_seed` and `build_constructed` also call. The `n=` and `ended=`
  comparison is what proves your sixteen runs are `corpus_pr`'s.
- **Starting from the prototype's file.** It is the corpus script copied whole with the budget
  hardcoded. Take the bridge call and the six expressions in `spk_row3`, and leave the rest.
- **Defaulting the bridge's other arguments.** The clock is the member's starting world's, the
  obligation is `NoReplay`, the metadata is `unknown_replay_metadata()`, the decision budget is
  undeclared. The plan's step 3 has the call.
- **Moving the bank into a shared module.** Better end state, wrong commit: it changes what the
  wall-clock target compiles and where the depth canary's rig lives.
- **Calling `build`, or persisting anything.** The gate names the path where `corpus_pr`
  persisted a program; it does not write one. Two writers of `.ailang/dst-corpus` race whenever
  someone runs the targets by hand.
- **Naming the script `driver_*_dst.ail`.** `tools/profile_definition/check_fixtures.py:954` globs
  that pattern and would start checking it as a profile.
- **A check that is green because it saw nothing.** A contiguity test over an empty list is true.
  Step 7 exists for this.
- **A verdict that hides the rule.** Print every member's rule rows before the vacuity verdict. A
  defect that empties a trace trips the guard on every member, and acceptance counts a row only
  when the rule it names is printed.
- **Reading "not evaluated" as passed.** On a bank member it is red.
- **Applying a balance outside the bank.** The two balances and the ordinal check are this gate's
  checks on the `driver_only` bank. The two control runs are scripted worlds under the same
  rig; say so where they are declared.
- **Putting the check functions under `src/core`.** They are gate checks by ruling. In the script
  they are also outside the contract policy and outside project 013's path list.
- **A workflow step that a red `corpus_pr` skips.** The new step carries
  `if: ${{ !cancelled() }}`.

## Stop and report, do not decide

- A healthy bank member red on anything, with or without the other cluster's rules merged.
- `corpus_pr`'s output changed, or its time outside the tolerance on a repeat.
- Either control behaving differently in the built gate, or needing a bank member.
- A `driver_only` member that parks.
- Any pin that would have to move: a corpus identity, the depth canary, `stream_parity`'s rule sets.
- Anything in ADR-003's *Not decided* list.

## Conventions

One worktree and one branch for this cluster, from `origin/main`. Nothing is committed on `main`.
The pull request goes through `tools/pr` (`tools/pr/README.md`) and says that a workflow file
changed.

## Report at the end

The two commits; the output of each done-check; `make corpus_judge`'s full output on the unmutated
tree, and the failure record you saw; for each commit, wall time from first edit to green, files
touched, edits that needed judgement against mechanical ones, and verification runs repeated and
why; anything in the plan or in this handoff that the source contradicted.
