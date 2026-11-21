---
repo: arniwesth/motoko_agent
pr: 341
branch: fix/run-agent-registry-cache
ticket: null
title: "fix(run-agent): restore lost AILANG registry deps before launch"
---

## Summary

`make motoko` failed with only `The AILANG runtime exited with code 1 before it reported done or an
error.` The cause, visible as a warning in the session log, was package resolution:
`sunholo/logging@0.4.0` is a registry dependency read from `~/.ailang/cache/registry`, and a fresh
container (or a wiped home) has no `~/.ailang` at all. `scripts/run-agent.sh` now notices a
registry package from `ailang.lock` missing from that cache and runs `ailang lock --check`, which
fetches it and writes nothing to the repo.

## Changes

- fix(run-agent): restore lost AILANG registry deps before launch

1 file changed.

- The check runs only when a package is missing. With the cache warm it costs one `bun -e` that reads
  `ailang.lock` (~6 ms), and it does not call `ailang lock --check`. That command also fails on a
  merely stale lock, which would otherwise warn on every launch while a path package is being
  edited.
- A failed fetch (offline, registry down) prints the `ailang` output as a warning and the launch
  continues, so the runtime's own error still reaches the TUI.
- `AILANG_CACHE_DIR` was tested and does not move the registry cache, so the path
  `~/.ailang/cache/registry/<vendor>/<name>/<version>` is fixed.

## Governing docs

None. This is a launcher fix with no design record.

## Predicted outcome

After a container rebuild, `make motoko` prints `AILANG registry cache is missing:
sunholo/logging@0.4.0 - fetching.` once and starts normally instead of failing with exit code 1.
Later launches print nothing extra.

## Test evidence

- `bash -n scripts/run-agent.sh`: syntax OK.
- A copy of the script with the final `exec bun` replaced by an echo, run with
  `~/.ailang/cache/registry/sunholo/logging/0.4.0` moved aside: printed the "missing … fetching"
  line, restored `0.4.0`, and reached the exec line.
- The same copy with the cache warm: no output besides the exec line, and `bash -x` shows
  `missing=` and an early return.
- The original failure was fixed by hand with the same `ailang lock --check`. After that,
  `ailang check src/core/supervisor.ail` reported `No errors found`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
