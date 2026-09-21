# REVIEW — PLAN-004 v2 §3 P1R, follow-up (round 2): re-review of the R1–R4 rework (claude)

- **Date:** 2026-09-17 (run about 09:05–09:20 local).
- **Reviewer:** claude (Claude Opus 5). **Codex is not permitted in this container**, so this is a `-claude-` review, and the receipt should say so.
- **Attempt:** this is `P1R`'s `followup` attempt. It refs `P1.9b-v2·a2`, the last part to be re-done (commit `2062605`).
- **HEAD:** `20626054e8015ebd8623459789d8de8bb6c260d2`, checked with `git rev-parse` at the start and again at the end; it did not move. `git diff --quiet 65003110 HEAD -- src/core` exits 0, so `src/core` still equals A.
- **The a1 review:** `REVIEW-plan004-p1-verdicts-claude.md` at HEAD `52b7d56`. Verdict **RETURN** with R1–R4, implicating P1.9b-v2, P1.4b, P1.9a and P1.2b-v2. I read it in full.
- **Round:** §0.10(a) round 2 of `rounds_max` 3. One round remains.
- **Inputs:**
  - the five rework commits: `bb7a027` and `053904a` (R4), `0b023b0` (R2), `d74079d` (R3), `2062605` (R1), with their messages and diffs as cited;
  - PLAN-004 §6, the P1R R1 record and C14 (`:928–1000`);
  - `tools/eval_protected/{starting_set,manifest-A}.json`;
  - `MATRIX.expected.tsv` and the untracked `MATRIX.tsv`;
  - `scripts/eval/{candidate.py, journal_replay.ail, journal_replay.sh, test_candidate.py}`;
  - `src/core/{fs_node,dst_persistence}.ail`;
  - the four delegate answers: R1 `answer-…1789629276856.md` (sha256 `361dbb04…`), R3 `…628370888`, R2 `…626093470`, R4 `…626088746`. They are gitignored; I read their headers and records.
- **Method:**
  - targeted reads;
  - a scripted check of the manifest (a regen at A compared field by field);
  - a scripted MATRIX check: shape, placeholders, row → test, test → row, and a re-join of `MATRIX.tsv` against HEAD's expected file;
  - suites under the 2-minute cap, run one at a time. `memory.current` was 7.0 GiB before the runs.
  - Logs are in the session scratchpad.
- **What I did not do:**
  - edit anything except this file; commit; touch a herdr pane or a `.dagr` file;
  - run `make dst`, replay, profiling, or a real corpus read;
  - run `make eval_matrix`: its `test_candidate.py` suite runs live for 15m50s, which is over budget;
  - run the live half of `test_candidate.py` or `selftest.py`, which took 138 s in the recorded run;
  - re-run the E7 mutant, because that would mean editing `excerpt.ail`.
  - For all of these I cite the recorded gates.
  - `git status --porcelain` was byte-identical before and after my runs.
- **Privacy:** synthetic fixtures only. This document holds counts, digests, indices and identities.

---

## Verdict: **ACCEPT WITH CORRECTIONS**

R1–R4 are done as required. I found no reason to send anything back, so no third round is needed; the one remaining round stays unused. The corrections below do not block `P1R`. They go to the orchestrator or `P1G`.

**New corrections:**
- **CF1 (MATRIX test → row).** R2 added 9 selftest cases, and none of them has a MATRIX row: `closure_flags_at_a`, `committed_manifest_current`, `gen_flags_direct_callee`, `gen_flags_transitive_callee`, `gen_path_refused_not_flagged`, `path_refused_glob`, `token_has_key`, `token_world_ordinal_advance` and `world_ordinal_imports`. That leaves 42 cases against 33 `M7.*` rows. The a1 review held the matrix to both directions, so either add `M7.*` rows for these 9 or state in §6 that checker-internal cases are exempt.
- **CF2 (`MATRIX.tsv` provenance).** The green matrix was produced on `d74079d+dirty`, before `2062605` was committed. Its commit column says so, and its sha256 prefix is `1ac7f001d132`, matching the record. My re-join shows it agrees row for row with HEAD's expected file (item 6). It still does not prove the committed evaluator produced it. **`P1G` must regenerate `MATRIX.tsv` at a clean, committed E (no `+dirty`) before pinning E.**
- **CF3 (claim wording).** `0b023b0` says "142 unlisted callees, 14 flagged". The committed manifest, and `gen` at HEAD, report **137** unlisted callees and 14 flagged. 142 is the count from before the orchestrator moved the five group-(a) callees into membership. This is record-only; no change is needed.
- **CF4 (the `fs_node` closure gap: next-revision item).** Ruled in item 5.

