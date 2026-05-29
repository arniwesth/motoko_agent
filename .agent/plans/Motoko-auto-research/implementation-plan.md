# Plan: `motoko_ext_autoresearch` — Autonomous Optimization Loop Extension

## Context

A general-purpose **auto-research extension** for Motoko — inspired by [pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) and [oh-my-pi's autoresearch](https://github.com/can1357/oh-my-pi/tree/main/packages/coding-agent/src/autoresearch) — that can autonomously run optimization loops against any objective. Example: "compact Motoko's codebase by mutating code." This is the foundation layer; recursive self-improvement of hooks (the Layer 2 research) becomes one *use case* of this extension, not the other way around.

### Reference Implementations

| Feature | pi-autoresearch | oh-my-pi | This plan |
|---------|----------------|----------|-----------|
| Persistence | JSONL files | SQLite (WAL mode) | DuckDB via `sunholo/duckdb@0.1.0` |
| Scope enforcement | None | `scope_paths` + `off_limits` + flagging | `scope_paths` + `off_limits` + flagging |
| Git revert strategy | Full `git checkout -- .` | Selective (only run-modified paths) | Selective (only run-modified paths) |
| Segments | None | Multi-segment sessions | Multi-segment sessions |
| Structured metadata | None | `ASI key=value` parsing | `ASI key=value` parsing |
| Tools | 3 (init, run, log) | 4 (+update_notes) | 4 (+ar_notes) |
| Prompt phases | Single | Two-phase (setup + loop) | Two-phase (setup + loop) |
| Branch management | None | Auto `autoresearch/<goal>-<date>` | Auto `autoresearch/<goal>-<date>` |
| Compaction survival | File reconstruction | DB + prompt injection | DuckDB reconstruction via `on_pre_step` |
| Solver gate | None | None (uses auto-resume) | `on_solver_candidate` → `ContinueWithFeedback` |

---

## Architecture Overview

The extension exposes **4 tools** (`ar_init`, `ar_run`, `ar_log`, `ar_notes`) and uses **5 hooks**:

```
Agent loop step
  │
  ├─ on_build_system_prompt → inject phase-appropriate prompt (setup vs loop)
  ├─ on_pre_step → reconstruct state from DuckDB after compaction (incl. current ArState)
  │
  ├─ on_tool_policy → STATE-MACHINE GUARD (runs before every tool, any tool)
  │   └─ Deny illegal transitions: e.g. edit/write/bash while AWAITING_LOG,
  │      ar_run/ar_log before ar_init. Hard Deny, not a nudge.
  │
  ├─ [agent builds harness, then calls ar_init]    (legal only in SETUP)
  │   └─ on_tool_handle → create session, branch, baseline → state becomes READY
  │
  ├─ [agent edits code, then calls ar_run]          (legal only in READY)
  │   └─ on_tool_handle → snapshot dirty paths, persist pending_run, execute benchmark,
  │      parse METRIC + ASI lines → state becomes AWAITING_LOG
  │
  ├─ [agent calls ar_log with keep/discard]         (legal only in AWAITING_LOG)
  │   └─ on_tool_handle → detect scope deviations, INSERT run, clear pending_run,
  │      selective git commit or revert → state becomes READY
  │
  ├─ [agent calls ar_notes to update knowledge base] (legal in READY/AWAITING_LOG)
  │   └─ on_tool_handle → replace or append to session notes
  │
  └─ on_solver_candidate → block premature completion if confidence not met → DONE
```

The agent drives the loop autonomously: edit → benchmark → log → evaluate → repeat. The
**state machine** (see "State Machine Enforcement" below) makes that loop *enforceable*
rather than merely prompt-suggested — illegal tool calls are rejected by `on_tool_policy`
and `on_tool_handle` before they can corrupt the keep/discard accounting.

---

## Package Structure

**In-tree** (like `context_mode`), at `src/core/ext/autoresearch/`. Can be extracted to a package later.

```
src/core/ext/autoresearch/
  register.ail       — entry point: register_with_config(RuntimeConfig) -> ExtensionHooks
  types.ail          — ExperimentConfig, RunEntry, ConfidenceResult, Segment types
  tools.ail          — ToolSchema definitions + argument parsing
  db.ail             — DuckDB schema init, session/run insert/query helpers
  notes.ail          — autoresearch.md file I/O + notes management
  metrics.ail        — MAD confidence scoring (uses DuckDB for sorted data)
  git_ops.ail        — branch mgmt, selective commit/revert, dirty path tracking
  scope.ail          — scope deviation detection + run flagging
  state.ail          — ArState enum, derive_state(db), legal(state, tool) transition guard
  prompts.ail        — two-phase system prompt builder (setup vs loop)
  compaction.ail     — on_pre_step: reconstruct state from DuckDB
```

Pattern reference: `src/core/ext/context_mode/register.ail` (the most complete in-tree extension example).

---

## Tools

### `ar_init` — Initialize or Reconfigure Experiment Session

Creates session directory, files, and git branch. Can also bump to a new segment within an existing session.

Arguments:
- `objective` (string, required) — what to optimize
- `metrics` (array of `{name, direction: "minimize"|"maximize"}`, required) — first entry is the primary metric
- `benchmark_script` (string, required) — bash body for `autoresearch.sh`, must print `METRIC name=value`
- `scope_paths` (array of string, optional) — files/dirs the agent is allowed to modify
- `off_limits` (array of string, optional) — files/dirs the agent must never touch
- `constraints` (array of string, optional) — free-text rules (e.g., "do not remove public API functions")
- `checks_script` (string, optional) — body for `autoresearch.checks.sh`
- `max_iterations` (int, optional, default 20) — per-segment cap
- `new_segment` (bool, optional, default false) — if true, bump segment within existing session
- `session_dir` (string, optional, default `.motoko/autoresearch`)

**On first call:**
1. Creates `autoresearch/<objective-slug>-<date>` branch (collision-safe with numeric suffixes)
2. Commits any pending changes as the baseline
3. Creates session files: `autoresearch.md`, `autoresearch.sh` (chmod +x), `autoresearch.jsonl`, `autoresearch.config.json`, optionally `autoresearch.checks.sh`
4. Writes config entry to JSONL

**On `new_segment: true`:**
1. Increments segment counter
2. Records new baseline commit at current HEAD
3. Abandons any pending (unlogged) run
4. Writes new config entry to JSONL

Returns: `{status: "initialized"|"segment_bumped", session_dir, branch, baseline_commit, segment, files_created}`

### `ar_run` — Run Benchmark

Snapshots dirty paths, executes `autoresearch.sh`, parses output. Arguments:
- `session_dir` (string, optional)
- `timeout_ms` (int, optional, default 60000)
- `label` (string, optional)

**Execution lifecycle:**
1. Capture pre-run dirty paths via `git status --porcelain`
2. Execute `bash autoresearch.sh` with timeout
3. Parse `METRIC name=value` lines from stdout
4. Parse `ASI key=value` lines from stdout (structured metadata)
5. If `autoresearch.checks.sh` exists and benchmark passed, run it
6. **Persist a `pending_runs` row** (run_number, pre_run_dirty paths, metrics, asi, checks) → transitions state to `AwaitingLog`. Pre-run dirty paths live in the DB, not just the returned payload, so selective revert and the state machine survive compaction.

(Legal only in `Ready`; `on_tool_policy` denies `ar_run` in `Setup`/`AwaitingLog`/`Done`.)

Returns:
```json
{
  "status": "completed"|"failed"|"timeout",
  "run_number": 4,
  "metrics": {"tokens_per_step": 1847, "test_pass_rate": 0.95},
  "asi": {"hypothesis": "removing redundant imports saves tokens", "approach": "static analysis"},
  "checks_passed": true|null,
  "exit_code": 0,
  "duration_ms": 3200,
  "stdout_tail": "... last 50 lines ...",
  "stderr_tail": "...",
  "pre_run_dirty_paths": ["src/foo.ail", "src/bar.ail"]
}
```

### `ar_log` — Log Result & Git Action

Appends to JSONL, detects scope deviations, triggers selective git commit or revert. Legal only in `AwaitingLog`. Arguments:
- `run_number` (int, required) — must match the open `pending_runs` row (mismatch → rejected)
- `decision` ("keep" | "discard" | "crash" | "checks_failed", required)
- `metrics` (JSON object, required) — `{metric_name: value}` from the benchmark run
- `changes_summary` (string, required) — what was changed
- `reasoning` (string, required) — why keeping or discarding
- `learnings` (string, optional) — appended to autoresearch.md
- `justification` (string, optional) — required if scope deviations detected and decision is "keep"
- `flag_runs` (array of `{run_number, reason}`, optional) — mark suspect runs to exclude from confidence math
- `asi` (JSON object, optional) — additional structured metadata

**Log lifecycle:**
0. Read the open `pending_runs` row; verify `run_number` matches (else reject)
1. Compute run-modified paths: `current_dirty - pre_run_dirty` (pre_run_dirty from the `pending_runs` row)
2. Detect scope deviations: modified paths outside `scope_paths` or inside `off_limits`
3. If deviations found and `decision == "keep"` and no `justification` → return error demanding justification
4. If `decision == "keep"`: stage and commit only run-modified files, not the whole tree
5. If `decision != "keep"`: revert only run-modified paths via `git checkout HEAD -- <paths>` + remove untracked run-created files
6. Process `flag_runs` — mark flagged runs so they're excluded from confidence calculations
7. Compute MAD confidence (excluding flagged runs)
8. `INSERT` run entry into `runs`, then **`DELETE` the `pending_runs` row** → transitions state back to `Ready`
9. If `learnings` provided, append to autoresearch.md

Returns:
```json
{
  "status": "logged",
  "iteration": 3,
  "segment": 1,
  "git_action": "committed"|"reverted"|"none",
  "commit_sha": "a1b2c3d"|null,
  "scope_deviations": ["tests/unrelated.ail"],
  "flagged": false,
  "confidence": {"tokens_per_step": {"value": 1847, "mad": 42.3, "ratio": 2.1, "confident": true}}
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
| `autoresearch.db` | DuckDB database — sessions + runs tables (see Persistence section) |
| `autoresearch.md` | Objectives, rules, scope, accumulated learnings + ideas. Injected into system prompt. |
| `autoresearch.sh` | Benchmark script. Outputs `METRIC name=value` and optionally `ASI key=value` lines. |
| `autoresearch.checks.sh` | Optional pass/fail validation (exit 0 = pass). |
| `autoresearch.config.json` | Human-readable configuration snapshot (scope_paths, off_limits, constraints, etc.). |

---

## Hook Implementations

### `on_build_system_prompt` — Two-Phase Prompt

**Phase 1 (Setup)**: If `autoresearch.sh` does not exist yet, inject setup instructions:
> "Build the benchmark harness first. Create autoresearch.sh that outputs METRIC lines. Do NOT call ar_run or ar_log before calling ar_init. Optimization starts only after ar_init."

**Phase 2 (Loop)**: If session is active (JSONL exists with config entry), inject:
- Contents of `autoresearch.md` (objectives, scope, learnings, ideas)
- Current segment state: baseline metric, best metric, iterations remaining, unjustified/flagged runs
- Loop protocol: "Edit code → ar_run → ar_log(keep/discard) → repeat. Keep when primary metric improves; discard when it regresses or stays flat. Do NOT declare done until confidence ≥ 2.0."
- Scope enforcement: "Only modify files in scope_paths. Never touch off_limits files. Out-of-scope changes require justification or the run gets flagged."

### `on_pre_step` (Compaction Survival)
If `autoresearch.db` exists but last 5 messages lack autoresearch tool calls → reconstruct summary via DuckDB queries:
- `SELECT segment, objective, max_iterations FROM sessions ORDER BY id DESC LIMIT 1`
- `SELECT COUNT(*), MIN(metrics_json), MAX(metrics_json) FROM runs WHERE segment = ?`
- `SELECT run_number, decision, metrics_json, changes_summary FROM runs WHERE segment = ? ORDER BY run_number DESC LIMIT 5`
- Flagged/unjustified runs: `SELECT run_number, flagged_reason FROM runs WHERE flagged = TRUE AND segment = ?`
- **Current state**: `derive_state(db)` (see State Machine Enforcement). If `AWAITING_LOG`, the summary MUST state the pending `run_number` and that the agent owes an `ar_log` before any further edits — otherwise a post-compaction agent will resume editing and corrupt the dirty-path diff.

Inject as `Compacted(msgs ++ [summary_msg], "autoresearch: session state reconstructed from DB")`. Otherwise `PassThrough`.

### `on_tool_policy` — State-Machine Guard
Runs **before** every tool call (any tool, not just `ar_*`) and is the enforcement floor. Computes `derive_state(db)` then:
- **`SETUP`** (no session row): `Deny` for `ar_run`, `ar_log`, `ar_notes`. Harness-build tools (edit/write/bash/read) and `ar_init` → `NoOpinion`.
- **`AWAITING_LOG`** (pending run not yet logged): `Deny` for `edit`/`write`/`bash` and a second `ar_run`. This is the **correctness gate** — it keeps `pre_run_dirty ↔ current_dirty` diffable. `ar_log`, `ar_notes`, read-only tools → `NoOpinion`.
- **`DONE`**: `Deny` for all `ar_*`.
- **`READY`** and all other cases → `NoOpinion`.

Every `Deny` message names the current state and the legal next actions (e.g. `Deny("AWAITING_LOG: run #4 must be logged with ar_log(decision=keep|discard) before editing. To abandon it, ar_log(discard) or ar_init(new_segment).")`). Recall the engine merges decisions `Deny > Pending > Allow > NoOpinion`, so this co-exists with other extensions' policies.

### `on_tool_handle`
First call `legal(derive_state(db), tool_name)` as a defense-in-depth transition check (mirrors the policy guard; protects against tools that bypass policy). On illegal transition → `Handle({error, current_state, legal_actions})`. Otherwise route `ar_init`/`ar_run`/`ar_log`/`ar_notes` to handlers and return `Delegate` for all other tools.

### `on_solver_candidate`
If active session exists and confidence threshold not met → `ContinueWithFeedback("Autoresearch confidence not reached (current: X, need ≥ 2.0). Continue iterating or call ar_notes to record why you're stopping.")`. If state is `AWAITING_LOG` → `ContinueWithFeedback("Pending run #N must be logged before completion.")`. If max_iterations reached → `NoDecision` (allow completion → `DONE`). Otherwise `NoDecision`.

### Other hooks
`on_budget_plan` → no-op patch, `on_response_intercept` → `NoIntercept`.

---

## State Machine Enforcement

The tool sequence (`ar_init → (ar_run → ar_log)* → done`) is enforced as a state machine, not merely suggested by the prompt. **Why enforcement, not nudging:** the selective commit/revert logic computes `run_modified = current_dirty − pre_run_dirty`. That invariant only holds if *no edits occur between `ar_run` and `ar_log`*. If the agent edits code after benchmarking but before logging, those edits are misattributed to the run, and the selective git op acts on the wrong fileset — silent corruption. A prompt cannot guarantee the run↔log pairing is atomic; a state machine can.

### States

```ailang
-- state.ail
type ArState = Setup | Ready | AwaitingLog | Done
```

| State | Meaning | Legal tools | Illegal calls rejected |
|-------|---------|-------------|------------------------|
| `Setup` | No session row in DB | edit/write/bash/read, `ar_init` | `ar_run`, `ar_log`, `ar_notes` |
| `Ready` | Session exists, no pending run | edit/write, `ar_run`, `ar_notes`, `ar_init(new_segment)` | `ar_log` ("no pending run") |
| `AwaitingLog` | `ar_run` completed, not yet logged | `ar_log`, `ar_notes`, read-only | **edit/write/bash**, second `ar_run` |
| `Done` | confidence met + declared, or max_iterations reached | — | all `ar_*` |

### Transitions

```
   Setup ──ar_init──▶ Ready ──ar_run──▶ AwaitingLog ──ar_log(keep|discard)──▶ Ready  (iteration++)
                        │  ▲                  │
                        │  └──────────────────┘  ar_log(discard) / ar_init(new_segment)  [abandon pending run]
                        └────── on_solver_candidate (confidence ok | max_iter) ──────▶ Done
```

**Escape hatch:** `AwaitingLog` is never a dead end — `ar_log(decision="discard")` or `ar_init(new_segment=true)` both abandon a bad pending run and return to `Ready`.

### State is derived from persisted data (not the conversation)

For the machine to be enforceable *and* survive compaction, the state must be a pure function of the DB — **not** carried in chat messages. This is a change from the original tool contracts, which returned `run_number` + `pre_run_dirty_paths` to the model and read them back as `ar_log` arguments (that does not survive compaction):

```ailang
func derive_state(db: DB) -> ArState ! {Process}
-- Setup       if sessions table empty
-- AwaitingLog if a pending_runs row exists for the current segment
-- Ready       if session exists and no pending run
-- Done        if session marked done OR runs_count >= max_iterations

func legal(state: ArState, tool_name: string) -> Result[(), RejectMsg]
type RejectMsg = { current_state: string, legal_actions: [string], message: string }
```

`ar_run` writes a `pending_runs` row (capturing `run_number` + `pre_run_dirty_paths` durably); `ar_log` clears it. So `run_number` and the pre-run dirty snapshot live in the DB, and a post-compaction agent recovers them via `on_pre_step` rather than from chat history.

### Enforcement layers (defense in depth)

1. **`on_tool_policy`** — the guard. Hard-`Deny`s illegal tools (including edit/write/bash) *before* they execute. Primary enforcement.
2. **`on_tool_handle`** — the transition. Re-checks `legal()` at the top of each `ar_*` handler and returns `Handle({error, current_state, legal_actions})` on violation. Catches anything that bypasses policy and gives actionable errors.
3. **Prompt** (unchanged) — still the *guide*: the state machine is the floor (can't do wrong), the prompt tells the agent what to do next. Complementary, not redundant.

**Decisions locked in:** edit/write/bash are *hard-denied* in `AwaitingLog` (not soft-warned); `ar_run`/`ar_log` are *denied* before `ar_init` (Setup). `ar_init` itself is allowed in Setup regardless of whether `autoresearch.sh` exists yet — harness-first ordering is steered by the prompt, not blocked by the state machine.

## Scope Enforcement

Ported from oh-my-pi's scope deviation detection:

**`scope.ail`** implements:
1. **`compute_modified_paths(pre_run_dirty, current_dirty) -> [string]`** — set difference to isolate run-modified files
2. **`compute_scope_deviations(modified_paths, scope_paths, off_limits) -> [string]`** — paths that are outside `scope_paths` OR inside `off_limits`
3. **`path_matches_spec(path, spec) -> bool`** — prefix matching (e.g., `"src/core/"` matches `"src/core/rpc.ail"`)

If scope deviations are found on a "keep" decision without justification, `ar_log` returns an error:
```json
{"error": "scope_deviation", "deviations": ["tests/unrelated.ail"], "message": "Out-of-scope changes detected. Provide justification parameter or discard."}
```

---

## Metrics & Confidence

MAD-based confidence scoring, leveraging DuckDB for sorted data retrieval:

```sql
-- Get sorted metric values for confidence computation (excludes flagged runs)
SELECT json_extract(metrics_json, '$.tokens_per_step')::DOUBLE AS val
FROM runs WHERE segment = ? AND NOT flagged AND decision = 'keep'
ORDER BY val
```

- **Median + MAD** computed in AILANG over the pre-sorted `[float]` list from DuckDB (no insertion sort needed)
- **Confidence ratio**: `|best_kept - baseline| / MAD`
  - `≥ 2.0` → likely real improvement (green)
  - `1.0 – 2.0` → marginal (yellow)
  - `< 1.0` → within noise (red)
- Returns `None` if < 3 unflagged data points or MAD = 0

```ailang
-- Key type signatures (metrics.ail)
pure func median(sorted_xs: [float]) -> float
pure func mad(sorted_xs: [float]) -> float
func confidence(db: DB, segment: int, metric_name: string, baseline: float) -> Option[ConfidenceResult] ! {Process}

type ConfidenceResult = { value: float, mad: float, ratio: float, confident: bool }
```

**SQL injection caveat**: The duckdb package has no parameterized queries — SQL is constructed via string interpolation. `db.ail` must sanitize all interpolated values (escape single quotes, validate metric names are alphanumeric).

---

## Git Integration

Via `exec("bash", [...])` (same pattern as existing extensions).

### Branch Management
- **On `ar_init`**: Create `autoresearch/<slug>-<YYYYMMDD>` branch, with `-2`, `-3` suffixes for collisions
- Branch name capped at 48 characters
- If already on an `autoresearch/` branch, reuse it

### Selective Commit (Keep)
```bash
# Stage only run-modified files, not the whole tree
git add -- <modified_path_1> <modified_path_2> ...
git commit -m "autoresearch #N: <summary>"
```

### Selective Revert (Discard)
```bash
# Revert only paths modified during the run
git checkout HEAD -- <tracked_modified_path_1> <tracked_modified_path_2> ...
# Remove untracked files created during the run
rm -f <untracked_created_path_1> ...
```

This preserves any pre-existing uncommitted work that wasn't part of the experiment.

### Dirty Path Tracking
- **Before `ar_run`**: capture `git status --porcelain` → `pre_run_dirty_paths`
- **At `ar_log` time**: capture `git status --porcelain` → `current_dirty_paths`
- **Run-modified** = `current_dirty_paths - pre_run_dirty_paths`

---

## Wiring into Motoko

Since the extension is in-tree (not a package), registration follows the `context_mode` pattern:

1. Add import + resolve case to `src/core/ext/registry_generated.ail`:
   ```ailang
   import src/core/ext/autoresearch/register (register_with_config as register_autoresearch)
   -- In resolve():
   else if name == "autoresearch" then Some(register_autoresearch(cfg))
   ```
   Or regenerate via `ailang generate-extension-registry` after adding to `ailang.toml` `[extensions]`.
2. Add `"autoresearch"` to profile's `extensions.order` in `.motoko/config/*/config.json`

**Dependencies**: Requires `sunholo/duckdb@0.1.0` (in registry; run `ailang install sunholo/duckdb@0.1.0` to resolve) and `duckdb` CLI on PATH.

---

## Implementation Phases

### Phase 1: Core (skeleton + tools) — ~3 days
1. Resolve `sunholo/duckdb@0.1.0`: run `ailang install sunholo/duckdb@0.1.0` and regenerate lock file
2. Add `duckdb` CLI install to `scripts/install-prerequisites.sh` and devcontainer; install it now
3. Create module structure at `src/core/ext/autoresearch/`
4. `types.ail` — all domain types (ExperimentConfig, RunEntry, ConfidenceResult, Segment, etc.)
5. `tools.ail` — 4 tool schemas + argument parsing
6. `db.ail` — DuckDB schema creation (`sessions` + `runs` + `pending_runs` tables), insert/query helpers using `pkg/sunholo/duckdb/*`. Include a `sanitize_sql_string` helper to escape single quotes in interpolated values.
7. `notes.ail` — autoresearch.md management
8. `git_ops.ail` — branch creation, dirty path capture, selective commit/revert
9. `scope.ail` — scope deviation detection
9b. `state.ail` — `ArState` enum, `derive_state(db)`, `legal(state, tool) -> Result[(), RejectMsg]` transition guard
10. `register.ail` — hooks wired: `on_tool_policy` (state-machine guard), `on_tool_handle` (legal() check + handlers) + `on_describe_tools`, rest no-op initially
11. Implement `ar_init` handler (create session, branch, baseline, DB schema, files) — Setup→Ready
12. Implement `ar_run` handler (snapshot dirty, persist pending_runs row, execute benchmark, parse METRIC + ASI) — Ready→AwaitingLog
13. Implement `ar_log` handler (verify pending run, scope check, INSERT into runs, delete pending_runs, selective git ops) — AwaitingLog→Ready
14. Implement `ar_notes` handler (replace/append notes)
15. Wire into registry, verify with `ailang check` on each new module
16. Note: `make check_core` only checks `src/core/*.ail` (not subdirs). Use direct `ailang check src/core/ext/autoresearch/*.ail` or add a `check_autoresearch` Makefile target.

### Phase 2: Intelligence — ~2 days
1. `metrics.ail` — median, MAD, confidence scoring using DuckDB sorted queries + segment/flagging filters
2. `on_solver_candidate` — confidence-based completion gating
3. `prompts.ail` — two-phase system prompt injection (setup vs loop)
4. `compaction.ail` — `on_pre_step` state reconstruction from DuckDB queries

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
  metrics: [{ name: "lines", direction: "minimize" }],
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
| Selective revert | Only run-modified files revert on discard; pre-existing work survives |
| Confidence scoring | After 3+ iterations, MAD stabilizes; ratio indicates real vs noise improvements |
| Solver gate | `on_solver_candidate` blocks premature "done" until confidence ≥ 2.0 or max_iterations reached |
| Two-phase prompts | Setup prompt guides harness creation; loop prompt drives optimization |
| Compaction survival | If session exceeds ~20 steps, on_pre_step reconstructs state from DuckDB |
| Branch management | All work happens on `autoresearch/compact-core-YYYYMMDD` branch |
| ar_notes | Agent documents patterns found (e.g., "runtime.ail has 3 nearly-identical fold helpers") |
| DuckDB persistence | Sessions + runs queryable after the session ends |

**Success criteria:**
1. The loop runs autonomously for at least 5 iterations without human intervention
2. At least one "keep" decision produces a measurable line reduction
3. At least one "discard" correctly reverts a broken change
4. `make check_core && make test_core` passes at every "keep" commit
5. The `autoresearch/` branch has a clean commit history of incremental improvements
6. Confidence score is computed and reported after iteration 3+
7. The DuckDB database is queryable post-session: `SELECT run_number, decision, metrics_json FROM runs`

**What we learn:**
- Whether the agent makes meaningful simplifications or thrashes
- Whether the safety rails (scope, checks, selective revert) actually prevent damage
- Whether confidence converges — does the noise floor get detected?
- Real-world performance: how many tokens/steps per iteration?
- Whether the extension is production-ready for other objectives

---

## Verification

1. `ailang check` on each `src/core/ext/autoresearch/*.ail` module — must pass type-checking
2. `make check_core` — must not break existing `src/core/*.ail` modules (note: this target doesn't recurse into subdirs, so it won't check autoresearch files directly)
3. Smoke test: scripted session using `StepProvider = Scripted([...])` simulating init → run → log → run → log flow
4. Scope test: scripted session where the agent modifies an off-limits file, verify ar_log rejects without justification
5. Selective revert test: verify pre-existing dirty files survive a discard
6. **State-machine tests:**
   - `ar_run`/`ar_log` before `ar_init` → denied (Setup)
   - edit/write/bash after `ar_run` but before `ar_log` → denied by `on_tool_policy` (AwaitingLog correctness gate)
   - second `ar_run` before logging → denied
   - `ar_log` with wrong `run_number` → rejected
   - `ar_log(discard)` from AwaitingLog → returns to Ready (escape hatch)
   - `derive_state(db)` returns `AwaitingLog` after `ar_run` and `Ready` after `ar_log` — verifying state is reconstructable from the DB alone (compaction safety)
7. Phase 4 end-to-end: run the "Compact Motoko's Core Runtime" objective live and verify all success criteria

---

## Persistence: DuckDB

Use `sunholo/duckdb@0.1.0` (published in the AILANG registry) for session and run persistence. SQL queries are a natural fit for segment filtering, confidence computation (sorted data via `ORDER BY`), and state reconstruction after compaction — all of which would require manual parsing and sorting over flat JSONL.

**Import paths** (consumers use `pkg/` prefix):
```ailang
import pkg/sunholo/duckdb/types  (DB, Row, QueryResult, openDB)
import pkg/sunholo/duckdb/query  (queryAll, queryOne, scalar)
import pkg/sunholo/duckdb/schema (execScript, tableExists)
```

**DB file**: `.motoko/autoresearch/autoresearch.db`

**Schema:**
```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY, segment INTEGER, objective TEXT,
  metrics_json TEXT, scope_paths_json TEXT, off_limits_json TEXT,
  constraints_json TEXT, max_iterations INTEGER,
  baseline_commit TEXT, branch TEXT, ts BIGINT
);

CREATE TABLE runs (
  id INTEGER PRIMARY KEY, session_id INTEGER, segment INTEGER,
  run_number INTEGER, decision TEXT, metrics_json TEXT, asi_json TEXT,
  changes_summary TEXT, reasoning TEXT, learnings TEXT,
  scope_deviations_json TEXT, justification TEXT,
  flagged BOOLEAN DEFAULT FALSE, flagged_reason TEXT,
  confidence_json TEXT, git_sha TEXT, checks_passed BOOLEAN,
  duration_ms INTEGER, modified_paths_json TEXT, ts BIGINT
);

-- Drives the AwaitingLog state; survives compaction. At most one row per segment.
-- Written by ar_run, deleted by ar_log. Its existence IS the AwaitingLog state.
CREATE TABLE pending_runs (
  session_id INTEGER, segment INTEGER, run_number INTEGER,
  pre_run_dirty_json TEXT, metrics_json TEXT, asi_json TEXT,
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

1. **Segment UX**: Should `ar_init` with `new_segment: true` auto-commit the current state as the new baseline, or require the user to commit first?
