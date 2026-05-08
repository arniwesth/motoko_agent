# Motoko AILANG Rebase-Forward Plan

## Goal
Move Motoko off the v0.9.0-based `dev_agent` fork and onto the most recent released version of AILANG (currently v0.13.0 on `dev`). Establish a permanent "rebase-forward" discipline: track upstream AILANG release tags as the base, layer Motoko's custom runtime extensions on top as clearly-marked `_motoko` files, and treat each AILANG release as a bounded rebase exercise rather than a cherry-pick triage.

## Fundamental Principle
**The Motoko-facing AILANG branch must remain as close as possible to the most recent released version of upstream AILANG.** All custom modifications exist as an additive layer on top of that base, never as diverging edits to shared files. Cherry-picking upstream changes backward into an old base is explicitly rejected.

## Context
- Upstream AILANG does not accept external PRs. Motoko must carry its runtime extensions as a permanent fork.
- Today: `dev_agent` = v0.9.0 + 7 custom commits (OpenRouter, `_io_poll_stdin`, local OpenAI endpoint, streaming, Result-based AI errors, ParseFloat underscore fix, test patches).
- Target: a Motoko branch whose base is identical to upstream `dev` at tag `v0.13.0`, with all custom logic isolated in files matching the `*_motoko.{go,ail}` pattern plus a small number of fenced one-line edits in shared dispatch/registration files.
- A prior deep comparison has confirmed which dev_agent modifications are superseded, conflicting, or still required. See `.agent/summaries/` (this session) and the analysis in `.agent/plans/Local_OpenAI_Endpoint_Integration.md`, `.agent/plans/OpenRouter_Integration.md`, `.agent/plans/OpenAI_LLM_Streaming_For_Motoko.md`, `.agent/plans/Native_Tool_Calling_For_Motoko.md`.

## Naming Convention (Hard Rule)
1. **New files only:** every file that does not exist upstream is suffixed `_motoko.{go,ail,ts}`. Examples:
   - `internal/effects/ai_motoko.go`
   - `internal/builtins/ai_motoko.go`
   - `internal/builtins/io_motoko.go`
   - `internal/effects/io_motoko.go`
   - `internal/ai/openai/stream_motoko.go`
   - `internal/ai/openai/openrouter_motoko.go`
   - `internal/ai/openai/endpoint_motoko.go`
   - `std/ai_motoko.ail`
   - Test files follow the same rule: `ai_stream_motoko_test.go`.
2. **Shared-file edits** are one-line additions only, fenced with comments:
   ```go
   // motoko:begin
   RegisterOp("AI", "callStreamResult", aiCallStreamResultMotoko)
   // motoko:end
   ```
   AILANG uses `-- motoko:begin` / `-- motoko:end`.
3. **Module names stay upstream-compatible** where possible. `std/ai_motoko.ail` may declare `module std/ai_motoko` (new module) rather than shadowing `std/ai`, so upstream `std/ai` remains untouched and importable. `core/rpc.ail` imports both as needed.
4. **If logic in a shared file grows past one line**, extract it into a `_motoko` file and call into it from the fenced block.
5. **`grep -r motoko ailang/` must be the complete enumeration of the fork surface.** This is the invariant that makes rebases tractable.

## Target Base
- AILANG release tag `v0.13.0` (commit `99f76ec7`).
- Future rebases pin to release tags, not raw `dev` HEAD, to avoid chasing unstable intermediate commits.

## Per-Modification Disposition
File paths listed below are the **target landing sites in v0.13.0's tree**, not v0.9.0 paths. Exact paths are confirmed during Phase 0.5 (directory layout has shifted across Type V2 migration and codegen refactors).

| dev_agent modification | Disposition on new base |
|---|---|
| OpenRouter integration | **Re-port** as `internal/ai/openai/openrouter_motoko.go` + fenced registration in provider dispatch |
| `_io_poll_stdin` runtime patch | **Re-port** as `internal/builtins/io_motoko.go` + `internal/effects/io_motoko.go` |
| Local OpenAI endpoint support | **Re-port** as `internal/ai/openai/endpoint_motoko.go` |
| OpenAI streaming + endpoint error handling (`CallStream`, SSE, typed `AIError`) | **Re-port** as `internal/ai/openai/stream_motoko.go` + `internal/effects/ai_motoko.go`. Endpoint error surface is folded in here — not a separate row. |
| Result-based AI error handling | **Re-port** as `internal/builtins/ai_motoko.go` + `std/ai_motoko.ail` (`AIError`, `AIStreamChunk`, `AIStreamResult`, `callResult`, `callJsonResult`, `callStreamResult`) |
| ParseFloat underscore rejection | **Drop** — already upstream on dev |
| Test patches (commit `c152a6d2`) | **Mandatory read-out in Phase 0**: `git show c152a6d2` must be reviewed, its intent documented in `.agent/reports/c152a6d2_test_patches_readout.md`, and a verdict (port / drop / partial) recorded before Phase 0 exits. No known-unknowns carried forward. |

