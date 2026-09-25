# ADR-001 v0.6 — full independent review

Date: 2026-09-20. Reviewer: Codex, **`gpt-6-astra`, reasoning effort `xhigh`**, as reported by this session's Codex `turn_context` records. The model guard remained satisfied, including after the operator renewed the limit.

Reviewed working-tree document: `ADR-001-extension-owned-structured-decisions.md`, **990 lines**, SHA-256 `f24b2b812ed3e8541fc3a2583c377c1a7e0b55efe4f3c0864a74e9369f01d282`. Grounding: branch `arniwesth/031-abi-8-0`, HEAD `2f3ee4d1e83feb677583924131ce08f7cb91b47a`, ABI 7.4, AILANG v0.33.0, compiler commit `ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a`. This is a review of the proposed contract, not an implementation acceptance.

## 1. Architectural verdict and freeze readiness

**The direction remains sound; v0.6 is not freeze-ready.** Explicit configuration data is a useful replacement for closure capture. Host admission supplies the missing binding-dependent reservation input. First registration on a pre-feature journal or an additive profile switch is now described without requiring a forced resume. None of those improvements justifies accepting all the associated claims.

The new configuration channel misses `DescribeTools`, which takes `()` rather than a context. Four current callbacks of that kind require registration-time data. The channel also does not establish the claimed information-flow property or automatically enforce the question/interpretation configuration split. The proposed binding-step repair can examine the wrong registration body, and a gate based only on a new binding rejection can pass without having enumerated any bindings. The identity waiver neither disposes of the orphan that caused refusal nor prevents a fresh, free `Immediate` intervention.

There are **eight new findings, N49–N56**. N49 and N51–N54 are blocking contract/enforcement defects. N50 requires a bounded disclosure/identity claim before acceptance; it can be repaired without abandoning JSON. N55–N56 are smaller but verified contradictions in the accounting and freeze evidence text.

The compiler evidence is narrower than an effect-system proof. I reproduced 35 previously published or explicitly reconstructable cases and ran ten additional compiler cases, including one invalid experimental setup. The new, genuinely named callbacks tested here did **not** escape effect checking. The new successful effect escape fools registration lookup: the executing callback is a lambda, while the tool reports a different, unshadowed top-level callback. That distinction is central to N51.

Freeze evidence 1–3 is still absent as implemented ABI-8 evidence. These scratch language probes do not supply compiled consumers, migrated registrations, an executable rejecting gate, or live/scripted/strict-replay evidence. The missing artifacts are an existing blocker, not a ninth new finding.

## 2. Remaining blockers

| Blocker | Concrete resolution/evidence required | References |
|---|---|---|
| Configuration has no route into four `DescribeTools` callbacks | Choose and compile its data-bearing signature or make the schemas registration data; migrate `tool_catalog.ail` with it. | N49; D2:265–266, 278–311; D7 ABI row |
| Disclosure and descriptor partition overclaimed | State exactly what `ext_config` hashing guarantees; retain an explicit dependency/versioning obligation for question-producing configuration, or restrict the preparation view. | N50; D2:293–305; D6:676–689 |
| Registration lookup can certify a different callback | Resolve the delegation path in lexical/module scope before binding verification; reject unsupported shadowed/parameter-produced registrations. Retain the required scope metadata. | N51; `hook_scope.py:590–669,763–783,910–942` |
| Gate can have zero named rejections because no bindings were found | Require complete registration/atom/binding enumeration as a prerequisite to success; define the new record-return grammar and an independent shape result. | N52; D2 gate; D7; freeze 2/8; release G5e |
| Forced identity change still leaves a refusing orphan | Record an explicit disposition/acknowledgment of each orphan without erasing its spend/counters; define removal with no replacement and second resume. | N53; D6:694–724 |
| A waived identity can intervene for free | Preserve the intervention budget through migration or explicitly disable interventions on a waived identity until a recorded grant/migration. Monetary allowance alone cannot do this. | N54; D5:562–578; D6:709–713 |
| Required freeze evidence remains outstanding | Accepted complete signatures, actual ABI-8 consumers/configuration migrations, combined boundary tests, rejecting tree gate, and identity/replay mismatch evidence. | Freeze 1–3; item 8's gate belongs before freeze |

N55 and N56 should be corrected in the same revision. They do not call for another ABI mechanism.

## 3. New findings (N49 onward)

### N49. `DescribeTools` is included in named-only but excluded from the configuration channel

**Evidence.** D2:169–170 includes every callback, expressly `DescribeTools`. D2:265–266 leaves that payload taking `()`, with no context. D2:290–293 stamps configuration on the six context views. The current ABI has `DescribeTools(() -> [ToolSchema])` (`packages/motoko-ext-abi/types.ail:1238` onward); `src/core/tool_catalog.ail:107–110` invokes it as `f()`. Neither obtains `ExtEntry.config` under the stated signature.

Four of the 30 capturing bindings are these callbacks: a2a `a2a.ail:167` closes over configured schemas; agentcli `agentcli.ail:208` reads `cfg.providers`; ailang-docs `ailang_docs.ail:49` closes over discovered schemas; herdr `herdr.ail:2023–2032` closes over `cfg` and `tools` to reflect enabled tools and permitted delegate kinds. Microrag and scratchpad's descriptions do not capture registration data and are not counterexamples to that count.

**Consequence.** JSON can represent all four values, but none can be handed to these named callbacks. Hoisting the function removes the configured behavior, and putting data on `PureCtx` does not help a function never given that context. Freeze 2(c)'s two decision consumers would miss this migration failure.

**Decision needed.** Give `DescribeTools` an explicit configuration argument or a small configuration-only view, or return its schemas as data. A full runtime `PureCtx` is not automatically the right choice: schema collection currently runs through a pure catalog over registry entries. Pin the signature, exported helper if applicable, catalog invocation, and tests for configured versus empty/disabled tool sets before freezing 8.0.

### N50. Hashing `ext_config` does not make the descriptor dependency split a fact

**Evidence.** D2:297 says “a named callback can read nothing the host did not hash.” `PureCtx` retains the history and artifacts fields, as well as both descriptor configurations on `DecisionInvocationState`. A named function can also read a pure module constant or imported pure data; the scratch `named_static_constant` compiles and returns 7 with no value supplied by registration. Conversely, `named_module_env` rejects a module-level environment read, and the reproduced `q_named_toplevel_apply` rejects the effectful module initializer. Thus this is not evidence that an effectful initializer can smuggle fresh registration state into a genuine pure named callback.

The ABI exposes the **entire** `ext_config` and **both** descriptor configurations to `prepare`. Nothing restricts it to the question projection. `config_projection` is a compiled named pure preparation analogue: with identical `question_config` and `interpretation_config`, changing only `ext_config` changes its returned question from `question A` to `question B`. That is allowed by the proposed types. D2:303–306 allows general config changes to append and continue; D6:680–683 refuses changes to the question version/config but accepts interpretation-only changes. A question dependency placed only in general or interpretation configuration therefore escapes the intended question-change refusal.

Artifacts and transcript are legitimate dynamic evidence, not the extension config digest. `runtime.ail:343–347` accepts artifact updates from compaction, and `session.ail:2607–2652` carries history/artifacts on in-process resume; ADR-003 D5 resets artifacts on a profile switch. Their provenance and replay identity need their own rules, already partly supplied by D3/D6. A config hash does not cover them merely because a callback is named.

**Consequence.** The JSON channel prevents transporting a function value and makes the returned configuration bytes hashable. It does not prove which configuration fields influence questions, interpretation, or evidence. Strict query replay still compares the exact prepared request and can catch changed questions; it does not make the preceding *live-resume* descriptor check dependency-complete. Versions for code and feedback templates remain a reviewed discipline.

**Decision needed.** Narrow the fact to “the host stamps and hashes the registration data returned through this channel.” Explicitly retain a conformance obligation that every question-producing configuration dependency is included in the question identity, or choose a restricted preparation configuration view. State how a general config change affecting questions is classified. Do not hash all dynamic transcript evidence into the extension config as a purported repair. There is no demonstrated alternative effectful registration-state capture through a genuine named callback in this review.

### N51. Checking the final binding cannot repair a shadowed registration delegation

**Evidence.** `Scope.locate` follows a tail call through `_resolve_func` before `_binding_text` is invoked (`hook_scope.py:632–658`). It does not resolve that callee against local or parameter bindings. `_resolve_func` uses imports, then the closure-wide declaration table, and returns the body without its declaration signature. `producing_body` is replaced on each hop; `producing_locals` is collected only after arriving at the final body. The metadata required to enforce all delegated lexical scopes is not preserved.

The new `delegate_shadow` compiler probe has a pure top-level `make_hooks` returning `[ToolPolicy(body)]`, and a registration-local **different** `make_hooks` lambda returning an escaping pass-through callback. The local helper shadows the top-level one. `ailang check` exits 0; execution prints `NAMED RULE ESCAPE` and `result=1`. The unmodified scoper reports:

```text
located: true
bindings: { "ToolPolicy[0]": "body" }
producing_locals: []
verdict: HOOK-PORT-MEDIATED
rejections: []
```

The reported `body` is genuinely top-level and unshadowed in the body the tool chose. Consulting that body's `let`s first does not change the result. Even recording an outer local named `make_hooks` would not reject a final payload named `body` unless delegation itself is checked. The counterexample is not the fifth review's direct `let body` shadow.

**Consequence.** A correct rule about *actual* named payloads is not sufficient when the tool locates a different capability list. Changing `_binding_text` alone cannot implement the v0.6 enforcement claim. The compiler did not accept an effectful genuinely named callback; the recognizer certified a callback that is not the one executed.

**Decision needed.** Extend the supported registration grammar and scope check to every delegation hop, including lexical locals/parameters and module-correct function resolution. Preserve signatures and scope provenance, or reject forms the reader cannot resolve. Add this exact fixture as an accepted bare-compiler escape and a required boundary rejection. Treat constructor and alias resolution as part of verifying the actual ABI constructor; no successful constructor-alias exploit is claimed here.

### N52. Zero named-only rejections is insufficient when the registration was never enumerated

**Evidence.** `derive_hook_scope` calls `walk` only if `locate()` succeeds (`hook_scope.py:1044–1046`). A computed list yields `located=false`, no bindings, and `capability-list-unresolvable`. The compiled `computed_list` probe returns its escaping inline callback through `if true then [...] else []`; it performs IO, but the scoper never calls `_binding_text`. A new rejection emitted only at that step would have count zero.

