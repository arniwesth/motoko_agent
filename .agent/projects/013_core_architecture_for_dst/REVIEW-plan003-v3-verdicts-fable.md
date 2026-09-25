# PLAN-003 v3 adversarial review verdicts

Date: 2026-09-07
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; the plan grounds at it, `PLAN-003-implement-adr-003.md:10`)
Subject: `PLAN-003-implement-adr-003.md` v3, against `ADR-003-session-snapshot-and-resume.md` v6.1 (`:3–5`, `:107–137`)
Prior: `REVIEW-plan003-verdicts-fable.md`, `REVIEW-plan003-v2-verdicts-fable.md` (v2.1 was ready to start); `REVIEW-adr003-v5-` and `-v6-verdicts-fable.md`

Every new coordinate and claim was checked at this HEAD; the sweep's evidence in §5 was checked against the working tree. §9 is the audit.

## Overall verdict

**Accept with corrections. P1 can start after two line edits; P3 cannot start until its part order is repaired.** Fidelity to v6.1 is complete, the four P1 deletions are exactly D8's, and the second judging number is the right one. Four things are wrong in a way an implementer would hit:

1. **P3's "family red first" is impossible in the order written.** `journal_fold_findings` must name the journal-class variants to select them from the trace, but those variants are added in Part 1 (`PLAN-003:353–387`) and the family is Part 2 (`:395–429`), which claims to land "before Part 1's events" (`:421–422`). A family that references `HistorySeeded` cannot compile before the variant exists. The order that works is three commits: the variants with their rows and goldens and **no emits** (`make event_vocabulary` green, `parity_findings` untouched since nothing is emitted); then the fold and the family, red on every fixture; then the emits, green. Renumber P3 so Part 1 is the fold and family, and split the events into "vocabulary" and "emits".
2. **The wiring fixture's digest-chain gate can never pass as written.** Part 1's chain hashes `canonical_messages_raw([message])` (`:373–374`; `src/core/phase_vocab.ail:237–243`, raw content) against the previous digest, while the gate compares the last `digest_after` with `digest_messages(suspended.history)` (`:392–393`), which hashes `canonical_messages` over the *whole* list with each content itself digested (`:229–233`, `:245–247`). A per-message chain is not a whole-list hash, and the two canonical forms differ. The gate must recompute the same incremental chain over `suspended.history` and compare with the last `digest_after`; Open question 8 (`:601–605`) already knows the form is undecided, so decide it there.
3. **Reading `MOTOKO_RESUME_COUNT` through the port is a new helped leaf.** Part 5 puts it "through the port … beside the other `session_policy_init` reads" (`:280–282`; the reads at `src/core/session.ail:2041–2044`). Every `ports.env_get` is a helped `EnvRead` (`tools/driver_leaf_inventory/derive.py:95`), and the fixtures pin the exact key set those reads make: `env_reads_always()` (`scripts/dst/seeded_generator_dst.ail:415–421`) and `env_expectations()` (`scripts/dst/run_report_dst.ail:173–178`), plus `strict_replay_dst.ail:400`, `discovery_dst.ail:665`, `driver_plus_compose_dst.ail:990`. Adding a key re-pins five fixtures and, under PLAN-001 P2, advances the ordinal. Read it ambiently in `rpc.run_with_config` as `headless_mode()` does (`src/core/rpc.ail:189–192`) and pass it down; §0.8 then holds in spirit as well as letter.
4. **`journal.ail` imports functions `phase_vocab.ail` does not export.** Part 3 lists `digest_messages`, `canonical_messages_raw`, `system_is_head_prefix`, `take_system_prefix` (`:199–201`); at HEAD all four are private (`phase_vocab.ail:245`, `:237`, `:75`, `:85`), and `history_valid_transcript` (`:71`) takes the private `History` type (`:26`), reachable only through `history_from_seed` (`:28–31`). Export what the module needs, or route through `history_from_seed`.

