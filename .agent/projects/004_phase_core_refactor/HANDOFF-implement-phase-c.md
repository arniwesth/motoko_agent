# Handoff: implement Phase C

Audience: a fresh implementer session. The Phase C plan was authored fresh after Phase B,
committed as `34f901a`, then reviewed before this handoff for implementation hazards. Keep
it short: **the plan is the spec — this file only tells you how to hold it.**

## Mission

Execute `PLAN-phase-c-full-inversion.md` in this directory, WI-C0 -> WI-C8, in order. One
commit per WI unless a WI's expected-diff table needs a separate evidence commit; every WI
must leave the system shippable and its verification block green. Done = the WI-C8 final
gate passes as a block: minimal-caps L1 scenarios, scripted approval protocol, pure-module
tests, sketch probes, sealing negative probe, strict parity against the final Phase C blessed
baseline, and the Phase B projection gate.

Do NOT start ABI v3, the conformance kit, `compaction_ai` v0.3.0, or registry publication of
`motoko_ext_compaction_structural`. Those are parallel-track work, not Phase C.

## Reading order

1. `PLAN-phase-c-full-inversion.md` — normative. Its D-C1..D-C7 decisions, WI-C0..WI-C8
   sequencing, per-WI verification blocks, rollback notes, and final gate are your work.
2. `ADR-001-phase-oriented-core.md` — Phase C deliverables + gate, Decision detail 5
   module split/approval protocol, Decision detail 4's checkpoint mechanics, and both
   dispositions logs. D1-D9, G1-G8, and G-B1-G-B7 are settled.
3. `NOTE-phase-b-implementation-findings.md` and
   `.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md` — Phase B as-built
   residuals. Especially: `validate_compactor_output` history, MOD011 structural-package
   collision, and final blessed baseline `/tmp/phase_b_blessed`.
4. `PLAN-phase-b-phase-results.md` — D-B1 explains why `loop_v2` still owns the driver; D-B7
   is the parity/expected-diff protocol Phase C inherits.
5. `RESEARCH-phase-core-dst-design.md` — §2 P1/P2/P3, §5 residual homes, §7.3/§7.4
   scenario/checkpoint seam, and §11 facts 13/17 for sealing/co-location.
6. `sketch/sketch_vocabulary.ail` + `sketch/probe_consumer_decide.ail` — re-run before
   leaning on the pure `decide` derivation or separate-module wrapper proof.
7. `NOTE-ailang-run-exit-code-false-alarm.md` — mandatory before measuring any negative
   probe or pipeline. Capture rc adjacent to the command; never inspect `$?` after a pipe.

## Verified-at, and when to re-verify

The plan's anchors were read on 2026-07-03 with AILANG v0.26.0 (`3b52a24`). Before editing:

- `ailang --version` must report v0.26.0 / `3b52a24`; if not, STOP and flag.
- `git log --oneline -10` should show the plan commit `34f901a` plus any handoff/review doc
  commits. If `src/`, `scripts/`, `Makefile`, or TUI files changed after the plan review,
  re-grep every affected anchor before editing.
- Run the inherited green checks once before production edits:

```bash
PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_b_blessed
ailang test src/core/phase_vocab.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

## Review fixes to preserve

The plan has been corrected for several implementation traps. Do not regress these while
executing it:

- **WI-C1 necessarily changes production bytes.** Replacing the interim `payload_digest`
  changes `provider_call_prepared.payload_digest`. WI-C1 must land a D-B7 expected-diff
  table, verify no other event line changed, then bless `/tmp/phase_c_blessed`. WI-C2 and
  later diff against `/tmp/phase_c_blessed`, not `/tmp/phase_b_blessed`.
- **The sealing probe is intentionally negative.** The final gate wraps
  `ailang check scripts/probe_phase_vocab_sealed.ail` so failure with `IMP010` is the pass
  condition under `set -euo pipefail`.
- **DP7 policy belongs in `step_machine`.** The verifier command is a port effect, but
  deciding pending verification, rejection -> `InjectUserMessage`, fail-open, and
  `Finalize` is pure policy. If that cannot fit existing `StepDecision`/state shapes,
  record an ADR gap before inventing a new constructor.
- **Approval order is pinned.** The scripted approval scenario must assert
  event-before-read; EOF/unparseable default handling; denial message behavior; and, on
  approval, execution of the approved call before the suspended `remaining` tail is
  reissued in original order.

## Phase C load-bearing sequence

- WI-C0 creates instruments only; no production behavior change and no baseline change.
- WI-C1 makes checkpoint/payload digests real and creates the first Phase C blessed parity
  baseline through an expected-diff table.
- WI-C2 lands pure `step_machine`, `cost_phase`, and `recovery` without routing production
  through them yet.
- WI-C3 adds ports and the in-memory ledger while `run_v2_with_stub` still works.
- WI-C4 inverts approval before batching the full tool phase; this unblocks `PhaseResult`
  extraction.
- WI-C5 routes through `session.ail` and the module split. This is the most likely event
  ordering diff; follow D-B7 exactly.
- WI-C6 migrates the parity fleet to scripted ports, leaving `run_v2_with_stub` only as a
  compatibility adapter.
- WI-C7 completes the L1 scenario family under `--caps IO` or less, no real model/network.
- WI-C8 is the final gate; run it as written.

## Discipline

- The reviewed plan is authoritative. Contradictions with HEAD are findings, not license to
  redesign.
- Every new substrate-defect claim needs a minimal repro before it enters a note, plan, or
  commit message.
- Run the WI verification block at every WI boundary. If parity differs, classify the diff
  before changing code or baseline: event-order-only, missing/extra line, or payload change.
- Keep `run_v2_with_stub` alive as a strangler adapter until the fleet has migrated; deleting
  it early orphans the inherited parity instrument.
- Do not touch unrelated dirty work. At handoff time `oh-my-pi/` was an unrelated untracked
  directory.
