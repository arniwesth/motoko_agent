# Handoff: implement the compaction DST scenarios plan

Date: 2026-07-06 (written by the ADR-002 authoring / plan-review session)
Audience: a fresh agent session that will **implement** `PLAN-compaction-dst-scenarios.md`.

## Mission

Implement `PLAN-compaction-dst-scenarios.md` in this directory — the five "now" compaction DST
scenarios from `ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md`, their precondition,
and their build-gate wiring. The plan is the normative spec: it carries re-verified `file:line`
anchors, exact code sketches, per-WI verification/rollback, and the acceptance gate. Follow it WI by
WI (WI-0 → WI-5).

**Do NOT** implement the three **gated** scenarios (`compaction.actual_tokens_drive_next_step`,
`compaction.actual_tokens_small_context_fail_open`, `compaction.summarizer_uses_agent_model`). They
are blocked on ABI v3 `ExtCtx.telemetry` + a fake `ai_step` port, which do not exist. Leave them
specified-only, unregistered in any harness list.

## Reading order

1. `PLAN-compaction-dst-scenarios.md` — **the spec.** Read whole first. Its "Work breakdown"
   (WI-0..WI-5), "Plan-level decisions" (D-P1..D-P5), and "Anchor re-verification log" are what you
   execute against.
2. `ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` — the decision the plan implements.
   D1–D4 are settled; do not re-open. §4 lists the scenarios (now vs gated); §"De-duplication map"
   says what is already covered — do not re-test it.
3. `004_phase_core_refactor/NOTE-ailang-run-exit-code-false-alarm.md` — **measurement discipline.**
   Read each command's own exit status directly; never read `$?` through a pipe; minimal repro before
   any substrate-defect claim.
4. Skip for implementation (context only): `NOTE-harness-spawn-boundary-in-core-…` and the
   env-manifest NOTE — those are the #76/harness track, independent of this work.

## Ground truth to re-establish before touching code

- **Toolchain pin: AILANG v0.26.0 (`3b52a24`).** `ailang --version`; if it disagrees, STOP and flag.
- **Plan anchors are grounded at HEAD `03b63c7`** ("Rerveiw of ADR"). `git log --oneline -5` first.
  If commits have landed on `packages/motoko-ext-compaction-structural/`, `src/core/phase_vocab.ail`,
  `src/core/context_usage.ail`, or `scripts/phase_c_l1_scenarios.ail`, **re-verify the plan's Anchor
  Log** before trusting the sketches.
- **Baseline green:** `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` → 12 PASS;
  `ailang check src/core/test/integration_tests.ail` → clean (proves the compaction pkg resolves).

## What is already compile-and-run verified this session (trust it; don't re-derive)

I probed the load-bearing pieces of WI-2/WI-3 with throwaway scripts (since deleted):

- **A `scripts/*.ail` file CAN import the pkg.** `import pkg/sunholo/motoko_ext_abi/types (ExtCtx,
  Msg, PreStepDecision, PassThrough, Compacted)` and
  `import pkg/sunholo/motoko_ext_compaction_structural/compaction_structural (compact_for_pre_step,
  elide_old_tool_results, <the 7 tier constants>)` resolve and check green from a brand-new script.
- **The clean 13-field `ExtCtx` literal in the plan compiles and runs.** Use it. Do **not** copy the
  pkg test-helper literal at `compaction_structural.ail:197-211` — it lists `context_limit` twice (a
  source quirk AILANG tolerates); the type has one.
- **`compact_for_pre_step(ctx, msgs)` + matching `PassThrough | Compacted(m, note)` works under
  `--caps IO`.** `show`/`length` need no extra import.
- **`catalog_context_limit_for("ollama/qwen3.6:35b-a3b-mxfp8")` returns `262144`** at runtime under
  `--caps IO,Env,FS` from repo root (WI-3 / D-P5 confirmed).

## The traps that will waste your time if you miss them (all verified)

1. **Target the LIVE hook `compact_for_pre_step` — NOT `compact_step_with_limit`.** The latter is the
   only entry returning a `"compaction_exhausted"` `Err`, but it is **off the live path** (not in
   `src/core`; only tests/smokes call it). The live hook returns `PassThrough | Compacted` and
   **never exhausts** — it defers exhaustion to core `seal` (already guarded by
   `oversized_payload_rejected`). Do not assert an exhaustion `Err` in these scenarios.
2. **`elide_content` is a no-op for content ≤ 80 chars** (`compaction_structural.ail:42`). A fixture
   of *small* tool messages yields **`PassThrough`, never `Compacted`** — I hit exactly this. To
   observe a `Compacted` you need BOTH (a) **more tool messages than the tier's keep-last** AND (b)
   the elidable (older) ones carrying **long, >80-char content** (use a ~200-char string like the
   pkg's `long_tool_content()`). Verified: 12 long tool messages at `context_limit: 520` (~75% usage)
   → `Compacted note="structural: tier=tier1 keep_last=10"`.
3. **Qwen's `262144` is qwen-agnostic for the tiers.** Tiers are limit-relative, so
   `estimate_tier_ladder` injects a **small** `ctx.context_limit` (e.g. ~250–520) with `model:
   "ollama/qwen…"` as a label only. The real `262144` appears in exactly ONE place — the
   `catalog_limit_qwen` scenario. Never hardcode `262144` or `70/85/95` in the policy file; import
   and reference `elide_tier_pct()` etc.
4. **Three files, three cap sets (plan D-P1):** `segment_excludes_system_prefix` → extend
   `phase_c_l1_scenarios.ail` (core-only, `--caps IO`); the 3 policy scenarios → new
   `scripts/compaction_policy_dst.ail` (`--caps IO`, imports pkg); `catalog_limit_qwen` → new
   `scripts/compaction_catalog_dst.ail` (`--caps IO,Env,FS`). Keep `phase_c_l1` core-only.
5. **WI-0 first:** `scripts/smoke_catalog_compaction.ail` is red at HEAD (imports the absent
   `compact_step_with_limit` from `src/core/compaction`). Fix/retire it before adding DST — do not
   build on a red smoke.
6. **WI-4 is not optional:** the two new scripts are wired into no build target; without WI-4 they run
   once and guard nothing. `test: test_core` does NOT include `phase_c_l1` — confirm what CI invokes.

## Out of scope (do not touch)

- The three gated scenarios and anything ABI v3 (`ExtCtx.telemetry`, fake `ai_step`, re-homing the
  60/75/85 actual tiers).
- The #76 harness-boundary / env-manifest work.
- Extracting a shared DST harness module — the plan deliberately re-declares ~40 trivial lines
  (D-P2) rather than refactor the green `phase_c_l1` file.
- Editing ADR-002, ADR-001, the research draft, or this plan (report drift as a finding).

## Definition of done

WI-5 acceptance gate green (maps to ADR-002 §Acceptance criteria): the four pure scenarios green
under `--caps IO`, `catalog_limit_qwen` green under `--caps IO,Env,FS`, constants imported (no bare
threshold comparison), scenarios target `compact_for_pre_step`, `262144` only in the catalog file, no
mocking/providers/recorder, gated scenarios unregistered, and `ailang check` green on the touched
core files. Each scenario names its id + first failed invariant on failure (the phase-C reporting
contract).

## Suggested WI order

WI-0 (fix red smoke) → WI-1 (segment, smallest/core-only, proves the harness pattern) → WI-2 (the
three policy scenarios — the bulk; mind trap 2) → WI-3 (catalog) → WI-4 (Make wiring) → WI-5
(acceptance). Each WI leaves the tree `ailang check`-green and shippable.
