# Finding C upstream: do not file — capture the missing evidence instead

Date: 2026-09-08. Decides the question left open by
[`HANDOFF-2026-09-03`](HANDOFF-2026-09-03-patch-state-and-what-remains.md):143 ("No upstream
filings, decided 2026-09-02 and not revisited").

**Finding C was never covered by that decision.** The 09-02 decision names "both candidates,
worked around in `scripts/dagr-pane.sh`". Finding C arose on 09-03 and is a different candidate
that inherited the posture rather than being judged under it. It is judged here.

## Decision

**Do not file. Instrument the refusal path so the next occurrence files itself.**

## What the tracker says

`herdrdev/herdr` is public, active (314 open issues, pushed today), and takes reports of this kind.
Searched for finding C's symptom:

| issue | what it is | bearing on ours |
|---|---|---|
| **#3397** | `agent prompt`/`send-keys` fail `agent_not_ready` on a pane `agent start` had just started — **and step 5 reports our exact string, *"is not an active named agent"*, on 0.8.2** | closest neighbour; **closed as duplicate** |
| **#3186** | what #3397 was deduped into: pi detection lost on **Windows** after a pi 0.84.3 path change | mechanism generalises; the fix does not |
| **#3207** | the fix for #3186 | Windows pi bundled-CLI path only |
| **#3696** | `foreground_cwd` returns a descendant's directory, not the foreground group leader's | independent evidence the foreground layer was shaky in this era |
| **#3413** | a *failed* `agent start` still binds the name | the exact inverse of ours |

So the symptom is known to the maintainers, and **the mechanism is now legible**: `agent prompt`
validates by identifying the **pane foreground process**. When that identification fails, an agent
herdr genuinely started is refused as not-named. #3186's first symptom is detection dropping
"during a burst of tool subprocess activity" — which is precisely what a claude spawning
subprocesses looks like.

That is a real hypothesis for finding C and it is better than the "lost name binding" phrasing in
[`MEASUREMENTS-2026-09-07`](MEASUREMENTS-2026-09-07-prompt-delivery.md): the binding is probably
intact, and the *foreground check in front of it* is what fails.

**No open or closed issue covers Linux + claude.** This is a genuine gap, not a duplicate.

## Why not file it anyway

1. **Not reproducible.** 2/2 on 2026-09-01, never since — including through the whole 09-07
   measurement session that went looking near it.
2. **Measured on 0.8.2; stable is 0.9.0**, whose notes rework `agent prompt` submission (#3506).
   A 0.8.2-only report into a 314-issue tracker is the kind that is rightly deprioritised.
3. **We lack the one diagnostic the maintainer asks for.** #3397's closing comment: *"reply with
   `herdr pane process-info --pane <pane-id>`"*. We never captured it, and cannot retroactively.

The 09-02 criterion ("worked around locally, not blocking") is now genuinely met for finding C by
the bounded retry — though *unproven*, since finding C has never been reproduced to retry against.

## What to do instead

`herdr pane process-info --pane <id>` **exists on 0.8.2** (verified). The extension is the thing
that sees the refusal, and by `DESIGN-prompt-retry` §5 it now sees it three times before giving up.

So: **on the final `agent_not_ready`, capture `pane process-info` into the run file before
`pane close`.** That converts an unfilable intermittent into a report that arrives with the
maintainer's requested evidence already attached. It is the same shape as everything else in this
project — make the failure visible where it happens rather than reason about it later.

Not scoped here. Note that it must land *before* the `pane close` in the failure branch, which is
the ordering constraint that makes it a real change rather than a logging line.

## If it recurs after a 0.9.0 upgrade

File it then, against 0.9.0, with `process-info` attached, citing #3397 as the same symptom on a
different platform and kind, and #3186/#3207 as the Windows-only fix that did not reach this case.
