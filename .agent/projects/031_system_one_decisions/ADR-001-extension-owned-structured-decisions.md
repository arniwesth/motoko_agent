# ADR-001: Extensions own structured decision questions; the host executes and records them

Date: 2026-09-18 (v0.1, v0.2); 2026-09-20 (v0.3 … v0.8)
Status: **Accepted on artifacts, 2026-09-21 (operator, at PLAN-001 `P0G`), with Amendment 1** — v0.8 was
the last text-only revision; the freeze evidence (items 1, 2(a)(b)(c) and 8) is recorded in PLAN-001 §9.
The ABI is frozen at 8.0 under the 8.x rule; further changes are numbered amendments (see
"Acceptance rule" under Freeze evidence, and "Amendments"). Seven reviews accepted the direction; findings per round
ran 13, 9, 8, 10, 8, 8, 9, and the seventh could not break the registration boundary as a rule. v0.8
answers N57–N65: the question-dependency obligation gets a real detector, a dry `prepare` at the
epoch boundary (N57); constructor data positions enter the epoch digest (N58); migration carries
allowance and limit and activates, acknowledgments end on reappearance, and every identity new at a
waived resume is inactive (N59–N61); the rule's resolution order is stated as measured and the
suite gains a fourth class (N62); the tool changes the gate needs are named in full (N63); D4's
diagram and the row sum are corrected (N64, N65). **No further review round is requested on this
text.** The operator closed the ring on 2026-09-20 after seven rounds; from v0.8 a change to this
ADR needs an artifact attached — a failing fixture, a compile error, a measured probe — and the
next reviewable object is the plan's evidence, not this prose.
Grounded at: HEAD `2f3ee4d1`; `src/core`, `packages`, `tools`, `scripts` and the Makefile are
byte-identical to the second review's HEAD `2062605` (checked with `git diff --stat`); extension
ABI `7.4`; AILANG v0.33.0 (the pinned build). Reviews: [first](REVIEW-adr001-v0.1-verdicts-fable.md),
[second](REVIEW-adr001-v0.2-verdicts-claude.md), [third](REVIEW-adr001-v0.3-verdicts-codex.md),
[fourth](REVIEW-adr001-v0.4-verdicts-claude-opus-5.md), [fifth](REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md),
[sixth](REVIEW-adr001-v0.6-verdicts-codex.md), [seventh](REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md);
evidence for F1: [NOTE-001](NOTE-001-effect-inference-gap.md), the third review's Appendix A (21
probes), the fourth review's A.2 (the escape set), the fifth review's A.3 (the named-arm attacks,
the shadowing and parenthesized escapes), the sixth review's A.3 (the delegated-shadow and
computed-list escapes, the registration-record shape) and the seventh review's A.3 (the
parameter-shadow escapes, the import-precedence controls, the `DescribeTools` probe), the
decisive ones re-run by the drafter on 2026-09-20 with identical results.
Implementation status: ABI 8.0 types landed (`packages/motoko-ext-abi`, PLAN-001 P0.4 `f7df893c`); core, the 45 registration sites and the dispatch cursor are PLAN-001 P1 (line R); formats, host service and the first consumer are line X.

## Context and established direction

Motoko needs to settle its extension interface before the upcoming major release. A completion
guard's evidence selection, questions, thresholds, abstention, and feedback constitute one
policy. The extension must own that policy; core should execute and record its requests.
The owner has explicitly asked to make the ABI changes now, before the release freezes it.

This applies the [harness-policy boundary](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md)
to model-assisted judgments. The established direction is extension ownership. The concrete
decisions below are proposed for acceptance, with implementation evidence still required.
v0.2 resolved the design questions in v0.1 rather than leaving them as alternatives. v0.3 answers
the second review: the callbacks' context type (D2, F1), the durability transport (D5, F2), the
existing slots' context types at 8.0 (D2), recorded configuration inputs and the live-resume rule
(D6), the evidence sharpenings (D3), the schema-1 superset fold and the `/5` rationale (D7), and
the freeze-evidence rewrite. v0.4 answers the third review: the enforcement boundary the context
types actually give and the registration discipline that closes the rest (D2), both row decisions
and helper migration (D2), the journal write barrier and the two cost lifetimes (D5), policy epochs
on resume (D6), the schema transition and the amendments this ADR requires of ADR-003 and ADR-004
(D7), adapter validation ownership (D3), and gate semantics that agree with the release scope
(freeze item 8). v0.5 answers the fourth review, which broke v0.4's registration rule from inside
its own permitted form: the boundary became named functions only (D2); the schema transition, the
admission equation, identity minting on resume, and the resume row's granularity were specified
(D5–D7). v0.6 answers the fifth review, which showed that named-only cuts the channel by which
configuration reaches a callback: that channel is now host-stamped data (D2, D3), the boundary is
respecified as shape plus compiler (D2), admission moves to the host (D5, D6), and `Identity`
fires on orphaning (D6). v0.7 answers the sixth review: the channel reaches `DescribeTools` and
claims only what it proves (D2), delegation is resolved in scope and the gate has a total
registration-shape result (D2), the identity waiver is completed (D6), and two contradictions of
the drafter's own are removed (D2, D5). v0.8 answers the seventh review and closes the text: the
detector the channel's obligation lacked (D2), constructor data in the digest (D2), the waiver's
missing sentences (D6), the measured resolution order and the tool changes in full (D2), and the
diagram (D4). The response tables at the end map every review item to its text.
This ADR is release-gating: the [release scope](../033_release/ADR-001-release-scope.md) (G5)
puts ABI 8.0 before the tag, because the owner wants the ABI to change little afterwards.

## Current behavior and external evidence

| Surface | Current behavior relevant to this proposal |
|---|---|
| [Capability ABI](../../../packages/motoko-ext-abi/types.ail) | `SolverJudge` has effect row `{Process}`; `ToolPolicy` is pure. Neither can call the current AI port **from a named or annotated binding**. An unannotated inline atom can: on v0.33.0 the checker does not infer the effects of `ctx.ports.ai_step(ctx.world, …)` into the lambda's row, so the call passes any payload row ([NOTE-001](NOTE-001-effect-inference-gap.md) §3, probes p1/p16/p18). |
| Same ABI | `ExtCtx` has transcript, waits, work declarations, artifacts, and ports, but lacks typed verification and tool-outcome evidence. `Accept(string)` can replace a candidate. |
| [Extension runtime](../../../src/core/ext/runtime.ail) | Every finalize atom runs in registry/atom order, threading the world. Feedback wins over acceptance, then no opinion. The fold has `ExtPorts`, not core `Ports`. |
| [Registry normalization](../../../src/core/ext/registry_normalize.ail) | Repeated votes are rejected by capability kind. This does not yet reject a legacy and a new variant in the same vote family. |
| [Session](../../../src/core/session.ail) | Nonblank candidates encounter DP7, open-wait handling, and then solver judges. Blank approvals have a later DP7 check. DP7's `Approve` also covers disabled verification and some infrastructure failures. |
| Same session code | Finalize receives `st.msgs ++ [assistant_msg]`. Compaction changes the model payload, not that stored history. Existing marker-count guards are not reset by ordinary compaction. |
| Same session code | `ext_ai_step` discards model usage. Adding decision usage to session accounting requires a new path through dispatch and candidate classification. |
| [Tool phase](../../../src/core/tool_phase.ail) | Tool-policy dispatch sees proposed calls before execution, including steps that never invoke a solver judge. |
| [Execution program](../../../src/core/dst_program.ail), [journal](../../../src/core/journal.ail) | Current formats are `execution-program/4` and journal schema 1. Neither defines the decision records proposed here. |
| [Journal](../../../src/core/journal.ail) (`:28-31`) | The child never writes. The journal file is the host's (ADR-003 D3, "one writer: the host"); the child's contribution is the events it emits, written by the host in host order. Anything the child must have "durably recorded before X" needs a host round-trip. |

