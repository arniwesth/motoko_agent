# Packageize Extension System

## Objective

Turn Motoko's extension system from a closed-world set of ADT variants into an open-world registry backed by AILANG's package system (`ailang.toml`, `pkg/` imports, effect ceilings, lockfile). Third parties — and we ourselves — should be able to add, version, and publish an extension without editing `src/core/ext/types.ail`, `registry.ail`, or `runtime.ail`.

## Why

Current state (`src/core/ext/`):
- `PureExt` / `EffectExt` are sealed ADTs (`types.ail:55-65`). Every extension is one variant.
- Adding an extension edits three central files and widens ~7 match expressions in `runtime.ail`.
- `runtime.ail` imports every extension directly and carries the **union** of every extension's effects on every dispatch arm (`! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`). Any new extension silently widens that row for all others.
- Extension prompt text is smuggled via `ExtRuntime.omnigraph_prompt` — a per-extension special case on a shared record.
- No versioning, no interface contract, no way to ship an extension outside this repo.

AILANG's package system gives us: `pkg/vendor/name` imports, `[effects].max` ceilings per package, dual-hash lockfile, `AGENT.md` + `ailang pkg-docs`, and registry metadata. These map 1:1 onto what the extension system is missing — **but** packages alone don't break the ADT dispatch; that requires an internal refactor first.

## Spike findings (see `.agent/fixtures/hook_record_spike{1,2,3_FAILS}.ail`)

Validated against `ailang dev` (commit `5a89c92`, 2026-04-21):

- ✅ **Function-typed record fields work.** Both pure and effectful functions can be record fields. Lists of such records fold cleanly. This is Phase 1's load-bearing assumption and it holds.
- ✅ **Multi-arg hook fields work.** `\ctx env. ...` inside a record literal type-checks under a field typed `(Ctx, Envelope) -> Decision`.
- ✅ **Effect widening works.** A lambda whose body only uses `IO` type-checks as a field declared `! {IO, FS}`. This is our mitigation for the next point.
- ❌ **Effect polymorphism on record fields does NOT work.** `type PolyHook[e] = { run: ... ! {e} }` fails unification; bare `! e` (without braces) is a parse error. Record fields must declare a **concrete** effect row.
- ℹ️ **Call syntax:** `(h.field)(args)` — parentheses around the field access are mandatory; `h.field(args)` is a parse error.
- ✅ **Top-level `func`s are first-class values.** `Some(test_dummy_register)` works without a thunk (see `.agent/fixtures/hook_record_spike5.ail`). §1.4 can store bare function references in the resolve table.

**Consequence:** the `ExtensionHooks` record declares a maximal effect row on effectful hook fields. The monolithic effect union from `runtime.ail:202` does not disappear in Phase 1 — it moves into the hook record type. Per-extension effect ceilings are enforced only at publish time via `[effects].max` in Phase 2, not by the core compiler.

## Relation to existing plans

- `Core_Extension_Disentangling_Plan.md` — this plan **supersedes** its §4 ("Extension runtime dispatch coupling") and §2 ("Core ADT coupling") sections. Its parser/RPC coupling work (§1, §3) is orthogonal and should land independently.
- `Compose_Extension_Extraction_Plan.md` — we are currently on that branch. That plan lands first; its output leaves Compose self-contained under `src/core/ext/compose/`, which is the preconditon for Phase 1 here. Do not start Phase 1 until the Compose extraction merges.

## Two-phase strategy

The ADT dispatch is the real coupling; the package format is the distribution story. Do them in order.

**Caller contract (unchanged):** the six dispatchers called from `rpc.ail` — `dispatch_build_system_prompt`, `dispatch_budget_plan`, `dispatch_tool_policy`, `dispatch_tool_handle`, `dispatch_response_intercept`, `dispatch_solver_candidate` — keep their current signatures. Only their implementations change. `rpc.ail` is untouched by this plan.

---

## Phase 1 — Hook-record dispatch (internal refactor, no package tooling)

Goal: dispatch by value, not by ADT variant. After this phase, adding an extension is "construct a record and append it to a list", and `types.ail` / `registry.ail` / `runtime.ail` no longer name any specific extension.

### 1.1 Replace `PureExt` / `EffectExt` with a single `ExtensionHooks` record

In `src/core/ext/types.ail`, delete `PureExt` and `EffectExt`. Replace with:

```ailang
export type ExtensionHooks = {
  id: string,
  provided_tools: [string],                                    -- plain data, no thunk
  on_build_system_prompt: (ExtCtx) -> PromptPatch,             -- pure
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch,         -- pure
  on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision, -- pure
  on_tool_handle: (ExtCtx, ToolCallEnvelope)
    -> ToolHandleDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_response_intercept: (ExtCtx, string)
    -> ResponseInterceptDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_solver_candidate: (ExtCtx, string)
    -> FinalizeDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
}

export type ExtRegistry = { hooks: [ExtensionHooks] }
```

The union effect row on the three effectful hooks is the one carried by `runtime.ail:202` today. Spike confirms AILANG has no way to make it per-extension inside the type system — narrower-effect lambdas still plug in via effect widening, but the type-level declaration is the union. Per-extension ceilings are enforced by `[effects].max` at publish time (Phase 2), not here.

**Declared-pure hooks require moving TestDummy's telemetry.** Today `decide_one_policy` (`runtime.ail:143-158`) picks up `! {IO, Clock, Env}` because TestDummy's body calls `emit_dummy_hook` (`now()` + `println`). In the new shape, `on_tool_policy` / `on_build_system_prompt` / `on_budget_plan` are declared pure on the record. TestDummy's telemetry therefore moves **out** of the hook body into a dispatcher-side wrapper that logs *after* the pure hook returns. This is a behaviour-preserving relocation — the same JSON events are emitted at the same sequence points — but it's a real code move, not just a refactor of types. Call it out in the TestDummy conversion PR explicitly.

One list, not two. No `PureExt` / `EffectExt` split — the record's field types already distinguish them. `provided_tools` is a plain `[string]` field, not a thunk; nothing in the current extensions needs deferred computation of the tool list.

**Implementation note:** AILANG requires parentheses around field access in a call: `(h.on_tool_policy)(ctx, env)`, not `h.on_tool_policy(ctx, env)` (parse error). Every dispatch site in `runtime.ail` needs this form.

### 1.2 Drop the `ExtRuntime` per-extension fields

`ExtRuntime` today carries `dummy_prompt`, `dummy_tool_decision`, `dummy_finalize`, `dummy_budget_total`, `omnigraph_prompt`, `strict_mode`. All of these are extension-private state leaking into core.

- Move `dummy_*` fields into a test_dummy-local config record that test_dummy reads from env itself.
- Move `omnigraph_prompt` into omnigraph's own module (loaded during its `register()` call).
- Keep only `strict_mode` on `ExtRuntime` (core-level policy).

### 1.3 Each extension exports `register()`

For each of `test_dummy`, `compose`, `omnigraph`, add one exported constructor:

```ailang
export func register() -> ExtensionHooks ! {Env, FS} { … }
```

`register()` closes over whatever config/prompts the extension needs. All the existing `on_*` functions become fields of the returned record.

### 1.4 Rewrite `registry.ail` as a lookup table

`parse_core_ext_order` becomes a string→`register()` dispatch. This is the **one** place in core that still mentions extensions by name — and in Phase 2 it goes away too.

```ailang
-- test_dummy.register() reads env; compose.register() reads env;
-- omnigraph.register() reads env + calls load_agent_prompt (FS).
-- Resolver row is the union: {Env, FS}.
func resolve(name: string) -> Option[() -> ExtensionHooks ! {Env, FS}] {
  if name == "test_dummy" then Some(test_dummy_register)
  else if name == "compose" then Some(compose_register)
  else if name == "omnigraph" then Some(omnigraph_register)
  else None
}
```

If a future extension widens this (e.g. `SharedMem` during register), the resolver's declared row widens with it. Spike5 confirmed bare-name references to top-level `func`s are accepted — no thunks needed.

### 1.5 Rewrite `runtime.ail` dispatch as folds over `[ExtensionHooks]`

Every `match ext { TestDummyPure(_) => …, ComposePure(_) => …, OmnigraphPure(_) => … }` collapses to `ext.on_build_system_prompt(ctx)` etc. All seven dispatch helpers (`fold_prompt_pure`, `decide_one_policy`, `ext_provided_tools`, `dispatch_handle_from`, `dispatch_intercept_from`, `decide_one_finalize`, `fold_budget_pure`) lose their match trees.

### 1.6 Test gate

Existing tests in `registry.ail` (`parse_empty`, `parse_two_dummies_keep_order`, `parse_mixed_order_stable`, `parse_compose_then_omnigraph`, etc.) must still pass. They only exercise string→registry parsing, which is not enough.

