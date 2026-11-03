---
repo: arniwesth/motoko_agent
pr: 312
branch: docs/041-handoff-i2-ruled
ticket: null
title: "docs(041): the handoff records ADR-002 I2's ruling"
---

## Summary

The W6–W7 session handoff still listed ADR-002 **I2** (`Search`'s deadline disclosure) as an open
question for the operator or W13. #311, already merged at `459b4336`, settled it: the ADR's scope was
amended and the code left alone. I2's `none` now applies to live runs only, the scripted arm's `unknown`
is stated, and ADR-002 is at its tenth revision. This PR updates the committed handoff so that both
passages that called it open now record the ruling.

**Documentation only. No code changed.** The ADR and plan changes are in #311, which is already merged.
This PR touches nothing but the handoff copy and this PR record.

## Changes

- docs(041): record ADR I2's ruling in the handoff

1 file changed: `.agent/projects/041_process_execution_timeouts/HANDOFF-session-W6-W7-2026-11-02.md`
(350 → 354 lines). It is a byte-exact copy of the final source in the orchestrator's `.dagr/HANDOFF-W6-W7.md`
(sha256 `15ff65970d131e64fa3364fc5046a117dae86567de989ad0f49da291ebab9771`). The diff has three hunks:

- "The three findings needing an operator or W13 decision", finding 1: rewritten to **RULED and FIXED in
  #311**, with the operator's reasoning (`unknown` is the safe direction, D4's byte rule, A10).
- "Two questions the operator should answer before W8" became **"One question …"**. The I2 item is struck
  out and points to #311, and the remaining item is marked **still open**.
- Trap wording (awk): the one-line form is reported at `line 1` and the continuation form at `line 2`,
  measured on mawk 1.3.4. This hunk is not about I2. It comes from the same final source.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/HANDOFF-session-W6-W7-2026-11-02.md`
- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md` (amended in #311, not here)
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md` (amended in #311, not here)

## Predicted outcome

A reader of the committed handoff no longer treats I2 as an open operator decision or as work that W13
will run into. One operator question remains before W8. Check: the handoff's claims about the ADR,
the plan and the code hold on `main`. They are verified below.

## Test evidence

Copy integrity:

```
$ cmp <copy> /workspaces/motoko_agent/.dagr/HANDOFF-W6-W7.md ; echo $?
0
$ wc -l <copy> <source>
  354 <copy>
  354 <source>
$ sha256sum <copy> <source>
15ff65970d131e64fa3364fc5046a117dae86567de989ad0f49da291ebab9771  <copy>
15ff65970d131e64fa3364fc5046a117dae86567de989ad0f49da291ebab9771  <source>
$ git show HEAD:<copy> | cmp - <source> ; echo $?
0
```

The handoff's new claims, checked against the repo at `origin/main` = `459b4336`:

```
$ sed -n '4p' ADR-002-per-call-process-timeouts.md
Status: **Accepted 2026-10-31 under R9, tenth revision. Not implemented. Rulings R1-R11 are in §7.**

$ sed -n '/^- \*\*I2\./,/^- \*\*I3\./p' ADR-002-per-call-process-timeouts.md
- **I2.** A timeout of `BashExec`, `RunTests` or another tool that may change state is never reported
  as `effects: none`. In a **live** run `ReadFile` and `Search` keep 034 D2's `none`: `Search` overrides
  the disclosure at `src/core/tool_runtime.ail:632-638`. **A scripted `Search` deadline reports
  `unknown`**, not `none`: the scripted arm builds every deadline through `deadline_fault`, which is
  tool-blind, and A10 keeps that path's behaviour as it is today. The two worlds differ here, deliberately.
- **I3.** Live and scripted runs get their limit from the same resolver and report it in the same

$ grep -n "asserted \*\*per world\*\*" PLAN-001-implement-adr-002.md
653:- A17, A20 and A21 across both worlds, with A21's `Search` disclosure asserted **per world**: live

$ grep -c 'fault: "\\"deadline\\" \\"unknown\\""' scripts/dst/strict_replay_dst.ail
3
  (lines 1872 BashExec, 1873 RunTests, 1874 scripted Search)

$ sed -n '314p' src/core/tool_fault.ail
export pure func deadline_fault(elapsed_ms: int) -> ToolFault
```

Sanity checks on the copy:

```
$ grep -c '^## ' <copy>
12
$ awk '/## Traps carried forward/,/^---$/' <copy> | grep -oE '^[0-9]+\.' | tr -d '.' | tr '\n' ' '
1 2 3 4 5 6 7 8 9 10 11 12 13
$ grep -c "Amend I2\|W13 will meet" <copy>
0
```

The awk-trap hunk's claim, reproduced on this image (`mawk 1.3.4 20240123`):

```
$ echo x | awk 'f /^   Only/{exit}'
awk: line 1: syntax error at or near ^
$ echo x | awk 'f \
/^   Only/{exit}'
awk: line 2: syntax error at or near ^
```

No code, DST script, ADR or plan was touched. `git diff --name-only origin/main...HEAD` lists only the handoff.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
