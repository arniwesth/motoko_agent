# Plan: `eval` MVP — persistent Python + JS kernels with local loopback (Design C)

Implements **[ADR-001](../../research/omp-style-python-eval/ADR-001-eval-mvp-local-loopback.md)**.
Design source: [`00-design.md`](../../research/omp-style-python-eval/00-design.md).
Reference impl: `oh-my-pi/packages/coding-agent/src/eval/`.
Toolchain: AILANG v0.19.1 (`ailang.lock`), Bun 1.3.x.

## Background

We are porting oh-my-pi's `eval` tool — persistent Python + JS cells that can call back into the agent's own tools mid-cell — into Motoko. AILANG cannot host a persistent bidirectional REPL (ADR-001 §Context), so the kernels live in the **Bun env-server** and `eval` is a Motoko extension that **delegates** to it over blocking `httpPost`, exactly as `exa_search` and the core bash/AILANG tools already delegate via `env_client.ail`. In this MVP the in-cell tool loopback (`tool.read/write/search`, `agent()`) is served **locally inside the env-server** — no re-entrancy, no deadlock. The faithful re-entrant variant is [ADR-002](../../research/omp-style-python-eval/ADR-002-eval-reentrant-websocket-loopback.md) / [plan 02](./02-design-b-prime-reentrant-websocket.md).

## Goals

- A new `eval` tool the LLM can call with one or more `cells` (`{language: "py"|"js", code, title?, timeout?, reset?}`).
- Persistent per-session Python and Bun-JS kernels in the env-server; state survives across cells **and** across separate `eval` tool calls in a session.
- `display()`, image, and JSON capture; stdout/stderr streaming; per-cell timeout; cancellation; idle kernel cleanup.
- In-cell `tool.read/write/search` (fs/ripgrep) and a single-call `agent()` (`callSubagentModel`), served locally by the env-server.
- A **frozen, transport-neutral frame protocol** so promoting to B′ (WebSocket loopback) is a transport+dispatch swap, not a rewrite.
- Fencing: workdir confinement, a network policy, and `on_tool_policy` gating of the `eval` tool itself.

## Non-goals

