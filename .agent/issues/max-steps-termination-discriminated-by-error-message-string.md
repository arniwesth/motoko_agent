# Max-steps termination is discriminated by an error-message string, not a code

## Status
open

## Branch
arniwesth/mot-46-execute-wi-a16-and-wi-a9 (surfaced while executing WI-A9; behaviour preserved, not fixed)

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
