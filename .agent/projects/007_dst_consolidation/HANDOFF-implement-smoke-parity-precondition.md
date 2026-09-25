# Handoff: implement the deterministic `smoke_parity` precondition

Date: 2026-07-12  
Audience: a fresh agent session implementing the reviewed parity-precondition plan

## Mission

Implement `.agent/projects/007_dst_consolidation/PLAN-smoke-parity-precondition.md` so
`make smoke_parity` is deterministic, provider-independent, network-free, and green. This
work is outside Track 1 and must be completed before parity is wired as a required CI check.

Do not edit `.github/workflows/verify-extensions.yml`, enable a required check, add a Make
target, add tests, or change production/DST/conformance behavior. No new ADR is needed.

## Current checkout and source grounding

- Branch: `arniwesth/mot-41-dts-consolidation`
- Current checkout at handoff: `3e28797e9e84298a68a53f2bc9cda7ca41a75f14`
- Relevant source baseline: `e839114abde95f466e46447bc1f4ba965367b7fe`
- The commits after the source baseline contain only handoff/plan documentation; the
  runner, Makefile, parity fixtures, and cited core files are unchanged.
- AILANG: `v0.26.0` (`3b52a24`); Bun: `1.3.14`

Re-check the branch, `git rev-parse HEAD`, tool versions, and all line anchors before editing.
Source wins if the checkout moves again. Read the full reviewed plan first.

## Current reproduction

After normal hydration:

```bash
./scripts/sync-extension-packages.sh
ailang lock
make --keep-going compaction_dst conformance phase_c_l1
```

the existing AILANG DST/conformance group passes (7.790s in the authoring observation).

The current parity floor is red:

```bash
make smoke_parity
```

The final current-HEAD review of the unchanged source failed in 3.900s. It warned that the
AI-capable run had neither `--ai <model>` nor `--ai-stub`, then failed before a successful
capture/diff.

A read-only temporary `--ai-stub` substitution in both full-cap runner branches failed in
3.616s. Its captures reached the scripted loop and reported:

```text
SystemPromptEmpty: system prompt required but system prefix is 0 chars
```

Do not treat either failure as permission to weaken `require_system_prompt`, alter
`seal_compacted_payload`, or use a live provider.

## Authorized files

The only implementation files permitted to change are:

- `scripts/phase_a_event_parity.sh`
- `scripts/smoke_v2_cost_budget_full_loop.ail`
- `scripts/smoke_v2_compaction_full_loop.ail`
- `scripts/smoke_v2_pending_full_loop.ail`
- `scripts/smoke_v2_dp7_gate.ail`
- `scripts/smoke_phase_a_tool_parity.ail`

Keep unchanged: `Makefile`, `.github/workflows/verify-extensions.yml`,
`src/core/session.ail`, `src/core/phase_vocab.ail`,
`src/core/test/scripted_ports.ail`, `src/core/test/stub_step.ail`, the three already-seeded
full-loop fixtures, the three direct/unit fixtures, all DST scenarios, conformance files, and
production code.

## Implementation directions

### Runner

In `run_json_smoke` in `scripts/phase_a_event_parity.sh`:

1. Create an empty Bash argument array and set it to `(--ai-stub)` only when the comma-
   separated `caps` argument contains `AI`.
2. Expand the same array in both the normal-stdin and `/dev/null` `ailang run` branches.
3. Remove `--net-allow-http` and `--net-allow-localhost` from both branches.
4. Do not add `--ai <model>`, provider credentials, fallback selection, or a live target.

The intended shape is:

```bash
local -a ai_args=()
case ",${caps}," in
  *,AI,*) ai_args=(--ai-stub) ;;
esac
ailang run --caps "$caps" "${ai_args[@]}" --entry main "$file"
```

The eight full-loop entries retain `FULL_CAPS` and get `--ai-stub`. The two unit-cap entries
and the IO-only compaction-tier entry do not get it. The actual scripted responses still come
from `run_v2_with_scripted_ports` and its `Ported(scripted_ports_from_steps(...))` provider;
the CLI stub only satisfies AILANG's AI-capability setup.

Preserve all checks and output semantics: `ailang check`, fixed
`MOTOKO_SESSION_ID=phase-a-parity`, duration/`make[N]` normalization, output directories,
`PARITY_STRIP_TYPES`, zero-event failure, event/order assertions, and the Makefile's two-fresh-
capture `diff -r` contract.

### Fixture setup

In each of the five edited fixtures, add a small local helper for this stable head-prefix
message:

```ailang
func parity_system_message() -> Message {
  { role: "system", content: "parity system prefix", tool_calls: [], tool_call_id: "" }
}
```

Use fixture-local setup; do not make `run_v2_with_scripted_ports` or the general scripted-port
helper inject history. Replace only the empty history arguments in:

