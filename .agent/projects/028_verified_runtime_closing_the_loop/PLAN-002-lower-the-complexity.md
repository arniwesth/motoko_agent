# PLAN-002 — Lowering complexity without losing the fossil record

Companion to ADR-002; evidence in NOTE-003. Items ordered by leverage per unit
of risk. Every item reuses an in-repo pattern (no new mechanism types). Does
not overlap PLAN-001 (enforcement gaps) — this plan is comprehension cost.

## 1. Glossary generation + gate (stops the bleeding)

- New `tools/glossary_gen/` (pattern: `tools/ext_registry_gen/`) over one
  source file mapping every `WI-…`, `M-MOTOKO-…`, `D#`, ADR id → one-line
  meaning + canonical doc link.
- Amended (NOTE-004, from 026): the source file is a SCHEMA, not a flat list —
  objects/links/actions: each id an *object* (meaning, status, owning sprint);
  typed *links* between ids (`relates-to`, `supersedes`, `blocked-by`); the
  *actions* are the gates themselves with preconditions ("id resolves",
  "caller is not new"). Emit a machine-readable index (JSON) so tooling or
  DST invariants can traverse it; `.agent/glossary.md` is the rendered view.
- `make glossary_check`: fail when a comment cites an id absent from the
  glossary (same posture as the DST demo-scale leak check).
- Acceptance: `grep -rhoE "WI-[A-Z0-9]+" src/core/*.ail | sort -u` all resolve;
  a planted `WI-9999` reference fails the gate.

## 2. Surface check, then retire the compatibility adapters

- `make check_surface`: fail on NEW callers of deprecated entries
  (`run_v2_with_stub_port_adapter` et al. in `session.ail` ~L3376-3420) —
  makes the existing "kept until they are audited" comments enforceable.
- Then audit and delete; target: one `run_v2*` entry point.
- Replace 12 positional parameters with a closed options record
  (`RunV2Options`) — AILANG records are closed, so this is strictly more
  type-safe and kills the adjacent-int transposition footgun NOTE-003 measured.

## 3. Split the hubs along recorded seams

- `phase_vocab.ail` (52 types, fan-in 13) → `phase_events` (LedgerEvent +
  info records; companion to `dst_event_vocabulary`), `phase_state`
  (StepState/delta/history), `phase_policy` (policies, telemetry, budgets).
- `session.ail` (3,706 lines) → loop body / DP7 gate / scripted-ports
  fixtures — moving `stub_step` + `scripted_ports` OUT of the production
  import graph (today `rpc.ail` imports `src/core/test/stub_step`).
- Precedent to cite in review: the `dst_program` → `dst_interaction` split and
  its header rationale. Blast-radius metric: hub fan-in 13 → most changes
  touch one module.

## 4. Runnable tour (docs that cannot rot)

- Promote this session's five demo files into `examples/tour/` with CI runs:
  `step_machine_drive` (decide), `loop_demo` (end-to-end loop),
  `checkpoint_demo` (calibration + checkpoint), `dst_demo` (PRNG),
  `events_demo` (ledger vocabulary).
- Each file must keep `ailang check` green in CI — the mechanism whose absence
  rotted `discount_calculator.ail` (NOTE-002 defect 2).
- Acceptance: a newcomer runs five commands and has seen every subsystem.

## 5. Failure-mode triage rule

- Toolchain rule: every failure is (a) diagnostic + fix-hint, or (b) skip +
  reason — never a hang, never a silent success.
- First two pinned members: `PAR_INFINITE_LOOP` on escaped-quote-in-
  interpolation (must become `PAR0xx` with position + hint), and the
  scratchpad batch veto reported as `exit_code: 0` (PLAN-001 item 2's
  regression covers it).

## 6. Symbol-anchored references

- Doc convention: reference code by symbol path, not line number
  (`session.ail#run_v2_with_scripted_ports`, not `session.ail:L3376`).
- Line anchors rot: 026's research note cites `types.ail:592/594/1010` —
  all three verified still-correct on 2026-08-30, but they are positions,
  and the substrate is under active change. Same rot class as
  `discount_calculator.ail` (NOTE-002 defect 2).
- Fold into item 1's generator: `glossary_check` also validates that doc
  references resolve to a symbol that exists; lint `:\d+` anchors in
  `.agent/` notes as warnings.
- Acceptance: a no-op reflow of `types.ail` breaks zero references.

## Sequencing (co-schedule with the ABI major)

- NOTE-002 W1-W3 (verifier re-wiring to unlock folds) and 026 §7.2
  (`Deny(Refusal)` — a second ABI major) both touch cross-cutting matched
  types. Land them as ONE gated change: one ABI/verifier major, one
  changelog entry, ADR-001/ADR-002 rationale updated in the same commit.
- The refusal record `{code, reason, retry_hint}` (026 §3.1) is the same
  shape item 5's triage rule needs for parser/runtime failures — design it
  once, use it at both boundaries.

## Non-goals

No rewrite of working code, no deletion of WI history, no doc-coverage CI
metric, no big-bang Makefile migration (generate the check matrix from a
manifest as a later item instead).
