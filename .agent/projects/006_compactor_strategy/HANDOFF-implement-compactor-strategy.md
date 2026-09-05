# Handoff: implement the compactor-strategy refinement

Date: 2026-07-10 (written by the session that authored `PLAN-compactor-strategy.md`, grounded it
against the code-graph, and hardened it through two review iterations).
Audience: a fresh implementer session. **The plan is the spec**: `PLAN-compactor-strategy.md` in this
directory. This handoff is intentionally narrow — it carries only the residual context the plan
compresses: current state, the discipline, and the traps ranked by how much they cost if you miss
them. Do not re-derive the design from the issue; the plan already did that and the review already
found the sharp edges.

## Why this work exists (one paragraph)

The affine-calibration fix on the previous branch made context measurement accurate, which exposed
three *strategy* defects **within the deliberately-ephemeral compaction model** (send-only payload;
full history retained — `design_docs/planned/m-motoko-conversation-compaction.md:52`): the structural
ladder over-escalates to emergency `keep_last=3` and guts the sent window to ~5% of the limit; the AI
compactor summarizes ~1 turn for ~0% relief every step; and the status tool conflates the
uncompacted-pending window with the last-sent window so `114%`-vs-`10%` reads as self-contradictory.
Normative issue: `../../issues/ephemeral-compaction-and-ai-noop-thrash.md`. This is PLAN-level
refinement of an extension-resident strategy (004 `ADR-001` D9), **not** an ADR.

## Current state

- Branch: `arniwesth/mot-36-compactor-strategy-refinement`. HEAD: `077cf8f`.
- **Commit the plan first.** `PLAN-compactor-strategy.md` has **uncommitted** review-hardening edits
  (~216/95 lines: the §2.2 base-check, §2.3 exhaustion rewrite, §3.1 symmetric pairing, §3.3 `gap>0`
  guard, rate-limit downgrade). Commit it docs-only before touching source, so your implementation
  diff is clean.
- The three commits since `aeb8a69` (`f24d333`, `3f74b55`, `077cf8f`) are **doc-only** — none touched
  `src/core/` or `packages/`. So every `file:line` anchor in the plan (verified at `aeb8a69`) **still
  holds at `077cf8f`.** That will stop being true the moment you start editing; see discipline.
- The code-graph in `tools/code-graph/.out/` was left rebuilt at **`--profile=all`** (169 modules),
  not the default `core`. Fine to leave; re-run `tools/code-graph/extract.sh` if you want core back.

## Reading order

1. `PLAN-compactor-strategy.md` — **the spec.** Read §0–§1 (wiring) and the Code-graph grounding
   before anything; §1.1 (ephemeral chain), §1.2 (artifacts channel), §1.3 (why calibration inflates)
   are the load-bearing mental model. Then the workstream you're implementing.
