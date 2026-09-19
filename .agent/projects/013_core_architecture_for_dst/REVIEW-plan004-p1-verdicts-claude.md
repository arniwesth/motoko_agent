# REVIEW — PLAN-004 v2 §3 P1R: aggregate review of the P1 tree (claude)

- **Date:** 2026-09-16 (run 23:14–23:23 local).
- **Reviewer:** claude (Claude Opus 5). **Codex is not permitted in this container**, so this is the `-claude-` review that P1R allows. The receipt should say so.
- **HEAD:** `52b7d56c88f8e338292232cf34fbd099f878b3fb`. I checked it with `git rev-parse HEAD` at the start, and it had not moved. A = `65003110`. `git diff --quiet 65003110 HEAD -- src/core` exits 0.
- **Graph id:** `P1R-v2`. The dep `P1.9b-v2` is done. Every P1 part's `·a1` attempt is `done` in `.dagr/run-plan004-v2.json`, which I read and did not edit.
- **Inputs, read in full:**
  - PLAN-004 v2 §0 (incl. §0.8 and §0.10(b)), §1 and §3 (P1.1–P1R)
  - ADR-004 v5 D2, D3, D5 and D8 (incl. "The P1 test contract" and the M15 ruling)
  - the 13 P1 commit messages (`6500311` … `52b7d56`)
  - `MATRIX.expected.tsv`, `tools/eval_protected/{starting_set,manifest-A}.json`, and the evaluator sources as cited
  - the P1.2b, P1.7a, P1.8 and P1.9b delegate answer files (gitignored, read for the §0.8 records)
- **Method:**
  - Ran every suite that fits the 2-minute budget, one at a time. `memory.current` was 8.9 GiB before the runs. Logs are in the session scratchpad.
  - Checked `MATRIX.expected.tsv` with a script, row → test and test → row.
  - Walked D8's contract clause by clause over the rows.
  - Compared the manifest with D5 and with the evaluator's actual `src/core` imports.
  - Took a symbol inventory by grep.
  - Checked the installed AILANG source at `ae36986` for the trace-loader claim.
  - Checked `dst_secrets.ail:261–272` for the JWT claim.
- **What I did not do:**
  - edit anything except this file; commit; touch a herdr pane or a `.dagr` file;
  - run `make dst`, replay, profiling, or a real corpus read;
  - run `m15_k_rows.sh`, which does five full candidate-tree compiles and exceeds the budget. I cite its recorded gate instead.
  - `make eval_matrix` does not exist, so `MATRIX.tsv` does not exist and no observed/expected join was possible.
  - `git status --porcelain` is byte-identical before and after my runs.
- **Privacy:** synthetic fixtures only. This document holds counts, digests, indices and identities.

---

## Verdict: **RETURN**

Every suite I could run is green, and the matrix is internally consistent. But P1 does not yet deliver what D8 step 2 and `P1G` need.

### Required changes

**R1. Wire K1–K7 into the runner's candidate mode, and create `make eval_matrix`.**
- Today `scripts/eval/candidate.py` and `journal_replay.ail` stop after K0 (P1.9b finding 1; `m15_k_rows.sh:21–23` says so).
- D8 step 2 builds "the candidate runner (K0–K7)".
- P2.2 calibrates "with the final evaluator, both verdicts".
- `P1G` pins E. An E that cannot produce a candidate verdict under the guard, with K0 and the effective lock, is not the final evaluator.

The same rework must:
- re-run the M15 K-rows through `candidate.py`'s assembly, not the side driver;
- make the corpus entry carry the record K1–K7 read (see C6).

`make eval_matrix` is also missing, and `P1R` and `P1G` both require it (§3 "The D8 P1 matrix"; `P1G`: "`MATRIX.tsv` clean"). §0.8 gives a missing make target to "the part that introduces" it. No part could, because the Makefile was outside every brief's write scope. It belongs with this rework unless the orchestrator names another owner.

**R2. Add the missing closure members and regenerate `manifest-A.json` at A** (see item 4).
- `tool_call_json` is a demonstrated missing member.
- 13 other transitive callees sit in non-path-refused files and are unpinned.
- The members also go to ADR-004's next revision, as D5 requires.
- After the change, the M15 `ProtectedRegionTouched` search must be redone:
  - The `tool_call_json` edit must now be `Refused(ProtectedRegionTouched)`.
  - The row then needs either a new edit outside every span that changes a recorder input, or `inapplicable` with the search stated (D8).

**R3. Replace the M15 `InadmissibleCandidate` path/intent fixture.**
- `PERMITTED_EDIT` (`scripts/eval/test_candidate.py:117`) changes `["m-end;"]` in `canonical_messages` (`src/core/phase_vocab.ail:300`).
- That is the digest-only list terminator. `payload_digest`/`digest_messages` (`:362–367`) is its only user, and it is not part of any message sent to the provider.
- So the fixture does not meet the row's premise ("so that one message changes", M15 table).
- The observed `K7:SeedDigestDiffers@snapshot:12` is a correct observation of a different case. It does not falsify the table's `ProjectionDiffers`, because the table's case was never built.
- Required:
  - a permitted-file edit that changes one sent message (expected first finding: K2 `ProjectionDiffers` at the first affected call, since K2 precedes K7), with its family-half assertions;
  - keep the current case as an additional, renamed row ("digest-function-only edit → K7").

