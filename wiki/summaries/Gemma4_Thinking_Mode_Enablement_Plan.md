---
doc_type: short
full_text: sources/Gemma4_Thinking_Mode_Enablement_Plan.md
---

# Summary: Gemma 4 Thinking Mode Enablement Plan

## Overview
This document outlines a plan to add first-class support for controlling Gemma 4's thinking mode in the Motoko benchmark flow. Instead of prompt hacks, a new benchmark CLI switch (`--thinking on|off|auto`) will be thread through the AI request options to the OpenAI-compatible provider, mapping to `chat_template_kwargs.enable_thinking`. The default behavior remains unchanged.

## Key Design
- **Transport layer**: Reuse `ai.Request.Options` to carry provider-specific controls (see [[concepts/ai-request-options]]).
- **Benchmark surface**: New `--thinking` flag with three modes (`on`, `off`, `auto`). `auto` preserves current behavior. `on`/`off` are rejected for non-OpenAI providers.
- **Environment bridging**: Benchmark CLI serializes options into `MOTOKO_AI_OPTIONS_JSON` env variable, which the runtime decodes and attaches to AI requests.
- **OpenAI payload extension**: `chat_template_kwargs` object added to chat request structs, populated from `Request.Options`.

## Implementation Phases
1. **Benchmark surface**: Add CLI parsing, validation, JSON payload generation, and metadata persistence.
2. **AI options plumbing**: Extend handler/stream call paths to accept options, parse env once, carry through step loop.
3. **OpenAI payload mapping**: Add `chat_template_kwargs` field, map from options in both `chat.go` and `stream_motoko.go`.
4. **Validation and docs**: Add unit/integration tests (ensure field included/omitted correctly, fail-fast behavior), update README with examples.

## Validation
- Unit tests for marshalling and absent/options.
- Integration: captured outbound JSON must contain `chat_template_kwargs.enable_thinking=true|false` when requested, omitted for `auto`.
- Regression: default runs unchanged; non-OpenAI + `on|off` fails fast; no `chat_template_kwargs` on non-OpenAI payloads.

## [[concepts/provider-native-controls]]
The approach avoids model-specific prompt injection by using provider-native APIs (`chat_template_kwargs`), keeping the feature clean and reusable for other provider-specific controls.

## [[concepts/benchmark-cli]]
New `--thinking` switch with strict validation ensures fail-fast behavior for unsupported combos. The CLI owns semantic validation while runtime focuses on safe decode and transport.

## Risks
- Some OpenAI-compatible servers may reject unknown fields; mitigated by `auto` default omitting the field.
- Stream/non-stream divergence prevented by mirrored mapping and tests.