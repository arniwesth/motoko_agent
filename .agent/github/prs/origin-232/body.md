---
repo: arniwesth/motoko_agent
pr: 232
branch: feat/011-corpus-judge-unreached-branch-controls
ticket: null
title: "feat(011): corpus_judge judges the two branches acceptance found unreached — ADR-003 ruling 18"
---

## Summary

Acceptance of ADR-003 left two blind mutants alive, each on a branch no corpus member walks, and
ruling 17 recorded both as known and not seen. This takes up *Not decided* item 10: the
`corpus_judge` gate gains one control run on each branch, and each mutant is now red on its
control by the rule that names it.

**No file under `src/core` changes.** Two scripts under `scripts/dst`, ADR-003 and an evidence
folder.

**The ADR gains ruling 18**, with the operator's words. The wording of D5's premises for the
control runs is this pull request's, and stands as merged.

## Changes

- feat(011): corpus_judge — two branch controls, a tool run without an approval and a verifier rejection
- docs(011): ADR-003 ruling 18 — the two unreached branches are judged, and the evidence for it

16 files changed.

| file | what |
|---|---|
| `scripts/dst/corpus_pr_dst.ail` | the rig's runtime is built in one function with the tool policy and the verifier as parameters; two run helpers exported for the controls |
| `scripts/dst/corpus_judge_dst.ail` | the two controls, `tool-run-without-approval` and `verifier-rejection`, and what each must leave behind |
| `ADR-003-judge-recoveries-on-real-runs.md` | ruling 18; the scope paragraph after D10; D6's lists; item 10 |
| `evidence/judge-recoveries/branch-controls-b0aaaca1/` | three runs of the gate, the predictions, the bank's fingerprint, the runner |

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`: D1, D3, D5,
  D10, D6's known-unseen list, *Not decided* item 10, rulings 17 and 18
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md`,
  "The two survivors": where the two mutants come from
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/branch-controls-b0aaaca1/README.md`
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## The two controls

Each is the bank's recording rig with one part of its runtime changed. Neither is a bank member,
and `corpus_pr` runs neither.

| control | what changes | the script | clean row |
|---|---|---|---|
| `tool-run-without-approval` | the tool policy answers `Allow` | one turn asks for two tools, the world holds an answer for each, a second turn ends the run | steps 0 and 1, two dispatch records, two tool interactions logged |
| `verifier-rejection` | the verifier is on, command `exit 3` | two turns answer and each is rejected | steps 0 and 1, `Err` on `max_steps` |

A control that never reached its branch would be green and worthless, so each row also states
what only its branch leaves behind: no approval interaction and a drained tool queue; rejections
recorded at steps 0 and 1 and the script's last entry never asked for.

**The verifier is a real process.** `run_dp7_verifier` runs `bash -c` in the working directory
and no world answers for it. `exit 3` reads nothing, writes nothing and prints nothing. The gate
already ran with the process capability.

**D5's premises.** The world records, no hook calls the model, and the counts are a delta over
the starting log. The changed parts are the policy's answer and the verifier, and neither is a
hook that calls the model. So the invariant set and all six checks are held against the controls
as against a member.

## Results

On `b0aaaca1` plus the first commit. The mutants are acceptance's blind rows B2 and B3, text from
its `blind/blind-mutants.tsv`. At acceptance both left the gate at exit 0 with every row clean.

| run | make's exit | red on the control | other rows |
|---|---|---|---|
| unmutated | 0 | none | 20 of 20 clean |
| B2, `tool_phase.ail:615` | 2 | `tool-dispatches-unbalanced`: 2 dispatch records, 0 tool interactions logged | 19 clean |
| B3, `session.ail:2985` | 2 | `driver-step-repeated` in the set, `steps-not-contiguous` with steps 0, 0, 0, `provider-calls-exceed-budget` | 19 clean |

**B3 hung before it went red.** Its first run did not end: with the step frozen the run never
reaches its step budget, and an exhausted script serves a terminal answer for ever, each one
rejected. The gate was killed by a 600 s timeout with no row printed. That is recorded as a hang
and not as a kill. The control's script now ends with a provider error that is not retried. The
unmutated run never asks for that entry, and the row holds it to that. Under B3 the third call
takes it and the run ends red in 42 s.

## Predicted outcome

Written before each run, in the evidence folder's `prediction.md` and `prediction-sweep.md`.

- **B2:** every line I was sure of held. The one I had marked unsure went the other way:
  `request-ordinals-not-contiguous` stayed clean, as D9 says for a successor dropped before its
  witness.
- **B3, first run:** I had named a hang as possible, and it happened.
- **B3, second run:** every line of the addendum held, written after the control changed and
  before the run.
- **The sweep:** exit 0 with no note. Held.

After this lands, a defect on either branch that leaves the bank's sixteen rows clean turns
`corpus_judge` red in the `pr-corpus` job.

## Test evidence

| check | result |
|---|---|
| `make corpus_judge`, unmutated | exit 0 in 43 s; "16 members, the invariant set and six checks, two budget-edge controls, two branch controls" |
| `make corpus_judge` under B2, under B3 | exit 2 each, the rows above; source restored and `src/core` clean after each |
| `make corpus_pr`, alone | exit 0, 82 s of a 180 s ceiling; 1,871 lines, 1,609 of them JSON, both digests equal to the baseline's |
| `make dst` | exit 0, "all targets passed", 2,179 s |

Not run, and why: `new_contract_policy`, `verify_classify_check`, `verify_core`, `verify_ext`.
Nothing under `src/core` changes.

## What this does not show

- A verifier that accepts after it rejected. No answer is accepted in the control.
- A tool that an extension handles, or either branch on a generated run.
- Whether another gate already saw B2. The comment at `tool_phase.ail:615` says
  `world_state_probe` does; it was not run against the mutant here or at acceptance.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
