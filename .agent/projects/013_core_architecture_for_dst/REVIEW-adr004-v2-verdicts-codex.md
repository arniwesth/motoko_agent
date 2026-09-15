# ADR-004 v2 adversarial review verdicts

Date: 2026-09-13
Reviewed HEAD: `a0384e45d0acc11871d71d1ee473cebec5fde46c` (`a0384e4`)
Branch: `arniwesth/013-plan003-and-herdr`
Subject: `ADR-004-journal-as-evaluation-source.md`, Proposed v2, untracked
Prior: `REVIEW-adr004-verdicts-codex.md` (v1)

V2 was read in full. New mechanisms and selected carried coordinates were checked with `git show a0384e4:<path>`. Python read existing host events, inputs, outputs, TSV and compressed profile samples in `/workspaces/motoko_agent-mem`. No code or ADR was edited, no commit was made, and no type check, replay or sweep was run this round. Only this review was written.

## Overall verdict

**Return for v3.** V2 makes substantial corrections: supplementary host evidence, explicit selectors, narrower claims, separate source/parent verdicts, protected evaluator identities, cumulative omissions and safe sequencing. Four decisions still prevent the proposed gate from being concrete:

1. **The overlay protects evaluator files, not the integrity of observations.** Candidate core owns and returns the world containing the adapter log. It can replace, omit or fabricate those observations. Overlaying the trusted normalization arm by whole file also risks overwriting the candidate's loop in `session.ail`.
2. **Cutoff exhaustion conflicts with exact counts and measurement scope.** An exhausted adapter is reached through another provider call, after its request was prepared; error handling and finalization also allocate. Counting that call violates C3's selected-prefix count; ignoring it fails to account for its measured execution.
3. **C3 compares model strings from different boundaries.** The live event contains the Motoko routing name; the adapter receives the stripped API name. Direct equality rejects this evidence session even with the right model configured. The declared candidate class also still permits changes invisible to its request projection.
4. **The zero-start classification is factually wrong.** Message starts can carry cumulative counts and derive nudges from history. The evidence r2.1 carries nonzero counts. Decide which such starts T0 admits, rather than assigning all of them the ordinary export's zero state.

The proposed `PortedWorld` variant is feasible and does not require a Ports field, new production entry or new helped request. The corrected historical evidence is mostly accurate. These positives do not resolve the four blockers above.

## 1. Disposition of the eight required changes for v2

| # | V1 required change | Verdict | V2 answer | Still missing |
|---|---|---|---|---|
| 1 | Exact selection, successful-call/delta association, missing response data, initial state | **PARTIALLY** | D1 Inputs, Selection, Association, Starting state, Configuration, Typed segment ends | Run association needs the two banner shapes and retained order; cache creation is conditionally logged, not unavailable; starts do not have uniformly zero counts/nudges; leading seed users and valid-cutoff versus corrupt-source refusals need distinction. |
| 2 | Explicit world initialization, full supported results, validated tools, fail-closed exhaustion | **ADDRESSED DIFFERENTLY — acceptable mechanism, incomplete execution contract** | D2 uses `PortedWorld`, full `StepResult`, exact tool validation and typed errors | The variant also needs imports/exhaustive helper updates. Error outcomes do not stop evaluation by themselves; exhaustion adds a request. Specify trusted mismatch persistence and cutoff/terminal accounting. |
| 3 | Separate source/parent fidelity, pinned inputs, admissible class, honest prefix measurement | **PARTIALLY** | D3 class, C1–C5, envelope, verdict, discarded divergence and bounded rerun | Model-boundary mismatch; world-log integrity; canonical blind spots inside allowed core code; no terminal/cutoff check; whole-process totals still extend beyond the declared prefix. |
| 4 | Simulation/profiling scope, timing-dependent GC, correct units, calibrated tolerance | **PARTIALLY** | D4 Claims; Context and retraction 4 | Units and secondary GC treatment are addressed. The recompilation explanation for the first-run outlier is unverified; warm-up does not establish a replay-only measurement boundary. D3/D4 extraction/verification scope must be implemented consistently. |
| 5 | Independent evaluator/corpus/pin protection, identities/exposure, private derived artifacts | **PARTIALLY** | New D5; D6 handling, admission, exposure and withheld entries | File hashes do not authenticate observations returned by candidate core; trusted and candidate regions overlap in `session.ail`; same-user coordination must not be described as enforceable against an adversarial candidate. |
| 6 | Cumulative omissions, additional extension observations, scoped streaming/compaction claims | **ADDRESSED DIFFERENTLY — acceptable** | Renumbered D7, with T2 explicitly an investigation | The primary correction is addressed. T2b should explicitly remove operator input from the refusal list; T3 should state whether it is a separate live experiment rather than a cumulative replay tier. These are editorial scope corrections. |
| 7 | Short sizing first, aggregate cgroup guard, exact counts, regression control, length decision | **PARTIALLY** | Renumbered D8 P0–P6 | Ordering and guard direction are addressed. Historical control needs the new evaluator bridge without replacing the candidate loop; its 57-turn numbers are wrong and include a synthetic call. Threshold/polling details belong in PLAN-004. |
| 8 | Correct 299+1 description, tally, loaded extensions, large-fixture qualification | **ADDRESSED** | Retraction 8; Context evidence/limits and workload comparison | The named historical corrections are accurate. D8 adds different unsupported 57-call figures; D4 adds an unsupported recompilation explanation. Neither is part of the corrected historical table. |

