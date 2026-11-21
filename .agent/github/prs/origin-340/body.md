---
repo: arniwesth/motoko_agent
pr: 340
branch: chore/devcontainer-ovis-port
ticket: null
title: "feat(agent_sandbox): Ovis baked in, served by `agent.sh ovis`; remove Herdr Studio"
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
- **`agent_sandbox/agent.sh`:** a new `ovis` command for the host half, which was typed by hand
  before.
  - `agent.sh ovis` (or `ovis on`) refuses without `OVIS_TOKEN` in `.env`, printing a freshly
    generated one to paste. It stops a leftover `socat` relay on the host port, brings the stack up,
    and refuses if the running container was created without the token; recreating it would end
    every herdr session. It starts Ovis if no herdr session has, waits for `/api/health` on
    `127.0.0.1:17317`, and points `tailscale serve --https=7317` at that port, replacing any stale
    target. Finally it prints the tailnet URL.
  - `agent.sh ovis status` reports both halves and changes nothing. `agent.sh ovis off` stops serving
    to the tailnet.
  - The Tailscale CLI is found on PATH or inside `/Applications/Tailscale.app`. Written for bash 3.2
    and BSD userland like the rest of the script: no `jq`, `mapfile` or GNU-only flags.
- **Docs:** the command in `agent.sh help`, the sandbox README (with a short "Ovis, from a phone"
  section), and `docs/running.md`.
- **`.devcontainer/docker-compose.yml`:** back to `main` (the first commit, reverted).
- **Herdr Studio removed entirely, as no longer in use.** Ovis replaces it as the browser client.
  This removes the `herdr-gui` install block in the Dockerfile (its pinned release, checksums and the
  `xz-utils` it installed only for itself), the `127.0.0.1:8787` entry in `ports:`, the `make studio`
  target, and its row in `docs/running.md`. Historical records under `.agent/projects/` that mention it
  are left as they are.

Ovis starts with the herdr server through its plugin's `[[startup]]` entry, so nothing else
launches it.

## Governing docs

None directly. This follows the patterns `.devcontainer/agent_sandbox/` already documents:
build-time plugin installs (herdr-dagr, herdr-projects), pinned third-party code (ADR-001 D7, cited
in the Dockerfile), and Herdr Studio's "host loopback port plus a token inside" for reaching a
container service from the host.

## Predicted outcome

After adding `OVIS_TOKEN=<token>` to the repo-root `.env` and running `agent.sh build`, one
command on the host, `agent.sh ovis`, prints `https://<mac>.<tailnet>.ts.net:7317`. A phone on the
tailnet opens that address and the browser asks for the token once. No `socat` relay is involved, and
nothing depends on the container's IP. `agent.sh ovis status` then shows both halves answering.

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
  file outside `.agent/` mentions `herdr-gui`, `herdr-studio`, `HERDR_STUDIO` or port 8787. The step
  that installed Studio ran as root, and the next step sets `USER root` itself, so no other step's
  user changes.
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
- `agent.sh`: `bash -n` passes, and `agent.sh help` lists the new command. Its helpers, extracted and
  run in this container:
  - `.env` parsing reads quoted values, a leading `export`, an empty value and an absent key correctly;
  - the host port is taken from the environment, then `.env`, then defaults to 17317;
  - the reachability check answers for the live Ovis and fails for a closed port;
  - the URL is pulled out of `tailscale serve status`-shaped output.
  shellcheck is not installed here. `agent.sh ovis` itself refuses to run inside a container, as the
  whole script does, so its Docker and Tailscale steps have not been run.
- **Not run:** `agent.sh build`, and therefore the installer in a fresh image. The step's own checks
  (`herdr plugin list` names `devswha.ovis`, and both binaries exist) fail the build if the install
  goes wrong.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
