# WI-D21 — the subprocess discrimination, and why it is not an ABI question

**Result: the decision is TAKEN, the build is a DRAFT-AND-STOP, and two of the handoff's three stop
conditions fired.** What shipped is the seam's true capability recorded at the seam, the parameter
rename, and two executed rows that convert this item's central finding from a paragraph into an
assertion. What did not ship is the typed discrimination, which cannot reach `ScriptedTool` without a
program-schema version bump, and the `absent_classes` pin, which is **left untouched** — while WI-D19's
stated ground for it turns out not to hold.

---

## 0. THE HEADLINE, BECAUSE IT CHANGES WHAT THE NEXT ITEM ASKS

The handoff asked: *"which identity class does an extension's subprocess belong to?"* and expected the
answer to be a choice between two live classes.

**It is not a choice. The seam as built produces a program its own validator REJECTS, and exactly one
class can legitimately hold it.** Both halves are measured below and both are asserted in the tree.

**And the second thing the item was asked to check did not survive.** WI-D19 pinned `ExtensionEffect`
at literal zero calling its unreachability STRUCTURAL. Measured, it is not: the catalogue row the class
needs already exists and names this seam, the `ext_id` exists at every dispatch site, and the real
reason the count is zero is that **no adapter records the class at all**. The pin is correct and its
published reason is wrong — reported rather than re-worded, per the handoff's stop condition.

---

## 1. The git wall-clock window

Handoff commit `2a9d310` at `2026-08-08T11:42:28Z`; commit closing the item at ~`12:45Z`. **The window
is ~1h03m**, against D19's ~52m and D20's ~1h13m.

**Three `make dst` runs fit inside it and only the third counts** (§11.2). The item routed nothing, so
the time went to measurement rather than to edits: §4's finding was not in the handoff and had to be
chased into four modules, and §5.2 had to be measured twice because the first draft inferred the
catalogue's contents from its accessor functions.

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
| 2 | `ToolOutcome.ToolCompleted` (`ports.ail:452`) | +1 field on a core sum variant; **4 match arms and 4 construction sites across 4 modules** (`ports` ×2+×3, `session:821`, `tool_phase:277`, `dst_replay:958`), plus the class-id literal in `dst_fault_catalogue:302` |
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

**WHAT IS NEW HERE IS THE CONNECTION, NOT THE RULE, and the distinction is worth keeping honest.**
`execution_program_dst` already exercises *"program-identity-component-missing <- tool interaction has a
blank call_id"*, so the validator's behaviour was tested. What nothing tested is that **`ExtPorts`'
`proc_exec` bridge is a construction site for exactly that shape**. The row below is that link.

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

### 5.2 What stands between the seam and the class is PLUMBING, not shape

**I drafted this section with two "structural" reasons and both were wrong. The corrected measurement is
the more useful finding, so the error is recorded rather than quietly fixed** — it is the same mistake
D19 and D20 made about the seam, made once more one layer down: a capability inferred from the nearest
accessor instead of read off the thing itself.

* **THE CLASS ID ALREADY EXISTS.** I wrote that A7 declares seven classes. It declares **eleven**
  (`dst_fault_catalogue.ail:821` asserts the count) — the `fault_class_*` accessor functions are a
  SUBSET, and reading them for the catalogue is the error. Row eleven is **`extension_effect_fault`**
  (`:405`), a member of `required_class_ids()`, so `validate_static_references:426` accepts it.
  **And its own coverage-gap entry (`:442`) already names this exact seam:** *"ExtPorts.proc_exec IS
  routed but projects the typed tool outcome back down to a string, so an extension can observe that a
  tool failed and not which fault class it was."* The catalogue has been describing this item's finding
  since WI-C5.
* **THE EXT ID EXISTS AT THE DISPATCH SITE.** `ExtensionHooks.id` (`types.ail:641`) is on every entry of
  the registry the dispatcher folds over. `ext_ports_of` builds ONE `ExtPorts` per step and shares it,
  and `ExtCtx` carries no `ext_id`, so this closure cannot name its caller and `validate_identity:284`
  rejects a blank one. **That is a threading gap** — per-extension ports, or an `ext_id` on `ExtCtx`,
  closes it.

**THE ACTUAL REASON THE CLASS READS ZERO:** all **seven** `record_interaction` call sites are in
`ports.ail` and **not one constructs `ExtensionEffectIdentity`**. The same is true of
`RandomDrawIdentity`. Routing this seam to the class means building an **eighth recording adapter**, not
relabelling a seventh.

### 5.3 THE PIN IS UNTOUCHED AND D19'S STATED GROUND DOES NOT HOLD

WI-D19 pinned `ExtensionEffect` at literal zero in `dst_discovery.absent_classes:447`, calling its
unreachability **structural** — and used that word to distinguish it from the three filesystem classes
it chose to witness rather than remove. The handoff asked for the distinction to be **re-asked rather
than inherited**.

**Re-asked, and it does not survive.** Nothing about the bridge or the catalogue makes the class
unreachable; §5.2 is two closable gaps and one unbuilt adapter. **"No adapter records it" is nearer to
"nothing routes it yet" than to the contrast D19 drew.**

