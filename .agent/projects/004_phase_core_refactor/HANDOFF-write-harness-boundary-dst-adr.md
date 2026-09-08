# Handoff: draft the harness-boundary (#76) DST ADR

Date: 2026-07-06 (written by the compaction-DST-ADR session, cashing out residual context per
`NOTE-plan-authoring-session-choice.md`)
Audience: a **fresh** session that will ground and draft the harness-boundary DST decision.

## Why you (a fresh session) and not the closing one

Per `NOTE-plan-authoring-session-choice.md`: the *decision synthesis* for this is already extracted
and durable in `NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md`. What remains is
**source-heavy work in the TypeScript harness / env layer**, which the closing session had *not*
loaded (its context was compaction). That is precisely the "source-heavy → fresh session grounded
against HEAD" case, and it doubles as the ADR-completeness test: if you cannot produce this ADR from
the NOTEs + `001_DST/ADR-001`'s harness sections alone, those upstream docs have a gap worth finding
now.

## First task (do this before drafting): ADR, or straight to a plan?

Decide early whether a full ADR is warranted. The compaction track needed `001_DST/ADR-002` because
ADR-001's compaction sections were **stale/pre-refactor**. The harness sections may be closer to
plan-ready, and two NOTEs already carry the decisions. Assess whether
`001_DST/ADR-001` harness scenarios + `NOTE-env-manifest-single-source-and-drift-guard.md` + the
policy-vs-mechanism NOTE constitute enough to skip to a plan. Record the determination; if ADR,
mirror the shape of `001_DST/ADR-002` (a mostly-subtractive re-grounding).

## Mission

Produce the decision that turns the **#76 bug class** (a 0-char system prompt from env scrubbing /
external `SYSTEM_MD` unreadable under `AILANG_FS_SANDBOX`) into **standing DST**, re-grounded on the
architecture that actually shipped. This is the harness-boundary DST that `001_DST/ADR-002`
explicitly **deferred** ("Out of scope: Harness-boundary (PR #76) DST"). Likely lands as
`001_DST/ADR-003` (parallel to how ADR-002 re-grounded the *compaction* sections of ADR-001) — but
confirm the number/location as part of the first task.

## Reading order

1. `NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md` (this project) — **settled decision
   inputs.** Do not re-litigate its conclusions (see "Settled" below).
2. `NOTE-env-manifest-single-source-and-drift-guard.md` (this project) — the single-source manifest
   fix (derive the allowlist from `CORE_MAP`) and the "one-line conformance check + AILANG-side
   manifest-completeness scenario" idea. This is the heart of the cheap DST path.
