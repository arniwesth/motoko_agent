# The PLAN-001 live run: what the 2026-09-05/06 orchestration session settled

Date: 2026-09-06. Source: `.motoko/logfile/session_2026-09-05T16-06-34-724Z.{md,jsonl}` (the
orchestrator, 16 user turns, 300 model steps, 2.1 MB), the four worker logs it spawned
(`session_2026-09-05T16-33-31-824Z`, `16-33-37-788Z`, `19-27-22-982Z`, `19-43-24-730Z`,
`20-13-14-952Z`, `2026-09-06T08-25-06-614Z`), the operator's plan file `.dagr/run-plan001.json`,
and the extension's own run file `.dagr/run-w3-p5-1788624394725.json`.

This is the first time the extension has driven a multi-task plan end to end rather than the
[`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md) probes. The plan is
[`../013_core_architecture_for_dst/PLAN-001-implement-adr-001.md`](../013_core_architecture_for_dst/PLAN-001-implement-adr-001.md).
Model on every pane: `openrouter/meta/muse-spark-1.3-contributor`. Operator env:
`HERDR_ALLOWED_KINDS=claude,motoko`, `HERDR_DAGR_PANE=1`, `HERDR_CHECK_WAIT_MS` unset (20 s).

Every number below is read off the logs, not off a session report. Nothing in this page is a fix;
the fixes are the issue files it links.

## What the plan file says happened

| task | attempts | how it actually got done |
|---|---|---|
| D6 | a1 `failed` (claude, no output) · a2 `done/verified` (motoko, w3:pJ) | delegate |
| P0 | a1 `failed` (claude, no output) · a2 `done/verified` (motoko, w3:pK) | delegate |
| INV | a1 `settled_unverified` (research only) · a2 `failed` (write phase, nothing written) · a3 `done/verified` | **orchestrator wrote it itself**, commit `5088611` |
| P1A | a1 `failed` (3 sessions, no file) · a2 `done/verified` | **orchestrator wrote it itself**, commit `a24a78a` |
| P1B | a1 `working` on w3:pQ since 08:25 | in flight at time of writing, same pathology building |

Two of the four completed tasks were delegated successfully. Both of those were report-writing or
one-line re-pin tasks. **Every delegated task that required writing a source file failed**, and the
plan only advanced because the orchestrator took the work over in its own pane. The takeover is
recorded honestly as a third attempt, which is the right thing for the run file and the wrong thing
for anyone reading "P1A done" as evidence that delegation works.

## Finding 1 — the worker's output budget is spent on reasoning, and the tool call never lands

The shape, identical in every stalled worker:

| worker | steps | steps ending `finish_reason: length` at 4096 output tokens, 0 tool calls | `WriteFile` calls | what those calls carried |
|---|---|---|---|---|
| INV write phase (`19-43-24-730Z`) | 27 | 5 | 1 | `arguments: {}` |
| P1A (`20-13-14-952Z`) | 42 | 5 | 1 (step 36) | `arguments: {}` |
| P1B (`2026-09-06T08-25-06-614Z`, live) | 41 | 3 | 0 | — |

The two `WriteFile` calls are the same failure as the length stops, in a different coat. The step
that produced each one reports `finish_reason: tool_calls` with `output_tokens` of 4176 and 4216,
so the working diagnosis is that the provider returned a tool call whose argument JSON was cut
off and the decoder turned the unparseable string into `{}` without a trace. **Two corrections
(2026-09-06, from the ADR-002 review §7.6 and the live-run fix 1 report):** the decoder on the
model's native path was `tool_dispatch_adapter.tool_call_to_envelope` (`:46–55` at that HEAD),
not `session.decode_or_empty`, which served only the extension bridge — both are now replaced
(`8980ba6`); and the diagnosis is *inferred* from a normalised `{}` plus an output-token count,
because the old decoder kept no raw string. Truncation versus a literal empty object cannot be
told apart from this log. The fix records the raw length on the next occurrence. The tool
runtime then reported `missing path` (`src/core/tool_runtime.ail:444`), which is true but points the
reader at the wrong layer. The orchestrator diagnosed it as "WriteFile is broken in your session"
and told the worker to use heredocs instead, which is the correct workaround for the wrong reason.

Where 4096 comes from is **not located in this repo**. `std/ai.step` (`ailang/std/ai.ail:203`)
takes model, messages and tools and nothing else; there is no output-token parameter to pass, so
the cap is whatever the AILANG runtime or OpenRouter applies by default for this model. That makes
half of the fix an upstream ask. Issue:
[`../../issues/delegate-worker-output-budget-exhausted-and-empty-tool-arguments.md`](../../issues/delegate-worker-output-budget-exhausted-and-empty-tool-arguments.md).

The orchestrator itself never hit the cap in 300 steps. Its turns are short. The workers are asked
to design a module and its contracts before writing it, and a reasoning model fills 4096 tokens
doing that with room to spare.

## Finding 2 — hybrid bash mode executed the model's explanatory examples

Three `hybrid_bash_extracted` events, all in the two turns where the user asked *how* to start
tasks and the model answered in prose with fenced shell examples. The runtime extracted the first
fence of each answer and ran it as a synthesised `BashExec`
(`src/core/session.ail:2853`–`2880`, config `tools.hybrid: true` in
`.motoko/config/default/config.json:27`).

What the extractions did: opened three stray panes (w3:pC, w3:pD, w3:pE), then ran
`herdr agent start d6-worker --kind motoko --pane w3:pX` with the literal placeholder pane id from
the example. That failed with `unsupported interactive agent kind: motoko`, and the model then
reported the failure in its next answer as if it had discovered it deliberately. By the fourth
answer the model had worked out what was happening and rewrote its examples with a `text:` prefix
instead of fences, which is a model routing around its own harness.

This session runs `v2_mode` with native typed tool calls. Hybrid extraction was built for models
that cannot emit those. Issue:
[`../../issues/hybrid-bash-extracts-prose-examples-in-native-tool-mode.md`](../../issues/hybrid-bash-extracts-prose-examples-in-native-tool-mode.md).

## Finding 3 — `Delegate` without a kind is `claude`

The first two `Delegate` calls carried `prompt` and `task_kind` only. `register.ail:61` reads
`HERDR_DELEGATE_KIND` and falls back to `default_kind()` = `"claude"` (`types.ail:430`). Both
claude panes (w3:pF, w3:pH) were gone by the next check (`agent_not_found`), produced no answer
file and no workdir change. The user's report — *"it started claude code instances and not
motoko"* — is exactly [`DESIGN-delegate-model-selection.md`](DESIGN-delegate-model-selection.md)'s
predicted failure, which that design lists as not implemented. Its status line now says so.

## Finding 4 — two run files, and they disagree

The extension writes `.dagr/run-w3-p5-1788624394725.json`, keyed by its own pane and session, and
under `HERDR_DAGR_PANE=1` opened a dagr pane (w3:pG) on it at the first `Delegate`. The operator
already had a dagr pane open on `.dagr/run-plan001.json`, which the orchestrator maintains by hand
through the tmp → `dagr check --strict` → `mv` loop. That second pane is the one the user objected
to.

The two files have drifted. At 08:35 the extension's file records **four delegates as `working`
whose panes no longer exist**: the claude P0 attempt on w3:pH, the INV write phase on w3:pN, and
P1A on w3:pP, plus the live P1B. The orchestrator settled each of those in the plan file by hand
and never called `DelegateCheck` again after taking a task over, so the extension never observed
the end. Neither file is wrong by its own contract. Together they are not one truth.
Issue: [`../../issues/herdr-extension-run-file-drifts-from-operator-plan-file.md`](../../issues/herdr-extension-run-file-drifts-from-operator-plan-file.md);
design question recorded in [`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §10.

There are also 15 older `run-w*-p*-*.json` files in `.dagr/`, and the first `Delegate` result
carried a 200-word "stale delegation record" note listing 11 tasks in them still recorded in
flight. That note is correct and nobody will ever act on it from a tool result.

## Finding 5 — the progress guard turns "waiting on a delegate" into a poll loop

After launching INV the orchestrator's answer ended *"I'll settle it when the answer lands"* and
stopped. `progress_contract_guard` fired (steps 6 and 76 of that turn):

> You stopped while your own response indicates the task is still in progress. Continue the
> existing task now.

So it continued, by polling. That one turn ("Launch it", 19:27 → 19:59) made **195 provider
calls** (corrected 2026-09-06 by the ADR-002 review, §7.6: 195 `thinking` records, 195
`provider_call_prepared`, `steps_executed: 195`; the first version of this page said 193, having
subtracted the two guard-rejected candidates, which were provider calls too). In it: two
`Delegate` launches, 55 `DelegateCheck` calls — every one carrying a delegate name; 50 returned
*"has not written its answer yet (state `working` …)"*, three saw herdr `done` with no answer,
one saw `idle` with no answer, one collected the interim answer — 52 `herdr pane read` commands,
four `send-text` nudges into the worker panes, one `sleep 90` inside a compound command, and
finally the takeover. (The first version of this page said "empty arguments", "~60 reads" and
"two nudges"; all three were wrong.) The user's observation —
*"the polling does not seem to work"* — is accurate: `DelegateCheck` on a motoko delegate watches
the answer file (§3.3 of the dagr design), and a worker that never emits a tool call never writes
one, so every check is truthful and none of them can succeed.

Recorded as a new section of the existing guard issue,
[`../../issues/progress-guard-prose-heuristics-permit-premature-stop.md`](../../issues/progress-guard-prose-heuristics-permit-premature-stop.md),
because the fix is the same guard consulting runtime state instead of prose.
The other half — how a session waits at all without spending steps, and how a motoko delegate
says it is finished — is an architecture decision, recorded as
[`../013_core_architecture_for_dst/ADR-002-park-and-wake.md`](../013_core_architecture_for_dst/ADR-002-park-and-wake.md).

## Finding 6 — the sidecar prints `vundefined` on every turn after the first

`session-logger.ts:275` renders the version banner from every `session_start` event. Only the
runtime-startup one carries `brainVersion` and `ailangBuilt`; the per-turn re-emits carry `null`.
`ui.ts:2325` already guards this for the screen. Issue:
[`../../issues/session-logger-prints-undefined-version-on-conversational-turns.md`](../../issues/session-logger-prints-undefined-version-on-conversational-turns.md).

## What did work, so it is not re-measured

- Motoko-kind delegates start in 0.0 s, come up on the right branch, and both report-shaped tasks
  (D6, P0) settled `done/verified` with the orchestrator independently re-running the check.
- The kind gate refuses what the operator did not allow, and says so in the tool result.
- The plan file passed `dagr check --strict` after every one of the orchestrator's ~20 edits; the
  tmp → check → mv discipline held for the whole session.
- Orphan panes from the claude attempts and the hybrid extractions were found and closed by hand
  within the session; nothing was left running.
- `agent_not_found` on a dead claude pane settled the extension's row `lost`, as
  [`MEASUREMENTS-2026-08-31-failure-codes.md`](MEASUREMENTS-2026-08-31-failure-codes.md) said it would.

## Not measured

Whether a worker on a larger output budget writes the file (the cap was not located, so it was
not raised). Whether claude-kind delegates would have completed the same tasks — both died before
doing anything, for reasons the log does not show (their panes were gone before any read).
Whether `HERDR_CHECK_WAIT_MS` larger than 20 s changes the poll count or only the poll duration.
