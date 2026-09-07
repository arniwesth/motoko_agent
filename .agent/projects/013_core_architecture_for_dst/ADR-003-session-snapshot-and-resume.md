# ADR-003: A session is a journal the host writes from the wire, and resume is a strict fold of it

Date: 2026-09-06 (v1 through v5), 2026-09-07 (v6, v6.1)
Status: **Proposed (v6.1 — journal-only; v6 folds the eight required changes of the v5 review;
v6.1 applies the v6 review's eight line edits, unreviewed. PLAN-003 v3 may be written against
this version).** v6 was reviewed by Claude Fable (`REVIEW-adr003-v6-verdicts-fable.md`, HEAD
`97827bf`): *accept with corrections; PLAN-003 v3 can be written after three items are settled
in a v6.1*; D5 and D7 accepted clean. v5
was reviewed by Claude Fable (`REVIEW-adr003-v5-verdicts-fable.md`, HEAD `97827bf`, also against
the oh-my-pi source): *accept the direction; return for a v6*; D5 and D7 accepted clean; all six
v4.1→v5 retractions judged factually right, one with a qualification that v6 folds. v1–v4
were reviewed by Claude Fable (`REVIEW-adr003-verdicts-fable.md`, `-v2-`, `-v3-`, `-v4-`, all at
HEAD `97827bf`); v4.1 was accepted as the version PLAN-003 could be written against, and PLAN-003
v2.1 was written and reviewed twice on that basis. v5 replaces the on-disk half of that design at
the owner's challenge — "why can't we just record all events and replay them" and "building both
a checkpoint and a journal seems unnecessarily complex" — after reading how oh-my-pi 18.1.11
resumes a session (`~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/src/session/`).
The in-memory half (the typed suspension and the in-process resume) is unchanged from v4.1 and
keeps its four reviews. Code coordinates are at HEAD `97827bf`.

---

## Version history and retractions

**v1 → v4.1** are recorded in the four reviews and were folded in order; the design they converged
on was a *checkpoint*: the child writes a `Snapshot` file through a ported atomic leaf at every
turn boundary, and a resumer decodes it strictly. That history is not repeated here.

**v4.1 → v5.** What v4.1 got wrong, in the order the owner found it:

1. *"The log Motoko writes cannot be replayed, so a checkpoint is needed."* True of the log as
   it is — provider calls are logged as digests (`session.ail:2773–2781`), compaction as a fact
   (`:350`), tool results capped for display (`phase_vocab.ail:866`) — and beside the point: the
   log can carry the exact deltas, and then the state is a **fold** over them, not a replay of
   the driver. Replay of the driver against its interaction log is what the DST harness does and
   is the wrong tool for resume (O2 below); a fold over history deltas needs no code re-execution
   and cannot diverge with a code change.
2. *"A journal beside the checkpoint would be a second mechanism."* Conceded. There is one
   mechanism in v5: the journal. The checkpoint, its ported writer (`file_replace`), its request
   class, its leaf module, the outer-backstop skip, the child-written `Restart` update, the
   `written` field and the child's side of the lease are **deleted**. What v4.1 priced as PLAN-003
   P2 does not exist.
3. *"The child writes on the witnessed path."* v4.1's writer was a helped leaf inside `c2_loop`,
   which under ADR-001 D2 advances the world ordinal and moves every frame gate. In v5 the
   **host** writes the journal from the wire it already receives, and the child performs no file
   IO at all. The ordinal gate is untouched.
4. *"Compaction rewrites history."* It does not, at HEAD: pre-step compaction builds a payload for
   one provider call (`session.ail:2741–2790`) and the retained history is never replaced by it;
   the only replacement of `st.msgs` is the checkpoint (`:2521`). v5's journal therefore appends
   history deltas and records a checkpoint as a **pointer entry** with its summary messages — the
   shape oh-my-pi's `CompactionEntry` has (`session-entries.ts:118–143`,
   `firstKeptEntryId`) — never a wholesale rewrite.
5. *"The returned trace is the wire."* It is not: 37 `ledger_emit` sites and 23 `WireRecord`
   appends in `session.ail`. The journal-class events v5 adds are defined as **appended and
   emitted**, with payload equality asserted, so the fold can be checked inside the harness
   over a run's own trace (D4). ADR-002 D2 already requires this of `ParkEntered` and
   `WakeReceived`.
6. *"Entries are a flat list."* oh-my-pi's entries carry `id` and `parentId` and the file is a
   tree with a leaf pointer (`session-manager.ts:246–341`); its turn recovery, checkpoint rewind
   and `/fork` are branches (`turn-recovery.ts:1103`, `:1144`, `:2749`; `agent-session.ts:8072`).
   v5 adopts the two fields and the leaf from the first line so that pointer-style checkpoints
   and later branching need no format migration; it schedules no branching feature.

**v5 → v6.** What v5 got wrong, in the order the review found it:

1. *"The fold emits the header's system prefix."* The header carries the prompt's digest, not the
   prompt, and the initial `[system, task]` is built in `rpc.run_with_config` (`rpc.ail:344–345`)
   and handed to the run as an argument; no append event ever saw it, so both the on-disk fold and
   the in-harness invariant started with no messages. v6: a `HistorySeeded` event at the traced
   entry, before `c2_loop` (`session.ail:3143`), carrying the run's starting history; the host
   journals it for a session's first run and drops it thereafter after checking its digest against
   the fold (D1, D2, D4).
2. *"Tool results are appended after a tool phase."* The tool-batch finish **rebuilds** the history
   from a pending prefix (`c2_pending_prefix`, `:2213–2215`; `:2251`), and on the hybrid-bash path
   that prefix ends with an *augmented* assistant message carrying the synthesized call
   (`:2998`) while the retained history holds the plain one (`:2989`). An append-only event would
   leave every hybrid run's fold with a plain assistant followed by a tool result, which the
   provider rejects and the digest chain exposes. v6: `history_appended` gains
   `replaces_previous: bool`, set on the hybrid batch's first entry; the corrected site table is
   in D2, including the DP7 sites (`:2356`, `:2381`) v5 missed and `:2907` relabelled as the
   intercept site.
3. *"`first_kept_id` addresses an entry."* A checkpoint's first kept message can sit inside a
   multi-message entry. v6: **one message per `history_appended` entry**, as oh-my-pi
   (`session-entries.ts:73–76`); a batch of N tool results is N consecutive entries; the id
   resolution is a lookup.
