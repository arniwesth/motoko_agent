# RESEARCH: Extension ABI evolution — making slot additions non-breaking

Date: 2026-08-17
Status: Research — problem statement + option analysis (no decision yet)
ABI version at time of writing: `sunholo/motoko_ext_abi` **5.0** (`packages/motoko-ext-abi/ailang.toml`)
Relates to:
- `packages/motoko-ext-abi/types.ail` (the contract itself; its comments carry most of the ABI's design history)
- `src/core/ext/runtime.ail` (host dispatcher: per-slot fold/merge semantics)
- `src/core/ext_world.ail` (world-token codec, holder stamp)
- `src/core/ext/registry_generated.ail` (registration path, 16 extensions)
- `tools/ext_call_inventory/` and `tools/ext_ambient_inventory/` (the derivation tooling any re-shape must survive)
- `types.ail:324–406` — the `proc_exec` rename, priced and deferred to the 6.0 major; option 3 below is the same conversation

---

## TL;DR

Adding a hook slot to `ExtensionHooks` today is a 16-package edit plus an ABI major, because
AILANG record literals must supply every label and every extension constructs the record
itself. Three fixes were considered:

1. **Defaults constructor in the ABI** (`default_hooks(id)` + record update) — cheap,
   non-breaking, kills the 16-package tax immediately. **Do this now.**
2. **Capability registration** (extensions return a list of ABI-owned sum variants) — the
   typed version of "subscribe to what you need"; makes slot additions zero-cost for
   packages while keeping per-slot closed effect rows. **This is the shape of the 6.0**,
   bundled with the `proc_exec` rename so the break is spent once.
3. **Message bus / pub-sub** — rejected. It trades away the per-slot effect rows and typed
   request/response that the ABI's whole history (WI-D6/D7/D8) was spent acquiring.

Plus one upstream lever: optional/defaultable record fields in AILANG would dissolve the
problem with no architecture change — worth filing via `ailang-feedback`, not worth waiting on.

---

## 1. What the ABI actually is (baseline for this project)

The extensions ABI is the pure package `sunholo/motoko_ext_abi` (one module,
`packages/motoko-ext-abi/types.ail`), and the contract has four layers enforced by
different mechanisms of different strength:

**Layer 1 — registration convention.** Every `motoko-ext-*` package exports
`register_with_config(cfg: RuntimeConfig) -> ExtensionHooks` from `<package-name>/register`.
Discovery is static: `ailang generate-extension-registry` emits
`src/core/ext/registry_generated.ail`, which hard-links all 16 extensions and resolves
install order from `cfg.extensions.order`. Registration runs before the world exists, which
is why registration-time env reads are a disclosed ambient gap
(`types.ail:497–518`, the `env_get` note).

**Layer 2 — the hook record, types AND effect rows.** `ExtensionHooks` carries `id`,
`provided_tools`, and eight slots. The per-slot effect rows are part of the ABI, not
documentation: AILANG record-field rows are CLOSED — an implementation must equal the row
exactly — so an extension that starts reading a file in its budget hook fails to compile.
The rows are asymmetric because they were narrowed to measurement, not designed
(WI-D6/D7/D8: all fifteen bindings measured against the compiler and the runtime capability
trap; each row is exactly what the widest in-tree binding demands).

| Slot | Host dispatch semantics | Effect row |
|---|---|---|
| `on_describe_tools` | concatenated | none |
| `on_build_system_prompt` | patches folded in registry order | none |
| `on_budget_plan` | patches folded | none (narrowed WI-D6) |
| `on_pre_step` | chained; compactor output validated, invalid stages rejected | `{AI, IO, Trace}` |
| `on_tool_policy` | collected, merged `Deny > Pending > Allow > NoOpinion` | none |
| `on_tool_handle` | first match on `provided_tools` | 10 effects (widest) |
| `on_response_intercept` | first intercept wins | `{IO, Process, FS, Clock}` |
| `on_solver_candidate` | collected, merged `ContinueWithFeedback > Accept > NoDecision` | `{Process}` |

**Layer 3 — context and ports.** Hooks receive `ExtCtx`: task/step/model/budget/
`history_slice`/telemetry/`artifacts`, plus `ports: ExtPorts` (the mediated effect surface —
`ai_step`, `proc_exec` (dispatches a Motoko TOOL, not a raw subprocess; the name is the
priced 6.0 rename), `file_read`/`file_write`/`file_remove`, `path_stat`/`dir_list`/
`dir_make`, `clock_now`, `env_get`) and `world: ExtWorld`.

**Layer 4 — the world-token protocol.** `ExtWorld = { token: Json }`, opaque by necessity:
the ABI cannot name `src/core/ports.WorldState` (dependency direction), and cannot inline it
(AILANG unifies records structurally but sums NOMINALLY, and `WorldState` transitively
contains sums — `types.ail:62–98`). The extension's obligation is to carry the token:
take `ctx.world`, thread it through world-threading port calls, return the last as
`next_state` on the outcome records. Known enforcement gaps, all documented in-file:
dropped successors are silent (WI-D19 found the driver itself dropping them on 3 of 4
intercept arms); declared rows don't bound lambdas in record-field position (WI-B4/D8);
both are held by out-of-band checks (`dropped_successor`, `make declared_vs_performed`),
not the type system. Attribution rides in the token via the holder stamp (WI-D24).

**Versioning rule** (`types.ail:7`): bumping `ExtensionHooks` is a major. Observed
discipline through 5.0: widenings/additions ride minors (records take additive fields —
consumers keep compiling); anything invalidating an existing record LITERAL is a major,
because every extension constructs `ExtensionHooks`/`ExtPorts` label-by-label and a
changed label set is a hard compile break with no shim path (`types.ail:364–391`).

## 2. The problem

**Adding a slot affects all packages.** A new field on `ExtensionHooks` means every one of
the 16 `register_with_config` implementations must be edited to supply the new label, even
extensions that will never use it — plus the ABI major. The cost is real: the ABI has
consumers outside this repo (`types.ail:386–388`), so a break is a release act, not a
refactor. The record shape makes evolution O(consumers) when it should be O(1).

Note the asymmetry that drives every option below: in AILANG, **adding a field to a record
breaks every constructor; adding a variant to a sum breaks only exhaustive matchers.**
Extensions construct; only the in-tree host dispatcher matches.

## 3. Options

### 3.1 Message bus / pub-sub (rejected)

Proposal: replace the hook record with typed messages; each package subscribes to the
message types it needs, possibly dynamically ("at the time specific message types are
known").

Why it fails here:

1. **It collapses the per-slot effect rows.** A single `handle(envelope)` entry point must
   declare the UNION of every subscriber's effects — reinstating the over-declared
   ten-effect row that WI-D7/D8 spent two items measuring away. The per-slot rows are the
   ABI's most valuable compiler-enforced property; a bus makes them architecture-level
   impossible.
2. **These hooks are not events.** They are transformations with merge semantics (prompt
   patches fold; policy opinions merge with a priority order; tool handling is
   first-match). A bus still needs typed responses per message kind and per-topic merge
   policy — you rebuild `ext/runtime.ail`'s dispatcher with weaker types.
3. **The envelope has nowhere good to live.** A `Message` sum is nominal and ABI-owned, so
   adding a variant is still an ABI change (though a non-breaking one — see 3.3, which
   keeps exactly this part). A Json envelope is the silent-wrong-shape failure mode the
   project exists to remove.
4. **Dynamic subscription fights DST.** Mid-run subscription state is mutable state, which
   under deterministic replay must become another cursor threaded through the world token.
   Static registration-time declaration buys the same additive evolution without touching
   the replay story.

Residual value: the pub-sub shape fits purely observational hooks (telemetry/diagnostics
that return nothing). A minority of the surface.

### 3.2 Defaults constructor in the ABI (do now; non-breaking)

The ABI exports `default_hooks(id: string) -> ExtensionHooks` returning all-no-op slots;
extensions construct by record update — syntax already used in-tree
(`registry_generated.ail`'s `{ h | id: id }`):

```
make_hooks(cfg) = { default_hooks("agentcli") | provided_tools: [...], on_tool_handle: handle }
```

- Adding a slot then edits ONE site (`default_hooks`); every existing package keeps
  compiling. Shippable without a major: existing full-literal constructions stay valid.
- **Closed-row enforcement survives intact**: an overridden field is still checked against
  the ABI's row.
- Costs: (a) "didn't implement" becomes indistinguishable from "implemented as no-op" at
  the type level — the conformance tooling (`ext_ambient_inventory`, the coverability
  derivation, `declared_vs_performed`'s per-binding sweep) reads bindings today and must
  learn to see through defaults, or coverage claims get vacuously easier; (b) the wide
  record still grows forever; this is a tax cut, not a re-shape.

### 3.3 Capability registration (the 6.0 shape; the typed version of "subscribe")

`register_with_config` returns a LIST of capabilities, each a variant of an ABI-owned sum:

```
type Capability
  = PromptShaper((ExtCtx) -> PromptPatch)
  | BudgetShaper((ExtCtx, BudgetPlan) -> BudgetPatch)
  | Compactor((ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})
  | ToolProvider([string], () -> [ToolSchema],
                 (ExtCtx, ToolCallEnvelope) -> ToolHandleOutcome ! {...})
  | ResponseInterceptor(...)
  | SolverJudge(...)
  | ToolPolicy(...)
```

"Subscribing" = returning the variants you implement. The sum/record asymmetry does the
work: extensions only CONSTRUCT variants, so **a new capability variant breaks zero
packages**; the only exhaustive matcher is the in-tree dispatcher. What survives:

- Each variant's payload keeps its own closed effect row — per-slot compiler enforcement
  is untouched.
- Dispatch stays deterministic registry-order folds with existing merge semantics,
  iterating capability lists instead of record fields.
- World-token threading and the holder stamp transfer unchanged — the dispatcher still
  knows which extension it is invoking.
- Cleaner in one spot: `provided_tools` + `on_tool_handle`, today two record fields that
  must be kept mutually consistent, collapse into one `ToolProvider` variant.

Costs / open questions:

- Unavoidably the **6.0 breaking change** (every `register_with_config` signature moves).
  `types.ail:342–349` already prices the `proc_exec` rename for 6.0 and argues breaks
  should be spent once — this is the same conversation; bundle them.
- The derivation tooling reads record fields (`derive.py`'s `SUCCESSOR_FIELD` classifier,
  `declared_vs_performed`, profile coverage's per-(extension, slot) barrier counts,
  WI-D13). All of it must re-derive over capability lists. This is the main design work.
- The record model guarantees at most one binding per slot per extension; a list silently
  allows two `Compactor`s from one extension. Registration must validate multiplicity —
  decide per capability whether N>1 is an error or a feature.
- The WI-B4 hole (lambda rows unchecked in record-field position) presumably applies to
  lambdas in constructor-argument position too — must be measured, not assumed, before
  claiming the rows are enforced.

### 3.4 Upstream: optional/defaultable record fields in AILANG

Root cause is a language limitation: no optional fields, no row-polymorphic record types in
declarations. If records could declare defaults for absent fields, the problem dissolves
with no architecture change. File via `ailang-feedback` against `sunholo-data/ailang`;
do not wait on it.

## 4. Recommendation

1. **Now:** ship 3.2 (`default_hooks`) as a minor. One ABI function, migrate packages
   opportunistically (record update is optional — full literals still compile).
2. **Next slot addition after that:** costs one line in `default_hooks` instead of a
   16-package sweep. This buys time to design 3.3 properly.
3. **6.0:** take 3.3 (capability registration) bundled with the `proc_exec` rename.
   Precondition: the derivation-tooling re-shape is designed first — the coverability
   classifiers and `declared_vs_performed` are the ABI's real enforcement layer, and a
   re-shape that outruns them converts measured guarantees into asserted ones.
4. **In parallel:** file the AILANG feature request (3.4).
5. **Rejected:** the untyped bus (3.1), for the reasons above; revisit only for
   observational no-response hooks if those multiply.

## 5. Open questions for this project

- How do the coverability criteria (D5) and per-(extension, slot) barrier derivation
  (WI-D13) restate over a capability list? Does "slot" remain the unit, or does
  (extension, capability-instance) become it?
- Multiplicity policy per capability (3.3): which capabilities admit N>1 per extension?
- Does the effect checker enforce closed rows on lambdas in sum-constructor-argument
  position, or does WI-B4's record-field hole recur there? (Measure with the same
  drop-an-effect mutation method.)
- Does `default_hooks` need a per-slot "was overridden" witness so conformance tooling can
  distinguish implemented-as-no-op from not-implemented, or is the ambient inventory's
  transitive-closure measurement (classifier 3, WI-D12) already sufficient because it
  reads bodies rather than bindings?
