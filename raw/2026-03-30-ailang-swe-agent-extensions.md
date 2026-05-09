# Session Summary: AILANG SWE Agent Extensions — 2026-03-30

## What was changed

Custom system prompt support via `SYSTEM_MD` environment variable.

---

## Motivation

The system prompt was hardcoded in `swe/prompts.ail` as `base_system(cwd)`. There was no way to override it without editing source. A `SYSTEM.md` file provides a stable, version-controllable override point for per-repo or per-task prompt customisation.

---

## Files modified

### `swe/rpc.ail`

Three changes:

**1. New import**
```ailang
import std/fs (readFile, fileExists)
```
`std/fs` already existed in the runtime. `fileExists` guards against a missing path being treated as a runtime error rather than a graceful fallback.

**2. Effect signature of `main`**

`FS` added:
```ailang
export func main() -> () ! {Net, AI, SharedMem, IO, Env, FS, Clock}
```
Scope is `main` only. `rpc_loop`, `conversation_loop`, and all helpers are unaffected.

**3. System prompt resolution in `main`**

Replaces the single `with_cache_hint(base_system(cwd), hint)` line with:
```ailang
let system_md_path = getEnvOr("SYSTEM_MD", "")
let raw_system =
  if system_md_path != "" && fileExists(system_md_path)
  then readFile(system_md_path)
  else base_system(cwd)
let system = with_cache_hint(raw_system, hint)
```

Precedence:
1. `SYSTEM_MD` path — file content used verbatim.
2. `base_system(cwd)` — built-in prompt with workdir-specific bash idioms.

In both cases `with_cache_hint` appends a trajectory hint when the SharedMem cache has a match. Existing behaviour is preserved exactly when `SYSTEM_MD` is unset.

### `tui/src/brain.ts`

`FS` appended to the `--caps` flag passed to `ailang run`:
```
"Net,AI,SharedMem,IO,Env,Clock,FS"
```
`SYSTEM_MD` requires no additional wiring — it already flows through `...process.env` in the spawn env block.

### `tui/src/index.ts`

`SYSTEM_MD` added to the env var documentation comment at the top of the file:
```
//   SYSTEM_MD — path to a SYSTEM.md file whose content replaces the built-in system prompt
```

---

## Usage

```bash
# Point at any file
SYSTEM_MD=/path/to/SYSTEM.md node tui/dist/index.js "Fix the regression"

# Relative path, co-located with the repo under repair
SYSTEM_MD=./SYSTEM.md WORKDIR=/repo node tui/dist/index.js "..."

# No SYSTEM_MD set — falls back to built-in base_system(cwd) as before
node tui/dist/index.js "Fix the regression"
```

The `SYSTEM.md` file content is used as-is. The trajectory cache hint is still appended when available, regardless of whether a custom prompt is in use.

---

## What was not changed

- `swe/prompts.ail` — `base_system`, `with_cache_hint`, `fmt_msgs`, `fmt_obs` are all unchanged. The module remains pure (no FS effects).
- `swe/rpc.ail` loop logic — `rpc_loop` and `conversation_loop` are unmodified.
- TypeScript build — `npm run build` passes with zero errors after the change.
