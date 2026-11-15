---
repo: arniwesth/motoko_agent
pr: 328
branch: fix/pin-ailang-0.60.4
ticket: null
title: "chore: pin AILANG v0.60.4"
---

## Summary

Pins AILANG v0.60.4 in place of v0.54.14. v0.60.4 is the latest release, from 2026-11-13. After
#324 and #326, every file that checks on v0.54.14 also checks on v0.60.4, except the 27 that pin
031 ADR-001's limitations. This PR moves the pin and fixes `make verify_classify_check`, the only
gate that v0.60.4 breaks outside those pins. It broke in two places. `make declared_vs_performed`
stays red. It is listed in `DST_KNOWN_RED`, and #327 holds the re-measurement it needs.

## Changes

- chore: pin AILANG v0.60.4
- fix(verify_classify): the trivial contract is `0 == 0`, which v0.60 reads
- fix(core): derive Eq for the results classify's probes compare
- chore(install): say how to clear the old build's compile caches
- chore(dst): list declared_vs_performed as known red on AILANG v0.60.4
- chore(github): issue #327 record — declared_vs_performed on AILANG v0.60.4

12 files changed.

**The pin.** `scripts/install-prerequisites.sh` needs both `AILANG_REF` and `AILANG_MIN_VERSION`,
because the installer skips the build when the installed version is at least the minimum. CI's
`dst-setup` action builds the floor in `ailang.toml`. In `ailang.lock` only `ailang_version`,
`generator` and `generated_at` change, and `ailang lock --check` passes on both compilers. A plain
`ailang lock` does not rewrite a lock that is current, so I deleted the lock and generated it
again. On v0.54.14 the new lock adds one warning, `VER001`.

**The trivial contract.** `new_contract_policy.py` checks a `-- contracts:` excuse by adding
`ensures { true }` to the function and asking whether `ailang verify` rejects it. v0.60.4 does not
encode the body for that clause. It returns `SKIPPED ... ensures is the literal true (nothing to
verify) [missing_postcondition]`. The policy reads SKIPPED as a rejection, so every excuse would
stand. Its own test catches this: `test_b` in `test_new_contract_policy.py` fails on v0.60.4.
`survey.py` adds the same clause, so every function reads as outside the fragment. Both tools now
add `ensures { 0 == 0 }`.

| `survey.py` over `src/core`, 2,197 functions | VERIFIED | SKIPPED | ERROR |
|---|---|---|---|
| v0.54.14, `ensures { true }` (main) | 447 | 1,618 | 131 |
| v0.54.14, `ensures { 0 == 0 }` | 448 | 1,617 | 131 |
| v0.60.4, `ensures { true }` | 0 | 2,197 | 0 |
| v0.60.4, `ensures { 0 == 0 }` | 488 | 1,614 | 92 |

On v0.54.14 the two probes disagree on 2 of the 2,197 functions. `dst_discovery.census` goes from
ERROR to VERIFIED, and `phase_vocab.seal_compacted_payload` goes from SKIPPED to ERROR.

**The probes' `==`.** The target's second step, `classify.py --check`, also failed on v0.60.4. The
first step's failure had stopped the recipe before it ran. Its DETERMINE probe states
`ensures { result == <body> }`, and v0.60.4 type-checks a contract's `==` (`TC_CONTRACT_001`, as
in #326). Four result types had no `Eq`:

| First contract to fail | Result type | Fix |
|---|---|---|
| `dst_generator.pinned_canary_v3` | `[CanaryRow]` | `deriving (Eq)` on `CanaryRow` |
| `process_limits.loopback_limits` | `ProcessLimits` | `deriving (Eq)`. Both its fields already derive it |
| `tool_fault.arguments_undecodable_fault` | `ToolFault` (`types.ail`) | `deriving (Eq)`. Both its fields already derive it |
| `tool_runtime.normalize_range` | `{ start: int, end: int }` | An anonymous record cannot derive, so it becomes `LineRange`, a type local to the module |

`classify.py` stops at the first module that does not compile. So I generated all 16 probe modules
and checked each on v0.60.4, which shows every failure at once. With these four changes, all 16
compile. The register hashes the contract and the body, not the return type, so
`contracts.register` does not change.

