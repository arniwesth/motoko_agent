# Handoff: write the conformance-kit implementation plan (Plan 1)

Date: 2026-07-07 (written by the ABI-v3 implement-and-verify session, which holds the frozen-surface
context Plan 1 consumes)
Audience: a fresh agent session that will **author** `PLAN-conformance-kit.md`. You are deliberately
fresh, same discipline as
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`: if you
cannot produce this plan from ADR-001 §6.1 plus the committed source at HEAD, the ADR has a gap —
report it in an "ADR gaps found" section, don't guess around it. And obey
`re-ground-inherited-anchors-before-building.md`: every `file:line` below is a starting point from
2026-07-07, not a fact — re-run the observation before you build on it.

## Mission

Write `PLAN-conformance-kit.md` in this directory: the implementation plan for the
`motoko_ext_conformance` package (**Plan 1** in `NOTE-remaining-dst-work-scope-and-sequence.md`) —
`invariants.ail` (the pure contract law, imported by core's transcript gate), `harness.ail` (the
test rig), the four compactor scenarios, and the generated registry probe. Its own acceptance test
is the **fail-then-pass pair**: the kit rejects `compaction_ai` **0.2.0** for the two live bugs and
accepts **0.3.0** (and the structural compactor).

Do **NOT** implement. Do **NOT** plan the checkpoint trigger (Plan 3, separate handoff). Do **NOT**
change the ABI surface — it is frozen (Plan 2 shipped; see below). This plan only *certifies* the
surface Plan 2 froze and the 0.3.0 fixture it produced.

## What is now frozen for you (Plan 2 is implemented — commit `e650b56`)

Plan 1 was the one plan that had to wait for Plan 2. That dependency is discharged:

- **ABI 3.0** ships as a workspace path-dep at `packages/motoko-ext-abi/types.ail`
  (`version = "3.0"`). `ExtPorts = { ai_step, proc_exec, clock_now, env_get }` (Open Q3 Option B),
  `ai_step: (string, [Msg]) -> Result[string, string]`; `ExtCtx += {ports, artifacts, telemetry}`;
  `Compacted(msgs, note, artifacts: Json)`; `TokenTelemetry` input/output-only. This is the surface
  the kit's `ExtCtx` fixtures and `Compacted`-output invariants run against.
- **Accept fixture:** `compaction_ai 0.3.0` at `packages/motoko-ext-compaction-ai/` — ports-native,
  prefix-aware (`split_prefix`), pairing-aware (`has_tool_call_id`/`split_body`), artifact-cached
  (`cached_summary`/`cache_artifact` over `ctx.artifacts`). Built to pass the kit; your job is the
  kit that proves it.
- **Reject fixture:** `compaction_ai 0.2.0` still in the registry cache
  (`~/.ailang/cache/registry/sunholo/motoko_ext_compaction_ai/0.2.0/`) — the version with the two
  live bugs (`split_msgs` splits by position, `compaction_ai.ail:101-110`).
- **Structural compactor** `1.1.0` at `packages/motoko-ext-compaction-structural/` — pure, must also
  pass the kit (it is the bundled default).

## Reading order

1. `NOTE-remaining-dst-work-scope-and-sequence.md` — Plan 1's boundaries (lines 35-40) and why it is
   sequenced after Plan 2 (now done).
2. `ADR-001-phase-oriented-core.md` **§6.1** — the plain-language spec; it is effectively the whole
   plan ("execution only — no open decisions," per the sequence note). Read the obligations catalog,
   the caps-as-conformance enforcement model, the who-runs-it split (extension CI vs core registry
   gate), the worked v0.2.0-fails/v0.3.0-passes example, and the lockstep-versioning rule. Then §6
   "Concrete targets" for the package path, scenario ids, commands, and probe.
3. `PLAN-abi-v3-rollout.md` §3 + §6 + §5.4 — the frozen ABI surface, the 0.3.0 design (so you know
   *why* it passes), and the driven-trace caps lesson (§5.4 / G-A5) — which you will hit again (see
   "caps" below).
4. Source you certify (re-ground each at HEAD):
   - **The contract law that already exists in core:** `src/core/phase_vocab.ail:269-293`
     `validate_compactor_output` — a *monolithic* recursive validator, imported and run by the live
     transcript gate at `src/core/ext/runtime.ail:27,170`. §6.1's finer named predicates
     (`pairing_preserved`, `ids_preserved`, `no_system_in_output`, `envelope_well_formed`) do **not
     exist** — they are bundled inside this one function (no-system←`:273`, severed-pair←`:264,283`,
     invented/empty-id←`:262-263,281`). Decomposing this is core plan work (Decision A below).
   - **Fake-ports pattern:** `scripts/smoke_ports_record.ail` — §6.1 names it as the harness's
     scripted-pure-ports model. Confirm it still demonstrates the pure-fake pattern under minimal
     caps.
   - **Registry probe surface:** `src/core/ext/registry_generated.ail` — `resolve()` /
     `parse_core_ext_order()` and the per-package `register_*` imports the probe iterates.
   - **Driven-trace harness precedent:** `scripts/phase_c2_wiring_scenarios.ail` — how scripted
     `ExtensionHooks` + fake ports drive hooks and assert over outputs; the harness is a cousin.
5. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` and the
   `verify-before-claiming-substrate-defects` memory (minimal repro; never read `$?` through a pipe;
   assert on printed verdicts — you will be measuring caps and fail-then-pass empirically).

