---
repo: arniwesth/motoko_agent
pr: 239
branch: fix/237-unknown-limit-visible
ticket: null
title: "fix: an unknown context limit is no longer silent — a warning everywhere, and a refusal under extensions.strict (#237)"
---

## Summary

Addresses #237, suggestion 1. A model that is in neither the profile (`agent.context_limit`) nor
`.motoko/model-catalog.json` resolves its context limit as `Unknown`. Both shipped compactors take
a percentage of the window, are handed 0, and pass through on every step. Until now the only trace
was the `context_limit_resolved` record on the wire and in the session log (#237: 157 steps, 3k to
260k tokens, nothing compacted).

Two changes. A profile that is not strict still runs exactly as it did, now with a warning.

- **A warning, everywhere a person or a harness reads.** The TUI host turns the `unknown` arm of
  `context_limit_resolved` into a `warning` event, once per distinct resolution and not once per
  turn. It names the model, both misses, the loaded compactors and the two fixes.
- **A refusal under `extensions.strict`.** A strict profile that registers a compactor refuses to
  start, with an `error` and exit 2, when the run's model has no window.

**Host startup code changes** (`src/core/rpc.ail`): one exported function and three calls. A
profile that is not strict performs exactly the reads it did, and every shipped profile has
`strict: false`.

**Plain headless output changes.** The plain logger had no arm for `warning` and dropped all of
them. It now prints each as `[warning] …` on stderr. That includes the runtime's own, among them
two lines AILANG writes on every start (`CACHE_WRITE_FAILED …`, `models registry: source=embedded
…`), which the TUI and the JSONL wire already carried.

**`check_core` gets slower.** The new gate is three runs that each compile the session modules,
3 min 28 s of CPU here. The CI job that runs `check_core` took 12 min 15 s on this pull request,
against 10 min 27 s on `main`'s last run and a 20-minute limit.

Not in it: a fallback window (suggestion 2) and a fixed token threshold (suggestion 3). See "Not
done here".

## Changes

