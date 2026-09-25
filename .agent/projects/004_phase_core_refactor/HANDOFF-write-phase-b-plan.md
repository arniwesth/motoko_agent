# Handoff: write the Phase B implementation plan

Date: 2026-07-03 (post-Phase-A; written by the Phase-A plan-authoring/review session)
Audience: a fresh agent session. You are deliberately fresh — same reasoning as
`NOTE-plan-authoring-session-choice.md`, now stronger: Phase A just rearranged the very
files Phase B edits, so any prior session's line-number knowledge is stale by construction.
Your freshness is again a test: **if you cannot produce this plan from the committed
documents plus the Phase A commits, the ADR has a gap — report it in an "ADR gaps found"
section, don't guess around it.**

## Mission

Write `PLAN-phase-b-phase-results.md` in this directory: the implementation plan for
**Phase B only** of `ADR-001-phase-oriented-core.md` — phases return `PhaseResult`, driver
keeps current control flow. Do NOT plan Phase C. Do NOT plan ABI v3 / conformance kit
(parallel track) — with ONE boundary exception: `motoko_ext_compaction_structural` is a
Phase B deliverable (it is pure, needs no ports, and ships against ABI **2.2.0**; it
re-certifies on 3.0 later). Do NOT start implementing.

## Reading order

1. `ADR-001-phase-oriented-core.md` — normative. Phase B deliverables + gate are your
   acceptance criteria, **including the 2026-07-03 additions** in the Phase B section:
   (G3c) retire the vestigial model-keyed compaction wrappers with the ladder relocation;
   (G7) a minimal in-repo test extension (scripted `Handled` + `ContinueWithFeedback`) so
   extension-path message construction is e2e-coverable. Read the three Review Comments
   passes, the Disposition Log, and the Plan-Authoring Findings & Dispositions log (G1–G8)
   — all of it is settled; none of it is yours to re-litigate.
2. **The Phase A as-built commits** — `660c4b5` (WI-0 harness), `6eb735a` (constants),
   `e8242b3` (phase_vocab), `ccd43d2`/`d0d5b7e` (extraction). There is **no implementation
   findings note**; the diffs are the ground truth for Phase A's real shape. Read
   `src/core/phase_vocab.ail` as built, not as the sketch or the Phase A plan describe it —
   and record any plan-vs-as-built deviations you find in your grounding section.
3. `RESEARCH-phase-core-dst-design.md` — §7.5 (D9 chain semantics — the core of Phase B),
   §2 P2 (ledger), §7.2 (pipeline), §11 facts (incl. 16–19).
4. `PLAN-phase-a-pure-foundations.md` — house style to follow, and the G1–G8 record. Its
   `agent_loop_v2.ail` line anchors are **pre-implementation — do not reuse a single one**.
5. `NOTE-ailang-run-exit-code-false-alarm.md` — the measurement discipline (pipefail,
   minimal repro before defect claims, never `$?` through a pipeline).
6. `../001_DST/ADR-001-…` — the provider-call recording seam Phase B must land is that
   ADR's "required first seam"; its R5/R15 carry 2026-07-03 amendment notes.

## Non-negotiable discipline

- Re-verify **every** citation against post-Phase-A HEAD; `git log --oneline -15` first.
  Re-run before relying on: `ailang test src/core/phase_vocab.ail`, `make smoke_parity`
  (self-diff mode), the sketch probes if you lean on sealing claims.
- Every source claim in YOUR plan carries a `file:line` you verified yourself at HEAD.
- A substrate-defect claim requires a minimal repro before it enters the plan (the note's
  lesson — this project almost filed a false one).

## Phase B deliverables (from the ADR — re-read it; summary, not substitute)

1. **All event emission through the ledger + `to_schema_v1`** — 48 call sites centralize;
   typed `LedgerEvent` in memory, JSONL projection at the driver.
2. **Streaming protocol**: driver-issued ledger **append handle** (port scoped to
   stream-delta events, arrival-order writes) so `thinking_delta`/`reasoning_delta` timing
   is preserved; byte-parity test for `thinking_stream_start → N×delta →
   thinking_stream_end`.
