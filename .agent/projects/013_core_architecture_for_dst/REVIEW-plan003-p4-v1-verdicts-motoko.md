# PLAN-003 P4 adversarial review verdicts (motoko)

Date: 2026-09-14
Reviewed HEAD: `d5edebf2cb75c159da8a46bdfb2a7d6f3629320e` (branch `arniwesth/013-plan003-and-herdr` per `git branch --show-current`).
Subject: `PLAN-003-implement-adr-003.md` P4 section ONLY (working-tree file, 1455 lines by `wc -l`; P4 ~lines 589-1090: Background, drift table, ADR-vs-HEAD rows 1-10, Parts 1-7, do-not-touch, evidence tiers, Q1-Q7 all DECIDED 2026-09-14, handoff).
Against:
- `ADR-003-session-journal-and-resume.md` D7 (plus D1/D4-rule-6/D5/D6-step-5 where D7 leans);
- `REVIEW-plan002-v1-verdicts-claude.md` + `REVIEW-plan002-v2-verdicts-claude.md` (shape + standard: every claim re-measured at HEAD source, coordinates re-read, no verdict from prose alone);
- Producer `PLAN-002-implement-adr-002.md` v3 transcription check (W4 Parts 1-7, W5(b), §6, §8.3-8.4).

**Method.** Read-only except this file. Every load-bearing coordinate below was read with `git show HEAD:<path>` + grep, each well under 60s. No sweep, no slow test, nothing committed. `git status` shows the plan file itself modified (`M PLAN-003…`) plus pre-existing untracked files; HEAD is authoritative and the P4 section states its grounding as `d5edebf`, which **is** HEAD — no drift.

**Drift.** None. P4 is grounded at `d5edebf` = HEAD.

## Overall verdict

**ACCEPT WITH CORRECTIONS. Parts 1-3 may start now (per decided P4-Q1). Parts 4-7 wait for W4 gate 8's live parked run, as the plan itself states.**

