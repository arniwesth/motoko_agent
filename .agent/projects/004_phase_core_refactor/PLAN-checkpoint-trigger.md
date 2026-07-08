# Plan 3 · Checkpoint trigger (wire `TakeCheckpoint` emission)

Authored 2026-07-08 in a fresh session grounded at HEAD `4371de0`, per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`. Inputs:
`HANDOFF-write-checkpoint-trigger-plan.md`, `NOTE-remaining-dst-work-scope-and-sequence.md` (Plan 3),
ADR-001 D7, ADR-002 §2. Every `file:line` below was re-grounded at HEAD before use
(`re-ground-inherited-anchors-before-building.md`); `session.ail` line numbers drift by the dozen —
re-verify at implementation time.

## TL;DR

The checkpoint **machinery** shipped in Phases A–C and is wired into the live loop
(`session.ail` `TakeCheckpoint(plan) => apply_checkpoint(...)`, currently `:1347`). The **trigger** is
missing: `decide` (`step_machine.ail:78`) has no `TakeCheckpoint` arm, so a long session dies at the
seal gate (`SealExhausted`, 95%) instead of taking the designed, audited escape. This plan wires the
emission under a policy gate, keeping v1 **pure, structural, independent of ABI/Plan 2, and
off-by-default**:

- **Trigger (D3-1):** pure usage-percent ceiling `checkpoint_pct = 90`, sitting between the compaction
  hard tier (85) and seal exhaustion (95). `decide` fires when `history` usage `>= checkpoint_pct`.
- **Emission site + summary (D3-2/D3-3):** pure `decide`, structural summary (no effect). AI/telemetry
  delegation recorded as the v2 path.
- **Flag default (D3-4):** `checkpoint_enabled = false`. `checkpoint_never_emitted_in_v1` is retargeted
  to `checkpoint_never_emitted_when_policy_off`; a new positive scenario asserts emission under the
  flag. v1-never-emits becomes v1-never-emits-**by-default** (the D9/D-B5 amendment pattern).
- **Termination guard (D3-5):** pressure-cleared (checkpoint rebuilds history to `pinned ++ [summary]`,
  dropping usage far below threshold) **plus a pure "would-relieve" precondition** — `decide` emits
  only if the projected post-checkpoint usage falls below `checkpoint_pct`. This handles the degenerate
  case (system prefix alone `>=` threshold) found by verification (§0), where a naive guard spins
  forever.

Blast radius: two new `StepPolicy` fields, one `decide` arm, one pure summary builder + two pure
helpers in `phase_vocab`, three scenario edits (one retargeted, two new), and routing
`checkpoint_output_is_valid_transcript` through the shared `invariants.validate_compactor_output` law.
No ABI change, no kit change, no checkpoint-mechanics change.

## 0. Grounding note (what re-grounding at HEAD `4371de0` confirmed / corrected)

Confirmed:

- `decide(s: StepState, pol: StepPolicy) -> StepDecision` (`step_machine.ail:78`) is pure and has **no
  `TakeCheckpoint` arm** (arms: RunTools/await/inject/Finalize via `call_model_or_fail`). It receives
  `s.history`, `s.telemetry`, and `pol.compaction.context_limit` — everything a pure structural trigger
  needs.
- `mk_policy(context_limit)` (`step_machine.ail:109`) builds the `StepPolicy`; `pol.compaction` is a
  `CompactionPolicy` with `context_limit`, `elide_tier_pct: 70`, `elide_hard_tier_pct: 85`,
  `emergency_pct: 95` (`phase_vocab.ail:163`).
- `checkpoint(h, plan) -> {history, event}` (`phase_vocab.ail:239`) rebuilds history to
  `take_system_prefix(xs) ++ [summary_msg]` where `summary_msg.content = "[CHECKPOINT] ${plan.summary}"`
  (`:243-246`). `apply_checkpoint` (`:323`) is the atomic driver path. `CheckpointPlan = {reason, summary}`
  (`:237`). `TakeCheckpoint(CheckpointPlan)` is a `StepDecision` variant (`:367`).
- The live handler is already wired: `TakeCheckpoint(plan) => let cp = apply_checkpoint(step_state, plan);
  ledger_emit(...); c2_loop(... next_state)` (`session.ail:1347-1369`). **Emission is the only missing
  piece; handling exists.**
- `seal_compacted_payload` (`phase_vocab.ail:140`) is the single effectful send-gate; `project` (`:176`)
  is pure and its payload/events are discarded by the live loop (ADR-002 §2 findings 1–2). This is the
  project-vs-seal fork D3-2 turns on.
- Usage math: `usage_percent_with_limit(msgs, limit)` and `exhaustion_pct() = 95` in `compaction.ail:25,30`;
  ~4 chars/token.
- Suite registers **13 scenarios** (`phase_c_l1_scenarios.ail:435-447`, prints `PASS count=13`). The
  checkpoint scenarios: `history_rewrite_requires_checkpoint_event` (`:137`),
  `checkpoint_output_is_valid_transcript` (`:172`), `checkpoint_never_emitted_in_v1` (`:298`).
- The shared valid-transcript law `validate_compactor_output` lives in
  `packages/motoko_ext_conformance/invariants.ail:133` and is imported by core at
  `src/core/ext/runtime.ail:27` and by the scenario file at `scripts/phase_c_l1_scenarios.ail:35`.

Corrected / newly discovered (see §1 gaps):

- **The handoff's `:1293` handler anchor is now `:1347`** (drift, as warned).
- **`checkpoint_output_is_valid_transcript` does NOT currently use the shared law.** It asserts
  `history_valid_transcript(cp.history)` (`:183`), a *separate* predicate from
  `invariants.validate_compactor_output`. ADR-001 D7(e) says checkpoint output is checked "by the same
  gate" as ext compaction — today that is aspirational, not literal. Routing it through the shared law
  is a concrete edit in this plan (§5), closing the one-law drift the handoff warns about.
- **The pressure-cleared guard is insufficient alone.** Verified with a minimal repro
  (`scratchpad/verify_guard.ail`, `ailang run --caps IO`):

  | case | before | after checkpoint | history len |
  |------|--------|------------------|-------------|
  | normal (small system prefix) | 91% | **16%** | 6 → 2 |
  | large system prefix (~25% of limit) | 105% | **31%** | 6 → 2 |
  | **system prefix alone ≥ 90% of limit** | 171% | **96%** | 6 → 2 |

  In the third case the checkpoint keeps the full system prefix, so post-checkpoint usage stays ≥
  threshold and a naive `decide` would re-emit `TakeCheckpoint` every step forever. D3-5's guard must
  therefore include the "would-relieve" precondition (§2, §4.3). This is evidence, not assertion.

## 1. ADR gaps found (record, don't invent silently)

- **G1 — "the same gate" for checkpoint output is not literally wired.** ADR-001 D7(e) (`:223-225`) says
  checkpoint output is validated "by the same gate" as ext compaction. In fact the scenario uses
  `history_valid_transcript`, not `invariants.validate_compactor_output`. **Resolution (this plan):**
  route `checkpoint_output_is_valid_transcript` through `validate_compactor_output` (§5). Amend D7(e) to
  name the shared predicate.
- **G2 — D7 under-specifies the helper surface `decide` needs.** `decide` lives in `step_machine.ail`
  and cannot destructure the opaque `History` type (not exported from `phase_vocab`). To compute the
  trigger and the would-relieve precondition purely, `phase_vocab` must export two small pure helpers
  (`history_usage_percent`, `checkpoint_would_relieve`, §4.3). D7 names neither. **Resolution:** add them
  in `phase_vocab` (the module that owns `History` internals) and note them in the D7 amendment.
- **G3 — the degenerate no-escape case is unspecified.** Neither ADR-001 D7 nor ADR-002 says what happens
  when no checkpoint can relieve pressure (system prefix alone ≥ threshold, §0). **Resolution:** `decide`
  does **not** emit in that case; it falls through to `CallModel` → `seal`, which returns `SealExhausted`
  — the honest terminal state (a run whose *pinned* prompt exceeds the window cannot be rescued by
  rewriting the tail). Record this in the D7 amendment as the trigger's precondition.
- **G4 — trigger uses the model-window limit, not the seal's pinned-adjusted limit.** The live seal path
  subtracts `pinned_tokens` from `context_limit` for the ext chain (`session.ail:1450-1451`); `decide`'s
  structural trigger uses `pol.compaction.context_limit` over the full history. This is an intentional
  simplification for v1 (the trigger is a *coarse* ceiling, not the exact seal predicate). Note as a
  fidelity caveat, not a defect.

## 2. Decisions closed (operator sign-off 2026-07-08 — carry the amendments, do not re-litigate)

Recommendations presented with tradeoffs; operator approved the bundle below.

- **D3-1 · Trigger condition — usage-% ceiling above the compaction ladder.** A `checkpoint_pct` field
  in `StepPolicy` (default **90**), between hard-tier (85) and exhaustion (95). Predicate:
  `history_usage_percent(s.history, pol.compaction.context_limit) >= pol.checkpoint_pct`. Rationale:
  checkpoint is the escape *after* compaction can no longer recover headroom but *before* seal kills the
  run. Rejected: "reactive to seal exhaustion" (requires the effectful site, contradicts D3-2);
  "step-budget proximity" (decoupled from the token-ceiling rationale).
- **D3-2 · Emission site — pure `decide`.** The trigger and summary are pure functions of `StepState`;
  no effect is needed, so emission stays in `decide`, keeping it Z3-eligible and Plan 3 independent of
  ABI/Plan 2. Rejected for v1: the effectful seal site (needed only if the summary requires AI/telemetry
  — the v2 path).
- **D3-3 · Summary source — structural.** The `CheckpointPlan.summary` is built purely from `StepState`:
  step index, message/tool-call counts elided, and the pre-checkpoint digest. No AI, no ABI telemetry.
  AI-summary delegation via a compactor extension is recorded as the documented **v2** option. Checkpoint
  output must satisfy `invariants.validate_compactor_output` regardless (D7(e)).
- **D3-4 · Policy flag default — OFF.** `checkpoint_enabled = false` in the shipped default (`mk_policy`).
  `checkpoint_never_emitted_in_v1` is **retargeted** to `checkpoint_never_emitted_when_policy_off` (still
  true for the default), and a **new** `checkpoint_emitted_under_pressure` scenario asserts emission with
  the flag on. Rejected: default ON (changes every session's behavior, deletes the tripwire outright).
- **D3-5 · Termination guard — pressure-cleared + would-relieve precondition.** Primary: checkpoint
  rebuilds history to `pinned ++ [summary]`, so usage drops below `checkpoint_pct` and the next `decide`
  falls through to `CallModel` (progress). Precondition (required by the §0 boundary finding): `decide`
  emits only if `checkpoint_would_relieve(s.history, plan, limit, pol.checkpoint_pct)` is true; otherwise
  it does not checkpoint and lets the loop reach seal-exhaustion honestly. This stays **pure** — no new
  `StepState` field, no latch plumbing (the latch option was rejected as strictly heavier and the
  would-relieve predicate subsumes it).

**ADR-001 D7 amendment text (apply on landing, `:226-228`):**

> v1 policy emits `TakeCheckpoint` **only when the checkpoint policy is enabled** (`checkpoint_enabled`,
> default off) **and** structural context usage over `History` reaches `checkpoint_pct` (default 90,
> between the hard-elide tier and exhaustion) **and** the rebuilt history would bring usage below that
> ceiling (`checkpoint_would_relieve`); if the pinned system prefix alone exceeds the ceiling, no
> checkpoint is emitted and the loop reaches seal-exhaustion, the honest terminal state. The trigger and
> summary are pure functions of `StepState` (structural summary; AI-delegated summary is a v2 option).
> Checkpoint output is validated by the shared `motoko_ext_conformance/invariants.validate_compactor_output`
> law — the same predicate as ext-compaction output — via `checkpoint_output_is_valid_transcript`. The
> former "v1 never emits" invariant becomes **"v1 never emits by default"**, enforced by
> `checkpoint_never_emitted_when_policy_off` plus the positive `checkpoint_emitted_under_pressure` scenario.

## 3. The surface being wired (reference, at HEAD)

```
step_machine.ail   decide(s, pol)                     :78    ← add TakeCheckpoint arm (before call_model_or_fail fall-through)
                   mk_policy(context_limit)           :109   ← default the two new fields
