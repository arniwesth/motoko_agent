# WI-D21 — the subprocess discrimination, and why it is not an ABI question

**Result: the decision is TAKEN, the build is a DRAFT-AND-STOP, and two of the handoff's three stop
conditions fired.** What shipped is the seam's true capability recorded at the seam, the parameter
rename, and two executed rows that convert this item's central finding from a paragraph into an
assertion. What did not ship is the typed discrimination, which cannot reach `ScriptedTool` without a
program-schema version bump, and the `absent_classes` pin, which **stays** — on a ground WI-D19 did not
state.

---

## 0. THE HEADLINE, BECAUSE IT CHANGES WHAT THE NEXT ITEM ASKS

The handoff asked: *"which identity class does an extension's subprocess belong to?"* and expected the
answer to be a choice between two live classes.

**It is not a choice. The seam as built produces a program its own validator REJECTS, and only one
class can hold it — and that class cannot be constructed from this bridge.** Both halves are measured
below and both are asserted in the tree.

---

## 1. The git wall-clock window

Handoff commit `2a9d310` at `2026-08-08T11:42:28Z`. First edit at ~`11:56Z`, sweep and commit closing
the item. **The window is ~1h05m**, against D19's ~52m and D20's ~1h13m.

The item ran short of D20 because **it did not route anything**, and it ran long of a pure analysis item
because §4's finding was not in the handoff and had to be chased into four modules.

---

## 2. THE INHERITED FRAMING, CORRECTED — AND THE CORRECTION IS SMALLER AND SHARPER THAN THE HANDOFF'S

The handoff's correction is right and it understates one thing and overstates another.

**RIGHT, and verified link by link at HEAD rather than grepped:**

| Step | What is there |
|---|---|
| `session.ail:958` | the bridge sets `call.tool = tool` — a Motoko tool name, not a binary |
| `ports.ail:1264` | `world_tool`, on an EMPTY `state.tools`, delegates to `dispatch_one` |
| `tool_dispatch_adapter.ail:174` | `dispatch_one` -> `run_native_batch` |
| `tool_runtime.ail:175` | `else if call.tool == "BashExec" then run_process_result(…)` |
| `tool_runtime.ail:896` | `run_process_result` calls `exec` — **a real subprocess** |
| `tool_runtime.ail:842` | `to_bash_result` builds `BashExecResult { …, exit_code, … }` |
| `tool_dispatch_adapter.ail:178` | `encode(tool_result_item_to_json(r))` — the exit code survives, as JSON text |

So `proc_exec(w, "BashExec", args)` runs a subprocess and produces a real exit code. **The data is not
lost; the TYPE is.**

**WHAT THE HANDOFF UNDERSTATED.** `run_process_result` wraps shell-tokened commands in `bash -lc`
(`tool_runtime.ail:885-895`), so the seam reaches **arbitrary command lines**, not only bare binaries.
Every one of the four ambient `exec` sites — `ailang check`, `ailang run`, `rg`, and the dispatcher's
`ailang check` — is reachable through it today. The seam is not narrow. It is untyped.

**WHAT THE HANDOFF OVERSTATED, and it matters for the price.** The handoff says the two adapters
*"cannot agree on a widened `ExtProcOutcome`, which is D1's stop condition"*. They can agree, and they
already do — **on a string**. `ToolCompleted.content` is a string on both sides, the live path puts
`BashExecResult`'s JSON in it, and a `ScriptedTool` can put the identical JSON in it. Nothing is
unrepresentable.

**The disagreement appears only when the discrimination is TYPED**, which is a different and weaker
claim than D1's stop condition, and it is the claim §3 prices. **D1 is not falsified.** B2b's stop
condition did not fire; the third one did.

---

## 3. THE END-TO-END PRICE, LINK BY LINK, AND THE ONE LINK THAT BLOCKS

A typed exit code has to travel from the live subprocess to a deterministic answer that reproduces it.
Seven links, each verified:

