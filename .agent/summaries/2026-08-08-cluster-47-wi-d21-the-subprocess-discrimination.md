# 2026-08-08 Cluster 47: WI-D21 — the subprocess discrimination, and the identity class

## Context

Branch: `arniwesth/mot-82-wi-d20-route-b-part-2b-route-on_tool_handle` (unchanged — D20's
branch, carried).

Session span: `2a9d310` → **`a385517`**. Input was
`HANDOFF-execute-d21-the-subprocess-discrimination.md`, grounded against HEAD `2a9d310`
(`2026-08-08T11:42:28Z`). Pin **v0.33.0**. First command `11:44Z`, commit `12:47Z`,
**~1h05m** — between D19's 52m and D20's 1h13m, and the time went to *measurement* rather
than to edits, because this item routed nothing.

**A draft-and-stop, and the smallest diff in the cluster by a wide margin.** Fifteen files,
**477 insertions / 71 deletions**. Most of it is prose, and that is the deliverable rather
than a shortfall: the item's job was to decide, price and record.

```text
.agent/.../NOTE-d21-the-subprocess-discrimination.md  168 +- the record (312 at first commit,
                                                             then corrected — see §"I was wrong")
src/core/session.ail                                  100 +- the seam's capability, recorded AT the seam
src/core/dst_program.ail                               69 +  TWO executed rows: the rejected identity,
                                                             and the class that exempts it
packages/motoko-ext-abi/types.ail                      52 +  what the two strings ARE; the widening's
                                                             measured reason for staying deferred
packages/motoko-ext-compose/compose.ail                30 +- the framing correction
tools/predicate-anchors/anchors.sh                     21 +- re-baseline #4 + the law's real form
src/core/dst_driver_only.ail                           21 +- v18 -> v19, hash re-recorded
packages/motoko-ext-compose/author_tools.ail           19 +  the framing correction, `rg` half
src/core/dst_attribution_table.ail                     12 +- five rows + one test literal
{conformance,progress_guard,empty_stop_guard}          30 +- (_cmd,_cwd) -> (_tool,_args_json) ×3
src/core/dst_driver_plus_no_ops.ail                    10 +- v5 -> v6
scripts/dst/attribution_table_dst.ail                   2 +- the `omitted_site` literal
```

| Definition-of-done item | State |
|---|---|
| The seam's true capability recorded at the seam | **met** — and it corrects the handoff as well as D19/D20 |
| Rename or re-document `proc_exec`'s `name` parameter | **met** — and the misreading was five bindings, not two items |
| The identity-class decision taken, with the `absent_classes` consequence stated either way | **met** — `ExtensionEffectIdentity`; pin untouched, D19's ground reported as not holding |
| The end-to-end price, link by link, with a one-item-or-bump recommendation | **met** — seven links, link 6 blocks, bump unavoidable |
| If it is one item, build it | **NOT built, deliberately** — stop condition 1 fired |
| S29: audit the path's arms before routing | **n/a — nothing was routed** |
| S13/S9/S17/S26/S28 process rules | **`sync_packages` first (18th consecutive). One new failure mode — see below** |
| Anchor cascade, priced | **FIRED, from a comment, and it falsifies both published forms of the law** |
| Yields 4 of 15 and 5 of 15 | **met — unmoved, and they had to be** |

---

## The mission result: the decision was not the choice the handoff described

The handoff asked *"which identity class does an extension's subprocess belong to?"* and
framed it as a choice between two live options.

**It is not a choice.** `session.ail`'s `proc_exec` bridge sets `call.id = ""`;
`recording_tool` records `ToolIdentity("loop_v2", inv.call.id, inv.call.tool)`; and
`dst_program.validate_identity:277` rejects a blank `ToolIdentity` call id with
`IdentityComponentMissing`. **The first extension to call the seam in a recorded run makes the
recorder emit a program its own validator refuses.**

`ToolIdentity` is wrong twice over: the blank call id, and the hardcoded `"loop_v2"` origin,
which names the driver's loop as the producer and is false for an extension-initiated
dispatch. `ExtensionEffectIdentity` is the one class D2 exempts from the call-id rule —
*"the only place a blank component is legitimate rather than a missing required value"*.

