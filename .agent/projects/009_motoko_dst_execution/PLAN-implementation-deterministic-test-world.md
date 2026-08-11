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

## Review disposition

Two independent reviews, 2026-08-02: `REVIEW-implementation-plan-execution-safety.md` (10 findings,
*Accept with conditions*) and `REVIEW-implementation-plan-second-verification.md` (14 findings,
*Revise*). Their union is **14 distinct findings; all 14 are accepted and applied here**, and none
reopens D1–D11.

Both reviewers built probes on the pin and both **broke P2's stated ground** — independently, by
different routes — which is recorded in P2 below rather than quietly repaired. One reviewer's probe
also produced a *positive* result that **replaces P1's weaker M1 citation** with build-backed
evidence. Both confirmed, against source: P1's record choice, P4's vacuity, that **WI-A9 does not
need WI-A8** (the author's judgement, upheld), the `32 provider:` figure's honest use, and the
A1 → A2 → A12 spine with no cycles.

The findings cluster in one place, and it is the place the review handoff predicted: **ADR
obligations with no implementation home** — nine of the fourteen. Self-review had found two such
gaps and scheduled them; independent review found nine more. That asymmetry is the argument for
independent review of a completeness claim, and it is why this pass adds a work item (A15) rather
than only editing prose.

## Survey: executed at HEAD, 2026-08-02

The ADR's handoff requires ten re-verifications. All ten were run against HEAD `eabaac8` on the
pinned toolchain before this plan was written, per `re-ground-inherited-anchors-before-building.md`.

One structural fact makes the whole survey strong: **`git diff --stat a0d4edb..HEAD -- src packages
scripts Makefile .github tools` is empty.** Every source measurement the two acceptance reviewers
verified at `a0d4edb` holds at HEAD by construction. The independent re-measurements below all
agree; zero anchor corrections were needed.

| # | Survey item | Measured at HEAD |
|---|---|---|
| 1 | D1 streaming capture & upstream API | No released AILANG through v0.31.0 exports a recorded-stream API. `sunholo-data/ailang#546` is parked on drain semantics only; the `{chunks, outcome}` shape survived two quorum rounds and can be typed against now. Gate not cleared; the fork prototype clears nothing. |
| 2 | `Ports`/`StepProvider` constructions and consumers | `Ports` has 6 fields (`ports.ail:17-24`). All construction funnels through `ports_shape_probe` (`ports.ail:36`); callers: `live_ports` (`stub_step.ail:148`), `scripted_ports_from_steps` (`stub_step.ail:157`), and `scripts/dst/long_qwen_compaction_dst.ail` (3 sites, plus 3 record rebuilds at `:181`, `:252`, `:750`). Post-`89a1d67`, `C2LoopState.provider` is `Ports`-typed (`session.ail:344`), `dispatch_step` takes `Ports` directly with no dead branches (`stub_step.ail:192-200`), and `ported_provider` (`session.ail:695`) returns bare `Ports` from 6 call sites (`:2015`, `:2051`, `:2114`, `:2137`, `:2267`, `:2295`). `StepProvider` survives as the entry-point argument type only. 32 `provider:` occurrences in `session.ail` (loop-state literals plus entry-point signatures) bound the widening's edit surface. |
| 3 | World-state threading feasibility | Spike Q1 confirmed against the real driver (`NOTE-spike-findings-real-driver-vertical.md`); `C2LoopState` (`session.ail:338-357`) is an 18-field record threaded by one loop. |
| 4 | Direct ambient effects reachable in a session | Classifier 1 re-run at HEAD: union 25 modules, 21 imported, 13 effect-bearing, 8 proven effect-free, **0 unresolved**; `make effect_inventory_selftest` → `agree=43 disagree=0`. Clock: **13 `now()` sites** — 4 driver (`session.ail:791,842,1991,2089`), 1 `ext/runtime.ail:190`, 8 `motoko-ext-compose`. `readLine`: 2 sites (`session.ail:1619` approval, `:2196` conversation loop). `std/sem` `SharedMem` read at `rpc.ail:200`. **Nothing routed**; `ExtPorts.clock_now` has **zero call sites** (`grep -rn '\.clock_now('` is empty). |
| 5 | Tool/timeout contracts | `tool_exec` is stringly (`ports.ail:22`). Timeouts ride in requests — `timeout_secs` in `tool_catalog.ail:53` schema and `env_client.ail:31 exec_in` — enforced outside the AILANG driver. No in-profile module observes time; D4's first time-bearing seam (typed `ToolCallEnvelope` + deadline) is a contract to build. |
| 6 | Hooks in the baseline profile | Eight closed ABI slots (`motoko-ext-abi/types.ail:151-165`): three rowless, `on_budget_plan` at `{Env, FS}`, four at the nine-effect row; six dispatched by unconditional fold, only `on_tool_handle` gated. `.ai_step(` call sites: exactly **2** (`compaction_ai.ail:106`, `reject_fixtures.ail:90`). The baseline profile below installs no extensions, so its profile-reachable hook set is empty. |
| 7 | Traced-driver returns | All terminal summaries route through `emit_run_summary` (`session.ail:833`; call sites `1325` [shared error helper], `1554`, `1704`, `1711`, `1762`), whose only ledger operation is the `ledger_emit` projection. **Zero `RunSummary` in the returned trace on every path** — D6.1's starting count confirmed. `session.ail`: 37 `ledger_emit` vs 15 `ledger_append`. |
| 8 | Event vocabulary & consumers | `LedgerEvent` has **34 variants** (`phase_vocab.ail:597`); `ledger_record_name` (`phase_vocab.ail:561`) names 3 and collapses 31 to `"wire"`; wire names live in trailing comments; the consumer is a TypeScript `switch` in another process. Terminal reasons are integer codes through `finish_reason_str(r: int)` (`session.ail:820`) — the helper D6.2 requires replaced. |
| 9 | Seeded families & CI | `make dst` aggregates `compaction_dst conformance phase_c_l1 smoke_parity dst_l2 dst_seeded`; `dst_seeded` runs two seeded **scalar** families under `--caps IO,Env,Rand`. The only workflow is `verify-extensions.yml`. No generated-trajectory axis exists; nothing currently claims the DST name. |
| 10 | Exhaustive matches & configs | `match provider` at `session.ail:696` and `scripted_ports.ail:31` are the only `StepProvider` matches left. 14 checked-in configs, **all 14** installing `compaction_ai`; `compose` only in `.motoko/config/ailang`; `test_dummy` in none; `motoko_ext_conformance` absent from `registry_generated.ail`. Latent under-declarations confirmed present: `agents_md.ail:106 walk_agents` performs `FS` rowless; `a2a.ail:131` calls `uuid4()` under a row without `Rand`. |

Executable checks run for this survey: `make effect_inventory` and `effect_inventory_selftest`
(clean, above), and `scripts/dst/spike_scripted_cursor_probe.ail` against HEAD (renamed to
`scripted_cursor_probe.ail` when WI-A2 promoted it) — **F6 reproduces
exactly**: `folding: served=[s0,s1,s2,s2,…] advancing=false`, `FAIL`, `exit(1)`. The probe is the
executable statement of the first defect this plan fixes.

## Decisions this plan owns

The ADR deliberately left these decisions to the plan. They are answered here, once, so no work
item re-litigates them.

**P1. `ProviderState` is a record, not a sum.** Declared in `src/core/ports.ail` as a record whose
first field is the scripted cursor (the remaining-script tail, the threading style
`scripted_model_next` already demonstrates). **Ground: build-backed, not analogy.** A reviewer's
three-module probe on the pin widened a `ProviderState` already used in a cross-module port
signature and the port module came out **byte-identical** — the compiler flagged only the
construction site, which is the additive-edit shape this decision wants. (An earlier revision
grounded P1 on M1 instead. That citation over-claimed: M1's 7 judgement sites were about *type
identity*, `Msg` versus `Message`, and it never measured the sum alternative. The probe is the
stronger evidence and replaces it.) The live/`Ported` value is the record with an empty script;
live adapters return their input unchanged (D1's specified identity transition).

**P2. The approval and clock cursors do not ride along in the interim widening.** The decision
stands; **its ground is no-interim-consumer, not structural closure**, and an earlier revision
claimed the latter wrongly.

*Why the decision stands:* neither cursor has an interim consumer. The scripted adapter's
`approval_read` is a constant deny (`deny_approval`, `ports.ail:26-28`, wired at `:42`) with no
position to thread, and the virtual clock only exists once `world_state` lands — which subsumes and
deletes the interim field anyway (D1). Dead rider state threaded through every construction site
would be cost without a customer.

*What is not true:* that P1 closes the ADR's bidirectional-widening risk. **The structural closure
covers only cursors consumed at `model_step`**, the one port gaining a state parameter.
`approval_read` and `clock_now` have no state parameter at all (`ports.ail:19-20`), so adding a
field to `ProviderState` does not make either reachable. Two independent reviewer probes on the pin
established this: assigning a state-threaded adapter to HEAD-shaped `approval_read` fails to unify
(`function arity mismatch: 2 vs 1`), and the only shape that compiles without changing the port is
a **closure-captured cursor — which runs, freezes, and reproduces F6's exact signature on a second
port** (`served=[allow, allow, allow]`, advancing=false). That is the arrangement D1 prohibits by
name.

*The residual, stated rather than hidden:* a pre-`world_state` need for a non-constant approval or
a clock value read from interim state forces a **second bidirectional port widening**, of
`approval_read` or `clock_now`. **Trigger to reopen this decision:** any such need arising before
WI-A12. `ScriptedPortsState` (`scripted_ports.ail:20-24`) already models all three cursors and is
the design precedent if it does.

**P3. Clock routing order, and the first routed-set claimant.** Order: (1) the four driver sites,
routed to the world clock as part of WI-A12 — every profile needs them; (2) `ext/runtime.ail:190`
is never routed — it is *attributed* to `test_dummy` in the WI-A5 table, which is what removes it
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
clock set of the four driver sites. The waiver list is settled at definition time against A7's full
table — the extension-effect class is waived by construction, and the approval-deadline class is
waived only if the profile's policy leaves its enabling condition off; either way each waived class
is named with its condition. It is the documented baseline profile for the Milestone C
name-adoption run. No shipped configuration can be the first profile: all fourteen install
`compaction_ai`, which calls `ai_step` and must be **omitted**, not installed-and-excluded (D1/D5).
A `compose`-bearing profile is the planned second claimant, in Milestone C.

**P5. The `stub_step.ail:170-173` stale comment** ("Returns both the step result and the updated
provider… thread next_provider") describes the pre-`89a1d67` contract and is deleted in WI-A2,
which rewrites that region anyway. The ADR's anchors into `stub_step.ail` are re-grounded in the
same change, filed as a normal amendment — not a review round.

**P6. `Ports.hooks_runtime` is removed.** *(Executed 2026-08-02, `4ad2c7a`, with cluster 1. It has
no work-item row, so the cluster map must name it — see C3 in
`NOTE-cluster-1-execution-report-and-plan-corrections.md`.)* D1 requires the plan to give it a demonstrated production
purpose or remove it. The survey found zero calls of the field repo-wide — only constructions. It
is deleted in the same edit wave as WI-A1 (both touch every construction site; separate commit).

## Work items

**How these are cut into executable sessions is recorded separately, in
`NOTE-execution-clustering-and-handoff-generation.md`** — the cluster map, what can run in parallel,
and how to generate the next handoff. Read it before writing one; it is derived from this plan's
dependency graph, so if the two disagree, this plan wins.

Milestone A is upstream-independent and starts now. Milestone B is **triggered**, not queued: it
begins the day a released AILANG ships the recorded-stream API, and interleaves with whatever A-item
is in flight. Milestone C depends on B.

**Sizing model, corrected by measurement at cluster 1** (`NOTE-cluster-1-execution-report-and-plan-corrections.md`):

- **Size by *sites touched*, not files and not days. This is the plan's sizing rule** — two
  independent confirmations (clusters 1 and 4), not a single observation. A1, A2 and A16 were
  estimated in days and measured in minutes, wrong by roughly two orders of magnitude and always in
  the same direction, because all three scaled M1 by *file* count. Site-scaling predicts both runs:
  cluster 1's 48 sites → ~10 min predicted against ~18 spent editing; cluster 4's 37 sites → ~13 min
  predicted for A9 against ~14 actual.
- **Size against the right population, which is not always the obvious one.** A9's five
  `emit_run_summary` call sites were the visible number; the load-bearing counts were **seven
  terminal returns and eight reachable termination reasons**. Sizing against the helper's callers
  would have missed two terminal paths outright (C2). **For an item that rewrites a *class* of
  things, count the class, not the helper.**
- **The judgement ratio scales with how much contract an item touches:** M1's additive band 10%,
  port widenings **~19%** (A1 3/13, A2 6/35), items rewriting a class of returns or a result
  contract **~27%** (A16 3/11, A9 7/26). Use 27% for A10, A13 and B2.
- **This does not generalise to new-artifact work.** A7, A8, A10, A13, A14, A15 and B2 build things
  that do not exist; nothing here measures those and their estimates stand unrevised.
- The 14-minute discipline held for the reason M1 gave: **tooling first.** Cluster 1 wrote a
  parallel `ailang check` over the affected import closure (22 modules, 12 s) that surfaces one
  error per module instead of one per compile. Without it, convergence costs one round-trip per
  site. Budget the tool before the edits, every time.

### Milestone A — pre-repin (pinned v0.26.0)

**WI-A1. Widen `Ports.model_step`'s result with the emission log** (ADR handoff item 1; D1's
loss-channel rule). Behaviour-preserving: `emissions: []` at every construction site. Edit surface:
the `ports.ail` type, `ports_shape_probe`, 2 `stub_step.ail` adapters, 3 `long_qwen` sites, and the
3 result consumers (`dispatch_step`, `ext_ai_step`, `long_qwen:744`).
*Size:* ~~estimate by analogy — half a day~~ → **MEASURED: ~5.5 min, 6 files** (`e59acaa`,
2026-08-02). The estimate was wrong by ~2 orders of magnitude and the edit surface named 4 files, not
6 — it missed `fake_model`/`fake_ports` in `scripted_ports.ail`, a construction site reached through
`ports_shape_probe`. See `NOTE-cluster-1-execution-report-and-plan-corrections.md` (C1); size
remaining widenings by **sites touched**, not files or days.
*Acceptance evidence:* `make check_core` green; `make dst` targets pass unchanged; a
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
`provider:` occurrences bound the edit surface), `agent_loop_v2.ail`, import sites of
`ScriptedStep`, DST scripts.
*Size:* ~~estimate by analogy — 1–2 days~~ → **MEASURED: ~10 min, 9 files, 35 sites of which 6
needed judgement** (`6dd1bbe`, 2026-08-02). Tooling first, as specified, and that is why it held.
The "judgement band dominates" call was right: 17% here against M1's 10%. **Two of the six are sites
where both alternatives type-check and the wrong one silently reproduces F6** — see
`NOTE-cluster-1-execution-report-and-plan-corrections.md`, which WI-A12 must read before threading
`world_state` through the same successor literals.
*Acceptance evidence:* the F6 probe prints PASS and exits 0, and is promoted out of spike naming
into the `make dst` aggregate as a permanent regression test — landed as
`scripts/dst/scripted_cursor_probe.ail`, wired at `Makefile:86`;
`phase_c2_wiring_scenarios` at its full count (**19** once WI-A1 adds its emission-log scenario to that harness — an earlier revision said 18/18, which A1 necessarily moves); `check_core` green; `grep` finds no `assistant_count`-derived
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
target and selftest.
*Size:* **estimate by analogy — an afternoon.** Basis: classifier 1, like for like.
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
`(source revision, content hash)` identity is what profiles reference. **Producer-side completeness
is evidence too, and row-shape checks do not supply it:** a fixture in which a
classifier-discovered core effect site appears in neither the attribution rows nor the explicit
unconditional-core set must be **rejected at profile load**. Without it a syntactically valid table
that silently omits a discovered site passes every other check — the fail-open D4 clause 3 exists
to close. **Scheduling prohibition honoured:** every routing-completeness claim in this plan
(A12's, C5's) names this item as a dependency.

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
**A branch discrimination that can silently break belongs here too, and this item owns deciding it**
(cluster 4, C4). `decision_fail_reason` (`session.ail:1357`) separates max-steps from internal
failure by matching the literal message `"v2 loop: step budget exhausted"`, because
`step_machine.ail:93` and `:57` emit **the same `Internal` code** for the step-budget failure and
the approval-without-pending-call failure. Behaviour is exact today, but editing that string
silently reclassifies every max-steps run. Giving the step-budget `Fail` its own code fixes it and
**changes the `AIError` code callers see — a compatibility decision, which is why A9 did not take
it.** D3's catalogue names a recovery-branch id per class, so this is the decision's natural home:
decide it here, with the wire-compatibility consequence stated.

**One uncovered case cluster 1 surfaced belongs in this catalogue.** After A2, an extension-issued
`ai_step` against a `Scripted` provider is handed a fresh empty `ProviderState` and serves
`terminal_step()`, per D1's exclusion of the extension model path. **No test in the tree changed its
output**, which means nothing covers "an extension calls `ai_step` against a `Scripted` provider" —
and that is the concrete reason D1's rule (a conformant interim profile must exclude *every* hook an
`ai_step`-calling extension registers) currently has no instrument behind it.
*Acceptance evidence:* validator fails closed on a class row missing any field or naming an unknown
constructor; **and on a catalogue missing any required D3 class id** — set completeness, not only
row shape, because every downstream counter reads its ids from this artifact and therefore cannot
discover a class the artifact omits. An empty catalogue must fail. The two conditional classes
carry their waiving conditions; D11's class-reached and branch-reached counters read their ids from
it (exercised in WI-A14).

