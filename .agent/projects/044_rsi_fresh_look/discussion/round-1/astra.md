# astra — round 1

## 1. What Motoko can already do

Motoko can execute an experiment someone else designed. In the recorded DST demo, the live model followed prescribed commands, changed one line, observed the failure and restored the original bytes. Ordinary replay agreed with the faulty recording. A separate check caught the missing environment read because its expected count came from the source and scenario. The run took 12 provider calls. This demonstrates execution and gives us a working example of independent evidence. (`docs/motoko-dst-demo-run-2026-10-04.md:8–26`, `:70–95`, `:102–104`)

The decisions about that evidence are themselves a source of defects. In the skills experiment, mutant m06 was marked `KILLED` after the process crashed without a test summary. The scoring code explicitly counted any nonzero exit. In a later toolchain upgrade, a skipped verifier probe made every contract excuse look justified. Changing the probe moved the survey from zero verified functions out of 2,197 to 488 on v0.60.4. These are mistakes with observable right answers. (`.agent/projects/037_skills_system/evidence/p3/mutants.tsv:6`, `.agent/projects/037_skills_system/evidence/p3/mutate.py:95–103`, commit `4bad256e`)

Motoko also has a pinned journal evaluator. Two real prefixes of 57 and 28 calls were admitted in a recorded run. Candidate mode checks a resource-only edit against stored observations and permits scoring after reproduction. For a change intended to alter which experiments the model proposes, I would measure what those new experiments accomplish. (`.agent/projects/013_core_architecture_for_dst/HANDOFF-2026-09-20-plan004-p24-parked.md:16–24`, `scripts/eval/candidate.py:18–45`, `src/eval/journal/candidate_checks.ail:27–32`, `:92–96`)

## 2. The first closed loop

**Let Motoko revise the procedure it uses to find and repair errors in its own acceptance checks.** Start with one editable paragraph appended to the standard system prompt for these jobs. The incumbent paragraph asks Motoko to reproduce a suspect verdict, find an input on which the proposed fix matters, check a nearby valid case, and submit one patch or keep the original. The headless entry point can already load an explicit prompt file. (`src/tui/src/index.ts:674–702`, `src/tui/src/system-prompt.ts:17–42`)

Run that procedure on development cases. Give Motoko, running under the incumbent paragraph, its attempted fixes and the referee's development results. Ask it to identify one recurring mistake and submit a replacement paragraph, capped at 300 words. For instance, m06 suggests asking *which named assertion actually ran?* A concrete test would supply two runs with exit status 1. In one the predicted assertion failed. In the other only an unrelated assertion failed. A repaired scorer should award credit only for the first.

A separate referee decides promotion by testing the **repairs produced under each paragraph**. The referee owns the task draw, reference behaviors, budgets, scoring executable and installed prompt pointer. The proposing worker gets a source snapshot stripped of history and answer-bearing fixtures. After it exits, the referee exports only the permitted patch and a data-only witness. It runs the patched checker in a disposable process isolated from the referee's files and network, sends inputs and compares returned values against expectations outside that process. The candidate can change the answer its checker returns. It has no write or query access to the expectations or promotion decision. On a win, the referee installs the new paragraph in the experimental profile and invokes it to produce the next revision.

## 3. First experiment and decision rule

Before any model run, freeze eight development tasks and sixteen blind tasks. Keep each root-cause family on one side of the split. The blind set contains four historical checker defects, eight newly planted defects and four correct snapshots paired with plausible false alarms. Give each worker the intended rule, the reported symptom and the relevant module. The worker must decide whether the report is accurate and locate the cause. For example, the coverage checker takes test records and returns findings, and the journal matrix joins an expected result to an observation. Both can be exercised with ordinary data. (`tools/test_coverage/derive.py:347–395`, `scripts/eval/candidate.py:1584–1595`)

Qualify each task before sealing it. A defective snapshot must fail a named behavior check that its reference fix passes. A correct snapshot must pass as supplied. Include legitimate acceptances and rejections in every hidden suite. For each blind task, run both paragraphs once in fresh workers, randomizing their order within each pair. Pin model version, decoding settings, tools and task text. Cap each run at ten minutes and 25,000 cumulative input plus output tokens including retries. Freeze the challenger before either arm sees a blind task.

A repair earns one point only if the referee reproduces the submitted witness on the original, gets the specified correction on the patch, and sees every hidden regression and valid control pass. A correct snapshot requires a no-change decision. A crash, missing answer or exhausted budget scores zero.

**Pass** if the revised procedure alone solves at least five of the twelve defects, including at least one historical and one newly planted defect, preserves every incumbent success and leaves all four correct snapshots alone. Verify closure by recording the winning paragraph's digest on a new development run that produces a successor proposal. Otherwise the experiment fails. If task qualification fails, report an invalid experiment and retain the incumbent.

**Estimated cost** is two to four engineer-days, mostly to qualify the cases. Eight development runs, one revision, 32 paired evaluations and one successor run give a maximum of 42 headless sessions, 1.05 million model tokens and seven serial worker-hours. Case availability and preparation time are estimates [unverified].

## 4. What would compound

A first win earns deployment for checker maintenance. To test whether the *ability to improve the procedure* has increased, give two authors the same copy of the winning paragraph to edit, the same new development failures and equal budgets. Run one author under the original instructions and the other under the promoted instructions. Judge their two offspring on fresh families against that common starting paragraph. Repeat on later checker failures discovered in ordinary work. More independently accepted repairs per fixed budget from the promoted author's offspring would be evidence of compounding. Merely inheriting a better starting paragraph cannot explain that difference.

I expect to run out of independent failure families first. Ten renderings of the same skipped-test bug can reward one memorized sentence ten times. Retire each blind set after one decision, count root causes, and record the cost of obtaining fresh cases. If a fixed checklist matches successive offspring on prospective failures, keep the checklist and stop spending calls on revision.

## 5. Where DST belongs

I would center this work on the quality of Motoko's next proposed repair. DST should supply a witness when the disputed behavior belongs to the driver. Its own acceptance history illustrates the value and the boundary. All fourteen prescribed mutations triggered the named checks, while two of eight blind mutations survived on lines the bank never ran. That finding justified looking for different cases. For a checker that misreads a test result, a recorded result and its expected disposition already give the necessary witness. (`.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md:15–24`, `:82–99`)

```yaml
participant: astra
round: 1
position_changed: n/a
top_proposals:
  - id: P1
    title: "Let Motoko improve how it repairs its own acceptance checks"
    one_line: "Promote a Motoko-written repair procedure when its downstream fixes win a blind paired trial, then use it to write the next revision."
first_experiment:
  what: "One self-revision from eight development runs, followed by paired trials on twelve defects and four correct snapshots."
  pass_if: "At least five challenger-only defect repairs, including one historical and one planted, no incumbent success lost, all four correct controls retained, and a successor proposed under the promoted procedure."
  fail_if: "Any promotion or closure criterion is missed. An unqualified case invalidates the experiment before scoring."
  cost: "Estimated 2–4 engineer-days and at most 42 live sessions, 1.05M model tokens and seven serial worker-hours."
disagreements: []
would_change_my_mind_if: "A fixed checklist matches the offspring of promoted procedures on fresh, prospectively collected checker failures at equal cost."
embargo_notes: ""
```
