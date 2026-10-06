#!/usr/bin/env python3
"""SPIKE ONLY — part 4: two extra rows for the outcome rule. Never merges."""
import sys
S = "src/core/session.ail"
MUTANTS = {
  # known bad for the EXISTING outcome rule (part 2's K2): failure finalize returns Ok
  "K2": ("emissions_after_call, Err(e), c2_final_state(st))", "emissions_after_call, Ok(st.msgs), c2_final_state(st))"),
  # the mirror of M3: the success finalize reports a failure reason
  "M3m": ('st.step_idx, TermSuccess, "", started_at_ms, published.trace, st.emissions, Ok(st.msgs)',
          'st.step_idx, TermProviderFailure, "", started_at_ms, published.trace, st.emissions, Ok(st.msgs)'),
}
if len(sys.argv) == 3 and sys.argv[1] == "apply" and sys.argv[2] in MUTANTS:
    old, new = MUTANTS[sys.argv[2]]
    s = open(S, encoding="utf-8").read()
    if s.count(old) != 1:
        sys.exit(f"{sys.argv[2]}: old text occurs {s.count(old)} times, expected 1")
    open(S, "w", encoding="utf-8").write(s.replace(old, new))
    print(f"{sys.argv[2]} applied at {S}:{s[:s.index(old)].count(chr(10)) + 1}")
else:
    sys.exit("usage: mutants4.py apply K2|M3m")
