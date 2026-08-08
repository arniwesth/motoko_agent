# 2026-08-08 Cluster 46: WI-D20 — Route B part 2b, route `on_tool_handle`

## Context

Branch: `arniwesth/mot-82-wi-d20-route-b-part-2b-route-on_tool_handle`.

Session span: `f9cb5bf` → **`26e4d7c`**. Input was
`HANDOFF-execute-d20-route-b-part-2b-route-on-tool-handle.md`, grounded against HEAD
`f9cb5bf` (`2026-08-08T10:06:52Z`). Pin **v0.33.0**. First command `10:07Z`, commit
`11:20Z`, **~1h13m** — the longest in the cluster, and roughly D19 plus one wasted sweep.

**The second routing, and seventeen times the first one's size.** Twenty-one files,
**1 782 insertions / 219 deletions**, of which **578** are the record.

```text
.agent/.../NOTE-d20-route-b-part-2b-route-on-tool-handle.md  578   the record
scripts/dst/discovery_dst.ail                               264 +- TWO graded scenarios: the routed
                                                                   hook, and the two-call batch
packages/motoko-ext-compose/author_tools.ail                240 +- 8 functions; std/fs and std/clock gone
packages/motoko-ext-compose/compose.ail                     170 +- the hook, one_attempt, the path key
packages/motoko-ext-compose/authoring/dispatcher.ail         83 +- check_snippet + the wrapper decision
tools/predicate-anchors/anchors.sh                           50 +- re-baseline + the NINE-consumer list
src/core/tool_phase.ail                                      50 +- THE DRIVER FIX, both halves
scripts/dst/declared_vs_performed.ail                        48 +  the on_tool_handle spine arm
scripts/dst/run_declared_vs_performed.sh                     46 +- the assertion + arm count 7 -> 8
packages/motoko-ext-compose/author_loop.ail                  69 +- 22 exits and recursions threaded
packages/motoko-ext-compose/store.ail                        57 +- 3 functions; std/fs gone
src/core/ports.ail                                           44 +- WI-D18's dir_make paragraph, tensed
src/core/dst_driver_only.ail                                 26 +- v17 -> v18, hash re-recorded
src/core/dst_attribution_table.ail                           23 +- the row + 3 test literals
src/core/dst_driver_plus_no_ops.ail                          10 +- v4 -> v5
scripts/dst/{driver_only,driver_plus_no_ops,profile_definition}_dst.ail  3 +- the three MISSED literals
```

| Definition-of-done item | State |
|---|---|
| All seventeen functions threaded, or a named list of what did not and why | **15 of 17 thread.** The other two perform only the unroutable `exec` and correctly take no world |
| The `proc_exec` decision taken and recorded | **met — not routed, again**, and a third binary makes it a seam property |
| The driver-arm audit for `on_tool_handle`, asserted rather than read | **met**, and it found **two** defects, not one |
| The `one_attempt:501` spelling fixed, with the compiler reason at the site | **met**, direction forced as predicted |
| A graded, routed `on_tool_handle` scenario with non-log witnesses | **met, and then a SECOND one**, because the first measured less than its label |
| S24: reachability separate from verdict, row not measuring less than its label | **met — after the row was caught doing exactly that** |
| S13/S9/S17/S26 process rules | **`sync_packages` first; mutants by `cp`. One new failure — see below** |
| Do not start two `make dst` sweeps | **met** (sequential, never concurrent) — but one sweep was wasted another way |
| Anchor cascade prediction | **FIRED, and the prediction's premise was false** |
| Yields 4 of 15 and 5 of 15 | **met, explicitly** |

---

## The mission result: 15 of 17 thread

Compose's `on_tool_handle` now takes its clock, directory creates, writes, removes, path
kinds, file reads and directory listings through `ctx.ports`, and returns the successor on
`ToolHandleOutcome.next_state` — which already existed, so **no ABI change**.

**The two that do not thread were decided, not skipped.** `compose.check_snippet` and
`run_snippet` each perform exactly one effect, `exec`, and that one cannot route. A function
performing nothing world-observable has no successor to carry; threading them would have
asserted a mediation that did not happen.

**The contrast is inside the item, which is what makes it a rule rather than an excuse.**
`authoring/dispatcher.check_snippet` and `author_tools.grep_impl` *also* shell out, and both
thread — because they perform routable effects as well. The test is not "does this function
shell out" but "does it perform anything the world can see".

Twenty-four signatures moved in total: fifteen of the seventeen, an eighteenth
(`store_snippet`, which has no callers anywhere), and eight pure carriers.

**`guard.ail` — the handoff's fifth module — has no effect sites and never did.** It imports
`std/string` alone; its apparent `readFile(` and `exec(` are *string literals*, because the
guard searches a snippet's text for those substrings. A grep finds them; a comment-stripping
grep still finds them. The kind of false member that survives being copied handoff to handoff.

