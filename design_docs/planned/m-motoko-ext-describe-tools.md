---
title: M-MOTOKO-EXT-DESCRIBE-TOOLS — on_describe_tools hook for rich extension ToolSchema
status: Planned
priority: P2
estimated: 1 day (~120 LOC)
depends_on: tools_with_extensions (shipped af79372)
---

## Problem

`tools_with_extensions(rt)` (af79372) surfaces extension-registered tool
names in the LLM's tool catalog. However the synthesized `ToolSchema` has
an empty parameters JSON Schema:

```ailang
pure func ext_tool_schema(name: string) -> ToolSchema {
  {
    name: name,
    description: "Extension tool: ${name}",
    parameters: "{\"type\":\"object\",\"properties\":{},\"required\":[]}"
  }
}
```

With no parameter descriptions, the LLM cannot know what arguments the
tool expects. In testing with the MCP microrag extension, the model called
`microrag_context_for_file` with `{}` even though the prompt explicitly
provided `{tool_name: 'ReadFile', file_path: 'std/ai.ail'}`. The model
has no signal to infer parameter names.

This is not blocking for the current dogfood (the empty schema is enough
to verify the dispatch path works), but will cause systematic wrong-args
failures in real agent sessions.

## Goal

Let extensions declare rich `ToolSchema` records so the LLM receives
accurate parameter descriptions for any tool they provide.

**Success metric**: the LLM calls `microrag_context_for_file` with the
correct args without being hand-held in the system prompt.

## Solution Design

### 1. Add `on_describe_tools` to `ExtensionHooks`

In `src/core/ext/types.ail`, add one optional hook field:

```ailang
export type ExtensionHooks = {
  id: string,
  provided_tools: [string],
  on_describe_tools: () -> [ToolSchema],   -- NEW
  on_build_system_prompt: (ExtCtx) -> PromptPatch,
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},
  on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision,
  on_tool_handle: (ExtCtx, ToolCallEnvelope) -> ToolHandleDecision
    ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_response_intercept: (ExtCtx, string) -> ResponseInterceptDecision
    ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_solver_candidate: (ExtCtx, string) -> FinalizeDecision
    ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
}
```

`on_describe_tools` takes no argument (pure; it cannot have side effects
because it is called from `tools_with_extensions` which is `pure`).
Returns `[ToolSchema]` — the full schemas for every tool this extension
provides.

**Default impl** (for extensions that don't care):

```ailang
on_describe_tools: func() -> [ToolSchema] { [] }
```

When `on_describe_tools` returns `[]`, `tools_with_extensions` falls back
to the existing minimal `ext_tool_schema(name)` synthesis.

### 2. Update `tools_with_extensions` in `tool_catalog.ail`

Replace `collect_hook_schemas` with a version that prefers the hook's
declared schemas over the synthesized fallback:

```ailang
pure func hook_schemas(h: ExtensionHooks) -> [ToolSchema] {
  let declared = h.on_describe_tools();
  if List.length(declared) > 0 then declared
  else collect_hook_schemas(h.provided_tools)
}

pure func collect_ext_schemas(hooks: [ExtensionHooks]) -> [ToolSchema] {
  match hooks {
    [] => [],
    h :: rest => hook_schemas(h) ++ collect_ext_schemas(rest)
  }
}
```

### 3. Wire in the MCP extension

`src/core/ext/mcp/mcp.ail` — `register_with_config` currently returns:

```ailang
{
  id: "mcp",
  provided_tools: tool_names,
  on_describe_tools: func() -> [ToolSchema] { [] },  -- stub
  ...
}
```

A follow-on task (M-MOTOKO-MCP-SUBPROCESS) will replace the stub with
schemas read from the MCP server's `tools/list` response once the
subprocess bridge is wired. Until then the fallback synthesis is used.

### 4. Update all existing `ExtensionHooks` construction sites

Add `on_describe_tools: func() -> [ToolSchema] { [] }` to:

- `src/core/ext/test_dummy/dummy.ail`
- `src/core/ext/compose/compose.ail`
- `src/core/ext/omnigraph/omnigraph.ail`
- `src/core/ext/context_mode/context_mode.ail`
- `src/core/ext/exa_search/exa_search.ail`
- `src/core/ext/mcp/mcp.ail`
- `src/core/test/stub_step.ail` (deny_all_rt hook)

All default to `[]` so no behaviour change for existing extensions.

### 5. Tests

- Extend `stub_step` with a `stub_tools_rt(schemas: [ToolSchema]) -> ExtRuntime`
  helper that exposes a hook with `on_describe_tools` returning `schemas`.
- Add an inline test to `tool_catalog.ail` verifying that
  `tools_with_extensions` for a runtime with declared schemas returns
  those schemas rather than synthesized stubs.
- Confirm empty-declared fallback still produces the minimal schema.

## Conflict Surface

This change adds a new required field `on_describe_tools` to
`ExtensionHooks`. Every construction site that pattern-matches or
constructs `ExtensionHooks` must be updated.

Existing programs that construct `ExtensionHooks` as a record literal
will get a type error until the field is added — this is intentional and
the type-checker guards against silent omissions. Search target:
`ExtensionHooks = {` in `src/core/ext/`.

No parser change. No new syntax. No new effect.

## Estimate

| Task | LOC |
|------|-----|
| Add field to `ExtensionHooks` type | 3 |
| Update `tools_with_extensions` logic | 15 |
| Update 7 construction sites with default stub | 21 |
| Tests (inline + integration stub helper) | ~80 |
| **Total** | **~120** |

## Not in scope

- Fetching schemas from live MCP `tools/list` — that's M-MOTOKO-MCP-SUBPROCESS.
- Schema validation against tool call arguments — future work.
