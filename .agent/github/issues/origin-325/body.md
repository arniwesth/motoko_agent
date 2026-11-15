---
repo: arniwesth/motoko_agent
issue: 325
title: "AILANG v0.60.0 warns LDR006: motoko_ext_scratchpad imports four src/core modules, and that is planned to become an error"
---

## Summary

`packages/motoko_scratchpad` (`sunholo/motoko_ext_scratchpad`) imports four modules of the root
package. The root package also depends on it, so the import goes back up the dependency
graph. AILANG v0.60.0 warns about each one with `LDR006` and says the rule is "planned to
become an error". On v0.54.14, which this repo pins, there is no warning and nothing fails
today. Found while testing #324 on v0.60.0. It is not one of the items in #323.

## Context

**Repro** (`main` @ `8f3ee198`, AILANG v0.60.0 release binary with its own `std/`). The warnings
appear on any root file that loads the package:

```sh
AILANG_STDLIB_PATH=<v0.60.0 std/> ailang check scripts/dst/stream_parity_dst.ail
```

```
LDR006 (warning): package sunholo/motoko_ext_scratchpad imports "src/core/env_client", which is a module of the root package local/motoko_agent; a dependency importing the package that depends on it is allowed for now but is planned to become an error — move the code into sunholo/motoko_ext_scratchpad, or into a package both declare
```

The same line repeats for `src/core/tool_contract`, `src/core/tool_envelope_dispatch` and
`src/core/types`. `check` still exits 0. v0.54.14 prints no `LDR006`.

**The code.** `LDR006` is new in v0.60.0. It is not in the `error_codes.json` of v0.55.0
through v0.59.0. Its catalog entry: "Import from an undeclared package … (or a dependency
importing the root package)". No other package in `packages/` imports from `src/`. The root
`ailang.toml` depends on the package (line 25), and `src/core/ext/registry_generated.ail`,
`src/core/tool_phase.ail` and `scripts/dst/declared_vs_performed.ail` load it.

| Package file | Imports | What it uses |
|---|---|---|
| `scratchpad.ail:17`, `ws_loopback.ail:13` | `src/core/env_client` | `exec_scratchpad_cell`, a `! {Net}` call to the env server |
| `ws_loopback.ail:11` | `src/core/types` | `CellExecResult`, the record `exec_scratchpad_cell` returns |
| `ws_loopback.ail:10` | `src/core/tool_contract` | `ToolCallEnvelope`, `ToolResultEnvelope`. `motoko_ext_abi/types.ail:78` declares the same two records, field for field |
| `ws_loopback.ail:12` | `src/core/tool_envelope_dispatch` | `dispatch_tool_envelope`, which sends a loopback tool call back into the core runtime. That module imports `tool_runtime`, `tool_dispatch_adapter` and `ext/runtime`, and nothing else in the repo imports it |

The first three look movable:
- **`exec_scratchpad_cell` and `CellExecResult`:** only this package uses them. `backend.ail`
  imports `exec_in` from `env_client`, not these.
- **The envelope types:** the package already depends on `motoko_ext_abi`, which declares
  both records with the same fields. A record is structural, so the package can import them
  from there.

The fourth is harder to move. `dispatch_tool_envelope` is the core tool runtime itself, so it
cannot go into the package or into a package both declare without that package containing the
runtime.

## Expected

- No `LDR006` from v0.60.0 for any root file that loads the package. To check, run the repro
  with v0.60.0 or later and grep for `LDR006`.
- The same source still checks on v0.54.14 for as long as that stays the pin. #322 and #324 hold
  to that rule.
- For `dispatch_tool_envelope`, a decision on one of these:
  - The core passes the dispatcher in. For example, `ExtRuntime` or `ExtCtx` carries a function
    value, which keeps the package free of `src/` imports.
  - `ws_loopback` moves out of the package into `src/`.
  - The package stops being a dependency of the root, if it can be loaded some other way.

  Settle this before the AILANG release that makes `LDR006` an error. That release is not
  scheduled yet.
