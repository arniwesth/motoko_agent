# Handoff: implement the seeded scenario generation plan

Date: 2026-07-18 (written by the planning/review session with the operator)
Audience: a fresh agent session that will **implement**
`PLAN-seeded-scenario-generation.md` (this directory).

## Mission

Implement ADR-001 Phase 4 v1 per `PLAN-seeded-scenario-generation.md` — the plan is the
normative spec. Five steps: (0) harness seed-threading fix, (1) `dst_gen.ail` helper,
(2) the seeded gate `scripts/dst/compaction_seeded_dst.ail`, (3) `dst_seeded` make target,
(4) CI step. Steps 0–2 are the substance; 3–4 are wiring. The four operator decisions
(D1–D4) and the review finding (D5) are settled — do not re-open them.

## Reading order

1. `PLAN-seeded-scenario-generation.md` — **the spec.** Read whole first, especially D5
   (direct seed loop, no closures) and Step 2's output contract.
2. `NOTE-seeded-scenario-generation-design-discussion.md` — the design rationale
   (oracle-preservation rule, why parameters-not-grammars). Context only; where it and the
   plan disagree (PRNG choice, closure design), **the plan wins** — it post-dates the note
   and incorporates operator decisions from 2026-07-18.
3. `HANDOFF-implement-compaction-dst-scenarios.md` §"traps" — older but two traps still
   bite here (carried into the traps list below).

## Ground truth to re-establish before touching code

- **Toolchain pin: AILANG v0.26.0 (`3b52a24`).** `ailang --version`; if it disagrees, STOP
  and flag. The plan's `std/rand` decision is only valid on ≥0.26.0.
- **Plan anchors are grounded at branch `arniwesth/mot-41-dts-consolidation`, HEAD
  `ed1401b`.** `git log --oneline -5` first. If commits have landed on
  `src/core/test/dst_harness.ail`, `scripts/dst/compaction_policy_dst.ail`,
  `packages/motoko-ext-compaction-structural/compaction_structural.ail`, or the Makefile
  DST targets (lines ~69–95), re-verify the plan's file/line claims before trusting them.
- **Baseline green:** `make dst` passes before you change anything. If it doesn't, STOP —
  do not build seeded gates on a red baseline.

## What was already verified this session (trust it; don't re-derive)

- **`std/rand` exists in the pinned v0.26.0**: `~/.local/share/ailang/std/rand.ail` defines
  `rand_seed(int)`, `rand_int(min,max)` (inclusive both ends), `rand_bool()`, all
  `! {Rand}`, cap `Rand`; all five `_rand_*` builtins are registered in the local binary
  (`ailang builtins list --by-effect` → `# Rand (5)`).
- **`report_failure` and `run_one` have NO callers outside `dst_harness.ail`** (grepped
  `src/`, `scripts/`, `packages/`). The Step 0 signature change cannot ripple; `run_all` is
  the only internal caller of `run_one`.
- **`validate_compactor_output` type-aligns**: `packages/motoko_ext_conformance/
  invariants.ail` imports `Msg` from `pkg/sunholo/motoko_ext_abi/types` — the same `Msg`
  the compaction gate uses. `phase_c_l1_scenarios.ail` already imports both together.
- **`std/string.stringToInt(s) -> Option[int]`** exists in the local stdlib (line 40 of
  `string.ail`).
- **Every current scenario sets `seed: "fixed"`** (grepped all `run:` sites), so Step 0
  keeps all existing gate output byte-identical.

## The traps that will waste your time if you miss them

1. **Do NOT use closures/lambdas for the generated cases.** The repo has zero precedent for
   capturing closures in record fields or lambda syntax anywhere in `src/`/`scripts/`
   (verified). Plan D5 mandates a direct seed loop: `run_tool_heavy(seed) -> bool`, a
   recursive `run_seeds(base, n) -> int` failure counter, harness helpers for reporting.
   Do not import `Scenario`/`run_all` in the seeded gate.
2. **`std/rand` is global-state**: call `rand_seed(seed)` and draw ALL params immediately,
   before any checking/printing, so each case's inputs are a pure function of its seed
   regardless of run order. Never draw lazily mid-check.
