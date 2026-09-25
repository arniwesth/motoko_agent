# Vocabulary sketch — pre-ADR substrate validation

Date: 2026-07-02, revised 2026-07-03 in response to the three-pass ADR review.
Toolchain: AILANG v0.26.0 (commit `3b52a24`).
Companion to `../RESEARCH-phase-core-dst-design.md` and `../ADR-001-phase-oriented-core.md`.
These files are **validation artifacts, not implementation** — the deliverable is that they
check/run and the questions below have empirical answers.

## Run

```bash
cd .agent/projects/004_phase_core_refactor/sketch
ailang check sketch_vocabulary.ail                       # passes
ailang run --caps IO --entry main sketch_vocabulary.ail  # demo: re-derivation, checkpoint, stream projection
ailang test sketch_vocabulary.ail                        # inline pure tests
ailang run --caps IO --entry main probe_opacity_legal.ail
ailang check probe_opacity_forge.ail                     # PASSES (export type exports ctors)
ailang check probe_sealed_forge.ail                      # FAILS IMP010 (ctor sealed)
ailang run --caps IO --entry main probe_sealed_name.ail  # FAILS IMP010 (type name not importable)
ailang run --caps IO --entry main probe_rec_structural.ail # runs (records forgeable)
ailang run --caps IO --entry main probe_consumer_decide.ail # runs (REVIEW ADJUDICATION — see Q1)
```

## Q1 — Is D7's opacity assumption real? YES; co-location applies to DEFINERS only

- `export type T = C(...)` exports the constructor too → forgeable (`probe_opacity_forge`).
- An **unexported** variant type with exported ops is truly sealed: constructor import fails
  `IMP010` (`probe_sealed_forge`); values still thread (`probe_sealed_thread`).
- The unexported **type name** is not importable (`probe_sealed_name`), so any type that NAMES
  a sealed type in its definition must be co-located with it.
- **Review adjudication (2026-07-03, refutes Pass-1 R1 / Pass-2 R3's conclusion):**
  `vocab_probe.ail` + `probe_consumer_decide.ail` prove that a *separate* module can import
  **exported wrapper types** that embed or carry sealed types (`StateP { hist: SealedH }`,
  `DecisionP = CallModelP(SealedP)`), define functions over them, construct decision variants
  (payload obtainable only via ops), and pattern-match binding sealed payloads. Sealing holds
  transitively. So `step_machine.ail` / `model_phase.ail` CAN be separate modules; only the
  **vocabulary module that defines the sealed types and the exported wrappers naming them**
  is co-located. Bare sealed-type parameters in foreign signatures remain impossible — hence
  the exported `ModelRequest` wrapper for the model phase.
- Exported **record** types are structurally forgeable (`probe_rec_structural`) — sealed types
  must be single-constructor **variants**.
- D7's `checkpoint`/`apply_checkpoint` shape runs end-to-end **and preserves the pinned system
  prefix** (revised per Pass-3 R1; the original sketch dropped it — a real catch). Note: "runs"
  demonstrates the SHAPE; transcript-validity of checkpoint output is a stated v1 obligation
  gated by scenario `checkpoint_output_is_valid_transcript`, not something this sketch proves.
  The digest remains a labeled placeholder (length-based, forgeable); the real design is a
  content hash with previous-digest chaining and seed-time chain validation.

## Q2 — Can one LedgerEvent type serve both event vocabularies? YES, with two name classes

`LedgerEvent` constructors are the typed/DST-canonical layer; `to_schema_v1` targets the
**production wire stream**. Corrected inventory (Pass-1/2/3 R2): **29** JSONL `type` values —
27 `emit_event` names + `thinking_delta` + `reasoning_delta` (both emitted directly via
`emit_json`, `agent_loop_v2.ail:255,:265`). Regeneration command is in the sketch's comment
block; the Phase B gate compares against the *generated* inventory, not a hand count.
Every constructor is classified `[prod]` (projects to an existing production name —
byte-compatible-subset gate) or `[NEW]` (additive name, e.g. `history_checkpoint`,
`provider_call_prepared` — gated by a TUI unknown-type tolerance check). `StreamDelta` covers
both delta types by payload kind.

## Q3 — How is state_delta expressed? Patch-record with one application point

`StateDelta` = record of `Option` fields (absent = unchanged), applied ONLY by
`apply_state_delta`. `apply_checkpoint` is the one additional state path — atomic
history-rewrite + event pairing (Pass-1 R4 / Pass-2 R6).

## Q4 — Do StepDecision variants carry what they need? YES — and re-derivation is now PROVEN

Revised per Pass-3 R3: `StepState` carries typed re-derivation fields
(`pending_tool_calls`, `last_finish_reason`, `last_response_text`); the placeholder
`pending_decision_seed` is retired. The demo drives `decide` through
`CallModel → RunTools → Finalize` purely from applied state — continuation is state, there is
no continuation field. `ApprovalRequest` now carries the live protocol's needs
(`default_allow`, `stream_id`, suspended `remaining` plan tail — Pass-1 R5 / Pass-2 R5).
`CompactionPolicy` is re-grounded on current source's single 70/85/95 tier table
(Pass-2 R1 / Pass-3 R4).