**Carried over, still open:**
- **C8.** It is now joined by CF4. The evaluator still imports `fs_node` (`scan.ail:120` `fs_content_of`, plus the types in `admission.ail:109` and `world.ail:48`) and `phase_vocab.run_summary_finish_reason` (`admission.ail:114`, `admission_run.ail:39`).
- **C10.** The JWT ruling, due before P3.1.
- **C11.** `ailang.lock` is still modified in the working tree (3 lines added, 3 removed).
- **C12.** The K4 wording.
- **C13.** The AILANG requests.
- **`P1G`'s two-tier matrix design point** (425 credited rows against 185 recorded rows), as raised in §6.

---

## 1. R1 — K1–K7 in the runner, `make eval_matrix` (P1.9b-v2·a2, `2062605`)

**The wiring exists.**
- **The runner.** `journal_replay.ail` `mode_candidate` (`:283–320`):
  1. loads the program and prints `K0BUILD` and `PROGRAM`;
  2. reads the entry records (`jr_records`: `witness.json` and `census.txt`, `:270`);
  3. decodes them with `candidate_checks_run.decode_entry`;
  4. runs `evaluate_candidate`;
  5. prints `KALL [<every K finding>]` and exactly one `KVERDICT <word>\t<first>\t<position>` line.
- **`candidate.py`.**
  - `parse_k` (`:1038`) accepts only a single `KVERDICT` line; two such lines count as no verdict.
  - `decide` (`:1137`) puts K0 first: any K0 finding refuses with `PreflightMismatch` and discards the K verdict (`record["k_discarded"]`, `:1447`). A runner error comes next (exit 2). Only then is the K verdict taken.
  - Exit codes: 0 for reproduced, 1 for diverged or refused (`:1441–1453`).
  - K0's after-run checks (the evaluator, the corpus, the protected span and tree invariance) run before `decide`.
- **One workdir.**
  - `candidate.py:1355` drops `EVAL_WORKDIR` from the passthrough environment.
  - Admit mode and candidate mode both use `jr_workdir()`, whose default is `.motoko/eval-admission-workdir` (`journal_replay.ail:201`, `journal_replay.sh:74–76`).
  - The record names the two-workdir red, `C = P diverged K2@interaction:10`.
- **The Makefile.** `Makefile:3121–3123` defines `eval_matrix` → `journal_replay.sh matrix` → `candidate.py matrix` (`:1598`).
  - It runs every suite a row names, plus `test_mem_guard`, and writes the observed-only `MATRIX.tsv`.
  - It joins on `case_id` into equal, credited, inapplicable or a failure status.
  - It exits 0 only if every row is good and every suite exited 0.
  - `--no-live` is documented as "never a clean matrix".
- **`m15_k_rows.sh`** is deleted, and nothing in `scripts`, `src`, `tools` or the `Makefile` references it.

**M15 K-rows through the runner.** Each row below is a `@live` test in `test_candidate.py:1243–1310`, with the expected row as follows.

| row | expected | test |
|---|---|---|
| `M15.InadmissibleCandidate.path` / `.intent` (the sent-message edit) | diverged `K2:ProjectionDiffers@interaction:14` | `…path_diverges_k2`, `…intent_diverges_k2` (the intent test also asserts the reviewed resource-only record) |
| `…digest_function_only` / `.intent` | diverged `K7:SeedDigestDiffers@snapshot:12` | `…digest_function_only_diverges_k7`, `…_intent_diverges_k7` |
| `M15.EvaluatorTouched` | diverged `K2:UnsafeIdentity@interaction:9` | `…evaluator_touched_diverges_k2` |
| `M15.clean.candidate` | reproduced `-` `-`; score permitted; envelope `checked=K0…K7` | `…clean_candidate_reproduced` |
| `M15.ProtectedRegionTouched.fixture_comment_only` | refused `ProtectedRegionTouched:changed:has_key` | `…comment_only_now_refused` (non-live; asserts 119 spans and that `has_key` is a member) |
| `M15.ProtectedRegionTouched` (the redone search) | diverged `K2:UnsafeIdentity@interaction:5` | `…search_diverges_k2` (asserts `src/core/fs_node` compiled) |
| `M15.DuplicateOrAmbiguousCallId.runner` (swap through admit mode) | refused `A2:MessageDiffers@snapshot:14` | `test_m15_admission_through_runner[swap]` |

