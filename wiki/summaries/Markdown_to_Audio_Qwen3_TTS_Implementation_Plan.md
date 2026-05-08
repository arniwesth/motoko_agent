---
doc_type: short
full_text: sources/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md
---

# Markdown to Audio – Qwen3‑TTS Implementation Plan

## Overview
This document specifies the design and phased implementation of `md2audio`, a local CLI tool that converts a Markdown file into a single spoken audio file (WAV/MP3) using the [[concepts/qwen3-tts]] family as the sole TTS runtime backend. The plan is grounded in findings from the [[papers/Qwen3_TTS]] technical report and a validated [[docs/model_allowlist]] from Phase 0.

## Core Architecture
The system follows a deterministic pipeline:
1. **Input** – Read Markdown file.
2. **Narration‑normalization** – Convert Markdown to spoken‑form plain text according to a set of [[concepts/markdown-narration-rules]] (headings, lists, links, code blocks, tables).
3. **Chunking** – Sentence‑ or paragraph‑aware segmentation with a character budget and carry‑over logic to support [[concepts/long‑form-speech]].
4. **Synthesis** – Each chunk is passed to a [[concepts/qwen3-tts-backend]] adapter that loads the model/tokenizer and returns raw audio.
5. **Assembly** – Insert pauses, concatenate chunks, and export the final audio file.

## Key Decisions
- **Backend exclusivity**: Only Qwen3‑TTS for MVP; alternate [[concepts/tts-backends]] (Kokoro, Chatterbox) are deferred.
- **Chunking independence**: The chunker is kept backend‑agnostic to simplify future swaps.
- **Device auto‑detection**: `cuda` preferred on bare‑metal Linux; `cpu` fallback, with explicit `cpu` path for Linux Docker on macOS Apple Silicon.
- **Profiles** to balance quality vs. latency:
  - `longform` → default `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` for high‑quality narration.
  - `realtime` → default `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` for lower‑latency streaming.
  - Experimental 25 Hz support is gated behind explicit model override, pending full availability validation.

## Phased Implementation
- **Phase 0 (completed)** – Feasibility spike: validate official model/tokenizer IDs; produce first WAV from a 12 Hz model; document findings in `docs/model_allowlist.md`.
- **Phase 1** – Project scaffold, CLI skeleton, argument parsing, `--help`.
- **Phase 2** – Markdown parser + narrative normalizer with unit tests covering all [[concepts/markdown-narration-rules]].
- **Phase 3** – Chunking engine with manifest output and carry‑over handling.
- **Phase 4** – Qwen adapter integration; end‑to‑end synthesis of all chunks for a medium markdown file.
- **Phase 5** – Audio assembly with silence insertion, concatenation, and dual‑format export (WAV, optional MP3).
- **Phase 6** – Test suite (unit, smoke, failure paths) plus CI compatibility.
- **Phase 7** – Documentation, example commands, and troubleshooting for Linux and Docker on macOS Apple Silicon.

## Risks and Mitigations
- **Apple Silicon Docker regression** – Enforce CPU‑only path with dedicated Docker setup notes.
- **Memory pressure on long documents** – Chunk‑by‑chunk synthesis and optional streamed concat.
- **Model/tokenizer pairing errors** – Startup validation with actionable error messages.
- **Upstream API drift** – Pinned dependency versions in `pyproject.toml`.

## Future Extensions
Once MVP is stable, the plan considers multi‑speaker scripting, SSML‑like markup, HTTP service mode, and integration of additional TTS backends.

## Related Concepts
- [[concepts/long-form-speech]]
- [[concepts/qwen3-tts]] – The primary synthesis model family.
- [[concepts/markdown-narration-rules]] – The rule set for converting Markdown into spoken text.
- [[concepts/long‑form-speech]] – Strategies for stable synthesis over >10 minutes.
- [[concepts/chunking-for-synthesis]] – Deterministic segmentation for large inputs.
- [[concepts/tts-backends]] – Alternative engines and their interface design.
- [[concepts/voice-profiles]] – Speaker selection and instruction parameters.