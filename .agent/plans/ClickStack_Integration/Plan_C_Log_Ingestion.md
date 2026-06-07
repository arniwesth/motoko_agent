# Plan C: Motoko Logfile Ingestion Into ClickStack

## Goal

Ship Motoko session JSONL logs from `.motoko/logfile/*.jsonl` into ClickStack
as OpenTelemetry logs, so HyperDX can search session events alongside traces.

Privacy/redaction is explicitly not a requirement for this plan. The local
JSONL files may contain prompts, model output, tool payloads, file contents,
commands, stdout/stderr, and errors; these should be ingested as-is unless a
future requirement says otherwise.

## Current State

- Motoko writes structured session logs under `.motoko/logfile/`.
- Each session has:
  - `session_*.jsonl`: structured event stream.
  - `session_*.md`: human-readable transcript.
- ClickStack trace export already works via:
  - `OTEL_EXPORTER_OTLP_ENDPOINT=http://clickstack:4318`
  - `OTEL_EXPORTER_OTLP_HEADERS=authorization=<ingestion-key>`
- The default Motoko profile now enables ClickStack trace export with
  non-secret defaults in `.motoko/config/default/config.json`.
- The ingestion key lives in `.env` as `OTEL_EXPORTER_OTLP_HEADERS`.

## Preferred Architecture

Add a separate OpenTelemetry collector sidecar in the devcontainer Compose file.
The collector runs in agent mode and tails Motoko's JSONL session logs using the
`filelog` receiver.

Flow:

```text
.motoko/logfile/*.jsonl
  -> motoko-log-collector filelog receiver
  -> JSON parser
  -> batch processor
  -> OTLP HTTP exporter
  -> clickstack:4318/v1/logs
  -> HyperDX Logs
```

Do not send logs directly from the TUI. The sidecar keeps batching, retries,
offset tracking, and ClickStack failures outside the Motoko runtime process.

## Scope

In scope:

- Ingest `.motoko/logfile/*.jsonl`.
- Preserve full JSON event content.
- Parse JSON lines into log attributes/body.
- Attach stable resource attributes:
  - `service.name=motoko-agent`
  - `service.namespace=motoko`
  - `deployment.environment=devcontainer`
- Use the same ClickStack ingestion key already loaded from `.env`.
- Persist filelog receiver offsets across collector restarts.
- Configure through `.motoko/config/default/config.json`.

Out of scope:

- Ingest `.motoko/logfile/*.md`.
- Redaction/filtering.
- Production deployment.
- Historical backfill UI.

## Config Shape

Extend the existing default profile ClickStack block:

```json
{
  "clickstack": {
    "enabled": true,
    "endpoint": "http://clickstack:4318",
    "protocol": "http/protobuf",
    "service_name": "motoko-agent",
    "trace": "standard",
    "trace_max_spans": 100,
    "metrics_exporter": "none",
    "timeout_ms": 5000,
    "logs_enabled": true,
    "logs_source": ".motoko/logfile/*.jsonl",
    "logs_start_at": "end"
  }
}
```

Default recommendation: `logs_start_at=end`.

Reason: the repo can already contain many historical session logs. Starting at
the end avoids a large first-run ingest and duplicate historical noise. For
debugging old sessions, temporarily switch to `beginning` and clear the
collector offset volume.

## Collector Config

Add `.devcontainer/otel/logs-collector.yaml`:

```yaml
receivers:
  filelog/motoko:
    include:
      - /workspace/.motoko/logfile/*.jsonl
    start_at: end
    include_file_path: true
    include_file_name: true
    operators:
      - type: json_parser
        parse_from: body

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000
  resource/motoko:
    attributes:
      - key: service.name
        value: motoko-agent
        action: upsert
      - key: service.namespace
        value: motoko
        action: upsert
      - key: deployment.environment
        value: devcontainer
        action: upsert

exporters:
  otlphttp/clickstack:
    endpoint: http://clickstack:4318
    headers:
      authorization: ${env:CLICKSTACK_INGESTION_KEY}
    compression: gzip

service:
  pipelines:
    logs:
      receivers: [filelog/motoko]
      processors: [resource/motoko, batch]
      exporters: [otlphttp/clickstack]
```

