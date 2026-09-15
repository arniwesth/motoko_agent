# ADR-004 v3 — adversarial review

Date: 2026-09-14. HEAD: `d5edebf2cb75c159da8a46bdfb2a7d6f3629320e`. Branch: `arniwesth/013-plan003-and-herdr`.

Subject: `ADR-004-journal-as-evaluation-source.md`, proposed v3, especially O7 and D1–D8. Prior: `REVIEW-adr004-verdicts-codex.md`, `REVIEW-adr004-v2-verdicts-codex.md`, and `REVIEW-adr004-v2-verdicts-fable.md`, including both Fable corrections. These documents and the brief were read in full. Draft/prior-review coordinates below refer to those supplied documents; code and architecture-document coordinates refer to `d5edebf`, read with `git show d5edebf:<path>`. Bare core module names mean `src/core/<name>.ail`; `stub_step` and `scripted_ports` mean `src/core/test/`. HEAD/branch were independently returned by `git rev-parse HEAD` and `git branch --show-current`.

Method: read the referenced types, codecs, consumers, policy arms, witnesses, persistence, profiles, anchor tooling, ADR-001 D2, ADR-003 O2/D1/D2/D4/retraction 4, PLAN-003 §0.6 and the RSI trust rule. Independently counted existing JSONL/output data, folded the snapshot prefix, recomputed request/chain digests, translated the scanner, and decoded stored gzip/pprof protobuf allocation samples. No replay, prototype, sweep, AILANG execution, commit, pane operation or agent was run. Only this review was written inside the repository.

Evidence directory, denoted **S** below:
`/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review/`.
`python3 S/evidence.py` produced `S/evidence.txt`; `python3 S/source_check.py` produced `S/source_check.txt`. Additional targeted Python reads using the same framing/protobuf functions produced `S/additional.txt`; their outputs are quoted as counts below. **M** means `/workspaces/motoko_agent-mem/.motoko/memfix/`; **L** means `.motoko/logfile/session_1789244855221-63164319c7d765ff.jsonl`. No conversation content is reproduced.

## Overall verdict — RETURN for v4; retain O7

The marriage is feasible. The replay loader reconstructs queues from recorded outcome payloads, not from the request projection, so an admission log with private wider projections can be an ordinary program. Recording policy/clock/environment interactions avoids building a second generic strict-replay engine. This substantially answers the Fable marriage argument (`dst_replay:681–703,745–808,831–874`; `strict_replay_dst.ail:636–666,708–781`).

The specified protocol is not yet sound enough to approve. Four issues require design corrections before implementation:

1. The last provider finish string does not determine the loop's next decision. D1's `NonReplayableLastFinish` explanation is false, and D2's unconditional exactly-N claim omits earlier finalization, completion policy and suspension eligibility (`step_machine:122–159`; `session:2778–2794,3255–3308,4020–4138`).
2. D2 lists private functions as exported; the current schema is already `execution-program/4`; and the copied model conversion is incomplete. Passing an already-converted model to the session can convert it a second time (`stub_step:121,136,464,540`; `dst_program:119–152`; `session:272–292,3824,4440–4442`).
3. `check_discovery` neither runs the thirteen invariant families nor accepts a trace directly. The existing fixture's approval witness cannot be copied into an empty-registry run. A2 also changes the comparand of `JournalFold` without acknowledging the new source comparison (`dst_discovery:260–310,529–545`; `strict_replay_dst.ail:366–387`; `dst_invariants:1956–1997,2010–2066`).
4. The new scan policy still refuses the evidence workload: four tool-output sites trigger `ProviderTokenLiteral`, including tool 0. These are prefix-substring findings, not proof that credentials were present. The source's final assistant turn also lacks its tool result; D1's own complete-batch rule limits this snapshot to 299 complete turns (**S/evidence.txt**, **S/additional.txt**; `dst_secrets:217–229`; draft:337,645–650).

These are correctable without returning to O4 or changing ADR-003's journal writer/fold. The cooperative trust choice is acceptable if its assumptions, protected core regions and remaining observability limits are made explicit (RSI doc:53–65; draft:581–622).

## 1. Disposition of the retractions and v2 required changes

### 1.1 Fourteen v2 → v3 retractions

The numbering is the draft's list at lines 78–149.

| # | Disposition | Evidence / remaining correction |
|---|---|---|
| 1 | **Addressed in direction; overstated deletion bill.** | Discovery-then-replay is real (`strict_replay_dst.ail:636–666,708–781`). O7 reuses `strict_replay_findings` and `world_state_of`. It still needs an admission verifier, source-chain comparison, corpus wrapper and refusal mapping; draft:531–536,633–650,687–694 contradict deleting all of those mechanisms. |
| 2 | **Addressed, with a residual overclaim.** | Draft:583–591 explicitly trusts cooperative reviewed candidates. That resolves v2 blocker 1 under the chosen assumptions. “Excluded by path refusal” is inaccurate for recorder/codecs inside permitted `ports.ail`; universal detection of reshaping is also too strong (`ports:1781–1803`; draft:497–498,587–606). |
| 3 | **Partial.** | The budget predicate precedes `CallModel` (`step_machine:103–118`), and valid suspension returns `final` plus `Some(cont)` (`session:2778–2794`). Exactly N requires an eligible sequence and no earlier termination; the finish-string rule does not establish that (`session:4020–4138`). |
| 4 | **Partial.** | Logical/API boundaries are distinguished. The pinned rule strips `openai/`, `anthropic/`, and `google/` too, and conversion must happen once (`session:272–292,3824`). Draft:311–314,398 must change. |
| 5 | **Partial, not an all-zero retraction.** | Seed-derived nudges and explicit zero prior counts are accurately disclosed (`session:988–1016,4239–4255,4423–4442`). Source offset 350/342 is independently verified (**S/evidence.txt**). `JournalFold` reads cumulative counts; runtime status can expose them to the next model call (`dst_invariants:1959–1969`; `session:707,727–735,3677–3681`). |
| 6 | **Partial.** | Positive cache creation is emitted (`phase_vocab:1362–1374`); optional decoding is appropriate. Scripted service zeroes caches (`stub_step:89–90`). “No observed projection depends on them” is only true for the narrowed checks, not wire thinking/summary/runtime-status output (`phase_vocab:1348–1374,1474`; `session:760–761`). |
| 7 | **Addressed.** | Ordered association replaces unavailable per-event `run_id`. **S/evidence.txt** finds ten banners in two shapes (3 rpc / 7 ledger), 693 prepared calls and 684 successful thinking events. Ambiguity must refuse, as draft:288–295 says. |
| 8 | **Partial.** | Leading user seed, genuine completion and cutoffs/refusals are separated (draft:282–307,325–351). The newly added last-finish cutoff is not justified by the actual arm order or result classification (`step_machine:122–159`; `session:4020–4138`). |
| 9 | **Addressed.** | `ToolFailed` and `ToolCorrelationMismatch` take records (`ports:647–655`). Rendering them as error transcript messages is correct (`tool_phase:277–296`). Such a tool error does not necessarily fail the end check. |
| 10 | **Addressed.** | Stored profiles decode to 2.002150 / 1.572677 GiB, with 58 prepared calls and 115 appends in both named “57” runs (**S/evidence.txt**). Recompilation is now explicitly a hypothesis (draft:571). |
| 11 | **Addressed.** | T2b explicitly removes operator entries from the cutoff; T3 is explicitly a separate live experiment (draft:670–671). PLAN-003:70–82 supports the remaining conversation-loop limitation. |
| 12 | **Variant correction addressed; composition bill partial.** | `RecordingWorld` binds fixed ports; `Ported` starts with an empty world (`session:1533–1545`). A custom-ports/world constructor is needed for this public-entry design. Several listed seam helpers are private, and normalizer insertion can move anchors (`stub_step:121,136`; anchor tool:593–625). |
| 13 | **Entropy explanation verified; replacement policy incomplete for this corpus.** | Real absolute paths qualify at six tool-output sites. Four outputs also trigger the retained prefix rule, so switching entropy to report-only does not admit r2.1 (**S/evidence.txt**). `encode_body` + digest can produce loadable bytes without rescanning (`dst_persistence:544–591,1095–1115,1344–1356`). |
| 14 | **Partial.** | Typed suspension, `final`, and `JournalFold` are HEAD facts (`session:2760–2795`; `dst_invariants:247,1991–1997`). Numerous allegedly unmoved coordinates have moved; current program version and model conversion were missed. See §4.2. |

