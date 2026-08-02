# Plan: implementing ADR-001 — the deterministic test-world migration

Status: Proposed. Date: 2026-08-02.
Basis: `ADR-001-deterministic-test-world-architecture.md` (Accepted 2026-08-02) and the project-007
taxonomy ADR (Accepted 2026-07-26). Source ground: HEAD `eabaac8`, pinned AILANG v0.26.0.
Mandated by: the ADR's `## Implementation handoff` and `HANDOFF-implementation-plan.md`.

**This is a build order, not a second specification.** The ADR names every mechanism and states
every acceptance criterion; this plan sequences building them and says what evidence discharges
each. Per `measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`, no
work item below refines *how* a detector decides anything — where that question arises during
execution, the answer is a spike against the artifact, not a paragraph in this document.

## Survey: executed at HEAD, 2026-08-02

The ADR's handoff requires ten re-verifications. All ten were run against HEAD `eabaac8` on the
pinned toolchain before this plan was written, per `re-ground-inherited-anchors-before-building.md`.

One structural fact makes the whole survey strong: **`git diff --stat a0d4edb..HEAD -- src packages
scripts Makefile .github tools` is empty.** Every source measurement the two acceptance reviewers
verified at `a0d4edb` holds at HEAD by construction. The independent re-measurements below all
agree; **zero anchor corrections were needed** — the first source-dense artifact in this project for
which that is true.

| # | Survey item | Measured at HEAD |
|---|---|---|
| 1 | D1 streaming capture & upstream API | No released AILANG through v0.31.0 exports a recorded-stream API. `sunholo-data/ailang#546` is parked on drain semantics only; the `{chunks, outcome}` shape survived two quorum rounds and can be typed against now. Gate not cleared; the fork prototype clears nothing. |
| 2 | `Ports`/`StepProvider` constructions and consumers | `Ports` has 6 fields (`ports.ail:17-25`). All construction funnels through `ports_shape_probe` (`ports.ail:37`); callers: `live_ports` (`stub_step.ail:148`), `scripted_ports_from_steps` (`stub_step.ail:157`), and `scripts/dst/long_qwen_compaction_dst.ail` (3 sites, plus 3 record rebuilds at `:181`, `:252`, `:750`). Post-`89a1d67`, `C2LoopState.provider` is `Ports`-typed (`session.ail:344`), `dispatch_step` takes `Ports` directly with no dead branches (`stub_step.ail:193-200`), and `ported_provider` (`session.ail:695`) returns bare `Ports` from 6 call sites (`:2015`, `:2051`, `:2114`, `:2137`, `:2267`, `:2295`). `StepProvider` survives as the entry-point argument type only. 32 `provider:` literals in `session.ail` bound the widening's edit surface. |
| 3 | World-state threading feasibility | Spike Q1 confirmed against the real driver (`NOTE-spike-findings-real-driver-vertical.md`); `C2LoopState` (`session.ail:338`) is a 19-field record threaded by one loop. |
| 4 | Direct ambient effects reachable in a session | Classifier 1 re-run at HEAD: union 25 modules, 21 imported, 13 effect-bearing, 8 proven effect-free, **0 unresolved**; `make effect_inventory_selftest` → `agree=43 disagree=0`. Clock: **13 `now()` sites** — 4 driver (`session.ail:791,842,1991,2089`), 1 `ext/runtime.ail:190`, 8 `motoko-ext-compose`. `readLine`: 2 sites (`session.ail:1619` approval, `:2196` conversation loop). `std/sem` `SharedMem` read at `rpc.ail:200`. **Nothing routed**; `ExtPorts.clock_now` has **zero call sites** (`grep -rn '\.clock_now('` is empty). |
| 5 | Tool/timeout contracts | `tool_exec` is stringly (`ports.ail:22`). Timeouts ride in requests — `timeout_secs` in `tool_catalog.ail:53` schema and `env_client.ail:31 exec_in` — enforced outside the AILANG driver. No in-profile module observes time; D4's first time-bearing seam (typed `ToolCallEnvelope` + deadline) is a contract to build. |
| 6 | Hooks in the baseline profile | Eight closed ABI slots (`motoko-ext-abi/types.ail:151-165`): three rowless, `on_budget_plan` at `{Env, FS}`, four at the nine-effect row; six dispatched by unconditional fold, only `on_tool_handle` gated. `.ai_step(` call sites: exactly **2** (`compaction_ai.ail:106`, `reject_fixtures.ail:90`). The baseline profile below installs no extensions, so its profile-reachable hook set is empty. |
| 7 | Traced-driver returns | All terminal summaries route through `emit_run_summary` (`session.ail:833`; call sites `1325` [shared error helper], `1554`, `1704`, `1711`, `1762`), whose only ledger operation is the `ledger_emit` projection. **Zero `RunSummary` in the returned trace on every path** — D6.1's starting count confirmed. `session.ail`: 37 `ledger_emit` vs 15 `ledger_append`. |
| 8 | Event vocabulary & consumers | `LedgerEvent` has **34 variants** (`phase_vocab.ail:597`); `ledger_record_name` (`phase_vocab.ail:561`) names 3 and collapses 31 to `"wire"`; wire names live in trailing comments; the consumer is a TypeScript `switch` in another process. Terminal reasons are integer codes through `finish_reason_str(r: int)` (`session.ail:820`) — the helper D6.2 requires replaced. |
| 9 | Seeded families & CI | `make dst` aggregates `compaction_dst conformance phase_c_l1 smoke_parity dst_l2 dst_seeded`; `dst_seeded` runs two seeded **scalar** families under `--caps IO,Env,Rand`. The only workflow is `verify-extensions.yml`. No generated-trajectory axis exists; nothing currently claims the DST name. |
| 10 | Exhaustive matches & configs | `match provider` at `session.ail:696` and `scripted_ports.ail:31` are the only `StepProvider` matches left. 14 checked-in configs, **all 14** installing `compaction_ai`; `compose` only in `.motoko/config/ailang`; `test_dummy` in none; `motoko_ext_conformance` absent from `registry_generated.ail`. Latent under-declarations confirmed present: `agents_md.ail:106 walk_agents` performs `FS` rowless; `a2a.ail:131` calls `uuid4()` under a row without `Rand`. |

