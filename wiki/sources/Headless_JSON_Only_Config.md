# Headless Motoko: JSON-Only Config with CLI Args

## Context

Motoko's config system currently has a complex four-layer precedence chain:
hardcoded defaults < `.env`/`.export` files < JSON profile files < shell env vars.
This creates ambiguity (which layer set a value?), requires
`MOTOKO_SHELL_ENV_KEYS` hacks, and scatters 37+ `getEnvOr` calls across 9 AILANG
files.

The user decided to simplify radically: **drop env var config entirely for
non-secrets**. Config comes from JSON profiles + hardcoded defaults. One-off
overrides use CLI args. Only API key secrets remain as env vars.

This enables fully headless operation where the AILANG supervisor is the sole
entry point — no TypeScript TUI required.

## Config model (new)

```
Precedence:  hardcoded defaults  <  profile JSON  <  CLI args
Secrets:     env vars only (ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.)
Profile:     --profile CLI arg (default: "default", fallback: MOTOKO_CONFIG env)
One-offs:    --model, --workdir, --port, --ext-order, --system-prompt
Task:        positional CLI arg (last non-flag argument)
```

## CLI arg interface

```bash
ailang run --entry main --caps IO,FS,Env,Process,Net,AI,SharedMem,Clock,Stream \
  src/core/supervisor.ail -- \
  --profile benchmark \
  --model openai/gpt-4o \
  --workdir /path/to/repo \
  --port 9090 \
  --ext-order compose,context_mode \
  --system-prompt ./SYSTEM.md \
  "Fix the off-by-one in parse_config"
```

Supported flags parsed from `getArgs()`:

| Flag | Type | Default | Purpose |
|------|------|---------|---------|
| `--profile` | string | `"default"` | Config profile name or absolute path |
| `--model` | string | `""` | Model override (beats profile JSON) |
| `--workdir` | string | `""` | Working directory override |
| `--port` | int | `0` (use JSON) | Backend port override |
| `--ext-order` | string | `""` | Extension order override (comma-separated) |
| `--system-prompt` | string | `""` | System prompt file override |
| `--no-backend` | flag | `false` | Skip backend startup (test/config mode) |
| positional | string | `""` | Task text |

`--profile` also falls back to `MOTOKO_CONFIG` env var for backwards compat.

---

## Phase 1 — CLI arg parser and simplified config loading

**Goal:** Add CLI arg parsing to config.ail alongside existing env overlay logic.
Both paths work — no breakage.

### Files to modify

**`src/core/config.ail`** — Add:

- `CliOverrides` record type:
  ```
  type CliOverrides = {
    profile: string, model: string, workdir: string,
    port: int, ext_order: string, system_prompt: string,
    no_backend: bool, task: string
  }
  ```
- `parse_cli_args(args: [string]) -> CliOverrides` — pure recursive parser,
  pattern-matches `--flag value` pairs, last positional arg = task
- `load_config_from_cli(args: [string]) -> RuntimeConfig ! {Env, FS, IO}` —
  new entry point that reads profile from CLI `--profile` (falling back to
  `MOTOKO_CONFIG` env), loads JSON, applies CLI overrides, skips env overlay
- `load_invocation_from_cli(args: [string]) -> InvocationConfig` — pure,
  extracts task/model/workdir from parsed CLI args
- Inline tests for `parse_cli_args`: empty args, all flags, positional task,
  unknown flags ignored, mixed order

**`src/core/supervisor.ail`** — Switch to `load_config_from_cli(getArgs())`.

### What stays unchanged

`load_runtime_config()` and `load_invocation_config()` keep working with env
overlay for the TUI path (rpc.ail still calls them).

---

## Phase 2 — Thread RuntimeConfig through rpc.ail

**Goal:** Remove all direct `getEnvOr` calls from rpc.ail. Every config value
comes from RuntimeConfig or InvocationConfig, passed through function parameters.

### Files to modify

**`src/core/rpc.ail`** — Replace env reads with config fields:

| Current env read | Replacement |
|---|---|
| `parse_env_int("AI_MAX_STEPS", 50)` in `compute_budget_plan` | `cfg.agent.max_steps` passed as parameter |
| `getEnvOr("SEMI_FORMAL_VERIFIER_MODE", "0")` | Add `semi_formal_verifier_mode: bool` to AgentConfig; use `cfg.agent.semi_formal_verifier_mode` |
| `getEnvOr("AILANG_SNIPPET_CAPS", "IO,FS,Process")` | `cfg.tools.snippet_caps` (join with ",") |
| `getEnvOr("TASK", "")` in `run_ailang_step` | Thread `task` param from `run_with_config` |
| `getEnvOr("AILANG_BUILT", "unknown")` | Thread `inv.ailang_built` |
| `read_retry_config()` (3 env reads) | Replace with pure `retry_from_config(cfg.agent)` |
| `delegated_wait_attempts()` (3 env reads) | Take `cfg.tools.delegated_*` fields as params |

