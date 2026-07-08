# Handoff: write the checkpoint-trigger implementation plan (Plan 3)

Date: 2026-07-08 (written by the conformance-kit implement-and-verify session, which holds the
frozen-law context Plan 3's checkpoint-output obligation consumes)
Audience: a fresh agent session that will **author** `PLAN-checkpoint-trigger.md`. You are
deliberately fresh, per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`. Obey
`re-ground-inherited-anchors-before-building.md`: every `file:line` below is a starting point from
2026-07-08 (HEAD `4371de0`), not a fact — re-run the observation before you build on it. Line
numbers in `src/core/session.ail` drift heavily (the scope note's `:1293` handler anchor already
moved to `:1347` between authoring and now).

## Mission

Write `PLAN-checkpoint-trigger.md` in this directory: the implementation plan for **Plan 3** in
`NOTE-remaining-dst-work-scope-and-sequence.md` — wiring the *emission* of `TakeCheckpoint` into the
live loop so a long session has a designed, audited escape (checkpoint) instead of silent death.
The machinery is **already built**; Plan 3 is about the **trigger** — when, where, and under what
policy the loop decides to checkpoint, plus the termination guard that stops it looping.

This is the **last of the three DST plans.** Plan 2 (ABI v3) and Plan 1 (conformance kit) are both
**done and gated green** (`make conformance` and `make check_core` pass at HEAD). Plan 3 is
**largely independent** of both — it touches `step_machine`, `session`'s seal path, `phase_vocab`,
and the checkpoint scenarios, not the ABI or the kit.

Do **NOT** implement. Do **NOT** re-open the checkpoint *mechanics* (D7 froze them: `checkpoint` /
`apply_checkpoint` / digest chain / resume validation are built). This plan decides the *trigger
policy* and wires emission, then amends ADR-001 D7.

## What is already built (re-ground each at HEAD before trusting)

The checkpoint **seam** shipped in Phases A–C; only the trigger is missing. Confirmed at HEAD
`4371de0`:

- **`phase_vocab.ail`** — `checkpoint(History, CheckpointPlan) -> {history, event}` (`:239`, the sole
  History-rewrite op); `apply_checkpoint(StepState, CheckpointPlan) -> {state, event}` (`:323`, the
  atomic driver path); `StepPolicy` (`:270`); `TakeCheckpoint(CheckpointPlan)` as a `StepDecision`
  variant (`:367`); `validate_checkpoint_chain` (`:494`); digest-chain tests (`:900`).
- **`step_machine.ail`** — `decide(s: StepState, pol: StepPolicy) -> StepDecision` (`:78`) is the
  pure decision fn. **It never returns `TakeCheckpoint` today** (grep its arms: `CallModel`,
  `Finalize`, await/inject/fail — no `TakeCheckpoint`). A guard at `:353` treats `TakeCheckpoint(_)`
  as a distinct case. `mk_policy` (`:109`) builds the `StepPolicy` — the natural home for a trigger
  threshold + flag.
- **`session.ail`** — the **handler is already wired**: `TakeCheckpoint(plan) => apply_checkpoint(
  step_state, plan)` (`:1347-1348`; scope note said `:1293` — drifted). So if `decide` ever emits
  `TakeCheckpoint`, the loop already applies it. What's missing is the *emission*, not the handling.
- **The v1-never-emits contract is enforced by scenario**, not convention: ADR-001 D7 (`:227`) says
  "v1 policy **never emits** `TakeCheckpoint`," and `scripts/phase_c_l1_scenarios.ail:298,315`
  (`checkpoint_never_emitted_in_v1`) **fails if `decide` returns `TakeCheckpoint`**. Turning on
  emission collides with this scenario head-on — reconciling it is a first-class part of your plan
  (see the policy-flag-default decision below), not an afterthought.
- **Checkpoint output is already governed by the conformance law you inherit.** ADR-001 D7(e)
  (`:223-225`): checkpoint output carries the *same* transcript-validity obligations as ext
  compaction (system prefix / pairing / ids), enforced by the **same gate** and by scenario
  `checkpoint_output_is_valid_transcript` (`phase_c_l1_scenarios.ail:172`). That gate's law now lives
  in `packages/motoko_ext_conformance/invariants.ail` (`validate_compactor_output`, moved out of
  `phase_vocab` by Plan 1, imported back at `runtime.ail:27`). **Your plan must route checkpoint
  output through that same predicate** — do not reintroduce a second copy of the law.

## Reading order

1. `NOTE-remaining-dst-work-scope-and-sequence.md` — Plan 3's boundaries (lines 42-48, 57-61) and
   why it is largely independent and may run in parallel with the others (now moot; it's last).
2. `ADR-001-phase-oriented-core.md` **D7** — the checkpoint decision + frozen mechanics: §4 bullet
   "The checkpoint seam" (`:215-228`) is the spec for what's built and the v1-never-emits invariant;
   the rationale ("long-session ceiling has a designed escape," `:512`) is the *why*. This is the
   section you amend on landing.
3. `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — **the emission-site tension.**
   Its §2 (`:70-95`) establishes that `seal_compacted_payload` is the **single, unconditional,
   effectful send-gate** (`session.ail:1402`) and that `project`/`decide` is **pure and vestigial for
   the payload** — "`project` cannot run the effectful compactor … is necessarily `seal`." This is
   exactly the fork your emission-site decision turns on (below).
4. Source you wire (re-ground each at HEAD): `src/core/step_machine.ail` (`decide`, `mk_policy`, the
   `:353` guard), `src/core/session.ail` (the `TakeCheckpoint` handler `:1347`, the seal path
   `~:1394-1456`), `src/core/phase_vocab.ail` (checkpoint ops), `scripts/phase_c_l1_scenarios.ail`
   (the three checkpoint scenarios: `history_rewrite_requires_checkpoint_event` `:137`,
   `checkpoint_output_is_valid_transcript` `:172`, `checkpoint_never_emitted_in_v1` `:298`).
5. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` and the
   `verify-before-claiming-substrate-defects` memory — minimal repro; never read `$?` through a pipe;
   assert on printed scenario verdicts.

## The open decisions this plan must close (operator sign-off, D9 / D-B5 pattern)

Unlike Plan 1 (which the scope note called "execution only"), **Plan 3 carries genuinely-open
decisions** — the scope note (`:44-46`) names them and defers them *into this plan*. Close each with
the operator, record the rationale, and carry the ADR-001 D7 amendment text. Do **not** pre-decide
them here — they need the operator. The five, plus the reconciliation each forces:

- **D3-1 · Trigger condition.** What makes `decide` (or the seal path) choose `TakeCheckpoint`?
  Candidate: a usage-percent ceiling above the compaction ladder (checkpoint is the escape *after*
  compaction can no longer recover headroom — cf. the exhaustion path in `seal_compacted_payload`,
  `phase_vocab.ail:146`). Define the exact predicate and where the threshold lives (`StepPolicy` /
  `mk_policy`).
- **D3-2 · Emission site — `project`/`decide` (pure) vs the `seal` gate (effectful).** *This is the
  ADR-002 project-vs-seal tension.* If v1's summary source is **pure/structural**, emission can live
  in pure `decide` (clean, Z3-eligible, matches the `StepDecision` design). If the summary needs an
  **effect** (AI/telemetry), it cannot originate in pure `project` and must be produced at the
  effectful `seal`/handler site (ADR-002 §2). Your choice here is **coupled to D3-3** — decide them
  together.
- **D3-3 · Summary source.** ADR-001/scope note: v1 can use a **trivial structural summary** and stay
  pure/independent, *or* delegate to a compactor extension using **ABI telemetry** (the only — soft —
  link to Plan 2). Recommend v1 = structural/pure to keep `decide` pure and Plan 3 independent;
  record the extension-delegation path as the v2 option. The checkpoint output **must** satisfy
  `invariants.validate_compactor_output` regardless (D7(e)).
- **D3-4 · Policy flag + default.** A `StepPolicy` flag gates emission. **The default resolves the
  collision with `checkpoint_never_emitted_in_v1`:** if default = **off**, that scenario stays true
  for the shipped default (rename/retarget it to `checkpoint_never_emitted_when_policy_off` or keep
  it asserting the default policy), and a *new* scenario asserts emission fires when the flag is on.
  State explicitly what happens to the existing scenario — it currently fails on *any* emission.
- **D3-5 · Post-checkpoint termination guard.** After a checkpoint rewrites history, the loop must not
  re-trigger immediately and spin. Define the guard (e.g. checkpoint clears the pressure that
  triggered it; a per-step "checkpoint already taken" latch; the `:353` guard's role). Prove it with
  a scenario that a checkpoint is followed by progress, not another checkpoint.

On sign-off, **amend ADR-001 D7** (`:215-228`): note the trigger condition, emission site, v1 summary
source, the flag + default, and that v1-never-emits becomes v1-never-emits-*by-default* (the D9 /
D-B5 amendment pattern).

## Deliverables the plan must specify

1. **The trigger** — the exact edit to `decide`/`mk_policy` (or the seal path, per D3-2) that emits
   `TakeCheckpoint(CheckpointPlan)` under the policy gate, with the `CheckpointPlan` (reason +
   summary) construction (per D3-3).
2. **The termination guard** (D3-5) — machinery + where it lives.
3. **Scenario changes** — reconcile `checkpoint_never_emitted_in_v1` (D3-4); add a
   `checkpoint_emitted_under_pressure` (or similarly-named) positive scenario; keep
   `checkpoint_output_is_valid_transcript` green by routing checkpoint output through
   `invariants.validate_compactor_output`; add the termination-guard scenario. All in the core-DST
   gate class (`--caps IO`, no hydration).
4. **Gate / acceptance criteria** as checkable commands — the `phase_c_l1_scenarios` suite (currently
   **PASS count=13**) stays green with the reconciled + new scenarios; `make check_core` green; the
   ADR-001 D7 amendment applied.

## Out of scope (owned elsewhere / frozen)

- The checkpoint **mechanics** — `checkpoint`, `apply_checkpoint`, digest-chain, resume validation
  (D7, built and tested; do not re-open).
- Any ABI change (frozen, Plan 2) or conformance-kit change (Plan 1, shipped). The checkpoint-output
  obligation **reuses** the kit's law; it does not extend it.
- Resume/session-restore UX, multi-checkpoint compaction policy, and AI-summary delegation — v2;
  v1 is a single structural-summary escape unless the operator directs otherwise at D3-3.

## Discipline reminders

- **The trigger is a real decision, not a lookup.** Do not silently pick a threshold or emission site
  — the ADR-002 project-vs-seal fork (D3-2) and the flag default (D3-4) are operator calls; present
  the tradeoffs and get sign-off, then amend ADR-001 D7.
- **The v1-never-emits scenario is a tripwire.** Any plan that wires emission without saying what
  happens to `checkpoint_never_emitted_in_v1` is incomplete — it will turn that gate red.
- **One law, still.** Checkpoint output is validated by `packages/motoko_ext_conformance/invariants`
  (Plan 1's moved law), not a `phase_vocab` copy. If you find yourself writing a second validator,
  stop — that is the exact drift Plan 1 existed to prevent.
- Re-verify every anchor at HEAD before relying on it; `session.ail` line numbers drift by the dozen.
- If ADR-001 D7 or ADR-002 under-specifies a fact you need (e.g. how `StepPolicy` threads the flag to
  `decide`), that is a legitimate gap — record it in an "ADR gaps found" section, don't invent policy
  silently.
