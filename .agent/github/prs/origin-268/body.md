---
repo: arniwesth/motoko_agent
pr: 268
branch: fix/agent-sh-bash32-heredoc
ticket: null
title: "fix(sandbox): agent.sh parses under macOS bash 3.2"
---

## Summary

Since #267, `./agent.sh build` on a macOS host fails before running anything: `agent.sh: line 509: unexpected EOF while looking for matching `"'`. `resolve_herdr` ran a Python heredoc inside `"$(...)"`, and macOS `/bin/bash` 3.2 mis-parses quotes in such a heredoc. The apostrophe in a Python comment (`urllib's default`) opened a quote that never closed. This PR moves the heredoc into its own function, `fetch_herdr_manifest`, and calls that from `resolve_herdr`. Behaviour is unchanged.

## Changes

- fix(sandbox): agent.sh parses under macOS bash 3.2

1 file changed.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` — D7 as amended in #267 (herdr resolved at build time). This change repairs that implementation; the decision itself is unchanged.

## Predicted outcome

`./agent.sh build` (and every other `agent.sh` command) parses again on a macOS host under `/bin/bash` 3.2, and `build` resolves the latest herdr as #267 intended. #267's `bash -n` check was run under bash 5, which does not have this bug. That is why it passed there.

## Test evidence

- Before: `/bin/bash -n agent.sh` (GNU bash 3.2.57, arm64-apple-darwin25) fails with the reported error. Removing only the apostrophe makes it parse, which confirms the cause.
- After: `/bin/bash -n agent.sh` passes under bash 3.2.57.
- `resolve_herdr` + `fetch_herdr_manifest`, run in isolation under bash 3.2 against the live manifest: return `0.9.5` and the linux-aarch64 sha256.
- **Not run:** a full `./agent.sh build` (Docker image build).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
