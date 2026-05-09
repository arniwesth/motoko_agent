# Compose Semi-Formal Evidence Guard — Implementation Summary

Date: 2026-04-12
Scope: Implement `Compose_Semi_Formal_Evidence_Guard.md` phases in Compose subagent path (self-contained), with runtime/UI visibility improvements and default enablement for SF5.

## Session objectives and constraints

1. Read and align to:
- `README.md`
- `ailang-v0.9.0-docs.md`
- `.agent/plans/Compose_Semi_Formal_Evidence_Guard.md`

2. Implement plan phases for Compose subagent, not main-agent verifier.

3. Explicit constraint respected:
- Did **not** use extension substrate from `Core_Extension_System_for_Semi_Formal.md`.
- Work kept self-contained in Compose env-server path + existing core prompt/type/plumbing.

## High-level outcomes

Implemented major portions of the plan in production code:

1. SF2: effect-set evidence witness guard (replacing weak read-call substring heuristic)
2. SF1: intent kind + certificate-template prompt injection
3. SF3: `expected_output.kind=certificate` validator
4. SF5: ClaimCheck-style two-pass round-trip verification, per-attempt, with retries and telemetry
5. UI/runtime support for SF5 live events and explicit SF5 status visibility
6. Default flip: `AILANG_COMPOSE_CLAIMCHECK=1` by default

Additionally:
- Updated stale effect annotation guidance in `CLAUDE.md`.

## Implemented changes by phase

### SF2 — Effect-set evidence witness

Implemented in `src/tui/src/env-server.ts`:

1. Added exported helpers:
- `parseDeclaredEffects(snippet: string): Set<string>`
- `composeSnippetGuard(intent, snippet, intentKind)`
- `deriveIntentKind(intent)` and `normalizeIntentKind(raw)`

2. Guard behavior now depends on `AILANG_COMPOSE_EFFECT_GUARD`:
- `1` (default):
  - marker blacklist active
  - for `analyze`/`summarize` intents, require `FS` or `Process` in declared effects
- `legacy`:
  - marker blacklist active
  - old `readFile(`/`exec(` substring requirement for analysis intent
- `0`:
  - guard fully disabled

3. Marker list narrowed:
- retained: `simulated analysis`, `in a real execution`, `would read files`, `based on structural inspection`, `hypothetical`
- removed false-positive entries: `assume`, `assumption`

4. Telemetry additions:
- `intent_kind`
- `guard_mode`
- `declared_effects_by_attempt`
- `last_declared_effects`

### SF1 — Certificate template in author prompt + intent kind

Implemented in `src/tui/src/env-server.ts` and core plumbing files.

1. Compose request schema in env-server now accepts optional `intent_kind`.

2. Kind derivation/fallback:
- If `intent_kind` present and valid, uses it
- Else derives from intent text
- Conservative default is `compute`

3. Author prompt builder now receives `intentKind` and can inject shape templates when `AILANG_COMPOSE_CERTIFICATE_TEMPLATE=1`:
- `analyze`: `PREMISES / TRACE / CONCLUSION` certificate
- `summarize`: `INPUT / KEY_POINTS / SUMMARY`
- `list`: `SOURCE / FILTER / ITEMS`
- `fetch`: `URL / STATUS / EXCERPT / DERIVED`
- `transform`/`compute`: no template injection

4. Prompt now includes explicit `Intent kind: <kind>` line.

5. Main-agent tool contract docs updated in `src/core/prompts.ail`:
- Compose examples now include `intent_kind`
- Compose guidance documents accepted values: `analyze | list | transform | compute | fetch | summarize`

6. Core tool-call transport updated to carry `intent_kind` end-to-end:
- `src/core/types.ail`
- `src/core/parse.ail`
- `src/core/rpc.ail`
- `src/core/env_client.ail`

### SF3 — Certificate validator (`expected_output.kind=certificate`)

Implemented in `src/tui/src/env-server.ts`.

1. Extended expected output spec union with:
- `{ kind: "certificate", min_premises?, require_trace?, require_conclusion? }`

2. Added parser and validator logic:
- section parsing for `PREMISES`, `TRACE`, `CONCLUSION` (case-insensitive)
- premise line shape enforcement: `<path> -> <text>` or `<path> → <text>`
- split on first arrow occurrence
- defaults:
  - `min_premises = 1`
  - `require_trace = true`
  - `require_conclusion = true`
- rejects invalid `min_premises < 1` as inconclusive spec

3. Existing exit policy preserved:
- high-confidence unsatisfied validator causes compose result exit code escalation to `2`

4. Telemetry split added:
- `validator_certificate_structure_failures`
- `validator_content_failures`

### SF5 — ClaimCheck-style round-trip informalization

Implemented primarily via new module:
- `src/tui/src/compose-claimcheck.ts`