## Non-Negotiable Invariants
- `git diff <upstream-tag>..motoko-branch -- <any-file-not-matching-*_motoko.*>` must be empty except for fenced edits.
- All streaming, Result-AI, and stdin-poll logic lives in `_motoko` files. No exceptions.
- Every fenced shared-file edit is bounded by `// motoko:begin` / `// motoko:end` markers so future rebases can locate and re-apply them mechanically.
- **Fenced-edit content rules** (enforced by `make verify-fork-surface`, see Phase 6):
  - Each fenced block must be ≤ 5 lines between markers.
  - Content must match one of these allowed shapes:
    1. Registration calls: `RegisterEffectBuiltin(...)`, `RegisterOp(...)`, `handlers[...] = ...`
    2. Single-line imports: `import ...`
    3. Dispatch forks of the shape `if motoko.ShouldX(...) { return motoko.DoX(...) }` — a one-line guard that hands off entirely to a `_motoko` file. The predicate and handler **must** live in a `_motoko` file, not inline.
    4. `case "...": return motoko.Handle(...)` — same principle for switch dispatch.
  - No business logic inline, no conditionals deeper than one level, no inline type definitions. If you want to write it, put it in a `_motoko` file and call into it.
- **The `_motoko` naming convention applies only inside `ailang/`.** Parent-repo changes (e.g., `src/core/rpc.ail`, `src/tui/src/*.ts`) are ordinary Motoko development and do not require suffixes or fenced blocks.
- Builds succeed with vanilla upstream AILANG command-line tests after each phase — Motoko additions must not break existing AILANG examples, stdlib tests, or goldens.
- `core/rpc.ail` imports from both upstream `std/ai` (for base `call`) and `std/ai_motoko` (for streaming + Result variants). No upstream module is shadowed.
- **Parallel-branch safety**: `dev_agent` remains Motoko's production branch and is not deleted, retargeted, or force-pushed until Phase 5 validation passes end-to-end on the new `motoko` branch. If any phase stalls or fails, Motoko keeps running on `dev_agent` with zero disruption.

## Phases

### Phase 0 — Baseline and branch setup
- Create new branch **directly from the release tag**: `cd ailang && git checkout -b motoko v0.13.0`. (Not from `dev` HEAD — pin to the tag exactly.)
- Confirm vanilla build on v0.13.0. Exact commands (discover and record in `.agent/reports/phase0_baseline.md`):
  - `cd ailang && make build` (or equivalent — inspect `ailang/Makefile` for the real target name)
  - `cd ailang && go test ./...` for Go-side tests
  - Golden suite — command discovered from `ailang/Makefile` or `ailang/scripts/`; record exact invocation.
- Record baseline test output (pass count, any pre-existing skips) for regression comparison in Phase 5.
- Snapshot the current `dev_agent` diff against `v0.9.0` fork point into `.agent/reports/dev_agent_fork_diff.patch` as a reference artifact (not applied).
- **Capture a `dev_agent` behavioral baseline**: run Motoko on a fixed deterministic task (e.g., `"echo hello"`) using `dev_agent` and a pinned model, save the full JSONL event stream to `.agent/reports/dev_agent_baseline_trace.jsonl`. This becomes the reference trace Phase 5 diffs against.
- **Read out commit `c152a6d2` (test patches)**: `cd ailang && git show c152a6d2`. Write `.agent/reports/c152a6d2_test_patches_readout.md` with: files touched, intent, and verdict (port / drop / partial-with-what-to-keep). Phase 0 does not exit until this report exists.
- Create `ailang/FORK.md` as a skeleton with headers: Base, `_motoko` Files Inventory, Fenced Edits Inventory, Effect-Set Changes, Rebase Playbook, Change Log. Sections are filled in through phases; Phase 6 finalizes the document.

