# ADR-003 v6 adversarial review verdicts

Date: 2026-09-07
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; the HEAD the ADR names, `ADR-003-session-snapshot-and-resume.md:15`)
Subject: `ADR-003-session-snapshot-and-resume.md` v6 (journal-only; folds the v5 review's eight changes)
Prior: `REVIEW-adr003-v5-verdicts-fable.md`; v1–v4 reviews; PLAN-003 v2.1 and its two reviews

Every new coordinate and claim was checked at this HEAD; claims carried from v5 stand on that audit. §6 lists what is new.

## Overall verdict

**Accept with corrections; PLAN-003 v3 can be written after three items are settled in a v6.1.** The eight changes are folded, and the two shape choices — one message per entry, and a `HistorySeeded` event at the traced entry — are the right ones. Three things a v3 plan would otherwise have to decide:

1. **`first_kept_index` points at nothing.** The checkpoint at HEAD rebuilds the history as the system prefix plus one summary message and keeps no tail: `checkpoint` returns `MkHistory(pinned ++ [summary_msg])` (`src/core/phase_vocab.ail:263–281`, the rebuild at `:270`), and `apply_checkpoint` installs that as the whole history (`:349–366`, `:355`). There is no "tail `apply_checkpoint` keeps" (`ADR-003:289–291`), so the host's index-to-id resolution (`:231`, `:291–292`) resolves an index that never exists. Make `first_kept` optional and `None` at HEAD; keep the field for a tail-keeping checkpoint later. The fold's rule 3 then reads: prefix, then the replacement's messages, then every history entry after the replacement.
2. **The seed's first-run-only rule breaks on a profile switch.** D6 step 4 replaces the head system prefix on a profile switch (`ADR-003:458–460`), so the resumed child's `HistorySeeded.digest` legitimately differs from the journal's last `digest_after`; the host's rule "check the digest and drop, mismatch marks the session unresumable" (`:229`) would mark exactly the restart-into-a-new-profile case the D8 gate tests (`:516–517`). The rule needs a third arm: after a `resumed` entry whose `profile_to` differs (or whose `prompt_digest_to` differs), the seed is journaled as a `history_replaced` carrying the new head, and its digest becomes the chain's new base.
3. **P1's restated acceptance test needs events P3 lands.** D8 step 1 says Part 1 asserts "that the journal-class records in the trace fold to `suspended.history`" (`:498–500`), but `HistorySeeded` and `HistoryAppended` are step 3's (`:510–512`). Either the seed and the append events move into P1 (which makes P1 the whole D2 wire change), or P1's fixture asserts `suspended.history` directly, as PLAN-003 v2.1 does, and the fold assertion is P3's first red. Decide.

Two smaller corrections that are not decisions: the host's digest check as written needs a TypeScript twin of `digest_messages` (`phase_vocab.ail:237–245`) — the two-sides-of-the-boundary shape `runtime-process.ts:375–378` names as MOT-118 — when it can instead compare the seed's child-computed `digest` with the previous entry's child-computed `digest_after`; and `history_valid_transcript` does not enforce tool-call pairing (`phase_vocab.ail:106–112` checks only that a tool message has a non-empty id and that assistant calls are well-formed), so the reason for `replaces_previous` is the provider's rejection of an unpaired result and the `digest_after` chain, not a refusal the fold would raise.

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT WITH CORRECTIONS** | One message per entry is right; `first_kept_index` is vacuous at HEAD (item 1); the seed rule needs the profile-switch arm (item 2). |
| D2 | **ACCEPT WITH CORRECTIONS** | Site table is now correct at every site; `replaces_previous` at `:2251` is the right rule; one wrong justification (transcript validity). |
| D3 | **ACCEPT WITH CORRECTIONS** | Host-lifetime `SessionJournal` and the same-commit digest rule are right; the `exit` entry from a process-exit hook must be a synchronous write; the digest twin (§3.1). |
| D4 | **ACCEPT WITH CORRECTIONS** | Fold rules sound with `first_kept` made optional; `final` at seven terminal arms, not three; the pairing check must be explicit. |
| D5 | **ACCEPT** | Unchanged from v5. |
| D6 | **ACCEPT WITH CORRECTIONS** | Order and the ambient read are right; the profile-switch seed (item 2). |
| D7 | **ACCEPT** | Unchanged from v5, with the `WakeReceived` producer now stated. |
| D8 | **ACCEPT WITH CORRECTIONS** | P1's deltas are listed, but the "Not retracted" paragraph still says P1 is untouched (`:106–107`), and Part 1's test needs P3's events (item 3). |

## 1. Disposition of the eight required changes

| # | v5 change | Disposition | Residual |
|---|---|---|---|
| 1 | Journal the initial history and system prompt | **Folded** (`ADR-003:229`, `:269–272`) | The host's digest check should compare child-computed digests (§3.1); the profile-switch arm (item 2); `ContextLimitResolved` does not exist at HEAD (0 occurrences in `session.ail`, `phase_vocab.ail`), so the seed has the first trace position free now, and PLAN-001 P1 must order its per-run entry event after it. |
| 2 | True site list; the `:2251` rule | **Folded** (`:273–288`) | Every site in the table matches the `msgs:` literals at HEAD (`session.ail:2251`, `:2356`, `:2381`, `:2494`, `:2907`, `:2944`, `:2989`, `:3025`, `:3057`, `:3409`; unchanged at `:2298`, `:2675`, `:2849`). The transcript-validity justification is wrong (§3.2). |
| 3 | One message per entry or `first_kept_offset` | **Folded, but the pointer it serves is vacuous** (`:230–231`) | Item 1. |
| 4 | `final` projection through `execution_of` into `ExecutionUnderTest`; seed the fold | **Folded** (`:390–395`) | "Set at every terminal arm (the success arm, `c2_suspend`, `c2_fail`)" names three; `c2_finalize` has seven callers (`session.ail:2206`, `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`), all with `st` in scope, and `final` must be set at each or the family refuses the invalid-history, approval and seal arms. `c2_fail` has one caller (`:2437`), so handing it `st` is one edit. `ExecutionUnderTest` is built by the bridge (`dst_execution.ail:110–118`) and by one fixture literal (`scripts/dst/invariants_dst.ail:385`) plus a record update (`:1008`); a required `final` touches those. |
| 5 | Host-lifetime journal; digest rule with the events | **Folded** (`:307–318`) | The `exit` entry is written "from its exit handler and the host's process-exit hooks" (`:327–328`); a stream write in a `process.on("exit")` listener does not flush (the reporter had to go synchronous for the same reason, `herdr-agent-state.ts:348–350`), so that one append must be `fs.appendFileSync`. |
| 6 | `cumulative` in `StateDelta` | **Folded** (`:232`, `:385–387`) | None; `:559` is the exact expression, and `:483–497` is where the counts come from. |
| 7 | List P1's deltas | **Folded** (`:496–506`) | `:106–107` still says "PLAN-003 P1, which writes nothing and is untouched"; item 3. |
| 8 | Citations | **Folded** (`:266–267`, `:582`) | `parity_findings` at `:946–951` is register + vocabulary presence + stream-delta parity; "compares presence, not payload" is right. |

## 2. Per-decision verdicts

### D1 — accept with corrections

Verified: `checkpoint` keeps no tail (`phase_vocab.ail:263–281`); one message per entry matches oh-my-pi (`session-entries.ts:73–76`, v5 audit); `RuntimeStatusCounts` and its helpers at `session.ail:431–437`, `:443`, `:545–553` with `zero_totals` at `:439–441` staying (`ADR-003:243–245`); `Msg` without `images` (`packages/motoko-ext-abi/types.ail:547`) vs `Message` (`session.ail:3402–3408`). Corrections: items 1 and 2; and the `exit` entry's `pending_tool_calls` "computed by the host with a TypeScript twin of the fold's trailing-pair rule" (`:238`) is a second twin — acceptable at three lines, but say the child could emit it in `RunSuspended`/`RunSummary` instead and the host would then compute nothing.

### D2 — accept with corrections

Verified: the site table (§1 row 2); `pending_tool_prefix` set to `msgs_with_assistant` on the native path (`session.ail:2953`) and to `st.msgs ++ [augmented_assistant_msg]` on the hybrid path (`:2998`, message built at `:2981–2987`); `c2_finish_tool_batch` rebuilds from the prefix (`:2213–2215`, `:2251`); telemetry and artifacts change at `:2911`, `:2947–2948`, `:2992–2993` and the checkpoint arm `:2524–2525`; the `SessionStart` and `RunSummary` goldens (`phase_vocab.ail:593`, `:791`).

**`replaces_previous` at `:2251`: right.** On the native path the prefix equals `st.msgs`, so `:2251` contributes only the tool results, one event each; on the hybrid path the first event carries the augmented assistant with the flag and the fold drops the plain one. The `digest_after` on that event is over the rebuilt history (`:2251`), so a fold that appended instead fails the digest at that entry — the ADR's "unfakeable" (`:405–409`) holds. Correction: `history_valid_transcript` is not what would catch an unpaired pair (`phase_vocab.ail:106–112`); the fold needs its own pairing rule, which rule 4 gives for the trailing assistant and the `ToolPairing` family (`dst_invariants.ail:1131`) gives in the harness. Say that, and drop the transcript claim from retraction 2 (`ADR-003:72–73`).

### D3 — accept with corrections

Verified: the logger is per spawn (`index.ts:903`) and closed at child exit (`:925`); `sessionStartMs` is the host-lifetime precedent (`session-identity.ts:37`); `parseAgentEventLine` accepts any typed object (`runtime-process.ts:105–117`) and unknown types are logged verbatim (`runtime-process.unknown-events.test.ts:36`); the header values the host has at spawn (`runtime-process.ts:482–505`); the lease hooks between `initExitActions()` and `initHerdrReporter()` (`index.ts:825–827`; `exit-actions.ts:422–428`). Corrections: the synchronous `exit` append (§1 row 5); the digest twin (§3.1).

### D4 — accept with corrections

§3 covers the rules. The comparand and the family: `TracedSessionResult.final` carried by `execution_of` (`dst_execution.ail:100–119`) into `ExecutionUnderTest` (`dst_invariants.ail:553–566`), a 13th `InvariantFamily` member (`:205–216`, `all_families()` `:273–277`, `family_id` `:219`, `violation_family` `:334`), and a `journal_fold_findings(x: ExecutionUnderTest)` on the pattern of `checkpoint_findings` (`:1319`). Implementable. Corrections: seven terminal arms, not three (§1 row 4); `first_kept` optional (item 1); an explicit pairing check.

### D5 — accept

Unchanged from v5; `from_ordinal == final` at `session.ail:1550–1554` stands.

### D6 — accept with corrections

Verified: the ambient `readFile` precedent (`rpc.ail:266–267`); `SCAN_FILES` excludes `rpc.ail` (`derive.py:144–149`) and `CALL_RE` matches port methods only (`:151–155`); the five-step order against `rpc.ail:241–247`, `:319`, `:342`, `:344–345`. Correction: item 2.

### D7 — accept

The `WakeReceived` producer is now stated (`ADR-003:479–483`; `ADR-002:279–281`). Unchanged otherwise.

### D8 — accept with corrections

Items 3 and the `:106–107` contradiction. Also: PLAN-003 v2.1 settled `c2_finalize` as "not re-parameterised; record update at the two producing sites"; with `final` at seven arms, a `c2_finalize` parameter is now the smaller edit, and D8's Part 4 delta should say so.

## 3. The new pieces

### 3.1 `HistorySeeded` and the first-run-only rule

**Sound in shape.** The traced entry has the run's `history` in hand at `session.ail:3143` before `c2_loop`; appending the seed to the initial state's trace (the constructor starts it empty, `:728`) is the bootstrap pattern ADR-001 D2 already prescribes for `witness` (`ADR-001:405–409`). For a fresh session the seed is `[system, task]` (`rpc.ail:344–345`); for a follow-up turn it is the loop's history including the operator message the loop journaled at `:3409`; for a resumed run it is the fold's output.

**Two corrections.** (a) The host's check "against the fold's current history digest" (`ADR-003:229`) requires the host to compute `digest_messages` over the messages it holds, i.e. a TypeScript twin of `canonical_messages_raw` and `sha256Hex` (`phase_vocab.ail:237–245`, `:253–255`). The journal already holds a child-computed digest on every history entry (`digest_after`), so the host can compare the seed's `digest` with the last history entry's `digest_after` and compute nothing. (b) Item 2: after a `resumed` entry with a changed prompt, the digests differ by design.

### 3.2 `replaces_previous` and the site table

Right (§2 D2). The one-per-message shape also fixes a subtlety v5 had: `:2907` is two messages (assistant, then the intercept's tool message) and the table now says "two" (`ADR-003:280`).

### 3.3 `digest_after` per entry

Sound, and it is the chain v4.1 could not have. One consequence to state: the child must compute a digest at every history site — nine sites plus the seed and the conversation loop's `:3409` — which is one `digest_messages(st.msgs)` per event; the cost is a canonical serialization of the whole history per append, quadratic over a long session. Say it is accepted, or digest incrementally (hash of previous digest plus the new message), which the fold can check equally.

### 3.4 `first_kept_index` with one message per entry

Vacuous at HEAD (item 1). With `first_kept: Option`, the resolution is a lookup when it exists and nothing otherwise; the one-per-message shape is still right because oh-my-pi's compaction does keep a tail and a future Motoko checkpoint may.

### 3.5 `final: FinalState`

Sound; seven arms (§1 row 4). `c2_fail` handed `st` is one call site (`:2437`) and the edit is inside the band P1 Part 4 already moves (between anchors `1529` and `3016`; `anchors.sh:385`), so no anchor moves that P1 does not already move. The literal at `:1554` sets `final` from what `c2_finalize` is given, so `c2_finalize` gains a `final` parameter or the seven callers apply a record update; the parameter is smaller.

### 3.6 `SessionJournal` and the digest rule

Sound (§2 D3), with the synchronous `exit` append.

### 3.7 `cumulative` in `StateDelta`

Sound; exact (`session.ail:559`, `:483–497`).

### 3.8 Trailing-only dangling rule

Sound for a single path; the widening condition is stated (`ADR-003:381–384`; `session-context.ts:501–507`). The crash-mid-tool-phase shape works because the assistant with its calls is journaled at `:2944` before `RunTools` runs; on the hybrid path the plain assistant carries no calls until `:2251`, so nothing is stripped, correctly.

### 3.9 The ambient `readFile` at resume

Outside the traced surface: `run_with_config` reads files ambiently before the driver starts (`rpc.ail:266–267`), `rpc.ail` is not in `SCAN_FILES` (`derive.py:144–149`), and `make world_state` gates the deterministic entry, which a resume does not enter. Right.

## 4. Is the invariant implementable, and red at HEAD?

Implementable once `final` and the seed exist (§2 D4). "Red at HEAD by construction" (`ADR-003:403`, `:567–568`) is imprecise: at HEAD the family cannot compile, because neither `final` nor any journal-class variant exists. It becomes compilable when P1 Part 4 lands `final`, and from that commit until the events land it is red on every fixture, because a fold over no journal-class records yields an empty history against a non-empty `final.history`. That is the useful red; say "red from P1 Part 4 until P3's events" rather than "at HEAD".

## 5. Can PLAN-003 v3 be written?

**After a v6.1 that settles items 1–3.** Item 1 removes a resolver the plan would otherwise build; item 2 changes the restart gate's expected journal; item 3 decides where the D2 wire events land. The remaining corrections (digest comparison, synchronous exit append, seven arms, the transcript claim, the `:106–107` contradiction, the digest cost) are line edits the plan can carry.

## 6. Coordinate audit (new in v6)

| cited | verified | note |
|---|---|---|
| `session.ail:483–497`, `:559` | yes | `runtime_status_count_one`; the exact `cumulative` expression |
| `:2213–2215`, `:2251`, `:2298`, `:2675`, `:2849` | yes | prefix rule; rebuild site; three unchanged sites |
| `:2356`, `:2381`, `:3020`, `:3080` | yes | `c2_after_dp7` literals and its two call sites |
| `:2517–2525`, `:2911`, `:2947–2948`, `:2981–2998`, `:2992–2993` | yes | |
| `:3137–3143` | yes | the traced entry; `c2_loop` call at `:3143` |
| `phase_vocab.ail:349` "the tail `apply_checkpoint` keeps" | **no** | `apply_checkpoint` (`:349–366`) installs `checkpoint`'s rebuild, which is `pinned ++ [summary_msg]` (`:263–281`, `:270`); no tail |
| `phase_vocab.ail:106–112` (implied by "history_valid_transcript" refusing an unpaired pair, `ADR-003:72–73`, `:374–375`) | **no** | it checks tool-message ids and call well-formedness, not pairing |
| `phase_vocab.ail:593`, `:791` | yes | `SessionStartInfo`; `RunSummary` projection |
| `dst_invariants.ail:205–216`, `:553–556`, `:946` | yes | `parity_findings` `:946–951` |
| `dst_execution.ail:110–118`; `dst_result.ail:93–98` | yes | |
| `derive.py:144–155`; `rpc.ail:266–267`, `:344–345` | yes | |
| `runtime-process.ts:105–117`, `:588`; `runtime-process.unknown-events.test.ts` | yes | `:36` is the verbatim-logging test |
| `index.ts:903`; `session-identity.ts` (`sessionStartMs`) | yes | `:37` |
| `env-server.ts:415–420` | yes | |
| `c2_fail` "handed `st`" | yes | one caller, `:2437` |
| `ExecutionUnderTest` literal sites | n/a | `scripts/dst/invariants_dst.ail:385` (literal), `:1008` (update); bridge `dst_execution.ail:112` |

## Required changes (a v6.1 line pass)

1. D1/D4: `first_kept: Option[int]`, `None` at HEAD; rule 3 reads prefix, replacement messages, then every later history entry (`phase_vocab.ail:263–281`, `:349–366`).
2. D1/D6: the seed after a `resumed` entry with a changed prompt is journaled as a `history_replaced` with the new head; the host's check otherwise compares `seed.digest` with the last `digest_after`, computing no digest itself.
3. D8: decide whether `HistorySeeded`/`HistoryAppended` land in P1 or P1's fixture asserts `suspended.history` directly; delete "untouched" at `:106–107`.
4. D4: `final` at all seven terminal arms via a `c2_finalize` parameter (`session.ail:2206`, `:2429`, `:2482`, `:2551`, `:2758`, `:2765`, `:2873`); one fixture literal and the bridge gain the field.
5. D2/D4: replace the `history_valid_transcript` justification with the provider's pairing requirement and the digest chain; add an explicit pairing check to the fold (`phase_vocab.ail:106–112`).
6. D3: the `exit` entry from the process-exit hook is a synchronous append (`herdr-agent-state.ts:348–350`).
7. D4: state the per-append digest cost or adopt an incremental digest.
8. D4/handoff: "red from P1 Part 4 until the events land", not "red at HEAD".
