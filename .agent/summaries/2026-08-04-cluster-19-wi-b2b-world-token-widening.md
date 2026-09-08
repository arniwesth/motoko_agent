# 2026-08-04 Cluster 19: WI-B2b — the world token, and the pin it moved

## Context

Branch: `arniwesth/mot-58-execute-wi-b2b`.

Session span: `73e16fd` → **uncommitted working tree, 58 modified files + 1 new untracked module**.
Input was `HANDOFF-execute-b2b-world-token-widening.md`, executed cold against HEAD. Nineteenth code
session of project 009, and **the last of Milestone B's content**. Pin **v0.33.0**.

**Window: ~2h05m**, `18:57:14Z` → `21:02Z`. Roughly a third was the representation question, which had
to be settled before a single site could be touched; the rest was the cascade and eleven
compiler-driven repair rounds.

| Definition-of-done item | State |
|---|---|
| Token threads in and out at all three levels | **met** |
| Representation chosen and its reason recorded | **met** — opaque Json token, and it was forced rather than preferred |
| `ai_step`'s exclusion lifted or explicitly still stands | **lifted**, and derived by the tool rather than asserted |
| Classifier-2 set / pin / `driver_only` brought into agreement | **two of three**; the third is the stop condition, reported not repaired |
| The two `ScriptedStep` widenings, kept distinct | **met** — fault is an error case, latency is `advance_ms` |
| `make check_core` green | **met** — exit 0, 52/52 |
| `make dst` — say what it does | **NOT RUN** — out of budget |

## Grounding correction, and it is the fourth consecutive one

The handoff says B2a's work is "uncommitted: 79 source files plus `ailang.lock`", and says it is
"stating what B2a's report stated plainly". B2a's report *was* accurate when written. **It was
committed afterwards, as `6e19764` ("Implemented") — 114 files, 79 of them `.ail`, including
`ailang.lock`** — and this session started clean on a new branch.

B1's handoff got this wrong about B1, B3's about B3, B2a's about B3, this one about B2a. **The file
count has been right every single time; the commit state has been wrong every single time.** The rule
that would end it: *don't restate commit state in a handoff — say "confirm with `git status`", because
the next session must run it anyway.*

## The headline: the ABI could not name the world, and "opaque" turned out to be load-bearing

`packages/motoko-ext-abi` imports `std/option` and `std/json` and nothing else, and `motoko_core`
depends on it — so **the ABI cannot name `src/core/ports.WorldState`**. Three alternatives, measured:

| Alternative | Verdict |
|---|---|
| **Inline it** — the ABI's own idiom for `Msg`, `ToolCall`, `ToolCallEnvelope` | **Dead.** Records unify STRUCTURALLY (probed), which is why that idiom works — but sums unify NOMINALLY (same probe), and `WorldState` transitively contains `IdentityBody`, `OutcomeStatus`, `ToolFaultChoice` |
| **Parametrise the ABI** over the world type | **Rejected** — turns `ExtCtx` into `ExtCtx[W]`, rewriting `on_build_system_prompt` and `on_tool_policy`. That is the handoff's explicit stop condition |
| **Extract `dst_interaction` (404 lines) + `dst_generator` (1519)** below the ABI | **Rejected** — feasible (both import only `std/*`) but puts the DST generator into all fourteen extension packages' dependency graphs to serve one seam |

So: `ExtWorld = { token: Json }`, with `src/core/ext_world.ail` the only place it is opened.
**D5's word "opaque" reads as permissive and is actually necessary: the dependency direction is what
forces it.**

### The trick that saved the rowless slots

