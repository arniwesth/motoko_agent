# Plan: `eval` persistent verified AILANG scratchpad

Feature context: **[plan 01](./01-design-c-mvp-local-loopback.md)** (persistent Python/JS eval), **[plan 03](./03-eval-tui-card-rendering.md)** (rich eval card), **[plan 04](./04-eval-inline-image-rendering.md)** (current eval card segment renderer), and the existing stateless `/exec-ailang` route.
Independent of [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md).
Toolchain: AILANG v0.19.1 (`ailang.lock`), Bun 1.3.x, Z3 if the pinned AILANG verifier requires the external binary.

## Background

The Python/JS eval design gives the model a persistent execution scratchpad: state survives across cells and across separate tool calls. AILANG already has a stateless eval-like path in the env-server:

- `src/core/env_client.ail` exposes `exec_ailang(...)`.
- `src/tui/src/env-server.ts` exposes `POST /exec-ailang`, which writes a temporary module, runs `ailang check`, then runs `ailang run`.
- The current eval implementation is already present on this branch, but its type surface is Python/JS-only: `EvalLanguage = "py" | "js"` in `src/tui/src/eval/frames.ts`, `normalizeEvalCells()` coerces any non-`"js"` language to `"py"`, `EvalRegistry` only routes `"py" | "js"`, and `ui.ts` rejects structured eval cells whose language is not `"py"` or `"js"`.

That route is useful, but it is not a persistent scratchpad and it does not surface AILANG's strongest advantage: the compiler and verifier can reject bad code before execution. A persistent AILANG eval should therefore **not** mimic a Python REPL heap. It should persist **source context**: imports, types, constants, pure functions, verified lemmas, and named executable entries. Each new cell updates an accumulated session module, then the env-server gates it through `ailang check` and, when requested, `ailang verify` / verifier-enabled `ai-check` before execution.

This gives a different value proposition from Python:

- Python eval is best for ad hoc computation, plotting, and library-heavy exploration.
- AILANG eval is best for checked reasoning: typed helper functions, effect rows, deterministic execution, and Z3-backed proof obligations for pure fragments.

## Goals

- Add persistent `ail` cells to the existing `eval` tool as `language: "ail"`.
- Maintain a per-session accumulated AILANG module so declarations survive across cells.
- Run `ailang check` on every proposed session update before accepting it.
- Support an explicit verification gate for cells containing `@verify`, `requires`, `ensures`, or a cell-level `verify: true` option.
- Execute checked AILANG entries through `ailang run` only after the check / verification policy passes.
- Return structured per-cell results compatible with plan 03's eval card: source, check status, verify status, stdout/stderr, diagnostics, and duration.
- Preserve AILANG effect discipline: cells declare requested caps, but the env-server and extension policy decide what can actually run.
- Keep workdir / filesystem confinement aligned with the current `/exec-ailang` behavior (`AILANG_FS_SANDBOX=workdir`).
- Update every current Python/JS-only branch (`frames.ts`, env-server normalization, eval registry, WebSocket eval path, TUI parsing/rendering, and package schema) so `ail` is not silently coerced to Python or dropped from the rich card.

## Non-goals

- **No live AILANG REPL process.** Persistence is source/module persistence, not a mutable interpreter heap. AILANG remains compile/check/run oriented.
- **No guarantee that every calculation is formally proved.** Z3 can prove stated properties for supported pure fragments. Unannotated code, effectful code, floating-point-heavy work, solver timeouts, and complex string/list recursion may be checked or executed but not formally proven.
- **No kernel loopback in AILANG cells for MVP.** AILANG code should not call `tool.*` from inside the cell in this plan. If needed later, route it through plan 02's canonical WebSocket loopback rather than creating another local fork.
- **No verifier ABI invention.** Use the pinned AILANG CLI's existing verification command shape. If v0.19.1 differs from current docs or plans (`ailang verify`, `ailang ai-check --verify`, or `@verify` handling), spike and codify the exact command first.
- **No rich proof UI beyond structured diagnostics.** The eval card can show "checked", "verified", "unknown", or "failed" plus diagnostics; proof-object browsing is a separate feature.

