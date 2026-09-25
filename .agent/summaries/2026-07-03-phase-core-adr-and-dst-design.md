# 2026-07-03 Phase-oriented core design, DST-first, from research to reviewed ADR

## Context

This session (2026-07-02 → 2026-07-03, branch `arniwesth/mot-26-csp-initial-research`,
AILANG v0.26.0 commit `3b52a24`) started from the post-revert direction note
`.agent/projects/003_CSP_core_refactor/NOTE-why-not-csp-now.md` and the operator's framing
constraint: the new core architecture must facilitate Deterministic Simulation Testing
(`.agent/projects/001_DST/ADR-001-...md`) as well as possible. The session produced the entire
`004_phase_core_refactor` project: research doc, substrate smokes/probes, a checked vocabulary
sketch, a three-times-reviewed and dispositioned ADR, and the handoff for the Phase A plan.

## Core thesis established

The phase-oriented core and DST are the same design pressure seen from two sides: **functional
core, imperative shell**. A pure step machine returns decisions-as-data; phases perform effects
only through injected **ports** and return `PhaseResult` values; a single pure transcript
builder is the only producer of provider-facing messages; a thin driver owns the real effect
row and appends an event **ledger that IS the DST trace** (resolving DST ADR-001's R4/R7/R8/R11
by construction).

## Decisions settled (full log in RESEARCH doc §9)

- **D1** Full inversion: pure `decide(StepState, StepPolicy) -> StepDecision` in Phase C.
- **D2** Ports record for all nondeterminism sources; substrate-validated.
- **D3** Compaction as a pure projection `History -> ProviderPayload` with sealed types
  (ephemerality and system-hiding by construction) — later amended by D9.
- **D4** All six `agent_loop_v2` squatters mapped (persist-nudge → step machine; hybrid-bash
  correlation → transcript gate; scratchpad → executor registry; approval `readLine` →
  `AwaitApproval` decision; cost/retry → step machine; DP7 → decision + port).
- **D5** Ledger/trace unification with single-point emission and patch-style `StateDelta`.
- **D6** ABI v3 scope: ports-in-`ExtCtx` + `artifacts` channel; no effect-row changes
  (three hooks already pure in 2.2.0); conformance kit as separate package.
- **D7** `Checkpoint` seam blessed in v1 types: sealed `History`, single self-auditing rebuild
  op returning `{history, event}`, digest-chained, v1 never emits it (enforced by scenario).
- **D8** Conformance kit: `invariants` (pure contract law, imported by core's gate — one
  source of law) + `harness`; **caps-as-conformance** enforcement (fake ports + minimal caps
  make raw effect calls fail at performance time); composition excluded by fault-isolation
  design.
- **D9** (2026-07-03, after review) **Extension-resident compaction**: core keeps only the
  scaffold (pin/gate/measurement/exhaustion); `dispatch_pre_step` becomes a fold-through
  **compactor chain** (registry order = pipeline order; every stage validated and
  ledger-recorded); the 70/85/95 ladder relocates to bundled `motoko_ext_compaction_structural`
  (pure, registered last); ABI v3 additionally gains `ExtCtx.telemetry`. Closes the
  actual-token-gating question: it's compactor policy now.

## Substrate results (all artifacts checked/run on v0.26.0)

- `scripts/smoke_ports_record.ail`: records of effectful function fields work; pure fakes
  subsume (even unannotated); **caps are charged at effect performance, not row declaration**
  (fakes-only entry runs under `--caps IO` despite declared `{Clock, Env}`) — the result the
  whole L1 DST story rests on. Parser gotchas recorded (no zero-arg anonymous `func()`; no
  anonymous `func` in record literals).
- `004/sketch/` opacity probes: unexported variant constructors are sealed (`IMP010`);
  unexported type names are unimportable → **co-location binds definers only** — exported
  wrappers embedding sealed types cross module boundaries with transitive sealing
  (`vocab_probe.ail` + `probe_consumer_decide.ail`, written to adjudicate the review).
  Exported records are structurally forgeable → sealed types must be variants.
- `004/sketch/sketch_vocabulary.ail`: full type vocabulary checks/runs/tests — sealed
  History/Segment/Payload, `StepState`/`StateDelta`/`apply_state_delta`, `StepDecision`,
  `PhaseResult` (no continuation field — re-derivation **proven**: demo drives
  `CallModel → RunTools → Finalize` from applied state), `LedgerEvent` + `to_schema_v1`
  projection, prefix-preserving `checkpoint` + atomic `apply_checkpoint`.

## Live bugs found in production code (verified, not yet fixed)

1. Extension compactors receive system messages (`rpc.ail:231` + `agent_loop_v2.ail:1154`).
2. `motoko_ext_compaction_ai` v0.2.0 destroys the system prefix above its threshold
   (`split_msgs` is position-only) and can sever tool_use/tool_result pairs; also
   re-summarizes every step (no cache) and duplicates core's token estimator.
   Both become the conformance kit's fail-then-pass acceptance targets.

## ADR and review cycle

`ADR-001-phase-oriented-core.md` drafted in-session (decision log as skeleton, artifacts as
evidence), then independently reviewed by **three models** (GPT-5 Codex, GLM 5.2, Opus 4.8)
per `HANDOFF-review-adr.md`. 13 unique findings; all adjudicated with re-verification in the
authoring session (dispositions appended to the ADR):

- 10 accepted, including the two highest-value: the **actual/estimate compaction split no
  longer exists in source** (single 70/85/95 ladder; DST ADR-001 R5/R15 premises stale) and
  the sketch's checkpoint **destroying the system prefix** — the exact bug class the design
  exists to prevent (fixed; `checkpoint_output_is_valid_transcript` is now a v1 obligation).
  Also: 28→29 event inventory (`reasoning_delta` was missing), streaming timing vs.
  single-point emission (resolved with a driver-issued ledger append handle), checkpoint
  digest/atomicity mechanics, approval protocol contract, phantom conformance targets, ABI
  migration overclaim, hydration-gate separation, emit-site count (48, not ~30).
- 2 partially accepted ([prod]/[NEW] projection name classes; continuation proof).
- 1 conclusion **refuted with a new probe**: all three reviewers assumed separate
  `step_machine.ail` was impossible under sealing; the exported-wrapper probe disproved it.

## Meta-artifacts

- `NOTE-plan-authoring-session-choice.md` — verbatim capture of the session-vs-fresh
  reasoning, generalized into a reusable rule (context-heavy artifacts → authoring session;
  source-heavy/citation-dense artifacts → fresh session at HEAD; review → always fresh;
  handoffs cash out residual context). Also saved to agent memory
  (`artifact-session-matching`).
- `HANDOFF-write-phase-a-plan.md` — next session's mission: `PLAN-phase-a-pure-foundations.md`
  for Phase A only, with mandatory re-verify-at-HEAD discipline and an "ADR gaps found"
  section (the fresh writer doubles as the ADR-completeness test).

## State at session end

Committed by the operator: the 004 project through the D9 amendment (research doc, sketch +
probes, ADR with reviews and disposition log, review handoff), plus `scripts/smoke_ports_record.ail`.
Uncommitted at time of writing: `NOTE-plan-authoring-session-choice.md`,
`HANDOFF-write-phase-a-plan.md`, this summary.

## Next steps

1. Fresh session executes `HANDOFF-write-phase-a-plan.md` → Phase A plan.
2. Amend DST ADR-001 R5/R15 to the single-tier source reality (flagged, not yet done).
3. Optional git-history read: when/why the actual-token compaction path was removed
   (informational now — D9 made it compactor policy).
