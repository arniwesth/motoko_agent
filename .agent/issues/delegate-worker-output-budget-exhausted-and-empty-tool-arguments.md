# Delegated workers spend their whole output budget reasoning; truncated tool calls decode to `{}` silently

## Status

open

## Branch

`arniwesth/013-dst-architecture-adr` (surfaced during the PLAN-001 live run, 2026-09-05/06)

## Description

Every motoko delegate asked to write a source file during the PLAN-001 run stalled the same way.
The model (`openrouter/meta/muse-spark-1.3-contributor`, a reasoning model) fills its output
budget designing the module and never reaches the tool call. The step ends
`finish_reason: "length"`, `output_tokens: 4096`, `tool_calls: 0`, the harness sees an empty
response, `empty_stop_guard` nudges, and the next step starts the design from scratch.

When the model does squeeze a `WriteFile` call in, the argument JSON is cut off at the same
boundary. The provider still reports `finish_reason: "tool_calls"`, the runtime decodes the
truncated arguments as an empty object, and the tool runtime reports `missing path`. That error
is true and misleading: the path was there, the whole payload was cut.

Two consequences in the run: two tasks (INV, P1A) were finished by the orchestrator writing the
file itself; the orchestrator told the worker "WriteFile is broken, use heredocs", which is a
workaround for the wrong cause.

## Evidence

| worker log | steps | length stops at 4096 / 0 tool calls | `WriteFile` calls | arguments |
|---|---|---|---|---|
| `.motoko/logfile/session_2026-09-05T19-43-24-730Z.jsonl` (INV write phase) | 27 | 5 | 1 at step 0 | `{}` — step reports `finish_reason: tool_calls`, `output_tokens: 4176` |
| `.motoko/logfile/session_2026-09-05T20-13-14-952Z.jsonl` (P1A) | 42 | 5 | 1 at step 36 | `{}` — `output_tokens: 4216` |
| `.motoko/logfile/session_2026-09-06T08-25-06-614Z.jsonl` (P1B) | 41+ | 3 | 0 | — |

The orchestrator in the same session (`session_2026-09-05T16-06-34-724Z.jsonl`) ran 300 steps and
never hit the cap; its turns are short. Full context in
`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md` finding 1.

## Location

- `src/core/session.ail:900` `decode_or_empty` — `Err(_) => jo([])`. No event, no warning.
- `src/core/session.ail:1073` — the only production consumer; feeds the empty object to the tool.
- `src/core/tool_runtime.ail:444` — `missing path`, the message the worker and orchestrator saw.
- `ailang/std/ai.ail:203` `step(model, messages, tools)` — no output-token parameter exists, so
  the 4096 cap is applied by the AILANG runtime or the provider default. **Not located in this
  repo.** Neither `.motoko/config/default/` nor `src/tui/src/runtime-process.ts` sets one
  (`AILANG_OLLAMA_MAX_TOKENS` is the only related env and is Ollama-only).

## Fix

1. **Make the truncation visible.** When `decode_or_empty` fails on a native tool call, emit an
   event (`tool_arguments_undecodable` or similar, with the tool name and the raw length) and give
   the model a tool result that says the arguments were cut, not `missing path`. This is the
   cheap part and it is what would have let the orchestrator diagnose it in one read.
2. **Raise or expose the output budget.** `std/ai.step` has no parameter for it, so this is an
   upstream ask through the `ailang-feedback` route: either a `max_output_tokens` on `step` and
   `stepWithCache`, or an env the runtime honours per model. Until then, note in the delegate
   task template that a design-then-write task must write first and justify after.
3. **Treat `finish_reason: length` with zero tool calls as its own guard case.** Today
   `empty_stop_guard` nudges "you returned an empty response", which restarts the design. A nudge
   that says "your output was cut at the token limit; emit the tool call first" is a different
   message and the evidence says it is the one needed.

## Non-goals

- Do not change the model. The pathology is budget-shaped, not model-shaped; a different
  reasoning model on the same cap will do the same.
- Do not make the orchestrator take tasks over automatically. That hides the failure rate.

## Progress (2026-09-06)

Status stays **open**: **fix item 1 is done, items 2 and 3 are not.**

Commit `PLAN-001 live-run fix 1: name the truncated tool call instead of
reporting missing path` on `arniwesth/013-dst-architecture-adr`.

### Item 1 — the truncation is visible (done)

New `LedgerEvent` variant `ToolArgumentsUndecodable`, wire name
`tool_arguments_undecodable`, payload `step, stream_id, tool, id, raw_length`,
classified Logical and reaching the returned trace. The full ripple is carried:
`phase_vocab` (type, variant, projection, byte-level golden),
`dst_event_vocabulary` (variant id, wire name, row, 34→35 in both pinned counts),
`scripts/dst/event_vocabulary_dst.ail` (sample). `make event_vocabulary` reports
35 == 35 == 35; `make ledger_parity` lists the new variant under `unwitnessed`,
which is the honest answer — no fixture in `make dst` emits it — and the
witnessed floor of 17 is unmoved.

The emission and the refusal are at
`tool_phase.execute_allowed_tool_call`, **before any hook and before any
dispatch**: the arguments are the call, and a policy decision or an extension
hook run against `{}` is a decision about a call the model did not make. The
model now gets `code: "arguments_undecodable"` with the byte count and the
instruction that acts on the measured cause — emit the tool call first, split a
large `content` — instead of `missing path`.

**The issue's Location section named the wrong site and the fix is at the right
one.** `session.ail:900` `decode_or_empty` and its consumer at `:1073` are the
*extension effect* bridge (`ext_ports_of`'s `tool_handle`), not the model's
native tool path; the model's `WriteFile` decodes in
`tool_dispatch_adapter.tool_call_to_envelope:47`, whose `Err(_) => jo([])` is the
fallback that produced `missing path`. Both are closed. `decode_or_empty` is
deleted and the bridge now reports a non-zero exit and a sentence rather than a
silent `{}` — it has no `emit` in scope and returns an `ExtProcOutcome`, not a
tool message, so it says the same thing in the vocabulary it has.

Blank is not undecodable, on both paths: providers send `""` for a call with no
arguments and `decode("")` fails, so only a NON-BLANK string that will not parse
is treated as a truncation.

### Item 2 — the output budget (not done, and not repo-side)

Unchanged and still an upstream ask through the `ailang-feedback` route.
`std/ai.step` has no output-token parameter, and this branch adds none.

### Item 3 — the `empty_stop_guard` nudge (NOT DONE — the guard cannot see it)

Checked before assuming, as the fix asks. **`ExtCtx` carries no `finish_reason`
and no per-step provider result** (`packages/motoko-ext-abi/types.ail:536`): the
fields are task, step, model, cwd, hybrid_tools, budget, mode, workdir,
env_server_url, budget_remaining, history_slice, state_key, context_limit, ports,
artifacts, telemetry, world. A step ending `finish_reason: "length"` with zero
tool calls is indistinguishable, from inside the guard, from any other empty
response. The guard is therefore left alone rather than given a nudge it cannot
condition on.

The nearest signal that IS in `ctx` is `telemetry.last_output_tokens` — a
budget-exhausted step spends the whole cap while an ordinary empty stop spends
almost nothing — but the cap itself is not in `ctx` either (`context_limit` is
the INPUT window), so the guard would be comparing a number against a threshold
it would have to guess. Recorded rather than built. The structural fix is a
`finish_reason` on `ExtCtx`, which is an additive ABI field and belongs with a
decision about the ABI, not with this issue.
