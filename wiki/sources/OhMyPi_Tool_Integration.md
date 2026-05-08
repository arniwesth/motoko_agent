# oh-my-pi Tool Integration (Path 3: Hybrid Channel)

**Date:** 2026-04-29
**Status:** Draft — open investigation, not yet committed
**Branch:** `OhMyPi_Tool_Integration`

**Source project:** [oh-my-pi](https://github.com/can1357/oh-my-pi) by can1357
**Key upstream packages:**
- `packages/coding-agent/src/tools/` — ReadTool, WriteTool, EditTool, SearchTool
- `packages/coding-agent/src/edit/` — edit modes (hashline, replace, patch)
- `packages/natives/` — TypeScript wrapper for Rust N-API addon
- `crates/pi-natives/` — Rust cdylib: grep, glob, fs_cache, syntax highlight, text measurement

---

## Goal

Replace Motoko's current native AILANG-side file tools (ReadFile, WriteFile,
EditFile, Search) with oh-my-pi's TypeScript+Rust implementations, routed
through the existing delegated-tool channel to the TypeScript frontend.

The AILANG runtime keeps full control of the agent loop, tool parsing, step
budget, trajectory cache, and observation shaping. Only the execution backend
for file operations moves to the TypeScript process, where oh-my-pi's tools
run in-process with access to the Rust N-API addon.

## Why

Motoko's current native file tools are functional but basic:

- **ReadFile** reads full file content, selects line ranges, returns plain text
- **EditFile** does exact string match/replace; no fuzzy matching, no staleness
  detection beyond optional `expected_sha256`
- **Search** shells out to `rg` via `std/process.exec`

oh-my-pi's tools are significantly more capable:

- **Hashline mode**: BPE-optimized line anchors (1 token per line) with built-in
  staleness detection and auto-rebase within ±2 lines
- **Fuzzy edit pipeline**: 8-strategy fallback (exact → whitespace-trimmed →
  comment-stripped → unicode-normalized → prefix → substring → fuzzy similarity)
- **Replace mode**: Levenshtein-scored sliding window with dominant-match
  auto-selection and automatic indent adaptation
- **Rust N-API**: memmap grep, rayon parallelism, fs_cache with TTL, mimalloc
- **Read tool**: streaming line reader with byte/line budgets, fuzzy path
  resolution, hashline formatting

## Non-Goals

