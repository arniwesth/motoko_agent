# motoko_core

Shared host/runtime contracts used by extension packages.

Primary exported modules:
- `src/core/tool_contract`
- `src/core/types`

Extension ABI types (`ExtCtx`, `ExtRuntime`, `ExtensionHooks`, etc.) now live in `pkg/sunholo/motoko_ext_abi/types` — host and extensions import them from the same single source.
