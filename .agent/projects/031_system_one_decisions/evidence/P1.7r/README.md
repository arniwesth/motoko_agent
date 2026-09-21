# P1.7r — the tool self-test fixtures onto ABI 8.0 (evidence)

PLAN-001 (031) §3 **P1.7r**, line R, brief `LEG-P1.7r.md`. Scope: the **17 fixtures** under
`tools/ext_ambient_inventory/fixtures/hook_scope/` plus their pin file `expected.json`; then, by two
orchestrator scope additions during the part (§4, §5): **classifier 2** (`tools/ext_call_inventory/`)
and **classifier 3** (`tools/ext_ambient_inventory/derive.py`), taught the 8.0 views. The 39
`scripts/dst/fixtures/adr001_boundary/` files are P0.2's frozen suite and were not touched; nothing
under `packages/` or `src/` was touched; `hook_scope.py` (P0.3's gate) was not touched.

Branch `arniwesth/031-abi-8-0`; started at `d83b8d63`, HEAD moved under this part to `6d81fbce`
(P1.3r's follow-up), `6d668fdd` (P1.6r) and `3fec575e` (the R-G pre-gate runner) -- none touched these
surfaces; every check below was re-run against `6d668fdd` (the HEAD workspace, the before/after and
the mutgate clone), and the four `make` targets once more at `3fec575e`, the commit's parent
(`AFTER-make.log`). AILANG v0.33.0.

## 1. The self-tests as they stood (before any change) — `BASELINE-as-they-stand.log`

| target | exit | what failed, and why |
|---|---|---|
| `make ext_hook_scope_selftest` | 2 | **all 17 fixture rows and all 29 gate rows green**; 4 yield pins red: `registration_heads` (18 × `capability-list`, derived `config-caps`), `registration_shape_results` (18 × `fail`, derived `pass`), `shape_binding_rejections` (35, measured 0) — the three P1.2a–d moved and nobody re-pinned; and `SHIPPED VERDICT MOVED: closure PORT-MEDIATED is []`, expected the pinned 4 — **§4 below** |
| `make ext_ambient_inventory_selftest` | 2 | its 14 fixtures green, cache precondition 18/18 established (the 18 roots are 8.0 now, so it provisions); 1 yield pin red: `port_mediated` expected 4, derived [] — the same cause, **§4** |
| `make ext_call_inventory_selftest` | 0 | green |

So the cache precondition that failed closed at P0.5 and P1.1 is met at HEAD, and everything that is
red is a tree-wide yield pin: three moved by P1.2 (re-pinned here, §3) and one moved by P0.4 through
the ABI -- a classifier blind to the 8.0 views, fixed here under the orchestrator's scope additions
(§4, §5), after which the pin is green **unmoved**.

## 2. The 17, migrated or kept — `expected.json`, each fixture's header

Every migrated fixture is on the 8.0 head: the record `{ config, caps }` at the registration tail,
every payload a **named top-level function on its row's view** (`PureCtx`, `AiCtx`, `ProcessCtx`,
`ProviderCtx`, `InterceptCtx`), `DescribeTools` on `Json`, `ToolProvider`'s row `+Trace`, a captured
registration value disclosed through `config` and decoded from `ctx.ext_config` (Amendment 3), the
eight-atom fixtures still eight atoms in the canonical order. The **walk verdicts and atom counts did
not move on any fixture** — only the head and shape pins, which is what migrating changes.

| # | fixture | disposition | walk (unchanged) | atoms | shape pin: 7.4 → 8.0 | `ailang check` on 8.0 |
|--:|---|---|---|--:|---|---|
| 1 | `control_capability_list_empty` | **migrated** | PORT-MEDIATED | 0 | fail [return-shape-unsupported] → **pass** | clean |
| 2 | `control_capability_list_inline` | **kept 7.4** | PORT-MEDIATED | 3 | fail [payload-inline-lambda, return-shape-unsupported] — unchanged | clean |
| 3 | `control_capability_list_named_wide` | migrated | AMBIENT | 1 | fail [return-shape-unsupported] → **pass** | **rejected by design**: the named judge declares `{Env, Process}` against `SolverJudge`'s closed `{Process}` — `incompatible closed rows … extra labels [Env]` (P0.4's measurement; Amendment 2) |
| 4 | `control_capability_list_same_kind` | migrated | PORT-MEDIATED | 4 | fail [payload-inline-lambda, payload-let-bound, return-shape-unsupported] → **pass** (delegated at `caps`, all named) | clean |
| 5 | `control_ext_ports_call` | migrated | PORT-MEDIATED | 8 | fail [payload-inline-lambda, return-shape-unsupported] → **pass** | clean (`AiPorts.ai_step` on `AiCtx`) |
| 6 | `control_hook_reaches_env` | migrated | AMBIENT | 8 | same → **pass** | **rejected by design**: `Env` performed on a rowless `PureCtx` slot — Amendment 3's measured fact |
| 7 | `control_interpolated_call` | migrated | AMBIENT | 8 | same → **pass** | **rejected by design**: `Clock` on a rowless slot, same class |
| 8 | `control_named_hook_in_register` | migrated | AMBIENT | 8 | same → **pass** | clean |
| 9 | `control_registration_only` | migrated | PORT-MEDIATED (registration reads `std/env.getEnvOr`) | 8 | same → **pass** | clean |
| 10 | `reject_applied_local` | **kept 7.4** | UNRESOLVED [applied-local] | 8 | fail [payload-inline-lambda, return-shape-unsupported] — unchanged | rejected (7.4 text, pre-existing) |
| 11 | `reject_binding_unresolvable` | migrated | UNRESOLVED [hook-binding-unresolvable] | 8 | fail [payload-inline-lambda, payload-unresolved, return-shape-unsupported] → fail [**payload-unresolved**] | rejected by design: `undefined variable: some_hook_from_nowhere` |
| 12 | `reject_capability_list_arity` | migrated | UNRESOLVED [capability-list-unresolvable] | – | fail [list-not-enumerable, return-shape-unsupported] → fail [**list-not-enumerable**] | rejected by design: the arity |
| 13 | `reject_capability_list_computed` | migrated | UNRESOLVED [capability-list-unresolvable] | – | head **null**, fail [caps-computed, return-shape-unsupported] → head `config-caps`, fail [**caps-computed**] | clean |
| 14 | `reject_capability_list_element` | migrated | UNRESOLVED [capability-list-unresolvable] | – | → fail [**list-not-enumerable**] | clean |
| 15 | `reject_capability_list_juxtaposed` | migrated | UNRESOLVED [capability-list-unresolvable] | – | → fail [**list-not-enumerable**] | rejected by design: `++` over two `Capability` values |
| 16 | `reject_capability_list_unknown_kind` | migrated | UNRESOLVED [capability-list-unresolvable] | – | → fail [**list-not-enumerable**] | rejected by design: `undefined variable: Judge` |
| 17 | `reject_unknown_callee` | migrated | UNRESOLVED [unknown-callee] | 8 | fail [payload-inline-lambda, return-shape-unsupported] → **pass** | clean |