**R4. Supply P1.2b's §0.8 record.**
- Commit `3f99293` says "mutation per delegate record".
- The delegate answer (`answer-mot-dlg-1789583249372.md`, sha256 `43026f2e…`) contains the unfilled placeholder `MUTATION_TABLE` at line 94 and `MUTATION_SHORT` at line 176.
- Only one survived-then-fixed mutation (N) is described.
- Under §0.8, "an asserted ordering with no recorded failure is not credited".
- Required: a recorded mutation run over `excerpt.ail` and `association.ail` (each mutation, the test that fails, the restore check). No code change is needed unless a mutant survives.

### Implicated parts (§0.10(b))

| part | why |
|---|---|
| `P1.9b-v2` | R1 (write scope extended to `scripts/eval/candidate.py`, `journal_replay.ail`/`.sh` and the Makefile), plus R3's catching half and R2's re-searched row |
| `P1.4b` | R2 |
| `P1.9a` | R3's family half (the fixture and its passes-its-refusal assertions) |
| `P1.2b-v2` | R4 |

- Their `·a1` attempts stay `done` and unchanged.
- Each gets a `sent_back` attempt that refs this `P1R` attempt.
- When all four are `done` again, `P1R` gets a `followup` attempt.

### Corrections for the orchestrator or `P1G`

These do not block the rework but should be ruled or landed before `P1G`. Details are in the items below: C1–C14.

---

## 1. Suites

Each suite ran once, sequentially, capped at 120 s (`timeout 120`). Durations come from `ailang test`'s own report or from log times.

| suite | exit | result | wall |
|---|---:|---|---|
| `python3 src/eval/journal/testdata/gen_fixtures.py --check` | 0 | all outputs up to date | <1 s |
| `make eval_protected_selftest` | 0 | 33/33 cases ok | 102 s |
| `ailang test` digests / digests_at_a_test | 0 / 0 | 7/7, 4/4 | 1.4 s, 2.7 s |
| `ailang test` reader / reader_at_a_test | 0 / 0 | 27/27, 2/2 | 16.7 s, 9.1 s |
| `ailang test` excerpt / association | 0 / 0 | 5/5, 31/31 | 1.5 s, 26.7 s |
| `ailang test` configuration / configuration_at_a_test | 0 / 0 | 5/5, 4/4 | 1.5 s, 3.6 s |
| `ailang test` stopping | 0 | 41/41 | 61.1 s |
| `ailang test` world / seams | 0 / 0 | 3/3, 6/6 | 8.6 s, 5.3 s |
| `ailang test` admission / witness / source_checks | 0 / 0 / 0 | 12/12, 7/7, 7/7 | 29.3 s, 18.2 s, 17.0 s |
| `ailang test` scan / candidate / candidate_checks | 0 / 0 / 0 | 9/9, 6/6, 4/4 | 20.7 s, 14.7 s, 11.6 s |
| live `seams_live_test` | 0 | 4 PASS, "all checks passed" | <10 s |
| live `admission_live_test` | 0 | 9 PASS | <10 s |
| live `witness_live_test` | 0 | 10 PASS | <10 s |
| live `source_checks_live_test` | 0 | 19 PASS | <10 s |
| live `scan_live_test` | 0 | 8/8 | <5 s |
| live `candidate_live_test` | 0 | 4 PASS, 0 FAIL | <5 s |
| live `candidate_checks_live_test` | 0 | 29 PASS | <10 s |
| `python3 -m pytest -q scripts/eval/test_mem_guard.py` | 0 | 55 passed | 9.7 s |
| `python3 -B -m pytest -q scripts/eval/test_candidate.py` | **124** | **killed at the 120 s cap**: 101 of 104 passed, 0 failed before the kill | >120 s |
| `protected.py pins --at 65003110 --pins-root .` | 0 | 147 pins, 0 bad | — |
| `protected.py check --manifest manifest-A.json --tree . --pins-root .` | 0 | 99 spans, 0 findings, 0 pin drift → clean | — |

Live runs used `ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand --ai-stub --entry main <file>`.

**Over budget, so the recorded gates are cited instead:**
- `test_candidate.py`: `d68d1ee` records "104 passed (incl. 5 live fresh-cache compiles, 169 modules)". The three tests the cap cut off are the live-compile tail.
- `m15_k_rows.sh`: not run. `52b7d56` records "5 KROW lines, each equal to its expected row; KPROT 0 findings on every tree".

