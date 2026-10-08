---
repo: arniwesth/motoko_agent
pr: 243
branch: chore/ailang-v0.52.5
ticket: null
title: "chore: AILANG v0.47.2 -> v0.52.5 — src/core/session fits the compile cache again"
---

## Summary

Moves the AILANG toolchain pin from v0.47.2 to v0.52.5, the latest release. v0.47.2 refuses to
cache a compiled artifact over 16 MiB, and the type info for `src/core/session` is 29.3 MB, so
every `ailang` process that imports session printed the warning below and compiled the module
again: about 35 s on every Motoko start in this container. v0.52.2 raised the limits to 64 MiB per
artifact and 128 MiB per module (sunholo-data/ailang `07e1a89bc`, the fix for
sunholo-data/ailang#1328). The operator reported the warning on 2026-10-08 and asked for the fix.

Running the gates on the new version found two things the bump changes besides the cache, and
both are fixed here at the operator's instruction. A row of `declared_vs_performed` pinned a
name-resolution order the compiler has reversed. And seven gates failed on the v0.52.5 stdlib
because the ambient inventory could no longer prove one builtin pure. Each has its own section
below. An independent review then asked for one more thing, also done here: the test-coverage
exception the old pin needed is removed, so three core files are in blocking coverage again.
With all four commits, `make dst` passes all 54 targets on v0.52.5.

```
Warning: CACHE_WRITE_FAILED module=src/core/session stage=encoding
 path=src/core/.ailang/cache/compile/modules/src__core__session/coretypeinfo.gob: ARTIFACT_TOO_LARGE:
 ...: artifact exceeds blob byte limit; using fresh compilation
```

## Changes

- chore: AILANG v0.47.2 -> v0.52.5
- fix(dst): on AILANG v0.52 the import shadow is an escape — LIMITATION 18 moves to group 3 (031 ADR-001 Amendment 6)
- fix(ext_ambient_inventory): a closed-row caller proves a builtin pure, whatever an effect-variable caller beside it carries
- ci: session.ail, ext/runtime.ail and test/scripted_ports.ail are in blocking test coverage again

The bump is 26 files:

- `scripts/install-prerequisites.sh`: `AILANG_REF` and `AILANG_MIN_VERSION`.
- `ailang.toml`: the floor, `>=0.52.5`. CI builds the toolchain from this line
  (`.github/actions/dst-setup`), and `make CI=1 sync_packages` fails unless it equals `AILANG_REF`.
- `ailang.lock` and the 23 `packages/*/ailang.lock`: regenerated with v0.52.5. Besides the
  stamps, the root lock takes two content hashes that had already drifted on `main`
  (`motoko_ext_herdr`, `motoko_ext_test_dummy`), and the package locks take the current
  `motoko_ext_abi` hash. No dependency version moved.

The first fix is 14 files, eight of them the amendment's artifact:

- `scripts/dst/run_declared_vs_performed.sh`: LIMITATION 18 is a group-3 row; the fourth group,
  its checker and its score line are removed.
- `scripts/dst/fixtures/adr001_boundary/gate/expected.json`: the two import-shadow rows are
  labelled `fail`. Their pins are unchanged.
- `tools/ext_ambient_inventory/hook_scope.py`: docstrings and two rejection reasons that said the
  compiler runs the import. No code path changes.
- `scripts/dst/adr001_boundary_mutgate_spec.tsv` and `adr001_boundary_mutgate.tsv`: the row's
  mutation, replaced.
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`:
  Amendment 6, and `evidence/amendment-6/`.

The second fix is 2 files:

- `tools/ext_ambient_inventory/derive.py`: the order of two branches in `builtin_effects`, the
  rule as its header states it, and a `builtin rule` line in the self-test.
- `tools/ext_ambient_inventory/fixtures/mutgate.tsv`: three mutations of that order.

The coverage change is 3 files, each removing what its own comment said to delete once AILANG
issue 1328 was fixed:

- `Makefile`: `TEST_COVERAGE_SLOW`, its timeout and the `test_coverage_slow` target are gone;
  `test_coverage` walks every file, and `terminal_trace` runs `session.ail`'s tests again.
- `.github/workflows/verify-extensions.yml`: the `coverage_slow` job is gone, so no job is
  `continue-on-error`. The limits of `dst_gates_heavy` and `coverage` go back to 25 minutes from
  45 and 60.
- `tools/test_coverage/derive.py`: `--exclude`, `--only` and the partial-walk case are gone, by
  reversing the change `9e79056e` made to the file.

No file under `src/` or `packages/` changes, apart from the lockfiles.

## Governing docs

- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`:
  the registration boundary. **Amendment 6**, added here, records the reversed name-resolution
  order under the ADR's own rule that a change is a numbered amendment with an artifact attached
  (`evidence/amendment-6/ARTIFACT.txt`).

- `.agent/projects/009_motoko_dst_execution/NOTE-d12-build-classifier-3.md` (WI-D12): the
  ambient inventory and its builtin rule. It states the rule as the second fix now implements
  it: a builtin is proven effect-free when some `std/*` export whose body calls it carries a
  closed empty cached row, and what is rejected is a builtin reached *only* from private helpers,
  effect-variable exports or a module with no cached interface. No document is amended for it.

No project document governs the toolchain bump itself. Where the repository already records the
cache defect:

- `.github/workflows/verify-extensions.yml`: the `dst_gates_heavy` and `coverage` jobs carried
  timeouts of 45 and 60 minutes "since AILANG v0.47", each with a note to re-measure and lower
  them once this is fixed upstream. The last commit lowers both to 25, the limit from before.
- `Makefile` (`TEST_COVERAGE_SLOW`), the workflow's `coverage_slow` job and
  `tools/test_coverage/derive.py` each carried a note to delete the coverage exception once
  AILANG issue 1328 was fixed. The last commit deletes it.
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md`:
  what the defect costs a sweep (fifty fresh compilations of session in one `make dst` log).
- sunholo-data/ailang#1328, closed upstream on 2026-10-06.

## Predicted outcome

- **The warning stops and a warm start is fast.** A headless start, run to the provider's
  rejection of a made-up model id, took 34.6 s and 35.0 s on v0.47.2 and 2.3 s and 2.1 s on
  v0.52.5 once the cache was filled (50.2 s for the first, cold start). Checked on the JSONL
  wire, where runtime stderr lines arrive as `warning` events.
- **The stale-lock warning stops too.** `main` prints `dependency sunholo/motoko_ext_herdr content
  changed ... Run 'ailang lock' to update` on every `ailang` call; the regenerated root lock ends
  that.
- **Nothing changes in a container until its toolchain is reinstalled**
  (`scripts/install-prerequisites.sh`, or an image rebuild). Until then the installed v0.47.2 on
  this tree prints `WARNING VER001 (toolchain-skew)` and still works; v0.52.5 on a branch still
  locked by v0.47.2 prints the same warning. Both directions checked with
  `ailang check src/core/types.ail`, exit 0.
- **The 88 tests of `session.ail`, `ext/runtime.ail` and `test/scripted_ports.ail` can block a
  merge again.** They run in `test_coverage`, inside the `test_coverage + smoke_parity` job; the
  `test_coverage_slow` check no longer exists. Checked by this pull request's next CI run: that
  job walks 624 tests and the check list has no non-blocking entry.
- **Two CI limits are 25 minutes again.** On three earlier runs of this pull request
  `DST gates (heavy)` took 4.5 to 6.5 minutes and `test_coverage + smoke_parity` 5.5 to 7, the
  second without the three files, which add under 2 minutes locally. If the removed check was
  listed as required in the branch's protection rules, that entry has to be removed there; the
  author cannot see those rules.
- **`DST gates (rest)` goes green.** It was the one red job on the bump and on the first fix,
  failing on `profile_definition`, `driver_only` and `ext_hook_scope_selftest`; every other job
  passed both times. The second fix is what those three need. Checked by this pull request's
  next CI run. No workflow runs `make dst` or `declared_vs_performed`, so CI never showed the row
  the first fix addresses.
- **Headroom is about 2.3x, not unlimited.** At 29.3 MB against a 64 MiB limit, the same warning
  returns if session's type info more than doubles.

Four upstream changes between the two versions can change what this repository's code or gates
do. Two were looked for before the sweep, the sweep found the third and CI found the fourth:

- An imported name that the module also defines is now compile error MOD015 (v0.52.0). Not
  present in what `make check_core` compiles, which passes.
- A `run` flag placed after the file path is now an error (v0.51.0). No such call was found by
  grep in `Makefile`, `scripts/`, `tools/`, `src/tui/src`, `packages/` or `.github/`; the TUI
  passes its flags before `src/core/supervisor.ail` and the program's arguments after `--`.
- A local binder now shadows an import of the same name (v0.52.0). One row of
  `declared_vs_performed` pinned the old order. Fixed here; first section below.
- `std/list` gained effect-polymorphic functions that call the builtin `_list_length`. The
  ambient inventory stopped proving that builtin pure. Fixed here; second section below.

## Fixed here: a name-resolution order the suite pinned has reversed

`declared_vs_performed`'s LIMITATION 18 pinned a fact about the compiler, fact 6 of ADR-001 in
project 031 (N62): an imported name outranks a local `let` of the same name. AILANG v0.52.0
reversed that on purpose (AILANG issue 1467, "local binders no longer captured by imports,
builtins or constructors of the same name"). On the bump alone the row went red and named the
class it belongs in.

Measured on both versions with `ailang run --caps IO,FS --entry main`
(`.agent/projects/031_system_one_decisions/evidence/amendment-6/ARTIFACT.txt` has the sources and
the raw output):

| Construction | v0.47.2 | v0.52.5 |
|---|---|---|
| a local `let make_hooks` over an imported `make_hooks` (the suite's fixture) | `result=2`: the import ran, no effect | `NAMED RULE ESCAPE`, `result=1`: the local ran and performed |
| a local `let body` over an imported `body` | `result=2` | `PAYLOAD SHADOW ESCAPE`, `result=1` |
| a parameter `body` over an imported `body` | `result=2`: the import ran, not the argument | `result=7`: the argument ran |
| a same-module `func make_hooks` beside an imported one | `result=2`: the import ran | does not compile, `MOD015` |

`ailang check` accepts the first three on both versions, with no warning.

**The boundary did not move.** The registration-shape gate resolves locals first (ADR-001 D2) and
rejects both import-shadow fixtures on v0.52.5 as it did before, for `payload-let-bound` and
`delegation-let-bound`. Nothing the gate accepts changes meaning.

**The row's class did.** Up to v0.47.2 the compiled program was harmless and the gate's rejection
was an over-rejection, taken by design. On v0.52.5 the construction is a real escape and the
rejection is what stops it. LIMITATION 18 is now scored with the compiler-accepted escapes (group
3, thirteen rows), the fourth group has no member and is removed, and ADR-001 Amendment 6 records
it. The mutation that proves the row can go red is replaced, because the old one changed the
imported body, which the row no longer reads.

**The rest of the tree.** The scoping change applies to every `.ail` file. A scan of 494 files
under `src`, `packages`, `scripts` and `tools` (4,952 imported lowercase names) found no local
binder that shares a name with an import outside the three boundary fixtures written for this
case. The scan is a regular-expression heuristic, not a parser; its method and limits are in the
artifact.

## Fixed here: seven gates were red on the v0.52.5 stdlib, for one cause

With the compiler and the stdlib both at v0.52.5, `make dst` failed seven targets:
`ext_ambient_inventory`, `ext_ambient_inventory_selftest`, `ext_hook_scope_selftest`,
`profile_definition`, `driver_only`, `driver_plus_compose` and `driver_plus_no_ops`. CI runs three
of them and was red on those three. All seven failed on one line of the ambient inventory:

```
UNRESOLVED -- fail closed, triage required:
  compaction_structural  packages/motoko-ext-compaction-structural/compaction_structural.ail:246  <builtin>._list_length  [effect-variable]
  compose  packages/motoko-ext-compose/authoring/dispatcher.ail:321  <builtin>._list_length  [effect-variable]
  ...
```

**Cause.** `tools/ext_ambient_inventory/derive.py` proves a builtin pure from the stdlib exports
that call it. `builtin_effects` ranked an effect-variable caller above a closed-row caller. In
v0.52.5's `std/list`, `mapE`, `filterE`, `foldlE` and `flatMapE` are effect-polymorphic and call
`_list_length` directly, so the builtin had both a closed-row caller (`length`, `nth`, `last`)
and row-variable callers, and read as unprovable. Two extensions call it directly and failed
closed: `compaction_structural` (one call, in a test function) and `compose` (nineteen calls in
seven files).

**The tool said two things that no longer agreed.** Its header comment said no export calling the
builtin may carry a row variable. The WI-D12 note, `builtin_effects`' own docstring and the
self-test's control, `control_pure_builtin.ail`, said a closed-row caller is the proof; the
control names `_list_length` and says it "must NOT be a rejection". No stdlib before v0.52 had a
builtin with both kinds of caller, so the two had never met.

**The operator's choice.** Two ways to close it were put to the operator on 2026-10-08: edit the
twenty call sites to use `std/list.length` and move the control to another builtin, or change
the order so that a closed-row caller is sufficient proof. The operator chose the second.

**What changed.** The two branches in `builtin_effects` are swapped: a closed-row caller proves
the builtin pure, and an effect-variable caller beside it takes nothing away, because the variable
is its callback's and not the builtin's. A caller that carries labels still decides the other way,
as before. The header comment states the rule as the code now has it.

**Scope, measured.**

- `_list_length` is the only builtin the swap reclassifies on v0.52.5, of 327 the tool sees. On
  v0.47.2 it reclassifies none, because no builtin there has both kinds of caller.
- On v0.52.5 the derivation is `PORT-MEDIATED (4 of 20)`, `AMBIENT (16)`, `UNRESOLVED (0)`,
  line for line what it was before the stdlib moved. No extension's verdict differs from `main`.
- The compiler's own registry gives `_list_length: list[a] -> int` on both versions.

**What it gives up.** A builtin that took an effectful callback would be pure in a pure caller and
effectful in a polymorphic one, and would now read as pure. v0.52.5's `std/list` says, beside
`mapE`, that a builtin cannot take an effectful callback "yet". The docstring names this as the
first thing to re-read if that changes.

**The rule is tested on both sides.** No installed stdlib has every case (v0.47.2 has no builtin
with both kinds of caller, v0.52.5 has none with an effect-variable caller alone), so the
self-test gains a `builtin rule` line that asserts the order on a synthetic stdlib: a closed-row
caller proves; a builtin reached only from an effect-variable export, only from a private helper,
or from a labelled caller is still rejected. Three mutations, one per side, each turn that line
red (`tools/ext_ambient_inventory/fixtures/mutgate.tsv`).

## Review

An independent review by Codex (`gpt-6.1-sol`) on 2026-10-08, of head `d9d1cf9f`, in its own
detached worktree with a v0.52.5 it built itself from the tag. It was told to read the diff before
this body and was given none of the author's conclusions. Its verdict: **merge after the listed
fix.** It found no correctness defect in either changed gate.

| # | Finding | Reproduced by the author | Disposition |
|---|---|---|---|
| 1 | **Three files are still outside blocking test coverage, for a reason that no longer holds.** `Makefile:3613` (`TEST_COVERAGE_SLOW`) excludes `src/core/session.ail`, `src/core/ext/runtime.ail` and `src/core/test/scripted_ports.ail` from `test_coverage`, and so from `make dst`. Their CI job, `coverage_slow`, has `continue-on-error: true` (`.github/workflows/verify-extensions.yml:215`), so a failure there cannot block a merge. Both places say to delete the exception once AILANG issue 1328 is fixed. | Yes. On v0.52.5, `python3 tools/test_coverage/derive.py --jobs 1 --timeout 600 --only` each of the three: 88 of 88 tests pass (41, 37, 10), the slowest file at 39 s against the 600 s cap on filled caches. The reviewer measured 78, 30 and 6 s. The upstream fixes are in v0.52.2 and later. | **Fixed here**, at the operator's instruction, in `2412f3d4`: the list, the target, the CI job and the tool's split are removed. `make test_coverage` on v0.52.5 walks 624 tests, 619 passed and 5 skipped against a record, with the three files at 37 of 37, 41 of 41 and 10 of 10. |
| 2 | **A count in this body was wrong.** `compose` calls `_list_length` nineteen times, not eighteen: `validator.ail:252` has two calls on one line, and the author counted lines. | Yes: 19 calls on 18 lines in 7 files, so 20 direct calls with `compaction_structural`'s one. | **Corrected above.** The commit message of `a8b3ab03` still says 18 and 19; it is pushed and is left as it is. |

The reviewer's one opinion, not a defect: the depth canary's notes (`Makefile:394-402`) explain
the instrument by saying AILANG has no tail-call elimination, and v0.52.0 added tail calls. The
canary passes on v0.52.5. Whether its pinned depths still measure what the notes say was not
looked into here.

Claims the reviewer re-measured, each matching this body: the headless start times (2.28 s and
2.25 s warm, 57.7 s cold, 36.6 s on v0.47.2 with the warning), the 29.3 MB artifact,
`make check_core`, `make declared_vs_performed` (137 passed, group 3 at 13 of 13), the 29 gate
fixtures with `--ailang-check`, the one builtin of 327 reclassified and none of 318 on v0.47.2,
the inventory's verdicts, both mutation gates, the four name-resolution probes on both compilers,
the shadow scan's figures, and that all 24 committed lockfiles pass `ailang lock --check`.

Not re-run by the reviewer: the full 54-target sweep, `corpus_pr`, `eval_matrix`, CI, and the
whole suite on v0.47.2.

## Test evidence

All on this branch in one worktree, with v0.52.5 built from the `v0.52.5` tag into a scratch
directory (the container's shared `~/.local/bin/ailang` is still v0.47.2) and its own `std`
beside it.

**One correction to how the first sweep was run.** The compiler read its own stdlib, but
`tools/ext_ambient_inventory/derive.py` reads stdlib sources from `AILANG_STDLIB_PATH` or else
`~/.local/share/ailang/std`, which in this container is v0.47.2's. So the first sweep paired the
v0.52.5 compiler with v0.47.2 stdlib sources for the gates built on that tool, and was green on
gates that CI, which has both at v0.52.5, showed red. The later sweeps set the variable.

- **The defect, on `origin/main` (`36ce3973`) with v0.47.2.**
  `MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 AILANG_FS_SANDBOX=workdir MOTOKO_CONFIG=default MODEL=anthropic/claude-nonexistent-probe ./scripts/run-agent.sh "say hi"`,
  twice: 34.6 s and 35.0 s, one `CACHE_WRITE_FAILED` warning event each, and no
  `src__core__session` directory in the cache afterwards.
- **The same command on this branch with v0.52.5,** three times from an empty cache: 50.2 s,
  2.3 s, 2.1 s, no `CACHE_WRITE_FAILED` event. The cache holds
  `src__core__session/coretypeinfo.gob` at 29,315,957 bytes. The only warning events left are the
  model registry's provenance line and the missing API key.
- **`make check_core`** on v0.52.5: exit 0. `src/core/ type-check: 60 passed, 0 failed`,
  `verify_extensions (default): 9 booted, 0 failed`, herdr `orchestrator.ail` 90 of 90 tests.
- **The root lock is stable:** a second `ailang lock` after regenerating the package locks
  changes only `generated_at`.
- **`ailang check src/core/session.ail` on a filled cache:** 33.2 s on v0.47.2 (which prints the
  warning each time), 2.3 s, 1.8 s and 1.7 s on v0.52.5.
- **`make dst` on the bump alone** (`a7c77571`, 54 targets, `-j8`, stdlib sources at v0.47.2 for
  the inventory tool, as corrected above): exit 2 after 1,228 s from cold caches. 53 targets
  pass; `declared_vs_performed` reports 136 passed, 1 failed, LIMITATION 18. The log has no
  `CACHE_WRITE_FAILED` line.
- **The first fix**, for LIMITATION 18, on v0.52.5: `make declared_vs_performed` 137 passed, 0 failed,
  group 3 at 13 of 13. `hook_scope.py --gate-fixtures --ailang-check`: 29 ok, 0 failures. The
  mutation gate for the row's new mutation: baseline green, mutated red, restored green. On
  v0.47.2 the same suite is red on that row alone, with its escape evidence absent.
- **`make dst` on the first fix** (`3a8afa6b`), compiler and stdlib both at v0.52.5: exit 2 after 359 s
  on filled caches. 47 targets pass, `declared_vs_performed` among them. The seven named above
  fail, each on the `_list_length` line.
- **CI on the bump** (`023857d7`) **and on the first fix** (`a66722c5`): `DST gates (rest)`
  failed both times, on `profile_definition`, `driver_only` and `ext_hook_scope_selftest`.
  Passed both times: `DST gates (heavy)` in 6 m 34 s and 4 m 28 s, `test_coverage +
  smoke_parity` in 5 m 43 s and 6 m 39 s, `check_core + verify_extensions +
  smoke_no_delegated_storm`, `verify_core + mutations + classify + contract policy`, `pr-corpus`
  and `dst_l2`.
- **The second fix**, compiler and stdlib both at v0.52.5: `make ext_ambient_inventory_selftest`
  0 failures, with `control_pure_builtin.ail` resolved clean, the `builtin rule` line ok and the
  yield 4 of 20. The same self-test against v0.47.2 stdlib sources: 0 failures. `derive.py`
  exits 0 with `RESULT: PASS -- 20/20 extensions resolved, 19/19 std modules resolved, 0
  unresolved symbols`; its output differs from the derivation taken before the rule change, with
  v0.47.2 stdlib sources, in the source-revision line only.
- **The mutation gate for the rule:** 3 of 3 discriminate, each baseline green, mutated red,
  restored green, bytes the same.
- **`make dst` on the second fix** (`a8b3ab03`), compiler and stdlib both at v0.52.5: exit 0,
  all 54 targets passed, 307 s on filled caches, no `CACHE_WRITE_FAILED` line.
- **CI on the second fix** (`d9d1cf9f`): every job passed, `DST gates (rest)` in 9 m 14 s.
- **The coverage change**, compiler and stdlib both at v0.52.5: `make test_coverage_selftest`
  0 failures; `make test_coverage` reports 73 files discovered, 50 carrying tests, 624 tests,
  619 passed, 5 skipped against a record, in 1 m 23 s. The slowest file is `session.ail` at 53 s,
  9% of the 600 s per-file cap. `make terminal_trace` passes with `session.ail`'s tests in it.
  The workflow file parses, with six jobs and none `continue-on-error`.
- **`make dst` on the coverage change** (`2412f3d4`), compiler and stdlib both at v0.52.5: exit 0,
  all 54 targets passed, 371 s on filled caches.
- **After merging `main`** (`bf23ae73`). #239 and #241 landed on `main` after the coverage change
  was pushed, both touching the workflow file and the Makefile, so this pull request stopped being
  mergeable and CI did not start on `cc60b8d8`. One conflict, in the workflow: #241 added three
  steps to the end of the `core` job on the lines above a comment this branch rewrote; both are
  kept. The merge brings in `src/core/context_limit.ail`, `src/core/rpc.ail` and two verification
  scripts that had only run on v0.47.2. On the merged tree, compiler and stdlib both at v0.52.5:
  `ailang lock --check` says the lock is current; the shadow scan finds the same six candidates
  in 496 files; `make check_core` 60 of 60; `make verify_profile_dir_agreement` agrees on all 14
  layouts; `make verify_strict_context_limit`, `verify_core`, `verify_classify_check` and
  `new_contract_policy` exit 0; `make dst` exits 0, all 54 targets passed, 344 s.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
