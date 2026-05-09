---
doc_type: short
full_text: sources/Hybrid_Tool_Execution_Parallelism_Insight.md
---

# Hybrid Tool Execution: Parallelism Insight

## Key Insight
State-of-the-art coding agents balance parallel and sequential tool calls: independent, read-only operations run in parallel for speed; dependent or mutating operations stay sequential for safety. This is not a binary choice but an **orchestration policy problem**.

## Why It Matters for AILANG Agent
- Sequential-only execution wastes time on independent calls.
- Full parallel execution risks race conditions on filesystem/process side effects.
- Fixed timeouts break with slower delegated batches.

## Proposed Direction
1. **Execution policies**: `sequential` (default) and `parallel_safe`.
2. **Call-level eligibility**:  
   - Always parallel: `ReadFile`, `Search`.  
   - Conditional: `BashExec`/`RunTests` if marked safe & non‑mutating.  
   - Always sequential: `WriteFile` and unknown/mutating commands.
3. **Result ordering**: Return results in original call order regardless of actual parallelism.
4. **Dynamic timeout**: Scale batch timeout with number/type of calls; preserve abort behavior.
5. **UI feedback**: Show `parallel`/`sequential` batch markers and per‑call status.

## Related Concepts
- [[concepts/tool-execution-policy]]
- [[concepts/batch-parallelism]]
- [[concepts/agent-timeout-handling]]
- [[concepts/readonly-vs-mutating-operations]]