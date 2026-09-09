# A killed Motoko process exits silently, and nothing on screen or on disk says it was killed

## Status

open

## Branch

`arniwesth/013-plan003-and-herdr` (observed 2026-09-08 during the PLAN-003 P1/P3 live run)

## Description

A Motoko session driving PLAN-003 by delegation disappeared mid-run. Nothing was printed to the
console, no error event reached the TUI, no exit manifest was written, and the operator's first
signal was an empty pane. The operator reports having seen the same shape "a few times before".

The proximate cause on 2026-09-08 was the **container's OOM killer** (evidence below). That part is
environmental and is fixed by raising a limit. What makes it an issue rather than a note is the
second half: **nothing in the tree can tell a killed process from a finished one.** A SIGKILL is
never observable by the process it kills, so the only place the fact can surface is the parent —
and the parent throws it away.

## Evidence (2026-09-08)

**The session ended mid tool-phase.** `.motoko/logfile/session_2026-09-08T18-55-10-603Z.jsonl`
ends on `native_tool_calls` for step 215 — tool `DelegateCheck`, `msg_count` 429,
`estimated_input_tokens` 65230 — with no `native_tool_results`, no `run_summary`, no `error` and
no `done`. Step 215 of a 1200 budget, so not exhaustion.

**The clean-exit path never ran.** `.motoko/exit/` holds manifests for earlier sessions
(`manifest-1788877501858-*`, `manifest-1788808155692-*`, `manifest-1788808009957-*`) and **none**
for `1788893710604`. Its delegate was never reaped and was still idle in its pane the next
morning, having written its answer file at 21:03 — 29 minutes after the orchestrator's last write
at 20:34.

**The kernel killed something.** `/sys/fs/cgroup/memory.max` is `8589934592` (8 GiB) and
`/sys/fs/cgroup/memory.events` reads:

```
max      2137700
oom      1
oom_kill 1
```

One OOM kill, cumulative for this cgroup's lifetime, against 2.1 million events of hitting the
ceiling. At rest the next morning four long-lived `claude` processes held ~1.6 GiB (471, 459, 335,
305 MiB) before any Motoko work started.

**What is NOT evidenced.** `oom_kill` is 1, so exactly one kill can be attributed. Two other
truncated logs — step 29 in `session_2026-09-08T18-42-46-467Z` and step 135 in
`session_2026-09-08T17-42-56-347Z` — coincide with the operator closing panes, and a pane close
SIGKILLs the process and produces a byte-identical signature. The earlier occurrences the operator
remembers are therefore **not** shown to be OOM kills by this evidence, and one of the two shapes
is innocent.

## Location

- `src/tui/src/runtime-process.ts:620` — `this.proc.on("exit", () => { ... })`. Node's `exit`
  event supplies `(code, signal)`; this callback **takes no arguments**, so a child killed by
  SIGKILL is indistinguishable from one that returned 0 at the one site that could tell them
  apart. The sibling handler at `:701` does read `code`, which is what makes the omission look
  accidental rather than considered.
- `.motoko/exit/` — the absence of a manifest is currently the most reliable "this did not exit
  cleanly" signal in the tree, and nothing reads it.

## Fix

Two halves, and only the second is this repo's.

1. **Environmental, and the operator's:** raise the container memory ceiling, and/or keep fewer
   long-lived agent CLIs resident. 8 GiB is not much for a TUI, an AILANG child and several
   delegate CLIs at once. `.devcontainer` is mounted read-only from inside, so this follows the
   `PATCH-agent-confined-*.md` pattern.

2. **Report a death as a death.** `runtime-process.ts:620` should take `(code, signal)` and, when
   the child exits non-zero or on a signal, surface it the way any other runtime failure is
   surfaced rather than calling `onExit()` as if the run had finished. `signal === "SIGKILL"` with
   no prior terminal event is worth naming out loud — "the runtime was killed (SIGKILL); this is
   usually the OOM killer" — because the operator cannot otherwise distinguish it from a clean
   finish, and the process that was killed cannot say anything at all.

**This does not cover the case measured on 2026-09-08.** No `bun`/`node` process for that session
survived, so the TUI itself was killed, not only its child — and a parent cannot report its own
SIGKILL. Fixing (2) covers the child-killed case and leaves the parent-killed one to the
`.motoko/exit/` manifest, whose absence a *later* session could notice and report.

## How to tell, next time

Before restarting, in this order:

1. `cat /sys/fs/cgroup/memory.events` — a rise in `oom_kill` since the last reading is the answer.
2. `ls .motoko/exit/ | grep <session_ms>` — no manifest means the clean-exit path never ran.
3. `tail -1 .motoko/logfile/session_*.jsonl` — a last event of `native_tool_calls` or
   `provider_call_prepared` means it died waiting on something external, not in the loop.
4. `herdr agent list` — an unreaped delegate still holding its pane corroborates an unclean exit.

## Non-goals

- Do not treat a truncated log as proof of an OOM kill. Closing a pane produces the same
  signature, and on 2026-09-08 two of the three truncations were pane closes.
- Do not add a memory watchdog inside Motoko. The process that is about to be killed is the wrong
  place to notice it, and a limit is the operator's to set.