### Phase 0.5 — Upstream AI layer interface spike (kill-switch gate)
This is the riskiest question in the entire plan, resolved before any porting begins. If the answer is bad, the plan itself is wrong and must be reconsidered.
- **Read `internal/ai/handler.go`, `internal/ai/provider.go`, `internal/effects/ai.go`, `internal/builtins/ai.go` on v0.13.0.** Document the current handler interface shape and how builtins are registered.
- **Question A — Streaming additivity**: can `CallStream(input, onEvent)` be added to the handler interface additively, or does v0.13.0 use a sealed/closed interface shape that would require modifying non-Motoko files more than a fenced registration? If the latter, the `_motoko` file convention is insufficient for streaming and the plan must be revisited (options: accept larger fenced blocks with raised line-count invariant, or fork the handler interface into `ai_handler_motoko.go` wrapping the upstream one).
- **Question B — Can `std/ai_motoko` be added as a new stdlib module at all?** The real risk is not namespace overlap — `std/ai_motoko` has its own function names — but whether `std/` is a closed set. Check: is there a manifest, an embed directive, a `go:embed`'d file list, or a registration table enumerating stdlib modules? Smoke test: add an empty `std/ai_motoko.ail` containing one trivial exported function, import it from a test AILANG file, run it. If the runtime rejects the module (not found, not in manifest), locate the registration site and either (a) add `std/ai_motoko` there via a fenced edit, or (b) fall back to `ext/ai_motoko` or a non-`std` location. Document the outcome.
- **Question C — Runtime registration source of truth**: inspect `internal/builtins/spec.go` and per-builtin registration files (for AI: `internal/builtins/ai.go`) first; treat `internal/builtins/registry.go` / `registry_codegen.go` as metadata/codegen unless proven otherwise. Document exactly where runtime registrations must live in v0.13.0 and confirm builtin naming conventions still support `_ai_call_stream_result` style symbols.
- **Question D — Effect system changes**: document the required effect set for streaming AI calls in v0.13.0. Default expectation is `AI` for AI operations and `Stream` only when exposing stream/event-loop primitives directly; do not assume a new `AIStream` effect exists without source proof.
- **Question E — Budget accounting surface**: locate the concrete budget counters/APIs and document the single-budget-unit test surface. Also verify whether current wrappers pre-charge via `RequireCapWithBudget` before calling `effects.Call(...)`, and if so, define the `callStream` rule as exactly one charging site.
- **Question F — Go module dependencies**: inspect `ailang/go.mod` on v0.13.0. List new direct dependencies vs v0.9.0 (M-BRAIN SQLite driver, OTEL for WASM trace, etc.). Confirm Motoko's streaming port (likely `net/http` + `bufio` only — no new SDK) does not require new dependencies or conflict with upstream version pins.
- Write `.agent/reports/phase0_5_ai_interface_spike.md` with findings for A–F and a go/no-go verdict. If no-go, halt and escalate.
- **Gate**: go verdict + written answers to all six questions, or plan revision.

### Phase 1 — Port `_io_poll_stdin` (smallest patch, validates convention)
- **Preflight (must pass before edits):**
  - Enumerate every planned shared-file edit and map each to a `motoko:begin`/`motoko:end` block.
  - Prove each block fits `make verify-fork-surface` constraints (<=5 non-blank lines, allowed line shapes only).
  - If any required edit cannot fit the fence constraints, halt and revise plan before implementation.
- Create `internal/builtins/io_motoko.go` with the `_io_poll_stdin` builtin logic (non-blocking peek via `bufio.Reader.Buffered()`, newline-complete lines only).
- Create `internal/effects/io_motoko.go` with the `IO.pollStdin()` effect op.
- Register both via fenced edits in the actual v0.13.0 runtime registration surfaces (`internal/builtins/spec`/per-builtin init path and `internal/effects/io.go`).
- Add `internal/builtins/io_motoko_test.go` covering: buffered content returns, empty buffer returns empty, partial line returns empty.
- Gate: `make build` succeeds; `_io_poll_stdin` is callable from an AILANG smoke script; upstream stdin behavior untouched.

