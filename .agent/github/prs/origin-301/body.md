---
repo: arniwesth/motoko_agent
pr: 301
branch: arniwesth/041-w5-program-v6
ticket: null
title: "feat(dst): add execution-program/6 with every writer legacy (041 W5)"
---

## Summary

Task `041/PLAN-001/W5`. `InitialWorld` gains `process_limits: LimitMode` and the program schema moves to `execution-program/6`, with `/5` kept in `decodable_schema_versions` by name. Every writer stamps `legacy`, the mode crosses the extension token, and a frozen `Limits` specimen proves the copy in `world_state_of` that the compiler cannot flag.

**Nothing activates.** Standing rule 6 keeps every live world `Legacy`, and the new C2 guard asserts that. No run behaves differently because of this pull request.

## Changes

- `dst_program`: the field, the version bump, `/5` by name, and `CeilingDefect` with D7's four rejections, read by both `validate_program` and the decoder.
- `dst_persistence`: C5's line, `process_limits<TAB>legacy` or `process_limits<TAB>limits<TAB><default><TAB><ceiling>`, required from v6 through `version_has_process_limits`. It is the schema's only line with two shapes, so `parse_line` takes its arity from the first field. Each ceiling defect has its own decode rule.
- `ports`: `WorldState.process_limits`, `Legacy` in `empty_world_state`. `dst_replay.world_state_of` copies it.
- `ext_world`: the token carries the mode as text, because `std/json` holds numbers as floats and `2^53 + 1` nanoseconds would not survive. An absent key or a value the codec did not write decodes as `Legacy`. `adopt_world` re-seats from `pre`.
- Writers: every `InitialWorld` literal states `Legacy`. The pins in `dst_program`, `scan.ail`, `admission.ail` and `admission_live_test.ail` move to `/6`.
- `program_persistence_dst`: byte identity moves from v5 to v6, and v5 is decode-only. There are two new frozen specimens. Frozen v0-v5 bytes are untouched.
- `world_state_probe`: the C2 guard, entry `c2_guard`, run by `make world_state`. W12 removes it.
- W1's R6 test now asserts `Legacy`, and `r6_transcoded_replays_strict` is new.

**Two decisions for review.**