### 1.2 Eight required changes from the v2 Codex review

This checks the actual list in `REVIEW-adr004-v2-verdicts-codex.md:192–199`, rather than accepting draft:773–774's blanket “folded” claim.

| V2 requirement | V3 disposition |
|---|---|
| 1. Ordered association, optional cache fields, starts/nudges, leading user, cutoff/completion/refusal split | **Mostly addressed.** Source fold through entry 1055 reproduces 694 seed messages and its digest; entry 1056 starts evaluated calls (**S/source_check.txt**). Replace the unsound last-finish classifier and qualify the count/cache omissions (§3.2,8,9). |
| 2. Exact stop protocol, no uncounted extra call, complete errors, surviving mismatch evidence | **Partial.** Positive N plus eligible continuation avoids N+1; complete record constructors are fixed. Observation integrity is now a trusted cooperative assumption, rather than independent storage. State that substitution explicitly and correct the exhausted-outcome/end semantics (§3.2–3). |
| 3. Trusted logical/API conversion, prefix hash, excerpt mode, terminal and pinned preflight | **Partial.** Mandatory excerpt and separate canonical/system/raw projections are sound (`phase_vocab:275–300,321–370`; draft:273–274,418–423). Conversion is incomplete; candidate K1 omits manifest/pin preflight; source configuration is labelled pinned-but-unchecked (§3.1–2). |
| 4. Narrow recorded-response-validity class, raw payload, review limitations | **Mostly addressed.** Draft:487–491,551–556 clearly separates live canonical evidence from parent raw evidence. Define the decoded-JSON tool-argument boundary and runtime-status exclusion; this seam cannot observe original argument bytes (§3.3,8,9). |
| 5. Observation integrity or cooperative trust; remove adversarial overlay guarantee | **Addressed in principle.** Draft:583–591 adopts the allowed alternative. Correct its residual universal recorder-detection/path-refusal claims (§3.7). |
| 6. Trusted-region/control assembly preserving C's core and showing C executes | **Partial.** Candidate files and a control-only compatibility patch are explicit (draft:600–611). Region policy, marker feasibility and anchor consequences remain unspecified (§3.4,7). |
| 7. Measurement scope/phase, guarded warm-up/profile, hypothesis, accurate control data, final calibration | **Mostly addressed.** Whole-process scope, guarded equal warm-ups, no prefix attribution after divergence, hypothesis and final calibration are explicit (draft:559–575,695–710). Define seed loading/folding and a practical recursion boundary; correct exact repeat deviations (§4.1). |
| 8. Actual settings/stop/exposure, T2b/T3 scope, leave existing debts alone | **Mostly addressed.** Entry includes assembled settings, scope and exposure (draft:633–641); T2b/T3 and independent debts are explicit (:670–671,716–717). Finish actual settings and verifier/native-tool eligibility rules rather than treating source BootInputs as sufficient (§3.2,8). |

## 2. Per-decision verdicts

### D1 — RETURN

The pure reader, explicit selector, independent seed fold, required excerpt, ordered association and strict source refusals are appropriate. Source verification confirms the r2.1 boundary: 1053 ends the preceding run with cumulative 350/342; 1054 starts r2.1; 1055 is leading user seed; 1056 is its first assistant. Folding through 1055 reproduces the prototype seed exactly (**S/evidence.txt**, **S/source_check.txt**; `journal:1557` and ADR-003:388–454).

Replace `NonReplayableLastFinish` and derive expected end from the actual T0 replay policy and assistant/tool shape. `decide` does not inject for every unlisted reason. The successful-result path makes any response with calls a `tool_calls` state regardless of its reported finish, while a no-call response enters hybrid/completion classification. Thus “recorded stop” is neither sufficient nor necessary for replay finalization (`step_machine:122–159`; `session:4020–4138`). Require all earlier calls to continue and the last call to reach the declared end under explicit synthetic/recorded settings; refusal or a shorter complete-turn selector is preferable to pretending the provider finish predicts this.

Copy the full converter and pass the logical model into the session; record the once-converted API model at the seam. Also narrow the omission assumptions: a native `MotokoRuntimeStatus` result exposes prior/cache totals and is synthesized before `tool_exec`. Serving counts/cache as zero cannot reproduce that source result by queuing it as an ordinary tool (`session:272–292,707–764,3677–3681`; `tool_phase:562–564`). The present r2.1 tool-name census contains no such call (**S/additional.txt**), so this is a class restriction, not a claim that this evidence already fails for runtime status.

### D2 — RETURN

Record rather than derive the interaction protocol; keep `PortedWorld`. Wider projections fit current `Interaction` and codecs and do not require rebasing the default recorder (`dst_interaction:297–302`; `dst_persistence:211–239,528–538`; `dst_replay:395–411,681–703`).

Correct the exported-helper claim, choose the composition strategy in §3.3, and require the *same* evaluator seams on candidate replay. `world_state_of` reconstructs response queues, not the custom recorder: using plain `RecordingWorld` produces narrower projections and K2 fails even for unchanged parent code (`session:1540`; `stub_step:505–527`; draft:407–431,518–520).

Current schema is /4, so the proposed seed schema must be a later version. Populate all required manifest fields; JSON-encode `RecordedConfig` into its string field. Specify N>0, valid continuation history, explicit verification-disabled runtime, context/system preflight, complete tools, and no injection/park/retry/replacement path. The finite-tool seam must never delegate an empty queue to `world_tool`'s live arm (`dst_program:132,366–369`; `dst_profile:1474–1491,1535–1572`; `session:2241–2254,2778–2794`; `ports:1677–1698`).

The exhausted provider payload records “served false,” not the proposed complete `replay_exhausted` AIError. It is skipped during reconstitution. Treat that branch as a fatal evaluator/candidate divergence which cannot become a source-faithful persisted program, or define an honestly encoded fault; do not suggest that the exhausted marker round-trips that error (`ports:2476–2507`; `dst_replay:687–697`). Tool errors may preserve the expected suspension end; K2/chain, not necessarily end, detects them (`tool_phase:277–296`; `step_machine:155–159`).

### D3 — RETURN

Keep A1/A3/A4 and K2's distinction between source canonical checks and parent raw checks. Keep exact counts and discarding all measurements on divergence (draft:505–523,551–562). Add a real HEAD-level runner contract for discovery witnesses, execution bridge, invariant evaluation and candidate preflight (§3.1). The listed K1–K6 do not implement D4's “every existing family runs” promise (`dst_execution:99–125`; `dst_invariants:2010–2066`).

