# Fix Spurious ClickStack 401 at Startup

Base branch: `origin/main`

## Summary

Launching Motoko with the `observability` profile printed a `traces export:
failed to send ... 401 Unauthorized (missing or empty authorization header)`
error on every startup — even when a valid `CLICKSTACK_INGESTION_KEY` was set in
`.env`. The error was misleading: the key was present and valid, but it never
reached the AILANG trace exporter.

Root cause: **bun's `execSync` does not propagate runtime-mutated `process.env`
to child processes** — only the snapshot captured at process start. The flow
was:

- `OTEL_EXPORTER_OTLP_ENDPOINT` is injected into the container env by
  docker-compose *at start*, so it is in bun's snapshot and the child `ailang`
  version probe sees it and attempts trace export.
- `synthesizeClickStackOtelHeaders()` derives
  `OTEL_EXPORTER_OTLP_HEADERS=authorization=$CLICKSTACK_INGESTION_KEY` *at
  runtime*, so it is **not** in the snapshot and never reaches the probe.
- Result: the probe exports traces with no auth header → ClickStack returns 401
  on every launch.

(The long-running agent runtime in `runtime-process.ts` was unaffected because
it builds its child env explicitly; the visible 401 came from the startup
version probe.)

## Changes

- Pass `env: process.env` to the `ailang` version-probe `execSync` in
  `src/tui/src/index.ts` so bun forwards the runtime-derived OTLP auth header to
  the child. With a valid key present, this eliminates the 401 entirely.
- Add a "skip export + show hint" path for when ClickStack tracing is enabled
  but no ingestion key resolves: Motoko now disables trace export for the run
  and prints a single actionable hint instead of letting the runtime spam raw
  401s. Implemented via three helpers:
  - `clickStackAuthHeaderPresent()` — detects whether an OTLP `authorization`
    header is configured (directly or synthesized from
    `CLICKSTACK_INGESTION_KEY`).
  - `disableOtelExport()` — deletes `OTEL_EXPORTER_OTLP_ENDPOINT`,
    `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, and `MOTOKO_OTEL` from `process.env`.
    Removing the endpoint is the *only* reliable way to stop AILANG from
    exporting — `AILANG_TRACE=off` / `AILANG_NO_TRACE=1` do **not** prevent it,
    since the exporter is initialized on endpoint presence alone.
  - `warnClickStackTracingDisabled()` — emits the one-line hint pointing at
    `CLICKSTACK_INGESTION_KEY` / `OTEL_EXPORTER_OTLP_HEADERS` /
    `clickstack.enabled=false`.
- Document the `standard` vs `deep` trace tiers (and `off`), tier precedence,
  aliases, and the `AILANG_TRACE_MAX_SPANS` interaction in
  `deploy/clickstack/README.md`.

## User Impact

- With a valid `CLICKSTACK_INGESTION_KEY` set, the startup 401 is gone and
  traces authenticate and export normally.
- With no key set, the run no longer spams cryptic 401 / `Trace:` lines. Instead
  it prints one clear hint explaining tracing is disabled for this run and how
  to enable it, e.g.:

  ```
  Motoko: ClickStack tracing is enabled but no ingestion key is set — tracing is disabled for this run (http://clickstack:4318 would reject it with 401).
    Fix: add CLICKSTACK_INGESTION_KEY=<key> to .env (find it in the ClickStack UI → Team Settings → API Keys),
         or set OTEL_EXPORTER_OTLP_HEADERS='authorization=<key>' directly, or set clickstack.enabled=false to silence this.
  ```

- `deploy/clickstack/README.md` now explains what `AILANG_TRACE=deep` buys
  (per-call `eval.function.*` and per-op `eval.effect.*` spans, ~2× overhead)
  versus the default `standard` structural spans.

## Verification

- `bun run build` (tsc) from `src/tui` — passes.
- Key present (`.env` has `CLICKSTACK_INGESTION_KEY`): startup emits no
  `401` / `traces export` / `Trace:` lines.
- Key absent (temporarily removed from `.env`): startup prints the
  `tracing is disabled for this run` hint and no 401 / `Trace:` lines.
- Confirmed via direct `ailang run` that only removing
  `OTEL_EXPORTER_OTLP_ENDPOINT` silences export — `AILANG_TRACE=off` and
  `AILANG_NO_TRACE=1` still 401 with the endpoint set.

Note: pre-existing lint diagnostics in the delegated-exec code
(`index.ts` "unreachable code" / unused `status`) are unrelated to this change
and left untouched.
