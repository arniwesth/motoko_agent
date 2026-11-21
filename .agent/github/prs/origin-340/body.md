---
repo: arniwesth/motoko_agent
pr: 340
branch: chore/devcontainer-ovis-port
ticket: null
title: "feat(agent_sandbox): bake Ovis into the confined image; drop Herdr Studio's port"
---

## Summary

Makes Ovis, the browser and phone client for herdr, part of the `agent_confined` image, so a
rebuild no longer loses it. It is installed at build time, published on the host's loopback beside
Herdr Studio, and given its access token from the repo-root `.env`. Without a token, Ovis stays on
the container's loopback. Ovis on a non-loopback address with no token lets anyone who reaches it
type into the herdr panes.

The first commit put the port on `.devcontainer/docker-compose.yml`. That file belongs to the
operator profile, and the session that asked for this runs in `agent_confined`. The last commit
reverts it.

## Changes

- **`agent_sandbox/Dockerfile`:** a new "Ovis (install)" block after herdr-projects. It fetches the
  installer from the `v0.5.9` tag rather than from ovis.sh, which serves the latest version, and checks
  it against a pinned SHA-256. It then installs with `OVIS_REF=v0.5.9`, and the installer verifies the
  release's signed manifest and the binaries' hashes. Auto-update stays off, which is Ovis's default.
- **`agent_sandbox/docker-compose.yml`:**
  - `ports:` gains `127.0.0.1:${OVIS_HOST_PORT:-17317}:7317`.
  - `environment:` gains `OVIS_TOKEN: ${OVIS_TOKEN:-}`.
  - `command:` writes `HOST=0.0.0.0` and `PORT=7317` to `~/.config/ovis/env` only when `OVIS_TOKEN`
    is set, then runs `sleep infinity` as before. Without a token it removes those lines. HOST and PORT
    are not set under `environment:`, because there they would apply to every process in the
    container.
- **`.devcontainer/docker-compose.yml`:** back to `main` (the first commit, reverted).
- **Herdr Studio's port removed, as no longer in use:** the `127.0.0.1:8787` entry in `ports:`, the
  `make studio` target that started the bridge and printed its host URL, and its row in
  `docs/running.md`. The `herdr-gui` binary stays in the image, reachable only from inside the
  container; the Dockerfile comment now says so.

Ovis starts with the herdr server through its plugin's `[[startup]]` entry, so nothing else
launches it.

## Governing docs

None directly. This follows the patterns `.devcontainer/agent_sandbox/` already documents:
build-time plugin installs (herdr-dagr, herdr-projects), pinned third-party code (ADR-001 D7, cited
in the Dockerfile), and Herdr Studio's "host loopback port plus a token inside" for reaching a
container service from the host.

## Predicted outcome

After adding `OVIS_TOKEN=<token>` to the repo-root `.env` and running `agent.sh build`:

- `curl -sI http://127.0.0.1:17317/` on the host returns `200`.
- `tailscale serve --bg --https=7317 http://127.0.0.1:17317` serves Ovis to a phone on the tailnet.
  This works with no `socat` relay and does not depend on the container's IP.
- The browser asks for the token once.

Without `OVIS_TOKEN`, the published port does not answer: Ovis listens on the container's loopback
only.

What it does not keep: a paired device or account sign-in. Those live in `~/.config/ovis` and are
gone after a rebuild, like every other login in this image. The token alone is enough to get in.

## Test evidence

Run in the current `agent_confined` container. Docker is not available inside it, so the image was
not built.

- Both files parse. `ports` reads `["127.0.0.1:${OVIS_HOST_PORT:-17317}:7317"]`, and `OVIS_TOKEN` is
  in `environment`.
- The Makefile parses (`make -pn` exits 0), and `make studio` now reports no such target. No other
  file in the tree names `HERDR_STUDIO_PORT` or `make studio`.
- The `command:` script, with `$$` turned into `$` and run against a scratch HOME:
  - with a token, it writes `HOST=0.0.0.0` and `PORT=7317` to a file with mode 600;
  - a second run does not duplicate them;
  - without a token, the file is left empty.
- Why the token is required, measured on Ovis 0.5.9 bound to `0.0.0.0` in an isolated state dir:
  - `OVIS_TOKEN` in the process environment: `/api/workspaces` with no credentials returns **401**.
  - No token: the same request gets past authentication (**404**, the API's own answer), and Ovis
    logs "anyone who can reach this address can type into your terminals".
- The installer at `v0.5.9` on GitHub is byte-identical to the one `https://ovis.sh/install.sh` served
  today (SHA-256 `a2a289a8…911e`).
- The route this PR bakes in worked by hand: Ovis on `0.0.0.0` with a token, a `socat` relay on the
  Mac's `127.0.0.1:17317`, and `tailscale serve` pointed at the relay. It loaded on an iPhone.
- **Not run:** `agent.sh build`, and therefore the installer in a fresh image. The step's own checks
  (`herdr plugin list` names `devswha.ovis`, and both binaries exist) fail the build if the install
  goes wrong.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
