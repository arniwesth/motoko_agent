# Handoff: implement plan 06 persistent verified Lean 4 eval

You are implementing [06-lean4-eval.md](./06-lean4-eval.md). Read that plan in full first — this handoff is the operational checklist, the plan is the rationale.

## Objective

Add `language:"lean"` support to the existing `eval` tool as a persistent, **proof-verified** Lean 4 scratchpad. Where `ail` cells type-check pure functions and prove SMT contracts, `lean` cells **prove arbitrary theorems**.

Lean is a **hybrid** of the two kernel styles already in the tree:

- Like py/js (`kernel-py.ts`, `kernel-js.ts`), it drives a **long-lived child process** — the `leanprover-community/repl`, JSON-over-stdio. The registry already owns spawn / idle-eviction / `close()` for this kind of kernel.
- Like `ail` (`kernel-ailang.ts`, `ailang-session.ts`), it is **verified-commit-gated** — each cell elaborates against the previous state, and only a clean cell advances the committed state.

Persistence is **env-id threading**, not source re-rendering: the repl returns an `env` integer that you thread into the next command. This is strictly cheaper than `ail`'s re-render-and-recheck model — prior cells are never re-elaborated.

## Current facts to verify first (Phase 0 — do this before any product code)

There is **no installed Lean toolchain assumed**. Spike it and record results in `06-phase0-lean-smoke-notes.md` (the analogue of `05-phase0-smoke-notes.md`). Do not implement against assumed JSON shapes.

1. **Install path:** `elan` (toolchain manager) → pin a Lean version → `lake` → clone & build `leanprover-community/repl` → confirm the exact launch command (`lake exe repl`, or the built binary under the right `LEAN_PATH`). Record cold-vs-warm startup time.
2. **JSON shapes:** capture a real `{ "cmd": "..." }` request and the `{ messages, sorries, env }` reply. Record message `severity` values (`error`/`warning`/`info`) and the exact text for a `sorry` (`declaration uses 'sorry'`).
3. **Env-threading:** prove a `theorem` in command 1 (capture its `env`), use it in command 2 via `{"cmd": "...", "env": <id>}`. **Critically:** send a deliberately broken command 3 and record whether it still mints an env id — this decides exactly what the commit gate abandons. Note: the **first** command must omit the `env` field entirely (it *creates* env 0; there is no pre-existing base env).
4. **Honesty signals:** capture `#print axioms <thm>` output for (a) a clean `omega`/`decide` proof, (b) a `sorry` proof (expect `sorryAx`), (c) a `native_decide` proof (expect a compiler-trust axiom — record its **exact** name, likely `Lean.ofReduceBool`; do not assume names). Confirm `sorries[]` is populated for a `sorry` proof.
5. **Toolchain/project layout:** confirm the repl launches from inside a Lake project whose lakefile pins the toolchain. Confirm **Mathlib is a project dependency, not a runtime flag** — the Mathlib-enabled session needs a *separate* pre-built Lake project (Mathlib fetched via `lake exe cache get`). Record both layouts so the `mathlibToolchain` resolver is concrete.
6. **`#eval` effect surface:** confirm `#eval (e : IO α)` performs real IO inside the repl (it does), and that the spawned child respects a workdir/network sandbox. This decides the confinement posture.
7. **Latency:** cold vs warm, with and without Mathlib.

**Phase 0 acceptance:** a clean `theorem ... := by omega` reports zero sorries and standard-only axioms; a `:= by sorry` proof is detectable from *both* `sorries[]` and `#print axioms`; env-threading lets cell 2 reference cell 1's theorem; an `#eval` IO action runs under the sandbox; commands are deterministic with captured JSON.

## Key semantic decisions

