# ADR-002: Per-call process timeouts and what a timeout tells the model

Date: 2026-10-30
Status: **Proposed, sixth revision. Rulings R1-R6 are recorded in §7, with two proposals not yet ruled; the ADR as a whole is not marked accepted.**
Grounded at: `origin/main` `a393314b` (#284 merged). AILANG v0.54.14, with the upstream API also
read at v0.55.0.

Revised after an independent review of the first revision by Codex GPT-6.1-Sol at xhigh, whose
verdict was rework. The operator chose the recommended amendment for each finding. A second review
of the fourth revision also returned rework, chiefly because that revision's D7 resolved limits below
the scripted path. A third review, of the fifth revision, found seven of those eight findings resolved
and again returned rework, chiefly over how live runs capture limits and how legacy programs survive
re-encoding. This revision addresses all seven of its findings, the first by narrowing the replay goal
(R6 in §7). It has not been re-reviewed, and the D7 design is unimplemented, so that verdict has not
been replaced.

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

**One function resolves every limit, before the world splits into live and scripted.** A call with
no request keeps the native session default untouched. A program states its limits or says it is
legacy, and that survives re-encoding. Strict replay of a production live run's limits is a stated
gap, not a promise. (D7)

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
| Scripted execution branches off before native dispatch, and its completed content passes straight through | `src/core/ports.ail:1843`, `src/core/tool_phase.ail:291` |
| The recorder persists `inv.timeout_ms` in the request projection, and strict replay compares projections exactly | `src/core/ports.ail:2172`, `src/core/dst_replay.ail:334` |
| Reconstitution restores a run's inputs from `InitialWorld`, such as its synthetic environment | `src/core/dst_replay.ail:925` |
| `--process-timeout` is a Go duration: `1500us` is kept as 1.5 ms, and `0` and `-1s` start and then time out immediately | AILANG `internal/runner/handlers.go:245`, measured by the second review |
| Production live runs use `live_ports` and `world_tool`, not the recording adapter, and even that adapter measured no duration for a real command. The route from a live run to a program is journal admission, whose recorded configuration has no process limits | `src/core/session.ail:1527`, `src/core/ports.ail:3106`, `src/eval/journal/configuration.ail:115`, `src/eval/journal/admission.ail:725`, measured by the third review |
| The decoder keeps an artifact's version, but both encoders always write the current one, and generators and admission stamp the current one too | `src/core/dst_persistence.ail:743`, `src/eval/journal/scan.ail:579`, `scripts/dst/corpus_pr_dst.ail:475`, `src/eval/journal/admission.ail:725` |
| Each encoding change bumps the schema and freezes a specimen: a version-gated header line with an explicit value, absent before its version, is the existing pattern | `applied_faults`, `src/core/dst_persistence.ail:441-470`, `scripts/dst/program_persistence_dst.ail:1694` |
| The scripted deadline predicate treats `timeout_ms` 0 as no deadline | `src/core/ports.ail:1884` |
| A process error reaches result construction as a `ProcessError` alone, with no receipt that a child ran | AILANG `internal/effects/process.go:223`, `src/core/tool_runtime.ail:1040` |

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

This is the contract of the model-facing tools through main dispatch. D7's entry-point table states
the two origins that differ: scratchpad loopback and extension effects.

### D2. The limits

The request table below applies to main dispatch. Loopback validates in the same way against a lower
effective ceiling, and extension effects do not read the argument at all (D7).

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
| Zero, negative, with a fractional part, not a number, or above 31,536,000 (one year) | Argument error before launch, `effects: none` |

A request above the ceiling is clamped rather than refused, because refusing costs a model turn
and the command may well finish in time. The applied limit is always in the result, so the model
is not left believing it got what it asked for, which was the original `timeout_secs` defect. A
lowered limit is honoured: a request may shorten as well as extend.

The upper bound exists so that a request converts to milliseconds without overflow, and so that
`requested_timeout_ms` is bounded. It is far above any sensible ceiling, so a value beyond it is
treated as a malformed argument and not clamped.

`tools.process_timeout_max` is a new setting, so unlike `process_timeout` it may be strict: it must
be positive and a whole number of milliseconds. A ceiling below the default is a configuration error,
raised at startup. `process_timeout` keeps its native domain unchanged (I4), including sub-millisecond
values and non-positive values that time out immediately.

### D3. The primitive comes from AILANG

Ask upstream for a per-call timeout on `exec`, for example
`execWith(cmd, args, { timeout_ms })`, sharing the existing group kill and `WaitDelay`.

Motoko validates the limit against its own ceiling (I1). If upstream also enforces a ceiling, that
is additional and not a replacement. Filed under ruling R1 as sunholo-data/ailang#2035.

A second request, sunholo-data/ailang#2036, asks for the run's configured process limit to be
readable before any process starts. Returning the limit with `Err(Timeout)` is not enough: it comes
too late to compare a request with the default, to validate a ceiling at startup, or to report the
limit on a command that succeeded. Motoko cannot otherwise know the limit of a run launched directly
with `--process-timeout`, as `Makefile:2673` does.

No part of D1, D2 or D4's limit metadata ships before a pin carries both #2035 and #2036. A schema that
advertises an argument nothing enforces is the defect #284 removed, and a reported limit that may
be wrong repeats it. D5's probe can ship earlier.

### D4. What a result says

**Every `BashExec` and `RunTests` result that attempted an `exec`** carries limit metadata, independent
of fault disclosure, on success, non-zero exit, timeout and any other process error alike:

- `timeout_ms`: the limit given to that attempt, and `requested_timeout_ms` when clamped.
- `max_timeout_ms`: the effective ceiling for this origin (D7), so the model can tell whether asking
  for more time can help.

The test is the attempt, not whether a child ran. A `ProcessError` carries no launch receipt, so the
fields say what limit applied and say nothing about whether the command started. Uncertainty about
that stays where it is today, in `effects: unknown`.

**A call the harness knows made no attempt**, such as an invalid request or an existing refusal, has
no applied limit and reports none. It carries `max_timeout_ms` alone, plus `requested_timeout_ms` when
the request was a number in range.

These are display values, in whole milliseconds and rounded up. They never feed enforcement, so a
sub-millisecond session limit stays exact in the runtime (D7). `null` means no deadline, which only a
scripted `NoDeadline` default can produce, for `timeout_ms` under `SessionDefault` and for
`max_timeout_ms` under `SameAsDefault`. `0` means an immediate deadline, the display of any non-positive
native default, and never means no deadline. The fields are bounded and go before
`cmd` and the output fields, so truncating a message cannot remove them, even for an oversized `cmd`.
An ordinary completed command still carries no `fault` (034). One rendering helper produces them, used
by the live path, the scripted path (which bypasses native result construction) and loopback.

**A timeout** of either tool also keeps `effects: unknown` (I2), and adds:

- Partial stdout and stderr, once #1878 is available on a pin. Until then the absence stays
  explicit, and an empty string must not read as "the command printed nothing".
- The existing instruction not to assume the command had no effect, extended to: check state
  before retrying, because a retry may repeat what already happened.

Today a live timeout arrives as `Err(Timeout)` and carries only the elapsed time, while the scripted
path has `ToolDeadlineExceeded` with a `timeout_ms`. Both must report the same fields (I3).

**Migration.** These fields change the bytes of results in a live run with limits and in any program
whose mode is `Limits` (D7). A `Legacy` program renders as it does today, so existing corpora need no
result change. Live-binding fixtures and recorded streams are re-baselined in the same change, with the
diff limited to these fields. Historical tool messages are never rewritten.

### D5. Detached descendants stay a disclosed limit

Motoko will not build process containment. A `setsid` or daemonized descendant survives the kill,
and if it holds the pipes the call returns no later than the limit plus `WaitDelay`, and earlier if
the pipes close first: with a 1 s limit and a descendant exiting at 3 s, it returned at about 3 s.

- Extend `make verify_native_process_tree` with a `setsid` case asserting today's behaviour, so an
  upstream change is seen instead of assumed. This is planned; the probe tests ordinary descendants
  only today.
- Upstream was asked, in sunholo-data/ailang#2037, for a stronger containment primitive such as Linux
  cgroups or a subreaper. This ADR does not depend on it.
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

A standalone reproduction with only `std/process.exec` and no Motoko code gave the same result on
v0.54.14 and v0.55.0. With the signal sent to the `ailang` pid alone, the command survived and wrote
its marker after SIGTERM (exit 143), SIGINT (130) and SIGKILL (137). Filed as
sunholo-data/ailang#2034.

Once the runtime is dead, nothing owns the deadline, so the command runs until it exits. **This does
not scale with the limit:** a 30 s limit does not make it short, and a low ceiling does not contain
it. It is a defect on `main` today, independent of everything else in this ADR.

Before D1 ships, one of these must hold:

- a test shows that cancelling a run stops the command and its ordinary descendants, with no late
  effect; or
- the operator accepts the unbounded failure in a new ruling. R5 chose to fix it.

R5 looks to AILANG first and to the TUI only if that stalls. AILANG owns the process group and already has process-lifetime
machinery on its stream and managed paths (`runlife.Prepare`, `internal/effects/stream_process.go:67`),
while the TUI is what chooses SIGTERM.

### D7. One resolver, ahead of the world split

**Status: designed from reading the code, not built.** Replay behaviour below rests on the second
review's probe of the current recorder and comparison code.

**Where it runs.** In `tool_phase.ail`, in the native dispatch, before `ports.tool_exec` selects
scripted or live behaviour (`src/core/tool_phase.ail:500`), and only for `BashExec` and `RunTests`.
Resolving any lower would miss scripted runs, which branch off at `src/core/ports.ail:1843`. An invalid
request stops here and never reaches the port, in either world.

**The types.** A limit is not reduced to a number, because the session default has a native domain
that an integer cannot hold. `ns` and `ms` are different units and are converted only where this
section says so:

```
SessionLimit  = Finite(ns) | NoDeadline          -- NoDeadline exists only in scripted worlds
ProcessLimits = { default: SessionLimit, ceiling: CeilingMs(int) | SameAsDefault }
LimitMode     = Legacy | Limits(ProcessLimits)
ProcessBudget = SessionDefault | ExplicitMs(int)
ResolvedProcess = { budget: ProcessBudget, requested_ms: Option[int], clamped: bool,
                    effective_ceiling: ProcessLimits.ceiling }
resolve_process_limit(limits, request) -> ResolvedProcess | invalid
```

**The rule**, with `r` as a valid request in milliseconds and `r_ns = r * 1_000_000`, which D2's upper
bound keeps from overflowing:

| Limits | Request | Budget | Clamped |
|---|---|---|---|
| Any | None | `SessionDefault` | No |
| `CeilingMs(c)` | `r <= c` | `ExplicitMs(r)` | No |
| `CeilingMs(c)` | `r > c` | `ExplicitMs(c)` | Yes |
| `SameAsDefault`, default `Finite(d)` | `r_ns < d` | `ExplicitMs(r)` | No |
| `SameAsDefault`, default `Finite(d)` | `r_ns >= d` | `SessionDefault` | Only if `r_ns > d` |
| `SameAsDefault`, default `NoDeadline` | `r` | `ExplicitMs(r)` | No |

`NoDeadline` is matched as its own case and never compared numerically, so a shorter scripted request
stays finite. A default of `NoDeadline` with a `CeilingMs` is valid in a scripted world: a call that
asks for nothing has no deadline, and a call that asks is bounded by the ceiling. Live enforcement
passes `SessionDefault` as a plain `exec`, so the native value, including `1500us`, `0` and `-1s`,
behaves exactly as it does today. Under `SameAsDefault`, a non-positive or fractional default falls in
the `r_ns >= d` row, so the native value still decides. Only `ExplicitMs` uses the new primitive, and a
request is at least one second, so nothing there needs sub-millisecond precision. `invalid` is D2's
table.

**The carrier.** `ToolInvocation` gains `process: Option[ResolvedProcess]`. It is `Some` only for
`BashExec` and `RunTests` in `Limits` mode, and `None` for every other tool and for everything in
`Legacy` mode, so those keep today's deadline contract exactly. The live path passes the budget to the
primitive, and rendering takes the other fields from the same value.
`run_native_batch` takes the resolved value for each call, so a caller cannot omit it, and it consumes
that value without clamping again.

**Scripted expiry.** The existing predicate cannot serve here, because it reads 0 as no deadline. For
a scripted duration `t` in milliseconds, the order of `scripted_tool_outcome`'s checks is unchanged and
the deadline check becomes:

| Carrier | Expires when |
|---|---|
| `None` | `timeout_ms > 0 && t > timeout_ms`, today's predicate |
| `SessionDefault`, `NoDeadline` | Never |
| `SessionDefault`, `Finite(n)`, `n <= 0` | Always, including `t = 0` |
| `SessionDefault`, `Finite(n)`, `n > 0` | `t * 1_000_000 > n` |
| `ExplicitMs(m)` | `t > m` |

`ToolDeadlineExceeded.timeout_ms` carries D4's display value, so the two worlds report the same field.

`ToolInvocation.timeout_ms` is a projection, and this makes it total: `ExplicitMs(m)` records `m`, and
every other outcome, including a request that resolved to `SessionDefault` or a tool with no carrier,
records today's value, which on a live run is 0. Enforcement of a process tool never reads it. This
keeps the projection of a call with no request byte-identical to today, which the second review's probe
shows is what strict replay needs: a live invocation that recorded 30000 failed against a scripted 0.

**Program modes.** `InitialWorld` gains `process_limits: LimitMode`, following the `applied_faults`
pattern: a required header line from `execution-program/6`, absent before it, with an explicit value,
either `legacy` or the default and ceiling with durations as integer nanoseconds.

| Program mode | Limits come from | Request | Metadata |
|---|---|---|---|
| `Limits` | `InitialWorld.process_limits` | Resolved | Rendered |
| `Legacy` | `MOTOKO_TOOL_TIMEOUT_MS`, as today | **Ignored, as today** | None |

The mode is the field, never inferred from the version. Decoding v1-v5 yields `Legacy`, as the absence
of `applied_faults` yields an empty list, because that is what those versions meant. Encoding always
writes the field, so `Legacy` survives decode, encode and decode under any later version, even though
the encoders stamp the current one. Ignoring a request in `Legacy` matters because older sessions did
send `timeout_secs`, and replaying them must not change what those runs did.

`MOTOKO_TOOL_TIMEOUT_MS` stays a scripted-only input and gains no live meaning, and its
once-per-dispatch read is kept in both modes because the discovery recorders count it. In `Limits` mode
it no longer governs process tools, so a scripted world can represent default 1000, ceiling 3000,
request 2000, and it still governs the other tools. In `Legacy` its 0 still means no deadline.

**Live runs.** The limits resolved at startup (D7's entry points) are held in the live `WorldState`
as `Limits(...)`, at `src/core/session.ail:1527`, and on what loopback's context carries. This is
runtime state and is not written to a program.

**What replay does not cover (ruling R6).** Production has no recorder for these limits. A live
run becomes a program only through journal admission, and journal configuration does not hold them.
This ADR does not add that capture path, so admission writes `Legacy`. Replay of a post-change journal
therefore serves the tool content the journal recorded, metadata and argument errors included, and does
not re-resolve a request. Whether that request was correctly clamped at the time is covered by live
probes and `Limits`-mode scripted programs, not by replay of that journal. This reading of admission is
inferred from the code and needs the admission test in §6. Adding the path later means the chain from
startup through journal configuration and admission to `InitialWorld`, with a rule for journals that
lack the input.

**Migrations this names:**

- Program schema: `execution-program/6`, with `execution-program/5` written out in
  `decodable_schema_versions()` by name, and a new frozen v6 specimen. Every writer, including
  generators and admission, stamps v6 with `legacy` until it is migrated. That is a schema-only artifact
  refresh at step 3: the version line, digest and that one header line change, while draws and
  interactions do not. Frozen v1-v5 specimens are untouched.
- Generator: stays `Legacy` until it is taught to emit limits and `timeout_secs`. That is a new draw, so
  it needs its own version bump and corpus refresh, in its own change. The 20-90 ms draw, its salts
  and the 2,000 ms corpus bound are not touched.
- Replay: the second review measured that today's code passes an old recording against 0 and fails any
  mismatch. Old-recording and scripted `Limits` round trips are both required tests.
- Journal resume: the second review measured that old journals fold and plan resume, and that resume
  checks workdir, lease, profile and digests, not `timeout_ms`. Full post-change compatibility can only
  be shown once this is built.
- Rendered results: see D4.

**Entry points:**

| Path | Rule |
|---|---|
| `BashExec`, `RunTests` via main dispatch | Resolved in `tool_phase`, as above |
| Scratchpad loopback (proposal P1) | Resolved in `tool_envelope_dispatch`, the adapter, with the run's limits but `ceiling` forced to `SameAsDefault`. It can shorten but never extend. An invalid request is rejected, a request above the default is reported as clamped, and `max_timeout_ms` reports the default and not the run's ceiling. With default 30 s and ceiling 300 s, a 60 s request runs at 30 s and says so |
| Extension effects, `world_ext_effect` (proposal P2) | These reach the same live executor, and herdr invokes `BashExec` this way (`packages/motoko-ext-herdr/herdr.ail:447`). In `Limits` mode, process tools carry `SessionDefault` with `SameAsDefault`, and no request. `timeout_secs` in their arguments is not read, so it is not validated either. `timeout_ms: 0` on that envelope stays |
| Internal helpers | Plain `exec` at the session default (I5) |
| TUI launch | `MOTOKO_PROCESS_TIMEOUT` and `MOTOKO_PROCESS_TIMEOUT_MAX`, resolved with the profile and passed to the runtime |
| Direct CLI launch | The default comes from the #2036 query, so the reported value is what was set on the command line |
| Profile restart | `respawnForRestart` must not leave stale limits. A restart keeps the values resolved at startup unless the profile changed, in which case it resolves them again |
| Herdr's check wait | Stays sized from the default. Herdr's own process calls make no timeout request |

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

1. D5's probe, and the D6 cancellation fix that R5 chose. Nothing below that activates a longer limit
   ships before the fix.
2. Upstream asks: filed on 2026-10-31 as sunholo-data/ailang#2034 to #2037.
3. The pure resolver and its tests, the scripted carrier and expiry, and `execution-program/6` with
   the schema-only artifact refresh D7 names, every writer stamping `legacy`. This activates nothing
   and needs no upstream change. Live wiring is step 4.
4. After a pin carries both #2035 and #2036: live wiring, D1, D2, D4's limit metadata with its
   re-baseline, and the replacement catalog test.
5. After a pin carries #1878: partial output.

Accepted when:

- With no new setting, a request for more than the default still stops at the default, and the
  result says so (I1, I4).
- With a ceiling set, a call requesting more than the default outlives the default, while a call
  in the same session that requests nothing stops at the default.
- A request above the ceiling stops at the ceiling. A clamped command that succeeds immediately
  still reports the clamp, and so does a clamped command that exits non-zero.
- A shorter request stops at the shorter limit.
- Zero, negative, fractional, string, null and out-of-range requests, including 10^16, are rejected
  by D2's table, with independent evidence that they never launched. They report no applied limit.
- Internal helpers and default calls in the same runtime run at the default after an extended call,
  which catches leaked global state (I5). Batches run one call at a time
  (`src/core/tool_runtime.ail:224`), so helpers running during a long call are not a reachable case.
- A DST scenario and a live probe under the same finite limits agree on actual enforcement and on the
  model-visible fields, not only on a number in two records (I3). This covers extension, omission,
  shortening and clamping.
- Scripted-only tests cover a `NoDeadline` default, with and without a ceiling, including its `null`
  fields. It has no live counterpart, because a native 0 is an immediate deadline.
- Every `SameAsDefault` row is tested with a 30 s default, a request of 60 s must not extend it, and
  equality, fractional and non-positive defaults and omission are covered. `timeout_ms` is projected
  for each outcome.
- A scripted `Finite(0)` expires at `t = 0`, while `timeout_ms: 0` with no carrier still means no
  deadline. `ReadFile`, `Search`, `WriteFile` and `EditFile` keep today's scripted deadline behaviour.
- A process error other than a timeout reports the attempt's limit, and a call refused before any
  attempt does not.
- `--process-timeout 1500us`, `0` and `-1s` behave as they do today (I4).
- An old recording replays unchanged, including one whose calls carry `timeout_secs`. A transcode test
  decodes, encodes and decodes a legacy program containing `timeout_secs: 0`, and it stays `Legacy` and
  ignores the request.
- A scripted `Limits` program round-trips with a clamped request. A post-change journal containing a
  clamped and an invalid request admits as `Legacy` and replays strictly, serving the recorded content.
- The schema's stated ceiling matches the configured one, and a ceiling below the default fails at
  startup.
- Every entry point in D7's table has a test, including loopback, a direct CLI launch and a restart.
  The same argument is sent through main dispatch, loopback and an extension effect, and each behaves
  and reports as its row says.
- Limit fields survive truncation of a result with very large output and with an oversized `cmd`.
- Generated programs keep their draws, salts and interactions for existing seeds, and differ from the
  pre-v6 artifact only in the version line, digest and `process_limits` line. Journals recorded before
  the change still fold and plan resume.
- After #1878, partial stdout and stderr are preserved on a timeout; before it, their absence is
  explicit.
- Timing tests separate the enforced deadline from return latency, which can include `WaitDelay`.
- A `BashExec` or `RunTests` timeout reports `effects: unknown`, and a `Search` timeout still reports
  `effects: none` (I2).
- Cancelling a run stops the command and its ordinary descendants with no late effect. A recorded
  failure alone does not satisfy this.
- An existing `MOTOKO_PROCESS_TIMEOUT` above any shipped limit still starts, with no new setting (I4).
- `tools.delegated_timeout_ms` is not given a role here. Its removal stays with the issue above.

## 7. Rulings

**Ruled by the operator on 2026-10-31**, in conversation, choosing the recommended option for each.

| # | Question | Ruling |
|---|---|---|
| R1 | File the per-call timeout, limit-reporting and containment asks upstream? | File all three. Per-call timeout and limit reporting are dependencies, containment is not. Filed as sunholo-data/ailang#2035, #2036 and #2037. #2036 and #2037 were corrected on 2026-10-31 after the second review |
| R2 | Should the shipped `default` profile set a ceiling? | No. Leave it unset, so extension stays opt-in and an existing `MOTOKO_PROCESS_TIMEOUT=600s` cannot become a startup error (I4). `demo_dst`'s `300s` is its default limit, not a ceiling, so it is no precedent |
| R3 | Clamp or refuse a request above the ceiling? | Clamp, and report it |
| R4 | If upstream declines or is slow, what then? | Keep the session setting as the only relief and revisit. Do not fork or build a second executor without a new ruling |
| R5 | Fix the D6 cancellation defect, or accept it? Where? | Fix it, separately and first, because it affects every session today. Ask upstream whether AILANG should end its process groups when the runtime is terminated, and only then consider the TUI. Filed as sunholo-data/ailang#2034 |
| R6 | Must replay cover a production live run's limits? | No. Existing recordings and generated programs must still replay unchanged, including after re-encoding, and journal admission writes `Legacy`. Production has no recorder for these limits, and live probes and scripted programs test resolution directly. This holds only if §6's admission test passes: if a post-change journal does not replay cleanly as `Legacy`, the ruling is reopened. Revisit it if journal replay is to serve as evidence of how limits were enforced |

**Proposed and not ruled:**

| # | Proposal | Reason |
|---|---|---|
| P1 | Scratchpad loopback can shorten a limit but not extend it | Loopback is a second route to a tool. Extending there would be a decision of its own |
| P2 | Extension effects stay on the session default and do not read `timeout_secs` | The argument is the model's, and an extension's process call is not a model request |

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
- A replayed journal cannot show that a past clamp was correct, only what the model saw (R6).
- `execution-program/6` refreshes every generated artifact once, for a field that stays `legacy` until
  something uses it.
