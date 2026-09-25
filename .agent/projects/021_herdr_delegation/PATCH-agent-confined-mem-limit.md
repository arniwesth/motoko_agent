# Pending patch: `agent_confined`'s memory ceiling defaults to 24g

Date: 2026-09-09. Raises `AGENT_MEM_LIMIT`'s default from `8g` to `24g` after 8g was measured
killing a live session. Blocks nothing that a `.env` line could not already fix; this moves the
default so the next machine does not have to discover it.

## Why it is not applied

The same reason as [`PATCH-agent-confined-allowed-kinds.md`](PATCH-agent-confined-allowed-kinds.md),
[`PATCH-agent-confined-reap-on-exit.md`](PATCH-agent-confined-reap-on-exit.md) and
[`PATCH-agent-confined-dagr-pane.md`](PATCH-agent-confined-dagr-pane.md), and this file follows
their shape deliberately. `/workspaces/motoko_agent/.devcontainer` is mounted **read-only** inside
the agent container, which is the protection the compose file states in its own words: *"Every edit
to this directory — including this file — is made from the operator's container or the host, never
from inside the agent's."* Writing to it from here fails with `Read-only file system`, which is the
mount working.

Apply from the operator's container or the host:

```
git apply .agent/projects/021_herdr_delegation/agent-confined-mem-limit.patch
```

(`git apply --check` passes against the current file as of this date, verified from inside the
agent container — checking is a read.)

## What it changes

Two effective lines, `mem_limit` and `memswap_limit`, from `${AGENT_MEM_LIMIT:-8g}` to
`${AGENT_MEM_LIMIT:-24g}`, plus the comment block that says what the new default assumes. Nothing
else moves. `AGENT_MEM_LIMIT` in the repo-root `.env` still overrides, and always did — the patch
changes only what happens when nobody sets it.

## Why 8g was wrong

Measured 2026-09-08, and it is the reason this exists rather than a preference. An orchestrating
Motoko, its AILANG child and one delegate CLI drove the cgroup to its ceiling and the kernel killed
the session mid tool-phase with **nothing printed**: no error, no `run_summary`, no exit manifest,
and an unreaped delegate still holding its pane. `/sys/fs/cgroup/memory.events` read `max 2137700`,
`oom_kill 1`. The full evidence and the four-step triage are in
[`../../issues/a-killed-motoko-process-exits-silently.md`](../../issues/a-killed-motoko-process-exits-silently.md).

This workload is heavier than the one the 8g default was sized for: an orchestrator plus delegates
means several agent CLIs resident at once, and at rest the same container idled at 2 GiB with four
`claude` processes alive before any Motoko work started.

## The one thing to check before applying it

**A limit larger than the host is not a limit.** `mem_limit` binds only if the OrbStack VM is
bigger than it, and the container's whole host-DoS argument — *"mem_limit makes a memory leak
OOM-kill inside the CONTAINER instead of the Mac"* — depends on it binding. Set the VM to at least
32 GB (OrbStack → Settings → System → Memory) before or with this patch. On a machine that cannot,
do **not** take the default: set `AGENT_MEM_LIMIT` in the repo-root `.env` to about half of what
`free -g` reports from inside the container, which is the VM rather than the Mac.

The patch writes that caveat into the compose file's own comment, because compose cannot check it
and the failure is silent: an inert ceiling looks exactly like a generous one until the day the Mac
goes down instead of the container.

## Verifying it took

From inside the agent container after a restart:

```
cat /sys/fs/cgroup/memory.max      # 25769803776 for 24g
cat /sys/fs/cgroup/memory.events   # note oom_kill, so the next delta is readable
free -g                            # the VM: must exceed the limit for it to bind
```

## What it does not change

Not a fix for the silent exit. A raised ceiling makes the kill rarer; it does not make it visible.
`runtime-process.ts:620` still binds the child's `exit` event with a callback taking no arguments,
discarding code and signal, so a killed runtime still cannot be told from a finished one. That half
stays open in the issue.
