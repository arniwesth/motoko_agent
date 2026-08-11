# WI-B2b execution report — the world token, and the pin it moved

Nineteenth calibration run, last of Milestone B's content. Written against HEAD `73e16fd`, branch
`arniwesth/mot-58-execute-wi-b2b`.

## Window

**~2h05m** wall-clock: `2026-08-04T18:57:14Z` → `2026-08-04T21:02Z`. Roughly a third was the design
question below, which had to be settled before a single site could be touched; the rest was the
cascade and eleven compiler-driven repair rounds.

**The grounding correction, and it is the fourth in a row.** The handoff says B2a's work is
"uncommitted: 79 source files plus `ailang.lock`, on `arniwesth/mot-57-execute-wi-b2-part-1`", and
says it is "stating what B2a's report stated plainly". B2a's report *was* accurate when written.
**It was committed afterwards, as `6e19764` ("Implemented") — 114 files, 79 of them `.ail`, including
`ailang.lock`** — and this session started on `arniwesth/mot-58-execute-wi-b2b` with a **clean tree**.
B1's handoff got this wrong about B1, B3's about B3, B2a's about B3, and this one about B2a. **The file
count has been right every single time; the commit state has been wrong every single time.** The rule
that would end this: *do not restate commit state in a handoff at all — say "confirm with
`git status`", because the next session must run it anyway.*

## The representation: an OPAQUE Json token, and the ABI could not have named the world

This is the item's central decided binding, and it was **forced, not preferred**.

`packages/motoko-ext-abi` imports `std/option` and `std/json` and nothing else. `motoko_core` depends
on the ABI, so **the ABI cannot name `src/core/ports.WorldState`** — the dependency cannot invert.
Three alternatives were measured and rejected:

1. **Inline it**, the idiom this ABI already uses for `Msg`, `ToolCall`, `ToolCallEnvelope` and
   `ToolResultEnvelope`. Those work because **AILANG unifies records STRUCTURALLY** — probed and
   confirmed: a differently-*named*, identically-shaped record unifies across modules. It does not
   extend, because **sums are NOMINAL** — the same probe gives
   `cannot unify type constructors: BStatus vs AStatus` for two identically-shaped sums — and
   `WorldState` transitively contains `IdentityBody`, `OutcomeStatus` and the generator's sums.
2. **Parametrise the ABI** over the world type. That turns `ExtCtx` into `ExtCtx[W]` and so rewrites
   `on_build_system_prompt` and `on_tool_policy` — two of D5's three ROWLESS slots. That is the
   handoff's explicit stop condition, so it was not taken.
3. **Extract `dst_interaction` (404 lines) and `dst_generator` (1519) into a leaf package** below the
   ABI. Feasible — both import only `std/*` — but it puts the DST generator into all fourteen
   extension packages' dependency graphs to serve one seam.

So the token is `ExtWorld = { token: Json }`. **D5's word "opaque" turns out to be load-bearing rather
than permissive: the dependency direction is what makes opacity necessary.** The cost is a real codec
(`src/core/ext_world.ail`), whose guard is S7's record-level rule.

**Record, not sum, at every level** — A12's P1 precedent, and the four decision types stay sums with a
record wrapped *around* each (`PreStepOutcome` &c). Folding the successor into each sum would have
restructured every variant and every match arm.

### The probe that settled it is worth keeping, because its first three mutants were inert

The structural-vs-nominal question was probed, and **the first probe passed while three mutants — an
extra record field, an extra sum variant, a changed payload type — all also passed.** The probe was
inert, and it looked like a result. The cause is a second AILANG finding: **a type declared in a
module that imports another module declaring the same NAME is silently shadowed by the imported one.**
The local declaration is simply dead. Only after renaming the types apart did the real answer appear.
**A control that fails is what separated a finding from a fiction here, and the control was nearly
skipped.**

## What changed, at three levels plus one

| Level | Change |
|---|---|
| `ExtPorts.ai_step` | `(ExtWorld, string, [Msg]) -> AiStepOutcome` — takes and returns the token |
| Hook results | four `XOutcome = { decision: XDecision, next_state: ExtWorld }` records; the four slots return them |
| Core dispatch | all four folds thread the world stage to stage; `PreStepChainResult` gains `next_state` |
| **Inbound**, and it is why the rowless slots survived | `ExtCtx.world`, an **additive** field — so no hook's *parameter list* changed type |

**That fourth row is the design's whole trick.** Passing the world in as a hook parameter would have
changed `on_build_system_prompt` and `on_tool_policy`; riding it on `ExtCtx` left all four
non-widened slots **byte-identical to HEAD, verified by diff**, and `make profile_coverage` exits 0.