A2 is an additional source transcript/chain comparison, not the current `JournalFold` function with a different argument. Keep the local invariant comparing folded replay trace to `run.final`, then independently compare source history/chain/counts. Do not replace the independent `final` comparand with a recomputation from the same trace (`dst_invariants:1956–1997`; `dst_execution:114–120`). Report source cumulative offsets as omitted while still checking local cumulative consistency.

Pin and validate manifest/profile/toolchain/corpus/settings before each candidate; K1's loader only runs structural validation, and observed bounds are not protective execution limits (`dst_replay:811–835`; `dst_program:589–596,648–653`). Define source argument decoding and deterministic JSON framing; the adapter has already converted raw strings to `Json` (§3.3). Refusal/finding mappings also remain new evaluator work despite the reused mismatch sum (draft:531–536).

### D4 — ACCEPT WITH CORRECTIONS

Whole-process allocation of the named simulated execution, secondary GC/RSS, equal guarded warm-ups, a stated hypothesis rather than a recompilation finding, and no quality/latency/provider claims are acceptable (draft:559–575; RSI doc:45–53). The stored allocation and GC/RSS evidence supports historical resource differences, not an already-calibrated O7 gate (§4.1).

Make seed loading explicit: choice (b) requires loading/verifying/folding the external snapshot, unless a separately pinned prefolded seed is supplied. State whether those operations run inside the profiled process. Stop/end events, finalization, trace serialization and checks remain included in whole-process allocation. Recursion depth needs a tool-supported phase boundary; a process-wide depth metric cannot simply subtract evaluator recursion by declaration. Add the actual invariant bridge/evaluation to the scope and correct the exact repeat-deviation figures (`dst_execution:99–125`; draft:475–478,571–575; §4.1).

### D5 — ACCEPT WITH CORRECTIONS

Cooperative reviewed candidates, immutable criteria during one evaluation, explicit basis transitions and retained identities agree with RSI:57–65 and ADR-003 O2:226–235. ADR-001:386–410 supplies request witnesses and successor discipline, not hostile-process isolation. Keeping candidate `session.ail` rather than overlaying it wholesale is the right granularity (draft:600–606).

Protect recorder/codec and normalization regions explicitly, since `ports.ail` and `session.ail` are allowed candidate files. Path refusal alone cannot exclude edits to those regions. Hashes detect disk changes, while witnesses help detect ordinary omissions; neither proves provenance of candidate-returned worlds/traces. A meaningful observable marker adds evidence when one exists, but a semantics-preserving candidate need not have a functional output difference. Use verified assembled source/patch identities and define a feasible marker rather than requiring a guaranteed difference for every admissible candidate (`ports:1781–1803`; `dst_discovery:374–377,529–545`; draft:587–606).

The control-only compatibility patch can be consistent with evaluator-path refusal because it is E's assembly operation, not C's diff. Record the full assembled identity and isolate its effect from the candidate resource comparison. Account for anchor reissues or intentional line-neutral edits (§3.4,7); “limited to three arms” does not by itself settle imports, legacy-match semantics or seam-export changes (draft:608–611).

### D6 — ACCEPT WITH CORRECTIONS

Private corpus, permissions, ignore-before-copy, retained identities, exposure accounting and genuinely withheld future sessions are appropriate (draft:626–641,656–661). `git check-ignore .motoko/eval-corpus/example` returned no match (exit 1), confirming that ignore-before-copy is still needed at the reviewed basis. Custom artifact assembly is compatible with the decoder if escaping, header and trailing newline are exactly those of the codec (`dst_persistence:544–591,663–668,1095–1115,1344–1356`).

Correct “precise”: the retained prefix detector is a substring rule and refuses this r2.1 program. Accepting refusals is a legitimate policy, but the ADR must name this consequence and identify a usable short dev entry for the gate or choose a separately reviewed contextual policy. Do not silently suppress findings or label substring findings verified credentials (§3.6). Specify scan coverage over program metadata/env/files/interactions *and* snapshot/excerpt/derived output; the seed outside the program is not outside the corpus. Retain or explicitly decide `CredentialBearingName`, the sixth scanner reason (`dst_persistence:615–637`; `dst_secrets:353–359`; draft:643–650).

### D7 — ACCEPT WITH CORRECTIONS

Cumulative omissions, content chunks versus real streaming, resumed traced entry versus production conversation loop, T2 as an investigation, T2b's operator-input exception and separate T3 transfer are substantially correct (draft:667–679; PLAN-003:70–82). The scope does not license pending journal/park/conversation debts.

T1 cache fidelity requires widening `ScriptedStep`, its provider outcome encoder/decoder and conversion/recording paths, not just the record field, under a version later than current /4. Prior-count message-only support needs a public wrapper normalizing ports before policy init. Specify which thinking/summary fields remain unreproduced at T0 and exclude or support generated runtime-status tools (§3.8–9; `ports:2461–2507`; `stub_step:72–90`; `session:4239–4255,4423–4442`).

### D8 — ACCEPT WITH CORRECTIONS

Preserve without running, tiny implementation checks, guard/calibrate, demonstrated short regression gate, held-out collection and long admission last is a sound sequence (draft:684–713). Guard trips invalidate runs; warm-ups/profile runs share the guard. A read of `memory.max` returned 25,769,803,776 bytes (24 GiB). Historical current-memory samples are observations, not execution authorization; this review ran nothing heavy.

P1 must include the missing source verifier/refusal mapping, empty-registry witness builder, execution bridge/invariants and preflight, plus the real variant/anchor bill. Remove its categorical “Not built: a verifier … corpus format … refusal vocabulary” claim (draft:687–694; §4.3). P3 must first find an entry admitted by the chosen scan policy and all complete-turn/source checks. The old 58-call terminal-augmented profiles establish neither the new finite-turn budget nor a threshold for O7. Final evaluator/control calibration, as already required at draft:708–710, remains essential.

## 3. Answers to the eleven questions

### 3.1 O7 soundness

**Yes conditionally; no drop-in proof from the existing fixture.** `world_state_of` structurally validates, decodes served provider outcomes into `script`, tool outcomes into `tools`, extension outcomes into `ext_effects`, approvals into raw lines, and wakes into their separate queue. It copies env/files/epoch from `InitialWorld`, starts `log` empty and does not read seed metadata (`dst_replay:681–703,717–808,831–874`). T0 should have no served extension/approval/wake interactions. Structured provider/tool records from the same evaluator seams can therefore reconstitute, balance and strict-replay; custom projection strings are compared verbatim rather than parsed (`dst_replay:395–411,580–603`).

`generator_id: "journal_admission"` needs no registered generator: schema validation requires a nonblank ID/version, not membership (`dst_program:357–364`). `validate_program` accepts structurally valid nonempty interactions and does not check bounds or manifest (:589–596). `validate_manifest(m, driver_only())` can accept an empty extension-package list, but must receive a populated classifier set/scan roots, string-encoded normalized config, matching profile/event/rule versions and nonblank revisions/toolchain/ABI (`dst_profile:1474–1491,1535–1572`). The sketch is not a literal complete manifest; binary hash can be carried in its toolchain identity/sidecar, not a nonexistent dedicated field. Current schema is /4 (`dst_program:132`).

`check_discovery(log, witness)` requires a **DiscoveryWitness**, not a trace. For this empty-registry class, derive provider count from prepared trace records (`strict_replay_dst.ail:310–315`), tool-dispatch count from native-dispatch evidence/cursor consumption independently of the recorder, clock delta from initial/final worlds, and approval/effect/fs-mutation expectations as explicit zero where unreachable. Native tool service does not itself mutate `WorldState.files` merely because the tool's name is WriteFile. Exact balance with zero is valid (`dst_discovery:260–310,374–377,473–545`; `ports:1729–1752`).

