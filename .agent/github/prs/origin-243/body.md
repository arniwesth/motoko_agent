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

Running the gates on the new version found two things the bump changes besides the cache. One is
fixed here, at the operator's instruction: a row of `declared_vs_performed` pinned a name-resolution
order the compiler has reversed. The other is **open and keeps CI red**: seven gates fail on the
v0.52.5 stdlib because the ambient inventory can no longer prove one builtin pure. Each has its own
section below.

```
Warning: CACHE_WRITE_FAILED module=src/core/session stage=encoding
 path=src/core/.ailang/cache/compile/modules/src__core__session/coretypeinfo.gob: ARTIFACT_TOO_LARGE:
 ...: artifact exceeds blob byte limit; using fresh compilation
```

## Changes

- chore: AILANG v0.47.2 -> v0.52.5
- fix(dst): on AILANG v0.52 the import shadow is an escape — LIMITATION 18 moves to group 3 (031 ADR-001 Amendment 6)

The bump is 26 files:

- `scripts/install-prerequisites.sh`: `AILANG_REF` and `AILANG_MIN_VERSION`.
- `ailang.toml`: the floor, `>=0.52.5`. CI builds the toolchain from this line
  (`.github/actions/dst-setup`), and `make CI=1 sync_packages` fails unless it equals `AILANG_REF`.
- `ailang.lock` and the 23 `packages/*/ailang.lock`: regenerated with v0.52.5. Besides the
  stamps, the root lock takes two content hashes that had already drifted on `main`
  (`motoko_ext_herdr`, `motoko_ext_test_dummy`), and the package locks take the current
  `motoko_ext_abi` hash. No dependency version moved.

The fix is 14 files, eight of them the amendment's artifact:

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

No file under `src/` or `packages/` changes, apart from the lockfiles.

## Governing docs

- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`:
  the registration boundary. **Amendment 6**, added here, records the reversed name-resolution
  order under the ADR's own rule that a change is a numbered amendment with an artifact attached
  (`evidence/amendment-6/ARTIFACT.txt`).

No project document governs the toolchain bump itself. Where the repository already records the
cache defect:

- `.github/workflows/verify-extensions.yml`: the `dst_gates_heavy` and `coverage` jobs carry
  timeouts of 45 and 60 minutes "since AILANG v0.47", each with a note to re-measure and lower
  them once this is fixed upstream. This pull request does not change them; see Predicted outcome.
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
- **This pull request's CI run is the first run of the gates on v0.52.5 in CI.** Its job
  durations are what the two raised timeouts should be re-measured from. Lowering them is left
  for a follow-up.
- **CI stays red on `DST gates (rest)` until the open finding below is decided.** On the bump
  alone that job failed on `profile_definition`, `driver_only` and `ext_hook_scope_selftest`;
  every other job passed. No workflow runs `make dst` or `declared_vs_performed`, so CI never
  showed the row that is fixed here.
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
  ambient inventory stops proving that builtin pure. Open; second section below.

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

## Open: seven gates are red on the v0.52.5 stdlib, for one cause

With the compiler and the stdlib both at v0.52.5, `make dst` fails seven targets:
`ext_ambient_inventory`, `ext_ambient_inventory_selftest`, `ext_hook_scope_selftest`,
`profile_definition`, `driver_only`, `driver_plus_compose` and `driver_plus_no_ops`. CI runs three
of them and is red on those three. All seven fail on one line of the ambient inventory:

```
UNRESOLVED -- fail closed, triage required:
  compaction_structural  packages/motoko-ext-compaction-structural/compaction_structural.ail:246  <builtin>._list_length  [effect-variable]
  compose  packages/motoko-ext-compose/authoring/dispatcher.ail:321  <builtin>._list_length  [effect-variable]
  ...
```

**Cause.** `tools/ext_ambient_inventory/derive.py` proves a builtin pure from the stdlib exports
that call it. Its stated rule (`:140-144`): some export calling the builtin carries a closed empty
row, and no export calling it carries labels or a row variable. In v0.52.5's `std/list`, `mapE`,
`filterE`, `foldlE` and `flatMapE` are effect-polymorphic and call `_list_length` directly, so the
builtin now has both a closed-row caller (`length`, `nth`, `last`) and row-variable callers, and
is classed unprovable. Two extensions call it directly and fail closed: `compaction_structural`
(one call, in a test function) and `compose` (eighteen calls in seven files).

**Scope, measured.** On v0.52.5, `_list_length` is the only builtin with this mixed evidence, of
327 the tool sees. On v0.47.2 no builtin has it. The compiler's own registry gives
`_list_length: list[a] -> int` on both versions.

**The tool states two things that no longer agree.** Its header gives the rule above. Its
self-test's control, `tools/ext_ambient_inventory/fixtures/control_pure_builtin.ail`, says
`_list_length` "is provably effect-free on compiler-derived evidence -- `std/list.length`'s body
calls it and carries a closed empty cached row -- so it must NOT be a rejection". On v0.47.2 both
held. On v0.52.5 the rule rejects what the control says must pass.

**Not decided here.** Two ways to close it, and the choice is the operator's:

1. Keep the rule, change the callers: the two extensions call `std/list.length`, and the control
   moves to another builtin. The gate's rule is untouched; nineteen call sites in two packages
   and the tool's own control change.
2. Change the rule: a closed-row caller proves the builtin pure whatever other exports call it.
   One line in `builtin_effects`, a no-op on v0.47.2, and the control holds as written. It gives
   up the protection the stricter rule would offer if a builtin ever took an effectful callback,
   which v0.52.5's `std/list` says a builtin cannot do "yet".

## Test evidence

All on this branch in one worktree, with v0.52.5 built from the `v0.52.5` tag into a scratch
directory (the container's shared `~/.local/bin/ailang` is still v0.47.2) and its own `std`
beside it.

**One correction to how the first sweep was run.** The compiler read its own stdlib, but
`tools/ext_ambient_inventory/derive.py` reads stdlib sources from `AILANG_STDLIB_PATH` or else
`~/.local/share/ailang/std`, which in this container is v0.47.2's. So the first sweep paired the
v0.52.5 compiler with v0.47.2 stdlib sources for the gates built on that tool, and was green on
gates that CI, which has both at v0.52.5, showed red. The later sweep sets the variable.

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
- **The fix for LIMITATION 18**, on v0.52.5: `make declared_vs_performed` 137 passed, 0 failed,
  group 3 at 13 of 13. `hook_scope.py --gate-fixtures --ailang-check`: 29 ok, 0 failures. The
  mutation gate for the row's new mutation: baseline green, mutated red, restored green. On
  v0.47.2 the same suite is red on that row alone, with its escape evidence absent.
- **`make dst` on the fix** (`3a8afa6b`), compiler and stdlib both at v0.52.5: exit 2 after 359 s
  on filled caches. 47 targets pass, `declared_vs_performed` among them. The seven named above
  fail, each on the `_list_length` line.
- **CI on the bump** (`023857d7`): `DST gates (rest)` failed on `profile_definition`,
  `driver_only` and `ext_hook_scope_selftest`. Passed: `DST gates (heavy)` in 6 m 34 s,
  `test_coverage + smoke_parity` in 5 m 43 s, `check_core + verify_extensions +
  smoke_no_delegated_storm`, `verify_core + mutations + classify + contract policy`, `pr-corpus`
  and `dst_l2`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
