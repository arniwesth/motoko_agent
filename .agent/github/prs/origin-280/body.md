---
repo: arniwesth/motoko_agent
pr: 280
branch: arniwesth/034-w1-world-and-catalogue
ticket: null
title: "feat(dst): world truth for tool faults, fault-catalogue/3, and fault on every harness fault message (034 Phase 1)"
---

## Summary

This is Phase 1 of 034 ADR-001 (`034/PLAN-001` workstream W1, tasks `034/PLAN-001/W1.1` to `034/PLAN-001/W1.8`). Phase 0 (#277) put a `fault` object with `kind` and `effects` on the live renderer. Phase 1 gives the deterministic world a ground truth to check that claim against, and extends the claim to every fault message the harness builds itself.

- A scripted tool fault now says whether its effect **applied** (world truth). The tool never reports this, so it never reaches the wire. The world keeps an append-only **effect log** of what actually happened.
- A recorded program carries the applied faults (`execution-program/5`). The catalogue names the two **world-only** fault classes, "applied, then reported failed" and "applied, then deadline" (`fault-catalogue/3`). The generator draws the dispatch stage and `applied` (`generator_version` "2").
- The typed renderer and the harness's own fault, denial, undecodable-argument and deferral messages now emit `fault`, as the live renderer does since #277.

**This changes the model-facing wire for those messages (ADR D5's cost).** `ToolFailed`, `ToolDeadlineExceeded` and `ToolCorrelationMismatch` from the typed path, policy denials, undecodable arguments and delegated deferrals each gain `"fault":{…}` right after `"tool"`. A message that is not a fault is byte-identical to before. Journals replay pre-W1 bytes verbatim and are never rebuilt (W1.4).

**Phase 1 moves 5 `eval_matrix` rows from pass to fail, as planned.** Under Option A (below), the evaluator's `manifest-A` is not regenerated here, so 5 protected-region rows see W1's edits to protected spans first. A separate evaluator pull request after this merges moves A and regenerates the manifest. The label those rows observe is `changed:<imports:1>`, not the `changed:WorldState` W1.1 predicted. The cause is W1.5's import in `dst_fault_catalogue.ail`; see *Predicted outcome*.

## Changes

- docs(034): re-ground Phase 1, settle versions, and record W1.1 lists (034 W1.1)
- feat(dst): ScriptedTool applied and stage, execution-program/5 world-truth header (034 W1.2)
- feat(dst): world effect log, token re-seat, and applied_faults recording/replay (034 W1.3)
- feat(core): typed fault, denial, undecodable and deferred messages emit fault (034 W1.4)
- feat(dst): fault-catalogue/3 visibility, world-only rows and wire guard (034 W1.5)
- feat(dst): generator draws stage and applied, generator_version 2, canary and PR bank (034 W1.6)
- test(034): Phase 1 mutation run v01-v22 at f160eebb (034 W1.7)
- fix(dst): satisfy new_contract_policy on pinned_canary_v3 (034 W1.6)
- test(034): Phase 1 baseline after W1.7 matches W1.1 predictions (034 W1.8)
- docs(034): ADR and plan status record Phase 1 in #280 (034 W1.8)

What each part does:

- **W1.1, re-grounding at `a94204aa`** (`RECORD-W1.1-regrounding-a94204aa.md`). The 25 Phase 1 source paths are byte-identical to `e69aaad7`. Eight anchors that were already wrong are corrected. It settles the versions: `execution-program/5`, `fault-catalogue/3`, `invariant-set/3` for W2, generator "2" at the producers only, and one bump per profile (`driver_only` 38, `no_ops` 27, `compose` 19, `herdr` 8). It records three lists:
  1. **List 1, the program builders and literal sites W1.2 breaks.** 3 `WorldState` literals, 20 `ExecutionProgram` literals (ten builders, the journal's `admission_program`, the decoder, fixtures and tests, and one evidence file not moved), 42 `ScriptedTool` literals, 7 anonymous `ScriptedTool`-shaped record types and 10 `ToolFailed` constructions. Found by `evidence/W1.1/litscan.py`. It also lists the 3 evaluator asserts of `execution-program/4` that W1.2 moves to `/5`.
  2. **List 2, every `generator_version` site.** 18 lines. Four producers move to "2" (`corpus_pr_dst`, `seeded_generator_dst`, `corpus_rotating_dst`, `export_trace`). The fixture literals, recorded evidence and comments stay. The list also covers the sites the pattern does not match (axis K, the canary pair, `versioned`) and the readers of the value.
  3. **List 3, the `eval_matrix` rows W1 is predicted to move.** Measured on a scratch clone by `evidence/W1.1/predict_matrix.sh`. 6 rows that pass move: `MATRIX.expected.tsv:477-481` and `:610`. 10 rows that already fail on the stale `manifest-A` (`:483`, `:492`, `:542`, `:556`, `:557`, `:560`, `:563`, `:565`, `:566`, `:567`) change their observed finding from `changed:<imports:1>` to `changed:WorldState`. The 4 rows that assert `/4` (`:189`, `:191`, `:193`, `:426`) are predicted not to move. W1.4's journal fixture was expected to add rows.
- **The `manifest-A` arrangement, Option A, which the operator accepted on 2026-10-18** (RECORD §6). W1 does not edit `tools/eval_protected/`, `scripts/eval/` or `MATRIX.expected.tsv`. W1.8 accepts `make eval_matrix` if the changed rows match List 3. After W1 merges, the operator directs one evaluator change in its own pull request: move `A` (`test_candidate.py:45`) to W1's merge commit, run `protected.py gen --at <merge> … --allow-flags`, review the closure against 119 spans and 14 flags, then `pins`, `selftest.py` and `make eval_matrix`. W1.2 keeps the closure: the dispatch stage is a `bool`, not a new sum type.
- **W1.2, the stage and world truth in the program.** `ScriptedTool` gains `after_dispatch` (an observation) and `applied` (world truth). `ToolFailed` gains `after_dispatch`. `ExecutionProgram` gains `applied_faults: [int]`, persisted as a required `applied_faults` header line at `/5` only. `/1` to `/4` decode with an empty list. The stage travels in the served payload, and a legacy payload decodes as after dispatch, the conservative value. `applied` never enters the payload or the world token. New rejections: `program-applied-fault-not-a-tool`, `program-applied-fault-repeated`, `replay-refused-applied-fault-completed` and `replay-refused-applied-fault-before-dispatch` (D4). It adds a frozen `execution-program-v5.artifact`.
- **W1.3, the world's effect log.** `WorldState.effect_log` is append-only, with one writer: `world_tool`, for every completed call and every applied fault. World truth never enters the extension token. `ext_world.adopt_world` re-seats it after a hook, at all nine adoption sites, not only the plan's `tool_phase.ail:437`. Every builder in List 1 records `applied_faults`, and replay rebuilds the log from them.
- **W1.4, `fault` on every harness-built fault message.** That covers the typed renderer's three faults (`ToolFailed`: `none` before dispatch, `unknown` after; deadline and correlation mismatch: `unknown`), policy denials (`none`, `denied`), undecodable arguments (`none`) and delegated deferral (`none`, `refused`). `FaultKind` gains four kinds, and every builder renders through `tool_fault`. The profiles take their one bump each, for the re-baselined attribution table. Journals carry pre-W1 bytes, with a new fixture and checks (A2 and K7 unchanged).
- **W1.5, `fault-catalogue/3`.** Every row has a `Visibility`: `Wire`, or `WorldOnly(twin)`. There are two new world-only rows, `tool_effect_applied_then_failed` and `tool_effect_applied_then_deadline`, and their twins are validated (v08 to v11). The coverage observer reads the effect log. A lexical guard enforces standing rule 6: no projected tool message names a world-only id. It runs in `corpus_pr` and `strict_replay`.
- **W1.6, the generator.** It draws the stage (1 in 3 before dispatch) and `applied` (1 in 2, after-dispatch failures and late outcomes only), with `generator_version` "2" at the four producers. The canary pair moves to ("2", "3"). The seeded suite's seeds and the PR bank are re-swept: 17 seeds and the constructed member, with two witnesses for each world-only class. `24d347d2` gives `pinned_canary_v3` the contract `new_contract_policy` asked for (`ensures { List.length(result) == 3 }`).
- **W1.7, the mutation run at `f160eebb`, uid 1001** (`meta.txt`: `uid 1001`). 29 mutants: the plan's 26 (v01 to v22, with v15a/b and v16a to d), all killed, plus v20b and v20c, killed, and v01b, which survived. v01b is equivalent on every pre-v5 artifact in the tree, because the frozen v1 to v4 specimens hold no tool fault. Both controls were green (575 tests and rows, 19 survival rows), and K0 was green. Every mutated file was restored byte for byte.
- **W1.8, the gate and the baseline at `24d347d2`.** See *Test evidence*.

The diff counts 666 files changed. Most are evidence: the per-mutant run logs under `evidence/mutation-w1-f160eebb/runs/`, W1.1's lists and the W1.8 baseline.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md` (and `PLAN-001.dagr.json`; task addresses `034/PLAN-001/W1.1` to `034/PLAN-001/W1.8`)
- `.agent/projects/034_ambiguous_tool_outcomes/RECORD-W1.1-regrounding-a94204aa.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w1-after-24d347d2/README.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w1-f160eebb/README.md`
- `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md` (a note that P2.1 renumbers past `execution-program/5`)

## Predicted outcome

- In a live session, the typed, denial, undecodable and deferral fault messages reach the model with `fault.kind` and `fault.effects`, as the live renderer's do since #277. That is checked by W1.4's exact-bytes tests and mutants v13 to v16d.
- Under DST, a fault whose effect applied is world truth that can be recorded, replayed and covered. Two world-only classes are each reached by two bank seeds, and no world-only id reaches the wire. That is checked by `make corpus_pr`, `strict_replay` and `fault_catalogue`, and by mutants v05 to v12.
- No DST target changes status. Checked, and it holds.
- `eval_matrix`: only rows on W1.1's List 3 change. Checked, and it holds. 5 rows change, all on the list. The other 11 predicted rows read the same string as before, for the reason below.
- No model-in-the-loop run is a gate (ADR ruling 5), so this PR claims no change in model behaviour.

### Baselines, before and after

- Before: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-after-2ac0ff88/` (W0.7's final baseline), and W0.1's `baseline-3ae506cc/`.
- After: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w1-after-24d347d2/`, at `24d347d2`. That is this branch before the W1.8 commit, which adds only that directory.

Every changed row at `24d347d2`, with its cause:

| what changed | cause |
|---|---|
| `eval_matrix` `:477` `M13.ProtectedRegionTouched.span_hash`: `changed:tool_outcome_record` → `changed:<imports:1>`, pass → fail | basis change under Option A. The first finding is now in a protected span W1 changed. On List 3 |
| `:478` `…missing`: `missing:scripted_step_faults` → `changed:<imports:1>`, pass → fail | the same. On List 3 |
| `:479` `…duplicate`: `duplicate:provider_api_model` → `changed:<imports:1>`, pass → fail | the same. On List 3 |
| `:481` `…moved`: `moved:provider_api_model` → `changed:<imports:1>`, pass → fail | the same. On List 3 |
| `:610` `M15.ProtectedRegionTouched.fixture_comment_only`: `changed:has_key` → `changed:<imports:1>`, pass → fail | the same. On List 3 |
| **finding:** the label is `changed:<imports:1>`, not `changed:WorldState`, so `:480` and the 10 already-failing rows on List 3 read the same string as before | W1.5 (`59c16984`) added `import std/string (contains)` to `dst_fault_catalogue.ail`, the first file in manifest order, for the standing-rule-6 guard's `ids_occurring_in`. `protected.py check` at `dd493a1a` gives `ports.ail WorldState` first, as predicted. At HEAD it gives `dst_fault_catalogue.ail <imports:1>` first. The matrix records the label without the file, and the stale `session.ail` imports already gave those 11 rows that label. `:480` still joins `equal`, now on a different file. RECORD §5 anticipated the label change and said the set of rows would stay the same, but the label collision hides 11 of them. Recorded, not fixed. The evaluator pull request must also cover this file's imports |
| `eval_matrix` suite `scripts/eval/test_mem_guard.py`: exit 1 → 0 against the base's run 1 only | the base's run-1 load flake (`baseline-after-2ac0ff88/README.md`). Against its run 2 and against `3ae506cc`, no suite exit differs |
| W1.4's journal fixture: no new matrix rows | `MATRIX.expected.tsv` is untouched under Option A. The new checks have no rows. Their suites exit 0, as at the base |
| DST failed targets: none on either side | |
| `corpus_pr`'s masked wire hash: 1847 → 1907 lines | W1.6's re-derived bank, and W1.4's `fault` on the typed wire |
| the sweep log: profile versions, schema and catalogue versions, catalogue 11 → 13 classes, anchors `tool_phase.ail:388/389/484` → `:403/404/499`, `test_coverage` 657 → 710 tests, re-swept seeds, the new world-truth, v5 and guard rows | W1.2 to W1.6, line by line in the baseline README's table |
| the sweep log: the `motoko_ext_herdr` lock warning, `herdr.ail` effect-site lines, 569 → 571 tracked `.ail` files | #278 and W0b.1 on `main` before the merge base, and W1.7's `bank_replay.ail`. No status changes |

## Test evidence

W1.8, all at `24d347d2`, uid 1001 (`id -u` → `1001`), AILANG v0.52.5, one `make` at a time, all under `env -u AILANG_FS_SANDBOX`:

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core test_coverage seeded_generator fault_catalogue corpus_pr run_report world_state invariants anchors attribution_table` | 0 | 397 s | `src/core/ type-check: 60 passed, 0 failed` … `test_coverage: … 697 of 710 passed, 13 skipped against a record` … `seeded generator: all axes green` … `fault_catalogue_dst PASS` … `the guard read 62 tool-role message(s) across 18 member trace(s)` … `WHOLE TARGET: 74000 ms against a declared ceiling of 180000 ms` … `run_report_dst PASS` … `fault_disclosure_witness PASS` … `invariants_dst PASS` … `attribution_table_dst PASS` |
| `make new_contract_policy verify_classify_check` | 0 | 49 s | `new_contract_policy: 43 in-scope new pure func declarations, all justified` … `verify_classify: 62 contracts, register agrees (59 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |
| `REV=24d347d2 WT=<this worktree> run_baseline.sh` → `make dst` | 0 | 1002 s | `1002s wall, -j8, load 8.05 10.54 7.50` … `all targets passed` |
| the same script → `make eval_matrix --logs` | 2, as at the base | 371 s | `make: *** [Makefile:3540: eval_matrix] Error 1`. The base's 2 suites exit 1: `tools/eval_protected/selftest.py` and `scripts/eval/test_candidate.py` |
| `compare_matrix.py baseline-after-2ac0ff88 <this run>` | 1 | | `rows whose observation differs: 5` (`:477`, `:478`, `:479`, `:481`, `:610`) … `VERDICT: DIFFERS`. Plus `test_mem_guard.py` 1 → 0 against the base's run 1 |
| the same against the base's run 2, and against `baseline-3ae506cc` | 1, 1 | | the same 5 rows, 0 suite exits differ |
| `diff dst-failed.txt` | 0 | | no output. Both empty |
| `protected.py check --manifest tools/eval_protected/manifest-A.json` at `a94204aa`, `dd493a1a`, `24d347d2` | 1, 1, 1 | | first finding `session.ail <imports:1>`, `ports.ail WorldState`, `dst_fault_catalogue.ail <imports:1>`. 2, 11 and 12 findings |

The first W1.8 attempt, at `9405d738`, stopped at gate 1: `new_contract_policy` refused `pinned_canary_v3`. `24d347d2` fixes that, and every gate above was re-run from the start.

The earlier tasks' evidence is in their commits:

- W1.2 to W1.6: each commit message lists its acceptance rows and spot-checked mutants. All of them are covered again by the W1.8 targets above.
- W1.7: `mutate.py` at `f160eebb` as uid 1001 (`meta.txt`: `uid 1001`), 2026-10-18T23:18:03Z to 2026-10-19T00:02:06Z. Then `make check_core`, and `make program_persistence strict_replay fault_catalogue corpus_pr` under `env -u AILANG_FS_SANDBOX`, exit 0.

Not run, or not done:

- **A pre-v5 tool-fault row** in `program_persistence_dst`, which W1.7 handed to W1.8 to close survivor v01b, is not added here. It is a source change, and W1.8's task did not include it. It is open.
- `cd src/tui && bun run test` was not run: W1 does not touch `src/tui`.
- `manifest-A` is not regenerated (Option A). The 5 rows above stay red until the evaluator pull request.
- No model-in-the-loop run was made.
- CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
