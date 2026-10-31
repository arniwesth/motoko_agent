# ADR-002: Per-call process timeouts and what a timeout tells the model

Date: 2026-10-30
Status: **Proposed. Not accepted; §7 lists the rulings it needs.**
Grounded at: `origin/main` `a393314b` (#284 merged). AILANG v0.54.14, with the upstream API also
read at v0.55.0.

Requested by the operator after #284 merged and tool calls were still seen to stop at 30 s.

Relates to:

- [ADR-001](ADR-001-delegated-process-timeouts.md), whose D6 deferred this design and whose D8
  this ADR keeps.
- [BashExec timeout-knob issue](../../issues/bashexec-timeout-knobs-are-dead.md).
- [Effect disclosure for tool faults](../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md),
  whose D2 mapping and ruling 6 (the withdrawn wrapper) bind this ADR.

## TL;DR

**Decision.** A `BashExec` or `RunTests` call may ask for its own timeout, and the operator's
ceiling always wins. A short default stays in force for every call that does not ask, so a hung
command does not get the long budget because one other command needed it. (D1, D2)

**The primitive has to come from AILANG.** `std/process.exec` has no per-call timeout, and the
existing workarounds are withdrawn or cannot capture output. This ADR asks upstream for one and
ships nothing until a pin carries it. (D3)

**Nothing changes by default.** With no new setting, the ceiling equals the default, so a model
cannot extend anything until the operator opts in. (D2)

**A timeout stays `effects: unknown`, always.** The result gains the limit that applied and, once
upstream #1878 lands, partial output. (D4)

**`setsid` escape stays disclosed, not solved,** but is pinned by a probe so a change is noticed.
(D5)

**One risk must be measured first.** The tool's command leads its own process group, so killing
the runtime may not kill it. A longer budget would make that worse. (D6)

## 1. The problem

Three gaps remain after #284:

1. **One limit for a whole session.** `--process-timeout`, set from `MOTOKO_PROCESS_TIMEOUT` or
   `tools.process_timeout`, is the only limit. It defaults to 30 s. To let one build run for five
   minutes, the operator must also let every hung command block for five minutes.
2. **The model has no control and no information.** `timeout_secs` was removed because nothing read
   it. A live timeout tells the model the elapsed time, not the limit or how to get more.
3. **Partial knowledge after a timeout.** Output captured before the kill is dropped
   (sunholo-data/ailang#1878, open), and a descendant that calls `setsid` leaves the process group
   and survives the kill.

## 2. What the code does today

| Fact | Where |
|---|---|
| The wall is one field, read on every `exec`: `context.WithTimeout(..., pc.Timeout)`, default 30 s | AILANG `internal/effects/process.go`, `process_context.go` |
| `exec(cmd, args)` takes no timeout. No commit changes it between v0.54.14 and v0.55.0 | AILANG `std/process.ail` |
| `spawnProcess` handles offer stdin and `cancelProcess` only: no stdout, no exit status | AILANG `std/process.ail` |
| `BashExec` and `RunTests` share `run_process_result` and `parse_exec_from_args` | `src/core/tool_runtime.ail:244-247`, `:175` |
| Internal helpers (path guard, `rg`, `mv`, `chmod`) also call `exec`, so they share the same wall | `src/core/tool_runtime.ail:494`, `:632`, `:853-889` |
| `ToolInvocation.timeout_ms` is filled from `MOTOKO_TOOL_TIMEOUT_MS` on every dispatch and enforced only in scripted/DST execution | `src/core/tool_phase.ail:500`, `src/core/ports.ail:1884` |
| Herdr sizes its check wait from `MOTOKO_PROCESS_TIMEOUT` | `packages/motoko-ext-herdr/register.ail:166` |
| The command leads its own process group; `WaitDelay` is 5 s | AILANG `internal/effects/process.go` |

## 3. Invariants

- **I1.** A model can never run a command past the operator's ceiling.
- **I2.** A timeout is never reported as `effects: none` (034 D2).
- **I3.** The limit a live call ran under and the limit a scripted run enforces come from the same
  value, so DST exercises what production does.
- **I4.** A profile that sets nothing new behaves as it does today.
- **I5.** Internal helpers do not inherit a long budget because a model asked for one.

## 4. Decisions

### D1. The argument

`BashExec` and `RunTests` regain an optional integer `timeout_secs`, this time parsed into
`ProcessExecReq` and described in the schema, including the ceiling that applies. The name is the
one models already sent. Other tools and internal helpers do not get it (I5).

The catalog test that forbids `timeout_secs` today
(`test_bash_schema_does_not_advertise_ignored_timeout_secs`) is replaced, not deleted: the schema
must advertise the argument only when the argument reaches the process.

### D2. The limits

| Setting | Meaning | When unset |
|---|---|---|
| `tools.process_timeout` (exists) | Limit for a call that does not ask | 30 s |
| `tools.process_timeout_max` (new) | Highest limit a call may ask for | Equals `process_timeout` |

`MOTOKO_PROCESS_TIMEOUT_MAX` beats the profile, as `MOTOKO_PROCESS_TIMEOUT` already does.

| Request | Result |
|---|---|
| No argument | The default |
| Positive, at or under the ceiling | The request |
| Above the ceiling | **The ceiling, and the result says so** |
| Zero, negative or not an integer | Argument error before launch, `effects: none` |

A request above the ceiling is clamped rather than refused, because refusing costs a model turn
and the command may well finish in time. The applied limit is always in the result, so the model
is not left believing it got what it asked for, which was the original `timeout_secs` defect. A
lowered limit is honoured: a request may shorten as well as extend.

A ceiling below the default is a configuration error, raised at startup.

### D3. The primitive comes from AILANG

Ask upstream for a per-call timeout on `exec`, for example
`execWith(cmd, args, { timeout_ms })`, sharing the existing group kill and `WaitDelay`.

Motoko validates the limit against its own ceiling (I1). If upstream also enforces a ceiling, that
is additional and not a replacement. Filing is outward-facing, so it waits for ruling R1.

No part of D1 or D2 ships before a pin carries the primitive, because a schema that advertises an
argument nothing enforces is the defect #284 removed. D4's limit field and D5's probe can ship
earlier.

### D4. What a timeout result says

Every process timeout keeps `effects: unknown` (I2), and adds:

- `timeout_ms`: the limit applied, and `requested_timeout_ms` when clamped.
- `max_timeout_ms`: the ceiling, so the model can tell whether retrying with more time can help.
- Partial stdout and stderr, once #1878 is available on a pin. Until then the absence stays
  explicit, and an empty string must not read as "the command printed nothing".
- The existing instruction not to assume the command had no effect, extended to: check state
  before retrying, because a retry may repeat what already happened.

Today a live timeout arrives as `Err(Timeout)` and carries only the elapsed time, while the scripted
path has `ToolDeadlineExceeded` with a `timeout_ms`. Both must report the same fields (I3).

`ToolInvocation.timeout_ms` carries the applied limit. `MOTOKO_TOOL_TIMEOUT_MS` stays, because the
DST generator and discovery recorders depend on it and on its once-per-dispatch read, but it remains
a scripted-run input and gains no live meaning. How it combines with the applied limit in a scripted
run is settled in the plan, subject to I3.

### D5. Detached descendants stay a disclosed limit

Motoko will not build process containment. A `setsid` or daemonized descendant survives the kill,
and if it holds the pipes the call returns at the limit plus `WaitDelay`.

- Extend `make verify_native_process_tree` with a `setsid` case asserting today's behaviour, so an
  upstream change is seen instead of assumed.
- Ask upstream, as a separate request, for a stronger containment primitive such as Linux cgroups
  or a subreaper. This ADR does not depend on it.
- State the limit in the tool documentation for operators. It does not go in the model-facing
  result, where `effects: unknown` already covers it.

### D6. Measure cancellation before raising budgets

**Not yet tested.** Because the command leads its own process group, killing the runtime may leave
the command running. ESC does exactly that when the run is neither suspended nor parked:
`rp.kill()` in `src/tui/src/runtime-process.ts`, the likely case during a running tool call. With a
30 s wall the leak is short. With a 10 minute wall it is not.

Before D1 ships, a probe must run a long command, press ESC on that path, and record whether the
command dies. If it survives, cancellation on that path is a blocker for D1, and is
fixed first or the ceiling is held low.

## 5. Alternatives considered

- **Raise the session limit and stop.** Available today and fine as relief, but every hung command
  gets the full budget. Gap 1 is the point of this ADR.
- **GNU `timeout` wrapper.** Withdrawn by the operator at 034 ruling 6. It changes the observation
  from `Err(Timeout)` to an exit code of 124. Not reopened.
- **`spawnProcess` plus `cancelProcess` in Motoko.** The handle exposes no stdout or exit status, so
  output would need redirecting through temporary files and polling. This builds a second process
  executor, the shape ADR-001 removed.
- **A background-job tool** (start, poll, stop). A real feature that would serve long jobs better,
  but larger, with its own lifecycle and effect questions. It does not remove the need for a sane
  limit on foreground calls.
- **Refuse a request above the ceiling.** Simpler to specify and rejected in D2, subject to R3.
- **Per-tool limits in the profile.** More settings without solving the case of one slow command
  among many fast ones.

## 6. Sequence and acceptance

1. D5's probe and the D6 cancellation probe. These can run on the current pin.
2. File the upstream asks after R1.
3. D4's `timeout_ms` and `max_timeout_ms`, using the session limit as the applied value.
4. After a pin carries the primitive: D1, D2, and the replacement catalog test.
5. After a pin carries #1878: partial output.

Accepted when:

- With no new setting, a request for more than the default still stops at the default, and the
  result says so (I1, I4).
- With a ceiling set, a call requesting more than the default outlives the default, while a call
  in the same session that requests nothing stops at the default.
- A request above the ceiling stops at the ceiling, and invalid requests never launch.
- Internal helpers keep the default during a session with a long-running request (I5).
- A DST scenario and a live probe agree on the applied limit (I3).
- Each timeout path still reports `effects: unknown` (I2).
- The D6 probe has a recorded result.
- `tools.delegated_timeout_ms` is not given a role here. Its removal stays with the issue above.

## 7. Rulings needed

| # | Question | Recommendation |
|---|---|---|
| R1 | File the per-call timeout and containment asks upstream? | File both. Only the first is a dependency |
| R2 | What ceiling should the shipped `default` profile set? | `300s`, matching `demo_dst`; the default stays 30 s |
| R3 | Clamp or refuse a request above the ceiling? | Clamp, and report it |
| R4 | If upstream declines or is slow, what then? | Keep the session setting as the only relief and revisit. Do not fork or build a second executor without a new ruling |

## 8. Consequences

- The model gets a way to ask for time, and with it a way to hold a session for up to the ceiling.
  The ceiling is the operator's bound on that, so its setting matters.
- Motoko takes a dependency on an upstream API that does not exist yet, so the main benefit has no
  date.
- A longer wall lengthens a blocked turn. Whether the TUI stays usable during that wait is part of
  what the D6 probe should note.
