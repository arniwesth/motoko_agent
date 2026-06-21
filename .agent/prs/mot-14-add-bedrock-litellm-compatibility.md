# Add Amazon Bedrock compatibility via LiteLLM (bearer-token-only)

Base branch: `origin/main`
Branch: `arniwesth/mot-14-add-bedrock-litellm-compability`

## Summary

Motoko can now run against Amazon Bedrock models without any native Bedrock
provider code. Bedrock sits behind a local LiteLLM proxy that exposes an
OpenAI-compatible endpoint, and Motoko reaches it through the existing
`OPENAI_BASE_URL` path:

```
Motoko -> AILANG OpenAI-compatible provider
       -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
       -> LiteLLM  (AWS_BEARER_TOKEN_BEDROCK + AWS_REGION)
       -> Amazon Bedrock
```

Auth is **bearer-token only** — `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` / `~/.aws` are never used and are
stripped from the LiteLLM subprocess. Motoko/AILANG only ever see a dummy
OpenAI key (`motoko-litellm-local`); a real `OPENAI_API_KEY` is never forwarded
to the local proxy.

A new `bedrock` profile mirrors the `observability` profile (same extensions,
clickstack tracing, and verification) but points at Bedrock Claude Opus 4.8 via
the proxy.

Validated end to end against real Bedrock (`eu-north-1`): LiteLLM direct →
AILANG `std/ai.stepWithStream` → Motoko minimal task → native tool-use
(`BashExec`).

