---
doc_type: short
full_text: sources/Omnigraph_Extension.md
---

# Omnigraph Extension — Plan Summary

Plan to port the Pi-targeted Omnigraph extension into a Motoko core extension under `src/core/ext/omnigraph/`, using the X1 hook surface.

## Overview

The agent will have four typed tools — `omnigraph_read`, `omnigraph_mutate`, `omnigraph_branch`, `omnigraph_status` — backed by the Omnigraph CLI. A main-branch write guardrail is enforced via `on_tool_policy`, and `AGENT_PROMPT.md` is injected into the system prompt.

## Phases

0. **Toolchain install:** Build Omnigraph CLI from source (Rust/protobuf) and add `--with-omnigraph` flag to install script.
1. **Graph scaffold:** Create repository layout, schema, queries, seed data, and validation script.
2. **Tool types and exec helper:** Define request/response types in AILANG, extend `ToolCallReq` and `ToolResultItem`, implement CLI exec wrapper with JSON output parsing, and propagate match arms.
3. **Extension wire-up:** Register extension in X1 registry, add dispatch arms in runtime, implement hook bodies (system prompt, tool policy, tool handle), and cache `AGENT_PROMPT.md`.
4. **Prompt injection and guardrail verification:** End-to-end positive trajectory (branch, mutate, merge) and negative trajectory (main-branch write denied). Confirm prompt content in traces.
5. **Test harness:** Unit tests for exec helper, guardrail, integration test with stub binary, registry and prompt caching tests.

## Key Design Decisions

- CLI-only backend; no HTTP server.
- No positional `repo.omni` arguments; URI resolved from `omnigraph.yaml`.
- Main-branch guardrail in `on_tool_policy` returns `Deny` for mutate on main, leaving `on_tool_handle` strictly for execution.
- `OmnigraphResult.json_metadata` as serialized string — mirrors Pi extension envelope, can upgrade later.

## Risks and Mitigations

- Toolchain build failure: pre‑install Rust and protobuf; opt‑in flag.
- `ToolCallReq` variant addition causes widespread match exhaustiveness: managed via systematic grep and `ailang check`.
- Flag ordering drift between Pi and CLI: verified by validate.sh and integration tests.
- Prompt bloat: keep `AGENT_PROMPT.md` concise.

See [[concepts/omnigraph]] for cross‑document synthesis. Related: [[Omnigraph_PoC_Plan]], [[Omnigraph_PoC_Implementation]].