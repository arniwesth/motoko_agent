# Handoff: implement the ABI v3 rollout plan

Date: 2026-07-07 (written by the ABI-v3 plan-authoring/review session)
Audience: a fresh agent session that will **implement** `PLAN-abi-v3-rollout.md`.

## Mission

Implement `PLAN-abi-v3-rollout.md` in this directory — the extension ABI **2.2.0 → 3.0** rollout
(`ExtCtx += {ports, artifacts, telemetry}`, `Compacted += artifacts`, new `ExtPorts`/
`TokenTelemetry`), the `compaction_ai` **0.3.0** migration, the `compaction_structural` **1.1.0**
re-cert, the core-side threading, and the one folded DST completion (assert an L1 scenario over a
`LedgerTrace` captured from a driven run). The plan is the normative spec: it carries re-grounded
`file:line` anchors, frozen type signatures, a 17-site blast-radius table, per-section wiring, and a
two-class gate. Follow it WI by WI (§9).

This is **Plan 2, the dependency root** of the three remaining DST plans. You are producing the
frozen surface that Plan 1 (conformance kit) certifies and the `compaction_ai` 0.3.0 accept fixture
it tests against. **Do NOT** build the conformance kit (Plan 1) or the checkpoint trigger (Plan 3),
and **do NOT** widen the ABI surface beyond what the plan freezes (§10).

## Reading order

1. `PLAN-abi-v3-rollout.md` — **the spec.** Read it whole first, TL;DR down. Its §1 (ADR gaps),
   §2 (the two decisions to close), §4 (blast-radius table), §5 (core wiring), §6 (`compaction_ai`
   0.3.0), §7 (structural re-cert), §8 (gates), and §9 (WI sequence) are what you execute against.
2. `ADR-001-phase-oriented-core.md` §6 / §6.1 — the normative decision. It is a *decision, not a
   plan* (thinner than ADR-002 was); the plan's §1 records where §6 under-specifies. Do not re-open
   §6; if HEAD contradicts it, that is a finding to report, not a redesign licence.
3. `NOTE-remaining-dst-work-scope-and-sequence.md` — why this is Plan 2 and where the boundaries to
   Plan 1 / Plan 3 fall.
4. `NOTE-ailang-run-exit-code-false-alarm.md` + memory `verify-before-claiming-substrate-defects` —
   measurement discipline: minimal repro before any substrate-defect claim; never read `$?` through
   a pipeline; assert on a run's printed verdict, not exit code.
5. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` — the mandatory
   re-verify-every-anchor rule below.

## Ground truth to re-establish before you touch code

- **Toolchain pin: AILANG v0.26.0.** Run `ailang --version`; if it disagrees, STOP and flag.
  `ailang.lock` `ailang_version` must read `"v0.26.0"` (confirmed at authoring).
- **The plan's anchors are grounded at HEAD `8923993`; current HEAD is `d797f7d`.** The two
  intervening commits (`9e3c0f5`, `d797f7d`) are **doc-only** (they added the plan and this
  handoff), so the source anchors still hold — but run `git log --oneline -10` first, and if any
  commit has since touched `src/core/session.ail`, `src/core/phase_vocab.ail`,
  `src/core/ext/runtime.ail`, `src/core/ports.ail`, `src/core/rpc.ail`, or the compactor packages,
  **re-verify every `file:line` in the plan before trusting it.** Line numbers across
  `src/core/session.ail` in particular drift easily (the plan cites sites up to `~:1652`). This is
  a registry cache + a moving branch — re-ground, don't assume.
- **Registry cache state (confirm):** `ailang.lock` pins `motoko_ext_abi 2.2.0`,
  `compaction_ai 0.2.0`, `compaction_structural 1.0.0`. Only `2.2.0` / `0.2.0` exist in
  `~/.ailang/cache/registry/...`. You are creating `3.0` / `0.3.0` / `1.1.0`.
- **Green baseline (capture before starting, so you can attribute any red to your change):**
  ```
  ailang --version                                                    # v0.26.0
  ailang check src/core/session.ail
  ailang check src/core/ext/runtime.ail
  ailang check src/core/phase_vocab.ail
  ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail  # PASS count=13
  ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail  # PASS count=6
  ```
  (Both scenario counts were verified green at authoring. The second file is **ungated in the
  Makefile today** — that is deliberate; gating it is part of WI-5.)

## The two decisions to confirm with the operator before WI-1

Both are ADR-001 Open Questions the plan closes with a recommendation; **get sign-off before
freezing the ABI in WI-1**, because they define the frozen surface Plans 1 and 3 build on. Full
rationale + drafted ADR-001 amendment text are in the plan §2.

- **Open Q2 — `artifacts` type.** Recommended: stay raw `Json`. One-token consequence in the ABI.
- **Open Q3 — `ExtPorts` field list.** Recommended (Option B): freeze
  **{ `ai_step`, `proc_exec`, `clock_now`, `env_get` }**, defer `http` + `kv`. Option A (all six)
  is recorded as the alternative. **If the operator picks Option A**, the `http`/`kv` signatures are
  *not grounded in any consumer* — flag that you will be inventing them, and get the signatures
  signed off too.

On sign-off, apply the plan §2 amendment text back into ADR-001's Open Questions log (the D9 / D-B5
pattern) as part of WI-1.

## Execution order and the strangler contract

Implement in plan order (§9 WI-1..WI-6). **Each WI must leave the tree `ailang check`-green and the
baseline suites green before you move on.** Sequence rationale: freeze the surface first (WI-1) so
the downstream plans never build on a moving target.

- **WI-1 — Freeze the ABI 3.0 surface** (§3). Three type edits + new `ExtPorts`/`TokenTelemetry`.
  Also resolve the **vestigial-mirror question** (§4a): grep for live importers of
  `src/core/ext/types`; the plan found none (all live code imports from `pkg/.../motoko_ext_abi/
  types`). Confirm, then delete the mirror or update it in lockstep — do not leave a diverged second
  `ExtCtx`.
- **WI-2 — Core threading** (§5.2). This is the hardest WI and the one the review corrected:
  `C2LoopState` carries **neither** `ext_artifacts` nor `telemetry` across steps, and
  `c2_step_state` hard-resets them each iteration. You must add both to `C2LoopState`, stop the
  reset, and write them back after the model phase (telemetry) and the pre-step fold (artifacts).
  **The artifact cache is dead until this is done** — do not skip it as "just exposing fields."
- **WI-3 — `compaction_ai` 0.3.0** (§6). Ports-native `ai_step`, core primitives (+`[Msg]→[Message]`),
  prefix/pairing-aware split, artifact cache via the `artifacts` field, the one `Compacted` site.
- **WI-4 — `compaction_structural` 1.1.0 re-cert** (§7). Version+dep bump + mechanical
  `Compacted`/ctx arity edits. No logic change.
- **WI-5 — Ledger consumption** (§5.4). **Reuse** `run_scripted` from
  `phase_c2_wiring_scenarios.ail` (do NOT rebuild a driver — it exists). Add one compaction-content
  invariant over a driven `LedgerTrace`; **gate the harness in the Makefile** under
  `--caps IO,Env,Clock,FS,Trace`.
- **WI-6 — Lock + gates** (§8). `ailang lock` to the three new majors; run both gate classes.

## Hazards specific to this plan (the review's hard-won corrections — read before coding)

1. **`Compacted` is a 17-site, 7-file break — construct *and* pattern-match** (§4b). A positional
   arity change breaks matches too (`runtime.ail:159,168` are **live core**, not tests). Use the
   mechanical codemod `Compacted(m, n) → Compacted(m, n, jo([]))` for every site **except**
   `compaction_ai` (real artifacts) and `runtime.ail:168` (wire artifacts into the stage result).
   Re-run `grep -rn 'Compacted(' src/ scripts/ packages/ --include=*.ail | grep -v cache` to confirm
   the site list at your HEAD before editing.
2. **`ExtCtx` construction is ~9 sites, incl. two ADR-unnamed `rpc.ail` builders** (`:118,:224`)
   and five smoke/DST scripts (§4a). A record literal missing the new fields fails to compile — find
   them all via the same grep discipline, not from memory.
3. **`ai_step` returns `Result[string, string]`, not `Result[StepResult, AIError]`** (§2). The ABI
   imports only `std/option` + `std/json` and inlines every `std/ai` shape; importing `StepResult`
   would break that pattern. The host wrapper maps `model_step`'s result to a string. Its effect row
   = `on_pre_step`'s row (no `Trace`) — the wrapper must discharge `model_step`'s `Trace` host-side.
4. **Driven-trace scenarios are NOT `--caps IO`.** Empirically they need
   `--caps IO,Env,Clock,FS,Trace` (progressive faults `Env→FS→Clock→Trace` below it). Still no
   `AI`/`Net` — scripted ports never perform them. **Re-measure this set after your WI-2 edits**, as
   new host effects can shift it. The pure-invariant L1 family stays at `--caps IO`.
5. **Two gate classes, never conflated** (§8): ABI/package gates are **hydration-required**
   (`ailang lock` first, run in core CI against hydrated extensions); the ledger scenario is
   **core-DST** (no provider/network/hydration). ADR-001 AC4's literal "`--caps IO` or less" applies
   to the pure family only — see plan G-A5 for the reconciliation and the recommended one-line ADR
   clarification.
6. **`Json`-in-`Compacted` keeps `deriving (Eq)`** — verified at authoring, do not "fix" the derive
   clause.

## What you own vs what you must NOT touch (§10)

- **Own:** the ABI 3.0 types, the core threading, `compaction_ai` 0.3.0, `compaction_structural`
  1.1.0, the driven-trace L1 scenario + its Makefile gate, `ailang.lock`, and the ADR-001 Open-Q2/Q3
  amendment.
- **Do NOT build:** the conformance kit package (`invariants.ail`, `harness.ail`, its four
  scenarios, the registry probe) — **Plan 1**. You produce the surface it certifies and the 0.3.0
  accept fixture; you write none of the kit. The fail-then-pass proof (0.2.0 rejected / 0.3.0
  accepted) is **Plan 1's** acceptance criterion — your obligation is only that 0.3.0 is *built to
  pass* it.
- **Do NOT build:** the checkpoint trigger (Plan 3) or any core loop / send-gate change (shipped in
  ADR-002).
- **Do NOT add** `http`/`kv` ports, cache-token telemetry, or typed artifacts — all deferred to a
  first consumer (plan §2, §5.3).

## Report back

If any anchor has drifted, or §6 turns out to under-specify a sequencing fact not already in the
plan's §1 gaps, record it as a new gap in the plan (or a findings note) and surface it — **do not
invent policy** to route around it. The plan's discipline is that ADR-001 §6 is a decision; a real
under-specification is a legitimate gap, not a licence to design.
