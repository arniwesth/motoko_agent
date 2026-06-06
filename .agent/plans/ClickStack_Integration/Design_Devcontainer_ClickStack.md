# Design: ClickStack as a Devcontainer Sidecar

**Status**: Design (pre-implementation)
**Author**: drafted 2026-06-06
**Scope**: the `.devcontainer` infrastructure — converting to a compose-based devcontainer, running ClickStack as an **opt-in** sidecar, and the env-wiring handoff. The in-AILANG span instrumentation lives in the companion **[Plan_B_Custom_Spans.md](./Plan_B_Custom_Spans.md)**; this doc references it rather than duplicating it.
**Decisions locked** (2026-06-06): opt-in via compose profile; persistent named volume; devcontainer-focused doc.
**Sources**: [ClickStack all-in-one (ClickHouse Docs)](https://clickhouse.com/docs/use-cases/observability/clickstack/deployment/all-in-one), [ClickStack getting-started](https://github.com/ClickHouse/clickhouse-docs/blob/main/docs/use-cases/observability/clickstack/getting-started.md), [hyperdxio/hyperdx](https://github.com/hyperdxio/hyperdx).

---

## 1. Goal

Give every Motoko contributor a **local OTLP target** so AILANG-native traces (Plan A) and Motoko's custom spans (Plan B) can be viewed in HyperDX without any cloud account or external service — by running `clickhouse/clickstack-all-in-one` as a sidecar in the dev environment. Default boot stays lightweight; observability is opt-in.

This doc covers **only** the infra + wiring. What spans get emitted, and the `std/trace` instrumentation, are Plan B.

---

## 2. Current state (what we're changing)

- `.devcontainer/devcontainer.json` is **single-container** (`build.dockerfile: Dockerfile`). Adding a service requires converting to a **compose-based** devcontainer.
- `.devcontainer/Dockerfile` (ubuntu:24.04, user `motoko`, runs `scripts/install-prerequisites.sh`) — reused unchanged as the `app` service build.
- **Port 8080 is taken**: Motoko's embedded env-server defaults to `ENV_PORT=8080` (`src/tui/src/config.ts:106`, `src/tui/src/index.ts:17`). HyperDX's UI *also* defaults to 8080 → host-port collision to resolve.
- `forwardPorts: [8080]`, `containerEnv` (API keys), `postCreateCommand` (bun install/build) — all carry over.

---

## 3. Architecture

```
.devcontainer/
├── devcontainer.json        # dockerComposeFile + service:"app" + runServices:["app"]
├── docker-compose.yml       # services: app (build: Dockerfile), clickstack (profile: observability)
├── Dockerfile               # unchanged
└── otel/collector.yaml      # (if needed) collector override to accept unauth OTLP on the compose net
```

Two services on one compose network:

| Service | Image / build | Starts by default? | Purpose |
|---|---|---|---|
| `app` | build from `.devcontainer/Dockerfile` | ✅ (`runServices: ["app"]`) | the dev container |
| `clickstack` | `clickhouse/clickstack-all-in-one:latest` | ❌ — `profiles: [observability]` | ClickHouse + OTel collector + HyperDX UI |

The `app` reaches ClickStack over compose DNS at **`http://clickstack:4318`** (no host networking needed for ingestion).

### Why opt-in (profile + runServices)
The all-in-one bundles ClickHouse + Mongo + collector + UI — comfortably **1.5–2 GB RAM** and a slower boot. Making every devcontainer/Codespaces start pay that is wasteful since most sessions don't need traces. So:
- `clickstack` is declared under `profiles: [observability]` → compose won't start it unless the profile is active.
- `devcontainer.json` sets `runServices: ["app"]` → the devcontainer lifecycle only auto-starts `app`.
- A dev opts in with one command (§6).

---

## 4. Concrete config (illustrative — verify against current ClickStack release before merge)

### `.devcontainer/docker-compose.yml`
```yaml
services:
  app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
    volumes:
      - ..:/workspaces/motoko_agent:cached     # explicit bind-mount (compose does NOT auto-mount)
    command: sleep infinity
    environment:
      # Wiring handoff to Plan B — see §5
      MOTOKO_OTEL: "1"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://clickstack:4318"
      OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
      OTEL_SERVICE_NAME: "motoko-agent"
      AILANG_TRACE: "standard"

  clickstack:
    image: clickhouse/clickstack-all-in-one:latest
    profiles: ["observability"]               # opt-in: not started by default
    ports:
      - "8081:8080"                            # HyperDX UI on host 8081 (avoid env-server's 8080)
      - "4317:4317"                            # OTLP gRPC
      - "4318:4318"                            # OTLP HTTP
    volumes:
      - clickstack-db:/data/db                 # persistence (decision: named volume)
      - clickstack-ch:/var/lib/clickhouse
      - clickstack-logs:/var/log/clickhouse-server

volumes:
  clickstack-db:
  clickstack-ch:
  clickstack-logs:
```

### `.devcontainer/devcontainer.json` (delta)
```jsonc
{
  "name": "Motoko Agent",
  "dockerComposeFile": "docker-compose.yml",   // replaces "build"
  "service": "app",
  "workspaceFolder": "/workspaces/motoko_agent",
  "runServices": ["app"],                       // clickstack stays down until opted-in
  "remoteUser": "motoko",
  "forwardPorts": [8080, 8081],                 // 8080 env-server, 8081 HyperDX UI
  "containerEnv": { /* API keys, unchanged */ },
  "postCreateCommand": "cd src/tui && bun install && bun run build && cd ../.. && echo 'Motoko ready.'"
}
```

> **Bind-mount gotcha**: with a dockerfile-build devcontainer the workspace is auto-mounted; with a compose devcontainer you must declare `volumes: - ..:/workspaces/...:cached` on `app` yourself, or the source won't be in the container.

---

## 5. Env wiring — the handoff to Plan B

Setting OTEL vars on the `app` service is necessary but **not sufficient**. Motoko spawns the AILANG runtime as a child with an **explicit env whitelist** (`src/tui/src/runtime-process.ts` `childEnv`, ~lines 296–346). Vars not in that list are dropped before the child sees them — the same trap already documented there for `MOTOKO_REPO`/cost vars. So the OTEL vars must be:

1. set on the `app` service (here), **and**
2. added to the `childEnv` whitelist + the `--caps ...,Trace` string (Plan B Phase 0/1, `runtime-process.ts:412`).

Both halves are required for an end-to-end trace. This doc owns (1); Plan B owns (2).

---

## 6. Developer workflow

```bash
# default: lightweight devcontainer, no ClickStack
# opt in when you want traces:
docker compose --profile observability up -d clickstack    # from .devcontainer/
# open HyperDX:
#   http://localhost:8081   (first run: create user, see §7 re: ingestion key)
# run motoko normally — spans flow to http://clickstack:4318
make run
# tear down when done (frees the ~2GB):
docker compose --profile observability stop clickstack
```

---

## 7. Open issues to resolve before implementation

| Issue | Plan |
|---|---|
| **Ingestion auth friction** | HyperDX all-in-one normally wants a first-run user + an ingestion API key pasted into `OTEL_EXPORTER_OTLP_HEADERS`. For a zero-touch dev loop, prefer mounting an OTel-collector config (`.devcontainer/otel/collector.yaml`) that accepts **unauthenticated OTLP on the internal compose network**. **Verify** the all-in-one image supports overriding the collector config this way; fallback = document the one-time key grab + add `OTEL_EXPORTER_OTLP_HEADERS` to both env spots (§5). |
| **Image tag pinning** | `:latest` is fine for the design sketch; pin to a specific ClickStack release at merge for reproducibility. |
| **Codespaces footprint** | ~2 GB sidecar may exceed small Codespaces machine types. Opt-in (profile) already mitigates; note in `.devcontainer` README which machine sizes can run it. |
| **`command: sleep infinity`** | confirm this is the right keep-alive for the `app` service vs. relying on devcontainer's default override. |
| **HyperDX UI port** | chose host `8081`; confirm no other forwarded service wants it. |

---

## 8. Risks

- **Compose conversion is a breaking change to the dev setup** — every contributor rebuilds. Land it deliberately, with README notes; verify a clean rebuild on both OrbStack (local) and Codespaces.
- **Silent no-traces** if the §5 whitelist half is skipped — the most likely failure mode. Call it out in the README and Plan B.
- **Volume growth** — persistent ClickHouse can accumulate; document `docker volume rm clickstack-*` reset.

---

## 9. File-change checklist

- `.devcontainer/devcontainer.json` — convert to compose (`dockerComposeFile`, `service`, `workspaceFolder`, `runServices`), remap `forwardPorts`.
- `.devcontainer/docker-compose.yml` — **new**: `app` + `clickstack` (profile, ports, volumes), named volumes.
- `.devcontainer/otel/collector.yaml` — **new, if** unauth-OTLP override is needed (§7).
- `.devcontainer/README.md` — **new/updated**: opt-in workflow, port map, machine-size note, reset.
- `.devcontainer/Dockerfile` — unchanged.
- (Plan B owns) `runtime-process.ts` whitelist + caps; `agent_loop_v2.ail` / `supervisor.ail` span emission.

---

## 10. Relationship to Plan B

```
Design_Devcontainer_ClickStack.md (this doc) ── provides ──▶ local OTLP endpoint + env wiring (1)
Plan_B_Custom_Spans.md            ── provides ──▶ AILANG/Motoko spans + whitelist/caps (2)
                                                  (1)+(2) = end-to-end traces in HyperDX
```

This doc is the **infra prerequisite**; Plan B Phase 0 ("upgrade & transport") is satisfied by standing up this sidecar. Implement this first, confirm AILANG's free runtime spans land in HyperDX, then proceed with Plan B's instrumentation phases.