The new valid `registration_record` probe models precisely the proposed outer data shape, `{config: Json, caps: [Capability]}`, with a harmless named callback. It compiles and runs. The current locator also rejects it before binding enumeration: it only recognizes a literal list or a delegated call to one. Supporting the new outer record and defining how its `caps` is located is required by the new ABI; “consult lets first” does not supply that grammar.

Today `Scope.verdict` collapses any rejection to `HOOK-UNRESOLVED`, ahead of ambient findings (`:953–956`); `emit_hook_scope` returns 0 (`:1122`). v0.6 correctly changes the exit contract and correctly allows unrelated walk residue to remain, but does not classify failed **registration enumeration** as a gate failure independently of those tolerated walk results.

**Consequence.** Testing just for the new callback rejection can produce a vacuous green. Testing every `HOOK-UNRESOLVED` instead would violate the intended tolerance of unrelated `show`/higher-order walk residue. The distinction must be encoded, not inferred from the umbrella verdict.

**Decision needed.** Make registration shape validity a separate total result: the registration return shape is supported, all actual atoms/function payloads are enumerated, and each satisfies the named rule; otherwise fail the gate. Include unresolved delegation, unknown/computed list elements, unsupported record/caps forms, and unresolved binding names in that failure class. Permit an actually recognized empty list where normalization allows omission. Keep hook-reachability diagnostics and the shipped closure inventory separate. `emit_hook_scope` can exit nonzero from this result without changing the shipped `ext_ambient_inventory` verdict.

### N53. A zero snapshot for the new identity does not retire the old orphan predicate

**Evidence.** D6:701–703 fires `Identity` when retained used interventions, known spend, or outstanding reservations belong to an identity absent from the invoked registry. D6:709–712 says a forced change registers the new identity at zero, the orphan remains under its old identity, and the next ordinary resume does not refuse.

Take an old identity `guard#0/finalize/g` with used interventions 1 and known spend 10, and a new registry containing only `guard#1/finalize/g`. Force the change. The specified snapshot now contains the new identity at zero, but the old identity is still absent from the registry and still retains 1/10. On the next ordinary resume the specified orphan predicate is **still true**. Membership of the new identity does not affect that test. An operator grant to the new identity also leaves it true. Removal with no replacement has no new “waived identity” on which to put the proposed zero snapshot.

**Consequence.** P0 → forced P1 → ordinary P1 is not established. The operator can face the same forced-resume requirement indefinitely, despite following the documented waiver path. Explicit migration is different: it is specified to move retained state once and close the old identity, so it can clear that orphan.

**Decision needed.** Add a recorded disposition for the exact orphan set at the accepted epoch: for example, acknowledged inactive identities whose liability remains retained but no longer counts as an unacknowledged registry mismatch. Define removal, a later reappearance/rollback, outstanding reservations, and grants against that disposition. It must preserve liabilities, prevent duplicate moves, and be compared against the effective epoch. Amend D7's records and the pinned two-resume cases accordingly.

### N54. Zero money with zero used interventions creates a new `Immediate` intervention budget

**Evidence.** D5:565–567 skips callbacks only when the effective **intervention** limit is exhausted. D5:572–574 expressly counts selected `Immediate(ContinueWithFeedback/Deny/Pending)` votes. D6's forced snapshot sets **used interventions to zero and monetary allowance to zero**; it does not set the intervention limit to zero or disable the identity. Its promise is only that the identity “can query nothing” until a migration or grant.

Let the old atom have `interventions_used=1`, `intervention_limit=1`, and no monetary spend because its first vote was `Immediate`. Rename/reorder it and force the identity mismatch. The new identity has used 0, configured limit 1, and money 0. Preparation is eligible and can return a selected `Immediate(ContinueWithFeedback(...))`. No query reaches the monetary admission gate. The atom gets another intervention without migration or grant. This remains a separate problem even after the orphan acknowledgment in N53 is added.

**Consequence.** The waiver manufactures effective control authority, contrary to D5's retained-counter rule and D6's “manufactures nothing” sentence. Money and interventions are independent budgets. A zero monetary allowance also does not by itself reject a genuinely zero-charge binding if such a binding is allowed; the ADR does not require strictly positive `r`.

**Decision needed.** Define a waived identity as inactive for interventions and, if intended, queries until explicit activation, or preserve/migrate its prior intervention balance. Specify whether an operator grant changes money, interventions, or both; an “allowance” assignment cannot leave that implicit. Test free `Immediate` votes as well as paid queries after a forced rename, removal/readdition, and profile replacement.

### N55. The terminal-query statement contradicts the admission equation

**Evidence.** D5:543–554 applies `r + run_cost <= cap` at host admission whenever `run_cap=Some(cap)`. It has no exception for finalize-site queries. D5:557–559 then says a finalize query ending the run is bounded by the decision allowance alone because the step machine observes spend only at the next model call. The N40 response row repeats that statement.

For `run_cost=95`, `cap=100`, decision allowance remaining 1000, and `r=10`, the host equation refuses a terminal query before provider contact. Whether another model call occurs is immaterial. `step_machine.ail:110–115` does check at the next model call, but it is no longer the only run-cap check in the proposed architecture.

**Consequence.** The text and freeze-5 fixture can encode opposite expected results. This is a contradiction in the proposed behavior, not an observed overspend in current code.

**Decision needed.** Keep the host admission equation and correct the terminal sentence/N40 response. A terminal query is bounded by both limits when the run cap is enabled, and by the persistent decision allowance when it is absent. Pin admission rejection at the terminal site and separate it from later `BudgetExceeded` behavior.

### N56. The “24 named-arm attacks all reject” claim misstates the cited suite

**Evidence.** D2:188–194 says the fifth review's 24 probes were all rejected; freeze 2(b) requires the “24 named-arm attacks” to still reject. The cited fifth review A.3 table contains **20 rejecting cases, one successful ordinary control, and three successful escapes** (`q_named_shadow`, `q_named_paren_apply`, `q_named_partial`). I reran those three escape sources: all check and run with exit 0 and print the effect. The positive control is explicitly listed as exit 0/0 in the source review; I have not reconstructed and independently rerun that unpublished full source.

**Consequence.** The acceptance statement is not executable as written. Forcing all 24 to reject would mis-score both intended success and known bare-compiler limitations, contrary to the two-sided limitation idiom correctly adopted elsewhere. This does not refute the narrower claim that none of the tested genuinely named, unshadowed, directly bound functions escaped.

**Decision needed.** Name the three groups and their expected compiler/boundary results. Keep the ordinary control accepted; keep the three historical escapes accepted by the pinned bare compiler and rejected by the boundary; keep the 20 negative controls rejected. Add this review's new cases separately rather than changing the old suite's denominator.

## 4. Resolution of N41–N48

These are verdicts on the proposed resolutions, not claims that the changes have landed. Core/package/tool/script tracked sources remain unchanged from the stated baseline.

| Item / v0.6 claim | Verdict | What was verified |
|---|---|---|
| **N41: JSON registration channel; host stamps/hashes it; descriptor configurations returned; epoch change continues; function captures become match** | **Partial** | All 30 captures are data, zero are function-valued. JSON is a suitable carrier for those values. Four `DescribeTools` callbacks have no argument for it (N49). Returned data is hashable, but dependency disclosure is not automatic (N50). Kind-only digest plus a separately recorded epoch is coherent subject to the Descriptor/Prompt checks. |
| **N42: named-only, lexical order, reject local/parameter shadow and partial applications** | **Partial** | The rule excludes the previous direct-shadow and partial-application escapes. Existing `_binding_text` needs that change. Earlier delegation resolution can select the wrong list (N51); the current metadata is insufficient for the full rule. |
| **N43: shape + compiler + limited walk; nonzero exit independent of other verdicts** | **Partial** | Correct division of responsibilities; walk blind spots verified in source. A separate shape result can drive the exit without altering closure verdicts. Registration/enumeration failures must participate (N52); none of this is implemented yet. |
| **N44: two preconditions; unannotated and parenthesized forms escape** | **Resolved as a factual correction** | Reconstructed the unannotated stored-lambda variant and reran the printed parenthesized source: both compile and perform the effect. Related named/imported-type controls still reject. |
| **N45: 10 named / 16 let / 19 inline; 45 total, 30 capturing** | **Resolved** | Independently inspected every registration and delegate; the 45-row ledger below reconciles all counts. Data constructor arguments are not counted as callback captures. |
| **N46: Identity only on orphaning, first registration, migration/grant, zero waiver snapshot** | **Partial** | Pre-feature and additive cases now work when no retained identity is orphaned; explicit move-and-close migration is useful. The claimed ordinary second resume and no-fresh-allowance property fail under the stated waiver (N53–N54). D5:569–570 still needs its blanket new-identity sentence reconciled with D6's first-registration exception. |
| **N47: host admission from recorded binding table/limits; child mirror; refusal is one exchange; replay repeats admission** | **Resolved at the admission-ownership level; replay/mirror implementation remains evidence work** | `r` follows `prepare`'s selected binding; host has the table and ledger, child owns run terms. No child per-binding maximum is required. The recorded-input replay rule is coherent; placement of its checker alongside child-side replay ports must be specified in the plan. N55 is a contradictory retained sentence, not missing `r`. |
| **N48: existing script, imported-ABI mechanism, committed fixtures** | **Resolved as a decision** | Read the existing limitation rows (`run_declared_vs_performed.sh:751–771`) and `write_abi_ctor` (`:945–1000`). The mechanism is appropriate; concrete fixture sources, updated imports/types and expected outcomes remain implementation work. N56 corrects the expected-outcome wording. |

## 5. The four questions

### Q-1. Configuration channel, every capture, cost, and identity

**Answer:** `ExtRegistration.config` plus host-stamped immutable JSON is a reasonable data channel for all 30 current captures, subject to N49. It removes the need for registration closures, provided the actual named-only boundary is enforced. **No current captured value is a function.** Agentcli's provider “table” consists of strings, string arrays and booleans; MCP mappings/server definitions and compose/herdr configuration are also data. None of the 30 requires converting a captured dispatcher into a `match` today. That remains a sensible rule for future function-valued configurations.

Here is the complete callback ledger. Paths are under `packages/`; abbreviations `motoko-ext-` are omitted from package names except the actual `motoko_scratchpad` path. **N** = named top-level; **L** = let-bound lambda; **I** = inline lambda. “—” means no registration-time data capture, not no use of constants/imports. The data column identifies the capture or the fields needed from a captured record; it is not a proposal to serialize unused fields.

