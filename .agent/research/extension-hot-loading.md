# Extension Hot-Loading: Session-Restart vs SharedMem Registry

2026-05-10 · Session: motoko_agent · Author: Motoko

## The Problem

Extensions are wired at startup via `ailang.toml` → `ailang generate-extension-registry` → `registry_generated.ail`. The resulting `ExtRuntime { registry: { hooks: [ExtensionHooks] } }` is an **immutable record built once** in `init_runtime_with_config()`. All hook-dispatch functions iterate the static snapshot. AILANG has no mutable references, so there is no way to append to that list mid-session.

This means `ailang init motoko-extension` + wiring works, but the new tools only appear in the **next** `make run` session, never the current one.

## Three Approaches

### 1. SharedMem-Backed Mutable Registry (best architecture)

**Concept:** Turn the static `[ExtensionHooks]` list into a `SharedMem` cell that the agent loop reads on every iteration.

```
SharedMem cell: "ext_registry"
  → serialized [ExtensionHooks] (JSON or binary)

Agent loop reads on each iteration ──► SharedMem cell ◄── HotLoadExtension tool writes
```

**Implementation:**
- Change `ExtRuntime` so `registry` is not a static list but a handle to a `SharedMem` key
- On every tool-catalog build / policy dispatch, read the current hook list from shared memory
- A `ReloadExtensions` tool (provided by a dedicated always-loaded extension) runs `ailang lock && ailang generate-extension-registry` externally, then writes the new hooks into the shared-memory cell
- The next loop iteration picks up the change automatically

**Cost:** ~200 LOC in `runtime.ail` + a new `session_tools` extension

**Key risk:** Extension hooks carry effect rows. SharedMem is keyed by `string`, not typed per-extension — serialization/deserialization boundary must be carefully managed.

### 2. Lazy Registration Table (less invasive, less powerful)

**Concept:** Make `registry_generated.ail`'s `resolve()` dynamic — backed by a `Map` that supports runtime `insert`.

```ailang
import std/map as M
let registry_map = _sharedmem_get("ext_registry_map")

func resolve(name: string, cfg: RuntimeConfig) -> Option[ExtensionHooks] {
  match M.lookup(registry_map, name) {
    Some(h) => Some(h),
    None    => None
  }
}
```

A `LoadExtension(name)` tool calls `register_with_config` for the named extension and inserts the result into the map. Works well for individual extension hot-loads, but doesn't handle the codegen step (`ailang generate-extension-registry`), so you can only hot-load extensions that were already compiled in.

**Cost:** ~100 LOC

**Limitation:** Cannot hot-load a brand-new extension package with its own source — only ones whose `register_with_config` was already compiled into the host's dependency tree.

### 3. Session Restart with State Serialization (simplest, full guarantees)

**Concept:** No true hot-loading. A `ReloadConfig` tool:

1. Appends the new extension to `ailang.toml`
2. Serializes current conversation state (messages, budget, workdir) to a temp file
3. Signals the TUI to restart with `MOTOKO_RESUME_SESSION=<path>`
4. The new process loads all extensions fresh and replays the conversation history

**Cost:** ~50 LOC in tool_runtime + a JSONL handshake with the TUI

**Advantages:**
- Trivially correct — no stale state, no SharedMem concurrency
- Works for any extension change (new packages, code edits to existing extensions)
- The serialized state is debuggable

**Disadvantages:**
- Full process restart — 1-3 second gap in UX
- Requires TUI-side support for the resume handshake

## Extension Hook Call Sites (for refactoring)

| Dispatch function | Module | Iterates `rt.registry.hooks` |
|---|---|---|
| `dispatch_build_system_prompt` | `src/core/ext/runtime.ail` | ✅ |
| `dispatch_budget_plan` | `src/core/ext/runtime.ail` | ✅ |
| `dispatch_tool_policy` | `src/core/ext/runtime.ail` | ✅ |
| `dispatch_tool_handle` | `src/core/ext/runtime.ail` | ✅ |
| `dispatch_response_intercept` | `src/core/ext/runtime.ail` | ✅ |
| `dispatch_solver_candidate` | `src/core/ext/runtime.ail` | ✅ |
| `tools_with_extensions` | `src/core/tool_catalog.ail` | ✅ |
| `loaded_extension_names` | `src/core/ext/runtime.ail` | ✅ |

All seven sites would need to switch from `rt.registry.hooks` to `read_hooks_from_sharedmem()`.

## Relevant AILANG Primitives

| Primitive | Module | Use |
|---|---|---|
| `_sharedmem_put(key: string, value: string)` | builtin | Write hooks blob |
| `_sharedmem_get(key: string) -> string` | builtin | Read hooks blob |
| `_sharedmem_cas(key: string, old: string, new: string) -> bool` | builtin | Atomic compare-and-swap |
| `std/map` (Map[k, v]) | stdlib | Alternative: keyed lazy registration |

## Test Dummy Precedent

The `test_dummy` extension already reads env vars at hook-invoke time (`getEnvOr("EXT_DUMMY_PROMPT", "")`) rather than at registration time. SharedMem follows the same pattern — defer reading until the hook fires — just using a different key namespace.

## Recommendation

| Timeline | Approach |
|----------|----------|
| **Short term** | Option 3: Session restart with state serialization. Simple, correct, works today. |
| **Medium term** | Option 1: SharedMem-backed registry. Right architecture; the loop already re-reads extension data on every iteration. |

## Open Questions

1. **Serialization format for [ExtensionHooks]:** JSON encode the hook record? Or use a SharedMem key per extension (kv store pattern)?
2. **Effect row for `read_hooks_from_sharedmem`:** SharedMem is a declared effect. Adding it to every dispatch function changes the effect signature of the entire agent loop — is the host ready for that?
3. **Thread safety:** If the agent loop reads hooks mid-iteration while `HotLoadExtension` writes, do we need `_sharedmem_cas` for atomic swap, or is eventual consistency acceptable (read on next turn)?
4. **TUI resume handshake:** Does the current JSONL protocol between runtime and TUI support a "restart requested" message type?