**Migrated 15, kept 2.** The compiler column is informational (`CHECKS.log`, from the committed-HEAD
workspace): the self-test compiles each fixture only to write the std rows it needs and never asserts
the verdict, and the fixtures marked *by design* are unresolvable or ill-rowed on purpose — the third
layer (the pinned compiler) refusing what the gate passes and the walk scans is the point of #3, #6, #7.

**The two kept, and the gate behaviour each pins:**

- `control_capability_list_inline` — its purpose is the **per-atom argument split over inline lambdas
  whose parameter lists hold commas**. 8.0 forbids the form at the boundary; migrated, it would have
  nothing to split. The gate is testing the old form: it pins `payload-inline-lambda` (facts 1 and 4)
  and `return-shape-unsupported` (the 7.4 bare list) on exactly this text, beside the walk's clean
  verdict and the three-atom count.
- `reject_applied_local` — a hook that **applies a value closed over at registration** (door 6's
  corner). A named top-level function captures nothing, so the construction has no 8.0 form; on 8.0
  the same walk rejection exists only as an applied parameter of a higher-order helper (herdr's `f`,
  pinned in the yield). The gate is testing the old form: `payload-inline-lambda` (fact 4 is its stated
  reason) and `return-shape-unsupported`, beside the walk's `applied-local`.

Both keep their code bytes identical to HEAD (only a header note was added; verified by diffing the
non-comment lines).

## 3. Re-pins, by hand, each with its reason — `expected.json` `yield._comment`

