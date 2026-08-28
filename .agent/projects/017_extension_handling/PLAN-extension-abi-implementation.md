# Plan: implement ADR-001 — `default_hooks` now, capability registration at 6.0

Date: 2026-08-26  
Status: Phase A landed; Phase B (B1–B7) and B8 (the 6.0 break) landed 2026-08-26 on
`arniwesth/mot-129-extension-abi-phase-a`, commits `8df6601` `13436f6` `280cb1f` `2a2c18a`
`9a7c091` `55a823a` (see §Tracking). Prose below that was written before B8 is corrected inline
where B8 changed a premise (payload-row enforcement, the generator, the `tool_handle` rename).  
Grounded source HEAD: 366193c plus the uncommitted `types.ail` / `empty_stop_guard/register.ail`
changes (the `default_hooks` minor; ADR §1 "already landed")  
Plan changes are plan-only.

Sources this plan traces to, cited inline as `[ADR §…]`, `[R §…]` (research), `[DSI I1–I8 / §…]`
(the DST-influence analysis `answer-mot-dlg-1787728183615`), `[RC …]` (codex review of the
analysis, `…1787728921532`), `[RK C1–C10 / M1–M9]` (claude review of the analysis,
`…1787728873263`), and `[AR-codex]` / `[AR-claude]` (the two ADR reviews).

## TL;DR

Two phases, tooling before ABI in both.

