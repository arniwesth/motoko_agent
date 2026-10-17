---
repo: arniwesth/motoko_agent
pr: 269
branch: fix/herdr-dagr-plugin-root
ticket: null
title: "fix(sandbox): find herdr-dagr via plugin_root under herdr 0.9"
---

## Summary

With #268 merged, `./agent.sh build` gets past parsing and then fails in the image build at the herdr-dagr step: `ls: cannot access '/home/motoko/.config/herdr/plugins/github/herdr-dagr-*/bin/dagr'`, then `ln` gets an empty target. herdr 0.9 (unpinned in #267) installs plugins under `plugins/github-installations/<id>-<hash>/<n>/checkout/` instead of `plugins/github/<id>-*/`. The Dockerfile now takes the symlink target from `herdr plugin list --json` (`plugin_root`) instead of a glob. `scripts/dagr-pane.sh` checked the same old path to decide whether the plugin is installed, so it would have refused under 0.9. It now asks `herdr plugin list` instead.

## Changes

- fix(sandbox): find herdr-dagr via plugin_root under herdr 0.9

2 files changed.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` — D7 as amended in #267 (herdr resolved at build time). This PR repairs that implementation; the decision itself is unchanged.

## Predicted outcome

`./agent.sh build` completes on the host. In the container, `dagr` is on PATH and points into herdr-dagr's 0.9 install directory, and `scripts/dagr-pane.sh` recognises the installed plugin. The Makefile's `DAGR_BIN` keeps working because it tries `command -v dagr` (the symlink) before its own old-path glob.

## Test evidence

- Plugin layout: herdr 0.9.5 + herdr-dagr v0.3.1 in a scratch `ubuntu:24.04` container. `plugin_root` is `~/.config/herdr/plugins/github-installations/herdr-dagr-bd0ed2fe5515/2837-0/checkout`, and the new Dockerfile step prints `dagr 0.3.1 (contract v3; reads v1/v2)`.
- Image build: `docker compose … build agent` on the host (arm64) with herdr 0.9.5 and the same build args `agent.sh build` passes, exit 0. The herdr-dagr step printed `dagr 0.3.1`, herdr-projects v1.2.1 installed, and `motoko_agent_confined/dev:1.0` was built.
- `bash -n scripts/dagr-pane.sh` passes.
- **Not run:** `agent.sh build`'s `compose up` (the container was not started), `agent.sh check`, and `dagr-pane.sh` in a live herdr session.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
