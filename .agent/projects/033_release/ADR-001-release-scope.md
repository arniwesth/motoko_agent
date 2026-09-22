# ADR-001: Release scope for motoko_agent

Date: 2026-09-20. Status: **Proposed v0.2 — D1 decided by the operator (ABI 8.0 lands before the
tag; ABI stability after the release is a goal); D2–D5 open; nothing below is executed.** Grounded
at HEAD `b37fcd47` on `arniwesth/013-plan003-and-herdr`, AILANG v0.33.0, extension ABI `7.4`,
1497 commits after the repo's first commit.

Replaces `.agent/plans/MOTOKO_PUBLIC_RELEASE.md`, deleted in the same change that adds this file.
That document was the plan that *created* this repository: it landed in the first commit
(`c4bbeef6`, 2026-05-03, "Initial public release of motoko_agent"), its seven phases were executed
that day, and it was never touched again. It described an extraction from a private repo into this
one. It is not a plan for the release wanted now. Its manifest is dead (§7). Provenance for the
re-decision is `.agent/plans/BRIEF-release-plan-legacy-review.md`.

v0.2 changes: D1 recorded as decided (v0.1 recommended the opposite and was overruled); the
ABI batch inventory (§3) added; the registry finding and D5 added; sequence rewritten.

## 0. What this release is

A **versioned release of this repository at a tagged commit, with the extension ABI at 8.0 and a
stated stability promise for it.** Not an extraction, not a subset. Everything tracked at the tag
ships. The operator's constraint, recorded 2026-09-20: *"Ideally ABI should not change much after
this release."* That makes the ABI the release's critical path (§2 G5) and the reason for §3.

Version identifiers disagree today and none has ever been cut:

| Identifier | Value | Where |
|---|---|---|
| `T.version()` (what the TUI banner prints) | `0.2.0` | `src/core/types.ail:8` |
| Root package version | `0.1.0` | `ailang.toml:3` |
| `package.json` | no version field | root |
| Git tags | none for a version | only `wip/p1-part4-2026-09-08`, `spike-archive-pre-strip` |
| CHANGELOG | only `[Unreleased]`, last touched 2026-05-08 | `CHANGELOG.md` |

The ABI has an external surface the legacy plan never mentioned. `packages/motoko-ext-abi/ailang.toml`
names a registry home (`sunholo-data/ailang-packages`), a docs page, and `[stability] level = "stable"`.
Fetched 2026-09-20 from that registry's `main`:

| Surface | In this tree | In the registry |
|---|---|---|
| `sunholo/motoko_ext_abi` | **7.4** (first in-tree commit 2026-07-07; 7.0–7.4 landed 2026-09-05..13) | **2.2.0** (root `ailang.toml` comment dates the registry set 2026-05-08) |
| Extension packages | 22 under `packages/`, 19 pin the ABI by path | 15 `motoko-ext-*`, every one pinning ABI `2.2.0` |
| Registry-only packages | — | `motoko-ext-fmt` (0.4.2), `motoko-ext-typefix-agent` (0.1.0) |
| Tree-only packages | agentcli, autoresearch, compaction-structural, empty-stop-guard, herdr, progress-contract-guard, repetition-guard | — |
| Version drift | compose 0.2.4, context-mode 0.2.2 | compose 0.2.6, context-mode 0.2.4 (registry *ahead* of tree) |

So there are external ABI consumers, and they are five majors behind. v0.1 of this document argued
there were none; that was wrong, and it is one more reason D1 went the way it did.

## 1. Decisions

### D1. Extension ABI — DECIDED 2026-09-20: 8.0 lands before the tag

The operator's words: *"I will have to push back on Recommendation B. Ideally ABI should not
change much after this release."* This matches what `031/ADR-001` recorded on 2026-09-18: *"The
owner has explicitly asked to make the ABI changes now, before the release freezes it."*

Consequences, all now in scope:

1. **8.0 is the batch.** Every known breaking ABI change lands in 8.0 or is explicitly recorded as
   deferred to a later, planned major. §3 is the inventory; each row needs a fold/defer decision.
2. **A written stability rule for 8.x.** The ABI header's rule today is "a `Capability` variant
   added, removed or re-rowed is a major." But 7.2 and 7.4 were *minors* that broke every
   `ExtCtx` constructor in the tree (records gain fields; 37 literals changed at 7.2). "Should not
   change much" has to say which of these is allowed after the tag. Recommendation: **8.x minors
   may add fields only behind a constructor helper the ABI exports, so a consumer that uses the
   helper keeps compiling; variant changes wait for 9.0.** Written into `types.ail`'s header and the
   package `ai_summary` before the tag (G5d).
3. **The freeze is only real if it is published** — see D5.

### D2. Is the repository already public

Two remotes: `origin` (`arniwesth/motoko_agent`) and `sunholo` (`sunholo-voight-kampff/motoko_agent`).
Visibility could not be verified from this container (`gh` returns 401). If either is already
public, everything in §5 is already published and hygiene is best-effort. If this tag is the first
public exposure, §5 is a gate.

### D3. Version number

**Recommendation: `0.3.0`.** The banner has said 0.2.0 since the identifier was introduced, so the
next cut is 0.3.0; `ailang.toml`'s 0.1.0 is stale. With D1 decided, the *ABI package version*
(8.0, `stability = "stable"`) carries the stability promise, so the repo version does not have to
be 1.0 to make it. If the operator wants the repo version itself to signal stability, it is 1.0.0
and README's "highly experimental" framing changes with it.

### D4. Release artifact and remote

**Recommendation:** an annotated tag `vX.Y.Z` on the tag commit, pushed to `origin`, plus a GitHub
Release whose body is the CHANGELOG section. No binary artifact: `scripts/install-prerequisites.sh`
builds AILANG from the floor in `ailang.toml` (`>=0.33.0`), which both CI workflows also pin.
Whether `sunholo` also receives the tag is the operator's call.

### D5. Registry publication (new)

The registry is at ABI 2.2.0 with fifteen packages pinned to it. Options:

| Option | Meaning |
|---|---|
| **A. Publish at the tag** | ABI 8.0 and every in-tree package to `sunholo-data/ailang-packages`; registry-only `fmt` and `typefix-agent` either re-based to 8.0 or marked as 2.2.0-era. Version numbers reconciled first (tree is behind the registry for compose and context-mode). |
| **B. Registry frozen at 2.2.0** | This repo becomes the sole distribution; the registry entries get a deprecation note pointing at the tag. |

**Recommendation: A.** An ABI freeze nobody outside the tree can consume is not a freeze.
Publishing is a separate repo under another org; the process is not documented anywhere in this
tree (the only two mentions of `ailang-packages` are in an unrelated eval plan), so it has to be
rediscovered, and access is the operator's. If A is chosen it is a gate (G8); if B, a follow-up.

## 2. Gates: what must be true at the tag commit