**Phase A (minor 5.x, non-breaking).** `default_hooks(id)` and the `empty_stop_guard`
record-update migration are landed but uncommitted. Before they are committed, teach
`hook_scope.locate()` the `{ default_hooks(id) | … }` head (the ADR Q4 fix; `make
ext_hook_scope_selftest` is red today on the stale pin [RK C1]) and derive
`declared_vs_performed`'s subject list from the generated registry (15 → 17; the runner is red
today on staleness, not on a violation [DSI §1.3; RK C7; RC]). Then the three cheap "now"
opportunities: lock the holder-stamp grammar (I7), measure the record-update position (I8's probe),
and migrate the probe's own safe literals (I8). File the AILANG feature request and append the
E/G cases to the existing upstream feedback item (non-blocking).

**Phase B (6.0 major).** Tooling first, in this order: I4 (constructor-argument probe + re-sited
mutant) → I3-6.0 (list-of-constructors reader, per-atom enumeration, fail-closed count/pin) → I1+I2
(coverage unit → (extension, kind, index); `Capability`-variant pin) → I6 (multiplicity validation
at the normalize boundary + `registry_multiplicity` DST) → I5 (per-atom `declared_vs_performed`
arms) → I7 typed atom identity. Only then the ABI break: the `Capability` sum, the `ToolProvider`
collapse, `ExtPorts.proc_exec → tool_handle`, the `{ id, caps }` registry, the re-iterated
dispatchers, the world-token/holder-stamp re-seat, the exhaustive matcher, and the ~20-file DST
fixture migration [RK C8].

No dispatcher merge semantics, hook effect rows, world-token protocol, attribution rows, or
conformance-kit behaviour change in either phase.

## Blast radius

- **Phase A, files changed:** `tools/ext_ambient_inventory/hook_scope.py`,
  `tools/ext_ambient_inventory/fixtures/hook_scope/` (one new control fixture),
  `scripts/dst/run_declared_vs_performed.sh`, `scripts/dst/declared_vs_performed.ail`,
  `src/core/dst_attribution_table.ail` (one test + stale header anchors), `src/core/ext/runtime.ail`
  (one inline test only). Nothing under `packages/` beyond what is already in the working tree.
- **Phase A, output changes:** `ext_hook_scope` moves `empty_stop_guard` from `HOOK-UNRESOLVED`
  to `HOOK-PORT-MEDIATED` (5/17, restoring the pinned yield); `declared_vs_performed` gains two
  subjects (`agentcli`, `herdr`) and its count pins move 15 → 17; one new limitation-probe row.
- **Phase B, files changed:** every `packages/motoko-ext-*/register.ail` (17 in-tree registrations),
  `packages/motoko-ext-abi/types.ail` (6.0), `src/core/ext/{runtime,registry_generated,
  tool_catalog,tool_phase}.ail`, `src/core/ext_world.ail` (no grammar change), `src/core/
  dst_profile_coverage.ail`, `src/core/dst_attribution_table.ail`, `tools/ext_ambient_inventory/
  hook_scope.py`, `tools/profile_definition/{check_no_op_profile,check_fixtures}.py`, both
  inventories' `expected.json` pins, the Makefile `profile_coverage` pin, the new
  `registry_multiplicity` target, and ~20 DST/test files holding full `ExtensionHooks` literals
  (`scripts/dst/*` ×15, `src/core/test/{ext_fixture,stub_step}.ail`, `runtime.ail` smoke literals,
  `scripts/smoke_v2_*` ×5) [RK C8; RC "Missed"].
- **CI and rollback:** every Phase A step is one commit, independently green under `make dst`,
  revertible in isolation. Phase B tooling steps are also one-commit-each and land against the
  5.x ABI (they must be green on the *record* shape before the break); the ABI break itself is one
  atomic commit (ABI + registry + dispatchers + fixtures) because no intermediate tree compiles.
- **External consumers:** the ABI has out-of-repo consumers [R §2; AR-codex "Missed"]. The minor
  is opt-in (full literals still compile [R §3.2]); the major needs a migration note (§"Migration
  mapping") published with the 6.0 tag.

## Scope and invariants

In scope: everything listed in the two phase sequences below. Out of scope: §"Out of scope".

Invariants that must hold at every commit:

1. **Fail-closed derivation.** `hook_scope` never emits a binding it could not parse; an
   unresolvable head/list is a named rejection, not an empty result [DSI I3; RK I1 caveat; AR-claude
   "Missed" (silent atom loss)].
2. **Merge semantics are unchanged.** Concatenation, registry-order patch fold, validated compactor
   chain, first-match, first-intercept, `Deny > Pending > Allow > NoOpinion`,
   `ContinueWithFeedback > Accept > NoDecision` survive as pure functions of a decision list
   [DSI §1.6; RC "Load-bearing"].
3. **Holder stamp grammar.** `"${name}#${idx}"` remains the *prefix* of every stamp; atom identity
   never enters the string [DSI I7; RK C3 — five prefix readers, not three].
4. **The compiler is trusted for payload-row confinement at direct bindings only.** As written
   this invariant read "the compiler is not trusted" [ADR Q3, §1]; B8 measured (v0.33.0) that on
   the *imported* ABI sum the payload rows ARE compiler-enforced at every direct binding, and that
   the hole ADR Q3 measured belongs to *locally declared* sums. What the compiler does not cover is
   the limitation-1 smuggle (a lambda bound to a local record field, passed as the atom); that is
   the derivation plane's job (B1/B2 + classifier 3) [B8 report §4 finding 1; ABI header in
   `packages/motoko-ext-abi/types.ail`].
5. **No hand edits to `registry_generated.ail`** (header forbids); host-owned policy lives in a
   hand-written module the generated code calls [RC I6; RK I6]. Enforced since `55a823a` by
   `make registry_gen_check` against the project-local generator `tools/ext_registry_gen/generate.py`.

## Decisions (status markers)

| # | Item | Status | Source |
|---|---|---|---|
| D1 | `default_hooks(id)` minor + opportunistic record-update migration | **decided, landed** | ADR §1 |
| D2 | `hook_scope` record-update support is a *release gate* for committing D1, not a follow-up | **decided (blocker)** | AR-codex corr. 2; RK M9 |
| D3 | Reject N>1 `ToolPolicy` / `SolverJudge`; `ToolProvider` N>1 only with disjoint names | **decided** | ADR §1, Q2, §4(b) |
| D4 | Fold kinds (`PromptShaper`, `BudgetShaper`, `Compactor`) N>1 allowed under rules | **signed at B8 (`true`)**; `make registry_multiplicity` reports `D4 SIGNED` | ADR §4(b); RC I6; B8 report |
| D5 | Registry representation `{ id, caps }` per extension | **decided, landed at B8**: `ExtEntry { id, caps }` + `ExtRegistry { entries }` in the ABI | ADR §5.3; RC "attribution"; B8 `8df6601` |
| D6 | Coverage unit = (extension, kind, index) | **decided by ADR, justification owed**: per-atom is required only because D4 admits repeated atoms; if D4 narrows to N≤1 everywhere, (extension, kind) suffices | ADR Q1; RC corr. 1 |
| D7 | Empty registration (`register_with_config → []`): reject / omit / explicit disclosure | **decided, kept at B8**: omit from the effective registry by name (the generator emits the omission) | DSI I1; RC corr. 3; B8 report |
| D8 | Inline-lambda-in-record-update-position enforcement | **measured (A4, v0.33.0)**: update position = literal position. Inline lambda body unchecked against its declared row (limitation 1 holds; enclosing row bounds it); a named override with a WIDER row is REJECTED by closed-row unification at the update field — ADR case E does not reproduce on v0.33.0 (it was measured on v0.33.1; toolchain skew, pinned as observed). I8's controls stay inline behind the `control_base() \|` head. | DSI I8, §4; ADR §4(a); A4 rows |
| D9 | Consumption-side (match-out) row enforcement | **measured (2026-08-26, v0.33.0)**: dispatcher rows are DECORATIVE at consumption. A narrow `! {IO}` consumer that `match`es a `K(f)` payload out and applies `f` is accepted even when the f's body (reached via a wider-declared named impl, ADR case E route) performs `Env` — `match9_named.ail` GREEN. Positive control (`consumer_direct.ail`) and isolation (`consumer_isolation.ail`) both REJECTED, so the instrument is sound and the construction side is innocent on the call axis (the Env lives only inside the payload). Implication: B8's dispatchers need body-reading coverage too, not only `register_with_config`. Evidence under `tmp/017-matchout/`; to land permanently as B1's third probe + match-out arm (`run_declared_vs_performed.sh:671-704`). | ADR §5.4; RC "Missed"; RK M5; measured this session |
| D10 | `I6` generator emission — the generator must call the normalize function | **decided, landed (`55a823a`)**: no longer an upstream dependency. The upstream `ailang generate-extension-registry` (v0.33.0) still emits the 5.x record shape and must not be run in this tree; the project-local `tools/ext_registry_gen/generate.py` (`make registry_gen`, verified by `make registry_gen_check`) emits the 6.0 list shape and the `normalize_registration` call. Its body is byte-identical to the file B8 had hand-edited (header only differs), so the hand edit was a bridge, not a residue. | RK I6; commit `55a823a` |

## Phase A — "now" (minor, non-breaking)

Already done — do not re-plan: `default_hooks(id)` at `packages/motoko-ext-abi/types.ail:964–993`
and `packages/motoko-ext-empty-stop-guard/register.ail:16`
`{ default_hooks("empty_stop_guard") | on_solver_candidate: finalize }` [ADR §1, Q4; AR-claude
corr. 3 for the exact literal]. `make check_core` was 56/0 as reported by the implementation
delegate [ADR §1]. These are uncommitted; **A1 must land in the same or an earlier commit** or CI's
`make dst` goes red on `ext_hook_scope_selftest` [RK M9].

### A1. `hook_scope.locate()` learns the record-update head — I3-now [ADR Q4; DSI I3; RK C1, I3]

Blocker.

- Files: `tools/ext_ambient_inventory/hook_scope.py` (`locate()` `:508–571`, `split_record`
  `:263–282`, `_looks_like_hooks` `:573–577`); `tools/ext_ambient_inventory/fixtures/hook_scope/`
  (add `control_record_update_head.ail`; extend `expected.json`).
- Change: before the field split, recognise a head of the form `{ default_hooks(<string>) | … }`
  (also `{ <ident> | … }` where `<ident>` resolves to a `default_hooks(...)` call), strip the
  prefix, resolve `default_hooks` to the ABI literal at `types.ail:964–993`, bind every
  un-overridden slot to the corresponding default lambda text, then run the existing tiling
  assertion (`SLOTS`, `hook-slot-missing`) over the merged field set. Overridden fields go through
  `_binding_text` unchanged (inline lambda or bare name → declaration). Any other update head (a
  computed base, a base that is not `default_hooks`) is the existing `hook-record-unresolvable`
  rejection — fail closed.
- Pins: **keep** `expected.json:91–93` as-is (it already pins `empty_stop_guard` under
  `hook_port_mediated`; the selftest is red *because* the tree stopped parsing it) [RK C1 —
  corrects DSI I3's "update the yield sets"]. Add one control fixture that uses the update head
  and one reject fixture with a non-`default_hooks` head.
- Verify: `python3 tools/ext_ambient_inventory/derive.py --hook-scope-selftest --no-provision`
  → rc 0, `HOOK-PORT-MEDIATED` yield = 5 incl. `empty_stop_guard`; `make ext_hook_scope`;
  `make ext_hook_scope_selftest`; `make ext_ambient_inventory` unchanged (closure scope was
  already `PORT-MEDIATED` [ADR §4(c)]).
- Acceptance: `empty_stop_guard` is HOOK-PORT-MEDIATED with the tiling assertion satisfied by
  construction; 10/17 → 9/17 HOOK-UNRESOLVED, the remaining 9 being the unrelated door-3 `show`
  residue [ADR Q4; RK C2].

### A2. Derive `declared_vs_performed`'s subject list from the registry — I5-subject-derivation [DSI §1.3, I5; RK C7; RC]

Blocker.

- Files: `scripts/dst/run_declared_vs_performed.sh` (`EXTS` `:91–93`; count pins around
  `:166–174`, `:426–428`); `scripts/dst/declared_vs_performed.ail` (imports `:123–137`, arms).
- Change: replace the hand-listed `EXTS` with the `reg_names` the runner already computes from
  `src/core/ext/registry_generated.ail` (`:166–167`); add import + arm for `agentcli` and
  `herdr`; move every `15`/`14-of-14` pin to be computed from `reg_names` (or pinned at 17 with a
  comment naming the registry as the producer). Also update `known_hook_ids()` in
  `src/core/dst_attribution_table.ail`, which omits the same two [RC "Missed"].
- Verify: `make declared_vs_performed` — the member-for-member row is green; **record how many
  of the 5 failures at ADR §5.1 this closes**. The other four are believed to be count pins [RK M3]
  but were not re-run; if any survives it is a genuine open item and must be reported, not pinned
  over. `make attribution_table`.

### A3. Lock the holder-stamp grammar — I7-now [DSI I7; RK C3; RC I7]

Opportunity; cheap; do before anyone designs D5.

- Files: `src/core/dst_attribution_table.ail` (test beside `test_instance_suffixed_ids_intersect`
  `:635–642`; fix stale header anchors at `:110`, `:117`), `src/core/ext/runtime.ail` (one inline
  test next to `hook_name` `:72–79`).
- Change: add `test_atom_index_never_in_holder_stamp` asserting semantic ownership — a stamp
  `name#idx` resolves to base `name` through `hook_name` and `hook_id_matches`, and that no
  stamp in the registry contains a second `#`. Correct the header's reader inventory to the five
  real prefix readers: `runtime.ail:72–79`, `:207`, `session.ail:509`, `tool_phase.ail:198`,
  `dst_attribution_table.ail:323`.
- Verify: `ailang test src/core/dst_attribution_table.ail`; `make attribution_table`;
  `make predicate_anchors` (if it covers this header; otherwise note it does not [RK C3]).

### A4. Record-update-position limitation probe — I8-probe [DSI I8, §4; ADR §4(a), §5.6]

Opportunity; a measurement, decides D8.

- Files: `scripts/dst/run_declared_vs_performed.sh` (next to the two limitation probes `:671–704`).
- Change: add a probe row that constructs `{ default_hooks("p") | on_budget_plan: <X> }` in
  both shapes: (a) an inline lambda performing an effect outside the slot row; (b) a named function
  declared with a *wider* row than the slot. Assert the checker's verdict for each and pin it
  (expected from ADR cases E/G: (b) accepted; (a) unmeasured — pin whatever is observed, the row
  goes red by design when upstream changes [DSI §4 toolchain skew]). Measure on the PATH `ailang`
  v0.33.0 that `make check_core` uses [AR-claude corr. 5].
- Verify: `make declared_vs_performed` with the new row in the limitation-probe section.

### A5. Migrate the probe's own safe literals — I8 [DSI I8; RK C8, I8]

Opportunity; conditional on A4.

- Files: `scripts/dst/declared_vs_performed.ail` (`witness_hooks()` `:512–531`, `control_base()`
  `:472`).
- Change: rewrite `witness_hooks()` and `control_base()` as `{ default_hooks("dvp_witness") |
  on_budget_plan: …, on_response_intercept: …, on_solver_candidate: … }`. Leave
  `env_control_hooks`/`fs_control_hooks` (`:458–470`) inline-in-literal unless A4 shape (a) is
  measured *checked*. Scope note: this fixes 1 of ~20 full-literal sites [RK C8]; the other 19 are
  deliberately left for Phase B step B7, where they must change anyway.
- Verify: `make declared_vs_performed`; `ailang check scripts/dst/declared_vs_performed.ail`.

### A6. Upstream AILANG feature request — non-blocking, tracked [R §3.4; ADR §1; AR-claude "Missed"]

- Action: via the `ailang-feedback` skill, (a) file the optional/defaultable-record-field request
  against `sunholo-data/ailang`; (b) **append** the E/G named-function cases to the existing
  feedback item `fb_74f53de3ae65854c` rather than re-filing. Record both ids in this plan's
  tracking table when done. Nothing in either phase waits on it.

Phase A commit order: A1 (with the working-tree `default_hooks` changes) → A2 → A3 → A4 → A5 → A6.
Gate after each: `make dst`.

## Phase B — 6.0 (capability registration; tooling first)

Precondition restated normatively [ADR §1 "steel"; AR-codex corr. 9]: **6.0 MUST NOT ship until
B1–B6 are green against the 5.x record shape** and B8's ABI commit turns them green again against
the list shape. Every tooling step is written to accept *both* shapes during the transition where
feasible, so it can land before the break.

### B1. Constructor-argument limitation probe + re-sited mutant — I4 [ADR Q3; DSI I4; RK I4; RC I4]

Blocker for any compiler-side claim at 6.0.

- Files: `scripts/dst/run_declared_vs_performed.sh` (probe section `:671–704`; mutant control
  `:477–503`).
- Change: add a third limitation probe: `type C = K((string) -> () ! {IO})` constructed with (i) an
  inline `Env`-performing lambda, (ii) a wide-rowed named function; assert both **accepted** (the
  hole), and assert that a narrowed *enclosing* function row **rejects** (i). **B8 outcome
  (`2a2c18a`): those rows measure a LOCAL sum and still hold; the IMPORTED-SUM table added at B8
  (7 rows) shows the same sum, once imported — as the ABI's `Capability` always is — REJECTS (ii)
  on closed-row unification and (i) at the payload row; only the record-field `smuggle`
  (limitation 1) survives. `mutant_register`'s widened control changed verdict (5.x accepted →
  6.0 rejected) and was re-pinned.** Add a **match-out
  arm** (RK M5; RC): a function with a narrow declared row that matches `K(f)` and applies `f`;
  pin the verdict — this measures D9. **LANDED (cc3560b, 2026-08-26): the D9 match-out arm is
  now pinned as a fourth probe at the bottom of the section (CONSUMPTION (D9) + control),
  measured on v0.33.0 — dispatcher rows are decorative at consumption; see the D9 row in the
  Decisions table. No further change to this arm is needed when B1 runs.** Keep the existing top-level `mutant_budget` (it validly
  measures a named function's own row [RC]) and add a second mutant whose "narrowed row rejects"
  claim is made about `register_with_config`'s row (`declared_vs_performed.ail:410–420`). Update
  the runner's producer-3 rationale text (`:462–466`) to the precise five-part enforcement plane
  [AR-codex corr. 4].
- Verify: `make declared_vs_performed`. Outcome of the match-out arm is recorded in D9; if the
  dispatcher rows do not bound the applied payload, B8's dispatchers need body-reading coverage
  too, not only the registration function.

### B2. `hook_scope.locate()` learns the list-of-constructors head — I3-6.0 [ADR Q1, Q3; DSI I3; RK I3; RC I3]

Blocker; this is the enforcement plane and the producer for B3.

- Files: `tools/ext_ambient_inventory/hook_scope.py` (`locate` `:508–571`, `_binding_text`
  `:732–764`, `balanced`, `_APPLY`); fixtures `expected.json`; new `reject_capability_list_*`
  and `control_capability_list_*` fixtures.
- Change: accept a tail expression that is a **literal list of constructor applications**
  `[Kind(arg, …), …]` (with `balanced()` per argument so lambdas containing commas split
  correctly). For each atom, every function-typed argument is a binding: inline lambda → its text;
  bare name → resolve to declaration and read the body (the existing `_resolve_func` path), so a
  wide-rowed named function is *scanned, not trusted*. Emit atoms keyed `(extension, kind, index)`.
  Fail closed: any non-literal list, computed element, spread, or delegated call yields
  `capability-list-unresolvable` (replacing `hook-slot-missing`, which is meaningless over a list).
  Add an **independent element count** (count top-level commas in the balanced list vs atoms
  emitted) and a **pinned per-extension atom count** in `expected.json` — the fail-closed
  denominator [AR-claude "Missed"; RK I1]. Config-dependent lists are *not* supported: this is the
  "literal lists only" convention [RC I1/I3], and it becomes an ABI rule in B8.
- Verify: `make ext_hook_scope_selftest` (fixtures cover: literal list, N>1 same kind, named-fn
  atom, computed list rejected, element-count mismatch rejected); `make ext_hook_scope` on the
  5.x tree still resolves records (both heads coexist until B8).

### B3. Coverage unit → (extension, kind, index) + `Capability`-variant pin — I1, I2 [ADR Q1; DSI §1.2, I1, I2; RK C4, I1, I2; RC I1, I2]

Blocker; the two real redesigns [ADR §3 item 2].

- Files: `src/core/dst_profile_coverage.ail` (`HookSlot` `:93–101`, `all_hook_slots` `:166–169`,
  `hook_dispatch` `:117–130`, `slot_accounting` `:246–259`, `unconditional_exclusions`
  `:261–272`, `validate_disclosure` `:278–284`, `ExtensionDisclosure` `:172–176`);
  `scripts/dst/profile_coverage_dst.ail`; `tools/profile_definition/check_no_op_profile.py`
  (`is_unconditional` regex `:227–229`); `tools/profile_definition/check_fixtures.py`
  (five-slot regex `:300–322`, `check_barrier_count` `:224–236`); `Makefile:538–552`.
- Change (I1): replace `HookSlot` with `CapabilityKind` (one constructor per `Capability` variant;
  `ToolProvider` absorbs `on_tool_handle`+`provided_tools`, `DescribeTools` is its own kind);
  keep `hook_dispatch` total over it (`ToolProvider` remains the only `Gated` kind). Replace
  `covered/excluded: [HookSlot]` with `[{ kind, index }]`, and add `atoms: [{ kind, index }]`
  per extension, **supplied by B2's output** (the only fail-closed producer; an extension B2
  cannot resolve cannot be installed in a profile [RK I1]). Exhaustion ranges over `atoms`;
  disjointness is per atom, so legal N>1 no longer trips `HookSlotDoubleClassified`. Empty
  `atoms` → `InstalledWithNoCapabilities(ext)` per D7. Replace the "all eight ABI slots" messages.
  State the D6 justification in the module header [RC corr. 1]. Note the real pre-fix failure mode
  is a *silent vacuous "covered"*, not rejection [RK C4] — write the header that way.
- Change (I2): replace the `awk … grep -c '^  on_'` pin with a portable count of variant lines
  inside `type Capability` (no `\s`; use `[[:space:]]`), cross-pinned to an AIL entry point that
  prints `length(all_capability_kinds())` — Make cannot evaluate AILANG [RC I2]. Count *kinds*, not
  instances. `check_fixtures.py` reads the same enumeration.
- Transition: during B3–B7 the ABI still has the record, so the pin producer must accept either
  `type ExtensionHooks` (8) or `type Capability` (7) until B8 flips it.
- Verify: `make profile_coverage`; `make profile_definition`; `ailang test
  src/core/dst_profile_coverage.ail`; `make driver_plus_no_ops` (barrier count derivation).

### B4. Multiplicity validation at the registration boundary — I6 [ADR Q2, §4(b); DSI I6; RK I6; RC I6]

Blocker for admitting N>1 at all.

- Files: new hand-written `src/core/ext/registry_normalize.ail` exporting
  `normalize_registration(id: string, caps: [Capability]) -> Result[ExtEntry,
  RegistrationRejection]`; `src/core/ext/registry_generated.ail` (`parse_tokens` `:55–69`,
  `with_id` `:51–53`) via the generator (D10); new `scripts/dst/registry_multiplicity_dst.ail`;
  Makefile `registry_multiplicity` target added to `DST_TARGETS` (`:430–439`).
- Change: rules per D3 — reject a second `ToolPolicy` or `SolverJudge` atom; build a per-extension
  tool-name set across all `ToolProvider` atoms and reject any duplicate (even inside one variant).
  Fold kinds: pass through in list order (list order = sub-order / precedence / chain order per
  ADR Q2 table) **only if D4 is signed off**; otherwise reject N>1 for them too — the gate is a
  single constant in the normalize module so narrowing D4 is a one-line change. Rejection names
  `id`, variant, and duplicate index; never silently discards; one bad extension rejects that
  extension's registration (recommend: reject the whole registry build, since silent omission is
  the fail-open shape [AR-codex "Missed"]). D7's `[]` handling lives here too.
