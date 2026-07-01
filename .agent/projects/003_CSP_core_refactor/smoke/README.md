# 003 CSP-core smokes

Capability proofs for the CSP-core feasibility research
([../RESEARCH-csp-core-feasibility.md](../RESEARCH-csp-core-feasibility.md), §5).

Each test answers: **can an effectful call run inside a live `runEventLoop` handler and
`transmit` its result back on the same socket?** A Bun server drives an AILANG client over a
local WebSocket; the client performs the effect *inside* its `onEvent` handler and sends the
result back; the server records it. Verified on AILANG **v0.26.0**.

| File | Proves |
|---|---|
| `smoke_net_in_handler.ail` + `ws_net_server.ts` | `Net` (`httpGet`) inside the handler — real network round-trip |
| `smoke_ai_in_handler.ail` + `ws_server.ts` | `AI` (`std/ai.call`) inside the handler — stub handler, no creds |
| `smoke_ai_toplevel.ail` | control: AI stub works at top level (isolates "AI in handler" from "AI stub broken") |
| `smoke_cognition_msg.ail` | probes `std/cognition` mailbox fabric (`Msg` effect). **Result: `NO_HANDLER` in native CLI** — the `Msg` transport is browser/WASM-wired (`cmd/wasm/effects.go`); `Msg`/`Cog` are also outside Motoko's effect ceiling (`ailang.toml`). Not usable for core messaging today. |
| `smoke_async_exec_name_routing.ail` | `asyncExecProcess(..., name, ...)` delivers `SourceBytes(name, bytes)` keyed by the supplied source name. |
| `smoke_async_exec_stderr_exit.ail` | `asyncExecProcess` surfaces process exit code as `Closed(code, reason)`; stderr does **not** surface as `SourceBytes`/`SourceText`. |
| `scripts/smoke_run_tool_select_wrapper.ail` | Repo-local wrapper path: `run_tool_select` runs a stderr-live `BashExec` through `scripts/tool_stream_wrapper.py` and returns stdout/stderr/exit_code in the transcript and batched TUI result. |

## Run

```bash
cd .agent/projects/003_CSP_core_refactor/smoke

# Net inside handler (real network round-trip)
RESULT_FILE=/tmp/ws_net_result.txt PORT=8790 bun run ws_net_server.ts        # terminal 1
ailang run --caps IO,Net,Stream --net-allow-http --net-allow-localhost \
  --stream-allow-http --stream-allow-localhost smoke_net_in_handler.ail      # terminal 2
# expect: SERVER_RECEIVED: net-in-handler-OK-7f3a

# AI effect inside handler (stub; no creds)
RESULT_FILE=/tmp/ws_ai_result.txt PORT=8791 bun run ws_server.ts             # terminal 1
ailang run --caps IO,Stream,AI -ai-stub \
  --stream-allow-http --stream-allow-localhost smoke_ai_in_handler.ail       # terminal 2
# expect: SERVER_RECEIVED: AI_REPLY::{"kind":"Wait"}

# Control (no server needed)
ailang run --caps IO,AI -ai-stub smoke_ai_toplevel.ail
# expect: TOPLEVEL_AI_REPLY: {"kind":"Wait"}

# Cognition mailbox probe — NOTE: blocked by Motoko's effect ceiling inside the repo
# (ailang.toml [effects].max excludes Msg/Cog). Copy to a standalone dir whose
# ailang.toml has max = ["IO","Msg","Cog"], then:
ailang run --caps Msg,IO --entry main main.ail
# expect: COG_SEND_ERR / COG_RECV_ERR: NO_HANDLER  (browser/WASM-only transport)

# asyncExecProcess substrate probes for Phase-1 run_tool_select
ailang run --caps Stream,Process,IO smoke_async_exec_name_routing.ail
# expect: PASS_SOURCE_NAME_ROUTING
ailang run --caps Stream,Process,IO smoke_async_exec_stderr_exit.ail
# expect: PASS_CLOSED_EXIT_7_OBSERVED_STDERR_NOT_DELIVERED_AS_SOURCE

# Wrapper-backed run_tool_select path (run from repo root)
cd /workspaces/motoko_agent
MOTOKO_RUN_TOOL_SELECT=1 ailang run --caps AI,FS,Process,IO,Env,Net,SharedMem,Clock,Stream,Trace \
  -ai-stub scripts/smoke_run_tool_select_wrapper.ail
# expect: PASS_RUN_TOOL_SELECT_WRAPPER
```

## Gotchas

- The `AI` effect needs **both** `--caps AI` *and* `-ai <model>` / `-ai-stub`. The `--help` example
  cap list omits `AI`. Missing the cap aborts the handler silently and the process still exits 0.
- `ws://` localhost needs `--stream-allow-http --stream-allow-localhost`; `http://` localhost needs
  `--net-allow-http --net-allow-localhost`. `ailang run` flags must precede the `.ail` file.
- Do **not** `pkill -f ws_server.ts` / `pkill -f PORT=...` — the pattern self-matches the killing
  shell (exit 144). Kill by PID.