| # | Link | Cost |
|---|---|---|
| 1 | `ExtProcOutcome` (`types.ail:160`) | +1 field. **1 ABI row**, 4 in-tree bindings, 0 external consumers |
| 2 | `ToolOutcome.ToolCompleted` (`ports.ail:452`) | +1 field on a core sum variant; **14 match sites across 6 modules** |
| 3 | `world_tool` (`ports.ail:1264`) | must derive the code on BOTH arms |
| 4 | `dispatch_one` (`tool_dispatch_adapter.ail:174`) | **the link the handoff did not name.** Its `(ToolCall) -> string` contract exists to satisfy upstream `runTools`. Either it gains a typed sibling or `world_tool` parses its JSON — and parsing here is the same string-parsing path one layer down |
| 5 | `ScriptedTool` (`ports.ail:418`) | +1 field; constructed at `ports.ail:1701`, four arms of `decode_tool_outcome`, `dst_replay.ail:1053`, and both directions of `ext_world`'s JSON |
| 6 | `encode_tool_outcome` / `decode_tool_outcome` (`ports.ail:1970`, `:1994`) | **THE BLOCKING LINK** — see below |
| 7 | `dst_replay.tools_of:698` | reconstitutes `ScriptedTool` from the log; follows 5 and 6 |

### 3.1 Why link 6 blocks, stated as the failure it produces

`decode_tool_outcome` reads the persisted payload with `str_field(root, "<name>", <default>)`. An
`exit_code` field added to the encoder is **absent from every artifact already recorded**, and absent
decodes to the default. Whatever default is chosen, `0` means success:

> **A recorded run in which `ailang check` failed replays as a run in which it passed, and every count
> balances.**

`dst_persistence:278` refuses an unknown schema version loudly — but the version would be unchanged, so
it refuses nothing. **D8 forbids exactly this silent reinterpretation.** So
`program_schema_version()` must go to `execution-program/2`.

### 3.2 The one road that avoids the bump, and why it is not free

Encode `exit_code` only when known and decode absence as `-1` = *"this artifact predates exit-code
recording"*. Old artifacts then decode honestly instead of wrongly, and no version moves.

It costs a **third state** in every consumer of the field, including `world_tool`, which must decide
what a deterministic run does when the script cannot say whether the tool succeeded. That is
manufacturing a state to avoid versioning, in a tree whose whole discipline is the opposite. **Named,
not recommended.**

### 3.3 The recommendation

**One item, and the schema bump is the item.** Links 1–5 and 7 are mechanical once 6 is decided;
deciding 6 is the whole content. Attempting it as a widening that "just adds a field" produces §3.1.

**AND IT NOW HAS ITS SECOND CONSUMER, WHICH PER S23 IS THE THRESHOLD.** `InitialWorld` (`dst_program.ail:76`)
carries `messages_and_policy`, `synthetic_environment`, `clock_epoch`, `extension_profile` — **no
`files`** — so `world_state_of` reconstitutes `files: []` (stated at `ports.ail:1389`) and D17/D18 have
owed the field since. `ScriptedTool.exit_code` is the second. **A deferred change with two consumers
should be scheduled**, and this is the answer to two questions rather than one.

---

## 4. THE FINDING THE HANDOFF DID NOT HAVE: THE SEAM ALREADY EMITS A REJECTED PROGRAM

**`session.ail`'s bridge sets `call.id = ""`.** `recording_tool` (`ports.ail:1540`) then records
`ToolIdentity("loop_v2", inv.call.id, inv.call.tool)`. And:

```
dst_program.ail:277
  ToolIdentity(origin, call_id, name) =>
    … ++ (if blank(call_id) then [IdentityComponentMissing(o, "tool call_id")] else []) ++ …
```

**The first extension to call `proc_exec` in a recorded run makes the recorder emit a program its own
validator refuses.** Nothing calls it today, so it is latent — which is precisely why it needed an
assertion rather than a sentence.

**Asserted, in `dst_program.ail`:**

* `test_the_ext_proc_exec_invocation_shape_records_a_rejected_tool_identity` — the bridge's identity,
  verbatim, produces exactly one `program-identity-component-missing`; a driver-issued dispatch with a
  real call id produces none. The second clause is the control: the row fails for the blank, not for
  the shape of the fixture.
* `test_the_extension_effect_class_exempts_the_call_id_and_requires_the_two_the_bridge_lacks` — the
  other half, so that "the class exists but is unreachable" is measured. It goes from two rejections to
  none the day someone builds the `ext_id` and the catalogue row.

Both pass.

---

## 5. THE IDENTITY-CLASS DECISION, AND WHAT `absent_classes` SAYS AFTERWARDS

### 5.1 The decision

**`ExtensionEffectIdentity`.** Not on preference — on two of D2's own rules, both of which `ToolIdentity`
breaks for this seam:

* **The call id.** The effect genuinely has none, and `ExtensionEffectIdentity` is the *only* class where
  a blank one is legitimate — `dst_interaction.ail:56-58`, enforced by `validate_identity` exempting
  `_call_id` at `:283`. Under `ToolIdentity` it is a rejection (§4).
