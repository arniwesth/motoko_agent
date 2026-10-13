---
repo: arniwesth/motoko_agent
pr: 261
branch: arniwesth/005-w3-remove-hybrid-mode
ticket: null
title: "refactor(core): hybrid mode leaves core (005 W3)"
---

## Summary

Removes hybrid mode from core: the branch that took a response with no tool call, pulled a fenced
shell block or a shell-looking line out of the prose and ran it as a `bash` tool call. This is
workstream W3 of `PLAN-finalize-policy-migration.md`, which implements 005 ADR-001 Amendment 2
(accepted 2026-10-10): the mechanism is deleted and nothing replaces it.

After this, a response with no tool call that no extension intercepted is a candidate final
answer. `extract_bash` and its helpers are gone, the wire event `hybrid_bash_extracted` no longer
exists and the event vocabulary is `event-vocabulary/4`. `hybrid_tools` is no longer a parameter
of the loop, core no longer reads `tools.hybrid`, and the TUI no longer maps `HYBRID_TOOLS`. The
name stays where a recorded format or the frozen ABI holds it (the journal header's
`boot.hybrid_tools`, the continuation, the exit manifest and the extension context views), and
the host writes `false` there.

## Changes

- refactor(core): core stops turning prose into a tool call (005 W3-2)
- refactor(core): hybrid_bash_extracted event goes, vocabulary to v4 (005 W3-3)
- refactor(core): hybrid_tools parameter leaves the loop (005 W3-4)
- docs(records): mark hybrid records, re-baseline anchors (005 W3-5)

80 files changed.

W3-1 was a probe in a scratch tree and has no commit. W3-7, the change that stops the Compose
extension reading the flag, merged earlier as #255. W3-6 is the gate under *Test evidence* and
adds no change of its own.

**Five of the files are evaluator paths** (`src/eval/journal/` and its `testdata/`). Under 013
ADR-004 D5 that part is an evaluator change and should be reviewed as one. ADR-004's Change 3,
added by W3-5, records it.

- W3-3: `witness.ail`, `witness_live_test.ail` and `testdata/MATRIX.expected.tsv`. The census
  loses its `hybrid_extractions` row (thirteen rows to twelve, 19 twins to 18) and the expected
  matrix loses two rows.
- W3-4: `admission_run.ail:72` and `seams_live_test.ail:160`. They passed the flag the journal
  recorded and now pass nothing, because the entry point no longer takes it.

**The anchor re-baseline is the eight-file, four-profile form**, the one W1 and W2 used, not the
six-file form the plan's W3-5 names. The five clock anchors in `src/core/session.ail` were
re-measured at their new offsets (`:1463`, `:1722`, `:1834`, `:3834`, `:4013`); no clock site was
added, removed or re-routed. All four DST profiles are re-issued against the new table
(`driver_only` 36 to 37, `driver_plus_no_ops` 25 to 26, `driver_plus_compose` 17 to 18,
`driver_plus_herdr` 6 to 7), and the two literals in `scripts/dst/herdr_graded_dst.ail` that
spell the herdr version move with it. W3-5 measured the six-file form first: it leaves
`make driver_plus_herdr` and `make herdr_graded` red on `[attribution-identity-stale]`.

**W3-3 re-pointed a code-graph test where the plan says "with its test".**
`test_multi_subject_rule_fans_out` used the deleted rule as its example and now uses
`ScratchpadResult`, so the file still has 25 tests. The operator has ruled that this stands.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`: Amendment 2
  is the decision. Not edited here.
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`, W3: the work
  items. Not edited here; its W3-5 still says "the six-file form".
- `.agent/projects/003_CSP_core_refactor/ADR-001-csp-core-phase1.md`: the passage that requires
  tool dispatch at the hybrid site is marked superseded for that site.
- `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md`: the passage that
  assigns hybrid synthesis to the response interpreter is marked superseded in part.
- `.agent/projects/013_core_architecture_for_dst/ADR-003-session-journal-and-resume.md`: a note
  in the `header` row at `:267`. `boot.hybrid_tools` is `false` in every header written from here
  on, and no new journal sets `replaces_previous`.
- `.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md`:
  Change 3, described above.
- `.agent/issues/hybrid-bash-extracts-prose-examples-in-native-tool-mode.md`: closed, with a note
  under its non-goal "Do not remove hybrid mode".
