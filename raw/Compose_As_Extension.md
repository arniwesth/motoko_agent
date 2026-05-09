# Compose As Extension — Migration Plan

**Date:** 2026-04-13
**Status:** Draft — awaiting confirmation of open questions
**Suggested branch:** `Compose_As_Extension`

**Related context:**
- `.agent/plans/Core_Extension_System_for_Semi_Formal.md` — X1 substrate (will be extended here)
- `.agent/summaries/2026-04-07-core-extension-phase-x1.md`
- `.agent/summaries/2026-04-11-ailang-composition-language.md`
- `.agent/summaries/2026-04-12-ailang-composition-subagent.md`
- `.agent/summaries/2026-04-12-compose-semi-formal-evidence-guard-implementation.md`

---

## Goal

Migrate the Compose subagent from its current split (TypeScript `env-server` + hand-wired `rpc.ail` hooks) to a self-contained AILANG extension under `src/core/ext/compose/`, using a reshaped X1 substrate. The reshape is part of the plan because X1 as-is cannot host Compose.

Secondary goal: move ~80% of Compose's logic from TS to AILANG, bringing it under AILANG's type system and (where pure) Z3 contracts. Eliminate the `/compose` HTTP endpoint and the `MOTOKO_STREAM_EVENTS` author-subprocess bridge.

## Non-goals

- TS-side plugin substrate. TUI card renderers stay hardcoded in `ui.ts`; event names remain stable.
- Second extension migration. Substrate changes are designed to generalize, but Compose is the only consumer in scope.
- SF4 (citation binding) — not currently implemented; untouched.
- Full-featured regex in AILANG stdlib. A scoped MVP appears as Phase 5 and is optional.

## Assumptions (please confirm before Phase 0)

The plan is written against these defaults. Flip any that are wrong.

