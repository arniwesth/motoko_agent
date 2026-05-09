# Motoko File-Based Config System

## Problem

Motoko has 49 environment variables that grew organically across the core runtime,
TypeScript frontend, and five extensions. The result:

- No discoverability — you have to grep the source to find what's configurable
- No grouping — `AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER` sits next to `MODEL`
- Extension config is tangled with core config
- No way to commit project-specific defaults to the repo
- Boolean flags use inconsistent conventions (`0`/`1`, `true`/`false`, `yes`/`no`)

## Design

### Directory layout

```
.motoko/
  config.toml           # core agent config (~15 keys)
  compose.toml          # compose extension config (~20 keys)
  context_mode.toml     # context-mode extension config
  exa_search.toml       # exa search extension config
  omnigraph.toml        # omnigraph extension config
```

All files live in a single flat directory at the repo root. Extension files are
optional — missing file means "use defaults." The directory name `.motoko/` is
distinct from any existing directory and signals project-level agent config.

### File format: TOML

TOML is the right fit:

- Human-readable, minimal syntax noise
- Supports nested tables for logical grouping
- Comments for documentation inline with values
- Mature parsers: `smol-toml` (zero-dep, ESM) for TypeScript, no AILANG parser needed
  (the TS layer reads TOML and passes values as env vars to the subprocess — same as
  today's `.env` loader)

JSON was considered but lacks comments, which matters for a config file that users
edit by hand. YAML was rejected for its ambiguity footguns.

### Precedence (lowest → highest)

```
1. Hardcoded defaults (in source code, unchanged)
2. .motoko/config.toml  /  .motoko/<ext>.toml
3. .env / .export files (existing loader, unchanged)
4. Shell environment variables
```

**Env vars always win.** This preserves backward compatibility — every existing
script, CI job, and `make run` invocation keeps working. The config file provides
discoverable, committable defaults; env vars provide per-invocation overrides.

### Where config is read

**TypeScript frontend only.** The AILANG runtime has no TOML parser and adding one
is out of scope. The existing architecture already works this way:

1. `index.ts` loads `.env` files → populates `process.env`
2. `runtime-process.ts` spawns the AILANG subprocess with `env: { ...process.env, ... }`
3. AILANG code reads values via `getEnv` / `getEnvOr`

The new loader slots in between steps 1 and 2: read `.motoko/*.toml`, flatten to
env vars, write to `process.env` (without overriding existing values — same rule
as the `.env` loader).

**No changes needed in `env-server.ts`.** The env server reads compose/subagent
config from `process.env` and forwards it to subprocesses. Because the config
loader populates `process.env` before anything runs, the env server picks up
file-based config values transparently — no code changes required on that path.

---

## Core config schema

### `.motoko/config.toml`

```toml
# ─── Agent ───────────────────────────────────────────────────────────
[agent]
model = "anthropic/claude-sonnet-4-6"   # MODEL
workdir = "."                            # WORKDIR
max_steps = 50                           # AI_MAX_STEPS
step_delay_ms = 0                        # AI_STEP_DELAY_MS
max_retries = 3                          # AI_MAX_RETRIES
retry_base_ms = 1000                     # AI_RETRY_BASE_MS
retry_cap_ms = 30000                     # AI_RETRY_CAP_MS
system_prompt = ""                       # SYSTEM_MD (path to file; empty = use built-in)
openai_base_url = ""                     # OPENAI_BASE_URL (for local/custom OpenAI-compatible endpoints)

# ─── Environment server ─────────────────────────────────────────────
[server]
port = 8080                              # ENV_PORT

# ─── Tools ───────────────────────────────────────────────────────────
[tools]
hybrid = true                            # HYBRID_TOOLS
ohmy_pi = false                          # OHMY_PI_TOOLS
snippet_caps = ["IO", "FS", "Process"]   # AILANG_SNIPPET_CAPS
delegated_timeout_ms = 30000             # DELEGATED_TOOL_TIMEOUT_MS
delegated_poll_ms = 100                  # DELEGATED_TOOL_POLL_MS
delegated_timeout_slack_ms = 5000        # DELEGATED_TOOL_TIMEOUT_SLACK_MS
edit_mode = ""                           # EDIT_MODE (hashline/replace/auto)

# ─── Extensions ──────────────────────────────────────────────────────
[extensions]
order = []                               # CORE_EXT_ORDER (list of strings)
strict = false                           # CORE_EXT_STRICT

# ─── UI ──────────────────────────────────────────────────────────────
[ui]
stream_events = true                     # MOTOKO_STREAM_EVENTS
jsonl_output = false                     # MOTOKO_JSONL_OUTPUT
plain_verbose_stream = false             # MOTOKO_PLAIN_VERBOSE_STREAM
show_tool_json_stream = false            # MOTOKO_SHOW_TOOL_JSON_STREAM
final_only = false                       # MOTOKO_FINAL_ONLY
activity_log = false                     # TUI_ACTIVITY_LOG
subagent_verbose = false                 # AILANG_SUBAGENT_VERBOSE
subagent_auto_collapse = false           # AILANG_SUBAGENT_AUTO_COLLAPSE
force_tty = false                        # FORCE_TTY

# ─── Runtime ─────────────────────────────────────────────────────────
[runtime]
ailang_bin = ""                          # AILANG_BIN (empty = find on PATH)

# ─── Verification ────────────────────────────────────────────────────
[verification]
semi_formal = false                      # SEMI_FORMAL_VERIFIER_MODE
```

**Design notes:**

- Boolean fields use actual booleans (`true`/`false`), not strings. The loader
  converts to `"1"`/`"0"` when writing to env vars.
- `extensions.order` and `tools.snippet_caps` are TOML arrays of strings
  (`["compose", "omnigraph"]`), joined to CSV when writing to their env vars.
- Comments document the env var each field maps to, so migration is transparent.
- `TASK` is intentionally excluded — it's always per-invocation (CLI arg or prompt).
- API keys are intentionally excluded — secrets belong in env vars or `.env`, never
  in a committable config file.

---

## Extension config schemas

### `.motoko/compose.toml`

```toml
[compose]
mode = "subagent"                        # AILANG_COMPOSITION_MODE
subagent_model = ""                      # AILANG_SUBAGENT_MODEL (empty = inherit agent.model)
max_attempts = 50                        # AILANG_SUBAGENT_MAX_ATTEMPTS
effect_guard = "1"                       # AILANG_COMPOSE_EFFECT_GUARD ("0"/"1"/"legacy")
certificate_template = false             # AILANG_COMPOSE_CERTIFICATE_TEMPLATE

[compose.authoring]
structured = true                        # AILANG_COMPOSE_STRUCTURED_AUTHORING
author_tools = false                     # AILANG_COMPOSE_AUTHOR_TOOLS
author_tools_budget = 25                 # AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET
author_tools_max_bytes = 16384           # AILANG_COMPOSE_AUTHOR_TOOLS_MAX_BYTES
author_tools_max_turns = 24             # AILANG_COMPOSE_AUTHOR_TOOLS_MAX_TURNS
author_tools_deny_globs = ""             # AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS
authoring_budget = 40                    # AILANG_COMPOSE_AUTHORING_BUDGET
fallback_after = 3                       # AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER
min_observed_chars = 180                 # AILANG_COMPOSE_MIN_OBSERVED_CHARS
stdout_max_bytes = 4000                  # AILANG_COMPOSE_STDOUT_MAX_BYTES

[compose.claimcheck]
enabled = true                           # AILANG_COMPOSE_CLAIMCHECK
informalizer_model = ""                  # AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL
comparator_model = ""                    # AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL
timeout_ms = 30000                       # AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS
max_invocations = 10                     # AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS
stdout_max_bytes = 4000                  # AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES
ledger_in_informalizer = true            # AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER
```

### `.motoko/context_mode.toml`

```toml
[context_mode]
bin = "context-mode"                     # CONTEXT_MODE_BIN
snapshot_key_prefix = "ctxmode:snapshot:" # CONTEXT_MODE_SNAPSHOT_KEY_PREFIX
```

### `.motoko/exa_search.toml`

```toml
[exa_search]
# API key is intentionally NOT here — use env var EXA_API_KEY
```

### `.motoko/omnigraph.toml`

```toml
[omnigraph]
# Omnigraph config TBD — currently has no env-var-based config
```

---

## Implementation plan

### Phase 1 — Config loader in TypeScript (core plumbing)

**Goal:** Load `.motoko/config.toml`, flatten to env vars, integrate into startup.

**Files to create:**

- `src/tui/src/config.ts` — the config loader module

**Files to modify:**

- `src/tui/package.json` — add `smol-toml` dependency
- `src/tui/src/index.ts` — call config loader after `.env` loader, before anything
  reads `process.env`

**Config loader (`src/tui/src/config.ts`) responsibilities:**

1. Resolve config directory: look for `.motoko/` in `WORKDIR` (or cwd). No walk-up
   search — check the single directory only. Walk-up can be added later for monorepo
   support if users request it, but for v1 a single known location avoids surprises
   (accidentally picking up a parent directory's config).
2. If `.motoko/config.toml` exists, parse it with `smol-toml`.
3. Flatten the parsed object to env var key-value pairs using a hardcoded mapping
   table (not convention-based — explicit mapping avoids surprises):

   ```typescript
   const CSV = (v: string[]) => v.join(",");

   const CORE_MAP: Record<string, { env: string; serialize?: (v: any) => string }> = {
     // [agent]
     "agent.model":                { env: "MODEL" },
     "agent.workdir":              { env: "WORKDIR" },
     "agent.max_steps":            { env: "AI_MAX_STEPS" },
     "agent.step_delay_ms":        { env: "AI_STEP_DELAY_MS" },
     "agent.max_retries":          { env: "AI_MAX_RETRIES" },
     "agent.retry_base_ms":        { env: "AI_RETRY_BASE_MS" },
     "agent.retry_cap_ms":         { env: "AI_RETRY_CAP_MS" },
     "agent.system_prompt":        { env: "SYSTEM_MD" },
     "agent.openai_base_url":      { env: "OPENAI_BASE_URL" },
     // [server]
     "server.port":                { env: "ENV_PORT" },
     // [tools]
     "tools.hybrid":               { env: "HYBRID_TOOLS", serialize: boolTo01 },
     "tools.ohmy_pi":              { env: "OHMY_PI_TOOLS", serialize: boolTo01 },
     "tools.snippet_caps":         { env: "AILANG_SNIPPET_CAPS", serialize: CSV },
     "tools.delegated_timeout_ms": { env: "DELEGATED_TOOL_TIMEOUT_MS" },
     "tools.delegated_poll_ms":    { env: "DELEGATED_TOOL_POLL_MS" },
     "tools.delegated_timeout_slack_ms": { env: "DELEGATED_TOOL_TIMEOUT_SLACK_MS" },
     "tools.edit_mode":            { env: "EDIT_MODE" },
     // [extensions]
     "extensions.order":           { env: "CORE_EXT_ORDER", serialize: CSV },
     "extensions.strict":          { env: "CORE_EXT_STRICT", serialize: boolTo01 },
     // [ui]
     "ui.stream_events":           { env: "MOTOKO_STREAM_EVENTS", serialize: boolTo01 },
     "ui.jsonl_output":            { env: "MOTOKO_JSONL_OUTPUT", serialize: boolTo01 },
     "ui.plain_verbose_stream":    { env: "MOTOKO_PLAIN_VERBOSE_STREAM", serialize: boolTo01 },
     "ui.show_tool_json_stream":   { env: "MOTOKO_SHOW_TOOL_JSON_STREAM", serialize: boolTo01 },
     "ui.final_only":              { env: "MOTOKO_FINAL_ONLY", serialize: boolTo01 },  // legacy alias MOTOKO_HEURISTIC_FINAL_ONLY not mapped — use canonical name
     "ui.activity_log":            { env: "TUI_ACTIVITY_LOG", serialize: boolTo01 },
     "ui.subagent_verbose":        { env: "AILANG_SUBAGENT_VERBOSE", serialize: boolTo01 },
     "ui.subagent_auto_collapse":  { env: "AILANG_SUBAGENT_AUTO_COLLAPSE", serialize: boolTo01 },
     "ui.force_tty":               { env: "FORCE_TTY", serialize: boolTo01 },
     // [runtime]
     "runtime.ailang_bin":          { env: "AILANG_BIN" },
     // [verification]
     "verification.semi_formal":   { env: "SEMI_FORMAL_VERIFIER_MODE", serialize: boolTo01 },
   };
   ```

4. For each mapped value, write to `process.env[envKey]` **only if the env var is
   not already set** (same precedence rule as the `.env` loader).

   **Empty string rule:** If a TOML value serializes to `""` (empty string), do NOT
   write it to `process.env`. In Node, `process.env.X = ""` is semantically different
   from `X` being unset — several places in the codebase use `process.env.X &&
   process.env.X.trim() !== ""` guards that would break if the config loader set
   empty strings. Treat `""` as "not configured" and skip it. This applies to string
   fields like `system_prompt`, `ailang_bin`, `openai_base_url`, `subagent_model`,
   etc. Booleans and numbers never produce empty strings so they are unaffected.

5. Export a `loadMotokoConfig(): void` function (no arguments — it resolves
   `workdir` internally from `process.env.WORKDIR ?? process.cwd()`, the same
   one-liner that `main()` uses).

**Integration in `index.ts`:**

Currently `loadDotEnv()` is called at module top-level (line 115), before
`main()`. Both loaders must move inside `main()`, before the first env var
reads (line 268+). This ensures `workdir` resolution is consistent and the
call order is explicit:

```typescript
async function main(): Promise<void> {
  loadMotokoConfig();  // 1. .motoko/*.toml (lowest file-based priority)
  loadDotEnv();        // 2. .env / .export (overrides .motoko/)
                       // 3. Shell env vars (already set, never overridden)

  const jsonlOutput = process.env.MOTOKO_JSONL_OUTPUT === "1";
  const workdir = process.env.WORKDIR ?? process.cwd();
  // ... rest of startup
```

Both loaders use the same "never override existing env vars" rule. Because
`loadMotokoConfig()` runs first and `.env` runs second, the effective
precedence is: **defaults < `.motoko/` < `.env` < shell env vars**.

**Implementation note:** `PlainLogger` (line 121) is defined at module level but
only *instantiated* inside `main()`. The loaders must run before any `PlainLogger`
construction so that `MOTOKO_PLAIN_VERBOSE_STREAM` is populated in time. Confirm
during implementation that no class constructor or module-level code reads
`process.env` before the loaders execute.

**Tests:**

- `src/tui/src/config.test.ts` — unit tests for the loader:
  - Parses a valid `config.toml` and produces correct env var map
  - Missing `.motoko/` directory → no-op (no crash)
  - Missing individual keys → skipped (no defaults injected)
  - Existing env vars are NOT overridden
  - Boolean serialization (`true` → `"1"`, `false` → `"0"`)
  - Array serialization (`["compose", "omnigraph"]` → `"compose,omnigraph"`)
  - Empty string values are NOT written to `process.env` (skipped, not set to `""`)
  - Empty array values (`[]`) produce `""` which is also skipped
  - Invalid TOML → warning logged, no crash

### Phase 2 — Extension config loading

**Goal:** Load `.motoko/<ext_name>.toml` for each active extension.

**Files to modify:**

- `src/tui/src/config.ts` — add `loadExtensionConfig(extName: string)` function

**How it works:**

After `loadMotokoConfig()` reads `config.toml` and writes `extensions.order` to
`CORE_EXT_ORDER`, it reads back the **resolved** value from `process.env.CORE_EXT_ORDER`
to determine which extension configs to load. This is important: if the user set
`CORE_EXT_ORDER` as a shell env var, the file's `extensions.order` was never
written (because the env var was already set), and the shell value is the one that
governs which extension config files get loaded.

It then iterates over active extensions and loads each `<ext_name>.toml` if present.
Each extension file has its own mapping table:

```typescript
const EXTENSION_MAPS: Record<string, Record<string, { env: string; serialize?: ... }>> = {
  compose: {
    "compose.mode":                    { env: "AILANG_COMPOSITION_MODE" },
    "compose.subagent_model":          { env: "AILANG_SUBAGENT_MODEL" },
    "compose.authoring.structured":    { env: "AILANG_COMPOSE_STRUCTURED_AUTHORING", serialize: boolTo01 },
    "compose.claimcheck.enabled":      { env: "AILANG_COMPOSE_CLAIMCHECK", serialize: boolTo01 },
    // ... complete table
  },
  context_mode: {
    "context_mode.bin":                { env: "CONTEXT_MODE_BIN" },
    "context_mode.snapshot_key_prefix": { env: "CONTEXT_MODE_SNAPSHOT_KEY_PREFIX" },
  },
  // ...
};
```

Same precedence rules apply. Extension config files that don't match an active
extension are silently ignored (no error for a stale `compose.toml` when compose
isn't in `extensions.order`).

### Phase 3 — `make init-config` scaffold command

**Goal:** Generate a starter `.motoko/config.toml` with all keys, defaults, and
comments.

**Files to create:**

- `src/tui/src/init-config.ts` — scaffold script (keeps the mapping tables and
  default values in one place — `config.ts` — rather than duplicating them in a
  shell heredoc)

**Files to modify:**

- `Makefile` — add `init-config` target: `bun src/tui/src/init-config.ts`

**Behavior:**

1. Creates `.motoko/` directory if missing
2. Writes `config.toml` with all keys set to their defaults, fully commented
3. Optionally writes extension config files for extensions listed in
   `CORE_EXT_ORDER` (or all known extensions if `--all` flag is passed)
4. Does NOT overwrite existing files (prints a warning instead)

This gives users a discoverable starting point — they can uncomment and modify
only what they need.

### Phase 4 — Documentation and migration

**Files to modify:**

- `README.md` — add `.motoko/` config section, update env var table to note
  "can also be set in `.motoko/config.toml`"
- `CLAUDE.md` — add config system to the "Key environment variables" section
- `.gitignore` — add a comment explaining that `.motoko/` is intentionally NOT
  ignored (it's meant to be committed). This prevents future contributors from
  adding it to `.gitignore` by mistake, assuming dot-directories should be ignored

**Migration notes for existing users:**

- Zero breaking changes. All env vars continue to work exactly as before.
- The config file is purely additive — it provides defaults, env vars override.
- Existing `.env` files continue to work and take precedence over `.motoko/`.
- Users can migrate incrementally: move one var at a time from `.env` to
  `.motoko/config.toml`.

---

## Decisions and rationale

| Decision | Rationale |
|----------|-----------|
| TOML over JSON | Comments are essential for a hand-edited config file |
| Flat directory, no nesting | Easy `ls`, easy discovery, matches extension naming |
| TS-only loading (no AILANG parser) | AILANG has no TOML parser; the TS→env→AILANG pipeline already exists |
| Explicit mapping table over convention | `agent.max_steps` → `AI_MAX_STEPS` has no derivable pattern; explicit is safer |
| `.motoko/` over `motoko.toml` | Separating core from extension config requires a directory |
| No API keys in config | Secrets should never be in a committable file |
| `OPENAI_BASE_URL` in config, `OPENROUTER_API_KEY` not | Base URL is an endpoint, not a secret — useful for permanent local-model setups. `TB_EXEC_PROXY` excluded as internal/debug-only |
| No `TASK` in config | Task is always per-invocation, never a default |
| `.env` overrides `.motoko/` | `.env` is closer to "shell-level" and often used for personal overrides |
| `smol-toml` over `@iarna/toml` | Zero dependencies, ESM-native, maintained, fast |
| No walk-up directory search | Single known location avoids surprises; walk-up for monorepos can come later |
| Both loaders inside `main()` | Avoids chicken-and-egg with `workdir` resolution; keeps call order explicit |

## Out of scope (future considerations)

- **Home-directory layering** (`~/.motoko/config.toml` for personal global defaults).
  Could be added later with minimal changes — just prepend another loader call.
- **Config validation / schema enforcement.** v1 silently ignores unknown keys.
  A future version could warn on typos using edit-distance matching.
- **Live config reload.** v1 reads config at startup only. Hot-reload during a
  session is not needed yet.
- **AILANG-native config reading.** If AILANG gains a TOML or structured config
  module, extensions could read their own config files directly instead of going
  through env vars. This would be a nice cleanup but isn't blocking.
