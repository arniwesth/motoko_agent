# Max-steps termination is discriminated by an error-message string, not a code

## Status
resolved — PLAN-003 P1 Part 2 / ADR-003 D2 item 1, the commit titled
`ADR-003 D2: P1 Part 2 — StepBudgetExhausted code, delete the message discriminator`,
the child of `cbf50f3` on `arniwesth/013-plan-003-implement-adr-003`. Its own hash is
not written here because a commit cannot contain it; the hash is in that commit's
report and in the PLAN-003 dagr receipt for P1P2.

## Branch
Surfaced on arniwesth/mot-46-execute-wi-a16-and-wi-a9 (while executing WI-A9;
behaviour preserved, not fixed). Fixed on arniwesth/013-plan-003-implement-adr-003.

## Description

`step_machine.ail` emits **the same `Internal` error code for two structurally different failures**:

- `step_machine.ail:93` — the step budget is exhausted
  (`Fail({ code: "Internal", message: "v2 loop: step budget exhausted", retryable: false })`)
- `step_machine.ail:57` — approval was requested with no pending call
  (`Fail({ code: "Internal", message: "approval requested without pending call", retryable: false })`)

Because the code cannot tell them apart, the driver distinguishes them by **matching on the message
text**. WI-A9 moved this into one typed mapping (`session.ail`, `decision_fail_reason`) and preserved
the existing behaviour exactly rather than changing it:

```
else if code == "Internal" && message == "v2 loop: step budget exhausted" then TermMaxSteps
else TermInternalFailure
```

An edit to that string literal in `step_machine.ail` — a reword, a typo fix, adding the budget value
to the message — would **silently reclassify every max-steps run as an internal driver failure**.
The wire `finish_reason` would flip from `"max_steps"` to `"error"` on the most common non-success
termination path. Nothing would fail to compile and no test outside the one noted below would go red.

This is pre-existing: the same string match was in `c2_fail` before WI-A9, as an integer mapping
(`... then 4 else 5`). A9 made it typed and gave it a comment, which is why it is now visible enough
to file.

## Location

- `src/core/step_machine.ail:57` — `Internal` / "approval requested without pending call"
- `src/core/step_machine.ail:93` — `Internal` / "v2 loop: step budget exhausted"
- `src/core/session.ail` — `decision_fail_reason`, the string match and its comment
- `src/core/session.ail` — `test_decision_fail_reason_mapping` pins the current mapping, including
  the exact string, so a `step_machine` reword breaks this test rather than passing silently. That
  is a tripwire, not a fix: the test asserts the coupling exists, it does not remove it.

## Fix

Give the step-budget failure its own code, e.g.
`Fail({ code: "StepBudgetExhausted", message: ..., retryable: false })`, and match on the code:

```
else if code == "StepBudgetExhausted" then TermMaxSteps
```

**This is why it was not done inside WI-A9.** The code travels out of the driver in the returned
`AIError`, so changing it changes what callers see — `run_v2`'s `Result[[Message], AIError]`
consumers, the TUI's error handling, and anything matching on `"Internal"`. That is a compatibility
decision about an externally visible field, and ADR-001 D6.2 scopes A9 to the *internal* termination
reason and the wire `finish_reason` string, both of which A9 changed without touching `AIError`.

The plan should give this an explicit owner. It is small, but it needs someone who can decide
whether the `AIError` code is a compatibility surface.

## Non-goals

- Do not "fix" this by loosening the match to a prefix or substring test. That trades a silent
  reclassification for a different silent reclassification.
- Do not change the wire `finish_reason` strings. They are a project-007 compatibility surface and
  are pinned by the `RunSummary` goldens at `phase_vocab.ail:1105-1106`.

## Notes

Found as one of four sites in WI-A9 where **both alternatives type-check and the wrong one is
silent** — the measurement cluster 1 identified as the transferable finding and cluster 4 repeated at
a higher rate (27%). See
`.agent/projects/009_motoko_dst_execution/NOTE-cluster-4-execution-report-and-plan-corrections.md`
(C4 and the judgement section).

## Resolution

Fixed as specified under "Fix" above, in PLAN-003 P1 Part 2 (the commit named in
Status).
ADR-003 v6.1 D2 item 1 took the compatibility decision this issue said needed an owner:
the step-budget `Fail` gets its own code, and the `AIError` code on that path changes from
`Internal` to `StepBudgetExhausted`.

- `step_machine.ail:101` — `Fail({ code: "StepBudgetExhausted", message: "step budget
  exhausted", retryable: false })`. The message is documentation now, not a discriminator,
  so it also drops the `v2 loop: ` prefix that only ever existed to make it unique.
- `session.ail` — `decision_fail_reason(code)` matches the code and no longer takes a
  `message` parameter at all. The parameter is gone rather than ignored, so the coupling
  cannot come back by accident.
- `dst_fault_catalogue.ail` — `max_steps_discriminator_message()`, its test
  `test_max_steps_discriminator_is_shared`, and the header rationale for keeping the wire
  `code` unchanged are deleted. There is no shared literal left to keep in sync.
- `session.ail` — `test_decision_fail_reason_mapping` now asserts the code table, and its
  last row is what this issue was about: `decision_fail_reason("Internal")` is
  `TermInternalFailure` no matter what message accompanies it.

**Why the wire concern in "Fix" did not bite.** The `code` does reach the TUI as an `error`
ledger event (`ErrorEvent { code: e.code }`), but the TUI's `error` record type has no
`code` field at all (`src/tui/src/runtime-process.ts:96`), so nothing on the host reads it.
The wire `finish_reason` is unchanged — `finish_reason_wire(TermMaxSteps) == "max_steps"`
is still asserted (`session.ail`, `test_finish_reason_wire_table`) and the DST fixtures that
pin a max-steps run still report `max_steps`. The one observable change is
`run_summary.error`, which goes from `"v2 loop: step budget exhausted"` to `"step budget
exhausted"`; no golden, fixture or host assertion matches that string.

Both non-goals were honoured: the match was not loosened to a prefix or substring test, and
no wire `finish_reason` string changed.

The sibling issue `step-budget-exhaustion-starts-a-fresh-session.md` is NOT closed by this —
that one is the resume behaviour, and it is what the rest of PLAN-003 P1 is for.