phase_vocab.ail    StepPolicy                         :270   ← + checkpoint_enabled: bool, checkpoint_pct: int
                   checkpoint / apply_checkpoint       :239/:323  (FROZEN — do not touch mechanics)
                   CheckpointPlan {reason, summary}    :237
                   (new) history_usage_percent                ← pure, owns History destructure
                   (new) checkpoint_would_relieve             ← pure, projects post-checkpoint usage
                   (new) checkpoint_summary (or in step_machine)  ← pure structural summary builder
session.ail        TakeCheckpoint handler              :1347  (already wired — no change needed)
invariants.ail     validate_compactor_output           :133   (shared law — reuse, do not copy)
scripts/phase_c_l1_scenarios.ail                              ← retarget + 2 new scenarios; route output law
```

## 4. Implementation

### 4.1 `StepPolicy` — two new fields (`phase_vocab.ail:270`)

```
export type StepPolicy = {
  ...existing...
  compaction: CompactionPolicy,
  checkpoint_enabled: bool,   -- [NEW] gates emission; default false
  checkpoint_pct: int         -- [NEW] usage ceiling that triggers checkpoint; default 90
}
```

**Blast radius (structural records — every literal must gain both fields):** `mk_policy`
(`step_machine.ail:109`, set `false`/`90`), the two inline policies in `step_machine` tests
(`~:210,:222`), the scenario `policy()` helper (`phase_c_l1_scenarios.ail:100`), and every other
`StepPolicy` constructor. Grep to enumerate at implementation time:
`grep -rn "step_budget:" src scripts --include=*.ail | grep -v .ailang/cache` (8 files at HEAD:
`agent_loop_v2`, `phase_vocab`, `session`, `recovery`, `step_machine`, `test/scripted_ports`,
`phase_c_l1_scenarios`, `phase_f_pipeline_wiring`). Prefer routing through `mk_policy` where a site
already does; add the two literals where it constructs inline.

### 4.2 `decide` — the `TakeCheckpoint` arm (`step_machine.ail:78`)

Insert the checkpoint decision **after the pending-tools/inject/finalize arms and before the final
`call_model_or_fail` fall-through** (i.e. checkpoint only when the loop would otherwise call the model —
never when tools are pending or a finalize/inject is due). Sketch:

```
  ...
  else if s.last_finish_reason == "user_injected"
  then call_model_or_fail(s, pol)
  else if should_checkpoint(s, pol)
  then TakeCheckpoint(mk_checkpoint_plan(s))
  else call_model_or_fail(s, pol)
