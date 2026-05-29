# Plan: `motoko_ext_autoresearch` — Autonomous Optimization Loop Extension

## Context

A general-purpose **auto-research extension** for Motoko — inspired by [pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) and [oh-my-pi's autoresearch](https://github.com/can1357/oh-my-pi/tree/main/packages/coding-agent/src/autoresearch) — that can autonomously run optimization loops against any objective. Example: "compact Motoko's codebase by mutating code." This is the foundation layer; recursive self-improvement of hooks (the Layer 2 research) becomes one *use case* of this extension, not the other way around.

### Reference Implementations

| Feature | pi-autoresearch | oh-my-pi | This plan |
|---------|----------------|----------|-----------|
| Persistence | JSONL files | SQLite (WAL mode) | DuckDB via `sunholo/duckdb@0.1.0` (spike-gated; `std/fs` JSONL fallback) |
| Scope enforcement | None | `scope_paths` + `off_limits` + flagging | `scope_paths` + `off_limits` + flagging |
| Git revert strategy | Full `git checkout -- .` | Selective (only run-modified paths) | Selective (only run-modified paths) |
| Segments | None | Multi-segment sessions | Multi-segment sessions |
| Structured metadata | None | `ASI key=value` parsing | `ASI key=value` parsing |
| Tools | 3 (init, run, log) | 4 (+update_notes) | 4 (+ar_notes) |
| Prompt phases | Single | Two-phase (setup + loop) | Static protocol (pure hook) + dynamic state injection (`on_pre_step`) |
| Branch management | None | Auto `autoresearch/<goal>-<date>` | Auto `autoresearch/<goal>-<date>` |
| Compaction survival | File reconstruction | DB + prompt injection | DuckDB reconstruction via `on_pre_step` |
| Solver gate | None | None (uses auto-resume) | `on_solver_candidate` → `ContinueWithFeedback` |

---

## Architecture Overview

The extension exposes **4 tools** (`ar_init`, `ar_run`, `ar_log`, `ar_notes`) and uses **4 hooks**.

> **ABI reality check** (verified against `sunholo/motoko_ext_abi@2.2.0` + AILANG 0.19.1 docs MCP). Two hooks are **pure** (no effect row) and therefore cannot read the DB or filesystem:
> - `on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision` — pure
> - `on_build_system_prompt: (ExtCtx) -> PromptPatch` — pure
>
> AILANG enforces effect discipline ("every side effect must be declared in the function signature"), so enforcement and dynamic prompt/state injection must live in the **effectful** hooks: `on_pre_step`, `on_tool_handle`, `on_solver_candidate` (all `! {IO, Process, FS, …}`). The state machine is therefore enforced in `on_tool_handle` (which the runtime invokes for *every* tool, returning `Delegate` to pass through), **not** `on_tool_policy`.

```
Agent loop step
  │
  ├─ on_build_system_prompt (PURE) → inject STATIC protocol text only
  │     (cannot read files; phase-specific content comes from on_pre_step)
  │
  ├─ on_pre_step (effectful) → after compaction OR when AR state is stale in history,
  │     read DuckDB and inject a state Msg: objective, segment, baseline/best metric,
  │     iterations left, current ArState, and any owed ar_log
  │
  ├─ on_tool_handle (effectful) → STATE-MACHINE GUARD + handlers. Invoked for EVERY tool:
  │     1. s = derive_state(db)
  │     2. if not legal(s, call.tool) → Handled(error ToolResultEnvelope, exit_code≠0)
  │        (this is how WriteFile/EditFile/BashExec get blocked while AwaitingLog)
  │     3. else dispatch ar_* handlers, or Delegate for foreign tools
  │
  │     ar_init  (Setup, or new_segment from Ready/Done) → branch/baseline/init_dirty → Ready
  │     ar_run   (legal only in Ready)       → run benchmark ×samples, persist authoritative
  │                                             pending_run, parse METRIC+ASI → AwaitingLog
  │     ar_log   (legal only in AwaitingLog) → checks gate, scope check, INSERT run, clear
  │                                             pending_run, selective commit/revert → Ready
  │     ar_notes (legal in Ready/AwaitingLog/Done) → replace/append session notes
  │
  └─ on_solver_candidate (effectful) → block premature completion until converged/cap → Done
```

The agent drives the loop autonomously: edit → benchmark → log → evaluate → repeat. The
**state machine** (see "State Machine Enforcement" below) makes that loop *enforceable*
rather than merely prompt-suggested — illegal tool calls are rejected by `on_tool_handle`
(returning a failing `ToolResultEnvelope`) before they can corrupt the keep/discard accounting.

---

## Package Structure

**In-tree**, at `src/core/ext/autoresearch/`. Can be extracted to a package later.

> Note: `context_mode` is **no longer in-tree** — it was extracted to the registry package `sunholo/motoko_ext_context_mode` (`src/core/ext/context_mode/` now holds only build artifacts; source is in the registry cache at `~/.ailang/cache/registry/sunholo/motoko_ext_context_mode/0.2.2/`). Use the **active, working** extensions as references — those wired in the default profile's `extensions.order` (`compaction_ai`, `context_mode`, `exa_search`, `mcp`, `ailang_docs`): `context_mode.ail` for the `Handled(…)`/`Delegate` tool-handling pattern *and* compaction, and `compaction_ai` for the dedicated `on_pre_step` reconstruction pattern. (Ignore `omnigraph`/`openkb` — not in the active set.) Decide explicitly whether autoresearch ships in-tree or as a package like every other extension; either way registration goes through `registry_generated.ail`.

```
src/core/ext/autoresearch/
  register.ail       — entry point: register_with_config(cfg: RuntimeConfig) -> ExtensionHooks ! {FS}
                       (must also set provided_tools + on_describe_tools)
  types.ail          — ExperimentConfig, RunEntry, ConfidenceResult, Segment types
  tools.ail          — ToolSchema definitions + argument parsing
  db.ail             — DuckDB schema init, session/run insert/query helpers
  notes.ail          — autoresearch.md file I/O + notes management
  metrics.ail        — keep rule, within-run MAD (noisy metrics), stall/convergence, confidence report
  git_ops.ail        — branch mgmt, selective commit/revert, dirty path tracking
  scope.ail          — scope deviation detection + run flagging
  state.ail          — ArState enum, derive_state(db), legal(state, tool) transition guard
  prompts.ail        — STATIC protocol text for on_build_system_prompt (pure) + the dynamic
                       state-summary string builder used by on_pre_step (fed DB/file reads)
  compaction.ail     — on_pre_step: reconstruct state from DuckDB + inject autoresearch.md content
```

Pattern reference: the active extensions (`context_mode`, `exa_search`, `mcp`) in the registry cache, and the host tool dispatch in `src/core/ext/runtime.ail` (`first_handle`).

---

## Tools

> **Result shape.** Every handler returns `Handled(ToolResultEnvelope)` where `ToolResultEnvelope = {tool_call_id, tool, exit_code, stdout, stderr, metadata: Json}`. The JSON objects shown below are the **`metadata`** payload (with `exit_code = 0`, a human summary in `stdout`). Rejections (illegal transition, scope deviation, run_number mismatch) return the *same* envelope with `exit_code ≠ 0` and the reason in `stderr` + structured detail in `metadata` — they are **not** a separate `{error: …}` type. Tool dispatch keys on `call.tool`; arguments arrive as `call.arguments: Json`.

### `ar_init` — Initialize or Reconfigure Experiment Session

Creates session directory, files, and git branch. Can also bump to a new segment within an existing session.

Arguments:
- `objective` (string, required) — what to optimize
- `metrics` (array of `{name, direction: "minimize"|"maximize", noisy: bool}`, required) — first entry is the primary metric. `noisy` (default `false`) marks metrics with measurement variance (latency, tokens/step, flaky pass rates) vs deterministic ones (line count, binary size); it selects the keep rule and whether per-run sampling applies (see Metrics & Confidence).
- `benchmark_script` (string, required) — bash body for `autoresearch.sh`, must print `METRIC name=value`
- `scope_paths` (array of string, optional) — files/dirs the agent is allowed to modify
- `off_limits` (array of string, optional) — files/dirs the agent must never touch
- `constraints` (array of string, optional) — free-text rules (e.g., "do not remove public API functions")
- `checks_script` (string, optional) — body for `autoresearch.checks.sh`
- `max_iterations` (int, optional, default 20) — per-segment cap
- `patience` (int, optional, default 3) — consecutive no-improvement iterations before the solver gate allows completion (convergence threshold)
- `new_segment` (bool, optional, default false) — if true, bump segment within existing session
- `session_dir` (string, optional, default `.motoko/autoresearch`)

**On first call:**
1. Creates `autoresearch/<objective-slug>-<date>` branch (collision-safe with numeric suffixes)
2. Sets `baseline_commit = HEAD`. **Does NOT auto-commit unrelated pending changes.** Instead captures `init_dirty = git status --porcelain` (the user's pre-experiment WIP) and records it as the experiment-external exclusion set — these paths are never committed or reverted by autoresearch. (`new_segment` follows the same no-auto-commit rule — resolves former Open Question #1.)
3. Initializes `autoresearch.db` (creates `sessions`/`runs`/`pending_runs` tables) and writes the flat files: `autoresearch.md`, `autoresearch.sh` (chmod +x), `autoresearch.config.json`, optionally `autoresearch.checks.sh`
4. `INSERT` the session row (segment 1, with `init_dirty_json`) into `sessions`

**On `new_segment: true`:**
1. Marks the prior segment terminal: `UPDATE sessions SET status='abandoned', done_reason='superseded by new segment' WHERE segment = <prev>` (if still `active`)
2. Abandons any pending (unlogged) run — `DELETE` the open `pending_runs` row
3. Increments the segment counter; sets `baseline_commit = HEAD` and **re-captures `init_dirty`** at the new HEAD (does **not** auto-commit — mirrors first call)
4. `INSERT` a new `active` `sessions` row for the new segment (with the new `init_dirty_json`)

Returns: `{status: "initialized"|"segment_bumped", session_dir, branch, baseline_commit, segment, files_created}`

### `ar_run` — Run Benchmark

Executes `autoresearch.sh` (with replication for noisy metrics), parses output, persists the authoritative result. Arguments:
- `session_dir` (string, optional)
- `timeout_ms` (int, optional, default 60000) — per sample
- `samples` (int, optional, default 1) — number of times to run the benchmark. Use ≥5 when the primary metric is `noisy`, so a within-state noise floor (MAD over samples) can be computed. For deterministic metrics, 1 is correct.
- `label` (string, optional)

**Execution lifecycle:**
1. Execute `bash autoresearch.sh` `samples` times with timeout (no dirty snapshot — the experiment-external set is `init_dirty` from `ar_init`).
2. Parse `METRIC name=value` lines per sample → per-metric sample arrays.
3. Parse `ASI key=value` lines (structured metadata) from the final sample.
4. If `autoresearch.checks.sh` exists and the benchmark exited 0, run it once → `checks_passed`.
5. **Persist a `pending_runs` row** (run_number, `samples_json`, aggregated metrics, asi, `checks_passed`, `exit_code`, `duration_ms`) → transitions state to `AwaitingLog`. These are the **authoritative** values; `ar_log` reads them rather than trusting the agent.

**METRIC/ASI parsing contract:**
- Primary metric absent from output → `status="failed"` (a failed run, not a NaN). The agent must `ar_log(discard)`.
- Non-numeric `METRIC` value → skip that line, record a parse warning in `stderr_tail`.
- Duplicate `METRIC name=` within one sample → last occurrence wins.
- Aggregated metric value = median of that metric's samples (mean is noise-sensitive); raw samples kept in `samples_json`.

(Legal only in `Ready`; `on_tool_handle` rejects `ar_run` in `Setup`/`AwaitingLog`/`Done` with a failing envelope.)

Returns (`metadata`):
```json
{
  "status": "completed"|"failed"|"timeout",
  "run_number": 4,
  "metrics": {"tokens_per_step": 1847, "test_pass_rate": 0.95},
  "samples": {"tokens_per_step": [1840, 1851, 1847, 1849, 1848]},
  "within_run_mad": {"tokens_per_step": 3.0},
  "asi": {"hypothesis": "removing redundant imports saves tokens", "approach": "static analysis"},
  "checks_passed": true,
  "exit_code": 0,
  "duration_ms": 3200,
  "stdout_tail": "... last 50 lines ...",
  "stderr_tail": "...",
  "ar_state": "AwaitingLog",
  "owed_action": "ar_log(run_number=4, decision=keep|discard)"
}
```

### `ar_log` — Log Result & Git Action

`INSERT`s into the `runs` table, detects scope deviations, triggers selective git commit or revert. Legal only in `AwaitingLog`. **Metrics and check results are read from the recorded `pending_runs` row, not from the agent** — `ar_log` does not accept a `metrics` argument. Arguments:
- `run_number` (int, required) — must match the open `pending_runs` row (mismatch → rejected)
- `decision` ("keep" | "discard", required) — `crash`/`checks_failed` are *derived* from the recorded result, not self-reported
- `changes_summary` (string, required) — what was changed
- `reasoning` (string, required) — why keeping or discarding
- `learnings` (string, optional) — appended to autoresearch.md
- `justification` (string, optional) — required if scope deviations detected and decision is "keep"
- `flag_runs` (array of `{run_number, reason}`, optional) — mark suspect runs to exclude from the confidence *report*
- `asi` (JSON object, optional) — additional structured metadata

**Log lifecycle:**
0. Read the open `pending_runs` row; verify `run_number` matches (else reject). Pull recorded `metrics`/`samples`/`checks_passed`/`exit_code` from it.
1. **Checks gate:** if `decision == "keep"` and recorded `checks_passed == false` or `exit_code ≠ 0` → reject with a failing envelope (`"cannot keep: run #N failed checks/exited nonzero"`). The agent cannot commit a broken change.
2. Compute `iteration_changes = current_dirty − init_dirty` (init_dirty from the `sessions` row). Flag any path in `iteration_changes` that is also in `init_dirty` (agent touched the user's WIP).
3. Detect scope deviations: paths in `iteration_changes` outside `scope_paths` or inside `off_limits`.
4. If deviations found and `decision == "keep"` and no `justification` → return error demanding justification.
5. If `decision == "keep"`: `git add -- <iteration_changes>` then commit (only those files).
6. If `decision == "discard"`: `git checkout HEAD -- <tracked iteration_changes>` + `rm` untracked iteration-created files. `init_dirty` paths are never touched.
7. Apply `decision`/derived status (keep|discard|crash|checks_failed) and process `flag_runs`.
8. Update the keep/improvement bookkeeping and `stall` counter (see Metrics & Confidence); compute the confidence **report**.
9. `INSERT` run entry into `runs` (with recorded metrics + `samples_json`), then **`DELETE` the `pending_runs` row**.
10. **Cap check:** if this was run #`max_iterations`, set `sessions.status='exhausted'`, `done_reason='max_iterations reached'` → state becomes `Done`. Otherwise state becomes `Ready`.
11. If `learnings` provided, append to autoresearch.md.

Returns (`metadata`):
```json
{
  "status": "logged",
  "iteration": 3,
  "segment": 1,
  "git_action": "committed"|"reverted"|"none",
  "commit_sha": "a1b2c3d"|null,
  "scope_deviations": ["tests/unrelated.ail"],
  "best_metric": {"lines": 9820},
  "stall": 0,
  "patience": 3,
  "confidence_report": {"lines": {"kind": "deterministic", "cumulative_delta": -180, "pct": 1.8}},
  "ar_state": "Ready"
}
```

### `ar_notes` — Update Session Knowledge Base

Maintains the session's durable notes (goals, scope reasoning, idea backlog). Arguments:
- `body` (string, optional) — replace entire notes content
- `append_idea` (string, optional) — append a bullet under `## Ideas` section

If `body` is provided, replaces the notes section of `autoresearch.md`. If `append_idea` is provided, inserts a bullet point under a `## Ideas` heading (creates the heading if absent).

Returns: `{status: "updated", char_count: int}`

---

## Session Files

Directory: `.motoko/autoresearch/` (within workdir)

| File | Purpose |
|------|---------|
| `autoresearch.db` | DuckDB database — `sessions` + `runs` + `pending_runs` tables (see Persistence section). **If the DuckDB spike fails, this becomes `autoresearch.jsonl` + an in-memory state derived from it** — see Persistence. |
| `autoresearch.md` | Objectives, rules, scope, accumulated learnings + ideas. Injected into system prompt. |
| `autoresearch.sh` | Benchmark script. Outputs `METRIC name=value` and optionally `ASI key=value` lines. |
| `autoresearch.checks.sh` | Optional pass/fail validation (exit 0 = pass). |
| `autoresearch.config.json` | Human-readable configuration snapshot (scope_paths, off_limits, constraints, etc.). |

---

## Hook Implementations

### `on_build_system_prompt` — Static Protocol Text Only (PURE)
This hook is `(ExtCtx) -> PromptPatch` with **no effect row**, so it **cannot read `autoresearch.sh`, `autoresearch.md`, or the DB**. It therefore injects only *static, file-independent* guidance — the tool protocol and the rules — and may branch only on pure `ExtCtx` fields (`ctx.step`, `ctx.mode`, `ctx.task`, `ctx.state_key`):
> "This session may run an autoresearch optimization loop. Protocol: build a benchmark harness (`autoresearch.sh` emitting `METRIC name=value`), then `ar_init` → (edit → `ar_run` → `ar_log(keep|discard)`)* . Do NOT call `ar_run`/`ar_log` before `ar_init`. After `ar_run` you MUST `ar_log` before editing again. Keep iterating until improvements stall (the loop signals convergence) or max_iterations. Stay within `scope_paths`; never touch `off_limits`."

All **dynamic, file/DB-derived** content (current objective, scope, learnings, segment metrics, owed `ar_log`) is injected by `on_pre_step` instead, because only it can perform `FS`/`Process` effects.

### `on_pre_step` (Dynamic State Injection + Compaction Survival) — EFFECTFUL
Signature carries `! {IO, Process, FS, …}`, so this is where DB/file reads happen. Fires when `autoresearch.db` exists and either (a) the last ~5 messages lack autoresearch tool calls (post-compaction), or (b) the loop-phase state isn't already present in recent history. Reconstruct via DuckDB queries:
- `SELECT segment, objective, max_iterations, patience, status FROM sessions ORDER BY id DESC LIMIT 1`
- `SELECT COUNT(*) FROM runs WHERE segment = ?` (iteration count); best metric via `SELECT MIN(json_extract(metrics_json,'$.<primary>')::DOUBLE) FROM runs WHERE segment = ? AND decision='keep'` (use `MAX` for `maximize` direction)
- `SELECT run_number, decision, metrics_json, changes_summary FROM runs WHERE segment = ? ORDER BY run_number DESC LIMIT 5`
- Current `stall` (via `stall_count`) and flagged runs: `SELECT run_number, flagged_reason FROM runs WHERE flagged = TRUE AND segment = ?`
- Also read `autoresearch.md` (objectives/scope/learnings) via `std/fs` and fold it in — this replaces the loop-phase content the pure prompt hook can't supply.
- **Current state**: `derive_state(db)`. If `AwaitingLog`, the summary MUST state the pending `run_number` and that the agent owes an `ar_log` before any further edits — otherwise a post-compaction agent resumes editing and corrupts the dirty-path diff. If `Done`, the summary states the segment is closed (`status`/`done_reason`) and that only `ar_init(new_segment)`/`ar_notes` remain.

Inject as `Compacted(msgs ++ [summary_msg], "autoresearch: session state reconstructed from DB")`, where `summary_msg` is a fully-populated `Msg` (`{role:"user", content:…, tool_calls:[], tool_call_id:""}` — all four ABI v2.2.0 fields). Otherwise `PassThrough`.

### `on_tool_handle` — State-Machine Guard + Handlers (EFFECTFUL, PRIMARY ENFORCEMENT)
Signature carries `! {Process, FS, …}` and the runtime calls it for **every** tool (each extension gets a turn; first to return `Handled` wins, else `Delegate` falls through to the real tool — see `src/core/ext/runtime.ail` `first_handle`, and the `context_mode`/`exa_search` handlers). This is the *only* place the state machine can be enforced, because it can read the DB. Logic:
0. **Fast path (perf):** `derive_state(db)` shells out to `duckdb`, and this hook runs on *every* tool call (reads, edits, bash). First do a cheap FS check for the session DB file (`.motoko/autoresearch/autoresearch.db`). If absent → no active session → `Delegate` immediately, paying no subprocess cost. Only when it exists do we query (and the state may be cached per step to avoid repeat spawns within one step).
1. `s = derive_state(db)`
2. `legal(s, call.tool)` — if illegal, return `Handled(reject_envelope)` with `exit_code ≠ 0` and the current state + legal actions in `stderr`/`metadata`. This is how the **mutator tools are blocked** while `AwaitingLog` (intercept a foreign tool → return a failing envelope instead of `Delegate`) and how `ar_run`/`ar_log` are blocked before `ar_init`. **Canonical tool names (verified in `tool_catalog.ail`):** `ReadFile`, `WriteFile`, `EditFile`, `BashExec`, `RunTests`, `Search`. The **mutator set** the `AwaitingLog` gate blocks is `{WriteFile, EditFile, BashExec}` — `BashExec` is the catch-all, since the agent can mutate the tree via `sed -i`/redirects, not just `EditFile`/`WriteFile`.
3. Otherwise: dispatch `ar_init`/`ar_run`/`ar_log`/`ar_notes` to their handlers; `Delegate` for all other tools.

Example reject `stderr`: `"AwaitingLog: run #4 must be logged via ar_log(decision=keep|discard) before editing. To abandon it: ar_log(discard) or ar_init(new_segment)."`

### `on_tool_policy` — PURE, best-effort only (cannot read DB)
`(ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision`, no effects. It **cannot** call `derive_state(db)`, so it is **not** the enforcement floor. Default it to `NoOpinion`. (Optional: a purely-`ctx`-based heuristic using `ctx.history_slice` could pre-warn, but it's compaction-fragile and redundant with `on_tool_handle`, so it is not relied upon.) The engine still merges `Deny > Pending > Allow > NoOpinion` across extensions.

### `on_solver_candidate` — EFFECTFUL
Gates on **convergence (`stall`), not a confidence ratio**. With an active session:
- state is `AwaitingLog` → `ContinueWithFeedback("Pending run #N must be logged before completion.")`.
- `stall < patience` and `iteration < max_iterations` → `ContinueWithFeedback("Not yet converged (stall X/{patience}). Keep iterating, or ar_notes to record why you're stopping.")`.
- `stall ≥ patience` (diminishing returns) → the agent is stopping at a converged plateau: write `sessions.status='converged'`, `done_reason='stall ≥ patience'` (→ `Done`), then `Accept(...)`/`NoDecision`. (Status is written here, on the *actual stop*, so convergence stays soft until the agent chooses to finish.)
- `iteration ≥ max_iterations` → status is already `exhausted` (set by `ar_log`); `NoDecision`.
- otherwise → `NoDecision`.

### Other hooks
`on_budget_plan` → no-op patch, `on_response_intercept` → `NoIntercept`, `on_describe_tools` → the 4 `ToolSchema`s, `provided_tools` → `["ar_init","ar_run","ar_log","ar_notes"]`.

---

## State Machine Enforcement

The tool sequence (`ar_init → (ar_run → ar_log)* → done`) is enforced as a state machine, not merely suggested by the prompt. **Why enforcement, not nudging:** `ar_log` commits/reverts `iteration_changes = current_dirty − init_dirty`, and the benchmark result it pairs with was measured at `ar_run` time. That pairing is only sound if *no edits occur between `ar_run` and `ar_log`* — i.e. **`current_dirty` at log time must equal the tree that was benchmarked**. If the agent edits after benchmarking but before logging, those unbenchmarked edits get committed (or reverted) as if they were part of the measured run — silent corruption. A prompt cannot guarantee the run↔log pairing is atomic; a state machine can.

### States

```ailang
-- state.ail
type ArState = Setup | Ready | AwaitingLog | Done
```

| State | Meaning | Legal tools | Illegal calls rejected |
|-------|---------|-------------|------------------------|
| `Setup` | No session row in DB | `ReadFile`/`WriteFile`/`EditFile`/`BashExec`, `ar_init` | `ar_run`, `ar_log`, `ar_notes` |
| `Ready` | Session exists, no pending run | edit/write, `ar_run`, `ar_notes`, `ar_init(new_segment)` | `ar_log` ("no pending run") |
| `AwaitingLog` | `ar_run` completed, not yet logged | `ar_log`, `ar_notes`, `ReadFile`/`Search` | **`WriteFile`/`EditFile`/`BashExec`**, second `ar_run` |
| `Done` | latest segment `status != 'active'` (exhausted / converged-and-stopped / abandoned) | `ar_init(new_segment)`, `ar_notes`, read-only | `ar_run`, `ar_log` |

### Transitions

```
   Setup ──ar_init──▶ Ready ──ar_run──▶ AwaitingLog ──ar_log(keep|discard)──▶ Ready  (iteration++)
                        ▲ │  ▲                  │
                        │ │  └──────────────────┘  ar_log(discard) / ar_init(new_segment)  [abandon pending run]
                        │ └──── status set: ar_log @cap (exhausted) | gate after convergence ──▶ Done
                        └──────────────── ar_init(new_segment) [status→abandoned] ─────────────────┘
```

Convergence (`stall ≥ patience`) is **soft**: `on_solver_candidate` stops prompting the agent to continue, but does **not** write `status` or block tools — the agent may try another idea. `status` flips to a terminal value (→ `Done`) only when the cap is hit, the agent actually stops after convergence, or a new segment supersedes this one.

**Escape hatch:** neither `AwaitingLog` nor `Done` is a dead end — `ar_log(discard)`/`ar_init(new_segment)` abandon a bad pending run, and `ar_init(new_segment)` reopens a `Done` segment into a fresh `Ready` one.

### State is derived from persisted data (not the conversation)

For the machine to be enforceable *and* survive compaction, the state must be a pure function of the DB — **not** carried in chat messages. This is a change from a naive contract that would return `run_number` to the model and read it back as an `ar_log` argument (that does not survive compaction):

```ailang
func derive_state(db: DB) -> ArState ! {Process}   -- effectful: shells out to duckdb
-- Setup       if sessions table empty
-- Done        if the latest segment's sessions.status != 'active'
-- AwaitingLog if a pending_runs row exists for the current segment
-- Ready       otherwise (session exists, active, no pending run)
-- NOTE: convergence (stall >= patience) is NOT a Done condition here — it stays soft
--       in on_solver_candidate. status is written only on real terminal events
--       (cap exhausted / agent stops after convergence / segment abandoned).

func legal(state: ArState, tool_name: string) -> Result[(), RejectMsg]   -- pure helper
type RejectMsg = { current_state: string, legal_actions: [string], message: string }
-- On violation, on_tool_handle renders RejectMsg into a failing ToolResultEnvelope
-- (exit_code ≠ 0, message in stderr, fields in metadata) and returns Handled(envelope).
```

`ar_run` writes a `pending_runs` row (capturing `run_number` + the authoritative benchmark result durably); `ar_log` clears it. The experiment-external exclusion set (`init_dirty`) lives in the `sessions` row from `ar_init`. So a post-compaction agent recovers the owed `run_number` and all state via `on_pre_step` rather than from chat history.

### Enforcement layers

Because `on_tool_policy` and `on_build_system_prompt` are **pure** (verified against the ABI), the *only* hook that can read DB-derived state and reject a call is `on_tool_handle`. So:

1. **`on_tool_handle`** (EFFECTFUL) — the sole enforcement point. `derive_state(db)` → `legal()` → `Handled(reject_envelope)` on violation, before the tool runs. Blocks both illegal `ar_*` calls *and* the mutator set `{WriteFile, EditFile, BashExec}` during `AwaitingLog` (by intercepting the foreign tool instead of delegating). Confirmed reachable: `agent_loop_v2.dispatch_calls` runs `dispatch_tool_policy` → `dispatch_tool_handle` for every call, and `Handled` short-circuits native dispatch.
2. **`on_tool_policy`** (PURE) — `NoOpinion`. Cannot consult the DB, so it is **not** an enforcement layer; do not rely on it for the state machine.
3. **Prompt** — the *guide* (static text from `on_build_system_prompt` + dynamic state from `on_pre_step`). The state machine is the floor (can't do wrong); the prompt tells the agent what to do next.

**Decisions locked in:** the mutator set `{WriteFile, EditFile, BashExec}` is *hard-blocked* in `AwaitingLog` — implemented as `on_tool_handle` returning `Handled(failing_envelope)` (since `on_tool_policy.Deny` isn't available without DB access). `ar_run`/`ar_log` are blocked before `ar_init` (Setup) the same way. `ar_init` itself is allowed in Setup regardless of whether `autoresearch.sh` exists — harness-first ordering is steered by the prompt, not blocked by the state machine.

## Scope Enforcement

Ported from oh-my-pi's scope deviation detection:

**`scope.ail`** implements:
1. **`compute_iteration_changes(init_dirty, current_dirty) -> [string]`** — set difference isolating this iteration's edits (excludes the user's pre-experiment WIP).
2. **`compute_scope_deviations(changed_paths, scope_paths, off_limits) -> [string]`** — paths outside `scope_paths` OR inside `off_limits`.
3. **`path_matches_spec(path, spec) -> bool`** — **path-segment** matching, not raw string prefix: normalize directory specs to a trailing `/` so `"src/core/"` matches `"src/core/rpc.ail"` but **not** `"src/core_helpers/x.ail"`. Also normalize `git status --porcelain` input: strip status flags, unquote quoted paths, and for rename entries (`R old -> new`) use the **new** path.

If scope deviations are found on a "keep" decision without justification, `ar_log` returns a failing envelope (`exit_code ≠ 0`) whose `metadata` is:
```json
{"reason": "scope_deviation", "deviations": ["tests/unrelated.ail"], "message": "Out-of-scope changes detected. Provide justification parameter or discard."}
```

---

## Metrics & Confidence

The original "MAD across kept commits, gate at ≥ 2.0" design was wrong on two counts: (a) for **deterministic** metrics (line count — the flagship) there is no measurement noise, so MAD across kept values measures step size, not a noise floor; (b) gating completion on *cumulative* improvement ≥ 2·MAD is backwards — convergence means *marginal* gains fall **below** noise. The corrected model:

### Keep rule (per iteration, at `ar_log`, using recorded `pending_runs` values)
- **deterministic** primary metric: keep iff it **strictly improves** in its `direction` **and** checks pass.
- **noisy** primary metric: keep iff the **median of samples improves by more than the within-run MAD** (so noise isn't kept) **and** checks pass. This requires `ar_run` `samples ≥ 5` — the within-state noise floor is MAD over *repeated samples of the same code state*, which the old single-sample design could never measure.

### Stop condition (the real gate) — unified, both metric kinds
Track `stall` = consecutive iterations that did not produce a **kept improvement**. A **discard counts as a stall iteration**, and a kept-but-non-improving run does too; only a *keep that improves the primary metric* (`runs.improved = TRUE`) resets `stall` to 0. (Without this, an agent that keeps discarding would never converge.) `on_solver_candidate` allows completion when `stall ≥ patience` (default 3) **or** `iteration ≥ max_iterations`. This is genuine diminishing-returns detection and works regardless of metric kind.

### Confidence is a *report*, not a gate
- deterministic: report `cumulative_delta` and `pct` reduction vs baseline.
- noisy: report `ratio = |best_median − baseline_median| / within_run_MAD` (≥2 green / 1–2 yellow / <1 red) as a *quality signal* — it does not gate completion.

```ailang
-- Key type signatures (metrics.ail) — median/MAD operate on PER-RUN samples, not across commits
pure func median(sorted_xs: [float]) -> float
pure func mad(sorted_xs: [float]) -> float          -- within-run noise floor for noisy metrics
pure func improved(direction: string, prev: float, cur: float, noise: float) -> bool
func stall_count(db: DB, segment: int) -> int ! {Process}   -- consecutive no-improvement keeps
func confidence_report(db: DB, segment: int, metric_name: string, noisy: bool, baseline: float)
    -> Option[ConfidenceResult] ! {Process}

type ConfidenceResult = { kind: string, value: float, noise: float, ratio: float, pct: float }
```

**SQL injection caveat**: the duckdb package has no parameterized queries — SQL is built via string interpolation. `db.ail` must sanitize all interpolated values (escape single quotes; validate metric names are alphanumeric). (N/A on the JSONL fallback.)

---

## Git Integration

Via `exec("bash", [...])` (same pattern as existing extensions).

### Branch Management
- **On `ar_init`**: Create `autoresearch/<slug>-<YYYYMMDD>` branch, with `-2`, `-3` suffixes for collisions
- Branch name capped at 48 characters
- If already on an `autoresearch/` branch, reuse it

### Selective Commit (Keep)
```bash
# Stage only this iteration's files, not the whole tree
git add -- <iteration_change_1> <iteration_change_2> ...
git commit -m "autoresearch #N: <summary>"
```

### Selective Revert (Discard)
```bash
# Revert only paths changed during this iteration
git checkout HEAD -- <tracked_iteration_change_1> ...
# Remove untracked files created during this iteration
rm -f <untracked_iteration_change_1> ...
```

This preserves any pre-existing uncommitted work (`init_dirty`) that wasn't part of the experiment.

### Dirty Path Tracking (snapshot once, not per-run)
- **At `ar_init`**: capture `git status --porcelain` → `init_dirty` (the experiment-external WIP), stored in the `sessions` row. `baseline_commit = HEAD`; WIP is **not** committed.
- **At `ar_log` time**: capture `git status --porcelain` → `current_dirty`.
- **`iteration_changes` = `current_dirty − init_dirty`** — because `ar_init` leaves a clean baseline and every `ar_log` commits/reverts, the tree is clean at each iteration start, so this is exactly the agent's edits for this iteration. (Capturing the snapshot per-`ar_run` would be wrong: the agent edits *before* `ar_run`, so a post-edit snapshot would treat its own edits as external and commit nothing.)

---

## Wiring into Motoko

Registration goes through `src/core/ext/registry_generated.ail` regardless of the in-tree-vs-package choice (Open Question #3). If in-tree:

1. Add import + resolve case to `src/core/ext/registry_generated.ail`:
   ```ailang
   import src/core/ext/autoresearch/register (register_with_config as register_autoresearch)
   -- In resolve():
   else if name == "autoresearch" then Some(register_autoresearch(cfg))
   ```
   Or regenerate via `ailang generate-extension-registry` after adding to `ailang.toml` `[extensions]`.
2. Add `"autoresearch"` to profile's `extensions.order` in `.motoko/config/*/config.json`

**Dependencies**: `sunholo/motoko_ext_abi@2.2.0` (already in `ailang.toml`/`ailang.lock`) for the hook ABI; `sunholo/duckdb@0.1.0` (**verified resolvable**, 2026-05-29) + the `duckdb` CLI on PATH (the one runtime binary still to be installed in the devcontainer). `std/fs` fallback remains available if a CLI dependency is undesirable. Target language: AILANG 0.19.1.

---

## Safety

`autoresearch.sh` and `autoresearch.checks.sh` are **agent-authored** and executed via `bash` with the **host's full effect capabilities** on every `ar_run`, repeatedly and unattended — and the flagship objective has Motoko editing its **own runtime**. There is no sandbox; `timeout_ms` bounds duration but not side effects. Mitigations the design relies on:

- All experiment work stays on the throwaway `autoresearch/<slug>-<date>` branch; baseline and `init_dirty` are recoverable.
- `off_limits` **must** include the autoresearch extension's own sources and any generated/registry files (already set in the flagship). The state machine enforces `off_limits` on every keep.
- The checks gate (`ar_log` refuses to keep a run whose recorded `checks_passed == false`) prevents committing changes that broke the build.
- Recommended: review the agent-authored `autoresearch.sh`/`autoresearch.checks.sh` before any long unattended run; consider constraining what `ar_init` accepts as a script body for self-modification objectives.

---

## Implementation Phases

### Phase 1: Core (skeleton + tools) — ~3 days
0. ~~**DuckDB spike (gate)**~~ **DONE (2026-05-29):** package resolves and the `{types,query,schema}` API matches (see Persistence). Decision: **use DuckDB**, not the fallback.
1. Re-run `ailang install sunholo/duckdb@0.1.0` (re-adds it to `ailang.toml`/`ailang.lock`; reverted after the spike) — and write the 10-line open/create/insert/read scratch program to confirm runtime behavior **once the CLI is installed**.
2. Add `duckdb` CLI install to `scripts/install-prerequisites.sh` and the devcontainer, then install it (the **only** outstanding runtime prereq; the GitHub release binary couldn't be fetched in the planning sandbox).
3. Create module structure at `src/core/ext/autoresearch/`
4. `types.ail` — all domain types (ExperimentConfig, RunEntry, ConfidenceResult, Segment, etc.)
5. `tools.ail` — 4 tool schemas + argument parsing
6. `db.ail` — DuckDB schema creation (`sessions` + `runs` + `pending_runs` + sequences; note DuckDB has no autoincrement), insert/query helpers using `pkg/sunholo/duckdb/*`. Include a `sanitize_sql_string` helper to escape single quotes in interpolated values.
7. `notes.ail` — autoresearch.md management
8. `git_ops.ail` — branch creation, `init_dirty` capture (once at ar_init), `iteration_changes` diff, selective commit/revert
9. `scope.ail` — scope deviation detection (path-segment matching; porcelain unquote + rename handling)
9b. `state.ail` — `ArState` enum, `derive_state(db)`, `legal(state, tool) -> Result[(), RejectMsg]` transition guard
10. `register.ail` — hooks wired: `on_tool_handle` (derive_state → legal() guard + handlers, the enforcement point), `on_describe_tools` + `provided_tools`; `on_tool_policy` → `NoOpinion`, rest no-op initially
11. Implement `ar_init` handler (create session, branch, baseline, DB schema, files) — Setup→Ready
12. Implement `ar_run` handler (execute benchmark ×`samples`, parse METRIC+ASI per contract, persist authoritative pending_runs row) — Ready→AwaitingLog
13. Implement `ar_log` handler (verify pending run, checks gate, `iteration_changes` diff, scope check, INSERT into runs, delete pending_runs, selective git ops) — AwaitingLog→Ready
14. Implement `ar_notes` handler (replace/append notes)
15. Wire into registry, verify with `ailang check` on each new module
16. Note: `make check_core` only checks `src/core/*.ail` (not subdirs). Use direct `ailang check src/core/ext/autoresearch/*.ail` or add a `check_autoresearch` Makefile target.

### Phase 2: Intelligence — ~2 days
1. `metrics.ail` — keep rule (deterministic vs noisy), within-run MAD over `samples_json`, `stall_count`, confidence *report*
2. `on_solver_candidate` — stall/convergence-based completion gating (effectful; reads DB)
3. `prompts.ail` — static protocol text for `on_build_system_prompt` (pure) + dynamic state-summary builder
4. `compaction.ail` — `on_pre_step` (effectful): state reconstruction from DuckDB + `autoresearch.md` injection, returning a fully-populated summary `Msg`

### Phase 3: Polish — ~1-2 days
1. Smoke tests (following `scripts/smoke_*.ail` pattern)
2. Inline AILANG unit tests for metrics functions and scope deviation logic
3. Optional: `on_budget_plan` to request higher step budgets for optimization sessions
4. Template `autoresearch.md` with best-practice structure

### Phase 4: End-to-End Validation — "Compact Motoko's Core Runtime"

The acid test. Motoko uses its own autoresearch extension to autonomously compact its own codebase.

**Objective:** Reduce total line count of `src/core/*.ail` while preserving correctness.

**Setup:**
```
ar_init({
  objective: "Reduce total line count of Motoko's core AILANG runtime",
  metrics: [{ name: "lines", direction: "minimize", noisy: false }],
  scope_paths: ["src/core/"],
  off_limits: [
    "src/core/ext/registry_generated.ail",
    "src/core/test/",
    "src/core/ext/autoresearch/"
  ],
  constraints: [
    "Do not remove public exports",
    "Do not change function signatures used by the TUI layer",
    "Do not modify generated files"
  ],
  max_iterations: 20
})
```

**Benchmark script (`autoresearch.sh`):**
```bash
#!/bin/bash
LINES=$(find src/core -name "*.ail" \
  ! -name "*_test.ail" \
  ! -path "*/test/*" \
  ! -name "registry_generated.ail" \
  | xargs wc -l | tail -1 | awk '{print $1}')
echo "METRIC lines=$LINES"
```

**Correctness checks (`autoresearch.checks.sh`):**
```bash
#!/bin/bash
set -e
make check_core
make test_core
```

**What this validates:**

| Concern | How it's tested |
|---------|----------------|
| Full tool lifecycle | ar_init → (ar_run → ar_log) × N → ar_notes |
| Keep decisions | Agent finds dead code or duplication, line count drops, tests pass |
| Discard decisions | Agent's refactor breaks type-checker, selective revert fires |
| Scope enforcement | Agent is tempted to simplify registry_generated.ail or test files — deviation detection blocks it |
| Selective revert | Only this iteration's files revert on discard; `init_dirty` (pre-existing work) survives |
| Stall convergence | `lines` is deterministic → stop fires on `stall ≥ patience` (no improvement in N iterations), not a noise ratio |
| Checks gate | A "keep" attempt on a run whose `checks_passed == false` is rejected by `ar_log` |
| Solver gate | `on_solver_candidate` blocks premature "done" until `stall ≥ patience` or max_iterations |
| Static + dynamic prompt | Static protocol from `on_build_system_prompt`; live state via tool results + `on_pre_step` |
| Compaction survival | If session exceeds ~20 steps, on_pre_step reconstructs state (incl. owed `ar_log`) from DuckDB |
| Branch management | All work happens on `autoresearch/compact-core-YYYYMMDD` branch |
| ar_notes | Agent documents patterns found (e.g., "runtime.ail has 3 nearly-identical fold helpers") |
| DuckDB persistence | Sessions + runs queryable after the session ends |

**Success criteria:**
1. The loop runs autonomously for at least 5 iterations without human intervention
2. At least one "keep" decision produces a measurable line reduction
3. At least one "discard" correctly reverts a broken change
4. `make check_core && make test_core` passes at every "keep" commit (and a deliberate break is rejected by the checks gate, not committed)
5. The `autoresearch/` branch has a clean commit history of incremental improvements
6. The loop stops on `stall ≥ patience` (or max_iterations) — convergence is detected, not forced to the cap
7. The DuckDB database is queryable post-session: `SELECT run_number, decision, metrics_json FROM runs`

**What we learn:**
- Whether the agent makes meaningful simplifications or thrashes
- Whether the safety rails (scope, checks gate, selective revert) actually prevent damage
- Whether stall/patience converges sensibly for a deterministic metric (and, on a noisy objective, whether the within-run MAD noise floor is detected)
- Real-world performance: how many tokens/steps per iteration?
- Whether the extension is production-ready for other objectives

---

## Verification

1. `ailang check` on each `src/core/ext/autoresearch/*.ail` module — must pass type-checking
2. `make check_core` — must not break existing `src/core/*.ail` modules (note: this target doesn't recurse into subdirs, so it won't check autoresearch files directly)
3. Smoke test: scripted session using `StepProvider = Scripted([...])` simulating init → run → log → run → log flow
4. Scope test: scripted session where the agent modifies an off-limits file, verify ar_log rejects without justification
5. Selective revert test: seed an unrelated dirty file (in `init_dirty`), run an iteration, discard — verify the agent's edit reverts but the seeded `init_dirty` file survives untouched; and verify a keep with an edit made *before* `ar_run` actually commits that edit (snapshot-timing regression test)
6. **Checks-gate test:** `ar_run` a change that fails `autoresearch.checks.sh`, then `ar_log(keep)` → rejected; confirm recorded `checks_passed` (not the agent's word) drives it
7. **Metric tests (inline AILANG):** deterministic keep rule (strict improvement); noisy keep rule (median-of-samples must beat within-run MAD); `stall_count` increments on no-improvement keeps and resets on improvement; `on_solver_candidate` blocks until `stall ≥ patience`
8. **State-machine tests:**
   - `ar_run`/`ar_log` before `ar_init` → denied (Setup)
   - `WriteFile`/`EditFile`/`BashExec` after `ar_run` but before `ar_log` → blocked by `on_tool_handle` returning `Handled(failing_envelope)` (AwaitingLog correctness gate)
   - second `ar_run` before logging → denied
   - `ar_log` with wrong `run_number` → rejected
   - `ar_log(discard)` from AwaitingLog → returns to Ready (escape hatch)
   - `derive_state(db)` returns `AwaitingLog` after `ar_run` and `Ready` after `ar_log` — verifying state is reconstructable from the DB alone (compaction safety)
9. Phase 4 end-to-end: run the "Compact Motoko's Core Runtime" objective live and verify all success criteria

---

## Persistence: DuckDB

> **✅ Spike DONE — package + API verified (2026-05-29).** `ailang install sunholo/duckdb@0.1.0` resolves and downloads from the registry. The three-module API matches this plan exactly: `sunholo/duckdb/types` exports `openDB(path) -> DB` (pure), `DB = {path}`, `Row`, `QueryResult`; `sunholo/duckdb/query` exports `query`/`queryAll`/`queryOne`/`scalar` (all `(DB, string) -> Result[…, string] ! {Process}`); `sunholo/duckdb/schema` exports `execScript`/`tableExists`. **One runtime prerequisite remains:** the `duckdb` CLI binary is not on PATH here (the package shells out to it) — install it in the devcontainer/`scripts/install-prerequisites.sh` (Phase 1, step 2). The manifest change from the spike was reverted; `ailang install` will re-add it at implementation time.
>
> **Fallback (still available if you prefer no CLI dep): `std/fs` + `std/process`.** Both modules exist in AILANG 0.19.1 (confirmed via docs MCP). The JSONL fallback stores `runs` as append-only lines via `std/fs`, derives state by reading the last line / a `pending` marker file, and does median/MAD sorting in AILANG. The state machine, scope enforcement, and selective git ops are **persistence-agnostic** — only `db.ail` and `metrics.ail` change.

Use `sunholo/duckdb@0.1.0` for session and run persistence. SQL queries are a natural fit for segment filtering, confidence computation (sorted data via `ORDER BY`), and state reconstruction after compaction — all of which would require manual parsing and sorting over flat JSONL.

**Import paths** (consumers use `pkg/` prefix):
```ailang
import pkg/sunholo/duckdb/types  (DB, Row, QueryResult, openDB)
import pkg/sunholo/duckdb/query  (queryAll, queryOne, scalar)
import pkg/sunholo/duckdb/schema (execScript, tableExists)
```

**DB file**: `.motoko/autoresearch/autoresearch.db`

**Schema:**
```sql
-- DuckDB has NO autoincrement: INTEGER PRIMARY KEY does not auto-assign.
-- Use sequences (or compute max(id)+1 in db.ail).
CREATE SEQUENCE seq_sessions START 1;
CREATE SEQUENCE seq_runs START 1;

CREATE TABLE sessions (
  id INTEGER DEFAULT nextval('seq_sessions') PRIMARY KEY, segment INTEGER, objective TEXT,
  metrics_json TEXT,                 -- includes per-metric {name, direction, noisy}
  scope_paths_json TEXT, off_limits_json TEXT,
  constraints_json TEXT, max_iterations INTEGER, patience INTEGER DEFAULT 3,
  init_dirty_json TEXT,              -- experiment-external WIP, excluded from commit/revert
  status TEXT DEFAULT 'active',      -- active | converged | exhausted | abandoned (drives Done)
  done_reason TEXT,                  -- human-readable terminal reason (queryable post-session)
  baseline_commit TEXT, branch TEXT, ts BIGINT
);

CREATE TABLE runs (
  id INTEGER DEFAULT nextval('seq_runs') PRIMARY KEY, session_id INTEGER, segment INTEGER,
  run_number INTEGER, decision TEXT, metrics_json TEXT, samples_json TEXT, asi_json TEXT,
  changes_summary TEXT, reasoning TEXT, learnings TEXT,
  scope_deviations_json TEXT, justification TEXT,
  flagged BOOLEAN DEFAULT FALSE, flagged_reason TEXT,
  confidence_json TEXT, git_sha TEXT, checks_passed BOOLEAN,
  improved BOOLEAN,                  -- did this kept run improve the primary metric? (drives stall)
  duration_ms INTEGER, iteration_changes_json TEXT, ts BIGINT
);

-- Drives the AwaitingLog state; survives compaction. At most one row per segment.
-- Written by ar_run, deleted by ar_log. Its existence IS the AwaitingLog state.
-- Holds the AUTHORITATIVE benchmark result that ar_log reads (not agent-supplied).
CREATE TABLE pending_runs (
  session_id INTEGER, segment INTEGER, run_number INTEGER,
  metrics_json TEXT, samples_json TEXT, asi_json TEXT,
  checks_passed BOOLEAN, exit_code INTEGER, duration_ms INTEGER, ts BIGINT
);
```

**Advantages over JSONL:**
- `INSERT INTO runs ...` — atomic append (AILANG does have `std/fs.appendFile`, but SQL INSERT is transactional and avoids partial writes)
- `SELECT metric FROM runs WHERE segment = ? AND NOT flagged ORDER BY metric` — sorted data for confidence, no AILANG insertion sort needed
- `SELECT COUNT(*) FROM runs WHERE segment = ?` — iteration count in one query
- State reconstruction for compaction is a single `SELECT`
- Segment/flag filtering is native SQL rather than in-memory list filtering

**Requirements:**
- `duckdb` CLI on PATH (add to `scripts/install-prerequisites.sh` and devcontainer)
- Effects: `Process` for all query/exec functions (already available in `on_tool_handle` hooks)
- Package API across three modules:
  - `pkg/sunholo/duckdb/types`: `openDB(path) -> DB`
  - `pkg/sunholo/duckdb/query`: `query`, `queryAll`, `queryOne`, `scalar` — all `(DB, string) -> Result[_, string] ! {Process}`
  - `pkg/sunholo/duckdb/schema`: `execScript(DB, string) -> Result[(), string] ! {Process}`, `tableExists(DB, string) -> Result[bool, string] ! {Process}`

**Flat files kept:** `autoresearch.md` (prompt-injected text), `autoresearch.sh` (benchmark script), `autoresearch.checks.sh` (optional), `autoresearch.config.json` (human-readable snapshot). Only structured experiment data moves to DuckDB.

### Future: ClickHouse

A ClickHouse AILANG package (`sunholo/clickhouse`) would be a natural follow-on for shipping experiment results to a shared analytics cluster (cross-session, cross-agent analysis). The existing `mcp-clickhouse` MCP server was evaluated but adds too much indirection for local persistence (3-process chain per query). A native AILANG package shelling out to the `clickhouse-client` CLI (same pattern as the DuckDB package) would be the right approach.

---

## Open Questions

1. ~~**Segment UX**: should `new_segment` auto-commit the new baseline?~~ **Resolved:** never auto-commit; both first-call and `new_segment` set `baseline_commit = HEAD` and capture `init_dirty` without committing.
2. ~~**DuckDB availability**~~ **Resolved (2026-05-29):** `sunholo/duckdb@0.1.0` resolves from the registry and the three-module API matches exactly. Using DuckDB; only the `duckdb` CLI binary needs installing in the devcontainer.
3. ~~**In-tree vs package**~~ **Decided: in-tree first.** Ship under `src/core/ext/autoresearch/` for fast iteration (no publish cycle), then extract to `sunholo/motoko_ext_autoresearch` once stable — mirroring how `context_mode` evolved. Easily reversible; registration goes through `registry_generated.ail` either way.
4. ~~**Blocking foreign tools**~~ **Resolved (2026-05-29):** `agent_loop_v2.dispatch_calls` routes every call through `dispatch_tool_policy` → `dispatch_tool_handle`, and `Handled` short-circuits native dispatch — so foreign tools **do** reach the extension's `on_tool_handle`. Canonical names from `tool_catalog.ail`: `ReadFile`/`WriteFile`/`EditFile`/`BashExec`/`RunTests`/`Search`; the `AwaitingLog` gate blocks `{WriteFile, EditFile, BashExec}`.

*(No open questions remain blocking; all were resolved by investigation on 2026-05-29.)*

## Verification Provenance

Hook contracts verified against `sunholo/motoko_ext_abi@2.2.0` (`~/.ailang/cache/registry/.../types.ail`) and the host dispatch logic in `src/core/ext/runtime.ail` (`first_handle`: per-tool iteration, `Handled` wins / `Delegate` falls through). The full per-call pipeline (`dispatch_tool_policy` → `dispatch_tool_handle`, `Handled` short-circuits native dispatch) confirmed in `.packages/motoko_core/src/core/agent_loop_v2.ail` (`dispatch_calls`). Canonical tool names from `.packages/motoko_core/src/core/tool_catalog.ail`. Reference extensions are the active ones in the default `extensions.order` (`context_mode`, `compaction_ai`, `exa_search`, `mcp`) — not `omnigraph`/`openkb`. Language facts (effect enforcement, `Process`/`FS` effects, `std/fs`/`std/process` availability, latest version 0.19.1) verified live via the `ailang-docs` MCP server (`ailang-api` 0.8.1) — now registered in `.mcp.json`. **DuckDB:** `sunholo/duckdb@0.1.0` installed and its `{types,query,schema}` source API inspected directly (`~/.ailang/cache/registry/sunholo/duckdb/0.1.0/`); `openDB`/`query`/`queryAll`/`queryOne`/`scalar`/`execScript`/`tableExists` all present. The `duckdb` CLI binary is the only unmet runtime prereq (GitHub release fetch blocked in the planning sandbox).
