# ClickStack Integration — Plan B: Custom Motoko Spans over AILANG-native OTLP

**Status**: Planned
**Author**: drafted 2026-06-06
**Assumes**: Motoko upgraded to latest AILANG (**0.24.2**; lockfile currently pins 0.19.1).
**Supersedes earlier note**: an initial read claimed "AILANG has no OTEL." That was wrong — AILANG ships comprehensive OTLP tracing at the runtime/CLI level, plus a user-facing `std/trace` (`Trace` effect) for custom spans. See memory `ailang-has-native-otel`.
**Related**: `design_docs/implemented/motoko_agent/m-motoko-eval-instrumentation.md` (the JSONL surface we extend), `design_docs/planned/m-motoko-cost-budget.md`, `.agent/plans/Motoko_MLflow_Observability_Plan.md` (prior observability effort — keep aligned, not competing).

---

## 1. Goal & scope

Plan B = **Plan A (transport + AILANG's free runtime spans) PLUS Motoko's own agent-loop semantics as spans/events** in ClickStack (ClickHouse + OTel collector + HyperDX).

Plan B is a strict superset of Plan A. Plan A is just `OTEL_EXPORTER_OTLP_ENDPOINT` pointed at ClickStack's collector, which makes AILANG's built-in spans (compile / eval / effect / **AI-provider spans carrying token+cost attributes**) land in ClickHouse — **this auto-export is documented and confirmed**. Plan B adds Motoko's own spans on top.

> ⚠️ **Transport for Motoko's custom spans is NOT yet confirmed and is the #1 thing to verify (Phase 0 spike, §4.0).** The docs confirm AILANG auto-exports its *built-in* spans, but the `guides/traces` "OTEL Forwarding" section describes forwarding *custom* `std/trace` spans as something an application implements via a trace handler (`otelExporter.addSpan()`), **not** a guaranteed automatic ride on `OTEL_EXPORTER_OTLP_ENDPOINT`. Plan B therefore has **two candidate routes for Motoko's spans**, chosen by the spike:
> - **Route N (native)**: `std/trace` spans auto-forward through the same OTLP exporter → cleanest, used if the spike confirms it.
> - **Route J (JSONL→collector)**: the existing session JSONL is tailed by the ClickStack collector's `filelog` receiver + a transform that maps it to spans → **zero dependency on `std/trace` forwarding, definitely works**, and needs no AILANG code changes at all.
>
> If Route N fails the spike, **Phases 1–3 below (the `std/trace` instrumentation) are replaced wholesale by Route J's collector config.** Do not start them before the spike.

**In scope**: a session becomes one trace tree — `session → step → tool-dispatch` — with agent-loop events (gate decisions, denials, delegation) attached; sub-agent processes nest under the parent trace; a ClickStack deployment + HyperDX dashboards for the eval/autoresearch comparisons.

**Out of scope**: replacing the session JSONL (it stays — it is the TUI-replay + eval-harness surface); building any OTLP encoder by hand (AILANG does it).

---

## 2. What AILANG gives us (from ailang-docs MCP, latest)

**Confirmed:**
- **OTLP auto-export of built-in spans**: `OTEL_EXPORTER_OTLP_ENDPOINT` → any OTLP backend; dual export with GCP. `--emit-trace jsonl,otel`. (This is Plan A and is documented.)
- **Tiers**: `AILANG_TRACE=off|standard|deep`; per-trace span budget `AILANG_TRACE_MAX_SPANS` (default 500, overflow → one `trace.truncated` rollup span). "Silent Failure Mode" — a missing/down collector does not crash the run.
- **Auto-instrumented**: compiler, eval harness, executors, **AI providers (token/cost span attributes)** — per-model token/cost querying rides these runtime spans, not our custom ones.
- **CLI**: `ailang trace status | list | view <trace-id>` (confirmed present in the local v0.19.1 build too).
- **`std/trace` API exists**: `spanStart(name) ! {Trace}`, `spanEnd(name) ! {Trace}` (name-paired, LIFO), `event(name, data) ! {Trace}` (string payload). `std/debug`: `log`, `check` (host-collected).

**⚠️ NOT confirmed — must verify in the Phase 0 spike (§4.0):**
- That `std/trace` spans **auto-forward over OTLP** (vs. requiring an app-level trace handler / `addSpan`). The traces guide frames custom-span forwarding as application-implemented. **This gates Route N vs Route J.**
- **How the `Trace`/`Debug` effect is granted.** The `reference/effects` capability list shows only IO/FS/Clock/Net/Env/Process/Stream — **`Trace`/`Debug` are NOT listed and there is no documented `--caps Trace`.** Likely they are ambient/host-collected effects needing no grant, but this is unverified — do **not** assume the caps string needs `,Trace` until confirmed.
- That AILANG's auto AI-provider span **nests under** a custom `motoko.step` span (requires the runtime to share one span stack between auto + custom spans).
- **Cross-process trace linking** env var (v0.6.3+, `m-otel-cross-process-linking`): the mechanism exists but the exact propagation var (expected `TRACEPARENT`) is unconfirmed.

> ⚠️ `spanStart` takes **only a name** — no attributes argument. Attributes therefore ride `event()` payloads (HyperDX indexes event attributes) or the auto AI-provider spans. Structure via spans, attributes via events.

---

## 3. Span / event model (target shape — Route N builds it with `std/trace`; Route J's collector transform maps the JSONL onto the same shape)

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

### Phase 0 — Upgrade, transport, and the decisive spike

**0.0 — Custom-span forwarding spike (BLOCKS Phases 1–3; do this before writing any span code).**
A ~15-line standalone `.ail` program that calls `std/trace.spanStart` / `event` / `spanEnd`, run with `--emit-trace jsonl,otel` and `OTEL_EXPORTER_OTLP_ENDPOINT` pointed at a local collector (Jaeger or the ClickStack sidecar). Determine:
- Does the custom span arrive at the collector **without** any app-level handler? → if yes, **Route N**; if no, **Route J** (collector tails JSONL; skip Phases 1–3, implement §6 collector transform instead).
- What capability (if any) must be granted for `! {Trace}` — does `--caps ...` need a `Trace`/`trace` token, or does it run cap-free? Record the exact answer; it dictates the `runtime-process.ts` caps edit (or that no edit is needed).
- (If Route N) does the auto AI-provider span nest under the custom span?

1. Bump AILANG runtime + `ailang.lock` from 0.19.1 → 0.24.2; run existing smoke/inline tests to confirm no migration regressions (check `design_docs/planned/ailang-tool-loop-migration.md` and 0.20–0.24 changelog breaks via `changelog_for_version`). Confirm `std/trace` resolves (it is absent or different pre-0.24).
2. Stand up ClickStack locally (see `Design_Devcontainer_ClickStack.md`).
3. Add OTEL env to the child-process **whitelist** in `src/tui/src/runtime-process.ts` (`childEnv`, ~lines 296–346 — explicit allowlist; unlisted vars are dropped, same gotcha as `MOTOKO_REPO`/cost vars). Gate on `MOTOKO_OTEL`:
   - `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` (ClickStack ingestion key: `authorization=<key>`), `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`, `OTEL_SERVICE_NAME=motoko-agent`, `OTEL_RESOURCE_ATTRIBUTES`, `AILANG_TRACE`, `AILANG_TRACE_MAX_SPANS`.
4. **Acceptance**: run a session, see AILANG runtime spans (incl. AI-provider token/cost) in HyperDX; `ailang trace list` shows the trace. No Motoko code changed yet. **This alone delivers Plan A**, independent of the spike outcome.

### Phase 1 — Single-chokepoint trace events (Route N only; low risk, high coverage)
*Skip if the spike selected Route J — there the JSONL already carries everything and the §6 collector transform does the mapping.*
The whole point: `emit_event` (`src/core/agent_loop_v2.ail:126`) is already the single funnel every JSONL event passes through. Make it dual-emit.
1. `import std/trace as Trace`.
2. Change `emit_event(session_id, event_type, extra) -> () ! {IO}` → `! {IO, Trace}`. After the JSONL write, call `Trace.event(event_type, <json of extra>)` reusing the existing `jo/kv/js` encoders.
3. **Exclude high-volume / sensitive types** from trace emission via an allowlist guard inside `emit_event`:
   - DROP `thinking_delta`, `reasoning_delta` (per-token deltas — would blow `AILANG_TRACE_MAX_SPANS` and leak raw model content).
   - For payloads that may carry secrets (prompt/content text), truncate or redact before `Trace.event` (keep full text in JSONL only).
4. Thread the `Trace` effect up the call chain: `dispatch_calls`, `conversation_loop_v2`, and the top-level entry in `src/core/supervisor.ail` (top-level effect row, currently `! {IO, FS, Env, Process, Net, AI, SharedMem, Clock, Stream}` → add `Trace`).
5. **Grant the `Trace` capability IF the spike (§4.0) showed one is needed** — the caps list in `runtime-process.ts:412` may or may not require a `Trace`/`trace` token (it is *not* in the documented capability list, so it is likely ambient and needs no edit). Apply only the form the spike confirmed; do not guess.
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
| **🔴 Custom spans may not auto-forward to OTLP** (the whole Route N premise) | Phase 0 spike (§4.0) decides before any code is written; **Route J (JSONL→collector) is a complete fallback** that needs no `std/trace` and no AILANG changes. Plan A (built-in spans) is unaffected either way. |
| **`Trace` capability grant unknown** | Spike records exact form; likely ambient (no `--caps` token). Don't pre-edit the caps string. |
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
- **Route J transform** (the fallback selected if the §4.0 spike fails, and also the path for historical logs): a collector `filelog` receiver tailing `${WORKDIR}/.motoko/logfile/session_*.jsonl` + a transform processor mapping `session_id`→trace_id, `type`→span name, token/cost→attributes. This is a real, complete delivery path — not a footnote.
- The devcontainer sidecar in `Design_Devcontainer_ClickStack.md` is the dev-loop instance of this deployment.

---

## 7. File-change checklist

*Always (both routes):*
- `ailang.lock` + runtime — upgrade to 0.24.2.
- `src/tui/src/runtime-process.ts` — OTEL env in `childEnv` whitelist (~296–346), gated on `MOTOKO_OTEL`.
- `deploy/clickstack/` + `Design_Devcontainer_ClickStack.md` sidecar.

*Route N only (if §4.0 spike confirms native forwarding):*
- `src/tui/src/runtime-process.ts` — caps token at line ~412 **only if the spike says one is required**; traceparent into `resolveDelegatedSpawn` (~475).
- `src/core/agent_loop_v2.ail` — `import std/trace`; `emit_event` dual-emit + allowlist (line 126); session/step/tool spans via `with_span`; thread `Trace` through `dispatch_calls` / `conversation_loop_v2`.
- `src/core/supervisor.ail` — thread `Trace` through top-level effect row + entry chain (if a grant is required).
- Tests — inline tests for `emit_event` dual-emission + span balance (`std/trace_test`); local-collector smoke (`ailang trace list`).

*Route J only (if spike fails):*
- `deploy/clickstack/collector.yaml` — `filelog` receiver + transform; **no AILANG/TS source changes beyond the env whitelist.**

> This plan lives in `.agent/plans/` (the working-plan space). A formal `design_docs/planned/m-motoko-*` entry is **not** created — there is no existing OTEL design doc, and that canon is reserved for docs with cross-repo significance (e.g. `m-motoko-eval-instrumentation.md`, which AILANG core references). Promote this only if AILANG-side work ends up needing to cross-reference it.

---

## 8. Sequencing / definition of done

**Phase 0** (upgrade + transport + the §4.0 spike) → spike picks the route:
- **Route N**: Phase 1 (events) → Phase 2 (waterfall) → Phase 3 (sub-agent linking) → Phase 4 (dashboards).
- **Route J**: collector `filelog`+transform (§6) → Phase 4 (dashboards). Phases 1–3 are skipped.

Phase 0 alone delivers Plan A (AILANG built-in spans, incl. token/cost) regardless of route. Each subsequent phase is independently shippable with its own acceptance check above.

**Done** = a delegating session renders as a single nested trace in HyperDX with per-step token/cost, and the autoresearch token/cost-per-regime dashboard is driven by ClickHouse instead of JSONL grep.
