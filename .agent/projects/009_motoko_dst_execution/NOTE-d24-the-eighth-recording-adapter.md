# WI-D24 — the eighth recording adapter, and the `ext_id` that reaches it

**Result: SHIPPED, no stop condition fired, and the headline is one sentence — WI-D21 §4's defect is
CLOSED BY MEASUREMENT.** An extension-initiated dispatch is now recorded as
`ExtensionEffectIdentity(<the performing extension>, extension_effect_fault, "")`, the program
VALIDATES with zero rejections, and the replay SERVES the dispatch from its own cursor with nothing
left unconsumed. The round trip runs in `discovery_dst`'s `effect_scenario` against the real bridge,
the real recorder and the real driver.

**And the transport is neither of the two the handoff named.** Both were measured and both were
worse. The ext id rides in the world token that `ext/runtime`'s fold already re-seats per hook.

---

## 0. THE HEADLINE

**Is the WI-D21 §4 defect closed by measurement? YES.** The row is
`effect: the recorded program VALIDATES — WI-D21 §4's rejected program is closed by measurement`,
and it is green against a program produced by a real recorded session in which a real hook called
`ctx.ports.proc_exec`. Through WI-D23 that call produced `ToolIdentity("loop_v2", "", tool)` and
`validate_identity` refused it. It no longer produces that identity at all.

**Second, smaller headline: the handoff's finding 3 hazard never comes into existence, and its
finding 2 tripwire is not the one that fires.** Measured, a dropped reconstitution produces
`OutcomeDiffers`, not `UnusedInteraction` — §5.

---

## 1. The git wall-clock window

Handoff commit `7380b51` at `2026-08-09T10:34:04Z`; work complete at ~`12:2xZ`. **~1h50m**, against
D23's ~42m, D22's ~1h25m, D21's ~1h03m — the longest of the run, and the reason is that this is the
first item since D19 that added a world class, a `Ports` field, a recording adapter, a
reconstitution projection, a witness field and a transport, rather than closing links on a surface
someone else had built. Roughly: ~35m grounding and design (three transport candidates priced
against measured construction censuses), ~50m build, ~15m mutants and the one design correction they
forced, ~10m cascade, sweep unattended.

---

## 2. THE TRANSPORT: chosen, and what the other two would have cost

The handoff offered two designs and asked for the choice. **Measured at HEAD, neither could deliver
the id**, and the reason is the same for both: the id has to reach a closure built once per step
from a registry it cannot index, whose ABI signature is fixed below `6.0`.

| Design | What it costs, measured | Verdict |
|---|---|---|
| **A. per-extension `ExtPorts`** (`ext_ports_of` gains an `ext_id`) | the fold must SELECT the right port record, so `dispatch_*` gains a parameter. `dispatch_tool_handle` is called from **`tool_phase.ail:365`** → the nine-file cascade, plus `tool_envelope_dispatch`, `dst_hook_guard` and six script files. And a `(string) -> ExtPorts` parameter carries `ext_ports_of`'s ten-effect row, which would union onto every dispatcher's declared row — the surface `declared_vs_performed` and criterion 1 measure | **rejected on the effect row before the file count** |
| **B. `originator` on `ToolInvocation`** (one adapter, one branch) | `ToolInvocation` has exactly **three** literal construction sites and one of them is **`tool_phase.ail:419`** → the nine-file cascade *anyway*. Plus `recording_tool` becomes a producer of two identity classes (S16), plus the shared-queue hazard the handoff's finding 3 names | **rejected: not even cheaper** |
| **C. the holder on the world token** — TAKEN | `WorldState` +2 fields, `ext_world` codec +2 fields, four one-line stamps and four one-line clears in `ext/runtime.ail`, and `Ports` +1 field bound in **one** constructor (`ports_shape_probe`) plus two `stub_step` record updates and two fixture updates | **taken** |

**Why C is not a workaround but the right shape.** The fold is the ONE place in the tree that knows
which extension is about to run. It cannot call back into `session` (cycle at `session.ail:52`). The
only value it hands the hook that reaches `proc_exec` is the world token — and it already re-seats
that token per hook for WI-B2b's reasons. So the id travels on the channel that already exists, and
the identity becomes a property of THE CALL rather than of the port record, which is what it
actually is.