Executable checks run for this survey: `make effect_inventory` and `effect_inventory_selftest`
(clean, above), and `scripts/dst/spike_scripted_cursor_probe.ail` against HEAD — **F6 reproduces
exactly**: `folding: served=[s0,s1,s2,s2,…] advancing=false`, `FAIL`, `exit(1)`. The probe is the
executable statement of the first defect this plan fixes.

## Decisions this plan owns

The ADR deliberately left five decisions to the plan. They are answered here, once, so no work item
re-litigates them.

**P1. `ProviderState` is a record, not a sum.** Declared in `src/core/ports.ail` as a record whose
first field is the scripted cursor (the remaining-script tail, the threading style
`scripted_model_next` already demonstrates). Ground: M1 measured additive record widening as cheap
and mechanical (69 sites, 14 minutes) while the 7 expensive sites were the ones needing structural
judgement — a record makes any future cursor an *additive field*, a sum would make it a variant
restructuring. The live/`Ported` value is the record with an empty script; live adapters return
their input unchanged (D1's specified identity transition).

**P2. The approval and clock cursors do not ride along in the interim widening.** Neither has an
interim consumer: scripted-run approvals resolve through policy today, and the virtual clock only
exists once `world_state` lands — which subsumes and deletes the interim field anyway (D1). Dead
rider state threaded through every construction site would be cost without a customer. The risk the
ADR warns about — reproducing the bidirectional widening — is closed **structurally, not by
guessing**: because of P1, adding a cursor later changes no port signature; the state parameter
stays `ProviderState` and the addition is an M1-class additive edit. `ScriptedPortsState`
(`scripted_ports.ail:20-24`) already models all three cursors and remains the design precedent for
that addition if a pre-`world_state` need materialises.

**P3. Clock routing order, and the first routed-set claimant.** Order: (1) the four driver sites,
routed to the world clock as part of WI-A13 — every profile needs them; (2) `ext/runtime.ail:190`
is never routed — it is *attributed* to `test_dummy` in the WI-A6 table, which is what removes it
from the baseline's reachable set; (3) the eight `motoko-ext-compose` sites are deferred to
Milestone C, because they route through `ExtPorts.clock_now` — a seam with zero call sites that may
not survive first contact — and belong with the ABI major. The first profile to claim a routed set
is `driver_only` (P4), claiming **4 routed sites** — a claim that per D4's scheduling prohibition
cannot be made before the attribution table validates (without it the fail-closed obligation is 5).

**P4. The first conformant profile is named `driver_only`, v1.** A purpose-built narrow profile,
per D10 deliberately not carrying "DST" or "simulation" in its name: the real traced driver plus
the main-loop cursor, **empty extension install list**, covering no extension behaviour — exactly
the interim profile the ADR describes. Its definition records: no installed extensions (so the
coverage floor and per-hook disclosure hold vacuously), the D3 extension-effect fault class waived
with its condition (no effectful hook installed), the attribution-table reference, and a reachable
clock set of the four driver sites. It is the documented baseline profile for the Milestone C
name-adoption run. No shipped configuration can be the first profile: all fourteen install
`compaction_ai`, which calls `ai_step` and must be **omitted**, not installed-and-excluded (D1/D5).
A `compose`-bearing profile is the planned second claimant, in Milestone C.

**P5. The `stub_step.ail:170-173` stale comment** ("Returns both the step result and the updated
provider… thread next_provider") describes the pre-`89a1d67` contract and is deleted in WI-A2,
which rewrites that region anyway. The ADR's anchors into `stub_step.ail` are re-grounded in the
same change, filed as a normal amendment — not a review round.

**P6. `Ports.hooks_runtime` is removed.** D1 requires the plan to give it a demonstrated production
purpose or remove it. The survey found zero calls of the field repo-wide — only constructions. It
is deleted in the same edit wave as WI-A1 (both touch every construction site; separate commit).

## Work items

Milestone A is upstream-independent and starts now. Milestone B is **triggered**, not queued: it
begins the day a released AILANG ships the recorded-stream API, and interleaves with whatever A-item
is in flight. Milestone C depends on B. Sizing cites M1/M2 from
`NOTE-spike-findings-real-driver-vertical.md` rather than re-estimating; "M1-class" means additive
and mechanical with a compiler-driven fix loop written first — the 14-minute figure held *only*
because tooling preceded editing, and that discipline is part of each estimate.

### Milestone A — pre-repin (pinned v0.26.0)

**WI-A1. Widen `Ports.model_step`'s result with the emission log** (ADR handoff item 1; D1's
loss-channel rule). Behaviour-preserving: `emissions: []` at every construction site. Edit surface:
the `ports.ail` type, `ports_shape_probe`, 2 `stub_step.ail` adapters, 3 `long_qwen` sites, and the
3 result consumers (`dispatch_step`, `ext_ai_step`, `long_qwen:744`). Size: below M1 — 4 files vs
28, same technique; half a day including the fix loop.
*Acceptance evidence:* `make check_core` green (35/35); `make dst` targets pass unchanged; a
`Scripted`-provider test asserts the emission log is present and empty. Note per D1: **this item
does not enable WI-A2** — a successor cursor is not an emission.

**WI-A2. Fix the scripted cursor, main loop only** (handoff item 2; D1 cursor ownership; F6).
Depends on A1 (ADR-fixed order). The second, bidirectional widening of the same field — state in
and out — reviewed as a distinct change. Contents, all ADR-named: concrete `ProviderState` (shape
per P1) declared in `ports.ail`; **relocation of `ScriptedStep`** to `ports.ail` or below (both
required consumers close an `LDR002` cycle where it sits today); `ported_provider` returning an
initial-state pair; the sole persistent copy in **one explicit `C2LoopState` field**;
`scripted_ports_from_steps` consuming the threaded cursor instead of deriving position from
`assistant_count` — the arrangement D1 prohibits by name. Includes P5 (stale comment + anchor
amendment). Not behaviour-preserving; `ScriptedPortsState`/`scripted_model_next` is precedent, not
reusable code. Edit surface: `ports.ail`, `stub_step.ail`, `scripted_ports.ail`, `session.ail` (32
`provider:` literals bound the loop-state edits), `agent_loop_v2.ail`, import sites of
`ScriptedStep`, DST scripts. Size: the largest pre-repin item — M1's judgement band dominates;
1–2 days, tooling first.
*Acceptance evidence:* `scripts/dst/spike_scripted_cursor_probe.ail` prints PASS and exits 0, and
is promoted from spike naming into the `make dst` aggregate as a permanent regression test;
`phase_c2_wiring_scenarios` 18/18; `check_core` green; `grep` finds no `assistant_count`-derived
script index. The extension model path is **not** fixed here and no work item pretends otherwise:
`ext_ai_step` (`session.ail:662`) discards state by ABI shape until Milestone B.

**WI-A3. File the two upstream reports — done 2026-08-02**, with this plan, via the
`ailang-feedback` skill's public MCP channel: (a) effect propagation through function-valued
record-field calls — the soundness gap D5's rowless-slot coverability leans on; minimal repro
verified at v0.26.0 (`check` clean, `EFFECT PERFORMED` at runtime, direct-call control correctly
rejected) — ticket `fb_74f53de3ae65854c`; (b) the `ailang iface` defects: `pure: true` alongside
nonempty `effects` on 12 `std/ai` exports (re-verified from `--json` output), the documented
`iface <module>` invocation failing (`cannot read file 'std/ai.ail'`), and `std/secret`'s `MOD010`
hard error auto-relaxing to a warning when run from a temp directory — ticket
`fb_d230853828108783`. Watch for replies when triaged.

**WI-A4. Build classifier 2** — the `ExtPorts` typed-call inventory (gate-mechanisms table). A
program, not a specification; the ADR fixes its contract (typed field-call inventory over `src` +
`packages`, fails closed on every alias, wrapper, re-export, or computed access it cannot resolve;
membership today exactly `ai_step`). Modeled on `tools/effect-inventory/derive.py` with a `make`
target and selftest. Size: classifier 1 took an afternoon; budget the same.
*Acceptance evidence (per the gate table):* at HEAD it reports exactly the two known call sites and
zero unresolved occurrences; a synthetic alias/wrapper fixture is reported as unresolved →
fail-closed triage, not a pass; re-derivation wired into the repin checklist.

**WI-A5. Build the site-to-hook attribution table and its profile-load validation** (D4 clause 3) —
**in the same change as WI-A4**, per D4's producer clause. Initial rows: `ext/runtime.ail:190` →
`test_dummy`; `tool_phase.ail:222` → `scratchpad`; each with a named reviewer recorded, which is
the **stated exception** to the automated-gate promise until the interprocedural necessity
validator exists (that validator is *not* scheduled here; building it prematurely is exactly the
prose-refinement trap).
*Acceptance evidence:* validation rejects unknown hook ids, stale source-revision bindings, and
malformed rows; permits known-but-uninstalled hooks; the empty-intersection rule is exercised by a
test (a row whose hook set misses the profile's installs removes the site); the table's
`(source revision, content hash)` identity is what profiles reference. **Scheduling prohibition
honoured:** no routing-completeness claim anywhere in this plan precedes this item.

**WI-A6. Build coverage-floor and disclosure validation** (D5; gate table, simplified — the
carve-out was deleted at acceptance, so this no longer depends on classifier 2). Profile-load code:
reject any installed extension with zero covered hooks; reject any installed extension with an
unconditionally-dispatched hook excluded; covered/excluded sets disjoint and exhausting all eight
slots; hook **ids**, not counts, in definition and run result.
*Acceptance evidence:* a fixture profile installing an all-excluded extension is rejected; the
rejection reason names the rule; `driver_only` (empty install list) passes vacuously.

**WI-A7. Construct D3's fault catalogue** as a versioned, machine-readable artifact with a
fail-closed validator. New construction; the required classes, per-class fields (stable class id,
applicability condition, delivery constructor, named recovery-branch id, logical transition), and
the 007-D1.3 physical-fault tripwire are all fixed in D3 — the work is the artifact and validator,
not the design.
*Acceptance evidence:* validator fails closed on a class row missing any field or naming an unknown
constructor; the two conditional classes carry their waiving conditions; D11's class-reached and
branch-reached counters read their ids from it (exercised in WI-A14).

**WI-A8. Construct D6's event vocabulary** — the fifth recorded axis. New construction for all 34
`LedgerEvent` variants: variant, wire name, payload schema, logical/display-only classification;
fail-closed on an unclassified variant; preferred form derives the wire name from the type so
drift is a compile error. `ledger_record_name` is not a seed and is not grown.
*Acceptance evidence:* load validation fails closed on a synthetic unclassified variant; the
vocabulary version lands in the execution manifest (WI-A10) and failure record. **Scheduling
prohibition honoured:** no D7 parity invariant or acceptance row depending on the classification is
scheduled before this item completes — WI-A14's invariant set is explicitly split on it.

**WI-A9. Route every terminal path through one finalizer, and type the termination reason** (D6.1,
D6.2). The spike proved `c2_finalize` (append **and** emit) tractable without restructuring the
driver; the starting count is zero everywhere. Replace `finish_reason_str(r: int)` with a typed
termination reason derived from the reachable terminal returns, mapped exhaustively to wire
`finish_reason`.
*Acceptance evidence:* a trace-level test asserts exactly one `RunSummary` as the final record on
every enumerated terminal path (success, budget, max-steps, compaction exhaustion, provider
failure, tool failure, invalid history, internal); returned outcome, `DoneEvent`, and `RunSummary`
agree; no integer code survives at a terminal call site.

**WI-A10. Build the profile definition and execution-manifest machinery, and define `driver_only`
v1** (D5; P4). Depends on A5, A6, A8 (the definition references the attribution table and records
the vocabulary version; load validation wires in the floor/disclosure checks and both classifier
outputs).
*Acceptance evidence:* `driver_only` loads clean; a fixture profile installing `compaction_ai` is
rejected **at definition time** with the classifier-2 reason; the manifest records the five axes
(program schema, generator version, profile id/version, manifest, vocabulary version) plus derived
classifier sets and scan-root commit.

**WI-A11. The predicate documentation check** the ADR assigns to this plan: a canonical
classifier-2 predicate sentence ("calls a classifier-2 field on an `ExtPorts`-typed value, at
extension granularity") plus the explicit list of normative anchors that must contain it, failing
when an anchor drifts or a normative statement appears outside the list. A small script with a
`make` target, CI-run.
*Acceptance evidence:* mutating one anchor in a scratch copy fails the check; the anchor list is
the six sites the ADR names.

**WI-A12. Thread `world_state` through the driver, one effect class at a time** (D1). Depends on
A2; subsumes and deletes the interim `C2LoopState` cursor field in its first change, per D1.
Order within the item: provider (subsumption of A2's field), then the four driver clock sites
routed to the world clock (P3), then approval, then env reads, then runtime randomness; the typed
`ToolCallEnvelope` with deadline replaces stringly `tool_exec` in the same wave — it is D4's named
first time-bearing seam and D1 requires it anyway. Behaviour-preserving throughout: live adapters
delegate to today's code paths; `emissions`/state plumbing verified against `Scripted` providers.
Spike Q1/Q2 confirm feasibility; the spike's surgery is *not* imported — this is fresh work at
HEAD. Size: the migration proper; several days, staged as one PR per effect class.
*Acceptance evidence per class:* existing targets green; the class's poison probe (capability
withheld) passes for the deterministic entry point and fails for the live world — the F3-corrected
per-run backstop; after the clock class, `driver_only`'s routed-set claim (4 sites, citing the A5
table) becomes true and is recorded in the profile.

**WI-A13. Build discovery and replay** (D2). Depends on A7 (class ids), A10 (manifest), A12
(world_state). `ExecutionProgram`/`DiscoveryConfig` types, the seeded generator with declared
bounds, the pure structural validator, strict and regression replay modes, the interaction log with
causal identities and encounter ordinals. Exact type names are plan-level per D2; semantics are
fixed there and not re-litigated here.
*Acceptance evidence:* D7's discovery-contract invariant — same manifest/profile/seed twice →
identical resolved program, interaction log, outcome, normalized trace; a mismatch fixture returns
typed `HarnessFailure` with position and projection; bounds violations fail as generator errors.

**WI-A14. Implement the D7 invariant set and D11 corpus reporting.** Depends on A9, A13; the
parity-classification invariants additionally depend on A8 and are not scheduled before it. Corpus
minimum seed counts are **selected from measured CI cost at this point, not invented now** — the
measurement is part of the work item, consistent with D11.
*Acceptance evidence:* every D7 bullet has a runnable invariant; a run report carries the full D11
field list; class-reached vs branch-reached are separate counters read from A7's artifact.

### Milestone B — the repin (trigger: a released AILANG carrying the recorded-stream API)

**WI-B1. Repin the toolchain.** Update `ailang.toml`, `scripts/install-prerequisites.sh:39`, and
the Makefile guard together; **clear every `.ailang/cache` in the tree before believing any
diagnostic** (the phantom-type-error trap reproduced across a version change). Size: **M2, measured
— 381 effect-row edits across 71 files**, almost all mechanical via the compiler-driven repair
loop; the two latent under-declarations (`walk_agents` `FS`, omnigraph `register_with_config`
`Process`) become hard errors and are fixed here.

**WI-B2. The extension-ABI major.** One coordinated major, containing both ADR-named parts: the
three `motoko-ext-abi/types.ail` row corrections (`ExtPorts.ai_step` gains `Trace`; the four
`ExtensionHooks` rows gain `Rand` and `Trace`) **and the world-token widening of `ExtPorts.ai_step`
plus the hook results and core dispatch results — the larger of the two** (Consequences). Lockstep
re-release of every extension package. This is what lifts D1's extension-model-path exclusion;
until it lands, an `ai_step`-calling extension is omitted from any conformant install list.

**WI-B3. The `Message` migration** (vision/images field of the new pin). Size: **M1, measured — 14
minutes, 28 files, 69 additive sites, 7 judgement sites** — with its two riders honoured: tooling
first (the brace-balanced rewriter and fix loop are what made 14 minutes true), and the settled
decision that Motoko's `Msg` and the ext-ABI `Msg` stay at four fields, vision parts dropped at the
seam.

**WI-B4. Re-derive both classifiers on the new pin** and re-record their sets and scan-root commit
in the profile/manifest — a required step of every repin, per D5. Re-run `make effect_inventory`,
`effect_inventory_selftest`, and the classifier-2 target; re-issue `driver_only`'s manifest.

### Milestone C — post-upstream

**WI-C1. Adopt the recorded-stream API in the one `live_ports` closure.** The blast radius A1
bought: one closure. Depends on B1.

**WI-C2. The direct positive integration probe** (D1's gate): immediate projection, exact
returned-log parity, success, partial-stream-then-error, no duplicate delivery. Its passing is the
substrate-gate evidence D1 requires; the forbidden delayed-projection fallback must not be
selected silently.

**WI-C3. The streaming-trace parity invariant** (D6.4's named exception, checked explicitly).
Depends on C2 and A8.

**WI-C4. Run the name-adoption gate for `driver_only`** — the acceptance-test table, answer by
answer, including the D4 latency-pair demonstration through the `ToolCallEnvelope` deadline seam
and D11's corpus minimums. Only after every row holds does any target adopt the "DST"/"simulation"
name (D10). Until then, all new targets keep non-simulation working names.

**WI-C5. The second profile: `compose`-bearing.** Routes the eight `motoko-ext-compose` clock
reads through `ExtPorts.clock_now` (first exercise of a seam with zero call sites today — budget
for it not surviving contact unchanged), claims the 12-site routed set, and expands hook coverage
within what the declared-row rule permits (the three rowless slots) until B2's successor-detector
or row-narrowing work widens it.

## Deferred artifacts: build step and acceptance evidence

The four artifacts the handoff requires scheduled, none of which blocks the ADR and all of which
block the name:

| Artifact | Built in | Acceptance evidence |
|---|---|---|
| Classifier 2 | WI-A4 | Gate-table criterion: fails closed on unresolved occurrences; two known call sites at HEAD; repin re-derivation wired in (WI-B4) |
| Site-to-hook attribution table | WI-A5 | Gate-table + D4 clause 3: schema/staleness/referential validation fail closed; named reviewer per row as the stated exception; empty-intersection semantics tested |
| Coverage-floor validation | WI-A6 | Gate-table (simplified): unconditional floor + disclosure, both enforced at load; fixture rejections demonstrated |
| D3 fault catalogue / D6 event vocabulary | WI-A7 / WI-A8 | Their own decisions' fail-closed contracts; scheduling prohibitions honoured by A14's split dependency |

## Milestone boundaries, and what each unblocks

- **Milestone A** ends with: F6 fixed and regression-locked; the routing audit citable (both
  classifiers built and verified); `driver_only` defined, loading, and truthfully claiming a
  4-site routed clock set; discovery/replay running against the real driver with invariants and
  corpus reporting. Everything except streaming parity and extension model coverage.
- **Milestone B** (external trigger) unblocks: recorded-stream adoption, the extension model path
  (world-token ABI), and coverage growth beyond the three rowless slots. It is the only milestone
  with third-party latency, and per upstream's own advice the project does not idle against it.
- **Milestone C** unblocks the name. Its gate is the ADR's acceptance-test table, nothing less.

## Traps carried forward

Verbatim from the handoff, because each has already cost this project time: **PR #103 must not be
merged** (conflicts in six files, reverts `89a1d67`); clear `.ailang` caches before believing type
errors that contradict source; never probe from `/tmp` (`MOD010` auto-relaxes there); the spike
branch is not HEAD state; the `arniwesth/ailang` fork is not the upstream gate — D1 requires a
**release**; the pin is v0.26.0 with a Makefile drift guard.

## Out of scope

- Building the interprocedural attribution-necessity validator (D4 names it as its own future
  obligation; the named-reviewer exception stands until then).
- Physical faults, durability contracts, concurrency (D9/Non-goals; the 007-D1.3 tripwire is in
  A7's artifact).
- Any change to the accepted architecture. Corrections to the ADR discovered during execution are
  filed as normal amendments — not review rounds, and not silent reconciliations.