| # | Site | Callback | Form | Registration data captured |
|---:|---|---|:---:|---|
| 1 | `a2a/a2a.ail:167` | `DescribeTools` | I | schemas: list of tool-schema data |
| 2 | `a2a/a2a.ail:168` | `ToolProvider` | L | agents: list of A2AAgent records |
| 3 | `agentcli/agentcli.ail:208` | `DescribeTools` | I | cfg.providers: Provider records |
| 4 | `agentcli/agentcli.ail:209` | `ToolProvider` | L | cfg: providers, lock path, output limit |
| 5 | `ailang-docs/ailang_docs.ail:49` | `DescribeTools` | I | schemas: list of tool-schema data |
| 6 | `ailang-docs/ailang_docs.ail:50` | `PromptShaper` | I | —; build_prompt_patch reads ctx.task |
| 7 | `ailang-docs/ailang_docs.ail:51` | `ToolProvider` | L | cfg: McpServerConfig; mappings |
| 8 | `compaction-ai/register.ail:106` | `Compactor` | I | CompactionAiConfig: model, limits, flags |
| 9 | `compaction-structural/register.ail:25` | `Compactor` | N | —; pre_step |
| 10 | `compose/compose.ail:1109` | `PromptShaper` | N | —; on_build_system_prompt |
| 11 | `compose/compose.ail:1110` | `ToolPolicy` | I | composition_mode: string |
| 12 | `compose/compose.ail:1111` | `ToolProvider` | L | runtime_cfg: ComposeHostConfig; snippet_caps: strings |
| 13 | `compose/compose.ail:1112` | `ResponseInterceptor` | L | composition_mode; snippet_caps |
| 14 | `context-mode/register.ail:54` | `PromptShaper` | I | cached_prompt: string |
| 15 | `context-mode/register.ail:55` | `ToolPolicy` | N | —; on_tool_policy |
| 16 | `context-mode/register.ail:56` | `ToolProvider` | L | cfg: CtxConfig |
| 17 | `context-mode/register.ail:57` | `SolverJudge` | L | cfg: CtxConfig |
| 18 | `decision-framework/register.ail:145` | `PromptShaper` | N | —; conditional_prompt_patch |
| 19 | `empty-stop-guard/register.ail:21` | `SolverJudge` | N | —; finalize |
| 20 | `exa-search/exa_search.ail:42` | `PromptShaper` | I | cached_prompt: string |
| 21 | `exa-search/exa_search.ail:43` | `ToolProvider` | L | cfg: McpServerConfig; mappings |
| 22 | `herdr/herdr.ail:2032` | `DescribeTools` | L | cfg: HerdrConfig; tools: strings |
| 23 | `herdr/herdr.ail:2037` | `PromptShaper` | I | orch: OrchestratorMode |
| 24 | `herdr/herdr.ail:2038` | `ToolPolicy` | I | orch: OrchestratorMode |
| 25 | `herdr/herdr.ail:2041` | `ToolProvider` | L | cfg: HerdrConfig |
| 26 | `herdr/herdr.ail:2051` | `ExitIntent` | L | cfg: HerdrConfig |
| 27 | `herdr/herdr.ail:2055` | `WorkInFlight` | L | cfg: HerdrConfig |
| 28 | `mcp/mcp.ail:165` | `ToolProvider` | L | servers: list of McpServerDef records |
| 29 | `microrag/register.ail:172` | `DescribeTools` | N | —; microrag_describe_tools |
| 30 | `microrag/register.ail:173` | `ToolPolicy` | N | —; microrag_tool_policy |
| 31 | `microrag/register.ail:180` | `ToolProvider` | N | —; microrag_tool_handle |
| 32 | `omnigraph/register.ail:38` | `PromptShaper` | I | cached_prompt: string |
| 33 | `omnigraph/register.ail:39` | `ToolPolicy` | N | —; on_tool_policy |
| 34 | `omnigraph/register.ail:40` | `ToolProvider` | I | —; on_tool_handle(ctx, call) |
| 35 | `progress-contract-guard/register.ail:20` | `SolverJudge` | I | —; decide(ctx, candidate) |
| 36 | `repetition-guard/register.ail:45` | `ToolPolicy` | L | calls: int |
| 37 | `repetition-guard/register.ail:46` | `SolverJudge` | L | answers: int |
| 38 | `test-dummy/register.ail:61` | `PromptShaper` | I | prompt_marker: string |
| 39 | `test-dummy/register.ail:65` | `BudgetShaper` | I | budget_total: Option[int] |
| 40 | `test-dummy/register.ail:73` | `ToolPolicy` | I | tool_decision: string |
| 41 | `test-dummy/register.ail:78` | `SolverJudge` | I | finalize: string; not a function |
| 42 | `motoko_scratchpad/scratchpad.ail:95` | `DescribeTools` | I | —; on_describe_tools() |
| 43 | `motoko_scratchpad/scratchpad.ail:96` | `PromptShaper` | I | —; prompt_patch() |
| 44 | `motoko_scratchpad/scratchpad.ail:97` | `ToolPolicy` | N | —; on_tool_policy |
| 45 | `motoko_scratchpad/scratchpad.ail:98` | `ToolProvider` | L | timeout_secs: int |

Totals: **45 sites = 10 N + 16 L + 19 I; 30 data-capturing; 0 function-capturing; 35 sites require a binding-form change.** The five noncapturing lambdas are ailang-docs' prompt, omnigraph's provider, progress-contract's judge, and scratchpad's description and prompt. They still violate named-only. Constructor data such as provider tool names, exit-intent IDs/enabled flags and work labels remain data arguments and must also participate in the relevant registration/policy records; a list of names is not a callback closure.

For JSON encoding: strings, booleans, integers, lists and the inspected records have direct encodings; optional integers need a declared null/tag convention, and schemas' string-valued JSON must retain its meaning. Agentcli's `Provider` type (`providers.ail:28–49`) has no callable fields. MCP's auth setting includes an environment-variable **name**, not a captured credential value; the named effectful provider can use permitted ports later. No literal runtime secrets were fetched for this review. JSON typing cannot enforce “no credentials” on arbitrary strings: that remains a reviewed serialization rule, not a new demonstrated credential leak.

Pure module data/imports remain readable, and code versions must identify those changes. Effectful module initialization was rejected in the probes. Transcript/artifact data remains accessible by design and has recorded-evidence provenance, not config-hash provenance (N50). Named callbacks therefore eliminate lexical registration capture under the verified shape discipline; they do not establish universal information-flow tracking.

**Cost:** “Per-call decoding is cheap against a hook's cost” (D2:311) is not measured and is especially unsupported for pure policy/prompt hooks. Stamping an immutable JSON reference need not serialize or deeply copy it, but rebuilding views, decoding schemas/provider lists/cached prompts, and repeated traversal can scale with configuration size times invocation count. The ADR should state reference sharing/hash-once-per-epoch as an implementation expectation, bound retained/serialized configuration size, and require migration measurements for the largest values. This is a performance assumption to qualify, not an independently measured slowdown.

**Identity:** keeping `ext_set_digest` at owner/kind granularity is consistent with the existing `runtime.ail:1107–1151` implementation and ADR-003 D5 if full configuration epochs are a separate recorded input. “Append and continue” must mean no *additional general-config refusal*: an unchanged-kind config edit can still change the system prompt and trigger existing same-profile `Prompt`, or change question/limit identity and trigger `Descriptor`. Strict whole-run replay must compare the relevant full config epoch as well as the two descriptor projections. ADR-004 D1 requires those configuration bytes or resolvable references, not only a digest. N50 is the missing dependency qualification; N53–N54 are independent retained-state problems.

### Q-2. Boundary, new attacks, and the gate

**Answer:** the semantic restriction to truly named, unshadowed, directly bound functions remains supported by the tested compiler behavior. It is **not implementable solely by reordering lookups in the present `_binding_text`**. That method needs reliable registration enumeration and lexical/module metadata that `locate` currently discards. The new delegation-shadow escape is N51; the no-enumeration case and new registration record are N52.

The additional genuine named attacks put an effectful local lambda into a matched record, a list, or a tuple, and attempted a module-level environment initializer. All were rejected by effect/type checking. A pure module constant was accepted. The attempted constructor-rename setup failed with an undefined constructor alias and supplies no boundary evidence. Full source/results are in Appendix A; none is described as a successful genuinely named effect escape.

The existing walk's `_APPLY` spelling requirement, uppercase skip and field-name-only port recognition remain defense-in-depth limits. They do not become an effect proof. Nor should unrelated transitive `HOOK-UNRESOLVED` results be allowed to conceal a shape rejection: inspect a separate shape result or rejection category, not only the overall verdict. `derive.py` already returns `emit_hook_scope`'s status from its hook-scope mode, so that mode can fail independently of the shipped closure-inventory mode. `installable_extensions` derives its membership from `ailang.toml` and validates the path/package names; the current universe is the 18 local installable extensions, including the unusually named scratchpad directory. Keep missing/unreadable installable roots fatal. External registry installations remain outside this gate, as disclosed in D2.

A supported grammar can be deliberately small, but it must cover the chosen `ExtRegistration` return shape and reject unknown forms. Test a direct named success; each migrated current site; direct callback shadow; delegated helper shadow; parameter binding; partial application; computed/unknown caps; an empty valid registration; and a named callback with unrelated walk residue. The last must pass shape validation without claiming the entire walk is resolved. The gate must become red on missing enumeration and on either shadow fixture.

### Q-3. Host admission, replay, and the child mirror

**Answer:** moving admission to the host is sound at the contract level and removes any requirement that the child know the per-binding maximum charge. `prepare` chooses the binding; the host resolves it from recorded inputs and checks its own ledger plus child-known run terms. One completed `Query` has one exchange whether admission refuses or a provider result is returned. A refusal has no provider contact or charged reservation; its typed `Unavailable` is recorded and replayed. An interrupted query is not a fabricated complete exchange.

Strict replay can repeat that admission computation using the recorded binding table, request limits, ledger prefix, run cost and cap, then compare the derived admission disposition with the recorded exchange. It must not re-read live configuration, call the provider, or update a live session's financial ledger. The complete observation remains recorded external data; recomputing admission does not reconstitute unknown provider usage. Cross-run outstanding reservations stay in the persistent allowance but are not added a second time to a fresh run's totals. A finite **maximum** must actually bound the configured request/backend contract; missing a safe maximum refuses, as D5 says.

The plan must identify where this replay validator runs. D5:597–598 keeps scripted/recording/strict-replay port arms child-side, while D6:653 calls the admission validator host-side. Those can coexist with a recorded-ledger checker/replay host or a shared admission reducer, but a child-only scripted port does not magically invoke the live TUI service. Require a concrete test with the provider unreachable and corrupted recorded admission inputs. This is an implementation placement obligation, not evidence that a query needs a second exchange or a second provider call.

