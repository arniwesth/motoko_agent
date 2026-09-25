# PLAN-001 P2G — answer (P2 Part 3: per-run frames on the stdout wire)

Branch `arniwesth/013-plan003-and-herdr`, parent `9e29fe1` (P2B is `6b33f36`). One commit, not pushed.

**Commit hash:** this file is inside the commit, so it cannot quote its own hash. Run
`git log -1 --format=%H -- .motoko/ab/answer-p2g.md`; the orchestrator's reply also gives it.

The working tree also holds other authors' uncommitted edits (`ailang.lock`, several untracked paths). **They are left
out of the commit.**

## 1. What landed

The commit touches three code files.

| File | Change |
|---|---|
| `scripts/dst/run_world_framed_wire.sh` (**new**) | The shell gate, written on the `run_ledger_parity_wire.sh` pattern, which is **not modified**. It has three modes: the default runs `ledger_parity_dst.ail` and checks it; `--wire FILE [N]` checks a captured wire; `--selftest` runs every red class and both green shapes over synthetic wires |
| `scripts/dst/ledger_parity_dst.ail` | Frames its 8 traced invocations. `frame_ordinal0`, `begin_frame` and `end_frame` are added above `main`. Each subject binds its provider to `pN`, prints `WORLD_RUN_BEGIN <label> <ordinal0>`, makes the outer call, then runs `end_frame`. The script prints `WORLD_RUN_FRAMES 8` next to `LEDGER_SUBJECTS 8`, and `framed` joins the PASS condition |
| `Makefile` | `make world_framed_wire` (selftest, then the gate) sits directly after `ledger_parity`. It is appended to `DST_TARGETS`; `make dst_target_list` shows it in the parallel set |

### Decisions

**Which script is framed.** I framed `ledger_parity_dst.ail` rather than adding a new DST script.
- It holds the 148-request census P2B measured.
- It holds the approval subject that acceptance case 1 needs, and its `pending_rt` fixtures are not exported.
- Labels match its `LEDGER_TRACE` labels (`native denied pending errored capped dp7 handled delegated`).

**Cost of that choice.** The sweep now runs this fixture twice, once under `ledger_parity` and once under
`world_framed_wire`. Each run takes about 22–38 s, and each is a single `ailang` process.

**`ordinal0` is the world handed to the OUTER call** (P2B §5.2).
- `ported_provider` is private to `session.ail`, so `frame_ordinal0` mirrors its world choice one constructor at a time:
  `scripted_world_state(script).ordinal`, `w.ordinal` for the three world-carrying constructors, and
  `empty_world_state().ordinal` otherwise.
- Every subject measured `ordinal0 = 0`. The non-zero case is covered by the `nonzero_ordinal0` selftest (synthetic).

**END comes from `run.world.ordinal`.**
- `end_frame` **refuses** END when `run.world.pending` is non-empty. It prints `WORLD_RUN_REFUSED <label> pending=N`
  instead.
- The refusal is **carried into `ledger_parity_dst`'s own verdict** as a ✗ row. So `make ledger_parity` also goes red
  on a refusal, through the census rc its gate already carries. This coupling is deliberate: a pending witness at return
  is a production defect, not a framing detail.

### What the gate asserts

These assertions are per frame, read from an awk state machine over the whole output in order:
- BEGIN and END markers must match `^WORLD_RUN_(BEGIN|END) <label> <int>$`. Anything else is a **truncated or malformed
  marker** (red).
- **Exactly one END per BEGIN.** Red on:
  - a BEGIN while a frame is open;
  - a label framed twice;
  - an END with no open frame;
  - an END whose label differs from the open frame's;
  - EOF inside a frame;
  - a REFUSED line.
- **Every `world_request` line inside a frame.**
- **Strict +1 from `ordinal0`.** The red messages name the cause: *repeated*, *backward* (both stale-world re-requests),
  or *gap of k*.
- **last == final**, otherwise a "drop after the last witness".
- **At least one request per frame.** Every traced run witnesses its finalize clock.

Across the run, these fail closed (vacuity rows):
- the frame count == 8;
- END count == BEGIN count;
- the script reached `WORLD_RUN_FRAMES 8`;
- the total number of requests > 0.