| area | verdict | short reason |
|---|---|---|
| Fidelity (§1) | **accept** | D1–D8 each land once; the four P1 deletions match D8 step 1; nothing re-decided. |
| Sequencing (§2) | **accept with corrections** | Items 1 and 3; the PLAN-001 P2 dependency is one field; P3 Part 1's anchor move is priced right. |
| Gates (§3) | **accept with corrections** | Items 1–2; the P1 fixture, the resume script, the lease test and the crash gate are executable. |
| Events part (§4) | **accept with corrections** | Nine sites right; the digest field touches every loop literal; one commit is feasible with the split of item 1. |
| Host part (§5) | **accept** | Lifetime, three-arm rule, same-commit digest rule, synchronous exit append all right; `first_kept` resolution is vacuous but harmless. |
| Open question 3 (§6) | **defensible** | "Always carry" is bounded by the provider payload; measure once. |
| Estimates (§7) | **accept** | P3's split adds no days. |
| P1 start (§8) | **yes, after items 3–4** | Both are line edits inside P1. |

## 1. Fidelity

| v6.1 | plan part | note |
|---|---|---|
| D1 journal, envelope, entry types, one message per entry, `first_kept: None`, codec, the type move | P1 Part 3 (`Continuation`, `RunIdentity`, `FinalState`, `[Message]` codec, the move, `:197–229`); P3 Part 2 (entry types, `:399–403`); P3 Part 3 (file, header, `:433–449`) | Right split: in-memory types in P1, on-disk types in P3. |
| D2 suspension; `HistorySeeded`; the nine-site table with `replaces_previous`; `HistoryReplaced` with `first_kept: None`; `StateDelta` with `cumulative`; `RunSummary`/`SessionStart` fields | P1 Parts 2, 4, 6; P3 Part 1 | Site table verified in the v5 review and unchanged (`session.ail:2251`, `:2356`, `:2381`, `:2494`, `:2907`, `:2944`, `:2989`, `:3025`, `:3057`, `:3409`). |
| D3 host writer, three-arm seed rule, digest rule in one commit, header rewrite, synchronous exit entry, lease | P3 Part 3 | |
| D4 fold rules, `final` at seven arms, `JournalFold` family, pairing check, incremental digest | P1 Part 4 (`final`); P3 Part 2 | |
| D5 ids, `resume_count`, compatibility, `from_ordinal` | P1 Part 5; P3 Parts 3–4 | Item 3 on where `resume_count` is read. |
| D6 in-process; cross-process order; restart; crash | P1 Part 5; P3 Part 4 | |
| D7 | P4 | |
| D8 | phase table (`:97–107`) | |

**The four P1 deletions** (`:115–118`, `:652–658`) are D8 step 1's (`ADR-003:553–566`): no `written`; `journal.ail` without `Snapshot`, `SnapshotWritten`, world decoding; `final` as a `c2_finalize` parameter at seven callers; no generation reset. Exact.

**Nothing invented or re-decided**, with two additions the ADR leaves to the plan and the plan chose: the canonical form of the incremental chain (Open question 8, item 2) and the read site of `MOTOKO_RESUME_COUNT` (item 3). Both are the plan's to choose; one is chosen wrong.

## 2. Sequencing

- **Family red first, then events:** item 1. With the three-commit split the claim holds and "red from P1 Part 4 until the emits land" (`ADR-003:136–137`) is what the sweep will show.
- **PLAN-001 P2 dependency:** one field, `run_finished.world_ordinal` (`:104–107`); `WorldState` has no `ordinal` at HEAD (`src/core/ports.ail:183–196`). Right.
- **No `Ports` field:** true throughout (§0.8, `:86–91`). **A new helped leaf:** item 3.
- **Anchors:** P1's three moving commits and the one-re-issue path are v2's finding, adopted (`:42–56`). P3 Part 1's emits sit between anchors `1529` and `3016` (`anchors.sh:385`), so they move `3016` and `3126`; the seed at `session.ail:3143` is below `3126` and moves nothing. One re-baseline for P3, priced (`:390`, `:678`). Right. The `C2LoopState.history_digest` field (`:375`) is declared at `:383–429`, above all five anchors, so it moves them too — in the same commit, no extra re-issue.

## 3. Gates