**Suites I ran:**
- `EVAL_CANDIDATE_LIVE=0 pytest -k "m15 or decide or observation or a9b or matrix or parse_k"` → exit 0: **14 passed**, 9 skipped (the live tests), 102 s.
  - This covers `test_m13_decide_k0_first_then_the_k_verdict`, `test_eval_matrix_observation_rules`, both A9b post-run tests, the two admit-mode runner cases and all six non-live M15 family tests.
- The full non-live `test_candidate.py` hit the 120 s cap with 102 passed and 0 failed before the kill.
- `ailang check` on `journal_replay.ail` and `candidate_checks_run.ail`: no errors.

**Cited, not re-run (over budget):** the R1 record (PLAN-004 §6 and the delegate answer):
- `make eval_matrix` exit 0, with 621 rows = 185 equal + 425 credited + 11 inapplicable;
- 28 suites at exit 0: pure 180/180, 7 live runners, `test_candidate` 123 passed live in 15m50s, selftest 42/42, `gen_fixtures --check`, `mem_guard` 55;
- `ailang check` ×36, 0 failed;
- mutations MR1–MR14, 14/14 caught.

**The Cs in R1's scope:**
- **C1:** landed (item 6).
- **C2:** landed (item 6).
- **C4:** `M11.live.a8_evaluate_violation_first` → `A8:journal-payload-disagrees@aggregate:invariants:emission-parity`, recorded and equal in `MATRIX.tsv`.
- **C5:** `M9.A9b.post_run_change` / `.post_run_unchanged` exist, and the tests passed in my run.
- **C6:** `scan.ail:93–97` now names `entry_json`/`decode_entry` as the one codec for `witness.json` and `census.txt`, and admit mode writes them (`journal_replay.ail:218–252`).
- **C7:** the reason is stated at `scan.ail:63ff`: `encode_artifact`'s gate refuses a credential-bearing name that D6 only reports. The record says this is asserted live.
- **C9:** the `digests.ail` header is corrected.
- **C14:** PLAN-004 §6 `:999`.

**Result: R1 accepted.** The caveat is CF2: the matrix run must be repeated at a committed E.

## 2. R2 — the protected closure (P1.4b·a2, `0b023b0`)

- **`starting_set.json` compared with `52b7d56`:** exactly **19 symbols added**, 0 removed.
  - 18 are in `ports.ail`: `advance_ordinal`, `empty_world_state`, `envelope_to_call`, `has_children`, `has_key`, `is_beneath`, `lookup_node`, `names_below`, `opt_int_field`, `remove_path`, `segment_below`, `sort_names`, `tool_call_json`, `wake_outcome_detail`, `wake_outcome_id`, `wake_payload`, `wake_read_unbound` and `world_path_kind`.
  - 1 is `world_ordinal.ail:advance`.
  - These are the 14 members R2 ruled plus the 5 group-(a) callees under the operator's ruling.
  - `path_refused` is present and matches `candidate.py`'s `D3_PATHS` and `EVALUATOR_PATHS`.
- **`manifest-A.json` at HEAD:**
  - source `65003110ff5a…`;
  - **119 spans** in 7 files: ports 88, stub_step 11, dst_fault_catalogue 9, session 4, dst_interaction 3, tool_contract 2, world_ordinal 2 (`<imports:1>` and `advance`);
  - 7 protected files;
  - **14 `closure_flags`**: `ambient_*` ×7, `generated_provider_entry`, `generating_approval`, `generating_tool`, `repeat_chunk`, `wake_outcome_of`, `wait_descriptor_to_json` and `wait_descriptors_json`;
  - 137 unlisted callees, of which 123 are `path_refused:*` and 14 are `FLAGGED` (CF3);
  - crosscheck `ok`, 8/8.
