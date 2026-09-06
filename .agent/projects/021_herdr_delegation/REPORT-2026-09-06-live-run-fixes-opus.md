# PLAN-001 live-run fixes — report

Repo: `/workspaces/motoko_agent`, branch `arniwesth/013-dst-architecture-adr` (never switched).
Date: 2026-09-06. Model: Opus 5 (`claude-opus-5`).

Six commits, one per fix, all on top of `a24a78a`:

| fix | commit | state |
|---|---|---|
| 1 — truncated tool arguments | `8980ba6` | **partial** (item 1 done; item 2 upstream; item 3 blocked, measured) |
| 2 — hybrid bash in native mode | `650f0e0` | **done** |
| 3 — `Delegate` without a kind | `75ab532` | **done** |
| 4 — two dagr views | `0255215` | **partial by design** (option B only, as instructed) |
| 5 — progress guard busy-poll | `562f821` | **partial** (only the "Second occurrence"; compaction items untouched) |
| 6 — `vundefined` in the transcript | `28a7c67` | **done** |

## Concurrency

`git status --short` at start recorded as dirty and NOT mine: `.agent/issues/progress-guard-…md`,
`.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`,
`…/DESIGN-delegate-model-selection.md`, `.agent/projects/028_…/PLAN-002-…md`, `ailang.lock`,
`src/core/tool_catalog.ail`, `tools/ext_ambient_inventory/fixtures/expected.json`, plus untracked
`docs/`, `little-coder/`, several `.agent/` files.

Two dirty files had to be edited because a fix required it, and both were committed with the fix:

- `.agent/issues/progress-guard-…md` — its whole dirty diff was the "Second occurrence" section
  that fix 5 answers, so committing them together is coherent. (After my commit the other agent
  added a cross-reference to `ADR-002-park-and-wake.md` in it; **left uncommitted, it is theirs**.)
- `.agent/projects/021_herdr_delegation/DESIGN-delegate-model-selection.md` — fix 3's spec is its
  status paragraph. Its dirty diff was that paragraph.

Nothing else dirty was staged. `src/core/tool_catalog.ail`, `ailang.lock`,
`tools/ext_ambient_inventory/fixtures/expected.json`, `DESIGN-dagr-as-delegation-view.md`,
`PLAN-002-…md` and the other agent's new `Makefile` `motoko:` target are untouched and still
uncommitted. **`make sync_packages` was deliberately NOT run** — it ends in `ailang lock`, which
would have rewritten the dirty `ailang.lock`. Package modules were checked and tested directly with
`AILANG_RELAX_MODULES=1 ailang check|test <path>`, which works without a sync.

No fix had to be abandoned for a collision.

---

## Fix 1 — `8980ba6` — partial

**Done (item 1).** New Logical `LedgerEvent` variant `ToolArgumentsUndecodable`
(`tool_arguments_undecodable`; `step, stream_id, tool, id, raw_length`), with the whole ripple:
`phase_vocab` type + variant + projection + byte-level golden, `dst_event_vocabulary` variant id +
wire name + row + both pinned 34→35 counts, `scripts/dst/event_vocabulary_dst.ail` sample.
Emission and refusal at `tool_phase.execute_allowed_tool_call`, before any hook and before any
dispatch. The model now gets `code: "arguments_undecodable"` with the byte count and an instruction
that acts on the measured cause, instead of `missing path`.

**Decisions the issue did not settle:**

