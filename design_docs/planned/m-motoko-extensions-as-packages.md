# M-MOTOKO-EXTENSIONS-AS-PACKAGES

**Status**: Planned — blocked on AILANG capability gap (see Prerequisite)  
**Priority**: P2 — ecosystem enabler, not on critical path  
**Estimated effort**: 5-7 days (4-5 without AILANG prerequisite; +2 if AILANG adds static-dispatch generation)  
**Dependencies**: AILANG static-dispatch code generation (see Prerequisite), compaction design doc, Pending design doc  
**Source**: motoko-explore inbox msg `046df945` (2026-05-06)

---

## Problem

motoko's extensions are vendored in `src/core/ext/` and the registry is a hardcoded `if name == "..."` ladder. Adding an extension requires a PR to motoko_agent. Extensions can't be versioned independently, pinned per-project, or shipped by third parties.

The proposal: distribute each extension as an independently-published AILANG package (`motoko-ext-microrag`, `motoko-ext-compaction`, `motoko-ext-exa-search`, ...) and make the registry load them from `ailang.toml`.

---

## Prerequisite: AILANG dynamic import limitation

**AILANG does not support runtime-resolved imports.** All `import` statements are resolved at compile time. This means the registry cannot do `importByName("motoko-ext-microrag")` from a runtime config string.

A capability check confirmed: `ModuleLoader.Load()` resolves paths statically; there is no `import_symbol(pkg_name, symbol_name)` builtin; `ImportDecl` AST nodes contain fixed string paths only.

**This blocks the "fully dynamic" registry design** from the motoko-explore proposal.

### Mitigation: static-dispatch code generation

Instead of runtime dynamic import, the migration becomes a **two-phase build step**:

1. **Config phase**: `ailang.toml` lists extension packages:
   ```toml
   [extensions]
   packages = [
     "motoko-ext-compaction@0.2.0",
     "motoko-ext-exa-search@0.4.1",
   ]
   ```

2. **Generation phase**: a build step (new `ailang generate-extension-registry` command or Makefile target) reads `ailang.toml` and writes `src/core/ext/registry_generated.ail` containing explicit static imports:
   ```ailang
   import motoko-ext-compaction/register (register_with_config) as register_compaction
   import motoko-ext-exa-search/register (register_with_config) as register_exa_search
   
   export func resolve(name: string) -> Option[ExtensionHooks] = ...
   ```

3. The generated file replaces the hand-written `registry.ail`. Regenerate when `ailang.toml` changes.

This requires:
- An `ailang generate-extension-registry` command (or makefile target) — ~150 LOC
- Convention: every `motoko-ext-*` package must export a `register_with_config` symbol

This is less elegant than true dynamic import but ships on existing AILANG without language changes.

**Alternative to generator**: if AILANG adds a proper `dynamic import` feature in a future version, the generated file becomes unnecessary. The design is forward-compatible — the `ailang.toml` schema is the same either way.

---

## Goals

1. Each motoko extension lives in its own repo/package, versioned independently
2. Adding an extension = `ailang add motoko-ext-NAME` + `ailang generate-extension-registry`
3. Core motoko shrinks: vendored ext directories removed after migration
4. `motoko-ext-abi` package stabilises the `ExtensionHooks` ABI contract
5. Extensions-as-packages is opt-in; existing vendored extensions work until migrated

---

## Design

### Phase 1: Stabilise the ABI (~1 day)

Create `motoko-ext-abi` package exporting the `ExtensionHooks` record type and all hook signatures. Every extension package depends on `motoko-ext-abi ^1.0`.

Files to move from `src/core/ext/types.ail`:
- `ExtensionHooks`, `ExtCtx`, `PromptPatch`, `ToolPolicyDecision`, `ToolHandleDecision`
- `ResponseInterceptDecision`, `FinalizeDecision`, `BudgetPlan`, `BudgetPatch`
- *(After M-MOTOKO-TOOL-POLICY-PENDING lands)* `PolicyDefault`
- *(After M-MOTOKO-CONVERSATION-COMPACTION lands)* `PreStepHook`

### Phase 2: Code-gen registry (~2 days)

New command: `ailang generate-extension-registry [--output src/core/ext/registry_generated.ail]`

Reads `[extensions].packages` from `ailang.toml`, locks versions from `ailang.lock`, emits the static-import registry file. Replaces the current `if name == "..."` ladder.

The generated file is committed (like `ailang.lock`), so the build is reproducible without running the generator in CI.

### Phase 3: Namespace reservation (~0.5 days)

Reserve `motoko-ext-*` prefix in the AILANG package registry. Document the publishing flow:
- Package `ailang.toml` must declare `motoko-ext-abi` as a dependency
- Must export `register_with_config(cfg: ExtConfig) -> ExtensionHooks ! {}`
- Semantic versioning required; breaking ABI = major bump

### Phase 4: Migrate one extension as proof (~1 day)

Extract `src/core/ext/exa_search/` → new repo `sunholo-data/motoko-ext-exa-search`. Publish v0.1.0. Prove `ailang add motoko-ext-exa-search` + generate works on a fresh clone. Delete vendored copy from motoko_agent in the same release.

---

## Files

| File | Change |
|------|--------|
| `ailang.toml` | Add `[extensions].packages` field |
| `src/core/ext/registry.ail` | Replace with `registry_generated.ail` (generated) |
| `src/core/ext/types.ail` | Thin shim re-exporting from `motoko-ext-abi` |
| `cmd/ailang` (AILANG repo) | New `generate-extension-registry` command |
| New repo: `motoko-ext-abi` | ABI types package |
| New repo: `motoko-ext-exa-search` | First migrated extension (proof) |

---

## Acceptance criteria

- [ ] `motoko-ext-abi` v1.0.0 published with all `ExtensionHooks` types
- [ ] `ailang generate-extension-registry` produces a valid, compilable registry file
- [ ] Adding `motoko-ext-exa-search` to `ailang.toml` + running generator = working exa_search extension
- [ ] Removing the package from `ailang.toml` + regenerating = extension not loaded
- [ ] Existing vendored extensions still work during migration period
- [ ] `motoko caps` command (or equivalent) shows aggregate effect set of loaded extensions
- [ ] Verified end-to-end in motoko_explore with 2 extensions loaded via packages

---

## Open questions

1. **AILANG repo work**: `ailang generate-extension-registry` is an AILANG CLI command. Should it land as an AILANG design doc (`m-ailang-extension-registry-gen`)? Or is it a motoko-side tool (a small Go/shell script that reads `ailang.toml` and emits AILANG code)? The latter ships faster and doesn't need AILANG changes.
2. **Dynamic import roadmap**: should AILANG add `dynamic import` to v0.18+? If yes, the generator becomes a bridge solution rather than permanent. The motoko-explore message suggested checking whether the package system supports it — confirmed it does not (see Prerequisite section).
3. **When to do this**: compaction and `Pending` are higher priority. This is a P2 that enables the ecosystem play. Suitable for v0.18 or post-cutover roadmap.
