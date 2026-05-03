# Motoko Core-Owned Config and Supervisor

## Context

Motoko currently loads project config in the TypeScript TUI before the AILANG
runtime starts:

1. `src/tui/src/index.ts` loads `.env` / `.export`
2. `src/tui/src/config.ts` loads legacy `.motoko/config/<profile>/*.toml`
3. TypeScript reads startup values such as `WORKDIR`, `MODEL`, `ENV_PORT`,
   `AILANG_BIN`, and UI flags
4. TypeScript starts the embedded `env-server.ts`
5. TypeScript spawns `src/core/rpc.ail`
6. AILANG core reads config-derived values via `getEnvOr(...)`

This means the config semantics are owned by TypeScript, while Motoko core only
receives normalized environment variables. The long-term goal is to make Motoko
usable headlessly without invoking any TypeScript entry point:

```bash
ailang run --entry main --caps IO,FS,Env,Process,Net,AI,SharedMem src/core/supervisor.ail -- "task"
```

or, eventually:

```bash
motoko run --profile benchmark "task"
```

The goal of this plan is to move config ownership and runtime supervision into
Motoko core while keeping the current TypeScript execution backend as a
replaceable bridge during migration.

## Explicit non-goals

Keep `src/tui/src/env-server.ts` as the initial execution backend for this
migration.
It owns substantial OS/process/tool integration today: `/exec`, delegated tools,
native/hybrid tool handling, compose authoring support, snippet execution,
timeouts, truncation, sandboxing, and subprocess behavior.

This does **not** mean TypeScript remains the long-term launcher. In the target
headless flow, the AILANG supervisor starts or connects to an execution backend.
Initially that backend may still be `env-server.ts` run under Bun as an external
process. A future phase may port or replace it with an AILANG-native or Go-hosted
backend, but that backend rewrite is intentionally out of scope here.

Do **not** modify the vendored AILANG runtime under `ailang/` for this task.
Earlier versions of this plan assumed adding `std/toml` to AILANG, but that
would make this migration depend on runtime/stdlib changes. For this task,
Motoko core must be implemented using AILANG capabilities already available in
the current runtime.

Do **not** hand-roll a TOML parser in AILANG. Correct TOML parsing is too broad
for this migration and would risk subtly diverging from the current TypeScript
`smol-toml` behavior. Instead, move core-owned profile config to JSON, which
AILANG can parse with existing `std/json`.

---

## Target architecture

```text
Headless entry point
  ailang run --entry main src/core/supervisor.ail -- "task"
        or future `motoko run "task"`
  |
  v

AILANG supervisor / Motoko core (primary owner)
  - owns profile resolution and config semantics
  - loads non-secret .env/.export defaults and .motoko/config/<profile>/*.json
  - merges defaults, env-file defaults, profile config, and shell env
  - starts or connects to an execution backend
  - initializes runtime and extensions from a typed config object
  - runs the agent loop
  - emits structured JSONL events
  - calls the backend over HTTP or a future direct protocol

Execution backend (replaceable)
  - initial backend: src/tui/src/env-server.ts run under Bun
  - future backend: AILANG-native or Go-hosted implementation
  - owns OS/process/tool integration details

Optional TypeScript TUI
  - starts or connects to the supervisor
  - renders JSONL events
  - sends JSONL commands: abort, model_change, etc.
```

The near-term end state is "headless top-level invocation works." It may still
depend on Bun/TypeScript internally for the execution backend, but users do not
need to invoke the TUI. The longer-term end state removes the TypeScript backend
dependency behind the same backend interface.

---

## Design principles

- Keep process lifecycle changes incremental.
- Do not duplicate config semantics permanently between TypeScript and AILANG.
- Preserve existing environment-variable compatibility during migration.
- Move core and extension code away from scattered `getEnvOr(...)` calls.
- Use typed config records inside AILANG once config has been loaded.
- Make `env-server.ts` a replaceable backend, not permanent launcher
  infrastructure.
- Keep the TypeScript TUI optional; it should become a client of the supervisor,
  not the owner of runtime startup.

