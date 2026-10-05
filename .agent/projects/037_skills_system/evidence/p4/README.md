# 037 P4 — evidence index

Evidence for PLAN-001 §5 P4, the effectful shell of `packages/motoko-ext-skills/`
(`register.ail` and its manifest). Everything here was produced on 2026-10-04 in
`/workspaces/motoko_agent-skills` on `feat/skills-extension`, with AILANG v0.47.2. The
package code these files describe is at commit `3213cd42`; `register.ail` itself is
unchanged since `2365f91e`. The commit after `3213cd42` adds this folder only.

## Two trees

The four inventory gates find extensions through the root `ailang.toml`, and wiring the
root manifest is P5's. So each gate was run in two trees, both at `3213cd42`:

| Tree | What it is | What it shows |
|---|---|---|
| **worktree** | `/workspaces/motoko_agent-skills` as committed. The package is not in the root manifest | No gate is newly red against P2's `GATES.tsv` |
| **wired clone** | A depth-1 clone of the branch under the worktree's gitignored `.motoko/herdr-delegates/p4/wired/`, with the package added to the root manifest, the root lock regenerated and `make registry_gen` run. `gates/wired/WIRING.diff` is the whole difference. Nothing in it is committed, and it is not under `/tmp`, where the tools refuse to run | The `skills` row |

## Package checks (`logs/`)

Each log starts with the directory, the command and the commit, and ends with the exit
status.

| File | Command | Result |
|---|---|---|
| `check_register.log` | `AILANG_RELAX_MODULES=1 ailang check register.ail`, in the package directory | no errors, exit 0 |
| `test_register.log` | `ailang test --no-color register.ail`, in the package directory | 18 of 18, exit 0 |
| `test_dir.log` | `ailang test --no-color .`, in the package directory | 91 of 91, exit 0 (62 in `skills.ail`, 11 in `a6b_test.ail`, 18 in `register.ail`) |
| `test_from_root.log` | `ailang test --no-color packages/motoko-ext-skills`, at the worktree root | 91 of 91, exit 0 |
| `test_package_mode.log` | `ailang test --no-color --package .` | 11 of 11, exit 0. Package mode runs `*_test.ail` only, as P3 found |
| `effects_max_narrowed.out` | Two experiments in the wired clone, both undone afterwards | See below |

**The manifest's effect ceiling.** P3 set `[effects] max` to the eleven effects of
`ToolProvider`'s row in anticipation. `effects_max_narrowed.out` shows it is needed:

- With `max = ["Env", "FS"]`, `ailang check register.ail` exits 1: `effect ceiling
  violation in package sunholo/motoko_ext_skills: effects [IO Process AI Net SharedMem
  Clock Stream Rand Trace] not in max [Env FS]`, at `skills_handle`.
- With `skills_handle` declared `! {FS}` instead, the check exits 1 at
  `ToolProvider(["Skill"], skills_handle)`: `incompatible closed rows`. The capability's
  row is closed, so the handler has to declare all eleven.

## Gates (`GATES.tsv`, `gates/`)

Each ran as `make <gate>`, one at a time, with the eleven credential variables removed
from the environment. Each log's first line is `make exit: <n>`.

- **`gates/worktree/`**: `registry_gen_check`, `ext_call_inventory`,
  `ext_call_inventory_selftest`, `profile_definition`, `ext_ambient_inventory`,
  `ext_hook_scope`. Five are green. `ext_hook_scope` exits 2 on `test_dummy`, with a log
  identical to P3's. The content differences from P3's logs are two: `ext_call_inventory`
  records one more non-member port call, `register.ail:331 ctx.ports.file_read` (ADR A6),
  and `profile_definition` counts 564 tracked `.ail` files, where it counted 563.
