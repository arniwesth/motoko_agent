# 2026-08-09 Cluster 50: WI-D24 — the eighth recording adapter, and the `ext_id` that reaches it

## Context

Branch: `arniwesth/mot-86-wi-d24-the-eighth-recording-adapter`.

Session span: `7380b51` → **`3e18d14`**. Input was
`HANDOFF-execute-d24-the-eighth-recording-adapter.md`, grounded against HEAD `7380b51`
(`2026-08-09T10:34:04Z`). Pin **v0.33.0**. **~1h50m** — the longest of the D19–D24 run, and the
reason is the opposite of D23's: this is the first item since D19 to add a world class, a `Ports`
field, a recording adapter, a reconstitution projection, a witness field *and* a transport, rather
than closing links on a surface someone else had built.

**Item 2 of the goal line's critical path. 28 files, 1426 insertions / 161 deletions:**

```text
.agent/.../NOTE-d24-the-eighth-recording-adapter.md      344 +  the record
scripts/dst/discovery_dst.ail                            301 +- effect_scenario: the record → validate →
                                                                replay round trip, 12 assertions
src/core/ports.ail                                       227 +- WorldState.ext_effects + holder_ext_id,
                                                                Ports.ext_effect_exec, world_ext_effect,
                                                                recording_ext_effect (the eighth), the two
                                                                shared arms lifted out of world_tool
src/core/ext_world.ail                                   148 +- both fields in the codec, stamp_holder /
                                                                clear_holder as a key-set, two new rows
src/core/session.ail                                     103 +- the bridge calls ext_effect_exec; the D21
                                                                identity block re-tensed two-part
src/core/ext/runtime.ail                                  64 +- four folds stamp, four dispatchers clear
src/core/dst_program.ail                                  58 +- the two D21 assertions re-tensed (rules stand)
src/core/dst_replay.ail                                   55 +- ext_effects_of, world_state_of binds it,
                                                                the reconstitution queue balance
src/core/dst_discovery.ail                                38 +- DiscoveryWitness.extension_effects; the pin
                                                                takes a witness, D19's ground re-worded
the anchor cascade (9 files)                             117 +- SIX anchors moved, driver_only 20→21,
                                                                no_ops 7→8, hash re-derived by running it
compose.ail / author_tools.ail / types.ail                58 +- the identity blocker is gone; re-tensed
tools/ext_call_inventory/fixtures/expected.json           15 +- the seam pin re-recorded with its reason
```

## The headline

**WI-D21 §4's defect is CLOSED BY MEASUREMENT.** Through WI-D23 the first extension to call
`ExtPorts.proc_exec` in a recorded run made the recorder emit `ToolIdentity("loop_v2", "", tool)`
— a program its own validator refuses. It no longer produces that identity at all: the bridge
calls `Ports.ext_effect_exec`, `ports.recording_ext_effect` writes
`ExtensionEffectIdentity(<the performing extension>, extension_effect_fault, "")`, the program
validates with **zero rejections**, and the replay **serves** the dispatch from its own cursor with
nothing left unconsumed.

## The transport is neither design the handoff offered

The handoff named two and asked for the choice. Measured at HEAD, **neither could deliver the id**,
for one shared reason: it has to reach a closure built once per step from a registry it cannot
index, whose ABI signature is fixed below `6.0`.

| Design | Measured cost | Verdict |
|---|---|---|
| per-extension `ExtPorts` | the fold must SELECT a port record → a `dispatch_*` parameter carrying `ext_ports_of`'s ten-effect row onto every dispatcher, plus `tool_phase.ail:365` and six script files | rejected on the effect row before the file count |
| `originator` on `ToolInvocation` | three literal sites, one of them `tool_phase.ail:419` → the wide cascade *anyway*; and one adapter producing two identity classes (S16) | rejected: not even cheaper |
| **the holder on the world token** | `WorldState` +2, codec +2, four stamps + four clears, `Ports` +1 bound in one constructor | **taken** |

`ext/runtime`'s fold is the one place in the tree that knows which extension is about to run, it
cannot call back into `session` (cycle at `session.ail:52`), and the only value it hands the hook
that reaches `proc_exec` is the world token it already re-seats. So the id travels on the channel
that exists, and the identity becomes a property of **the call** rather than of the port record.
**No ABI shape changed, and `ExtCtx.ext_id` — which both the handoff and D21 §5.2 expected — was
not needed:** it would tell the hook what the hook already knows, and still not reach the closure.

## Eight, not a branch

A real eighth `record_interaction` site, beside a real eighth `Ports` field, served from a real
second cursor. `recording_tool` is untouched and still produces one class. The two adapters
**share their arms and not their queue** — `live_tool_outcome` and `scripted_tool_outcome` were
lifted out of `world_tool` so both seams dispatch through one call, while the cursor splits because
`world_tool`'s correlation guard fires only when both ids are non-blank and this class's call id is
legitimately blank. In the shared queue an extension-effect entry is consumable by a driver
dispatch **with no mismatch reported**; with two cursors that is not representable.

## The round trip and the mutants

`discovery_dst.effect_scenario`, under `make discovery`: a hook with registry id **`ext_delta_24`**
— deliberately not compose's, per S33 — calling `ctx.ports.proc_exec` once per intercept.
**4 extension effects interleaved with 3 driver dispatches**, 6 entries seeded / 4 consumed,
reconstituted tools 3 / ext_effects 4, **0 rejections, 0 replay mismatches, 0 discovery findings**.
Distinct quantities throughout (durations 7/11/13 vs 17/19/23/29/31/37; exit codes -1 vs
41/43/47/53/59/61).

