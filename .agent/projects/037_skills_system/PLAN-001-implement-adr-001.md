# PLAN-001: implement ADR-001 v0.3 — the skills extension

Date: 2026-10-03. Status: **Proposed — not started. Parts P0 and P1 are grounded and can be
handed off now; P2 to P6 are sized in outline and are written in detail only after gate G1.**
Grounded at HEAD `cf54dff9` on `main`; `src`, `packages`, `scripts`, `tools`, the `Makefile` and
the CI workflow are unchanged since `21ba95c9`, where the research began, for every path the ADR
cites. ADR-001 is **Accepted v0.3**. AILANG v0.47.2, extension ABI 8.0.

This plan follows the repository's standing disciplines and says where each applies:
**sequence by source surface** (`.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`):
each part owns one surface and ends in one green state, and a handoff is written only for the
next part that can be grounded; **re-ground inherited anchors**
(`re-ground-inherited-anchors-before-building.md`): every part starts by checking the
coordinates it was handed; **detector placement**: each check is a test or a make target the
author runs before submitting, not something a review is expected to catch.

## 0. Preconditions and standing rules

1. **The ADR is the decision record.** A part that finds the ADR wrong stops, records the
   evidence, and the ADR is revised with the operator's ruling. It does not build around the
   disagreement. Three questions are known to be able to do this, and all three are answered
   in P1 (§7).
2. **A shared tree.** Other live sessions work in this checkout, and the root manifest, the
   lock and the generated registry are shared files. P1 runs in a git worktree beside the
   checkout, as `../motoko_agent-fix3` already does. P2 onward runs on the dedicated branch
   `feat/skills-extension`, created 2026-10-03 from `main` at `cf54dff9`, in its own worktree at
   `/workspaces/motoko_agent-skills`.
   Nothing in this plan edits `ailang.lock` or `registry_generated.ail` in the shared tree
   before P5.
