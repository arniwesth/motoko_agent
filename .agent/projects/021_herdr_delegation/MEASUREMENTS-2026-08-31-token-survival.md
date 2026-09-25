# Measurements: does a `mot-owner` token survive a herdr server restart?

Date: 2026-08-31. herdr 0.8.2 (`/usr/local/bin/herdr`). Closes the one prerequisite the handoff's
build-order item 1 reserved: [`DESIGN-f5-orphan-ownership.md`](DESIGN-f5-orphan-ownership.md) §2.1
measured token persistence **within a running server** and left survival across a **server restart**
unmeasured, while §5.4's startup sweep is the rung that depends on it.

**Answer: no. Tokens do not survive a server restart — and neither do the delegates they tag.**

## Method, and why it needed an isolated server

`herdr server stop` from inside a live session kills every pane process, this Motoko included, so
the operator's server could not be the subject. herdr keys a **named** session to its own socket and
its own state directory (`~/.config/herdr/sessions/<name>/`), so the probe ran headless and isolated:

    herdr --session dagrprobe server            # headless, own socket + own session.json
    herdr --session dagrprobe workspace create --cwd /workspaces/motoko_agent

**A trap worth recording.** The first attempt isolated only the socket (`HERDR_SOCKET_PATH=…`) and
left the config directory at its default. That second server **restored the operator's live layout
from the shared `~/.config/herdr/session.json` and rewrote it**. It was stopped immediately and the
operator's session was unharmed (verified: distinct checksums, the live pane's `agent_session` row
intact), but socket isolation is not state isolation. Use `--session <name>`.

## Results

| # | step | observation |
|---|---|---|
| 1 | `pane report-metadata w1:p1 --source motoko-delegate --token mot-owner=w1:p9:1756000000000` | exit 0 |
| 2 | `pane get w1:p1` | `"tokens":{"mot-owner":"w1:p9:1756000000000"}` — **on the pane object, not under `metadata`** |
| 3 | `pane run w1:p1 "sleep 600"`, then `pane process-info --pane w1:p1` | foreground `sleep 600`, pid recorded |
| 4 | `server stop` | `ps -o stat` on that pid: **`Z`, `[sleep] <defunct>`** — the pane process was killed, immediately, not orphaned |
| 5 | restart, `pane get w1:p1` | pane restored, same `pane_id`, **new `terminal_id`**, **no `tokens` key** |
| 6 | `pane process-info --pane w1:p1` after restart | a fresh `/bin/bash`; the previous process is not reattached |

**The absence is structural, not a timing artifact.** The persisted `session.json` (`"version": 3`)
carries per pane exactly `cwd`, `label` and `agent_session`. There is no `tokens` key in the schema,
so there is nothing that could have been written and lost.

One field correction for the design: §2.1 records the read-back path as `.metadata.tokens`. In
0.8.2's CLI JSON it is `.result.pane.tokens`. The producer/sweep parser must look there.

## What this does and does not cost the sweep

**The sweep is same-server-lifetime.** It cannot recognise a delegate tagged before a server
restart, and — per the F-5 fence — it must not fall back to a name-based rule to try (P2-6).

**That costs approximately nothing, because step 4 is the other half of the answer.** A server
restart does not *hide* orphans from the sweep; it *ends* them. The delegate the sweep would have
found is dead before the next server comes up, and the pane that returns is an empty shell with a
new `terminal_id`. The population the sweep exists for — F-5 §1's O1 and the SIGKILL backstop,
where **Motoko** dies and the **herdr server keeps running** — is exactly the population whose
tokens §2.1 already measured as persistent.

So the sweep still meets its design where its design applies, and the honest statement of its reach
is: *stale-owner detection holds for as long as the herdr server that spawned the delegate is
running; a server restart resets both the tags and the delegates.*

## Not measured

- **A delegate that ignores `SIGHUP` or detaches.** Step 4 used `sleep`, which does not trap it. A
  `nohup`/`setsid` process would survive the restart and, having lost its pane association, would be
  invisible to `agent list` and unreachable by any token-gated sweep. Delegates are started as pane
  foreground processes (`agent start`, `pane run`), so this is not the expected shape — but the
  measurement is `sleep`, not a real `claude`.
- **Token TTL (`--ttl-ms`) interaction with a restart.** Moot while no token survives at all.
- **Whether a client detach/reattach (as opposed to a server restart) clears tokens.** The server
  holds the state and never stopped, so no reason to expect loss; untested.

## Addendum, same session: enumerate the sweep with `pane list`, not `agent list`

Design §2.1 chose `agent list` because it carries tokens and needs one call. Both are true, and
`pane list` is strictly better on the same terms — measured against the same isolated server:

| call | a tokened pane that is **not** an agent row |
|---|---|
| `agent list` | **invisible** — `{"agents":[]}` |
| `pane list` | visible, with `"tokens":{"mot-owner":"w1:p9:1756000000000"}` |

That gap is exactly the orphan shape worth catching: a motoko delegate whose inner run released its
agent authority (or never got far enough to report one) leaves a live pane with no agent row. One
call either way, tokens either way, so the sweep enumerates panes. This refines §5.4's mechanism; it
does not touch its rule — the gate is still the `mot-owner` token and nothing else.

Also measured, and the reason the key filter is not optional: **herdr writes its own tokens.** The
sidebar pane carried `herdr-sidebar-explorer` and `herdr-sidebar-git`. "Has tokens" is not a
Motoko signal; only `mot-owner` is.
