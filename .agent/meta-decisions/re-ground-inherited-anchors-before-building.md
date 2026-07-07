# Meta-decision: a "verified at HEAD" anchor in a durable doc decays — re-ground it before you build on it

Date: 2026-07-07
Status: Standing discipline
Scope: any session that authors a plan, ADR, or migration on top of an earlier NOTE/ADR/handoff.

## The principle

A file:line citation, a "verified at HEAD" claim, or a "this already shipped" assertion written into a
durable doc is a **point-in-time measurement, not a live fact**. It is true when written and rots
silently thereafter — across commits, across branches, across the gap between "designed" and "what
actually landed." **Before building a source-dense artifact (plan, migration, DST scenarios) on an
inherited anchor, re-run the observation against current source. Trust the source, not the sentence
that claims to have read it.** This holds even when the sentence explicitly says "verified" and names
a recent date — that stamp is the strongest false-confidence signal, not a substitute for re-checking.

## The recurring instance that motivates it

Every time this project has been burned, the shape is identical: a decision doc carried an anchor that
was accurate when written and stale when consumed.

- DST ADR-001 inherited compaction constants from a 5-day-old grounding while `compaction.ail` had
  moved; the review's highest-value finding was that the constants no longer existed. (→ `001_DST/ADR-002`
  re-grounded them.)
- A handoff and two NOTEs pointed at `runtime-process-env.test.ts` and an `autoForwardedEnvKeys()`
  refactor as landed, "verified 2026-07-06 HEAD." Neither existed on the branch — the refactor's
  commit was never cherry-picked over. A plan built on those anchors would have specified DST over a
  mechanism that never shipped. (→ `001_DST/ADR-003`, which found five such corrections.)
- A `--system-prompt` argv was documented as "delivered by value"; source showed it carried a
  *path*, with correctness resting on content materialization elsewhere. The imprecision would have
  produced a scenario asserting the wrong invariant.

None of these were sloppy authoring. Each anchor was correct at its keystroke. The failure is
structural: **long sessions and inherited docs accumulate anchors faster than they re-verify them, and
citation-dense artifacts compound the risk** — a plan is denser in anchors than the ADR it derives
from, so it inherits more decayed claims per page.

## The rule

1. **Re-observe, don't re-cite.** For every load-bearing anchor you're about to build on — a file:line,
   an "already landed," a "the manifest is derived from X" — run the cheap check that regenerates it:
   `grep` for the symbol, `ls` the file, read the function. Seconds each; they gate hours of misdirected
   work.
2. **A dated "verified" stamp lowers your guard — raise it instead.** Treat "verified at HEAD
   <recent date>" as *this was true once*, and re-check anyway. The more authoritative the phrasing,
   the more expensive the silent decay.
3. **Distrust "shipped/landed" across branch boundaries especially.** "Present in PR #N" ≠ "present on
   this branch." Confirm the commit is actually reachable from HEAD before treating a feature as built.
4. **When source contradicts the doc, the source wins and the contradiction is a finding.** Don't
   quietly reconcile — record what the doc claimed, what HEAD shows, and re-point downstream work. The
   correction is often more valuable than the artifact you set out to write.
5. **Fresh, source-heavy work belongs in a fresh session grounded against HEAD** (see
   `NOTE-plan-authoring-session-choice.md`): distance from the authoring session is what makes the
   re-grounding honest. The completeness test is deliberate — if you *can't* rebuild the artifact from
   the upstream docs alone, those docs have a gap worth finding now, cheaply.

## Relationship to the sibling discipline

This generalizes the same rot the "minimal repro before a defect claim" memory
(`verify-before-claiming-substrate-defects`) fights, one layer up: that one says *your own fresh
observation* can be a measurement artifact; this one says *an inherited written observation* decays the
same way. Both reduce to: a claim about code is only as current as the last time someone actually ran
it against source. Re-run it.