- **P1 Part 1 fixture** (`:122–143`): buildable and red-first, as v2 found; `final.history == s.history` is one more assertion on a value P1 Part 4 returns. The `continuing_token_step` import (`scripts/dst/phase_c2_wiring_scenarios.ail:33`; `src/core/test/stub_step.ail:771–781`) is now stated. Executable.
- **Digest chain in the wiring fixture** (`:391–393`): item 2. Also the canonical forms omit `images` (`phase_vocab.ail:233`, `:241` frame role, content, `tool_call_id`, `tool_calls`), so a chain built on either is blind to an image change; say so or add `images` to the per-message frame the chain uses.
- **`JournalFold` red then green on the sweep** (`:421–424`): executable after item 1; the red claim is right for every fixture because `final.history` is never empty (every terminal arm has at least the seed).
- **`journal_resume_dst.ail`** (`:507–512`): "builds a journal from its trace as the host would" is the same id-assignment the family performs, so the script shares that code; the seed-digest equality and the ordinal assertion are two integers the script holds. Needs its Make target and `DST_TARGETS` row, which the plan says (`Makefile:436–441`). Executable.
- **Fake-emitter lease test** (`:464–468`): executable; `exit-actions.test.ts:43–115` has no precedent, as stated.
- **Crash-resume live gate** (`:515–517`): a `kill -9` of the child reaches the exit handler with no flag set, which writes the `exit(child_exit)` entry and exits the TUI (`src/tui/src/index.ts:980–985`); the operator then starts a TUI with `--resume`. Executable, and it exercises the host's synchronous exit append (`:452–453`).

## 4. The events part

