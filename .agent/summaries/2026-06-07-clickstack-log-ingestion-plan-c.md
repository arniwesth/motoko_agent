# ClickStack Log Ingestion Plan C Session Summary

Date: 2026-06-07

## User Goal

Implement `.agent/plans/ClickStack_Integration/Plan_C_Log_Ingestion.md` so
Motoko session JSONL logs from `.motoko/logfile/*.jsonl` are shipped into
ClickStack/HyperDX as OpenTelemetry logs.

## Implementation Completed

Added a new OpenTelemetry collector sidecar in `.devcontainer/docker-compose.yml`:

- Service name: `motoko-log-collector`
- Image: `otel/opentelemetry-collector-contrib:0.153.0`
- Config mount:
  - `./otel/logs-collector.yaml:/etc/otelcol-contrib/logs-collector.yaml:ro`
- Workspace mount:
  - `..:/workspace:ro`
- Persistent storage volume:
  - `motoko-log-collector-storage:/var/lib/otelcol`
- Uses root `.env` via service `env_file` with `required: false`.
- Top-level volume `motoko-log-collector-storage` was added.

Added `.devcontainer/otel/logs-collector.yaml`:

- `filelog/motoko` tails `/workspace/.motoko/logfile/*.jsonl`.
- `start_at: beginning`
- `exclude_older_than: 24h`
- `storage: file_storage/motoko` for persistent file offsets.
- `max_log_size: 16MiB`
- JSON parser operator parses each line from `body`.
- Resource attributes:
  - `service.name=motoko-agent`
  - `service.namespace=motoko`
  - `deployment.environment=devcontainer`
- Exports via `otlphttp/clickstack` to `http://clickstack:4318`.
- Authorization header uses `${env:CLICKSTACK_INGESTION_KEY}` as the bare key.
- Exporter sending queue persists through `file_storage/motoko`.

Updated `.devcontainer/devcontainer.json`:

- `runServices` now includes `motoko-log-collector`.

Updated `.motoko/config/default/config.json`:

- Added ClickStack log mirror settings:
  - `"logs_enabled": true`
  - `"logs_source": ".motoko/logfile/*.jsonl"`
  - `"logs_start_at": "beginning"`
  - `"logs_exclude_older_than": "24h"`

Updated TUI source:

- `src/tui/src/index.ts`
  - `.env` allowlist now includes `CLICKSTACK_INGESTION_KEY`.
  - Added `synthesizeClickStackOtelHeaders()`.
  - After `loadDotEnv(...)`, if `CLICKSTACK_INGESTION_KEY` is set and
    `OTEL_EXPORTER_OTLP_HEADERS` is empty/unset, it sets:
    `OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>`.
  - Existing explicit `OTEL_EXPORTER_OTLP_HEADERS` remains authoritative.
  - JSON profile parsing now recognizes `clickstack.logs_enabled`,
    `logs_source`, `logs_start_at`, and `logs_exclude_older_than` for
    documentation/future use.

- `src/tui/src/runtime-process.ts`
  - The explicit child-process env whitelist now forwards
    `CLICKSTACK_INGESTION_KEY`.

Updated docs:

- `deploy/clickstack/README.md`
  - Documents `CLICKSTACK_INGESTION_KEY=<hyperdx-ingestion-key>`.
  - Notes the launcher derives `OTEL_EXPORTER_OTLP_HEADERS` unless explicitly set.
  - Notes the devcontainer collector tails `.motoko/logfile/*.jsonl`.
  - Notes log source/start/age settings are currently mirrored in config and
    collector YAML; changing them requires updating both until a generator exists.

Migrated ignored root `.env`:

- Replaced legacy `OTEL_EXPORTER_OTLP_HEADERS=authorization=...` with
  `CLICKSTACK_INGESTION_KEY=...`.
- The secret value was not printed in the conversation.
- `.env` is gitignored.

## Behavior Notes

Initial ingestion behavior:

- The collector starts at the beginning of each newly discovered matching file.
- It ignores files older than 24 hours due to `exclude_older_than: 24h`.
- Therefore first startup backfills `.motoko/logfile/*.jsonl` files from the last
  24 hours, then tails new files and appended lines.
- Persistent file offsets prevent normal restarts from replaying already
  consumed records.

For deliberate historical backfill:

- Increase/remove `exclude_older_than`.
- Clear the `motoko-log-collector-storage` volume.
- Restart the collector.

Devcontainer/restart guidance:

- The devcontainer should be reopened/rebuilt, or the new service should be
  started explicitly, so Docker Compose starts `motoko-log-collector`.
- ClickStack itself does not need a restart unless it is unhealthy or its own
  config changed.

## Validation Performed

Passed:

- `bun run build` from `src/tui`
- JSON parse check for:
  - `.devcontainer/devcontainer.json`
  - `.motoko/config/default/config.json`
- `node node_modules/.bin/jest --testPathPattern='src/config.test.ts'`
  - 16 tests passed
- Static YAML tab/read check on:
  - `.devcontainer/docker-compose.yml`
  - `.devcontainer/otel/logs-collector.yaml`

Could not run:

- `docker compose -f .devcontainer/docker-compose.yml config`
  - `docker` is not installed in this execution environment.
- Ruby YAML parser check
  - `ruby` is not installed.

Known test caveat:

- `bun node_modules/.bin/jest --testPathPattern='src/config.test.ts'` failed
  before running tests with:
  `TypeError: Attempted to assign to readonly property.`
- Running the same Jest test via Node succeeded. This appears to be an existing
  Bun/Jest runtime compatibility issue rather than a Plan C implementation issue.

## Worktree State After Implementation

Expected modified/untracked files from this session:

- `.devcontainer/devcontainer.json`
- `.devcontainer/docker-compose.yml`
- `.devcontainer/otel/logs-collector.yaml`
- `.motoko/config/default/config.json`
- `deploy/clickstack/README.md`
- `src/tui/src/index.ts`
- `src/tui/src/runtime-process.ts`

Pre-existing dirty file not touched by this implementation:

- `ailang.lock`
  - Diff was timestamp-only in `generated_at`.

`src/tui/dist/index.js` and `src/tui/dist/runtime-process.js` were regenerated
by `bun run build` and contain the new key handling, but they are not tracked in
git, so no dist diff appeared.

## If This Does Not Work

Start with these checks from the host:

```bash
docker compose -f .devcontainer/docker-compose.yml up -d motoko-log-collector
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'clickstack|motoko-log-collector'
docker logs <motoko-log-collector-container> --tail 200
```

Confirm the collector has the key:

```bash
docker inspect <motoko-log-collector-container> \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | awk -F= '$1 == "CLICKSTACK_INGESTION_KEY" && length($2) > 0 { print "key-present" }'
```

Expected:

```text
key-present
```

Confirm ClickStack OTLP HTTP is reachable from inside the app container:

```bash
curl -i --max-time 5 http://clickstack:4318
```

Expected without auth header: `401 Unauthorized`.

Create a new Motoko session, then search HyperDX Logs:

```text
service.name:motoko-agent
type:session_start
```

If early `session_start` events are missing:

- Confirm collector config has `start_at: beginning`.
- Confirm file age is under `exclude_older_than: 24h`.
- Confirm the file offset volume did not already record the file as consumed.

If no logs appear:

- Check collector logs for `401 Unauthorized`, parser errors, or dropped records.
- Confirm root `.env` exists and contains `CLICKSTACK_INGESTION_KEY`.
- Confirm `.devcontainer/docker-compose.yml` service `env_file` points at
  `../.env`.
- Confirm ClickStack is healthy and listening on `clickstack:4318`.

## Follow-up Debugging: Collector Missing After Rebuild

After the Plan C implementation, the user reported that a Motoko session was
running but no logs appeared in ClickStack.

Observed from inside the devcontainer:

- Current Motoko JSONL logs are being written under `.motoko/logfile/*.jsonl`.
- ClickStack resolves on the Compose network:
  - `getent hosts clickstack` returned `192.168.97.2`.
- The app container resolves:
  - `getent hosts app` returned `192.168.97.3`.
- The collector sidecar did **not** resolve:
  - `getent hosts motoko-log-collector` returned no result.
- `clickstack:4318` is reachable.
- A request without an auth header returned the expected `401 Unauthorized`:
  - `missing or empty authorization header: Authorization`
- A direct OTLP logs POST from inside the app container to
  `http://clickstack:4318/v1/logs` using the root `.env`
  `CLICKSTACK_INGESTION_KEY` returned:
  - `HTTP/1.1 200 OK`
  - `{"partialSuccess":{}}`

Conclusion:

- ClickStack ingestion and the ingestion key are working.
- Motoko is producing log files.
- The missing piece is that `motoko-log-collector` is not running or is exiting
  before joining the Compose network.

Applied a follow-up Compose fix:

- Updated `.devcontainer/docker-compose.yml` so `app` depends on both:
  - `clickstack`
  - `motoko-log-collector`