- **Regen check:** `protected.py gen --at 65003110 --symbols starting_set.json --skip-crosscheck --allow-flags` into the scratchpad.
  - Output: "119 spans in 7 files … 137 unlisted callees, 14 flagged".
  - The regen equals the committed manifest in every field except `crosscheck`, which the regen skipped.
  - **Manifest-A at HEAD matches.**
- **Checks:**
  - `protected.py check --manifest manifest-A.json --tree . --pins-root .` → "119 spans, 0 findings, 0 pin drift → clean".
  - `pins --at 65003110` → 147 pins, 0 bad.
- **Selftest:** a static count of `selftest.py` finds **42** distinct case ids: 26 `CHECK_CASES`, 11 `R.record`, 6 `gen_case`, with one id shared. This agrees with "42/42".
  - Not re-run, since it took 138 s. The 42/42 result is cited from `0b023b0` and the R1 matrix run.
  - See CF1 for the 9 rows that are missing.
- **Transitive walk and flag behaviour:** `protected.py` walks to a fixed point, and `gen` exits 1 on flags unless `--allow-flags` is given. The selftest cases `gen_flags_direct_callee`, `…_transitive_callee` and `…path_refused_not_flagged` cover this.
- **§0.8:** the red-first run and the 12 mutants are cited from the commit.

**Result: R2 accepted.** CF3 is record-only.

## 3. R3 — the sent-message fixture (P1.9a·a2, `d74079d`)

- **The new edit.** `SENT_MESSAGE_EDIT` edits `phase_vocab.ail` `tool_result_message`, changing its content to `"${content} "`.
  - The file is outside D3's path list and §0.5, and the edit falls in no span of the 119-span manifest.
  - `test_m15_inadmissible_path_edit_changes_a_sent_message` asserts that the change reaches a sent message. This is the row's premise, which the a1 fixture did not meet.
- **The old edit** (`PERMITTED_EDIT`, the digest-only terminator) is kept and renamed.
  - `M15.InadmissibleCandidate.digest_function_only.{passes_path, passes_k0, intent.passes_intent}` → pass.
  - Its K rows are `K7:SeedDigestDiffers@snapshot:12`.
- **New family rows:** `path.passes_protected` and `path.edit_changes_sent_message`.
- **The catching half** is now R1's `K2:ProjectionDiffers@interaction:14`, which is the first of 14 findings in the R3 scratch run.
- **In my run:** the 5 non-live R3 family tests passed.
- **§0.8:** the 4 mutation groups are cited from the commit.
- **The `has_key` test** that fails at `d74079d` is fixed in `2062605`: the test is now `…comment_only_now_refused`, and it passed.

**Result: R3 accepted.**

## 4. R4 — P1.2b's §0.8 record (P1.2b-v2·a2, `bb7a027` and `053904a`)

- **`bb7a027`** is `--allow-empty`, so the record is its commit message: 22 mutants, E1–E7 and A1–A15. Each entry has the exit code, the failing tests and a restore check with a sha256 match. The baseline prefixes are `3820ec3e83f5` (excerpt) and `556fbc1afb27` (association). 21 of the 22 were killed.
- **The one survivor, E7**, is stated honestly. It turns `ledger == rpc` into `ledger && rpc`.
- **`053904a`** kills E7:
  - adds the fixture `m2_excerpt_session_start_no_shape` (`gen_fixtures.py:1490`, regenerated into `association_fixtures.ail`);
  - makes `excerpt.ail:459` assert `excerpt_refused_at(…no_shape, 0, "session_start.shape")`;
  - leaves the guard at `excerpt.ail:203` as `ledger == rpc`;
  - records the E7 re-run on the new tree as exit 1 with a restore match.
- **In my run:**
  - `ailang test excerpt.ail` → 5/5, exit 0;
  - `association.ail` → 31/31, exit 0;
  - `gen_fixtures.py --check` → up to date.
- **Not done:** I did not re-run E7 itself, because that would mean editing a file.

**Result: R4 accepted.**

## 5. The new finding: the `fs_node` decoder callees are neither protected nor refused

**The gap is real.**
- **`src/core/fs_node.ail` exports** `FsNode`, `fs_kind_id` (`:86`), `fs_content_of` (`:93`) and `fs_node_of_kind` (`:99`).
- **`dst_persistence.ail`, which is path-refused (`dst_*`), calls them:**
  - `encode_body` uses `fs_kind_id` and `fs_content_of` (`:479`);
  - the scan uses `fs_content_of` (`:648`);
  - the program decoder uses `fs_node_of_kind` (`:874`, `:894`).
  - The decoder is reached through `decode_artifact` (`:1095`) and `load_program` (`:1344`).
