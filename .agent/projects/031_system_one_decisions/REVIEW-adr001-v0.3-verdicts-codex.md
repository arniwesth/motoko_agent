# Review: ADR-001 Extension-owned structured decisions (v0.3)

Reviewer: Codex, independent full review, 2026-09-20. This reviews the **working-tree v0.3**, not the v0.2 committed at HEAD. Branch `arniwesth/031-abi-8-0`; HEAD `2f3ee4d1e83feb677583924131ce08f7cb91b47a`; ABI `7.4`; AILANG `v0.33.0`, commit `ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a`, matching the lock. The reviewed file has 633 lines and SHA-256 `a78d505fe1685467276b2593fde0f17b473983b4c1f9fb5741e5635e78371ba1`. Final provenance and the post-write SHA check are below the appendix.

## 1. Architectural verdict and freeze readiness

**Retain the architecture; do not freeze v0.3.** Extension-owned preparation and interpretation, two invocation sites, explicit evidence limitations, nullary `Accept`, ordered execution, and separate query/policy identities remain sound. Host-mediated decision transport resolves F2's architectural contradiction with the journal's single writer. Six context views are a reasonable ABI choice, and the D2 port membership table is correctly derived from the actual rows.

**F1 is only partially resolved.** Removing ports prevents a callback from successfully invoking an absent supplied port. It does not make the proposed compile-time rejection gate true, and narrow context records do not make effect rows merely documentation. Fresh scratch probes against an **imported** sum found:

- A callback receiving a data-only context can call the nonexistent `ctx.ports.emit(ctx.name)`, pass `ailang check`, and fail at runtime with `record has no field: ports`. Adding `! {}` does not repair this. A named top-level callback is rejected correctly.
- An annotated `{FS}` callback can likewise call a nonexistent `clock_now` in its restricted ports record and pass checking; it fails at runtime.
- An annotated `{FS}` callback, constructed through a local record under an effectful registration function, can perform `println` at invocation despite its context supplying only an FS port. Matching direct-constructor and named-function controls reject it. This reproduces ADR-017's record-field hole with a restricted context.

These are different results: absent-port calls crash, while the record-field case actually performs an out-of-row effect. **No successful ambient-effect escape from the rowless slot was demonstrated**; the direct, captured, and local-record pure-slot attempts in the appendix were rejected. The evidence therefore supports restricted supplied authority, not D2's general structural-purity claim. The second review's recommendation was too broad on this point too.

There are also unresolved policy-epoch and budget-scope rules on resume. These are decisions about behavior, not requests to implement the whole feature before accepting an ADR. Eight new findings follow, **N23–N30**. Missing implementation evidence is identified separately, not counted as a new finding.

## 2. Remaining freeze blockers

| Blocker | Decision or evidence needed | References |
|---|---|---|
| **F1 remains partial: N23** | Narrow the guarantee to supplied ports; define and prove the supported registration forms. Annotation alone is insufficient. Either use an upstream fix or enforce a checked, fail-closed construction discipline that covers indirect bindings. Replace the false compile-rejection claim with a gate that actually passes for that discipline. | D2; freeze 2 and 8; Appendix A |
| **Final callback rows remain open: N24** | Close both row choices before freezing signatures: add `Trace` to `ToolProvider`; retain `{FS}` for `ExitIntent`/`WorkInFlight`. Compile the resulting contexts and helper projections. | D2 table; D7 ABI row; Q-A |
| **Resume policy comparison: N26** | Compare with the latest effective policy snapshot, specify profile/registry migration behavior, and retain the original effective allowance independently of changed descriptor declarations. | D5–D6; ADR-003 D5 |
| **Accounting scope: N28** | Define the relationship between the persistent decision allowance and ADR-003's fresh per-run cost allowance. State the admission equation and which amounts enter a resumed run's totals. | D5; ADR-003 D1/D6 |
| **Incompatible acceptance gates: N30** | Reconcile the deliberately red compiler row with release G5e's required green target. State whether a fixed compiler is a release prerequisite or an explicitly classified known failure is allowed. | Freeze 8; release G5e |
| **Evidence 1–3 is not supplied** | After the above decisions, provide accepted signatures, actual compiled ABI-8 examples for both consumers, context/construction probes, updated inventories, and strict mismatch/offline-experiment evidence. | Freeze 1–3 |

F2's **transport choice is resolved**. N25 identifies the host implementation contract required to deliver it; it does not require adding `Net` or `FS` to the child port. N27 and N29 must be specified in the implementation plan before their affected work begins, and tested before live enforcement.

## 3. New findings (N23 onward)

### N23. Restricted records do not establish the stated compiler or effect guarantees

**Evidence.** Appendix A's `missingport`, `missingannot`, and `fs_missing` check successfully despite absent fields. `fs_smuggle` both checks and prints `IO OUTSIDE FS VIEW` during callback invocation. `fs_direct_io` and `fs_named_io`, with the same enclosing IO allowance, reject the corresponding effect. The latter is the limitation already documented in 017 ADR-001, now tested against the proposed context mechanism. A context argument also does not erase imported functions or values in a closure's lexical scope.

**Consequence.** Freeze 2(a) is false on the pin, while 2(b) can pass merely because a missing-field exception prevents execution. That is not a successful purity/type-safety proof. The annotation-or-named rule cannot by itself reject `missingannot`, and a row annotation on a record-stored callback does not prevent `fs_smuggle`. Pure-slot coverage cannot be granted just by noticing a context type name.

**Decision needed.** Keep the views, but state their actual guarantee. Require named top-level bodies where inference is relied upon, or an equivalently demonstrated registration checker; resolve and inspect indirect bindings and reject unresolved construction. Make that discipline part of freeze evidence, not only a later live-enforcement task. Keep distinct tests for missing authority, unexpected ambient effects, and ordinary successful callbacks. Do not claim this is a sandbox against arbitrary extension code.

