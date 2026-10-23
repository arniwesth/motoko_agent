# Acceptance of 034 ADR-001 §2's P1-P3 by mutant at `8c996274`: the result

Run on 2026-10-20 for `../../PLAN-001-effect-disclosure.md` W2.3 (`PLAN-001.dagr.json` W2.3: "Mutants
p1a, p1b, p2, p3 of the plan's W2.3 table are each red on the named rule's row; predictions.tsv
hashed before the run; the unmutated bank and make corpus_judge's members and controls are clean on
both rules"). Commit handed in: `8c996274` (W2.2, head of `arniwesth/034-w2-properties`). AILANG
v0.52.5, 8 cores. Pattern: `011…/judge-recoveries/acceptance-ce9cb247/`.

No source was changed. Every mutation was one edit to `src/core/tool_phase.ail` in this worktree,
on its own line so no line below it moved. Each was restored with `git checkout -- src/core/tool_phase.ail`
and checked against `base.sha256` and `git status --short --untracked-files=no` before the next
(`sequence.log`).

## The result

- **Every mutant is a kill on the rule its row names.** p1a and p1b are red on
  `effect-disclosure-unsound`, p3 on `tool-call-redispatched` (all three in `make corpus_judge`), and
  p2 on `applied-twin-trace-record` (in `make applied_twin`), each with all 18 self-pairs clean.
- **Two prediction misses. Neither touches a kill.** p1b has 14 red rows where 13 were predicted:
  seed-215 has four tool-fault messages, not three. p2 is red on 4 members where 5 were predicted:
  seed-61's ToolFailed comes *before* dispatch, so it has no twin pair (the bank's 13 pairs include four
  from seed-215). Both misses are in how the bank was read before the run, not in the rules.
