# ADR-001: Extension ABI evolution — decisions on the four open questions

Date: 2026-08-17 (decision); supersedes the open questions in `RESEARCH-extension-abi-evolution.md` §5
Status: Decision — Phase C (ABI 6.0) landed 2026-08-26 on `arniwesth/mot-129-extension-abi-phase-a`
(commits `8df6601`…`55a823a`). **Post-6.0 correction (B8 report §4, finding 1):** the Q3 answer
below was measured on a *locally declared* sum; on the *imported* ABI `Capability` sum the
compiler DOES enforce the payload rows. Q3, §1 "Steel", §3(1), §4(a) and §5 carry the correction
inline; the original text is kept where it is quoted as history.

Closes project 017 by answering the four §5 open questions with measured evidence produced
by four delegated agents, not by reasoning.

---

## 1. Decision

- **Now:** ship `default_hooks(id)` (§3.2) as a minor. One added ABI constructor; migrate
  extensions opportunistically by record update. Do not add a per-slot "was overridden"
  witness — the record-update expression *is* the witness, but only once the static tooling
  is taught to read it.
- **At 6.0:** take capability registration (§3.3), bundled with the `proc_exec` →
  `tool_handle` rename. Reject the untyped bus (§3.1). File the AILANG feature request (§3.4).
  *Status: both taken at B8 — `8df6601` (the `Capability` list, `ExtEntry { id, caps }`,
  `ExtRegistry { entries }`) and `9a7c091` (`ExtPorts.proc_exec → tool_handle`, rename only, no
  semantic change).*
- **Steel the 6.0 precondition (as decided, then corrected at B8):** as decided, capability-list
  rows were taken to be NOT compiler-enforced in constructor-argument position, so the
  enforcement plane was made the body-reading derivation tooling (classifier 3) plus the
  `declared_vs_performed` differential, re-shaped and taught to walk into constructor arguments
  before 6.0 shipped. That tooling landed (B1/B2/B5). **B8 then measured (v0.33.0) that on the
  imported ABI sum the compiler enforces the payload rows at every direct binding** — a wide-rowed
  named atom is rejected (`incompatible closed rows`), an unannotated inline atom at the payload
  row, an annotated one at its own annotation. The hole is a property of *locally declared* sums
  only. What survives is limitation 1 (a lambda bound to a LOCAL record field is not checked
  against its row and can be passed as the atom — the `smuggle` row), and that is what the
  derivation plane now covers. Pinned two-sided in `make declared_vs_performed` (IMPORTED-SUM
  rows) and stated in the `Capability` header of `packages/motoko-ext-abi/types.ail`.
- **Reject N>1 duplicates** in the vote kinds (`ToolPolicy`, `SolverJudge`) at registration;
  admit N>1 (under rules) for the composable kinds. **Note:** the two tooling delegates
  disagreed on the composable kinds — see §4. The adopted minimum is the point they both
  agree on (reject votes, allow `ToolProvider` with disjoint names); the fold kinds
  (`PromptShaper`, `BudgetShaper`, `Compactor`) remain conditional on their merge semantics.
  This is a policy choice, not an uncontested measurement.
- Provenance: the four delegations and their answers are in §6. Verification confirms §3.2
  as implemented leaves the tree compiling (`make check_core` 56 passed, 0 failed, as reported
  by the implementation delegate).

---

## 2. The four questions, answered

### Q1 — Coverability criteria (D5) and the per-(extension, slot) barrier derivation over a capability list? Does "slot" survive as the unit?

**Answer: the unit becomes (extension, capability-atom) — one element of the returned list,
keyed by constructor plus position. "Slot" does not survive as the coverage unit.**

Evidence (delegate `mot-dlg-1787599899154`, kind claude):

- Today the coverage artifact's exhaustion check is slot-indexed and closed:
  `slot_accounting` iterates `all_hook_slots()` and demands
  `count(covered) + count(excluded) == 1` per slot (`dst_profile_coverage.ail:246–256`).
  It works only because the record guarantees exactly one binding per slot per extension.
  A list breaks that congruence.
