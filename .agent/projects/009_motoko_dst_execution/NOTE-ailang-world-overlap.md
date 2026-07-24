# AILANG World overlap and boundary

Date: 2026-07-24
Status: Informational companion to
`ADR-001-deterministic-test-world-architecture.md`
Upstream reviewed:
[`sunholo-data/ailang-world@03efeef`](https://github.com/sunholo-data/ailang-world/tree/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1)

## Conclusion

The Motoko deterministic-test-world ADR and AILANG World have substantial architectural overlap:
both make state transitions explicit, isolate nondeterminism at effect boundaries, record effect
results, retain typed evidence, and require deterministic replay. They are nevertheless different
layers and neither makes the other redundant.

The Motoko test world is an ephemeral, seed-driven effect-scenario interpreter used to test the
real session driver. AILANG World is a persistent production governance, execution, provenance,
and storage substrate. A future AILANG World effect broker could implement a live adapter for
Motoko and its object store could retain Motoko replay artifacts, but it does not replace seeded
discovery, logical-fault generation, virtual time, or `ExecutionProgram` replay.

This distinction is load-bearing because AILANG World's design explicitly identifies Motoko as a
future native agent whose shell orchestration would be replaced by World transitions and whose
runs would become replayable transition history
([DESIGN.md, initial target and milestones](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/design_docs/DESIGN.md#L673-L694)).

## Comparison

| Concern | Motoko deterministic test world | AILANG World | Ruling |
|---|---|---|---|
| State | Driver-threaded run state containing the program cursor, generator/replay state, virtual clock, synthetic environment, randomness, and logical resources | Persistent immutable world revision identified by a state root and log head | Similar transition discipline; different state, ownership, and lifetime |
| Effect boundary | Returns synthetic provider, tool, approval, environment, random, and time outcomes, including generated faults and latency | Plans to execute capability- and budget-authorized production effects through a broker and record their real results | Principal future adapter boundary |
| Replay unit | Exact resolved `ExecutionProgram` plus execution manifest; supports strict reproduction and compatibility-aware regression | Content-addressed transition function plus exact interpreter artifact and recorded effect results; reconstructs persistent state bit-for-bit | Complementary replay contracts |
| Trace | Complete `LedgerTrace` is the domain oracle for one Motoko session | Transition log, evidence objects, and OTEL-bound traces provide operational provenance | Bind by stable identity or content hash; do not merge the schemas |
| Fault and time search | Seeded reactive discovery, logical faults, virtual latency/clock, invariant checking, shrinking, and rotating search corpora | No corresponding generated test-world mechanism in the reviewed implementation or M1/M3 descriptions | Remains Motoko DST responsibility |
| Purpose | Hermetically test Motoko's real production driver | Govern and record production agent activity | Test harness versus production substrate |

AILANG World's current `World` type contains `revision`, `stateRoot`, and `logHead`, while its
`Evidence` variants hold content references
([`world/types.ail`](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/world/types.ail#L20-L36)).
That type is not a substitute for D1's `world_state`, which must carry the test program cursor,
clock, generator state, synthetic environment, and modeled resources.

Likewise, a World transition log is not an `ExecutionProgram`. A production recording describes
what occurred. DST discovery reacts to requests from the real driver and deliberately selects
synthetic successes, faults, emissions, and latencies that change the later trajectory.

## Candidate integration shape

The shared seam should be the typed request/result contract, not either project's state type:

```text
Motoko production session driver
  -> typed world/effect request
       -> DeterministicTestWorld adapter
       -> current direct LiveWorld adapter
       -> future AilangWorldLiveAdapter
  <- ordered emissions + typed result + explicit successor adapter token
  -> Motoko LedgerTrace and terminal invariant oracle

Optional outer integration:
  AILANG World transition/evidence
    -> content references to ExecutionProgram, LedgerTrace, and replay manifest
```

An `AilangWorldLiveAdapter` would delegate live provider, tool, approval, and other external
requests to the World effect broker while preserving the ADR's typed response and emission
contract. It must not move Motoko's history construction, recovery policy, budget decisions,
phase transitions, or finalization into the broker. Those remain production behavior tested by
the ADR.

AILANG World's physical architecture places a result-recording broker between its semantic store
and external systems
([DESIGN.md, physical architecture](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/design_docs/DESIGN.md#L637-L658)).
Its current mission schedules that broker after the store and daemon, with FS, Git, model, and
`Human.Approve` handlers
([world mission queue](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/design_docs/world-mission.md#L226-L258)).
That M3 broker design is the first concrete point at which schema compatibility should be reviewed.

## Reuse opportunities

### Typed effect envelope

The projects could share or deliberately align:

- effect kind and origin, including extension identity;
- stable causal identity and global encounter ordinal;
- bounded request projection and digest;
- deadline and completion timing;
- ordered intermediate emissions;
- typed success/error result;
- capability/profile identity; and
- content references for recorded evidence.

Any shared schema must preserve the ADR's partial-stream-then-error case and exact returned
emission log. A request/result shape that records only a terminal provider result is insufficient.

### Content-addressed artifacts and manifests

AILANG World has already chosen tagged hashes, content-addressed transition functions, append-only
log entries, and an exact interpreter artifact as authoritative replay identity
([`world/logepoch.ail`](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/world/logepoch.ail#L41-L83)).
Those are useful precedents for D8:

- record an exact AILANG interpreter artifact hash, not only a version string;
- content-address the serialized `ExecutionProgram`, complete `LedgerTrace`, and normalized
  execution manifest;
- retain the bytes required for replay rather than only their digests; and
- fail explicitly when a pinned artifact is unavailable rather than silently substitute a
  believed-compatible version.

Motoko need not depend on the World daemon to adopt those artifact-identity rules. If AILANG World
later stores DST evidence, its `TestReport` or `RecordedEffect` references can point to the exact
program, trace, and manifest objects without replacing their Motoko-owned schemas.

### Trace binding

`LedgerTrace` and the AILANG World transition log answer different questions:

- `LedgerTrace`: did the Motoko session execute legally and satisfy its whole-run invariants?
- World transition/evidence history: who proposed and authorized the run, which capabilities and
  effects it used, what artifacts it produced, and why it committed?

The integration should bind a World transition/evidence entry to hashes or stable identities for
the Motoko program, manifest, outcome, and trace. It should not treat OTEL projection or a World log
entry as a substitute for the complete returned `LedgerTrace`.

## Existing `ailang replay` primitive

AILANG World's M1 design records that the released AILANG binary exposes
`ailang replay <trace.jsonl>` for replaying one program against a recorded effect trace. World
classifies its own planned replay component as a complementary store/log-level orchestrator that
pins artifacts, verifies the hash chain, and delegates single-transition execution to the released
binary
([M1 replay-layer analysis](https://github.com/sunholo-data/ailang-world/blob/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1/design_docs/planned/w-world-library-m1.md#L361-L376)).

The fresh Motoko implementation plan required by the ADR should explicitly inspect and probe this
command. It may supply a useful low-level recorded-effect replay primitive, but it must not be
assumed to satisfy the DST contract. A direct probe must determine whether it preserves:

- request-reactive seeded discovery rather than replay alone;
- strict causal request matching across provider, tool, approval, environment, random, and clock;
- generated logical faults and meaningful virtual-time behavior;
- partial provider streams followed by failure;
- immediate projection plus an identical returned ordered emission log;
- Motoko's complete terminal `LedgerTrace`; and
- strict and compatibility-aware regression replay semantics.

In particular, the ADR's upstream recorded-stream blocker remains unless this primitive can pass
the same immediate-projection and returned-log parity probe. The existence of generic effect-trace
replay is not evidence that provider stream chunks are captured losslessly.

## Current reuse limit

At the reviewed commit, direct code reuse is limited. AILANG World has landed its pure semantic
types/transitions and Go hashing/canonicalization foundation. Its SQLite store, artifact archive,
episode replay, daemon, and effect broker remain later milestones. The current types also do not
provide the ADR's timed emissions, causal matcher, generator state, virtual clock, logical fault
catalogue, or typed `HarnessFailure`.

Accordingly:

- reuse concepts and align envelopes now where that does not delay the Motoko architecture;
- do not make Motoko DST depend on an unfinished World daemon or broker;
- do not reuse the persistent `World` or `RecordedTransition` types as the test-world state or
  execution program; and
- revisit direct package or protocol reuse when the World effect-broker M3 contract exists.

## Terminology

Both designs use “world” as a central term, and the collision becomes operationally ambiguous once
Motoko can run on AILANG World. Documentation and implementation should distinguish:

- **Motoko deterministic test world** / `DeterministicTestWorld` for the ADR's synthetic execution
  environment; and
- **AILANG World** / `AilangWorld` for the external persistent production substrate.

The ADR's conceptual `LiveWorld` and `DeterministicWorld` names are not changed by this note, but a
fresh implementation plan should choose unambiguous concrete names. A bare `World` type shared
across the two meanings should be avoided.

## Revisit triggers

Review this boundary again when any of the following occurs:

1. AILANG World's M3 effect-broker request/result contract is proposed.
2. Motoko begins native AILANG World integration.
3. AILANG gains the recorded-stream API required by ADR D1.
4. AILANG World's scheduler introduces concurrent ledger-affecting Motoko execution, triggering
   the ADR's D9 concurrency review.

The review should decide whether a common typed effect envelope and artifact codec are mature
enough to share. It must not weaken the ADR's explicit-state, exact-emission, hermetic-profile,
complete-trace, or seed-driven search requirements.