| pin | was | now | reason |
|---|---|---|---|
| `registration_heads` | 18 × `capability-list` | 18 × `config-caps` | P1.2a–d put every package on the record head; measured 18/18 at HEAD |
| `registration_shape_results` | 18 × `fail` | 18 × `pass` | same; the orchestrator's intakes read 6 → 11 → 16 → 18 of 18 across the four batches |
| `shape_binding_rejections` | 35 | 0 | the 35 moved with the batches (32 → 18 → 9 → 0 remaining) |
| `capability_list_atoms` | 45 over 18 | **unchanged** | measured green, and **re-counted by hand** from each `register.ail` at HEAD (`ATOMS-hand-count.txt`: depth-0 constructor heads in the literal list, following compose's and herdr's delegation at `caps`) — 45 over 18 of 18, every package matching |
| `hook_port_mediated` 6, `hook_ambient` 3, `door_3_residue` {intToFloat, show} | | **unchanged** | measured green at HEAD |
| `closure_port_mediated` | 4 | **unmoved, and green again** | it read 0 of 18 at HEAD because classifier 2 could not read the 8.0 ABI's projections (§4); with the classifier taught, the closure measures exactly these four again -- so it was not re-pinned to `[]`, which would have recorded a classifier that resolves nothing as the expected state |
| the 17 fixture pins | | per §2 | the fixture's own text |

P0.3's registration-shape pins therefore moved exactly where 8.0 moved them and nowhere else.

## 4. Classifier 2 taught the 8.0 views — `tools/ext_call_inventory/` (orchestrator scope addition 1) — `BEFORE-AFTER.md`, `json/`

**What was found.** After §2 the hook-scope self-test still had one failure and the ambient inventory
self-test one, with one cause: `SHIPPED VERDICT MOVED: closure PORT-MEDIATED is []`. The ambient
inventory's closure mode runs classifier 2 (`tools/ext_call_inventory/derive.py`, `scan_file`) over
every module of each extension's closure, and every closure holds `packages/motoko-ext-abi/types.ail`,
which at 8.0 declares the view-port projections `fs_ports`, `ai_ports`, `intercept_ports`
(`types.ail:1236-1261`, all 26 lines blamed to P0.4 `f7df893c`) taking **every `ExtPorts` field as a
value**. Classifier 2 matched `ExtPorts` by name, read those as its form 3 ("the function escapes"),
skipped every call through a view **silently** (a view was "another type's field"), and typed every
identifier by the first declaration of that name anywhere in the file. Result at HEAD: `make
ext_call_inventory` exit 1 with **24 unresolved** (15 ABI, 8 compose, 1 agentcli), every one of the 18
closures UNRESOLVED, the closure yield 0 of 18, `make profile_definition` / `make driver_only` /
`make driver_plus_no_ops` stopped there (P1.5r-a2 item 3, P1.6r item 2). ADR-001 D7 had named the
edit -- "the leaf inventory must recognize every view type as a receiver; `ext_call_inventory` matches
`ExtPorts` by name today" -- and no part owned it; the orchestrator assigned it here.

**What was taught** (`derive.py`, the section "8.0: the views"; each rule is one line, each has a
control and a negative fixture, each has mutgate rows in §6):

