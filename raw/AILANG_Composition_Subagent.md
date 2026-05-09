# AILANG Composition — Subagent Delegation Mode

## Purpose

Evolve the already-implemented inline AILANG composition flow (see
`.agent/plans/AILANG_Composition_Language.md` and
`.agent/summaries/2026-04-11-ailang-composition-language.md`) into a
delegation pattern:

- The **main agent** no longer authors AILANG snippets. It emits a
  high-level intent (natural language + structured parameters) via a new
  `Compose` tool call.
- A **composition subagent** owns the full AILANG authoring lifecycle:
  read the intent, write a snippet, handle type-check retries, execute,
  summarise the result.
- The main agent sees only the final result — it never sees retries,
  type errors, raw stdout explosions, or AILANG source code unless it
  explicitly asks for it.

Subagent mode becomes the **default**. The existing inline mode
(main agent authors AILANG directly, reads retry feedback itself) is
preserved as a **fallback** under an env-var toggle so we can
A/B-compare, debug, and recover if the subagent loop misbehaves.

This is "Option 2" from the design discussion: ship the subagent as a
new feature layered on top of the implemented inline mode, rather than
a rewrite of Phase 0–4.

---

## Why delegate

Observing the inline implementation in live runs surfaced three pain
points that motivate delegation:

### 1. Retry churn in the main agent's context
A failed type-check appends the failing snippet, the stderr from
`ailang check`, and a targeted doc section to the main conversation.
With up to 20 retries per snippet, a composition step that eventually
succeeds can cost the main agent 4× the tokens of a single well-typed
snippet — plus the cognitive load of "I'm supposed to be fixing a bug,
why am I debugging AILANG effect annotations." The main agent's task
is rarely "compose AILANG," it is "edit a TypeScript file" or "find
why a test fails"; AILANG is just the vehicle.

