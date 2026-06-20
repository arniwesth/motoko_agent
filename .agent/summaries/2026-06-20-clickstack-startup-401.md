# 2026-06-20 ClickStack Startup 401 Investigation And Fix

## Context

Branch: `arniwesth/mot-11-fix-clickstack-wrongly-reported-issue-at-startup`
(base `origin/main`).

The user reported that `make run` with the `observability` profile printed on
every startup:

```
Trace: standard (set AILANG_TRACE=deep or --trace-tier deep for per-call spans)
2026/06/20 ... traces export: failed to send to http://clickstack:4318/v1/traces: 401 Unauthorized (missing or empty authorization header: Authorization)
```

The initial ask was simply "Motoko should write out a short hint on how to solve
it." The session turned into a deeper diagnosis: the error was misleading and a
real propagation bug was hiding behind it.

## Investigation

The diagnosis went through several wrong turns before landing on the root cause:

1. **First hypothesis (proactive hint).** Added a pre-flight warning when
   ClickStack was enabled but no `OTEL_EXPORTER_OTLP_HEADERS` was set. It never
   fired — established that the message comes from the AILANG runtime's
   inherited stderr, which Motoko cannot intercept after the fact.
2. **Traced the launch flow.** `make run` → `scripts/run-agent.sh` →
   `bun src/tui/src/index.ts` (runs the TS source directly, not `dist`). The
   startup 401 comes from the `ailang run --entry print_version` version probe
   (`index.ts` ~line 740), not from the long-running agent runtime.
3. **Found existing key infrastructure.** `.env` already contained a valid
   `CLICKSTACK_INGESTION_KEY`, and `synthesizeClickStackOtelHeaders()` turns it
   into `OTEL_EXPORTER_OTLP_HEADERS=authorization=<key>` at runtime. So the hint
   gating (header-present check) was being satisfied — yet ClickStack still
   401'd. The key was the wrong thing to blame.
4. **Verified the key is valid.** Running `ailang run` directly with the header
   in the environment → no 401. Without it → 401. So the key worked; it just was
   not reaching the exporter.
5. **Root cause — bun env snapshot.** Instrumented the TUI and confirmed
   `process.env.OTEL_EXPORTER_OTLP_HEADERS` was correctly set right before the
   `execSync` probe, yet the child still 401'd. A minimal repro nailed it:
   **bun's `execSync` does not propagate runtime-mutated `process.env` to
   children** — only the snapshot captured at process start.
   - `OTEL_EXPORTER_OTLP_ENDPOINT` is injected by docker-compose *at start* →
     in bun's snapshot → child sees it → attempts export.
   - `OTEL_EXPORTER_OTLP_HEADERS` is set *at runtime* → not in the snapshot →
     child sends no auth header → 401.
   - Passing `env: process.env` explicitly to `execSync` fixes propagation.
6. **Which knob silences AILANG export.** Tested empirically: `AILANG_TRACE=off`
   and `AILANG_NO_TRACE=1` do **not** stop trace export — AILANG initializes its
   OTLP exporter purely on `OTEL_EXPORTER_OTLP_ENDPOINT` being set. Only removing
   the endpoint reliably silences it.
7. **AILANG trace tiers.** Read `ailang/internal/trace/options.go` and
   `otel_emitter.go` to answer a follow-up question about `standard` vs `deep`.

## Changes (final state on branch)

- `src/tui/src/index.ts`:
  - Pass `env: process.env` to the version-probe `execSync` so the runtime-set
    OTLP auth header reaches the child. Eliminates the 401 when a valid key is
    present.
  - "Skip export + show hint" path (the behavior the user chose) when ClickStack
    is enabled but no key resolves: `clickStackAuthHeaderPresent()`,
    `disableOtelExport()` (deletes `OTEL_EXPORTER_OTLP_ENDPOINT`,
    `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `MOTOKO_OTEL`), and
    `warnClickStackTracingDisabled()` (one-line actionable hint). No more raw
    401 spam in the no-key case.
- `deploy/clickstack/README.md`: documented the `standard` vs `deep` (and `off`)
  trace tiers, precedence, aliases, and `AILANG_TRACE_MAX_SPANS` interaction.
- `.agent/prs/mot-11-fix-clickstack-startup-401.md`: PR description for the
  branch.

## Verification

- `bun run build` (tsc) from `src/tui` — passes.
- Key present: no `401` / `traces export` / `Trace:` lines at startup.
- Key absent (temporarily removed from `.env`, then restored): prints the
  `tracing is disabled for this run` hint, no 401 / `Trace:` lines.

## Key Takeaways

- **bun gotcha:** mutating `process.env` at runtime does *not* affect
  `execSync` / `spawnSync` children unless `env: process.env` is passed
  explicitly. Any future child spawn relying on a runtime-set var has the same
  trap. (The agent runtime in `runtime-process.ts` was already safe because it
  builds its child env explicitly.)
- **AILANG OTLP export is gated on `OTEL_EXPORTER_OTLP_ENDPOINT` presence, not
  on `AILANG_TRACE`.** To disable export, remove the endpoint; the trace tier
  only controls span granularity.
- The user-facing 401 originated from the startup version probe, not the agent
  loop.

## Follow-ups / Notes

- Pre-existing lint diagnostics in the delegated-exec code (`index.ts`
  "unreachable code" / unused `status`) are unrelated and were left untouched.
- The branch's single commit folds the trace-tier README docs in with the 401
  fix; could be split if a cleaner history is wanted.
