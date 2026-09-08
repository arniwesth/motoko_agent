# Handoff: author the smoke-parity precondition plan

Date: 2026-07-12
Audience: a fresh agent session authoring a focused plan for the deterministic parity
precondition that blocks Track 1 CI wiring.

## Mission

Author a small, implementation-ready plan for making `make smoke_parity` deterministic,
network-free, and green. This is a prerequisite work item outside Track 1. Do not edit
`.github/workflows/verify-extensions.yml` or enable the required CI check in this work item.

No new ADR is needed. The governing decisions already exist in
`.agent/projects/007_dst_consolidation/PLAN-ci-dst-gates.md` and
`.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md`:
parity must be deterministic, provider/network-independent, and blocking once green.

## Why this handoff exists

Track 1 was intentionally not implemented because its required `smoke_parity` floor is red
at the current source HEAD. Leaving the workflow change in place would create a permanently
red required PR check. The plan author must first re-ground the source and then specify the
smallest authorized repair.

The current working session observed:

- branch: `arniwesth/mot-41-dts-consolidation`
- source HEAD: `0b061b7`
- AILANG: `v0.26.0`
- Bun: `1.3.14`

These are observations, not trusted anchors. Re-check them before writing the plan; source
wins if the checkout has moved.

## Required reading

Read completely, in this order:

1. `.agent/projects/007_dst_consolidation/NOTE-dst-consolidation-scope-and-sequence.md`
2. `.agent/projects/007_dst_consolidation/PLAN-ci-dst-gates.md`, especially WI-0 and the
   `smoke_parity` precondition
3. `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md`,
   especially Decision Drivers, Constraints, CI Shape, and the advisory Z3 decision
4. `Makefile`, `scripts/phase_a_event_parity.sh`, and every fixture invoked by that script
5. `src/core/session.ail`, `src/core/phase_vocab.ail`,
   `src/core/test/scripted_ports.ail`, and `src/core/test/stub_step.ail`

Re-ground every file/line anchor at implementation HEAD. Do not rely on the observations
below if source has changed.

## Reproduction at the handoff source HEAD

After normal hydration:

```bash
./scripts/sync-extension-packages.sh
ailang lock
make --keep-going compaction_dst conformance phase_c_l1
make smoke_parity
```

The AILANG DST/conformance command passed. `make smoke_parity` failed after about 3.2 seconds
with output of this form:

```text
check scripts/smoke_v2_cost_budget_full_loop.ail
run smoke_v2_cost_budget_full_loop
Warning: --caps AI requires --ai <model> flag.
  No AI model configured. Programs using AI.call will fail.
  Fix: ailang run --caps AI --ai gemini-2-5-flash ...
  Or for testing: ailang run --caps AI --ai-stub ...
```

The runner proceeds into the full-loop smokes but exits nonzero before producing a successful
parity capture/diff. Hydration resolves package imports and regenerates the lockfile; it does
not select an AI provider, provide credentials, or change AILANG CLI flags.

The independent Layer-2 slice and advisory proof were healthy:

```bash
cd src/tui && bun test src/harness-dst.test.ts   # 7 pass
make verify_core                                # 0 failures
```

## Current source facts to verify

At the handoff HEAD, the relevant shape was:

- `Makefile:44-53`: `smoke_parity` runs `phase_a_event_parity.sh` twice and diffs the two
  output directories unless `PARITY_BASELINE` is set.
- `scripts/phase_a_event_parity.sh:18`: `FULL_CAPS` includes `Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace`.
- `scripts/phase_a_event_parity.sh:69-82`: full-loop invocations use `ailang run --caps
  "$caps" --net-allow-http --net-allow-localhost ...` with neither `--ai <model>` nor
  `--ai-stub`.
- `scripts/phase_a_event_parity.sh:171-180`: the full-loop parity fixture list includes
  cost-budget, compaction, pending, DP7, tool, extension, compaction-chain, stream, handle,
  and hybrid smokes.
- `src/core/test/scripted_ports.ail:83-100`: `run_v2_with_scripted_ports` supplies a
  deterministic `Ported` provider, but its effect row still includes `AI`.
- Several parity fixtures call `run_v2_with_scripted_ports` with an empty initial history,
  including `scripts/smoke_v2_cost_budget_full_loop.ail` and
  `scripts/smoke_v2_compaction_full_loop.ail`.
- `src/core/session.ail` sets `require_system_prompt` to `not headless` in the normal session
  policy.
- `src/core/phase_vocab.ail` rejects a sealed payload when `require_system_prompt` is true and
  the pinned system prefix has zero characters.

The handoff review also performed a read-only temporary `--ai-stub` substitution. It reached
the scripted replay and then exposed `SystemPromptEmpty`, because the current fixture inputs
have no non-empty system message. Reproduce this against the current HEAD rather than treating
the line references as permanent.

## Likely repair shape — not yet normative

The plan should evaluate this two-part repair:

1. Make the parity runner explicitly deterministic by passing `--ai-stub` to the AILANG runs
   that declare the AI capability. Do not use a real model, provider credentials, or live
   network. Confirm whether all full-cap runs need the flag and whether the unit-cap runs need
   no change.
2. Seed the existing parity fixtures with a minimal, non-empty system message, preserving the
   core `require_system_prompt` invariant. For compaction fixtures, re-check all threshold
   expectations because the pinned system message contributes to estimated input size.

The plan must decide whether the smallest safe implementation is explicit fixture setup,
a narrowly scoped shared fixture helper, or another mechanism. Do not silently make the
general scripted-port helper inject a system prompt if that would change unrelated tests.

## Hard constraints

- No real `--ai` model, provider credentials, live target, or network-dependent execution.
- Do not make `smoke_parity` advisory or ignore a failed subprocess.
- Do not disable or weaken `require_system_prompt`.
- Do not change `seal_compacted_payload` or any DST invariant to accommodate the fixtures.
- Do not edit DST scenarios, conformance fixtures/ABI behavior, production behavior, or the
  Track 1 workflow as part of this precondition work.
- Do not add new tests; repair only the existing parity runner/fixture setup if authorized.
- Preserve parity scenario names, event assertions, and deterministic output semantics.
- Treat any change to existing smoke fixture thresholds or expected behavior as a plan-level
  review item, not an incidental adjustment.

## Plan author’s required work

The new plan should:

1. Reproduce the current failure and the temporary-stub follow-on failure at the current HEAD.
2. Inventory every fixture invoked by `phase_a_event_parity.sh`, identifying which histories
   already contain a system message and which do not.
3. Define the exact file changes and explain why they preserve each smoke’s purpose.
4. Include explicit checks that no provider or network is contacted.
5. Require `ailang check` for all affected fixtures.
6. Require a successful `make smoke_parity` with two fresh captures and a recorded wall time.
7. Re-run the existing AILANG DST/conformance gates after the repair.
8. Hand Track 1 back only after the parity target is green; Track 1 then applies its existing
   `make CI=1 sync_packages`, DST gate, advisory `verify_core`, and `dst_l2` workflow changes.

## Stop conditions

Stop and report if:

- the source no longer matches the reproduced failure;
- making the runner green requires a live provider or credentials;
- the proposed fixture changes alter a DST scenario or conformance contract;
- the parity baseline/output contract cannot be preserved deterministically; or
- the operator has not authorized changes outside Track 1.

## Expected handoff back to Track 1

Report the authorized files changed, the deterministic execution mode, the final parity
scenario count, `make smoke_parity` wall time and output status, and confirmation that no
workflow file was changed. Only then should a separate implementation session enable parity
as a required CI check.
