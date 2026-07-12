# Plan: make `smoke_parity` deterministic and green

Date: 2026-07-12  
Status: Completed 2026-07-12 (implementation commit `22f494e`; review amendment recorded)
Grounded checkout HEAD: `765b094a8f0ff8e5644165b36d7c66ea962a730b`
Relevant source baseline: `e839114abde95f466e46447bc1f4ba965367b7fe` (unchanged at the grounded checkout)
Toolchain observed at authoring: AILANG `v0.26.0`, Bun `1.3.14`

This plan repairs only the existing parity runner and the existing parity fixture setup.
It does not edit `.github/workflows/verify-extensions.yml`, enable a required check, change
the Makefile parity contract, add tests, or alter production/DST/conformance behavior. No new
ADR is required; the governing decisions are ADR-001 and the DST CI-gates plan.

## TL;DR

Make the parity runner pass `--ai-stub` only to its eight AI-capable runs, remove its stale
network-allow flags, and seed five empty full-loop fixtures with one stable non-empty system
message. Keep the existing scripted-port provider, event assertions, output layout, and
two-capture `diff -r` contract. The extreme compaction fixture is approved to report `Ok`
after structural tier-1 elision: its former `Err` was caused by `SystemPromptEmpty`, not
compaction exhaustion. Track 1 remains blocked until the repaired target is green.

## Blast radius

- **Changed:** `scripts/phase_a_event_parity.sh` and five existing parity fixtures:
  cost-budget, compaction, pending, DP7, and Phase-A tool parity. The compaction assertion's
  expected provider message count is re-grounded from 13 to 14 because of the pinned seed.
- **Execution:** eight full-loop entries run with local `--ai-stub` support and no network-allow
  flags; two unit entries and the IO-only tier entry receive no AI stub. The default target
  still makes two fresh captures: 11 logical entries per capture, 22 executions total.
- **Unchanged:** `Makefile`, workflow wiring, `require_system_prompt`, sealing/compaction core,
  scripted-port helpers, already-seeded fixtures, DST scenarios, conformance behavior, and
  production code. No provider credentials, live model, or live network is introduced.
- **Review risk:** the pinned system message contributes to compaction sizing. The extreme
  compaction expectation therefore receives an explicit correction below; all five compaction
  outcomes and the deterministic capture assertions must be revalidated before handoff.

## Ground truth and reproduction

The checkout is `arniwesth/mot-41-dts-consolidation` at `765b094`. The only commits after
the reproduced source baseline add the handoff and this plan; the runner, fixtures, Makefile,
and core files cited below are byte-identical to `e839114`. After:

```bash
./scripts/sync-extension-packages.sh
ailang lock
```

the existing AILANG DST/conformance group passed:

```text
make --keep-going compaction_dst conformance phase_c_l1   # pass, 7.790s locally
```

The required baseline reproduction was:

```bash
make smoke_parity
```

It failed in 3.900s in the final current-HEAD review (the initial authoring run was 3.238s).
The runner checked and began
`smoke_v2_cost_budget_full_loop`, then printed AILANG's warning that `--caps AI` had no
`--ai` model or `--ai-stub`; it reached the next full-loop fixture and exited before a
successful parity capture/diff. The Make recipe returned nonzero (`make` status 2 in this
shell).

A read-only substitution of `--ai-stub` into both full-cap `ailang run` branches was then
run with the source script supplied through process substitution. The final current-HEAD
review failed in 3.616s (the initial authoring run was 3.268s), and the captures contained:

```text
type=error source=system_prompt code=SystemPromptEmpty
message=system prompt required but system prefix is 0 chars
```

This is the expected second failure, not permission to weaken the invariant. At
`src/core/session.ail:1213-1227`, normal non-headless sessions set
`require_system_prompt` to true. At `src/core/session.ail:1686-1703`, the loop seals the
scripted provider payload and reports `SystemPromptEmpty`; the underlying invariant is
`src/core/phase_vocab.ail:143-152`. The existing system-prefix split and sealing behavior
must remain unchanged.