---

## User-facing shape

An AILANG eval cell is a source fragment plus execution intent:

```json
{
  "language": "ail",
  "title": "verified absolute difference",
  "code": "export pure func abs_diff(a: int, b: int) -> int ! {}\\nensures { result >= 0 }\\n{ if a > b then a - b else b - a }",
  "verify": true
}
```

Executable cells can either define declarations or request an entry call:

```json
{
  "language": "ail",
  "title": "run checked helper",
  "code": "export func main() -> unit ! {IO} { println(show(abs_diff(10, 3))) }",
  "caps": "IO",
  "run": true
}
```

For convenience, a later enhancement can add expression cells (`expr: "abs_diff(10, 3)"`) that the env-server lowers into a generated `main`. The MVP can require users / the model to write `main` explicitly.

The JSON schema must model `verify` as either a boolean or the string `"auto"`; if the AILANG schema helper cannot conveniently express a union, use a string enum (`"auto" | "required" | "skip"`) instead of a mixed-type field.

## Architecture

```
LLM ── "eval" tool ──▶ motoko_ext_eval
                          │ httpPost POST /exec-cell
                                          ▼
                                   env-server (Bun)
                                          │ session→AilangSession registry
                                          ▼
                           accumulated tmp/session_<id>.ail
                              │          │             │
                              ├─ ailang check
                              ├─ ailang verify / ai-check --verify (optional gate)
                              └─ ailang run --entry main --caps ...
```

`AilangSession` is source-backed:

```ts
type AilangSession = {
  sessionId: string;
  moduleName: string;
  imports: string[];
  acceptedDecls: AilangAcceptedDecl[];
  lastGoodSource: string;
  capsDefault: string;
  createdAt: number;
  lastUsedAt: number;
};
```

Each new cell is compiled into a candidate module:

1. Strip any user-supplied `module ...` declaration.
2. Classify top-level `import` lines separately from declarations. Imports must be rendered immediately after the generated module declaration; raw cell-order concatenation will eventually produce invalid modules if a later cell introduces an import.
3. Keep persistent declarations separate from ephemeral run wrappers. A cell that defines `main` for execution should not permanently shadow future generated entries unless the user explicitly marks it as a declaration.
4. Render the candidate module as: generated module declaration, deduplicated imports, accepted declarations, candidate declaration(s), optional generated run wrapper.
5. Write to a stable temp path for the session.
6. Run the check / verification / run pipeline.
7. Commit the candidate declarations/imports only if the configured acceptance policy passes.

This is the key semantic difference from Python: a failed AILANG cell does **not** mutate session state.

---

## Phase 0 — verify the pinned CLI contract

**Files:** no product files required; add notes to this plan or a tiny smoke under `.agent/research/omp-style-python-eval/ailang-verify-smoke/` if useful.

Before implementation, prove the exact commands supported by the pinned runtime:

- `ailang check <file>`
- `ailang run --caps <caps> --entry main <file>`
- verifier command:
  - preferred if present: `ailang verify <file>`
  - preferred machine-readable form if present: `ailang verify --json <file>`
  - alternate if that is the real interface: `ailang ai-check --verify <file>`
  - document how `@verify(depth: N)`, `requires`, and `ensures` are discovered and reported.

Also confirm whether Z3 must be installed separately or is bundled / optional. If external, update `scripts/install-prerequisites.sh` to check for `z3` when verified AILANG eval is enabled.

**Acceptance:** a tiny module with a provable `ensures { result >= 0 }` passes; a deliberately false postcondition fails; the command exits and diagnostics are captured deterministically.

---

## Phase 1 — env-server persistent AILANG session registry