- The barrier count is today `|{slots : unconditional ∧ rowed}|` (3 at HEAD: `on_pre_step`,
  `on_response_intercept`, `on_solver_candidate`), uniform across extensions. Under a list
  it becomes per-extension and data-dependent: `|{atoms returned by e : kind(atom)
  unconditional ∧ rowed}|`. An extension that returns no atom of a kind has zero barriers on
  that kind *by construction*.
- Exhaustion changes from "all 8 slots accounted for" to "all returned atoms accounted
  for", and the producer of "returned atoms" can no longer be the ABI (which only knows the
  kinds) — it must be derived from source per extension, giving the coverage artifact a new
  dependency on the re-designed hook_scope. The empty capability list (`register_with_config`
  returns `[]`) becomes a new, legal vacuous case (D5 P4 must cover it).
- The delegate corrected a premise in the task: only `hook_scope.py` reads the hooks
  *record*. `ext_call_inventory/derive.py` keys on `ExtPorts` (the port record extensions
  *call*), not on `ExtensionHooks`; `ext_ambient_inventory/derive.py` keys on the transitive
  import closure of `register.ail`; `declared_vs_performed` keys on the ABI row plus runtime
  dispatch. So §3.3's "main design work" collapses to one real redesign file
  (`hook_scope.py`); the other derivations re-target mechanically. **Corrected:** there are
  in fact *two* real redesigns, not one — `hook_scope.locate()` for binding reading
  *and* the coverage exhaustion/atom-denominator accounting in `dst_profile_coverage.ail`
  (the producer of "returned atoms" must come from a new fail-closed source).

### Q2 — Multiplicity policy per capability: which admit N>1 per extension?

**Answer: N>1 is allowed for the composable/concatenated kinds and forbidden for the vote
kinds; enforcement lives at registration (the host boundary that builds `ExtRegistry`),
never in the dispatchers.**

Evidence (delegate `mot-dlg-1787599903186`, kind codex):

| Variant | N>1 allowed? | Why | Where enforced |
|---|---|---|---|
| DescribeTools | Yes | Concatenation: several producers = one producer returning their concatenation | Registry validation (no count rejection) |
| PromptShaper | Yes | Registry-order patch fold; several explicit patches compose | Registry validation; list order = sub-order |
| BudgetShaper | Yes | Last-`Some`-wins fold; every stage gets the updated plan | Registry validation; list order = precedence |
| Compactor | Yes | Explicit chain; each stage consumes the previous valid output + successor world | Registry validation |
| ResponseInterceptor | Yes | Ordered first-match chain; every delegate threads state | Registry validation; list order = first-match order |
| ToolProvider | Yes, if advertised names are disjoint within the extension | First-match per tool family; overlap recreates the `provided_tools`/handler inconsistency | Registry builds a per-extension tool-name set; rejects duplicates (even inside one variant) |
| ToolPolicy | **No** | Vote under Deny>Pending>Allow>NoOpinion; N>1 = multiple votes from one extension | Reject in the registration/normalization boundary |
| SolverJudge | **No** | Vote under ContinueWithFeedback>Accept>NoDecision; N>1 = one extension disagreeing with itself | Reject in the registration/normalization boundary |

Validation belongs at the single host-owned boundary (currently the `parse_core_ext_order`
path). Failure rejects the offending registration with id, variant, and the duplicate index;
it must not silently discard capabilities.

### Q3 — Does the effect checker enforce closed rows on lambdas in sum-constructor-argument position, or does WI-B4 recur there?

**Answer as measured (2026-08-17, LOCAL sum): NOT enforced.** The gap recurs identically to
WI-B4 in constructor-argument position, and the cases where a *declared* named function
carries a wider row go further than the original record-field note: a closed
effect row on a constructor payload type (or a record-field type) does not bound the
effects — inferred lambda *or* named function — handed to it. Verified empirically, with
runtime proof that the undeclared effect performs.

