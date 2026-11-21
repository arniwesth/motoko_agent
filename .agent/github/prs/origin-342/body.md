---
repo: arniwesth/motoko_agent
pr: 342
branch: fix/ovis-relay-sidecar
ticket: null
title: "fix(agent_sandbox): publish Ovis through an ovis-relay sidecar"
---

## Summary

#340 broke Ovis on the phone. It published Ovis with `ports:` on the `agent` service. That service's only
network is `internal: true`, and Docker publishes no port for such a container, so nothing listened on the
Mac's `127.0.0.1:17317`. `tailscale serve` forwarded to that empty port and answered 502. `agent.sh ovis`
had also stopped the hand-started `socat` relay that made the phone work before. This PR adds a small
`ovis-relay` service that owns the published port and forwards it to `agent:7317`. The agent stays on the
internal network only.

## Changes

- **`agent_sandbox/docker-compose.yml`:**
  - New `ovis-relay` service: `alpine/socat` pinned by digest (the multi-arch index of `1.8.1.1`, built
    2026-06-20). It sits on `confined_internal` and the routed `confined_egress`, publishes
    `127.0.0.1:${OVIS_HOST_PORT:-17317}` and forwards to `agent:7317` by name. It runs as `65534:65534`,
    read-only, with `cap_drop: ALL`, `no-new-privileges`, 64 MB and 256 pids. It has no `depends_on`.
  - The agent's `ports:` entry is removed, since it never took effect. The comment that said
    `internal: true` "does NOT block this" is replaced by what was measured.
- **`agent_sandbox/agent.sh`:** `agent.sh ovis` runs `compose up -d --no-deps ovis-relay` after
  `ensure_up`.
  - `ensure_up` returns early on a running stack, so without this a stack started before this PR would
    never get the relay.
  - `--no-deps` keeps compose from recreating the agent, which would end every herdr session.
  - If Ovis does not answer, the message now also points to the relay's log.
- **`agent_sandbox/README.md`:**
  - The Ovis section describes the relay.
  - The egress-boundary section says `ovis-relay` is a second dual-homed container but not a second exit:
    its only action is to connect to `agent:7317`.

## Governing docs

None directly. This follows what `.devcontainer/agent_sandbox/` already does: the egress-boundary design in
its README and `docker-compose.yml`, and third-party images pinned by digest, as `egress-proxy` is.

## Predicted outcome

On the host, after this merges:

```sh
.devcontainer/agent_sandbox/agent.sh ovis
```

- It creates `ovis-relay` without touching the running agent, so herdr sessions survive.
- `lsof -nP -iTCP:17317 -sTCP:LISTEN` on the Mac shows a listener.
- `curl http://127.0.0.1:17317/api/health` returns 200.
- `curl https://<mac>.<tailnet>.ts.net:7317/api/health` returns 200 instead of 502.
- The phone loads Ovis at that URL again.

A stack started from scratch (`agent.sh stop && agent.sh`) brings the relay up with everything else.

## Test evidence

Run in the `agent_confined` container. Docker is not available inside it, so the stack was not brought up.

- **The bug, measured on the host (2026-11-21):**
  - `curl https://<host>.<tailnet>.ts.net:7317/api/health` returned `502` with an empty body.
  - `curl http://127.0.0.1:17317/api/health` failed: `Couldn't connect to server`.
  - `lsof -nP -iTCP:17317 -sTCP:LISTEN` printed nothing.
  - `tailscale serve status` showed `:7317 → proxy http://127.0.0.1:17317`.
  - The host browser reached Ovis only at the container's IP, `http://<container IP>:7317/`.
- **The relay's target, from inside the agent:**
  - `getent hosts agent` gives the agent's address on `confined_internal`.
  - `curl http://<that address>:7317/api/health` returns `200`, so Ovis answers on the container's network
    address.
  - `~/.config/ovis/env` holds `HOST=0.0.0.0` and `PORT=7317`, and Ovis's environment has `OVIS_TOKEN`.
- **The image pin, checked against the registry:**
  - `registry-1.docker.io/v2/alpine/socat/manifests/1.8.1.1` returns `docker-content-digest: sha256:7f9a0675…c3b0`,
    which is the pinned digest, and Docker Hub lists amd64, arm, arm64, ppc64le and s390x under it.
  - The arm64 config has `Entrypoint ["socat"]` and no `User`, so `command:` is socat's arguments and
    `user:` sets the uid.
- **Syntax:**
  - `bash -n agent.sh` passes.
  - The compose file parses (Bun's YAML parser). It lists the services `agent`, `ovis-relay` and
    `egress-proxy`; `agent` has no `ports` and only `confined_internal`; `ovis-relay` has both networks and
    the published port.
- **Not run:**
  - `agent.sh ovis` against the new compose file.
  - Docker publishing a port for a container on one internal and one routed network. The routed network
    supplies the gateway (the egress proxy reaches the internet that way), and Docker binds published ports
    through it, but this has not been run here.
  - `checks/r9-container.sh`: no leg reads the agent's ports or counts services.
  - `shellcheck`: not installed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
