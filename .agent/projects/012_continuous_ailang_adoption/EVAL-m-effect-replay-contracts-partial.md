# EVAL: `m-effect-replay-contracts` — LANDED (PARTIAL), not adopted, not an ask

Date: 2026-09-05. Branch `arniwesth/013-dst-architecture-adr` at `3fe71b0`.
Pinned binary: AILANG **v0.33.0** (commit `ae36986`, built 2026-09-04).
Written under PLAN-001 P0/D3 step 4. **Not an ask; not a claimed adoption.**

## Upstream status

`ailang/design_docs/implemented/v0_30_0/m-effect-replay-contracts.md` — **LANDED
(PARTIAL) 2026-07-24, iter-99**, M0–M5 shipped. Delivered and green:

- `ailang/internal/replay/contracts.go` registry: Rand 3 rows (seeded→deterministic,
  os→re-sampleable, crypto→opaque) + AI 3 **label-only** rows (fixed→deterministic,
  routeable→re-sampleable, replay-only→opaque), with the cross-table drift-guard
  invariant (`TestReplayContractsAreLegalModes` against `effectSchema`).
- Mode-aware Rand dispatch (os/seeded/crypto via `EffContext` threading), seeded source
  via `AILANG_SEED` + typed no-seed error, crypto via `crypto/rand`, additive trace
  `Mode`/`Contract` fields, bare-Rand byte-identical golden gate.
- **Clock/Net/FS rows belong to another sprint** (sprint 3,
  `m-effect-clock-net-fs-modes.md`): `ContractFor` returns `false` for those pairs,
  and callers must not invent a fallback label.

## Capability check (executable, re-run at re-evaluation)

```sh
grep -rn "ReplayContract" src packages scripts --include="*.ail" | wc -l   # 0
grep -rn "replay/contracts" src packages scripts | wc -l                   # 0
grep -rn "mode=" src packages scripts --include="*.ail" | wc -l            # 0
```

Measured 2026-09-05 at HEAD: **zero matches on all three**. No Motoko code references
the registry. Admission criterion for flipping this entry to "adopted": a non-zero,
intentional reference (import, annotation, or dispatch on a contract label) plus the
gate that covers it.

## Evaluation answers

**Q1 — Does the shipped Rand/AI registry express any part of DRAFT §5.2's prose
contract?** Partly in vocabulary, not in mechanism — and Motoko uses neither half.

DRAFT §5.2 (`papers/motoko-dst-report/DRAFT.md:423-451`) states its replay contract at
**world/program granularity**: seeded *discovery* reacts to the external requests
production code makes and records an ordered, versioned `ExecutionProgram`; *strict
replay* consumes that exact program without invoking the generator and compares
normalized terminal traces member-for-member (interaction logs and world-request
censuses, not digests alone); the program, not the seed alone, is the reproduction key.

The registry states its contract at **(effect, mode) granularity**: per-pair labels in
{deterministic (= replay must pin), re-sampleable (= replay may redraw), opaque (=
replay must substitute from the harness)}. The `deterministic` label is the same *idea*
as §5.2's "pin this value", and `re-sampleable`/`opaque` name distinctions §5.2's prose
never draws per effect. But the levels do not meet: Motoko's strict replay compares
interaction logs, never consults an effect mode, and — per the check above — references
no registry row. The Rand dispatch pilot (seeded via `AILANG_SEED`) is also a different
determinism mechanism from Motoko's seeded discovery (generator + recorded program).
So: the registry *taxonomises* a contract §5.2 states only in prose, but it does not
*implement* any part of §5.2's mechanism, and nothing in the tree consumes it.

**Q2 — What would the Clock/FS rows need?** Exactly sprint 3's frozen scope, no more:

1. Legal modes in `effectSchema` via the sprint-1 validation table
   (`Clock: wall|pinned`, `FS: real|fixture`; defaults `wall`, `real`; bare forms
   unchanged).
2. Registry rows: Clock pinned→deterministic / wall→re-sampleable;
   FS fixture→deterministic / real→re-sampleable (parent taxonomy).
3. Dispatch wiring to the switches that already exist (`clock.go` virtual-time path,
   `fs.go` sandbox path) with typed errors, not silent fallbacks
   (pinned-without-`AILANG_SEED` fails at first clock op; fixture escape fails loudly).
4. Until then, `ContractFor(Clock, *)` / `ContractFor(FS, *)` return unknown, and under
   the doc's no-silent-fallback rule replay tooling must treat them as unknown — a
   wrong replay label corrupts replay decisions.

**Re-evaluation trigger (`fires_when`):** `ContractFor` gains Clock/FS rows upstream
(visible as new keys in `ailang/internal/replay/contracts.go`) **and** a Motoko-side
consumer exists that dispatches on a contract label. Either condition alone keeps this
entry as-is.

## Do not claim

- The registry is **not** fully shipped across all effects (Rand dispatch pilot +
  Rand/AI labels only; Clock/Net/FS in another sprint).
- No Motoko adoption is claimed (zero references, verified above).
- This entry is an evaluation, not a fourth ask. D3 files three asks; this is the
  bounded registry record.
