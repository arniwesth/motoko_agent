# AILANG ClickHouse Integration Options

Date: 2026-05-31

## Context

We want to investigate how AILANG can interface with other languages and external systems, concretely to access ClickHouse.

AILANG MCP docs for `0.19.1` show relevant host effects and stdlib support:

- `Net` effect via `std/net`, including `httpRequest(method, url, headers, body) -> Result[HttpResponse, NetError] ! {Net}`.
- `Process` effect via `std/process`, including `exec(cmd, args) -> Result[ProcessOutput, ProcessError] ! {Process}`.
- Go interop exists via runtime embedding and compile-time code generation in AILANG docs, but for ClickHouse the direction likely matters: Go should host or adapt ClickHouse access rather than AILANG reimplementing a full driver first.

ClickHouse exposes multiple viable integration surfaces:

- HTTP/HTTPS interface.
- `clickhouse` and `clickhouse-local` CLI.
- Official Go client (`clickhouse-go`) and lower-level/high-throughput Go clients.
- Native TCP protocol.

## Recommendation

Start with direct ClickHouse HTTP from AILANG via `std/net.httpRequest`.

This is the simplest useful path because ClickHouse already exposes a language-neutral HTTP API, and AILANG already has the `Net` capability. It avoids driver implementation work while still keeping the ClickHouse boundary explicit and capability-gated.

## Preferred Progression

1. Direct HTTP client in AILANG

   Best first implementation.

   Use ClickHouse HTTP/HTTPS endpoints and AILANG `std/net.httpRequest`. Query with formats such as `JSON`, `JSONEachRow`, `CSV`, or `TabSeparated`. This should handle reads, inserts, admin queries, and prototyping.

2. Thin wrapper around ClickHouse CLI

   Useful for local development, `clickhouse-local`, file processing, and quick experiments.

   Use AILANG `std/process.exec` with allowlisted commands. Main weaknesses are process-spawn overhead, argument hygiene, deployment portability, and weaker connection/pooling behavior.

3. Go adapter using `clickhouse-go`

   Best production path when connection pooling, native protocol, high-throughput inserts, compression, retries, observability, or stronger typing matter.

   Expose it to AILANG as one of:

   - A small local HTTP service called through `std/net`.
   - A process bridge called through `std/process`.
   - A Go host embedding AILANG and implementing ClickHouse access as a host-side effect/extern boundary.

4. MCP

   Good for AI-agent/tooling workflows, not as the primary application database boundary.

   Use MCP when the goal is: an agent can inspect/query ClickHouse through governed tools. Avoid making MCP the core app data-access path unless the app itself is agent-tool orchestration.

5. Full native AILANG ClickHouse client

   Highest control, highest cost.

   A native client would need protocol handling, auth, compression, formats, type mapping, TLS, streaming, error handling, and compatibility work. Only worth doing if AILANG specifically needs a first-class reusable database driver and the HTTP/Go adapter paths are insufficient.

6. WASM

   Not a first-choice ClickHouse integration path.

   WASM can be useful if AILANG is embedded in a WASM-capable host, or if a component is already packaged as WASM. It does not eliminate the need for host-provided networking/TLS/process/database capabilities. For ClickHouse, WASM still needs an external boundary.

## Initial Package Shape

A practical first package could be:

```text
sunholo/clickhouse_http
```

Potential API:

```text
query(sql, format) -> Result[string, ClickHouseError] ! {Net}
queryJson(sql) -> Result[Json, ClickHouseError] ! {Net}
insertJsonEachRow(table, rows) -> Result[(), ClickHouseError] ! {Net}
ping() -> Result[bool, ClickHouseError] ! {Net}
```

Implementation outline:

```text
POST https://host:8443/?query=<sql>
Headers: Authorization or X-ClickHouse-User / X-ClickHouse-Key
Body: large SQL, INSERT payloads, or JSONEachRow data
Format: append FORMAT JSON / JSONEachRow / TabSeparated as appropriate
```

## When To Escalate

Stay with direct HTTP until one of these becomes true:

- Sustained high-throughput batch inserts are needed: move to Go + `clickhouse-go` or a lower-level Go ClickHouse client.
- Local file/S3 ad-hoc analytics are needed: wrap `clickhouse-local`.
- Agent-facing database tools are needed: add an MCP server/tool layer.
- A reusable language-native database library is needed and HTTP limitations are concrete: consider a native AILANG ClickHouse client.

## Short Decision

Build the HTTP wrapper first. Keep the API small and typed. Treat Go and MCP as adapter layers for performance and agent-tooling needs, not as the initial implementation.
