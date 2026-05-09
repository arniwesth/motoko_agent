# 2026-04-18 — md2audio Qwen TTS, Remote GPU, Modal, and Speech Preprocessing

## Session Goal
Implement `.agent/plans/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md`, get end-to-end Markdown-to-audio working with Qwen3-TTS, and make it practical in a Linux devcontainer on macOS Apple Silicon.

## High-Level Outcome
- Built a full `tools/md2audio` Python package (CLI + pipeline + tests + docs).
- Added robust support for local and remote inference backends.
- Added host-macOS remote inference mode for Apple Silicon GPU (MPS) usage.
- Added Modal serverless GPU deployment path and validated GPU type at runtime.
- Added plan-focused speech preprocessor and SSML-like tag mapping to improve narration quality.
- Resolved multiple real-world integration issues (API drift, endpoint mismatch, path validation, timeouts, device routing).

## Major Implementation Work

### 1) New md2audio package scaffold
Created:
- `tools/md2audio/pyproject.toml`
- `tools/md2audio/README.md`
- `tools/md2audio/src/md2audio/*` modules:
  - `cli.py`
  - `config.py`
  - `markdown_parse.py`
  - `text_normalize.py`
  - `chunking.py`
  - `tts_qwen.py`
  - `audio_assemble.py`
  - `pipeline.py`
- `tools/md2audio/tests/*`
- wrapper script: `scripts/md2audio`

Implemented CLI contract (profiles, model/tokenizer/device, format, chunking, pauses, dry-run, exit codes).

### 2) Qwen3-TTS adapter hardening
`qwen-tts` API mismatch was discovered in environment:
- Installed package used `Qwen3TTSModel.from_pretrained(...)`, not ctor with `model_name_or_path`.
- Patched adapter to support both API shapes.
- Fixed method arg mismatch for voice design (`instruct` vs `prompt`).
- Fixed device bookkeeping bug for MPS path (`Placeholder storage has not been allocated on MPS device!`) by syncing wrapper device after `.to(...)`.

### 3) Local model/tokenizer path support
Added support for:
- `--model` as local directory path
- `--tokenizer` as local directory path
- In remote mode, allow host-only path strings even when they do not exist in client container filesystem.

### 4) Progress and UX improvements
Added stage/chunk progress plus heartbeats:
- stage progress logs
- per-chunk running heartbeat
- per-chunk completion timing, average/chunk, ETA
- provisional ETA while chunk is still running

### 5) Remote inference mode (host server)
Added remote client and host server:
- `src/md2audio/tts_remote.py`
- `src/md2audio/host_server.py`
- CLI flags/env:
  - `--remote-url`, `MD2AUDIO_REMOTE_URL`
  - `--remote-timeout-sec`, `MD2AUDIO_REMOTE_TIMEOUT_SEC`
  - `--remote-api-key`, `MD2AUDIO_REMOTE_API_KEY`

Behavior:
- container client calls host HTTP endpoint for synthesis
- allows using macOS host MPS GPU from Linux devcontainer workflow

### 6) Modal cloud GPU integration
Added deployable Modal app:
- `src/md2audio/modal_app.py`
- optional dependencies in `pyproject.toml` (`modal` extra)
- `gpu_info` endpoint to verify runtime GPU

Modal-specific fixes:
- fixed import packaging issues (`md2audio` module missing in runtime)
- added local source to image with `add_local_dir(..., copy=True)` and `PYTHONPATH`
- fixed endpoint usage expectations (`synthesize` vs `gpu-info`)
- improved remote client endpoint logic for `.modal.run` URLs (root endpoint handling)
- increased Modal function timeout to 1800s
- switched default GPU in `modal_app.py` from L4 back to A100 per user request

## Narration Quality Changes

### 7) Speech preprocessor for plan-like markdown
Added `src/md2audio/speech_preprocess.py` and pipeline integration:
- `--speech-mode plan|general` (default `plan`)
- removes code/noise-heavy content unsuitable for speech
- maps SSML-like tags to plain speech cues
  - `<break .../>`, `<emphasis>`, `<prosody>`, `<say-as>`, `<phoneme>`, `<sub ...>`

### 8) List narration refinement
Changed list rendering to improve naturalness:
- removed `Bullet:` prefix for unordered lists
- removed `Item N:` prefix for ordered lists

## Key Debugging/Resolution Timeline
- Fixed initial `qwen-tts` constructor incompatibility.
- Identified and handled `sox` host/container warnings (mostly non-fatal).
- Implemented remote host mode due to no Apple GPU passthrough into Linux containers.
- Fixed FastAPI body binding issue causing `422` (`req` treated as query param).
- Improved remote error surfacing with response body details.
- Fixed host path mismatch errors (`Repo id must be ...` from invalid local path).
- Fixed wrong endpoint usage errors (`405` from `gpu-info` URL used for synthesis).
- Added Modal deployment/runtime fixes and verified GPU details.

## Confirmed Working States During Session
- Local CLI dry-run and tests pass repeatedly (`pytest` green across updates).
- Host macOS remote mode working and confirmed `device=mps` in logs.
- Modal deployment working and GPU verified via `/gpu_info`:
  - `cuda_available: true`
  - device reported as NVIDIA GPU (A10/L4/A100 depending on deploy setting).
- End-to-end synth succeeded with output written to:
  - `/workspaces/ailang_agent/tools/md2audio/plan2.wav`
  - `/workspaces/ailang_agent/tools/md2audio/plan2.wav.manifest.json`

## Notable Operational Lessons
- On Apple Silicon devcontainers, GPU passthrough for generic Linux CUDA/MPS workloads is unavailable; use host remote service or cloud GPU.
- Endpoint confusion (`gpu-info` vs `synthesize`) is a frequent failure mode.
- First request latency can be large due to model load/download; high client timeout and smaller chunk sizes help.
- Absolute output path avoids confusion about where audio artifacts land.

## Files Touched (representative)
- `.devcontainer/Dockerfile`
- `scripts/md2audio`
- `tools/md2audio/README.md`
- `tools/md2audio/pyproject.toml`
- `tools/md2audio/src/md2audio/{cli.py,config.py,markdown_parse.py,text_normalize.py,chunking.py,tts_qwen.py,tts_remote.py,audio_assemble.py,pipeline.py,host_server.py,modal_app.py,speech_preprocess.py}`
- `tools/md2audio/tests/{test_normalize.py,test_chunking.py,test_pipeline_smoke.py,test_config.py,test_speech_preprocess.py}`

## Current Status at End of Session
- `md2audio` is functional with:
  - local backend
  - host remote backend
  - Modal backend
- Speech preprocessor is integrated and tuned for plan-style technical markdown.
- Modal default GPU is set to `A100` in code.