## 2. Per-decision verdicts

| Decision | Verdict | Reason |
|---|---|---|
| D1 | **RETURN** | Required host fields are available, but zero-start classification, optional cache fields and source/cutoff rules remain wrong or incomplete. |
| D2 | **ACCEPT WITH CORRECTIONS** | `PortedWorld` is a suitable explicit initialization mechanism; error outcomes, model observations and cutoff accounting need correction. |
| D3 | **RETURN** | Useful restricted checks, with unresolved boundary mismatch, evidence integrity and canonical-blind candidate changes. |
| D4 | **ACCEPT WITH CORRECTIONS** | Resource scope and timing qualifications are appropriate; warm-up causality and actual cutoff measurement remain unproven. |
| D5 | **RETURN** | An evaluator overlay is file independence; it does not establish independent observations from the candidate-owned world/trace. |
| D6 | **ACCEPT WITH CORRECTIONS** | Privacy, admission distinctions and exposure rules are substantially addressed; enforcement depends on D5 and association on D1. |
| D7 | **ACCEPT WITH CORRECTIONS** | Cumulative omissions and T2 investigation are honest; clarify T2b/T3 and operationalize source-compaction eligibility. |
| D8 | **ACCEPT WITH CORRECTIONS** | Safe sequencing and cgroup guard are appropriate; corrected control figures and historical assembly/measurement rules are needed. |

### D1 — return

The excerpt repairs the missing successful-response metadata without changing ADR-003. It is feasible to associate requests and successful results by ordered run context: seven ledger `session_start` events have `run_id`; three rpc banners have `config_profile` and `loaded_extensions`. The request/result/retry events themselves have `session_id` and `step`, **not `run_id`**. Preserve both banner shapes, event order and source positions; establish a current run from the ledger banner and a current spawn profile from the rpc banner, and validate that mapping against the selected journal path. Missing/ambiguous association may then refuse. A schema requiring every `session_start` to have all listed fields would refuse the actual log.

`thinking.tool_calls` is a numeric count, not the invocation list; the actual calls must still come from the recorded assistant message and agree with that count. `cache_read_input_tokens` is present in 681/684 successful result events. Both cache fields are emitted only when positive (`phase_vocab.ail:1071–1085`). At this producer version, absent cache usage means zero; `cache_creation_input_tokens` is absent throughout this particular log, but the producer **does log it when positive**. Retract “cache creation is not logged” and the proposed host-logging decision. Decode the optional fields under a pinned producer contract, retain positive cache-creation values where present, and return a full `StepResult` rather than `Unknown` into an integer field.