## Fixture inventory

`phase_a_event_parity.sh:171-180` invokes 11 parity entries: eight full-loop entries, two
unit-cap entries, and one IO-only compaction-tier entry.

| Runner entry | Current history/setup | AI capability | Repair |
|---|---|---:|---|
| `smoke_v2_cost_budget_full_loop` | Four `run_v2_with_scripted_ports` calls pass `[]` (`:73-184`) | yes | Add the same one-message non-empty system seed to each call |
| `smoke_v2_compaction_full_loop` | `mk_history` and `multi_tool_history` contain no system message (`:54-94`; calls `:99-169`) | yes | Prepend the seed to every five tested histories; recheck thresholds and payload counts |
| `smoke_v2_pending_full_loop` | Two calls pass `[]` (`:135-158`) | yes | Add the system seed to both |
| `smoke_v2_dp7_gate` | Three calls pass `[]` (`:65-124`) | yes | Add the system seed to all three |
| `smoke_phase_a_tool_parity` | One call passes `[]` (`:57-72`) | yes | Add the system seed |
| `smoke_v2_ext_fixture_parity` | `seed_history()` already starts with non-empty `fixture system prefix` (`:21-26`) | yes | No fixture change |
| `smoke_v2_compaction_chain` | `seed_history()` already starts with non-empty `chain system prefix` (`:84-91`) | yes | No fixture change |
| `smoke_v2_stream_parity` | `seed_history()` already starts with non-empty `stream system prefix` (`:19-24`) | yes | No fixture change |
| `smoke_v2_handle` | Direct `dispatch_tool_handle`; no scripted full-loop call | no | No change |
| `smoke_v2_hybrid` | Pure `extract_bash`/JSON checks; no scripted full-loop call | no | No change |
| `smoke_v2_compaction_tiers` | Direct pure `compact_step_with_limit`; IO-only invocation | no | No change |

The `history_slice: []` values in the direct handle fixture are local extension-context
construction, not a session history passed to `run_v2_with_scripted_ports`; they must not be
seeded as part of this repair.

## Authorized implementation

### 1. Make the runner select the local AI stub

File: `scripts/phase_a_event_parity.sh`.

Inside `run_json_smoke`, derive an empty argument list for ordinary/unit-cap runs and
`(--ai-stub)` when the comma-separated `caps` argument contains `AI`. Use that argument list
in both the normal-stdin and `/dev/null` `ailang run` branches. This covers all eight
`FULL_CAPS` entries and makes the choice explicit at the runner boundary. Do not add a real
`--ai` model, provider selection, credential lookup, or fallback behavior.

The flag only satisfies AILANG's AI-capability setup. The fixture's actual model path remains
the caller-supplied `Ported` provider from `run_v2_with_scripted_ports`; the AILANG stub is not
used as a second source of model responses.

The shell change should be equivalent to this shape, with the same `ai_args` expansion in
both branches:

```bash
local -a ai_args=()
case ",${caps}," in
  *,AI,*) ai_args=(--ai-stub) ;;
esac
ailang run --caps "$caps" "${ai_args[@]}" --entry main "$file"
```

Remove the stale `--net-allow-http` and `--net-allow-localhost` flags from those runner
invocations. None of the 11 fixtures performs a network operation, and no network permission
is needed for the local scripted-port provider. Keep the `Net` effect name in `FULL_CAPS`
because it is part of the existing full-loop effect row; capability declaration is not an
invitation to contact a target. The unit-cap entries receive no `--ai-stub` flag; they also
run without the stale network-allow flags.

Keep unchanged:

- every `ailang check` call;
- `MOTOKO_SESSION_ID=phase-a-parity`;
- duration and `make[N]` normalization;
- all existing event/order assertions, including the ext-fixture, stream, and compaction-chain
  checks; the compaction full-loop count assertion is retained with its expected count
  re-grounded from 13 to 14 solely because the repaired fixture adds one pinned message;
