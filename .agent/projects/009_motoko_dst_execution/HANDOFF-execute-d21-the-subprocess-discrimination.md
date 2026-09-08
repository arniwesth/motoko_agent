# Handoff: WI-D21 — the subprocess discrimination, and why it is not an ABI question

Audience: a fresh session grounded against HEAD. **The decision WI-D19 and WI-D20 both named and both
declined**, each with the same sentence: *"the two live options are unchanged and neither is taken
here."* Twice-deferred with a reason is this project's signal to take it.

**Read first:** `NOTE-d20-…` §3, then follow `session.ail:879-889` down yourself. **The inherited
framing is incomplete and the correction changes what the item is.**

## Why now

Compose is at **11 ambient sources**, verified. Four are `println` (D16's option 3, disclosed), three
are registration's (structurally unroutable), one is ambient AI — **and three are `std/process.exec`,
the only remaining hook-reachable sources that could route and do not.** This is the last one.

## The inherited framing, corrected — and I read the path rather than grepping it (S28)

D19 and D20 concluded: *"the seam does not front subprocesses; it fronts Motoko's own tool names."*
**True about what it fronts, and it produces the wrong menu.** Measured end to end:

| Step | What is there |
|---|---|
| `session.ail:879-889` | the bridge sets `call.tool = name` — **`name` IS a Motoko tool name, not a binary** |
| `tool_runtime.ail:175` | `else if call.tool == "BashExec" then run_process_result("BashExec", …, parse_exec_from_args(args))` |
| `tool_runtime.ail:842-853` | `to_bash_result` builds `BashExecResult { cmd, stdout, stderr, **exit_code**, meta }` |
| `tool_dispatch_adapter.ail:178` | `encode(tool_result_item_to_json(r))` — **the exit code survives, as JSON text** |

**So `proc_exec(w, "BashExec", args)` already runs a subprocess and already produces a real exit code.**
The data is not lost. **The TYPE is.** A caller must decode a string and pull `exit_code` — the
string-parsing path D19 correctly refused, which would also put a tool-error blob and a genuine
compiler failure on one code path.

**This shrinks the menu the two reports left.** "A real subprocess seam beside `proc_exec`" would
duplicate `run_process_result` for a seam that already reaches it. **And the parameter is misnamed** —
`proc_exec(w, name, args)` reads as a binary and is a tool name, which is most of why two items read the
seam as broken rather than as miscalled.

## THE FINDING THAT DECIDES THE SHAPE OF THIS ITEM

**The deterministic half cannot answer the question the live half can.**

```
ScriptedTool = { tool_call_id, duration_ms, code, message, content }     -- ports.ail:418
ToolCompleted({ tool_call_id, content: string })                          -- ports.ail:452
```

**There is no exit code anywhere on the deterministic side.** So a nonzero exit has exactly two
representations today, and both are wrong:

- **`ToolFailed(code, message)`** — makes a compile error a **fault**. A7's catalogue declares no class
  for it, so this is D17 §7c's rejected arm verbatim: manufacture a class the catalogue lacks, or leave
  a fault uncountable by D11's counter.
- **`ToolCompleted` with a JSON blob in `content`** — the string-parsing path, one layer down.

**And a nonzero exit from `ailang check` is a NORMAL answer, not a failure** — it is the thing compose's
whole retry loop is built on. That is what makes both representations unacceptable rather than merely
inelegant.

**So the two adapters cannot agree on a widened `ExtProcOutcome`, which is D1's stop condition.** The
seam question was never an ABI question.

## What it actually costs, so the item can decide before building

The chain a typed discrimination has to travel, each link verified:

1. **`ExtProcOutcome`** — one ABI row. Its own comment already anticipated this: *"widening the ABI to
   carry the discrimination is a SECOND widening on a second ground — D1's part-3 typed-fault
   argument."*
2. **`ToolOutcome` / `ToolCompleted`** — a core sum, and `ToolCompleted` is matched in the driver, the
   recorder and the replay decoder.
3. **`ScriptedTool`** — the deterministic answer.
4. **`decode_tool_outcome` and `dst_replay.tools_of:698`** — `ScriptedTool` is **reconstituted from
   `ToolIdentity` interactions**, so a new field is a persisted-codec change and touches the recorded
   corpus.

**That is a core class change of D3's or D17's size, not a row.** Price it first; build it only if it
comes in at one item.

**And it gives the owed program-schema change its SECOND consumer.** `InitialWorld.files` has been owed
since D17 and D18 grew it a field before it was taken; `ScriptedTool`'s exit code is the second.
**Per S23, a deferred change with two consumers is one that should be scheduled** — so if this item
concludes the schema bump must happen, say that, because it is then the answer to two questions rather
than one.

## The decision this item owns, and it is the recording question

**Which identity class does an extension's subprocess belong to?**

**Today the plumbing answers `ToolIdentity`.** `ExtPorts.proc_exec` → `Ports.tool_exec` →
`recording_tool` → `ToolIdentity(origin, call_id, name)`. **So routing compose's `ailang check` puts a
compiler invocation into the run's tool-dispatch census, beside the model's own tool calls** — the
consequence D19 and D20 both named and neither priced.

**But D2 already has a class for exactly this.** `ExtensionEffectIdentity(ext_id, class_id, call_id)`,
whose own comment says the call id is `""` *"where the effect has none — the only place a blank
component is legitimate rather than a missing required value."*

**And here is the thing that makes it sharp: WI-D19 pinned `ExtensionEffect` at literal zero in
`dst_discovery.absent_classes`, on the ground that its unreachability is STRUCTURAL** rather than
"nothing calls it yet" — that being the distinction it used to justify witnessing the three filesystem
classes instead of removing them. **If an extension's subprocess is `ExtensionEffectIdentity`'s, then
"structural" is the wrong word and the pin has to move**, and the distinction D19 leaned on has to be
re-asked rather than inherited.

**Decide, and say what the tool-dispatch census means afterwards** — `w.tool_dispatches` is a witness
several gates read.

## Definition of done

**The seam's true capability recorded at the seam**, replacing the two reports' framing: it fronts tool
names, `BashExec` reaches a real subprocess, and the loss is the rendering rather than the dispatch.
**Rename or re-document `proc_exec`'s `name` parameter** — two items misread it, which is evidence
about the name.

**The identity-class decision taken, with the `absent_classes` consequence stated either way.**

**The end-to-end price of a typed discrimination**, link by link, with a recommendation on whether it
is one item or needs the program-schema bump first.

**If it is one item, build it**; the ABI is at fifteen rows and changing a row has never been the thing
this project defers — **cutting the release is**, and that stays deferred.

**Per S29 — audit before routing.** Two hook slots audited, two successor drops found, and `proc_exec`
threads through `tool_exec` and `recording_tool`. **If this item routes anything, walk that path's arms
first**; `on_pre_step` and `on_solver_candidate` are also still unaudited and the base rate is 2 of 2.

**Per S13/S9/S17/S26/S28** — `make sync_packages` first (seventeenth consecutive item); sweep cache-cold
with `AILANG_RELAX_MODULES=1` including dependents; restore mutants by `cp`; append to shared fixtures;
**and do not edit any tracked file while a long instrument runs** — D19 lost a sweep to concurrent runs
and **shipped a mutant in `df7fd26`** by committing mid-harness, D20 lost one to a comment-only edit.

**Expect the anchor cascade and price it.** D20 established the exception to D18's law: a non-surface
item re-baselines too if it needs a driver-side codec. **A moved anchor touches NINE files, three of
them `*_dst.ail` discovered-site fixtures whose failure reads like a real routing defect.**

## Out of scope

- **Routing the four `exec` sites**, unless the decision lands cheaply enough to carry them. They are
  the beneficiaries, not the mission.
- **Cutting the ABI major.** Fifteen rows, six items deferring it, unchanged.
- **`on_pre_step` / `on_solver_candidate` successor audits** — owed, real, and their own item.
- **The scratchpad loopback successor** (`tool_envelope_dispatch.ail:44`, still projecting `.decision`).
- **Door 3's producer** and the hook-scope promotion. Still parallel.
- **C5's compose-bearing profile.** No graded profile installs compose, which is why D19 had to build a
  scenario to make its own tripwires fire — that is a growing debt and it is not this item's.
- **The eight stale classifier-2 literals**, now nine items stale.
- Classifier 1's repair; the stdlib cache's producer; the gate-table State column; F3.

## Stop and report rather than deciding inline

- **If the typed discrimination cannot reach `ScriptedTool` without a program-schema version bump**,
  draft and stop. That is a re-attestation, it now has two consumers, and it deserves to be scheduled as
  its own item rather than absorbed.
- **If the identity-class answer moves `ExtensionEffect` out of `absent_classes`**, stop before changing
  the pin. D19 put it there on a stated ground and the ground would be what changed.
- **If the two adapters still cannot agree after the widening**, that falsifies D1 rather than the
  design — B2b's stop condition, and this is the first seam where the live half is richer than the
  deterministic one.

## Report back

Forty-fifth calibration run.

- **The git wall-clock window.** D19 ~52m, D20 ~1h13m.
- **The identity-class decision**, and what `absent_classes` says afterwards.
- **The end-to-end price**, and whether the schema bump is now unavoidable.
- **Whether `proc_exec`'s parameter was renamed**, and what it is called.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one — and what the running
  total is.** It stood at **74 across forty-two runs** and **neither D19 nor D20 stated a new one**,
  while both found rows measuring less than their labels. **Say whether those belong in the count**;
  four consecutive items have hit that shape and it is not obvious it is the same failure mode.
- **The yields**, which should still be 4 of 15 and 5 of 15 unless door 3 moved.