`ExtPorts.proc_exec` and `env_get` are **deliberately not widened** and remain classifier-2 members.
WI-C5 owns them; leaving them measured and named is S2.

## Which fields left the classifier-2 set, and the state of all three artifacts

**`ai_step` left it. `proc_exec` and `env_get` did not.** Derived, not asserted:

```
ai_step    returns-it  fronts Ports.model_step and ExtPorts.ai_step's AiStepOutcome carries next_state
proc_exec  member      ... returns string and cannot carry it
env_get    member      ... returns string and cannot carry it
CLASSIFIER-2 SET (2): env_get, proc_exec        member call sites (0)
```

1. **The derived set** — 3 → 2, and **zero member call sites** remain in the tree.
2. **The pinned membership block** (`tools/ext_call_inventory/fixtures/expected.json` — note the path,
   the handoff gives it as `tools/ext_call_inventory/expected.json`) — **moved deliberately**,
   `ai_step: member` → `returns-it`. `make ext_call_inventory_selftest` is green **with the pin
   moved**, which is the point: it is green because the criterion no longer selects the field, not
   because the pin was bent to fit.
3. **`driver_only`'s omission record** — **left alone, and it is now loudly red.** `make driver_only`
   exits 2 with
   `FAIL: the manifest fixture records classifier-2 set ['ai_step','env_get','proc_exec'] but the tool derives ['env_get','proc_exec']`.
   **That is the stop-and-report condition firing, and it is reported rather than repaired.**

A **fourth** artifact carries the same prose and is also now stale: `dst_fault_catalogue.ail:299-333`,
whose `NoReachableBranch` says *"session.ext_ai_step hands the port a FRESH EMPTY world"*. It no
longer does. The handoff named three artifacts; there are four.

### The two questions, answered separately as asked

- **Did `ai_step` stop being a classifier-2 caller?** Yes, measured.
- **Is `compaction_ai` now installable?** **Yes, on the evidence — and that is exactly why it was not
  acted on.** `compaction_ai` calls no other classifier-2 field (checked: `ai_step` is its only port
  call), so the recorded reason for omitting it is void, and D5's "unconditionally-dispatched hook
  excluded" objection has nothing left to bite on. **Re-issuing `driver_only` with `compaction_ai`
  installed changes what the profile COVERS — a conformance claim, not a tidy-up — so it is left for
  the plan to take deliberately, with a profile version bump.**

## The classifier nearly returned a FAIL-OPEN answer, twice, and both were my change

**This is the run's most transferable finding.** After the widening the tool reported

```
ai_step   unrouted   the bridge reaches no core Ports seam
```

`unrouted` is not a milder `member` — it means *this field bypasses the world protocol entirely*, it
removes the field from the gated set, and `derive.py`'s own comment calls that class of answer
**"a fail-open answer produced by a parsing slip … the single most expensive bug in this tool's
history."** It looks like a clean result. Two independent causes, both introduced by this item:

1. **`ext_ai_step(p, token_to_world(w), …)`** — the tool follows one level of port-forwarding call
   with `\b(IDENT)\s*\(([^()]*)\)`, which **cannot match an argument list containing nested
   parentheses.** Fixed by hoisting the conversion into its own `let w0`.
2. **An anonymous record RETURN TYPE** on `ext_ai_step`. The tool finds a body by taking the first
   `{` after the signature that is not an effect row — so `-> { result: …, next_state: … } ! {…} {`
   hands it the *return type* as the body, in which no `p.model_step(` appears. Fixed by naming the
   type (`ExtAiStepResult`), which is better code anyway.

Only after both did it report `returns-it`. **Both sites are now commented with the reason, because
each is a landmine that re-arms on an innocent-looking edit.** The deeper point is for B4: this
detector fails OPEN and its failure is indistinguishable from a clean pass, so **any run that touches
`ext_ports_of` or its helpers must read the derived membership, not just the exit code.**

## The two `ScriptedStep` widenings, kept distinct

Two changes, deliberately not one:

- **The FAULT half is an error case.** `error_code` / `error_message`, flat, mirroring `ScriptedTool`
  directly above it. A non-empty `error_code` is what lets a scripted entry serve `Err` — until now
  `stub_step`'s world provider wrapped every entry in `Ok(...)`, so the catalogue's
  `provider_error_*` classes had **no scripted delivery at all**.
- **The LATENCY half is `advance_ms`**, restored on replay from `TimedOutcome.advance_ms` exactly as
  the tool duration already is: `decode_provider_outcome(payload, advance_ms)` now takes it as a
  parameter, the same shape `decode_tool_outcome` has always had. **No codec change on the wire** —
  it travels beside the payload, not inside it, because the elapsed time is what happened to the
  clock and recording it twice lets the two drift.

