# Handoff: write the Phase A implementation plan

Audience: a fresh agent session. You are deliberately fresh — see
`NOTE-plan-authoring-session-choice.md` for why the plan is written by you and not by the
session that wrote the ADR. Your freshness is also a test: **if you cannot produce this plan
from the committed documents alone, the ADR has a gap — report the gap, don't guess around
it.** Collect any such gaps in an "ADR gaps found" section of the plan.

## Mission

Write `PLAN-phase-a-pure-foundations.md` in this directory: the implementation plan for
**Phase A only** of `ADR-001-phase-oriented-core.md` — pure foundations, zero behavior change.
Do NOT plan Phases B/C or the ABI track (one plan per phase; Phase B gets its own plan once
Phase A's real shape is known). Do NOT start implementing.

## Reading order

1. `ADR-001-phase-oriented-core.md` — normative; Phase A deliverables + gate are your
   acceptance criteria. Read the three Review Comments sections and the Author Response &
   Disposition Log too: they show which claims were contested and how they were resolved.
2. `RESEARCH-phase-core-dst-design.md` — elaboration; §4.1 (sketch answers), §7 (compaction,
   incl. §7.5/D9), §11 (facts list — substrate rules you must obey).
3. `sketch/README.md`, then the sketch/probe files — run them all before relying on them.
4. `NOTE-plan-authoring-session-choice.md` — context for your role.
5. `../003_CSP_core_refactor/PLAN-phase1-run-tool-select.md` — the house style for plans.

## Non-negotiable discipline (the staleness lesson, made procedural)

This project's proven failure mode is trusting document-recorded source facts after the source
moved (see ADR disposition log, P2-R1/P3-R4). Therefore:

- Re-verify **every** `file:line` citation you inherit from the ADR/research doc against HEAD
  before using it in the plan. `git log --oneline -20` first; note any commits newer than
  2026-07-03 touching `src/core/` and treat all inherited citations as suspect if there are
  any.
- Re-run the artifacts before citing them: `sketch/sketch_vocabulary.ail`
  (`ailang check` / `run --caps IO --entry main` / `test`), the opacity probes (forge probes
  MUST fail `IMP010`), `scripts/smoke_ports_record.ail` (fake entry under `--caps IO` only).
- Every source claim in YOUR plan carries a `file:line` you verified yourself at HEAD.

## Phase A deliverables (from the ADR — re-read it; this is a summary, not a substitute)

1. **Vocabulary module** (working name `src/core/phase_vocab.ail`; final name is ADR Open
   Question 1 — the plan should propose and justify a choice), seeded from
   `sketch/sketch_vocabulary.ail`. The plan must decide and justify what lands in Phase A vs.
   later: types can land unused (LedgerEvent, StepState, StepDecision, PhaseResult,
   sealed History/Segment/Payload + ops), but nothing may be *wired into* production paths —
   `decide` is Phase C, ledger emission is Phase B, checkpoint is types-only (v1 never emits).
2. **Compaction constants/primitives**: verify what already exists (`estimate_tokens`,
   `usage_percent` are already `export pure func` in `compaction.ail` — the "export" work is
   partly done); export the tier constants (`ELIDE_TIER_PCT=70`, `ELIDE_HARD_TIER_PCT=85`,
   `EMERGENCY_PCT=95`, keep-last 10/5) as named exports replacing inline literals. Under D9
   these constants later relocate with the ladder (Phase B) — Phase A just names them.
3. **Transcript builder extraction**: the pure provider-message constructors
   (`step_result_to_message`, `envelope_to_tool_message`, `tool_result_message`,
   `cap_tool_message_content`, and whatever else your call-site survey finds) move to the
   vocabulary module (or a sibling — plan's choice, justified), with `agent_loop_v2.ail`
   importing them. Enumerate EVERY call site; this is the survey the plan exists to do.

**Gate (verbatim from the ADR):** `ailang check` + existing smokes green; **no event-stream
diff**. The plan must specify how the no-diff gate is checked mechanically (e.g., a scripted
run with `Scripted` provider before/after, JSONL streams compared byte-for-byte).

## Substrate rules you must obey (all proven in `sketch/` — do not re-derive, do re-run)

- Sealed types = **unexported single-constructor variants**; exported records are structurally
  forgeable. Unexported type *names* are unimportable → types naming sealed types co-locate in
  the vocabulary module; consumers use exported wrappers (`vocab_probe.ail` +
  `probe_consumer_decide.ail` prove wrappers cross module boundaries with transitive sealing).
- Imports lexically precede all declarations. Zero-arg anonymous `func()` does not parse.
  Anonymous `func` can't sit directly in record literals (let-bind). A match-arm RHS starting
  with a record literal parses as a block (let-bind it). Unused function-typed params get
  effect rows narrowed since v0.21 (`let _ = f in` pins).
- The 29-event inventory regeneration command is in the sketch's comment block. Phase A does
  not touch events, but the plan's no-diff gate needs the inventory to compare against.

## Plan output contract

Follow the 003 plan house style. Must include: ordered steps with file-level change lists;
per-step verification commands; a rollback note per step; the gate checklist as the final
step; an "ADR gaps found" section (empty is a valid finding); an explicit "out of scope"
list (Phase B/C/ABI items readers might expect). State the toolchain you verified against
(`ailang --version`).

## Constraints

- Do NOT re-litigate D1–D9 (decision log in the research doc records operator sign-off).
  Contradictions between the ADR and HEAD source are findings for "ADR gaps found", not
  license to redesign.
- Phase A changes NO behavior: no event-stream changes, no ABI changes, no dispatch changes
  (the compactor chain is Phase B), no new production code paths — extractions and additions
  of unused pure code only.
- Do not modify the research doc, ADR, or sketch. The plan is a new file.
