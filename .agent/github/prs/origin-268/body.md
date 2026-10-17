---
repo: arniwesth/motoko_agent
pr: 268
branch: fix/agent-sh-bash32-heredoc
ticket: null
title: "fix(sandbox): agent.sh build works again on macOS after the herdr 0.9 bump"
---

## Summary

#267 left `./agent.sh build` broken on a macOS host in two places, and this PR fixes both.

1. **agent.sh would not parse.** The error was `line 509: unexpected EOF while looking for matching `"'`. `resolve_herdr` ran a Python heredoc inside `"$(...)"`, and macOS `/bin/bash` 3.2 mis-parses quotes in such a heredoc. The apostrophe in a Python comment (`urllib's default`) opened a quote that never closed. The fix moves the heredoc into its own function, `fetch_herdr_manifest`. Behaviour is unchanged.
2. **The image build failed at the herdr-dagr step.** herdr 0.9 installs plugins under `plugins/github-installations/<id>-<hash>/<n>/checkout/` instead of `plugins/github/<id>-*/`. The Dockerfile's glob for `bin/dagr` matched nothing, so `ln` got an empty target. The symlink target now comes from `herdr plugin list --json` (`plugin_root`). `scripts/dagr-pane.sh` checked the same old path to decide whether the plugin is installed, so it would have refused under 0.9. It now asks `herdr plugin list` instead.

## Changes

- fix(sandbox): agent.sh parses under macOS bash 3.2
- fix(sandbox): find herdr-dagr via plugin_root under herdr 0.9

3 files changed.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` — D7 as amended in #267 (herdr resolved at build time). This PR repairs that implementation; the decision itself is unchanged.

## Predicted outcome

`./agent.sh build` parses and builds the image on a macOS host. In the container, `dagr` is on PATH and points into herdr-dagr's 0.9 install directory, and `scripts/dagr-pane.sh` recognises the installed plugin. #267's `bash -n` check ran under bash 5, which does not have the parse bug, and its image build was never run. That is why neither problem showed there.

## Test evidence

- agent.sh before the fix: `/bin/bash -n agent.sh` (GNU bash 3.2.57, arm64-apple-darwin25) fails with the reported error. Removing only the apostrophe makes it parse, which confirms the cause.
- agent.sh after the fix: `/bin/bash -n agent.sh` passes. `resolve_herdr` + `fetch_herdr_manifest`, run in isolation under bash 3.2 against the live manifest, return `0.9.5` and the linux-aarch64 sha256.
- Plugin layout: herdr 0.9.5 + herdr-dagr v0.3.1 in a scratch `ubuntu:24.04` container. `plugin_root` is `~/.config/herdr/plugins/github-installations/herdr-dagr-bd0ed2fe5515/2837-0/checkout`, and the new Dockerfile step prints `dagr 0.3.1 (contract v3; reads v1/v2)`.
- Image build: `docker compose … build agent` on the host (arm64) with herdr 0.9.5 and the same build args `agent.sh build` passes, exit 0. The herdr-dagr step printed `dagr 0.3.1`, herdr-projects v1.2.1 installed, and `motoko_agent_confined/dev:1.0` was built.
- **Not run:** `agent.sh build`'s `compose up` (the container was not started), `agent.sh check`, and `dagr-pane.sh` in a live herdr session.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