**New test: dispatch smoke.** Add a test that constructs a two-hook `ExtRegistry` manually (two `ExtensionHooks` records with known ids and known decisions), calls each of the six dispatchers once, and asserts the expected merged result. This is the test that proves the field-call pattern actually dispatches correctly — existing parse tests can't fail when the dispatch path is miswired.

**Exit criterion for Phase 1:** grep `src/core/ext/runtime.ail` and `src/core/ext/types.ail` for `Compose`, `Omnigraph`, `TestDummy` — both files return zero hits. `registry.ail` is explicitly excluded — it keeps a `resolve(name)` table by design until Phase 2.

---

## Phase 2 — Lift each extension to a package

Goal: extensions live at `pkg/sunholo/motoko-<name>`, not under `src/core/ext/`. `CORE_EXT_ORDER` resolves through lockfile.

### 2.1 Create three packages

**Precondition:** resolve risk #2 first. Publish a throwaway package (`sunholo/motoko-spike`) with a non-trivial `module_prefix` and confirm (a) the exact `import pkg/…` path consumers use, (b) whether `readFile("AGENT.md")` from inside the package resolves relative to the package root or the consumer's cwd. The TOML and import examples below are written assuming `module_prefix` strips the prefix on the consumer side — **revise if the throwaway says otherwise.**

For each extension, author an `ailang.toml`:

```toml
[package]
name = "sunholo/motoko-compose"
version = "0.1.0"
edition = "1"
module_prefix = "src/core/ext/compose"  # keep existing module paths

[exports]
modules = ["src/core/ext/compose/compose"]  # only register() is exported

[effects]
max = ["IO", "FS", "AI", "Net", "SharedMem", "Clock", "Env"]  # per-extension ceiling
```

`module_prefix` means the existing file `src/core/ext/compose/compose.ail` doesn't move — only the manifest is new. Repeat for `sunholo/motoko-omnigraph` and `sunholo/motoko-test-dummy`.

Effect ceilings need to be measured per extension:
- `test_dummy`: `[IO, Clock]` only
- `compose`: needs AI, FS, SharedMem (claim-check store), IO, Clock
- `omnigraph`: needs Process (CLI shell-out), FS, IO, Env

This is a **publish-time lint**, not a runtime/compile-time effect guarantee. The runtime effect row stays at the union declared on `ExtensionHooks` in Phase 1 — spike confirmed AILANG can't make that per-extension polymorphic. What `[effects].max` gives us is: an extension that starts using `Net` without updating its ceiling fails `ailang publish --dry-run`. Useful for catching capability creep in review; not a substitute for the missing type-level guarantee.

### 2.2 Ship `AGENT.md` per package

Each extension already has prompt text living somewhere (`compose/prompts.ail`, `omnigraph/prompts.ail`, hard-coded strings in runtime). Move that text into an `AGENT.md` in the package root. The extension's `register()` reads it via `ailang pkg-docs` or a bundled `readFile`.

This removes the last per-extension field from `ExtRuntime` (`omnigraph_prompt`) and the `load_agent_prompt(workdir)` special case in `runtime.ail:38`.

### 2.3 Switch core imports to `pkg/`

```ailang
-- Before
import src/core/ext/compose/compose (register as compose_register)

-- After
import pkg/sunholo/motoko-compose/compose (register as compose_register)
```

Still a closed set in `registry.ail` — that's fine. Third-party *packages* can be activated by adding their `register` function to the resolve table (first-party gatekeeping of third-party code). True third-party-in-prod extensibility — where an operator flips on an extension without a core code change — requires §2.4.

### 2.4 (Optional / stretch) Dynamic extension discovery

Once packages are the transport, `CORE_EXT_ORDER=compose,omnigraph,acme/custom-ext` could resolve via `ailang.toml` dependencies rather than a hardcoded table. Deferred — requires AILANG runtime support for plugin-style loading that may not exist yet. Verify before scheduling.

### 2.5 Publish dry-run

`ailang publish --dry-run` for each package validates:
- Effect ceiling not exceeded
- Contracts on pure hooks (e.g. `merge_tool_decisions`, `apply_prompt_patch`) verify under Z3
- Interface hash matches what dependents expect

