# Motoko Benchmark Harness

## Currently Supported

- Polyglot / Exercism (actively supported):
  - Runner: `benchmarks/aider_polyglot.py`
  - Language descriptors currently implemented: `python`
  - Result schema/status: `pass_1`, `pass_2`, `fail`, `error`
- Smoke test (actively supported):
  - Runner: `benchmarks/smoke.py`
  - Validates preflight + end-to-end event flow.

## Not Yet Fully Supported

- Terminal-Bench adapter:
  - Code exists in `benchmarks/tb_adapter/`, but this repo does not include a turnkey TB runner script.
- Harbor adapter:
  - Placeholder only (`benchmarks/harbor_adapter/`).
- Multi-language Polyglot:
  - Go/Rust/JS/Java descriptors are not wired yet in `aider_polyglot.py`.

## Quick commands

- Smoke test:
  - `python benchmarks/smoke.py --model anthropic/claude-sonnet-4-6`
- Single Polyglot exercise:
  - `python benchmarks/aider_polyglot.py --language python --exercise hello-world --verbose`
- Single Polyglot exercise (local OpenAI-compatible endpoint):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 python benchmarks/aider_polyglot.py --language python --exercise hello-world --model openai/google/gemma-4-26B-A4B-it --verbose`
- Single Polyglot exercise (local endpoint + extensions):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 CORE_EXT_ORDER=context_mode,exa_search python benchmarks/aider_polyglot.py --language python --exercise hello-world --model openai/google/gemma-4-26B-A4B-it --verbose`
- Gemma thinking mode ON (OpenAI-compatible route only):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 python benchmarks/aider_polyglot.py --language python --exercise hello-world --model openai/google/gemma-4-26B-A4B-it --thinking on --verbose`
- Gemma thinking mode OFF (explicit):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 python benchmarks/aider_polyglot.py --language python --exercise hello-world --model openai/google/gemma-4-26B-A4B-it --thinking off --verbose`
- Gemma thinking mode AUTO (default, omit provider key):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 python benchmarks/aider_polyglot.py --language python --exercise hello-world --model openai/google/gemma-4-26B-A4B-it --thinking auto --verbose`
- Full Python track (local endpoint + extensions):
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1 CORE_EXT_ORDER=context_mode,exa_search python benchmarks/aider_polyglot.py --language python --model openai/google/gemma-4-26B-A4B-it --verbose`
- Status summary:
  - `bash benchmarks/status.sh`
- Error breakdown:
  - `python benchmarks/error_breakdown.py`
- Tool failure breakdown:
  - `python benchmarks/tool_failures.py`

## Observability

- Runner heartbeat:
  - `python benchmarks/aider_polyglot.py ... --heartbeat-secs 10 --verbose`
  - Prints periodic progress lines per in-flight exercise with elapsed time, attempt, step, and last event type.
- Live status view:
  - `watch -n 2 'bash /workspaces/ailang_agent/benchmarks/status.sh'`
  - Shows run phase, current exercise, step, last completed exercise, and stale-state warning if no runner process is active.
- Live state file:
  - `benchmarks/results/polyglot_live.json`
- Structured event stream (per run):
  - `benchmarks/results/polyglot_events_<run_id>.jsonl`
- Per-exercise artifacts:
  - `benchmarks/polyglot_logs/<language>/<exercise>/attempt1_events.json`
  - `benchmarks/polyglot_logs/<language>/<exercise>/attempt2_events.json` (if retry happened)
  - `attempt*_thinking.txt`, `attempt*_final.txt`, `tests_output.txt`, and `attempt*_error.txt` on failures.

## Thinking mode behavior

- `--thinking auto` (default): does not send `chat_template_kwargs`.
- `--thinking on`: sends `{"chat_template_kwargs":{"enable_thinking":true}}` through `MOTOKO_AI_OPTIONS_JSON`.
- `--thinking off`: sends `{"chat_template_kwargs":{"enable_thinking":false}}`.
- `--thinking on|off` fails fast unless `--model` uses an `openai/*` route.
- If `MOTOKO_AI_OPTIONS_JSON` is set and malformed, runtime startup fails with a JSON decode error.

## Layout

- `motoko_rpc.py`: JSONL subprocess client for Motoko.
- `aider_polyglot.py`: Exercism/Polyglot runner.
- `tb_adapter/`: Terminal-Bench adapter + shell sidecar.
- `prompts/`: benchmark-specific system prompts.
- `results/`: persisted result JSON files.
- `smoke.py`: preflight + minimal end-to-end validation.