4. *"The invariant compares the fold with the run's final state."* `ExecutionUnderTest` holds
   the outcome, the trace and the world (`dst_invariants.ail:553–556`); `SystemRun` the outcome
   and trace (`dst_result.ail:93–98`); neither carries telemetry, artifacts or a suspended run's
   history. v6: `TracedSessionResult` gains `final: FinalState`, carried by `execution_of`
   (`dst_execution.ail:110–118`) into `ExecutionUnderTest`, and the seed of item 1 is the first
   journal-class record of every run's trace (D4).
5. *"`SessionLogger` carries the journal writer."* The logger is constructed per child spawn
   (`index.ts:903`) and closed at child exit; the journal's leaf, `seq` and handle must outlive a
   `restart` respawn. v6: a host-lifetime `SessionJournal` beside `sessionStartMs()`, handed to
   each logger (D3). And the "payload replaced by a digest in the log" rule is new code —
   the TUI logs unknown event types verbatim today (`runtime-process.unknown-events.test.ts`) —
   so it lands in the same commit as the events.
6. *"Counts are reconstructed from assistant appends."* Approximate (a retried stream error
   appends nothing, `:2849`; stage counts are not derivable). v6: `StateDelta` carries
   `cumulative` computed exactly as `runtime_status_json` does (`:559`); the fold reads the last
   delta (D4 rule 5).
7. *"PLAN-003 P1 is unchanged."* Four of its parts change by deletion (`written`, the snapshot
   types, the generation reset). Listed in D8.
8. Citations: emission parity is `parity_findings` (`dst_invariants.ail:946`), not the two-run
   determinism check at `:1742–1769`; `resume-command.ts` is under `src/utils/`.

**v6 → v6.1.** Eight line edits from the v6 review, one of them a choice:

1. *"`first_kept_index` is the tail the checkpoint keeps."* The checkpoint at HEAD keeps no
   tail: `checkpoint` rebuilds the history as the pinned system prefix plus one summary message
   (`phase_vocab.ail:263–281`, `:270`) and `apply_checkpoint` installs that whole
   (`:349–366`). `first_kept` is `Option[int]`, `None` at HEAD, kept for a tail-keeping
   checkpoint later (D1, D4 rule 3).
2. *"The host drops every later seed after a digest check."* After a profile switch the head
   prefix is replaced by design (D6 step 4), so the resumed child's seed legitimately differs.
   Third arm: after a `resumed` entry whose `prompt_digest_to` differs, the seed is journaled
   as a `history_replaced` carrying the new head and becomes the chain's new base. And the host
   compares the seed's child-computed `digest` with the last entry's child-computed
   `digest_after`; it computes no digest itself (D1, D6).
3. *Where the wire events land.* **Chosen:** P1 keeps PLAN-003 v2.1's fixture, asserting
   `suspended.history` directly; the fold assertion is P3's first red. P1 stays the reviewed
   in-memory half (D8). The "Not retracted" line below no longer says P1 is untouched.
4. `final` is set at all **seven** terminal arms — `c2_finalize`'s callers (`session.ail:2206`,
   `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`), all with `st` in scope — via a
   `c2_finalize` parameter, which is now the smaller edit; the bridge and one fixture literal
   (`scripts/dst/invariants_dst.ail:385`, `:1008`) gain the field (D4, D8).
5. `history_valid_transcript` does not enforce tool-call pairing (`phase_vocab.ail:106–112`); the
   reason for `replaces_previous` is the provider's rejection of an unpaired result and the
   digest chain, and the fold carries its own pairing check (D2, D4 rule 4).
6. The `exit` entry written from a process-exit hook is a **synchronous** append — an async
   write in an `exit` listener never runs, which is why the reporter's exit report is
   `spawnSync` (`herdr-agent-state.ts:346–351`) (D3).
7. `digest_after` is **incremental** — the digest of the previous entry's digest plus the
   canonical form of the new message — so the child does not serialise the whole history per
   append; the fold checks the same chain (D2, D4).
8. The invariant is not "red at HEAD": at HEAD it cannot compile. It is red from P1 Part 4,
   which lands `final`, until P3's events land (D4, handoff).

Not retracted, and unchanged from v4.1: the typed suspension captured at the `Fail` arm with the
additive `suspended` field (D2 here); the in-process resume with a fresh per-turn allowance,
reset totals and carried cumulative counts (D6 here); the strict-decode discipline, now applied
per entry (D4); the profile switch accepted and recorded; the host-owned lease as the
single-writer guarantee; the judging number and PLAN-003 P1, which writes nothing and keeps
its scope, with four parts changed by deletion (D8).

---

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | **The journal.** `.motoko/sessions/<session_id>/journal.jsonl`, one entry per line, every entry `{ id, parent_id, seq, type, … }`; the first entry a header carrying the boot inputs and compatibility digests; a leaf pointer the host holds. **One message per history entry.** Entry types: history seeded, history appended (with a replaces-previous flag), history replaced (checkpoint, as a pointer plus its new messages), state delta, run boundary, settings change, suspension, resume, park, wake, exit. Written **by the host**, never the child | 1–2 days, core (types, codec) + host (writer) |
| D2 | **Typed suspension, unchanged**, plus the journal-class wire events: `history_seeded` at the traced entry, `history_appended` at the eight sites where the retained history grows or its tail is replaced, `history_replaced` at the checkpoint, `state_delta` at every step end and at the checkpoint, all **appended and emitted** with payload parity. `run_suspended` replaces `error` on the budget path; herdr sees `blocked` | 3–4 days, core + host |
| D3 | **One writer, the host.** A host-lifetime `SessionJournal` assigns ids and holds the leaf across child respawns; each per-spawn logger routes journal-class events to it and digests their payloads into the JSONL log, in the same commit as the events. The lease is the host's alone; a hostless runtime has no journal, as it has no log today. Abort and restart are entries, not file rewrites | 1–2 days, host |
| D4 | **The fold.** A pure `fold_journal(entries, leaf) -> Result[SessionState, Refusal]` in core: walk leaf to root, strict-decode each entry, emit history from the seed through the latest checkpoint pointer, honouring replaces-previous, read counts from the last state delta, take the last settings; refuse on schema, digest, transcript shape; strip a trailing unpaired tool call. **The same fold over a run's own trace equals the run's `final` state**, a projection `TracedSessionResult` now returns and the harness carries — a DST invariant on every existing traced fixture | 2–3 days, core |
| D5 | **Identity.** `session_id` forwarded to the child; `resume_count` supplied by the host in the environment; `run_id = <session_id>.r<resume_count>.<run_ordinal>` threaded by the loop; refusals on schema, workdir, extension set and same-profile prompt mismatch; the profile switch accepted and recorded as an entry | 1 day, host + core |
| D6 | **Resume.** In-process: unchanged from v4.1. Cross-process: the child reads the journal, folds from the leaf, rebuilds the runtime and prompt from the header's task, compares the prompt digest, enters the loop suspended or between turns; `restart` respawns with `--resume`; a crash leaves the journal one entry short and the next resume strips the dangling tool call | 2–3 days, core + host |
| D7 | **Park, when ADR-002 D2 exists.** `ParkEntered` becomes a `park` entry with its open waits and request; a resolved wake is a `wake` entry whose parent is the park entry — no wake file, no generation counter; the resumer seeds the `wakes` cursor from it and `wake_read` consumes it exactly once. Unscheduled | 2–3 days after ADR-002 D2 |
| D8 | **Sequencing and plan impact.** PLAN-003 P1 kept, with four parts changed by deletion; P2 deleted; P3 becomes the journal writer, the fold, the invariant and `--resume`; P4 as D7. Format adopts `id`/`parent_id`/leaf now; branching, rewind and fork are additive later work | — |

