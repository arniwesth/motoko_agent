Written 2026-10-07T13:13:43Z, after the unmutated gate ran clean with both new controls
(patch sha256 e2f96965bfae7e84) and before either mutant was applied.

The two mutants are acceptance's blind rows B2 and B3, text taken from
evidence/judge-recoveries/acceptance-ce9cb247/blind/blind-mutants.tsv. At acceptance both left
the gate at exit 0 with all sixteen members clean.

B2 (tool_phase.ail:615, the fold recurses with `world`):
  - gate exit 1;
  - CONTROL tool-run-without-approval tool-dispatches-unbalanced RED, with 2 dispatch records in
    the trace and fewer than 2 tool interactions in the log (I expect 0: the turn is handed the
    world it started with);
  - the control's "branch was walked" line fails as well, on the log count and the undrained queue;
  - all sixteen members clean, and the verifier-rejection control clean.
  Not sure: whether request-ordinals-not-contiguous is red on that control too. The world handed
  back carries the ordinal from before the batch, so I think it is, but D9 says it does not see a
  successor dropped before its witness.

B3 (session.ail:2985, c2_dp7_rejected_state keeps step_idx):
  - gate exit 1;
  - CONTROL verifier-rejection steps-not-contiguous RED, prepared steps starting 0, 0;
  - the invariant set on that control carries driver-step-repeated;
  - all sixteen members clean, and the tool-run-without-approval control clean.
  Not sure: how the run ends. The step never advances, so it cannot end on its step budget; it
  ends when the two scripted answers run out, in whatever way an empty script ends a run. If it
  does not end, that is a hang and not a kill by the named rule, and I will say so.

A kill is only the named rule going red on the named control.

--- Addendum, 2026-10-07T13:26:30Z ---

B2 was run and read: as predicted on every sure line (rc 2 from make, the named rule RED with
trace=2 log=0, the branch line failing, 19 other rows clean). The line I was not sure of went the
other way: request-ordinals-not-contiguous stayed clean, as D9 says.

B3's first run did not end. The gate was killed by its 600 s timeout with no row printed. That is
the hang I named as possible, and it is not a kill. The control was changed: its script now ends
with a provider error that is not retried (patch sha256 2f01f253d13419aa), and the
unmutated gate was re-run clean with it. Written before B3's second run:

B3, second run:
  - gate exit 1 in about the time of a clean run;
  - CONTROL verifier-rejection steps-not-contiguous RED with prepared steps 0, 0, 0;
  - the set on that control carries driver-step-repeated;
  - provider-calls-exceed-budget RED on it as well (3 calls on a budget of 2);
  - the run ends Err on error, not on max_steps, so the control's first line fails;
  - all sixteen members and the other three controls clean.