| rule | the line | control / negative |
|---|---|---|
| **Views are derived by structure.** A record type -- ABI or extension-local -- other than `ExtPorts`, every field of which is an `ExtPorts` field under the same name with the *identical* signature (effect row included), is a view; a call through it is a mediated call. Not a name list (the fail-open detector the tool's own docstring warns about); the structure also excludes core `Ports`/`ContextReader`, which share names and no signature. At HEAD: `AiPorts` (1), `FsPorts` (6), `InterceptPorts` (8) from the ABI; compose's `SnippetExecPorts` (1), `RemovePorts` (2). | `port_views()`: `if all(f in ext and ext[f] == sig …)` | `control_view_receiver` (AiCtx + FsCtx calls, 2 resolved); the `port_views` pin in `expected.json`, both directions, like `membership` |
| **A projection resolves.** A field taken as a value is resolved when, and only when, it is the same-named field of a record literal inside a function whose declared result type is a view declaring that field: it is forwarded under its own name into a record the tool reads as a receiver, so the later call site is visible. Counted as a `projection`, never as a call; any other value-escape is still form 3. | `if named_field and target in views and field in types[target]:` | `control_view_projection` (1 projection, 1 call through the local view); `form_projection_not_a_view` (renamed / non-view: 2 unresolved) |
| **Binders are scoped to their function.** A parameter's type comes from the `func` whose body holds the occurrence (nested lambdas included; `header_and_body` reads `-> T ! {row} {` the way the grammar does, so a record-literal result type is no longer mistaken for the body). | `containing()`: `[s for s in scopes if s.start <= o < s.end]` | `control_scoped_binder` (first `p`/`ctx` in the file are not ports; 2 resolved) |
| **An alias of a declared-typed path binds its type.** `let p = ctx.ports;` with `ctx` a declared parameter binds `p` to what that path resolves to *in scope* -- the same declaration-only lookup a direct `ctx.ports.x(` gets, one step earlier, no inference. An alias of an undeclared source stays form 1. | the `"alias"` `let` regex | `form_alias` **re-pinned** 1 unresolved → 1 resolved (below); `form_alias_untyped` keeps form 1 (1 unresolved) |

Also: `main()` skips only the **core's** owners of shared field names (`Ports`, `ContextReader`); the
report gains `port_views` and `port_view_projections` (JSON) and two text sections; `Occurrence` gains
`via` (`view:<Name>` on a call through a view). `scan_file`'s five-argument shape, `strip_noise`,
`record_types`, `ALL_TYPES`, the `--roots` default and the `/tmp` guard line are unchanged for their
consumers (classifier 3, `check_fixtures.py`, `journal_replay.sh`, `test_candidate.py`).

**The re-pin, named.** `form_alias.ail`: "1 unresolved" → "1 resolved". Scoping the binders exposed
that every in-tree `let p = ctx.ports` (herdr ×4, compose ×2; 31 call sites) had been counted resolved
at HEAD only through some *other* function's `p: ExtPorts` -- the file-wide accident -- so the old pin
was never what the tree ran under. 009 ADR-001 D5 names the alias as a **limit** of the grep
approximation ("not seen") and asks for "a parsed, type-aware field-call inventory"; resolving an alias
of a declared-typed path is that, and the alias of an *undeclared* source (`form_alias_untyped`) is
what form 1 still means. The fixture's header and `expected.json` carry the reasoning.

**Before / after** (`p17r_before_after.sh`: a fresh HEAD clone, lock regenerated, both tools' `--json`
as committed, then with this part's paths overlaid; `json/c2-{before,after}.json`):

| `derive.py --json` | before | after |
|---|---|---|
| exit | 1 | 0 |
| `unresolved` | **24** (types.ail 15, compose.ail 8, agentcli.ail 1) | **0** |
| `non_member_call_sites` | 87 | 91 (80 direct; via views: InterceptPorts 3, FsPorts 2, AiPorts 2, SnippetExecPorts 2, RemovePorts 2) |
| `member_call_sites` / `classifier_2_set` / `unrouted_fields` | 0 / `[env_get]` / `[]` | unchanged |
| `port_views` | absent | AiPorts 1, FsPorts 6, InterceptPorts 8, RemovePorts 2, SnippetExecPorts 1 |
| `port_view_projections` | absent | 21 (types.ail 15, compose.ail 6) |

`make ext_call_inventory_selftest`: 0 failures, 11 fixtures (6 new / re-pinned), 10 membership rows,
reachability 10/10, 3 views pinned.

## 5. Classifier 3, the twin — `tools/ext_ambient_inventory/derive.py` (orchestrator scope addition 2)

P1.6r (`6d668fdd`, its README item 2) found the same blindness in the ambient inventory's own `--json`
(all 18 UNRESOLVED on the same 15 ABI hits; where `make driver_plus_no_ops` stops). It is the same
scanner: classifier 3 loads classifier 2 by path and calls its `scan_file` in `mediated_calls`, so §4's
teaching reaches it unchanged -- verified by its own `--json` and self-test, not assumed. Its own
changes: `mediated_calls` passes the projections list and counts it (`ext_ports_projections` per
extension in the JSON and the text report -- a projection is neither a call nor an unresolved receiver,
so classifier 3's mediated-call count stays a count of calls); its owners set is core-only, as in §4
(passing the ABI's views as "other owners" is what had skipped every call through a view). P0.3's
registration-shape logic in `hook_scope.py` is untouched.

| `derive.py --json` | before | after |
|---|---|---|
| exit | 1 | 0 |
| verdicts | UNRESOLVED 18 | PORT-MEDIATED 4, AMBIENT 14, UNRESOLVED 0 |
| PORT-MEDIATED | `[]` | `compaction_structural, decision_framework, empty_stop_guard, progress_contract_guard` -- **the pinned four, measured** |
| unresolved receivers per closure | 15 (compose 23, agentcli 16) | 0 everywhere |
| projections per closure | -- | 15 (the ABI's), compose 21 |
| cache precondition | 18/18 | 18/18 |

The full per-extension table is in `BEFORE-AFTER.md`. Consequences: `closure_port_mediated`
(hook-scope) and `port_mediated` (ambient) are **unmoved and green**; the three self-tests exit 0 with
no exclusion; `make ext_call_inventory` exits 0.

**Also seen, not acted on** (outside the brief): the gate's own `fx_form_*` fixtures under
`scripts/dst/fixtures/adr001_boundary/gate/` are still pinned `fail` as "IN-TREE FORM (…)"; P0.3's
`expected.json` said P1.2 would rewrite each to the migrated form and flip its pin batch by batch, and
no batch did. They are green as pinned; the record is merely stale.

## 6. How every check was run — `p17r_selftest.sh`, `p17r_headws.sh`, `p17r_before_after.sh`

- **Against committed HEAD, never the working tree** (plan §0 item 13): `p17r_headws.sh` makes a
  `git clone --shared` of this checkout (HEAD checked out, nothing of the working tree) under
  `/workspaces`, copies only P1.7r's paths over it, and runs the three self-tests and the fixture
  compiles there. `AFTER-head-*.log` / `AFTER-head-*.raw.log`; `CHECKS.log` is the compile column.
- **The `ailang.lock` trap**: the tracked lock pins path dependencies to the primary checkout. Anywhere
  but the primary, `p17r_selftest.sh` regenerates the lock once (`ailang lock`, offline — every
  dependency is a path dependency; verified 0 primary paths remain) so every compile resolves the
  workspace's own packages.
- **Scoring**: every mode is GREEN iff its self-test exits 0 -- no exclusions. (Between §2 and §4 the
  harness excluded the one named closure-verdict line; the exclusion went with the residual.) `c2` is
  classifier 2 over the tree. No `cmd | grep -q` under pipefail.
- `AFTER-make.log` is the four `make` targets in the primary, as `make` runs them, after everything.

## 7. mutgate — `p17r_mutgate_spec.tsv`, `p17r_mutgate.sh`, `mutgate-result.tsv`, `MUTGATE-run.log`

Fresh `git clone --shared` of this checkout with P1.7r's paths overlaid (`--overlay`; the intake form is
`--clone-from <repo>`), under `/workspaces`; every row's test runs in the throwaway through
`p17r_selftest.sh` (lock regenerated once). 40 rows:

- **15 migrated fixtures, each reverted to the 7.4 head** by `sed` → its head/shape pins → red (the
  brief's "revert it → its self-test → red");
- **7 walk rows** on the migrated controls: the env read removed from the hook twin, the env read moved
  INTO the registration twin's hook, the interpolated `now()` removed, the named handle's `writeFile`
  removed, `show` removed, the wide judge's env read removed, the port-call Compactor bound to a name
  that resolves nowhere → the pinned verdict flips → red;
- **2 kept fixtures, migrated anyway** (the 7.4 list wrapped in the 8.0 record) → the 7.4 head/shape
  pins they carry → red (the brief's "migrate it anyway → the verdict it pins → red");
- **2 yield rows**: one package's payload re-inlined in the throwaway (`test_dummy`'s PromptShaper) →
  17 of 18, 1 binding → the re-pinned `registration_shape_results`/`shape_binding_rejections` → red; and
  the pin file's `shape_binding_rejections` set back to 35 → red;
- **13 classifier-2 rows** (§4): each of the four rules broken by one `sed` -- a view dropped from the
  receiver set (the structural rule made to need >1 field, so `AiPorts` is no longer a view),
  projections back to form 3, binders file-wide again, the alias rule's regex made unmatchable -- each
  against the tree (`c2`: 0 unresolved → red) and the self-test (`call`), the view drop also against
  the ambient yield pin and the hook-scope shipped-closure pin (`ambient`, `hook`: the pins are live
  again); plus a pin un-named (`AiPorts` → `AiPortsX`) and a control's view type removed → `call` red;
- **1 classifier-3 row** (§5): `mediated_calls` reporting 0 projections → its `--json`
  `ext_ports_projections` (≥ 15 in every closure) → red.

Result: `mutgate-result.tsv`, §7a.

### 7a. Result

`start 2026-09-21T20:38:31Z HEAD 6d668fdd rows 40`; `mutgate: 40/40 discriminate, 0 failed` — every row baseline GREEN → mutated RED → restored GREEN, bytes `same`.

| group | rows | PASS |
|---|--:|--:|
| 15 migrated fixtures reverted to 7.4 | 15 | 15 |
| 7 walk probes moved or removed | 7 | 7 |
| 2 kept fixtures migrated anyway | 2 | 2 |
| 2 yield rows (a package re-inlined; the pin file) | 2 | 2 |
| 13 classifier-2 rows | 13 | 13 |
| 1 classifier-3 row | 1 | 1 |
| **total** | **40** | **40** |


## 8. Could not run

`make dst` — forbidden by the brief. Nothing else.