3. **Elision is a no-op for tool content ≤ 80 chars** (verified by the previous
   implementation session; the fixed gate's `long_content()` comment exists because of
   this). The plan draws `content_len` in `[40, 400]` **deliberately** — short-content
   draws legitimately produce `PassThrough`/no-op at every tier. That is why Step 2.4
   asserts **invariants only**. Do not "fix" a short-content `PassThrough` by tightening
   assertions, and do not assert `Compacted` above the elide tier.
4. **Small `n_tools` draws (< keep-last) also legitimately no-op** — same rule: invariants
   only. The single decision assertion allowed is: drawn pct `< elide_tier_pct()` ⇒
   `PassThrough`.
5. **Never hardcode thresholds** (70/85/95 or keep-last values). Compute pct choice points
   from the imported `elide_tier_pct()`/`elide_hard_tier_pct()`/`emergency_pct()`.
6. **Don't reuse the fixed gates' `PASS count=N` line shape** in the seeded gate — it would
   break the anti-silent-drop oracle ("pass count must increase by exactly your
   additions") since seeded counts vary with `DST_SEEDS`. Use the plan's
   `family=... seeds=<N> ok` / `compaction_seeded_dst PASS families=1 base_seed=<k>
   seeds=<N>` shapes exactly.
7. **Effect rows vs caps**: gates run with narrow `--caps` while scenario functions declare
   wide effect rows — that is the established pattern (fixed gate: 10-effect rows under
   `--caps IO`). Annotate `run_tool_heavy` with whatever row `ailang check` demands
   (`compact_for_pre_step`'s row + `Rand` + `IO`); run the gate under `--caps IO,Env,Rand`.
8. **Config errors must be loud**: env var set-but-unparseable or `DST_SEEDS < 1` ⇒ print a
   config error and `exit(1)`. A silent zero-scenario PASS is the failure mode this rule
   exists to prevent. (Unset vars quietly get defaults via `getEnvOr` — that's fine.)
9. **Canary golden values**: run once against the pinned binary to capture the 3 values for
   `rand_seed(12345)` → `rand_int(0, 2147483646)`×3, then pin them as constants. If the
   canary won't stabilize (values differ across runs with the same seed), STOP — that
   invalidates plan decision D1; report it rather than working around it.
10. **Exit-code discipline** (from the 004 note): read each command's own exit status
    directly; never `$?` through a pipe.

## Out of scope (do not touch)

- L1 (`phase_c.l1.*`) seeded families, L2/fast-check, shrinking, grammar generation.
- The fixed gate `compaction_policy_dst.ail` (copy its private helpers into the new script;
  do not modify or export from it).
- `weighted_bool`, generic `pick(xs: [a])`, or other speculative combinators — v1 is
  `pick_int` + raw `rand_int` only.
- Editing ADR-001, the design NOTE (except its status line, see plan Follow-ups), or the
  plan itself (report drift as a finding).

## Definition of done

The plan's Verification section, all six items green:
1. `ailang check` clean on touched/new `.ail` files; `make dst` output byte-identical for
   fixed gates.
2. `make dst_seeded` (defaults 5×base-1) green; two runs diff-identical.
3. `DST_BASE_SEED=7 DST_SEEDS=1 make dst_seeded` twice → diff-identical (replay contract).
4. Deliberately-broken invariant prints `scenario=compaction.gen.tool_heavy seed=<s>
   invariant=<inv>` + `trace param n_tools=.. content_len=.. pct=.. limit=.. usage=..`;
   reverted after.
5. `DST_SEEDS=200 DST_BASE_SEED=20260718 make dst_seeded` green in reasonable time.
6. Canary green on the pinned binary.

Plus: `dst_seeded` in the `dst` aggregate, CI step added per the plan's YAML, and the
NOTE's status line updated to point at the plan.

## Suggested order

Step 0 (harness fix, verify `make dst` byte-identical) → Step 1 (`dst_gen.ail`) → Step 2
canary only (proves `--caps Rand` + determinism end-to-end, captures golden values) →
Step 2 family + loop + config → Step 3 (Make) → Step 4 (CI) → full verification. Each step
leaves the tree `ailang check`-green.
