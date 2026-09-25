# NOTE: Can the #76 harness (TypeScript) spawn logic move into AILANG core?

Date: 2026-07-06
Toolchain: AILANG v0.26.0 (`3b52a24`); `std/process` capability checked against MCP `latest`.
Relates to:
- `NOTE-env-manifest-single-source-and-drift-guard.md` (this project) — the env-allowlist /
  `CORE_MAP` single-source work; this NOTE is the "why the mechanism can't just move to core"
  companion.
- `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` (this project) — established that
  the #76 env-scrub root cause "runs before any `.ail`, so core DST cannot observe it." This NOTE
  refines that "irreducible boundary" claim.
- `001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` — defers harness-boundary
  (#76) DST; this NOTE records where that boundary actually sits.
- PR **#76** — the TypeScript changes in question (`runtime-process.ts`, `index.ts`,
  `runtime-process-env.test.ts`; plus `rpc.ail`).

## Question

PR #76's fix lives mostly in TypeScript (`runtime-process.ts` env allowlist / `autoForwardedEnvKeys`,
`index.ts` external-`SYSTEM_MD` materialization). Could that functionality move into AILANG core so
it becomes directly core-DST-able instead of Layer-2-only?

## Answer: split policy from mechanism — they go opposite ways

The TS functionality is two layers:

- **Policy / data** — *which* env keys to forward, *where* the system prompt authoritatively comes
  from, *which* files to materialize.
- **Mechanism** — build `childEnv` (`runtime-process.ts:342`), impose `AILANG_FS_SANDBOX:workdir`
  (`:351`), materialize / mirror files (`mirrorProfileFromRepo :478`), `spawn(... env: childEnv)`
  (`:512/:531`). All of it runs **at or before** the spawn, i.e. before the AILANG child exists.

### Policy → yes, move it. It is the actual fix.

#76 was a **policy** bug: `SYSTEM_MD` fell off a hand-maintained allowlist. The high-leverage move is
single-sourcing that policy so both the TS applier and an AILANG conformance scenario derive from one
manifest — exactly what #76's `autoForwardedEnvKeys()` (derives from `CORE_MAP` + extension maps +
`MOTOKO_*`/`AILANG_*` namespaces) and the env-manifest NOTE already propose. That makes the bug class
core-DST-able as a **manifest-completeness scenario** (AILANG asserts the manifest covers every key)
plus a one-line TS drift-guard — **without relocating any mechanism**.

### Mechanism → no, not today — and moving it would not even fix #76.

Two independent blockers:

1. **Capability gap.** `std/process` (MCP `latest`) exposes only
   `exec(cmd, args) -> Result[ProcessOutput, ProcessError] ! {Process}` and
   `spawnProcess(cmd, args) -> ProcessHandle ! {Process}` — **no child-env argument, no cwd/sandbox
   control, stdout/stderr discarded**, commands allowlist-gated. AILANG literally cannot construct a
   `childEnv` or set `AILANG_FS_SANDBOX` on a child. New stdlib primitives would be required first.
2. **Self-defeating for this bug class.** A process AILANG spawns inherits *AILANG's* environment —
   which node already scrubbed on the way in. AILANG can pass-through or narrow, **never widen back**.
   Relocating the plumbing into AILANG cannot un-scrub a dropped var; only an authoritative *data*
   source that survives the boundary (config-by-value `--system-prompt` argv per ADR-002; a shared
   manifest) recovers it. Which is the policy answer again.

## What is genuinely irreducible

Only the **birth environment of the outermost process**, set by its parent (OS/shell → node today;
OS/shell → AILANG if AILANG were the entry). No program in any language governs the env it is born
with. The precise form of ADR-002's "irreducible boundary": *the root process's birth env* is
irreducible; the policy above it — and, with new primitives, the mechanism below it — are not.

## The one world where mechanism-in-core makes sense

Make **AILANG the entry/supervisor process**, replacing the `runtime-process.ts` spawn layer: then
materialization, sub-worker spawning, and sandbox imposition become AILANG-governed and directly
core-DST-drivable. Not fantasy — AILANG already spawns the backend via `spawnProcess`
(`src/core/backend.ail:5,:58`) and has an env-server exec pattern (`src/core/env_client.ail`,
`exec_in`). But it is gated on: new `std/process` env/cwd/sandbox primitives; an AILANG-as-entry
integration with the TUI; and it *still* leaves the OS→AILANG birth env irreducible. Large effort;
the DST payoff over the manifest path is only "direct-drive vs conformance," which the #76 class does
not need.

## Recommendation

- **For #76:** single-source the env/prompt **policy** (env-manifest NOTE). Cheap, and it is the
  layer that caused and catches the bug.
- **Moving the spawn mechanism into core:** blocked on `std/process` primitives, does not address the
  data-authority root, and only pays off inside a larger "AILANG-as-harness" rewrite. Log as a
  long-horizon architectural option, not a near-term move.

## Anchors (verified 2026-07-06, HEAD)

- `src/tui/src/runtime-process.ts`: `childEnv` build `:342`, `AILANG_FS_SANDBOX:workdir` `:351`,
  `mirrorProfileFromRepo` `:478`, `spawn(...)` `:512`, `env: childEnv` `:531`; `autoForwardedEnvKeys`
  (PR #76) derives the allowlist from config maps.
- `std/process` (MCP `latest`): `exec(cmd, args)`, `spawnProcess(cmd, args)` — no env/cwd/sandbox
  params.
- `src/core/backend.ail:5` `import std/process (spawnProcess, ProcessHandle)`, spawn at `:58`
  (`{IO, Process, Net}`); `src/core/env_client.ail` `exec_in` (backend exec pattern).