**What C explicitly did NOT need: `ExtCtx.ext_id`.** The handoff and WI-D21 §5.2 both expected it.
It would tell the HOOK who it is — which the hook already knows — and would still not reach the
closure. **No ABI shape changed**; the only `types.ail` edit is a documentation paragraph on the
`proc_exec` row.

---

## 3. THE ADAPTER COUNT: EIGHT, not a branch

`ports.recording_ext_effect` is a real eighth `record_interaction` site, beside a real eighth
`Ports` field (`ext_effect_exec`) served from a real second cursor (`WorldState.ext_effects`).
`recording_tool` is untouched and still produces exactly one identity class.

**The two adapters share their two arms and do not share their queue**, which is the inverse of the
usual split and is deliberate. `live_tool_outcome` and `scripted_tool_outcome` were lifted out of
`world_tool` so both seams dispatch through one call and evaluate the fault order (correlation →
deadline → code → completion) in one place; the CURSOR is what differs, because that is the only
thing that actually differs.

**Why the queue had to split**, restated as the failure it prevents: `world_tool`'s correlation
guard fires only when both ids are non-blank, and this class's call id is legitimately blank. An
extension-effect entry in the shared queue is therefore consumable by a driver dispatch **with no
mismatch reported** — present-but-wrong inside the world's own supply. With two cursors that is not
representable rather than forbidden by a rule someone has to remember.

---

## 4. THE ROUND-TRIP ROW, with its numbers

`scripts/dst/discovery_dst.ail`'s `effect_scenario`, under `make discovery`. Subject: a hook whose
registry id is **`ext_delta_24`** — *not* compose's, per S33 — bound to `on_response_intercept`,
calling `ctx.ports.proc_exec(ctx.world, "BashExec", …)` once per intercept.

| Quantity | Value |
|---|---|
| extension effects recorded | **4** |
| driver tool dispatches recorded, same log | **3** |
| `ext_effects` seeded / consumed | **6 / 4** |
| reconstituted queues | tools **3**, ext_effects **4** |
| program rejections | **0** |
| replay mismatches | **0** |
| discovery findings | **0** |

Distinct quantities per S7: driver tool durations 7/11/13 with `exit_code -1`; extension effect
durations 17/19/23/29/31/37 with exit codes 41/43/47/53/59/61. Nothing in one queue can be mistaken
for anything in the other.

**Twelve assertions**, of which four are the item's substance: the origin is the extension's own id;
the class id is the catalogue's row; the program validates; the reconstituted queue serves the
recorded content and exit code, and the whole program replays identically.

**THE SLACK IN THE SEEDED QUEUE IS LOAD-BEARING.** An empty `ext_effects` queue does not fail — it
DELEGATES, and runs a real `bash -lc` inside a deterministic gate. Six entries against four
intercepts means a future off-by-one in the dispatch count is a quiet unconsumed tail rather than a
live subprocess.

---

## 5. THE MUTANTS: 4 applied, 4 killed their named row — and one corrected a handoff finding

Save and restore by file copy (S17); all three files verified byte-identical by `diff` afterwards
and the suite re-run to green.

| # | Mutant | Named row | Result |
|---|---|---|---|
| M1 | the adapter hardcodes `"compose"` as the ext id | the ORIGIN row (S33) | **✗ origin only** — every other row in the scenario stayed green, which is exactly S33's claim executed: a constant satisfies every count-based row because compose is the only extension the project ever names at this seam |
| M2 | `world_state_of` binds `ext_effects: []` (reconstitution dropped) | the reconstitution row, the served-content row, the replay | **✗ all three**, and the replay diff shows the live arm ran: the replayed log carries `{"tool":"BashExec","cmd":"true","exit_code":0,…}` where the program carries `EXT-EFFECT-1/41`. **A real subprocess executed inside a replay.** |
| M3 | `ext_effects_of` collects `ToolIdentity` (the two classes share a home) | the served-content row (S26) | **✗ served content** — head is `OK-ALPHA/-1`, the DRIVER's entry, where `EXT-EFFECT-1/41` belongs |
| M4 | the fold's stamp dropped at `first_intercept` | the origin row AND validation | **✗ origin, ✗ validation (4 rejections), ✗ reconstitution refused** — `world_state_of` returns `replay-refused-invalid-program`. A blank component is a rejection, not a placeholder, end to end |