---

## FINDING 1 — the driver dropped the successor on EVERY arm, and staled the input too

The audit D19 §3.4 owed. **Two independent defects, and the second inverts the first.**

### Where the drop was, and where it was not

`ext/runtime.first_handle` and `dispatch_tool_handle` are **correct and always have been** —
`first_handle` even carries a WI-B2b comment explaining why a *delegating* hook still threads
its successor. The drop was one frame above, at two call sites, both discarding it by
**projection**:

| Site | Shape |
|---|---|
| `tool_phase.ail:334` | `dispatch_tool_handle(…).decision` — then `next_state: world` on every arm |
| `tool_envelope_dispatch.ail:44` | same projection, into a function whose return type has **no successor field at all** |

Where D19 found the intercept's successor carried on one arm of four, this slot carried it on
**none**. `.decision` is a field access — there was never an arm at which the world could have
been kept.

### The read side, which makes the obvious fix a REGRESSION

`ctx` is built **once per batch** at `session.ail:2307` and passed unchanged through
`dispatch_tool_entries_with_builtin`'s fold, while `world` advances per entry. **From the
second tool call in a batch onward, `ctx.world` is the batch-start world.**

Writing `token_to_world(handled.next_state)` back without re-seating would hand the loop a
world **rewound past everything the earlier entries did** — a regression written by the very
edit that repairs the drop, type-checking exactly as readily. Both halves had to move
together: re-seat on the way in, carry the successor out on all three arms including into the
native dispatch's `ports.clock_now`.

### Why nothing could see either half

D19 §3.2's argument one slot over: **no `on_tool_handle` binding performed a world-threading
effect until this item routed compose's**, and under that condition all three answers — drop,
re-seat, rewind — produce identical worlds.

**Two hook slots audited, two drops found.** `on_pre_step` and `on_solver_candidate` remain
unaudited; the base rate is now 2 of 2.

### What was NOT fixed

The scratchpad loopback (`dispatch_tool_envelope` → `ws_loopback` → `exec_scratchpad_cell_ws`)
is structurally unable to carry a successor — it needs two return-type changes, a core type
change, and the WS event loop's recursion, in another package, on a path `on_tool_handle`
never travels. Reported, not patched.

---

## FINDING 2 — `proc_exec` fails on a third binary, which makes it a seam property

**Decision: not routed, all four sites, recorded at each.** `run_native_call` was
re-verified at HEAD rather than taken from D19's note: an if-chain over exactly six of
Motoko's own tool names with a final `else` returning *"requires extension capability…"*.

**The new fact is `rg`, in `author_tools.grep_impl`.** D19's finding could be read as "compose's
compiler invocation is an awkward fit for a tool-dispatch seam". `rg` is an ordinary
subprocess with no relationship to compose's compiler, and it fails identically. **The seam
does not front subprocesses; it fronts Motoko's tool names.**

The shape failure has a second form too: `grep_impl` branches on `Ok`/`Err` and needs
`out.stdout` as *bytes*, so under `ExtProcOutcome`'s single rendered string an `Err` and a
successful search matching nothing become the same value — and the fallback scan would fire
on the second.

What routed there: both `grep_fallback_scan` calls and `mk_ok`'s clock. An honest partial
rather than a silently complete one.

---

## Three rows that measured less than their labels — and three different repairs

Fourth consecutive item to find one; this item found three, all caught by mutating the thing
the label names.

**1. Repaired by building a new FIXTURE.** `routing_handle_scenario`'s threading row claimed to
catch both driver defects. Reverting the successor → red. **Reverting the re-seating → green.**
Structural: `script()` emits one tool call per step, so every batch holds one call and a
per-batch `ctx` is never stale within it — the two answers agree by construction. The
distinguishing input needs *both* two calls in one assistant step *and* an **allowing** policy,
because the pending path resolves one call at a time and builds a fresh `ctx` for each. That is
`batch_handle_scenario`, and it catches the mutant by name.

**2. Repaired by narrowing the LABEL, because no fixture could.**
`compose_tool_handle_threading` claimed three links of the spine; it pins **two**. The third —
`run_attempts` recursing on `w2` rather than `w` — is unpinnable in-process: without a model
`one_attempt` reaches its early `NeedRetry` before any routed seam, so `w2` *is* `w`. Named as
a gap rather than covered by a row that would pass either way.

**3. Avoided by choosing the right subject.** The S24 reachability row reads the two classes the
hook itself performs, not `provider_calls` or `tool_dispatches` — both non-zero in a run where
`provided_tools` was left `[]` and the hook never ran, which is D19 §8's defect exactly.

---

## Criterion 2 — 28 → 11 ambient, 5 → 32 field calls

