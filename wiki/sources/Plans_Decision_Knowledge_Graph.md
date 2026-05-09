# Plans Decision Knowledge Graph

Extract all architectural and implementation decisions from `.agent/plans/*.md` into the Omnigraph knowledge graph, producing a machine-queryable dependency map of every design choice in the Motoko project.

**72 source files. ~200-700 structured decisions. One queryable graph.**

---

## Context

The project has accumulated 72 plan documents covering architecture, extensions, TUI, runtime, config, testing, ML integration, and error recovery. These plans contain the complete decision history of the project — why each design choice was made, what was rejected, what depends on what — but the knowledge is trapped in flat markdown files.

The Omnigraph infrastructure already exists: Decision/Component node types, Governs/DependsOn edges, mutation/read queries, branch workflow. The seed data (`omnigraph/seed/data.jsonl`) is from a different domain (energy trading). The `.agent/plans/` decision graph will be Motoko-specific, describing the actual system built in this repository.

Plans contain heterogeneous structures: some have explicit "Key decisions" sections (`AILANG_Agent.md`), others are phased implementation specs with embedded tradeoff analyses (`Core_Extension_Disentangling_Plan.md`, `Hybrid_Tool_Execution.md`), and some are small focused decisions (`ESC_Interrupt.md`, `Tool_Parse_Robustness.md`). Extraction must handle all these shapes.

There is no Decision→Decision edge in the current schema. Plans routinely reference dependency relationships — e.g., "Hybrid Tool Execution" depends on "Yolo Mode" (without yolo, there is no brain to own tool semantics); "Extension Disentangling" defers descriptor-based registration; "Stream-Aware Markdown Rendering" depends on the TUI architecture decision. These relationships are the graph's primary value and are currently invisible.

---

## Schema Changes

### New edge types (RelatesTo → five named edges)

Existing edges `DependsOn` and `Governs` carry no properties — just `from` and `to`. Edge properties are unsupported in the current schema syntax. Instead of one `RelatesTo` edge with a `relation` property, use five purpose-named edges:

```
edge Supersedes: Decision -> Decision
edge DependsOnDecision: Decision -> Decision
edge Refines: Decision -> Decision
edge Implements: Decision -> Decision
edge ConflictsWith: Decision -> Decision
```

Each maps one-to-one to the `relation` values from the original plan, but as distinct schema-level edge types. This is consistent with how `DependsOn` (Component→Component) and `Governs` (Decision→Component) are already modeled as separate edge types rather than a generic `RelatesTo` with a type discriminator.

**Mutation queries needed (in `omnigraph/mutations/decisions.gq`):**

```
query insert_supersedes($from_slug: String, $to_slug: String)
query insert_depends_on_decision($from_slug: String, $to_slug: String)
query insert_refines($from_slug: String, $to_slug: String)
query insert_implements($from_slug: String, $to_slug: String)
query insert_conflicts_with($from_slug: String, $to_slug: String)
```

Each follows the pattern of existing `insert_dependency`/`insert_governs`.

**Read queries needed (in `omnigraph/queries/decisions.gq`):**

```
query decisions_superseded_by($slug: String)   -- what did this decision supersede?
query decisions_depending_on($slug: String)     -- which decisions depend on this one?
query decisions_depended_on_by($slug: String)   -- which decisions does this one depend on?
```

Each follows the pattern of existing `decisions_governing`.

### Decision node convention

Every extracted Decision uses:
- `slug`: `<plan-filename-stem>:<short-decision-key>` — e.g. `ailang-agent:yolo-mode`, `extension-disentangling:defer-descriptor-registry`
- `title`: human-readable from plan context
- `rationale`: quoted or paraphrased from the plan's justification text
- `status`: `accepted` for implemented/decided, `proposed` for optional phases or plans with no observable implementation, `superseded` where a later plan overrides
- `date`: extracted from plan content, Git log date of the plan file's first commit, or directory listing heuristic as last resort

`status: accepted` vs `proposed` distinction: If the plan describes a design that was committed but never implemented (no corresponding code in the repo), use `proposed`, not `accepted`. A follow-up cross-reference pass (Phase 8) can promote eligible decisions.

### Component node extraction

Many plans introduce or modify system components:
- `src/core/rpc.ail` — core runtime loop
- `src/core/ext/registry.ail` — extension registry
- `src/core/parse.ail` — tool call parsing
- `src/tui/src/ui.ts` — TUI rendering
- `ailang/internal/effects/ai.go` — AI effect operators
- etc.

