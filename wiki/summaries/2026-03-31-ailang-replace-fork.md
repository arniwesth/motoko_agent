---
doc_type: short
full_text: sources/2026-03-31-ailang-replace-fork.md
---

# Replaced aiLang with arniwesth/ailang fork

**Date:** 2026-03-31

Replaced the original `ailang/` directory (from `sunholo-data/ailang`) with a fork (`arniwesth/ailang`) and reapplied the two required runtime Go patches.

## Key actions

- Deleted the old clone and cloned the fork.
- Reapplied patches to `internal/effects/io.go` (added `ioPollStdin` effect) and `internal/builtins/io.go` (registered `_io_poll_stdin`).
- Built and installed with `go build/install`.
- Verified that `_io_poll_stdin(())` returns an empty string when no input is buffered.

## Findings & notes

- The fork is ahead of the original: it has extra builtins (e.g., `_io_exit`) and uses variable names `implPollStdin`/`typePollStdin` to avoid collisions.
- A [[version mismatch warning]] appears at runtime because the fork’s stdlib carries `v0.10.0` while the dev binary reports `dev` — this is harmless.
- Only the Go source [[ailang runtime patches]] were reapplied; non-Go files (prompts, tests) from the old clone were not carried over.

## Potential cross-document topics

- [[ailang fork]] — rationale for using the arniwesth fork instead of the original.
- [[ailang runtime patches]] — details of the stdin-poll additions.
- [[version mismatch warning]] — handling version tags vs dev builds.