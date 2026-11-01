---
repo: arniwesth/motoko_agent
pr: 297
branch: arniwesth/041-d5-sigkill-wording
ticket: null
title: "docs(041): state SIGKILL's pipe limit in D5 (041 D5)"
---

## Summary

Follow-up to 041 W2. One sentence in ADR-002 D5 becomes accurate. No ruling changes: R10 still says SIGKILL stays disclosed.

**What D5 said.** "the runtime cannot clean up after it, so the command survives. A row in the same probe pins today's behaviour, and the operator documentation states it."

**What W2 measured.** In #293: "a command that later writes to stdout dies of SIGPIPE at that write, because its pipes died with the runtime." W2 measured this once, on stdout, and kept no raw output.

**What changed.** D5's third bullet, which now reads:

> SIGKILL gets the same treatment under R10: the runtime cannot clean up after it, so the command keeps running and its side effects still happen. Its stdout and stderr pipes died with the runtime, so its next write to them normally ends it with SIGPIPE. A row in the same probe pins the surviving case, and the operator documentation states it.

## Evidence

`evidence/d5-sigkill/measurement.md` holds the re-measurement: AILANG v0.54.14, Linux, dash, three rounds of nine cases, with identical results each round.

| After the runtime's SIGKILL | Result |
|---|---|
| No further write to stdout or stderr | The command finishes and its marker appears |
| Write to stdout or stderr | The write ends with status 141, and a later file write in the same shell never happens |
| Write with SIGPIPE ignored | The write fails with status 1 and the command finishes. This is why D5 says "normally" |
| Same write, no kill (control) | The command finishes |

## Notes for review

- **Depends on #293 for one claim.** D5 cites the row and the operator documentation, and both are on #293, not yet on `main`. The ADR already described them before this PR.
- **`docs/configuration.md` is unchanged.** #293's text already agrees with the new wording, and it is not on this branch, so editing it here would only conflict with #293.
- **No SIGPIPE row.** The existing row pins the surviving case. Adding a row for the SIGPIPE case is a separate decision.
- **Not changed:** R10, R5, D6, section 6, `PLAN-001`, the probe, the `Makefile`, any `.ail` file. The ADR's revision line is also unchanged.
- **Line numbers.** Lines after the bullet in the ADR move down by 2. Nothing found in the repository cites this ADR by line number at or past that point.

## Test evidence

| Command | Exit | Result |
|---|---|---|
| `env -u AILANG_FS_SANDBOX make check_core` | 0 | Sanity signal only: this PR changes no code. `src/core/ type-check: 60 passed, 0 failed` |
| `make anchors` | 0 | All ten anchors hold. They cover code only, so the ADR edit cannot move them |

CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