- fix(tui): an unknown context limit is a warning, in the TUI and in headless output (#237)
- feat(core): extensions.strict refuses to start a compactor whose model has no context limit (#237)
- docs(configuration): extensions.strict, the unknown-limit warning, and how to give a model a window

8 files changed.

| file | what |
|---|---|
| `src/tui/src/context-limit.ts` | new: the message for an `unknown` resolution, and `UnknownLimitWatch`, which raises it once per distinct resolution |
| `src/tui/src/context-limit.test.ts` | new: 10 tests, two of them through a real `RuntimeProcess` with a shell script as the runtime |
| `src/tui/src/runtime-process.ts` | raises the `warning` right after the record; `context_limit_resolved` is typed in `AgentEvent` |
| `src/tui/src/index.ts` | the plain logger prints `warning` events on stderr |
| `src/core/rpc.ail` | `reject_if_strict_and_limit_unknown`, called at boot, at the first task after a `model_change`, and on a resume |
| `scripts/verify_strict_context_limit.ail` | new: loads a profile, builds its runtime, hands both to the refusal |
| `Makefile` | `verify_strict_context_limit`, six arms over three runs, added to `check_core` |
| `docs/configuration.md` | what `extensions.strict` refuses; the warning; how to give a model a window; `"disabled"` |

## Governing docs

- `.agent/projects/013_core_architecture_for_dst/ADR-001-sequencing-the-dst-architecture-caps.md`,
  D1 rule 2 ("`Unknown` is visible on every poll and once per run") and its named TypeScript
  follow-up. The warning is that rule reaching a person.
- The same ADR, "Options considered" and "Not decided". It rejected a general refusal under
  `Unknown` (option 4: "loud, not blocking") and left "behaviour under `Unknown` beyond loudness"
  to the owner. The refusal here is narrower than option 4: opt-in through `extensions.strict`, and
  only when a compactor is registered. The operator asked for it on 2026-10-08. The ADR text is
  not edited.
- `docs/configuration.md`, "Model identifiers": compaction for an uncatalogued model "is skipped
  rather than guessed". Unchanged, and the reason there is no fallback window here.
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`: how the seven
  mutants below were chosen, predicted and read.

## What was there, and what was missing

013 ADR-001 D1 made the resolved limit a sum with an `Unknown` arm carrying both misses, a
once-per-run `context_limit_resolved` record, and `context_limit_source` on the status tool. That
made the condition recorded. It did not make it seen:

- nothing in the TUI read the record, so an interactive session showed nothing;
- the plain headless logger dropped every `warning` event, so even a runtime that had warned
  would not have reached a harness reading stderr;
- under `extensions.strict`, a compactor that could never run counted as installed and registered.

## The warning

On the JSONL wire of a real headless run (default profile, an uncatalogued model id), directly
after the record:

```
{"type":"warning","message":"context limit unknown for openrouter/motoko-test/not-a-real-model: the model is not in .motoko/model-catalog.json and the profile sets no agent.context_limit. compaction_ai and compaction_structural cannot trigger without a window, so this session's context will grow uncompacted. Set agent.context_limit in the profile's config.json, or add the model under context_limits in .motoko/model-catalog.json."}
```

- It is raised in `RuntimeProcess`, which already turns the child's stderr lines into `warning`
  events. So the TUI history, the JSONL wire and the transcript show it with no change of their own.
- The compactors are the loaded extensions whose name starts with `compaction_`. The host cannot
  see capabilities; the core side, below, reads them.
- With no compactor loaded it says that context usage is unmeasured instead.
- A declared `disabled` limit is silent. It is a choice written in the profile.
- A TTY runtime serves each follow-up turn as a new run and re-emits the record, so the warning is
  keyed on the model and the two misses. Another uncatalogued model warns again.

## The refusal

`reject_if_strict_and_limit_unknown(cfg, ext_runtime, model)` exits 2 after one line:

```
{"type":"error","error_code":"strict_context_limit_unknown","config_profile":"…","config_dir":"…","message":"extensions.strict: the context limit for 'stub-unknown' is unknown (model_not_in_catalogue, profile_key_absent), so compaction_structural would never compact; refusing to start. Set agent.context_limit in the profile's config.json, or add the model under context_limits in .motoko/model-catalog.json."}
```

- **When:** the profile is strict, at least one registered extension carries a `Compactor` atom,
  and the limit resolves `Unknown`. A compactor is read off the registry's capabilities.
- **Not when:** the limit is `Bounded` or a declared `Disabled`; no compactor is registered; the
  profile is not strict. In the last case the limit is not even resolved here.
- **Where it is asked:** at boot, so a pre-warm TUI spawn refuses before a prompt is spent on it;
  at the first task, only if a `model_change` arrived before it; in `resume_from_journal`, with
  the model the resume will run.
- **In the TUI**, read from `index.ts` and not run: the error is shown and the TUI stays open
  awaiting a task, as it does for any runtime that exits after an `error`. A `/model` switch to a
  catalogued model then starts.
- **Not covered:** a `model_change` after the start. This refuses to start; a later switch to an
  uncatalogued model gets the warning.

`rpc.ail` is the live launcher, above the traced surface, and reads the host ambiently throughout.
A deterministic run drives `run_v2_session_traced` and never reaches it.

## Predicted outcome

Written to two files in the session's scratch directory before the runs they predict, the mutant
table before any mutant ran and the gate list before any gate ran on the core change:

1. `make check_core` exits 0, with six OK lines from the new gate and the four existing ones.
   **Held.**
2. `make verify_core` exits 0 with `main`'s proven and blocked counts. **Held**; the line is the
   one `main`'s CI printed.
3. `make verify_classify_check` exits 0. The one I was least sure of. **Held.**
4. `make new_contract_policy` exits 0 and reports no pure func added. **Held.**
5. `make dst` exits 0 with no target changed, because nothing it runs reaches `rpc.ail`.
   **Held.** The sweep finished after this pull request was opened, and this line and its row
   below were filled in then.
6. Each mutant turns the arm named for it red, and no arm before it. **Held**, seven of seven.

After this lands: a session on an uncatalogued model shows one yellow warning in the TUI and one
`[warning]` line on headless stderr; a strict profile with a compactor refuses such a model with
exit 2; nothing else about any start changes. The fleet in #237 should see the warning for any
model #238 did not add.

## Test evidence

On `bb4424fe` plus the three commits, in a worktree, AILANG v0.47.2. `main` has since moved by a
README-only merge (#236). The machine was shared with other sessions, so the times are upper bounds.

| check | result |
|---|---|
| `make verify_strict_context_limit` | six OK lines |
| `make check_core` | exit 0, 363 s; ten strict lines; `src/core/ type-check: 60 passed, 0 failed` |
| `make verify_core` | exit 0; `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare`, the same line as `main`'s CI run |
| `make verify_classify_check` | exit 0; `17 contracts, register agrees` |
| `make new_contract_policy` | exit 0; `no pure func added under src/core/ since origin/main` |
| TUI `tsc --noEmit` | exit 0 |
| TUI jest (`src/.*\.test\.ts`) | 440 tests pass in 44 suites, 10 of them new. 5 suites fail to load; see "Not done here" |
| `make dst_l2` | 9 pass, 0 fail |
| `make dst` | exit 0, "all targets passed", 2,981 s at `-j8`. Started on `4bab6bd2`; the record commit landed while it ran |

Seven mutants of `src/core/rpc.ail`, one at a time and restored, each confirmed to compile before
its run. The arm was named before the run:

| mutant | rule it breaks | arm that went red | its line |
|---|---|---|---|
| the refusal's `exit(2)` replaced by `()` | strict, compactor and `Unknown` refuse | strict/unknown | `FAIL strict/unknown: rc=0` |
| `cfg.extensions.strict` replaced by `true` | only under strict | lax/unknown | `FAIL lax/unknown: rc=2` |
| `has_compactor` true for any capability | only with a `Compactor` atom | strict/no-compactor | `FAIL strict/no-compactor: rc=2` |
| a `Bounded(_)` arm that exits 2 | a bounded limit starts | strict/bounded | `FAIL strict/bounded: rc=2` |
| a `Disabled` arm that exits 2 | a declared disabled limit starts | strict/disabled | `FAIL strict/disabled: rc=2` |
| the compactor names replaced by a literal | the message names the compactor | strict/unknown | `FAIL strict/unknown: rc=2` |
| the boot call removed from `run_with_config` | the launcher asks at boot | strict/launcher | `FAIL strict/launcher: rc=0` |

Every arm before the red one stayed green. Under the last mutant the launcher ran a one-step stub
session and exited 0, so a launcher that stops asking fails the arm; it does not hang it.

Against the real runtime, by hand, with a model id the provider rejects, so no paid call was made:

- **Warning, JSONL:** default profile. `context_limit_resolved` (`unknown`, `profile_key_absent`,
  `model_not_in_catalogue`) is followed by the `warning` quoted above.
- **Warning, plain:** the same message as `[warning] …` on stderr.
- **Refusal, plain:** a throwaway strict profile with `compaction_structural`, through
  `scripts/run-agent.sh`. stderr has `[error] extensions.strict: the context limit for
  'openrouter/motoko-test/not-a-real-model' is unknown …`; the host exits 1; no provider call.
- **Refusal after a `model_change`:** `supervisor.ail` booted on a catalogued model, then
  `model_change` to an uncatalogued one and a `user_message` on stdin: exit 2, the same error.
- **Not run:** the interactive TUI. It shows `warning` and `error` events through arms `ui.ts`
  already had.

## Not done here

- **No fallback window** (suggestion 2). A guessed window is what `docs/configuration.md` says
  Motoko does not do. With the 65,536-token output reservation, a 128k guess leaves about 62k of
  working budget, so a 75% threshold would fire near 46k tokens on a model that may have 1M.
  `agent.context_limit` already gives a profile its own fallback. This stays ADR-001's open item.
- **No fixed token threshold** (suggestion 3). Worth its own issue: 75% of a 1M window is past
  where cost hurts even for a catalogued model. It is more than a config key, because
  `compaction_ai` also reads the window for its relief check and its fold cap.
- **Two of the three calls have no gate arm.** The first-task call was checked by hand (above).
  The resume call was not exercised at all.
- **The TUI status-bar context counter is not touched, and is dead.** It reads a `context_usage`
  event the runtime has not emitted since `6350b7ad`. ADR-001 D1 names "rendering unmeasured in
  the TUI counter" as a follow-up; there is no live counter to render it in.
- **Five TUI suites fail to load under bun's jest in this container**, with `callSite.getFileName
  is not a function` from `depd`: `env-server`, `compose-output-validator`,
  `compose_guard_semiformal`, `scratchpad/loopback`, `test/path-guard`. The same five fail in an
  untouched checkout. Left as found; no CI job runs them.
- **A clean checkout of `main` warns on every start** that `sunholo/motoko_ext_herdr` content
  changed against `ailang.lock`. Seen in every run above. Left as found.
