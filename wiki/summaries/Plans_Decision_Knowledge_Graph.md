---
doc_type: short
full_text: sources/Plans_Decision_Knowledge_Graph.md
---

This plan defines a systematic extraction of all architectural and implementation decisions from the `.agent/plans/` directory into the [[Omnigraph]] knowledge graph, creating a machine-queryable dependency map of every design choice in the Motoko project.

## Key Objectives
- Ingest **72 plan documents** covering architecture, TUI, extensions, tools, config, ML, and recovery.
- Produce **~200–700 structured Decision nodes** with explicit inter-decision edges (supersedes, depends on, refines, implements, conflicts).
- Extend the Omnigraph schema and query layer to support five new edge types and corresponding read/mutation operations.
- Ensure every Component node resolves to an actual source file or is flagged; no orphan nodes.

## Schema & Edge Enhancements
Add five purpose-named edges to the existing `schema.pg`:
- `Supersedes`
- `DependsOnDecision`
- `Refines`
- `Implements`
- `ConflictsWith`

New mutation queries (`insert_supersedes`, `insert_depends_on_decision`, etc.) and read queries (`decisions_superseded_by`, `decisions_depending_on`, `decisions_depended_on_by`) are created in `omnigraph/mutations/decisions.gq` and `omnigraph/queries/decisions.gq`. All schema changes occur in Phase 0 and are validated before extraction begins. [[Omnigraph schema]] remains unchanged during later phases.

## Pipeline Architecture
1. **Phase 0** – Schema upgrade, seed cleanup (archive legacy energy‑trading data).
2. **Phases 1–7** – Batch extraction from plan files into JSONL segments (`omnigraph/extractions/batch-*.jsonl`) with per‑plan audit files. Extraction uses a consistent template and covers core architecture, TUI rendering, extension system, tool execution, config/runtime, ML/benchmarks, and remaining cleanup plans.
3. **Phase 8** – Cross‑plan resolution: trace dependencies between decisions in different plans, deduplicate Components, verify file‑path correctness, and adjust statuses (e.g., downgrade unimplemented `accepted` to `proposed`).
4. **Phase 9** – Branch‑based insertion into Omnigraph, verification via new queries, merge to main, and assembly of final seed file from the batch JSONLs.

## Decision & Component Conventions
- Decision slug: `<plan-stem>:<short-key>` (e.g., `ailang-agent:yolo-mode`).
- Status: `accepted` (implemented/decided), `proposed` (unimplemented), `superseded` (by later plan).
- Component slugs align with file paths; layer defaults to `infrastructure` unless a more specific role (domain, api, frontend) is clear.

## Phase Effort & Deliverables
- 32 agent turns total: Phase 0 (1 turn), Phases 1‑7 (27 turns extraction), Phase 8 (2 turns), Phase 9 (1 turn).
- Acceptance criteria: every plan represented by ≥1 Decision, all decisions have rationale and ≥1 edge, Component slugs resolve to real files, cross‑plan queries work, seed data assembled from extraction JSONLs, and schema validates.

See also: [[Decision extraction pipeline]], [[Component extraction]], [[Cross-plan resolution]], [[Seed data aggregation]], [[Omnigraph mutation queries]].