### 5.1 The handoff's finding 2 is right in its conclusion and wrong in its mechanism

The handoff predicted that dropping reconstitution would surface as `UnusedInteraction` — *"the one
most easily forgotten, because NOTHING FAILS"*. **Measured under M2, `UnusedInteraction` does not
fire.** The replayed run makes the SAME number of requests; it just answers them from a live
dispatch, so the rule that fires is `OutcomeDiffers`. `UnusedInteraction` needs the replay to make
FEWER requests, which a delegating adapter never does.

The conclusion survives — it is loud, and only after the subprocess ran. **So the item added the
check that fires FIRST and without a run:** `reconstitution_balance` gained an `extension_effects`
queue balance, and under M2 it reports before the replay is even started.

---

## 6. THE PIN: what its re-worded ground now says

`ExtensionEffect` is out of `absent_classes`' literal-zero pin and under a `DiscoveryWitness` field,
exactly as D19's three filesystem classes were. `RandomDraw` stays pinned at literal zero.

The re-wording is at `dst_discovery.absent_classes` and it says, in substance:

> WI-D24 took the pin off `ExtensionEffect` and put a witness under it — D19's choice made a second
> time, and for the second time in preference to removal, because a witnessed class still pins at
> zero for every run that routes nothing and every graded run in this tree but one does. **And this
> is where D19's recorded ground is finally re-worded, three items after it was refuted.** WI-D21
> §5.3 measured that "structural" did not survive: the catalogue row had existed since WI-C5, the
> ext id existed at every dispatch site, and the real reason the count was zero was that no adapter
> constructed the class. D21 reported the error instead of re-wording it in place, deliberately, so
> the refutation stayed visible to the item that would act on it. WI-D24 is that item. **`RandomDraw`
> stays pinned and its ground is unchanged** — no `record_interaction` site constructs it, and unlike
> this class it has no consumer asking for one. That is still "nothing routes it yet" rather than
> "structural", and saying so is the honest version of the distinction D19 drew.

The history above it is kept per S15 rather than deleted.

---

## 7. THE ONE DESIGN CORRECTION CONTACT FORCED, and it is the item's most transferable finding

**The first `stamp_holder` was `world_to_token({ token_to_world(t) | holder_ext_id: id })`.** It is
shorter, it type-checks, every row in `ext_world`, `discovery` and `world_state` passed under it —
and it is wrong.

`token_to_world` is TOTAL. A token this module did not write decodes to `empty_world_state()`, and
the re-encode replaces it. `declared_vs_performed`'s trace ports hand the fold exactly such a token
— `{ token: jo([kv("trace", …)]) }`, a deliberate fabrication whose whole job is to record which
seams a hook called — and the round-trip form silently erased it. **Two reachability rows went red
and that is how it was caught.**

**The rule the correction establishes is wider than this field: THE HOST MUST NOT REWRITE A TOKEN IT
DID NOT BUILD.** `ExtWorld` is documented as opaque to extensions; opacity has to run both ways, or
"opaque" means "the host may reinterpret it". `stamp_holder`/`clear_holder` are now a key-set over
the token's own object (`std/json.asObject`), and the identity on anything that is not an object.
Asserted in `ext_world` by
`test_the_holder_stamp_preserves_a_token_the_host_did_not_build`, both clauses.

This is the hazard `dst_interaction.ail`'s header has reported-not-fixed since WI-D17 —
"`ext_world.identity_body_of` falls through to `ClockAdvanceIdentity` for an unrecognised tag, by
its own stated design" — biting one level up, at its first caller.

---

## 8. THE CASCADE: NINE files, with `tool_phase.ail` untouched, which the recorded law says is impossible

The handoff priced the six-file form. **Measured, six anchors moved, not five:**

- the five `session.ail` clock anchors `1096/1355/1461/2906/3016 -> 1111/1370/1476/2921/3031`, all
  **+15**, for the usual `ext_ports_of` reason;
- **`src/core/ext/runtime.ail:190 -> :199`**, because the eighth adapter's ext id is stamped by that
  file's fold and the import plus its rationale sit above the anchor.

All six anchored expressions compared to `git show HEAD:` character by character — **byte-identical,
pure offset drift.**