- the output directory layout, `PARITY_STRIP_TYPES` handling, and zero-event failure;
- the `make smoke_parity` two-fresh-capture `diff -r` contract in `Makefile:44-53`.

The `smoke_v2_compaction_full_loop` provider-count assertion must not be deleted. Because its
12-tool history currently has 13 messages and the repair adds one pinned system message, the
expected provider payload count should be re-grounded to 14 after the fixture edit. This is
an explicit expected-wire-shape review item, not an incidental assertion relaxation; if the
observed count is not 14, stop and investigate rather than broadening the matcher.

### 2. Seed only the five empty full-loop fixtures

Files:

- `scripts/smoke_v2_cost_budget_full_loop.ail`
- `scripts/smoke_v2_compaction_full_loop.ail`
- `scripts/smoke_v2_pending_full_loop.ail`
- `scripts/smoke_v2_dp7_gate.ail`
- `scripts/smoke_phase_a_tool_parity.ail`

In each fixture, add a small local helper returning one stable, non-empty head-prefix
`Message`, for example:

```ailang
func parity_system_message() -> Message {
  { role: "system", content: "parity system prefix", tool_calls: [], tool_call_id: "" }
}
```

Use an explicit fixture-local seed (or an equally narrow fixture-local prepend helper) at the
existing call sites. Do not modify `run_v2_with_scripted_ports` or make the general scripted
port constructor inject a message: `src/core/test/scripted_ports.ail:83-100` must continue to
honor the caller's supplied history for unrelated tests.

For `smoke_v2_cost_budget_full_loop`, `smoke_v2_pending_full_loop`, `smoke_v2_dp7_gate`, and
`smoke_phase_a_tool_parity`, replace only the empty history argument with the local one-message
seed. Preserve each scripted step, tool call, budget, model label, workdir, and assertion.

For `smoke_v2_compaction_full_loop`, prepend the seed to the histories produced by
`mk_history` and `multi_tool_history`; do not rewrite those builders or silently change their
10/300/385/1000-character loads or 12-by-50,000-character multi-tool load. The system message
must remain first so `split_for_compaction` pins it and passes only the non-system segment to
the compactor, as defined by `src/core/phase_vocab.ail:128-152`.

Re-evaluate, before changing any expected result, all five compaction cases:

- light history remains `Ok`;
- tier-1 history remains `Ok` with elision;
- the extreme history applies structural tier-1 elision and completes `Ok` after the required
  system prefix is present; the former `Err` was `SystemPromptEmpty`, not exhaustion;
- unknown-model behavior remains fail-open;
- the multi-tool history still exercises structural tier-1 elision.

The pinned prompt reduces the effective compaction limit and contributes to the final sealed
payload estimate. If an expectation or threshold must change, document the before/after
calculation and obtain plan-level review; do not adjust a threshold merely to get a green
capture. No DST scenario ID, event type, event order, or DST/conformance contract may change.

### Approved correction to the extreme compaction expectation

The original `test_tier3_history_refused` expectation was not exercising compaction exhaustion.
With an empty initial history, normal non-headless policy rejected the payload first with
`SystemPromptEmpty`. After the required system message is seeded, the existing structural
compaction hook legitimately applies tier-1 elision (`keep_last=10`) to the oversized tool
history, and the loop completes `Ok`.

This is an approved correction to the existing parity fixture's label and assertion, not a
production or policy change. The fixture keeps the original 385-character load, model, tool
history shape, structural extension, and event contract; no threshold is changed. The direct
implementation run at commit `22f494e` observed the structural tier-1 event, `Ok`, and the
expected `msg_count:14` provider payload. The fixture name/report may therefore be
`test_extreme_history_compacts` / `Ok after elision`. Any future exhaustion coverage must be
planned as a separate fixture change rather than restoring the unreachable pre-seed `Err`.

## Verification and acceptance

Run from a hydrated checkout with `PARITY_BASELINE` unset.

