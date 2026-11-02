# AILANG World overlap and boundary

Date: 2026-07-24. Revised: 2026-10-18.
Status: Informational companion to
`ADR-001-deterministic-test-world-architecture.md`
Upstream reviewed: the July text reviewed
[`sunholo-data/ailang-world@03efeef`](https://github.com/sunholo-data/ailang-world/tree/03efeef0a4d02311d78b6d6d4f95ea3752a22ea1).
This revision reviews
[`sunholo-data/ailang-world@a0c73053`](https://github.com/sunholo-data/ailang-world/tree/a0c73053f10092fd511ad22fcf6b95d6a3f896aa)
(`dev`, 2026-10-17), the state behind the `v1.0.0-rc.1` pre-release of 2026-10-16.

## Conclusion

The ruling of the July text stands and has been adopted on both sides. The Motoko deterministic
test world and AILANG World share a transition discipline: explicit state transitions,
nondeterminism isolated at effect boundaries, recorded effect results, typed evidence and
deterministic replay. They are different layers and neither makes the other redundant.

The Motoko deterministic test world is an ephemeral, seed-driven effect-scenario interpreter used
to test the real session driver. AILANG World is a persistent production governance, execution,
provenance and storage substrate. World adopted this ruling on 2026-07-31 and records it in
[DESIGN.md §16](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/DESIGN.md#L683-L694)
and in its
[REFERENCES.md entry for this note](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/REFERENCES.md#L421-L442),
which also says the note's first revisit trigger has fired and that a boundary review is due on
both sides. This revision is that review on the Motoko side.

What changed is that World is no longer a plan. In July its store, daemon, effect broker,
episode replay and protocol boundary were later milestones. At `a0c73053` all of them exist, the
seven release clauses are marked met, and the integration boundary this note called "future" is
now a concrete contract that can be compared field by field. Three things follow:

1. The July "candidate integration shape" splits into two routes. Motoko can already be a World
   *resident* through its `mcp` extension, on paper and untested, because World serves its tools
   over streamable-HTTP MCP and Motoko's bridge speaks that transport with bearer auth. The
   `AilangWorldLiveAdapter` route, in which World's broker carries Motoko's own live effects,
   remains future and is now blocked on a named World gap rather than on World's absence.
2. The ADR's upstream recorded-stream blocker is cleared on Motoko's side. AILANG v0.33.0 shipped
   `stepWithStreamRecorded` on 2026-08-04 and Motoko adopted it on 2026-08-05 (WI-C1/C2). World's
   effect records remain terminal-only, so the partial-stream-then-error requirement is now a gap
   in World, not in Motoko or AILANG. World's REFERENCES.md names it as such.
3. Motoko's standing in World's plan moved. World's charter demoted Motoko on 2026-07-23 from a
   gating arm of the non-inferiority floor to an "optional third arm, informative and never
   gate-blocking", citing "motoko's current instability". The floor was run to a final verdict on
   2026-10-15 with Claude Code and codex only. The upstream AILANG repo's own Motoko mission names
   World as the first lane for Motoko's executor trial. Both are recorded below because they set
   the order in which any integration work would be judged.

## What changed since July

### On World's side

| Concern | At `03efeef` (2026-07-24) | At `a0c73053` (2026-10-17) |
|---|---|---|
| AILANG surface | `world/types.ail`, `world/logepoch.ail`; pure types only | `world/core`: types, transitions, contracts, logepoch; `EvidenceGrade` (PROVEN, TESTED, ATTESTED, CLAIMED); published to the AILANG registry as `world/core@0.1.1` on 2026-10-02 through World's own propose, verify, commit pipeline (clause 7) |
| Store and daemon | Later milestones | SQLite content-addressed object store, append-only transition log, intent/outcome journal; `ailang-worldd`, a loopback-only daemon with REST API and CLI; one writer per file-backed database (clauses 1 and 2) |
| Effect broker | Planned as M3 | `host/broker` landed. Two modes, `Live` and `Replay`. Every effect request writes exactly one immutable `EffectRecord`, whether allowed, denied or failed. Capability and budget law Z3-proven in a sketch and asserted by the Go side over every record (clause 3) |
| Handlers | None | `FS.Read`, `FS.Write`, `Git.Commit`, `Model.Infer`, `Workspace.Read`, `Workspace.Write`, `Workspace.Exec`, `Ailang.Check`, `Ailang.Run`, `Ailang.RunEnv`, `Ailang.RunNet`, `Ailang.Discover`, `Ailang.CLI`. `Model.Infer` runs `std/ai call` through the pinned interpreter and returns one result; it does not stream |
| Receipts | Not designed | Effect journal: a durable intent is written before dispatch and an outcome after the record. An effect with no intent was never dispatched; an intent with no outcome is *indeterminate* and fails closed. Operators are told not to retry an indeterminate receipt automatically |
| Replay | "`ailang replay <trace.jsonl>` noted as a primitive to probe" | `host/replay` re-runs each pinned transition source on the archived interpreter binary with `ailang run`, byte-compares the result and the reconstructed world hash, and fails on any divergence. Effect results come from the broker's `Replay` mode, which serves recorded results or denials and never calls a handler. No daemon route or CLI verb runs a replay yet; the engine is exercised by tests |
| Interpreter identity | Designed | Every log entry header carries the interpreter's content hash; the archived binary is re-hashed before each run; a semantics-epoch registry selects the epoch. `pins/ailang-releases.json` pins the interpreter at AILANG v0.41.0 and the tool binary at v0.54.15 |
| Protocol boundary | Planned | MCP over streamable HTTP at `POST /mcp/` and A2A at `POST /a2a/`. A session is a bearer token bound to one *episode* and a set of grants written `EFFECT=SCOPE:BUDGET`. Residents see only the tools their grants cover: eight AILANG coding tools plus the operator-gated `workspace-exec` (clause 6) |
| Motoko's role | M4 "first native agent"; the floor's reference arm | Optional third arm, never gate-blocking (charter amendment 2026-07-23). Floor FINAL 2026-10-15: Claude Code and codex both held non-inferiority; 414 of 414 graded cells passed; Motoko was not run |
| Release | Pre-M1 | `v1.0.0-rc.1` (2026-10-16); all seven clauses marked met; `v1.0.0` waits on rows 156, 150 and 151 |

### On Motoko's side

- **Recorded streams.** The ADR's D1 gate was answered on 2026-08-05
  (`NOTE-c1-c2-execution-report-and-plan-corrections.md`): immediate projection, exact returned-log
  parity, partial-stream-then-error and no duplicate delivery were all proven against a fixture
  server, on the adopted upstream API. The July worry that generic effect-trace replay would not
  capture provider chunks losslessly no longer applies to Motoko's own ports.
- **Artifact identity.** Motoko's `ExecutionManifest` records the toolchain as a version string
  (`toolchain` in `src/core/dst_profile.ail`; fixtures use the form `ailang 0.33.0`). The July
  recommendation to record an exact interpreter artifact hash is still open.
- **Toolchain pin.** Motoko requires AILANG `>=0.52.5` (`ailang.toml`). World runs transitions on
  v0.41.0 and its tool binary on v0.54.15. Any artifact or package shared between the two must
  name the interpreter it was produced under; a version floor is not enough.
- **MCP transport.** Motoko's `mcp` extension (`packages/motoko-ext-mcp`) calls MCP servers through
  the bundled `assets/mcp-call.mjs`, which posts JSON-RPC `tools/list` and `tools/call` to a
  `base_url`, sends `Accept: application/json, text/event-stream`, supports `header:Bearer` auth
  from an environment variable, and parses SSE or plain JSON replies. That is the request shape
  World's `AGENTS.md` documents for `/mcp/`. The config field named `transport` defaults to
  `stdio`, but the `stdio` path is the bridge described here; the `mcp-http` value is a stub for an
  unrelated AILANG feature and returns an error. Nothing in this repo has yet called a World
  daemon; the compatibility claim is read from both sides' source, not measured.

## Comparison

| Concern | Motoko deterministic test world | AILANG World at `a0c73053` | Ruling |
|---|---|---|---|
| State | Driver-threaded run state containing the program cursor, generator/replay state, virtual clock, synthetic environment, randomness and logical resources | Persistent immutable world revision (`revision`, `stateRoot`, `logHead`); one row per commit; old worlds stay readable | Similar transition discipline; different state, ownership and lifetime. Unchanged |
| Effect boundary | Returns synthetic provider, tool, approval, environment, random and time outcomes, including generated faults and latency | Live broker: capability, scope and budget decision, handler dispatch, one `EffectRecord` per request; `Model.Infer` is terminal-only | The adapter boundary now exists on World's side but lacks ordered intermediate emissions |
| Replay unit | Exact resolved `ExecutionProgram` plus execution manifest; strict and compatibility-aware regression replay | Recorded episode: pinned transition source, pinned interpreter artifact, recorded result bytes and world hash per entry; broker records for effects | Complementary. World's replay reconstructs what happened; Motoko's serves what could happen to the real driver |
| Trace | Complete `LedgerTrace` is the domain oracle for one Motoko session | Invocation record (`world/invocation-record/v2`) linking input, plan, output and ordered effect record refs; `ailang-worldd why <entry>` walks it | Bind by content hash or stable identity; do not merge the schemas. Unchanged |
| Receipts for ambiguous outcomes | Project 034 (effect disclosure for tool faults) is defining Motoko's classes | Intent before dispatch, outcome after record; indeterminate fails closed; MCP is at-least-once with no idempotency, A2A task ids are idempotent within a session | Align the vocabulary (never dispatched, denied, failed, indeterminate) before either side hardens its own |
| Fault and time search | Seeded reactive discovery, logical faults, virtual latency and clock, invariant checking, rotating corpora | None. World's replay is byte-exact reproduction of recorded history; its daemon has no generated-fault or virtual-time mechanism | Remains Motoko DST's responsibility. Unchanged |
| Purpose | Hermetically test Motoko's real production driver | Govern and record production agent activity; answer provenance questions | Test harness versus production substrate. Unchanged |

World's `World` type is still `{revision, stateRoot, logHead}` and its `Evidence` variants still
carry content references
([`world/types.ail`](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/world/types.ail)).
Neither is a substitute for D1's `world_state`, which carries the test program cursor, clock,
generator state, synthetic environment and modeled resources. A World transition log is not an
`ExecutionProgram`: a production recording describes what occurred, while DST discovery reacts to
the real driver's requests and selects synthetic outcomes that change the later trajectory.

## Integration shapes

The shared seam is still the typed request/result contract, not either project's state type. Two
routes now exist.

### Route A: Motoko as a World resident (available on paper)

```text
Motoko session driver
  -> Motoko `mcp` extension (bundled bridge, bearer session, POST /mcp/)
       -> World daemon: plan (pure transition) -> broker (one effect) -> commit (one log entry)
  <- tool result + `world` block {plan ref, effects[].status, effects[].record}
  -> Motoko LedgerTrace keeps the refs; World keeps the provenance
```

This is the shape the upstream Motoko mission's executor trial asks for (land one real World sprint
with held-out tests passing), and it needs no change to Motoko's core. It does need:

- an `mcp` server entry with World's `base_url`, `header:Bearer` auth from `WORLD_SESSION`, and a
  tool mapping from World's tool ids (`ailang-read`, `ailang-write`, `ailang-edit`, `ailang-check`,
  `ailang-run`, `builtins-search`, `examples-search`, `ailang-cli`) to Motoko canonical tools;
- a profile that withholds Motoko's shell and native file tools, since a resident has no shell, no
  network, and no write access outside its episode worktree;
- an operator to mint the session. Minting is attended today: `ailang-worldd session mint` runs
  with the daemon stopped and asks for confirmation on a terminal. That rules out unattended Motoko
  runs on World until World changes it;
- a retry policy that respects World's semantics. MCP calls are at-least-once with fresh task ids,
  so a resend after a lost reply runs the tool again and records both runs. A2A task ids are
  idempotent within a session. Project 034's disclosure classes should map onto this before the
  route is exercised.

The resident route does not touch the DST boundary. Motoko's driver, recovery policy, budget
decisions, phase transitions and finalization stay in Motoko, and the deterministic test world
still tests them with World's tools modeled as tool outcomes like any other.

### Route B: `AilangWorldLiveAdapter` (future)

```text
Motoko production session driver
  -> typed world/effect request
       -> DeterministicTestWorld adapter
       -> current direct LiveWorld adapter
       -> future AilangWorldLiveAdapter -> World broker (Live mode)
  <- ordered emissions + typed result + explicit successor adapter token
  -> Motoko LedgerTrace and terminal invariant oracle
```

Here World's broker would carry Motoko's own live effects: provider calls, tool runs, approvals.
The contract on World's side is now concrete and the comparison is exact:

- `EffectRecord` is `{Effect, Scope, Cost, BudgetBefore, BudgetAfter, Allowed, Failed, Denial,
  RequestRef, ResultRef}`
  ([`host/broker/record.go`](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/broker/record.go)).
  One request object, one result object, no intermediate emissions.
- `Model.Infer` returns one result from `std/ai call`
  ([`host/broker/handlers_model.go`](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/broker/handlers_model.go)).

The ADR's requirement is immediate projection of provider chunks plus an identical returned
ordered emission log, including the partial-stream-then-error case. A terminal-only record cannot
express it, so Route B stays blocked until World records ordered emissions. World's own
REFERENCES.md calls this "a REAL World gap for streaming `Model.Infer` records, converging with
upstream ailang recorded-stream work". The upstream API that Motoko adopted (`stepWithStreamRecorded`,
AILANG v0.33.0) is the natural shape for World to record.

An adapter must not move Motoko's history construction, recovery policy, budget decisions, phase
transitions or finalization into the broker. Those remain production behavior tested by the ADR.

## Reuse opportunities

### Typed effect envelope

The July list, checked against World's record and invocation objects:

| Field in the July list | World at `a0c73053` |
|---|---|
| Effect kind and origin, including extension identity | `Effect` and `Scope`; no extension or origin identity |
| Stable causal identity and global encounter ordinal | Invocation id `a2a:<episode>:<task-id>`; effect id within a plan (`e1`); journal ordinal minted by the store inside the appending transaction |
| Bounded request projection and digest | `RequestRef` to a `world/effect-request/v1` object holding the full payload, not a bounded projection |
| Deadline and completion timing | `LogicalTime` on the intent; `Now` supplied by the caller, the broker never reads a clock |
| Ordered intermediate emissions | Absent |
| Typed success/error result | `Allowed`, `Failed`, `Denial`; `ResultRef` to the handler's bytes |
| Capability/profile identity | Grant matched by effect name and scope; budget before and after |
| Content references for recorded evidence | `RequestRef`, `ResultRef`; the invocation record links input, plan, output and effect records |

Alignment is worthwhile for the fields both sides have. The partial-stream-then-error case and the
exact returned emission log remain Motoko's requirements alone, and a shared schema that records
only a terminal result is still insufficient.

### Content-addressed artifacts and manifests

World has now done what the July text recommended for D8, and the mechanism is readable:
`serve --ailang-bin` archives the interpreter by content hash, every log entry names that hash in
`header.interpreter`, the capsule re-hashes the archived bytes before each run, and replay resolves
the interpreter from the entry's own hash rather than from a registry candidate
([`host/replay/replay.go`](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/replay/replay.go)).
`pins/ailang-releases.json` is the single source of truth for the pinned releases, with per-platform
tarball and binary digests.

For Motoko the recommendations stand, now with a worked precedent:

- record an exact AILANG interpreter artifact hash in the execution manifest, not only the
  `toolchain` version string;
- content-address the serialized `ExecutionProgram`, complete `LedgerTrace` and normalized
  execution manifest;
- retain the bytes required for replay rather than only their digests; and
- fail explicitly when a pinned artifact is unavailable rather than substitute a believed-compatible
  version.

Motoko need not depend on the World daemon to adopt these. If World later stores DST evidence, a
`TestReport` or `RecordedEffect` reference can point to the exact program, trace and manifest
objects without replacing their Motoko-owned schemas. World's `gradeOf` would grade such a
`TestReport` as TESTED and a `RecordedEffect` as ATTESTED; nothing a Motoko run produces can mint
PROVEN on World's side.

### Receipts and ambiguous outcomes

World's effect journal and Motoko's project 034 address the same failure: an effect whose outcome
is unknown to the caller. World's answer is structural: intent before dispatch, outcome after the
record, four distinguishable states from the record bytes alone, indeterminate fails closed and is
resolved by deterministic reconciliation, never by automatic retry. Project 034's ADR on effect
disclosure for tool faults should be checked against that vocabulary so that a Motoko session
running on World reports the same class World recorded.

### Trace binding

`LedgerTrace` and World's invocation history answer different questions:

- `LedgerTrace`: did the Motoko session execute legally and satisfy its whole-run invariants?
- World invocation record and effect records: who proposed and authorized the run, which
  capabilities and effects it used, what it produced, and why it committed?

Every World tool result carries a `world` block with the plan ref and each effect's status and
record ref. A Motoko resident should keep those refs in its trace so the two histories bind by
identity. Neither an OTEL projection nor a World log entry substitutes for the complete returned
`LedgerTrace`.

## The replay primitive, revisited

The July text asked a future plan to probe `ailang replay <trace.jsonl>`. Two facts settle it:

- AILANG v0.52.5 still ships `ailang replay` with `-caps`, `-entry`, `-file`, `-json` and `-quiet`.
- World does not use it. World's replay re-runs pinned transition source with `ailang run` on the
  archived binary and byte-compares the output; effects are served from records by the broker's
  `Replay` mode.

Neither provides the DST contract: request-reactive seeded discovery, strict causal matching across
provider, tool, approval, environment, random and clock, generated faults with virtual time, partial
streams followed by failure, immediate projection with an identical returned log, a complete
terminal `LedgerTrace`, and strict and compatibility-aware regression replay. Motoko's own replay
(`make strict_replay` and the corpora) remains the mechanism, and the recorded-stream half of the
July probe list was answered on Motoko's side on 2026-08-05.

## Current reuse limit

Direct code reuse is still limited, for different reasons than in July:

- World's host is Go. Its AILANG surface is `world/core`, a registry package Motoko could depend on
  for `HashRef`, `Evidence` and `EvidenceGrade` if it wanted to emit World-shaped evidence. Check
  that the package projects cleanly under Motoko's AILANG floor (`>=0.52.5`) before depending on it;
  World's own frozen-compiler pin for that package is v0.41.0.
- Do not make Motoko DST depend on the World daemon, its broker or its replay engine. The daemon is
  one writer per database, replay has no operator entrypoint, and session minting is attended.
- Do not reuse the persistent `World` or `RecordedTransition` types as the test-world state or the
  execution program. Unchanged.
- Route A needs configuration and a profile, not World code. Route B needs World to record ordered
  emissions first.

## Terminology

Both designs use "world" as a central term. World adopted the July rule in DESIGN.md §16:
`DeterministicTestWorld` for the ADR's synthetic execution environment, `AilangWorld` for the
external persistent substrate, and never a bare shared `World`. Two more collisions are worth
naming now that both systems run:

- **Session.** In Motoko, one driver run. In World, a bearer credential bound to one *episode* and a
  set of grants. A Motoko session on World would hold one World session for one World episode.
- **Replay.** In Motoko, serving a resolved `ExecutionProgram` to the real driver. In World,
  re-running pure transitions on the pinned interpreter while effect results are read back from
  records. Say which one is meant.

## Revisit triggers

Status of the July triggers:

1. World's M3 effect-broker request/result contract is proposed. **Fired.** `host/broker` landed;
   this revision is the review.
2. Motoko begins native AILANG World integration. **Not fired.** The upstream Motoko mission defines
   the first step as landing one real World sprint through World's tools (its row 25), and that
   mission has been paused since 2026-09-08.
3. AILANG gains the recorded-stream API required by ADR D1. **Fired** 2026-08-04 (v0.33.0); adopted
   by Motoko 2026-08-05.
4. World's scheduler introduces concurrent ledger-affecting Motoko execution. **Not fired.** The
   daemon is one writer per database with a per-episode lock; speculative execution (World M5) has
   not landed.

New triggers for the next review:

5. World's effect records gain ordered intermediate emissions, or a streaming `Model.Infer` record.
   This unblocks Route B.
6. World ships an operator replay entrypoint (a daemon route or CLI verb).
7. World's session minting becomes unattended-capable. This is the precondition for any automated
   Motoko-as-resident run.
8. World tags `v1.0.0`, or its pinned interpreter epoch changes (World row 139).
9. The upstream Motoko mission unpauses and runs the World executor trial.
10. Motoko's project 034 lands its disclosure classes; check them against World's four receipt
    states.

The review should decide whether a common typed effect envelope and artifact codec are mature
enough to share, and whether Route A has been exercised. It must not weaken the ADR's
explicit-state, exact-emission, hermetic-profile, complete-trace or seed-driven search requirements.

## Sources

World, at `a0c73053` unless stated:

- [README.md](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/README.md): status, the seven clauses, the floor and the value, effect receipts.
- [DESIGN.md §16 and §17](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/DESIGN.md#L678-L713): the Motoko boundary ruling and milestones.
- [REFERENCES.md, the entry for this note](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/REFERENCES.md#L421-L442).
- [world-mission.md](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/world-mission.md): clause 4 and the 2026-07-23 third-arm amendment.
- [design_docs/implemented/w-effect-broker-m3.md](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/implemented/w-effect-broker-m3.md) and [w-effect-journal.md](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/implemented/w-effect-journal.md).
- [host/broker/record.go](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/broker/record.go), [host/broker/broker.go](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/broker/broker.go), [host/broker/handlers_model.go](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/broker/handlers_model.go), [host/replay/replay.go](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/host/replay/replay.go), [world/types.ail](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/world/types.ail), [pins/ailang-releases.json](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/pins/ailang-releases.json).
- [Floor FINAL evidence, 2026-10-15](https://github.com/sunholo-data/ailang-world/blob/a0c73053f10092fd511ad22fcf6b95d6a3f896aa/design_docs/verification/world-floor-final-2026-10-15/README.md).
- Docs site: [AGENTS.md](https://www.sunholo.com/ailang-world/AGENTS.md), [Results and errors](https://www.sunholo.com/ailang-world/docs/agents/results-and-errors), [Provenance and replay](https://www.sunholo.com/ailang-world/docs/concepts/provenance-and-replay), [Sessions and episodes](https://www.sunholo.com/ailang-world/docs/concepts/sessions-and-episodes). The landing page still says "5 of 7 release clauses met" and AGENTS.md still says the floor has not been run; the README is the current source.

Upstream AILANG:

- [design_docs/motoko-mission.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/motoko-mission.md): the executor trial targeting World (row 25), the pause since 2026-09-08.

Motoko:

- `NOTE-c1-c2-execution-report-and-plan-corrections.md` and
  `HANDOFF-post-upstream-recorded-stream-landing.md`: the recorded-stream adoption and D1 gate.
- `src/core/dst_profile.ail`: the `toolchain` manifest field.
- `packages/motoko-ext-mcp/exec.ail`, `mcp.ail`, `types.ail`, `assets/mcp-call.mjs`: the MCP
  transport.
- `../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`.
