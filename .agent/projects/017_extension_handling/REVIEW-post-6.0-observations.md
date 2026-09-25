# Review: observations on the landed 6.0 implementation

Date: 2026-08-30  
Status: Observations only — no code changed. Follow-ups on top of ADR-001 Phase C
(commits `8df6601`…`76178f8`, branch `arniwesth/mot-129-extension-abi-phase-a`).  
Measured at HEAD: `make check_core` 56/0, `make registry_gen_check` ✓,
`make registry_multiplicity` PASS, `make ext_hook_scope` 5/17 HOOK-PORT-MEDIATED (9 blocked
by the door-3 `show` residue, out of scope per PLAN).

Related: `ADR-001-extension-abi-evolution.md`, `PLAN-extension-abi-implementation.md`.

## What landed is sound

The record → list move (`Capability`, `ExtEntry { id, caps }`, `ExtRegistry { entries }`), the
per-kind folds in `src/core/ext/runtime.ail`, and the single host-owned boundary in
`src/core/ext/registry_normalize.ail` all read correctly. Every fold arm threads the world
token, the holder stamp stays per extension, and atom identity is typed (B6). The design trail
(ADR → PLAN → per-item commits) is complete.

## Follow-ups, in priority order

### 1. Cross-extension tool-name collisions are unchecked (highest value)

`registry_normalize.walk` (`registry_normalize.ail:183`) enforces disjoint `ToolProvider` names
*within* one extension only. No registry-wide name set is built, so:

- two extensions advertising the same tool silently resolve by `order` position in
  `first_handle` (`runtime.ail:477`), and `tools_with_extensions` (`tool_catalog.ail:143`) sends
  the model the schema twice;
- no reserved-name check exists against the 7 core tools. `dispatch_tool_handle` runs *before*
  native dispatch (`tool_phase.ail:365`), so an extension advertising `ReadFile` shadows the core
  tool with no diagnostic.

Proposed: a registry-level pass in `normalize_registry` adding
`DuplicateToolNameAcrossExtensions(id_a, id_b, name)` and `ReservedToolName(id, name)`
(seeded from `tool_catalog.tools()`). Because mcp/herdr/compose compute their name lists from
config, this can only be a runtime check — which is exactly the boundary that exists.

### 2. `parse_tokens` re-implements `normalize_registry` instead of calling it

The generator (`tools/ext_registry_gen/generate.py`) emits a per-extension loop calling
`normalize_registration` and hand-rolls the D7 empty-omission with a `println`
(`registry_generated.ail:66-91`). The tested `normalize_registry → NormalizedRegistry
{ entries, omitted_empty }` (`registry_normalize.ail:223`) is unused on the real load path,
which is why item 1 has nowhere to live today.

Proposed: generator collects `[ExtEntry]`, makes one `normalize_registry` call, and
`rpc.ail`'s `loaded_extensions` event carries `omitted_empty` so omissions are visible at
runtime, not only in DST.

### 3. Unknown / duplicate names in `extensions.order` are dropped silently

`resolve → None → parse_tokens(rest, …)` (`registry_generated.ail:39,72`). A typo
(`compaction-ai`) yields a session running fewer extensions than its profile claims — the
fail-open shape ADR-001 argues against for rejections. `a,a` registers twice (`a#0`, `a#1`) and
runs `register_with_config`'s Env/FS reads twice.

Proposed: both are rejections (exit 2), or at minimum named in an `unknown: [string]` field
beside `omitted_empty`.

### 4. `tool_catalog.hook_schemas` is all-or-nothing per extension

`tool_catalog.ail:123-129`: if an entry has *any* `DescribeTools` atom, no name-only fallback
is synthesized. With N>1 `ToolProvider` atoms now legal (D4), an extension that declares
schemas for some tools leaves the rest invisible to the model while still dispatchable.

Proposed: synthesize per name not covered by a declared schema; reject at the boundary a
declared schema whose name no `ToolProvider` in the same entry advertises (the model can call
it, it `Delegate`s, and falls to native dispatch as an unknown tool).

### 5. Test instrumentation lives in the production dispatchers

`emit_dummy_hook` / `is_test_dummy` (`runtime.ail:196-208`) force `! {IO, Clock}` onto the
otherwise pure `PromptShaper` / `BudgetShaper` / `ToolPolicy` folds and do a string-prefix
compare per atom. `dst_attribution_table.ail:218` already has to document this ambient `now()`
as a special case. With the list shape, `test_dummy` can observe itself from the fixture side;
removing the host-side emit makes three dispatchers `pure`, which strengthens the D5
criterion-1 story directly. Check `dst_attribution_table.ail` consumers first.

### 6. Smaller items

- ABI header (`types.ail:733-736`) says "LITERAL list of constructor applications" but
  constructor *arguments* may be computed (mcp `tool_names`, herdr `tools`). State it — it is
  the reason item 1 must be a runtime check.
- Every dispatcher skips unknown kinds via `_ :: rest`; only `kind_name` is exhaustive. A 7.0
  variant compiles with every fold ignoring it. Extend `dispatch_smoke_record_hooks`
  (`runtime.ail:834`) into an all-kinds-visited assertion.
- ADR §5.2 still lists "N>1 same-kind must dispatch every element … not exercised against real
  packages" as open; `second_compactor_atom_is_index_one_test` covers `Compactor` only. Close it
  for `PromptShaper` / `BudgetShaper` or mark it closed in the ADR.
- No author-facing 5.x → 6.0 migration note outside `.agent/` and the `types.ail` comment
  block; `packages/motoko-ext-abi` has no CHANGELOG entry for 6.0. The kind → slot table should
  be discoverable to external ABI consumers.

## Grouping

Items 1–3 are one coherent follow-up ("registry-wide validation on the real load path");
4 and 5 are independent; 6 is housekeeping.
