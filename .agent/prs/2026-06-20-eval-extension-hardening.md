# PR Description

## Summary

This branch adds an extension-backed `scratchpad` tool for persistent agent-side cells and hardens the surrounding runtime, logging, and loopback paths.

- Adds `sunholo/motoko_ext_scratchpad`, registering the `scratchpad` tool.
- Adds persistent scratchpad kernels for Python, JavaScript, AILANG, and Lean 4.
- Adds structured `scratchpad_result` events and TUI/plain/markdown rendering for scratchpad cells.
- Adds WebSocket loopback support so in-cell `tool.*` calls can route back through the agent tool policy/dispatch path.
- Adds AILANG contract checking/verification through `ailang ai-check`/Z3 and optional execution.
- Adds Lean theorem-proving support through `leanprover-community/repl`, with proof metadata that distinguishes verified proofs from `sorry`, skipped, failed, and axiom-tainted results.
- Removes the old `eval` tool/package/config/protocol naming from this feature to avoid confusion with eval harnesses and LLM evals.

## Major Changes

### Scratchpad Extension Package

- Introduces `packages/motoko_scratchpad/` with:
  - `register.ail` for extension registration.
  - `scratchpad.ail` for tool schema, prompt patch, policy, and handling.
  - `ws_loopback.ail` for WebSocket-backed scratchpad execution.
  - `types.ail` and `prompts.ail` for tool metadata and model guidance.
- Adds the package to `ailang.toml`, `ailang.lock`, and generated extension registry imports.
- Removes the old `eval` extension/tool alias from the registry, tool renderer, and active-extension detection.
- Aligns the compose extension registry pin with the dependency version (`0.2.4`).

### Runtime Integration

- Routes `scratchpad` calls in `agent_loop_v2` through the scratchpad WebSocket loopback only when the `scratchpad` extension is active.
- Emits structured `scratchpad_result` events for TUI rendering and session logs.
- Adds `tool_envelope_dispatch.ail` to route in-cell loopback tool calls through extension policy/handling and native fallback dispatch.
- Preserves native tool failure status by propagating `exit_code` from native result payloads instead of forcing loopback results to success.
- Blocks recursive scratchpad loopback calls.
- Renames env-server endpoints from `/exec-cell` and `/exec-cell-ws` to `/scratchpad-cell` and `/scratchpad-cell-ws`.

### TUI Scratchpad Runtime

- Renames the TUI subsystem from `src/tui/src/eval/` to `src/tui/src/scratchpad/`.
- Adds:
  - Python runner and prelude.
  - JavaScript kernel with confined file/tool helpers.
  - Persistent AILANG source-backed session and kernel.
  - Lean session/kernel with optional Mathlib support.
  - Kernel registry, frame types, display parsing, transcript generation, image spilling, loopback server, and WebSocket channel.
- Adds workdir-confined `tool.read`, `tool.write`, `tool.append`, `tool.search`, and `agent(...)` helpers for scratchpad cells.
- Adds interpreter availability checks and graceful skip notices for missing Python, AILANG, or Lean backends.

### TUI And Log Rendering

- Adds rich scratchpad cards in `ui.ts` with:
  - Per-cell status, code, stdout/stderr, display bundles, errors, metadata, and collapse/expand behavior.
  - AILANG check/verify metadata rendering.
  - Lean elaboration/proof metadata rendering.
  - Image-aware default expansion.
- Adds dedicated plain and markdown transcript formatting for `scratchpad_result`.
- Adds inline image rendering support:
  - Kitty/iTerm2 image rendering via `pi-tui`.
  - ANSI true-color half-block fallback for terminals without a graphics protocol.
  - Plain text image placeholders when image rendering is unavailable.
- Suppresses scratchpad image capability notices and ignores stray scratchpad result rendering when the scratchpad extension is not active.

### AILANG Scratchpad