- **Why nothing catches an edit to them:**
  - `fs_node.ail` has no span and is not a protected file;
  - it matches no `path_refused` pattern;
  - it has no entry in `unlisted_callee_status`, because the walk starts at `recording_ports`' bindings and the seams' delegates, not at the program decoder;
  - `FsNode` sits only in `named_types_not_pinned`.
  - So a candidate can edit how the harness's own refused codec decodes the world, and none of D3's pre-run refusals see it.
- **The encode and decode sides share the candidate's `fs_node`.** A symmetric edit therefore leaves both the artifact bytes and the re-encoded `program_digest` unchanged, so K0 passes.
- **The fixture:** `fs_node_edit` (`test_candidate.py:178–199`) adds `#` on decode and strips it on encode.
- **The two tests:**
  - The non-live `test_m15_protected_region_search_passes_protected_refusal` passed in my run. It asserts that the file is in no span, not a protected file, not path-refused, not an evaluator path and not in the unlisted list.
  - The live `…search_diverges_k2` (`K2:UnsafeIdentity@interaction:5`) is cited from the R1 run.
- **What catches it:** K2 does, after the run. D5 requires closure edits to be refused before running, so this is a missing closure member, the same kind of gap as `tool_call_json` in round 1.

**Ruling: accept as a next-revision item. No second rework round.**
- The row is correctly pinned as the observed divergence.
- The search did what D8 asks: it found an edit outside every span that changes a recorder input.
- The gap is recorded in PLAN-004 §6 (`:955–959`).

**Recommended fix, to record for ADR-004's next revision and its implementing part:**
1. Protect `fs_node.ail`'s `fs_kind_id`, `fs_content_of` and `fs_node_of_kind`, and the type `FsNode`. Add the file as a protected file with its `<imports:1>` span, following the `world_ordinal.ail` precedent. That covers the fixture's added import too.
2. Start the closure walk at `load_program` and `decode_artifact` as well, and go through `encode_body`/`program_digest`, which K0 re-encodes with. The walk must not stop at the path-refused `dst_persistence`, because its callees outside refused paths are exactly the gap.
3. Merge this with C8. The evaluator's own `fs_node` import (`scan.ail:120`) goes away or becomes pinned under the same change.
4. After the change, `M15.ProtectedRegionTouched` needs a fresh search (a new edit, or `inapplicable` with the search stated). `…search_passes_protected_refusal` then flips to a refusal.

## 6. MATRIX

This was checked by script (`matrix_check.py` in the scratchpad).

- **Shape:** `MATRIX.expected.tsv` has 622 lines, which is a header plus **621 rows**. Every line has 5 columns, and there are no duplicate `case_id`s. The diff from `52b7d56` is +62/−20 lines.
- **C1 (finding-level `Ak:Name`):**
  - Only 6 rows keep `AdmissionCheck(…)`, all of them verdict-mapping rows (`M10.verdict.*` and `P17a.Refused*`).
  - `M5.ProfileMissed.witness` → `A7:EnvReadOverRecorded`.
  - The M15 A-rows → `A3:PayloadDiffers` ×5 and `A2:MessageDiffers@snapshot:14`, plus the `.runner` row.
  - **Applied.**
- **C2 (literals):** every placeholder the a1 review listed is gone.
  - `M12.entry.scan_refused` is split ×10, e.g. `ScanRefusal:PrivateKeyBlock`.
  - `M13.ProgramUndecodable.garbage` / `.structural` → `…ProgramStructurallyInvalid(artifact-not-an-execution-program)` / `(program-duplicate-ordinal)`.
  - `…run.during_run` → `PreflightMismatch:profile:profile_id`.
  - `M11.live.census_twins` is split ×19.
  - The four `<…>` cells that remain (`M7.import_*` ×3 and `M13.ProtectedRegionTouched.import_statement`) are the literal span name `<imports:1>`, not placeholders.
  - One observation: `census_twins.exit_manifest_writes` has position `…:exit_manifest_reads`. That is correct. The writes twin also adds a read, and `witness_live_test.ail:432–439` asserts both findings in order with reads first.
  - All 19 split rows are credited through the one boolean `m11_census_twins_live` (the two-tier point).
