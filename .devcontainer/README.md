# Devcontainer Observability

The devcontainer runs Motoko in the `app` service by default. ClickStack is
declared as an opt-in sidecar so normal rebuilds stay lightweight.

## Ports

- `8080`: Motoko env server
- `8081`: HyperDX UI from ClickStack
- `4317`: OTLP gRPC
- `4318`: OTLP HTTP

## Start ClickStack

From `.devcontainer/`:

```bash
docker compose --profile observability up -d clickstack
```

Then enable export for the shell that starts Motoko:

```bash
export MOTOKO_OTEL=1
make run
```

Motoko forwards OTLP environment variables to the AILANG child process only when
`MOTOKO_OTEL` is set. This keeps default runs from attempting exports while the
sidecar is down.

AILANG `v0.24.2` requires the `Trace` capability for programs that use
`std/trace`; the Motoko launcher grants it to the child runtime.

Open HyperDX at http://localhost:8081. If the first-run setup requires an
ingestion key, set it before starting Motoko:

```bash
export OTEL_EXPORTER_OTLP_HEADERS='authorization=<hyperdx-ingestion-key>'
```

## Stop Or Reset

```bash
unset MOTOKO_OTEL
docker compose --profile observability stop clickstack
```

To remove persisted ClickStack data:

```bash
docker compose --profile observability down -v
```

ClickStack can use roughly 1.5-2 GB of memory. Use a Codespaces or local Docker
machine size that has room for ClickHouse, Mongo, the collector, and the app.
