---
doc_type: short
full_text: sources/Packageize_Extension_System.md
---

# Packageize Extension System

This plan refactors Motoko’s extension system to eliminate the sealed ADT (`PureExt` / `EffectExt`) dispatch and instead uses **hook records** and **package-based distribution**. It breaks the tight coupling between core runtime and extensions, enabling extensions to be authored, versioned, and shipped independently.

## Current pain points
- Extensions are ADT variants in `types.ail`; adding one edits `types.ail`, `registry.ail`, and `runtime.ail`.
- `runtime.ail` carries a monolithic effect row (`!{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`) on every dispatch arm, and match expressions list every extension explicitly.
- Extension-private state (dummy prompts, omnigraph prompt) leaks into `ExtRuntime`.

## Two-phase solution

### Phase 1 — Hook-record dispatch (internal refactor)
- Introduce a single `ExtensionHooks` record type with pure and effectful fields (the latter declared with the full effect row). [[concepts/effect-polymorphism]] attempts failed (spike), so the union row is hardcoded.
- Each extension exports a `register()` function that returns an `ExtensionHooks`; the registry.ail maintains a string→register table.
- All dispatch in `runtime.ail` becomes folds over `[ExtensionHooks]`, with function-call syntax `(h.field)(args)`. The ADTs `PureExt` and `EffectExt` are deleted.
- Test dummy’s telemetry is moved out of pure hook bodies to wrapper calls to preserve declared purity.
- An exit criterion: grep for extension names in `runtime.ail` and `types.ail` returns zero hits (except the registry table).

### Phase 2 — Lift extensions to AILANG packages
- Each extension becomes a package (`sunholo/motoko-compose`, etc.) with `ailang.toml`, `[effects].max` ceiling, and a module prefix that keeps sources in place.
- Per-extension prompt text migrates into `AGENT.md`; loading uses package docs or `readFile` (requires confirming `module_prefix` semantics via throwaway spike).
- Core imports switch to `import pkg/sunholo/motoko-...`, keeping the resolver table until dynamic discovery (stretch goal).
- `ailang publish --dry-run` validates effect ceilings and interface hashes.

## Key spike findings
- Function-typed record fields work for both pure and effectful callbacks; lists of such records fold correctly. [[concepts/hook-record]]
- Effect polymorphism on record fields is **not supported** — fields must declare a concrete effect row. [[concepts/effect-polymorphism]]
- Per-extension effect ceilings are enforced at publish time via `[effects].max`, not by the type system.

## Risks & sequencing
- **module_prefix semantics** for `readFile` must be clarified before Phase 2.
- If the hook-record pattern fails in some dispatch shape, a fallback keyed sum dispatch is possible.
- Ten sequential PRs are planned: dispatch smoke test → convert test_dummy, Compose, Omnigraph → delete ADTs → throwaway package validation → per‑extension manifests and import switches → AGENT.md migration → publish dry‑run.

## Related documents
- Supersedes sections of [[Core_Extension_Disentangling_Plan]] and depends on [[Compose_Extension_Extraction_Plan]] finishing first.

## Non-goals
- The `CORE_EXT_ORDER` activation mechanism is preserved; only its resolution changes.
- Extension semantics remain unchanged; this is a behaviour‑preserving refactor.
- No third‑party hosting infrastructure is created here.