**`src/core/tool_runtime.ail`** — Replace:

| Current env read | Replacement |
|---|---|
| `getEnvOr("OHMY_PI_TOOLS", "0")` | Accept `ohmy_pi: bool` parameter |
| `getEnvOr("WORKDIR", ".")` | Accept `workdir: string` parameter |

**`src/core/config.ail`** — Add fields to existing types:

- `AgentConfig`: add `semi_formal_verifier_mode: bool`
- `ContextModeConfig`: add `timeout_ms: int`, `max_output_chars: int`
  (currently only in env vars, not in the config type)
- `ExaSearchConfig`: replace `placeholder: string` with `timeout_ms: int`,
  `max_output_chars: int`
- `OmnigraphConfig`: replace `placeholder: string` with real fields as needed

Update JSON loading functions and default profile JSON files to match.

Also update `ComposeAuthoringConfig` in config.ail: change
`author_tools_deny_globs` from colon-separated string to `[string]` array,
matching JSON's native list type. Update `compose.json` default profile and
the `load_compose` function accordingly.

---

## Phase 3 — Extension config plumbing

**Goal:** Extensions receive typed config records instead of reading env vars.
The registry passes config through to each extension's `register()`.

### Architecture change

Currently:
```
resolve(name) -> Option[() -> ExtensionHooks ! {Env, FS}]
```

After:
```
resolve(name) -> Option[(RuntimeConfig) -> ExtensionHooks ! {FS}]
```

The `Env` effect drops from the signature because extensions no longer read env
vars (except test_dummy, which keeps its own reads for testing ergonomics).

### Files to modify

**`src/core/ext/registry.ail`**:
- Change `resolve()` return type to accept `RuntimeConfig`
- Change wrapper functions (`register_compose`, etc.) to pass config through
- Update `parse_tokens` to pass config to each constructor
- `parse_core_ext_order` and `init_runtime_with_config` accept `RuntimeConfig`
- Remove `import std/env`

**`src/core/ext/runtime.ail`**:
- `init_runtime_with_config` accepts `RuntimeConfig` (or relevant subset) and
  forwards to registry
- Remove `getEnvOr("CORE_EXT_STRICT", ...)` — use `cfg.extensions.strict`

**Extension packages** (each is under `src/core/ext/<name>/` with its own
`ailang.toml`):

| Extension | Current env reads | Change |
|---|---|---|
| `compose/compose.ail` | 16 `getEnvOr` calls + `parse_env_int` | `register(cfg: RuntimeConfig)` → extract `cfg.compose.*`, `cfg.tools.snippet_caps`, `cfg.agent.workdir`; capture in closures |
| `compose/author_tools.ail` | 1 `getEnvOr` (deny globs) | Receive deny globs from `ComposeAuthoringConfig.author_tools_deny_globs`; change JSON schema from colon-separated string to `[string]` array |
| `context_mode/context_mode.ail` | 5 env reads | `register(cfg: RuntimeConfig)` → extract `cfg.context_mode.*`, `cfg.agent.workdir` |
| `exa_search/exa_search.ail` | 3 env reads | `register(cfg: RuntimeConfig)` → extract `cfg.exa_search.*`, `cfg.agent.workdir` |
| `omnigraph/omnigraph.ail` | 1 env read (WORKDIR) | `register(cfg: RuntimeConfig)` → extract `cfg.agent.workdir` |
| `test_dummy/dummy.ail` | 4 env reads | **Unchanged** — test extension keeps env var reads |

Compose is the largest change (~16 env reads scattered through register(),
handle_compose_tool, and on_response_intercept). The typed config is already
defined in `ComposeConfig`, `ComposeAuthoringConfig`, `ComposeClaimcheckConfig`.
The register function captures these as closure-bound values.

### Package source note

Extensions are imported in registry.ail via `pkg/sunholo/motoko_compose/...`
etc., but the source lives locally at `src/core/ext/<name>/`. Verify at
implementation time whether these resolve to the local source (symlinked or
path-dependency in `ailang.toml`) or require publishing updated package
versions. If the latter, Phase 3 includes package releases for each modified
extension.

### Phase ordering

Phase 3 (extensions stop reading env vars) must complete before Phase 4
(env overlay removed from config.ail). During Phase 3, config.ail still has
the env overlay — extensions just ignore it. After Phase 4, the overlay is
gone and nothing reads non-secret env vars.

---

## Phase 4 — Remove env overlay from config.ail

