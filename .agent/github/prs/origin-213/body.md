---
repo: arniwesth/motoko_agent
pr: 213
branch: feat/skills-extension
ticket: null
title: "feat(ext): skills extension — SKILL.md skills behind one Skill tool (037)"
---

## Summary

**Draft: documents and baseline only so far, no code.** Project 037 gives Motoko a skills system:
one extension, `packages/motoko-ext-skills`, that indexes `.motoko/skills/<name>/SKILL.md` (the
Agent Skills format) and gives the model one `Skill` tool that loads a skill's instructions when
the model asks for them. A broken or duplicate skill refuses startup instead of being skipped.

The branch currently holds the research, ADR-001 (Accepted, v0.3, after two rounds of independent
review), PLAN-001, the orchestrator handoff, the delegate briefs and the P0 gate baseline. It also
deletes `design_docs/planned/m-motoko-ext-skills-import.md`, which the ADR replaces.

The PR is open as a draft so documents and evidence can be pushed as the work proceeds. Next is a
throwaway prototype with its measurements (PLAN-001 P1), then the operator's gate G1. The
implementation (P2 to P6) comes after G1 and is not planned in detail yet, because what the
prototype measures can change it.

## Changes

- docs(037): skills system — research, ADR-001 v0.3, PLAN-001, reviews
- docs(037): P0 and P1.1 delegate briefs
- docs(037): rewrite the orchestrator handoff for a Motoko orchestrator
- docs(037): bring P0 and P1.1 briefs up to Delegate-tool routing
- evidence(037): P0 baseline at 501cd879
- docs(037): P1.2 delegate brief (prototype extension)
- docs(037): P1.3a delegate brief (workdir-not-launch-dir measurement)
- docs(037): P1.3b-e delegate brief (estimate first, then measure)

42 files changed: 41 added under `.agent/projects/037_skills_system/`, and the one design doc
deleted. Nothing under `src/`, `packages/`, `scripts/` or `tools/` is touched yet.

## Governing docs

- `.agent/projects/037_skills_system/ADR-001-skills-system.md`
- `.agent/projects/037_skills_system/HANDOFF-2026-10-03-orchestrator-start-plan-001.md`
- `.agent/projects/037_skills_system/LEG-P0.md`
- `.agent/projects/037_skills_system/LEG-P1.1.md`
- `.agent/projects/037_skills_system/LEG-P1.2.md`
- `.agent/projects/037_skills_system/LEG-P1.3a.md`
- `.agent/projects/037_skills_system/LEG-P1.3b-e.md`
- `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md`
- `.agent/projects/037_skills_system/RESEARCH-skills-system.md`
- `.agent/projects/037_skills_system/REVIEW-001-claude-fable-5.1.md`
- `.agent/projects/037_skills_system/REVIEW-001-codex-gpt-6-astra.md`
- `.agent/projects/037_skills_system/REVIEW-002-claude-fable-5.1.md`
- `.agent/projects/037_skills_system/REVIEW-002-codex-gpt-6-astra.md`

## Predicted outcome

As it stands, landing this changes no runtime behaviour: it adds documents and removes one.

When the implementation is in:

- A skill is a directory under `.motoko/skills/` holding a `SKILL.md`. The model sees the skills'
  names and descriptions in the `Skill` tool's description and loads one by name (ADR D4, D10).
- A broken skill, a duplicate name or an unreadable root stops the runtime at startup with a
  message naming the path and the rule (D1). The host does the refusing, through a reserved
  `registration_refusal` key, recorded as Amendment 5 to 031 ADR-001 with no ABI version change
  (D2).
- A session that does not install the extension is unaffected: it is not in the default profile
  in v1 (D11) and is omitted from all four DST profiles (D13).

Checked by the ADR's acceptance criteria A1 to A10 (ADR §2), and against the P0 baseline below:
the gates that are green there stay green.

## Test evidence

- [x] **P0 baseline**, at `501cd879`, before any code change: 17 gates, 13 green and 4 red
  (`ext_hook_scope`, `declared_vs_performed`, `driver_plus_no_ops`, `driver_plus_compose`). Each
  red is the gate's own failure, not a missing build. They are the state of `main`, not something
  this branch caused: three of them name the `ailang_tools` extension and one the `test_dummy`
  extension. Table and logs: `.agent/projects/037_skills_system/evidence/baseline/`.
- [x] **Probes the ADR rests on**, scripts under `.agent/projects/037_skills_system/evidence/`:
  - `m7`: under the sandbox the TUI sets, a relative path resolves against the workdir, so the
    skill root is the bare path `.motoko/skills` (D7).
  - `m2`: putting the index in the tool description or in the system prompt made no difference to
    how often the skill was triggered, 139 of 150 for each (D4).
  - `m8`: a 16,000-character tool description is accepted by Anthropic, Google, DeepSeek and Meta
    models through OpenRouter. OpenAI could not be tested: this account's OpenAI key was rejected.
- [ ] **P1 prototype measurements**: not run yet.
- [ ] **Implementation and A1 to A10**: not started.
