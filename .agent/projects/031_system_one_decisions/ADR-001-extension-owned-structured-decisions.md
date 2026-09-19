# ADR-001: Extensions own structured decision questions; the host executes and records them

Date: 2026-09-18
Status: **Proposed, v0.2 — revised after the first Claude Fable review; not frozen.**
Grounded at: HEAD `2062605`, current working-tree source; extension ABI `7.4`.
Implementation status: Documentation only. None of the proposed ABI, runtime, or format changes is implemented.

## Context and established direction

Motoko needs to settle its extension interface before the upcoming major release. A completion
guard's evidence selection, questions, thresholds, abstention, and feedback constitute one
policy. The extension must own that policy; core should execute and record its requests.
The owner has explicitly asked to make the ABI changes now, before the release freezes it.

This applies the [harness-policy boundary](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md)
to model-assisted judgments. The established direction is extension ownership. The concrete
decisions below are proposed for acceptance, with implementation evidence still required.
This revision resolves the design questions in v0.1 rather than leaving them as alternatives.
See the [first review](REVIEW-adr001-v0.1-verdicts-fable.md) and the response table below.

## Current behavior and external evidence

| Surface | Current behavior relevant to this proposal |
|---|---|
| [Capability ABI](../../../packages/motoko-ext-abi/types.ail) | `SolverJudge` has effect row `{Process}`; `ToolPolicy` is pure. Neither can call the current AI port. |
| Same ABI | `ExtCtx` has transcript, waits, work declarations, artifacts, and ports, but lacks typed verification and tool-outcome evidence. `Accept(string)` can replace a candidate. |
| [Extension runtime](../../../src/core/ext/runtime.ail) | Every finalize atom runs in registry/atom order, threading the world. Feedback wins over acceptance, then no opinion. The fold has `ExtPorts`, not core `Ports`. |
| [Registry normalization](../../../src/core/ext/registry_normalize.ail) | Repeated votes are rejected by capability kind. This does not yet reject a legacy and a new variant in the same vote family. |
| [Session](../../../src/core/session.ail) | Nonblank candidates encounter DP7, open-wait handling, and then solver judges. Blank approvals have a later DP7 check. DP7's `Approve` also covers disabled verification and some infrastructure failures. |
| Same session code | Finalize receives `st.msgs ++ [assistant_msg]`. Compaction changes the model payload, not that stored history. Existing marker-count guards are not reset by ordinary compaction. |
| Same session code | `ext_ai_step` discards model usage. Adding decision usage to session accounting requires a new path through dispatch and candidate classification. |
| [Tool phase](../../../src/core/tool_phase.ail) | Tool-policy dispatch sees proposed calls before execution, including steps that never invoke a solver judge. |
| [Execution program](../../../src/core/dst_program.ail), [journal](../../../src/core/journal.ail) | Current formats are `execution-program/4` and journal schema 1. Neither defines the decision records proposed here. |

