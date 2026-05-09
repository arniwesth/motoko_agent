# Markdown to Audio (Qwen3-TTS) Implementation Plan

Status: Ready for execution
Owner: `tools/md2audio` (new)
Primary model family: `Qwen3-TTS`
Implementation language: `Python 3.11+`
Primary runtime stack: `qwen-tts` + `PyTorch`

## 0. Paper Grounding (`papers/Qwen3_TTS.md`)
This plan is grounded in the local technical report and uses the following findings as hard assumptions:
- Qwen3-TTS provides two tokenizer/model tracks with different operating points:
  - `12Hz` track: optimized for ultra-low-latency streaming and strong zero-shot/content consistency.
  - `25Hz` track: semantic-rich track with stronger long-speech stability in reported long-form experiments.
- Supported language set is 10 major languages (zh, en, ja, ko, de, fr, ru, pt, es, it).
- Reported streaming design details include `12.5 Hz` token rate and packetization choices (4-token packets, 320 ms speech per packet).
- Reported model scales are `0.6B` and `1.7B`, with consistent gains from scaling in benchmark tables.
- Reported long-speech robustness is validated on >10 minute samples; our markdown narration workflow is aligned with this long-form target.

Implementation consequence:
- Keep Qwen3-TTS as sole backend for MVP.
- Expose both 12Hz and 25Hz model families.
- Provide an explicit profile switch so users can choose low-latency vs long-form stability.

## 1. Goal
Build a local CLI program that converts a Markdown file into a single spoken audio file on Linux (including Linux Docker on macOS Apple Silicon), using Qwen3-TTS as the first and only runtime backend for this implementation.

## 2. Scope
In scope:
- Local file input (`.md`) and local audio output (`.wav`, optional `.mp3` export).
- Markdown-to-speech text normalization suitable for narration.
- Qwen3-TTS inference backend with model/config selection.
- Chunked synthesis and deterministic concatenation.
- Basic CLI UX, logging, and error handling.
- Automated tests for parsing/chunking/pipeline behavior.

Out of scope (explicitly deferred):
- Alternate TTS backends (Kokoro/Chatterbox).
- Web UI/service deployment.
- Multi-speaker scripted dialogue synthesis.
- Fine-tuning or training.

## 3. Product Requirements
- Input: Markdown file path.
- Output: single audio artifact in an output directory.
- Default behavior must be non-interactive and scriptable.
- Works offline once model weights are present locally.
- Reasonable defaults for long documents (chunking + pauses).

## 4. CLI Contract (MVP)
Command:
- `md2audio <input.md> --out <output.wav>`

Core flags:
- `--profile` (`longform|realtime`, default `realtime`)
- `--model` (optional override; default resolved from `--profile`)
- `--tokenizer` (optional override; default resolved from selected model family)
- `--device` (`auto|cuda|cpu`, default: `auto`)
- `--voice` (Qwen voice preset name for CustomVoice models)
- `--instruction` (style/prosody guidance)
- `--max-chars` (chunk size, default ~1400)
- `--pause-ms` (inter-chunk silence, default 300)
- `--format` (`wav|mp3`, default `wav`)
- `--sample-rate` (default model-native, optional resample)
- `--cache-dir` (model cache override)
- `--keep-chunks` (debug; save intermediate chunk wav files)
- `--dry-run` (emit normalized/chunked text only)

Profile behavior:
- `longform`:
  - default model family: `Qwen3-TTS-12Hz-*` (released, stable path).
  - default model: `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`.
  - optimized for higher-quality markdown narration using released checkpoints.
  - experimental option: 25Hz family may be enabled by explicit model override only after availability validation.
- `realtime`:
  - default model family: `Qwen3-TTS-12Hz-*`
  - default model: `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`.
  - optimized for lower-latency streaming-like behavior.

Exit codes:
- `0` success
- `2` invalid input/args
- `3` model/runtime init failure
- `4` synthesis failure
- `5` post-processing/export failure

