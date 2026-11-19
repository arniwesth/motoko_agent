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

A second commit closes the same symptom for a result over 64 KB. `cap_tool_message_content` cuts
such a message, it no longer decodes, and the row fell back to `{}`: `[done] exit=0`, not marked
truncated. AILANG's process limit is 10 MB, so a BashExec that prints 100 KB gets there.

## Changes

- fix(tui events): a tool result's exit_code is the payload's, not the error flag's
- fix(tui events): a capped tool result keeps its exit code and reads truncated

3 files changed, plus this record.

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
- **A cut result.** The cap cuts from the end. BashExec and RunTests render `exit_code` ahead of
  `stdout`, and a refusal renders `error` ahead of `message`, so the head still holds them.
  `capped_result_fields` reads them back from a content that `tool_message_capped` recognises,
  and marks it truncated. ReadFile, Search, WriteFile and EditFile render their code after the bulk
  and can lose it, but theirs is always 0, the fallback. A number the marker cut into does not
  decode, so `12` is never read as `1`. Content that never was JSON, such as an extension's plain
  text, stays `{}` as before. The TUI shows no stdout for a cut row, as before: recovering a cut
  string from broken JSON is not attempted.
- **One spelling of the marker.** `cap_marker_head` in `phase_vocab.ail` is read by the cap and by
  `tool_message_capped`, so recognising a cut cannot drift from making one. The cap's output is
  byte-identical. Both new `pure func`s carry contracts, both classified `substantive` and pinned
  in `tools/verify_classify/contracts.register`. That file's totals line already said 79 for 80
  entries on `main`; it now reads 82.
- **Anchors.** The nine replaced lines are nine, and `asNumber` joins the existing `std/json`
  import line, as do `find` and `tool_message_capped` on theirs. The five `clock_now` sites `dst_attribution_table` pins (1463, 1722, 1834, 3834,
  4013) do not move. The new helper and both tests are at the end of the file for the same reason.

## Governing docs

- `.agent/projects/009_motoko_dst_execution/NOTE-d23-the-exit-code-reaches-the-caller.md`: the
  typed code's authority, and why this display reads the content instead (above).
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`,
  the amendment of 2026-08-03 (WI-A5): `src/core/dst_attribution_table.ail` cites each clock site
  by line, and `make attribution_table` re-checks the line's content. A moved site re-issues every
  profile that refers to the table (`attribution-identity-stale`), which is why this edit keeps the
  line count.

## Predicted outcome

A BashExec, or RunTests, that exits non-zero renders `failed` with its real code in the TUI, also
when its output is over 64 KB. A cut output shows as truncated. Denials and tool faults still render `failed` with `exit=1`. Checked by
`test_333_result_jsons_carry_the_payload_exit_code` and `test_333_capped_result_keeps_its_exit_code`
under `make terminal_trace`
(`ailang test src/core/session.ail`), and by running a failing command in the TUI.

## Test evidence

AILANG v0.60.4, dev box (linux arm64). The first commit, `d66085ab`:

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

The second commit, `fc546d68`:

- The capped test failed before the fix for the reason given: with its expectation flipped to
  `0/false`, it passed. After the fix, `ailang test src/core/session.ail` passes 48 of 48.
- Mutants, each red on the capped test (47 of 48):
  - D, decode failure gives `{}` again;
  - E, no cut at the comma;
  - F, no `error` scan;
  - G, every undecodable content counts as cut.
  The restored file was byte-identical.
- `ailang test src/core/phase_vocab.ail`: 43 of 43, including both cap tests.
- `make new_contract_policy BASE=origin/main`: "2 in-scope new pure func declarations, all
  justified".
- `make verify_classify_check`: "85 contracts, register agrees".
- `make verify_core`: 84 contracts proven, 0 files failed. `phase_vocab.ail` now ticks, 2 proven.
- `make check_core`: 61 passed, 0 failed.
- `make dst` (970 s, `-j8`): exit 2, "no new failures". The one red target is again
  `declared_vs_performed`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