**Corrected at B8 (2026-08-26, v0.33.0, IMPORTED sum): ENFORCED on the real ABI.** Every file in
the matrix below declares its sum *locally* (`type C = K(...)` in the probe file). The ABI's
`Capability` is *imported* by every extension, and for an imported sum the compiler unifies a
constructor argument's row against the payload row as closed rows, exactly as it does for a
record field. Isolated variable: import position — the same `K((string) -> () ! {IO})` sum,
moved to a separate module and imported, flips the named-wide case to REJECTED while the
exact-row control stays accepted; effect names, multi-effect rows, list position and return
type were probed and are irrelevant. What survives is limitation 1: a lambda bound to a LOCAL
record field is not checked against its row, and that field can be passed as the atom (the
`smuggle` row, ACCEPTED). All of it is pinned two-sided in `scripts/dst/run_declared_vs_performed.sh`
(IMPORTED-SUM rows, 7 of the 63) and stated in the `Capability` header of
`packages/motoko-ext-abi/types.ail`. The matrix below is kept as the local-sum history.

Evidence (delegate `mot-dlg-1787599891172`, kind claude), seven-file mutation matrix:

- `ctor_violation.ail` (constructor-arg lambda performing `{IO, Env}` against a payload row
  of `! {IO}`) checks **green** — the hole.
- `record_violation.ail` (same violation in record-field position) checks **green** — WI-B4
  reproduced, confirming the method can see through the record/constructor split.
- `named_violation.ail` (positive control: same body as a top-level named function against
  `! {IO}`) → **rejected** by the checker: `Missing effects: Env`.
- `ctor_violation_narrow_outer.ail` → **rejected**, but for the *enclosing* function's row
  (`build`), not the payload — the only enforcement is the enclosing constructor's row.
- `ctor_named_payload.ail` (a named function *declared* `! {IO, Env}` handed to a payload
  row of `! {IO}`) → **green**; `record_named_payload.ail` mirror → **green**. The checker
  does not compare function-type effect rows at all when a function value flows into a
  constructor/field slot.
- Runtime (`ailang run --caps IO,Env --entry main`) prints the undeclared `Env` value
  through the `{IO}`-row slot for all three green violators.