## 5. Proposed File Layout
New package (Python):
- `tools/md2audio/pyproject.toml`
- `tools/md2audio/README.md`
- `tools/md2audio/src/md2audio/__init__.py`
- `tools/md2audio/src/md2audio/cli.py`
- `tools/md2audio/src/md2audio/config.py`
- `tools/md2audio/src/md2audio/markdown_parse.py`
- `tools/md2audio/src/md2audio/text_normalize.py`
- `tools/md2audio/src/md2audio/chunking.py`
- `tools/md2audio/src/md2audio/tts_qwen.py`
- `tools/md2audio/src/md2audio/audio_assemble.py`
- `tools/md2audio/src/md2audio/pipeline.py`
- `tools/md2audio/tests/test_normalize.py`
- `tools/md2audio/tests/test_chunking.py`
- `tools/md2audio/tests/test_pipeline_smoke.py`

Optional integration helpers:
- `scripts/md2audio` (shell wrapper)

## 6. Architecture
Pipeline stages:
1. Read markdown.
2. Convert markdown to narratable plain text.
3. Normalize text (headings, lists, links, code handling).
4. Chunk by sentence/paragraph with size cap.
5. Synthesize each chunk via Qwen3-TTS.
6. Concatenate with configurable pauses.
7. Export final artifact and metadata.

Key design choices:
- Keep TTS backend behind a simple interface (`synthesize(text) -> np.ndarray`).
- Preserve deterministic chunk ordering and naming.
- Make chunking independent of model to support future backend swap later.

## 7. Markdown Narration Rules (MVP)
- Headings: read as plain heading text with a pause.
- Paragraphs: keep as-is with punctuation cleanup.
- Bullet lists: prepend "Bullet:".
- Numbered lists: prepend "Item N:".
- Links: keep anchor text; drop URL by default.
- Images: drop image URLs; optionally read alt text if present.
- Code blocks: default skip with marker phrase "Code block omitted." (configurable).
- Inline code: read token literally, bounded by cleanup rules.
- Tables: flatten row-wise, with cell separators.

## 8. Qwen3-TTS Backend Plan
Runtime adapter responsibilities:
- Load model/tokenizer from local cache or Hugging Face.
- Resolve device from `auto` policy:
  - Linux: prefer `cuda`, fallback `cpu`.
  - Linux Docker on macOS Apple Silicon: use `cpu` unless GPU passthrough is explicitly available.
- Handle instruction/voice parameters per selected Qwen variant.
- Return PCM float32 waveform + sample rate.

Model policy:
- Default profile for first-run reliability: `realtime` (released 12Hz model).
- Recommended profile for narrated quality on capable hardware: `longform` (still 12Hz released family by default).
- `longform` default model:
  - `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`.
- `realtime` default model:
  - `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`.
- Allow override to `1.7B` variants via `--model` for quality gains.
- Ensure tokenizer/model family consistency validation:
  - 12Hz models must pair with `Qwen3-TTS-Tokenizer-12Hz`.
  - 25Hz models must pair with corresponding 25Hz tokenizer.
- Document expected resource and latency profiles for each family and model tier.

## 9. Post-Processing Plan
- Normalize amplitude (peak limiter; optional LUFS pass deferred).
- Insert fixed silence between chunk files.
- Concatenate in-memory for small/medium runs; streamed concat for large runs.
- WAV export via `soundfile`; MP3 export via `ffmpeg` when available.

## 10. Phased Implementation

### Phase 0: Feasibility Spike
Status: Completed (2026-04-11)

Deliverables:
- Validate and freeze an allowlist of actually available Hugging Face model IDs/tokenizer IDs for MVP defaults.
- Verify one-shot local synthesis from released 12Hz models.
- Optionally probe one 25Hz model only if availability is confirmed during allowlist validation.
- Record exact dependency versions and device matrix behavior (Linux CUDA/CPU and Linux Docker on macOS Apple Silicon CPU).

Exit criteria:
- `docs/model_allowlist.md` (or equivalent section in README) listing validated model/tokenizer IDs.
- Reproducible commands that create valid WAV for at least one released 12Hz model.
- If no public 25Hz model is validated, plan defaults remain fully 12Hz without blocking MVP.

