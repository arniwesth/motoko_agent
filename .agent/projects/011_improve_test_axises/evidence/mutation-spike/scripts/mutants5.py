#!/usr/bin/env python3
"""SPIKE ONLY — part 5: the two reviewers' mutants (REVIEW-001, both). Never merges."""
import sys
S = "src/core/session.ail"; SM = "src/core/step_machine.ail"
RETRY = "let retry_event = StreamErrorRetry("
MUTANTS = {
  # Fable 1 / Astra 1: a provider failure reported under another failure reason
  "R1": (S, None, "step_idx, TermProviderFailure, e.message, started_at_ms, capt.trace",
                  "step_idx, TermMaxSteps, e.message, started_at_ms, capt.trace"),
  # Fable 2: a suspension reported as an internal failure
  "R2": (S, None, "st.step_idx, TermMaxSteps, info.message, started_at_ms",
                  "st.step_idx, TermInternalFailure, info.message, started_at_ms"),
  # Fable 3 / Astra 2: a retry that costs two steps
  "R3": (S, RETRY, "step_idx: step_idx + 1,", "step_idx: step_idx + 2,"),
  # Fable 4: the failure finalize drops the capture read's successor
  "R4": (S, None, "c2_finalize(st.provider, capt.world, session_id, model, st.totals, step_idx, TermProviderFailure",
                  "c2_finalize(st.provider, stepped.world, session_id, model, st.totals, step_idx, TermProviderFailure"),
  # Fable's added kill for the calls rule: the step machine allows one call past the budget
  "R5": (SM, "func call_model_or_fail(", "if pol.step_budget > 0 && s.step_idx >= pol.step_budget",
                   "if pol.step_budget > 0 && s.step_idx > pol.step_budget"),
  # Astra 3 (executed by Astra): the retry keeps the successor's log and rewinds its generator
  "R6": (S, RETRY, "world_state: capt.world,", "world_state: { capt.world | gen: st.world_state.gen },"),
}
if len(sys.argv) == 3 and sys.argv[1] == "apply" and sys.argv[2] in MUTANTS:
    f, anchor, old, new = MUTANTS[sys.argv[2]]
    s = open(f, encoding="utf-8").read()
    start = 0
    if anchor:
        if s.count(anchor) != 1: sys.exit(f"{sys.argv[2]}: anchor occurs {s.count(anchor)} times")
        start = s.index(anchor)
        if s[start:start + 6000].count(old) < 1: sys.exit(f"{sys.argv[2]}: old text not in the window")
        pos = start + s[start:start + 6000].index(old)
    else:
        if s.count(old) != 1: sys.exit(f"{sys.argv[2]}: old text occurs {s.count(old)} times, expected 1")
        pos = s.index(old)
    open(f, "w", encoding="utf-8").write(s[:pos] + new + s[pos + len(old):])
    print(f"{sys.argv[2]} applied at {f}:{s.count(chr(10), 0, pos) + 1}")
else:
    sys.exit("usage: mutants5.py apply R1..R6")
