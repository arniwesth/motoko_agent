---
repo: arniwesth/motoko_agent
pr: 310
branch: arniwesth/041-docs-no-rotting-lines
ticket: null
title: "docs(041): stop the handoff's trap list pinning Makefile line numbers"
---

## Summary

Trap 9 of the W6–W7 handoff cited the overclaiming `verify_*` recipes by `Makefile` line number. #309's 6-line change shifted three of those targets by +6 the moment it merged, so the trap now names the targets instead of pinning lines. It also says **eight** recipes, not seven (the earlier list missed `verify_repetition_guard`), records that AILANG v0.55.0, v0.56.0 and v0.56.1 landed without the per-call timeout (`exec(cmd, args)` still has no timeout argument at the v0.56.1 tag, so W8 stays blocked), and warns that the check for the list must be scoped to trap 9's own name list. The trap's self-check command was corrected twice after the first push and is now the command that was actually run (see below). A final pass fixes three text errors in trap 9: the heading still said "Seven more", a stray "syntax" in "syntax targets", and a false explanation of an awk quoting trap, now replaced by the real cause (a bare pattern before `/regex/` parsed as division), checked case by case below.

## Changes

- docs(041): name the verify_* targets instead of their line numbers
- docs(041): make the trap-9 self-check command actually correct
- docs(041): correct trap 9's count, stray word and awk explanation

1 file changed. The eight overclaiming recipes are **not** fixed here; the `Makefile`, `src/`, `scripts/` and the plan files are untouched.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/HANDOFF-session-W6-W7-2026-11-02.md`

## Predicted outcome

- The trap list no longer goes stale when lines are added above a cited target: it contains no `verify_<name>:<line>` reference, so a future `Makefile` edit cannot make it point at the wrong recipe.
- The eight names in trap 9 equal exactly the set of recipes whose body has `[ $$rc -eq 0 ] || (echo`, the overclaiming shape. Checked by the scoped diff below, using the command written in trap 9 itself; anyone can rerun it after a `Makefile` change.
- Document structure unchanged: traps numbered 1–13 and 12 `## ` sections.

## Test evidence

The committed file is byte-identical to the operator's final source (`.dagr/HANDOFF-W6-W7.md` in the shared checkout): `cmp` exit 0, 350 lines each, sha256 `3c7e7a5cffd8f194ab11878beb1797343b0908647a10251b2b18ca8e7760ba75` for both, and `git show HEAD:<path> | cmp - <source>` exit 0.

Trap 9's names against the recipes that overclaim (A = trap 9's own self-check command, run verbatim against the committed copy; B = an independent derivation from the `Makefile`):

```
$ awk '/all still unfixed after #309:/{f=1} f{print} \
       /^   Only .verify_native_path_guard. distinguishes/{if(f) exit}' <copy> \
    | grep -oE 'verify_[a-z_]+' | grep -v '^verify_native_path_guard$' | sort -u > A.txt
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

Text checks on the committed copy (`grep -c`):

```
"Seven more"                                 0
"syntax targets"                             0
"backslash continuation cannot go between"   0   (the earlier false explanation)
"the shell then parses the second"           0
"divided by"                                 1   (the corrected cause)
"silently matches nothing"                   1   (the non-erroring variant)
```

The awk explanation in trap 9, verified on a two-line input (`a`, `b`) with mawk 1.3.4 before committing:

```
(i)   awk '/^a$/{f=1} f /^b$/{print}' in.txt                  # one line, no backslash
      awk: line 1: syntax error at or near ^                   exit 2
(ii)  awk '/^a$/{f=1} f \
      /^b$/{print}' in.txt                                     # continuation
      awk: line 2: syntax error at or near ^                   exit 2
(iii) awk '/^a$/{f=1} f{print} \
      /^b$/{print "B:" $0}' in.txt                             # f has an action
      a / b / B:b                                              exit 0
(iv)  awk '/^a$/{f=1} f \
      NR==2{print "hit:" $0}' in.txt                           # concatenation
      (no output)                                              exit 0
```

(i) and (ii) fail the same way, so the continuation and the shell are not the cause; (iv) is the silent variant.

Note on the self-check: the first push scoped A with a `sed` range on the prose, which opened a second time at the caveat's own line (it quotes "**Eight** recipes") and passed only because the one name in that second range was filtered out by `grep -v`. Its replacement was corrected twice — the first draft read only one of the five lines holding the names; the second failed with an awk syntax error, first blamed on a literal backtick and then on the backslash continuation, both wrongly: the real cause is the bare-pattern division parse shown above — and the closing marker now uses `.` for the backtick (for readability only) and is anchored. The command above is the one now written in trap 9, run verbatim against the committed copy; it reproduces the eight names and `diff` against B is empty.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
