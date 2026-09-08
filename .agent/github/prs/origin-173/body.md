---
repo: arniwesth/motoko_agent
pr: 173
branch: arniwesth/mot-115-verify-the-herdr-agent-state-reporter-against-a-running
ticket: MOT-115
title: "MOT-115: verify the herdr agent-state reporter against a running herdr server"
---

## Summary

The herdr agent-state reporter was written, unit-tested and shipped without ever meeting a running
herdr server — ADR-001 (project 020) said so in its own *"what is asserted rather than measured"*
section. This takes those measurements inside `agent_confined` against herdr v0.8.2, replaces that
section with the evidence, and fixes the one defect the live server exposed.

That defect is worth reading before the rest: herdr accepts a report only when `--seq` is **strictly
greater** than the last it accepted for that `(pane, source)` pair, and the high-water mark survives
both `release-agent` and the exit of the process that set it. The counter started at 0 in every
process, so the **second** Motoko started in a given pane was invisible to herdr for its entire run —
silently, because herdr rejects a stale report on the server rather than telling the caller. No unit
test could have found it.

## Changes

- `src/tui/src/herdr-agent-state.ts` — `initHerdrReporter` seeds the sequence counter from
  `Date.now()` before the first report, with a `__setClockForTests` seam. A run cannot emit more
  reports than it lasts milliseconds, so each process outranks the last. The `buildReportArgs`
  comment is corrected: herdr requires strictly greater, not merely not-lower.
- `src/tui/src/herdr-agent-state.test.ts` — three new cases (11 → 14): the seed is applied at init,
  a restart in the same pane outranks the run before it, and the value is sent as a plain integer.
- `ADR-001-herdr-agent-integration.md` — the asserted-not-measured section is replaced by M1–M9;
  a Corrections section (C1–C4) records what the measurements falsified, fixed in place; the Linear
  identifiers are recorded.

No new reporting call sites (D2 intact), no change to the `error` → `blocked` mapping (D3 approved),
and the reporter stays non-blocking, non-retrying and unsupervised (D4).

## Governing docs

- `.agent/projects/020_herdr_agent_integration/ADR-001-herdr-agent-integration.md`
- `.agent/projects/020_herdr_agent_integration/HANDOFF-verify-herdr-agent-state.md`
- Linear MOT-115 (parent), MOT-116, MOT-117, MOT-118, MOT-119

## Predicted outcome

A `motoko` row is visible in `herdr agent list` beside the delegate panes, for every Motoko started
in a pane — not only the first. Checked by starting Motoko twice in one pane and seeing a row both
times; before this change the second produced no row at all.

**One decision is deliberately not taken here.** D3's second path — the runtime-exit recovery — was
measured at **92 ms**, and what replaces the blocked row renders as `done`, so a crashed run
presents as a finished one. That kills "accept it", and with `agent wait --until idle` measured
working it also kills sticky-blocked (an orchestrator would hang forever on a Motoko that crashed
once and is sitting ready at a prompt). The only survivor is a change to Motoko's recovery
semantics, which belongs to whoever owns the TUI's error handling. Escalated as **MOT-117**.

## Test evidence

Measured 2026-08-22 in `agent_confined` (image `ab3ed0fab4f6`), pane `w1:p5`, herdr v0.8.2, five
runs of `herdr pane run w1:p5 'make run'`. Full detail in the ADR's M1–M9.

- **M1** row appears: `herdr agent list` → `motoko` on `w1:p5`, `agent_status: idle`, beside
  `claude` on `w1:p1`.
- **M2** lifecycle authority granted: `agent explain w1:p5` → `agent_explain_unavailable — "does not
  have a detected agent label"`, while the same command on the Claude pane returns
  `manifest: bundled 2026.08.13.1 / rule: osc_title_working / evidence: …`. `pane process-info`
  shows `make`, `sh`, `bun` — nothing herdr can detect — yet `agent get` returns a live state.
- **M3** a real run: `idle` 17:23:14 → `working` 17:23:36 → `done` 17:24:18, in step with Motoko's
  own status line; the `thinking`/`tools_wait`/`tools_run` churn stays one `working` row.
- **M5** release fires on `ctrl+c` (~193 ms), on a clean runtime exit, and on `SIGTERM` (80 ms).
  `SIGKILL` leaves a ghost row, unchanged 60 s later — the ADR inferred this; it is now measured.
- **M6** the seq defect, and the fix verified against the server: run 3 appeared in a pane whose
  high-water was an epoch-millisecond value left by the probes.
- **M7** `HERDR_BIN_PATH=/usr/local/bin/herdr` read from `/proc/<bun pid>/environ` through
  `make run` → `sh -c` → `run-agent.sh` → `exec bun`.
- **M8** D3 timed: in-band error → `blocked` 244 ms behind the transition and it stays; runtime-exit
  recovery → leaves `blocked` after 92 ms.
- **M9** primitives: `agent get`/`read`/`wait` work against the pane id; `agent prompt` and
  `agent send-keys` refuse a reported agent (`not an active named agent`); the reported label is not
  an addressable target.

```
bun run build                              # tsc, clean
jest --testPathPattern=herdr-agent-state   # 14 passed, 14 total (was 11)
jest --testPathPattern='src/.*\.test\.ts'  # 223 passed, 0 failed (was 220)
                                           # 5 suites still fail TO LOAD on the pre-existing
                                           # bun-jest/depd incompatibility via express; none of
                                           # them import anything this change touches
```
