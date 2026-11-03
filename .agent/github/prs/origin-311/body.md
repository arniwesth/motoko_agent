---
repo: arniwesth/motoko_agent
pr: 311
branch: arniwesth/041-adr-i2-scope
ticket: null
title: "docs(041): amend ADR-002 I2 — a scripted Search deadline reports unknown"
---

## Summary

ADR-002's invariant **I2** and its acceptance bullet (A21) said a `Search` timeout reports `effects: none`, with no world qualifier. That holds on the **live** path only: `tool_runtime.ail:637` hardcodes `EffectsNone` for `Search`. The **scripted** path builds every deadline through `deadline_fault` (`tool_fault.ail:314-318`), which is tool-blind and pinned by `ensures` to `EffectsUnknown`; W7 pinned those bytes (`test_w7_deadline_disclosure_by_tool`, `tool_phase.ail:979`) and reported the conflict.

**Operator ruling: amend the ADR's scope, change no code.** Changing the scripted arm would alter a `Legacy` program's result bytes, against D4, and contradict A10, which keeps `Search`'s scripted deadline behaviour as it is today. `unknown` is also the conservative direction. **No code, test, fixture or Makefile changed.**

## Changes

- docs(041): scope I2's Search disclosure to the live path (041 I2)
- docs(041): state A21's Search disclosure per world (041 I2)

Four edits plus the revision bump:

1. **ADR I2** — `ReadFile` and `Search` keep `none` "in a **live** run"; a scripted `Search` deadline reports `unknown` because `deadline_fault` is tool-blind and A10 keeps that path. `BashExec`/`RunTests` wording unchanged.
2. **ADR acceptance bullet (A21)** — the same qualifier.
3. **PLAN W13 acceptance** — "A17, A20 and A21 across both worlds" now asserts A21's `Search` disclosure per world: live `none`, scripted `unknown`.
4. **PLAN coverage row A21** — "live `Search` timeout `none`, scripted `Search` deadline `unknown`".
5. **ADR header** — Status "ninth revision" → "tenth revision"; the revision narrative records what was wrong, what the tenth revision did, and why the code was not changed.

R9 does not require a re-check: it gates acceptance on "a narrow independent check [that] confirms the resolutions of the carrier's `session_default` and the extension token". This amendment touches neither, and changes no design: it makes the ADR describe behaviour already shipped and pinned.

2 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`

## Predicted outcome

W13 asserts A21 per world (live `none`, scripted `unknown`) instead of meeting an unsatisfiable "`none` in both worlds", and the ADR stops contradicting the code. Checked by W13's parity rows and by W7's existing pinned test staying green unchanged.

## Test evidence

Documents only; no build or test run applies. Checks:

**1. The four edits read correctly.** See the ADR diff below and the plan diff:

```
-- A17, A20 and A21 across both worlds.
+- A17, A20 and A21 across both worlds, with A21's `Search` disclosure asserted **per world**: live
+  `none`, scripted `unknown` (ADR I2 as amended).
-| A21 | Timeout `unknown`; `Search` timeout `none` (560) | W7, W10, W13 |
+| A21 | Timeout `unknown`; live `Search` timeout `none`, scripted `Search` deadline `unknown` (560) | W7, W10, W13 |
```

**2. No other doc asserts the unqualified claim.** Every line in `.agent/projects/041_process_execution_timeouts/` and `docs/` mentioning `Search` within two lines of `none`/`EffectsNone` (JSON scanned by ±200-char window; no JSON hits):

| Hit | Verdict |
|---|---|
| ADR:22 (revision narrative) | correctly amended — describes the defect |
| ADR:112-113 (I2) | correctly amended |
| ADR:569-570 (acceptance) | correctly amended |
| PLAN:653 (W13) | correctly amended |
| PLAN:708 (A21 row) | correctly amended |
| PLAN:546 (W10: "A21: a live `BashExec` and `RunTests` timeout is `unknown`, and a `Search` timeout stays `none`.") | correct in context — W10 is "Live executor and loopback", acceptance by direct live calls; the W6-W7 handoff reads it the same way ("The plan gives Search to W10 (line 546)"). Not edited. |
| HANDOFF-session-W6-W7:87-88, :345 | unrelated — historical record that reported this conflict |

**3. Code untouched.** `git diff --name-only origin/main...HEAD`:

```
.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md
.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md
```

**4. Nothing else in the ADR moved.** `git diff origin/main -- ADR-002`; four hunks: Status bump, narrative sentence, I2, acceptance bullet:

```diff
diff --git a/.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md b/.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md
index da6d4161..8836d0aa 100644
--- a/.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md
+++ b/.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md
@@ -1,7 +1,7 @@
 # ADR-002: Per-call process timeouts and what a timeout tells the model
 
 Date: 2026-10-30