The prize, and larger than D19's 0 → 5.

**Six of the seventeen removed were imports this item's own edit made dead.** Classifier 3
reads **import lines, not call sites**, so `compose.ail`'s `std/clock` and four `std/fs`
symbols plus `dispatcher.ail`'s `std/clock` were reporting ambient sources for effects the
extension could no longer perform.

**The handoff put import removal in part 3, and this is not that.** Part 3's question is the
closure-unit verdict for *already* unused imports. These went dead in the same commit that
killed their callers; leaving them would have left the instrument describing a state that had
ceased to exist. D19 correctly left them alone because `one_attempt` still used all five.

Criterion 1 did not move and could not — `ExtPorts.file_write` declares `! {FS}`.

The eleven that remain, counted: `ai_compat`'s `stepWithStream`; four `println`s; three
`exec`s; `config.ail`'s two registration reads; `register.ail`'s `getEnvOr`.

---

## The anchor cascade — FIRED, and the prediction's premise was false

The handoff predicted no cascade for an item that only adds call sites. **The premise did not
hold:** the driver fix needs `ext_world`'s codec inside `tool_phase.ail`, and an import can
only go above the anchors. Holding them would have meant compressing an unrelated import block
for four lines — the cosmetic edit `ext/runtime.ail:24` already carries once. Per the
handoff's own stop condition, **the anchors are an instrument; the drop is a defect.**

Re-baselined 313/314/373 → **317/318/413**; `driver_only_version` 17 → 18, `no_ops_version`
4 → 5, both hashes re-recorded.

**Two of the three are byte-identical drift; the third is not**, and that is recorded rather
than averaged away. `tool_phase.ail:373` read `ports.clock_now(world)` and `:413` reads
`ports.clock_now(handle_world)` — same site, same effect, same routing, different starting
world. Every previous re-baseline in this cluster could say "character-identical"; this one
cannot.

### The blast radius is NINE files, not six

**Three were missed and only `make dst` found them.** `driver_only_dst.ail:75`,
`driver_plus_no_ops_dst.ail:110` and `profile_definition_dst.ail:111` each carry their own
literal copy of the attributed Process site. All three went red with `[site-unaccounted]`,
which **reads exactly like a real routing-claim defect and is not one**.

They are invisible to every search that finds the other six — not in `src/core/`, not in the
attribution table, not named by `anchors.sh`. D16, D17 and D18 all moved *`session.ail`*
anchors, which these fixtures do not reference, so a re-baseline had never touched them and
nothing recorded they existed. The enumeration and the grep that finds all nine are now in
`anchors.sh`.

---

## The yields — said explicitly

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| shipped closure verdict | 4 of 15 | **4 of 15, "unmoved"** |
| door-3 residue | `intToFloat, show` | **`intToFloat, show`** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |

Exactly as predicted. Door 3 is live throughout the routed chain — `show(reading.now_ms)`,
`show(attempt)`, `show(seen)` — so compose stays HOOK-UNRESOLVED however completely 2b routes.

---

## The mutants

Restored by `cp` throughout (S17). No git operation while a mutant was in the tree.

| # | Mutation | Result |
|---|---|---|
| 1 | `tool_phase` Delegate arm returns `world`; native clock from `world` | **RED**, 3 rows |
| 2 | `tool_phase` drops the `ctx` re-seating only | **PASS** vs `routing_handle_scenario`; **RED** vs `batch_handle_scenario` |
| 3 | `run_attempts` recurses on `w` instead of `w2` | **PASS** — a named gap, not a repair |
| 4 | `handle_compose_tool` passes `w` instead of `started.next_state` | **RED** — witness `clock_now;` |
| 5 | `on_tool_handle` returns `next_state: ctx.world` | **RED** — witness empty |

**Mutant 2 is the one worth reporting.** Under it the census stays perfectly balanced — both
`dir_make`s and both `file_write`s logged — and what breaks is *which path each write names*.
**A count cannot see a collision on a path key**, which is why the graded row reads the final
world's directory rather than the log.

---

## Gate and sweep

`make dst`, cache-cold, run alone on a frozen tree — the **second** attempt; see below.

**Two red targets, both red before this item:** `test_coverage_selftest` and `test_coverage`.
(`Makefile:199: dst` is the aggregate propagating those two.) Neither `prompts.ail`,
`prompts_test.ail` nor `tools/test_coverage/` is in this diff, and `git diff f27c9a3 f9cb5bf`
over those paths is empty.

**One refinement to D19's binding 7.** D19 recorded the symptom as `LDR001: module not found`,
measured in a `git worktree`. At HEAD in place the module *is* found and **six assertions
fail**. Red either way and not this item's — but **D19's recorded symptom was an artefact of
measuring in an unsynced worktree**, and repeating that method reproduces the wrong diagnosis.