### N24. Migration is more than changing callback parameter types

**Evidence.** AILANG records are closed: Appendix A's `helper` fails when a restricted context is passed to a helper expecting the old full record. In production, compose's interceptor passes `ctx.ports` to `check_snippet`, `run_snippet`, and `remove_if_file`, whose parameters are `ExtPorts` (`compose.ail:312,326,921,1018`). `InterceptCtx` removes fields from that record. Repetition has common `ExtCtx` helpers across pure policy and Process judge paths; compaction-ai passes `ExtCtx` through its summarization/compaction chain. Inferring a named function's effects does not infer a new structural parameter type for its callees.

**Consequence.** D2's “the change for them is the parameter type” understates the migration. Calls can use only permitted fields and still fail type checking after the signature change. Inventing dummy forbidden ports to make old helpers compile would defeat the design.

**Decision needed.** Close the two rows now; price helper signatures, explicit projections and fixtures in the plan. Prefer data-only helper inputs or the smallest shared ports record. Retain six external views; do not restore full `ExtCtx` to narrow slots. Q-A gives the package-level migration assessment.

### N25. The existing host journal path is best-effort, not a write-success barrier

**Evidence.** `SessionJournal.append` catches write errors and returns `null` (`session-journal.ts:367`); `record` returns a count; `SessionLogger.log` discards that count (`session-logger.ts:404`). `RuntimeProcess.onEvent` returns `void`. Live `sendWakeReply` writes stdin without first journaling the observation (`runtime-process.ts:1287`). Wake observation logging normally occurs after the child has consumed it. The suspended-child wake path is different and also must not be copied as a decision transaction.

**Consequence.** Merely routing new events through today's logger would allow a provider call after a failed reservation append, or interpretation after a failed observation append. A normal successful synchronous append does support the process-crash ordering D5 needs; the current callback interface cannot certify its success.

**Decision needed.** Give the decision service a success-returning journal operation. Failed reservation write means no dispatch; failed observation write means no normal reply and retention of the reservation; journal failure is a host control failure, never interpreter-visible `Unavailable`. Decide the fail-stop behavior for vote-application writes and preserve the expressly accepted emission-to-write crash window. Define durability as the intended child/host process-crash guarantee; if machine/power-loss durability is intended, specify syncing separately. Do not imply that `appendFileSync` supplies that stronger guarantee. Include duplicate-request and late-reply handling, and a single application entry that avoids double-folding the ordinary history/control event.

### N26. A descriptor comparison against the original header becomes wrong after force

**Evidence.** D6 compares against the resume header, but overrides append policy snapshots. Consider header P0, a forced resume to P1, then another ordinary resume with P1: comparing with P0 rejects the unchanged current policy. Conversely, returning to P0 could pass without acknowledging the change away from P1. Existing `resume_refusal` only compares extension/prompt digests under the same profile (`journal.ail:1796`); `plan_resume` also accommodates an accepted profile switch. Copying that behavior blindly would bypass the new policy check on precisely the migrations D5 says must retain allowances.

**Consequence.** “Append a snapshot” is insufficient unless the fold makes it authoritative for subsequent compatibility checks. Changed descriptor limits also cannot silently recompute a larger effective allowance after force: D5 says that allowance is fixed for the identity. Registered owners currently include the installation index (`types.ail:1275`; runtime registration), so reordering needs an explicit mapping too.

**Decision needed.** Define an effective policy epoch folded from the header and subsequent snapshots. Compare against that epoch, including across profile changes. Persist used counts, the fixed effective allowance, and retained spend independently of the latest descriptor. Define explicit identity migration and whether `--resume-force` authorizes it; a waived mismatch must not manufacture new allowances. Pin P0 → forced P1 → ordinary P1, rollback, descriptor-limit changes, reorder, removal/reinstall and profile-switch cases.

### N27. Reading schema 1 is decided; continuing that journal as schema 2 is not

**Evidence.** D7 correctly permits a pre-feature journal to start with empty decision state. The host's `adopt` keeps the existing header, and `writeHeader` does nothing for a nonempty file (`session-journal.ts:288,403`). ADR-003 allows one special in-place rewrite to complete the initial header, not an upgrade rewrite. Changing the schema constant therefore does not promote an adopted journal.

**Consequence.** Appending decision entries below a schema-1 header yields a mixed file. An old reader may fail at an unknown entry rather than the promised header-level `Schema` refusal. More seriously, an implementation that interprets “schema 1 means empty decision state” on every resume could reset state accumulated after the upgrade.

**Decision needed.** Specify a crash-safe transition: for example a permitted atomic header promotion preserving the historical body, or an explicitly versioned successor/transition format. Amend ADR-003's rewrite rule if necessary. Zero-initialize only genuinely pre-feature history, then fold every decision record. Preserve historical fixtures as historical bytes and add an upgraded-session fixture that resumes twice. This is a persisted-format plan decision, not a reason to reject the strict-superset reading policy.

### N28. Persistent decision spend and fresh per-run totals have different lifetimes

**Evidence.** D5 reserves against a “session spend allowance,” retains decision spend across resume, and feeds conservative charges into `totals.cost_millicents`. ADR-003 explicitly resets per-run totals on resume and grants a fresh per-turn allowance; `c2_state_from_continuation` documents why carrying totals would change that policy (`session.ail:2607–2652`). `call_model_or_fail` checks those totals only when `cost_metered` is true (`step_machine.ail:110–115`).