The starting-state rule mistakes one telemetry field for the entire constructor. `c2_initial_state_with_counts` zeros telemetry/artifacts, derives `nudges_used = count_persist_nudges(history)`, and accepts `prior_counts` (`session.ail:952–974`). The ordinary exported entry supplies zero prior counts through `run_v2_from_messages_traced_with_policy` (`:3827`), but the production message-only follow-up passes the loop's accumulated counts (`:4461–4463`). This is distinct from a continuation start. In the r2.1 snapshot, the preceding state delta has started/completed counts **350/342**, and the first delta in r2.1 has **351/343**. Thus that source start does not meet v2's all-zero rule even though it follows a successful run. Either refuse it explicitly, carry the appropriate state through an existing suitable entry, or declare precisely which values are synthetic and restrict the supported observations. Do not silently classify it as zero-state source fidelity. Nudges must be classified from the seed, not assumed zero.

Selection must also separate leading seed input from in-run input. Source r2.1 has `run_started` at entry 1054, a user message at 1055, and its first assistant at 1056. The prototype's seed includes that user. Define `start` as the first evaluated call/turn after leading input, or otherwise specify that seed-building operation; cutting every user after `run_started` would yield an empty segment. Identify normal completed ends versus interrupted/truncated ends: the output requires a `cutoff.reason` even when the selector uses `EndAt` on genuine completion.

Finally, D1's “typed segment ends” puts valid unsupported boundaries together with `ChainBreak`, malformed/schema errors and ambiguous IDs. A well-formed retry or interjection may authorize a smaller prefix. A corrupt source or ambiguous association must produce `Refused`, not silently manufacture a shorter `SourceFaithful` entry. State which reasons are cutoffs, which are refusals, and what validation applies outside the selected prefix. This preserves ADR-003 strictness rather than weakening it for admission.

### D2 — accept with corrections

The new variant is **feasible, not implemented at this HEAD**. The required normalization is straightforward:

```ailang
PortedWorld(p, world) => { ports: p, world: world }
```

This changes the existing compatibility sum and normalization, not Ports or an exported function signature, and performs no effect/request. Existing `Ported` remains unchanged. `dispatch_step` already takes Ports directly, so it needs no new variant branch (`stub_step.ail:705–715`). Add the constructor import to `session.ail` and update applicable exhaustive matches. In particular `ledger_parity_dst.ail:394–402` mirrors provider normalization to compute the outer frame's starting ordinal; it needs `PortedWorld(_, w) => w.ordinal`. The old `test/scripted_ports.ail:30–35` has an already narrow legacy match; audit its applicability rather than assuming the sum has only one consumer. This is more than “one normalization arm” as an implementation census, but no new frame contract or helped request is necessary.

Returning `ToolCompleted` with status -1 is the correct existing convention for unknown status (`ports.ail:616–621`). `ToolFailed` takes a record `{tool_call_id, code, message}`, not the positional constructor written in D2; fix the pseudocode. The correlation outcome is also a record `{expected_id, got_id}`. An argument/name mismatch with an unchanged ID should use a meaningful failure record, rather than equal “expected/got” IDs alone.

These outcomes prevent silent successful result fabrication, but **they do not abort the loop**: `tool_outcome_message` turns each error into a tool transcript message (`tool_phase.ail:277–296`). The runner must retain the mismatch independently and reject the complete measurement even if the candidate consumes, clears or masks the world-log record. Similarly `Err(replay_exhausted)` needs the complete AIError shape, especially `retryable: false`; a retryable sentinel can trigger additional attempts.

An observation stored in `WorldState.log` is currently an `Interaction` (`ports.ail:446`), not an unconstrained private append-only channel. Specify its encoding, current-call/consumption tracking and who authenticates it. A private digest function protects the computation from candidate imports; it does not protect the containing log from candidate core (§D5).

The exhaustion cutoff issue is substantive (§D3): the adapter cannot prevent the next provider call's preparation. Use a declared existing entry budget or another explicitly scoped stopping protocol, distinguishing natural completion, expected artificial suspension and unexpected exhaustion. No new production entry/helped request is implied by requesting that contract.

