---
doc_type: short
full_text: sources/2026-04-23-omnigraph_extension.md
---

# Omnigraph Extension Implementation

**Date:** 2026-04-23

## Overview

This document describes the full integration of the Omnigraph graph extension into the system. It covers new extension modules, tool variants, core wiring, and optional build support.

## Changes

- **Extension Module:** Added `src/core/ext/omnigraph/` with files for types, execution, guardrails, prompts, and tests.
- **Core Wiring:** Omnigraph registered in core [[core/types]], [[core/parse]], and [[core/ext/runtime]]; new `CORE_EXT_ORDER=omnigraph` support.
- **Tool Variants:** Introduced `OmnigraphRead`, `OmnigraphMutate`, `OmnigraphBranch`, `OmnigraphStatus` and a new result variant `OmnigraphResult`.
- **Guardrail:** `on_tool_policy` denies `OmnigraphMutate` when branch equals `"main"` [[guardrails/tool_policy]].
- **Prompt Injection:** `on_build_system_prompt` injects cached content from `omnigraph/AGENT_PROMPT.md` [[prompt/injection]].
- **Execution:** `on_tool_handle` runs the Omnigraph CLI with fixed branch argument ordering and no positional `repo.omni`.
- **Build Support:** `scripts/install-prerequisites.sh` now accepts `--with-omnigraph` to optionally install the Omnigraph binary.
- **Scaffold:** Added graph schema, YAML config, queries, seed data, agent catalog, and validator under `omnigraph/`.

## Verification

All core type and runtime checks passed (`ailang check` / `ailang test`). The Omnigraph validator failed early due to missing binary, but the extension code itself is syntactically and type-checked. Full validation requires installing the binary first.

## Next Steps

1. Run `./scripts/install-prerequisites.sh --with-omnigraph`.
2. Run `./omnigraph/validate.sh`.
3. Smoke-run an agent with `CORE_EXT_ORDER=omnigraph` and inspect `trace.jsonl` for tool round-trips.

## Related Concepts

- [[extension system]]
- [[tool dispatch]]
- [[guardrails/tool_policy]]
- [[prompt/injection]]
- [[omnigraph/graph scaffold]]