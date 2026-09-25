# Handoff: write the Layer-2 harness DST plan

Audience: a fresh agent session. You are deliberately fresh — see
`../004_phase_core_refactor/NOTE-plan-authoring-session-choice.md` for why the plan is written by
you and not by the session that wrote/re-grounded ADR-003. Your freshness is also a test: **if you
cannot produce this plan from ADR-003 alone, the ADR has a gap — report the gap, don't guess around
it.** Collect any such gaps in an "ADR gaps found" section of the plan (empty is a valid finding).

## Mission

Write `PLAN-harness-boundary-dst.md` in this directory (`001_DST/`): the implementation plan for the
**four live Layer-2 scenarios** of
`ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md` — a single net-new
`bun test` file, `src/tui/src/harness-dst.test.ts`. Do NOT plan the gated AILANG scenarios, do NOT
plan WI-1/WI-2, and do NOT start implementing.

## Reading order

1. `ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md` — **normative**.
   Your acceptance criteria are its §"Acceptance criteria" (items 1–6). Also read §"Decision detail 1"
   (the re-grounded `harness.*` id table — each row names the scenario and its invariants), §"Decision
   detail 2" (scope split), and the §"Grounding and anchor log" (your `file:line` starting points).
   Read the Consequences §"Long-term: pure-AILANG headless" — it dictates how to shape assertions
   (below).
2. `../004_phase_core_refactor/NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md` and
   `../004_phase_core_refactor/NOTE-env-manifest-single-source-and-drift-guard.md` — **context only**.
   ADR-003 Findings 1 & 4 flag that these NOTEs carry **stale anchors** (`autoForwardedEnvKeys`
   "verified at HEAD" is wrong; `runtime-process-env.test.ts` does not exist). Do not trust their
   `file:line` claims.
3. `PLAN-compaction-dst-scenarios.md` (this dir) — the house style for a DST plan in this project.

## Non-negotiable discipline (the staleness lesson, made procedural)

The re-grounding session verified every ADR-003 anchor against HEAD **`df85703`** on 2026-07-09 —
they are fresh, not hours-stale. **But still re-verify**, because your plan is denser in citations
than the ADR and this project's proven failure mode is trusting document-recorded source facts after
the source moved:

- `git log --oneline -20 -- src/tui/` first. Note any commit newer than `df85703` touching
  `src/tui/src/index.ts`, `runtime-process.ts`, or `config.ts`; if any exist, treat every inherited
  citation as suspect until re-checked.