- Replacing the AILANG runtime or agent loop with oh-my-pi's agent
- Adopting oh-my-pi's TUI (we already use pi-tui independently)
- Moving bash execution to oh-my-pi (Motoko's delegated process execution works)
- Changing the JSONL protocol between runtime and frontend
- Modifying the `ailang/` language runtime fork
- Adopting all 30+ oh-my-pi tools — only ReadFile, WriteFile, EditFile, Search
- Provider-native tool calling (function_call / tool_use API) — Motoko uses
  text-parsed tool calls; that stays unchanged

## Architecture

```
Current flow (file tools):
  AILANG runtime → parse tool_calls → run_native_batch() → ReadFile/EditFile in AILANG
                                                          → result back to conversation

Proposed flow (file tools):
  AILANG runtime → parse tool_calls → backend_for() returns Delegated
                 → emit tool_calls JSONL → TypeScript frontend
                 → dispatch to oh-my-pi tool class (in-process, Rust N-API)
                 → tool_results JSONL back to AILANG runtime
                 → result back to conversation

Unchanged flow (bash/tests):
  Same as today — simple process calls run native, shell calls get delegated
```

The key insight: Motoko already has the delegated-tool channel (`tool_calls` /
`tool_results` over JSONL stdin/stdout). File tools just need to be reclassified
from `Native` to `Delegated`, and the TypeScript frontend needs to dispatch them
to oh-my-pi tool classes instead of spawning child processes.

---

## Dependencies

### npm packages to add to `src/tui/package.json`

The exact package names depend on how oh-my-pi publishes. Likely:

| Package | Purpose |
|---------|---------|
| `@aspect-build/pi-natives` (or vendored) | Rust N-API addon (grep, glob, fs_cache, highlight) |
| oh-my-pi tool source (vendored or forked) | ReadTool, WriteTool, EditTool, edit modes |

**Decision needed:** vendor the tool source into `src/tui/src/tools/` or add as
an npm dependency. Vendoring gives us full control over the integration surface
and avoids coupling to oh-my-pi's release cadence. The Rust addon is a binary
artifact that must match the host platform — it already handles platform
detection internally.

### No changes to `ailang/`

The AILANG language runtime is not touched. All changes are in:
- `src/core/` (AILANG application code — tool routing, prompts)
- `src/tui/` (TypeScript frontend — tool dispatch, oh-my-pi integration)

---

## Phases

### Phase 0: Migrate TypeScript Frontend from Node.js to Bun

**Goal:** Motoko's TypeScript frontend runs on Bun instead of Node.js, removing
the Bun/Node compatibility gap before oh-my-pi tool code is integrated.

**Why this is Phase 0:** oh-my-pi targets Bun throughout. Its hashline system
uses `Bun.hash.xxHash32` for line-content hashing — a Bun runtime built-in with
no Node.js equivalent. Rather than shimming every Bun-specific API in vendored
oh-my-pi code (unknown surface area, risk of hash divergence on seed/encoding,
ongoing maintenance burden), we move Motoko to Bun. This also simplifies the
build: Bun runs TypeScript directly, eliminating the `tsc` compile step and the
Jest ESM workaround machinery.

**Compatibility basis:** All Node built-ins used by Motoko (`child_process`,
`fs`, `path`, `readline`, `crypto`, `url`, `http`) are supported by Bun. All
npm dependencies (`express`, `chalk`, `@mariozechner/pi-tui`) work unchanged.
Zero TypeScript source files need code changes.

Files changed:
- `scripts/run-agent.sh` — `exec node` → `exec bun`
- `scripts/install-prerequisites.sh` — replace Node.js install with Bun install
- `src/tui/package.json` — update scripts, optionally drop tsc/ts-jest devDeps
- `Makefile` — update build/run targets
- `README.md` — prerequisites table, install/run instructions
- `CLAUDE.md` — update commands section

**Scope:** This phase migrates the runtime only (scripts, entry point, package
management). The test runner stays on Jest initially — migrating tests to
`bun:test` is optional follow-up work, not a prerequisite for oh-my-pi
integration.

Tasks:
- [ ] Install Bun in dev environment; verify `bun src/tui/src/index.ts` starts
      the frontend and environment server correctly
- [ ] Update `scripts/run-agent.sh:41`: `exec node "$ENTRY"` → `exec bun "$ENTRY"`
- [ ] Update `scripts/install-prerequisites.sh`: replace Node.js 20 install
      (`install_node`) with Bun install (`curl -fsSL https://bun.sh/install | bash`);
      update version check from `node --version` to `bun --version`
- [ ] Update `src/tui/package.json`:
  - `"build"` script: keep `tsc` for type-checking only (no longer on the run path)
  - `"test"` script: change `node --experimental-vm-modules node_modules/.bin/jest`
    to `bun node_modules/.bin/jest` (keeps Jest, drops the ESM flag workaround)
- [ ] Replace `npm install` with `bun install` in scripts and Makefile
- [ ] Update `Makefile` build/run targets: `node` → `bun`
- [ ] Run existing Jest test suite under `bun jest`; fix any failures
- [ ] Update `README.md` prerequisites table: Node.js ≥ 20 → Bun ≥ 1.x
- [ ] Update `CLAUDE.md` commands section
- [ ] Verify `ailang` subprocess spawning works correctly under Bun's
      `child_process.spawn` (the AILANG runtime is a Go binary — Bun spawns it
      the same way Node does, but verify JSONL stdin/stdout piping)
- [ ] End-to-end smoke test: `bun src/tui/src/index.ts "echo hello"` completes
      a single-step agent run

**Optional follow-up** (not blocking): Migrate test suite from Jest to
`bun:test`. This drops `ts-jest`, `@jest/globals`, and the Jest ESM config from
`package.json`, but is cosmetic — Jest works fine under Bun.

**Deliverable:** Motoko runs on Bun. Node.js is no longer a prerequisite.

### Phase 1: Dependency Audit and Vendoring Decision

**Goal:** Determine exactly which oh-my-pi source files and packages are needed,
and decide vendor vs. dependency.

Tasks:
- [ ] Inventory oh-my-pi's tool class dependencies (what does ReadTool import?)
- [ ] Inventory Rust N-API addon exports used by the file tools
- [ ] Map oh-my-pi's `ToolSession` interface to determine what adapter surface
      Motoko needs to provide
- [ ] Decide: vendor tool source into `src/tui/src/ohMyPi/` or add npm dep
- [ ] Decide: vendor Rust addon or use published binary
- [ ] Verify pi-natives binary availability for linux-x64 (Motoko's primary
      platform) and darwin-arm64 (dev machines)
- [ ] Document the decision in this plan

**Deliverable:** Updated dependency list and vendoring strategy.

### Phase 2: TypeScript Tool Dispatcher

**Goal:** The TypeScript frontend can dispatch ReadFile/WriteFile/EditFile/Search
to oh-my-pi tool classes in-process.

Files changed:
- `src/tui/src/runtime-process.ts` — add tool dispatch branch in `handleToolCalls`
- `src/tui/src/ohMyPi/` (new) — vendored or imported tool classes
- `src/tui/src/ohMyPi/session-adapter.ts` (new) — adapts Motoko context to
  oh-my-pi's `ToolSession` interface
- `src/tui/package.json` — add dependencies

Tasks:
- [ ] Create `ToolSession` adapter that provides:
  - `cwd` (from WORKDIR env var)
  - `hasEditTool: true` (enables hashline formatting in reads)
  - settings/config (edit mode selection, default to hashline)
- [ ] Implement `dispatchOhMyPiTool(call: DelegatedCall): Promise<DelegatedResult>`
  - Maps `DelegatedCall` → oh-my-pi tool arguments
  - Invokes the appropriate tool class
  - Maps oh-my-pi `ToolResultMessage` → `DelegatedResult`
- [ ] Wire into `handleToolCalls`:
  ```typescript
  if (["ReadFile", "WriteFile", "EditFile", "Search"].includes(call.tool)) {
    result = await dispatchOhMyPiTool(call);
  } else {
    result = await this.runDelegatedCall(call);
  }
  ```
- [ ] Handle errors gracefully — if oh-my-pi tool throws, return
  `DelegatedResult` with exit_code=1 and error in stderr
- [ ] Gate the dispatch behind `OHMY_PI_TOOLS=1` env var (default off). When off,
  `handleToolCalls` uses the existing `runDelegatedCall` path for all tools.
  This gate is used throughout Phases 2–5 for development and testing.

**Deliverable:** TypeScript frontend dispatches file tools to oh-my-pi when
`OHMY_PI_TOOLS=1` is set. Not yet wired to the AILANG runtime (file tools still
run native).

### Phase 3: Reclassify File Tools as Delegated

**Goal:** The AILANG runtime sends file tool calls to the TypeScript frontend
instead of executing them natively.

Files changed:
- `src/core/tool_runtime.ail` — change `backend_for()` to return `Delegated`
  for ReadFile, WriteFile, EditFile, Search

Tasks:
- [ ] Update `backend_for()`:
  ```ailang
  export pure func backend_for(call: ToolCallEnvelope) -> ToolBackend {
    if call.tool == "ReadFile" || call.tool == "WriteFile"
       || call.tool == "EditFile" || call.tool == "Search" then Delegated
    else if call.tool == "BashExec" || call.tool == "RunTests" then
      if needs_delegation_for_process(...) then Delegated else Native
    else Native
  }
  ```
- [ ] Verify `rpc.ail:run_hybrid_step` handles the increased delegated batch
      correctly (it should — the delegation pipeline is generic)
- [ ] Update `delegated_wait_attempts` timeout calculation if needed — file
      tools are faster than process execution, but batches may be larger
- [ ] Remove or gate the read-before-edit policy in `run_edit_file` since
      oh-my-pi's hashline staleness detection subsumes it
- [ ] Run existing AILANG tests to confirm no regressions in parse/types

**Deliverable:** End-to-end flow works: AILANG runtime → delegated → TypeScript
→ oh-my-pi tool → result back to runtime.

### Phase 4: LLM Integration (System Prompt + Observation Format)

**Goal:** The LLM knows how to use the new tools, and tool results are optimally
formatted in the conversation.

These are two sides of the same loop — the system prompt tells the LLM what to
emit, the observation format determines what it sees back — so they must be
designed and tested together.

Files changed:
- `SYSTEM.md` — add hashline format documentation to the tool reference section
- `src/core/prompts.ail` — system prompt assembly and `fmt_tool_obs` formatting

System prompt tasks:
- [ ] Document hashline read format in SYSTEM.md:
  - Line format: `42nd|function hi() {` where `nd` is the content hash
  - Structural lines (braces only) use ordinal suffixes: `1st`, `2nd`, etc.
  - When editing, reference lines by anchor (e.g. `42nd`)
- [ ] Document edit operations:
  - `replace_line(anchor, new_content)`
  - `replace_range(start_anchor, end_anchor, new_content)`
  - `append_at(anchor, content)` / `prepend_at(anchor, content)`
- [ ] Document staleness behavior: if anchor hash doesn't match, edit is
      rejected with updated anchors — re-read and retry
- [ ] Keep replace mode documented as fallback (old/new string matching) for
      models in replace mode or after adaptive downgrade

Observation format tasks:
- [ ] Tune `fmt_tool_obs` in `src/core/prompts.ail` for oh-my-pi result shapes
  - ReadFile results now include hashline-formatted content
  - EditFile results include richer diff and staleness feedback
- [ ] Decide whether to pass oh-my-pi's structured result directly or reshape it
      into Motoko's existing `ToolResultItem` ADT format
- [ ] Verify token budget impact — hashline adds ~1 token per line to read
      output; measure on representative files

Testing tasks:
- [ ] Test with Claude and GPT-4o to verify models understand the format and
      produce correct anchor references in edits
- [ ] Run Gemma 4 edit benchmark (10 files, mix of single-edit and multi-edit
      tasks) in all three modes (hashline, replace, auto) — see "Gemma 4 26B"
      section below for measurement criteria
- [ ] Test trajectory cache compatibility — cached trajectories from pre-hashline
      runs should degrade gracefully (hint text won't match exactly, which is
      acceptable)

**Deliverable:** Models use hashline anchors for precise, stale-safe edits.
Observation formatting produces clean, token-efficient results.

### Phase 5: Testing, Documentation, and Default-On

**Goal:** Tested, documented, and promoted to default.

The `OHMY_PI_TOOLS` gate was introduced in Phase 2. This phase adds test
coverage, updates documentation, and flips the default from off to on.

Tasks:
- [ ] Add TypeScript tests for the tool dispatcher (mock oh-my-pi tool classes)
- [ ] Add integration test: spawn runtime with `OHMY_PI_TOOLS=1`, submit a task
      that reads and edits a file, verify correct result
- [ ] Verify native fallback still works with `OHMY_PI_TOOLS=0`
- [ ] Update README.md tool documentation
- [ ] Update CLAUDE.md if tool contracts change
- [ ] Flip `OHMY_PI_TOOLS` default from `0` to `1` after bake-in
- [ ] Remove dead native file-tool code from `tool_runtime.ail` once the gate
      is removed (defer to after bake-in period)

**Deliverable:** oh-my-pi tools are the default, with native fallback available
via `OHMY_PI_TOOLS=0`.

---

## Result Format Mapping

oh-my-pi tools return rich structured results. These map to Motoko's
`DelegatedResult` format:

| oh-my-pi field | DelegatedResult field | Notes |
|----------------|----------------------|-------|
| content (read) | stdout | Hashline-formatted file content |
| diff (edit/write) | stdout | Unified diff of changes |
| error message | stderr | Tool-level errors |
| success/failure | exit_code | 0 = success, 1 = error |
| details.truncated | truncated | Whether output was truncated |

The AILANG runtime already handles `DelegatedResult` generically — it doesn't
need to know the internal structure of stdout/stderr.

### Input Argument Mapping

Motoko's `ToolCallEnvelope` arguments must be translated to oh-my-pi tool
arguments in the Phase 2 dispatcher. The tool names and argument shapes differ:

| Motoko tool | Motoko arguments | oh-my-pi tool | oh-my-pi arguments | Notes |
|---|---|---|---|---|
| ReadFile | `{path, start_line?, end_line?}` | ReadTool | `{path, offset?, limit?}` | Rename fields; oh-my-pi also accepts byte budgets |
| WriteFile | `{path, content}` | WriteTool | `{path, content}` | Direct mapping; WriteTool strips hashline prefixes from content |
| EditFile (replace mode) | `{path, old_string, new_string}` | EditTool | `{path, old_string, new_string}` | Direct mapping; oh-my-pi adds fuzzy fallback pipeline |
| EditFile (hashline mode) | `{path, anchor, new_content}` | EditTool | `{path, anchor, new_content}` | New argument shape — requires system prompt changes (Phase 4) |
| EditFile (hashline range) | `{path, start_anchor, end_anchor, new_content}` | EditTool | `{path, start_anchor, end_anchor, new_content}` | Multi-line replace by anchor range |
| Search | `{pattern, path?, glob?}` | SearchTool | `{query, path?, include?}` | Rename fields; oh-my-pi `include` replaces `glob` |

**Key difference:** In replace mode, EditFile keeps the same argument shape as
today — the LLM sends `old_string`/`new_string` and oh-my-pi's fuzzy pipeline
handles matching. In hashline mode, the argument shape changes to anchor-based
addressing, which requires system prompt updates (Phase 4). The dispatcher must
handle both shapes based on the active edit mode.

---

## Read-Before-Edit Policy Migration

Current policy (`tool_runtime.ail:619`): EditFile checks that the target path
appears in `read_paths` (accumulated during the native batch). This prevents
blind edits.

oh-my-pi's hashline system replaces this with a stronger guarantee: every line
reference includes a content hash. If the file changed since the last read, the
hash won't match and the edit is rejected with updated anchors.

Migration:
1. Phase 3: Remove the `read_paths` check for delegated EditFile calls
2. The hashline staleness check in oh-my-pi's edit tool provides the safety net
3. For non-hashline edit modes (replace, patch), oh-my-pi's tools have their
   own validation (fuzzy match confidence thresholds, dominant-match logic)

---

## Edit Mode Strategy: Per-Model Defaults and Adaptive Fallback

### The Problem

Hashline mode asks the LLM to do something novel: parse a `LINE+BIGRAM|`
display format, hold anchors in working memory, and reference them precisely
in edit operations. This is easy for frontier models but creates specific,
predictable failure modes for smaller models.

### Failure Modes (ordered by frequency)

1. **Format contamination.** The model copies `LINE+HASH|` prefixes into
   replacement content. It treats the display format as part of the file
   content. Example: emitting `5th|order.discount = 0.15;` as the new line
   instead of `order.discount = 0.15;`. oh-my-pi's WriteTool strips these
   prefixes, but EditTool replace modes may not.

2. **Anchor hallucination.** The model generates a plausible-looking anchor
   (`4xy`) that wasn't in the read output. It remembers the line number but
   fabricates the bigram. oh-my-pi catches this (hash mismatch → rejection
   with updated anchors), so it's safe but wastes a step.

3. **Bare line numbers.** The model ignores the bigram entirely and uses
   plain line numbers (`replace_line(4, "...")`). This bypasses staleness
   detection — the whole point of hashline.

4. **Multi-edit anchor confusion.** Hashline edits must reference the file
   *as it was read*, not after prior edits in the same batch. Smaller models
   sometimes try to compute what anchors would be post-edit and get it wrong.

5. **Format bleed.** The model over-learns the hashline format and starts
   emitting anchors in bash commands, commit messages, or prose.

### Per-Model Edit Mode Defaults

| Model tier | Default mode | Rationale |
|---|---|---|
| Frontier (Opus, Sonnet, GPT-4o, Gemini Pro) | `hashline` | Full staleness detection, precise anchoring |
| Mid-tier (Haiku, GPT-4o-mini, Flash) | `hashline` with auto-fallback | Benefits when it works, graceful degradation |
| Small/open (Gemma 4 26B, local models) | `replace` | Fuzzy pipeline is the real win; don't risk anchor confusion |

The mode is selectable via `EDIT_MODE=hashline|replace|auto` env var. The
model-string-based default can be overridden.

### Adaptive Fallback (`auto` mode)

When `EDIT_MODE=auto`:

1. Start with `hashline` for the session
2. Track consecutive anchor failures (hash mismatch, hallucinated anchor,
   format contamination in replacement content)
3. After N failures (default: 3) in a session, downgrade to `replace` for the
   remainder of the session
4. Emit a JSONL event (`edit_mode_downgrade`) so the TUI can show the switch
5. Log the downgrade reason for telemetry

This lets us **learn empirically** how each model handles hashline without
hard-coding assumptions. The telemetry from `auto` mode informs the per-model
default table over time.

### Gemma 4 26B: Specific Investigation

Gemma 4 is a priority model for Motoko (see `Structured_Tool_Call_Authoring`
plan). Its tool-calling is strong but its AILANG syntax emission is weak — it
relies heavily on structured tool surfaces to avoid out-of-distribution syntax.

Hashline anchors are a new structured format that plays to Gemma 4's strengths
(tool-call JSON with typed fields) rather than its weaknesses (freehand syntax).
The anchor is just a string field in the tool call — `"anchor": "42nd"` — which
is well within Gemma 4's capabilities. The question is whether it can:

- Hold anchors from a read result across a tool-call boundary
- Avoid contaminating replacement content with display prefixes
- Handle multi-edit batches without anchor confusion

These are empirically testable. The investigation plan:

1. **Phase 4 includes Gemma 4 testing.** Run a standard edit benchmark (10
   files, mix of single-edit and multi-edit tasks) with Gemma 4 in all three
   modes (hashline, replace, auto).
2. **Measure:** anchor accuracy rate, format contamination rate, steps-to-
   completion, total tokens used.
3. **Compare against:** Motoko's current exact-match EditFile as baseline,
   replace mode as middle ground, hashline as ceiling.
4. **If Gemma 4 handles hashline well:** promote it to default for that model
   tier. This would be a significant capability upgrade for small-model agents.
5. **If Gemma 4 struggles:** investigate targeted mitigations:
   - Simplified anchor format (line number only, no bigram — loses staleness
     but keeps the addressing benefit)
   - Anchor stripping in replacement content (detect and remove `LINE+HASH|`
     prefixes before applying edits)
   - Reduced anchor vocabulary (fewer bigrams → more collisions but simpler
     for the model to reproduce)
   - Few-shot examples in the system prompt showing correct anchor usage

The Gemma 4 results will directly inform the default table and may lead to a
Gemma-optimized anchor format variant.

### Read Format Coupling

The edit mode selection also affects the read format:

| Edit mode | Read format | Extra tokens per line |
|---|---|---|
| `hashline` | `42nd\|function hi() {` | ~1 token (bigram) |
| `replace` | `42: function hi() {` | 0 (standard line numbers) |

When the session is in `replace` mode, ReadFile should emit standard numbered
lines, not hashline-formatted output. This keeps the context window clean and
avoids confusing models with a format they won't use for edits.

The `hasEditTool` flag in oh-my-pi's ToolSession controls this — set it based
on the active edit mode, not just whether EditTool exists.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Bun migration breaks existing functionality | Low | High | Bun's Node compat covers all APIs used; smoke test in Phase 0 |
| Rust N-API binary not available for target platform | Low | High | Verify in Phase 1; fall back to pure-TS implementations |
| oh-my-pi API surface changes upstream | Medium | Medium | Vendor the source; pin to a specific commit |
| Hashline format confuses smaller models | Medium | Medium | Per-model defaults + adaptive fallback (see above) |
| Token overhead from hashline anchors | Low | Low | ~1 token/line; disable for replace mode |
| ToolSession adapter is complex | Medium | Low | oh-my-pi's ToolSession is well-documented; start with minimal surface |
| Delegated round-trip latency vs native | Low | Low | In-process dispatch; no HTTP. Rust addon makes it faster than current native |
| Gemma 4 anchor hallucination rate too high | Medium | Low | Auto-fallback to replace; telemetry informs defaults |

---

## What This Plan Does NOT Change

- The AILANG language runtime (`ailang/`)
- The JSONL protocol between runtime and frontend
- The agent loop structure in `rpc.ail`
- Tool parsing in `parse.ail`
- BashExec / RunTests execution
- The extension system
- Provider/model handling
- The trajectory cache mechanism

**Note:** Phase 0 migrates the JavaScript runtime from Node.js to Bun. This
changes the execution environment but not the TypeScript source code — all
imports, APIs, and behavior remain identical.

---

## Open Questions

1. **Vendor or depend?** Vendoring gives control but means manual sync. npm dep
   means automatic updates but coupling to oh-my-pi's release schedule. Leaning
   vendor given that we only need ~4 tool classes + the edit engine.

2. ~~**Hashline as default or opt-in?**~~ **Resolved:** per-model defaults with
   adaptive fallback. See "Edit Mode Strategy" section above. Frontier models
   get hashline by default, small/open models get replace, mid-tier gets auto.

3. ~~**Edit mode per model?**~~ **Resolved:** yes, keyed off model string with
   `EDIT_MODE` env var override. Gemma 4 gets specific investigation in Phase 4.

4. **Rust addon licensing?** Verify oh-my-pi's license permits vendoring the
   Rust N-API binary in Motoko's distribution.

5. ~~**Bun vs Node?**~~ **Resolved:** Phase 0 migrates Motoko to Bun, eliminating
   the compatibility gap. `Bun.hash.xxHash32` and other Bun-specific APIs in
   oh-my-pi's tool code work natively — no shimming or hash-compatibility testing
   needed.

6. **Gemma 4 anchor format variant?** If Gemma 4 testing in Phase 4 shows
   high anchor hallucination but good line-number accuracy, consider a
   simplified format (line numbers only, no bigram) as a Gemma-specific mode.
   This loses staleness detection but keeps structured addressing.