**The round-trip test asserts the passed value (983) wins over the fixture's own (449).** Asserting
`back.advance_ms == s.advance_ms` would pass equally against an encoder that wrote the field into the
payload and a decoder that ignored the parameter — the exact silent loss the suite exists to catch.

## The codec's guard was mutation-tested, and both mutants died

`src/core/ext_world.ail` carries four round-trip tests over a fixture world in which **every quantity
is distinct** and which carries every shape the token must survive (a faulted script entry *and* a
clean one, a non-empty approvals queue, an env pair, a scripted tool, a payload-carrying identity
variant, a recorded bound failure). All four pass. Then, per S7/S1:

| Mutant | Result |
|---|---|
| decoder reads the wrong key for `gen.rng` (writes-but-ignores species) | **RED** |
| encoder drops the faulted step's `error_code` | **RED** |

Restored: 4/4 green. **A codec whose guard has not been shown to fail is not a guarded codec**, and
this is the one place in the design where a silent loss would corrupt D1's single home.

## Sites and files, against the corrected 206

**58 files changed, 892 insertions / 586 deletions, plus one new module** (`src/core/ext_world.ail`,
untracked). 57 `.ail` files.

| Population | Sites |
|---|---|
| Hook implementations widened to return an outcome (typed form) | **149** |
| Lambda-form hook assignments | **15** |
| `runtime.ail`'s own smoke/chain hooks | **17** |
| **Subtotal against the handoff's 206** | **181** |
| `_ctx` → `ctx` binder renames (single- and multi-line) | 141 |
| `ExtCtx` literals gaining `world` | 16 |
| `ScriptedStep` literals gaining three fields | 20 |
| `ai_step` stub functions | 7 |
| ABI import repairs | 41 files |

**The 206 is a count of rowed sites, not of edits.** 181 of them are hook implementations; the
remaining 25 are the ABI's own declarations, the core dispatch functions rewritten by hand, and the
two `ai_step` call sites — which is consistent with the handoff's figure rather than a correction to
it.

## Recorded bindings: decided versus discovered

**Discovered — the compiler or a tool forced them and I transcribed:**

1. **`next_state` as the successor field's NAME**, on `AiStepOutcome` and all four hook outcomes.
   `derive.py`'s `SUCCESSOR_FIELD = "next_state"` derives membership by asking whether the result type
   has a field literally so named. **Renaming it silently puts `ai_step` back in the classifier-2
   set.** Matching `ProviderExchange`, `EnvRead`, `ToolExecution`, `ClockReading`.
2. Every widened row and every import repair.
3. The `let w0` hoist and the named `ExtAiStepResult`, both forced by the detector.

**Decided — a human chose:**

1. **The opaque Json token**, over inlining / parametrising / extraction. Argued above and in the
   ABI header.
2. **`ExtCtx.world` for the inbound half**, specifically to keep the three rowless slots
   byte-identical.
3. **Records around the sums**, not new variants (P1).
4. **`proc_exec` and `env_get` left un-widened**, so they stay classifier-2 members and WI-C5 keeps a
   real target.
5. **Helpers stay decisions; only hook SLOTS return outcomes.** Three functions the bulk tool
   over-widened (`omnigraph.handle_branch`, `microrag.auto_write_with_microrag`,
   `context_mode.finalize_with_index`) were reverted; `folding_pre_step` was kept widened because it
   is passed to `rt_with` as a hook value.
6. **NOT re-issuing `driver_only`.** The stop condition.
7. **The back-compat `summarize_with_ai` discards its successor**, narrowly and with the reason
   stated: nothing on the compaction path uses it.

## Sites where two answers type-checked and one was silently wrong: 2 found, both fixed, and B2a's structural argument holds

**Running total 37 → 39 across nineteen runs. Determinism has still caught none.**

B2a argued that closed rows admit exactly one width, so lockstep sites have no silent band — **and
that held here: not one of the 181 rowed sites had two answers.** But this item changed the *shape*
of the results, not just their rows, and that opened a band the row argument does not cover:

1. **`compaction_ai.register.on_pre_step` re-wrapping instead of forwarding.**
   `{ decision: compact_with_ai(...), next_state: ctx.world }` type-checks perfectly and **discards
   the world the summarizer advanced** — F6, in the one hook in the tree that actually calls
   `ai_step`. Caught only because the double-wrap happened to be a type error *at that particular
   site*; the same mistake written by hand would have compiled.
