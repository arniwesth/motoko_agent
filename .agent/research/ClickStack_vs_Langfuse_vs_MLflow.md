# ClickStack vs Langfuse vs MLflow — observability backend for Motoko/AILANG traces

**Status**: Research / decision note
**Author**: drafted 2026-06-07 (MLflow added 2026-06-07)
**Context**: companion to `.agent/plans/ClickStack_Integration/` (Design_Devcontainer_ClickStack.md + Plan_B_Custom_Spans.md), which currently assume **ClickStack**; and to the older `.agent/plans/Motoko_MLflow_Observability_Plan.md` (a pre-OTLP MLflow effort — see note below). This records *why* ClickStack was the default and what would shift the call toward MLflow or Langfuse.
**Sources**: [langfuse/langfuse](https://github.com/langfuse/langfuse) · [Langfuse OTEL](https://langfuse.com/integrations/native/opentelemetry) · [mlflow/mlflow](https://github.com/mlflow/mlflow) · [MLflow OTLP ingest](https://mlflow.org/docs/latest/genai/tracing/opentelemetry/ingest/) · [MLflow self-hosting](https://mlflow.org/docs/latest/self-hosting/) · AILANG `guides/telemetry.md`, `guides/traces.md` (ailang-docs MCP, latest = 0.24.2) · memory `ailang-has-native-otel`.

---

## TL;DR

> Three OSS backends, all able to ingest AILANG's native OTLP. They differ most in **deployment weight** and in **what job they're best at**.
>
> - **MLflow (minimal) is the *lightest* of the three** — a single FastAPI process with a SQLite file and a local artifact dir; **no ClickHouse, no extra services**. It is also an AI-engineering platform (evals, prompts, datasets) whose **run/experiment model fits this repo's autoresearch/benchmark-leaderboard work natively**.
> - **ClickStack (all-in-one) is one container** (ClickHouse + OTel collector + HyperDX). Best pure **ops/trace-waterfall** tool; you build dashboards in ClickHouse SQL.
> - **Langfuse is a heavy, 5+ service deployment** (web + worker + ClickHouse + Postgres + Redis + S3/MinIO). Strongest dedicated LLM prompt/eval product UX, but its footprint fights the "lightweight dev sidecar" goal.

The three separate by job: **ClickStack = debug agent traces**; **MLflow = compare runs across model×regime with evals attached, at the lightest footprint**; **Langfuse = dedicated prompt/eval product, if its UX is worth 5 services.**
>
> **Spike result (2026-06-07):** AILANG emits **custom `ai.*` span attributes, not `gen_ai.*` semconv** → only **ClickStack** turns token/cost into dashboards with no translation; MLflow & Langfuse both need an `ai.*→gen_ai.*` collector transform to light up their LLM cost/token UI. Net tilt: **ClickStack baseline**, MLflow optional complement, Langfuse weakest on cost/benefit.

---

## ⚠️ Deployment weight — the decisive practical difference

The devcontainer sidecar's whole point (Design doc §1) is a *lightweight, opt-in* local OTLP target every contributor can spin up. Weight is therefore a first-order criterion, not a footnote.

| | **MLflow (minimal)** | **ClickStack (all-in-one)** | **Langfuse (self-host)** |
|---|---|---|---|
| Processes / containers | **1 process** (FastAPI) | **1 container** | **5+ services** |
| Heavy backing stores | **none** — SQLite file + local `./mlruns` artifacts | ClickHouse (bundled in image) | ClickHouse **+** Postgres **+** Redis/Valkey **+** S3/MinIO |
| RAM (rough) | **~hundreds of MB** | ~1.5–2 GB | heaviest (multi-service + 2 DBs + cache + blob) |
| "Deploy it" | `pip install mlflow && mlflow server` | one `profiles:[observability]` compose service | a mini stack: many services, volumes, startup ordering |
| Persistence surface | one SQLite file + a dir | a few ClickHouse volumes | ClickHouse **and** Postgres **and** blob store |
| Codespaces fit | excellent | tolerable (already opt-in in design) | likely too heavy for small machine types |
| Scale caveat | SQLite contends under concurrent writers → Postgres for heavy/parallel use (then footprint rises, still < Langfuse) | ClickHouse handles high span volume well | built for scale, but you pay the footprint always |

**Bottom line on weight:** MLflow-minimal < ClickStack < Langfuse. Langfuse is a production-grade platform deployment, disproportionate as a per-devcontainer sidecar. MLflow-minimal is paradoxically the lightest *because it has no ClickHouse at all* — at the cost of SQLite's weakness under the parallel eval subprocesses this repo runs (`-parallel 2–4` in local-ollama eval).

---

## What AILANG actually emits (the asset everything is measured against)

From `guides/telemetry.md` (latest):
- Comprehensive **OpenTelemetry** instrumentation; exports to "Google Cloud Trace, Grafana, Honeycomb, Jaeger, and more" via standard `OTEL_EXPORTER_OTLP_ENDPOINT` (OTLP **4317 gRPC / 4318 HTTP**).
- Auto-instrumented spans: compiler, eval harness, executors, coordinator, **AI providers** (token + USD cost; `resolvedroute` payload records resolved model / fallback chain / prompt+completion+cached tokens / cost).
- Tiers `off|standard|deep`; per-trace span budget (`AILANG_TRACE_MAX_SPANS`, default 500 → `trace.truncated` rollup); **Silent Failure Mode** (down collector never crashes the run).
- Native **cross-process trace linking** (v0.6.3+) over W3C trace context.
- CLI: `ailang trace status|list|view`.

➡️ This is *generic, standard OTLP* — it drops into any OTLP backend with **zero application code**. All three candidates can receive it; they differ in transport ergonomics and what they do with it.

---

## OTLP transport ergonomics (how cleanly each receives AILANG spans)

| | Endpoint | Protocol | Auth / required headers |
|---|---|---|---|
| **ClickStack** | standard `:4317` / `:4318` | gRPC **and** HTTP | none on internal compose net (unauth OTLP) |
| **MLflow** (≥3.6.0) | `/v1/traces` | **HTTP only** (no gRPC) | header `x-mlflow-experiment-id=<id>` (→ must be in `childEnv` whitelist as `OTEL_EXPORTER_OTLP_TRACES_HEADERS`) |
| **Langfuse** (≥3.22.0) | `/api/public/otel` | **HTTP only** (no gRPC) | Basic-Auth `Authorization=Basic base64(pk:sk)` |

ClickStack is the only one accepting vanilla OTLP on the standard ports with no header ceremony. MLflow and Langfuse both need a specific header injected into the runtime child env whitelist (`runtime-process.ts`, the same gotcha already documented for `MOTOKO_REPO`/cost vars).

---

## Fit analysis

### MLflow
- Now "an open-source AI engineering platform for agents, LLMs, and ML models": **Tracing** (built on OpenTelemetry) **+** classic experiment tracking **+ evals (50+ metrics / LLM judges) + prompt versioning & optimization + datasets + AI Gateway** (cost/routing).
- **Native OTLP ingestion** at `/v1/traces` (3.6.0) → AILANG OTLP flows straight in, **no custom telemetry writer** (this obsoletes the old MLflow plan's TS event→run mapping; see note).
- **Lightest deployment** (single FastAPI + SQLite + local files).
- **License: Apache-2.0 — fully OSS, no `ee` gating** (cleaner than Langfuse on this axis).
- 🟢 **Best structural fit for this repo's gravity:** the run/experiment model maps directly onto autoresearch — each benchmark run = one MLflow run with `params={model, regime}`, `metrics={tokens, cost, pass_rate}`, traces attached. Replaces ad-hoc JSONL grep for the leaderboard better than ClickHouse SQL or Langfuse.
- 🔴 **SQLite under concurrent eval subprocesses** (`-parallel 2–4`) → contention; heavy/parallel use wants Postgres.
- 🔴 **Weaker as a pure-ops trace tool** — traces+runs, not the traces+logs+metrics + full-text + SQL story HyperDX gives. For raw agent-loop debugging waterfalls, HyperDX is stronger.

### ClickStack / HyperDX
- Ingests AILANG spans **verbatim** on standard 4317/4318 — no schema assumptions, no header. Plan A works day one.
- Cross-process sub-agent nesting (Plan B Phase 3) = native W3C `tracecontext`, essentially free.
- Trace waterfall + full-text + **ClickHouse SQL** → we *build* the token/cost-per-`model×benchmark×regime` dashboards.
- **Single-container** sidecar. Strong dev-loop fit; strongest pure-observability tool.
- 🔴 No evals, no prompt management, no datasets — pure observability.

### Langfuse
- Purpose-built LLM-engineering platform: traces/observations/**generations** + LLM-as-judge evals, datasets + experiments, prompt versioning, prebuilt cost/token dashboards. MIT core (**some features `ee`/cloud-gated** — verify which we need are OSS).
- OTLP ingest with the most ceremony (path + Basic-Auth + gen_ai semconv dependence, below).
- 🔴 **Heaviest deployment** (5+ services) — the main strike against it as a dev sidecar.

---

## 🔑 RESOLVED: AI-span semconv — AILANG uses custom `ai.*`, NOT `gen_ai.*`

**Spike done (2026-06-07, source: [ailang.sunholo.com/docs/guides/telemetry](https://ailang.sunholo.com/docs/guides/telemetry) "Trace Attributes Reference").** AILANG's AI-provider spans use **custom attribute names**, not OpenTelemetry GenAI semantic conventions:

```
ai.provider        ai.model           ai.tokens_in
ai.tokens_out      ai.tokens_total    ai.cost_usd
ai.prompt_preview  ai.response_preview ai.finish_reason
```

(Resource attrs `service.name` / `service.version` / `process.runtime.*` *are* standard OTel; the AI-specific keys — the ones that matter — are custom `ai.*`. There is **no** `gen_ai.usage.*` / `gen_ai.request.model` / `gen_ai.system`.)

**Consequence — this gated both MLflow and Langfuse, and the answer is unfavorable to both:**

| Backend | Effect of `ai.*` (not `gen_ai.*`) |
|---|---|
| **ClickStack** | ✅ **Unaffected.** `ai.cost_usd`, `ai.tokens_total`, `ai.model` are just columns — group/filter in ClickHouse SQL / HyperDX. Plan B Phase 4's "token/cost per model×benchmark×regime" dashboards work **directly** off these keys, no translation. |
| **Langfuse** | ❌ generations view + auto cost rollups key off `gen_ai.*`; AILANG spans land as **generic spans** → headline product value does **not** light up without a collector transform `ai.* → gen_ai.*`. |
| **MLflow** | ❌ trace UI token/cost panels read MLflow/`gen_ai` conventions → same: generic spans unless the same mapping transform is added. |

**Upshot:** ClickStack is the **only** one of the three that delivers its value with **zero attribute translation**. To unlock the LLM-specific UI in MLflow or Langfuse you must insert an OTel-collector **transform processor** remapping `ai.*` → each tool's expected convention — an extra moving part; without it they are generic-span viewers (and weaker at that than HyperDX). This also tempers MLflow's "lightweight strong middle" position: its run/eval model is still attractive, but its *trace cost/token UI* now carries the same mapping tax as Langfuse.

---

## Note on the existing `Motoko_MLflow_Observability_Plan.md`

That earlier plan modeled telemetry as **MLflow runs/metrics/artifacts written by a custom TypeScript telemetry sink** (one run per session, file-backed `mlruns/`, feature-flagged). It predates two facts now central:
1. **AILANG is already native OTLP** — so a hand-written event→MLflow sink is no longer required.
2. **MLflow added OTLP ingestion** (`/v1/traces`, 3.6.0) — so AILANG can feed MLflow Tracing directly.

If MLflow is chosen, that plan should be **revised to the OTLP-ingest path** (point the endpoint; drop the custom sink) and *aligned* with the run/experiment mapping for the leaderboard — not implemented as originally written.

---

## Recommendation

The choice now hinges on **which job is primary**, with weight as a tie-breaker:

1. **If the priority is debugging agent traces / ops** → **ClickStack** (as the plans specify): native vanilla OTLP, one container, cross-process for free, strongest waterfall + SQL. Ships Plan A immediately, Plan B with minimal code.
2. **If the priority is comparing runs across model×regime with evals attached** → **MLflow**: lightest footprint, Apache-2.0, native OTLP ingest, and the run model fits autoresearch better than the other two. Revise the old MLflow plan to the OTLP path. Watch SQLite→Postgres if eval parallelism grows.
3. **Langfuse** → only if the dedicated prompt/eval **product UX** is worth a 5-service deployment; if so, run it as a **shared/hosted instance, never a per-devcontainer sidecar**.
4. **No lock-in either way** — AILANG emits standard OTLP, so a collector can **fan out** to more than one backend, or you re-point the endpoint to switch. Realistic combo if both jobs matter: **ClickStack (or nothing) as the light dev sidecar + MLflow as the shared run/leaderboard store** — both lighter together than Langfuse alone.

**Current lean (post-spike):** the semconv result tilts toward **ClickStack** — it is the only backend that turns AILANG's `ai.*` token/cost into dashboards with **no translation layer**, which is exactly Plan B Phase 4. MLflow's run/eval model and light footprint remain genuinely attractive for the autoresearch leaderboard, but adopting MLflow *or* Langfuse for trace cost/token now both require an `ai.* → gen_ai.*` collector transform. So: **ClickStack for the traces/dashboards baseline; consider MLflow as a complementary run/eval store** (fed either via the transform, or via a thin run-level adapter using `ai.*` directly). Langfuse is hardest to justify — heaviest footprint *and* needs the transform.

---

## Open items
- [x] ~~Semconv spike~~ **RESOLVED**: AILANG uses custom `ai.*`, not `gen_ai.*` → MLflow & Langfuse both need a remap transform to light up cost/token UI; ClickStack does not.
- [ ] If MLflow/Langfuse pursued: write the OTel-collector `transform` processor mapping `ai.tokens_in/out/total`, `ai.cost_usd`, `ai.model`, `ai.provider` → `gen_ai.usage.input_tokens` / `output_tokens` / `gen_ai.request.model` / `gen_ai.provider.name` etc.
- [ ] **MLflow scale check** — does SQLite hold under `-parallel 2–4` eval span ingestion, or is Postgres needed?
- [ ] Verify cross-process W3C tracecontext nesting works in MLflow and Langfuse (it's free in ClickStack).
- [ ] If Langfuse considered: enumerate which eval/dashboard features are OSS vs `ee`.
- [ ] Reconcile / revise `Motoko_MLflow_Observability_Plan.md` to the OTLP-ingest path if MLflow is chosen.