### Phase 2 — Port OpenRouter provider routing
- Create `internal/ai/openai/openrouter_motoko.go`: detects `openrouter/<model-id>` prefix, sets base URL `https://openrouter.ai/api/v1`, strips prefix for the upstream API call.
- Fenced edit in `internal/ai/openai/chat.go` (or current v0.13.0 provider dispatch) to route through the Motoko detection function when the prefix is present.
- Add `openrouter_motoko_test.go` with prefix detection, URL routing, and pass-through cases.
- Gate: smoke test via a Motoko end-to-end run against an OpenRouter model.

### Phase 3 — Port local OpenAI endpoint + error handling
- Create `internal/ai/openai/endpoint_motoko.go`: `openai://localhost:<port>` URI parsing, custom base URL override, retryable-error classification, typed `AIError` surface.
- Fenced edit in provider dispatch to route `openai://` URIs.
- Tests in `endpoint_motoko_test.go`: URI parsing, error classification, retry metadata.
- Gate: smoke test against the local OpenAI-compatible endpoint used by Motoko's local-model flow.

### Phase 4 — Port streaming + Result variants (largest phase)
- Create `internal/ai/openai/stream_motoko.go`: SSE parser, chunk decoder, stream lifecycle.
- Create `internal/effects/ai_motoko.go`: `CallStream(input, onEvent)` handler method, stream state, abort propagation.
- Create `internal/builtins/ai_motoko.go`: `_ai_call_result`, `_ai_call_json_result`, `_ai_call_stream_result` builtins.
- Create `std/ai_motoko.ail`: `AIError`, `AIStreamChunk`, `AIStreamResult` types; `callResult`, `callJsonResult`, `callStreamResult` wrappers.
- Do not broadly widen upstream `AIHandler`/provider interfaces unless Phase 0.5 evidence proves it can be done within fenced-edit invariants. Preferred path is Motoko wrapper integration via `_motoko` files plus minimal shared hooks.
- Fenced registration/dispatch edits only where upstream v0.13.0 actually wires AI effect ops and provider dispatch (as established by Phase 0.5 findings).
- **Test acceptance criteria (non-negotiable, copied from `OpenAI_LLM_Streaming_For_Motoko.md` invariants):**
  - **Ordered sequence**: each chunk carries a monotonic sequence index; a test asserts out-of-order delivery is impossible or detected.
  - **Single-budget-unit**: one `callStream` invocation represents exactly one provider call regardless of chunk count. Implement with one charging site only (avoid double-charge paths). Assert via budget counters where exposed and always assert mock provider `Call*` invocation count is exactly one.
  - **Abort-correctness**: mid-stream abort cancels the provider context and emits exactly one terminal event (error or cancelled), never zero and never two. Test with abort at chunk 1, chunk N/2, and after final chunk.
  - **Error-mid-stream**: provider error during streaming surfaces as a typed `AIError` Result, not a panic or silent truncation. Test with a provider that errors after 3 successful chunks.
  - **Typed Result propagation**: `_ai_call_result` returns `Err(AIError)` for HTTP non-2xx, JSON parse failure, and network timeout — each with the right error tag.
  - **Trace-visibility**: stream lifecycle emits structured effect trace events for start, each chunk, and terminal event. Test asserts trace log contains the expected sequence.
- Gate: all acceptance criteria above have passing tests + Motoko runs end-to-end with streaming visible in TUI for OpenAI and OpenRouter models.

### Phase 4b — TUI protocol and renderer updates
Streaming is invisible to users unless the TypeScript side decodes and renders deltas. This phase is explicitly in scope; it is not deferred.
- Define the JSONL protocol additions in a contract document at `.agent/specs/motoko_stream_protocol.md` (events: `thinking_stream_start`, `thinking_delta`, `thinking_stream_end`, payload shapes, ordering guarantees).
- Update `src/core/rpc.ail` to emit the new events when using `callStream` (this also triggers the effect-annotation audit described in Phase 5).
- Update `src/tui/src/runtime-process.ts` to decode the new events.
- Update `src/tui/src/ui.ts` to render incremental deltas in the history pane, reconciling with the existing `thinking`/`done` flow.
- Tests: JSONL decoder unit tests, UI reconciliation tests ensuring delta → final transition is idempotent.
- Gate: user visibly sees streaming output in the TUI when running against an OpenAI or OpenRouter model; abort mid-stream stops rendering cleanly.