- **Nine sites:** the table (`:363–370`) matches the v5 review's audit at every line.
- **The digest threaded as a `C2LoopState` field** (`:375`): every full `C2LoopState` literal must set it — the thirteen loop literals at `session.ail:2250`, `:2297`, `:2355`, `:2380`, `:2493`, `:2520`, `:2674`, `:2848`, `:2906`, `:2943`, `:2988`, `:3024`, `:3056` plus the two constructors (`:709–730`, and P1's `c2_state_from_continuation`). Those are the history sites plus the unchanged-`msgs` sites; say the count so the estimate holds.
- **`HistorySeeded` appended to the initial state's trace** (`:355–359`): the constructor starts the trace empty (`:728`); appending after construction is the bootstrap pattern ADR-001 D2 prescribes for `witness` (`ADR-001:405–409`). No fixture asserts the first trace record (the `match records` walkers at `phase_c2_wiring_scenarios.ail:98`, `:392`, `:407` and `discovery_dst.ail:510`, `:533` filter by variant). Feasible.
- **Five variants and two fields in one commit under `make event_vocabulary`:** the gate counts `LedgerEvent` variants against `event_vocabulary()` rows and goldens (`Makefile:1257–1262`; rows at `src/core/dst_event_vocabulary.ail:241–246`; goldens `phase_vocab.ail:1221–1229`), and the `RunSummary`/`SessionStart` goldens move (`:593`, `:791`). Feasible in one commit; with item 1 that commit carries no emits.

## 5. The host part

- **`SessionJournal` lifetime** beside `sessionStartMs()` (`src/tui/src/session-identity.ts:37`), handed to each per-spawn logger (`index.ts:903`; `session-logger.ts:355–359`): right.
- **Three-arm seed rule** (`:437–440`): compares child-computed digests only; the host computes none. Right, and the "Do not" row enforces it (`:534–535`).
- **Digest rule in the same commit** (`:441–445`): `parseAgentEventLine` accepts any typed object (`runtime-process.ts:105–117`) and unknown types are logged verbatim (`runtime-process.unknown-events.test.ts:36`). Right.
- **Synchronous exit append** (`:452–453`): the reporter's `spawnSync` is the precedent (`herdr-agent-state.ts:346–351`). Right.
- **`first_kept` resolution with a running message count** (`:435`): vacuous while `first_kept` is `None` (`phase_vocab.ail:263–281`, `:349–366`); the count costs nothing and is ready for a tail-keeping checkpoint. Fine.

## 6. Open question 3: the seed on stdout

Defensible. Every traced run's `HistorySeeded` carries its starting history; for a follow-up turn that is the whole retained history, the same messages the provider call sends each step (`session.ail:2790`), so the pipe carries what the network already carries, once per turn rather than once per step. The pipe has no line cap (`runtime-process.ts:588`) and the host drops the seed after a digest compare. The trace must carry it for the family. Keep "always carry" as the default and record one measurement in §5: bytes of `history_seeded` per turn in the probe. The environment toggle is a later optimisation, not a decision the plan needs now.

## 7. Estimates

P1 6–9 (`:676`) is v2.1's minus the deleted work; right. P3 9–12 (`:678`) is plausible; the three-commit split of item 1 reorders, it does not add. The one thing unpriced is the `C2LoopState` field's fifteen literal edits (§4), which fit inside the "five new events at nine sites" line.

## 8. Can P1 start?

**Yes, after two line edits:** item 4 (export or route the four helpers; P1 Part 3) and item 3 (read `MOTOKO_RESUME_COUNT` ambiently in `rpc.run_with_config`; P1 Part 5). The sweep precondition is met (§5 of the plan; `.ailang/dst-last.log` dated Sep 6 18:59 exists; the anchors red is deferred to Part 4 by §0.2; the ambient-inventory re-pin is uncommitted in the working tree, `git status` shows `M tools/ext_ambient_inventory/fixtures/expected.json`, and `hook_scope/expected.json:197` says 18; the depth canary is the owner's call under `run_depth_canary.sh:53–58`, with `DST_KNOWN_RED` empty at `Makefile:493`). The canary listing under `DST_KNOWN_RED` is a Makefile edit the owner makes or declines before Part 2's gate runs `make dst`; say which in §5.

P3 cannot start until items 1 and 2 are folded; neither affects P1.

## 9. Coordinate audit (new in v3)

| cited | verified | note |
|---|---|---|
| `session.ail:2044–2053` for the policy-init env reads | approx | the four `ports.env_get` calls are `:2041–2044` |
| `:3137–3148` | yes | traced entry; `c2_loop` at `:3143` |
| `:2973` (hybrid gate) | yes | `if hybrid_tools && session_emitted_native_tool_call(...) == false` |
| `phase_vocab.ail:106–112`, `:237–245`, `:263–281`, `:349–366` | yes | `:237–243` is the raw form; `digest_messages` at `:245–247` uses `canonical_messages` `:229–233` (item 2) |
| `phase_vocab.ail` helpers as importable (`PLAN-003:199–201`) | **no** | `system_is_head_prefix` `:75`, `take_system_prefix` `:85`, `canonical_messages_raw` `:237`, `digest_messages` `:245` are private; `History` `:26` is private |
| `seeded_generator_dst.ail:415–421`; `run_report_dst.ail:173–178` | yes | the pinned env-read keys (item 3) |
| `dst_invariants.ail:1131`, `:1319` | yes | `tool_pairing_findings`; `checkpoint_findings` |
| `session-identity.ts:37`; `herdr-agent-state.ts:346–351` | yes | |
| `Makefile:493`, `:2776` | yes | `DST_KNOWN_RED :=`; `attribution_table` runs `make anchors` |
| `tools/ext_ambient_inventory/fixtures/expected.json:84` | now the note | after the re-pin `:84` is the "RE-PINNED BY HAND" line; the count is `"extensions": 18` |
| `fixtures/hook_scope/expected.json:197` | yes | `"extensions": 18` |
| `run_depth_canary.sh:53–58` | yes | the pin-bump rule |
| `.ailang/dst-last.log` | yes | 737 KB, Sep 6 18:59 |
| `stub_step.ail:771–781`; `phase_c2_wiring_scenarios.ail:33`, `:66–68`, `:120–122` | yes | |
| `invariants_dst.ail:385`, `:1008`; `dst_execution.ail:110–118` | yes | |
| `runtime-process.unknown-events.test.ts:36`; `runtime-process.ts:105–117`, `:588` | yes | |
| `rpc.ail:189–192` (not cited; the ambient precedent item 3 recommends) | yes | `headless_mode()` |

## Required changes

1. P3: reorder into vocabulary (variants, rows, goldens, no emits) → fold and family (red) → emits (green); renumber Parts 1–2 and fix `:348–349`, `:421–424`.
2. P3 Part 1 gate: recompute the incremental chain over `suspended.history` and compare with the last `digest_after`; settle Open question 8 on one per-message frame (`phase_vocab.ail:229–243`), and say whether `images` enter it.
3. P1 Part 5: read `MOTOKO_RESUME_COUNT` ambiently in `rpc.run_with_config` (`rpc.ail:189–192` pattern) and pass it to the loop; no port read (`seeded_generator_dst.ail:415–421`; `run_report_dst.ail:173–178`).
4. P1 Part 3: export `system_is_head_prefix`, `take_system_prefix`, `canonical_messages_raw`, `digest_messages` from `phase_vocab.ail`, or build a `History` through `history_from_seed` (`:28–31`) and keep the digest helpers in `phase_vocab.ail`.
5. P3 Part 1: name the fifteen `C2LoopState` literal sites the `history_digest` field touches.
6. §5: record whether the canary goes under `DST_KNOWN_RED` before Part 2's `make dst`.
