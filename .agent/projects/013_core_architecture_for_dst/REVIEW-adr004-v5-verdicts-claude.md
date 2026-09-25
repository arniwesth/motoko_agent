# ADR-004 v5 — adversarial review

Date: 2026-09-15. HEAD: `55f110093835c8081cc5ee2b669db94970224fd8`. Branch: `arniwesth/013-plan003-and-herdr`.
The ADR under review is v5 at commit `21c1728`; its code pin is `3920814`.

**Reviewer: claude (Claude Fable 5.1), not Codex.** Codex is not available in this container. Per the
operator's delegation orders (PLAN-004 §2 `V5R`, delegate task `mot-dlg-1789505227559`) this round was
run with claude, and the file is named `-claude-` rather than `-codex-` so the provenance stays honest.

Subject: `ADR-004-journal-as-evaluation-source.md`, proposed v5, including its nine v4→v5 retractions,
the ⟨v5⟩ answer table and D1–D8. Prior: `REVIEW-adr004-v4-verdicts-codex.md` (nine required changes at
`:282–292`), read in full together with `BRIEF-adr004-v4-review.md`, `BRIEF-adr004-v5-review.md` and
PLAN-004 v1.2 (§0, §2 `V5R`, §3 P1.1/P1.4b/P1.5–P1.7b/P1.9a/P1.9b, the M-matrix and M15, §4 P3.2, §5).
**ADR** coordinates refer to the v5 document at `21c1728`; **v4 review** coordinates to the prior review.
Code coordinates are at `3920814`, read with `git show 3920814:<path>`. Bare module names mean
`src/core/<name>.ail`; `stub_step` and `scripted_ports` mean `src/core/test/`.

**Drift.** `git diff --stat 3920814 21c1728 -- src scripts Makefile tools` is empty, and `21c1728..HEAD`
adds only `scripts/eval/mem_guard.py` and `scripts/eval/test_mem_guard.py` (P2.1, `55f1100`). Every code
coordinate at `3920814` is therefore also HEAD's; no stale line number had to be resolved.

Method: read the whole v5; re-read every coordinate v5 cites at `3920814` (`S5/pin/` holds the blobs);
traced the loop's result classification, `decide`, the suspension and finalize arms, native/built-in tool
dispatch, policy initialisation and context resolution, the recording adapters and their dependencies,
replay comparison and reconstitution, manifest construction and validation, the witness, the invariant
bridge and `family_evidence`, the scan rules, the anchor and inventory tooling; recomputed the historical
`recording_ports` hashes under the v4 review's rule and under plain line ranges; verified the five
line-neutral joins and every anchor pin; reused the v4 review's scan counts (`S4/scan_v4.txt`, counts and
indices only). No `make dst`, replay, prototype, profiling, `ailang` execution or type-check, commit, pane
operation or agent was run (a `make dst DST_JOBS=1` sweep was running; memory is contended). Only this
document was written inside the repository.

Evidence directories:

