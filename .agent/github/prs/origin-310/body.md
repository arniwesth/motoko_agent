---
repo: arniwesth/motoko_agent
pr: 310
branch: arniwesth/041-docs-no-rotting-lines
ticket: null
title: "docs(041): stop the handoff's trap list pinning Makefile line numbers"
---

## Summary

Trap 9 of the W6–W7 handoff cited the overclaiming `verify_*` recipes by `Makefile` line number. #309's 6-line change shifted three of those targets by +6 the moment it merged, so the trap now names the targets instead of pinning lines. It also says **eight** recipes, not seven (the earlier list missed `verify_repetition_guard`), records that AILANG v0.55.0, v0.56.0 and v0.56.1 landed without the per-call timeout (`exec(cmd, args)` still has no timeout argument at the v0.56.1 tag, so W8 stays blocked), and warns that the check for the list must be scoped to trap 9's own sentence.

## Changes

- docs(041): name the verify_* targets instead of their line numbers

1 file changed. The eight overclaiming recipes are **not** fixed here; the `Makefile`, `src/`, `scripts/` and the plan files are untouched.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/HANDOFF-session-W6-W7-2026-11-02.md`

## Predicted outcome

- The trap list no longer goes stale when lines are added above a cited target: it contains no `verify_<name>:<line>` reference, so a future `Makefile` edit cannot make it point at the wrong recipe.
- The eight names in trap 9 equal exactly the set of recipes whose body has `[ $$rc -eq 0 ] || (echo`, the overclaiming shape. Checked by the scoped diff below; anyone can rerun it after a `Makefile` change.
- Document structure unchanged: traps numbered 1–13 and 12 `## ` sections.

## Test evidence

The committed file is byte-identical to the operator's final source (`.dagr/HANDOFF-W6-W7.md` in the shared checkout): `cmp` exit 0, 320 lines each, sha256 `2bf1d2e076f47cc94c365904849200e302310e408d51cacf532978ad89789219` for both, and `git show HEAD:<path> | cmp - <source>` exit 0.

Trap 9's names against the recipes that overclaim (A = names in trap 9's own sentence, minus `verify_native_path_guard`; B = from the `Makefile`):

```
$ sed -n '/\*\*Eight\*\* recipes/,/Only .verify_native/p' <copy> \
    | grep -oE '`verify_[a-z_]+`' | tr -d '`' | grep -v '^verify_native_path_guard$' | sort -u > A.txt
$ awk '/^verify_[a-z_]+:/{t=$1; sub(/:$/,"",t); g=t} /\[ \$\$rc -eq 0 \] \|\| \(echo/{print g}' Makefile | sort -u > B.txt
$ cat A.txt          # B.txt is identical
verify_delegate_kind
verify_exit_intent
verify_herdr_check_answer
verify_herdr_dagr_pane
verify_herdr_delegate_wait
verify_herdr_owner_tag
verify_repetition_guard
verify_wait_descriptor_fixtures
$ diff A.txt B.txt
(no output, exit 0)
```

Structure and line-pin checks:

```
$ grep -oE 'verify_[a-z_]+:[0-9]+' <copy>
(no output, exit 1)
$ awk '/## Traps carried forward/,/^---$/' <copy> | grep -oE '^[0-9]+\.' | tr -d '.' | tr '\n' ' '
1 2 3 4 5 6 7 8 9 10 11 12 13
$ grep -c '^## ' <copy>
12
```

Note on the scoped check: the `sed` range opens a second time at the caveat's own line, because it quotes "**Eight** recipes", and closes on the next line. The only name in that second range is `verify_native_path_guard`, which is filtered out, so A is unaffected.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
