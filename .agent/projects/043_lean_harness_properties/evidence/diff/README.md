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
| 2026-11-03 | `43530c0` | Lean 4.28.0 and bun 1.4.4, full | **0 mismatches** over 16,105 histories; bounded check 449 accepted within H1/H2, 0 disagree. Exit 0. Details below |

A run that compares the two halves goes in this table with its mismatch count and the
`axioms.txt` it wrote.

### The full run of 2026-11-03

What it covers: the model's **host** side (`hostPending`) against the real `updatePending`. The
model's **fold** side (`pairing`) has not been compared with the real `pair_step` (no AILANG
half), so every statement about the fold is still about the model.

- **Code under test:** `origin/main` `43530c0a`, unchanged. **Machine:** linux aarch64. **Lean:**
  4.28.0 (`7e01a1bf5c70`), core only, installed with elan 4.2.4 as
  `elan toolchain install leanprover/lean4:v4.28.0`; `run_diff.sh` was run with that toolchain's
  `bin/` first on `PATH`. **bun:** 1.4.4.
- **Kernel:** `PairingModel.lean` checks with no error in about 0.5 s.
- **Differential:** `ts.out` and `lean.cmp` are byte-identical, 16,105 lines, sha256
  `6de0b5877d1ace2f04df4336baa4d0ce1a59b1fd48e5da15ec4a26a44100a271` (the same bun output as
  the `--ts-only` row). `lean.out`, with the fold's fields: sha256
  `b890f15f6e5b6f1008aaad8482eda1cb644a06d2984466ddfb333399268848d4`.
- **Bounded check:** the model's fold accepts 833 histories and refuses 15,272. Of the 833, 449
  satisfy (H1) and (H2), and in none of them does host pending differ from fold open ids. The
  other 384 contain message 8 (violates H2) or message 10 (violates H1), and 222 of those do
  differ, the cases `twin_disagrees_without_h2` and `h1_not_free_in_trailing_batch` state.
- **Axioms:** `#print axioms` for every one of the file's 16 theorems. The file printed 5 of them
  at the run; it now also prints the two controls and the witness, so `axioms.txt` has 8 lines,
  and a re-run with that change gave the same 0 mismatches and the same `lean.out`. Nothing beyond `propext` and `Quot.sound`; no `sorryAx`,
  no `Classical.choice`, no `Lean.ofReduceBool`.

  | Theorem | Axioms |
  |---|---|
  | `admits_duplicate_result`, `admits_result_after_user`, `refuses_unanswered_call_before_user`, `refuses_result_for_unmade_call`, `trailing_call_is_dangling`, `twin_disagrees_without_h2`, `h1_not_free_in_trailing_batch` | none |
  | `host_twin_agrees`, `agrees_fold`, `step_agrees` | `propext`, `Quot.sound` |
  | `err_sticky`, `containsString_mem`, `filter_eq_without`, `filter_nonempty_id`, `tag_map`, `tag_mem` | `propext` |

- **Negative control** (039's practice; RESEARCH §4 says it is not wired in, and it still is
  not). One mutant at a time in the real `updatePending`, `enumerate.ts` re-run, its output
  compared with the unmutated run's `lean.cmp`, the file restored with `git checkout`:

  | Mutant in `session-journal.ts` | Histories that mismatch |
  |---|---|
  | drop `.filter((id) => id !== "")` from the new open set | 2,252 of 16,105 |
  | `if (answered !== "")` → `if (false)`: a result never closes a call | 2,940 of 16,105 |
  | `if (calls.length > 0)` → `if (calls.length > 0 && m.role !== "tool")` | 1,842 of 16,105 |

  So the test can tell the real twin from a twin that differs in any one of its three rules.
  Note the third mutant: a role-aware host would agree with the fold on message 8, which is
  (H2)'s case, and the differential test does see it as a change.

The AILANG half is still not written. `ailang` v0.54.14, the pin, is installed on the machine
that ran this, so RESEARCH §10 item 2 is not blocked there; it was not attempted.

Spot checks of the bun output, read by hand against the model's definition (not a
substitute for the run):

| History (alphabet indices) | Host pending | Why it matters |
|---|---|---|
| `1,8` | `b` | (H2) violated: the host reads the tool message's calls as a new batch |
| `10,4` | (empty) | (H1) violated in the trailing batch: the host filters `""`, the fold keeps it open |
| `1,9` | (empty) | The host closes a call on a non-tool message with an id; the fold refuses this history, so the theorem does not cover it |