| Gate | Check | State at grounding |
|---|---|---|
| **G1 core clean, tests green** | `git status --porcelain src/core packages` empty; `make check_core`, `make test`, `make test_integration`, `make conformance`; `cd src/tui && bun run test`; both `.github/workflows/*` green on the tag commit | Core surface clean. Test runs not executed for this document. |
| **G2 version agreement** | `T.version()`, `ailang.toml`, CHANGELOG heading, tag name all equal | Disagree (§0). |
| **G3 CHANGELOG cut** | `[Unreleased]` becomes `[X.Y.Z] — date`; a *summary* section for 2026-05-08..tag by area (core, extensions/ABI, eval, TUI, tooling), not a 1497-commit backfill; ABI 7.x→8.0 gets its own subsection naming the stability rule; fresh empty `[Unreleased]` above | Not started. |
| **G4 README refresh** | Project-structure block lists `src/core/ext/` with five extensions that no longer exist there, and omits `packages/` (22), `src/eval/`, `scripts/eval/`, `evidence/`, `tools/`, `design_docs/`, `.devcontainer/`. Last touched 2026-06-24. Extensions and Development sections need the same pass. | Stale. |
| **G5 ABI 8.0 landed** — the critical path | **G5a** `031/ADR-001` is accepted by **artifacts, not by a further review round**: v0.8 (2026-09-20) is the last text-only revision, after seven full reviews at a steady finding rate (13, 9, 8, 10, 8, 8, 9) whose later rounds were about unbuilt mechanisms. Acceptance = its freeze evidence items **1, 2 and 8** exist (compiled ABI-8 signatures and both consumers registered as named functions reading `ext_config`, plus the configured-versus-empty `DescribeTools` catalog; the shape gate implemented and red/green on its fixture set) and item 8's gate runs. **Amended 2026-09-21 (operator, at 031 P0G):** item 3 — the `Descriptor`/`Identity`/dry-`prepare` mismatch fixtures — is journal schema 2, not ABI, and moved to 031 PLAN-001's post-release line X (P0.7) in v1.1; the ABI freeze does not depend on it, so G5a no longer waits for it. Any further change to the ADR cites a failing fixture, a compile error or a measured probe and lands as a numbered amendment. The plan's evidence is reviewed once, at the end, by someone other than the implementer. **G5b** a PLAN implements ADR-001 §D7: ABI 7.4→8.0; `execution-program/4`→`/5`; journal schema 1→2; event vocabulary v2; 19 package pins; conformance and no-op profiles. **G5c** every §3 row folded or deferred in writing. **G5d** the 8.x stability rule (D1 item 2) written into `types.ail` and `ailang.toml`. **G5e** the checks ADR-001 names run green: `make declared_vs_performed` (green in the script's existing two-sided idiom: the trigger-shape and escape rows report `ok … still holds` while the pinned compiler accepts them and go red only when the upstream fix lands; a fixed compiler is not a prerequisite), the tree-wide `make ext_hook_scope` run with the named-only shape verdict — the derivation, not only `ext_hook_scope_selftest`; green means a total registration-shape result for every installable extension — supported `{ config, caps }` return shape, every payload enumerated, every payload a named unshadowed function, every delegation resolved in the caller's scope — with zero rejections, and a nonzero exit otherwise, independent of the walk's other verdicts — `profile_coverage`, `driver_plus_no_ops`, `event_vocabulary`, plus `conformance`. | **v0.8 final text; PLAN-001 drafted 2026-09-20** (`031/PLAN-001-implement-adr-001-abi-8.md`, G5b). The ADR carries an acceptance rule: no further review round on the text; changes only as numbered amendments with an artifact attached. The plan is sequenced by source surface: **P0** produces the freeze artifacts first — probe suite in its home, shape gate red/green on fixtures, ABI 8.0 types with the 8.x rule (G5d), conformance and kind maps, two compiled scripted consumers plus the `DescribeTools` example, the schema-2 fold with every D6 mismatch fixture — and **P0G** accepts the ADR (G5a) with the tree deliberately red; **P1** migrates core and the 45 registration sites in four measured batches and lands 8.0 green at **P1G** (this doc's D1 met; G8 may start); **P2** formats (`/5`, vocabulary 2, epoch resume, dry `prepare`); **P3** the host decision service and writer; **P4** the first guard in shadow, the ADR-003 amendment, measurements; one review of the evidence at the end. v1.1 splits it into a **release line R** — ABI 8.0 closed: suite, gate, types, conformance, one scripted consumer per variant, core views and config, the 45 sites, a dispatch cursor with a stub adapter arm, truthful evidence defaults — **14–18 delegate-days, about two weeks wall-clock with parallel batches**, ending at R-G where this doc's D1 is met and the tag may proceed; and a post-release line X (schema-2 fold, live wire arm, host service, formats, shadow guard: additive, not ABI; 27–37). **2026-09-22: line R implemented** (PLAN-001 §9): ABI 8.0 landed and frozen with the 8.x rule, ADR-001 accepted with Amendments 1–4, 42 registration sites and core migrated; at `d78a7c3e` the full `make dst` sweep is green and every R-G make target but the pre-existing TUI red passes. **R-G open on one item: both CI workflows** (the container's GitHub token is rejected). |
| **G6 root cleanup** | Remove from the tree: `.delegate_prompt_final_cleanup.md` (a delegate prompt, 2026-08-29), `phase_log.md` (calibration log, 2026-07-10), `scratchpad/verify_guard.ail`. Independent of D2. | Present. |
| **G7 hygiene** | §5, **only if D2 = first public exposure** | Measured, not applied. |
| **G8 registry publish** | **only if D5 = A**: package versions reconciled against the registry, ABI 8.0 and all packages published, registry-only packages dispositioned | Registry at 2.2.0. |

## 3. ABI 8.0 batch inventory

Everything found in the tree that has ever asked for an ABI break and has not landed. Each row
needs **fold into 8.0** or **defer, additive-only** before G5b starts, so that "should not change
much" is a decision and not a hope.

| Candidate | Source | What it wants | Status | Fold / defer |
|---|---|---|---|---|
| Structured decisions | `031/ADR-001` §D7 | Two `Capability` variants; descriptor/request/observation/evidence/state types; three `ExtCtx` fields; nullary `Accept`; vote-family normalization | Proposed v0.2 | **Fold** — it is the driver |
| Stateful no-op backoff | `006_compactor_strategy/PLAN-compactor-strategy.md` §gaps | `PreStepDecision.PassThrough` cannot carry artifacts; persisting no-op state needs a break | Noted 2026, never picked up | open |
| Faithful in-turn compaction hook | `004/ADR-001` D9, cited in `.agent/issues/compaction-rederive-cost-dominates-after-strategy-fixes.md:163` | "a separate ABI change" | Unlanded | open |
| Lifecycle boundary | `013/ADR-001` D5 | A fifth DST `FaultBoundary`, "no plan until D4's pilot has landed or the next ABI major is scheduled" | Not an ABI `Capability` change; wants to ride the same train | open (scheduling only) |
| Parametrise ABI over the world type | `types.ail:84` | `ExtCtx[W]` | **Rejected** in the header | closed — do not reopen |
| Telemetry seam | `001/ADR-002` | `ExtCtx.last_input_tokens` | **Landed** (`types.ail:528`) | closed |
| `ExtRegistry` shape | `017/ADR-001` §5 item 3 | per-extension `{ id, caps }` record | **Landed** at 6.0 | closed |

## 4. Explicitly out of scope (follow-ups, not gates)

- **ADR-004 / PLAN-004** (`013_core_architecture_for_dst`): eval-only. Its evidence commit touches
  nothing under `src/core/` or `packages/`. Stands on its own evidence per the brief.
- **PLAN-004 P2.4** in flight in the detached worktree at a pinned E, under an operator grant.
  Not release-relevant. Do not disturb.
- **A release CI workflow** (tag → GitHub Release): useful, not a gate for the first cut.
- **Registry publication** if D5 = B.
- **Untracked observer apparatus** the brief reports (observer skill, gate scripts, ledgers): real
  and at risk of loss, but a separate housekeeping item. Not visible from this checkout's
  `git status`; it lives with the observer's worktree.

## 5. Publication hygiene (gate only under D2 = first exposure)

`.agent/` is 1007 of the repo's 2013 tracked files (≈15 MB) and ships wholesale under a tag, as it
did under the legacy manifest. It carries operational detail, not secrets. Measured at grounding
over tracked files:

| Category | Files | Notes |
|---|---|---|
| Herdr pane ids (`wN:pX`) | 58 | Densest in `021_herdr_delegation/MEASUREMENTS-*`, `020_herdr_agent_integration/ADR-001`, `013/PLAN-003`, and the `plan003-p4-live-gate` evidence JSONL. |
| Home-directory absolute paths | 28 | |
| Delegate / grant handle language | 21 | `run.observer`, grant ids. |
| Legacy repo name `ailang_agent` | 9 in `.agent/`, 3 in `benchmarks/` | Cosmetic. |
| 32-hex session/run ids | 2 | |
| API-key-shaped strings | 2 | **Both synthetic**: the AWS documentation example key in `src/core/dst_secrets.ail` test fixtures; a 40-character placeholder in `021_herdr_delegation/MEASUREMENTS-2026-08-22.md`. Real keys are ~108 characters. |

Also noted: the legacy plan's Phase 5 config sanitization was never applied as written
(`openai_base_url` and `ai_options_json` remain in 14 profile files). `.agent/local/` is gitignored and holds unrelated material; it must
stay ignored.

**Rule if G7 applies:** redact in place, do not rewrite history, do not drop files from the tag.

## 6. Sequence

1. **G5a** — ADR-001 v0.3 per the handoff; second review; accepted.
2. **G5c** — fold/defer decision on every §3 row, recorded in this file.
3. **G5b** — PLAN for 8.0; implement; **G5e** checks green; **G5d** stability rule written.
4. G6 root cleanup.
5. G4 README, then G3 CHANGELOG.
6. G2: set `T.version()`, `ailang.toml`, CHANGELOG heading to the D3 value; reconcile package
   versions against the registry if D5 = A.
7. G1 locally; push; both workflows green on that commit.
8. G7 if D2 says so.
9. Annotated tag; push to the D4 remote(s); GitHub Release from the CHANGELOG section.
10. **G8** if D5 = A: publish ABI 8.0 and packages to the registry.

Steps 1–3 bound the timeline. Steps 4–9 are a day's work once 3 is done.

## 7. What changed from the legacy plan, so nobody re-derives it

| Legacy plan said | Now |
|---|---|
| Extract from `ailang_agent` into `motoko_agent` | Done 2026-05-03. This repo is the output. |
| Non-goal: "changing runtime behavior, extension logic, or TUI implementation" | **Not carried over.** D1 decided the opposite: extension ABI 8.0 is in scope and gates the tag. This non-goal was the source of the withdrawn conclusion that ABI 8.0 was out. |
| Extensions live in `src/core/ext/{compose,context_mode,exa_search,mcp,omnigraph}` | None of those directories exist. 22 packages under `packages/`, 19 pinning the ABI by path. |
| No mention of a package registry | The ABI and 14 extensions are published at `sunholo-data/ailang-packages`, five ABI majors behind (§0, D5). |
| Exclude `tools/`, `docs/`, `.claude/`, `benchmarks/` | `tools/` (187 files), `.claude/` (17), `benchmarks/` (17) are tracked and ship. `docs/` is empty. |
| Create `.devdocker/`; replace `.devcontainer/` | Inverted on day one (`d75d2505`). `.devcontainer/` is the dev environment. |
| Sanitize `default/config.json` (Phase 5) | Never applied; 14 profiles now. See §5. |
| Include `.agent/` wholesale | Still true under a tag. Contents now measured (§5). |
| `v0.12.1.md`, `src/eval`, `scripts/eval`, `evidence/`, `experiments/`, `deploy/`, `web/`, `design_docs/` | First is gone; the rest exist and were never in any manifest. Under a tag they simply ship. |

## Related records

- `.agent/plans/BRIEF-release-plan-legacy-review.md` — the handoff that triggered this re-decision
- `031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` — the ABI 8.0 proposal (G5)
- `031_system_one_decisions/HANDOFF-2026-09-18-adr001-v0.2-review-to-v0.3.md` — the v0.3 edit list (G5a)
- `017_extension_handling/ADR-001-extension-abi-evolution.md` — ABI versioning policy
- `packages/motoko-ext-abi/types.ail` — the ABI header's own major-version rule and its rejected alternatives
- `013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` — eval-only, out of scope (§4)
- `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` — why the legacy plan was not trusted