**WI-A8. Construct D6's event vocabulary** — the fifth recorded axis. New construction for all 34
`LedgerEvent` variants: variant, wire name, payload schema, logical/display-only classification;
fail-closed on an unclassified variant. `ledger_record_name` is not a seed and is not grown.

**The schema is `wire name = f(variant, payload)`, not `f(variant)`, and that is settled here rather
than discovered inside the item.** One variant of the 34 is payload-dependent: `StreamDelta`
projects to `reasoning_delta` or `thinking_delta` selected from `i.kind`
(`phase_vocab.ail:713`), both pinned by goldens (`:1139-1140`) and both recorded in the variant's
own trailing comment (`:631`). A one-name-per-variant artifact cannot represent it, so the
derive-from-the-type form is available only with a total projection function or an allowed-name
set — pick one in this item. It remains the preferred direction for the other 33, where drift stays
a compile error.
*Acceptance evidence:* load validation fails closed on a synthetic unclassified variant; **every one
of the 34 variants, and both `StreamDelta` branches, round-trip to the wire name the current
projection produces** — the existing goldens make this cheap and it is what would have caught the
schema error; the vocabulary version lands in the execution manifest (WI-A10) and failure record.
**Scheduling prohibition honoured:** no D7 parity invariant or acceptance row depending on the
classification is scheduled before this item completes — WI-A14's invariant set is explicitly split
on it.