- Use existing `eval` with `language:"lean"`. Do **not** create a separate `lean_eval` tool or `/exec-lean` route — that forks the eval-card metadata path and the v2/WebSocket dispatch.
- Persistence = the committed **env id**, not source. A failed cell does not advance `committedEnv`.
- A cell can use declarations from earlier committed cells via the threaded env.
- **No `duplicateNames` pre-check** (unlike `ail`): the threaded env already holds accepted names, so a redeclaration fails elaboration *in the repl* with a native `'foo' has already been declared` error. Treat that as an elaboration failure → no commit.
- **`#eval` is an effect hatch.** `#eval (e : IO α)` performs real IO (file reads, `IO.Process.run`). The repl child is therefore a privileged effect surface, **not** a pure prover. Run it under the same workdir/network confinement as py/js (`AILANG_FS_SANDBOX=workdir`, network off by default). This is mandatory, not optional.
- **Proof honesty is the central discipline.** `proof:"verified"` requires three things together: elaborated, **zero sorries** (`sorries[]` empty *and* no `declaration uses 'sorry'` message), **and** `#print axioms` containing nothing beyond `{propext, Classical.choice, Quot.sound}`. Anything else maps to `sorry` / `axiom_tainted` / `failed` / `skipped` / `error` and is **never** reported as proved.
- **Named theorems only for a full verdict.** `#print axioms` needs a name; an anonymous `example` cannot be axiom-audited (and an `example` hiding a custom `axiom` evades detection entirely). An `example` caps at "no sorry detected," surfaced honestly — never `verified`. Tell the model (in the teach guide) to use named `theorem`/`lemma` when it wants a machine-checkable proof.
- Unknown eval languages must produce explicit errors (the plan-05 rule). Do not coerce unknown languages to Python.

## Per-cell flow (the contract `lean-session.ts` must implement)

1. If `reset` (or `mathlib` changed), reset the session and respawn the repl on the right toolchain.
2. Parse the cell source for top-level decl **names + kinds** (`theorem`/`lemma` = provable, `def`/`abbrev`/`instance` = not a proof, `example` = provable-but-unnameable) via a `parseLeanCell` helper modeled on `ailang-session.ts:parseCell`/`declName`. These names drive the axiom check.
3. Send `{ "cmd": <cell.code>, "env": committedEnv }` (omit `env` when `committedEnv` is `null`), with a per-cell timeout that **hard-kills** the child on expiry.
4. Read `{ messages, sorries, env }`. **Elaboration status:** any `error`-severity message → `failed`; otherwise `passed` (warnings, including `sorry`, are not elaboration failures).
5. **Proof verdict:** send one batched `{ "cmd": "#print axioms a\n#print axioms b\n...", "env": <new env> }` for the cell's named theorems; parse per-name axiom lists from the `info` messages. Anonymous `example`s → rely on `sorries`/`uses 'sorry'` only.
6. `decideCommit(...)` (port of `ailang-session.ts:decideCommit`) decides whether to advance `committedEnv` to **step 3's** env, given elaboration status, proof verdict, and `prove` mode.
7. On commit: advance `committedEnv`, record new decl names. On non-commit: leave `committedEnv` untouched (the minted env is abandoned in repl memory).

## Main files

Read before editing:

- `src/tui/src/eval/frames.ts`
- `src/tui/src/eval/registry.ts`
- `src/tui/src/eval/kernel-ailang.ts` and `src/tui/src/eval/ailang-session.ts` (your closest templates — mirror their split: CLI-free core + process driver)
- `src/tui/src/env-server.ts` (look at `normalizeEvalCells`, `normalizeAilangVerify`, `ailangAgentPrompt`/`ailangCapsCeiling`, and the `new EvalKernelRegistry(...)` wiring ~line 753)
- the WebSocket eval channel
- `src/tui/src/ui.ts` (`normalizeEvalCellResult`, `highlightCodeLines`, the `ail`/`ailang` highlighter branch ~line 616, `DiffInnerLang` ~line 59)
- `src/tui/src/ui.tool-render.test.ts`
- `src/core/env_client.ail`, `src/core/types.ail`, `src/core/agent_loop_v2.ail`
- `packages/motoko_eval/types.ail`, `packages/motoko_eval/eval.ail`, `packages/motoko_eval/prompts.ail`