Wired through:
- `src/tui/src/env-server.ts`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`

#### SF5 behavior implemented

1. Dispatch:
- Runs only when enabled and `intent_kind == analyze`
- Per-attempt execution (not end-of-session batch)

2. Pass 1 (informalizer):
- Input: certificate stdout only (intent excluded)
- streaming deltas emitted
- timeout/error -> inconclusive accept + telemetry
- empty output -> inconclusive accept + telemetry

3. Pass 2 (comparator):
- Input: original intent + pass1 description
- certificate/snippet source excluded
- streaming deltas emitted
- parses strict JSON verdict schema
- malformed JSON triggers one repair attempt; second failure -> inconclusive accept + telemetry

4. Retry policy:
- `disputed` / `vacuous` / `surprising_restriction` with `confidence=high` => force retry via existing compose retry loop
- retry hint uses only most recent informalization summary

5. Budget and truncation:
- per-session invocation cap via `AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS`
- stdout truncation bound via `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES` with marker

6. Telemetry structure implemented under `telemetry.sf5`:
- `invocations`
- verdict counters
- `informalizer_ms`, `comparator_ms`
- timeout/error counters
- empty informalizer counter
- JSON repair counters
- budget exhausted flag
- truncated stdout counter

7. Environment variables implemented:
- `AILANG_COMPOSE_CLAIMCHECK`
- `AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL`
- `AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL`
- `AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS`
- `AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS`
- `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES`

## TUI and runtime visibility improvements

### New compose events supported

Added in runtime event union and UI handling:
- `compose_claimcheck_informalize_delta`
- `compose_claimcheck_informalize_result`
- `compose_claimcheck_compare_delta`
- `compose_claimcheck_compare_result`

### Compose card rendering enhancements

In `src/tui/src/ui.ts`:

1. Compose card stores and renders per-attempt SF5 state:
- pass1 delta text
- pass1 final informalization
- pass2 delta text
- final verdict/confidence/reason

2. Non-confirmed verdicts rendered with high-contrast error box treatment.

3. Added explicit top-level card fields:
- `intent_kind`
- `sf5: enabled|disabled`

4. Added final SF5 summary line parsed from telemetry:
- `sf5 status: PASS (...)`
- `sf5 status: NOT RUN (...)`
- `sf5 status: ISSUES (...)`

This addresses prior UX issue where SF5 status was only visible deep inside raw telemetry JSON.

## Default behavior flip

Updated in `src/tui/src/env-server.ts`:

- `AILANG_COMPOSE_CLAIMCHECK` now defaults to `"1"` (enabled) instead of `"0"`.
- Still supports explicit override to disable:
  - `AILANG_COMPOSE_CLAIMCHECK=0`

## Test coverage added/updated

### New test files

1. `src/tui/src/compose_guard_semiformal.test.ts`
- validates declared-effect parsing
- rejects analyze intent without `FS`/`Process`
- accepts analyze with `FS`
- verifies `assume` text no longer causes fabricated marker failure

2. `src/tui/src/compose_claimcheck.test.ts`
- high-confidence disputed verdict triggers retry
- empty informalizer output => inconclusive accept
- separation invariant (pass1 excludes intent; pass2 excludes certificate)
- budget-exhausted skip behavior

### Updated test file

3. `src/tui/src/compose-output-validator.test.ts`
- certificate pass case
- missing TRACE fail case
- malformed premise line fail case

## Validation and checks executed

Repeatedly executed during implementation:

1. TypeScript build:
- `cd src/tui && npm run build`

2. Jest suites (focused + full path-pattern run):
- `npm test -- --runInBand compose_guard_semiformal compose-output-validator`
- `npm test -- --runInBand compose_claimcheck compose_guard_semiformal compose-output-validator`
- `npm test -- --runInBand ui.tool-render compose_claimcheck`

3. Core runtime type checks:
- `ailang check src/core/types.ail`
- `ailang check src/core/parse.ail`
- `ailang check src/core/prompts.ail`
- `ailang check src/core/env_client.ail`
- `ailang check src/core/rpc.ail`

All checks completed without errors in this session.

## Files changed in this implementation (source)

1. `src/tui/src/env-server.ts`
2. `src/tui/src/compose-claimcheck.ts` (new)
3. `src/tui/src/compose_guard_semiformal.test.ts` (new)
4. `src/tui/src/compose_claimcheck.test.ts` (new)
5. `src/tui/src/compose-output-validator.test.ts`
6. `src/tui/src/runtime-process.ts`
7. `src/tui/src/ui.ts`
8. `src/core/types.ail`
9. `src/core/parse.ail`
10. `src/core/env_client.ail`
11. `src/core/rpc.ail`
12. `src/core/prompts.ail`
13. `CLAUDE.md`

Generated outputs were also updated during build:
- `src/tui/dist/*`

## Notes and caveats

1. `src/src/snippets/*` contains many untracked snippet artifacts generated by testing runs; these are expected by current snippet persistence behavior.

2. SF4 citation binding was not implemented in this session; current behavior includes SF2 + SF1 + SF3 + SF5 and UI visibility/default tuning.

3. SF5 is default-on now, but still non-blocking in outage/failure scenarios via inconclusive-accept policy and budget caps.

## Net result

Compose now has a materially stronger anti-fabrication pipeline:

1. Capability-level evidence guard (SF2)
2. Structured certificate prompting (SF1)
3. Deterministic certificate structure enforcement (SF3)
4. Semantic intent-vs-certificate consistency check (SF5)
5. Clear operator-facing visibility in TUI, with SF5 enabled by default.
