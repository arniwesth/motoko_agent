# Handoff: implement "Preserve context across ESC abort (Option A)"

You are implementing the plan in
[`Abort_Context_Persistence_Option_A.md`](./Abort_Context_Persistence_Option_A.md)
(same directory). Read it in full before writing any code — it is the source of truth;
this file is the operating brief around it.

## What you're fixing

GitHub issue **#15**: pressing **ESC** mid-task SIGTERM-kills the AILANG runtime, which
holds the conversation history only in memory (`loop_v2`'s `[Message]` param), so the
next prompt respawns a fresh, empty process and the agent loses all context. The fix
persists history to disk on a step boundary and rehydrates it on the post-ESC respawn.

## Scope — three patches, land in order

1. **Patch 1 — stable session id (TS).** `src/tui/src/index.ts`,
   `src/tui/src/runtime-process.ts`. Prerequisite for 2 and 3.
2. **Patch 2 — checkpoint writes (AILANG).** `src/core/agent_loop_v2.ail`. One
   checkpoint at the **top of `loop_v2`** (≈`:1075`) + secondary in
   `conversation_loop_v2` after `Ok(updated_history)`. Plus the `Message`↔JSON codec.
3. **Patch 3 — resume (AILANG + TS).** `src/core/rpc.ail`, `src/core/agent_loop_v2.ail`,
   `src/tui/src/index.ts`, `src/tui/src/runtime-process.ts`,
   `src/tui/src/session-logger.ts`. The user-visible fix lands here.

Each patch is independently testable and revertible; commit them separately. Do **not**
fold them into one commit.

## Hard constraints

- **Phoenix Architecture / no human-written code.** You (the agent) write all code. Match
  the surrounding style: explicit recursion over `map`+lambda (there is a known
  match-in-lambda parser bug, see `agent_loop_v2.ail:1125`); reuse existing helpers
  (`msg_get_str`, `msgs_to_messages`, `emit_event`, `_int_to_float`) rather than
  inventing new ones.
- **Ground every AILANG stdlib assumption against the AILANG docs MCP** (`ailang-docs`,
  defined in `.mcp.json`) for the installed version (`ailang version` → query the MCP's
  "latest"). The plan already verified: `std/io` is blocking-only (no non-blocking
  stdin — that's why Option B is deferred), `std/fs` has `writeFile`/`writeFileResult`/
  `readFileResult`/`mkdirAllResult`/`fileExists`/`removeFile` but **no `rename`**, and
  `std/json` has `getArray`/`getString`/`asArray`/`repair`. If you reach for any other
  stdlib function, confirm it exists via the MCP first — do not assume.
- **Keep `rpc.ail` codec-free.** It must not import `Message`. All `Message`/JSON logic
  lives in `agent_loop_v2.ail` behind `try_load_checkpoint` / `resume_v2_conversation`.
- **Resume is best-effort, never fatal.** Missing/corrupt checkpoint → `repair` retry →
  fall back to the init history. A checkpoint write failure must never abort a task (use
  the `*Result` fs variants and discard the error).
- **The checkpoint key depends on Patch 1.** `loop_v2` and `conversation_loop_v2` derive
  `session_id` independently; they only agree when `MOTOKO_SESSION_ID` is set. Verify
  Patch 1 actually exports that env var to the child before testing Patch 2.

## Watch-outs (real traps, already analysed)

- `loop_v2` recurses from **7** branches (`:1211,:1255,:1283,:1299,:1322,:1338,:1374`).
  Do **not** checkpoint per-branch — the single top-of-loop site covers all of them plus
  step 0. If you find yourself editing 7 sites, stop and re-read Patch 2c.
- `ToolCall.arguments` is a **JSON-encoded string** (`std/ai`), not a `Json`. Do not
  confuse it with `tool_contract.ToolCallEnvelope.arguments` (which is a `Json`).
- The respawn-with-resume path replaces the current `setAwaitingTask(true)` interrupt
  branch (`index.ts:932-935`). After resume, plain input must route to `onUserMessage`
  (follow-up), **not** `onInitialTask` (fresh task). Drive that via the `session_resume`
  event handler in the UI, since `taskDone` has no public setter.
- `session_start` and `session_resume` must be **mutually exclusive** for one spawn —
  gate the existing unconditional `session_start` emit in `rpc.ail` (~`:180-191`).
- The FS sandbox is `AILANG_FS_SANDBOX = workdir` (`runtime-process.ts:308`). Write the
  checkpoint under that same `workdir` (= `cwd` in `run_with_config`). The TS-side
  cleanup must target the identical path.

## Validation (must all pass before calling it done)

- `make check_core` — type-checks all `.ail` modules.
- `make test` — core runtime tests (add the AILANG tests from the plan's Tests section:
  codec round-trip, truncation/`repair` recovery, step-0 coverage, resume entry,
  best-effort fallback).
- `cd src/tui && bun run test` — add the TS tests: env (`MOTOKO_SESSION_ID` stable +
  `MOTOKO_RESUME` only on interrupt respawn), the stream-protocol resume scenario, and
  the UI follow-up-routing test.
- **Manual repro of #15** (the acceptance test): `make run`, start "Read README.md and
  run ailang prompt", press ESC mid-task, then ask "What was my last prompt?" → the agent
  must reference the README task. Confirm `${workdir}/.motoko/session/<id>.json` exists
  during the run and is removed after a clean exit. Use the `run` or `verify` skill to
  drive this.

## Definition of done

All four validation gates green, three commits (one per patch) on a feature branch (not
`main`), and a PR description that links issue #15 and the plan file. Do **not** push or
open the PR until the user asks.

## Out of scope (do not attempt here)

- Non-blocking stdin / soft-abort (Option B) — blocked on an upstream AILANG primitive.
  After this lands, file that as AILANG feedback via the `ailang-feedback` skill; don't
  implement it in this repo.
- Recovering the *partial* in-flight (interrupted) step's output — explicit non-goal; the
  checkpoint is the pre-step snapshot.
- `/restart` cross-session history, multi-session resume UX.

## If you get stuck

- AILANG compiler/parser/stdlib error whose symptom is in `ailang check`/`ailang run`
  output → it's likely an AILANG-side issue; route via the `ailang-feedback` skill rather
  than working around it silently.
- Plan assumption contradicted by the code → stop, report the contradiction, and propose
  the adjustment before proceeding. Don't paper over it.