### D3 — return

The class/envelope is materially more honest than v1. It retracts byte equality, names unchecked parameters/schemas/configuration, separates parent agreement, excludes bypassed paths and discards divergent totals. Accept those corrections; do not expand this review into a demand for live provider/task-quality evidence at T0.

**C3's model comparison cannot pass as specified.** `ProviderCallPrepared.model` is `model`, before routing conversion (`session.ail:3412–3420`). The call to `dispatch_step` uses `provider_api_model(model, ...)` (`:3430`), which strips `openrouter/` except for `openrouter/auto` (`:271–294`). For this log the expected field is `openrouter/meta/muse-spark-1.3-contributor`; the adapter receives `meta/muse-spark-1.3-contributor`. Pin a trusted routing conversion of the expected model, store the logical and API model identities separately, and cross-check candidate-emitted logical metadata against its own appropriate expected value. Do not “fix” this by importing the candidate's conversion or comparing suffixes indiscriminately; that loses the independence C3 is meant to establish.

The adapter can compute a system-prefix digest from the leading system messages it receives. The live field is computed from pre-step `split.pinned` (`session.ail:3418`), not necessarily an independently observed post-extension prefix. T0's unchanged-payload/empty-extension assumption must be explicit, and the trusted evaluator must use the raw-prefix function, not `payload_digest` of that prefix (`phase_vocab.ail:369–370`). Source eligibility still does not prove all live extension activity was absent merely because a canonical hash matches.

**Allowed internal core changes can evade C1–C5.** For example, inside the allowed loop file a candidate can alter `make[1]` to `make[2]` only in a transient non-system payload message, preserving retained history and tools. C1 and C2 remain unchanged; C3 normalizes both spellings, the system prefix and model remain unchanged; C4/C5 see identical tools/requests/ordinals. Dropping/changing only transient non-system image parts is another example. The private copy reproduces these blind spots. This is not an evaluator-path edit or a tool/provider adapter change. The class currently requires expected preservation of **canonical** requests, so path-and-intent checks do not exclude it. The envelope acknowledges the blind spot, making the projected verdict honest, but does not establish that using the old response remains valid for a materially changed raw request. Narrow admissibility to raw-input-preserving changes with an independently reviewed assumption, and where possible add a raw expected-message check for these reconstructable T0 payloads. Continue to state that the live excerpt proves only the recorded projection.

**Exact count is necessary but not terminal equivalence.** The verdict has no terminal check or expected termination field. A candidate can make the same calls, retain the same messages and tools, keep its frame consistent, then return a different success/error/suspension outcome. No C1–C5 row requires that outcome to match either a recorded completion or the expected artificial cutoff. D8's promise to reject premature termination needs an explicit outcome/cutoff check, not just counts. Missing profile/synthetic config validation also needs a concrete preflight rule; D3 labels these pinned but unchecked.

**Exhaustion reintroduces the extra call problem.** After N recorded turns the existing core can prepare call N+1, emit its provider event, invoke the adapter, advance ModelStep and read the error-handling/finalization clocks. The adapter then returns exhaustion. If C3 includes that observation, exact source-prefix count fails; if it excludes it, the measurement still includes that extra computation. The whole-process profile also includes post-cutoff finalization and verification, so it cannot literally be allocation “up to” the source cutoff. Define either a driver-phase measurement ending before the sentinel or a whole-process experiment with explicitly included synthetic stopping overhead and separately counted sentinel traffic. On a supported exact N-call budget, expected artificial suspension can avoid a sentinel call, but the overridden budget/outcome must be recorded as synthetic configuration rather than source completion.

`ParentAgreement` remains acceptable as an explicitly weaker mode. D1 nevertheless says the excerpt is required at T0, while D3/D6 allow no-excerpt admission. Resolve whether that is a separate non-T0 mode or an intentional exception; specify where it obtains finish/usage metadata. Also map failed C1/seed/source checks to a defined refusal rather than treating `SegmentEnd` interchangeably as a successful cutoff and a source error.

