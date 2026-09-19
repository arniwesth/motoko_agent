# Review: ADR-001 Extension-owned structured decisions (v0.1)

Reviewer: Claude Fable 5.1, independent read-only review against working tree at HEAD `2062605`, ABI `7.4`.

## 1. Overall verdict

**Architectural direction: sound, and correctly grounded.** Every row of the ADR's "Current surfaces" table checks out against source. `SolverJudge` is `! {Process}` and that row admits no `ExtPorts` field at all, so the ADR is right that a judge cannot reach the model port today. The finalize merge order, the five-stage candidate classification, the ephemeral compaction model, and the `execution-program/4` writer are all as the ADR describes. Placing question ownership in the extension follows the 005 boundary ADR without stretching it. Preferring a declared prepare/interpret capability over a callable port is the right default, and the source gives a stronger reason for that preference than the ADR states. I give that reason in section 4.

**Freeze readiness: not ready, and the draft does not claim to be.** Q1 to Q7 are honestly scoped. Beyond them I found six items that are freeze-relevant and are not in the Q list. Two are hidden structural consequences of the declared design, two are missing requirements, and two are latent contradictions inside D2 and D6. None invalidates the direction. All are decidable in one revision.

The most important new item is where the host executes the query. The fold that knows which extension is running cannot reach core `Ports`, and the module that holds `Ports` cannot see inside the fold. How that is resolved decides whether `ExtPorts` gains a field, which is an ABI question.

## 2. Findings

Findings are ordered by severity. Each states the practical consequence and the decision needed. New findings are marked N. Items that sharpen an acknowledged Q are marked with the Q they refine.

### Freeze-blocking, not in Q1 to Q7

**N1. The execution site of the query is undecided, and it decides the ABI surface.**
The finalize fold lives in `src/core/ext/runtime.ail:666-728` and receives `ExtRuntime` and `ExtCtx` only. `ExtCtx.ports` is the bridged `ExtPorts` record, not core `Ports`. Core `Ports` lives in `C2LoopState.provider` and is visible in `session.ail`, which calls `dispatch_solver_candidate` from `classify_candidate` at `src/core/session.ail:3278`. The ADR's D4 sequence says "Host validates, resolves binding, checks limits, executes and records" without naming the module. Three resolutions exist and they are not equivalent:

- Bridge the call through a new `ExtPorts` field and let the fold call `ctx.ports.decision_query`. This puts the field on the ABI record, which is the callable-port alternative by another name, and it costs the 17 `ExtPorts` literals in 15 files.
- Pass `Ports` into the dispatcher. No import cycle: `ext/runtime` already reaches `ports` through `ext_world` at `runtime.ail:34-36`. But the leaf inventory that pins helped requests scans only `session.ail`, `tool_phase.ail`, `context_usage.ail` and `stub_step.ail` per 013 ADR-001 D2 part 6, and `witness` is private to `session.ail`. A helped leaf inside `ext/runtime.ail` is invisible to the no-bypass gate.
- Two-phase dispatch. The fold collects `Immediate` or `Query` per atom in list order with typed atom identity, `session.ail` executes each query through `Ports.decision_query` with `advance` and `witness`, and a second fold interprets and merges.

Decision needed: choose the third. It keeps `ExtPorts` unchanged, keeps the leaf in a scanned file, and keeps the successor thread visible to `witness`. State it in D4, because the current single-fold description at `runtime.ail:666-681` cannot host a port call the way the ADR draws it.

**N2. The new kind's vote status and multiplicity are undecided.**
`registry_normalize.ail:168-174` names exactly `ToolPolicy` and `SolverJudge` as vote kinds, and `:231` rejects a second vote atom per extension. `DecisionSolverJudge` produces a `FinalizeDecision` that enters the same `merge_finalize_decisions` at `runtime.ail:710-719`. 017 ADR-001 Q2 forbids "one extension disagreeing with itself". Nothing in the ADR says whether one extension may register both `SolverJudge` and `DecisionSolverJudge`, or where a `DecisionSolverJudge` atom sits relative to `SolverJudge` atoms within the same entry's list.

