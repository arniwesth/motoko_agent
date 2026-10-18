# W1.1 record: Phase 1 re-grounded at `a94204aa`

Task `034/PLAN-001/W1.1` of [PLAN-001](PLAN-001-effect-disclosure.md), on branch
`arniwesth/034-w1-world-and-catalogue`, cut from `origin/main` at **`a94204aa`** (#279's merge),
2026-10-18. AILANG v0.52.5. A docs-only task: it changes nothing under `src/`, `scripts/` or
`tools/`. It does four things before W1.2 starts:

1. re-reads every Phase 1 anchor at `a94204aa` and records what moved since `e69aaad7` (§1);
2. settles the version numbers W1 and W2 take (§2);
3. writes the three lists into the pull request before any code (§3, §4, §5);
4. states the `manifest-A` arrangement for the operator, as 013 ADR-004's owner, to accept (§6).

Every `file:line` below was read at `a94204aa`. The two scripts in
[`evidence/W1.1/`](evidence/W1.1/) reproduce §3's literal sites and §5's matrix prediction.

## 1. What moved from `e69aaad7` to `a94204aa`

57 commits. Phase 1 starts after Phase 0 (#277) and the Phase 0b probe and withdrawal (#279).

**Byte-identical, so every anchor in them holds.** These 25 paths have no diff between the two
commits:

- `src/core/`: `ports.ail`, `ext_world.ail`, `dst_program.ail`, `dst_persistence.ail`,
  `dst_replay.ail`, `dst_fault_catalogue.ail`, `dst_generator.ail`, `dst_corpus.ail`,
  `dst_invariants.ail`, `dst_attribution_table.ail`, `tool_phase.ail`, `session.ail`, and the four
  profiles (`dst_driver_only.ail`, `dst_driver_plus_no_ops.ail`, `dst_driver_plus_compose.ail`,
  `dst_driver_plus_herdr.ail`);
- `src/eval/journal/`: `world.ail`, `seams.ail`, `witness.ail`, `admission.ail`,
  `source_checks.ail`, `testdata/MATRIX.expected.tsv`;
- `tools/predicate-anchors/anchors.sh`, all of `tools/eval_protected/`, all of `scripts/eval/`.

Under `scripts/dst/` only `world_state_probe.ail` changed (W0.5). The profile table in *What is
true at `e69aaad7`* holds exactly: versions "37", "26", "18", "7" at `dst_driver_only.ail:549`,
`dst_driver_plus_no_ops.ail:238`, `dst_driver_plus_compose.ail:243`, `dst_driver_plus_herdr.ail:163`,
and the same `content_hash` `sha256:38d8a67e…` at `:919`, `:451`, `:420`, `:199`.

**What W0 moved.** Phase 0 changed the `Makefile`, `world_state_probe.ail` and four `src/core`
files (`types.ail`, `tool_runtime.ail`, `tool_dispatch_adapter.ail`, `tool_catalog.ail`), and
added `tool_fault.ail`. The plan's anchors into them are these:

| Cited at `e69aaad7` | At `a94204aa` | Cause |
|---|---|---|
| `Makefile:2558-2571`, the `check_core` loop (W1.2 gate) | `:2560-2573` | W0.5 added two lines to `world_state` at `:2283-2284` |
| `Makefile:3526`, `eval_matrix` (standing rule 4) | `:3528`; the 12 GiB note is `:3524` | the same two lines |
| `Makefile:3193-3203`, `make test` | `:3195-3205` | the same |
| `Makefile:3693`, `test_coverage` | `:3695` | the same |
| `Makefile:2278-2282`, `world_state` | `:2278-2284` | W0.5's `fault_disclosure_witness` entry |
| `world_state_probe.ail:1128-1179`, `exit_code_witness` | `:1135-1186`; W0.5's `fault_disclosure_witness` is `:1243` | W0.5's imports, then the new entry |
| `tool_dispatch_adapter.ail:95-160`, `tool_result_item_to_json`; `:204-213`, `dispatch_one_typed` | `:110`; `:272`, its defensive arm `:286` | W0.3 |
| `tool_runtime.ail:974`, `run_process_result` | `:1017` | W0.2 |
| C3's "one home" | `src/core/tool_fault.ail`, new; the types `EffectDisclosure`, `FaultKind`, `ToolFault` are `types.ail:125-150` | W0.2 |

`Makefile:952-959` and `:1277-1281` sit above the insertion and hold.

**Anchors the plan had wrong at `e69aaad7` already.** Their files did not change, so these are
corrections, not drift:

| Plan says | It is | Effect on W1 |
|---|---|---|
| `observed_classes`, `corpus_pr_dst.ail:545-563` (W1.5) | `:542-558` | none |
| the journal builder `admission.ail:720-737` (W1.1, W1.2) | `admission_program` is `:721-738` | none |
| `required_header_tags_at`, `dst_persistence.ail:398-430` (W1.2) | the function is `:426-428`; `:398-428` is the version-gating block it closes (`version_has_chunk_draw_hi` `:398`, `bounds_arity_at`, `with_bounds_arity`) | W1.2 adds its version test beside `version_has_chunk_draw_hi`, on that pattern |
| "a presence read with the stated default (the `exit_code` precedent, `ports.ail:2638-2648`)" (W1.2) | the presence read is there, but its absent arm **refuses** (`ToolRecordUndecodable`, `:2641`). It does not default | the stage's legacy default (after dispatch) is a new arm, not a copy of the precedent. W1.2 records which it uses, as planned |
| `ext_world.ail` "and its round-trip test"; its header names `ext_world_test.ail` (`:15`) | no such file. The round-trip suite is inline in `ext_world.ail`: `codec_fixture_world` `:740`, tests from `:825` | W1.3's rows (g) go in `ext_world.ail` |
| W1.2's gate: "about 25 literal sites in `scripts/`, `src/eval/`, `src/core/test/`, `src/core/ext/`" | 57 literal sites in 25 files, none in `src/core/test/` or `src/core/ext/`, plus seven anonymous record types of `ScriptedTool`'s shape (§3) | W1.2's `ailang check` list is §3's file list |
| `Makefile:1277-1281` refuses a pair that lost its equal count (W1.6) | the line holds. Its message names "seeds 9 and 13"; the pair is 132 and 12 (`seeded_generator_dst.ail:1179-1180`, `:1225-1226`) | W1.6 re-sweeps the pair; the message should name the new seeds |
| `generating_tool`, `ports.ail:2269-2299` | `:2269-2298` | none |

**Every other Phase 1 anchor holds.** Read at `a94204aa`:

- `ports.ail`: `WorldState` `:183`; `ScriptedTool` `:599-606`; `ToolFailed` `:649`; `ToolExecution`
  `:653-656`; `world_tool` `:1723`, scripted arm `:1745-1748`, empty-queue arm `:1744`;
  `live_tool_outcome` `:1759-1762`; `scripted_tool_outcome` `:1775-1788` (`:1787`);
  `encode_tool_outcome` `:2577-2602`; `decode_tool_outcome` `:2608`.
- `dst_program.ail`: header `:1-16`, imports `:31-40`, version history `:63-131`,
  `program_schema_version` `:132` (`/4`), `decodable_schema_versions` `:151-153`,
  `ExecutionProgram` `:243-252`, pin test `:700-718`.
- `dst_persistence.ail`: `required_header_tags` `:344` (`generator_version` `:346`), repeatable
  tags `:378-385`, encoder line `:550`, `artifact_dir`/`artifact_path` `:1246-1256`.
- `dst_replay.ail`: `tools_of` `:761-772`, `world_state_of` `:831`, `fixture_program` `:1133-1135`.
- `dst_invariants.ail:2242-2244` (keyed on `outcome.payload`); `invariant_set_version` `:228`.
- `dst_fault_catalogue.ail`: version `:55`, `fault_class_*` `:61-63`, `FaultClass` `:234-241`,
  `ToolFailed`'s "did NOT occur" `:346`, `validate_catalogue` `:565-570`, `== 11` `:795`.
- `dst_generator.ail`: comment `:15`, `seed_state` `:395`, `draw` `:433`, `choose_tool` `:740-777`,
  the re-pin note `:1248-1273`, `pinned_canary_v1`/`v2` `:1274-1284`.
- `dst_corpus.ail`: `measured_ms_per_seed` `:347`, `pr_target_ceiling_ms` `:487`,
  `expected_bank_coverage` `:1156`.
- `tool_phase.ail`: `denial_message` `:108`, `delegated_deferred_message` `:211`,
  `tool_outcome_message` `:277`, `tool_fault_message` `:297-304`, `undecodable_arguments_message`
  `:347-355` ("the tool was NOT run", `:353`), anchors `:388`, `:389`, `:484`, the re-seat `:428`,
  the token round trip `:436-437`, the policy `Deny` arm `:569-579`, the exact-bytes test
  `:670-678`. Note `:45`: three imports are joined on one line so that the anchors stay put. A W1.4
  import of `tool_fault` has to keep the net line count above `:388` in view the same way.
- `session.ail`: `policy_denied_message` `:2060`, its call `:3254`; the clock anchors `:1463`,
  `:1722`, `:1834`, `:3834`, `:4013` (`anchors.sh:761-763`). `:2060` lies between `:1834` and
  `:3834`, as W1.4 says.
- `ext_world.ail`: failure-mode header `:15-19`, `scripted_tool_json` `:254-284`, `world_json`
  `:589`, `world_of_json` `:627-640`.
- `seams.ail`: `replay_unrecorded_code`'s `ToolFailed` `:228-234`, `seam_cardinality_code`'s `:251`.
- `source_checks.ail`: K7's reuse note `:50-51`; A2 `MessageDiffers` `:285` within `:285-314`.
- `corpus_pr_dst.ail`: `generator_version()` `:299`, `pending_policy` `:337`, `:419`,
  `program_of` `:428-447`, `fixed_bank` `:628`, `:675`. `seeded_generator_dst.ail`: `:255`, `:597`,
  `program_of` `:600-619`, axis K `:1135-1137`, `v2` `:1145-1148`, `:1153`, `wire_witness`
  `:1177-1180`, `main`'s fixtures `:1224-1228`, `versioned` `:1228`. `corpus_rotating_dst.ail`:
  `:162`, `program_of` `:225-243`. `profile_definition_dst.ail:207`.
- `anchors.sh:110-111`, `:764`; `dst_attribution_table.ail:221`, `:249`, `table_content_hash`
  `:292`; `Makefile:952-959`.
- `tools/eval_protected/starting_set.json` names all seven symbols the Phase 1 intro lists, and
  `MATRIX.expected.tsv:477-481` are the five rows it cites.
- Out-of-tree: `009…/NOTE-d1-fault-reachability-rows-4-and-11.md:8`, `:325-330`, and the
  `59d5cbb9` baseline directory are unchanged.

**W1's surface gains two files, because W0 put C3's one home in a module of its own.** W1.4's
kinds `failed`, `correlation_mismatch`, `denied` and `arguments_undecodable` (C3) do not exist:
`FaultKind` (`types.ail:135-145`) has W0's nine arms only. W1.4 adds them to `types.ail` and their
names to `tool_fault.ail`, or it adds the name constants alone and renders those four kinds from
strings. Either way `src/core/types.ail` and `src/core/tool_fault.ail` join Phase 1's surface.
Neither is protected or anchored. `tool_fault.ail` imports only `types` and `std`, so `tool_phase`
and `session` can import it without a cycle.

**Overlap.** No open pull request touches W1's surface. #234 and #209 change the `Makefile` in the
`verify_strict_extensions` and `verify_skills_tests` targets (`:2640`, `:2744` on their bases), which
W1 does not touch.
No unmerged branch, remote or local, changes `dst_program.ail`, `dst_fault_catalogue.ail`,
`dst_invariants.ail`, `dst_replay.ail` or the four profiles.

## 2. The version numbers

| Version | At `a94204aa` | Other claims | W1 takes |
|---|---|---|---|
| program schema | `execution-program/4` (`dst_program.ail:132`) | 031 PLAN-001 P2.1 claims `/5` (`:434`; also `:43`, `:92`, `:116`), unlanded and undated; 031's addendum A (#272) adds A2 as a second dependant of P2.1; it depends on the part, not on its number. 013 ADR-004 names `/5` twice, in D7's T1 tier and under *Not decided*; both are hypothetical. No code and no branch writes `/5` | **`execution-program/5`**. A note in 031's plan says P2.1 renumbers to the next version free when it lands |
| fault catalogue | `fault-catalogue/2` (`dst_fault_catalogue.ail:55`); hand literal `profile_definition_dst.ail:207` | none | **`fault-catalogue/3`**, count `11` → `13` (`:795`) |
| invariant set (W2) | `invariant-set/2` (`dst_invariants.ail:228`), 42 constructors | none | **`invariant-set/3`**, 42 → 44 (W2.1) |
| generator | `"1"`, a literal at each producer (§4) | none: D8's knob widening still has no plan, branch or pull request (ruling 1 stands) | **`"2"`** at the producers only |
| `driver_only` | "37" | none | **"38"** |
| `no_ops` | "26" | none | **"27"** |
| `compose` | "18" | none | **"19"** |
| `herdr` | "7"; also hand-copied as `"driver_plus_herdr/7"` at `herdr_graded_dst.ail:411` | none | **"8"**, and the copy at `:411` to `/8` |

The profiles take **one bump each in W1**. W1.4 makes it, for the anchor cascade's new
`table_content_hash`, with a dated history paragraph that also names catalogue `/3` (W1.5). W1.5
and W1.6 do not bump again: the four versions are released once, when W1's pull request merges.
W1.6's "any profile not already bumped" therefore bumps nothing, unless W1.4 is split from W1.5
across pull requests.

## 3. List 1: every program builder, and every literal site W1.2 breaks

Found by `evidence/W1.1/litscan.py`, which matches record literals by their field set and skips
record updates (`{ x | … }`) and record types. Run from the repository root as
`python3 <path>/litscan.py . src scripts packages evidence | sort`. Its output at `a94204aa` is
[`evidence/W1.1/literal-sites.tsv`](evidence/W1.1/literal-sites.tsv). A type-check of a copy with
the four types widened was tried first and abandoned. The compiler stops at the first error per
module, so every importer of `ports.ail` fails before its own sites are reached.

**`WorldState` full literals: 3, all in `src/core`.** `empty_world_state` `ports.ail:826`,
`world_of_json` `ext_world.ail:628`, `codec_fixture_world` `ext_world.ail:741`. Every other world
is built by updating `empty_world_state()`, so W1.3's effect log reaches them through `:826`.

**`ExecutionProgram` literals: 20.** W1.3's "every builder W1.1 lists" means the first two groups.

| Group | Site | What it builds |
|---|---|---|
| generated (the generator draws `applied`) | `scripts/dst/corpus_pr_dst.ail:428-447` | the PR bank |
| | `scripts/dst/seeded_generator_dst.ail:600-619` | the seeded suite |
| | `scripts/dst/corpus_rotating_dst.ail:225-243` | the rotating corpus |
| recorded from a scripted run (list empty unless the fixture scripts an applied fault) | `scripts/dst/discovery_dst.ail:806` `program_of` | |
| | `scripts/dst/driver_plus_compose_dst.ail:718` `graded_program` | |
| | `scripts/dst/herdr_graded_dst.ail:400` `graded_program` | |
| | `scripts/dst/strict_replay_dst.ail:637` `program_of` | |
| | `scripts/dst/latency_pair_dst.ail:238` `program_of` | |
| | `scripts/dst/park_wake_dst.ail:658` `program_of` | |
| journal (list empty: "no world truth recorded", W1.2) | `src/eval/journal/admission.ail:721-738` `admission_program` | every admitted journal |
| decoder | `src/core/dst_persistence.ail:1180` `project` | reads the new line per version |
| fixtures and tests | `scripts/dst/execution_program_dst.ail:182`, `scripts/dst/program_persistence_dst.ail:809`, `src/core/dst_persistence.ail:1491`, `src/core/dst_replay.ail:1133`, `src/eval/journal/admission.ail:1177`, `src/eval/journal/candidate_checks.ail:656`, `src/eval/journal/seams_live_test.ail:136`, `src/eval/journal/testdata/scan_fixtures.ail:124` | |
| recorded evidence, not moved | `evidence/D11-CEIL/per_seed_bench.ail:126` | |

`corpus_pr_dst.ail:672-676` (`constructed_program`) updates `program_of`'s result, so it inherits
the field and needs no edit.

**`ScriptedTool` literals: 42.** In `src/core`: `ports.ail:2275` (`generating_tool`'s entry),
`:2643`, `:2652`, `:2657`, `:2660` (`decode_tool_outcome`'s four arms); `ext_world.ail:278`
(`scripted_tools_of`), `:781`, `:788`, `:790`; `dst_replay.ail:1161`. Outside it:

- `scripts/dst/discovery_dst.ail:279-281`, `:1155-1160`, `:1471`, `:1474`, `:1682`, `:1685` (13);
- `scripts/dst/world_state_probe.ail:1064-1067`, `:1154` (5);
- `scripts/dst/strict_replay_dst.ail:1122-1124` (3);
- `scripts/dst/driver_plus_compose_dst.ail:603`, `:606`; `scripts/dst/latency_pair_dst.ail:210`,
  `:331`; `scripts/dst/herdr_graded_dst.ail:153`; `scripts/dst/corpus_judge_dst.ail:926`;
- `src/eval/journal/world.ail:89`, `seams.ail:338`, `witness.ail:412`, `witness_live_test.ail:241`,
  `candidate_checks_live_test.ail:340`.

**Seven anonymous record types of `ScriptedTool`'s shape**, which break as a literal does because
records are closed: `discovery_dst.ail:278`, `:1141`, `:1463`, `:1677`;
`driver_plus_compose_dst.ail:602`; `herdr_graded_dst.ail:152`, `:159`. W1.2 can name
`ScriptedTool` there instead.

**`ToolFailed` constructions: 10.** `ports.ail:1781` (`scripted_tool_outcome`), `:2766` (a test);
`scripts/dst/fault_catalogue_dst.ail:153`; `scripts/dst/invariants_dst.ail:221`, `:1183`, `:1187`,
`:1271`; `src/eval/journal/seams.ail:231` (unrecorded: before dispatch), `:251` (cardinality: after
dispatch); `seams_live_test.ail:103`.

**W1.2's `ailang check` list** is the 24 files outside `src/core/*.ail` named above, the evidence
file excepted: 56 literal sites and the seven types.

**Hard-coded `execution-program/4` asserts in evaluator tests**, which the bump breaks at run time,
not at compile time. W1.2 moves each to `/5`, as `program_persistence_dst.ail` moves its own:
`src/eval/journal/admission.ail:1240` (`test_m9_program_shape`), `admission_live_test.ail:127`
(`p16_end_case`), `scan.ail:1029` (`test_m12_artifact_frame`). `candidate_checks.ail:658` is a
fixture written at `/4`, which stays decodable; it does not move.

## 4. List 2: every `generator_version` site

At `a94204aa`, 18 lines match `generator_version: "1"` or define `generator_version()`. They are
the plan's 17 and `evidence/D11-CEIL/per_seed_bench.ail:63`, which the plan's count left out.

**Producers: move `"1"` → `"2"` in W1.6.** Each is the version a generator run is drawn under:

| Site | Why it is a producer |
|---|---|
| `scripts/dst/corpus_pr_dst.ail:299` | feeds `generated_world_at` (`:311`) and so the bank |
| `scripts/dst/seeded_generator_dst.ail:255` | the seeded suite's runs, axis K, `wire_witness` |
| `scripts/dst/corpus_rotating_dst.ail:162` | the rotating corpus (`:174`) |
| `scripts/dst/export_trace.ail:104` | "kept byte-for-byte in step with `corpus_pr_dst.ail:299-313`" (`:99`). Left at "1", the trace view would show a different world for the same seed |

**Fixture literals: do not move.** Hand-built programs under generator ids that are not
`motoko_driver_only`, a report fixture, and an inline test. Their version names nothing the
generator draws:
`corpus_pr_dst.ail:675` (`motoko_constructed`), `driver_plus_compose_dst.ail:722`,
`latency_pair_dst.ail:241`, `herdr_graded_dst.ail:404`, `execution_program_dst.ail:185`,
`strict_replay_dst.ail:649`, `discovery_dst.ail:818`, `park_wake_dst.ail:662`,
`run_report_dst.ail:213` and `:222` (with the path literal `:215`), `dst_replay.ail:1135`.

**Recorded evidence: does not move.** `evidence/D11-CEIL/per_seed_bench.ail:63`.

**Comments: do not move.** `dst_generator.ail:15` and `seeded_generator_dst.ail:597` describe
stage 2's hand-authored programs.

**Sites the pattern does not match, which W1.6 must also handle:**

- *Move with the bump:* axis K, `seeded_generator_dst.ail:1135-1137` (`== "1"` and the message's
  `/1`); the canary calls `:1139` (`"1"`), `:1145` (`"2"`), `:1153` (`"1"`); `versioned` `:1228`
  (`"2"`); `pinned_canary_v1`/`v2`, `dst_generator.ail:1274-1284`. W1.6 states how.
- *Version-independent, do not move:* the site-22 demonstration `corpus_pr_dst.ail:1065` (`"2"`)
  and `:1068` (`"1"`), which shows that version 2 at seed s aliases version 1 at seed s+1 whatever
  the current version is; `dst_generator.ail`'s inline tests `:1389-1510` and `:1681`.
- *Derived, no literal:* `generator_version: initial.gen.version` in the three generated builders
  (`corpus_pr_dst.ail:431`, `seeded_generator_dst.ail:604`, `corpus_rotating_dst.ail:229`).
- *Readers of the value:* `seed_state` (`dst_generator.ail:395`) hashes it into the stream;
  `dst_persistence.ail:346` requires the header line and `:550` writes it; `artifact_dir`
  (`:1246-1248`) puts it in the path, so bank artifacts move from `…/motoko_driver_only/1/` to
  `…/2/` under `.ailang/dst-corpus`, which is untracked and rewritten by `corpus_pr`
  (`Makefile:1873`). No tracked file and no `Makefile` grep names a `/1/` artifact path. The
  `seeded_generator` grep reads `version=[0-9]*` and takes any value.
- *Not this version:* `src/eval/journal`'s `generator_version` is evaluator E's pinned commit
  (`admission.ail:85`, `:583-599`), a different quantity. None of its literals move.

## 5. List 3: the `eval_matrix` rows W1 is predicted to move

**How it was predicted.** `evidence/W1.1/predict_matrix.sh a94204aa <dir>` clones the tree twice,
widens W1's four types by one field in the second clone, and runs
`scripts/eval/test_candidate.py` in both with `EVAL_CANDIDATE_LIVE=0`, recording each test's
observation as `make eval_matrix` does. The protected check is lexical, so the widening need not
compile. Its output at `a94204aa` is
[`evidence/W1.1/predict_matrix.out`](evidence/W1.1/predict_matrix.out): 11 failed, 92 passed,
13 skipped and 7 errors at the base, and 17 failed, 86 passed at the widened tree. The 7 errors
are runner tests whose identity collection fails in a scratch clone (`journal_replay: identity
collection failed`), the same in both trees.

**Why rows move.** `test_candidate.py` builds each candidate on `HEAD` and checks it against
`manifest-A`, which is pinned at `65003110`. The checker reports findings file by file in the
manifest's order (`dst_fault_catalogue`, `dst_interaction`, `ports`, `session`, `stub_step`, …)
and, within a file, in span order (`protected.py:554-650`). A row records only the **first**
finding. At `a94204aa`, `HEAD` already differs from A in two places: `session.ail`'s and
`stub_step.ail`'s imports regions. Both sort after `ports.ail`, so the rows that refuse a
`ports.ail` edit still see their own finding first. W1 changes `ports.ail` spans: `WorldState`
(`:183`, W1.3), `ScriptedTool` (`:599`), `ToolOutcome` (`:647`), and the functions W1.2 and W1.3
edit. `WorldState` is the first span in `ports.ail` after `ScriptedStep`, so after W1 every
candidate's first finding is `ProtectedRegionTouched:changed:WorldState`.

**Rows that pass today and move: 6.**

| `MATRIX.expected.tsv` | Case | Expects, and observed at the base | After W1 |
|---|---|---|---|
| `:477` | `M13.ProtectedRegionTouched.span_hash` | `changed:tool_outcome_record` | `changed:WorldState` |
| `:478` | `M13.ProtectedRegionTouched.missing` | `missing:scripted_step_faults` | `changed:WorldState` |
| `:479` | `M13.ProtectedRegionTouched.duplicate` | `duplicate:provider_api_model` | `changed:WorldState` |
| `:480` | `M13.ProtectedRegionTouched.import_statement` | `changed:<imports:1>` | `changed:WorldState` |
| `:481` | `M13.ProtectedRegionTouched.moved` | `moved:provider_api_model` | `changed:WorldState` |
| `:610` | `M15.ProtectedRegionTouched.fixture_comment_only` | `changed:has_key` | `changed:WorldState` |

`:610` is the one the plan missed. `:482` (`checker_error`) does not move: the lexer error exits 2
before any finding.

**Rows that fail today and whose observation changes: 10.** They are failing at `3ae506cc`, at W0's
head and at `a94204aa`, because `manifest-A` is stale against `HEAD` (W0's baseline README, the
`test_candidate.py` row). They stay failed, and their observed first finding changes from
`changed:<imports:1>` to `changed:WorldState`. A row-by-row comparison shows them as changed, so
they are on the list.

- Measured by the script (6): `:483` `M13.clean.refusals`; `:560`, `:563`, `:565`, `:566`, `:567`
  (`M15.*.passes_*`). The script also shows `test_m15_inadmissible_path_passes_path_refusal`
  changing. It feeds `:558` and `:561`, whose matrix observation at the base is `fail (asserted)`,
  so those two rows are predicted not to change.
- Inferred, because they are live or error in a scratch clone (4): `:492`
  `M13.GuardTripped.run`, `:542` `M13.PreflightMismatch.run.dev_evaluator_real_entry`, `:556` and
  `:557` `M13.ProgramUndecodable.run(.live)`. Each observes the protected refusal
  `changed:<imports:1>` at the base, and that is the step W1 changes.

**Rows that move only if W1.2 forgets them: 4.** `:189` `P16.EndSuspended3`, `:191`
`P16.EndFinalize` (`admission_live_test.ail:127`), `:193` `P16.program_shape`
(`admission.ail:1240`), `:426` `M12.artifact.frame` (`scan.ail:1029`) assert
`execution-program/4`. W1.2 moves the three asserts with the bump (§3), so these are predicted
**not** to move. If one moves, it is a finding.

**Rows W1.4 adds.** W1.4's journal fixture, recorded with the pre-W1 denial and undecodable bytes,
adds new rows, admitted by A2 and K7. Their case ids are W1.4's to name.

**Predicted not to move.** Every other row. The journal replays read recorded tool content
verbatim and no fixture holds a denial or an undecodable message (review 2, finding 6). The seam
faults gain a stage in their payload, but both sides of every comparison are encoded by the same
build. The generator bump does not reach journals. This part is inferred. W1.8's run tests it.

**The rule this gives W1.8.** The changed rows are exactly the 6 + 10 above and W1.4's new rows. If
W1.5 changes a protected span or the imports of `dst_fault_catalogue.ail` (`:39-40`, `:61-63`,
`:82-85`, `:152-154`), the label becomes that span's instead of `WorldState`, and the set of rows
stays the same. W1.5 has no reason to touch them.

## 6. The `manifest-A` arrangement, for the operator to accept before W1.2

**Who owns it.** The operator. 013 ADR-004 and PLAN-004 name no other owner, and PLAN-004 §5 says
"New questions go to the operator through the graph". ADR-004 D5: a change to a protected span is
"a basis change". The precedent, `0b023b0d`, changed `tools/eval_protected/` only and regenerated
the manifest **at the same A**, `gen --at 65003110 --allow-flags`, because the symbol set changed.
W1's case is the other one: the symbols stay, and their source changes on `main`.

**What W1 touches in `starting_set.json`.** In `src/core/ports.ail`: the types `WorldState`
(W1.3), `ScriptedTool` (W1.2), `ToolOutcome` (W1.2, `ToolFailed`'s stage); the functions
`encode_tool_outcome` and `decode_tool_outcome` (W1.2), `scripted_tool_outcome` (W1.2, the stage),
`world_tool` (W1.3, the effect log), and `empty_world_state`, whose literal must state the new
field (W1.3). The plan's list of seven lacks `empty_world_state`. Possibly `ports.ail`'s
`<imports:1>`, if W1.3's `effect_key` digest needs a new import. In `src/core/session.ail`:
`<imports:1>`, if W1.4's `policy_denied_message` imports `tool_fault`. That region is already
stale against A. Nothing in `dst_fault_catalogue.ail`, `dst_interaction.ail`, `stub_step.ail`,
`tool_contract.ail` or `world_ordinal.ail`. Type closure: a new type that a pinned type names,
such as a stage type in `ScriptedTool`, is pinned at the next `gen` and raises the manifest's span
count above 119. `test_m15_protected_region_comment_only_now_refused` asserts `== 119`. Naming the
stage with an existing type (`string`, `bool`) or declaring it outside `ports.ail`, `session.ail`
and `stub_step.ail` keeps the count. W1.2 records which.

**The evaluator files W1 itself edits** (all under `src/eval/journal/**`, D3's evaluator paths):
`admission.ail`, `world.ail`, `seams.ail`, `witness.ail`, `scan.ail`, `admission_live_test.ail`,
`witness_live_test.ail`, `seams_live_test.ail`, `candidate_checks.ail`,
`candidate_checks_live_test.ail`, `testdata/scan_fixtures.ail`. They are forced by the
type and version changes, or are W1.4's remedy. None holds a `-- SOURCE` pin of a span W1 changes;
the session pins (`configuration.ail:75`, `stopping.ail:129`, `:137`) already drift and are
reported, never refused.

**Proposed arrangement:**

1. **W1 does not regenerate `manifest-A`** and does not edit `tools/eval_protected/`,
   `scripts/eval/` or `MATRIX.expected.tsv`. W1.8 runs `make eval_matrix` against the base and
   accepts the result if the changed rows are exactly §5's list. The 6 credited rows that move are
   recorded in the pull request as an expected consequence of a basis change, not re-pinned.
2. **After W1 merges, the operator, as ADR-004's owner, directs one evaluator change** in its own
   worktree and pull request:
   - move A to W1's merge commit (`test_candidate.py`'s `A`, `:45`);
   - `protected.py gen --at <merge> --symbols tools/eval_protected/starting_set.json --allow-flags`.
     Use `--skip-crosscheck` and say so if the cross-check still fails as at the base (W0
     baseline: `package "sunholo/motoko_ext_abi" not found in ailang.lock`);
   - review the closure, as `0b023b0d` did. The span count and the flags are compared with 119
     and 14;
   - `protected.py pins --at <merge>`, `selftest.py`, then `make eval_matrix`.
   
   It is expected to return §5's 6 rows to their expectations. It also lets the 10 rows failing
   today on the stale `session.ail` and `stub_step.ail` imports get past the protected step;
   whether they then pass is for that change to measure.
3. **If the operator wants W1 green on `eval_matrix` instead,** the same steps become W1's last
   commit, after W1.8's comparison has been recorded against the unregenerated manifest. W1.8 then
   runs `make eval_matrix` a second time, and the PR states both runs.

**The operator's answer** is recorded here before W1.2 starts: **accepted, Option A, 2026-10-18.**
W1 leaves `tools/eval_protected/`, `scripts/eval/` and `MATRIX.expected.tsv` untouched (points 1
and 2 above); W1.8 verifies that the changed rows match §5; a separate evaluator pull request after
W1 merges moves `A` and regenerates `manifest-A`. Point 3 is not taken.

**W1.2's answer to the type-closure question above:** the dispatch stage is a `bool`,
`ScriptedTool.after_dispatch` and `ToolFailed.after_dispatch`, not a new sum type. A sum declared
in `ports.ail` would be pinned at the next `gen` and move the span count off 119; declared in
`types.ail` or `tool_fault.ail` it needs a new import in `ports.ail`, which changes the protected
`<imports:1>` region, the first span in `ports.ail`, and so the first finding of every row §5
predicts. A `bool` does neither, and W1.2 adds no function that a protected `ports.ail` function
calls, so the closure flags stay at 14. With W1.2 alone the first `ports.ail` finding is
`changed:ScriptedTool`; it becomes `changed:WorldState` when W1.3 edits `WorldState`, as §5 predicts.