The motivating backend is `typesafe/jev-1.13` on
[OpenRouter](https://openrouter.ai/typesafe/jev-1.13). The official SDK exposes
`POST /api/alpha/decisions` with model, state, and named questions:
[transport](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/funcs/alphaDecisionsCreate.ts),
[request types](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionsrequest.ts).
Its [choice answer](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionschoiceanswer.ts)
allows absent probabilities and confidence. These primary sources were inspected by the
drafting agent on 2026-09-18; the first reviewer did not independently verify them. No paid
inference or calibration evaluation has been run. Endpoint and provider details remain adapter
concerns and must be checked again when implementing that adapter.

## D1. Extensions own judgment policy; the host owns execution

| Extension owns | Host owns |
|---|---|
| Whether querying is useful; evidence selection and its limitations | Invocation sites and recorded runtime evidence |
| Questions, options, rubrics, and identifiers | Generic validation and operator-configured backend bindings |
| Thresholds, abstention, feedback, and a declared intervention ceiling | Transport, deadlines, admission, accounting, and the effective ceiling |
| Pure preparation and interpretation | Ordering, attribution, persistence, replay, and applying votes |

Core has no completion-specific questions or feedback templates. Extensions select a logical
backend binding without handling credentials. The first guard can use Jev, a scripted backend,
or another conforming adapter. The host may lower an extension's declared limits but cannot
silently change its questions or interpretation thresholds.

## D2. Declare two pure decision capabilities in ABI 8.0

Choose declared preparation and interpretation, with a shared vocabulary and two invocation
sites. The notation below specifies the proposed contract; it is not compiled AILANG:

```text
DecisionSolverJudge(
  descriptor: DecisionPolicyDescriptor,
  prepare:   (ExtCtx, candidate: string) -> JudgePreparation,
  interpret: (ExtCtx, candidate: string, DecisionRequest, DecisionObservation)
             -> FinalizeDecision
)
JudgePreparation = Immediate(FinalizeDecision) | Query(DecisionRequest)

DecisionToolPolicy(
  descriptor: DecisionPolicyDescriptor,
  prepare:   (ExtCtx, ToolCallEnvelope) -> ToolPreparation,
  interpret: (ExtCtx, ToolCallEnvelope, DecisionRequest, DecisionObservation)
             -> ToolPolicyDecision
)
ToolPreparation = Immediate(ToolPolicyDecision) | Query(DecisionRequest)

DecisionPolicyDescriptor = {
  local_id: string,
  question_version: string, question_config: Json,
  interpretation_version: string, interpretation_config: Json,
  max_interventions: int
}
DecisionRequest = { backend_binding: string, state: Json, questions: [NamedQuestion] }
```

Both callbacks are pure and are positional constructor arguments. Imported-constructor probes
must test direct lambdas, named bindings, and indirect closure construction. The pure contract
admits no port effects even though `ExtCtx` contains ports. This avoids widening the legacy
judge's effect barrier and makes the new callback slots eligible for the pure-slot coverage
criterion; the host's query leaf must independently satisfy the recording gates.

Registration may capture immutable configuration only when all decision-relevant values are
represented in the descriptor. `question_config` includes configuration affecting selection of
evidence and construction of questions; `interpretation_config` includes thresholds, abstention,
and feedback policy. Versions identify code/policy revisions, including feedback-template changes.
No environment reads occur inside the pure callbacks. The host hashes these explicit values;
it cannot inspect closures or prove that an extension disclosed all captured configuration.
Disclosure and version discipline are extension conformance obligations, not a security property
of the digest. The current kind-only `ext_set_digest` cannot enforce this contract by itself.

Each invocation issues at most one request, containing all questions for one state. Interpretation
receives the exact prepared request and the same evidence snapshot used by preparation. Its world
token is refreshed to the host's successor; the pure interpreter cannot execute against it.
Interpretation cannot request a second query or mutate artifacts.

Multiplicity is by **vote family**: at most one of `SolverJudge`/`DecisionSolverJudge` and at most
one of `ToolPolicy`/`DecisionToolPolicy` per extension. One finalize atom and one tool-policy atom
may coexist. Local IDs must be nonempty, unique within an extension, and stable across resumes.
Normalization, kind enumeration, fixtures, and coverage classification must encode these rules.

Both new variants are part of the proposed 8.0 contract, even if only the completion extension
ships first. The second variant lets a no-progress guard examine a proposed tool call and recent
recorded outcomes; it may return an existing `Deny(feedback)` or `NoOpinion`. It does not require
a new generic hook or widen the existing pure `ToolPolicy`. `ExtPorts` gains no field. Existing
`SolverJudge` callback effects stay unchanged, but its shared vote type changes under D4.

## D3. Freeze typed observations, explicit absence, and evidence provenance

The public question/answer vocabulary is provider-independent:

```text
NamedQuestion = { id: string, prompt: string, guidance: Json, kind: QuestionKind }
QuestionKind = Binary | Choice([NamedOption]) | Rubric([NamedOption])
NamedOption = { id: string, description: string }

DecisionAnswer = { question_id: string, answer: Answer }
Answer = BinaryAnswer(probability: int)
       | ChoiceAnswer(option_id: string, distribution: Option[[Probability]],
                      confidence: Option[int])
       | RubricAnswer(score: int, distribution: Option[[Probability]])
Probability = { option_id: string, probability: int }
DecisionResponse = { answers: [DecisionAnswer] }

DecisionObservation = { result: DecisionResult, usage: DecisionUsage }
DecisionResult = Answered(DecisionResponse) | Unavailable(UnavailableReason)
UnavailableReason = UnconfiguredBackend | UnsupportedRequest | InvalidRequest
                  | InvalidResponse | BudgetExhausted | Timeout | ProviderFailure
DecisionUsage = { input_tokens: Option[int], output_tokens: Option[int],
                  cost_millicents: Option[int] }
```

Probabilities and optional confidence use integer basis points, `0..10000`. A rubric has at
least two ordered levels; score is `0..10000` from its first to last level. The adapter maps an
index-based provider score linearly to that interval. A choice has at least two distinct options.
IDs are nonempty and unique in their scope. Requests have at least one question. Sizes are
host-bounded, while backend-specific limits remain adapter validation rules.

The adapter validates finite raw numbers and their domains before conversion. A provided full
distribution must include every option exactly once and sum to 1 within `1e-6` on the wire;
outside that tolerance it is invalid. Inside the tolerance, normalize and apportion 10000 units
using largest remainders, breaking ties in request option order. Scalar conversion rounds to the
nearest basis point, with halves rounded up. Integers give deterministic ABI values; they do not
eliminate validation of the provider's floating-point response. Returned scores need not equal
the mean of a separately supplied distribution unless the adapter's documented contract requires it.

Duplicate, missing, extra, or mismatched answers invalidate the whole response. Validate kinds,
IDs, ranges, coverage, and nonnegative usage. Missing optional distributions, confidence, or
usage remain `None`; do not manufacture certainty or zero cost. An adapter that cannot supply
a required binary probability or rubric score returns `InvalidResponse`, not an invented value.
An extension can require a distribution and abstain when it is absent. No probability is a
claim of calibration. Cancellation, codec corruption, and strict-replay divergence are host
control failures, never `Unavailable` that an interpreter may turn into a vote.

Batch the following **three `ExtCtx` additions** into 8.0:

```text
verification: VerificationEvidence
tool_evidence: ToolEvidenceWindow
decision_state: Option[DecisionInvocationState]

VerificationEvidence = NotReached | Disabled
                     | Passed(VerificationRun) | Failed(VerificationRun)
                     | VerificationUnavailable(reason: string,
                                               run: Option[VerificationRun])
VerificationRun = { occurrence: string, step: int, command: string,
                    exit_code: Option[int], output: string, truncated: bool,
                    workspace_revision: Option[string] }

ToolEvidenceWindow = { records: [ToolEvidence], complete_from_session_start: bool,
                       omitted_count: Option[int] }
ToolEvidence = { call_id: string, step: int, tool_name: string,
                 outcome: ObservedToolOutcome, output: string, truncated: bool,
                 workspace_revision: Option[string] }
ObservedToolOutcome = CommandExit(int) | ToolSucceeded | ToolFailed(string)
                    | ToolDenied(string) | ToolPending | ToolOutcomeUnknown

DecisionInvocationState = { invocation_id: string, mode: DecisionMode,
                            interventions_used: int, intervention_limit: int }
DecisionMode = DisabledDecision | ShadowDecision | EnforcingDecision
```

Evidence is constructed from recorded host observations, with occurrence/call IDs providing
provenance. `CommandExit` requires a command outcome carrying that exit code; arbitrary textual
tool output and model claims cannot create it. `ToolSucceeded` means the tool reported success,
not that the user's task passed. Unknown, missing, truncated, and historical untyped results stay
explicitly uncertain. Window truncation sets completeness false; an unknown omitted count is
`None`. Full transcript access is not proof that the separate typed window is complete.

Verification gating and evidence are separate outputs of the verifier integration. Preserve
today's gate behavior, while distinguishing an actual pass from disabled verification, failed
execution, and missing infrastructure. Blank candidates can legitimately see `NotReached` before
the later DP7 gate. Evidence from an earlier invocation must retain its occurrence and must not
be relabeled as current. Workspace revision is optional and may be populated only from an actual
recorded revision mechanism; absent revision means freshness across edits is unknown. This ADR
does not promise a complete file-change set or a filesystem snapshot. A guard requiring those
facts must abstain until an authoritative evidence producer supplies them.

Other hook sites receive truthful evidence where available and `decision_state = None`. Decision
callbacks always receive `Some` with host-stamped identity and limits. Legacy context fixtures
must explicitly initialize these new fields, including `NotReached` or incomplete/empty tool
evidence where appropriate; defaults must not assert success.

## D4. Execute between pure callbacks at visible core port leaves

Use per-atom, two-phase dispatch. `ext/runtime.ail` owns ordered enumeration, preparation,
interpretation, and vote merging; it does not execute `decision_query`. An internal typed cursor
identifies the current extension, atom position, site, and prepared request. The caller drives
that cursor one atom at a time:

```text
session.ail: existing candidate gates → finalize dispatcher cursor
tool_phase.ail: existing tool-policy boundary → tool-policy dispatcher cursor
    ↓
ext/runtime.ail: run next legacy atom OR prepare next declared atom
    ↓ Query
calling core module: validate/admit → reserve → advance + decision_query + witness
    ↓ observation and successor world
ext/runtime.ail: interpret, collect vote → next atom with successor world
    ↓ end
merge votes → calling module applies result and journals selected intervention
```

Finalize queries execute through `C2LoopState.provider` in `session.ail`. Tool-policy queries
execute through core `Ports` already supplied to `tool_phase.ail`. Both are scanned by the
driver leaf inventory. Extract the existing ordinal-witness recording helper from its private
session implementation for both callers; keep the actual port call in each scanned module and
teach the inventory the new request class. Do not hide a helped leaf inside `ext/runtime.ail`.
The internal dispatch result carries successor world, accounting deltas, and attributed votes;
candidate and tool-phase results propagate all three to session state.

Preparation is not performed for all atoms in advance: each subsequent atom sees the world
after previous legacy effects and decision exchanges. Interpretation occurs before proceeding
to the next atom. Every eligible atom runs, even if an earlier vote already wins. Query losers
still consume budget and their successor worlds are retained. Registry/atom order is stable;
no skip-on-first-feedback optimization, cross-extension batching, concurrency, or automatic
transport retries is part of v1. An atom can avoid inference through `Immediate`, and host limits
can refuse admission. A tool-policy invocation is per proposed tool call, not once per batch.

Preserve finalize precedence: first `ContinueWithFeedback` wins, otherwise `Accept`, otherwise
`NoDecision`. Preserve tool-policy precedence and current tie behavior: first `Deny`, otherwise
last `Pending`, otherwise `Allow` if any, otherwise `NoOpinion`. Host permissions and deterministic
verification remain authoritative; a learned `Allow` cannot grant permissions unavailable through
the existing tool path. Open waits retain the existing park/wake boundary.

**Remove output replacement in 8.0: `FinalizeDecision.Accept` becomes nullary.** It approves the
candidate supplied to the judges; finalization always uses that original candidate. Production
in-tree acceptors already pass through their candidate, while a synthetic runtime test exercises
replacement and must change. External users need a migration notice. This closes ambiguity about
which text was judged without adding re-query loops. DP7 verifies workspace work, not the prose
of a candidate; removing replacement does not make DP7 a prose validator or solve unrelated
workspace mutation by legacy effectful judges.

## D5. Bound cost and interventions, including interrupted execution

The host enforces request size, call-count, spend, and adapter deadline limits. Each query must
have a finite configured maximum charge to reserve before dispatch; lack of a safe reservation
refuses admission. Reserve against both the decision allowance and the session spend allowance.
Afterwards, reconcile known usage; unknown charge retains the reservation. Known provider cost
is rounded upward to integer millicents for admission accounting. Preserve optional raw usage in
the recorded observation and distinguish known charges from outstanding reservations in totals
and diagnostics. Do not treat a failed HTTP request as proof that nothing was charged.

This requires new accounting propagation through dispatch, `CandidateClass`, tool-phase results,
and both session-state update paths. The old integer totals can represent conservatively charged
amounts but cannot alone represent uncertainty; retain a separate decision accounting ledger.
Existing `ext_ai_step` usage loss is a separate current limitation. This work must account for
every new decision query, but must not claim all existing extension AI spend is already covered.

Pure callbacks have no durable write channel. Add host-owned session state keyed by registered
extension owner, invocation site, and stable local ID. It stores applied intervention counts and
the decision accounting ledger, outside extension-writable `ext_artifacts`. For a decision atom,
the effective intervention limit is the lower of operator and descriptor limits, fixed for that
session identity. At exhaustion, skip both callbacks, emit a limit event, and produce the neutral
vote (`NoDecision`/`NoOpinion`); record why. An extension cannot raise or reset its counter by
changing its policy version. Renaming/removing/reinstalling an atom or switching profiles must
preserve prior spend and retained counters; a newly introduced identity requires explicit registry
migration rather than silently obtaining a fresh allowance on resume.

Increment the counter only when that atom's selected `ContinueWithFeedback`, `Deny`, or `Pending`
is applied, including an `Immediate` vote. Nonwinning, neutral, acceptance/allow, and shadow votes
do not consume intervention allowance. Each applied pending restriction counts once at selection,
not once per subsequent wake. Persist vote application, the associated transcript/control effect,
and counter increment as one recoverable journal transaction before advancing the session. This
is new persistence work, not an existing artifact update facility. Ordinary compaction already
leaves finalize history intact; durable counters avoid coupling the new pure API to marker prose.

Calls remain synchronous. The adapter owns a bounded deadline; expiration produces
`Unavailable(Timeout)`, possibly with unknown cost. Cooperative cancellation of an in-flight
callback is not promised. The TUI can terminate the runtime child on escape; process death is a
host control outcome. The host must not apply a result belonging to a previous invocation.

Before dispatch, durably record invocation identity and its reservation. Record a complete
observation before interpreting it. On process death, a started request without a complete
observation remains interrupted with unknown charge; retain the reservation. Do not fabricate an
answer or replay a partial exchange. A complete observation without committed vote application
remains an auditable, charged observation with no applied intervention. Resume reconstructs these
facts, abandons that interrupted invocation, and may start a fresh occurrence only after normal
admission checks. No automatic reissue, exactly-once upstream billing, or transparent mid-callback
resume is promised. These durable records deliberately strengthen the first review's simpler
suggestion to leave interrupted requests absent from the journal.

The first completion guard maps unavailable service or insufficient evidence to `NoDecision`.
That preserves existing stopping behavior, not proof of successful completion. Its uncertain
answers and transport failures remain distinguishable in the record.

## D6. Record queries, policy identity, and proposed versus applied votes

Add a core `Ports.decision_query` with live, recording, scripted, and strict-replay adapters.
The exchange returns an observation and successor `WorldState`; scripts store observations,
not recursively embedded worlds. The port is an observation leaf, with complete request-class,
ordinal, witness, identity, cursor, reconstruction, fault-catalogue, and trace-projection support.
Public `ExtPorts` remains unchanged, but its opaque `ExtWorld` codec must transport the new world
cursor correctly. Unknown identity tags must fail validation, not fall through to the current
`ClockAdvanceIdentity` default or reset to an empty world.

Each admitted `Query` consumes exactly one decision-port read and ordinal, even if its adapter
returns a timeout or invalid response. Host preflight refusal (including invalid requests and
exhausted budget) performs no port read: record the refusal event and invoke the interpreter with
the corresponding `Unavailable`. Disabled/exhausted-intervention atoms are skipped as D5 defines.
Strict replay re-executes deterministic preflight and never contacts the provider. Divergence in
admission, invocation occurrence, or expected interaction is a replay failure.

Split policy identity into two layers:

| Layer | Recorded contents and matching rule |
|---|---|
| Query identity and canonical request projection | Host-stamped session/run/turn, candidate or tool-call occurrence, extension owner, site, atom position/local ID; question version/config digest; logical binding and resolved configured backend/model; adapter contract version; exact state, ordered questions, evidence, and host request limits. Strict query replay matches these. |
| Policy/run manifest and vote metadata | Interpretation version/config digest, descriptor limit, effective mode/limits, registered extension set, proposed vote, effective vote, and selected/applied attribution. Strict whole-run replay checks this policy snapshot too and compares derived votes. |
| Response metadata | Provider-returned model/version, complete observation, usage, recorded timing, and diagnostics. Values learned only after the call are not retroactive request-matching fields. |

Use canonical JSON serialization and explicit ordered arrays for stable digests. Record request
payloads or durable references that resolve to their exact bytes, subject to existing evidence
retention/access rules; a digest alone is insufficient. Exclude credentials. This ADR does not
authorize exporting private session corpora. The descriptor snapshot augments the kind-only
extension digest; it does not rely on that digest to detect thresholds captured in closures.

Strict whole-run replay rejects changed interpretation policy even when its query is byte-identical.
An explicit **offline re-interpretation experiment** may load fixed requests/observations and run
a different pure interpreter when the question/evidence digest is unchanged. It labels that change,
compares proposed votes, and performs no live calls or session transitions. It is not strict replay
of the modified policy's trajectory. Once changed votes branch execution, downstream recorded
observations cannot be presumed applicable. No permissive regression-mode fallback is implied.

Introduce decision event vocabulary for invocation/preparation, skip or preflight refusal, query
start/reservation, complete observation, proposed/effective vote, and selected application. Record
`Immediate(NoDecision)` so an invoked abstaining guard differs from an absent guard. Disabled mode
records a skip without callbacks. Shadow mode runs preparation/query/interpretation and pays normal
query cost, but substitutes the neutral effective vote and increments no intervention count.
Record losing votes as well as the selected one. Runtime events and journal records have explicit
mapping; replay must reproduce deterministic projections while consuming recorded external timing.

## D7. Migrate the ABI and each persisted format explicitly

Target extension ABI **8.0**, coordinated with the upcoming major release. The
[ABI header](../../../packages/motoko-ext-abi/types.ail) assigns any `Capability` variant addition
to a major version. This proposal also changes `FinalizeDecision` and adds `ExtCtx` fields.
No version is bumped by this document.

| Surface | Proposed migration |
|---|---|
| ABI 7.4 → 8.0 | Two capability variants; public descriptor/request/observation/evidence/state types; three `ExtCtx` fields; nullary `Accept`; vote-family normalization. No `ExtPorts` addition. |
| Core interfaces | `Ports.decision_query`; world cursor and dispatch result propagation; accounting/evidence/session state; shared witness helper with scanned call sites. |
| `execution-program/4` → `/5` | New decision interaction identity, request/observation codecs, scripts, cursor, reconstruction, projections, and catalogue class. Preserve historical v4 fixture bytes and semantics. |
| Journal schema 1 → 2 | Typed host decision state, reservation/observation records, policy snapshot, and atomic vote-application recovery. Use a versioned fold; do not hide host counters in extension-writable artifacts. |
| Event vocabulary → version 2 | Invocation, skip, query, observation, vote, and application events, including immediate and shadow paths. |
| Extensions and tooling | Kind/arity maps, conformance and no-op profiles, leaf inventory, all constructors/codecs, package pins/locks, and external consumers. |

Journal schema 1 remains readable only under its original semantics for inspection/evaluation;
live schema-2 resume requires a schema-2 journal. Refuse a schema-1 live resume with pinned-runner
guidance, rather than fabricate historical evidence, spending, or counters. An explicit historical
migration tool may be designed separately. `--resume-force` may waive an extension-digest mismatch
under the established policy; it does not bypass incompatible schema decoding or erase retained
host state. A same-profile `SolverJudge` → `DecisionSolverJudge` change changes `ext_set_digest`
and triggers its existing resume refusal in addition to the format checks. Any allowed profile
or registry migration must retain old decision spend/counters under D5's rules.

The first review's source inventory identified 37 `ExtCtx` literals in 28 files, 8 core `Ports`
literals in 3 files, 3 full `WorldState` literals in 2 files, and 9 documented `IdentityBody`
consumers. Treat these as point-in-time review counts to refresh during implementation, not a
complete dependency proof. Its 17 `ExtPorts` literals need no new field under this design.
Known tooling edits include `tools/driver_leaf_inventory/derive.py`'s request-class count,
`tools/ext_ambient_inventory/hook_scope.py`'s arity table,
`tools/profile_definition/check_fixtures.py`'s kind list, and `dst_profile_coverage.ail`'s capability
maps/classification. Include the world-token decoder's unknown-tag behavior in migration tests.

## Consumers and evaluation

The completion-evidence extension asks narrow questions about specific claims or acceptance
criteria. It supplies explicit evidence limitations and an insufficient-evidence option. It
returns `NoDecision` or bounded `ContinueWithFeedback` using its own templates, not generated
completion prose. An unavailable or stale verification record cannot substantiate a claimed pass.

The no-progress example uses `DecisionToolPolicy` to compare a proposed call with recent typed
outcomes and transcript evidence, including loops that never reach finalization. Its `Deny` gives
corrective feedback through the existing tool-policy path. It must abstain on insufficient evidence
and obey the same limits; it cannot turn a semantic answer into broader tool authority.

Start both contracts with scripted consumers and synthetic evidence. The first live completion
guard begins in shadow mode before opt-in interventions. Compare correct stops, premature stops,
honest blocked reports, repeated tool calls, missing infrastructure, truncated/stale evidence, and
outstanding waits against deterministic guards. Measure false objections, missed bad completions,
task outcome, added steps, cost, and latency separately from replay fidelity. Typed answers and
reproducible decisions are not correctness certificates.

## Review response and decisions formerly open

| First-review item | v0.2 resolution |
|---|---|
| N1 execution site | D4: sequential per-atom prepare/execute/interpret, with query leaves in session/tool phase and shared witness support. |
| N2 multiplicity | D2: one vote per family, including legacy/new cross-kind combinations. |
| N3 evidence | D3: typed verification, tool outcomes with explicit limits/provenance, and invocation state on `ExtCtx`. No invented file snapshot. |
| N4 hidden config | D2/D6: explicit descriptor and digests; disclose the host's inability to inspect closure captures. |
| N5 version split | D6: query matching separate from interpretation metadata; strict runs still validate both, offline experiments explicitly differ. |
| N6 replacing acceptance | D4: nullary `Accept`; migrate the synthetic replacement test and external consumers. |
| N7 accounting | D5: new propagation path, optional usage, and conservative reservation ledger; acknowledge the separate existing AI-usage gap. |
| N8 durable state | D5: host-owned counters, atomic application record; correct the compaction/history claim. |
| N9 cancellation/resume | D5: synchronous timeout versus process death; persist reservations to avoid losing unknown charges across restart. |
| N10 every atom runs | D4: preserve full ordered collection, including paid losing votes. |
| N11 compatibility | D7: explicit ABI/program/journal/event versions, constructor inventory, resume refusal, strict world-tag validation. |
| N12 events | D6: immediate, skipped, losing, shadow, and applied-vote records; catalogue additions. |
| N13 provider claims | External-evidence section attributes verification to the drafting agent, with dated primary sources and limits. |

Q1 chooses declared callbacks. Q2 includes finalize and tool-policy variants in 8.0. Q3 adopts
the three context additions and host state. Q4 specifies typed observations, units, absence, and
validation. Q5 removes replacement. Q6 specifies admission, accounting, counters, timeout, and
crash recovery. Q7 chooses the separate migrations above. Acceptance of these decisions remains
pending review; no unresolved alternative is silently treated as a frozen interface.

The callable `ExtPorts.decision_query` alternative remains useful if a future consumer needs
adaptive multi-query workflows. Those workflows are outside v1, so the new public effect surface
and wider callback rows have no demonstrated benefit here. Core-owned questions, chat prompts
masquerading as this endpoint, implicit artifact protocols, and extension-local subprocess
transport do not meet the ownership, type, and replay requirements.

## Freeze evidence and implementation handoff

Before calling the ABI frozen, require:

1. Accepted review of both capability signatures, shared types, context additions, multiplicity,
   nullary `Accept`, policy identity, and execution placement.
2. Imported-constructor compiler probes for callback purity, updated inventories/conformance,
   and compiled scripted examples for both consumers. No ABI claim rests solely on this sketch.
3. Evidence that question/configuration changes require no core edits; strict query and policy
   mismatches fail; offline re-interpretation cannot be mistaken for strict trajectory replay.

The implementation plan must then provide, before enabling live enforcement:

4. Live-recorded/scripted parity, world propagation for losing votes, distinct identical-content
   occurrences, strict replay without network, and explicit exhaustion/divergence behavior.
5. Verification/evidence truthfulness; malformed/absent answers; budget/deadline failures; crash
   points before/after reservation, observation, and atomic application; resumed accounting and
   intervention limits; no replay of a partial exchange.
6. Composition with DP7, waits, permissions, all-atom ordering, tool-policy tie behavior, and shadow
   mode; compaction/profile changes/resume cannot silently reset host allowances.
7. Separate format migrations, historical fixtures left intact, unknown-tag rejection, and
   operator-facing resume/migration guidance.

Relevant existing checks include `make declared_vs_performed`, `make ext_hook_scope_selftest`,
`make profile_coverage`, `make driver_plus_no_ops`, and `make event_vocabulary`. These are future
implementation obligations, not tests run for this documentation revision. Configured provider
limits, first-guard wording/thresholds, and live quality measurements can evolve without changing
the proposed ABI. Persistence and adapter implementation remain separate release work; they are
not grounds to call an unprobed ABI frozen.

## Related records

- [First review: Claude Fable](REVIEW-adr001-v0.1-verdicts-fable.md)
- [Research: System One implications](RESEARCH-system-one-implications.md)
- [Research: System One implications, second analysis](RESEARCH-system-one-implications_2.md)
- [005: Harness policy boundary](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md)
- [013: DST architecture sequencing](../013_core_architecture_for_dst/ADR-001-sequencing-the-dst-architecture-caps.md)
- [013: Park and wake](../013_core_architecture_for_dst/ADR-002-park-and-wake.md)
- [013: Session journal and resume](../013_core_architecture_for_dst/ADR-003-session-journal-and-resume.md)
- [013: Journal as evaluation source](../013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md)
- [017: Extension ABI evolution](../017_extension_handling/ADR-001-extension-abi-evolution.md)
- [028: The loop that would not stop](../028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md)
