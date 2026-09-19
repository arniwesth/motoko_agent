# An exhausted empty-stop guard finalizes indistinguishably from success

## Status

open — filed 2026-09-19 from the PLAN-004 v2 P2.3 delegation run (graph
`.dagr/run-w3-p1-1789663745618.json`).

## Description

Three long delegate sessions ended with no answer file written. The orchestrator recorded two of
them as `lost` with the reason *"herdr reports agent_not_found for pane … and no answer file was
written"* and the third as *"empty-stop at ~3.6h"*. All three diagnoses were wrong about the
mechanism, and one was wrong about the failure class entirely.

`empty_stop_guard` was loaded in every session and **worked as designed in every session**: it fired
its full budget of 2, then correctly returned `NoDecision`. The defect is not that the guard misses
these — it is that **once the budget is spent, the resulting finalize is byte-identical to a healthy
completion in every artifact an external observer can read.**

The session journal records:

```json
{"type":"run_finished", "finish_reason":"stop", "cumulative":{...}}
{"type":"exit", "reason":"host_exit", "pending_tool_calls":[]}
```

A successful run emits the same two lines. There is no field distinguishing "the model stopped
because it was finished" from "the model returned its third consecutive blank response and the guard
had no budget left to object". The orchestrator therefore has nothing to key on, falls back to
herdr's `agent_not_found` — which only means the pane returned to a bare shell — and files the
attempt as infrastructure loss. Real model-behaviour failures are being recorded as transport
failures.

A core floor for exactly this was specified in
[`silent-empty-stop-finalize.md`](silent-empty-stop-finalize.md) §2 — *"never finalize an empty stop
silently … emit a distinct ledger event"* — and it **was** implemented: `session.ail:3378` builds an
`EmptyStopFinalize` record and appends it to the returned trace under `trim(info.output) == ""`.
It does not reach `journal.jsonl`. Grepping the two affected journals for
`EmptyStopFinalize|empty_stop_finalize` returns **0**. The floor exists in the trace and phase
vocabulary; it is absent from the artifact anything outside the process actually reads.

## Evidence

Journals under `.motoko/sessions/`. Guard firings counted by `[motoko-empty-stop-guard]` markers on
`role: "user"` messages.

| attempt | session | steps | guard fired | ending |
|---|---|---|---|---|
| P2.2·a7 | `1789676556624-c39de25f45c92c86` | 134 | step 29, step 38 | step 134 assistant `len=0 tc=0` → `run_finished finish_reason=stop` |
| P2.2·a11 | `1789711644363-7eacb1df1cc8f3eb` | 67 | step 37, step 66 | step 67 assistant `len=0 tc=0` → `run_finished finish_reason=stop` |
| P2.3·a5 | `1789720567530-2cdf8b839e0339d1` | 685 | step 30, step 556 | step 685 assistant `len=0 **tc=1**`, `exit`, **no `run_finished`** |

Answer files `answer-mot-dlg-1789676556084.md`, `-1789711643777.md`, `-1789720567140.md`: all three
absent.

Two distinct failures are hiding under one label:

**a7 and a11 — genuine silent empty-stop finalize.** Budget spent, then a blank stop that nothing
objects to. In a7 the gap is wide: the guard was exhausted at step 38 and the fatal blank stop came
at step 134, **96 steps later**, with no mechanism left to notice. a11's pane printed
`[answer-file] nothing published …: the run ended with an empty 'done'` — the host knew, and that
knowledge reached a terminal nobody was reading, not the journal.

**a5 — not an empty stop at all.** It ends on a tool call (`tc=1`), with
`provider_calls_started: 686` against `completed: 685`, an `exit` and **no `run_finished`**. The
process was terminated mid-flight after 3.6 h. The graph's `"empty-stop at ~3.6h"` is a guess, and
the wrong one; a5 never reached the finalize gate. Nothing in the journal labels an external kill
either, so the two failures are indistinguishable downstream — which is how they came to share a
diagnosis.

## Location

- `src/core/session.ail:3378` — `EmptyStopFinalize` built and `ledger_append`ed to the trace under
  `trim(info.output) == ""`. Correct, and invisible to the journal.
- `src/core/phase_vocab.ail:1000,1313` — `EmptyStopFinalizeInfo` / the `EmptyStopFinalize` variant.
- `src/core/dst_event_vocabulary.ail:109,178,238,420` — wire name `empty_stop_finalize`.
- `packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail` — `budget() = 2`;
  `decide_with_budget` returns `NoDecision` once `count_markers(ctx.history_slice) >= 2`.
- Journals: `.motoko/sessions/session_{1789676556624-c39de25f45c92c86,1789711644363-7eacb1df1cc8f3eb,1789720567530-2cdf8b839e0339d1}/journal.jsonl`.

## Fix

**1. Land the floor in the journal.** Whatever sink `journal.jsonl` is written from needs the
`EmptyStopFinalize` record, or `run_finished` needs a field carrying it — e.g.
`finish_reason: "empty_stop"` or `empty_stop: true` alongside the existing `"stop"`. One field makes
every downstream consumer able to tell the two apart. Without it the floor protects an audience of
nobody.

**2. Distinguish external termination.** A journal ending in `exit` with no `run_finished`, and
`provider_calls_started > provider_calls_completed`, is a kill, not a stop. Either emit a terminal
record on that path or let consumers key on the asymmetry — but it should not require reading
cumulative counters to work out that a session was killed.

**3. Reconsider a flat budget of 2 for long sessions.** It is sized for a model that stalls twice
early. Over 134 and 685 steps it is spent long before it is needed — 96 steps early in a7 — and it
never renews. A budget that decays with distance since the last firing, or simply refreshes after N
productive steps, would still bound the loop while being present when the session actually ends.

**4. The guard's predicate is blankness, not deliverable.** `is_blank(candidate)` cannot see that a
delegate whose contract is *"write your answer to `answer-<handle>.md`, then stop"* never wrote the
file. A non-blank sign-off with no answer file finalizes clean and looks like success. That is a
separate gap from the three above and probably belongs in the delegate harness rather than this
guard, but it is the same silence.

## What it cost here

Six delegate-hours across a7 (52 min), a11 (76 min) and a5 (3.6 h), each re-issued from scratch
because nothing identified the failure as a model stop rather than a dead pane. The re-issues
themselves were sound; the misdiagnosis meant the *briefs* were never shortened, so a11 was re-sent
the same oversized brief that had just failed. The brief was only split after a human read the pane
scrollback by hand.

## Not investigated

- Whether `ledger_emit` reaches any consumer other than the returned trace, or whether the journal
  writer simply subscribes to a different stream.
- Why the model returned blank responses at all in a7/a11 — context state at those steps was not
  examined. The resolved [`silent-empty-stop-finalize.md`](silent-empty-stop-finalize.md) traced its
  own case to gutted context from over-compaction; whether that applies here is unchecked.
- What killed a5 at step 685. `exit` carries `reason: "host_exit"` in the sessions that have it;
  a5's terminal rows were not examined for a cause.
- Whether `count_markers` sees a complete history under `compaction_ai` / `compaction_structural`,
  both loaded here. If compaction elides marker-bearing messages the budget would silently *widen*,
  not narrow, so it does not explain these cases — but it makes the budget non-deterministic.
