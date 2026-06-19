# Plan: `eval` persistent verified Lean 4 scratchpad

Feature context: **[plan 05](./05-persistent-verified-ailang-eval.md)** (persistent verified AILANG eval — the kernel pattern this reuses), **[plan 01](./01-design-c-mvp-local-loopback.md)** (persistent Python/JS eval), **[plan 03](./03-eval-tui-card-rendering.md)** / **[plan 04](./04-eval-inline-image-rendering.md)** (eval card renderer), and the research note **[02-additional-evaluators](../../research/omp-style-python-eval/02-additional-evaluators.md)** that proposed Lean 4 as the headline next backend.
Toolchain: Lean 4 via the **`leanprover-community/repl`** (JSON-over-stdio), installed through `elan` → `lake`. Bun 1.3.x. **Ship Lean-without-Mathlib first**; Mathlib is an opt-in, pre-warmed flag. Phase 0 must measure the exact repl JSON + install path before any product code.

## TL;DR

Add `language:"lean"` to the existing `eval` tool as a persistent, **proof-verified** scratchpad. Where `ail` cells type-check pure functions and prove SMT contracts, `lean` cells **prove arbitrary theorems**. Lean is a hybrid of the two kernel styles already in the tree: like py/js it drives a **long-lived child process** (the `repl`), but like `ail` it is **verified-commit-gated** — each cell elaborates against the previous environment, and only a clean cell advances the committed state. Persistence is **env-id threading** (the repl returns an `env` integer you thread into the next command), not source re-rendering — strictly cheaper than `ail` because prior cells are never re-elaborated. The defining hazard is **proof honesty**: a Lean theorem can silently escape via `sorry`/`admit` or a sneaky `axiom`, so `proof: verified` must mean **"elaborated, zero sorries, and `#print axioms` shows only the standard `{propext, Classical.choice, Quot.sound}`"** — anything else (`sorry`, `axiom_tainted`, `native_decide` trust deps) is reported honestly and never as proved. Reuse the exact plan-05 seams: `EvalLanguage` union, `normalizeEvalCells`, `EvalKernelRegistry` routing (incl. idle eviction / `close()`), the eval-card `metadata` channel, the one-time teach-prompt mechanism, and the TUI status renderer.

## Background

Plan 05 did not really build "an AILANG kernel" — it built a reusable **verified-eval kernel pattern**: a state-accumulating session (accepted declarations persist; a failed candidate never mutates state), a *check → optional-verify* commit gate, **honest status mapping** (`verified` only when the prover actually proved it), a one-time teaching prompt surfaced in the *visible* output, plus env-server normalization, a host capability ceiling, and TUI status rendering. Any backend shaped "accumulate → check → optionally prove" drops into that shape. Lean 4 is the highest-value addition because it upgrades the tool from "checks contracts" to "**proves theorems**" — propositions outside the decidable arithmetic fragment Z3 handles.

How Lean differs from the two existing lanes, and why that shapes the design:

- **py / js** (`kernel-py.ts`, `kernel-js.ts`) — own a **long-lived child process**; `registry.ts` already manages spawn, idle eviction, and `close()` teardown for these. Lean's `repl` is exactly this kind of process.
- **ail** (`kernel-ailang.ts`, `ailang-session.ts`) — **stateless per call** (`execFileSync ai-check`), persistence faked by re-rendering and re-checking the whole accumulated module each cell; `close()` is a no-op. Lean borrows the *verified-commit gate* and *honesty discipline* but **not** the re-render model.

So Lean is a genuine hybrid: **live process (py/js) + verified-commit gate (ail)**. Concretely:

- The `repl` accepts one JSON command per line on stdin and replies with JSON: `{ messages, sorries, env }` (and `#print axioms` text in `messages`). The `env` integer is threaded into the next command (`{"cmd": "...", "env": N}`) — this **is** the persistence mechanism. Cell 1 → `env 0`; cell 2 sends `env:0` → `env 1`. A failed candidate may still mint an env id; the commit gate decides whether the session's *committed* env pointer advances. A failed cell does **not** advance it. This is a near-drop-in for `AilangSession`'s "accepted state only moves on success," with **no source re-elaboration** of prior cells.
- **Elaboration is the check.** There is no cheap `ai-check` equivalent: parsing+elaborating the cell *is* both the type-check and the proof attempt. The persistent env is what keeps this fast (prior cells already elaborated).
- **The proof caveat is sharper than Z3's.** With Z3, "not verified" = unknown / timeout / counterexample, all visibly non-success. With Lean the escape hatches are *silent*: `sorry` / `admit` produce a warning but still "succeed," and an `axiom` declaration lets you assume anything. So honesty requires two signals, not one: the repl's `sorries` field (must be empty, and no `declaration uses 'sorry'` message), **plus** a `#print axioms <thm>` check per theorem (must contain nothing beyond `propext`, `Classical.choice`, `Quot.sound`; `sorryAx` and `Lean.ofReduceBool`/`native_decide` trust axioms are red flags).

## Goals

- Add persistent `lean` cells to the existing `eval` tool as `language:"lean"`.
- Maintain a per-session **committed env id** so declarations/theorems persist across cells via repl env-threading; a failed cell never advances the committed env.
- Elaborate every proposed cell against the committed env before accepting it.
- Compute an honest **proof verdict** for theorems in the cell: `verified` only when elaborated + zero sorries + clean `#print axioms`.
- Support a proof gate (`prove: "auto" | "required" | "off"`) mirroring `ail`'s `verify` mode and its `decideCommit` semantics.
- Return structured per-cell results compatible with the plan-03/04 eval card: elaboration status, proof status, per-theorem axioms, repl messages, duration — carried through `EvalCellResult.metadata.lean`.
- Surface a **Lean-4-specific teaching guide once per session** (models reflexively write Lean 3 tactics), reusing the plan-05 `teachPromptSeen` mechanism and visible-stdout surfacing.
- Ship **Lean-without-Mathlib** as the default; make Mathlib an explicit opt-in (`mathlib:true`) that selects a heavier, pre-warmed toolchain.
- Update every `EvalLanguage`-bearing branch (`frames.ts`, `normalizeEvalCells`, `registry.ts`, env-server config, the v2/WebSocket eval path, `ui.ts` parsing + highlighter, and `packages/motoko_eval` schema/prompt) so `lean` is neither dropped nor coerced.
- Manage the `repl` child process safely: spawn lazily, enforce per-cell timeouts with hard kill, evict on idle, and tear down on `close()` (the registry already calls this).

## Non-goals