The relevant app service stanza now includes:

```yaml
    depends_on:
      - clickstack
      - motoko-log-collector
```

Reason:

- VS Code attaches to the `app` service. Adding the collector as an app
  dependency makes Compose start the collector when starting the devcontainer
  app service, instead of relying only on `devcontainer.json` `runServices`.

The user is rebuilding the devcontainer after this edit.

Post-rebuild checks to run inside the new devcontainer:

```bash
getent hosts motoko-log-collector clickstack app
```

Expected:

```text
... motoko-log-collector
... clickstack
... app
```

If `motoko-log-collector` still does not resolve after the rebuild:

- Open VS Code Docker/Containers view.
- Look for a container similar to:
  - `motoko_agent-motoko-log-collector-1`
- If it exists but is exited, inspect its logs. The most likely causes are:
  - OpenTelemetry collector config validation error.
  - File storage permission/path issue.
  - Image startup failure.
  - Environment interpolation/auth header issue.

Useful state from before rebuild:

- `.env` exists and contains `CLICKSTACK_INGESTION_KEY`.
- `docker` CLI and `/var/run/docker.sock` are not available inside the app
  container, so sibling container logs cannot be inspected from this shell
  unless Docker access is added.

## Follow-up Debugging: Collector Storage Permission Fix

After the rebuild, `getent hosts motoko-log-collector clickstack app` still
returned only `clickstack` and `app`. Since Docker access was still unavailable
inside the app container, the collector config was validated by downloading and
running `otelcol-contrib` v0.153.0 locally.

Findings:

- `otelcol-contrib validate --config .devcontainer/otel/logs-collector.yaml`
  passed.
- Running the collector locally with the live config failed before startup with:
  `failed to create extension "file_storage/motoko": mkdir /var/lib/otelcol: permission denied`
- This explains why the sidecar could start briefly and then disappear from
  Compose DNS.

Applied fix:

- `.devcontainer/docker-compose.yml`
  - Added `user: "0:0"` to `motoko-log-collector` so the collector can write
    the named volume mounted at `/var/lib/otelcol`.
- `.devcontainer/otel/logs-collector.yaml`
  - Renamed deprecated component aliases:
    - `filelog/motoko` -> `file_log/motoko`
    - `otlphttp/clickstack` -> `otlp_http/clickstack`

Validation after fix:

- `CLICKSTACK_INGESTION_KEY=dummy /tmp/otelcol-test/otelcol-contrib validate --config .devcontainer/otel/logs-collector.yaml`
  passed.
- A smoke run with `/workspace/.motoko` rewritten to the current
  `/workspaces/motoko_agent/.motoko` path and file storage rewritten to `/tmp`
  started successfully, initialized the persistent queue, watched Motoko JSONL
  files, and stayed running until the intentional timeout.

Next check after another devcontainer rebuild/reopen:

```bash
getent hosts motoko-log-collector clickstack app
```

Expected: all three services resolve.

## Current Handoff State

As of the end of this follow-up, the collector startup issue has a concrete fix
in the worktree, but it has not been verified through Docker Compose because
this app container still has neither `docker` nor `/var/run/docker.sock`.

Current expected modified/untracked files:

- `.agent/summaries/2026-06-07-clickstack-log-ingestion-plan-c.md`
- `.devcontainer/devcontainer.json`
- `.devcontainer/docker-compose.yml`
- `.devcontainer/otel/logs-collector.yaml`
- `.motoko/config/default/config.json`
- `deploy/clickstack/README.md`
- `src/tui/src/index.ts`
- `src/tui/src/runtime-process.ts`
- `ailang.lock` remains a pre-existing timestamp-only dirty file.

The next agent should start by checking whether the user has reopened/rebuilt
the devcontainer after the `user: "0:0"` collector fix. If yes, run:

```bash
getent hosts motoko-log-collector clickstack app
curl -i --max-time 5 http://clickstack:4318
```

Expected:

- `motoko-log-collector`, `clickstack`, and `app` all resolve.
- `curl` to `clickstack:4318` without auth still returns `401 Unauthorized`.

Then create or wait for a new Motoko session log and search HyperDX Logs for:

```text
service.name:motoko-agent
```

If `motoko-log-collector` still does not resolve, inspect the sidecar from the
host/VS Code Docker view. The prior local smoke test strongly suggests the
collector config itself is valid after the storage permission fix, so the next
most useful evidence is the actual sidecar container status and logs.
