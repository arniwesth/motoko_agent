# Fix TUI Footer Profile Display

Base branch: `origin/arniwesth/mot-5-merge-all-eval-prs-into-one`

## Summary

This branch fixes the Motoko TUI footer showing `profile: default` even when the runtime is actually using another profile, such as `observability`.

The TUI already accepted a profile value, but startup did not pass the active profile into `AgentUI`, so the footer kept the class default until some later UI path updated it. The runtime also emits the effective `config_profile` in `session_start`, but the TUI event type and handler did not consume that field.

## Changes

- Pass the active profile into `AgentUI` when the TUI starts.
- Add `config_profile` and `config_dir` to the typed `session_start` event shape.
- Update the footer profile from `session_start.config_profile` when the runtime reports the effective loaded profile.
- Keep the footer in sync when restarting with a different profile through the profile switch flow.
- Add `mcp` to the observability profile extension order.

## User Impact

The status footer now reflects the profile Motoko is actually running with. In an observability devcontainer, where `MOTOKO_CONFIG=observability` is set by Compose, `make run` now shows `profile: observability` instead of incorrectly showing `profile: default`.

## Verification

- `bun run build`
- `node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/(runtime-process.stream-protocol|ui.wait-state)\\.test\\.ts'`

Note: the Bun/Jest launcher failed before executing tests with `Attempted to assign to readonly property`, but the same focused tests pass under Node's Jest runner.
