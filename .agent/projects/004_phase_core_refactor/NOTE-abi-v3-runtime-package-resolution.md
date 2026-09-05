# ABI v3 Runtime Package Resolution Note

Date: 2026-07-07

## Question

Does `make run` launch Motoko with the ABI v3 packages created during the rollout session?

## Answer

Yes, for the checked-in workspace state after the ABI v3 rollout.

`make run` depends on `build`:

```make
build: sync_packages check_core build_tui

run: build
	clear
	MOTOKO_CONFIG=$(PROFILE) ./scripts/run-agent.sh
```

The root `ailang.toml` now resolves the ABI and active rollout packages through durable workspace
path dependencies:

- `sunholo/motoko_ext_abi` -> `packages/motoko-ext-abi`
- `sunholo/motoko_ext_compaction_ai` -> `packages/motoko-ext-compaction-ai`
- `sunholo/motoko_ext_compaction_structural` -> `packages/motoko-ext-compaction-structural`

The regenerated `ailang.lock` records these as `source: "path"` packages with the rollout versions:

- `sunholo/motoko_ext_abi@3.0`
- `sunholo/motoko_ext_compaction_ai@0.3.0`
- `sunholo/motoko_ext_compaction_structural@1.1.0`

The generated registry imports extension registers by package name, for example:

```ailang
import pkg/sunholo/motoko_ext_compaction_ai/register (register_with_config as register_compaction_ai)
import pkg/sunholo/motoko_ext_compaction_structural/register (register_with_config as register_compaction_structural)
import pkg/sunholo/motoko_ext_abi/types (ExtensionHooks)
import pkg/sunholo/motoko_ext_abi/types (ExtRegistry)
```

Those `pkg/...` imports resolve through the lockfile and therefore use the workspace `packages/`
copies, not newly created registry-cache directories.

## Default Profile

At the time of this note, `.motoko/config/default/config.json` enables:

```json
[
  "compaction_ai",
  "context_mode",
  "exa_search",
  "scratchpad",
  "compaction_structural"
]
```

So a default `make run` loads both rollout compaction extensions, and both share the ABI v3 package
through the same path dependency.

## Caveat

`make run` still runs `sync_packages` as part of `build`. That script mirrors older source-tree
extensions and `src/core` into `.packages/`, then runs `ailang lock`.

This does not overwrite the ABI v3 rollout packages under `packages/`. It may still consult the
preexisting AILANG registry cache for unrelated registry dependencies such as `sunholo/logging`.
The rollout-specific package sources must remain under `packages/`; do not recreate
`motoko_ext_abi@3.0`, `motoko_ext_compaction_ai@0.3.0`, or `motoko_ext_compaction_structural@1.1.0`
under `~/.ailang/cache`.
