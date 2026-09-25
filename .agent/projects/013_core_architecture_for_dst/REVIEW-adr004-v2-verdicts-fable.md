# ADR-004 v2 review — can DST strict replay be married to the ADR-003 journal?

Date: 2026-09-14
Reviewed HEAD: `d5edebf` (branch `arniwesth/013-plan003-and-herdr`); ADR coordinates re-read at `a0384e4` with `git show` where cited as such
Subject: `ADR-004-journal-as-evaluation-source.md`, Proposed v2, untracked
Prior: `REVIEW-adr004-verdicts-codex.md` (v1), `REVIEW-adr004-v2-verdicts-codex.md` (v2, *return for v3*, four blockers)
Question asked by the owner: whether DST strict replay and the ADR-003 journal can be married.

Read in full: ADR-004 v2, both Codex reviews, ADR-003 v6.1, the P2D handoff, the RSI design doc. Read in code: `dst_program`, `dst_replay`, `dst_interaction`, `dst_persistence`, `dst_secrets`, `step_machine`, `ports`, `test/stub_step`, `session` (`ported_provider`, `c2_suspend`, `TracedSessionResult`), `journal.all_entry_types`, `dst_invariants` (`JournalFold`), `scripts/dst/strict_replay_dst.ail`, and the prototype `mem_journal_replay.ail` in `../motoko_agent-mem`. Nothing was run, edited or committed except this file.

## Overall verdict

**Yes, they can be married, and the ADR should choose the marriage instead of O4's parallel machinery.** ADR-004 v2 treats DST strict replay as a different thing ("live sessions never produce a program") and then rebuilds most of it: a new provider variant, custom adapters, a private verifier with five checks, a private digest copy, an identity record, a corpus format, and a refusal vocabulary. The existing harness already has each of those, typed, versioned and tested, and its replay loop already enters through `run_v2_session_traced`. What the ADR is missing is one option it never lists:

> **O7 — Record an `ExecutionProgram` at admission by replaying the journal segment through `RecordingWorld`, offline; strict-replay every candidate against that program.**

O2 (record a program on the *live* path) is correctly rejected. O7 records the program from the *replay* of the journal, so nothing touches the live path or the frame gates. The journal snapshot and the host-log excerpt are the oracle for that one admission run (C1, C2, C3 as the ADR defines them); the recorded program is the reproduction unit every candidate is graded against, with the harness's own comparison, witnesses, refusals, manifest, persistence and secret gate. This is the same two-stage shape `strict_replay_dst.run_scenario` already runs: a discovery run produces the program (`:708`, `program_of(discovery.world.log, initial)` at `:636`), and the replay is graded against it (`:737–781`).

The marriage is not free. Five concrete gaps are listed in §3; two of them (seed history not in the program, the live fall-through on an empty tool queue) are decisions the ADR must make, not implementation details. The marriage also settles two of Codex's four v2 blockers by construction (§4).

**Return for v3**, with the required changes in §5. Codex v2's four blockers stand; this review does not repeat its D1/D6/D7/D8 findings, which I checked against the code and agree with.

**Corrected after first issue (same day), on two points a second pass found wrong:**
- The `PortedWorld(Ports, WorldState)` variant **is** needed. `RecordingWorld(w)` normalises to `recording_ports(rt)` and cannot carry custom ports; `Ported(p)` normalises to `empty_world_state()` and cannot carry a world (`session.ail` `ported_provider`, HEAD). The fail-closed adapters therefore need the variant v2 proposed. What v2 got wrong is the adapters' content, not the variant: they should be `recording_ports` with two evaluator-owned seams, not a from-scratch set (§3 gap 4, §5 item 2, corrected below).
- `encode_artifact` cannot persist a journal-sourced program. `scan_text`'s `OpaqueHighEntropy` rule fires on any 32+ character run of the credential alphabet holding an upper, a lower and a digit (`dst_secrets.ail:280–352`), which an ordinary repository path satisfies. It was written for synthetic programs. The evaluator must assemble the artifact from the exported `encode_body` and `program_digest` under its own scan policy; `load_program` verifies the digest and does not rescan (`dst_persistence.ail:1113`) (§1 table, §5 item 5, corrected below).

## 1. What the harness already provides, verified

Every row is a thing ADR-004 v2 proposes to build in D2, D3, D5 or D6.

