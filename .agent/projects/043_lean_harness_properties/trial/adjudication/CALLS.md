# W4: the same-defect and reachability calls

PLAN-001 §8 gives two judgements to the operator:

- **Same defect.** For real defects, whether one fix closes both.
- **Reachability.** Whether an unknown real defect can occur in a real run (Kiro's steps 6-7).
  It "matters only for §10 (b)".

The adjudicator drafted each call with its reason. The operator decided in the adjudicator's
session, and the decisions are in the last section. Every report named here is one that
`table.tsv` classes as a real defect: it exits 1 on T and on B0, and detects no seed.

## What counts

- **Which properties.** Only a real defect on a primary property can count towards U and §10.
  §3 says secondary results are "reported but do not count", and §13 says exploratory ones "do
  not decide anything". The secondary and exploratory groups below are drafted for the record
  (§9), and need no reachability call.
- **Who found what.** "Found" means a report by any session of that arm, whatever property it
  names.
- **What "known" means.** A defect counts as known only if it is the same defect as a §4 entry
  (K1-K10). Anything else is unknown, even when the code or the research note describes it.

## Primary properties: the drafts

| Id | Target, property | The defect | Reports | Found by | Same as a §4 entry? |
|---|---|---|---|---|---|
| D1 | T2 P2.1 | `failure_shape` tests for `nested herdr` before it tests for herdr's JSON (types.ail:1139), so a JSON envelope whose message holds that text is `nested_herdr` in AILANG and its code in TS | A1-T2-9, A2-T2-5, B1-T2-3, B2-T2-2; also B1-T2-10 (P2.2) | A1 A2 B1 B2 | **K7.** The same line and order, and the same consequence for `agent_not_found` that K7 predicted. A1 shows that swapping the two AILANG tests makes its repro exit 0, and A2 that adding the test to the TS side does |
| D2 | T2 P2.1 | AILANG's `std/json` decode accepts a JSON value followed by more text and reads the value; `JSON.parse` rejects the whole stderr | A1-T2-5, A2-T2-4, B1-T2-6, B2-T2-6 | A1 A2 B1 B2 | No |
| D3 | T2 P2.1 | TS trims stderr with `String.prototype.trim`, which strips Unicode spaces that JSON does not allow and AILANG's decode refuses (U+00A0, U+FEFF, U+3000, …) | A1-T2-7, A2-T2-6, B1-T2-5, B2-T2-7 | A1 A2 B1 B2 | No |
| D4 | T2 P2.1 | A repeated key: `JSON.parse` keeps the last member, AILANG's `get` the first | A1-T2-8, A2-T2-7, B1-T2-7, B2-T2-5 | A1 A2 B1 B2 | No |
| D5 | T2 P2.1 | A number beyond float64 anywhere in the stderr makes AILANG's decode fail; `JSON.parse` reads Infinity | A1-T2-10, A2-T2-8, B1-T2-8, B2-T2-14 | A1 A2 B1 B2 | No |
| D6 | T3 P3.1 | An empty call id: the host's `updatePending` filters `""`, the fold keeps it open, so the writers arm a crash resume differently | A1-T3-3, B1-T3-6 | A1 B1 | **No**, but RESEARCH §6.2 described this shape (`[asst([a, ""]), tool(a)]`) before the trial, and both reporters cite it. It is not a §4 entry |
| D7 | T3 P3.1 | `first_kept` = -1: the host drops it as out of range, the twin copies it, and the fold's `drop_hist(-1)` keeps everything | A1-T3-4; also A2-T3-5 (X-2, case x2a) | A1 (A2) | No |
| D8 | T3 P3.1 | After a checkpoint the host's `historyMessages` counts only the replacement's messages, not the head prefix the fold keeps, so an in-range `first_kept` is dropped and the host folds a shorter history | A1-T3-5, B1-T3-5; also A2-T3-5 (x2b), B2-T3-6 (X-1) | A1 B1 (A2 B2) | No |
| D9 | T3 P3.1 | Message text that is not valid UTF-8: the child hashes the raw bytes, the wire encoding writes U+FFFD, so the host's journal is refused `digest` and the twin's folds | B1-T3-9 | B1 | **No.** K5 is `std/bytes.toString` not repairing invalid UTF-8. This is a hash taken before an encoding that does repair, and a fix to K5 would not close it |
| D10 | T3 P3.2 | A checkpoint followed by a follow-up turn: the loop chains the append from the empty base, not from the checkpoint's rebased chain, and both writers' journals are refused `digest` | A1-T3-6, B1-T3-7, B2-T3-5 | A1 B1 B2 | **No**, but the code documents it as a known, fail-closed limitation (session.ail:4372-4386, session-journal.ts:646-656). It is not a §4 entry |
| D11 | T3 P3.2 | A parked resume's record list carries the wake message's `HistoryAppended` before its `HistorySeeded`, and the twin writes it as the journal's first history entry | A2-T3-4 | A2 | No |
| D12 | T5 P5.3 | `""` is both the no-parent sentinel and an id the decoder accepts, so `path_up` from start id `""` returns `[]` even when an entry has that id | A1-T5-2, A2-T5-3, B1-T5-3, B2-T5-2 | A1 A2 B1 B2 | No |

### Why these groupings

- **D2, D4 and D5 are kept apart.** Each is a different decoder behaviour, so no one change to
  either side's JSON reading closes all three. An exception would be replacing AILANG's reading
  outright with a parser that matches `JSON.parse`. For D4, RFC 8259 leaves duplicate names
  undefined.
- **D7 and D8 are kept apart.** No count of `historyMessages` makes -1 in range, so D8's fix
  (count the head prefix) leaves D7 open. D7's fix (refuse, or drop, a negative index in the
  twin and the fold) leaves D8 open.