**Goal:** Delete the env overlay machinery. Config loading becomes:
parse JSON + fill defaults + apply CLI overrides.

### Files to modify

**`src/core/config.ail`** — Remove:
- `env_file_value`, `env_default`, `parse_env_line`, `lookup_env_lines`,
  `lookup_env_file`, `strip_quotes` (`.env` file parsing)
- `shell_string`, `shell_int`, `shell_bool01` (shell env overlay)
- `cfg_string`, `cfg_int`, `cfg_bool`, `cfg_string_array` (three-layer merge)
- `current_workdir()` (env-based)

Replace `load_agent`, `load_backend`, `load_tools`, `load_extensions`,
`load_compose`, `load_context_mode` with simplified versions that use
`json_string`/`json_int`/`json_bool` with hardcoded fallbacks only.

Make `load_config_from_cli` the primary entry point. Keep
`load_runtime_config()` as a thin wrapper that calls
`load_config_from_cli(getArgs())` so rpc.ail's `main()` still works for
backwards compat.

Remove `Env` from config loading effect signatures (except `getArgs()` at the
top and secret validation).

### Secret validation

Add to supervisor.ail startup:
```
func validate_secrets(model: string) -> [string] ! {Env}
```
Checks which API key is needed based on model prefix (`anthropic/` →
`ANTHROPIC_API_KEY`, etc.), returns warning strings for missing keys. Uses
`getEnv` from `std/env` — the only remaining non-secret env read is
`MOTOKO_CONFIG` as fallback for `--profile`.

---

## Phase 5 — TypeScript TUI migration

**Goal:** TUI spawns supervisor.ail with CLI args instead of passing env vars.

### Files to modify

**`src/tui/src/runtime-process.ts`**:
- Build CLI args array: `["--profile", profile, "--model", model, "--workdir", workdir, "--port", port, task]`
- Spawn target changes from `src/core/rpc.ail` to `src/core/supervisor.ail`
- Env passed to subprocess: only secrets + `PATH` + `HOME` (not MODEL, WORKDIR, etc.)

**`src/tui/src/index.ts`**:
- Keep `loadDotEnv()` but only for secrets (API keys)
- Remove or simplify `loadMotokoConfig()` call — TUI no longer needs to read
  TOML and set process.env for the subprocess
- Profile selection moves to CLI arg construction

**`src/tui/src/config.ts`**:
- Remove `CORE_MAP`, `EXTENSION_MAPS`, `loadMotokoConfig()`,
  `applyConfigObject()` — all dead code after TUI stops setting env vars
- Keep `resolveProfileDir()` and `activeProfile()` if TUI still needs to know
  the profile for display purposes

**`src/tui/src/init-config.ts`**:
- JSON templates become primary output
- TOML generation becomes optional/deprecated

---

## Phase 6 — Cleanup and docs

- Remove legacy TOML config files from `.motoko/config/default/`
- Update default JSON profiles with new fields (semi_formal_verifier_mode,
  context_mode timeout/max_output, exa_search timeout/max_output)
- Update `README.md`: document JSON-only config, CLI args, headless invocation
- Update `CLAUDE.md`: remove env var config references, document new precedence
- Remove `import std/env (getEnvOr)` from all files that no longer need it

---

## Verification

### AILANG

```bash
# Config module tests (parse_cli_args, JSON loading)
ailang test src/core/config.ail

# Type-check all modified modules
ailang check src/core/config.ail
ailang check src/core/backend.ail
ailang check src/core/supervisor.ail
ailang check src/core/rpc.ail
ailang check src/core/ext/registry.ail
ailang check src/core/ext/runtime.ail

# Extension type-checks
ailang check src/core/ext/compose/compose.ail
ailang check src/core/ext/context_mode/context_mode.ail
ailang check src/core/ext/exa_search/exa_search.ail
ailang check src/core/ext/omnigraph/omnigraph.ail

# Existing parse/agents_md tests still pass
ailang test src/core/parse_test.ail
ailang test src/core/agents_md.ail
```

### Headless smoke test

```bash
ANTHROPIC_API_KEY=sk-ant-... \
  ailang run --entry main \
  --caps IO,FS,Env,Process,Net,AI,SharedMem,Clock,Stream \
  src/core/supervisor.ail -- \
  --profile default \
  --model anthropic/claude-sonnet-4-6 \
  --workdir . \
  "echo hello"
```

Confirm: session_start includes config_profile, no getEnvOr for MODEL/WORKDIR,
backend starts from config.

### TypeScript (after Phase 5)

```bash
cd src/tui && bun run build
cd src/tui && node --experimental-vm-modules node_modules/.bin/jest \
  --testPathPattern='src/.*\.test\.ts' --runInBand
```
