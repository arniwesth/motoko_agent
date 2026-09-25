# Review: ADR-001 Extension-owned structured decisions (v0.5)

Reviewer: Claude Fable 5.1 (`claude-fable-5-1`), fifth review, full and independent, 2026-09-20. **Same model as
the drafter, different session:** this session has none of the drafter's context, asked for none, and its evidence
is its own (every probe re-run, the walk driven on fixtures rather than read). Independence here is of session and
of evidence, not of model, as the brief requires me to say. Neither the third reviewer (Codex `gpt-6-astra`) nor
the fourth (Claude Opus 5). This reviews the **working-tree v0.5**, not the v0.2 at HEAD. Branch
`arniwesth/031-abi-8-0`; HEAD `2f3ee4d1e83feb677583924131ce08f7cb91b47a`; ABI `7.4`; AILANG `v0.33.0`, commit
`ae36986`. The reviewed file has 875 lines and SHA-256
`385e81f8a7fac147639a2c6b50c39112ac8f01bd55512928fd24a30a92bbcdc2`, matching the handoff. `git diff --stat 2062605
HEAD` over `src/core`, `packages`, `tools`, `scripts` and the `Makefile` is empty and those paths carry no tracked
working-tree change. Final provenance and the post-write SHA check are below the appendix.

## 1. Architectural verdict and freeze readiness

**Retain the architecture; do not freeze v0.5.** Everything the first four reviews accepted stands, and v0.5
closes more of the fourth review than any earlier revision closed of its predecessor: the pass-through arm is gone,
the schema-2 header and both refusal messages are now stated correctly against the fold (N34), the admission
equation has its guard and a carrier (N35), the `Descriptor` row is split the right way (N37), G5a is fixed (N38),
the gate rows use the script's idiom (N39), and the finalize-site disclosure is right (N40). I re-ran the third
review's 21 probes (**0 mismatches**) and the fourth review's escape set (8 of 8 sourced probes reproduce), and
then attacked the named-function arm directly with 24 further probes (Appendix A.3). **At the compiler, the named
arm holds.** Mutual recursion, a generic higher-order helper, a `pure` declaration, a `! {}` declaration, a
let-annotation that lies, a local record or local sum holding an effectful *named* function, an uppercase-named
helper, and a module-level `let` all reject, and they reject by the effect pass charging the callback. I could not
make a named top-level function perform an ambient effect from `PureCtx`, from `FsCtx`, or at the `prepare` arity.

**But v0.5 has replaced one false boundary claim with a boundary that is under-specified in two ways that matter,
and it has not noticed what the rule costs.**