- DST: fixtures in the `profile_definition` style (`Makefile:554–562`) — one rejecting fixture per
  rule, each one mutation away from a negative control that loads clean.
- Transition: the module can be written and DST'd against a *local* `Capability` sketch (research
  §3.3 / A4's type-checked scratch) before B8, so the target is green before the break.
- Verify: `make registry_multiplicity`; `make dst`.

### B5. Per-atom `declared_vs_performed` arms + all-atoms witness — I5 [ADR §5.2; DSI §1.3, I5; RK I5; RC I5]

Blocker if D4 admits N>1 for any fold kind; opportunity if 6.0 ships N≤1 everywhere.

- Files: `scripts/dst/run_declared_vs_performed.sh`, `scripts/dst/declared_vs_performed.ail`,
  `src/core/ext/runtime.ail` (`PreStepStage` `:303–320` gains `atom: int`).
- Change: generate arms per (extension, kind, index) from B2's atom list (not per extension).
  Keep the witness-after-subject trick, but assert the registry constructor is
  `[…subject atoms in returned order…, …witness atoms…]` — this requires the D5 registry to
  preserve per-kind install-order concatenation, which B8 must assert. Add a structural row that
  `length(atoms_of_kind)` were *visited*: `Compactor` via `PreStepChainResult.stages` + atom index;
  `BudgetShaper`/`PromptShaper` via per-atom sentinel patches. First-match kinds (`ToolProvider`,
  `ResponseInterceptor`) are path-bound: mark atom k>1 `CONFOUNDED-BY-SHORT-CIRCUIT` and settle
  them only by B1/B2 body evidence. Re-write producer-1 greps (`:113`, `:137`, `check_slot_row`
  `:531–540`, stale-row grep `:596`) to read `| Kind((…) -> T ! {row})` lines.
