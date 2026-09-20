# AILANG: pinned-clock and fixture-FS modes — `WorldState.clock_ms` / `WorldState.files` are the feature in userland

## Status

Written 2026-09-05 on branch `arniwesth/013-dst-architecture-adr` at `3fe71b0`.
Measured against the pin, **AILANG v0.33.0**, commit `ae36986`, built 2026-09-04
(`ailang version`).

Upstream: `ailang/design_docs/planned/v1_0_0/m-effect-clock-net-fs-modes.md` —
**Planned**, ~20 hours (~3 days), sprint 3 of 4 of the `m-effect-refinement`
decomposition, shipping on the normal v0.29.x road. Schemas per the frozen design:
`Clock: {mode: wall|pinned}` (default `wall`), `FS: {mode: real|fixture}` (default
`real`), `Net: {mode: live|recorded}` (default `live`). Bare `!{Clock}` / `!{Net}` /
`!{FS}` keep today's behaviour as the default mode. No new runtime subsystems — the
sprint wires declared modes to switches that already exist (`clock.go` virtual-time
path under `AILANG_SEED`, `fs.go` sandbox path); where no switch exists (Net
`recorded`?), ship the registry row plus a typed not-yet-supported error, not a stub
behaviour. Stdlib annotations stay bare (2 `!{Clock}`, 4 `!{Net}`, 18 `!{FS}`).

## Not yet filed upstream

Not submitted to `sunholo-data/ailang` — filing is an outward-facing action and was not
part of the diagnosis this came out of. Worth routing through the `ailang-feedback` skill
(Channel 2 if the CLI is configured, Channel 1 otherwise).

Filing pre-flight, measured 2026-09-05 rather than assumed: Channel 2 is unavailable —
`gh auth status` reports "You are not logged into any GitHub hosts" and
`~/.ailang/config.yaml` is absent. The `ailang-feedback` skill is not installed in this
session (no skills directory), and the Channel 3 MCP `submit_feedback` POST is not
reachable from the available tool set, so Channel 3 was not attempted either. No ticket
exists; there is no URL and nothing to poll. See the identical channel caveat recorded in
`ailang-no-warning-for-unreachable-match-arm.md`'s *How it was filed* section: Channel 3
is fire-and-forget with no URL and no status to poll.

## Symptom

Clock pinning (`AILANG_SEED`), FS sandboxing, and Net recording exist as runtime
behaviours with zero type-level visibility. A function that only works under pinned
time, or a test that must not touch real disk, cannot say so; reviewers and agents must
know the env-var folklore. Motoko's answer is to implement both features in userland:

- `WorldState.clock_ms` (`src/core/ports.ail:195`) — the only clock in a deterministic
  run; the virtual-time pair (identical provider script, approval queue, and deadline,
  differing only in clock advancement) makes 4 of 9 native tool results in the slow half
  carry `ToolDeadlineExceeded` with no OS timeout involved (DRAFT §5.2).
- `WorldState.files` (`src/core/ports.ail:352`) — the synthetic FS; deterministic writes
  land in `WorldState.files` and are therefore replayed member-for-member.

Measured at HEAD across the boundary modules (`ports.ail`, `session.ail`,
`tool_phase.ail`, `context_usage.ail`, `ext_world.ail`, `rpc.ail`,
`dst_driver_only.ail`, `dst_driver_plus_compose.ail`, `dst_driver_plus_no_ops.ail`,
`dst_fault_catalogue.ail`):

```
$ grep -rn "next_state" <those ten files> | wc -l
198
```

198 textual `next_state` lines, of which 31 open a `--` comment and 4 carry trailing
`--` commentary on code lines — **167 non-comment lines** threading the userland
world past every leaf. That threading *is* the pinned clock and the fixture FS.

## Where it comes from

Verified upstream state 2026-07-11 (v0.28.0, doc Framing): `defaultEffectModes` has
Rand + AI only; Clock/Net/FS are an explicit "Future:" comment naming this port.
`clock.go` already implements wall vs virtual time; `fs.go` sandbox machinery exists —
both runtime-only, invisible in types. The collapsed-contracts table of the parent doc
(`m-effect-refinement.md`) is uncorrected for exactly these three effects.

## How it bites Motoko

DRAFT §5.2's virtual-time and hermeticity results (the latency pair; the five two-sided
poison pairs showing the deterministic world completing with `AI`/`Clock`/`Env`/`FS`/
`Process` withheld while live wiring dies) are established by measurement over the
userland clock and FS — and preserved by discipline, not by type. With
`Clock[mode=pinned]` and `FS[mode=fixture]`, pinning and fixture-ness become declarable,
checkable properties: `Clock[mode=pinned]` without `AILANG_SEED` is a typed error (no
silent wall-clock fallback, op-site per the design freeze), and `FS[mode=fixture]`
escape attempts fail loudly through the existing sandbox.

## Suggested upstream fix

Ship the sprint as frozen: per effect, (1) schema row, (2) default row in
`defaultEffectModes`, (3) replay-registry contract rows (Clock pinned=deterministic /
wall=re-sampleable; FS fixture=deterministic / real=re-sampleable; Net
recorded=deterministic / live=re-sampleable, subject to the planner's Net reality
check), (4) dispatch wiring to the existing switches, (5) `examples/modal_clock.ail` +
`examples/modal_net.ail` and the migration-guide section.

## Workaround in this repo

The userland world *is* the workaround: `WorldState.clock_ms` and `WorldState.files`
under the 167 non-comment `next_state` lines. It stays until adoption is measured.

## Do not claim

- No claim about which `next_state` lines disappear on adoption — which parts the modes
  replace is measured after adoption, not claimed here.
- The upstream ~20h estimate is a language-implementation estimate, not a Motoko
  integration estimate.
- Net `recorded` is explicitly scoped to what is real today (possibly
  registry-label-only in this sprint, like AI); this ask does not overclaim it.
