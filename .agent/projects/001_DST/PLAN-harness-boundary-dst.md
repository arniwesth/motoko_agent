# Plan: implement the Layer-2 harness-boundary DST scenarios

Date: 2026-07-09
Implements: `001_DST/ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md`
(the **four live Layer-2 scenarios** only — Decision detail 1 & 2, "Land now").
Branch: `arniwesth/mot-33-add-runtime-status-tool`
Grounding HEAD: **`09751cd`** ("Added long-term note to ADR"). The ADR was re-grounded at `df85703`
(2026-07-09); `df85703` is an ancestor of HEAD, and **no commit newer than `df85703` touches
`src/tui/`** (last `src/tui` commit is `fd933b6`, 2026-07-03) — so every inherited TS anchor was
re-verified against HEAD this session and holds (see Anchor log).
Toolchain: **Layer-2 exercises no AILANG** (pure TS). Runner verified: **bun 1.3.14**; node **v22.23.1**
present (relevant to the runner gap, below). `ailang.lock` is dirty in the worktree but irrelevant to
this plan.

Re-verify the Anchor log below before starting if any commit has since landed on
`src/tui/src/index.ts`, `src/tui/src/runtime-process.ts`, or `src/tui/package.json`.

---

## Goal

Land the four re-grounded Layer-2 scenarios from ADR-003 §"Decision detail 1" as a single net-new
file, `src/tui/src/harness-dst.test.ts`, whose **test names ARE the scenario ids** (ADR-003 reporting
contract). Each test: a `mkdtemp` workdir, save/restore of `process.env.SYSTEM_MD` and `process.argv`,
**no AILANG, no `spawn`, no network**.

1. `harness.external_system_md_materialized` — `materializeSystemPromptArg` copies an out-of-workspace
   source's **content** into `<workdir>/.motoko-system-prompt.md`.
2. `harness.workspace_system_md_not_rewritten` — an in-workspace `SYSTEM_MD` + no `--system-prompt`
   flag: `systemPromptForWorkspace` returns the workdir-relative path unchanged; no managed file written.
3. `harness.out_of_sandbox_or_missing_system_md_yields_empty` — `""` for missing / sandbox-escaping
   paths; `null` + log for an unreadable materialization source.
4. `harness.child_env_sandbox_and_prompt_by_reference` — `AILANG_FS_SANDBOX === workdir`, `SYSTEM_MD`
   absent from `childEnv`, and a `--system-prompt <relpath>` pair in `supervisorArgs`.

The four scenario names are language-neutral **contract** that will port to a future `launcher.ail`
scenario; only the `bun test` runner and the TS-specific mechanism assertions are throwaway (ADR-003
Consequences §"Long-term"). See §"Contract vs. mechanism" for which assertions are which.

## Out of scope (do NOT touch here) — mirrors ADR-003 §"Out of scope"

- The two **gated** AILANG scenarios `harness.env_manifest_complete` and
  `harness.childenv_covers_manifest` (blocked on WI-1 `CORE_MAP`-derived `childEnv` + WI-2 AILANG
  `env_manifest` export; neither on this branch). They guard the general scrub class, **not** #76's
  prompt (ADR-003 Finding 6). Leave specified-in-the-ADR and unplanned.
