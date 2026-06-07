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
- The trace ingestion key currently lives in `.env` as
  `OTEL_EXPORTER_OTLP_HEADERS=authorization=<ingestion-key>`.

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
- Use the same ClickStack ingestion key already loaded from `.env`, but store
  the bare key once as `CLICKSTACK_INGESTION_KEY` and derive the OTEL header
  form from it when needed.
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
    "logs_start_at": "beginning",
    "logs_exclude_older_than": "24h"
  }
}
```

Default recommendation: `logs_start_at=beginning` with
`logs_exclude_older_than=24h`.

Reason: Motoko creates a fresh JSONL file for each session and writes important
early records such as `session_start` immediately. With `start_at=end`, the
filelog receiver can discover a new file after the first records were written
and skip those records. Starting at `beginning` makes each newly discovered
session file complete. `exclude_older_than=24h` prevents an initial devcontainer
start from ingesting the entire historical `.motoko/logfile` directory. The
persistent file offset store prevents normal restarts from replaying files that
were already consumed.

For a deliberate historical backfill, temporarily increase or remove
`logs_exclude_older_than`, then clear the collector offset volume before
starting the collector.

Also extend `.env` to use a single source of truth for the ingestion key:

```bash
CLICKSTACK_INGESTION_KEY=<hyperdx-ingestion-key>
```

Migration note: if `.env` currently has only
`OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>`, replace it with
`CLICKSTACK_INGESTION_KEY=<key>`. The TUI should continue to honor an explicitly
set `OTEL_EXPORTER_OTLP_HEADERS` for backwards compatibility, but the collector
sidecar should depend on `CLICKSTACK_INGESTION_KEY`.

Then update the TUI `.env` loader so, after loading `.env`, it synthesizes:

```bash
OTEL_EXPORTER_OTLP_HEADERS=authorization=$CLICKSTACK_INGESTION_KEY
```

only when `OTEL_EXPORTER_OTLP_HEADERS` is not already set. This keeps the
existing trace exporter behavior while avoiding duplicate secrets for the log
collector.

## Collector Config

Add `.devcontainer/otel/logs-collector.yaml`:

```yaml
receivers:
  filelog/motoko:
    include:
      - /workspace/.motoko/logfile/*.jsonl
    start_at: beginning
    exclude_older_than: 24h
    storage: file_storage/motoko
    max_log_size: 16MiB
    include_file_path: true
    include_file_name: true
    retry_on_failure:
      enabled: true
    operators:
      - type: json_parser
        parse_from: body

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  batch:
    timeout: 2s
    send_batch_size: 100
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
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      storage: file_storage/motoko

extensions:
  file_storage/motoko:
    directory: /var/lib/otelcol/file_storage
    create_directory: true

service:
  extensions: [file_storage/motoko]
  pipelines:
    logs:
      receivers: [filelog/motoko]
      processors: [memory_limiter, resource/motoko, batch]
      exporters: [otlphttp/clickstack]
```

Implementation notes:

- The filelog receiver's `storage` field stores file offsets. Without it,
  offsets are memory-only and collector restarts can duplicate or skip data.
- The exporter `sending_queue.storage` stores unsent batches while ClickStack is
  unavailable. This is separate from file offsets.
- The collector config wants the bare authorization header value. That is why
  `.env` should expose `CLICKSTACK_INGESTION_KEY=<key>`, while the TUI derives
  `OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>` for AILANG trace export.
- Motoko JSONL entries can be much larger than ordinary application logs
  because tool result events may include file contents or command output.
  `max_log_size` and `send_batch_size` are deliberately set to avoid silently
  dropping large single-line JSON records or batching too many large records at
  once.

## Compose Changes

Add a service to `.devcontainer/docker-compose.yml`:

```yaml
  motoko-log-collector:
    image: otel/opentelemetry-collector-contrib:0.153.0
    command: ["--config=/etc/otelcol-contrib/logs-collector.yaml"]
    depends_on:
      - clickstack
    env_file:
      - path: ../.env
        required: false
    volumes:
      - ..:/workspace:ro
      - ./otel/logs-collector.yaml:/etc/otelcol-contrib/logs-collector.yaml:ro
      - motoko-log-collector-storage:/var/lib/otelcol
```

Also add `motoko-log-collector-storage` to top-level volumes.

The `env_file` entry is deliberate. The TUI reads root `.env` itself, but Docker
Compose will not reliably inject root `.env` into a sibling collector service
unless the service is explicitly wired to it. If the local Docker Compose
version does not support `required: false`, either create an empty root `.env`
for contributors without secrets or use the older short form:

```yaml
env_file:
  - ../.env
```

and document that `.env` must exist.

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

- Add `CLICKSTACK_INGESTION_KEY` to the `.env` allowlist.
- If `CLICKSTACK_INGESTION_KEY` is set and `OTEL_EXPORTER_OTLP_HEADERS` is not,
  synthesize `OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>` before spawning
  the AILANG child.
- Keep reading `clickstack.logs_enabled`, `logs_source`, and `logs_start_at`
  from `.motoko/config/default/config.json` for documentation and future use.
- The sidecar collector cannot dynamically read Motoko profile config unless
  Compose or an entrypoint script translates it into collector config.

Pragmatic first implementation:

- Put the actual file path and `start_at` value in
  `.devcontainer/otel/logs-collector.yaml`.
- Mirror `logs_source`, `logs_start_at`, and `logs_exclude_older_than` in
  `.motoko/config/default/config.json`.
- Document that changing `logs_source`, `logs_start_at`, or
  `logs_exclude_older_than` currently requires updating the collector config or
  adding a generator script.

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

3. Confirm the collector got the ingestion key:

```bash
docker inspect <motoko-log-collector-container> \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | awk -F= '$1 == "CLICKSTACK_INGESTION_KEY" && length($2) > 0 { print "key-present" }'
```

Expected:

```text
key-present
```

4. Confirm ClickStack is reachable inside the app container:

```bash
curl -i --max-time 5 http://clickstack:4318
```

Expected without auth header: `401 Unauthorized`.

5. Run Motoko normally and create a new event:

```bash
motoko
```

6. Check collector logs for parser/export errors:

```bash
docker logs <motoko-log-collector-container> --tail 200
```

No repeated filelog parser errors or OTLP `401 Unauthorized` errors should
appear.

7. In HyperDX Logs, search:

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

8. Confirm logs and traces can be correlated by:

- `service.name`
- `session_id`
- timestamp proximity

## Risks

- **Backfill volume**: `start_at=beginning` can ingest historical logs. Keep
  `exclude_older_than` enabled by default.
- **Offset duplication**: without persistent receiver offsets, collector
  restarts may duplicate log records.
- **Collector config drift**: values mirrored in Motoko config and collector
  YAML can diverge until a generator exists.
- **Schema shape**: JSON parser behavior may put fields under attributes
  rather than top-level body fields. Validate HyperDX search names after first
  ingest and adjust parser/move operators if needed.
- **Large records**: some tool-result JSONL lines can be very large. If
  collector logs show max-size drops or memory limiter pressure, raise
  `max_log_size`, lower `send_batch_size`, or split large tool payloads in the
  session logger.
- **Resource overhead**: another collector sidecar adds memory/CPU overhead to
  the devcontainer.

## Acceptance Criteria

- A new Motoko session writes `.motoko/logfile/session_*.jsonl`.
- The collector tails the new JSONL lines.
- HyperDX Logs shows those events under `service.name=motoko-agent`.
- Searches by `type`, `session_id`, and `model` work.
- A large tool-result event is ingested without collector max-size errors.
- Existing trace ingestion still works.
- Restarting the collector does not replay already-consumed files because
  filelog offsets are persisted.
- A newly created session includes early records such as `session_start`; these
  are not skipped by tailing from end-of-file.
