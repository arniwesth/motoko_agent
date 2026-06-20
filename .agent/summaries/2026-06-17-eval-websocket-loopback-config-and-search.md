# 2026-06-17 eval WebSocket loopback config + search contract hardening

## Context

Worked through `.agent/plans/omp-style-python-eval/02-design-b-prime-reentrant-websocket.md` follow-ups for the faithful eval loopback: make the WebSocket eval path usable from normal Motoko profile config, smoke it from Motoko, and debug a `tool.search()` false-negative / parse failure observed in manual testing.

The user repeatedly tested with the `observability` profile and the `eval` extension loaded:

- `Loaded extensions: compaction_ai, context_mode, exa_search, eval`
- Core Runtime `v0.2.0`, TUI `v0.1.0`

## Main changes

### WebSocket eval loopback opt-in

The eval extension now uses a WebSocket-driven path when `MOTOKO_EVAL_WS_LOOPBACK=1`:

- `packages/motoko_eval/ws_loopback.ail`
  - Connects to `${ctx.env_server_url}/exec-cell-ws`.
  - Sends a `run` frame with eval cells/session/timeout.
  - Captures `tool-request` frames from the env-server.
  - Dispatches those requests back through `dispatch_tool_envelope(rt, ctx, ...)`.
  - Transmits correlated `tool-result` frames back on the same WebSocket.
  - Falls back to the existing HTTP `exec_cell(...)` path when the opt-in env var is absent or the WebSocket cannot connect.

Important design detail: AILANG `onEvent` handlers cannot directly do the full effectful dispatch safely; the implemented path captures the request frame to a temp file, lets `runEventLoop` return, then dispatches outside the handler and transmits the result. The smoke in `.agent/research/omp-style-python-eval/smoke/smoke_deferred_dispatch.ail` exercises that deferred-dispatch shape.

### Config-backed opt-in

`MOTOKO_EVAL_WS_LOOPBACK=1` was moved from shell-only usage into project config:

- `src/tui/src/config.ts`
  - Added TOML mapping: `tools.eval_ws_loopback -> MOTOKO_EVAL_WS_LOOPBACK`.
  - Added `eval_ws_loopback = false` to the TOML template.
  - Added `eval_ws_loopback: false` to the JSON template.
- `src/tui/src/index.ts`
  - Reads `tools.eval_ws_loopback` from active profile `config.json`.
  - Applies it to `process.env.MOTOKO_EVAL_WS_LOOPBACK` before runtime spawn.
  - Shell-provided `MOTOKO_EVAL_WS_LOOPBACK` remains protected and wins over profile config.
- `.motoko/config/*/config.json`
  - Added `"eval_ws_loopback": false` to checked-in profiles.
  - Set `"eval_ws_loopback": true` for `.motoko/config/observability/config.json`, matching the profile used during testing.
- `src/tui/src/config.test.ts`
  - Added coverage for TOML boolean serialization to `MOTOKO_EVAL_WS_LOOPBACK=1`.

### Search contract hardening

Manual Motoko smoke showed:

```text
search parse error: Expecting value: line 1 column 1 (char 0)
WebSocket mentions count: 0
```

Initial model diagnosis blamed missing `rg`, but local inspection showed `rg` is installed. The actual problem was a contract mismatch:

- The test prompt expected `tool.search()` to return JSON with `matches`.
- The fallback TS loopback returned ripgrep text stdout.
- The WebSocket path could route through core `Search`, whose metadata is structured, but the cell-facing `stdout` contract was not normalized.

Fixes:

- `src/tui/src/eval/loopback.ts`
  - Local fallback `tool.search()` now parses ripgrep output into:

    ```json
    {
      "tool": "Search",
      "pattern": "...",
      "matches": [
        {
          "path": "...",
          "line_number": 1,
          "line_text": "...",
          "context": []
        }
      ],
      "exit_code": 0
    }
    ```

  - No-match ripgrep status `1` still maps to success with an empty `matches` array.
- `packages/motoko_eval/ws_loopback.ail`
  - `ReadFile` results are unwrapped so `tool.read(path)` returns plain file content to Python/JS cells.
  - `Search` results are returned as JSON-encoded metadata so `json.loads(tool.search(...))` works.
- `src/tui/src/eval/loopback.test.ts`
  - Added a regression test asserting local loopback `search` returns parseable JSON with a `matches` array.

## Motoko test prompt used

The final intended manual prompt shape was:

```text
Test the opt-in WebSocket eval loopback.

Use exactly one Python eval cell.

Inside the Python cell:
- Do not use open(), pathlib, os.walk(), glob, subprocess, or direct filesystem APIs.
- Access repository files only through tool.read() and tool.search().
- Call tool.read("README.md") and print the first line.
- Call tool.search("WebSocket", "src/tui/src/eval"), parse the returned string as JSON, count len(obj["matches"]), and display that count.
- Build a summary dictionary with:
  - readme_first_line
  - websocket_mentions_count
  - used_tool_read: true
  - used_tool_search: true
  - direct_fs_used: false
  - expected_transport: "websocket-loopback"
- Display that summary as JSON using display(summary).

After the eval tool returns, summarize:
1. Whether tool.read worked.
2. Whether tool.search worked.
3. Whether the eval cell avoided direct filesystem access.
4. Whether the returned JSON summary is consistent with WebSocket eval loopback.
5. The JSON summary returned by the eval cell.

Important: do not replace tool.read/tool.search with normal Python filesystem code.
```

Before the search-contract fix, this prompt demonstrated transport success but JSON parse failure for search.

## Verification

Commands that passed:

```bash
bun run build
node --experimental-vm-modules node_modules/.bin/jest src/eval/loopback.test.ts src/config.test.ts --runInBand
AILANG_RELAX_MODULES=1 ailang check packages/motoko_eval/ws_loopback.ail
```

`ailang lock` was run after modifying the path package; `ailang.lock` was refreshed.

Expected warning observed during AILANG checking:

```text
traces export: failed to send to http://clickstack:4318/v1/traces: 401 Unauthorized
```

The trace export warning did not fail the check.

Known Jest runner gotcha still applies:

- `bun node_modules/.bin/jest ...` failed before test loading with `TypeError: Attempted to assign to readonly property`.
- The same tests passed through Node's ESM VM path.

## Carry-forward notes

- The profile config knob is now `tools.eval_ws_loopback`.
- For `observability`, it is intentionally enabled:

  ```json
  "tools": {
    "eval_ws_loopback": true
  }
  ```

- Shell env still wins. If `MOTOKO_EVAL_WS_LOOPBACK` is already set externally, profile config will not override it.
- `tool.read()` and `tool.search()` now intentionally have different ergonomic return shapes:
  - `tool.read(path)` returns raw file content.
  - `tool.search(pattern, path)` returns a JSON string with `matches`.
- If a future test still gets `websocket_mentions_count: 0`, check whether the active profile is actually `observability` or whether a shell env/profile override disabled `MOTOKO_EVAL_WS_LOOPBACK`.
- The loaded extension set includes `context_mode`, so in-cell loopback requests should continue to exercise real policy/registry dispatch, not the old env-server-only fork.

## Files touched in this workstream

- `.agent/research/omp-style-python-eval/smoke/smoke_deferred_dispatch.ail`
- `.motoko/config/*/config.json`
- `ailang.lock`
- `packages/motoko_eval/ws_loopback.ail`
- `src/tui/src/config.ts`
- `src/tui/src/config.test.ts`
- `src/tui/src/eval/loopback.ts`
- `src/tui/src/eval/loopback.test.ts`
- `src/tui/src/index.ts`