The environment witness must describe the chosen settings and reached branches, not count the recorder's own log. The complete known-key set is `driver_env_keys():224–237`. For the normal traced entry:

- Policy reads persist, stream retry, base URL and headless once; derive-session-id reads its key once (`session:1728,2352–2355`).
- Context resolution reads profile-dir once; config/repo fallback only without an explicit directory. Catalogue reads models-file once, with a second repo fallback only if the local catalogue probe is absent. A positive/disabled profile skips catalogue entirely (`context_usage:59–76,139–150,178–195,241–250`). With empty env/files: profile-dir/config/models-file once, repo twice, and three file reads per resolution (:233–240). This entry resolves during policy initialization (`session:2360`); do not reuse historical per-arm resolution counts.
- Tool-timeout is read once per reached native dispatch (`tool_phase:485`; `strict_replay_dst.ail:419–463`). Runtime-status/bypassed/invalid-argument cases need their own eligibility treatment.
- Exit-manifest is read only when successful finalization reaches publication; budget suspension does not (`session:3398,5066–5067`; `strict_replay_dst.ail:395–408`). Failed-payload capture remains zero for successful T0 calls (`session:3862–3921`; `driver_env_keys`:225).

Pin explicit zero expectations for skipped known keys as well as positive expectations: `env_balance` checks the supplied list, not an automatic complete provenance table (`dst_discovery:542–544`). Synthetic file inputs needed to serve a config/catalogue must appear in both initial worlds; unconditional `files: []` cannot simultaneously promise a present recorded/synthetic catalogue (`context_usage:180,110`; `dst_replay:852–863`; draft:319–321,386,464).

The fixture's `approval_rt` installs an approval-bearing extension (`strict_replay_dst.ail:282–295`). Its `witness_of:370` equates approval reads to consumed provider tool calls, and its nonvacuity assertion requires approval observations (:792–795). Neither applies to an empty registry. Construct new scenario-specific witnesses; keep zero approval balance rather than fabricate observations.

Finally add `execution_of(...)`, `evaluate(...)` and `family_evidence(...)` at admission and candidate replay. The bridge needs initial clock, replay obligation/metadata, decision/retry budgets, ambient-RNG/forbidden-site inputs and actual `run.final` (`dst_execution:99–125`). The thirteen families are separate from discovery (`dst_invariants:2010–2066`). Their coarse evidence counts do not prove every event subclass was exercised; report evaluated versus exercised and explicitly vacuous extension/checkpoint/streaming observations. This resolves A7/D4's ambiguous “every expected family non-empty” without importing the rich fixture's incompatible requirements.

### 3.2 The end and earlier stopping

N>0, valid seed, N successful recorded calls, complete reached tools, no earlier completion/injection/park/retry/seal failure, and a last call entering the continuation path give exactly N provider calls from step zero. Pending tools run before the next budget test; exhausted continuation reaches `StepBudgetExhausted` and typed suspension. `c2_suspend` first checks resumable history, so invalid continuation instead fails; for valid history it appends/emits `RunSuspended`, returns `Err`, `TermMaxSteps`, `Some(cont)` and populated `final` (`step_machine:103–118,123–129`; `session:988–1016,2778–2794,4033`). Thus the budget is an upper bound/protocol component, not an unconditional N-call generator.

The complete relevant `decide` ordering is:

| State | Before ordinary budget test |
|---|---|
| `hybrid_bash` with pending calls | RunTools |
| any other pending calls | AwaitApproval for `await_approval`; otherwise RunTools |
| `dp7_rejected`, `solver_feedback`, `persist_nudge` | InjectUserMessage |
| open waits with `await_wake`, `stop`, `dp7_approved`, `dp7_fail_open` | Local budget test: suspend if exhausted, otherwise Park |
| `stop`, `dp7_approved`, `dp7_fail_open` with no matching wait path | Finalize(model_stop) |
| `stream_error`, `intercept_handled`, `tools_complete`, `user_injected`, other strings | call_model_or_fail: budget, cost, checkpoint, projection, CallModel |

Source: `step_machine:122–159`. In particular an arbitrary unlisted string does **not** automatically inject. LastFinish is internal state: any actual tool calls, even with recorded `stop`/`length`, take the tool branch and store `tool_calls` (`session:4020–4045`). Without calls, hybrid synthesis or `classify_candidate` can choose approved/nudge/rejected/feedback/wait states (:4064–4138,3255–3308); approval stores `dp7_approved` (:3045). Hybrid synthesis also replaces the assistant later, already excluded by the replacement cutoff (:4080–4089; draft:336).

`BudgetPlan.total` becomes remaining budget in ExtCtx, not an independent loop-stop predicate (`session:1935–1950`); an empty extension registry removes its solver feedback decisions. Recorded r2.1 BootInputs have total/solver 1200, verifier 0, source step budget 1200, hybrid true, ohmy_pi false, cap/rates zero (**S/source_check.txt**). Replay step budget N and cap zero are explicit overrides; the cost branch is disabled (`step_machine:112–113`). The chosen entry initializes checkpoint_enabled false regardless of context size (`session:2376`), but projection/sealing can still fail or change the transient payload (`step_machine:116–118`; `session:3783–3799`). Pin the context/system settings and reject any unexpected transformation before scoring.

Empty registry alone does not disable `rt.verification.enabled`; DP7 verification can execute a real subprocess (`session:2241–2254,3269`). Pin false separately. Positive persist budget plus seed WriteFile history can inject a nudge even after a no-tool stop (:3288–3296). Require the reached completion policy/end to agree. `open_waits` starts empty (:1014); assert it remains empty/no park/wake at T0. No synthetic assistant sentinel is needed, but suspension/finalization/configuration observations and their allocation are synthetic parts of this simulated execution. Replace “nothing is synthesised” with the narrower no-extra-provider/assistant claim (draft:449).

For the present snapshot, 300 source assistants contain 300 tool calls; only 299 tool results exist. Missing-result turn is zero-based 299, with one unanswered call (**S/additional.txt** and targeted Python `Counter(tools.tool_call_id)` against script calls: `[(299, 1, 1)]`). D1 must cut before that whole turn: the complete prefix has N=299, 299 tools and 598 appends, not a source-faithful 300-call terminal turn. Eof/cutoff end is synthetic suspension, not source completion.

### 3.3 The seams, exports and wider projection

| Piece requested in brief | Exported at HEAD? |
|---|---|
| `record_interaction` | Yes, `ports:1781` |
| `provider_outcome_record` | Yes, `ports:2171` |
| `scripted_to_step_result` | Yes, `test/stub_step:72` |
| `scripted_step_faults` | Yes, `ports:2125` |
| `scripted_step_ai_error` | Yes, `ports:2119` |
| `scripted_chunks` | **No**, private `test/stub_step:136` |
| `play_chunks` | **No**, private `test/stub_step:121` |
| `world_tool` | Yes, `ports:1677` |
| `encode_tool_outcome` | Yes, `ports:2531` |
| `tool_outcome_record` | **No**, private `ports:2087` |
| `encode_exhausted_provider_outcome` | Yes, `ports:2476` |

Also private: `recording_model_step` (:464), `chunk_records` (:540), `provider_calls_in` (:547) in stub_step and `scripted_tool_outcome` (:1729) in ports. Public `recording_ports` (:621) and `recording_tool` (`ports:2010`) already encapsulate successful service/recording.