The number this ADR is judged on is unchanged: after a run reaches its step budget, the
operator's next `continue` produces a first provider payload that contains the exhausted turn's
history, and the step count continues. v5 adds a second: **a run that dies at step N resumes
with N steps of history**, which the checkpoint design could not promise.

---

## Context / the question

**What is lost at HEAD** is as v4.1 stated and the reviews verified: the driver's `Fail` arm
passes totals and step index to `c2_fail` and not the messages (`session.ail:2437`,
`:2171–2185`); the two outer loops recurse with the pre-turn history (`:3421–3426`,
`:3606–3611`); every traced run derives its own session id and the child never receives one
(`:3137–3139`, `:1440–1447`; `runtime-process.ts:337–389`); `world_of_json` is total
(`ext_world.ail:543–553`). The typed suspension (D2) repairs the first two in memory; the rest
is what a durable session needs.

**What the wire carries, and what it does not.** Every ledger event is emitted as one JSON line
on the child's stdout and written by the host's `SessionLogger.log` as one JSONL line
(`session-logger.ts`, `log(event)`). Assistant text arrives as stream deltas
(`phase_vocab.ail:823`); native tool calls and results as batch events whose payload is a
summary (`:580`); totals as `TotalsUpdated`; a checkpoint as its two digests (`:586`); compaction
as a note (`:581`). What never reaches the wire is the exact `Message` values as they entered
`st.msgs` — the starting history handed to the run (`rpc.ail:344–345`; `session.ail:3143`), the
assistant appends (`:2944`, `:2989`, `:3025`, `:3057`), the DP7 appends (`:2356`, `:2381`), the
intercept-handled pair (`:2907`), the injected user message (`:2494`), the tool-batch finish that
**rebuilds** the history from a pending prefix (`:2213–2215`, `:2251`), and the operator's message
at `:3409` — the checkpoint's replacement history (`:2521`), and the per-step extension artifacts
and telemetry. Those are the deltas. Add them and the wire is a journal.

**What the harness can check.** A traced run returns its `trace` (`LedgerTrace`, records of
`WireRecord(event)`, decision and stage records, `phase_vocab.ail:602–606`) and its final state.
Events that are appended to the trace as well as emitted can be folded in-process and compared
with the state the loop actually reached. The trace does not hold every emitted event today (23
appends against 37 emits in `session.ail`), so v5's new events are defined as both, on the
precedent ADR-002 D2 sets for its park events; the emission-parity family that checks
append-against-emit is `parity_findings` (`dst_invariants.ail:946`). What the harness's
execution record holds is the outcome, the trace and the world (`ExecutionUnderTest`,
`dst_invariants.ail:553–556`; `SystemRun`, `dst_result.ail:93–98`), not the loop's final
telemetry, artifacts or a suspended run's history — so a fold needs a comparand the record does
not yet carry (D4).

**The precedent.** oh-my-pi 18.1.11 keeps one append-only JSONL per session; the first record
is a header with the session id and working directory; every later entry has `id`, `parentId`,
`timestamp`, `type` (`session-entries.ts:66–71`); `message` entries hold the full message
including tool results (`:73–76`); `compaction` entries hold a summary and `firstKeptEntryId`
(`:118–143`); `model_usage`, `model_change`, `mode_change` are entries; extensions persist state
as `custom` entries. Resume loads the file, rebuilds the id index, sets the leaf to the last
entry, walks leaf to root and emits the latest compaction's summary, then the kept messages from
`firstKeptEntryId`, then the rest (`session-context.ts:180–345`); usage is a sum over
`model_usage` entries (`session-manager.ts:326`). Each entry is written as it happens; a
postmortem hook records a `session_exit` entry with any pending tool calls and prints the resume
command (`agent-session.ts:1649–1658`; `exit-diagnostics.ts:272`); the fold strips dangling
tool calls so the provider never sees an unpaired call (`session-context.ts:501–507`). Its only
snapshot is in memory, for rolling back a session switch (`session-manager.ts:1303`). It has no
checkpoint file. Its writer is the process that owns the loop, which is the one place v5
differs, for the reason in retraction 3.

## Options considered

**O1 — Reconstruct from the JSONL log as it is.** Rejected: digests, notes and capped text
(retraction 1).

**O2 — Replay the driver against a recorded interaction log.** What the DST harness does
(`dst_program.ail:229–238`; `dst_replay.ail:793–833`). Rejected for resume: the recording
adapters are bound only in the harness (`ports.ail:2568–2570` overrides world-served defaults
with ambient ones in production); replay re-executes the driver, so any code, extension or
profile change between the run and the resume diverges silently; and it rebuilds from an
initial world, not the current one. Kept, unchanged, for reproduction.

**O3 — Checkpoint (v4.1).** A `Snapshot` file written by the child at boundaries through a
ported atomic leaf, decoded strictly by the resumer. Rejected in v5: it is a second mechanism
beside the log; its writer is a helped leaf on the witnessed path; it gives no mid-turn
durability; and it copies the whole history at every boundary. Its strict-decode, lease,
identity and in-process-resume decisions survive here.

**O4 — Journal written by the child.** oh-my-pi's shape. Rejected here only because the child's
per-step write would be a helped leaf under ADR-001 D2 and would move every frame gate; the
host already receives every event and already writes one file per session.

**O5 — Journal written by the host from the wire, entries with `id`/`parent_id`, fold in the
child.** Chosen.

**O6 — Flat entries versus a tree.** The tree costs two fields and a leaf pointer and makes a
checkpoint a pointer rather than a rewrite. Adopted as format; no branching feature scheduled.

## Decision

### D1 — The journal

**File.** `.motoko/sessions/<session_id>/journal.jsonl`, created `0700`, one JSON object per
line, append-only. The JSONL log under `.motoko/logfile/` is unchanged and keeps carrying
digests; the journal carries content, and nothing in it is copied to the log.