2. `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — the acceptance criteria (the two
   sections' Consequences + Fix lists). The plan's §5 maps each to a test.
3. `tools/code-graph/AGENTS.md` — if you want to re-ground a claim; the plan's grounding table shows
   the queries. Remember: call/effect rows are source-parsed approximations, and the effect pass does
   **not** cover the two extension logic modules (treat as unknown, not pure).
4. This directory's `HANDOFF-write-compactor-strategy-plan.md` — the planning handoff, for the *why*
   behind the scope guardrails (do not re-litigate them).

## Non-negotiable discipline

- **The plan's anchors hold at `077cf8f` but drift as you edit.** `session.ail` in particular moves
  (it grew 2455→2523 during recent work). Before you trust an inherited `file:line`, re-grep the
  symbol. Every source claim you *add* (in commit messages, in new comments) carries a `file:line` you
  verified yourself at your working HEAD.
- **Two gates, green before every commit:** `make compaction_dst` and `make conformance`. The plan
  (§5) treats `conformance.compactor.artifact_cache_effective` as the specific **gate on the WS2
  rate-limit** — it runs the real AI compactor and will catch a missing `gap>0` guard. Do not merge a
  red gate "to fix later."
- **Stay inside the guardrails (plan §0).** Do **not** persist compaction into history / mutate
  `st.msgs`; do **not** bound retained history; do **not** touch `src/core/compaction.ail`
  calibration. WS1/WS2 are extension-only; WS3 is the single core touch. A diff that touches
  `st.msgs ++ [assistant_msg]` (`session.ail:1705`) or `affine_calibrate` is wrong by construction.

## The traps, in order of expense

These are the mistakes the review already paid for. Each is fully specified in the plan; this is the
ranked index so you read them *first*, not after a red gate.

1. **(WS1) The selection loop must check the *uncompacted input* before looping tiers — plan §2.2-A.**
   Skip it and you elide already-fine windows (>10 tool results under 70%) that today `PassThrough`.
   The `if calib(msgs) < result_target_pct(): return PassThrough` short-circuit is mandatory, not
   cosmetic.
2. **(WS1) The extension cannot emit exhaustion — plan §2.3.** `compact_for_pre_step` returns
   `PreStepDecision` (no `Err`). Exhaustion is core's, in `seal_compacted_payload` (raw char/4 ≥ 95%
   on the *sealed* window). Your fallback hands seal the smallest best-effort window (`keep_last=1`,
   note `"floor"` not `"emergency"`); seal decides. Test exhaustion **through a session**, never by
   calling the hook (plan §5, exhaustion guard).
3. **(WS2) The rate-limit `gap>0` guard — plan §3.3.** Without it, `artifact_cache_effective` breaks:
   the conformance self-test re-invokes the AI compactor with the prior decision's artifacts (now
   carrying `last_ran_step`) at the *same* `step:1`; a naive `gap<min_gap` rate-limits the re-run and
   diverges from the cached output. `gap>0` (only *later* steps) is both correct and the exact fix.
   Land batch + no-op guard first; add the rate-limit (behind a flag) last, with this invariant as the
   gate.
4. **(WS2) Batch pairing is symmetric — plan §3.1.** Summarizing `old` drops *both* calls and their
   results. The old/recent boundary must never (a) leave an `old` call whose result is in `recent`,
   nor (b) let `recent` *begin* with a tool result whose call is in `old`. Both are "severed pair"
   errors in `validate_compactor_output` (`invariants.ail:60,77`), and a rejected stage **silently
   disables compaction** (`runtime.ail:170`) — worse than a crash. Move the boundary *earlier* to keep
   pairs together; `recent` starts at a turn boundary.
5. **(WS2) The no-op guard is *pre-call* — plan §3.2.** Project relief from `prefix ++ recent`
   (summary treated as empty; an upper bound) and `PassThrough` *before* spending the AI call. The
   whole point is to not pay `summarize_with_ai` to discover 0%. A post-call check is only a
   belt-and-suspenders.
6. **(WS3) Relabel, don't recompute — plan §4.** You cannot measure est/calib on the sent window (its
   message list isn't retained, only its token count). Group `context_window` into `last_sent` /
   `uncompacted_pending` + a `note`; same four numbers. Update the one affected test
   (`test_runtime_status_reports_actual_context_window`, `session.ail:2451`); the other status test is
   unaffected (plan §4.3). Grep TS/web/deploy for flat `*_usage_pct` consumers before committing —
   the one place this can ripple beyond core.

## Suggested WI breakdown and order (from plan §7)

1. **WI-1 (WS3, core):** regroup `context_window`; fix the one test; grep external consumers. Smallest,
   isolates the core touch, and makes the status output legible for the WS1/WS2 scenarios that read it.
2. **WI-2 (WS1, extension):** `result_target_pct` + `select_by_result` (base-check → gentlest-fit →
   `"floor"` fallback); rewire `compact_for_pre_step` selection only; leave elision mechanics and
   `try_emergency_compaction_with_limit` untouched. Add the "not-emergency" unit test + the seal-side
   exhaustion guard.
3. **WI-3a (WS2, extension):** batch `split_body` (symmetric pairing) + pre-call no-op guard. Confirm
   `scenario_multiple_compactions` still holds (it likely does with rate-limit off).
4. **WI-3b (WS2, extension, optional):** rate-limit behind a config flag (`gap>0`; `last_ran_step` in
   the `compaction_ai` artifacts node; `hard_override_pct`). Its own DST scenario + the
   `artifact_cache_effective` gate. This is an optimization, not a correctness fix — it is fine to
   defer or drop if time is short.

Each WI: both gates green before committing.

## Definition of done

- Both gates green: `make compaction_dst`, `make conformance`.
- New tests exist and pass for each fix (plan §5): WS1 gentle-tier-not-emergency; WS1 seal-side
  exhaustion; WS2 drip→PassThrough (no AI call spent), batch→real relief + pairing intact, rate-limit
  cadence + `gap=0` defers-to-cache; WS3 unambiguous `last_sent`/`uncompacted_pending` labels.
- The pathology is gone end-to-end: on the compaction fixture, structural picks the gentlest tier that
  fits (not emergency at low utilization), and the AI compactor no longer emits `Compacted` at ~0%
  relief every step.
- No guardrail violated (no history mutation, no calibration change, WS3 the only core diff).

## Commit and closeout conventions

- Work on `arniwesth/mot-36-compactor-strategy-refinement` (already checked out). Commit the plan
  (docs-only) first, then one commit per WI with the `file:line`-anchored rationale in the message.
- Follow the repo's commit trailer convention (see recent `git log`); keep messages specific about
  *what invariant each change preserves* (the review found these the hard way — encode them).
- When done, drop a `NOTE-compactor-strategy-implementation-findings.md` in this directory if
  as-built diverged from the plan (e.g. you dropped WI-3b, or the batch boundary needed a different
  nudge), and add a stale banner to this handoff pointing at it. Update the issue's Status.

## Pre-flight (run before WI-1)

```bash
git rev-parse --short HEAD                      # expect 077cf8f (or later)
git status --short                              # commit the PLAN edits first
make compaction_dst && make conformance         # baseline must be green BEFORE you start
git log --oneline -20 -- src/core/ packages/    # anything newer than 077cf8f here → re-verify anchors
```