The child mirror is enough for **advisory** preparation, not for a promise that a query will be admitted. Resume must fold the effective policy epoch, grants, migrations, retained reservations and promotion state before stamping it; fresh registration must seed configured first allowances. Every reply, including admission refusals, must carry the authoritative updated terms. The run terms must incorporate ordinary model cost and this run's reconciled decision charges, not simply the previous reply's cost. An out-of-process interruption stops the child, so a missing reply cannot authorize continuing with a stale balance. If the mirror overstates available money, the host still refuses safely; if it understates money and `prepare` abstains, a useful query can be lost. Capture the stamped snapshot in replay evidence and test those cases.

Counter updates also occur on **selected Immediate applications**, which have no decision reply. The child dispatch state must advance those local counts when emitting the application event, and the host must serialize that event before subsequent admission; seed-and-reply updates alone are not a counter protocol. D5 already requires counting such applications. The plan must implement both paths and retain the accepted emission-to-write crash window, rather than claiming acknowledgment the ADR deliberately omits. Preparation and interpretation must use the promised immutable invocation evidence snapshot while subsequent atoms receive the updated state.

The inspected host code supports the need for a new service, not an existing durability guarantee: `SessionJournal.append` catches failure and returns null; `SessionLogger.log` drops the count; wake requests are specially routed before ordinary `onEvent`, and `sendWakeReply` sends to stdin before the later child observation is journaled. D5's success-returning append, host serialization, discriminator, invocation/deadline checks and stdin ownership are therefore substantive implementation work. Reservation failure prevents provider contact; observation failure prevents a reply; application failure stops the run. These are host control failures, not interpreter-visible unavailability. The read of host code included the routing and duplicate/late-reply paths, not only the append method.

### Q-4. Orphaning, first registration, migration, grant, and force

**Answer:** orphaning is the right trigger for retained identities, but the waiver transition is incomplete (N53–N54). Cases must be evaluated from the effective epoch and actual retained state, not from the operation's label alone.

| Case | Result under the proposed rules / remaining correction |
|---|---|
| First schema-2 resume of a pre-feature journal | No decision liabilities exist. Promote once; record first registrations with configured allowance. No `Identity` refusal. Typed tool window remains incomplete. |
| Additive profile switch preserving existing owners/site/IDs | First registration for genuinely new identities; retain old balances. No orphan. “Additive” insertion **before** an existing decision extension changes its install index and is instead the reorder case. |
| Same identity, unchanged policy | Retain money, reservations and intervention count; no refill. |
| Interpretation-only version/config change | Append an epoch and continue, retaining limits/counters. Strict whole-run replay differs; offline reinterpretation remains explicitly separate. |
| Non-decision config digest change | Append epoch and continue subject to existing `Prompt`/`ExtSet` checks. No implicit whole-session immunity to other refusals. |
| Question or declared-limit change | `Descriptor` refuses even across profiles; force records the new effective epoch but must not recalculate the retained effective allowance/limit. |
| P0 → forced P1 → ordinary P1, descriptor-only | Comparing against the folded epoch fixes the old header problem. Rollback to P0 is another changed descriptor and refuses unless forced. |
| Reorder, removal or replacement with retained state | Missing old identity causes `Identity`. A rename with used interventions alone is enough; money need not have been spent. |
| Removal/reorder with no used count, spend or outstanding reservation | The stated retained-state predicate has nothing to protect. Do not claim every syntactic reorder necessarily refuses; preserve the recorded policy/config change either way. |
| Reinstall under exactly the same owner/index/site/local ID | The ledger already has that identity; retain it. This is not automatically orphaning. If the owner index changes, use the reorder case. |
| Forced identity mismatch | New zero snapshot leaves old orphan predicate true; ordinary second resume still refuses (N53). It also admits new free interventions unless separately disabled (N54). |
| Removal with no replacement | No new identity exists to receive the zero snapshot. Requires an explicit retained-orphan disposition (N53). |
| Operator grant after force | Can assign the named monetary allowance, but does not close/acknowledge the old orphan or specify intervention activation (N53–N54). |
| Explicit old → new registry migration | Move retained state once and close the old active identity. Define destination with a prior zero snapshot or grant, duplicate moves, outstanding liability attribution and rollback; no double credit. |
| Rollback/reappearance after forced identity change | Must consult the orphan disposition and existing ledger, not mint another first allowance. Currently not specified sufficiently (N53–N54). |
| In-process suspension / new-process resume | Same persistent balances and applied counts; reset only per-run totals. No implicit grant because the child process changed. |
| Old unknown reservation + new run | Keep old liability against the identity allowance; do not charge it again to the new run cap. |

D5:569–570's unconditional “newly introduced identity requires explicit registry migration” must be marked superseded by D6's no-orphan first-registration rule. The useful part of the fourth review's warning survives: a new *replacement* identity must not reset exhausted authority. V0.6 repairs pre-feature/additive onboarding, but its force path still fails that warning.

## 6. D1–D7 assessment

| Decision | Verdict and evidence |
|---|---|
| **D1: policy/host ownership** | **Supported.** Extensions own selection/questions/interpretation; host owns execution, permissions and accounting. Logical bindings keep adapter credentials out of callbacks. The guarantee is cooperative reviewed extension behavior plus the specified boundary; it is not a sandbox against arbitrary unreviewed compiler/tool exploits. No calibrated-provider claim follows. |
| **D2: ABI and boundary** | **Blocked.** N49–N52. Six restricted views remain useful; `ProcessCtx` has no ports, FS views expose six FS functions, AI/Intercept/Provider rows preserve their intended authority. Adding `Trace` to Provider resolves the declared port-row mismatch. Each view requires a constructor and helper migration. `DescribeTools` needs an explicit data channel. Vote-family normalization must reject legacy/new combinations, not just repeat kinds. Both decision callback signatures and the one-query maximum are otherwise coherent. |
| **D3: observations and evidence** | **Supported as specified, with validation evidence outstanding.** Integer basis points, absent optionals, invalidating the whole malformed response, one host float normalizer, strict integer codec/fold validation and a shared vector set form a coherent contract. The `-1` exit sentinel, incomplete resumed tool window, heuristic missing-infrastructure evidence and optional workspace revision are stated truthfully. Config dependency qualification is N50; the mirror needs the Q-3 protocol. No provider response or float-normalization implementation was executed. |
| **D4: execution and composition** | **Supported.** Existing runtime collectors confirm ordered all-atom execution and the described vote precedence; preserve losing-query worlds and cost. Core leaves belong in `session.ail`/`tool_phase.ail`, not a hidden extension helper. Nullary `Accept` removes replacement and needs the synthetic test/external migration. The diagram still puts “validate/admit → reserve” in the calling core module: update it to show local request/leaf work versus host wire admission/reservation after N47. This is stale placement prose, not a reason to restore child admission. |
| **D5: cost, counters and durability** | **Partial.** Host admission/write barriers and two cost lifetimes address the previously identified omissions. N54 breaks intervention retention after forced identity change; N55 contradicts the terminal cap. D5's first-registration sentence needs D6's exception. The current host logger/wake path is not the success-returning decision service. Accepted emission-to-write loss is named; do not claim exactly-once application or upstream billing. |
| **D6: replay and identity** | **Partial.** One exchange per completed Query, recorded configuration inputs, occurrence identity, query versus policy identity, strict replay versus offline reinterpretation, and effective epochs are coherent. N50 bounds descriptor completeness; N53–N54 block the waiver/identity story. The plan must locate the recorded-admission checker alongside child-side replay ports. |
| **D7: ABI and persisted migrations** | **Supported apart from the outstanding ABI/identity corrections.** ABI 8.0, execution-program/5, journal 2 and event vocabulary 2 change independently. `/5` follows payload/scripts, not a constructor count. Schema-1 histories can start with truly empty decision state; append promotion before any decision record, preserve historical bytes, and fold later state on every subsequent resume. Native header 2 and promoted header 1 have different old-reader failures, correctly described. Update registration/catalog tooling and new identity disposition records before accepting the table as complete. |

**D7 table audit.** The ABI row must include N49's chosen signature and the actual count of added fields per view; D3's three evidence/state fields plus D2's configuration field must all be initialized. The tooling row must cover the new outer registration record and lexical delegation, not just kind/arity maps and `_binding_text`. The “Other records” row correctly adds the config epoch and recorded migration/grant; N53–N54 require precise orphan disposition and grant/activation semantics there. The ADR-003 D3 one-writer/one-initial-rewrite model is preserved by appended promotion; ADR-003 D5 gains real compatibility/state transitions that need an amendment. ADR-004 D1's recorded inputs and D5's separately pinned evaluation basis require a basis refresh; this review did not operate on its evaluator worktree.

`SessionJournal.adopt` preserves an existing header; `writeHeader` is a no-op on nonempty files; `completeHeader` is the existing atomic rename for initial completion. This supports the proposed append-only transition. The plan must teach adoption/folding the *effective* schema and epoch rather than inferring them from the retained header number. The old AILANG fold already refuses unknown entries; a promoted file fails at `schema_promotion`, while a native schema-2 file fails at header version. `--resume-force` cannot repair decoding or erase a ledger.

**Freeze-evidence audit:**

| Item | Assessment |
|---|---|
| **1: accepted signatures/types/identity/placement** | Not met: `DescribeTools`, configuration identity qualification, and identity-waiver transitions need decisions. The broad execution direction is accepted, not the complete freeze surface. |
| **2(a): missing authority** | The old language probes reproduce missing-field faults for accepted inline lambdas and compile rejection for named controls. They are not evidence for every actual ABI-8 view or its host control-failure route. Keep this class separate from the named gate. |
| **2(b): ambient boundary** | Not met: add delegated-shadow and no-enumeration negative fixtures, and fix the 24-probe expectations (N51–N52, N56). No genuinely named escape found is bounded evidence, not a proof. |
| **2(c): ordinary ABI-8 success** | Not met: compile both decision consumers with actual constructors/config stamping, plus configured `DescribeTools` coverage and the migrated registration universe. Minimal local types do not count. |
| **3: policy changes and mismatches** | Not met: show question/config changes without core edits, strict query/policy/full-config mismatch rejection, and distinctly labeled offline reinterpretation. Add the N50 dependency example. |
| **4: parity/worlds/occurrences/replay** | Appropriate pre-live obligations. Include admitted and refused Queries as exchanges, late/duplicate IDs, identical content at distinct occurrences, and losing votes. No network in strict replay. |
| **5: evidence/accounting/crashes/resume** | Scope is appropriate but fixtures need N53–N55: acknowledged removal, ordinary second resume after force, free Immediate after force, grant activation, terminal admission with cap present/absent. Exercise successful/failed append barriers separately from the accepted child-emission crash window, and interruption around promotion. |
| **6: composition and retained allowances** | Retained intervention and money budgets must be tested independently. Preserve DP7/waits/permissions, first-Deny/last-Pending ties, losing costs, shadow neutrality, and profile/compaction invariants. |
| **7: formats/amendments/basis** | Correct separate migration obligations. Test native/promoted journals with old/new readers, repeated resume, unknown tags, and effective-epoch comparisons. Historical fixtures remain unchanged; evaluator refresh is separately coordinated. |
| **8: suite and executable gate** | Existing two-sided limitation rows are the right mechanism; N56 supplies the correct case classes. Tree-wide gate and complete enumeration are **before-freeze** obligations, as item 8 itself clarifies. Compiled row probes do not require fixing the upstream compiler first. |

