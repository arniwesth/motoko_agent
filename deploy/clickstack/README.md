# ClickStack Deployment

This compose file runs the ClickStack all-in-one image for local Motoko
observability outside the devcontainer.

```bash
cd deploy/clickstack
docker compose up -d
```

Open HyperDX at http://localhost:8081. The collector accepts OTLP on:

- `http://localhost:4318` for OTLP HTTP
- `localhost:4317` for OTLP gRPC

Point Motoko at the collector before starting the TUI:

```bash
export MOTOKO_OTEL=1
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_SERVICE_NAME=motoko-agent
export AILANG_TRACE=standard
```

If HyperDX requires an ingestion key, also set:

```bash
export OTEL_EXPORTER_OTLP_HEADERS='authorization=<hyperdx-ingestion-key>'
```

The Route J fallback in `.agent/plans/ClickStack_Integration/Plan_B_Custom_Spans.md`
is intentionally not enabled here yet. The custom-span forwarding spike must
first decide whether native `std/trace` spans reach OTLP automatically; if not,
add a collector `filelog` receiver here to map `.motoko/logfile/session_*.jsonl`
events into spans.

The local AILANG `v0.24.2` spike confirmed that `Trace` is a real capability:
`ailang run --caps IO --entry main scripts/spike_trace_forwarding.ail` fails,
while `--caps IO,Trace` succeeds.

To stop ClickStack:

```bash
docker compose stop
```

To remove stored ClickStack data:

```bash
docker compose down -v
```