- Verify: `make declared_vs_performed`; arm count = Σ atoms (log it — no silent caps).

### B6. Typed atom identity, stamp unchanged — I7-6.0 [DSI I7; RK C3]

- Files: `src/core/ext/runtime.ail` (`PreStepStage`, `emit_dummy_hook` sites), `src/core/ext_world.ail`
  (no change — `stamp_holder(world, entry.id)` stays per extension).
- Change: atom identity goes into typed records (`PreStepStage.atom`, dummy-hook emission), never
  the stamp string. A3's test guards it.
- Verify: `ailang test src/core/dst_attribution_table.ail`; `make attribution_table`.

### B7. Migrate the ~20 full-literal DST/test fixtures behind a shim [RK C8; RC "Missed"]

Do this *before* B8 so the ABI commit is smaller.

- Files: `src/core/test/ext_fixture.ail`, `src/core/test/stub_step.ail`, the 15 `scripts/dst/*`
  literals, `runtime.ail` smoke literals, `scripts/smoke_v2_*` ×5.
- Change: route every literal through one test-owned constructor in `ext_fixture.ail`
  (`fixture_hooks(id, overrides)`), using `default_hooks` today. At B8 only that constructor
  changes shape. Run the `rg -n 'on_solver_candidate:|ExtensionHooks' scripts src/core/test`
  audit before and after; the after-count outside `ext_fixture.ail` must be zero.