| ADR-004 v2 proposes | Already exists | Where |
|---|---|---|
| D2 `PortedWorld(Ports, WorldState)`: a world-bearing provider with adapters | The world-bearing shape: `RecordingWorld(WorldState)`, normalised as `{ ports: recording_ports(rt), world: world }`. **The variant is still needed** to install evaluator adapters with a world (see the correction above); its ports should be `recording_ports` with two seams, not a new set | `stub_step.ail:69` (a0384e4); `session.ail` `ported_provider` (HEAD) |
| D2 replay through the production traced entry | Strict replay enters through `Session.run_v2_session_traced(..., RecordingWorld(w))` | `scripts/dst/strict_replay_dst.ail:298–302` |
| D2 provider adapter that consumes the cursor on every call and returns finish reason, usage and tool calls | `recording_model_step` wraps the `scripted_ports` cursor (consumed on success and fault, F6 honoured) and records the whole `StepResult` as the outcome | `stub_step.ail:464–520` (a0384e4); `ports.encode_provider_outcome:2245` |
| D2 tool adapter validating call id, returning a typed mismatch | `world_tool` consumes an ordered queue; `scripted_tool_outcome` returns `ToolCorrelationMismatch({expected_id, got_id})` on an id mismatch; the recorder logs `ToolIdentity(origin, call_id, name)` | `ports.ail:1676–1731`, `:2010–2022` (HEAD) |
| D3 C2/C4 "exact count up to the cutoff", "exact sequence of invocations" | `strict_replay_findings`: `WrongKind`, `WrongOrigin`, `UnsafeIdentity`, `ProjectionDiffers`, `OutcomeDiffers`, `ProgramExhausted`, `UnusedInteraction`, positioned; exhaustion and unused are fatal in both modes | `dst_replay.ail:395`, `ReplayMismatch` (a0384e4) |
| D3 `Diverged { position, check }` with no measurement credited | Strict mode stops at the first mismatch; `RegressionMode` records projection differences and continues, for diagnosis | `dst_replay.ail` walk and `regression_replay_findings` |
| D3 "the candidate's own digests are not trusted" | `check_discovery` grades the replayed run's ledger trace against its interaction log, class by class, two-sided — the defence against "the recorder grading itself", which O4 has no counterpart for | `dst_discovery.ail:529`; `strict_replay_dst.ail:781` and axis H |
| D2 fail-closed world reconstruction | `world_state_of` refuses `ProgramStructurallyInvalid`, `ProviderOutcomeUndecodable`, `ToolOutcomeUndecodable`; `reconstitution_balance` checks under- and over-filled queues both ways | `dst_replay.ail:580`, `:793` (a0384e4) |
| D5 "identities per result" | `ExecutionManifest`: `source_revision`, `toolchain`, `extension_packages`, `abi_version`, `profile_id/version`, `event_vocabulary_version`, `normalized_configuration`, rule versions; validated against the profile before the world is built (axis B) | `dst_profile.ail` (a0384e4); `strict_replay_dst.ail` header |
| D5 "changing the evaluator changes the basis; re-admission" | `program_schema_version` with the D8 migration rule: a default is admissible only when the old version's semantics fixed the value, otherwise refusal; frozen specimen `execution-program-v2.artifact` | `dst_program.ail` header, `decodable_schema_versions` |
| D6 corpus entry with hashes, private handling | `encode_body` + `program_digest` produce the artifact; `load_program` decodes and verifies the digest. `encode_artifact`'s secret gate is **not usable as-is** for real content (its entropy rule fires on ordinary paths, see the correction above); the precise rules (`ProviderTokenLiteral`, `UrlUserinfo`, `PrivateKeyBlock`, `JsonWebToken`) can be applied by the evaluator as refusals and the entropy rule as a report | `dst_persistence.ail:544`, `:591`, `:615`, `:663`, `:1113`, `:1344` (HEAD) |
| Not decided: redaction | `redact_env_map`, `redact_interactions` exist for artifacts recorded from live runs, with a reported trajectory cost | `dst_secrets.ail:530`, `:589` (HEAD) |
| D3 C2 transcript chain | `JournalFold` is an invariant family at HEAD: fold the trace's journal-class records and compare with `final` | `dst_invariants.ail:247` |
| D2 "no terminal message is synthesised", D8 "premature termination" | ADR-003's typed suspension: `call_model_or_fail` checks `step_idx >= step_budget` **before** `CallModel`, so `step_budget = N` makes exactly N provider calls and ends in `RunSuspended` via `c2_suspend`, `result: Err(StepBudgetExhausted)`, `suspended: Some`, `final` populated | `step_machine.ail:103–111`; `session.ail:2760`, `:3351–3352` (HEAD) |

