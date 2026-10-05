---
repo: arniwesth/motoko_agent
pr: 213
branch: feat/skills-extension
ticket: null
title: "feat(ext): skills extension — SKILL.md skills behind one Skill tool (037)"
---

## Summary

Adds a skills system to Motoko: one extension, `packages/motoko-ext-skills`, that indexes
`.motoko/skills/<name>/SKILL.md` (the Agent Skills format) and gives the model one `Skill` tool
that loads a skill's instructions when the model asks for them. A broken or duplicate skill, or a
broken root, refuses startup instead of being skipped. The host does the refusing, through a
reserved `registration_refusal` key recorded as Amendment 5 to 031 ADR-001, with no ABI version
change.

The extension is opt-in. It is wired into the registry and has a named profile, `skills`, and it
is not in the default profile (ADR D11). All of PLAN-001 is implemented, P0 to P6. The operator
closed gate G1 on 2026-10-04 and gate G2 on 2026-10-05.

**Still a draft.** The implementation has been reviewed twice by two independent reviewers, and
both now say merge. Three DST gates that CI does not run are red on an extension this PR does not
touch. See Test evidence.

## Changes

60 commits, 475 files. 417 of the files are evidence under
`.agent/projects/037_skills_system/evidence/`.

- **Documents (project 037).** Research, ADR-001, PLAN-001, two rounds of independent review, the
  orchestrator handoff and the delegate briefs. The design doc
  `design_docs/planned/m-motoko-ext-skills-import.md` is deleted; the ADR replaces it.
- **P0, the baseline.** The gates as they stood at `501cd879`, before any change.
- **P1, a throwaway prototype and its measurements.** `NOTE-p1-prototype-results.md` and
  `evidence/p1/`. The prototype's code is not in this PR.