### D4 — accept with corrections

Primary cumulative profiled allocation, calibrated tolerance, secondary GC/RSS, explicit toolchain/settings and listed invariant families address the earlier scope complaints. The GC/RSS figures agree with the stored data. It is correct to say that these are measurements of a named simulated execution and cannot credit bypassed paths.

The **new causal explanation** for the fixed probe's first-run 22.12 versus 10.88/10.86 GiB is not verified. Existing stdout shows type/effect checking; stderr shows a changed-dependency warning and gctrace. That proves neither that recompilation caused the additional allocation nor that one excluded warm-up eliminates the difference. Mark recompilation/cache warming as a hypothesis unless supported by logs or a targeted separate experiment. A warm-up policy can be chosen independently, but its state and exposure must be recorded and used equally for parent/candidate/control. A warm-up is itself a heavy execution and must pass the guard.

Specify the actual measurement process/interval. A pprof profile from the ailang child cannot automatically include extraction/verification performed later in a separate runner process; if they run inside the evaluator program, say so. Including those consistently is a legitimate total-experiment measurement, but it includes verification and stopping overhead after the last recorded turn. Resolve D3's cutoff language rather than claiming to truncate a whole-process profile. Recursion depth likewise needs a practical phase boundary that excludes evaluator recursion, not just that intention.

### D5 — return

E's private functions and path refusal prevent direct edits to the verifier. Hashing E/corpus before and after prevents undetected disk changes under the stated coordination rules. These are useful protections, but the Consequences claim that the checks cannot be rewritten by the graded candidate is insufficient as a claim about **evidence integrity**.

**The candidate runs between the adapter and the verifier.** Core receives the adapter's next_state and subsequently passes/returns a WorldState it constructs. `log`, `script`, `ordinal` and `pending` are ordinary fields available to candidate code. It can clear or replace the observation log, reseed the cursor or return a previously constructed world. C2 likewise depends on candidate-returned messages/trace unless a separate channel is specified. Pinning the code that later computes the checks does not independently authenticate those inputs.

A concrete adversarial bypass requires no change to E or corpus files: allowed core computes an alternate request, calls the pinned adapter on an expected request instead, uses the recorded response for the alternate computation, then returns a world/trace consistent with the expected execution. The adapter observes the expected call; C1–C5 and file hashes pass. More directly, core can fabricate replacement observation records after seeing recorded calls/responses. Existing effects also let in-process core emit candidate-controlled stdout; a separate parser receiving unauthenticated adapter records on that same stdout is not automatically independent. A separate OS user/container protects disk, but does not by itself make candidate-owned in-process world fields append-only or authenticate their provenance.

Choose a trust model. For cooperative reviewed candidates, explicitly state that observation integrity and correct core execution are trusted assumptions enforced by independent review, rather than claiming adversarial enforcement. For hostile candidates, provide an evaluator-owned channel/storage mechanism the candidate cannot replace and define what authenticated adapter observations mean; still limit claims to the externally observed interaction boundary. An authenticated real-call log alone cannot prove arbitrary internal computation or bypassed paths. Do not imply that private hashes solve that larger problem.

**The overlay granularity is unresolved.** The new variant definition is in `stub_step.ail`; its trusted import/normalization arm is in `session.ail`, also home to the candidate loop being measured. If that file is an evaluator path, refusing all C diffs that touch it excludes the primary candidate class. If E overlays the entire file, it replaces C's loop. If it is not an evaluator path, specify how the arm is added when testing historical `a6abda4`, where the variant does not exist. Use a reviewed compatibility patch/trusted-region policy or require a compatible baseline, and record the assembled tree and all applied changes. Verify with a small independently chosen marker/control that the assembled run actually executes C's modified core rather than E's copy. Whole-path overlay alone is not that specification.

### D6 — accept with corrections

