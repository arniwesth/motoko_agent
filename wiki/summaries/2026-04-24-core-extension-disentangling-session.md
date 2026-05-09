---
doc_type: short
full_text: sources/2026-04-24-core-extension-disentangling-session.md
---

# Core Extension Disentangling Session

## Overview
This session executed the `Core_Extension_Disentangling_Plan`, refactoring the core runtime to use a generic tool contract and moving all Omnigraph-specific semantics into its extension module. A user‑reported runtime crash was investigated and fixed. An extraction plan for the Compose extension was also authored.

## Key Changes
- **Generic tool envelope** introduced in `src/core/tool_contract.ail` with `ToolCallEnvelope` and `ToolResultEnvelope`, plus serialization helpers. (see [[Tool Envelope Pattern]])
- Core ADT types (`src/core/types.ail`) removed Omnigraph constructors and results, now produce `ParsedToolCalls` containing only envelopes. (see [[Core/Extension Separation]])
- Parser (`src/core/parse.ail`) made extension‑agnostic: emits generic envelopes and no longer normalizes Omnigraph arguments.
- Omnigraph normalization, coercion, guardrail, policy, and execution migrated to `src/core/ext/omnigraph/`. The extension now receives and returns envelopes exclusively.
- Core‑extension interface (`ext/types.ail`, `ext/runtime.ail`) updated to use envelopes for policy/handle and result dispatch.
- RPC telemetry (`src/core/rpc.ail`) and tool runtime backend (`src/core/tool_runtime.ail`) switched to envelope‑based routing, removing all Omnigraph‑specific branches.

## Runtime Fix
A user error `expected TaggedValue, got *eval.StringValue` occurred when calling `OmnigraphStatus`. Root cause: metadata string values passed to `kv(...)` without wrapping in `js(...)`. Fixed in `omnigraph/exec.ail` and `omnigraph/omnigraph.ail`.

## Validation
- All type‑checked modules passed.
- All test suites passed (parse: 27/27, omnigraph: 12/12, dummy extension: 5/5, tool_runtime: 7/7).

## Next Steps
- Authored `Compose_Extension_Extraction_Plan.md` to extract Compose’s extension semantics from core. Known incompatibilities (string concatenation) remain orthogonal to Omnigraph disentangling.

## Connections
- The envelope pattern is foundational for [[Extension Decoupling]].
- Omnigraph tool handling now lives under [[Omnigraph Extension]]; the framework for other tools is defined in [[Tool Envelope Pattern]].
- The future Compose extraction will use a similar phased approach, building on the [[Core/Extension Separation]] model.