---
repo: arniwesth/motoko_agent
pr: null
branch: arniwesth/mot-129-extension-abi-phase-a
ticket: MOT-129
title: "MOT-129: extension abi phase a"
---

## Summary

This branch takes the extension ABI from 5.0 to 6.0. The fixed `ExtensionHooks` record is
replaced by a `Capability` sum and a list-shaped registry -- `ExtEntry { id, caps }`,
`ExtRegistry { entries }` -- so an extension registers the atoms it actually binds instead of
tiling a record of neutral slots, and multiplicity is *validated* at the registration boundary
rather than assumed by shape. Seventeen packages, the host dispatch layer, the profile layer and
the DST/test fixtures move with it, `registry_generated.ail` becomes generator-produced (D10)
instead of hand-edited, and the HookSlot half is deleted so there is one dispatch table.

Phase A also lands the limitation probes that decided D8/D9/B1 (record-update position,
consumption-side match-out, constructor-argument rows), and a TUI boot pre-spawn so the AILANG
module load overlaps with the user typing their first prompt.

Base is `main_dst`, not `main`.

## Changes

- MOT-129 A1: hook_scope learns the default_hooks record-update head; land default_hooks(id)
- MOT-129 A2: derive declared_vs_performed's subject list from the registry (15 -> 17)
- MOT-129 A3: lock the holder-stamp grammar; refresh ailang.lock for the ABI minor
- MOT-129 A4: record-update-position limitation probe (decides D8)
- MOT-129 A5: migrate the probe's own safe literals to default_hooks
- MOT-129 D9: pin the consumption-side (match-out) limitation probe, measured on v0.33.0
- MOT-129 B1: constructor-argument limitation probe, register_with_config mutant, five-part producer-3 rationale
- MOT-129 B2: hook_scope.locate() learns the 6.0 literal list-of-constructors head
- MOT-129 B3: coverage unit (extension, kind, index) + Capability-kind pin
- MOT-129 B4: multiplicity validation at the registration boundary (registry_normalize + DST)
- MOT-129 B6: typed atom identity -- PreStepStage.atom and the dummy-hook record; stamp unchanged
- MOT-129 B7: route the full-literal DST/test fixtures through one test-owned constructor
- MOT-129 B8: ABI 6.0 -- Capability list, ExtEntry { id, caps }, ExtRegistry { entries }; 17 packages + host + fixtures migrated
- MOT-129 B8: delete the HookSlot half -- one dispatch table, atoms everywhere in the profile layer
- MOT-129 B8: B2 hook_scope -- 17 capability-list atom pins by hand; record path removed
- MOT-129 B8: declared_vs_performed on the 6.0 payload rows; IMPORTED-SUM rows
- MOT-129 B8: 6.0 second break -- ExtPorts proc_exec -> tool_handle
- MOT-129 6.0 generator: emit list-shape registry (D10, no more hand editing)
- MOT-129 item 4: 6.0 extension registration trimming -- drop neutral atoms, re-issue profiles + B2 pins
- hook_guard_dst: fix 3-vs-4 field record shape and un-mask dst type errors
- dst: empty the stale DST_KNOWN_RED list -- test_coverage{,_selftest} pass
- final cleanup: correct atoms_at_zero header, drop dead neutral helpers
- final cleanup: complete the dead neutral-helper drop (one remaining package)
- final cleanup: drop two leftover dead no_budget_patch neutral helpers (compaction_structural, progress_contract_guard)
- core: annotate legitimate empty-Ok sites with @allow_empty_ok to silence STRICT_FALLBACK_001 at startup
- Finalized
- Additional changes
- Review fixes

177 files changed.

## Governing docs

- `.agent/projects/017_extension_handling/ADR-001-extension-abi-evolution.md`
- `.agent/projects/017_extension_handling/PLAN-extension-abi-implementation.md`
- `.agent/projects/017_extension_handling/TASK-motoko-delegated-exploration.md`
- `.agent/projects/017_extension_handling/mmd/README.md`
- `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`
- `.agent/projects/021_herdr_delegation/DESIGN-delegate-model-selection.md`
- `.agent/projects/025_envharness_contracts/RESEARCH-envharness-implications.md`
- `.agent/projects/026_operational_ontology/RESEARCH-operational-ontology-implications.md`
- `.agent/projects/027_z3_contracts/ADR-001-contract-classification-register.md`
- `.agent/projects/027_z3_contracts/HANDOFF-implement-contract-adoption.md`
- `.agent/projects/027_z3_contracts/PLAN-z3-contract-adoption.md`
- `.agent/projects/027_z3_contracts/RESEARCH-contract-baseline.md`
- `.agent/projects/027_z3_contracts/REVIEW-adr001-verdicts.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-motoko-session-assessment.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/PLAN-001-closing-the-loop.md`

## Predicted outcome

- **A new ABI variant fails closed instead of being skipped.** Adding a capability kind is a
  `CAPABILITY_KINDS` entry plus a match arm; an atom whose constructor is not enumerated is a
  `capability-list-unresolvable` rejection, not a silent omission. Checked by
  `make ext_hook_scope_selftest`, which also pins per-extension atom counts by hand (39 over 17)
  so a list read short is noticed.
