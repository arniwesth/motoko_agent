# T3: the journal writer twin and the round trip (arm A, replicate 1)

**Target.** `SessionJournal`, the host's writer (`src/tui/src/session-journal.ts:139`).
`journal_lines_of_records`, its AILANG twin (`src/core/journal.ail:2137`). Both are judged
by `fold_journal` (`journal.ail:1677`).

**Method.** Only executed checks on the real code. Programs drive the real
TypeScript class and the real AILANG functions. There is no model of the writers or the fold;
the only model is of the child that emits the wire events (see Limits).
Everything is in `harness/`, and every report has a one-command repro (`harness/repro.sh`)
that runs from the tree root. Each repro takes 15–30 s.

## Results

| Report | Property | Defect | Reachable at HEAD |
|---|---|---|---|
| A1-T3-1 | P3.1 (and P3.2) | The twin never sets `replaced_since_seed`. After a checkpoint, a same-profile crash `--resume` is not re-based, so the twin's journal is refused with `digest` and the host's is accepted | **Yes**: checkpoint, `kill -9`, `--resume` |
| A1-T3-2 | P3.1 | The host's `replaceLastHistoryMessage` drops `updatePending`. A crash after a hybrid batch head leaves the host with no open calls, so the resume is not re-based and the host's journal is refused with `digest` where the twin's is accepted. `exit.pending_tool_calls` is wrong too | Only for hybrid-era journals (005 W3 removed `replaces_previous` emission) resumed at HEAD |
| A1-T3-3 | P3.1 | The host drops `""` call ids that the fold keeps dangling. After the non-empty call is answered, a resume splits the two writers: host `digest`, twin accepts | Not shown: needs a provider call with an empty id |
| A1-T3-4 | P3.1 | `first_kept = -1`: the host drops it as out of range, the twin copies it, and the fold keeps everything, so the twin's journal is refused with `head-prefix` | No: `first_kept` is always `None` at HEAD |
| A1-T3-5 | P3.1 | After a checkpoint, the host counts the history without the head system prefix. An in-range `first_kept` is then dropped by the host and kept by the twin, and the two histories differ | No: same reason |
| A1-T3-6 | P3.2 | A checkpoint followed by a follow-up turn: the operator's append is chained from the empty base. Both writers' journals are refused with `digest` | **Yes**, but the emitter documents it as a known limitation (`session.ail:4372-4386`). The cause is outside the target functions |
| A1-T3-7 | X-2 | `chain_digests_over(base, ms)` ignores `base` | Latent: every caller passes the empty base |

Negative controls (`harness/controls/`). With the twin fixed (`replaced_since_seed: true` in
its `HistoryReplaced` arm), A1-T3-1's witness passes P3.1 and P3.2. With the host fixed
(`this.updatePending(message)` restored), A1-T3-2's witness passes. Both controls use patched
copies loaded through `T3_JOURNAL_PATCHED` and `T3_HOST_MODULE`, and the tree is unchanged.
With both fixes applied, the full length-3 enumeration over 16 ops leaves no run-emittable
P3.1 violation. What remains is the `first_kept` shapes, one empty-id case, and A1-T3-6
(`L3A16_fixed` in the "Runs" table).

## The harness

Four stages, run by `harness/run_t3.sh`:

1. **`gen_twin.ail`** (AILANG) is a **child model** that emits the journal-class wire
   events a run emits, the way `session.ail` builds them:
   - the seed carries the prefix chain (`chain_digests_over`, `:3868`);
   - there is one `HistoryAppended` per message, chained with `chain_digest_after`. For
     `replaces_previous`, the chain starts from the entry *before* the replaced one
     (`c2_append_step`, `:839`);
   - the checkpoint is `HistoryReplaced(checkpoint, [summary], digest_messages(prefix ++
     summary))`, and the chain continues from it (`:3109`, `:3141`);
   - the follow-up turn is `run_summary`, then the user append chained from
     `c2_seed_digest(history)`, then `session_start` and the next run's seed (`:4350-4392`);
   - the crash resume is `SessionResumed`, then `HistorySeeded(folded history)`
     (`:4804-4810`), where the folded history is the **real `fold_journal`** of the twin's
     journal so far. After that come the resumed run's own `session_start` and seed.

   For every op sequence the generator prints the wire events (`to_schema_v1`, the real
   encoder). It also prints the real `fold_journal(journal_lines_of_records(header, rs),
   journal_leaf(..))`, the P3.2 spec history computed from the records, and the child
   model's own history.
2. **`host_write.ts`** (bun) feeds those wire events to the **real `SessionJournal`**:
   `writeHeader`, then `record(event)` per event. At every `session_resumed` it constructs a
   new instance on the same directory, because a `--resume` is a new host process and
   `adopt()`s the file (`T3_ADOPT=0` keeps a single instance; the key witnesses give the same
   verdicts either way). It prints the journal file the class wrote, its `currentLeaf` and
   its `pendingToolCalls`.