Ignore-before-copy, 0700/0600 modes, contained derived output, local-only handling, per-entry identities, exposed dev entries, genuine withheld sessions and reporting refusals address the earlier corpus objections. It is reasonable to leave redaction/export unscheduled. Retention needs a concrete policy in the plan; “deletion includes every copy” is the right scope, not yet a retention duration.

Admission depends on D1's correct association/start classification and D5's declared trust model. A no-log entry cannot have its successful-result finish/usage values derived as D1 specifies; document its alternate input and weaker mode. The admission result must include actual assembled settings/configuration and the stopping/measurement scope, rather than only the source BootInputs and private-file hashes. Warm-up and held-out validation are exposures and belong in the exposure log; candidate-producing agents must not receive held-out details and later continue tuning under the claim that they remain withheld.

### D7 — accept with corrections

Cumulative omissions, T2 requiring new observations, no streaming cost-share inference and scoped compaction are substantially addressed. The current T0 verdict remains a projection agreement even if an unseen live extension transformation would pass that projection. Record source-compaction eligibility/assumptions in admission, rather than deriving them solely from C3 success.

T2b's “as T2” should explicitly remove operator input from the inherited refusal policy if it adds operator input support; it still inherits the other omitted lifetimes/effects. T3's live sampling/A/B are distinct transfer experiments, not simply additions to a deterministic recorded-response execution. State that separation and their applicable omissions. T1's synthetic content chunks can coexist with “streaming omitted” only when results say that real streaming/encoding/chunk boundaries remain omitted. Its resumed-entry composition still does not exercise the conversation loop, consistent with ADR-002 D4 and PLAN-003 §0.6.

### D8 — accept with corrections

P0 preservation, tiny P1 cases, P2 guard/calibration, short P3 gate, withheld process, long admission and T1 are in the right order. The guard now considers cgroup current/max/headroom and exclusive heavy execution, not host `MemAvailable`. A small read this round found **24 GiB max and approximately 9.93 GiB current**; that does not prove the earlier 10.5 GiB timestamp, and current usage remains unsuitable as permission to run a replay with other work active. No replay was run.

The plan must define margin, polling/termination threshold, treatment of unlimited `memory.max`, and guard warm-ups/profiling as well as scored runs. Monitoring is a conservative backstop, not a proof against a sudden allocation spike. All guard trips invalidate the result. The handoff's no-sweep/no-other-heavy-work prerequisite remains separate from this read-only review.

`a6abda4` is genuinely `de4b4f5`'s parent and contains the inefficient canonical builder, so it is a suitable historical regression control for that change. It also lacks `PortedWorld`; specify the E compatibility assembly without replacing its core (§D5). Calibrate both successful and failing verdicts with the final metadata-aware evaluator and the same short entry. The stored recent profiles show **2.00215 → 1.57268 GiB**, not 2.05 → 1.61; both stored “57” executions have **58** provider calls and **115** appended messages, including the synthetic terminal turn. They support the existence of a useful allocation difference, not a calibrated new 57-call gate or its exact final threshold. Pin the calibrated gate only after source fidelity, cutoff/counts, measurement scope and control rejection actually pass.

## 3. Claim audit

### 3.1 New host-log assumptions

The source log is `.motoko/logfile/session_1789244855221-63164319c7d765ff.jsonl`. Counts below are across the full stored file, not just r2.1.

| V2 input/claim | Verified evidence | Verdict |
|---|---|---|
| `thinking.finish_reason`, input/output usage, `tool_calls` | Present in all **684** `thinking` events; `tool_calls` is a count | **Verified**, with count/list distinction. |
| `thinking.cache_read_input_tokens` | Present in **681/684**, conditionally positive | **Verified as optional**, not universally present. |
| Cache-creation usage is not logged | None in this file; `thinking_usage_kvs` emits it when positive (`phase_vocab.ail:1082–1085`) | **False as a producer claim**; absence here is not a general missing field. |
| `stream_error_retry` | **8**, each has step/error/session metadata | **Verified**; no per-event run_id or full AIError is present. T0 refusing retries avoids needing to reconstruct that error. |
| `provider_call_prepared` fields | **693**, all have payload/system-prefix digest, model, message count and step | **Verified**; model is before API routing, and no per-event run_id exists. |
| `session_start` fields | **10 total**: 3 rpc banners with profile/extensions; 7 ledger banners with run_id/mode | **Present across distinct shapes**, not all fields on one shape. |
| The new data can be associated | Ordered ledger run banners precede requests; r2.1 banner exists | **Feasible with an explicit ordered association contract**; field equality on `(run, step)` alone is unavailable. |