```

where (pure):

```
func should_checkpoint(s: StepState, pol: StepPolicy) -> bool {
  let limit = pol.compaction.context_limit;
  pol.checkpoint_enabled
    && history_usage_percent(s.history, limit) >= pol.checkpoint_pct
    && checkpoint_would_relieve(s.history, mk_checkpoint_plan(s), limit, pol.checkpoint_pct)
}

func mk_checkpoint_plan(s: StepState) -> CheckpointPlan {
  { reason: "context_pressure_at_step_${show(s.step_idx)}",
    summary: checkpoint_summary(s) }     -- structural, see 4.3
}
```

(Note: `should_checkpoint` calls `mk_checkpoint_plan(s)` to feed `checkpoint_would_relieve`, and the
`decide` arm calls it again to build the emitted decision — it is pure, so the duplicate call is free;
an implementer may hoist it into a `let` if preferred.)

Placement matters for the guard: because checkpoint sits on the `call_model_or_fail` branch, the very
next iteration after a checkpoint re-enters `decide` with the rebuilt (small) history, `should_checkpoint`
is false (pressure cleared), and the loop proceeds to `CallModel` — progress, not another checkpoint.

### 4.3 New pure helpers in `phase_vocab` (owns `History` internals)

```
-- Structural usage of a History against a model window (0 = unknown limit).
export pure func history_usage_percent(h: History, limit: int) -> int {
  match h { MkHistory(xs) => usage_percent_with_limit(xs, limit) }
}

