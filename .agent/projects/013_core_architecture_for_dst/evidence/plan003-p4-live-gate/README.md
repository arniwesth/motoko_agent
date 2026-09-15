# PLAN-003 P4 Part 7 — the live gate (T4), captures

ADR-003 v6.1 D7, PLAN-003 §P4 Part 7. Run 2026-09-15 by the P4.7 worker in a herdr pane
(`w1:p3M`, tab `w1:tA`), `--park-exits` passed explicitly, profile `default`, model
`openrouter/anthropic/claude-haiku-4.5`, delegate kind `claude`. Each capture is one session:

| dir | what | wake outcome |
|---|---|---|
| `success/` | the gate's success path: Delegate → park → child exits → delegate answers → `wake` as the park's child → `--resume` respawn → `<R'>.p0` served from the cursor → DelegateCheck → final answer | `settled` |
| `lost/` | the `Lost` control: the delegate pane closed while the host is in suspended-child | `lost` |
| `attempt1-r5-window/` | the first success-path attempt, which did NOT wake: the delegate's answer was on disk 13 s before the park, and Part 4's R5 rule dropped the waiter's reply in the kill→exit window (finding 1, reported in §5); its `recovery-*` files are the same session restarted WITHOUT `--park-exits`, which re-observed the park and read the answer (`recovery-wire.jsonl` is the wire from that restart on; `recovery-journal.jsonl` the whole journal) | none (quit; `exit(host_exit)`); then `settled` on the re-observation |

Per capture: `wire.jsonl` (the SessionLogger's copy of both children's stdout, in order),
`transcript.md`, `journal.jsonl` (the session's journal as it stood after the host quit),
`session-dir-while-suspended.txt` (the session directory's listing while the host was in
suspended-child), `host-children-while-suspended.txt` (the host's child processes then: none),
`resumed-child-argv.txt` (the respawned child's argv, read from `ps` while it ran), `judge.log`, the output of `judge.sh` over the capture, and `timeline.txt`, the journal's boundary
entries with UTC times. `judge.sh <sid> <wire> <journal> <dir-listing-while-suspended> [expected
outcome]` re-checks a capture; `lost/` is judged with `host_error` (finding 2).
