# Fix Scratchpad Graph Output Spilling Into Model Context

Base branch: `origin/main`

## Summary

This branch fixes a context-window blow-up caused by scratchpad graph/image
results being sent back to the model as raw tool-result metadata.

Scratchpad output has two consumers:

- the TUI, which needs full cell payloads including image base64 so it can
  render inline graphs;
- the model, which only needs a compact observation with stdout/stderr,
  exit code, and `[image: path]` references.

Before this change, the model-facing tool message used the same full
`ToolResultEnvelope` serialization as internal/TUI paths. That meant
`metadata.cells` could include large ANSI/image bundles and PNG base64, causing
image-heavy scratchpad runs to re-enter the prompt and risk
`ContextWindowExceededError`.

## Changes

- Add `result_to_model_json` in `src/core/tool_contract.ail` for model-facing
  tool result serialization.
- Strip known-heavy metadata keys from model-facing results:
  - `cells`
  - `images`
  - `jsonOutputs`
- Keep regular `result_to_json` unchanged for non-model consumers.
- Route extension-handled scratchpad/tool results in `agent_loop_v2.ail` through
  the new model serializer.
- Keep `emit_scratchpad_result_if_present` unchanged, so `scratchpad_result`
  still carries full `cells_json` with base64 to the TUI.
- Add a 64 KB hard cap for all tool-role `Message.content` strings, including
  native dispatch results, as defense in depth.
- Add inline AILANG regression tests for:
  - model serialization dropping heavy metadata while preserving scalar fields;
  - tool message content capping behavior.
- Add the implementation plan documenting the root cause and acceptance criteria.
- Update `.gitignore` for local development artifacts:
  - `/ailang/`
  - `.venv-litellm/`
- Refresh `ailang.lock` timestamp from the local lock generation.

## User Impact

Scratchpad graph/image runs no longer send raw cell payloads or PNG base64 back
to the model. The model now receives a small observation like:

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

The TUI still receives full scratchpad cells for inline rendering, so graph
display behavior is preserved.

## Verification

- `ailang check src/core/tool_contract.ail`
- `ailang test src/core/tool_contract.ail`
- `ailang check src/core/agent_loop_v2.ail`
- `ailang test src/core/agent_loop_v2.ail`
- Manual scratchpad graph run with the `scratchpad` extension active.

Manual log inspection of
`.motoko/logfile/session_2026-06-21T12-01-36-774Z.jsonl` confirmed the split:

- `scratchpad_result` events still contained PNG base64 for the TUI:
  - line 55: `107,961` bytes, `has_iVBOR=true`
  - line 296: `348,421` bytes, `has_iVBOR=true`
  - line 445: `307,855` bytes, `has_iVBOR=true`
- model-facing `native_tool_results` events were small and contained no raw
  image/cell payloads:
  - line 56: `528` bytes, `has_iVBOR=false`, no `cells`, no `images`, no
    `jsonOutputs`
  - line 297: `534` bytes, same
  - line 446: `528` bytes, same

Note: AILANG check/test commands emitted unrelated ClickStack trace export
`401 Unauthorized` warnings after successful completion.
