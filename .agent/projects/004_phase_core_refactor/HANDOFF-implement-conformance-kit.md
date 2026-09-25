# Handoff: implement the conformance kit plan (Plan 1)

Date: 2026-07-08 (written by the conformance-kit plan-authoring/review session)
Audience: a fresh agent session that will **implement** `PLAN-conformance-kit.md`.

## Mission

Implement `PLAN-conformance-kit.md` in this directory — the `motoko_ext_conformance` **package**
(`invariants.ail` the pure contract law, `harness.ail` the test-rig library, `fixtures/` the reject
fixtures), the two root scripts (`scripts/conformance_selftest.ail`, `scripts/conformance_registry_probe.ail`),
the extraction of the compactor-output law **out of** `src/core/phase_vocab.ail` and **back into**
the package (Decision A/B), and the `make conformance` gate. The plan is the normative spec: it
carries re-grounded `file:line` anchors, the frozen ABI surface, the exact predicate/scenario
mapping, per-module wiring, a blast-radius list, and checkable gate commands. Follow it WI by WI (§8).

The kit's own acceptance test is the **fail-then-pass pair**: it rejects the in-kit 0.2.0-behavior
reject fixtures (each on its own named invariant) and accepts `compaction_ai` 0.3.0 and
`compaction_structural` 1.1.0 on all four scenarios. This is **Plan 1**; the ABI surface and both
accept fixtures were frozen by **Plan 2** (shipped) — you *certify* them, you do not change them.

**Do NOT** touch the ABI (frozen), re-open compactor behavior (0.3.0/structural are built to pass),
build the checkpoint trigger (Plan 3), or add composition / `envelope_well_formed` tests (§9).

## Reading order

1. `PLAN-conformance-kit.md` — **the spec.** Read it whole, TL;DR down. The load-bearing sections:
   §1 (ADR gaps G1–G4, closed inside the plan), §2 (inherited decisions A/B/C/D + the ADR-001 §6.1
   amendment text), §4.0 (why an ABI-only package — the dependency argument), §4.1 (the law
   extraction + decomposition + blast radius), §4.2–4.4 (harness / fixtures / self-test), §5 (the
   four scenarios), §6 (probe), §7 (gate commands), §8 (WI sequence), §10 (risks R1–R6).
2. `ADR-001-phase-oriented-core.md` §6 / §6.1 — the normative decision. It is a *decision, not a
   plan*; the plan's §1 records where §6.1 under-specifies (the harness boundary, the ABI-version
   guard, the predicate/scenario mismatch). Do not re-open §6.1; if HEAD contradicts it, that is a
   finding to report, not a redesign licence.
3. `HANDOFF-write-conformance-kit-plan.md` — the handoff that produced the plan; carries the four
   decisions (A/C/D closed with the operator, B scoped) so you inherit them settled.
4. `NOTE-remaining-dst-work-scope-and-sequence.md` — why this is Plan 1 and where the Plan 2 / Plan 3
   boundaries fall.
5. `NOTE-ailang-run-exit-code-false-alarm.md` + memory `verify-before-claiming-substrate-defects` —
   measurement discipline: minimal repro before any substrate-defect claim; never read `$?` through
   a pipeline; assert on a run's **printed verdict**, not exit code. You will be measuring caps and
   fail-then-pass empirically — this is not optional.
6. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` — the mandatory
   re-verify-every-anchor rule below.
7. Orientation (not normative): `mmd/conformance-kit-plan.svg` (build flow) and
   `mmd/conformance-kit-end-state.svg` (the as-built import graph you are producing).

## Ground truth to re-establish before you touch code

- **Toolchain:** root `ailang.toml` pins `ailang = ">=0.26.0"`. Run `ailang --version`; if it is
  below 0.26.0, STOP and flag.
- **The plan's anchors are grounded at HEAD `44a4c6e`.** Everything added since (the plan, the two
  `mmd/` diagrams, this handoff) is **doc-only**, so the source anchors still hold — but run
  `git log --oneline -12` first, and if any commit has since touched `src/core/phase_vocab.ail`,
  `src/core/ext/runtime.ail`, `scripts/phase_c_l1_scenarios.ail`, the ABI, or the compactor packages,
  **re-verify every `file:line` in the plan before trusting it.** Line numbers in `phase_vocab.ail`
  (validator ~`:233–294`, its tests ~`:943–966`) and `runtime.ail` (`:27`, `:170`) drift on a live
  branch. Re-ground, don't assume.
- **Green baseline — capture before starting, so any red is attributable to your change:**
  ```
  ailang --version
  ailang check src/core/ext/runtime.ail
  ailang check src/core/phase_vocab.ail
  ailang test  src/core/phase_vocab.ail                                  # incl. the 3 validator tests you will MOVE
  ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail     # imports validate_compactor_output (:266) — must stay green
  make check_core
  ```
  The law move (Decision A) must leave all of these green — `phase_c_l1_scenarios` and `runtime.ail`
  both import `validate_compactor_output` and must keep compiling and passing after you repoint them.

## Decisions are already closed — apply the amendment, do not re-litigate

Unlike Plan 2, **no fresh operator sign-off is required.** Decisions A (law moves to `invariants.ail`
typed on ABI `Msg`, core imports it back), C-i (reject fixtures in-kit, not registry-resolvable), and
D (`--caps IO` hook-driving floor) are **closed with the operator**; B (decompose the monolithic
validator into the three named predicates) is **scoped** in the plan. Carry them as settled. Your one
obligation on landing: apply the **ADR-001 §6.1 amendment text** (plan §2) into the ADR — the D9 /
D-B5 pattern (WI-7). If your own re-grounding *contradicts* a closed decision, that is a **finding to
report**, not a re-open.

## Confirm the AILANG workspace-resolution assumptions FIRST (spike before you build)

The plan's highest residual risk is **R6**: three AILANG package/script resolution behaviors the plan
*infers* from existing patterns but does not prove. If any is false, the file layout (§4) needs
adjustment — so **spike them in ~30 minutes with throwaway files before writing the real modules**,
asserting on printed `ailang check`/`ailang run` verdicts (measurement discipline above):

1. **Core imports a package module by path.** A `src/core` file can
   `import pkg/sunholo/motoko_ext_conformance/invariants (validate_compactor_output)` given a root
   `ailang.toml` path dep (mirrors the existing ABI dep).
2. **A package can export a module a root script imports, while it stays out of `[extensions]`.**
   `fixtures/reject_fixtures` in `[exports] modules` is importable by `scripts/conformance_selftest.ail`
   yet never appears in `registry_generated` (Decision C-i).
3. **Root scripts resolve compactor + `src/core` imports against the root `ailang.toml`.**
   `scripts/conformance_selftest.ail` can import `compaction_ai`/`compaction_structural` registers
   (which themselves import `src/core/*`) with no cycle, because it is a root script, not a package
   module. **This is why the self-test and probe are root scripts, not package modules (§4.0).**

If a spike fails, report it as a new gap and adjust §4 layout — do not invent a workaround silently.

## Execution order and the strangler contract

Implement in plan order (§8, WI-1..WI-7), preceded by the resolution spike above. **Each WI must
leave the tree `ailang check`-green and the baseline suites green before you move on.** The law move
(WI-1) is the one that touches live core; land it atomically (move + repoint + root dep) so core is
never half-migrated.

- **WI-1 — Extract & decompose the law** (§4.1). Create `packages/motoko_ext_conformance/{ailang.toml,
  invariants.ail}`; move the validator cluster from `phase_vocab.ail`, **retype on ABI `Msg`**, split
  into `no_system_in_output` / `pairing_preserved` / `ids_preserved` + the composed
  `validate_compactor_output` wrapper; port the 3 tests + add per-predicate + equivalence tests.
  Repoint importers (`runtime.ail:27`, `scripts/phase_c_l1_scenarios.ail`); add the root path dep;
  `ailang lock`. Gate: `ailang test invariants.ail` (zero caps) + `ailang check runtime.ail` +
  `make check_core` + `phase_c_l1_scenarios` still green.
- **WI-2 — Harness library** (§4.2). `harness.ail` **no `main`, imports only ABI + `invariants`**;
  ctx builder, canned/poison fake ports, adapted report shape, `run_scenario`/`run_conformance`, the
  four scenario constructors, JSONL emitter, **local copies** of `same_msgs` + the three
  `ctx_defaults` constructors (keep the kit core-free). Gate: `ailang check harness.ail`.
- **WI-3 — Reject fixtures** (§4.3). `fixtures/reject_fixtures.ail`, three per-bug variants, each
  failing **exactly one** invariant. Exported; never in `[extensions]`/`registry_generated`.
- **WI-4 — Scenarios + `scripts/conformance_selftest.ail`** (§5, §4.4). Scenario bodies in `harness`;
  the root self-test script asserting fail-then-pass **by invariant name** + the liveness guard.
  Gate: command 3.
- **WI-5 — Measure caps & finalize floors** (Decision D). Confirm `--caps IO` drives a fixture green
  and a ports-bypassing fixture faults on the withheld cap; record the confirmed self-test/probe
  floors (`IO,Env,FS`).
- **WI-6 — Registry probe** (§6). `scripts/conformance_registry_probe.ail` via `parse_core_ext_order`;
  run command 4 over the full registry (compactors certified, non-compactors pass vacuously).
- **WI-7 — Gates + amendment** (§7). Add the `make conformance` target (registry/conformance class,
  distinct from core-DST); apply the ADR-001 §6.1 amendment (§2); `ailang lock`.

## Hazards specific to this plan (the review's hard-won corrections — read before coding)

These are seven defects the review caught in the *first* draft of the plan; a naive implementation
will re-introduce them. Each is spelled out in the cited plan section.

1. **Predicate quantification is over the OUTPUT, never the input** (§4.1, the ⚠ box). The core
   validator iterates *output* messages only, so a compactor that **drops a complete tool pair** (both
   sides) is *accepted* — and that is exactly what `compaction_ai` 0.3.0 does when it summarizes old
   turns. A predicate written "for every id *in input*, presence must agree in output" is **stricter
   than the law** and makes 0.3.0 fail its own cert. Your test battery **must include a
   dropped-complete-pair case asserting `Ok` / all three booleans true**.
2. **The fake `ai_step` is a constant per-run port, not a cross-call script** (§4.2). Its signature
   `(string,[Msg]) -> Result[string,string]` is stateless and `compact_with_ai` calls it **at most
   once** per compaction. Do not build a call-counting/scripted port (unimplementable purely). Use two
   **constant** fakes: a canned summary and a poison sentinel; the cache scenario swaps the whole ctx
   between runs.
3. **The probe uses the exported `parse_core_ext_order`, NOT `resolve`** (§6). `resolve`
   (`registry_generated.ail:26`) is **not exported** and cannot be imported. Feed a CSV of the short
   names to `parse_core_ext_order(csv, cfg) -> ExtRegistry` and fold `run_conformance` over
   `registry.hooks`.
4. **`harness.ail` is a `main`-less library; the self-test lives in a root script** (§4.0, §4.2,
   §4.4). If you put the self-test `main` in `harness.ail`, it drags `compaction_ai`,
   `compaction_structural`, and the fixtures into **every extension's** build. If you make the
   *package* depend on the compactors, you pull `src/core` into an ABI-only package and risk a cycle.
   Keep the package ABI-only; put `main` + fixture/accept imports in `scripts/conformance_selftest.ail`.
5. **The wrapper must preserve exact Err strings/order; two encodings coexist** (§4.1, R1). Core
   imports `validate_compactor_output` back and its per-stage `Err` message must be byte-identical, so
   the wrapper keeps the id-aware recursion (the id-bearing messages can't be rebuilt from booleans);
   the three booleans are separate total scans over the same helpers. **Pin them with the equivalence
   test** `is_ok(wrapper) == (no_system ∧ pairing ∧ ids)`. And the **one load-bearing compile**: after
   the retype, `runtime.ail:170` passes **core `Msg`** into an **ABI-`Msg`** param (the reverse of the
   compat direction shipping code exercises today) — confirm with `ailang check src/core/ext/runtime.ail`;
   if it fails, wrap `msgs` through the existing `messages_to_msgs`/`msgs_to_messages` round-trip.
6. **Scenarios pass vacuously on `PassThrough`** (§5). Certifying 0.3.0/structural proves nothing
   unless the segment **forces compaction**: set `ctx.context_limit` very low (drives `usage_percent`
   past every tier), give the segment **long tool content** (so structural elides) and **enough
   non-system turns** (so 0.3.0's `split_body` yields non-empty `old`). The self-test adds a
   **liveness guard** (accept packages must return `Compacted`, not `PassThrough`). Non-compactors in
   the *probe* passing vacuously is correct — they make no compaction claim.
7. **Fixtures fail exactly one invariant, asserted by name; caps floors are split** (§4.3, §7, R3).
   Assert the specific `failed_invariant` string, never merely `failures > 0`. Hook-driving is
   `--caps IO`; the self-test and probe need `--caps IO,Env,FS` (constructing real hooks and
   `parse_core_ext_order` perform `{Env,FS}` — not the scenarios). Keep the two gate classes distinct
   (registry/conformance = hydration; never fold into core-DST Makefile targets).

## What you own vs what you must NOT touch (§9)

- **Own:** the `motoko_ext_conformance` package (`invariants.ail`, `harness.ail`,
  `fixtures/reject_fixtures.ail`, `ailang.toml`); the two root scripts; the law extraction from
  `phase_vocab.ail` + repointed importers + root `ailang.toml` dep; the `make conformance` target; the
  ADR-001 §6.1 amendment.
- **Do NOT change the ABI** (frozen by Plan 2) or **re-open compactor behavior** — `compaction_ai`
  0.3.0 and `compaction_structural` 1.1.0 are built to pass; you certify them, you do not modify them.
- **Do NOT** add the fixtures to `[extensions]` / `registry_generated` (Decision C-i keeps a known-bad
  compactor off the registry-probe path).
- **Do NOT build:** the checkpoint trigger (Plan 3); `envelope_well_formed` / tool-handle
  certification (deferred, G3); cross-extension composition or provider-payload tests (owned by core
  L1 / the transcript gate, §9); the `generate-extension-registry` companion name-list emitter (note
  it, don't build it).

## Report back

If any anchor has drifted, a resolution spike fails, or §6.1 turns out to under-specify a fact not
already in the plan's §1 gaps, **record it as a new gap in the plan (or a findings note) and surface
it — do not invent policy to route around it.** The review already found and closed seven such issues
(the hazards above); AILANG's workspace-resolution behavior (R6) is the most likely place a new one
hides. ADR-001 §6.1 is a decision; a real under-specification is a legitimate gap, not a licence to
design.
