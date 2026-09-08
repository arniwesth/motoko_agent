# Handoff: write the ABI v3 rollout implementation plan

Date: 2026-07-07 (written by the DST-status / remaining-work-scoping session)
Audience: a fresh agent session. You are deliberately fresh, same discipline as
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`: **if you
cannot produce this plan from ADR-001 §6 plus the committed source at HEAD, the ADR has a gap —
report it in an "ADR gaps found" section, don't guess around it.** And obey
`re-ground-inherited-anchors-before-building.md`: **every `file:line` below is a starting point
from 2026-07-07, not a fact — re-run the observation before you build on it.**

## Mission

Write `PLAN-abi-v3-rollout.md` in this directory: the implementation plan to take the extension
ABI from **2.2.0 → 3.0** (ports + artifacts + telemetry), migrate the reference compactor, and
fold in the one core-side DST completion that rides this work. **Do NOT implement. Do NOT write
the conformance-kit plan** (that is Plan 1, a separate handoff — this plan only produces the
surface the kit will later certify) **and do NOT plan the checkpoint trigger** (Plan 3).

This is the **dependency root** of the three remaining DST plans
(`NOTE-remaining-dst-work-scope-and-sequence.md`): the kit certifies ABI v3 lockstep and uses
`compaction_ai` 0.3.0 as its accept/reject fixture, both produced here. Scope this well and the
other two sit on a frozen surface.

## Reading order

1. `NOTE-remaining-dst-work-scope-and-sequence.md` — the boundaries, sequence, and why there is
   no new ADR. This plan is "Plan 2" there.
2. `ADR-001-phase-oriented-core.md` — **normative**. Decision detail **§6** (ABI v3 + conformance
   kit) and **§6.1** (kit explainer — read for the *lockstep* obligation only, not to plan the
   kit); the **migration plan's "ABI v3 track"** paragraph; **Open Questions 2 and 3** (the two
   decisions this plan closes); the **D9** amendment (telemetry rationale) and the **Consequences /
   Rejected alternatives** touching the ABI major bump. Its "Gate separation" note is load-bearing:
   the ABI/conformance track is the **hydration-required** gate class, *unlike* core DST.
3. `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — context for the telemetry
   surface (per-step `StepResult` usage numbers) and the `seal`/`project` split.
4. Source under change — read each definition whole; verify every anchor at HEAD:
   - **ABI types** (registry cache, current pin `2.2.0`):
     `~/.ailang/cache/registry/sunholo/motoko_ext_abi/2.2.0/types.ail` — `ExtCtx` (`:62`, the
     record that gains `ports`/`artifacts`/`telemetry`), `CompactionResult`/`Compacted(msgs, note)`
     (`:125-126`, gains an `artifacts` field), `ExtRuntime` (`:146`). Confirm 2.2.0 is still the
     pin in `ailang.lock`.
   - **Reference compactor**: `~/.ailang/cache/registry/sunholo/motoko_ext_compaction_ai/0.2.0/
     compaction_ai.ail` — the `Compacted(...)` construction (`:148`) that breaks at the source
     level, and its `usage_percent` duplication (the defect ADR-001 says v0.3.0 fixes structurally
     by consuming core's measurement primitives).
   - **Bundled structural compactor**: `packages/motoko-ext-compaction-structural/` — `ailang.toml`
     (currently `version = 1.0.0`, dep `motoko_ext_abi = 2.2.0`). It is pure and needs no ports, so
     it is a **re-cert on 3.0, not a rewrite** (ADR-001 says it can ship early on 2.2.0).
   - **Core ABI seams**: `src/core/ext/types.ail` and `src/core/ext/runtime.ail` (how core builds
     `ExtCtx` and consumes the compactor chain); `src/core/session.ail` `mk_v2_ext_ctx` (`~:670`,
     the `ExtCtx` construction site that is a **constructor-only** break); the telemetry source —
     the per-step `StepResult` fields (`last_input_tokens`, output/cache tokens) surfaced in
     `session`'s per-step usage (`per_step_usage_kvs`, `~:548`).
   - **Typed-ledger consumption (the folded item)**: `src/core/phase_vocab.ail` `LedgerTrace`
     (`~:517`), `ledger_append` (`~:523`); `scripts/phase_c_l1_scenarios.ail` — today its scenarios
     assert over **pure functions** (`history_valid_transcript`, `validate_*`) rather than over a
     `LedgerTrace` captured from a real `c2_loop`/`run_v2_with_scripted_ports` run. Closing that is
     the dst-status "partial".
   - **Registry probe surface**: `src/core/ext/registry_generated.ail` and how core CI iterates it
     (the probe the kit plan will later add runs per package here).

## The two decisions this plan closes (ADR-001 Open Questions)

ADR-001 explicitly defers both **into this migration** — close them in the plan with a short
rationale, operator sign-off, and an amendment back to ADR-001's Open Questions log (the D9 / D-B5
pattern):