2. **The summarizer's FAILURE branches returning `ctx.world`.** `fresh_compaction` and
   `compact_with_ai` degrade to `PassThroughObserved` / the cached summary when the summarizer
   exhausts its attempts — but those attempts **were made**, and they consumed script entries.
   Returning the entered world there type-checks, passes every test in the tree, and replays them.
   **The decision falls back; the world must not.**

Both are the same species: **an identity transition is the correct answer for a hook that did
nothing, and a silent defect for one that did something.** Nothing in the type system distinguishes
them. The mitigation shipped is comment-level — every `next_state: ctx.world` in a hook that can
reach `ai_step` is now annotated — and **that is weaker than a check.** A real instrument would be an
assertion that a hook which performed a provider call did not return the world it was given; it needs
a counter the `ExtWorld` does not carry, and it belongs with B4 or C.

## Gate state

- **`make check_core` — EXIT 0, GREEN.** `src/core/` type-check **52 passed, 0 failed** (51 at start;
  the extra file is the new `ext_world.ail`). Genuinely cache-cold: **2 live `.ailang/cache`
  directories**, per S9's corrected count, cleared with S9's two exclusions before every believed run.
- **`make profile_coverage` — exit 0.** D5's coverable surface intact; all four un-widened ABI slots
  byte-identical to HEAD by diff.
- **`make ext_call_inventory_selftest` — exit 0**, with the pin moved.
- **`make driver_only` — exit 2**, deliberately, as described above.
- **`make dst` — NOT RUN.** Out of budget after the gate. `attribution_table` was expected to stay red
  regardless (nine of A5's ten anchors were already stale at HEAD; re-deriving them is B4's).
- **Whole-tree sweep — NOT RUN.** The honest consequence: **`check_core` and the extension packages
  are verified; the `scripts/dst/` suites are type-checked only where a dependency pulled them in.**
  B4 should sweep before trusting the tree-wide number.

## A5's anchors: what moved, stated precisely

The line-count guard was asserted on every mechanical edit and **fired nowhere**; two of the four
anchor files are byte-count-identical.

| File | HEAD | Now | Anchors |
|---|---|---|---|
| `src/core/tool_phase.ail` | 554 | **554** | 286, 287, 342 unmoved |
| `src/core/test/stub_step.ail` | 568 | **568** | 161 unmoved |
| `src/core/ext/runtime.ail` | 723 | 761 | **:190 HELD** — the import was collapsed onto one line specifically to hold it, and it is the ONE anchor that matched at HEAD |
| `src/core/session.ail` | 2962 | 3028 | **807, 948, 1053, 2290, 2400 all moved.** All five were already stale at HEAD (B2a measured them); the threading is structural and could not avoid it |

## Corrections owed to the plan

1. **Stop restating commit state in handoffs.** Four for four. Say "confirm with `git status`".
2. **`derive.py` fails OPEN and its failure looks like a pass.** Two separate innocuous constructs —
   a nested paren in an argument list, and an anonymous record return type — each silently reclassify
   a gated field as `unrouted`. **A tool whose failure mode is indistinguishable from success needs a
   positive control**: a fixture whose field MUST resolve to a seam, failing loudly if it stops.
   (`control_resolved.ail` checks call-site resolution, not the *bridge*.)
3. **`export type X = X` has a sibling: name shadowing across modules.** A type declared locally with
   the same name as one in an imported module is silently replaced by the imported one. S11 should
   grow this second clause — it is the same species (an accepted declaration that is quietly dead)
   and it made three mutants read green.
4. **The pin's path is `tools/ext_call_inventory/fixtures/expected.json`**, not
   `tools/ext_call_inventory/expected.json`.
5. **There are FOUR artifacts encoding the ai_step exclusion**, not three: add
   `dst_fault_catalogue.ail:299-333` to the list beside the derived set, the pin, and `driver_only`.
6. **A new silent band exists that closed rows do not cover** — the identity-transition band described
   above. B2a's "closed rows admit exactly one width" is still true and still protects the row sites;
   it does not protect a successor value.

## Deliberately not done

- **Re-issuing `driver_only`** and the profile version bump — the stop condition, reported above.
- **Updating `dst_fault_catalogue`'s `NoReachableBranch` prose** — same decision, same reason: it is
  half of the same conformance claim.
- **`make dst` and the whole-tree sweep** — budget.
- **The 7 `TC_ARITY_001` smoke scripts**, A5's anchors, the mutation loops, the 13 stale
  `ailang 0.26.0` strings — B4's.
- **`ExtPorts.proc_exec` / `env_get` widening** — WI-C5's, deliberately left as live classifier-2
  members.

## Commit state

**Nothing is committed.** 58 modified files plus the new untracked `src/core/ext_world.ail`, on
`arniwesth/mot-58-execute-wi-b2b`. Confirm with `git status` rather than believing this sentence.
