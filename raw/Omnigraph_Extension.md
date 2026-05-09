# Omnigraph Extension — Plan

**Date:** 2026-04-23
**Status:** Draft
**Suggested branch:** `Omnigraph_Extension`

**Related context:**
- `.agent/research/003_Omnigraph/Omnigraph_PoC_Plan.md` — Pi-targeted PoC (source material)
- `.agent/research/003_Omnigraph/Omnigraph_PoC_Implementation.md` — what actually shipped; syntax findings + bug fixes
- `.agent/research/003_Omnigraph/index.ts` — reference Pi extension (source material)
- `.agent/research/003_Omnigraph/Omnigraph_Pi_transcript.md` — design rationale
- `.agent/research/003_Omnigraph/Omnigraph_Possibilities.md` — forward-looking use cases
- `.agent/plans/Compose_As_Extension.md` — precedent for porting a Pi-shaped integration into `src/core/ext/`

---

## Goal

Port the Pi-targeted Omnigraph PoC (`.agent/research/003_Omnigraph/index.ts`) into a self-contained Motoko extension under `src/core/ext/omnigraph/`, using the established X1 hook surface (`on_build_system_prompt`, `on_tool_policy`, `on_tool_handle`). The agent gets four typed tools — `omnigraph_read`, `omnigraph_mutate`, `omnigraph_branch`, `omnigraph_status` — backed by the Omnigraph CLI, with a `main`-branch write guardrail and automatic injection of `omnigraph/AGENT_PROMPT.md` into the system prompt.

## Non-goals

- Omnigraph HTTP server deployment. CLI-only for now.
- Vector search / embeddings. Text queries prove the contract.
- Obsidian / Dataview bridge. Separate concern.
- Rewriting Compose or touching any other existing extension.
- Persisting Omnigraph state in git. `omnigraph/repo.omni/` is gitignored per the PoC plan.
- TUI card renderers for Omnigraph tool calls. The existing generic tool-call rendering is sufficient for this plan.
- Removing the Pi extension. `.omp/extensions/pi-omnigraph/` stays — this is a parallel port for Motoko users, not a replacement.

## Assumptions

Flip any of these before Phase 0 if wrong.

1. **Graph root:** `omnigraph/` per user decision. The Pi extension uses `.omnigraph/` — the AILANG port intentionally diverges. Extension resolves `<ctx.cwd>/omnigraph` at dispatch time.
2. **Extension id / activation:** `omnigraph`. Enable via `CORE_EXT_ORDER=omnigraph` (or `CORE_EXT_ORDER=compose,omnigraph` alongside Compose).
3. **Toolchain install is Phase 0 of this plan** (see below). Rust + Omnigraph CLI must be built from source — no arm64 Linux binary exists. Recipe codified in `Omnigraph_PoC_Implementation.md`.
4. **CLI is authoritative.** No HTTP client in this plan. If a future phase adds `Net`-based calls, it's additive.
5. **`AGENT_PROMPT.md` is a first-class deliverable** (per PoC plan). The extension reads it via `std/fs.readFile`; if absent, `on_build_system_prompt` returns an empty `PromptPatch` silently.
6. **Main-branch guardrail lives in `on_tool_policy`**, not inline in the handler. Cleaner separation; matches the hook's purpose; keeps `on_tool_handle` focused on execution.
7. **Event-name parity with Pi extension is not required.** Motoko emits generic tool-call events; no `omnigraph_*` named events in this plan.

---

## Target state

```
src/core/
  ext/
    types.ail              [MODIFIED]  PureExt/EffectExt add OmnigraphPure/OmnigraphEffect
    registry.ail           [MODIFIED]  parse_tokens handles "omnigraph"; debug_pure_names matches new variant
    runtime.ail            [MODIFIED]  match-arm additions in every dispatch; ext_provided_tools returns omnigraph tools
    omnigraph/             [NEW]
      omnigraph.ail        -- entry: hook bodies (prompt / policy / handle)
      types.ail            -- OmnigraphReadReq, OmnigraphMutateReq, OmnigraphBranchReq, OmnigraphStatusReq
      exec.ail             -- spawn helper wrapping std/process.exec with cwd + timeout + JSON fallback parse
      guardrail.ail        -- main-branch detector for on_tool_policy
      prompts.ail          -- AGENT_PROMPT.md reader, PromptPatch builder
      omnigraph_test.ail   -- inline + fixture tests
  types.ail                [MODIFIED]  ToolCallReq adds four variants; ToolResultItem adds OmnigraphResult

omnigraph/                 [NEW — per PoC plan]
  repo.omni/               -- Omnigraph repository (gitignored)
  schema.pg
  queries/*.gq
  mutations/*.gq
  seed/data.jsonl
  omnigraph.yaml
  AGENT_PROMPT.md
  validate.sh
  .gitignore               -- repo.omni/
```

