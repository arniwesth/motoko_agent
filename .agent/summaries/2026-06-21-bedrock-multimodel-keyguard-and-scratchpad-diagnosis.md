# 2026-06-21 Bedrock: multi-model, key-guard fix, profile mirror, scratchpad-bloat diagnosis

Continuation of `2026-06-21-bedrock-litellm-integration.md`. That summary covered
the initial LiteLLM-first integration; this session hardened it into a usable
daily-driver profile, added more models, fixed a second AILANG guard, and
diagnosed a context-window blow-up. Branch:
`arniwesth/mot-14-add-bedrock-litellm-compability`.

## Starting state

The Bedrock-via-LiteLLM integration already existed (config, smoke `.ail`, plans).
The AILANG `OPENAI_BASE_URL` direct-fallback fix + regression test were already
present in the `ailang/` checkout's **working tree** (uncommitted), but the
**installed** `ailang` on PATH (v0.24.2) predated it. The locally built
`ailang/.bin/ailang` carried the fix.

## What was done

### 1. Made `PROFILE=bedrock` actually runnable
- `scripts/run-agent.sh`: auto-detect prefers `ailang/.bin/ailang` (patched
  binary), falls back to `ailang/bin/ailang`, and only sets `AILANG_BIN` when
  unset (explicit override wins).
- `Makefile`: `verify_extensions` now derives the profile from `$(PROFILE)`
  instead of reading `$MOTOKO_CONFIG` from the outer shell — fixes the
  propagation bug where `PROFILE=bedrock make run` verified a *different* profile
  than it booted (an ambient `MOTOKO_CONFIG=observability` was winning).
- Added `make bedrock_proxy` + layered smokes
  (`smoke_bedrock_litellm → _ailang → _motoko → _tools`, plus `smoke_bedrock`),
  secret-safe, logs to `tmp/`.
- Added `scripts/bedrock-proxy.sh` (loads `.env`, requires `AWS_REGION` +
  `AWS_BEARER_TOKEN_BEDROCK`, strips AWS credential-chain vars, no secret
  printing) and `scripts/smoke_bedrock_litellm.sh` (redacted curl smoke).
- README "Bedrock through LiteLLM" rewritten as a runbook.

Validated all four smoke layers end-to-end against **real Bedrock**
(`eu-north-1`, bearer-token-only): LiteLLM direct → AILANG `stepWithStream`
(`finish_reason=stop`) → Motoko minimal (`bedrock smoke ok`) → tool-use
(`BashExec`, exit 0, follow-up turn accepts result).

### 2. Renamed the alias to name the real model
`gpt-bedrock-smoke` → `gpt-bedrock-claude-sonnet-4-5` across all 6 live files in
lockstep (the alias is both the AILANG `--ai` name *and* the LiteLLM
`model_name`). Documented the **naming constraint**.

### 3. Added Opus 4.8 + Sonnet 4.6
`scripts/bedrock-litellm.yaml` now serves three aliases:
`gpt-bedrock-claude-sonnet-4-5`, `gpt-bedrock-opus-4-8`, `gpt-bedrock-sonnet-4-6`
→ `eu.anthropic.claude-{sonnet-4-5-20250929-v1:0, opus-4-8, sonnet-4-6}`.
Each verified to invoke through Bedrock.

### 4. Mirrored the bedrock profile from observability
`.motoko/config/bedrock/config.json` now mirrors `observability` (extensions,
clickstack tracing, `verification: make check_core`) with only `agent.model =
gpt-bedrock-opus-4-8` and `openai_base_url = http://127.0.0.1:4000/v1` changed.
(`scratchpad` is intentionally **not** in `extensions.order` — see §6.)

