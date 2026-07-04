# Handoff: implement Phase C2 (live inversion)

Date: 2026-07-04 (written by the session that verified Phase C as-built, wrote
`NOTE-phase-c-implementation-findings.md`, and authored + reviewed the plan)
Audience: a fresh implementer session. **The plan is the spec**:
`PLAN-phase-c2-live-inversion.md`, WI-C9 → WI-C14. This handoff is intentionally narrow;
it carries only the residual context the plan compresses.

## Why this work exists (one paragraph)

Phase C's WI-C8 gate passes, but the inversion is not live: `decide` and the phase
modules have **zero production callers**; the live loop is the old recursion relocated
into `session.ail`; the approval `readLine()` still blocks mid-dispatch
(`session.ail:785`); env reads are still mid-loop. Full evidence with anchors:
`NOTE-phase-c-implementation-findings.md`. Phase C2 routes the live driver through the
pure core under a frozen wire contract, and adds the positive wiring checks whose
absence let a relocation pass as an inversion.

## Current state

- Branch: `arniwesth/mot-27-phased-core-architecture`. Last commit: `8604365`.
- **Uncommitted work from the authoring session** (commit this first, docs-only):
  `NOTE-phase-c-implementation-findings.md` (new),
  `PLAN-phase-c2-live-inversion.md` (new),
  `HANDOFF-continue-phase-c.md` (stale banner added), this handoff.
- Worktree residue: `M ailang.lock` — benign regeneration (only `generated_at` +
  mirror content hashes; verified 2026-07-04); commit it deliberately, alone or with
  the docs. `?? oh-my-pi/` — unrelated, do not touch.
- Active strict baseline: `/tmp/phase_c_blessed`. `/tmp` is volatile: if the dir is
  gone, regenerate at the last green commit with
  `./scripts/phase_a_event_parity.sh /tmp/phase_c_blessed` run **twice** (self-diff
  empty) before starting.
- The WI-C8 gate block, strict parity, projection gate, L1 scenarios (10/10), approval
  protocol (4/4), and all module tests were re-run green on 2026-07-04 at `8604365`.

## Blocking item before WI-C9