- **`gates/wired/`**: `registry_gen_check`, `ext_call_inventory`, `ext_ambient_inventory`,
  `ext_hook_scope`, `profile_definition`.
  - `ext_hook_scope`: `skills  config-caps  pass`. The hook walk, which reports and does
    not gate, gives `skills` `HOOK-PORT-MEDIATED`, with `skills.ail` reachable from the
    handler. The gate exits 2 on `test_dummy` alone: pass 19 of 20.
  - `ext_ambient_inventory`: PASS, 20 of 20 extensions and 19 of 19 std modules.
    `skills` is `AMBIENT` on five registration-time sources (`std/env.getEnvOr`,
    `std/fs.isDir`, `isFile`, `listDir`, `readFileResult`), with one `ExtPorts` field
    call and nothing rejected.
  - `profile_definition`: exit 0; 80 of 100 pairs stand, where 75 of 95 did.

**The other eleven gates of ADR A7 were not run for P4**: `check_core`, `driver_only`,
`profile_coverage`, `conformance`, `test_coverage`, `new_contract_policy`,
`registry_multiplicity`, `declared_vs_performed`, `driver_plus_no_ops`,
`driver_plus_compose`, `driver_plus_herdr`.

## The discovery probe (`probe/`)

Inline tests cannot reach `register_with_config`: it reads the disk. The probe runs it
against 26 fixture workdirs with `AILANG_FS_SANDBOX` set to each, one process per
workdir, then drives the handler with a port that reads the real file.

| File | What it is |
|---|---|
| `build_fixtures.sh` | Builds the 26 workdirs: six controls, four for R1, fifteen for V1–V8 (V1 two ways, V3 three ways, V4 its four cases, one with two violations), and one directory that cannot be listed |
| `skills_shell_probe.ail.txt` | The driver. Stored as `.ail.txt` so that scans of tracked `.ail` files do not pick it up. It imports the package and `src/core/ext/ctx_defaults`, so it runs from the root of the wired clone |
| `run_probe.sh` | Runs the driver once per case |
| `discovery_probe.out` | The output: 32 runs, of which 31 exit 0 and one, the directory that cannot be listed, exits 1. Identical on four runs, the last at `3213cd42` |

What it shows:

- **Every rule refuses through the real `std/fs`.** R1 for a root that is a file, a
  symlink out of the workdir, an absolute-target symlink and a dangling symlink; V1 for
  a directory with no `SKILL.md` and for one with `skill.md`; V2; V3 for a file with no
  read permission, a `SKILL.md` that is a directory and one that is a symlink out; V4's
  four cases; V5; V6; V7; V8. The two-violation fixture names both. In each, `config`
  has no skill, the valid skill beside the broken one is not listed, and a call for it
  returns the refusal.
- **The controls start.** No `.motoko`, no root and an empty root give the D12 text and
  no `enum`. The valid set of seven lists in name order with every scalar style and a
  malformed optional field. A skill reached by a relative symlink inside the workdir
  loads. The five real skills from `.claude/skills` load, and `dagr-producer` loads at a
  limit of 24,309 and not at 24,308, as P1 measured.
- **`listDir` returns names in name order** in each of the 23 runs whose root is a directory (`in_name_order=true`).
- **A directory that cannot be listed ends the process**: `Error: execution failed:
  listDir: openat .motoko/skills/sealed: permission denied`, exit 1. ADR D1 states this
  limit; nothing in the extension can turn it into a refusal.
- **Without the sandbox** the flag is false, the root resolves against the process
  directory (so the fixture's skills are not found), and with a workdir other than `.`
  the call returns D7's error.

The fixture path is replaced by `<fixtures>` in the output. `std/fs` puts the absolute
path of the workdir into some read errors (V3 for a directory, and for a symlink out),
and those reach the refusal message.

## Mutation check (`mutants.tsv`, `mutate_p4.py`)

`mutate_p4.py` applies one source change at a time to `register.ail` in the wired clone,
runs a detector, and restores the file. The worktree's file is never changed.

45 mutants, 45 killed, on the `register.ail` of `2365f91e` (unchanged at `3213cd42`).
None is killed by failing to compile.

- 31 change the config, the catalogue or the handler. The detector is `ailang test
  register.ail`, and the third column names the failing tests.
- 14 change discovery or registration. The detector is the probe: the mutant is killed
  when the probe's output differs from `discovery_probe.out`. Lock-drift warnings, which
  any edit to the package causes, are filtered out of both sides first.

No file here holds a credential; nothing in P4 called a model or a network service.