- **WI-1 / WI-2** themselves (owned by the env-manifest NOTE's follow-up).
- **Re-guarding #76's in-core symptom in headless** (`require_system_prompt` policy work — separate WI).
- The **optional L3 runtime probe** (ADR-003 R11: the L2 ∘ in-core composition discharges the
  criterion).
- **Compaction DST** (`ADR-002` + `PLAN-compaction-dst-scenarios.md`).
- Fixing the **repo-wide test-runner breakage** or the two unrelated red scratchpad tests (see ADR
  gap G2). This plan lands green under its own scoped command and does not adopt the red suite.

---

## TL;DR — layout & the two production changes

**One net-new test file**, `src/tui/src/harness-dst.test.ts`, four `describe`/`it` blocks named for the
scenario ids, importing the functions under test from their (newly extractable) production homes.

The reachability survey (§"Survey findings") shows **all four scenarios are unreachable without a
behavior-preserving extraction** — not just scenario 4 as the handoff anticipated. Two production
changes, both pure textual cuts, both justified by the survey, both flagged where they exceed the
ADR's sanctioned scope (ADR gap G3):

| # | Scenarios | Extraction | Why unreachable as-is |
|---|---|---|---|
| WI-1a | 1, 2, 3 | move `systemPromptForWorkspace` + `materializeSystemPromptArg` out of `index.ts` into new `src/tui/src/system-prompt.ts`; `index.ts` imports them | both are **unexported** and `index.ts` **self-executes `main()`** at load (`index.ts:1007`) — importing to test them would launch the agent |
| WI-1b | 4 | add exported `buildChildEnv` + `buildSupervisorArgs` in `runtime-process.ts`; the `RuntimeProcess` constructor calls them | `childEnv` / `supervisorArgs` are **constructor locals**; the constructor `spawn`s at `:512` — no way to read them without a real child process |

Everything else is net-new test code.

## Plan-level decisions

- **D-P1 — one file, `@jest/globals` imports, verified under `bun test`.** ADR-003 crit 1 names the
  command `bun test src/tui/src/harness-dst.test.ts`. The existing `runtime-process.*.test.ts` family —
  which the ADR says the new file "joins" — is written with `import { describe, it, expect } from
  "@jest/globals"`. Bun's native runner runs such files green (verified: `bun test
  src/runtime-process.stream-protocol.test.ts` → 9 pass). So use **`@jest/globals` imports, matching
  the family verbatim**; this satisfies the literal `bun test <path>` command *and* keeps the file in
  the same family. Do **not** use `bun:test` imports (they would break the jest CI glob if it is ever
  repaired — ADR gap G1). Use `beforeEach`/`afterEach` (or per-`it` try/finally) for env/argv
  save/restore; both work under bun's jest-compat.
- **D-P2 — extract, do not inline.** This repo has an inline-copy test precedent
  (`test/path-guard.test.ts` inlines the logic under test with a "keep lockstep" comment). It is
  **rejected here**: ADR-003 crit 2 requires scenario 1 to **fail against a build that skips
  materialization** — an inline copy cannot observe the real function regressing, so it provides no
  #76 regression law. The behavior-preserving extraction (WI-1a/WI-1b) is the minimum that makes the
  real functions observable. This is the same category of change the handoff already sanctioned for
  scenario 4; the survey extends the identical rationale to scenarios 1–3 (ADR gap G3).
- **D-P3 — keep the FS side-effects out of `buildChildEnv`.** The constructor's `childEnv`
  construction is entangled with two file-mirroring side-effects — `mirrorProfileFromRepo`
  (`runtime-process.ts:478`) and `mirrorAbsoluteProfile` (`:484`, which yields `resolvedProfile`) —
  plus a post-mirror `MOTOKO_PROFILE_DIR` rewrite (`:488-495`). `buildChildEnv` covers only the pure
  env-shape block (`:342-468`: base literal + `AILANG_STDLIB_PATH` + `MOTOKO_OTEL` + openai/aiOptions
  forwards) and **returns** the object; the two `mirror*` calls stay in the constructor, mutating the
  returned object exactly as today. This is behavior-preserving **and** sufficient: scenario 4's two
  env invariants (`AILANG_FS_SANDBOX === workdir` at `:351`, `SYSTEM_MD` absent) are both fixed inside
  the pure block and are **invariant under the mirror steps** (neither mirror touches `AILANG_FS_SANDBOX`
  or adds `SYSTEM_MD`). `buildSupervisorArgs` (from `:497-510`) is already pure (calls only module-level
  `supervisorWorkdirArg:223`).
- **D-P4 — assert thick on contract, thin on mechanism.** Per ADR-003 Consequences §"Long-term": the
  content-byte-equality / dest-inside-sandbox / empty-on-missing-or-escape / prompt-by-reference
  assertions are the portable **contract**; the `process.env.SYSTEM_MD` repoint, `process.argv`
  save/restore, and the literal `.motoko-system-prompt.md` filename are **mechanism** — asserted only
  as thinly as needed to drive the code. See the table in §"Contract vs. mechanism".
- **D-P5 — precondition is the *slice*, not the repo.** The full `src/tui` suite is **not** green at
  HEAD (ADR gap G2), but the runtime-process family the new file joins **is** (14/14 under bun-native).
  The plan gates on that slice, not the pre-existing repo-wide red.

---

## Survey findings (the reachability evidence behind WI-1a/WI-1b)

- **`index.ts` is a self-executing entry module.** `main().catch(...)` at `index.ts:1007` runs on
  import; `systemPromptForWorkspace` (`:409`) and `materializeSystemPromptArg` (`:430`) are **not
  exported** (grep: no `export` on either). ⇒ scenarios 1–3 cannot import the real functions without
  launching the agent. **Resolution: WI-1a** (extract to `system-prompt.ts`). Both functions reference
  only `fs`, `path`, `process.env.SYSTEM_MD`, and `process.cwd()` — a clean, dependency-free cut.
- **`childEnv` / `supervisorArgs` are constructor-locals.** Both are built inside the `RuntimeProcess`
  **constructor** (`:317`), which `spawn`s the real `ailang` child at `:512` (`env: childEnv` at
  `:531`). ⇒ scenario 4's assertions are unreachable without a real spawn. **Resolution: WI-1b**
  (extract pure `buildChildEnv` / `buildSupervisorArgs`, mirroring the existing exported-helper pattern
  — `runtime-process.ts` already exports `parseAgentEventLine`, `providerSelectionModel`, etc. for its
  tests).

---

## Contract vs. mechanism (ADR-003 Consequences §"Long-term")

| Assertion | Kind | Ports to `launcher.ail`? |
|---|---|---|
| dest content **byte-equals** source (`readFileSync(dest) === source`) | **contract** | yes |
| dest resolves **inside** `workdir` (`path.relative(workdir, dest)` not `..`/absolute) | **contract** | yes |
| out-of-workspace source is still captured | **contract** | yes |
| `""` on missing file / sandbox-escape; `null` on unreadable source | **contract** | yes |
| prompt carried **by reference**: `--system-prompt <relpath>` pair in args | **contract** | yes |
| `AILANG_FS_SANDBOX === workdir`; `SYSTEM_MD` **absent** from child env | **contract** | yes |
| managed filename is literally `.motoko-system-prompt.md` | mechanism | no (thin) |
| `process.env.SYSTEM_MD` repoint (`index.ts:740-744`) | mechanism | no (thin) |
| `process.argv` / `process.env` save-restore harness | mechanism | no (thin) |

Write contract assertions **thick** (exact byte equality, exact emptiness); touch mechanism only
enough to exercise the path.

---

## Test-file skeleton (`src/tui/src/harness-dst.test.ts`)

```ts
import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
// WI-1a exports (BLOCKED on G3): import { systemPromptForWorkspace, materializeSystemPromptArg } from "./system-prompt.js";
import { buildChildEnv, buildSupervisorArgs } from "./runtime-process.js";   // WI-1b

let workdir: string;
let savedEnv: string | undefined;
let savedArgv: string[];
beforeEach(() => {
  workdir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-"));
  savedEnv = process.env.SYSTEM_MD;          // ADR-003 harness discipline
  savedArgv = process.argv;
});
afterEach(() => {
  if (savedEnv === undefined) delete process.env.SYSTEM_MD; else process.env.SYSTEM_MD = savedEnv;
  process.argv = savedArgv;
  fs.rmSync(workdir, { recursive: true, force: true });
});
```

Match the codebase's `import * as fs from "fs"` style (not `node:fs`). Each `describe` name **is** the
scenario id (e.g. `describe("harness.external_system_md_materialized", ...)`) — that is the ADR-003
reporting contract. The env/argv save-restore and the `.motoko-system-prompt.md` literal are
**mechanism** (thin); assert **thick** on the contract rows in §"Contract vs. mechanism".

## Work breakdown

Establish the baseline **first** (see WI-0). Every step's verification is ADR-003 crit 1's exact
command, run from **repo root**:

```
bun test src/tui/src/harness-dst.test.ts
```

Verified this session that this repo-root form runs a `src/tui/src/*.test.ts` family file green (bun
resolves `node_modules`/`@jest/globals` upward from the test file, so cwd does not matter). The
`cd src/tui && bun test src/harness-dst.test.ts` form is equivalent.

**Gating note (ADR gap G3) — RESOLVED 2026-07-09.** The ADR owner **approved** the WI-1a module
extraction (see G3 in §"ADR gaps found"). WI-1a + scenarios **1–3** (WI-2/3/4) are now **unblocked**
and proceed as written. WI-1b + scenario **4** (WI-5) were already handoff-authorized.

### WI-0 — precondition: prove the *slice* is green (do not adopt the red repo)

**Purpose.** ADR-003 §Preconditions: do not add DST on a red suite — but scoped to the family the new
file joins, because the repo-wide suite is pre-existing red (ADR gap G2).

**Checks (baseline, expected green).**
```
cd src/tui
bun test src/runtime-process.stream-protocol.test.ts \
         src/runtime-process.tool-progress.test.ts \
         src/runtime-process.unknown-events.test.ts     # 14 pass, 0 fail (verified this session)
```
Record: bun `1.3.14`. Do **not** run `bun run test` as the gate — it is repo-wide red (G2). Do **not**
block on the two unrelated scratchpad WebSocket/loopback failures surfaced by `bun test src/`.

**Rollback.** n/a (read-only).

### WI-1a — extract host prompt functions into `src/tui/src/system-prompt.ts` (production, behavior-preserving) — **G3 APPROVED 2026-07-09**

**Purpose.** Make `systemPromptForWorkspace` / `materializeSystemPromptArg` importable in isolation so
scenarios 1–3 observe the **real** #76 host logic (survey finding 1; D-P2). This exceeded the ADR's /
handoff's originally-sanctioned production-change scope (only the scenario-4 helpers were authorized);
the ADR owner **approved** the extension on 2026-07-09 (ADR gap G3), on the ground that it is the same
behavior-preserving-extraction category already sanctioned for scenario 4. Proceed as written.

**File-level changes.**
- **New** `src/tui/src/system-prompt.ts`: move the bodies of `systemPromptForWorkspace` (`index.ts:409-421`)
  and `materializeSystemPromptArg` (`index.ts:430-449`) **verbatim**; add `export` to both; import fs/path
  in **index.ts's own style** — `import * as fs from "fs"; import * as path from "path";` (verified
  `index.ts:20-21`). Keep the doc comment on `materializeSystemPromptArg` (`index.ts:423-429`).
- **Edit** `src/tui/src/index.ts`: delete the two function definitions (verified the only other
  occurrences are the two call sites + doc comments — grep this session); add `import {
  systemPromptForWorkspace, materializeSystemPromptArg } from "./system-prompt.js";`. Call sites
  (`:741`, `:766`) unchanged. `main()`'s self-execution (`:1007`) untouched.

**Alternative the owner may prefer (equal G3 weight):** keep both functions in `index.ts`, add `export`
to each, and guard the launch with `if (import.meta.main) main().catch(...)`. Rejected as the default
because it changes `index.ts`'s entry behavior (relies on `import.meta.main` being true under the real
launch path), whereas the module extraction leaves `main()` untouched.

**Behavior-preserving because:** pure textual move; both functions reference only `fs`/`path`/`process`,
no `index.ts`-local symbols. `main()`'s self-execution (`:1007`) is untouched.

**Verification.**
```
cd src/tui && bun test src/runtime-process.stream-protocol.test.ts   # family still 9 pass (no regression)
grep -n 'from "./system-prompt.js"' src/index.ts                     # import present
grep -nE 'export function (systemPromptForWorkspace|materializeSystemPromptArg)' src/system-prompt.ts
```
**Teeth check.** Deferred to WI-2/3/4 (the scenarios are the teeth for this extraction).
**Rollback.** `git checkout src/tui/src/index.ts && rm src/tui/src/system-prompt.ts`.

### WI-1b — extract `buildChildEnv` / `buildSupervisorArgs` in `runtime-process.ts` (production, behavior-preserving)

**Purpose.** Make scenario 4's env/args assertions reachable without a real spawn (survey finding 2;
D-P3). This is the change the handoff explicitly sanctioned.

**File-level changes (`src/tui/src/runtime-process.ts`).**
- Add exported `buildChildEnv(workdir: string, profile: string, openaiBaseUrl: string, aiOptionsJson:
  string): NodeJS.ProcessEnv` containing current lines **`:342-468`** (base `childEnv` literal +
  `AILANG_STDLIB_PATH` branch + `MOTOKO_OTEL` block + the `openaiBaseUrl`/`aiOptionsJson` forwards),
  `return childEnv;`. Reads `process.env` and `process.stdin.isTTY` exactly as today.
- Add exported `buildSupervisorArgs(resolvedProfile: string, model: string, workdir: string, port:
  number, systemPrompt: string, task: string): string[]` containing current lines **`:497-510`**
  (`--profile`…`--port` + the `systemPrompt.trim() !== ""` guarded `--system-prompt` push at `:507-508`
  + `supervisorArgs.push(task)`), `return supervisorArgs;`. Uses module-level `supervisorWorkdirArg`.
- In the constructor: replace `:342-468` with `const childEnv = buildChildEnv(workdir, profile,
  openaiBaseUrl, aiOptionsJson);`; **leave `:470-495` unchanged** (the `mirror*` side-effects +
  `MOTOKO_PROFILE_DIR` rewrite still mutate `childEnv`); replace `:497-510` with `const supervisorArgs =
  buildSupervisorArgs(resolvedProfile, model, workdir, port, systemPrompt, task);`.

**Behavior-preserving because:** pure textual cut; the moved blocks reference only the new params +
module globals; the mirror side-effects and their ordering are untouched (D-P3).

**Verification.**
```
cd src/tui && bun test src/runtime-process.stream-protocol.test.ts   # family still 9 pass
grep -nE 'export function (buildChildEnv|buildSupervisorArgs)' src/runtime-process.ts
```
**Teeth check.** Deferred to WI-5.
**Rollback.** `git checkout src/tui/src/runtime-process.ts`.

### WI-2 — `harness.external_system_md_materialized` (scenario 1)

**Purpose.** ADR-003 crit 2 — the shipped #76 fix **is** materialization.

**Test (in `src/tui/src/harness-dst.test.ts`), over `materializeSystemPromptArg(extPath, workdir)`.**
- Fixtures: `workdir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-"))`; an **out-of-workspace**
  source at a *second* `mkdtemp` dir (so the source is genuinely outside `workdir`), content e.g. a
  multi-line string with a trailing newline.
- Assert (contract, thick):
  - return value is non-null and equals `path.join(path.resolve(workdir), ".motoko-system-prompt.md")`;
  - **`fs.readFileSync(dest, "utf8")` byte-equals the source content**;
  - `path.relative(path.resolve(workdir), dest)` does **not** start with `..` and is not absolute
    (dest **inside** workdir);
  - the external source path is outside workdir (`path.relative(workdir, srcAbs)` starts `..`) yet was
    still captured.
- **Must fail against a build that skips materialization** (crit 2): the assertion set (dest exists,
  content byte-equal, dest-inside-workdir) fails if the source is left out-of-sandbox / not copied.

**Verification.** `cd src/tui && bun test src/harness-dst.test.ts` (this test green).
**Teeth check.** Point the assertion at the **source** path instead of `dest` → dest-inside-workdir
must FAIL (source is outside); revert.
**Rollback.** Remove the `describe`/`it` block.

### WI-3 — `harness.workspace_system_md_not_rewritten` (scenario 2)

**Purpose.** ADR-003 crit — an in-workspace prompt is delivered by reference, not rewritten.

**Test, over `systemPromptForWorkspace(projectRoot, workdir)`.**
- Fixtures: `workdir` = mkdtemp; write a file **inside** it, e.g. `<workdir>/prompt.md`; set
  `process.env.SYSTEM_MD = "prompt.md"` (workdir-relative); **no** `--system-prompt` in `process.argv`.
  `projectRoot` = workdir (or a sibling — the configured `SYSTEM_MD` wins the resolution at `index.ts:411`).
- Assert (contract): return value === `"prompt.md"` (the workdir-relative path, unchanged); **no**
  `.motoko-system-prompt.md` exists in `workdir` (`!fs.existsSync(path.join(workdir,
  ".motoko-system-prompt.md"))`).
- Edge sub-case — the `"."` branch (`index.ts:418`; the handoff cites `:417`, actual is `:418` — ADR
  gap G4). `systemPromptForWorkspace` returns `"."` **only when the configured path resolves to the
  workdir directory itself** (`rel === ""`), not for a child file. Cover it directly: set
  `process.env.SYSTEM_MD = path.resolve(workdir)` (absolute), then assert the return is `"."`
  (`existsSync(workdir)` is true since it is a directory). This pins the one non-obvious return in the
  function.

**Verification / Teeth / Rollback.** As WI-2. Teeth: create a `.motoko-system-prompt.md` in workdir
before the assertion → the "no managed file written" assertion must FAIL; revert.

### WI-4 — `harness.out_of_sandbox_or_missing_system_md_yields_empty` (scenario 3)

**Purpose.** ADR-003 crit 4 — the host resolves to empty on missing / escaping input; the **loud**
rejection lives in-core and is **absent in headless mode** (Finding 5), so this Layer-2 scenario is the
operative guard there. **Record this in a test-file comment** (the ADR reporting expects the note).

**Test, three cases.**
- Missing file: `SYSTEM_MD` points at a non-existent in-workdir path ⇒ `systemPromptForWorkspace`
  returns `""` (`index.ts:414`).
- Sandbox escape: **create a real file in a second `mkdtemp` dir outside `workdir`** and set
  `SYSTEM_MD` to its absolute path ⇒ `""` (`rel` starts `..`/absolute, `index.ts:419`). The file
  **must exist**, else the missing branch (`:414`) fires first and the escape branch (`:419`) is never
  exercised — both return `""` so the test would pass for the wrong reason.
- Unreadable materialization source: `materializeSystemPromptArg(<path to a dir, or a missing file>,
  workdir)` ⇒ returns `null` (and logs to stderr, `index.ts:438`). Assert `null`; optionally spy on
  `console.error` to confirm the log (mechanism — keep thin).

**Verification / Teeth / Rollback.** As WI-2. Teeth: feed a **valid in-workdir** file to the
missing-case assertion → the `=== ""` assertion must FAIL; revert.

### WI-5 — `harness.child_env_sandbox_and_prompt_by_reference` (scenario 4)

**Purpose.** ADR-003 crit 3 — the prompt reaches the child by **reference**, `SYSTEM_MD` never rides
the child env, and the sandbox is set. Must **fail** if a future change reintroduces `SYSTEM_MD` into
`childEnv` without materialization.

**Test, over the WI-1b helpers (no spawn).**
- **Set `process.env.SYSTEM_MD` to a sentinel** (e.g. `"/tmp/leak-sentinel.md"`) first, so the test
  proves the parent's `SYSTEM_MD` is **not forwarded** — not merely that it happened to be unset.
  `childEnv = buildChildEnv(workdir, "someprofile", "", "")`. Assert (contract):
  `childEnv.AILANG_FS_SANDBOX === workdir`; `!("SYSTEM_MD" in childEnv)` (SYSTEM_MD **absent** despite
  being present in `process.env`).
- `args = buildSupervisorArgs("someprofile", "some/model", workdir, 12345, "prompt.md", "do a task")`.
  Assert (contract): `args` contains the **adjacent pair** `["--system-prompt", "prompt.md"]` (find
  index of `"--system-prompt"`, assert `args[i+1] === "prompt.md"`); and with `systemPrompt = ""`,
  **no** `--system-prompt` entry appears (the `:507` guard).
- Save/restore `process.stdin.isTTY`/`process.env` as needed (mechanism — `buildChildEnv` reads them).

**Verification.** `cd src/tui && bun test src/harness-dst.test.ts`.
**Teeth check (the crit-3 regression teeth).** Temporarily add `SYSTEM_MD: "x"` to the `buildChildEnv`
literal → the `!("SYSTEM_MD" in childEnv)` assertion must FAIL; revert. Also temporarily drop the
`--system-prompt` push → the pair assertion must FAIL; revert.
**Rollback.** Remove the `describe`/`it` block.

### WI-6 — final gate

Run the full new file + confirm no scope leakage:
```
cd src/tui
bun test src/harness-dst.test.ts                                  # 4 scenarios green
grep -nE 'spawn|child_process|fetch|http|net\.' src/harness-dst.test.ts || echo "good: no spawn/network"
grep -nE 'from "bun:test"' src/harness-dst.test.ts && echo "FIX: use @jest/globals" || echo "good: @jest/globals"
# no AILANG touched:
git status --porcelain | grep -E '\.ail$' && echo "FIX: .ail changed" || echo "good: no .ail"
```

---

## Acceptance gate — the six ADR-003 §"Acceptance criteria" (final checklist)

> **G3 approved 2026-07-09**, so all six criteria are in scope for this plan. (Historical note: crits
> 1/2/4 cover scenarios 1–3, which were contingent on the G3 decision via WI-1a; crit 3 + crits 5–6
> were always reachable via the handoff-authorized scenario 4.)

1. **Four Layer-2 scenarios green** under `bun test src/tui/src/harness-dst.test.ts`, each using a
   `mkdtemp` workdir and restoring `process.env`/`process.argv`; no AILANG, no spawn, no network; each
   test name **is** its scenario id. → WI-2..WI-5 + WI-6 grep.
2. **`external_system_md_materialized` asserts content byte-equality + dest-inside-workdir** and fails
   against a build that skips materialization. → WI-2 + its teeth check.
3. **`child_env_sandbox_and_prompt_by_reference` asserts `AILANG_FS_SANDBOX === workdir`, `SYSTEM_MD ∉
   keys(childEnv)`, and a `--system-prompt <relpath>` pair**, and **fails** if `SYSTEM_MD` is
   reintroduced into `childEnv`. → WI-5 + its teeth check.
4. **`out_of_sandbox_or_missing_system_md_yields_empty` proves `""`/`null`** for missing + escaping
   paths, and the file records the loud rejection is **in-core and absent in headless**. → WI-4 +
   its comment.
5. **The two gated scenarios stay specified-but-unregistered** (no live runner) with their
   general-scrub-class scope note. → not touched by this plan (Out of scope); confirm no new
   registration references them.
6. **No scenario depends on real providers, live network, effect-handler mocking, or a bespoke
   recorder.** → WI-6 grep + design (helpers are pure).

---

## ADR gaps found

The ADR-003 anchors and semantics were fresh and held on re-verification. These are gaps in the ADR's
**assumptions about testability / preconditions**, surfaced only by building the plan:

- **G1 (material) — runner identity.** ADR crit 1 + §Preconditions say "`bun test` runs the existing
  `runtime-process.*.test.ts` suite." At HEAD the family runs under **jest** (`@jest/globals`), invoked
  by the npm script `bun node_modules/.bin/jest --testPathPattern='src/.*\.test\.ts'`; **bare `bun
  test` does not discover the `src/*.test.ts` family** (it runs only `test/path-guard.test.ts`).
  *Resolved in-plan* (D-P1): `bun test <explicit path>` **does** run a `@jest/globals` file green
  (verified), so the ADR's command works with the explicit path and `@jest/globals` imports. Not a
  blocker; the ADR's precondition wording is inaccurate.
- **G2 (material) — "src/tui is green" is false at HEAD.** `bun run test` (the npm/CI runner, jest
  **under bun**) is entirely broken: 31/31 suites fail with **0 tests run** (`TypeError: Attempted to
  assign to readonly property` inside `jest-runtime` — jest is a node tool run under bun). Under real
  **node**, jest = 15 failed suites / 1 failed test. `bun test src/` (native) = **2 failed** (unrelated
  scratchpad WebSocket/loopback flakes) / 226 passed. *Resolved in-plan* (D-P5, WI-0): the **runtime-
  process family the new file joins is green under bun-native (14/14)**; gate on that slice, not the
  pre-existing repo-wide red. The ADR should narrow its precondition accordingly.
- **G3 (material) — scenarios 1–3 are not directly bun-testable. → APPROVED 2026-07-09.** The ADR
  (Decision drivers, Decision detail 2) treats `systemPromptForWorkspace` / `materializeSystemPromptArg`
  as "bun-test-able directly." At HEAD both are **unexported** and `index.ts` **self-executes `main()`**
  (`:1007`), so they are unreachable without a production change. The handoff sanctioned only the
  scenario-4 `buildChildEnv`/`buildSupervisorArgs` extraction. This plan proposed a second,
  same-category behavior-preserving extraction (WI-1a → `system-prompt.ts`); inlining was rejected
  (D-P2, because crit 2 requires catching the real function regressing).
  **Decision:** the ADR owner **approved** the WI-1a module extraction on 2026-07-09 (rationale: same
  behavior-preserving-extraction category already sanctioned for scenario 4; the alternative
  `import.meta.main` guard was declined in favor of the extraction because it leaves `main()`'s entry
  behavior untouched). WI-1a and scenarios 1–3 are unblocked; all six acceptance criteria are in scope.
- **G4 (trivial) — line drift.** The handoff cites the `"."`-root-return at `index.ts:417`; actual is
  **`:418`**. (The ADR grounding log does not cite that line.) Also the ADR grounding log lists the
  materialization write at `:441`; `:441` constructs the `dest` path literal, the `writeFileSync` is at
  `:443`. Cosmetic; no impact.

---

## Anchor re-verification log (HEAD `09751cd`, verified this session; `df85703` ancestor, no newer `src/tui` commit)

- Host materialization — `src/tui/src/index.ts`: `systemPromptForWorkspace` `:409` (`""` on missing
  `:414`, `"."` on root `:418`, `""` on escape `:419`); `materializeSystemPromptArg` `:430`
  (`readFileSync` source `:436`, `null`+`console.error` on unreadable `:438`, `dest` literal `:441`,
  `writeFileSync` `:443`); `--system-prompt` flag parse `:647-655`; `SYSTEM_MD` repoint `:740-744`;
  `systemPromptForWorkspace` call site `:766`; **`main()` self-executes `:1007`**; both host fns
  **unexported** (grep).
- Spawn / child env — `src/tui/src/runtime-process.ts`: `RuntimeProcess` class `:317`, constructor
  `:323`; `childEnv` literal `:342-411` (**`SYSTEM_MD` absent**), `AILANG_FS_SANDBOX: workdir` `:351`,
  headless-by-TTY `:361-363`; pure env block ends `:468`; `AILANG_STDLIB_PATH` `:417-419`; `MOTOKO_OTEL`
  block `:424-459`; openai/aiOptions forwards `:467-468`; `mirrorProfileFromRepo` `:238`/call `:478`;
  `mirrorAbsoluteProfile` `:274`/call `:484`; `MOTOKO_PROFILE_DIR` rewrite `:488-495`; `supervisorArgs`
  `:497-510` (`--system-prompt` push `:507-508`); `supervisorWorkdirArg` `:223`; `spawn` `:512`, `env:
  childEnv` `:531`. Existing exported test helpers `:103/:117/:146` (pattern for the new exports).
  `buildChildEnv`/`buildSupervisorArgs` names **free** (grep). **No `autoForwardedEnvKeys`** (grep,
  reconfirms ADR Finding 1).
- Absent on this branch (reconfirmed): `src/tui/src/runtime-process-env.test.ts` (ADR Finding 4);
  `autoForwardedEnvKeys`.
- Runner facts (this session): npm `test` script `src/tui/package.json:9` = `bun node_modules/.bin/jest
  --testPathPattern='src/.*\.test\.ts'`; family uses `@jest/globals`; `bun 1.3.14`; `node v22.23.1`.
- Superseded by ADR-003 (do not re-plan): the two gated AILANG scenarios; WI-1/WI-2; the L3 probe.
