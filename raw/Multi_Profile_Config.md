# Multi-Profile Config System

## Context

Motoko's config system currently uses a flat `.motoko/` directory with TOML files.
When testing different configurations (e.g. local model vs cloud, benchmark settings,
verbose debug), users must manually edit `config.toml` or juggle env vars. This makes
A/B testing and reproducible benchmarks painful.

The fix: support named config profiles under `.motoko/config/<profile>/`, selectable
via `MOTOKO_CONFIG` env var, defaulting to `default`.

---

## Target layout

```
.motoko/
  config/
    default/
      config.toml
      compose.toml
      context_mode.toml
      ...
    benchmark/
      config.toml
      compose.toml
    debug/
      config.toml
  logfile/
    session_2026-05-03T...jsonl
    session_2026-05-03T...md
```

Usage: `MOTOKO_CONFIG=benchmark make run TASK="..."` or just `make run` for default.

---

## Phase 1 -- Config resolution (`src/tui/src/config.ts`)

### 1a. Replace `configDir()` with `resolveProfileDir()`

Current `configDir()` (line 234) returns `.motoko/`. New logic:

```
1. Read MOTOKO_CONFIG from process.env (not from TOML, not protected-keys)
2. If unset or empty -> "default"
3. If absolute path   -> use as-is
4. Otherwise          -> path.join(WORKDIR, ".motoko", "config", profileName)
```

### 1b. Backward-compat fallback

Before returning the profile dir, check if the old flat layout is in use:

- If `.motoko/config.toml` exists AND `.motoko/config/<profile>/config.toml` does NOT exist:
  - Log deprecation warning to stderr
  - Return `.motoko/` (the flat dir)
- Otherwise: return the profile dir

This means existing setups keep working until migrated.

### 1c. Export `activeProfile()` helper

Returns the resolved profile name (for banner/logging).

### 1d. Update callers

- `loadExtensionConfig()` default param: `configDir()` -> `resolveProfileDir()`
- `loadMotokoConfig()` body: `configDir()` -> `resolveProfileDir()`

No changes to mapping tables, templates, or serializers.

---

## Phase 2 -- Init-config script (`src/tui/src/init-config.ts`)

### 2a. Parse `--profile <name>` from argv (default: `"default"`)

### 2b. Change output directory

From: `path.join(cwd, ".motoko")`
To: `path.join(cwd, ".motoko", "config", profile)`

`fs.mkdirSync(dir, { recursive: true })` already handles nested creation.

### 2c. Add `--migrate` flag

When passed:
1. Check if flat `.motoko/config.toml` exists
2. Create `.motoko/config/default/`
3. Move each `.toml` file from `.motoko/` into `.motoko/config/default/`
4. Print what was moved

---

## Phase 3 -- Migrate existing config files

After implementing Phases 1-2, run `make init-config ARGS=--migrate` to move the
current `.motoko/*.toml` files into `.motoko/config/default/`. Commit the result.

---

## Phase 4 -- Tests (`src/tui/src/config.test.ts`)

### Keep existing tests as-is (they exercise the backward-compat fallback)

Add `"MOTOKO_CONFIG"` to the `ENV_KEYS` cleanup list (line 7).

### New tests to add

| Test | What it verifies |
|------|-----------------|
| Named profile | `MOTOKO_CONFIG=benchmark` loads from `.motoko/config/benchmark/` |
| Default profile | Unset `MOTOKO_CONFIG` loads from `.motoko/config/default/` |
| Absolute path | `MOTOKO_CONFIG=/abs/path` loads from that directory |
| Fallback + warning | Flat `.motoko/config.toml` triggers deprecation warning, still loads |
| Profile extensions | Extension TOMLs load from the profile directory |
| Profile overrides flat | When both layouts exist, profile wins (no warning) |

---

## Phase 5 -- Makefile

Update `init-config` target (line 57-58):

```makefile
PROFILE ?= default
init-config:
	bun src/tui/src/init-config.ts --profile $(PROFILE) $(ARGS)
```

Usage: `make init-config`, `make init-config PROFILE=benchmark`,
`make init-config ARGS=--migrate`.

---

## Phase 6 -- Documentation

### README.md

- Add `MOTOKO_CONFIG` to env var table (lines 188-194)
- Update "File-based config" section (lines 196-216) with new directory layout
- Update `make init-config` examples to show `PROFILE=` usage
- Note backward compat with flat layout

### CLAUDE.md

- Update `.motoko/` references (lines 60-64) to `.motoko/config/<profile>/`
- Add `MOTOKO_CONFIG` to env var table
- Update `make init-config` examples

---

## Phase 6.5 -- Move logfile/ under .motoko/ (`src/tui/src/session-logger.ts`)

Currently `session-logger.ts:46` writes to `path.join(projectRoot, "logfile")`.
Change to `path.join(projectRoot, ".motoko", "logfile")`.

Also update `.gitignore`: replace `logfile/` with `.motoko/logfile/`.

Existing log files in `logfile/` can be moved manually or left as-is (they're
already gitignored).

---

## Files to modify

| File | Change |
|------|--------|
| `src/tui/src/config.ts` | `resolveProfileDir()`, `activeProfile()`, update callers |
| `src/tui/src/init-config.ts` | `--profile`, `--migrate`, nested output dir |
| `src/tui/src/config.test.ts` | Add profile tests, keep existing for fallback coverage |
| `src/tui/src/session-logger.ts` | Change log dir from `logfile/` to `.motoko/logfile/` |
| `Makefile` | `PROFILE` variable for `init-config` target |
| `README.md` | Directory layout, env var table, examples |
| `CLAUDE.md` | Config references and env var table |
| `.gitignore` | `logfile/` -> `.motoko/logfile/` |

---

## Verification

1. `cd src/tui && bun run test` -- all existing + new tests pass
2. `make init-config` -- creates `.motoko/config/default/config.toml`
3. `make init-config PROFILE=benchmark` -- creates `.motoko/config/benchmark/config.toml`
4. `make init-config ARGS=--migrate` -- moves flat files to `config/default/`
5. With flat layout still present, verify deprecation warning on `make run`
6. `MOTOKO_CONFIG=benchmark make run TASK="test"` -- loads benchmark profile

---

## Precedence (unchanged)

```
hardcoded defaults < .env/.export < .motoko/config/<profile>/*.toml < shell env vars
```

`MOTOKO_CONFIG` itself is always a shell env var -- it cannot be set from within a config file.