New files to create:

- `src/tui/src/eval/lean-session.ts` — CLI-free core (env-threading state, `parseLeanCell`, status mapping, `decideCommit`). **Unit-testable with no Lean installed.**
- `src/tui/src/eval/kernel-lean.ts` — owns the `repl` child (spawn under sandbox, JSON request/response, timeout+kill, `close()` that **kills the child** — unlike `AilangKernel.close()` which is a no-op).
- a static `lean4-teach.md` asset (the one-time teaching guide).

Blockers the plan calls out (same class as plan 05):

- `EvalLanguage` is `"py" | "js" | "ail"` — extend to add `"lean"`.
- `normalizeEvalCells()` language guard (`env-server.ts:436`) rejects anything but py/js/ail — add `"lean"` and a `normalizeLeanProve` helper (modeled on `normalizeAilangVerify`).
- `EvalKernelRegistry` routes py/js/ail only — add a `lean` `RegistryEntry`, a `makeLeanConfig` arg, and `"lean"` routing. Add `"lean"` to the `cell.reset && cell.language !== "ail"` guard (`registry.ts:69`) so reset is handled inside the kernel (preserving `teachPromptSeen`).
- `normalizeEvalCellResult()` in `ui.ts` drops result cells whose language isn't py/js/ail — add `"lean"` and preserve `metadata.lean`.
- `agent_loop_v2.ail` special-cases `eval` and calls `exec_cell_ws(...)` directly — both HTTP and WS paths need `lean` coverage.
- `packages/motoko_eval` schema/prompt advertise py/js/ail only.

## Implementation shape

1. **Phase 0 spike** — see "Current facts" above. Output `06-phase0-lean-smoke-notes.md`.
2. **Types & normalization** — extend `EvalLanguage`; add `prove` (`"auto" | "required" | "off"`) and `mathlib` (boolean) to `EvalCell`; add `LeanCellMetadata` to `frames.ts`; widen `EvalCellResult.metadata` to `{ ailang?: ...; lean?: LeanCellMetadata }`.
3. **Lean session + process kernel** — `lean-session.ts` + `kernel-lean.ts` per the per-cell flow. Process management: one repl child per session, newline-delimited JSON, per-cell timeout + hard kill; on death mark `proof:"error"` and reset so the next cell respawns. Optional `lastGoodReplay` (retain accepted-cell source) for crash recovery, or just reset (open question).
4. **Proof/commit policy** — port `decideCommit`:
   - `off` ⇒ commit on elaboration success; report `proof` informationally.
   - `auto` (default) ⇒ commit on elaboration success; do **not** block on `sorry`/`axiom_tainted`/`skipped`; an elaboration *failure* always blocks. (Lean has no "counterexample" — a failed proof attempt is unproven, not a disproof.)
   - `required` ⇒ commit only if every named theorem is `verified`.
   - `elaborated` `failed`/`error` ⇒ never commit.
   Status sets: `elaborated: passed | failed | error`; `proof: verified | sorry | axiom_tainted | failed | skipped | error`. Emit a human-readable `display {type:"status"}` line (reuse the `statusSummary` shape from `kernel-ailang.ts:69`).
5. **Routing** — extend `/exec-cell` (no new route); make the WS path and v2 `exec_cell_ws` use the same normalization + runner as HTTP.
6. **Extension schema/prompt/policy** — `types.ail`: add `"lean"` to the enum + `prove`/`mathlib`. `prompts.ail`: ail-vs-lean-vs-py/js selection advice, the proof caveat, the one-time teach-guide instruction. `on_tool_policy`: treat `lean` at least as strictly as py/js by default; a "proving allowed, execution denied" profile rejects cells containing `#eval`/`#exit`/`run_cmd` via a **best-effort source guard** (the sandbox, not the guard, is the real boundary).
7. **TUI** — accept `language:"lean"` in `normalizeEvalCellResult`; preserve `metadata.lean`; render `Elaboration` / `Proof` (with unexpected axioms) / `#eval` sections; add a `lean` highlighter branch (minimal keywords/tactics, or plain passthrough for MVP).
8. **Phase 7 (optional, defer)** — only after both `ail` and `lean` are green, extract a shared `VerifiedSession`/`VerifierKernel` interface. Do not abstract prematurely.