A cheaper composition is to guard finite queues, delegate nonempty model/tool calls to `base.model_step` and `base.tool_exec`, and replace only the last interaction's request projection with the independently computed wider projection. Preserve all returned outcome/chunk/emission/cursor fields and ordinal/pending; assert exactly one record appended. This avoids new exports and duplicating private outcome/fault/chunk code. T0 also deliberately supplies chunks [], so direct successful model composition need not call the private chunk helpers. Specify one approach; the draft's literal exported-helper recipe is impossible as written (`stub_step:474–528`; `ports:2010–2059`). Empty queues require separately recorded, honestly classified failures; they must not be delegated.

`record_interaction` assigns interaction ordinal from log length and does not advance helped-request ordinal/pending (`ports:1781–1797`). `identity_projection` reads identity only (`dst_interaction:233–235`), while strict findings compare projection separately (`dst_replay:334–364,395–396`). Wider projection therefore does not change identity or automatically cause HarnessFailure. Persistence escapes backslash/tab/newline/carriage return; `=` and `<` are ordinary field bytes, so they round-trip (`dst_persistence:211–239,528–538`). Scanner coverage includes projections, however, and a projection may itself trigger a finding (`dst_secrets:431–442`).

`max_payload_bytes` measures only `Str.length(outcome.payload)`; it does not bound request_projection, initial seed/metadata, or all chunk text, and structural validation does not invoke it (`dst_program:627–653`). Observe limits using the implementation's length convention and add independent resource guards. Wider projections fit the type, but are not covered by this bound.

ToolInvocation.call carries a ToolCallEnvelope whose arguments are already `Json` (`ports:616–621`; `tool_dispatch_adapter:46–56`). A4 must decode source argument strings using the pinned boundary, then hash a specified deterministic JSON representation. It cannot compare a digest of original journal bytes to a digest of decoded Json and claim universal raw-byte equivalence. For this first-299 prefix, all 299 argument strings decode and equal compact JSON serialization (**S/additional.txt**), which makes this evidence simple, not the general boundary byte-preserving. Define/refuse malformed arguments and distinguish semantic JSON equality from original byte equality; private provider-frame/chain checks still preserve original retained message bytes where those messages are compared.

### 3.4 Variant, exhaustive matches, anchors and gates

HEAD's sum has six constructors and lacks PortedWorld (`stub_step:69`). `git grep` for constructor arms at `d5edebf` finds the exhaustive normalizer (`session:1533–1545`) and exhaustive `frame_ordinal0` (`scripts/dst/ledger_parity_dst.ail:429–435`). `test/scripted_ports:30–35` is an existing legacy **nonexhaustive three-arm match**, not a third exhaustive six-arm match; define how it handles/refuses world-bearing providers rather than merely saying “audited.” Constructor uses in other scripts are not additional exhaustive matches; `dispatch_step` takes Ports and WorldState rather than matching StepProvider (`stub_step:777–788`). The implementation bill includes constructor imports as well as the declaration/arms.

No new helped request, Ports field or LedgerEvent is needed; preserving existing normalization/outcomes leaves ordinal-frame/golden semantics unchanged (`session:1533–1545`; ADR-001:386–410). That does **not** guarantee unchanged anchor files:

- Extending the one-line sum at stub_step:69 can be line-neutral; adding imports/comments/new lines above its ambient `now():203` moves its pinned site. Its import notes explicitly warn about this (`stub_step:31,44`; `tools/predicate-anchors/anchors.sh:593`).
- Adding a new line to session's normalizer around 1540 moves anchors 1730/1842/4302/4523; anchor 1471 is above it. An added import near 195 moves all five, and can move the bridge span. Either consciously preserve physical lines or reissue attribution references/profiles and referring fixtures (`tools/predicate-anchors/anchors.sh:594–625`; `dst_driver_only:211–227`).
- `tools/driver_leaf_inventory/derive.py:154` pins session bridge span 1085–1474. A change below it with no earlier line drift leaves this span and helped-leaf semantics intact. An earlier insertion requires repinning that span; do not casually widen the frozen recognition rules (:101–116,123–154).

The actual tool paths are `tools/predicate-anchors/anchors.sh` and `tools/driver_leaf_inventory/derive.py`. A symbol-only variant is not a reason to regenerate runtime frame goldens, but normalizer/legacy-match coverage and applicable anchor/profile/ordinal gates must be validated in implementation. This review ran no gate/sweep. Draft:733–738's categorical unchanged-frame-gates/derive bill needs the physical-edit condition above.

### 3.5 Seed in snapshot rather than program

Choice (b) is sound as an **entry-level** reproduction design. InitialWorld.messages_and_policy is opaque, validated only for nonblank text; no seed decoder is called (`dst_program:182–188,366–369`). Reconstitution checks queue counts, epoch and env/file quantities, not supplied session messages (`dst_replay:580–603,831–874`). Persistence encodes that opaque string without interpreting it (`dst_persistence:552`). Existing fixture replay supplies its own `history()` (`strict_replay_dst.ail:226,298–302,651`).

The runner must independently verify snapshot/selector/seed digest and pass the same seed/settings to admission and candidate; a valid standalone program currently proves none of that. Its program alone is not the reproduction unit claimed by D11; draft:475–478 already states this correctly. Define seed loading in the measurement process (§2 D4).

A typed `[Message]` seed would cost a new field in InitialWorld or ExecutionProgram, updates to every record constructor/world-builder and persistence encoder/decoder/required-tag/projection/scanner path, current frozen specimen/compatibility paths, and explicit replay-entry plumbing. Reuse `journal.messages_json:377` / `messages_of_json:550`; adding the field does not make `world_state_of` seed the session automatically. Current /4 is already wake support, so the seed change needs a later schema, e.g. /5 with an explicit old-version seed policy (`dst_program:119–152`; `dst_persistence:544–588,1095`; `dst_replay:831–874`). This duplicates necessary reproduction input, not necessarily a second response script, but is a larger bill than choice (b).

### 3.6 Scan policy and real sites

The translated rule uses `[A-Za-z0-9+/=_.-]+`, qualifying only runs containing upper, lower and digit, threshold 32 (`dst_secrets:287–327`). **S/evidence.txt** reports qualifying absolute-path substrings in tool outputs at indices **0,96,97,184,195,228**, longest qualifying runs **32,32,48,48,32,48** respectively. The existential ordinary-path claim is verified. Not every repository path qualifies; case/digit/length matter.

The exact value-rule scan over evidence content yields:

| Input sites (zero-based within prototype arrays) | ProviderTokenLiteral | OpaqueHighEntropy | URL / private-key / JWT |
|---|---:|---:|---:|
| 694 seed-message contents | 16 | 44 | 0 / 0 / 0 |
| First 299 provider-script contents | 0 | 0 | 0 / 0 / 0 |
| 299 tool-output contents | **4** | 10 | 0 / 0 / 0 |
| Encoded completed-tool outcome payloads | **4** | 10 | 0 / 0 / 0 |

Tool prefix sites: **0,96,195,228**. Entropy sites: **0,96,97,140,184,195,216,222,228,252**. Seed prefix sites: **1,16,78,86,98,103,184,258,267,277,369,385,671,683,689,691**. Output: **S/evidence.txt**; translated functions: **S/evidence.py**, compared to `dst_secrets:217–270,287–347`. These are counts of strings with a reason, not token counts or asserted leaked credentials.

**Yes, retained precise rules refuse an r2.1 program containing those outcomes**, even though the external seed is omitted from the program. Tool 0 means every nonempty complete-turn prefix starting at the specified first call still hits the prefix rule. Scanning the snapshot seed adds further findings. `ProviderTokenLiteral` is `Str.contains` for any configured prefix, with no credential-body validation; URL checks the first authority, PEM checks two substrings, and JWT's current implementation examines its first three split parts rather than being a comprehensive token parser (`dst_secrets:225–270`). Calling all these “precise” overstates both specificity and coverage. Filter exact scanner reasons under a reviewed policy, cover every corpus component, retain name-axis treatment, and report refusal honestly. Bypassing encode_artifact only bypasses its gate; it does not establish safe content or source fidelity (`dst_persistence:615–669`).

