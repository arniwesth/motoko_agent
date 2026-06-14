# Devcontainer Profiles

This repo provides two VS Code devcontainer profiles:

- `.devcontainer/default/devcontainer.json`: starts only the `app` service.
- `.devcontainer/observability/devcontainer.json`: starts `app`, ClickStack,
  and the Motoko log collector sidecar.

The default profile is intentionally lightweight and matches the main branch
shape. Use the observability profile when you want Motoko logs or traces shipped
to ClickStack/HyperDX.

The observability profile runs Motoko in the `app` service and ClickStack as a
sibling sidecar. Both services must be in the same Compose project for
`http://clickstack:4318` to resolve inside the devcontainer.

## Ports

- `8080`: Motoko env server
- `8081`: HyperDX UI from ClickStack
- `18123`: ClickHouse HTTP ping/query endpoint from ClickStack
- `4317`: OTLP gRPC
- `4318`: OTLP HTTP

## Start Observability Sidecars

ClickStack and the Motoko log collector start when VS Code rebuilds/reopens the
observability devcontainer because
`.devcontainer/observability/devcontainer.json` includes all required services:

```json
"runServices": ["app", "clickstack", "motoko-log-collector"]
```

To start them manually from `.devcontainer/` using the same Compose files as the
observability profile:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d clickstack motoko-log-collector
```

That command must use the same Compose project as the devcontainer `app`
service. If Docker shows different prefixes, for example:

```text
devcontainer-clickstack-1
motoko_agent_test_devcontainer-app-1
```

then the two containers are on different Compose networks and
`http://clickstack:4318` will not resolve inside the devcontainer.

From the host shell, find the devcontainer app's Compose project name:

```bash
docker ps --format '{{.Names}}' | grep 'devcontainer-app'
docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' <app-container-name>
```

Then start the sidecars with that project name from `.devcontainer/`:

```bash
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml up -d clickstack motoko-log-collector
```

If startup fails with a port allocation error such as:

```text
Bind for 0.0.0.0:4317 failed: port is already allocated
```

another ClickStack container is already publishing the OTLP port. Stop the old
container from the host shell, then start the sidecars again:

```bash
docker ps --format '{{.Names}} {{.Ports}}' | grep '4317'
docker stop <old-clickstack-container>
docker rm <old-clickstack-container>
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml up -d clickstack motoko-log-collector
```

If `docker ps` shows two ClickStack containers, the one with published host
ports is the one reached by `host.docker.internal`:

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E '4318|clickstack'
```

For example, if `devcontainer-clickstack-1` owns `0.0.0.0:4317-4318` and
`<project-name>-clickstack-1` has no published ports, Motoko is still talking to
the old sidecar. Stop and remove the old container, then recreate the intended
one:

```bash
docker stop devcontainer-clickstack-1
docker rm devcontainer-clickstack-1
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml rm -sf clickstack
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml up -d clickstack motoko-log-collector
```

The `observability` Motoko config profile enables ClickStack export with
non-secret defaults from `.motoko/config/observability/config.json`. The
observability devcontainer sets `MOTOKO_CONFIG=observability`. Shell environment
variables still override those defaults for one-off runs.

Motoko forwards OTLP environment variables to the AILANG child process only when
`MOTOKO_OTEL` is set. The observability profile sets this when
`clickstack.enabled=true`.

AILANG `v0.24.2` requires the `Trace` capability for programs that use
`std/trace`; the Motoko launcher grants it to the child runtime.

Open HyperDX at http://localhost:8081. ClickStack's logs may mention
`http://localhost:8080`; that is the container's internal UI port. In this repo
the host port is `8081` because Motoko's env server uses `8080`.

ClickStack requires an ingestion API key for OTLP. Get it from HyperDX
`Team Settings -> API Keys`, then store the bare key in the repo-root `.env`:

```bash
CLICKSTACK_INGESTION_KEY=<hyperdx-ingestion-key>
```

The observability Compose profile passes `.env` to both the app and
`motoko-log-collector` services. The Motoko launcher derives
`OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>` for trace export when
`CLICKSTACK_INGESTION_KEY` is set and `OTEL_EXPORTER_OTLP_HEADERS` is not
already set. Existing explicit `OTEL_EXPORTER_OTLP_HEADERS` values still take
precedence for the app process.

After that, run Motoko normally from the observability devcontainer profile; no
per-shell OTEL exports are required.

## Log Ingestion

The `motoko-log-collector` sidecar tails `.motoko/logfile/*.jsonl` through the
workspace mount at `/workspace/.motoko/logfile/*.jsonl`, parses each JSON line,
adds Motoko resource attributes, and exports logs to ClickStack over OTLP HTTP.

Current collector defaults are:

- `start_at: beginning`
- `exclude_older_than: 24h`
- `max_log_size: 16MiB`
- persistent file offsets in the `motoko-log-collector-storage` volume
- resource attributes:
  - `service.name=motoko-agent`
  - `service.namespace=motoko`
  - `deployment.environment=devcontainer`

The same log source/start/age settings are mirrored in
`.motoko/config/observability/config.json` for profile visibility. The collector
currently reads `.devcontainer/otel/logs-collector.yaml` directly, so changing
those values requires updating both files until a generator exists.

On first startup, the collector backfills matching files from the last 24 hours
and then tails new records. Normal restarts keep offsets in the persistent
storage volume, so already-consumed records are not replayed.

## Connectivity Checks

Inside the devcontainer, the compose-network endpoint should resolve after the
devcontainer has been rebuilt/reopened from this compose config:

```bash
curl -i http://clickstack:4318
curl -i http://clickstack:8123/ping
```

If `clickstack` does not resolve, the current shell is probably in a container
that was launched before the compose conversion or the sidecar was started under
a different Compose project. Start the observability sidecars with the same
project name as the devcontainer app, or use Docker's host gateway fallback
instead:

```bash
curl -i http://host.docker.internal:4318
curl -i http://host.docker.internal:18123/ping
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Expected responses:

- `401 Unauthorized`: collector is reachable, but
  `CLICKSTACK_INGESTION_KEY=<key>` is missing or wrong, or an explicit
  `OTEL_EXPORTER_OTLP_HEADERS` override is wrong.
- `404` or `405`: collector is reachable; use the OTLP exporter rather than
  a browser/curl GET for actual ingestion.
- `Ok.` from `/ping`: ClickHouse inside ClickStack is reachable.
- `Could not resolve host: clickstack`: recreate/reopen the devcontainer, or
  start ClickStack with the same Compose project as the devcontainer app.
- A timeout from `/v1/traces` or `/v1/metrics`: the app is exporting, but
  ClickStack is not responding fast enough. Lower `AILANG_TRACE_MAX_SPANS` and
  restart the sidecar if the healthcheck is not healthy. Do not point AILANG at
  `4317` for this setup; current exports use OTLP/HTTP paths such as
  `/v1/metrics`, so `4317` will produce HTTP requests against the gRPC port.

To reduce exporter noise while debugging, disable metrics and keep traces only:

```bash
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=none
export OTEL_EXPORTER_OTLP_TIMEOUT=5000
```

Motoko forwards these variables to the AILANG child process when `MOTOKO_OTEL`
is set.

Motoko's own custom `std/trace` events are intentionally low-volume: only
`session_start` and `run_summary` are mirrored into OTLP. The full structured
event stream remains in JSONL; mirroring every agent-loop event can overload
the ClickStack all-in-one collector during long sessions.

If `clickstack` still does not resolve after starting it with the app's Compose
project name, inspect both containers from the host shell:

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'clickstack|devcontainer-app'
docker inspect -f '{{json .NetworkSettings.Networks}}' <app-container-name>
docker inspect -f '{{json .NetworkSettings.Networks}}' <clickstack-container-name>
```

Both containers need to share a network, usually
`<project-name>_default`. If the app container is not attached to that network,
connect it from the host shell:

```bash
docker network connect <project-name>_default <app-container-name>
```

Then retry `curl -i http://clickstack:8123/ping` from inside the devcontainer.

## Stop Or Reset

```bash
unset MOTOKO_OTEL
docker compose -f docker-compose.yml -f docker-compose.observability.yml stop clickstack motoko-log-collector
```

If ingestion times out or the UI is unhealthy, restart only the observability
sidecars. This leaves the devcontainer `app` service running:

```bash
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml stop clickstack motoko-log-collector
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml rm -f clickstack motoko-log-collector
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml up -d clickstack motoko-log-collector
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml logs -f clickstack motoko-log-collector
```

To deliberately replay recent JSONL logs, stop the collector, remove its offset
volume, and start it again:

```bash
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml stop motoko-log-collector
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml rm -f motoko-log-collector
docker volume rm <project-name>_motoko-log-collector-storage
docker compose -p <project-name> -f docker-compose.yml -f docker-compose.observability.yml up -d motoko-log-collector
```

`docker compose down` may print:

```text
Network devcontainer_default Resource is still in use
```

That is expected while the devcontainer `app` service is still attached to the
Compose network. It does not prevent restarting ClickStack with the commands
above.

To remove persisted ClickStack data and collector offsets, close/stop the
devcontainer app first, then run:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml down -v
```

ClickStack can use roughly 1.5-2 GB of memory. Use a Codespaces or local Docker
machine size that has room for ClickHouse, Mongo, the collector, and the app.
