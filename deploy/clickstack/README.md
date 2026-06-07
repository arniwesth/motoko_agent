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

ClickHouse's HTTP ping/query endpoint is exposed at http://localhost:18123.
Check readiness with:

```bash
curl -i http://localhost:18123/ping
```

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
export CLICKSTACK_INGESTION_KEY=<hyperdx-ingestion-key>
```

The Motoko launcher derives
`OTEL_EXPORTER_OTLP_HEADERS=authorization=$CLICKSTACK_INGESTION_KEY` when the
OTLP headers variable is not already set. Existing explicit
`OTEL_EXPORTER_OTLP_HEADERS` values still take precedence.

If OTLP HTTP on `4318` returns timeouts from `/v1/traces` or `/v1/metrics`,
lower trace volume while debugging:

```bash
export AILANG_TRACE_MAX_SPANS=100
```

Do not point AILANG at `4317` for this setup. Current exports use OTLP/HTTP
paths such as `/v1/metrics`, so `4317` will produce HTTP requests against the
gRPC port.

The Route J fallback in `.agent/plans/ClickStack_Integration/Plan_B_Custom_Spans.md`
is intentionally not enabled here yet. The custom-span forwarding spike must
first decide whether native `std/trace` spans reach OTLP automatically; if not,
add a collector `filelog` receiver here to map `.motoko/logfile/session_*.jsonl`
events into spans.

In the devcontainer, session JSONL logs are tailed by the
`motoko-log-collector` service from `.motoko/logfile/*.jsonl` and exported to
ClickStack as OpenTelemetry logs. The source path, starting point, and age
cutoff are mirrored in `.motoko/config/default/config.json` for documentation;
changing them also requires updating
`.devcontainer/otel/logs-collector.yaml` until a generator script exists.

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