**All five response tables were checked against the operative text.** The first table's capture-disclosure N4 becomes historical under N41, but N50 shows why total disclosure should not be called mechanically proved. The second table's structural “purity” summary and header-only descriptor comparison are superseded by D2's layered boundary and D6's effective epochs; its N16/N20/N21/N22 direction remains valid. The third table correctly marks the pass-through discipline and XFAIL decision superseded; its Q-A “DescribeTools no context” fact now exposes N49. The fourth table's N31 walk-as-boundary, N32 counts and N35 child admission are historical and should be explicitly marked superseded; N34's schema correction and N37's split remain sound. Its N40 terminal-only bound is currently false (N55). The fifth table is assessed claim by claim in section 4; N41–N43 and N46 cannot yet be labeled closed. These are operative inconsistencies or history labels, not eight extra findings.

## 7. Before freeze, before the plan, and afterwards

**Before freeze:** choose the `DescribeTools` data-bearing contract; narrow/disambiguate configuration dependency identity; extend registration resolution and require complete enumeration for the shape gate; define retained-orphan acknowledgment and waived intervention authority. Correct the terminal-cap and probe-count statements. Then produce the actual freeze 1–3 artifacts and the implemented item-8 gate. Both ordinary ABI-8 success and rejected negative cases are required. This review supplies neither by writing a document.

**Before the affected implementation plan is approved:** allocate the 45-site migration using the inventory of 30 capturing bindings; define JSON encoding/decoding errors, retention/size cost and no-credential projection; update registration normalization, generated registry, catalog, constructors and all inventories. Specify host append success propagation, serialized request/application ordering, reply ledger payloads, fresh/resumed mirror initialization, run-cost propagation, replay-admission checker placement, wire validation/deadline behavior, schema promotion/adoption, and exact migration/grant/orphan record folds. Record the ADR-003 amendment and separate ADR-004 basis refresh. The suite home is decided; the plan must name the committed fixture directory and exact imported-ABI rows.

**During implementation, before live enforcement:** satisfy freeze 4–7 and their added failure cases, confirm every query occurrence's accounting/witness/world propagation, and rerun gate regressions after migration. Start the first live guard in shadow mode and measure false objections, missed bad completions, outcome, added steps, cost and latency separately. Do not use replay fidelity as evidence that a judgment is correct.

**Afterwards:** policy wording, thresholds and provider-specific limits can evolve under the recorded identity rules. Existing `ext_ai_step` usage loss remains separate acknowledged accounting debt. A compiler upgrade changes the evidence basis: a formerly accepted limitation becoming rejected should deliberately fail the limitation row until the controls and boundary are re-reviewed.

## 8. Method and limitations

I read the v0.6 brief first, verified its SHA and 990-line identity before reading the target ADR, and verified HEAD/branch/compiler. `git diff --stat 2062605 HEAD -- src/core packages tools scripts Makefile` and the corresponding tracked working-tree diff were empty. Existing unrelated modified/untracked files were left alone. The initial session and subsequent turn contexts, including after limit renewal, all report `gpt-6-astra` / `xhigh`.

Read in full: target ADR v0.6; all five earlier reviews, newest first, including their probe appendices; NOTE-001; all four 2026-09-20 handoffs; the release scope; **all 1266 lines of `hook_scope.py`**; every `packages/*/register.ail` and every delegated `make_hooks`/`make_hooks_with` body; the cited compose and herdr helpers; `registry_normalize.ail`; and 017's ABI-evolution ADR. Truncated tool outputs were followed by smaller overlapping reads of the omitted sections.

Read the required source regions and necessary dependencies: ABI header/`ExtPorts`/`ExtCtx`/`Capability`/`ExtEntry`; runtime registration, dispatch/merge, artifact update and digest; generated registry identity and tool catalog; derive's installable-extension enumeration and hook-mode return; script limitation/imported-constructor mechanism; Make gate membership/targets; journal writer contract/refusals/header/fold/resume/unknown-entry test; resumed session state and step-machine cost guard; typed outcomes and wake ports. Host reads covered `session-journal.ts` initial/adopt/append/header/completion paths, `session-logger.ts:404`, and `runtime-process.ts` stdout routing, wake request/reply, invocation checks and suspended-wake handling. Cross-ADR reads covered ADR-003 D3/D5 and ADR-004 D1/D5. I did not read every line of the large session, ports, journal, compose, or TUI modules and do not claim otherwise.

**Executed:** 45 distinct compiler cases in `/tmp/adr001-v06-codex-vzzcbryn`, with 17 accepted modules also executed (14 completed successfully; three reached the expected missing-field runtime failure) under explicit `IO,FS` capabilities. The 35 historical/reconstructed cases consist of the third review's 21 printed modules, eight printed fourth-review attack/control modules, five printed fifth-review modules, and the unannotated variant reconstructed by deleting its stored lambda's row annotation. All 21 third-review check/run outcomes reproduce; the other runs agree with the fifth review's corrected evidence. Ten additional cases comprise four genuine named-effect attacks, a pure module-constant control, delegation-shadow and computed-list escapes, a configuration-projection example, a registration-record example, and one rejected constructor-alias experiment. Appendix A quotes the sources and exact results. The known missing-field probes are successful checks with failed runs, not successful executions.

The walk was executed read-only through its `Scope` API with a small stub producer and no producer-cache/closure derivation. Bytecode writing was disabled before importing repository Python. This isolates registration resolution and traversal; it is **not** a run of `make ext_hook_scope`, a patch implementing the future rule, or a measurement of the whole installable universe. N51's returned binding is directly measured; N52's future gate consequence is an explicit inference from where the proposed new rejection is emitted.

No repository target was run: the compiler-row script writes under `scripts/dst`, and other targets can generate artifacts. No ABI-8 package migration, TUI decision service, provider inference, journal crash simulation, cost benchmark, or strict replay integration was implemented or executed. I did not re-fetch external SDK/model-route pages or endorse their current state; the ADR's dated attributed evidence and implementation-time recheck remain such. Of the fifth review's 24 attacks, I independently reran its five fully printed modules, not all 24 unpublished source bodies. The full table was read and its 20/1/3 classification checked.

No subagents, commits, Herdr commands or pane operations were used. No evaluator-worktree file contents were read or changed. An initial broad filename discovery listed paths under `/workspaces`; those paths were not opened or used. The sole repository write is this review file. Compiler sources, drivers and captured output are outside the repository. Model/HEAD/SHA provenance and final integrity checks follow the appendix.

## Appendix A. Compiler probes, walk fixtures, and exact results

### A.1 Environment and commands

All working directories, local manifests, sources and logs for these commands were outside the repository. The relevant commands were:

```bash
cd /tmp/adr001-v06-codex-vzzcbryn
ailang --version
ailang check repro/<case>.ail
# Only after check exit 0:
ailang run --caps IO,FS --entry main repro/<case>.ail
python3 walk_probes.py
```

The per-module driver used `subprocess.run` and captured stdout followed by stderr; the quotations below retain that combined output. The initial 42 cases and three added cases form the 45 unique compiler cases; `registration_record` was rechecked after changing its config field to actual `Json`. Its final source and final result are quoted. Walk output is from the final source. No source is presented as an actual ABI-8 consumer; `boundary_types.ail` deliberately supplies a small pure callback slot for language and reader tests.

**`ailang.toml`**

```toml
[package]
name = "local/repro"
version = "0.1.0"
edition = "1"
module_prefix = "repro"
ailang = ">=0.33.0"

[dependencies]
```

**`repro/types.ail`**

```ailang
module repro/types
export type PureCtx = { name: string }
export type Slot = Pure((PureCtx) -> int)
export type FsCtx = { name: string, world: int, ports: { file_read: (int, string) -> string ! {FS} } }
export type FsSlot = Fs((FsCtx) -> int ! {FS})
```

**`repro/helpers.ail`**

```ailang
module repro/helpers
import repro/types (PureCtx)
export type W = { f: (PureCtx) -> int }
export func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
```

**`repro/boundary_types.ail`**

```ailang
module repro/boundary_types
export type Ctx = { name: string }
export type Capability = ToolPolicy((Ctx) -> int)
```

### A.2 Outcome ledger

`—` means not run because checking failed. A check exit of 0 with run exit 1 is not a successful effect escape. The invalid `constructor_shadow` experiment is explicitly retained so it cannot be mistaken for supporting evidence.

| Case | Origin | Check | Run |
|---|---|---:|---:|
| `captured` | printed prior source | 1 | — |
| `capturedannot` | printed prior source | 1 | — |
| `capturednamed` | printed prior source | 1 | — |
| `clean` | printed prior source | 0 | 0 |
| `direct` | printed prior source | 1 | — |
| `fs_direct` | printed prior source | 1 | — |
| `fs_direct_io` | printed prior source | 1 | — |
| `fs_missing` | printed prior source | 0 | 1 |
| `fs_named` | printed prior source | 1 | — |
| `fs_named_io` | printed prior source | 1 | — |
| `fs_smuggle` | printed prior source | 0 | 0 |
| `fs_smuggle_norow` | printed prior source | 1 | — |
| `helper` | printed prior source | 1 | — |
| `localannot` | printed prior source | 1 | — |
| `localrecord` | printed prior source | 1 | — |
| `localunannot` | printed prior source | 1 | — |
| `missingannot` | printed prior source | 0 | 1 |
| `missingnamed` | printed prior source | 1 | — |
| `missingport` | printed prior source | 0 | 1 |
| `missingworld` | printed prior source | 1 | — |
| `n_dec_prepare_escape` | printed prior source | 0 | 0 |
| `n_fs_named_indirect` | printed prior source | 1 | — |
| `n_fs_named_localsmuggle` | printed prior source | 1 | — |
| `n_fs_passthru_captured2` | printed prior source | 0 | 0 |
| `n_pure_named_localsmuggle` | printed prior source | 1 | — |
| `n_pure_passthru_captured` | printed prior source | 0 | 0 |
| `n_pure_passthru_capturedfn` | printed prior source | 1 | — |
| `n_pure_passthru_xmod` | printed prior source | 1 | — |
| `named` | printed prior source | 1 | — |
| `q_named_paren_apply` | printed prior source | 0 | 0 |
| `q_named_partial` | printed prior source | 0 | 0 |
| `q_named_recfield_named` | printed prior source | 1 | — |
| `q_named_shadow` | printed prior source | 0 | 0 |
| `q_named_toplevel_apply` | printed prior source | 1 | — |
| `n_pure_passthru_unannot` | reconstructed N44 | 0 | 0 |
| `delegate_shadow` | new | 0 | 0 |
| `computed_list` | new | 0 | 0 |
| `registration_record` | new | 0 | 0 |
| `config_projection` | new | 0 | 0 |
| `named_match_record` | new | 1 | — |
| `named_list_lambda` | new | 1 | — |
| `named_tuple_lambda` | new | 1 | — |
| `named_module_env` | new | 1 | — |
| `named_static_constant` | new | 0 | 0 |
| `constructor_shadow` | new | 1 | — |

