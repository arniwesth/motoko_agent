# ADR-003: Harness-boundary DST, re-grounded on system-prompt materialization

Date: 2026-07-06
Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`
Grounded at: branch `arniwesth/mot-28-compaction-dst-scenarios`, HEAD `4786355`

Relates to:
- `001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — the original DST architecture,
  authored **2026-06-27 against the pre-refactor harness**. This ADR **supersedes its
  harness-boundary sections** ("Layer 2: Harness-Boundary DST", the four `harness.*` canonical ids,
  and the harness-relevant findings R1/R7/R11) and re-grounds them on the shipped system-prompt
  materialization path. ADR-001's layer model and CI discipline are retained by reference.
- `001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` — the **template** this ADR
  mirrors (retire stale bits, reuse what shipped, split scope, gate what isn't buildable yet). ADR-002
  explicitly deferred "Harness-boundary (PR #76) DST"; this is that deferred work.
- `004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` §5 — landed
  the in-core symptom guard `empty_system_prompt_rejected` (the `seal` refusal of an empty served
  prefix). This ADR **corrects and bounds** that ADR's §5 host-boundary claims against HEAD.
- `004_phase_core_refactor/NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md` — the
  policy-vs-mechanism split (settled: move the *policy*, not the spawn *mechanism*). **Its central
  anchor is stale** — see Finding 1.
- `004_phase_core_refactor/NOTE-env-manifest-single-source-and-drift-guard.md` — the single-source
  manifest fix (derive `childEnv` from `CORE_MAP`) + the AILANG manifest-completeness scenario. This
  is the gated path; the NOTE correctly records that its precedent (PR #76 `c5b0924`) is **not on this
  branch**.
- PR **#76** (`fix(harness): serve the system prompt reliably`) — the bug class this DST turns into
  standing law.

---

## First-task determination: ADR, not straight-to-plan

The handoff asked me to decide early whether a full ADR is warranted or the harness sections are
plan-ready. **A full ADR is warranted**, for the same reason ADR-002 needed one: the upstream docs
describe an architecture that only *partly* shipped, and a plan built directly on them would encode
stale anchors. Grounding the NOTEs + ADR-001's harness sections against HEAD surfaced **five material
corrections** (Findings 1–5 below), three of which change *which* scenarios are worth building. That
is a re-grounding decision, not a projection of a settled decision onto source — so it belongs in an
ADR (context-heavy synthesis), and the plan follows from it. This lands as **`001_DST/ADR-003`**,
parallel to how ADR-002 re-grounded ADR-001's compaction sections.

## TL;DR

The harness that actually shipped on this branch **does not match** either ADR-001's four `harness.*`
scenarios or the "verified at HEAD" anchors in the policy-vs-mechanism NOTE. Concretely:

- `SYSTEM_MD` is **not forwarded to the child env at all** — the ADR-001 id
  `harness.system_md_forwarded_to_child_env` describes an architecture that did not ship.
- The system prompt reaches the sandboxed child as a **workdir-relative path argv** whose **content is
  materialized into the workdir** (`materializeSystemPromptArg`), not by env and not "by value."
- The `CORE_MAP`-derived allowlist (`autoForwardedEnvKeys`, PR #76 `c5b0924`) that the NOTEs treat as
  landed **does not exist in the repo**; `childEnv` is still a hand-maintained literal.
- The in-core backstop `empty_system_prompt_rejected` that ADR-002 §5 relies on to say "#76's symptom
  is already guarded in-core" is **`require_system_prompt: not headless`** — i.e. **off in headless /
  eval-harness runs**, the exact path #76 bit.

**Decision:**

1. **Re-ground the four `harness.*` ids** against the materialization path (§Decision detail 1):
   retire `system_md_forwarded_to_child_env`, re-point `external_system_md_materialized` and
   `workspace_system_md_not_rewritten` at `materializeSystemPromptArg` / `systemPromptForWorkspace`,
   and split `missing_system_md_fails_loudly` into a host half (empty resolution) and an in-core half
   (the `seal` gate, non-headless).
2. **Layer-2 materialization DST lands now (D1).** The #76 fix on this branch is host-side
   materialization + a workdir-relative-path argv. Its DST is a small **bun-test** suite over the two
   pure host functions (`materializeSystemPromptArg`, `systemPromptForWorkspace`) plus a spawn-arg /
   `childEnv`-shape assertion — no AILANG, no spawn, no providers. This is not redundant with the
   in-core guard: **in headless mode the in-core guard is off, so Layer-2 is the sole line of
   defense** for #76 (D3).
3. **The AILANG manifest-completeness scenario is specified-but-gated (D2).** It is the cheap
   high-value path the env-manifest NOTE proposes, but it has **nothing to check yet**: neither the
   `CORE_MAP`-derived `childEnv` (WI-1) nor an AILANG-owned `env_manifest` export (WI-2) exists on this
   branch. Fix its id + invariant now; gate it on WI-1/WI-2 landing. Note it protects the **residual
   general scrub class** (`MOTOKO_REPO`, pricing vars), **not #76's system prompt**, which has moved
   off the env-forwarding mechanism entirely.
4. **Resolve R1/R7/R11 for the harness layer** (§Decision detail 3), including defining the Layer-2
   trace/reporting contract and collapsing the L3 "runtime probe" into an L2 ∘ in-core composition.

---

## Context

"Harness-boundary DST for #76" reads as: prove that a system prompt configured out-of-workspace (an
external `SYSTEM_MD`, or an eval-adapter `--system-prompt` path) reaches the AILANG child **readable
under `AILANG_FS_SANDBOX=workdir`**, instead of silently resolving to a 0-char prompt. ADR-001 modeled
this as four `harness.*` scenarios centered on **forwarding `SYSTEM_MD` into the child env**. The
shipped architecture does not forward `SYSTEM_MD` at all; it **materializes the content into the
sandbox and passes a workdir-relative path by argv**. Writing scenarios against ADR-001 unamended
would assert over a delivery mechanism that does not exist. This ADR re-establishes what is real at
HEAD and splits the work accordingly.

## Investigation findings (grounded at HEAD `4786355`, toolchain v0.26.0 / `3b52a24`)

1. **`autoForwardedEnvKeys` / the `CORE_MAP`-derived allowlist does not exist.** `grep -rn
   autoForwardedEnvKeys` over the repo returns nothing; `childEnv` is a **hand-maintained literal**
   (`src/tui/src/runtime-process.ts:342-411`) listing each key explicitly (`PATH`, API keys,
   `AILANG_FS_SANDBOX`, `MOTOKO_REPO`, pricing vars, …). The env-manifest NOTE is correct that PR #76
   `c5b0924` is "not present on this branch"; the **policy-vs-mechanism NOTE's "verified 2026-07-06,
   HEAD … `autoForwardedEnvKeys` derives the allowlist from config maps" is stale/wrong** and must not
   be cited as shipped. Any DST that asserts "adding a `CORE_MAP` entry auto-forwards it" has no
   referent yet.

2. **`SYSTEM_MD` is deliberately not in `childEnv`.** It appears nowhere in the child env literal
   (`runtime-process.ts:342-411`). The prompt is delivered instead as a **`--system-prompt <path>`
   supervisor argv** (`runtime-process.ts:507-508`), where the value is
   `systemPromptForWorkspace(projectRoot, workdir)` (`index.ts:766`) — a **workdir-relative path**
   (`index.ts:409-421`, `""` if the file is missing or escapes the sandbox). So ADR-001's
   `harness.system_md_forwarded_to_child_env` and its invariant "child env `SYSTEM_MD` points to a
   sandbox-readable path" describe a mechanism that **did not ship**.

3. **The #76 fix is content materialization + sandbox-relative-path argv, not "by value."** An
   external `--system-prompt` path (from the eval adapter) or `SYSTEM_MD` is handled by
   `materializeSystemPromptArg(flagValue, workdir)` (`index.ts:430-449`): it `readFileSync`s the source
   (any path, incl. outside the workspace), **writes the content into `<workdir>/.motoko-system-prompt.md`**,
   and repoints `process.env.SYSTEM_MD` at that in-sandbox file (`index.ts:740-744`).
   `systemPromptForWorkspace` then converts it to a workdir-relative path; core reads that path under
   the sandbox (`rpc.ail:197-201`, `readFile(system_md_path)`; argv precedence at `config.ail:487`,
   parse at `config.ail:226`). **Correction to 004 ADR-002 §5:** "delivered by value as a
   `--system-prompt` argv … an argv cannot be scrubbed" is imprecise — the argv carries a **path**, and
   correctness still depends on the **content being materialized inside the sandbox**. The env-scrub of
   `SYSTEM_MD` is moot not because the content is inlined, but because `SYSTEM_MD` is no longer the
   child's delivery channel at all.

4. **The referenced host test files do not exist.** ADR-001 Phase 2 and both NOTEs name
   `src/tui/src/runtime-process-env.test.ts` as the drift-guard / harness test home; it is **not on
   this branch** (`ls` → no such file). The existing `runtime-process.*.test.ts` files cover stream
   protocol, tool progress, and unknown events — none touch env/materialization. The Layer-2 suite is
   **net-new**, not an extension of an existing family.

5. **The in-core backstop is off in headless mode.** `require_system_prompt: not headless`
   (`session.ail:968`; `headless = getEnvOr("MOTOKO_HEADLESS","") == "1"` at `:960`). The launcher
   sets `MOTOKO_HEADLESS=1` whenever stdin is not a TTY (`runtime-process.ts:361-363`) — i.e. CI, the
   eval harness, and every non-interactive `--system-prompt` injection. In that path
   `seal_compacted_payload(..., require_system_prompt=false)` **does not reject** an empty prefix, so
   `empty_system_prompt_rejected` (004 ADR-002) provides **no coverage exactly where #76 bit**. The
   claim "#76's symptom is already guarded in-core" holds only for interactive runs. This is the
   decisive finding: Layer-2 materialization DST is **not** redundant with the in-core guard.

6. **The manifest/drift-guard path does not protect #76's system prompt.** Because `SYSTEM_MD` is not
   env-forwarded (Finding 2), deriving `childEnv` from `CORE_MAP` (WI-1) and an AILANG
   manifest-completeness scenario (WI-2) would guard the **residual general scrub class**
   (`MOTOKO_REPO`, `AILANG_OLLAMA_MAX_TOKENS`, pricing vars — the hand-list at
   `runtime-process.ts:368-410`), **not** the system prompt. The two tracks are orthogonal: #76 proper
   is a **materialization** problem (Layer-2), the scrub class is an **env-completeness** problem
   (gated AILANG scenario).

## Decision drivers

- Don't assert over a delivery mechanism that didn't ship (Findings 1–3). Every invariant needs a
  referent at HEAD.
- Target the **live** path: `materializeSystemPromptArg` + `systemPromptForWorkspace` +
  `--system-prompt` argv + `rpc.ail:197` readFile, not `SYSTEM_MD`-in-child-env.
- Prefer the cheapest layer that catches the bug. #76's host half is two pure-ish functions over the
  filesystem — bun-test-able directly, no AILANG runtime, no spawn, no providers.
- Keep DST decoupled from unbuilt seams: the AILANG manifest scenario waits on WI-1/WI-2 exactly as
  ADR-002's actual-token scenarios wait on ABI v3.
- Reuse existing reporting contracts: bun test for Layer-2; the `phase_c_l1_scenarios.ail` scenario-id
  + first-failed-invariant contract for the gated AILANG scenario.

---

## Decision detail

### 1. Re-ground the four `harness.*` ids

| ADR-001 id | Status at HEAD | Re-grounded form |
|---|---|---|
| `harness.external_system_md_materialized` | **Survives — central.** The shipped fix *is* materialization. | Layer-2: `materializeSystemPromptArg(extPath, workdir)` writes source content into `<workdir>/.motoko-system-prompt.md`; assert dest content byte-equals source, dest resolves **inside** `workdir`, and an external/out-of-workspace source is still captured. (`index.ts:430-449`) |
| `harness.workspace_system_md_not_rewritten` | **Survives, re-pointed.** | Layer-2: with `SYSTEM_MD` at an in-workspace file and **no** `--system-prompt` flag, `systemPromptForWorkspace` returns the workdir-relative path unchanged and **no** `.motoko-system-prompt.md` is written. (`index.ts:409-421`) |
| `harness.missing_system_md_fails_loudly` | **Split.** Host resolves to empty; loudness moved in-core (non-headless only, Finding 5). | Layer-2 host half `harness.out_of_sandbox_or_missing_system_md_yields_empty`: `systemPromptForWorkspace` returns `""` for a missing file (`index.ts:414`) or one escaping the sandbox (`rel` starts `..`/absolute, `:419`); `materializeSystemPromptArg` returns `null` + logs on unreadable source (`:438`). In-core half is **already covered** by `empty_system_prompt_rejected` (004 ADR-002) — **but only when `require_system_prompt` is true (non-headless)**; the headless gap is called out in D3, not re-guarded here. |
| `harness.system_md_forwarded_to_child_env` | **Retired.** Describes non-shipped architecture (Finding 2). | Replace with `harness.child_env_sandbox_and_prompt_by_reference`: assert `childEnv.AILANG_FS_SANDBOX === workdir` (`runtime-process.ts:351`), `SYSTEM_MD` is **absent** from `childEnv`, and the prompt is carried as a `--system-prompt <relpath>` entry in `supervisorArgs` (`:507-508`) — a sandbox-relative reference, not an env var. |

### 2. Scope split — Layer-2 now, AILANG manifest specified-but-gated (D1, D2)

**Land now (Layer-2 bun test; new file `src/tui/src/harness-dst.test.ts`; tmpdir fixtures + a
save/restore of `process.env.SYSTEM_MD`/`process.argv`; no AILANG, no spawn, no network):** the four
re-grounded scenarios above. These become standing law for the host half of #76 — and per D3 the sole
guard in headless mode.

**Specify but gate (on WI-1 `CORE_MAP`-derived `childEnv` **and** WI-2 AILANG-owned `env_manifest`,
per the env-manifest NOTE):**

- `harness.env_manifest_complete` — AILANG L0 (`--caps IO`, `phase_c_l1` profile): every `cfg.agent.*`
  / `cfg.tools.*` field core reads has a matching `env_manifest` entry wired to a `ports.env_get`
  read; "core needs env X but forgot to declare it" fails as a red scenario. *Blocked:* no
  `env_manifest` export exists.
- `harness.childenv_covers_manifest` — the one-line TS drift-guard `keys(childEnv) ⊇
  envVars(manifest)`. *Blocked:* `childEnv` is still a hand-list (Finding 1); there is no manifest to
  diff against.

Both guard the **general scrub class, not #76's prompt** (Finding 6); named here so the two tracks are
not conflated. No DST gate depends on WI-1/WI-2 until they land.

### 3. Resolve inherited ADR-001 findings for the harness layer

- **R1 (dangling #76 reference).** Resolved by describing the **bug class** — "an out-of-workspace
  `SYSTEM_MD` is unreadable under `AILANG_FS_SANDBOX=workdir`, yielding a 0-char system prompt" — and
  pinning it to the **shipped** shape: materialization (`index.ts:430`) + workdir-relative-path argv
  (`runtime-process.ts:508`) + in-core `seal` (004 ADR-002, non-headless). Explicitly record that PR
  #76's env-allowlist refactor (`c5b0924`) is **not on this branch**, so the number names a bug class,
  not a landed diff here.
- **R7 (per-layer effect satisfaction).** Layer-2 needs **no AILANG effects**: its "effects" are the
  real filesystem (a per-test `mkdtemp` workdir) and `process.env` — satisfied natively by bun test,
  no `--caps`, no effect-handler mocking. The **gated** AILANG scenario is pure `--caps IO` reading a
  generated manifest artifact (or a pure `env_manifest` export), matching the `phase_c_l1` dependency
  profile. No harness scenario touches `Net`.
- **R11 (undefined L3 "runtime probe").** For #76 the L3 probe **collapses**: the acceptance criterion
  "a configured non-empty prompt produces a non-empty runtime observation" is discharged by the
  composition **Layer-2 (materialization observable via function return values) ∘ in-core
  (`readFile(system_md_path)` at `rpc.ail:201`, then the `seal` gate)** — no bespoke probe binary or
  `std/ai.step` stub is required. Contract, if an end-to-end check is ever wanted (optional, not in
  scope): spawn the real `supervisor.ail` against a materialized prompt with a scripted/stub step and
  assert it does **not** emit the `rpc.ail:205` "system prompt file not found" warning — the probe
  must emit that warning event on a missing path and must refuse to use a path that escaped the
  sandbox. Given the headless gap (Finding 5), the **higher-value** end-to-end is a regression test
  that a headless run with a materialized prompt serves non-empty content, since the in-core `seal`
  won't.
- **Layer-2 reporting/trace contract (R4 analogue for this layer).** Layer-2 uses bun test's native
  `describe`/`test` naming: each test's name **is** the scenario id, so a failure prints the id and
  the failed assertion. Layer-2 does **not** reimplement the AILANG normalized-trace recorder; the
  `phase_c_l1` reporting contract (scenario id + first failed invariant + normalized trace) applies
  only to the gated AILANG `env_manifest_complete` scenario.

## Re-grounding / de-duplication map (do not re-implement)

| Old canonical id / claim | Status at HEAD |
|---|---|
| `harness.external_system_md_materialized` | **Re-implement** over `materializeSystemPromptArg` (was: forward external `SYSTEM_MD`) |
| `harness.workspace_system_md_not_rewritten` | **Re-implement** over `systemPromptForWorkspace` |
| `harness.missing_system_md_fails_loudly` | **Split**: host-empty (Layer-2) + in-core loud (`empty_system_prompt_rejected`, non-headless) |
| `harness.system_md_forwarded_to_child_env` | **Retired** → `harness.child_env_sandbox_and_prompt_by_reference` |
| ADR-002 §5 "delivered by value as argv" | **Corrected**: workdir-relative **path** argv + materialized content |
| policy-vs-mechanism NOTE "`autoForwardedEnvKeys` verified at HEAD" | **Stale**: does not exist; `childEnv` is a hand-list |
| `runtime-process-env.test.ts` (ADR-001 Phase 2, NOTEs) | **Absent**: Layer-2 suite is net-new (`harness-dst.test.ts`) |

## Preconditions (before implementing)

- Confirm `src/tui` test harness is green and `bun test` runs the existing `runtime-process.*.test.ts`
  suite (the new file joins that runner). Do not add DST on top of a red suite (ADR-001 Phase 0
  discipline).
- The gated scenarios require **WI-1** (derive `childEnv` from `CORE_MAP ∪ EXTENSION_MAPS`, i.e.
  re-land PR #76 `c5b0924` on this branch) and **WI-2** (AILANG `env_manifest` export + launcher
  codegen) from the env-manifest NOTE. Neither is landed; both are named blockers, not part of this
  DST.

## Out of scope

- **Landing WI-1/WI-2** (single-source manifest, `env_manifest` export). Named as the blocker for the
  gated scenarios; owned by the env-manifest NOTE's follow-up WI, not this DST.
- **Moving the spawn mechanism into core / AILANG-as-entry.** Settled (policy-vs-mechanism NOTE):
  blocked on `std/process` env/cwd/sandbox primitives (`backend.ail:5,:58` shows only
  `spawnProcess(cmd, args)` — no child-env arg), does not address the data-authority root, pays off
  only inside a larger rewrite. Long-horizon option, not this work.
- **Re-guarding #76's in-core symptom** — `empty_system_prompt_rejected` exists (004 ADR-002) for the
  non-headless path. This ADR *flags* the headless gap (Finding 5) but does not fix it in core; if a
  fix is wanted, it is `require_system_prompt` policy work, a separate WI.
- **Compaction DST** — its own track (`001_DST/ADR-002` + `PLAN-compaction-dst-scenarios.md`).

## Acceptance criteria

1. The four Layer-2 scenarios run green under `bun test src/tui/src/harness-dst.test.ts`, using a
   `mkdtemp` workdir and restoring `process.env`/`process.argv` per test; no AILANG, no spawn, no
   network. Each test name is its scenario id.
2. `harness.external_system_md_materialized` fails against a build that skips materialization (source
   left out-of-sandbox) and passes once `materializeSystemPromptArg` copies content into
   `<workdir>/.motoko-system-prompt.md`; it asserts **content byte-equality** and **dest-inside-workdir**.
3. `harness.child_env_sandbox_and_prompt_by_reference` asserts `AILANG_FS_SANDBOX === workdir`,
   `SYSTEM_MD ∉ keys(childEnv)`, and a `--system-prompt <relpath>` pair in `supervisorArgs`. It must
   **fail** if a future change reintroduces `SYSTEM_MD` into `childEnv` without materialization.
4. `harness.out_of_sandbox_or_missing_system_md_yields_empty` proves `""`/`null` for missing and
   sandbox-escaping paths, and the ADR records that the **loud** rejection is in-core and **absent in
   headless mode** — so this Layer-2 scenario is the operative guard there.
5. The two gated scenarios (`env_manifest_complete`, `childenv_covers_manifest`) are specified with ids
   + invariants and marked blocked-on-WI-1/WI-2; neither is registered in a live runner until the
   manifest lands. Their scope note states they guard the general scrub class, not #76's prompt.
6. No scenario depends on real providers, live network, effect-handler mocking, or a bespoke
   provider-call recorder.

## Consequences

Positive: the host half of #76 gains standing, fast (`bun test`) regression law that runs in the
headless path where the in-core guard is disabled; the DST design stops asserting over a
`SYSTEM_MD`-in-child-env mechanism that never shipped; ADR-002 §5 and the policy-vs-mechanism NOTE are
corrected against HEAD; the env-completeness track is precisely specified and cleanly separated from
the #76 prompt track, ready the day WI-1/WI-2 land.

Negative / accepted: the **general scrub class stays untested until WI-1/WI-2** (the manifest doesn't
exist yet) — made explicit rather than papered over. The **headless in-core gap** (empty prompt not
rejected when `MOTOKO_HEADLESS=1`) is documented but left to a separate policy WI; until then Layer-2
is the only guard there, which is exactly why it lands now.

## Rejected alternatives

- **Implement the four ADR-001 `harness.*` ids as written** — rejected: `system_md_forwarded_to_child_env`
  and its "child env `SYSTEM_MD`" invariant have no referent (Finding 2); the others need re-pointing
  from env-forwarding to materialization.
- **Build the AILANG manifest-completeness scenario now** (per the env-manifest NOTE as if landed) —
  rejected: `autoForwardedEnvKeys`/`env_manifest` don't exist (Finding 1); the scenario would have no
  manifest to check and would assert over nothing.
- **Treat the manifest/drift-guard as #76's DST** — rejected: `SYSTEM_MD` isn't env-forwarded
  (Finding 6); that path guards a different bug class.
- **Rely on `empty_system_prompt_rejected` alone and skip Layer-2** — rejected: it's off in headless
  mode (Finding 5), the exact context of #76.
- **Define a bespoke L3 runtime-probe binary** (ADR-001 R11) — rejected: the L2 ∘ in-core composition
  discharges the acceptance criterion; a probe is optional end-to-end polish, not a prerequisite.

## Decision log

- **D1** (2026-07-06): DST the **shipped host materialization path** now as a Layer-2 `bun test` suite
  over `materializeSystemPromptArg` / `systemPromptForWorkspace` + the `childEnv`/spawn-arg shape.
- **D2** (2026-07-06): **specify but gate** the AILANG `env_manifest_complete` scenario + the TS
  drift-guard on WI-1 (`CORE_MAP`-derived `childEnv`) and WI-2 (`env_manifest` export). They guard the
  general scrub class, not #76's prompt.
- **D3** (2026-07-06): Layer-2 is **not redundant** with the in-core guard, because
  `require_system_prompt: not headless` disables `empty_system_prompt_rejected` in the headless / eval
  path where #76 bit. Layer-2 is the operative guard there.
- **D4** (2026-07-06): supersede the **harness-boundary sections** of 001_DST/ADR-001 (the four
  `harness.*` ids, findings R1/R7/R11 for this layer); retain its layer model and CI discipline by
  reference.

## Grounding and anchor log (HEAD `4786355`, v0.26.0 / `3b52a24`)

- Host materialization: `src/tui/src/index.ts` — `systemPromptForWorkspace:409` (workdir-relative,
  `""` on missing `:414` / sandbox-escape `:419`), `materializeSystemPromptArg:430` (readFileSync
  source `:436`, write `<workdir>/.motoko-system-prompt.md` `:441`, `null`+log on unreadable `:438`),
  flag parse `:647-655`, repoint `SYSTEM_MD` `:740-744`, call site `:766`.
- Spawn / child env: `src/tui/src/runtime-process.ts` — hand-maintained `childEnv` literal `:342-411`
  (`SYSTEM_MD` absent), `AILANG_FS_SANDBOX: workdir` `:351`, headless-by-TTY `:361-363`,
  `mirrorProfileFromRepo` `:238`/`:478`, `--system-prompt` supervisor arg `:507-508`,
  `spawn(..., { env: childEnv })` `:512/:531`. **No `autoForwardedEnvKeys`** (grep: absent).
- Manifest source (for gated WI): `src/tui/src/config.ts` — `CORE_MAP:22`,
  `"agent.system_prompt": { env: "SYSTEM_MD" }` `:30`, `EXTENSION_MAPS:57`.
- In-core delivery: `src/core/config.ail` — argv parse `--system-prompt` `:226`, argv-over-config
  precedence `:487`; `src/core/rpc.ail` — `cfg.agent.system_prompt` (a **path**) `:197`,
  `readFile`/missing-warning `:200-205`, `dispatch_build_system_prompt` `:228`.
- In-core guard + headless gate: `src/core/session.ail` — `headless` `:960`, `require_system_prompt:
  not headless` `:968`, `seal` call `:1398`, `SystemPromptEmpty` error `:1400`; `seal_compacted_payload`
  `src/core/phase_vocab.ail:140`; existing scenario `empty_system_prompt_rejected` in
  `scripts/phase_c_l1_scenarios.ail`.
- Absent on this branch (verified): `src/tui/src/runtime-process-env.test.ts`, `autoForwardedEnvKeys`,
  PR #76 `c5b0924`.
- AILANG-as-entry (out of scope): `src/core/backend.ail:5` `import std/process (spawnProcess,
  ProcessHandle)`, spawn `:58` — no child-env/cwd/sandbox param.
- Superseded: `001_DST/ADR-001` harness-boundary sections + R1/R7/R11 for this layer.
- **Re-verify before implementing:** the two NOTEs carried stale anchors (Findings 1, 4); re-run
  `grep autoForwardedEnvKeys` and `ls runtime-process-env.test.ts` before trusting any secondhand
  "verified at HEAD" claim.