3. **What is committed.** The project folder and the deletion of
   `design_docs/planned/m-motoko-ext-skills-import.md` are the first commit on
   `feat/skills-extension` (2026-10-03, at the operator's instruction). An unrelated change to
   `tools/code-graph/` is still uncommitted in the shared checkout; it gets a branch of its own,
   which is the operator's call and blocks nothing here.
4. **Heavy runs one at a time.** The DST targets are slow and the machine is shared.
5. **Spend.** P1 calls models through OpenRouter. The research's proxy run cost about $0.50 for
   450 single-step requests; the harness runs in P1 are multi-step and will cost more. The P1
   session states an estimate and gets the operator's go-ahead before running them.
6. **Sizes are rough.** They are in working days for one agent session with review, and none
   has been measured.

## 1. Parts, by surface

| Part | Surface | Ends in | Size | Depends on |
| --- | --- | --- | --- | --- |
| P0 Baseline | none; read-only | a recorded table of gate results | ½ day | — |
| P1 Prototype and measurements | a worktree; a throwaway package | measurements, and gate **G1** | 2–3 days | P0 |
| P2 Amendment 5 and the host rejection | `src/core/ext/registry_normalize.ail`, the registration-boundary DST script, the ABI comment, 031's ADR | `registry_multiplicity` and `check_core` green | 1 day | G1; the operator on Amendment 5 |
| P3 The package, pure parts | `packages/motoko-ext-skills/` except `register.ail` | the package's inline tests green | 1½–2 days | G1 |
| P4 The package, wiring | `packages/motoko-ext-skills/register.ail` and its manifest | the package checks; shape and call inventories green | 1–1½ days | P2, P3 |
| P5 Registry wiring and the CI recipe | root `ailang.toml`, the lock, `registry_generated.ail`, the `verify_extensions` recipe, one named profile | `check_core` green; the refusal fixtures pass | ½–1 day | P4 |
| P6 Repair, then re-pin | the four DST profile files, the inventory fixtures, `declared_vs_performed` | no new red against the P0 baseline; gate **G2** | 1–1½ days | P5 |

P2 and P3 touch disjoint surfaces and can run in parallel after G1.

## 2. P0 — the baseline (½ day, read-only)

Run every gate ADR A7 names and record, for each, whether it is green or red and the first
lines of its failure. Nothing is changed.

- In CI: `check_core`, `profile_definition`, `driver_only`, `profile_coverage`, `conformance`,
  `ext_call_inventory`, `ext_call_inventory_selftest`, `test_coverage`.
- Outside CI: `registry_gen_check`, `registry_multiplicity`, `ext_hook_scope`,
  `ext_ambient_inventory`, `declared_vs_performed`, `driver_plus_no_ops`, `driver_plus_compose`,
  `driver_plus_herdr`.

Expected, from the research's survey and not yet verified: `driver_plus_herdr` is in
`DST_KNOWN_RED` (`Makefile:697`); `ext_hook_scope` exits 1 on `test_dummy`'s registration shape;
the profile count pins are stale by one because `ailang_tools` is in none of the four omitted
lists.

**Output:** `evidence/baseline/BASELINE.tsv` (gate, result, first failure line, commit) and the
raw logs beside it. **Done when** every gate has a row.

## 3. P1 — the prototype and the measurements (2–3 days, worktree, not merged)

The cheapest test of the idea. Nothing after it is worth doing if models do not load, follow
and reload skills delivered this way, and three ADR decisions can still fall here.

### P1.1 — the `std/yaml` check (first, an hour)

A registration-shaped module that imports `std/yaml (decode)`, wired into the worktree, then
`ext_ambient_inventory`, `ext_hook_scope` and `profile_definition`. **Settles Q1.** If the
closure is unresolved or rejected, stop and return D9 to the operator with the output; the
fallback is the subset parser of ADR v0.1.

### P1.2 — the prototype extension

`packages/motoko-ext-skills` in the worktree, prototype quality, valid fixtures only, no refusal
path:

- discovery over the bare relative root `.motoko/skills` (`isDir`, then `listDir`, then
  `readFileResult`, then `std/yaml.decode`);
- a `DescribeTools` catalogue with the index in the `Skill` description and the `enum`;
- a `ToolProvider` handler that reads through `ctx.ports.file_read`, prepends the directory
  line `.motoko/skills/<name>`, and applies D8's size check;
- wiring in the worktree only: the root manifest, `ailang lock`, `make registry_gen`, and a
  profile `skills_proto` that names `skills` in `extensions.order`.

The registration shape the gates require (literal `{ config, caps }`, named top-level payloads
in `register.ail`) is followed even here, so that P1.1's answer carries over.

### P1.3 — the measurements

Fixture skills in a test workdir: copies of two or three existing skills, and one written for
the purpose that instructs an action that can be checked afterwards. Sessions are launched the
way the tree already does it (`MOTOKO_CONFIG=<profile> ./scripts/run-agent.sh`, or the headless
form `scripts/probe_budget_continue.sh` uses).

| # | Measurement | Settles |
| --- | --- | --- |
| a | A session whose workdir is not the directory it was launched from: are the indexed and loaded skills the workdir's? In both layouts, does `ReadFile` on a bundled file under the directory line succeed? | Q3; A10 and part of A9 |
| b | The research's M2 task set through the real runtime, on the three profile models: how often `Skill` is the first call, how often it is called at all in the first response, and whether the checkable action was done | Q4; A5 |
| c | A run driven past 70% usage under the structural compactor, then under `compaction_ai` at 75%: reloads per run, and the tokens they cost | Q4; A5 |
| d | A model whose context is small enough that the size check must answer with its error | A5 |
| e | One request with an index at the 16,000-char budget to each provider family the profiles use, OpenAI included | Q2; A5 |

Measurement (e) needs a working route to an OpenAI model. This account's OpenAI key was rejected
on 2026-10-03, so the operator supplies one or rules OpenAI models out of scope for skills.

If (a) shows native file tools failing in the layout where the workdir is a subdirectory of the
launch directory, that is recorded and raised as its own issue; the research's path probe
suggests it and nothing has run it. It does not block this plan's default layout.

**Output:** the scripts and result tables under `evidence/p1/`, and
`NOTE-p1-prototype-results.md` with the numbers and what each one means for the ADR.

### G1 — the operator gate

The operator records a disposition of P1's results: go on to P2–P6, revise the ADR first, or
stop. The three ADR questions (§7 Q1–Q3) are closed here one way or the other. The worktree is
then removed; nothing from it is merged.

## 4. P2 — Amendment 5 and the host rejection (1 day)

Surface: `src/core/ext/registry_normalize.ail`, `scripts/dst/registry_multiplicity_dst.ail`, the
comment beside `ExtRegistration` in `packages/motoko-ext-abi/types.ail`, and Amendment 5's text
in 031 ADR-001.

1. **The artifact first.** A fixture in the registration-boundary script: a registration whose
   `config` carries `registration_refusal`, accepted by the host as it stands. This is what
   Amendment 5 cites, and it is the test that turns red when the check lands.
2. The reader, `RegistrationRefused`, and the arm in each of `rejection_rule`,
   `rejection_extension` and `rejection_message`. The check runs before the multiplicity walk.
3. Inline tests for the four cases of ADR A4: non-empty string, non-string value, absent key,
   empty string; and an ordinary registration still accepted.
4. Amendment 5 written into 031 ADR-001 with the artifact attached, and the ABI comment. No
   code and no version change in the ABI package.

**Green when** `ailang test src/core/ext/registry_normalize.ail`, `make registry_multiplicity`,
`make check_core` and `new_contract_policy` pass. **Needs the operator** to approve the
amendment's text, and to say whether it lands before or after the release tag of project 033.

## 5. P3 to P6 — in outline

These are written in detail after G1, each in the session that starts it, because P1 may change
what they build.

- **P3, pure parts.** Frontmatter extraction; the rules R1 and V1–V8 as functions over a
  listing and file contents, so they are testable without a filesystem; the index (name order,
  whitespace collapsed, the budget); the size estimate on the encoded envelope; the refusal
  message naming every violation. Inline tests for each rule, and ADR A6b as pure tests over
  both compactors.
- **P4, wiring.** The effectful shell around P3: discovery, the `config` record (index, whether
  the sandbox was set, any refusal), the catalogue, and the handler with call-time validation,
  the size check, the unsandboxed-launch check and the fail-safe when a refusal is recorded.
  The handler's stub-port tests (A6) and the call-time cases (A9). Before writing it, re-ground
  the research's survey of what the inventories reject: no `import std/x as X`, no helper named
  with a leading underscore, no `*E` list functions, typed port receivers only.
- **P5, registry and CI.** The root manifest, the lock, `make registry_gen`; a named profile;
  the two changes to the `verify_extensions` recipe (run under the sandbox, print the
  rejection); the refusal fixtures of A3 run under the sandbox; A1 and A2; and the row in the
  registration-boundary script asserting the extension and the host use the same key.
- **P6, repair then re-pin.** First, as its own change, give `ailang_tools` its place in the
  four profile lists. Then add `skills` to all four with its measured reason, change each
  profile's version, and move the inventory fixtures and `declared_vs_performed`'s arms and
  counts. Every moved pin is checked against the P0 baseline: a gate red before may not gain a
  failure.

### G2 — the operator gate

The evidence for A1–A10, reviewed once. The operator accepts the implementation and rules on
default-profile membership (ADR D11).

## 6. What is not in this plan

Everything ADR §3 lists: harness-forced loading, `/skill-name`, a second root, per-profile
selection, `allowed-tools`, sub-agent execution, pinning through compaction, a
`driver_plus_skills` DST profile, an error channel on the file-read port, and moving any of the
skills in `.claude/skills`.

Two requests for AILANG upstream fall out of the research and are not blockers: a `Result` form
of `listDir`, and `ailang iface` accepting modules whose declared path differs from their file
path. Routing them is the operator's call.

## 7. Open questions, each with what settles it

| # | Question | Settled by | If the answer is no |
| --- | --- | --- | --- |
| Q1 | Do the inventories accept an extension that imports `std/yaml`? | P1.1 | D9 returns to the operator; the fallback is the subset parser. |
| Q2 | Does OpenAI accept a 16,000-char tool description? | P1.3 (e) | D4 returns to the operator for those models. |
| Q3 | Does the bare relative root index the workdir's skills in a real session, in both layouts? | P1.3 (a) | D7 returns to the operator. |
| Q4 | Do models load a matching skill, follow it, and reload it after compaction, at a cost worth paying? | P1.3 (b), (c) | The operator decides at G1: stop, or open the pinning decision the ADR defers. |
| Q5 | Does Amendment 5 land before or after the 033 release tag? | The operator, before P2 | — |
| Q6 | Which of the research's survey items about the gates are still true? | Re-grounding at the start of P4 and P6 | The part adjusts its checklist; no ADR change. |

## Related records

- `ADR-001-skills-system.md` (Accepted v0.3), `RESEARCH-skills-system.md`, the four `REVIEW-*`
  files and `evidence/` (this folder)
- `../031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` (receives
  Amendment 5) and `PLAN-001-implement-adr-001-abi-8.md` (the house plan format)
- `../033_release/ADR-001-release-scope.md` (Q5)
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` (D5; P6)