1. **The `Limits` specimen is a separate, smaller program from the legacy specimen.** `world_state_of` decodes every payload, and the legacy specimen's payloads are placeholders it refuses, so that specimen cannot reach the assertion p4 needs. The plan's two artifacts stay as named: `-v6.artifact` holds every identity class, and `-v6-limits.artifact` holds two codec-written interactions.
2. **The C2 guard is its own entry point, not part of `main`.** It reads `session.ail` to hold `ported_provider`'s private `LiveAI` arm. My first version was inside `main`, and `make world_state`'s filesystem poison pair correctly refused it, because `main` must complete with FS withheld. This also avoids exporting a function from `session.ail`, which C3 keeps line-neutral and #287 is editing.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`: D7, "Program modes" and "The extension token".
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`: W5, C2 and C5, standing rules, R11.
- Evidence: `.agent/projects/041_process_execution_timeouts/evidence/W5/`.

## Predicted outcome

### Matrix rows, predicted before the run

**Predicted: no `make eval_matrix` row changes between `f3e77a19` and this branch.** No row moves in either direction, and no first finding changes.

This differs from the plan, which says "W5, W6 and W10 move `eval_matrix` rows, as 034 W1 did". The measurement is `evidence/W5/predict_matrix.sh`, 034's method without the simulated widening, because this source exists. `predict_matrix.out` holds the result:

- **`protected.py check` against `manifest-A`: 16 finding keys at base and 16 here, none new and none gone.** `WorldState`, `empty_world_state` and `ports.ail`'s `<imports:1>` are already stale against A, from 034 W1 and later.
- **`test_candidate.py` with `EVAL_CANDIDATE_LIVE=0`: 0 of 93 observed tests differ.** 16 fail and 7 error on both sides, and the names are the same.

**Cause of each row staying where it is.** The protected rows report the first finding, and that is already `ProtectedRegionTouched` at base, so a further edit to an already-stale span changes nothing they report. Admission rows read program content, not the version literal in the expected file. Rows in `src/eval/journal/**` that pin `execution-program/5` move with this branch, and their tests stay green.

**What this prediction does not cover.** The 13 live tests are skipped by `EVAL_CANDIDATE_LIVE=0`, and those are predicted unchanged by inference only. A row that moves in the real run is a finding, and it will be reported as one below.

**A flaw in how the prediction was measured.** Its two clones sat under `/tmp`, and the harness refuses a repo there, so some of those 16 failures and 7 errors were location artefacts. They were the same on both sides, so the diff still means something, but the tests that errored observed nothing. The real runs below are what confirm it.

### Other predictions

- `make dst`: no FAILED name changes against base.
- `make anchors`: no movement, because `tool_phase.ail` and `session.ail` are untouched (C3).
- No profile version bump. `scripts/verify_single_construction.py` stays green, because neither `ResolvedProcess` nor `InvalidRequest` is built here.

### Re-grounding: what moved

The plan's anchors are from `e3293ede`. Almost none moved by the time of `f3e77a19`, despite W1-W4 landing.

| Plan | At `f3e77a19` | Note |
|---|---|---|
| `admission_live_test.ail:127` | `:148` | moved by W1's imports and checks |
| `world.ail:105` | `src/eval/journal/world.ail:104` | no `src/core/world.ail` exists, so this is the journal module |
| `dst_replay.ail` record update `:918` | `:919` | |
| `dst_replay.ail` literal `:1300` | `fixture_program`, `:1282` | the literal's `extension_profile` line is `:1295` |
| `dst_replay.ail` literal `:1469` | `wt_program`, `:1463` | a record update of `fixture_program()`, so it inherits and needed **no edit** |
| `dst_program.ail` list `:183` | function `:182`, list `:183` | same place |
| `ext_world.ail` round trip `:915`/`:917` | `:913` | |

Unmoved: `dst_program.ail:163`, `:214`, `:805-807`; `dst_persistence.ail:464`, `:1651`; `ports.ail:183`, `:890`; `ext_world.ail:600`, `:642`, `:705`; `admission.ail:727`, `:1188`, `:1249`; `scan.ail:1029`; `program_persistence_dst.ail:1686-1696`; `session.ail:1527`. "Twenty lines in eighteen files" still holds.

## Test evidence

Code is at `867ba06e`. Later commits add only files under `evidence/W5/`. G-core ran at `f6f4a3bc`, which differs from `867ba06e` only in `world_state_probe.ail` and the `Makefile`, the move of the C2 guard. `make dst` and `make eval_matrix` ran at `6f17d5d2`, which has the same code as `867ba06e`.

### Predicted against actual

| Prediction | Actual |
|---|---|
| No `eval_matrix` row changes | **Confirmed.** 619 rows on each side, 0 differ in any field but the commit |
| No `make dst` FAILED name changes | **Confirmed.** `declared_vs_performed` on both, with identical `✗` lines |
| `make anchors` does not move | **Confirmed.** Exit 0 |

**No unpredicted row.** The plan's expectation that W5 moves rows does not hold, because 034 W1 had already made these rows red with the same first finding.

### Gates

| Gate | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 61 passed, 0 failed`; **the path guard passed here**, see below |
| `make verify_single_construction` | 0 | green |
| `make test` | 0 | passed |
| `cd src/tui && bun run test` | **1** | `Test Suites: 4 failed, 45 passed, 49 total`, `Tests: 472 passed, 472 total`; see below |
| `make test_coverage` | 0 | `926 of 939 passed, 13 skipped` |
| `make new_contract_policy BASE=origin/main` | 0 | `18 in-scope new pure func declarations, all justified` |
| `make verify_classify_check` | 0 | `79 contracts, register agrees` |
| `make anchors attribution_table profile_definition execution_program program_persistence strict_replay seeded_generator invariants corpus_judge fault_catalogue journal_resume corpus_pr` | 0 each | run one at a time; `journal_resume PASS rows=13` |
| `make world_state` | 0 | after the guard moved; 2 before it, see *Two decisions* |
| `make dst` | **2, same at base** | `FAILED (1): declared_vs_performed`, `127 passed, 10 FAILED` on both |
| `make eval_matrix` | **2, same at base** | `619 rows: credited=418, equal=124, failed=33, inapplicable=11, missing=33` on both |

Peak machine memory during the heavy runs was about 8 GiB, sampled every 20 s, under the 12 GiB rule.

**`check_core` passed, which is not what the brief expected.** It was measured red on `main` at `verify_native_path_guard`. In this session's shell the guard printed its `OK` lines and the type-check ran. This pull request does not touch the guard or `tool_runtime.ail`, so this says nothing about #299 and #300, only that the failure did not reproduce here.

**TUI failures.** `compose-output-validator`, `compose_guard_semiformal`, `env-server` and `scratchpad/loopback` fail to load with `callSite.getFileName is not a function`. These are the same four suites #292 and #295 record. The base was not re-run here. No TUI source changes.

**The base runs from `/tmp` are discarded.** The first base `make dst` and `make eval_matrix` ran in a worktree under `/tmp`, and showed 11 FAILED names and 8 differing rows. The harness refuses a repo there: "AILANG auto-relaxes MOD010 there and interface failures are hidden". Re-run from `/workspaces`, both match head exactly. Anyone taking a base for a later item should not put it under `/tmp`.

### Rows left red (R11)

`manifest-A`, `tools/eval_protected/`, `scripts/eval/` and `MATRIX.expected.tsv` are untouched. 33 rows fail and 33 are missing, all at base too. `evidence/W5/matrix_rows_left_red.txt` lists each one:

- **Failed:** `M13.*` (16) and `M15.*` (17), the rows that see a stale `manifest-A`.
- **Missing:** `M7.*` (33), because `tools/eval_protected/selftest.py` exits non-zero.

`make eval_matrix` does not report W1's checks, or the new `r6_transcoded_replays_strict`, because `MATRIX.expected.tsv` has no rows for them. They ran inside it and passed. Proposed row for the regeneration:

```
R6.post_change.transcoded_replays_strict	src/eval/journal/admission_live_test.ail:r6_transcoded_replays_strict	pass	-	call:3
```

### Mutants, run at `867ba06e`

`evidence/W5/mutants.tsv`, `commit` and `mutate.sh`. A kill counts only when the named test fails.

| Mutant | Break | Named test | Verdict |
|---|---|---|---|
| p1 | v6 reads the version and answers `Limits` | `scenario_a_legacy_program_with_timeout_secs_transcodes_as_legacy` | killed |
| p2 | absent before v6 decodes as `Limits` | `scenario_the_frozen_v5_specimen_still_decodes` | killed |
| p3 | a missing line at v6 is accepted | the mode-line-deleted row of `scenario_decode_mutants` | killed |
| p4 | `world_state_of` drops the mode | `scenario_the_limits_specimen_reaches_the_world` | killed |
| p5a | `world_of_json` drops it | `test_a_limits_value_round_trips_through_the_token` | killed |
| p5b | `world_json` drops it | `test_a_limits_value_round_trips_through_the_token` | killed |
| p6 | `adopt_world` drops the re-seat | `test_adoption_re_seats_the_mode_from_the_pre_hook_world` | killed |
| p7 | a ceiling below the default is accepted | the below-default row of `scenario_the_ceiling_refusals` | killed |
| p8 | an absent token key decodes as `Limits` | `test_a_token_without_the_mode_decodes_as_legacy` | killed |

Three more, not in the plan, show that the guard detects a break: `c2.world`, `c2.switch` and `c2.schema`, all killed.

### Acceptance

| Criterion | Demonstrated by |
|---|---|
| A13 | `scenario_a_legacy_program_with_timeout_secs_transcodes_as_legacy` (real v5 bytes, `timeout_secs: 0`, stays `Legacy`); `r6_transcoded_replays_strict` (a real run replays strictly after the bytes round trip); every frozen v1-v5 row |
| A15, decoder half | `scenario_the_ceiling_refusals`: one rule per defect (`artifact-ceiling-not-positive`, `-not-whole-ms`, `-too-large`, `-below-default`) and a valid neighbour for each |
| A18 | `evidence/W5/a18_diff.out`: 18 artifacts from `make corpus_pr` at `f3e77a19` and here differ only in the version line, digest and `process_limits` line. `make journal_resume` for journals folding and resume planning. The generator is untouched |
| A14d | `r6_post_change_admits` and `r6_post_change_replays_strict`, tightened to assert `Legacy` on the program, the reconstituted world and the run's world |
| A25 | `test_a_limits_value_round_trips_through_the_token` with a value distinct from the default; `test_adoption_re_seats_the_mode_from_the_pre_hook_world` in both directions; `test_a_token_without_the_mode_decodes_as_legacy` |
| C2 | `c2_guard`, run by `make world_state` |

### Limits of this evidence

- **A18's interactions cover the corpus's 18 seeds**, not all seeds. No generator source changed, so nothing else could move them.
- **`journal_resume` uses journals its own suite builds.** This item adds no separately recorded pre-change journal. A18's last clause returns at W12 on the built change.
- **The encoder does not validate.** `process_limits_field` multiplies a `CeilingMs` by 1,000,000, and an out-of-range value in a hand-built program would wrap if it were encoded without calling `validate_program`. The decoder refuses a non-positive result. No writer here produces `Limits`.

CI was not waited for. The pull request is not merged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