- **D6 and D10 are drafted as unknown,** because §8 makes known mean "in §4". The operator may
  instead read §4 as covering what was written down before the trial.

### What an exploratory report adds

A2-T3-5 and B2-T3-6 report D7 and D8 under X-labels. They change no "found by" for §10: D8 was
already found by both arms, and D7 already by arm A.

### Who found what

- **Found by arm B and by no arm A session:** D9 only.
- **Found by arm A and by no arm B session:** D7 and D11.
- **Found by both arms:** everything else.

## Reachability: drafts for the unknown primary defects

| Id | Draft | Reason |
|---|---|---|
| D2 | Not shown | Two sources of trailing text are known, and neither reaches both twins. herdr's measured stderr is one JSON envelope. The only trailing text the reports found is the TS runner's own "killed by SIG…" line (wake-waiter.ts:514), which only the TS twin sees, and then at exit -1. No report shows herdr writing after its envelope (A1 and B1 say so) |
| D3 | No | herdr writes ASCII JSON, and no report shows a leading BOM, NBSP or other Unicode space from it |
| D4 | No | herdr's serializer does not emit duplicate names (A2, B1, B2) |
| D5 | No | herdr's error envelope carries no numbers (A1, A2, B2) |
| D6 | Not shown | It needs a provider adapter that emits a tool call with an empty id. RESEARCH §6.3 leaves this open, and so do both reports |
| D7 | No, at HEAD | The only producer sends `first_kept` None (session.ail:3113). The wire schema admits any integer, so it is latent |
| D8 | No, at HEAD | The same: every checkpoint sends `first_kept` None. Latent until a checkpoint keeps a tail |
| D9 | Not shown | See below. The obvious route is closed |
| D10 | **Yes** | A checkpoint followed by a follow-up turn is an ordinary session: compaction, then the operator types again. A1 counts it among the run-emittable cases. The code documents it as fail-closed: the host marks the session unresumable. B2 notes that it takes two runs of one session, which the operator may read as outside "a run" |
| D11 | Not shown | A2's own note: production feeds this record list only after frame1's records, where ADR-003 D1's arm 3 drops the seed and the journal folds. No entry point was shown that journals it alone |
| D12 | No | The host writes ids as `entryId(seq)`, never `""` (session-journal.ts:89-91). Only a journal that Motoko did not write could reach it |

### D9, the obvious route

**Why it matters.** D9 is the only defect in the "found by arm B and by no arm A session" set, so
its reachability is the one call that bears on §10 (b). B1's note names a route: tool output of
a Latin-1 file, if the tool layer keeps raw bytes. The adjudicator followed that route in B0's
code and with one AILANG probe.

**What the code does.**

1. A bash tool's output is read as raw bytes and turned into text by `std/bytes.toString`
   (`tool_runtime.ail:985`), which keeps invalid UTF-8 (K5).
