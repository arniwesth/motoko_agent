# Pending patch: `agent_confined` sets `HERDR_REAP_ON_EXIT=1`

Date: 2026-08-31. Blocks nothing; the reaper works without it, this only turns it on for the
disposable container.

## Why it is not applied

This is the one line of F-5 D2 that a Motoko session cannot write for itself.
`/workspaces/motoko_agent/.devcontainer` is mounted **read-only** inside the agent container
(`virtiofs (ro,relatime)`), which is the protection the compose file states in its own words:
*"Every edit to this directory — including this file — is made from the operator's container or the
host, never from inside the agent's."* Applying it from here would mean defeating that mount, which
is not a thing to do quietly for a convenience default.

Apply it from the operator's container or the host.

## Applying it

From the **host**, or from the operator's dev container (only `agent_confined` mounts
`.devcontainer` read-only; `.devcontainer/docker-compose.yml` mounts the repo read-write, so the
edit works from there too):

```sh
git apply .agent/projects/021_herdr_delegation/agent-confined-reap-on-exit.patch
```

Then recreate the container so the new environment reaches it — an env-var change needs no rebuild,
but `docker compose` only delivers it on recreate, and recreating ends every herdr session in the
container:

```sh
.devcontainer/agent_confined/agent.sh          # `compose up -d` recreates on config drift
```

## The patch, inline

`.devcontainer/agent_confined/docker-compose.yml`, in the `environment:` block, immediately after
the `GH_TOKEN: ${MOTOKO_BOT_GH_TOKEN:-}` line:

```yaml
      # REAP DELEGATE PANES ON A CLEAN EXIT — this profile only, and by decision (F-5 D2,
      # .agent/projects/021_herdr_delegation/DESIGN-f5-orphan-ownership.md §6).
      #
      # A herdr pane does not die with its caller: a delegate whose Motoko exited keeps working,
      # keeps burning subscription quota, and keeps unsandboxed write access to the tree. The
      # default everywhere else is to LEAVE IT RUNNING and say so, because reaping destroys
      # in-flight work on every clean exit — including the case the answer-file gate exists to
      # honour, where the delegate finishes after Motoko quits and the next session collects the
      # answer off disk.
      #
      # That trade-off inverts here and only here. This container is disposable, nothing but the
      # agent runs in it, no operator work lives in a pane, and the quota an unattended delegate
      # burns is the dominant cost. So the safe default for a throwaway container is set for the
      # container rather than hard-coded for everyone.
      #
      # The reaper closes panes carrying THIS session's `mot-owner` token, by explicit pane id,
      # never by name or agent kind (P2-6). src/tui/src/herdr-reap.ts.
      HERDR_REAP_ON_EXIT: "1"
```

## How to tell it worked

Inside the container, `env | grep HERDR_REAP_ON_EXIT` prints `1`, and quitting Motoko with a
delegate still running closes that delegate's pane. Without the variable the pane survives the
exit, which is the documented default everywhere else.