**Decision: `ExtensionEffectIdentity`.** Taken on D2's own rules rather than on preference.

---

## I WAS WRONG ONCE, IN THE ITEM'S CENTRAL SECTION, AND THE CORRECTION IS THE BETTER FINDING

The first draft of §5.2 gave two reasons the class was unreachable and called both
**structural**. Both failed on measurement, and the way they failed is the same mistake the
item was convened to correct in D19 and D20 — **a capability inferred from the nearest
accessor instead of read off the thing itself**, one layer down.

* **"A7 declares no process-failure class."** False. A7 declares **eleven**
  (`dst_fault_catalogue.ail:821` asserts the count); I had read the seven `fault_class_*`
  accessor functions and taken them for the catalogue. Row eleven is
  **`extension_effect_fault`**, and **its own coverage-gap entry (`:442`) has named
  `ExtPorts.proc_exec` since WI-C5.** The class id this seam needs was written down before the
  item existed.
* **"The bridge cannot name its caller."** Too strong. `ExtensionHooks.id` is on every entry
  of the registry the dispatcher folds over. `ext_ports_of` builds one `ExtPorts` per step and
  shares it, and `ExtCtx` carries no `ext_id` — a **threading gap**, closable by per-extension
  ports or an `ext_id` on `ExtCtx`.

**The actual reason the class reads zero:** all seven `record_interaction` call sites are in
`ports.ail` and **not one constructs `ExtensionEffectIdentity`**. Same for `RandomDrawIdentity`.
Routing this seam means building an **eighth recording adapter**, not relabelling a seventh.

The error is recorded in the note rather than quietly fixed, because the corrected version is
what the next item needs and the shape of the mistake is the item's own subject.

---

## The `absent_classes` pin: untouched, and D19's ground does not hold

WI-D19 pinned `ExtensionEffect` at literal zero calling its unreachability **structural**, and
used that word to distinguish it from the three filesystem classes it chose to *witness*
rather than remove. The handoff asked for the distinction to be **re-asked rather than
inherited**.

**Re-asked; it does not survive.** Nothing about the bridge or the catalogue makes the class
unreachable — two closable gaps and one unbuilt adapter.

**Zero is still the correct expectation, so the pin is right and the reason on record is
wrong.** Per the stop condition — *"stop before changing the pin; D19 put it there on a stated
ground and the ground would be what changed"* — the pin is **not touched** and the ground is
reported. Re-wording `absent_classes` in place would destroy the evidence that D19's
justification was measured and found wanting.

**What would move it:** an item that threads an `ext_id` and builds the eighth adapter. The
catalogue row it would name already exists.

---

## The framing correction, in both directions

D19/D20 concluded *"the seam does not front subprocesses; it fronts Motoko's own tool names"*
— true about what it fronts, and it produced the wrong menu. Verified link by link at HEAD:
`proc_exec(w, "BashExec", args)` → `world_tool` → `dispatch_one` → `run_native_call` →
`run_process_result` → `exec`. **A real subprocess, and a real exit code, arriving as JSON text
in `ExtProcOutcome.output`. The data is not lost; the TYPE is.**

**The handoff understated it.** `run_process_result` wraps shell-tokened commands in
`bash -lc`, so the seam reaches **arbitrary command lines**. All four ambient `exec` sites —
two `ailang`, one `rg`, one dispatcher — are reachable today. The seam is not narrow; it is
untyped.

**The handoff overstated one thing, and it matters.** It claimed the two adapters *"cannot
agree on a widened `ExtProcOutcome`, which is D1's stop condition"*. They already agree — **on
a string**. `ToolCompleted.content` is a string on both sides and a `ScriptedTool` can carry
the same JSON. The disagreement appears **only under typing**, which is a weaker claim.
**D1 is not falsified; B2b's stop condition did not fire.**

---

## The price: seven links, and link 6 blocks