**Consequence for §3.3 (as corrected at B8):** the claim that each capability variant "keeps
its own closed effect row — per-slot compiler enforcement is untouched" *does* survive the move
to an argument position on the imported ABI sum. `Compactor((ExtCtx, [Msg]) -> PreStepOutcome
! {AI, IO, Trace})` is compiler-enforced at every direct binding: a named atom declared wider is
rejected, an unannotated inline atom is rejected at the payload row, an annotated one at its
own annotation. What the compiler does not give is coverage of the limitation-1 smuggle (a
lambda bound to a local record field, then passed as the atom); that is what the derivation
tooling (classifier 3; B2's `hook_scope` body scan at binding scope; `declared_vs_performed`)
covers, and B2's named-atom body scan matters only for the smuggle. The "design the tooling
first" precondition (§4.3) was paid in full before 6.0 and remains the enforcement plane for
the smuggle, not for direct bindings.

### Q4 — Does `default_hooks` need a per-slot "was overridden" witness, or is the ambient closure measurement sufficient?

**Answer: NO runtime witness is needed.** The record-update expression *is* the witness.
The ambient closure was already sufficient for the barrier derivation; the one tool that
reads bindings (`hook_scope`) has a *parser* gap (not a measurement gap) and must be taught
to read the record-update form.

Evidence (delegate `mot-dlg-1787599899154`, kind claude):

- `default_hooks` exists at `types.ail:964–993`, and `motoko-ext-empty-stop-guard` already
  uses the record-update form
  (`{ default_hooks("empty_stop_guard") | on_solver_candidate: finalize }`).
- The barrier derivation (`check_no_op_profile.py:197–224`) reads
  only the classifier-3 closure verdict, `ext_ports_calls`, and slot-level facts. It never asks
  "was this slot overridden", so a witness would not change output. Classifier 3 reads
  bodies (transitive import closure), so a no-op default and an absent override are the same
  for effect-provenance purposes.
- But `hook_scope.locate()` cannot read the record-update form: the `{ default_hooks(...) | ... }` head does
  not match `IDENT\s*:`, so the extension is rejected. Confirmed live (during the ADR
  review): the cost is already paid — `empty_stop_guard` is `HOOK-UNRESOLVED` at binding
  scope despite being `PORT-MEDIATED` at closure scope. The review also observed 10/17
  extensions HOOK-UNRESOLVED at HEAD, 9 of them for an unrelated door-3 `show` residue; only
  `empty_stop_guard` is attributable to the record-update gap.
- A flag is rejected: it would add an ABI field, be another lie surface, and is invisible to
  the one *static* tool that needs it. The fix is to teach `locate()` the record-update head,
  bind missing fields to the default lambdas, and keep the tiling assertion.

---

## 3. What the measurements changed

Nothing in §4 (the recommendation) is overturned. Three changes, all additive:

1. **§3.3's "closed effect row — per-slot compiler enforcement untouched" was taken to be
   false as an enforcement claim — and B8 reversed that for the real ABI.** Delegate 1
   measured that the payload row never bounds the argument (inferred lambda or named function)
   in constructor-argument position on a *locally declared* sum, so the enforcing tool was
   built to consume constructor arguments and resolve named-function references. At B8 the
   same probe on the *imported* `Capability` sum showed the payload row IS enforced at every
   direct binding (v0.33.0); the enforcing tool remains necessary only for the limitation-1
   record-field smuggle.
2. **The "all four derivation tools read record-fields" premise was wrong.** Only one reads
   the record; `ext_call_inventory` keys on `ExtPorts`, the ambient inventory on the import
   closure, `declared_vs_performed` on row+runtime. There are **two** real redesigns, not
   one: `hook_scope.locate()` for binding reading *and* the coverage
   exhaustion/atom-denominator accounting in `dst_profile_coverage.ail` (whose "returned
   atoms" producer must come from a new fail-closed source). The other derivations re-target
   mechanically.
3. **The override-witness question is settled syntactically, not with a flag**, and the
   parser gap is already being paid on one extension. The fix is a static parse extension.

## 4. Disagreements between delegates

Two findings in the ADR are reconciliations, and one is a genuine, unresolved disagreement:

### (a) Delegate 1 vs Delegate 2 — enforced where?

- **Delegate 1 (claude, effect rows)** measured the payload row is NOT enforced in
  constructor-argument position.
- **Delegate 2 (codex, default_hooks)** measured a mutated override being rejected: it added
  `IO` inside the migrated extension's top-level `finalize` function, declared `! {Process}`,
  and the checker rejected `finalize`.

It is important to state the mechanism precisely. Delegate 2's mutation was rejected because
`finalize` was checked against **its own declared row** (`! {Process}`), not
because "the enclosing construction" (register_with_config's `{Env, FS}` row) bounds it —
Delegate 1's case C, not case D. And Delegate 1's case E/G shows that if `finalize` had been
declared with a *wider* row (`{IO, Process}`), the record update would still have
type-checked into the `{Process}` slot. So the two results are compatible, but only in this
narrower sense: a named-function override is bounded by its own signature, and — on the
LOCAL sums both delegates measured — the ABI slot (payload) row bounds neither lambdas nor
named functions handed to it. The Q3 answer was the union of both. **B8 correction:** on the
imported ABI sum the payload row *does* bound both (see Q3); `mutant_register`'s widened
control changed verdict accordingly (5.x: accepted; 6.0: rejected at the lambda's annotation)
and was re-pinned, not inherited.

### (b) Delegate 3 vs Delegate 4 — the real multiplicity disagreement (Q2)

The two tooling delegates recommend **opposite** multiplicity policies for the composable
kinds, and this is a genuine conflict that is NOT reconciled:

- **Delegate 4 (`…9903186`, capability sketch)**: allows N>1 for all kinds except the two
  vote kinds `ToolPolicy` and `SolverJudge`.
- **Delegate 3 (`…9899154`, tooling read-analysis)**: recommends N>1 be an **error** for
  `PromptShaper`, `BudgetShaper`, `ToolPolicy`, `SolverJudge` *and* `Compactor`
  ("chaining semantics make order-within-extension an undocumented contract"), a feature only
  for `ToolProvider`.

The ADR adopts Delegate 4's permissive regime in §1/Q2. This ADR records that as a **policy
choice**, not an uncontested measurement: the two agree on rejecting the votes and on
allowing `ToolProvider` only with disjoint tool names; the fold kinds (`PromptShaper`,
`BudgetShaper`, `Compactor`) are the disagreement, and the adopted answer treats them as
allowed-with-rules pending an explicit decision on intra-extension ordering and disclosure
identity. If a stricter regime is preferred, §1 bullet and Q2's table should be narrowed
accordingly.

### (c) Binding scope vs closure scope (Delegates 2 and 3)

Delegate 3 reports `hook_scope` marks `empty_stop_guard` unresolvable (HOOK-UNRESOLVED) at
binding scope; Delegate 2 observed `make ext_ambient_inventory` marks it PORT-MEDIATED at
closure scope. Same tool at two scope layers, not an inconsistency.

## 5. What is still unknown

1. `declared_vs_performed` reported `41 passed, 5 FAILED`; the failures were inventory/count
   baseline assertions (17 vs 15 subjects) and not compile failures in touched files, but
   whether the count is stale or genuinely open was not isolated.
2. Multiplicity vs the `declared_vs_performed` witness trick: N>1 same-kind capabilities
   must dispatch *every* element the subject returns, or the fold is measured fail-open
   (flagged by delegate 3; the ADR earlier mis-attributed this to 4). Not exercised against
   real packages.
3. 6.0 `ExtRegistry` shape — whether it keeps a per-extension record around the list
   (`{ id, caps }`); the holder stamp needs an `id` somewhere. Delegate 4 proposed this shape;
   delegate 3 flagged the same as undetermined. Listed as open here because the adopted
   registry representation is a 6.0 decision, not yet taken.
4. Consumption-side row enforcement: matching *out* of a constructor was unmeasured at
   decision time. *Measured 2026-08-26 (v0.33.0, PLAN D9): dispatcher rows are decorative at
   consumption; pinned as the CONSUMPTION (D9) probe in `run_declared_vs_performed.sh`.*
5. Toolchain skew across the delegates: `make check_core` uses the PATH `ailang` binary,
   v0.33.0 (which matches the pinned lock). Delegates 1 and 4 measured on
   `ailang/bin/ailang` v0.33.1-84-g127c1443e; delegate 2 on v0.33.0. The constructor-argument
   (Q3) and capability-typecheck results therefore reflected v0.33.1, not the locked build.
   *Re-run on the pinned v0.33.0 at A4, B1 and B8: the local-sum verdicts reproduced; the
   imported-sum verdicts (Q3 correction) were first measured there.*
6. Whether AILANG accepts `! {…}` annotations on lambdas in constructor-argument position
   was unmeasured at decision time. *Measured at B1/B8 (v0.33.0): accepted, and an annotated
   inline atom is checked against its own annotation (the (i-annot) and IMPORTED SUM (annot)
   rows).*

## 6. Provenance

| Handle | Kind | Asked | Succeeded | Answer file |
|---|---|---|---|---|
| `mot-dlg-1787599891172` | claude | Measure closed-row enforcement in constructor argument position vs record-field WI-B4 | Yes — 7-file matrix | `.motoko/herdr-delegates/answer-mot-dlg-1787599891172.md` |
| `mot-dlg-1787599895137` | codex | Implement `default_hooks`, migrate one extension, mutation test | Yes — compiling, 56/0 | `.motoko/herdr-delegates/answer-mot-dlg-1787599895137.md` |
| `mot-dlg-1787599899154` | claude | Tooling read-analyse: binding keys, coverage unit, witness | Yes — live ambient run | `.motoko/herdr-delegates/answer-mot-dlg-1787599899154.md` |
| `mot-dlg-1787599903186` | codex | Capability type sketch + typecheck + multiplicity | Yes — type-checked | `.motoko/herdr-delegates/answer-mot-dlg-1787599903186.md` |