**Entry envelope.** `{ id: string, parent_id: string | null, seq: int, at_ms: int, type, … }`.
`id` is host-assigned (`<seq>` zero-padded is sufficient; opaque to the child); `parent_id` is
the leaf at the time of the append; `seq` is the file position, monotonic. The **leaf** is held
by the host in memory and is the last entry unless a branch operation moves it (none in v5);
the child treats the last entry on the active branch as the leaf.

**Entry types.**

| type | producer | payload |
|---|---|---|
| `header` | host, first line | `schema_version: 1`, `session_id`, `workdir`, `profile`, `ext_set_digest`, `model`, `system_prefix_digest`, `boot: { task, env_url, hybrid_tools, budget, step_budget, ohmy_pi, max_cost_millicents, cost_rates }` — the loop inputs v4.1's envelope enumerated (`session.ail:2407–2421`, `:3330–3345`) |
| `history_seeded` | child event, once per traced run | `run_id`, `messages: [Message]`, `digest` — the history the run starts from. Three arms in the host: for the **session's first run**, journaled as N `history_appended` entries; after a `resumed` entry whose `prompt_digest_to` differs from `prompt_digest_from` (a profile switch, D6 step 4), journaled as a `history_replaced` carrying the new head, which becomes the chain's new base; **otherwise** the host compares `digest` with the last history entry's `digest_after` — both child-computed, the host computes none — and drops the event, logging a mismatch and marking the session unresumable. It is in every run's trace, which is what seeds the invariant |
| `history_appended` | child event, **one message each** | `run_id`, `step`, `message: Message`, `replaces_previous: bool`, `digest_after` — a batch of N tool results is N consecutive events; `replaces_previous` is set on the first entry of a hybrid-bash batch, whose augmented assistant replaces the plain one the previous entry holds (`:2251`, `:2998`). `digest_after` is **incremental**: the digest of the previous entry's `digest_after` concatenated with the canonical form of this message (`canonical_messages_raw`, `phase_vocab.ail:237–245`), so an append costs one message's serialisation, not the history's |
| `history_replaced` | child event | `run_id`, `step`, `reason: checkpoint \| profile_switch`, `first_kept: Option[int]`, `messages: [Message]`, `digest_after` — the replacement's messages and, when a checkpoint keeps a tail, the pre-checkpoint history index of its first kept message, which the host resolves to an entry id as it appends (one message per entry makes it a lookup). **`None` at HEAD**: the checkpoint rebuilds the history as the pinned system prefix plus one summary message and keeps no tail (`phase_vocab.ail:263–281`, `:349–366`). The fold keeps the head system prefix, emits `messages`, then every history entry after this one, or from `first_kept` when it is `Some` |
| `state_delta` | child event | `run_id`, `step`, `cumulative: RuntimeStatusCounts` (exactly `runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace))`, `:559`), `telemetry`, `ext_artifacts_digest`, `ext_artifacts?: Json` (present only when the digest changed) — at every step end (`:2911`, `:2947–2948`, `:2992–2993`) and at the checkpoint arm (`:2524–2525`) |
| `run_started` / `run_finished` | child events (`SessionStart` / `RunSummary`, already on the wire) | `run_id`; on finish `cumulative: RuntimeStatusCounts`, `world_ordinal` (after PLAN-001 P2), `finish_reason` |
| `settings` | child events (`model_change` today; `SessionResumed.profile_to`) | `model?`, `profile?` |
| `suspended` | child event `run_suspended` | `run_id`, `reason: budget_exhausted`, `step` |
| `resumed` | child event `session_resumed` | `resume_count`, `from_id`, `from_ordinal`, `profile_from`, `profile_to`, `prompt_digest_from`, `prompt_digest_to`, `forced` |
| `park` / `wake` | child events (ADR-002 D2, D7 here) | open waits and the request; the wake input |
| `exit` | **host**, from its exit handler and the child-exit callback | `reason: abort \| exit \| restart \| child_exit \| host_exit`, `pending_tool_calls` — computed by the host with a TypeScript twin of the fold's trailing-pair rule over the entries it holds in memory (the rule is three lines: the last assistant's `tool_calls` minus the `tool_call_id`s of the entries after it) |

**Codec.** `[Message]` gains a JSON codec in core (new work: the ABI's `Msg` has no `images`,
`packages/motoko-ext-abi/types.ail:547`; `Message` does, `session.ail:3402–3408`), with a
round-trip test over every role and the tool-correlation fields. Each entry type has an encoder
used by the child to build the event and a strict decoder used by the fold. `RuntimeStatusCounts`
and its two helpers move from `session.ail:431–446`, `:545–553` to `phase_vocab.ail` so the leaf
module `snapshot.ail` (renamed `journal.ail`) can name them; `zero_totals` stays.

**What the journal never holds.** The live `Ports`, the trace and the emissions of a run — a
resumed run opens its own frame. Per-run `totals` — they are per run (`:712`, `step_machine.ail:104`)
and appear in `run_finished` for the record only.

### D2 — Typed suspension, unchanged; the journal-class events

The suspension is v4.1 D2 items 1–4 verbatim: `StepBudgetExhausted` as its own code
(`step_machine.ail:93–103`; `session.ail:2164–2169`; the catalogue constant and its test deleted,
`dst_fault_catalogue.ail:210`, `:825–829`); `TracedSessionResult` gains `suspended:
Option[Continuation]` (the in-memory continuation, v4.1's `ContinuationSnapshot` minus the
on-disk fields; `None` in the literal at `:1554`); the `Fail` arm at `:2437` splits into
`c2_suspend`, which builds it from `st` (all in scope, `:2407–2437`), appends and emits
`RunSuspended`, and finalises with `TermMaxSteps` and `result: Err`, so `outcome_agreement`
holds (`dst_invariants.ail:1385–1388`); the outer loops check `suspended` first and emit no
`ErrorEvent` when it is `Some`, except in headless until the loggers switch (`:3421–3425`,
`:3606–3610`; `index.ts:517–519`, `:572–575`). The `written` field of v4.1 is gone.

**The journal-class events**, new `LedgerEvent` variants with vocabulary rows and goldens
(`make event_vocabulary`, `phase_vocab.ail:1221–1229`), each **appended to the trace and
emitted**, with payload equality asserted in the emission-parity family (`parity_findings`,
`dst_invariants.ail:946`, which today compares presence, not payload):

- `HistorySeeded` once per traced run, at the traced entry before `c2_loop` (`:3143`), with the
  run's starting history. A fresh session's is `[system, task]` (`rpc.ail:344–345`); a
  follow-up turn's is the loop's history; a resumed run's is the folded history. It is the first
  journal-class record in every run's trace.
