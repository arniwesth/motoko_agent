---
repo: arniwesth/motoko_agent
pr: 172
branch: arniwesth/mot-114-add-herdrs-own-skill-to-claudeskills-so-delegates-can-drive
ticket: MOT-114
title: "MOT-114: add herdrs own skill to claudeskills so delegates can drive"
---

## Summary

Adds herdr's own skill at `.claude/skills/herdr/SKILL.md`, so a `claude` delegate started in a pane
on this tree knows the pane/agent CLI instead of discovering it by trial.

MOT-113's findings share one root cause. `agent start` failing was misread as a permissions problem;
a 43-line brief nearly went in as pasted text; `agent wait` was trusted as a completion signal and
silently never fired. All three are "the agent did not know the tool".

Linear: [MOT-114](https://linear.app/motoko-agent/issue/MOT-114/add-herdrs-own-skill-to-claudeskills-so-delegates-can-drive).
Related: [MOT-113](https://linear.app/motoko-agent/issue/MOT-113/record-the-first-autonomous-delegation-in-agent-confined-herdr-agent) (the findings), [MOT-105](https://linear.app/motoko-agent/issue/MOT-105/residual-1-record-an-r7-baseline-outside-the-repo-from-a-sanitised) (the baseline this invalidates).

## Changes

- feat(skills): add herdr's own skill so delegates can drive the session

1 file changed.

## Governing docs

- `.agent/projects/021_herdr_delegation/RESEARCH-herdr-delegation-surface.md` **§8** — the findings this answers (F-B and F-C are knowledge gaps; F-A is not)
- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` — **C2** (the re-record obligation this triggers), **D7** (a pin as the review boundary for third-party code that runs in this container), **D9** (why instructions loaded into a session are a grant, not a convenience)
- `.devcontainer/agent_confined/checks/r7_git_audit.py` — the f-4 frozen set, and why `.claude/skills/**` is in it

## Predicted outcome

The next delegation should not repeat F-B or F-C, because the skill documents the start and prompt
paths directly. It cannot fix F-A — `agent wait` losing a transition is a herdr defect, not a
knowledge gap — and the skill does not warn about it, which is why MOT-113 §8 stays the record.

**Two consequences that are the point, not side effects:**

1. **This is not documentation — it is instructions loaded into every matching session.** That is
   precisely why `r7_git_audit.py` puts `.claude/skills/**` in the f-4 frozen set. Third-party text
   that steers an agent holding this container's tokens is a deliberate grant. The byte-identity
   check below is the review boundary for it, the same role the pinned tag plays for the herdr
   sidebar in ADR-001 D7.
2. **The R7 baseline is now invalid** and must be re-recorded host-side from a sanitised tree, noting
   this change as the reason. ADR-001 C2 fires as designed.

## Test evidence

**Provenance — byte-identical to the upstream tag.** Sourced from `herdr --skill` (the installed
binary's own copy) rather than fetched, then compared:

```
local:  195 lines, sha256 237ad2ab2d8123e2...
remote: 195 lines, sha256 237ad2ab2d8123e2...   (raw.githubusercontent.com/.../v0.8.2/skills/herdr/SKILL.md)
diff -> IDENTICAL
```

The binary is the correct authority because `versions.env` pins `HERDR_VERSION=0.8.2`. A copy taken
from a tag URL can drift from the binary after `agent.sh upgrade` with nothing to report it.
Regenerate on upgrade: `herdr --skill > .claude/skills/herdr/SKILL.md`, committed beside the
`versions.env` diff.

**It self-gates, so it is inert outside a pane.** Line 13 is `test "${HERDR_ENV:-}" = 1`, with an
instruction to stop if it fails, and the frontmatter narrows it to tasks that name herdr. That is
what makes it safe project-wide rather than only inside the confined image.

**It loads.** Confirmed live in the session that wrote this PR, immediately after the file landed.

**R7 detects it, as predicted.** Verified against the pre-change baseline:

```
R7 FAIL — 3 finding(s):
  * f-4 .devcontainer: content changed: .devcontainer/agent_confined/Dockerfile
  * f-4 .devcontainer: content changed: .devcontainer/agent_confined/herdr.toml
  * f-4 harness config: NEW file not in the attested inventory: .claude/skills/herdr/SKILL.md
```

All three are approved changes — the first two are the operator's `8d7954b` terminal-settings commit,
which had already invalidated the baseline before this PR. The audit is working, not complaining.