This can be rechecked without execution by counting keys per event type; do not output conversation `task`/`text` contents as review evidence. The selected source run's first request is after its ledger banner; leading user input must already be in its seed.

### 3.2 New mechanisms and carried coordinate spot-checks

| Coordinate/mechanism | Verified disposition |
|---|---|
| `stub_step.ail:69` / `session.ail:1492–1505` | Existing sum and normalizer support the proposed additional `(Ports, WorldState)` variant shape. It is absent at HEAD. The session constructor import and frame helper also need updating. |
| `ledger_parity_dst.ail:378–412` | Correct frame contract/reference. `frame_ordinal0` is an exhaustive provider match; starting ordinal is before policy bootstrap. Final `pending` must be empty. |
| `ports.ail:618–622` | Correct ToolOutcome declaration. Status -1 is documented immediately above it. Failed/correlation constructors take records; outcomes are rendered to transcript errors rather than aborting. |
| `ports.ail:824`, `:957` | Correct model/tool signatures. Model argument is the API-routing result at this call site; model parameters/schemas are not passed through it. |
| Private canonical/chain copy | **Feasible with a pinned version**, including raw prefix hashing and images/raw-content chain framing. No implementation exists to audit. Cross-tests against known framing vectors must distinguish candidate imports and canonical projection from raw equality. |
| World observation log | `ports.ail:446` is `[Interaction]`; ordinary core can construct/replace it. No private append-only storage is specified. |
| `(review)` `session.ail:957` | Telemetry zeros verified; surrounding `:968–970` contradicts all-zero nudges/counts. |
| `(review)` `session.ail:1492–1495` | `Ported` uses an empty world, verified. |
| `(review)` `session.ail:2310–2325` | Policy reads env/base URL/headless/context values through ports, verified; recorded header is not a complete snapshot of those reads. |
| `(review)` `session.ail:2554–2608` | Continuation carries telemetry, artifacts, counts and nudges, verified. |
| `(review)` `session.ail:3485–3518` | Retry consumes an attempt but journals unchanged telemetry and no assistant append, verified. |
| `(review)` `stub_step.ail:89–90` | Scripted conversion zeroes both cache fields, verified. |
| `(review)` `phase_vocab.ail:275–300`, `:321–358` | Payload form normalizes make[1..20] and omits images; incremental chain uses raw content/image source/MIME, verified. |
| `session.ail:4014`, `:4860` | Existing ordinary/resumed traced entry signatures and normalization-before-policy behavior verified. Neither needs a new production export. |

The private evaluator copy is compatible with leaving ADR-003's production chain/writer/fold unchanged: it is an evaluation oracle, not a second production journal implementation. Adding the provider variant must preserve the existing default/live normalization and ordinal contract. The fixed frame semantics remain valid; helper coverage changes are still required.

### 3.3 Numbers, retractions and new causal claims

