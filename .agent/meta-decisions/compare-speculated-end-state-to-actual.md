# Meta-decision: speculated end-state diagrams are hypotheses — compare them to grounded actuals

Date: 2026-07-08
Status: Standing discipline
Scope: implementation plans, architecture diagrams, migration maps, and any source-dense artifact
that predicts a future module graph, gate surface, or ownership boundary.

## The principle

A planned end-state diagram is valuable because it makes intent concrete before code exists:
expected modules, import arrows, gate boundaries, and forbidden edges are visible enough to review.
But it is still a **hypothesis**, not documentation truth. After implementation, create or refresh
an actual-state artifact from source and compare it against the planned one.

The comparison is an architecture snapshot test:

- the planned snapshot says what the design meant to land;
- the actual snapshot says what the code really landed;
- the diff is where plan blind spots, implementation drift, or useful extra support edges show up.

Treat differences as findings to classify, not automatic failures.

## Why this exists

During the Plan 1 conformance-kit implementation, the plan-authoring session had already produced
`conformance-kit-end-state.mmd`: a speculative "as-built" diagram of the expected final module graph.
After implementation, a refreshed all-profile code graph and source index grounded
`conformance-kit-implemented.mmd`.

The comparison confirmed the main architecture:

- `runtime.ail` imports the extracted law from `motoko_ext_conformance/invariants`;
- the conformance package remains ABI-only and does not import `src/core`;
- the root self-test and registry probe live outside the package;
- the accept fixtures remain the frozen compaction packages;
- everything bottoms out at `motoko-ext-abi @ 3.0`.

It also surfaced real details the speculative diagram did not carry:

- `scripts/phase_c_l1_scenarios.ail` is a real consumer of the moved law;
- `scripts/conformance_registry_probe.ail` depends on `src/core/config` via `load_runtime_config`;
- the registry probe runs the full registry, including non-compactors that pass vacuously;
- the actual gate is one concrete `make conformance` target, not only abstract self-test/probe boxes;
- the code-graph import table did not resolve `pkg/sunholo/...` package namespace imports back to
  filesystem slugs for the underscore package, so those edges had to be labeled as source-index
  confirmed rather than silently presented as import-table edges.

None of those contradicted the plan; they made the implemented architecture more precise.

## The rule

1. **Name planned artifacts as planned.** Use words like `plan`, `expected`, or `speculated` in
   filenames or headers when an artifact is authored before implementation. Do not let a future-state
   picture masquerade as a measured state.
2. **Make an actual artifact after landing.** For architecture diagrams, refresh the relevant graph
   first. In this repo, use `tools/code-graph/extract.sh --profile=all` when packages/scripts are in
   scope, then query `modules`, `imports`, `source_lines`, and `source_chunks` as needed.
3. **Put grounding metadata in the actual artifact.** Record the extraction command, timestamp,
   profile, staleness flags, and any known limitations. If an edge is source-index-confirmed rather
   than graph-import-confirmed, say so.
4. **Compare boundaries before aesthetics.** The important questions are: Did the intended modules
   exist? Did import arrows point the right direction? Did forbidden dependencies stay absent? Did
   gates land where expected? Did support modules appear that the plan should now acknowledge?
5. **Classify diffs.** A difference may be:
   - an implementation bug;
   - a stale or under-specified plan;
   - a harmless support edge omitted for readability;
   - a tool limitation that needs explicit labeling.
   Do not quietly reconcile these by editing the diagram until the classification is clear.
6. **Preserve both views when useful.** Keeping the planned and actual diagrams side by side is often
   more useful than overwriting the planned one. The planned view explains intent; the actual view
   explains the landed system.

## Anti-patterns

- Treating a speculative end-state diagram as proof that code now has that shape.
- Updating the planned diagram after implementation until it matches reality, erasing the useful diff.
- Drawing actual-state edges from memory when a cheap graph/source query can verify them.
- Presenting approximate call/effect graph rows as compiler facts; follow `tools/code-graph/AGENTS.md`
  and label approximate or incomplete data.

## Relationship to re-grounding

This is the diagram/architecture-map form of `re-ground-inherited-anchors-before-building.md`.
That discipline says inherited source claims decay and must be re-observed. This one adds:
**future-state architecture claims must be checked against the actual landed graph.** The planned
artifact is allowed to be wrong or incomplete; the value comes from finding out exactly how.