### Phase 5 — Integration validation
- Update `core/rpc.ail` imports to use `std/ai_motoko` where streaming/Result variants are needed; keep upstream `std/ai` imports for plain calls.
- **Effect-annotation audit**: walk every file in `src/core/*.ail` and confirm top-level effect signatures still type-check. Adding `std/ai_motoko` calls may change the transitive effect set in `core/rpc.ail`'s `! {IO, FS, Process, Net, AI, SharedMem, Stream, Env}`. Default expectation from Phase 0.5 is no new `AIStream` effect type; use `AI` for AI calls and `Stream` only where stream primitives are explicitly used. Run `ailang check` on every file; fix every mismatch. **If the effect set changes, update runtime capability flags in the same phase**: `scripts/run-agent.sh`, any `make run` targets in `Makefile`, and `--caps` invocations in docs. Record the before/after effect sets in `FORK.md`.
- Update `runtime-patches/` directory: either retire it (if all patches are now `_motoko` files) or reduce to documentation of the fenced registry edits.
- Run the full Motoko end-to-end smoke path: TUI starts, model picker works, task runs with streaming, abort works, OpenRouter and OpenAI-local both succeed.
- **Baseline trace diff**: rerun the deterministic task from Phase 0 on the new `motoko` branch, capture the JSONL stream, and diff against `.agent/reports/dev_agent_baseline_trace.jsonl`. Annotate every expected difference (new event types from streaming, reordered fields, changed formatting) in `.agent/reports/phase5_trace_diff.md`. Unexplained differences block the gate.
- Run AILANG's own test suite and goldens from the v0.13.0 tag to confirm no upstream regressions; compare against the Phase 0 baseline test output.
- Update `README.md`, `SYSTEM.md`, `AGENTS.md` (parent-repo and `ailang/AGENTS.md`), and `CLAUDE.md` to reflect the new branch name and rebase-forward convention. Add a one-line pointer from parent-repo `CLAUDE.md` to `ailang/FORK.md`.
- **Cutover point**: only after all of the above passes does `motoko` become Motoko's production branch. `dev_agent` is tagged (`git tag pre-rebase-forward dev_agent`) and retained for reference, not deleted.

### Phase 6 — Rebase playbook and fork hygiene
Status: Completed on 2026-04-21.

- Completion evidence:
  - `.agent/reports/phase6_rebase_readiness.md`
  - `.agent/reports/phase6_dryrun_rebase_summary.txt`
  - `.agent/reports/phase6_verify_fork_surface.out`
  - `ailang/FORK.md`
- Completion summary:
  - `make verify-fork-surface` is implemented and passing.
  - `FORK.md` is finalized with inventory, fenced edits, playbook, risk areas, and changelog.
  - Dry-run rebase baseline against `origin/dev` recorded with zero conflicts.

- Finalize `ailang/FORK.md` (skeleton created in Phase 0, populated through phases). Sections:
  - **Base**: upstream tag and commit SHA
  - **`_motoko` Files Inventory**: one entry per file with purpose, key exports, upstream interfaces it depends on
  - **Fenced Edits Inventory**: file path + line range + purpose for every `motoko:begin`/`motoko:end` block
  - **Effect-Set Changes**: before/after effect sets on `core/*.ail` from Phase 5
  - **Rebase Playbook**: step-by-step procedure for the next AILANG release (checkout new tag, cherry-pick Motoko commits, resolve fenced-edit conflicts, run `make verify-fork-surface`, run Phase 5 validation)
  - **Known Risk Areas**: files most likely to see upstream churn affecting Motoko layer (AI handler interface, builtin registry, effect dispatcher)
  - **Change Log**: one line per rebase recording date, new base tag, conflict count, issues found
- Add a `make verify-fork-surface` target that enforces the real invariants. Exact rules:
  ```
  1. Enumerate changed files:
     git diff <base-tag>..HEAD --name-only -- . \
       ':(exclude)*_motoko.*' ':(exclude)FORK.md' ':(exclude).agent/**'
  2. For each file in the list:
     a. File must contain at least one motoko:begin/motoko:end pair.
     b. Every hunk from `git diff <base-tag>..HEAD -- <file>` must fall
        entirely between a motoko:begin and its matching motoko:end.
  3. Global balance: count(motoko:begin) == count(motoko:end).
  4. For each fenced block:
     a. Line count between markers (exclusive) <= 5.
     b. Every non-blank line matches one of these regexes:
       - ^\s*RegisterEffectBuiltin\(
       - ^\s*RegisterOp\(
       - ^\s*handlers\[.*\]\s*=
       - ^\s*import\s
       - ^\s*if\s+motoko\.\w+\(.*\)\s*\{\s*return\s+motoko\.\w+\(.*\)\s*\}
       - ^\s*case\s+".*":\s*return\s+motoko\.\w+\(
  5. Any violation prints file:line and exits non-zero.
  ```
