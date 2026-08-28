# Extension ABI evolution diagrams

Diagrams for project 017, drawn from `../ADR-001-extension-abi-evolution.md` and its research
document `../RESEARCH-extension-abi-evolution.md`. Each is a Mermaid `.mmd` source with its
rendered `.svg` alongside, following the convention in
`../../004_phase_core_refactor/mmd/README.md` as applied by `../../007_dst_consolidation/mmd/`.

The four form a **set with one overview and three detail views**, split by concern rather than by
document. `ext-abi-evolution` is the map you open first: the problem, the options, the decision,
and the four §5 answers as they attach to it. `ext-abi-5-hooks` expands the *present* — the 5.0
record the decision starts from, slot by slot. `ext-abi-6-capabilities` expands the *target* — the
capability-list shape 6.0 moves to and the registration boundary that polices it.
`ext-abi-enforcement-plane` expands the *guarantee* — what the compiler was measured to enforce,
what it was measured not to, and which tools therefore carry the enforcement and must be re-taught
before 6.0. The detail views expand the overview without repeating it, so a claim lives in exactly
one file.

Colour is **role** in the overview, 5.0 and 6.0 views, and **status** in the enforcement-plane view
(green = the checker rejects / the tool already works · red-dashed = the measured hole · purple =
tooling that must be re-taught). Each file's `%%` header states its own legend.

| File | What it shows |
|------|---------------|
| `ext-abi-evolution` | **Overview of the decision.** Research §2's problem (a record field breaks every constructor; a sum variant breaks only the in-tree matcher — so slot additions are O(consumers)) → the four §3 options → ADR §1's decision: `default_hooks(id)` now as a minor, capability registration bundled with the `proc_exec → tool_handle` rename at 6.0, the untyped bus rejected, the AILANG optional-fields request filed in parallel. The steeled 6.0 precondition (Q3: rows are not compiler-enforced in constructor-argument position, so the derivation tooling is the entire enforcement plane) hangs off the 6.0 branch; Q1/Q2/Q4 attach as side facts; ADR §5's unknowns close the view. |
| `ext-abi-5-hooks` | **Detail view — the current ABI (5.0).** `ExtensionHooks` (`types.ail:702`) with `id`/`provided_tools` and the eight slots, each with its closed effect row (`types.ail:705–957`; four rowless, four rowed, `on_tool_handle` widest), each wired to its host dispatcher in `src/core/ext/runtime.ail` with the merge rule and line: concatenation, registry-order patch folds, the validated `on_pre_step` chain, first-match / first-intercept, and the two priority merges (`Deny > Pending > Allow > NoOpinion`, `ContinueWithFeedback > Accept > NoDecision`). The holder-stamp re-seat on the four world-threading slots, and `default_hooks` (`types.ail:964`) as the per-dispatcher identity with the `empty_stop_guard` record-update migration. |
| `ext-abi-6-capabilities` | **Detail view — the 6.0 shape.** `register_with_config` returning `[Capability]`, the ABI-owned nominal sum with one variant per hook kind (`provided_tools + on_tool_handle` collapsed into `ToolProvider`), bundled with the priced `ExtPorts.proc_exec → tool_handle` rename (`types.ail:342–349`). ADR Q2's multiplicity policy as a decision at the single host-owned registry boundary: N>1 admitted for the composable kinds (list order = sub-order / precedence / first-match order), `ToolProvider` admitted only with disjoint tool names, `ToolPolicy` and `SolverJudge` rejected at registration because they are votes. What transfers unchanged (registry-order folds, world token, holder stamp), what does not (the payload row — pointer to the enforcement view), and the §5 open items (`ExtRegistry` shape, N>1 fold fail-open). **The `Capability` type does not exist at HEAD** — it is the research §3.3 sketch as type-checked by delegate `mot-dlg-1787599903186`. |
| `ext-abi-enforcement-plane` | **Detail view — what enforces what.** ADR Q3's seven-file mutation matrix as a status map: the named-function positive control and the enclosing-row case are rejected by the checker; the constructor-argument lambda, the record-field lambda (WI-B4 reproduced) and the two declared-named-payload cases check green, with runtime proof that the undeclared `Env` performs. The consequence — classifier 3 and `declared_vs_performed` are the enforcement plane and must walk into constructor arguments — feeds Q1's coverage-unit change (slot → `(extension, capability-atom)`; `slot_accounting` at `dst_profile_coverage.ail:246–256` is the slot-closed check that breaks; `[]` becomes a legal vacuous case), the corrected premise that only `hook_scope.py` reads the record, and Q4: no witness needed, flag rejected, but `hook_scope.locate()` cannot parse the `{ default_hooks(...) \| ... }` head (`hook_scope.py:279`), already visible as `empty_stop_guard` `HOOK-UNRESOLVED` at binding scope. Ends with ADR §4's reconciliation of the two delegates. |

These diagrams are **dated evidence**: their `%%` headers carry the grounding commit and the ADR
date. They were grounded on 2026-08-26 at `366193c` (2026-08-24) **plus the uncommitted working
tree** — `default_hooks` (`types.ail:964–993`) and the `empty_stop_guard` record-update migration
are unstaged hunks at that commit, not yet in history. Re-render them when the decisions change or
when 6.0 lands and the `Capability` sum acquires a real `types.ail` line.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/017_extension_handling/mmd/<name>.mmd \
  .agent/projects/017_extension_handling/mmd/<name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
