# 2026-06-15 eval TUI card + devcontainer data-science packages

## Context

The session started by verifying documentation access:

- Read `README.md`.
- Confirmed `.mcp.json` defines `ailang-docs` at `https://mcp.ailang.sunholo.com/mcp/`.
- Successfully called the AILANG MCP (`ailang_versions`, latest `0.25.0`).
- Confirmed access to mounted/local AILANG docs under `ailang/docs/` and MCP resource `ailang://meta/modules`.

## Eval Rich TUI Card Implementation

Implemented `.agent/plans/omp-style-python-eval/03-eval-tui-card-rendering.md`.

Main changes:

- `src/core/agent_loop_v2.ail`
  - Added `emit_eval_result_if_present`.
  - Emits `eval_result` events for handled eval tool results when `metadata.cells` exists.
  - Uses the model tool call id as `tool_call_id` and request id `step-${step_idx}` for correlation with native result rows.

- `src/tui/src/runtime-process.ts`
  - Added `AgentEvent` variant:
    `{ type: "eval_result"; tool_call_id; request_id; step; cells_json }`.

- `src/tui/src/eval/frames.ts`
  - Added optional `code` and `durationMs` to `EvalCellResult`.

- `src/tui/src/eval/registry.ts`
  - Decorates returned cell results with source `code` and measured `durationMs`.

- `src/tui/src/env-server.ts`
  - Error fallback eval cell results now include `code` and `durationMs`.

- `src/tui/src/ui.ts`
  - Added `EvalCardState`.
  - Added parsing/normalization for `cells_json`, including compatibility with both `displays` and plan-style `display`.
  - Added rich eval renderer:
    - `EVAL · N cells · ✓P ✗F · duration` header.
    - Per-cell `✓/✗ [i/N] title (duration)` header.
    - Python/JS code highlighting through existing `highlightCodeLines`.
    - `─ Output` divider.
    - stdout/stderr previews with existing `Ctrl+O` affordance.
    - JSON display via `highlightJsonLines`.
    - markdown display via existing stream markdown segmentation.
    - image placeholders as `[image: path (WxH mime)]`.
  - Added eval-specific tool-call metadata renderer (`eval-1 eval 2 cells`).
  - `Ctrl+O` toggles the selected rich eval or compose card, with newest rich card taking focus.
  - If no eval card exists, tool output falls back to existing `formatToolDetailLines`.

- Tests:
  - `src/tui/src/runtime-process.stream-protocol.test.ts`: added `eval_result` parser round-trip.
  - `src/tui/src/ui.tool-render.test.ts`: added eval metadata, rich card rendering, collapse affordance, display placeholder, and cells-json normalization tests.

## Validation

Commands run:

- `cd src/tui && bun run build`
  - Passed.

- `make check_core`
  - Passed after fixing local AILANG package resolution.
  - Extension boot probes: `compaction_ai`, `context_mode`, `exa_search`, `eval` all passed.
  - Core type check: 23 passed, 0 failed.

- `node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/.*\\.test\\.ts' --runInBand`
  - Passed all `src/` TUI tests.

Known caveat:

- `cd src/tui && bun run test -- --runInBand` still fails before loading tests with Bun/Jest:
  `TypeError: Attempted to assign to readonly property.`
  Running Jest through Node with `--experimental-vm-modules` works.

AILANG package resolution notes:

- `ailang.toml` had duplicate dependency keys for `sunholo/motoko_ext_abi` and `sunholo/logging`, which caused AILANG to report no parseable `ailang.toml`.
- Removed duplicates and regenerated `ailang.lock`.
- Installed missing registry cache packages with `ailang install`, then `ailang lock` succeeded.

## Devcontainer Python Data Science Packages

User asked to install common data science Python packages in devcontainers:

- pandas
- polars
- numpy
- SciPy
- scikit-learn

Implemented in `scripts/install-prerequisites.sh`:

- Apt packages added for Ubuntu/Debian:
  - `python3-pip`
  - `python3-numpy`
  - `python3-pandas`
  - `python3-scipy`
  - `python3-sklearn`
- Added `install_python_data_science_packages`, called on Debian after Node install.
- Installs Polars via:
  `python3 -m pip install --user --break-system-packages polars`

Reasoning:

- Ubuntu 24.04 apt repo in the dev environment provides NumPy/Pandas/SciPy/scikit-learn, but not `python3-polars`.
- Heavy compiled packages are installed through apt; Polars is installed through user pip.

Validation:

- `bash -n scripts/install-prerequisites.sh` passed.

## Worktree Notes

At the end of the session, modified files included the eval TUI/core changes, `ailang.lock`, and `scripts/install-prerequisites.sh`.

Unrelated/pre-existing worktree items noted:

- `.gitignore` modified.
- `.agent/research/omp-style-python-eval/Screenshot 2026-06-14 at 20.14.52.png` untracked.
