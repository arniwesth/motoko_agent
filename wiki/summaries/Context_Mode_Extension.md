---
doc_type: short
full_text: sources/Context_Mode_Extension.md
---

This document plans a Motoko extension for [[concepts/context-mode]], a TypeScript tool that reduces LLM context window consumption by ~98% through sandboxed tool output, SQLite FTS5 session indexing, and aggressive output compression. The extension follows the same `ExtensionHooks` pattern used by omnigraph and compose, communicating with context-mode via shell exec (`std/process.exec`).

**Licensing** is a key consideration: context-mode is under Elastic License 2.0, which prohibits offering it as a managed service. The extension therefore treats context-mode as an optional, user-installed binary—never vendoring its source—mirroring how omnigraph is an optional dependency.

**Architecture** routes different context-mode operations (`ctx_execute`, `ctx_search`, etc.) through `on_tool_handle` hooks that shell out to the CLI. Lazy-loaded session snapshots (via SQLite) are injected into the system prompt on subsequent turns, while output compression happens within the tool handler itself. If the binary is not found, the extension gracefully degrades by returning `Delegate`. The `on_tool_policy` hook remains a no-op; enforced blockage of raw `curl`/`wget` is deferred to prompt-based routing instructions.

**Phased implementation** starts with scaffold and CLI wrappers (`exec.ail`), then builds system prompt patches (`prompts.ail`), tool routing, output compression (`compress.ail`), registry integration, and thorough testing. Environment variables control session store location and compression thresholds.

Key risks (e.g., missing binary, CLI version drift) are mitigated by fallback paths and version checks. The plan maps existing Pi extension hooks to the Motoko `ExtensionHooks` lifecycle, notably using `on_build_system_prompt` for session snapshots and `on_solver_candidate` for indexing final answers.

Cognate concepts: [[concepts/context-mode]], [[concepts/ExtensionHooks]], [[concepts/context-window-compression]], [[concepts/session-persistence]], [[concepts/shell-exec-pattern]], [[concepts/licensing-ELv2]].