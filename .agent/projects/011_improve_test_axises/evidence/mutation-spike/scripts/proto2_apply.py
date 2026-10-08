#!/usr/bin/env python3
"""SPIKE ONLY — part 5 prototype (ADR-003 v0.2 draft). Never merges.

Two rule changes in src/core/dst_invariants.ail, exact-once replacements:
  D2' outcome agreement by reason: Ok iff the summary finished "stop"; Err(e) iff it finished
      with the reason e.code implies (three named codes, everything else "error").
  D3  the DRIVER's own provider-call step numbers must not repeat.
Both reuse existing Violation constructors, which the real change must not.
"""
import sys
F = "src/core/dst_invariants.ail"
EDITS = [
  ("import",
   "  StreamDelta,\n  -- ADR-003 D1's journal class",
   "  StreamDelta, ProviderCallPrepared,\n  -- ADR-003 D1's journal class"),
  ("D3 helper",
   "export pure func bounded_progress_findings(x: ExecutionUnderTest) -> [Violation] {",
   """-- SPIKE PROTOTYPE (never merges). The step numbers the DRIVER put on its own
-- provider-call records in the returned trace.
pure func spike_prepared_steps(rs: [LedgerRecord]) -> [int] {
  match rs {
    [] => [],
    r :: rest =>
      match r {
        WireRecord(e) =>
          match e {
            ProviderCallPrepared(i) => i.step :: spike_prepared_steps(rest),
            _ => spike_prepared_steps(rest)
          },
        _ => spike_prepared_steps(rest)
      }
  }
}

export pure func bounded_progress_findings(x: ExecutionUnderTest) -> [Violation] {"""),
  ("D3 use",
   "  d ++ r ++ repeated_steps(steps, steps, [])",
   """  let driver_steps = spike_prepared_steps(trace.records);
  d ++ r ++ repeated_steps(steps, steps, []) ++ repeated_steps(driver_steps, driver_steps, [])"""),
  ("D2' table",
   "export pure func outcome_agreement_findings(x: ExecutionUnderTest) -> [Violation] {",
   """-- SPIKE PROTOTYPE (never merges). The finish reason an Err outcome's code implies, stated
-- HERE and not imported from the driver: an oracle that asked the driver would agree with it.
pure func spike_expected_finish(code: string) -> string {
  if code == "StepBudgetExhausted" then "max_steps"
  else if code == "BudgetExceeded" then "cost_exhausted"
  else if code == "ContextExhausted" then "compaction_exhausted"
  else "error"
}

export pure func outcome_agreement_findings(x: ExecutionUnderTest) -> [Violation] {"""),
  ("D2' use",
   "          agree ++ done_agreement(rs, fin, err)",
   """          let fin_agree = match run.outcome {
            Ok(_) => if fin == "stop" then [] else [OutcomeSummaryDisagree("ok", "finish_reason='${fin}'")],
            Err(e) =>
              if fin == spike_expected_finish(e.code) then []
              else [OutcomeSummaryDisagree("err code='${e.code}'", "finish_reason='${fin}'")]
          };
          agree ++ fin_agree ++ done_agreement(rs, fin, err)"""),
]
s = open(F, encoding="utf-8").read()
for name, old, new in EDITS:
    if s.count(old) != 1:
        sys.exit(f"{name}: old text occurs {s.count(old)} times, expected 1")
    s = s.replace(old, new)
open(F, "w", encoding="utf-8").write(s)
print("prototype v2 applied:", ", ".join(n for n, _, _ in EDITS))
