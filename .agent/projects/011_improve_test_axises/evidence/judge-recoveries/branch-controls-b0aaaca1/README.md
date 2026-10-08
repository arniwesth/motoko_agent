# Two branch controls in `corpus_judge`, and the two mutants that now go red

ADR-003 ruling 18, which takes up *Not decided* item 10. Measured on `b0aaaca1` plus this change,
AILANG v0.47.2, 2026-10-07.

## The result

Acceptance left two blind mutants alive, B2 and B3, each on a branch no bank member walks. The
gate now has one control run on each branch. Both are clean unmutated, and each mutant is red on
its control by the rule that names it. The sixteen members and the other three controls stay
clean under both.

| run | make's exit | the control | rules red on it | other rows |
|---|---|---|---|---|
| unmutated | 0 | both clean | none | 20 of 20 clean |
| B2, `tool_phase.ail:615` | 2 | `tool-run-without-approval` | `tool-dispatches-unbalanced` | 19 clean |
| B3, `session.ail:2985` | 2 | `verifier-rejection` | `driver-step-repeated` (the set), `steps-not-contiguous`, `provider-calls-exceed-budget` | 19 clean |

At acceptance both mutants left the gate at exit 0 with every row clean
(`../acceptance-ce9cb247/README.md`, "The two survivors").

## The two controls

Each is the bank's recording rig with one part of its runtime changed, through a helper
`corpus_pr_dst.ail` exports. Neither is a bank member.

- **`tool-run-without-approval`.** The tool policy answers `Allow`. One model turn asks for two
  tools, the world holds one answer for each, and a second turn ends the run. Clean row: steps 0
  and 1, two dispatch records, two tool interactions logged. Beside it the row states what only
  this branch leaves: no approval interaction, and the world's tool queue drained.
- **`verifier-rejection`.** The verifier is on with the command `exit 3`, which rejects every
  answer. Two turns answer, each is rejected, and the run ends on its step budget of two. Clean
  row: steps 0 and 1, `Err` on `max_steps`. Beside it: rejections recorded at steps 0 and 1, and
  the script's third entry never asked for.

The verifier is a real `bash -c` in the working directory. No world answers for it. `exit 3`
reads nothing, writes nothing and prints nothing.

## B3 hung before it went red

The first run of B3 did not end. With the step frozen the run never reaches its step budget, and
an exhausted script serves a terminal answer for ever, each one rejected. The gate was killed by
a 600 s timeout with no row printed. That is not a kill, and it is recorded here as what it was.

The control's script now ends with a provider error that is not retried
(`E_PROVIDER_PROTOCOL`). The unmutated run never asks for that entry, and the row holds it to
that. Under B3 the third call takes it and the run ends, so the defect is three rows red in 42 s.

## Predictions

`prediction.md`, written before either mutant was applied, with an addendum written after B3's
first run and before its second.

- **B2:** every line I was sure of held. The one I was not sure of went the other way:
  `request-ordinals-not-contiguous` stayed clean, as D9 says it would for a successor dropped
  before its witness.
- **B3, first run:** I had named a hang as possible and it happened.
- **B3, second run:** every line of the addendum held.

## The bank is unchanged

`corpus_pr_dst.ail` now builds its runtime in one function with the policy and the verifier as
parameters; the bank's runtime is that function with the values it had. `make corpus_pr`, alone:
exit 0 in 82 s of a 180 s ceiling. Its output, masked as the baseline masks it, has the
baseline's line counts and both of its digests (`corpus_pr.wire.sha256`).

## The sweep

`make dst` on the final tree: exit 0, "all targets passed", 2,179 s, no note. Predicted in
`prediction-sweep.md` in the sweep's first minute. Nothing under `src/core` changes, so the
contract-policy and verify gates have nothing to read.

## What this does not show

- A verifier that accepts after it rejected. No answer is accepted in the control.
- A tool that an extension handles, or either branch on a generated run.
- Whether another gate already saw B2. The comment at `tool_phase.ail:615` says
  `world_state_probe` does. It was not run against the mutant here or at acceptance.

## How it was run

`scripts/run_mutant.sh B2|B3 <output>` applies one edit to a clean tree, runs `make corpus_judge`
under a timeout, and restores the source. The edits are the text of acceptance's
`blind/blind-mutants.tsv`. All three runs below are on the final text of the two scripts.

## Files

| file | what |
|---|---|
| `runs/clean.log`, `.rc` | the gate, unmutated |
| `runs/B2.log`, `.rc`, `.edit` | the gate under B2, its exit and the edit as `git diff` showed it |
| `runs/B3.log`, `.rc`, `.edit` | the same for B3, second run |
| `prediction.md` | the predictions and the addendum |
| `prediction-sweep.md` | the sweep's prediction |
| `corpus_pr.wire.sha256` | the bank's output, fingerprinted |
| `scripts/run_mutant.sh` | the runner |

The first B3 run left no output to keep: the recipe prints nothing until its process ends.