---

## Phase 0 — Toolchain install

No published arm64 Linux binary for Omnigraph exists; source build is the only path. Recipe is now known and documented (`Omnigraph_PoC_Implementation.md` §Toolchain).

### Tasks

- **0.1** Install apt prerequisites: `gcc`, `protobuf-compiler` (build deps for the Rust workspace).
- **0.2** Install Rust via `rustup` — stable channel, host-detected target (rustup auto-detects x86_64 / aarch64). Persist `~/.cargo` so incremental build cache survives container restarts.
- **0.3** Clone Omnigraph source to a persistent location (e.g. `/opt/omnigraph-src`). Persistent location matters: first build is ~10–15 min; subsequent rebuilds with cache are seconds.
- **0.4** Build: `cargo build --release --locked -p omnigraph-cli -p omnigraph-server`.
- **0.5** Install the resulting `omnigraph` binary to `~/.local/bin/`. Confirm `~/.local/bin` is on `PATH`.
- **0.6** Extend `scripts/install-prerequisites.sh` with an `install_omnigraph()` function that runs steps 0.1–0.5 idempotently (skip if `omnigraph version` already succeeds). Gate behind a flag (`--with-omnigraph`) so existing users aren't forced into a 15-min build.

### Exit criteria

- `omnigraph version` reports ≥ 0.3.0 from a fresh shell. Minimum pinned explicitly so future CLI breaks surface during install rather than at first use.
- `scripts/install-prerequisites.sh --with-omnigraph` succeeds idempotently on a fresh container.
- README section added documenting the install path and the `--with-omnigraph` flag.

---

## Phase 1 — Graph scaffold (no AILANG code)

Port the PoC plan's Phases 1–2 verbatim. Detailed in `Omnigraph_PoC_Plan.md`; syntax gotchas captured in `Omnigraph_PoC_Implementation.md`.

### Tasks

- **1.1** Create `omnigraph/` layout: `schema.pg`, `queries/`, `mutations/`, `seed/`, `omnigraph.yaml`, `.gitignore` (contains `repo.omni/`).
- **1.2** Write `schema.pg` (Decision, Component, DependsOn, Governs — per PoC).
- **1.3** Write `queries/*.gq` and `mutations/*.gq` with `@description` / `@instruction` annotations. Honour the syntax rules surfaced during PoC implementation:
    - Mutation files use the `query` keyword, **not** `mutation` — the body content determines the kind.
    - `where` predicate uses single `=`, not `==`.
    - Match/return must be wrapped: `match { ... } return { ... }`.
    - Filter bindings prefer `$d: Decision { status: $status }` over `$d.status == $status` in the match block.
    - `delete` syntax is bare `delete TypeName where field = $val` — no `match` binding.
- **1.4** Write `omnigraph.yaml` with a single `local` graph pointing at `./repo.omni`. All CLI commands run with `cwd=omnigraph/`; URI resolves from this config, never from a positional arg.
- **1.5** Write `seed/data.jsonl` with real Zeus-style decisions from `.agent/plans/` and `.agent/research/`. Target: ≥4 decisions, ≥8 components, ≥4 Governs edges, ≥6 DependsOn edges (match PoC footprint).
- **1.6** Write `AGENT_PROMPT.md` (schema summary + query/mutation catalog + usage rules — branch discipline, verification after mutation, param passing, branch-naming convention, enum values, slug immutability).
- **1.7** Write `validate.sh` end-to-end script (init, load, read, branch, mutate, merge, delete-branch). Idempotent — guards against leftover test branches.

### Exit criteria

- `omnigraph/validate.sh` exits 0 with no manual intervention.
- `omnigraph read --query queries/decisions.gq --name list_decisions --json` returns seed rows.
- `omnigraph branch create --from main <name> && omnigraph change ... --branch <name> && omnigraph branch merge <name> --into main` round-trips.

---

## Phase 2 — Tool types and exec helper (no dispatch yet)

Add the request/result types and the thin CLI exec wrapper. No wiring into `runtime.ail` yet — this phase is type-checkable in isolation.

**Heads-up:** this is the longest and riskiest single chunk. Adding variants to `ToolCallReq` / `ToolResultItem` ripples through every exhaustive `match` on those types across `src/core/`. Expect fallout proportional to the number of existing match sites.