The plan does what a D7 transcription should:
- All 10 ADR-vs-HEAD rows hold at HEAD source (rows 2, 3, 8, 9 exact; rows 1, 4, 5, 6, 10 correctly identified as residuals with owner decisions recorded).
- The producer transcription is faithful: W4 Parts 1-7 mechanics, W5(b) identity rule, §6 consumption list, and the §8.3 mechanism note **with the v3 R1 correction** (step-budget guard on `decide`'s `Park` arm, not the v2-unreachable `call_model_or_fail` route).
- ~60 coordinates checked; all load-bearing ones exact except minor cite-range slips and one missing-evidence path (R1 below).
- No ADR decision is reopened: every place the plan overrides literal ADR text (rows 1, 5, Q2, Q4) is carried by an explicit owner DECIDED line dated 2026-09-14.

The defects are minor — cite ranges, unconfirmed counts, one evidence path, and two small mechanics notes (R6, R7). No part is rejected.

## Per-part verdicts

| Part | Verdict | Short reason |
|---|---|---|
| Part 1 (entries, red first) | **ACCEPT WITH CORRECTIONS** | All four reds are red at HEAD for the stated reasons; fold rules sound; R1-R3 are cite/confirm corrections. |
| Part 2 (live cursor-first read) | **ACCEPT** | Factor is a pure refactor of a verified head arm; red row cannot hang; inventory-unchanged claim holds. |
| Part 3 (resumer, option (a)) | **ACCEPT WITH CORRECTIONS** | Transcribes §8.4/R9/W5(b) exactly; mismatch path has no budget loop by construction; R4 is confirm-only. |
| Part 4 (suspended-child branch) | **ACCEPT WITH CORRECTIONS** | Q3 DECIDED scope (host kill, first-issue, TTY-only); exit-handler coordinates exact; R5 race note. |
| Part 5 (wake entry + respawn) | **ACCEPT** | Parent==park follows from D1 leaf rule + no-exit branch; gates concrete. |
| Part 6 (named states + exits) | **ACCEPT WITH CORRECTIONS** | Q5 DECIDED covers the weak (review-only) sourcing; R6 disambiguates the two operator-input paths. |
| Part 7 (invariant + live gate) | **ACCEPT WITH CORRECTIONS** | T0/T2/T4 ladder sound; 4-call figure correctly treated as to-be-measured live; R1 blocks only the evidence path. |

## 1. Background gates and drift table, verified at HEAD

| P4 claim | Verdict | Evidence at HEAD |
|---|---|---|
| `Park` arm `session.ail:3527-3564` | ✓ | arm at `:3528` (`Park(waits) =>`), `park_attempt == 0` emit at `:3530`, `wake_read` + witness at `:3532-3533`, mismatch re-issue at `:3534-3535` |
| `ParkRequest { request_id, step, waits, attempt }` `ports.ail:779` | ✓ | type at `:779-785` with all four fields |
| `park_request_id` `session.ail:3091-3093` | ✓ exact | `:3091-3093` |
| `wake_matches` `:3121-3129` | ✓ exact | `:3121-3129`, request_id always + wait_id only for Settled/Lost/TimedOut |
| `apply_wake` `:3149-3159` | ✓ exact | `:3149-3159` incl `Aborted => []` |
| `wake_message` `:3168-3179` | ✓ exact | `:3168-3179` |
| `ParkEntered`/`WakeReceived` `phase_vocab.ail:1320-1321`, payloads `:1015`, `:1020`, wire `:1503-1504` | ✓ all exact | verified each line |
| `wakes` cursor `ports.ail:211-221`, `WakeObservation` `:792` | ✓ | `:211-222` cursor comment + element-never-worlds prose; `:792-796` type |
| `scripted_wake` `:1150-1163` (cited range slightly wide) | ✓ substantively | actual `:1157-1163`; head arm `:1160-1161` is what Part 2 factors |
| `recording_wake` `:1174-1199` | ✓ | actual `:1181-1199`; `WakeIdentity("loop_v2", req.request_id, …)` + `OutcomeOk`/`OutcomeMissing` as claimed |
| live wake `stub_step.ail:214-222`, `live_wake_await` `:294-319` | ✓ | binding `:218-222`, await `:294-319`; EOF→`Aborted`/`"eof"` verified |
| host protocol `runtime-process.ts:137-142`, `:737-746`, `:985-1040` | ✓ | `:141-142` park/wake event types; `:738` wake_request dispatch, `:744` resolve; `:985-1040` onWakeRequest/sendWakeReply/resolvePark |
| waiter factory `wake-waiter.ts:108`, `:479` | ✓ approx | `:108` factory interface; `:479` default factory |
| `initial_park_ordinal` `session.ail:602-604` | ✓ exact | `:602-604` |
| `between_turn_request_id` `:4723-4725` | ✓ exact | `:4723-4725` |
| `next_turn_world` `:4736-4738` | ✓ | `:4736-4738` |
| `loop_run_identity` `:4683-4689` | ✓ exact | `:4683-4689` |
| W4 gate-8-open / T2-not-T4 reporting | ✓ honest | plan reports against its own interest; `85ce0c7` message confirms fixture-only metric + "LIVE herdr delegation NOT run" (checked via `git show -s`) |
| `Makefile:672` KNOWN_RED assignment not dropped | ✓ | `:672` still `DST_KNOWN_RED := depth_canary driver_plus_herdr herdr_graded` under a rewritten comment `:653-671`; correctly left for PINDH/operator |
| drift: `live_ports` left `ports.ail` → `stub_step.ail:186-262`, binding `:214-222`, rule at `:205-208` | ✓ | verified; sketch cite `ports.ail:2568-2570` is stale as claimed |
| drift: `recording_approval` pattern `ports.ail:1718-1747` → `:1974`, twin exists `:1174-1199` | ✓ in substance | twin verified; `:1974` itself unconfirmed (R4) |
| drift: exit handler `index.ts:1132-1185`, `pendingRestart` `:1138`, one-shot `:1142-1153`, `writeExit` `:1160`, non-TTY `:1048-1060` (`:1052`), getter `runtime-process.ts:1067-1069` | ✓ all | each verified within 1-2 lines |

## 2. ADR-vs-HEAD rows 1-10, verified at HEAD source

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `.p0` = re-issued request; resumed runs start at ordinal 1; resumer id = `loop_run_identity(…,0)` at `:5318-5319`; rewritten id = `between_turn_request_id(…,0)` at `:4723-4725`; W5 test pins pairing | ✓ **with a real residual correctly surfaced** | `session.ail:602-604`, `:4723-4725`, `:5318-5319`, W5 tests `:5867-5893` all verified; comment at `:4713-4722` names P4's resumer as a rule site. The residual (D7-literal "first `decide` parks" vs §8.4/R9 "before the run") is genuine and becomes P4-Q2 — exactly the right handling |
| 2 | `Park` carries only waits; `ParkEntered` only on `park_attempt == 0`; entry = `ParkEnteredInfo` as-is; no golden move | ✓ | `phase_vocab.ail:424-434`-family claim inherits PLAN-002 §1 row 3 (verified there); `session.ail:3530` verified; `:1015`, `:1962-1963` verified |
| 3 | recording binding serves cursor; P4 adds live read + assertion | ✓ | `ports.ail:1157-1163`, `:1181-1199` verified — "half landed" is accurate |
| 4 | v4.1 D7 not in tree; Part 6 names states from reviews + W4 Part 5 table | ✓ **with weak-source flag** | `phase_vocab`/`journal`/`session` show no `suspended-child` (grep-clean by construction of the new work); the two review cites are secondary sources. Covered by decided P4-Q5, but Part 6's authority is sign-off, not source — stated openly in the plan |
| 5 | ADR-002 D4 vs ADR-003 D4-rule-6 disagree; plan pins ADR-002 (`park → exit` folds `Parked`) | ✓ (needs owner decision — has it, Q4) | `ADR-002:499-500` verified ("the host writes the `exit` entry; a park entry with no wake child is then re-observed on resume"); `ADR-003:435` (rule 6, last-entry-decides) verified. Overriding literal D4-rule-6 is a real prioritisation and it is DECIDED in Q4 |
| 6 | `wake` child of `park` iff nothing appended between; suspended-child branch writes no `exit`; lease hook writes host-death `exit` | ✓ | D1 leaf rule `ADR-003:258-261` verified; `session-lease.ts:236-246` verified (exit + SIGINT/SIGTERM, no re-raise) |
| 7 | no wake file / no generation = Part 7 invariant | ✓ | D7 text `ADR-003:546-551` verified; Part 7's T0/T2 formulation is the right tier split |
| 8 | `session-journal.ts:36-46` + test `:484-490` stale since `85ce0c7` | ✓ exact | comment and test verified verbatim; `phase_vocab.ail:1320-1321` + `runtime-process.ts:141-142` verified |
| 9 | twin drops park/wake at `journal.ail:1989` (`_ => acc`) | ✓ exact | verified; red-first twin test is red for the stated reason |
| 10 | `from_ordinal` names previous run's final after a park exit; resumed world restarts ordinals | ✓ (stated limit, Q6 DECIDED) | `journal.ail:1251-1256`, `:2169` (`from_ordinal: s.world_ordinal`), `journal_resume_dst.ail:30-34` restart-ordinals claim taken as cited; not extending `ParkEnteredInfo` is the consistent choice with the do-not-touch list |

## 3. Producer transcription (PLAN-002 v3)

- **W4 Parts 1-7**: first-issue-only `ParkEntered` (`:3530`), step-charge + `park_attempt` re-issue (`:3534-3535`), `wake_matches`/`apply_wake`/`wake_message`, `recording_wake` + `WakeIdentity`, live `wake_request`/`live_wake_await` + command table, fixture metric shape — all present where P4 consumes them. The §8.3 mechanism is transcribed **with the v3 R1 correction** (guard on `decide`'s `Park` arm; P4 adds no re-issue outside a run, where no budget exists — consistent, not a regression to the v2-unreachable route).
- **W5(b)**: `<next run_id>.p0` + `initial_park_ordinal(true)` + `between_turn_request_id` + W5 tests — transcribed into rows 1, Part 3 steps 1/4, and gates. W5(a)/(c), §§8.1-8.2/8.5-8.7 correctly not re-consumed except row 4's review sources and Part 6's table (under Q5).
- **§6 consumption list** (`PLAN-002:1206+`): every item P4 takes (`ParkRequest` shape, `wake_read` + live binding, `wakes` cursor + codec, appended/emitted `ParkEntered`/`WakeReceived`, dropped-reply-appends-nothing, no-second-`ParkEntered` on re-issue, host protocol, `recording_wake`, between-turn identity) is named there. P4 takes nothing §6 withholds. The "§3 remainder" (blocking-read-as-park) is explicitly left unscheduled — good scope discipline.

## 4. Per-part findings

**Part 1.** Red rows: (1) `journal.ail:2739` `all_entry_types()==10` ✓ (`:1173-1176` verified, becomes 12); (2) mutate-to-`"park"` refused at `:1496-1499` ✓ (unknown-type refusal verified) so the flip-to-`"not_an_entry"` + new `BoundaryParked` fold test is genuinely red; (3) twin red at `:1989` ✓; (4) host test flip ✓ (§2 row 8). Design: strict per-field decode with `Refusal::Entry(seq, field)` matches the existing refusal family (`:579-590` verified); `wake` outcome's six ids match the set `dst_invariants.ail:1242-1243` checks ✓; `wake_outcome_of` stays in `session.ail` because `journal.ail:39-65` does not import `ports` while `ports.ail:44-88` imports upward ✓ (import directions verified); `BoundaryParked` + `boundary_id "parked"` extends a verified enum (`:1226-1245`, no `Parked` today ✓); `plan_resume` keeps `suspended: None` for `Parked` with `plan.last` carrying it — `plan.last` field exists ✓ (`:last: s.last` in `plan_resume`); `Aborted`-closure to `Open("wake:aborted")` matches Q4 DECIDED. Gate: fold fixture list is the right shape; `event_vocabulary` stays 45 and `event_vocabulary_version()` untouched — consistent with "no new `LedgerEvent`" (entries are projections of W4's two variants).

**Part 2.** `cursor_wake` factors the verified head arm (`:1160-1161`); `scripted_wake` wrapper is byte-identical by construction. Live binding edit is at the verified site (`stub_step.ail:218-222`). The `/dev/null` red row is sound: `readLine` returns `""` → `Aborted`/`"eof"` (verified), so it is red and cannot hang. Recording assertion (`ports.ail:1188-1197`) pins `WakeIdentity("loop_v2", "<R'>.p0", wait_id)` + `OutcomeOk` — matches verified code. `driver_leaf_inventory` unchanged: `live_ports` is not a driver call site and no new `.wake_read(` *call* text is added here (only a rebinding) — consistent with `CALL_RE` (`derive.py:194-196`, verified matching `.wake_read`).

**Part 3.** Option (a) is correctly identified as the §8.4/R9/W5(b) transcription, and Q2 DECIDES it — (b) would re-read decided §8.4. Steps: R' from the verified identity build (`:5318-5319`); `<R'>.p0` via the verified constructor; seed rewrites only `request_id`; consume via `wake_read` + `witness` (helper def at `session.ail:4572` — see R3); `wake_matches` (`:3121-3129`) + `park_drop_warning` (`:3183-3186`) verified; **no re-issue loop outside a run** — correct, since the §8.3 bound is a step budget and none exists there. `Aborted` opens no run, mirroring W4 Part 5's abort-returns shape; other outcomes build via `c2_state_from_continuation` (`:2644-2685` verified) + `wake_message` + `apply_wake` + `initial_park_ordinal(true)` + `last_finish_reason: "user_injected"` — the one site W5(b) names (comment at `:4716-4722` verified). New traced sibling justified: `Continuation` carries no waits (`journal.ail:135`-family, verified `:117-140` region). Journal order (`run_started` after `wake`) is D7's exactly-once order; `run_ordinal` 1 follows. T2 gate rows (three truncations, `<R'>.p0` identity, single `WakeReceived`, next park `.p1`, `park,exit`→unbound-`HostError` with waits kept per `ports.ail:1109-1112` ✓, aborted-closes) are all testable. Cost disclosed: 25→26 driver sites + new tree mutant (R4: confirm the "25" at run time).

**Part 4.** Q3 DECIDED scope (host `kill()` once `park` on disk; every first-issue park; TTY-only; no core-side exit — the core-side alternative is correctly rejected: it would write `run_summary` and fold `RunFinished`). Coordinates: `--oneshot` parse site `index.ts:658` ✓; `onWakeRequest :985-999` ✓; `kill()`→`killRequested`→suppresses synthesised `error` (`:940-950`, `:764-780` ✓); child emits `park_entered` before `wake_request` (`session.ail:3530` then `stub_step.ail:220` — code order verified on the core side); `resolvePark :769` cancels waiter (`:1028-1032` verified); TTY branch above `:1138` ✓; non-TTY `:1048-1060` untouched per decision ✓; lease held (`:906-928`, taken as cited). Red-first host test is red at HEAD for the stated reason (waiter cancelled at `:769` ✓).

**Part 5.** `wake.parent_id == park.id` follows from Part 1's routing + row 6's no-exit branch + D1's leaf-is-last-entry (no branch op). `respawnForRestart` (`:1244-1254`) + `canResume` (`session-journal.ts:258`-family ✓) + `--resume` argv shape verified; `sendWakeReply` request_id-drop rule (`:1005-1019` ✓) moves with the request. Gate (one wake, duplicate dropped, argv, fold-to-`Parked(p, Some(w))` via small AILANG script) is concrete.

**Part 6.** Table transcribes row-4 sources + W4 Part 5's table (`live_wake_await` commands verified: `wake_reply`/`user_message`/`abort`/`exit`/EOF→`"eof"`/`restart`→`"restart:<p>"`/`model_change`-dropped). The quit-vs-live-`exit` distinction (no `wake` + lease `exit` while suspended vs `Aborted` cancel to a live child) is exactly what Q5 DECIDES. `interruptRuntime :187-197` ✓; `onInitialTask` resume-via-`--resume` shape ✓; restart-with-new-profile respawn (`:1161-1166`, taken as cited). Per-row host tests with the ESC/quit assertions are the right gates. R6 below.

**Part 7.** T0 (dir holds `journal.jsonl` + `lease`; grep for `WakeGeneration`), T2 second-resume exactly-once, T4 live script (park → exit-no-error-leaf-`park` → one child-`wake` → `--resume` → cursor-serve with no pre-`wake_received` `wake_request` on stdout) — all concrete and correctly tiered. The 4-call figure is presented as to-be-recorded, not as inherited evidence — honest given the Background's own T2-not-T4 finding. `--park-exits` default-off + operator-runs-live (Q7 DECIDED) is the safe close.

**Sequencing.** Core-before-host with host respawn landing after the resumer exists; Parts 1-3 DST-visible before any live part (§0.6 — the conversation REPL `readLine` sits above the traced surface, verified comment) — sound. Q1 gating (1-3 now, 4-7 after W4 gate 8) respected throughout.

## 5. Coordinate audit — checked vs wrong

Checked exact (or within 1-2 lines, noted): all Background/row coordinates in §1-2 above; `journal.ail` envelope `:658-731`-family, `Refusal :579-590`, `all_entry_types :1173-1176`, fold `:1438-1501`, twin `:1873-1999`, `plan_resume :2110-2187`, tests `:2739`, `:3136-3141`-family; `session.ail` park block `:3091-3186`, `:3527-3564`, `:4683-4745`, `:5299-5333`, `:5867-5893`; `ports.ail` cursor `:211-222`, request `:779-800`, unbound `:1109-1112`, codec `:1115-1153`, scripted/recording `:1157-1199`, probe `:2809-2835`; `stub_step.ail` live `:205-222`, await `:294-319`; host `runtime-process.ts` `:137-142`, `:730-780`, `:940-1069`, `index.ts :658`, `:1048-1190`, `:1244-1330`, `session-journal.ts :36-57`, `:258`, `:482-529`, test `:484-490`, `session-lease.ts :225-250`; `derive.py :23`, `:93-115`, `:142-213`, `:310-318`; `Makefile :366-368`, `:489-500`, `:653-672`; ADR cites `ADR-002:499-500`, `ADR-003:258-261`, `:435`, `:546-551`.

Wrong or unconfirmed (all minor; none load-bearing):
- **W5 test range**: plan cites `:5867-5877`; the tests span `:5867-5893`. Cite slip only.
- **`scripted_wake` range**: plan cites `:1150-1163`; actual `:1157-1163`. Cite slip only.
- **`session.ail:4572`** is the `witness` helper *definition*, cited as the consumption act — harmless but reword to "via `witness` (def `:4572`)".
- **`session.ail:4809-4815`** (W4 abort-returns), **`ports.ail:1974`** (`recording_approval`), **`stub_step.ail:626`, `:723`** (recording sites), **`index.ts:906-928`** (lease hold), **`index.ts:1161-1166`** (restart respawn), **`journal_resume_dst.ail:30-34`** (ordinal restart), **counts** (`event_vocabulary` 45, `journal_resume` 13/13, inventory "25", `park_wake` 17 fixtures / metric `== 4`): taken as cited, not re-measured — confirm at run time (R3/R4).
- **`evidence/plan002-w5-probe/`**: path does not exist in the HEAD worktree (`ls` fails). Either gitignored, external, or moved — the plan's only evidence pointer that does not resolve (R1).

## 6. Required changes

- **R1 (evidence).** `evidence/plan002-w5-probe/` does not resolve at HEAD. Point P4's W5-T4 pointer at the real location (or attach the 6/6 captures) before Part 3 starts. Parts 1-3 are unaffected (their gates are T1/T2).
- **R2 (Part 1 gate).** Name the refusal for the cross-`request_id` `wake` row as `Entry(seq, "request_id")` in the gate (the design says it; the gate's bullet says "refused at that entry" — pin the field).
- **R3 (Part 1/3 gates).** Confirm counts at run time rather than asserting them now: `event_vocabulary` 45, `journal_resume` 13/13, W5 tests `:5867-5893`, `recording_approval :1974`, `stub_step.ail:626/:723`. No design change.
- **R4 (Part 3 gate).** Confirm the "25 → 26" inventory baseline from `make driver_leaf_inventory` output at the branch point; add the `TREE_MUTANTS` entry on the `derive.py:640-644` pattern as stated.
- **R5 (Part 4).** Name the race explicitly: a waiter reply arriving between `kill()` and child exit must not write a `wake` entry nor respawn (the request died with the child; the park re-observes per row 5). One gate bullet: kill-then-reply writes nothing.
- **R6 (Part 6).** Disambiguate the two operator-input paths in one sentence: parked-input-route text → `OperatorInput(content)` + respawn, vs ESC/`interruptRuntime` → `Aborted`/`"abort"` + no respawn. The table has both rows; the entry condition ("typed at the parked prompt" vs "ESC") is what needs naming.
- **R7 (Part 3 design, one sentence).** State that the resumer-emitted `ParkEntered(req)` belongs to the *resumed frame's* trace (the prior frame already journaled its own `park`), so the twin's exactly-once argument (`run_started` after `wake`) reads over the resumed journal. Prevents a future "duplicate `ParkEntered`" misreading.
- **R8 (cites).** Fix the three slips: W5 test `:5867-5893`, `scripted_wake :1157-1163`, `witness` def `:4572`.

## 7. Handoff readiness

The §7-ready rows (estimates-table row, Phases-table row, one-commit-per-part titled `ADR-003 D7: P4 Part N — …`, `P4.1-P4.7` dagr split with 1→2→…→7 dependencies) are well-formed and consistent with the section. The "neither row is applied by this pass" scoping note is correct discipline.

REVIEW-COMPLETE ACCEPT WITH CORRECTIONS