Four mutants, each red on its named row, restored by file copy per S17 and verified byte-identical:

| Mutant | Row it killed |
|---|---|
| the adapter hardcodes `"compose"` | the ORIGIN row **and only that row** — S33 executed rather than argued |
| `world_state_of` binds `ext_effects: []` | reconstitution, served content, replay — and a **real `bash -lc` ran inside the replay** |
| `ext_effects_of` collects `ToolIdentity` | the served-content row: head is the DRIVER's `OK-ALPHA/-1` |
| the fold's stamp dropped | origin, validation (4 rejections), and `world_state_of` refuses the program outright |

## The five findings worth carrying

1. **The handoff's finding 2 is right in conclusion and wrong in mechanism.** Dropping
   reconstitution does **not** fire `UnusedInteraction` — the replay makes the same number of
   requests and answers them from a live dispatch, so `OutcomeDiffers` fires. `UnusedInteraction`
   needs *fewer* requests, which a delegating adapter never produces. Loud, but only after the
   subprocess ran — so the item added a `reconstitution_balance` queue check that fires **first and
   without a run**.
2. **THE HOST MUST NOT REWRITE A TOKEN IT DID NOT BUILD.** The first `stamp_holder` was
   `world_to_token({ token_to_world(t) | … })` — shorter, type-checks, and silently erased any
   token the host did not write, because `token_to_world` is total.
   `declared_vs_performed`'s trace ports hand the fold exactly such a token and two rows went red.
   Now a key-set over the token's own object (`std/json.asObject`), identity on anything that is
   not an object, asserted in `ext_world`. This is the hazard `dst_interaction.ail`'s header has
   reported-not-fixed since WI-D17, biting one level up at its first caller.
3. **The cascade was NINE files with `tool_phase.ail` untouched**, which D21 §11.1 recorded as
   impossible. Six anchors moved: the five `session.ail` clock sites **+15**
   (`1096/1355/1461/2906/3016 → 1111/1370/1476/2921/3031`) and **`ext/runtime.ail:190 → :199`**.
   The three discovered-site fixtures carry *both* anchors, so either fires the wide form. All six
   expressions byte-identical against `git show HEAD:`. Law corrected in `anchors.sh`.
4. **Four anchor references are STRING-form** — `classify_site("src/core/ext/runtime.ail:190", …)`
   — and invisible to the record-form grep. `make attribution_table` found them; the widened grep
   is now recorded.
5. **`ext_call_inventory_selftest`'s seam pin caught the re-route**, deriving
   `Ports.ext_effect_exec` against a pinned `Ports.tool_exec`. Exactly the slip the seam half of
   that pin was added for — the state pin alone stays green through a re-route. Re-recorded with
   the reason rather than relaxed.

## The pin

`ExtensionEffect` is out of `absent_classes`' literal-zero pin and under a `DiscoveryWitness`
field, as D19's three filesystem classes were. **D19's "structural" ground is re-worded here, three
items after D21 §5.3 refuted it and deliberately left it standing** so the refutation stayed
visible to the item that would act on it. `RandomDraw` stays pinned at literal zero with its ground
unchanged and now stated: nothing records it, and unlike this class it has no consumer asking.

## Counters and sweep

Silent-wrong **75 → 76** — the new site is `ext_world`'s host-side token rewrite (finding 2),
recorded as a pre-existing hazard reaching its first caller rather than a defect this item authored;
flagged in the NOTE so a future reader can subtract one and say so. Instrument-weaker-than-its-claim
**7 unchanged**. Yields asserted unmoved: PORT-MEDIATED 4/15, HOOK-PORT-MEDIATED 5/15, shipped
closure verdict 4/15, compose 11 sources / 32 field calls — this item records and serves, it routes
no compose site.

**Two sweeps; the second is the reported one.** Sweep 1 found the stale seam pin, whose fix is a
source edit. Sweep 2 is red only on `test_coverage` / `test_coverage_selftest`, the same two D22
stash-confirmed at its HEAD; no `[untracked]` row and nothing names a file this item touched.
Census **415 tests / 405 passed** against D23's 413/403 — exactly the two rows added to `ext_world`.

**One process slip, recorded:** `expected.json` was edited while sweep 1 was still running. The
target that reads it had already run and failed, and no later target reads it — but "it could not
have mattered" is an argument, not a guarantee, which is why the rule exists and why sweep 2 was
run with the tree untouched.

## What item 3 (the successor audits) inherits

The seam is done: routing a compose `exec` site needs no type work (D23) and no identity work
(this item). What remains at compose's sites is compose's own shape question, and both notes are
re-tensed to name only that. Measured from the ABI rows for the audit's benefit: **`on_pre_step`
cannot reach `proc_exec`** (`! {AI, IO, Trace}`, no `Process`) while `on_response_intercept` and
`on_solver_candidate` can; all four world-threading folds are stamped anyway so a future row
widening cannot silently record effects attributed to nobody. `DiscoveryWitness.extension_effects`
is hand-maintained by design. The bridge's `workdir: "."` / `timeout_ms: 0` remain, so this class's
recorded deadline is always 0.
