# Brief: adversarial review of ADR-002 (park and wake)

Repo: /workspaces/motoko_agent, branch `arniwesth/013-dst-architecture-adr`. Read-only review:
edit no file under the repo except the one review document you write; run no commit; run no
`make dst` sweep. Two other agents are editing this working tree concurrently (an Opus worker
on `packages/motoko-ext-*`, `src/core/session.ail`, `src/tui/src/session-logger.ts`; a motoko
worker on `src/core/*.ail`). Make no claim about their uncommitted changes; cite HEAD.

## Under review

`.agent/projects/013_core_architecture_for_dst/ADR-002-park-and-wake.md` — Proposed, v1,
direction chosen by the owner. Five decisions D1–D5. Review each decision independently and
give a verdict per decision: ACCEPT / ACCEPT WITH CORRECTIONS / REJECT, with the reason, in the
same table shape as `REVIEW-adr001-v2-verdicts-codex.md` §1 in the same directory (read that
file first: it is the standard this review is held to — every claim re-measured at HEAD, source
coordinates re-read, no verdict from prose alone).

## Inputs the ADR relies on (read them; check the ADR against them, not the reverse)

- `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md` — the
  evidence. Re-derive at least the 193-step count and the four-idle-meanings claim from the
  logs it names (`.motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl`, orchestrator turn
  with session_id `1788636426215`).
- `ADR-001-sequencing-the-dst-architecture-caps.md` D2, D6, and "Not decided".
- `PLAN-001-implement-adr-001.md` §2.1 and `tools/driver_leaf_inventory/derive.py` — the
  five-class freeze the ADR proposes to move.
- `.agent/projects/020_herdr_agent_integration/ADR-001-herdr-agent-integration.md` D1–D3.
- `.agent/projects/021_herdr_delegation/DESIGN-motoko-as-delegate.md` §3,
  `DESIGN-dagr-as-delegation-view.md` §3.3.
- Code at HEAD: `src/core/phase_vocab.ail` (StepDecision ~:449), `src/core/step_machine.ail`
  (`decide`), `src/core/ports.ail` (`approval_read` ~:789, the Ports record ~:783–939),
  `src/core/test/scripted_ports.ail`, `src/core/session.ail` (~:3270 multi-turn block; ~:1073
  `decode_or_empty` consumer), `src/tui/src/herdr-agent-state.ts`, `src/tui/src/index.ts`
  (`--headless`), `packages/motoko-ext-herdr/herdr.ail` and `types.ail`.
- `herdr` CLI at `$HERDR_BIN_PATH`: `herdr pane report-agent --help`, `herdr agent wait --help`.
  You are inside herdr (`HERDR_ENV=1`); read-only commands are fine; do not open, close or
  prompt any pane or agent.

## Questions the review must answer, beyond per-decision verdicts

1. Is `approval_read` actually the right template for `wake_read`? Read how it is served on the
   production side (the TUI/RPC path) and the DST side, and say whether a blocking read that can
   last minutes fits the same RPC shape or needs something the ADR does not name.
2. The ADR asserts `Finalize` on a stop with open waits becomes unreachable. Check `decide`'s
   actual precedence (persist nudges, DP7, empty-stop, the guards as extensions) and say whether
   `Park` can be inserted where the ADR says without breaking an existing decision's test.
3. The sixth `RequestClass`: is "after P2 lands" the right sequencing, or does adding a Ports
   field before P2 cost less? Price it from the code, not from the ADR.
4. D1's one-shot exit: does the extension's `do_check_motoko` really settle `done` on an early
   answer read when the agent is already gone? Read the branch order in `herdr.ail` ~:996–1065
   and say so with line numbers.
5. Is there a cheaper design the ADR did not consider that meets the same "≤ 4 model steps"
   number and stays DST-replayable? If yes, describe it in ≤ 10 lines.
6. Anything the ADR gets factually wrong about the code or the measurements: list every one.

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-adr002-verdicts-codex.md` in the
shape of `REVIEW-adr001-v2-verdicts-codex.md`: header (date, HEAD, reviewer, method, what you did
not do), §1 verdict table, then one section per decision, then the six questions, then
"Corrections to the ADR" as a numbered list. Every claim carries a file:line or a command and
its output. Temporary evidence goes under
`<scratchpad>/`.
When finished, reply with only the review file's path.
