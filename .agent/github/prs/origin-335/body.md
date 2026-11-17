---
repo: arniwesth/motoko_agent
pr: 335
branch: fix/tool-result-exit-code
ticket: null
title: "fix(tui events): a tool result's exit_code is the payload's, not the error flag's"
---

## Summary

Fixes #333. The TUI showed a BashExec that exited 127 as `[done] … exit=0`, while the model was
told 127. `tool_messages_to_result_jsons` (`src/core/session.ail`) built the `native_tool_results`
entry with `exit_code` derived from the payload's `error` flag. A non-zero BashExec carries no
such flag. This reads `exit_code` from the payload and falls back to `error` only when the payload
has no numeric `exit_code`.

## Changes

- fix(tui events): a tool result's exit_code is the payload's, not the error flag's

1 file changed.

- **`exit_code`** is the payload's own when it is a number. Every `tool_result_item_to_json` arm
  writes one. A payload without one (`policy_denied_message`, `delegated_deferred_message`, a tool
  fault) falls back to `error: true` → 1, else 0, as before. No payload built in `src/` or
  `packages/` sets `error: true` with `exit_code: 0`, so the two rules agree on every shape the
  harness emits.
- **`truncated`** was a constant `false` for the same reason, so the TUI never marked a cut output.
  It is now the payload's flag. It's the same defect on the line below, so it's fixed here rather
  than in a second PR.
- **Which code it reads.** The event reads the model-facing content, not the typed code WI-D23 made
  authoritative for callers that branch. The row displays the message the model read. A native
  tool's content takes its `exit_code` from `tool_result_exit_code`, the accessor the typed path
  reads, so the two cannot drift. The batch accumulates `[Message]`, so threading the typed code
  through would mean changing `accumulated_tool_msgs`. Nothing here needs that.
- **Anchors.** The nine replaced lines are nine, and `asNumber` joins the existing `std/json`
  import line. The five `clock_now` sites `dst_attribution_table` pins (1463, 1722, 1834, 3834,
  4013) do not move. The regression test is at the end of the file for the same reason.

## Governing docs

- `.agent/projects/009_motoko_dst_execution/NOTE-d23-the-exit-code-reaches-the-caller.md`: the
  typed code's authority, and why this display reads the content instead (above).
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`,
  the amendment of 2026-08-03 (WI-A5): `src/core/dst_attribution_table.ail` cites each clock site
  by line, and `make attribution_table` re-checks the line's content. A moved site re-issues every
  profile that refers to the table (`attribution-identity-stale`), which is why this edit keeps the
  line count.

## Predicted outcome

A BashExec, or RunTests, that exits non-zero renders `failed` with its real code in the TUI. A cut
output shows as truncated. Denials and tool faults still render `failed` with `exit=1`. Checked by
`test_333_result_jsons_carry_the_payload_exit_code` under `make terminal_trace`
(`ailang test src/core/session.ail`), and by running a failing command in the TUI.

## Test evidence

AILANG v0.60.4, dev box (linux arm64), on `d66085ab`.

- `ailang test src/core/session.ail`: 47 of 47 passed. The new test failed on `origin/main`
  (46 of 47) before the fix.
- Mutants, each reverting one part of the fix, each red on the new test (46 of 47):
  - A, `exit_code` derived from `error` again;
  - B, `truncated` a constant `false`;
  - C, no `error` fallback.
  The restored file was byte-identical and green.
- `make check_core`: 61 passed, 0 failed.
- `make new_contract_policy BASE=origin/main`: no `pure func` added.
- `make dst` (681 s, `-j8`): exit 2, "no new failures". The one red target is
  `declared_vs_performed`, already listed in `DST_KNOWN_RED` on `main`. Every scenario that emits
  `native_tool_results` passed, including `ledger_parity`, `latency_pair`, `herdr_graded` and the
  phase C wiring scenarios.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