### Tasks

- **2.0** Grep for every `match` site on `ToolCallReq` and `ToolResultItem` in `src/core/` (and anywhere else in the codebase). List them. This becomes the work-list for 2.6; doing it up front removes surprise.
- **2.1** `src/core/ext/omnigraph/types.ail`: `OmnigraphReadReq`, `OmnigraphMutateReq`, `OmnigraphBranchReq` (with `action: string`, `name: Option[string]`, `from: Option[string]`, `into: Option[string]`), `OmnigraphStatusReq`. Mirror the TypeBox shapes in `index.ts` exactly. Note: `OmnigraphStatusReq` carries only `id: string` for telemetry — Pi's `StatusParams = Type.Object({})` is intentionally empty.
- **2.2** Extend `src/core/types.ail::ToolCallReq` with four new variants: `OmnigraphRead(OmnigraphReadReq)`, `OmnigraphMutate(OmnigraphMutateReq)`, `OmnigraphBranch(OmnigraphBranchReq)`, `OmnigraphStatus(OmnigraphStatusReq)`.
- **2.3** Extend `src/core/types.ail::ToolResultItem` with `OmnigraphResult({ id: string, tool: string, stdout: string, stderr: string, exit_code: int, json_metadata: string })`. `json_metadata` holds the JSON payload produced by the output-parsing rule defined in 2.4 (try-JSON-decode, wrap raw on failure), serialized back to string for transport.
- **2.4** `src/core/ext/omnigraph/exec.ail::run_omnigraph(args, cwd, timeout_ms) -> OmnigraphResult ! {Process, IO, Clock}`: spawn `omnigraph` via `std/process.exec`, collect stdout/stderr, apply the Pi extension's `parseOutput` rule (try `std/json.decode`; on failure wrap as `{"output": <raw>}`), return populated `OmnigraphResult`. Default `timeout_ms = 30_000` (matches Pi extension's per-tool timeout). Arg ordering for `branch create` matches the fixed Pi extension: `["branch", "create", "--from", from, name, "--json"]` (flags before positional).
- **2.5** **URI handling:** Never append a positional `repo.omni` to any arg array. The Pi extension shipped this bug (caught in post-implementation test 2026-04-22) — `branch create|list|merge|delete` subcommands reject positional URIs and only accept `--uri`. Since `omnigraph.yaml` in `cwd` resolves the URI uniformly for every subcommand, the AILANG port does not pass `--uri` anywhere. Document this in `exec.ail` as a comment referencing the bug in `Omnigraph_PoC_Implementation.md` §Post-implementation test.
- **2.6** Propagate variants through every existing consumer-side `match` on `ToolCallReq` / `ToolResultItem` (the list produced in 2.0). This is distinct from the **extension-side** dispatch arms added in Phase 3.3, which operate on `PureExt` / `EffectExt` — different hierarchy, different files. `ailang check src/core/rpc.ail` + `ailang check src/core/ext/runtime.ail` must pass.

### Exit criteria

- `ailang check src/core/types.ail` clean.
- `ailang check src/core/ext/omnigraph/types.ail` and `exec.ail` clean.
- `ailang test src/core/ext/omnigraph/*` passes (exec helper tested via a fixture binary or stub; see Phase 5).
- Every `match` on `ToolCallReq` or `ToolResultItem` in the existing codebase handles the new variants (exhaustiveness checker enforces this).

---

## Phase 3 — Extension wire-up

Register `omnigraph` in the X1 registry + dispatch.

### Tasks

