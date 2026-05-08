---
doc_type: short
full_text: sources/2026-04-11-ailang-composition-language.md
---

Source: [[sources/2026-04-11-ailang-composition-language]]

# AILANG Composition Language Summary

This document describes the implementation of a new execution mode for the Motoko agent, where the LLM can generate AILANG snippets inside fenced ```ailang blocks to compose multiple file/search/bash operations into a single, efficient agent step. It addresses the overhead of many sequential tool calls by leveraging AILANG's effect system and pre-execution type-checking.

## Key Concepts

- **[[concepts/ailang-composition|AILANG Composition Mode]]** – a third execution mode alongside JSON tool-calls and bash fallback.
- **[[concepts/agent-execution-modes|Agent Execution Modes]]** – the agent's ability to process LLM output in different ways (tool calls, AILANG, bash).
- **[[concepts/type-checking-retries|Type-Checking & Retry Budget]]** – pre-execution `ailang check` catches errors; up to 3 free retries per step with targeted doc hints.
- **[[concepts/env-server-sandbox|Env-Server Sandbox]]** – AILANG runs inside a workdir sandbox with configurable capability set (`IO,FS,Process` by default; no `Net`).

## Implementation Highlights

### Extraction and Parsing
- New `extract_ailang` in [[sources/2026-04-11-ailang-composition-language|src/core/parse.ail]] safely pulls the body of ```ailang blocks, ignoring fences inside `