### 5. Fixed the OPENAI_API_KEY guard in the AILANG *direct* path
Interactive `make run PROFILE=bedrock` (without the dummy key the smoke targets
set) failed with `OPENAI_API_KEY environment variable required`. Root cause: the
`M-AI-OPENAI-LOCAL-ENDPOINT-RELAX` relaxation (a custom `OPENAI_BASE_URL` stands
in for the key) was applied to `setupAIHandlerFromConfig` and `executeAPI` but
**not** `setupAIHandlerDirect` — the exact path `gpt-bedrock-*` aliases take.
Relaxed it there too (`ailang/cmd/ailang/ai_handlers.go`), added two regression
tests (`openai_local_endpoint_test.go`), rebuilt `ailang/.bin/ailang`, and
verified with `OPENAI_API_KEY` fully unset. (Still uncommitted/out-of-tree per
the user's earlier "leave as-is" delivery choice.)

### 6. Diagnosed the scratchpad context-window blow-up
A scratchpad run rendering graphs hit
`ContextWindowExceededError: 1,460,049 tokens > 1,000,000`. Root cause traced
hop-by-hop: the env-server returns a 50 KB-capped `stdout` transcript **plus**
the uncapped `cells` (base64 images + ANSI); `env_client.ail:144` keeps the whole
response as `metadata`; `result_to_json` (`tool_contract.ail:38`) serializes
`metadata` into the **model** tool message at `agent_loop_v2.ail:776`/`:799`.
The base64-to-TUI flow is *intended* (plan 04 inline images), so the fix must
split brain→TUI (keep full cells) from brain→model (slim). Wrote
`.agent/plans/omp-style-python-eval/07-scratchpad-result-context-bloat-fix.md`
(not implemented — `result_to_model_json` that drops `cells`/`images` + an
absolute content cap).

### 7. PR description
`.agent/prs/mot-14-add-bedrock-litellm-compatibility.md`, grounded in the real
`main...HEAD` diff.

## Key learnings / gotchas

- **AILANG `GuessProvider` (`internal/ai/config.go`) routes by name.** A model
  alias on the LiteLLM path must start with `gpt` (not `gpt-5`/`o1`/`o3`/`codex`,
  which hit the OpenAI Responses API) and must **not** start with `claude` or
  contain `anthropic` (→ direct Anthropic API) or look like `vendor/model`
  (→ OpenRouter). So the raw `eu.anthropic.claude-...` Bedrock ID can't be the
  alias; the real ID lives only in the LiteLLM `model:` line.
- **The Bedrock bearer token works against the control plane.** No AWS CLI /
  SigV4 needed: `curl -H "Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK"
  https://bedrock.$AWS_REGION.amazonaws.com/foundation-models` lists invokable
  models. `list-inference-profiles` is stale (only returned Sonnet 4); use
  `foundation-models` and prefix `eu.` for the EU cross-region profile.
- **`.env` values may be shell-quoted** (`AWS_REGION="eu-north-1"`); a raw
  `sed`-based reader must strip surrounding quotes or LiteLLM rejects
  `'"eu-north-1"'`.
- **`pkill -f <pattern>` self-matches** — the running Bash tool's own command
  line contains the pattern string, so `pkill -f litellm` kills the shell
  (exit 144). Manage the proxy by PID (pidfile) or port instead.
- **`make -n` runs recipes containing `$(MAKE)`** even in dry-run (and
  propagates `-n`), so nested `make run` smokes appear to "fail" under `-n`
  because the inner run is also dry — not a real failure.
- **The AILANG key relaxation was applied inconsistently** (configured path +
  executeAPI, but not the direct fallback) — a reminder to audit *all* parallel
  dispatch paths when adding a guard.

## State at session end

- Branch changes committed (config, Makefile, scripts, README, plans, PR/summary
  docs). Uncommitted: a trivial `.gitignore` trailing-newline change. Untracked:
  unrelated `oh-my-pi/`.
- AILANG changes (both relaxations + tests) remain in the `ailang/` checkout
  working tree, out-of-tree relative to this repo, built into `ailang/.bin/ailang`.
- LiteLLM proxy serving 3 aliases on `127.0.0.1:4000` (pid in
  `tmp/bedrock-proxy.pid`).

## Follow-ups

- Implement plan 07 (scratchpad result slimming) before re-enabling `scratchpad`
  in the bedrock profile.
- Decide AILANG fix delivery (commit/upstream) — currently working-tree only.
- Optional: install a patched `ailang` system-wide so smokes pass without
  `ailang/.bin/ailang`.