**Accept, with one caveat:** item 1 is green where it ran. The caveat is that the live-compile tail of `test_candidate.py` and the M15 K-row driver rest on the delegates' records.

## 2. `MATRIX.expected.tsv`

580 lines: a header plus 579 rows, 5 columns on every line, no duplicate `case_id`.

The rows each part landed match its commit claim: 11 + 34 + 33 + 42 + 53 + 14 + 77 + 59 + 60 + 39 + 117 + 40 = 579.

- **Every expected row names an existing test.**
  - All 568 named tests resolve to a function or live check label in the named file.
  - The one that the script did not resolve literally is `M5.api_model.copy_bytes` → `gen_fixtures.py:--check (check_api_model_copy)`, which exists at `gen_fixtures.py:2169`.
  - 11 rows name `-`, and every one of them is `inapplicable`.
- **Every test has a row.**
  - Every `test_*` in the 17 pure modules, the 53 `test_*` in `test_candidate.py`, the 33 selftest cases and the 5 `m15_k_rows.sh` cases are named by at least one row.
  - The only live labels without a row are failure-path labels, not checks: `seams_live_test.ail:185` `c2_fixture_reads` and `:207` `c2_world_state_of`.
- **Positions.**
  - 21 rows have position `-`. Eleven are `inapplicable`. Nine are clean `admitted`/`reproduced` rows, where no finding exists (e.g. `M14.reproduced.*`, `P17a.SourceFaithful.*`, `M15.clean.*`, and `M15.ProtectedRegionTouched.fixture_comment_only`). One is `M13.run.run_directory_exists`, an `error` row with no position; that is acceptable, but see C2.
  - **Placeholders instead of literals (C2):**
    - `M12.entry.scan_refused`: `ScanRefusal:<per component, as M12.component.*>`
    - `M13.ProgramUndecodable.garbage`: `…(<decode rule>)`
    - `M13.ProgramUndecodable.structural`: `…(<program rule>)`
    - `M13.PreflightMismatch.run.during_run`: `PreflightMismatch:<first of k0; …>`
    - `M11.live.census_twins`: `aggregate:census:<each count>`
  - An `eval_matrix` join on literal equality cannot pass on these. Each must be a literal or be split into one row per value.
- **Inapplicable M15 rows carry reasons.** All ten do: `UnknownEntryType`, `UnknownSchema`, `park_wake`, `ContinuationStart`, `EmptySegment`, `HybridPredicate`, `ScanRefusal`, `ProgramUndecodable`, `PreflightMismatch` and `GuardTripped`. The eleventh inapplicable row, `M8.C2.join5`, carries P1.1R C2's reason. `EvaluatorTouched` is not inapplicable: a fixture exists.
- **`make eval_matrix` does not exist** (`grep eval_matrix Makefile` finds nothing), so no `MATRIX.tsv` exists. See R1.
- **The format split, for P1G's ruling (C1).** It is wider than M5 against M11:
  - **Verdict-level** `AdmissionCheck(Ak)`: `M5.ProfileMissed.witness`, the six M15 A-rows, `M10.verdict.*` and `P17a.*`.
  - **Finding-level** `Ak:Name`: every M9, M10 and M11 detail row. The K-rows use `Kn:Name` throughout.
  - **Recommendation:**
    - Finding-level `Ak:Name` for any row that asserts which check caught what. That changes `M5.ProfileMissed.witness` → `A7:EnvReadOverRecorded`, and the M15 A-rows → `A3:PayloadDiffers` or whichever name was observed, and `A2:<name>` for the swap row.
    - `AdmissionCheck(Ak)` only for the verdict-mapping rows (`M10.verdict.*`, `P17a.*`).
    - Alternatively, `eval_matrix` emits both a verdict and a finding column.

**Correction:** the rows are consistent and complete in both directions; C1, C2 and R1 remain.

## 3. Coverage of v5 D8's revised contract