- **No Mathlib in the MVP default.** Mathlib means multi-GB caches and seconds-plus per-cell latency; it is opt-in and pre-warmed only.
- **No claim that every cell is proved.** A `def`/`#eval` cell with no theorem proves nothing (`proof:"skipped"`). `sorry`, `admit`, custom `axiom`, and compiler-trust axioms (`Lean.ofReduceBool` via `native_decide`) are reported honestly, never as `verified`.
- **No general code execution / effects.** Lean is for proving, not running effectful programs. `#eval` output (captured from repl `messages`) is allowed; there is no caps/FS/Process surface like `ail run`. No capability ceiling is needed for Lean.
- **No tool/agent loopback from inside Lean cells.**
- **No proof-object / tactic-state browsing UI** beyond structured diagnostics and the repl's `goals`/`messages`. (The repl's `sorries` carry proof states; surfacing them richly is a later feature.)
- **No env pickling to disk** (the repl's `pickleTo`/`unpickleEnvFrom`) in the MVP — env lives in process memory; process death = session loss (see Open questions).
- **No premature shared abstraction.** Build `lean-session.ts` / `kernel-lean.ts` mirroring the AILANG pair first; extract a shared `VerifiedSession`/`VerifierKernel` interface only after both backends are green (Phase 7, optional — the design note in 02 anticipates exactly this once a *second* verifier lands).

---

## User-facing shape

A Lean eval cell is Lean 4 source plus an optional proof gate:

```json
{
  "language": "lean",
  "title": "add_comm is provable",
  "code": "theorem my_add_comm (a b : Nat) : a + b = b + a := by omega",
  "prove": "required"
}
```

Definitions/lemmas accumulate; a later cell uses them through the threaded env:

```json
{
  "language": "lean",
  "title": "use the earlier theorem",
  "code": "example : 2 + 3 = 3 + 2 := my_add_comm 2 3"
}
```

`#eval` is allowed and its output is captured from repl `messages` (no separate run/entry/caps machinery):

```json
{ "language": "lean", "code": "#eval List.range 5 |>.map (· * 2)" }
```

Cell fields (Lean-only fields ignored for py/js/ail):

- `prove`: `"auto"` (default) | `"required"` | `"off"`.
  - `auto` — compute the proof verdict when the cell declares a `theorem`/`lemma`; do **not** block commit on `sorry`/`unknown` (mirrors `ail` `verify:"auto"` + `decideCommit`).
  - `required` — every theorem in the cell must be `verified` (clean axioms, no sorry) or the cell is rejected and the env does not advance.
  - `off` — elaborate only; report the proof verdict but never gate on it.
- `mathlib`: boolean, default `false`. Selects the Mathlib-enabled toolchain for the session. Changing it mid-session implies `reset:true`.
- Shared fields reused as-is: `code`, `title?`, `timeout?`, `reset?`.

The JSON schema models `prove` as a string enum (`"auto" | "required" | "off"`), exactly like `ail`'s `verify` (see `packages/motoko_eval/types.ail`), to avoid a mixed boolean/string union.

## Teaching prompt contract

Models reflexively emit **Lean 3** tactics and syntax, so a Lean-4-specific reference must be surfaced **once per session before the first `lean` cell**. Unlike AILANG (which has `ailang agent-prompt`), there is **no upstream CLI prompt** to lean on — this plan **ships a concise Lean-4 cheat-sheet asset** in the repo and surfaces it through the existing one-time mechanism.

Reuse plan 05's proven path verbatim:

- The `LeanKernel` (mirroring `AilangKernel`) holds `session.teachPromptSeen`; the **first** `lean` authoring attempt in a session attaches the guide via `metadata.lean.teachPrompt` **and** prepends it to the visible `stdout` (the model reads stdout back, not nested metadata — this is why plan 05 surfaces it in `stdout`, see `kernel-ailang.ts:170`). Subsequent cells omit it. `teachPromptSeen` survives `reset()` (don't re-burn tokens on a source reset).
- The env-server caches the guide for the process lifetime via a `leanAgentPrompt()` provider passed in `makeLeanConfig()` — the direct analogue of `ailangAgentPrompt()` / `ailangCapsCeiling()` wiring in `env-server.ts`. Source: a static `lean4-teach.md` asset shipped in the repo (concise: tactic-mode basics, `by`/`:=`, common tactics `omega`/`simp`/`decide`/`rfl`/`induction`, "Lean 4 not Lean 3" pitfalls, and the honesty note that `sorry`/`native_decide` are not real proofs).
- `prompts.ail` keeps a short standing instruction: "Before writing `language:\"lean\"` cells, read the one-time Lean 4 guide attached to your first `lean` cell result; do not guess Lean syntax, and never call a result 'proved' unless `metadata.lean.proof` is exactly `verified`."

**Acceptance:** in an end-to-end session the full Lean guide appears at most once before the first `lean` cell; later `lean` cells in the same session do not duplicate it; after compaction/resume the model still has the short reminder and can ask for the guide again.

## Architecture

```
LLM ── "eval" tool ──▶ motoko_ext_eval
                          │ httpPost POST /exec-cell  (and v2 exec_cell_ws path)
                                          ▼
                                   env-server (Bun)
                                          │ EvalKernelRegistry  key = "lean:<sessionId>"
                                          ▼
                                   LeanKernel  ── owns a long-lived `repl` child ──┐
                                          │ JSON over stdin/stdout                  │
                                          ▼                                          │
                              { messages, sorries, env }  ◀───────────────────────┘
                                          │
                              LeanSession: committedEnv id, accepted decl names,
                                           teachPromptSeen, lastGoodReplay (fallback)
```

`LeanSession` (the CLI-free core, in `lean-session.ts` — unit-testable with **no Lean installed**, mirroring `ailang-session.ts`):

```ts
type LeanSession = {
  committedEnv: number | null;   // repl env id of last accepted cell; null = fresh
  acceptedNames: string[];       // top-level def/theorem names committed so far
  teachPromptSeen: boolean;
  mathlib: boolean;              // toolchain selected for this session
  createdAt: number;
  lastUsed: number;
};
```

Per-cell flow (the gate logic lives in `lean-session.ts`; process I/O in `kernel-lean.ts`):

1. If `reset` (or `mathlib` changed), reset the session and respawn the repl on the right toolchain.
2. Send `{ "cmd": <cell.code>, "env": session.committedEnv ?? <base> }` to the repl with a per-cell timeout (hard-kill the child on timeout).
3. Read the reply `{ messages, sorries, env }`. **Elaboration status** from `messages` severity: any `error` → `failed`; otherwise `passed` (warnings, incl. `sorry`, are not elaboration failures).
4. **Proof verdict** per theorem declared in the cell: for each theorem name, send `{ "cmd": "#print axioms <name>", "env": <new env> }` and parse the axiom list. Map (see Status mapping below).
5. `decideCommit(...)` (port of `ailang-session.ts:decideCommit`) decides whether to advance `session.committedEnv` to the new env, given elaboration status, proof verdict, and `prove` mode.
6. On commit, advance `committedEnv`, record new decl names. On non-commit, leave `committedEnv` untouched (the freshly-minted env is simply abandoned in repl memory).

Key semantic match to plan 05: **a failed Lean cell does not mutate committed session state** — here that means the committed env pointer does not advance.

### Status mapping (the only genuinely Lean-specific part)

```ts
type LeanElabStatus = "passed" | "failed" | "error";
type LeanProofStatus =
  | "verified"        // elaborated, 0 sorries, axioms ⊆ {propext, Classical.choice, Quot.sound}
  | "sorry"           // declaration uses 'sorry'/'admit', or sorries[] non-empty, or sorryAx present
  | "axiom_tainted"   // clean of sorry but axioms include something outside the standard set
  | "failed"          // a theorem failed to elaborate
  | "skipped"         // no theorem/lemma in the cell — nothing to prove
  | "error";          // repl/process error, unparseable reply
```

Standard allowed axiom set: `{ propext, Classical.choice, Quot.sound }`. Flag and surface anything else (notably `sorryAx`, `Lean.ofReduceBool` / `Lean.trustCompiler` from `native_decide` / `#eval`-backed proofs). A cell with no theorem is `proof:"skipped"`, exactly like `ail` `verify:"skipped"` when no `requires`/`ensures` are present. Conservative default: anything we are not certain proves the theorem is **not** `verified` (port the spirit of `mapFnVerify` / `aggregateVerify`).

---

## Phase 0 — measure the repl contract (no product code)

**Files:** notes only → `.agent/plans/omp-style-python-eval/06-phase0-lean-smoke-notes.md` (the analogue of `05-phase0-smoke-notes.md`), recording exact commands + captured JSON so the Lean-without-Mathlib vs Mathlib vs Dafny decision rests on measured facts.

Spike, mirroring the plan-05 AILANG smoke:

1. **Install path:** `elan` (toolchain manager) → pin a Lean version → `lake` → clone & build `leanprover-community/repl` → confirm the exact launch command (`lake exe repl`, or running the built binary under the right `LEAN_PATH`). Record cold-vs-warm startup time.
2. **JSON shapes:** capture a real `{ "cmd": "..." }` request and the `{ messages, sorries, env }` reply. Note message `severity` values (`error`/`warning`/`info`) and the precise text Lean prints for `sorry` (`declaration uses 'sorry'`).
3. **Env-threading:** prove a `theorem` in command 1 (capture its `env`), then *use* it in command 2 via `{"cmd": "...", "env": <id>}`. Confirm a deliberately broken command 3 returns an `error` message and whether it still mints an env id (decides exactly what the commit gate abandons).
4. **Honesty signals:** confirm `sorries[]` is populated for a `sorry` proof; capture `#print axioms <thm>` output for (a) a clean `omega`/`decide` proof, (b) a `sorry` proof (expect `sorryAx`), and (c) a `native_decide` proof (expect `Lean.ofReduceBool`/trust axiom). This is what makes `verified` honest.
5. **Latency:** cold vs warm, with and without Mathlib.

**Acceptance:** a clean `theorem ... := by omega` reports zero sorries and standard-only axioms; a `:= by sorry` proof is detectable from *both* `sorries[]` and `#print axioms`; env-threading lets cell 2 reference cell 1's theorem; commands run deterministically with captured JSON.

---

## Phase 1 — persistent Lean session registry + repl process kernel

**Files (new):** `src/tui/src/eval/lean-session.ts` (CLI-free: env-threading state, status mapping, commit gate — unit-testable without Lean), `src/tui/src/eval/kernel-lean.ts` (owns the `repl` child process: spawn, JSON request/response, timeout+kill, `close()`).
**Files (modified):** `src/tui/src/eval/frames.ts`, `src/tui/src/eval/registry.ts`, `src/tui/src/env-server.ts`, the WebSocket eval channel.

- Extend `EvalLanguage` in `frames.ts:1` to `"py" | "js" | "ail" | "lean"`.
- `normalizeEvalCells` (`env-server.ts:431`): accept `"lean"` in the language guard at `:436` (the error string at `:437` becomes `expected "py", "js", "ail", or "lean"`); in a `language === "lean"` branch set `prove` (via a `normalizeLeanProve` helper modeled on `normalizeAilangVerify`, `env-server.ts:420`) and `mathlib`. Never coerce unknowns to Python.
- `registry.ts`: add a `{ language: "lean"; kernel: LeanKernel; lastUsed }` `RegistryEntry`; add a `makeLeanConfig` constructor arg; route `"lean"` to `new LeanKernel(...)` in `get()`; in `runCell` call the lean kernel. **Reuse the existing idle eviction and `close()` path** — unlike `AilangKernel.close()` (a no-op), `LeanKernel.close()` **must kill the repl child**. Like `ail`, handle `reset` inside the kernel (so `teachPromptSeen` survives), so add `"lean"` to the `cell.reset && cell.language !== "ail"` guard at `registry.ts:69` (i.e. `!== "ail" && !== "lean"`).
- `env-server.ts`: add a `makeLeanConfig()` to the `new EvalKernelRegistry(...)` call (`env-server.ts:753`), supplying the repl launch command/toolchain path, the `leanAgentPrompt()` provider (cached like `ailangAgentPrompt()` at `:739`), and a `mathlibToolchain` resolver. No caps ceiling needed (Lean doesn't execute effects).
- **Process management:** the repl is one child per session. Send newline-delimited JSON; read replies with a length/heuristic framing confirmed in Phase 0. Enforce the per-cell timeout with a hard `kill`; on death, mark the cell `proof:"error"` and reset the session so the next cell respawns. Optionally keep a `lastGoodReplay` (concatenated accepted source) so a crashed session can be rebuilt — or just reset (Open question).

**Acceptance:** cell 1 proves a theorem and commits; cell 2 references it through the threaded env and elaborates; a broken cell 3 fails without advancing the committed env or losing cells 1–2; `reset:true` clears the session and respawns the repl; `close()` leaves no zombie repl process.

**Teach-prompt acceptance:** the first `lean` attempt records the guide was surfaced (in `stdout` + `metadata.lean.teachPrompt`); the second `lean` attempt in the same session does not repeat it.

---

## Phase 2 — proof honesty gate and result model

**Files:** `src/tui/src/eval/frames.ts`, `src/tui/src/eval/lean-session.ts`, `src/tui/src/eval/kernel-lean.ts`, `src/tui/src/ui.ts`.

Add Lean metadata to `frames.ts` alongside `AilangCellMetadata`, and widen `EvalCellResult.metadata`:

```ts
type LeanCellMetadata = {
  elaborated: LeanElabStatus;          // did the cell elaborate
  proof: LeanProofStatus;              // honest verdict over the cell's theorems
  committed: boolean;                  // did the committed env advance
  theorems?: Array<{ name: string; status: LeanProofStatus; axioms?: string[] }>;
  sorries?: number;
  unexpectedAxioms?: string[];         // axioms beyond the standard set (drives axiom_tainted)
  teachPrompt?: string;                // one-time, first lean cell only
  notice?: string;                     // human-readable status/guidance
};

// EvalCellResult.metadata becomes: { ailang?: AilangCellMetadata; lean?: LeanCellMetadata }
```

Proof/commit policy (port `decideCommit` from `ailang-session.ts`):

- `prove:"off"` ⇒ commit on elaboration success; report `proof` for information only.
- `prove:"auto"` (default) ⇒ commit on elaboration success; do **not** block on `sorry`/`axiom_tainted`/`skipped` (we could not fully prove, but did not disprove). A theorem that fails to *elaborate* is an elaboration failure, which blocks commit regardless.
- `prove:"required"` ⇒ commit only if every theorem in the cell is `verified` (clean axioms, zero sorries); otherwise no commit and the env does not advance.
- `elaborated:"failed"|"error"` ⇒ never commit (port the `check !== "passed"` short-circuit).

As in plan 05, also emit a human-readable `display {type:"status"}` line (reuse the `statusSummary` shape from `kernel-ailang.ts:69`) so the fallback stdout path stays useful; `metadata.lean` is the source of truth for the card and tests. The transcript must **never** print "proved"/"verified" for `sorry`, `axiom_tainted`, `skipped`, or `error`.

**Acceptance:** the response distinguishes an elaboration error from an unproved theorem; a `sorry` proof is reported as `proof:"sorry"` (never committed under `required`); a `native_decide` proof surfaces its trust axiom as `axiom_tainted`; `metadata.lean` survives the eval-card wire; the transcript never overclaims.

---

## Phase 3 — route integration

**Files:** `src/tui/src/env-server.ts`, the WebSocket eval channel, `src/core/env_client.ail`, `src/core/types.ail`, `src/core/agent_loop_v2.ail`, `packages/motoko_eval/eval.ail`.

Extend the existing `/exec-cell` route (and the v2 `exec_cell_ws` direct path in `agent_loop_v2.ail`) to accept `language:"lean"` alongside `py`/`js`/`ail`. Do **not** add a separate `/exec-lean` route — that would fork the eval-card metadata path and the v2/WebSocket dispatch, exactly the divergence plan 05 warns about. Both the HTTP fallback and the v2 WebSocket path must route `lean` cells through `LeanKernel`, or behavior diverges by runtime mode.

Request shape (additive):

```json
{ "cells": [ { "language": "lean", "code": "...", "title": "...", "timeout": 30,
               "reset": false, "prove": "auto", "mathlib": false } ],
  "sessionId": "..." }
```

Response stays the plan-01/03 `CellExecResult` shape with `metadata.lean` per cell.

**Acceptance:** a mixed request runs py/js cells, `ail` cells, and `lean` cells through their respective runners without changing the TUI wire type; the v2 WebSocket path and the HTTP path produce identical `lean` results.

---

## Phase 4 — extension schema, prompt, and policy

**Files:** `packages/motoko_eval/types.ail`, `packages/motoko_eval/eval.ail`, `packages/motoko_eval/prompts.ail`.

- `types.ail`: add `"lean"` to the `language` enum; add `prove` (`enum ["auto","required","off"]`) and `mathlib` (boolean) with descriptions, mirroring how `verify`/`run`/`entry`/`caps` were added for `ail`.
- `prompts.ail`: add guidance distinguishing the three verified-ish lanes — **use `ail`** for typed pure functions + SMT contracts (decidable arithmetic), **use `lean`** for arbitrary theorems / inductive proofs / mathematical propositions, **use py/js** for scripting and data work. Include the **proof caveat**: a Lean result is proved **only** when `metadata.lean.proof` is exactly `verified`; `sorry`, `axiom_tainted`, `skipped`, `failed`, `error` are not proofs. Add the one-time Lean-4 teaching-guide instruction.
- `on_tool_policy`: Lean cells **execute no effects** (no caps/FS/Process), so they are pure static reasoning. This means restricted/read-only profiles can permit `lean` (and check-only `ail`) more liberally than py/js — gate on inspecting the `cells` argument, as plan 05's Phase 4 already requires for `ail`. Keep Lean at least as strict as py/js by default, but allow profiles to opt into "proving allowed, execution denied."

**Acceptance:** the tool description makes proof-overclaim hard; a read-only profile can allow Lean proving while denying py/js execution.

---

## Phase 5 — TUI rendering

**Files:** `src/tui/src/ui.ts`, `src/tui/src/ui.tool-render.test.ts`, `src/tui/src/eval/frames.ts`.

Reuse the plan-03/04 eval card. Lean cells render with extra status lines:

- Header: `✓ [i/N] title (elaborated · verified · 120ms)` / `✗ ... (sorry)` / `⚠ ... (axiom-tainted)`.
- Source: a Lean highlighter. `ui.ts` already has `highlightCodeLines(code, lang)` with an `ail`/`ailang` branch (`ui.ts:616`) and a `DiffInnerLang` union (`ui.ts:59`); add a `lean` branch (a minimal keyword/tactic highlighter, or plain passthrough for MVP).
- Output sections: `Elaboration` (errors/warnings), `Proof` (per-theorem status + any unexpected axioms), `#eval` output (from repl messages).
- **Blocker (same class as plan 05):** `normalizeEvalCellResult()` in `ui.ts` must accept `language:"lean"` and preserve `metadata.lean` (plan 05 fixed the identical issue for `ail`). Without this, a `lean` `eval_result` is silently dropped.

**Acceptance:** a `sorry`/`axiom_tainted` proof is visible in the collapsed preview; a clean `verified` theorem shows a concise status without dumping raw repl JSON.

---

## Phase 6 — tests & verification

- **TS unit (`lean-session.ts`, no Lean needed):** env-threading commit/non-commit; `decideCommit` across `off`/`auto`/`required`; status mapping for verified / sorry / axiom_tainted / failed / skipped / error; `#print axioms` parsing (standard set vs `sorryAx` vs `Lean.ofReduceBool`).
- **Normalization regression:** unknown languages still error; `language:"lean"` survives `/exec-cell`, the WebSocket path, `eval_result` JSON, and TUI parsing; `prove`/`mathlib` normalize correctly.
- **Lean smoke (gated on Lean installed):** a clean `omega` theorem (`verified`, committed), a `sorry` theorem (`sorry`, not committed under `required`), a `native_decide` theorem (`axiom_tainted`), a second cell using the first cell's theorem, a `#eval` cell.
- **Process-management test:** per-cell timeout hard-kills the repl; `close()` leaves no zombie; a crashed repl resets cleanly.
- **Policy smoke:** a read-only profile allows Lean proving and denies py/js execution.
- **Teach-prompt smoke:** fresh session surfaces the Lean guide once before the first `lean` cell; same session does not repeat it.
- **Wire metadata test:** `metadata.lean` survives env-server response → `ToolResultEnvelope.metadata.cells` → `eval_result.cells_json` → `parseEvalCellsJson` (mirror the plan-05 `ailang` wire test).
- **TUI test:** card renders elaboration/proof statuses and unexpected axioms.
- **Regression:** existing py/js and `ail` eval tests stay green.

Manual E2E:

```text
use eval in Lean to state and prove that addition on Nat is commutative with `by omega`,
require the proof, then in a second cell use that theorem; confirm the card shows "verified"
and that a `:= by sorry` variant is reported as "sorry", not proved.
```

Expected: cell 1 elaborated + verified + committed; cell 2 elaborated using the threaded env; the `sorry` variant reported `proof:"sorry"`, not committed, never called "proved."

---

## Phase 7 (optional) — extract the shared verified-eval kernel

Per the design note in [02-additional-evaluators](../../research/omp-style-python-eval/02-additional-evaluators.md): with **two** verifier backends now in the tree (`ail` + `lean`), factor the shared shape out of `kernel-ailang.ts`/`ailang-session.ts` and `kernel-lean.ts`/`lean-session.ts`:

- a `VerifiedSession` interface (accumulate / render-or-thread / commit / reset / `teachPromptSeen`),
- a `VerifierKernel` interface (`run(cell) -> { check/elaborate, verify/proof, committed, ran, units, notice, teachPrompt }`),
- per-backend **status mapping** and **teach prompt** as the only language-specific parts.

The TUI status lines, env-server normalization, teach-prompt surfacing, idle eviction, and proof-caveat wording are already backend-agnostic. Do this **after** both backends are green, not before — premature abstraction would couple a stateless re-render model (`ail`) to a live-process env-threading model (`lean`) before their real differences are settled.

---

## Sequencing & risks

1. Phase 0 first — never build against an assumed repl JSON shape.
2. Phase 1 session + process kernel.
3. Phase 2 proof honesty gate + result model.
4. Phase 3 route integration (HTTP + v2 WebSocket).
5. Phase 4 schema/prompt/policy.
6. Phase 5 card/highlighter/transcript.
7. Phase 6 tests + E2E. Phase 7 optional shared-interface extraction.

Risks:

- **Proof dishonesty** — the central risk. `sorry`/`admit` "succeed," custom `axiom`s assume anything, and `native_decide`/`#eval`-backed proofs add compiler-trust axioms (`Lean.ofReduceBool`). Mitigate with the two-signal rule (`sorries[]` **and** `#print axioms`) and a conservative default (`verified` only when proven clean).
- **Repl process management** — hangs on malformed input, zombie children, memory growth (the repl retains every env in memory over a long session). Mitigate: per-cell timeout + hard kill, `close()` teardown via the registry, idle eviction, and `reset` to drop accumulated envs.
- **Mathlib weight/latency** — multi-GB caches, seconds-plus elaboration. Mitigate: Lean-without-Mathlib default; Mathlib opt-in and pre-warmed.
- **Lean 3 vs 4 drift** — models emit Lean 3 tactics/syntax. Mitigate: the one-time Lean-4 teaching guide + honest error surfacing.
- **Env-threading vs source replay** — committed env lives in process memory; a crash loses the session. Mitigate: reset cleanly (MVP) or replay `lastGoodReplay` (follow-up); pickling is out of scope.
- **Runtime-path drift** — the v2 direct `exec_cell_ws` path can bypass package `on_tool_handle`; keep HTTP, WS, and extension dispatch under the same tests (same lesson as plan 05).
- **Determinism** — `Date.now()`-style nondeterminism and unbounded `#eval` must be timeout-bounded; Lean elaboration itself is deterministic.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| 1 | Add `language:"lean"` to `eval` or a separate `lean_eval` tool? | Add to `eval` — reuse the card, registry, WS path, and teach-prompt mechanism, exactly as `ail` did. |
| 2 | Persistence: env-id threading vs source re-render (like `ail`)? | Env-threading — it's the repl's native model and avoids re-elaborating prior cells. Keep an optional `lastGoodReplay` for crash recovery. |
| 3 | What counts as `verified`? | Elaborated + zero sorries (`sorries[]` empty, no `uses 'sorry'`) + `#print axioms` ⊆ `{propext, Classical.choice, Quot.sound}`. Everything else is reported honestly. |
| 4 | How is `native_decide` treated? | `axiom_tainted` (surfaces `Lean.ofReduceBool`); proved-modulo-compiler-trust, not `verified`. Document the distinction in the prompt. |
| 5 | Mathlib in MVP? | No. Default Lean-without-Mathlib; `mathlib:true` opt-in, pre-warmed, session-scoped (changing it ⇒ reset). |
| 6 | Where does the teach prompt come from (no upstream CLI prompt)? | Ship a static `lean4-teach.md` asset; surface once via the plan-05 mechanism. |
| 7 | Install Lean by default? | No — Lean (`elan`/`lake`/`repl`) is heavy; gate behind a flag in `scripts/install-prerequisites.sh`, like Rust/omnigraph. |
| 8 | Extract the shared `VerifiedSession`/`VerifierKernel` now? | After both backends are green (Phase 7), not before. |
