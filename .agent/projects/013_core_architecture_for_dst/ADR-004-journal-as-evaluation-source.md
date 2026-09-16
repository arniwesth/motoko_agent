# ADR-004: A session journal is an evaluation source — an execution program recorded from its replay at admission, strict-replayed by every candidate, graded by an evaluator the candidate does not own

Date: 2026-09-13 (v1, v2), 2026-09-14 (v3, v4), 2026-09-15 (v5)
Status: **Accepted (v5 — folds the v4 Codex review's nine required changes and answers PLAN-004's ⟨v5⟩ questions; reviewed by `V5R·a1`, claude, `REVIEW-adr004-v5-verdicts-claude.md` sha256 `b53604f8…`: ACCEPT WITH CORRECTIONS, C1–C6 and the cosmetic item applied in `988a863`; accepted by the operator at PLAN-004 `V5G`, 2026-09-16; to be implemented by PLAN-004 v2).**
v4 was reviewed by Codex (`REVIEW-adr004-v4-verdicts-codex.md`, HEAD `d5edebf`): *return for v5;
retain O7* — D1, D3 and D5 returned; D2, D4, D6, D7 and D8 accepted with corrections. It found the
central integration sound — guarded delegation records ordinary harness outcomes and replaces only
the request projection, and replay rebuilds its queues from outcome payloads — and returned three
mechanisms: the stopping contract and its settings, the witness and invariant contract, and the
protected basis of the historical control. v3 was reviewed by Codex
(`REVIEW-adr004-v3-verdicts-codex.md`): *return for v4; retain O7*. v2 was reviewed by Codex
(`REVIEW-adr004-v2-verdicts-codex.md`) and Claude Fable (`REVIEW-adr004-v2-verdicts-fable.md`);
v1 by Codex (`REVIEW-adr004-verdicts-codex.md`). No ADR-004 review names its model; v4's
`gpt-5.6-sol` attribution of the v3 review is withdrawn.
Code coordinates are at HEAD **`3920814`**, re-read for v5, unless marked *(review)* — verified
by a review at `d5edebf`, not re-read here. Four cited modules moved between `d5edebf` and
`3920814` (`git diff --stat`): `session.ail` +316 lines, all after `:5097`; `ports.ail` +46 at
every cited site from `:1259` on; `test/stub_step.ail` +14 from `:321` on; `journal.ail` +2, +80
and +122 at its three cited definitions. Every coordinate in those four is re-pinned below. Five
cited modules changed between `d5edebf` and `3920814`: the four above and
`tools/driver_leaf_inventory/derive.py` (+10 at `:642–654`, no cited coordinate affected); every
other cited module is byte-identical between the two commits and keeps its coordinate.
This ADR still changes nothing in ADR-003: the journal format, writer, fold and resume are
untouched. It changes one thing in the DST harness: one `StepProvider` variant (D2).

---

## Version history and retractions

*Coordinates inside this history are those of the version that made the claim (`a0384e4` for
v1–v3, `d5edebf` for v4) and are not re-pinned; the decision text below the history is pinned at
`3920814`.*

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

**v4 → v5.** What v4 got wrong, in the order of the review's nine required changes
(`REVIEW-adr004-v4-verdicts-codex.md:282–292`). Each item names the decision text that replaces
it and the contract or test it implies (PLAN-004's M-rows):

1. *"Under the T0 settings the loop has exactly these reachable ends: a continuation call, or a
   non-blank, call-free stop."* Three shapes were unnamed and one cutoff was wrong.
   - A call-free assistant whose finish string is `tool_calls` takes the **tool branch**: the
     predicate is `finish_reason == "tool_calls" || n_calls > 0` (`session.ail:4020`), the state gets
     `last_finish_reason: "tool_calls"` with nothing pending (`:4020–4055`), and `decide` falls through
     to `call_model_or_fail` (`step_machine.ail:123–159`) — before N it continues without a tool
     result, at N it suspends. v5 **cuts** it (`CallFreeToolCallsFinish`, before the turn); admitting
     it as a third class is Not decided (D1).
   - For a call-free response whose finish is not `tool_calls`, **hybrid extraction precedes
     classification** (`:4058–4066`); its predicate, `session_emitted_native_tool_call`, is an
     assistant call whose id does not start `hybrid-step-`, anywhere in the accumulated messages
     (`:2126–2140`). "A seed with native calls makes it unreachable" was recorded, not enforced. v5
     asserts the predicate at admission when `hybrid_tools` is recorded true and cuts any result whose
     id starts `hybrid-step-` (D1).
   - A **blank stop is reachable**: stage 2 is skipped, stage 3 finds no wait, stage 4's empty solver
     yields `NoDecision` with a zero persist budget, stage 5 re-runs the disabled verifier and gets
     `None` (`:3267–3305`); the run finalises with empty output and `EmptyStopFinalize`
     (`:3378–3387`). v5 cuts it (`BlankStop`) and says that it is reachable (D1).
   - `StopBeforeEnd` is not the generic before-the-turn cutoff: it keeps call k and its assistant
     append, recomputes N = k and expects `Finalize`. The parenthetical "a completed run that resumed
     in-process" is withdrawn: the traced entry returns at `Finalize` (`:3354–3409`) and the journal
     does not say why the live run went on (D1).
   Contract: D1's classification procedure and cutoff table; M3 (`StopBeforeEnd` → selector, N, end);
   M4 (the four shapes).
2. *"Empty registry and zero witness counts mean no terminal effects; `MOTOKO_CONFIG` and
   `MOTOKO_REPO` are read zero times; `MOTOKO_CAPTURE_FAILED_PAYLOAD` zero, unqualified."*
   - A non-empty `MOTOKO_EXIT_MANIFEST` makes `publish_exit_manifest` write a file and `exec("mv")`
     outside the recorded file port (`src/core/ext/exit_manifest.ail:202–223`; the name is read through
     `Ports.env_get` at `session.ail:5066`, once on a `Finalize` end, `:3398`). A non-retryable provider
     failure — the seam's exhausted `Err` included — reads `MOTOKO_CAPTURE_FAILED_PAYLOAD` once
     (`:3878`), and a non-empty value writes `.motoko/failing_payload.json` ambiently (`:1050–1057`).
     Neither is visible to a mutation witness. v5 pins both **empty** in every synthetic environment,
     failure tests included (D1, D3).
   - `profile_dir_path` reads `MOTOKO_PROFILE_DIR` first and reads `MOTOKO_CONFIG` and `MOTOKO_REPO`
     only when it is empty (`context_usage.ail:139–150`); v4 pinned no override and still counted
     zero. v5 pins an explicit `MOTOKO_PROFILE_DIR` and the matching `FsFile` at `<dir>/config.json`,
     so the two zeros follow from the override (D1, D3).
   - The context-limit encoding is stated: `agent.context_limit` a positive integer
     (`ProfileWindow` → `resolve_bounded_from_profile`, `context_limit.ail:129–132`) or the string
     `"disabled"` (`declares_disabled`, `context_usage.ail:168–175`; `disabled_profile_value`,
     `context_limit.ail:145`); a missing or non-positive key falls to the catalogue and
     `MOTOKO_MODELS_FILE` (`:178–195`, `:241–250`) (D1).
   - Accepted-end counts and fault-path reads are separate columns (D3).
   Contract: D1's settings table, D3's env table; M5; M11's fault-path read.
3. *"K3 uses the entry's witness; the candidate's own `provider_call_prepared` events are not
   consulted."* Reusing the admission witness compares candidate log counts with stored counts only
   and loses the trace/world balance `check_discovery` exists for (`dst_discovery.ail:529–545`). v5
   builds C's witness from C's trace (prepared count), C's queues (dispatches) and C's worlds
   (clock), keeps the source-derived env expectations and the route zeros, and compares the runtime
   counts with the entry's separately. What K2 does not need is the candidate's prepared-event
   *digests* (D3). Contract: D3 K3; M14's "prepared ≠ recorded" mutation.
4. *"`evaluate(execution_of(run, epoch, obligation, budgets, 0, [], meta))`; the extension,
   checkpoint, approval, park and streaming families are vacuous at T0 and printed from
   `family_evidence`."* The bridge takes eight arguments — a `ReplayObligation`, separate
   `decision_budget` and `retry_budget`, a `ReplayMetadata` (`dst_execution.ail:100–126`;
   `dst_invariants.ail:599–602`; `dst_profile.ail:1582–1588`). The thirteen families are
   `TerminalSummary` … `JournalFold` (`dst_invariants.ail:228–247`); no extension, approval, park or
   streaming family exists. `family_evidence` reports each family's *total* record or log count
   (`:2043–2067`), so `CheckpointHistory` reads evaluated with positive inputs while its chain check
   is vacuous with no checkpoints (`:1631–1640`). v5 specifies the obligation (`NoReplay` at
   admission, `StrictAgainst(program.interactions)` for a candidate), `replay_metadata_of(manifest)`,
   a decision bound derived from the entry's shape and a retry bound of zero, keeps `family_evidence`
   unchanged, and adds an evaluator-owned **sub-obligation census** (D3, D4). Contract: D3 A8/K4;
   M11.
5. *"The empty-cursor records are specified by the returned error and payload; an exhausted marker
   is `ProgramExhausted` at its position; `Diverged` carries an integer position; manifest provenance
   is filled from the same sources `discovered_manifest` does."*
   - Both seams' empty arms now write a complete `TimedOutcome`: the provider marker is the harness's
     own exhausted record (`stub_step.ail:488–505`), the tool record mirrors `tool_outcome_record`'s
     `ToolFailed` arm (`ports.ail:2133–2145`) with the exported class literal
     (`dst_fault_catalogue.ail:61`) (D2).
   - `ProgramExhausted` is emitted only when the expected log is exhausted (`dst_replay.ail:374–379`);
     a marker where a served interaction was expected is a projection or outcome mismatch at that
     position (`:358–367`), and an earlier mismatch stays first. v5 keeps the explicit no-marker
     condition in A6/K6 and reports the first mismatch, never a universal `ProgramExhausted` (D2, D3).
   - `Diverged` carries a typed `Location` — interaction ordinal, source position, call index or an
     aggregate tag (D3).
   - `discovered_manifest` passes literals (`strict_replay_dst.ail:631–633`). v5 gathers every
     provenance field from the actual identity and checks it against a different source (A9b), uses
     `driver_only_manifest` for the build-derived fields only (`dst_driver_only.ail:1097–1123`), and has
     K0 compare gathered values (D2, D5). Contract: M8, M9, M10, M14.
6. *"The listed hashes protect the recorder and all its seams."* The list omitted the dependencies
   the recorder serves through — `tool_outcome_record`, `scripted_step_ai_error`,
   `scripted_step_faults` (`ports.ail:2133–2172`); `recording_clock` → `virtual_clock`, `recording_env`
   → `scripted_env`, `lookup_env`, `env_has_key` (`:1851–1895`, `:1305–1320`); `ports_shape_probe` →
   `scripted_file`, `lookup_file` (`:2855–2885`, `:1335–1364`) — and the imports and declarations they
   name. No existing tool hashes source spans: `check.py` hashes whitespace-normalised ADR prose
   (`tools/predicate-anchors/check.py:62–73`), and normalising inside an AILANG string literal is a
   semantic change. A tree hash names assembled source, not what the compiler loaded. v5 defines the
   protected closure, the checker's contract and an execution-provenance record beside the assembly
   identity (D5). Contract: M7, M13.
7. *"The control runs at `a6abda4` plus a patch limited to the sum, the two arms and the imports,
   and K0–K7 pass."* The historical `recording_ports` lacks HEAD's `wake_read: recording_wake`
   binding (`a6abda4:src/core/test/stub_step.ail:554–575` against `stub_step.ail:635–658`; SHA-256
   `e6df6f20…` against `495d3c8f…`, review §3.8), a difference outside that patch, so it fails A's
   pins at K0 — and a K0 refusal is not the budget rejection D8 needs. The two digests are the
   SHA-256 of the definition text from `export func recording_ports(` through its closing brace and
   newline (the v4 review's `audit_v4.py`; historical lines 554–575, current 635–658); a `sed`
   line-range hash differs. v5 makes a **same-basis
   regression control** primary: a candidate diff on A reverting `de4b4f5`'s change to
   `canonical_messages` — that commit touched only `src/core/phase_vocab.ail` (10+/7−) and is an
   ancestor of `3920814` — which must pass review as resource-only, the protected check, and K1–K7
   before its budget failure counts. The historical control becomes an optional, separately reviewed
   basis with its own manifest (D5, D8). Contract: D8 P3; PLAN-004 P3.2's obligations (i)–(iv).
8. *"Body-16 is the shape a credential body has; 'every other finding' is reported."* The prefix
   list carries no length rule and `Basic `/`Bearer ` are generic schemes (`dst_secrets.ail:217–229`):
   short bodies escape refusal, long bodies occur in ordinary text. `scan_text` reports only the
   **first** matching prefix (`:225–229`, `:337–347`), so a policy that filtered that finding could
   miss a later body-bearing occurrence. v5 states the heuristic with its limits, scans every
   occurrence of every prefix, names `CredentialBearingName` (`:353–359`) report-only, records r2.1's
   refusal (four seed sites) and component counts, and names no admitted entry (D6). Contract: M12;
   PLAN-004's `SCAN0`.
9. *Claims and coordinates* (review §4). "Every other string reaches `call_model_or_fail`": pending
   tools, an open-wait `Park` and the stop/approved `Finalize` precede that fallback
   (`step_machine.ail:123–150`). "The program is the reproduction unit for all the others" (Context):
   the corpus entry is. "Built is" (retraction 14): to be built. "The 300-call T0 replay peaked at
   6,969–7,058 MiB": the terminal-augmented prototype did; the finite-turn entry has not run.
   Coordinates: the runtime-status callback is `session.ail:3677–3681` (`:3670–3673` is its comment);
   the full `DiscoveryWitness` is `dst_discovery.ail:260–310`; `family_evidence` is
   `dst_invariants.ail:2043–2067`; `execution_of` is `dst_execution.ail:100–126`; `ported_provider` is
   `session.ail:1532–1547` and `provider_api_model` `:272–293`; the prototype's `Ok(ms)` arm is
   `mem_journal_replay.ail:153` (`:150` sets cost rates). D1's `ParkOrWake` reason — "no decoder at
   HEAD" — was stale at `3920814`: `686da16` added the `park` and `wake` entries (`journal.ail:1179–1180`,
   `:1253–1256`); the boundary is restated from the loop's reachable states (D1).

**PLAN-004's ⟨v5⟩ questions** (PLAN-004 §5), each answered in the decision it belongs to:

| marker | answered in |
|---|---|
| D8's per-family sentence; M15's near-misses and inapplicable rows | D8 step 2 (the sentence, rewritten) and "The P1 test contract" (the ruling) |
| 1 — zero-call `tool_calls`, blank completion, hybrid predicate, `StopBeforeEnd` | D1 "The stopping contract", "Segment ends" |
| 2 — env values, profile path, context-limit encoding, fault-path counts | D1's settings table; D3's env table |
| 3 — candidate witness comparison | D3 K3 |
| 4 — obligation, metadata, budgets, census | D3 A8, K4, "The census" |
| 5 — failure `TimedOutcome`, marker, locations, provenance | D2 "The ports", "What a mismatch does", "The program"; D3 A9b, `Location` |
| 6 — protected closure, comment rule, execution/cache/package provenance | D5 "Protected regions", "The checker", "Execution provenance" |
| 7 — control class and basis | D8 P3; D5 "The control basis" |
| 8 — scan policy text, `CredentialBearingName` | D6 "Scan policy" |
| park/wake refusal reason | D1: `Parked` is a **cutoff**; a wake-opened run is `ContinuationStart`; a stray wake is the fold's refusal |
| decoders as copies or imports | D5 "The evaluator": copies, pinned by the hash of the span they copy |

Not retracted: O7; the pure reader; the excerpt as a required input; the seed in the snapshot; the
cooperative trust model; `PortedWorld`; guarded delegation; the line-neutral commit; the cumulative
omissions; the whole-process measurement scope with the fold inside it; the sequencing.

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | **Extraction.** A pure reader turns an explicit journal segment plus a host-log excerpt into a seed, recorded calls, recorded configuration, the T0 settings and expected observations. Ordered association; cutoffs distinguished from refusals; a **stopping contract** stated as a classification procedure over the recorded call's shape, with the reachable-but-cut shapes named; two ambient keys pinned empty and an explicit profile directory; both model names; arguments as canonical JSON | 2–3 days, evaluator |
| D2 | **Admission run.** A `WorldState` built from D1 is driven through `run_v2_session_traced` as `PortedWorld(ports, world)`, where `ports` is `recording_ports` with two **guarded-delegation** seams whose empty arms write complete fail-closed records; `step_budget = N`; the run's interaction log **is** an `ExecutionProgram` at schema `/4`, with a manifest built from gathered provenance | 1–2 days: one line-neutral variant commit, two seams, a world builder, a manifest |
| D3 | **Checks and verdict.** Admission: fold, source transcript, requests, invocations, frames, end, a runner-built witness, the thirteen families with their evidence plus a sub-obligation census, round trip, provenance. Candidate: preflight, then the harness's `world_state_of`, `reconstitution_balance`, `strict_replay_findings`, `check_discovery` with a witness built from the candidate's own run, `evaluate`, frames, end, source transcript. `Reproduced`, `Diverged { location, finding }`, `Refused` | 1–2 days, evaluator |
| D4 | **Claims.** Cumulative profiled allocation of the named evaluator process — the seed fold inside it — is primary; GC, live heap, RSS and recursion depth secondary; no task-quality, latency or provider claims | — |
| D5 | **Trust model and identities.** Cooperative, reviewed candidates; witnesses, not isolation. A protected **closure** in candidate files pinned by exact-span hash with a checker; execution provenance beside the assembly identity; identities: manifest, snapshot, excerpt, selector, program, assembly, execution. Line-neutral variant commit; a same-basis control | 1–2 days |
| D6 | **Corpus.** Private, ignored, `0700`. Entry = snapshot + excerpt + selector + program + expectations + envelope + identities + exposure log. A contextual scan heuristic over every component with stated limits; findings reported, refusals named; r2.1 refused at its seed | 1 day |
| D7 | **Fidelity ladder, cumulative omissions.** T0 this ADR; T1 chunks, counts, cache (`/5`), continuation starts; T2 extensions as an investigation; T2b operator input; T3 live, separately | T1 2–3 days; T2 unscheduled |
| D8 | **Gate and sequencing.** Preserve, build under a stated test contract, guard and calibrate, gate with a demonstrated rejection of a same-basis regression control, held-out process, long admission last | 2 days |

The number this ADR is judged on:
- A candidate in the admissible class is measured on a real session's workload, deterministically,
  with a verdict that names what was checked and what was not.
- A candidate outside the class is refused before it runs.
- A replay whose observations diverge is not scored.

## Context / the question

**Two of the three things called "replay" are the same thing, once the program is recorded from
the journal's replay.**

1. **DST strict replay** (`dst_program.ail:243–252`, `dst_replay.ail:395–397`, `:831`). It
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
2. **The ADR-003 journal fold** (`journal.ail:1679`). A fold over history deltas for resume.
   ADR-003 O2 rejected *driver replay for resume* and kept replay "for reproduction". It says
   nothing about evaluation.
3. **Live A/B** (`.motoko/ab/muse-replay-20260907T185514Z/`). Realistic, nondeterministic.

What was missing is a discovery run whose world is built from a journal: its script from the
recorded assistant turns, its tool queue from the recorded results, its environment from
declared values. The interaction log of that run is a program in the harness's own format, and
every candidate is then a strict replay of it. The journal and the host log are the oracle for
that one run; the **corpus entry** — snapshot, excerpt, selector and program together — is the
reproduction unit for all the others, because the seed stays in the snapshot (D2).

**The gap** is as v2 stated. No existing fixture has the workload shape a real session produced:
a ~0.9 MB content history seed (1,170,593 bytes of default Python JSON for 694 messages;
903,364 bytes of content) growing over hundreds of tool turns with real tool-output sizes. The
memory defect fixed in `de4b4f5` scaled with history bytes. Two workloads at the same commit
(not a controlled comparison):
- a synthetic 200-step probe with 4 KiB tool outputs: 33.3 GiB allocated;
- 150 steps replayed from a real journal: 128.9 GiB allocated.

**The evidence** (prototype `scripts/dst/mem_journal_replay.ail`, untracked in
`../motoko_agent-mem`; run r2.1 of `session_1789244855221-63164319c7d765ff`; HEAD `2fe783a`).
These are stored observations of the **terminal-augmented prototype**, not measurements of the
finite-turn entry this ADR admits, which has not been run:

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
the F6 shape `stub_step.ail:335–351` rejects), the fabricated terminator, the manufactured
`exit_code: 0` (`:106`), the min-length checker — are all replaced here; and its `Ok(ms)` arm
(`:153`, inside the result match at `:152–154`) never fires on the suspension end D2 uses.

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
the harness under a pinned evaluator.** Chosen (v3), retained by the v3 and v4 reviews.

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
`EndAt(e)` names the assistant entry of the **last evaluated call**, whose turn is kept;
`CutoffBefore(e)` names the first entry outside the segment.

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
`MotokoRuntimeStatus` built-in (below). A start that carries continuation state is
`Refused(ContinuationStart)` at T0 and handled at T1: a suspended run's continuation (`:2664`,
`run_v2_session_resumed_traced :5394`) **and a run opened by a consumed wake** — the resumer
seeds it as `SeedParked({ continuation, open_waits })` (`C2Seed`, `:4271`; `c2_state_from_parked`,
`:5531–5536`; `:5577`), a continuation with open waits, never a message-only start.

