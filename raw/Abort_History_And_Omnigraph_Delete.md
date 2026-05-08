# Plan: Preserve in-flight history on abort + enable Omnigraph deletion

## Background

A live session exposed two coupled defects (transcript: 2026-04-25 12:00–12:08, model gemini-style, omnigraph extension loaded):

1. The user asked Motoko to clean PoC test data from Omnigraph. The agent found no delete tool in the omnigraph extension, fell back to guessing shell tool names (`execute_shell`, `execute_command`, `read_file`, …), and spun in a single LLM stream until aborted.
2. After the abort, the agent could not explain what had been attempted ("I don't have access to your previous command history"). That answer is technically correct: the abort path discards the in-flight assistant turn.

Defect 1 is a missing capability + missing prompt guidance. Defect 2 is a state-threading bug in `src/core/rpc.ail`. They are independent and should ship together so the next "clean up Omnigraph" interaction works end to end and is debuggable if it doesn't.

## Goals

- An abort never erases the assistant content (and any tool results already collected) for the in-flight turn.
- The model can delete decisions, components, and edges from Omnigraph using the existing `OmnigraphMutate` tool, without inventing tools or shelling out.
- The model is told the cleanup workflow (branch → delete edges → delete nodes → merge) explicitly in the system prompt.
- A safety rail prevents a bulk delete from wiping `main` data accidentally.

## Non-goals

- No new tool wrappers in the omnigraph extension. The CLI's `change` subcommand already runs `delete` queries; `OmnigraphMutate` is a thin pass-through and stays as is.
- No changes to streaming or to the abort signal pathway (Ctrl+C / `/abort`). The fix only touches what gets persisted on the AILANG side once the abort is observed.
- No TypeScript frontend changes. `runtime-process.ts` and `ui.ts` are untouched. Stated explicitly so a reader doesn't go hunting.

---

## Patch 1 — preserve in-flight state on `DelegatedAborted`

**Files:** `src/core/rpc.ail`

### Scope

The only buggy site is `DelegatedAborted` inside the inline `wait_for_tool_results` match in `run_hybrid_step` at `rpc.ail:982-988`. Everywhere else is fine:

- `rpc_loop`'s `drained.aborted` branch (`rpc.ail:1106-1111`) returns `drained.state` *before* the LLM call for this iteration. No assistant message exists yet, so nothing is lost. **Keep as is.**
- `run_legacy_step` calls `exec_in` synchronously and never enters `wait_for_tool_results`. **No change.**
- `DelegatedReceived` and `DelegatedTimedOut` (`rpc.ail:956-981`) already preserve everything. They are the model the abort branch should mirror.

### Current code (`rpc.ail:982-988`)

```ailang
DelegatedAborted(ab) => {
  let _ = emit(encode(jo([
    kv("type", js("error")),
    kv("message", js("aborted"))
  ])));
  ab.state
}
```

`ab.state.msgs` is the snapshot from before this step's LLM call. It loses: (a) the assistant response (`msgs1` in scope), (b) any native tool results just computed (`native_results_with_denied` in scope), (c) any extension tool results (`ext_results` in scope).

### Replacement — mirror the success branch

Build `obs_text` from completed results, plus a per-tool aborted marker for each delegated call still in flight. Add `delegated_aborted_results` next to `delegated_timeout_results` (`rpc.ail:392-402`):

```ailang
func delegated_aborted_results(calls: [ToolCallEnvelope]) -> [ToolResultItem] {
  match calls {
    [] => [],
    c :: rest =>
      ToolErrorResult({
        id: tool_call_id(c),
        tool: "delegated",
        message: "aborted"
      }) :: delegated_aborted_results(rest)
  }
}
```

Per-tool message is terse (`"aborted"`); the trailing turn-level marker carries the explanation. Two strings, one source of truth each — no drift risk.

Replacement at `rpc.ail:982-988`:

```ailang
DelegatedAborted(ab) => {
  let _ = emit(encode(jo([
    kv("type", js("error")),
    kv("message", js("aborted"))
  ])));
  let aborted_results = delegated_aborted_results(by_backend.delegated);
  let all_results = concat(native_results_with_denied, aborted_results);
  let obs_text = "${warnings_prefix(parsed.warnings)}${fmt_tool_obs(all_results)}${fmt_ext_tool_obs(ext_results)}\n\n[turn aborted by user before all tool results returned]";
  let msgs2 = msgs1 ++ [{ role: "user", content: obs_text }];
  {
    env_url: ab.state.env_url,
    msgs:    msgs2,
    cwd:     ab.state.cwd,
    step:    state.step,        -- do NOT increment; conversation_loop will +1 when the next user_message arrives (rpc.ail:1170)
    inbox:   ab.state.inbox
  }
}
```

**Why no `+1` here.** The success branches at `rpc.ail:943/965/978` increment because they recurse back into `rpc_loop` for more work in the *same* turn. The abort branch ends the turn — `conversation_loop` then receives the next `user_message` and applies its own `state.step + 1` (`rpc.ail:1170`). Adding `+1` here too would double-count. Keeping the step flat means the aborted turn still occupies one logical step (the user prompt + assistant response that was emitted) and the next user prompt advances by exactly one.

The `[turn aborted …]` marker is included by default and inline, not gated. The model has to know the previous turn was cut; without it, it would treat the truncated tool output as authoritative. If a model tokenizes the marker badly we revisit; adding a flag now is premature.

### Tests

- AILANG-side: extend an existing rpc unit test (or add one) that drives `wait_for_tool_results` to `DelegatedAborted` and asserts the returned `AgentState` contains an assistant `Msg` followed by a user `Msg` whose content ends with the `[turn aborted …]` marker.
- TS-side: add a `runtime-process.stream-protocol.test.ts` scenario — send `user_message` → wait for `tool_calls` event → send `abort` → send a second `user_message` → on the next `thinking` event (the LLM input for turn 2), inspect its `text` field and assert it contains both the assistant text emitted in turn 1 and the substring `"[turn aborted by user before all tool results returned]"`. (The `thinking` event's payload is the response, but its preceding LLM input is what's logged in `trace.jsonl` under the `messages` field of the next API call — assert against whichever is more accessible to the test harness; both reflect the same prompt history.)
- Manual reproduction: replay the original transcript flow (cleanup → abort → "what failed?") and confirm the agent references its own previous attempt.

### Blast radius / rollback

One return value in one branch, plus one new helper. Land as a single commit. Revert is `git revert`.

---

## Omnigraph fixes (supersede the generic "patch 2")

The earlier "patch 2" idea was to enumerate tools and tell the model "no Delete exists." The three items below remove the missing capability instead, so the failure mode that triggered the loop becomes impossible.

### Fix A — add delete query templates

**Files:** `omnigraph/mutations/decisions.gq`, `omnigraph/mutations/components.gq`

Append the following.

`decisions.gq`:
```graphql
query delete_decision($slug: String)
  @description("Delete a Decision by slug")
  @instruction("Use on a feature branch to remove an obsolete or PoC decision; merge to main when reviewed")
{
  delete Decision
  where slug = $slug
}
```

`components.gq`:
```graphql
query delete_component($slug: String)
  @description("Delete a Component by slug")
  @instruction("Only safe after all DependsOn/Governs edges referencing this slug are removed first")
{
  delete Component
  where slug = $slug
}

query delete_dependency($from_slug: String, $to_slug: String)
  @description("Delete a DependsOn edge")
{
  delete DependsOn
  where from = $from_slug and to = $to_slug
}

query delete_governs($decision_slug: String, $component_slug: String)
  @description("Delete a Governs edge")
{
  delete Governs
  where from = $decision_slug and to = $component_slug
}
```

### Verification matrix (every query must lint clean before merge)

| Query name | File | `omnigraph query lint` exit code | Notes |
|---|---|---|---|
| `delete_decision` | `decisions.gq` | 0 expected | Already proven against single-predicate `where slug = $slug` |
| `delete_component` | `components.gq` | 0 expected | Same shape as above |
| `delete_dependency` | `components.gq` | **Unverified** | Two-predicate `where … and …` — confirm the dialect supports `and` |
| `delete_governs` | `components.gq` | **Unverified** | Same |

