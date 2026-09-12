# Pending patch: `agent_confined` runs an init as PID 1

Date: 2026-09-12. Adds `init: true` to the `agent` service. Docker runs its init (tini) as PID 1,
and `command: sleep infinity` becomes its child. That init reaps orphaned processes, which nothing
in the container does today.

## Why it is not applied

The same reason as [`PATCH-agent-confined-mem-limit.md`](PATCH-agent-confined-mem-limit.md),
[`PATCH-agent-confined-allowed-kinds.md`](PATCH-agent-confined-allowed-kinds.md),
[`PATCH-agent-confined-reap-on-exit.md`](PATCH-agent-confined-reap-on-exit.md) and
[`PATCH-agent-confined-dagr-pane.md`](PATCH-agent-confined-dagr-pane.md).
`/workspaces/motoko_agent/.devcontainer` is mounted **read-only** inside the agent container.
Writing to it from here fails with `Read-only file system`, which means the mount is working.

Apply from the operator's container or the host:

```
git apply .agent/projects/021_herdr_delegation/agent-confined-init.patch
```

`git apply --check` passes as of this date both with and without the 24g memory patch
([`agent-confined-mem-limit.patch`](agent-confined-mem-limit.patch)) applied. The two touch lines
about 70 apart, so they apply in either order. Both checks were run from inside the agent container,
which is allowed because checking only reads.

The change takes effect only when the container is **recreated**, not when it is restarted.

## What it changes

One line, `init: true`, directly after `command: sleep infinity`, plus a comment saying why it is
there. Nothing else moves.

## Why

Measured 2026-09-12 inside the container:

- **PID 1 reaps nothing.** PID 1 is `sleep infinity`. A process whose parent chain is gone by the
  time it dies is re-parented to PID 1 and never reaped, so it stays `<defunct>` for the container's
  lifetime. There were **200** such zombies (`ps -eo ppid,stat | awk '$1==1 && $2 ~ /^Z/'`): old
  `ailang`, `bun`, `make`, `claude`, `node`, `git` and `herdr-sidebar` processes from ordinary use.
- **Zombies use up PID slots.** Every zombie counts against `pids_limit: ${AGENT_PIDS_LIMIT:-4096}`.
  A long-lived container that runs many short agent processes creeps toward that ceiling, and
  hitting it is another silent failure: forks start failing.
- **Zombies blocked a session from resuming.** A zombie still answers `kill(pid, 0)`.
  - When the pane of a running Motoko was closed, its TUI died without running its exit hooks and
    became a zombie, still holding its session lease.
  - Every restart on that session id was then refused as "already held by pid 120166", although
    that process could never write again.
  - The host side is fixed in `src/tui/src/session-lease.ts`: a `Z`/`X` owner now counts as gone.
  - This patch removes the condition that created the zombie in the first place.

## What it does not do

It does not stop a Motoko dying when its pane closes, and it does not run the Motoko's exit hooks
(no journal `exit` entry, no lease release). That death still looks like a crash, and the
stale-lease takeover recovers it. What changes is that the dead process is reaped, so it no longer
looks alive to anything that checks.

## Verifying it took

After recreating the container, from inside it:

```
tr '\0' ' ' </proc/1/cmdline          # an init (docker-init / tini), not "sleep infinity"
ps -eo ppid,stat | awk '$1==1 && $2 ~ /^Z/' | wc -l    # 0, and it stays near 0 over a working day
```

To exercise it, start a Motoko in a pane, close the pane, and check that no `<defunct>` `bun` or
`ailang` process is left behind with parent 1.