2. That text does not enter the history raw. The live path JSON-encodes it into the tool
   message's content: `tool_dispatch_adapter.ail:151-160` (`kv("stdout", js(r.stdout))`), then
   `tool_phase.ail:291` (`tool_result_message(call, c.content)`). The raw-text renderer
   `prompts.ail:fmt_tool_obs` has no caller.
3. AILANG's `encode` writes an invalid byte as U+FFFD. `probe/utf8_encode.ail` on the bytes
   `61 62 FF 62 63` gives `{"stdout":"ab\xEF\xBF\xBDbc"}` (`probe/utf8_encode.out`).

**So.** A tool that prints a non-UTF-8 byte puts valid UTF-8 into the history, and D9 is not
reached that way. Not examined: any other place where a `Message`'s content is built from text
that never passed through `encode`. Nothing was run end to end.

## Secondary properties (P2.2, P6.3): drafts for the record

None of these counts. Each line below is a same-defect draft.

| Id | The defect | Reports | Draft |
|---|---|---|---|
| S1 | Empty stderr on a failing exit: `herdr_failed_silently` against `herdr_cli_rejected` | A1-T2-13, B1-T2-11, B2-T2-9 | K6 |
| S2 | Plain `nested herdr` text: `nested_herdr` against `herdr_cli_rejected` | A1-T2-14, B1-T2-12, B2-T2-10 | K6 |
| S3 | A timeout envelope whose message mentions `nested herdr` | B1-T2-10 | D1, that is K7 |
| S4 | Stderr holding `{"error"` that is not valid JSON: `herdr_json_undecodable` against `herdr_cli_rejected` | A1-T2-11, B1-T2-14, B2-T2-12 | Unknown. K6 names two cases outside herdr's JSON, and this is a third code |
| S5 | Valid JSON that is not herdr's envelope: `herdr_json_undecodable` in TS, `herdr_cli_rejected` in AILANG | A1-T2-12, B1-T2-13, B2-T2-11 | Unknown |
| S6 | A lone-surrogate escape in `error.code` | B2-T2-8 | Unknown |
| S7 | The cut splits a multi-byte character | A1-T6-2, B1-T6-2, B2-T6-2 | K2 |

## Exploratory properties: drafts for the record

None of these counts.

| Id | The defect | Reports | Draft |
|---|---|---|---|
| X1 | `adopt()` leaves a torn last line, and the next append glues onto it | A2-T3-6, B1-T3-8 | One defect |
| X2 | `first_kept` | A2-T3-5, B2-T3-6 | D7 and D8 (see above) |
| X3 | `chain_digests_over` is quadratic (`acc.out ++ [d]`) | A1-T4-3, A2-T4-3 | One defect |
| X4 | `chain_digest_after` has no delimiter, so a non-fixed-width `previous` collides | A2-T4-4 | One defect. Latent: every base the tree passes is 71 characters |
| X5 | The header comment on `chain_digest_base` names the wrong digest | B2-T4-3 | A comment, not behaviour |
| X6 | `path_up` is quadratic in path length | A1-T5-3, A2-T5-4, B2-T5-4 | One defect |
| X7 | A repeated id: `find_entry` takes the first, `journal_leaf` the last | B2-T5-3 | One defect, and a question of intent |
| X8 | compose-claimcheck's `truncateUtf8ByBytes` decodes a split character to U+FFFD: text over the cap, not a byte prefix, and `omittedBytes` under-reported | A1-T6-3, A1-T6-5, A2-T6-3 | One defect: cutting at a character boundary in that function closes all three |
| X9 | env-server.ts's `truncateUtf8ByBytes`, the same code in a second function | A1-T6-4 | Separate from X8, a second place to fix. It is never called at this snapshot |
| X10 | `store_stdout_and_elide` drops `dir_make`/`file_write` failures | A2-T6-4 | One defect |

## Not a call: A2-T6-1 and A2-T6-2

Both errored on B0 and T−s14, with exit 2. The session's driver calls `Str.length` and relies on
`store.ail` importing `std/string as Str`, an import only seed s14 adds. By §8 an error is not a
detection, so they are unclassified. They are noted because A2-T6-1's claim is s14's defect. The
rule decides this, not a judgement.

## The operator's decisions

(Recorded below as the operator gives them in the adjudicator's session.)