Fallback if the dialect rejects `and`: split the edge delete into either (a) a query taking a single composite key, or (b) a sequence of two single-predicate `delete … where from = $a` / `delete … where to = $b` filters joined by query composition. Decide by trial during implementation; do not merge until each line of the matrix is filled with a real exit code from a local run.

### Fix B — document the cleanup workflow in `omnigraph/AGENT_PROMPT.md`

The omnigraph extension reads this file at register time (`prompts.ail::load_agent_prompt` checks `${cwd}/omnigraph/AGENT_PROMPT.md` first) and appends it to the system prompt. **Insert the new section directly after the existing description of `OmnigraphMutate`** (so the workflow appears alongside the tool that implements it, not buried at the bottom of the file):

```markdown
## Deleting graph data

There is no dedicated delete tool. Use `OmnigraphMutate` with the
`delete_*` queries in `mutations/`. The workflow:

1. **Branch.** Direct mutations on `main` are denied. Create a working
   branch first:
   `OmnigraphBranch` with `action: "create"`, `name: "cleanup/<slug>"`.
2. **Delete edges before nodes.** A node with referencing edges may
   fail to delete. For each target slug, first run `delete_dependency`
   and `delete_governs` for every edge that references it, then
   `delete_decision` / `delete_component`.
3. **Verify.** `OmnigraphRead list_decisions` (or `list_components`)
   on the working branch — the targets should be gone.
4. **Merge.** `OmnigraphBranch` with `action: "merge"`,
   `name: "cleanup/<slug>"`, `into: "main"`.

Available delete query names (file → name): `mutations/decisions.gq`
→ `delete_decision`; `mutations/components.gq` → `delete_component`,
`delete_dependency`, `delete_governs`.
```

**Restart required.** `register()` runs in `init_runtime` once per `main()`; the prompt is read there and frozen for the session. Operators must restart the runtime (next `make run`) for this change to be visible. Tests against this fix MUST start a fresh runtime — testing against an already-running session will appear to fail for the wrong reason.

### Fix C — bulk delete + naming-based guardrail

**Files:** `omnigraph/mutations/decisions.gq`, `omnigraph/mutations/components.gq`, `src/core/ext/omnigraph/guardrail.ail`, `src/core/ext/omnigraph/omnigraph.ail`, `src/core/ext/omnigraph/omnigraph_test.ail`

**Bulk queries.** Append parameter-less wipe queries:

```graphql
query delete_all_decisions()
  @description("Delete every Decision node on this branch — DESTRUCTIVE")
  @instruction("Only on a branch named wipe/* or cleanup/*; never run unscoped")
{
  delete Decision
}
```
Plus `delete_all_components`, `delete_all_dependencies`, `delete_all_governs`. Verify each lints cleanly **and** that `omnigraph change --params "{}" --name delete_all_decisions --branch cleanup/test --query mutations/decisions.gq --json` runs end-to-end on a throwaway branch (the parameter-less form is unproven against this CLI build).

**Guardrail integration.** `guardrail.ail` currently exports one bool-returning predicate, called from `omnigraph.ail::on_tool_policy:93` as a single `if`. Chosen approach: **one fused predicate** returning a deny reason. Reason for choosing this over a sibling predicate: a single `Option[string]` return type means `on_tool_policy` stays a one-line `match`; adding rules later is one extra `else if` inside `denied_mutation_reason` instead of more `if/else` chains at every call site.

Rename `is_main_branch_mutation` → `denied_mutation_reason: ToolCallEnvelope -> Option[string]`. Update `on_tool_policy`:

```ailang
match denied_mutation_reason(canonical) {
  Some(msg) => Deny(msg),
  None => NoOpinion
}
```

**Call sites that move with the rename** (full change set is two source files plus tests):
- `src/core/ext/omnigraph/omnigraph.ail:93` — the `if is_main_branch_mutation(...)` call.
- `src/core/ext/omnigraph/omnigraph_test.ail:64,71,106` — three test cases reference the predicate by name.

**Required new imports** (in `guardrail.ail`):
- `import std/string (startsWith)` — currently absent.
- `import std/option (Option, Some, None)` — needed for the new return type.

