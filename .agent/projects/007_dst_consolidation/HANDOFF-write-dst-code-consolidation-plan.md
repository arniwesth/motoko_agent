# Handoff: write the Track 2 plan — DST code consolidation

Date: 2026-07-12 (written by the scope-holding session)
Audience: a fresh session that will **author `PLAN-dst-code-consolidation.md`** in this directory.
Sequenced **after Track 1 lands** (CI protection first — see the scope note). You write the plan;
implementation may be the same or a later session.

## Mission

Plan the extraction of the duplicated DST scenario-runner machinery into one shared module,
normalization of scenario IDs onto the dotted namespace, a `make dst` umbrella target, and a
`scripts/` layout that separates DST gates from spikes/probes/smokes. **Behavior-preserving
refactor**: same scenarios, same invariants, same pass counts, same wire behavior.

## Reading order

1. `NOTE-dst-consolidation-scope-and-sequence.md` (this directory) — confirmed scope. The
   `smoke_v2_*` retirement audit is **operator-deferred**; do not scope it in.
2. The duplication evidence (re-verify at your HEAD):
   - `scripts/phase_c2_wiring_scenarios.ail` and `scripts/long_qwen_compaction_dst.ail` — the
     `Scenario` record, `ScenarioFailure` record, `run_all` recursion, and per-scenario
     `println("scenario=${s.id} …")` reporting are byte-identical between them (~lines 60–100 in
     each at this writing).
   - `scripts/runtime_status_tool_dst.ail`, `scripts/phase_c_l1_scenarios.ail`,
     `scripts/compaction_policy_dst.ail`, `scripts/conformance_selftest.ail` — variants of the
     same machinery.
   - Every scenario function repeats the effect row
     `! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}`.
3. `src/core/test/` — the existing shared seams (`stub_step.ail`, `scripted_ports.ail`,
   `ext_fixture.ail`). The new `dst_harness.ail` belongs beside them.
4. `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — §"Core Components"
   ("Scenario ids are the stable public contract"; the required failure report: scenario id,
   seed, trace) and §"Layers". The harness you extract should realize that contract in one place.

## Ground truth to re-establish at your HEAD

- Baseline pass counts before any move (at 2026-07-12: compaction_dst → long_qwen 8;
  phase_c_l1 15; phase_c2 18; conformance 4 scenarios + registry probe; runtime_status and
  compaction_policy have their own counts — record them). These are your migration oracle.
- Which scenario IDs are already dotted (`compaction.*`, `conformance.compactor.*`) vs. bare
  (`traced_prose_decisions`, `strict_provider_orphaned_toolcall`, …). Build the full rename map
  in the plan, per script.
- Track 1's CI state: which make targets CI calls. Your moves must keep those targets working
  at every commit (CI calls targets, not paths — that contract is in the scope note).
- AILANG constraints that shape the design: check whether a polymorphic-ish `Scenario` record
  with a single effect row can host all scripts' scenarios, or whether per-layer scenario types
  are needed (L0 scripts run `--caps IO` only; L1 wiring scripts need the full row). Do not
  assume — probe with `ailang check` before freezing the harness signature.

## Decisions the plan must close (operator sign-off where marked)

1. **Layout** (operator sign-off): `scripts/dst/` subdirectory vs. naming convention in flat
   `scripts/`. Whichever wins, the outcome must make "is this a load-bearing gate?" answerable
   from `ls`.
2. **Harness shape**: one `Scenario` type with the maximal effect row vs. per-caps-tier types.
   Driven by the AILANG probe above, not preference.
3. **ID namespace map** (operator sign-off on the final map): dotted, layer-prefixed
   (`phase_c.*`, `compaction.*`, `runtime_status.*`, `harness.*`). Renames change gate output
   lines — anything parsing them (CI greps, docs) must be found and updated (`rg "scenario="`).
4. **`make dst` umbrella**: which targets it chains, and whether existing target names
   (`compaction_dst`, `phase_c_l1`) stay as aliases (recommended: keep them; CI and muscle
   memory reference them).

## Acceptance criteria for the plan you write

- Post-migration, every gate reports the same scenario count as its recorded baseline, and the
  full renamed-ID inventory is enumerated in the plan (no silent drops — a dropped scenario must
  be impossible to miss in review).
- The duplicated runner blocks are deleted, not shadowed — `rg "func run_all"` over `scripts/`
  finds only the shared harness (or nothing outside it).
- Track 1 CI green at every commit of the migration (plan the commit sequence accordingly:
  harness first, then one script per commit).
- `make dst` runs the complete deterministic DST gate set.
- No change to `packages/motoko_ext_conformance` semantics or its ABI-lockstep versioning.

## Guardrails

- Behavior-preserving only: no new scenarios, no invariant changes, no threshold/policy edits.
- Do not touch `smoke_v2_*` scripts (deferred audit) except where one is *also* a DST gate
  dependency — in that case note it, don't move it.
- The conformance kit's `harness.ail` is package-side and ABI-versioned; consolidating it with
  the in-repo runner is **out of scope** unless the plan shows it requires no kit version bump.
- After Track 2 lands, its session writes `HANDOFF-write-dst-as-built-doc.md` (Track 3) — the
  doc consumes the consolidated end state. Don't skip this; it's in the scope note.
