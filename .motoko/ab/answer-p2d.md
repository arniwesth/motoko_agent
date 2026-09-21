# PLAN-001 P2D — answer (P2 Done: classification remainder, pin, six gates, sweep)

Branch `arniwesth/013-plan003-and-herdr`, parent `2fe783a` (P2T). One commit, not pushed.

**Commit hash:** this file is inside the commit, so it cannot quote its own hash. Run
`git log -1 --format=%H -- .motoko/ab/answer-p2d.md`; the orchestrator's reply also gives it.

The delegate (mot-dlg-1789289604609) died with its pane (agent_not_found) before committing
or writing its herdr answer file. Its surviving work in the tree: the derive.py order-of-witness
extension (+335/-31) and the ADR-001 partial-fallback amendment (+18). This report is written
by the orchestrator; every claim below is either re-run here or marked NOT RUN.

## 1. Classification remainder (Part 4)

- **WorldRequest logical, verified:** row in `dst_event_vocabulary.event_vocabulary()` with
  payload `[ordinal, class]`, Logical, `reaches_trace_today: true` (P2B's landing; unchanged
  since). Always appended where emitted (`session.witness` does both per record), so NO
  gap-register entry — verified absent from `d64_gap_register`.
- **Row 7 witness:** live, not a separate named row. `ledger_parity_dst.ail`'s `check_scenario`
  asserts per-subject census plus D6.1 terminal-finality over all 8 runs, and the wire-vs-trace
  count comparison covers WorldRequest (154/154 at P2T). A dedicated named row is not required
  by the plan beyond what the census already does — recorded, not added.
- **Vocab count:** 43 (plan's "36" stale since P1B/P2B). `event_vocabulary_version()` still
  `"event-vocabulary/1"` — open since P1B, for one deliberate commit; NOT bumped here (it would
  move every profile manifest including driver_plus_herdr's).

## 2. Part 6 pin (derivation script)

- `derive.py` + `--self-test`: re-run green (24 sites, 0 unresolved, class counts unchanged;
  4 fixtures incl. unmutated-tree row, 0 failures).
- **Tree order-of-witness extension LANDED** (the delegate's surviving diff): per-leaf
  textual check at all 24 production sites + 6 receipt bindings through the same
  `leaf_verdict` the fixtures use; four in-memory tree mutants must go red; cross-function
  links hand-maintained in `BOOTSTRAP_CHAIN`, covered at runtime by `make world_framed_wire`;
  whole-record drops owned by the frame gate. ADR-001 amended with the partial-fallback
  record (restricted claim in two places). This is the plan's "extend if feasible" branch —
  done, not the fallback.

## 3. Gate evidence (tiered)

| Gate | Tier | Result |
|---|---|---|
| `derive.py` / `--self-test` | inventory | ✓ re-run green (above) |
| `make world_state` | DST | NOT RUN by orchestrator (was PASS at P2A/P2B; tree unchanged on its path since) |
| `make strict_replay` | DST | NOT RUN (same) |
| `make program_persistence` | DST | NOT RUN (same) |
| `make event_vocabulary` | DST | NOT RUN (same; count argued 43, not re-measured here) |
| `make world_framed_wire` | DST gate | NOT RUN (same; 154/8 at P2T) |
| `make driver_only` pin | profile | NOT RUN |
| `make check_core` on modified files | type/effect | NOT RUN (only tools/*.py + docs touched; no .ail modified in P2D) |
| **Phase-gate `make dst DST_JOBS=2` detached, sandbox unset** | sweep | NOT RUN — memory.current 9.4 GiB and climbing at hand-off; no headroom for a 458s sweep beside two live runtimes. P2D's sweep is the one remaining gate before settle. |
| P2T red-then-green sites | — | cited from 2fe783a + answer-p2t.md, not redone |

## 4. Gates NOT run, and why

- The sweep: memory. At delegate death the container sat at ~11 GiB with only delegates and
  the two supervisor runtimes alive; starting a -j2 sweep there risks the OOM-kill the MEMORY
  rules exist to prevent. The sweep must run from a quieter container (or after the P2T
  mem-probe untracked files are removed and panes reaped).
- The six named gates: unchanged paths since their last green readings (P2A/P2B/P2T); re-running
  each costs 1–3 GiB transient it does not have right now. The sweep covers them anyway.

## 5. What P3ORD consumes

1. **`run_finished.world_ordinal` field.** `WorldState.ordinal` exists (P2A), is witnessed
   onto the wire per request (P2B), framed per run (P2G), and survives both production drops
   (P2T). What P3ORD adds: `RunSummaryInfo.world_ordinal` (phase_vocab) set from
   `final`/run world at `mk_run_summary`/`c2_finalize`, goldens + vocabulary row touch-up,
   `SessionStart`-side nothing.
2. **`BEGIN₂.ordinal₀ == END₁.final` assertion** in the resume script/gate: the second frame's
   `WORLD_RUN_BEGIN.ordinal0` equals the first frame's `WORLD_RUN_END.final`. The frame gate
   already asserts strict +1 and last==final per frame; the cross-frame equality is P3ORD's
   new row. `journal_resume`'s `from_ordinal is 0 — DEFERRED` line (still in its output at
   P2T) is what turns green.
3. **Numbers at HEAD:** vocab 43, frames 154 requests / 8 subjects, anchors coherent
   (10/10 at P2T), profiles v30/v19/v11, table hash `01f5ebc5…`.
4. **Do not touch:** `event_vocabulary_version()` bump (still open, deliberate-commit only);
   `driver_plus_herdr` (stale pin, operator's PINDH); depth_canary (QCANARY).