| # | Link | Cost |
|---|---|---|
| 1 | `ExtProcOutcome` | +1 field; 1 ABI row, 4 in-tree bindings, 0 external consumers |
| 2 | `ToolOutcome.ToolCompleted` | +1 field; 4 match arms, 4 construction sites |
| 3 | `world_tool` | derive the code on both arms |
| 4 | `dispatch_one` | **the link the handoff did not name** — its `(ToolCall) -> string` contract serves upstream `runTools` |
| 5 | `ScriptedTool` | +1 field, six construction/codec sites |
| 6 | `encode`/`decode_tool_outcome` | **BLOCKS** |
| 7 | `dst_replay.tools_of` | follows 5 and 6 |

**Why 6 blocks:** an `exit_code` added to the persisted payload is absent from every existing
artifact and decodes to its default. `0` means success, so **a recorded run in which
`ailang check` failed replays as one in which it passed, with every count balanced.**
`dst_persistence:278` refuses only *unknown* schema versions, and the version would be
unchanged. **`program_schema_version()` must go to `execution-program/2`.**

One road avoids it — decode absence as `-1` = "predates exit-code recording" — at the cost of a
**third state** in every consumer including `world_tool`. Named, not recommended.

**Recommendation: one item, and the schema bump IS the item.** It now has its **second
consumer** (`InitialWorld.files`, owed since D17), which per S23 is the threshold to schedule.

---

## The rename: five bindings, two incompatible readings

| Site | Read as |
|---|---|
| `session.ail` bridge | `(name, args)` — correct |
| `motoko_ext_conformance/harness.ail` | `(_cmd, _cwd)` |
| `motoko-ext-progress-contract-guard` | `(_cmd, _cwd)` |
| `motoko-ext-empty-stop-guard` | `(_cmd, _cwd)` |
| the ABI row | `(ExtWorld, string, string)` — **documented neither** |

The noops ignore both arguments, so nothing is broken — but **a conformance harness is a
template**, and an implementation written from a `(cmd, cwd)` signature shells out the tool
name in a directory named by a JSON blob. It compiles. **Silent-wrong site #75.**

Now `(tool, args_json)` at all four implementation sites, with the ABI row stating what the
strings are. **The field name `proc_exec` is itself the cause** — it says "execute a process"
and the seam dispatches a tool — and is priced but left for the schema-bump item, since it is
a break to a published ABI at `5.0` and splitting it spends the break twice.

---

## THE ANCHOR CASCADE FIRED FROM A COMMENT

**WI-D18's law:** every Route B *surface* item re-baselines.
**WI-D20's exception:** a non-surface item does too, if it needs a driver-side codec.

**This item added no seam, no import and no expression.** It wrote a comment block inside
`ext_ports_of`'s `proc_exec` closure, and all five `session.ail` clock anchors moved **+96**:
965/1224/1330/2775/2885 → **1061/1320/1426/2871/2981**.

**Both published forms of the law are too narrow. ANY EDIT TO `ext_ports_of`, PROSE INCLUDED,
re-issues both profiles.** An item whose entire deliverable is documentation pays the full
cascade — the cheapest possible demonstration, which is why it is recorded as the law rather
than as a third exception.

**Six files, not nine.** All five anchored expressions compared to `git show HEAD:` character
by character and byte-identical. `driver_only` **18 → 19**, `no_ops` **5 → 6**, hash
`5f000167…` → `c007fb3e…`, `source_revision` unchanged at `c0fbf10`. **The three `*_dst.ail`
discovered-site fixtures were NOT touched** — they carry `tool_phase.ail:318`, which did not
move. **Nine is the price of a `tool_phase` move; a `session.ail`-only move is six.**

---

## A NEW PROCESS FAILURE, AND IT IS NOT D19'S OR D20'S

Three `make dst` runs; only the third counts. **Neither loss was the "edited during an
instrument" failure D19 and D20 hit.**

1. **`make -k dst 2>&1 | tail -80`.** `tail` buffers until the pipe closes, so the log retained
   only the last 80 lines and **the failing sub-target's output was discarded entirely** — the
   run reported nothing but the aggregate `Makefile:199` error, which names no target.
   **Never pipe a sweep through `tail`; redirect to a file.**