Totals: **45 final case results; 28 rejected; 17 accepted and run; 14 runs exit 0 and three exit 1.** One of the 28 rejected cases is an invalid constructor-alias setup, not an effect-checking control. The historical result claims are check/run outcomes, not byte-equality of compiler diagnostics.

### A.3 New compiler sources and exact results

#### `delegate_shadow`

Check `0`; run `0`. Source SHA-256 `9331f51efa51643b036b54013d5e28966057625b4c65170c4a8b74b58357516f`.

```ailang
module repro/delegate_shadow
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
func make_hooks(_n: int) -> [Capability] { [ToolPolicy(body)] }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; let make_hooks = func(_n: int) -> [Capability] { [ToolPolicy(func(ctx: Ctx) -> int { apply(ctx,w) })] }; make_hooks(0) }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/delegate_shadow.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/delegate_shadow.ail
NAMED RULE ESCAPE
result=1
```

#### `computed_list`

Check `0`; run `0`. Source SHA-256 `535063b7959e72c735546ade0a236591b82f52b05b31c810ebc83becfd0d5864`.

```ailang
module repro/computed_list
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; if true then [ToolPolicy(func(ctx: Ctx) -> int { apply(ctx,w) })] else [] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/computed_list.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/computed_list.ail
NAMED RULE ESCAPE
result=1
```

#### `registration_record`

Check `0`; run `0`. Source SHA-256 `49167e7dd4831a6e5634b34dea6b033414b55e20cdfcefea8df9ed1e95836833`.

```ailang
module repro/registration_record
import std/io (println)
import std/json (Json, JString)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
type Registration = { config: Json, caps: [Capability] }
export func register_with_config(_cfg: int) -> Registration { { config: JString("data"), caps: [ToolPolicy(body)] } }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0).caps, {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/registration_record.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/registration_record.ail
result=1
```

#### `config_projection`

Check `0`; run `0`. Source SHA-256 `4033f266607a3c78bffe7780ae52c15724f392edd617ff1b76d8cab327db5f25`.

```ailang
module repro/config_projection
import std/io (println)
import std/json (Json, JString)
type Ctx = { ext_config: Json }
type State = { question_config: Json, interpretation_config: Json }
func prepare(ctx: Ctx, _state: State) -> string { match ctx.ext_config { JString(s) => s, _ => "fallback" } }
export func main() -> () ! {IO} {
 let same: State = { question_config: JString("fixed"), interpretation_config: JString("fixed") };
 println(prepare({ext_config: JString("question A")}, same));
 println(prepare({ext_config: JString("question B")}, same))
}
```

Check output:

```text
→ Type checking repro/config_projection.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/config_projection.ail
question A
question B
```

#### `named_match_record`

Check `1`; run `not run`. Source SHA-256 `c7c843c828963a3359a7b32460d3cfb633460762628ee9135a1a69ab4f07a8a6`.

```ailang
module repro/named_match_record
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { match { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } } { w => apply(ctx,w) } }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/named_match_record.ail...
→ Effect checking...
Error: effect checking failed in repro/named_match_record: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T
  Suggested fix:     func body(...) -> T ! {IO}
```

#### `named_list_lambda`

Check `1`; run `not run`. Source SHA-256 `2da49cf2993980e42a9e99039a8201537725e15cae7f30f5ec216f60430b4646`.

```ailang
module repro/named_list_lambda
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { let fs = [func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 }]; match fs { f :: _ => f(ctx), [] => 0 } }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/named_list_lambda.ail...
→ Effect checking...
Error: type error in repro/named_list_lambda (decl 2): type unification failed at [function application at repro/named_list_lambda.ail:7:81]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `named_tuple_lambda`

Check `1`; run `not run`. Source SHA-256 `eaee7daf50d46aca15e0c3ae858b2e804f9671dbacaf06c4864af3b2daa65dc1`.

```ailang
module repro/named_tuple_lambda
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { let pair = (func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 }, 0); match pair { (f,n) => f(ctx) } }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/named_tuple_lambda.ail...
→ Effect checking...
Error: type error in repro/named_tuple_lambda (decl 2): type unification failed at [function application at repro/named_tuple_lambda.ail:7:81]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `named_module_env`

Check `1`; run `not run`. Source SHA-256 `504fa3a5ff363c45b8dc967f29a212aeb07af9d91938c484853172c3341e3373`.

```ailang
module repro/named_module_env
import std/io (println)
import std/env (getEnvOr)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
let policy = getEnvOr("ADR_REVIEW_VALUE", "")
func body(ctx: Ctx) -> int { if policy == "" then 0 else 1 }
export func register_with_config(_cfg: int) -> [Capability] { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/named_module_env.ail...
→ Effect checking...
Error: effect checking failed in repro/named_module_env: Effect checking failed for function 'policy'
  Function uses effects not declared in signature

  Missing effects: Env

  Current signature: func policy(...) -> T
  Suggested fix:     func policy(...) -> T ! {Env}
```

#### `named_static_constant`

Check `0`; run `0`. Source SHA-256 `30552edc68c7d6df6b5316f9bd086de849d2238f2d77823c8f6ab8c74dccbafe`.

```ailang
module repro/named_static_constant
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
let policy = 7
func body(ctx: Ctx) -> int { policy }
export func register_with_config(_cfg: int) -> [Capability] { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { ToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/named_static_constant.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/named_static_constant.ail
result=7
```

#### `constructor_shadow`

Check `1`; run `not run`. Source SHA-256 `1d7fa3fcb352981c5b38f9356ae5de1baf93f39fab95ce0f06c29af1cb8073bb`.
This setup fails because `RealToolPolicy` is undefined. It supplies no evidence for constructor shadowing or an effect escape.


```ailang
module repro/constructor_shadow
import std/io (println)
import repro/boundary_types (Ctx, Capability, ToolPolicy as RealToolPolicy)
type W = { f: (Ctx) -> int }
func apply(ctx: Ctx, w: W) -> int { w.f(ctx) }
func body(ctx: Ctx) -> int { 1 }
func ToolPolicy(_f: (Ctx) -> int) -> Capability ! {IO} { let w: W = { f: func(c: Ctx) -> int ! {} { let _ = println(c.name); 1 } }; RealToolPolicy(func(ctx: Ctx) -> int { apply(ctx,w) }) }
export func register_with_config(_cfg: int) -> [Capability] ! {IO} { [ToolPolicy(body)] }
func invoke(cs: [Capability], ctx: Ctx) -> int { match cs { RealToolPolicy(f) :: _ => f(ctx), [] => 0 } }
export func main() -> () ! {IO} { println("result=${show(invoke(register_with_config(0), {name: "NAMED RULE ESCAPE"}))}") }
```

Check output:

```text
→ Type checking repro/constructor_shadow.ail...
→ Effect checking...
Error: type error in repro/constructor_shadow (decl 2): undefined variable: RealToolPolicy at repro/constructor_shadow.ail:7:133
```

### A.4 Reproduced/reconstructed compiler sources and exact results

The third review supplied the 21 base modules through `fs_smuggle_norow`; the fourth supplied the eight `n_` modules except the reconstructed unannotated variant; the fifth supplied the five `q_named_` modules. The final unannotated variant is exactly the printed `n_pure_passthru_captured` with its module name changed and the stored lambda's `! {}` deleted. Common imported types are quoted in A.1.

#### `captured`

Check `1`; run `not run`. Source SHA-256 `8369348eb5fa48f6dd45ecf94a8a8716e601b8c0f2c407be7ea2cb5d8fdb7cc5`.