- **3.0** **Cache `AGENT_PROMPT.md` at extension load.** The pure-hook dispatcher `fold_prompt_pure` is declared `! {IO, Clock}` — no `FS`. Rather than widen the substrate, read the file once in `init_runtime` (extend its effect set from `! {Env}` to `! {Env, FS}`) and cache the content on a new `ExtRuntime.omnigraph_prompt: string` field. Empty string when absent. The pure hook in 3.4 returns the cached value. This keeps `fold_prompt_pure` pure-ish and avoids rippling `FS` into every prompt hook.
- **3.1** `src/core/ext/types.ail`: add `OmnigraphPure(string)` to `PureExt`, `OmnigraphEffect(string)` to `EffectExt`. Add `omnigraph_prompt: string` to `ExtRuntime`.
- **3.2** `src/core/ext/registry.ail::parse_tokens`: add `"omnigraph"` branch producing both variants with id `"omnigraph#${idx}"`. Update `pure_names` match arm.
- **3.3** `src/core/ext/runtime.ail`: add `OmnigraphPure(_)` / `OmnigraphEffect(_)` arms in every match — `fold_prompt_pure`, `fold_budget_pure`, `decide_one_policy`, `dispatch_handle_from`, `dispatch_intercept_from`, `decide_one_finalize`. (`ext_provided_tools` carved out — specified separately in 3.5.)
- **3.4** `src/core/ext/omnigraph/omnigraph.ail`: entry module exporting the hook bodies called from `runtime.ail`. Signatures:
    - `on_build_system_prompt(rt: ExtRuntime, ctx: ExtCtx) -> PromptPatch` — returns `{prepend: [], append: [rt.omnigraph_prompt]}` when non-empty; empty patch otherwise. Pure (cache populated in 3.0).
    - `on_tool_policy(ctx: ExtCtx, call: ToolCallReq) -> ToolPolicyDecision` — `OmnigraphMutate` with `branch == "main"` → `Deny("refuses to write to main directly; create a feature branch first")`; everything else → `NoOpinion`.
    - `on_tool_handle(rt: ExtRuntime, ctx: ExtCtx, call: ToolCallReq) -> ToolHandleDecision ! {Process, IO, Clock}` — dispatch on the four variants into `exec.run_omnigraph` with appropriate arg arrays (exact ordering from the **fixed** `index.ts`, no positional URI). Return `Handled(OmnigraphResult(...))`. Non-omnigraph calls → `Delegate`.
- **3.5** `ext_provided_tools(OmnigraphEffect(_))` returns `["OmnigraphRead", "OmnigraphMutate", "OmnigraphBranch", "OmnigraphStatus"]`. `tool_name(call)` gets four new arms.
- **3.6** Thread the extension through any effect-set or registration checks so `CORE_EXT_ORDER=omnigraph` loads cleanly.

### Exit criteria

- `ailang test src/core/ext/registry.ail` — existing tests still pass; add a test confirming `parse_core_ext_order("omnigraph")` produces size-2 registry with matching ids.
- `ailang test src/core/ext/runtime.ail` (if present) — clean.
- `make run` boots with `CORE_EXT_ORDER=omnigraph` and no error in stderr.
- Manual smoke: model message proposing `omnigraph_read` → round-trips to CLI → returns JSON to the model.

---

## Phase 4 — Prompt injection + guardrail verification

Prove the two behavioral contracts end to end: (a) the agent sees the catalog, (b) `main`-branch writes are blocked.

### Tasks

- **4.1** Confirm `omnigraph/AGENT_PROMPT.md` (from Phase 1) lands in the first turn's system prompt by checking `trace.jsonl`.
- **4.2** Positive trajectory: task = "Insert a new Decision for the Omnigraph extension itself on a new branch, then query to confirm it's visible, then merge back to main." Expected sequence: `omnigraph_branch create` → `omnigraph_mutate` → `omnigraph_read` (verify) → `omnigraph_branch merge` → `omnigraph_branch delete`.
- **4.3** Negative trajectory: task = "Insert a decision directly on main." Expected behavior: `on_tool_policy` returns `Deny`; agent receives the deny message without the CLI being invoked.
- **4.4** Exercise the four branch subcommand arg arrays end-to-end **through the AILANG extension code path** (not via `validate.sh` or the stub binary, which only cover the shell script and the unit seam respectively). Catches any AILANG-side arg-array drift that would otherwise only surface in production.

### Exit criteria

- Positive trajectory completes within the 50-step budget.
- Negative trajectory surfaces the deny message to the model without calling the CLI.
- `AGENT_PROMPT.md` content appears verbatim in `trace.jsonl` system-prompt field on every turn.

---

## Phase 5 — Test harness

### Tasks

- **5.1** Unit tests for the output-parsing helper in `exec.ail` (JSON, non-JSON, empty, whitespace).
- **5.2** Unit tests for the guardrail predicate: `is_main_branch_mutation(OmnigraphMutate{...}) -> bool`.
- **5.3** Integration test for `on_tool_handle`: use a stub `omnigraph` binary on `PATH` (small shell script under `tests/fixtures/bin/`) that echoes a canned JSON response. Test confirms the handler returns a well-formed `OmnigraphResult` and that no positional `repo.omni` appears in the spawned argv.
- **5.4** Registry test: `parse_core_ext_order("omnigraph")`, `parse_core_ext_order("compose,omnigraph")` — confirm both activation orders work.
- **5.5** `on_build_system_prompt` test: two cases — (a) `AGENT_PROMPT.md` present → returned `PromptPatch.append` contains the file content; (b) file absent → empty patch. Exercises the 3.0 caching path.

