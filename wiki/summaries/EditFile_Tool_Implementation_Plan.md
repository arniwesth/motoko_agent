---
doc_type: short
full_text: sources/EditFile_Tool_Implementation_Plan.md
---

## Goal

Add a native `EditFile` tool for targeted in-file edits without rewriting the entire file, while maintaining backward compatibility with existing tools like `WriteFile` and ensuring UI observability.

## Key Design Principles

- **Deterministic & safe**: Same input always produces same edit; fail on ambiguity unless `replace_all` is set.
- **Atomic writes**: No partial writes if any edit in a batch fails.
- **Observable**: Return a structured result plus [[concepts/diff-observability|unified diff]] and first changed line for UI/model feedback.
- **Backward-compatible**: Additive change; existing tools and protocol remain intact.

## Proposed Tool Contract (v1)

```json
{
  "id": "t1",
  "tool": "EditFile",
  "path": "relative/path",
  "edits": [
    {
      "old": "needle",
      "new": "replacement",
      "replace_all": false
    }
  ],
  "dry_run": false,
  "expected_sha256": "optional-hash"
}
```

Semantics:
- `edits` are applied sequentially against the current file content.
- `replace_all=false` requires exactly one match; `replace_all=true` replaces all occurrences (at least one must match).
- An [[concepts/optimistic-concurrency|optimistic hash guard]] (`expected_sha256`) prevents edits when the file has changed externally.
- `dry_run` computes and returns the diff without writing.
- Path safety is enforced: canonicalize against workspace, reject traversal (`..`), absolute paths, and symlinks that escape workspace (see [[concepts/path-safety]]).

## Execution and Observability

The tool engine reads the file once, validates preconditions, applies edits in order, then writes the result atomically (temp file + rename) if no failures occur. The result includes:
- `bytes_written`, new `sha256`
- `diff` (unified diff)
- `first_changed_line`
- `applied_edits` count and `dry_run` flag
- match strategy (`exact` in v1)

Errors provide actionable details: exact line/snippet hints for ambiguity, zero matches, or hash mismatches. The TUI renders the diff similarly to existing edit tools, with [[concepts/diff-observability|diff preview and collapse]] for large outputs.

## High‑Value Ideas from oh-my-pi and Codex

- **Strict-by-default matching** to prevent accidental broad changes.
- **Optimistic staleness protection** with `expected_sha256`.
- **Phased edit maturity**: start with strict text edits; future phases may add anchored (`LINE#ID`) or hunk/patch modes.
- **Clear error taxonomy** and a deterministic fallback ladder (exact, trim whitespace, Unicode normalization) reserved for relaxed future modes.
- **Transactional guarantee per file**: all edits succeed or none are written.

## Implementation Phases

1. **Type, Parser, Prompt Surface**: Add `EditOp`, `EditFile` tool variant, and result type; parse JSON; extend prompts to guide model usage (prefer `EditFile` for localized changes, `WriteFile` for full rewrites).
2. **Native Runtime Execution**: Implement edit engine in `tool_runtime.ail` with path guards, ordered apply, strict matching, hash guard, dry-run, and atomic writes.
3. **TUI Metadata & Rendering**: Update TUI types and display components to show edit count, diff preview, and collapsed view.
4. **Tests**: Parse tests, runtime tests for all success/error paths, path safety (traversal, absolute, symlink), read‑before‑edit enforcement, atomicity, TUI rendering, and protocol round‑trip stability.

## Safety and Rollout

The plan is additive, behind existing schema. Risks like ambiguous edits, concurrent modifications, and large diffs are mitigated by strict matching, `expected_sha256`, and UI truncation. Rollout proceeds phase‑wise with monitoring for tool parse errors and failure distributions.

## Future Extensions

Later phases may introduce an `ApplyPatch` tool for hunk‑based edits, anchor‑validated edit modes (`LINE#ID`), and a Codex‑style patch parser with a matcher ladder, while preserving transactional guarantees.