* **The origin.** `recording_tool` hardcodes `"loop_v2"`, which names the driver's loop as the producer.
  For an extension-initiated dispatch **that is false**, and D2 gives an origin only to the three classes
  that answer a named producer's request.

So the plumbing's current answer is wrong twice, and the handoff's framing of the consequence — *"routing
compose's `ailang check` puts a compiler invocation into the run's tool-dispatch census"* — is real but
is the second-order problem. The first-order one is that the interaction is invalid.

### 5.2 And it is NOT REACHABLE, for two structural reasons

Neither is "nothing calls it yet":

1. **THE BRIDGE CANNOT NAME ITS CALLER.** `ext_ports_of(p, world, base_url)` builds ONE `ExtPorts` per
   step and hands the same record to every extension; `ExtCtx` (`types.ail:421`) carries no `ext_id`.
   `validate_identity:284` rejects a blank `ext_id`. The class cannot be constructed from here at all.
2. **THE CATALOGUE HAS NO CLASS TO NAME.** `validate_static_references:426` requires a non-blank
   `class_id` to be a catalogue row; `validate_identity:285` rejects a blank one. A7 declares **seven** —
   `ToolFailed`, `ToolCorrelationMismatch`, `ToolDeadlineExceeded` and four provider classes. **There is
   no process-failure class.**

### 5.3 THE PIN STAYS — AND D19'S WORD SURVIVES ON A GROUND D19 DID NOT STATE

WI-D19 pinned `ExtensionEffect` at literal zero in `dst_discovery.absent_classes:447` calling its
unreachability **structural**, and used that distinction to justify witnessing the three filesystem
classes instead of removing them. The handoff asked for that distinction to be **re-asked rather than
inherited**, and warned that an `ExtensionEffectIdentity` answer would move the pin.

**Re-asked. It survives, and the pin is not touched.** §5.2 is what "structural" means for this class:
two shape facts about the bridge and the catalogue, not an unbuilt caller. D19's word was correct; D19's
*reason* was never written down, and it is written down now.

**What would move it:** an item that gives `ExtCtx` an `ext_id` **and** adds a process-failure class to
A7. Either alone is insufficient. When both land, `absent_classes` must take a witness the way D19's
three filesystem classes did, and `class_balance(…, 0, …)` becomes a real balance.

---

## 6. `proc_exec`'s PARAMETERS — RENAMED, AND THE MISREADING WAS WORSE THAN "TWO ITEMS"

The handoff said two items misread the `name` parameter. **Measured: five bindings in the tree, reading
the two positional strings TWO INCOMPATIBLE WAYS.**

| Site | Read as |
|---|---|
| `session.ail` bridge | `(name, args)` — correct |
| `motoko_ext_conformance/harness.ail:41` | `(_cmd, _cwd)` |
| `motoko-ext-progress-contract-guard:145` | `(_cmd, _cwd)` |
| `motoko-ext-empty-stop-guard:61` | `(_cmd, _cwd)` |
| ABI row `types.ail:292` | `(ExtWorld, string, string)` — **documented neither** |

**THIS IS A SITE THAT ADMITS TWO TYPE-CHECKING ANSWERS WITH A SILENT WRONG ONE.** The three noops ignore
both arguments, so nothing is broken today — but a conformance harness is a **template**, and an
implementation written from a `(cmd, cwd)` signature shells out the tool name in a directory named by a
JSON blob. It compiles. It is wired backwards. Both are `string` and no type tells them apart.

**Renamed to `(tool, args_json)` at all four implementation sites, and the ABI row now says what the two
strings are** — the row is where the reading is decided, and positional strings cannot carry it.

**THE FIELD NAME `proc_exec` IS ITSELF THE CAUSE AND IS NOT CHANGED.** It says "execute a process"; the
seam dispatches a tool, and that is what sent two items looking for a subprocess seam. The rename is a
four-site edit in-tree with zero external consumers — cheap — and a breaking change to a **published ABI
at 5.0**. It is priced and left **beside §3's widening, for the item that takes the schema bump**: they
are the same conversation, and splitting them spends the break twice.

---

## 7. WHAT DID NOT SHIP, AND WHICH STOP CONDITION FIRED

| Handoff stop condition | Fired? |
|---|---|
| typed discrimination needs a program-schema bump -> draft and stop | **YES** — §3.1. Two consumers, scheduled |
| identity answer moves `ExtensionEffect` out of `absent_classes` -> stop before changing the pin | **YES in the answer, NO in the consequence** — §5.3. The answer is `ExtensionEffectIdentity`; the pin stays and is untouched |
| the two adapters still cannot agree after the widening -> falsifies D1 | **NO** — §2. They agree on a string today; the disagreement is only under typing |