2. **The first honest sweep found the cascade**, whose repair required source edits, which
   invalidated it. Unavoidable and correctly sequenced.

**Final sweep is at baseline:** only `test_coverage_selftest` and `test_coverage`, whose files
(`src/core/prompts*.ail`, `tools/test_coverage/`) are **untouched since `2a9d310`** — verified
by an empty `git diff` over those paths. Same symptom D20 recorded. `declared_vs_performed`
**40 passed, 0 failed**. `attribution_table`, `driver_only`, `driver_plus_no_ops`,
`profile_definition`, `execution_program` all green after the re-baseline.

---

## Concurrency: the tree moved during the sweep

Three commits landed from **concurrent work on project 010** while `make dst` was running:
`83de84f`, `9de51d7`, and `9af0e40` — the last of which **committed an earlier 312-line draft
of this item's note** along with a `PLAN-implementation-deterministic-test-world.md` this
session did not write.

**`git diff --name-only 2a9d310 HEAD -- src/ packages/ scripts/ tools/ Makefile` is empty**, so
no code moved and the sweep stands. `.agent/projects/010_.../ADR-001-…` was left uncommitted
because it is not this item's.

---

## The counts

| | |
|---|---|
| Silent-wrong sites | **75** across forty-three runs (+1: `proc_exec`'s two positional strings) |
| Rows measuring less than their labels | **a separate counter, starting at 6** — see below |
| Bindings | 5 decided, 7 discovered |
| Compose ambient sources | **11, unchanged** (4 `println`, 3 registration, 1 ambient AI, 3 `exec`) |

**On the handoff's question — do "rows measuring less than their labels" belong in the 75?
No.** The 75 counts **production sites where two answers type-check and the wrong one ships
silently**; a weak row ships nothing wrong, its evidence is merely thinner than advertised.
They share a cause and differ in consequence, which is what a count is for. Merging them
destroys what the number answers. **Separate counter, starting at six** (D18 §5, D19 §8,
D20 §8 ×3, and this item's §4 control clause, written specifically to avoid becoming one).

## The yields

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |
| door-3 residue | `intToFloat, show` | **unchanged** |

**Unmoved, and they had to be.** The item routed nothing. A moved yield would have meant an
instrument was reading something other than what it claims to.

---

## What the next item should know

1. **THE SEAM'S CAPABILITY IS NOW AT THE SEAM** (`session.ail`'s `proc_exec` closure). Both
   compose notes point at it instead of restating it. Three items have now inferred this seam's
   behaviour from the wrong place; read it there.
2. **DO NOT ADD A FIELD TO A PERSISTED PAYLOAD WITHOUT MOVING THE SCHEMA VERSION.**
   `decode_tool_outcome`'s defaults make absence indistinguishable from a recorded value, and
   `dst_persistence`'s loud refusal only fires on a version it does not know.
3. **THE SCHEMA BUMP HAS TWO CONSUMERS** — `InitialWorld.files` and `ScriptedTool.exit_code`.
   Per S23, schedule it. Take the `proc_exec` **field** rename in the same item.
4. **A BLANK COMPONENT IS A REJECTION, NOT A PLACEHOLDER.** A seam with no natural value for a
   required identity component is a seam in the wrong class — a design finding, not formatting.
5. **"STRUCTURAL UNREACHABILITY" NEEDS ITS REASON WRITTEN DOWN.** D19's word was wrong and its
   ground was never stated, so this item had to re-derive it before it could decide whether to
   move a pin. Any future pin justified as "structural" should name the shape facts.
6. **CHECK THE CATALOGUE, NOT ITS ACCESSORS.** `fault_class_*` covers seven of eleven rows.
   This item got that wrong first and it nearly became a published conclusion.
7. **NEVER PIPE A SWEEP THROUGH `tail`.** It discards exactly the output you need.
8. **`on_pre_step` and `on_solver_candidate` are still unaudited**, successor-drop base rate
   still **2 of 2**. This item routed nothing and added no evidence either way.