### 3.7 Trust model, path refusal, marker and historical control

Cooperative trust is consistent with the harness's source-carried evidence and the RSI requirement that acceptance criteria remain independently fixed during evaluation. It does not establish hostile-candidate evidence integrity (RSI:57–65; ADR-003 O2:226–235; ADR-001:386–410). Path refusal protects evaluator/test/dst files; hashes protect their disk identity; trace/world witnesses detect ordinary count/successor omissions. Candidate core still owns the returned world and can fabricate mutually consistent evidence (`ports:818–824,1781–1803`; `dst_discovery:260–310,529–545`). Reconstitution decodability cannot detect every reshaped request projection.

Since allowed `ports.ail` houses recorder/codecs and `session.ail` houses normalization, protect those regions with pinned hashes/review or treat their changes as reviewed basis transitions. The current whole-path list does not enforce this exclusion (draft:493–498,587–606). Independently chosen markers help when their expected effect is meaningful; a candidate deliberately preserving all functional observations may require source/assembly verification and resource-path evidence instead of a guaranteed transcript difference. Do not treat one marker as proof that every measured path executes C.

`git show de4b4f5^` identifies `a6abda4`; the control's canonical implementation is the inefficient historical one identified in the prior review (`REVIEW-adr004-v2-verdicts-codex.md:132,186`). A reviewed E-only compatibility patch adding custom-world normalization is compatible with refusing C's evaluator-path edits. Record base/control/E/patch/full assembly and maintain historical core. If successful delegation avoids extra exports, its core compatibility patch can remain small; if D2 instead exports private helpers, widen and review the actual compatibility bill. Anchor drift is an assembly cost too, not a reason to overlay the entire measured session file (§3.4).

### 3.8 Prior counts, nudges and traced wrapper

`c2_initial_state_with_counts` zeros totals/telemetry/artifacts, derives `nudges_used` from seed, stores supplied prior counts, clears pending calls/approvals/waits and starts step zero (`session:988–1016`). Default message-only traced entries supply zero counts; the internal counts-aware traced function is not exported (`session:4239–4255,4423–4442`). Source r2.1 offset is 350/342 (**S/evidence.txt**). Continuation starts carry counts and other state, legitimately outside T0 (`session:2664`; draft:307).

The narrow claim “no loop decision directly tests cumulative” is supported: `decide` reads step/history/totals/telemetry/pending/waits/policy, not cumulative (`step_machine:102–159`). The broad “no check reads it” is false once the promised `JournalFold` family runs; it compares all five cumulative fields (`dst_invariants:1959–1969`). Local replay consistency can pass with zero prior counts while source-count comparison remains omitted.

Reporting can also enter the model input: runtime_status_json computes prior+trace counts and cache totals, and the built-in tool path turns that report into a tool message before ordinary execution (`session:707–764,3677–3681`; `tool_phase:562–564`). Exclude/support it and state source cumulative/summary fields not reproduced. Nudges are a real stop-policy dependency because seed WriteFile attempts and persist budget influence completion (`session:3288–3296`), even though prior counts themselves are not a direct decide predicate.

A public sibling wrapper can mirror `run_v2_session_traced:4423–4442`, accept RuntimeStatusCounts, normalize provider first, initialize policy through those ports, and call the existing internal counts-aware traced entry with `init.next_state`. PortedProvider is already exported (`ports:818`); the wrapper adds no helped request or new loop algorithm. Exporting only the low-level counts function exposes preinitialized-policy/provider responsibility; the public sibling preserves the ordinary entry convention. Insert below pinned sites or explicitly account for physical drift. This is a modest API/coverage bill, not a new replay engine.

### 3.9 Cache served as zero

`scripted_to_step_result` zeroes both fields (`stub_step:89–90`); provider codec lacks cache fields (`ports:2461–2507`). `c2_add_step_totals` accumulates caches for totals/cost reporting (`session:1549–1557`). Telemetry records only last input/output counts (`model_phase:17–25`); cap zero disables the cost termination predicate (`step_machine:112–113`). For eligible ordinary scripted-tool runs, A3/K2/provider raw frames and source transcript-chain checks do not need source cache usage. Thus this is a defensible **declared omission for named checks**.

It is false for all observed projections: ThinkingInfo carries caches (`model_phase:33–43`), positive caches change emitted thinking keys (`phase_vocab:1362–1374`), summary usage changes (:1348–1359,1474), and runtime status exposes them (`session:760–761`). In the full host log 681/684 successful thinking events contain read-cache usage; in selected r2.1 299/300 are positive; creation is absent here, although producer emits it when positive (**S/evidence.txt**, **S/source_check.txt**; `phase_vocab:1372–1374`). Local emission parity can still pass because replay emits and records its own zero values; that is not live-field fidelity. Name those omitted output fields and the runtime-status eligibility rule in the envelope.

### 3.10 Everything factually wrong / overstated

The corrections are enumerated in §4.2–3 as well as §3.2–9: current schema /4; future seed version; incomplete/double model conversion; private seam helpers; finish-string/injection/expected-end rule; unconditional exactly-N and valid-continuation prerequisite; tool error need not fail end; “nothing synthesized”; trace-vs-witness signature; discovery-vs-invariants; rich-fixture approval assumptions; JournalFold source comparand/cumulative reads; categorical cache observability; decoded-JSON argument boundary; bounds function/name/coverage; incomplete manifest sketch; unconditional no-anchor bill; path-only recorder exclusion/reshaping detection/guaranteed marker; deleted-verifier/corpus/refusal claim; retained scan-rule specificity and actual r2.1 refusal; source's incomplete 300th batch; stale allegedly unmoved coordinates; exact versus rounded deviation numbers. Draft estimates in days are estimates, not measured facts. No new estimated duration is presented as an implementation measurement.

V3 generally describes the v2 review's objections accurately. Two qualifications: prior requirement 2's independent mismatch integrity has been replaced by the review's expressly allowed cooperative alternative, not implemented as independent storage; prior numerical deviation observations used rounded TSV values, whereas exact profiles yield different third decimals (§1.2, §4.1). Fable's two corrections are correctly carried in principle; implementation cost/export and scan consequences were not fully followed through (§1.1 rows 12–13).

### 3.11 A cheaper design (at most ten lines)

No cheaper *different architecture* was established that retains these checks and the required source/request/tool observations.
The cheapest supported refinement is still O7: add PortedWorld and use exported recording_ports (`session:1533–1545`; `stub_step:621`).
Guard finite queues, delegate nonempty calls, then replace only each appended request projection (§3.3).
Reuse core outcome codecs and all replay/discovery/invariant functions; add scenario-specific witnesses and source checks.
Keep the independently verified seed in the corpus snapshot, avoiding a program-schema change (§3.5).
This removes unnecessary private-helper exports and mirrored success/outcome code, but not admission, preflight, corpus or trust work.

## 4. Claim audit

### 4.1 Numbers, independently re-derived

Profile allocation is the sum of pprof `alloc_space` sample values, divided by 2^30; TSV labels “GB” are GiB. JSON/output counts are from parsed existing files, not historical prose. Commands/output: **S/evidence.py → evidence.txt**, **S/source_check.py → source_check.txt**, and additional targeted framing/protobuf reads → **S/additional.txt**.