**Files (new):** `src/tui/src/eval/kernel-ailang.ts`, `src/tui/src/eval/ailang-session.ts`.
**Files (modified):** `src/tui/src/eval/frames.ts`, `src/tui/src/eval/registry.ts`, `src/tui/src/eval/ws-channel.ts`, `src/tui/src/env-server.ts`.

Implement a source-backed session registry:

- Key by `sessionId`, matching the Python/JS eval registry semantics.
- Store accepted cells and the last-good full module source.
- Add idle eviction and explicit `reset:true`, mirroring Python/JS eval.
- Use a per-session temp directory under the existing snippet area, not the repo tree.
- Preserve accepted source for diagnostics / snippets, but avoid writing failed candidates to permanent training stores unless explicitly wanted.
- Extend `EvalLanguage` to `"py" | "js" | "ail"`.
- Change `normalizeEvalCells()` to preserve `"ail"` and reject unknown languages with an explicit per-cell error; do **not** default unknown languages to Python.
- Update `EvalRegistry` so `"ail"` routes to the source-backed runner instead of trying to allocate a Python/JS kernel.
- Update the WebSocket eval channel's cell normalization path so B′ and v2 eval dispatch see the same cell language semantics as HTTP `/exec-cell`.

Candidate handling:

- `reset:true` clears accepted imports/declarations before applying the current cell.
- A declaration-only cell runs `check` and optional `verify`, then commits if gates pass.
- A run cell runs `check`, optional `verify`, then `ailang run --entry main` or the requested entry.
- Failed candidates return diagnostics and do not update `lastGoodSource`.

**Acceptance:** two separate `ail` cells can define a pure helper in the first cell and use it from `main` in the second; a later cell can add an `import` without producing an invalid mid-module import; a third invalid cell fails without removing the previous definitions; `reset:true` clears the session.

---

## Phase 2 — verification gate and result model

**Files:** `src/tui/src/eval/frames.ts`, `src/tui/src/eval/kernel-ailang.ts`, `src/tui/src/eval/transcript.ts`, `src/tui/src/ui.ts`.

Extend eval cell/result types for AILANG-specific statuses without disrupting Python/JS:

```ts
type AilangCheckStatus = "passed" | "failed" | "skipped";
type AilangVerifyStatus = "verified" | "failed" | "unknown" | "timeout" | "skipped";

type AilangCellMetadata = {
  check: { status: AilangCheckStatus; diagnostics: string };
  verify: { status: AilangVerifyStatus; diagnostics: string; command?: string };
  committed: boolean;
  proofClaim: "proved" | "not_proved";
  entry?: string;
  caps?: string;
};
```

Add this as an optional per-cell metadata field on `EvalCellResult`, not only as top-level response metadata:

```ts
type EvalCellResult = {
  // existing fields...
  metadata?: { ailang?: AilangCellMetadata };
};
```

The plain transcript should also receive human-readable status lines (either rendered from metadata or emitted as `display {type:"status"}` bundles) so the fallback stdout path remains useful. The structured `metadata.ailang` field is the source of truth for the TUI card and tests.

Verification policy:

- `verify: "auto"` (default): run verifier only when annotations are present (`@verify`, `requires`, `ensures`).
- `verify: true`: require verification to pass before commit/run.
- `verify: false`: skip verifier, but still run `ailang check`.
- `verify_required` profile option: in strict profiles, annotated cells that return `unknown` or timeout fail closed.

Status semantics:

- `check failed` ⇒ no commit, no run.
- `verify failed` with required verification ⇒ no commit, no run.
- `verify unknown/timeout` with optional verification ⇒ commit can proceed, but transcript must say it is not proved.
- `run failed` after check/verify ⇒ commit policy is configurable. Recommendation: declaration cells commit before run; generated `main` wrappers do not become persistent session source.

**Acceptance:** the response distinguishes type errors from verification failures, `cells_json` preserves `cell.metadata.ailang` through `emit_eval_result_if_present`, and the transcript never claims "verified" for skipped / unknown / timed-out proof attempts.