- Implements persistent AILANG cells that accumulate accepted declarations in a source-backed session.
- Rejects duplicate top-level declarations unless the session is reset.
- Gates accepted cells through `ailang ai-check`.
- Supports `verify: "auto" | "required" | "off"` and reports precise verification metadata.
- Supports optional `run`, `entry`, and capability selection with a host-enforced capability ceiling.
- Includes a one-time AILANG teaching guide in the first AILANG scratchpad authoring attempt.
- Documents a known issue: if the AILANG teaching prompt was already loaded earlier in the wider agent session, the scratchpad AILANG kernel can load it again because its prompt cache is scoped to the scratchpad session.

### Lean Scratchpad

- Adds persistent Lean 4 cells backed by `leanprover-community/repl`.
- Supports `prove: "auto" | "required" | "off"` and optional `mathlib`.
- Reports elaboration status, proof status, committed state, theorem-level proof metadata, sorries, and unexpected axioms.
- Treats a result as verified only when elaboration succeeds, no `sorry` is present, and theorem axioms are limited to the allowed baseline.
- Adds a Lean 4 teaching guide and mixed Lean + AILANG verification documentation.

### Setup And Docs

- Extends `scripts/install-prerequisites.sh` with:
  - Python data science packages used by scratchpad cells.
  - Z3 for AILANG contract verification.
  - Optional `--with-lean` setup for Lean REPL.
  - Optional `--with-lean-mathlib` setup for Mathlib-backed Lean scratchpad use.
- Adds `packages/motoko_scratchpad/README.md` with setup notes and the AILANG duplicate-teaching-prompt known issue.
- Updates configs, package manifests, dependency locks, installer support, smoke tests, and regression tests for the scratchpad feature.

## Config Changes

- Enables `scratchpad` in the default and observability extension orders on the branch.
- Renames tool config from `tools.eval_ws_loopback` to `tools.scratchpad_ws_loopback`.
- Renames scratchpad-related env vars from `MOTOKO_EVAL_*` to `MOTOKO_SCRATCHPAD_*`.
- Adds `ws` / `@types/ws` to TUI dependencies for the WebSocket scratchpad channel.

## Tests And Validation

Branch adds coverage for:

- Scratchpad cell normalization and env-server behavior.
- Python/JS display bundle parsing.
- AILANG session persistence, duplicate rejection, check/verify handling, and run behavior.
- Lean session persistence and proof metadata handling.
- WebSocket loopback request/result flow.
- Scratchpad transcript generation and image spilling.
- ANSI image fallback rendering.
- Scratchpad card parsing/rendering and image segment behavior.
- Runtime stream protocol handling for `scratchpad_result`.
- Config serialization for scratchpad loopback.

Validation run locally:

- `AILANG_RELAX_MODULES=1 ailang check packages/motoko_scratchpad/scratchpad.ail`
- `ailang check src/core/supervisor.ail`
- `ailang check src/core/agent_loop_v2.ail`
- `ailang check src/core/tool_envelope_dispatch.ail`
- `bun run build` from `src/tui`
- `node --experimental-vm-modules node_modules/.bin/jest src/ui.tool-render.test.ts src/session-logger.test.ts src/runtime-process.stream-protocol.test.ts src/env-server.test.ts src/scratchpad/ailang-session.test.ts src/scratchpad/transcript.test.ts src/scratchpad/loopback.test.ts src/scratchpad/image-segment.test.ts src/scratchpad/kernel-ailang.test.ts --runInBand` from `src/tui`
- `node --experimental-vm-modules node_modules/.bin/jest src/runtime-process.stream-protocol.test.ts --runInBand` from `src/tui` after the final fixture rename

Notes:

- The AILANG checks completed successfully but printed the existing unrelated ClickStack `401 Unauthorized` trace export warning after type/effect checking.
- The focused Jest suite passed under Node's ESM runner.

## Review Notes

- The scratchpad path is intentionally extension-gated. If `scratchpad` is not in the active extension order, the runtime should not take the special scratchpad WS loopback path and the TUI should not render scratchpad image output.
- Native loopback fallback results now preserve failed exit codes, so in-cell native tool errors surface as failures instead of successful payload text.
- Lean/Mathlib support is optional and heavier than the default setup; reviewers can validate core scratchpad behavior without Mathlib.
- Benchmark/eval-harness terminology remains only where it refers to the separate benchmark infrastructure, not this tool.