| Claim | Result / qualification |
|---|---|
| 694 seed messages; 1,170,593 bytes; ~0.9 MB content | Confirmed: default Python json.dumps UTF-8 bytes **1,170,593**; compact non-ASCII-escaped JSON **1,148,108**; raw content UTF-8 bytes **903,364**. Serialization matters. |
| Source seed/script/tool extraction | Prefix fold through seq1055 gives 694 messages, raw seed/digest agreement, no errors; all 300 source assistants and 299 source results equal prototype arrays (**source_check.txt**). |
| 300 unique request digests and live subsequence | 300 distinct requests; unique subsequence starts at **zero-based 351** of 693 live prepared requests; 300/300 system-prefix matches; 300 model-string differences at logical/API boundary. Independently recomputed source payload digests agree **300/300** (**additional.txt**). |
| Raw chain / prototype “MATCH” | Source chain independently agrees **599/599**; substituting prototype's synthetic terminal response produces first mismatch at **zero-based 598**. Historical output compares only 598 appends; it is not full source fidelity (**evidence.txt**, **additional.txt**). |
| Last source batch | Script has 300 calls, tools 299; only missing-result turn index **299**, one call. First 299 complete turns have 299 tools / 598 appends. Old 300th request is synthetic terminal, not source turn 300. |
| Nine matched pairs / recent two | Counts **201+201+201+101+151+300+300+300+51 = 1,806**; recent **58+84 = 142** gives **1,948**. Each paired request-digest sequence matches. These remain prototype observations. |
| Recent “57” / “84” source fidelity | Both 57 outputs: 58 requests, seed2, final117, **115** appends, trace999, checker114. Both 84 outputs: 84 requests, printed steps83, seed2, final170, trace1447, checker166, divergence index114. Equal request sequences do not repair source transcript divergence. |
| Cache / event counts / extensions | Full L: prepared693, successful thinking684, read-cache present681, creation0, retries8, thinking_delta801, reasoning_delta57. Banners10: rpc3 / ledger7; three loaded-extension arrays each length9. Loaded is not executed. Selected r2.1: thinking300 all tool_calls; read-cache positive299, input/output telemetry agreement300; no retry/replacement in the selected prefix (**source_check.txt**). |
| Long baseline alloc, repetitions1/2/3 | **346,841,061,868 / 346,438,032,606 / 347,239,976,715 bytes = 323.020911 / 322.645560 / 323.392429 GiB**. |
| Long fixed alloc, repetitions1/2/3 | **78,190,724,188 / 78,352,688,418 / 77,946,429,587 bytes = 72.820787 / 72.971628 / 72.593269 GiB**. |
| ±0.115% / ±0.279% observations | Rounded TSV-based observations from prior reviews; full-precision maximum deviations from each mean are **0.115805025% / 0.277433524%** (three-decimal **0.116% / 0.277%**). Correct or identify rounded-input method. Neither is a calibrated universal tolerance. |
| Long RSS / duration | TSV: baseline **9,280 / 11,802 / 11,703 MiB**, **121 / 144 / 83 s**; fixed **6,969 / 7,058 / 6,987 MiB**, **56 / 59 / 61 s**. These are 300-call terminal-augmented runs. |
| GC / maximum live heap | TSV and independently parsed gctrace agree: baseline **97/99/93**, **1,898/2,450/2,343 MiB**; fixed **34/34/33**, **1,213/1,271/1,272 MiB** (**source_check.txt**). |
| Recent named control profiles | prefix_57 **2,149,792,369 bytes = 2.002150 GiB**; fix_57 **1,688,648,874 = 1.572677 GiB**. Both have 58 provider calls, not a calibrated new 57-call finite replay. |
| 200-step first-run outlier | Fixed profiles **22.120580 / 10.882213 / 10.857291 GiB**; baseline **33.321049 / 33.214783 / 33.199823 GiB**. Recompilation/warming remains a hypothesis, now correctly labelled (draft:571). |
| Other cited scale observations | 150-step profiles baseline **138,423,129,445 bytes = 128.916585 GiB**, fixed **32,806,973,133 = 30.553875 GiB**; 100-step TSV RSS baseline4307/fix2749 MiB. These are individual observations, not a guarantee of safety at that prefix. |
| Large synthetic seed | HEAD PLAN-003:772–775 records the earlier **1,050,218-byte** maximum, 11 seeds / 2,301,545 total bytes. Independent reads of stored `.ailang/w3-compaction_dst.out` and `dst-p1c.out` find **11** history_seeded events, maximum current stored line **1,050,377 UTF-8 bytes** (excluding newline; largest w3 line1170). Thus the large-fixture retraction is supported; the exact earlier number is an attributed historical measurement, not the byte size of these later stored outputs. Do not claim it was newly reproduced exactly. |
| Cgroup observations | `cat /sys/fs/cgroup/memory.max`: **25,769,803,776** bytes =24GiB. Prior 10.5/9.93GiB current samples cannot be re-derived as past state; v2 review:128,188 records its specific sample. No current-memory read licenses shared heavy execution. |

No numerical improvement above is credited to a not-yet-built SourceFaithful/Reproduced O7 run. Costs and time estimates in the draft are prospective, and the stored wire/profile measurement scope differs from the final evaluator (draft:571,687–710).

### 4.2 Coordinates and HEAD facts needing correction

All destinations below were re-read at HEAD. Old coordinates labelled `(a0384e4)` can remain historical references, but draft:806's “not moved since” is false. `(review)` coordinates are not current HEAD evidence.

| Draft coordinate / claim | HEAD correction |
|---|---|
| execution-program/3 at :460; execution-program/4 as future seed schema at :477,750 | Current schema **/4** (`dst_program:119–152`), already introduced for WakeIdentity. Future seed/cache schema must not reuse that identifier. |
| `dst_program:229` as ExecutionProgram | **243–252** is ExecutionProgram;229 is DiscoveryConfig. InitialWorld remains182–188. |
| `dst_interaction:218,260,287` as old identity/interaction locations | Identity body projection211–224; causal identity228–235; Interaction297–302.218 is EnvironmentReadIdentity projection;260 is OutcomeMissing label;287 is missing-outcome literal. |
| `dst_replay:679,723,793` | script_of681; tools_of761; world_state_of831.723 is inside wakes_of. approvals_of745 / ext_effects_of792 must also be included in the current queue audit. Strict findings395 and reconstitution580 remain useful current coordinates. |
| `stub_step:271,554,731` | scripted_ports338; recording_ports621; chunked_prose_step803. Sum69, conversion72–90 and recording_model_step464 remain valid. F6 explanation is now321–337. |
| provider codec `ports:2245–2295`; cross-ref :2245,:2272,:2315,:2346 | Provider encode/decode2461–2507; exhausted2476; tool encode2531/decode2562. The old ranges concern generation/approval logic, not the provider outcome codec. |
| unknown tool status convention `ports:616–621` | Those lines define ToolInvocation. ToolOutcome647–655; ScriptedTool's status convention is above it in586–615. Preserve -1 as synthetic unknown, not source exit status. |
| `Ports.model_step:824` | Current field **886**; tool_exec1024.824 is not the model-step field. |
| `thinking_usage_kvs:1071–1085` | Current **1362–1374**; usage summary1348–1359. Optional positive cache emission is still real. |
| policy env/context `session:2310–2325` | Current init2350–2388, env reads2352–2355, context2360, checkpoint disabled2376. |
| injected-user `session:3080–3110` / retry3485–3518 | Current loop InjectUserMessage3409–3441 / provider retry3862–3921. Earlier ranges are other state/policy branches. |
| lastfinish explanation `step_machine:122–150` | Extend through159 and inspect result-to-state classification in session4020–4138. The cited range itself already shows selective injection and open-wait local budget checking. |
| `check_bounds` at dst_program649 / brief and cross-refs | No such exported function. Name is **validate_bounds:648–653**, not called by validate_program589–596. `max_resource_size` is not checked there; max_payload_bytes counts only outcome.payload. |
| Journal fold1558 and all_entry_types | Current fold1557; all_entry_types1173 (still ten journal entry types). messages_json377/messages_of_json550. |
| `JournalFold:247` as source transcript comparison |247 is the family constructor. Function1991–1997 compares replay trace fold with x.final; source comparison is additional evaluator code. |
| Manifest sketch config/fields | normalized_configuration is **string**; required classifier_2_set/scan_roots/scan_root_commit must be supplied. No dedicated ailang_binary_hash field (`dst_profile:1474–1491,1535–1572`). |
| API conversion “strip openrouter/ except auto” | Correct only for that branch. Current function also strips openai/anthropic/google (`session:272–292`). Pass logical model at entry; converter is not universally idempotent: openrouter/openai/gpt-4o → openai/gpt-4o → gpt-4o on two conversions. |
| Corpus ignore “at HEAD (checked a0384e4)” | Historical check is insufficient evidence for HEAD. This review's `git check-ignore .motoko/eval-corpus/example` exit1 independently confirms no match at the reviewed basis. |