---

## Phase 3 — route integration

**Files:** `src/tui/src/env-server.ts`, `src/tui/src/eval/ws-channel.ts`, `src/core/env_client.ail`, `src/core/types.ail`, `src/core/agent_loop_v2.ail`, `packages/motoko_eval/eval.ail`.

Extend `/exec-cell` to accept `language: "ail"` alongside `"py"` and `"js"`. Do not add a separate `/exec-ailang-cell` route for the MVP; a second route would duplicate the eval-card metadata path and the v2/WebSocket dispatch path.

Current-branch integration detail: `src/core/agent_loop_v2.ail` special-cases `eval` and calls `exec_cell_ws(...)` directly before the normal extension `dispatch_tool_handle` path. AILANG cells must work through this direct v2/WebSocket path as well as through the extension's HTTP fallback path, or behavior will diverge by runtime mode.

Request shape:

```json
{
  "cells": [
    {
      "language": "ail",
      "code": "...",
      "title": "prove helper",
      "timeout": 30,
      "reset": false,
      "verify": "auto",
      "run": false,
      "entry": "main",
      "caps": "IO"
    }
  ],
  "sessionId": "..."
}
```

Response remains the plan-01/03 `CellExecResult` shape, with AILANG check/verify details attached to each cell's structured metadata.

**Acceptance:** a mixed request can run Python/JS cells through existing kernels and AILANG cells through the source-backed AILANG runner without changing the TUI wire type.

---

## Phase 4 — extension schema and prompt

**Files:** `packages/motoko_eval/types.ail`, `packages/motoko_eval/eval.ail`, `packages/motoko_eval/prompts.ail`.

Update tool schema and prompt guidance:

- Add `"ail"` to `language` enum.
- Add optional AILANG fields: `verify`, `run`, `entry`, `caps`.
- Explain that AILANG state is source-persistent: declarations persist only after check/verify gates pass.
- Teach the model when to choose AILANG over Python:
  - use AILANG for typed helper functions, integer/string/list invariants, effect-checking, and proof obligations;
  - use Python for data science libraries, plotting, floating point exploration, and quick ad hoc numeric work.
- Include a caveat that verification proves declared contracts, not every informal intent.

Policy:

- `on_tool_policy` should treat AILANG eval at least as strictly as Python/JS eval.
- In restricted modes, allow `check`-only / `verify`-only AILANG cells only if that profile explicitly wants pure static analysis. This requires inspecting the `cells` argument in `on_tool_policy`; the current package denies all `eval` in restricted/read-only modes.
- Cap strings are intersected with policy before the cells are sent to the env-server; user/model requested caps are not authoritative. Also enforce the same cap ceiling in the env-server as defense in depth, because the v2 WebSocket path can bypass package-level `on_tool_handle`.

**Acceptance:** the tool description makes it hard for the model to overclaim proof strength, and restricted policy can permit static checking without permitting arbitrary execution.

---

## Phase 5 — TUI rendering

**Files:** `src/tui/src/ui.ts`, `src/tui/src/ui.tool-render.test.ts`, `src/tui/src/eval/frames.ts`.

Reuse the current eval card/segment renderer from plans 03–04. AILANG cells render like normal cells with extra status lines:

- Header: `✓ [i/N] title (check passed · verified · 123ms)` or `✗ ... (verify failed)`.
- Source: syntax-highlighted with the existing `highlightCodeLines(code, "ail")` / `"ailang"` path.
- Output divider sections:
  - `Check` diagnostics.
  - `Verify` diagnostics.
  - `Run` stdout/stderr.

Current blocker: `normalizeEvalCellResult()` in `ui.ts` currently returns `null` unless `language` is `"py"` or `"js"`, causing an `eval_result` with `ail` cells to be ignored. This parser must accept `"ail"` and preserve `metadata.ailang`; the highlighter path for `"ail"` / `"ailang"` already exists.