- **S5** = `/tmp/claude-1001/-workspaces-motoko-agent/7d4cdf9a-dc4e-4513-844b-624f1b7c18ca/scratchpad/review-v5/`:
  `audit_v5.py` → `audit_v5.txt` (hashes, line counts, anchors, joins, call sites, commit facts),
  `scan_v4_counts.txt` (the prior scan's count lines, no content), `pin/` (the blobs).
- **S4** = `/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review-v4/`
  and **S3** its sibling `codex-review/`, the v4/v3 reviews' evidence, read only.

## Overall verdict — ACCEPT WITH CORRECTIONS; PLAN-004 v2 may be written against v5

All nine required changes of the v4 review are addressed with decision text and the contract or test
each implies, and every ⟨v5⟩ marker of PLAN-004 §5 has an answer in the decision it belongs to. The three
returned mechanisms now hold against the code: the stopping contract is a classification over the
recorded call's shape whose reachable-but-cut shapes are named and whose settings are pinned to the
reads that make each arm unreachable (`session:4020,4058–4066,3267–3305`; `step_machine:102–159`;
`context_usage:139–150`; `exit_manifest:202–203`; `session:3878`); the witness is built from the
candidate's own trace, queues and worlds and the invariant bridge is called with the real eight-argument
signature, the thirteen actual families and a separate census (`dst_discovery:224–237,260–310,529–545`;
`dst_execution:100–126`; `dst_invariants:228–247,1570–1579,2043–2067`); and the control is a same-basis
revert of `de4b4f5`, which touched only `phase_vocab.ail` (10+/7−) and is an ancestor of `3920814`
(`S5/audit_v5.txt`). D1's `2N + 1` / `2N` decision count is right: one `DecisionRecord` per `decide`
(`session:790–791,3338–3339`), counted by `count_decisions` (`dst_invariants:1521–1527`).

What remains is textual: a wrong parenthetical in D1's `Parked` row, a private helper named as if the
seam called it, hash values attached to line ranges they were not computed over, an over-broad header
sentence about drift, and a closure list presented as the closure. None changes a mechanism, a count or
a test; each is listed under "Corrections" with its replacement. No v6 is required.

## §1 — Disposition of the changes and retractions

### 1.1 The nine required changes of the v4 review

Numbers refer to **v4 review:284–292**.

| # | Disposition | Evidence and remaining issue |
|---|---|---|
| 1 — Branch-complete call shapes; hybrid predicate enforced; blank stop cut; `StopBeforeEnd` as post-turn exception | **ADDRESSED** | Six-shape procedure with the tool-branch predicate `finish_reason == "tool_calls" \|\| n_calls > 0` (`ADR:629–671`; `session:4020`), `last_finish_reason: "tool_calls"` with nothing pending (`:4045`), fall-through at `step_machine:159`; blank stop traced through stages 2–5 (`session:3267–3305`) to `EmptyStopFinalize`/`DoneEvent` (`:3378–3397`); predicate asserted once, monotone (`:2134–2140`); `StopBeforeEnd` keeps call k, recomputes N and end, cause withdrawn (`ADR:707`; `session:3354–3405`). One wrong parenthetical in the `Parked` row (§3.1, C1). |
| 2 — Pin `EXIT_MANIFEST`/`CAPTURE_FAILED_PAYLOAD` empty; explicit `PROFILE_DIR` + `FsFile`; encoding; separate columns | **ADDRESSED** | Both keys `""` in every environment (`ADR:616–617`); `publish_exit_manifest` returns before any write when `dest == ""` (`exit_manifest:202–203`), the read is `session:5066` reached only from the `Finalize` arm on the traced path (`:3398`; the other three callers are conversation entries, `S5/audit_v5.txt`); capture read at `:3878`, write at `:1050–1057`. `profile_dir_path` reads `MOTOKO_PROFILE_DIR` first (`context_usage:139–143`) and the exact key `.motoko/eval-profile/config.json` is what `config_context_limit_override` requests (`:178–181`) through `scripted_file`/`lookup_file` (`ports:1335–1364`; `context_reader_of`, `:1070–1071`). Encoding: `n > 0` → `ProfileWindow` (`:187–188`; `context_limit:129–132`), `"disabled"` → `declares_disabled` (`:168–175`, `:145`). Three columns in D3's table (`ADR:958–971`). |
| 3 — Candidate witness from C's trace/worlds; prepared-digest qualification; prepared ≠ recorded mutation | **ADDRESSED** | K3 (`ADR:1033`): `provider_calls` from C's `ProviderCallPrepared` count, dispatches from C's queue lengths, clock from C's worlds, then the three counts compared with the entry separately; digests not consulted, count is. M14's mutation named (`ADR:327`). `check_discovery`'s class balance is what makes N+1 prepared / N recorded fail (`dst_discovery:532–533`). |
| 4 — Obligation, metadata, separate budgets; real families + census; vacuity tests | **ADDRESSED** | `execution_of(run, epoch, NoReplay, decisions, 0, 0, [], replay_metadata_of(manifest))` matches the eight parameters (`dst_execution:100–109`); `NoReplay` at admission → only `ReplayConsistency` unevaluated (`dst_invariants:1753`, `:2057`), `StrictAgainst(program.interactions)` for C (`:599–602`, `:1754`); `replay_metadata_of` (`dst_profile:1582–1588`); decision bound `2N + 1`/`2N` derived, retry bound 0 (`ADR:988–995`; `bounded_progress_findings`, `dst_invariants:1570–1579`); `family_evidence` kept unchanged and a thirteen-row census beside it with the four words (`ADR:997–1024`; `:2043–2067`, `:1631–1640`). |
| 5 — Complete failure `TimedOutcome`; first-mismatch marker handling; `Location`; gathered provenance | **ADDRESSED** | Provider empty arm writes the harness's own exhausted record (`ADR:797–808`; `stub_step:488–505`; `ports:2522–2524`); tool empty arm mirrors `tool_outcome_record`'s `ToolFailed` arm field for field (`ADR:822–832`; `ports:2138–2139`; `dst_fault_catalogue:61`; `encode_tool_outcome :2577` exported). Marker: `ProgramExhausted` only on expected-log exhaustion (`dst_replay:374–379`), otherwise a projection/outcome mismatch at that position (`:357–367`), earlier mismatch first, explicit no-marker scan in A6/K6 (`ADR:849–858,939`). Typed `Location` (`ADR:1045–1048`). A9b gathers and cross-checks; `discovered_manifest`'s literals named as not a source (`ADR:891–898`; `strict_replay_dst:631–633`; `dst_driver_only:1097–1123`; `dst_profile:1535–1573`). One private name used as if callable (C2). |
| 6 — Protected closure; original-byte checker; execution/build/cache provenance | **ADDRESSED WITH CORRECTIONS** | Closure rule, member list, imports/type regions, what is deliberately not frozen, missing-member rule (`ADR:1126–1162`); checker hashes original bytes, borrows `strip_noise`/`func_spans` techniques but not their hashes (`ADR:1164–1180`; `check.py:62–73`; `derive.py:63–86,323–329`); execution provenance with three agreeing records and the effective lock (`ADR:1204–1219`; `ailang.lock:71–77`, an absolute path at `:75`). The list is presented as the closure while omitting transitive members (C5); the one-paragraph checker summary omits the literal-aware brace rule P1.4b's contract has (C6). |
| 7 — Control basis resolved | **ADDRESSED** | Same-basis primary control (`ADR:1232–1244,1385–1390`): `de4b4f5` → `src/core/phase_vocab.ail` only, 10+/7−, ancestor of `3920814` (`S5/audit_v5.txt`); obligations (i)–(iv) via PLAN-004 P3.2; historical `a6abda4` optional with its own manifest; a K0 refusal is not the rejection. Hash values right, span attribution loose (C3). |
| 8 — Scan: record r2.1's refusals and counts; body-16 as heuristic; every occurrence; `CredentialBearingName` report-only | **ADDRESSED** | Counts and indices equal `S4/scan_v4.txt` exactly (`ADR:1308–1315`): seed 694/16/44, four body-16 refusals at 1, 78, 86, 98 with maximum run 24; tool outputs 299/4 (0, 96, 195, 228; body 6)/10; scripts 0. Heuristic with false negatives/positives stated (`ADR:1300–1306`); every occurrence enumerated against `scan_text`'s first-prefix behaviour (`dst_secrets:225–229,337–347`); `CredentialBearingName` report-only by explicit rule (`ADR:1295–1298`; `:353–359`); no entry named admitted (`ADR:1320–1321`). "Six tool outputs hold a qualifying path" matches `S3/evidence.txt:41`. |
| 9 — Claim/citation repairs | **ADDRESSED WITH CORRECTIONS** | Every §4 item of the v4 review is repaired (`ADR:386–397`): runtime-status callback `:3677–3681`, full witness `:260–310`, `family_evidence :2043–2067`, `execution_of :100–126`, `ported_provider :1532–1547`, `provider_api_model :272–293`, prototype `Ok(ms)` at `:153`, "corpus entry is the unit", "to be built", prototype attribution of the RSS figures. Remaining: the header's "every other cited module is byte-identical" (C4). |

### 1.2 The nine v4→v5 retractions

Numbers refer to **ADR:277–397**.

| # | Disposition | Evidence |
|---|---|---|
| 1 — Three unnamed shapes and the `StopBeforeEnd` rule | **ADDRESSED** | All four statements verified at `session:4020–4057,4058–4066,2126–2140,3267–3305,3378–3397,3354–3405`; `step_machine:123–159`. |
| 2 — Ambient effects; `CONFIG`/`REPO` counts; encoding; columns | **ADDRESSED** | `exit_manifest:202–223`; `session:5066,3398,3878,1050–1057`; `context_usage:139–150,168–195,241–250`; `context_limit:129–132,145`. |
| 3 — K3 from the candidate's run | **ADDRESSED** | `dst_discovery:529–545`; `ADR:1033`. |
| 4 — Eight-argument bridge; thirteen families; census | **ADDRESSED** | `dst_execution:100–126`; `dst_invariants:228–247,599–602,1631–1640,2043–2067`; `dst_profile:1582–1588`. |
| 5 — Complete records; marker; `Location`; provenance | **ADDRESSED WITH CORRECTIONS** | `stub_step:488–505` (v5 cites `:483–505`, which starts on a comment); `ports:2133–2145`; `dst_replay:357–379`; `strict_replay_dst:631–633`; `dst_driver_only:1097–1123`. C2 applies. |
| 6 — Closure, checker, provenance | **ADDRESSED WITH CORRECTIONS** | `ports:2133–2172,1851–1895,1305–1320,2855–2885,1335–1364`; `check.py:62–73`. C5, C6. |
| 7 — Same-basis control | **ADDRESSED WITH CORRECTIONS** | `de4b4f5` facts confirmed; hash values confirmed under the audit rule (§3.8); the line-range attribution is loose (C3). |
| 8 — Scan heuristic and counts | **ADDRESSED** | `dst_secrets:217–229,225–229,292–295,337–347,353–359`; `S4/scan_v4.txt`. |
| 9 — Claims and coordinates; `ParkOrWake` withdrawn | **ADDRESSED** | `686da16` touches `journal.ail`; `all_entry_types` has twelve types (`journal:1253–1256`), `ParkEntry`/`WakeEntry` (`:1179–1180`), the fold's wake refusal at `request_id` (`:1603–1614`), `BoundaryParked` (`:1316`). |

## §2 — Per-decision verdicts

| Decision | Verdict | Reason |
|---|---|---|
| **D1 — Extraction** | **ACCEPT WITH CORRECTIONS** | The classification procedure, cutoff/refusal tables, settings table and env pins all hold against the code (§3.1–3.2, §3.6). Correct the `Parked` row's parenthetical: the turn preceding a park is a call-free stop-class turn, not the turn whose handled tool opened the wait (C1). |
| **D2 — Admission run** | **ACCEPT WITH CORRECTIONS** | Guarded delegation, both fail-closed arms, the marker's handling and the program/manifest sketch are implementable with exported names only (§3.3–3.5). `provider_calls_in` is private and must be described as a quantity the evaluator recomputes (C2). |
| **D3 — Checks and verdict** | **ACCEPT** | Witness, env table with three columns, A8/K4 bridge inputs, decision count, census, `Location` and K-order all verified (§3.6–3.7). |
| **D4 — Claims** | **ACCEPT** | Whole-process scope with the fold inside it, prospective calibration, prototype numbers pin nothing (§3.11). |
| **D5 — Trust/identities** | **ACCEPT WITH CORRECTIONS** | Closure rule, checker contract, execution provenance, line-neutral commit and same-basis control are right (§3.8–3.9). State the hash span rule (C3); call the member list a starting set (C5); name the literal-aware brace rule (C6). |
| **D6 — Corpus** | **ACCEPT** | Counts match the prior scan exactly; heuristic limits stated; nothing admitted; report-only name axis explicit (§3.10). |
| **D7 — Fidelity ladder** | **ACCEPT** | T0's cumulative omissions now list the four new cuts and the two pins; T1 routes cite real entry points (`stub_step:817`; `session:4423–4442,4239,5394`; `journal:1679,2250`). |
| **D8 — Gate/sequencing** | **ACCEPT** | The revised per-check sentence and the M15 ruling are coherent (§3.12); the same-basis control is the demonstrated rejection; P2's guard landed at `55f1100` as an outside-`src/core` script, consistent with §0.5. |

## §3 — Mechanism checks against HEAD

### 3.1 Stopping contract, settings and reachable arms

**Shapes 1–6 are the loop's arms.** The tool branch is entered by `result.finish_reason == "tool_calls" || n_calls > 0` (`session:4020`); it journals the assistant, sets `last_finish_reason: "tool_calls"` and `pending_tool_calls: applied.pending_tool_calls` (`:4027–4055`). A call-free response with `finish_reason == "tool_calls"` therefore has nothing pending and `decide` falls to `call_model_or_fail` at `step_machine:159` — the next call before N, `Fail(StepBudgetExhausted)` at N (`:103–111`). Shape 3's cut is the right treatment; admitting it as a class would need a finish string the journal does not carry (`ADR:640–645`).

The else branch runs hybrid extraction first: `hybrid_tools && session_emitted_native_tool_call(msgs_with_assistant) == false` (`:4064–4066`); the predicate is true on the first assistant message with a call whose id does not start `hybrid-step-`, over the accumulated messages including the seed (`:2126–2140`), hence monotone, so asserting it once over seed plus appends before the first stop call is sound (`ADR:659–663`). `extract_bash` lives in `parse.ail:118`; it is outside the closure, and it cannot affect an admitted segment because the predicate is asserted true and `hybrid-step-` results are cut (shape 6).

**Blank stop.** `classify_candidate` skips stage 2 when `trim(candidate) == ""` (`:3267–3269`), stage 3 sees no open wait (`:3274`), stage 4's empty registry yields `NoDecision` (`ext/runtime:721–727,710–718`) and `should_inject_persist_nudge(0, …)` is false (`recovery:59–60`), so `CandidateApproved` (`:3296`); stage 5 calls the disabled verifier and gets `None` (`:3301–3305`; `:2241–2242,2287–2289`). `c2_dp7_approved_state` sets `dp7_approved` (`:3045`), `decide` finalises (`step_machine:149–150`), and the `Finalize` arm emits `EmptyStopFinalize` when `trim(info.output) == ""` and always `DoneEvent` (`:3378–3397`). Reachable, cut, as v5 says.

**Stop call.** `CandidateApproved` → `c2_dp7_approved_state` (`:4135–4136`) → `Finalize({ reason: "model_stop" })` → `c2_finalize(..., TermSuccess, ..., Ok(st.msgs), ...)` (`:3402`). **Suspension.** After call N's tools, `tools_complete` (`:2880`) → `call_model_or_fail` → `Fail` (`:103–111`) → `c2_suspend` (`:3351–3352`), which requires `continuation_history_ok` (`:2778–2779`; `journal:208`), emits `RunSuspended`, finalises with `TermMaxSteps`, `result: Err`, `suspended: Some(cont)` (`:2781–2794`). A6's expected ends are exactly these.

**Unreachable arms** all hold against the code: verifier rejection (`:2242`); solver feedback (`ext/runtime:683–691,721–727` with empty `entries`); nudge (`recovery:60`); `Park`/`AwaitApproval` (`open_waits: []` at `:1014`; only the `Handled` arm applies a lifecycle, `tool_phase:439–447`; native dispatch passes `open_waits` through, `:506`; the park arm needs a wait, `step_machine:141–148`; approval needs `await_approval`, `:127`); `TakeCheckpoint` (`checkpoint_enabled: false`, `:2376`); cost (`step_machine:112`; `max_cost_millicents: 0`); the built-in (`:3677–3681`).

**`StopBeforeEnd`** is coherent as the one post-turn cut: call k is a complete servable turn, the selector's end moves to its assistant entry, N and the expectations are recomputed and the expected end is `EndFinalize(model_stop)`; the live continuation is recorded, not explained (`ADR:707`; `Finalize` returns at `:3402–3404`).

**`Parked` (C1).** The row says "cut before the last assistant turn preceding the park entry (the turn whose handled tool opened the wait…)". The two turns differ. `Park` fires only when `last_finish_reason` is `await_wake`, `stop`, `dp7_approved` or `dp7_fail_open` (`step_machine:141–148`), all stop-class; `CandidateAwaitWake` is reached only from the call-free branch (`:4058` → `:3274` → `c2_await_wake_state`, `:3078–3079`). The wait was opened by a `Handled` tool on a strictly earlier tool-calling turn (`tool_phase:439–447`), after which the loop called the model again. So the turn preceding the park is the call-free stop call k; cutting before it ends the segment at call k−1 with `EndSuspended(k−1)`. `park.step` is `st.step_idx − st.park_attempt` (`:3528`), which with attempt 0 is the 0-indexed index of the call that would have followed — consistent with v5's sentence. Only the parenthetical is wrong. Dropping the stop turn rather than keeping it as a `StopBeforeEnd` is a defensible choice (the live classification was `await_wake`, not approved) and should be stated as one.

### 3.2 Runtime-status cutoff and other tool bypasses

The built-in callback tests exactly `call.name == "MotokoRuntimeStatus"` (`session:3677–3680`) and `dispatch_tool_entries_with_builtin` appends its message without policy, clock, env or `tool_exec` (`tool_phase:562–564`); its content is `prior_counts` plus trace counts and cache totals (`session:707,757–763`). Cutting before the whole turn is the right treatment. Every other name: empty policy entries merge to `NoOpinion` (`ext/runtime:402–406,426–434`) → the allowed arm (`tool_phase:608–615`); empty handle entries → `Delegate` (`ext/runtime:477–479,490–493`); `ohmy_pi = false` forces `Native` (`tool_phase:452`); `Native` reads the clock and `MOTOKO_TOOL_TIMEOUT_MS` then calls `ports.tool_exec` (`:484–492`). No other tool bypasses the queued seam on this route.

### 3.3 Guarded delegation, cardinality and projection replacement

`recording_ports` is exported (`stub_step:635–658`) and inherits `ports_shape_probe`'s bindings (`ports:2855–2885`), overriding clock, approval, wake, env, the three mutations, `tool_exec` and `ext_effect_exec` but **not** `file_read`, which stays `scripted_file` (`:2869`). The seam needs `record_interaction` (exported, `:1827–1843`; ordinal from `List.length(state.log)`), `ProviderIdentity`/`ToolIdentity`/`OutcomeOk`/`OutcomeFault` (`dst_interaction`), the codecs (`:2507–2524,2577`), `fault_class_tool_failed` (`dst_fault_catalogue:61`), `ToolFailed` (`ports:647–649`) and `ToolExecution = { outcome, next_state }` (`:653–656`). All exported.

Non-empty provider script: `recording_model_step` consumes one step and appends exactly one `ProviderIdentity` record (`stub_step:506–541`); the empty arm would append one exhausted record and return `Ok(terminal_step())` (`:488–505`), which the seam intercepts. Non-empty tool queue: `recording_tool` calls `world_tool`, whose scripted arm advances cursor and clock and classifies through `scripted_tool_outcome` (`ports:1745–1748,1775–1787`), and appends exactly one `ToolIdentity` record (`:2056–2068`); the empty arm is the live arm (`:1744`), which the seam intercepts. The driver's clock read is a separate port call (`tool_phase:484`), so "old log plus exactly one interaction" holds on every normal return of both delegates. Replacing only `request_projection` leaves identity, outcome, chunks, cursors and ordinal untouched; `world_state_of` reads outcomes and initial state (`dst_replay:831–874`), strict replay reads the projection verbatim (`:357–367`).

**C2.** `ADR:801` says `k = provider_calls_in(state.log, 0)`. That function is private (`stub_step:561`, no `export`; v3→v4 retraction 3 lists it as such). The seam must count `ProviderIdentity` records itself — the same quantity — and the text should say so. Also `{ recording_ports(rt) | model_step: eval_model_step(base), tool_exec: eval_tool_exec(base) }` with `base = recording_ports(rt)` constructs the ports twice; write `{ base | … }`. "Prefix byte-equal" over a `[Interaction]` value means structural equality.

### 3.4 Exhausted markers

`encode_exhausted_provider_outcome()` is `{"served":false}` (`ports:2522–2524`); `decode_provider_outcome` maps it to `ProviderScriptExhausted` (`:2540`) and `script_of` skips it (`dst_replay:689`). A marker at position p is `ProgramExhausted` only when the expected log has no interaction at p (`:374–379`); with an expected served interaction it is a projection or outcome mismatch (`:357–367`), and the walk reports positions in order, so an earlier mismatch is first (`:386`). A marker balances `check_discovery`'s provider class (one `ProviderCallPrepared`, one `ProviderIdentity` record), which is exactly why A6/K6's explicit payload scan is needed and is stated as independent (`ADR:939`). Correct.

### 3.5 Program and manifest

`driver_only_manifest` takes seven caller values and fills profile id/version, vocabulary and four rule versions, `scan_roots` and empty `extension_packages` (`dst_driver_only:1097–1123`). `validate_manifest` requires eight non-blank strings, two non-empty lists, the profile pair and five version equalities (`dst_profile:1535–1573`) — a shape check, as v5 says. `discovered_manifest` passes literals (`strict_replay_dst:631–633`). `InitialWorld.messages_and_policy` is an opaque string (`dst_program:182–188`); `validate_program` does not call `validate_bounds` (`:589–596,648–653`); `GeneratorBounds` has six fields including `chunk_draw_hi` (`dst_generator:308–315`). The sketch fills every `ExecutionProgram` field (`:243–252`). A9b's per-field comparators are PLAN-004 P1.6's table, which v5 adopts by reference.

### 3.6 Witness and env multiplicities

`DiscoveryWitness` is the six runtime fields plus the three mutations, `extension_effects` and `expected_env_reads` (`dst_discovery:260–310`); `driver_env_keys()` has the twelve keys of D3's table (`:224–237`); `env_balance` checks multiplicities of the supplied list (`:407–417`) and `env_keys_not_in_source` refuses any other key (`:542`). Per key, on the traced path (`run_v2_session_traced :4423` → `run_v2_from_messages_traced_with_policy :4442` → `run_v2_traced_from_seed :4420` → `c2_loop`):

| Key | Site | `EndSuspended` / `EndFinalize` / failure |
|---|---|---|
| `MOTOKO_PERSIST_RETRIES`, `MOTOKO_RETRY_STREAM_ERROR`, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS` | `session:2352–2355` | 1 / 1 / 1 |
| `MOTOKO_PROFILE_DIR` | `context_usage:140` (via `context_reader_of`, `ports:1070–1071`) | 1 / 1 / 1 |
| `MOTOKO_CONFIG`, `MOTOKO_REPO` | `:145–146`, only when the explicit value is empty | 0 / 0 / 0 |
| `MOTOKO_MODELS_FILE` | catalogue only on `ProfileMissed` or non-positive (`:241–250`) | 0 / 0 / 0 |
| `MOTOKO_SESSION_ID` | `session:1727`, called once at `:4301` on this path | 1 / 1 / 1 |
| `MOTOKO_TOOL_TIMEOUT_MS` | `tool_phase:485`, per native dispatch | T / T / T |
| `MOTOKO_EXIT_MANIFEST` | `session:5066`, from `:3398` in the `Finalize` arm only; the other three callers (`:4927,5208,5356`) are conversation entries not on this path | 0 / 1 / 0 |
| `MOTOKO_CAPTURE_FAILED_PAYLOAD` | `session:3878`, non-retryable failure only | 0 / 0 / 1 |

D3's table (`ADR:958–971`) matches every row. The clock balance compares the sum of recorded advances with the worlds' delta (`dst_discovery:540–541`; each `recording_clock` tick records its own advance, `ports:1851–1864`). `absent_classes` pins `RandomDraw` at zero and balances the mutation and effect classes against the witness (`:473–519`). The tool-message cap is idempotent (`cap_tool_message_content`, `phase_vocab:1559–1568`: `keep + marker == cap`), so a capped live result re-served from the queue yields the same bytes and A2/K7's byte equality is not disturbed.

### 3.7 A8/K4 bridge inputs, decision count and census

`execution_of` takes `(run, initial_clock_ms, replay, decision_budget, retry_budget, ambient_rng_reads, forbidden_effect_sites, meta)` (`dst_execution:100–109`); v5's A8 expression supplies exactly these. `NoReplay` makes `replay_findings` empty (`dst_invariants:1753`) and only `ReplayConsistency` unevaluated (`:2057`); `StrictAgainst` runs `strict_replay_findings` plus the unconsumed check (`:1754–1763`). **Decision count:** `decide` is called once per loop entry (`session:3338`) and one `DecisionRecord` appended before the match (`:3339`, `:790–791`), including for the terminal `Fail`/`Finalize`; `count_decisions` counts them (`dst_invariants:1521–1527`). A continuation call costs `CallModel` and `RunTools`; the end costs one more (`Fail`) or `CallModel` + `Finalize`: `2N + 1` and `2N` as v5 derives. `family_evidence` reports totals (`:2045–2066`) and `checkpoint_findings` is vacuous with no checkpoints (`:1631–1640`); the census rows name real trace records (`ParkEntered`, `WakeReceived`, `phase_vocab:1320–1321`; `StreamErrorRetry`, `session:3880`; `HybridBashExtracted`, `:4070`).

### 3.8 Protected regions, checker, control basis

The listed members exist at the cited lines (`ports:1827,2507–2553,2577,2608,1723,1775,2056,2133,2217,2165,2171,1851,1305,1871,1311,1315,1891,2855,1335,1356,1086,2020,1178,1201`; `stub_step:635,478,72,95,121,136,554,561,791,69`; `session:272–293,1532–1547,3824`; `dst_fault_catalogue:61–63,82–85`). **C5:** the list is introduced as "the dependency closure" but omits members reachable from listed ones: the codec helpers `tool_calls_json`/`tool_calls_of` and the JSON field readers (`ports:2514,2543–2550`), `live_tool_outcome` (`:1744`), `cursor_wake` (`:1179`), `scripted_file_write`/`scripted_file_remove`/`scripted_dir_make`/`scripted_path_stat`/`scripted_dir_list`/`world_ext_effect` and the four recorders `recording_ports` binds (`:2870–2874,2883`; `stub_step:642–658`), `provider_error_is_retryable` (`dst_fault_catalogue`, path-refused). v5 already says the closure is reviewed, generated by P1.4b and that a missing member is reported; the sentence at `ADR:1128–1131` should call the list a starting set. **C6:** the checker paragraph should carry P1.4b's literal-aware lexer clause — `${…}` interpolations put braces inside strings (`stub_step:494,522`; `ports:2064`) — since v5 says it adopts that contract.

**Hashes (C3).** `python3 S5/audit_v5.py`: under the v4 review's rule (from `export func recording_ports(` through the closing `}` and newline) the definition hashes `e6df6f20…` at `a6abda4` (lines 554–575, no `wake_read` binding) and `495d3c8f…` at both `d5edebf` (621–644) and `3920814` (635–658). The values v5 quotes are therefore right for `3920814`. But `sed -n 554,576p | sha256sum` gives `fa24f268…` and `sed -n 635,658p` gives `4555dd30…`; a reader recomputing over the cited line ranges will not reproduce the quoted digests. State the span rule beside the values, and note that P1.4b's rule (first byte of the first line to the matching brace) is a third span.

**Control.** `de4b4f5`: one file, `src/core/phase_vocab.ail`, 10+/7−, ancestor of `3920814`; the diff is inside `canonical_messages` (`S5/audit_v5.txt`). A revert on A leaves every protected span untouched, so the protected basis equals A's and the assembled identity differs, as D5 says. P3.2's (i)–(iv) are the right obligations.

### 3.9 Line-neutral variant edits

At `3920814`, verified by `S5/audit_v5.py`: `stub_step:69` is the one-line sum ending in a `--` comment; `session:195` is a one-line constructor import; `session:1545` holds the `GeneratedWorld` arm as the last arm with `}` on `:1546`; `ledger_parity_dst:73` is the import line; `:435` holds the `Ported` arm as the last arm with `}` on `:436`. All five joins are same-line edits. Anchors at `3920814`: `clock_now` on `session` 1471, 1730, 1842, 4302, 4523 and `tool_phase:484`; `now()` on `stub_step:203` (`anchors.sh:593,614–617`); the bridge span `1085–1474` (`derive.py:154`) contains neither 195 nor 1545. Line counts 915 / 6320 / 642. PLAN-004 P1.1's gate is achievable. This is a textual check; neither assembly was type-checked.

### 3.10 Contextual scan

`credential_value_prefixes()` has 23 prefixes (`dst_secrets:217–223`); `first_value_prefix` returns the first list entry contained in the string (`:225–229`) and `scan_text` reports that one only (`:340–342`); the alphabet is letters, digits and `+/=_.-` (`:292–295`); `opaque_run_threshold` is 32 (`:287`); `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo` are `:254`, `:261`, `:236`; `name_axis`/`scan_env_entry` `:207`, `:353–359`; `scan_interaction` `:431–437`; `redact_interactions` `:589`. v5's table equals `S4/scan_v4.txt` row for row, and the four short-body probes it cites are that file's last four lines. r2.1 is refused at its seed; nothing is admitted. The scan was not re-run (no corpus content was opened).

### 3.11 Measured process

D4 keeps the fold inside the profiled AILANG process for parent, control and candidate alike and calibrates fresh; the prototype's totals and deviations are labelled observations that pin nothing (`ADR:1103`). Consistent with the v4 review's §3.11.

### 3.12 D8's per-family sentence and the M15 ruling

The revised sentence splits the old one by vocabulary — refusal family (refused case + clean twin), cutoff (selector/N/end), check A1–A9/A9b and K1–K7 (failing case + twin, one per `ReplayMismatch` variant), seam arm, witness under/over-count and prepared ≠ recorded, census row zero-by-name + non-zero twin, one vacuous family (`ADR:1406–1419`). Each clause maps to an M-row (M1/M2/M13, M3, M9/M10/M14, M8, M11, M11, M11). The ruling (`ADR:1421–1436`) is coherent: a near-miss is the known-failing case for the check that catches it, proves the ordering assumption, and is not owed per refusal family, so M15's inapplicable rows are satisfied by their recorded reason; the park/wake row is settled by `Parked` being a cutoff and a wake-opened start being `ContinuationStart` (`journal:1595–1614`; `session:5531–5536,5577`); the `ProtectedRegionTouched` row is retained as the closure's regression test. The handoff's PSYNC deltas (`ADR:1504–1510`) list exactly those moves.

## §4 — Claim audit and corrections

### 4.1 Incorrect, unsupported or imprecise claims

| V5 claim/site | Correction and evidence |
|---|---|
| `Parked` row: "the turn whose handled tool opened the wait" (`ADR:697`) | The preceding turn is a call-free stop-class turn; the wait was opened on an earlier tool-calling turn (`step_machine:141–148`; `session:3274,3078–3079`; `tool_phase:439–447`). §3.1, C1. |
| "`k = provider_calls_in(state.log, 0)`" in a seam that uses "no private helper" (`ADR:801,840`) | `provider_calls_in` is private (`stub_step:561`). The evaluator computes the same count. C2. |
| Header: "every other cited module is byte-identical between the two commits" (`ADR:19–20`) | `tools/driver_leaf_inventory/derive.py` changed (+10 lines at `:642–654`, `git diff d5edebf 3920814`); its cited coordinates `:63–86`, `:154`, `:320–329` are unaffected. PLAN-004 §0.9 records it. C4. |
| SHA-256 `e6df6f20…` / `495d3c8f…` attributed to `a6abda4:…:554–576` and `stub_step.ail:635–658` (`ADR:370–371,1233–1235`) | Hashes of the definition text under the v4 review's rule, not of those line ranges (which hash `fa24f268…` / `4555dd30…`); the historical definition is `554–575` under that rule. Values confirmed for `3920814`. C3. |
| "The entry pins … the dependency closure … :" followed by a list (`ADR:1128–1152`) | The list omits transitive members (§3.8). Call it the starting set; the generated manifest is the closure. C5. |
| Checker summary (`ADR:1164–1180`) | Add the literal-aware brace rule (P1.4b's lexer). C6. |
| Retraction 5: the exhausted arm at `stub_step.ail:483–505` (`ADR:345`) | The arm is `:488–505`; `:478–487` are the closure header and `provider_step` binding. Cosmetic. |
| "Assert … the prefix byte-equal" (`ADR:811,837`) | The log is a `[Interaction]` value; structural equality. Cosmetic. |

Nothing numeric in v5 is wrong: the scan counts, the evidence-log counts (`session_start` 10, `context_limit_resolved` 6, `ext_solver_feedback` 2, `thinking_delta` 801, `reasoning_delta` 57, `provider_call_prepared` 693 — `S3/evidence.txt:1`), 24 GiB = 25,769,803,776 bytes, `de4b4f5` 10+/7−, twelve entry types, twelve env keys, thirteen families, seven manifest arguments, eight bridge arguments, and the `2N + 1`/`2N` decision count all check.

### 4.2 Cross-references and other coordinates

Every coordinate in **ADR:1543–1583** that names a `3920814` file was read (`S5/pin/`); none is missing or out of range, and each identifies the claimed definition or its body. Notes: `dst_execution.ail:46` is a header comment describing `NoReplay`; `session.ail:2126–2140` spans `any_native_call` (`:2126–2131`) and `session_emitted_native_tool_call` (`:2134–2140`); `ports.ail:1851–1895` spans `recording_clock`, `recording_env` and `env_has_key`; `dst_replay.ail:374–388` is the `walk` less its closing brace at `:389`. `git check-ignore .motoko/eval-corpus/example` still exits 1 at HEAD `55f1100`; P2.1 did not add the rule, which remains P0's. PLAN-004 §0.9's `tool_outcome_record :2126` is stale — the function is at `:2133` as v5 says — a PSYNC item, not an ADR error.

## Required changes for v6

**None: PLAN-004 v2 may be written against v5.**

**Corrections to apply under ACCEPT WITH CORRECTIONS** (PLAN-004 §0.10 (a)3; each is a text change, none touches a mechanism, count or test):

1. **C1 — D1 `Parked` row (`ADR:697`).** Replace the parenthetical with: "the turn preceding a park is the call-free stop-class call k whose classification found an open wait (`step_machine.ail:141–148`; `session.ail:3274`); the wait was opened by a `Handled` tool on an earlier turn (`tool_phase.ail:439–447`). The segment ends at call k−1 with `EndSuspended(k−1)`; call k is dropped rather than kept as `StopBeforeEnd` because the live run classified it `await_wake`, not approved. `park.step` = k (`session.ail:3528`, attempt 0)."
2. **C2 — D2 provider seam (`ADR:801`, `:793–794`).** "k = the number of `ProviderIdentity` records in `state.log`, computed by the evaluator (the quantity the private `provider_calls_in`, `stub_step.ail:561`, computes)"; write the ports as `{ base | model_step: …, tool_exec: … }`; say "structurally equal prefix".
3. **C3 — retraction 7 and D5 control basis (`ADR:370–371`, `:1233–1235`).** Attach the span rule to the two digests: "SHA-256 of the definition text from `export func recording_ports(` through its closing brace and newline (the v4 review's `audit_v4.py`; historical lines 554–575, current 635–658); a `sed` line-range hash differs."
4. **C4 — header (`ADR:19–20`).** "Five cited modules changed between `d5edebf` and `3920814`: the four above and `tools/driver_leaf_inventory/derive.py` (+10 at `:642–654`, no cited coordinate affected); every other cited module is byte-identical."
5. **C5 — D5 closure (`ADR:1128–1131`).** "The entry pins the dependency closure …, generated by P1.4b by symbol; the members below are the reviewed starting set" and add the omitted transitive names of §3.8 to the `ports.ail` bullet.
6. **C6 — D5 checker (`ADR:1164–1169`).** Add: "braces and parentheses are counted outside string literals (with `${…}` interpolation) and `--` comments; an unterminated literal or unbalanced brace is a hard error", per P1.4b.
7. **Cosmetic.** `stub_step.ail:488–505` for the exhausted arm (`ADR:345`, `:799`).

Retain O7. Leave the production journal/resume/park/conversation debts, the pending P2D sweep and the canaries outside this ADR, as v5 does.