Components are extracted from sections that enumerate file changes and architectural diagrams. Layer classification follows the Omnigraph convention. For file-path components (source files), default to `infrastructure` layer unless the component has a clear domain, API, or frontend role.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Extraction pipeline                                           │
│                                                                │
│  Phase 0: Schema + queries + seed cleanup                      │
│    - Edit schema.pg locally (5 edge types)                     │
│    - Add 5 mutation queries (decisions.gq)                     │
│    - Add 3 read queries (decisions.gq)                         │
│    - Archive existing seed data (different domain)             │
│    - Verify with omnigraph validate                            │
│                                                                │
│  Phases 1-7: Batch extraction to JSONL (no Omnigraph yet)      │
│    - For each plan: read → identify decisions/components/edges │
│    - Append JSONL records to batch file                        │
│    - Write per-plan audit file to omnigraph/extractions/       │
│                                                                │
│  Phase 8: Cross-plan resolution + source verification          │
│    - Trace edges between decisions in different plans          │
│    - Deduplicate components referenced across multiple plans   │
│    - Cross-reference component slugs against actual file paths │
│    - Check for orphan nodes, fix statuses                     │
│                                                                │
│  Phase 9: Branch → insert → verify → merge → seed              │
│    - Create feature branch                                     │
│    - Insert all nodes/edges via OmnigraphMutate                │
│    - Verify with new read queries                              │
│    - Merge to main                                             │
│    - Concatenate batch JSONLs into seed/data.jsonl             │
└────────────────────────────────────────────────────────────────┘
```

Schema changes are local file edits to `omnigraph/schema.pg` — schema is not mutated through Omnigraph itself, only graph data is.

---

## Extraction Format

Each plan produces a JSONL segment appended to a per-batch file and a standalone audit file. The format matches the existing `omnigraph/seed/data.jsonl` structure:

```jsonl
{"type":"Decision","data":{"slug":"<slug>","title":"<title>","rationale":"<text>","status":"accepted|proposed|superseded|deprecated","date":"<YYYY-MM>"}}
{"type":"Component","data":{"slug":"<slug>","name":"<name>","description":"<text>","layer":"domain|infrastructure|api|frontend"}}
{"edge":"Governs","from":"<decision-slug>","to":"<component-slug>"}
{"edge":"DependsOn","from":"<component-slug>","to":"<component-slug>"}
{"edge":"Supersedes","from":"<decision-slug>","to":"<decision-slug>"}
{"edge":"DependsOnDecision","from":"<decision-slug>","to":"<decision-slug>"}
{"edge":"Refines","from":"<decision-slug>","to":"<decision-slug>"}
{"edge":"Implements","from":"<decision-slug>","to":"<decision-slug>"}
{"edge":"ConflictsWith","from":"<decision-slug>","to":"<decision-slug>"}
```

Per-plan audit files are written to `omnigraph/extractions/<plan-slug>.jsonl`. Batch aggregate files are written to `omnigraph/extractions/batch-<N>.jsonl`. In Phase 9, all batch files are inserted into Omnigraph, then concatenated into `omnigraph/seed/data.jsonl`.

---

## Phase Plan

### Phase 0 — Schema upgrade + queries + seed cleanup

**Effort:** 1 agent turn

**Actions:**
1. Add five edge types to `omnigraph/schema.pg`: `Supersedes`, `DependsOnDecision`, `Refines`, `Implements`, `ConflictsWith`
2. Add five mutation queries to `omnigraph/mutations/decisions.gq`: `insert_supersedes`, `insert_depends_on_decision`, `insert_refines`, `insert_implements`, `insert_conflicts_with`
3. Add three read queries to `omnigraph/queries/decisions.gq`: `decisions_superseded_by`, `decisions_depending_on`, `decisions_depended_on_by`
4. Archive existing seed data: move `omnigraph/seed/data.jsonl` to `omnigraph/seed/legacy/domain-trading.jsonl`
5. Create empty seed file for Motoko-specific data
6. Verify: `omnigraph validate` passes, new queries return empty results

**Acceptance:**
- Schema validates with 5 new edge types
- All 5 new mutation queries resolve without error
- 3 new read queries return empty results on empty graph
- Legacy seed data preserved in `legacy/` directory

---

### Phase 1 — Core architecture decisions

**Effort:** 4 agent turns (1 per plan)

**Files:** `.agent/plans/AILANG_Agent.md`, `Motoko_AILANG_Rebase_Forward.md`, `Motoko_AILANG_Rebase_Forward_Handoff.md`, `DST_v1_Motoko_Core.md`

These four plans establish the project's foundational architecture:
- Yolo mode (always execute, no confirm/reject)
- Option D model selection via SharedMem
- Three-process architecture (TUI ↔ AILANG brain ↔ env server)
- JSONL protocol
- Rebase forward decisions (plan + handoff document)
- Core runtime structure
- Decision to fork the AILANG runtime as vendored `motoko` branch

**Expected output:** ~18 Decision nodes, ~8 Component nodes, ~25 edges

---

### Phase 2 — TUI and rendering decisions

**Effort:** 4 agent turns (3-4 plans per turn, denser plans get their own)

**Files:** `TUI_Thinking_Trace_Coloured_Rendering.md`, `TUI_Streaming_JSON_Rendering.md`, `TUI_Stream_Aware_Markdown_Rendering.md`, `TUI_Streamed_Tool_Plan_UX.md`, `TUI_Context_Window_Counter.md`, `TUI_Session_Logging.md`, `TUI_Tool_Call_Rendering_Implementation_Plan.md`, `TUI_Code_Block_Rendering.md`, `TUI_Dynamic_Runtime_Banner.md`, `TUI_Wait_State_Clarity.md`, `TUI_OM_Command_Patterns.md`

These cover the complete TUI rendering pipeline: markdown streaming, JSON rendering, tool call display, context window tracking, session logging, dynamic banners, wait states.

**Expected output:** ~30 Decision nodes, ~10 Component nodes, ~40 edges

---

### Phase 3 — Extension system decisions

**Effort:** 4 agent turns

**Files:** `Core_Extension_Disentangling_Plan.md`, `Core_Extension_System_for_Semi_Formal.md`, `Compose_Extension_Extraction_Plan.md`, `Packageize_Extension_System.md`, `Generic_MCP_Extension.md`, `Context_Mode_Extension.md`, `Exa_Websearch_Extension.md`, `Omnigraph_Extension.md`, `Compose_As_Extension.md`, `Compose_Semi_Formal_Evidence_Guard.md`, `Compose_Author_Premise_Tools.md`

These capture the extension architecture evolution: generic envelope contracts, Omnigraph disentangling, Compose extraction, context-mode/Exa search/Omnigraph as extensions, MCP integration. High decision density — many contain explicit "Decision for this effort" sections.

**Expected output:** ~50 Decision nodes, ~15 Component nodes, ~60 edges

---

### Phase 4 — Tool execution decisions

**Effort:** 4 agent turns

**Files:** `Structured_Tool_Call_Authoring.md`, `Native_Tool_Calling_For_Motoko.md`, `Hybrid_Tool_Execution.md`, `Brain_Owned_Tool_Execution.md`, `Self_Modifying_Brain.md`, `Self_Modifying_Brain_Safe_Cutover.md`, `Tool_Dispatch_to_TUI.md`, `Tool_Parse_Robustness.md`, `EditFile_Tool_Implementation_Plan.md`, `Brain_Test_Suite.md`, `Brain_Formal_Verification.md`, `OhMyPi_Tool_Integration.md`

The tool execution evolution from brain-owned to hybrid to self-modifying. Contains the most explicit cross-plan dependencies of any batch — later plans explicitly reference and build on earlier ones. `OhMyPi_Tool_Integration.md` belongs here (tool integration) rather than the config/runtime batch.

**Expected output:** ~45 Decision nodes, ~14 Component nodes, ~55 edges

---

### Phase 5 — Config and runtime decisions

**Effort:** 4 agent turns

**Files:** `Motoko_Config_System.md`, `Headless_JSON_Only_Config.md`, `Multi_Profile_Config.md`, `Motoko_Core_Config_Supervisor.md`, `Error_Recovery_Idle_Mode.md`, `Error_Recovery_Runtime_Fix.md`, `Error_Recovery_Runtime_Merged_Best_Plan.md`, `AI_Runtime_Result_Error_Recovery_Plan.md`, `Runtime_Continuation_Intent_Guard.md`, `Runtime_Filter_Thinking_From_Context.md`, `OpenAI_LLM_Streaming_For_Motoko.md`

Config system simplification (env vars → JSON profiles + CLI args), error recovery (retry/backoff for AI provider failures), streaming, intent guard, thinking trace filtering. The error recovery plans are a case of explicit supersession — earlier plans got replaced by the merged best plan.

**Expected output:** ~35 Decision nodes, ~10 Component nodes, ~45 edges

---

### Phase 6 — ML, benchmarks, and niche integrations

**Effort:** 5 agent turns (more files, lower density, but wider variety)

**Files:** `MLflow_Experiment_Tracking_Plan.md`, `Motoko_MLflow_Observability_Plan.md`, `Motoko_MLflow_Observability_Kickoff.md`, `MLflow_Experiment_Tracking_Kickoff.md`, `RunPod_Additive_Integration_Plan.md`, `RunPod_Additive_Integration_Kickoff.md`, `GRPO_Pilot_AILANG.md`, `Motoko_Benchmark_Harness.md`, `Gemma4_Thinking_Mode_Enablement_Plan.md`, `Gemma4_FSharp_Benchmark.md`, `Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md`, `OpenRouter_Integration.md`, `Local_OpenAI_Endpoint_Integration.md`, `AILANG_Chess_Engine.md`

MLflow observability, RunPod integration, GRPO pilot, benchmark harness, Gemma thinking mode, TTS, OpenRouter, local endpoints, chess engine. Lower decision density but wider domain variety.

**Expected output:** ~30 Decision nodes, ~8 Component nodes, ~35 edges

---

### Phase 7 — Rebrand, cleanup, and remaining

**Effort:** 3 agent turns

**Files:** `Core_Rebrand_and_Prompt_Rewrite.md`, `Core_Rebrand_Phase0_Inventory.md`, `Update_SYSTEM_and_AGENTS.md`, `Thinking_Traces.md`, `ESC_Interrupt.md`, `Abort_History_And_Omnigraph_Delete.md`, `AILANG_Composition_Language.md`, `AILANG_Composition_Subagent.md`, `Semi_Formal_Reasoning_Integration.md`

Rebrand, prompt rewrite, thinking traces, ESC interrupt, abort history management, AILANG composition language design. `Compose_Extension_Extraction_Plan.md` is not included here — it was already extracted in Phase 3.

**Expected output:** ~20 Decision nodes, ~5 Component nodes, ~25 edges

---

### Phase 8 — Cross-plan resolution + source verification

**Effort:** 2 agent turns

**Actions:**
1. Scan all extracted decisions for cross-plan references
   - Plans that explicitly name other plans (e.g., "The Safe Cutover plan requires…")
   - Decisions that are prerequisites for later decisions
   - Designs that supersede earlier proposals
2. Add edge types where dependencies are identified
3. Deduplicate Component nodes referenced across multiple plans
4. Cross-reference every Component `slug` against actual file paths in the source tree:
   - Match found at expected path → confidence confirmed
   - Match not found → flag for review; could be plan that was never implemented
5. Verify every Decision slug is unique
6. Check for orphan nodes with no edges — add at minimum a `Governs` edge to an affected component
7. Review `status: accepted` decisions: if the plan describes code that was never written, downgrade to `proposed`

**Acceptance:**
- Complete graph with no isolated nodes
- Every Decision has ≥1 edge (Governs or one of the five Decision→Decision edges)
- Every Component has ≥1 edge
- All slugs are unique
- Every Component slug resolves to a real file path in the repo, or is flagged with a rationale note

---

### Phase 9 — Omnigraph insertion + seed data

**Effort:** 1 agent turn + manual verification

**Actions:**
1. Create feature branch: `feature/plans-decision-graph`
2. Insert all Decision nodes via `OmnigraphMutate` using `insert_decision`
3. Insert all Component nodes via `OmnigraphMutate` using `insert_component`
4. Insert all edges (Governs, DependsOn, Supersedes, DependsOnDecision, Refines, Implements, ConflictsWith) via their respective mutation queries
5. Add cross-plan edges from Phase 8
6. Run read queries to verify every phase's data is present
7. Run `omnigraph validate` against full graph
8. Merge to main
9. Concatenate all `omnigraph/extractions/batch-*.jsonl` files into `omnigraph/seed/data.jsonl`
10. Commit seed data

**Note:** Schema changes were already applied to `omnigraph/schema.pg` in Phase 0. Phase 9 operates only on graph data, not schema definitions. Seed data is assembled by concatenating the batch JSONL files (already in the correct format), not by exporting from Omnigraph.

**Acceptance:**
- `omnigraph read list_decisions` returns all extracted decisions
- `omnigraph read list_components` returns all extracted components
- New read queries work: `decisions_superseded_by`, `decisions_depending_on`, `decisions_depended_on_by`
- Cross-plan queries work (e.g., "which decisions does Hybrid Tool Execution depend on?")
- Seed data assembled from extraction files, matching what was inserted

---

## Edge Cases

| Case | Handling |
|---|---|
| Plan with no explicit decisions (pure research/exploration) | Extract as single `proposed` Decision with rationale "Exploratory analysis, no committed direction" |
| Plan that is superseded by a later plan | Extract both; add `Supersedes` edge from later to earlier. Set earlier status to `superseded` |
| Unreadable or corrupted plan file (broken markdown, encoding issue) | Log the file path and skip; create a task note to investigate. Do not block the batch |
| Multiple plans making the same decision | Deduplicate — one Decision node, multiple `Refines`/`DependsOnDecision` edges from consuming plans |
| Component mentioned in 10+ plans | Single Component node, multiple `Governs` edges |
| Plan with kickoff files (e.g., RunPod has plan + kickoff) | Treat kickoff as separate Decision (implementation start), add `Implements` edge from kickoff to plan decision |
| Ambiguous date | Use Git log date of the plan file's first commit; if absent, use `YYYY-MM` from directory listing heuristic |
| Plan referencing non-existent component | Extract as Component with `layer: domain` and note in rationale; Phase 8 cross-reference will flag it |
| Plan that was written but never implemented | Extract as `proposed`, not `accepted`. Phase 8 may upgrade after source verification |
| Circular dependencies between decisions | Extract as-is; the graph model allows cycles (prefer query-time cycle detection over schema enforcement) |
| Failed Omnigraph mutation on a batch | Insertion is idempotent per slug — retry the batch. If non-idempotent, use `delete_decision`/`delete_component` on the branch first |

---

## Risks and Mitigations

1. **Risk: Extraction inconsistency across 72 files (different agent turns use different granularity)**
   - Mitigation: Each phase starts with the same extraction template. Phase 8 cross-plan scan catches granularity anomalies. Use consistent slug naming convention.

2. **Risk: Schema drift during multi-phase extraction (edge types added mid-process)**
   - Mitigation: All schema changes happen in Phase 0. No schema modifications after Phase 0 completes.

3. **Risk: Omnigraph branch conflicts across batches**
   - Mitigation: No branch conflicts because Phases 1-7 write JSONL files only, never insert into Omnigraph. Single batch insertion in Phase 9.

4. **Risk: False dependencies extracted from vague cross-references**
   - Mitigation: Only add Decision→Decision edges when the dependency is explicit (plan text says "this depends on X" or "requires Y from plan Z"). Inferred dependencies get a note in the slug or rationale.

5. **Risk: Plan files that are actually executive summaries or kickoff notes with minimal technical content**
   - Mitigation: Extract a single low-granularity Decision per such file rather than forcing split decisions.

6. **Risk: Edge properties not supported by current schema syntax (already mitigated by design — five named edge types instead of one parameterized edge)**
   - No further action needed. The five-edge approach is provably compatible with the existing schema format (same pattern as `DependsOn`/`Governs`).

---

## Effort Summary

| Phase | Agent turns | Description |
|-------|-------------|-------------|
| 0 | 1 | Schema + queries + cleanup |
| 1 | 4 | Core architecture (4 plans) |
| 2 | 4 | TUI rendering (11 plans) |
| 3 | 4 | Extension system (11 plans) |
| 4 | 4 | Tool execution (12 plans) |
| 5 | 4 | Config + runtime (11 plans) |
| 6 | 5 | ML, benchmarks, integrations (14 plans) |
| 7 | 3 | Rebrand, cleanup, remaining (9 plans) |
| 8 | 2 | Cross-plan + source verification |
| 9 | 1 | Omnigraph insertion + seed data |
| **Total** | **32** | ≈ 32 agent responses to complete |

---

## Acceptance Criteria

- Every `.agent/plans/*.md` plan is represented by ≥1 Decision node in the graph
- Every Decision has status, rationale, date, and ≥1 edge
- Every Component slug resolves to a real file path in the source tree, or is explicitly flagged
- Cross-plan queries work: "show all decisions governing rpc.ail", "find decisions superseded by later plans", "list all decisions in the extension domain with their dependency graph"
- Omnigraph schema validates with 5 new edge types and all new queries
- Seed data file assembled from extraction JSONL files, not hand-edited
- All 72 plan files are accounted for (no silent skips)
- Unreadable/corrupted files are logged, not silently dropped
