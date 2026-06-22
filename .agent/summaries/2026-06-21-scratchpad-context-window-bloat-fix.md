# 2026-06-21 Scratchpad Context Window Bloat Fix

## Context

Investigated a scratchpad graph/image run that could push the model prompt over
the context window. The failure mode was that scratchpad cell output had two
intended consumers, but both were receiving the same heavy payload:

- The TUI needs full `cells_json` with image base64 so inline graph rendering
  continues to work.
- The model only needs a compact observation: exit code, stdout/stderr, and
  `[image: path]` references.

The bug was on the model path: extension-handled scratchpad results were
serialized with `result_to_json`, which preserved full `metadata`, including
raw `cells`, image bundles, and base64.

## Implementation

Updated `src/core/tool_contract.ail`:

- Added `sanitize_model_metadata`.
- Added `result_to_model_json`.
- Stripped known-heavy model-facing metadata keys:
  - `cells`
  - `images`
  - `jsonOutputs`
- Preserved scalar metadata such as `error` and `message`.
- Kept `result_to_json` unchanged for non-model consumers.
- Added an inline regression test covering heavy-key stripping and scalar
  preservation.

Updated `src/core/agent_loop_v2.ail`:

- Added `cap_tool_message_content`, a 64 KB hard cap for tool-role
  `Message.content`.
- Added `result_env_model_content` to combine model-facing serialization with
  the content cap.
- Swapped extension-handled scratchpad/tool model messages from
  `encode(result_to_json(...))` to `result_env_model_content(...)`.
- Applied the same cap to native dispatcher tool messages.
- Updated response-intercept envelope tool messages to use the model-facing
  serializer.
- Left `emit_scratchpad_result_if_present` untouched so the TUI still receives
  full `cells_json` with base64.
- Added inline regression tests for small-content passthrough and oversized
  content truncation.

Added `.agent/plans/omp-style-python-eval/07-scratchpad-result-context-bloat-fix.md`
with the root-cause analysis, implementation plan, and acceptance criteria.

Added `.agent/prs/mot-15-fix-scratchpad-context-window-bloat.md` with the PR
description for the branch versus `origin/main`.

## Validation

Commands run successfully:

```sh
ailang check src/core/tool_contract.ail
ailang test src/core/tool_contract.ail
ailang check src/core/agent_loop_v2.ail
ailang test src/core/agent_loop_v2.ail
```

Notes:

- AILANG check/test commands passed, but emitted the existing unrelated
  ClickStack trace export `401 Unauthorized` warning after completion.
- These are interpreted `.ail` changes; no Go/binary rebuild was needed.

## Manual Scratchpad Evidence

Ran a scratchpad graph test with the `scratchpad` extension active. Log inspected:

`.motoko/logfile/session_2026-06-21T12-01-36-774Z.jsonl`

The log confirmed the intended split:

- `scratchpad_result` events still contained PNG base64 for TUI rendering:
  - line 55: `107,961` bytes, `has_iVBOR=true`
  - line 296: `348,421` bytes, `has_iVBOR=true`
  - line 445: `307,855` bytes, `has_iVBOR=true`
- model-facing `native_tool_results` events were small and contained no raw
  image/cell payloads:
  - line 56: `528` bytes, `has_iVBOR=false`, no `cells`, no `images`, no
    `jsonOutputs`
  - line 297: `534` bytes, same
  - line 446: `528` bytes, same

The model-facing payload contained only a compact scratchpad observation with
an image path reference, for example:

```json
{
  "tool": "scratchpad",
  "exit_code": 0,
  "stdout": "",
  "stderr": "",
  "metadata": {
    "stdout": "== py cell 1 ==\n[image: .motoko/artifacts/core_ext_v2/cell1-1.png (image/png)]\n[done: exit=0 count=3]",
    "stderr": ""
  }
}
```

## Current Repo State At Summary Time

`git status --short` showed:

- untracked `.agent/prs/mot-15-fix-scratchpad-context-window-bloat.md`
- untracked `.agent/summaries/2026-06-21-scratchpad-context-window-bloat-fix.md`
- unrelated untracked `oh-my-pi/`

The `oh-my-pi/` directory was not touched.