- **The properties are orthogonal, as predicted.** P2 does not see p1a or p1b (applied_twin stays
  identical to C-gate's rows, line for line). P1 does not see p2: corpus_judge stays fully clean, with
  18/18 members and 4/4 controls clean, under a mutant whose message reads world truth. p2 is sound
  (it says `none` only where nothing applied) and present (it always discloses), so only the pair
  relation catches it.
- **Survival: the unmutated bank is clean on all three properties.** C-gate and C-restored: corpus_judge
  exit 0, 18/18 JUDGEROW and 4/4 CONTROLROW clean, no RED row. applied_twin exit 0 with
  `COUNT members=18 ran=18 identical_clean=18 pairs=13 clean=13 to_applied=8 to_unapplied=5 refused=0 controls=6 controls_red=6`.
  K0, a comment-only edit, matches C-gate's rows line for line. `make invariants` passes, with
  W2.1's 20 P1/P3 rows ✓.
- **The two rules are held on corpus_judge's members and controls.** On every row, every mutant
  included, the four `CONTROL` runs are clean (0 CONTROL RED in all 7 gate runs). How much each rule
  reads there is measured by `p1p3_reach.ail` (R-reach):
  - **Members: P1 and P3 are non-vacuous.** 11 of 18 members carry 14 harness fault dispatches,
    5 of them applied (seed-11, 14, 102, 165, 215: P1's soundness half). 35 refusal-answered calls are
    read by P1's presence half, and 62 projected tool messages, 49 of which disclose. On every member,
    `disclosing == fault_disp + refusals`. 12 members dispatch 27 tool calls under 27 distinct ids, and
    62 ids are emitted (P3), with 0 re-dispatches.
  - **Controls: P3 is non-vacuous on one of the four, P1 on none.** `tool-run-without-approval`
    dispatches 2 calls under 2 ids with 2 emissions, and answers both with completions. The other
    three dispatch nothing and project no tool message. No control draws a fault or a refusal, so on
    all four controls P1 is clean because it has nothing to read. That follows from how
    corpus_judge's controls are built: they test the budget edge and two driver branches, not
    tool faults. This acceptance does not change them. P1's real-run evidence is the members, and
    p1a and p1b show it firing there.

## The rows

"Seen" is the set of members whose output holds the named rule red: `JUDGE <member> <rule> RED` for
corpus_judge, and a ✗ twin-pair line naming the rule for applied_twin.

| id | one edit (`src/core/tool_phase.ail`) | gate | rule named | predicted | seen | red rows | verdict | also red, same gate | other gate |
|---|---|---|---|---|---|---|---|---|---|
| p1a | `:293` `failed_fault(f.after_dispatch)` → `failed_fault(false)`: every ToolFailed renders `none` | corpus_judge | `effect-disclosure-unsound` | seed-102, 165, 215 at #15, #17, #32; 3 rows | the same 3, at #15, #17, #32 | 3 | **KILL**, as predicted | none, as predicted | applied_twin unchanged (C-gate's rows), as predicted |
| p1b | `:313` the `fault` object keeps `kind` and `note` and drops `effects` | corpus_judge | `effect-disclosure-unsound` | the 11 tool-fault members; 13 rows | the same 11 | **14** (seed-215: 4) | **KILL**; row-count miss | none, as predicted | applied_twin unchanged, as predicted |
| p2 | `:515` an after-dispatch ToolFailed whose dispatch did not grow the effect log renders as before dispatch (`none`) | applied_twin | `applied-twin-trace-record` | pairs of seed-61, 71, 102, 165, 215 | seed-71 #17, seed-102 #15, seed-165 #17, seed-215 #32 | 4 pairs (9 of 13 clean) | **KILL**; member miss (seed-61) | `-outcome` on 71, 102, 165 (as predicted); `-final-state` on the 4 (predicted on 5); `-served`, `-served-length`, `-trace-length` on none (as predicted); self-pairs 18/18 ✓; controls ✓ | corpus_judge fully clean, as predicted: P1 cannot see it |
| p3 | `:507` a ToolDeadlineExceeded dispatch is dispatched once more, same invocation | corpus_judge | `tool-call-redispatched` | seed-11, 14, 60, 109, 215; 5 rows | the same 5 | 5 | **KILL**, as predicted | `tool-dispatches-unbalanced` `log above trace` on the same 5 (as predicted); `effect-disclosure-unsound` on seed-215 #47 (not predicted either way) | applied_twin passes (16 pairs, all clean; not predicted either way) |

p3's extra P1 row on seed-215 is the P1 join seeing the re-dispatch: the one message for
`gcall_20_912` is joined to the first dispatch, a deadline fault, but carries the second dispatch's
answer. So a harness-reported fault went without a disclosure. This is a true second finding of the
same defect, not noise.

## Controls

| id | what | expect | seen | verdict |
|---|---|---|---|---|
| C-gate | both gates, unmutated, before any mutant | corpus_judge exit 0, 18/18 + 4/4 clean, no RED; applied_twin exit 0, 13/13, 18/18, 6/6 | exactly that (176 judge rows, 53 twin rows) | PASS |
| K0 | `:515` a comment appended | rows equal C-gate's line for line | equal | PASS |
| C-invariants | `make invariants` | `invariants_dst PASS`, W2.1's P1/P3 rows ✓ | PASS; 97 ✓, 0 ✗; 20 of 20 P1/P3 rows ✓ | PASS |
| R-reach | `p1p3_reach.ail`, unmutated | 8 clauses (`predictions.tsv`) | 8 of 8 hold | PASS |
| C-restored | both gates after the last mutant | equal to C-gate | equal, line for line | PASS |

Not a row of the table: `make check_core` on the restored tree exited 0, printing
`src/core/ type-check: 60 passed, 0 failed` (`runs/check_core.log`; `verify_native_path_guard`
passed on its first run).

## Files

| file | what |
|---|---|
| `predictions.tsv`, `predictions.tsv.sha256` | the predictions and scoring rules S1-S8, hashed before any run (`sha256 00eb4d3d…`) |
| `sequence.log` | every step, timestamped: the hash first, then each row's apply, gate exits, restore and integrity |
| `base.sha256` | `src/core/tool_phase.ail` at `8c996274`, the one file ever edited |
| `mutants.tsv` | the scored rows, written by `scripts/score.py` from the runs |
| `runs/<id>/` | `apply.log`, `mutant.diff`, `judge.out` (`make corpus_judge`, every non-wire line), `twin.out` (`make applied_twin`), `*.rc`, `rc`. A red recipe's kept trace was counted and deleted, as the precedent did |
| `runs/C-invariants/invariants.out`, `runs/R-reach/reach.out` | the unit fixtures and the reach probe |
| `runs/typecheck*.log` | each edit and the probe type-checked before the hash, and nothing run |
| `scripts/apply_mutant.py` | the five edits; `check` verifies each occurs once (`scripts/apply-check.txt`) |
| `scripts/run_row.sh`, `scripts/run_all.sh` | apply → both gates side by side → `git checkout --` → hash and status check |
| `scripts/typecheck_mutants.sh` | the pre-hash type-check |
| `scripts/score.py` | S1-S8, read from the gates' rows; exit status is not a verdict |
| `p1p3_reach.ail` | what P1 and P3 read per member and control; run with `--relax-modules` |

Reproduce, from the worktree root, on a clean tracked tree at `8c996274`:
`.agent/projects/034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274/scripts/run_all.sh`, then
`python3 …/scripts/score.py …/acceptance-w2-8c996274 > …/mutants.tsv`. Delete `base.sha256` and
`runs/` first, or `run_row.sh` keeps the old baseline.
