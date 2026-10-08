#!/usr/bin/env python3
"""SPIKE ONLY — part 4 prototype. Never merges.

Applies two rule changes to src/core/dst_invariants.ail, each one exact-once replacement:
  R1 outcome agreement: outcome is Ok if and only if the summary finished "stop".
  R2 bounded progress: the DRIVER's own provider-call step numbers must not repeat.
Both reuse existing Violation constructors, which the real change should not (plan, part 4).
"""
import sys
F = "src/core/dst_invariants.ail"
EDITS = [
  ("import",
   "  StreamDelta,\n  -- ADR-003 D1's journal class",
   "  StreamDelta, ProviderCallPrepared,\n  -- ADR-003 D1's journal class"),
  ("R2 helper + call",
   "export pure func bounded_progress_findings(x: ExecutionUnderTest) -> [Violation] {",
   """-- SPIKE PROTOTYPE (never merges). The step numbers the DRIVER put on its own
-- provider-call records in the returned trace. `provider_steps` above reads the
-- RECORDER's count of provider calls, which advances whatever the driver does.
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
  ("R2 use",
   "  d ++ r ++ repeated_steps(steps, steps, [])",
   """  let driver_steps = spike_prepared_steps(trace.records);
  d ++ r ++ repeated_steps(steps, steps, []) ++ repeated_steps(driver_steps, driver_steps, [])"""),
  ("R1",
   "          agree ++ done_agreement(rs, fin, err)",
   """          -- SPIKE PROTOTYPE (never merges): Ok if and only if the summary finished "stop".
          let fin_agree = match run.outcome {
            Ok(_) => if fin == "stop" then [] else [OutcomeSummaryDisagree("ok", "finish_reason='${fin}'")],
            Err(_) => if fin == "stop" then [OutcomeSummaryDisagree("err", "finish_reason='stop'")] else []
          };
          agree ++ fin_agree ++ done_agreement(rs, fin, err)"""),
]
s = open(F, encoding="utf-8").read()
for name, old, new in EDITS:
    if s.count(old) != 1:
        sys.exit(f"{name}: old text occurs {s.count(old)} times, expected 1")
    s = s.replace(old, new)
open(F, "w", encoding="utf-8").write(s)
print("prototype applied:", ", ".join(n for n, _, _ in EDITS))