1. **Cutover style:** clean flip. Once Phase 4 lands, `/compose`, `compose-claimcheck.ts`, and all TS-side SF guards are deleted. No legacy path kept behind a flag. **Two cutover points, not one:** Phase 2.6 (`/compose` HTTP endpoint deletion) and Phase 4 (final TS SF-guard deletion). Both are destructive; tag commits before each for clean reset.
2. **Test strategy:** existing TS Jest suites (`compose-output-validator.test.ts`, `compose_guard_semiformal.test.ts`, `compose_claimcheck.test.ts`) are promoted to **golden behavioral tests** — they keep running via a thin TS shim that invokes the AILANG extension end-to-end (shim mechanism specified in the LLM-porting strategy section). Unit-level tests are additionally written in AILANG (`*_test.ail`) for pure logic; integration tests for LLM-touching code use a replay harness, not inline `tests [...]`.
3. **Env var names:** preserve existing `AILANG_COMPOSE_*` variable names for operator continuity. Extension reads them via `std/env.getEnv`.
4. **Extension id / tool name:** `compose`. Activation via `CORE_EXT_ORDER=compose`.
5. **Regex MVP trigger (was open question #4):** Phase 5 becomes **required** iff an active `lines_regex` pattern uses features outside the lowered subset (anchors `^`/`$`, literal match, `contains`, `startsWith`, `endsWith`) **and** that pattern is blocking a real task, not a synthetic test. Otherwise Phase 5 is skipped indefinitely and the lowering returns `"pattern requires regex extension (Phase 5)"` for out-of-subset patterns.
6. **`intent_kind` schema ownership:** stays in core `ToolCall` as generic optional metadata (`intent_kind: Option[string]`). Core parser does not interpret it; Compose extension reads it from `ToolCall.args` or a well-known top-level field. This keeps the core tool-call schema extension-agnostic without requiring a schema-registration hook.
7. **Event-name stability is a frozen contract.** All `compose_*` event names and telemetry field names emitted today must be preserved exactly. `ui.ts` and `runtime-process.ts` are unchanged; they are the consumers of record. Any rename is out of scope for this plan.

---

## Target state

```
src/core/
  ext/
    types.ail              [MODIFIED]  enriched ExtCtx, new decision types
    registry.ail           [MODIFIED]  provided_tools registration
    runtime.ail            [MODIFIED]  new dispatchers
    compose/               [NEW]
      compose.ail          -- entry: hook registrations, provided_tools=["compose"]
      types.ail            -- IntentKind, ComposeRequest, ComposeResult, Verdict, Telemetry
      prompts.ail          -- author prompt + certificate templates + intent-kind derivation
      guard.ail            -- SF2: effect-set witness + marker blacklist
      validator.ail        -- SF3: certificate parser + output contract validators
      claimcheck.ail       -- SF5: informalizer + comparator + repair
      retry.ail            -- attempt-loop state machine + hint selection
      telemetry.ail        -- record shape + accumulators
      store.ail            -- stdout elision + .motoko-store writes
      regex.ail            [OPTIONAL Phase 5]
      *_test.ail
  rpc.ail                  [SLIMMED]   extract_ailang / count_ailang_retries / run_compose_tool removed

src/tui/src/
  env-server.ts            [SLIMMED]   /compose and /exec-ailang routes + SF guards deleted
  compose-claimcheck.ts    [DELETED]
  ui.ts                    unchanged (compose_* event names preserved)
  runtime-process.ts       unchanged
```

---

## Phase 0 — X1 substrate reshape

Grow X1 from "policy hooks" to "capability hooks." `test_dummy` is updated in lockstep with the substrate (see 0.8); the rename in 0.1 is a breaking change contained by that update.

### Tasks

- **0.1** Rename `on_tool_call` → `on_tool_policy`. Merge rule unchanged (deny-wins). Breaking for `test_dummy` — reconciled in 0.8.
- **0.2** Add `on_tool_handle(ctx, call) -> Handled(ToolResult) | Delegate`. Registry accepts `provided_tools: [string]` per extension; dispatcher only invokes matching handlers. First handler in `CORE_EXT_ORDER` wins per tool name. Fallback to built-in dispatch if all delegate.
- **0.3** Add `on_response_intercept(ctx, response_text) -> Handled(ToolResult) | NoIntercept`. Fires after model response, before `extract_bash` and tool-call parse. First-intercept-wins.
- **0.4** Enrich `ExtCtx`: `workdir: string`, `env_server_url: string`, `step: int`, `budget_remaining: int`, `history_slice: [Msg]`, `state_key: string` (for SharedMem-scoped per-extension state).
- **0.5** Expand effectful-hook effect set to `{IO, FS, Net, Process, Stream, AI, SharedMem, Env}`. Thread through dispatcher signatures.
- **0.6** Generalize `ToolResult`: `{stdout: string, stderr: string, exit_code: int, metadata: Json}`. `metadata` is the extension's payload channel (telemetry, intent_kind, etc.).
- **0.7** Bless event emission. Document that extensions emit JSONL events via `println`; runtime guarantees line-level atomicity. Add optional helper `ext_emit(ctx, event_type, payload_json) -> () ! {IO}` that stamps `extension_id`. Reserved event shape `ext_error = {extension_id: string, hook: string, error: string, step: int}` — used by 0.10 and any future hook-isolation site; extensions must not reuse this name.
- **0.8** Update `test_dummy` to exercise `on_tool_handle` + `on_response_intercept` (new `dummy_hook` event kinds). Update all existing dummy registrations for the `on_tool_call` → `on_tool_policy` rename.
- **0.9** Inline tests for new hooks + conflict-resolution rules.
- **0.10** Defensive hook-error isolation: the dispatcher wraps every extension hook invocation in a `try`-equivalent (AILANG error capture pattern). On error: log an `ext_error` event with extension id + hook name + error message; treat the hook's contribution as `NoOpinion` (policy), `NoIntercept` (intercept), `Delegate` (handle), or `NoDecision` (finalize). Runtime continues; built-in dispatch proceeds unaffected. Add a test that registers a deliberately-crashing dummy hook and confirms the runtime completes successfully.
- **0.11** Ordering contract: when both `on_response_intercept` and `on_tool_handle` could fire on the same turn, interceptor runs first. If the interceptor returns `Handled`, tool-call parsing is skipped. If it returns `NoIntercept`, tool-call parsing proceeds and `on_tool_handle` is consulted per tool name. If all registered handlers for that tool return `Delegate` (per 0.2), control falls through to built-in dispatch. Full chain: `on_response_intercept` → `on_tool_handle` (first-match-wins in `CORE_EXT_ORDER`) → built-in. Document this in `src/core/ext/runtime.ail` header and cover with a test.
- **0.12** Verify CLI support for the test harness shim: `ailang run --entry <name>` and `--ai-stub <file>` flags (referenced in Strategy #1 and Phase 3.7). If absent, implement them here. `--ai-stub` semantics: when set, `std/ai.call` / `callStreamResult` pops the next response from the stubbed script instead of making a network call; stub is a JSON file with a `responses: [string]` array consumed in order. Without this, the golden-test shim cannot function.

### Exit criteria

- `ailang test src/core/ext/*` passes (registry, runtime, dummy, dummy_test).
- `ailang check src/core/rpc.ail` clean after threading new ExtCtx fields.
- Conflict-resolution tests cover: two handlers registered for same tool → first wins; interceptor + tool-handle present → interceptor runs first; delegate chain falls through correctly; crashing hook isolated from runtime.
- **Integration smoke:** `make run TASK="hello" MODEL=<stub>` with `CORE_EXT_ORDER=test_dummy` completes end-to-end, emitting expected `dummy_hook` events. Confirms extended `ExtCtx` threads cleanly through `rpc_loop` / `run_hybrid_step` / `run_legacy_step` without plumbing regressions.

---

## Phase 1 — Pure-logic migration (clean wins)

Port all pure TS logic to `src/core/ext/compose/`. No behavioral change. Each sub-task = one LLM port session + verification against golden fixtures.

### Tasks

- **1.0** Extract golden fixtures from existing Jest suites (`compose-output-validator.test.ts`, `compose_guard_semiformal.test.ts`, `compose_claimcheck.test.ts`). For each meaningful case, materialize `.agent/golden/compose/<suite>/<case>.input.json`, `.expected.json`, and — for LLM-touching cases — `.llm_script.json`. Write a small TS adapter that re-runs the extracted fixtures through the current TS code paths and confirms round-trip. This establishes the pre-port baseline before any AILANG is written. Note: extraction may require per-case adaptation because some tests use inline literals and per-case mock construction; budget this as real work, not a mechanical step.
- **1.1** `types.ail`: `IntentKind`, `ComposeRequest`, `ComposeResult`, `OutputContract` ADT (`NonEmpty | ContainsAll([string]) | Certificate({...}) | LinesRegex(...)`), `Verdict`, `Telemetry`. Baseline for the rest.
- **1.2** `prompts.ail`: author prompt builder, intent-kind derivation (`deriveIntentKind`, `normalizeIntentKind`), certificate-template selection per intent kind.
- **1.3** `guard.ail`: `parseDeclaredEffects`, marker blacklist, `composeSnippetGuard`. Port with Z3 contracts on pure predicates where possible.
- **1.4** `validator.ail`: PREMISES/TRACE/CONCLUSION parser, premise-line shape check (`<path> -> <text>`), output contracts `NonEmpty` and `ContainsAll`. `LinesRegex` is lowered to `startsWith`/`endsWith`/`contains` for the subset currently used; other patterns return a clear "requires regex extension" error. Full native regex deferred to Phase 5.
- **1.5** `retry.ail`: attempt-loop state machine, prior-errors accumulator, hint selection by error category (parse / effect / type / import_or_symbol / other).
- **1.6** `telemetry.ail`: record shape + accumulators. Mirror field names currently emitted by env-server so TUI renderers see no change.
- **1.7** `store.ail`: stdout elision above `AILANG_COMPOSE_STDOUT_MAX_BYTES`, path resolution for `.motoko-store/compose/<id>.stdout`.

### Exit criteria

- Each ported module has `ailang test` passing.
- **Golden fixtures** (snapshotted from current TS behavior before Phase 1 starts, stored under `.agent/golden/compose/`) produce bit-identical outputs from the AILANG ports.
- `env-server.ts` unchanged; new AILANG modules coexist with existing TS path.

---

## Phase 2 — Modest-lift migration (transport + subprocess)

Move the orchestration layer. Delete the HTTP hop and the author-subprocess bridge.

### Tasks

- **2.1** `compose.ail` entry module: registers with `provided_tools=["compose"]`, hooks `on_response_intercept` (for inline ```ailang fences), `on_tool_handle` (for `compose` tool calls), `on_build_system_prompt` (inject existing compose contract card).
- **2.2** In-extension LLM call: replace TS author subprocess with direct `std/ai.callStreamResult`. Emit `compose_author_delta` events via `println`/`ext_emit`. Removes the `MOTOKO_STREAM_EVENTS=1` bridge entirely.
- **2.3** In-extension snippet execution: `std/process.exec` runs `ailang check` and `ailang run --caps <...> --entry main` on the temp snippet. Temp-file write, module-decl prepend, and cleanup move into `compose.ail`.
  - **Temp file location:** `<workdir>/.motoko-store/snippets/snippet_<counter>_<epoch>.ail`, replacing the previous `/tmp/motoko-snippets/` path. Rationale: `AILANG_FS_SANDBOX=<workdir>` (set by rpc.ail) blocks writes outside workdir; co-locating snippets with `.motoko-store/compose/` keeps everything sandbox-compatible.
  - **Cleanup policy change:** the TS SIGINT/SIGTERM hooks that clean `.motoko-store/` on exit are not portable to the extension. Replace with best-effort startup prune: on extension init, delete snippets older than 24h from `.motoko-store/snippets/`. Individual snippets still deleted in the extension's `finally` equivalent per-invocation. Document this behavior change in the Phase 4 README update.
  - **Subprocess environment:** the `ailang` subprocess inherits the parent's env including `AILANG_FS_SANDBOX`. Confirm in smoke that `ailang run` on the snippet resolves paths relative to the sandboxed workdir as expected.
- **2.4** Event emission: preserve `compose_author_delta`, `compose_check`, `compose_retry`, `compose_exec`, `compose_result` event names so `ui.ts` renderers work unchanged.
- **2.5** `rpc.ail` wiring: thread updated `ExtCtx` + ext_runtime through intercept path. Remove `extract_ailang`, `count_ailang_retries`, `fmt_ailang_obs`, `run_ailang_step`, `run_compose_tool`. Expect a meaningful `rpc.ail` slim.
- **2.6** Delete `/compose` endpoint from `env-server.ts`. Delete `/exec-ailang` — the extension's `std/process.exec` path supersedes it. If the smoke test in 2.5 uncovers a gap, fix it in the extension, not by keeping `/exec-ailang` alive. This is the first cutover point; tag the commit `pre-compose-http-cutover` immediately before merging 2.6.

### Exit criteria

- Smoke task runs end-to-end:
  `make run TASK="List .ts files under src/tui that import express, print each with line count" MODEL=anthropic/claude-sonnet-4-6`
- `compose_*` events render identically in TUI (visual diff on a controlled run).
- TS test suite shrinks (dead tests removed); AILANG test suite grows.
- `src/tui/src/env-server.ts` shrinks by the expected ~600–800 lines.

---

## Phase 3 — SF5 ClaimCheck migration

Separate phase because of the separation invariant (pass 1 sees no intent; pass 2 sees no certificate) and the repair-on-malformed-JSON subtlety.

### Tasks

- **3.1** `claimcheck.ail`: port informalizer (pass 1: certificate → prose) and comparator (pass 2: intent + prose → JSON verdict) as two `std/ai.call` / `callStreamResult` invocations. Prompts constructed with strict separation.
- **3.2** Verdict JSON parsing + repair (one retry on malformed) via `std/json.decode` + explicit shape check.
- **3.3** Per-session invocation budget backed by `SharedMem` via ExtCtx `state_key`. Truncation bound via `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES` preserved.
- **3.4** Dispatch guard: run only when `intent_kind == analyze` and `AILANG_COMPOSE_CLAIMCHECK=1` (default on).
- **3.5** Emit `compose_claimcheck_informalize_delta/result` and `compose_claimcheck_compare_delta/result` with identical shapes.
- **3.6** Delete `src/tui/src/compose-claimcheck.ts`.
- **3.7** Test harness for SF5 (split into two layers, because inline `tests [...]` cannot mock `std/ai.call`):
  - **Pure-helper tests (inline):** verdict JSON parsing, shape validation, separation-invariant checks on prompt-builder outputs, budget-counter logic. Use `tests [(input, expected)]` on pure functions.
  - **Integration tests (replay harness):** create `src/core/ext/compose/test_harness.ail` — a test-mode entry point that reads a scripted fixture (stdin JSON with `{intent, certificate, llm_responses: [...]}`) and runs the claimcheck pipeline with LLM calls replaced by a stub that returns the next scripted response per call. Driven by `ailang run --entry test_claimcheck --caps IO,FS,AI,SharedMem --ai-stub` with fixture piped on stdin. Each integration case is a fixture file under `.agent/golden/compose/claimcheck/` + an expected-output JSON; a small Jest test shells out to `ailang run` and compares stdout JSONL to expected.
  - Retain one TS golden end-to-end test covering the full disputed-retry loop via the same harness.

### Exit criteria

- SF5 behavior identical on fixture inputs: `disputed`/`vacuous`/`surprising_restriction` with `confidence=high` triggers retry; empty informalizer output accepts as inconclusive; separation invariant verified by a test that inspects prompt strings directly.
- Zero references to `compose-claimcheck.ts` anywhere.
- `telemetry.sf5` fields unchanged downstream.

---

## Phase 4 — Cutover and cleanup

### Tasks

- **4.1** Remove remaining dead TS: SF2 guard code, SF3 validator, output-contract switch, telemetry accumulators in `env-server.ts`.
- **4.2** Final `rpc.ail` slim: confirm no Compose-specific knowledge remains outside the extension.
- **4.3** Update `CLAUDE.md` and `README.md` to describe Compose-as-extension. Document `CORE_EXT_ORDER=compose` activation. Explicitly call out the snippet-cleanup behavior change from 2.3: SIGINT/SIGTERM cleanup replaced by best-effort startup prune of snippets older than 24h; per-invocation cleanup unchanged. Operators upgrading should expect stale snippets from crashed sessions until the next run.
- **4.4** Update `.agent/plans/Core_Extension_System_for_Semi_Formal.md` with the Phase 0 substrate additions.
- **4.5** Write session summary to `.agent/summaries/YYYY-MM-DD-compose-as-extension.md`.

### Exit criteria

- `cd src/tui && npx tsc --noEmit` clean.
- `cd src/tui && npm test` passes (thinner suite).
- `ailang test src/core/ext/compose/*` all pass.
- End-to-end smoke with `CORE_EXT_ORDER=compose` passes.
- End-to-end smoke with `CORE_EXT_ORDER=` (empty) confirms Compose is cleanly absent — tool calls to `compose` fail with a recognizable "no handler registered" error, not a crash.
- End-to-end smoke with `CORE_EXT_ORDER=compose` but a deliberately-broken `compose.ail` (e.g., a syntax error, temporarily introduced) confirms a clear load-time error to stderr, not silent absence. Revert the break after the smoke passes.

---

## Phase 5 (OPTIONAL) — AILANG RegEx

Only pursue if Phase 1–4 lands cleanly **and** the Assumption #5 trigger fires (an active `lines_regex` pattern outside the lowered subset blocks a real task).

**Pre-implementation check confirmed (2026-04-13):** no regex exists in AILANG today. Searched `ailang/docs/docs/` and `ailang/std/` — only hits are a speculative future-features mention of "quasiquotes for regex" and an unrelated phrase in a migration doc. Stdlib provides `find`/`contains`/`startsWith`/`endsWith`/`replace`/`split` only. No `_re_*` builtins. Phase 5 genuinely has to add regex from scratch.

### Shared scope (both options)

Pragmatic subset covering regexes users plausibly write in `lines_regex`:

- Anchors: `^`, `$`
- Literals + escapes: `\.`, `\*`, `\\`, `\n`, `\t`
- Character classes: `[a-z]`, `[^abc]`, shorthand `\d`, `\w`, `\s`
- Wildcard: `.`
- Quantifiers: `*`, `+`, `?`, `{n}`, `{n,m}`
- Grouping: `(...)` with capture
- Alternation: `|`

**Out of scope:** backreferences, lookaround, named groups, Unicode property classes, lazy quantifiers.

### Shared public API (both options)

```
compile(pattern: string) -> Result[Regex, string]
matches(r: Regex, text: string) -> bool
find(r: Regex, text: string) -> Option[{start: int, end: int, groups: [string]}]
findAll(r: Regex, text: string) -> [{start: int, end: int, groups: [string]}]
replaceAll(r: Regex, text: string, replacement: string) -> string
```

Lives in `src/core/ext/compose/regex.ail` (extension-local) regardless of option chosen. If Option B is taken, the stdlib `std/regex.ail` added in AILANG is imported from here.

---

### Option A — Pure-AILANG Thompson NFA

Implement regex in AILANG. No runtime patches; no host dependencies. Primarily valuable as a demonstration of AILANG expressiveness and as a reference for future pure-AILANG extensions.

**Architecture:** Classic Thompson NFA — purely functional, no mutable state. O(n·m) matching, no catastrophic backtracking.

**Modules under `src/core/ext/compose/regex/`:**
- `ast.ail` — regex AST ADT
- `parse.ail` — pattern string → AST (recursive-descent)
- `nfa.ail` — AST → NFA (Thompson construction, counter threaded through recursion)
- `sim.ail` — NFA simulation via subset construction, with per-frontier capture tracking
- `regex.ail` — public API
- `regex_test.ail` — 40+ inline + wrapper tests

**Known stdlib gaps (documented as MVP limitations):**
- No char-to-codepoint primitive. `\d`/`\w`/`\s` implemented as predicates on single-character strings (`c >= "0" && c <= "9"` etc.). ASCII only; Unicode-range classes not supported.
- No mutable counter for state-ID generation. Threaded as `(counter, result)` tuple through AST→NFA recursion.
- Capture groups add per-state memory multiplier k (number of groups). Correct but memory-bound.

**Tests:**
- 40+ inline cases covering each feature.
- Adversarial patterns (`(a+)+b` on long non-matching input) to confirm no exponential blowup.
- Curated subset of public regex conformance tests as golden fixtures.

**Completion criteria:**
- All regex tests pass.
- `validator.ail::LinesRegex` switches from lowered subset to native regex; existing fixtures behave identically.
- No new external dependencies; no AILANG runtime patches added.

**Effort / risk:** ~800–1,200 LOC across 5 modules + 200–400 LOC tests. One to two LLM port sessions. Low drift risk (reference implementations are plentiful — Russ Cox's "Regular Expression Matching Can Be Simple And Fast", Go's `regexp/syntax`).

---

### Option B — Go-builtin wrapper (recommended if Phase 5 is triggered)

Expose Go's `regexp` as AILANG builtins, mirroring the precedent already set by `runtime-patches/io_poll_stdin.*` (builtin + effect registration, two Go files). Battle-tested RE2 semantics, full Unicode support, ~10× less code, essentially zero correctness risk.

**Patches (new files under `runtime-patches/`):**
- `regex.builtin.go` — registers `_re_compile`, `_re_match`, `_re_find`, `_re_find_all`, `_re_replace_all` inside `registerStrings()` (or a new `registerRegex()`) in `internal/builtins/`.
- `regex.effects.go` — ops for any effectful operations. In practice, regex ops are pure; no effect registration needed (unlike `_io_poll_stdin`). File may be omitted.
- `README.md` — patch application instructions in the same format as `io_poll_stdin.*`.

**AILANG stdlib addition:**
- `ailang/std/regex.ail` — thin wrapper exposing the builtins with the shared public API signature above. Pure (`! {}`), same as `std/string`.

**Behavior alignment:**
- RE2 disallows some features we don't need anyway (backreferences, lookaround) — matches our "out of scope" list naturally.
- Capture groups return `[]string` with group 0 = full match; map to `[string]` via direct copy.
- Unicode handling is free (RE2 is Unicode-aware by default).

**Integration into the extension:**
- `src/core/ext/compose/regex.ail` becomes a re-export shim importing `std/regex`. No extension-local regex engine.
- `validator.ail::LinesRegex` uses it directly.

**Completion criteria:**
- `ailang/runtime-patches/regex.*` files exist and apply cleanly on a fresh AILANG clone.
- `scripts/install-prerequisites.sh` + existing patch-application docs updated to cover the new patch.
- Regex test suite (shared with Option A — same test cases, different engine behind the public API) passes.
- `validator.ail::LinesRegex` switches from lowered subset to native regex; existing fixtures behave identically.
- Third runtime patch (after `_io_poll_stdin.builtin.go` and `_io_poll_stdin.effects.go`) documented in `README.md` section 1.

**Effort / risk:** ~60 LOC Go + ~20 LOC AILANG wrapper + ~40 LOC patch docs. One LLM session for the Go builtin, one for the AILANG wrapper + wiring. Near-zero drift risk (Go's `regexp` is the reference). Primary risk: setup friction — fresh clones now require three runtime patches instead of two.

---

### Decision criterion when Phase 5 is triggered

- If the driver is **shipping `lines_regex` correctly for a real validator pattern** → **Option B**. Smaller, safer, done in a day, full Unicode.
- If the driver is **demonstrating that AILANG can host its own regex engine** (dogfooding, language maturity showcase, reducing host dependencies) → **Option A**.

Default recommendation when triggered: Option B. The extension's job is validation, not language advocacy.

**Selection procedure.** When the trigger fires, the plan author (human or agent) appends a one-paragraph amendment to this file under a new `## Phase 5 selection` heading, stating: (a) the specific blocking pattern, (b) A or B, (c) one-sentence rationale. Implementation starts only after that amendment lands.

---

## LLM-porting strategy

An LLM will do the porting. The risk is not speed — it is **semantic drift during translation**, particularly in guard predicates, validator state machines, and SF5's separation invariant. Mitigations are baked into the phase structure.

1. **Golden tests survive the port.** Every TS test with meaningful assertions is kept alive as a behavioral test that invokes the AILANG extension through a thin shim. Cross-language equivalence is checked at the boundary, not trusted via code review alone.
   - **Shim mechanism:** a Jest test in `src/tui/src/__golden__/compose.golden.test.ts` spawns `child_process.spawn("ailang", ["run", "--entry", "<harness_entry>", "--caps", "<caps>", "--ai-stub", "<harness.ail>"])`, pipes fixture JSON on stdin, reads JSONL from stdout, and asserts line-by-line (or normalized deep-equal) against a golden file. Non-determinism (timestamps, run IDs, durations) is stripped by a normalizer before comparison.
   - **LLM-call determinism:** Compose makes LLM calls in `std/ai.call` / `callStreamResult`. `--ai-stub` provides deterministic canned responses. For multi-turn scenarios where different responses are needed per call (SF5 pass 1 vs pass 2, or retry sequences), the test harness reads a scripted-response list from the fixture and uses an in-harness stub that pops the next response per `ai.call`. This is the replay mechanism referenced in Phase 3.7.
2. **Golden fixture freeze before Phase 1.** Concrete procedure:
   - For each Jest suite currently in `src/tui/src/compose*.test.ts`, identify fixture inputs and expected outputs already embedded in the test code.
   - For each, materialize `.agent/golden/compose/<suite>/<case>.input.json` and `.agent/golden/compose/<suite>/<case>.expected.json`.
   - For LLM-touching cases, also snapshot the currently-mocked LLM responses as `<case>.llm_script.json`.
   - Run the existing TS tests once against these extracted fixtures (via a small adapter) to confirm round-trip. This establishes the pre-port baseline before any AILANG code is written.
3. **One module per port session.** Each sub-task in Phases 1–3 is a single module with paired tests. Context stays small, review is tractable, a bad port is revertable without blast radius.
4. **Contracts where the fragment allows.** For pure predicates in `guard.ail` and `validator.ail`, add `requires`/`ensures` during the port so `ailang verify` catches what Z3 can prove. Not all logic fits the decidable fragment (anything recursive, higher-order, or effectful is out), but effect-set parsing and premise-line shape should.
5. **Separation-invariant tests for SF5.** Assertions must inspect the prompt strings passed to pass 1 and pass 2 directly, not just the final verdict. Drift here is silent and dangerous.
6. **Porting directive: faithful translation first, refactor later.** The instruction to the porting LLM on each sub-task is explicit: reproduce the source logic 1:1, keep variable names adjacent where possible, no opportunistic cleanup. Refactoring, if any, happens in a separate pass after golden tests are green. This prevents the common failure mode of "clean up while porting" introducing silent behavioral changes.
7. **Tight per-port prompts.** Each port session's prompt includes: the source file slice, the target AILANG module path, the AILANG syntax cheatsheet subset relevant to the port (effects, pattern-matching style, Option/Result conventions), the golden fixture it must reproduce, and the directive above.
8. **Checkpoint after every module.** Run `ailang check` + `ailang test` + the golden diff after each sub-task. Do not batch ports before verification.

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Semantic drift in SF2/SF3/SF5 during port | Medium | Golden fixtures + single-module ports + direct-prompt inspection for SF5 |
| AILANG stdlib missing a primitive mid-port | Medium | Phase 1 surfaces gaps early; regex is explicitly deferred to Phase 5 |
| `std/ai.callStreamResult` streaming semantics differ from the TS subprocess bridge (delta timing, event ordering) | Medium | Smoke-test against a fixed LLM mock in Phase 2 before deleting the TS path |
| `std/process.exec` can't reproduce `ailang check`/`ailang run` subprocess behavior exactly (timeout handling, stderr capture) | Low | Cross-check on fixture snippets before deleting `/exec-ailang` |
| TUI events arrive out of order or with altered timing | Low | `ui.ts` unchanged; event names preserved; only emission site moves |
| Phase 0 substrate changes break `test_dummy` | Low | Phase 0.8 updates dummy alongside hook changes |
| Scope creep into a second extension or TS-side plugin substrate | Medium | Non-goals section is binding; a second extension is the trigger for that work, not this plan |

## Rollback

Each phase is independently revertable through Phase 2.5. **Two cutover points**, both destructive:

- **Phase 2.6** — deletion of `/compose` and `/exec-ailang` HTTP endpoints. Tag commit `pre-compose-http-cutover` immediately before.
- **Phase 4** — deletion of TS-side SF guards and `compose-claimcheck.ts`. Tag commit `pre-compose-extraction-cutover` immediately before.

Post-cutover rollback means restoring from git, not flipping a flag. Phases 0 / 1 / 2.1–2.5 / 3.1–3.6 are additive and cleanly revertable by branch discard.

---

## Open questions (answers drive Phase 0)

Most original questions collapsed into Assumptions after the 2026-04-13 patch. What remains:

1. **Branch name** — `Compose_As_Extension` acceptable, or prefer something else?
2. **Golden fixture scope** — Jest-tested surface only (narrower, faster) vs that plus 2–3 recorded end-to-end compose runs (broader, catches orchestration drift). Default: Jest-tested surface + 2–3 recorded E2E runs.
3. **Hook-error reporting channel (from Phase 0.10)** — `ext_error` events via stdout JSONL (default; matches existing event pattern and appears in TUI/trace) vs stderr-only logging (quieter in normal operation, less observable during bugs).

Cutover style, test strategy, env var names, `intent_kind` schema ownership, regex MVP trigger, and event-name stability are pinned in Assumptions. Flip any of those if a default is wrong; otherwise Phase 0 can begin once questions 1–3 are answered.
