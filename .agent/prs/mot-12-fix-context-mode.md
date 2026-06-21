# Fix context_mode Tool Registration

Base branch: `origin/main`

## Summary

This branch fixes Motoko's `context_mode` extension loading successfully while
advertising no `Ctx*` tools to the model.

Root cause: the registry package `sunholo/motoko_ext_context_mode@0.2.2`
contains the real context-mode implementation, but its published
`register.ail` is a stub. It returns:

- `provided_tools: []`
- `on_describe_tools: []`
- no-op policy/handle/finalize hooks

That means the extension can appear in `loaded_extensions`, while the runtime
tool catalog still has no `CtxDoctor`, `CtxSearch`, `ctx_search`, etc.

## Changes

- Vendor `sunholo/motoko_ext_context_mode` under
  `packages/motoko-ext-context-mode/` so this branch has a complete,
  versionable local package override.
- Point `ailang.toml` at the local package:

  ```toml
  "sunholo/motoko_ext_context_mode" = { path = "packages/motoko-ext-context-mode" }
  ```

- Replace the stub registration with a real `register_with_config` that wires:
  - `provided_tools()` into `ExtensionHooks.provided_tools`
  - the context-mode prompt patch
  - Bash policy denial for raw `context-mode` / `ctx_*` probes
  - direct handling for `Ctx*` / `ctx_*` tool calls
  - final-output indexing
- Keep env-backed defaults for context-mode bridge configuration:
  - `CONTEXT_MODE_BIN`
  - `CONTEXT_MODE_TIMEOUT_MS`
  - `CONTEXT_MODE_MAX_OUTPUT_CHARS`
  - `CONTEXT_MODE_SNAPSHOT_KEY_PREFIX`
- Add `packages/motoko-ext-context-mode/README.md` explaining that the extension
  wraps <https://github.com/mksglu/context-mode> and documenting two demo prompts
  for showing token-saving behavior.
- Regenerate `ailang.lock` so dependency resolution uses the local context-mode
  package.

## User Impact

Profiles that include `context_mode` now expose the expected context-mode tools
to the model, including:

- `CtxDoctor` / `ctx_doctor`
- `CtxStats` / `ctx_stats`
- `CtxIndex` / `ctx_index`
- `CtxSearch` / `ctx_search`
- `CtxFetchAndIndex` / `ctx_fetch_and_index`
- `CtxExecute` / `ctx_execute`

This makes context-mode usable for repository archaeology and debugging tasks
without forcing the agent to read large raw files into the model context.

## Upstream Follow-Up

The upstream `sunholo/motoko_ext_context_mode` package should be updated and
republished with this fixed `register.ail`. Once a fixed registry version is
available, Motoko can drop the local path override and return to a normal
versioned registry dependency.

## Verification

- `MOTOKO_CONFIG=observability make verify_extensions`
  - `compaction_ai`, `context_mode`, `exa_search`, and `scratchpad` all boot.
- `make build`
  - `sync_packages`, extension boot probes, core AILANG checks, and TUI build
    all pass.
- `timeout 20s make run PROFILE=observability TASK='Say ready and stop.'`
  - starts successfully and reports:

    ```text
    loaded_extensions=compaction_ai, context_mode, exa_search, scratchpad
    ```

- Direct runtime catalog probe confirms `context_mode` advertises the expected
  `Ctx*` / `ctx_*` tool names.

Note: the branch used for this PR does not include the autoresearch package.
Any stale `sunholo/motoko_ext_autoresearch` references were removed from the
active dependency graph so `make run` works on this branch.