**Zero is still the correct expectation, so the pin is right and the reason on record is wrong.** Per
the handoff's stop condition — *"stop before changing the pin; D19 put it there on a stated ground and
the ground would be what changed"* — **the pin is not touched and the ground is reported.** Re-wording
`absent_classes` in place would destroy the evidence that D19's justification was measured and found
wanting, which is the thing the next item needs.

**What would move the pin:** an item that threads an `ext_id` and builds the eighth recording adapter.
The catalogue row it would name is already there. When that lands, `absent_classes` must take a witness
exactly the way D19's three filesystem classes did, and `class_balance(…, 0, …)` becomes a real balance.

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
| identity answer moves `ExtensionEffect` out of `absent_classes` -> stop before changing the pin | **YES, and harder than expected** — §5.3. The answer is `ExtensionEffectIdentity`, and D19's stated ground for the pin does not hold. Pin untouched, ground reported |
| the two adapters still cannot agree after the widening -> falsifies D1 | **NO** — §2. They agree on a string today; the disagreement is only under typing |

Also not done, and deliberately: **the four `exec` sites are not routed.** They are the beneficiaries of
§3, not of this item.

---

## 8. RECORDED BINDINGS: DECIDED VERSUS DISCOVERED

**Decided:**

1. The identity class is `ExtensionEffectIdentity` (§5.1).
2. The `absent_classes` pin is left untouched and D19's "structural" ground is reported as not holding,
   rather than re-worded in place (§5.3).
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
10. **A7's catalogue already declares `extension_effect_fault`, and its coverage-gap entry has named
    `ExtPorts.proc_exec` since WI-C5** (§5.2). The class this item was asked to consider was written
    down before the item existed.
11. **No `record_interaction` site constructs `ExtensionEffectIdentity` or `RandomDrawIdentity`** — all
    seven are in `ports.ail` and none does (§5.2). That, and not shape, is why both pin at zero.
12. **THE ANCHOR CASCADE FIRES ON A COMMENT-ONLY EDIT** (§11). Five `session.ail` clock anchors moved
    because this item inserted a comment block above them.

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

## 11. THE ANCHOR CASCADE FIRED FROM A COMMENT, WHICH FALSIFIES BOTH FORMS OF THE LAW

**WI-D18's law:** every Route B **surface** item re-baselines the anchors.
**WI-D20's exception:** a non-surface item does too, if it needs a driver-side codec.

**This item added no seam, no import and no expression.** It wrote a comment block inside
`ext_ports_of`'s `proc_exec` closure, and **all five `session.ail` clock anchors moved +96**:
965/1224/1330/2775/2885 -> **1061/1320/1426/2871/2981**.

**So the rule's real form is neither of the above: ANY EDIT TO `ext_ports_of`, PROSE INCLUDED,
re-baselines the list and re-issues both profiles.** An item whose entire deliverable is documentation
pays the full cascade — which is the cheapest possible demonstration, and the reason it is recorded as a
law rather than a third exception.

### 11.1 It cost SIX files, not nine — and which nine matters

All five anchored expressions were compared to `git show HEAD:` **character by character and are
byte-identical**, so no site changed identity, routing or attribution. Only the offset moved.

| # | File | What changed |
|---|---|---|
| 1 | `tools/predicate-anchors/anchors.sh` | the five-element loop |
| 2 | `src/core/dst_attribution_table.ail` | five rows + one test literal |
| 3 | `scripts/dst/attribution_table_dst.ail` | one literal (the `omitted_site` fixture) |
| 4 | `src/core/dst_driver_only.ail` | version **18 -> 19**, hash |
| 5 | `src/core/dst_driver_plus_no_ops.ail` | version **5 -> 6**, hash |
| 6 | — | *(the sixth is the second file's test literal, counted separately above)* |

`sha256:5f000167…` -> **`sha256:c007fb3e…`**; `source_revision` unchanged at `c0fbf10`, per D4's rule
that an anchor re-measurement is not a table re-binding.

**THE THREE `*_dst.ail` DISCOVERED-SITE FIXTURES WERE NOT TOUCHED**, and the handoff expected them to be.
They carry `tool_phase.ail:318`, which did not move. **Nine files is the price of a `tool_phase` move; a
`session.ail`-only move is six.** WI-D20 recorded nine because its move was in `tool_phase`; the
enumeration in `anchors.sh` is right and its scope needed saying.

### 11.2 And the sweep was lost twice before it was right

Both losses were mine and neither was the D19/D20 failure mode (editing during an instrument):

1. **`make -k dst 2>&1 | tail -80`.** `tail` buffers until the pipe closes, so the log kept only the last
   80 lines and **the failing sub-target's output was discarded** — the run reported nothing but the
   aggregate `Makefile:199` error. Re-run redirecting to a file. **Never pipe a sweep through `tail`.**
2. **The first honest sweep found the cascade**, which required source edits, which invalidated it.

Third run is the reported one, and it is at baseline.

---

## 12. WHAT THE NEXT ITEM SHOULD KNOW

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
