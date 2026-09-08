# Handoff: Investigate AILANG LSP for `ailang-graph`

Date: 2026-06-30
For: the agent evaluating whether AILANG LSP should feed `tools/code-graph/`
From: MOT-25 code-graph PoC follow-up

## Your task

Investigate whether the AILANG Language Server Protocol implementation can improve,
replace, or complement the current `ailang-graph` extractor in `tools/code-graph/`.

You are **researching and prototyping lightly**, not rewriting the extractor. Produce a
recommendation with evidence: what LSP can provide today, what it cannot provide, which
code-graph tables or phases it could improve, and whether adopting it is worth doing
before the pending upstream `ailang debug ast --json` / stdlib iface feature requests
land.

Primary reference:

- AILANG LSP guide: `https://ailang.sunholo.com/docs/guides/lsp`

## Current implementation facts

The current code graph does **not** use LSP. It uses:

- raw-source parsing in `tools/code-graph/extractor/source_parser.py` for modules,
  imports, function spans, constructors, and approximate call edges;
- `ailang iface` in `tools/code-graph/extractor/iface_pass.py` for exported typed
  signatures, type rows, declared effects, and iface coverage status;
- `ailang builtins list --by-effect` in
  `tools/code-graph/extractor/seed_catalog.py` for module-granular stdlib effect
  seeding;
- CSV output under `tools/code-graph/.out/` queried with embedded chDB from
  `tools/code-graph/query/cgq.py`;
- documentation for agents in `tools/code-graph/AGENTS.md`.

The call graph and reachable effect graph are explicitly approximate. This is a design
contract, not a bug: every answer must keep coverage/staleness/incomplete metadata
unless LSP provides enough structured evidence to strengthen the claim.

## Read first

1. `tools/code-graph/AGENTS.md` — current user/agent operating contract.
2. `tools/code-graph/README.md` — current CLI examples and caveats.
3. `.agent/projects/002_code_graph/AILANG_Code_Graph.md` — implemented plan. Focus on
   the upstream feature-request notes, Phase 1 parser scope, Phase 2 iface/effect
   layer, and Phase 4 AST/JSON upgrade.
4. `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md` — design
   rationale, especially why source parsing shipped and what `debug ast --json` would
   replace.
5. `tools/code-graph/extractor/source_parser.py`,
   `tools/code-graph/extractor/iface_pass.py`, and
   `tools/code-graph/extractor/seed_catalog.py` — current extraction sources.
6. `tools/code-graph/query/cgq.py` — metadata/staleness/query contract.
7. The AILANG LSP guide linked above. Verify claims against the local `ailang` binary;
   do not rely only on docs.

## Investigation questions

Answer these with concrete evidence:

1. **Protocol availability.** Does the local `ailang` version support `ailang lsp
   --stdio`? What initialization options, workspace root shape, and file URI handling
   does it require?
2. **Document symbols.** Can LSP `textDocument/documentSymbol` provide function/type
   spans that are more accurate than `source_parser.func_spans`? Does it expose
   exported vs internal functions, constructors, test blocks, imports, or module
   declarations?
3. **Definitions and references.** Can LSP `textDocument/definition` or
   `textDocument/references` recover call edges, import edges, or type-use edges at
   repo scale? If yes, measure whether it handles:
   - internal function calls;
   - imported symbol calls;
   - aliases and symbol-list imports;
   - constructors vs function calls;
   - calls inside string interpolation;
   - higher-order or type-class-dispatched calls.
4. **Diagnostics.** Can LSP diagnostics replace or improve `ailang iface` failure
   classification, hydration checks, or stale-cache detection?
5. **Hover/signature data.** Does LSP hover or signature help expose type signatures,
   effects, purity, or exported status in a machine-readable enough form to replace
   some `iface` usage?
6. **Stdlib/effect data.** Does LSP expose public stdlib function-to-effect data, or is
   the `seed_catalog.py` upstream feature request still needed?
7. **Performance.** How long does it take to initialize the LSP and query symbols or
   references for the default `core` profile? Compare roughly with the current source
   parser and `ailang iface` pass.
8. **Robustness.** Does LSP require full dependency hydration for the same modules that
   `ailang iface` requires? Does it fail cleanly on modules like `agent_loop_v2.ail`?
9. **Artifact fit.** If LSP is useful, which CSV tables would it populate or improve:
   `modules`, `funcs`, `types`, `ctors`, `imports`, `invokes`, `uses`, `effects`,
   `effect_edges`, `source_chunks`, or `extraction_status`?
10. **Agent ergonomics.** Would adding LSP make the tool easier for agents to use, or
    would it add a long-lived protocol dependency that is worse than the current CLI
    commands?

## Prototype guidance

Keep any prototype isolated under `tools/code-graph/experiments/` or as a temporary
script unless the user explicitly asks for implementation.

Suggested minimal prototype:

1. Start `ailang lsp --stdio`.
2. Send `initialize`, `initialized`, and `textDocument/didOpen` for one small module
   and one hard module such as `src/core/agent_loop_v2.ail`.
3. Query `textDocument/documentSymbol`.
4. Query `textDocument/definition` and `textDocument/references` for a few known
   symbols:
   - `dispatch_step`;
   - `try_emergency_compaction`;
   - `httpGet`;
   - one constructor such as `Ok` or `Err`;
   - one imported alias if available.
5. Record raw responses and summarize which fields are stable enough to depend on.

Do not add a runtime dependency to `tools/code-graph/extract.sh` during the
investigation. The current extractor must keep working without LSP.

## Acceptance evidence

Provide a short report with:

- exact `ailang --version`;
- exact LSP startup command used;
- tested files and symbols;
- representative sanitized JSON-RPC responses or field summaries;
- a table mapping LSP capability to current code-graph table/feature;
- a recommendation: **adopt now**, **keep as optional experiment**, or **defer until
  AILANG AST/stdlib feature requests land**;
- risks and fallback plan;
- any proposed follow-up issue or implementation handoff.

## Decision guardrails

- Do not weaken existing metadata discipline. If LSP data is partial, stale, or
  hydration-dependent, encode that in `extraction_status`/query metadata.
- Do not replace exact import extraction with weaker LSP-derived guesses.
- Do not replace `ailang iface` typed/effect rows unless LSP exposes equivalent
  structured data with clear failure modes.
- Prefer an optional LSP enrichment layer over making the core extractor depend on a
  long-lived server process unless the evidence is strong.
- If LSP does not expose call edges or effects directly, say so plainly. It may still
  be useful for symbol spans or navigation, but not for the effect graph.