**Configuration.**
- The **logical model** from `settings` entries on the path, falling back to the header. The
  entry receives it and converts it once at dispatch (`session.ail:3824`); the seam receives the
  **API model**. The evaluator holds a copy of the whole of `provider_api_model`
  (`:272–293`: `openrouter/auto` kept; `openrouter/`, `openai/`, `anthropic/`, `google/`
  stripped; not idempotent), pinned by hash, for the expected identities. The excerpt's
  `provider_call_prepared.model` must equal the logical model.
- `BootInputs` supplies the task, `hybrid_tools`, budget, `env_url`, `max_cost_millicents` and
  `cost_rates` (r2.1: `hybrid_tools` true, total/solver 1200, verifier 0, step budget 1200,
  `ohmy_pi` false, cap and rates zero).
- **The T0 settings**, pinned in the entry and served through the world's environment and file
  table, because policy initialisation reads them through ports (`session.ail:2350–2388`) and
  they decide which completion arms are reachable. Every value is served; nothing is ambient:

  | Setting | Value at T0 | Why |
  |---|---|---|
  | `rt.verification` | `{ enabled: false }` | `run_dp7_verifier` executes a real subprocess otherwise (`:2241–2254`); disabled, `dp7_rejection_errors` returns `None` without `exec` (`:2287–2298`) |
  | `MOTOKO_PERSIST_RETRIES` | `"0"` | `should_inject_persist_nudge(budget, used, write_attempted)` is `budget > 0 && used < budget && not write_attempted` (`recovery.ail:59`); zero makes the nudge arm unreachable |
  | `ohmy_pi` | recorded (`false`) | `backend_for_v2(envelope, true)` can route a tool to `Delegated` (`tool_phase.ail:452–464`); `false` forces `Native` before name-based routing, so every tool reaches `ports.tool_exec` (`:484–501`) |
  | `hybrid_tools` | recorded (`true`) | hybrid extraction runs for a call-free response only while `session_emitted_native_tool_call` is false (`session.ail:4058–4066`; the predicate, `:2126–2140`). **The entry asserts the predicate** (below); a segment that fails it is `Refused(HybridPredicate)` |
  | `MOTOKO_HEADLESS`, `OPENAI_BASE_URL`, `MOTOKO_RETRY_STREAM_ERROR` | recorded | read once each at policy init (`:2352–2355`) |
  | `MOTOKO_SESSION_ID` | the recorded session id | read once (`:1727`); the derived id is the journal's |
  | `MOTOKO_PROFILE_DIR` | **explicit, non-empty**: `.motoko/eval-profile` | `profile_dir_path` reads it first and reads `MOTOKO_CONFIG`/`MOTOKO_REPO` only when it is empty (`context_usage.ail:139–150`); an explicit value makes those two reads unreachable **by construction**, not by assumption |
  | the profile config | `FsFile` at the exact key `.motoko/eval-profile/config.json` | `config_context_limit_override` requests `${dir}/config.json` through the file port (`:178–195`), which is `scripted_file` → `lookup_file` on the world's table, exact path, `FsFile` only (`ports.ail:1335–1364`); no host filesystem is touched |
  | context limit | in that file: `{"agent":{"context_limit": <n>}}` with the recorded raw window `n > 0`, or `{"agent":{"context_limit":"disabled"}}` when the recorded resolution was `Disabled` | `n > 0` → `ProfileWindow(n)` → `resolve_bounded_from_profile` (`context_limit.ail:129–132`), catalogue never reached (`context_usage.ail:241–250`); `"disabled"` → `declares_disabled` (`:168–175`; `disabled_profile_value`, `context_limit.ail:145`) → `ProfileDisabledDeclared`. A missing or non-positive key is `ProfileMissed` and reaches the catalogue and `MOTOKO_MODELS_FILE` — an entry that would do so is refused at admission by the witness. **Declared:** the resolution's `source` reads `ProfileOverride` even when the live run resolved from the catalogue; the raw window is equal |
  | `MOTOKO_CONFIG`, `MOTOKO_REPO`, `MOTOKO_MODELS_FILE` | not served | unreachable under the two rows above; the witness pins their counts at zero |
  | `MOTOKO_TOOL_TIMEOUT_MS` | recorded, else `"0"` | read once per native dispatch (`tool_phase.ail:485`) |
  | `MOTOKO_EXIT_MANIFEST` | **`""`** | read once on a `Finalize` end (`session.ail:3398` → `publish_turn_exit_manifest`, `:5041`; the read at `:5066`) and never on a suspension; `publish_exit_manifest` returns before any write when the destination is empty (`src/core/ext/exit_manifest.ail:202–203`), otherwise it writes a file and runs `exec("mv")` outside the recorded file port (`:204–223`). Pinned empty in **every** synthetic environment, failure fixtures included |
  | `MOTOKO_CAPTURE_FAILED_PAYLOAD` | **`""`** | read once on a non-retryable provider failure (`session.ail:3878`), the seam's exhausted `Err` included; a non-empty value calls `capture_failing_payload`, an ambient write of `.motoko/failing_payload.json` (`:1050–1057`). Pinned empty everywhere; zero reads on a served success |
  | `checkpoint_enabled` | `false` by the entry (`:2376`) | a `TakeCheckpoint` cannot fire; a live checkpoint inside the segment is the `HistoryReplaced` cutoff anyway |
  | `max_cost_millicents` | `0` | disables the cost arm (`step_machine.ail:112–113`) |