**WI-A9. Route every terminal path through one finalizer, type the termination reason, and build
D6's two result classes** (D6.1, D6.2, D6.6, D6.7). The spike proved `c2_finalize` (append **and**
emit) tractable without restructuring the driver; the starting count is zero everywhere. Replace
`finish_reason_str(r: int)` with a typed termination reason derived from the reachable terminal
returns, mapped exhaustively to wire `finish_reason`. **Also builds the result contract itself,
which an earlier revision left homeless:** the disjoint `SystemRun` / `HarnessFailure` shapes with
their D6-fixed fields — outcome, ledger trace, interaction log, replay metadata; and kind,
interaction position, actual request projection, partial ledger trace, replay metadata — plus
setup-failure-before-the-world-is-established as a typed `HarnessFailure` rather than a successful
empty trace.
*Size:* **MEASURED: ~14 min, 6 files (2 new), 26 sites of which 7 needed judgement** (`ff8d8e5`,
2026-08-02). Previously unsized.
*Acceptance evidence:* a trace-level test asserts exactly one `RunSummary` as the final record on
every enumerated terminal path; returned outcome, `DoneEvent`, and `RunSummary` agree; no integer
code survives at a terminal call site; a setup failure returns a typed `HarnessFailure` carrying its
partial evidence, and a raw capability bypass remains a non-zero run rather than a typed value —
D6.6 requires the two be distinguishable and they are tested as distinct. Landed as
`make terminal_trace`, invoked by CI.