-Status: **Accepted 2026-10-31 under R9, ninth revision. Not implemented. Rulings R1-R11 are in §7.**
+Status: **Accepted 2026-10-31 under R9, tenth revision. Not implemented. Rulings R1-R11 are in §7.**
 Grounded at: `origin/main` `a393314b` (#284 merged). AILANG v0.54.14, with the upstream API also
 read at v0.55.0.
 
@@ -18,7 +18,12 @@ lacked a value its readers need, and the extension token dropped the run's limit
 all of them. The check R9 requires found that both design changes hold, with amendments. This revision
 applies those, plus six gaps PLAN-001 found. These last changes have not been reviewed, by the operator's
 choice: what remains is left to the plan's tests. The route for startup limits is the one new piece of
-design here, and W11 confirms it.
+design here, and W11 confirms it. A tenth revision, after W7, corrected I2 and its acceptance bullet:
+both stated `none` for a `Search` timeout without restricting it to the live path, while the scripted
+arm builds every deadline through `deadline_fault`, which is tool-blind and reports `unknown`. It scopes
+both to the live path and states the scripted path's `unknown`. The code was not changed instead,
+because D4 renders a `Legacy` program as it does today and A10 keeps `Search`'s scripted deadline
+behaviour.
 
 Requested by the operator after #284 merged and tool calls were still seen to stop at 30 s.
 
@@ -104,8 +109,10 @@ Three gaps remain after #284:
   operator's ceiling. Detached descendants (D5) and a killed runtime (D6) are outside this bound,
   and are stated here so that it is not read as absolute.
 - **I2.** A timeout of `BashExec`, `RunTests` or another tool that may change state is never reported
-  as `effects: none`. `ReadFile` and `Search` keep 034 D2's `none`: `Search` overrides the disclosure
-  at `src/core/tool_runtime.ail:632-638`.
+  as `effects: none`. In a **live** run `ReadFile` and `Search` keep 034 D2's `none`: `Search` overrides
+  the disclosure at `src/core/tool_runtime.ail:632-638`. **A scripted `Search` deadline reports
+  `unknown`**, not `none`: the scripted arm builds every deadline through `deadline_fault`, which is
+  tool-blind, and A10 keeps that path's behaviour as it is today. The two worlds differ here, deliberately.
 - **I3.** Live and scripted runs get their limit from the same resolver and report it in the same
   fields wherever the harness renders the result, so DST exercises what production does. A scripted
   completion is served as authored (D4). Their configuration may differ.
@@ -559,8 +566,9 @@ Accepted when:
 - After #1878, partial stdout and stderr are preserved on a timeout; before it, their absence is
   explicit.
 - Timing tests separate the enforced deadline from return latency, which can include `WaitDelay`.
-- A `BashExec` or `RunTests` timeout reports `effects: unknown`, and a `Search` timeout still reports
-  `effects: none` (I2).
+- A `BashExec` or `RunTests` timeout reports `effects: unknown`. A **live** `Search` timeout reports
+  `effects: none` (I2). A **scripted** `Search` deadline reports `unknown`, because the scripted arm's
+  `deadline_fault` is tool-blind and A10 keeps that path as it is today; the two worlds differ here.
 - Cancelling a run with SIGTERM or SIGINT stops the command and its ordinary descendants with no late effect. A recorded
   failure alone does not satisfy this.
 - An existing `MOTOKO_PROCESS_TIMEOUT` above any shipped limit still starts, with no new setting (I4).
```

**5. W7 agrees with the plan.** W7's acceptance says "A21, scripted half." Under the amended A21, the scripted half is `BashExec`/`RunTests` `unknown` and a scripted `Search` deadline `unknown` — exactly what `test_w7_deadline_disclosure_by_tool` pins. No word needs changing; W7 is untouched.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