**Tool arguments.** The journal's argument strings are decoded as JSON and re-serialised
canonically (compact, keys in source order); a string that does not decode is
`Refused(MalformedToolArguments)`. That is the boundary the seam sees: `ToolInvocation.call` is
a `ToolCallEnvelope` whose arguments are already `Json` (`ports.ail:616–621`;
`tool_dispatch_adapter.ail:46–56`). Equality is JSON equality, not byte equality; retained
message bytes are still compared by the transcript chain. r2.1's 299 argument strings decode and
equal their compact serialisation *(review)*.

**The stopping contract.** The loop decides its next state from the **result's shape**
(`session.ail:4020`), and D1 classifies every recorded call by the same shape, consulting the
excerpt's finish string only where the shape alone cannot decide. In order:

1. **Continuation call** — at least one tool call, every call has a recorded result, no result id
   starts `hybrid-step-`. The loop enters the `tool_calls` state (`:4020`), journals the assistant
   before the tool phase (`:4020–4055`), runs its tools (`decide` serves pending calls before
   anything else, `step_machine.ail:123–128`) and returns to `call_model_or_fail`, which tests the
   budget before `CallModel` (`:103–111`; `CallModel` at `:118`).
2. **Incomplete batch** — at least one tool call, some call has no result: `IncompleteToolBatch`
   cutoff, before the whole turn (r2.1's 300th turn).
3. **Call-free `tool_calls` finish** — no tool call and `finish_reason == "tool_calls"`: the same
   branch as 1 with nothing pending, `last_finish_reason: "tool_calls"`; `decide` falls through to
   `call_model_or_fail` — the next call before N, the suspension at N — with no tool result in
   between (`step_machine.ail:123–159`). **Cut** (`CallFreeToolCallsFinish`, before the turn). It is
   coherent to replay, but admitting it would add a third call class whose only distinguishing
   datum is a finish string the journal does not carry; Not decided.
4. **Blank stop** — no tool call, finish not `tool_calls`, `trim(content) == ""`: reachable.
   `classify_candidate` skips stage 2 for a blank candidate, stage 3 finds no open wait, stage 4's
   empty registry yields `NoDecision` and the zero persist budget makes it `CandidateApproved`,
   stage 5 calls the disabled verifier and gets `None` (`session.ail:3267–3305`); the state is
   `dp7_approved`, `decide` finalises (`step_machine.ail:149–150`), and the run ends successfully
   with empty output, an `EmptyStopFinalize` wire record and `DoneEvent` (`:3378–3397`). **Cut**
   (`BlankStop`, before the turn): the admitted stop shape carries content, the blank shape is not
   in the evidence, and the entry records the cut from the call's shape, not from a later event.
5. **Stop call** — no tool call, finish not `tool_calls`, non-blank content: `classify_candidate`
   → `CandidateApproved` → `dp7_approved` (`:4135–4155`) → `Finalize(model_stop)`
   (`step_machine.ail:150`). Hybrid extraction stands between the result and `classify_candidate`
   (`:4058–4066`) and runs `extract_bash` only while the session has emitted **no native call** —
   `session_emitted_native_tool_call` over the accumulated messages, seed included, true on the
   first assistant call whose id does not start `hybrid-step-` (`:2126–2140`). The predicate is
   monotone, so the entry **asserts it once**: over the seed plus the assistant appends before the
   first stop call, when `hybrid_tools` is recorded true. False is `Refused(HybridPredicate)`; r2.1's
   seed satisfies it (review S4, `seed_native_call_predicate True`), and every continuation call
   after it does too.
6. **Hybrid extraction in the source** — a recorded tool result whose id starts `hybrid-step-`: the
   live run synthesised a call (`HybridBashExtracted`); `HybridExtraction` cutoff, before the turn.

So: **every call before N is a continuation call; call N is a continuation call (expected end
`EndSuspended(N)`: after its tools, `call_model_or_fail` fails with `StepBudgetExhausted`,
`c2_suspend` finds `continuation_history_ok`, `journal.ail:208`, and finalises with
`TermMaxSteps`, `session.ail:2778–2794`) or a stop call (expected end `EndFinalize(model_stop)`).**
A segment whose calls do not fit is cut at the first call that does not.

*Unreachable under the settings*, with the arm that makes it so: verifier rejection
(`dp7_rejection_errors` → `None`, `:2287–2298`); solver feedback (an empty registry collects no
decision and merges to `NoDecision`, `src/core/ext/runtime.ail:683–716`, `:721–727` *(review)*);
the persist nudge (`recovery.ail:59`); `Park` and `AwaitApproval` (`open_waits` starts empty,
`:988–1016`; native dispatch preserves it and only the extension `Handled` lifecycle adds a wait,
`tool_phase.ail:438–449`, `:499–506`; the park arm needs one, `step_machine.ail:137–147`);
`TakeCheckpoint`; the cost arm; `MotokoRuntimeStatus` and every other tool bypass — the built-in
callback tests exactly that name (`session.ail:3677–3681`; `tool_phase.ail:558–566`), empty policy
entries yield `NoOpinion` → the allowed arm and empty handle entries yield `Delegate`
(`src/core/ext/runtime.ail:402–406`, `:426–435`, `:477–493` *(review)*; `tool_phase.ail:608–615`).
*Reachable and cut*: shapes 3, 4 and 6. *Preconditions* that can end a run before its expected
end — invalid history at sealing (`session.ail:3330–3335`), a failing `project`
(`step_machine.ail:116–118`) — are found by A6 on the parent's admission run, not assumed away.
Zero recorded mutation witnesses do not prove the absence of the two ambient effects the settings
table pins away; the pins do.

**Segment ends.** Two kinds, never confused. A **cutoff** ends the segment before the entry (or
before the whole affected turn) and yields a shorter admissible segment; a **refusal** means the
source or its association is unusable for this selector.

| Cutoff | Why |
|---|---|
| `Completed(finish_reason)` | `run_finished` on the path: the genuine end |
| `Suspended`, `Resumed`, `SettingsChange`, `RunStarted`, `Exit`, `EofWithoutRunFinished` | run boundary or state change |
| `Parked` | a `park` entry inside the run (`journal.ail:1179`, `park_of_entry :1211`). The loop reached `Park`, which needs an open wait that only the extension `Handled` lifecycle opens (`tool_phase.ail:438–449`) — unreachable at T0 (empty registry, `wakes: []`). Cut **before the last assistant turn preceding the park entry**: the turn preceding a park is the call-free stop-class call k whose classification found an open wait (`step_machine.ail:141–148`; `session.ail:3274`); the wait was opened by a `Handled` tool on an earlier turn (`tool_phase.ail:439–447`). The segment ends at call k−1 with `EndSuspended(k−1)`; call k is dropped rather than kept as `StopBeforeEnd` because the live run classified it `await_wake`, not approved. `park.step` = k (`session.ail:3528`, attempt 0). Whatever follows the park inside the run — the `wake` child and the wake message the loop injects as a `user_injected` history append (`:3546–3551`) — is inside the cut. A park is a boundary of the loop's *state*, not necessarily of the run: an in-process wake continues the same run; a process death while parked makes the resumer open a new one (`:5338`, `:5414–5424`) |
| `ProviderRetry` | a `stream_error_retry` consumes a provider position with no assistant message (`session.ail:3862–3921` *(review)*) |
| `UserMessage` | an in-run user entry: operator input **or** runtime-injected feedback (`:3409–3441` *(review)*; the evidence log has two `ext_solver_feedback` events); role alone cannot tell them apart |
| `HistoryReplaced` | any reason, including `resume` |
| `ReplacesPrevious` | a replacement of an existing response, not a new call |
| `IncompleteToolBatch` | before the whole turn, when any of its calls lacks a result — r2.1's 300th turn |
| `CallFreeToolCallsFinish` | shape 3 above, before the turn |
| `BlankStop` | shape 4 above, before the turn |
| `HybridExtraction` | shape 6 above, before the turn |
| `RuntimeStatusCall` | before the turn whose assistant calls `MotokoRuntimeStatus`: its result is synthesised from `prior_counts` and cache totals (`session.ail:707`, `:757–763`) by the built-in callback (`:3677–3681`) and cannot be served from the queue |
| `StopBeforeEnd` | **the one post-turn cutoff.** A stop call at k < N that the source continued past without any of the entries above: the segment **keeps** call k and its assistant append, `end` becomes `EndAt(assistant entry of call k)`, N is recomputed to k, the selected call count and every expectation are recomputed to k, and the expected end is `EndFinalize(model_stop)`. Every other cutoff drops the turn it names; this one keeps it because a stop call is a complete, servable turn that decides the end. What the live run did afterwards is recorded as an observation, not explained: the traced entry returns at `Finalize` (`session.ail:3354–3409`) |

| Refusal | Why |
|---|---|
| `ChainBreak`, `MalformedEntry`, `UnknownEntryType`, `UnknownSchema` | ADR-003 D4 strictness. A `wake` with no open park, an already-answered park or another request's id is the fold's own refusal at `request_id` (`journal.ail:1603–1614`) and is `MalformedEntry` here |
| `DuplicateOrAmbiguousCallId`, `UnexpectedToolResult` | results cannot be attributed |
| `MalformedToolArguments` | the pinned JSON boundary |
| `Association` | excerpt and journal do not agree on the run's calls |
| `ContinuationStart` | T0: a suspended continuation or a wake-opened run (above) |
| `HybridPredicate` | `hybrid_tools` recorded true and the native-call predicate false at a stop call |
| `EmptySegment` | no evaluated call after the cutoffs |

`park` and `wake` decode at HEAD (`all_entry_types`, `journal.ail:1253–1256`, twelve types;
`ParkEntry`/`WakeEntry`, `:1179–1180`; the fold's arms, `:1595–1614`; `BoundaryParked`, `:1316`),
so v4's "no decoder" refusal is withdrawn: the boundary is a consequence of the loop's reachable
states, not of the reader.

**Output.**

```
JournalWorld = {
  seed: [Message], seed_digest: string,                  -- validated against the independently folded source
  config: RecordedConfig,                                -- logical model, profile, BootInputs, recorded env values, context limit and its source
  settings: T0Settings,                                  -- the table above, as served; hybrid_predicate: bool
  calls: [RecordedCall],                                 -- in order; N = length
  end: { cutoff: Cutoff, expected: EndSuspended(int) | EndFinalize(string) },
  expected: { chain: [string], payload: [string], system_prefix: [string],
              logical_models: [string], api_models: [string], msg_counts: [int],
              tool_invocations: [ToolKey],               -- ToolKey = (call_id, name, canonical-JSON argument digest)
              decisions: int },                          -- 2N + 1 for EndSuspended(N), 2N for EndFinalize at N (D3)
  unreproduced: { prior_counts: RuntimeStatusCounts, cache_usage: [{ read: int, creation: int }],
                  context_limit_source: string },
  omissions: [Omission]
}
RecordedCall = { step: int, assistant: Message, finish_reason: string,
                 usage: { input: int, output: int, cache_read: int, cache_creation: int },
                 tools: [RecordedTool] }
RecordedTool = { call_id: string, name: string, arguments: Json, content: string }   -- exit status not recorded
```

For r2.1: N = 299, 299 tools, 598 appends, expected end `EndSuspended(299)`, 599 decisions.

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
  env:     the recorded values and the T0 settings, MOTOKO_EXIT_MANIFEST and MOTOKO_CAPTURE_FAILED_PAYLOAD present and empty,
  clock_ms: the declared epoch,
  files:   [{ path: ".motoko/eval-profile/config.json", node: FsFile(<D1's config>) }],
  approvals: [],  wakes: [] }
```

Cache usage is served as zero: `ScriptedStep` has no cache fields and the codec writes none
(`ports.ail:2507–2553`); `scripted_to_step_result` zeroes both (`stub_step.ail:72–90`).
Telemetry copies input and output tokens only (`model_phase.ail:17–25` *(review)*), the
journal's `state_delta` carries the same two, and the cost arm is off. What does depend on it is
on the wire — `ThinkingInfo` and the summary usage — and the `MotokoRuntimeStatus` result, which
D1 cuts. It is listed as unreproduced. Widening `ScriptedStep` and the codec is `/5` (D7).

**The entry.** `run_v2_session_traced` (`session.ail:4423–4442`) with the recorded
`BootInputs`, the **logical** model, the seed, a throwaway `workdir`, **`step_budget = N`**,
`max_cost_millicents: 0`, an `ExtRuntime` with an empty registry and `verification.enabled =
false`, and a new **test-provider variant** `PortedWorld(Ports, WorldState)`. It is added to
`StepProvider` (`stub_step.ail:69`) with one arm in `ported_provider` mirroring
`RecordingWorld`: `PortedWorld(p, w) => { ports: p, world: w }` (`session.ail:1532–1547`, the
`GeneratedWorld` arm at `:1545`); `frame_ordinal0` gains `PortedWorld(_, w) => w.ordinal`
(`scripts/dst/ledger_parity_dst.ail:428–435`); the constructor is imported where the arms live
(`session.ail:195`, `ledger_parity_dst.ail:73`). `test/scripted_ports.ail:30–35` is a three-arm
legacy match over `Scripted`, `LiveAI` and `Ported` and is left as it is, with its non-coverage
of world-bearing providers stated in the commit. It is not a `Ports` field, a production entry
or a helped request; nothing that runs today changes adapters. **The commit is line-neutral**
(D5): the sum is extended on its line, the arm and the import are joined onto existing lines,
as `stub_step.ail:44` and `tool_phase.ail:484` already do to keep anchors still (PLAN-004 P1.1
verified the five joins at `3920814`).

**The ports.** `{ base | model_step: eval_model_step(base), tool_exec: eval_tool_exec(base) }` where
`base = recording_ports(rt)` (`stub_step.ail:635–658`) — the
harness's recording adapters with two evaluator-owned seams by **guarded delegation**:

- **`eval_model_step(base)`.** If `state.script` is empty, the seam does **not** delegate: the
  harness's own empty arm returns `Ok(terminal_step())`, a fabricated assistant turn
  (`stub_step.ail:488–505`, `terminal_step :95`) — the prototype's terminator, one layer down.
  Instead it records the marker through `record_interaction` (`ports.ail:1827–1843`) with
  `ProviderIdentity("loop_v2", k, api_model)` — k = the number of `ProviderIdentity` records in
  `state.log`, computed by the evaluator (the quantity the private `provider_calls_in`,
  `stub_step.ail:561`, computes) — the projection
  `"model_step model=… msg_count=… replay=exhausted"`, deadline `-1`, and **exactly the record the
  harness's exhausted arm writes**: `{ advance_ms: 0, chunks: [], payload:
  encode_exhausted_provider_outcome(), status: OutcomeOk, fault_class_id: "" }` (`ports.ail:2522–2524`,
  `{ "served": false }`, which `script_of` skips, `dst_replay.ail:689`). It returns `{ emissions: [],
  result: Err({ code: "replay_exhausted", message, retryable: false }), next_state }`. The marker
  carries no serialised `AIError`; the `Err` is constructed, not decoded. Otherwise delegate
  to `base.model_step` — `recording_model_step` serves the step and records the interaction
  with the whole `StepResult` as outcome (`stub_step.ail:478–542`) — assert that the log is the old
  log plus **exactly one** interaction (a structurally equal prefix), and **replace that interaction's
  `request_projection`** with `"model_step model=… msg_count=… payload=<D> system=<S> raw=<R>"`:
  `D` the private canonical payload digest, `S` the private system-prefix digest over the leading
  system messages (`system_prefix_digest_for`, `phase_vocab.ail:369–370`), `R` a private **raw frame
  digest** over the whole transient payload (the append-chain frame with raw content and images,
  `:321–358` *(review)*), so the canonical blind spots (`make[N]`, omitted images, `:275–300`
  *(review)*) are covered against the parent. Identity, outcome, chunks, emissions, cursor,
  `ordinal` and `pending` are untouched; `record_interaction` assigns the ordinal from the log
  length and advances nothing else. Nonempty-script cardinality holds on every normal return —
  success, fault, `scripted_step_faults` (`stub_step.ail:506–541`; `ports.ail:2165–2172`) — and
  T0 plays no chunks, so the callback appends nothing.
- **`eval_tool_exec(base)`.** If `state.tools` is empty, the seam does not delegate: `world_tool`'s
  empty arm is the **live** arm and performs the real effect (`ports.ail:1723–1749`). It records
  through `record_interaction` with `ToolIdentity("loop_v2", call_id, name)`, the projection
  `"tool_exec call_id=… tool=… args=<digest of the canonical JSON of inv.call.arguments> workdir=…
  timeout_ms=… started_at_ms=… replay=unrecorded"`, deadline `inv.timeout_ms`, and the **complete
  failure record** `tool_outcome_record`'s `ToolFailed` arm writes (`ports.ail:2133–2145`, private,
  so the seam builds it from exported parts): `{ advance_ms: 0, chunks: [], payload:
  encode_tool_outcome(o), status: OutcomeFault, fault_class_id: fault_class_tool_failed() }`
  (`encode_tool_outcome :2577`; `dst_fault_catalogue.ail:61`), where `o = ToolFailed({ tool_call_id:
  inv.call.id, code: "replay_unrecorded_invocation", message })` (`ToolOutcome`, `ports.ail:647–651`).
  It returns `{ outcome: o, next_state }` with the clock unadvanced. Otherwise delegate to
  `base.tool_exec` (`recording_tool`, `:2056–2068`, over `world_tool`'s scripted arm, whose
  correlation guard returns `ToolCorrelationMismatch({ expected_id, got_id })` on an id mismatch,
  `:1775–1777`; every scripted outcome — completion, mismatch, deadline, failure — returns normally
  after cursor and clock advancement and is classified by `tool_outcome_record`), assert one
  appended interaction with a structurally equal prefix, and replace its projection with the same
  string without `replay=unrecorded`.

No private helper is used and no export is added. The core recorder's projections are not
widened, so no recorded fixture is re-baselined. The seams depend on `record_interaction`, the
outcome codecs, `recording_ports`, `recording_tool`, `world_tool` and what those serve through,
which are candidate files: they are the **protected closure** (D5). A wider projection is ordinary
text to persistence (escaping covers backslash, tab, newline and carriage return; `=` and `<`
round-trip, `dst_persistence.ail:211–239` *(review)*), is compared verbatim by
`ProjectionDiffers`, and is scanned by `scan_interaction` (`dst_secrets.ail:431–439`);
`validate_bounds` does not bound it.

**What a mismatch does.** A provider `Err` ends the run (`TermProviderFailure`, after the one
`MOTOKO_CAPTURE_FAILED_PAYLOAD` read); a tool failure becomes a tool transcript message
(`tool_phase.ail:277–296`) and the run can still reach the expected end, so K2 and the transcript
chain (K7) reject it separately. Both are in the world log. **The exhausted marker is never a
served record**, and its diagnosis is not one finding: a run containing one fails A6/K6 by the
explicit no-marker condition; where `strict_replay_findings` reports it depends on the expected
log — `ProgramExhausted(pos)` only when the program has no interaction left at that position
(`dst_replay.ail:374–379`), a `ProjectionDiffers`/`OutcomeDiffers` at that position when a served
interaction was expected there (`:358–367`), and an earlier mismatch, if any, is the **first** and
is the verdict's. The envelope names the marker's position beside the first mismatch.

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
{ schema_version: program_schema_version(),          -- execution-program/4 at HEAD (dst_program.ail:132; the schema history at :119–152)
  generator_id: "journal_admission", generator_version: <E's commit>, seed: 0,
  initial_world: {
    messages_and_policy: <JSON: session, RunSelector, seed_digest, seed message count, expected end, T0 settings>,
    synthetic_environment: env, files: the synthetic profile config, clock_epoch, extension_profile: "driver_only/<version>" },
  bounds: the observed maxima (chunk_draw_hi 0),        -- data, not a limit
  manifest: driver_only_manifest(source_revision, toolchain, abi_version, normalized_configuration,
                                 classifier_2_set, unrouted_fields, scan_root_commit),   -- dst_driver_only.ail:1097–1123
  interactions: world.log }
```

`driver_only_manifest` fills the build-derived fields itself — profile id and version, the
vocabulary and four rule versions, `scan_roots`, empty `extension_packages` — and takes the seven
run-specific values from the caller. **Provenance is gathered, then checked against a different
source** (A9b, D3): `discovered_manifest` passes literals (`"HEAD"`, `"ailang 0.33.0"`, `"7.4"`,
`"{}"`, three classifier names, `["clock_now"]`; `strict_replay_dst.ail:631–633`) and is not a
source of anything; `validate_manifest(m, driver_only())` (`dst_profile.ail:1535–1573`) checks
non-blank strings, non-empty `classifier_2_set` and `scan_roots`, the profile and the five version
comparisons, and accepts a stale-but-non-blank literal, so it is a shape check, not provenance.
`validate_schema` requires only non-blank ids and a decodable version (`dst_program.ail:357–369`);
`validate_program` (`:589–596`) does not call `validate_bounds` (`:648–653`).

`InitialWorld.messages_and_policy` is an opaque string (`dst_program.ail:182–188`; every
fixture fills it with a description, `strict_replay_dst.ail:651`), and the harness's replay loop
takes its seed from a fixture literal (`history()`, `:226`). **The seed stays in the journal
snapshot**, referenced by digest, and the corpus entry supplies and verifies the actual `[Message]`;
the **corpus entry** (snapshot + excerpt + selector + program) is the reproduction unit, and the
program alone is not one in D11's sense. Carrying `[Message]` in the program is `/5` and Not
decided.

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
  evaluator path, `ailang.lock`, `ailang.toml`, `packages/**`, and the protected closure in
  `ports.ail`, `session.ail` and `stub_step.ail`.

**Admission checks**, computed by the evaluator against the source, at admission commit A,
on the parent's run:

| # | Check | Against |
|---|---|---|
| A1 | Source chain: the segment's `digest_after` chain recomputes from the snapshot, and the seed digest equals the independently folded prefix — the expectation is the snapshot's **recorded** `digest_after` values, never a value the admission derived | snapshot |
| A2 | Source transcript: `final.history` equals seed ++ every recorded append, byte for byte; the trace's `HistoryAppended` records chain from the seed digest to the snapshot's `digest_after` values with exact count. This is evaluator code beside `JournalFold`, not that family with a different comparand | snapshot |
| A3 | Requests: per call, the program's `payload=` and `system=` equal the excerpt's digests, its identity's model equals the pinned conversion of the excerpt's logical model, `msg_count` equal, exact count | live excerpt |
| A4 | Invocations: the program's tool identities and `args=` equal the journal's decoded calls, in order, exact count | snapshot |
| A5 | Framing: `WORLD_RUN` frames, ordinals, empty pending queue | ADR-001 D2 |
| A6 | End: the expected end reached — `result` code `StepBudgetExhausted` with `suspended: Some` and `RunSuspended` in the trace, or `Ok` with `model_stop` — **and no exhausted marker anywhere in the log** (an explicit scan for the `{ "served": false }` payload, independent of what K2 would say) | entry |
| A7 | Witness: `check_discovery(world.log, witness)` is empty, with the witness **built by the runner** from the run and the entry (below) | trace and worlds |
| A8 | Invariants: `evaluate(execution_of(run, epoch, NoReplay, decisions, 0, 0, [], replay_metadata_of(manifest)))` is empty (`dst_execution.ail:100–126`; `dst_invariants.ail:2010–2024`), `family_evidence` (`:2043–2067`) recorded **unchanged**, and the **census** (below) recorded and asserted | execution bridge |
| A9 | Round trip: `validate_program`, `validate_manifest`, `world_state_of`, `reconstitution_balance` all clean on the program just recorded | program |
| A9b | Provenance: every manifest and identity field gathered by the runner equals its independent comparator (D5's table), before the run and again after it | a second source per field |

**The witness.** `DiscoveryWitness` (`dst_discovery.ail:260–310`: six runtime fields plus
`file_writes`, `file_removes`, `dir_makes`, `extension_effects`, `expected_env_reads`) for an
empty-registry run: `provider_calls` from `ProviderCallPrepared` records in the trace
(`strict_replay_dst.ail:310–315`); `tool_dispatches` from queue consumption (initial minus final
`tools`); `approval_reads`, `approvals_consumed`, `file_writes`, `file_removes`, `dir_makes`,
`extension_effects` **zero**; `clock_delta_ms` = final minus initial clock of the worlds, which
`check_discovery` compares with the sum of every recorded advance (`:540–541`; tool durations,
provider steps, each `recording_clock` tick, `ports.ail:1851–1862`) — never a hard-coded number of
clock reads; `expected_env_reads` one entry per key of `driver_env_keys()` (`:224–237`, the twelve
below), explicit zeros included, because `env_balance` checks multiplicities of the supplied list
and derives no provenance (`:407–417`, `:542–544`). **T** is the number of native dispatches.
Accepted ends and the fault path are separate columns; only the first two are admissible:

| Key | `EndSuspended` | `EndFinalize` | non-retryable provider failure (never admitted) | Source |
|---|---:|---:|---:|---|
| `MOTOKO_PERSIST_RETRIES` | 1 | 1 | 1 | `session.ail:2352` |
| `MOTOKO_RETRY_STREAM_ERROR` | 1 | 1 | 1 | `:2353` |
| `OPENAI_BASE_URL` | 1 | 1 | 1 | `:2354` |
| `MOTOKO_HEADLESS` | 1 | 1 | 1 | `:2355` |
| `MOTOKO_PROFILE_DIR` | 1 | 1 | 1 | `context_usage.ail:140` |
| `MOTOKO_CONFIG` | 0 | 0 | 0 | explicit profile dir (`:142–146`) |
| `MOTOKO_REPO` | 0 | 0 | 0 | same (`:146–150`) |
| `MOTOKO_MODELS_FILE` | 0 | 0 | 0 | profile branch resolves (`:241–250`) |
| `MOTOKO_SESSION_ID` | 1 | 1 | 1 | `session.ail:1727` |
| `MOTOKO_TOOL_TIMEOUT_MS` | T | T | T | `tool_phase.ail:485` |
| `MOTOKO_EXIT_MANIFEST` | 0 | 1 | 0 | `session.ail:3398`, `:5066` |
| `MOTOKO_CAPTURE_FAILED_PAYLOAD` | 0 | 0 | 1 | `:3878` |

The fixture's approval-based witness and non-vacuity rule (`strict_replay_dst.ail:366–378`,
`:792–795`) are not reused. Zero approvals, mutations and extension effects are route
expectations for the constrained route; `RandomDraw` is separately pinned at zero
(`dst_discovery.ail:473–519`).

**The bridge (A8, K4).** `execution_of` takes the run, the epoch, a `ReplayObligation`, a
`decision_budget`, a `retry_budget`, `ambient_rng_reads`, `forbidden_effect_sites` and a
`ReplayMetadata` (`dst_execution.ail:100–126`). The entry fixes them:
- **Obligation.** `NoReplay` at admission — the admission run *is* the discovery run and its
  comparands are A1–A4; `ReplayConsistency` is then the one family whose `evaluated` flag is
  false (`dst_invariants.ail:2057`, `:1753`), stated as such. `StrictAgainst(program.interactions)`
  for a candidate (`:599–602`, `:1754`), so the family is exercised; K2 remains the authoritative
  comparison and the verdict's first finding comes from K2 when both report.
- **Metadata.** `replay_metadata_of(manifest)` (`dst_profile.ail:1582–1588`): source revision,
  toolchain, profile id and version, vocabulary version, from the gathered manifest.
- **Budgets.** `decision_budget` is derived from the entry's shape, not set to N: the loop
  appends one `DecisionRecord` per `decide` (`session.ail:790`, `:3339`) and
  `bounded_progress_findings` counts them (`dst_invariants.ail:1570–1579`) — two per continuation
  call (`CallModel`, `RunTools`) plus the terminal decision, so **2N + 1** for `EndSuspended(N)` and
  **2N** for a stop at N (`JournalWorld.expected.decisions`); the census asserts the observed count
  equal at admission, and the bound is that count. `retry_budget` is **0**: a retry inside a
  segment is a cutoff. `ambient_rng_reads` 0 and `forbidden_effect_sites` `[]` are supplied
  observations under cooperative trust (D5), not proof that arbitrary code had no ambient effect.

**The census.** `family_evidence` is kept exactly as the harness reports it — thirteen rows,
`{ family, evaluated, inputs }`, where `inputs` is the trace's record count or the log's length
(`:2043–2067`) — and it is not asked to say what it cannot: with a non-empty trace every family
but `ReplayConsistency` (under `NoReplay`) reads evaluated with positive inputs, and
`CheckpointHistory`'s chain check is vacuous whenever no checkpoint exists (`:1631–1640`). Beside
it the evaluator records a **sub-obligation census**, one row per excluded input, each a count with
its route assumption, computed independently of the family API:

| census row | T0 expectation | how counted |
|---|---|---|
| checkpoints | 0 | `TakeCheckpoint` decisions and checkpoint records in the trace |
| stream chunks | 0 | `chunks` over the log's provider interactions |
| approval reads / approvals consumed | 0 / 0 | approval identities in the log; the world's cursor |
| waits opened / parks / wakes | 0 / 0 / 0 | `ExtToolHandled` waits, `ParkEntered`, `WakeReceived` in the trace |
| extension effects | 0 | extension-effect identities in the log |
| retries | 0 | `StreamErrorRetry` in the trace |
| injected messages | 0 | `InjectUserMessage` decisions |
| hybrid extractions | 0 | `HybridBashExtracted` in the trace |
| file writes / removes / dir makes | 0 / 0 / 0 | the recorded mutation identities |
| exit-manifest publications | 0 (`EndSuspended`) / 1 read, 0 writes (`EndFinalize`) | the env read; no file class recorded |
| capture reads | 0 | the env read |
| decisions | `expected.decisions` | `DecisionRecord` count |
| not observed | — | `path_stat`, `dir_list` (never recorded, `stub_step.ail:635–658`'s note); live extension effects; streaming; compaction |

Four words are kept apart in every report: **family evaluated** (`family_evidence.evaluated`),
**family aggregate inputs** (`family_evidence.inputs`), **sub-obligation exercised** (a census
row above zero), **not observed** (no recorder exists). No family is invented and the rich
fixture's approval non-vacuity rule (`strict_replay_dst.ail:792–795`) is not applied.

**Candidate checks**, per candidate C, on the assembled tree:

| # | Check | Source |
|---|---|---|
| K0 | Preflight: the entry's manifest, profile, toolchain and binary hash, corpus hashes, T0 settings and **execution provenance** (D5) equal what the runner assembled and observed; evaluator and protected-closure hashes unchanged, before and after | entry, E |
| K1 | `world_state_of(program)` succeeds and `reconstitution_balance` is empty | harness |
| K2 | `strict_replay_findings(program.interactions, run.world.log)` is empty — kind, origin, identity, projection (model, message count, canonical payload, system prefix, raw frame, tool arguments), outcome, exhaustion and unused, by position | harness |
| K3 | `check_discovery(C.world.log, witness_C)` is empty, where **`witness_C` is built from C's own run**: `provider_calls` from C's trace's `ProviderCallPrepared` count, `tool_dispatches` from C's initial minus final queue length, `clock_delta_ms` from C's worlds, the source-derived `expected_env_reads` and the route zeros from the entry. **Then, separately:** C's three runtime counts equal the entry's. A trace with N + 1 prepared calls and N records fails the class balance whatever the stored witness says. The candidate's prepared-event **digests** are not consulted — K2 carries the private digests in the projections — but its prepared-event **count** is | harness; entry |
| K4 | `evaluate` under `StrictAgainst(program.interactions)`, the entry's budgets and metadata, is empty; `family_evidence` equals the entry's record; the census, recomputed from C's run, equals the entry's | harness; entry |
| K5 | Framing, as A5 | ADR-001 D2 |
| K6 | End, as A6, including the no-marker scan | entry |
| K7 | Source transcript, as A2, on the candidate's trace: A2's function reused unchanged, against the entry's seed digest and recorded chain | entry |

Comparands: K1–K7 compare C's run with the **entry** — its program, expectations and recorded
census — never with anything derived by the admission run beyond what the entry stores.

**The verdict.**

```
Location  = Interaction(ordinal)                           -- a program position (K1, K2, K4's replay family)
          | Call(k)                                        -- a provider call (A3, A6, K6)
          | Source { source: Snapshot | Excerpt, position } -- an entry seq or an event index (A1, A2, A4, K7)
          | Aggregate(name)                                -- a balance or family with no position (A7, K3, K4, A5/K5 frame totals)

Admission = SourceFaithful { entry, calls: N, end, envelope }
          | Refused        { reason: Refusal | AdmissionCheck(A1..A9, A9b, location) | ScanRefusal }

Candidate = Reproduced { calls: N, end, envelope }
          | Diverged   { location: Location, finding: ReplayMismatch | ReconstitutionFinding | DiscoveryFinding | Violation | CensusMismatch | FrameMismatch | EndMismatch | ChainMismatch }
          | Refused    { reason: InadmissibleCandidate | EvaluatorTouched | ProtectedRegionTouched | PreflightMismatch | GuardTripped | ProgramUndecodable(ReplayRefusal) }
```

`Diverged` uses the harness's vocabulary where it has one (`ReplayMismatch`: `WrongKind`,
`WrongOrigin`, `UnsafeIdentity`, `ProjectionDiffers`, `OutcomeDiffers`, `ProgramExhausted`,
`UnusedInteraction`, each with its interaction position; `DiscoveryFinding` and `Violation` as
aggregates unless the finding names a position) and the evaluator's for frames, end, chain and
census. The **first** finding in K-order, at its own location, is the verdict's; no interaction
index is invented for a global balance failure, and a sentinel is never used where a tagged
location exists. Regression mode (`regression_replay_findings`, `dst_replay.ail:438`) is available
for diagnosis and never scores.

**The envelope.** Printed with every verdict.
- **Checked:** A1–A9 and A9b at admission; K0–K7 per candidate.
- **Pinned and preflighted:** the recorded config, the T0 settings, the registry used, the
  execution provenance.
- **Unreproduced, declared:** `prior_counts` and every `cumulative` on the wire; cache usage in
  `thinking`, the summary and totals; tool exit status; the context-limit resolution's `source`.
- **Not observed at all:** model parameters, tool schemas and request encoding
  (`Ports.model_step` receives a model string and messages, `ports.ail:886`); real tool
  execution; streaming; extensions (r2.1's 115 `Delegate`/`DelegateCheck` calls are served as
  recorded content, their live extension effects omitted); compaction; live GC timing;
  `path_stat`/`dir_list`.
- **Family evidence and the census**, both records, with the four words above.
- **What the raw frame covers and does not:** it pins the transient payload's content and image
  sources against the parent's admission run, not against the live request; an image URL does
  not freeze the bytes behind it. Tool arguments are compared as JSON, not bytes.
- **Which evidence the run's identity rests on:** the marker check, or the execution-provenance
  record when the marker is not applicable (D5).

"Byte-identical requests" is not claimed. A3 is equality under the canonical projection against
the live excerpt; K2's raw frame is equality against the parent's admission run, which is
**candidate–parent agreement**, not live equality.

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
| Cumulative profiled allocation (GiB) | **Primary** | The measured process is the evaluator's replay program from start to exit: load and hash-check the entry, **fold the snapshot prefix into the seed** with the evaluator's own fold (A1's fold runs inside the profiled AILANG process — never a shell or Python pre-fold — and is part of the measurement, equally and as common overhead for parent, control and candidate; its implementation is recorded in the identities), load and validate the program, `world_state_of`, the traced run to its end, `strict_replay_findings`, the witness, `evaluate`, the census, the chain. Extraction, admission of the entry and persistence are not in it. Pinned: runner, `ailang` binary hash, `GOGC`/`GOMEMLIMIT` recorded (unset by default), profile flags. One warm-up run per assembled tree, guarded, recorded in the exposure log, applied equally to parent, control and candidate; that recompilation explains the observed 22.12 against 10.88 / 10.86 GiB first-run outlier is a **hypothesis**. The tolerance comes from D8's calibration on the finite-turn entry with this evaluator; 0.1158% and 0.2774% are prototype observations and pin nothing |
| GC count, live heap after GC | Secondary | Timing-dependent (prototype: baseline 97/99/93 GCs, 1,898/2,450/2,343 MiB max live heap; fixed 34/34/33, 1,213/1,271/1,272 MiB) |
| Peak RSS | Secondary | Timing-dependent; the replay omits live waits (prototype: baseline 83–144 s, fixed 56–61 s for 300 requests) |
| Recursion depth | Secondary, whole-process | No phase boundary exists that would exclude the evaluator's own recursion by measurement; until one does (Not decided), the number is the evaluator process's — reader, fold and checks included — with the evaluator's folds named |
| Trace invariants | Yes, listed | The thirteen families through `evaluate`, reported with `family_evidence` unchanged and the census beside it. They do not cover the conversation loop, input waits, TUI, extension effects or streaming chunks (PLAN-003 §0.6) |
| Task quality, tool-choice quality, latency, provider behaviour | **No** | Responses are recorded |

Results are *measurements of the named simulated execution*, which includes the synthetic
suspension, the seed fold and the checks. A change to a path the replay does not execute cannot
be accepted on them, and is inadmissible anyway (D3).

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

**Protected regions: the closure, not a list of entry points.** `ports.ail`, `session.ail` and
`stub_step.ail` are candidate files — the loop under measurement lives in the second — and they
also hold what the seams delegate to and what those delegates serve through. The entry pins, by
hash of the original bytes of each declaration at A, the **dependency closure of
`recording_ports`' bindings and of the two seams' delegates**, read at A and reviewed with the
manifest, generated by P1.4b by symbol from `git show A:<path>`; the members below are the
reviewed starting set:
- in `ports.ail`: `record_interaction` (`:1827`); the provider codec — `encode_provider_outcome`,
  `decode_provider_outcome`, `encode_exhausted_provider_outcome` (`:2507–2553`); the tool codec —
  `encode_tool_outcome` (`:2577`), `decode_tool_outcome` (`:2608`); `world_tool` (`:1723`),
  `scripted_tool_outcome` (`:1775`), `recording_tool` (`:2056`), `tool_outcome_record` (`:2133`),
  `provider_outcome_record` (`:2217`), `scripted_step_ai_error` (`:2165`), `scripted_step_faults`
  (`:2171`); `recording_clock` and `virtual_clock` (`:1851`, `:1305`); `recording_env`,
  `scripted_env`, `lookup_env`, `env_has_key` (`:1851–1895`, `:1311–1320`); `ports_shape_probe`
  (`:2855`), `scripted_file`, `lookup_file` (`:1335`, `:1356`); the bound approval and wake
  defaults `scripted_approval`, `recording_approval`, `scripted_wake`, `recording_wake` (`:1086`,
  `:2020`, `:1178`, `:1201`) and the bound mutation and effect recorders — the four `recording_ports`
  binds, `recording_file_write`, `recording_file_remove`, `recording_dir_make`, `recording_ext_effect`
  (`:1931`, `:1957`, `:1993`, `:2107`; bound at `stub_step.ail:642–658`), and `ports_shape_probe`'s
  `scripted_file_write`, `scripted_file_remove`, `scripted_dir_make`, `scripted_path_stat`,
  `scripted_dir_list`, `world_ext_effect` (`:2870–2874`, `:2883`); the transitive members review §3.8
  names — the codec helpers `tool_calls_json`, `tool_calls_of` and the JSON field readers `bool_field`,
  `str_field`, `int_field`, `json_array` (`:2514`, `:2543–2550`), `live_tool_outcome` (`:1744`),
  `cursor_wake` (`:1179`); the types `ToolInvocation`,
  `ToolCallEnvelope`, `ToolOutcome`, `ToolExecution`, `TimedOutcome`, `OutcomeStatus`, `ScriptedStep`,
  `ScriptedTool`, `WorldState` and `Ports`;
- in `stub_step.ail`: `recording_ports` (`:635`), `recording_model_step` (`:478`),
  `scripted_to_step_result` (`:72`), `terminal_step` (`:95`), `play_chunks` (`:121`),
  `scripted_chunks` (`:136`), `chunk_records` (`:554`), `provider_calls_in` (`:561`),
  `dispatch_step` (`:791`), the `StepProvider` sum (`:69`);
- in `session.ail`: `provider_api_model` (`:272–293`, the live conversion the evaluator's copy is
  compared with), `ported_provider` (`:1532–1547`), and `dispatch_step`'s call site (`:3824`);
- in `dst_fault_catalogue.ail` (path-refused anyway): the class literals (`:61–63`, `:82–85`) and
  `provider_error_is_retryable` (`:152`, review §3.8);
- in each of the three files, the **imports region** (every import statement, as one span per
  contiguous run) and every type declaration a listed function names.

A candidate diff that changes a listed declaration, an imports region, or a named type is
`Refused(ProtectedRegionTouched)`; a change to one is a basis change. What is **not** frozen, on
purpose: the measured session loop itself, `phase_vocab.ail` (`de4b4f5` touched it; the private
digest copies are what make that admissible), `journal.ail`, `context_usage.ail`, `step_machine.ail`
and `tool_phase.ail` — legitimate candidates change these; the witnesses, the chain and the raw
frame are what catch a change that alters an observation. The closure is reviewed, not derived:
P1.4b's manifest lists every member with its span hash, and a review of the closure is part of
`P1G`. An edit outside every span that changes a recorder's input is not a checker defect but a
missing member, reported to the next revision (D8's M15 row for `ProtectedRegionTouched`).

**The checker** (`tools/eval_protected/`, Python; PLAN-004 P1.4b's contract is adopted). It hashes
**original bytes** of exact spans: a braced declaration from its first line to its matching brace,
extended through a following `deriving (…)`; a non-braced union to the last non-blank line before
the next column-0 declaration, a heuristic cross-checked by type-checking a copy with the span
removed; one aggregate imports span per contiguous run of import statements, statements parsed
across lines and several per line (`stub_step.ail:28–33`, `:44`; `ports.ail:60–67`). Braces and
parentheses are counted outside string literals (with `${…}` interpolation) and `--` comments; an
unterminated literal or unbalanced brace is a hard error (P1.4b's lexer). No whitespace
normalisation: `check.py`'s `normalize` collapses whitespace for ADR prose
(`tools/predicate-anchors/check.py:62–73`) and would erase a semantic change inside an AILANG
projection string; `derive.py`'s `strip_noise` and `func_spans` (`tools/driver_leaf_inventory/derive.py:63–86`,
`:320–329`) locate declarations but erase literals and extend a span to the next start, so their
techniques are borrowed and their hashes are not. The decision is taken **at C**, by symbol: a
protected symbol missing, duplicated, moved to another file, or hashing differently — span or
imports region — refuses, naming each. Comments inside a span are protected; outside every span
they are not. The self-test list is P1.4b's: whitespace inside a projection literal, one token in
`tool_outcome_record`, an added import name, an alias change, a moved function, a renamed function
re-added elsewhere (allowed: the span is unchanged), a change outside every span (not detected, by
design), the parser cross-check on every non-braced span.

**The evaluator**, at pinned commit **E** in its own worktree (`../motoko_agent-eval`;
PLAN-004 §0.5's paths):
- the D1 reader and its refusals, with **copies** of `journal.ail`'s decoders and fold rather than
  imports: the fold runs inside the measured process (D4) and must be common overhead for parent,
  control and candidate, and importing it would force `journal.ail`'s fold and decoders into the
  protected closure — excluding exactly the fold and decoder changes D3's class admits. Each copy
  records the SHA-256 of the source span it copies at A, checked by the protected checker so that
  drift between the copy and the candidate's `journal.ail` is **reported**, not refused; A1 and a
  fold-equality test against `fold_journal` (`journal.ail:1679`) at A keep the copy honest, and a
  journal schema change is a basis change that refreshes it;
- the world builder; the two seams; the private digest functions (canonical payload, system
  prefix, raw frame, canonical-JSON arguments), pinned by hash and not imported from the
  candidate's `phase_vocab.ail` or `journal.ail`; the copy of `provider_api_model`;
- the admission runner (A1–A9, A9b), the candidate runner (K0–K7), the witness builder, the census,
  the guard, the manifest builder, the scan policy, the protected checker;
- the corpus, the expected observations, the pins and budgets.

**The assembled tree.** The runner assembles candidate C's tree with the evaluator paths from E.
It refuses `Refused(EvaluatorTouched)` if C's diff against its parent touches an evaluator path;
verifies E's, the corpus's and the protected closure's hashes before and after; and records the
**assembly identity**: the tree hash of C's files as assembled, E, and any compatibility patch.

**Execution provenance.** A tree hash names assembled source, not what the compiler loaded, and
`ailang` v0.33.0 prints no module-to-file mapping. So the assembly identity is joined with an
execution record that three sources must agree on (PLAN-004 P1.9a's contract is adopted): the
compiled module set, from a fresh empty `AILANG_CACHE_DIR` per assembly with `-debug-compile`'s
per-module `MISS` lines and summary (zero hits, no `SKIP`) equal to the cache's
`compile/manifest.json`; the selected file per module, re-derived by the runner from the loader's
rules (project ids against the assembled root, `std/` through the traced search paths or the
embedded copy covered by the binary hash, `pkg/` through the effective lock) and each hashed; and
the statement-level import closure from the checker, equal to the compiled set minus the injected
prelude. `pkg/` packages are pinned by the entry at A and copied into the assembly under an
**effective lock** that differs from A's only in the rewritten `path` fields (`ailang.lock:71–77`
points outside every assembled tree at `3920814`); a candidate diff touching `ailang.lock`,
`ailang.toml` or `packages/**` is `Refused(InadmissibleCandidate)`. A missing record or any
disagreement is `PreflightMismatch` at K0. The residual gap — the selected path is the runner's
re-derivation, cross-checked, not the loader's own report — is printed in every envelope, and a
loader flag that closes it is an AILANG feature request, not an assumption.

**The marker.** A **marker check** is run when P and C differ observably — an independently
chosen difference the run must exhibit — and is reported as *not applicable* when a candidate
preserves every observation. In that case the verdict rests on the **execution-provenance record**
under cooperative trust, and says so; the assembly identity alone is not the evidence that C's
code ran.

**The variant commit.** One reviewed, line-neutral core commit adds the sum, the two arms and the
constructor imports (D2; PLAN-004 P1.1's five joins at `3920814`, anchors `anchors.sh:593`,
`:614–617`, the bridge span `derive.py:154`); it lands before A and is inside A's protected basis by
construction.

**The control basis.** The regression control D8 requires must pass K1–K7 on the entry and fail
only the budget. The historical `a6abda4` cannot do so on A's pins: its `recording_ports` lacks the
`wake_read` binding (`a6abda4:src/core/test/stub_step.ail:554–575`, SHA-256 `e6df6f20…`, against
`stub_step.ail:635–658`, `495d3c8f…` — each the SHA-256 of the definition text from
`export func recording_ports(` through its closing brace and newline, the v4 review's `audit_v4.py`;
historical lines 554–575, current 635–658; a `sed` line-range hash differs), and a K0 refusal is
not a rejection by allocation. So the
**primary control is same-basis**: a candidate diff on A that reverts `de4b4f5` — "Build
`canonical_messages` with one concat instead of right-nested interpolation", `src/core/phase_vocab.ail`
only, an ancestor of `3920814` — run through the candidate runner like any candidate. Its
protected basis equals A's; its assembled source identity differs and is recorded. The
**historical basis** stays available as an option with its own obligations: a separately reviewed
control-basis manifest enumerating every protected, schema and dependency difference and the
permitted compatibility patch, its own protected pins derived from that basis, type-checked, and
equal entry observations with K1–K7 passing before any resource failure is credited. Neither
control's failure counts without matching observations (D8 P3).

**Identities per result:** source recording commit, admission commit A, parent P, candidate C,
evaluator E, the assembly identity, the execution-provenance record, `ailang` binary hash, the
effective lock's hash, and the entry's digests: snapshot, excerpt, selector, program
(`program_digest`, `dst_persistence.ail:591`), plus the program's own `ExecutionManifest`.

**Changing the evaluator changes the experiment's basis.** A change to E, to the seams'
projections, to the canonical or frame functions, to the reader's copies, to the journal schema,
to the program schema, to the protected closure or to the scan policy needs its own review and
re-admission of the corpus; old identities and results are retained. This is the RSI design doc's
rule that a successor earns acceptance against criteria it cannot rewrite during its own
evaluation.

### D6 — Corpus

**Location and handling.** `.motoko/eval-corpus/`, **not ignored at HEAD** (`git check-ignore
.motoko/eval-corpus/example` exits 1 at `3920814`; P0 adds the rule before any content is
copied). Directories `0700`, files `0600`. Everything derived goes under `<entry>/runs/` — the
replay's wire carries full `history_seeded`/`history_appended` payloads, and the runner redirects
it only there. Local-only by default; retention is a duration and a deletion rule that includes
every copy, fixed in PLAN-004 (its `QRET`), not here.

**An entry.**
- the snapshot and the excerpt (only the D1 event types), with their SHA-256;
- the `RunSelector`, the `JournalWorld` expectations, the T0 settings and the expected end;
- the **program artifact**, assembled from `encode_body` and `program_digest`
  (`dst_persistence.ail:544`, `:591`) as `"<schema>\ndigest\t<digest>\n<body>\n"`, loadable by
  `load_program` (`:1344`), which verifies the digest (`:1113`) and does not rescan;
- the witness, the `family_evidence` record and the census;
- the envelope; the identities (D5); the assembled settings and measurement scope;
- the **scan report** (below);
- an **exposure log**: every experiment, warm-up, held-out validation, candidate and agent that
  has seen the entry or its results.

**Scan policy.** `encode_artifact`'s gate (`:663`) refuses any program whose text holds a run
of 32+ credential-alphabet characters with an upper, a lower and a digit — six of r2.1's tool
outputs hold an absolute repository path that qualifies — and is not used. Its rules are not
precise either: `ProviderTokenLiteral` is `Str.contains` over 23 published prefixes with nothing
required behind them (`dst_secrets.ail:217–229`), and `scan_text` reports only the **first**
prefix that matches (`:225–229`, `:337–347`). The evaluator applies a **contextual policy**,
reviewed and versioned with E, over **every** component — snapshot, excerpt, program (identity,
projection, payload, chunks: `scan_interaction`, `:431–439`), environment (values through
`scan_text`, keys through `name_axis`, `:207`, `:353–359`), file table, metadata and derived
output:
- **refuse** on `PrivateKeyBlock`, `JsonWebToken`, `UrlUserinfo` (`:254`, `:261`, `:236`), and on
  `ProviderTokenLiteral` when **any occurrence of any of the 23 prefixes** — every occurrence is
  enumerated, not `scan_text`'s first — is followed by at least 16 characters of the credential
  alphabet (`in_credential_alphabet`, `:292–295`: letters, digits, `+/=_.-`);
- **report** every other finding per site with its reason, count and body length, in the entry's
  scan report, without copying a body and without calling it a credential:
  `OpaqueHighEntropy`, prefix hits with a shorter body, and **`CredentialBearingName`** on an
  environment key, which is **report-only by this policy's explicit rule**, so that an
  implementation neither inherits `encode_artifact`'s stronger name-axis refusal nor drops the
  finding.

**Body-16 is a reviewed heuristic, with its limits stated.** The prefix implementation carries no
minimum body length; `Basic ` and `Bearer ` are generic schemes, not issuer-fixed-length tokens; a
short body is report-only although it may carry a credential (false negatives: invented short
`Basic`/`Bearer`/`sk-`/`npm_` probes match the raw prefix and pass body-16), and a long body occurs
in quoted examples and ordinary prose (false positives). It is a threshold that lives in the
evaluator's copy, not in `dst_secrets`; changing it is a policy change and re-admits the corpus.
Prefix-specific or contextual rules beyond it are Not decided.

**r2.1 under this policy, at HEAD's alphabet** (review S4, `scan_v4.py`; counts and indices only):

| Component | Strings | Raw `ProviderTokenLiteral` | Raw `OpaqueHighEntropy` | `PrivateKeyBlock` / `JsonWebToken` / `UrlUserinfo` | Body-16 refusals |
|---|---:|---:|---:|---:|---:|
| Seed message contents | 694 | 16 | 44 | 0 / 0 / 0 | **4** — indices 1, 78, 86, 98, each with a maximum post-prefix run of 24 |
| Retained complete script contents | 299 | 0 | 0 | 0 / 0 / 0 | 0 |
| All source script contents (diagnostic) | 300 | 0 | 0 | 0 / 0 / 0 | 0 |
| Retained tool output contents | 299 | 4 (sites 0, 96, 195, 228; maximum body 6, report-only) | 10 | 0 / 0 / 0 | 0 |

**r2.1 is `Refused(ScanRefusal)` at its seed.** Those are findings, not evidence that the strings
are credentials, and the seed alone decides: no unbuilt program scan is needed to reach the result,
and the result is not relaxed to admit the large entry. The second session's first 57 turns are
scanned next (PLAN-004 `SCAN0`, a heuristic pre-scan under this rule that admits nothing); **no
entry is named admitted by this ADR** — the first is P3's, after every component passes this scan
and A1–A9. Redaction (`redact_interactions`, `:589`, which reports its trajectory cost) would
produce a program that no longer reproduces the run and is Not decided.

**Admission.** At commit A, against independent evidence: A1–A9 and A9b as `SourceFaithful`, the
scan policy passed. Re-admission after a change to the canonical form, the frame function, the
journal schema, the program schema, the seams, the protected closure, the reader's copies or the
scan policy is a basis change (D5).

**Held out.** An entry is `held-out` only if no agent producing candidates has inspected the
entry or its results. The two sessions used so far are `dev` and marked exposed: r2.1 of
`session_1789244855221-63164319c7d765ff`, and the first 57 turns of
`session_1789293423477-2e87f61dff66d42e`. Held-out pins and results are stored outside the
candidate's write scope; candidate-producing agents receive no held-out details. Reports give
per-entry outcomes, including refusals.

### D7 — Fidelity ladder, with cumulative omissions

| Tier | Adds to the tier below | Still omits (cumulative) | Depends on |
|---|---|---|---|
| **T0** | D1–D6 | streaming; conversation loop and cross-turn lifetime; extensions and compaction; model parameters, tool schemas and encoding; real tools and exit status; cache usage (served as zero; unreproduced on the wire); prior counts (served as zero; `cumulative` unreproduced); `MotokoRuntimeStatus` (cut); the context-limit resolution's source; live GC timing. Refuses continuation starts (suspended or wake-opened) and a failing hybrid predicate; cuts at retries, user messages, replacements, runtime-status calls, parks, call-free `tool_calls` finishes, blank stops and hybrid extractions; pins `MOTOKO_EXIT_MANIFEST` and `MOTOKO_CAPTURE_FAILED_PAYLOAD` empty | — |
| **T1** | synthetic *content* chunks at a stated granularity (`chunked_prose_step`, `stub_step.ail:817`, fixed usage and finish, so usage/reasoning/tool/error streams need their own adapters); prior counts for message-only starts through an exported wrapper mirroring `run_v2_session_traced` (`session.ail:4423–4442`) that normalises the provider, initialises policy and calls `run_v2_from_messages_traced_with_policy_and_counts` (`:4239`); continuation starts through `fold_journal` → `plan_resume` → `run_v2_session_resumed_traced` (`journal.ail:1679`, `:2250`; `session.ail:5394`), as `journal_resume_dst` does, wake-opened runs included; cache fields in `ScriptedStep`, the provider codec (`ports.ail:2507–2553`) and `scripted_to_step_result` under **`execution-program/5`**; possibly the call-free `tool_calls` finish as a class | everything T0 omits except continuation starts, prior counts and cache usage; real chunk boundaries and encoding. **Does not reach the production conversation loop** (PLAN-003 §0.6; ADR-002 D4) | — |
| **T2** | extensions | everything T1 omits except extensions; **needs observations neither the journal nor the host log records** — extension effects, pre-step and solver provider calls, extension file reads, opened waits — served fail-closed, with no empty effect queue falling through to a real subprocess. An investigation, not a promise | new recorded observations; the ADR-001 exemption; 028 PLAN-002 D4 |
| **T2b** | operator input as scripted input; the `UserMessage` cutoff no longer applies to operator entries | as T2 for everything else | ADR-002 D4 |
| **T3** | **a separate live experiment**, not a replay tier: live sampling (RSS against journal bytes) and live A/B, to assess transfer | determinism; the whole envelope | — |

**Compaction, scoped.** Retained history and a pre-step compacted payload differ (ADR-003
retraction 4). A message-changing compaction normally fails A3. A no-op compaction, or a change
invisible to the canonical projection, need not; the raw frame of K2 sees it against the
**parent's admission run** only — candidate–parent agreement, not live equality.
Source-compaction eligibility is recorded at admission, not inferred from A3.

**Streaming, scoped.** The evidence log holds 801 `thinking_delta` and 57 `reasoning_delta`
events against 693 provider calls; the host may coalesce deltas. No streaming cost share is
claimed.

### D8 — Gate and sequencing

1. **P0 — Preserve.** Archive the prototypes and the stored evidence with hashes, without
   running them. Add the corpus ignore rule. The prototypes may otherwise be deleted
   (HANDOFF-2026-09-13). A heuristic pre-scan of the dev candidates under D6's rule may run here;
   it admits nothing.
2. **P1 — Build.** In core, one reviewed, line-neutral commit: the `PortedWorld` variant, its
   two arms and constructor imports. At E: the D1 reader and refusals; the world builder with
   the T0 settings; the two guarded-delegation seams; the witness builder and the census; the
   manifest builder with gathered provenance; the protected checker; the admission verifier
   (A1–A9, A9b) and the candidate runner (K0–K7) over the harness's `world_state_of`,
   `reconstitution_balance`, `strict_replay_findings`, `check_discovery` and `evaluate`; the source
   transcript comparison; the entry wrapper and artifact assembly; the scan policy; the finding
   mapping. Type-check and unit-test on tiny synthetic journals under **the P1 test contract**
   (below). **Not built:** a second comparison walk, a second reconstitution, a second persistence
   codec, a second manifest type.
3. **P2 — Guard and calibrate.** The guard reads `/sys/fs/cgroup/memory.current` and
   `memory.max` (25,769,803,776 bytes, 24 GiB; `memory.current` sampled at 10.5 and later 9.93
   GiB), requires exclusive heavy execution, headroom (current plus calibrated peak plus margin
   below `max`, current well under 12 GiB per the handoff rule), monitors during the run,
   terminates on a conservative threshold, applies to warm-ups and profiling runs, and
   invalidates the result on any trip. Margin, polling and the treatment of an unlimited
   `memory.max` are PLAN-004's. Calibrate short segments (at most 100 recorded calls) with the
   final evaluator, both verdicts, with the seed fold inside the profiled process.
4. **P3 — The gate.** Admit the first `dev` entry the scan policy and A1–A9 accept. Pin in
   `make journal_replay_budget`: allocation and the exact observation counts (calls, appended
   messages, tool invocations, interactions by class, env reads by key, decisions). Fail closed on a
   loader error, a missing profile, a preflight or provenance mismatch, a divergence, a changed
   scope, or a guard trip. **Show it rejects a known regression by its budget while K1–K7 pass:**
   the **same-basis control** (D5) — A with `de4b4f5` reverted, reviewed as resource-only,
   `canonical_messages` byte-identical on the digest fixtures and the entry's seed, the protected
   check passing at C, K1–K7 passing on the entry — exceeds the allocation budget. A K0 or any
   other refusal is not the rejection; a control whose observations do not match is not a
   control. The historical `a6abda4` route is optional and needs D5's control-basis manifest
   first. The stored 58-call profiles (2.002150 against 1.572677 GiB) show the difference exists;
   they are terminal-augmented prototype runs and are **not** the gate's inputs. Pin the gate only
   after A1–A9, K0–K7 and the control rejection pass with the final evaluator on the finite-turn
   entry. The segment length is fixed here, by calibration. Repinning requires a recorded reason
   and happens outside the candidate's control.
5. **P4 — Held-out process.** Collect new sessions under the exposure rule.
6. **P5 — Long admission.** Entries of the 300-call class are admitted only under the guard with
   exclusive execution, never inside a sweep.
7. **P6 — T1.**

**The P1 test contract.** v4's sentence — "one known-divergent and one known-refused case per
refusal family" — conflated two vocabularies: a *refusal family* names a reason the source or the
candidate is unusable, and *divergent* is a verdict about a replay that ran. A refusal family has
no divergent counterpart by construction. The sentence is **revised**:

- per **refusal family** (D1's refusals; D3's `Refused` reasons): one known-refused case at a
  pinned location, and one **clean twin** that passes that family's check;
- per **cutoff**: one case asserting the resulting selector, N and expected end, genuine or
  synthetic;
- per **admission check** A1–A9, A9b and per **candidate check** K1–K7: one known-failing case
  whose first finding and location are pinned, and its clean twin; per `ReplayMismatch` variant,
  one;
- per **seam fail-closed arm**: one, asserting the complete record, the returned value and the
  absence of any live effect;
- one witness under-count and one over-count; one candidate whose prepared count and recorded
  count differ;
- per **census row**: the T0 fixture asserting zero by name, and a non-zero twin;
- one vacuous family (`CheckpointHistory` on a checkpoint-free trace) reported through
  `family_evidence` unchanged and the census beside it.

**Ruling on PLAN-004's M15.** Its near-miss rows — an input that passes its own family's refusal
and every earlier check and is caught by a later check at a pinned location, `Refused(AdmissionCheck(Ak))`
at admission or `Diverged` for a candidate — **satisfy the revised contract's per-check
requirement** and are kept: each is the known-failing case for the check that catches it, and each
proves a check-ordering assumption (that the family's refusal is not what stops the input). They
are **not required per refusal family**, so every row M15 marks inapplicable — `UnknownEntryType`,
`UnknownSchema`, `ContinuationStart`, `EmptySegment`, `ProgramUndecodable`, `PreflightMismatch`,
`GuardTripped`, the scan refusal as a divergence, and `EvaluatorTouched` where no fixture can name
an edit — is **satisfied by its recorded reason** in `MATRIX.expected.tsv`, not a gap. Two rows are
settled by this revision: the park/wake row is inapplicable because `Parked` is a cutoff (its M3
case asserts the selector) and a wake-opened start is `ContinuationStart`; the
`ProtectedRegionTouched` row is retained as the closure's regression test — an edit outside every
protected span that changes a recorder's input is reported as a missing member (D5) — and if the
v5 closure leaves no such edit to find, that is the row's success, recorded as inapplicable with
the search stated. `DuplicateOrAmbiguousCallId`'s conditional row stands as written: the test first
asserts what ordered association does with swapped results.

Separately owned and not licensed by this ADR: the pending P2D sweep, P3ORD, and the
operator-owned canaries.

## Consequences

**What gets possible.** Resource and structural changes to the traced loop are measured on real
workloads, and every candidate run is a strict replay the harness already knows how to load,
validate, replay and report. The verdict names its envelope in the harness's own vocabulary.

**What gets load-bearing.**
- The ADR-003 journal schema, the canonical message form and frame function, the host log's
  `thinking`, `provider_call_prepared`, `context_limit_resolved` and `session_start` fields, the
  program schema, the outcome codecs, the protected closure, the reader's copies and the T0
  settings: changing any of them costs a re-admission.
- The excerpt is captured at admission, so indefinite retention of the whole host log is not
  required.

**What changes in code.**
- One `StepProvider` variant, two match arms and the constructor imports, line-neutral
  (`stub_step.ail`, `session.ail`, `ledger_parity_dst.ail`); a compatibility patch of the same
  only if the historical control basis is ever taken.
- The evaluator modules, runner, guard and protected checker at E, outside `src/core`.
- `Ports`, the journal format and writer, the fold, strict replay, the recorder's projections,
  the program schema, `dst_secrets`, the frame gates and `derive.py` are untouched. Anchors are
  untouched because the commit is line-neutral; if that fails, the re-baseline is priced in D5.

**Costs.**
- Local disk: a program per entry carries every tool output at real size beside the snapshot.
- Exclusive heavy execution for long entries: the terminal-augmented prototype's 300-request run
  peaked at 6,969–7,058 MiB RSS with `de4b4f5`; the finite-turn entry's peak is P2's to measure.
- A pinned second worktree, and a fresh compile cache per assembly.
- Privacy handling for real conversation content, now also inside program artifacts, with a
  scan report per entry.
- Two seams that delegate to a protected closure and must follow it; a closure that must be
  reviewed, not merely hashed.

## Not decided

- **Carrying the seed in the program** (`execution-program/5` with a `[Message]` field), which
  would make the program alone a reproduction unit.
- **Widening the core recorder's projections** with the payload digest and tool arguments, which
  would retire the seams' replaced projections at the cost of re-baselining every recorded
  program.
- **Cache fields in `ScriptedStep` and the outcome codec** (`/5`; T1).
- **Exporting the counts-carrying traced wrapper** (T1).
- **The call-free `tool_calls` finish as an admitted class** (D1 shape 3), and whether a blank
  stop should ever be admitted.
- **A phase boundary for recursion depth** that excludes the evaluator's own folds by
  measurement.
- **The `ProviderTokenLiteral` sharpening** (16 characters) as a change to `dst_secrets` itself;
  prefix-specific or contextual rules beyond it.
- **A no-excerpt admission mode** with inferred finish reasons and journal-only usage.
- **Redaction and export.** Redacted entries would need fresh identities and fresh admission.
- **Moving request digests into the journal.** A change to ADR-003 D2's event set.
- **The recorded observations T2 needs** for extensions, opened waits and compaction.
- **T1's chunk granularity source.**
- **A tool-result seam on the live path** (O3).
- **The isolation strength for the evaluator**: same-user worktree, separate user, or container.
- **The historical control basis** (`a6abda4` with its own manifest), if the same-basis control
  ever proves insufficient.
- **A loader flag printing module id → selected file**, which would close the execution-provenance
  gap (an AILANG feature request).
- **Retention duration** (PLAN-004 `QRET`).

## Implementation handoff

PLAN-004 v1.2 exists, grounded at `3920814`, with every ⟨v5⟩ marker awaiting this revision; its
`PSYNC` re-grounds it on v5 as PLAN-004 v2. Every marker has an answer above; the deltas PSYNC
carries: M1's park/wake row moves to M3 as the `Parked` cutoff, plus a `MalformedEntry` case for
a stray wake and a `ContinuationStart` case for a wake-opened start; M4 gains `HybridExtraction`
and `HybridPredicate`; M5 pins the explicit profile directory and both empty keys; M11 asserts the
derived decision count; M14's exhausted-marker case asserts its actual first finding; M15 is ruled
in D8; P3.2's same-basis route is primary and the historical route optional. P0 and P2's guard
come first because the prototypes can be deleted and memory is contended. P1 is written against
the harness's existing entry points and the prototypes' evidence, not their code. The variant
commit is one reviewed, line-neutral core commit that changes no running adapter and moves no
anchor; everything else lands at E.

## Cross-references

- `REVIEW-adr004-v4-verdicts-codex.md`: the v4 review; its per-decision verdicts (§2), mechanism
  checks (§3.1–3.11), claim audit (§4) and nine required changes are folded here.
  `REVIEW-adr004-v3-verdicts-codex.md`, `REVIEW-adr004-v2-verdicts-codex.md`,
  `REVIEW-adr004-v2-verdicts-fable.md`, `REVIEW-adr004-verdicts-codex.md`: the earlier rounds.
  `BRIEF-adr004-v3-review.md`, `BRIEF-adr004-v4-review.md`: the briefs.
- `PLAN-004-implement-adr-004.md` v1.2 (§0.5 evaluator paths, §0.9 drift table, §3 M1–M15,
  P1.4b, P1.6, P1.9a, P3.2, §5 the ⟨v5⟩ markers).
- ADR-003: O2, O4, D1, D2 (the typed suspension), D4 (the fold, `JournalFold`), D7 (park and
  wake, PLAN-003 P4), retraction 4, Consequences, Not decided.
- ADR-001 D2 (frames; the `ExtPorts` forwarding exemption). ADR-002 D2, D4. PLAN-003 §0.6,
  `:772–775` (the large seed).
- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md` (acceptance against criteria
  a successor cannot rewrite; withheld evaluation; a recorded response sequence may cease to be
  valid when a candidate changes the request).
- HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md (the 12 GiB `memory.current` rule; `de4b4f5`).
- Commits: `de4b4f5` (the `canonical_messages` fix, `src/core/phase_vocab.ail` only; the
  same-basis control reverts it), `a6abda4` (the historical control), `686da16` (the `park` and
  `wake` entries), `d5edebf` (v4's pin), `3920814` (this pin).
- Prototypes and evidence (untracked, worktree `../motoko_agent-mem`):
  `scripts/dst/mem_journal_replay.ail` (`:96–97`, `:106`, `:140–157`, the result match `:152–154`),
  `mem_growth_probe.ail`, `mem_canonical_bench.ail`; `.motoko/memfix/` (`runs/results.tsv`,
  `runs-new/`, outputs, profiles, gate logs). The v3 and v4 reviews' evidence scripts and outputs
  (`evidence.py`, `source_check.py`, `scan_v4.py`, `audit_v4.py`, their `.txt`) in their scratchpad
  directories, quoted in their §4.
- Live A/B: `.motoko/ab/muse-replay-20260907T185514Z/`.
- Code at `3920814`, read for v5:
  - `session.ail`: `:195`, `:272–293`, `:707`, `:757–763`, `:790`, `:988–1016`, `:1050–1057`,
    `:1532–1547`, `:1727`, `:2126–2140`, `:2241–2254`, `:2287–2298`, `:2350–2388`, `:2376`, `:2664`,
    `:2760`, `:2778–2794`, `:3255–3308`, `:3330–3335`, `:3339`, `:3351–3352`, `:3354–3409`,
    `:3378–3397`, `:3398`, `:3527–3563`, `:3677–3681`, `:3824`, `:3878`, `:4020–4066`, `:4135–4155`,
    `:4239`, `:4271`, `:4423–4442`, `:4445`, `:4612`, `:5041`, `:5066`, `:5338`, `:5394`,
    `:5414–5424`, `:5531–5536`, `:5577`; `TracedSessionResult` (`result`, `trace`, `world`,
    `emissions`, `suspended`, `final`);
  - `step_machine.ail:102–159`; `recovery.ail:59`; `tool_phase.ail:277–296`, `:438–449`,
    `:452–464`, `:484–501`, `:499–506`, `:558–566`, `:608–615`; `journal.ail:208`, `:1179–1180`,
    `:1211`, `:1229`, `:1253–1256`, `:1311–1316`, `:1595–1614`, `:1679`, `:2250`, `:2295–2296`;
  - `ports.ail`: `:12–14`, `:60–67`, `:586–615`, `:616–621`, `:647–651`, `:886`, `:1024`, `:1086`,
    `:1178`, `:1201`, `:1305–1320`, `:1335–1364`, `:1723–1749`, `:1775–1787`, `:1827–1843`,
    `:1851–1895`, `:2020`, `:2056–2068`, `:2133–2172`, `:2217`, `:2507–2553`, `:2577`, `:2608`,
    `:2855–2885`;
  - `test/stub_step.ail`: `:28–33`, `:44`, `:69`, `:72–90`, `:95`, `:121–134`, `:136`, `:203`,
    `:335–351`, `:352`, `:478–542`, `:554`, `:561`, `:635–658`, `:791`, `:817`;
    `test/scripted_ports.ail:30–35`;
  - `src/core/ext/exit_manifest.ail:86`, `:202–223`; `src/core/ext/runtime.ail:402–406`,
    `:426–435`, `:477–493`, `:683–716`, `:721–727` *(review; file unchanged since `d5edebf`)*;
  - `context_usage.ail:139–150`, `:168–175`, `:178–195`, `:241–250`; `context_limit.ail:129–132`,
    `:145`;
  - `dst_program.ail`: `:119–152`, `:132`, `:182–188`, `:243–252`, `:357–369`, `:589–596`, `:648–653`;
  - `dst_replay.ail`: `:358–367`, `:374–388`, `:395–397`, `:438`, `:580`, `:681–703`, `:745`, `:761`,
    `:792`, `:831–874`; `dst_interaction.ail:297–302`;
  - `dst_discovery.ail`: `:224–237`, `:260–310`, `:407–417`, `:473–519`, `:529–545`;
    `dst_execution.ail:46`, `:100–126`; `dst_invariants.ail`: `:228–247`, `:599–610`, `:1570–1579`,
    `:1631–1640`, `:1753–1782`, `:1991–1997`, `:2010–2024`, `:2043–2067`;
  - `dst_profile.ail`: `:1535–1573`, `:1582–1588`; `dst_driver_only.ail:1065`, `:1097–1123`;
    `dst_fault_catalogue.ail:61–63`, `:82–85`; `dst_persistence.ail`: `:544`, `:591`, `:615`, `:663`,
    `:1095`, `:1113`, `:1344`; `dst_secrets.ail`: `:207`, `:217–229`, `:236`, `:254`, `:261`,
    `:287`, `:292–299`, `:337–347`, `:353–359`, `:431–439`, `:589`;
  - `scripts/dst/strict_replay_dst.ail`: `:226`, `:257`, `:298–302`, `:310–315`, `:366–378`,
    `:631–633`, `:636`, `:651`, `:708`, `:737–781`, `:792–795`;
    `scripts/dst/ledger_parity_dst.ail:73`, `:428–435`;
  - `tools/predicate-anchors/anchors.sh:593`, `:614–617`; `tools/predicate-anchors/check.py:62–73`;
    `tools/driver_leaf_inventory/derive.py:63–86`, `:154`, `:320–329`; `ailang.lock:71–77`.
- Code as cited by the reviews and not re-read for v5: `session.ail:3409–3441`, `:3862–3921`;
  `phase_vocab.ail:275–300`, `:321–358`, `:1362–1374`; `model_phase.ail:17–25`;
  `tool_dispatch_adapter.ail:46–56`; `dst_persistence.ail:211–239`; the historical
  `a6abda4:src/core/test/stub_step.ail:554–575`.
