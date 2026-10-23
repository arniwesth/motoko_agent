---
repo: arniwesth/motoko_agent
pr: 281
branch: arniwesth/034-w2-properties
ticket: null
title: "feat(dst): P1 and P3 as invariant rules, P2 as an applied-twin pair relation (034 Phase 2)"
---

## Summary

This is Phase 2 of 034 ADR-001 (`034/PLAN-001` workstream W2, tasks `034/PLAN-001/W2.1` to `034/PLAN-001/W2.4`). Phase 1 (#280) gave the deterministic world a ground truth for whether a faulted tool call's effect applied. Phase 2 checks the harness's disclosure against that truth, with the three properties of ADR §2:

- **P1, `effect-disclosure-unsound`** (a rule, `invariant-set/3`). A fault whose effect applied is never answered `effects: none`, and every harness-reported fault message carries `fault.effects` of `none` or `unknown`.
- **P2, `applied_twin_findings`** (a pair relation, not a family). Two programs that differ only in one `applied` field give identical served interactions, outcome, final state and trace. Its runner is `make applied_twin`, in `DST_TARGETS`.
- **P3, `tool-call-redispatched`** (a rule). No call id is dispatched twice and more often than the model emitted it.

**Stacked on #280.** The base is `arniwesth/034-w1-world-and-catalogue`, so this diff is W2 only. Merge #280 first; GitHub then retargets this PR to `main`.

No source outside the DST oracle changes: the harness, the wire and the evaluator are untouched. `make dst` and `make eval_matrix` give the same results as W1's baseline.

## Changes

- feat(dst): P1 and P3 as rules — effect-disclosure-unsound, tool-call-redispatched (034 W2.1)
- feat(dst): P2 as a pair relation — applied-twin findings and runner (034 W2.2)
- test(034): acceptance of P1-P3 by mutant — four kills, predictions hashed first (034 W2.3)
- test(034): Phase 2 gate at 0e09e09d — dst and eval_matrix unchanged against W1, ADR and plan status (034 W2.4)

What each part does:

- **W2.1** (`src/core/dst_invariants.ail`, `scripts/dst/invariants_dst.ail`). `EffectDisclosureUnsound(int, string)` and `ToolCallRedispatched(string)` under `ToolPairing`. Violation constructors 42 → 44, `invariant-set/2` → `/3`. P1 joins each projected tool message to the dispatch it answers, and recognises a harness fault from the run's record, never from the builder (the plan's seven sites, refusals at ordinal -1). P3 counts dispatches in `world.log` against the assistant messages' emissions of the id. The oracle is independent: it calls nothing in `tool_outcome_message`'s tree and restates the wire words. `invariants_dst` gets a conversation fixture with survival and mutant rows.
- **W2.2** (`src/core/dst_invariants.ail` PART 8, `scripts/dst/applied_twin_dst.ail`, `Makefile`, `tools/verify_classify/contracts.register`). Six rules: `applied-twin-served-length`, `-served`, `-outcome`, `-final-state`, `-trace-length`, `-trace-record`. Every side is compared in full, because a variant-only comparison (`trace_positions`) is blind to a content change. The runner pairs each of the 18 bank programs with a twin for each after-dispatch fault, runs every base program twice against itself, and runs 6 controls, each red on its own rule only. `make applied_twin` also reads the runner's `COUNT` line.
- **W2.3** (`evidence/acceptance-w2-8c996274/`). Four mutants of `tool_phase.ail`, predictions hashed before any run: p1a, p1b, p2 and p3 all killed. p1b's row count and p2's member set missed their predictions, and the README says why. Controls C-gate, C-restored, K0, C-invariants and R-reach (P1 and P3 are not vacuous on the bank) all pass.
- **W2.4** (`evidence/baseline-w2-after-0e09e09d/`). The gate. See *Test evidence*. ADR-001 and PLAN-001 status lines name this PR.

90 files changed against #280's head, 5 of them outside `.agent/` (+1449, −71). The rest is evidence.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md` (§2, P1 to P3)
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md` (and `PLAN-001.dagr.json`; task addresses `034/PLAN-001/W2.1` to `034/PLAN-001/W2.4`)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274/README.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w2-after-0e09e09d/README.md`

## Predicted outcome