### Exit criteria

- `ailang test src/core/ext/omnigraph/*` passes end-to-end, no real CLI calls.
- Stub-binary integration test runs in CI-equivalent mode (no Rust toolchain required to build).

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `omnigraph` CLI flag ordering differs between Pi extension and actual CLI behavior | Low (now known) | Phase 1.7's `validate.sh` exercises every command shape; the two known gotchas (positional `repo.omni` rejected by `branch`, `delete` bare syntax) are called out explicitly in Phase 1 and Phase 2 |
| Rust/protobuf/cargo build fails on fresh container | Medium | Phase 0 codifies the exact apt packages and rustup invocation that shipped; `--with-omnigraph` flag makes it opt-in |
| First `cargo build --release` takes 10–15 min and may time out agent sessions | Medium | Persistent `/opt/omnigraph-src` + `~/.cargo` survive container restarts; subsequent builds are seconds |
| `ToolCallReq` variant additions ripple across many files (exhaustiveness) | Medium | Expected; single port session catches every match via `ailang check` |
| `std/process.exec` semantics differ from Node `spawn` (timeout, SIGTERM, PATH handling) | Medium | Phase 5.3 stub-binary test exercises the shape; document deltas |
| `AGENT_PROMPT.md` bloats the system prompt on every turn | Low | Pi extension has the same property; keep the file compact; revisit if token budget becomes a problem |
| Omnigraph schema changes invalidate seed data | Medium | Re-init acceptable per PoC plan; document migration in README |
| Main-branch guardrail in `on_tool_policy` gets bypassed by direct `BashExec` to `omnigraph change` | Medium | Acceptable residual for Phase 1–3; document it. Tightening requires parsing `BashExec` args — deferred |

## Rollback

Phases 0, 1, 4, 5 are cleanly additive — revert the branch, drop `CORE_EXT_ORDER=omnigraph` from whatever environment enables it, and the `omnigraph/` directory can stay (inert without the extension).

**Phase 2 is additive but downstream-coupled.** Adding variants to `ToolCallReq` / `ToolResultItem` ripples into every consumer match. Safe to land Phase 2 without Phase 3 (extension unused), but reverting Phase 2 after other work builds on the new variants is not free. Tag commit `pre-omnigraph-toolreq-landing` before merging Phase 2 for clean reset.

---

## Open questions

1. **Branch name** — `Omnigraph_Extension` acceptable?
2. **Activation default** — off by default (extension present but `CORE_EXT_ORDER` empty) vs on-by-default in `Makefile`'s `run` target? Default: off; opt-in per run.
3. **`OmnigraphResult.json_metadata` as string vs structured `Json`** — string is simplest and matches Pi extension's `JSON.stringify` envelope. Promoting to `std/json.Json` is easy later. Default: string.

## Future work (not in scope)

- Structured events (`omnigraph_read_result`, `omnigraph_mutate_result`) with TUI rendering.
- `Net`-based HTTP client to replace CLI shell-out when `omnigraph serve` is running.
- Cross-project graph mounting (per `Omnigraph_Possibilities.md` §6).
- `.agent/` ingestion tool that walks plans and auto-creates Decision nodes.
- Tighter `BashExec` guardrail that parses `omnigraph change --branch main` bypass attempts (currently documented residual).

---

## Verification checklist

- [ ] `omnigraph version` reports ≥ 0.3.0 from a fresh shell after `install-prerequisites.sh --with-omnigraph`.
- [ ] `omnigraph/validate.sh` exits 0 with no manual intervention.
- [ ] `ailang check` clean across `src/core/types.ail`, `src/core/rpc.ail`, `src/core/ext/runtime.ail`, and all `src/core/ext/omnigraph/*.ail`.
- [ ] `make run` with `CORE_EXT_ORDER=omnigraph` boots without error.
- [ ] `AGENT_PROMPT.md` content appears verbatim in `trace.jsonl` system-prompt field on the first turn.
- [ ] Positive trajectory (Phase 4.2) completes: branch create → mutate → read → merge → delete.
- [ ] Negative trajectory (Phase 4.3): `omnigraph_mutate` with `branch="main"` returns `Deny` without spawning the CLI.
- [ ] Stub-binary integration test (Phase 5.3) confirms no positional `repo.omni` in spawned argv.
- [ ] `parse_core_ext_order("compose,omnigraph")` registers both extensions in order.
