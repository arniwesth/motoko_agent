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

```
Warning: CACHE_WRITE_FAILED module=src/core/session stage=encoding
 path=src/core/.ailang/cache/compile/modules/src__core__session/coretypeinfo.gob: ARTIFACT_TOO_LARGE:
 ...: artifact exceeds blob byte limit; using fresh compilation
```

## Changes

- chore: AILANG v0.47.2 -> v0.52.5

26 files changed.

- `scripts/install-prerequisites.sh`: `AILANG_REF` and `AILANG_MIN_VERSION`.
- `ailang.toml`: the floor, `>=0.52.5`. CI builds the toolchain from this line
  (`.github/actions/dst-setup`), and `make CI=1 sync_packages` fails unless it equals `AILANG_REF`.
- `ailang.lock` and the 23 `packages/*/ailang.lock`: regenerated with v0.52.5. Besides the
  stamps, the root lock takes two content hashes that had already drifted on `main`
  (`motoko_ext_herdr`, `motoko_ext_test_dummy`), and the package locks take the current
  `motoko_ext_abi` hash. No dependency version moved.

No source file changes.

## Governing docs

No project document governs a toolchain bump. Where the repository already records this defect:

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
- **Headroom is about 2.3x, not unlimited.** At 29.3 MB against a 64 MiB limit, the same warning
  returns if session's type info more than doubles.

Two upstream changes between the two versions can break a caller, and were looked for:

- An imported name that the module also defines is now compile error MOD015 (v0.52.0). Not
  present in what `make check_core` compiles, which passes.
- A `run` flag placed after the file path is now an error (v0.51.0). No such call was found by
  grep in `Makefile`, `scripts/`, `tools/`, `src/tui/src`, `packages/` or `.github/`; the TUI
  passes its flags before `src/core/supervisor.ail` and the program's arguments after `--`.

## Test evidence

All on this branch in one worktree, with v0.52.5 built from the `v0.52.5` tag into a scratch
directory (the container's shared `~/.local/bin/ailang` is still v0.47.2) and its own `std`
beside it.

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
- **`make dst`** (the full sweep) on v0.52.5: started, and still running when this pull request
  was opened. Its result will be added here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