- Under DST, a harness change that hides an applied effect, drops `fault.effects`, lets world truth leak into what the model sees, or re-dispatches a call now turns a gate red. Checked by W2.3's four mutants: each is red on the rule it targets.
- On the unmutated tree the three properties are clean: `corpus_judge` 18 of 18 members, `applied_twin` 13 of 13 pairs. Checked, and it holds.
- No DST target changes status. Checked, and it holds.
- `eval_matrix` does not change. W2 touches no file in `manifest-A`. Checked, and it holds: 0 rows differ from W1's baseline. W1's 5 rows (pass → fail under Option A) stay as #280 left them, for the evaluator pull request after #280 merges.
- No model-in-the-loop run is a gate (ADR ruling 5), so this PR claims no change in model behaviour.

### Baselines, before and after

- Before: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w1-after-24d347d2/`, W1.8's baseline. W1's commits after `24d347d2` change only `.agent/`.
- After: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w2-after-0e09e09d/`, at `0e09e09d`. That is this branch before the W2.4 commit, which adds only that directory and the two status lines.

| what changed | cause |
|---|---|
| `eval_matrix`: nothing. `VERDICT: IDENTICAL`, 619 and 619 rows, 0 observations, 0 join statuses and 0 suite exits differ. `suites.json` and `join.tsv` byte-identical; `MATRIX.tsv` differs only in the `commit` column | W2 changes no protected file. `protected.py check` against `manifest-A` gives the same 12 findings, byte for byte, as at `24d347d2` |
| DST failed targets: none on either side | |
| `corpus_pr`'s masked wire hash: unchanged | W2 does not change the wire |
| the sweep log: a new `applied_twin` section (43 bank rows, the constructed member, 7 control lines, `COUNT`, `PASS`) | W2.2 |
| the sweep log: `invariant-set/2` → `/3`, 42 → 44 Violation constructors, `dst_invariants.ail` 16/16 → 23/23, `test_coverage` 710 → 717 tests (697 → 704 passed), the P1/P3 fixture's mutant and survival rows | W2.1 |
| the sweep log: 571 → 573 tracked `.ail` files in the pin census | W2.2's runner and W2.3's `p1p3_reach.ail`. The check passes |
| the sweep log: revision, a temp file name, `WHOLE TARGET` 20,000 → 73,000 ms, the slowest-file line; `make dst` wall 1002 → 1336 s | load. Within every ceiling |

## Test evidence

W2.4, all at `0e09e09d`, uid 1001, AILANG v0.52.5, one `make` at a time, all under `env -u AILANG_FS_SANDBOX`:

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core invariants corpus_judge verify_classify_check new_contract_policy` | 0 | 228 s | `src/core/ type-check: 60 passed, 0 failed` … `invariants_dst PASS` (`invariant-set/3`, `all 44 Violation constructors sampled by name`) … `✓ corpus_judge: 18 members, the invariant set and six checks, two budget-edge controls, two branch controls` … `Ran 18 tests … OK` … `verify_classify: 69 contracts, register agrees (64 substantive, 2 tautology, 0 spec-equals-body, 3 unclassified)` … `new_contract_policy: 78 in-scope new pure func declarations, all justified; 59 more out of scope, reachable only from a tests block` |
| `make applied_twin` | 0 | 72 s | `COUNT members=18 ran=18 identical_clean=18 pairs=13 clean=13 to_applied=8 to_unapplied=5 refused=0 controls=6 controls_red=6` … `applied_twin PASS` |
| `REV=0e09e09d WT=<this worktree> run_baseline.sh` → `make dst` | 0 | 1336 s | `1336s wall, -j8, load 5.58 7.72 8.24` … `all targets passed` |
| the same script → `make eval_matrix --logs` | 2, as at the base | 371 s | `make: *** [Makefile:3593: eval_matrix] Error 1`. The base's 2 suites exit 1: `tools/eval_protected/selftest.py` and `scripts/eval/test_candidate.py` |
| `compare_matrix.py baseline-w1-after-24d347d2 <this run>` | 0 | | `VERDICT: IDENTICAL` |
| `diff dst-failed.txt` | 0 | | no output. Both empty |

The gate-1 log carries no `✗`. W2.1 to W2.3 each list their own runs in their commit messages, and W2.3's evidence directory holds every mutant's output.

Not run, or not done:

- `cd src/tui && bun run test` was not run: W2 does not touch `src/tui`.
- `manifest-A` is not regenerated (Option A, as in #280).
- No model-in-the-loop run was made.
- CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