- **G1 / G2 rows are present:**
  - G1 is `M11.live.a8_evaluate_violation_first`, a recorded row.
  - G2 is `M9.A9b.post_run_change` and `.post_run_unchanged`.
- **Row → test:**
  - 610 rows name 420 distinct tests. Each file exists, and each function or label resolves in it.
  - The only rows my literal regex did not match were the `test_candidate.py` parametrised ids (`name[param]`) and `gen_fixtures.py:--check (check_api_model_copy)`. The base functions exist.
  - 11 rows name `-`, and all 11 are `inapplicable`.
- **Test → row:**
  - Every `test_*` in the pure modules that the matrix names has a row: 0 without one.
  - Every `def test_*` in `test_candidate.py` has a row, directly or through its parametrised ids.
  - The exception is the **9 new selftest cases (CF1)**.
- **Observed join:**
  - The untracked `MATRIX.tsv` has 621 rows with the same `case_id`s in the same order and the same `test_name` on every row as HEAD's expected file.
  - My re-join, using `candidate.py`'s rule (a record needs all three fields equal; an assertion needs `pass`), gives **185 equal, 425 credited, 11 inapplicable, 0 bad**. That matches the record exactly.
  - Every row's commit column is `d74079d…+dirty` (CF2).

**Result: accepted**, with CF1 and CF2.

---

## Claim audit

| claim (source) | checked by | result |
|---|---|---|
| HEAD `2062605`; `src/core` = A | `git rev-parse`; `git diff --quiet 65003110 HEAD -- src/core` → 0 | true |
| K1–K7 wired: KVERDICT/KALL, K0 then K, one workdir (`2062605`) | `journal_replay.ail:283–320`; `candidate.py:1038,1137,1355,1388–1453`; decide test passed | true |
| `m15_k_rows.sh` retired | file absent; no references | true |
| `make eval_matrix` exists and exits 0 with 621 rows = 185 + 425 + 11 (`2062605`) | `Makefile:3121`; my re-join of the recorded `MATRIX.tsv` | counts true; the exit 0 is cited, not re-run; produced on `d74079d+dirty` (CF2) |
| `MATRIX.tsv` sha256 `1ac7f001…` (§6) | `sha256sum` | true |
| M15 K-rows: sent-message K2@14, digest K7@12, swap A2@snapshot:14, EvaluatorTouched K2@9, clean reproduced, comment-only refused `has_key`, search K2 UnsafeIdentity@5 | expected rows and test assertions read; non-live halves passed; live halves cited (123 passed) | true (live cited) |
| `test_candidate` 123 passed live (§6) | not re-run (15m50s); non-live full run 102 passed and 0 failed before the 120 s cap; `-k` subset 14 passed | consistent; not re-verified live |
| R2: 19 members, 119 spans, 14 flags (`0b023b0`) | starting-set diff; manifest parse; regen at A | true |
| "142 unlisted callees" (`0b023b0`) | manifest and regen → 137 | **stale** (CF3) |
| crosscheck 8/8 (`0b023b0`) | manifest `crosscheck` | true |
| selftest 42/42 | static count of 42 distinct ids; not re-run | count true; the pass is cited |
| pins 147/0; check 0 findings at HEAD | ran | true |
| R3 sent-message fixture and renamed digest-only rows (`d74079d`) | test and rows read; the 5 family tests passed | true |
| R4 22 mutants, 21 killed, E7 survived then killed (`bb7a027`, `053904a`) | commit record; fixture and assertion present; excerpt 5/5, association 31/31, `gen --check` passed | true (the E7 re-run is cited) |
| `fs_node` decoder callees are neither protected nor refused (R1 finding) | `dst_persistence.ail:189,479,648,874,894`; manifest has no `fs_node` span, file or unlisted entry; the non-live search test passed | **true**; next-revision item (item 5) |
| C1, C2, C4, C5, C6, C7, C9, C14 landed (`2062605`) | rows and sources read | true |
| every test has a MATRIX row | script | true except for the 9 new selftest cases (CF1) |
| C8, C10–C13 | `scan.ail:120`, `admission*.ail` imports; `git diff --stat ailang.lock` → 3/3 | still open |
| my runs left the tree unchanged | `git status --porcelain` before and after, compared with `diff` | true |
