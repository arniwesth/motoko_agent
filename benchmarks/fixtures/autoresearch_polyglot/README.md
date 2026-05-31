# Autoresearch Polyglot Fixture

This is the Phase 0.5a warm-up fixture for the autoresearch loop. It optimizes
Motoko's Polyglot scaffolding against Python Exercism tasks without Docker.

## Candidate Surface

The intended initial `scope_paths` is:

- `benchmarks/prompts/polyglot_system.md`

The intended `off_limits` is:

- `benchmarks/aider_polyglot.py`
- `benchmarks/motoko_rpc.py`
- `benchmarks/fixtures/autoresearch_polyglot/`
- `packages/motoko-ext-autoresearch/`
- `/workspaces/polyglot-benchmark/`

The fixture sets `SYSTEM_MD=benchmarks/prompts/polyglot_system.md` before invoking
the runner, so edits to the prompt are live candidate changes.

## Metrics

`pass_rate` is the primary metric and should be maximized:

`pass_rate = (pass_1 + pass_2) / total`

`wall_ms` is a noisy secondary metric and should be minimized.

## Non-Docker Separate Verifier

Docker is unavailable in this environment. The held-out verifier is therefore a
fresh process invocation using a clean scratch directory plus immutable hash checks
and `off_limits` protections. It is weaker than a fresh container, but still keeps
TEST out of `benchmark.sh` and blocks candidate edits to the grader/splits.

## Run

Prepare the local Python verifier once:

```bash
uv venv .motoko/ar_polyglot_py
uv pip install --python .motoko/ar_polyglot_py/bin/python pytest
```

Run TRAIN:

```bash
POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-flash \
  bash benchmarks/fixtures/autoresearch_polyglot/bench/benchmark.sh
```

Run held-out TEST manually:

```bash
POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-flash \
  bash benchmarks/fixtures/autoresearch_polyglot/bench/grade_test.sh
```

The fixture fails fast if `POLYGLOT_MODEL` is set to anything other than
`openrouter/deepseek/deepseek-v4-flash`.