**The terminal-path enumeration this item inherited was wrong in three ways, all found by building
it** (`NOTE-cluster-4-execution-report-and-plan-corrections.md`, C2/C3; ADR amended 2026-08-02):
**seven terminal returns, not five `emit_run_summary` call sites** — invalid history and the
internal approval failure emitted nothing at all, not even a projection, and an implementer working
from the five would have left both unfinalized. Among the reasons, **`dp7_rejected` is unreachable**
(no call site ever passed it; a DP7 rejection re-injects and terminates later), **unrecovered tool
failure is not a terminal path** at all (tool results feed back as messages), and
**system-prompt-empty is reachable and was missing**. An earlier revision of this line listed "tool
failure" among the paths to assert. Eight reachable reasons, all mapping onto the existing wire
strings, so no wire change was required.

**WI-A10. Build the profile definition and execution-manifest machinery, and define `driver_only`
v1** (D5; P4). Depends on A4, A5, A6, A7, A8: the definition references the attribution table,
names its waived fault classes by A7's stable class ids, and records the vocabulary version; load
validation wires in the floor/disclosure checks and both classifier outputs. **Also installs
runtime routing's fail-closed exclusion check** — dispatch reaching an excluded hook returns an
in-runner `HarnessFailure` (D5, D6.6), using A9's result types. Load-time rejection and A12's
capability probes do not implement this path; it is vacuous for `driver_only` and binding from C5
onward, and leaving it unbuilt would surface as a missing acceptance row at the gate.