**Exit criterion for Phase 2:** `src/core/ext/` directory is empty (or holds only `types.ail`, `registry.ail`, `runtime.ail` — the host). All three extensions resolve via `pkg/` imports. `ailang publish --dry-run` succeeds for each.

---

## Risks / open questions

1. ~~**Effect polymorphism on `on_tool_handle`.**~~ **Resolved by spike:** not supported. Plan uses a declared union effect row on hook fields; per-extension ceilings enforced by `[effects].max` at publish time only. See `.agent/fixtures/hook_record_spike3_FAILS.ail`.
2. **`module_prefix` semantics.** The published docs say it maps module paths to package namespaces without moving files. Confirm by publishing a throwaway package first. Specifically: does `readFile` inside a package resolve relative to the package root or the consuming project's cwd? Affects §2.2 (AGENT.md loading).
3. **Circular imports.** If an extension needs to call back into core (e.g. `src/core/tool_contract`), that module must itself be either stdlib-shaped or its own package. Inventory core→ext→core cycles before Phase 2.
4. **Lockfile churn.** Every core change that bumps an extension's interface hash triggers a lockfile update. Acceptable for first-party; would matter more once third parties ship.
5. **Packages are necessary but not sufficient.** Phase 2 on top of today's ADT dispatch would buy us nothing — we'd still be editing `runtime.ail` match arms. Phase 1 first, always.
6. **Fallback if function-record dispatch hits an unexpected AILANG limit.** Spike covers the common patterns but not all of `runtime.ail`'s dispatch shapes (e.g. effect rows interacting with `SharedMem`/`Stream` inside a folded list). If a blocker appears mid-refactor, fall back to a keyed sum: `type HookCall = PromptCall(ExtCtx) | PolicyCall(ExtCtx, ToolCallEnvelope) | ...` dispatched by id through a table. Uglier but still eliminates the per-extension match arms.

## Non-goals

- Removing `CORE_EXT_ORDER` as the activation mechanism. It stays; only its resolution changes.
- Changing extension semantics (Compose's guard, Omnigraph's aliasing, test_dummy's envelopes). Behaviour-preserving refactor.
- Third-party extension hosting / registry work. We'd use the public AILANG registry if/when publishing; no Motoko-side infra.

## Sequencing

Each row is one reviewable PR unless marked otherwise.

| # | Step | Phase | Rough size | Gate |
|---|---|---|---|---|
| — | ~~Spike `! {e}` effect-polymorphic record field~~ | 1 | — | ✅ Done, failed, plan revised |
| — | ~~Spike top-level funcs as first-class values~~ | 1 | — | ✅ Done, works |
| 1 | `ExtensionHooks` record lands in `types.ail` + dispatch smoke test; no extension converted yet | 1 | 2 files | New smoke test passes against a hand-built 2-hook registry |
| 2 | Convert test_dummy (includes relocating `emit_dummy_hook` telemetry out of hook bodies) | 1 | 3-4 files | Existing parse tests + smoke test pass; dummy JSON events unchanged |
| 3 | Convert Compose | 1 | 2-3 files | Compose tests pass |
| 4 | Convert Omnigraph | 1 | 2-3 files | Omnigraph tests pass |
| 5 | Delete `PureExt` / `EffectExt` ADTs from `types.ail`; collapse `runtime.ail` match trees | 1 | 2 files | Grep clean (excl. `registry.ail`) |
| — | **Phase 1 merge gate.** Do not start Phase 2 until PRs 1-5 are on main. | | | |
| 6 | Throwaway `sunholo/motoko-spike` package to pin `module_prefix` / `readFile` resolution (risk #2) | 2 | — | Resolution documented; §2.1/§2.3 body updated if needed |
| 7 | `ailang.toml` for test_dummy + flip import to `pkg/`; measure runtime effect set | 2 | 1 manifest + 1 import | `ailang check` passes; `[effects].max` matches measured set |
| 8 | Manifests + `pkg/` flip for Compose and Omnigraph | 2 | 2 manifests + 2 imports | Same gate, per package |
| 9 | AGENT.md migration (Omnigraph prompt out of `ExtRuntime`) | 2 | 3 files moved | `ExtRuntime` loses `omnigraph_prompt`; `load_agent_prompt` caller gone |
| 10 | `ailang publish --dry-run` green for all three | 2 | — | Interface hashes stable across two consecutive runs |

Phase 1 is the load-bearing work. Phase 2 is mostly packaging. Ten PRs total, two of them throwaway/gate work.
