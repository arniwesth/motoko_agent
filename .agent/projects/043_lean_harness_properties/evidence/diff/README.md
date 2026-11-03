# Differential test for `PairingModel.lean`

`run_diff.sh` runs three halves over every history of length 0 to 4 in an eleven-message
alphabet, 16,105 histories: the model (`../PairingModel.lean`), the real
`SessionJournal.updatePending` (`src/tui/src/session-journal.ts:865-875`) and the real
`fold_journal` (`src/core/journal.ail`). It compares the model with each real function, runs a
bounded check of `host_twin_agrees` on the model's own outputs, and compares the two real
functions with each other. See RESEARCH-lean-harness-properties.md §6.

| File | What it is |
|---|---|
| `enumerate.ts` | The TypeScript half: the real class, reached through a cast to its private `updatePending` |
| `enumerate.lean.tail` | The Lean half: appended to `../PairingModel.lean`, prints one line per history |
| `enumerate_fold.ail` | The AILANG half: the real `fold_journal`, over journals written by `journal_lines_of_records` |
| `compare_fold.awk` | The model's fold against the real fold, and the real host against the real fold |
| `run_diff.sh` | Runs all three: diffs the host fields, the bounded check, then `compare_fold.awk`. `--ts-only`, or a missing toolchain, exits 2 |

## Runs

| Date | Commit | Half | Result |
|---|---|---|---|
| 2026-11-03 | `43530c0` | bun 1.4.4, `--ts-only` | 16,105 histories; output sha256 `6de0b5877d1ace2f…`. **Not a pass**: nothing was compared |
| 2026-11-03 | `43530c0` | Lean | **Not run.** `release.lean-lang.org` answered 403 from the session's sandbox, so `elan` could not install 4.28.0 |
| 2026-11-03 | `43530c0` | AILANG | **Not run.** No AILANG half exists yet (RESEARCH §10 item 2), and AILANG v0.54.14 could not be built: `proxy.golang.org` was unreachable |
| 2026-11-03 | `43530c0` | Lean 4.28.0 and bun 1.4.4 | **0 mismatches** over 16,105 histories; bounded check 449 accepted within H1/H2, 0 disagree. Exit 0. Details below |
| 2026-11-03 | `43530c0` | Lean 4.28.0, bun 1.4.4 and ailang v0.54.14, three-way | **0 mismatches** in each comparison: model and host, model and fold, and host and fold on the 449 histories the real fold accepts within H1/H2. Exit 0. Details below |

A run that compares the halves goes in this table with its mismatch counts and the
`axioms.txt` it wrote.

### The Lean run of 2026-11-03

What it covered: the model's **host** side (`hostPending`) against the real `updatePending`. At
this run the model's **fold** side (`pairing`) had not been compared with the real `pair_step`;
the three-way run below does that.

- **Code under test:** `origin/main` `43530c0a`, unchanged. **Machine:** linux aarch64. **Lean:**
  4.28.0 (`7e01a1bf5c70`), core only, installed with elan 4.2.4 as
  `elan toolchain install leanprover/lean4:v4.28.0`; `run_diff.sh` was run with that toolchain's
  `bin/` first on `PATH`. **bun:** 1.4.4.
- **Kernel:** `PairingModel.lean` checks with no error in about 0.5 s.
- **Differential:** `ts.out` and `lean.cmp` are byte-identical, 16,105 lines, sha256
  `6de0b5877d1ace2f04df4336baa4d0ce1a59b1fd48e5da15ec4a26a44100a271` (the same bun output as
  the `--ts-only` row). `lean.out`, with the fold's fields, in the four-field format of this
  run: sha256 `b890f15f6e5b6f1008aaad8482eda1cb644a06d2984466ddfb333399268848d4`.
- **Bounded check:** the model's fold accepts 833 histories and refuses 15,272. Of the 833, 449
  satisfy (H1) and (H2), and in none of them does host pending differ from fold open ids. The
  other 384 contain message 8 (violates H2) or message 10 (violates H1), and 222 of those do
  differ, the cases `twin_disagrees_without_h2` and `h1_not_free_in_trailing_batch` state.
- **Axioms:** `#print axioms` for every one of the file's 16 theorems. The file printed 5 of them
  at the run; it now also prints the two controls and the witness, so `axioms.txt` has 8 lines,
  and a re-run with that change gave the same 0 mismatches and the same `lean.out`. Nothing
  beyond `propext` and `Quot.sound`; no `sorryAx`, no `Classical.choice`, no
  `Lean.ofReduceBool`.

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

At this run the AILANG half was not yet written.

### The three-way run of 2026-11-03