Decision needed: `DecisionSolverJudge` is a vote kind. At most one finalize-vote atom per extension across both kinds. Both kinds are collected by one fold in list order. Add it to `is_vote_kind`, `kind_name`, and `capability_kind` at `runtime.ail:1139-1151`.

**N3. Verification status is not visible to a guard, and typed evidence does not exist on `ExtCtx`.**
Stage 2 runs DP7 before the solver for non-blank candidates at `session.ail:3269-3278`. But `run_dp7_verifier` at `session.ail:2241-2254` returns `Approve` when verification is disabled, when `exec` fails, and when output matches the missing-infrastructure pattern. A guard at stage 4 cannot tell "verified and passed" from "verification off" from "failed open". Those are the cases a `claims_unrun_work` question exists to catch. Tool exit codes reach the guard only as JSON text inside tool-role `Msg.content`, rendered by `tool_outcome_text` at `session.ail:1158-1165`. The ADR's instruction that "command exit status should come from recorded observations" has no typed source to come from. `ExtCtx` at `packages/motoko-ext-abi/types.ail:536-619` carries no file-change set.

Decision needed under Q3: add a typed `verification` field with at least three arms, and decide whether typed tool outcomes cross the ABI. Both are `ExtCtx` additions, and `ExtCtx` literals are source-breaking. Count below.

**N4. Configuration captured at registration is invisible to the host, so D6's mismatch rule is unenforceable as written.**
D2 allows registration to capture immutable configuration. D6 says changed "relevant policy configuration is a mismatch, not a cache hit". The digest at `runtime.ail:1108-1112` records why this cannot work: capability payloads are closures and nothing can hash them. A guard whose threshold changed through env config produces the same `Capability` kind, the same `local_id`, and unless the extension chooses otherwise, the same request.

Decision needed: require `prepare` to fold every decision-relevant configuration value into the canonical request, or into a version string the host includes in the identity. The host then hashes only what it can see. D6 should say the host cannot detect captured configuration on its own.

**N5. `policy_version` in the identity contradicts the threshold-experiment clause.**
D6 places `policy_version` among the recorded fields and says strict replay matches only "the matching recorded request". It then says reusing observations to compare interpretation thresholds is "a separate controlled experiment". If `policy_version` is part of the request-matching identity, a threshold change is a mismatch and the experiment cannot run against the recording at all. If it is not, strict replay of a changed policy proceeds silently. `identity_body_eq` at `src/core/dst_interaction.ail:181-206` is component-exact, and `compare_at` at `src/core/dst_replay.ail:357-362` also compares `request_projection`, so whatever enters the identity or projection is matched exactly.

Decision needed: split the version. A question-set version that changes when questions or evidence selection change belongs in the identity. An interpretation version belongs in recorded metadata only. The existing regression mode at `dst_replay.ail:209-217` is the precedent for a mode that demotes some mismatches.

**N6. Output-replacing `Accept` can be removed rather than reconciled.** Refines Q5.
`classify_candidate` treats `Accept(output)` as the finalized text with source `ext_solver_accept` at `session.ail:3281`, and stage 5 at `:3300-3301` does not re-verify a non-blank candidate, so a replacing `Accept` finalizes text DP7 never saw. No in-tree judge replaces. `repetition_guard.ail:309` returns `Accept(candidate)` and the test dummy does the same. `FinalizeDecision` is an imported sum, so narrowing `Accept` to a nullary constructor is a major-version change, which is exactly the release being cut.

Recommendation: at 8.0, make `Accept` mean "accept the candidate as-is", either by dropping the payload or by having the host reject an `Accept` whose payload differs from the candidate. This turns Q5 from an ordering and revalidation design into a deletion with zero consumers.

### Settle before the implementation plan, not before the ABI freeze

