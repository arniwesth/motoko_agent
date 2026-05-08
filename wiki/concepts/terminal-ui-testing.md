---
sources: [summaries/TUI_OM_Command_Patterns.md, summaries/AILANG_Agent.md, summaries/think-block.md]
brief: Testing interactive terminal UIs via mock terminals, protocol contracts, and phase-gated acceptance criteria.
---

# Terminal UI Testing

Testing interactive terminal UIs is a specialised practice that involves simulating user input, mimicking runtime events, asserting on rendered screen state, and verifying inter-process communication contracts. The [[summaries/AILANG_Agent]] project applies this methodology across multiple layers: pi-tui component tests with mock `ProcessTerminal` instances, environment server acceptance tests, brain integration tests with `--ai-stub`, JSONL protocol contract tests, and end-to-end benchmarks on real repository issues.

## Motivation

Terminal UIs built with libraries such as `@mariozechner/pi-tui` often contain non-trivial interaction logic that is error-prone when written without tests. The think block component (see [[concepts/think-block]]) demonstrates several issues that automated testing would catch:

- **Cycling logic**: `selectThinkBlock` advances through blocks, wraps around, and ensures only one block is expanded at a time.
- **State leakage**: `selectedThinkIdx` and `thinkBlocks` may persist across sessions, leading to incorrect indices.
- **Visual artifacts**: A blank line appears for each collapsed block because an empty `Text` row is always added.
- **Timestamp integrity**: The displayed timestamp changes on every expand/collapse toggle.

Beyond individual components, the SWE-Agent architecture introduces additional failure modes that demand systematic testing:

- **Protocol drift**: The [[concepts/JSONL Protocol]] between the TypeScript frontend and the AILANG brain process must remain well-formed and correctly sequenced. A missing `session_start` event or malformed `obs` payload can silently break the UI rendering pipeline.
- **Environment server reliability**: The embedded [[concepts/Environment Server]] (`tui/src/env-server.ts`) handles command execution, timeouts, and snapshot/restore. Failures here propagate as incorrect observations fed back to the LLM.
- **Brain determinism**: The AILANG brain loop in `swe/rpc.ail` must behave identically under `--ai-stub` as under live API calls, modulo the response content. This enables fast, repeatable integration tests.
- **Cache integrity**: The [[concepts/SharedMem Cache]] layer must store and retrieve trajectory hints across runs without corruption or stale data.

Without tests, these defects can go unnoticed during development and are easily reintroduced during refactoring.

## Testing Layers

The SWE-Agent project employs a layered testing strategy mirroring its architecture. Each layer produces independently testable artifacts before the next begins.

### Layer 1: Environment Server Acceptance Tests

The environment server is the first component built and tested. Four acceptance criteria must pass:

1. **Echo command**: `POST /exec` with `{ "cmd": "echo hello" }` returns `{ "stdout": "hello\n", "exit_code": 0 }`.
2. **Nonzero exit**: `POST /exec` with a failing command returns the correct exit code and stderr.
3. **Timeout enforcement**: A command exceeding the timeout (default 30s) is killed and returns a nonzero exit code.
4. **Snapshot/restore round-trip**: `POST /snapshot` captures state via `git stash`; `POST /restore` with the returned `snapshot_id` restores it.

These tests run against the real `child_process.execSync` with a temporary working directory, ensuring the server behaves correctly under realistic conditions.

### Layer 2: Brain Integration Tests (Mock Env + `--ai-stub`)

The AILANG brain (`swe/rpc.ail`) is tested against a mock environment server that returns canned responses. Combined with the `--ai-stub` flag — which replaces live LLM calls with deterministic stub responses — this produces a fully repeatable test harness. Key assertions:

- The JSONL event stream is well-formed: every line is valid JSON with a `type` field.
- Events arrive in the correct order: `session_start` → `thinking` → `proposed_cmd` → `obs` → (repeat) → `done` or `error`.
- Abort handling: sending `{"type":"abort"}` on stdin causes the brain to exit cleanly after the current observation, with an `error` event emitted.
- Model change handling: sending `{"type":"model_change","model":"..."}` updates SharedMem and the brain reflects the new model in subsequent behaviour (phase 5).
- Step limit: the brain terminates with an `error` event after the configured maximum steps (default 50).

### Layer 3: JSONL Protocol Contract Tests

Integration tests verify the full protocol contract between the TypeScript `Brain` class and the AILANG process:

- **Event parsing**: `Brain` correctly deserializes every event type (`session_start`, `thinking`, `proposed_cmd`, `obs`, `done`, `error`) from raw JSONL lines.
- **Command delivery**: `Brain.send()` writes well-formed JSON commands to the AILANG stdin pipe, and the brain consumes them at the top of each loop iteration (non-blocking poll via `_io_poll_stdin`).
- **Graceful shutdown**: When the brain process exits, `Brain` invokes the `onExit` callback and stops the readline interface.
- **Malformed line resilience**: Lines that fail to parse as JSON are silently skipped without crashing the event stream.

### Layer 4: pi-tui Component Tests

The recommended approach in pi-tui is to drive the `AgentUI` class (or similar component) with a **mock `ProcessTerminal`**. This mock object:

- Emulates the underlying terminal process by accepting events (`thinking`, `session_start`, etc.) and forwarding them to the UI.
- Provides a way to inject raw keyboard input, such as `ctrl+t` for cycling think blocks.
- Exposes the rendered output — typically through the text content of UI elements like `headerRow` and `bodyRow` — allowing assertions on what the user would see.

A typical test file (e.g., `tui/src/ui.think-cycling.test.ts`) follows this pattern:

1. **Setup**: Create an `AgentUI` instance with a mock `ProcessTerminal`.
2. **Inject events**: Send a sequence of `thinking` events with `think`/`answer` payloads to simulate model responses.
3. **Simulate key presses**: Call the internal handler for `ctrl+t` (or fire a key event through the mock terminal) to trigger cycling.
4. **Assert**: Verify that `headerRow.text` shows the correct step number and block state (collapsed/expanded), and that `bodyRow.text` is hidden or shown accordingly. Checks include wrap-around behaviour, single-block toggling, and multiple-block state consistency.

This pattern is already used in existing tests such as `ui.wait-state.test.ts`, which also drives the UI with a mock terminal. The same approach can be extended to other interactive features like the `(N/M)` position indicator, lazy body-row insertion for collapsed blocks, the `/model` SelectList overlay, and the slash-command autocomplete registry.

### Layer 5: End-to-End Benchmark

The final validation gate runs the full system on a 10-issue SWE-bench sample, targeting >50% resolution rate. This catches integration issues that unit and contract tests miss: real LLM behaviour, network latency, disk I/O patterns, and long-running session state management. The benchmark script compares results against a mini-swe-agent baseline to quantify the implementation's effectiveness.

## Key Considerations

- **Test isolation**: Each test should reset the UI state or create a fresh instance to avoid cross-test contamination (similar to the `session_start` reset fix). For brain tests, spawn a fresh AILANG process per test case.
- **Edge cases**: Cover boundary conditions: zero think blocks, exactly one block, many blocks, rapid sequential keystrokes, empty stdout, commands that produce only stderr, and snapshot/restore with no prior stash.
- **Visibility guarantees**: Assert not only on the text content but also on whether rows are added or removed from the box (e.g., `bodyAdded` flag) to prevent hidden blank lines.
- **Timestamps**: Capture original timestamps at render time and test that they remain unchanged after expand/collapse cycles.
- **Mock fidelity**: The mock environment server must respect the same timeout and output-truncation behaviour as the real server to produce realistic observations.
- **Phase gating**: Each phase in the build order has a concrete success criterion that must pass before proceeding. This prevents compounding errors across layers.

## Related Concepts

- [[concepts/think-block]] — the component that motivates the pi-tui testing strategy.
- [[summaries/think-block]] — the original issue document detailing the bugs and proposed fixes.
- [[concepts/session-state-management]] — resetting UI state between sessions to avoid stale data.
- [[concepts/JSONL Protocol]] — the inter-process communication contract tested in Layer 3.
- [[concepts/Environment Server]] — the embedded HTTP server with its own acceptance test suite.
- [[concepts/Yolo Mode]] — simplifies brain testing by eliminating pause/confirm branches.
- [[concepts/SharedMem Cache]] — trajectory hint storage tested for cross-run integrity.
- [[summaries/AILANG_Agent]] — the full implementation plan describing the phase-gated testing strategy.

Adopting this multi-layered testing methodology ensures that terminal UI interactions, protocol contracts, and system integration remain robust across changes, reducing regressions and improving developer confidence.

See also: [[summaries/TUI_OM_Command_Patterns]]