# Differential test for `PairingModel.lean`

`run_diff.sh` compares the model's `hostPending` with the real `SessionJournal.updatePending`
(`src/tui/src/session-journal.ts:865-875`) over every history of length 0 to 4 in an
eleven-message alphabet: 16,105 histories. It then runs a bounded check of
`host_twin_agrees` on the model's own outputs. See RESEARCH-lean-harness-properties.md §6.

| File | What it is |
|---|---|
| `enumerate.ts` | The TypeScript half: the real class, reached through a cast to its private `updatePending` |
| `enumerate.lean.tail` | The Lean half: appended to `../PairingModel.lean`, prints one line per history |
| `run_diff.sh` | Runs both, diffs fields 1-2, then the bounded check; `--ts-only` runs the bun half alone and exits 2 |

## Runs

| Date | Commit | Half | Result |
|---|---|---|---|
| 2026-11-03 | `43530c0` | bun 1.4.4, `--ts-only` | 16,105 histories; output sha256 `6de0b5877d1ace2f…`. **Not a pass**: nothing was compared |
| 2026-11-03 | `43530c0` | Lean | **Not run.** `release.lean-lang.org` answered 403 from the session's sandbox, so `elan` could not install 4.28.0 |
| 2026-11-03 | `43530c0` | AILANG | **Not run.** No AILANG half exists yet (RESEARCH §10 item 2), and AILANG v0.54.14 could not be built: `proxy.golang.org` was unreachable |

A run that compares the two halves goes in this table with its mismatch count and the
`axioms.txt` it wrote. Until then the table says what it says: one half ran.

Spot checks of the bun output, read by hand against the model's definition (not a
substitute for the run):

| History (alphabet indices) | Host pending | Why it matters |
|---|---|---|
| `1,8` | `b` | (H2) violated: the host reads the tool message's calls as a new batch |
| `10,4` | (empty) | (H1) violated in the trailing batch: the host filters `""`, the fold keeps it open |
| `1,9` | (empty) | The host closes a call on a non-tool message with an id; the fold refuses this history, so the theorem does not cover it |