| Claim | Check/result |
|---|---|
| 694 messages; 1,170,593-byte default Python JSON seed; ~0.9 MB content | **Verified again:** 694; 1,170,593 bytes under `json.dumps(seed).encode()`; 903,364 UTF-8 content bytes. Units/serialization now honest. |
| Baseline/fix allocation and RSS figures in Context | **Agree with stored TSV and the prior independently decoded profiles.** GiB/MiB correction is accurate. Baseline/fix maximum allocation deviations 0.115%/0.279% are observations, not tolerance promises. |
| 300 unique digests; unique match at provider position 351 | **Verified again:** 300 replay events; the only matching live subsequence starts at zero-based 351 in 693 live requests; all 300 system-prefix hashes match. |
| 299 recorded turns plus one synthetic terminal call; 598 chain positions only | **Verified:** stored output contains 300 requests and 599 appended messages; the prototype's exact min-length checker excludes the terminal mismatch. V2 retracts the historical overclaim correctly, but its new exhaustion protocol needs different explicit accounting. |
| 1,806 result-matched candidate digests; 1,948 including two recent pairs | **Verified count:** nine `runs/fix_*.out` files total 1,806; two recent files add 58 + 84 = 142. Their corresponding parent files have the same digest sequences, as checked in v1. No basis for assigning the old tally to new source-faithful admission is implied. |
| Nine loaded extensions; large fixtures exist | **Correct retraction**; actual loaded-extension arrays have nine names. No hook-execution/cost share follows from that count. |
| 801 thinking deltas; 57 reasoning deltas; 693 requests | **Verified again**; correctly no streaming cost share is now inferred. |
| D8 recent control: 2.05 → 1.61 GiB | **Not supported by the named profiles:** `prefix_57.mprof` alloc_space = 2,149,792,369 bytes = **2.002150 GiB**; `fix_57.mprof` = 1,688,648,874 bytes = **1.572677 GiB**. Cite another profile/setup if these draft figures came from elsewhere. |
| D8 “57-call replay” | **Ambiguous historical naming:** both stored outputs have 58 calls, 115 appended messages, 57 native tool-call events; printed `steps=57` refers to recorded turns, followed by a synthetic call. |
| a6abda4 is the regression parent | **Verified** through `git show de4b4f5^`; its canonical builder is the nested version. Neither commit contains the proposed new provider variant. |
| The first after-edit run recompiles and therefore allocates 22.12 GiB | **Unverified causal explanation.** Stored logs show checks/dependency warning and the outlier; they do not establish its cause. Treat as a hypothesis. |
| memory.max 24 GiB, earlier current 10.5 GiB | **Max verified**: 25,769,803,776 bytes. This review sampled current at 10,663,694,336 bytes (~9.93 GiB); the earlier point-in-time value is not independently reconstructable. |

## Required changes for v3

1. **D1:** specify ordered run/spawn association, optional cache-field decoding under the producer version, and retract unavailable cache creation. Classify actual message starts/counts/nudges and leading user seed input. Distinguish valid cutoffs, genuine completion and fatal source refusals.
2. **D2/D8:** define the exact stopping protocol and expected outcome. Avoid an uncounted extra exhausted call; if sentinel/finalization overhead is measured, name/count it separately and weaken “up to cutoff” accordingly. Use nonretryable complete AIError/record-shaped tool constructors and preserve mismatches independently of candidate-returned state.
3. **D3:** distinguish logical versus API model names with trusted expected conversion and correct prefix hashing. Resolve the T0 excerpt requirement versus ParentAgreement's alternative metadata source. Add terminal/cutoff and pinned-input preflight checks.
4. **D3:** narrow the candidate class to the assumptions actually needed for recorded-response validity, including raw transient payload preservation; state how those assumptions are reviewed/checked. A canonical-projection pass alone cannot validate a materially changed image/make[N] request inside allowed core code.
5. **D5:** specify observation integrity or explicitly adopt a cooperative, independently reviewed trust model. Remove adversarial guarantees that file overlays/hashes do not establish. Disk isolation alone does not fix candidate-owned in-process logs.
6. **D5/D8:** specify trusted-region/compatibility assembly for the normalization arm while preserving candidate core in `session.ail`; record the assembled identity and demonstrate that C's modified code executes. Apply the same rule to historical a6abda4 control runs.
7. **D4/D8:** define the measurement process/phase, guard warm-up and profiling, and qualify the recompilation hypothesis. Correct recent control totals to the named profile evidence and recalibrate the final evaluator before pinning/rejecting the control.
8. **D6/D7:** carry actual settings/stopping scope/exposure into admission; clarify operator-input refusal removal at T2b and live transfer's separate scope at T3. Keep ADR-003 and ADR-002's existing journal/resume/frame debts unchanged.
