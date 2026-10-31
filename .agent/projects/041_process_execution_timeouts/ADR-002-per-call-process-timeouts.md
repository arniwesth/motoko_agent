# ADR-002: Per-call process timeouts and what a timeout tells the model

Date: 2026-10-30
Status: **Proposed, third revision. Not accepted; §7 lists the rulings it needs.**
Grounded at: `origin/main` `a393314b` (#284 merged). AILANG v0.54.14, with the upstream API also
read at v0.55.0.

Revised after an independent review of the first revision by Codex GPT-6.1-Sol at xhigh, whose
verdict was rework. The operator chose the recommended amendment for each finding, and all seven are
now applied. The revised text has not been re-reviewed, so that verdict has not been replaced.

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
existing workarounds are withdrawn or lack what a tool result needs. This ADR asks upstream for one and
ships nothing until a pin carries it. (D3)

**Nothing changes by default.** With no new setting, the ceiling equals the default, so a model
cannot extend anything until the operator opts in. (D2)

**A timeout of a process tool stays `effects: unknown`.** Every `BashExec` and `RunTests` result
gains the limit that applied, whether or not it timed out, and a timeout gains partial output once
upstream #1878 lands. Project 034's read-only mapping is unchanged. (D4)

**One function resolves every limit.** Live and scripted runs differ only in the configuration they
give it, and each native entry point is named. (D7)

**`setsid` escape stays disclosed, not solved,** but is pinned by a probe so a change is noticed.
(D5)

**Cancellation blocks this work.** ESC kills the runtime, and the deadline lives inside the runtime,
so the command keeps running with no limit at all. This is a defect today, at any limit, and D1
does not ship until it is fixed or the operator accepts it. (D6)

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
| `live_tool_outcome` ignores `inv.timeout_ms` | `src/core/ports.ail:1865` |
| The DST generator draws that setting between 20 and 90 ms, and the PR corpus bounds a clock advance at 2,000 ms | `src/core/dst_generator.ail:875`, `scripts/dst/corpus_pr_dst.ail:352` |
| Extension effects build an invocation with `timeout_ms: 0`, and scratchpad loopback calls `run_native_batch` directly | `src/core/session.ail:1372`, `src/core/tool_envelope_dispatch.ail:47` |
| A successful process result has `fault: None` and no limit information | `src/core/tool_runtime.ail:984`, `src/core/tool_dispatch_adapter.ail:151` |

## 3. Invariants

- **I1.** While the runtime lives, a model cannot keep a managed foreground command running past the
  operator's ceiling. Detached descendants (D5) and a killed runtime (D6) are outside this bound,
  and are stated here so that it is not read as absolute.
- **I2.** A timeout of `BashExec`, `RunTests` or another tool that may change state is never reported
  as `effects: none`. `ReadFile` and `Search` keep 034 D2's `none`: `Search` overrides the disclosure
  at `src/core/tool_runtime.ail:632-638`.
- **I3.** Live and scripted runs get their limit from the same resolver and report it in the same
  fields, so DST exercises what production does. Their configuration may differ.
- **I4.** A profile that sets nothing new keeps today's limits and enforcement. The added result
  metadata (D4) is the one deliberate change to what such a session sees.
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

The same request asks for the session's configured process limit to be readable, or for the limit
to be returned with `Err(Timeout)`. `Err(Timeout)` carries only elapsed time, so Motoko cannot
otherwise know the limit of a run launched directly with `--process-timeout`, as `Makefile:2673`
does.

No part of D1, D2 or D4's limit metadata ships before a pin carries the primitive. A schema that
advertises an argument nothing enforces is the defect #284 removed, and a reported limit that may
be wrong repeats it. D5's probe can ship earlier.

### D4. What a result says

**Every `BashExec` and `RunTests` result** carries limit metadata, independent of fault disclosure,
on success, non-zero exit and harness fault alike:

- `timeout_ms`: the limit applied, and `requested_timeout_ms` when clamped.
- `max_timeout_ms`: the ceiling, so the model can tell whether asking for more time can help.

These fields are bounded and go before `cmd` and the output fields, so truncating a message cannot
remove them. An ordinary completed command still carries no `fault` (034).

**A timeout** of either tool also keeps `effects: unknown` (I2), and adds:

- Partial stdout and stderr, once #1878 is available on a pin. Until then the absence stays
  explicit, and an empty string must not read as "the command printed nothing".
- The existing instruction not to assume the command had no effect, extended to: check state
  before retrying, because a retry may repeat what already happened.

Today a live timeout arrives as `Err(Timeout)` and carries only the elapsed time, while the scripted
path has `ToolDeadlineExceeded` with a `timeout_ms`. Both must report the same fields (I3).

**Migration.** Adding fields changes the bytes of successful results, which were previously stable.
Corpora, recorded streams and any comparison over rendered results must be re-baselined in the same
change, with the diff limited to these fields.

### D5. Detached descendants stay a disclosed limit

Motoko will not build process containment. A `setsid` or daemonized descendant survives the kill,
and if it holds the pipes the call returns at the limit plus `WaitDelay`.

- Extend `make verify_native_process_tree` with a `setsid` case asserting today's behaviour, so an
  upstream change is seen instead of assumed.
- Ask upstream, as a separate request, for a stronger containment primitive such as Linux cgroups
  or a subreaper. This ADR does not depend on it.
- State the limit in the tool documentation for operators. It does not go in the model-facing
  result, where `effects: unknown` already covers it.

### D6. Cancellation is a blocker

**Measured.** AILANG creates the deadline inside the runtime, with
`context.WithTimeout(context.Background(), pc.Timeout)` (`internal/effects/process.go:159`), and the
command leads its own process group. ESC, when the run is neither suspended nor parked, reaches
`rp.kill()`, which sends SIGTERM to the runtime alone (`src/tui/src/runtime-process.ts:212`, `:1149`).

The experiment ran the real `RuntimeProcess` and the exported `interruptRuntime`, with a native
`BashExec` under `--process-timeout 1s`, and called the helper once the command had started:

```
isParked=false
interruptRuntime=kill
runtime_onExit=true
at_interrupt_plus_2400ms runtimeDead=true marker=true
```

The runtime died, and the command wrote its marker 2 s after it started, past its 1 s limit. The
review measured this first, and it was reproduced from clean markers on 2026-10-31. It exercises the
helper, not a keypress in a full provider session.

Once the runtime is dead, nothing owns the deadline, so the command runs until it exits. **This does
not scale with the limit:** a 30 s limit does not make it short, and a low ceiling does not contain
it. It is a defect on `main` today, independent of everything else in this ADR.

Before D1 ships, one of these must hold:

- a test shows that cancelling a run stops the command and its ordinary descendants, with no late
  effect; or
- the operator accepts the unbounded failure by ruling R5.

Where the fix belongs is part of R5. AILANG owns the process group and already has process-lifetime
machinery on its stream and managed paths (`runlife.Prepare`, `internal/effects/stream_process.go:67`),
while the TUI is what chooses SIGTERM.

### D7. One resolver, and how each path reaches it

A pure function turns configuration and a request into the limit, and nothing else computes one:

```
ProcessLimits = { default_ms, ceiling_ms }
resolve_process_limit(limits, requested) -> { applied_ms, requested_ms, clamped } | invalid
```

D2's request table is this function. `ToolInvocation.timeout_ms` carries `applied_ms`. Enforcement
stays per world: the scripted path applies it to scripted durations, and the live path passes it to
the D3 primitive.

**Scripted configuration.** `MOTOKO_TOOL_TIMEOUT_MS` stays a scripted-only input and gains no live
meaning. In a scripted world its value supplies both `default_ms` and `ceiling_ms`, so a call with
no request gets exactly the value it gets today. Its once-per-dispatch read is kept, because the
discovery recorders count it. A value of 0 keeps its meaning of no deadline, in scripted worlds only.
This leaves the 20–90 ms draw, its salts and the 2,000 ms corpus bound unchanged for existing
programs, which is why the production default is not fed into DST.

**Migrations this names:**

- Generator: teaching it to emit `timeout_secs` is a new draw, which changes generated programs. It
  needs a generator version bump and a corpus refresh, in its own change.
- Replay: live invocations start recording a non-zero `timeout_ms`. A plan must measure whether
  strict replay and resume accept journals recorded with 0, before this ships.
- Rendered results: see D4.

**Entry points:**

| Path | Rule |
|---|---|
| `BashExec`, `RunTests` via main dispatch | Resolve the request. Always pass the applied limit explicitly to the primitive |
| Scratchpad loopback, `run_native_batch` | Same. Resolution sits in the shared process executor, `run_process_result`, so a path cannot skip it |
| Extension effects, `session.ail` | No model request reaches this seam. `timeout_ms: 0` stays, and processes they start keep the session default |
| Internal helpers | Plain `exec` at the session default (I5) |
| TUI launch | `MOTOKO_PROCESS_TIMEOUT` and `MOTOKO_PROCESS_TIMEOUT_MAX`, resolved with the profile |
| Direct CLI launch | The session limit comes from the D3 accessor, so the reported value is what was set on the command line |
| Profile restart | `respawnForRestart` must not leave stale limits. A restart keeps the values resolved at startup unless the profile changed, in which case it resolves them again |
| Herdr | Its check wait stays sized from the default. It is not a tool call and makes no request |

## 5. Alternatives considered

- **Raise the session limit and stop.** Available today and fine as relief, but every hung command
  gets the full budget. Gap 1 is the point of this ADR.
- **GNU `timeout` wrapper.** Withdrawn by the operator at 034 ruling 6. It changes the observation
  from `Err(Timeout)` to an exit code of 124. Not reopened.
- **`spawnProcess` plus `cancelProcess` in Motoko.** The handle exposes no stdout or exit status, so
  output would need redirecting through temporary files and polling. This builds a second process
  executor, the shape ADR-001 removed.
- **`std/stream.asyncExecProcess` plus `cancelProcessSource`.** This does deliver stdout, and its
  subprocess is owned by its execution. Rejected as the executor because its public interface has no
  combined stdout, stderr and exit-status result and no per-call deadline, so Motoko would have to
  rebuild those. Its lifetime handling is relevant to R5.
- **A background-job tool** (start, poll, stop). A real feature that would serve long jobs better,
  but larger, with its own lifecycle and effect questions. It does not remove the need for a sane
  limit on foreground calls.
- **Refuse a request above the ceiling.** Simpler to specify and rejected in D2, subject to R3.
- **Per-tool limits in the profile.** More settings without solving the case of one slow command
  among many fast ones.

## 6. Sequence and acceptance

1. D5's probe, and the D6 cancellation fix or ruling R5. These do not depend on a new primitive, and
   nothing below ships before D6 is resolved.
2. File the upstream asks after R1.
3. The D7 resolver and its scripted configuration, with the replay measurement. This needs no
   primitive and changes no enforced limit.
4. After a pin carries the primitive: D1, D2, D4's limit metadata with its re-baseline, and the
   replacement catalog test.
5. After a pin carries #1878: partial output.

Accepted when:

- With no new setting, a request for more than the default still stops at the default, and the
  result says so (I1, I4).
- With a ceiling set, a call requesting more than the default outlives the default, while a call
  in the same session that requests nothing stops at the default.
- A request above the ceiling stops at the ceiling. A clamped command that succeeds immediately
  still reports the clamp, and so does a clamped command that exits non-zero.
- A shorter request stops at the shorter limit.
- Zero, negative, fractional, string, null and very large requests are handled by D2's table, with
  independent evidence that invalid calls never launched.
- Internal helpers run at the default during and after a long-running request, which catches leaked
  global state (I5).
- A DST scenario and a live probe under the same configuration agree on actual enforcement and on
  the model-visible fields, not only on a number in two records (I3).
- The schema's stated ceiling matches the configured one, and a ceiling below the default fails at
  startup.
- Every entry point in D7's table has a test, including loopback, a direct CLI launch and a restart.
- Limit fields survive truncation of a result with very large output.
- Generated programs and salts are unchanged for existing seeds, and journals recorded before the
  change still replay, or the migration is recorded.
- After #1878, partial stdout and stderr are preserved on a timeout; before it, their absence is
  explicit.
- Timing tests separate the enforced deadline from return latency, which can include `WaitDelay`.
- A `BashExec` or `RunTests` timeout reports `effects: unknown`, and a `Search` timeout still reports
  `effects: none` (I2).
- Cancelling a run stops the command and its ordinary descendants with no late effect, or ruling R5
  accepts the failure. A recorded failure alone does not satisfy this.
- An existing `MOTOKO_PROCESS_TIMEOUT` above any shipped limit still starts, with no new setting (I4).
- `tools.delegated_timeout_ms` is not given a role here. Its removal stays with the issue above.

## 7. Rulings needed

| # | Question | Recommendation |
|---|---|---|
| R1 | File the per-call timeout, limit-reporting and containment asks upstream? | File all three. Per-call timeout and limit reporting are dependencies, containment is not |
| R2 | Should the shipped `default` profile set a ceiling? | No. Leave it unset, so extension stays opt-in and an existing `MOTOKO_PROCESS_TIMEOUT=600s` cannot become a startup error (I4). `demo_dst`'s `300s` is its default limit, not a ceiling, so it is no precedent |
| R3 | Clamp or refuse a request above the ceiling? | Clamp, and report it |
| R4 | If upstream declines or is slow, what then? | Keep the session setting as the only relief and revisit. Do not fork or build a second executor without a new ruling |
| R5 | Fix the D6 cancellation defect, or accept it? Where? | Fix it, separately and first, because it affects every session today. Ask upstream whether AILANG should end its process groups when the runtime is terminated, and only then consider the TUI |

## 8. Consequences

- The model gets a way to ask for time, and with it a way to hold a session for up to the ceiling.
  The ceiling is the operator's bound on that, so its setting matters.
- Every process result grows by a few bounded fields, in every session, which costs a re-baseline
  and a small number of tokens per call.
- Motoko takes a dependency on an upstream API that does not exist yet, so the main benefit has no
  date.
- A longer wall lengthens a blocked turn. Whether the TUI stays usable during that wait is not yet
  measured.
- Raising `tools.process_timeout` today does not change the D6 defect, which is already unbounded.
