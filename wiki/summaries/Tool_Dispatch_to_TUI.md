---
doc_type: short
full_text: sources/Tool_Dispatch_to_TUI.md
---

**Tool Dispatch to TUI** outlines a phased architectural migration that decouples tool execution from the AILANG reasoning loop and hands it to the TypeScript TUI. The brain retains all reasoning (LLM calls, tool selection, loop control, state management) and the TUI owns execution (HTTP dispatch, parallelism, abort handling). This makes the brain’s effect signature ([`concepts/effect-signature`]) honest—it contains `AI`, `SharedMem`, `IO`, `Env`, `FS`, `Clock` but no `Net`—aligning with the project’s thesis of AILANG as an inspectable reasoning substrate.

### Key invariants
- **One round-trip per step** ([`concepts/invariant-one-round-trip`]): The brain emits all tool calls in a single `tool_calls` event and blocks on a single `readLine()` for `tool_results`. This avoids serialization latency and keeps the protocol deterministic.
- **Parallel execution** ([`concepts/batch-parallel-execution`]): TUI runs calls via `Promise.all`; the brain only emits a batch and does not dictate execution strategy.

### Architecture change
- The `rpc_loop` no longer calls `exec_in` (HTTP). Instead it parses the LLM response as a JSON array of tool calls, emits them, then reads back all results. The `swe/env_client.ail` module is deleted; `AgentState` loses `env_url`.
- Tool call requests become an ADT ([`concepts/adts-for-tool-type-safety`]) starting with `Bash`, with future variants (`ReadFile`, `Search`, etc.). The parser (`parse_tool_calls`) translates from stringly-typed JSON to typed ADT, supporting mixed supported/unsupported tools and explicit parse failure.

### Protocol
- New events: `tool_calls` (brain→tui), `tool_results` (tui→brain), `warning` (brain→tui for unsupported tools), `obs` per result (one per tool, with correlation `id`).
- `model_change` while blocked on results is handled by looping in `read_tool_results`.
- Abort is signal-safe with a `pendingAbort` flag and an abort controller; concurrent `tool_calls` or step mismatch are treated as fatal protocol violations.

### CWD and batching
- Within a batch commands do not sequence; `cwd` is attached to each `Bash` as structured data, not command‑string prefixing. After a batch, cwd is updated conservatively from at most one `cd` command ([`concepts/cwd-management`]).
- System prompt teaches the LLM which commands are safe to batch (independent reads) vs. unsafe (dependent writes).

### Phases (must ship atomically)
1. `swe/types.ail` — `ToolCallReq` ADT, `ToolResultItem`, updated `AgentState`.
2. `swe/parse.ail` — `parse_tool_calls` with full test suite.
3. `swe/rpc.ail` — new `rpc_loop` emitting `tool_calls`, `read_tool_results`, helpers (`encode_calls`, `parse_result_items`, `emit_obs`), delete `swe/env_client.ail`.
4. `tui/src/brain.ts` — async `tool_calls` interception, abort safety, `ToolExecutor` injection.
5. `tui/src/index.ts` — `makeToolExecutor` using `Promise.all`, switch on tool type.
6. `swe/prompts.ail` — updated system prompt teaching JSON tool calls and batching rules.
7. Named tools (additive) — `read_file`, `search`, `write_file`, `run_tests` as new ADT variants and TUI cases.

### Context growth
Multi‑tool batching accelerates context accumulation; tool output must be size‑limited and truncated metadata provided. A future compression module ([`concepts/context-compression`]) is noted.

### Testing
Inline tests for `parse_tool_calls`; integration tests covering single/multi calls, abort, protocol violations, interleaved commands, unsupported tools, truncation, and crash recovery.

Success criteria include: only one `readLine()` per step, no `Net` effect, and `AgentState` without `env_url`.

## See also
- [[concepts/effect-signature]] — brain's honest capability description
- [[concepts/adts-for-tool-type-safety]] — using algebraic types for tool dispatch
- [[concepts/batch-parallel-execution]] — why parallel execution matters
- [[concepts/cwd-management]] — cwd handling in batched commands
- [[concepts/invariant-one-round-trip]] — structural protocol constraint
- [[concepts/parse-tool-calls]] — robust JSON parsing with ADTs
- [[concepts/read-tool-results]] — handling model_change while blocked
- [[concepts/context-compression]] — future mitigation for context growth