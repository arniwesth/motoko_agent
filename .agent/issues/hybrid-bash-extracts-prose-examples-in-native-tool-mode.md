# Hybrid bash mode executes fenced examples from an explanatory answer while native tool calls are in use

## Status

resolved — commit `PLAN-001 live-run fix 2: prose is prose once a session has
emitted a native tool call` on `arniwesth/013-dst-architecture-adr` (2026-09-06).

**Option 1**, which this file calls the smallest of the three. `session.ail`'s
no-native-tool-calls branch now reads
`hybrid_tools && session_emitted_native_tool_call(msgs_with_assistant) == false`
before it calls `extract_bash`. Hybrid mode stays available for its original
consumers — a model that has never emitted a typed call is unaffected — and
`tools.hybrid` stays `true` in the default profile (option 2 not taken).

Three things this file did not settle:

- **The signal is the transcript, not a new `C2LoopState` field.** "Has this
  session ever emitted a native call" is already written down: an assistant
  message carrying `tool_calls`. A state field would be a second home for it.
  (This file suggested `last_finish_reason`, which is the PREVIOUS step's and
  cannot answer "ever".)
- **The `hybrid-step-` id filter is load-bearing.** The hybrid branch builds an
  assistant message carrying the *synthesised* call and that message enters
  `msgs` through `pending_tool_prefix`, so a naive `tool_calls != []` would let
  one extraction latch extraction off for the rest of the run — which looks like
  this fix working and is the opposite of it. It is pinned by a test.
- **Compaction degrades this to today's behaviour**, not to a wrong answer: fold
  the tool-calling turns away and extraction switches back on. Safe direction,
  and it is why the read is per-step rather than latched.

Deterministic test, `test_hybrid_extraction_stops_after_a_native_tool_call` in
`session.ail`: the prose fixture is the live-run shape (placeholder `w3:pX` and
all) and the test asserts FIRST that `extract_bash` does extract from it, so the
case cannot pass because the fence stopped matching. The pin is at the gate
expression rather than through a full `c2_loop` run — there is no in-tree harness
that drives the loop with a scripted provider over two steps, and building one
for this would have been the larger half of the change.

## Branch

`arniwesth/013-dst-architecture-adr` (surfaced during the PLAN-001 live run, 2026-09-05)

## Description

The v2 loop runs with typed native tool calls (`v2_mode` event at session start). The config also
has `tools.hybrid: true`, so on any model response that carries no native tool call the runtime
looks for a fenced shell block, synthesises a `BashExec` from it, and runs it.

When the user asked *"How do we use the herdr extension to actually start the tasks?"* the model
answered in prose with copy-paste examples in ```bash fences. The runtime ran the first fence of
each answer. Over three extractions it opened three panes, then ran
`herdr agent start d6-worker --kind motoko --pane w3:pX` with the placeholder pane id from the
example text. That failed with `unsupported interactive agent kind: motoko`; the model then
presented the failure in its next answer as a finding. By the fourth answer the model had
recognised the pattern and rewrote its examples with a `text:` prefix to stop the harness running
them, which is a model working around its own runtime.

Hybrid extraction was built for models that cannot emit native tool calls. A model that has just
emitted several hundred of them and then writes prose is writing prose.

## Evidence

`.motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl`, three `hybrid_bash_extracted` events:

- session `1788625168256` step 1: the `pane split` / `agent start --kind codex` / `agent prompt`
  example from the first "how to" answer.
- session `1788625393412` step 0: the full D6/P0 example including `test "${HERDR_ENV:-}" = 1` and
  `agent start … --kind motoko --pane w3:pX`.
- session `1788625393412` step 2: the `pane run w3:pX "make claude"` example.

The model's own thinking at 16:24:32: *"prior turns created stray panes by executing placeholder
examples (w3:pX) — cleaned up w3:pC/w3:pD/w3:pE. Must answer prose-only, no fenced bash/sh/shell
blocks (hybrid_tools could auto-execute them)."*

Context: `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`
finding 2.

## Location

- `src/core/session.ail:2853`–`2880` — `extract_bash(result.message.content)` on the
  no-native-tool-calls branch, gated only by `hybrid_tools`.
- `src/core/parse.ail:118` `extract_bash` — matches ```bash, ```sh, ```shell, a bare fence that
  `looks_like_shell`, and finally any line that looks like a shell command.
- `.motoko/config/default/config.json:27` — `"hybrid": true` in the default profile.

## Fix

Pick one; the first is the smallest.

1. **Disable extraction once the session has seen a native tool call.** The loop state already
   knows `last_finish_reason`; a session that has produced `tool_calls` at least once is a native
   session and prose is prose from then on.
2. **Default `hybrid` to false in the default profile** and keep it on only in the profiles for
   models measured to need it.
3. If hybrid must stay on for native sessions, at minimum refuse to extract a block that contains
   an obvious placeholder (`<…>`, `w3:pX`) or more than one command, and never extract from a
   response that is answering a question rather than performing a task. This is heuristic and
   the first option is better.

Deterministic test: a v2 session whose step N emitted a native call and whose step N+1 is prose
with a ```bash fence must produce no `hybrid_bash_extracted` event.

## Non-goals

- Do not remove hybrid mode. Its original consumers (models without typed tool calls) still exist.