## Tests required

- **TS unit (`lean-session.ts`, no Lean needed):** env-threading commit/non-commit; `decideCommit` across `off`/`auto`/`required`; status mapping (verified / sorry / axiom_tainted / failed / skipped / error); `#print axioms` parsing (standard set vs `sorryAx` vs the native_decide axiom); `parseLeanCell` name/kind extraction.
- **Anonymous-`example` honesty:** `example := by sorry` caught via `sorries`/`uses 'sorry'` and never graded `verified`; named `theorem := by sorry` additionally caught via `#print axioms`.
- **Normalization regression:** unknown languages still error; `language:"lean"` survives HTTP `/exec-cell`, WS path, `eval_result.cells_json`, and TUI parsing; `prove`/`mathlib` normalize.
- **Wire metadata:** `metadata.lean` survives env-server response → `ToolResultEnvelope.metadata.cells` → `eval_result.cells_json` → `parseEvalCellsJson`.
- **Lean smoke (gated on Lean installed):** clean `omega` theorem (`verified`, committed); `sorry` theorem (`sorry`, not committed under `required`); `native_decide` theorem (`axiom_tainted`); second cell using the first's theorem; an `#eval` cell.
- **Process-management:** per-cell timeout hard-kills the repl; `close()` leaves no zombie; a crashed repl resets cleanly.
- **Effect-confinement:** an `#eval` IO file action is confined to the workdir; a network `#eval` is blocked by default.
- **Teach-prompt:** fresh session surfaces the Lean guide once before the first `lean` cell; same session does not repeat it.
- **Policy:** the "proving allowed, execution denied" profile permits a proof-only cell and rejects an `#eval` cell; default profiles treat `lean` at least as strictly as py/js.
- **TUI:** card renders elaboration/proof statuses and unexpected axioms.
- **Regression:** existing py/js and `ail` eval tests stay green.

Manual E2E target:

```text
use eval in Lean to state and prove that addition on Nat is commutative with `by omega`,
require the proof, then in a second cell use that theorem; confirm the card shows "verified"
and that a `:= by sorry` variant is reported as "sorry", not proved.
```

Expected: Lean teach guide appears once before authoring; cell 1 elaborated + verified + committed; cell 2 elaborated using the threaded env; the `sorry` variant `proof:"sorry"`, not committed, never called "proved"; no py/js/ail kernel involvement.

## Be careful

- **Never report `verified` unless all three signals are clean** (elaborated, zero sorries, clean axioms). `sorry`, `axiom_tainted`, `skipped`, `failed`, `error` are not proofs.
- **`native_decide` is `axiom_tainted`, not `verified`** — it adds a compiler-trust axiom. Surface it.
- **Anonymous `example`s can't be axiom-audited** — never grade one `verified`; require named theorems for a full verdict.
- **`#eval` runs real IO** — the repl child must run sandboxed; do not treat Lean as effect-free.
- **The first repl command omits `env`** — `env: null`/`<base>` is wrong.
- **One bad `#eval` can hang the child** — enforce the timeout with a hard kill, and accept that a kill drops the in-memory session (mitigate with `lastGoodReplay` or reset).
- **Don't add a second route** — extend `/exec-cell`; cover the v2 direct `exec_cell_ws` path too, not just package `on_tool_handle`.
- **Don't put the full teach guide in every prompt** — surface it once per session in the *visible* stdout (see `kernel-ailang.ts:170`), not just nested metadata.
- **Don't mutate committed session state after a failed cell** — `committedEnv` only advances on a clean commit.
- **Default Lean-without-Mathlib** — Mathlib is a separate pre-built project, opt-in, and not installed by default (gate it in `scripts/install-prerequisites.sh` like Rust/omnigraph).