What it adds is the real fold. `enumerate_fold.ail` writes each history as a journal with
`journal_lines_of_records`, the module's own writer twin, the way `journal.ail`'s tests build
theirs, and folds it with `fold_journal` at its leaf. So the model's `pairing` is compared with
the real `pair_step`, and the cross-language contract is checked on the two real functions
directly, with no model between them.

- **Code under test:** `origin/main` `43530c0a`, unchanged. **ailang:** v0.54.14, the pin. The
  AILANG half takes about 1 min 45 s, which is nearly all of `run_diff.sh`'s time.
- **Output format.** The fold-side lines now end with the number of ids, in
  `enumerate.lean.tail` as in `enumerate_fold.ail`. Joining `[""]` and `[]` both give `""`, so
  without the count the comparison could not see §6.2's case. `lean.out` changed with it: sha256
  `c729a3cb30df336a057c31fb99709d1de9deb2bbfb8661a487b8fa3eb4f3bdde`. `ts.out` and `lean.cmp`
  did not (`6de0b5877d1ace2f…`). `ail.out`: sha256
  `953896c1a30e5ccc9efb386080462fb025d850fad84cb01450573cabf5286437`.
- **The model against the real fold:** 0 mismatches.

  | Model | Real fold | Histories |
  |---|---|---|
  | refuses | refuses with `pairing` | 15,272 |
  | accepts | accepts, with `dangling` equal to the model's open ids | 750 |
  | accepts | refuses with `transcript`, a check the fold runs after pairing | 83 |

- **The real host against the real fold** (`exit.pending_tool_calls` against
  `SessionState.dangling`): of the 449 histories the real fold accepts within (H1) and (H2),
  none disagree. Outside them 213 do: 87 contain message 8 only, 78 message 10 only, 48 both.
- **The note's predictions, on the real code:**

  | History | Prediction | Real fold | Real host pending |
  |---|---|---|---|
  | `1,4,4` | `admits_duplicate_result` | accepts | none |
  | `1,4,7,4` | `admits_result_after_user` | accepts | none |
  | `10,4` | §6.2: the fold keeps the trailing empty id, the host drops it | accepts, `dangling = [""]` | none |
  | `1,8` | `twin_disagrees_without_h2` | accepts, `dangling = []` | `b` |

  Message 10, a call with an empty id, is in 3,730 histories without message 8. The real fold
  refuses 3,604 of them with `pairing` and 48 with `transcript`, and accepts 78, and the host
  disagrees with it on all 78. That is the size, in this alphabet, of §6.2's "refuses most such
  histories, but not all".
- **Negative control on the fold side.** One mutant at a time in the real `pair_step`,
  `enumerate_fold.ail` re-run and compared with this run's `lean.out` through
  `compare_fold.awk`, the file restored with `git checkout`:

  | Mutant in `journal.ail` | Model and real fold | Host and fold, within H1/H2 |
  |---|---|---|
  | a result is checked against `open_ids`, not `cur_ids` | 173 mismatches | 0 of 405 disagree |
  | a result never closes its call (`then acc`) | 500 mismatches | 86 of 327 disagree |

  The first mutant is half of the fix RESEARCH §10 item 3 sketches. On the real code it refuses
  44 of the 449 histories the unmutated fold accepts within (H1) and (H2), and the host and the
  fold still agree on every one it accepts.
- **Why a program and not an in-module test.** §10 item 2 asked for a test in `journal.ail`.
  This leaves `src/core` unchanged, and no test pins the two admitted shapes as correct before
  §10 item 3 decides whether they are.
- **What it does not show.** Reachability, Kiro's steps 6 and 7: whether any writer or provider
  adapter produces message 8, message 10, or a second result for an answered call. The
  journals here come from the AILANG writer twin, not the TypeScript host's writer. Until one
  is shown reachable, each shape is reproduced on the real code but is still an observation,
  not a finding (RESEARCH §6.3).
- **What the proof added.** Within this alphabet and up to length 4, this run on the two real
  functions shows everything the theorems state, without the model. What the proof adds is
  `host_twin_agrees` for every length, about the model; the differential test ties the model
  to the code only up to length 4.

Spot checks of the bun output, read by hand against the model's definition (not a
substitute for the run):

| History (alphabet indices) | Host pending | Why it matters |
|---|---|---|
| `1,8` | `b` | (H2) violated: the host reads the tool message's calls as a new batch |
| `10,4` | (empty) | (H1) violated in the trailing batch: the host filters `""`, the fold keeps it open |
| `1,9` | (empty) | The host closes a call on a non-tool message with an id; the fold refuses this history, so the theorem does not cover it |
