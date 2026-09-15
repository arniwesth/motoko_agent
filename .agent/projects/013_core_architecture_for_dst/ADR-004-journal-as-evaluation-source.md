# ADR-004: A session journal is an evaluation source — an execution program recorded from its replay at admission, strict-replayed by every candidate, graded by an evaluator the candidate does not own

Date: 2026-09-13 (v1, v2), 2026-09-14 (v3, v4)
Status: **Proposed (v4 — folds the v3 Codex review's ten required changes; unreviewed).**
v3 was reviewed by Codex (`gpt-5.6-sol`, `REVIEW-adr004-v3-verdicts-codex.md`, HEAD
`d5edebf`): *return for v4; retain O7*. It found the marriage feasible — the replay loader
rebuilds its queues from recorded outcome payloads, not from request projections, so an admission
log with private wider projections is an ordinary program — and returned D1, D2 and D3 on four
design errors: the last-finish rule, the seam recipe and schema facts, the witness and invariant
contract, and the scan policy. D4–D8 were accepted with corrections. v2 was reviewed by Codex
(`REVIEW-adr004-v2-verdicts-codex.md`) and Claude Fable (`REVIEW-adr004-v2-verdicts-fable.md`);
v1 by Codex (`REVIEW-adr004-verdicts-codex.md`).
Code coordinates are at HEAD **`d5edebf`**, re-read for v4, unless marked *(review)* — verified
by a review, not re-read here. Every module the v3 review found to have moved since `a0384e4`
is re-pinned below; no coordinate is carried as "not moved since".
This ADR still changes nothing in ADR-003: the journal format, writer, fold and resume are
untouched. It changes one thing in the DST harness: one `StepProvider` variant (D2).

---

## Version history and retractions

**v1 → v2.** What v1 got wrong, in the order of the review's required changes:

1. *"D1 reads everything the replay needs from the journal."* It does not.
   - The journal has no per-call finish reason, cache usage or failed-call outcome.
   - `[Message]` alone cannot rebuild a continuation start (telemetry, counts, artifacts, nudges).
   - v1's end list missed retries, `suspended`/`resumed`/`settings` boundaries, partial tool
     batches, runtime-injected user messages and `replaces_previous` turns.
   - v2's D1 takes the missing per-call data from a **host-log excerpt**, refuses continuation
     starts at T0, and names exact selectors and typed cutoffs.
2. *"`Ported(journal_ports(world))` loads the world."* It does not: `ported_provider` normalises
   `Ported(p)` to `empty_world_state()` (`session.ail:1492–1495` *(review)*).
   - v1's tool port served results by call id, did not validate the invocation, and
     manufactured `exit_code: 0`.
   - The prototype also fabricated a terminal "replay done" turn.
   - v2's D2 adds an explicit world-bearing test-provider variant and fails closed.
3. *"Chain plus payload digest is a complete validity oracle; requests were byte-identical."*
   Retracted.
   - Both digests pass under changes to model and parameters, tool schemas, bypassed prompt or
     extension builders, and the evaluator's own code.
   - In the evidence, all 300 replayed `model` fields (`probe/model`) differ from live, yet every
     digest matched.
   - v1's `Faithful` also conflated live fidelity with agreement with the parent commit.
   - v2's D3 declares an admissible candidate class and a validity envelope, separates
     `SourceFaithful` from `ParentAgreement`, and credits no measurement past a divergence.
4. *"Allocation repeats within ±0.2%, in GB."* The totals are **GiB**. Maximum observed
   deviation over three repeats is 0.115% at baseline and 0.279% with the fix, so it is not a
   tolerance. RSS values are MiB. GC count and live heap depend on timing. v2's D4 pins a
   measurement scope.
5. *"The journal, host log and digest definitions are external to the candidate."* The digest
   definitions, reader, adapters and verifier are repository code a candidate can edit, and a
   gitignored directory is writable by the same user. v2's new **D5** puts the evaluator at a
   pinned commit, overlays it on the candidate tree, and refuses candidates that touch it.
6. *"Tier omissions stated per tier."* They were not cumulative.
   - T2 needs observations that neither the journal nor the host log records.
   - The streaming statement inferred cost from event counts.
   - The compaction statement was categorical.
   - v2's D7 makes omissions cumulative and scopes both statements.
7. *"Admit the 299-step entry at P1, then build a 100-step gate; guard with `MemAvailable`."*
   Wrong order and wrong guard.
   - The handoff's rule is about aggregate cgroup `memory.current`, not per-process RSS.
   - v1's P2 fixed 100 steps while its Not decided left the length open.
   - v2's D8 guards and calibrates short runs first, pins exact counts, shows the gate rejects a
     known regression, and admits long entries last.
8. *Evidence errors.*
   - "299 steps" was 299 recorded turns plus one synthetic terminal call, so 300 requests. The
     prototype checker compared only the shorter prefix.
   - The 1,756 digest tally was an addition error: the nine result-matched runs hold **1,806**
     digests (1,948 including the new session's two pairs). The error is repeated in `de4b4f5`'s
     commit message.
   - "Nine hooks ran" should be nine *loaded* extensions.
   - "Synthetic fixtures are small" is overbroad: `long_qwen_compaction_dst` has a
     1,050,218-byte seed event.

**v2 → v3.** What v2 got wrong, in the order the two reviews found it:

1. *"DST strict replay reconstructs a world from an `ExecutionProgram` recorded by adapters bound
   only in the harness; live sessions never produce a program."* True, and beside the point. A
   program can be **recorded from the replay of a journal**, offline, by the discovery-then-replay
   shape `strict_replay_dst.run_scenario` already runs (`scripts/dst/strict_replay_dst.ail:708`,
   `program_of` at `:636`, the replay graded at `:737–781`); nothing touches the live path or the
   frame gates. v2's O4 rebuilt the harness's comparison (`strict_replay_findings`,
   `dst_replay.ail:395` *(a0384e4)*), its refusals (`ReplayRefusal`, `ProgramRejection`), its
   reconstitution check (`reconstitution_balance`, `:580`), its witnesses (`check_discovery`,
   `dst_discovery.ail:529`), its manifest (`ExecutionManifest`), its persistence and its mode
   split under new names. v3 chooses **O7** and deletes those from P1.
2. *"The overlay makes the checks unrewritable by the candidate."* File independence, not
   evidence integrity (Codex blocker 1): candidate core owns the world and its log and returns
   both. Strict replay compares two candidate-carried logs and defends with witnesses over the
   trace, not with isolation. v3 adopts that trust model — cooperative, reviewed candidates —
   and claims nothing adversarial (D5).
3. *"Past the cursor the adapter returns `Err(replay_exhausted)`."* Reached only through an
   N+1th prepared call (Codex blocker 2). v3: `step_budget = N`. `call_model_or_fail` tests the
   budget **before** `CallModel` (`step_machine.ail:103–111`), so the run ends in ADR-003's typed
   suspension after exactly N calls (`c2_suspend`, `session.ail:2760`, routed at `:3351–3352`),
   or in `Finalize(model_stop)` when the last recorded call stopped. The expected end is a check
   (D2, D3).
4. *"C3 compares the model string."* Two boundaries (Codex blocker 3): the live event carries the
   routing name (`ProviderCallPrepared.model`, before `provider_api_model`), the adapter receives
   the API name. v3 records both, with a pinned conversion in the evaluator (D1, D3).
5. *"Message-only starts have the ordinary entry's zero values."* Wrong (Codex blocker 4):
   `c2_initial_state_with_counts` (`session.ail:988`) derives `nudges_used` from the history and
   takes `prior_counts`; the delta preceding r2.1 reads 350/342. v3: nudges come from the seed
   as in production; `prior_counts` are served as zero because no **exported** message-only
   traced entry carries them (`:4423`, `:4445`, `:4612`) — the internal
   `run_v2_from_messages_traced_with_policy_and_counts` (`:4239`) does, unexported, and the
   resumed entry does through a continuation (`:2664`, `:5346`) — and the replay's
   `state_delta.cumulative` is declared unreproduced: every site that reads `prior_counts`
   computes `cumulative` for reporting (`runtime_status_json:707`, `c2_state_delta_event:930`,
   `:2493`, `:2534`) and no check reads it (D1).
6. *"`cache_creation_input_tokens` is not logged."* Retracted: `thinking_usage_kvs` emits both
   cache fields when positive (`phase_vocab.ail:1071–1085` *(review)*); they decode as optional
   under the pinned producer contract. T0 nevertheless serves cache usage as **zero**: `ScriptedStep`
   and the provider outcome codec carry no cache fields (`ports.ail:2245–2295`), no observed
   projection depends on them, and widening the codec is a schema event taken later (D2).
7. *"Association by `(run, step)` fields."* The request, result and retry events carry
   `session_id` and `step`, not `run_id`; `session_start` comes in two shapes (Codex D1). v3
   associates in order from the banners (D1).
8. *"Typed segment ends", one list.* It mixed cutoffs with refusals, cut every user message
   including the leading one, and had no reason for a genuine completion (Codex D1). v3 splits
   them and adds the rule the suspension end needs (D1).
9. *Tool constructors.* `ToolFailed` and `ToolCorrelationMismatch` take records (`ports.ail:650`).
10. *"The 57-call replay went from 2.05 to 1.61 GiB."* The named profiles read **2.002150** and
    **1.572677 GiB**; both runs made **58** provider calls and appended **115** messages including
    a synthetic terminal turn (Codex §3.3). The recompilation explanation for the 22.12 GiB
    outlier is a hypothesis (D4, D8).
11. *T2b and T3.* T2b removes operator input from the inherited refusal; T3 is a separate live
    experiment, not a replay tier (D7).
12. *A new variant — and, briefly, no variant.* v2 proposed `PortedWorld(Ports, WorldState)` with
    a from-scratch adapter set; the Fable review first said the variant was unnecessary because
    `RecordingWorld` is world-bearing, then corrected itself: `RecordingWorld(w)` cannot carry
    custom ports (`session.ail:1540`) and `Ported(p)` cannot carry a world (the first arm of the
    same match).
    v3 keeps the variant and drops the from-scratch set: its ports are `recording_ports` with two
    evaluator-owned seams (D2).
13. *"`persist_program` handles the corpus."* `encode_artifact` refuses any program whose text
    holds a 32+ character run of the credential alphabet with an upper, a lower and a digit
    (`dst_secrets.scan_text:337`, `opaque_run_threshold:287`); an ordinary repository path
    satisfies that. It was written for synthetic programs ("Programs contain synthetic values
    only"). v3 assembles the artifact from the exported `encode_body` and `program_digest` under
    an evaluator scan policy; `load_program` verifies the digest and does not rescan
    (`dst_persistence.ail:664` is the only `scan_program` call; `:1113` verifies on decode) (D6).
14. *Status and coordinates.* v2 said "unreviewed" after `REVIEW-adr004-v2-verdicts-codex.md`
    had returned it. `session.ail` has grown by over a thousand lines since `a0384e4`, and
    `c2_suspend`, `final` and `JournalFold` (`dst_invariants.ail:247`) are HEAD facts, so v3
    re-pins to `d5edebf`.

Not retracted: the pure reader, no ADR-003 change; the host-log excerpt as a required input;
the admissible candidate class by path and intent; the cumulative omissions; the cgroup guard;
short calibration before long admission; the corrected evidence table.

**v3 → v4.** What v3 got wrong, in the order the review found it:

1. *"The last recorded finish reason determines the loop's next decision."* False. The loop
   classifies the next state from the **result**: any tool call makes it a `tool_calls` state
   whatever the reported finish (`session.ail:4020`); a call-free response goes to hybrid
   extraction when `hybrid_tools` is set and no native call has been emitted in the session
   (`:4064–4066`), otherwise to `classify_candidate` (`:3255–3308`), which yields rejected,
   approved, await-wake, feedback or nudge. `decide` injects only for `dp7_rejected`,
   `solver_feedback` and `persist_nudge`; every other string reaches `call_model_or_fail`
   (`step_machine.ail:122–159`). v3's `NonReplayableLastFinish` cutoff is withdrawn; v4's D1
   and D2 state a **stopping contract** in terms of the states a call reaches (D1, D2).
2. *"`step_budget = N` makes exactly N calls, unconditionally, and nothing is synthesised."*
   Conditional. It holds when N is positive, the seed satisfies `continuation_history_ok`
   (`journal.ail:206`; `c2_suspend` routes to `c2_fail` otherwise, `session.ail:2778–2780`),
   every call before N is a continuation (tool calls with complete results), no injection, park,
   retry or replacement occurs, and the **T0 settings** hold: `rt.verification.enabled = false`
   (else `run_dp7_verifier` executes a real subprocess, `:2241–2254`), `MOTOKO_PERSIST_RETRIES =
   0` (else `should_inject_persist_nudge`, `recovery.ail:59`, injects after a call-free stop),
   `ohmy_pi = false` (else `backend_for_v2` can defer a tool as `Delegated`,
   `tool_phase.ail:452–464`), and a context limit under which `project` succeeds. The
   suspension, its `RunSuspended` event and the finalisation are synthetic parts of the simulated
   execution and are measured; what is not synthesised is an extra provider call or an assistant
   turn (D2).
3. *"The seams are composed from exported core pieces."* `scripted_chunks`
   (`stub_step.ail:136`), `play_chunks` (`:121`) and `tool_outcome_record` (`ports.ail:2087`) are
   private, as are `recording_model_step` (`:464`), `chunk_records` (`:540`), `provider_calls_in`
   (`:547`) and `scripted_tool_outcome` (`ports.ail:1729`). v4's seams are **guarded delegation**:
   a non-empty call is delegated to `recording_ports`' own `model_step` or `tool_exec`, and the
   appended interaction's `request_projection` is then replaced. No new export (D2).
4. *"On an empty script the seam records the interaction and returns a complete
   `replay_exhausted` error."* The exhausted payload is `{ served: false }` (`ports.ail:2476`)
   and `script_of` **skips** it (`dst_replay.ail:689`); it carries no `AIError`. v4: an empty
   cursor is a fatal finding — the seam records the exhausted marker so counts and
   `ProgramExhausted` see it, returns a non-retryable `Err`, and a run containing one is never
   admitted and is `Diverged` at that position; the marker never becomes a served record (D2).
5. *"`execution-program/3`; a seed field would be `/4`."* The current schema is **`/4`**
   (`dst_program.ail:119`, wake support). A seed or cache field is `/5` or later (D2, D7).
6. *"The pinned conversion strips `openrouter/` except `auto`."* It also strips `openai/`,
   `anthropic/` and `google/` (`session.ail:272–292`), and it is not idempotent
   (`openrouter/openai/gpt-4o` → `openai/gpt-4o` → `gpt-4o`). The entry receives the **logical**
   model and converts once at dispatch (`:3824`); the seam receives the API name; the evaluator
   copies the whole function (D1, D3).
7. *"`check_discovery` over the run's trace; every family runs."* `check_discovery` takes a
   `DiscoveryWitness` (`dst_discovery.ail:260–271`), which the runner must build; the fixture's
   approval-based witness (`strict_replay_dst.ail:366–378`) and its non-vacuity rule
   (`:792–795`) do not transfer to an empty registry. The thirteen invariant families are a
   separate call — `evaluate(execution_of(run, …))` (`dst_execution.ail:99–125`;
   `dst_invariants.ail:2010–2024`) with `family_evidence` (`:2036–2066`) — and several are
   vacuous at T0 and must be reported as such (D3).
8. *"A2 is `JournalFold` with the snapshot as comparand."* `journal_fold_findings` compares the
   fold of the run's own trace with `run.final` (`dst_invariants.ail:1991–1997`), including all
   five cumulative fields (`:1956–1969`). v4 keeps that family as it is — it passes with zero
   prior counts because the replay's own deltas carry zero-based counts — and adds a **separate**
   source comparison of history bytes and chain against the snapshot; counts are reported as an
   offset, never compared (D3).
9. *"No check reads `cumulative`; no observed projection depends on cache usage."*
   `JournalFold` reads `cumulative` (locally consistent, above). `runtime_status_json` exposes
   prior-plus-trace counts and cache totals (`session.ail:707`, `:757–763`) and is served as a
   built-in tool message before `tool_exec` (`:3670–3673`; `tool_phase.ail:562–564`); the
   `thinking` and summary wire events carry cache usage (`phase_vocab.ail:1348–1374`
   *(review)*). v4: a `MotokoRuntimeStatus` call inside a segment is a cutoff at T0 — r2.1 has
   none (tool census: BashExec 182, DelegateCheck 110, Delegate 5, ReadFile 2, WriteFile 1) —
   and the wire fields are listed as unreproduced (D1, D3, D7).
10. *"Tool arguments are raw bytes at the seam."* `ToolInvocation.call` is a `ToolCallEnvelope`
    whose arguments are already `Json` (`ports.ail:616–621`; `tool_dispatch_adapter.ail:46–56`
    *(review)*). A4 and K2 digest a canonical JSON serialisation; the journal's argument strings
    are decoded under the same rule and a malformed one is a refusal. r2.1's 299 argument
    strings all decode and equal their compact serialisation *(review)* (D1, D3).
11. *"Bounds keep wider projections bounded."* The function is `validate_bounds`
    (`dst_program.ail:648–653`), not `check_bounds`; it measures `outcome.payload` length only and
    `validate_program` (`:589–596`) does not call it. The cgroup guard is the limit (D2, D8).
12. *"One variant, three arms, no anchor moves."* A new line in `ported_provider`
    (`session.ail:1533–1545`) moves the anchored clock sites 1730, 1842, 4302 and 4523
    (`tools/predicate-anchors/anchors.sh:614–616`); a new import line near the top moves all
    five and the bridge span `1085–1474` (`tools/driver_leaf_inventory/derive.py:154`); a new
    line above `stub_step.ail:203` moves its `now()` anchor (`anchors.sh:593`). v4 prices this:
    the variant commit is **line-neutral** (the sum extended on its line, the arm and the import
    joined onto existing lines, as `stub_step.ail:44` and `tool_phase.ail:484` already do), or
    it re-baselines the anchors and the three profiles. `test/scripted_ports.ail:30–35` is a
    three-arm legacy match, not an exhaustive one (D2, D5).
13. *"The precise scan rules admit ordinary real content."* `ProviderTokenLiteral` is
    `Str.contains` over 23 prefixes (`dst_secrets.ail:217–229`) — `AKIA`, `AIza`, `Basic `,
    `Bearer ` among them — with no credential body behind it; four of r2.1's 299 tool outputs
    (sites 0, 96, 195, 228) hit it, so v3's policy refused r2.1 as surely as `encode_artifact`
    did. v4's D6 is a reviewed contextual policy that reports every finding and refuses on the
    shapes that carry a body (D6).
14. *"Not built: a verifier, a corpus format, a refusal vocabulary."* Overstated. Not built is a
    second comparison walk, a second reconstitution, a second persistence codec, a second manifest
    type. Built is the admission verifier, the source transcript comparison, the witness builder,
    the entry wrapper and the finding mapping (D8).
15. *Coordinates.* Modules v3 called "not moved since `a0384e4`" had moved: `ExecutionProgram` is
    `dst_program.ail:243–252` (`:229` is `DiscoveryConfig`); `CausalIdentity` `:228–235` and
    `Interaction` `:297–302` in `dst_interaction.ail`; `script_of :681`, `approvals_of :745`,
    `tools_of :761`, `ext_effects_of :792`, `world_state_of :831` in `dst_replay.ail`;
    `scripted_ports :338`, `recording_ports :621`, `chunked_prose_step :803`, the F6 note
    `:321–337` in `stub_step.ail`; the provider codec `ports.ail:2461–2507`, `encode_tool_outcome
    :2531`, `decode_tool_outcome :2562`, `Ports.model_step :886`, `tool_exec :1024`;
    `thinking_usage_kvs` `phase_vocab.ail:1362–1374` *(review)*; policy init `session.ail:2350–2388`,
    the injected user message `:3409–3441` *(review)*, the provider retry `:3862–3921` *(review)*;
    `fold_journal` `journal.ail:1557`, `all_entry_types :1173`. All re-pinned.
16. *Numbers.* The repeat deviations at full precision are **0.1158%** and **0.2774%** (v2's
    0.115% and 0.279% came from rounded TSV values). r2.1 has **299 complete turns**: the 300th
    assistant carries one tool call with no result, so D1's own rule cuts before it — 299 calls,
    299 tools, 598 appends; the prototype's 300th request was its synthetic terminator. The
    1,050,218-byte seed event is PLAN-003's attributed measurement (`PLAN-003:772–775`
    *(review)*); the stored outputs hold 1,050,377-byte lines. The corpus ignore rule was
    re-checked at HEAD (`git check-ignore .motoko/eval-corpus/example` exits 1).

Not retracted: O7; the pure reader; the excerpt as a required input; the seed in the snapshot;
the cooperative trust model; `PortedWorld`; the cumulative omissions; the sequencing.

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | **Extraction.** A pure reader turns an explicit journal segment plus a host-log excerpt into a seed, recorded calls, recorded configuration, the T0 settings and expected observations. Ordered association; cutoffs distinguished from refusals; a **stopping contract** in terms of reached states; both model names; arguments as canonical JSON | 2–3 days, evaluator |
| D2 | **Admission run.** A `WorldState` built from D1 is driven through `run_v2_session_traced` as `PortedWorld(ports, world)`, where `ports` is `recording_ports` with two **guarded-delegation** seams; `step_budget = N`; the run's interaction log **is** an `ExecutionProgram` at schema `/4` | 1–2 days: one line-neutral variant commit, two seams, a world builder, a manifest |
| D3 | **Checks and verdict.** Admission: fold, source transcript, requests, invocations, frames, end, a runner-built witness, the thirteen families with evidence, round trip. Candidate: preflight, then the harness's `world_state_of`, `reconstitution_balance`, `strict_replay_findings`, `check_discovery`, `evaluate`, frames, end, source transcript. `Reproduced`, `Diverged { position, finding }`, `Refused` | 1–2 days, evaluator |
| D4 | **Claims.** Cumulative profiled allocation of the named evaluator process is primary; GC, live heap, RSS and recursion depth secondary; no task-quality, latency or provider claims | — |
| D5 | **Trust model and identities.** Cooperative, reviewed candidates; witnesses, not isolation. Protected regions in candidate files pinned by hash. Identities: manifest, snapshot, excerpt, selector, program, assembly. Line-neutral variant commit | 1 day |
| D6 | **Corpus.** Private, ignored, `0700`. Entry = snapshot + excerpt + selector + program + expectations + envelope + identities + exposure log. A contextual scan policy over every component; findings reported, refusals named | 1 day |
| D7 | **Fidelity ladder, cumulative omissions.** T0 this ADR; T1 chunks, counts, cache (`/5`), continuation starts; T2 extensions as an investigation; T2b operator input; T3 live, separately | T1 2–3 days; T2 unscheduled |
| D8 | **Gate and sequencing.** Preserve, build, guard and calibrate, gate with a demonstrated rejection of a known regression, held-out process, long admission last | 2 days |

The number this ADR is judged on:
- A candidate in the admissible class is measured on a real session's workload, deterministically,
  with a verdict that names what was checked and what was not.
- A candidate outside the class is refused before it runs.
- A replay whose observations diverge is not scored.

## Context / the question

**Two of the three things called "replay" are the same thing, once the program is recorded from
the journal's replay.**

1. **DST strict replay** (`dst_program.ail:243–252`, `dst_replay.ail:395`, `:831`). It
   reconstitutes a world from an `ExecutionProgram` — an ordered list of `Interaction {
   identity: { ordinal, body }, request_projection, deadline_ms, outcome }`
   (`dst_interaction.ail:297–302`) — and requires a run to agree with it position by position.
   Its loop enters the **production traced entry**: `run_v2_session_traced(...,
   RecordingWorld(w))` (`scripts/dst/strict_replay_dst.ail:298–302`). The program does not
   carry the provider script or the tool queue; `world_state_of` derives both from the recorded
   **outcome payloads** (`script_of :681`, `tools_of :761`), never from the request projections,
   so a served response necessarily has a recorded interaction behind it. A program is produced
   by a **discovery run** through the same entry with the recording adapters (`:708`), and the
   harness knows its recorder can grade itself, so a replayed run is also graded by witnesses
   over the ledger trace (`check_discovery`, `:781`; axis H's fixture matches the program and
   fails the witness).
2. **The ADR-003 journal fold** (`journal.ail:1557`). A fold over history deltas for resume.
   ADR-003 O2 rejected *driver replay for resume* and kept replay "for reproduction". It says
   nothing about evaluation.
3. **Live A/B** (`.motoko/ab/muse-replay-20260907T185514Z/`). Realistic, nondeterministic.

What was missing is a discovery run whose world is built from a journal: its script from the
recorded assistant turns, its tool queue from the recorded results, its environment from
declared values. The interaction log of that run is a program in the harness's own format, and
every candidate is then a strict replay of it. The journal and the host log are the oracle for
that one run; the program is the reproduction unit for all the others.

**The gap** is as v2 stated. No existing fixture has the workload shape a real session produced:
a ~0.9 MB content history seed (1,170,593 bytes of default Python JSON for 694 messages;
903,364 bytes of content) growing over hundreds of tool turns with real tool-output sizes. The
memory defect fixed in `de4b4f5` scaled with history bytes. Two workloads at the same commit
(not a controlled comparison):
- a synthetic 200-step probe with 4 KiB tool outputs: 33.3 GiB allocated;
- 150 steps replayed from a real journal: 128.9 GiB allocated.

**The evidence** (prototype `scripts/dst/mem_journal_replay.ail`, untracked in
`../motoko_agent-mem`; run r2.1 of `session_1789244855221-63164319c7d765ff`; HEAD `2fe783a`):

| Check | Result | Limit |
|---|---|---|
| Appended-message chain against `digest_after` | 598 compared positions equal; the source chain itself re-derives 599/599 | The 599th replay message is the prototype's synthetic terminator; the checker compared the shorter prefix only |
| `provider_call_prepared.payload_digest` against the live host log | 300 of 300 equal, in order, as the only contiguous match in 693 live calls (from provider position 351); all 300 distinct; `system_prefix_digest` equal too | Canonical message projection only; all 300 `model` fields differ (routing name against `probe/model`); tool schemas, parameters and encoding unchecked |
| The segment's shape | 300 assistants, each with tool calls; **299 tool results**; 600 history entries; 300 state deltas | The 300th assistant's call has no result: the segment admissible under D1 is **299 complete turns**, 598 appends |
| Total allocation, 3 repeats | 323.02 / 322.65 / 323.39 GiB | Max deviation 0.1158% |
| Peak RSS, same runs | 9,280 / 11,802 / 11,703 MiB | Timing-dependent |
| `de4b4f5` on the same segment | 72.82 / 72.97 / 72.59 GiB; RSS 6,969 / 7,058 / 6,987 MiB; max deviation 0.2774% | 1,806 digests equal across the nine result-matched runs |
| The 57-turn entry, parent against fix | 2.002150 → 1.572677 GiB (`prefix_57.mprof`, `fix_57.mprof`) | 58 provider calls and 115 appended messages in both, including one synthetic terminal turn; not a calibrated gate input |

The prototype's four defects — the history-count provider position (`mem_journal_replay.ail:96–97`,
the F6 shape `stub_step.ail:321–337` rejects), the fabricated terminator, the manufactured
`exit_code: 0` (`:106`), the min-length checker — are all replaced here; and its `Ok(ms)` arm
(`:150`) never fires on the suspension end D2 uses.

**The question.** For which candidate changes can a recorded live session, replayed through the
production traced entry, serve as deterministic evaluation evidence? And how does the verdict say
what was checked, what was not, and where the evidence stops?

## Options considered

**O1 — Status quo: DST fixtures plus live A/B.** Kept, but insufficient for workload-proportional
resource changes on this workload shape.

**O2 — Record an `ExecutionProgram` on the live path.** Rejected: it adds recording on the live
path, which ADR-001 D2 and ADR-003 O4 price as moving the frame gates.

**O3 — Drive the real supervisor/rpc from a recording.** Rejected for T0: the live path has no
seam that serves tool results. Revisit after 028 PLAN-002 D4.

**O4 — Journal plus host-log excerpt → recorded calls → traced entry, graded by a new verifier
under a pinned evaluator** (v2's choice). Rejected in v3: it rebuilt, under new names, the
comparison, refusals, reconstitution check, manifest, persistence and mode split the harness
already has, and it had no counterpart for the witnesses at all.

**O5 — Journals only as seeds for synthetic generation.** Complementary; loses the observation
checks.

**O6 — Evaluator code inside the candidate tree.** Rejected (D5).

**O7 — Journal plus host-log excerpt → a world → one admission run through the traced entry
with recording adapters → an `ExecutionProgram` → strict replay of every candidate, graded by
the harness under a pinned evaluator.** Chosen (v3), retained by the v3 review.

## Decision

### D1 — Extraction

**Inputs.**
- A frozen journal snapshot.
- A **host-log excerpt** from `.motoko/logfile/<session>.jsonl`, limited to these event types,
  in file order with their source positions:
  - `session_start`, in both shapes it has: the ledger banner carrying `run_id` and `mode`
    (seven in the evidence log), and the rpc banner carrying `model`, `config_profile` and
    `loaded_extensions` (three);
  - `provider_call_prepared`: `payload_digest`, `system_prefix_digest`, `model` (the **logical**
    name, before `provider_api_model`), `msg_count`, `step`;
  - `thinking`: `finish_reason`, `input_tokens`, `output_tokens`, `tool_calls` (a **count**),
    and the optional `cache_read_input_tokens`, `cache_creation_input_tokens`, each present only
    when positive (`thinking_usage_kvs`, `phase_vocab.ail:1362–1374` *(review)*) — absent means
    zero under this producer version, which the entry pins;
  - `context_limit_resolved` (six in the evidence log): the recorded context limit and its
    source;
  - `stream_error_retry`.

  The excerpt is required at T0. There is no no-excerpt admission mode.

**Selection.** Explicit, never inferred:

```
RunSelector = { leaf: EntryId, run_id: string, start: EntryId, end: EndAt(EntryId) | CutoffBefore(EntryId) }
```

The path is leaf to root by `parent_id`, with ADR-003 D4's strict decoding. **`start` is the
first evaluated provider call's assistant entry.** The seed is the fold of the path up to the
entry before it — which includes any leading user entries after `run_started` (r2.1: entry 1054
is `run_started`, 1055 a user message and seed, 1056 the first assistant and `start`; folding
through 1055 reproduces the prototype's 694-message seed and its digest). The fold's
dangling-call repair is applied only to obtain that seed, never to the evaluated segment.

**Association.** In order, from the banners: a ledger `session_start` opens a run and an rpc
`session_start` opens a spawn profile; within the selected run, the k-th `provider_call_prepared`
is call k, its `thinking` event is the next one with the same `step`, and its journal counterpart
is the k-th assistant `history_appended` of the run (not counting `replaces_previous`
replacements, which are cutoffs) together with the `state_delta` carrying its telemetry and the
tool results that follow it. `thinking.tool_calls` must equal the assistant's call count. A
missing or ambiguous association is `Refused(Association)`. Assistant entries are never counted
to find calls.

**Starting state.** T0 admits **message-only starts** only. The traced entry builds the loop
state with `c2_initial_state_with_counts` (`session.ail:988–1016`): telemetry and artifacts
zero, `nudges_used` derived from the seed exactly as production does, `prior_counts` **zero**,
pending calls, approvals and open waits empty, step zero. No exported message-only entry carries
prior counts (`:4423`, `:4445`, `:4612`); the internal
`run_v2_from_messages_traced_with_policy_and_counts` (`:4239`) does, and an exported wrapper
over it is T1's route. r2.1's source start carried 350/342 (the delta at entry 1053). This is
declared: the replay's `state_delta.cumulative` differs from the source by that offset; the
`JournalFold` family compares the replay's own fold with its own `final` and passes; no loop
decision reads `cumulative` (`decide` reads step, history, totals, telemetry, pending calls,
waits and policy, `step_machine.ail:122–159`); the one place it reaches the model is the
`MotokoRuntimeStatus` built-in (below). A start that carries continuation state (`:2664`,
`:5346`) is `Refused(ContinuationStart)` at T0 and handled at T1.

**Configuration.**
- The **logical model** from `settings` entries on the path, falling back to the header. The
  entry receives it and converts it once at dispatch (`session.ail:3824`); the seam receives the
  **API model**. The evaluator holds a copy of the whole of `provider_api_model`
  (`:272–292`: `openrouter/auto` kept; `openrouter/`, `openai/`, `anthropic/`, `google/`
  stripped; not idempotent), pinned by hash, for the expected identities. The excerpt's
  `provider_call_prepared.model` must equal the logical model.
- `BootInputs` supplies the task, `hybrid_tools`, budget, `env_url`, `max_cost_millicents` and
  `cost_rates` (r2.1: `hybrid_tools` true, total/solver 1200, verifier 0, step budget 1200,
  `ohmy_pi` false, cap and rates zero).
- **The T0 settings**, pinned in the entry and served through the world's environment and file
  table, because policy initialisation reads them through ports (`session.ail:2350–2388`) and
  they decide which completion arms are reachable:

  | Setting | Value at T0 | Why |
  |---|---|---|
  | `rt.verification` | `{ enabled: false }` | `run_dp7_verifier` executes a real subprocess otherwise (`:2241–2254`) |
  | `MOTOKO_PERSIST_RETRIES` | `"0"` | `should_inject_persist_nudge(budget, used, write_attempted)` is `budget > 0 && used < budget && not write_attempted` (`recovery.ail:59`); zero makes the nudge arm unreachable |
  | `ohmy_pi` | recorded (`false`) | `backend_for_v2(envelope, true)` can route a tool to `Delegated` (`tool_phase.ail:452–464`); `false` makes every tool native, which is how r2.1's 115 `Delegate`/`DelegateCheck` calls reached the tool port live |
  | `hybrid_tools` | recorded (`true`) | hybrid extraction is reached only when no native call has been emitted in the session (`session.ail:4064–4066`); a seed with native calls makes it unreachable, which the entry records |
  | `MOTOKO_HEADLESS`, `OPENAI_BASE_URL`, `MOTOKO_RETRY_STREAM_ERROR` | recorded | read once each at policy init (`:2352–2355`) |
  | context limit | recorded, from `context_limit_resolved` | served as a synthetic profile config in the world's file table (`.motoko/config/<profile>/config.json` with `agent.context_limit`), so `resolve_context_limit_sum` takes the profile branch and never reaches the catalogue (`context_usage.ail:241–250`); the reads this causes are pinned in the witness (D3) |
  | `checkpoint_enabled` | `false` by the entry (`:2376`) | a `TakeCheckpoint` cannot fire; a live checkpoint inside the segment is the `HistoryReplaced` cutoff anyway |
  | `max_cost_millicents` | `0` | disables the cost arm (`step_machine.ail:112–113`) |

**Tool arguments.** The journal's argument strings are decoded as JSON and re-serialised
canonically (compact, keys in source order); a string that does not decode is
`Refused(MalformedToolArguments)`. That is the boundary the seam sees: `ToolInvocation.call` is
a `ToolCallEnvelope` whose arguments are already `Json` (`ports.ail:616–621`). Equality is
JSON equality, not byte equality; retained message bytes are still compared by the transcript
chain. r2.1's 299 argument strings decode and equal their compact serialisation *(review)*.

**The stopping contract.** Under the T0 settings the loop has exactly these reachable ends, by
the shape of the recorded call, not by its finish string:
- A **continuation call** — the assistant carries at least one tool call and every call has a
  recorded result — enters the `tool_calls` state (`session.ail:4020`), runs its tools, and
  returns to `call_model_or_fail`, which tests the budget before `CallModel`
  (`step_machine.ail:103–111`; `CallModel` at `:118`).
- A **stop call** — no tool call, non-blank content — goes through `classify_candidate`
  (`session.ail:3255–3308`): verification disabled, no open waits, an empty registry's solver
  returns no decision, persist budget zero → `CandidateApproved`, state `dp7_approved`, and
  `decide` finalises with `model_stop` (`step_machine.ail:150`).
- Anything else — a blank stop, a feedback or nudge, a park, a retry, an injected message, a
  replacement — cannot occur inside an admissible segment: the settings make the arms
  unreachable, or the journal shows the event and D1 cuts there.

So: **every call before N is a continuation call; call N is a continuation call (expected end
`EndSuspended(N)`: after its tools, `call_model_or_fail` fails with `StepBudgetExhausted`,
`c2_suspend` finds `continuation_history_ok`, `journal.ail:206`, and finalises with
`TermMaxSteps`, `session.ail:2778–2794`) or a stop call (expected end `EndFinalize(model_stop)`).**
A segment whose calls do not fit is cut at the first call that does not.

**Segment ends.** Two kinds, never confused. A **cutoff** ends the segment before the entry (or
before the whole affected turn) and yields a shorter admissible segment; a **refusal** means the
source or its association is unusable for this selector.

| Cutoff | Why |
|---|---|
| `Completed(finish_reason)` | `run_finished` on the path: the genuine end |
| `Suspended`, `Resumed`, `SettingsChange`, `RunStarted`, `Exit`, `EofWithoutRunFinished` | run boundary or state change |
| `ProviderRetry` | a `stream_error_retry` consumes a provider position with no assistant message (`session.ail:3862–3921` *(review)*) |
| `UserMessage` | an in-run user entry: operator input **or** runtime-injected feedback (`:3409–3441` *(review)*; the evidence log has two `ext_solver_feedback` events); role alone cannot tell them apart |
| `HistoryReplaced` | any reason, including `resume` |
| `ReplacesPrevious` | a replacement of an existing response, not a new call |
| `IncompleteToolBatch` | before the whole turn, when any of its calls lacks a result — r2.1's 300th turn |
| `RuntimeStatusCall` | before the turn whose assistant calls `MotokoRuntimeStatus`: its result is synthesised from `prior_counts` and cache totals (`session.ail:707`, `:757–763`, `:3670–3673`) and cannot be served from the queue |
| `StopBeforeEnd` | a stop call at k < N that the live run continued past without a user entry (a completed run that resumed in-process): cut after it, expected end `EndFinalize` |

| Refusal | Why |
|---|---|
| `ChainBreak`, `MalformedEntry`, `UnknownEntryType`, `UnknownSchema` | ADR-003 D4 strictness |
| `DuplicateOrAmbiguousCallId`, `UnexpectedToolResult` | results cannot be attributed |
| `MalformedToolArguments` | the pinned JSON boundary |
| `Association` | excerpt and journal do not agree on the run's calls |
| `ContinuationStart` | T0 |
| `ParkOrWake` | no decoder at HEAD: `all_entry_types` (`journal.ail:1173`) is still ten types without them |
| `EmptySegment` | no evaluated call after the cutoffs |

**Output.**

```
JournalWorld = {
  seed: [Message], seed_digest: string,                  -- validated against the independently folded source
  config: RecordedConfig,                                -- logical model, profile, BootInputs, recorded env values, context limit
  settings: T0Settings,                                  -- the table above, as served
  calls: [RecordedCall],                                 -- in order; N = length
  end: { cutoff: Cutoff, expected: EndSuspended(int) | EndFinalize(string) },
  expected: { chain: [string], payload: [string], system_prefix: [string],
              logical_models: [string], api_models: [string], msg_counts: [int],
              tool_invocations: [ToolKey] },             -- ToolKey = (call_id, name, canonical-JSON argument digest)
  unreproduced: { prior_counts: RuntimeStatusCounts, cache_usage: [{ read: int, creation: int }] },
  omissions: [Omission]
}
RecordedCall = { step: int, assistant: Message, finish_reason: string,
                 usage: { input: int, output: int, cache_read: int, cache_creation: int },
                 tools: [RecordedTool] }
RecordedTool = { call_id: string, name: string, arguments: Json, content: string }   -- exit status not recorded
```

For r2.1: N = 299, 299 tools, 598 appends, expected end `EndSuspended(299)`.

### D2 — Admission run: the program is recorded, not derived

**Why recorded.** The traced entry makes requests the journal never records — the policy-init
environment and file reads, the per-dispatch `MOTOKO_TOOL_TIMEOUT_MS` read
(`tool_phase.ail:485`), clock reads — and `world_state_of` (`dst_replay.ail:831–874`) needs
every class the driver will ask for, with `ProgramExhausted` and `UnusedInteraction` fatal in
both replay modes. So the program is the interaction log of **one run of the parent** over a
journal-built world, as `strict_replay_dst` records its programs from a discovery run.

**The world.** From `JournalWorld`, the shape `base_world` builds (`strict_replay_dst.ail:257`):

```
{ empty_world_state() |
  script:  [ScriptedStep]   -- per call: prose = assistant content, tool_calls, input/output tokens, finish_reason from the excerpt, chunks [], no error, advance_ms 0
  tools:   [ScriptedTool]   -- per result, in journal order: tool_call_id, content, exit_code -1 (the "not executed; status not recorded" convention, ports.ail:586–615), duration_ms 0, no fault
  env:     the recorded values and the T0 settings,  clock_ms: the declared epoch,
  files:   the synthetic profile config (D1),  approvals: [],  wakes: [] }
```

Cache usage is served as zero: `ScriptedStep` has no cache fields and the codec writes none
(`ports.ail:2461–2507`); `scripted_to_step_result` zeroes both (`stub_step.ail:72–90`).
Telemetry copies input and output tokens only (`model_phase.ail:17–25` *(review)*), the
journal's `state_delta` carries the same two, and the cost arm is off. What does depend on it is
on the wire — `ThinkingInfo` and the summary usage — and the `MotokoRuntimeStatus` result, which
D1 cuts. It is listed as unreproduced. Widening `ScriptedStep` and the codec is `/5` (D7).

**The entry.** `run_v2_session_traced` (`session.ail:4423–4442`) with the recorded
`BootInputs`, the **logical** model, the seed, a throwaway `workdir`, **`step_budget = N`**,
`max_cost_millicents: 0`, an `ExtRuntime` with an empty registry and `verification.enabled =
false`, and a new **test-provider variant** `PortedWorld(Ports, WorldState)`. It is added to
`StepProvider` (`stub_step.ail:69`) with one arm in `ported_provider` mirroring
`RecordingWorld`: `PortedWorld(p, w) => { ports: p, world: w }` (`session.ail:1533–1545`);
`frame_ordinal0` gains `PortedWorld(_, w) => w.ordinal` (`scripts/dst/ledger_parity_dst.ail:429–435`);
the constructor is imported where the arms live. `test/scripted_ports.ail:30–35` is a three-arm
legacy match over `Scripted`, `LiveAI` and `Ported` and is left as it is, with its non-coverage
of world-bearing providers stated in the commit. It is not a `Ports` field, a production entry
or a helped request; nothing that runs today changes adapters. **The commit is line-neutral**
(D5): the sum is extended on its line, the arm and the import are joined onto existing lines,
as `stub_step.ail:44` and `tool_phase.ail:484` already do to keep anchors still.

**The ports.** `{ recording_ports(rt) | model_step: eval_model_step(base), tool_exec:
eval_tool_exec(base) }` where `base = recording_ports(rt)` (`stub_step.ail:621`) — the
harness's recording adapters with two evaluator-owned seams by **guarded delegation**:

- **`eval_model_step(base)`.** If `state.script` is empty: record the exhausted marker through
  `record_interaction` (`ports.ail:1781–1797`) with `ProviderIdentity("loop_v2", k, api_model)`,
  the projection `"model_step model=… msg_count=… replay=exhausted"` and the payload
  `encode_exhausted_provider_outcome()` (`:2476`, `{ served: false }`, which `script_of` skips),
  and return `Err({ code: "replay_exhausted", message, retryable: false })`. Otherwise delegate
  to `base.model_step` — `recording_model_step` serves the step and records the interaction
  with the whole `StepResult` as outcome (`stub_step.ail:464–528`) — assert that exactly one
  interaction was appended, and **replace that interaction's `request_projection`** with
  `"model_step model=… msg_count=… payload=<D> system=<S> raw=<R>"`: `D` the private canonical
  payload digest, `S` the private system-prefix digest over the leading system messages (the
  raw-prefix function, `phase_vocab.ail:369–370` *(review)*), `R` a private **raw frame digest**
  over the whole transient payload (the append-chain frame with raw content and images,
  `:321–358` *(review)*), so the canonical blind spots (`make[N]`, omitted images, `:275–300`
  *(review)*) are covered against the parent. Identity, outcome, chunks, emissions, cursor,
  `ordinal` and `pending` are untouched; `record_interaction` assigns the ordinal from the log
  length and advances nothing else.
- **`eval_tool_exec(base)`.** If `state.tools` is empty: record the invocation through
  `record_interaction` with `ToolIdentity("loop_v2", call_id, name)` and the tool codec
  (`encode_tool_outcome`, `:2531`) and return `ToolFailed({ tool_call_id, code:
  "replay_unrecorded_invocation", message })` — `world_tool`'s empty arm is the **live** arm and
  would perform the real effect (`ports.ail:1677–1698`). Otherwise delegate to `base.tool_exec`
  (`recording_tool`, `:2010–2022`, over `world_tool`'s scripted arm, whose correlation guard
  returns `ToolCorrelationMismatch({ expected_id, got_id })` on an id mismatch, `:1730–1731`),
  assert one appended interaction, and replace its projection with `"tool_exec call_id=… tool=…
  args=<digest of the canonical JSON of inv.call.arguments> workdir=… timeout_ms=…
  started_at_ms=…"`.

No private helper is used and no export is added. The core recorder's projections are not
widened, so no recorded fixture is re-baselined. The seams depend on `record_interaction`, the
outcome codecs, `recording_ports`, `recording_tool` and `world_tool`, which are candidate
files: they are **protected regions** (D5). A wider projection is ordinary text to persistence
(escaping covers backslash, tab, newline and carriage return; `=` and `<` round-trip,
`dst_persistence.ail:211–239` *(review)*), is compared verbatim by `ProjectionDiffers`, and is
scanned by `scan_interaction` (`dst_secrets.ail:431–437`); `validate_bounds` does not bound it.

**What a mismatch does.** A provider `Err` ends the run; a tool failure becomes a tool
transcript message (`tool_phase.ail:277–296` *(review)*) and the run can still reach the
expected end. Both are in the world log, where `strict_replay_findings` locates them by
position, and the transcript chain rejects the run (D3). The exhausted marker is never a served
record; a run containing one is `Diverged` at that position and is never admitted.

**The end.** By D1's contract: `call_model_or_fail` tests `step_idx >= step_budget` before
`CallModel` (`step_machine.ail:103–111`) and `decide` runs pending tool calls first
(`:123–128`). With `step_budget = N` and N continuation calls the run makes exactly N provider
calls, runs call N's tools, and `c2_suspend` appends and emits `RunSuspended`, finalises with
`TermMaxSteps`, `result: Err`, `suspended: Some(cont)` and `final` populated
(`session.ail:2778–2794`). With a stop call at N it finalises with `model_stop` before the
budget is reached. The evaluator reads `final.history`, `suspended`, `result`'s code and the
trace. What is synthetic: the budget, the suspension and its event, the finalisation, and their
allocation — all inside the measured process (D4). What is not: any extra provider call or
assistant turn.

**Framing, ordinals, extensions.** As v2: the seams preserve `ordinal` and `pending`, the driver
stays the only source of helped-request advancement, and each traced invocation is framed with
`WORLD_RUN_BEGIN <label> <ordinal0>` / `WORLD_RUN_END <label> <final>` and an empty final
pending queue. T0 runs an empty registry and reports both the recorded `ext_set_digest` and the
digest of the registry used.

**The program.** From the admission run's `world.log` and the world it started from:

```
{ schema_version: program_schema_version(),          -- execution-program/4 at HEAD (dst_program.ail:119)
  generator_id: "journal_admission", generator_version: <evaluator version>, seed: 0,
  initial_world: {
    messages_and_policy: <JSON: session, RunSelector, seed_digest, seed message count, expected end, T0 settings>,
    synthetic_environment: env, files: the synthetic profile config, clock_epoch, extension_profile: "driver_only/<version>" },
  bounds: the observed maxima (chunk_draw_hi 0),        -- data, not a limit
  manifest: { source_revision: A, toolchain: "<ailang version> <binary sha256>", extension_packages: [],
              abi_version, profile_id: "driver_only", profile_version, event_vocabulary_version,
              normalized_configuration: JSON(RecordedConfig ++ T0Settings),
              classifier_2_set, unrouted_fields, scan_roots, scan_root_commit,
              profile_rules_version, coverage_rules_version, attribution_rules_version, fault_catalogue_version },
  interactions: world.log }
```

`validate_manifest(m, driver_only())` (`dst_profile.ail:1535–1572`) requires every string
non-blank, `classifier_2_set` and `scan_roots` non-empty, the profile equal to `driver_only`'s
and the five rule versions equal to the build's; the evaluator fills them from the same sources
`discovered_manifest` does (`strict_replay_dst.ail:631–633`). `validate_schema` requires only
non-blank ids and a decodable version (`dst_program.ail:357–364`); `validate_program`
(`:589–596`) does not call `validate_bounds` (`:648–653`).

`InitialWorld.messages_and_policy` is an opaque string (`dst_program.ail:182–188`; every
fixture fills it with a description, `strict_replay_dst.ail:651`), and the harness's replay loop
takes its seed from a fixture literal (`history()`, `:226`). **The seed stays in the journal
snapshot**, referenced by digest; the **corpus entry** (snapshot + excerpt + program) is the
reproduction unit, and the program alone is not one in D11's sense. Carrying `[Message]` in the
program is `/5` and Not decided.

The program is validated, reconstituted (`world_state_of`) and balanced
(`reconstitution_balance`, `dst_replay.ail:580`) **before** it is persisted (D6).

### D3 — Checks and verdict

**The admissible candidate class at T0.** Changes to the traced loop's internal computation
(traversal, data structure, allocation, retention) that are expected to leave the **raw** inputs
of every provider call — the message list handed to `model_step` — and every tool invocation
unchanged, not merely their canonical projections. The expectation is declared in the candidate
record and reviewed (D5); it is checked to the extent the projections below reach.

Refused before running, by path, by protected region (D5) and by declared intent:
- prompt, system and extension prompt builders; extensions, the tool catalogue and schemas,
  provider adapters and encoding; model or parameter selection, tool implementations, streaming
  handlers;
- `src/core/dst_*.ail`, `src/core/test/*.ail`, `scripts/dst/strict_replay_dst.ail`, every
  evaluator path, and the protected regions of `ports.ail` and `session.ail`.

**Admission checks**, computed by the evaluator against the source, at admission commit A,
on the parent's run:

| # | Check | Against |
|---|---|---|
| A1 | Source chain: the segment's `digest_after` chain recomputes from the snapshot, and the seed digest equals the independently folded prefix | snapshot |
| A2 | Source transcript: `final.history` equals seed ++ every recorded append, byte for byte; the trace's `HistoryAppended` records chain from the seed digest to the snapshot's `digest_after` values with exact count. This is evaluator code beside `JournalFold`, not that family with a different comparand | snapshot |
| A3 | Requests: per call, the program's `payload=` and `system=` equal the excerpt's digests, its identity's model equals the pinned conversion of the excerpt's logical model, `msg_count` equal, exact count | live excerpt |
| A4 | Invocations: the program's tool identities and `args=` equal the journal's decoded calls, in order, exact count | snapshot |
| A5 | Framing: `WORLD_RUN` frames, ordinals, empty pending queue | ADR-001 D2 |
| A6 | End: the expected end reached — `result` code `StepBudgetExhausted` with `suspended: Some` and `RunSuspended` in the trace, or `Ok` with `model_stop` — and no exhausted marker in the log | entry |
| A7 | Witness: `check_discovery(world.log, witness)` is empty, with the witness **built by the runner** (below) | trace and worlds |
| A8 | Invariants: `evaluate(execution_of(run, epoch, obligation, budgets, 0, [], meta))` is empty (`dst_execution.ail:99–125`; `dst_invariants.ail:2010–2024`), with `family_evidence` (`:2036–2066`) reported as **evaluated versus exercised**: the extension, checkpoint, approval, park and streaming families are vacuous at T0 and are printed as such | execution bridge |
| A9 | Round trip: `validate_program`, `validate_manifest`, `world_state_of`, `reconstitution_balance` all clean on the program just recorded | program |

**The witness.** `DiscoveryWitness` (`dst_discovery.ail:260–271`) for an empty-registry run:
`provider_calls` from `ProviderCallPrepared` records in the trace (`strict_replay_dst.ail:310–315`);
`tool_dispatches` from queue consumption (initial minus final `tools`); `approval_reads`,
`approvals_consumed`, `file_writes`, `file_removes`, `dir_makes`, `extension_effects` **zero**;
`clock_delta_ms` from the worlds; `expected_env_reads` one entry per key of `driver_env_keys()`
(`:224–237`) with the count the T0 settings cause: `MOTOKO_PERSIST_RETRIES`,
`MOTOKO_RETRY_STREAM_ERROR`, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS` once each (`session.ail:2352–2355`),
`MOTOKO_PROFILE_DIR` once (the profile branch; `context_usage.ail:139–150`), `MOTOKO_CONFIG`,
`MOTOKO_REPO`, `MOTOKO_MODELS_FILE` zero (the catalogue branch is not reached), `MOTOKO_SESSION_ID`
once (`:1728` *(review)*), `MOTOKO_TOOL_TIMEOUT_MS` once per native dispatch
(`tool_phase.ail:485`), `MOTOKO_EXIT_MANIFEST` zero on a suspension end and once on a
finalisation (`session.ail:3398`, `:5066–5067` *(review)*), `MOTOKO_CAPTURE_FAILED_PAYLOAD` zero.
`env_balance` checks the supplied list, not a provenance table (`dst_discovery.ail:542–544`), so
the zeros are listed explicitly. The fixture's approval-based witness and non-vacuity rule
(`strict_replay_dst.ail:366–378`, `:792–795`) are not reused.

**Candidate checks**, per candidate C, on the assembled tree:

| # | Check | Source |
|---|---|---|
| K0 | Preflight: the entry's manifest, profile, toolchain and binary hash, corpus hashes and T0 settings equal what the runner assembled; evaluator and protected-region hashes unchanged | entry, E |
| K1 | `world_state_of(program)` succeeds and `reconstitution_balance` is empty | harness |
| K2 | `strict_replay_findings(program.interactions, run.world.log)` is empty — kind, origin, identity, projection (model, message count, canonical payload, system prefix, raw frame, tool arguments), outcome, exhaustion and unused, by position | harness |
| K3 | `check_discovery` with the entry's witness is empty | harness |
| K4 | `evaluate` is empty; `family_evidence` matches the entry's evaluated-versus-exercised record | harness |
| K5 | Framing, as A5 | ADR-001 D2 |
| K6 | End, as A6 | entry |
| K7 | Source transcript, as A2, on the candidate's trace | entry |

The candidate's own `provider_call_prepared` events are not consulted: K2 carries the private
digests inside the program's projections.

**The verdict.**

```
Admission = SourceFaithful { entry, calls: N, end, envelope }
          | Refused        { reason: Refusal | AdmissionCheck(A1..A9) | ScanRefusal }

Candidate = Reproduced { calls: N, end, envelope }
          | Diverged   { position: int, finding: ReplayMismatch | ReconstitutionFinding | DiscoveryFinding | Violation | FrameMismatch | EndMismatch | ChainMismatch }
          | Refused    { reason: InadmissibleCandidate | EvaluatorTouched | ProtectedRegionTouched | PreflightMismatch | GuardTripped | ProgramUndecodable(ReplayRefusal) }
```

`Diverged` uses the harness's vocabulary where it has one (`ReplayMismatch`: `WrongKind`,
`WrongOrigin`, `UnsafeIdentity`, `ProjectionDiffers`, `OutcomeDiffers`, `ProgramExhausted`,
`UnusedInteraction`; `DiscoveryFinding`; `Violation` with its family) and the evaluator's for
frames, end and chain. Regression mode (`regression_replay_findings`) is available for
diagnosis and never scores.

**The envelope.** Printed with every verdict.
- **Checked:** A1–A9 at admission; K0–K7 per candidate.
- **Pinned and preflighted:** the recorded config, the T0 settings, the registry used.
- **Unreproduced, declared:** `prior_counts` and every `cumulative` on the wire; cache usage in
  `thinking`, the summary and totals; tool exit status.
- **Not observed at all:** model parameters, tool schemas and request encoding
  (`Ports.model_step` receives a model string and messages, `ports.ail:886`); real tool
  execution; streaming; extensions (r2.1's 115 `Delegate`/`DelegateCheck` calls are served as
  recorded content, their live extension effects omitted); compaction; live GC timing.
- **Vacuous families at T0**, named from `family_evidence`.
- **What the raw frame covers and does not:** it pins the transient payload's content and image
  sources against the parent's admission run, not against the live request; an image URL does
  not freeze the bytes behind it. Tool arguments are compared as JSON, not bytes.

"Byte-identical requests" is not claimed. A3 is equality under the canonical projection against
the live excerpt; K2's raw frame is equality against the parent.

**Measurements and divergence.**
- Whole-process measurements are credited only to a `Reproduced` run; the measured process is
  defined in D4.
- A `Diverged` run's measurements are discarded. To measure the part before a divergence, admit
  a shorter entry with `CutoffBefore` and its own program; no prefix attribution by assertion.

**ADR-003 O2.** Answered for the admissible class only. Changes visible to K1–K7 are detected
and located; changes outside the class are excluded by declaration, region and review, not
detected.

### D4 — Claims

| Claim | Status | Scope |
|---|---|---|
| Cumulative profiled allocation (GiB) | **Primary** | The measured process is the evaluator's replay program from start to exit: load and hash-check the entry, **fold the snapshot prefix into the seed** (A1's fold runs inside the process and is part of the measurement, equally for parent, control and candidate), load and validate the program, `world_state_of`, the traced run to its end, `strict_replay_findings`, the witness, `evaluate`, the chain. Extraction, admission of the entry and persistence are not in it. Pinned: runner, `ailang` binary hash, `GOGC`/`GOMEMLIMIT` recorded (unset by default), profile flags. One warm-up run per assembled tree, guarded, recorded in the exposure log, applied equally to parent, control and candidate; that recompilation explains the observed 22.12 against 10.88 / 10.86 GiB first-run outlier is a **hypothesis**. The tolerance comes from D8's calibration; 0.1158% and 0.2774% are observations |
| GC count, live heap after GC | Secondary | Timing-dependent (baseline 97/99/93 GCs, 1,898/2,450/2,343 MiB max live heap; fixed 34/34/33, 1,213/1,271/1,272 MiB) |
| Peak RSS | Secondary | Timing-dependent; the replay omits live waits (baseline 83–144 s, fixed 56–61 s for 300 calls) |
| Recursion depth | Secondary, whole-process | No phase boundary exists that would exclude the evaluator's own recursion by measurement; until one does (Not decided), the number is the evaluator process's, with the evaluator's folds named |
| Trace invariants | Yes, listed | The thirteen families through `evaluate`, reported with `family_evidence` as evaluated versus exercised; vacuous families named. They do not cover the conversation loop, input waits, TUI, extension effects or streaming chunks (PLAN-003 §0.6) |
| Task quality, tool-choice quality, latency, provider behaviour | **No** | Responses are recorded |

Results are *measurements of the named simulated execution*, which includes the synthetic
suspension and the checks. A change to a path the replay does not execute cannot be accepted
on them, and is inadmissible anyway (D3).

### D5 — Trust model and identities

**The trust model is the harness's.** Strict replay compares the discovery run's log with the
replayed run's log; both are carried by the world the candidate's core threads and returns, and
the harness defends with independent witnesses over the trace, not with isolation. This ADR
inherits that model and states it: **candidates are cooperative and reviewed.** Path refusal,
region hashes and file hashes protect what the evaluator and the recorder are; witnesses and
reconstitution detect ordinary omissions and reshaping; none of them proves the provenance of a
world or trace the candidate returns. A candidate that edits the recorder to lie consistently is
excluded by review, not detected. Same-user filesystem separation is a coordination boundary.
No adversarial guarantee is claimed; stronger isolation is Not decided.

**Protected regions.** `ports.ail` and `session.ail` are candidate files — the loop under
measurement lives in the second — and they also hold what the seams delegate to. The entry pins,
by hash of the function text at A: `record_interaction`, the provider and tool outcome codecs,
`world_tool`, `recording_tool`, `provider_outcome_record` and `scripted_tool_outcome` in
`ports.ail`; `ported_provider` and `dispatch_step`'s call site in `session.ail`;
`recording_ports` and `recording_model_step` in `stub_step.ail`. A candidate diff that touches a
protected region is `Refused(ProtectedRegionTouched)`; a change to one is a basis change.
`phase_vocab.ail` is not protected — `de4b4f5` itself touched it — and the private digest copies
are what make that admissible.

**The evaluator**, at pinned commit **E** in its own worktree:
- the D1 reader and its refusals; the world builder; the two seams; the private digest
  functions (canonical payload, system prefix, raw frame, canonical-JSON arguments), pinned by
  hash and not imported from the candidate's `phase_vocab.ail` or `journal.ail`; the copy of
  `provider_api_model`;
- the admission runner (A1–A9), the candidate runner (K0–K7), the witness builder, the guard,
  the manifest builder, the scan policy;
- the corpus, the expected observations, the pins and budgets.

**The assembled tree.** The runner assembles candidate C's tree with the evaluator paths from E.
It refuses `Refused(EvaluatorTouched)` if C's diff against its parent touches an evaluator path;
verifies E's, the corpus's and the protected regions' hashes before and after; and records the
**assembly identity**: the tree hash of C's files as assembled, E, and any compatibility patch.
A **marker check** is run when P and C differ observably — an independently chosen difference
the run must exhibit — and is reported as *not applicable* when a candidate preserves every
observation; the assembly identity is then the evidence that C's code ran, and the verdict says
which of the two it rests on.

**The variant commit and the compatibility patch.** The variant's arms (D2) do not exist at the
historical control `a6abda4`. The control runs on `a6abda4` plus a **reviewed compatibility
patch** limited to the sum, the two arms and the constructor imports, written line-neutral so
no anchor moves (`anchors.sh:593`, `:614–616`; the bridge span `derive.py:154`); if line
neutrality is impossible at that base, the patch re-baselines the anchors and the three
profiles, and the identity records it. The patch is evaluator code, not a candidate change.

**Identities per result:** source recording commit, admission commit A, parent P, candidate C,
evaluator E, the assembly identity, `ailang` binary hash, and the entry's digests: snapshot,
excerpt, selector, program (`program_digest`, `dst_persistence.ail:591`), plus the program's
own `ExecutionManifest`.

**Changing the evaluator changes the experiment's basis.** A change to E, to the seams'
projections, to the canonical or frame functions, to the journal schema, to the program schema,
or to a protected region needs its own review and re-admission of the corpus; old identities and
results are retained. This is the RSI design doc's rule that a successor earns acceptance
against criteria it cannot rewrite during its own evaluation.

### D6 — Corpus

**Location and handling.** `.motoko/eval-corpus/`, **not ignored at HEAD** (`git check-ignore
.motoko/eval-corpus/example` exits 1 at `d5edebf`; P0 adds the rule before any content is
copied). Directories `0700`, files `0600`. Everything derived goes under `<entry>/runs/` — the
replay's wire carries full `history_seeded`/`history_appended` payloads, and the runner redirects
it only there. Local-only by default; retention is a duration and a deletion rule that includes
every copy, fixed in PLAN-004, not here.

**An entry.**
- the snapshot and the excerpt (only the D1 event types), with their SHA-256;
- the `RunSelector`, the `JournalWorld` expectations, the T0 settings and the expected end;
- the **program artifact**, assembled from `encode_body` and `program_digest`
  (`dst_persistence.ail:544`, `:591`) as `"<schema>\ndigest\t<digest>\n<body>\n"`, loadable by
  `load_program` (`:1344`), which verifies the digest (`:1113`) and does not rescan;
- the witness and the evaluated-versus-exercised family record;
- the envelope; the identities (D5); the assembled settings and measurement scope;
- the **scan report** (below);
- an **exposure log**: every experiment, warm-up, held-out validation, candidate and agent that
  has seen the entry or its results.

**Scan policy.** `encode_artifact`'s gate (`:663`) refuses any program whose text holds a run
of 32+ credential-alphabet characters with an upper, a lower and a digit — six of r2.1's tool
outputs hold an absolute repository path that qualifies — and is not used. Its rules are not
precise either: `ProviderTokenLiteral` is `Str.contains` over 23 prefixes with nothing required
behind them (`dst_secrets.ail:217–229`), and four of r2.1's 299 tool outputs (sites 0, 96, 195,
228) hit one; the seed holds sixteen more. The evaluator applies a **contextual policy**,
reviewed with E, over **every** component — snapshot, excerpt, program (identity, projection,
payload, chunks: `scan_interaction`, `:431–437`), environment (with `CredentialBearingName` on
keys, `:353–359`), file table, metadata and derived output:
- **refuse** on `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo`, and on `ProviderTokenLiteral`
  when the prefix is followed by at least 16 credential-alphabet characters — the shape a
  credential body has, a sharpening that lives in the evaluator's copy, not in `dst_secrets`;
- **report** every other finding (`OpaqueHighEntropy`, bare prefix hits) per site with its
  reason, in the entry's scan report, without calling it a credential.

A refused entry is `Refused(ScanRefusal)` naming the sites. Whether r2.1 is admitted under this
policy is decided by running it, and the report is kept either way; if it is refused, the second
session's first 57 turns are scanned next, and P3's dev entry is the first one admitted.
Redaction (`redact_interactions`, `:589`, which reports its trajectory cost) would produce a
program that no longer reproduces the run and is Not decided.

**Admission.** At commit A, against independent evidence: A1–A9 as `SourceFaithful`, the scan
policy passed. Re-admission after a change to the canonical form, the frame function, the
journal schema, the program schema, the seams, a protected region or the scan policy is a basis
change (D5).

**Held out.** An entry is `held-out` only if no agent producing candidates has inspected the
entry or its results. The two sessions used so far are `dev` and marked exposed: r2.1 of
`session_1789244855221-63164319c7d765ff`, and the first 57 turns of
`session_1789293423477-2e87f61dff66d42e`. Held-out pins and results are stored outside the
candidate's write scope; candidate-producing agents receive no held-out details. Reports give
per-entry outcomes, including refusals.

### D7 — Fidelity ladder, with cumulative omissions

| Tier | Adds to the tier below | Still omits (cumulative) | Depends on |
|---|---|---|---|
| **T0** | D1–D6 | streaming; conversation loop and cross-turn lifetime; extensions and compaction; model parameters, tool schemas and encoding; real tools and exit status; cache usage (served as zero; unreproduced on the wire); prior counts (served as zero; `cumulative` unreproduced); `MotokoRuntimeStatus` (cut); live GC timing. Refuses continuation starts; cuts at retries, user messages, replacements, runtime-status calls | — |
| **T1** | synthetic *content* chunks at a stated granularity (`chunked_prose_step`, `stub_step.ail:803`, fixed usage and finish, so usage/reasoning/tool/error streams need their own adapters); prior counts for message-only starts through an exported wrapper mirroring `run_v2_session_traced` (`session.ail:4423–4442`) that normalises the provider, initialises policy and calls `run_v2_from_messages_traced_with_policy_and_counts` (`:4239`); continuation starts through `fold_journal` → `plan_resume` → `run_v2_session_resumed_traced` (`:5346`), as `journal_resume_dst` does; cache fields in `ScriptedStep`, the provider codec (`ports.ail:2461–2507`) and `scripted_to_step_result` under **`execution-program/5`** | everything T0 omits except continuation starts, prior counts and cache usage; real chunk boundaries and encoding. **Does not reach the production conversation loop** (PLAN-003 §0.6; ADR-002 D4) | — |
| **T2** | extensions | everything T1 omits except extensions; **needs observations neither the journal nor the host log records** — extension effects, pre-step and solver provider calls, extension file reads — served fail-closed, with no empty effect queue falling through to a real subprocess. An investigation, not a promise | new recorded observations; the ADR-001 exemption; 028 PLAN-002 D4 |
| **T2b** | operator input as scripted input; the `UserMessage` cutoff no longer applies to operator entries | as T2 for everything else | ADR-002 D4 |
| **T3** | **a separate live experiment**, not a replay tier: live sampling (RSS against journal bytes) and live A/B, to assess transfer | determinism; the whole envelope | — |

**Compaction, scoped.** Retained history and a pre-step compacted payload differ (ADR-003
retraction 4). A message-changing compaction normally fails A3. A no-op compaction, or a change
invisible to the canonical projection, need not; the raw frame of K2 sees it against the parent
only. Source-compaction eligibility is recorded at admission, not inferred from A3.

**Streaming, scoped.** The evidence log holds 801 `thinking_delta` and 57 `reasoning_delta`
events against 693 provider calls; the host may coalesce deltas. No streaming cost share is
claimed.

### D8 — Gate and sequencing

1. **P0 — Preserve.** Archive the prototypes and the stored evidence with hashes, without
   running them. Add the corpus ignore rule. The prototypes may otherwise be deleted
   (HANDOFF-2026-09-13).
2. **P1 — Build.** In core, one reviewed, line-neutral commit: the `PortedWorld` variant, its
   two arms and constructor imports. At E: the D1 reader and refusals; the world builder with
   the T0 settings; the two guarded-delegation seams; the witness builder; the manifest builder;
   the admission verifier (A1–A9) and the candidate runner (K0–K7) over the harness's
   `world_state_of`, `reconstitution_balance`, `strict_replay_findings`, `check_discovery` and
   `evaluate`; the source transcript comparison; the entry wrapper and artifact assembly; the
   scan policy; the finding mapping. Type-check and unit-test on tiny synthetic journals: one
   known-divergent and one known-refused case per refusal family, one per `ReplayMismatch`
   variant, one per cutoff, one per seam's fail-closed arm, one witness under- and over-count,
   one vacuous family reported as such. **Not built:** a second comparison walk, a second
   reconstitution, a second persistence codec, a second manifest type.
3. **P2 — Guard and calibrate.** The guard reads `/sys/fs/cgroup/memory.current` and
   `memory.max` (25,769,803,776 bytes, 24 GiB; `memory.current` sampled at 10.5 and later 9.93
   GiB), requires exclusive heavy execution, headroom (current plus calibrated peak plus margin
   below `max`, current well under 12 GiB per the handoff rule), monitors during the run,
   terminates on a conservative threshold, applies to warm-ups and profiling runs, and
   invalidates the result on any trip. Margin, polling and the treatment of an unlimited
   `memory.max` are PLAN-004's. Calibrate short segments (at most 100 recorded calls) with the
   final evaluator, both verdicts.
4. **P3 — The gate.** Admit the first `dev` entry the scan policy and A1–A9 accept. Pin in
   `make journal_replay_budget`: allocation and the exact observation counts (calls, appended
   messages, tool invocations, interactions by class, env reads by key). Fail closed on a loader
   error, a missing profile, a preflight mismatch, a divergence, a changed scope, or a guard
   trip. **Show it rejects a known regression:** run it at `a6abda4` with the compatibility patch
   on the same entry. The stored 58-call profiles (2.002150 against 1.572677 GiB) show the
   difference exists; they are terminal-augmented prototype runs and are **not** the gate's
   inputs. Pin the gate only after A1–A9, K0–K7 and the control rejection pass with the final
   evaluator on the finite-turn entry. The segment length is fixed here, by calibration.
   Repinning requires a recorded reason and happens outside the candidate's control.
5. **P4 — Held-out process.** Collect new sessions under the exposure rule.
6. **P5 — Long admission.** Entries of the 300-call class are admitted only under the guard with
   exclusive execution, never inside a sweep.
7. **P6 — T1.**

Separately owned and not licensed by this ADR: the pending P2D sweep, P3ORD, and the
operator-owned canaries.

## Consequences

**What gets possible.** Resource and structural changes to the traced loop are measured on real
workloads, and every candidate run is a strict replay the harness already knows how to load,
validate, replay and report. The verdict names its envelope in the harness's own vocabulary.

**What gets load-bearing.**
- The ADR-003 journal schema, the canonical message form and frame function, the host log's
  `thinking`, `provider_call_prepared`, `context_limit_resolved` and `session_start` fields, the
  program schema, the outcome codecs, the protected regions and the T0 settings: changing any of
  them costs a re-admission.
- The excerpt is captured at admission, so indefinite retention of the whole host log is not
  required.

**What changes in code.**
- One `StepProvider` variant, two match arms and the constructor imports, line-neutral
  (`stub_step.ail`, `session.ail`, `ledger_parity_dst.ail`); a compatibility patch of the same
  for the historical control.
- The evaluator modules at E.
- `Ports`, the journal format and writer, the fold, strict replay, the recorder's projections,
  the program schema, the frame gates and `derive.py` are untouched. Anchors are untouched
  because the commit is line-neutral; if that fails, the re-baseline is priced in D5.

**Costs.**
- Local disk: a program per entry carries every tool output at real size beside the snapshot.
- Exclusive heavy execution for long entries: the 300-call T0 replay peaked at 6,969–7,058 MiB
  with `de4b4f5`.
- A pinned second worktree.
- Privacy handling for real conversation content, now also inside program artifacts, with a
  scan report per entry.
- Two seams that delegate to protected regions and must follow them.

## Not decided

- **Carrying the seed in the program** (`execution-program/5` with a `[Message]` field), which
  would make the program alone a reproduction unit.
- **Widening the core recorder's projections** with the payload digest and tool arguments, which
  would retire the seams' replaced projections at the cost of re-baselining every recorded
  program.
- **Cache fields in `ScriptedStep` and the outcome codec** (`/5`; T1).
- **Exporting the counts-carrying traced wrapper** (T1).
- **A phase boundary for recursion depth** that excludes the evaluator's own folds by
  measurement.
- **The `ProviderTokenLiteral` sharpening** (16 characters) as a change to `dst_secrets` itself.
- **A no-excerpt admission mode** with inferred finish reasons and journal-only usage.
- **Redaction and export.** Redacted entries would need fresh identities and fresh admission.
- **Moving request digests into the journal.** A change to ADR-003 D2's event set.
- **The recorded observations T2 needs** for extensions and compaction.
- **T1's chunk granularity source.**
- **A tool-result seam on the live path** (O3).
- **The isolation strength for the evaluator**: same-user worktree, separate user, or container.
- **Retention duration** (PLAN-004).

## Implementation handoff

A PLAN-004 with P0–P6 as in D8. P0 and P2's guard come first because the prototypes can be
deleted and memory is contended. P1 is written against the harness's existing entry points and
the prototypes' evidence, not their code. The variant commit is one reviewed, line-neutral core
commit that changes no running adapter and moves no anchor; everything else lands at E.

## Cross-references

- `REVIEW-adr004-v3-verdicts-codex.md`: the v3 review; its four blockers, its answers to the
  eleven questions (§3), its claim audit (§4) and its ten required changes are folded here.
  `REVIEW-adr004-v2-verdicts-codex.md`, `REVIEW-adr004-v2-verdicts-fable.md`,
  `REVIEW-adr004-verdicts-codex.md`: the earlier rounds.
- ADR-003: O2, O4, D1, D2 (the typed suspension), D4 (the fold, `JournalFold`), retraction 4,
  Consequences, Not decided.
- ADR-001 D2 (frames; the `ExtPorts` forwarding exemption). ADR-002 D4. PLAN-003 §0.6,
  `:772–775` (the large seed).
- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md` (acceptance against criteria
  a successor cannot rewrite; withheld evaluation; a recorded response sequence may cease to be
  valid when a candidate changes the request).
- HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md (the 12 GiB `memory.current` rule; `de4b4f5`).
- Prototypes and evidence (untracked, worktree `../motoko_agent-mem`):
  `scripts/dst/mem_journal_replay.ail`, `mem_growth_probe.ail`, `mem_canonical_bench.ail`;
  `.motoko/memfix/` (`runs/results.tsv`, `runs-new/`, outputs, profiles, gate logs). The v3
  review's evidence scripts and outputs (`evidence.py`, `source_check.py`, their `.txt`) in its
  scratchpad directory, quoted in its §4.
- Live A/B: `.motoko/ab/muse-replay-20260907T185514Z/`.
- Code at `d5edebf`, read for v4:
  - `session.ail`: `:272–292`, `:707`, `:757–763`, `:988–1016`, `:1533–1545`, `:1549–1557`,
    `:1935–1950`, `:2241–2254`, `:2350–2388`, `:2664`, `:2778–2794`, `:3255–3308`, `:3338`,
    `:3351–3352`, `:3670–3673`, `:3824`, `:4020`, `:4064–4066`, `:4221`, `:4239`, `:4423–4442`,
    `:4445`, `:4612`, `:5346`; `TracedSessionResult` (`result`, `trace`, `world`, `emissions`,
    `suspended`, `final`);
  - `step_machine.ail:102–159`; `recovery.ail:59`; `tool_phase.ail:452–464`, `:485`,
    `:555–570`; `journal.ail:206`, `:1173`, `:1557`;
  - `ports.ail`: `:586–615`, `:616–621`, `:647–651`, `:818–821`, `:886`, `:1024`, `:1677–1698`,
    `:1729–1731`, `:1781–1797`, `:2010–2022`, `:2087`, `:2119`, `:2125`, `:2171`, `:2461–2507`,
    `:2531`, `:2562`;
  - `test/stub_step.ail`: `:44`, `:69`, `:72–90`, `:121`, `:136`, `:203`, `:321–337`, `:338`,
    `:464–528`, `:540`, `:547`, `:621`, `:777`, `:803`; `test/scripted_ports.ail:30–35`;
  - `dst_program.ail`: `:119–123`, `:182–188`, `:243–252`, `:357–369`, `:589–596`, `:648–653`;
  - `dst_replay.ail`: `:395`, `:580`, `:681–703`, `:745`, `:761`, `:792`, `:831–874`;
    `dst_interaction.ail:297–302`;
  - `dst_discovery.ail`: `:224–237`, `:260–271`, `:529–545`; `dst_execution.ail:99–125`;
    `dst_invariants.ail`: `:247`, `:1956–1997`, `:2010–2024`, `:2036–2066`;
  - `dst_profile.ail`: `:1474–1491`, `:1535–1572`; `dst_persistence.ail`: `:544`, `:591`,
    `:615`, `:663–668`, `:1095`, `:1113`, `:1304`, `:1344`; `dst_secrets.ail`: `:217–229`,
    `:287`, `:337`, `:353–359`, `:431–442`, `:530`, `:589`; `context_usage.ail`: `:59–76`,
    `:139–150`, `:178–195`, `:241–250`;
  - `scripts/dst/strict_replay_dst.ail`: `:226`, `:257`, `:298–302`, `:310–315`, `:366–378`,
    `:631–633`, `:636`, `:651`, `:708`, `:737–781`, `:792–795`;
    `scripts/dst/ledger_parity_dst.ail:429–435`;
  - `tools/predicate-anchors/anchors.sh:593`, `:614–616`; `tools/driver_leaf_inventory/derive.py:154`.
- Code as cited by the reviews and not re-read for v4: `session.ail` `:1728`, `:3045`,
  `:3398`, `:3409–3441`, `:3862–3921`, `:5066–5067`; `phase_vocab.ail` `:275–300`, `:321–358`,
  `:369–370`, `:1348–1374`; `model_phase.ail:17–43`; `tool_phase.ail:277–296`;
  `tool_dispatch_adapter.ail:46–56`; `dst_persistence.ail:211–239`.