The number of distinct `session_id`s is reported, not asserted, because equal ordinals in different frames are valid.

**Per-frame request counts are measured, not pinned.**
- An exact count pin would duplicate `ledger_parity`'s order literals.
- It would also force a re-pin at every Part 5 witness.
- The frame count is the plan's "expected count".

## 2. Gate evidence (only gates that ran, tiered)

| Gate | Tier | Result |
|---|---|---|
| `bash -n scripts/dst/run_world_framed_wire.sh` | syntax | ✓ (`shellcheck` is **not installed** in this container, so it was NOT RUN) |
| `ailang check scripts/dst/ledger_parity_dst.ail` | type/effect | ✓ `No errors found` |
| `run_world_framed_wire.sh --selftest` | gate can go red (synthetic) | ✓ 21/21. Green: `shared_session_two_runs`, `nonzero_ordinal0`. Red, each with its named row: `repeated_ordinal`, `backward_ordinal`, `gap`, `gap_at_ordinal0`, `final_mismatch`, `request_outside_frame`, `request_after_frame`, `missing_end_at_eof`, `missing_end_midstream`, `duplicated_begin`, `duplicated_end`, `truncated_end`, `truncated_begin`, `label_mismatch`, `refused_end`, `empty_frame`, `frame_count`, `frames_line_missing`, `empty_wire` |
| `make world_framed_wire` | DST (real wire) | ✓ `world_framed_wire gate PASS`. 8 frames, each `ordinal0=0` and strict +1 to final: **native 21, denied 18, pending 19, errored 17, capped 17, dp7 20, handled 18, delegated 18 = 148**. All on `session_0`. One END per BEGIN (8). `WORLD_RUN_FRAMES 8` reached. Green again after every mutant was reverted |
| `make ledger_parity` (with the framed script) | DST (wire vs trace) | ✓ `ledger_parity wire gate PASS`, `WorldRequest: projected 148, returned 148`, witnessed=23. The added marker lines do not disturb it: it reads prefixes and `"type":"…"` |
| `tools/predicate-anchors/anchors.sh` | anchors | ✓ 10 ✓, 0 ✗ (no `src/core` file changed; `session.ail` is byte-identical to HEAD after the mutants) |

### Acceptance cases, red first

Each case used a real mutant. Each mutant was restored from a byte copy, confirmed with `cmp` and
`git diff --quiet -- src/core/session.ail`, and followed by a green re-run.

| # | Case | Mutant | Gate result on the mutant |
|---|---|---|---|
| 1 | **Whole-record drop**: `st` instead of `post` at the approval site | `let post: C2LoopState = st;` in place of `{ st \| world_state: approved.world }` | **red**, exit 1: `✗ frame pending: ordinal 17 repeated (stale-world re-request)`. **This is the only ✗ row.** `ledger_parity_dst`'s in-process census stayed green (the script exited 0; no "failed" row). Only the frame gate sees this drop |
| 2 | **Missing end marker**: the script exits before `WORLD_RUN_END` | `let _ = exit(3);` before the `pending` subject's `end_frame` | **red**, exit 1: `✗ frame pending: no END marker (the script exited inside the frame…)`, `✗ expected 8 frame(s), saw 3`, `✗ 3 BEGIN but 2 matching END`, `✗ WORLD_RUN_FRAMES is none`. The script's exit 3 is carried |
| 3a | **Dropped last request**, with `pending` left non-empty | `c2_finalize`: `let clocked = { trace: trace, world: advance(reading.next_state, ClockRead) };` (no `witness`) | **red**: the script refuses END in all 8 frames. `✗ frame native: the script REFUSED END (pending=1)` × 8, and `✗ 8 BEGIN but 0 matching END` (after the refusal-closes-frame fix, re-run) |
| 3b | **Dropped last request** as a silent drain, which is the plan's "final mismatch" | the same, with `{ adv \| pending: [] }` | **red** in every frame: `✗ frame native: last witnessed ordinal 20 != final 21 (a drop after the last witness)`, and the same for denied 17/18, pending 18/19, errored 16/17, capped 16/17, dp7 19/20, handled 17/18, delegated 17/18 |
| 4 | **Two honest runs sharing `session_id`** | none. Real: all 8 frames are on `session_0` and restart at ordinal 1 | **green** (the real run above: 148 requests across 1 session_id). The same shape is also a synthetic selftest (`shared_session_two_runs`) |