3. `001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — its **harness sections**:
   "Layer 2: Harness-Boundary DST", "Initial Scenario Families → Harness Prompt Materialization"
   (canonical ids `harness.external_system_md_materialized`,
   `harness.workspace_system_md_not_rewritten`, `harness.missing_system_md_fails_loudly`,
   `harness.system_md_forwarded_to_child_env`), and review findings R1/R7/R11. These are
   **pre-refactor (2026-06-27)** and need the same re-grounding ADR-002 gave the compaction ids.
4. `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md` §"Follow-up PR
   #76" (Scenarios 6–8) — the original harness-materialization scenario sketches.
5. `001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` — the **template**: how a
   pre-refactor DST design gets re-grounded (retire stale bits, reuse what shipped, split scope,
   ground with `file:line`, gate what isn't buildable yet).
6. `ADR-002-send-gate-…` §5 (this project) — how #76's in-core symptom + host root cause were already
   handled; and `NOTE-ailang-run-exit-code-false-alarm.md` for measurement discipline.
7. PR **#76** itself (via `gh`/WebFetch if reachable, or the diff on its branch): the actual final
   shape — `runtime-process.ts` `autoForwardedEnvKeys()`, `index.ts` materialization,
   `runtime-process-env.test.ts` drift-guard, `rpc.ail` env-authoritative loading.

## Settled inputs — do NOT re-litigate (from the policy-vs-mechanism NOTE)

- **Policy vs mechanism split.** Move the *policy* (single-source manifest); do **not** move the
  *spawn mechanism* into core.
- **`std/process` capability gap is real:** `exec(cmd,args)` / `spawnProcess(cmd,args)` have **no
  child-env / cwd / sandbox control** (verified against MCP `latest`). So AILANG cannot build
  `childEnv` or impose `AILANG_FS_SANDBOX`, and an AILANG child inherits node's already-scrubbed env
  (can narrow, never widen).
- **Irreducible boundary refined:** only the *root process's birth env* is irreducible; the policy
  above it is not.
- **AILANG-as-entry supervisor** is a long-horizon option, explicitly **not** the near-term move.
- **#76's in-core symptom is already guarded** by `ADR-002`'s `empty_system_prompt_rejected` — so
  this DST is about the *host boundary* (materialization, env forwarding), not re-guarding the
  symptom.

## The real work / open decisions for the ADR

1. **Re-ground ADR-001's four `harness.*` ids** against #76's actual shape (`autoForwardedEnvKeys` ←
   `CORE_MAP`, `index.ts` materialization). Which survive, which change, which are already covered.
2. **Pick the DST mechanism per scenario:** (a) an **AILANG-side manifest-completeness scenario**
   (core-DST-able — the cheap high-value path the env-manifest NOTE proposes); (b) **Layer-2 TS
   tests** for materialization / sandbox-readable paths (the `runtime-process-env.test.ts` family);
   and decide which are worth building given the symptom is already guarded in-core.
3. **Resolve the inherited ADR-001 findings** that block harness DST: R7 (per-layer effect / env
   satisfaction), R11 (the L3 runtime-probe contract), R1 (the dangling "#76" reference — now
   concrete). Decide the trace format / reporting contract for Layer-2 tests.
4. **Scope split, ADR-002-style:** what lands now vs what's deferred; state the acceptance gate.

## Ground truth to re-establish before citing anything

- **Toolchain pin: AILANG v0.26.0 (`3b52a24`).** `ailang --version`.
- **Re-survey the TS harness against HEAD.** The closing session only *lightly* touched it. Leads to
  verify, not trust: `src/tui/src/runtime-process.ts` (`childEnv` build ~`:342`,
  `AILANG_FS_SANDBOX:workdir` ~`:351`, `mirrorProfileFromRepo` ~`:478`, `spawn` ~`:512/:531`,
  `autoForwardedEnvKeys` from #76); `config.ts` `CORE_MAP` ~`:22`; `src/core/backend.ail:5,:58`
  (`spawnProcess`); `src/core/env_client.ail` (`exec_in`); `rpc.ail` system-prompt loading (argv
  `--system-prompt` per ADR-002 §5). **Re-verify every line before citing** — staleness is this
  project's proven failure mode.
- Confirm PR #76's branch/diff is what these NOTEs assume before grounding the re-grounding on it.

## Out of scope

- Moving the spawn mechanism into core / AILANG-as-entry (settled: not now).
- Re-guarding #76's in-core symptom (done — `empty_system_prompt_rejected`).
- Compaction DST (its own track: `001_DST/ADR-002` + `PLAN-compaction-dst-scenarios.md`).
- Implementing anything — this handoff produces a **decision/plan doc**, not code.

## Definition of done

A committed decision doc (ADR or plan, per the first-task determination) that: re-grounds the
`harness.*` scenarios against #76's shipped shape; picks the DST mechanism (AILANG manifest-completeness
scenario and/or Layer-2 TS) with a clear rationale tied to the env-manifest NOTE; resolves ADR-001
R1/R7/R11 for the harness layer; states an acceptance gate; and grounds every source citation against
HEAD. If you determine an ADR is *not* warranted, say so explicitly and hand straight to a plan.