| clause | rows | status |
|---|---|---|
| per D1 refusal family: refused at a pinned location + clean twin | M1 (`ChainBreak` ×4, `MalformedEntry` ×8 incl. three stray-wake cases, `UnknownEntryType`, `UnknownSchema`) + `M1.clean`; M2 (`DuplicateOrAmbiguousCallId` ×2, `UnexpectedToolResult` ×3, `MalformedToolArguments`, `Association` ×8, `ContinuationStart` ×3 incl. wake, `EmptySegment`) + `M2.clean`; `HybridPredicate` `M4.HybridPredicate` + `.true` | covered |
| per D3 `Refused` reason + twin | `InadmissibleCandidate` path ×15 / intent ×6, `EvaluatorTouched` ×5, `ProtectedRegionTouched` ×6, `PreflightMismatch` ×40, `GuardTripped` ×9, `ProgramUndecodable` ×12; twins `M13.clean.refusals`, `M13.GuardTripped.clean`, `M13.PreflightMismatch.clean.*`, `M13.ProgramUndecodable.clean.*`; `ScanRefusal` M12 + `M12.component.clean` | covered |
| per cutoff: selector, N, end, genuine/synthetic | M3: all 18 of D1's table plus `SelectorEnd`, `StopThenUserMessage`, `StaleResultAfterCut`, `StopBeforeEnd.cut_turn`; M4's shapes | covered |
| A1–A9, A9b: failing + twin, first finding + location pinned | A1 `M10.A1.*`; A2 `M10.A2.*`; A3 `M10.A3.*`; A4 `M10.A4.*`; A5 `M9.A5.*`; A6 `M9.A6.*`; A7 `M11.witness.*`; A8 `M11.census.twin.*`, `M11.live.bridge.*`, `M11.live.budget.*`; A9 `M9.A9.*`; A9b `M9.A9b.*`, each with `.clean` | covered, with two gaps: **G1**, **G2** |
| K1–K7: failing + twin | K1 `M14.K1.*`; K2 below; K3 `M14.K3.*`; K4 `M14.K4.*`; K5, K6, K7 `M14.K5/K6/K7.*`; twin `M14.reproduced.*`; K0 = the M13 `PreflightMismatch` rows | covered in-process; the cross-process runner path is R1 |
| one per `ReplayMismatch` variant | `WrongKind`, `WrongOrigin`, `UnsafeIdentity`, `ProjectionDiffers`, `OutcomeDiffers`, `ProgramExhausted` and `UnusedInteraction` (by log length), plus the exhausted-marker trio | covered, 7/7 |
| per seam fail-closed arm: record, return value, no live effect | `M8.provider.empty_script` (record + non-retryable `Err`); `M8.tool.empty_queue` (record, `ToolFailed`, sentinel absent, live); `M8.guard.exactly_one_append` (the cardinality arm); `M8.tool.correlation_mismatch` | covered |
| witness under- and over-count; prepared ≠ recorded | `M11.witness.under/over`, `M11.live.under/over/tool_over`; `M14.K3.DiscoveryFinding.prepared_gt/lt_recorded`, incl. `stored_witness_agrees` | covered |
| per census row: zero by name + non-zero twin | `M11.census.zero_by_name`; 19 `M11.census.twin.*` rows cover all 12 counted rows (checkpoints ×2, chunks, approvals ×2, waits/parks/wakes, ext effects, retries, injected, hybrid, file ×3, exit-manifest reads/writes, capture, decisions). The "not observed" row has no count. | covered |
| one vacuous family through `family_evidence` unchanged | `M11.live.checkpoint_history_vacuous`, `M11.live.family_evidence_unchanged`, `M11.four_words` | covered |
| M15 near-miss rows as per-check known-failing cases | the six A-rows (live, with passes-family assertions); the K-rows via the driver | **R2** (closure row), **R3** (path/intent premise not met), R1 (the driver is not the runner) |

**Gaps:**
- **G1 (A8).** No row has an `evaluate(...)` Violation as the admission's first finding.
  - Every A8 failing row is caught earlier, by the bridge-input or census checks.
  - For example, `M11.live.budget.n`'s first finding is `DecisionBudgetDiffers`. `3ff4dbd` notes that `evaluate` then reports `decision-budget-exceeded`, but no row pins that.
  - K4 has the equivalent (`M14.K4.Violation`).
  - Recommended: one A8 row with correct bridge inputs whose trace violates a family. Owner: P1.7b, or with the rework.