**Red-first note.** Case 3's mutants (3a, 3b) also make `ledger_parity_dst`'s native order literal fail; case 1's does
not. `make ledger_parity` itself was **not** run on the mutants: its per-variant counts would stay equal
(projected == appended), which is argued, not measured.

## 3. NOT RUN, and why

- **`make dst`: NOT RUN.** The brief forbids it (memory ceiling). The new target's position in the sweep is shown by
  `make dst_target_list`, not by a sweep run.
- **`shellcheck`: NOT RUN.** It is not installed; `bash -n` ran instead.
- **`make check_core`, the `ailang test` units and the TS host tests: NOT RUN.** No `src/core/` file changed in the
  commit.
- **`make ledger_parity` on the mutants: NOT RUN.** See the red-first note above.
- **Known reds (`depth_canary`, `driver_plus_herdr`, `herdr_graded`): NOT RUN and not needed.** No anchor moved, and no
  profile was touched.
- **Other DST scripts' traced invocations: NOT framed.** 20 other scripts under `scripts/dst/` call traced entries,
  including `strict_replay_dst`, `journal_resume_dst`, `stream_parity_dst`, `terminal_trace_dst`, `phase_c2_wiring_scenarios`
  and the corpus/discovery scripts. Only `ledger_parity_dst` is gated.
  - Framing another script means reusing `begin_frame`/`end_frame`, which are script-local here (not exported), plus a
    gate invocation.
  - Recorded as follow-up, not chased.
- **Live-loop publish calls (`publish_turn_exit_manifest` from the conversation loop) and the multi-turn loop: NOT
  framed.** They are a Non-goal. No deterministic run enters them.

## 4. What P2T / P2D consume

1. **The gate is the Part 5 red-first instrument.** Run `./scripts/dst/run_world_framed_wire.sh` directly (about 25 s),
   or `--wire FILE` over a captured run.
   - **5(b), provider error (`:3483`, `errored` frame).** Witnessing the advanced read while the successor stays
     discarded should give `✗ frame errored: ordinal 17 repeated`: the finalize clock re-advances from the stale 16. It
     would give `last … != final` instead only if no helped leaf followed. **After the fix**, errored measures 18.
   - **5(a), exit manifest (`:4535`).** The same shape applies, but only in frames whose run publishes an exit manifest.
     Check which subjects do before predicting the row.
2. **No count re-pin is needed in this gate after Part 5.** It pins the frame count (8), not per-frame counts.
   `ledger_parity`'s native/capped order literals are the pins that will move.
3. **Refusal coupling.** A Part 5 edit that advances without witnessing on a returned world makes **both**
   `world_framed_wire` (REFUSED) and `ledger_parity` (the census row from `end_frame`) red.
4. **Markers and stale references.**
   - The precedent line `ledger_parity_dst.ail:330` (`LEDGER_TRACE`) cited by the plan and the ADR has moved down,
     because the frame helpers sit above `main`.
   - The markers are `WORLD_RUN_BEGIN`, `WORLD_RUN_END`, `WORLD_RUN_REFUSED` and `WORLD_RUN_FRAMES`, all in that script.
5. **Part 4's remainder is unchanged from P2B §5.6.** The `event_vocabulary_version` bump is still open, and the
   vocabulary is at 43.
6. **P2D (Part 6).** `derive.py` is unaffected: no `src/core` edit. The gate complements the order-of-witness pin but
   does not replace it. A successor dropped **before** its witness in a frame whose next leaf re-advances shows as
   *repeated*; one dropped with its pending witness shows as REFUSED. A drop that loses both the advance and the witness
   (an un-advanced leaf) is **invisible** to the gate. That is Part 6's job.
7. **Anchor cost: zero.** No `src/core` line moved.