## The decisions this plan must close (with operator sign-off, D9 / D-B5 pattern)

The sequence note calls Plan 1 "execution only — no open decisions." **Re-grounding at HEAD found
otherwise** — the ABI froze cleanly, but the *law's current home in core* plus the ABI-major gap in
the reject fixture forced four. **Three are now closed with the operator (A, C, D); B is scoped and
coupled to A.** They are recorded below so the planning session inherits them settled — do not
re-litigate; just carry the amendment text into ADR-001 §6.1. (If your own re-grounding contradicts
one, that's a finding to report, not a re-open.)

- **Decision A — where the contract law lives / dependency direction. → CLOSED 2026-07-07 (operator
  sign-off): A1.** The contract-law predicates move **out of** `src/core/phase_vocab` **into**
  `packages/motoko_ext_conformance/invariants.ail`, and **core imports them back** (`runtime.ail`
  imports the `invariants` module, never `harness`). This matches §6.1 verbatim ("invariants.ail …
  imported by the core transcript gate").
  - **Enabling detail (do this or you create a cycle):** type the law on the **ABI `Msg`**
    (`pkg/sunholo/motoko_ext_abi/types.Msg`), not `src/core/types.Msg`. `src/core/types.Msg` is a
    separate-but-structurally-identical definition (`types.ail:10,16`); typing invariants on core
    `Msg` would make `conformance-pkg → src/core → conformance-pkg`. On ABI `Msg` the graph is
    `core → conformance/invariants → ABI` (acyclic; core already `→ ABI`). Core can still call the
    law with core `Msg` — that structural compat is **already exercised in shipping code** at
    `runtime.ail:170` (an ABI `Msg` from the ABI `Compacted` is passed where core `Msg` is expected
    and compiles), so the retype is cheap, likely conversion-free.
  - **Blast radius to enumerate in the plan:** move `validate_compactor_output` + its helpers
    (`validate_output_calls`, `has_assistant_call_id`, `has_tool_result_id`,
    `validate_compactor_output_rec`, `phase_vocab.ail:240-293`) + their tests out of `phase_vocab`;
    update importers `src/core/ext/runtime.ail:27,170` and `scripts/phase_c_l1_scenarios.ail`; keep
    core's `import` granularity so `harness.ail` never enters core's build.
  - **Accepted cost:** core's build now depends on the conformance package existing — this *is*
    §6.1's shared-single-law coupling, not an accident (rejected A2 because it drags all of
    `motoko_core` into every extension's conformance CI; rejected A3 as either blurring §6.1's
    shapes/behavior split or adding a second package + lockstep version).
  - **Amend ADR-001 §6.1** on landing: note the law's canonical home is `invariants.ail` typed on
    ABI `Msg`, extracted from `phase_vocab` (the D9 / D-B5 amendment pattern).
  - Pairs with **Decision B** (decomposing the moved monolithic validator into the named
    predicates) — do them together, since both edit the same functions.
- **Decision B — decompose the monolithic validator into named invariants.** §6.1 requires failures
  to name the *first failed invariant* (`pairing_preserved` etc.). Today there is one `Result[(),
  string]`. The plan must split it into the four named predicates and define how core's coarse
  wrapper composes them (so the transcript gate keeps its single Err message while the harness gets
  per-invariant booleans). Scope the refactor + its blast radius; this pairs with Decision A.
- **Decision C — the reject fixture. → PARTIALLY SETTLED (premise corrected 2026-07-07; sub-choice
  C-i/C-ii open for the plan).** The original framing ("load two versions of the same package, one
  lockfile") is a **false premise**: published `compaction_ai 0.2.0` targets **ABI 2.2.0**
  (`its ailang.toml: motoko_ext_abi = "2.2.0"`, 2-arg `Compacted` at `:148`) — it **cannot compile
  or link under the ABI-3.0 harness**, and its `std/ai.step` port-bypass would fault on a missing
  `AI` cap (failing for the *wrong* reason, before any invariant observes bad output). §6.1's own
  worked example already presumes a **ports-consuming** buggy compactor ("a fake `ai_step` port
  returning a canned summary"), not the shipped `0.2.0`.
  - **Therefore:** the reject fixture is a **frozen ABI-3.0 regression fixture** — ports-native (so
    scenarios observe its bad *output*), reproducing `0.2.0`'s positional `split_msgs` (severs system
    prefix + tool pairs) and no-cache behavior. Published `0.2.0` stays as provenance
    documentation, not a loadable artifact. No lockfile version-swap: both fixtures are ABI-3.0,
    loaded side by side. The fail-then-pass is the **kit's own self-acceptance test**, distinct from
    the registry probe (which tests whatever the lockfile resolves — now `0.3.0`).
  - **Sub-choice → CLOSED 2026-07-07 (operator): C-i.** The reject fixture is an **in-kit
    `fixtures/` module**, hand-written ABI-3.0 `ExtensionHooks` modeled on the 3.0-clean
    `src/core/test/ext_fixture.ail` (`Compacted(msgs, note, empty_ext_artifacts())`, `:89`).
    Self-contained, single run, no package/version overhead — and it must **not** be registry-
    resolvable (C-ii, a standalone fixture package modeled on `packages/motoko-ext-test-dummy/`, was
    rejected precisely to keep a known-bad compactor out of the registry-probe path). The cap-floor
    measurement (Decision D) built exactly this pattern and confirmed it drives `compact_with_ai`
    through fake ports cleanly.
  - **Plan must also carry** (not a decision): the fixture likely needs **per-bug variants**
    (prefix-dropping, pair-severing, no-cache) so each scenario fails on *its own* invariant rather
    than all failing on the first flaw hit.
- **Decision D — the harness's real cap set. → CLOSED 2026-07-07 (measured): `--caps IO`.** §6's
  `--caps IO` is **correct for the hooks harness** — confirmed empirically, not inherited on faith. A
  throwaway harness (fake ports + one `compact_with_ai` call + output check, the exact C-i pattern)
  ran `compaction_ai 0.3.0` **green under `--caps IO`**; with no caps it faults only on `IO` (the
  harness's own `println`). The compaction hook under fake ports performs **no gated effect**, so the
  floor is bare `IO` — sharply unlike Plan 2's *driven-loop* scenario (`IO,Env,Clock,FS,Trace`,
  because the full loop performs `now()`/`Trace`/FS/Env). This is caps-as-conformance working as
  designed: a compactor that **bypassed** ports (`std/ai.step` directly) would need `AI`, which
  `--caps IO` withholds, and would fault at the bypass — so the harness *at `--caps IO`* **is** the
  enforcement. The plan should still re-measure once the real harness adds its own scaffolding (e.g.
  reading fixtures), but the floor for hook-driving is settled.

## Deliverables the plan must specify (ADR §6 / §6.1)

1. **`packages/motoko_ext_conformance/`** — `invariants.ail` (pure predicates, `ailang test`-able,
   zero caps, per Decision A/B) + `harness.ail` (test-only; scripted `ExtCtx` + fake ports; drives
   one package's `ExtensionHooks` through scenarios; on failure reports scenario id + first failed
   invariant + normalized JSONL trace, same shape as the core ledger). `ailang.toml` at
   `conformance` major **3.x** (lockstep with ABI 3.0), exporting `conformance_abi_version()`; the
   harness refuses a mismatched ABI loudly.
2. **Four scenarios**, exact ids: `conformance.compactor.system_prefix_preserved`,
   `conformance.compactor.tool_pairing_preserved`, `conformance.compactor.deterministic_replay`,
   `conformance.compactor.artifact_cache_effective`. The first two fail on 0.2.0 / pass on 0.3.0;
   the cache scenario re-runs with run-one's artifacts and an **empty `ai_step` script** (0.2.0
   re-calls the port → poison; 0.3.0 hits the cache → passes).
3. **Registry probe** `scripts/conformance_registry_probe.ail` — imports
   `registry_generated.ail`'s package list, runs the harness per package in core CI (the
   hydration-required gate class).