### 2. Two very different skill demands in one prompt
The main agent's system prompt currently carries both the software
engineering guidance *and* the ~2K AILANG reference card. Splitting
the prompts lets each agent focus:
- Main agent: SWE guidance, tool contract, no AILANG details (it only
  needs to know "call `Compose` with an intent and the subagent does
  the rest").
- Subagent: AILANG reference card, expanded stdlib cheat sheet, few-shot
  examples, strict output contract (single snippet, no prose).

### 3. Model-tier mismatch
AILANG snippet authoring is well-scoped and cheap to iterate on. The
main agent runs on Sonnet/Opus-class models because it does judgement
work. The subagent can run on a Haiku-class model (or a cheap local
model) that is more than capable of writing a 20-line snippet and
reacting to `ailang check` errors. The main agent gets 1× Opus calls
instead of 4× Opus calls for the same composition.

---

## Mode selection

A single env var chooses which path `run_ailang_step` takes. The
existing inline flow is preserved byte-for-byte and only engaged when
explicitly requested.

```
AILANG_COMPOSITION_MODE=subagent   (default)
AILANG_COMPOSITION_MODE=inline     (fallback; current implementation)
```

Additionally:

| Var                       | Default            | Purpose                                           |
|---------------------------|--------------------|---------------------------------------------------|
| `AILANG_COMPOSITION_MODE` | `subagent`¹        | `subagent` \| `inline`                            |
| `AILANG_SUBAGENT_MODEL`   | same as main model | Provider/model string used by the subagent        |
| `AILANG_SUBAGENT_MAX_ATTEMPTS` | `50`          | Total snippet-author attempts (initial + retries) |
| `AILANG_SUBAGENT_VERBOSE` | `0`                | preserved for compatibility (expanded-by-default now) |
| `AILANG_SUBAGENT_AUTO_COLLAPSE` | `0`         | `1` collapses compose cards on completion |
| `AILANG_SUBAGENT_CACHE`   | `0`                | `1` enables the intent→snippet cache (Phase 4)    |
| `AILANG_SNIPPET_CAPS`     | `IO,FS,Process`    | (unchanged) effects granted to the snippet        |

¹ End-state default. During Phases 1–2 the default stays `inline`;
Phase 3 flips it to `subagent` once the full path (author loop +
summariser) has been exercised on real tasks.

`subagent` mode also implies a change in how the main agent expresses
composition: it emits a structured tool call, not a raw ```ailang
fence. In `inline` mode the existing ```ailang fence contract is
still honoured.

---

## Surface change for the main agent

Today the main agent emits:

~~~
```ailang
import std/fs (listDir, readFile)
...
export func main() -> () ! {IO, FS} { ... }
```
~~~

In subagent mode, it emits instead a JSON tool call:

```json
{"tool_calls": [
  {
    "id": "c1",
    "tool": "Compose",
    "intent": "List every .ts file under src/tui that imports express, then print each filename with its line count.",
    "expected_output": "one line per file in the form '<path> (<N> lines)'",
    "hints": {
      "read": ["src/tui"],
      "write": [],
      "avoid": ["Net"]
    }
  }
]}
```

Fields:

- `intent` (required) — natural-language description of the operation.
  This is the primary signal the subagent uses to author a snippet.
- `expected_output` (optional) — shape of the stdout the main agent
  wants back; the subagent uses it to gate its own success criterion
  and to produce the final summary line.
- `hints.read` / `hints.write` (optional) — paths the snippet is
  expected to touch. Used for a **second** sandbox tightening layer
  (see Security Model), and as a hint to the subagent about where to
  look.
- `hints.avoid` (optional) — capabilities the main agent explicitly
  does not want granted (e.g. `"Net"`). Enforced by `--caps` stripping.

The main agent's system prompt only needs to know the **shape of the
tool call and when to use it** — roughly the same guidance currently
in the "AILANG composition" section, minus the language reference.

---

## Architectural integration

### Reuse unchanged

The following already exist and are re-used verbatim:

- `POST /exec-ailang` endpoint in `src/tui/src/env-server.ts`
- Module-declaration handling and unique temp-path generation
- `ailang check` + `ailang run` invocation pair, including
  `AILANG_FS_SANDBOX` and the 10s check timeout
- `.motoko-store/` session directory and its SIGINT/SIGTERM cleanup
- `AilangExecResult` record (stdout, stderr, exit_code, check_passed,
  check_errors)
- `exec_ailang` in `src/core/env_client.ail` — the subagent uses the
  **same** endpoint the inline path uses today
- `ailang_error_doc_section` in `src/core/prompts.ail` — now also used
  as the subagent's own retry-prompt material
- `dispatch_solver_candidate` and the rest of the extension system

### Separation of concerns: LLM context vs TUI visibility

The design has two audiences with opposite needs:

- **Main LLM** — must not see retries, snippet source, or type-check
  errors. Keeps its context window focused on the user's task.
- **Developer watching the TUI** — must see everything. Subagent
  snippets, retries, check failures, and streaming tokens are the
  main diagnostic for when a compose call does the wrong thing.

These are already separate channels in the runtime: `msgs: [Msg]` in
`AgentState` is what the main LLM sees next turn; JSONL events on
stdout are what the TUI renders. Subagent activity is **fully
emitted on the JSONL stream and deliberately kept out of `msgs`**.
No trade-off — the same run produces a clean main-agent history and
a fully-populated TUI trace.

See the "TUI visibility" section below for event schema and
rendering.

### New pieces

1. **`Compose` ToolCallReq variant** (`src/core/types.ail`)

   ```ailang
   | Compose({
       id:              string,
       intent:          string,
       expected_output: string,
       hints_read:      [string],
       hints_write:     [string],
       hints_avoid:     [string]
     })
   ```

   `expected_output` and the three hint lists are nullable at the JSON
   layer — `parse_tool_calls` fills blanks with `""` / `[]`.

2. **`ComposeResult` ToolResultItem variant**

   ```ailang
   | ComposeResult({
       id:         string,
       intent:     string,
       stdout:     string,
       stderr:     string,
       exit_code:  int,
       attempts:   int,          -- how many snippets the subagent tried
       summary:    string,       -- subagent-authored one-line summary
       truncated:  bool,
       meta:       ToolResultMeta
     })
   ```

   The main agent sees `summary + stdout`. `attempts > 1` is informational
   only; the main agent is not asked to debug.

3. **`/compose` endpoint in env-server** (new)

   `POST /compose` accepts the `Compose` payload, runs the subagent
   loop described below, and streams `compose_*` events back as
   chunked JSONL (see *TUI visibility*). The subagent loop lives
   entirely inside the env-server process because:

   - The env-server already owns `/exec-ailang` (no new process).
   - It already has `AILANG_FS_SANDBOX` plumbing and cap-string
     handling.
   - The env-server is the natural host; the runtime forwards the
     event stream verbatim so subagent activity reaches the TUI
     without a second stdout pipe.

4. **Subagent system prompt** (`src/core/subagent_prompts.ail` — new
   module, or a second exported function in `prompts.ail`)

   Strict contract:
   - "You receive an intent and constraints. Respond with exactly one
     ```ailang fenced block. No prose outside the fence. No module
     declaration."
   - Full compressed reference card (same ~2K card as today).
   - 3–5 high-signal few-shot examples covering: listDir+filter,
     readFile+filterE, writeFile+encode, process exec, multi-file
     aggregation.
   - Failure mode: if the subagent receives a type-check error, it is
     instructed to return a **new complete snippet**, not a patch.
     Patching is hard; full rewrite with the error as context is
     reliable.

5. **Subagent loop** in env-server (TypeScript)

   ```
   emit compose_start
   attempt = 0
   prior_errors = []
   while attempt < max_attempts:
     attempt += 1
     snippet = llm_call(subagent_prompt, intent, prior_errors)
                                                    -- stream tokens as
                                                    -- compose_author_delta
     emit compose_snippet(attempt, snippet)
     check = ailang check snippet
     emit compose_check(attempt, check.ok, check.errors)
     if not check.ok:
       prior_errors.push(check.errors + error_doc_section(check.errors))
       if attempt < max_attempts:
         emit compose_retry(attempt + 1, reason=check.errors)
       continue
     run = ailang run snippet
     emit compose_exec(run.stdout, run.stderr, run.exit_code)
     summary = llm_call(summary_prompt, intent, run.stdout, run.stderr)
                                                    -- stream tokens as
                                                    -- compose_summary_delta
     emit compose_result(attempts=attempt, stdout=run.stdout,
                         summary=summary, exit_code=run.exit_code)
     return
   emit compose_result(attempts=max_attempts, exit_code=3,
                       summary="subagent exhausted attempts; last error: ...")
   ```

   A single `Compose` call always costs **one step** of the main
   agent's budget, regardless of how many internal attempts the
   subagent uses. Internal attempts do not decrement the step
   counter. (Contrast: inline mode decrements on the 3rd
   type-check failure.)

   Implementation note: the env-server already has Node-side HTTP
   plumbing for calling providers (the frontend handles model-change
   events). The simplest first cut reuses the **same provider call
   path** the main runtime uses, parameterised by
   `AILANG_SUBAGENT_MODEL`. If that wiring is awkward, the env-server
   spawns a second short-lived `ailang run` using `std/ai (call)` and
   a tiny loop module, keeping the subagent fully inside AILANG. See
   "Open Question 1" below.

   Prompt caching: the subagent's system prompt is the full AILANG
   reference card (~2–3K tokens) and stays static across calls.
   Enable provider-side prompt caching (Anthropic: `cache_control`;
   OpenAI: automatic for ≥1024-token prefixes) so the per-call cost
   is only the intent + prior errors + completion.

### Execution flow (subagent mode, happy path)

```
Main agent emits  →  {"tool_calls":[{"tool":"Compose", "intent":..., ...}]}
rpc.ail           →  parse_tool_calls → ToolCallReq::Compose
rpc.ail           →  dispatch: new run_compose_tool(env_url, req)
env_client        →  POST /compose
env-server        →  subagent loop:
                       LLM(author) → ailang check → (retry?) → ailang run
                       LLM(summarise stdout w.r.t. intent)
env-server        →  returns {summary, stdout, stderr, exit_code, attempts}
run_compose_tool  →  ToolResultItem::ComposeResult
main agent sees:     summary + stdout (no retries, no AILANG source)
```

### Execution flow (inline mode, unchanged)

When `AILANG_COMPOSITION_MODE=inline`, `run_ailang_step` is engaged
exactly as today: the main agent writes ```ailang fences, the retry
loop runs in `rpc.ail`, and every retry appears in the main
conversation. No code paths change; the dispatch simply skips the new
`Compose` tool case and falls through to `extract_ailang`.

---

## TUI visibility

Subagent work is fully visible to the developer without ever entering
the main agent's `msgs`. This is achieved with three pieces: a
correlated event schema, a nested-card rendering pattern, and a
streaming pipe from the env-server to the runtime.

### Event schema

All events carry a `compose_id` (the tool-call id the main agent
generated) so the TUI can group them under the parent `Compose` call.
Where behaviour mirrors an existing inline-mode event, the renderer
is reused verbatim — the only new rendering concern is grouping.

```
{"type":"compose_start",        "step":3, "compose_id":"c1", "intent":"...", "model":"anthropic/claude-haiku-4-5", "max_attempts":3}
{"type":"compose_author_delta", "step":3, "compose_id":"c1", "attempt":1, "delta":"import std/fs ..."}    -- streams
{"type":"compose_snippet",      "step":3, "compose_id":"c1", "attempt":1, "code":"..."}                   -- complete snippet
{"type":"compose_check",        "step":3, "compose_id":"c1", "attempt":1, "passed":false, "errors":"..."}
{"type":"compose_retry",        "step":3, "compose_id":"c1", "attempt":2, "reason":"missing FS effect"}
{"type":"compose_snippet",      "step":3, "compose_id":"c1", "attempt":2, "code":"..."}
{"type":"compose_check",        "step":3, "compose_id":"c1", "attempt":2, "passed":true}
{"type":"compose_exec",         "step":3, "compose_id":"c1", "stdout":"...", "stderr":"", "exit_code":0}
{"type":"compose_summary_delta","step":3, "compose_id":"c1", "delta":"Found 3 files..."}                  -- streams
{"type":"compose_result",       "step":3, "compose_id":"c1", "attempts":2, "summary":"...", "exit_code":0}
```

Renderer reuse:

- `compose_snippet` → existing `proposed_ailang` AILANG highlighter
- `compose_check` → existing `ailang_check` pass/fail chip
- `compose_author_delta` / `compose_summary_delta` → same streaming
  markdown/code renderer the main agent uses for `assistant_delta`,
  routed into the nested card

### Nested card rendering

Render the `Compose` tool call as a collapsible section that owns all
its `compose_*` children:

```
▼ Compose  c1                                     model: claude-haiku-4-5
│ intent: List every .ts file under src/tui ...
│ ▼ attempt 1 of 3                                ✗ check failed
│ │ [ailang snippet with highlighting]
│ │ ✗ Effect checking failed: missing effect FS
│ ▼ attempt 2 of 3                                ✓ check passed
│ │ [ailang snippet with highlighting]
│ │ ✓ type-check ok
│ │ ▶ stdout (7 lines)                            (collapsed)
│ ▼ summary
│ │ Found 3 files importing express. Printed ...
└ result                                           attempts=2 · 412ms
```

Collapse/expand at three levels: the whole Compose, a single attempt,
or the stdout block inside a successful attempt.

Default expansion policy:

- **In flight** — fully expanded. Developer sees the snippet being
  authored token-by-token, check results as they land, and the exec
  stdout block populated as soon as `compose_exec` arrives (stdout
  itself is batch, not streamed — matches inline mode's `obs`).
- **After `compose_result`** — auto-collapses to a single-line summary
  showing `attempts`, `exit_code`, duration, and the subagent's
  one-line summary. One keystroke re-expands.
- `AILANG_SUBAGENT_VERBOSE=1` disables the auto-collapse so the full
  trail stays on screen during development sessions.

### Footer status line

While any compose is in flight, the TUI footer shows a single-line
status derived from the most recent `compose_*` event:

```
subagent · attempt 2/3 · check failed: missing FS effect · retrying…
```

Clears when `compose_result` arrives. Gives peripheral awareness
without forcing the card to stay expanded.

### Emission path: env-server → runtime → TUI

The subagent loop runs inside the env-server, but the TUI consumes a
single JSONL stream from the AILANG runtime process. To keep the
runtime as the single event author:

- `POST /compose` responds with **chunked JSONL** (one event per line),
  not a single JSON body. Each line is a `compose_*` event; the final
  line is `compose_result`.
- `run_compose_tool` in `rpc.ail` consumes the chunked response. For
  each event line it receives, it forwards the line verbatim to its
  own stdout (so the TUI sees it as any other runtime event). When it
  sees `compose_result`, it stops forwarding and synthesises the
  `ComposeResult` ADT value for the main-agent history.
- Ordering is preserved because the env-server emits events in the
  order they happen, and `run_compose_tool` forwards them in the
  order they arrive. No buffering games.

This keeps the runtime the single owner of stdout, avoids a second
stdout pipe from the env-server, and means the TUI reader needs zero
changes beyond the new event types.

### Trace persistence

`trace.jsonl` already records main-agent LLM calls. Add a `role`
field and capture subagent calls with `role: "subagent_author"` and
`role: "subagent_summary"`. Greppable after the fact; no new file.

---

## Phased delivery

Across all phases, `AILANG_COMPOSITION_MODE=inline` (the existing
implementation) remains the **default** until Phase 3 lands. The
subagent path is opt-in during Phases 1–2 so we can exercise it on
real tasks before flipping the default.

### Implementation status update (2026-04-12)

This section records what is already implemented in the codebase.

- Phase 1: **implemented**
  - `Compose` added to `ToolCallReq`
  - `ComposeResult` added to `ToolResultItem`
  - parser support for `{"tool":"Compose", ...}` with defaults
  - mode toggle plumbing (`AILANG_COMPOSITION_MODE`)
  - minimal TUI/plain-logger handling for `compose_*` events

- Phase 2: **implemented with Phase 2b completion**
  - `/compose` endpoint implemented with authoring attempts, type-check loop,
    execute, summarize, and final `compose_result`
  - `compose_*` event emission implemented
  - runtime forwarding implemented
  - **Phase 2b (streaming transport): implemented**
    - runtime-side streaming primitive added in `env_client.ail`
    - `/compose` consumed line-by-line and forwarded incrementally
    - previous buffered `httpPost` compose path replaced in `rpc.ail`
  - snippet archival implemented:
    - every generated AILANG snippet is persisted with metadata for offline
      analysis and potential fine-tuning dataset curation
    - current archive path: `src/src/snippets/`
    - companion metadata files (`*.meta.json`) include task/prompt/model/caps
      and outcome fields (`success`, `check_failed`, `run_failed`)

- Phase 3: **partially implemented**
  - summarization pass present in `/compose`
  - default flip to `subagent` in runtime env default is in place
  - expected-output strict sentinel behavior (`exit_code=2` mismatch policy)
    is not fully enforced yet

- Phase 4: **not implemented**
  - intent -> snippet cache remains pending

- Phase 5: **implemented**
  - `ComposeCard` rendering in TUI keyed by `compose_id`, grouping
    `compose_*` events under a dedicated card
  - attempts/snippet/check/exec/summary/result are rendered in the card body
  - compose cards remain expanded on `compose_result` by default to preserve
    streamed snippet/error history; optional collapse via
    `AILANG_SUBAGENT_AUTO_COLLAPSE=1`
  - one-keystroke re-expand/collapse via existing `Ctrl+O` shortcut
  - footer status line includes live subagent progress while compose is in-flight
  - compose-result telemetry counters emitted as `telemetry_json` for
    debugging and research metrics (attempt churn, check-failure categories,
    validator outcomes, summary failures, duration)

- Phase 5b: **implemented (intent-preservation hardening)**
  - runtime now forwards the user’s raw triggering prompt to `/compose`
    (`trigger_prompt`) alongside `intent`
  - subagent author prompt now treats the raw user prompt as the primary
    objective and demotes `intent` to non-binding execution guidance
  - scope guardrails added to author prompt: do not narrow to a strict subset;
    when uncertain, preserve breadth and include additional likely coverage
  - snippet archival now records the primary objective (verbatim trigger when
    present) as the `task` field for downstream research analysis
  - compose hints policy updated: hints remain optional in tool schema, but
    runtime defaults to ignoring/stripping hints unless
    `AILANG_COMPOSE_ENABLE_HINTS=1` is set (opt-in)

- Phase 5c: **implemented (live snippet author streaming)**
  - env-server now runs subagent authoring through `std/ai.callStreamResult`
    in a streamed subprocess path and forwards incremental deltas to TUI via
    `compose_author_delta` while generation is in-flight
  - author subprocess now forces `MOTOKO_STREAM_EVENTS=1` so
    `thinking_delta` events are actually emitted from the AILANG runtime
    and can be bridged to `compose_author_delta`
  - `compose_snippet` remains the canonical finalized artifact after fence
    extraction/normalization; streaming deltas are diagnostic/live draft only
  - compatibility fallback preserved: when no stream deltas are observed,
    env-server emits a single buffered author delta from final output
  - TUI compose-card renderer now displays live `authorDelta` draft content
    before finalized `compose_snippet` arrives, so streamed compose authoring
    is visible during generation
  - compose execution policy hardened: nonzero `ailang run` exit now emits
    `compose_retry` and continues attempts (until success or max attempts),
    instead of terminating immediately on first runtime failure
  - anti-fabrication compose guard added: snippets that include simulated/
    hypothetical-analysis markers or analysis-intent snippets without evidence
    reads (`readFile`/`exec`) are rejected with `compose_check` failure and
    retried with targeted correction hints

### Phase 1 — End-to-end plumbing with stub subagent

Ships the toggle, the `Compose` ADT, and a minimal end-to-end path
with a single-attempt stub. Enough to emit `Compose` tool calls from
the main agent, route them through `run_compose_tool`, and get a
`ComposeResult` back without any of the retry or summarisation
machinery.

- `AILANG_COMPOSITION_MODE` env var plumbed through
  `src/tui/src/index.ts` → runtime process env → read in
  `src/core/rpc.ail`.
- When `inline`: behaviour is bit-for-bit identical to today.
- When `subagent`: `extract_ailang` path is bypassed; main agent is
  expected to emit `Compose` tool calls.
- Types: `Compose` added to `ToolCallReq`, `ComposeResult` added to
  `ToolResultItem` in `src/core/types.ail`.
- Parser: `src/core/parse.ail::parse_tool_calls` accepts
  `{"tool":"Compose", ...}`.
- Dispatch: `run_compose_tool` as a **stub** that makes one LLM call
  with a minimal subagent prompt, feeds the result into `exec_ailang`
  (existing `/exec-ailang` endpoint), and wraps the outcome as a
  `ComposeResult` with `attempts=1`. No retry loop yet.
- TUI: `src/tui/src/runtime-process.ts` registers the `compose_*`
  event types; `src/tui/src/ui.ts` ships a **minimal plain-line
  renderer** (one line per event: `compose attempt 1 — check ok`,
  etc.) so nothing is silently dropped. Polished nested-card
  rendering comes in Phase 5.
- Main-agent system prompt gets a short `Compose` tool description
  (just the contract — no AILANG language details).

Exit criteria: main agent can emit `Compose`, get back a
`ComposeResult`, see plain-line subagent events in the TUI, and the
snippet source never appears in the main-agent `msgs`.

### Phase 2 — Real subagent loop with streaming events

Replaces the stub with the full author-retry loop in the env-server.

- Add `POST /compose` to `src/tui/src/env-server.ts`.
- Move the author-retry logic from `run_compose_tool` into the
  `/compose` handler.
- `/compose` responds with **chunked JSONL** — one `compose_*` event
  per line, ending with `compose_result`. Not a single JSON body.
- Add a streaming HTTP primitive to `src/core/env_client.ail` (e.g.
  `exec_compose_stream(url, req, on_event) ! {Net, IO}`) that reads
  the response body line-by-line and invokes a callback per line.
  Today's `exec_ailang` is batch request/response; chunked-response
  consumption is **new plumbing** for Phase 2, not a free reuse.
  Before implementing, confirm AILANG's `Net` cap exposes the
  necessary streaming reads; fall back to repeated polling of a
  session-scoped event file under `.motoko-store/compose/<id>.events`
  if it does not.
- `run_compose_tool` uses the streaming primitive, **forwards each
  `compose_*` event verbatim to the runtime's stdout**, and on
  `compose_result` synthesises the `ComposeResult` ADT for the
  main-agent history.
- Subagent system prompt (`src/core/subagent_prompts.ail` or
  extension of `prompts.ail`) with full reference card + few-shots +
  strict output contract. Enable provider-side prompt caching for
  the static prefix.
- Attempt accounting: `AILANG_SUBAGENT_MAX_ATTEMPTS` (default 50),
  same error→doc-section mapping that inline mode uses today.
- On exhaustion: `ComposeResult` with `exit_code=3` and a summary
  that quotes the last error.

Exit criteria: subagent handles type-check retries silently, TUI
shows each attempt's snippet + check result as chunked events
arrive, main-agent `msgs` still only contains the `Compose` call and
its `ComposeResult`.

### Phase 3 — Summarisation pass, flip default to subagent

- After a successful `ailang run`, the subagent makes a second LLM
  call: "given the intent and the raw stdout/stderr, produce a
  one-paragraph summary plus, optionally, a condensed stdout suitable
  for the main agent."
- If `expected_output` was supplied, the summariser is instructed to
  check whether the stdout satisfies it; if not, it flags this in
  the summary and the `ComposeResult.exit_code` is set to a sentinel
  (`2`) so the main agent can retry with a clearer intent.
- Large stdout (>N bytes) is elided in `ComposeResult.stdout`; the
  subagent's summary does the compression. Raw stdout remains
  available on disk under `.motoko-store/compose/<id>.stdout` for
  debugging.
- **Flip default**: at the end of Phase 3, change the
  `AILANG_COMPOSITION_MODE` default from `inline` to `subagent`. By
  this point we've exercised the full path on real tasks and have
  the summariser giving the main agent a clean signal.

#### Phase 3b — Output-contract validator and elision policy

To make `expected_output` enforceable (not just advisory), Phase 3 is
extended with a deterministic validator and explicit exit semantics.

- `expected_output` contract format (v1): JSON string with one of:
  - `{"kind":"non_empty"}`
  - `{"kind":"contains_all","tokens":["..."],"case_sensitive":false}`
  - `{"kind":"lines_regex","pattern":"...","flags":"","min_lines":1,"max_lines":200}`
- Validation result shape:
  - `decided` (bool), `satisfied` (bool), `confidence` (`high|low`), `reason` (string)
- Exit-code policy after successful snippet execution:
  - validator `decided=true`, `confidence=high`, `satisfied=false` → force `exit_code=2`
  - otherwise preserve execution exit code (`0` or nonzero runtime code)
- Legacy `expected_output` free-text (non-JSON) is treated as
  validator-inconclusive (`decided=false`, `confidence=low`) and does
  **not** force `exit_code=2`.
- Stdout elision policy:
  - Persist full raw stdout to `.motoko-store/compose/<compose_id>.stdout`
  - Return elided `ComposeResult.stdout` when above
    `AILANG_COMPOSE_STDOUT_MAX_BYTES` (default `4000`)
  - Keep a pointer marker in returned stdout to the on-disk raw path

### Phase 4 — Intent → snippet cache (opt-in)

Gated by `AILANG_SUBAGENT_CACHE=1`; disabled by default until we
have enough subagent runs to validate the key shape.

- Extend SharedMem cache (`src/core/cache.ail`) with a new namespace
  `compose:<task_hash>:<intent_hash>` → snippet.
- On each `/compose` invocation:
  - Compute an intent hash (normalise whitespace, lowercase).
  - Look up the cached snippet. If present and `ailang check` still
    passes against the current workdir, skip the authoring LLM call
    and jump straight to execution.
  - On successful run, cache the snippet.
- Cache invalidation is passive: if `ailang check` fails on a cached
  snippet (e.g. the codebase changed), the subagent falls through to
  the normal authoring loop. The stale entry is overwritten on the
  next success.
- Intent-hash narrowness is a known limitation: semantically
  equivalent intents with different wording miss each other. Fine
  for v1; future work could use intent embeddings.

### Phase 5 — Polished nested-card rendering

Upgrades the plain-line renderer shipped in Phase 1 to the
collapsible nested card described in *TUI visibility*.

- `src/tui/src/ui.ts` — replace the plain-line renderer with a
  `ComposeCard` component keyed by `compose_id`. Routes all
  `compose_*` events to the matching card instead of the top-level
  transcript. Renders:
  - A header line with intent + model
  - One sub-section per attempt (snippet + check result), using the
    existing `proposed_ailang` AILANG highlighter and `ailang_check`
    pass/fail chip
  - A streaming summary block using the existing streaming
    markdown/code renderer
  - A final single-line result row
- Auto-collapse: on `compose_result`, the card collapses to the
  single-line result row by default. `AILANG_SUBAGENT_VERBOSE=1`
  keeps it expanded. Any collapsed card is expandable with a
  keystroke (reuse the existing tool-card expand/collapse shortcut).
- Footer status: derive from the latest `compose_*` event; clear on
  `compose_result`.
- `src/tui/src/index.ts` — keep the PlainLogger one-line-per-event
  fallback from Phase 1 unchanged; CI runs continue to work.

---

## Security model

All the guarantees from the inline plan carry over. Two tightenings
become available because intent is now structured:

### Tighter per-call capability grants

In inline mode the main agent's snippet declares its own effects and
the runtime grants `AILANG_SNIPPET_CAPS` uniformly. In subagent mode
the main agent can tell the subagent "do not use Net" via
`hints.avoid`, and the env-server enforces this by stripping the
named caps from `AILANG_SNIPPET_CAPS` before invoking `ailang run`.

This is strictly additive — the base grant never grows, only shrinks.

### Path-scoped sandboxing (future)

`hints.read` / `hints.write` give us paths the operation *should*
touch. For Phase 2 we only surface these to the subagent as
authoring hints. A later phase can narrow `AILANG_FS_SANDBOX` to the
union of those paths for the duration of one `/compose` call, giving
per-intent sandboxes rather than per-session ones. Not on the
critical path.

### No cross-agent capability escalation

The subagent cannot request caps beyond what the env-server is
configured to grant. The main agent cannot smuggle caps through
intent text — `--caps` is computed from `AILANG_SNIPPET_CAPS` minus
`hints.avoid`, intent text is not parsed for capability directives.

### Snippet retention note (research mode)

This project intentionally retains generated AILANG snippets plus
metadata for research workflows (error analysis, retry-pattern mining,
and future fine-tuning corpus construction). These files are not
ephemeral debug artifacts and should be treated as archival outputs.

---

## Comparison: inline vs subagent

| Dimension                          | Inline (current)                   | Subagent (new default)                     |
|------------------------------------|------------------------------------|--------------------------------------------|
| Who writes AILANG                  | Main agent                         | Subagent                                   |
| Retries visible to main agent      | Yes (up to 3 per step)             | No (collapsed into `attempts` field)       |
| Main-agent prompt size             | +~2K AILANG card                   | +~200 tokens `Compose` tool contract       |
| Main-agent model tier needed       | Same as general SWE                | Same as general SWE                        |
| Subagent model tier                | N/A                                | Can be Haiku / cheap local                 |
| Step budget cost of 3-retry compose| 4× main-model calls                | 1× main + 4× subagent calls                |
| Cache granularity                  | None (each snippet re-checked)     | Intent-keyed reuse                         |
| Debuggability of failures          | High (retries in main transcript)  | High (retries in nested TUI card, not in LLM context) |
| Fallback on subagent failure       | N/A                                | Operator sets `AILANG_COMPOSITION_MODE=inline` |

The subagent-mode trade is deliberate: cleaner main transcript + lower
main-model cost with no debuggability tax — the TUI always shows the
full subagent trace, it just lives in a nested card instead of the
main timeline.

---

## Risks and mitigations

### R1: Intent ambiguity
The main agent might describe an operation loosely, and the subagent
produces a snippet that does something slightly different. Inline
mode has the same risk, but it is more visible.

Mitigations:
- `expected_output` field gives the subagent a success criterion.
- Summarisation pass (Phase 3) flags "stdout does not match
  expected_output" as a soft failure.
- If the main agent finds `ComposeResult.summary` unsatisfying, it
  can call `Compose` again with a more specific intent.

### R2: Silent subagent failures
A subagent that burns many retries (for example, 20) on type errors and surfaces a generic
"could not produce a valid snippet" is unhelpful.

Mitigations:
- `ComposeResult.exit_code` distinguishes "snippet ran, produced
  stdout" (0) from "snippet ran, stdout did not match expected" (2)
  from "subagent could not author a valid snippet" (3) from "snippet
  ran with nonzero exit" (runtime exit code).
- `ComposeResult.summary` always includes the last error when the
  subagent gives up, so the main agent has something actionable.
- Full retry trail is always visible in the TUI's nested Compose
  card — the developer watching live sees every attempt, snippet,
  and check failure without any env-var toggle.

### R3: Cache poisoning
An intent-keyed cache could return a snippet that happens to
type-check but semantically does the wrong thing.

Mitigations:
- Cache key includes the intent hash, not just a task hash — subtle
  intent changes miss the cache.
- Cache stores only snippets that *successfully executed*, not just
  type-checked; still not a correctness guarantee.
- Phase 4 is gated by `AILANG_SUBAGENT_CACHE=1` and disabled by
  default until we have enough subagent runs to validate the key
  shape.

### R4: Subagent model drift
Different subagent models produce different snippet styles, making
debugging harder.

Mitigations:
- `AILANG_SUBAGENT_MODEL` is a single env var — easy to pin.
- Default is "same as main model" initially; only switch to Haiku
  once we have empirical evidence the cheap model is sufficient.
- The subagent's prompt contract is strict enough (one fence, no
  prose) that style drift is bounded.

### R5: Concurrency in env-server
`/compose` is long-running (multiple LLM calls). Multiple in-flight
requests could interleave temp-file paths.

Mitigations:
- Temp-path generation is already unique per invocation
  (`snippet_<counter>_<epoch>.ail` — implemented).
- The env-server already serialises `/exec-ailang` via the Node event
  loop; `/compose` inherits this.

---

## Testing strategy

### Unit tests
- `src/core/parse_test.ail` — JSON parsing for `Compose` tool call
  (happy path, missing optional fields, malformed hints list).
- `src/core/rpc.ail` — mode toggle: `subagent` routes to `Compose`
  dispatch, `inline` routes to `extract_ailang` (existing path).

### Env-server tests (`src/tui`)
- `POST /compose` happy path — stub the LLM provider, assert a
  `ComposeResult` with `attempts=1` and the canned stdout.
- `POST /compose` with mocked LLM that returns bad snippet twice then
  a good one — assert `attempts=3`, success.
- `POST /compose` with mocked LLM that never produces a valid
  snippet — assert exit_code=3, summary mentions last error.
- `hints.avoid=["Net"]` → `--caps` does not contain `Net`.
- `AILANG_COMPOSITION_MODE=inline` → `POST /compose` returns 404 or
  501 (endpoint disabled).

### End-to-end
- Same task run in both modes (`AILANG_COMPOSITION_MODE=subagent` vs
  `inline`) — assert main-agent message-history token counts differ
  by ≥ the size of the retry trail, and final output is equivalent.
- Regression: every existing inline-mode test continues to pass when
  `AILANG_COMPOSITION_MODE=inline`.

---

## Success criteria

1. Main-agent transcript no longer contains AILANG source or
   `ailang check` errors in subagent mode.
2. Main-agent prompt tokens drop by at least the size of the AILANG
   reference card (~2K) in subagent mode.
3. `Compose` tool can be disabled instantly via
   `AILANG_COMPOSITION_MODE=inline` with zero behavioural change from
   today.
4. Subagent handles type-check retries silently up to
   `AILANG_SUBAGENT_MAX_ATTEMPTS`, then surfaces a clear failure
   summary.
5. All existing inline-mode tests pass under `inline` mode. New
   subagent-mode tests pass under `subagent` mode.
6. Subagent activity (snippets, check results, retries, streaming
   author/summary tokens) is visible in the TUI by default, nested
   under the parent `Compose` tool call, without being folded into
   the main agent's `msgs` history.
7. Intent-cache hit rate and subagent retry-count distribution are
   derivable from the existing JSONL event stream and `trace.jsonl`.

---

## Open questions

1. **Where does the subagent's LLM call happen — AILANG or TypeScript?**
   The env-server is Node; calling a provider from Node means
   re-implementing provider selection logic that `std/ai (call)`
   already handles. Two options:

   - (a) Call from TypeScript, using the same provider list the
     frontend already knows about.
   - (b) Spawn a short `ailang run` with a tiny subagent loop module
     that uses `std/ai (call)`. Reuses all existing provider wiring;
     costs one process spawn per `/compose`.

   Lean: (b) for Phase 2, revisit if the spawn cost dominates.

2. **Does the subagent get its own trajectory cache, or share the
   main cache?** Separate namespace (`compose:`) to avoid evicting
   main-agent hints. Covered in Phase 4.

3. **Should `Compose` be available in legacy (non-hybrid) mode?**
   Legacy mode predates JSON tool calls, so `Compose` cannot exist
   there. Concrete behaviour: if `hybrid_enabled=false` and
   `AILANG_COMPOSITION_MODE=subagent`, the runtime logs a one-line
   warning at session start (`subagent mode not supported in legacy
   hybrid-disabled flow; falling back to inline for this session`)
   and silently uses the inline path. No mid-session switching.

4. **Sub-composition**: can the subagent's snippet itself emit a
   `Compose` call (via a tool written in AILANG)? No. Snippets have
   no tool loop. If a composition is too big for one snippet, the
   main agent must issue multiple `Compose` calls.

5. **Migration from inline-authored snippets in the trajectory
   cache**: existing bash/snippet trajectory cache entries are from
   the pre-Compose era. They stay valid for inline-mode runs and are
   ignored by the subagent's intent-keyed cache. No migration needed.

---

## Decision

Ship subagent-mode as the default, behind an env-var flag that
preserves the already-implemented inline mode as a fallback. This
gives us:

- A cleaner main-agent transcript and smaller main-agent prompt
  immediately.
- An easy rollback (`AILANG_COMPOSITION_MODE=inline`) if the subagent
  misbehaves on real traffic.
- An incremental delivery path — Phase 1 proves the tool-plumbing
  end-to-end, Phase 2 brings the real subagent loop, Phase 3 adds
  summarisation and flips the default, Phases 4–5 are optional
  enhancements.

The architectural bet is that AILANG authoring is a **well-scoped
specialist task** that benefits from its own prompt, its own model
tier, and its own retry budget, exactly the same way the existing
tool-call system benefits from being separated from free-form
reasoning.
