# A killed Motoko process exits silently, and nothing on screen or on disk says it was killed

## Status

open

## Branch

`arniwesth/013-plan003-and-herdr` (observed 2026-09-08 during the PLAN-003 P1/P3 live run, and again
2026-09-12 during P3 Part 6 — at 24 GiB)

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

## Evidence (2026-09-12) — the same kill at three times the ceiling

The 8g → 24g patch (`.devcontainer/agent_confined/docker-compose.yml`) was live, and the ceiling was
reached anyway.

**The session ended mid tool-phase, again on `DelegateCheck`.**
`.motoko/logfile/session_2026-09-12T15-34-13-013Z.jsonl` (session `1789227279088`, pane `w1:p5`)
ends on `native_tool_calls` for step 650 — `DelegateCheck` of `mot-dlg-1789238512848` (P3 Part 6),
`msg_count` 1315, `estimated_input_tokens` 230784, provider-reported input 356793, no compaction
applied in 3h16m (`elapsed: 11777s`). No `native_tool_results`, `run_summary`, `error` or `done`. The
footer froze at `last update: 40s ago | at: 18:50:01.021`, putting the death at about **18:50:41**,
and the pane went straight back to its shell prompt with nothing printed. No `.motoko/exit/`
manifest for the session.

**The kernel killed something, once.** Read at 18:58:

```
memory.max   25769803776   (24 GiB)
memory.peak  25769803776   (the ceiling, exactly)
memory.swap.max 0          (no swap inside the cgroup: reaching max is a kill)
memory.events: max 180872, oom 4, oom_kill 1
```

The container started 15:26, so this `oom_kill 1` is this incident's alone.

**What was running when it died.** The delegate in `w1:pH` ran `make dst DST_JOBS=4` from
**18:44:38 to 18:56:43** (725 s, `.ailang/dst-last.log` mtime minus the sweep's own wall time) — the
kill is in the middle of it. Around it, the delegate's headless probes show the pressure: the one
started 18:50:12 took **76 s** to print `Runtime is reasoning...`, the ones at 18:51:32 and 18:51:39
took about 4 s. Residents at the time: this orchestrator (bun TUI + AILANG child), a second idle
Motoko in `w1:pB` (its AILANG child `VmHWM` 754 MiB after 19 steps), the delegate `claude` (~420 MiB),
an idle `codex` (~120 MiB), herdr.

**The victim was not a sweep job.** The sweep ran to its summary with no `Killed`/137 row; its three
reds are `depth_canary` (known) and two herdr targets with non-memory causes the delegate reproduced.
The kernel kills the largest task, so at 18:50:41 the largest task in the container was a process of
this Motoko — most plausibly its AILANG child, 650 uncompacted steps in. Not proven: `dmesg` and
`/var/log/journal` are empty inside the container, so the victim's name and RSS are not recorded.

**What is still NOT evidenced.** Whether the memory was the orchestrator's growth, the sweep's, or
both. 2026-09-08 died at step 215 against 8 GiB; 2026-09-12 at step 650 against 24 GiB — consistent
with a runtime whose footprint grows with session length, and equally with a heavy delegate workload
tipping over a large long-lived process. The next occurrence needs an RSS sampler running outside
Motoko (per-process `ps -eo pid,rss,etime,args` every ~15 s) and a `make dst` peak measured alone.

## Location

- `src/tui/src/runtime-process.ts:620` (before the fix, `:679` by 2026-09-12) —
  `this.proc.on("exit", () => { ... })`. Node's `exit`
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

2. **Report a death as a death.** *Implemented 2026-09-12:* the exit hook takes `(code, signal)`;
   when the child dies on a signal or a non-zero code and its last wire event was not `done`,
   `error` or `session_resume_refused` (and the host did not `kill()` it), it emits
   `{type:"error"}` naming the cause (`describeUnexplainedExit`, SIGKILL → "usually the OOM killer")
   before `onExit()`. The TTY renders it and recovers into awaiting a task; the headless loggers
   exit 1 and the JSONL log records the `error`. Test: `runtime-process.unexplained-exit.test.ts`.
   The original wording: `runtime-process.ts:620` should take `(code, signal)` and, when
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

0. Since the 2026-09-12 fix: an `[error] The AILANG runtime was killed (SIGKILL) …` line (screen or
   session JSONL) means the child was killed and the TUI survived. No such line and no TUI at all
   means the TUI itself was killed — the fix cannot speak for its own death.
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
