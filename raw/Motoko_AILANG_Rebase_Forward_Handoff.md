# Handoff Prompt: Motoko AILANG Rebase-Forward Execution

Paste the prompt below into a fresh Claude Code session. It is self-contained; do not add conversational context from the planning session.

---

## Prompt

You are executing a pre-approved migration plan for the Motoko AILANG agent. The plan document is `.agent/plans/Motoko_AILANG_Rebase_Forward.md` — read it in full before doing anything else. It is the source of truth; this prompt only scopes what to execute in this session.

### Context you need to know

- The parent repo at `/workspaces/ailang_agent/` is "Motoko," a TypeScript + AILANG agent. It embeds a Go-based AILANG runtime under `ailang/` (a git repo in its own right).
- Today Motoko runs on the `dev_agent` branch of `ailang/`, which is **AILANG v0.9.0 plus 7 custom commits** (OpenRouter integration, `_io_poll_stdin` runtime patch, local OpenAI endpoint, OpenAI streaming, Result-based AI error handling, ParseFloat underscore fix, test patches).
- Upstream AILANG has moved to v0.13.0 on `dev`. Upstream **does not accept PRs**, so Motoko will permanently carry its custom layer.
- The plan's fundamental principle: **the Motoko-facing AILANG branch must remain as close as possible to the most recent released version of upstream AILANG.** Cherry-picking upstream changes backward into the v0.9.0 base is explicitly rejected. Instead, we rebase forward onto v0.13.0 and re-apply Motoko's custom logic as `_motoko`-suffixed files plus narrowly fenced one-line edits in shared files.
- The plan went through two review rounds. It has six Phase 0.5 gate questions (Q-A through Q-F) that must be answered from source before any Phase 1 work.

### Your scope in this session

Execute **Phase 0 and Phase 0.5 only**. Do not start Phase 1.

Specifically:
1. **Phase 0** — baseline and branch setup:
   - Create `motoko` branch from tag `v0.13.0` in `/workspaces/ailang_agent/ailang` (plan specifies the exact `git checkout -b motoko v0.13.0` command).
   - Discover and run the vanilla build + test commands for v0.13.0; record baseline in `.agent/reports/phase0_baseline.md`.
   - Snapshot the `dev_agent` vs v0.9.0 diff to `.agent/reports/dev_agent_fork_diff.patch`.
   - Capture a deterministic Motoko behavioral baseline trace on `dev_agent` and save to `.agent/reports/dev_agent_baseline_trace.jsonl`.
   - Read out commit `c152a6d2` and write `.agent/reports/c152a6d2_test_patches_readout.md` with verdict (port / drop / partial).
   - Create `ailang/FORK.md` as a skeleton with the six sections the plan specifies.

2. **Phase 0.5** — upstream AI layer interface spike:
   - Answer **all six** questions by reading v0.13.0 source — not by guessing:
     - Q-A streaming additivity (whether `CallStream` can be integrated without breaking fenced-edit invariants, or requires Motoko-side wrapping)
     - Q-B `std/ai_motoko` module feasibility/coexistence with upstream `std/ai`
     - Q-C **runtime** builtin registration source-of-truth + naming (validate `internal/builtins/spec.go` + per-builtin `RegisterEffectBuiltin(...)` init files)
     - Q-D streaming effect set (default expectation: `AI` for AI calls, `Stream` only when exposing stream primitives directly)
     - Q-E budget accounting surface (locate counters/API and account for potential pre-charge + `effects.Call(...)` double-charge paths)
     - Q-F Go dependency drift
   - Write `.agent/reports/phase0_5_ai_interface_spike.md` with findings and a go/no-go verdict.

3. **Hard stop at the Phase 0.5 gate.** Report the go/no-go verdict and wait for user review before proceeding. If the spike reveals the plan needs material revision, say so explicitly and propose specific revisions — do not attempt to improvise around bad news.

### What not to do in this session

- Do not start Phase 1 (the `_io_poll_stdin` port) even if Phase 0.5 returns a clean "go."
- Do not modify `dev_agent`. It remains Motoko's production branch until Phase 5 passes; a tag `pre-rebase-forward` will be placed on it at cutover, not earlier.
- Do not touch parent-repo files (`src/core/*.ail`, `src/tui/src/*.ts`) in this session. Those are Phase 4b and Phase 5 concerns.
- Do not delete, retarget, or force-push `dev_agent`.
- Do not silently relax any plan invariant. If a Phase 0.5 finding makes an invariant untenable (e.g., fenced-block line limits can't hold for the AI handler registration), raise it as a plan-revision item in the spike report, don't just adjust behavior.

### Working conventions for this execution

- Use `git` commands through Bash; do not use destructive operations without confirmation.
- All reports go under `.agent/reports/` with the exact filenames the plan specifies.
- The deterministic baseline trace in Phase 0 needs a fixed task, a fixed model, and seed/temperature controlled where possible. Pick something small (e.g., `TASK="echo hello"`). If the model is non-deterministic (OpenAI typically is), record that in the report and capture a *structural* baseline (event types and ordering) rather than byte-for-byte.
- For Phase 0.5, read the actual v0.13.0 source under `ailang/internal/ai/`, `ailang/internal/effects/`, `ailang/internal/builtins/`, `ailang/std/`. Do not rely on pre-baked assumptions about what the interface "probably" looks like — the whole point of the spike is to confirm empirically.
- Reference materials in the parent repo `/workspaces/ailang_agent/`:
  - `.agent/plans/Motoko_AILANG_Rebase_Forward.md` — the plan (source of truth)
  - `.agent/plans/OpenAI_LLM_Streaming_For_Motoko.md` — design intent of the custom streaming layer
  - `.agent/plans/OpenRouter_Integration.md` — design intent of OpenRouter routing
  - `.agent/plans/Local_OpenAI_Endpoint_Integration.md` — design intent of local endpoint support
  - `.agent/summaries/2026-03-31-openrouter-integration.md`
  - `.agent/summaries/2026-03-31-ailang-replace-fork.md`
  - `.agent/summaries/2026-04-19-local-openai-model-prefix-regression-fix.md`
  - `runtime-patches/` — existing `_io_poll_stdin` patch files (v0.9.0-shaped; informational, not applied)

### Exit criteria for this session

- `ailang/` is on a new `motoko` branch at tag `v0.13.0`.
- All Phase 0 artifacts exist at their specified paths under `.agent/reports/`.
- `ailang/FORK.md` skeleton exists.
- `.agent/reports/phase0_5_ai_interface_spike.md` exists with answers to Q-A through Q-F and a go/no-go verdict.
- You have reported the verdict and stopped. No Phase 1 work has begun.

Begin by reading `.agent/plans/Motoko_AILANG_Rebase_Forward.md` end-to-end. Then proceed.