- cost-budget: all four calls;
- pending: both calls;
- DP7: all three calls;
- Phase-A tool parity: its one call.

For compaction, prepend the seed to all five histories produced from `mk_history` and
`multi_tool_history`. Keep the existing 10/300/385/1000-character loads and 12-by-50,000-
character multi-tool load. Keep the system message first so core pins it and compaction sees
only the non-system segment.

Re-run all five compaction cases before changing expectations. Preserve the light, tier-1,
extreme, unknown-model, and multi-tool purposes and outcomes. The existing parity assertion
for the multi-tool provider payload is retained and should become `msg_count:14` because the
13-message history gains one pinned system message. If the observed count is not 14, stop and
investigate; do not broaden or delete the matcher. Any threshold or expected-result change
requires explicit plan-level review.

Do not modify the already-seeded ext-fixture, compaction-chain, or stream fixtures. Do not seed
the direct handle fixture's local `history_slice: []`; it is not a session history.

## Verification sequence

Run with `PARITY_BASELINE` unset.

1. Check every runner fixture, including the five edited ones:

   - `smoke_v2_cost_budget_full_loop.ail`
   - `smoke_v2_compaction_full_loop.ail`
   - `smoke_v2_pending_full_loop.ail`
   - `smoke_v2_dp7_gate.ail`
   - `smoke_phase_a_tool_parity.ail`
   - `smoke_v2_ext_fixture_parity.ail`
   - `smoke_v2_compaction_chain.ail`
   - `smoke_v2_stream_parity.ail`
   - `smoke_v2_handle.ail`
   - `smoke_v2_hybrid.ail`
   - `smoke_v2_compaction_tiers.ail`

2. Audit determinism/offline behavior:

   - every AI-capable `ailang run` has `--ai-stub` and no real `--ai <model>`;
   - no parity runner command has a `--net-allow-*` flag;
   - all eight full-loop fixtures use the scripted `Ported` path;
   - the unit/tier entries are direct or pure checks;
   - run once with provider credential variables unset and an invalid HTTP/HTTPS proxy
     tripwire, such as loopback port 9 with `NO_PROXY` empty; the parity target must still pass;
   - if a network syscall audit or network-disabled wrapper is available, record it as
     corroborating evidence.

   A failed static audit or tripwire is a stop condition. Never fix it with credentials or a
   live provider.

3. Re-run the existing gates:

   ```bash
   ./scripts/sync-extension-packages.sh
   ailang lock
   make --keep-going compaction_dst conformance phase_c_l1
   make verify_core
   ```

   `verify_core` remains advisory per ADR-001; the AILANG DST/conformance gates must pass.

4. Verify two fresh captures and record wall time:

   ```bash
   rm -rf /tmp/phase_a_parity_a /tmp/phase_a_parity_b
   start=$(date +%s%N)
   make smoke_parity
   rc=$?
   end=$(date +%s%N)
   printf 'smoke_parity_rc=%s wall=%.3fs\n' "$rc" "$((end-start))e-9"
   exit "$rc"
   ```

   Require zero status, both fresh directories, successful `diff -r`, no AI-handler warning,
   no `SystemPromptEmpty`, no provider/network error, and stable normalized captures. Report
   11 logical entries per capture and 22 fixture executions across the default two-capture
   target.

5. Run a final scope audit. Only the six authorized implementation files may be modified by
   the implementation session; the pre-existing plan/handoff documentation is not part of
   that implementation diff. In particular, the workflow and Makefile must be untouched. Run
   `git diff --check`.

## Stop conditions

Stop and report instead of improvising if:

- the current source no longer reproduces the baseline or stub follow-on failure;
- a live provider, model, credential, or network-dependent behavior is required;
- a fixture change alters a DST scenario, conformance contract, scenario name, or event purpose;
- compaction thresholds/results change without explicit review;
- deterministic output, the two-capture diff, or the baseline/output contract cannot be kept;
- an additional file outside the six authorized implementation files is needed; or
- the workflow/Makefile/core invariant files would need editing.

## Required handback to Track 1

Only after the parity target is green, hand back:

- exact authorized files changed;
- deterministic execution mode (`--ai-stub`, scripted `Ported` provider, no network flags);
- 11 logical parity entries per capture and 22 total default-target executions;
- `make smoke_parity` wall time, exit/output status, and confirmation of two fresh captures;
- results of `make --keep-going compaction_dst conformance phase_c_l1` and advisory
  `make verify_core`;
- confirmation that `.github/workflows/verify-extensions.yml` was not changed.

Then a separate Track 1 session may apply its existing `make CI=1 sync_packages`, DST-gate,
advisory `verify_core`, and `dst_l2` workflow changes.
