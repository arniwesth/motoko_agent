# 037 P3 — evidence index

Evidence for PLAN-001 §5 P3, the pure core of `packages/motoko-ext-skills/`. Everything
here was produced on 2026-10-04 in `/workspaces/motoko_agent-skills` on
`feat/skills-extension`, with AILANG v0.47.2. The package code these files describe is
at commit `928009c4`; the commits after it add evidence only.

## Test and check logs (`logs/`)

Each log starts with the directory and command and ends with the exit status.

| File | Command | Result |
|---|---|---|
| `test_skills.log` | `ailang test --no-color skills.ail`, in the package directory | 62 of 62, exit 0 |
| `test_a6b.log` | `ailang test --no-color a6b_test.ail`, in the package directory | 11 of 11, exit 0 |
| `test_dir.log` | `ailang test --no-color .`, in the package directory | 73 of 73, exit 0 |
| `test_from_root.log` | `ailang test --no-color packages/motoko-ext-skills`, at the worktree root | 73 of 73, exit 0 |
| `test_package_mode.log` | `ailang test --no-color --package .` | 11 of 11, exit 0. Package mode discovers `*_test.ail` only, so it runs `a6b_test.ail` and not the 62 inline tests of `skills.ail` |
| `check_skills.log`, `check_a6b.log` | `AILANG_RELAX_MODULES=1 ailang check <file>` | exit 0 |
| `check_strict_cold.log` | `ailang check skills.ail` with the package's `.ailang` cache removed | exit 1, `MOD010`. The Makefile checks package modules with `AILANG_RELAX_MODULES=1` for the same reason |

## Gates that walk the tree (`GATES.tsv`, `gates/`)

The package is not wired into the root manifest, the lock, the registry or any profile,
so no gate installs it. Six light gates read `packages/` or the tracked `.ail` files, and
were run at `bbad5b59` to see whether the new directory moves them. Each ran as
`make <gate>`, one at a time, with the eleven credential variables P0 lists removed from
the environment. `GATES.tsv` compares each log with P2's log of the same gate
(`../p2/gates/`).

No gate is newly red. Five are green as in the baseline. `ext_hook_scope` is red as in the
baseline, on `test_dummy`, with a log identical to P2's. The one content difference in
any log is `profile_definition`'s count of tracked `.ail` files, 563 where it was 561.

**The other eleven gates of ADR A7 were not run for P3**: `check_core`, `driver_only`,
`profile_coverage`, `conformance`, `test_coverage`, `new_contract_policy`,
`registry_multiplicity`, `declared_vs_performed`, `driver_plus_no_ops`,
`driver_plus_compose`, `driver_plus_herdr`.

## Two copies of core code, and what holds each equal

A package cannot import `src/core`, so the package carries two copies. Each is pinned by
a test to values the core's own function printed.

| Copy | Core original | Evidence |
|---|---|---|
| `envelope_message` (`skills.ail`) | `result_env_model_content` (`src/core/phase_vocab.ail`), which encodes `result_to_model_json` (`src/core/tool_contract.ail`) | `envelope_parity_core.ail.txt` and `envelope_parity_pkg.ail.txt` are the two drivers; `envelope_parity.out` is their output: four envelopes, byte-identical between the two sides |
| `working_limit` (`a6b_test.ail`) | `working_budget_for_ext` (`src/core/context_limit.ail`) | `working_limit_core.ail.txt` is the driver; `working_limit_core.out` is the core's value for the twelve windows the test pins |

The drivers are stored as `.ail.txt` so that scans of tracked `.ail` files do not pick
them up. The core-side drivers ran from the worktree root with `AILANG_RELAX_MODULES=1
ailang run --caps IO --entry main <file>`; the package-side driver ran from the package
directory, where it was a temporary file.

## The five real skills (`real_skills.out`)

`real_skills.ail.txt` reads the five `SKILL.md` files under `.claude/skills` and passes
them to `scan` and `load_skill`. All five are accepted; the index is 2,302 chars of the
16,000 budget; `dagr-producer` is 24,305 chars of message and 6,077 tokens, the figure
P1 measured, and is the only one refused at a declared limit of 20,000.

## Mutation check (`mutants.tsv`, `mutate.py`)

`mutate.py` applies one source change at a time, runs the package's tests, and restores
the file. Run from the worktree root as `python3 mutate.py <output.tsv>`, one mutant at a
time.

55 mutants, 55 killed, at `928009c4`. Fifty-three change `skills.ail` and two change the
`working_limit` copy in `a6b_test.ail`. 54 are killed by a failing test, named in the
third column. One, `m06` (a limit of 0 no longer loads), is killed differently: the
mutant divides by zero and `ailang test` aborts with `panic: division by zero` and exit
2, with no test summary.

No file here holds a credential; nothing in P3 called a model or a network service.
