# ClickStack Integration — Plan B: Custom Motoko Spans over AILANG-native OTLP

**Status**: Planned
**Author**: drafted 2026-06-06
**Assumes**: Motoko upgraded to latest AILANG (**0.24.2**; lockfile currently pins 0.19.1).
**Supersedes earlier note**: an initial read claimed "AILANG has no OTEL." That was wrong — AILANG ships comprehensive OTLP tracing at the runtime/CLI level, plus a user-facing `std/trace` (`Trace` effect) for custom spans. See memory `ailang-has-native-otel`.
**Related**: `design_docs/implemented/motoko_agent/m-motoko-eval-instrumentation.md` (the JSONL surface we extend), `design_docs/planned/m-motoko-cost-budget.md`, `.agent/plans/Motoko_MLflow_Observability_Plan.md` (prior observability effort — keep aligned, not competing).

---

## 1. Goal & scope

Plan B = **Plan A (transport + AILANG's free runtime spans) PLUS Motoko's own agent-loop semantics as first-class spans/events**, all flowing through the *same* OTLP pipe into ClickStack (ClickHouse + OTel collector + HyperDX).

Plan B is a strict superset of Plan A. Plan A is just `OTEL_EXPORTER_OTLP_ENDPOINT` pointed at ClickStack's collector, which makes AILANG's built-in spans (compile / eval / effect / **AI-provider spans carrying token+cost attributes**) land in ClickHouse. Plan B reuses that exact wiring and nests Motoko's spans inside the same traces.

**In scope**: a session becomes one trace tree — `session → step → tool-dispatch` — with agent-loop events (gate decisions, denials, delegation) attached; sub-agent processes nest under the parent trace; a ClickStack deployment + HyperDX dashboards for the eval/autoresearch comparisons.

**Out of scope**: replacing the session JSONL (it stays — it is the TUI-replay + eval-harness surface); building any OTLP encoder by hand (AILANG does it).

---

## 2. What AILANG gives us (verified via ailang-docs MCP, latest)

- **`std/trace`** — `spanStart(name) ! {Trace}`, `spanEnd(name) ! {Trace}` (name-paired, LIFO), `event(name, data) ! {Trace}` (data is a string payload). This is the custom-span API Plan B is built on.
- **`std/debug`** — `log(msg) ! {Debug}`, `check(cond, msg) ! {Debug}` (host-collected). Optional, for assertions.
- **OTLP export**: `OTEL_EXPORTER_OTLP_ENDPOINT` → any OTLP backend; dual export with GCP. `--emit-trace jsonl,otel`.
- **Tiers**: `AILANG_TRACE=off|standard|deep`; per-trace span budget `AILANG_TRACE_MAX_SPANS` (default 500, overflow → one `trace.truncated` rollup span).
- **Auto-instrumented**: compiler, eval harness, executors, **AI providers (token/cost span attributes)** — so per-model token/cost querying rides the runtime spans, not our custom ones.
- **Cross-process trace linking** (v0.6.3+): parent trace context propagates to spawned CLI subprocesses (used today for Claude Code / Gemini CLI) — the mechanism we reuse for Motoko sub-agents.
- **CLI**: `ailang trace status | list | view <trace-id>` for local verification.

> ⚠️ `spanStart` takes **only a name** — no attributes argument. Span attributes are therefore attached via `event()` payloads inside the span (HyperDX indexes event attributes), or come from the auto AI-provider spans. Bake this into the design: structure via spans, attributes via events.

---

## 3. Span / event model

```
trace = one Motoko session  (trace_id correlated to MOTOKO_SESSION_ID / derive_session_id)
└─ span  motoko.session                      [spanStart at session_start → spanEnd at run_summary]
   ├─ event session_start {model, commit, profile, caps}
   ├─ span  motoko.step.{idx}                 [bracket one loop iteration]
   │  ├─ (AILANG auto span: ai.provider.call  ← token/cost attributes, FREE)
   │  ├─ span motoko.tool.{name}.{idx}.{call} [v2_tool_dispatch_start → v2_tool_dispatch_complete]
   │  │  └─ event v2_tool_dispatch_complete {ok, bytes, duration_ms}
   │  ├─ event dp7_gate {decision}
   │  └─ event native_tool_denied {reason}
   └─ event run_summary {totals: tokens, cost_usd, steps}
```

**Naming discipline**: span names must be unique on the LIFO stack at any instant. Steps are sequential (not nested in each other) so a bare `motoko.step` would pair correctly, but to be safe and to disambiguate in `ailang trace view`, suffix with `step_idx` / `stream_id` / call index.

---

## 4. Implementation phases

### Phase 0 — Upgrade & transport (this is Plan A; do first, prove it)
1. Bump AILANG runtime + `ailang.lock` from 0.19.1 → 0.24.2; run existing smoke/inline tests to confirm no migration regressions (check `design_docs/planned/ailang-tool-loop-migration.md` and any 0.20–0.24 changelog breaks via `changelog_for_version`).
2. Stand up ClickStack locally (§6).
3. Add OTEL env to the child-process **whitelist** in `src/tui/src/runtime-process.ts` (`childEnv`, ~lines 296–346 — it is an explicit allowlist; unlisted vars are dropped, same gotcha documented there for `MOTOKO_REPO`/cost vars). Gate on `MOTOKO_OTEL`:
   - `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` (ClickStack ingestion key: `authorization=<key>`), `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`, `OTEL_SERVICE_NAME=motoko-agent`, `OTEL_RESOURCE_ATTRIBUTES`, `AILANG_TRACE`, `AILANG_TRACE_MAX_SPANS`.
4. **Acceptance**: run a session, see AILANG runtime spans (incl. AI-provider token/cost) in HyperDX; `ailang trace list` shows the trace. No Motoko code changed yet.

### Phase 1 — Single-chokepoint trace events (low risk, high coverage)
The whole point: `emit_event` (`src/core/agent_loop_v2.ail:126`) is already the single funnel every JSONL event passes through. Make it dual-emit.
1. `import std/trace as Trace`.
2. Change `emit_event(session_id, event_type, extra) -> () ! {IO}` → `! {IO, Trace}`. After the JSONL write, call `Trace.event(event_type, <json of extra>)` reusing the existing `jo/kv/js` encoders.
3. **Exclude high-volume / sensitive types** from trace emission via an allowlist guard inside `emit_event`:
   - DROP `thinking_delta`, `reasoning_delta` (per-token deltas — would blow `AILANG_TRACE_MAX_SPANS` and leak raw model content).
   - For payloads that may carry secrets (prompt/content text), truncate or redact before `Trace.event` (keep full text in JSONL only).
4. Thread the `Trace` effect up the call chain: `dispatch_calls`, `conversation_loop_v2`, and the top-level entry in `src/core/supervisor.ail` (top-level effect row, currently `! {IO, FS, Env, Process, Net, AI, SharedMem, Clock, Stream}` → add `Trace`).
5. Add `Trace` to the runtime caps string in `runtime-process.ts:412` (`"Net,AI,...,Stream"` → append `,Trace`), gated so it's only granted when `MOTOKO_OTEL=1` (granting the cap with no endpoint is harmless — spans go to observatory.db — but keep it conditional for cleanliness).
6. **Acceptance**: every non-excluded JSONL event now also appears as a span event in HyperDX, searchable by `type`, `session_id`.

### Phase 2 — Span tree (the waterfall)
Add explicit `spanStart`/`spanEnd` for the three bracketed regions. **Balancing is the main risk** (see §5): an early return / `Err` between start and end leaks an unclosed span.
1. **Session root**: `spanStart("motoko.session")` at the session_start site; `spanEnd("motoko.session")` at the run_summary / terminal site. Ensure end fires on *every* termination path (`done`, cost_exhausted, error).
2. **Per-step**: bracket each loop iteration in `conversation_loop_v2` with `motoko.step.{idx}`.
3. **Per-tool**: bracket `dispatch_calls` tool handling with `motoko.tool.{name}.{step}.{call}` between the existing `v2_tool_dispatch_start` / `v2_tool_dispatch_complete` emissions.
4. Introduce a `with_span(name, thunk)` helper that guarantees `spanEnd` on all Result branches (start → run → end-before-return), and route span sites through it to avoid hand-balancing.
5. **Acceptance**: `ailang trace view <id>` and HyperDX render a nested waterfall; AILANG's auto AI-provider span sits *inside* the matching `motoko.step`.

### Phase 3 — Cross-process sub-agent linking
Delegated sub-agents spawn via `resolveDelegatedSpawn` (`runtime-process.ts` ~line 475). To nest their traces under the parent:
1. Propagate the W3C trace context to the spawned child env (AILANG cross-process linking, v0.6.3+ — **verify exact var**, expected `TRACEPARENT` / OTEL propagation envs).
2. Confirm child spans appear as children of the parent `motoko.session` trace in HyperDX.
3. **Acceptance**: a session that delegates shows one trace spanning both processes.

### Phase 4 — ClickStack dashboards & queries
Build HyperDX saved searches / ClickHouse views for the comparisons this repo actually does:
- Token/cost per `model × benchmark × regime` (autoresearch / eval leaderboard — replaces ad-hoc JSONL parsing; see scout-value & benchmark prompt work).
- Cost dashboard tied to `m-motoko-cost-budget.md` thresholds.
- Tool-failure / gate-decision rates per model.
- Single-session trace-waterfall drilldown.

---

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Unbalanced spans** (early return/`Err` skips `spanEnd`) → leaked/never-closed spans | Phase 1 (events-only) carries zero balancing risk and ships value first. In Phase 2 route all spans through `with_span` and assert balance in tests. |
| **Span-budget blowout / content leak** from per-token deltas | `emit_event` allowlist DROPS `thinking_delta`/`reasoning_delta`; set `AILANG_TRACE_MAX_SPANS` deliberately. |
| **Secrets to ClickStack** (prompt/thinking text) | Redact/truncate payloads before `Trace.event`; full text stays in JSONL only; default `MOTOKO_OTEL` off (opt-in). |
| **`spanStart` has no attributes** | Attributes via `event()` payloads + rely on auto AI-provider spans for token/cost. |
| **Effect-signature churn** (`Trace` must thread through the call chain) | Concentrate emission in `emit_event` + ~3 span sites; minimizes touched signatures. |
| **Env-whitelist drops OTEL vars** | Explicitly add all `OTEL_*` + `AILANG_*` to `childEnv` (documented gotcha). |
| **0.19→0.24 migration breakage** | Run smoke/inline suite right after the bump (Phase 0) before any new code. |
| **Cross-process var name uncertain** | Verify against `guides/telemetry.md` "Cross-Process Trace Linking" before Phase 3. |
| Performance overhead | Default tier `standard`; OTLP export is async; `off` in CI/perf benchmarks. |

---

## 6. ClickStack deployment (ops)

Add `deploy/clickstack/` with a compose file + README:
- ClickStack all-in-one (HyperDX + ClickHouse + OTel collector); collector listens OTLP **4317 (gRPC) / 4318 (HTTP)**.
- Point Motoko at it: `OTEL_EXPORTER_OTLP_ENDPOINT=http://<host>:4318`, `OTEL_EXPORTER_OTLP_HEADERS=authorization=<hyperdx-ingestion-key>`.
- Fallback for historical data: collector `filelog` receiver tailing `${WORKDIR}/.motoko/logfile/session_*.jsonl` (Plan A's old path A) — keep documented but not primary.

---

## 7. File-change checklist

- `ailang.lock` + runtime — upgrade to 0.24.2.
- `src/tui/src/runtime-process.ts` — caps `,Trace` (line ~412); OTEL env in `childEnv` whitelist (~296–346); traceparent into `resolveDelegatedSpawn` (~475), all gated on `MOTOKO_OTEL`.
- `src/core/agent_loop_v2.ail` — `import std/trace`; `emit_event` dual-emit + allowlist (line 126); session/step/tool spans via `with_span`; thread `Trace` through `dispatch_calls` / `conversation_loop_v2`.
- `src/core/supervisor.ail` — add `Trace` to top-level effect row + entry chain.
- Tests — inline tests for `emit_event` dual-emission and span balance (use `std/trace_test`); a local-collector smoke asserting spans arrive (`ailang trace list`).
- `deploy/clickstack/` — compose + README.

> This plan lives in `.agent/plans/` (the working-plan space). A formal `design_docs/planned/m-motoko-*` entry is **not** created — there is no existing OTEL design doc, and that canon is reserved for docs with cross-repo significance (e.g. `m-motoko-eval-instrumentation.md`, which AILANG core references). Promote this only if AILANG-side work ends up needing to cross-reference it.

---

## 8. Sequencing / definition of done

Phase 0 (Plan A: spans visible in HyperDX) → Phase 1 (all events as trace events) → Phase 2 (waterfall) → Phase 3 (sub-agent linking) → Phase 4 (dashboards). Each phase is independently shippable and has its own acceptance check above. **Done** = a delegating session renders as a single nested trace in HyperDX with per-step token/cost, and the autoresearch token/cost-per-regime dashboard is driven by ClickHouse instead of JSONL grep.
```
