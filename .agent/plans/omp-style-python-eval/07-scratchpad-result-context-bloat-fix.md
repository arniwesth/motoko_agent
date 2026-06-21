# Plan: stop scratchpad cell `metadata` from blowing the model context window

Feature context: the scratchpad/eval tool (plans [01](./01-design-c-mvp-local-loopback.md), [03](./03-eval-tui-card-rendering.md)) and inline image rendering ([plan 04](./04-eval-inline-image-rendering.md)).
Status: **bug fix.** Discovered 2026-06-21 running `PROFILE=bedrock` (model `gpt-bedrock-opus-4-8`) with the `scratchpad` extension active and image/graph output.

## Symptom

A scratchpad run that rendered graphs failed mid-stream:

```
litellm.ContextWindowExceededError: BedrockException: Context Window Error -
  prompt is too long: 1460049 tokens > 1000000 maximum
model=gpt-bedrock-opus-4-8
```

1.46M tokens (~5–6 MB of text) in a single prompt. The scratchpad's rendered
image/ANSI output is ending up **in the model conversation**, not just on screen.

## Root cause

The scratchpad has two output sinks and the model sink wrongly receives the
full, uncapped cell payload.

Verified hop-by-hop (current code, scratchpad naming; this is the same data path
plan 04's hop table describes under the older "eval" names):

| Hop | File:line | Carries full cells (base64 + ANSI)? |
|---|---|---|
| env-server builds response | `src/tui/src/env-server.ts:949-957` — `{ stdout: buildScratchpadTranscript(...) (50 KB cap), cells (UNCAPPED), images, jsonOutputs }`. `spillImages` writes images to disk but does **not** strip `displays[].data` base64 from `cells`. | ✅ |
| brain decodes response | `src/core/env_client.ail:144` — `exec_scratchpad_cell` returns `metadata: obj`, i.e. the **entire** decoded response (incl. uncapped `cells`). | ✅ |
| brain → TUI event (intended) | `src/core/agent_loop_v2.ail:188-201` — `emit_scratchpad_result_if_present` emits `scratchpad_result` with `cells_json = encode(metadata.cells)`. **This is correct** — plan 04 relies on base64 reaching the TUI for inline Kitty/iTerm2 image rendering. | ✅ (by design) |
| brain → **model message** (the bug) | `src/core/agent_loop_v2.ail:776` (scratchpad-handled branch) and `:799` (generic `Handled` branch) — `content: encode(result_to_json(result_env))`. | ✅ **leak** |
| serializer includes metadata | `src/core/tool_contract.ail:31-40` — `result_to_json` emits `metadata` verbatim (line 38), alongside the already-capped `stdout`. | ✅ |

So the tool-role `Message.content` the model sees contains the **full
`metadata.cells`** — every cell's base64 image `data` plus rendered ANSI/text
bundles — re-sent on every subsequent turn. The 50 KB `buildScratchpadTranscript`
cap only governs `stdout`; `metadata.cells` bypasses it entirely.

### Why the existing safeguards don't catch it
- `buildScratchpadTranscript` (`transcript.ts`, `DEFAULT_LIMIT = 50*1024`) caps
  only `stdout`, and correctly renders images as `[image: <path> (WxH mime)]`
  references — but that capped string is *not* the only thing sent to the model.
- `compaction_ai` can shrink history over time, but this is a single-turn
  blow-up that exceeds the window before compaction can run.

### The load-bearing constraint
The base64 in `cells`/`cells_json` is **intentional** for the TUI (plan 04
inline images). The fix must therefore **separate the brain→TUI path (keep full
cells) from the brain→model path (slim)** — it must not strip base64 at the
env-server or in `metadata`, or it regresses inline image rendering.

## Goals

- A scratchpad tool result sent to the model is **bounded** regardless of how
  many images/how much ANSI a cell produces — no single tool message can blow
  the context window.
- The model still receives a useful observation: the capped transcript
  (`stdout`) with `[image: <path> …]` references, stdout/stderr, results, errors,
  and exit code.
- The TUI `scratchpad_result` event is **unchanged** — full `cells` (incl.
  base64) keep flowing for inline image rendering (plan 04).
- Systemic, not scratchpad-only: any extension returning large `metadata` is
  prevented from bloating the model context (per AILANG "audit before patching").

## Non-goals

- No change to the env-server cell payload, the wire/frame protocol, or
  `cells_json` (TUI keeps base64). No kernel changes.
- No change to inline image rendering (plan 04) — this fix is upstream of it on
  the model path and orthogonal on the TUI path.
- Not a rewrite of `metadata` semantics for other tools; only its size on the
  model-facing message is bounded.

## Design

Two layers; layer 1 is the fix, layer 2 is defense-in-depth.

### Layer 1 — model-facing serialization excludes heavy metadata (the fix)

Add a sibling to `result_to_json` in `src/core/tool_contract.ail`:

```
-- Model-facing serialization. Same shape as result_to_json MINUS the heavy,
-- harness-only keys. The model needs stdout/stderr/exit_code (stdout is the
-- already-capped scratchpad transcript with [image: path] refs); it never
-- needs the raw cells/base64 — those go to the TUI via scratchpad_result.
export func result_to_model_json(result: ToolResultEnvelope) -> Json {
  jo([
    kv("tool_call_id", js(result.tool_call_id)),
    kv("tool",         js(result.tool)),
    kv("exit_code",    jnum(_int_to_float(result.exit_code))),
    kv("stdout",       js(result.stdout)),
    kv("stderr",       js(result.stderr)),
    kv("metadata",     sanitize_model_metadata(result.metadata))
  ])
}
```

`sanitize_model_metadata` drops the known-heavy keys (`cells`, `images`,
`jsonOutputs`) and keeps the small scalar keys some tools rely on (e.g. the
`error`/`message` flags set in `tool_envelope_dispatch.ail:20`). Simplest robust
form: rebuild the object from an allowlist of small keys, or strip the denylist
`["cells","images","jsonOutputs"]`.

Then change the two model-message construction sites to use it:
- `agent_loop_v2.ail:776` (scratchpad-handled branch)
- `agent_loop_v2.ail:799` (generic `Handled` branch)

`emit_scratchpad_result_if_present` is called **before** both sites
(`:773`, `:792`) with the full `result_env`, so the TUI event is unaffected.

### Layer 2 — absolute size cap on any tool message content (belt & suspenders)

Even with heavy keys removed, a future tool could return a multi-MB `stdout` or
metadata scalar. Add a single bound when building the tool `Message.content`: if
the encoded content exceeds a cap (e.g. 64 KB), truncate with a explicit marker
(`…[truncated N bytes]`). One helper applied at both sites (and ideally the
Native path, see Audit) guarantees no tool can exceed the budget.

### Audit (systemic)

Grep for every place a tool result becomes a `Message.content` and confirm the
bound applies or the path can't carry large metadata:
- `agent_loop_v2.ail:776`, `:799` — fixed by layer 1+2.
- `agent_loop_v2.ail:744` `tool_result_message(call, result_content)` (Native
  path) — `result_content` is a string from `dispatch_one`; confirm it's already
  bounded or apply the layer-2 cap.
- Delegated/deferred path — confirm results route through the env-server caps.

## Implementation steps

1. `src/core/tool_contract.ail`: add `result_to_model_json` +
   `sanitize_model_metadata` (denylist `cells`/`images`/`jsonOutputs`). Keep
   `result_to_json` as-is for any non-model consumer.
2. `src/core/agent_loop_v2.ail`: swap `result_to_json` → `result_to_model_json`
   at `:776` and `:799`. Leave `emit_scratchpad_result_if_present` untouched.
3. Add the layer-2 content cap helper and apply it where tool `Message.content`
   is built.
4. (Optional, separate) `env-server.ts` `spillImages`/response: drop
   `displays[].data` base64 from `cells` **only if** a TUI-only field retains it
   — DO NOT do this unless inline rendering is confirmed to read from a separate
   field, since `cells_json` currently needs the base64. Default: skip; layer 1
   already fixes the leak.

All changes are interpreted `src/core/*.ail` — **no Go rebuild**; restart Motoko
(and clear `src/core/.ailang/cache` if stale) to pick them up.

## Testing

- **AILANG unit (`tool_contract`):** `result_to_model_json` on an envelope whose
  `metadata` has `cells`/`images` plus a small `error` scalar → output omits
  `cells`/`images`, keeps `error`, keeps `stdout`/`stderr`/`exit_code`.
- **AILANG unit (cap):** content > cap → truncated with marker; ≤ cap → verbatim.
- **TS regression (`env-server`/transcript):** `buildScratchpadTranscript` still
  emits `[image: path]` refs and stays ≤ 50 KB (unchanged).
- **Integration / smoke:** run a scratchpad cell that emits a plot under
  `PROFILE=bedrock` (`gpt-bedrock-opus-4-8`); assert (a) the TUI still renders the
  image (`scratchpad_result`/`cells_json` intact, base64 present) and (b) the
  model tool message size is small (no base64) — inspect
  `.motoko/logfile/*.jsonl`. Re-run the original failing scenario; assert no
  `ContextWindowExceededError`.

## Acceptance criteria

- Reproduction scenario completes without `ContextWindowExceededError`.
- Model-facing scratchpad tool message contains the capped transcript and **no**
  base64 / raw `cells`; size bounded by the layer-2 cap.
- `scratchpad_result` TUI event unchanged (full `cells` incl. base64); inline
  image rendering (plan 04) unaffected.
- No Go/binary changes; fix is in interpreted `.ail` (+ optional TS test).

## Risks / notes

- **Don't strip base64 from the TUI path.** The whole point of plan 04 is that
  base64 reaches the TUI; stripping it at env-server or in `metadata.cells`
  regresses inline images. The split must be brain-side (model vs TUI).
- Some tools read small `metadata` keys downstream; `sanitize_model_metadata`
  must preserve scalars (allowlist or targeted denylist), not nuke `metadata`.
- Operational stopgap until shipped: avoid image-heavy scratchpad cells on
  large-context-sensitive models, or drop `scratchpad` from
  `extensions.order` in the bedrock profile.
```