Also not done, and deliberately: **the four `exec` sites are not routed.** They are the beneficiaries of
§3, not of this item.

---

## 8. RECORDED BINDINGS: DECIDED VERSUS DISCOVERED

**Decided:**

1. The identity class is `ExtensionEffectIdentity` (§5.1).
2. The `absent_classes` pin stays, and D19's "structural" is re-grounded rather than inherited (§5.3).
3. The typed discrimination is one item, and that item is the schema bump (§3.3).
4. `proc_exec`'s parameters are `(tool, args_json)`; the field name is priced and deferred to the schema-bump item (§6).
5. The blank call id is asserted, not repaired — repairing it *is* decision 1, which is blocked (§4).

**Discovered:**

6. `run_process_result` wraps in `bash -lc`, so the seam reaches arbitrary command lines (§2).
7. `dispatch_one`'s `(ToolCall) -> string` contract is a seventh link the handoff's chain did not name (§3, link 4).
8. `session.ail`'s bridge hardcodes `workdir: "."` and `timeout_ms: 0`. A routed subprocess runs where
   the process started, not where the extension thinks it is, and **this seam can never produce
   `ToolDeadlineExceeded`.** Recorded at the site.
9. The `_cmd, _cwd` misreading is in three packages, not two items (§6).
10. There is no process-failure class in A7's catalogue at all (§5.2).

---

## 9. THE SILENT-WRONG COUNT, AND THE QUESTION THE HANDOFF ASKED ABOUT IT

**One new site: `proc_exec`'s two positional strings (§6). The running total is 75 across
forty-three runs.**

**And the handoff's question — do "rows that measure less than their labels" belong in that count?
NO, and they need their own counter.** They are a different failure mode and merging them would destroy
what the number answers:

* The 75 count is **production sites where two answers type-check and the wrong one ships silently**. It
  answers "how many latent defects of this shape has the project found".
* A row measuring less than its label is **an instrument weaker than its claim**. Nothing ships wrong;
  the evidence is thinner than advertised.

They share a cause — a type that does not distinguish — and they differ in consequence, which is what a
count is for. **Four consecutive items have now hit the second shape (D18 §5, D19 §8, D20 §8 ×3, and
this item's §4 control clause is written specifically to avoid becoming one).** That is a real trend
and it deserves to be counted, separately, starting at **six**.

---

## 10. THE YIELDS

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope_selftest` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |
| door-3 residue | `intToFloat, show` | **unchanged** |

**Unmoved, and they had to be:** this item routed nothing. Compose stays at **11 ambient sources** — the
four `println`, three registration, one ambient AI, three `std/process.exec`. A yield that had moved
would have meant an instrument was reading something other than what it claims to.

---

## 11. WHAT THE NEXT ITEM SHOULD KNOW

1. **THE SEAM'S CAPABILITY IS NOW RECORDED AT THE SEAM** (`session.ail`'s `proc_exec` closure), not in
   two extension comments. Read it there. Both compose notes now point at it instead of restating it.
2. **DO NOT ADD A FIELD TO A PERSISTED PAYLOAD WITHOUT MOVING THE SCHEMA VERSION.** §3.1 is the general
   form: `decode_tool_outcome`'s defaults make absence indistinguishable from a recorded value, and
   `dst_persistence`'s loud refusal only fires on a version it does not know.
3. **THE SCHEMA BUMP NOW HAS TWO CONSUMERS** — `InitialWorld.files` and `ScriptedTool.exit_code`. Per
   S23 it should be scheduled. Take the `proc_exec` field rename in the same item (§6).
4. **A BLANK COMPONENT IS A REJECTION, NOT A PLACEHOLDER.** §4. `validate_identity` is strict on every
   class but one, and a seam that has no natural value for a required component is a seam in the wrong
   class — which is a design finding, not a formatting one.
5. **"STRUCTURAL UNREACHABILITY" NEEDS ITS REASON WRITTEN DOWN.** §5.3. D19's word was right and its
   ground was never stated, so this item had to re-derive it before it could decide whether to move a
   pin. Any future pin justified as "structural" should name the two or three shape facts that make it so.
6. **`on_pre_step` and `on_solver_candidate` are still unaudited** and the successor-drop base rate is
   **2 of 2**. This item routed nothing, so it added no evidence either way.
