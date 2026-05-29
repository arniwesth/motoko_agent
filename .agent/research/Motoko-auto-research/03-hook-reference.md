# Motoko Extension Hook Reference for Self-Improvement

## Overview

This is a concrete reference for the Motoko code paths and data structures
relevant to recursive self-improvement. It documents what hooks exist, where
they're defined, how they're loaded, and what tools Motoko has to modify them.

## Key Files

```
.packages/motoko_core/src/core/
├── ext/types.ail              ← ExtensionHooks type definition
├── ext/runtime.ail            ← Hook dispatch (fold + merge logic)
├── ext/registry_generated.ail ← Extension loading (auto-generated)
├── rpc.ail                    ← Entry point: init_runtime_with_config
├── agent_loop_v2.ail          ← Agent loop: calls dispatch_* functions
├── tool_catalog.ail           ← Tool schemas + tools_with_extensions
└── config.ail                 ← RuntimeConfig, VerificationConfig
```

## ExtensionHooks Type (ext/types.ail)

```ailang
export type ExtensionHooks = {
  id: string,
  provided_tools: [string],
  on_describe_tools: () -> [ToolSchema],
  on_build_system_prompt: (ExtCtx) -> PromptPatch,
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},
  on_pre_step: (ExtCtx, [Msg]) -> PreStepDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision,
  on_tool_handle: (ExtCtx, ToolCallEnvelope)
    -> ToolHandleDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_response_intercept: (ExtCtx, string)
    -> ResponseInterceptDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_solver_candidate: (ExtCtx, string)
    -> FinalizeDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
}
```

## Hook Dispatch Order (from agent_loop_v2.ail)

The agent loop calls hooks in this order each step:

1. **`dispatch_pre_step`** — Compaction before the AI call. First `Compacted` wins.
2. Model step via `std/ai.step()`
3. **`dispatch_response_intercept`** — Intercept model output
4. **`dispatch_tool_policy`** — Evaluate each tool call
5. **`dispatch_tool_handle`** — Handle intercepted tools
6. **`dispatch_solver_candidate`** — Evaluate final answer (when model emits no tool calls)

## ToolPolicyDecision Variants

```ailang
export type ToolPolicyDecision
  = Allow
  | Deny(string)          -- Deny(reason)
  | NoOpinion
  | Pending(string, PolicyDefault)  -- Pending(reason, default_if_timeout)
```

Priority merge order: **Deny > Pending > Allow > NoOpinion**.

Deny immediately short-circuits — the tool is blocked with no further hooks consulted.

## How Extensions Are Loaded

`rpc.ail` calls `init_runtime_with_config(cfg)` which:
1. Reads `cfg.extensions.order` (a comma-separated list like `"context_mode,exa_search,compose"`)
2. Calls `parse_core_ext_order(order, cfg)` from `registry_generated.ail`
3. For each name, calls the corresponding `register_*` function
4. Each register function returns an `ExtensionHooks` record with hook implementations

Extensions live in:
```
.packages/sunholo/motoko_ext_*/register.ail     ← Third-party / first-party extensions
.packages/motoko_core/src/core/ext/*/register.ail  ← Built-in extensions (context_mode)
```

## Existing Extensions (from registry_generated.ail)

```
test_dummy, omnigraph, context_mode, mcp, exa_search,
ailang_docs, compose, a2a, decision_framework, microrag, compaction_ai
```

`test_dummy` is the no-op extension — its hooks log to JSONL but always return
neutral decisions (NoOpinion, NoIntercept, NoDecision).

## Self-Modification Surface

Motoko can modify its own extensions using these tools:

| Tool | Use |
|---|---|
| `ReadFile` | Read extension source before editing |
| `EditFile` | Targeted substring edits to extension AILANG |
| `WriteFile` | Full replacement of an extension source |
| `BashExec` | Run `make check_core` to verify edits compile |
| `Search` | Find hook implementations across the codebase |

For registration, Motoko would need to edit:
- `ailang.toml` — add extension name to the `[extensions]` order list
- `registry_generated.ail` — add import + resolve case (or regenerate via `ailang generate-extension-registry`)

## ExtCtx (Context Passed to Every Hook)

```ailang
export type ExtCtx = {
  task: string,           -- The current task prompt
  step: int,              -- Current step number in the agent loop
  model: string,          -- Model name (e.g., "claude-opus-4-5-20250514")
  cwd: string,            -- Working directory
  hybrid_tools: bool,     -- Whether hybrid shell mode is enabled
  budget: BudgetPlan,     -- Total/solver/verifier budget
  mode: string,           -- "default" or "verifier"
  workdir: string,        -- Working directory (same as cwd)
  env_server_url: string, -- Environment server URL
  budget_remaining: int,  -- Steps remaining in budget
  history_slice: [Msg],   -- Recent message history
  state_key: string       -- Key for cross-hook state sharing
}
```

## ToolCallEnvelope (Passed to on_tool_policy)

```ailang
-- From src/core/tool_contract.ail
export type ToolCallEnvelope = {
  id: string,             -- Tool call ID from the model
  name: string,           -- Tool name (e.g., "BashExec", "ReadFile")
  arguments: Json         -- Arguments as a JSON object
}
```

## Safety Mechanisms (Existing)

| Mechanism | What It Protects |
|---|---|
| `make check_core` | AILANG type-checking — modified extensions must compile |
| `EditFile.expected_sha256` | Optimistic concurrency — prevents editing stale file versions |
| Verifier mode (`cfg.agent.semi_formal_verifier_mode`) | Splits budget into solver/verifier; verifier validates output |
| `strict_mode` on `ExtRuntime` | If true, may reject unknown extensions |
| `reject_if_ohmy_pi_unsupported` | Startup guard for unsupported features |

## Safety Gaps (for Self-Improvement)

| Gap | Risk |
|---|---|
| No rollback mechanism | Broken extension persists across restarts |
| No watch-dog for "agent stranded" | If `on_tool_policy` denies all tools, agent can't recover |
| No atomic extension swap | Multiple files must be edited for a new extension |
| No version tracking | Can't compare "extension v1 vs v2" without manual bookkeeping |
| Generated registry | `registry_generated.ail` is auto-generated; manual edits may be overwritten |

## Recommended Safety Additions for Self-Improvement Experiments

1. **Git-based checkpointing**: Before any self-modification, `git stash` the
   current extension state. If the agent breaks, `git stash pop` restores it.
2. **Tool-policy whitelist**: Never deny `ReadFile`, `EditFile`, `WriteFile`,
   or `BashExec` unconditionally — always leave an escape hatch for self-repair.
3. **Extension version directory**: Instead of editing in-place, write new
   extension versions to a versioned directory and swap the registry reference.
4. **Bootstrap extension**: A minimal extension that is always loaded and
   guarantees at least `ReadFile` + `EditFile` + `BashExec make check_core` are
   allowed — the "recovery partition" for the agent.