- `HistoryAppended`, **one message per event**, at every site where `st.msgs` grows or its tail
  is replaced. The sites, every `msgs:` in a `C2LoopState` literal that is not `st.msgs`:

  | site | what enters | events |
  |---|---|---|
  | `:2944`, `:2989`, `:3025`, `:3057` | the assistant message after a model call | one |
  | `:2356`, `:2381` (via `c2_after_dp7`, called at `:3020`, `:3080`) | the assistant message on the DP7 paths | one |
  | `:2907` | the intercept-handled assistant and its tool message | two |
  | `:2494` | the injected user message | one |
  | `:2251` | the tool-batch finish: `c2_pending_prefix(st) ++ tool_msgs` (`:2213–2215`) | one per tool result; on the hybrid path the first carries the augmented assistant (`:2998`) with `replaces_previous: true`, then one per result |
  | `:3409` | the operator's message, emitted by the conversation loop | one |

  `:2298`, `:2675`, `:2849` carry `st.msgs` unchanged and emit nothing. Each event carries
  `digest_after`, the incremental chain digest (D1), computed by the child; at `:2251` the
  hybrid batch's first event chains from the entry *before* the replaced one, which is what pins
  the replacement — a fold that appended instead breaks the chain at that entry.
- `HistoryReplaced` at the checkpoint (`:2521`), carrying the summary message
  `checkpoint` produced (`phase_vocab.ail:263–281`) and `first_kept: None`, because
  `apply_checkpoint` keeps no tail at HEAD (`:349–366`; `session.ail:2517–2521`). The field
  exists for a checkpoint that later keeps one.
- `StateDelta` at the end of every step and at the checkpoint arm, with `cumulative`,
  telemetry and the artifacts digest; artifacts inline only on change.
- `RunSummary` gains `cumulative` and, after P2, `world_ordinal`; `SessionStart` gains `run_id`.
  Both goldens move (`phase_vocab.ail:593`, `:791`).

The wire change to the host is v4.1's: `AgentEvent` (`runtime-process.ts:58–103`) gains the
new variants; `run_suspended` replaces `error` on the budget path for the seven consumers
(`index.ts:517–519`, `:572–575`, `:877–882`, `:918`; `ui.ts:2752–2761`, `:2282`;
`session-logger.ts:343–346`); `MotokoRunState`, `RunState` and `TranscriptState` gain
`suspended`; herdr sees `blocked` with a message (`herdr-agent-state.ts:63`, `:73–74`,
`:81–91`).

### D3 — One writer: the host

**A host-lifetime `SessionJournal`.** `SessionLogger` is constructed per child spawn
(`index.ts:903`) and closed at child exit, so it cannot own the journal: a `SessionJournal`
object created once per session beside `sessionStartMs()` (`session-identity.ts`) holds the file
handle, the leaf and the `seq` counter across every respawn, and each logger is handed it.
`log(event)` routes: journal-class events (`history_seeded`, `history_appended`,
`history_replaced`, `state_delta`, `session_start`, `run_summary`, `model_change`,
`run_suspended`, `session_resumed`, `park_entered`, `wake_received`) become entries with fresh
`id`, `parent_id = leaf`, `seq`, and go to the journal; every event goes to the JSONL log as
today, journal-class ones **with their payload replaced by a digest**. That rule is new code:
`parseAgentEventLine` accepts any object with a string `type` (`runtime-process.ts:105–117`) and
the logger writes unknown types verbatim (`runtime-process.unknown-events.test.ts`), so the
events and the digest rule land in **one commit**, or the JSONL doubles in content. The header
is written before the first spawn from the values the host already has (`buildSupervisorArgs`,
`runtime-process.ts:482–505`; the profile and workdir it resolves) plus the system-prefix digest
and extension-set digest the child reports in `session_start`, which means the header is
completed by the host on the first `session_start` and rewritten in place — the **only**
in-place write the design admits, done atomically with Node's rename. A journal whose header
was never completed (the child died before `session_start`) has no history and is refused by
the fold with `Refusal::Header`; there is nothing to resume.

