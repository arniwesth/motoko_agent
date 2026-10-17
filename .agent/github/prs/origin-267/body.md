---
repo: arniwesth/motoko_agent
pr: 267
branch: arniwesth/sandbox-herdr-latest
ticket: null
title: "sandbox herdr latest"
---

## Summary

Herdr is no longer pinned in the agent sandbox: every `agent.sh build` takes the latest release and verifies it against the sha256 from `https://herdr.dev/latest.json`. This is needed to install `eliasstravik/herdr-projects`, which requires Herdr 0.9.3+ (the image had 0.8.2), and the plugin is now installed at build time, pinned to v1.2.1. Also fixes `agent.sh upgrade`, whose agent-browser lookup read a field the npm package document does not have.

## Changes

- feat(sandbox): build herdr at latest, add herdr-projects plugin

6 files changed.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` — D7 (versions pinned in the tree), amended here; D11 (profile edits need a host shell).

## Predicted outcome

After a host-side `agent.sh build`, `herdr --version` in the container reports the latest release (0.9.5 at the time of writing), `herdr plugin list` shows `herdr-projects`, and `herdr plugin action invoke open --plugin herdr-projects` opens the board. `versions.env` carries only `AGENT_BROWSER_VERSION`. Trade-off accepted: `build` now needs `herdr.dev`, and herdr is not reproducible across builds.

## Test evidence

- `bash -n agent.sh` passes.
- `resolve_herdr`, run in isolation against the live manifest: returns 0.9.5 with the linux-x86_64 sha256; `HERDR_VERSION` alone is refused; `HERDR_VERSION` + `HERDR_SHA256` together are used as given.
- `resolve_versions` + `write_versions_file`, run in isolation: now return `AGENT_BROWSER_VERSION=0.39.1` (before this PR the lookup failed with `'version'`) and rewrite `versions.env` without the herdr lines.
- **Not run:** the Docker image build and `agent.sh check` (no Docker in this environment). The `herdr-projects` install step and the fallback to the compose empty-default args are untested until someone builds on the host.
