---
sources: [summaries/Omnigraph_Possibilities.md, summaries/AILANG_Agent.md]
brief: A cross-run memory layer that stores agent trajectories to accelerate future task completions via hint injection.
---

# SharedMem Cache Layer

A persistent, cross-run memory subsystem built into the [[concepts/AILANG]] runtime that allows software engineering agents to store and retrieve trajectory hints from previous task executions. It forms the caching backbone of the [[summaries/AILANG_Agent]] architecture.

## Purpose

When an agent solves a task, the sequence of actions, observations, and final resolution constitutes a valuable artefact. The SharedMem cache layer captures this trajectory and makes it available to subsequent runs. If a later task resembles a previously solved one, the agent retrieves a hint and injects it into the system prompt, reducing redundant exploration and token consumption.

## Architecture

The cache layer is implemented as the `swe/cache.ail` module and relies on AILANG's `SharedMem` effect. It exposes two primary functions:

- **`get_hint(task: string) -> string`**: Queries the cache for a trajectory hint matching the given task description. Returns an empty string if no relevant trajectory is found.
- **`put_trajectory(task: string, output: string) -> () ! {SharedMem}`**: Stores the current task's trajectory (task description and final output) into SharedMem for future retrieval.

Both functions require the `SharedMem` capability in the AILANG effect signature, ensuring capability-based access control.

## Two-Tier Retrieval Strategy

The cache uses a two-tier lookup approach:

1. **Exact match**: Search for a trajectory with an identical or highly similar task description.
2. **Semantic fallback**: If no exact match is found, retrieve the most semantically related trajectory, if any, based on SharedMem namespace conventions.

This strategy balances precision against recall — exact matches provide highly reliable hints, while the fallback ensures some benefit even for novel task formulations.

## Hint Injection

When `get_hint` returns a non-empty string, the [[concepts/AILANG/SWE-Prompts]] module's `with_cache_hint` function appends it to the base system prompt:

```ailang
func with_cache_hint(system: string, hint: string) -> string =
  if hint == "" then system
  else system ++ "\n## A similar issue was previously resolved\n" ++ hint
```

This prefixed section gives the LLM a concrete example of a successful resolution path, acting as few-shot guidance without consuming the main conversation context window for repeated retrieval.

## Integration with the Agent Loop

In the [[summaries/AILANG_Agent]]'s `swe/rpc.ail` brain, the cache is consulted once at startup in the `main` function:

```ailang
let hint    = get_hint(task);
let system  = with_cache_hint(base_system, hint);
let init    = [{ role: "system", content: system },
               { role: "user",   content: task }];
```

The trajectory is stored only upon successful completion, within `rpc_loop`, ensuring that incomplete or aborted runs do not pollute the cache.

## SharedMem Namespace Conventions

The cache layer follows established SharedMem namespace conventions, using consistent key patterns to organise trajectories. This ensures compatibility with other SharedMem consumers (such as the model config key used by [[concepts/Option D Model Selection]]) and avoids key collisions.

## Validation

The Phase 3 success criterion for the cache layer is:

- **Second run on the same issue injects a cache hint** — confirmed by inspecting logs for hint retrieval.
- **Token reduction** — measured by comparing trace sizes between first and second runs on identical tasks.

## Relationships

- Depends on [[concepts/AILANG]]'s `SharedMem` effect system for capability-gated persistent storage.
- Works in tandem with [[concepts/AILANG/SWE-Prompts]] for hint injection into the system message.
- Complements [[concepts/Option D Model Selection]], which also uses SharedMem (for storing the current model name).
- Built into the core agent loop of [[summaries/AILANG_Agent]].

## See Also

- [[concepts/Environment Server]] — the execution backend that produces the trajectories stored by this cache.
- [[concepts/JSONL Protocol]] — the communication layer that carries trajectory data between processes.
- [[concepts/Yolo Mode]] — the execution mode that simplifies trajectory capture by removing confirmation pauses.

See also: [[summaries/Omnigraph_Possibilities]]