- `.agent/plans/AILANG_Composition_Subagent.md`: the open question about Compose's fallback is
  marked as overtaken by W3-7.

## Predicted outcome

- **A prose answer that holds a shell example ends the run. It is not executed.** Checked here by
  one live session on the `default` profile (below): the answer was a `bash` fence, the run ended
  with one `done` event, nothing ran, and the log has no `hybrid_bash_extracted`. The next
  ordinary session is the real check.
- **A model that writes shell blocks where it should make typed tool calls can no longer act.**
  Amendment 2 found two recorded sessions that worked that way, the last on 2026-06-07. No
  extension is shipped for them. A profile for such a model can register a
  `ResponseInterceptor`.
- **A resume across this merge is refused unless forced.** W3-2 deletes the "Hybrid Mode" section
  of `SYSTEM.md`, which changes the system prompt's digest. A session started before the merge
  and resumed after it under the same profile is refused as `Prompt` unless the resume is forced
  (`src/core/journal.ail:1804-1805`). That is the journal working as designed, and it is the
  same consequence W1's edit to `SYSTEM.md` had (the plan's WI-5, #256). Not measured here: no
  session was resumed across the edit.
- **Every journal header written from here on records `hybrid_tools: false`**, whatever the
  profile says. Both live sessions below show it, the one on `ailang` included, whose config
  still sets `tools.hybrid: true`. A session started before the merge keeps `true` in its header.
  If it is resumed after the merge and ends on a stop with no native call before it, the
  evaluator refuses that journal with `HybridPredicate`. Amendment 2 calls that refusal
  conservative and leaves it.
