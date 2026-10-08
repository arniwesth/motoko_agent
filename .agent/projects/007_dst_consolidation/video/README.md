# Motoko DST explainer

`motoko-dst-explainer.mp4` is a narrated **4 min 8 s**, 1920×1080, 30 fps explanation of the repository's deterministic simulation testing system. `dst.py` is the complete film: eight Manim scenes deriving from `Explainer`, based on `tools/explainer/examples/minimal.py`. Narration is the tool's local synthetic voice; captions carry the same words.

Source snapshot: **`7a48869a3eeb33d5d0c27cedb5fe66948fd97299`**, branch `feat/explainer-tool`, inspected 2026-10-03. This is a source-grounded explanation, **not a fresh DST acceptance run**. The film says this explicitly. Existing working-tree changes were preserved. The Makefile had an unrelated local change in `verify_native_path_guard`; the cited DST definitions match HEAD.

## Scenes and sources

Paths below are relative to the repository root unless linked. Every scene also has its own `self.source(...)` line. “007 ADR” means [the definition and taxonomy ADR](../ADR-001-motoko-dst-definition-and-taxonomy.md); “009 ADR” means [the deterministic test-world architecture ADR](../../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md). The starting overview is `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`.

| Scene | What it shows | Claim-level grounding |
|---|---|---|
| `S1_Idea` | Swap the environment around the real driver; seed → execution → trace → invariants. | Overview, “What DST means” and “Architecture”; 007 ADR D1–D2, single-actor logical-fault scope; `src/core/dst_driver_only.ail`, `driver_only()` and empty installed set; 009 ADR D10, profile-specific naming. |
| `S2_Boundary` | Production phases exchange typed requests, responses and explicit successor state; returned evidence reaches the checker. | `src/core/ports.ail`, `WorldState`, `virtual_clock` (1305–1307), `recording_clock` (1851–1865); `src/core/session.ail`, `TracedSessionResult`; `src/core/dst_execution.ail`, `execution_of`. The clock narration follows the implementation, not the older design's no-advance rule. |
| `S3_DiscoveryReplay` | Reactive seeded discovery records an exact program; strict and regression replay have different comparison obligations. | `src/core/dst_generator.ail`, request-dependent choice and explicit generator state; `src/core/dst_program.ail`, `ExecutionProgram`; `src/core/dst_replay.ail`, `regression_fatal`, common comparison, reconstitution and independent witnesses; 009 ADR D2/D8 for manifest/profile reproduction scope. |
| `S4_FaultsTime` | Fault classes cross environment boundaries; virtual latency straddles a tool deadline; approval deadlines remain waived. | `src/core/dst_fault_catalogue.ail`, `required_class_ids()` lists **11** ids, `fault_catalogue()` gives applicability, delivery constructors, recovery branches and logical transitions; `catalogue_coverage_gaps()` names the missing clock-driven approval policy. `src/core/dst_generator.ail`, deadline-relative tool choice and `test_the_late_choice_exceeds_the_requests_own_deadline`. Eleven catalogue entries does **not** mean eleven reached classes in every profile. |
| `S5_Oracle` | A trace is checked for structural obligations; system failure and harness failure stay distinct. | `src/core/dst_invariants.ail`, `InvariantFamily`, `all_families()` and its `length == 13` test, `family_obligation`, `journal_fold_findings`; `src/core/dst_execution.ail`, `execution_of`/`result_of`; `src/core/dst_result.ail`, `SystemRun`, `HarnessFailure`, `DstResult` and the terminal-trace contract. Thirteen is the current enumeration, not a claim that every run exercises every family. |
| `S6_Profiles` | Baseline coverage, compose mediation and no-op coverage have different meanings. | `src/core/dst_driver_only.ail`, `driver_only_version() == "32"` and empty install list; `src/core/dst_driver_plus_compose.ail`, `compose_profile_version() == "13"`, `installed_extension_ids`, `criterion_2_slot_ids`, `excluded_slot_ids` and `test_the_coverage_mediates_exactly_one_hook`; `src/core/dst_driver_plus_no_ops.ail`, the coverage test with `world_mediating_hooks == 0`; `src/core/dst_profile_coverage.ail` for disclosure and coverage rules. These are selected examples, not an exhaustive profile inventory: `dst_driver_plus_herdr.ail` also exists. |
| `S7_Gates` | `make dst` combines established deterministic layers with generated-world gates and corpus search. | HEAD `Makefile`, `DST_TARGETS`, `DST_TIMED_TARGETS`, `dst`, `corpus_pr`, `corpus_rotating`, `invariants`; `src/core/dst_corpus.ail`, corpus members, minimums, fault/branch obligations and rotating-window checks; overview “Layers, as built”. No CI status, performance measurement or claim of a fresh green sweep is made. |
| `S8_Limits` | What structural testing can expose; excluded failure domains; designed program shrinking; tests for the tester. | 007 ADR D1.3/D2 and overview's structural-oracle/live-calibration distinction; `src/core/dst_fault_catalogue.ail`, parser exclusion, physical-fault scope and coverage gaps; `src/core/dst_replay.ail`, independent-witness rationale; `src/core/dst_generator.ail`, seed-sensitivity negative controls; [dst-discovery-replay.mmd](../mmd/dst-discovery-replay.mmd), `version` node's program-shrinking design. Searches of the current `src/core/dst_*.ail` and `scripts/dst` found no failure-preserving program reducer, so it is explicitly labeled **DESIGNED**, not built. |