**G-C2-1 / D-C2-1 needs operator sign-off**: `seal_compacted_payload` in `phase_vocab`
and the ADR wording widening ("no way to obtain a `ProviderPayload` outside
`phase_vocab`'s exported projection ops"). It is dispositioned in the plan pending that
sign-off. Do not land WI-C9's `phase_vocab` changes without it; everything else in
WI-C9 is unaffected if you need to start while waiting.

## Reading order

1. `NOTE-phase-c-implementation-findings.md` — the problem statement.
2. `PLAN-phase-c2-live-inversion.md` — the spec. Its plan-level decisions D-C2-1 …
   D-C2-6 are settled (pending the G-C2-1 sign-off above); the parent plan's D-C1–D-C7
   remain in force.
3. `src/core/session.ail` — the ground truth you are inverting. Read `loop_v2`
   (`:1103-1500`) and `dispatch_calls` (`:747-1016`) completely before writing anything.
4. The pure surface you are wiring: `step_machine.ail`, `tool_phase.ail`,
   `model_phase.ail`, `hook_phase.ail`, `cost_phase.ail`, `recovery.ail`, `ports.ail`,
   `test/scripted_ports.ail`, and `phase_vocab.ail:476-506` (in-memory ledger).
5. `PLAN-phase-b-phase-results.md` D-B7 only (parity protocol).

Do **not** start from `HANDOFF-continue-phase-c.md` or the 2026-07-04 session summary —
both carry stale-state banners for a reason.

## Non-negotiable discipline

- Re-verify every plan anchor against HEAD before editing (`git log --oneline -5`
  first). The plan's anchors were read at `8604365`; the docs commit will not move
  source lines, but re-grep anyway — it is the house rule that caught the last three
  sessions' staleness bugs.
- Toolchain pin v0.26.0 / `3b52a24`; if `ailang --version` disagrees, STOP.
- `rg` is **not installed** in this environment; use `grep`. When a gate transcribes an
  `rg` command from the parent plan, substitute `grep` fixed-string equivalents.
- Never read `$?` after a pipeline; capture rc adjacent
  (`NOTE-ailang-run-exit-code-false-alarm.md`). The sealing probe is a negative check:
  `IMP010` failure is the pass condition.
- A parity diff anywhere is a **stop**, classified per D-B7 before any code or baseline
  change. No expected-diff table is anticipated in this plan; needing one means
  something is wrong — investigate before believing it.

## Residuals the plan compresses (the traps, in order of expense)

1. **Transcribe live strings by copy, never by retyping.** Several live strings contain
   em-dashes and unicode punctuation (`"prose —"` in the nudge, `"timeout — no approval
   received"` and both other approval defaults). A retyped `--` or `-` passes review and
   fails the differ hours later. Copy the bytes out of `session.ail` into the golden
   tests; that is what WI-C9 is for.
2. **The `"stop"` sentinel trap (D-C2-2).** `decide` finalizes on
   `last_finish_reason == "stop"`. If the driver ever writes the raw provider
   `finish_reason` into state before intercept/hybrid/solver/persist-nudge/DP7 have
   resolved, the cycle finalizes early and the differ lights up everywhere. Raw
   `finish_reason` is interpretation input only.
3. **Transcript-append deferral.** Do not append the assistant message to history until
   interpretation is done — the hybrid path must swap in the augmented message
   (tool_calls patched) or Bedrock-class orphaned tool_results reappear
   (`session.ail:1330-1350`).
4. **One results batch across the approval pause.** The live path emits exactly one
   `native_tool_results` after the whole call set resolves, blocking mid-batch on the
   read. Accumulate tool messages across the AwaitApproval boundary; per-segment
   batches are a wire regression.
5. **Step accounting is driver-owned.** `StateDelta` has no `step_idx` (deliberate).
   Increment on `CallModel` execution; stream-retry consumes a step via its
   re-`CallModel`, matching live.
6. **The A/B differ is the WI-C11/C12 completion criterion, not a per-sub-commit
   gate.** Flag-off strict parity ships every sub-commit; the differ
   (`scripts/phase_c2_ab_parity.sh`, created WI-C9, retired WI-C13a) must be
   byte-empty at the WI boundary. If an arm isn't implemented yet, the differ will
   fail — that is expected mid-WI, not a defect.
7. **Do not weaken the wiring scenarios to make them pass.** They are the
   anti-relocation instrument (D-C2-4). If a `DecisionRecord` sequence assertion is
   inconvenient, the cycle is wrong, not the assertion. The DP7-rejection scenario
   needs `Process` caps — that is in the plan, not an error.
8. **Two `ExtCtx` shapes per step** (`session.ail:1153` vs `:1257`). Extensions observe
   `history_slice` and `context_limit`; collapsing the two builds is invisible to the
   parity fleet but breaks real extensions.
9. **`make smoke_parity` runs the dp7 workdir setup itself** (harness `:169`) and takes
   minutes; don't parallel-run two harness invocations — they share `/tmp` capture dirs
   only if you pass the same path (the differ uses its own `/tmp/c2_ab_*` dirs).

## Commit and closeout conventions

- Commit subjects continue the sequence: `WI-C9 …` through `WI-C14 …` (WI-C13 as
  `WI-C13a/b/c` sub-commits per the plan). One WI per commit unless the plan says
  otherwise.
- Deviations from the plan discovered against HEAD are **findings**: record them in a
  `NOTE-phase-c2-implementation-findings.md` (Phase B note is the model), never guess
  around the plan silently.
- WI-C14 owns the documentation closeout (findings-note addendum flipping the
  disposition rows, handoff banner updates, session summary). Do not claim Phase C
  complete anywhere until the WI-C14 gate passes as a block.
- Do not start ABI v3, conformance kit, `compaction_ai` v0.3.0, or registry publication
  of `motoko_ext_compaction_structural`.

## Pre-flight (run before WI-C9)

```
ailang --version                                   # v0.26.0 / 3b52a24, else STOP
git status --short                                 # commit the docs + lock first
ls -d /tmp/phase_c_blessed                         # regenerate if missing (see above)
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
ailang test src/core/phase_vocab.ail
ailang test src/core/step_machine.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
```

All were green at handoff time. If any is not, stop and reconcile before implementing.
