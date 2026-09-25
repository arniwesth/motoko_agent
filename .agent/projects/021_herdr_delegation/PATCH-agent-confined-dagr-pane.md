# Pending patch: `agent_confined` opens the dagr view automatically

Date: 2026-09-03. Turns on MOT-137 (`HERDR_DAGR_PANE=1`) for the confined container. The extension
side is landed and gated (`make verify_herdr_dagr_pane`); this is the one line that makes it
visible in this repo's own container.

## Why it is not applied

Same reason as [`PATCH-agent-confined-allowed-kinds.md`](PATCH-agent-confined-allowed-kinds.md) and
[`PATCH-agent-confined-reap-on-exit.md`](PATCH-agent-confined-reap-on-exit.md), and this file
follows their shape deliberately. `/workspaces/motoko_agent/.devcontainer` is mounted **read-only**
inside the agent container so that the agent cannot rewrite its own confinement. Writing to it from
in here fails with `Errno 30: Read-only file system`, which is the mount working. Apply from the
operator's container or the host:

```
git apply .agent/projects/021_herdr_delegation/agent-confined-dagr-pane.patch
```

(`git apply --check` passes against the current file as of this date.)

## What it changes

One environment variable, `HERDR_DAGR_PANE: "1"`, next to `HERDR_REAP_ON_EXIT` and
`HERDR_ALLOWED_KINDS`. Nothing else moves.

## Why it is an operator decision rather than the package default

The extension has always **produced** `.dagr/run-<pane>-<session>.json`; producing it costs nothing
when nobody reads it, so it is gated on nothing. Opening the pane that **reads** it is a different
rung: it splits the operator's terminal from inside a tool call, while they are reading something
else. That is the same asymmetry `HERDR_SWEEP_STALE` sits on — reporting is the default, and
anything that mutates the operator's workspace waits to be asked — so `register.ail` leaves it off
and the profile that wants it turns it on.

It is turned on **here** for the reason the other two are: this container is disposable, nothing but
the agent runs in it, and there is no operator layout to protect. What it buys is the failure
measured on 2026-09-01, where a session spent twenty minutes and ~90 scratch panes looking for a
delegation view while its own run file sat unread on disk the whole time
([`MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](MEASUREMENTS-2026-09-02-run-file-truthfulness.md)).
A graph nobody can see is a graph nobody checks.

## What keeps it from becoming that same pane storm

Three things, and the gate (`scripts/verify_mot137_dagr_pane.ail`) pins all three:

1. **One pane per run, marked on disk before the attempt.** The extension carries no state between
   tool calls, so `.dagr/.pane-<pane>-<session>` (`dagr.pane_marker`) is the state. The marker goes
   down *before* the open is tried, which is `sweep_once`'s rule and for the same reason: a failed
   attempt that retries on every subsequent `Delegate` is the same runaway with a slower fuse.
2. **A delegate inherits the variable and it does not matter.** `buildChildEnv` forwards the whole
   `HERDR_` prefix, so a motoko delegate's pane carries `HERDR_DAGR_PANE=1` too — but it is spawned
   at `HERDR_DELEGATE_DEPTH=1` against a max of 1, so it never delegates, never writes a run file,
   and never reaches the opener. The recursion bound is what keeps this to one view, not this
   variable.
3. **The view is tagged `mot-owner` like a delegate**, so `HERDR_REAP_ON_EXIT=1` above closes it on
   a clean exit and the orphan sweep recognises one left behind by a session that is gone. A view
   pane that outlives its run is a picture of nothing.

## What it does not change

The run file. It is written exactly as before, on the same schedule, to the same path — the flag
only decides whether anything is pointed at it. With the line removed, `scripts/dagr-pane.sh` still
opens the view by hand, and the tool result says so.
