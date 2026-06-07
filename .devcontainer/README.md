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
export OTEL_EXPORTER_OTLP_ENDPOINT=http://clickstack:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_SERVICE_NAME=motoko-agent
export AILANG_TRACE=standard
make run
```

Motoko forwards OTLP environment variables to the AILANG child process only when
`MOTOKO_OTEL` is set. This keeps default runs from attempting exports while the
sidecar is down.

AILANG `v0.24.2` requires the `Trace` capability for programs that use
`std/trace`; the Motoko launcher grants it to the child runtime.

Open HyperDX at http://localhost:8081. ClickStack's logs may mention
`http://localhost:8080`; that is the container's internal UI port. In this repo
the host port is `8081` because Motoko's env server uses `8080`.

ClickStack requires an ingestion API key for OTLP. Get it from HyperDX
`Team Settings -> API Keys`, then set it before starting Motoko:

```bash
export OTEL_EXPORTER_OTLP_HEADERS='authorization=<hyperdx-ingestion-key>'
```

## Connectivity Checks

Inside the devcontainer, the compose-network endpoint should resolve after the
devcontainer has been rebuilt/reopened from this compose config:

```bash
curl -i http://clickstack:4318
```

If `clickstack` does not resolve, the current shell is probably in a container
that was launched before the compose conversion. Use Docker's host gateway
fallback instead:

```bash
curl -i http://host.docker.internal:4318
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
```

Expected responses:

- `401 Unauthorized`: collector is reachable, but
  `OTEL_EXPORTER_OTLP_HEADERS='authorization=<key>'` is missing or wrong.
- `404` or `405`: collector is reachable; use the OTLP exporter rather than
  a browser/curl GET for actual ingestion.
- `Could not resolve host: clickstack`: recreate/reopen the devcontainer, or
  use `host.docker.internal`.

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
