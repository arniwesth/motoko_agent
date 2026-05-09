---
doc_type: short
full_text: sources/2026-04-18-md2audio-qwen-modal-and-speech-preprocessing.md
---

# 2026-04-18 md2audio Qwen TTS Implementation Summary

This session delivered a fully functional `tools/md2audio` Python package that converts Markdown documents to spoken audio using Qwen3-TTS. The implementation supports three inference backends—local, remote host (macOS Apple Silicon), and [[concepts/modal-serverless-gpu-deployment|Modal serverless GPU]]—and includes a dedicated [[concepts/speech-preprocessing-for-technical-text|speech preprocessor]] tuned for plan‑style technical Markdown.

## Key Achievements
- Built the `md2audio` CLI, pipeline, and test suite.
- Hardened the [[concepts/qwen3-tts-integration|Qwen3-TTS adapter]] to handle API mismatches and device‑routing bugs (especially MPS).
- Added [[concepts/remote-inference-for-devcontainers|remote inference mode]] that lets a Linux devcontainer on Apple Silicon use the host’s MPS GPU via HTTP.
- Deployed a Modal serverless app with GPU endpoint, runtime GPU detection, and high client timeouts.
- Integrated a speech preprocessor that strips noise‑heavy content (code blocks, tables) and maps SSML‑like markup to natural speech cues; list narration was refined for better flow.
- Resolved numerous real‑world integration issues: endpoint mismatches, path validation, FastAPI binding errors, first‑request latency handling, and Modal packaging.

## Design Decisions & Patterns
- The pipeline processes documents in chunks with configurable pauses, providing stage‑level progress, heartbeats, and ETA estimates.
- Remote backends decouple inference from the container filesystem; path‑only host‑side model/tokenizer references are allowed.
- Speech preprocessing is controlled by a `--speech-mode` flag (`plan` or `general`), enabling different content‑filtering strategies.
- Absolute output paths are used to avoid ambiguity about where generated `.wav` files land.

## Operational Lessons
- GPU passthrough into Linux containers on Apple Silicon is unavailable; use a host remote service or cloud GPU ([[concepts/remote-inference-for-devcontainers]]).
- Endpoint confusion (`gpu-info` vs `synthesize`) is a common error; clear client logic and explicit root‑endpoint handling mitigate it.
- Large model load/download times require high client timeouts and smaller chunk sizes ([[concepts/modal-serverless-gpu-deployment]]).

## Status at Session End
`md2audio` is operational with all three backends, the speech preprocessor is integrated and validated for plan‑style content, and the Modal default GPU is set to A100 as requested.