## Illustrative rather than measured

- All boxes, arrows, transitions and trace cells are explanatory drawings, not captures of a particular execution. The sample trace omits intermediate records; it is not a valid serialized fixture.
- The deadline diagram has no numeric axis. Its dots show alternative completion orders, not simultaneous completions, a measured latency or a measured success rate. This is said in the caption.
- Colors consistently identify production code (blue), modeled world (teal), generator (purple), obligations/caveats (yellow), and failures (red). They do not encode measured quantities.
- The profile versions, eleven catalogue entries, thirteen invariant families and one-millisecond clock tick are read from current code. No suite size, seed throughput, bug-discovery rate or universal coverage percentage is invented.
- The film depicts selected fault examples and selected profiles. It does not equate catalogue membership, a declared invariant, or a profile record with exercised coverage.
- The film uses source inspection, not a DST test run, as evidence of implementation. It does not claim the current acceptance gates all pass. In particular, HEAD's Makefile contains `DST_KNOWN_RED`; the film makes no green-build claim.

## Disagreements and claims deliberately narrowed

1. **Clock reads:** 009 D4 and `dst-world-boundary.mmd` specify reads that do not advance world time. Current `ports.virtual_clock` returns `clock_ms` and increments its successor by **1 ms**; `recording_clock` records the actual delta. Scene 2 follows the code. This is a substantive difference, not merely a dated comment.
2. **Built versus historical target:** `dst-as-built.mmd` still labels seeded generation deferred, while `dst-world-boundary.mmd` and `dst-discovery-replay.mmd` say their target does not exist at their historical HEAD. Current generator, program, replay, profile, fault and invariant implementations do exist. Those diagrams supplied conceptual structure, not present-day implementation status.
3. **Extension coverage:** the overview preserves both zero-coverage and later no-op-only caveats, including a statement that no profile covers effectful mediation. The current compose profile and its explicit mediation assertion contradict that blanket statement. Scene 6 names the current profile and limits its claim to the covered response interceptor. It does not transfer that evidence to every compose path or other extensions. Current compose code excludes `tool_provider[0]`; its old header's seven-hook count is also stale, so the film does not repeat it.
4. **Invariant counts:** historical prose mentions twelve or sixteen families. The current `InvariantFamily`/`all_families()` enumeration and its count assertion say **thirteen**, including `JournalFold`. Scene 5 uses that count.
5. **Fault coverage:** eleven catalogue ids are not eleven unconditionally reachable faults. In particular, `approval_deadline_exceeded` has no declaring production policy; end-of-input is not a clock timeout. The film shows the waiver instead of claiming a modeled approval timeout race.
6. **Shrinking:** the design calls for reduction of valid programs while preserving the failure. No implementation was located in the inspected DST modules or scripts. The film labels that feature **DESIGNED** and qualifies the absence as an inspection result. Exact replay itself is implemented.
7. **No-op profile:** the current code has a criterion-1 prompt shaper as well as vacuous criterion-2 hooks. The film says **no world-mediating hooks**, not that every covered behavior is literally an identity function.
8. **Harness failure scope:** the film describes runner-observable invalid-program and mismatch failures. `dst_result.ail` also documents that raw capability denial terminates evaluation nonzero without a typed failure or preserved partial trace. The picture must not be read as a promise that every failure returns a `HarnessFailure`.

## Re-render

From the repository root, using the already installed environment:

```sh
tools/explainer/explainer lint .agent/projects/007_dst_consolidation/video/dst.py
tools/explainer/explainer say .agent/projects/007_dst_consolidation/video/dst.py
tools/explainer/explainer render .agent/projects/007_dst_consolidation/video/dst.py --draft
tools/explainer/explainer sheet .agent/projects/007_dst_consolidation/video/dst.py --draft
tools/explainer/explainer render .agent/projects/007_dst_consolidation/video/dst.py
```

`OUTPUT` sets the final filename. Scratch clips, reports, logs and contact sheets stay under the tool's `/tmp/explainer-media/` default. No tool code was edited and no installation was run.

## Authoring-tool test

- **Helpful:** the minimal example is sufficient to start; `say`/`rest` removes manual voice timing; shared fonts, caption placement, source lines and panels make a consistent visual vocabulary; cached local narration and isolated scene renders support iteration. Geometry lint made a cheap first pass possible without drawing.
- **README clarity:** the root-relative invocation of `tools/explainer/explainer` is followed by `examples/minimal.py` in Quick start. From the repository root that example needs the `tools/explainer/` prefix; from the tool directory the launcher should be `./explainer`. I used the actual repository-relative paths and did not invoke the ambiguous example command. Optional helper keyword arguments are easier to discover from `kit.py` and the worked example than from the README's signature table. The guide accurately warns that geometry lint does not judge visual balance or content truth.
- **Lint:** the first pass was clean geometrically and estimated 4:29. That duration report prompted caption shortening; the second pass estimated 4:04 with zero errors and warnings. No planted defects were used and no geometry repair is credited to lint.
- **Outside lint's remit:** manual code review caught the false no-advance clock sentence while lint was green. Reading current enumeration/profile bodies also prevented stale counts and stale coverage claims. The tool cannot validate these content claims.
- **Draft-only timing surprise:** draft 1 exited 0 but reported three `caption_cut` warnings, each approximately 0.1 s early, despite `rest()` at those sites and no warning in dry lint. This is consistent with 15 fps frame quantization. A film-local `rest(0.15)` margin removed all three in draft 2. No change to the kit was needed. The README's description of `rest()` sounds stronger than this observed behavior; a documented frame margin would help.
- **Visual findings:** I inspected contact sheets for all eight scenes. A text-to-text `ReplacementTransform` produced garbled intermediate glyphs; a sequential fade fixed it. The boundary arrows looked detached, so I attached them to rails descending from their boxes. A short profile-contract panel had uncomfortable text padding, so I enlarged and repositioned it. None was a rest-pose geometry error. I regenerated the draft sheets and inspected the three changed scenes again. The kit's ordinary caption crossfades also briefly show old and new text together; that is visible in transition samples and is not a static overlap finding.
- **CLI behavior:** all film CLI commands completed successfully. The first narrated render created 32 clips; the second draft reused them. Default scratch placement kept the repository free of intermediate artifacts, as required. The draft-only warnings above were the only unexpected diagnostic. `say` exposed the spoken expansions and phonemes; it does not constitute listening to the synthesized delivery.
- **Runs:** **3 standalone lint runs, 2 draft renders, 1 final render**. Also 2 `say` calls and 2 draft `sheet` calls. The third lint was clean at an estimated 4:08; draft 2 was clean at 4:09. No setup, dependency installation, tool patch, commit, push or GitHub action was performed.

## Final verification

The required full `render` command exited **0**. The tool decoded the finished movie and checked it against the rendered frame count. Its JSON report records 248.24 seconds, `ok: true`, no lint findings, no overlapping narration, and no missing clip starts. Voice QA here consists of the pronunciation listing, synchronization and loudness checks; I did not listen to the voice or run optional transcription.

Final render report, verbatim:

```text
8 scenes, 4 min 8 s, 1920x1080 at 30 fps (final)
  S1_Idea          29.9 s  4 captions
  S2_Boundary      28.1 s  4 captions
  S3_DiscoveryReplay   31.0 s  4 captions
  S4_FaultsTime    31.6 s  4 captions
  S5_Oracle        31.4 s  4 captions
  S6_Profiles      30.6 s  4 captions
  S7_Gates         32.5 s  4 captions
  S8_Limits        33.3 s  4 captions
lint: 0 errors, 0 warnings
voice: 32 clips, 182.6 s of speech, 0 overlaps (af_heart)
  sync: worst 23 ms, 0 clips not found where their scene put them
  loudness: -17.3 LUFS, peak -1.0 dBFS
/workspaces/motoko_agent/.agent/projects/007_dst_consolidation/video/motoko-dst-explainer.mp4
ok
```

Only `dst.py`, `README.md` and `motoko-dst-explainer.mp4` were created in the repository. Existing files and the checked-out branch were preserved.
