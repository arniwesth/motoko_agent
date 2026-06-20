# Session summary & handover — omp-style `eval` for Motoko

**Date**: 2026-06-14
**Branch**: `autoresearch-loop`
**Toolchain**: AILANG v0.19.1 (pinned in `ailang.lock`), Bun 1.3.14

---

## What this session was about

Designing how to bring oh-my-pi's §01 `eval` feature — **persistent Python + JS
cells that can call back into the agent's own tools** (`tool.read/search/agent`) over
a loopback bridge — into Motoko (the AILANG agent harness in this repo).

The discussion was grounded against:
- The **actual oh-my-pi source**, cloned locally at `oh-my-pi/` (version
  `v15.12.6-70-gcd0000382`). The relevant code is
  `oh-my-pi/packages/coding-agent/src/eval/` and `oh-my-pi/docs/tools/eval.md`.
- Motoko's own runtime (`src/core/`), extension ABI
  (`~/.ailang/cache/registry/sunholo/motoko_ext_abi/2.2.0/types.ail`), and the Bun
  env-server (`src/tui/src/env-server.ts`).
- The installed AILANG 0.19.1 stdlib (`~/.local/share/ailang/std/`) and the
  `ailang-docs` MCP.

## What was produced

1. **`00-design.md`** — the full design RFC. Reviewed over 3 passes; no major issues
   remaining. Read this first.
2. **`smoke/`** — a working smoke test that resolved the one open feasibility blocker
   (see below): `smoke_transmit.ail` (AILANG client) + `ws_server.ts` (Bun WS server).

## Key conclusions (the load-bearing facts)

- **`eval` is still a Motoko extension** (`motoko-ext-eval`): it owns the schema,
  `on_tool_policy`, and `on_tool_handle`. It *delegates* execution to the env-server —
  the same front/backend split that `exa_search` and the core bash/AILANG tools
  already use. The user explicitly asked about this; the answer is yes, still an
  extension.
- **Kernels must live in the Bun env-server, not the AILANG brain.** This is forced,
  not a preference: AILANG 0.19.1 **cannot host a persistent bidirectional REPL**.
  `std/process.spawnProcess` gives a writable stdin but **discards stdout/stderr**;
  `std/stream.asyncExecProcess` reads stdout but is read-only and **kills the
  subprocess when the event loop exits**. The Bun env-server already holds long-lived
  bidirectional subprocesses, so oh-my-pi's `kernel.ts`/`worker-core.ts` port almost
  directly.
- **oh-my-pi avoids loopback deadlock by co-locating kernels + tool registry in one
  async process.** Motoko's registry (brain) and kernels (env-server) are split
  across a synchronous HTTP boundary, so the loopback is the one real design fork:
  - **Design C (MVP, recommended first):** blocking `httpPost`; loopback served
    *locally in the env-server* (read=fs, search=ripgrep, agent=`callSubagentModel`
    which already exists). No deadlock. Cost: in-cell `tool.*` is a *fork* of the real
    registry — no other extensions' tools, no `on_tool_policy`.
  - **Design B′ (faithful, later):** WebSocket channel; env-server forwards
    `tool-request` frames to the brain, which dispatches through the canonical
    `tool_runtime` and `transmit`s the result back. True parity.
- **The B′ blocker is RESOLVED.** The open question was whether AILANG can call
  `transmit` *inside* an `onEvent` handler during a live `runEventLoop` (needed for
  the brain to answer loopback requests mid-stream). **It can** — verified both at
  type-check time and at runtime via an end-to-end WebSocket round-trip. So B′ has no
  remaining language dependency; C→B′ is a pure engineering swap.