**Consequence.** Carrying the whole ledger into each new run would make old decision charges consume a fresh run's cap repeatedly, while old ordinary-model charges reset. Carrying nothing could refund interrupted reservations against the very allowance intended to contain them. Simply assigning the ledger total to the existing integer does not define correct admission or reporting. A metered decision backend alongside an unmetered ordinary-model route also cannot rely solely on the current step-machine predicate.

**Decision needed.** Choose and name both scopes. A compatible option is a persistent decision allowance plus the existing per-run allowance, with each reservation attributed to its originating run and with an explicit rule for outstanding cross-run debt. Alternatively change the ordinary cap to session scope and acknowledge the ADR-003 policy change. State one admission equation, reconciliation deltas, resumed totals, and the behavior when ordinary model cost is unmetered. Count each charge once; never refund unknown spend merely because a run ended.

### N29. The TypeScript adapter needs a validation contract and explicit retry settings

**Evidence.** TS must validate provider floats and convert them before recording; AILANG must strictly decode and validate the resulting integer observation. These are two trust boundaries, although they need not implement the same float conversion twice. The official SDK's choice schema only checks numeric shape, not D3's domains, coverage, sum or rounding. Its decision transport currently defaults to backoff, retryable connection errors/5xx, a one-hour retry budget, and an unset timeout when none is supplied. [Choice schema](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionschoiceanswer.ts), [transport](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/funcs/alphaDecisionsCreate.ts).

**Consequence.** Using SDK validation/defaults would violate the decided whole-response checks, one-attempt transport policy and bounded deadline, and could incur several upstream charges behind one reservation. Independently normalizing again in the child would create rounding drift.

**Decision needed.** Make the host adapter the sole raw-number normalizer; the child validates the canonical ABI observation without renormalization. Share versioned fixtures/schema constraints across host, child codec, journal fold and replay. Cover finite numbers, negative usage, missing optionals, duplicate/extra/missing answers, boundary half-rounding, distribution tolerance and remainder ties. Disable SDK retries explicitly and impose an end-to-end deadline. Keep internal invocation identity separate from the outbound provider projection; D6's journal identity contains host IDs even though D3's outbound request omits them. Adapter contract versions must change with semantic normalization changes.

### N30. The compiler gate cannot both stay red and satisfy release G5e

**Evidence.** Freeze item 8 says the trigger-shape row stays red until the upstream fix; release G5e requires `make declared_vs_performed` green. On the pinned compiler the defect remains. Item 8 also arrives only before live enforcement, even though the supported registration discipline is part of the purity evidence needed before freezing the ABI.

**Consequence.** The documents describe incompatible acceptance criteria unless “red row” has an explicitly different meaning from a failing target. An implementer cannot infer whether to wait for a compiler release, waive G5e, or convert a failure into an expected limitation.

**Decision needed.** State the acceptance policy in both records. Either require a fixed pinned compiler, or distinguish an expected compiler limitation from a passing enforcement gate and prove the separately enforced construction discipline. Do not silently call a successful exploit a successful safety test. Move whatever discipline freeze item 2 relies on before freeze. Keep the original unrestricted trigger and the new restricted-context/indirect-construction regressions separately visible.

## 4. Resolution tables

“Resolved” below means a coherent architectural decision, not that an unimplemented feature has passed its gates.

| Item | Verdict | What was verified |
|---|---|---|
| **F1 / N14** purity | **Partial** | Missing supplied ports close the original runtime port route, but N23 falsifies the compile gate and broader per-row guarantee. Imported-sum scratch probes, NOTE-001, ADR-017 and actual callback registrations. |
| **F2 / N15** one-writer durability | **Resolved as architecture** | D5 puts reservation, external call and observation in the host, with the child blocked until reply. Actual stdout/stdin wake transport supports this. N25 is required new journal failure handling; wake does not already provide decision durability. |
| **N16** recorded preflight inputs | **Resolved, with integration limits** | D6 records binding resolution, maximum charge and effective limits. ADR-004 D1 supports explicit recorded configuration, but its T0 evaluator does not implement these new inputs. N26/N28 must define their resumed values. |
| **N17** descriptor resume | **Partial** | Refuse/force is chosen and kind-only digest insufficiency is real. Latest-snapshot authority and profile/identity migration remain undefined: N26. |
| **N18** evidence | **Resolved** | `ToolCompleted.exit_code == -1` is unknown; current tool fold consumes the typed outcome before rendering. D3 adds accumulation and explicitly incomplete resumed windows. DP7's substring heuristic is correctly called uncertain. |
| **N19** wire identifiers | **Resolved** | D3 omits optional session/user/trace fields. SDK still makes them optional. Keep outbound projection distinct from the internally stamped request identity (N29). |
| **N20** historical schema 1 | **Resolved for reading; partial for continuation** | Empty decision state is truthful for pre-feature history; no fabricated typed tool window. N27 concerns writing after that read, not the soundness of accepting old history. |
| **N21** `/5` rationale | **Resolved** | `dst_interaction.ail:96–110` distinguishes identity additions; `dst_program.ail:117–150` explains the wake payload bump. D7 now attributes `/5` to payload/scripts. |
| **N22** witness helper | **Resolved** | Tool leaves advance in `tool_phase.ail`; `session.ail:3623,3692–3694` witnesses returned worlds/traces; the private helper is at `:4572`. Extraction is optional. |

The first response table was also checked, rather than inherited as accepted:

| First-review claims | Verdict and basis |
|---|---|
| **N1 execution; N2 multiplicity** | Sound. Both proposed leaf sites have core Ports/world access; current normalization checks kind, so family normalization is new required work. Runtime must keep attribution and successor state through the cursor. |
| **N3 evidence; N4 hidden config** | Sound as disclosure contracts. The three fields address real gaps; immutable capture disclosure remains a conformance duty, not something the host can prove. N23 prevents upgrading that statement into a general effect guarantee. |
| **N5 identity split; N6 nullary acceptance** | Sound. Strict whole-run replay must check interpretation policy; offline reinterpretation cannot reuse a changed trajectory. Current production acceptors pass through the candidate; the runtime synthetic replacement case must change. |
| **N7 accounting** | Partial: reservation and propagation direction are right; lifetime/admission semantics need N28. `ext_ai_step` still discards usage, correctly disclosed as separate debt. |
| **N8 host state; N9 cancellation/resume** | Sound direction with N25–N28. Counters outside artifacts and a single application entry are appropriate. Process death is not a provider abstention; no automatic replay of interrupted work. |
| **N10 all atoms; N12 events** | Resolved. The real collectors run every atom before merging. D6 records skips, immediate abstentions, shadow and losing votes as well as selected applications. |
| **N11 compatibility** | Partial: surfaces and version responsibilities are explicit; N24/N27 complete migration mechanics. Unknown world identity tags must not use the existing permissive fallback. |
| **N13 provider evidence** | Independently strengthened: the SDK endpoint/request shape and optional choice fields were verified again. The Jev model page now resolves and names `typesafe/jev-1.13`. This confirms a published route page, not successful authorized inference or calibration. [Model page](https://openrouter.ai/typesafe/jev-1.13), [request type](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionsrequest.ts). |

## 5. Explicit answers to Q-A, Q-B and Q-C

### Q-A. Context views, rows and migration

The real `ExtPorts` inventory is ten fields: `ai_step` has `{AI, IO, Trace}`; `tool_handle` has `{IO, Process, FS}`; six filesystem fields have `{FS}`; `clock_now` has `{Clock}`; `env_get` has `{Env}` and no world threading. Taking row subsets gives exactly:

| Context | Admitted fields | World | Assessment |
|---|---|---|---|
| `PureCtx` | none | absent | Right for the three existing rowless context slots and both new callbacks. |
| `ProcessCtx` | none | present | No current port has row `{Process}` alone. The legacy judge still returns `FinalizeOutcome.next_state` and can perform ambient Process effects. |
| `FsCtx` | `file_read`, `file_write`, `file_remove`, `path_stat`, `dir_list`, `dir_make` | present | Correct; no clock. Herdr's two FS renderers only use `file_read`, at `herdr.ail:1935,1990`. No demonstrated reason to widen them. |
| `AiCtx` | `ai_step` | present | Correct for `Compactor`, including structural compaction's effect-free body in that slot. |
| `InterceptCtx` | six FS fields, `tool_handle`, `clock_now` | present | Correct for compose's interceptor; helper record signatures need migration. |
| `ProviderCtx` | all except `ai_step` under today's row; all ten after adding `Trace` | present | Add `Trace` in 8.0. The slot already admits AI; excluding the world's existing AI port encourages the ambient path and is an accidental row mismatch. This does not solve existing AI-usage accounting. |

`DescribeTools` is the exception to “every callback receives a context”: its unchanged argument is `()`. Keep it explicit. Six is the appropriate number of distinct supplied-authority views here. Two types (`PureCtx` plus full `ExtCtx`) would reintroduce the wrong-port route for narrow effectful slots. Reuse a common data projection and exported constructors internally; do not add dummy ports. Keep `ProcessCtx` distinct from `PureCtx` because of its world-carrying outcomes. The constructor stability promise should cover every exported context view, not just literals named `ExtCtx`.

All eighteen `register.ail` files were read, including registrations delegated into package implementations and compose's capability list. The nineteenth ABI-dependent package is conformance. **No currently registered body was found to require a removed port after the recommended provider row choice.** That is a source-level feasibility judgment, not a claim that ABI-8 packages compile today. Named-function row inference is confirmed by the negative controls; it does not establish helper compatibility or validate every indirect lambda.

| Package(s) | Migration assessment |
|---|---|
| a2a, mcp | Provider callbacks and outcome/world fixtures; small context migration. `DescribeTools` unchanged. |
| exa-search, ailang-docs | Pure prompt and provider signatures, delegated helper signatures; registration-time FS/Process work remains outside the hook. |
| agentcli | Provider context plus `ExtPorts` helpers for lock read/write/remove. Adding provider `Trace` allows the full existing ports view; update provider wrapper row annotations too. A smaller helper view is also valid. |
| omnigraph, microrag, scratchpad | Separate pure prompt/policy contexts from provider context; migrate handler/helper and test types. Scratchpad's core special execution path also consumes the full host context and must not be accidentally narrowed. |
| compose | Largest cross-view helper migration: pure policy/prompt, provider, interceptor, shared data helpers and shared ports helpers. `compose.ail:1110` must remain a registered pure policy; the unused exported `on_tool_policy` with an Env row is not that registration. |
| context-mode | Split prompt/policy, provider and Process finalize chains. Its finalize function performs Process work directly, so dropping ports is feasible. |
| compaction-ai, compaction-structural | `AiCtx` throughout context-consuming helper chains and fixtures. AI compaction needs exactly `ai_step`; structural compaction does not need a broader view. |
| decision-framework | Pure prompt context; cached/config-derived content remains registration data. |
| empty-stop-guard, progress-contract-guard | Process finalize context, world-bearing wrapper and nullary-accept migration where applicable. Their decision logic needs data only. |
| repetition-guard | Both `PureCtx` policy and `ProcessCtx` judge; shared history helpers need a common data input/projection. Migrate candidate-pass-through acceptance. |
| herdr | Pure prompt/policy, Provider context, and two FS renderers. Keep `{FS}`; no clock use in the FS bodies. Provider helpers and fixtures need their appropriate views. |
| test-dummy, conformance | Multiple slot-specific callback/fixture types, no-op constructors, probes and nullary `Accept`. Conformance is migration work even without a `register.ail`. |

The two registry-only packages differ materially. `fmt@0.4.2` still imports ABI 2.2.0's `ExtensionHooks` record and returns bare handling decisions: it needs the earlier record-to-capability and world-outcome migration as well as 8.0 contexts, or an explicit legacy-only disposition. Its real work fits Provider FS/Process access. `typefix-agent@0.1.0` is a standalone pure A2A service: its manifest has **no ABI dependency**, and its exported handler has no extension context. It needs service compatibility/disposition, not an invented ABI-8 callback rewrite. These are read-only checks of current registry sources, not builds or a pinned release audit. [fmt manifest](https://github.com/sunholo-data/ailang-packages/blob/main/packages/motoko-ext-fmt/ailang.toml), [fmt registration](https://github.com/sunholo-data/ailang-packages/blob/main/packages/motoko-ext-fmt/register.ail), [typefix manifest](https://github.com/sunholo-data/ailang-packages/blob/main/packages/motoko-ext-typefix-agent/ailang.toml), [typefix handler](https://github.com/sunholo-data/ailang-packages/blob/main/packages/motoko-ext-typefix-agent/main.ail).

### Q-B. Host transport, validation and `{IO}`

**Implementable, with a new decision service and journal-success interface. `{IO}` is the correct child row for stdout/stdin transport.** The child's live wake adapter emits the request and then calls `readLine()` (`src/core/test/stub_step.ail:227–332`). `RuntimeProcess` routes the request to `onWakeRequest`, installs `wake-waiter` observers, and eventually writes a correlated reply to stdin. The waiter reads/subscribes/re-reads answer files, observes Herdr state, or uses timers; it does not own journal writes. `env-server.ts` provides HTTP execution/scratchpad/environment facilities and is not the wake/journal service.

A decision exchange should use that transport shape, with a separate request/reply discriminator, active invocation tracking and host deadline. It must not copy the wake semantics that consume user input as a wake, ignore unrelated lines, or intentionally reissue waits. Queue or explicitly handle user/model-change commands while the decision read owns stdin. A stale result may settle a charge if the chosen contract permits, but must never reply to or apply a new invocation.

The TUI host already owns the leased `SessionJournal` and gives it to the logger (`index.ts` initialization and `session-logger.ts`). Inject a decision service backed by that same writer. The order must be successful reservation append → one provider attempt → host normalization → successful observation append → child reply. No second journal writer is necessary. Wake's current live reply precedes the child's observation event; it is a blocking-transport precedent, not evidence for that new ordering. N25 supplies the failure paths.

TS HTTP/credentials/clock/FS activity does not widen the AILANG wire port's row. An HTTP call made by the child to `env-server` would require a different row, so the plan must retain the stated stdio exchange. Scripted/replay adapters can inhabit the `{IO}` function type without performing IO; keep the actual query leaf visible to the inventory. Credential separation applies to the decision adapter: today's child still receives credentials for ordinary model calls, which D5 intentionally leaves child-side.

There is necessarily shared validation of the integer ABI at multiple trust boundaries; there need not be two float normalizers. Use the split and cross-language vectors in N29. The host must reject malformed request wire data before provider dispatch; `parseAgentEventLine`'s current object/type cast is not adequate decision-request validation.

### Q-C. Cross-ADR consistency and resumed state

**ADR-003:** a new `Descriptor` refusal and force override are coherent extensions of the compatibility set. They require an explicit amendment to D5 and a folded current policy (N26). Force must continue to leave workdir/lease/strict decoding barriers intact. A profile switch may reset extension artifacts under ADR-003, but cannot reset the new host ledger/counters. The journal fold, in-process continuation and new-process resume all need the same retained host decision state; putting it only in the journal leaves in-process suspension vulnerable to a reset.

**Schema 1:** strict-superset reading is a justified correction to v0.2. Old sessions really did make zero decision calls, and an incomplete typed evidence window is honest. It reverses ADR-003's literal “only schema 1” decoder rule through a new versioned reader; it does not permit unknown future schemas or unknown entries. Choose the write transition in N27. Do not initialize a post-upgrade session's ledger from its old header version alone.

**ADR-004:** D1's explicit recorded configuration is the right principle, not an existing general-purpose decision manifest. Its admitted T0 profile has an empty extension registry, prescribed environment inputs and a disabled cost cap. It does not establish strict replay of decision atoms, policy snapshots or admission. Adding the new port/world/program shape and journal schema touches its evaluation basis; D5 explicitly treats protected definitions and schema changes as basis changes requiring refreshed evidence. Coordinate that separately without modifying its evaluator worktree in this review. Record all admission-relevant configuration, including size/count/deadline limits, once per effective policy/run and use the recorded values during strict replay.

**Accounting:** ADR-003's reset totals are an intentional policy, not incidental code. D5 must explicitly reconcile them with retained reservations (N28). Retaining only intervention counts is insufficient; dropping outstanding reservations refunds uncertain spend. Conversely, carrying a lifetime decision subtotal into a fresh run's ordinary cost meter without a scope rule changes established behavior.

## 6. D1–D7 assessment

| Decision | Assessment |
|---|---|
| **D1 ownership** | Accept. Questions, evidence selection, thresholds and feedback stay extension policy; transport/admission/persistence stay host concerns. TypeScript transport does not imply TypeScript ownership of the guard's policy. |
| **D2 callbacks and contexts** | Accept the two positional variants, one query per invocation and family multiplicity. Correct the enforcement claim (N23), close rows and account for helpers (N24). Immutable capture disclosure is necessary and explicitly limited. |
| **D3 observations/evidence** | Accept the provider-independent integers, absence, whole-response validation and evidence provenance. Verification unavailable is uncertain, not pass/fail. The native typed tool result must be captured before rendering; do not reinterpret arbitrary result strings as command exits. Define validation ownership as N29 requires. |
| **D4 execution/merges** | Accept. Actual merges are first feedback/otherwise acceptance and first Deny/otherwise last Pending/otherwise any Allow. Collectors run all atoms. Both call sites have the required core Ports; the candidate and tool paths must propagate world, ledger deltas and attribution, including losing votes and pending approval. Preserve the existing DP7/open-wait order and the original candidate with nullary Accept. |
| **D5 bounds/durability** | Accept host-mediated transport and conservative unknown-charge reservations. Correct budget lifetime ambiguity (N28); implement N25's success barriers. A child emission is intentionally not an acknowledged application transaction; retain that limitation explicitly. |
| **D6 recording/identity** | Accept separate query identity, policy snapshot and response metadata; strict versus offline semantics are sound. Complete effective-policy resume semantics (N26). Preflight refusal must remain zero port reads; each admitted query advances once, including invalid provider responses/timeouts. |
| **D7 migrations** | Accept the ABI/program/journal/event separation and historical fixture preservation. Complete helper/context migration and schema continuation (N24/N27). Widen scanners to understand the new ports-view receiver types; `ext_call_inventory` currently recognizes `ExtPorts` by name. Reconcile enforcement gates (N30). |

Freeze-evidence audit:

| Item | Review result |
|---|---|
| **1** accepted contract review | Conditional acceptance only; blockers above remain. |
| **2** context/purity and compiled consumers | Not met. The minimal imported-type probes disprove part (a); they are not compiled ABI-8 consumers. Inventories must recognize all view types and indirect registration forms. A missing-field crash must be reported as such. |
| **3** extension-only changes/strict mismatch/offline separation | Correct requirement; no implementing artifacts or results provided. Keep question changes, interpretation-only changes and changed trajectory tests distinct. |
| **4** parity, propagation, occurrences, strict replay | Good implementation obligations. Include paid losing votes, multiple calls in a batch and approval continuation; no skipped successor worlds. |
| **5** evidence and crash matrix | Expand with journal write failure, schema upgrade interrupted/repeated resume, P0/P1 policy epochs and cross-run reservations. The accepted application emission window remains distinct from a failed reservation barrier. |
| **6** composition and non-resetting limits | Correct; include in-process suspension, profile reorder/removal and shadow queries consuming spend but no interventions. |
| **7** format migration | Correct; N27 supplies the missing transition decision, and ADR-004 requires a separate basis refresh. |
| **8** annotation rule and red regression | Insufficient and inconsistent as written: N23/N30. Annotation does not catch all measured restricted-context failures. |

The D7 migration table is directionally complete, but “core interfaces” must include both continuation lifetimes and host writer results; “extensions/tooling” must include helper record types and view-aware inventories; “journal 1 → 2” needs an actual transition protocol. `/5` should preserve older decode semantics as well as fixture bytes, and reject malformed new decision payloads rather than defaulting them to empty state. No need was found for a public `ExtPorts.decision_query` field.

## 7. Before freeze, before the plan, and afterwards

**Before freeze:** correct and prove D2's enforcement boundary (N23); settle provider Trace/FS Clock choices and the exported context-constructor policy (N24); decide effective policy epochs and allowance identity (N26); settle cost lifetimes (N28); reconcile release gates (N30). Then satisfy evidence 1–3 with actual contract artifacts. This review does not substitute minimal language probes for those artifacts.

**Before the affected implementation plan is approved:** specify the success-returning host journal operations and host/child failure protocol (N25), schema upgrade/append protocol (N27), and validation/wire/retry/deadline contract (N29). Enumerate helper and fixture migrations across the nineteen ABI-dependent packages, disposition the two registry-only packages accurately, and schedule the ADR-003 amendments and ADR-004 basis refresh. These are concrete plan inputs, not further ABI variants.

**During implementation, before live enforcement:** run the corrected freeze/release checks and evidence 4–8; exercise all crash and resume boundaries, deterministic admission, losing-vote worlds, pending restrictions, no-network strict replay, unknown tags, and accounting reconciliation. Shadow remains charged. Do not infer correctness from a schema bump or matching query digest alone.

**After that:** provider limits and versions, guard wording/thresholds and live quality evaluation can evolve under recorded policy versions. Performance, calibration and false-objection rates need measurements separate from replay fidelity. Existing extension AI-spend loss remains separately disclosed debt.

## 8. Method and limitations

I read the named handoff first and grounded the review before reading v0.3. The working-tree ADR, both complete prior reviews, NOTE-001, the September 18 handoff, release ADR, 017 ABI ADR and 013 ADRs 002/003/004 were read. The required ABI records/rows/outcomes, extension dispatchers/merges/digest, journal headers/refusals/resume path, Ports wake/tool outcomes, named session sections, full tool phase and step machine, and identity/program notes were inspected. `runtime-process.ts` and `env-server.ts` were read in full; journal/logger/index and waiter implementation paths were followed. All package registrations and compose's capability list were read, with delegated binding/helper bodies inspected where relevant.

Grounding confirmed that tracked `src/core`, `packages`, `tools`, `scripts` and `Makefile` are unchanged between `2062605` and HEAD and have no working-tree tracked diff. This is not a claim about untracked files: untracked scripts and other unrelated working-tree changes already existed. Committed HEAD contains the 491-line v0.2 with SHA-256 `53956e5d25e8282b1f94d23f2f9f1ae4d9433ef90e0d482d165b7b5b1ce3258a`. The working-tree delta weighted attention but did not bound scope. Historical source-inventory counts were not re-certified.

Twenty-one fresh compiler probes were run entirely in `/tmp/adr001-v03-codex-5gqurul8`; sources and captured results follow. They use a separate imported type module to avoid the known local-sum confound. The FS context is a reduced structural analogue, not a claim to have implemented ABI 8.0. Successful probes were executed with explicit capabilities; rejected probes were not run. The only performed effect in the exploit is harmless stdout output. No provider calls, project Make targets, host integration tests, migrated-package builds or full six-view gate were run. Existing targets can generate files, so they were not run against the read-only tree. Full `session.ail`, `ports.ail`, `journal.ail`, all extension implementation modules and all TUI neighbors were not read line-for-line; the requested sections and dependency paths were.

Public SDK and registry source checks were read-only on 2026-09-20; cited `main` URLs are mutable, not release pins. No paid inference was attempted. Two unrelated untracked files appeared during review (`013_core_architecture_for_dst/DIRECTIVE-p23-a37-state-and-detector.md` and `detect-settle.py`); I did not create or modify them. The reviewed ADR hash and HEAD remained stable. No subagents were used. No commits were made. No Herdr command was invoked and pane `w3:p1` and `/workspaces/motoko_agent-eval` were not operated on. The sole repository file written by this review is this output file; compiler sources/results and draft assembly live outside the repository.

## Appendix A. Compiler probes and exact results

These are language-mechanism probes, not replacements for the ADR's full ABI/context/consumer evidence. Every case imports its sum from `repro/types.ail`. The name `Pure` below is a constructor, not an unchecked local sum or a `pure func` assertion.

Commands, from the scratch root:

```sh
ailang check repro/<case>.ail
# Only after a successful check:
ailang run --caps IO --entry main repro/<pure-case>.ail
ailang run --caps IO,FS --entry main repro/<fs-case>.ail
```

`ailang.toml`:

```toml
[package]
name = "local/repro"
version = "0.1.0"
edition = "1"
module_prefix = "repro"
ailang = ">=0.33.0"

[dependencies]
```

`repro/types.ail` (the final two declarations were added for the FS batch; the first fourteen probes used the first three lines):

```ailang
module repro/types
export type PureCtx = { name: string }
export type Slot = Pure((PureCtx) -> int)
export type FsCtx = { name: string, world: int, ports: { file_read: (int, string) -> string ! {FS} } }
export type FsSlot = Fs((FsCtx) -> int ! {FS})
```

### A.1 Result matrix

| Case | Check exit | Run exit | Observed result |
|---|---:|---:|---|
| `clean` | 0 | 0 | Clean result, no callback effect. |
| `direct` | 1 | — | Rejected; diagnostic below. |
| `named` | 1 | — | Rejected; diagnostic below. |
| `captured` | 1 | — | Rejected; diagnostic below. |
| `localrecord` | 1 | — | Rejected; diagnostic below. |
| `missingport` | 0 | 1 | Missing-field runtime failure. |
| `helper` | 1 | — | Rejected; diagnostic below. |
| `capturednamed` | 1 | — | Rejected; diagnostic below. |
| `capturedannot` | 1 | — | Rejected; diagnostic below. |
| `missingnamed` | 1 | — | Rejected; diagnostic below. |
| `missingannot` | 0 | 1 | Missing-field runtime failure. |
| `missingworld` | 1 | — | Rejected; diagnostic below. |
| `localunannot` | 1 | — | Rejected; diagnostic below. |
| `localannot` | 1 | — | Rejected; diagnostic below. |
| `fs_missing` | 0 | 1 | Missing-field runtime failure. |
| `fs_smuggle` | 0 | 0 | **Out-of-row IO performed during invocation.** |
| `fs_direct` | 1 | — | Rejected; diagnostic below. |
| `fs_named` | 1 | — | Rejected; diagnostic below. |
| `fs_direct_io` | 1 | — | Rejected; diagnostic below. |
| `fs_named_io` | 1 | — | Rejected; diagnostic below. |
| `fs_smuggle_norow` | 1 | — | Rejected; diagnostic below. |

The `helper` case is a closed-record migration control. `fs_direct_io` and `fs_named_io` match the enclosing IO allowance of `fs_smuggle`; both reject, isolating indirect record construction. `fs_smuggle_norow` shows that removing the registration allowance changes the check result. Failed pure-slot escape attempts are included rather than extrapolating the FS result to rowless slots.

### A.2 Exact sources and captured outputs

#### Probe 1: `clean`

```ailang
module repro/clean
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/clean.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run` exit 0:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/clean.ail
result=1
```

#### Probe 2: `direct`

```ailang
module repro/direct
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/direct.ail...
→ Effect checking...
Error: type error in repro/direct (decl 0): type unification failed at [function application at repro/direct.ail:4:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 3: `named`

```ailang
module repro/named
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/named.ail...
→ Effect checking...
Error: type error in repro/named (decl 1): type unification failed at [function application at repro/named.ail:5:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 4: `captured`

```ailang
module repro/captured
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; Pure(func(ctx: PureCtx) -> int { let _ = p.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/captured.ail...
→ Effect checking...
Error: type error in repro/captured (decl 0): type unification failed at [function application at repro/captured.ail:4:91]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 5: `localrecord`

```ailang
module repro/localrecord
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot { let w: W = { f: func(ctx: PureCtx) -> int ! {} { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/localrecord.ail...
→ Effect checking...
Error: type error in repro/localrecord (decl 0): type unification failed at [function application at repro/localrecord.ail:5:111]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 6: `missingport`

```ailang
module repro/missingport
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let _ = ctx.ports.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/missingport.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run` exit 1:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/missingport.ail
Error: execution failed: record has no field: ports
```

#### Probe 7: `helper`

```ailang
module repro/helper
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type FullCtx = { name: string, world: int }
func helper(ctx: FullCtx) -> int { 1 }
func body(ctx: PureCtx) -> int { helper(ctx) }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/helper.ail...
→ Effect checking...
Error: type error in repro/helper (decl 1): type unification failed at [function application at repro/helper.ail:6:40]: failed to unify parameter 0: record field mismatch: expected 2 fields, got 1
  expected fields: {name, world}
  actual fields:   {name}
  missing fields:  world

  Hint: this record is missing required field(s): world
        AILANG records are closed — add the field(s) to the literal, e.g. world: <value>
```

#### Probe 8: `capturednamed`

```ailang
module repro/capturednamed
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; p.emit(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/capturednamed.ail...
→ Effect checking...
Error: type error in repro/capturednamed (decl 1): type unification failed at [function application at repro/capturednamed.ail:5:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 9: `capturedannot`

```ailang
module repro/capturedannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; Pure(func(ctx: PureCtx) -> int ! {} { let _ = p.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/capturedannot.ail...
→ Effect checking...
Error: type error in repro/capturedannot (decl 0): type unification failed at [function application at repro/capturedannot.ail:4:91]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 10: `missingnamed`

```ailang
module repro/missingnamed
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let _ = ctx.ports.emit(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/missingnamed.ail...
→ Effect checking...
Error: type error in repro/missingnamed (decl 0): type unification failed at [field access at repro/missingnamed.ail:4:45]: record field 'ports' not found in concrete record
```

#### Probe 11: `missingannot`

```ailang
module repro/missingannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int ! {} { let _ = ctx.ports.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/missingannot.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run` exit 1:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/missingannot.ail
Error: execution failed: record has no field: ports
```

#### Probe 12: `missingworld`

```ailang
module repro/missingworld
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let w = ctx.world; 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/missingworld.ail...
→ Effect checking...
Error: type error in repro/missingworld (decl 0): type unification failed at [function application at repro/missingworld.ail:4:28]: failed to unify parameter 0: failed to unify parameter 0: record field 'world' not found in concrete record
```

#### Probe 13: `localunannot`

```ailang
module repro/localunannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot ! {IO} { let w: W = { f: func(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/localunannot.ail...
→ Effect checking...
Error: type error in repro/localunannot (decl 0): type unification failed at [function application at repro/localunannot.ail:5:113]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 14: `localannot`

```ailang
module repro/localannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot ! {IO} { let w: W = { f: func(ctx: PureCtx) -> int ! {} { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/localannot.ail...
→ Effect checking...
Error: type error in repro/localannot (decl 0): type unification failed at [function application at repro/localannot.ail:5:118]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### Probe 15: `fs_missing`

```ailang
module repro/fs_missing
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = ctx.ports.clock_now(ctx.world); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/fs_missing.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run` exit 1:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/fs_missing.ail
Error: execution failed: record has no field: clock_now
```

#### Probe 16: `fs_smuggle`

```ailang
module repro/fs_smuggle
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func build() -> FsSlot ! {IO} { let w: W = { f: func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 } }; Fs(w.f) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 0:

```text
→ Type checking repro/fs_smuggle.ail...
→ Effect checking...

✓ No errors found!
```

`ailang run` exit 0:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/fs_smuggle.ail
IO OUTSIDE FS VIEW
result=1
```

#### Probe 17: `fs_direct`

```ailang
module repro/fs_direct
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/fs_direct.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_direct: Effect checking failed for function 'build'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func build(...) -> T
  Suggested fix:     func build(...) -> T ! {IO}

```

#### Probe 18: `fs_named`

```ailang
module repro/fs_named
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func body(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/fs_named.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_named: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}

```

#### Probe 19: `fs_direct_io`

```ailang
module repro/fs_direct_io
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot ! {IO} { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/fs_direct_io.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_direct_io: effect checking failed: lambda at repro/fs_direct_io.ail:4:36 uses effects not declared in its ! {FS} annotation
  Missing effects: IO

```

#### Probe 20: `fs_named_io`

```ailang
module repro/fs_named_io
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func body(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }
func build() -> FsSlot ! {IO} { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/fs_named_io.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_named_io: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}

```

#### Probe 21: `fs_smuggle_norow`

```ailang
module repro/fs_smuggle_norow
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func build() -> FsSlot { let w: W = { f: func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 } }; Fs(w.f) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

`ailang check` exit 1:

```text
→ Type checking repro/fs_smuggle_norow.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_smuggle_norow: Effect checking failed for function 'build'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func build(...) -> T
  Suggested fix:     func build(...) -> T ! {IO}

```

## Provenance and final integrity check

- **Model, self-reported by Codex:** `gpt-6-astra`. No model-switch notification was received and no model override or delegated reviewer was used. The user's limit-renewal message did not report a switch.
- **Reasoning effort:** the configured effort level is not exposed in this session's reportable metadata. I cannot truthfully give a specific level; none is inferred from the task, tool model menu or amount of work. The model statement above is self-report, not independent backend attestation.
- **HEAD:** `2f3ee4d1e83feb677583924131ce08f7cb91b47a`.
- **ADR SHA-256 before reading:** `a78d505fe1685467276b2593fde0f17b473983b4c1f9fb5741e5635e78371ba1`.
- **ADR SHA-256 after writing the review body and appendix:** `a78d505fe1685467276b2593fde0f17b473983b4c1f9fb5741e5635e78371ba1`.
- **Integrity verdict:** unchanged; the reviewed working-tree v0.3 remained the same throughout the observed checks.
- **Repository write:** `.agent/projects/031_system_one_decisions/REVIEW-adr001-v0.3-verdicts-codex.md` only. No commit.