- **After G1.** ADR D8 revised (the size check and the compactor's cap use different limits), and
  the OpenAI and layout rulings recorded in D4 and D7.
- **P2, the host refusal.** `src/core/ext/registry_normalize.ail` refuses a registration that
  carries `registration_refusal`; a comment in `packages/motoko-ext-abi/types.ail`; Amendment 5
  added to `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`.
- **P3, the package's pure core.** `skills.ail`: frontmatter, the refusal rules R1 and V1 to V8,
  the index and the size check. `a6b_test.ail`.
- **P4, registration and the handler.** `register.ail`.
- **P5, the wiring.** Root `ailang.toml` and `ailang.lock`, the generated registry, the `skills`
  profile under `.motoko/config/skills/`, and `make verify_skills_refusal`.
- **P6, the DST position.** `ailang_tools` and then `skills` named in the four profiles' omitted
  lists, with the pins that moved: the four `src/core/dst_driver_*.ail` modules, three scripts
  under `scripts/dst/` and two fixture files under `tools/ext_ambient_inventory/`.
- **R3, after the review.** The five fixes the implementation review held the merge for, and one
  test assertion from its second round: a `SKILL.md` that is not a regular file refuses as V3 and
  no longer hangs startup; `make verify_skills_tests`, and a CI step that runs it and
  `verify_skills_refusal`; `scripts/verify_skills_call.ail`, which dispatches a `Skill` call
  through the real host, with ten more checks in the suite; and a test in each of the four DST
  profile modules that names the extensions it omits. `evidence/r3/`.
- chore(github) commits recording this PR.

One archive is larger than anything now on `main`:
`evidence/p1/captures/p1-captures.tar.gz`, 7.9 MB, the P1 session captures (3,187 files).

## Governing docs

- `.agent/projects/037_skills_system/ADR-001-skills-system.md`
- `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md`
- `.agent/projects/037_skills_system/NOTE-p1-prototype-results.md`
- `.agent/projects/037_skills_system/AMENDMENT-5-draft.md`
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`
- `.agent/projects/037_skills_system/RESEARCH-skills-system.md`
- `.agent/projects/037_skills_system/HANDOFF-2026-10-03-orchestrator-start-plan-001.md`
- `.agent/projects/037_skills_system/REVIEW-001-claude-fable-5.1.md`
- `.agent/projects/037_skills_system/REVIEW-001-codex-gpt-6-astra.md`
- `.agent/projects/037_skills_system/REVIEW-002-claude-fable-5.1.md`
- `.agent/projects/037_skills_system/REVIEW-002-codex-gpt-6-astra.md`
- `.agent/projects/037_skills_system/REVIEW-003-claude-fable-5.1.md` and
  `REVIEW-003-codex-gpt-6-astra.md`: the implementation review
- `.agent/projects/037_skills_system/REVIEW-004-claude-fable-5.1.md` and
  `REVIEW-004-codex-gpt-6-astra.md`: its second round
- `.agent/projects/037_skills_system/LEG-R3.md`
- `.agent/projects/037_skills_system/LEG-P0.md`, `LEG-P1.1.md`, `LEG-P1.2.md`, `LEG-P1.3a.md`,
  `LEG-P1.3b-e.md`, `LEG-P2.md`, `LEG-P3.md`, `LEG-P4.md`, `LEG-P5.md`, `LEG-P6.md`

## Predicted outcome

- **A session that does not install the extension is unaffected.** It is not in the default
  profile and is named in all four DST profiles' omitted lists.
- **With the `skills` profile**, a directory under `.motoko/skills/` holding a valid `SKILL.md` is
  listed in the `Skill` tool's description, and the model loads it by name.
- **A broken skill stops the runtime at startup**, exit 2, with one error event naming the path
  and the rule.
- **Adding or removing a skill, or rewording its description, does not refuse a resume.** Only
  `ext_config_digest` moves.

Checked by `make verify_skills_refusal` and the package's tests, and by the ADR's acceptance
criteria A1 to A10. Known limits, stated in the ADR: no model reloaded a skill after the
structural compactor elided it; and a skill that passes the size check can still be capped by the
compactor.

## Test evidence

- [x] **Package tests, re-run on 2026-10-05 at `a74bdcc2`:** `make verify_skills_tests`, which
  runs `ailang test` on `skills.ail`, `a6b_test.ail` and `register.ail`: 62, 11 and 18 tests, 91
  passed, 0 failed.
- [x] **`make verify_skills_refusal`, re-run the same day at `a74bdcc2`:** 51 passed, 0 failed,
  through the real runtime entry. It covers a fixture for R1 and each of V1 to V8 (a named pipe
  among them), the controls that must start, the digest behaviour of A2, a `Skill` call
  dispatched through the real host, and one start without the sandbox.
- [x] **The gates of ADR A7, from the delegate's table at `7e6f6ab6`**
  (`evidence/p6/GATES.tsv`), not re-run for this record: 14 green and 3 red, and none newly red
  against the P0 baseline. `declared_vs_performed` went from red to green.
- [ ] **Three gates are red: `ext_hook_scope`, `driver_plus_no_ops`, `driver_plus_compose`.** All
  three stop on the `test_dummy` extension's registration, which this PR does not change.
  `ext_hook_scope` was red on it in the baseline. In the two profile gates it was hidden behind an
  earlier failure on `ailang_tools`, which P6 repaired. The operator accepted them at G2. No issue
  has been filed for `test_dummy` yet.
- [x] **Mutation checks by the delegates**, in each part's evidence: 55 mutants in P3, 45 in P4,
  12 in P5 and 4 in P6, all recorded as killed. P3's and P4's scripts count any failing run as a
  kill, which is looser than the discipline proposed in PR #219. R3 follows that discipline: 18
  mutants, each killed by the committed check named for it before the run.
- [x] **P1 measurements, through the real runtime on seven models:** the right skill was loaded in
  the first response in 88% to 100% of matching sessions, and `Skill` was never called in 135
  control sessions. The checkable action was done in 53 of 54 sessions. A 16,000-character index
  was accepted by seven provider families. OpenAI was ruled out of scope and not tested.
- [ ] **One layout is not covered.** A session whose workdir is a subdirectory of the directory it
  was launched from loads no extension at all, for a reason in the TUI and core. It was ruled its
  own issue, which has not been filed. A10 holds for the other layout.
- [x] **Reviewed twice, by Codex (GPT-6-Astra) and Claude (Fable 5.1), each alone in its own
  worktree.** Round 1 at `4c9f9c25`: both said merge after fixes, and four findings held the
  merge. Round 2 at `e7d635ef`, by fresh sessions: both say merge, and no finding holds it. Each
  reviewer also broke rules of its own choosing to see whether a test noticed. Three such mutants
  survived across the two rounds, and each now fails a committed check. Records: `REVIEW-003-*`
  and `REVIEW-004-*`. There is no third round; `REVIEW-004` says why.
- [ ] **Five review notes are not fixed and are with the operator:** the reserved key can reach
  the host from the operator's own `ailang_tools.json`; the unsandboxed-launch guard sees "unset"
  and not "set to something else"; invalid UTF-8 and control characters in a skill are accepted;
  one test compares against a literal copy of a core encoding; and a red `test_dummy` comparison
  would hide a wrong pin beside it.
- [x] **CI passed at `4c9f9c25`,** all nine checks, before the fixes. The fixes add a CI step that
  runs the package's tests and the refusal suite; the checks on this PR show its first run.