### Reproduce the smoke test
```bash
cd .agent/research/omp-style-python-eval/smoke
# terminal 1 (or background): start the WS server
RESULT_FILE=/tmp/ws_smoke_result.txt PORT=8787 bun run ws_server.ts
# terminal 2: run the AILANG client
ailang run --caps IO,Net,Stream --stream-allow-http --stream-allow-localhost smoke_transmit.ail
# expect: server prints "SERVER_RECEIVED: reply-from-handler"
```
Gotchas learned: `Stream` is its own capability (not folded into `Net`); `ws://`
localhost needs `--stream-allow-http --stream-allow-localhost`; `ailang run` flags
must precede the positional `.ail` file. **Do NOT use `pkill -f ws_server.ts`** to
clean up — the pattern self-matches your own shell's command line and kills it
(exit 144); kill by PID instead.

## Recommended next step (where we were headed)

Scaffold **Design C**: the `motoko-ext-eval` extension skeleton + the env-server
`/exec-cell` kernel host. Per the README:
```bash
cd ../ailang-packages
ailang init motoko-extension --name <org>/motoko_ext_eval \
  --tools "eval" --effects "Net,Stream,Process,FS,Env"
```
Freeze the frame protocol up front (`run`/`display`/`result`/`tool-request`/
`tool-result`/`done`) so promoting C→B′ later swaps only the transport.

## Open questions still unanswered (from 00-design.md §7)

2. JS runtime: Bun `Worker` vs `vm` context?
3. Python availability probing + install-script guarantee of `python3`.
4. What does the eval session id key off, and must `compose`/subagents inherit it to
   share kernels?
5. Output limits — adopt oh-my-pi's (50KB window, 30s default timeout, artifact
   spill) or our own?

## Git / working-tree state at session end

- No commits made this session. New untracked files under
  `.agent/research/omp-style-python-eval/`: `00-design.md`,
  `01-session-summary-and-handover.md`, `smoke/`.
- Pre-existing uncommitted changes from before this session (unrelated):
  modified `.agent/research/Motoko-auto-research/04-layer-2-discussion.md`,
  `.gitignore`, `ailang.lock`; untracked `05-darwin-godel-machine.md`,
  `06-ai-scientist.md` under `Motoko-auto-research/`.
- `smoke/.ailang/` is a build-cache dir created by `ailang check/run` — safe to
  delete or gitignore.

---

## HANDOVER PROMPT (paste to the next agent)

> You are picking up work on bringing oh-my-pi's `eval` tool (persistent Python + JS
> cells with a tool-loopback bridge) into Motoko, the AILANG agent harness in this
> repo (`/workspaces/motoko_agent`).
>
> **Start by reading these, in order:**
> 1. `.agent/research/omp-style-python-eval/00-design.md` — the design RFC (the plan).
> 2. `.agent/research/omp-style-python-eval/01-session-summary-and-handover.md` — this
>    file (context + what's verified).
> 3. The reference implementation: `oh-my-pi/packages/coding-agent/src/eval/`
>    (cloned locally) and `oh-my-pi/docs/tools/eval.md`.
>
> **What's already settled (don't re-litigate):** `eval` is a Motoko extension that
> delegates execution to the Bun env-server; kernels must live in the env-server
> because AILANG can't host a persistent bidirectional REPL; the loopback re-entrancy
> for the "faithful" design (B′) is already proven feasible (see `smoke/`). Build the
> MVP (Design C) first.
>
> **Your task (unless the user redirects):** scaffold Design C — the `motoko_ext_eval`
> extension skeleton and the env-server `/exec-cell` route with persistent
> Python + JS kernels — porting from oh-my-pi's `py/kernel.ts`, `py/runner.py`,
> `py/prelude.py`, and `js/worker-core.ts`. Freeze the NDJSON frame protocol
> (`run`/`display`/`result`/`tool-request`/`tool-result`/`done`) up front so a later
> swap to the WebSocket-based B′ loopback changes only the transport.
>
> **Environment notes:** AILANG is v0.19.1; `Stream` is its own `--caps` capability;
> verify changes with `ailang check` and `make check_core`. Confirm tooling came back
> up cleanly after the devcontainer reboot (`which ailang bun`, `ailang --version`)
> before building. Do not use `pkill -f ws_server.ts` — it self-matches the shell.
>
> Confirm your understanding of Design C vs B′ and the C-first plan before writing
> code.