- Verify: `make dst` (all `DST_TARGETS`); `make check_core`.

### B8. The ABI break — one atomic commit [ADR §1; R §3.3, §4; ADR Q2; DSI §1.4, §1.6]

- Files: `packages/motoko-ext-abi/{types.ail,ailang.toml}` (6.0), all 17 `register.ail`,
  `src/core/ext/{runtime,registry_generated,registry_normalize,tool_catalog,tool_phase}.ail`,
  `tools/ext_call_inventory` + `tools/ext_ambient_inventory` `expected.json` pins,
  `packages/motoko_ext_conformance` (ABI-lockstep bump), the B3 pin, B7's shim.
- Change:
  1. `type Capability` per research §3.3 as type-checked by delegate 4 (ADR §6 `…9903186`):
     `DescribeTools`, `PromptShaper`, `BudgetShaper`, `Compactor`, `ToolProvider([string],
     () -> [ToolSchema], (ExtCtx, ToolCallEnvelope) -> ToolHandleOutcome ! {…})`,
     `ResponseInterceptor`, `SolverJudge`, `ToolPolicy` — payload rows copied verbatim from the
     5.x slots. As planned, the `types.ail` comments were to say the rows are *ABI claims*
     enforced by B1/B2/B5, not by the compiler [ADR Q3; AR-claude "Missed" re §3.2]; **as landed
     (`8df6601`, `2a2c18a`) the header says the rows ARE compiler-enforced at the constructor on
     the imported sum, and that B1/B2 + classifier 3 cover only the limitation-1 smuggle** [B8
     report §4 finding 1]. Add the "literal lists only" registration rule (B2).
  2. `register_with_config(cfg) -> [Capability]`; `provided_tools` + `on_tool_handle` collapse
     into `ToolProvider`; `ExtensionHooks` and `default_hooks` removed.
  3. `ExtPorts.proc_exec → tool_handle` (`types.ail:324–406`), kept distinct in naming from the
     provider-side `ToolProvider` to avoid conflating "invoke a host tool through the port" with
     "handle a tool as a provider" [RC "Missed"]. **Landed as the 6.0 second break (`9a7c091`),
     rename only, no semantic change; the WI-D15 row note in `types.ail` keeps the historical
     `proc_exec` row as a verbatim quote.**
  4. `ExtRegistry` = `[{ id: string, caps: [Capability] }]` per D5; `parse_tokens` builds the
     wrapper through `normalize_registration` (B4); registry order = per-extension lists in
     install order, per-kind concatenation (B5's invariant — add an inline test).
  5. `runtime.ail` dispatchers: each fold filters the registry to its kind, preserving per-slot
     merge semantics verbatim; `contains_tool(h.provided_tools, name)` (`:404`) becomes a match on
     the `ToolProvider` name list; `stamp_holder(world, entry.id)` / `clear_holder` re-seat at the
     same four sites (`:289, :410, :434, :464` / `:337, :423, :446, :526`); `is_test_dummy` and
     `emit_dummy_hook` take the id from the wrapper. `tool_catalog.ail:115–126`
     (`collect_ext_schemas`) and `tool_phase.ail:198` (`scratchpad_extension_active_rec`) get the
     same selection/ownership migration [RC "Missed"].
  6. The exhaustive `match` over `Capability` lives only in `runtime.ail` — adding a variant later
     breaks that one site [R §2].
  7. World-token protocol unchanged: `ctx.world` → threaded → `next_state` [R §1 layer 4].
- Verify (all must be green in the same commit): `make check_core`; `make dst` — in particular
  `profile_coverage` (pin now counts `Capability` variants), `declared_vs_performed` (per-atom
  arms, no `CONFOUNDED` entry that B2 cannot resolve), `ext_hook_scope_selftest`,
  `registry_multiplicity`, `ext_call_inventory`/`ext_ambient_inventory` (+selftests, renamed pins),
  `attribution_table`, `conformance`; `git diff --check`.

Phase B commit order: B1 → B2 → B3 → B4 → B5 → B6 → B7 → B8. B1–B7 each land green on the 5.x
tree; B8 is the single break.

## What does not survive, and what it costs [ADR Q3, §5; DSI §4; RC; RK M4]

- **"Per-slot compiler enforcement untouched" [R §3.3] was planned as gone — and B8 measured
  it as kept.** This plan was written on ADR Q3's finding that payload rows bound nothing in
  constructor-argument position, for inline lambdas *and* named functions. B8 (`2a2c18a`,
  v0.33.0) showed that finding is a property of *locally declared* sums; on the *imported* ABI
  sum the payload rows are compiler-enforced at every direct binding [B8 report §4 finding 1].
  What the derivation plane (B1/B2/B5 + classifier 3) must still cover is the limitation-1
  record-field smuggle. B2's reader now pins all 17 extensions at binding scope (`280cb1f`,
  17 × 8 atoms) — the "4/17 resolved" figure [RK C2] is the pre-B2 state.
