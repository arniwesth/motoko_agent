# Changelog

All notable changes to motoko_agent are recorded in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added (M-MOTOKO-EVAL-INSTRUMENTATION — 2026-05-07)

Session JSONL gains schema-v1 instrumentation so downstream eval harnesses (AILANG `internal/executor/motoko/`, post-run analysis) can extract per-step token + cost data without needing a separate metrics endpoint. Strictly additive — existing consumers ignore new fields and keep working.

**Schema v1 surface** (per-event metadata):
- `schema_version: "1"` on every event — forward-compat marker
- `session_id` top-level field — derived from `MOTOKO_SESSION_ID` env var (preferred, matches filename) or fallback `session_${now()}`
- Per-step `thinking` events gain `input_tokens`, `output_tokens`, `cost_usd`
- `cost_warning` events gain `total_cost_usd` (alongside existing `_millicents`)
- `cost_exhausted` events gain `total_cost_usd`
- `session_start` gains top-level `motoko_commit` (build-time const, "dev" fallback)

**New `run_summary` terminal event** — always emitted on every termination path (success, Err, cost_exhausted, compaction_exhausted, max_steps, streaming-error). Carries: `model`, `motoko_commit`, `finish_reason` (`stop` | `cost_exhausted` | `dp7_rejected` | `compaction_exhausted` | `max_steps` | `error`), `steps_executed`, `usage: { input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens, total_tokens }` (cache fields omitted when upstream provider doesn't surface them), `total_cost_usd` (float, derived from millicents) + `total_cost_millicents` (int), `duration_ms` (wall-clock from `started_at_ms` to terminal), `error` (empty string on success; failure message otherwise).

**Implementation** (`src/core/agent_loop_v2.ail`, +~250 LOC):
- New helpers: `schema_version`, `motoko_commit`, `millicents_to_usd`, `emit_event`, `emit_run_summary`, `derive_session_id`, `per_step_usage_kvs`, `finish_reason_str`, `zero_totals`
- New `LoopTotals` record bundles cumulative token/cost state — threaded through `loop_v2` recursion (replaces 2 scalar params, prepares for future totals additions without param churn)
- `loop_v2` signature gains `session_id`, `started_at_ms`, `totals` (now passes `LoopTotals` instead of scalar `total_cost_millicents` + `cost_warned_pct`)
- `dispatch_calls` and `dp7_gate` gain `session_id` so all event emissions thread through the same envelope helper
- All 30+ `emit_json(jo([...]))` sites migrated to `emit_event(session_id, "type", [...])`
- 6 inline pure tests (`test_schema_version_is_one`, `test_millicents_to_usd_*`, `test_finish_reason_str_table`, `test_zero_totals_initializes_clean`)

**Snapshot fixture**: `examples/fixtures/eval_session_v1.jsonl` — canonical 15-event session demonstrating the schema. Future schema changes must update the fixture in the same PR.

**Deferred to v1.1**:
- Cache token plumbing (`cache_read_input_tokens` / `cache_creation_input_tokens`) — `std/ai.step` doesn't surface upstream cache-token data today; will land when AILANG-side support arrives
- Build-time `motoko_commit` injection via Makefile `-ldflags` — currently hardcoded to `"dev"`; trivial to wire up but not blocking

**Why now**: AILANG's planned [M-MOTOKO-EXECUTOR-ADAPTER](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_18_0/m-motoko-executor-adapter.md) needs structured token/cost data to populate `Result.CostUSD` / `Result.InputTokens`. Without this work, motoko on the eval leaderboard would appear "free" and "tokenless" — making the threshold-measurement experiment that is the strategic point of the adapter useless.

Design doc: [`design_docs/planned/m-motoko-eval-instrumentation.md`](design_docs/planned/m-motoko-eval-instrumentation.md).

### Fixed (M-MOTOKO-WORKDIR-CWD-RESOLUTION — 2026-05-06)

Dispatcher `workdir` argument is now correctly applied to all filesystem
operations. Previously `validate_path_common` used `workdir` for the bash
path-escape guard, but the leaf fs calls (`readFileResult`, `writeFileResult`,
`mkdirAllResult`, `rg`) resolved against the AILANG runtime's process cwd —
producing files at unexpected locations or silent read misses.

**Changes** (`src/core/tool_runtime.ail`):
- Added `resolve_workdir_path(workdir, path)` helper — joins workdir + validated
  relative path; handles trailing-slash, `.`, and empty-workdir edge cases
- `run_read_file`: `readFileResult` uses resolved path
- `run_write_file`: `fileExists`, `readFile` (prior content), `path_dirname`,
  `mkdirAllResult`, `writeFileResult` all use resolved path
- `run_edit_file`: `fileExists`, `readFile`, `atomic_write` use resolved path;
  `read_paths` policy check remains on the tool-supplied relative path
- `run_search`: new `workdir` parameter; `dir` resolved before passing to `rg`
- `path_dirname`: fixed to handle absolute paths (was dropping the leading `/`,
  causing `mkdirAllResult` to create parent dirs at a cwd-relative location)
- `validate_path_common` (bash escape guard) is unchanged — security model preserved

**Verification**: `scripts/smoke_v2_workdir_resolution.ail` — WriteFile to
`deep/nested/hello.txt` within a temp workdir lands at the absolute path.
All 6 prior v2 unit smokes pass (no regression).

Design doc: `design_docs/implemented/motoko_agent/m-motoko-workdir-cwd-resolution.md`
Sprint plan: `design_docs/implemented/motoko_agent/m-motoko-workdir-cwd-resolution-sprint-plan.md`

### Changed (M-MOTOKO-RPC-LOOP-FULL-MIGRATION — 2026-05-06)

The agent loop has been **fully migrated** from motoko's text-based
`parse_tool_calls` heuristic to upstream AILANG's `std/ai.step()` typed
tool-use protocol. Each provider's native tool-call mechanism now drives
dispatch directly:

- **Anthropic (Claude)** — `tool_use` content blocks
- **OpenAI (GPT-5+, o1, o3)** — `tool_calls` field with function-calling schema
- **Google (Gemini 2.5+)** — `functionCall` parts in `candidates[].content.parts`
- **OpenRouter (GLM, MiniMax)** — forwards to provider's native protocol

This retires the `arniwesth/ailang@motoko` fork: motoko_agent now consumes
upstream AILANG (v0.15.2) as a vendored stdlib without any patches to the
parser or AI provider layers.

#### All 6 legacy decision points retained

The migration preserves every behavior of the legacy `rpc_loop` while
moving dispatch onto the typed protocol:

1. **Extension intercept dispatch (DP1)** — `dispatch_response_intercept`
   and `dispatch_solver_candidate` fire at the same decision points
   `rpc_loop` fired them.
2. **Tool gating policy (DP3)** — per-call `dispatch_tool_policy` runs
   before native dispatch; `Deny(reason)` produces a structured
   tool-role denial JSON.
3. **Tool-handle routing (DP4)** — `dispatch_tool_handle` lets compose
   extensions (claimcheck, author_loop) intercept specific tools.
4. **Native vs ohmy_pi backend split (DP5)** — `backend_for(envelope,
   ohmy_pi)` classifies per-call. With `ohmy_pi=false` (the standalone
   default), all calls route Native — the env-server delegation path
   stays available for production deployments via `ohmy_pi=true`.
5. **Hybrid mode** — `extract_bash` extracts fenced shell blocks from
   prose-only responses when `hybrid_tools=true` and synthesizes a
   `BashExec` tool call that flows through the same dispatch pipeline.
6. **Multi-turn conversation_loop** — `conversation_loop_v2` reads
   stdin for follow-up `user_message`/`abort`/`exit`/`model_change`
   commands across the same agent process lifetime.

#### Validation: 25/25 provider × task matrix

Every cell of the M9 acceptance matrix passed against live APIs:

| Provider          | policy-default | factual | tool-write | tool-read | tool-build |
|-------------------|----------------|---------|------------|-----------|------------|
| Claude Sonnet 4.5 | ✅             | ✅      | ✅         | ✅        | ✅         |
| Gemini 2.5 Flash  | ✅             | ✅      | ✅         | ✅        | ✅         |
| GPT-5             | ✅             | ✅      | ✅         | ✅        | ✅         |
| GLM-5             | ✅             | ✅      | ✅         | ✅        | ✅         |
| MiniMax M2.7      | ✅             | ✅      | ✅         | ✅        | ✅         |

Smoke runner: `scripts/smoke_v2_provider_matrix.sh`.

#### Findings filed during migration

- Upstream AILANG fix: `internal/ai/openai/step.go` was sending
  `max_tokens` for GPT-5+ / o-series reasoning models where
  `max_completion_tokens` is required. Fixed in
  [ailang@daaa595b](https://github.com/sunholo-data/ailang/commit/daaa595b)
  with a 5-case table-driven regression test.
- motoko v2 internal: `backend_for(BashExec, ohmy_pi=false)` was
  routing to `Delegated` when shell tokens or `cwd` were present
  (`needs_delegation_for_process`); v2 standalone has no env-server,
  so Delegated had nowhere to land — fixed by forcing Native when
  `ohmy_pi=false`.

### Added

- `src/core/agent_loop_v2.ail` — the v2 agent loop (~700 LOC) with
  6 decision points and a typed tool-use pipeline.
- `scripts/smoke_v2_*.ail` — 5 v2 smoke tests covering policy denial,
  tool-handle routing, backend split, hybrid mode, and multi-turn
  conversation termination.
- `scripts/smoke_v2_provider_matrix.sh` — bash 3.2-compatible matrix
  runner across 5 providers × 5 task variants.

### Changed

- `src/core/rpc.ail#run_with_config` no longer consults
  `MOTOKO_AGENT_V2`; v2 is unconditionally the active loop.
- `src/tui/src/runtime-process.ts` no longer forwards
  `MOTOKO_AGENT_V2` to the child process.
- `SYSTEM.md` — replaced the JSON `tool_calls` block instructions with
  a provider-native API description.

### Deprecated

The following functions in `src/core/rpc.ail` and `src/core/parse.ail`
are unreachable post-cutover and pending a follow-up cleanup commit:

- `rpc_loop`, `conversation_loop`, `run_legacy_step`, `run_hybrid_step`,
  `run_ailang_step`, `apply_tool_policy`, `route_tool_handles`,
  `wait_for_tool_results`, `ai_stream_call_with_retry` (rpc.ail)
- `parse_tool_calls`, `indicates_continuation_intent`,
  `extract_any_tool_json_candidate`, `looks_like_non_json_tool_syntax`,
  `parse_legacy_terminal_call`, `parse_legacy_direct_call` (parse.ail)

These will be removed in a separate commit (sized for reviewability).

## Cross-references

- Upstream AILANG design: [m-agent-loop-architecture.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_17_0/m-agent-loop-architecture.md)
- Sprint plan: [m-motoko-rpc-loop-full-migration-sprint-plan.md](design_docs/planned/m-motoko-rpc-loop-full-migration-sprint-plan.md)
- Sprint design: [m-motoko-rpc-loop-full-migration.md](design_docs/planned/m-motoko-rpc-loop-full-migration.md)
- M9 playbook: [m-motoko-rpc-loop-m9-test-matrix.md](design_docs/planned/m-motoko-rpc-loop-m9-test-matrix.md)
