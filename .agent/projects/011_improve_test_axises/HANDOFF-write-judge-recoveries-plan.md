# Handoff: write the plan that implements ADR-003

Date: 2026-10-06
From: the session that ran the mutation spike (six parts), authored ADR-003 v0.1 and v0.2, and
adjudicated its two reviews
For: a fresh session grounded against HEAD
Deliverable: `PLAN-judge-recoveries-on-real-runs.md` — a WI-numbered execution plan for ADR-003 v0.2

**Write the plan; do not build it.** This is the split
`../../meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md` names: an
implementation plan is source-heavy and belongs to a session fresh at HEAD. The ADR, the findings
note, the two reviews and this handoff are the inputs. A survey of the invariant module, the
execution record's call sites, the corpus gate and the Makefile is the work.

Where this handoff and ADR-003 disagree, **the ADR wins**.

**Where the inputs are.** Until draft PR #223 merges, ADR-003 and everything beside it are on
branch `docs/011-adr-003-judge-recoveries-on-real-runs`, not on `main`. Check which is true before
you start, and read them from wherever they are.

## Your task

Author `PLAN-judge-recoveries-on-real-runs.md`. Its subject is one sentence:

> Add one DST gate that evaluates the invariant set and five two-channel checks on every corpus
> member's real run, change two invariant rules so they read what a wrong recovery changes, and
> accept each rule only on a named source mutant seen red.

**Do not re-derive the decision.** ADR-003 is Accepted as v0.2. The operator has ruled twice, the
second time after two independent reviews and a 24-row run of the amended rules. If you believe a
decision is wrong, say so as a finding against the ADR, not by planning something else.

## Read first, in order

1. **`ADR-003-judge-recoveries-on-real-runs.md`** — the spec. Load-bearing: *Decision* D1 to D10
   with each rule's stated soundness boundary; D6's mutant table, its four precondition controls and
   its known-unseen list; *Rulings* 7 to 12 with their tightenings; *Not decided*; *What a plan
   would sequence*.
2. **`NOTE-spike-findings-mutation-operator-feasibility.md`** — every number. Parts 4, 5 and 6 are
   the ones the plan leans on. *Corrections after REVIEW-001* lists twelve things earlier text got
   wrong; do not re-derive the wrong versions.
3. **`REVIEW-001-adr-003-codex-gpt-6-astra.md`** and **`REVIEW-001-adr-003-claude-fable-5.1.md`** —
   read the disposition tables first. The reviews are where the rules' failure cases are argued.
4. **`evidence/mutation-spike/scripts/prototype2.diff`** and **`spike_families_on_bank.diff`** —
   the prototype of v0.2. A sketch, not the implementation; see *Guardrails*.
5. `../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`,
   `sequence-implementation-handoffs-by-source-surface.md` and
   `re-ground-inherited-anchors-before-building.md`.