- **G2 (A9b).** A9b's second, post-run pass exists only in `journal_replay.sh`, which re-collects identities after the run. No row asserts that a change between the two collections is a finding.
- **G3.** The intent row `M15.InadmissibleCandidate.intent` reuses the path case's test (`m15_k_rows.sh:path_permitted`). The K run never reads `candidate.json`, so the intent half is only `test_m15_inadmissible_intent_passes_intent_refusal`. That is acceptable once R3 lands, as long as the row says so.
- **G4.** `M15.EvaluatorTouched` uses `MOTOKO_TOOL_TIMEOUT_MS` → `_MX` in `tool_phase.ail`. That changes an env-read identity (`K2:UnsafeIdentity@interaction:9`), not a "tool invocation" as the table words it. The case is valid (outside §0.5 and D3's list, caught by K2), but the table's wording should follow.

**Correction:** D8's contract is covered clause by clause. G1 and G2 remain as small gaps, and R3 applies to M15.

## 4. Closure review (v5 D5)

### Manifest against D5's starting set

`manifest-A.json` (source commit `65003110`, 99 spans, 6 files) was verified:
- ports.ail: 70 spans
- stub_step.ail: 11
- session.ail: 4 (imports, `provider_api_model`, `ported_provider`, and the `dispatch_step@call` call site)
- dst_fault_catalogue.ail: 9
- dst_interaction.ail: 3
- tool_contract.ail: 2

Every name in D5's list is present in `starting_set.json`:
- ports: the recorder, both codecs and their helpers, `world_tool`, `live_tool_outcome`, `scripted_tool_outcome`, `recording_tool`, `tool_outcome_record`, `provider_outcome_record`, `scripted_step_*`, clock, env, file, approval, wake (incl. `cursor_wake`), the mutation and effect recorders, `ports_shape_probe` with its six scripted file and effect ops, and the ten named types;
- stub_step: its ten members;
- session: its three;
- the fault catalogue literals and `provider_error_is_retryable`.

Types are pinned only in the three files, per D5's letter. `named_types_not_pinned` lists 8 for review:
- `FsNode@fs_node.ail` is **not** path-refused and is named by `WorldState`, `lookup_file` and the file ops. Flag it for the next revision (C8).
- `ApprovalRequest` and `WaitDescriptor` are in `phase_vocab`, unfrozen on purpose; T0 has no approvals or waits.
- The other five are in `dst_*`, which is path-refused.

`protected.py check --tree .` is clean (item 1).

### Against the seams' actual delegations

What the seams and the world call (`seams.ail:69–84`, `world.ail`):

| callee | status |
|---|---|
| `recording_ports`, `record_interaction`, `encode_exhausted_provider_outcome`, `encode_tool_outcome`, `fault_class_tool_failed`, `fault_class_tool_correlation_mismatch`, `PortedWorld`/`StepProvider` | pinned |
| `empty_rt` | stub_step, path-refused |
| **`empty_world_state`** (`ports.ail:825`), also used by `world.ail`, `admission.ail` and `witness.ail` | **unpinned**; not path-refused |
| `FsNode`/`FsFile` | `fs_node.ail`, unpinned |

### Missing members: ruling

`manifest-A.json`'s `unlisted_callees` report names 23 functions called by 17 members:
- 9 are in path-refused files: 4 in `dst_fault_catalogue`, 4 in `test/stub_step`, and `dispatch_one_typed` in `tool_dispatch_adapter`, which `candidate.py:155` refuses.
- **14 are neither pinned nor path-refused**, so by D5's definition ("the dependency closure of `recording_ports`' bindings and of the two seams' delegates") they are missing members:
  - `ports.ail`: `tool_call_json` (`:2482`, callee of `tool_calls_json`), `has_key` (`:2465`) and `opt_int_field` (`:2444`) in the decoders, `empty_world_state` (`:825`), `envelope_to_call` (`:1810`, `live_tool_outcome`), `advance_ordinal` (`:536`, `cursor_wake`), `wake_payload` (`:1188`), `wake_read_unbound` (`:1109`), `lookup_node` (`:1369`), `remove_path` (`:1482`), `world_path_kind` (`:1545`), `names_below` (`:1518`), `sort_names` (`:1563`);
  - `world_ordinal.ail:40`: `advance`, callee of `dispatch_step`.

**`tool_call_json`: confirmed missing member** (P1.9b finding 3, from `52b7d56` and the delegate record).
- Reordering its keys passes the checker (KPROT 0 findings).
- It changes the provider outcome the recorder writes.
- K2 reports `OutcomeDiffers@interaction:7`.
- Detection by K2 does not substitute for membership. D5 refuses closure edits before running.

**The other 13: missing by definition.**
- Some are only reached on routes T0 does not exercise: wake, and `ports_shape_probe`'s file ops.
- `has_key`, `opt_int_field`, `empty_world_state` and `advance`/`advance_ordinal` are on T0's path: decoding, world construction and ordinals.

R2 therefore requires:
- add all 14 to `starting_set.json` (with `world_ordinal.ail` as a protected file) and regenerate at A;
- make the `unlisted_callees` report transitive to a fixed point, so the next review sees the whole set;
- have `gen` flag (not silently list) any unlisted callee in a non-path-refused file;
- report the members to ADR-004's next revision.

**`has_key`.** The comment-only fixture edit reproduces, which is correct because it changes nothing. After R2 the same edit lands inside a span and must be refused, so `M15.ProtectedRegionTouched.fixture_comment_only` and `test_m15_protected_region_passes_protected_refusal` (`test_candidate.py:287–294`, which asserts `has_key` is unlisted) must change with it.

**Evaluator imports from unfrozen candidate files (C8).** These are not D5 members, but they are read by checks:
- `admission.ail:114` and `admission_run.ail` import `phase_vocab.run_summary_finish_reason` (`phase_vocab.ail:1266`), which A6 and K6 use to read the finish reason. A candidate edit to it changes what K6 sees.
- `scan.ail` imports `fs_node.fs_content_of`.

Either copy these into the evaluator with a SOURCE pin, like the digests, or pin them.

### Symbol inventory of `src/eval/journal/` and `scripts/eval/journal_replay.ail`

Test modules are listed where they call the harness. The grep excluded comment lines.

| harness symbol | call sites |
|---|---|
| `strict_replay_findings` | `candidate_checks.ail:332` (K2); `:365` (locating K4's replay-family violations, same function, positions only) |
| `regression_replay_findings` | `candidate_checks.ail:536` (envelope diagnostic only; MU1/MU8 show that it never sets the verdict) |
| `reconstitution_balance` | `admission.ail:385` (A9); `candidate_checks.ail:319–320` (K1: the rebuilt world, then the handed world); `seams_live_test.ail:171` (test) |
| `world_state_of` | `admission.ail:382` (A9); `candidate.ail:88` (ProgramUndecodable); `candidate_checks.ail:316` (K1); `candidate_checks_run.ail:98` (C's world); `seams_live_test.ail:206` (test) |
| `load_program` | `candidate.ail:111`; `scan_live_test.ail:100,107,163` (tests) |
| `decode_artifact` / `encode_artifact` | `candidate.ail:97`; `scan_live_test.ail:97` (test) |
| `encode_body` + `program_digest` | `admission.ail` (import `:129`); `admission_run.ail:147`; `source_checks_run.ail:121`; `candidate.ail:127`; `scan.ail:566–567,570,1011–1012`; `candidate_live_test.ail:51` |
| `ExecutionManifest` (harness type, imported, never redefined) | `admission.ail:121,356,636,721`; `admission_run.ail:44`; `bridge.ail:47,60,83,123,137`; `candidate_checks.ail:120,667`; `scan.ail:114,492` |
| `driver_only_manifest` / `validate_manifest` / `validate_program` | `admission.ail:358,381,565,638,907,934`; `candidate.ail:86`; `candidate_checks.ail:668`; tests |
| `check_discovery` | `witness.ail:193` (A7); `candidate_checks.ail:351` (K3) |
| `execution_of` | `bridge.ail:61` (A8); `candidate_checks_run.ail:102` (K4); `witness_live_test.ail:292–293` (test) |

**Findings from the inventory:**
- **No second comparison walk, reconstitution or manifest type.** `grep '^(export )?type'` over the evaluator finds no manifest, program, interaction or mismatch type. The only identity record is `admission.ail:398` `Identities`, the collected-identities record of P1.6's table, not a manifest.
- A1–A4 are the source checks D3 assigns to the evaluator ("evaluator code beside `JournalFold`"), not a replay walk.
- **`scan.ail:565–567` `program_artifact`** re-spells `encode_artifact`'s frame (`dst_persistence.ail:663–670`) over the harness's `encode_body`/`program_digest`, and skips `scan_program`.
  - The plan prescribes exactly this shape, and `scan.ail:1011–1012` tests byte equality.
  - It is not a second codec, but calling `encode_artifact` would remove the duplicate frame and add the harness's own secret scan (C7).

**`entry_json` / `decode_entry` (`candidate_checks_run.ail:192–331`), P1.9b finding 5: ruling — not a second persistence codec in D8's sense.**
- It encodes no program, which still goes through `load_program`, and it defines no manifest type.
- It serialises only entry-level comparands the harness has no codec for: end, calls, the `DiscoveryWitness`, budgets, `ReplayMetadata`, epoch, `FamilyEvidence`, the census and omissions. All of these use the harness's own types.
- It does create a **second entry format** beside P1.8's entry writer, which stores `witness.json` and `census.txt` as opaque text (`scan.ail:590–591, 626–633`). Nothing writes `entry_json` into a corpus entry today; only the test driver writes `entry.json`.

**Correction C6:** there must be one entry-comparand codec. Either P1.8's `witness.json` and `census.txt` become `entry_json`'s rendering, or the entry layout gains `entry.json` written by it. This lands with R1's wiring.

**Result: RETURN (R2).** The inventory itself is accepted, with corrections C6 and C7.

## 5. The open rulings backlog for P1G

| # | item | ruling |
|---|---|---|
| a | M15 path/intent rows diverge at K7 `SeedDigestDiffers`, not `ProjectionDiffers` (P1.9b finding 2) | **Correct the claim; RETURN R3.** The observation is right, but the fixture edits the digest-only `"m-end;"` terminator (`phase_vocab.ail:300`), so no message changes. The table's premise was never tested. Keep the observation as its own row. It also shows that K7 compares the candidate's own digest functions with the recorded chain, so any candidate change to `canonical_messages`' output diverges at K7. That is consistent with D5's "private digest copies" note only because the P3 control (`de4b4f5` reverted) is byte-identical (D8 P3); P3.2 must assert K7 passes. |
| b | K1–K7 not wired into the runner's candidate mode (finding 1) | **RETURN R1.** |
| c | K1 also balances the handed world; K4's family record declares the replay-consistency flip (finding 4) | **Accept both.** The handed world is `world_state_of(program)` (`candidate_checks_run.ail:98`), so the second balance is redundant but harmless (`candidate_checks.ail:320`). The flip is forced: `NoReplay` at admission against `StrictAgainst` for the candidate. D3's K4 text ("`family_evidence` equals the entry's record") should say "except `ReplayConsistency`'s `evaluated`" in the next revision (C12). |
| d | JWT false negative pinned (P1.8 finding 1) | **Confirmed.** `dst_secrets.ail:266–271`: `jwt_in_parts` recurses on `b :: c :: []`, dropping the tail, and needs a dot segment that *starts* with `eyJ`, so a JWT after a space or mid-JSON is missed. Pinning it as `M12.JsonWebToken.false_negative` is right for P1, since D6 pins the rule. **P1G must rule before P3.1 admits a real entry (C10):** either revise D6's policy (fix it in the evaluator's policy copy, not `dst_secrets.ail`) or accept it and print the false negative in the scan report and the envelope. |
| e | trace-loader deviation (P1.9a) | **Confirmed; accept.** At `/home/motoko/.local/share/ailang` `ae36986`, `cmd/ailang/main_run_exec.go:141–143` reads `_ = traceLoader` ("accepted but not fully wired up"). The file's sha256 `3dff9e7f…` equals `candidate.py`'s pin, and `stdlib_resolver.go` `0859f5cb…` does too. Re-deriving the order from pinned source, recording the trace as absent and stating it in the residual gap is the right response. Three AILANG requests are still to be raised through `ailang-feedback` (C13): an id → path flag, `-trace-loader` on `run`, and the `ailang test` decode_artifact bug. Add the private-name collision (P1.3, P1.8) and the `std/json` SharedMem demand (P1.6). |
| f | `entry.name` duplicate rows (pure-pass + live-refused) | **Confirmed.** `M12.entry.name` → `scan.ail:test_m12_entry_name`, `pass`, `aggregate:entry`. `M12.entry.name_invalid` → `scan_live_test.ail:m12_entry_name_invalid`, `refused`, `Entry:NameInvalid`, `aggregate:entry`. These are two tests and two distinct case ids, both of which exist and passed. Two other pairs share one test, which is acceptable but should be noted when `eval_matrix` maps one test to several rows: `M12.JsonWebToken` + `.false_negative` both → `test_m12_shape_refusals`, and `M12.entry.layout` + `.exposure_row_undecodable` both → `test_m12_entry_layout`. |
| g | M15 swap `snapshot:14` against `entry:14` | **Confirmed: same entry.** `gen_fixtures.py:1442` builds `swap_bodies(m2_bodies(), 14, 15)`. `chain()` sets `seq = i` (`:833`), so the first swapped result is seq 14. `Source(Snapshot, seq)` is `snap(seq)` (`source_checks.ail:129`). `3f99293`'s pending `entry:14` became `9c1067d`'s `snapshot:14` for the same entry. Association accepts the swap (`M15.DuplicateOrAmbiguousCallId.association_accepts`), so the conditional row applies, and the live check passed (`m15_duplicate_call_id_swap`, item 1). |
| h | red-first / mutation records per §0.8 | See the table below. |

**§0.8 records by part:**

| part | commit record | status |
|---|---|---|
| P1.1 | mutations M1 (caught), M0 (uncaught, noted) | present; P1.1R accepted it |
| P1.4a | 4 mutations, named tests | present |
| P1.2a | 9 mutations | present |
| P1.4b | 2 recorded reds + 7 mutations | present |
| **P1.2b** | "mutation per delegate record"; the record is an unfilled placeholder | **absent → R4** |
| P1.3 | red-first stub (1/39) + 7 mutations | present |
| P1.5 | red-first (0/6, live) + 11 mutations | present |
| P1.6 | 12 mutations | present |
| P1.7b | red-first (0/7) + 16 mutations | present |
| P1.7a | "red-first stub 5/7-fail; mutations M1–M7": not itemised in the commit | the itemised table is only in the gitignored answer (`answer-mot-dlg-1789591401669.md` sha256 `6709813e…`, lines 69–90). **C14:** copy it into a tracked record (§6 or the P1R follow-up) |
| P1.8 | "Red-first stub 0/9; 10 mutations caught" | same as P1.7a: the itemised table is only in `answer-mot-dlg-1789593205428.md` (sha256 `e8f59fda…`, lines 86–106). **C14** |
| P1.9a | 19 mutations | present |
| P1.9b | 15 mutations (MU1–MU15) | present |

Two mutations in the P1.7a table (M4, M5) are caught only by pure tests, which is acceptable.

## 6. Corrections (not blocking the rework; for the orchestrator or `P1G`)

- **C1.** Rule the MATRIX first-finding format (item 2).
- **C2.** Replace the five placeholder cells with literals or split rows (item 2).
- **C3.** *(Folded into R1: the owner of `make eval_matrix`.)*
- **C4.** G1: an A8 row whose first finding is an `evaluate` Violation.
- **C5.** G2: a row for A9b's post-run re-collection change.
- **C6.** One entry-comparand codec (item 4), with R1.
- **C7.** `scan.ail` `program_artifact` → `encode_artifact`, or state why not.
- **C8.** Evaluator reads through candidate-owned `phase_vocab.run_summary_finish_reason` and `fs_node` (`FsNode`, `fs_content_of`): copy with pins, or protect. List `FsNode` for the next ADR revision.
- **C9.** Stale header in `digests.ail`: it says `digests_at_a_test.ail` is the only `src/core` importer, which P1.5 already noted is no longer true.
- **C10.** Rule the JWT false negative before P3.1.
- **C11.** `ailang.lock` is still modified in the working tree (`git diff --stat`: 3 +/3 −). Any real `journal_replay.sh admit` is refused by A9b `TrackedChanges` until it is committed. P1.6 noted this, and it must be settled before P3.1.
- **C12.** ADR K4 wording on the replay-consistency flip.
- **C13.** Raise the AILANG requests.
- **C14.** Make P1.7a's and P1.8's itemised mutation tables durable.
- **Also for `P1G`:** `../motoko_agent-eval` does not exist yet, so the §0.5 collision check will pass as "absent". The installed `ailang` is v0.33.0 `ae36986`, and `sha256` of `/home/motoko/.local/bin/ailang` is `daf06db1ec7e45ba53c6967b4662a830df2a79de228b7d2b5ce52e0ff8a0c76c`. That is the value to pin if `P1G` uses this binary. Note that the running muse sessions use `/workspaces/motoko_agent/ailang/bin/ailang`, a different path.

## Claim audit

| claim (source) | checked by | result |
|---|---|---|
| HEAD `52b7d56`, `src/core` = A | `git rev-parse HEAD`; `git diff --quiet 65003110 HEAD -- src/core` → 0 | true |
| manifest 99 spans in 6 files (70/11/4/9/3/2) (`6c8bbc9`) | parsed `manifest-A.json` | true |
| "unlisted_callees (23 distinct functions called by 17 members)" (`6c8bbc9`) | parsed: 17 keys, 23 distinct | true |
| pins 147, 0 bad (`d68d1ee`) | `protected.py pins --at 65003110 --pins-root .` → "147 pins, 0 bad" | true |
| protected check clean at HEAD (`52b7d56`) | `protected.py check … --tree .` → "99 spans, 0 findings, 0 pin drift" | true |
| selftest 33/33 (every part since P1.4b) | `make eval_protected_selftest` → 33/33 in 102 s | true |
| suite counts: reader 27, association 31, excerpt 5, configuration 5+4, stopping 41, world 3, seams 6, admission 12, witness 7, source_checks 7, scan 9, candidate 6, candidate_checks 4, digests 7+4, reader_at_a 2 | `ailang test` (item 1) | all true |
| live counts: seams 4, admission 9, witness 10, source_checks 19, scan 8, candidate 4, candidate_checks 29 | live runs (item 1) | all true |
| pytest mem_guard 55 | ran | true |
| pytest candidate 104 passed (`d68d1ee`) | ran under the 120 s cap: 101 passed, 0 failed before the kill | consistent; the last 3 not re-verified |
| m15_k_rows.sh 5 KROW = expected (`52b7d56`) | not run (budget) | not re-verified |
| MATRIX rows per part (11, 34, 33, 42, 53, 14, 77, 59, 60, 39, 117, 40) | counted by prefix | true; sum 579 |
| "the table's ProjectionDiffers was falsified by observation" (`52b7d56`, answer finding 2) | read `phase_vocab.ail:292–367`, `test_candidate.py:117` | **overstated**: the fixture changes a digest terminator, not a message (R3) |
| "one message's frame changes" (`test_candidate.py:117` comment; `test_m15_inadmissible_path_passes_path_refusal` comment "so that one message's frame changes") | same | true only of the *digest* frame; no sent message changes |
| `has_key` is an unlisted callee; the comment edit is outside every span | manifest `unlisted_callees` | true; becomes false after R2 |
| `tool_call_json` is an unlisted callee of `tool_calls_json` | manifest | true |
| `-trace-loader` is a no-op at `ae36986` (`d68d1ee`) | `main_run_exec.go:141–143`; hash `3dff9e7f…` equals the pin | true |
| JWT rule drops the tail (`a20d988`) | `dst_secrets.ail:266–271` | true |
| swap row `snapshot:14` = the family's `entry:14` (`9c1067d`) | `gen_fixtures.py:833,1442`; `source_checks.ail:129` | true |
| P1.2b mutation record exists "per delegate record" (`3f99293`) | answer file lines 94, 176 | **false**: placeholders only (R4) |
| P1.7a "mutations M1–M7", P1.8 "10 mutations caught" | answer files | true, but only in gitignored files (C14) |
| "`make eval_matrix` does not exist" (every part) | `grep eval_matrix Makefile` → no match | true |
| MATRIX format split M5 against M11 (`3ff4dbd`) | row scan | true, and wider (item 2, C1) |
| `ailang.lock` must be committed first (`64d08ab`) | `git diff --stat -- ailang.lock` → 3/3 lines modified | still open (C11) |
| my runs left the tree unchanged | `git status --porcelain` before and after, `diff` → identical | true |