Valid carried coordinates include session988,707,930,1540,2493,2534,2664,2760–2795,3351–3352,4239,4423,4445,4612,5346; ports1677–1698,1730–1731,2010–2022; persistence544,591,615,663–668,1095,1113,1304,1344; secrets287,337,439,530,589; discovery374,529,583; manifest1535; fixture226,257,298–302,636,651,708,737–781 and ledger frame432. Their valid locations do not validate the surrounding stronger claims. Raw/canonical framing ranges phase_vocab275–300,321–358,369–370 and model_phase17–43/tool_phase277–296 still support the described boundaries.

### 4.3 New mechanisms and overclaims

| V3 assertion | Correction / implementation consequence |
|---|---|
| “Composed from exported core pieces” | Two listed chunk helpers and tool_outcome_record are private; success delegation avoids widening exports (§3.3). |
| “Exactly N”; finish cutoff complete; stopped call finalizes | Conditional on reached loop states and no earlier end. classify_candidate/hybrid/pending/waits, not provider finish alone, determine behavior (§3.2). |
| Every tool/provider mismatch fails end | Provider failure ends; a tool failure can become a tool transcript and still suspend at N. K2/chain must reject independently (`tool_phase:277–296`). |
| Exhausted payload represents complete nonretryable replay_exhausted | served:false is skipped, with no encoded AIError. This branch must not be admitted as a faithful served record (`dst_replay:687–697`; `ports:2476`). |
| Discovery runs all families / A2 is JournalFold against snapshot | Discovery needs explicit witness; thirteen invariant evaluation and separate source-chain/history comparisons remain needed (§3.1). |
| No check reads cumulative / no observed projection depends on cache | Local JournalFold reads counts; thinking/summary/runtime-status outputs expose omitted fields. Narrow checks and class explicitly (§3.8–9). |
| Raw tool arguments at seam | Arguments are already Json; define source decode and canonical serialization, plus malformed-input eligibility (§3.3). |
| Bounds make wider projections bounded | Structural validation skips them; payload bound omits request projections and other resources (`dst_program:589–596,627–653`). Runtime guard is separately necessary. |
| No anchor/golden/gate bill | Semantic frame goldens need not change; physical insertion can require profile/attribution/bridge pin reissues. State edit strategy and validation (§3.4). |
| Lying core excluded by path / reshaping always visible / marker proves C | Candidate ports/session regions require protection/review; witness completeness is limited; marker evidence is conditional (§3.7). |
| “Not built: a verifier, comparison walk, corpus format, refusal vocabulary” | No second generic strict comparator is needed. A1–A8 source admission verifier, chain comparison, JournalWorld/entry artifact wrapper and new refusal/end/frame/chain findings are still evaluator mechanisms (draft:505–536,633–650,687–694). |
| Precise rules admit ordinary-path real programs | Entropy relaxation helps six path sites but four prefix hits still refuse r2.1; name-axis and complete corpus scan coverage require an explicit policy (§3.6). |
| Old 300-call/57 profiles establish new gate inputs | r2.1 has only299 complete turns; both old57 runs have58 calls with a terminal append. Calibrate the final finite-turn evaluator, not its old terminal-augmented proxy (§4.1; draft:708–710). |

## Required changes for v4

1. **D1/D2:** replace last-finish eligibility/end derivation with a complete T0 result-to-state and stopping contract. Specify positive N, no earlier completion, complete tools, valid continuation, no retry/injection/replacement/park/wake, and explicit verification/context/system/persist settings. Document r2.1's 299-complete-turn limit (§3.2).
2. **D1/D2:** copy the full HEAD provider conversion, pass logical model into session, convert exactly once, and correct all schema /3 and future /4 claims. Describe seed/cache bumps as versions later than current /4 (§3.3,5; §4.2).
3. **D2:** choose an implementable seam recipe, preferably guarded success delegation plus projection replacement, and use the same custom ports on admission and candidate replay. Specify complete honest failure recording/classification, with no empty-queue live fallthrough and no admitted exhausted-marker/AIError ambiguity (§3.3).
4. **D3/D4:** add explicit scenario-specific DiscoveryWitness construction, all known-key branch/multiplicity expectations, execution_of/evaluate/family_evidence and evaluated-versus-exercised reporting. Retain zero approval/effect observations for empty registry; do not inherit the rich fixture's approval witness (§3.1).
5. **D3:** keep local JournalFold-to-final invariants and separately define source fold/chain/history/count comparisons. Add candidate manifest/profile/toolchain/corpus/settings preflight and a defined mapping for new source/frame/end/chain/refusal findings. Rename validate_bounds and state its actual limited coverage (§3.1,8; §4.2–3).
6. **D1/D3/D7:** define the decoded-JSON tool-argument boundary and source normalization/refusal rules. Exclude or support generated MotokoRuntimeStatus and any other tool bypassing the queued seam. List cumulative/cache thinking/summary/runtime-status fields as unreproduced where applicable (§3.3,8,9).
7. **D5/D8:** specify protected core regions, full assembly/import/compatibility identities and conditional meaningful marker evidence while retaining cooperative review assumptions. Price intentional anchor/profile/fixture/bridge pin changes or specify line-neutral edits; preserve C's session core (§3.4,7).
8. **D6/D8:** state that the current retained prefix policy refuses r2.1 and name an admitted dev entry or a separately reviewed contextual scan policy. Cover snapshot/excerpt/program/env/files/metadata/derived output and decide CredentialBearingName. Report findings as findings, without claiming credentials from substrings (§3.6).
9. **D4/D8:** define external seed loading/folding and a practical recursion measurement boundary inside the named process; include stopping/check overhead consistently. Correct exact-versus-rounded repeat deviations and attribute the historical large-seed measurement accurately. Require guarded final-evaluator calibration/control rejection before any new budget pin (§4.1).
10. **All / P1:** repair the HEAD coordinate audit and remaining categorical claims, especially allegedly unmoved modules, exported helpers, all-family discovery, source-comparand JournalFold and deleted verifier/corpus/refusal work. Keep O7 and leave existing production journal/resume/park/conversation debts outside this ADR (§4.2–3).
