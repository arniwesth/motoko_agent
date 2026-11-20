# fable — round 1

Read at HEAD `2eae0666`, clean worktree. Nothing was run beyond `grep`, `wc`, `git log`.

## 1. Current state as it bears on RSI

A self-improvement loop needs a proposer, a guard ("did not break") and a gradient ("got
better"). Motoko has a strong guard, a thin gradient and an acceptance process that still ends in
a human ruling.

- **Guard.** The production driver runs against a seeded world with record, strict replay and 13
  invariant families; `make dst` is 53 targets (`README.md:101`). Reproducibility is real.
- **The oracle is the measured weak part.** On 2026-10-05, 2 of 11 single-site recovery-branch
  mutants survived the whole sweep, each breaking an obligation a family states
  (`.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md:20`).
  A production abort was missed by every family (`011…/NOTE-dst-substrate-versus-oracle.md:48`).
  Two days later the follow-up rules were accepted: the authors' fourteen mutants were all
  killed, a blind reviewer's eight gave six kills and two survivors
  (`011…/evidence/judge-recoveries/acceptance-ce9cb247/README.md:17-23`). That is 100% on
  mutants the author wrote and 75% on ones it had not seen. Whether those survivors stand today
  is `[unverified]`.
- **Acceptance is slow and not mechanical.** Warm sweep 1,770–1,875 s against a planned 196 s,
  3.7 minutes per targeted mutant, because `session.ail` exceeds the compile-cache limit (spike
  note `:179-183`; the file is 5,959 lines at HEAD, `wc -l`; today's sweep time `[unverified]`).
  `corpus_pr`'s verdict depends on wall time (`:481`). Reds are standing:
  `DST_KNOWN_RED := declared_vs_performed` (`Makefile:717`), and `eval_matrix` had "66 rows red
  on both sides" (`.agent/projects/041_process_execution_timeouts/RECORD-session-W1-W5-2026-11-02.md:42`).
  PLAN-004's measurement was blocked on adjudicating 14 regen fails, after a part that took 37
  attempts (`.agent/projects/013_core_architecture_for_dst/HANDOFF-2026-09-20-plan004-p24-parked.md:24-25`).
- **A candidate evaluator exists, and is narrow.** `scripts/eval/candidate.py` pins the
  evaluator at a commit, refuses `EvaluatorTouched` and `ProtectedRegionTouched` (`:32-34`) and
  scores only `Reproduced` (`:18`). It admits one intent, `resource-only` (`:165`), refuses by
  path every change to prompts, extensions, tool catalogue, provider adapters, config and tool
  implementations (`:185-200`), and claims no task quality
  (`013…/ADR-004-journal-as-evaluation-source.md:1114`). Its trust model is "Cooperative,
  reviewed candidates; witnesses, not isolation" (`:432`).
- **Gradient.** The tree holds two "better" signals: allocated bytes (ADR-004 D4, `:1109`) and
  mutants killed. Every other gate is pass/fail, and the empty change passes all of them.
- **Finding.** The defects that mattered came from live sessions: compaction silently off,
  broken examples, unusable delegation, "absence renders as health"
  (`.agent/projects/028_verified_runtime_closing_the_loop/README.md:98-99`), a 197-step runaway
  (`:58`). Delegates empty-stop on about 17% of the longest briefs (`013…/HANDOFF…p24-parked.md:48`).
  A fix set came back 60% defective, every defect a test that does not discriminate
  (`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md:40-41,55`).
- **Competence is unmeasured.** Polyglot runs Python only; Terminal-Bench is not turnkey; Harbor
  is a placeholder (`benchmarks/README.md:7,16,18`).

## 2. The first closed loop: Motoko improves its oracle, scored on faults it has not seen

**What gets improved.** The checks that accept Motoko's changes: `src/core/dst_invariants.ail`,
fixed-corpus members and their `scripts/dst/` wiring. This is the accepting process itself, and it
is the one place where the tree already has a gradient.

**What proposes.** A Motoko session on a fixed model and profile. It receives the *visible*
survivors as paired traces (the same seed with and without the fault) and may write to the oracle
surface only. One rule per candidate commit, per the batch-size rule (meta-decision `:38-47`).

**What accepts.** A script at a pinned commit E in its own worktree. It reuses `candidate.py`'s
assembly and refusals with a new intent, `oracle-only`, whose refused-path list is the inverse of
today's: driver, generator and evaluator. Accept if and only if:

1. the unfaulted tree is green, and so are the K most recent merged commits. This is the
   false-alarm control, the direction mutation cannot see (`tools/test_coverage/mutants.py:8-9`);
2. held-out kills rise, a kill being the candidate's named rule firing;
3. no fault killed before is now missed;
4. targeted-gate wall time stays within 1.15× of baseline.

**Why the evaluator is outside the candidate's influence.**

- Held-out faults have two sources the proposer did not author: mechanical single-site mutants
  generated at E, and **reverts of historical driver fixes**. Twenty-five `fix` commits touch the
  driver files (command above the YAML). History predates the candidate and cannot be edited.
- The candidate cannot touch what is mutated (the driver) or what scores (E's files, overlaid on
  the candidate tree as `candidate.py` does today, `:36-45`).
- The held-out half sits outside the proposer's mount; a sandbox exists
  (`.devcontainer/agent_sandbox/README.md`). A `0700` directory under the same user is not
  enough, as ADR-004 concedes (`:62-65`).
- One channel remains: rules keyed to a mutation operator's syntactic footprint. The
  historical-revert half and the held-out split exist to detect that.

## 3. The first experiment

**Part A, baseline, no model.** Harvest about 20 fix reverts that apply and type-check at one
commit, plus about 20 mechanical mutants in recovery and termination branches, the spike's eleven
among them. E splits them by hash into visible and held-out halves. Run the targeted gate set on
each and classify it as detected, non-detected, non-propagated or non-activated
(`.agent/projects/039_systematic_mutation_testing/NOTE-dst-and-mutation-testing-as-one-method.md:61-66`).
The detection rate on real reverted fixes is a number I did not find anywhere in the records.

**Part B, the loop.** Up to five Motoko candidates, one rule each, written from the visible
survivors and judged by E.

Pass, all of:

- Part A gives a mechanical verdict for every fault on a green unfaulted baseline, with no human
  ruling.
- Accepted candidates raise held-out kills by at least 2, at least 1 of them a historical
  revert, with zero reds on the unfaulted tree and on K=5 known-good commits, inside the time
  bound.
- At least 3 of 5 proposer sessions end unattended with a committed candidate.

Fail, any of:

- The baseline needs adjudication. The first work item is then a green targeted gate whose
  verdict does not depend on wall time, and no loop.
- Visible kills rise and held-out kills do not.
- A candidate accepted on kills turns a known-good commit red.
- Fewer than 3 of 5 sessions complete.

**Cost.** Build: 4–6 agent-days for the harvester, the split and mount, the `oracle-only` intent
and a classifying wrapper around the existing `mutgate.sh`. Compute: 40 faults × 3.7 minutes is
about 2.5 hours per pass; baseline, five candidates and controls come to 16–18 hours with one
heavy run at a time. Model: five sessions; a 70-step session measured about 8.2M input tokens at
about 96% cache reads (`028…/README.md:65`), so tens of dollars `[unverified]`.

## 4. What compounds, and what breaks first

The loop compounds only where iteration *n* lowers the cost or widens the reach of iteration
*n+1*. There are three multipliers.

1. **Verdict cost.** Bringing the driver module back under the cache limit is worth roughly 9× on
   sweep time. A behaviour-preserving split of `session.ail` is the first driver change a stronger
   oracle should buy.
2. **Admissible class.** An oracle gain counts when it moves a class of change from "reviewed" to
   "accepted mechanically": resource-only, then refactors, then recovery logic. The RSI metric is
   the share of merged changes that needed no human ruling. Kill rate is instrumental.
3. **Fault supply.** Mechanical operators saturate and the signal goes to zero. The renewable
   source is live use: every defect found live enters the held-out set before the proposer sees
   its fix, and the score becomes prospective: of defects later found live, how many did the
   oracle already kill? One rung up, the fault generator is the candidate and its coupling to
   those real defects is the evaluator.

At every rung the last evaluator is evidence the system did not author. A stronger proposer model
is exogenous; harness gains will not supply it.

What I expect to break, in order:

1. The baseline is not mechanical (standing reds, wall-time verdicts; the spike's own reference
   sweep was red on four targets, spike note `:128`). Part A fails before any loop runs.
2. Footprint overfit.
3. Fault supply: 25 driver fixes in six months is thin, and the held-out half is spent within a
   few iterations.
4. False alarms that a sixteen-member bank (spike note `:36`) cannot show.

## 5. Is the DST-centred framing right?

Half. DST is the right guard and the right substrate for the first loop: determinism is what
makes a paired run and a held-out kill count cheap and exact. It is the wrong centre.

- A guard has no gradient. "Evidence that each change left it working" (`README.md:14`) never
  says a change made anything better.
- A simulation holds only what was modelled. 028's defects were absences and integration
  failures, found live.
- The evaluator refuses by path every surface that decides competence (`candidate.py:185-200`).

Centre the framing on a ladder of evaluator independence instead: held-out mutants, repository
history, defects found live, then held-out live tasks, with DST as the lowest and cheapest rung.
The cheapest credible competence rung is the repository's own merged pull requests replayed as
tasks from the parent commit, graded by the tests each one added (P3). The Darwin Gödel Machine
reported benchmark gains from an agent rewriting its own code, and also an agent defeating its own
hallucination check (Zhang et al., 2025, arXiv:2505.22954; recalled from memory, not re-read).
That second result is why each rung here names what the candidate cannot touch.

Command behind "twenty-five fix commits":

```
$ git log --format='%h' --grep='^fix' -- src/core/session.ail src/core/step_machine.ail \
    src/core/recovery.ail src/core/journal.ail src/core/model_phase.ail src/core/tool_phase.ail \
    src/core/hook_phase.ail src/core/agent_loop_v2.ail src/core/supervisor.ail | wc -l
25
```

```yaml
participant: fable
round: 1
position_changed: n/a
top_proposals:
  - id: P1
    title: "Oracle loop on held-out faults"
    one_line: "Motoko proposes invariant rules and corpus members; a pinned evaluator accepts them on kills of faults the proposer never saw (mechanical mutants plus reverted historical fixes), with a known-good false-alarm control."
  - id: P2
    title: "Make the verdict mechanical and cheap before looping"
    one_line: "A targeted gate with zero standing reds, no wall-time-dependent verdict and the driver module under the compile-cache limit; every later iteration pays this cost."
  - id: P3
    title: "Competence rung outside DST"
    one_line: "Replay the repository's own merged pull requests as held-out live tasks, graded by the tests each added, to score the prompt, tool and config changes the DST evaluator refuses by path."
first_experiment:
  what: "Part A: harvest ~20 reverted driver fixes and ~20 mechanical mutants, split by hash into visible and held-out, and classify each against the targeted gate set at a pinned commit. Part B: up to 5 Motoko-authored one-rule oracle candidates written from the visible survivors, judged by the pinned evaluator on the held-out half."
  pass_if: "Part A yields a mechanical verdict for every fault on a green unfaulted baseline with no human ruling; accepted candidates raise held-out kills by >=2 including >=1 historical revert, with zero reds on the unfaulted tree and on 5 known-good commits and targeted-gate wall time <=1.15x; >=3 of 5 proposer sessions finish unattended with a committed candidate."
  fail_if: "The baseline needs adjudication; or visible kills rise while held-out kills do not; or a candidate accepted on kills turns a known-good commit red; or fewer than 3 of 5 proposer sessions complete."
  cost: "Build 4-6 agent-days (harvester, split and mount, oracle-only intent, classifying wrapper on mutgate.sh). Compute ~16-18 h of one-heavy-run-at-a-time machine time at 3.7 min per fault. Model spend: five sessions, tens of dollars [unverified]."
disagreements: []
would_change_my_mind_if: "Part A shows the current gates already detect most reverted real fixes (above ~80%), which leaves the oracle little headroom and makes P3 the first loop; or it shows they detect almost none (below ~20%) because the reverts are non-activated, which says real defects live outside what the simulated world models and again puts P3 first. Also if the sweep is already back near its planned 196 s, P2 drops out."
embargo_notes: "Opened no embargoed file. Saw one embargoed project's commit subject in git log output (6d1f3ae4, 'docs(014): re-read the Gödel-machine lineage research'); did not open the document. Read 028's README (verification loop, not a self-improvement plan) and did not open its VISION-001. Read ADR-004 in 013 (TL;DR, D4, D8 opening, version history items); its subject is an evaluator, not a self-improvement plan."
```