- **Dry-run rebase measurement**: after `FORK.md` and the Makefile target are committed, perform a dry-run rebase of the `motoko` branch onto current `dev` HEAD (don't keep it — discard with `git rebase --abort` or a throwaway branch). Record the conflict count and file list in the `FORK.md` Change Log as the initial rebase-readiness baseline. A high conflict count here reveals insufficient isolation and triggers remediation before declaring Phase 6 done.
- Commit the `FORK.md` and Makefile target.

## Expected File Surface After Migration
New Motoko-only files (in `ailang/`):
- `internal/builtins/io_motoko.go`, `internal/builtins/io_motoko_test.go`
- `internal/effects/io_motoko.go`
- `internal/ai/openai/openrouter_motoko.go`, `openrouter_motoko_test.go`
- `internal/ai/openai/endpoint_motoko.go`, `endpoint_motoko_test.go`
- `internal/ai/openai/stream_motoko.go`, `stream_motoko_test.go`
- `internal/effects/ai_motoko.go`, `ai_motoko_test.go`
- `internal/builtins/ai_motoko.go`, `ai_motoko_test.go`
- `std/ai_motoko.ail`
- `FORK.md`

Fenced shared-file edits (exact list to be confirmed against v0.13.0 layout during Phase 1):
- `internal/builtins/ai.go` (and/or other per-builtin init files) — register `_motoko` builtins via `RegisterEffectBuiltin(...)`
- `internal/effects/io.go` — register `IO.pollStdin` op
- `internal/effects/ai.go` — register streaming AI op dispatch hook
- `internal/ai/openai/chat.go` or provider dispatch — route OpenRouter prefix and `openai://` URI

Parent-repo changes:
- `core/rpc.ail` — update imports to `std/ai_motoko`
- `runtime-patches/` — retire or reduce to documentation
- Docs (`README.md`, `SYSTEM.md`, `CLAUDE.md`) — reflect new branch and convention

## Phase 0.5 Resolved Questions
Phase 0.5 answers are recorded in `.agent/reports/phase0_5_ai_interface_spike.md` and gate all subsequent phases:
- **Q-A** (streaming additivity): upstream `AIHandler` is non-streaming; default integration path is Motoko-side wrappers plus minimal shared hooks.
- **Q-B** (module duality): `std/ai_motoko` can coexist with upstream `std/ai`.
- **Q-C** (registry source of truth): runtime builtin source-of-truth is `internal/builtins/spec.go` + per-builtin `RegisterEffectBuiltin(...)` init files.
- **Q-D** (effect set for streaming): default is `AI` for AI calls; `Stream` only when exposing stream primitives directly.
- **Q-E** (budget accounting surface): budget counters are available; `callStream` must use exactly one charging site to preserve single-unit semantics.
- **Q-F** (Go dependency drift): v0.13.0 adds dependency drift relative to v0.9.0; treat as environment/CI parity risk, not a blocker.

Any future change that invalidates these findings triggers plan revision before continuing.

## Success Criteria
- Motoko runs end-to-end on AILANG v0.13.0 with streaming, OpenRouter, local OpenAI endpoint, and stdin polling all functional.
- `git diff v0.13.0..HEAD -- . ':(exclude)*_motoko.*' ':(exclude)FORK.md' ':(exclude).agent/**'` shows only fenced edits that pass `make verify-fork-surface` rules (≤5 lines per block, whitelisted patterns only).
- `make verify-fork-surface` passes.
- `dev_agent` is retained and tagged `pre-rebase-forward` — not deleted.
- Parent-repo `CLAUDE.md` contains a pointer to `ailang/FORK.md`.
- Rebase-readiness measurement (from the Phase 6 dry-run rebase onto `dev` HEAD): conflict count and file list are recorded as the baseline in `FORK.md`. On each subsequent AILANG release, if the measured conflict count exceeds (baseline × 2) or introduces conflicts in non-fenced regions of shared files, that's a signal the fork surface has drifted and requires remediation before proceeding with the rebase.
