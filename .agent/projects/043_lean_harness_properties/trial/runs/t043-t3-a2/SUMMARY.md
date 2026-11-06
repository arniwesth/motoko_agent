# T3 — the journal writer twin and the round trip (arm A, replicate 2)

Targets: `SessionJournal` (`src/tui/src/session-journal.ts:139`, the host writer) and
`journal_lines_of_records` (`src/core/journal.ail:2137`, the twin), judged by `fold_journal`
(`:1677`). Method: executed checks only. Every check calls the real functions. No model of
them was written.

## Findings (details in `reports.tsv`)

| id | property | what | reachable at HEAD |
|---|---|---|---|
| A2-T3-1 | P3.1 | **Twin**: `HistoryReplaced` never sets `replaced_since_seed`. After a checkpoint, a same-profile `--resume` seed is dropped instead of becoming `history_replaced(resume)`, so the twin's journal is refused (`digest`) where the host's is accepted. | yes (checkpoint, then crash or quit, then `--resume`) |
| A2-T3-2 | P3.1 | **Host**: `replaceLastHistoryMessage` ignores its message, so a `replaces_previous` entry's calls never become pending. The resume is not armed, the seed is dropped, the session is marked unresumable, and the host's journal is refused (`digest`) where the twin's is accepted. Without a later append, both accept but `dangling` differs. | no live HEAD child sets `replaces_previous`. Reachable through `adopt()` of a journal recorded before 005 W3 |
| A2-T3-3 | X-1 | Same root cause as A2-T3-2, a different observable: the host writes `exit.pending_tool_calls = []` for a journal the fold reports `dangling = [h1]` for. | as A2-T3-2 |
| A2-T3-4 | P3.2 | **Twin** refuses (`digest`) the record list `run_v2_session_park_resumed_traced` returns, because the wake message's `HistoryAppended` comes before that run's `HistorySeeded`. | the trace is real. No current caller folds it alone (`park_resume_dst` prepends frame 1) |
| A2-T3-5 | X-2 | The writers disagree on `first_kept`. The twin copies it verbatim; the host range-checks it against a count that leaves out the checkpoint's head prefix. So `-1` gives head-prefix refusal vs accept, and a valid index `4` gives two different histories. | no: `first_kept` is always `None` at HEAD |
| A2-T3-6 | X-3 | **Host** `adopt()` leaves a torn last line in place, and the next append is glued onto it. A journal that folded becomes permanently unreadable (`entry`/json). | needs a partial write (kill -9, power loss, ENOSPC), which the adopt comment itself anticipates |

Every repro exits 1 on the real code (`work/repro_check.log`). The repros for A2-T3-1, -2, -3
and -6 were also checked to exit 0 on a copy with a minimal fix (`out/work/fix/`):
- `journal_fixed_twin.ail` adds `replaced_since_seed: true`;
- `session-journal.fixed.ts` adds `this.updatePending(message)`;
- `session-journal.fixed-x3.ts` truncates the torn bytes.

The A2-T3-4 and A2-T3-5 repros were not fix-validated. Their right fix is a design choice
(where a pre-seed append belongs; which `first_kept` count is authoritative). The A2-T3-4 repro
judges only acceptance, so any fix that makes the fold accept that trace turns it to 0. The tree itself was not modified, apart from the harness copies
described under "Running".

Exploratory properties used above:
- **X-1**: on every journal the fold accepts, the host's `pendingToolCalls` (what `writeExit`
  writes as `pending_tool_calls`) equals the fold's `dangling`.
- **X-2**: P3.1 extended to `history_replaced` events that carry `first_kept` (not emitted at HEAD).
- **X-3**: a journal the fold accepts stays accepted after the adopting host appends to it.

## What was checked, how, and up to what size

### The generator (`harness/t3gen.ail`)

The generator is a small input child. It keeps the history a run keeps, plus the `{at, prev}`
chain pair the conversation loop threads. It turns an action symbol into the journal-class
`LedgerEvent`s the real child emits at that point. Every digest comes from the real functions,
computed as the emit sites in `session.ail` compute them: seed `:3868`, `c2_append_step` `:841`,
checkpoint `:3109`/`:3141`, follow-up turn `:4350-4392`, resume `:4805`. The wire form is the
real `phase_vocab.to_schema_v1`.