**N7. Extension-initiated spend has no accounting path today.**
`ext_ai_step` at `session.ail:1094-1110` discards `StepResult` usage and returns only message content. `c2_add_step_totals` at `:1551-1555` is fed only by the driver's own result at `:3931`. So `max_cost_millicents` and `CostWarning` never see extension-initiated model calls; the AI compactor's summaries are unaccounted today. D5's "counts toward the session's total spend" is a new path, not a hook into an existing one. `classify_candidate` returns a `CandidateClass` carrying a world but no totals, and both post-classification state builders take `totals` from the caller. Usage must be returned up through the fold and the classifier. `RuntimeLoopTotals` fields are plain ints at `session.ail:450-454`, so "unknown remains unknown" needs a representation. If usage is exposed in `DecisionObservation`, that representation is ABI and belongs in Q4.

**N8. D5's durable-allowance concern is aimed at the wrong gap.**
The finalize context's history is `st.msgs ++ [assistant_msg]` at `session.ail:3934`. Compaction is ephemeral; `compacted_msgs` at `:3802-3824` feeds only the model call. So marker counting on `ctx.history_slice` in `empty_stop_guard.ail:48-66` and `progress_contract_guard.ail:24-32` already sees the full loop history. The real gap is different: pure callbacks have no write channel. The only extension-writable durable state today is `ext_artifacts`, written solely by `Compacted(msgs, note, artifacts)` at `runtime.ail:343-347` and journaled through the state-delta fold at `src/core/journal.ail:941-942` and `:1536`. `FinalizeOutcome` at `types.ail:748` carries no artifact field. Under the declared design the allowance is either transcript markers as today, or a host-counted per-atom intervention count that the host journals. Recommend the second; the host already stamps ownership and occurrence, and a host counter cannot be reset by an extension.

**N9. Cancellation should be defined against the runtime's synchronous model.**
Port calls are synchronous inside the AILANG process. Operator `abort` and `exit` are read only at `readLine` sites between turns at `session.ail:4809-4815` and during a park under 013 ADR-002 D2. There is no in-flight cancellation of a `model_step`, so "a late provider response injecting feedback into a later candidate" cannot happen in-process. It can only arise at the host if the host retries or caches. Q6 should therefore define two outcomes only: an adapter-enforced deadline yielding `Unavailable(timeout)`, and process death, after which the request is absent from the journal and a resume re-issues it as a new occurrence with a new request id. No partial request is ever replayed.

**N10. Every-atom-runs versus skip-once-feedback-exists is a real choice with replay consequences.**
`dispatch_solver_candidate` at `runtime.ail:721-728` runs every atom whatever decision wins. Under that rule a paid query is issued even when an earlier deterministic guard already produced the winning feedback. Skipping the query once feedback is collected saves cost but makes the query occurrence depend on other extensions' votes and on registry order, which changes recorded identities when order changes. Recommend every-atom-runs in v1, with the decision guard ordered after deterministic guards and cost bounded by D5 limits. State it.

**N11. Migration consequences the Q7 inventory should name.**
`ext_set_digest` at `runtime.ail:1113-1151` hashes capability kinds per entry, and 013 ADR-003 D5 refuses resume on a digest change under the same profile. Migrating an existing guard from `SolverJudge` to `DecisionSolverJudge` therefore refuses every pre-upgrade journal without `--resume-force`. A new `IdentityBody` constructor needs `execution-program/5`; the wake class forced `/4` by the same rule at `src/core/dst_program.ail:119-132`, and `dst_persistence.body_of` at `:958-981` refuses unknown kinds. The world-token decoder at `src/core/ext_world.ail:405-429` falls through to `ClockAdvanceIdentity` on an unknown tag, and `dst_interaction.ail:117-124` already records that this is not loud. The ADR should either accept that documented behaviour or require a tag check.

**N12. Observation-only mode and `Immediate(NoDecision)` need host-side vocabulary.**
Acceptance item 6 wants the proposed vote recorded without being applied. `Immediate(NoDecision)` performs no exchange, so nothing distinguishes "guard declined to query" from "guard not installed". Both need a new ledger event, which is an event-vocabulary version bump. Decision faults need catalogue rows, because `validate_static_references` rejects unknown class ids as `ports.ail:82-87` explains.