3. **`fold_host.ail`** runs the **real `fold_journal`** on the host's journal at the host's
   leaf.
4. **`compare.ts`** holds the executable statements:
   - **P3.1**: the two folds give the same refusal id, or both accept with equal `history`
     (compared as `encode(messages_json(..))`) and equal `dangling`, including its count.
   - **P3.2**: for every case marked run-emittable, the twin's fold accepts, and its `history`
     equals the spec history. The spec is rule 3 stated over the records: the seed; one
     message per append, where `replaces_previous` takes the previous message's place; and
     from the latest replacement, the head system prefix (for a checkpoint), then its messages,
     then the kept tail (`first_kept`), then later entries. A seed after `session_resumed` is
     the resumed history. Rule 4's strip of the trailing unanswered calls is applied after.
     The spec is also compared with the child model's history, and they never differed.
   - **X-1** (exploratory): when both accept with equal history and dangling, the rest of the
     state also agrees: `last` boundary, `world_ordinal`, `model` and `profile`.
   - **X-3** (exploratory): when the fold of the host's journal accepts, the host's
     `pendingToolCalls` (written as D1's `exit.pending_tool_calls`) equal that fold's
     `dangling`.

   **X-2** is `check_chain_digests.ail`: the last element of `chain_digests_over(base, ms)`
   equals `chain_digest_over(base, ms)`.

`ail_run.sh` copies a harness `.ail` into a transient `t3h_*` directory under the tree root,
because `ailang` resolves `src/core/...` and `pkg/...` imports only inside the package. It
removes the directory on exit. `repro.sh <witness>` runs one case.
`attribute.sh` sorts every listed violation into a reported root cause by the ops in its
case, and prints anything it cannot sort as UNATTRIBUTED.

### The alphabet (ops after a fixed prefix: `session_start`, seed `[system, user]`, `state_delta`)

| # | Op | Wire events |
|---|---|---|
| 0 | `A0` | append an assistant message with no calls |
| 1 | `A1` | append an assistant message with calls `[a]` |
| 2 | `A2` | append an assistant message with calls `[a, b]` |
| 3 | `TA` | append the tool result for `a` |
| 4 | `TB` | append the tool result for `b` |
| 5 | `U` | append a user message |
| 6 | `R1` | `replaces_previous`: an assistant with calls `[a]` (the hybrid batch head) |
| 7 | `CP` | checkpoint (`first_kept` absent), then `state_delta` |
| 8 | `FU` | follow-up turn |
| 9 | `RS` | crash, then `--resume` with the same profile |
| 10 | `PS` | crash, then `--resume` with a profile switch (prompt digest changes) |
| 11 | `SU` | `run_suspended`, then `run_summary` |
| 12 | `H1` | append an assistant message with calls `[a, ""]` |
| 13 | `SB` | `session_start` with no `run_id` (the startup banner) |
| 14 | `KN` | checkpoint with `first_kept = -1` |
| 15 | `KL` | checkpoint with `first_kept = len(history) - 1` |

**Run-emittable** means the sequence follows the grammar the loop obeys:
- a call batch is answered before anything else, unless a crash (`RS`/`PS`) cuts it;
- `R1` comes only straight after `A0`;
- `CP`, `FU`, `SU` and `SB` come only when no call is open;
- `H1`, `KN` and `KL` are outside the grammar (not shown reachable, or not emitted at HEAD).

`single_run` excludes `FU`, `RS`, `PS` and `SB`. Optional `T3_NSYS=2` seeds two system messages.

### Runs (all on the unchanged tree; output under `runs/`)

Each `runs/<name>.full.txt` lists every violating case by class, and `runs/<name>.txt` is the
summary. Stage outputs over 1 MB are gzipped (`gen.out.gz`, `host.out.gz`). `runs/w_*` and
`runs/c_*` are the single-case witnesses and the two negative controls.

| Run | Generator | Cases | P3.1 violations | P3.2 (run-emittable cases, violations) | X-1 | X-3 |
|---|---|---|---|---|---|---|
| `L3A16` | exhaustive, length 0–3, all 16 ops | 4,369 | 645 | 862, 28 | 126 (all contain `SB`) | 474 |
| `R7A13` | 3,000 random sequences of length 7 (LCG), ops 0–12 | 3,000 | 103 | 101, 17 | 0 | 104 |
| `L4A13` | exhaustive, length 0–4, ops 0–12 | 30,941 | 598 | 4,925, 365 | 0 | 1,975 |
| `L3A16_fixed` | as `L3A16`, with both writer fixes applied | 4,369 | 604: 603 `first_kept`, 1 empty id; none run-emittable | 862, 23 (all A1-T3-6) | 126 (all `SB`) | 253 (all `KN`/`KL` or `H1`) |
| witnesses | `T3_OPS` single cases (`repro.sh`), including `T3_NSYS=2` and the interactive start | 1 each | | | | |

Attribution (`attribute.sh`). In `L3A16`, the 645 P3.1 violations split as:
- 612 `first_kept` (A1-T3-4/5);
- 23 host replace (A1-T3-2);
- 7 twin `replaced_since_seed` (A1-T3-1);
- 3 empty id (A1-T3-3).

Its 28 P3.2 violations split as 23 follow-up after checkpoint (A1-T3-6) and 5 A1-T3-1.

In `R7A13`, the 103 P3.1 violations split as 41 empty id, 35 A1-T3-1 and 27 A1-T3-2. Its 17
P3.2 violations split as 10 A1-T3-6 and 7 A1-T3-1.

In `L4A13`, the 598 P3.1 violations split as 304 A1-T3-2, 196 A1-T3-1 and 98 empty id. Its
365 P3.2 violations split as 263 A1-T3-6 and 102 A1-T3-1. Among run-emittable cases, the
P3.1 splits are:
- 100 host-accept/twin-digest, all a checkpoint followed by a resume (A1-T3-1);
- 5 host-digest/twin-accept, all `A0,R1,RS,x` (A1-T3-2);
- 8 equal-verdict cases with a different `dangling`, all with `R1` (A1-T3-2).

All 69 run-emittable X-3 differences contain `R1`.

Nothing was unattributed in any run. **Single-run traces** (no follow-up or resume) gave **no P3.2
violation**. There, every accepted twin history equalled the rule-3 spec and the child
model's history.

## What was checked and not reported

- **The banner `session_start`** (X-1, every `SB` case). The twin writes a `run_started` with
  an empty `run_id`, and resets its `run_id`, for a `SessionStart` with no `run_id`. The host
  writes nothing (`session-journal.ts:509-510`). So `last` differs, for example
  `suspended(...)` against `open(run_started)`. Not reported: the banner is written by
  `rpc.ail:284` as raw JSON and is never a `LedgerRecord`, and every `SessionStart` the loop
  emits carries the run's id. The twin cannot be handed one.
- **The interactive start** (`session.ail:4660`, `task == ""`). The first turn would append
  the operator's message *before* the session's first seed. Both writers then refuse with
  `digest`, so P3.1 holds and P3.2 fails. Not reported: `rpc.ail`'s `await_first_task` skips
  empty content (`:266`), so `task == ""` cannot reach `run_v2_with_conversation` from the RPC
  entry. Run it with `T3_NSYS=-1 T3_OPS=0 bash ../out/harness/run_t3.sh`.
- **X-3, the host's pending set against the fold's `dangling`.** Every run-emittable
  difference is A1-T3-2's `R1`, already in that report's notes. Outside the grammar it is
  `H1`, plus `KL`/`KN`, where `recordReplaced` resets the open set (`:723`) while the kept
  tail still holds open calls. Not separately reported.
- **Duplicate results, results after a user message, and the tool-message-with-calls shape
  (H2).** The fold admits all three. They are the shapes `evidence/diff/README.md` already
  lists, and none is in this alphabet. By reading only, not executed: on H2 the host's open
  set is non-empty where the fold's `dangling` is empty, so the host arms a re-base the twin
  does not. Both seeds are the same history, though, so P3.1 should hold.

## Limits

- The child is a **model of the emitter**, written from `session.ail`, not the running child.
  The writers and the fold are real. Stage-1 events go through the real `to_schema_v1`, and
  the digests come from the real `chain_digest_after`, `chain_digests_over` and
  `digest_messages`. Resume seeds are the real fold's history of the twin's journal, which
  `plan_resume` would also edit, for example on a suspended boundary. That editing is not
  modelled.
- The host is driven only through `writeHeader`, `record` and construction (`adopt`).
  `completeHeader`, `writeExit`, `markUnresumable`'s sidecar, the TUI's routing in
  `index.ts`, `park`/`wake` and `model_change` are not exercised. The twin has no
  `model_change` event.
- The leaf is each writer's own: the host's `currentLeaf`, and `journal_leaf` for the twin.
  There are no branch operations.
- Sizes: exhaustive up to length 3 over 16 ops, up to length 4 over 13 ops, and random length
  7. Bugs needing longer or different interleavings, such as a second checkpoint with a kept
  tail holding duplicate call ids, which `strip_dangling` could over-strip, were not searched
  for.

## Running it

From the tree root (bun 1.4.4, ailang v0.54.14):

```
bash ../out/harness/repro.sh <witness>          # one report; exit 1 = defect present
T3_MAXLEN=3 T3_ALPHA=16 bash ../out/harness/run_t3.sh ../out/runs/x   # an enumeration
T3_MAXLEN=-1 T3_RANDOM=3000 T3_RLEN=7 T3_ALPHA=13 bash ../out/harness/run_t3.sh ../out/runs/y
```

`run_t3.sh` exits 1 on any violation. `T3_PROP=P3.1|P3.2|X-1|X-3` selects which property
the exit status reports. `T3_EXAMPLES` sets how many examples to list per class.
`bash ../out/harness/attribute.sh <compare output>` attributes violations to reports.
`probe.ail` was the first toolchain probe and is kept for the record.