-- Would a checkpoint bring usage below `threshold`? False when the pinned system
-- prefix alone (kept by every checkpoint) already meets/exceeds the threshold —
-- the degenerate no-escape case (G3): emitting would spin. Pure; projects the
-- exact rebuilt history via the frozen `checkpoint` op.
export pure func checkpoint_would_relieve(h: History, plan: CheckpointPlan, limit: int, threshold: int) -> bool {
  let projected = checkpoint(h, plan).history;
  history_usage_percent(projected, limit) < threshold
}
```

`checkpoint_summary(s: StepState) -> string` (home: `step_machine.ail`, or `phase_vocab` if it needs
`History` destructure — prefer `step_machine` using `history_len`) — a pure structural summary, e.g.
`"session checkpoint at step ${show(s.step_idx)}: folded ${show(history_len(s.history))} messages"`.
No AI, no telemetry effect. The exact string is not load-bearing; only that it is deterministic and that
the resulting `[CHECKPOINT] ...` message keeps the output a valid transcript (it is a plain assistant
message — trivially satisfies `validate_compactor_output`).

### 4.4 Handler — no change

`session.ail:1347` already applies `apply_checkpoint`, emits the `CheckpointTaken` event, and continues
the loop. Confirm at implementation time it still threads `cp.state` (history rewrite) into `next_state`
(it does at HEAD: `:1354-1355` + `trace` append `:1367`). If `decide` starts emitting, this path lights up
unchanged.

## 5. Scenario changes (all core-DST class: `--caps IO`, no hydration)

1. **Retarget `checkpoint_never_emitted_in_v1` → `checkpoint_never_emitted_when_policy_off`**
   (`phase_c_l1_scenarios.ail:298`). Keep the body; assert that with `checkpoint_enabled = false` (the
   default `policy(...)` helper), `decide` on a **pressured** state does **not** return `TakeCheckpoint`.
   Rename the scenario id and its registrar (`:412`, `:442`).
2. **New `checkpoint_emitted_under_pressure`.** Build a state whose history usage `>= checkpoint_pct`
   with `checkpoint_enabled = true` and a system prefix well below threshold; assert `decide` returns
   `TakeCheckpoint(_)`. (Mirror the pressured fixture from `scratchpad/verify_guard.ail`: small system
   prefix + large tail, limit chosen so usage ≥ 90%.)
3. **New `checkpoint_terminates_not_spins`** (D3-5). Two parts: (a) after `apply_checkpoint` on a
   pressured state, `decide` on the *rebuilt* state returns a non-checkpoint decision (progress); (b)
   the degenerate case — a state whose **system prefix alone** ≥ `checkpoint_pct` with the flag on — has
   `should_checkpoint` false, so `decide` does **not** emit (it would spin otherwise). Assert both.
4. **Route `checkpoint_output_is_valid_transcript` through the shared law** (`:172`, G1). Replace the
   `history_valid_transcript(cp.history)` assertion with `result_ok(validate_compactor_output(input,
   output))`, where `input`/`output` are the pre- and post-checkpoint message lists (`[Msg]`). Keep the
   digest-chain and `history_len == 2` checks. This makes "the same gate" literal.

Registry (`:435-447`): retarget id #1, append the two new scenarios → **`PASS count=15`**.

## 6. Gate / acceptance criteria (checkable commands)

```bash
# 1. static + effect check of the core
ailang check src/core/step_machine.ail src/core/phase_vocab.ail