**The profile *definition* has its own field list, distinct from the manifest's, and an earlier
revision enumerated only the manifest.** The definition records all ten D5 fields — id/version;
included extensions with per-hook classifications; **included and excluded provider/tool adapter and
parser boundaries**; **logical resource models**; **permitted diagnostic projections**; **forbidden
ambient effects/capabilities during execution**; waived D3 classes with conditions; the attribution
table reference; per-extension covered/excluded hook **ids**; and **omitted extensions with their
reason**. Four of those are *not* vacuous for an empty install list: the adapter/parser boundary
scopes D3's wire-parser exclusion, the diagnostic projections bound D1's collecting sink, the
forbidden-capability set is what A12's poison probes test against, and `driver_only` must name the
`compaction_ai` omission and its reason even though it installs nothing.
*Acceptance evidence:* `driver_only` loads clean and names its omission; a fixture profile
installing `compaction_ai` is rejected **at definition time** with the classifier-2 reason; **a
fixture definition missing any one required field is rejected at load, naming the field** — "loads
clean" alone cannot falsify a field the validator was never told to require; a fixture installing a
package whose AILANG source lies outside the recorded scan roots either extends the roots through
the resolved lock graph or **fails validation closed** (D5; the live shape is `ailang.toml:9`'s
registry-resolved `sunholo/logging`, exposure nil today); the manifest separately records D5's full
manifest list — source revision, toolchain, extension package and ABI versions, profile
id/version, event-vocabulary version, normalized configuration — plus both derived classifier sets
and the scan-root commit.

**WI-A11. The predicate documentation check** the ADR assigns to this plan. **It is an anchor-set
drift check, not a containment check, and that choice is forced rather than preferred:** the ADR
records that its six normative sites are "substantively aligned, **not word-identical** — the six
use six formulations" (`ADR:462-465`). A check requiring one canonical sentence to appear at all six
is therefore **red on the unmutated ADR at HEAD**, and the alternative — canonicalising the six —
is six ADR amendments this plan does not budget. Build instead: the six anchors named by location,
each with a content hash and a named reviewer who accepted that its formulation states the
predicate; the check fails when an anchor's text changes without a re-accepted hash, or when a
normative statement of the predicate appears outside the six. A small script with a `make` target,
CI-run.
*Acceptance evidence:* **the check is green on the unmutated ADR at HEAD** — the falsifiable half,
and the one a containment check would fail; *and* mutating one anchor in a scratch copy turns it
red. Both, because the second alone passes trivially while the first is broken.

**WI-A12. Thread `world_state` through the driver, one effect class at a time** (D1). Depends on
A2; subsumes and deletes the interim `C2LoopState` cursor field in its first change, per D1.
Order within the item: provider (subsumption of A2's field), then the four driver clock sites
routed to the world clock (P3), then approval, then env reads, then runtime randomness; the typed
tool contract replaces stringly `tool_exec` in the same wave — it is D4's named first time-bearing
seam and D1 requires it anyway. **That contract is all three of D1's parts, not one:** a typed
`ToolCallEnvelope`, timeout/deadline information, **and a typed result/error** replacing
`tool_exec(string, string) -> string` (`ADR:606-609`; HEAD shape at `ports.ail:22`). An earlier
revision named only the envelope and deadline, under which a request-only widening would pass the
listed probes while leaving the return an undifferentiated string — weaker than D1 requires and
unable to carry D3's typed tool fault classes. Behaviour-preserving throughout: live adapters
delegate to today's code paths; `emissions`/state plumbing verified against `Scripted` providers.
Spike Q1 confirmed the threading and Q2 confirmed routing tractability (its count clause falsified
and superseded by the 13-site inventory); the spike's surgery is *not* imported — this is fresh
work at HEAD. **Also deletes `ported_provider`'s now-dead `history` parameter** (`_history` at
`session.ail`, six call sites): it existed only to compute the `base_assistant_count` that A2
retired, and D1 keeps the seam stable until `world_state` replaces it — which is this item (C5).

**The silent-freeze hazard is this item's defining risk, and cluster 1 measured it rather than
predicting it.** A2 threaded thirteen `C2LoopState` successor literals. The compiler forces the new
field to be *present* at all thirteen but accepts `st.provider_state` at every one — while six are
downstream of the dispatch call and must carry the successor. Cluster 1 verified the failure
empirically: flipping all six to the carry-forward form type-checks clean (`✓ No errors found!`) and
serves `[s0,s0,s0,…]` in **both** scenarios — a total freeze, worse than F6 itself. Only
`scripted_cursor_probe` catches it. **A12 threads more cursors through the same literals, at a
larger site count, for values with no equivalent instrument.**
*Therefore, binding:* **land an executable advancement assertion for each cursor before threading
it.** Not after. A cursor threaded without one is indistinguishable from a cursor frozen, in a tree
where every type-check passes.

**Cluster 4 sharpened this and the strengthening is not optional.** A9 found *four* silent-wrong
sites, and their shape is worse than cluster 1's: cluster 1's were successor literals where the
wrong value froze a cursor; A9's are **trace arguments where the wrong value yields a trace that
still passes its own invariant** — handing the finalizer `st.trace` instead of the trace carrying
the decision record silently drops the evidence the failure is about, while the one-`RunSummary`
assertion stays green. A12 now threads `world_state` through those same literals *and* through a
finalizer taking a trace argument. **The advancement assertion must therefore cover trace
completeness, not only cursor advancement**, or a dropped record satisfies every check A9 leaves
behind.
*Size:* **estimate — several days**, staged as one PR per effect class. Basis: the spike threaded
world state and routed the clock on a throwaway branch; this repeats that behaviour-preservingly
across six effect classes plus the typed tool contract. Per the corrected model, re-size against
sites once the per-class site counts are known — A2's 35 sites for one cursor is the anchor, and
the advancement assertions are new work the spike never did.
*Acceptance evidence per class:* existing targets green; the class's poison probe (capability
withheld) passes for the deterministic entry point and fails for the live world — the F3-corrected
per-run backstop; for the tool class, the typed contract carries ordinary success, typed
execution/non-zero error, wrong-call-id correlation, and completion-after-deadline through one
production adapter contract; after the clock class, `driver_only`'s routed-set claim (4 sites)
becomes true and is recorded in the profile — a claim that additionally depends on A5, per D4's
scheduling prohibition.

