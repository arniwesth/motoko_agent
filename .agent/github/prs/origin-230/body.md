---
repo: arniwesth/motoko_agent
pr: 230
branch: docs/011-accept-judge-recoveries
ticket: null
title: "docs(011): WI-4 — acceptance of ADR-003's rules at ce9cb247"
---

## Summary

The acceptance run of ADR-003's rules: WI-4 of `PLAN-judge-recoveries-on-real-runs.md`, run once at
`ce9cb247` by a session that built none of it. This PR adds evidence and a verdict per rule, and
the handoff the run was made under. It changes no rule, no gate and no source.

All four preconditions held and every control is green. All fourteen rows of the table are kills
on the rule each names. The blind reviewer's eight rows gave six kills and two survivors, both on
lines no corpus member runs. Six rule ids are accepted; two are held for the operator.

**Ruled since, and recorded here.** On 2026-10-07 the operator accepted the two held rules with
the other six: "I will follow your recommendations". A third commit, by the delegating session,
adds that as ADR-003 ruling 17, lists the two unreached branches in D6's known-unseen list and in
*Not decided* (item 10), updates the ADR's and the plan's status lines, and puts a note above the
result note's text. The acceptance session's own text and evidence are unchanged.

## Changes

- docs(011): WI-4 — acceptance of ADR-003's rules at ce9cb247, fourteen rows killed and two blind survivors
- docs(011): ADR-003 ruling 17 — all eight rule ids accepted; two unreached branches recorded as not claimed

161 files changed, all under `.agent/projects/011_improve_test_axises/`: the handoff,
`evidence/judge-recoveries/acceptance-ce9cb247/`, and with the ruling ADR-003 and the plan.

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`: D6 in full,
  rulings 10, 14 and 16
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`: WI-4, F3
- `.agent/projects/011_improve_test_axises/HANDOFF-accept-judge-recoveries.md`
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md`,
  the result note
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Verdict per rule

The handoff's rule: accepted when every row naming the rule is a kill and every control is green.
Blind rows are counted as rows.

| rule id | decision | table rows naming it | blind rows naming it | verdict |
|---|---|---|---|---|
| `outcome-finish-disagrees` | D2 | 1, 2, 3, 4: kills | B6: kill | accepted |
| `steps-not-contiguous` | D3, gate | 6: kill | B7: kill | accepted |
| `provider-calls-exceed-budget` | D4 | 7: kill, alone | B4: kill | accepted |
| `retry-at-budget-edge` | D4 | 8: kill | B1: kill | accepted |
| `provider-calls-unbalanced` | D5 | 9: kill, log below trace. P3: kill, log above trace | none written | accepted |
| `request-ordinals-not-contiguous` | D9 | 9, 10, 11: kills | B5: kill | accepted |
| `driver-step-repeated` | D3, family | 5: kill | B3: **survived** | **held** |
| `tool-dispatches-unbalanced` | D10 | 12 and 13: kills, one in each direction | B8: kill. B2: **survived** | **held** |

**The question for the operator.** Each held rule has every table row a kill, so it meets D6's
sentence, "accepted when its mutant has been seen red on that rule and the controls green". Each
also has one blind row that no rule printed, so it does not meet the handoff's sentence read over
every row. Which governs, and whether an unreached branch withholds a rule or joins D6's
known-unseen list, is not decided here. Nothing was repaired.

## The two survivors

| | B2 | B3 |
|---|---|---|
| the edit | `tool_phase.ail:615`: the tool fold recurses with `world`, not `executed.next_state` | `session.ail:2985`: the state after a verifier rejection keeps `step_idx` |
| the gate | exit 0, sixteen members clean | exit 0, sixteen members clean |
| measured | no member and neither control evaluates the line | no member and neither control evaluates the line |

The bank's policy hook answers `Pending` for every tool call, and its runtime has verification
disabled. Three reach probes confirm it: the line made to panic if evaluated crashes the gate on
row 12's line and leaves it green on these two. The probes are diagnostic and decide nothing.

## Predicted outcome

Landing this changes no behaviour and no gate: it is documents and evidence. It gives the operator
what a ruling on ADR-003's status needs. After it lands,
`evidence/judge-recoveries/acceptance-ce9cb247/README.md` is the record of what was accepted at
`ce9cb247`, and of what acceptance does not claim: D6's known-unseen list, the two table rows of
F3, ADR-003's *Not decided*, and the two branches the blind survivors are on.

## Test evidence

Everything ran in a scratch worktree detached at `ce9cb247`, AILANG v0.47.2, one edit at a time.
Predictions were hashed before any run (`predictions.tsv.sha256`, `4cde56fe…`).

| what | result |
|---|---|
| `make corpus_judge`, unmutated | exit 0; 16 of 16 members clean; both budget-edge controls clean |
| a comment-only edit in the retry branch | exit 0; 144 rule rows equal to the unmutated run's line for line |
| `make invariants`, `make stream_parity`, `ailang test src/core/dst_invariants.ail` | pass; `stream_parity`'s two pinned rule sets unchanged; 16 of 16 inline tests |
| `make eval_matrix` against `baseline-59d5cbb9` | `VERDICT: IDENTICAL`, 28 suites and 621 rows, 789 s; the three real-run suites exit 0 on both sides |
| known-bad D2 and D3 in `dst_invariants.ail` | `witness_live_test` exits 1 with `A8:outcome-finish-disagrees@aggregate:invariants:outcome-agreement` and with `A8:driver-step-repeated@aggregate:invariants:bounded-progress` |
| a recording run whose pre-step hook calls `ai_step` | healthy; 1 prepared record, 2 provider interactions logged |
| rows 1 to 13 and P3 | 14 kills, each on the rule and the members predicted; none failed to compile or timed out |
| the blind reviewer's rows | 6 kills, 2 survivors; file hash `a042edec…` checked before use, opened after the rows above were scored |
| integrity | the five files ever edited at their starting hashes after each of 28 edits; scratch worktree clean at the end |

Machine time 2,173 s, about 36 minutes. No run was repeated: none timed out and none spanned a
suspend. `scripts/score.py` reads `JUDGE` rows and never exit status; `scripts/score_selftest.py`
passes.

Not run: `make dst`, `make corpus_pr`. Neither is part of WI-4, and this PR touches no code.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