3. **Provider-call recording seam** — `provider_call_prepared` ledger events around the
   model phase (DST ADR-001's first seam), consumed by at least one L1 test.
4. **Core-side system-prefix fix** — pass `CompactableSegment`, not the raw list, to
   `dispatch_pre_step` (zero ABI cost; closes the live §7.0 gap).
5. **(D9) Compactor chain** — `dispatch_pre_step` converts from first-`Compacted`-wins to
   fold-through; gate validates every stage (invalid ⇒ `ext_compaction_rejected`, skip,
   continue); registry order = pipeline order; each stage ledger-recorded.
6. **Ladder extraction** → new package `motoko_ext_compaction_structural` (pure; registered
   last; ships against ABI 2.2.0), taking WI-1's seven named constants with it. Decide
   *during this extraction* (ADR Open Question 4 remnant): whether the emergency path moves
   too — the ADR's recorded lean is yes, zero-compactor core behavior is honest exhaustion.
7. **(G3c)** retire `compact_step` / `usage_percent` / `try_emergency_compaction` /
   `context_limit_for` (dead model-keyed wrappers; evidence in ADR G3 + research fact 19).
8. **(G7)** the minimal in-repo test extension, so the parity/e2e story covers
   `envelope_to_tool_message` / `handled_tool_message` paths before emission rewires.

**Gate (from the ADR, re-read the exact wording):** the projection's emitted `type` set for
[prod] constructors is a **byte-compatible subset** (modulo the G4 volatile fields —
definition inherited from Phase A's gate) of the **mechanically regenerated 29-name
inventory** (regeneration command in `phase_vocab.ail`'s comment block — regenerate, never
hand-count; Phase B itself changes the emission sites, so regenerate against the *pre-B*
baseline); **[NEW] names admitted only after the TUI unknown-type tolerance check**; the
streaming byte-parity test passes; `system_messages_hidden_from_compactors` verified in
wiring. The Phase A parity harness + `make smoke_parity` are the inherited instrument —
Phase B's plan must state how the baseline is re-captured and which diffs are *expected*
(none for [prod]; additive-only for [NEW]).

## Session residuals worth having (things the docs underemphasize)

- **The TUI has never been read in this project.** The unknown-type tolerance check
  requires surveying `src/tui`'s event consumption (`runtime-process.ts`, `ui.ts` were
  named in the 003 plan's blast-radius section as the consumers). Budget real time there.
- **G8 remainder intersects Phase B directly**: `smoke_v2_compaction_ai.ail` and
  `smoke_v2_compaction_ai_registry.ail` are among the 11 still-broken scripts, and they sit
  exactly where the chain conversion works. Your plan will need them repaired or replaced —
  decide which, and say so.
- The chain conversion is behavior-preserving **only** because structural-registered-last
  equals today's sequential composition (`ext → structural`, `agent_loop_v2` region around
  the old `:1154→:1171` — re-find these anchors post-A). If the plan sequences the chain
  before the ladder extraction exists as a package, today's behavior must be reproduced by
  a shim; call the ordering explicitly.
- `dispatch_pre_step` consumes `messages_to_msgs(msgs)` (ABI `Msg`), deliberately NOT moved
  in Phase A — the Phase A plan's survey says its Phase B home is the `CompactableSegment`
  boundary. That's deliverable 4's seam.
- Packaging precedent for the new extension: `packages/` layout + `registry_generated.ail`
  + `scripts/sync-extension-packages.sh` (`make sync_packages`). The conformance kit is NOT
  Phase B; do not let the reference-consumer language pull it in.

## Plan output contract

House style per the two prior plans. Must include: ordered WIs with file-level change
lists, per-step verification commands, per-step rollback, the gate checklist as the final
step; an "ADR gaps found" section (empty is a valid finding); an explicit out-of-scope list
(Phase C, ABI v3, conformance kit, checkpoint digest); the toolchain you verified against
(`ailang --version` — the pin is v0.26.0/`3b52a24`; if it moved, STOP and flag); and an
anchor re-verification log. Strangler discipline: every WI leaves the system shippable and
`make smoke_parity` explicable (identical, or additive-[NEW]-only with the tolerance check
green).

## Constraints

- D1–D9 and dispositions G1–G8 are settled. Contradictions between ADR and HEAD are
  findings, not license to redesign.
- One plan per phase: Phase C gets its own plan once Phase B's real shape is known.
- Do not modify the ADR, research doc, sketch, or Phase A plan. Your plan is a new file.