**Exit entries.** The host's exit handler (`index.ts:922–985`) and its process-exit hooks write
an `exit` entry naming the reason; `abort` and `restart` are the same entry with their reason,
which replaces v4.1's two metadata-update rewrites. The one written from a `process.on("exit")`
listener is a **synchronous** append (`fs.appendFileSync`): an async write started inside an
`exit` listener never runs, which is why the reporter's own exit report is `spawnSync`
(`herdr-agent-state.ts:346–351`). Pending tool calls at exit are computed by
the host from the journal (the fold's dangling-call rule, D4) and recorded, as oh-my-pi's
`session_exit` does.

**The lease** is v4.1 D5's, host-only: `.motoko/sessions/<id>/lease` with `owner_pid`, written
with an atomic rename, released in the host's own unconditional `exit`/`SIGINT`/`SIGTERM`
listeners registered between `initExitActions()` and `initHerdrReporter()`
(`index.ts:825–827`; `exit-actions.ts:422–428`) and not re-raising. A resume that finds a live
owner is refused. **Hostless runs** (`rpc.main` directly, `rpc.ail:355–359`; the eval harness;
the PLAN-003 probe) have no journal, exactly as they have no log today; the child never takes a
lease and never writes.

**Durability.** Each entry is written as it arrives, so a child crash loses at most the entry
in flight; a host crash loses what its stream had not flushed, bounded by the same `close()`
drain the log already has (`index.ts:922–926`). No `fs_atomic.ail`, no `file_replace`, no
`FileReplace` class, no scanner change, no outer-backstop change, no child-written `Restart`.

### D4 — The fold, and the invariant that checks it

```
fold_journal(entries: [JournalEntry], leaf: string) -> Result[SessionState, Refusal]
SessionState = {
  header: Header,
  history: [Message],
  cumulative: RuntimeStatusCounts,
  telemetry, ext_artifacts: Json,
  model: string, profile: string,
  last: Boundary            -- RunFinished(run_id, world_ordinal) | Suspended(run_id, step) | Parked(...) | Exit(reason)
}
```

Rules, in the order oh-my-pi's `buildSessionContext` applies them:

1. **Path.** From `leaf` to the root by `parent_id`, stopping at the first repeated id; reversed.
   The first entry must be the `header` (`Refusal::Header`).
2. **Strict decode** of every entry on the path; any missing or malformed field is
   `Refusal::Entry(seq, field)`. No fallbacks. The extension token's total `world_of_json` is
   untouched; the journal does not carry a `WorldState`, only `world_ordinal`.
3. **History.** The history entries on the path are the seed's N entries followed by every
   `history_appended`, one message each, in path order; an entry with `replaces_previous` drops
   the message the previous history entry contributed before contributing its own. Find the
   latest `history_replaced` on the path: emit the head system prefix (the seed's leading system
   messages, `take_system_prefix`, `phase_vocab.ail:85–90`), then that entry's `messages`, then
   every history entry **after it**, or from `first_kept` when that is `Some`. Without a
   replacement, every history entry. Each entry's `digest_after` must equal the chain digest
   recomputed through it (`Refusal::Digest(seq)`); the result must satisfy
   `system_is_head_prefix` and `history_valid_transcript` (`:40`, `:71–73`) — which check the
   head and the well-formedness of each message, **not** tool-call pairing (`:106–112`) — and
   the fold's own **pairing check**: every tool result on the path must answer a call in the
   assistant message before it, and every assistant call except a trailing one must be
   answered (`Refusal::Pairing(seq)`). In the harness the `ToolPairing` family
   (`dst_invariants.ail:1131`) is the same rule over the trace.
4. **Dangling tool calls.** If the emitted history ends with an assistant message whose tool
   calls have no matching results, drop those calls from the message and record them in
   `SessionState.dangling` for the TUI — the provider must never see an unpaired call, and a
   crash mid tool-phase is exactly this shape: the assistant with its `tool_calls` is journaled
   at `:2944` before the tool phase runs. On the hybrid path the journaled assistant carries no
   calls until `:2251` replaces it, so a crash there strips nothing, correctly. v6 strips from
   the **trailing** assistant only; oh-my-pi strips from any assistant on the path
   (`session-context.ts:501–507`) because a branch point can strand a middle turn's results,
   and the rule widens to that when branching lands.
5. **Counts and settings.** `cumulative`, `telemetry` and `ext_artifacts` from the last
   `state_delta` on the path — no reconstruction; `model` and `profile` from the last
   `settings` after the header.
6. **Boundary.** The last entry's type decides how the loop re-enters (D6).

**The comparand.** `TracedSessionResult` gains `final: FinalState = { history: [Message],
cumulative: RuntimeStatusCounts, telemetry, ext_artifacts: Json }`, set at **all seven**
terminal arms — `c2_finalize`'s callers at `session.ail:2206` (via `c2_fail`, whose one
caller at `:2437` hands it `st`), `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`, each
with `st` in scope — through a new `final` parameter on `c2_finalize`, which the literal at
`:1554` copies; with seven arms the parameter is the smaller edit, and it stays inside the band
P1 Part 4 already moves. `execution_of` (`dst_execution.ail:110–118`) carries it into
`ExecutionUnderTest` (`dst_invariants.ail:553–556`) as `final`; the one fixture literal and one
record update that build that type (`scripts/dst/invariants_dst.ail:385`, `:1008`) gain the
field. The bridge's `SystemRun` (`dst_result.ail:93–98`) is unchanged.

**The invariant.** In core, `JournalFold` joins `InvariantFamily` (`dst_invariants.ail:205–216`,
`all_families()`, `family_id`, `violation_family`) with `journal_fold_findings(x:
ExecutionUnderTest)`: take the `WireRecord`s of journal-class events from the trace, the
`HistorySeeded` first, assign sequential ids and parents as the host would, fold, and compare
with `x.final` field by field. It runs on **every existing traced fixture**, because every
fixture returns a trace and now a `final`. This is the check the checkpoint design could only
get from a round-trip fixture of its own. At HEAD it cannot compile — neither `final` nor any
journal-class variant exists; it is **red from PLAN-003 P1 Part 4**, which lands `final`,
**until P3's events land**, because a fold over no journal-class records yields an empty
history against a non-empty `final.history`.

**Digest chain.** Each history entry carries `digest_after`, the incremental chain digest of
D1: `sha256(previous digest_after ++ canonical(message))`, with the seed's `digest` as the
base and a `history_replaced`'s `digest_after` as a new base. The child computes one message's
canonical form per append (`canonical_messages_raw`, `phase_vocab.ail:237–245`), never the
whole history; the fold recomputes the same chain. That is the checkpoint-chain continuity v4.1
left undecided, achieved without `history_from_resume`'s whole-history rule (`:42–47`), and it
is what makes the `:2251` replacement unfakeable: the hybrid batch's first entry chains from
the entry before the replaced one, so a fold that appended instead breaks the chain there.

### D5 — Identity

- **`session_id`** is minted by the host once per session and forwarded as `MOTOKO_SESSION_ID`
  (`buildChildEnv`, `runtime-process.ts:337–389`), so `derive_session_id` returns it at both sites
  (`session.ail:1441–1442`, `:3137–3139`, `:3586`) — v4.1's repair of the issue's two ids.
- **`resume_count`** is the host's: `0` for a fresh session, incremented on every `--resume`
  spawn, forwarded as `MOTOKO_RESUME_COUNT`. It replaces v4.1's `generation`, which counted
  snapshot writes that no longer exist.
- **`run_id = <session_id>.r<resume_count>.<run_ordinal>`**, where `run_ordinal` is a
  conversation-loop parameter incremented per traced run in this process (v4.1's `written`
  reset rule is gone: no write, no reset). The traced run receives its `RunIdentity {
  session_id, run_id, profile }` as an argument; the exported entries build a default (`r0.0`,
  profile `""`) and keep their signatures (PLAN-003 §0.7).
- **Compatibility**, checked by the fold against the header and the invoked runtime: schema
  version (refused), canonical workdir (refused), extension-set digest under the same profile
  (refused; `--resume-force` overrides), system-prefix digest under the same profile (refused;
  `--resume-force` overrides), **profile switch accepted** and written as a `settings` entry
  with the head system prefix replaced and `ext_artifacts` reset, model difference accepted as a
  `settings` entry. `ext_set_digest` comes from the extension registry, not from the
  `session_start` names (`rpc.ail:260`).
- **`SessionResumed`** is emitted first by the resumed child and becomes the `resumed` entry.
  `from_ordinal` is the last `run_finished.world_ordinal`, which is taken from the world
  `c2_finalize` returns **after** its clock read (`session.ail:1550–1554`) — that is, the
  previous frame's `final` itself. The resumed frame opens exactly there; there is no `+1` or
  `+2` to pin, and the resume fixture asserts `END₁.final == BEGIN₂.ordinal₀`.

### D6 — Resume

**In-process** is v4.1 D6 unchanged: after `c2_suspend` the conversation loop holds
`suspended: Some(continuation)`; the next `user_message` appends the operator's message
(`HistoryAppended`), runs `c2_state_from_continuation` with `step_idx 0`, `totals` zero,
`prior_counts = cumulative`, telemetry and artifacts carried, pending fields empty; `model_change`
while suspended rewrites the held continuation's model and is a `settings` entry.

