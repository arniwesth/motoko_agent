# PR Description

## Summary

This branch merges the eval work into one extension-backed feature set:

- Adds a new `sunholo/motoko_ext_eval` AILANG package that registers the `eval` tool.
- Adds persistent eval kernels for Python, JavaScript, AILANG, and Lean 4.
- Adds eval result streaming/rendering in the TUI, including structured cell cards, display bundles, image artifacts, and inline image fallbacks.
- Adds WebSocket loopback support so in-cell `tool.*` calls can route back through the agent's tool policy/dispatch path.
- Adds AILANG scratchpad verification support through `ailang ai-check`/Z3 and optional execution.
- Adds Lean 4 theorem-proving support through `leanprover-community/repl`, with proof metadata that distinguishes verified proofs from `sorry`, skipped, failed, and axiom-tainted results.
- Updates configs, package manifests, dependency locks, installer support, plans, research notes, smoke tests, and regression tests for the eval feature.

## Major Changes

### Eval Extension Package

- Introduces `packages/motoko_eval/` with:
  - `register.ail` for extension registration.
  - `eval.ail` for tool schema, prompt patch, policy, and handling.
  - `ws_loopback.ail` for WebSocket-backed eval execution.
  - `types.ail` and `prompts.ail` for tool metadata and user-facing model guidance.
- Adds the package to `ailang.toml`, `ailang.lock`, and generated extension registry imports.
- Aligns the compose extension registry pin with the dependency version (`0.2.4`).

### Runtime Integration

- Routes `eval` calls in `agent_loop_v2` through the eval WebSocket loopback only when the `eval` extension is active.
- Emits structured `eval_result` events for TUI rendering and session logs.
- Adds `tool_envelope_dispatch.ail` to route in-cell loopback tool calls through extension policy/handling and native fallback dispatch.
- Preserves native tool failure status by propagating `exit_code` from native result payloads instead of forcing loopback results to success.
- Blocks recursive eval loopback calls.

### TUI Eval Runtime

- Adds the `src/tui/src/eval/` subsystem:
  - Python runner and prelude.
  - JavaScript kernel with confined file/tool helpers.
  - Persistent AILANG source-backed session and kernel.
  - Lean session/kernel with optional Mathlib support.
  - Kernel registry, frame types, display parsing, transcript generation, image spilling, loopback server, and WebSocket channel.
- Adds `/exec-cell` and WebSocket exec-cell handling to the env server.
- Adds workdir-confined `tool.read`, `tool.write`, `tool.append`, `tool.search`, and `agent(...)` helpers for eval cells.
- Adds interpreter availability checks and graceful skip notices for missing Python, AILANG, or Lean backends.

### TUI Rendering

- Adds rich eval cards in `ui.ts` with:
  - Per-cell status, code, stdout/stderr, display bundles, errors, metadata, and collapse/expand behavior.
  - AILANG check/verify metadata rendering.
  - Lean elaboration/proof metadata rendering.
  - Image-aware default expansion.
- Adds inline image rendering support:
  - Kitty/iTerm2 image rendering via `pi-tui`.
  - ANSI true-color half-block fallback for terminals without a graphics protocol.
  - Plain text image placeholders when image rendering is unavailable.
- Suppresses eval image capability notices and ignores stray `eval_result` events when eval is not active.

### AILANG Eval

- Implements persistent AILANG cells that accumulate accepted declarations in a source-backed session.
- Rejects duplicate top-level declarations unless the session is reset.
- Gates accepted cells through `ailang ai-check`.
- Supports `verify: "auto" | "required" | "off"` and reports precise verification metadata.
- Supports optional `run`, `entry`, and capability selection with a host-enforced capability ceiling.
- Includes a one-time AILANG teaching guide in the first AILANG eval result.

### Lean Eval

- Adds persistent Lean 4 cells backed by `leanprover-community/repl`.
- Supports `prove: "auto" | "required" | "off"` and optional `mathlib`.
- Reports elaboration status, proof status, committed state, theorem-level proof metadata, sorries, and unexpected axioms.
- Treats a result as verified only when elaboration succeeds, no `sorry` is present, and theorem axioms are limited to the allowed baseline.
- Adds a Lean 4 teaching guide and mixed Lean + AILANG verification documentation.

### Setup And Docs

- Extends `scripts/install-prerequisites.sh` with:
  - Python data science packages used by eval cells.
  - Z3 for AILANG contract verification.
  - Optional `--with-lean` setup for Lean REPL.
  - Optional `--with-lean-mathlib` setup for Mathlib-backed Lean eval.
- Adds eval plans, ADRs, research notes, smoke scripts, handoff docs, and session summaries under `.agent/`.
- Adds `packages/motoko_eval/README.md` with setup notes and a mixed Lean + AILANG validation prompt.

## Config Changes

- Enables `eval` in the default and observability extension orders on the branch.
- Adds `tools.eval_ws_loopback` config plumbing and environment serialization.
- Adds `ws` / `@types/ws` to TUI dependencies for the WebSocket eval channel.

## Tests And Validation

Branch adds coverage for:

- Eval cell normalization and env-server behavior.
- Python/JS display bundle parsing.
- AILANG session persistence, duplicate rejection, check/verify handling, and run behavior.
- Lean session persistence and proof metadata handling.
- WebSocket loopback request/result flow.
- Eval transcript generation and image spilling.
- ANSI image fallback rendering.
- Eval card parsing/rendering and image segment behavior.
- Runtime stream protocol handling for `eval_result`.
- Config serialization for eval loopback.

Validation run locally while preparing this PR description:

- `ailang check src/core/supervisor.ail`
- `ailang check src/core/tool_envelope_dispatch.ail`
- `ailang check src/core/agent_loop_v2.ail`
- `bun run build` from `src/tui`
- `node --experimental-vm-modules node_modules/.bin/jest src/ui.tool-render.test.ts --runInBand` from `src/tui`

Notes:

- The AILANG checks completed successfully but printed an unrelated ClickStack `401 Unauthorized` trace export warning after type/effect checking.
- The Bun/Jest wrapper failed before loading tests with `Attempted to assign to readonly property`; the same focused Jest suite passed under Node's ESM runner.

## Review Notes

- The eval path is intentionally extension-gated. If `eval` is not in the active extension order, the runtime should not take the special eval WS loopback path and the TUI should not render eval image output.
- Native loopback fallback results now preserve failed exit codes, so in-cell native tool errors surface as failures instead of successful payload text.
- Lean/Mathlib support is optional and heavier than the default setup; reviewers can validate core eval behavior without Mathlib.