- Every source claim in YOUR plan carries a `file:line` you verified yourself at HEAD.
- The graph tool (`tools/code-graph/`, ref `AGENTS.md`) is for the AILANG side; Layer-2 is pure TS,
  so `rg`/Read are your tools here. Re-run `tools/code-graph/extract.sh` only if you cite AILANG
  anchors (you shouldn't need to — Layer-2 touches no `.ail`).

## Deliverables (from ADR-003 — re-read it; this is a summary, not a substitute)

One file, `src/tui/src/harness-dst.test.ts`, four tests whose **names ARE the scenario ids** (ADR-003
reporting contract). Per-test: `mkdtemp` workdir, save/restore `process.env.SYSTEM_MD` and
`process.argv`. No AILANG, no `spawn`, no network. Fresh-grounded anchors (re-verify before use):

1. **`harness.external_system_md_materialized`** — `materializeSystemPromptArg(extPath, workdir)`
   (`index.ts:430`) reads an **out-of-workspace** source (`readFileSync` `:436`) and writes it to
   `<workdir>/.motoko-system-prompt.md` (`:441`). Assert: dest content **byte-equals** source; dest
   resolves **inside** `workdir`; an external source is still captured. Must **fail** against a build
   that skips materialization (source left out-of-sandbox).
2. **`harness.workspace_system_md_not_rewritten`** — with `SYSTEM_MD` at an in-workspace file and
   **no** `--system-prompt` flag, `systemPromptForWorkspace` (`index.ts:409`) returns the
   workdir-relative path unchanged and **no** `.motoko-system-prompt.md` is written. (Note the edge:
   the function returns `"."` when the file sits at the workdir root — `index.ts:417`.)
3. **`harness.out_of_sandbox_or_missing_system_md_yields_empty`** — `systemPromptForWorkspace` returns
   `""` for a missing file (`index.ts:414`) or a sandbox-escaping one (`rel` starts `..`/absolute,
   `:419`); `materializeSystemPromptArg` returns `null` + logs on an unreadable source (`:438`). The
   plan should record that the **loud** rejection is in-core and **absent in headless mode**
   (ADR-003 Finding 5) — so this Layer-2 scenario is the operative guard there.
4. **`harness.child_env_sandbox_and_prompt_by_reference`** — assert `childEnv.AILANG_FS_SANDBOX ===
   workdir` (`runtime-process.ts:351`), `SYSTEM_MD` **absent** from `childEnv` (the literal at
   `:342`), and a `--system-prompt <relpath>` pair pushed into `supervisorArgs` (`:508`). Must **fail**
   if a future change reintroduces `SYSTEM_MD` into `childEnv` without materialization. **Survey task
   for the plan:** `childEnv` is a hand-maintained literal and the `--system-prompt` push sits inside
   `RuntimeProcess`'s spawn method (`spawn` at `:512`, `env: childEnv` at `:531`). Determine whether
   these are reachable/assertable without a real spawn — extract a pure `buildChildEnv` /
   `buildSupervisorArgs` helper if not, and make that refactor an explicit, justified step (keep it
   behavior-preserving; it is the only production-code change the plan may propose).

## Assertion shape (from ADR-003 Consequences §"Long-term: pure-AILANG headless")

The long-term goal is pure-AILANG headless; the launcher tier (this TS) is slated to become
`launcher.ail`. So write assertions as a **language-neutral contract** that will port to a future
AILANG scenario: assert **thick** on content byte-equality, dest-inside-sandbox, empty-on-missing/
escape, prompt-carried-by-reference. Keep **thin** the TS-mechanism-specific parts that WON'T port —
`process.env.SYSTEM_MD` repointing (`index.ts:743`), `process.argv` save/restore, and the literal
`.motoko-system-prompt.md` filename. The plan should note which assertions are contract vs. mechanism.

## Preconditions (ADR-003 §"Preconditions")

- Confirm `src/tui` is green and `bun test` runs the existing `runtime-process.*.test.ts` suite; the
  new file joins that runner. **Do not add DST on top of a red suite.** State the exact `bun test`
  invocation and the `bun --version` you verified against.
- `harness-dst.test.ts` is **net-new** — not an extension of an existing family (ADR-003 Finding 4:
  `runtime-process-env.test.ts` does not exist).

## Plan output contract

Follow the `PLAN-compaction-dst-scenarios.md` house style. Must include: ordered steps with
file-level change lists; a per-step verification command (`bun test src/tui/src/harness-dst.test.ts`);
a rollback note per step; the six ADR-003 acceptance criteria as the final gate checklist; an "ADR
gaps found" section; an explicit "out of scope" list.

## Out of scope (do NOT plan these)

- The two **gated** AILANG scenarios `harness.env_manifest_complete` and
  `harness.childenv_covers_manifest` — blocked on WI-1 (`CORE_MAP`-derived `childEnv`) and WI-2
  (AILANG `env_manifest` export), neither on this branch. They guard the general scrub class, **not**
  #76's prompt (ADR-003 Finding 6). Leave them specified-in-the-ADR and unplanned.
- **WI-1 / WI-2** themselves (owned by the env-manifest NOTE's follow-up).
- **Re-guarding #76's in-core symptom in headless** (`require_system_prompt` policy work — separate WI).
- The **optional L3 runtime probe** (ADR-003 R11: the L2 ∘ in-core composition discharges the
  criterion; a probe is not required).
- **Compaction DST** (`ADR-002` + `PLAN-compaction-dst-scenarios.md`).

## Constraints

- Do not re-litigate ADR-003's decisions D1–D4. Contradictions between the ADR and HEAD source are
  findings for "ADR gaps found," not license to redesign.
- The only production-code change the plan may propose is a **behavior-preserving** extraction of
  `buildChildEnv` / `buildSupervisorArgs` if (and only if) the survey shows the assertions in scenario
  4 are otherwise unreachable without a real spawn. Everything else is net-new test code.
- Do not modify ADR-003 or the NOTEs. The plan is a new file.