```ailang
module repro/captured
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; Pure(func(ctx: PureCtx) -> int { let _ = p.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/captured.ail...
→ Effect checking...
Error: type error in repro/captured (decl 0): type unification failed at [function application at repro/captured.ail:4:91]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `capturedannot`

Check `1`; run `not run`. Source SHA-256 `aa0a9387084cd00567debcffde17ec23bd0f429d8c1945b251e0ffff743586f1`.

```ailang
module repro/capturedannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; Pure(func(ctx: PureCtx) -> int ! {} { let _ = p.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/capturedannot.ail...
→ Effect checking...
Error: type error in repro/capturedannot (decl 0): type unification failed at [function application at repro/capturedannot.ail:4:91]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `capturednamed`

Check `1`; run `not run`. Source SHA-256 `b794228b29668b3a91fcddc7c55eeb09b4f5c4e4211fc6a27d3a0a17a345c262`.

```ailang
module repro/capturednamed
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let p = { emit: func(s: string) -> () ! {IO} { println(s) } }; p.emit(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/capturednamed.ail...
→ Effect checking...
Error: type error in repro/capturednamed (decl 1): type unification failed at [function application at repro/capturednamed.ail:5:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `clean`

Check `0`; run `0`. Source SHA-256 `5189493c9cda0d3f10dbff5839b9197e81aaefa34edbdc5fd21f4a10a41ada6e`.

```ailang
module repro/clean
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/clean.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/clean.ail
result=1
```

#### `direct`

Check `1`; run `not run`. Source SHA-256 `06c11e41ff653570dca173aa4a4ba1092e539bc10fd02d5540e8e096dbd15642`.

```ailang
module repro/direct
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/direct.ail...
→ Effect checking...
Error: type error in repro/direct (decl 0): type unification failed at [function application at repro/direct.ail:4:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `fs_direct`

Check `1`; run `not run`. Source SHA-256 `e004912d81cf14e5d0861900e40090123d757d33599575637d3455b0579b1d44`.

```ailang
module repro/fs_direct
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_direct.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_direct: Effect checking failed for function 'build'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func build(...) -> T
  Suggested fix:     func build(...) -> T ! {IO}
```

#### `fs_direct_io`

Check `1`; run `not run`. Source SHA-256 `45b812bade130ffc44337432a68611f8ec02f1410c7f22f97abee8e80518ae63`.

```ailang
module repro/fs_direct_io
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot ! {IO} { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_direct_io.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_direct_io: effect checking failed: lambda at repro/fs_direct_io.ail:4:36 uses effects not declared in its ! {FS} annotation
  Missing effects: IO
```

#### `fs_missing`

Check `0`; run `1`. Source SHA-256 `718643a253fc34bbda9f4391066a047a17cb50214f536dc70070eff30a1bc754`.

```ailang
module repro/fs_missing
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func build() -> FsSlot { Fs(func(ctx: FsCtx) -> int ! {FS} { let _ = ctx.ports.clock_now(ctx.world); 1 }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_missing.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/fs_missing.ail
Error: execution failed: record has no field: clock_now
```

#### `fs_named`

Check `1`; run `not run`. Source SHA-256 `95df3955752e2b94618e5180cf9e520c00cf306b73c3d9daafd19bf017516868`.

```ailang
module repro/fs_named
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func body(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_named.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_named: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}
```

#### `fs_named_io`

Check `1`; run `not run`. Source SHA-256 `782de960ad606d17c87bf45b140db4be31e02561b6dc86697f6c293ce8f44729`.

```ailang
module repro/fs_named_io
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
func body(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 }
func build() -> FsSlot ! {IO} { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_named_io.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_named_io: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}
```

#### `fs_smuggle`

Check `0`; run `0`. Source SHA-256 `12c1022180c78b850746ad490cff6bc6e4abc593e3c10ff29104beb34beb71e0`.

```ailang
module repro/fs_smuggle
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func build() -> FsSlot ! {IO} { let w: W = { f: func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 } }; Fs(w.f) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_smuggle.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/fs_smuggle.ail
IO OUTSIDE FS VIEW
result=1
```

#### `fs_smuggle_norow`

Check `1`; run `not run`. Source SHA-256 `1a2bd51f199fb16981434738275bb41e23d65366f1a59e7b7270527856afb89d`.

```ailang
module repro/fs_smuggle_norow
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func build() -> FsSlot { let w: W = { f: func(ctx: FsCtx) -> int ! {FS} { let _ = println(ctx.name); 1 } }; Fs(w.f) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/fs_smuggle_norow.ail...
→ Effect checking...
Error: effect checking failed in repro/fs_smuggle_norow: Effect checking failed for function 'build'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func build(...) -> T
  Suggested fix:     func build(...) -> T ! {IO}
```

#### `helper`

Check `1`; run `not run`. Source SHA-256 `dec773e707403be5ace07535485fcf8569c8539c5f8ce189ec34f96174292236`.

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

Check output:

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

#### `localannot`

Check `1`; run `not run`. Source SHA-256 `c462cc75bf0be2988dd0af0e868b715e3a4e11d10f2ab7234853f7db02339dc0`.

```ailang
module repro/localannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot ! {IO} { let w: W = { f: func(ctx: PureCtx) -> int ! {} { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/localannot.ail...
→ Effect checking...
Error: type error in repro/localannot (decl 0): type unification failed at [function application at repro/localannot.ail:5:118]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `localrecord`

Check `1`; run `not run`. Source SHA-256 `79c60ab0b14d6893f69ba82821129326be9710c6f201775be67cac8e514394b1`.

```ailang
module repro/localrecord
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot { let w: W = { f: func(ctx: PureCtx) -> int ! {} { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/localrecord.ail...
→ Effect checking...
Error: type error in repro/localrecord (decl 0): type unification failed at [function application at repro/localrecord.ail:5:111]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `localunannot`

Check `1`; run `not run`. Source SHA-256 `5ed79b8c34c3879ed0cd1fbfd311af1ca94b0deaec462d943492c026ee8a4c6b`.

```ailang
module repro/localunannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func build() -> Slot ! {IO} { let w: W = { f: func(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 } }; Pure(w.f) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/localunannot.ail...
→ Effect checking...
Error: type error in repro/localunannot (decl 0): type unification failed at [function application at repro/localunannot.ail:5:113]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `missingannot`

Check `0`; run `1`. Source SHA-256 `e2038692cecd482ec8f323caec3e327420b3fb41542183730d72654715bca1b8`.

```ailang
module repro/missingannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int ! {} { let _ = ctx.ports.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/missingannot.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/missingannot.ail
Error: execution failed: record has no field: ports
```

#### `missingnamed`

Check `1`; run `not run`. Source SHA-256 `6b0cf197446b2fd2cb1056f2944bc9b540ac5395c8605a1421edeca8c7424917`.

```ailang
module repro/missingnamed
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let _ = ctx.ports.emit(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/missingnamed.ail...
→ Effect checking...
Error: type error in repro/missingnamed (decl 0): type unification failed at [field access at repro/missingnamed.ail:4:45]: record field 'ports' not found in concrete record
```

#### `missingport`

Check `0`; run `1`. Source SHA-256 `a734516bc3cbd1e02789012c83022f1994d430922816defbfae9a8450efca0e2`.

```ailang
module repro/missingport
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let _ = ctx.ports.emit(ctx.name); 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/missingport.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/missingport.ail
Error: execution failed: record has no field: ports
```

#### `missingworld`

Check `1`; run `not run`. Source SHA-256 `e91fd4dc46c18c2b65239e72dbc987778975a0a73496f3db2705357917519801`.

```ailang
module repro/missingworld
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func build() -> Slot { Pure(func(ctx: PureCtx) -> int { let w = ctx.world; 1 }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/missingworld.ail...
→ Effect checking...
Error: type error in repro/missingworld (decl 0): type unification failed at [function application at repro/missingworld.ail:4:28]: failed to unify parameter 0: failed to unify parameter 0: record field 'world' not found in concrete record
```

#### `n_dec_prepare_escape`

Check `0`; run `0`. Source SHA-256 `bd3d65e5b5f4854b0a88acaecd07187bee262296f069cf7a4aa9fa1142267f09`.

```ailang
module repro/n_dec_prepare_escape
import std/io (println)
import repro/types (PureCtx)
type Prep = Immediate(int) | Query(int)
type Judge = DJ((PureCtx, string) -> Prep)
type W = { f: (PureCtx, string) -> Prep }
func run_prepare(ctx: PureCtx, cand: string, w: W) -> Prep { w.f(ctx, cand) }
func build() -> Judge ! {IO} {
  let w: W = { f: func(c: PureCtx, cand: string) -> Prep ! {} { let _ = println("EXFIL candidate=${cand} name=${c.name}"); Immediate(1) } };
  DJ(func(ctx: PureCtx, cand: string) -> Prep { run_prepare(ctx, cand, w) })
}
func invoke(j: Judge, ctx: PureCtx, cand: string) -> Prep { match j { DJ(f) => f(ctx, cand) } }
export func main() -> () ! {IO} {
  let r = invoke(build(), {name: "pure-ctx"}, "secret candidate text");
  match r { Immediate(n) => println("result=${show(n)}"), Query(n) => println("q=${show(n)}") }
}
```

Check output:

```text
→ Type checking repro/n_dec_prepare_escape.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/n_dec_prepare_escape.ail
EXFIL candidate=secret candidate text name=pure-ctx
result=1
```

#### `n_fs_named_indirect`

Check `1`; run `not run`. Source SHA-256 `e409698c9c717e749090ab5a8446f4095825a7dcc6c23d2b1353f7996a659c35`.

```ailang
module repro/n_fs_named_indirect
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func mk() -> W ! {IO} { { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } } }
func body(ctx: FsCtx) -> int ! {FS} { let w = mk(); w.f(ctx) }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/n_fs_named_indirect.ail...
→ Effect checking...
Error: effect checking failed in repro/n_fs_named_indirect: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}
```

#### `n_fs_named_localsmuggle`

Check `1`; run `not run`. Source SHA-256 `f470d2c26579b399060ea78d209f110fac492abac752f50c9f797135a6765f42`.

```ailang
module repro/n_fs_named_localsmuggle
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func body(ctx: FsCtx) -> int ! {FS} { let w: W = { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } }; w.f(ctx) }
func build() -> FsSlot { Fs(body) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/n_fs_named_localsmuggle.ail...
→ Effect checking...
Error: effect checking failed in repro/n_fs_named_localsmuggle: Effect checking failed for function 'body'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func body(...) -> T ! {FS}
  Suggested fix:     func body(...) -> T ! {FS, IO}
```

#### `n_fs_passthru_captured2`

Check `0`; run `0`. Source SHA-256 `14af6489cd31fec6b273e0b2f0eaeda399a721b31612a9635b3c0590552ac33a`.

```ailang
module repro/n_fs_passthru_captured2
import std/io (println)
import repro/types (FsCtx, FsSlot, Fs)
type W = { f: (FsCtx) -> int ! {FS} }
func apply(ctx: FsCtx, w: W) -> int ! {FS} { w.f(ctx) }
func build() -> FsSlot ! {IO, FS} { let w: W = { f: func(c: FsCtx) -> int ! {FS} { let _ = println(c.name); 1 } }; Fs(func(ctx: FsCtx) -> int ! {FS} { apply(ctx, w) }) }
func invoke(s: FsSlot, ctx: FsCtx) -> int ! {FS} { match s { Fs(f) => f(ctx) } }
export func main() -> () ! {IO, FS} { let ctx: FsCtx = { name: "IO OUTSIDE FS VIEW", world: 0, ports: {file_read: func(w: int, path: string) -> string ! {FS} { "" } } }; println("result=${show(invoke(build(), ctx))}") }
```

Check output:

```text
→ Type checking repro/n_fs_passthru_captured2.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/n_fs_passthru_captured2.ail
IO OUTSIDE FS VIEW
result=1
```

#### `n_pure_named_localsmuggle`

Check `1`; run `not run`. Source SHA-256 `64c2354f8b470875d34715049aff40202c8f2779ca3cd5fe6d6881fff881c2da`.

```ailang
module repro/n_pure_named_localsmuggle
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func body(ctx: PureCtx) -> int { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; w.f(ctx) }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/n_pure_named_localsmuggle.ail...
→ Effect checking...
Error: type error in repro/n_pure_named_localsmuggle (decl 1): type unification failed at [function application at repro/n_pure_named_localsmuggle.ail:6:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `n_pure_passthru_captured`

Check `0`; run `0`. Source SHA-256 `68635e91ddf9d5154fb0b1a277005ff10c9fe2e3cd7fe563e575a6572aef99ef`.

```ailang
module repro/n_pure_passthru_captured
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/n_pure_passthru_captured.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/n_pure_passthru_captured.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

#### `n_pure_passthru_capturedfn`

Check `1`; run `not run`. Source SHA-256 `bf0eb03f8a2043dec41bd9c537dd6e4e879c45c58ff7012531c7d28e4d8946a7`.

```ailang
module repro/n_pure_passthru_capturedfn
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func apply(ctx: PureCtx, g: (PureCtx) -> int) -> int { g(ctx) }
func build() -> Slot ! {IO} { let g = func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 }; Pure(func(ctx: PureCtx) -> int { apply(ctx, g) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/n_pure_passthru_capturedfn.ail...
→ Effect checking...
Error: type error in repro/n_pure_passthru_capturedfn (decl 1): type unification failed at [function application at repro/n_pure_passthru_capturedfn.ail:5:104]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `n_pure_passthru_xmod`

Check `1`; run `not run`. Source SHA-256 `c7575bafc7a300412f717f15ed10a6c25db7e38e7e5298aca3deeeaca6d60545`.

```ailang
module repro/n_pure_passthru_xmod
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
import repro/helpers (W, apply)
func build() -> Slot { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/n_pure_passthru_xmod.ail...
→ Effect checking...
Error: type error in repro/n_pure_passthru_xmod (decl 0): type unification failed at [let annotation w at repro/n_pure_passthru_xmod.ail:5:24]: failed to unify record field 'f': failed to unify effect rows: incompatible closed rows: r1 has extra labels [IO], r2 has extra labels []
```

#### `named`

Check `1`; run `not run`. Source SHA-256 `a83ddf741b02bd91d43a27adf43e0e441ae93b6ac4021d92c6442f6e2f28bc84`.

```ailang
module repro/named
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
func body(ctx: PureCtx) -> int { let _ = println(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/named.ail...
→ Effect checking...
Error: type error in repro/named (decl 1): type unification failed at [function application at repro/named.ail:5:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `q_named_paren_apply`

Check `0`; run `0`. Source SHA-256 `b2b1d7ad141669e44a6e53f2ab4ca0a0147a119135b3101f6cefd049e0bb47b3`.

```ailang
module repro/q_named_paren_apply
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { (w.f)(ctx) }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/q_named_paren_apply.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/q_named_paren_apply.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

#### `q_named_partial`

Check `0`; run `0`. Source SHA-256 `4dc60f37c987cd06711f3dcb56a77b21ff6eded7c2d5f1c106b8e2457ad62bed`.

```ailang
module repro/q_named_partial
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply_w(w: W) -> (PureCtx) -> int { func(ctx: PureCtx) -> int { w.f(ctx) } }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(apply_w(w)) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/q_named_partial.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/q_named_partial.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

#### `q_named_recfield_named`

Check `1`; run `not run`. Source SHA-256 `0e26391526211f3905d14b58a264d1ef92a4bb50383cbfbe946fa8b9c76280c4`.

```ailang
module repro/q_named_recfield_named
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type R = { f: (string) -> () ! {} }
func body(ctx: PureCtx) -> int { let r: R = { f: println }; let _ = r.f(ctx.name); 1 }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/q_named_recfield_named.ail...
→ Effect checking...
Error: type error in repro/q_named_recfield_named (decl 1): type unification failed at [function application at repro/q_named_recfield_named.ail:6:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

#### `q_named_shadow`

Check `0`; run `0`. Source SHA-256 `fd7ca7cc8d14aafa39de5f418b012e3178c060046a014b3e9d9c61a7c34cefe4`.

```ailang
module repro/q_named_shadow
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
func body(ctx: PureCtx) -> int { 1 }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; let body = func(ctx: PureCtx) -> int { apply(ctx, w) }; Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/q_named_shadow.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/q_named_shadow.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

#### `q_named_toplevel_apply`

Check `1`; run `not run`. Source SHA-256 `6ec3aa6a44fe3d95dc465a1a56f1988e462bb1d3ec07a80ffc0ec3b00fb9c274`.

```ailang
module repro/q_named_toplevel_apply
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
func body(ctx: PureCtx) -> int { apply(ctx, w) }
func build() -> Slot { Pure(body) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/q_named_toplevel_apply.ail...
→ Effect checking...
Error: effect checking failed in repro/q_named_toplevel_apply: Effect checking failed for function 'w'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func w(...) -> T
  Suggested fix:     func w(...) -> T ! {IO}
```

#### `n_pure_passthru_unannot`

Check `0`; run `0`. Source SHA-256 `47d6a571cfe8c78b2e512fc99d1e7f4118672d5cd343df16a356856ab19a91a5`.

```ailang
module repro/n_pure_passthru_unannot
import std/io (println)
import repro/types (PureCtx, Slot, Pure)
type W = { f: (PureCtx) -> int }
func apply(ctx: PureCtx, w: W) -> int { w.f(ctx) }
func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
func invoke(s: Slot, ctx: PureCtx) -> int { match s { Pure(f) => f(ctx) } }
export func main() -> () ! {IO} { println("result=${show(invoke(build(), {name: "EFFECT WITH NO PORTS OR WORLD"}))}") }
```

Check output:

```text
→ Type checking repro/n_pure_passthru_unannot.ail...
→ Effect checking...

✓ No errors found!
```

Run output:

```text
→ Type checking...
→ Effect checking...
✓ Running repro/n_pure_passthru_unannot.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

### A.5 Read-only walk driver and measured results

This driver imports the repository tool with Python bytecode writes disabled. Its stub producer classifies only `print`/`println` as effectful; no claim about real producer-cache or whole-closure behavior follows. The test measures which registration/binding the existing reader selects. No future shape check has been patched into the repository or silently assumed to exist.

```python
import sys, importlib.util, json
from pathlib import Path
sys.dont_write_bytecode=True
root=Path(__file__).parent
p=Path('/workspaces/motoko_agent/tools/ext_ambient_inventory/hook_scope.py')
spec=importlib.util.spec_from_file_location('review_hook_scope',p)
hs=importlib.util.module_from_spec(spec);sys.modules[spec.name]=hs;spec.loader.exec_module(hs)
class Producer:
 def classify(self,mpath,src):
  return ('EFFECTFUL',['IO']) if src in ('println','print') else ('PURE',[])
def resolve(path):return ('std',path) if path.startswith('std/') else ('residue',path)
out={}
for name in ['delegate_shadow','computed_list','named_static_constant','registration_record']:
 f=root/'repro'/f'{name}.ail'
 if not f.exists():continue
 sc=hs.Scope(name,f,[f],root,resolve)
 located=sc.locate();ambient,ports=sc.walk(Producer(),{},[]) if located else ([],[])
 out[name]={'located':located,'bindings':{k:v[1] for k,v in sc.bindings.items()},'producing_locals':sorted(sc.producing_locals),'verdict':sc.verdict(ambient),'rejections':[(r.shape,r.detail) for r in sc.rejections],'ambient':ambient,'reached':[s for _,s in sc.reached]}
print(json.dumps(out,indent=2));(root/'walk_results.json').write_text(json.dumps(out,indent=2))
```

```json
{
  "delegate_shadow": {
    "located": true,
    "bindings": {
      "ToolPolicy[0]": "body"
    },
    "producing_locals": [],
    "verdict": "HOOK-PORT-MEDIATED",
    "rejections": [],
    "ambient": [],
    "reached": [
      "ToolPolicy[0]"
    ]
  },
  "computed_list": {
    "located": false,
    "bindings": {},
    "producing_locals": [],
    "verdict": "HOOK-UNRESOLVED",
    "rejections": [
      [
        "capability-list-unresolvable",
        "tail expression `if true then [ToolPolicy(func(ctx: Ctx) -> int { apply(ctx,w` builds the capability list by an expression rather than writing it as a literal -- literal lists only"
      ]
    ],
    "ambient": [],
    "reached": []
  },
  "named_static_constant": {
    "located": true,
    "bindings": {
      "ToolPolicy[0]": "body"
    },
    "producing_locals": [],
    "verdict": "HOOK-PORT-MEDIATED",
    "rejections": [],
    "ambient": [],
    "reached": [
      "ToolPolicy[0]"
    ]
  },
  "registration_record": {
    "located": false,
    "bindings": {},
    "producing_locals": [],
    "verdict": "HOOK-UNRESOLVED",
    "rejections": [
      [
        "capability-list-unresolvable",
        "tail expression `{ config: JString(\"    \"), caps: [ToolPolicy(body)] }` builds the capability list by an expression rather than writing it as a literal -- literal lists only"
      ]
    ],
    "ambient": [],
    "reached": []
  }
}
```

The delegated-shadow result reaches a clean `body` that is not the callback executed. The computed-list result has no bindings to check. The new registration record also has no bindings under the current grammar, even though its actual named callback is harmless. These are distinct from a transitive walk rejecting an otherwise correctly enumerated named binding.

## Provenance and final integrity check

- Codex session ID: `01a0bec3-673b-71d1-bda0-f3e796b35d61`.
- Model/effort: **`gpt-6-astra` / `xhigh`**, read from Codex's own session `turn_context` metadata, including the continued turn after the operator renewed the limit. No model change or subagent was used.
- Branch: `arniwesth/031-abi-8-0`.
- HEAD before and after: `2f3ee4d1e83feb677583924131ce08f7cb91b47a`.
- AILANG: v0.33.0; full compiler commit `ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a`; build `2026-09-17_13:18:12`.
- Reviewed ADR: 990 lines before and after.
- ADR SHA-256 before reading: `f24b2b812ed3e8541fc3a2583c377c1a7e0b55efe4f3c0864a74e9369f01d282`.
- ADR SHA-256 after writing this review: `f24b2b812ed3e8541fc3a2583c377c1a7e0b55efe4f3c0864a74e9369f01d282`.
- Historical v0.5 identifier, verified against its review header, not reconstructed from git: 875 lines, SHA-256 `385e81f8a7fac147639a2c6b50c39112ac8f01bd55512928fd24a30a92bbcdc2`.
- `git diff --stat 2062605 HEAD -- src/core packages tools scripts Makefile`: empty. Tracked working-tree diff over those paths: empty.
- Only repository file written by this review: `.agent/projects/031_system_one_decisions/REVIEW-adr001-v0.6-verdicts-codex.md`. No commits; no Herdr pane interaction; no evaluator-worktree contents read or modified.