- **No re-entrant loopback to the brain.** In-cell `tool.*` does not run other extensions' tools and does not honor `on_tool_policy` for in-cell calls (deferred to B′). Stated so a reviewer doesn't expect parity.
- **No `parallel()`/`pipeline()`, no depth-3 recursion cap, no spawn-policy** — `agent()` is single-call only (ADR-001 consequence). Additional work if wanted later.
- No ABI change. `motoko_ext_abi` stays at 2.2.0; `on_tool_handle`'s effect row already covers `{Net, Process, FS, …}`.
- **No rich TUI rendering.** Results render as a **flattened plain-text transcript** through the existing tool-result path (Phase 5b, "Option A"). The rich expandable eval card is a separate, independently-shippable follow-up — [plan 03](./03-eval-tui-card-rendering.md) — not gated on this plan or B′. Inline images are out of scope in every variant (they need a terminal-image capability that doesn't exist today).

---

## Architecture (recap)

```
LLM ── "eval" tool ──▶ motoko_ext_eval (AILANG extension: schema, policy, on_tool_handle)
                              │ httpPost  POST /exec-cell   (env_client.exec_cell)
                              ▼
                       env-server (Bun)  ── session→kernel registry (python:${id}, js:${id})
                              │ NDJSON over stdin/stdout         ┌──── local loopback ────┐
                              ▼                                   ▼                        │
                    python runner.py  /  Bun Worker  ◀── tool.read()/agent() (HTTP) ──────┘
                                                          served locally in env-server TS
```

Two channels, mirroring oh-my-pi exactly:
1. **Control channel** — NDJSON between env-server and each kernel subprocess (`runner.py` for Python; a Worker for JS).
2. **Loopback channel** — a separate local 127.0.0.1 HTTP endpoint with a bearer token that the kernel calls *synchronously mid-cell*; in C the env-server answers it itself.

---

## Phase 0 — Freeze the frame protocol (do this first; shared with B′)

**Artifact:** `.agent/plans/omp-style-python-eval/frame-protocol.md` (the contract) + a TS module `src/tui/src/eval/frames.ts`.

Define two transport-neutral frame families, decoupled from whether the transport is `httpPost` (C) or WebSocket (B′):

- **Cell-run frames** (env-server ⇄ kernel, NDJSON — port oh-my-pi `runner.py` shapes). The kernel subprocess is already language-specific, so `language` is selected at the `/exec-cell` request level (which kernel to route to), **not** carried in the per-kernel frame:
  `run {id, code, silent?, cwd?, env?}` · `started` · `stdout` · `stderr` · `display {bundle}` · `result {bundle}` · `error {ename, evalue, traceback}` · `done {status, executionCount, cancelled}`.
- **Loopback frames** (kernel → resolver, transport-neutral — this is the C↔B′ seam):
  `tool-request {reqId, tool, arguments}` → `tool-result {reqId, exit_code, stdout, stderr, metadata}`.

In **C**, `tool-request` is resolved by a local env-server handler. In **B′**, the identical `tool-request` is forwarded down the WebSocket to the brain. **Freezing this shape now is the entire reason C→B′ is a swap.** No kernel changes between C and B′.

**Acceptance:** the frame types are a standalone module imported by both the kernel host and the loopback resolver; no transport details leak into them.

---

## Phase 1 — env-server kernel host

**Files (new):** `src/tui/src/eval/kernel-py.ts`, `src/tui/src/eval/kernel-js.ts`, `src/tui/src/eval/runner.py`, `src/tui/src/eval/prelude.py`, `src/tui/src/eval/worker-core.ts`, `src/tui/src/eval/display.ts`.

Near-direct port from oh-my-pi:

- **Python** (`runner.py` + `kernel-py.ts`): port `oh-my-pi/.../eval/py/runner.py` and `py/kernel.ts`. One subprocess per kernel, NDJSON over stdin/stdout, `SIGINT`→`KeyboardInterrupt` for cancel, `{type:"exit"}`→SIGTERM/SIGKILL escalation on shutdown. Self-contained (no IPython); rich display via `_repr_*_` fallback. Cache the runner script to a temp path keyed by content hash (oh-my-pi does this).
- **JS** (`worker-core.ts` + `kernel-js.ts`): port `oh-my-pi/.../eval/js/worker-core.ts`. **Open question (ADR-001/§7-2):** Bun `Worker` (oh-my-pi's choice) vs a `vm` context. *Recommendation:* start with Bun `Worker` to keep the port faithful and the cancellation story (terminate worker) simple; revisit only if the env-server process model objects.
- **`prelude.py` / prelude.ts**: install the in-runtime helpers `display`, `read`/`write`/`append`, `tool.<name>(args)`, `agent(...)`. The `tool`/`agent` proxies make a **blocking** loopback HTTP call (Phase 3).
- **`display.ts`**: capture display/result bundles → `EvalDisplayOutput` (`{type:"json"|"image"|"markdown"|"status"}`), porting oh-my-pi `eval/py/display.ts` + `types.ts`.

**Acceptance:** a unit test drives one kernel directly (no HTTP), runs two cells that share state (`x=1` then `print(x)`), captures stdout, a `display()` JSON bundle, and an image bundle, and cancels a `while True` cell via SIGINT within the escalation window.

---

## Phase 2 — `/exec-cell` route + session→kernel registry

**Files:** `src/tui/src/env-server.ts` (new route, near existing `/exec` at line 941), `src/tui/src/eval/registry.ts` (new).

- `app.post("/exec-cell", …)` accepting `{cells: EvalCell[], sessionId, timeout?}`. For each cell: look up or lazily spawn `python:${sessionId}` / `js:${sessionId}` in the registry; run the cell; aggregate `started…done` frames into one response.
- **Registry** keyed by `${language}:${sessionId}`; persists kernels across requests; idle-eviction timer (close kernel after N minutes idle); `reset:true` on a cell tears down and respawns its kernel.
- **Response body** (matches the env-server's HTTP-200-always convention, like `/exec`): `{exit_code, stdout, cells: EvalCellResult[], images, jsonOutputs, notice?}`. `exit_code != 0` signals cell error.
- **Python availability** (ADR-001/§7-3): probe `python3 -c ...` on first `py` cell; if absent, return a structured `notice` and `exit_code=0` with a clear "python unavailable" message rather than throwing. The install script (`scripts/install-prerequisites.sh`) gains a `python3` check — *track as a follow-up item, not a blocker.*
- **Session id** (ADR-001/§7-4): key off the brain's existing session/state identifier. *Decision for MVP:* use `ctx.state_key` (already on `ExtCtx`) as the `sessionId`; subagents/compose inheriting it to share kernels is **out of scope for C** (revisit with B′).

**Acceptance:** an HTTP test hits `/exec-cell` twice with the same `sessionId` and confirms state persistence across calls; a third call with `reset:true` confirms a fresh kernel.

---

## Phase 3 — local loopback bridge

**Files:** `src/tui/src/eval/loopback.ts` (new), wired into the kernel host.

- A 127.0.0.1 loopback HTTP endpoint with a per-execution bearer token (port oh-my-pi `py/tool-bridge.ts`). The kernel prelude's `tool.<name>()` / `agent()` POST `tool-request` frames here mid-cell.
- **Local resolvers (the fork):**
  - `read`/`write`/`append` → fs, **confined to workdir** (Phase 5).
  - `search` → ripgrep (`rg`) under workdir.
  - `agent(prompt, model?)` → `callSubagentModel` (already in `env-server.ts:600`). **Single-call only.**
- Resolver returns a `tool-result` frame. Gate the resolver to this **fixed allowlist** — do not attempt to mirror `on_tool_policy` in TS (ADR-001 consequence).

**Acceptance:** a cell that does `data = tool.read("README.md"); print(len(data))` returns the file length; `agent("say hi")` returns subagent text; `tool.read("/etc/passwd")` is denied by workdir confinement.

---

## Phase 4 — `motoko_ext_eval` extension

**Files (new package):** scaffold via `ailang init motoko-extension`, then fill in.

```bash
cd ../ailang-packages
ailang init motoko-extension --name sunholo/motoko_ext_eval \
  --tools "eval" --effects "Net,Stream,Process,FS,Env"
```

`Stream` is included even though C only needs `Net` (blocking `httpPost`): the **same package** gains the WebSocket loopback in B′ ([plan 02](./02-design-b-prime-reentrant-websocket.md)), `on_tool_handle`'s ABI effect row already declares `Stream`, and scaffolding it now avoids re-touching the effect annotations later. Matches the design §6 / handover recommendation.

Package layout mirrors `motoko_ext_exa_search/` (`eval.ail`, `prompts.ail`, `register.ail`, `types.ail`). Implement the hooks (others no-op):

- `provided_tools()` → `["eval"]`.
- `on_describe_tools()` → the `cells` schema (mirror oh-my-pi: `cells: EvalCellInput[]`, each `{language, code, title?, timeout?, reset?}`).
- `on_build_system_prompt()` → short usage blurb (persistent state, `display`, `tool.*`, `agent`) + the effect-hatch caveat.
- `on_tool_policy(ctx, call)` → gate `eval`: `Deny` in restricted modes; otherwise `NoOpinion`/`Allow`. **This is the canonical gate** (the in-cell fork has none).
- `on_tool_handle(ctx, call)` → decode `cells`, call `env_client.exec_cell(ctx.env_server_url, …, ctx.state_key)`, map the response into `Handled(ToolResultEnvelope)`; `Delegate` if the tool isn't `eval`.

Wire into `motoko_agent/ailang.toml` (`[dependencies]` + `[extensions].packages`) and run `ailang generate-extension-registry`.

**Acceptance:** `ailang check` clean on the package; `make check_core` clean; the tool appears in `on_describe_tools` output.

---

## Phase 5 — `env_client.exec_cell` + result mapping + fencing

**Files:** `src/core/env_client.ail` (new `exec_cell`), `src/core/types.ail` (new `CellExecResult` if needed).

- `exec_cell(url, cells_json, session_id, timeout_secs) -> CellExecResult ! {Net}` — same shape as `exec_in`/`exec_ailang`: build body with `jo/kv/js/jnum`, `httpPost("${url}/exec-cell")`, `decode`, with a synthetic `exit_code=1` envelope on malformed response.
- Map into `ToolResultEnvelope`: `stdout` = the **pre-rendered plain-text transcript** (Phase 5b — this is what the TUI actually renders), `exit_code` = worst cell exit, `metadata` = structured JSON `{cells, images, jsonOutputs, notice?}`. **Correction to an earlier draft:** `metadata` is retained on the envelope for the model / forward-compat / plan 03's card, but it does **not** drive the TUI — the TUI's wire type `DelegatedResult` (`runtime-process.ts`) has **no `metadata` field**, so the TUI renders `stdout` only (verified: `DelegatedResult = {tool_call_id, stdout, stderr, exit_code, truncated}`).
- **Fencing (cross-cutting, ADR-001 effect-hatch consequence):**
  - **Workdir confinement** enforced in Phase 3 resolvers (path normalization, reject escapes).
  - **Network policy**: env var / config flag controlling whether kernels may reach the network; default deny-with-note for the MVP unless the profile opts in. Document in the package README.
  - **`eval`-tool gate** via `on_tool_policy` (Phase 4).
- **Output limits** (ADR-001/§7-5): *Decision for MVP:* adopt oh-my-pi's caps — 50KB truncation window per cell, 30s default per-cell timeout, artifact spill for oversized output. Cheap to change later.

**Acceptance:** end-to-end via `make run` — an `eval` cell prints, `display()`s JSON, reads a workdir file, and calls `agent()`; result renders in the TUI as a readable flattened transcript (Phase 5b); oversized output truncates at 50KB.

---

## Phase 5b — TUI rendering (Option A: flatten to text, zero TUI changes)

**Files:** `src/tui/src/eval/transcript.ts` (new, env-server side); no changes to `ui.ts` / `runtime-process.ts`.

The TUI renders tool results from `DelegatedResult.stdout` via `ui.ts` → `formatToolDetailLines()` (8-line stdout / 4-line stderr preview, `[truncated]` badge, `... N more (Ctrl+O to collapse)`). There is **no structured-metadata render path** to the TUI today. So for the MVP we pre-render server-side into plain text and ride the existing path with **no `ui.ts` changes**.

- The `/exec-cell` response's `stdout` is a **pre-rendered plain-text transcript** built in `transcript.ts`. Per cell, in order:
  - a header line (`title` / language / cell index),
  - stdout, then stderr,
  - textual renderings of display/result bundles: **JSON** via `JSON.stringify(value, null, 2)`; **markdown** as its raw text; **status events** summarized to one line each.
  - **images**: spilled to `.motoko/artifacts/<session>/cell<N>.<ext>` (gitignored) and represented inline as `[image: <path> (<w>×<h> <mime>)]` — **no inline rendering** (no terminal-image capability exists; see Non-goals).
- **Plain text only** — no ANSI/coloring. Coloring (`highlightJsonLines`, `segmentStreamMarkdown`) would require the TUI to know the row is eval output, which is plan 03's card, not this path.
- Pre-truncate the transcript to the 50KB cap (Phase 5) before returning; the TUI's own preview/collapse then applies on top.
- The structured fields (`cells`, `images`, `jsonOutputs`) are still returned in the response and retained on `ToolResultEnvelope.metadata` — unused by the C TUI, but the exact data source plan 03's card consumes. No payload change is needed between C and plan 03; only the TUI render path is added there.

**Acceptance:** an `eval` call mixing stdout + a JSON `display()` + an image renders as a readable text transcript through the standard preview/collapse path; the image appears as an artifact-path line; `git diff src/tui/src/ui.ts src/tui/src/runtime-process.ts` is empty.

---

## Phase 6 — tests & verification

- **TS unit:** kernel state persistence, cancellation, display/image/json capture, idle eviction, loopback allowlist + workdir confinement, **transcript builder** (Phase 5b: JSON/markdown/image-placeholder flattening + 50KB pre-truncation) (`cd src/tui && bun run test`).
- **AILANG:** `ailang check` on `motoko_ext_eval`; `make check_core`; a `scripts/smoke_eval.ail` exercising `exec_cell` against a running env-server.
- **E2E:** `make run TASK="use eval to load README.md in python and report its line count"`.
- **Regression:** `make test` (core runtime) stays green.

---

## Sequencing & risks

1. Phase 0 (freeze protocol) → 1 (kernels) → 2 (route+registry) → 3 (loopback) → 4 (extension) → 5 (client+fencing) → 5b (transcript rendering) → 6 (tests). Phases 1–3 are the genuinely new, B′-shared work; do them first.
2. **Risks:**
   - *Python portability* — the runner must stay dependency-free; gate `py` cells on a probe (Phase 2).
   - *JS runtime choice* — Worker vs vm is an open question; faithful Worker port first.
   - *Effect-system hole* — native kernels bypass AILANG capabilities; fencing (Phase 5) is mandatory, not optional, for the Phoenix ethos.
   - *Scope creep into B′* — resist adding re-entrancy here; the local fork is the deliberate MVP boundary.

## Open questions carried (from ADR-001 §Consequences / design §7)

| # | Question | MVP decision in this plan |
|---|---|---|
| 2 | JS runtime: Bun `Worker` vs `vm` | Bun `Worker` (faithful port); revisit if process model objects |
| 3 | Python availability + install guarantee | Probe on first `py` cell; install-script `python3` check as follow-up |
| 4 | Session id source / subagent sharing | `ctx.state_key`; subagent sharing deferred to B′ |
| 5 | Output limits | Adopt oh-my-pi's 50KB / 30s / artifact-spill |
