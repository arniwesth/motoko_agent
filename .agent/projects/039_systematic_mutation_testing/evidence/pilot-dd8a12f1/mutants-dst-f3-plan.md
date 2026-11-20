# F3: the two control-only mutants, m09 and m14, under a full `make dst`

Added 2026-11-20 at the operator's request, after F2. F2 ran under `make dst` every mutant at a site
another target reaches, except two. m09 and m14 are reached only by `corpus_judge`'s own controls
(tier 2), so the pilot stopped them at tier 2 (deviation 2), and F1 did not probe them. With F3,
every drawn mutant that any `make dst` run reaches will have run under a full `make dst`, so the
write-up can give one suite-wide verdict per mutant.

**What runs.** The drawn mutants `m09` and `m14`, in draw order, one at a time, by
`scripts/run_gate.sh dst` (unchanged since the pilot), in a scratch worktree recreated for F3 as a
detached worktree at `dd8a12f1` (the F2 scratch was removed on 2026-11-20). Nothing else runs.

**Readings.** As F2 (`mutants-dst-plan.md`):

- *Ordinary*: `scripts/score_dst.py` (unchanged; self-tested again before F3). A target newly red
  against C-base is a KILL. F2's m02 and m03 failed exactly C-base's set on 2026-11-19, so C-base
  still holds on this machine and toolchain (AILANG v0.60.4, `563c6c9`).
- *Rule*: each newly red target's output is read by hand. It counts only if a failing check is about
  the broken behaviour. A count pin kept for something else, a vacuity guard or a runtime crash is
  recorded and not counted.

**One reading fixed here, before any F3 sweep.** At tier 1 the brief counted `corpus_judge`'s
`JUDGE` rows only, because tier 1 graded the bank. At the suite level the question is whether any
check in `make dst` fails on the broken behaviour, and `make dst` runs `corpus_judge` with its
controls. So under F3's rule reading a `CONTROL` row of `corpus_judge` counts as a kill when it is red
on a rule about the broken behaviour (for m14, ADR-003 D4's `journal-fold-disagrees`: the journal's
fold must reproduce the final history). A control red on a vacuity guard or an unrelated rule does
not count. The pilot's tier-1 verdict for m14 ("not killed: no member reaches it") is unchanged; this
reading applies to the suite-wide verdict only.

**Predictions**, written before any F3 sweep:

| mutant | the edit | what reaches it | predicted | by | confidence |
|---|---|---|---|---|---|
| m09 | `tool_arguments_invalid` not emitted to the wire; the returned trace keeps it (`tool_phase.ail:515`) | `corpus_judge`'s `invalid-request` control (tier 2), which reads only the trace and stayed green at tier 1; `ledger_parity_dst.ail`'s subject 10, "invalid", built from the same kind of `Limits` world, whose base row is `✓ ToolArgumentsInvalid: projected 1, returned 1` | killed | ledger_parity: `ToolArgumentsInvalid` projected 0, returned 1 | high |
| m14 | an injected user message is journaled but not added to the history (`session.ail:3052`) | `corpus_judge`'s `solver-feedback` control, red at tier 1 on `journal-fold-disagrees` | killed | corpus_judge: `CONTROL solver-feedback journal-fold-disagrees RED`, as at tier 1 | high |

m14's prediction is close to a replay of tier 1, because `make dst` runs `corpus_judge`. What the
sweep adds is whether any other target also notices it.

**Limits, known before running.** One sweep per mutant; no re-run unless a sweep is INCOMPLETE. The
recreated scratch starts without `.ailang/` caches, so its first sweep may take longer; wall time is
recorded, not compared.
