---
repo: arniwesth/motoko_agent
pr: 296
branch: arniwesth/041-single-construction-gate
ticket: null
title: "test(core): run the single-construction check in check_core (041 gate)"
---

## Summary

This PR is based on W4's branch `arniwesth/041-w4-resolver` and must land after W4; its diff will shrink to its own changes once W4 merges, so merge it only once PR #295 is in.

W4 added `src/core/process_limits.ail`, and ADR-002 D7 says `resolve_process_limit` is the only constructor of both of its results. The compiler cannot hold that rule because records are structural. W4 built a scanner for it, but no gate ran the scanner, and W5 is where these types start being consumed. This PR makes it a gate.

- **Moved:** `evidence/W4/check_single_construction.py` is now `scripts/verify_single_construction.py`, because evidence directories hold records, not gates.
- **Wired in:** there is a new `make verify_single_construction` target, and `check_core` depends on it.
- **One behaviour change to the check, which the brief did not ask for:** a module moved off disk now exits 2. The brief says to keep behaviour exactly, and the docstring already said a missing module exits 2, but it did not. `git ls-files -c` still lists a tracked file that has left the disk, and the scan skips any path that is not a file. So at `ce9f39b9`, moving the module away printed `574 .ail files, 0 breaches` and exited 0. It is a separate commit, `9d03d6c9`, and it only makes the check stricter. Without it, row `g3` would have passed the gate.

**Please check two things in review:**

1. **A stale path stays in the module.** `src/core/process_limits.ail:18` still names the old checker path, because the module has to stay byte-identical so that W4's table stands. It should be fixed the next time the module changes, for example in W5.
2. **`make` cannot report exit 1.** The brief asks for `make verify_single_construction` to exit 1 on a breach. `make` itself exits 2 for any failed recipe. The script does exit 1, and `make` names it as `Error 1`. The harness checks both.

## Changes

- refactor(core): move the single-construction check to scripts/ (041 gate)
- fix(core): exit 2 when the tracked module is gone from disk (041 gate)
- test(core): run the single-construction check in check_core (041 gate)
- test(core): the mutation harness for the single-construction gate (041 gate)
- test(core): evidence that a breach fails check_core (041 gate)

`evidence/W4/mutate.sh` now runs the check from its new path. `evidence/W4/mutants.tsv` does not name the path, so it is unchanged.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`: D7
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

No production behaviour changes and no matrix row moves. `make check_core` gets about 1.2 seconds slower, and from now on it fails if any `.ail` file git can see constructs either result outside the resolver, or if the module is missing. W5 should expect this gate to catch any new function parameter or field named like a result label: the scan treats that as a breach, and the checker's docstring says to rename it.

## Test evidence

Gates ran at `f7f66c4b`. The module is unchanged: `git diff --stat 858af7cb..HEAD -- src/core/process_limits.ail` is empty.

| Command | Exit | Result |
|---|---|---|
| `env -u AILANG_FS_SANDBOX make verify_single_construction` | 0 | `check_single_construction: 575 .ail files, 0 breaches` |
| `env -u AILANG_FS_SANDBOX make check_core` | 0 | `check_single_construction: 575 .ail files, 0 breaches`, then `src/core/ type-check: 61 passed, 0 failed` |
| `env -u AILANG_FS_SANDBOX make test` | 0 | `All core runtime module tests passed!` |
| `make verify_classify_check` | 0 | `verify_classify: 76 contracts, register agrees (73 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |

**Is it a real gate?** `evidence/gate-single-construction/`, run at `58e68797`:

| Row | Break | `ailang check` | Script | `make check_core` | Verdict |
|---|---|---|---|---|---|
| `g1` | another module writes the literal | 0 | 1 | 2, `[Makefile:2702: verify_single_construction] Error 1` | killed |
| `g2` | another module updates `budget`, which only the record-update rule sees | 0 | 1 | 2, `[Makefile:2702: verify_single_construction] Error 1` | killed |
| `g3` | module moved off disk, still in the index | not run | 2 | 2, `[Makefile:2702: verify_single_construction] Error 2` | killed |
| `g3.index` | module moved off disk and out of the index | not run | 2 | 2, `[Makefile:2702: verify_single_construction] Error 2` | killed |
| `g4` | none (the clean control) | not run | 0 | 0, `src/core/ type-check: 61 passed, 0 failed` | passed |

In every red row the type-check step never ran, so this target is what failed `check_core`. `g3.index` is one row more than the four the brief named. It covers the other way a module can go missing.

**W4's evidence still reproduces.** `evidence/W4/mutate.sh` was rerun from the new path at `f7f66c4b`: 92 killed, 1 passed, 1 n/a. The `verdict` and `observed` columns are identical to the committed table for all 94 rows.

**Not run:** `cd src/tui && bun run test`, `make dst` and `make eval_matrix`. They are not in this task's gate set, and this PR does not touch `src/tui`.

**Known limit, not fixed:** the file list is split on whitespace, so a `.ail` path containing a space would not be scanned. No such path exists today. The brief asked to keep the check's behaviour, so this one is left as it is.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
