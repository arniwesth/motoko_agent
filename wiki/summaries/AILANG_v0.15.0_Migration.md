---
doc_type: short
full_text: sources/AILANG_v0.15.0_Migration.md
---

# AILANG v0.15.0 Migration — Summary

This document is a **pointer** to the canonical design in the AILANG repo ([[concepts/ailang]]), describing the plan to switch `motoko_agent` from a fork of AILANG to the upstream v0.15.0 release. The migration is blocked on [[concepts/provider-config]] decisions from arni’s team; no code changes exist yet.

## Key Points
- **Why upstream?** Three fork-specific features are now native in AILANG v0.15.0:
  - **OpenRouter routing** → built-in `openrouter` provider
  - **Custom OpenAI base-URL** → `[[ai_provider]]` blocks in `ailang.toml` ([[concepts/provider-config]])
  - **Token streaming** → `std/ai/streaming.openaiCompatStream` + event loop ([[concepts/streaming]])
- **Design ownership** – The canonical plan lives with the AILANG release to keep cross-references stable and track upstream feature dependencies (M-AI-PROVIDER-CONFIG, M-AI-STREAMING-HELPER).
- **Files to change** – 8 files (clone target, config, API call sites, codegen), with an estimated **4–5 hours** of work after arni’s input.
- **Testing** – Smoke tests include `make test`, `ailang check`, TypeScript compile, and a real-provider end-to-end run.

## Related Concepts
- [[concepts/ailang]] – upstream language release and its feature set
- [[concepts/provider-config]] – M-AI-PROVIDER-CONFIG and `ailang.toml` provider blocks
- [[concepts/streaming]] – streaming helpers and event-loop integration
- [[concepts/motoko-agent]] – the client project that depends on AILANG
- [[concepts/migration-strategy]] – phased approach to eliminating fork dependency