- **Open Q2 — `artifacts`: raw `Json` vs a typed record.** ADR-001's lean is "start `Json`,
  revisit when a second artifact consumer exists." Confirm that still holds against the 0.3.0
  cache-artifact shape you design, and record it.
- **Open Q3 — the exact `ExtPorts` field list.** ADR-001 §6 names the intended set
  (`ai_step, http, proc_exec, kv, clock_now, env_get`). Freeze the concrete field names and
  signatures here, grounded in what `compaction_ai` 0.3.0 actually needs (the port set is
  justified by its first real consumer, not invented ahead of one).

## Deliverables the plan must contain

1. **Blast-radius table** (ADR-002's format is the model): every construction site touched by
   `ExtCtx += {ports, artifacts, telemetry}` and `Compacted += artifacts`, split into
   **constructor-only breaks** (core `mk_v2_ext_ctx`, extension test fixtures — recompile, no logic
   change) vs **source-level breaks** (every `Compacted(...)` site — currently only
   `compaction_ai`). Cite each at HEAD.
2. **`compaction_ai` 0.3.0 migration**: ports-native, artifact-cached, consuming core's
   `estimate_tokens_messages`/`usage_percent_with_limit` instead of its own tables — i.e. the
   version that makes the kit's two live-bug scenarios (`system_prefix_preserved`,
   `tool_pairing_preserved`) and the cache scenario pass. This plan **produces** that fixture; it
   does not write the kit that tests it.
3. **Structural compactor re-cert** on 3.0 (version bump + dep bump; verify no code change needed).
4. **Typed-ledger consumption wiring**: how an L1 scenario captures the `LedgerTrace` from a driven
   `run_v2_with_scripted_ports` run and asserts invariants over *it*, closing the dst-status
   "partial". Scope this to the mechanism + at least one converted scenario; the full conversion
   can be enumerated as follow-on.
5. **Gate / acceptance criteria**: derived from ADR-001 §6 and its Acceptance criteria 2–3, phrased
   as checkable commands. Remember these run in the **hydration-required** gate class (`ailang lock`
   first), not the `--caps IO` core-DST class.

## Out of scope (owned elsewhere)

- The conformance **kit** package itself (`invariants.ail`, `harness.ail`, the registry probe) —
  Plan 1, separate handoff. You define the surface it certifies and the 0.3.0 fixture; you do not
  build it.
- The **checkpoint** trigger (Plan 3).
- Any core loop / send-gate change (that shipped in ADR-002).

## Discipline reminders

- **ADR gaps:** ADR-001 §6 is a decision, not a plan — thinner than ADR-002 was. If a needed
  sequencing fact isn't derivable from §6 + source, that's a legitimate gap; record it, don't
  invent policy.
- **Re-verify every anchor at HEAD** before relying on it — line numbers here are 2026-07-07
  observations across a registry cache and a moving branch; the ABI version pin especially.
- **One plan, this scope only.** Resist widening into the kit or checkpoint; the sequence note
  keeps them separate on purpose.
