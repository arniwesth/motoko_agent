---
doc_type: short
full_text: sources/OhMyPi_Tool_Integration.md
---

# OhMyPi Tool Integration Plan

**Goal:** Swap Motoko's basic file tools (ReadFile, WriteFile, EditFile, Search) for oh‑my‑pi's more advanced TypeScript+Rust implementations, routed through the existing delegated‑tool JSONL channel. The AILANG runtime retains full control; only the execution backend moves to the frontend process.

## Key Motivations
- oh‑my‑pi provides [[concepts/hashline_anchors|hashline anchors]] for stale‑safe edits, a fuzzy 8‑strategy edit pipeline, and a high‑performance Rust N‑API addon (memmap grep, ray‑on parallelism, fs_cache).
- Current native tools lack staleness detection and rely on exact string matching.
- Integration is non‑invasive: the AILANG language runtime, agent loop, and JSONL protocol stay unchanged.

## Architecture
File tools are reclassified from `Native` to `Delegated`. The TypeScript frontend dispatches them to oh‑my‑pi tool classes (in‑process, using the Rust addon) instead of spawning subprocesses. The [[concepts/delegated_tool_channel|delegated‑tool channel]] already exists for bash processes; this extends it in a principled way.

## Phased Rollout
### Phase 0: Bun Migration
Motoko's frontend moves from Node.js to Bun, removing the compatibility gap (oh‑my‑pi uses Bun‑specific APIs like `Bun.hash.xxHash32`). All existing TypeScript code and dependencies work unchanged; only runtime scripts and tooling are updated. [[concepts/Bun_migration|Details →]]

### Phase 1: Dependency Audit & Vendoring
Determine exactly which oh‑my‑pi source files and the Rust addon are needed. Decision leans toward **vendoring** the tool source into `src/tui/src/ohMyPi/` for control and to avoid upstream release coupling.

### Phase 2: TypeScript Dispatcher
Implement a dispatcher in the frontend that maps incoming `DelegatedCall` objects to oh‑my‑pi tool classes. Gated behind `OHMY_PI_TOOLS=1` during development.

### Phase 3: Reclassify Tools in AILANG
Update `tool_runtime.ail` so `ReadFile`, `WriteFile`, `EditFile`, and `Search` are returned as `Delegated`. Remove the old read‑before‑edit policy — hashline staleness checking replaces it.

### Phase 4: LLM Integration
- **System Prompt:** Teach models how to read hashline‑formatted file content and emit anchor‑based edits (`replace_line(42nd, …)`).
- **Observation Format:** Tune `fmt_tool_obs` to handle enriched edit results and diffs.
- **Testing:** Run with Claude, GPT‑4o, and Gemma 4; measure anchor accuracy, contamination rates, and tokens.

### Phase 5: Testing, Docs, Default‑On
Add TypeScript/integration tests, update documentation, and flip `OHMY_PI_TOOLS` to default on after a bake‑in period.

## Edit Mode Strategy
- **Per‑model defaults:** Frontier models use `hashline`; small/open models use `replace`; mid‑tier uses `auto` with adaptive fallback (downgrade after N consecutive anchor failures).
- **Gemma 4** is a specific investigation target — its structured‑tool strength may handle hashline anchors well; results will inform the default table and potentially spawn a simplified anchor variant.
- **Read format** adapts to the active edit mode (bigram annotations only when `hashline` is active).

## Non‑Goals
- Not replacing the AILANG runtime or agent loop
- Not adopting oh‑my‑pi’s TUI or all 30+ tools
- Not changing the text‑parsed tool‑calling protocol (no function‑call API)
- No modifications to the `ailang/` language runtime

## Risks & Open Questions
- **Bun compatibility**: Low risk; all Node APIs used are supported.
- **Rust addon availability**: Verified in Phase 1; pure‑TS fallback possible.
- **Hashline model confusion**: Mitigated by per‑model defaults and adaptive fallback.
- **Vendor vs. npm dependency**: Decision in Phase 1; vendor preferred for control.
- Licensing of the Rust N‑API addon must be confirmed.

[[concepts/oh-my-pi_tool_integration]] serves as a broader cross‑document concept once this plan is implemented.