| # | action | events |
|---|---|---|
| 0 | A | assistant text |
| 1 | C1 | assistant with one call |
| 2 | C2 | assistant with two calls |
| 3 | T | result for the first open call |
| 4 | HP | hybrid plain assistant |
| 5 | HR | hybrid replacement, `replaces_previous`, chained from `prev` |
| 6 | K | checkpoint `HistoryReplaced` + `StateDelta` |
| 7 | D | `StateDelta` |
| 8 | F | follow-up turn: `RunSummary`, `SessionStart`, `HistoryAppended(user)`, `HistorySeeded` |
| 9 | R | crash + same-profile resume: `SessionResumed`, `HistorySeeded(folded, dangling stripped)` |
| 10 | P | profile-switch resume |
| 11 | S | `RunSuspended` |
| 12 | PK | `ParkEntered` |
| 13 | WK | `WakeReceived` |
| 14 | AX | assistant with odd content and an image: `"`, `\`, `\n\t\r`, NUL, U+0001/001F/007F, é, emoji, U+2028/2029, BOM, `</script>` |

Constraints keep sequences to what a run emits:
- no new assistant turn while calls are open;
- HR only right after HP (a checkpoint may sit between them, as `TakeCheckpoint` keeps the pending batch);
- K and F only with no open call;
- nothing between a park and its wake.

Each case starts with a fresh session: `SessionStart`, then `HistorySeeded([system, user])`.

### P3.1: host vs twin (`run_p31.sh` = `p31_twin.ail` → `p31_host.ts` → `p31_fold.ail` → `p31_compare.awk`)

For each action sequence:
1. The wire events go to the REAL `SessionJournal.record`, in three host lifecycles:
   - `one`: one process;
   - `crash`: a new `SessionJournal` adopting the file at every `session_resumed`, as `--resume` does;
   - `restart`: `writeExit("restart")`, then a new adopting `SessionJournal`.
2. The same events, as `LedgerRecord`s, go to the REAL `journal_lines_of_records`.
3. Both journals go to the REAL `parse_journal_text`/`fold_journal`; the host's journal is folded at its `currentLeaf`.

P3.1 as executed: either both refuse with the same refusal id, or both accept with equal
`history` (compared as the canonical JSON of the `[Message]`) and equal `dangling` (ids and
count).

| run | sequences | host journals | P3.1 disagreements | X-1 |
|---|---|---|---|---|
| every sequence of length 0–3, actions 0–13, lifecycles one/crash/restart | 2,955 | 8,865 | 18: per lifecycle 5 of the `[6,9,0]` class (A2-T3-1) + 1 of the `[4,5,9]` class (A2-T3-2) | 93 (31 per lifecycle) |
| the same, both one-line fixes applied | 2,955 | 8,865 | **0** | **0** |
| every sequence of length 0–4, actions 0–13, crash lifecycle | 41,371 | 41,371 | 250: 210 twin `digest` / host accept, 35 both accept with different `dangling`, 5 host `digest` / twin accept. By pattern, 190 have a checkpoint followed later by a resume and 60 contain a hybrid replacement; none fits neither | 673 |
| the same, both fixes applied | 41,371 | 41,371 | **0** | **0** |
| random (seed 1): 1,500 sequences of length 5–9, actions 0–13, crash | 1,500 | 1,500 | 36 (29 / 5 / 2 of the same three shapes) | 51 |
| the same sample, both fixes applied | 1,500 | 1,500 | **0** | **0** |
| random (seed 2): 2,000 sequences of length 8–16, actions 0–14, crash + restart, both fixes applied | 2,000 | 4,000 | **0** | **0** |
| odd-content codec sequences | 4 | 12 | 3, all A2-T3-1's `[14,6,9,0]` | 0 |
| crafted `first_kept` (X-2) | 2 | 2 | 2 (A2-T3-5) | – |

### P3.2: twin round trip (`run_p32.sh` = `p32.ail`)

`fold_journal(journal_lines_of_records(h, rs), journal_leaf(..))` is run over single-run
traces `rs`, and compared with an executable statement of rule 3 (`journal.ail:1266-1270`)
computed from `rs` alone:
- the seed, then one message per appended entry;
- `replaces_previous` takes the place of the message before it;
- from the latest `history_replaced`: the head system prefix (for `checkpoint`), that entry's
  messages, `first_kept`'s tail, then later entries.

Rule 4 is then applied: the trailing assistant's unanswered calls are removed and become
`dangling`. The fold must accept, and its `history` and `dangling` must equal the statement's.

Starts:
- 0: fresh `[system, user]`;
- 1: a longer seed with a completed tool exchange (follow-up or resumed run);
- 2: `SessionStart`, `HistoryAppended(wake)`, `HistorySeeded(plan ++ [wake])`;
- 3: a bare seed with no `SessionStart`;
- 4: the whole trace `run_v2_session_park_resumed_traced` returns.

Run actions are 0–7, 11–15 (15 = `RunSummary`), and every sequence up to the length shown is
enumerated.

| starts | max length | runs | FAIL |
|---|---|---|---|
| 0, 1, 2, 3 | 1 | 56 | 14, all start 2 (A2-T3-4) |
| 0, 1, 3 | 2 | 549 | 0 |
| 0, 1, 3 | 3 | 7,140 | 0 |
| 0 | 4 | 30,941 | 0 |
| 1 | 4 | 30,941 | 0 |
| 3 | 4 | 30,941 | 0 |
| 4 | 1 | 14 | 14, every one `digest` at entry 5 (A2-T3-4) |

### Other executed checks

- **Codec on the host path**: action 14 (odd content, NUL in an image `source`) survives AILANG
  encode → TS `JSON.parse`/`JSON.stringify` → AILANG decode → re-digest, in all three lifecycles
  (`[[14],[14,1,3],[1,3,14,9,0],[14,6,9,0]]`). The only disagreement was A2-T3-1's
  `[14,6,9,0]`. Action 14 is also in the seed-2 random alphabet (`rand_seqs.ts 2000 8 16 2 15`),
  which shows 0 disagreements on the fixed code.
- **Crafted `first_kept`** (`p31_crafted.ail`): 2 cases, both disagree (A2-T3-5).
- **Torn tail + adopt** (`x3_torn.ts`, `run_x3.sh`): 1 case (A2-T3-6). It passes once the
  truncating fix is applied.

### What passed

Within the generator's domain, with A2-T3-1/2 fixed, the host and the twin agreed on every
sequence. Both folds agreed with the rule-3 statement for starts 0, 1 and 3. Covered: checkpoints
(also between a hybrid plain assistant and its replacement), dangling stripping with one or two
open calls, crash resumes with open calls (both arm `history_replaced(resume)`), profile
switches, follow-up turns, suspension, adjacent park/wake, and the odd-content codec.

## Limits

- The generator is the domain. Sequences outside it were not explored: H1/H2-violating
  messages, unanswered tool results, interleaved turns, a model change, a fresh `/restart` child seeding a
  new history into an already-seeded journal, non-`None` `first_kept` beyond X-2,
  multi-system-message heads beyond X-2, and seed messages that fail to decode.
- Two generator artifacts were found and removed rather than reported: an assistant appended
  while calls are open, and an event between a park and its wake. Both writers refuse those
  identically (or both host and twin refuse), so they could not have produced P3.1 reports.
- For P3.2 starts 2 and 4, a `HistoryAppended` precedes the seed, and P3.2's wording ("the
  seed, then one message per appended entry") does not settle where that message belongs. So
  A2-T3-4 is judged on acceptance alone (`T3_ACCEPT_ONLY=true`).
- Repro timings: `harness/check_repros.sh` runs every `repro` column command as written. Each
  exits 1 on the real code, in 0–8 s once `ailang` has run the same files before
  (`work/repro_check.log`). Cold runs on a machine loaded by other trials took 25–55 s. All are
  under 120 s.

## Running (all from the tree root)

AILANG resolves `src/core/...` imports only from inside the package. The runner scripts
therefore copy the `.ail` files into `scratchpad/<T3_DIR>/` in the tree, rewriting their
`scratchpad/t3/` imports. That is the only thing written under the tree. Everything else,
including scratch journals, goes to `../out/work/`.

```
bash ../out/harness/run_p31.sh 3 ../out/work/p31_3                  # P3.1, every sequence up to length 3
T3_MODES=crash bash ../out/harness/run_p31.sh 4 ../out/work/p31_4   # length 4, crash lifecycle
bash ../out/harness/run_p31.sh "$(bun ../out/harness/rand_seqs.ts 1500 5 9 1)" ../out/work/p31_rand1
bash ../out/harness/run_p32.sh 3 '[0,1,3]'                          # P3.2
bash ../out/harness/run_x3.sh ../out/work/x3                        # X-3
```

Environment knobs:
- `T3_DIR`: where the `.ail` copies go. Use a distinct one for concurrent runs.
- `T3_MODES`: which host lifecycles to run.
- `T3_STRICT_PENDING=1`: also fail on X-1.
- `T3_GEN=p31_crafted.ail`: run the X-2 cases.
- `T3_ACCEPT_ONLY=true`: judge P3.2 on acceptance alone.
- `T3_JOURNAL_AIL`, `T3_HOST_MODULE`: patched copies, for fix validation only.

Raw outputs of every run named above are under `out/work/`. The `*.log` files hold each
run's verdict lines. The per-case host journal directories (`j/`) of the large sweeps were
deleted to save space; their `twin.tsv`/`hostfold.tsv` verdicts are kept. Rerunning a sweep
regenerates them. The tree's `scratchpad/` was returned to its original contents
(`verify_guard.ail`); each runner re-creates its copies when it starts.

## Harness files (`out/harness/`)

| file | what it does |
|---|---|
| `t3gen.ail` | the shared generator: child state, action alphabet, real digests, real `to_schema_v1` wire form, twin fold and verdict printing |
| `p31_twin.ail` | P3.1 AILANG half: enumerates or takes explicit sequences, prints wire events (W) and the twin's fold (V) |
| `p31_host.ts` | P3.1 bun half: the real `SessionJournal` over the W events, in the three host lifecycles |
| `p31_fold.ail` | the real `parse_journal_text` + `fold_journal` over each host journal |
| `p31_compare.awk` | P3.1's executable statement (plus X-1) |
| `run_p31.sh` | runs the four stages above |
| `p31_crafted.ail` | X-2's hand-built wire sequences, for the same pipeline |
| `p32.ail`, `run_p32.sh` | P3.2: the twin's journal of single-run traces, folded, against the rule-3/rule-4 statement |
| `x3_torn.ts`, `run_x3.sh` | X-3: torn tail, adopt, one append, fold |
| `rand_seqs.ts` | seeded random action sequences |
| `check_repros.sh` | runs every `repro` command in `reports.tsv` and records exit codes and times |

The fix-validation copies (`out/work/fix/`) are evidence only. They are not part of any repro.