**Cross-process.** `InvocationConfig` (`config.ail:133–138`) gains `resume: string` (the journal
path) and `resume_force: bool` (a bare-flag arm beside `--no-backend`, `:235`; the `flag ::
value` arm would otherwise eat the task, `:236–239`); `buildSupervisorArgs` emits both. The
order in `run_with_config` (`rpc.ail:241–262`, `:296–345`):

1. Host: acquire or refuse the lease; increment `resume_count`; spawn with `--resume`.
2. Child: read the journal with the ambient `readFile` — the same pre-driver read the system
   prompt file uses (`rpc.ail:266–267`), outside the traced surface and therefore not a helped
   leaf and not scanned (`derive.py:144–149` lists no `rpc.ail`) — and `fold_journal` from the
   leaf; refuse on `Refusal`.
3. Build the extension runtime for the invoked profile (`rpc.ail:241–247`); compute
   `ext_set_digest`; apply the compatibility rows.
4. `compute_budget_plan` and `dispatch_build_system_prompt` from **`header.boot.task`** (`:319`,
   `:342`); compare `system_prefix_digest_for([system_msg])` (`phase_vocab.ail:253–255`) with
   the header's; on a profile switch replace the whole head prefix (`take_system_prefix`,
   `:85–90`) with the one new message and reset `ext_artifacts` — and the resumed run's
   `HistorySeeded` then carries that new head, which the host journals as a `history_replaced`
   because the `resumed` entry it follows records a changed prompt digest (D1). `run_model` is
   `--model` else the folded `model`.
5. Emit `SessionResumed`; enter the conversation loop: `last = Suspended` → `suspended:
   Some(continuation from the folded state)`; `last = RunFinished | Exit` → between turns with
   the folded history; `last = Parked` → D7. Wait for input as the empty-task path does
   (`session.ail:3597–3598`); `await_first_task` is bypassed.

**Restart** (`session.ail:3391–3399`) emits `SessionSuspend` as today, the host writes an
`exit(restart)` entry, and the respawn passes `--resume` with the new profile
(`index.ts:931–934`, `:951`). **A crash** at any step leaves the journal ending in the last
entry the host flushed; the next `--resume` folds it, strips a dangling tool call if the crash
was mid tool-phase, and enters between turns with the step count carried — the second judging
number.

**The TUI** shows the folded history with a marker line naming `resume_count`, the reason of
the last boundary, and both profiles on a switch; on a crash resume it names the dangling calls.

### D7 — Park, on the journal

When ADR-002 D2 exists: `ParkEntered` is appended and emitted (as ADR-002 requires) and becomes a
`park` entry carrying `open_waits` and the `ParkRequest`; a wake delivered while the runtime is
alive is consumed by `wake_read` as ADR-002 says and recorded as a `wake` entry — the host gets
it from ADR-002's `WakeReceived`, which that ADR already requires to be appended and emitted
(`ADR-002:279–281`); D7's are the only entries whose producer is an ADR-002 event. Under
`--park-exits` the host's suspended-child state owns the request (v4.1 D7, unchanged) and, on
the answer, writes the `wake` entry **as a child of the `park` entry**, then respawns with
`--resume`. The fold's `last = Parked(request, wake?)`: with a `wake` child, the resumer seeds
`WorldState.wakes` with it, its `request_id` rewritten to the re-issued request
(`run_id + park ordinal 0`), and the first `decide` parks and `wake_read` serves it from the
cursor — exactly once, because a consumed wake is followed by a `run_started` entry and the
fold will not offer it again; without a `wake` child, the resumer re-observes (ADR-002 D2's
initial read) and a gone pane wakes `Lost`. No wake file, no `WakeGeneration`. The states,
their `Lost`/`Aborted` exits, and the live and recording `wake_read` bindings are v4.1's.

### D8 — Sequencing and plan impact

1. **PLAN-003 P1, kept, four parts changed by deletion** (core + host): the typed suspension,
   the `[Message]` codec, the in-process resume, the `run_suspended` UI case. The deltas against
   PLAN-003 v2.1: Part 1's fixture no longer asserts `written`; it asserts `suspended` is
   `Some` with the eight-message history **directly**, and `RunSuspended` before `RunSummary`
   — the fold assertion is **P3's** first red, since the seed and append events are P3's, and
   P1 stays the reviewed in-memory half. Part 3's module is `journal.ail`, keeps
   `Continuation`, `RunIdentity` and the `[Message]` codec, and drops `Snapshot`,
   `SnapshotWritten` and every world-decoding path; the entry codecs move to P3. Part 4 adds
   `suspended` and `final`, not `written`, and `final` goes in as a **`c2_finalize` parameter**
   set at all seven callers (v2.1's record-update choice was for two sites; with seven the
   parameter is smaller); `RunSuspended` carries no `generation` or `published`. Part 5's loop
   rule is "increment `run_ordinal` per traced run",
   with `resume_count` from the environment; `generation` leaves the loop's parameters. Part 6
   is unchanged. Its acceptance test is the judging number.
2. **P2 is deleted.** Nothing in v5 waits for PLAN-001 P2 except `world_ordinal` in
   `run_finished`, which is one field added when P2's `ordinal` exists; the fold ignores it
   until then.
3. **P3, reshaped** (core + host): D1's entry types and codecs; D2's `HistorySeeded`, the
   corrected site list with `replaces_previous`, `StateDelta` with `cumulative`, all with
   append-and-emit parity; D4's `final` projection through `execution_of`, the fold with
   `first_kept_id` resolution and the trailing-pair rule, and `journal_fold_findings` on every
   traced fixture; D3's `SessionJournal`, the digest rule in the same commit as the events, the
   header, the exit entry and the lease; D5's ids; D6's `--resume`. Gate: the invariant
   green on the whole `make dst` sweep; a resume across a TUI respawn; a restart into a second
   profile; **a kill -9 of the child mid tool-phase followed by a resume that shows the dangling
   call stripped and the step count carried**.
4. **P4 = D7**, unscheduled until ADR-002 D2 activates.

**Format now, features later.** `id`, `parent_id` and the leaf are in the schema from the first
entry. Branching from an earlier entry, rewinding a bad checkpoint, `/fork`, and sibling
branches for retried turns are additive: each is a host operation that moves the leaf, and the
fold already reads one path. None is scheduled.

## Consequences

