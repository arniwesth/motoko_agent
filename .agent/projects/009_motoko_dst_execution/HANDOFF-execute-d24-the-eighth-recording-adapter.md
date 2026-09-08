# Handoff: WI-D24 — the eighth recording adapter, and the `ext_id` that reaches it

Audience: a fresh session grounded against HEAD. **Item 2 of the goal line's critical path** (the
plan's "The goal line" section): after this item, routing compose's `exec` sites has no remaining
blocker. D21 §5 took the identity-class decision and named this work; D23 finished the typed surface
and exported the bridge. **This item makes an extension-initiated dispatch record as a VALID
interaction and replay as a SERVED one.**

**Read first:** `NOTE-d21-…` §4 and §5 (the decision and the two closable gaps), then the goal-line
section's scope rule: a finding joins the queue only if it blocks the demonstration or the
disclosure table.

## What D21 established and D23 left standing — re-measured, not inherited

- The bridge dispatch records `ToolIdentity("loop_v2", "", tool)` (`ports.ail:1626`), and a blank
  tool call id is a **rejected program** — asserted at `dst_program.ail:697`.
- The right class is **`ExtensionEffectIdentity(ext_id, class_id, call_id)`**
  (`dst_interaction.ail:63`): the only class whose blank call id is legitimate, and the only class
  whose origin projection names the extension rather than the driver's loop (`:161`).
- **The `class_id` is already written**: `extension_effect_fault` is catalogue row 11, in
  `required_class_ids()`, and `dst_program.ail:724`'s test constructs
  `ExtensionEffectIdentity("compose", "extension_effect_fault", "")` and asserts **zero
  rejections**. The seam lacks exactly one component: the `ext_id`.
- All seven `record_interaction` construction sites are in `ports.ail`
  (`:1434/:1459/:1514/:1540/:1576/:1603/:1639` — re-derived at this writing); none constructs the
  class.

## Three findings this handoff adds, all measured at HEAD

**1. No schema work is needed, at all.** The persistence codec already encodes and decodes the
class (`dst_persistence.ail:459`, `:896-897` — `expect_extension_effect`), and D22's freeze put
**all 10 identity classes in frozen v2 bytes** (its gate says so in its own words). Recording the
class is a producer change against a surface that is already complete. Do not touch
`program_schema_version`.

**2. Replay must be taught to SERVE the class, and the tripwire for forgetting is already armed.**
`tools_of` (`dst_replay.ail:710`) collects **only `ToolIdentity`** interactions into the world's
tool queue. Record the bridge dispatch under the new class without touching reconstitution and a
replay under-seeds the queue: the extension's call hits `world_tool`'s `[]` arm and performs a
**real dispatch inside a deterministic run** (or dies on a withheld `Process` capability), and the
recorded interaction goes unconsumed — which `UnusedInteraction` grades **FATAL**
(`dst_replay.ail:199`: *"the one most easily forgotten, because NOTHING FAILS"*). So the failure is
loud one level out, but only after a real subprocess ran inside a replay. **Recording and serving
are one decision** (S27); this item owns both halves.

**3. The interleaving hazard if the class shares the driver's tool queue.** `world_tool`'s
correlation guard fires only when **both** ids are non-blank (`ports.ail`, scripted arm:
`t.tool_call_id != "" && t.tool_call_id != inv.call.id`). An extension-effect entry reconstituted
with a blank id into the SHARED queue can be consumed by a **driver** tool call with no mismatch —
present-but-wrong reading as correct, S26's shape in the world's supply. Either serve the class
from its **own queue** behind its own adapter, or state precisely why the shared queue cannot
misalign (and build the fixture that proves it — interleaved driver-and-extension dispatches, all
quantities distinct per S7).

## The transport problem, with its measured constraints

The `ext_id` exists at the dispatch site and fails to reach the closure (D21 §5.2, still true):

- `ExtensionHooks.id` is on every registry entry, and the fold already stamps `ext_id: h.id` into
  stage labels (`ext/runtime.ail:262` et al.).
- `mk_v2_ext_ctx` builds **one** ctx per step at **four** sites (`session.ail:2394/:2438/:2521/:2664`),
  each passing one shared `ext_ports_of(...)` result — the closure is captured before any hook is
  chosen.
- **`session.ail:52` imports `ext/runtime`, so the fold cannot call back into `ext_ports_of`**
  without a cycle. Per-extension ports cannot be built inside `runtime`; they must be built in
  `session` (or threaded in as data).
- `proc_exec`'s ABI signature is fixed: `(ExtWorld, string, string)`. No identity parameter can be
  added without the `6.0` this project has twice deferred.
- `ToolInvocation` is `{ call, workdir, timeout_ms, started_at_ms }` (`ports.ail:487`), in-memory
  only — never persisted, so widening it is a core edit with a construction-site census, not a
  schema event.

Two coherent designs, and the choice is the item's:

- **A distinct seam end to end** — a new `Ports` field (the extension-effect dispatch), its own
  recording wrapper (**a true eighth adapter** constructing
  `ExtensionEffectIdentity(ext_id, "extension_effect_fault", "")`), its own world queue and
  scripted/live adapters, with `ext_ports_of` gaining an `ext_id` parameter and the bridge calling
  the new field. Keeps the driver's tool class and the extension's effect class **producer-separate**
  (S16's instinct), and finding 3's hazard never exists.
- **An originator on `ToolInvocation`** — the bridge stamps `originator: ext_id`, drivers stamp
  `""`, and `recording_tool` branches on it. Cheaper; but the "eighth adapter" is then a branch in
  the seventh, the shared-queue hazard (finding 3) must be closed by fixture, and one adapter now
  produces two identity classes — the exact shape S16's C5 extension warns about, so if you take
  this road, say why the shared producer cannot lie here.

Either way, per-extension delivery of the id happens in `session` — whether as per-extension ports
handed to the fold or as a re-seated ctx field — and **the fold's re-seat must not disturb D19's
world re-seating** (S29's read-side warning: the batch ctx and the live world are separate
concerns; both halves are one decision).

## The recording adapter's own discipline

- `deadline_ms`: `class_has_deadline` is **true** for this class (`dst_interaction.ail:304`), and
  the validator rejects a `-1` (`dst_program.ail:399-400`). Record `inv.timeout_ms` exactly as
  `recording_tool` does — the bridge's `0` is a valid deadline; copying a no-deadline class's `-1`
  is a loud rejection, which is the right failure.
- The identity's components must come from the transport, not from constants: an adapter that
  hardcodes `"compose"` passes every fixture built around compose (S33 — the proxy and the truth
  agree on almost every input by construction). The witness scenario below must use an ext id that
  is **not** compose's.

## What flips, what stands, and what gets re-worded

- **The two D21 assertions at `dst_program.ail:697` and `:724` STAND** — they pin validator rules,
  constructing identities directly, and the rules do not change. What re-tenses is their prose
  ("what the bridge could supply today"). A **new** integration row is owed beside them: the
  recording path, driven through the real bridge, now produces the valid class — the row that turns
  D21 §4's latent defect into a green round trip.
- **`absent_classes` (`dst_discovery.ail:446`) finally moves — witness, not removal**, exactly as
  D19's three filesystem classes did: `DiscoveryWitness` (`:248`) gains an extension-effect count,
  `class_balance(…, 0, …)` becomes a real balance, and `RandomDrawIdentity` stays pinned at literal
  zero (its ground is unchanged). **This is the item that finally re-words the pin's recorded
  ground** — D21 and D23 left D19's "structural" wording in place deliberately so the measured
  refutation stayed visible; superseding it now, cite D21 §5.3 in the re-wording rather than
  deleting the history.
- The bridge's identity comment block (`session.ail:955-974`) and D21 §5's mirrors re-tense
  two-part per S15.

## The witness, and S14's two subjects

The demonstration-grade row is a **record → validate → replay** round trip through the real
machinery: a graded scenario (D19's pattern — no graded profile installs compose, so the scenario
builds its own subject) in which an extension hook calls `ctx.ports.proc_exec` under recording
ports; the resulting program **validates with zero rejections** (the D21 §4 defect, closed by
measurement); the replay **serves** the dispatch from the world (no live arm, no real subprocess —
assert the served content and exit code arrive); and `UnusedInteraction` reports nothing. Distinct
quantities throughout (S7): the scenario should interleave at least one driver tool dispatch with
the extension's so the queue discipline is exercised, with no two counts equal.

Mutants that must go red, each against its named row: the adapter hardcoding the ext id (S33 row);
the reconstitution dropped (UnusedInteraction row — prove the tripwire fires rather than trusting
it); the interleaving swapped (the S26 row, if the shared queue is chosen).

## Cascade and gates

- Edits inside `ext_ports_of` re-baseline the five `session.ail` anchors again — the six-file form,
  profiles `driver_only` **20 → 21**, `driver_plus_no_ops` **7 → 8**. S18: re-tense first, compute
  anchors once. If `tool_phase.ail` is touched (it should not be), the nine-file form applies.
- `make sync_packages` after any `types.ail` edit (only needed if `ExtCtx` gains a field — which is
  optional under the distinct-seam design; prefer no ABI edit at all).
- Green before hand-back: `execution_program`, `discovery`, `world_state`, `program_persistence`,
  `strict replay`'s suite, `declared_vs_performed`, `conformance`, `anchors`, `predicate_anchors`,
  `attribution_table`; `ext_ambient_inventory` unchanged (this item records and serves — it still
  routes no compose site, so compose stays 11/32 and yields stay 4/15, 5/15 — assert it).

## Out of scope, per the goal-line rule

- **Routing compose's `exec` sites** — item 3 of the path, unblocked by this item, not performed by
  it.
- The four-variant fault-class discrimination across the ABI (maintenance register).
- `RandomDrawIdentity`'s adapter (same seven-sites fact, no consumer on the path).
- The bridge's `workdir`/`timeout_ms` hardcoding (register).
- Anything the successor audits (item 3… of the queue ordering: audits precede routing) will do —
  do not audit `on_pre_step`/`on_solver_candidate` here.

## Stop and report rather than deciding inline

- If neither transport design can deliver the id without an ABI surface change beyond an additive
  `ExtCtx` field — anything touching `ExtPorts`'s field set or `proc_exec`'s signature stops here.
- If serving the class demands a second decode path or any schema-version motion (finding 1 says it
  must not; if measurement disagrees, the finding is wrong and that is itself reportable).
- If the shared-queue design is chosen and no fixture can make the misalignment observable
  in-process — a row that would pass either way is worse than no row (S33); narrow the label and
  report.

## Report back

`NOTE-d24-…` in the established form: the transport design chosen and what the other would have
cost; the adapter count afterwards (is it eight, or a branch — say which and why); the round-trip
row's numbers; what the pin's re-worded ground now says; every mutant and its row; the cascade
cost; and what item 3 (the successor audits) inherits. State explicitly whether the D21 §4 defect
is closed by measurement — that sentence is the item's headline.