`declared_vs_performed`: **40 passed, 0 failed** (39 before; +1 from this item's spine arm).

---

## Process failures — one new, and it cost a sweep

**D19 §1's two did not recur.** Every mutant restored by `cp`; no git operation while a
mutation was in the tree; sweeps sequential, never concurrent.

**NEW: a comment-only edit to `src/core/ports.ail` was made while a `make dst` sweep was
running.** Nothing changed behaviourally, but the sweep was reading that file, so its result
could not be quoted as a measurement of a fixed tree — and a sweep you have to caveat is a
sweep you have to re-run.

> **D19's rule was "do not touch git while a mutation harness runs". The generalisation is: do
> not touch TRACKED FILES while any long instrument runs**, including for edits you are certain
> are inert. Cost of being wrong: a full sweep. Cost of waiting: a few minutes.

**Also worth recording, smaller:** three wait-loops written as
`until ! pgrep -f "make dst"` never fired, because the loop's own command line contains the
pattern it greps for. `kill -0 <pid>` is the version that works.

**AND ONE ERROR THAT REACHED THE COMMIT.** `git add -A` swept in
`.agent/research/simulation_visualization/zoomable_map_and_simulation_overlay.md` (225 lines),
an unrelated research document created outside this session at `11:13Z`. It is **not** WI-D20's
work and corrupts that commit's file list. It was discovered while writing this summary, by
which time `26e4d7c` was already pushed and had `2526ef0` on top of it — so **history was not
rewritten**, and the stray file is recorded here instead. `git add -A` after a long session is
not safe on a shared tree; `git add <paths>` is.

---

## Recorded bindings

**Discovered — a tool, a compiler or a measurement forced it:**

1. The successor was dropped on **every** arm, by a projection above an innocent dispatcher.
2. `ctx.world` goes stale after the first call in a batch — found while writing the fix for 1,
   and it inverts it.
3. `proc_exec` cannot take `rg` either — a second, unrelated binary.
4. `guard.ail` has no effect sites at all.
5. `fileExists` is **true** for a directory (probed against `std/fs`), which is what makes
   `file_exists_impl`'s two-call collapse behaviour-preserving.
6. Classifier 3 counts **import lines**, not call sites.
7. The anchor re-baseline has **nine** consumer sites, not six.
8. `routing_handle_scenario` could not see the stale-`ctx` defect; the spine arm cannot see the
   `run_attempts` recursion. Both found by running the mutant.
9. `test_coverage`'s failure mode is not what D19 recorded.

**Decided — the code admitted more than one answer:**

1. Fix the driver rather than report it, and fix **both** halves together.
2. Report the scratchpad loopback rather than fix it.
3. Do not widen `proc_exec`; accept a module keeping `std/process` while losing `std/fs`.
4. Leave `check_snippet`/`run_snippet` unthreaded.
5. A `next_state` **field** on `AuthorToolResult` and `AuthorLoopResult`, a **wrapper** for
   `AuthoringToolResult` — the shape follows where the effects are, not the module.
6. Route `store_snippet` although nothing calls it, so `store.ail` drops `std/fs` entirely.
7. Remove the six imports this item made dead.
8. Re-baseline rather than buy neutrality with a cosmetic edit.
9. Build a second fixture where one could exist; narrow the label where none could.
10. Tense WI-D18's `ports.ail` paragraph rather than delete it (S15).

---

## Owed

* **`on_pre_step` and `on_solver_candidate` successor audits.** 2 of 2 slots audited have had a
  drop; these two are still unlooked-at.
* **The scratchpad loopback successor** — a real defect, structurally larger.
* **`proc_exec`'s widening or a `BashExec` routing** — a decision with consumers.
* **Registration's four `config.ail` functions** — disclosure, not routing.
* **Door 3's producer** and the hook-scope promotion.
* **`InitialWorld.files` and the program-schema bump**, owed since D17.
* **The eight stale classifier-2 literals**, now eight items stale.
* **`ambient_dir_list`'s sort mutant** — still blocked on any target driving an ambient
  directory read; the routed scenarios run on `RecordingWorld`.
* **The stray research file in `26e4d7c`**, if the record is to be tidied.

---

## Postscript

`2526ef0` — *"docs(009): apply D19 and D20 — compose is mediated, and the first caller
falsified a seam"* — independently re-derived and confirmed the central measurements before
applying them: compose at 11 ambient sources and 32 field calls; `run_native_call`'s if-chain
at `tool_runtime.ail:180`; the re-seating at `tool_phase.ail:365`; anchors green at
317/318/413; `declared_vs_performed` 40/0; yields unmoved. It also records the framing this
item argued for — **the seam fronts tool names, not subprocesses, which falsifies D16's
reasoning rather than being an implementation detail.**