- **A mis-registered extension fails the whole build.** `normalize_registration` rejects a second
  vote-kind atom, a duplicate provider name or an unsigned fold repeat, and the runtime exits 2
  rather than loading the other sixteen -- the fail-open shape the ADR names. Checked by
  `make registry_multiplicity`.
- **The registry is never hand-edited again.** `make registry_gen_check` fails if
  `src/core/ext/registry_generated.ail` drifts from what the generator emits from
  `ailang.toml [extensions]`.
- **The first prompt no longer pays the AILANG module load.** The pre-spawn warms the module graph,
  config and extension init while the user types; measured ~1.2s warm, ~15s after editing a
  widely-imported core module, ~20s fully cold.

The review pass over the diff produced eight findings, all fixed in `Review fixes`; four of them
were regressions introduced by the pre-spawn itself, which is what a task-less runtime at boot
turns out to cost:

- Ctrl+C quits again at the first prompt. The pre-spawn always populated `runtimeProcess`, so the
  first press aborted the warm runtime and the second was swallowed by the dead-child guard --
  the TUI could not be exited at all.
- The system prompt and budget plan are built from the real task again. Both are task-conditional
  and both are built exactly once, so a runtime started with `task == ""` handed every prompt
  shaper the empty string for the whole session. `run_with_config` now waits in `await_first_task`
  before it builds anything; everything task-independent (extension init, the session_start
  banner, the system-prompt file read) still happens at boot.
- A registry rejection is visible. It went out as a bare `println`, which the TUI's
  `parseAgentEventLine` drops -- an operator saw a runtime exit 2 for no stated reason, and a fresh
  one die the same way on every prompt. Both notices are JSONL events now.
- `MOTOKO_HEADLESS=1` with no task exits 2 with a named error instead of running no turn and
  exiting 0 -- a success code for zero work is the one outcome a calling harness cannot tell apart
  from a completed run.
- `hook_scope`'s element-count cross-check is now live. Its denominator was a depth-0 comma count,
  the same scan the element splitter already performs, so it could not disagree with the parse it
  was meant to check. It counts depth-0 constructor heads instead, which closes a real fail-open
  hole: `[ToolPolicy(p) ++ PromptShaper(q)]` is one comma-delimited element and the greedy element
  pattern accepts it whole, emitting one atom for two capabilities. Paired fixture
  `reject_capability_list_juxtaposed.ail`; a mutation test confirms the old denominator lets it
  through.
- Also: `taskDone` is reset on the `awaitingTask` submit path (reachable after `/restart`, and it
  disabled ESC for that turn), and a genuine startup failure is no longer relabelled as a benign
  pre-warm exit.

## Test evidence

Guards, all green on this branch:

```
make check_core                    src/core/ type-check: 56 passed, 0 failed
make test_coverage                 441 tests, 437 passed, 4 skipped against a record
make ext_hook_scope_selftest       0 failure(s); 17/17 extensions via the 6.0 list head, 39 atoms
make ext_ambient_inventory         PASS -- 17/17 extensions, 18/18 std modules, 0 unresolved
make ext_ambient_inventory_selftest  0 failure(s)
make registry_multiplicity         registry_multiplicity_dst PASS
make profile_definition            pass (ABI 6.0 named at 10 sites across 6 files)
make driver_plus_compose           pass
make driver_plus_no_ops            pass
tools/predicate-anchors/anchors.sh pass
python3 tools/ext_registry_gen/generate.py --check
                                   registry_generated.ail matches the generator
ailang check src/core/{rpc,session,ext/registry_generated}.ail
                                   no errors
cd src/tui && npx tsc --noEmit     clean
cd src/tui && bun jest             229 passed
```

`bun jest` also reports 5 suites that fail to *load* (`compose-output-validator`,
`compose_guard_semiformal`, `env-server`, `scratchpad/loopback`, `test/path-guard`): express pulls
`depd`, which throws `callSite.getFileName is not a function` under bun. Pre-existing, unrelated to
this branch, and none of those suites import the files it touches.

Runtime smoke tests of the pre-spawn path, against a `test_dummy` profile so the hook dispatch is
observable:

- Empty task, then `{"type":"exit"}` on stdin: `session_start` at boot, no `v2_mode`, no model
  call, exit 0. Same for EOF.
- Empty task, then `{"type":"model_change","model":"switched-model"}`, then
  `{"type":"user_message","content":"Update register_with_config"}`: `dummy_hook on_budget_plan`
  and `on_build_system_prompt` fire *after* the user message, `msg_count: 2` (system + the real
  task), and the run uses `switched-model` -- the pre-warm model switch carries through.
- `MOTOKO_HEADLESS=1` with an empty task: `{"type":"error","error_code":"headless_without_task"}`,
  exit 2. With a real task it still runs its turn normally.

The mutation test behind the `hook_scope` fix: restoring the depth-0 comma denominator makes
`reject_capability_list_juxtaposed` escape the capability-list check
(`expected shapes ['capability-list-unresolvable'], got ['hook-binding-unresolvable']`), so the new
denominator is doing work the old one could not.