**N13. External claims are unverified here.** The OpenRouter route, the decisions endpoint, and the optional probability fields are cited from web sources I cannot reach. Treat them as the ADR's claims, not confirmed facts.

### Construction-site counts for the D7 inventory

| Surface touched | Sites | Files |
|---|---|---|
| `ExtCtx` literals, source-breaking on any field addition | 37 | 28 |
| `ExtPorts` literals, only if a callable port is chosen | 17 | 15 |
| Core `Ports` literals, for a new field | 8 | 3 |
| Full `WorldState` literals, for a new cursor | 3 | 2 |
| `IdentityBody` consumers, listed at `dst_interaction.ail:80-84` | 9 | 9 |

Also: `tools/driver_leaf_inventory/derive.py:185` freezes `RequestClass` at six; `tools/ext_ambient_inventory/hook_scope.py:108` has a per-kind arity table; `tools/profile_definition/check_fixtures.py:324` lists kind ids; `src/core/dst_profile_coverage.ail:160-265` has the `CapabilityKind` sum, id maps, and the `Unconditional` classification; the three profile modules carry atom lists at `dst_driver_plus_no_ops.ail:491` and `dst_driver_plus_compose.ail:485`; `src/core/test/ext_fixture.ail:195` and the conformance `reject_fixtures.ail:127` construct judges.

## 3. D1 to D7 assessment

| Decision | Verdict | Note |
|---|---|---|
| D1 Extension owns policy | Accept | Matches 005 ADR-001. Backend binding as operator config is right. |
| D2 Declared prepare/interpret | Accept with N1 | Pure rowless payloads are compiler-checked on the imported sum per 017 ADR-001 Q3 correction. `ExtCtx.ports` is present but any port call fails the empty row, which is the enforcement wanted. The execution site must be fixed. |
| D3 Explicit questions, answers, unavailability | Accept, Q4 open | Keep control outcomes out of `Unavailable`. Add the unknown-usage representation. |
| D4 Ordering and finalization boundary | Accept with N1, N10 | The sequence diagram must name the two-phase dispatch. |
| D5 Bounded resources and interventions | Accept with N7, N8 | Reframe the allowance gap as "purity removes the write channel". Accounting is a new path. |
| D6 First-class recorded observation | Accept with N4, N5 | Split the version. Say what the host can and cannot hash. |
| D7 Land in the major | Accept with N11 | Add the counts above and the journal-resume consequence. |

## 4. Recommendations for Q1 to Q7

**Q1. Prefer the declared capability, and for a reason the ADR does not state.**
The coverage classifier at `dst_profile_coverage.ail:223` treats `SolverJudge` as unconditional, and the ABI's long note at `types.ail:907-934` records why `on_solver_candidate` is a barrier: a declared row cannot say "effectful only through a mediated port". A callable `ExtPorts.decision_query` would widen the judge's row and deepen that barrier. A pure prepare/interpret atom has no row and is coverable under criterion 1 with zero barriers, while the host owns the only leaf. That is a measurable coverage gain, not a taste. The callable port keeps its stated advantage for adaptive multi-call workflows, which D4 defers anyway. Choose declared. Keep the callable port as a post-freeze addition only if a consumer proves the need.

**Q2. Finalize now, and sketch the tool-policy-shaped twin at the type level in the same major.**
The no-progress consumer must see tool-bearing steps; `repetition_guard.ail:17-26` records that `SolverJudge` never fires on them. `ToolPolicy` is rowless at `types.ail:1243`, so a callable port there would widen a pure slot. The declared shape generalises: a `DecisionToolPolicy` with the same prepare/interpret pair and `ToolPolicyDecision` as its vote. Make `DecisionRequest`, `DecisionObservation`, and the answer types independent of `FinalizeDecision` so only the two callback signatures are site-specific. If the second variant cannot land at 8.0, at least freeze the shared types so adding it later is one variant and not a second vocabulary.

