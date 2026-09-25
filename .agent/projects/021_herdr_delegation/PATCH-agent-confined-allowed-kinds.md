# Pending patch: `agent_confined` permits `motoko` as a delegate kind

Date: 2026-09-01. Unblocks the live integration exercise
([`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md)), which was refused at
the kind gate on its first attempt and produced zero panes, zero handles and zero run files.

## Why it is not applied

Same reason as [`PATCH-agent-confined-reap-on-exit.md`](PATCH-agent-confined-reap-on-exit.md), and
this file follows that one's shape deliberately. `/workspaces/motoko_agent/.devcontainer` is
mounted **read-only** inside the agent container (`virtiofs (ro,relatime)`) so that the agent
cannot rewrite its own confinement. Editing it from in here would mean defeating that mount, which
is not a thing to do quietly — least of all for a change that widens what the agent is permitted
to spawn.

Apply it from the operator's container or the host.

## What it changes, and why it is an operator decision

The extension's built-in default is `claude` alone. This adds `motoko`, so the confined container
permits both.

The reason it is not simply the default everywhere: a `motoko` delegate is this agent spawning
another copy of itself. That is a capability an operator should grant deliberately. It is granted
*here* because a `motoko` delegate is started with `pane run` inside this same container and
inherits this compose file's confinement entire — internal-only network, egress proxy, read-only
`.devcontainer`, the bot PAT. It acquires nothing the parent did not already have.

The reason it is needed at all, rather than merely convenient: `claude` and `codex` delegates go
through `agent start`, which depends on a CLI that may be sitting on a sign-in screen. Measured
2026-09-01 — herdr matched no screen rule for such a pane and closed it
([`NOTE-005`](../028_verified_runtime_closing_the_loop/NOTE-005-third-session-compaction-blind-spot-and-ungated-examples.md)
§3). With the coding-agent CLIs unauthenticated, `motoko` is the only delegate kind that works in
this container, and a confined agent that cannot delegate cannot run its own gates either:
`make check_core` alone outlasts the 35 s `BashExec` ceiling.

What this line does **not** do: it is not the recursion bound, and that bound is already tight. A
delegate's pane is spawned with `HERDR_DELEGATE_DEPTH=1`, and `HERDR_MAX_DELEGATE_DEPTH` defaults
to `1` (`types.default_max_depth`), so **a motoko delegate cannot itself delegate**. This patch
permits one level of self-delegation, not a tree. Widening the depth is a separate, deliberate
change to a separate variable, and this one does not imply it.

## Ordering

This patch's context includes the `HERDR_REAP_ON_EXIT` block, so it applies **on top of**
`agent-confined-reap-on-exit.patch`. That one is already applied in the working tree and is still
uncommitted; if you revert it, revert this first.

## Applying it

From the **host**, or from the operator's dev container (only `agent_confined` mounts
`.devcontainer` read-only):

```sh
git apply .agent/projects/021_herdr_delegation/agent-confined-allowed-kinds.patch
```

Then recreate the container so the new environment reaches it — an env-var change needs no
rebuild, but `docker compose` only delivers it on recreate, and recreating ends every herdr session
in the container:

```sh
.devcontainer/agent_confined/agent.sh          # `compose up -d` recreates on config drift
```

## The patch, inline

`.devcontainer/agent_confined/docker-compose.yml`, in the `environment:` block, immediately after
the `HERDR_REAP_ON_EXIT: "1"` line:

```yaml
      HERDR_ALLOWED_KINDS: "claude,motoko"
```

(the patch file carries the full comment block; only the effective line is reproduced here).

## How to tell it worked

Inside the container, `env | grep HERDR_ALLOWED_KINDS` prints `claude,motoko`. The test that
matters is one level further in, because the variable has to cross the TUI→AILANG boundary:
`buildChildEnv` forwards the whole `HERDR_` prefix (`src/tui/src/runtime-process.ts`), a rule
widened on 2026-08-23 after a named allowlist silently dropped exactly this variable. So the real
check is that a `Delegate` call with `kind: "motoko"` returns a handle instead of

> `motoko` is a kind herdr knows, but the operator has not permitted it here. Permitted: claude.

Note that the variable is read when the **TUI process** starts, not per tool call. An `export` in
a shell where Motoko is already running changes nothing — which is how the first run of the
integration exercise came to be refused five times in a row.

## Reverting

Remove the name from the list and recreate. Nothing in the extension caches it, and the refusal
path is the documented behaviour, not a failure: `types.kind_allowed` refuses an unpermitted kind
and says so rather than falling back to a permitted one.