6. `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D2 and D7, only
   if you need what governs.

## What is already built or measured, so you do not plan it

Re-ground each against HEAD before citing it. These are this session's claims, observed at
`259265b5` on AILANG v0.47.2, not yours.

| thing | where | state |
|---|---|---|
| the spike's instruments: mutant scripts, runners, scorers, the bank probe | `evidence/mutation-spike/scripts/` | committed; throwaway, never merges; reusable for WI-4 |
| the spike worktree with raw output | `/workspaces/motoko_agent-spike-mut`, branch `spike/011-mutation-operator-feasibility` | local to this container; may be gone |
| the rules as a prototype | `prototype2.diff`, `families_probe3` in `spike_families_on_bank.diff` | not applied anywhere |
| the corpus under the prototype | findings note, part 5 | all 16 members clean on every rule; 24 mutant and control rows as predicted |
| the journal suites under the prototype | findings note, part 6 | `make eval_matrix` identical to its baseline; a known-bad control red |

Costs, measured:

| run | cost |
|---|---|
| the bank probe (16 members, the set and six checks) | about 40 s, nearly all one compile of `session.ail` |
| a targeted gate set per mutant | about 3.7 minutes |
| a full `make dst` sweep | 31 minutes warm, 50 cold |
| `make eval_matrix` | 14 to 18 minutes |

## The work items, and what makes each hard

The ADR's four steps. Whether they are four sessions or fewer is yours to decide, by source
surface; WI-1 and WI-2 both edit `src/core/dst_invariants.ail`.

**WI-1 — the record carries the effective step budget (D4).** `ExecutionUnderTest` is declared at
`src/core/dst_invariants.ail:645` and built in full at `src/core/dst_execution.ail:110` and
`scripts/dst/invariants_dst.ail:409`. `execution_of` (`dst_execution.ail:100`) has five call sites.

- **Four of the five are evaluator files of project 013**: `src/eval/journal/bridge.ail:61`,
  `witness_live_test.ail:295` and `:296`, `candidate_checks_run.ail:108`. The fifth is
  `scripts/dst/stream_parity_dst.ail:269`. Project 013's PLAN-004 is parked and pins its evaluator
  at a commit, so an edit there is a cost to that project. Price it, and say what value each of
  those sites states. The ADR's answer for a caller with no positive budget is *undeclared*.
- **No behaviour changes in this item.** Its green state is a sweep and a matrix that each add
  nothing to their baseline.

**WI-2 — two rules in the invariant set (D2, and D3's family half).** `outcome_agreement_findings`
is at `dst_invariants.ail:1687`, `bounded_progress_findings` at `:1570`, `evaluate` at `:2010`.

- **Each rule gets its own `Violation` constructor.** That touches the type (`:318`),
  `violation_family` (`:381`), `violation_rule` (`:426`), `violation_message` (`:471`) and
  `sample_violations` (`:2306`), and in `scripts/dst/invariants_dst.ail` one mutant row per rule
  (the existing rows are near `:915` to `:962`). Find every place that quotes a count of rules or
  constructors; the ADR says a report draft does and does not say where.
- **D2's table is stated in the invariant module.** It must not call the driver's
  `decision_fail_reason`.
- **`make stream_parity` pins the exact rule set a real run reports.** It must stay as it is.
- **A `src/core` change has gates outside `make dst`**: `make verify_core`,
  `make verify_classify_check` and `make new_contract_policy`. Find out how the last one treats a
  new pure function in a `dst_*` module. The module has no `-- contracts:` line today.

**WI-3 — the gate (D1, D3's gate half, D4's two rules, D5, D9, D10).** One script, one target, in
`DST_TARGETS` (`Makefile:507`).

- **The bank is not importable.** In `scripts/dst/corpus_pr_dst.ail`, `fixed_bank` (`:573`),
  `generated_world` (`:310`), `run_generated` (`:354`) and `run_recording` (`:361`) are private;
  only `main` is exported. The spike copied the file. The plan decides how two gates share one
  bank without moving `corpus_pr`'s pins or its wall clock.
- **The budget must not be a second literal.** `run_generated` and `run_recording` pass `12`. The
  probe hardcodes `12` beside them. The gate's declared budget and the run's must be one value.
- **`corpus_pr` gates on wall time** and is the only member of `DST_TIMED_TARGETS` (`Makefile:632`).
  The new gate is a separate target by ruling.
- **An undeclared budget prints "not evaluated".** By ruling it is never reported as passed.
- **Find out what a new script under `scripts/dst/` must be registered with.** `make test_coverage`
  is first in `DST_TARGETS`; this session did not check what it requires of a new script.

**WI-4 — acceptance (D6).** Run once, at the commit handed in.

- **The four precondition controls come first, the journal callers first among them.** Part 6
  is that control at prototype level only: it had no D4, and its known-bad control covers D2's
  `Err` half and nothing of D3.
- **Two controls need something that does not exist**: a valid retry with two steps of budget
  left (the corpus's retries are at steps 1 and 8 of 12), and a profile whose hook calls the model.
  Say what each costs to build.
- **Then the twelve mutant rows, then a reviewer's own.** Predictions are written before the runs.
  `mutants.tsv`, the script and the commit go into this project's evidence.

## Stop and report rather than deciding

- **If a healthy corpus member or a healthy journal run is red under a rule as implemented.** The
  spike measured all of them clean. A red is a finding, not something to tune away.
- **If any existing pin would have to move**: `stream_parity`'s rule sets, the depth canary, a
  corpus identity. D7 says existing pins are not touched.
- **If sharing the bank changes what `corpus_pr` runs or how long it takes.**
- **If a precondition control needs a new member in the fixed bank.** That changes `corpus_pr`'s
  counters and is an operator call. A scripted scenario is the cheaper place to look first.
- **Anything in the ADR's *Not decided* list.** Nine items. The plan does not settle one inline.
- **How the journal precondition is read.** D6 names `make eval_matrix`. It is red on the unmutated
  tree at `259265b5` on 3 of 28 suites, for reasons that are project 013's. Whether the control is
  the whole matrix read as a difference, or the suites that reach `evaluate`, is the operator's.

## Guardrails

- **Do not copy the prototype.** It reuses two existing constructors, and a reused constructor
  printed a false message in part 4. It computes every gate check in a probe that is a copy of
  `corpus_pr_dst.ail`, and it hardcodes the budget.
- **Read `make dst` and `make eval_matrix` as differences.** Both are red on the unmutated tree in
  the spike worktree: four extension-inventory targets in the sweep, three suites in the matrix.
  "Green" means the failure set of the unmutated tree at the same commit.
- **Run `corpus_pr` alone.** In parallel with other gates it fails its 180-second ceiling with
  every content check green.
- **A kill counts only when the named rule goes red.** A compile failure, a timeout or a different
  check going red is recorded as that.
- **Scope.** D5, D9 and D10 are checks of this gate on the `driver_only` bank. Do not plan them
  into a family rule or onto another profile.
- **Expect to find defects in ADR-003.** Two reviews found v0.1 wrong in four rulings. One to price
  early: D4 puts the budget on the record, and both rules that read it are gate checks. If your
  survey finds the gate is the field's only reader, say so as a finding before you plan four edits
  to evaluator files.

## Calibration ask

Nobody has measured what this costs to build; the spike measured what it costs to run.

- **Before scheduling, establish the baseline at HEAD on a clean checkout**: which `make dst`
  targets and which matrix suites are red, and whether CI agrees. This session saw them red only in
  a spike worktree with a private-path `Makefile` edit.
- **Make WI-1 the first cluster and ask back for its real cost**: time, files touched, and how many
  of the sites needed judgement against how many were mechanical. The rest of the schedule is an
  analogy until that number exists.