First, **the named-only rule severs the only channel by which registration-time configuration reaches a callback,
and the ADR's stated remedy does not restore it (N41).** A named top-level function closes over nothing. I
classified all 45 registration sites in `packages/`: 10 bind a named function today, 16 bind a `let`-bound lambda,
19 bind an inline lambda, and 30 of the 35 non-named bindings capture a value computed at registration — a config
record, a cached prompt, a composition mode, a tool list, an orchestrator mode, a budget. Under named-only none of
those values can reach its callback. D2 says a captured value "becomes a parameter of a named function that returns
the capability list, or a field the host supplies"; the first moves the value into the list builder, where only a
closure could still reach it, and the second names no field that exists or is proposed. Module-level `let` exists in
AILANG but is effect-checked as a rowless function (probe `q_named_toplevel_apply`: "Effect checking failed for
function 'w'"), so it cannot hold anything read from the environment. This is an ABI-shape decision — a data channel
from registration to invocation — and it belongs before the freeze.

Second, **the boundary as specified is escaped by local shadowing (N42).** v0.5 specifies the boundary as
`hook_scope.py`'s binding step failing closed on anything that is not a named top-level function. That step resolves
a bare name to a module declaration *before* it looks at the producing body's `let`s (`hook_scope.py:916-926`).
AILANG lets a local `let body = …` shadow a top-level `func body`, and the registered value is then the lambda: probe
`q_named_shadow` checks with exit 0 and prints `EFFECT WITH NO PORTS OR WORLD` from inside the `PureCtx` slot. I
drove the tool's own `Scope` class on that shape (Appendix A.4, `fx_shadow`): it walks the clean top-level `body`
and reports `HOOK-PORT-MEDIATED`. So a construction the bare compiler accepts is classified by the tool as a named
binding. Under the rule as v0.5 writes it, that is an escape.

Third, **the walk is not the sound reachability check D2 describes, and the tree-wide target cannot fail (N43).** The
walk's application regex does not see `(w.f)(ctx)` (`fx_paren`, `fx_toplevel_paren`: `HOOK-PORT-MEDIATED`); it skips
every uppercase-initial callee as a constructor (`fx_uppercase`: an effectful `Helper(ctx)` is invisible); its
port check is by field *name*, not receiver type (`fx_collision`); and `emit_hook_scope` returns 0 unconditionally
(`hook_scope.py:1122`, returned by `derive.py:888`), so `make ext_hook_scope` never goes red. At HEAD 6 of 18
extensions are `HOOK-PORT-MEDIATED`, 3 `HOOK-AMBIENT`, 9 `HOOK-UNRESOLVED` for reasons unrelated to any registration
rule, so "green" in G5e has no meaning until the gate's pass criterion is defined.

Beyond the boundary: the `Identity` row **fires on the first schema-2 resume of every pre-feature journal and on
every profile switch that adds a decision extension**, and the waiver it prescribes leaves the atom at zero
allowance with no defined way to grant one (N46); the admission equation is carried but its inputs are still
incomplete — the reserved charge itself needs the configured maximum charge and the host limits, and the supply path
of the host's ledger terms into the child's context is unspecified (N47); fact 4's "annotated stored lambda"
precondition is false on the pin — the unannotated variant escapes too (N44); and N32's count is still low: 16
`let`-bound bindings in 11 packages, 19 inline, 45 sites, 10 compliant (N45). One minor item on where the regression
suite lives (N48).

**Eight new findings, N41–N48.** Missing implementation evidence (freeze items 1–3) is identified separately and is
not counted, as in the third and fourth reviews. The fourth review noted that findings per round had not converged
(13, 9, 8, 10); this round is 8, and five of the eight (N41–N45) are consequences of a single decision — the
named-only rule — rather than independent defects, which is the first round where that has been true.

## 2. Remaining blockers

| Blocker | Decision or evidence needed | References |
|---|---|---|
| **Configuration has no channel under named-only: N41** | Decide the ABI-shape mechanism by which a value computed at registration reaches a named callback: registration returns it as data and the host stamps it back on every context view (and hashes it — which also makes D2's closure-disclosure obligation checkable), or every constructor takes a data argument the callback receives as its first parameter. Either is ABI. Until one is chosen, freeze item 2(c) cannot be met by any configured extension in the tree. | D2 registration boundary, D2 "Registration may capture…", freeze 2(c) |
| **The boundary is escaped by shadowing: N42** | Specify the binding rule in AILANG's scoping order: a bare name that is `let`-bound in the producing body or any delegated body is not a named function; a name that resolves both to a declaration and to a local is shadowed and rejected. Add `q_named_shadow` to the suite as an escape the bare compiler accepts and the rule must reject. | D2, freeze 2(b); `hook_scope.py:910-942` |
| **The walk is not the boundary, and the gate cannot fail: N43** | Specify the boundary as the shape rule plus the compiler's effect pass on named functions; make the transitive walk defense-in-depth with its blind spots stated. Define the tree-wide gate as "zero rejections of the new named-only verdict across every installable extension, nonzero exit otherwise", independent of the `HOOK-UNRESOLVED` verdicts that will remain for other reasons. | D2, D7, freeze 8, release G5e; `hook_scope.py:153,820,837-847,1122` |
| **`Identity` refuses the ordinary cases: N46** | Fire `Identity` on *orphaning* — the ledger holds retained state for an identity the invoked registry lacks — not on any identity absent from the epoch. Define first registration. Define the registry-migration entry and the operator grant the row's waiver depends on. State that a forced waiver appends a snapshot registering the waived identity at zero. | D5, D6, D7 "Other records"; ADR-003 D5 |
| **Admission inputs still incomplete: N47** | Carry the configured maximum charge for the request's backend binding and the host request limits, or say the host stamps `r`. State how the host-owned ledger terms reach the child's context per invocation and that `run_cost`/`run_cap` are child-known. | D3, D5, D6 |
| **Evidence 1–3 still not supplied** | Unchanged from the third and fourth reviews: accepted signatures; compiled ABI-8 examples of both consumers registered as named functions; view/construction probes; updated inventories; strict-mismatch and offline-experiment evidence. | Freeze 1–3 |

N44, N45 and N48 are corrections to text and counts; they do not block on their own but N44 changes the suite's
composition and N45 feeds N41.

## 3. New findings (N41 onward)

### N41. The named-only rule removes the only channel from registration to callback, and D2's remedy does not restore it

**Evidence.** D2: "Every `Capability` payload callback, `DescribeTools` included, must be a **named top-level
function**, bound directly in the capability list." A named top-level function in AILANG closes over nothing but
module-level declarations. Module-level `let` exists on the pin, but it is effect-checked as a rowless function —
probe `q_named_toplevel_apply` fails with `Effect checking failed for function 'w' … Missing effects: IO` — so it
cannot hold a value read from the environment or the filesystem at registration, which is where every configured
extension in the tree reads its configuration (`register_with_config` in a2a, agentcli, ailang-docs, compaction-ai,
compose, context-mode, exa-search, herdr, mcp, repetition-guard, scratchpad, test-dummy; see §A.3 for the probe).

I read every `register_with_config` and every delegated `make_hooks`/`make_hooks_with` and classified all 45
capability-constructor sites in `packages/` outside the ABI and conformance packages (N45 has the table). Thirty
of the thirty-five non-named bindings capture a registration-time value:

| Package | Bindings that capture | Captured |
|---|---|---|
| compose (`compose.ail:1110-1112`) | `ToolPolicy` lambda, `handle`, `intercept` | `composition_mode`, `snippet_caps`, `runtime_cfg` |
| context-mode (`register.ail:54-57`) | `PromptShaper` lambda, `handle`, `finalize` | `cached_prompt`, `cfg` |
| herdr (`herdr.ail:2032-2055`) | `describe`, `PromptShaper` and `ToolPolicy` lambdas, `handle`, `at_exit`, `waiting` | `cfg`, `tools`, `orch` |
| repetition-guard (`register.ail:45-46`) | `policy`, `finalize` | `calls`, `answers` |
| a2a, agentcli, ailang-docs, exa-search, mcp, scratchpad | `handle`, `DescribeTools`/`PromptShaper` lambdas | `agents`/`cfg`/`mappings`/`servers`/`timeout_secs`/`cached_prompt`/`schemas` |
| compaction-ai (`register.ail:106`) | `Compactor` lambda | `compaction_cfg` |
| test-dummy (`register.ail:61-78`) | all four | `prompt_marker`, `budget_total`, `tool_decision`, `finalize` |
| omnigraph (`register.ail:38`) | `PromptShaper` lambda | `cached_prompt` |

D2's migration rule: "a captured registration value (compose's `composition_mode`, herdr's `orch`) becomes a
parameter of a named function that returns the capability list, or a field the host supplies." The first clause
moves the value into the *list builder*; the callback is a separate named function with the slot's fixed arity
`(PureCtx, …)` and cannot see the builder's parameters except by closing over them, which is the form the rule
forbids. The second clause names no field: `ExtCtx` (`types.ail:536-619`) has no per-extension configuration field,
`artifacts` is written only by `Compacted(…)` (`runtime.ail:343-347`), and D3's three additions carry evidence, not
configuration. For the two new callbacks the situation is the same: `DecisionPolicyDescriptor` carries
`question_config` and `interpretation_config` for the host to hash, but `prepare`'s and `interpret`'s signatures
do not receive the descriptor back, and D2's paragraph "Registration may capture immutable configuration only when
all decision-relevant values are represented in the descriptor" is written as though capture were still possible.

**Consequence.** Under the rule as written, no configured extension in the tree can be migrated, and the first
completion guard — which reads thresholds, a backend binding and templates at registration — cannot be written
either. Freeze item 2(c), "compiled ABI-8 examples of both consumers registered as named functions", is
unsatisfiable for any consumer with configuration until this is decided. It is not a plan question: the fix is a
change to what a `Capability` constructor or a context view carries.

**Decision needed.** Choose the channel and put it in D2 and the D7 ABI row. Two shapes fit the rest of the ADR:
(i) registration returns its disclosed configuration as data beside the list (`{ config: Json, caps: [Capability] }`
or a data field on `ExtEntry`), and the host stamps that value on every context view it builds for that extension
and folds it into the extension digest — which turns D2's "the host cannot inspect closures" limitation into a
checkable contract, since a named callback can then read nothing the host did not hash; or (ii) each constructor
takes a data argument beside the named function and the host passes it as the callback's first parameter. For the
decision callbacks, hand the descriptor's two config values back on `DecisionInvocationState` or as a parameter,
and rewrite the "may capture" paragraph accordingly. A third option — permit one closure form whose captured values
are of data-only types — is not available to a textual tool: the walk cannot see types, and N31's escape was
precisely a captured value whose type carried a function.

### N42. The boundary as specified is fail-open on local shadowing

**Evidence.** Probe `q_named_shadow` (Appendix A.3): a module declares `func body(ctx: PureCtx) -> int { 1 }` and,
inside `build() -> Slot ! {IO}`, binds `let body = func(ctx: PureCtx) -> int { apply(ctx, w) }` over a local record
`w` holding an effect-performing lambda, then returns `Pure(body)`. `ailang check` exit 0; `ailang run --caps IO`
exit 0, printing `EFFECT WITH NO PORTS OR WORLD` from inside the rowless slot. AILANG resolves the local `let`
first, as one would expect; the compiler permits the shadowing.

`_binding_text` (`hook_scope.py:910-942`) resolves a bare name by calling `_resolve_func` — module declarations and
imports — **before** consulting `let_bindings(self.producing_body)` (`:916-926`). I drove the tool's `Scope` class on
a registration of that shape (`fx_shadow`, Appendix A.4): it reports `HOOK-PORT-MEDIATED`, reached text
`['ToolPolicy[0]']` only, no rejection. It walked the clean top-level `body` and never saw the lambda.

**Consequence.** v0.5 specifies the boundary as this step "failing closed on anything that is not a named top-level
function". As the step resolves names today, the shadowed binding *is* a named top-level function to it, so the
proposed change accepts it. Freeze item 2(b)'s "the registration boundary … rejects every construction the combined
suite shows escaping the bare compiler" is false for a construction the suite does not yet contain. The escape is
deliberate on the extension author's part — nothing in the tree shadows a declaration — but the rule is a boundary,
and a boundary that a two-line edit walks through is not one. It is also the exact failure mode the tool's own header
warns against: "a green answer can never be produced by resolving nothing", and here it is produced by resolving the
wrong thing.

**Decision needed.** State the binding rule in AILANG's scoping order and make the tool follow it: a bare name that is
`let`-bound in the producing body, in any delegated body on the path, or as a parameter of the producing function is
not a named top-level function; a bare name that resolves both to a local and to a declaration is shadowed and is a
rejection under its own shape. Add `q_named_shadow` to the suite as an escape-accepted-by-the-bare-compiler row that
the rule must reject.

### N43. The walk is not the sound reachability check D2 says it is, and the tree-wide target cannot fail

**Evidence.** D2: "the tool resolves the binding to its text and walks transitively into named callees, rejecting a
dotted call on a receiver that is not a supplied port (`applied-local`), an unknown callee, and an unresolvable
binding … That walk rejects fact 4's escape today — `w.f(ctx)` inside `apply` — for the right reason." I confirmed
the parts that are true (Q-2), then measured the walk on the shapes it does not describe (Appendix A.4):

1. **Parenthesized application is invisible.** `_APPLY` is `\b(IDENT)\s*\(` (`:153`). `(w.f)(ctx, call)` inside
   `apply` matches nothing: `fx_paren` reports `HOOK-PORT-MEDIATED` with `apply` reached and no rejection.
   The compiler accepts that spelling of fact 4 as readily as the dotted one (probe `q_named_paren_apply`: check 0,
   run 0, effect performed). So "the walk rejects fact 4's escape" holds for one spelling of the escape.
2. **Uppercase-initial callees are skipped as constructors.** `:820`: `if … name[0].isupper(): continue`. AILANG
   accepts `func Helper(ctx: PureCtx) -> int` as a function (probe `q_named_uppercase` is rejected by the compiler
   for IO, not for the name). `fx_uppercase` — a named `body` calling an effectful `Helper` — reports
   `HOOK-PORT-MEDIATED`; the `println` inside `Helper` is never reached.
3. **The port check is by field name.** `:837-841`: a dotted call whose field is in `ext_fields` is recorded as
   `ExtPorts.<name>` on any receiver. `fx_collision` — a local `type W = { file_read: … }` — records
   `PORT file_read`; the ambient effect was found only because the walk separately entered `mk()`.
4. **The derivation never fails.** `emit_hook_scope` ends `return 0` (`:1122`); `_hook_scope` returns that value
   (`derive.py:888`); `main` returns it (`:920-922`). `make ext_hook_scope` (`Makefile:3214-3215`) therefore exits 0
   whatever the verdicts. Only the selftest pins anything, and it pins the *fixture* suite plus the yield.
5. **"Green" is undefined over the real tree.** `expected.json` pins the current yield: 18 installable extensions,
   `hook_port_mediated` 6, `hook_ambient` 3, and by subtraction 9 `HOOK-UNRESOLVED`, on the door-3 residue (`show`,
   `intToFloat`, and herdr's higher-order parameter `f`). Under named-only, `applied-local` will keep firing on every
   hook-reachable application of a parameter or local function value — ordinary higher-order code — so
   `HOOK-UNRESOLVED` stays common and cannot be the gate's failure condition.

**Consequence.** Three of these (1–3) mean the walk is weaker than D2's sentence. None of them is an escape of the
*compound* boundary — the compiler charges `Helper`, charges a `w` obtained by a call, and refuses a module-level
`w` — but D2 has moved the load from the shape rule to the walk ("the boundary is specified as the reachability walk
… not as a shape"), and the walk cannot carry it. Items 4–5 mean the D7 tooling row and release G5e name a target
that cannot go red and a colour that has no definition.

**Decision needed.** Specify the boundary as: (a) the shape rule — a named top-level function, unshadowed, bound
directly, `DescribeTools` included — enforced at `_binding_text`; (b) the compiler's effect pass over named
functions, which is what actually rejects every named-arm construction in the suite; and (c) the transitive walk as
defense-in-depth against ambient `std/*` and builtin effects, with items 1–3 recorded as known limits. Define the
gate: the derivation exits nonzero when any installable extension has a rejection of the new named-only shape, and
that check runs regardless of the extension's other verdicts. Put that criterion in freeze item 8 and G5e in place
of "run green".

### N44. Fact 4's "annotated stored lambda" precondition is false on the pin

**Evidence.** D2 fact 4: "Three preconditions, each ordinary in the tree: a local record type, an annotated stored
lambda, and a registration function whose row declares the smuggled effect." The fourth review's probe 26
(`n_pure_passthru_unannot`, "as above, stored lambda unannotated") is recorded as rejected. Its source is not in that
appendix; it is described as "Identical to probe 22 with the stored lambda written `func(c: PureCtx) -> int { … }`". I
built exactly that (Appendix A.2 shows the one-line diff against probe 22): `ailang check` exit 0, `✓ No errors
found!`; `ailang run --caps IO` exit 0, printing `EFFECT WITH NO PORTS OR WORLD`. The other two preconditions hold
as stated: `n_pure_passthru_norow` (enclosing row dropped) rejects with `build` missing `IO`, and
`n_pure_passthru_xmod` (imported record type) rejects at the `let` annotation.

**Consequence.** The escape needs two preconditions, not three, and the one that is gone was the least ordinary of
the three; so the class the pass-through arm admitted was wider than v0.5 records. Nothing in the *decision*
changes — the arm is dropped — but fact 4's text is wrong, the fourth review's probe 26 does not reproduce, and a
suite that lists the unannotated variant among the rejecting controls (as the fourth review's A.2 table does) would
score an escape as a control.

**Decision needed.** Correct fact 4 to two preconditions. Record the unannotated variant as an escape row —
accepted by the bare compiler, rejected by the boundary — beside probes 22–24, not among the controls.

### N45. The binding-form count is still low, and only ten of forty-five sites comply today

**Evidence.** D2 (N32): "at least twelve `let`-bound payload bindings across ten packages … plus test-dummy's four
inline atoms …, herdr's two lambdas, ailang-docs' prompt lambda, `progress-contract-guard`'s annotated inline judge,
and the `DescribeTools` `\_ . <expr>` forms in a2a, agentcli, ailang-docs and scratchpad. Forty-six
capability-constructor call sites in `packages/` in all." I enumerated every constructor application in
`packages/**/*.ail` outside comments, excluding the ABI package and the conformance package's fixtures and harness
(9 sites, which construct test atoms, not registrations):

| Form | Sites | Where |
|---|---|---|
| Named top-level function | **10** | compaction-structural `pre_step`; context-mode `on_tool_policy`; decision-framework; empty-stop-guard; microrag ×3; omnigraph `on_tool_policy`; scratchpad `on_tool_policy`; compose `on_build_system_prompt` |
| `let`-bound lambda | **16** | compose `handle`, `intercept`; context-mode `handle`, `finalize`; repetition-guard `policy`, `finalize`; a2a, agentcli, ailang-docs, exa-search, mcp, scratchpad `handle`; **herdr `describe`, `handle`, `at_exit`, `waiting`** |
| Inline lambda (`func` or `\`) | **19** | test-dummy ×4; herdr ×2; progress-contract-guard; a2a, agentcli, ailang-docs, scratchpad `DescribeTools`; ailang-docs `PromptShaper`; **compaction-ai `Compactor`; context-mode, omnigraph, exa-search `PromptShaper`; omnigraph `ToolProvider`; scratchpad `PromptShaper`; compose `ToolPolicy` (`:1110`)** |
| **Total** | **45** | |

The `let`-bound count is 16 in 11 packages, not 12 in 10: herdr's four are missing. The inline count is 19, not 12:
seven are missing, and five of the seven capture a registration value. Forty-five sites, not forty-six; I could not
find a forty-sixth outside the conformance fixtures.

**Consequence.** "so it is not underestimated a third time" — it is, though by less. More important than the number:
35 of 45 sites change form, and 30 of them cannot change form at all until N41 is decided.

**Decision needed.** Replace the count with the table above or defer it explicitly to the plan; either way, stop
stating a number the tree contradicts.

### N46. The `Identity` row refuses the ordinary cases and leaves them with no way out

**Evidence.** D6: "a third row, **`Identity`**, refuses a resume whose invoked registry introduces an identity absent
from the effective epoch's ledger, compared across profile switches like `Descriptor`. `--resume-force` waives it,
and a **waived identity starts with zero used interventions and zero allowance** — it can query nothing — until an
explicit registry-migration entry assigns it the retained state of the identity it replaces, or a fresh allowance
by operator decision recorded in the journal."

Three cases the row fires on, none of which is a minting attempt:

1. **The first schema-2 resume of any pre-feature journal.** D7 folds a schema-1 body with "empty decision state";
   the epoch's registered decision set is therefore empty, and every decision atom in the invoked registry is
   "introduced". D7 withdrew v0.2's blanket refusal because "its cost was every existing session becoming
   non-resumable at the major"; this row reintroduces that cost for every profile that carries a decision atom.
2. **A profile switch that adds a decision extension.** ADR-003 D5 accepts a profile switch and `resume_refusal`
   compares nothing across one (`journal.ail:1796-1806`). The `Identity` row, compared across switches, refuses it.
3. **Adding any extension earlier in the list.** Identity is `"${name}#${idx}"` (`types.ail:1275`,
   `runtime.ail:1113-1122`), so inserting an extension before a decision extension changes that extension's index
   and mints a new identity while orphaning the old one. This one is the fourth review's "reorder" and is arguably
   right to refuse; it is listed because the cost is positional and should be said.

In every case the remedy is `--resume-force`, after which the atom has zero allowance. The two things that can raise
it — "an explicit registry-migration entry" and "a fresh allowance by operator decision recorded in the journal" —
are not defined anywhere in the ADR: no entry type, no flag, no event, no row in the D7 table. D5's "That allowance
is fixed at first registration" names a moment, first registration, that the ADR never defines for a resumed
session either. So a session cannot gain a decision extension, and an existing session cannot cross the major with
one, without a mechanism that does not exist.

**Consequence.** The minting path the fourth review found is closed, but by a rule that also closes the front door.
The interaction with the split `Descriptor` row and the epoch fold is otherwise clean (Q-3), with one omission: the
ADR does not say that a forced `Identity` waiver appends a policy snapshot registering the waived identity at zero;
without that entry the next *ordinary* resume finds the identity still absent from the epoch and refuses again.

**Decision needed.** Fire `Identity` on **orphaning** — the effective epoch's ledger holds retained state (used
interventions, known spend, or outstanding reservations) for an identity the invoked registry no longer contains —
rather than on any absent identity. An identity with no predecessor and no orphan is a *first registration*: it is
recorded in a policy snapshot at its configured allowance, which is the moment D5's "fixed at first registration"
refers to. Define the registry-migration entry (old identity → new identity, retained state moves once) and the
operator grant as journal entries in the D7 table. State that a forced waiver appends the snapshot at zero.

### N47. The admission equation is carried, but its inputs are still incomplete and their supply path is unspecified

**Evidence.** D3 adds `allowance_millicents`, `known_spend_millicents`, `outstanding_millicents`,
`run_cost_millicents` and `run_cap_millicents: Option[int]` to `DecisionInvocationState` and says "The child's
preflight is a function of these fields and the request alone". D5's equation has a left-hand side `r`, "the reserved
charge the child's deterministic preflight computed", and D5 says "Each query must have a finite configured maximum
charge to reserve before dispatch". D6 (N16) makes that configured maximum charge — per logical backend binding —
and "the effective limits" recorded configuration inputs read "from the record, never from ambient configuration".
None of those is on `DecisionInvocationState`, and the backend binding is chosen by `prepare` per request
(`DecisionRequest.backend_binding`), so the maximum charge cannot be stamped as one number before `prepare` runs.
The host's other admission checks — request size and call count — read limits that are likewise not carried.

Separately, the five terms have two owners. `run_cost_millicents` is `C2LoopState.totals.cost_millicents` and
`run_cap_millicents` is derived from `StepPolicy.max_cost_millicents`/`cost_metered` (`step_machine.ail:112-114`):
both are child-side. The three ledger terms are "host-owned session state" (D5). D3 calls all five "host-stamped".
The ADR does not say how the host's ledger reaches the child's context at each invocation: a wire read before
`prepare`, or a child-side mirror seeded by the fold on resume and updated by every observation reply. Strict replay
can re-execute preflight "from the recorded context" only if the context that was recorded contained the values the
child actually used, which depends on that choice.

**Consequence.** The inequalities in D5 are now evaluable; `r` is not, from the carrier alone. And "host-stamped" is
half right in a way that matters for replay: the run terms come from the child, the ledger terms from the host, and
the protocol that joins them is the thing the plan will build, so the ADR should name it.

**Decision needed.** Either carry the per-binding maximum-charge table and the host limits on the context (a small
record keyed by binding), or state that the host evaluates `r` and admission and the child records the host's
answer — in which case D6's "strict replay re-executes deterministic preflight" is the host's re-execution from the
record. State the supply path for the ledger terms and correct "host-stamped" to say which side supplies which term.

### N48. The regression suite has no in-tree home, and freeze item 8 does not say which script mechanism the escape rows use

**Evidence.** D2: "The probe suite is the third review's 21 cases plus the fourth review's escape set, and it is a
regression for the rule." Freeze 8: "the trigger-shape row and the escape rows are new rows in
`run_declared_vs_performed.sh`, written in the idiom the script already uses (`:751-771`)". The 21 + escape suite
lives in two review appendices and in reviewers' scratch directories; the ADR names no directory, target or fixture
set for it. The script's limitation idiom at `:751-771` uses `write_lim`, a single-module probe checked under
`AILANG_RELAX_MODULES=1`; the controls that make the escape rows two-sided (`n_pure_named_localsmuggle` and its
siblings) reject only because the sum is *imported* (017 ADR-001 Q3's correction, and probe 27's `let`-annotation
rejection), which a single local module cannot express. The script's later `write_abi_ctor` rows (`:945-1000`) do
import the real ABI sum, and the escape construction needs no 8.0 view — it performs an ambient `println` through a
rowless slot, which `ToolPolicy`/`ExtCtx` already provide at 7.4 — so the rows are writable today through that
mechanism.

**Consequence.** Small, but "a regression for the rule" is a claim about something that must run; and an implementer
reading `:751-771` will reach for `write_lim` and find the controls do not reject.

**Decision needed.** Name the suite's home (a fixture directory under `tools/` or `scripts/dst/` with a make target,
or the script itself) and say the escape rows use the imported-ABI mechanism.

## 4. Resolution of N31–N40

"Resolved" means a coherent decision whose stated facts hold against the tree and the pin, not that an
unimplemented feature has passed a gate.

| Item | Verdict | What I verified against |
|---|---|---|
| **N31** pass-through arm | **Partial** | The arm is dropped and the named arm holds at the compiler: 24 attack probes (Appendix A.3), every one that a named callback could reach rejected by the effect pass — including a local record and a local sum holding an effectful *named* function, which the fourth review did not try, and a module-level `let`, which is effect-checked as a function. The three escapes and their rejections reproduce (A.2). But the boundary *as specified* — the tool's binding step — is escaped by shadowing (N42), the walk it is specified as has measured blind spots (N43), and fact 4's preconditions are misstated (N44). |
| **N32** count | **Partial** | 45 sites, not 46; 16 `let`-bound in 11 packages, not 12 in 10; 19 inline, not 12 (N45). The count is closer than v0.4's. The migration rule for captured values does not work (N41). |
| **N33** enforcement point | **Partial** | The tree-wide `ext_hook_scope` run is named, put in `DST_TARGETS` as an obligation, and in G5e ("the derivation, not only `ext_hook_scope_selftest`"); the registry-installed residual is stated. `ext_hook_scope` is still absent from `DST_TARGETS` at HEAD (`Makefile:507-519`) as expected of an obligation. But the target cannot fail and "green" is undefined (N43). |
| **N34** schema transition | **Resolved** | Native header `2`, `header_of_entry`'s `v != 1` widened (`journal.ail:809-817`); promoted journal refuses at the promotion entry with `Entry(seq, "type=schema_promotion")` — the fold's unknown-kind arm at `:1621` and the test at `:3282-3288` asserting `Entry(6, "type=not_an_entry")`; native journal refuses at the header with `Schema` (`:634`). Amendment withdrawn correctly. `adopt`/`writeHeader`/`completeHeader` behave as described (`session-journal.ts:288-333`, `:403-417`, `:430-471`); the second rewrite was mechanically available and the trade is now stated. Q-4 has two plan-level notes. |
| **N35** admission carrier | **Partial** | The five fields exist, the `max_cost_millicents > 0` guard matches `step_machine.ail:112-114`, `None` for unmetered-or-disabled is right and matches ADR-004's T0 profile. `r`'s own inputs and the ledger supply path are missing (N47). |
| **N36** minting | **Partial** | The row closes the fourth review's three cases (Q-3) and the waiver-at-zero rule stops a forced resume manufacturing allowance. It also fires on every pre-feature journal, every additive profile switch and every insertion before a decision extension, and the unlock it names is undefined (N46). |
| **N37** row granularity | **Resolved** | The split follows D6's identity layers exactly: question version/config digest and limit refuse; interpretation version/config alone appends an epoch and continues; strict whole-run replay still rejects the changed interpretation. Comparison is against the folded epoch, so P0 → forced P1 → ordinary P1 is clean and rollback refuses. Consistent with `ext_set_digest` being kind-only (`runtime.ail:1107-1122`). |
| **N38** G5a | **Resolved** | The working-tree diff of the release scope changes only the G5 row; G5a now states the acceptance criterion in D2's terms and names the latest handoff as the edit list. |
| **N39** gate idiom | **Resolved** | The `ok "LIMITATION n still holds …"` / `bad "… FIXED UPSTREAM …"` pair is at `run_declared_vs_performed.sh:751-771` with its argument-position control at `:773-782`; freeze 8 and G5e describe it the same way, name the ticket, and say "new row, not red". N48 notes the mechanism the rows must use. |
| **N40** finalize-site reservation | **Resolved** | The run cap is read only in `call_model_or_fail` (`step_machine.ail:102-114`), so a terminal finalize-site query is bounded by the decision allowance alone; D5 says exactly that. |

## 5. The four questions

### Q-1. Attack the named-function arm

**At the compiler, it holds; I could not break it, and I say below what I tried. The boundary as v0.5 specifies
it — the tool's binding step — does not hold (N42), and the walk it is specified as is weaker than described (N43).**

Every probe imports its sum from `repro/types.ail`, byte-identical to the third review's, to avoid the local-sum
confound; sources and results are in Appendix A.3. What I tried against a named top-level callback bound directly
in the constructor:

| Route | Probe | Result |
|---|---|---|
| Mutual recursion, the effect two calls away | `q_named_mutual` | rejected at `Pure(body)`: `r2 has extra labels [IO]` |
| A generic higher-order helper applying an annotated `! {}` lambda | `q_named_generic` | rejected: argument-position lambdas are checked |
| `pure func` on the callback | `q_named_pure_kw` | rejected, same row error |
| `! {}` declared on the callback | `q_named_emptyrow` | rejected |
| `let g: (string) -> () ! {} = println; g(…)` | `q_named_letannot` | rejected |
| Local record with a false field row holding **`println` itself** | `q_named_recfield_named`, `_paren` | rejected: the construction is charged to the callback even without a lambda body to walk |
| Same, unannotated `let` / imported record type | `_nolet`, `_xmod` | rejected (the imported one at the `let` annotation) |
| Local **sum** payload holding `println`, applied after `match` | `q_named_sumpayload_named` | rejected: `body` missing `IO` |
| Record obtained from a named maker | `n_pure_named_applier` (reconstructed) | rejected: `body` missing `IO` |
| **Module-level `let`** holding the fact-4 record, laundered through a typed helper | `q_named_toplevel_apply`, `_paren`, `_unannot`, `_noannot_let`, `_xmod`, at `prepare` arity, from `FsCtx` | all rejected: `Effect checking failed for function 'w'` — a top-level `let` is effect-checked as a rowless function |
| Uppercase-named effectful helper | `q_named_uppercase` | rejected by the compiler (the walk misses it — N43) |
| Local record whose field is named `file_read` | `q_named_collision` | rejected (the walk records it as a port — N43) |
| Ordinary success at `prepare` arity | `q_dec_prepare_named_ok` | check 0, run 0, `q=1` |

The named arm's strength is structural: a named function cannot capture, so the smuggled value must arrive by a
call, and every call on the path is charged by the effect pass. The one place a value can arrive without a call —
a module-level `let` — is itself charged as a function. That is a stronger guarantee than the fourth review had
evidence for, and it is the right arm to keep.

What escapes is not the arm but the *specification of how it is recognised*: (a) `q_named_shadow` — the compiler
lets a local `let body = …` shadow `func body`, the smuggle runs, and the tool resolves the declaration first and
reports the extension mediated (N42); (b) `q_named_partial` — `Pure(apply_w(w))` compiles and performs, and is
stopped only by `_binding_text`'s "neither an inline function nor a bare name" rejection, which shows the shape check
is load-bearing and must stay fail-closed; (c) `q_named_paren_apply` and `n_pure_passthru_unannot` — two further
spellings of fact 4 the bare compiler accepts, one of which the walk cannot see and one of which the ADR records as a
control (N43, N44).

**Recommendation.** Keep named-only. Specify it as a shape rule in scoping order (N42) enforced at the binding step,
with the compiler's effect pass as the enforcement of effects and the walk as a stated-limits second layer (N43).
Then decide the configuration channel (N41), without which the rule cannot be applied to the tree.

### Q-2. Is the walk what v0.5 says it is?

**Point by point, against `hook_scope.py` read in full and driven on fixtures:**

- *Walks transitively into named callees* — **yes.** `walk` pushes a declared or imported callee's body onto the
  stack (`:880-894`) and processes it under the same slot; `fx_escape22`'s reached list shows `apply` entered.
- *`applied-local` rejects `w.f(ctx)` inside a named function* — **yes, for that spelling.** `:837-847`: a dotted
  call whose field is not in `ext_fields` is `applied-local`. `fx_escape22` and `fx_toplevel_dotted` report
  `HOOK-UNRESOLVED` with that shape. **Not** for `(w.f)(ctx)` (`fx_paren`, `fx_toplevel_paren`: `HOOK-PORT-MEDIATED`),
  because `_APPLY` (`:153`) needs an identifier immediately before the parenthesis.
- *`_binding_text` accepts inline lambdas of any body and follows `let`-bound lambdas* — **yes.** `:913-915`
  returns `lambda_body(expr)` for any `func`/`\` form; `:922-926` enters a `let`-bound lambda's body
  (`fx_letlambda`: `HOOK-PORT-MEDIATED`). And it resolves declarations *before* lets (`:916-921` then `:922`), which
  is N42.
- *"registration_only" is where fact 4's construction is filed today* — **yes, by reading.** `derive_hook_scope`
  computes `registration_only` as the closure's import-granular ambient sources minus those the walk reached
  (`:1048-1050`). For fact 4 the walk never enters the `let w = { f: … println … }` text — a local's value is not
  hook-reachable text unless bound to a slot — so `std/io.println` is in the closure set and not in the hook set, and
  is listed as registration-only. The extension's *verdict*, though, is `HOOK-UNRESOLVED` from `applied-local`, so the
  tool does not pass fact 4 silently today; the ADR is right that it "rejects the escape today", for the dotted
  spelling.

**Is specifying the boundary as this walk sound?** No, and the ADR's own sentence points the wrong way: "**The
boundary is specified as the reachability walk … not as a shape**". The measured facts are the reverse. The walk is
a regex instrument with a header that says so ("REPORTS a second answer"); its blind spots (N43 items 1–3) are
exactly the kind a textual tool has, and the tool's authors built its self-test around the admission that it can be
fooled by position. What actually rejects every named-arm construction in the suite is the compiler; what stops
`Pure(apply_w(w))` and the inline lambda is the *shape* check at `_binding_text`; the walk adds a check on ambient
`std/*` and builtin calls that the compiler already charges for named functions, plus door-3 residue it cannot
classify. Making the walk the specified boundary turns an inventory into a load-bearing gate it was not designed to
be, and it inherits the gate's failure mode: `HOOK-UNRESOLVED` for reasons that have nothing to do with the rule.
Specify the shape rule as the boundary, the compiler as the enforcer of effects, and the walk as a second layer with
its limits written down; and give the derivation a pass criterion and a failing exit (N43).

### Q-3. Identity and allowances

**The row closes the fourth review's cases; it also closes cases that should be open (N46). The equation is
evaluable except for `r` (N47). The epoch and `Descriptor` interactions are clean.**

- **Same-profile reorder.** `ext_set_digest` covers `"${name}#${idx}"` and kinds in order (`runtime.ail:1113-1151`),
  so a reorder trips `ExtSet`; with `--resume-force` the moved identities are new and `Identity` fires too; one
  force waives both; every moved atom starts at zero allowance; the old identities' state is retained, never
  refunded. Closed. The cost is that identity is positional: inserting an extension before a decision extension
  re-identifies it (N46 item 3).
- **Cross-profile replace or reorder.** `resume_refusal` compares nothing across profiles (`journal.ail:1796-1806`;
  ADR-003 D5 "profile switch accepted"). `Identity` is compared across switches, so it fires; forced, zero
  allowance. Closed.
- **Reinstall.** Same `name#idx` → same identity → retained state, no minting; a changed question/limit trips
  `Descriptor`. Closed.
- **Interaction with the split `Descriptor` row.** Independent: `Descriptor` compares an atom's descriptor to the
  epoch's entry for the same identity; `Identity` asks whether the identity is in the epoch at all. A resume that
  introduces X and changes Y's interpretation refuses on X, and after force appends Y's new epoch. No conflict.
- **Interaction with the epoch fold.** The fold derives the epoch from the header snapshot and every later policy
  snapshot; the `Identity` comparison must read the *registered set* of that epoch, which the policy/run manifest
  layer carries. Clean, with the omission N46 names: a forced `Identity` waiver must append a snapshot, or the next
  ordinary resume refuses again.
- **Over-firing.** A pre-feature journal's epoch registers no decision atom, and an additive profile switch
  introduces atoms with nothing orphaned; both refuse, both force to zero allowance, and the unlock is undefined
  (N46). The fourth review asked for a refusal that "fires when the invoked registry introduces an identity the
  effective epoch's ledger does not hold"; v0.5 implemented that sentence literally, and the sentence was too wide.
- **Evaluability.** Given `r`, both inequalities are evaluable from the five fields, and `run_cap = None` correctly
  removes the second when the cap is disabled or unmetered. `r` needs the configured maximum charge for the
  request's binding and the host limits, which are not carried (N47). The refund side is still closed: I found no
  path in v0.5 that refunds an outstanding reservation or re-charges it to a fresh run.

### Q-4. Schema shapes

**Both shapes and both refusals are correct against the fold and the host, and the withdrawn amendment is
genuinely unnecessary.**

- *Native.* Header `schema_version: 2`. A schema-1 runner's `header_of_entry` refuses at `v != 1` with `Schema`
  (`journal.ail:809-817`, message at `:634`). A schema-2 runner widens that test to `1` or `2`. The message text at
  `:634` says "is not 1" and must be reworded with the widening — trivial, but it is the operator-facing line.
- *Promoted.* Header `1`, `schema_promotion` entry. A schema-1 runner folds the header, then meets the entry: the
  fold's kind dispatch (`:1531-1616`) knows `state_delta`, `settings`, `run_finished`, `suspended`, `resumed`,
  `exit`, `park`, `wake`, the history kinds and `header`; anything else is `Entry(e.seq, "type=${e.kind}")` at
  `:1621`. The test at `:3282-3288` mutates entry 6's type to `not_an_entry` and asserts `Entry(6,
  "type=not_an_entry")`, commented "AN UNKNOWN TYPE IS REFUSED, not skipped". So `Entry(seq,
  "type=schema_promotion")` is what a schema-1 runner produces, exactly as D7 now says, and no ADR-003 amendment is
  needed to make it so.
- *Host side.* `adopt` (`session-journal.ts:288-333`) reads any file and sets `seq` to the count read; `writeHeader`
  returns at `seq !== 0` (`:403-417`); `completeHeader` is the one atomic in-place rewrite (`:430-471`). The
  appended-entry transition needs none of them changed and is crash-safe under `appendFileSync` (`:367-386`). Two
  plan-level notes the ADR does not need but the plan will: `adopt` has no schema check, so a schema-2 host must
  learn from the header version or the presence of a `schema_promotion` entry whether the file is already promoted
  before writing one; and an old host that adopts a native schema-2 journal will still append its own `exit` entry
  after the child refuses — harmless, since `exit` is a known kind to both generations, but worth a fixture.
- *The un-taken second rewrite* is now recorded with its cost. Right call, stated honestly.

## 6. D1–D7 assessment

| Decision | Assessment |
|---|---|
| **D1 ownership** | **Accept, unchanged.** Nothing in v0.5 moves policy to the host. N41's proposed channel — the host stamping back what the extension disclosed — keeps ownership where D1 puts it and strengthens D2's disclosure obligation. |
| **D2 callbacks and contexts** | **Accept the shape and the six views; the registration boundary needs one decision and two corrections.** The views, the row derivation (`ai_step` `{AI, IO, Trace}` at `types.ail:294`; `tool_handle` `{IO, Process, FS}` at `:407`; the six FS fields; `clock_now` `{Clock}`; `env_get` `{Env}` at `:524`), vote-family multiplicity and the helper rule are right. The three measured facts hold except that fact 4 has two preconditions, not three (N44). The named-only rule is the right arm and holds at the compiler (Q-1). It is specified as the wrong thing (N43), recognised by a step that shadowing fools (N42), and costs the tree its configuration channel, which the ADR neither prices nor provides (N41). One wording point: `missingnamed` is rejected by the type checker ("record field 'ports' not found"), not by the effect pass. |
| **D3 observations and evidence** | **Accept, with N47.** The five new state fields are the right terms and `run_cap = None` is the right encoding of the step machine's disabled-cap guard. What is missing is the maximum-charge input and the statement of which side supplies which term. Everything the fourth review verified here still holds (`-1` sentinel, `is_missing_infrastructure` substring match at `session.ail:2231-2239`, new-accumulation window). |
| **D4 execution and merges** | **Accept, unchanged.** Precedences match `merge_finalize_decisions` (`runtime.ail:710-719`) and `merge_tool_decisions` (`:402-416`); the `/5` attribution is correct. Nothing new. |
| **D5 bounds and durability** | **Accept the transport, the barrier and the two allowances; complete the inputs.** The write barrier is correctly grounded (`append` swallows at `session-journal.ts:381`; `log` discards at `session-logger.ts:409`; `sendWakeReply` writes stdin with no journal write at `runtime-process.ts:1282-1298`). The two allowances and the no-refund rule are sound; the finalize-site disclosure is right. Outstanding: N47. |
| **D6 recording and identity** | **Accept the three layers, the epoch and the split `Descriptor` row; fix `Identity`.** The split is exactly what the first review's N5 asked for and what the fourth review's N37 needed. `Identity` closes minting and over-fires (N46). |
| **D7 migrations** | **Accept; the journal row is now right.** Both schema shapes and both refusals verified (Q-4). The tooling row's "named-only rule … as an explicit verdict with `_binding_text` failing closed" needs N42's scoping rule and N43's gate criterion; the "46 constructor sites" is 45 (N45); the "binding-form migration of D2" is blocked on N41. The `fmt`/`typefix-agent` dispositions and the ADR-004 basis refresh are unchanged and right. |

**Freeze-evidence audit.**

| Item | Result |
|---|---|
| **1** accepted contract review | Not met; blockers above. |
| **2** three enforcement classes | **Not met.** (a) correct and unchanged. (b) now rests on the boundary; the boundary's stated form is escaped by shadowing (N42) and its stated mechanism is weaker than described (N43); the suite's control list scores an escape as a control (N44). (c) cannot be met by any configured extension until N41 is decided; the "one supported registration form" the inventories must recognise needs the scoping rule. |
| **3** extension-only change, strict mismatch, offline separation | Correct requirement, no artifacts. Unchanged. |
| **4** parity, propagation, occurrences, strict replay | Good obligations, unchanged. |
| **5** evidence and crash matrix | Well specified. Add: a shadowed binding (N42); the unannotated escape row (N44); the first schema-2 resume of a pre-feature journal and an additive profile switch under `Identity` (N46); an old host adopting a native schema-2 journal (Q-4). |
| **6** composition and non-resetting limits | Correct; in-process suspension still named. |
| **7** format migrations | Correct; the journal row is now consistent with the fold. |
| **8** gate semantics | **Half met.** The script idiom and G5e agree (N39). The enforcement gate named here cannot fail and has no pass criterion (N43); the rows' mechanism is unnamed (N48). |

**The four response tables** are faithful to the reviews they summarise; I checked the fourth-review table row by
row against `REVIEW-adr001-v0.4-verdicts-claude-opus-5.md`. Four rows overstate: N31 ("the reachability walk, which
rejects the escape" — for the dotted spelling; N43), N32 (the count; N45), N35 ("child evaluates" — from inputs it
does not have; N47) and N36 ("closes the minting path" — and the ordinary path with it; N46). The earlier three
tables are unchanged from v0.4 and were verified by the fourth review; I re-checked the second-review table's F1 row
and the third-review table's N23 row against their sources and found them accurate as historical summaries.

## 7. Before freeze, before the plan, and afterwards

**Before freeze.** Decide the configuration channel and put it in D2 and the D7 ABI row (N41): this is the one new
ABI-shape decision this review adds, and it is prior to every migration sentence in the ADR. Specify the binding rule
in scoping order and add the shadow probe (N42). Re-specify the boundary as shape plus compiler, with the walk as a
stated-limits second layer, and define the gate's pass criterion and failing exit (N43). Correct fact 4 and the
suite's control list (N44). Fix the count or defer it (N45). Redefine `Identity` on orphaning and define first
registration and the migration/grant entries (N46). Carry or relocate `r`'s inputs and state the ledger supply path
(N47). Then satisfy freeze evidence 1–3 with real artifacts — this review, like the third and fourth, substitutes
language probes for none of them.

**Before the affected implementation plan is approved.** The success-returning journal operations and failure
protocol (N25). The `schema_promotion` write protocol, including how `adopt` learns the effective schema (Q-4). The
validation, wire, retry and deadline contract (N29). The per-package migration across 18 packages under the chosen
configuration channel, with N45's table as the site list. The suite's in-tree home and the rows' mechanism (N48).
The ADR-003 amendment (the `Descriptor` and `Identity` rows, plus the migration and grant entries) and the ADR-004
basis refresh.

**During implementation, before live enforcement.** Freeze evidence 4–8 with the additions in the audit above. Run
the tree-wide gate with the new verdict and confirm it goes red on the shadow fixture and green on the migrated tree.

**Afterwards.** Provider limits, guard wording and thresholds, and live quality measurement under recorded policy
versions; N37's split makes that tuning a live-resume operation rather than a forced one, which is the point. The
`ext_ai_step` usage loss remains separately disclosed debt.

## 8. Method and limitations

I read the brief first and completed both grounding checks before reading the ADR: HEAD `2f3ee4d1`; 875 lines with
the stated SHA-256; `git diff --stat 2062605 HEAD` over the five paths empty; no tracked working-tree change in them
(three untracked files exist there — `scripts/dst/mem_canonical_bench.ail`, `scripts/dst/mem_growth_probe.ail`,
`src/eval/journal/testdata/MATRIX.tsv` — which I did not read or create). `ailang` on PATH is v0.33.0, commit
`ae36986`.

Read in full: the ADR v0.5; the fourth review including all of Appendix A; the third review including all of
Appendix A (its 21 probe sources were extracted by script from the appendix, not retyped); the second and first
reviews; NOTE-001; the three 2026-09-20 handoffs and the 2026-09-18 handoff; the release scope's G5 row and its
working-tree diff; **`tools/ext_ambient_inventory/hook_scope.py`, all 1266 lines**; every `packages/*/register.ail`
and every delegated `make_hooks`/`make_hooks_with` body, plus `compose.ail:1101-1112` and its cited helper lines.
Read in the named sections and their dependencies: `types.ail` (`ExtPorts` `:256-535`, `ExtCtx` `:536-619`,
`Capability` `:1238-1273`, `ExtEntry` `:1275`), `runtime.ail` (digest `:1098-1151`, both dispatchers and merges),
`journal.ail` (`:20-40`, the `Refusal` type `:581-592` and messages `:620-636`, `header_of_entry` `:809-817`, the
fold's kind dispatch `:1531-1621`, `resume_refusal` `:1785-1806`, the unknown-type test `:3270-3290`), `session.ail`
(`:2225-2260`, `:2600-2660`), `step_machine.ail:95-125`, `ports.ail` (`ToolOutcome` `:560-660`, the `wake_read`
sites), `run_declared_vs_performed.sh` (`:735-785`, `:940-1000`), the `Makefile` (`:495-530`, `:3205-3230`),
`derive.py` (`installable_extensions` `:155-195`, `_hook_scope` `:840-888`, `main`), the hook-scope
`expected.json`, and `ailang.toml`'s `[extensions]` block. Host side: `session-journal.ts` (`:25-45`, `:280-345`,
`:360-475`), `session-logger.ts:395-415`, `runtime-process.ts:1270-1305`. ADRs: ADR-003 D3–D6, ADR-004 D1 (opening)
and D5, 017 ADR-001 Q3, Q4, §3 and §5. The stdlib's `std/io.ail` for builtin names.

**Probes.** Fifty-nine AILANG modules in a scratch directory outside the repository
(`…/scratchpad/adr001-v05-probes/repro/`), with `ailang.toml` and `repro/types.ail` byte-identical to the third
review's: the 21 reproduced (0 mismatches on check exit, run exit and the first diagnostic line), the 9 escape-set
probes whose sources the fourth review printed (all reproduce), 3 reconstructed from that review's descriptions
(two agree; `n_pure_passthru_unannot` does not — N44), and 24 new (Appendix A.3). Successful probes were run with
explicit capabilities; the only effect any exploit performs is stdout output. **The walk was driven, not only
read:** a 30-line Python driver imported `hook_scope.py` from the repository by path, read-only, and ran its `Scope`
class on ten fixtures in the scratch directory with a stub producer (`println`/`getEnvOr`/`exec`/`writeFile`
effectful, everything else pure), no builtin evidence, and the ten `ExtPorts` field names (Appendix A.4). That is a
measurement of the walk's resolution and application logic; it is not a run of `make ext_hook_scope` and does not
exercise the closure, the producer cache or the parent tool.

**Not done.** I did not run `make ext_hook_scope`, `make ext_hook_scope_selftest`, `make declared_vs_performed` or
any other project target: the script writes probes inside `scripts/dst/` and several targets generate files, which
the read-only rule forbids. My statements about the targets' exit behaviour are from reading `derive.py` and
`hook_scope.py`, and about the current yield from `expected.json`. I did not build any package against a
hypothetical ABI 8.0; N45's classification is of binding forms at HEAD and N41's table is of captured names in
source. I did not re-verify the first review's inventory counts, attempt any provider call, or re-check the external
SDK and registry sources. I did not read `session.ail`, `ports.ail` or `journal.ail` line for line, nor
`compose.ail` beyond its registration and the five cited helper sites. I did not reproduce the fourth review's six
escape-set probes whose sources it did not print, beyond the three reconstructions named above.

No subagents were used. No commits were made. No Herdr command was invoked; pane `w3:p1` and
`/workspaces/motoko_agent-eval` were not touched. The sole repository file written by this review is this one; probe
sources, fixtures, the driver and captured output live outside the repository.

## Appendix A. Compiler probes, walk fixtures, and exact results

Scratch root outside the repository. `ailang.toml` and `repro/types.ail` are byte-identical to the third review's
Appendix A (module `local/repro`, prefix `repro`; `PureCtx = { name: string }`, `Slot = Pure((PureCtx) -> int)`,
`FsCtx`, `FsSlot`). Commands:

```sh
ailang check repro/<case>.ail
# only after a successful check:
ailang run --caps IO      --entry main repro/<pure-case>.ail
ailang run --caps IO,FS   --entry main repro/<fs-case>.ail
```

### A.1 Reproduction of the third review's 21 probes

| Case | Expected (3rd) | Check | Run | Match |
|---|---|---:|---:|:--:|
| `clean` | 0 / 0 | 0 | 0 | ✓ |
| `direct` | 1 / — | 1 | — | ✓ |
| `named` | 1 / — | 1 | — | ✓ |
| `captured` | 1 / — | 1 | — | ✓ |
| `localrecord` | 1 / — | 1 | — | ✓ |
| `missingport` | 0 / 1 | 0 | 1 | ✓ (`record has no field: ports`) |
| `helper` | 1 / — | 1 | — | ✓ |
| `capturednamed` | 1 / — | 1 | — | ✓ |
| `capturedannot` | 1 / — | 1 | — | ✓ |
| `missingnamed` | 1 / — | 1 | — | ✓ (`record field 'ports' not found`) |
| `missingannot` | 0 / 1 | 0 | 1 | ✓ |
| `missingworld` | 1 / — | 1 | — | ✓ |
| `localunannot` | 1 / — | 1 | — | ✓ |
| `localannot` | 1 / — | 1 | — | ✓ |
| `fs_missing` | 0 / 1 | 0 | 1 | ✓ (`record has no field: clock_now`) |
| `fs_smuggle` | 0 / 0, IO performed | 0 | 0 | ✓ (`IO OUTSIDE FS VIEW`) |
| `fs_direct` | 1 / — | 1 | — | ✓ |
| `fs_named` | 1 / — | 1 | — | ✓ |
| `fs_direct_io` | 1 / — | 1 | — | ✓ |
| `fs_named_io` | 1 / — | 1 | — | ✓ |
| `fs_smuggle_norow` | 1 / — | 1 | — | ✓ |

**21 of 21 match; 0 mismatches.** First diagnostic lines compared and identical, including column offsets.

### A.2 Reproduction of the fourth review's escape set

Sourced probes (printed in that review's A.2) reproduce byte-for-byte:

| Case | 4th review | Check | Run | Match |
|---|---|---:|---:|:--:|
| `n_pure_passthru_captured` | 0 / 0 escape | 0 | 0 | ✓ `EFFECT WITH NO PORTS OR WORLD` |
| `n_dec_prepare_escape` | 0 / 0 escape | 0 | 0 | ✓ `EXFIL candidate=secret candidate text name=pure-ctx` |
| `n_fs_passthru_captured2` | 0 / 0 escape | 0 | 0 | ✓ `IO OUTSIDE FS VIEW` |
| `n_pure_passthru_xmod` | 1 | 1 | — | ✓ at the `let` annotation |
| `n_pure_named_localsmuggle` | 1 | 1 | — | ✓ |
| `n_fs_named_localsmuggle` | 1 | 1 | — | ✓ `body` missing `IO` |
| `n_fs_named_indirect` | 1 | 1 | — | ✓ |
| `n_pure_passthru_capturedfn` | 1 | 1 | — | ✓ |

Reconstructed from that review's descriptions (sources not printed there):

| Case | 4th review | Check | Run | Match |
|---|---|---:|---:|:--:|
| `n_pure_passthru_norow` (probe 22, `build` row dropped) | 1 | 1 | — | ✓ `build` missing `IO` |
| `n_pure_named_applier` (named `body` applies a named `! {IO}` maker's record) | 1 | 1 | — | ✓ `body` missing `IO` |
| **`n_pure_passthru_unannot`** (probe 22, stored lambda unannotated) | **1** | **0** | **0** | **✗ — escapes** (N44) |

The one-line diff of `n_pure_passthru_unannot` against probe 22, and its output:

```diff
-func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int ! {} { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
+func build() -> Slot ! {IO} { let w: W = { f: func(c: PureCtx) -> int { let _ = println(c.name); 1 } }; Pure(func(ctx: PureCtx) -> int { apply(ctx, w) }) }
```

```text
→ Type checking repro/n_pure_passthru_unannot.ail...
→ Effect checking...

✓ No errors found!
```

```text
✓ Running repro/n_pure_passthru_unannot.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

### A.3 Q-1: attacking the named-function arm (24 new probes)

`—` means not run because the check failed. "Rejected: app" is the closed-row unification error at the
`Pure(body)` application (`r1 has extra labels [], r2 has extra labels [IO]`); "rejected: eff(x)" is `Effect
checking failed for function 'x' … Missing effects: IO`.

| Case | Shape | Check | Run | Result |
|---|---|---:|---:|---|
| `q_named_mutual` | named `body` ↔ `helper`, effect in `helper` | 1 | — | rejected: app |
| `q_named_generic` | named `body` passes an annotated `! {}` lambda to a higher-order helper | 1 | — | rejected: app |
| `q_named_pure_kw` | `pure func body` performing `println` | 1 | — | rejected: app |
| `q_named_emptyrow` | `func body(…) -> int ! {}` performing `println` | 1 | — | rejected: app |
| `q_named_letannot` | `let g: (string) -> () ! {} = println; g(…)` in named `body` | 1 | — | rejected: app |
| `q_named_recfield_named` | local `type R = { f: (string) -> () ! {} }`; `let r: R = { f: println }; r.f(…)` | 1 | — | rejected: app |
| `q_named_recfield_paren` | same, applied as `(r.f)(…)` | 1 | — | rejected: app |
| `q_named_recfield_named_nolet` | same, unannotated `let` | 1 | — | rejected: app |
| `q_named_recfield_xmod` | same, `R` imported | 1 | — | rejected at the `let` annotation |
| `q_named_sumpayload_named` | local `type S = K((string) -> () ! {})`; `match K(println) { K(g) => g(…) }` | 1 | — | rejected: eff(body) |
| `n_pure_named_applier` | named `body` applies `mk() ! {IO}`'s record | 1 | — | rejected: eff(body) |
| `q_named_toplevel_apply` | **module-level** `let w: W = {…annotated lambda…}`; named `body` → `apply(ctx, w)` | 1 | — | rejected: **eff(w)** |
| `q_named_toplevel_apply_paren` | same, `(w.f)(ctx)` | 1 | — | rejected: eff(w) |
| `q_named_toplevel_apply_unannot` | same, stored lambda unannotated | 1 | — | rejected: eff(w) |
| `q_named_toplevel_noannot_let` | same, `let w = …` unannotated | 1 | — | rejected: eff(w) |
| `q_named_toplevel_xmod` | same, `W`/`apply` imported | 1 | — | rejected: app |
| `q_dec_prepare_toplevel_escape` | module-level `let` at `(PureCtx, string) -> Prep` arity | 1 | — | rejected: eff(w) |
| `q_fs_named_toplevel_escape` | module-level `let` from `FsCtx` | 1 | — | rejected: eff(w) |
| `q_named_uppercase` | named `body` calls effectful `func Helper` | 1 | — | rejected: app (walk-blind, A.4) |
| `q_named_collision` | local record field named `file_read`, from `mk() ! {IO}` | 1 | — | rejected: eff(body) |
| `q_dec_prepare_named_ok` | control: named `prepare` at the real arity, pure | 0 | 0 | `q=1` |
| **`q_named_shadow`** | top-level `func body` **and** `let body = <pass-through lambda>`; `Pure(body)` | **0** | **0** | **ESCAPE of the boundary as specified** (N42) |
| **`q_named_paren_apply`** | probe 22 with `(w.f)(ctx)` inside `apply` | **0** | **0** | escape; walk-blind (N43) |
| **`q_named_partial`** | `Pure(apply_w(w))`, a call expression | **0** | **0** | escape; stopped only by the shape check |

#### `q_named_shadow` — the compiler accepts shadowing; the walk resolves the wrong `body`

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

`ailang check` exit 0: `✓ No errors found!`. `ailang run --caps IO` exit 0:

```text
✓ Running repro/q_named_shadow.ail
EFFECT WITH NO PORTS OR WORLD
result=1
```

#### `q_named_paren_apply` — fact 4 in a spelling the walk cannot see

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

`ailang check` exit 0; `ailang run --caps IO` exit 0, printing `EFFECT WITH NO PORTS OR WORLD`.

#### `q_named_partial` — a call expression as the binding

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

`ailang check` exit 0; `ailang run --caps IO` exit 0, printing `EFFECT WITH NO PORTS OR WORLD`. `_binding_text`
rejects this binding today as `hook-binding-unresolvable` (A.4, `fx_partial`), which is the behaviour the rule must
keep.

#### `q_named_toplevel_apply` — a module-level `let` is effect-checked as a function

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

`ailang check` exit 1:

```text
Error: effect checking failed in repro/q_named_toplevel_apply: Effect checking failed for function 'w'
  Function uses effects not declared in signature

  Missing effects: IO

  Current signature: func w(...) -> T
  Suggested fix:     func w(...) -> T ! {IO}
```

#### `q_named_recfield_named` — a local record holding `println` under a false row is charged to the callback

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

`ailang check` exit 1:

```text
Error: type error in repro/q_named_recfield_named (decl 1): type unification failed at [function application at repro/q_named_recfield_named.ail:6:28]: failed to unify parameter 0: failed to unify effect rows: incompatible closed rows: r1 has extra labels [], r2 has extra labels [IO]
```

### A.4 Driving `hook_scope.py`'s walk on scratch fixtures

The driver imports the tool from the repository by path (read-only) and runs its `Scope` class the way
`self_test` does, with `trivial_resolve`, a stub producer that classifies `println`/`print` as `{IO}`, `getEnvOr` as
`{Env}`, `exec`/`writeFile` as `{FS}` and everything else `PURE`, no builtin evidence, and `ext_fields` set to the ten
`ExtPorts` field names.

```python
import importlib.util, sys
from pathlib import Path
HS = Path("/workspaces/motoko_agent/tools/ext_ambient_inventory/hook_scope.py")
spec = importlib.util.spec_from_file_location("motoko_hook_scope", HS)
hs = importlib.util.module_from_spec(spec); sys.modules["motoko_hook_scope"] = hs; spec.loader.exec_module(hs)
class Producer:
    def classify(self, mpath, src):
        if src in ("println", "print", "getEnvOr", "exec", "writeFile"):
            return ("EFFECTFUL", ["IO"] if src in ("println","print") else ["Env" if src=="getEnvOr" else "FS"])
        return ("PURE", [])
EXT_FIELDS = ("ai_step","tool_handle","file_read","file_write","file_remove","path_stat","dir_list","dir_make","clock_now","env_get")
def trivial_resolve(path):
    return ("std", path) if path.startswith("std/") else ("residue", path)
fx = Path("walkfx")
for f in sorted(fx.glob("*.ail")):
    sc = hs.Scope(f.stem, f, [f], fx, trivial_resolve)
    located = sc.locate()
    ambient, ports = sc.walk(Producer(), {}, EXT_FIELDS) if located else ([], [])
    print(f.stem, sc.verdict(ambient), [s for _, s in sc.reached], [(r.shape, r.detail[:90]) for r in sc.rejections],
          [(a["origin"], a["symbol"]) for a in ambient], [p["symbol"] for p in ports])
```

Every fixture begins:

```ailang
module sunholo/motoko_ext_fx/register
import std/io (println)
import pkg/sunholo/motoko_ext_abi/types (Capability, ToolPolicy, ExtCtx, ToolCallEnvelope, ToolPolicyDecision, NoOpinion)
```

| Fixture | Registration tail | Verdict | Reached | Rejections / findings |
|---|---|---|---|---|
| `fx_named_ok` | `[ToolPolicy(on_tool_policy)]`, pure named | `HOOK-PORT-MEDIATED` | `ToolPolicy[0]` | — (positive control) |
| `fx_letlambda` | `let policy = func…; [ToolPolicy(policy)]` | `HOOK-PORT-MEDIATED` | `ToolPolicy[0]` | — (a `let`-bound lambda is followed) |
| `fx_escape22` | inline lambda → `apply(ctx, call, w)`; `apply` has `w.f(ctx, call)` | `HOOK-UNRESOLVED` | `ToolPolicy[0]` ×2 | `applied-local`: "`.f(...)` … field call on a value this tool cannot resolve to an `ExtPorts`-typed receiver" |
| **`fx_paren`** | same, `apply` has `(w.f)(ctx, call)` | **`HOOK-PORT-MEDIATED`** | `ToolPolicy[0]` ×2 | none — the application is invisible to `_APPLY` |
| **`fx_shadow`** | top-level `func body` (pure) and `let body = func… apply(ctx, call, w)`; `[ToolPolicy(body)]` | **`HOOK-PORT-MEDIATED`** | `ToolPolicy[0]` | none — the declaration was resolved, the `let` never read |
| `fx_toplevel_dotted` | module-level `let w: W`; named `body` → `apply`; `w.f(ctx, call)` | `HOOK-UNRESOLVED` | ×2 | `applied-local` |
| **`fx_toplevel_paren`** | same, `(w.f)(ctx, call)` | **`HOOK-PORT-MEDIATED`** | ×2 | none |
| **`fx_uppercase`** | named `body` calls `func Helper(ctx)` which performs `println` | **`HOOK-PORT-MEDIATED`** | `ToolPolicy[0]` | none — `Helper(` skipped at `:820`; `Helper`'s body never reached |
| `fx_collision` | local `type W = { file_read: … }` from `mk() ! {IO}`; `w.file_read(ctx)` | `HOOK-AMBIENT` | ×2 | `AMB std/io.println` (via `mk`); **`PORT file_read`** recorded for a non-port receiver |
| `fx_partial` | `[ToolPolicy(apply_w(w))]` | `HOOK-UNRESOLVED` | — | `hook-binding-unresolvable`: "bound to `apply_w(w)` -- neither an inline function nor a bare name" |

The two bold `fx_shadow`/`fx_paren` rows are the walk passing constructions the bare compiler accepts and performs
(A.3). `fx_uppercase` and `fx_toplevel_paren` are the walk passing constructions the compiler rejects; they bound
what the walk, as opposed to the compound boundary, can be relied on for.

## Provenance and final integrity check

- **Model:** `claude-fable-5-1`, as this session reports it. Self-report, not a backend attestation. **Same model as
  the drafter of v0.3–v0.5; a fresh session with none of the drafter's context** — independence of session and of
  evidence, not of model. No model override, no delegated reviewer, no subagents.
- **Reasoning effort:** not exposed in this session's reportable metadata; I do not infer one.
- **Branch / HEAD:** `arniwesth/031-abi-8-0` / `2f3ee4d1e83feb677583924131ce08f7cb91b47a`.
- **ADR SHA-256 before reading:** `385e81f8a7fac147639a2c6b50c39112ac8f01bd55512928fd24a30a92bbcdc2` (875 lines).
- **ADR SHA-256 after writing this review:** `385e81f8a7fac147639a2c6b50c39112ac8f01bd55512928fd24a30a92bbcdc2` —
  **unchanged**; the reviewed working-tree v0.5 was stable throughout.
- **Repository write:** `.agent/projects/031_system_one_decisions/REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md`
  only. No commit. Probe sources, fixtures, the walk driver and captured output are outside the repository.