Implementation note: Compose currently has `OTEL_EXPORTER_OTLP_HEADERS` in
`authorization=<key>` format. The collector config wants the bare header value
for `authorization`. Either:

1. Add a separate `.env` key such as `CLICKSTACK_INGESTION_KEY=<key>`, or
2. Generate a collector env var from `OTEL_EXPORTER_OTLP_HEADERS` before
   starting the collector.

Prefer option 1 for clarity unless duplicate secrets in `.env` becomes a
problem.

## Compose Changes

Add a service to `.devcontainer/docker-compose.yml`:

```yaml
  motoko-log-collector:
    image: otel/opentelemetry-collector-contrib:0.130.0
    command: ["--config=/etc/otelcol-contrib/logs-collector.yaml"]
    depends_on:
      - clickstack
    environment:
      CLICKSTACK_INGESTION_KEY: ${CLICKSTACK_INGESTION_KEY:-}
    volumes:
      - ..:/workspace:ro
      - ./.devcontainer/otel/logs-collector.yaml:/etc/otelcol-contrib/logs-collector.yaml:ro
      - motoko-log-collector-storage:/var/lib/otelcol
```

Also add `motoko-log-collector-storage` to top-level volumes.

If the collector image supports persistent storage extension for filelog
offsets, configure it explicitly. If not, verify whether the filelog receiver's
default offset behavior is acceptable. Persistent offsets are preferred to
avoid re-ingesting logs on every rebuild/restart.

## Devcontainer Changes

Update `.devcontainer/devcontainer.json` `runServices` to include:

```json
["app", "clickstack", "motoko-log-collector"]
```

If this adds too much overhead, make log ingestion optional with a future
profile. For now, keep it aligned with default ClickStack tracing since the
user wants integrated logs during normal devcontainer runs.

## TUI/Config Changes

Minimal TUI changes are needed.

- Keep reading `clickstack.logs_enabled`, `logs_source`, and `logs_start_at`
  from `.motoko/config/default/config.json` for documentation and future use.
- The sidecar collector cannot dynamically read Motoko profile config unless
  Compose or an entrypoint script translates it into collector config.

Pragmatic first implementation:

- Put the actual file path and `start_at` value in
  `.devcontainer/otel/logs-collector.yaml`.
- Mirror those values in `.motoko/config/default/config.json`.
- Document that changing `logs_source` / `logs_start_at` currently requires
  updating the collector config or adding a generator script.

Future improvement:

- Add a small script that reads `.motoko/config/default/config.json` and writes
  `.devcontainer/otel/logs-collector.generated.yaml`.
- Run that script as the collector entrypoint before `otelcol-contrib`.

## Validation

1. Rebuild/reopen the devcontainer.
2. Confirm all services are up from the host:

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'clickstack|motoko-log-collector'
```

3. Confirm ClickStack is reachable inside the app container:

```bash
curl -i --max-time 5 http://clickstack:4318
```

Expected without auth header: `401 Unauthorized`.

4. Run Motoko normally and create a new event:

```bash
motoko
```

5. In HyperDX Logs, search:

```text
service.name:motoko-agent
```

Then narrow by event type:

```text
type:session_start
```

or by a current session id:

```text
session_id:<session-id>
```

6. Confirm logs and traces can be correlated by:

- `service.name`
- `session_id`
- timestamp proximity

## Risks

- **Backfill volume**: `start_at=beginning` can ingest many historical logs.
  Keep default at `end`.
- **Offset duplication**: without persistent receiver offsets, collector
  restarts may duplicate log records.
- **Collector config drift**: values mirrored in Motoko config and collector
  YAML can diverge until a generator exists.
- **Schema shape**: JSON parser behavior may put fields under attributes
  rather than top-level body fields. Validate HyperDX search names after first
  ingest and adjust parser/move operators if needed.
- **Resource overhead**: another collector sidecar adds memory/CPU overhead to
  the devcontainer.

## Acceptance Criteria

- A new Motoko session writes `.motoko/logfile/session_*.jsonl`.
- The collector tails the new JSONL lines.
- HyperDX Logs shows those events under `service.name=motoko-agent`.
- Searches by `type`, `session_id`, and `model` work.
- Existing trace ingestion still works.
- Restarting the collector does not replay the entire historical logfile
  directory under the default configuration.
