---
repo: arniwesth/motoko_agent
pr: 343
branch: fix/ovis-herdr-config-dir
ticket: null
title: "fix(agent_sandbox): Ovis listens on all interfaces when herdr starts it"
---

## Summary

After #342 Ovis still could not be reached from the Mac or the phone, for two reasons.

- **Ovis listened on loopback only.** The container's start command writes `HOST=0.0.0.0` to
  `~/.config/ovis/env`. herdr starts Ovis with `HERDR_PLUGIN_CONFIG_DIR` set to herdr's own config
  directory for the plugin, and Ovis reads its settings from there. That directory was empty, so Ovis
  defaulted to `127.0.0.1`, and the `ovis-relay` sidecar from #342 got an empty reply.
- **An old relay held the host port.** On the Mac, a hand-started socat still held `127.0.0.1:17317`
  ahead of the relay's port forward. `agent.sh ovis` is meant to stop that process, but it missed it.

This PR writes the settings where Ovis reads them, makes `agent.sh ovis` find and stop the old relay, and
says in the README which address to use on the host.

## Changes

- **`agent_sandbox/docker-compose.yml`:** the `agent` service's start command writes `env` into
  `$(herdr plugin config-dir devswha.ovis)`, falling back to the literal
  `~/.config/herdr/plugins/config/devswha.ovis`.
  - `herdr plugin config-dir` needs no running server, and the command runs before herdr starts.
  - Both ways Ovis starts read that file. herdr's `[[startup]]` entry passes the directory in
    `HERDR_PLUGIN_CONFIG_DIR`. An `ovis start` from a shell, which is what `agent.sh ovis` runs, asks
    `herdr plugin config-dir` and uses the directory once it holds an `env` file.
  - It still fails closed: without `OVIS_TOKEN`, the file is created with no `HOST` line, and Ovis stays on
    loopback.
- **`agent_sandbox/agent.sh`:**
  - New `ovis_stray_socat`: finds a socat by the socket it listens on (`lsof … -sTCP:LISTEN -t`, then
    `ps -o comm=`), with `pgrep -if "socat.*listen:<port>"` as the fallback on a host without lsof. The old
    check was `pgrep -f "socat TCP-LISTEN:<port>"`. It misses Homebrew's binary, which is named `socat1`,
    and any command line with options or a lowercase address before the listen address.
  - `agent.sh ovis` stops such a process, then runs `compose restart ovis-relay` so the relay's port
    forward takes the freed port. Only the relay restarts; the agent and its herdr sessions keep running.
  - `agent.sh ovis status` names a socat that holds the port.
  - If Ovis does not answer, the error message now names the right settings file and gives the restart
    that keeps herdr sessions running: `agent.sh run ovis stop && agent.sh ovis`.
- **`agent_sandbox/README.md`:** on the host, open `http://127.0.0.1:17317`. It also says why the container
  IP and port 7317 are the wrong address, and what happens to a hand-started relay.

## Governing docs

None directly. This corrects #340 and #342 in `.devcontainer/agent_sandbox/` and keeps their fail-closed
rule: Ovis leaves loopback only when `OVIS_TOKEN` is set.

## Predicted outcome

- A container created from this compose file runs herdr's Ovis on `0.0.0.0:7317` with no hand step.
  - Check: inside the container, `/proc/net/tcp` shows `00000000:1C95` listening.
  - Check: `curl http://ovis-relay:7317/api/health` returns 200.
- On a host where a socat holds 17317, `agent.sh ovis` stops it. Then `curl http://127.0.0.1:17317/api/health`
  on the host returns 200.
- Without `OVIS_TOKEN`, Ovis stays on `127.0.0.1`.

## Test evidence

Run in the `agent_confined` container, plus host commands the operator ran on the Mac and pasted back.

- **The first cause, measured inside the container (2026-11-21):**
  - Ovis 0.5.9, started by herdr, ran with `HOST=127.0.0.1` and `HERDR_PLUGIN_CONFIG_DIR` set to
    `~/.config/herdr/plugins/config/devswha.ovis`, an empty directory. `~/.config/ovis/env` held
    `HOST=0.0.0.0`.
  - `/proc/net/tcp` showed it listening on `0100007F:1C95` (127.0.0.1:7317).
  - Through the relay, `curl http://ovis-relay:7317/api/health` got an empty reply.
  - The Ovis binary explains it. It reads `env` and `.env` from `HERDR_PLUGIN_CONFIG_DIR`, and only from
    `herdr plugin config-dir` or `~/.config/ovis` when that variable is unset. The plugin's `start` takes
    `HOST` from what it read, defaulting to `127.0.0.1`, and passes it to the server it spawns.
- **The fix, applied by hand to the running container:**
  - Wrote the same `env` file to herdr's directory, then restarted Ovis with herdr's own plugin actions
    (`herdr plugin action invoke stop|start --plugin devswha.ovis`).
  - Ovis came up on `HOST=0.0.0.0` and `00000000:1C95`, with `ovis status` showing
    `config: …/devswha.ovis/env`.
  - Through the relay, `/` returned 200 `text/html` and `/api/health` returned 200. `/api/sessions` with
    no token returned 401.
- **The second cause, on the Mac (operator's output):**
  - `curl http://127.0.0.1:17317/api/health` gave `Empty reply from server`.
  - `curl http://<container IP>:7317/api/health` returned 200.
  - `lsof -nP -iTCP:17317 -sTCP:LISTEN` showed `socat1 … TCP 127.0.0.1:17317 (LISTEN)`, while
    `docker ps` showed `ovis-relay` with `127.0.0.1:17317->7317/tcp`.
  - The relay's log had no connection from the Mac.
  - After stopping that socat, `docker restart` on the relay and `agent.sh ovis`, Ovis works on the Mac
    and on the phone (operator's report).
- **The start script:** extracted from the compose file with Bun's YAML parser, `$$` unescaped, and run
  under a scratch `HOME`:
  - With a token: `…/herdr/plugins/config/devswha.ovis/env`, mode 600, holds `HOST=0.0.0.0` and
    `PORT=7317`.
  - Without a token: the same file, empty.
  - With herdr not on `PATH`: the fallback path.
- **`ovis_stray_socat`:** tested with a copy of `python3` named `socat1`, listening on a spare port, with
  the command line `socat1 … -d tcp-listen:<port>,fork …`, which the old pattern does not match. The
  function returned that PID, and returned nothing for Ovis's port 7317. This exercised the `pgrep`
  fallback, because the container has no `lsof`.
- **Syntax:** `bash -n agent.sh` passes.
- **Not run:**
  - The `lsof` path on macOS. The flags are the same `lsof -nP -iTCP:17317 -sTCP:LISTEN` the operator ran,
    plus `-t`.
  - `compose restart ovis-relay` after a socat is stopped. The operator ran `docker restart` on the relay
    by hand.
  - A container created from scratch from this compose file. Docker is not available inside the
    container.
  - `shellcheck`: not installed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
