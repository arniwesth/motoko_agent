# The transcript sidecar prints `AILANG built undefined | Core Runtime vundefined` on every turn after the first

## Status

resolved — commit `PLAN-001 live-run fix 6: guard the transcript version banner`
on `arniwesth/013-dst-architecture-adr` (2026-09-06). `session-logger.ts` now
carries the same `if (event.ailangBuilt && event.brainVersion)` guard as
`ui.ts:2325`, with a deterministic jest case in `session-logger.test.ts`
("writes the version banner only for the session_start that carries versions")
that logs one versioned and one null `session_start` and asserts the transcript
holds exactly one banner and no `undefined`. The open question the Fix section
raises last — whether the per-turn re-emit should be its own event type — is NOT
answered here; it is a wire-schema change and belongs with the event vocabulary.

## Branch

`arniwesth/013-dst-architecture-adr` (noticed in the PLAN-001 live run transcript, 2026-09-05)

## Description

`session_start` is emitted once at runtime startup with `brainVersion` and `ailangBuilt`, and
again on every conversational turn without them (`null`). The screen renderer guards this; the
transcript writer does not.

## Evidence

`.motoko/logfile/session_2026-09-05T16-06-34-724Z.md`: the first banner reads
`AILANG built unknown | Core Runtime v0.2.0 | TUI v0.1.0`; the following 15 read
`AILANG built undefined | Core Runtime vundefined | TUI v0.1.0`. The matching `.jsonl` has 16
`session_start` events, 15 with `"brainVersion":null,"ailangBuilt":null`.

## Location

- `src/tui/src/session-logger.ts:275` — unguarded `writeTranscriptLine` of the banner.
- `src/tui/src/ui.ts:2319`–`2326` — the guard and the comment explaining exactly this case.

## Fix

Apply the same `if (event.ailangBuilt && event.brainVersion)` guard in the session logger, or
write a one-line turn marker instead. Also worth asking whether the per-turn re-emit should be a
different event type; `ui.ts:2319` already calls it a "conversational re-emit", which is a name
for a thing that wants its own tag.
