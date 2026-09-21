# PLAN-001 P2T — answer (P2 Part 5: terminal ordering + two production drops, red first)

Branch `arniwesth/013-plan003-and-herdr`, parent `c1bc518` (P2G). One commit, not pushed.

**Commit hash:** this file is inside the commit, so it cannot quote its own hash. Run
`git log -1 --format=%H -- .motoko/ab/answer-p2t.md`; the orchestrator's reply also gives it.

The delegate (mot-dlg-1789288718822) finished `done` but never wrote its herdr answer file
(known unsandboxed-delegate failure; pane reaped). Its work survives in the tree; this report
is reconstructed by the orchestrator from `git diff` plus re-run gates. Anything the
orchestrator did not re-run is marked NOT RUN even where the delegate's pane scrollback
claimed it.

## 1. What landed

**(a) Exit reorder — Part 5(a).** `publish_turn_exit_manifest` moved BEFORE `c2_finalize`'s
clock read and `RunSummary`, takes the loop's world (`st.world_state`), advances at its env
read, witnesses there, and returns `{ world, trace }`. `exit_manifest.publish_exit_manifest`
returns the rendered world (`ExtWorld`) instead of a `bool` — the bool had no reader (every
caller discarded it) while the world was dropped. `c2_finalize` takes that world.
`RunSummary` stays last; publication stays before `done`. The three live-loop call sites
take the new shape (two discard, one threads). Out of reach per the plan: `:3265`-class
stdin-loop and separately-framed lifecycle publishes — recorded, not chased.

**(b) Provider error — Part 5(b).** The `:3483` capture read advances and is witnessed
(`capt`, on `stepped.world` — the step's successor, not the pre-step world), and `capt.world`
/ `capt.trace` feed the retry arm AND the terminal `TermProviderFailure` call in place of
`stepped.world` / `trace_after_end`. On a retryable error `capt` is exactly the old values.
Line-count-neutral at the terminal (S18): the four routed clock anchors below do not move.

**Re-pin.** `ledger_parity_dst.ail` native order: `...DoneEvent|WorldRequest|RunSummary|`
→ `...DoneEvent|WorldRequest|WorldRequest|RunSummary|` — `native` ends in `DoneEvent`, so
its run publishes the exit manifest, now before finalize; the publish's env read is witnessed
after DoneEvent and ahead of the finalize clock's. `capped` publishes nothing (no DoneEvent
on a cost cap), unchanged. Counts move 148 → 154 (WorldRequest projected 154, returned 154).

## 2. Red-first demonstrations (both shown, per the plan)

- **5(a) red:** instrument the publish read, leave the discards — the frame's `final` trails
  the last witness by 1 (all publishing frames fail). Measured by the delegate via the P2G
  frame gate before the fix; the tree now carries the fix. NOT re-run by the orchestrator.
- **5(b) red:** witness the capture read while its successor is still discarded — the
  errored frame fails (`ordinal 16/17 repeated` readings during the work). Measured by the
  delegate; NOT re-run by the orchestrator.

## 3. Gate evidence (tiered; only what the orchestrator re-ran is verified)

| Gate | Tier | Result |
|---|---|---|
| `ailang check src/core/session.ail`, `src/core/ext/exit_manifest.ail` | type/effect | ✓ clean (re-run) |
| `make world_framed_wire` | DST gate | ✓ PASS — 154 world_request lines, 8 frames (re-run; was 148 at P2G) |
| `make ledger_parity` | DST wire-vs-trace | ✓ wire gate PASS; WorldRequest projected 154, returned 154 (re-run) |
| `make anchors` | anchor check | ✓ 10/10 (re-run; no cascade — edits joined/neutral) |
| unit tests (session, ext_world, exit_manifest), `make terminal_trace`, `make journal_resume`, `make stream_parity`, `make check_core` | — | NOT RUN by orchestrator (delegate scrollback claims green; unverified here) |
| `make dst` full sweep | — | NOT RUN (not a phase gate; P2D owns it) |

## 4. Gates NOT run, and why

- Full `make dst`: not a phase gate; P2D runs it detached with DST_JOBS=2.
- The two red-first runs: shown by the delegate, not re-run by the orchestrator (would
  require re-mutating the tree; the re-pinned order literals plus the green gates are the
  standing evidence).
- `make attribution_table` / profiles: anchors unmoved, table untouched — no re-issue due.
- `verify_core` / `verify_classify_check`: no new pure funcs with contracts.

## 5. What P2D consumes

1. **P2 is mechanically complete** after this: advance (P2A) → witness (P2B) → frames (P2G)
   → drops closed (P2T). P2D's work: vocab 43 + Row7 wiring check, six named gates green,
   `driver_only` pin green, `check_core` — then the phase-gate `make dst DST_JOBS=2` detached.
2. **Frame/gate numbers at HEAD:** native order carries the double-WorldRequest close;
   world_framed_wire expects 154 requests over 8 frames (was 148).
3. **`event_vocabulary_version` string bump still open** (since P1B).
4. **Part 6 pin (derivation script §2.1):** run `derive.py` after every edit per the plan;
   P2B notes its tree scan still does not check witnessed-in-order at the 24 sites — P2D
   either extends it or records the hand-maintained restriction and amends the ADR per the
   fallback rule.