1. **The issue's Location section named the wrong site, and I fixed the right one as well.**
   `session.ail:900` `decode_or_empty` and its consumer at `:1073` are the *extension effect*
   bridge (`ext_ports_of`'s `tool_handle`), not the model's native tool path. The model's
   `WriteFile` decodes in `tool_dispatch_adapter.tool_call_to_envelope:47`, whose
   `Err(_) => jo([])` is what produced `missing path`. **Both are closed.** `decode_or_empty` is
   deleted; the bridge now returns a non-zero exit and a sentence rather than a silent `{}` (it has
   no `emit` in scope and returns an `ExtProcOutcome`, not a tool message, so it says the same
   thing in the vocabulary it has).
2. **Blank is not undecodable.** Providers send `""` for a call with no arguments and `decode("")`
   fails, so only a NON-BLANK unparseable string is treated as a truncation. Without this the
   change would have broken every no-argument tool call.
3. **`raw_length`, not the raw string,** on the ledger record: a truncated payload is kilobytes of
   a file the model was writing. The length is what discriminates a malformed emission from an
   exhausted output budget.
4. **`reaches_trace_today: true`** is claimed because the emission site returns the event in
   `execute_allowed_tool_call`'s `emitted` log, which both call sites thread into the trace. No
   `make dst` fixture emits it, so `ledger_parity` prints it under `unwitnessed` — a coverage gap,
   reported by name, floor unmoved at 17.

**Item 2 (output budget): not done, not repo-side.** Unchanged; still an upstream ask.
`std/ai.step` has no output-token parameter.

**Item 3 (`empty_stop_guard` nudge): NOT DONE — the guard cannot see `finish_reason`.** Checked
before assuming, as instructed. `ExtCtx` (`packages/motoko-ext-abi/types.ail:536`) carries: task,
step, model, cwd, hybrid_tools, budget, mode, workdir, env_server_url, budget_remaining,
history_slice, state_key, context_limit, ports, artifacts, telemetry, world. **No `finish_reason`
and no provider result.** A step ending `finish_reason: "length"` with zero tool calls is
indistinguishable from any other empty response inside the guard, so the guard is left alone.
Noted but not built: `telemetry.last_output_tokens` would separate the two cases (a budget-exhausted
step spends the whole cap), but the cap is not in `ctx` either — `context_limit` is the *input*
window — so the guard would compare against a threshold it had to guess. The structural fix is a
`finish_reason` field on `ExtCtx`, an additive ABI change that belongs with an ABI decision.

**Gates:** `make check_core` 0 · `make event_vocabulary` 0 (35 == 35 == 35) · `make invariants` 0 ·
`make ledger_parity` 0 · `ailang test src/core/session.ail` 25/25 ·
`ailang test src/core/tool_phase.ail` 12/12 · `make new_contract_policy` — both new `pure func`s
carry checked excuses.

## Fix 2 — `650f0e0` — done

Option 1 of the issue. `session.ail`'s no-native-tool-calls branch gates `extract_bash` on
`session_emitted_native_tool_call(msgs_with_assistant) == false`. Issue status → `resolved`.

**Decisions the issue did not settle:**

- **The signal is the transcript, not a new `C2LoopState` field.** The issue suggested
  `last_finish_reason`; that is the *previous step's* and cannot answer "ever". An assistant
  message carrying `tool_calls` already records the fact.
- **The `hybrid-step-` id filter is load-bearing** and is why this is not `m.tool_calls != []`.
  The hybrid branch builds an assistant message carrying the *synthesised* call, and that message
  enters `msgs` through `pending_tool_prefix` — a naive check would let one extraction latch
  extraction off for the rest of the run, which *looks* like the fix working and is its opposite.
  Pinned by a test conjunct.
- **Compaction degrades this to today's behaviour**, not to a wrong answer.

**The deterministic test is at the gate expression, not through a full `c2_loop` run.** There is no
in-tree harness that drives the loop with a scripted provider across two steps (`scripts/smoke_v2_hybrid.ail`
only calls `extract_bash` directly and is wired to no target); building one would have been the
larger half of the change. The test asserts *first* that `extract_bash` does extract from its
live-run-shaped fixture, so it cannot pass because the fence quietly stopped matching.

**Gates:** `ailang check src/core/session.ail` 0 · `ailang test src/core/session.ail` 25/25 ·
`make new_contract_policy` — all three new `pure func`s carry checked excuses.

## Fix 3 — `75ab532` — done

Resolution order is now: the call → `HERDR_DELEGATE_KIND` → the allowlist when it holds exactly one
kind → **refuse**, listing the allowed kinds.

**The decision the spec did not settle, and it is why `register.ail:61` is in the task's Location
line.** A literal reading ("more than one allowed and no `kind` on the call ⇒ refuse") would also
refuse an operator who had explicitly set `HERDR_DELEGATE_KIND=motoko`. The extension could not
tell that apart, because `register.ail:61` read `getEnvOr("HERDR_DELEGATE_KIND", default_kind())`
and so `cfg.kind` was `claude` whether the operator had chosen claude or chosen nothing. It now
defaults to `""`, and an operator's choice is honoured however many kinds are allowed. The shipped
single-kind configuration is unchanged. `default_kind()` loses its last caller and is **deleted**.

Two further judgements: the refusal is checked *before* `known_kind` (on that branch `kind` is `""`
and "`` is not an agent kind herdr knows at all" is a true sentence about the wrong problem), and
the **tool schema moved with the handler** — `delegate_params` marks `kind` required and drops
"omit it unless you have a specific reason" exactly when the handler refuses the omission.

**The tests the task pointed at do not exist.** `grep -rn "Delegate" packages/motoko-ext-herdr/*test*`
matches nothing — that package has no `*test*` files; its tests are inline `tests [...]` blocks plus
the `scripts/verify_*.ail` gates. So: inline tests for `allowed_kind_count`/`sole_allowed_kind` in
`types.ail`, and a new gate `scripts/verify_delegate_kind_required.ail` wired in as
`make verify_delegate_kind` and added to `check_core`. Five cases, and the two that must **not**
refuse (the shipped single-kind default, and an operator-set kind) are the expensive half.

**Gates:** `make verify_delegate_kind` 0 (5/5) · `make verify_herdr_gate` 0 · `make check_core` 0 ·
`ailang check` 0 on all three package modules · `AILANG_RELAX_MODULES=1 ailang test types.ail`
253 passed / **12 failed, all pre-existing** (`kind_model_args_test_1..8`, `argv_start_model_test_1..4`;
verified by stashing my diff — 239 passed / the same 12 failed on a clean tree).

## Fix 4 — `0255215` — partial by design (option B only)

`ensure_dagr_pane` consults `operator_view_open` before opening: if `.dagr/.pane` (the sentinel
`scripts/dagr-pane.sh` writes) names a pane, that id goes through `herdr pane get` and must still
answer `"label":"dagr"`. If it does, the extension yields — nothing opened, nothing said, no marker
written. Option A was not attempted. Issue stays `open` with a Progress section: **the two run
files still drift**; only one is now on screen.

**Decisions the issue did not settle:**

- **The marker is probed, not trusted.** A present `.dagr/.pane` says a view was opened once, not
  that it is still up, and pane ids are reused. A stale marker taken at face value would suppress
  the extension's view for the rest of the run with nothing on screen and nothing said — the more
  expensive of the two failures. The probe is the same test that script's own `close_marked` makes.
  Cost: one `herdr pane get` per `Delegate`, and only until this session opens its own view or the
  operator's is found gone.
- **No marker on the yield branch**, so the decision is re-taken next `Delegate`. This is the one
  path through `ensure_dagr_pane` where at-most-once does not apply — nothing was opened.
- **It yields silently**, per the task's "return an empty note" — including dropping the
  `scripts/dagr-pane.sh` fallback sentence, which would be odd advice to someone already looking at
  a dagr view. (A one-line note naming the operator's pane would have been my own preference; the
  spec was explicit, so the spec won.)

**Gates:** `make verify_herdr_dagr_pane` 0 — grew case 6, which asserts `pane get w1:pOP` **is** in
the call log and `plugin pane open` is not; asserting the probe and not merely the absence of the
open is deliberate, because silent stale suppression is invisible to a case that only checks that no
pane appeared. `make verify_dagr_producer` 0 · `ailang check` 0 on all three modules.

## Fix 5 — `562f821` — partial (only the "Second occurrence")

`decide_with_budget` will not nudge while `has_open_delegate(ctx)`. The compaction-era fix items in
that issue are untouched, so it stays `open` with a Progress section.

**Decisions the issue did not settle:**

- **The signal.** `ExtCtx` exposes no in-flight delegate count, so the guard reads the sentences the
  herdr extension wrote into **tool-role** messages of `ctx.history_slice`. Those strings come from
  deterministic code in `herdr.ail`, not from the model — the one predicate in that file reading a
  fact rather than a claim. The *last* delegate signal in the slice wins, so a collected delegate
  stops being open and a second launch reopens.
- **`BLOCKED` is not open.** A delegate waiting for someone to answer a prompt on its screen will
  not progress on its own; that is a thing to report, not work in flight. The guard keeps nudging.
- **Assistant messages are excluded**, for `history_has_contract`'s trap-#1 reason.
- **Re-wording the herdr strings degrades this to a nudge**, not to a wrong allowance — the safe
  direction, and the reason a structured flag on `ExtCtx` is still the better long-term shape.

Four tests; the two the section names are a genuine differential (same candidate, empty slice vs one
launch message → `ContinueWithFeedback` vs `NoDecision`).

**Gates:** `ailang check` 0 · `ailang test progress_contract_guard.ail` **17 passed / 0 failed**
(13 before) · `make check_core` 0 (the extension boots).

## Fix 6 — `28a7c67` — done

`session-logger.ts` carries `ui.ts:2325`'s guard. Issue status → `resolved`. The Fix section's last
question — whether the per-turn re-emit should be its own event type — is a wire-schema change and
is **not** answered; noted in the issue.

Deterministic jest case: one versioned `session_start` then one with nulls; the transcript must hold
exactly one `AILANG built ` line and no `undefined`. It fails against the unguarded writer.

**Gates:** `npx tsc --noEmit` 0 · `npx jest src/session-logger.test.ts` 8 passed / 0 failed.

---

## Full gate sweep at HEAD (`8980ba6`)

```
make check_core              rc=0   (57 src/core modules, 9 extensions booted, every herdr/guard gate)
make event_vocabulary        rc=0   (35 variants == 35 rows == 35 goldens)
make invariants              rc=0
make ledger_parity           rc=0   (witnessed=17, floor 17; ToolArgumentsUndecodable unwitnessed)
make verify_delegate_kind    rc=0   (new)
make verify_herdr_dagr_pane  rc=0
make verify_dagr_producer    rc=0
cd src/tui && npx tsc --noEmit                    rc=0
cd src/tui && bun node_modules/.bin/jest …        250 tests passed, 0 test failures
```

Two pre-existing reds, neither caused by nor touched by this work:

1. **`make new_contract_policy` → `8 of 31 new declarations unjustified`, all in
   `src/core/context_limit.ail`** (`output_token_allowance`, `effective_input_limit`,
   `resolve_bounded_from_profile`, `resolve_bounded_from_catalogue`,
   `raw_window_of_bounded_is_window`, `raw_window_of_unbounded_is_zero`,
   `working_budget_matches_seal_minus_pinned`, `seal_roundtrip_bounded`). That file arrived in
   `a24a78a` and `git diff a24a78a HEAD -- src/core/context_limit.ail` is empty. **Every declaration
   this work added is justified**: five new `pure func`s in `src/core` (three in `session.ail`, two
   in `tool_phase.ail`) plus one renamed test in `dst_event_vocabulary.ail` all carry
   `-- contracts:` excuses that the tool probed and confirmed. The gate will stay red until
   `context_limit.ail` is dealt with — it is diff-relative, so this is a CI red on the branch.
2. **`bun jest`: 5 suites report `You are trying to 'import' a file after the Jest environment has
   been torn down`** (`scratchpad/loopback`, `compose-output-validator`, `env-server`,
   `compose_guard_semiformal`, `test/path-guard`). Teardown noise — 250 tests pass and 0 tests
   fail — and none of the five is a file this work touched. (Plain `npx jest` additionally fails 14
   suites on `TS1343 import.meta`; that is the wrong runner — the repo's own script runs jest
   under `bun`.)

## Things a reviewer should look at

- **Fix 1's ext-bridge change is a behaviour change on the extension path**: a non-blank
  unparseable `args_json` now returns exit 1 with a sentence instead of dispatching with `{}`.
  Every in-tree caller builds that string with `encode`, so nothing in this repo can hit it — but
  it is the one place where a third-party extension passing non-JSON would now be refused.
- **Fix 3 deletes `default_kind()`** and changes `HERDR_DELEGATE_KIND`'s unset value from `claude`
  to `""`. `cfg.kind` had exactly one reader, and all six `scripts/verify_*.ail` fixtures set
  `kind: "claude"` with a single-kind allowlist, so no gate moved. An operator relying on the
  implicit claude default *with a multi-kind allowlist* will now be refused with an explanation —
  which is the point of the fix, and is worth a line in a release note.
- **Fix 4 adds one `herdr pane get` per `Delegate`** until a view exists. `ensure_dagr_pane`'s own
  header argues against pre-flight round-trips on that call; the distinction is that this one
  decides whether to open at all, where the one it argues against would only predict an exit code
  the open reports for free.