The last row is the ADR-003 half of the marriage and is independent of the program question. It is the answer to Codex v2 blocker 2: no sentinel call is prepared, no fabricated terminator is served, and the expected end of every admitted segment is a typed, checkable outcome (`TermMaxSteps` at exactly N). The evaluator must read `final.history` and `suspended`, not `result`: the prototype's `Ok(ms)` arm (`mem_journal_replay.ail:150`) never fires on a suspension.

## 2. The marriage, stated

**Admission (once per corpus entry, at admission commit A).**
1. D1 extraction as in v2: fold the prefix for the seed; take assistant turns, finish reasons and usage from the journal plus excerpt; tool results by call id; declared synthetic env/clock values.
2. Build a `WorldState` from it: `script: [ScriptedStep]` (prose, tool calls, finish reason, tokens; `chunks: []`), `tools: [ScriptedTool]` (call id, content, `exit_code: -1`, `duration_ms` 0 or declared), `env`, `clock_ms`. This is `base_world`'s shape (`strict_replay_dst.ail:257`).
3. Run the **parent** through `run_v2_session_traced(..., seed, ..., step_budget = N, ..., RecordingWorld(world))` with two fail-closed wrappers (§3, gaps 3 and 4).
4. Grade that run against the source: C1 (fold and seed digest), C2 (chain of the trace's `HistoryAppended` records from the seed digest against `digest_after`), C3 (per-call `payload_digest`, `system_prefix_digest`, model modulo the pinned routing conversion, `msg_count`, exact count, against the excerpt), the framing, and `check_discovery`. Expected end: `RunSuspended` at N.
5. `program_of(world.log, initial)` with a manifest, bounds set to the observed maxima, and `messages_and_policy` carrying the seed's digest and the selector (gap 1). `persist_program` into the corpus entry beside the snapshot and excerpt. `SourceFaithful` admission is the program's provenance.

**Evaluation (per candidate C).**
1. Refuse by path and intent as D3 says; refuse if the evaluator's runner or the corpus changed.
2. `world_state_of(program)`; `reconstitution_balance`; run C through the same entry with the same seed and `step_budget = N`.
3. `strict_replay_findings(program.interactions, run.world.log)`; `check_discovery`; the frame check; the terminal check (`RunSuspended` at N); C2 and C3 recomputed on the trace as cooperative cross-checks (gap 2).
4. Measure only when everything is empty. Otherwise `Diverged { position, mismatch }` from the harness's own vocabulary.

The candidate never sees the journal or the excerpt; it sees a program, which is what the harness already knows how to load, validate, replay and report on.

## 3. What the marriage costs — the gaps, verified

1. **The program does not carry the seed history.** `InitialWorld.messages_and_policy` is an opaque string (`dst_program.ail:183`); every fixture fills it with a description such as `{"messages":["system","user"],"policy":"driver_only"}` (`strict_replay_dst.ail:651` and six other scripts), and the replay loop takes its seed from a fixture literal (`history()`, `:226`). The validator requires only non-blank; `scan_program` scans it as text. Two choices: (a) bump to `execution-program/4` with a `[Message]` seed field, using the codec ADR-003 added (`journal.messages_of_json:550`), and pay the persistence suite and specimen; or (b) keep the seed in the journal snapshot, put its digest and the `RunSelector` in `messages_and_policy`, and make the **corpus entry** (snapshot + excerpt + program) the reproduction unit. (b) is the T0 answer; it must be said explicitly that the program alone is then not a reproduction unit in D11's sense, and that C1 is what turns the snapshot into the seed.

2. **The provider projection is model and message count only.** `recording_model_step` records `"model_step model=${model} msg_count=${N}"` (`stub_step.ail:481`, `:509` at a0384e4). `ProjectionDiffers` therefore cannot see a changed payload. C3 (canonical payload digest against the excerpt) is stronger and must stay. Either keep it outside strict replay as a cross-check on the trace's `provider_call_prepared` — cooperative trust, see §4 — or widen the recorder's projection with the digest, which changes every recorded program's projection strings and is a schema-version event by `dst_program`'s own rule. Recommend the cross-check at T0 and the widening as its own reviewed change.

3. **The tool projection has no arguments.** `recording_tool` records `"tool_exec call_id=… tool=… workdir=… timeout_ms=… started_at_ms=…"` (`ports.ail:2010–2022`); identity is `(origin, call_id, name)`. A candidate that rewrites arguments but keeps id and name passes strict replay. ADR-004 C4 checks arguments; keep that check, at admission against the journal and at candidate time against the trace, or widen the projection under the same rule as gap 2.

4. **An empty tool queue performs the real effect.** `world_tool`'s `[]` arm is the live arm (`ports.ail:1676–1697`, "No world opinion: perform the real effect"). Under plain `RecordingWorld`, a candidate that makes one tool call more than the recording executes it in `workdir`. The ADR's fail-closed `tool_exec` (D2) is right and is the one adapter the marriage still needs: a wrapper that returns `ToolFailed({code: "replay_unrecorded_invocation", …})` on an empty queue and otherwise delegates to `recording_tool`, so the interaction is still recorded and `ProgramExhausted` still names the position. The provider side has the mirror: `recording_model_step` serves `terminal_step()` on an empty script (the fabricated terminator v1 was faulted for). With `step_budget = N` that arm is unreachable on a faithful candidate, and `ProgramExhausted` names it on a divergent one; a wrapper returning a non-retryable `Err` is cheap and honest. The wrappers need v2's `PortedWorld(Ports, WorldState)` variant to be installed together with a world (correction above); they are not a `Ports` field, a production entry or a helped request. Composed from exported pieces (`record_interaction`, `world_tool`, `provider_outcome_record`, the outcome codecs), each is a recording adapter whose projection is wider than the core recorder's — which is also how gaps 2 and 3 close without re-baselining the recorded corpus: the evaluator's provider seam writes `payload=<canonical digest> raw=<frame digest> system=<prefix digest>` into `request_projection`, the tool seam writes `args=<digest>`, and `ProjectionDiffers` then checks them at every candidate run for free.

5. **Cache usage is not in the outcome codec.** `ScriptedStep` has no cache fields; `encode_provider_outcome` writes none; `scripted_to_step_result` zeroes both (`stub_step.ail:89–90`). This does not justify a new provider variant at T0: telemetry copies input and output tokens only (`model_phase.ail:17–25`, per the v1 review), the journal's `state_delta` carries the same two, and cost metering is off, so cache = 0 changes no observed projection. Declare it as the omission v2 already lists and widen `ScriptedStep` later; absence → 0 is an admissible default by the D8 rule because the old semantics fixed it at 0.

Two further points that are not gaps but must be stated:

- **Why the program is recorded and not derived.** The traced entry makes requests the journal never records — the policy-init environment read, clock advances — and `world_state_of` needs every class the driver will ask for, with `ProgramExhausted` and `UnusedInteraction` fatal in both modes. Deriving a program from the journal alone would refuse at position 0. The admission run records those interactions from the declared synthetic world, which is exactly D1's "declared synthetic values listed in the envelope", now as typed interactions the candidate must match.
- **Bounds are not a blocker.** `validate_program` (`dst_program.ail`, HEAD) does not call `check_bounds` (`:649`); bounds are a generator-failure check and travel with the program as data. An admission run declares its own.

## 4. How the marriage bears on Codex v2's four blockers

| Codex v2 blocker | Under the marriage |
|---|---|
| 1. The overlay protects files, not observations; candidate core owns the world log | **Settled by choosing DST's trust model.** Strict replay compares `discovery.world.log` with `replay.world.log`, both candidate-carried, and defends with witnesses over the trace (axis H), not with isolation. Marrying makes ADR-004 D5 inherit that model explicitly: cooperative, reviewed candidates; file pins and hashes protect the runner and corpus; nothing claims adversarial enforcement. This is what Codex asked for and what the rest of the DST architecture already assumes. The overlay-granularity problem in `session.ail` disappears with `PortedWorld`. |
| 2. Exhaustion adds an uncounted call | **Settled by ADR-003's suspension.** `step_budget = N` (§1, last row). The measurement scope is "the traced run to `RunSuspended` at N", with no sentinel traffic to count separately. |
| 3. Model strings from different boundaries | **Unchanged.** `ProviderIdentity`'s model is what the adapter receives, the API name; the excerpt's is the routing name. The admission derivation needs the pinned conversion Codex specified, and the program then carries the API name as identity. |
| 4. Zero-start classification | **Unchanged**, a D1 matter. Note that `run_v2_session_traced` passes zero prior counts; r2.1's message-only start with cumulative 350/342 needs either the counts-carrying entry or a refusal at T0. |

## 5. Required changes for v3

1. **Options.** Add O7 as stated in §2 and choose it. Keep O2 rejected for the reason given. Record why the program is recorded at admission rather than derived (§3, "why recorded").
2. **D2.** Keep `PortedWorld(Ports, WorldState)`; its ports are `recording_ports(rt)` with the two evaluator seams of §3 gap 4 (fail closed on an empty cursor; wider projections carrying the private digests). Specify the journal-derived `WorldState` (script, tools, env, clock), `step_budget = N`, and the expected end: `RunSuspended` at N when the last recorded call carried tool calls, `Finalize(model_stop)` when it stopped; cut one call earlier for any other last finish reason, because `decide` injects a message before the budget check. Read `final.history` and `suspended`, never `result`. Serve cache = 0 as a declared omission (gap 5).
3. **D3.** Split the checks into admission checks (C1, C2, C3 against the excerpt, C4 against the journal, framing, witnesses, terminal) and candidate checks (`strict_replay_findings`, `reconstitution_balance`, `check_discovery`, framing, terminal, plus C2/C3/C4 recomputed on the trace as cooperative cross-checks). Map `Diverged` to `ReplayMismatch` positions. Name gaps 2 and 3 as the projection's known blind spots beside the canonical ones already listed.
4. **D5.** State the cooperative trust model in DST's terms. Identities become the `ExecutionManifest` plus snapshot hash, excerpt hash, selector and program digest. The evaluator overlay reduces to the runner script, the pinned digest functions and the corpus.
5. **D6.** The corpus entry is snapshot + excerpt + program artifact, assembled from `encode_body` and `program_digest` under an evaluator scan policy (precise rules refuse, the entropy rule reports) and loaded with `load_program`. Decide gap 1 (recommend (b)). Point "Not decided: redaction" at `redact_interactions` and its trajectory-cost report.
6. **D8.** P1 shrinks to: the D1 reader, the world builder, the two wrappers, the admission runner, and the C2/C3/C4 cross-checks; strict replay, witnesses, persistence and manifest are not built. Keep P0, P2 and the regression control as Codex corrected them.
7. **Housekeeping.** The status line says v2 is unreviewed; `REVIEW-adr004-v2-verdicts-codex.md` returns it with four blockers. Re-pin coordinates to HEAD: `session.ail` has grown by over a thousand lines since `a0384e4`, and the facts this marriage relies on (`c2_suspend`, `final`, `JournalFold`) are HEAD facts. `journal.all_entry_types` is still ten types with no park or wake at HEAD, so the `ParkOrWake` refusal row stands.

## 6. Claim audit — what was checked and how

| Claim in this review | How checked |
|---|---|
| Strict replay enters through `run_v2_session_traced` with `RecordingWorld` | `strict_replay_dst.ail:298–302`, read |
| `RecordingWorld(w)` normalises to recording adapters over the supplied world | `ported_provider` at HEAD, read |
| Recorder projections carry model + msg_count (provider) and id/name/workdir/timeout/started_at (tool), no payload digest, no arguments | `stub_step.ail:481`, `:509` (a0384e4); `ports.ail:2010–2022` (HEAD), read |
| Outcome codec carries prose, finish reason, tokens, tool calls, error; no cache fields | `ports.ail:2245–2295` (a0384e4), read |
| Empty tool queue performs the real effect | `ports.ail:1676–1697` (HEAD), read |
| Empty script serves `terminal_step()` and records `script=exhausted` | `stub_step.ail:464–490` (a0384e4), read |
| Step budget is checked before `CallModel`; suspension is typed and lands `final`/`suspended` | `step_machine.ail:103–111`; `session.ail:2760–2795`, `:3338–3352`; `TracedSessionResult` (HEAD), read |
| Seed history is not in the program; `messages_and_policy` is descriptive text | `dst_program.ail:183`; seven fixture literals; `strict_replay_dst.ail:226` |
| Bounds are not enforced by `validate_program` | `dst_program.ail` `validate_program` body and `check_bounds:649` (HEAD), read |
| Secret refusal and redaction helpers exist | `dst_persistence.ail:615–670`; `dst_secrets.ail:530`, `:589` (HEAD), read |
| `JournalFold` family exists | `dst_invariants.ail:247` (HEAD) |
| No `PortedWorld` at HEAD; exhaustive `StepProvider` matches to extend | `grep -rn PortedWorld src/ scripts/`, empty; `RecordingWorld(` consumers: `session.ail:1540`, `ledger_parity_dst.ail:432` |
| The secret scanner's entropy rule fires on ordinary paths | `dst_secrets.ail:280–352`, read: alphabet includes `/ . - _`, threshold 32, needs upper+lower+digit |
| `load_program` verifies the digest and does not rescan | `dst_persistence.ail:664` is the only `scan_program` call; `:1113` verifies the digest on decode |
| Codex v2's evidence figures (digest counts, GiB, profiles) | **Not re-verified**; taken as reported. |
| The prototype's cursor and terminator defects | `mem_journal_replay.ail:96–97`, `:106`, `:150` in `../motoko_agent-mem`, read; agree with both Codex reviews |
