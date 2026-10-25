# BashExec's two timeout knobs are dead: `timeout_secs` is never parsed and `tools.delegated_timeout_ms` is never read

## Status

open — filed 2026-09-26 from the `make demo_dst` runs (sessions
`session_1790414683122-598f9b02d794a0b1` and `session_1790415720845-56963b377d77b009`).
Interim relief landed in `242eeb4d` (`MOTOKO_PROCESS_TIMEOUT` → `--process-timeout`), which is a
per-session global and not a fix for either knob. **The per-session half was then closed the same
day:** a profile's `tools.process_timeout` is forwarded to `--process-timeout` (`index.ts`,
`resolveProfileAgentConfig` → `applyToolProfileConfig`, with the shell env var taking precedence),
so a profile now states a budget that is applied. The live BashExec schema no longer advertises
`timeout_secs`; it was never parsed. `tools.delegated_timeout_ms` is still loaded, copied and read
by nothing after M10b removed its delegated-result consumer — it should be deleted so no profile
states a budget nobody applies.

**2026-10-24 update, corrected after independent review:** the additional TUI
`RuntimeProcess.runDelegatedCall` timer was unreachable in current sessions. M10b deleted its
AILANG producer and result consumer, and `tool_phase.ail` routes live calls to native execution.
The reported long-demo timeout and the surviving-descendant reproduction are therefore native
AILANG behavior, not delegated TUI behavior. The delegated timeout patch was rejected and is being
replaced by dormant-path removal. It did not fix the native defect.

The live native issue on the pinned v0.52.5 remains: AILANG `exec.CommandContext` kills the
immediate process, and a descendant can survive and write after the timeout while `WaitDelay`
bounds pipe waiting. Upstream v0.54.14 already implements process-group cancellation with
`WaitDelay`; this PR includes that pin and the native process-tree probe, while project 012 keeps
continuous adoption ownership. The revised architecture and scope are recorded in
[project 041 ADR-001](../projects/041_process_execution_timeouts/ADR-001-delegated-process-timeouts.md).
The live schema no longer advertises `timeout_secs`; consistent per-call semantics remain follow-up work.

## Original report (2026-09-26, historical)

The body below records the original observations and proposals. The **Status** section above takes
precedence for the current architecture. In particular, `timeout_secs` is no longer advertised,
profile forwarding now reaches the native process wall, and native timeout results carry a
structured deadline fault with `effects: unknown`. The original proposal to give
`delegated_timeout_ms` a new process-wall role is not adopted.


A BashExec that runs longer than about 35 s comes back to the model as

```json
{"exit_code":1,"stdout":"","stderr":"timeout after 35005ms"}
```

and nothing the model or an operator can set through the tool or the profile changes that number.
Two things advertise control over it, and neither is connected to anything.

**1. The tool schema advertises `timeout_secs`; the dispatcher never reads it.**
`src/core/tool_catalog.ail:55` declares BashExec's parameters as `cmd`, `args` and
`timeout_secs` (integer). `parse_exec_from_args` (`src/core/tool_runtime.ail:174`) builds the
`ProcessExecReq` from `cmd`, `args`, `cwd`, `streaming`, `needs_stderr_live` and
`needs_hard_cancel` — `timeout_secs` is not among them, and `ProcessExecReq` has no field to carry
it. Models do use the parameter, because the schema tells them to: session
`…598f9b02d794a0b1` step 4 sent `"timeout_secs": 240` and session `…56963b377d77b009` step 5 sent
`"timeout_secs": 180`; both were killed at 35 s. A parameter the schema offers and the runtime
ignores is worse than no parameter: the model reasonably believes it has raised the budget, and
its next inference is built on that belief.

**2. `tools.delegated_timeout_ms` travels through three records and is read by none.**
`config.ail:375` loads it from the profile JSON (default 30000), `config.ail:655` serializes it
back out, and `rpc.ail:348` and `:453` copy it into `RunSettings.delegated_timeout_ms` — and there
it stops. A recursive grep over `src/` and `packages/` (`.ail` and `.ts`, excluding `config.*`
and `rpc.ail`) for any reader returns zero. Every profile in `.motoko/config/` sets this key to
30000 alongside `delegated_timeout_slack_ms: 5000`, and 30000 + 5000 happens to equal the wall the
model actually hits, so a reader who patches the key (as the first version of `make demo_dst` did)
sees the number they expect in the profile, a `demo_dst` header in the journal, and the same 35 s
kill. The TUI's `config.ts:38` maps the key to `DELEGATED_TOOL_TIMEOUT_MS` for TOML profiles; that
path ends in the same place.

**What actually sets the wall.** `run_process_result` executes the command as
`exec(effective.cmd, effective.args)` (`src/core/tool_runtime.ail:988`), and `std/process.exec`
takes no timeout: the runtime applies its global `--process-timeout`, default `30s`
(`ailang/cmd/ailang/main_run.go:81`, `ailang/std/process.ail:11`), and after the kill Go's
`cmd.WaitDelay = 5 * time.Second` (`ailang/internal/effects/process.go:130`) holds the pipes open
for the orphan — which is the 5 s over 30 in every observed `timeout after` value. The TUI spawned
the runtime with a fixed argument list, so no profile value could reach the flag until `242eeb4d`.

**Why it matters beyond the demo.** The failure mode is silent at the point of use: exit 1 with an
empty stdout looks like "the command produced nothing", not "the harness gave up". In the demo the
prompt's honesty rule read it correctly as *no verdict* and stopped; an ordinary session has no such
rule and will proceed on the empty result. Any real task that compiles, runs a test suite, or waits
on a network call is exposed.

## What a fix looks like

- **Per call:** honour `timeout_secs`. `std/process.exec` has no per-call timeout, so this is either
  an upstream AILANG API (`exec` with a deadline option) or an in-tree implementation over
  `spawnProcess`/`closeProcessStdin` with the deadline enforced by the harness. Until one exists the
  schema should stop advertising the parameter, or the dispatcher should reject a call that passes
  it, so the model's belief and the runtime's behaviour cannot diverge silently.
- **Per session:** either wire `tools.delegated_timeout_ms` to the spawn's `--process-timeout` (the
  TUI reads the profile in `index.ts:353` and could pass the value the way `242eeb4d` passes the env
  var) or delete the key from `config.ail`, `rpc.ail` and every profile, so a profile no longer
  states a budget nobody applies.
- **At the kill:** the tool result should say it was the harness. `timeout after 35005ms` in
  `stderr` with exit 1 is the whole signal today; a distinct field or a `ToolErrorResult` would let
  a guard or an orchestrator tell "command failed" from "budget exhausted".