**Acceptance:** a failed verification is visible in the collapsed preview; a successful verified helper shows a concise "verified" status without drowning the user in raw solver output.

---

## Phase 6 — tests & verification

- **TS unit:** source accumulation, reset, failed-cell non-commit, check failure mapping, verify success/failure/unknown mapping, timeout handling.
- **Normalization regression:** unknown eval languages produce explicit errors; `language:"ail"` is preserved through HTTP `/exec-cell`, WebSocket `/exec-cell-ws`, `eval_result` JSON, and TUI parsing.
- **AILANG smoke:** one checked-only cell, one verified pure function, one false contract, one run cell using a previously accepted declaration.
- **Policy smoke:** restricted profile permits check-only if configured and denies run/effectful caps.
- **TUI test:** card renders check/verify statuses and diagnostics.
- **Wire metadata test:** `cell.metadata.ailang` survives env-server response → `ToolResultEnvelope.metadata.cells` → `eval_result.cells_json` → `parseEvalCellsJson`.
- **Regression:** existing Python/JS eval tests stay green; existing `/exec-ailang` stateless route remains available unless deliberately deprecated.

Manual E2E:

```text
use eval in AILANG to define a pure abs_diff function with an ensures clause proving the result is non-negative, verify it, then run main to print abs_diff(10, 3)
```

Expected transcript:

- first cell: check passed, verify verified, committed;
- second cell: check passed, verify skipped or verified, run prints `7`;
- no Python/JS kernel involvement.

---

## Sequencing & risks

1. Phase 0 first. Do not build against an assumed verifier command.
2. Phase 1 source registry and check-only persistence.
3. Phase 2 verification statuses and gates.
4. Phase 3 route integration.
5. Phase 4 schema/prompt/policy.
6. Phase 5 card/transcript rendering.
7. Phase 6 tests and E2E.

Risks:

- *Verifier command drift* — plans and research mention `ailang verify`, `ai-check --verify`, `@verify`, `requires`, and `ensures`. The pinned CLI must be treated as source of truth.
- *Overclaiming proofs* — "Z3 verified" only means the stated contract discharged in the supported fragment. The transcript and prompt must preserve `unknown` / `skipped` states.
- *Persistent source composition* — concatenating arbitrary fragments can create duplicate exports, shadowing, stale `main` functions, or invalid import placement. Mitigate by storing imports/declarations/wrappers separately and rendering the module deterministically.
- *Performance* — check/verify on the full accumulated module may get slow. MVP accepts this; later optimize by splitting stable accepted declarations from generated run wrappers or caching verified snapshots.
- *Effect policy confusion* — AILANG caps are safer than Python, but still execute effects through the runtime. The extension policy must intersect requested caps with the active profile.
- *Z3 limits* — string/list reasoning and recursion can time out or return unknown. Treat unknown as a first-class result, not a failure of the tool.
- *Runtime-path drift* — v2's direct `exec_cell_ws` eval path can bypass package `on_tool_handle`. Keep HTTP, WS, and extension dispatch behavior covered by the same tests.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| 1 | Add `language:"ail"` to `eval` or make `ailang_eval` separate? | Add `language:"ail"` to existing `eval`; the current branch already has the eval card and WebSocket path that should be reused. |
| 2 | Should declaration cells with `run` failure commit? | Commit checked declarations; keep generated `main` wrappers ephemeral so run failures do not poison session state. |
| 3 | What is the default verification policy? | `auto`: verify annotated cells, report unknown honestly, require pass only when `verify:true` or strict profile says so. |
| 4 | Should failed candidate source be saved for training? | Not by default. Save only redacted diagnostics unless the snippet store explicitly opts into failed verified-eval examples. |
| 5 | Can AILANG cells call tools / agents? | Not in this MVP. If needed, use plan 02's canonical loopback so policy remains centralized. |
