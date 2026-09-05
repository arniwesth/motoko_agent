# Handoff: implement the Layer-2 harness-boundary DST

Date: 2026-07-09 (written by the plan-authoring / review session)
Audience: a fresh agent session that will **implement** `PLAN-harness-boundary-dst.md`.

## Mission

Implement `PLAN-harness-boundary-dst.md` in this directory — the **four live Layer-2 harness-boundary
DST scenarios** for `ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md`:
a single net-new **`bun test`** file `src/tui/src/harness-dst.test.ts`, plus **two behavior-preserving
production extractions** that make the code under test observable (WI-1a, WI-1b). This is **pure
TypeScript** — no AILANG, no `spawn`, no network, no providers.

The plan is the normative spec: it carries a re-verified `file:line` anchor log, a test-file skeleton,
a contract-vs-mechanism table, per-WI verification/rollback, and the six-criteria acceptance gate.
Follow it WI by WI.

**G3 is APPROVED (2026-07-09).** Both extractions are authorized — WI-1a (`system-prompt.ts` module
extraction) was ratified by the ADR owner; WI-1b was already handoff-sanctioned. Do the **module
extraction** for WI-1a, not the `import.meta.main` guard (that alternative was explicitly declined).

**Do NOT** implement: the two **gated** AILANG scenarios (`harness.env_manifest_complete`,
`harness.childenv_covers_manifest` — blocked on WI-1/WI-2, which don't exist); WI-1/WI-2 themselves;
the in-core headless re-guard (`require_system_prompt` policy work); the optional L3 runtime probe;
compaction DST. See §"Out of scope".

## Reading order

1. `PLAN-harness-boundary-dst.md` — **the spec.** Read whole first. Execute against its "Work
   breakdown" (WI-0…WI-6), "Plan-level decisions" (D-P1…D-P5), "Test-file skeleton", "Contract vs.
   mechanism" table, and "Anchor re-verification log". Its "ADR gaps found" records G3 as approved.
2. Diagrams in `mmd/`:
   - `harness-boundary-dst-plan.mmd` / `.svg` — implementation work-item flow (note: renders G3 as a
     live gate; it is now approved — the plan doc is authoritative).
   - `harness-boundary-dst-end-state.mmd` / `.svg` — expected runtime/dataflow end state (the outer-tier
     launch path, where the DST taps it, the contract oracle).
3. `ADR-003-harness-boundary-…-materialization.md` — the decision. §"Decision detail 1" (the re-grounded
   id table), §"Acceptance criteria" (items 1–6 = your gate), §Consequences "Long-term: pure-AILANG
   headless" (the contract-vs-mechanism shaping). D1–D4 are settled; do not re-open.
4. **Context only, do NOT trust their `file:line`:** `../004_phase_core_refactor/NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md`
   and `../004_phase_core_refactor/NOTE-env-manifest-single-source-and-drift-guard.md`. ADR-003
   Findings 1 & 4 flag these as carrying stale anchors (`autoForwardedEnvKeys` "verified at HEAD" is
   wrong; `runtime-process-env.test.ts` does not exist). They describe the **gated** track, not your work.

## Ground truth to re-establish before touching code

This is **pure TS**; there is **no AILANG toolchain gate** for this work. The runner is **bun**.

- **Plan anchors grounded at HEAD `09751cd`.** `git log --oneline -5 -- src/tui/` first. The plan holds
  as long as no commit newer than `df85703` (2026-07-09) touches `src/tui/src/index.ts` or
  `src/tui/src/runtime-process.ts`. If any has, **re-verify the plan's Anchor log** before trusting the
  line ranges — the extractions are line-range cuts and will silently mis-cut if the source moved.
- **THE RUNNER LANDMINE (read twice).** Use **bun-native** `bun test <path>`. Do **NOT** use
  `bun run test` — that npm script is `bun node_modules/.bin/jest …` (jest under bun) and is **broken
  repo-wide** (0 tests run, `TypeError: Attempted to assign to readonly property`). Bare `bun test`
  (no path) does **not** discover the `src/*.test.ts` family either — always pass an explicit path.
- **Baseline (the slice, not the repo):** the family your file joins is green under bun-native. The
  full `src/tui` suite is **not** green (2 unrelated scratchpad WebSocket/loopback failures + the jest
  breakage) — do **not** gate on it (plan D-P5 / ADR gap G2).

```bash
git rev-parse --abbrev-ref HEAD && git rev-parse --short HEAD
bun --version                                   # verified 1.3.14 at plan time
git log --oneline -5 -- src/tui/
cd src/tui && bun test src/runtime-process.stream-protocol.test.ts \
                       src/runtime-process.tool-progress.test.ts \
                       src/runtime-process.unknown-events.test.ts   # expect 14 pass, 0 fail
```

## What is already verified this session (trust it; don't re-derive)

- **The reachability survey (why both extractions exist).** `systemPromptForWorkspace` (`index.ts:409`)
  and `materializeSystemPromptArg` (`index.ts:430`) are **unexported**, and `index.ts` **self-executes
  `main()`** at `:1007` — importing them would launch the agent (⇒ WI-1a). `childEnv`/`supervisorArgs`
  are **constructor locals** in `RuntimeProcess` (`:317`), which `spawn`s at `:512` (`env: childEnv`
  `:531`) — unreachable without a real spawn (⇒ WI-1b).
- **Runner facts.** `bun 1.3.14`, `node v22.23.1` present. `bun test src/tui/src/runtime-process.stream-protocol.test.ts`
  from **repo root** → 9 pass (proves the ADR's exact crit-1 command form works; bun resolves
  `@jest/globals` upward from the file). Bun's jest-compat runs `@jest/globals`-style files green.
- **The move is clean.** `index.ts` imports fs/path as `import * as fs from "fs"; import * as path from
  "path"` (`:20-21`) — **match that style** in `system-prompt.ts` (not `node:fs`). The only references
  to the two host fns in `index.ts` are the defs + the two call sites (`:741`, `:766`) + doc comments.
- **The extraction cuts (verified line ranges).** WI-1b: `buildChildEnv` = current `:342-468` (base
  literal + `AILANG_STDLIB_PATH` + `MOTOKO_OTEL` + openai/aiOptions forwards); **leave `:470-495` in
  the constructor** (the `mirror*` FS side-effects + `MOTOKO_PROFILE_DIR` rewrite mutate the returned
  object). `buildSupervisorArgs` = current `:497-510`. Names `buildChildEnv`/`buildSupervisorArgs` are
  free; `runtime-process.ts` already exports test helpers (`parseAgentEventLine`, etc.) — same pattern.

## The traps that will waste your time if you miss them (all verified)

1. **Runner (again): `bun test <path>`, never `bun run test`.** If you "run the tests" the repo way,
   you get 0 tests and a jest crash and will think everything is broken. It isn't.
2. **WI-1a is the module extraction, not a guard.** Move both host fns verbatim into
   `src/tui/src/system-prompt.ts`, `export` them, `import` them back into `index.ts`. **Do not** guard
   `main()` with `if (import.meta.main)` — that changes entry behavior and was declined at G3.
3. **WI-1b: keep the mirror side-effects in the constructor.** `buildChildEnv` is `:342-468` only.
   `mirrorProfileFromRepo` (`:478`), `mirrorAbsoluteProfile` (`:484`), and the `MOTOKO_PROFILE_DIR`
   rewrite (`:488-495`) do **file I/O** and must stay at spawn time. Scenario-4's invariants
   (`AILANG_FS_SANDBOX == workdir`, `SYSTEM_MD` absent) are fixed inside the pure block and survive the
   mirror steps — that's why the cut is behavior-preserving.
4. **WI-4 sandbox-escape case: the out-of-sandbox file MUST EXIST.** If you point `SYSTEM_MD` at a
   non-existent escaping path, the **missing** branch (`index.ts:414`) fires first and the **escape**
   branch (`:419`) is never exercised — both return `""`, so the test passes for the wrong reason.
   Create a real file in a *second* `mkdtemp` dir and point `SYSTEM_MD` at its absolute path.
5. **WI-3 `"."` edge fires only when the path resolves to the workdir directory itself** (`rel === ""`,
   `index.ts:418`), not for a child file. Cover it with `SYSTEM_MD = path.resolve(workdir)`.
6. **WI-5: set a `SYSTEM_MD` sentinel first** so the test proves it is *not forwarded*, not merely that
   it happened to be unset. Assert `!("SYSTEM_MD" in childEnv)` *despite* the parent env having it.
7. **`materializeSystemPromptArg` resolves a relative source against `process.cwd()`** (`:433`). In
   tests, pass **absolute** source paths (mkdtemp dirs are absolute) so results don't depend on cwd.
8. **`@jest/globals` imports, not `bun:test`** (plan D-P1). Runs green under bun-native *and* survives
   the jest CI glob if it's ever repaired. Save/restore `process.env.SYSTEM_MD` + `process.argv` per
   test; `mkdtemp` workdir; clean up in `afterEach`. Each `describe` name **is** the scenario id.

## Out of scope (do not touch)

- The two **gated** AILANG scenarios (`env_manifest_complete`, `childenv_covers_manifest`) and
  WI-1/WI-2 (`CORE_MAP`-derived `childEnv`, AILANG `env_manifest` export) — not on this branch; they
  guard the general scrub class, not #76's prompt (ADR-003 Finding 6).
- Re-guarding #76's in-core symptom in headless (`require_system_prompt` policy work — separate WI).
- The optional L3 runtime probe (ADR-003 R11 — the L2 ∘ in-core composition discharges it).
- Compaction DST (`ADR-002` + `PLAN-compaction-dst-scenarios.md`).
- **Fixing the repo-wide runner breakage** (jest-under-bun) or the two unrelated scratchpad failures.
  Land green under the scoped `bun test <path>` command; do not adopt the red repo suite.
- Editing ADR-003, the two NOTEs, or the plan (report drift as a finding, don't rewrite the spec).

## Suggested WI order

Front-load the lower-risk, dependency-free slice, then the extraction that unlocks the rest:

1. **WI-0** — baseline: the runtime-process family green under bun-native (above). Stop if red.
2. **WI-1b** — `buildChildEnv` / `buildSupervisorArgs` (smallest prod cut; unlocks scenario 4).
3. **WI-5** — `harness.child_env_sandbox_and_prompt_by_reference` (no test-visibility risk; proves the
   test file + runner end-to-end). Run its teeth check (add `SYSTEM_MD` to the literal → must FAIL).
4. **WI-1a** — extract the two host fns to `system-prompt.ts`; confirm the family is still green (the
   extraction is behavior-preserving, so no test should move).
5. **WI-2 → WI-3 → WI-4** — scenarios 1, 2, 3 over the now-importable host fns. Run each teeth check.
6. **WI-6** — final gate + no-scope-leak greps.

Each WI leaves the tree building and the new file green under `bun test src/tui/src/harness-dst.test.ts`.

## Verification commands

```bash
# after each WI touching the test file (ADR-003 crit-1 exact form, from repo root):
bun test src/tui/src/harness-dst.test.ts

# after each extraction — prove behavior-preserving (family unmoved):
cd src/tui && bun test src/runtime-process.stream-protocol.test.ts   # still 9 pass
grep -nE 'export function (buildChildEnv|buildSupervisorArgs)' src/runtime-process.ts
grep -nE 'export function (systemPromptForWorkspace|materializeSystemPromptArg)' src/system-prompt.ts
grep -n 'from "./system-prompt.js"' src/index.ts

# WI-6 no-scope-leak:
grep -nE 'spawn|child_process|fetch|net\.' src/tui/src/harness-dst.test.ts || echo "good: no spawn/network"
grep -nE 'from "bun:test"' src/tui/src/harness-dst.test.ts && echo "FIX: use @jest/globals" || echo "good"
git status --porcelain | grep -E '\.ail$' && echo "FIX: .ail changed" || echo "good: no .ail"
```

Expected: four `describe` blocks named `harness.external_system_md_materialized`,
`harness.workspace_system_md_not_rewritten`, `harness.out_of_sandbox_or_missing_system_md_yields_empty`,
`harness.child_env_sandbox_and_prompt_by_reference` — all green.

## Definition of done (maps to ADR-003 §"Acceptance criteria" 1–6; all in scope post-G3)

- Four Layer-2 scenarios green under `bun test src/tui/src/harness-dst.test.ts`; each uses a `mkdtemp`
  workdir and restores `process.env`/`process.argv`; no AILANG, no spawn, no network; each test name
  is its scenario id.
- `external_system_md_materialized` asserts **content byte-equality** + **dest-inside-workdir** and
  fails against a build that skips materialization.
- `child_env_sandbox_and_prompt_by_reference` asserts `AILANG_FS_SANDBOX === workdir`,
  `SYSTEM_MD ∉ keys(childEnv)` (with a parent sentinel set), and a `--system-prompt <relpath>` pair;
  fails if `SYSTEM_MD` is reintroduced into `childEnv`.
- `out_of_sandbox_or_missing_system_md_yields_empty` proves `""`/`null` for missing + escaping paths,
  with a comment recording the loud rejection is in-core and **absent in headless**.
- The two gated scenarios stay specified-only, unregistered in any live runner.
- No scenario uses real providers, live network, effect-handler mocking, or a bespoke recorder.
- Both extractions verified behavior-preserving (runtime-process family unmoved; no `.ail` touched).

## If the plan is wrong

Line ranges drift; re-grounding is normal. If HEAD contradicts the plan, **stop and record a short
finding** before inventing policy. Worth stopping for: `index.ts` already has an `if (import.meta.main)`
guard or already `export`s the two fns (WI-1a becomes trivial); `childEnv` already contains `SYSTEM_MD`
(a real regression — the scenario should catch it, flag loudly); `materializeSystemPromptArg` changed
its dest filename or the `:342-468` block gained a dependency on a constructor local outside
`{workdir, profile, openaiBaseUrl, aiOptionsJson}` (the WI-1b signature needs updating). Report the
exact failing evidence + the smallest amendment.

## Report back

- `bun test src/tui/src/harness-dst.test.ts` output (four scenario ids, green).
- Confirmation both extractions are behavior-preserving (runtime-process family still green; diff is a
  pure move/cut).
- The teeth-check results (each scenario demonstrably FAILs when its invariant is broken, then reverted).
- Confirmation: no spawn / network / AILANG in the new file; no `.ail` changed; repo-wide runner
  breakage left untouched.

## Branch

This plan currently lives on `arniwesth/mot-33-add-runtime-status-tool`, an unrelated feature branch.
Implement on a **dedicated branch cut from `main`** (e.g. `arniwesth/harness-boundary-dst`) so the DST
does not mix with the runtime-status-tool work.
