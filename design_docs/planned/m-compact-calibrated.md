# M-COMPACT-CALIBRATED: fix the compaction oscillation overflow

**Status:** In Progress (2026-06-28)
**Severity:** High — docx_reimplement overflows the context window in 3/5 runs (267k > 262144), capping pass-rate regardless of language fixes. This is the **4th** iteration of compaction; the prior three each shipped as "solved" and regressed.

## Root cause (proven from the token trace, not assumed)

`compact_step_actual` (compaction.ail:159) decides whether to compact from `actual_input` = the provider's exact token count **from the previous call**:

```
effective = 262144 - 75000 = 187144
pct = actual_input * 100 / effective
pct >= 85 → emergency;  >= 75 → keep_last=5;  >= 60 → keep_last=10;  else → NO compaction (60% floor = 112,286 tok)
```

Compaction is **per-step transient** — the full history is rebuilt every step; compaction only shapes that one call. The provider reports tokens **after** a call, so `actual_input` is stale by one step **and reflects whatever was sent** (compacted or not). Emergency compaction drives the call down to a **floor of ~104k**, which is **just under the 112k (60%) trigger**. Result — a stable oscillation (real token trace):

```
246429 → 103830 → 254162 → 104257 → 261021 → 105690 → 267365 ✗ REJECTED
 full    compacted  full    compacted  full    compacted  full
```

After a compacted call reports ~104k, the next step reads 104k → 55% → **skips compaction** → sends the full, uncompacted, ever-growing history (~254k). The full side creeps up each cycle (246→254→261→267) until it crosses 262,144 and ollama rejects it. **The control signal (`actual_input`) is contaminated by the control action (compaction).**

Compaction is **not broken for gradual growth** (the trace shows it firing 110k→81k and holding ~104k for 50 steps). The bug is specifically using the post-compaction provider count to gate the next, uncompacted step.

### Why "use the exact provider numbers" was the wrong fix (answers the standing question)

You must decide whether to compact **before** the call; the provider only returns the exact count **after**. So `actual_input` is necessarily stale and reflects the compacted size. The fix is not estimate-vs-exact — it is **use the exact numbers to *calibrate* the estimate of the current history**: after each call we know `actual_input` and the chars we sent, so `ratio = actual_input / chars_sent` is the provider's ground-truth chars→token ratio. Apply it to the **current** full history's chars → an accurate size of what we are about to send, measured on the right thing (current history) with the right accuracy (provider ratio). The prior iterations failed because they measured the wrong thing: v2 `chars/4` (over-count → thrash), v4 `chars/7` (under-count + excludes pinned prefix → never fires → overflow), v5 actual-tokens (stale → oscillation).

## The fix

1. **Calibrated current-history estimate** drives the decision (replacing the stale-actual trigger):
   - Track `last_sent_chars` in `LoopTotals` (total chars of the messages actually sent last call, including the pinned system prefix).
   - `est_now = current_total_chars * last_input_tokens / last_sent_chars`, where `current_total_chars = pinned_prefix_chars + chars(msgs_after_ext)`. This **includes the pinned system prefix** (which the old `usage_percent` path wrongly excluded) and uses the provider's true ratio.
   - Tier on `est_now / effective` with the existing 60/75/85 levels. Because it measures the **current full history every step**, it cannot oscillate.
   - Step-0 fallback (no provider data yet): the existing `chars/7` estimate on the full history (pinned + msgs).
2. **Hard input ceiling (safety net):** if `est_now >= effective` (≈100%), force emergency compaction regardless of tiers, and if even emergency can't get the estimate under the ceiling, fail loudly with `compaction_exhausted` **before** sending — never hand the provider a call we estimate will be rejected.

## Milestones
- **M1 — Calibrated estimator + ceiling** in `compaction.ail`: new `compact_step_calibrated(msgs, model, pinned_chars, last_input_tokens, last_sent_chars)`; keep `compact_step` (estimate) as the step-0 fallback. Wire it at agent_loop_v2.ail:1145; add `last_sent_chars` to `LoopTotals` and record it where the call is sent.
- **M2 — Trajectory regression test** (the guard that was missing): a pure test that simulates the oscillation scenario — a large current history whose *previous* call was compacted to a low count — and asserts the calibrated decision **still compacts** (the old logic skipped → overflow). This is the test that would have caught all three prior regressions.
- **M3 — Verify end-to-end**: `ailang check` clean; trajectory test green; then a docx run shows **0 context overflows** (the real proof — no compaction change is "done" without this).

## Why this won't regress again
- The decision now measures the **current** history (monotonic within a step), so the oscillation is structurally impossible.
- The **trajectory test** locks the behavior: any future change that reintroduces a stale-signal skip fails the test.
- **Process rule:** a compaction change is not done until a long-context run reports 0 overflows. The prior three skipped this.