> **External dependency (not in this repo's diff):** the feature needs two small
> fixes in the AILANG OpenAI provider's *direct* (provider-guessing) path —
> honoring `OPENAI_BASE_URL`, and relaxing the `OPENAI_API_KEY` guard when a
> custom base URL is set (mirroring the already-fixed configured-model path).
> Those changes live in the AILANG repo, not `motoko_agent`. Until an
> upstream-fixed `ailang` is installed on `PATH`, a locally built binary at
> `ailang/.bin/ailang` is used automatically (see `scripts/run-agent.sh` below).
> `ailang/` is gitignored here.

## Changes

### Bedrock profile + LiteLLM proxy

- **`.motoko/config/bedrock/config.json`** (new) — mirrors `observability`
  (`max_steps: 50`, extensions `compaction_ai, context_mode, exa_search`,
  clickstack tracing, `verification: make check_core`), changing only
  `agent.model = gpt-bedrock-opus-4-8` and
  `agent.openai_base_url = http://127.0.0.1:4000/v1`.
- **`scripts/bedrock-litellm.yaml`** (new) — LiteLLM model map with three
  aliases, each an EU cross-region inference profile:
  - `gpt-bedrock-claude-sonnet-4-5` → `eu.anthropic.claude-sonnet-4-5-20250929-v1:0`
  - `gpt-bedrock-opus-4-8` → `eu.anthropic.claude-opus-4-8`
  - `gpt-bedrock-sonnet-4-6` → `eu.anthropic.claude-sonnet-4-6`
  Aliases must start with `gpt` (not `gpt-5`) and avoid `anthropic`/`claude`/`/`,
  or AILANG's `GuessProvider` routes them off the LiteLLM path; the real Bedrock
  IDs live only in the `model:` lines. Header comment documents the discovery
  one-liner.
- **`scripts/bedrock-proxy.sh`** (new) — starts LiteLLM on `127.0.0.1:4000`.
  Loads `.env`, requires `AWS_REGION` + `AWS_BEARER_TOKEN_BEDROCK` (presence
  reported, values never printed; no `set -x`), strips AWS credential-chain vars
  from the subprocess. Handles shell-quoted `.env` values.

### Make targets

- **`bedrock_proxy`** — runs the proxy script.
- **Layered smokes** (stop at first failure to isolate the failing layer):
  `smoke_bedrock_litellm` → `smoke_bedrock_ailang` → `smoke_bedrock_motoko` →
  `smoke_bedrock_tools`, plus `smoke_bedrock` to run all. Secret-safe (redact
  bearer tokens), logs to `tmp/`. The AILANG layer auto-uses
  `ailang/.bin/ailang` when present.
- **`verify_extensions` profile-propagation fix** — the recipe now derives the
  profile from the Make `$(PROFILE)` variable instead of reading `MOTOKO_CONFIG`
  from the outer shell. Previously `PROFILE=bedrock make run` could verify a
  different profile than the one the `run` recipe booted (an ambient
  `MOTOKO_CONFIG` won). Now an explicit `PROFILE=bedrock` consistently wins.

### Launcher

- **`scripts/run-agent.sh`** — auto-detects the locally built AILANG binary,
  now preferring `ailang/.bin/ailang` (the patched-binary location) and falling
  back to `ailang/bin/ailang`. Only sets `AILANG_BIN` when it is not already set,
  so an explicit override always wins.

### Smoke fixture + docs

- **`scripts/smoke_bedrock_litellm.ail`** (new) — minimal `std/ai.stepWithStream`
  preflight against the proxy.
- **`scripts/smoke_bedrock_litellm.sh`** (new) — layer-1 curl smoke
  (`/v1/models` + `/v1/chat/completions`), redacted/secret-safe.
- **`README.md`** — new "Bedrock through LiteLLM" runbook: install, proxy,
  layered smokes, dummy-key + AWS-creds warnings, inference-profile selection,
  the alias-naming constraint, and the AILANG-binary note.
- **`ailang.lock`** — refreshed by `ailang lock` during `sync_packages`.

### Planning / archive docs (`.agent/`)

- Bedrock integration plans + handoffs under
  `.agent/plans/bedrock-integration/` and a session summary under
  `.agent/summaries/`.
- `.agent/plans/omp-style-python-eval/07-scratchpad-result-context-bloat-fix.md`
  — a separately-scoped plan (not implemented in this PR) for a context-window
  blow-up observed while testing this profile: the scratchpad tool's full
  `metadata.cells` (base64 images + ANSI art) leaks into the model message via
  `result_to_json`. Captured here for follow-up.

## User impact

- New `PROFILE=bedrock` runs Motoko on Bedrock through LiteLLM:
  ```bash
  make bedrock_proxy                       # one terminal
  PROFILE=bedrock MOTOKO_CONFIG=bedrock make run   # another
  ```
- Three Bedrock Claude aliases available; switch via `agent.model` or
  `MODEL=<alias>`.
- No AWS SDK credentials required — just `AWS_REGION` +
  `AWS_BEARER_TOKEN_BEDROCK` in `.env`.

## Verification

Validated against real Bedrock (`eu-north-1`, bearer-token-only):

- `make smoke_bedrock_litellm` — `/v1/models` lists the aliases; chat completion
  returns assistant text.
- `make smoke_bedrock_ailang` — AILANG `stepWithStream` reaches LiteLLM (not
  OpenAI cloud); `finish_reason=stop`.
- `make smoke_bedrock_motoko` — minimal task on `PROFILE=bedrock` replies
  correctly; `model=gpt-bedrock-opus-4-8`.
- Tool-use — model emits `BashExec`, Motoko dispatches it (exit 0), follow-up
  turn accepts the result. No tool-result correlation errors.
- `gpt-bedrock-opus-4-8` and `gpt-bedrock-sonnet-4-6` each return text through
  the proxy.
- `PROFILE=bedrock make verify_extensions` reports the `bedrock` profile (not an
  ambient `MOTOKO_CONFIG`) and all extensions boot.

## Notes / known issues

- The AILANG-side fixes are required and live out-of-tree (see the External
  dependency note above); they are not part of this PR's diff.
- Scratchpad image/graph output can overflow the model context window on
  large-context models — tracked by plan `07-scratchpad-result-context-bloat-fix`
  and intentionally excluded from the `bedrock` profile's `extensions.order`
  for now.
- `oh-my-pi/` (untracked) is unrelated scratch and not part of this branch.