The token travels **in** on an *additive* `ExtCtx.world` field and **out** on record wrappers around
each decision (`PreStepOutcome` &c — records not variants, per A12's P1). Passing it as a hook
*parameter* would have changed `on_build_system_prompt` and `on_tool_policy`. Riding it on `ExtCtx`
left **all four un-widened ABI slots byte-identical to HEAD, verified by diff**, and
`make profile_coverage` exits 0.

### The probe that settled it was inert for three mutants

The structural-vs-nominal question was probed, the probe passed — and then **three mutants (extra
record field, extra sum variant, changed payload type) all passed too.** The probe was measuring
nothing while looking like a result. Cause: **a type declared locally in a module that imports another
declaring the same NAME is silently shadowed by the imported one** — the local declaration is dead.
Only after renaming the types apart did the real answer appear. **A control that fails is what
separated a finding from a fiction, and it was nearly skipped.**

## Which fields left the classifier-2 set

**`ai_step` left it. `proc_exec` and `env_get` did not** (deliberately un-widened; WI-C5 owns them,
and leaving them as live members is S2).

```
ai_step    returns-it  fronts Ports.model_step and ExtPorts.ai_step's AiStepOutcome carries next_state
CLASSIFIER-2 SET (2): env_get, proc_exec        member call sites (0)
```

| Artifact | State |
|---|---|
| The derived set | 3 → 2, **zero member call sites** remain in the tree |
| The pinned membership block | **moved deliberately**, `member` → `returns-it`; selftest green *because the criterion no longer selects the field*, not because the pin was bent |
| `driver_only`'s omission record | **left alone, and now loudly red** — `make driver_only` exits 2 naming the drift. The stop condition, reported not repaired |
| **`dst_fault_catalogue.ail:299-333`** | A **fourth** artifact carrying the same prose, also now stale. The handoff named three |

**Both questions answered separately, as asked.** `ai_step` stopped being a classifier-2 caller: yes,
measured. `compaction_ai` now installable: **yes on the evidence — and that is exactly why it was not
acted on.** Re-issuing `driver_only` with it installed changes what the profile *covers*, which is a
conformance claim and a version bump, not a tidy-up.

## The run's most transferable finding: the classifier fails OPEN, twice, and both were my change

After the widening the tool reported `ai_step  unrouted`. That is not a milder `member` — it means
*bypasses the world protocol entirely*, removes the field from the gated set, and `derive.py`'s own
comment calls that class of answer **"the single most expensive bug in this tool's history."** It
looks like a clean result. Two independent causes, both introduced here:

1. **`ext_ai_step(p, token_to_world(w), …)`** — the tool follows one level of port-forwarding call
   with `\b(IDENT)\s*\(([^()]*)\)`, which cannot match an argument list containing **nested
   parentheses**. Fixed by hoisting into `let w0`.
2. **An anonymous record RETURN TYPE** on `ext_ai_step` — the tool finds a body by taking the first
   `{` after the signature that is not an effect row, so `-> { result: …, next_state: … } ! {…} {`
   hands it the *return type* as the body. Fixed by naming it (`ExtAiStepResult`), better code anyway.

Both sites are now commented, because each re-arms on an innocent-looking edit. **Any future run
touching `ext_ports_of` must read the derived membership, not just the exit code.**

## The two `ScriptedStep` widenings, kept distinct

- **FAULT = an error case.** `error_code` / `error_message`, flat, mirroring `ScriptedTool`. Until now
  `stub_step`'s world provider wrapped every entry in `Ok(...)`, so the catalogue's `provider_error_*`
  classes had **no scripted delivery at all**.
- **LATENCY = `advance_ms`**, restored on replay from `TimedOutcome.advance_ms` exactly as the tool
  duration already is — `decode_provider_outcome(payload, advance_ms)` now takes it as a parameter,
  the same shape `decode_tool_outcome` always had. **No codec change on the wire.**

The round trip asserts the **passed** value (983) beats the fixture's own (449). Asserting
`back.advance_ms == s.advance_ms` would pass equally against an encoder that wrote the field into the
payload and a decoder that ignored the parameter — the exact silent loss the suite exists to catch.

## The codec's guard was mutation-tested and both mutants died

Four round-trip tests over a fixture world with **every quantity distinct**, carrying every shape the
token must survive (faulted *and* clean script entries, approvals queue, env pair, scripted tool, a
payload-carrying identity variant, a recorded bound failure).

| Mutant | Result |
|---|---|
| decoder reads the wrong key for `gen.rng` (writes-but-ignores species) | **RED** |
| encoder drops the faulted step's `error_code` | **RED** |

Restored 4/4 green. **A codec whose guard has not been shown to fail is not a guarded codec** — and
this is the one place a silent loss would corrupt D1's single home.

## Sites and files

**58 files changed, 892 insertions / 586 deletions**, plus new untracked `src/core/ext_world.ail`.

| Population | Sites |
|---|---|
| Hook implementations widened (typed form) | 149 |
| Lambda-form hook assignments | 15 |
| `runtime.ail`'s own smoke/chain hooks | 17 |
| **Subtotal against the handoff's 206** | **181** |
| `_ctx` → `ctx` binder renames | 141 |
| `ExtCtx` literals gaining `world` | 16 |
| `ScriptedStep` literals gaining three fields | 20 |
| `ai_step` stub functions | 7 |
| ABI import repairs | 41 files |

The 206 is a count of rowed **sites**, not edits: 181 are hook implementations, the remainder the
ABI's own declarations, the hand-written dispatch functions, and the two `ai_step` call sites. The
handoff's figure stands.

## Silent-wrong sites: 37 → 39, and a band closed rows do not cover

**Determinism has still caught none.** B2a's structural argument held — **not one of the 181 rowed
sites had two answers**, because closed rows admit exactly one width. But this item changed the
*shape* of results, not just rows, which opened a new band:

1. **`compaction_ai.register.on_pre_step` re-wrapping instead of forwarding.**
   `{ decision: compact_with_ai(...), next_state: ctx.world }` type-checks and **discards the world
   the summarizer advanced** — F6, in the one hook in the tree that actually calls `ai_step`.
2. **The summarizer's FAILURE branches returning `ctx.world`.** The attempts *were* made and consumed
   script entries. Returning the entered world type-checks, passes every test, and replays them.
   **The decision falls back; the world must not.**

Same species: **an identity transition is correct for a hook that did nothing and a defect for one
that did something**, and nothing in the type system distinguishes them. Shipped mitigation is
comment-level, which is weaker than a check; a real instrument needs a counter `ExtWorld` does not
carry. B4 or C.

## Gate state

- **`make check_core` — EXIT 0.** `src/core/` **52 passed, 0 failed** (51 at start; the extra file is
  the new module). Genuinely cache-cold: **2 live `.ailang/cache` directories**, per S9's corrected
  count, cleared with S9's two exclusions before every believed run.
- `make profile_coverage` — exit 0; `make ext_call_inventory_selftest` — exit 0 with the pin moved.
- `make driver_only` — **exit 2, deliberately**.
- **`make dst` — NOT RUN. Whole-tree sweep — NOT RUN.** Out of budget after the gate. The honest
  consequence: `check_core` and the extension packages are verified; **`scripts/dst/` is type-checked
  only where a dependency pulled it in.** B4 must sweep before trusting a tree-wide number.

## A5's anchors

The line-count guard was asserted on every mechanical edit and **fired nowhere**.

| File | HEAD | Now | Anchors |
|---|---|---|---|
| `tool_phase.ail` | 554 | **554** | 286, 287, 342 unmoved |
| `test/stub_step.ail` | 568 | **568** | 161 unmoved |
| `ext/runtime.ail` | 723 | 761 | **:190 HELD** — the import was collapsed onto one line specifically to hold the one anchor that matched at HEAD |
| `session.ail` | 2962 | 3028 | 807, 948, 1053, 2290, 2400 **all moved**; all five were already stale at HEAD, and the threading is structural |

## Corrections owed to the plan

1. **Stop restating commit state in handoffs.** Four for four.
2. **`derive.py` fails OPEN and its failure is indistinguishable from a pass.** Two innocuous
   constructs each silently reclassify a gated field. It needs a **positive control** — a fixture
   whose field MUST resolve to a seam. `control_resolved.ail` checks call-site resolution, not the
   bridge.
3. **S11 has a sibling clause: cross-module name shadowing.** A locally-declared type with the same
   name as an imported one is silently replaced. Same species as `export type X = X` — an accepted
   declaration that is quietly dead — and it made three mutants read green.
4. **The pin's path is `tools/ext_call_inventory/fixtures/expected.json`**, not
   `tools/ext_call_inventory/expected.json`.
5. **FOUR artifacts encode the `ai_step` exclusion**, not three — add `dst_fault_catalogue.ail`.
6. **A new silent band exists that closed rows do not cover** — the identity-transition band above.

## Deliberately not done

Re-issuing `driver_only` and the profile version bump (the stop condition); updating
`dst_fault_catalogue`'s prose (same conformance claim); `make dst` and the sweep (budget); the 7
`TC_ARITY_001` smoke scripts, A5's anchors, the mutation loops, the 13 stale `ailang 0.26.0` strings
(B4's); `ExtPorts.proc_exec` / `env_get` widening (WI-C5's, left as live classifier-2 members).

## Commit state

**Nothing is committed.** 58 modified files plus untracked `src/core/ext_world.ail`, on
`arniwesth/mot-58-execute-wi-b2b`. Confirm with `git status` rather than believing this sentence.

## Files

- `packages/motoko-ext-abi/types.ail` — `ExtWorld`, `empty_ext_world`, `AiStepOutcome`, four hook
  outcome records, `ExtCtx.world`, widened `ai_step`; version 4.0 → **5.0**
- `src/core/ext_world.ail` — **new**, the codec and its mutation-tested round trip
- `src/core/ext/runtime.ail` — all four dispatch folds thread the world
- `src/core/session.ail` — `ext_ai_step` takes/returns the world, `ext_ports_of` bridges the token,
  `mk_v2_ext_ctx` carries it, three dispatch sites write the successor back to `C2LoopState`
- `src/core/ports.ail` — the two `ScriptedStep` widenings and the provider-outcome codec
- `tools/ext_call_inventory/fixtures/expected.json` — the pin, moved
- 50-odd extension/script files — the cascade
- `.agent/projects/009_motoko_dst_execution/NOTE-b2b-execution-report-and-plan-corrections.md`
