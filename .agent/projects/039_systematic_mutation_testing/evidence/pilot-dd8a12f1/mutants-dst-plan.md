# F2: the eight mutants at F1's reached sites, under a full `make dst`

Added 2026-11-19 at the operator's request, after F1. F1 found that another `make dst` target runs 8
of the 11 sites no `corpus_judge` run walks. The mutants at those sites stopped at tier 2. Tier 3
ran only on mutants a bank member reaches, and tier 4 only on four survivors. So none of the eight
has run under the targets that reach it. F2 runs each one through a full `make dst`.

**What runs.** The drawn mutants themselves, not probes: `m02`, `m03`, `m12`, `m13`, `m17`, `m19`,
`m23`, `m30`, in draw order, one at a time in the scratch worktree at `dd8a12f1`, by
`scripts/run_gate.sh dst` (unchanged: it applies each one with `scripts/mutator.py` from its
candidate id in `draw-checked.tsv`, and hash-checks the tree before and after). Nothing else runs:
not the tier-3 targets on their own, and not m15, m08 or m26, which F1 found that nothing reaches.

**Readings.** Two, as at tier 4 in the pilot (README, deviation 1):

- *Ordinary*: `scripts/score_dst.py` (unchanged, self-tested before the pilot). A target newly
  red against C-base, the pilot's base sweep on the same tree and toolchain, is a KILL. F1's three
  unreached sweeps (X-m15, X-m08, X-m26) failed exactly C-base's set, `declared_vs_performed`, so
  C-base still holds on this machine.
- *Rule*: each newly red target's output is read by hand. It counts only if a failing check is about
  the broken behaviour. A red for another reason (a count pin kept for something else, a vacuity
  guard, a runtime crash) is recorded and not counted. If a red target's printed output does not
  show which check failed (`ledger_parity` and `world_framed_wire` print only `✗` rows and delete
  the rest), that is recorded, and any extra run to read it is logged in `sequence.log` before it
  runs.

**Predictions**, written before any F2 sweep, from each edit and a reading of what the targets F1
lists exercise:

| mutant | the edit | F1's reaching targets | predicted | by | confidence |
|---|---|---|---|---|---|
| m02 | the intercept arm journals its messages with `replace = true` | discovery, driver_plus_compose, smoke_driver, smoke_parity, strict_replay | not killed | - | medium: m22's twin was caught only by `corpus_judge`'s journal fold, and none of these targets is known to fold the journal |
| m03 | `AllowAfterTimeout` means deny | smoke_driver, smoke_parity | killed | smoke_driver (`smoke_v2_pending_full_loop`) | medium |
| m12 | the delegated tool's event is not emitted to the wire; the returned trace keeps it | ledger_parity, world_framed_wire | killed | ledger_parity (wire against trace) | high |
| m13 | a policy-denied call's denial message is dropped; its event is kept | compaction_dst, journal_resume, smoke_driver, smoke_parity, terminal_trace, world_state | killed | smoke_driver or journal_resume | low |
| m17 | the await-wake state keeps the pre-step world | driver_plus_herdr, herdr_graded, park_resume | killed | park_resume or herdr_graded | low |
| m19 | a policy-denied call's event is not emitted to the wire; the returned trace keeps it | as m13; F1's sweep also turned ledger_parity red | killed | ledger_parity (wire against trace) | high |
| m23 | a wake reply with `OperatorInput`, `HostError` or `Aborted` is dropped | park_resume | killed | park_resume (`resume_aborted`) | medium |
| m30 | the wake match's `&&` becomes `||` | driver_plus_herdr, herdr_graded, park_resume | killed | park_resume (`resume_dropped`: a mismatched reply) | medium |

**Limits, known before running.** One mutant per site and one sweep per mutant; no re-runs unless a
sweep is INCOMPLETE. `check_core` and `stream_parity`, two of the six tier-3 targets, are judged
here only as far as `make dst` runs them. A kill under F2 says a target in the suite notices the
mutant. It does not change the pilot's verdicts, which are defined on `corpus_judge`'s reach. It
adds a column beside them.
