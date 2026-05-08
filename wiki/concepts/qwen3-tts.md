---
sources: [summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md]
brief: Qwen3‑TTS: a text‑to‑speech model family with 12Hz and 25Hz tracks, scalable 0.6B/1.7B models, and 10‑language support.
---

# Qwen3‑TTS Model Family

## Definition
Qwen3‑TTS is the primary text‑to‑speech synthesis family used in the `md2audio` Markdown‑narration pipeline. It originates from the Qwen team and provides state‑of‑the‑art zero‑shot voice cloning, multi‑lingual support, and streaming‑optimised inference. The design choices in [[summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan]] are deeply grounded in the Qwen3‑TTS technical report and its reported capabilities.

## Model Architecture & Tracks
Qwen3‑TTS offers two operating tracks, each with a dedicated tokenizer and a family of model checkpoints:

- **12 Hz track** – Optimised for ultra‑low‑latency streaming and strong zero‑shot content consistency. It operates at a token rate of 12.5 Hz, packing 4 tokens into every 320 ms of generated speech.
- **25 Hz track** – A semantic‑richer variant that exhibits superior long‑speech stability in reported long‑form experiments (>10 minutes). This track is currently less widely released and treated as experimental in the `md2audio` pipeline.

The two tracks are not interchangeable; each requires its own tokenizer (e.g., `Qwen3-TTS-Tokenizer-12Hz` for 12 Hz models) and model pairing. Startup‑time validation enforces this consistency.

## Model Scales
Both tracks are available in two sizes:

- **0.6B parameters** – A lightweight option for real‑time and resource‑constrained environments. It serves as the default for the `realtime` profile.
- **1.7B parameters** – The higher‑quality variant, with reported gains in naturalness and long‑form robustness. It is the default for the `longform` profile.

Scaling from 0.6B to 1.7B consistently improves benchmark scores, and the plan recommends the 1.7B model when hardware permits.

## Multilingual Support
Qwen3‑TTS natively supports 10 major languages: Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, and Italian. The `md2audio` pipeline is designed around this set, and no further language expansion is planned for MVP.

## Streaming Design
A distinctive feature of Qwen3‑TTS is its streaming‑ready architecture. The 12 Hz track’s fixed‑rate tokenisation and packetised output (4 tokens per 320 ms) allow for chunk‑by‑chunk synthesis without waiting for the entire text. This characteristic directly informs the [[concepts/chunking-for-synthesis]] strategy used in the pipeline.

## Role in the Implementation Plan
Qwen3‑TTS is the sole TTS runtime backend for the initial version of `md2audio`. The pipeline’s [[concepts/qwen3-tts-backend]] adapter encapsulates model loading, device selection, and parameter mapping (voice preset, instruction). The adapter ensures that:
- The correct tokenizer is used for the selected model family (12 Hz or 25 Hz).
- Device selection follows `auto` policy: `cuda` on bare‑metal Linux, `cpu` as fallback, and explicit `cpu` for Docker on Apple Silicon.
- Default models are chosen per profile: `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` for `longform` and `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` for `realtime`.

For the authoritative list of validated and publicly available model IDs, refer to [[docs/model_allowlist]].

## Relationship to Other Concepts
- [[concepts/long‑form-speech]] – Qwen3‑TTS’s 25 Hz track and 1.7B model are particularly well‑suited for >10 minute narration.
- [[concepts/chunking-for-synthesis]] – The 12 Hz streaming guarantees make sentence‑level chunking a natural fit.
- [[concepts/tts-backends]] – Qwen3‑TTS is the first backend implemented; the abstract interface is designed to eventually accommodate other engines.
- [[concepts/voice-profiles]] – The `--voice` and `--instruction` flags directly map to Qwen3‑TTS’s CustomVoice capabilities.
- [[summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan]] – The full design document that operationalises these model choices.