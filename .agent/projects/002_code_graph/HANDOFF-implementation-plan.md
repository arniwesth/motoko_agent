# Handoff: Write the implementation plan for `ailang-graph`

Date: 2026-06-28
For: the agent producing the implementation plan
From: ADR-002 design work (Opus 4.8)

## Your task

Turn **ADR-002** into a concrete, step-by-step **implementation plan** for `ailang-graph` — a structural + effect graph of Motoko's own AILANG source, queryable by Claude Code and Codex. Write the plan to `.agent/plans/AILANG_Code_Graph.md` (the repo's plans live in `.agent/plans/`).

You are **planning, not implementing**. Produce phased, ordered tasks with critical files, per-phase acceptance gates, and test/fixture specs. Do not write the extractor itself.

## Read first (in this order)

1. `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md` — the authoritative design. Read it **fully**. The load-bearing sections: **Resolved During Review**, **Slug Scheme (Decided)**, **Root Set for Unimported-Module Detection (Decided)**, **Implementation Plan** (Phases 0–4), **Acceptance Criteria**, **Constraints**, **Edge & Node Model**, **How This Serves ADR-001 (DST)**.
2. `.agent/projects/002_code_graph/poc_callgraph.py` — the ~70-line validated PoC source parser (run it: `python3 .agent/projects/002_code_graph/poc_callgraph.py $(find src/core -name '*.ail')` → ~1019 edges, 0.1s, zero hydration). Phase 1 hardens this.
3. `.agent/tools/code-graph-query.ts`, `code-graph-refresh.ts` — **reference-only** (Zeus/ClickHouse-targeted, stale `tools/code-graph/` paths). Borrow the *query mechanism* idea, not the code.
4. `code-graph/` (repo root) — the C# precedent: `visualize.py` (SVG-render path is reusable; namespace-coarsening graph-building is not), `tools/mmd2svg/`. `load.py`/`schema.sql` are ClickHouse-server-oriented and **not** reused.
5. ADR-001 (`.agent/projects/001_DST/`) — DST is the primary consumer; the graph must answer its R3/R7/R8/R13/R15 questions.

## Decisions already made — DO NOT relitigate (cite the ADR)

- **Two sources.** `ailang iface` for the typed layer (exported types/sigs/effect rows; needs hydration; exits 0 on failure — classify by output). Raw-source parser for imports + call graph + ctors (hydration-free, whole-program, approximate).
- **Engine: chDB** (embedded ClickHouse, `pip install chdb`, ~712 MB, **not yet a prerequisite** — adding it is a Phase-0 task). Queries CSVs in-process via `file('…','CSVWithNames')`. DuckDB was the rejected lighter runner-up; schema stays engine-neutral.
- **Surface: CLI-first**, documented in `AGENTS.md`, callable via the agents' Bash tool. MCP may wrap it later. Not a harness plugin.
- **Location: `tools/code-graph/`** (tooling); generated artifacts in `tools/code-graph/.out/` (gitignored).
- **Effect model:** effects seed at **stdlib-primitive call sites**, propagate **BACKWARD** over `invokes` (callee→caller). `iface` effect rows are **transitive** (verified) and are the **validation oracle** — a function's computed reachable effects must equal its `iface` row; divergence = call-graph incompleteness = the precision metric. Do **not** forward-propagate exported effects.
- **Slug scheme:** `{module}#{name}`, **case-preserving**, **kind-separated tables** (`modules`/`funcs`/`types`/`ctors`; edges join by edge type). Module slug = file path (validate against `module` decl). Ctor names payload-stripped. Assert `(table, slug)` uniqueness + flag duplicate unqualified imports at emit.
- **Unimported-module roots:** derived **programmatically** from the dynamic-load sources (TS-host `src/core/*.ail` string-literal scan; `registry_generated.ail` + `[extensions].order`; `scripts/`+`examples/`+test globs). Label output **"unimported," never "dead"/"safe to delete."**
- **Call-graph precision cut line** (heuristic work is throwaway once `--json` lands): **Do** alias-only-qualified resolution, source-derived ctor filtering, interpolation-call scanning (27 real edges measured). **Skip** `let`-shadowing (0 occurrences). **Defer to `--json`** higher-order + type-class dispatch. Re-export origin via typed layer only.
- **`pure`** carries no signal today (invariant across 78 funcs) — passthrough column, upstream question filed.
- **AILANG pinned to v0.26.0** (already adopted; `make check_core`/`test_core` green). `debug ast` confirmed too shallow for a call graph on v0.24.2 **and** v0.26.0.

## Still open — the plan should resolve in design or explicitly defer

- Whether the TS host exposes a machine-readable load manifest (vs. scraping `.ts` string literals for runtime-entry roots).
- Policy for a module with test functions but no importer and no `main` (auto test-root vs. flag).

## What the plan must specify (the ADR leaves these to you)

1. **File layout under `tools/code-graph/`** — extractor (Python), chDB query CLI, viz, `extract.sh` orchestration, `.out/` (+ `.gitignore` entry). Decide co-location with / migration of the existing root `code-graph/` (flagged in ADR as a separate action).
2. **CSV schemas** (exact columns) for every table: `modules`, `funcs`, `types`, `ctors`, `imports`, `invokes`, `uses`, `effects`, `effect_edges` (`func_slug, effect, source_func_slug, distance, derivation`), `extraction_status` (incl. `built_at`, `ailang_version`, `graph_schema`).
3. **The `ok/failed/partial` classifier** rules + golden fixtures (incl. the warning-line-on-stdout case).
4. **The stdlib primitive→effect seed catalog** build step (`ailang builtins list --by-effect` + stdlib `iface`) and the backward-propagation algorithm + oracle check.
5. **CLI contract** — args, output JSON shape, staleness + coverage/`INCOMPLETE` banners, row truncation; example queries for DST R3/R7/R8/R13.
6. **Test plan** — golden parser fixtures (imports/aliases/selective/comments/strings/interpolation/ctors/shadowing/qualified/same-name/failed-iface) **and** measured precision/recall on a hand-validated 3-module sample (must include `agent_loop_v2`), recorded in the ADR/plan before "Accepted."
7. **Prerequisite + CI changes** — add `chdb` to `install-prerequisites.sh`; `extract.sh` in CI; advisory unimported + effect-diff checks.
8. **`AGENTS.md` documentation** task.

## Grounding rules (non-negotiable)

- Validate every AILANG-behavior claim against the **local v0.26.0 binary**, never docs/memory. Use `iface`/`builtins list --by-effect` directly.
- The **`iface` effect-oracle is the correctness check** — design the plan so it is computed and reported, not assumed.
- Label all call-graph / effect-reachability output **approximate**, with coverage + staleness.
- Phases are sequenced so the **hydration-free structural+call graph (Phase 1) ships first** and works on modules `iface` can't load.
- If you find an ADR decision that is wrong or contradictory, **flag it for the user** — do not silently diverge. The ADR is source of truth; changing it is a conversation, not a plan edit.

## Deliverable shape

A phased plan mirroring ADR Phases 0–4, each phase with: goal, ordered tasks, critical files (full paths), acceptance gate, and test/fixture deliverables. Front-load Phase 0 (chdb prerequisite, seed catalog, classifier+fixtures, precision/recall harness) and Phase 1 (the hydration-free graph). End with the precision/recall numbers required before marking v1 Accepted.
