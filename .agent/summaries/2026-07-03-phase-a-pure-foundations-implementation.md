# Phase A Pure Foundations Implementation

Date: 2026-07-03
Branch: `arniwesth/mot-27-phased-core-architecture`
Final HEAD: `d0d5b7e`
Toolchain verified: AILANG v0.26.0, commit `3b52a24`

## What Changed

Implemented `PLAN-phase-a-pure-foundations.md` WI-0 through WI-4 with one commit per work item, except WI-3 split into 3a/3b as planned.

Commits:

- `660c4b5` Add Phase A parity harness
- `6eb735a` Name compaction tier constants
- `e8242b3` Add phase vocabulary module
- `ccd43d2` Move transcript builders to phase vocab
- `d0d5b7e` Consolidate handled tool messages

## Work Items

WI-0 added `scripts/phase_a_event_parity.sh`, `scripts/smoke_phase_a_tool_parity.ail`, and `make smoke_parity`. It also repaired the two G8 smoke fixtures:

- `scripts/smoke_v2_pending_full_loop.ail`: added passthrough `on_pre_step`.
- `scripts/smoke_v2_handle.ail`: added `on_describe_tools`, `on_pre_step`, `verification`, and `context_limit`.

The parity harness checks each listed smoke before running it, normalizes `duration_ms`, filters JSONL event lines, fails full-loop smokes that emit zero events, and validates the new tool-parity smoke has the native dispatch bracket.

WI-1 named compaction tier constants in `src/core/compaction.ail` as zero-arg `export pure func`s and replaced inline literals for 70/85/95, keep-last 10/5, and emergency keep-last 3/1.

WI-2 added unused `src/core/phase_vocab.ail` seeded from the sketch: sealed history/payload types, checkpoint/state/delta scaffolding, `LedgerEvent`, `to_schema_v1`, and tests. Added `scripts/probe_phase_vocab_sealed.ail`, which is expected to fail with `IMP010`.

WI-3a moved transcript builders from `agent_loop_v2.ail` into `phase_vocab.ail`: `msgs_to_messages`, `step_result_to_message`, `cap_tool_message_content`, `result_env_model_content`, `tool_result_message`, and `envelope_to_tool_message`. Because AILANG imports exported type names into local resolution even with a module alias, `agent_loop_v2`'s private `LoopTotals` was renamed to `RuntimeLoopTotals` to avoid collision with `phase_vocab.LoopTotals`.

WI-3b added `handled_tool_message(call_id, env)` and replaced the three duplicate handled-tool literals in `agent_loop_v2.ail`.

## Verification

Final WI-4 gate passed:

- `ailang --version`
- `make check_core`
- `make test_core`
- `make test_integration`
- `ailang test src/core/compaction.ail`
- `ailang test src/core/agent_loop_v2.ail` returned 17 tests, as expected after moving the two cap tests.
- `ailang test src/core/phase_vocab.ail`
- `ailang verify src/core/compaction.ail`
- `make verify_core`
- `ailang check scripts/probe_phase_vocab_sealed.ail` failed with `IMP010`, as expected.
- `bash scripts/setup_dp7_smoke_workdirs.sh`
- `./scripts/phase_a_event_parity.sh /tmp/phase_a_after`
- `diff -r /tmp/phase_a_baseline /tmp/phase_a_after` was empty (`rc=0`).

Negative checks passed:

- `phase_vocab` appears only in `agent_loop_v2` import and its own module declaration.
- `grep -c emit_event src/core/phase_vocab.ail` is `0`.
- No diff under `src/tui/`, `packages/`, or `src/core/ext/`.

## Notes

During WI-1 verification, `smoke_v2_dp7_gate` produced different nested Make labels (`make[1]` vs `make[2]`) depending on whether the parity harness was invoked directly or through `make smoke_parity`. This was fixed in WI-0 by normalizing `make[N]` to `make[0]`; the WI-0 commit was amended and `/tmp/phase_a_baseline` was regenerated.

The working tree after implementation was clean except unrelated untracked entries that were not touched:

- `.agent/projects/004_phase_core_refactor/HANDOFF-write-phase-b-plan.md`
- `oh-my-pi/`