# 2. the L1 scenario suite — reconciled + new scenarios, all pure (IO only)
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
#   expect final line: phase_c_l1_scenarios PASS count=15
#   (13 → 15: +checkpoint_emitted_under_pressure, +checkpoint_terminates_not_spins;
#    checkpoint_never_emitted_in_v1 renamed, not removed)

# 3. full core gate
make check_core

# 4. ADR-001 D7 amendment applied (§2 text at :226-228)
grep -n "never emits by default\|checkpoint_enabled" \
  .agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md
```

Done = all four green + the D7 amendment committed.

## 7. Work items (sequence)

1. **WI-1 · Policy fields.** Add `checkpoint_enabled`/`checkpoint_pct` to `StepPolicy`; update every
   constructor (grep, §4.1); `mk_policy` defaults `false`/`90`. Gate: `make check_core` compiles.
2. **WI-2 · Pure helpers.** Add `history_usage_percent`, `checkpoint_would_relieve` to `phase_vocab`;
   add `checkpoint_summary` (structural). Gate: `ailang check`.
3. **WI-3 · Trigger arm.** Add `should_checkpoint`/`mk_checkpoint_plan` + the `decide` arm (§4.2). Gate:
   `ailang check`; existing `decide` tests still green.
4. **WI-4 · Scenarios.** Retarget #1; add the two positives; route the output law (§5). Gate:
   `phase_c_l1_scenarios PASS count=15`.
5. **WI-5 · ADR-001 D7 amendment** (§2 text) + note the new helper surface (G2) and the no-escape
   terminal (G3). Gate: grep in §6 step 4.
6. **WI-6 · Full gate.** `make check_core` green. (Optional: a live smoke — a session with
   `checkpoint_enabled=true` and a tiny `context_limit` — to observe a `history_checkpoint` ledger event,
   if a driver-level fixture is cheap; not required for acceptance.)

## 8. Out of scope (owned elsewhere / frozen — do not widen)

- Checkpoint **mechanics**: `checkpoint`, `apply_checkpoint`, digest-chain, resume validation (D7 frozen,
  built, tested). This plan only adds *read-only* pure helpers over `History`; it does not change the
  rewrite op.
- Any **ABI** change (Plan 2, frozen) or **conformance-kit** change (Plan 1, shipped). Checkpoint output
  **reuses** `invariants.validate_compactor_output`; it does not extend the law.
- **AI/telemetry-delegated summary** (v2), **resume/session-restore UX**, **multi-checkpoint compaction
  policy**. v1 is a single structural-summary escape.
- The **effectful-seal emission site** — rejected for v1 (D3-2); documented as the v2 shape only.

## 9. Risks / notes

- **Structural-record blast radius (WI-1).** Adding two `StepPolicy` fields breaks every literal that
  doesn't include them; AILANG will flag each at compile. Enumerate with the grep in §4.1 — miss one and
  `make check_core` fails loudly (acceptable: the compiler is the backstop).
- **Guard correctness rests on the would-relieve precondition, verified (§0).** Do not drop it for
  "simplicity" — the naive pressure-cleared guard spins in the system-prefix-heavy case. The
  `checkpoint_terminates_not_spins` scenario is the regression lock.
- **One law, still.** Checkpoint output validation goes through
  `motoko_ext_conformance/invariants.validate_compactor_output` (WI-4, G1). If a second validator appears,
  stop — that is the drift Plan 1 existed to prevent.
- **Trigger fidelity (G4).** The trigger's structural usage over the full model window is coarser than the
  seal's pinned-adjusted predicate. Acceptable for a v1 ceiling; if a future version wants exactness, that
  is the effectful-seal path (v2), not a patch here.
- **`session.ail` line drift.** The handler anchor moved `:1293 → :1347` between scope-note authoring and
  now. Re-ground it (and every anchor in §3) at implementation-time HEAD before editing.
```