**WI-A13. Build discovery and replay** (D2, D8). Depends on A7 (class ids), A9 (result types), A10
(manifest), A12 (world_state). `ExecutionProgram`/`DiscoveryConfig` types, the seeded generator
with declared bounds, the pure structural validator, strict and regression replay modes, the
interaction log with causal identities and encounter ordinals. Exact type names are plan-level per
D2; semantics are fixed there and not re-litigated here. **Three D8 obligations ride here that an
earlier revision left homeless** — all normative, none deferrable the way shrinking is: **(1)
persistence safety** — programs carry synthetic values only, and environment maps and interaction
artifacts reject or redact secret-shaped/live credentials *before* persistence; **(2) the encoding
and compatibility policy** — a deterministic, diffable encoding (its selection is delegated to this
plan by the ADR's Non-goals) whose schema migrations either preserve old-program decoding or pin a
runner, never silently reinterpret; D6 binds the event vocabulary to the same rule, so it is
load-bearing twice.
*Acceptance evidence:* D7's discovery-contract invariant — same manifest/profile/seed twice →
identical resolved program, interaction log, outcome, normalized trace; a mismatch fixture returns
typed `HarnessFailure` with position and projection; bounds violations fail as generator errors;
D8's pinned generator canary exists per stable generator id and fails on a seed remap without a
generator-version bump; **a secret-shaped fixture is rejected or redacted before persistence**; and
**an old-schema program either decodes or fails closed with a pinned-runner pointer** — never
silently reinterpreted.
*Size:* **estimate — 1–2 weeks**, the largest Milestone A item. Basis: program and config types, a
seeded generator with bounds, a structural validator, two replay modes, the interaction log with
causal identity and ordinals, the canary, and the encoding/compatibility policy — each small, the
set wide, and no measurement covers any of it.

**WI-A14. Implement the D7 invariant set, the D4 latency pair, and D11 run reporting.** Depends on
A9, A13; the parity-classification invariants additionally depend on A8 and are not scheduled
before it. **Includes D4's latency-pair demonstration**, which an earlier revision left in WI-C4:
two replayable programs holding request and underlying completion result constant while changing
only generated latency/clock movement, producing the expected different completion-versus-timeout
result without an OS timeout. It is name-gate evidence but not upstream-dependent work — the
deadline seam (A12), generator and replay (A13) are all Milestone A — so leaving it in C made
Milestone A's boundary claim false. C4 runs the gate; it does not build the evidence.
*Acceptance evidence:* every D7 bullet has a runnable invariant; the latency pair demonstrates the
differing deadline outcome and both programs replay deterministically; a run report carries the
full D11 field list; class-reached vs branch-reached are separate counters read from A7's artifact;
a promoted failure travels as one artifact — exact program **with** its execution manifest — per
D11's promotion rule; **and the failure report carries a copy-pasteable local replay command or a
retained artifact reference** (D8), without which a CI failure is not reproducible by the person
reading it.
*Size:* **estimate — 3–5 days.** Basis: eleven D7 invariant families over an existing trace ADT,
plus the latency pair; each invariant is small but the set is wide, and the parity family cannot
start before A8. No measurement covers this; treat the range as coarse.

**WI-A15. Build D11's two corpora and their CI jobs.** Depends on A13, A14. An earlier revision
scheduled corpus *reporting* in A14 and left the corpora themselves unbuilt, which C4 would then
gate against. Build: the **blocking PR corpus** of fixed seeds and exact promoted regression
programs; the **scheduled rotating corpus** whose seed window changes deterministically; both CI
jobs, which are new construction — survey row 9 records the only workflow at HEAD is
`verify-extensions.yml` with no generated-trajectory axis. Select rotation, retention, and sharding
from measured CI cost here, together with each job's operator-accepted minimum seed count, per
D11's delegation to this plan.
*Acceptance evidence:* both jobs run and declare their minimums; the gate **fails** on a zero,
silently truncated, or below-minimum window (tested by forcing one); the fixed bank collectively
reaches every required non-waived fault class in A7's catalogue; a promoted counterexample enters
the fixed corpus with its manifest attached.
*Size:* **estimate — 2–4 days**, dominated by CI cost measurement rather than code.

**WI-A16. Wire the unrun driver coverage into `make` and CI — do this before A9 and A12.** No
dependencies; it is Makefile and workflow work, and it is sequenced first because it *protects* the
remaining driver items rather than following them. Cluster 1 found a live gap: **eight smoke scripts
that exercise the driver's full loop are in no `make` target and no CI job** —
`scripts/smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,stream_parity,ext_fixture_parity,cost_budget_full_loop,compaction_chain}.ail`
and `smoke_phase_a_tool_parity.ail` — and **`src/core/test/scripted_ports.ail`'s six unit tests are
run by nothing**, since `check_core` covers `src/core/*.ail` only. Verified at HEAD: all nine have
zero references in the Makefile.

This is not hygiene. WI-A2 changed the contract every one of those eight depends on and nothing in
the repo would have run them; cluster 1 ran all eight by hand and all eight passed, but the next
driver change has no such guarantee. `smoke_v2_dp7_gate` is the **only** executable coverage of
`c2_after_dp7`, whose two successor literals A2 had to thread — precisely the code path A12's
silent-freeze hazard threatens.
*Acceptance evidence:* all nine run in a `make` target reachable from CI; the target fails when any
one of them fails (verified by breaking one deliberately); `scripted_ports.ail`'s unit tests are in
a named target.
*Size:* ~~estimate — under a day~~ → **MEASURED: ~9 min, 6 files, 11 sites of which 3 needed
judgement** (`61f38db`, 2026-08-02). Wrong in the same direction and for the same reason as cluster
1's estimates — sized as wiring by file count, when the real site count was 11, not the 2 this item
implied.

**The demonstration clause earned its keep, and that is a finding about how to write acceptance
evidence** (cluster 4, C1). "Verified by breaking one deliberately" could not be satisfied as
written: **four of the eight scripts had no failing exit path at all** —
`smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,cost_budget_full_loop}` printed `✗` on a
failed assertion and exited **0**. Wiring them would have produced a target green regardless of
whether their assertions held. Measured, not inferred: with one assertion inverted, the script
exited 0 before the fix and 1 after. **Prefer acceptance clauses that must be demonstrated over
clauses that can be asserted** — an assertion here would have shipped the illusion of coverage.

**WI-A17. Sweep the second coverage axis: `ailang test`.** No dependencies; small. Cluster 4 found
that `check_core` type-checks `src/core/*.ail` but never *runs* their inline tests, so
`session.ail`'s 21 and `phase_vocab.ail`'s 27 — including the `RunSummary` goldens that hold the
wire strings — were executed by nothing. A16 put those two files in `make terminal_trace`, but the
general defect stands: **`ailang check` coverage and `ailang test` coverage are separate axes and
only the first has a target.** Cluster 1's C6/C7 did not catch it because they looked at
`src/core/test/` rather than `src/core/`. Also fix or retire `scripts/dst/probe_phase_vocab_sealed.ail`,
which fails at baseline (`IMP010: symbol 'MkHistory' not exported`) and stayed broken precisely
because it is in no target.
*Acceptance evidence:* every `.ail` file carrying inline tests is in a target CI invokes, verified
by an inventory that fails when a file with tests is unreferenced — not a hand-maintained list;
breaking one inline test turns CI red.
*Size:* **estimate — under a day**, at 27%: it is an inventory plus wiring, and the inventory is
the part that must not be hand-maintained.

### Milestone B — the repin (trigger: a released AILANG carrying the recorded-stream API)

**The triggered graph is explicit, because milestone order is not a dependency here.** Milestone B
starts whenever the release appears and interleaves with whatever A-item is in flight, so an item
that needs an A-item must say so or it can be started without it. **B1–B3 are one inseparable wave,
not three green states**: the new pin exposes the effect/ABI repairs and the `Message` migration
simultaneously, so B1 alone leaves the tree red. B1 is therefore **preparation-only**, and **WI-B4
is the wave's green integration gate.**

**WI-B1. Repin the toolchain — preparation-only, not independently green.** Update `ailang.toml`,
`scripts/install-prerequisites.sh:39`, and the Makefile guard together; **clear every
`.ailang/cache` in the tree before believing any diagnostic** (the phantom-type-error trap
reproduced across a version change). The two latent under-declarations (`walk_agents` `FS`,
omnigraph `register_with_config` `Process`) become hard errors and are fixed here.
*Size:* **measured, as one wave with B2/B3 — M2's 381 effect-row edits across 71 files**, almost
all mechanical via the compiler-driven repair loop. M2 is *not* allocated between B1 and B2: three
of its edits are the `motoko-ext-abi/types.ail` row corrections that belong to B2, and the rest are
the mechanical repairs here. Treat the 381 as the wave's total, not B1's.

**WI-B2. The extension-ABI major.** Depends on B1 (the pin that forces it) and **A12** — its larger
half threads the world token, and `world_state` is built there; if the trigger fires before A12,
the row corrections can proceed and the world-token widening cannot. One coordinated major,
containing both ADR-named parts: the
three `motoko-ext-abi/types.ail` row corrections (`ExtPorts.ai_step` gains `Trace`; the four
`ExtensionHooks` rows gain `Rand` and `Trace`) **and the world-token widening of `ExtPorts.ai_step`
plus the hook results and core dispatch results — the larger of the two** (Consequences). Lockstep
re-release of every extension package. This is what lifts D1's extension-model-path exclusion;
until it lands, an `ai_step`-calling extension is omitted from any conformant install list. Per D5,
the same major is where coverage can widen beyond the three rowless slots — either per-hook row
narrowing or the declared-versus-performed successor detector, both of which D5 assigns to this
major; WI-C5 depends on that part landing.
*Size:* **estimate — 1–2 weeks**, and it is the largest single item in the plan. Basis: the ADR
calls the world-token widening "the larger of the two" changes in this major, it touches
`ExtPorts.ai_step`, the hook results and core dispatch results together, and it forces a lockstep
re-release of **every** extension package. No measurement covers it; the mechanical row edits are
inside M2's 381, the widening is not.

**WI-B3. The `Message` migration** (vision/images field of the new pin). Depends on B1.
*Size:* **M1, measured — 14 minutes, 28 files, 69 additive sites, 7 judgement sites** — with its
two riders honoured: tooling first (the brace-balanced rewriter and fix loop are what made 14
minutes true), and the settled decision that Motoko's `Msg` and the ext-ABI `Msg` stay at four
fields, vision parts dropped at the seam.

**WI-B4. Re-derive both classifiers on the new pin, and close the repin wave.** Depends on B1, B2,
B3 (the source and ABI set is not final until they land), **A4** (classifier 2 must exist to be
re-derived) and **A10** (a manifest must exist to re-issue). Re-run `make effect_inventory`,
`effect_inventory_selftest`, and the classifier-2 target; re-record both derived sets and the
scan-root commit; re-issue `driver_only`'s manifest. If the trigger fires before A4/A10, this
degrades to re-running classifier 1 alone and the rest waits — say so rather than letting it pass
silently.
*Acceptance evidence:* **this is the wave's green gate** — full compile and test suites pass on the
new pin, both classifiers report zero unresolved, and the re-issued manifest names the new
toolchain and ABI versions.

### Milestone C — post-upstream

**WI-C1. Adopt the recorded-stream API in the one `live_ports` closure.** Depends on **A1** (the
widened loss channel is what makes adoption observable — adopting first would carry an empty
emission log, D1's named trap) and **B4** (the integrated repin, not the bare B1). The blast radius
A1 bought: one closure.

**WI-C2. The direct positive integration probe** (D1's gate). Depends on C1 — it is the positive
proof of C1's adoption. Immediate projection, exact returned-log parity, success,
partial-stream-then-error, no duplicate delivery. Its passing is the substrate-gate evidence D1
requires; the forbidden delayed-projection fallback must not be selected silently.

**WI-C3. The streaming-trace parity invariant** (D6.4's named exception, checked explicitly).
Depends on C2 and A8.

**WI-C4. Run the name-adoption gate for `driver_only`** — depends on C2, C3, and all of
Milestone A. The acceptance-test table, answer by answer. **This item runs the gate; it builds no
evidence.** Every row's evidence is produced earlier — the latency pair in A14, corpus minimums in
A15, routing audit in A4/A5, hermeticity probes in A12, trace contract in A9 — and a row with no
earlier producer is a planning defect to fix here rather than an experiment to run at the gate. Only after every row holds does any target adopt the "DST"/"simulation"
name (D10). Until then, all new targets keep non-simulation working names.

**WI-C5. The second profile: `compose`-bearing.** Depends on **B2, A5, A10 and A12** — B2 for the
coverage widening, A5 because its routed-set claim is a routing-completeness claim gated on the
attribution table, A10 for the profile machinery it instantiates, A12 for the world clock its
extension reads route *into*. An earlier revision named only B2; milestone order does not supply
the rest, because B interleaves with A and C5 carries no all-of-A guard the way C4 does. The
dependency on B2 is not just the clock: `compose` puts real behaviour in an
unconditionally-dispatched nine-effect hook
(`on_response_intercept`, bound at `compose.ail:840`, body at `:761-790`), which under the
declared-row rule cannot be covered and — being unconditionally dispatched — cannot be excluded
either, so `compose` is un-installable in a conformant profile until B2's world-token/coverage
widening lands. (Its `on_tool_handle` is the one *gated* hook and could be excluded; that does not
rescue the install.) The work:
route the eight `motoko-ext-compose` clock reads through `ExtPorts.clock_now` (first exercise of a
seam with zero call sites today — budget for it not surviving contact unchanged), make the
effectful hooks world-mediated, and claim the routed set — **12 sites post-table; 13 is the
fail-closed figure if the attribution table is absent or invalid** (D4's 4/12/13 versus 5/13/13
split). The dispatch-time exclusion check A10 installs becomes binding here, and its in-runner
probe — reaching an excluded hook returns a typed `HarnessFailure` with partial evidence — is part
of this item's acceptance rather than assumed from load-time validation.

## Deferred artifacts: build step and acceptance evidence

The four artifacts the handoff requires scheduled, none of which blocks the ADR and all of which
block the name:

| Artifact | Built in | Acceptance evidence |
|---|---|---|
| Classifier 2 | WI-A4 | Gate-table criterion: fails closed on unresolved occurrences; two known call sites at HEAD; repin re-derivation wired in (WI-B4) |
| Site-to-hook attribution table | WI-A5 | Gate-table + D4 clause 3: schema/staleness/referential validation fail closed; **plus producer-side completeness — a classifier-discovered site in neither the rows nor the unconditional-core set is rejected at load**; named reviewer per row as the stated exception; empty-intersection semantics tested |
| Coverage-floor validation | WI-A6 | Gate-table (simplified): unconditional floor + disclosure, both enforced at load; fixture rejections demonstrated |
| D3 fault catalogue / D6 event vocabulary | WI-A7 / WI-A8 | Their own decisions' fail-closed contracts, **including set completeness** — A7 rejects a catalogue missing a required class, A8 round-trips all 34 variants and both `StreamDelta` branches; D6's scheduling prohibition honoured by A14's split dependency, D4's by A12's and C5's claim clauses |

## Milestone boundaries, and what each unblocks

- **Milestone A** ends with: F6 fixed and regression-locked; the routing audit citable (both
  classifiers built and verified); `driver_only` defined, loading, and truthfully claiming a
  4-site routed clock set; discovery/replay running against the real driver; the D7 invariants and
  the D4 latency pair; both D11 corpora and their CI jobs. **Everything the name gate needs except
  streaming parity and extension-model coverage** — and that claim is now true, where an earlier
  revision's was not: it left the latency pair in C4 and the corpora unbuilt while claiming the
  same boundary.
- **Milestone B** (external trigger) unblocks: recorded-stream adoption, the extension model path
  (world-token ABI), and coverage growth beyond the three rowless slots. It is the only milestone
  with third-party latency, and per upstream's own advice the project does not idle against it.
- **Milestone C** unblocks the name. Its gate is the ADR's acceptance-test table, nothing less —
  and C4 only *runs* that table, since every row's evidence is produced in A or B.

## Traps carried forward

Verbatim from the handoff, because each has already cost this project time: **PR #103 must not be
merged** (conflicts in six files, reverts `89a1d67`); clear `.ailang` caches before believing type
errors that contradict source; never probe from `/tmp` (`MOD010` auto-relaxes there); the spike
branch is not HEAD state; the `arniwesth/ailang` fork is not the upstream gate — D1 requires a
**release**; the pin is v0.26.0 with a Makefile drift guard.

## Out of scope

- Building the interprocedural attribution-necessity validator (D4 names it as its own future
  obligation; the named-reviewer exception stands until then).
- **Shrinking, explicitly deferred past the first name-adoption gate** — recorded here because D8
  permits that deferral only if the project records it. Replay of the unshrunk failing program is
  not optional and is in WI-A13.
- Physical faults, durability contracts, concurrency (D9/Non-goals; the 007-D1.3 tripwire is in
  A7's artifact).
- Any change to the accepted architecture. Corrections to the ADR discovered during execution are
  filed as normal amendments — not review rounds, and not silent reconciliations.