- **`tools.hybrid` in a profile is read by nothing.** All sixteen tracked profiles still carry
  the key, fifteen `false` and `ailang` `true`. What the host does with a config entry it does
  not use is left to its own pull request (the plan's decision 2).
- **Compose is still allowed on `ailang`.** The host now writes `false` into the context views,
  and since #255 Compose does not read it. Checked here by one live session (below): the model
  called `Compose` once and the call was not denied.
- **Old traces need the pinned runner.** A build at `event-vocabulary/4` refuses an
  `event-vocabulary/3` manifest with `ManifestVersionDrifted`. Version 3 is read by commit
  `d59c6a33d359af10c442f903a952cc0488586bf9`, the commit this branch is cut from. Nothing is
  built for the pin and no recorded trace is committed.
- **`make eval_matrix` stays red exactly as it is on `main`.** It exits 2 at `d59c6a33` on 61 of
  621 rows, and it exits 2 here on the same 61 of 619. The two rows that are gone are the two
  W3-3 deletes. The operator's reading of the gate is "no bad row beyond that baseline".
- **CI.** Every target CI runs was run here and passed. CI's own result was not waited for.

## Known leftovers

- **`src/core/parse.ail` is an empty shell.** It holds one private function,
  `find_json_fence_close`, that nothing calls, and no module imports the file. Its header still
  says it holds the extractor "used by v2's hybrid mode". W3-2 deleted what the plan names and
  left the file, by the operator's decision. Whether the file goes, and in which item, is open.
- **A dead arm in `c2_finish_tool_batch`.** No site writes `pending_tool_batched: false` any
  more, so `hybrid_replacement` (`src/core/session.ail:2596-2598`) is always false and its
  replacing arm cannot run. The fold for `replaces_previous` stays, for old journals.
- **Comments still describe the deleted branch.** `src/core/session.ail:456`, `:842` and
  `:2582-2583`; `packages/motoko-ext-abi/types.ail:732` and `:1346`;
  `packages/motoko-ext-repetition-guard/repetition_guard.ail:19`, which cites the
  `hybrid_attempt = None` arm by name; and `src/eval/journal/admission_run.ail:12` and
  `admission.ail:19`, which still list `hybrid_tools` among the inputs the run is given.
- **One evidence copy still passes the argument.**
  `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/hook-probe/hook_calls_model_probe.ail:135`
  is a record of a run at `ce9cb247`. It no longer type-checks against this tree, and no gate
  compiles it. Left as a record.
- **Two test contexts still write `true`**: `src/core/ext/runtime.ail:943` and
  `src/core/test/ext_neutral_registration.ail:34`. Nothing reads the value. They are not among
  the writers the plan lists.
- **Two `SOURCE` pins in the evaluator point at deleted code.**
  `src/eval/journal/stopping.ail:129` and `:137` pin the evaluator's copies of `any_native_call`
  and `session_emitted_native_tool_call` to lines of `session.ail` that W3-2 deleted. The copies
  stay, because the evaluator's two hybrid rules stay for old journals. With `--pins-rev HEAD`
  the protected check reports them as 2 pin drift reports; at `d59c6a33` it reports none.
- **The protected manifest refuses `main` and this branch alike.**
  `python3 tools/eval_protected/protected.py check --manifest tools/eval_protected/manifest-A.json --tree <rev>`
  exits 1 with `119 spans, 2 findings, 0 pin drift reports -> REFUSED` at `d59c6a33` and at this
  branch's head. Not regenerated here; `manifest-A.json:2396` still lists `HybridBashExtracted`.
  That is the evaluator's task (013 ADR-004 D5). No gate runs this check. Inside the matrix,
  `tools/eval_protected/selftest.py` exits 1 here and at `d59c6a33` alike.
- **Two probe scripts still write the key**: `scripts/probe_between_turn_frame.sh:234` and
  `scripts/probe_budget_continue.sh:407`.
- **Two citations of a file that is gone.** `src/core/prompts_test.ail:22` and
  `tools/test_coverage/skip_reasons.json:35` name `src/core/parse_test.ail` as the file whose
  test idiom they follow. Text only.
- **Nothing checks the herdr script's version literal** against the profile's version. It is
  moved by convention, as in W1 and W2.

## Test evidence

All of it ran in the branch's worktree at `056a09d8`, the last commit before this pull request's
record, on AILANG v0.52.5 (`7200786`), each command as `env -u AILANG_FS_SANDBOX <command>` and
one group at a time. `origin/main` was `d59c6a33`, the branch's merge base. The tree was clean
after every group but the last: `make eval_matrix` leaves
`src/eval/journal/testdata/MATRIX.tsv` untracked, and it was moved out of the tree.

| Command | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 59 passed, 0 failed`; 185 `OK` lines, no `FAIL` |
| `make test_coverage_selftest test_coverage` | 0 | `self-test: 0 failure(s)`; 72 files, 49 with tests, `591 of 596 passed, 5 skipped against a record` |
| `make smoke_parity` | 0 | two runs of the nine smokes, `diff -r` empty |
| `make dst` | 0 | 54 targets, `all targets passed`, 1037 s wall at `-j8`; `corpus_pr` ran by itself as the sweep's timed phase, 29000 ms against a ceiling of 180000 ms |
| `make test` | 0 | `agents_md.ail` 12 passed, 0 failed; `All core runtime module tests passed!` |
| `make verify_core verify_mutations verify_classify_check` | 0 | `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare`; `5 falsified, 0 unfalsified`; 18 unit tests OK; `17 contracts, register agrees` |
| `make new_contract_policy BASE=origin/main` | 0 | `no pure func added under src/core/ since origin/main` |
| `make verify_skills_tests verify_skills_refusal smoke_no_delegated_storm verify_profile_dir_agreement tui_context_limit dst_l2` | 0 | skills 62, 11 and 18 passed; `verify_skills_refusal: 51 passed, 0 failed`; four profiles `ohmy_pi=false`; `host and runtime agree on all 14 layouts`; 14 pass, 0 fail; 25 pass, 0 fail |
| `python3 -m pytest tools/code-graph/tests/test_event_subjects.py -q` | 0 | `25 passed` |
| `cd src/tui && bun test src/config.test.ts` | 0 | 16 pass, 0 fail, 42 `expect()` calls |
| `make corpus_pr`, run alone | 0 | 20000 ms against a ceiling of 180000 ms |
| `make eval_matrix`, run alone | **2** | same as `main`; see below |

The counts that differ from W2's gate differ by what W3 deletes. `check_core` type-checks 59
files where it had 60, and `test_coverage` counts 596 tests where it had 616: `parse_test.ail`
and its 19 cases are gone, and so is one inline test in `session.ail`. `smoke_parity` runs nine
smokes where it ran ten. `make test` no longer runs `parse_test.ail`.

`new_contract_policy` reads commits only. It ran with every change committed. `corpus_pr` ran
twice: inside the sweep, alone in its timed phase, and once more as its own `make` after it.

**`make eval_matrix` exits 2 and is read against the baseline.** The operator's decision: the
gate is "no new bad rows beyond the baseline", compared row for row against `join.tsv` from
`d59c6a33`.

```
eval_matrix: 619 rows: credited=418, equal=129, failed=28, inapplicable=11, missing=33
eval_matrix: suites 28, non-zero exit: scripts/eval/test_candidate.py=1, tools/eval_protected/selftest.py=1
```

- The baseline has 621 rows (`sha256:5a6776e4…b255dd8`, measured by W3-1 on an untouched
  `d59c6a33`). This run has 619 (`sha256:68a12a29…7842abc`).
- The only rows in one file and not the other are `M11.census.twin.hybrid_extractions` and
  `M11.live.census_twins.hybrid_extractions`, both `credited` at baseline, both deleted by W3-3.
- No status differs on any of the 619 shared rows, and they are in the same order.
- The 61 bad rows (28 failed, 33 missing) are the same 61. New bad rows: 0.
- The two non-zero suites are the baseline's two, and the log's list of failed and missing cases
  is the same in both runs.

**Two live sessions.** Headless, from the worktree, each on its profile's own model. The
`HERDR_*` variables were unset for both, so that they would not report agent state for the pane
the gate ran in.

1. **`default` profile, a question whose natural answer is a fenced shell example.**

   ```
   MOTOKO_CONFIG=default MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 ./scripts/run-agent.sh \
     "What is the shell command to create an empty file called w3-6-canary.txt in the current
     directory? Answer with one short fenced bash example. Do not run it and do not call any tool."
   ```

   Exit 0 in 7 s, on `openrouter/meta/muse-spark-1.3-contributor`. The answer was a `bash` fence
   holding `touch w3-6-canary.txt`. The session log has 46 events: one `done`, one `run_summary`
   with `finish_reason: stop`, `steps_executed: 1` and one provider call, and one `thinking`
   event with `tool_calls: 0`. It has no `hybrid_bash_extracted`, no `native_tool_calls` and no
   tool result. `w3-6-canary.txt` does not exist afterwards and `git status` did not change. The
   header records `boot.hybrid_tools: false`. The system prompt the session was seeded with does
   not contain "Hybrid Mode".

2. **`ailang` profile, one `Compose` call.**

   ```
   MOTOKO_CONFIG=ailang MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 ./scripts/run-agent.sh \
     'Call the Compose tool exactly once, with intent "Count the lines of the file AGENTS.md in
     the working directory and return the count", intent_kind "analyze" and expected_output
     "one integer". Then answer in one sentence with what the tool returned. Do not call any
     other tool.'
   ```

   The call was allowed. On `openrouter/deepseek/deepseek-v4-pro`, with the profile's four
   extensions loaded, the log has one `native_tool_calls` event naming `Compose`, then
   `compose_start` for the same call id. It has no `native_tool_denied`, and no tool result that
   says `denied_by_policy`. The header records `boot.hybrid_tools: false`, on the one profile
   whose config still sets `tools.hybrid: true`.

   **The session did not finish.** The gate's own 540 s limit stopped it while Compose's
   authoring subagent was on its second attempt of 50: the model had not yet written AILANG that
   parses. So this session has no `done` event, and what it shows is the policy decision, not a
   completed composition. `compose_live_exec` and `driver_plus_compose`, both in the sweep, cover
   Compose's own machinery.

**Also run, outside the gate:**

- `ailang test packages/motoko-ext-compose/compose.ail`, exit 0: `subagent_mode_allows_compose`,
  2 passed. It expects `Allow` under either value of the flag.
- The protected check quoted under *Known leftovers*, at `d59c6a33` and at `056a09d8`.

**Not run:**

- `make verify_ext`. Nothing under `src/core/ext` or `packages` changes.
- The TUI's full jest suite. Two files under `src/tui/src` change, `config.ts` and its test. This
  gate ran that test, `tui_context_limit` and `dst_l2`.
- A second run of the sweep.
- A `Compose` session through to its result.
- A resume across the merge, and a session inside the TUI or a herdr pane.
- CI on this pull request was not waited for.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