**Gates that move.** `step_machine.ail`'s `Fail` code and `decision_fail_reason` (as v4.1).
`TracedSessionResult` gains `suspended` and `final`; one literal changes; `execution_of` and
`ExecutionUnderTest` gain `final`. `LedgerEvent` gains `HistorySeeded`, `HistoryAppended`,
`HistoryReplaced`, `StateDelta`, `RunSuspended`, `SessionResumed`, with rows and goldens;
`RunSummary` and `SessionStart` gain fields, which moves their goldens (`phase_vocab.ail:593`,
`:791`) and the wire. `parity_findings` (`dst_invariants.ail:946`) gains payload assertions for
the journal-class events. A new invariant family, `JournalFold`, on every traced fixture. `AgentEvent`, three run-state enums, seven `error` consumers. `Ports` is
**untouched**; `derive.py` is untouched; no anchor moves for a writer, only for the D2 edits
PLAN-003 §0.2 already prices.

**What gets simpler.** The child does no file IO. There is no snapshot schema beside the wire
vocabulary; there is one fold and one invariant. Abort, restart, park and wake are entries.
Mid-turn crashes are recoverable. The DST "trajectory" and the journal share a shape: a path of
entries from a root.

**What does not.** Conversation content and tool output are now on disk under
`.motoko/sessions/`, `0700`, and the journal grows with the session (a checkpoint entry does
not shrink it; pruning is "Not decided"). `HistoryAppended` and `HistorySeeded` put full messages
on stdout; the host digests them into the log, but the pipe carries them, and the TUI's
`readline` over the child's stdout has no line cap (`runtime-process.ts:588`). The eval-harness
adapter reads the JSONL for `run_summary` (`env-server.ts:415–420`) and sees digests once the
D3 rule exists. Hostless runs remain undurable.

## Not decided

- **Journal pruning.** oh-my-pi keeps everything; a `history_replaced` makes earlier entries
  unreachable from the leaf but not deleted. Whether to compact the file is open.
- **Branching features.** Rewind to a checkpoint with a `branch_summary` entry, sibling branches
  for retried turns, `/fork`. Format-ready; unscheduled.
- **Cost and context exhaustion as suspensions**, as before.
- **Hostless durability.** A child-written journal for `rpc.main` runs would reintroduce the
  witnessed-path write; not wanted now.
- **`--resume` of a headless one-shot**, as before.
- **Whether `state_delta` should carry artifacts inline at all**, or only their digest with the
  extension re-deriving them on resume, as oh-my-pi's `custom` entries let extensions do.

## Implementation handoff

PLAN-003 v3: delete P2, reshape P3 as D8 step 3, keep P1 and its §0 rules with the four deltas
D8 lists, and add the three live gates above. The fold's invariant is P3's first item, written
against the tree P1 leaves, where it compiles once `final` exists and is red on every fixture
until the events land.

## Cross-references

- v1–v4 reviews: `REVIEW-adr003-verdicts-fable.md`, `-v2-`, `-v3-`, `-v4-` — the in-memory
  half's provenance; `PLAN-003-implement-adr-003.md` v2.1 and its two reviews.
- `ADR-002-park-and-wake.md` v3 D2 (append-and-emit for park events), D6 (points here).
- `ADR-001-sequencing-the-dst-architecture-caps.md` D2 (why the child must not write).
- `REVIEW-adr003-v6-verdicts-fable.md` — the v6 review; overall items 1–3 the `first_kept`,
  profile-switch seed and P1-placement questions v6.1 settles, §3 the new-piece audit, §4 the
  invariant's compile-versus-red timing.
- `REVIEW-adr003-v5-verdicts-fable.md` — the v5 review; §2 D2 the true site table, §3 the fold
  audit, §4 the pointer resolution, §5 the ordinal-gate verification, §8 the oh-my-pi audit.
- oh-my-pi 18.1.11, `@oh-my-pi/pi-coding-agent/src/`: `session/session-entries.ts:66–76`,
  `:118–143`, `:232–262`; `session/session-manager.ts:246–341`, `:1176–1182`, `:1303`,
  `:1405–1484`, `:2658–2710`; `session/session-context.ts:180–345`, `:501–507`;
  `session/agent-session.ts:1649–1658`, `:2276–2300`; `session/exit-diagnostics.ts:272`;
  `session/turn-recovery.ts:1103`, `:1144`, `:2749`; `utils/resume-command.ts`.
- Code at `97827bf`: `session.ail:350`, `:431–446`, `:483–497`, `:545–553`, `:559`, `:712`,
  `:1441–1442`, `:1550–1554`, `:2164–2169`, `:2171–2185`, `:2213–2215`, `:2251`, `:2298`,
  `:2356`, `:2381`, `:2407–2437`, `:2494`, `:2517–2525`, `:2675`, `:2741–2790`, `:2773–2781`,
  `:2849`, `:2907`, `:2911`, `:2944`, `:2947–2948`, `:2981–2998`, `:2992–2993`, `:3020`,
  `:3025`, `:3057`, `:3080`, `:3137–3143`, `:3330–3345`, `:3391–3399`, `:3402–3408`, `:3409`,
  `:3421–3426`, `:3586`, `:3597–3598`, `:3606–3611`; `step_machine.ail:93–104`;
  `phase_vocab.ail:40`, `:42–47`, `:71–73`, `:85–90`, `:106–112`, `:237–245`, `:253–255`,
  `:263–281`, `:349–366`, `:580–598`, `:593`, `:602–606`, `:791`, `:823`, `:866`, `:1221–1229`;
  `ext_world.ail:543–553`; `ports.ail:32`, `:2568–2570`; `dst_fault_catalogue.ail:210`,
  `:825–829`; `dst_invariants.ail:205–216`, `:553–556`, `:946`, `:1131`, `:1385–1388`;
  `dst_result.ail:93–98`; `dst_execution.ail:110–118`; `scripts/dst/invariants_dst.ail:385`,
  `:1008`;
  `dst_program.ail:229–238`; `dst_replay.ail:793–833`; `config.ail:133–138`, `:235–239`;
  `rpc.ail:241–262`, `:260`, `:266–267`, `:296–345`, `:344–345`, `:355–359`;
  `tools/driver_leaf_inventory/derive.py:144–155`; `packages/motoko-ext-abi/types.ail:547`;
  `runtime-process.ts:58–103`, `:105–117`, `:337–389`, `:482–505`, `:588`;
  `runtime-process.unknown-events.test.ts`; `session-logger.ts:221–240`, `:343–346`;
  `session-identity.ts:37`; `env-server.ts:415–420`; `herdr-agent-state.ts:63`, `:73–74`,
  `:81–91`, `:346–351`; `exit-actions.ts:422–428`; `ui.ts:2282`, `:2752–2761`; `index.ts:517–519`,
  `:572–575`, `:825–827`, `:877–882`, `:903`, `:918`, `:922–985`, `:931–934`, `:951`.