Completion notes:
- Allowlist created: `docs/model_allowlist.md`.
- Public official 12Hz model/tokenizer IDs validated and recorded.
- 25Hz official IDs checked and marked non-public in current validation environment.

### Phase 1: Project Scaffold + CLI Skeleton
Deliverables:
- Python package skeleton and argument parsing.
- Config object and logging scaffold.

Exit criteria:
- `md2audio --help` and input validation tests pass.

### Phase 2: Markdown Parsing + Normalization
Deliverables:
- Parser + narration normalization rules from section 7.
- Unit tests for headings/lists/code/tables/links behavior.

Exit criteria:
- Deterministic normalized text for fixture markdown files.

### Phase 3: Chunking Engine
Deliverables:
- Paragraph/sentence-aware chunker with max char budget and carry-over logic.
- Chunk manifest (`json`) for debug mode.

Exit criteria:
- Stable chunk boundaries and no dropped text.

### Phase 4: Qwen Adapter Integration
Deliverables:
- `tts_qwen.py` model loader + synthesis function.
- CLI flags mapped to backend options.

Exit criteria:
- End-to-end synthesis of all chunks for a medium markdown file.

### Phase 5: Audio Assembly + Export
Deliverables:
- Silence insertion + concatenation + output export.
- Optional mp3 conversion path guarded by ffmpeg availability.

Exit criteria:
- Final output audio is playable and duration roughly matches expected speech length.

### Phase 6: Tests + Reliability
Deliverables:
- Unit tests for normalization/chunking.
- Smoke test with mocked synthesizer.
- Failure-path tests (missing model, bad markdown, ffmpeg absent for mp3).

Exit criteria:
- Test suite passes in CI-compatible environment.

### Phase 7: Docs + Usability
Deliverables:
- README with install/run/troubleshooting.
- Example commands for Linux and Linux Docker on macOS Apple Silicon.
- Notes on expected model download size and runtime memory.

Exit criteria:
- New user can run first conversion without code changes.

## 11. Acceptance Criteria (MVP)
- Converts a real markdown document to a single WAV via one command.
- Produces no missing/duplicated chunk content.
- Works on Linux (CUDA preferred, CPU fallback) and in Linux Docker on macOS Apple Silicon (CPU path).
- Handles documents with headings, lists, links, tables, and code blocks without crashing.
- Provides clear errors for model init/download/runtime failures.
- Includes profile-driven defaults that use validated released models; 25Hz usage is experimental and opt-in until validated.

## 12. Risks and Mitigations
- Container runtime differences on macOS Apple Silicon:
  - Mitigation: support contract is Linux container CPU path; provide Docker-specific setup and tested base image notes.
- Long-doc memory pressure:
  - Mitigation: chunk-by-chunk synthesis and streamed concat mode.
- Runtime API drift in upstream Qwen package:
  - Mitigation: pin tested versions in `pyproject.toml` and lock file.
- Latency for large models:
  - Mitigation: default to 0.6B model; document 1.7B tradeoffs.
- 12Hz vs 25Hz mismatch with workload:
  - Mitigation: explicit profile switch and documented guidance:
    - markdown/audiobook narration -> prefer `longform` (1.7B released default),
    - interactive streaming scenarios -> prefer `realtime` (12Hz).
- Model/tokenizer pairing mistakes:
  - Mitigation: startup-time validation with actionable error messages.

## 13. Deferred Future Work
- Add backend interface implementations for Kokoro and Chatterbox.
- Add optional speaker scripting for multi-voice narration.
- Add SSML-like markup for pauses/emphasis.
- Add HTTP service mode and batch folder processing.

## 14. Source References
- Qwen3-TTS repository: `https://github.com/QwenLM/Qwen3-TTS`
- Qwen3-TTS model cards: `https://huggingface.co/collections/Qwen/qwen3-tts`
- Local report grounding: `papers/Qwen3_TTS.md`
- Phase 0 allowlist artifact: `docs/model_allowlist.md`
