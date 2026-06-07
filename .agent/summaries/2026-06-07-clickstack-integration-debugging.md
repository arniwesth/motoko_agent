# 2026-06-07 ClickStack Integration Debugging Summary

## Context

Branch: `clickstack_integration`

The session implemented the ClickStack integration plan from
`.agent/plans/ClickStack_Integration/` and then spent significant time debugging
local devcontainer OTLP ingestion into ClickStack.

The user rebooted the machine and then hit a VS Code devcontainer port-forwarding
issue when opening HyperDX. The current next step is to reopen/rebuild VS Code's
devcontainer so the updated port-forwarding config takes effect. If ClickStack
trace ingestion still times out after that, the likely next decision is to scrap
ClickStack rather than continue sinking time into the all-in-one collector.

## Implemented Integration

- Upgraded AILANG requirement/runtime references to `0.24.2`.
- Added `Trace` capability to `ailang.toml` and Motoko runtime child caps.
- Added ClickStack sidecar compose support under `.devcontainer/docker-compose.yml`.
- Added standalone ClickStack deploy files under `deploy/clickstack/`.
- Added OTEL env forwarding in `src/tui/src/runtime-process.ts`, gated by
  `MOTOKO_OTEL`.
- Added optional forwarding for:
  - `OTEL_EXPORTER_OTLP_HEADERS`
  - `OTEL_RESOURCE_ATTRIBUTES`
  - `OTEL_TRACES_EXPORTER`
  - `OTEL_METRICS_EXPORTER`
  - `OTEL_EXPORTER_OTLP_TIMEOUT`
  - trace/metrics-specific OTLP endpoint/header/timeout variables
- Added custom `std/trace` instrumentation in `src/core/agent_loop_v2.ail`.
- Added `scripts/spike_trace_forwarding.ail` for minimal OTLP trace testing.
- Updated `.devcontainer/README.md` heavily with ClickStack start/restart,
  duplicate-container, port, network, and host-gateway troubleshooting.
- Updated `.devcontainer/devcontainer.json` to stop forwarding `8081` through
  the app devcontainer and to ignore auto-forwarding for `8081`.

## Current Code State

Important: a final attempted change to remove all custom Motoko tracing was
started conceptually but was interrupted before any patch was applied.

Current `src/core/agent_loop_v2.ail` state:

- `std/trace` is still imported.
- `emit_event` still calls `emit_trace_event`.
- `trace_event_enabled` currently allows only:
  - `session_start`
  - `run_summary`
- Explicit session spans still exist around:
  - `run_v2`
  - `run_v2_from_messages`
  - `run_v2_with_stub`
- The next likely code experiment, if reboot does not help, is to remove or
  gate those explicit `Trace.spanStart` / `Trace.spanEnd` session spans and make
  `emit_trace_event` a no-op, leaving only AILANG built-in OTEL spans.

Current OTEL defaults:

- Runtime defaults are back to OTLP HTTP:
  - `OTEL_EXPORTER_OTLP_ENDPOINT=http://clickstack:4318`
  - `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`
- Devcontainer env also defaults:
  - `OTEL_METRICS_EXPORTER=none`
  - `OTEL_EXPORTER_OTLP_TIMEOUT=5000`
  - `AILANG_TRACE_MAX_SPANS=100`
- If `clickstack` DNS does not resolve inside the devcontainer, use:
  - `OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318`
  - `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`

## Validation Run

Completed successfully during the session:

```bash
ailang check src/core/agent_loop_v2.ail
ailang check scripts/smoke_v2_compaction_full_loop.ail
bun run build
```

Earlier broader validation also passed:

```bash
make check_core
make test_core
make test_integration
cd src/tui && bun run build
```

## Debugging Findings

### UI Port

ClickStack logs print:

```text
Visit the HyperDX UI at http://localhost:8080
```

In this repo the host UI port is mapped to:

```text
http://localhost:8081
```

The user confirmed `8081` works.

After rebooting the machine, the user saw VS Code still intercept
`http://localhost:8081` and try to proxy it into the app devcontainer:

```text
Error: connect ECONNREFUSED 127.0.0.1:8080
```

Cause: `.devcontainer/devcontainer.json` had `forwardPorts: [8080, 8081]`.
ClickStack's HyperDX UI is not running inside the `app` devcontainer; it is a
sibling container whose internal `8080` is published to host `8081`. VS Code was
therefore forwarding to the wrong container.

Applied fix:

```json
"forwardPorts": [8080],
"portsAttributes": {
  "8081": {
    "onAutoForward": "ignore"
  }
}
```

This requires reopening/rebuilding the devcontainer. Then open HyperDX from a
normal host browser at:

```text
http://localhost:8081
```

If VS Code still intercepts `localhost`, try:

```text
http://127.0.0.1:8081
```