- **Per-atom attribution.** Attribution stays per extension (D4 semantics); two atoms of one
  extension are indistinguishable in `ext_effect ext=…` lines. Accepted; atom identity is typed
  (B6), not stamped.
- **Runtime witness for first-match kinds.** Atom k>1 behind a handling atom 1 can never be
  runtime-witnessed; only body reading certifies it (B5 `CONFOUNDED-BY-SHORT-CIRCUIT`).
- **The `on_*` count pin** has no producer post-6.0; replaced, not re-targeted (B3).
- **Registration-time effects** remain a disclosed ambient gap [R §1]; B1 cannot settle them.
- **Toolchain skew** [ADR §5.5]: Q3 was measured on v0.33.1; A4/B1/B8 re-measured on the pinned
  v0.33.0 (local-sum verdicts reproduced; the imported-sum verdicts were first measured at B8),
  and every limitation row goes red by design when upstream fixes the surviving hole
  (limitation 1).

## Migration mapping

| 5.x | 6.0 | Notes |
|---|---|---|
| `register_with_config(cfg) -> ExtensionHooks` | `-> [Capability]` | literal list only |
| `{ default_hooks(id) \| on_x: f }` / full literal | `[Kind(f), …]` | `id` no longer in the record; it comes from the order entry |
| `on_describe_tools` | `DescribeTools(f)` | concatenated |
| `on_build_system_prompt` | `PromptShaper(f)` | fold, registry order |
| `on_budget_plan` | `BudgetShaper(f)` | fold, last-Some-wins |
| `on_pre_step ! {AI, IO, Trace}` | `Compactor(f)` | validated chain |
| `provided_tools` + `on_tool_handle` | `ToolProvider(names, schemas, handle)` | disjoint names per extension |
| `on_tool_policy` | `ToolPolicy(f)` | N=1 |
| `on_response_intercept ! {IO, Process, FS, Clock}` | `ResponseInterceptor(f)` | first-intercept |
| `on_solver_candidate ! {Process}` | `SolverJudge(f)` | N=1 |
| `ports.proc_exec` | `ports.tool_handle` | rename only |
| `ExtRegistry = { hooks: [ExtensionHooks] }` | `[{ id, caps }]` | D5 |
| `HookSlot` / `all_hook_slots()` | `CapabilityKind` / `all_capability_kinds()` | B3 |
| `ExtensionDisclosure.covered: [HookSlot]` | `[{ kind, index }]` + `atoms` | B3 |