**Helper sharing.** The bulk-wipe check needs to read `name` and `branch` from `call.arguments`. The existing `arg_string` helper lives in `omnigraph.ail:24`. Hoist it into a new `src/core/ext/omnigraph/args.ail` module exporting `arg_string`, and import it from both files. (Duplicating the four lines into `guardrail.ail` is the cheaper alternative if the hoist proves noisy; pick at implementation.)

**Predicate body** with **fixed rule order — main-branch check first, bulk-wipe second**:

```ailang
export func denied_mutation_reason(call: ToolCallEnvelope) -> Option[string] {
  if call.tool != "OmnigraphMutate" then None
  else {
    let branch = arg_string(call.arguments, "branch", "");
    let name   = arg_string(call.arguments, "name", "");
    -- Rule 1 (highest priority): never write to main directly.
    if branch == "main" then
      Some("refuses to write to main directly; create a feature branch first")
    -- Rule 2: bulk wipe queries require an explicitly-named cleanup or wipe branch.
    else if startsWith(name, "delete_all_") &&
            not (startsWith(branch, "wipe/") || startsWith(branch, "cleanup/")) then
      Some("bulk wipe queries (delete_all_*) are only allowed on wipe/* or cleanup/* branches")
    else None
  }
}
```

The fixed order makes the test matrix below deterministic — bulk wipe attempted on `main` always returns the main-branch message.

**No `provided_tools()` change.** Bulk delete queries are invoked through the existing `OmnigraphMutate` tool by passing the corresponding `name` (e.g. `delete_all_decisions`); they are not new tools and `omnigraph.ail:50` does not need an entry.

**Tests** (`omnigraph_test.ail`):

| Scenario | `name` | `branch` | Expected |
|---|---|---|---|
| Single-slug delete on cleanup branch | `delete_decision` | `cleanup/poc` | NoOpinion (allowed) |
| Single-slug delete on main | `delete_decision` | `main` | Deny (existing main rule) |
| Bulk wipe on feature branch | `delete_all_decisions` | `feature/x` | Deny (new bulk rule) |
| Bulk wipe on cleanup branch | `delete_all_decisions` | `cleanup/poc` | NoOpinion (allowed) |
| Bulk wipe on wipe branch | `delete_all_decisions` | `wipe/poc` | NoOpinion (allowed) |
| Bulk wipe on main | `delete_all_decisions` | `main` | Deny with the **main-branch message** (rule 1 fires first, per fixed order above) |

The deny-path tests are non-negotiable. The guardrail is the only safety net for bulk delete; a typo in the prefix check means data loss.

### Blast radius / rollback for Fixes A/B/C

- Fix A is additive (new files / new query blocks), no live behavior change until something invokes them. Trivially revertible.
- Fix B is a markdown edit, takes effect on next runtime spawn. Revertible.
- Fix C introduces destructive capability. Land Fix C as one atomic commit (queries + guardrail + tests). Before first real use against any non-throwaway repo, run `omnigraph export --json > backup.jsonl` so a bad merge is recoverable. Document this in the merge note.

---

## Order of work

Two independent streams:

- **Omnigraph stream (sequential):** Fix A (templates + lint matrix, zero-risk, unblocks manual cleanup) → Fix B (AGENT_PROMPT.md, ships the workflow to the model) → Fix C (bulk + guardrail, last because it adds destructive capability that's only safe once the workflow doc is in).
- **Runtime stream (independent):** Patch 1 (abort persistence). Can land any time — no dependency on the omnigraph stream and no shared files.

## How we'll know it worked

Replay the original transcript against a freshly restarted runtime (Fix B requires restart):

- "We need to clean Omnigraph. All of the above is PoC test data" → agent emits `OmnigraphBranch create cleanup/poc`, then a sequence of `OmnigraphMutate` calls referencing the new `delete_*` queries (edges before nodes), then `OmnigraphBranch merge cleanup/poc into main`. No tool-name guessing, no shell fallback.
- If the user aborts mid-cleanup and then asks "what failed?", the agent's response references its own previous attempt, the specific `OmnigraphMutate` calls it had emitted, and the `[turn aborted by user …]` marker.
- Bulk-wipe attempted on `feature/x` returns the new deny message verbatim, with no CLI invocation reaching the omnigraph binary.