### Devcontainer Network Confusion

The user’s devcontainer had not been recreated after the Compose conversion, so
`clickstack` DNS did not resolve inside the devcontainer:

```bash
curl -i http://clickstack:4318
# curl: (6) Could not resolve host: clickstack
```

Using the host gateway worked. Note: current compose maps ClickHouse's HTTP
port to host `18123`, not `8123`.

```bash
curl -i http://host.docker.internal:18123/ping
# HTTP/1.1 200 OK
# Ok.
```

The current unrestarted devcontainer should continue using
`host.docker.internal`. After rebuilding/reopening the devcontainer,
`http://clickstack:4318` should be usable.

### Duplicate ClickStack Containers

At one point there were two ClickStack containers:

```text
devcontainer-clickstack-1
motoko_agent_test_devcontainer-clickstack-1
```

The old `devcontainer-clickstack-1` owned host ports `4317`, `4318`, and `8081`,
so `host.docker.internal:4318` was hitting the wrong container.

The user removed the old container. The correct current state became:

```text
motoko_agent_test_devcontainer-clickstack-1
  0.0.0.0:4317-4318->4317-4318/tcp
  0.0.0.0:8081->8080/tcp
```

### gRPC Attempt Was Wrong

An attempted switch to gRPC was incorrect for the current AILANG exporter.

The error showed:

```text
Post "http://host.docker.internal:4317/v1/metrics"
```

That means AILANG was still using OTLP/HTTP paths while pointed at the gRPC
port. Defaults/docs were reverted to:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

### Spike Succeeds

The minimal trace spike succeeded:

```bash
ailang run --caps IO,Trace --entry main scripts/spike_trace_forwarding.ail
```

Output:

```text
→ Type checking...
→ Effect checking...
✓ Running scripts/spike_trace_forwarding.ail
Trace: standard (set AILANG_TRACE=deep or --trace-tier deep for per-call spans)
trace forwarding spike emitted
```

This proves the OTLP endpoint can accept a tiny AILANG trace.

### Full Motoko Session Still Times Out

Despite the spike succeeding, full Motoko sessions still fail with:

```text
traces export: Post "http://host.docker.internal:4318/v1/traces": processor export timeout
```

and earlier:

```text
failed to upload metrics: reader collect and export timeout:
Post "http://host.docker.internal:4318/v1/metrics": context deadline exceeded
```

Metrics export was then disabled via:

```bash
export OTEL_METRICS_EXPORTER=none
```

but traces still timed out.

## Recommended Post-Reboot Checks

From the host:

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E '4318|clickstack'
```

Expected: only one ClickStack container owns `4317`, `4318`, and `8081`.

From the current devcontainer:

```bash
curl -i --max-time 5 http://host.docker.internal:18123/ping
curl -i --max-time 5 http://host.docker.internal:4318
```

Then run the spike:

```bash
export MOTOKO_OTEL=1
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS='authorization=<hyperdx-ingestion-key>'
export OTEL_SERVICE_NAME=motoko-agent
export AILANG_TRACE=standard
export AILANG_TRACE_MAX_SPANS=20
export OTEL_METRICS_EXPORTER=none
export OTEL_EXPORTER_OTLP_TIMEOUT=5000

ailang run --caps IO,Trace --entry main scripts/spike_trace_forwarding.ail
```

If the spike still works but full Motoko still times out, the next focused code
change is to disable all Motoko custom `std/trace` output and leave only AILANG
built-in OTEL spans.

## Suggested Next Code Experiment

If reboot does not fix ingestion:

1. Remove or gate the three explicit session spans:
   - `Trace.spanStart(session_span)`
   - `Trace.spanEnd(session_span)`
2. Make `emit_trace_event` a no-op, or gate it behind a new env var such as
   `MOTOKO_OTEL_CUSTOM=1`.
3. Keep OTEL env forwarding and `Trace` capability support in place.
4. Re-run:

```bash
ailang check src/core/agent_loop_v2.ail
ailang check scripts/smoke_v2_compaction_full_loop.ail
bun run build
```

If this works, the conclusion is that ClickStack all-in-one cannot handle the
custom Motoko trace shape/volume reliably, even though basic AILANG traces work.

## Current Dirty Files Noted

As of this summary, `git status --short` included:

```text
 M .devcontainer/README.md
 M .devcontainer/devcontainer.json
 M .devcontainer/docker-compose.yml
 M .motoko/config/default/config.json
 M ailang.lock
 M deploy/clickstack/README.md
 M deploy/clickstack/docker-compose.yml
 M src/core/agent_loop_v2.ail
 M src/tui/src/runtime-process.ts
?? .devcontainer/200
```

`.motoko/config/default/config.json`, `ailang.lock`, and `.devcontainer/200`
may include unrelated or incidental local changes. Do not revert them without
checking.