The motivating backend is `typesafe/jev-1.13` on
[OpenRouter](https://openrouter.ai/typesafe/jev-1.13). The official SDK exposes
`POST /api/alpha/decisions` with model, state, and named questions:
[transport](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/funcs/alphaDecisionsCreate.ts),
[request types](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionsrequest.ts).
Its [choice answer](https://github.com/OpenRouterTeam/typescript-sdk/blob/main/src/models/decisionschoiceanswer.ts)
allows absent probabilities and confidence. These primary sources were inspected by the
drafting agent on 2026-09-18; the first reviewer did not independently verify them. The second
reviewer confirmed the endpoint, the request shape (questions as a name-keyed map with kinds
`Choice`/`Noul`/`Score`; optional `provider`, `sessionId`, `trace`, `user`) and the optional
`confidence`/`probabilities` fields, and could not confirm the `typesafe/jev-1.13` route (404 and a
truncated model listing). No paid
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
  prepare:   (PureCtx, candidate: string) -> JudgePreparation,
  interpret: (PureCtx, candidate: string, DecisionRequest, DecisionObservation)
             -> FinalizeDecision
)
JudgePreparation = Immediate(FinalizeDecision) | Query(DecisionRequest)

DecisionToolPolicy(
  descriptor: DecisionPolicyDescriptor,
  prepare:   (PureCtx, ToolCallEnvelope) -> ToolPreparation,
  interpret: (PureCtx, ToolCallEnvelope, DecisionRequest, DecisionObservation)
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

PureCtx = ExtCtx without `ports` and without `world`   -- every other field, including the
                                                       -- D3 additions, is present
```

Both callbacks are pure and are positional constructor arguments. **What the context types
guarantee is restricted supplied authority, not compile-time purity (F1, corrected by N23).**
`PureCtx` carries no port value and no world token, so a callback cannot *successfully* invoke a
port: there is none to invoke, and the host builds the context from its full `ExtCtx` at the
leaf. On the pinned v0.33.0 that is the whole guarantee. Three measured facts bound it, all from
the third review's probe set, which the drafter re-ran with identical results (Appendix A of
[REVIEW v0.3](REVIEW-adr001-v0.3-verdicts-codex.md); 21 cases, 0 mismatches on 2026-09-20):

1. An inline lambda may call a field its parameter type does not have — `ctx.ports.emit(…)` on a
   context with no `ports` — and `ailang check` accepts it, annotated or not; the call fails at
   invocation with `record has no field: ports`. A named top-level function with the same body is
   rejected. So the compile-time rejection v0.3 claimed does not exist for lambdas; the missing
   field is caught at runtime, as a **host control failure of the registration**, never as an
   `Unavailable` an interpreter may vote on.
2. An unannotated inline lambda's row omits the effects of applying a function stored in a field
   of its own parameter ([NOTE-001](NOTE-001-effect-inference-gap.md) §0–§3; upstream ticket
   `fb_30e82f6bdc5fc8c3`). With no ports in scope this route has nothing to reach, which is what
   the views buy.
3. An annotated `! {FS}` lambda built inside a local record under a registration function that
   itself carries `! {IO}` can perform `println` when invoked — the 017 record-field hole. Without
   the enclosing `IO` row it is rejected; passed as a named function it is rejected.
4. The same hole reaches the **rowless** slot through one intervening named function: an inline
   lambda whose body is one call to a named function, passing its parameter through **plus a
   captured locally-typed record** that holds an annotated lambda, compiles and performs `println`
   from `PureCtx`, from `FsCtx`, and at the real `prepare` arity, where it prints the candidate
   text (fourth review, Appendix A.2 probes 22–24; drafter reproduced all three). **Two**
   preconditions, both ordinary in the tree: a local record type, and a registration function
   whose row declares the smuggled effect — compose's declares `! {Env, FS, AI, Clock, IO, Process,
   Rand}`. The stored lambda need not be annotated: the unannotated variant escapes too (fifth
   review N44; drafter rebuilt and confirmed), which corrects the fourth review's probe table. The
   parenthesized spelling `(w.f)(ctx)` escapes as readily as the dotted one. This is the
   construction v0.4's rule blessed; it is why there is no pass-through arm. Capturing a bare
   function value, or an imported record type, or building the record inside a named function, is
   rejected.
5. A binding that *looks* named is not necessarily one: a local `let body = func(…) { apply(ctx, w) }`
   shadows a top-level `func body`, the compiler permits the shadowing, `Pure(body)` registers the
   lambda, and the effect performs from `PureCtx` (fifth review, `q_named_shadow`; drafter
   reproduced). Nothing in the tree shadows a declaration; the boundary below rejects it anyway.
6. The same shadow one hop earlier: a registration function declares a local
   `let make_hooks = func(…) { [ToolPolicy(func(ctx) { apply(ctx, w) })] }` over a top-level
   `func make_hooks` that returns `[ToolPolicy(body)]` with a clean named `body`; the compiler
   accepts it, the effect performs, and a reader that resolves the delegated call to the top-level
   declaration certifies `body`, which never runs (sixth review, `delegate_shadow`; drafter
   reproduced). A capability list built by an expression — `if … then [ToolPolicy(…)] else []` —
   compiles and performs too, and a reader that only enumerates literal lists never sees its
   payload (`computed_list`; drafter reproduced). A payload, or a delegated callee, bound to a
   **parameter** that shadows a top-level function escapes the same way, and the tool today
   certifies both as named because it never reads a signature (seventh review, `v7_param_shadow`,
   `v7_delegate_param`; drafter reproduced). All are rejections under the rule below.

**Registration boundary (what is enforced, and by what).** Every `Capability` payload callback,
`DescribeTools` included, is a **named top-level function, unshadowed, bound directly** in the
capability list. The boundary has three layers, and v0.6 is explicit about which one carries which
load, because v0.5 put the load on the wrong one:

(a) **The shape rule, in AILANG's scoping order**, over the whole registration, not only the
final binding. The supported registration grammar is small and closed: `register_with_config`
returns `ExtRegistration = { config, caps }` (below) whose `caps` is either a **literal list** of
constructor applications or a **delegated call** to a named function that, recursively, satisfies
this rule; every constructor's function payload is a **bare name** that resolves to a top-level
`func` declaration of the module or an import and is **not** `let`-bound or parameter-bound in the
producing body or in any delegated body on the path. Resolution is lexical at **every hop and
stricter than the compiler's**: a payload name or a delegated callee is looked up in the calling
body's locals and parameters first, then the **home module's** imports, then the home module's own
declarations — never another closure module's — so a local `let make_hooks` over a top-level
`make_hooks` is a rejection (fact 6), exactly as a local `let body` over a top-level `body` is
(fact 5). The pinned compiler's own order is different for imports: v0.33.0 resolves an
**imported** name over a local `let` and over a same-module declaration (`v7_import_shadow`,
`v7_delegate_import_shadow`: the import runs, no effect), so the rule over-rejects a local that
shadows an import. That is the safe direction, taken by design, and the suite scores such rows as
a fourth class (freeze item 2). A computed list (a conditional, a `match`, a concatenation, a call
the reader cannot resolve), an inline lambda of any body, a `let`-bound lambda, a partial
application (`Pure(apply_w(w))`), and any other expression **fail closed**. What the tool must
change to implement this, in full (N63): `func_body` and `_resolve_func` return the signature's
parameter names beside the body, because today the signature is discarded (`:371`, `:415`, `:763`)
and parameters are never read; `Scope.locate` records per hop `(module, parameters, lets)` instead
of overwriting `producing_body` (`:659`), and `_resolve_func` takes that chain and rejects a callee
found in any hop's locals or parameters before consulting imports and declarations; the
declaration table is per home module, not the closure-wide table keyed by bare name (`:557-558`,
`:773-777`), which today resolves a clean `body` to an effectful `body` in another module; and
`_binding_text` consults the chain before declarations (`:916-926`). The self-test's
`capability_list_atoms` and `registration_shape` pins are re-pinned by hand for the
`{ config, caps }` head. This is the rule's whole text.

(b) **The compiler's effect pass over named functions is what enforces effects.** A named function
cannot capture, so a smuggled value must arrive by a call, and every call on the path is charged;
the one place a value arrives without a call, a module-level `let`, is itself effect-checked as a
rowless function. The fifth review's A.3 set is **20 attacks on this arm, one ordinary control,
and three escapes of the *recognizer*** (N56 corrects v0.6's "24 all reject"): the 20 — mutual
recursion, a generic higher-order helper, `pure` and `! {}` declarations, a lying `let` annotation,
a local record and a local sum holding an effectful *named* function, an uppercase-named helper, a
module-level `let` laundered through a typed helper, at `prepare` arity and from `FsCtx` — were all
rejected by the effect pass charging the callback; the control passed; the three escapes
(`q_named_shadow`, `q_named_paren_apply`, `q_named_partial`) are accepted by the bare compiler and
are rejections under (a). The sixth review added an effectful local lambda inside a matched record,
a list and a tuple, and an effectful module-level initializer: all rejected. It also showed that a
named callback **can** read a pure module constant (`named_static_constant`, returns 7) — which is
code, versioned, not registration state — see the channel below. No probe in any suite escapes a
named, unshadowed, directly bound function reached through a resolved delegation.

(c) **The transitive walk is defense-in-depth, with its limits written down.** `hook_scope.py`
resolves the binding to text and walks into named callees (`:880-894`), rejecting a dotted call on
a receiver that is not a supplied port (`applied-local`, `:837-847`), an unknown callee, and an
unresolvable binding. It rejects fact 4's dotted spelling for the right reason. It does **not** see
parenthesized application (`_APPLY` needs an identifier before the parenthesis, `:153`), it skips
uppercase-initial callees as constructors (`:820`), and it checks ports by field name, not receiver
type (`:837-841`). None of these is an escape of the compound boundary — the compiler charges every
one — and the walk's `HOOK-UNRESOLVED` verdicts for door-3 residue (`show`, `intToFloat`,
higher-order parameters) are unrelated to this rule and will remain. The walk is an instrument
whose header says so; it is not the boundary.

**The gate (N43, N52).** The tree-wide derivation (`make ext_hook_scope`, not only its fixture
self-test) joins the gate lane with a **registration-shape result that is total** and a failing
exit. For every installable extension the result is *pass* only when all three hold: the
registration's return shape is supported (the `{ config, caps }` record with a literal or resolved
`caps`); every atom and every function payload was **enumerated**; and every payload satisfies (a).
Unresolved delegation, a computed or unknown list element, an unsupported return form, or an
unresolved binding name is a *fail*, distinct from — and never hidden by — the walk's
`HOOK-UNRESOLVED` residue, which the tool collapses every rejection into today (`:953-956`). A
recognized empty list passes where normalization allows omission. The result is **its own
per-extension field** (`registration_shape_result: pass | fail(reason)`) with its own rejection
shapes, computed from `locate` and the binding pass — not derived from the walk's `rejections`,
because the walk emits `hook-binding-unresolvable` too, for an imported callee outside the closure
(`:882-886`), and on the real tree that fires for five extensions for reasons unrelated to any
registration rule. `emit_hook_scope` exits nonzero from that field alone (`:1122`, through
`derive.py:888`) without changing the shipped `ext_ambient_inventory` verdict. Counting only
binding rejections is not the criterion: a computed list produces zero of them because `walk` runs
only when `locate` succeeds (`:1044-1046`), which is how fact 6's second construction would read
green. "Green" in release G5e means exactly this criterion. The gate's fixtures: a direct named
success; each migrated in-tree site; the direct shadow, the delegated shadow, the **parameter
shadow and the delegated parameter**; a partial application; a computed, a `match`-selected and an
unknown `caps`; a valid empty registration; the **import-shadow controls**, which the gate rejects
and the compiler runs cleanly; and a named callback with unrelated walk residue, which must pass.
On the unmigrated tree the result is red by 35 bindings; "green on the migrated tree" means exactly
that those 35 have moved.

**Migration this implies (N32, N45).** The count at HEAD, as the fifth review measured it over
every constructor application in `packages/` outside the ABI and conformance packages:

| Form | Sites | Where |
|---|---|---|
| Named top-level function (compliant today) | 10 | compaction-structural, context-mode, decision-framework, empty-stop-guard, microrag ×3, omnigraph, scratchpad, compose (`on_build_system_prompt`) |
| `let`-bound lambda | 16 | compose ×2, context-mode ×2, repetition-guard ×2, herdr ×4, a2a, agentcli, ailang-docs, exa-search, mcp, scratchpad |
| Inline lambda | 19 | test-dummy ×4, herdr ×2, progress-contract-guard, four `DescribeTools` forms, eight others: ailang-docs `PromptShaper`, compaction-ai `Compactor`, compose `ToolPolicy`, context-mode, exa-search, omnigraph and scratchpad `PromptShaper`, omnigraph `ToolProvider` |
| **Total** | **45** | 35 change form; 30 of those capture a registration value and migrate through the channel above |

Pricing per package is the plan's, with the fifth review's N41 and N45 tables as the site list.

**Residual, stated.** The shape rule and the walk see in-tree sources resolved through the
repository's path dependencies. A registry-installed extension with no in-tree source meets neither;
for such an extension the guarantee is restricted supplied authority plus the data channel, and the
runtime's missing-field control failure is the only enforcement. The boundary is freeze evidence
(item 2), not a later live-enforcement task.

**The suite and its home (N48).** The regression is the third review's 21 cases, the fourth
review's escape set with the unannotated variant moved from the controls to the escapes (N44), and
the fifth review's shadowing, parenthesized-application and partial-application probes, plus its
20 named-arm attacks and its ordinary control as controls, and the sixth review's delegated-shadow, computed-list and registration-record probes. It lives in `scripts/dst/run_declared_vs_performed.sh` as rows
written through the script's **imported-ABI mechanism** (`write_abi_ctor`, `:945-1000`) — not
`write_lim`, whose single-module probes cannot express the imported-sum rejections the controls
depend on — with the probe sources committed in a fixture directory beside the script's existing
fixtures, named by the plan. It is a regression **for the rule**: it must keep rejecting the
controls and, until the upstream fix lands, keep *accepting* facts 1, 3, 4 and 5 under the bare
compiler, which is what shows the boundary and not the compiler is doing the work. This is not a
sandbox against arbitrary extension code and the ADR does not call it one. Restricted authority
keeps the legacy judge's effect barrier unwidened; the new callback slots enter the pure-slot
coverage criterion on the strength of the views *plus* the boundary, and the host's query leaf
must independently satisfy the recording gates.

**The existing slots get the same treatment at 8.0.** 8.0 is the only window before the freeze
(the [release scope](../033_release/ADR-001-release-scope.md) D1 wants no further re-rows), the
`ExtCtx` literals are being rebuilt for D3 anyway, and the rule below is mechanical. Every
`Capability` callback receives a context whose `ports` record holds **exactly the `ExtPorts`
fields whose declared rows are subsets of the slot's declared row**; a rowless slot receives
`PureCtx`, which also drops `world` because a rowless slot returns no successor state. Rows thus
become documentation of a fact the record type enforces (NOTE-001 §6). Derived from the 7.4 rows:

| Slot row | Slots | Context | `ports` view |
|---|---|---|---|
| `{}` | `PromptShaper`, `BudgetShaper`, `ToolPolicy`, and both decision callbacks | `PureCtx` | none; no `world` |
| `{Process}` | `SolverJudge` | `ProcessCtx` | none (no `ExtPorts` field fits `{Process}`); keeps `world` for `next_state` |
| `{FS}` | `ExitIntent`, `WorkInFlight` | `FsCtx` | `file_read`, `file_write`, `file_remove`, `path_stat`, `dir_list`, `dir_make` |
| `{AI, IO, Trace}` | `Compactor` | `AiCtx` | `ai_step` |
| `{IO, Process, FS, Clock}` | `ResponseInterceptor` | `InterceptCtx` | the six FS ports, `tool_handle`, `clock_now` |
| `{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand, Trace}` (`Trace` added in 8.0) | `ToolProvider` | `ProviderCtx` | all ten fields |

**Both row decisions are closed in 8.0 (N24).** (i) `ToolProvider`'s row gains `Trace`, so
`ProviderCtx` carries all ten fields; the slot already admits `AI`, and excluding the world's
AI port would only push a provider toward the ambient path. (ii) `ExitIntent` and `WorkInFlight`
stay `{FS}`: the two in-tree renderers (`motoko-ext-herdr`) use `file_read` only. `DescribeTools`
takes the extension's configuration and no context (N49, below). **Migration is more than the callback's
parameter type.** AILANG records are closed, so a helper that takes `ExtPorts` or `ExtCtx` no
longer accepts a narrower view: compose's interceptor passes `ctx.ports` to three helpers typed
`ExtPorts`, repetition-guard shares `ExtCtx` helpers between its pure policy and its judge, and
compaction-ai threads `ExtCtx` through its chain. The rule: shared helpers take `PureCtx` (the
data projection every view contains) or the smallest ports record they use; **no dummy ports** to
make an old helper compile. The ABI exports each view type plus a constructor for each, and the
8.x stability rule (D7) covers every exported view, not only `ExtCtx`. The third review's Q-A
table prices this per package and found no registered body that needs a removed port once (i)
holds. `env_get` survives only in `ProviderCtx`, which closes the unrecorded environment read
from a pure slot (NOTE-001 §5 item 2) at the level of supplied authority.

**Configuration reaches a callback as host-stamped data (N41).** A named top-level function
closes over nothing, and a module-level `let` is effect-checked as a rowless function, so nothing
an extension computes at registration — a config record, a cached prompt, a composition mode, a
tool list, a server list — can reach its callback by capture. Thirty of the tree's 45 registration
bindings capture such a value today (fifth review N41). The channel is therefore data:

```text
register_with_config(cfg: RuntimeConfig) -> ExtRegistration ! {…}
ExtRegistration = { config: Json, caps: [Capability] }
ExtEntry        = { id: string, config: Json, caps: [Capability] }     -- host-side registry entry
DescribeTools((Json) -> [ToolSchema])                                  -- was () -> [ToolSchema]
```

`DescribeTools` is the one payload that takes no context, and v0.6 left it at `()`, so the four
catalogs that capture configuration today — a2a and ailang-docs close over discovered schemas,
agentcli reads its provider list, herdr reflects its enabled tools — had no route to it (N49).
It now receives the extension's `config`; the pure catalog (`tool_catalog.ail:107-110`) passes the
entry's `config` where it calls `f()` today. A catalog whose schemas are fixed ignores the
argument.

Registration returns its disclosed configuration beside its capability list. The host keeps it on
the registry entry, **stamps it as `ext_config: Json` on every context view it builds for that
extension** — `PureCtx` and the five effectful views alike — and hashes its canonical JSON as the
extension's **config digest**. A callback decodes what it needs per call. `Json` cannot hold a
function value, so the channel cannot carry an effect: that, plus (b) above, is the whole
guarantee, and no textual tool has to reason about types. Configuration carries no credentials
(D1) — a reviewed serialization rule, since `Json` typing cannot enforce it on a string; the in-tree
captures hold environment-variable *names*, not values — and it is hashed and recorded, as bytes
or a resolvable reference (ADR-004 D1), not only as a digest.

**What the channel proves, stated exactly (N50).** The host stamps and hashes the registration data
returned through this channel, and a named callback can read no *registration-time* state that was
not returned through it. That is the whole fact. A named callback can also read pure module
constants and imports — code, identified by the extension's version — and the transcript,
artifacts and typed evidence on its view, which are recorded with their own provenance (D3, D6),
not under the config digest. And `prepare` sees the **whole** `ext_config` beside the two
descriptor projections the host hands back on `DecisionInvocationState` (D3), so a question
dependency placed in general configuration would change a prepared request without changing
`question_config`. Therefore the conformance obligation stays: **every configuration value that
influences evidence selection or question construction must be represented in `question_config`**,
and every value that influences thresholds, abstention or feedback in `interpretation_config`.
**The detector is a dry `prepare` at the epoch boundary (N57).** Strict replay does *not* detect
this violation: it serves each epoch's recorded configuration, so a re-executed `prepare`
reproduces the recorded request, and the live `Descriptor` row is designed not to fire on general
configuration — v0.7 said otherwise and was wrong. So when a resume accepts a config-digest change
(or a constructor-data change, below) for an extension that registers decision atoms, the host
**re-runs `prepare`** for each such atom on the **last recorded invocation's evidence snapshot**
(recorded under D3/D6) with the new `ext_config` and the unchanged descriptor projections. If the
canonical request differs while the question digest is unchanged, the resume is **refused** —
`--resume-force` overrides, the epoch is appended, and the violation is recorded in it. The dry
`prepare` is pure, reads only recorded inputs, performs no exchange and consumes no ordinal; an
atom with no recorded invocation yet has nothing to compare and passes. This turns the obligation
into something a fixture can show (freeze item 3). The alternative, a restricted question-only view
for `prepare`, was not taken: the dry `prepare` closes the gap without a seventh context type.
Versions identify code/policy revisions, including feedback-template changes. No environment reads
can occur inside the pure callbacks: `PureCtx` has no `env_get`.

**Constructor data positions are in the digest too (N58).** Three constructors carry data beside
their callback — `ToolProvider`'s tool names, `ExitIntent`'s label and `enabled` flag,
`WorkInFlight`'s label (`types.ail:1244-1273`) — and that data is registration-time state the host
acts on without invoking any callback: the catalog advertises the names, the exit machinery reads
the flag, and the ABI header itself says `enabled` is "resolved and captured at registration". It
is outside `config` and outside the kind-only `ext_set_digest`. So the per-epoch config digest
covers **`config` plus the data positions of every atom**, projected as `Json` where the kind
enumeration already reads them (`runtime.ail:1139-1151`), and recorded beside `config` in the epoch
snapshot. A change to them on resume is the same event as a config-digest change.

The kind-only `ext_set_digest` stays kind-only for the `ExtSet` resume row; the config digest is
recorded **per policy epoch** and a change on resume appends a snapshot and continues — the
journal shows the change; refusal is reserved for the question and limit layer of decision atoms
(D6), and an unchanged-kind config edit that alters the system prefix still meets the existing
`Prompt` row — so that editing an extension's configuration is not by itself a forced resume,
which is N37's rule applied to every extension. Strict whole-run replay compares the full config
epoch as well as the two descriptor projections.

**Cost, as an expectation the plan measures.** The host stamps a reference to one immutable value
per extension per epoch and hashes it once per epoch; it does not serialize or copy it per
invocation. What scales with invocation count is the callback's own decoding of what it reads. The
plan bounds the retained configuration size and measures migration of the largest in-tree values
(cached prompts, tool schemas, provider lists) before claiming the cost is small; "cheap against a
hook's cost" is an assumption until then.

**Migration under this channel.** A capturing extension encodes what it captured at registration
and decodes it in the callback. The sixth review's 45-row ledger found that **all 30 captured
values are data** — strings, integers, booleans, lists, and records with no callable field — so no
in-tree site needs a rewrite beyond encode/decode; optional integers need a declared null or tag
convention, and schema strings keep their meaning. A future captured value that is a *function*
cannot cross and becomes a `match` in a named function, which is the intended effect.

Each invocation issues at most one request, containing all questions for one state. Interpretation
receives the exact prepared request and the same evidence snapshot used by preparation. Neither
callback sees a world token: the host threads the successor world itself through the dispatch
result (D4), so there is nothing for an interpreter to execute against. Interpretation cannot
request a second query or mutate artifacts.

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
The adapter sends **no** session, user, or trace identifier (the OpenRouter request type offers
them as optional fields); the canonical request of D6 contains none, and the corpus-privacy line
of ADR-004 D6 argues for sending none.

**Validation ownership (N29).** Under D5's transport the host adapter is the **sole normalizer of
raw provider numbers**: it validates finiteness and domains, applies the tolerance, apportionment
and rounding rules above, and records the integer `DecisionObservation`. The child's codec
validates that integer observation strictly — kinds, IDs, ranges, coverage, nonnegative usage —
and never renormalizes, so there is one float conversion and no rounding drift. Both sides, the
journal fold and replay validate against **one versioned set of fixture vectors** (finite and
non-finite numbers, negative usage, missing optionals, duplicate/extra/missing answers, half
rounding at the boundary, distribution tolerance, remainder ties). The SDK's own schema checks
numeric shape only and is not a substitute; its transport defaults (backoff, retryable 5xx, a
one-hour retry budget, no timeout) are **disabled explicitly** in favour of one attempt under an
end-to-end deadline, so one reservation never covers several upstream charges. The adapter
contract version changes whenever a normalization rule changes. The outbound request is a
projection of the internal invocation identity: D6's record carries the host's identifiers, the
wire request does not.

Duplicate, missing, extra, or mismatched answers invalidate the whole response. Validate kinds,
IDs, ranges, coverage, and nonnegative usage. Missing optional distributions, confidence, or
usage remain `None`; do not manufacture certainty or zero cost. An adapter that cannot supply
a required binary probability or rubric score returns `InvalidResponse`, not an invented value.
An extension can require a distribution and abstain when it is absent. No probability is a
claim of calibration. Cancellation, codec corruption, and strict-replay divergence are host
control failures, never `Unavailable` that an interpreter may turn into a vote.

Batch the following **three `ExtCtx` additions** into 8.0; they are present in every context type of D2, `PureCtx` included:

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
                            interventions_used: int, intervention_limit: int,
                            question_config: Json, interpretation_config: Json,
                            allowance_millicents: int, known_spend_millicents: int,
                            outstanding_millicents: int,
                            run_cost_millicents: int, run_cap_millicents: Option[int] }
DecisionMode = DisabledDecision | ShadowDecision | EnforcingDecision
```

Evidence is constructed from recorded host observations, with occurrence/call IDs providing
provenance. `CommandExit(n)` requires a `ToolCompleted` whose `exit_code` is `n` and is not the
`-1` sentinel (`ports.ail:645-646`: "no subprocess, or a seam that cannot say"); a `-1` maps to
`ToolOutcomeUnknown`. Arbitrary textual tool output and model claims cannot create it. `ToolSucceeded` means the tool reported success,
not that the user's task passed. Unknown, missing, truncated, and historical untyped results stay
explicitly uncertain. Window truncation sets completeness false; an unknown omitted count is
`None`. Full transcript access is not proof that the separate typed window is complete.

The window is **new accumulation** on `C2LoopState`: today the typed `ToolOutcome` is consumed at
dispatch and only its text survives in `st.msgs`. On a live `--resume` the window begins with
`complete_from_session_start = false` and `omitted_count = None`, and fills from the resume point.
Journal schema 2 does **not** carry typed tool outcomes in v1; if a later revision records them,
that is an additive journal record and the resumed window may then be reconstructed as complete.

Verification gating and evidence are separate outputs of the verifier integration. Preserve
today's gate behavior, while distinguishing an actual pass from disabled verification, failed
execution, and missing infrastructure. `VerificationUnavailable` is a **heuristic** classification:
`is_missing_infrastructure` (`session.ail:2231-2239`) is a substring match over verifier output, so
a guard treats that variant as uncertain, never as a pass or a fail. Blank candidates can legitimately see `NotReached` before
the later DP7 gate. Evidence from an earlier invocation must retain its occurrence and must not
be relabeled as current. Workspace revision is optional and may be populated only from an actual
recorded revision mechanism; absent revision means freshness across edits is unknown. This ADR
does not promise a complete file-change set or a filesystem snapshot. A guard requiring those
facts must abstain until an authoritative evidence producer supplies them.

Other hook sites receive truthful evidence where available and `decision_state = None`. Decision
callbacks always receive `Some` with identity and limits, **the descriptor's two configuration
values handed back** (the data the host hashed for D6's identity layers; D2's channel), and **the
ledger terms as of the last decision reply** — the identity's allowance, its known spend and
outstanding reservations, and this run's cost with its cap, `None` when the run is unmetered or
the cap is disabled (`max_cost_millicents ≤ 0`). Which side supplies which term, stated (N47): the
three ledger terms are host-owned and reach the child through a **mirror** seeded by the journal
fold on resume and updated by every decision reply; the two run terms are child-known. The terms
are **informational** — they let `prepare` choose `Immediate` when the budget is thin — and are
not the admission decision, which is the host's (D5). Legacy context fixtures
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
calling core module: build request → advance + decision_query (wire) → host: admit, reserve, call, observe, reply → witness successor world
    ↓ observation and successor world
ext/runtime.ail: interpret, collect vote → next atom with successor world
    ↓ end
merge votes → calling module applies result and journals selected intervention
```

Finalize queries execute through `C2LoopState.provider` in `session.ail`. Tool-policy queries
execute through core `Ports` already supplied to `tool_phase.ail`. Both are scanned by the
driver leaf inventory. Keep the actual port call in each scanned module and teach the inventory
the new request class. The tool-phase leaf may follow the existing `tool_exec` pattern — advance
the world at the leaf in `tool_phase.ail`, witness the returned trace in `session.ail` — so
extracting the private `witness` helper from `session.ail` is optional, not required (N22). Do
not hide a helped leaf inside `ext/runtime.ail`.
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

**Two allowances with two lifetimes (N28).** ADR-003 resets `RuntimeLoopTotals` on every resume
by design (`session.ail:2607-2652`: a resumed run is its own run), and `call_model_or_fail`
checks those totals only when `cost_metered` is set (`step_machine.ail:110-115`). Decision spend
therefore has two scopes, named here so neither is implied by the other:

| Allowance | Scope | Holds | Reset |
|---|---|---|---|
| **Decision allowance** | session identity; persistent host state (below) | known decision spend and outstanding reservations, each attributed to the run that made it | never on resume; only by explicit registry migration |
| **Run cost cap** | one run; `totals.cost_millicents` | ordinary model cost plus the decision reservations **made in this run**, reconciled downward when usage becomes known | every resume, as ADR-003 says |

**Admission is the host's (N47).** The reserved charge `r` depends on the backend binding
`prepare` chose for this request, so it cannot be known before `prepare` runs; the host, not the
child, evaluates admission when the request arrives over the wire (transport above). `r` is the
configured maximum charge for the request's binding, from the recorded per-binding table (D6),
and the request must also satisfy the recorded size and count limits. The equation, evaluated
against the host's own ledger and the run terms the child sends with the request:
`r ≤ allowance − (known_spend + outstanding)`, and, when `run_cap = Some(cap)`, `r + run_cost ≤
cap`. `run_cap` is `Some(cap)` only when the run is metered **and** `max_cost_millicents > 0`, the
guard the step machine itself applies (`step_machine.ail:112-114`); a metered profile with the cap
disabled, which is what ADR-004's admitted T0 profile is, sends `None`, and the decision allowance
alone bounds decision spend. A refusal is the query's one exchange: the host records it and replies
with the corresponding `Unavailable`, which the interpreter sees like any other observation (D6).
A reservation left outstanding by an earlier run stays in the decision ledger: it is **never
refunded** because that run ended, and it is **not re-charged** to a fresh run's cap. Each charge
is counted once. Because admission is the host's, the run cap is applied **at admission** to every query, a
terminal finalize-site query included: with `run_cap = Some(cap)` a query with `r + run_cost > cap`
is refused before provider contact whatever site it comes from (N55, which corrects v0.4's N40
sentence). The step machine's own check at the next model call (`BudgetExceeded`,
`step_machine.ail:114`) is a second observation point, not the only one. With `run_cap = None` the
decision allowance is the only bound. The ledger carries the known/outstanding split that the
integer total cannot.

Pure callbacks have no durable write channel. Add host-owned session state keyed by registered
extension owner, invocation site, and stable local ID. It stores applied intervention counts and
the decision accounting ledger, outside extension-writable `ext_artifacts`. For a decision atom,
the effective intervention limit is the lower of operator and descriptor limits, fixed for that
session identity except by a recorded operator grant (D6). At exhaustion, skip both callbacks, emit a limit event, and produce the neutral
vote (`NoDecision`/`NoOpinion`); record why. An extension cannot raise or reset its counter by
changing its policy version. Renaming/removing/reinstalling an atom or switching profiles must
preserve prior spend and retained counters. A **replacement** identity — one whose predecessor holds
retained state — requires explicit registry migration rather than silently obtaining a fresh
allowance on resume; an identity with no predecessor and no orphan is a first registration and
starts at its configured allowance (D6).

Increment the counter only when that atom's selected `ContinueWithFeedback`, `Deny`, or `Pending`
is applied, including an `Immediate` vote. Nonwinning, neutral, acceptance/allow, and shadow votes
do not consume intervention allowance. Each applied pending restriction counts once at selection,
not once per subsequent wake. The host records vote application, the associated transcript/control
effect, and the counter increment as **one journal entry in host order**, from the single
`decision_vote_applied` event the child emits; recovery treats an observation without that entry
as charged and unapplied (below). The child emits and continues; it does not wait. This is new
persistence work, not an existing artifact update facility. Ordinary compaction already
leaves finalize history intact; durable counters avoid coupling the new pure API to marker prose.

Calls remain synchronous. The adapter owns a bounded deadline; expiration produces
`Unavailable(Timeout)`, possibly with unknown cost. Cooperative cancellation of an in-flight
callback is not promised. The TUI can terminate the runtime child on escape; process death is a
host control outcome. The host must not apply a result belonging to a previous invocation.

**Transport (F2): the live query is host-mediated over the wire.** The child never writes the
journal (`journal.ail:28-31`, ADR-003 D3), so the durability below is produced the way
`wake_read` already is (ADR-002 park-wake): the live arm of `Ports.decision_query` emits the
canonical request as a wire exchange and blocks on the reply; its effect row is `{IO}`. The host
(the TUI process that owns the journal) evaluates admission (below), appends either the refusal
or the reservation entry — invocation identity plus the reserved charge it computed — and, if
admitted, **only then** calls the provider through a host-side adapter; it validates and converts the response to the typed
`DecisionObservation` of D3, appends the complete observation with usage and timing, and only then
replies. Reservation, provider call, and observation are therefore host journal entries in host
order, and "recorded before dispatch" and "recorded before interpretation" are literally true.
Credentials live host-side only. The scripted, recording, and strict-replay arms stay child-side
port arms over the typed observation, as for every other leaf; the wire codec rejects unknown
tags. Provider calls for ordinary model steps remain child-side (`session.ail` imports `std/ai`);
decision queries are the exception, for the durability reason, and the plan must not let the two
paths drift in accounting. The alternative — a child-side `Net` adapter with emission-order
semantics — was rejected because it makes every durability sentence here approximate.

**The host's journal write must return success (N25).** Today `SessionJournal.append` swallows
its own IO failure and returns `null` (`session-journal.ts:367`), `SessionLogger.log` discards
the count (`session-logger.ts:404`), and the live wake reply is written to stdin before the
observation is journaled (`runtime-process.ts:1287`). Routing decision events through that path
would allow a provider call after a failed reservation write. The decision service therefore
uses a **success-returning append** on the same leased writer: a failed reservation append means
no dispatch and a host control failure reported to the child; a failed observation append means
no reply and the reservation retained; a failed vote-application append is a host control
failure that **stops the run**, since the counters it protects would otherwise diverge from the
record. Journal failure is never interpreter-visible as `Unavailable`. Durability here means
process-crash durability, which `appendFileSync` gives; power-loss durability would need a sync
this ADR does not require. Requests carry an invocation id; a duplicate is refused and a late
reply is never applied to a newer invocation. The decision exchange has its own request/reply
discriminator, active-invocation tracking and host deadline; it does not copy wake's habit of
consuming user input as a wake or reissuing waits, and user or model-change commands are queued
while a decision read owns stdin. The wake path's "reply first, journal after" is a transport
precedent, not an ordering precedent, and is not copied.

On process death, a started request without a complete observation remains interrupted with
unknown charge; retain the reservation. Do not fabricate an answer or replay a partial exchange. A
complete observation without a recorded vote application remains an auditable, charged
observation with no applied intervention; the crash window between the child's emission of
`decision_vote_applied` and the host's write is the one accepted window, named in freeze item 5.
Resume reconstructs these facts, abandons that interrupted invocation, and may start a fresh
occurrence only after normal admission checks. No automatic reissue, exactly-once upstream
billing, or transparent mid-callback resume is promised. These durable records deliberately
strengthen the first review's simpler suggestion to leave interrupted requests absent from the
journal.

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

Every `Query` consumes exactly one decision-port exchange and ordinal, whose observation is either
the host's **admission refusal** (`Unavailable(BudgetExhausted | InvalidRequest |
UnconfiguredBackend)`, recorded, no provider contact) or the provider's result, including a
timeout or an invalid response. The child performs no preflight of its own beyond
`Immediate`; disabled and exhausted-intervention atoms are skipped as D5 defines, before any
exchange. Strict replay serves both kinds of observation from the record and never contacts the
provider; **the host re-executes admission from the record** — the per-binding maximum-charge
table, the size and count limits, the ledger state and the run terms as recorded — and a
different verdict is a replay failure, as is divergence in invocation occurrence or expected
interaction. For that to be a property of the record and not of the replaying host's environment,
**backend-binding resolution (logical binding → configured backend/model), the per-binding
maximum charge, and the effective limits are recorded configuration inputs of the program** in
ADR-004 D1's sense, carried in the policy/run manifest layer below; admission reads them from the
record, never from ambient configuration or `config.ail` at replay time (N16).

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

**Live `--resume` under a changed descriptor (N17, N26, N37).** `ext_set_digest` is kind-only
(`runtime.ail:1113`), so a same-kind change to a descriptor does not trip the `ExtSet` refusal.
The descriptor snapshot is therefore its own resume row, `Descriptor`, beside `ExtSet` and `Prompt`
(`journal.ail:628-636`), and it is **split along the identity layers of this section**: a change to
the **question version or config digest, or to the declared limit** refuses the resume, and
`--resume-force` overrides; a change to the **interpretation version or config digest alone** —
thresholds, abstention, feedback templates, the things shadow-mode tuning edits — is *not* a
refusal: the resume appends a policy-snapshot entry recording the new epoch and continues, so the
journal shows the change and strict whole-run replay still rejects it (above), while a live
operator is not forced through every threshold edit. Comparison is against the **effective policy
epoch**, not the header: the fold derives the epoch from the header snapshot and every later
policy-snapshot entry, whether appended by an override or by an interpretation-only resume. So
P0 → forced P1 → ordinary P1 resumes cleanly; a rollback to P0 is refused unless forced; comparing
against the header, as v0.3 said, would reject the unchanged current policy. Existing
`resume_refusal` compares digests only under the same profile (`journal.ail:1796`); the
`Descriptor` row compares across profile switches too, because ADR-003 D5's accepted profile
switch resets `ext_artifacts` and must not reset host decision state.

**Identity, first registration, and the refusal that stops a fresh allowance (N36, N46).**
Identity is the registered owner (`"${name}#${idx}"`, `types.ail:1275`), site, and local ID. A
decision identity the effective epoch's ledger does not hold, and that orphans nothing, is a
**first registration**: the resume records it in a policy snapshot at its configured allowance,
and that snapshot is the moment D5's "fixed at first registration" refers to. So the first
schema-2 resume of a pre-feature journal, and a profile switch that *adds* a decision extension,
proceed without refusal — v0.5's row refused both, which reintroduced the cost D7 withdrew. The
third resume row, **`Identity`**, fires on **orphaning**: the ledger holds retained state — used
interventions, known spend, or outstanding reservations — for an identity the invoked registry no
longer contains. That is a reorder (inserting an extension before a decision extension changes its
index), a removal, a reinstall, or a profile switch that replaces or reorders the registry; it is
compared across profile switches like `Descriptor`, because `resume_refusal` compares nothing
across one (`journal.ail:1796-1806`). Orphaning is a predicate over **retained state**, not over
syntax: a reorder or removal of an atom that holds no used intervention, no spend and no
outstanding reservation orphans nothing and does not refuse; a reinstall under the same owner,
index, site and local ID is the same identity and retains its ledger.

**What a waiver does (N53, N54).** `--resume-force` waives `Identity`, and the waiver appends one
snapshot that does three things at that epoch. (1) It records an **orphan acknowledgment** for each
orphaned identity: its liabilities — used interventions, known spend, outstanding reservations —
stay retained under the old identity, but an acknowledged orphan no longer satisfies the `Identity`
predicate, so the next ordinary resume does not refuse again; without this the predicate stays
true forever, since the new identity's presence never retires the old one's absence. **An
acknowledgment ends when the acknowledged identity is registered again** (N60): its ledger resumes
and it is once more subject to the predicate, so an identity that reappears, accrues liabilities and
is removed a second time refuses again. (2) It registers **every identity the effective epoch does
not hold** as **inactive** — zero allowance *and* interventions disabled — because the host cannot
tell a replacement from a coincidence, and the grant is the recorded way to say which it was
(N61); the first-registration rule at configured allowance applies to ordinary resumes and to
forced resumes that waive only `ExtSet` or `Prompt`. Inactive means neither a paid query nor a
free `Immediate` intervention is available — money and interventions are separate budgets, and
zero money alone would leave a renamed atom with a fresh intervention limit; an inactive atom is
skipped like an exhausted one (D5), and the skip is recorded. (3) It records the new identities'
descriptors and nothing else: no allowance is recomputed, nothing is manufactured. Three further
entries complete the transition (D7 table): a **registry-migration entry** (old identity → new
identity; the retained state, **the allowance and the effective limit** move once, the old identity
is closed, and the destination — which must be inactive-registered — is **activated**, so the atom
continues exactly where it was; a second move is refused, N59), an **operator grant** (to an
inactive identity: sets money and the intervention limit *separately* and activates it; to an
active identity: a recorded operator change of the operator limit, an epoch entry, which is the one
exception to D5's "fixed for that session identity"; to an identity the registry does not contain:
refused), and, for removal with no replacement, the acknowledgment alone. A later reappearance or
rollback of an acknowledged identity resumes its retained ledger, ends the acknowledgment, and
mints nothing. The plan pins:
P0 → forced P1 → ordinary P1 (accepted at the second resume); rollback; limit change after force;
interpretation-only change on resume (continues, epoch appended); config-digest change of a
non-decision extension (continues, epoch appended; D2); first schema-2 resume of a pre-feature
journal (first registrations, no refusal); additive profile switch (first registration); reorder,
removal, reinstall with retained state, and **profile switch that reorders or replaces the
registry** (`Identity` fires on the orphan); reorder with no retained state (no refusal); forced
`Identity` followed by a paid query and by an `Immediate` vote (both unavailable: inactive), then
by a grant (activated at the granted money and interventions) or a migration entry (retained
state moves once); removal with no replacement (acknowledgment; second resume accepted);
reappearance after acknowledgment (retained ledger, acknowledgment ended, nothing minted);
**acknowledged → reappears → accrues → removed again (refuses)**; grant to an active identity
(recorded limit change); grant to an absent identity (refused); forced `Identity` resume that also
adds an unrelated decision extension (inactive; a grant activates it); config-digest or
constructor-data change for an extension with decision atoms (dry `prepare`; refuses if a question
changed under an unchanged digest); in-process suspension, which must read the same retained
state as a new-process resume. Appending silently on a plain resume
for a *question* or *limit* change was rejected: it would hide a change that alters what is being
asked. The `Descriptor` and `Identity` rows and the three entries extend ADR-003 D5 and are
recorded there as an amendment (D7).

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
No version is bumped by this document. After 8.0 the rule the release scope asks for applies: 8.x
minors add context fields only behind an exported constructor helper, so a consumer that uses the
helper keeps compiling; `Capability` variant and row changes wait for 9.0.

| Surface | Proposed migration |
|---|---|
| ABI 7.4 → 8.0 | Two capability variants; public descriptor/request/observation/evidence/state types; three `ExtCtx` fields; **per-row context types (`PureCtx`, `ProcessCtx`, `FsCtx`, `AiCtx`, `InterceptCtx`, `ProviderCtx`) replacing `ExtCtx` in every callback signature, `ToolProvider`'s row widened with `Trace`, an exported constructor for every view; `register_with_config` returns `ExtRegistration = { config: Json, caps }`, `ExtEntry` gains `config`, every view gains `ext_config: Json`, `DescribeTools` takes `(Json)`, and `DecisionInvocationState` carries the descriptor's two configs and the ledger terms (D2, D3)**; nullary `Accept`; vote-family normalization. No `ExtPorts` addition. |
| Core interfaces | `Ports.decision_query`; world cursor and dispatch result propagation; accounting/evidence/session state; shared witness helper with scanned call sites. |
| `execution-program/4` → `/5` | Forced by the decision class's **observation payload and scripts** (request/observation codecs, reservation and observation records a scripted run replays), not by the added `IdentityBody` constructor: the tree's rule (`dst_interaction.ail:99-108`, WI-D17) is that a constructor alone moves no version, and `/4` was moved by the wake class's payload (`dst_program.ail:119-131`). Also: cursor, reconstruction, projections, and catalogue class. Preserve historical v4 fixture bytes and semantics. |
| Journal schema 1 → 2 | Typed host decision state, reservation/observation records, policy snapshot (with the `Descriptor` resume row), and vote-application recovery. A **strict superset fold**: a schema-1 body decodes with empty decision state (N20, below). Do not hide host counters in extension-writable artifacts. |
| Event vocabulary → version 2 | Invocation, skip, query, observation, vote, and application events, including immediate and shadow paths. |
| Other records | **ADR-003 amendments:** the `Descriptor` and `Identity` resume rows compared against the effective policy epoch, the **orphan-acknowledgment** (ended on reappearance), **registry-migration** (carries allowance and limit, activates) and **operator-grant** entries (money and intervention limit separately; a recorded limit change on an active identity), the inactive-identity marker, the per-epoch **config-digest snapshot** covering `config` and constructor data positions, and the **dry-`prepare` refusal** at a config epoch boundary (D2, D6); header `schema_version: 2` for native schema-2 sessions and the `schema_promotion` entry for promoted ones (above). No amendment for unknown entries: the fold already refuses them and `journal.ail:3282-3288` pins it. **ADR-004:** the new port, world and program shape and the journal schema change its evaluation basis, so its D5 requires refreshed evidence; coordinated separately, never by editing its evaluator worktree. |
| Extensions and tooling | Kind/arity maps, conformance and no-op profiles, leaf inventory (which must recognize every view type as a receiver; `ext_call_inventory` matches `ExtPorts` by name today), all constructors/codecs, helper record types, the **binding-form and configuration-channel migration of D2** (45 constructor sites, tabulated there), package pins/locks, and external consumers (`fmt` is still on ABI 2.2.0's hooks record and needs the 6.0 migration first or a legacy-only disposition; `typefix-agent` has no ABI dependency and needs none). Plus, independent of the upstream fix: the **named-only shape rule** in `hook_scope.py` as a **total registration-shape result** in its own per-extension field — the `{ config, caps }` grammar recognized; `func_body`/`_resolve_func` returning parameter names; `Scope.locate` recording `(module, parameters, lets)` per hop; a per-home-module declaration table; the chain consulted before imports and declarations; computed lists and unresolved forms failing the result (D2) — with `emit_hook_scope` **exiting nonzero** from that field alone (`:1122`), the self-test pins re-pinned for the new head, the catalog passing `config` to `DescribeTools` (`tool_catalog.ail:107-110`), the tree-wide **`ext_hook_scope` derivation added to `DST_TARGETS`** beside its self-test, and the **trigger-shape and escape rows** written into `run_declared_vs_performed.sh` through its imported-ABI mechanism in the existing two-sided limitation idiom, with the probe sources in a committed fixture directory (freeze item 8, N48). |

**Schema 1 under schema 2 (N20, N27).** A pre-feature journal truthfully contains no decision
invocations, no decision spend, and no intervention counters, and its typed tool-evidence window
is `complete_from_session_start = false` under D3. Reading it with empty decision state is the
truth, not a fabrication, so the schema-2 fold is a **strict superset**: it reads a schema-1 body
and continues live with empty decision state and an incomplete window. Continuing to *write* is
the part v0.3 left open: the host adopts an existing file and keeps its header, and `writeHeader`
is a no-op on a nonempty file (`session-journal.ts:288,403`); ADR-003 permits one in-place
rewrite, to complete the initial header, and no upgrade rewrite. So the transition is an
**appended `schema_promotion` entry** (`1 → 2`), written by the first schema-2 host before any
decision entry: above it the fold applies schema-1 semantics (empty decision state), below it
schema-2, and the boundary is where zero-initialization stops — a second resume folds every
decision record after it and resets nothing. A second permitted in-place rewrite was mechanically
available (`completeHeader` is already an atomic rename) and was not taken, to keep ADR-003's
one-rewrite rule and the crash-safety of append-only; the cost is **two shapes of schema-2
journal**, both normal: *promoted* (header `schema_version: 1`, `schema_promotion` present) and
*native* (a new session's header carries **`schema_version: 2`**, no promotion entry, the boundary
is the header itself). `header_of_entry`'s `v != 1` (`journal.ail:813-818`) widens to accept 1 and
2, and `JOURNAL_SCHEMA_VERSION` (`session-journal.ts:34`) becomes 2 for new sessions. What a
schema-1 runner sees, stated truthfully because old runners cannot be changed: a native schema-2
journal refuses at the header with the `Schema` message (`journal.ail:634`); a promoted journal
refuses at the promotion entry with `Entry(seq, "type=schema_promotion")`, because the fold already
refuses the first entry kind it does not know — no ADR-003 amendment is needed for that, and
`journal.ail:3282-3288` pins it by test. The operator-facing migration guidance names that
second message so it reads as "your runner is too old", not as corruption. Historical fixtures
stay historical bytes; the plan adds an upgraded-session fixture resumed twice and a native
schema-2 journal read by a schema-1 runner. v0.2's blanket refusal was withdrawn because its
cost was every existing session becoming non-resumable at the major. `--resume-force` may waive an extension-digest mismatch
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

| Second-review item | v0.3 resolution |
|---|---|
| F1 / N14 purity not compiler-enforced | D2: `PureCtx` (no `ports`, no `world`) for both decision callbacks; purity structural. Existing slots get per-row context types at 8.0 (table in D2), with two row decisions to close in 8.0. Freeze item 2 rewritten to name the shape and require a runtime probe; `hook_scope.py` rule and red script row are D7 obligations. |
| F2 / N15 durability vs one-writer | D5: host-mediated wire transport for the live arm, row `{IO}`; reservation → provider call → observation are host entries in host order; vote application is one host entry from one child event, with the emission→write window accepted and named (freeze item 5). Adapter and credentials host-side. |
| N16 preflight determinism | D6: binding resolution, maximum charge and effective limits are recorded configuration inputs (ADR-004 D1), read from the record at replay. |
| N17 live resume, changed descriptor | D6: `Descriptor` row in the resume header comparison; refuse; `--resume-force` overrides and appends a new policy snapshot. |
| N18 evidence sharpenings | D3: `-1` sentinel → `ToolOutcomeUnknown`; window is new `C2LoopState` accumulation, incomplete on resume, schema 2 carries no typed tool outcomes in v1; `VerificationUnavailable` is heuristic and treated as uncertain. |
| N19 wire identifiers | D3/D6: the adapter sends no session, user, or trace identifier. |
| N20 schema-1 refusal too broad | D7: strict superset fold; refusal reserved for schema-2 read by a schema-1 runner. |
| N21 `/5` rationale | D7: attributed to the observation payload and scripts, per `dst_interaction.ail` WI-D17. |
| N22 witness extraction | D4: optional; the `tool_exec` pattern suffices. |
| N7 note (accounting) | D5: conservatively charged decision spend enters `totals.cost_millicents` for `BudgetExceeded`. |
| N13 (partial) | External evidence: endpoint and optional fields confirmed by the second review; model route unconfirmed. |

| Third-review item (Codex, full review of v0.3) | v0.4 resolution |
|---|---|
| F1 partial / N23 restricted records give no compiler guarantee | *(v0.4 resolution; the discipline it names was broken by N31 and replaced in v0.5, next table.)* D2: guarantee restated as restricted supplied authority; the three measured facts recorded; registration discipline named-or-pass-through, fail closed in `hook_scope.py`, moved into freeze item 2; missing-field faults are host control failures; the 21-case suite is the regression. Drafter re-ran all 21 probes: 0 mismatches. |
| N24 migration is more than parameter types | D2: `Trace` added to `ToolProvider`; `{FS}` kept; helper rule (data projection or smallest ports record, no dummy ports); exported constructors for every view under the 8.x rule; per-package pricing deferred to the plan with the review's Q-A table as input. |
| N25 host journal path is best-effort | D5: success-returning append; failed reservation → no dispatch; failed observation → no reply, reservation retained; failed application → run stops; never `Unavailable`; process-crash durability only; duplicate/late-reply and stdin-ownership rules. |
| N26 descriptor comparison wrong after force | D6: effective policy epoch folded from header plus snapshots; compare against the epoch, across profile switches; allowance fixed at first registration; identity includes the install index; explicit migration only; pinned case list; ADR-003 amendment. |
| N27 schema-1 continuation undefined | D7: appended `schema_promotion` entry as the fold boundary; schema-1 readers refuse at the first unknown entry; upgraded-session fixture resumed twice; ADR-003 amendment. |
| N28 two cost lifetimes | D5: decision allowance (persistent, per session identity) and run cost cap (per run, ADR-003 reset) named; admission equation; no refund of outstanding reservations, no re-charge to a fresh run; unmetered ordinary cost handled. |
| N29 adapter validation and retries | D3: host adapter is the sole float normalizer; child validates integers only; one versioned fixture-vector set across host, codec, fold, replay; SDK retries disabled, end-to-end deadline; contract version tied to normalization; wire request is a projection of the internal identity. |
| N30 red row vs release G5e | *(v0.4 resolution; reframed by N39 in v0.5, next table.)* Freeze item 8: `XFAIL` class; target green with expected-limitation rows listed; discipline gate before freeze; release scope G5e reworded to match. |
| Q-A, Q-B, Q-C | Q-A: table confirmed, six views kept, `DescribeTools` noted as the no-context payload, registry-only packages dispositioned in D7. Q-B: transport confirmed implementable; the child row stays `{IO}`; the decision exchange gets its own discriminator, invocation tracking and deadline (D5). Q-C: ADR-003 and ADR-004 amendments recorded in D7. |
| N13 | The model route page now resolves and names `typesafe/jev-1.13`; still not evidence of authorized inference or calibration. |

| Fourth-review item (Claude Opus 5, full review of v0.4) | v0.5 resolution |
|---|---|
| N31 pass-through arm escapes from `PureCtx` | D2: arm dropped; named top-level functions only; boundary specified as `hook_scope.py`'s reachability walk, which rejects the escape; escape recorded as fact 4; three escape probes join the suite; drafter reproduced them. |
| N32 exception list wrong by an order of magnitude | *(v0.5 resolution; count corrected again by N45 in v0.6, next table.)* D2: the count stated (twelve `let`-bound bindings across ten packages, named; 46 constructor sites; the `DescribeTools` lambdas included); migration rule for captured registration values; pricing deferred to the plan explicitly. |
| N33 enforcement point not a gate | D2, D7, freeze 8: tree-wide `ext_hook_scope` in `DST_TARGETS` and G5e; `_binding_text` fails closed; explicit new verdict; residual for registry-installed extensions stated. |
| N34 schema refusal wrong both ways; header unspecified | D7: native schema-2 header is `2`, `header_of_entry` widens; two journal shapes named; the refusal a schema-1 runner actually produces stated for each; unknown-entry amendment withdrawn, `journal.ail:3282-3288` cited instead; the un-taken second rewrite and its cost recorded. |
| N35 admission equation incomplete, uncarried | D3, D5: `DecisionInvocationState` gains the five ledger terms, host-stamped; `run_cap = None` when unmetered or `max_cost_millicents ≤ 0`; child evaluates, replay re-executes from the record. |
| N36 new identity mints a fresh allowance | D6: `Identity` resume row, compared across profile switches; a forced waiver starts at zero allowance until explicit migration; product case added to the pinned list. |
| N37 threshold tuning forces resumes | D6: `Descriptor` row split; interpretation-only changes append an epoch and continue; question/limit changes refuse. |
| N38 release G5a stale | Release scope G5a reworded to the current acceptance criterion. |
| N39 `XFAIL` duplicates an existing idiom | Freeze 8, D7: class dropped; rows written in the script's two-sided limitation idiom; "new row, not red". |
| N40 finalize-site reservation untested by the run cap | *(v0.4 resolution; superseded by N55 in v0.7: under host admission the run cap applies at the terminal site too.)* D5: stated; bounded by the decision allowance alone. |

| Fifth-review item (Claude Fable 5.1, fresh session, full review of v0.5) | v0.6 resolution |
|---|---|
| N41 named-only severs the configuration channel | *(v0.6 resolution; `DescribeTools` and the narrowed claim by N49/N50 in v0.7.)* D2, D3, D7: registration returns `{ config: Json, caps }`; the host keeps it on `ExtEntry`, stamps `ext_config` on every view, hashes it as the config digest; the descriptor's two configs come back on `DecisionInvocationState`; `Json` cannot carry a function; disclosure becomes a fact; config-digest change on resume appends and continues; function-valued captures become a `match`. |
| N42 binding step fail-open on shadowing | D2: shape rule stated in scoping order; `_binding_text` consults `let`s and parameters of the producing and delegated bodies first; shadowing rejected; fact 5 recorded; `q_named_shadow` in the suite as an escape row. |
| N43 walk is not the boundary; gate cannot fail | D2: three layers named — shape rule, compiler effect pass, walk as defense-in-depth with its three blind spots recorded; gate criterion: nonzero exit on any named-only rejection, independent of other verdicts; `emit_hook_scope:1122` changes; G5e reworded. |
| N44 fact 4's third precondition false | D2: two preconditions; unannotated variant recorded as an escape, not a control; parenthesized spelling noted. |
| N45 count still low | D2: the fifth review's table (10 / 16 / 19 / 45) replaces the prose count. |
| N46 `Identity` refuses the ordinary cases | *(v0.6 resolution; waiver transition completed by N53/N54 in v0.7.)* D6: fires on orphaning only; first registration defined and recorded at configured allowance; migration entry and operator grant defined (D7 table); forced waiver appends a snapshot at zero; pre-feature and additive cases proceed. |
| N47 admission inputs incomplete; supply path unspecified | D5, D6: admission is the host's, at request arrival, from the recorded per-binding maximum-charge table and limits; a refusal is the query's exchange; the child's ledger terms are a mirror seeded by the fold and updated by every reply, informational; run terms child-known; strict replay = the host re-executing admission from the record. |
| N48 suite has no home | D2, D7, freeze 8: rows in `run_declared_vs_performed.sh` through `write_abi_ctor`; sources in a committed fixture directory. |

| Sixth-review item (Codex, full review of v0.6) | v0.7 resolution |
|---|---|
| N49 `DescribeTools` outside the channel | D2, D7: `DescribeTools((Json) -> [ToolSchema])`; the catalog passes the entry's `config`; the four capturing catalogs migrate; freeze 2(c) gains a configured-versus-empty catalog example. |
| N50 hashing does not make the dependency split a fact | *(v0.7 resolution; its detector claim replaced by the dry `prepare`, N57, in v0.8.)* D2: the claim narrowed to registration-time state returned through the channel; pure module constants, transcript, artifacts and evidence named as the other readable inputs with their own provenance; the `question_config` obligation retained; a violation is a conformance failure that strict query replay detects; the restricted-view alternative recorded as not taken; cost stated as an expectation the plan measures. |
| N51 delegated shadow certifies the wrong callback | D2: fact 6; resolution lexical at every delegation hop, locals and parameters before declarations; `Scope.locate` changes; unresolvable delegation fails closed; `delegate_shadow` in the suite; drafter reproduced. |
| N52 vacuous gate without enumeration | D2, freeze 8: registration-shape validity is the gate's own total result (return shape, enumeration, named rule, resolved delegation); computed and unknown lists fail it; distinct from walk residue; `computed_list` and `registration_record` in the suite; drafter reproduced both. |
| N53 waiver leaves the orphan predicate true | *(v0.7 resolution; completed by N59–N61 in v0.8.)* D6, D7: the forced snapshot records an orphan acknowledgment per orphaned identity; liabilities retained, predicate retired; removal with no replacement is acknowledgment alone; reappearance resumes the retained ledger. |
| N54 free `Immediate` after force | D6, D7: a waived identity is registered inactive for money *and* interventions, skipped like an exhausted atom; the grant sets money and the intervention limit separately and activates; migration moves the intervention balance with the rest. Orphaning is over retained state, not syntax. |
| N55 terminal query contradicts host admission | D5: the run cap applies at admission to every query, terminal included; the step machine's check is a second observation point. |
| N56 "24 all reject" | D2, freeze 2(b): 20 attacks, one control, three recognizer escapes, scored as three groups; new cases are new rows. |

| Seventh-review item (Claude Fable 5.1, fresh session, full review of v0.7) | v0.8 resolution |
|---|---|
| N57 "strict query replay detects" is false | D2, freeze 3: the detector is a dry `prepare` at the config epoch boundary on the last recorded evidence snapshot; refuse on a changed canonical request under an unchanged question digest; `--resume-force` overrides with the violation recorded; the replay sentence deleted. |
| N58 constructor data positions outside every digest | D2, D7: `ToolProvider` names, `ExitIntent` label and `enabled`, `WorkInFlight` label projected as `Json` into the per-epoch config digest beside `config`; a change is the same event as a config-digest change. |
| N59 migration carries no allowance, does not activate | D6, D7, D5: migration moves allowance and effective limit with the retained state, closes the source, activates the destination; grant to an active identity is a recorded limit change (D5's "fixed" excepted); grant to an absent identity refused. |
| N60 acknowledgment never retired | D6: ended when the acknowledged identity is registered again; the second-orphaning case pinned as refusing. |
| N61 two rules claim a new identity at a forced resume | D6: every identity the epoch does not hold is inactive at a waived `Identity` resume; first registration applies to ordinary resumes and to forced resumes waiving only `ExtSet`/`Prompt`; "records the new identities' descriptors and nothing else". |
| N62 resolution order not the compiler's for imports | D2, freeze 2(b): order stated as locals/parameters, home imports, home declarations, stricter than the compiler by design; import-shadow rows a fourth suite class; `v7_delegate_param` an escape and a gate fixture. |
| N63 four tool edits cannot implement the rule | D2, D7: signature retention in `func_body`/`_resolve_func`, per-hop `(module, parameters, lets)` in `locate`, a per-home-module declaration table, the shape result as its own field with its own rejection shapes, self-test re-pins. |
| N64 D4 diagram | D4: host admits, reserves, calls, observes, replies; the child builds the request and witnesses the successor world. |
| N65 row sum | D2: the eight named. |

Q1 chooses declared callbacks over a **ports-free context** (F1). Q2 includes finalize and
tool-policy variants in 8.0. Q3 adopts the three context additions, host state, and the per-row
context types. Q4 specifies typed observations, units, absence, and validation. Q5 removes
replacement. Q6 specifies admission, accounting, counters, timeout, and crash recovery over the
host-mediated transport (F2). Q7 chooses the separate migrations above, with the superset fold
and the `Descriptor` and `Identity` resume rows. Acceptance of these decisions is governed by the acceptance rule under Freeze evidence: artifacts, not a further review round;
no unresolved alternative is silently treated as a frozen interface.

The callable `ExtPorts.decision_query` alternative remains useful if a future consumer needs
adaptive multi-query workflows. Those workflows are outside v1, so the new public effect surface
and wider callback rows have no demonstrated benefit here. Core-owned questions, chat prompts
masquerading as this endpoint, implicit artifact protocols, and extension-local subprocess
transport do not meet the ownership, type, and replay requirements.

## Freeze evidence and implementation handoff

**Acceptance rule (v0.8).** Seven full reviews have produced findings at a steady rate — 13, 9, 8,
10, 8, 8, 9 — and from the fourth onward most of each round has been about text describing
mechanisms that do not yet exist: tool edits, journal entries, gate criteria. Every review since
the third has also recorded that freeze evidence 1–3 "remains unsupplied by any artifact". The
operator closed the ring on 2026-09-20. From v0.8 this ADR is accepted **when the artifacts below
exist, not when a review finds nothing**: (i) no further review round is requested on this text;
(ii) a change to this ADR must cite an artifact — a fixture that fails, a compile that fails, a
probe with a measured result — and is recorded as a numbered amendment with the artifact attached,
not as a new revision; (iii) a question that cannot be settled on paper is moved into the
implementation plan as a decision with its fixture, and is not re-litigated here; (iv) the next
reviewable object is the plan's evidence for items 1–3 and the gate of item 8, reviewed once, at
the end, by a reviewer other than the implementer. This is the repository's own standing rule on
review-loop convergence applied to itself: measure the rate, and when the findings are about
unbuilt things, build them.

Before calling the ABI frozen, require:

1. Accepted review of both capability signatures, shared types, context additions, multiplicity,
   nullary `Accept`, policy identity, and execution placement.
2. Enforcement-boundary evidence in three separate classes, none substituting for another
   (N23): (a) **missing authority** — for each view, a callback calling a port outside the view
   fails at invocation with a missing-field host control failure that the runtime reports as a
   registration defect; the compile-time check does *not* catch it for lambdas and the evidence
   must say so; (b) **ambient effect** — the registration boundary (D2: the shape rule in scoping
   order over the whole registration, plus the compiler's effect pass over named functions)
   rejects every construction the combined suite shows escaping the bare compiler — **the
   pass-through lambda capturing a locally-typed record (annotated or not) from `PureCtx`, from
   `FsCtx` and at the `prepare` arity, its parenthesized spelling, the partial application, the
   local `let` that shadows a top-level `func`, the local `let make_hooks` that shadows a
   delegated top-level `make_hooks`, and the computed capability list** — scored in three groups
   with their own expected results (N56, N62): the 20 named-arm attacks reject at the compiler;
   the ordinary controls pass; the escapes — now including the parameter shadow and the delegated
   parameter — are accepted by the bare compiler and rejected by the boundary, which is what shows
   the boundary and not the compiler is doing the work; and a **fourth class**, compiler-clean and
   boundary-rejected with no effect performed, holds the import-shadow rows the rule over-rejects
   by design; the suite is a regression for the rule and has the home D2 names, and new cases are
   added as new rows, never by changing an old group's denominator; (c) **ordinary success** — compiled ABI-8 examples of
   both consumers registered as named functions reading their configuration through `ext_config`,
   plus a `DescribeTools` consumer whose catalog differs between a configured and an empty tool set,
   not minimal language probes.
   Plus inventories that recognize every view type and the one supported registration form, and
   updated conformance. No ABI claim rests solely on this sketch.
3. Evidence that question/configuration changes require no core edits; strict query and policy
   mismatches fail; the dry `prepare` at a config epoch boundary refuses a resume whose general
   configuration changed a question under an unchanged question digest, and passes one that did
   not (D2, N57); offline re-interpretation cannot be mistaken for strict trajectory replay.

The implementation plan must then provide, before enabling live enforcement:

4. Live-recorded/scripted parity, world propagation for losing votes, distinct identical-content
   occurrences, strict replay without network, and explicit exhaustion/divergence behavior.
5. Verification/evidence truthfulness; malformed/absent answers; budget/deadline failures; crash
   points before/after reservation, observation, and vote application — including the accepted
   window between the child's `decision_vote_applied` emission and the host's write (D5), which
   must recover as charged-and-unapplied, and distinct from a failed reservation append, which
   is a barrier; journal write failure at each of the three appends (N25); the schema promotion
   interrupted and repeated, and both journal shapes read by both runner generations (N27, N34);
   the policy-epoch, interpretation-only, config-digest, first-registration, orphaning,
   acknowledgment, acknowledgment-ended-on-reappearance, inactive-identity, migration-entry
   (allowance and limit carried, destination activated) and grant cases of D6 — to an inactive,
   an active and an absent identity — including a free `Immediate` vote attempted by a waived
   identity and a second orphaning after reappearance (N26, N36, N37, N46, N53, N54, N59–N61); host-side
   admission re-executed from the record, including a refusal served as the query's exchange and
   a terminal finalize-site query refused by the run cap (N47, N55); cross-run outstanding
   reservations (N28); resumed accounting and intervention limits; no replay of a partial
   exchange.
6. Composition with DP7, waits, permissions, all-atom ordering, tool-policy tie behavior, and shadow
   mode; compaction/profile changes/resume cannot silently reset host allowances.
7. Separate format migrations, historical fixtures left intact, unknown-tag rejection, the
   `schema_promotion` transition with an upgraded-session fixture resumed twice, the ADR-003
   amendments and the ADR-004 basis refresh (D7), and operator-facing resume/migration guidance.
8. Gate semantics that agree with the release scope (N30, N39): the trigger-shape row and the
   escape rows are **new** rows in `run_declared_vs_performed.sh`, written in the idiom the script
   already uses for its two known compiler limitations (`:751-771`): `ok "LIMITATION n still holds
   …"` naming `fb_30e82f6bdc5fc8c3` when the bare compiler accepts the construction, `bad "…
   FIXED UPSTREAM …"` when it rejects, so the target is green on the pin and goes red when the fix
   lands and the controls need re-reading (NOTE-001 §7). No new result class; the rows use the
   imported-ABI mechanism (N48). The passing enforcement gate is the tree-wide `make
   ext_hook_scope` run with the named-only shape verdict, in `DST_TARGETS` and named in release
   G5e, whose pass criterion is **a total registration-shape result for every installable
   extension** — supported return shape, every payload enumerated,
   every payload a named unshadowed function, every delegation resolved in scope — **with zero
   rejections, and a nonzero exit otherwise** (N43, N52), independent of the `HOOK-UNRESOLVED`
   verdicts that remain for other reasons; the gate must go red on the direct shadow, the
   delegated shadow, the parameter shadow, the delegated parameter and a computed list, reject the
   import-shadow controls, and go green on the empty registration, on a named callback with walk
   residue, and on the migrated tree; it is part of item 2,
   before the freeze, not a live-enforcement task; a fixed compiler is not a release prerequisite.
   Registry-installed extensions are outside this gate's reach (D2, residual).

Relevant existing checks include `make declared_vs_performed`, `make ext_hook_scope_selftest`,
`make profile_coverage`, `make driver_plus_no_ops`, and `make event_vocabulary`. These are future
implementation obligations, not tests run for this documentation revision. Configured provider
limits, first-guard wording/thresholds, and live quality measurements can evolve without changing
the proposed ABI. Persistence and adapter implementation remain separate release work; they are
not grounds to call an unprobed ABI frozen.

## Amendments

Recorded under the acceptance rule (ii): each cites the artifact that forced it, and supersedes the
cited text without revising it.

### Amendment 1 (2026-09-21) — distinct constructor names for the two preparation sums

**Supersedes** D2 `:121` and `:129`:

```
JudgePreparation = JudgeImmediate(FinalizeDecision)   | JudgeQuery(DecisionRequest)
ToolPreparation  = ToolImmediate(ToolPolicyDecision)  | ToolQuery(DecisionRequest)
```

**The artifact: a compile error on the pin.** As written, both sums declare constructors named
`Immediate` and `Query`. On AILANG v0.33.0 the ABI package alone checks clean, but a consumer that
imports both cannot build a `JudgePreparation`: `Immediate(Accept)` in a finalize `prepare` resolves to
the later declaration and fails with `cannot unify type constructors: ToolPolicyDecision vs
FinalizeDecision`. So freeze evidence 2(c) — compiled ABI-8 consumers of **both** decision variants —
cannot be built from the text. Three readings were compiled against the pin by P0.4, each with an 8.0
consumer that registers every slot (`evidence/P0.4-amendment-1/EVIDENCE.txt`, the three workspaces
beside it):

| reading | ABI alone | an 8.0 consumer |
|---|---|---|
| as written (`Immediate`/`Query` in both sums) | clean | **fails** — the unification error above |
| parametric `Preparation[v]` with the two names as aliases | clean | **fails** matching on the alias: `constructor 'Immediate' belongs to ADT 'Preparation', not 'JudgePreparation'`; passes only if every scrutinee is typed `Preparation[FinalizeDecision]` |
| **distinct names** (above) | clean | **clean** |

Only the distinct reading gives both variants an ordinary consumer without type annotations the ADR
never asks for, so it is adopted. **Nothing else moves.** Where D2–D7 say `Immediate` or `Query` as a
kind of preparation — an `Immediate` vote, a free `Immediate` intervention, `Immediate(NoDecision)` —
they mean `JudgeImmediate`/`ToolImmediate` and `JudgeQuery`/`ToolQuery` for the respective variant;
the semantics, the D5 accounting of an immediate vote and the D6 records are unchanged. The two
`Query` constructors carry the same `DecisionRequest`, so the host's decision path is untouched.

### Amendment 2 (2026-09-21) — a package's effect ceiling admits the rows of the slots it registers

**Adds to** D2 (the per-row context types and closed slot rows, `:320-339`) and D7's "Extensions and
tooling" row. **Nothing in the contract moves**; this states a consequence the text did not.

**The artifact: package checks on the pin.** An AILANG package may declare `[effects].max` in its
`ailang.toml`, and `ailang check` run with that package as its root rejects any function whose
**declared** row exceeds it. Two facts of 8.0 combine: a `Capability` payload's row must match its slot's
row exactly (closed-row unification at the constructor on the imported sum — P0.4 measured a narrower
row rejected as surely as a wider one), and every payload is a **named** top-level function (D2's
boundary). So a package's handler now *declares its slot's whole row*, whatever it performs. PLAN-001
P1.2a checked the six batch-A packages as their own roots at `181051d0` (7.4) and `df2df96e` (8.0)
(`evidence/amendment-2/RESULT.txt`, `pkgcheck.sh`): omnigraph's named ToolProvider handler exceeds
`max = [Process, FS, Env, SharedMem, IO]` by `[AI Net Clock Stream Rand Trace]` — at 7.4 the handler was
an inline lambda the ceiling did not see; compaction-structural's Compactor exceeds by `Trace`. The class
predates 8.0: at 7.4 two packages already exceeded their ceilings on a named stub declaring the
`ai_step` port row. 8.0 extends it to every payload.

**The rule.** A package's `[effects].max` must **admit the full row of every slot it registers** (the
table at `:320-327`; a `ToolProvider` package admits all eleven), and no more on account of the ABI.
The ceiling therefore bounds *which slots a package may occupy* rather than which effects its handlers
perform; the performed effects remain bounded by the views (D2) and, for named functions, by the
compiler's effect pass. **Scope:** no make target or CI step checks an extension package as its own root
(the registry loads packages as dependencies, where ceilings are not enforced — microrag exceeded its
ceiling at 7.4 with the sweep green), so this binds **registry publication (033 G8) and every external
8.0 consumer**, and PLAN-001's batches check each package as its own root from P1.2a on.

### Amendment 3 (2026-09-21) — non-credential registration values, environment values included, go through `config`

**Corrects** D2 `:370-372`, the clause "the in-tree captures hold environment-variable *names*, not
values". **The rule is unchanged**: configuration carries **no credentials** (D1), a reviewed
serialization rule checked on each migrated `register_with_config` (PLAN-001 §0 item 9).

**The artifact: two batches stopped on it.** PLAN-001 P1.2b and P1.2d measured the clause false at HEAD
`eebc4d13` (`evidence/P1.2b/STOP-env-captures.md` with `env_probe/`; `evidence/P1.2d/STOP.md` with
`fs_view_probe/`). Batch B's settings captures are environment **values** read at registration —
repetition-guard's budgets, test-dummy's marker, budget and decisions, context-mode's `CtxConfig`,
exa-search's and scratchpad's timeouts; herdr's `ExitIntent`, `WorkInFlight`, orchestrator `PromptShaper` and
`ToolPolicy` need its pane id, session time and run-file paths at call time. Compiled against the committed
8.0 ABI in a lock-free workspace: a named callback on a port-less view (`PureCtx`, `FsCtx`, `ProcessCtx`)
that reads the environment is rejected (`Missing effects: Env`); declaring `Env` is rejected at the slot's
closed row (`incompatible closed rows … extra labels [Env]`) — by design, `env_get` survives only on
`ProviderCtx`; the same value **read from `ext_config` checks clean**. None of the blocked values is a
credential; exa-search's key already travels as a name (`auth_env_var: "EXA_API_KEY"`).

**The rule, restated.** A value an extension reads at registration and a callback needs — environment
values included — is **disclosed through `config`** unless it is a **credential**, which travels as a
*name* only and is resolved where a port allows it. That is the channel's purpose: registration state is
stamped, hashed and recorded rather than hidden. Sites on `ProviderCtx` take the value at registration too,
keeping 7.4's one-read-at-registration behaviour rather than adding a recorded port read per call.
**Consequence, stated:** an extension whose disclosed configuration includes per-session identity —
herdr's pane id and session time, its run-file paths — has a **config digest that differs per session by
construction**, so a resume records a new policy epoch for it; no refusal follows, since the dry-`prepare`
detector (N57) applies only to extensions with decision atoms. Those values are recorded in session
journals, which the existing corpus privacy rules (013 ADR-004 D6) govern. **Rejected alternatives:** a
host-stamped identity field on the views (a change to the frozen contract for one package), and an
exemption for herdr's atoms (the registration-shape gate requires every site).

## Related records

- [First review: Claude Fable](REVIEW-adr001-v0.1-verdicts-fable.md)
- [Second review: Claude](REVIEW-adr001-v0.2-verdicts-claude.md)
- [Third review: Codex, full review of v0.3](REVIEW-adr001-v0.3-verdicts-codex.md) — Appendix A is the 21-probe suite D2 relies on
- [Fourth review: Claude Opus 5, full review of v0.4](REVIEW-adr001-v0.4-verdicts-claude-opus-5.md) — Appendix A.2 holds the escape that removed the pass-through arm
- [Fifth review: Claude Fable 5.1, fresh session, full review of v0.5](REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md) — A.3 is the named-arm attack set; N41 is the configuration channel
- [Sixth review: Codex, full review of v0.6](REVIEW-adr001-v0.6-verdicts-codex.md) — the 45-row capture ledger; A.3 holds the delegated-shadow and computed-list escapes
- [Seventh review: Claude Fable 5.1, fresh session, full review of v0.7](REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md) — A.3 holds the parameter-shadow escapes and the import-precedence measurement; A.5 the binding pass over the eighteen extensions
- [HANDOFF 2026-09-20: v0.7 full review brief](HANDOFF-2026-09-20-adr001-v0.7-full-review.md)
- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md` — the standing rule the acceptance rule applies
- [HANDOFF 2026-09-20: v0.6 full review brief](HANDOFF-2026-09-20-adr001-v0.6-full-review.md)
- [HANDOFF 2026-09-20: v0.5 full review brief](HANDOFF-2026-09-20-adr001-v0.5-full-review.md)
- [HANDOFF 2026-09-20: v0.4 full review brief](HANDOFF-2026-09-20-adr001-v0.4-full-review.md)
- [HANDOFF 2026-09-20: v0.3 full review brief](HANDOFF-2026-09-20-adr001-v0.3-full-review.md)
- [NOTE-001: the effect-inference gap](NOTE-001-effect-inference-gap.md) — evidence behind F1; upstream `fb_30e82f6bdc5fc8c3`
- [HANDOFF 2026-09-18: v0.2 review → v0.3](HANDOFF-2026-09-18-adr001-v0.2-review-to-v0.3.md) — the edit list v0.3 follows
- [033: Release scope](../033_release/ADR-001-release-scope.md) — this ADR is gate G5
- [Research: System One implications](RESEARCH-system-one-implications.md)
- [Research: System One implications, second analysis](RESEARCH-system-one-implications_2.md)
- [005: Harness policy boundary](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md)
- [013: DST architecture sequencing](../013_core_architecture_for_dst/ADR-001-sequencing-the-dst-architecture-caps.md)
- [013: Park and wake](../013_core_architecture_for_dst/ADR-002-park-and-wake.md)
- [013: Session journal and resume](../013_core_architecture_for_dst/ADR-003-session-journal-and-resume.md)
- [013: Journal as evaluation source](../013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md)
- [017: Extension ABI evolution](../017_extension_handling/ADR-001-extension-abi-evolution.md)
- [028: The loop that would not stop](../028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md)
