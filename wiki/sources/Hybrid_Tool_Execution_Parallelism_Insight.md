# Hybrid Tool Execution: Parallelism Insight

Date: 2026-04-04

## Context

Current delegated tool execution in the TUI is sequential (`calls.map(runDelegatedCall)` with `spawnSync`), while modern coding agents commonly use selective parallelism.

## Key Insight

State-of-the-art agents typically do both:

- Parallelize independent, mostly read-only work (faster wall-clock completion).
- Keep dependent or mutating operations sequential (safer, deterministic behavior).

This is not a strict "parallel vs sequential" choice. It is an orchestration policy problem.

## Why This Matters for AILANG Agent

- Fixed timeout assumptions break when delegated batches contain multiple slow calls.
- Sequential-only delegated execution leaves performance on the table for independent calls.
- Full parallel execution without policy introduces race conditions for filesystem/process side effects.

## Suggested Feature Direction

1. Introduce backend policy: `sequential` (default) vs `parallel_safe`.
2. Add call-level eligibility rules for parallel execution:
- Eligible by default: `ReadFile`, `Search`.
- Conditionally eligible: `BashExec`/`RunTests` only if explicitly marked safe and non-mutating.
- Force sequential for `WriteFile` and unknown/mutating commands.
3. Keep result ordering stable by returning results in original call order.
4. Add stronger timeout model:
- Batch timeout scales with number/type of delegated calls.
- Preserve abort and model-change handling while waiting.
5. Surface execution mode in UI (`queued/running/done`, plus `parallel`/`sequential` batch marker).

## Sources Used

- OpenAI Codex prompting guide (parallel tool calling patterns): https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide
- OpenAI "Unrolling the Codex agent loop": https://openai.com/index/unrolling-the-codex-agent-loop/
- OpenAI Codex cloud overview (parallel background tasks): https://developers.openai.com/codex/cloud
- Anthropic tool-use docs (parallel tool use guidance): https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/implement-tool-use