**Q3. Inventory is done above; decide the additions now.**
`ExtCtx` today carries task, step, model, cwd, hybrid_tools, budget, mode, workdir, env_server_url, budget_remaining, history_slice with tool calls and text results, state_key, context_limit, finish_reason, work_in_flight, open_waits as Json, ports, artifacts, telemetry, and world. Add a typed verification status per N3 and a host-counted intervention count per N8. Decide on typed tool outcomes. Every addition breaks the 37 literals, so batch them into 8.0.

**Q4. Types.**
Use basis-point ints for probabilities and scores; the project's persisted codecs flatten options to sentinels, and ints avoid a tolerance rule. Use `Option` in ABI-only types where absence is meaningful, and sentinels only in persisted payloads, following the `exit_code` precedent at `ports.ail:566-586`. `DecisionObservation` is a two-arm sum, answered or unavailable, with `UnavailableReason` a closed sum that excludes cancellation and replay mismatch. Include usage with an explicit unknown arm.

**Q5. Remove output replacement.** See N6.

**Q6. Lifecycle.**
Deadline owned by the host adapter. Reservation before the call against the configured allowance, reconciled after; unknown usage reserves the configured maximum. Interrupted request per N9. Intervention persistence per N8.

**Q7. Compatibility.**
ABI 8.0 for the variants and types. `execution-program/5` for the identity class, with the v4 fixture bytes untouched. Event vocabulary bump for the new events. Journal schema unchanged if the intervention count rides in the existing state delta. State the `ext_set_digest` resume refusal.

## 5. Before the freeze versus after

**Must be settled before the ABI freezes:** Q1; Q2 at least to the shared-type level; the public request, answer, observation, and unavailable-reason types including unknown usage; `Accept` semantics; the `ExtCtx` additions; the vote-kind and multiplicity rule; the version split between identity and metadata; and the execution-site decision insofar as it keeps `ExtPorts` unchanged.

**Can remain after the freeze:** the adapter's transport and where it lives, since core `Ports` is not ABI; the backend binding configuration format; limit values; catalogue rows; event vocabulary; the program schema bump, which is versioned separately; observation-only mode; the first guard's questions and templates; the evaluation method. One caveat: if Q1 were to flip to the callable port, the transport decision becomes freeze-relevant because the `ExtPorts` row depends on it. Today only `src/core/backend.ail:22` performs `Net` in core, and provider auth lives in the host, so an AILANG-side HTTP adapter would be a new posture.

## 6. Method and limitations

I read the ADR, both research notes, the four cited ADRs, the ABI package, `ext/runtime.ail`, `registry_normalize.ail`, `ext_world.ail`, `dst_interaction.ail`, `world_ordinal.ail`, the relevant regions of `ports.ail`, `session.ail`, `dst_program.ail`, `dst_replay.ail`, `stub_step.ail`, and the three guard extensions. Counts come from grep over `.ail` files. No tests, builds, or live inference were run. No external URL was fetched, so vendor claims are unverified. Line numbers are from the working tree at review time and will drift.

Untested assumptions: that a rowless closure in constructor position rejects a call through `ctx.ports` at the payload row, which follows from the B8 measurement recorded in 017 ADR-001 but which I did not re-probe; that `st.msgs` is never replaced by a compacted list on any path I did not read; and that the TS host performs no retry or caching around provider calls, which I did not inspect.

## Review provenance recorded by the delegating agent

- Requested model alias: `fable`.
- Resolved model reported by Claude Code: `claude-fable-5-1`.
- CLI: `2.1.276 (Claude Code)`.
- Reviewed working-tree ADR: [ADR-001-extension-owned-structured-decisions.md](ADR-001-extension-owned-structured-decisions.md).
- Git HEAD at delegation: `20626054e8015ebd8623459789d8de8bb6c260d2`; the ADR was an untracked working-tree file.
- Reviewed ADR SHA-256: `b48a7b1a2c93004c735b841a5d80defc472c7880b079f7e4355b76ee273f1e97`; unchanged when the review completed.
- Reviewer tools were restricted to `Read`, `Glob`, and `Grep`. The review body above is Claude's returned text, preserved without substantive edits.
- The delegating agent saved this review; the ADR and implementation were not edited as part of the review.