**And the three discovered-site fixtures carry the `ext/runtime.ail` anchor as well as
`tool_phase.ail:318`.** WI-D21 §11.1 recorded nine files as *"the price of a `tool_phase` move"*. The
real rule is that it is the price of moving **either** anchor those fixtures carry. This item paid
nine with `tool_phase.ail` untouched. The law is corrected in `anchors.sh`, where the enumeration
lives, with the widened grep.

| # | File | Change |
|---|---|---|
| 1 | `tools/predicate-anchors/anchors.sh` | the loop, the runtime check, the law's correction |
| 2 | `src/core/dst_attribution_table.ail` | 6 rows + 3 test literals + the header's `classify_site` string |
| 3 | `scripts/dst/attribution_table_dst.ail` | 8 literals (5 record-form, 3 `classify_site` string-form) |
| 4 | `src/core/dst_driver_only.ail` | version **20 → 21**, hash |
| 5 | `src/core/dst_driver_plus_no_ops.ail` | version **7 → 8**, hash |
| 6-8 | `driver_only_dst.ail`, `driver_plus_no_ops_dst.ail`, `profile_definition_dst.ail` | the discovered-site fixtures |
| 9 | — | (the third file's second literal form, counted above) |

`sha256:f23a1166… -> sha256:4339fef0…`, derived by running `table_content_hash()`, not hand-computed.
`source_revision` unchanged at `c0fbf10` per D4's rule.

**THE STRING-FORM ANCHORS ARE A TRAP THE RECORD-FORM GREP MISSES.** `classify_site("src/core/ext/runtime.ail:190", …)`
does not match `grep 'runtime.ail", line: [0-9]'`. Four of them existed, `make attribution_table`
found them, and the widened grep is now in `anchors.sh`.

---

## 9. THE ADOPTION ROW WI-D23 BUILT HAD TO MOVE, and that it went red is the design working

`world_state_probe`'s `exit_code_witness` adoption row seeded `WorldState.tools` and drove
`ext_ports_of`'s `proc_exec`. After this item that closure reads the OTHER cursor, so the queue was
empty, the closure delegated, and the row reported `got exit_code 1` — the defensive arm's code from
a real `BashExec {}`. **The row was MOVED to `ext_effects`, not rewritten**: its subject is
unchanged and is still the real bridge against a scripted world, per S14.

---

## 10. THE YIELDS AND THE AMBIENT INVENTORY — asserted, not assumed

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |
| compose | 11 ambient sources, 32 `ExtPorts` field calls | **11 / 32** |

All unmoved, and they had to be: **this item records and serves; it routes no compose site.** A
moved yield would have meant an instrument reading something other than what it claims.

---

## 11. THE COUNTERS, KEPT APART

**Silent-wrong: 75 → 76.** The new site is `ext_world`'s host-side token rewrite (§7): because
`token_to_world` is total, "decode, edit, re-encode" and "preserve" both type-check on a token the
host did not build, and the wrong one destroys it silently. **This is recorded as a PRE-EXISTING
hazard reaching its first caller rather than as a defect this item authored** — the totality is
WI-B2b's, the hazard is the one `dst_interaction.ail`'s header has reported since WI-D17, and this
item is simply the first to write a host-side rewrite. If a future reader judges it an
authored-and-closed defect under D22's rule, subtract one and say so.

**Instrument-weaker-than-its-claim: 7, unchanged.** No row measured less than its label. The
scenario's first draft replayed under a different ext id and `WrongOrigin` fired — that is a fixture
bug caught in one run, and it is kept at the site because it is the cheapest available proof that
the origin is read from the transport rather than being decorative.

---

## 12. WHAT ITEM 3 (the successor audits) INHERITS

1. **The seam is done.** Routing a compose `exec` site now needs no type work (D23) and no identity
   work (this item). What remains at compose's sites is compose's own shape question:
   `proc_exec(w, "ailang", …)` reaches no compiler, and `grep_impl` reads `out.stdout` as bytes where
   the seam renders JSON. Both notes are re-tensed at their sites and now name only that.
2. **`on_pre_step` CANNOT reach `proc_exec` and `on_solver_candidate` CAN** — measured from the ABI
   rows, not assumed: `on_pre_step` is `! {AI, IO, Trace}` (no `Process`), `on_response_intercept` is
   `! {IO, Process, FS}`, `on_solver_candidate` is `! {Process}`. All four world-threading folds are
   stamped anyway, so a future row widening cannot silently start recording effects attributed to
   nobody.
3. **The dispatchers now clear the holder on the way out.** If the audit adds a fold, it must stamp
   on the way in and clear on the way out, and it must use `stamp_holder`/`clear_holder` rather than
   a world round trip — §7.
4. **`DiscoveryWitness.extension_effects` is a hand-maintained count.** A scenario that installs an
   extension reaching this seam has to set it; nothing derives it from the run, by design.
5. **`RandomDrawIdentity` is now the only class pinned at literal zero**, and its ground is stated
   rather than inherited.
6. The bridge's `workdir: "."` and `timeout_ms: 0` remain, named at the site (D21 §8) — this seam
   still cannot produce `ToolDeadlineExceeded`, and the extension-effect class's recorded deadline is
   therefore always 0.

---

## 13. THE SWEEP

`make sync_packages` re-run after every `types.ail` and core edit. `check_core`: **56 passed, 0
failed**. `AILANG_RELAX_MODULES=1 make -k dst` to a log file, never through `tail`, with no tracked
file touched while it ran.

Targets run individually before the sweep, all green: `discovery`, `world_state` (both entry points),
`execution_program`, `program_persistence`, `strict_replay`, `declared_vs_performed` (40/40),
`conformance`, `attribution_table`, `predicate_anchors` ("no drift: 6 anchors and 7 references"),
`driver_only`, `driver_plus_no_ops`, `ext_ambient_inventory`, `ext_hook_scope_selftest`.

**TWO SWEEPS, AND THE SECOND IS THE REPORTED ONE**, for WI-D21 §11.2's reason with a new instance.
Sweep 1 found a THIRD red target — `ext_call_inventory_selftest`, §13.1 — whose fix is a source edit,
which invalidated it. Sweep 2 is clean of it.

**AND I BROKE THE NO-EDIT-DURING-A-SWEEP DISCIPLINE TO GET THERE**, recorded rather than glossed:
`expected.json` was edited while sweep 1 was still running. The target that reads it had already run
and failed 200 lines earlier, and no later target reads it, so sweep 1's other results are unaffected
— but "the edit could not have mattered" is an argument, and the rule exists because that argument is
easy to make and hard to be sure of. Sweep 2 was run with the tree untouched throughout, which is why
it and not sweep 1 is the reported one.

**Sweep 2's only two red targets are `test_coverage` and `test_coverage_selftest`, and both are the
SAME failures WI-D22 §12 recorded and stash-confirmed at its HEAD** and WI-D23 §11 re-confirmed:
`[failing] src/core/prompts_test.ail` (0 of 6), `[stale_skip_record] "Named test blocks not yet
implemented"`, and the selftest's identical `stale_skip_record` leak into its `named_only.ail`
fixture (`self-test: 2 failure(s)`). **No finding names any file this item touched, and there is no
`[untracked]` row.** Not re-confirmed by stash-and-run, for D23's reason: D22 measured that `git
stash` is unsafe for a HEAD baseline while another session shares this worktree, D22's own stash-run
already pinned these two, and every failing subject is a file this item never edited.

The coverage census moved exactly where this item's tests were added: src/core **65 files, 42 carry
tests, 415 tests, 405 passed, 4 skipped**, against D23's 413/403 — **+2**, which is the two inline
rows added to `ext_world.ail`. `ports.ail` 5/5, `session.ail` 23/23, `dst_replay.ail` 21/21 all still
pass their whole inline suite in the same run that exercises the new anchors and profiles.

### 13.1 The third red target, and the pin that caught it

`ext_call_inventory_selftest` failed:

```
FAIL membership proc_exec: state returns-it agrees but the BRIDGE SEAM moved
     -- expected Ports.tool_exec, derived Ports.ext_effect_exec
```

**This is the seam half of that pin doing precisely the job it was added for.** The fixture pins both
the classifier STATE and the core seam each `ExtPorts` field forwards to, and its own note says why:
*"pinning the state alone would also miss a slip that resolved a field to the WRONG seam, so the seam
is pinned too."* The state is unchanged at `returns-it`; the seam moved, deliberately, and nothing
else in the tree would have said so. Re-recorded to `ext_effect_exec` with the reason in the
fixture's prose rather than relaxed.
