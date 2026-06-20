# 2026-06-20 - Lean 4 eval and mixed verifier test

## Context

Implemented plan 06: add `language:"lean"` support to the existing `eval` tool as a persistent, proof-verified Lean 4 scratchpad. Lean eval is designed as a hybrid of the existing kernels:

- Like Python/JS, it drives a long-lived child process.
- Like AILANG, it is commit-gated: failed cells do not advance accepted state.
- Persistence uses Lean REPL `env` ids, not source re-rendering.

## Phase 0 findings

Created `.agent/plans/omp-style-python-eval/06-phase0-lean-smoke-notes.md`.

Key measured facts:

- Installed `elan`; stable resolved to Lean 4.31.0, but current `leanprover-community/repl` pins Lean `v4.32.0-rc1`.
- Built `leanprover-community/repl` in `/tmp/lean-repl-smoke`.
- REPL protocol is JSON over stdin/stdout with blank-line-separated commands.
- First command omits `env`; later commands pass returned numeric `env`.
- Failed elaboration still mints an `env`, so the commit gate must abandon failed env ids.
- `sorry` is detected both via `sorries[]` and `#print axioms` returning `sorryAx`.
- `native_decide` produced theorem-specific trust axioms like `native_thm._native.native_decide.ax_1`, so any non-standard axiom is `axiom_tainted`.
- `#eval` performs real file IO, process execution, and network-capable subprocesses unless externally sandboxed.
- Mathlib is a separate Lake project, not a runtime flag. Smoke project was `/tmp/lean-mathlib-smoke`; launch is `lake env /path/to/repl`.

## Implementation summary

Added Lean support through the existing `eval` tool, not a separate route.

Major files added:

- `src/tui/src/eval/lean-session.ts`
- `src/tui/src/eval/kernel-lean.ts`
- `src/tui/src/eval/lean-session.test.ts`
- `src/tui/src/eval/kernel-lean.test.ts`
- `src/tui/src/eval/lean4-teach.md`

Major files updated:

- `src/tui/src/eval/frames.ts`: added `EvalLanguage = "lean"`, `prove`, `mathlib`, and `LeanCellMetadata`.
- `src/tui/src/eval/registry.ts`: routes Lean to `LeanKernel`; reset handled inside Lean kernel so the teach prompt marker survives.
- `src/tui/src/env-server.ts`: normalizes Lean cells, wires `makeLeanConfig`, supplies the one-time Lean guide, and checks Lean availability.
- `src/tui/src/ui.ts`: parses/preserves `metadata.lean`, adds Lean status rendering and minimal Lean syntax highlighting.
- `src/tui/src/ui.tool-render.test.ts` and `src/tui/src/env-server.test.ts`: regression tests for Lean metadata, normalization, and UI rendering.
- `packages/motoko_eval/types.ail`, `eval.ail`, `prompts.ail`: schema/prompt/policy updates for `lean`.
- `scripts/install-prerequisites.sh`: optional `--with-lean` and `--with-lean-mathlib`.
- `packages/motoko_eval/README.md`: extension overview, setup notes, mixed Lean + AILANG test prompt, and expected outcome.

## Important bug found and fixed

The first manual prompt failed because the backend fell back to:

```sh
lake exe repl
```

with `cwd = /workspaces/motoko_agent`, but the repo root is not a Lake project. The session log was:

`.motoko/logfile/session_2026-06-19T20-15-57-552Z.md`

Fix in `src/tui/src/env-server.ts`:

- If `MOTOKO_LEAN_REPL_BIN` / `MOTOKO_LEAN_REPL_CWD` are unset, auto-detect a built REPL checkout:
  - `$HOME/.local/share/lean-repl`
  - `/tmp/lean-repl-smoke`
- Use the built `repl` binary with the correct project cwd.
- For Mathlib, auto-detect:
  - `$HOME/.local/share/motoko-lean-mathlib`
  - `/tmp/lean-mathlib-smoke`
- Launch Mathlib via `lake env <repl-binary>` from the Mathlib project.

Verified with an env-server smoke with all `MOTOKO_LEAN_REPL_*` vars unset. It returned `metadata.lean.proof = "verified"` for an `omega` theorem.

## Verification performed

Commands used successfully:

```sh
cd src/tui
npm run build
node --experimental-vm-modules node_modules/.bin/jest --runInBand
bash -n ../../scripts/install-prerequisites.sh
```

Notes:

- The repo's `npm test` wrapper using Bun/Jest failed before loading tests with `Attempted to assign to readonly property`; running Jest through Node worked.
- Direct `ailang check packages/motoko_eval/eval.ail` was blocked by package-context import resolution for `src/core/env_client`, but broader TUI tests covering package behavior passed.
- Manual Lean kernel smokes succeeded:
  - clean theorem: `proof:"verified"`, committed.
  - second theorem used prior theorem through threaded env.
  - `sorry`: `proof:"sorry"`, not committed under `prove:"required"`.
  - `native_decide`: `proof:"axiom_tainted"`.
  - `#eval`: captured output with `proof:"skipped"`.

## Mixed Lean + AILANG test

The useful cross-verifier prompt was added to `packages/motoko_eval/README.md`.

Test design:

- Lean proves nonlinear invariant preservation for triangular-number step updates.
- A second Lean cell proves a concrete step using the first theorem, exercising Lean env persistence.
- AILANG implements `tri_step(n, t) = t + n + 1`.
- AILANG/Z3 verifies only linear contracts:
  - `result == t + n + 1`
  - `result >= t`
  - `result >= 0`
- AILANG run cell prints `tri_step(10, 55) = 66`, exercising AILANG persistence and execution.

Observed successful expected outcome:

- `metadata.lean.elaborated = "passed"`
- `metadata.lean.proof = "verified"`
- `metadata.lean.committed = true`
- `metadata.ailang.check = "passed"`
- `metadata.ailang.verify = "verified"`
- `metadata.ailang.committed = true`
- AILANG stdout: `66`

Clarification captured in README:

- Lean handles the nonlinear theorem. The theorem contains multiplication of variables, so successful proofs may need rewrites/calc steps before arithmetic goals close.
- AILANG/Z3 handles the executable step function in the linear arithmetic fragment.

## Current repo state at summary time

`git status --short` showed only:

- modified `ailang.lock`
- untracked `.agent/research/omp-style-python-eval/Screenshot 2026-06-14 at 20.14.52.png`
- untracked `ailang/`
- untracked `oh-my-pi/`

Those were not part of the final README-summary edit.
