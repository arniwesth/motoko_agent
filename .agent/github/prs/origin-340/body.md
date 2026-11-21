---
repo: arniwesth/motoko_agent
pr: 340
branch: chore/devcontainer-ovis-port
ticket: null
title: "chore(devcontainer): publish Ovis's port to the host's localhost"
---

## Summary

Publishes Ovis's port (7317 in the container) as `127.0.0.1:17317` on the host. Without it, the
host reaches Ovis only at the container's own IP. The sandboxed Tailscale Mac app cannot open that
address, so `tailscale serve` pointed there sends an empty response, which Safari on the iPhone
saved as an empty `document.txt`. With the port published, `tailscale serve --bg --https=7317
http://127.0.0.1:17317` reaches Ovis without a `socat` relay or the container's IP, which can
change on a rebuild.

## Changes

- chore(devcontainer): publish Ovis's port to the host's localhost

1 file changed: `.devcontainer/docker-compose.yml`, a `ports:` entry with a comment explaining why
it is there.

## Governing docs

None. This is a devcontainer convenience, not covered by a design record.

## Predicted outcome

After the container is rebuilt, `curl -sI http://127.0.0.1:17317/` on the host returns
`HTTP/1.1 200 OK`, and the iPhone reaches Ovis through `tailscale serve` with nothing else running
on the Mac.

What this does not do: Ovis and its settings (`~/.config/ovis/env`: `HOST=0.0.0.0`, `PORT=7317`,
`OVIS_TOKEN`) live in the container's home directory, so a rebuild still loses them. Ovis then has
to be installed and configured again before the published port has anything to reach.

The host side is bound to 127.0.0.1, so the port is not offered to the LAN. Port 17317 rather than
7317 avoids a clash with an Ovis running on the host itself.

## Test evidence

- The compose file parses: `ports` reads `[ "127.0.0.1:17317:7317" ]`.
- Not tested end to end. Docker is not available inside the container, and the change takes effect
  only on a rebuild.
- The same route worked by hand before this change: a `socat` relay on the Mac from
  `127.0.0.1:17317` to the container's `7317`, with `tailscale serve` pointed at the relay. Ovis
  loaded on the iPhone that way.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
