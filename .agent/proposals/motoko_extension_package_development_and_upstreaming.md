# Motoko Extension Package Development And Upstreaming Proposal

## Context

Motoko now consumes most extensions as AILANG registry packages through `ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_context_mode" = "0.2.1"

[extensions]
packages = [
  "sunholo/motoko_ext_context_mode@0.2.1",
]
```

The generated registry imports package modules:

```ailang
import pkg/sunholo/motoko_ext_context_mode/register (...)
```

This is the right long-term model. The problem we hit is that, while fixing `context_mode`, it was tempting to patch Motoko directly under:

```text
src/core/ext/context_mode/register.ail
```

and hand-edit:

```text
src/core/ext/registry_generated.ail
```

That works locally, but it is fragile because `registry_generated.ail` is generated and will be overwritten. It also bypasses the actual registry package that downstream users consume.

## Proposed Development Workflow

### 1. Treat `ailang-packages` As Source Of Truth

Extension implementation work should happen in:

```text
ailang-packages/packages/motoko-ext-<name>/
```

For context mode:

```text
ailang-packages/packages/motoko-ext-context-mode/
```

The Motoko repo should not carry long-lived extension implementations under `src/core/ext/<name>` unless they are genuinely core-owned and not packageized.

### 2. Use Local Path Dependencies During Development

Desired workflow to confirm with the AILANG maintainer: when testing an unpublished package change from Motoko, use a path dependency in `motoko_agent/ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_context_mode" = { path = "../ailang-packages/packages/motoko-ext-context-mode" }
```

Then run:

```bash
ailang lock
ailang generate-extension-registry
```

The generated registry should continue to import the package namespace:

```ailang
import pkg/sunholo/motoko_ext_context_mode/register (...)
```

This avoids hand-editing generated code and exercises the same package import mechanism used after publishing.

If this does not currently work with `ailang generate-extension-registry`, that is the gap to fix: the generator should resolve package identity through `[dependencies]` even when the dependency source is a local path. The fallback should not be a mergeable hand-edit to `registry_generated.ail`; at most, a temporary local override can be used for debugging and then removed before review.

### 3. Keep `[extensions].packages` Aligned With Package Identity

If path dependencies are supported as proposed above, the extension package list should keep using the package identity:

```toml
[extensions]
packages = [
  "sunholo/motoko_ext_context_mode@<local-package-version>",
]
```

The version suffix should match the local package's `[package].version`.

During local path testing, the package's own `ailang.toml` still defines:

```toml
[package]
name = "sunholo/motoko_ext_context_mode"
version = "<local-package-version>"
```

If the version is being prepared for publish, bump the package version in `ailang-packages`, then update the Motoko manifest accordingly.

### 4. Never Hand-Edit `registry_generated.ail`

`src/core/ext/registry_generated.ail` should only be changed by:

```bash
ailang generate-extension-registry
```

If a desired change requires manual edits to that file, that is a signal that either:

- the package manifest is wrong,
- the package exports are wrong,
- or the generator needs an improvement.

### 5. Validate Package And Host Together

Package-local validation should run from the extension package directory:

```bash
ailang lock
AILANG_RELAX_MODULES=1 ailang check register.ail
```

For packages with behavior split across sibling modules, check those modules too. For context mode that means at least:

```bash
AILANG_RELAX_MODULES=1 ailang check context_mode.ail
AILANG_RELAX_MODULES=1 ailang check exec.ail
AILANG_RELAX_MODULES=1 ailang check prompts.ail
AILANG_RELAX_MODULES=1 ailang check compress.ail
```

If `ailang check --package .` is available and reliable for package workspaces, prefer that as the package-level gate.

Motoko-side validation should then run from `motoko_agent`:

```bash
ailang lock
ailang generate-extension-registry
make check_core
```

In this branch, `make check_core` already depends on `verify_extensions`, so it covers extension registration boot checks as well as core type-checking.

For context mode specifically, keep a host-level smoke test:

```bash
AILANG_RELAX_MODULES=1 CORE_EXT_ORDER=context_mode \
  ailang run --caps IO,Env,FS,Process,SharedMem,Clock \
  --entry main scripts/smoke_context_mode_dispatch.ail
```

That test should verify:

- extension registration succeeds,
- expected tools are advertised,
- unsafe `BashExec` context-mode calls are denied,
- core tools such as `CtxDoctor` / `CtxStats` dispatch,
- `on_describe_tools` returns useful schemas, not empty `{}` parameter objects
- after regeneration, `src/core/ext/registry_generated.ail` imports `pkg/sunholo/motoko_ext_context_mode/register`, not a local `src/core/ext/context_mode/register` override.

## Publishing Workflow

### 1. Bump Package Version

In `ailang-packages/packages/motoko-ext-context-mode/ailang.toml`:

```toml
[package]
name = "sunholo/motoko_ext_context_mode"
version = "0.2.2"
```

### 2. Publish From `ailang-packages`

Run the package publish flow:

```bash
ailang publish --dry-run
ailang publish
```

Publishing requires registry credentials, so this step likely needs maintainer involvement.

### 3. Switch Motoko Back To Registry Dependency

After publishing, replace the local path dependency in `motoko_agent/ailang.toml`:

```toml
"sunholo/motoko_ext_context_mode" = "0.2.2"
```

and update:

```toml
[extensions]
packages = [
  "sunholo/motoko_ext_context_mode@0.2.2",
]
```

Then run:

```bash
ailang lock
ailang generate-extension-registry
make check_core
```

In this branch, `make check_core` includes `make verify_extensions`.

The generated registry should still import:

```ailang
pkg/sunholo/motoko_ext_context_mode/register
```

## Context-Mode-Specific Lessons

The current context-mode package in the registry was not enough for Motoko because registration was effectively a stub:

- no useful `provided_tools`,
- no real `on_tool_handle`,
- no schema propagation via `on_describe_tools`.

The local fix showed the behavior Motoko needs:

- route `Ctx*` / `ctx_*` calls through the context-mode MCP bridge,
- deny direct `BashExec` attempts to run context-mode,
- expose tool schemas so provider-native typed tool use can pass required args,
- advertise only provider-safe names such as `CtxExecute` and `ctx_execute`,
- keep dotted aliases accepted internally but do not advertise them.

## Open Questions For Maintainer

1. Should `ailang generate-extension-registry` support path dependencies in `[dependencies]` while `[extensions].packages` keeps package identity/version strings?
2. Should the docs explicitly recommend path dependency development for Motoko extensions?
3. Should `ailang init motoko-extension` scaffold:
   - a host smoke test,
   - `on_describe_tools` schema placeholders,
   - provider-safe tool naming guidance,
   - and a publish checklist?
4. Should the package registry enforce or warn that advertised tool names match provider-safe patterns?
5. Should Motoko keep `.packages/` sync tooling, or is that now deprecated in favor of direct `ailang-packages` path deps?
6. Is `ailang check --package .` the intended package-wide validation command for extension packages, or should package templates provide an explicit module check list?

## Desired End State

For extension development:

- implement in `ailang-packages`,
- consume via path dependency in `motoko_agent`,
- regenerate registry,
- run Motoko smoke tests,
- publish package,
- switch Motoko back to registry version,
- regenerate registry again.

No hand-edited generated files. No long-lived local extension forks. The published package remains the source of truth.