**The known-red entry.** `declared_vs_performed` was already red on main: on v0.54.14 it reports
126 passed, 11 failed. On v0.60.4 its probe does not compile, because its two vacuity controls
perform through the record-field door that v0.60.4 closes. The Makefile comment and #327 list the
rows. The entry waives nothing: `make dst` still exits 2, and its summary calls the target known
red, not new. No CI workflow runs this target.

**The cache warning.** After an upgrade, the old build's `.ailang/` compile caches stay in the
tree. `tools/ext_ambient_inventory/derive.py --json` read them alongside the new build's caches and
exited 1. That failed `profile_definition`, `driver_only`, `driver_plus_compose` and
`driver_plus_no_ops`. With the caches removed, all four pass. On the upgrade path only, the
installer now prints the command that removes them. It deletes nothing itself.

Not changed:

- **`-- contracts:` excuses already in the tree.** The policy reads only the diff, so it does not
  re-check them. On v0.60.4, 8 of the 136 excused functions in top-level `src/core` files verify
  under the trivial contract, so their excuses no longer hold. 5 of those 8 are new on v0.60.4:
  `dst_program.ceiling_ms_defect`, `dst_profile.one_per_kind`,
  `process_limits.needs_process_primitive`, `process_limits.process_deadline_expires` and
  `process_limits.projected_timeout_ms`. The other 3 already verified on v0.54.14. The survey
  does not cover the 29 excuses in subdirectories.
- **Go.** v0.60.4's `go.mod` asks for Go 1.26.11, and v0.54.14's asks for 1.26.9. The installer
  and CI set up Go 1.22.5 and rely on `GOTOOLCHAIN=auto` to fetch the newer toolchain, as they
  already do for v0.54.14.
- **`LDR006`** (#325) is unchanged on v0.60.4.
- **Open PRs on the same files.** #234 also rewrites the `ailang.lock` header, from v0.52.5 to
  v0.54.18, and already conflicts with main. #21, #35, #37 and #56 are drafts from May and June
  that pin v0.18 and v0.19.

## Governing docs

- #323, AILANG's changes up to 1.0. #324 and #326 made the tree ready for v0.60.4.
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`, whose
  gate stays red until #327 is done.

## Predicted outcome

With v0.60.4 installed and the caches cleared, `make dst` fails only on `declared_vs_performed`,
and its summary lists that as known red. CI passes, building v0.60.4 from `ailang.toml`.
`make verify_classify_check` passes on both compilers. To check: CI on this PR, and the runs below.

## Test evidence

v0.60.4 is the release binary (linux arm64) with its own `std/` from tag v0.60.4. The runs are
from a worktree under `/workspaces`, because AILANG relaxes `MOD010` under `/tmp`. Caches were
cleared between compilers. All of these runs are at this branch's head.

| | v0.54.14 | v0.60.4 |
|---|---|---|
| `ailang check`, 502 tracked `.ail` files outside `.agent/` | 397 pass | 370 pass. The other 27 are the pins: 26 in `scripts/dst/fixtures/adr001_boundary/` and `scripts/dst/declared_vs_performed.ail` |
| `ailang test`, the 110 files with `tests [` | same result as merged main for every file | same result as merged main for every file |
| `make verify_classify_check` | pass | pass (failed before this PR) |
| `make check_core`, `verify_core`, `verify_mutations`, `test_core` | pass | pass |
| `make new_contract_policy BASE=origin/main` | pass | pass |
| `ailang lock --check` | pass, with `VER001` | pass |

`make dst` on v0.60.4 took 1,210 s and exits 2. Its summary: "FAILED (1): declared_vs_performed
known-red ... no new failures".

Earlier runs at the first commit, `b4aeb035`:

- On v0.54.14, `make dst` before the pin fails only on `declared_vs_performed`, as main does.
- The CI-only targets `verify_skills_tests`, `verify_skills_refusal`, `smoke_no_delegated_storm`,
  `verify_profile_dir_agreement` and `tui_context_limit` pass on both compilers.

Not run: `make dst` on v0.54.14 after the `Eq` commit, a live provider session, the TUI suite
(`cd src/tui && bun run test`), and the installer's upgrade path end to end. The installer change
is checked with `bash -n` only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