4. **Gate / acceptance criteria** as checkable commands — `ailang check
   packages/motoko_ext_conformance/harness.ail`, then the harness pointed at each package under test
   (Decision C arg convention), plus the fail-then-pass proof against 0.2.0/0.3.0. This is the
   **registry/conformance gate class** (hydration required) — keep it distinct from core-DST gates,
   per ADR §6 "Gate separation."

## Out of scope (owned elsewhere)

- Cross-extension composition, provider payload acceptance, cross-package id uniqueness, resource/
  time budgets — each has an owner in §6.1's "what it deliberately does NOT do." The obligations are
  composition-closed by design; do not add composition tests.
- The checkpoint trigger (Plan 3). Any ABI change (frozen). Any new compactor *behavior* — 0.3.0 is
  built; you certify it, you don't re-open it.

## Discipline reminders

- §6.1 is a decision *and* very nearly a plan — thicker than §6 was. If a needed fact (e.g. how a
  package-under-test is selected at the harness boundary) is not derivable from §6.1 + source, that
  is a legitimate gap; record it, don't invent a convention silently.
- Re-verify every anchor at HEAD before relying on it — the ABI moved from registry cache to
  `packages/` in the Plan 2 implementation; `src/core` line numbers drift on a live branch.
- One plan, this scope only. The fixtures exist; the surface is frozen; your job is the executable
  law that turns "certified" from a README claim into a gate.