---

## Phase 0 -- Inventory and boundaries

### 0a. Inventory TypeScript-owned startup config

Audit current TypeScript reads of config-derived env vars:

- `src/tui/src/index.ts`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/env-server.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/session-logger.ts`
- tests under `src/tui/src/*.test.ts`

Classify each variable:

| Class | Examples | Owner after migration |
|---|---|---|
| Bootstrap shell | `AILANG_BIN`, provider API keys, `MOTOKO_CONFIG` | Shell / wrapper script |
| Invocation inputs | task text, one-off model override, one-off workdir override | CLI args / shell env |
| Runtime core | `MODEL`, `WORKDIR`, `AI_MAX_STEPS`, `AI_STEP_DELAY_MS` | AILANG config, overridable by invocation/shell |
| Extension core | `CORE_EXT_ORDER`, `CORE_EXT_STRICT`, compose/context_mode settings | AILANG config |
| Backend startup | backend mode, port, URL, command, args, startup timeout | AILANG config |
| Backend behavior | `HYBRID_TOOLS`, `OHMY_PI_TOOLS`, snippet caps, compose guard settings used by `env-server.ts` | AILANG config passed to backend |
| UI-only | activity log, subagent collapse/verbose display | TypeScript UI |

`AILANG_BIN` is intentionally bootstrap-only. Config cannot choose the binary
used to run the config loader itself. If `runtime.ailang_bin` remains in config,
it should be treated as a wrapper/TUI hint or diagnostic, not as core-owned
preflight input.

Provider API keys also remain bootstrap shell environment. They may be read from
`.env` by a wrapper script, but Motoko core cannot rely on mutating a parent
process environment after startup.

`.env` / `.export` therefore has two roles:

- non-secret config defaults may be parsed by `src/core/config.ail`
- provider secrets must be present in the actual process environment before AI
  provider initialization, either exported by the shell or loaded by a wrapper
  before `ailang run`

### 0b. Inventory AILANG `getEnvOr(...)`

Audit all AILANG config reads:

```bash
rg "getEnvOr|_stringToInt\\(getEnvOr" src/core -n
```

Group into:

- runtime loop config
- extension registry/config
- compose config
- context_mode config
- exa_search config
- omnigraph config
- native tool runtime config

Output: a checklist of variables to migrate into typed records.

---

## Phase 1 -- JSON profile config

Motoko core should own profile config without requiring changes to the vendored
AILANG runtime. Since AILANG already has `std/json`, switch Motoko profile
config from TOML to JSON for the core-owned path.

### 1a. Add JSON config files

Add JSON profile files alongside the current TOML files:

```text
.motoko/
  config/
    default/
      config.json
      compose.json
      context_mode.json
      exa_search.json
      omnigraph.json
```

Use the same logical shape as the current TOML tables. Example:

```json
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-6",
    "workdir": ".",
    "max_steps": 50,
    "step_delay_ms": 0,
    "max_retries": 3,
    "retry_base_ms": 1000,
    "retry_cap_ms": 30000,
    "system_prompt": "",
    "openai_base_url": "",
    "ai_options_json": ""
  },
  "backend": {
    "mode": "external_http",
    "url": "http://127.0.0.1:8080",
    "port": 8080,
    "auto_start": true,
    "command": "bun",
    "args": ["src/tui/src/env-server-main.ts"],
    "startup_timeout_ms": 5000
  },
  "tools": {
    "hybrid": true,
    "ohmy_pi": false,
    "snippet_caps": ["IO", "FS", "Process"]
  },
  "extensions": {
    "order": [],
    "strict": false
  }
}
```

JSON does not support comments, so keep explanatory comments in README/docs and
in generator code, not in profile JSON files.

### 1b. Update config generation

Update `make init-config` / `src/tui/src/init-config.ts` to emit JSON config.
During a compatibility window, it may emit both JSON and TOML, but JSON is the
source of truth for the headless AILANG supervisor.

If both formats are present, AILANG core reads JSON. The TypeScript TUI may
continue reading TOML until it becomes a supervisor client.

### 1c. Tests

Add tests for:

- nested objects: `agent`, `backend`, `compose.claimcheck`
- strings, ints/floats, booleans
- arrays of strings
- missing JSON files fall back to hardcoded defaults
- invalid JSON error message
- JSON wins over legacy TOML in headless core mode

### 1d. Legacy TOML behavior

The existing TOML files are legacy compatibility for the TypeScript TUI.
Headless core mode should not parse TOML. If `config.toml` exists but
`config.json` does not, the supervisor should emit an actionable warning:

```text
profile contains legacy TOML config but no JSON config; run make init-config
or migrate .motoko/config/<profile>/*.toml to JSON for headless mode
```

Do not add `std/toml`, `_toml_parse`, or any other `ailang/` runtime changes as
part of this task.

---

## Phase 2 -- Core config module

Add `src/core/config.ail`.

### 2a. Responsibilities

`src/core/config.ail` owns:

- active profile resolution
- absolute profile path support
- default profile fallback
- flat layout backward compatibility
- config file discovery
- JSON parsing
- mapping config paths to normalized config fields
- default values
- shell/env-file precedence
- extension config loading

### 2b. Preserve current profile behavior

Use the same semantics as `src/tui/src/config.ts`:

1. `MOTOKO_CONFIG` is read only from shell/process env
2. unset or empty means `default`
3. absolute path means use that directory
4. relative profile means `.motoko/config/<profile>`
5. if `.motoko/config.json` exists and profile `config.json` does not, load
   the flat layout with a deprecation warning
6. if only legacy `.motoko/config.toml` / profile `config.toml` exists, warn
   that headless mode requires JSON and continue with hardcoded/env defaults

### 2c. Typed config records

Start with records that mirror current tables:

```ailang
type AgentConfig = {
  model: string,
  workdir: string,
  max_steps: int,
  step_delay_ms: int,
  max_retries: int,
  retry_base_ms: int,
  retry_cap_ms: int,
  system_prompt: string,
  openai_base_url: string,
  ai_options_json: string
}

type BackendConfig = {
  mode: string,                -- "external_http" initially; "native" later
  url: string,
  port: int,
  command: string,
  args: [string],
  startup_timeout_ms: int,
  auto_start: bool
}

type ExtensionConfig = {
  order: [string],
  strict: bool
}

type InvocationConfig = {
  task: string,
  model_override: string,
  workdir_override: string,
  ailang_built: string
}

type RuntimeConfig = {
  profile: string,
  profile_dir: string,
  agent: AgentConfig,
  backend: BackendConfig,
  extensions: ExtensionConfig,
  compose: ComposeConfig,
  context_mode: ContextModeConfig,
  exa_search: ExaSearchConfig,
  omnigraph: OmnigraphConfig
}
```

Keep UI-only settings out of `RuntimeConfig` unless core needs them.
Keep invocation-specific inputs (`TASK`, command-line task text, one-off model
overrides) out of profile JSON and model them separately as `InvocationConfig`.

### 2d. Compatibility output

Expose a normalized JSON output for optional launchers and the TypeScript TUI:

```ailang
export func print_config_json() -> () ! {IO, FS, Env}
```

This lets TypeScript consume core-owned config during the transition, but it is
not the final headless path. The primary headless path loads config inside the
AILANG supervisor itself.

---

## Phase 3 -- Backend abstraction

Put the execution backend behind an explicit AILANG-facing interface before
building the headless supervisor milestone.

### 3a. Backend config

Add profile config for backend startup:

```json
{
  "backend": {
    "mode": "external_http",
    "url": "http://127.0.0.1:8080",
    "port": 8080,
    "auto_start": true,
    "command": "bun",
    "args": ["src/tui/src/env-server-main.ts"],
    "startup_timeout_ms": 5000
  }
}
```

Initial modes:

| Mode | Meaning |
|---|---|
| `external_http` | Existing HTTP backend contract; may be already running or supervisor-started |
| `none` | For config/unit tests that do not execute tools |

Future modes:

| Mode | Meaning |
|---|---|
| `native` | AILANG/Go-hosted backend replacing `env-server.ts` |
| `stdio` | Backend child process speaks JSONL over stdin/stdout |

### 3b. Standalone TypeScript backend entrypoint

Add a standalone backend entrypoint rather than assuming `env-server.ts` can be
executed directly:

```text
src/tui/src/env-server-main.ts
```

Responsibilities:

- read backend-compatible env vars or a startup JSON path
- start the existing Express env server
- expose `GET /health`
- keep the process alive until SIGTERM/SIGINT
- shut down HTTP server and child processes cleanly when possible
- avoid importing or starting the TUI

### 3c. Backend HTTP contract inventory

Before supervisor-started backend work, freeze the backend contract the core
expects. Inventory the current endpoints and event payloads in `env-server.ts`.

Minimum contract:

- `GET /health`
- `POST /exec`
- native/delegated tool batch endpoint(s)
- snippet check/run endpoint(s)
- compose authoring/subagent endpoint(s)
- timeout, truncation, stderr/stdout, and exit-code schema
- cancellation/shutdown behavior

If some capabilities are still only reachable through current TUI glue, either
move them into `env-server-main.ts` or mark them unsupported in headless mode for
the first milestone.

### 3d. Backend client module

Add `src/core/backend.ail`:

```ailang
type BackendHandle = {
  mode: string,
  url: string,
  process_id: string
}

type BackendConfig = { ... }

func start_or_connect_backend(cfg: BackendConfig) -> BackendHandle ! {IO, Process, Net}
func exec_backend(handle: BackendHandle, req: ExecReq) -> AilangExecResult ! {Net}
func stop_backend(handle: BackendHandle) -> () ! {IO, Process}
```

Initially, `exec_backend` can delegate to the existing `env_client.exec_in`
HTTP path.

### 3e. Backend payload

Define how config reaches `env-server-main.ts` when the supervisor starts it:

- env vars for compatibility in the first pass
- later, a startup JSON payload or generated `.motoko/runtime/backend.json`

The first pass can keep env-var compatibility because the backend implementation
already reads env vars. The important change is that AILANG supervisor chooses
and starts the backend.

---

## Phase 4 -- Runtime uses typed config

Move `src/core/rpc.ail` from scattered env reads to `RuntimeConfig` plus
`InvocationConfig`.

### 4a. Main startup

Change runtime startup from:

```ailang
let env_url = getEnvOr("ENV_URL", "http://localhost:8080");
let task = getEnvOr("TASK", "");
let model = getEnvOr("MODEL", "anthropic/claude-sonnet-4-6");
...
```

to:

```ailang
let cfg = load_runtime_config();
let inv = load_invocation_config();
let backend = start_or_connect_backend(cfg.backend);
let task = inv.task;
let model =
  if inv.model_override != "" then inv.model_override else cfg.agent.model;
...
```

`TASK` can remain env/argv-owned because it is invocation-specific and should
not live in profile JSON.

### 4b. Preserve env overrides

The config module should still honor shell env overrides with the existing
precedence:

```
hardcoded defaults < .env/.export < .motoko/config/<profile>/*.json < shell env
```

To preserve this precisely, core config loading must distinguish original shell
environment from `.env` / `.export` values. If AILANG cannot mutate or inspect
that distinction directly, use a wrapper convention such as:

```bash
MOTOKO_SHELL_ENV_KEYS='MODEL,WORKDIR,...'
```

or pass shell-protected keys through a small launcher/wrapper. Headless direct
`ailang run` should still work, but exact `.env` vs shell precedence may require
this host-provided boundary.

After config is loaded, downstream runtime code should prefer config fields over
direct env access.

### 4c. Bootstrap env

Keep these outside profile JSON:

- provider API keys
- `AILANG_BIN`
- `MOTOKO_CONFIG`
- task text / CLI args
- transient CI or benchmark overrides

### 4d. Tests

Add tests for:

- default profile
- named profile
- absolute profile path
- flat fallback
- shell override beats profile JSON
- `.env` beats hardcoded default but loses to profile JSON
- `TASK` is not loaded from profile JSON
- legacy TOML-only profiles emit a warning and do not block env/default startup

---

## Phase 5 -- Extension config records

Refactor extension initialization so extensions receive config explicitly.

### 5a. Extension registry

Current registry reads `CORE_EXT_ORDER` via env. Move this into:

```ailang
init_runtime(cfg: RuntimeConfig) -> ExtRuntime
```

or:

```ailang
init_runtime(ext_cfg: ExtensionConfig, per_ext_cfg: PerExtensionConfig) -> ExtRuntime
```

### 5b. Compose

Replace compose env reads with `ComposeConfig` fields:

- composition mode
- subagent model
- max attempts
- effect guard
- certificate template
- authoring config
- claimcheck config

### 5c. Context mode

Replace env reads with `ContextModeConfig`:

- binary path
- snapshot key prefix

### 5d. Other extensions

Add empty or future-ready config records for:

- exa_search
- omnigraph
- test_dummy
- future MCP extension

### 5e. Compatibility period

During migration, extension config field defaults can still consult env vars
inside `src/core/config.ail`. Extension implementation modules should not read
env directly once migrated.

---

## Phase 6 -- Headless supervisor entry point

Add a new entry point rather than rewriting `src/core/rpc.ail` in place:

```text
src/core/supervisor.ail
```

### 6a. Supervisor responsibilities

The supervisor:

- loads `RuntimeConfig`
- reads `InvocationConfig` from CLI args and shell env
- emits a `config_loaded` or enriched `session_start` event
- initializes extensions from typed config
- tracks active profile/profile dir
- starts or connects to the configured execution backend
- runs the existing agent loop
- reads stdin JSONL commands
- emits stdout JSONL events
- calls the backend via configured URL/protocol

### 6b. Start backend from AILANG

When `backend.auto_start = true`, the supervisor should:

1. choose a port from `cfg.backend.port`
2. spawn `cfg.backend.command` with `cfg.backend.args`
3. pass backend-compatible env vars
4. poll `GET /health` until ready or timeout
5. call `/exec` and tool endpoints through the backend client
6. shut down the child backend on normal exit or abort when possible

### 6c. Connect to existing backend

When `backend.auto_start = false`, the supervisor should:

1. use `cfg.backend.url`
2. verify health
3. fail with an actionable error if unavailable

### 6d. Command protocol

Formalize stdin commands:

```json
{"type":"abort"}
{"type":"model_change","model":"openai/gpt-4o"}
{"type":"reload_config"}
```

`reload_config` can be optional in the first version, but the protocol should
reserve it for future profile switching or live config reload.

### 6e. Session metadata

Include active config profile in startup events:

```json
{
  "type": "session_start",
  "task": "...",
  "model": "...",
  "config_profile": "benchmark",
  "config_dir": ".motoko/config/benchmark",
  "backend_mode": "external_http"
}
```

### 6f. Headless smoke target

This command is the first major milestone:

```bash
MOTOKO_CONFIG=default \
  ailang run --entry main \
  --caps IO,FS,Env,Process,Net,AI,SharedMem \
  src/core/supervisor.ail -- "echo hello"
```

It should not invoke `src/tui/src/index.ts`.
Confirm the final required capability set during implementation. Depending on
how streaming AI and backend process management are represented, `Stream` or
additional effects may need to be added.

---

## Phase 7 -- Optional TypeScript TUI as client

Once headless supervisor mode works, simplify the TUI around it.

### 7a. New TUI startup flow

TypeScript should:

1. read only UI/bootstrap shell values needed to find `ailang` and choose UI mode
2. start `src/core/supervisor.ail` or connect to an existing supervisor
3. render supervisor JSONL events
4. send command JSONL to supervisor stdin/socket

TypeScript should no longer own Motoko profile JSON semantics or be required for
headless operation.

### 7b. Remove or demote TypeScript config loader

Options:

- delete `src/tui/src/config.ts` after one compatibility release
- or keep it only for UI-only config
- or keep it as a thin wrapper around `print_config_json` output from AILANG

The preferred end state is no duplicated config mapping tables in TypeScript.

### 7c. Compatibility bridge

If needed during transition, TypeScript can call:

```bash
ailang run --entry print_config_json --caps IO,FS,Env src/core/config.ail
```

This is compatibility glue for the TUI, not the headless architecture.

---

## Phase 8 -- Future native backend

After headless mode is stable with `env-server.ts` as a supervisor-started
external backend, create a separate plan to replace that backend.

That future migration would need to cover:

- shell command execution
- streaming stdout/stderr
- process timeout and cancellation
- filesystem sandboxing
- delegated/native tool execution
- compose authoring subprocesses
- snippet checking/running
- truncation policy
- security boundaries
- HTTP or direct in-process protocol replacement

Possible implementations:

- AILANG-native backend using existing `std/process`, `std/fs`, and future stream
  capabilities
- Go-hosted backend bundled with the AILANG runtime
- standalone backend binary with a stable HTTP/stdio protocol

This should be treated as a new project, not as part of the config ownership
migration.

---

## Phase 9 -- Documentation and cleanup

Update:

- `README.md`
- `CLAUDE.md`
- `.agent/plans/Multi_Profile_Config.md` follow-up notes if needed
- `src/core/AGENT.md`
- config examples under `.motoko/config/default/`

Document:

- core-owned config semantics
- active profile behavior
- headless supervisor invocation
- backend modes and backend startup config
- compatibility env vars
- known bootstrap shell variables
- TypeScript TUI as optional client
- future `env-server.ts` migration possibility

---

## Verification checklist

### AILANG

```bash
ailang test src/core/config.ail
ailang check src/core/backend.ail
ailang check src/core/supervisor.ail
ailang test src/core/ext/compose/compose_test.ail
ailang test src/core/ext/context_mode/context_mode_test.ail
```

### TypeScript

```bash
cd src/tui
bun run build
node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/.*\\.test\\.ts' --runInBand
```

### Manual smoke tests

```bash
make init-config
MOTOKO_CONFIG=default \
  ailang run --entry main \
  --caps IO,FS,Env,Process,Net,AI,SharedMem \
  src/core/supervisor.ail -- "echo hello"

MOTOKO_CONFIG=benchmark \
  ailang run --entry main \
  --caps IO,FS,Env,Process,Net,AI,SharedMem \
  src/core/supervisor.ail -- "echo hello"

MOTOKO_CONFIG=/abs/path/to/profile \
  ailang run --entry main \
  --caps IO,FS,Env,Process,Net,AI,SharedMem \
  src/core/supervisor.ail -- "echo hello"
```

Confirm:

- startup event includes active profile
- final required caps are documented and match implementation
- shell env overrides profile JSON
- `.env` values are lower precedence than profile JSON
- supervisor starts or connects to the configured backend
- `env-server.ts` still handles `/exec` in `external_http` mode
- extension order comes from core-owned config
- compose/context_mode settings come from typed config records
- the command does not invoke `src/tui/src/index.ts`

---

## Risks

| Risk | Mitigation |
|---|---|
| Duplicate config semantics linger in TypeScript and AILANG | Make AILANG supervisor the primary path; keep TS fallback temporary and TUI-only |
| Legacy TOML users are stranded | Emit both JSON and TOML during one compatibility window, document JSON as the headless source of truth, and warn when only TOML exists |
| Backend settings are needed before backend starts | Supervisor loads config before backend startup and passes a backend env/payload |
| Extensions rely on env reads deeply | Migrate extension by extension with compatibility defaults in `config.ail` |
| Headless still depends on Bun via `env-server.ts` | Treat TypeScript backend as replaceable `external_http` backend; plan native backend separately |
| Startup gets slower | Cache config parse output per process; keep backend health polling bounded |
| Behavior changes silently | Emit active profile/config dir in `session_start`; test precedence exhaustively |
| Provider secrets from `.env` are not visible to host AI calls | Keep secrets as bootstrap shell env or load `.env` before provider initialization in the actual process |