Publish this table with the 6.0 tag for out-of-repo consumers; the minor needs no note.

## CI and rollback

- Phase A: `make dst` after every commit; rollback = revert that commit. A1 is coupled to
  committing the working-tree `default_hooks` change — revert them together.
- Phase B tooling (B1–B7): each green under `make dst` on the 5.x ABI; individually revertible.
- B8: single commit; rollback = revert B8 alone (B1–B7 stay valid on 5.x by construction). No
  intermediate state may leave a `DST_TARGETS` member pointing at a shape that does not compile.
- CI stays target-based (`verify_extensions` → `make check_core`, `make dst` components); no new
  script paths in the workflow.

## Tracking

| Item | Id / owner | Status |
|---|---|---|
| AILANG optional-field request (A6a) | `fb_f7ecc535fde19c8e` (MCP `submit_feedback`, category feature, 2026-08-26) | filed |
| E/G cases appended to `fb_74f53de3ae65854c` (A6b) | `fb_c1cf1a339764a683` — the MCP channel has no append primitive, so filed as an explicit addendum referencing `fb_74f53de3ae65854c` (category limitation, 2026-08-26); includes the v0.33.0 re-measurement | filed as addendum |
| Phase A implementation (A1–A5) | Linear MOT-129, branch `arniwesth/mot-129-extension-abi-phase-a`, commits 56e0b8b 17d0fd1 1f7974b dcdcde7 d033f8a | landed |
| Phase B tooling (B1–B7) | same branch, up to `2f66ffc` | landed |
| B8 — the 6.0 break | `8df6601` (ABI 6.0, 17 packages + host + fixtures), `13436f6` (HookSlot half deleted), `280cb1f` (B2 hook_scope 17 × 8 atom pins), `2a2c18a` (declared_vs_performed on the 6.0 payload rows; IMPORTED-SUM rows), `9a7c091` (`ExtPorts.proc_exec → tool_handle`) | landed |
| Generator emits `normalize_registration` call (D10) | `55a823a` — project-local `tools/ext_registry_gen/generate.py`; `make registry_gen` / `make registry_gen_check`; not an upstream item | landed |

## Out of scope

- The untyped bus / pub-sub (rejected, ADR §1; revisit only for no-response observational hooks).
- Door-3 `show` residue that keeps 9/17 extensions HOOK-UNRESOLVED [RK C2] — separate project.
- Narrowing registration rows (`register_with_config ! {Env, FS}` etc.; 9/15 read `Env`) — a
  precondition for *compiler-side* claims [DSI I4 risk], not for this plan's tooling-side ones.
- Any change to merge semantics, effect rows, the world-token codec, attribution rows, the
  conformance kit's scenarios, or `dst_harness.ail` (class (i) [DSI §1.1]) and the Bun L2 harness
  (class (i) [RK M7]).
- Runtime registration manifests for config-dependent capability lists [RC I1] — 6.0 forbids
  computed lists instead; a manifest is a 6.x follow-up if the restriction proves too tight.
- Re-running the ADR's seven-file effect matrix on the pinned toolchain beyond what A4/B1 add.