1. `ailang check` every one of the 11 inventory fixtures, including all five edited files;
   the runner's own checks must also pass.
2. Audit the runner for deterministic/offline execution:
   - every AI-capable run contains `--ai-stub` and no real `--ai <model>`;
   - no runner invocation contains `--net-allow-*`;
   - no provider credential is required or read;
   - the five edited fixtures reach `Ported(scripted_ports_from_steps(...))`, while the
     remaining entries are direct/pure checks;
   - statically confirm that all eight full-loop fixtures use
     `run_v2_with_scripted_ports`/`Ported(scripted_ports_from_steps(...))`, and that the three
     unit/tier entries are direct or pure checks with no provider/network call path;
   - run once with all provider credential variables unset and a deliberate invalid HTTP/HTTPS
     proxy tripwire (for example, loopback port 9 with `NO_PROXY` empty); the parity target
     must still pass. This proves the target does not depend on a provider or external network.
     A network-syscall audit (`connect`, `sendto`, `recvfrom`) or network-disabled wrapper is
     useful corroborating evidence when available, but is not a new required tool dependency.
     If the static audit or tripwire run fails, stop and report it; do not reintroduce a live
     provider.
3. Re-run the existing AILANG gates:

   ```bash
   ./scripts/sync-extension-packages.sh
   ailang lock
   make --keep-going compaction_dst conformance phase_c_l1
   make verify_core
   ```

   `verify_core` remains advisory per ADR-001; the DST and conformance targets remain
   blocking and must pass.

4. Run:

   ```bash
   rm -rf /tmp/phase_a_parity_a /tmp/phase_a_parity_b
   start=$(date +%s%N)
   make smoke_parity
   end=$(date +%s%N)
   ```

   Require a zero exit status, two newly created capture directories, successful `diff -r`,
   and no `SystemPromptEmpty`, missing-AI-handler warning, provider error, or network error.
   Record the measured wall time from `end-start` and retain the final output status. The
   final logical parity count is 11 runner entries per capture: 8 full-loop, 2 unit-cap, and
   1 tier entry. The default `make smoke_parity` performs two fresh captures, so it executes
   22 fixture entries in total; report both counts, plus any internal fixture pass counts if
   the implementation handoff reports them.

5. Inspect the fresh captures for the preserved event assertions, including non-zero system
   prefix fields on all provider calls, the structural tier-1/`Ok` extreme compaction result,
   the updated compaction payload count, stream ordering, chain ordering/counts, and deterministic
   digests after normalization. Repeat the runner if either fresh capture differs.

6. Perform a scope audit. The only implementation files permitted to differ are
   `scripts/phase_a_event_parity.sh` and the five edited fixtures listed above. In particular,
   `Makefile`, `src/core/session.ail`, `src/core/phase_vocab.ail`,
   `src/core/test/scripted_ports.ail`, `src/core/test/stub_step.ail`, all already-seeded
   parity fixtures, conformance/DST files, and
   `.github/workflows/verify-extensions.yml` must remain unchanged.

No new test file or test case is authorized. The existing smoke fixtures are repaired only so
they supply the production-required system-prefix precondition.

## Handoff and stop conditions

The implementation handoff to Track 1 must report the exact authorized files changed, the
`--ai-stub`/offline execution mode, the final 11-entry logical count and 22-entry two-capture
execution count, the approved structural tier-1/`Ok` extreme compaction result,
`make smoke_parity` wall time and status, the AILANG DST/conformance results, and confirmation that
`.github/workflows/verify-extensions.yml` was not changed. Only then may Track 1 apply its
existing `make CI=1 sync_packages`, DST-gate, advisory `verify_core`, and `dst_l2` workflow
changes.

Stop and report if the source no longer reproduces either failure, if a live provider or
credential is required, if seeding changes a DST scenario or conformance contract, if the
normalized output/baseline contract cannot remain deterministic, if a threshold change is not
reviewed, or if changes outside this runner/fixture scope have not been authorized.
