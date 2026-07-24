# ADR-001: What Constitutes Motoko's DST — Definition, Taxonomy, and the Term's Scope

Date: 2026-07-24
Status: Proposed
Consolidates: `NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md` (this project) — the running
analysis across PRs #84 → #99 → #100 that this ADR formalizes.
Relates to: `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` (the origin
architecture ADR; unchanged by this ADR). As-built framework doc is Track 3 of this project
(`design_docs/implemented/motoko_agent/`, not yet written).

## Context

`../001_DST/ADR-001` named the method "Deterministic Simulation Testing" and built the layered
scenario-and-invariant system that now exists (L0 policy invariants, L1 loop-state scenarios, L2
harness boundary, L3 event parity, the typed `LedgerTrace` oracle, ABI-lockstep conformance).
PRs #99 and #100 added a seeded axis: a PRNG-seeded generator draws input parameters and drives
production transition code (`scripts/dst/compaction_seeded_dst.ail`,
`scripts/dst/phase_c_seeded_dst.ail`).

The branch name (`mot-43-l1-seeded-families`) and the make target (`dst_seeded`) carry the "DST"
label — whose middle word is *Simulation*. A review of what actually landed at HEAD found the
label is being applied to something that does not yet meet the established engineering definition
of DST — and, more
importantly, that **the canonical definition of DST cannot be met by an agent harness as-written,
and should not be the target.** The physical-environment simulation that DST-the-artifact
(FoundationDB, TigerBeetle, Antithesis) is built around is overkill here; but "therefore drop the
simulated environment" is the wrong conclusion. The environment relocates rather than disappears.

Nobody has written down what "DST" is *entitled to mean* in this repo. The result is that HEAD —
which is honest, strong property-based testing — wears a label that promises capabilities it does
not have, and the one architectural move that would earn the label has no formal target. This ADR
fixes the definition, the taxonomy, the scope boundary, and the naming rule.

Grounded against HEAD (branch `arniwesth/mot-43-l1-seeded-families`):
- `scripts/dst/phase_c_seeded_dst.ail` — four seeded families; seed draws scalar params.
- `Scripted([ScriptedStep])` reaches the real driver: `src/core/session.ail:684,696`,
  `src/core/agent_loop_v2.ail:102-104,120-122`.
- No scheduling / interleaving / fault-injection / virtual-clock vocabulary exists anywhere in
  `.ail` (grep over `src/`, `scripts/`: every `crash`/`partition` hit is a production-behavior
  comment, never a test-injected fault). The seeded path has no clock dimension at all; the
  framework normalizes clock-derived fields rather than virtualizing them (`../001_DST/ADR-001`).

## Definition of DST (the engineering artifact)

DST, as pioneered by FoundationDB and productized by TigerBeetle / Antithesis / Resonate, is:

> Run the **real system logic**, as one or more logical actors, against a **simulated
> environment** whose entire behavior — event orderings, fault timings, clock advances, and all
> randomness — is a **deterministic function of one seed**. Search that space by running many
> seeds; a failing run *is* a seed, replayable bit-for-bit.

It decomposes into seven pillars. The discriminating power is not evenly distributed: pillars 3,
4, 5 are what make simulation *simulation*; pillar 6 is shared with property-based testing and so
does not distinguish anything.

| # | Pillar | What it requires |
|---|--------|------------------|
| 1 | **Hermetic determinism** | All ambient nondeterminism (time, IO, rand, map order) funneled through one seed; touching the real world is forbidden |
| 2 | **Simulated environment** | A *model of the world* the system runs against, including its adversarial behaviors |
| 3 | **Seed-driven schedule** | The seed generates the *ordering of events over time* — the execution, not the input |
| 4 | **Fault injection** | Seed-timed faults the environment can actually produce |
| 5 | **Time as a controlled dimension** | The clock is *advanced by the simulator*, not deleted — timeout/retry races are reachable |
| 6 | **Invariant oracle** | Safety + liveness checked over the whole history (shared with PBT) |
| 7 | **Search economics + reproduction** | Many seeds, red seed = bug, deterministic replay, ideally shrinking |

The single axis that separates DST from its neighbors: **the unit a seed controls is an
*execution*, not an *input value*.**

- **Trace replay** pins *recorded* outputs and asserts equality — historical inputs, one path,
  change-detector oracle.
- **Property-based testing (PBT)** generates counterfactual *inputs* and asserts *invariants* —
  bug-detector oracle, but authored control flow.
- **DST** generates *executions* — schedules of events, faults, and time — and asserts invariants
  over the resulting history.

## Decision

### D1. Motoko's target method is **single-actor, logical-fault DST**

We adopt a scoped variant of DST as the target, defined by three deliberate boundary choices, not
by omission:

1. **Single-actor.** The agent loop is one sequential logical thread of control. There is no
   concurrency to interleave *between actors*. Pillar 3 therefore takes its **linear** form: the
   seed generates a *temporal sequence of environment responses over one trajectory* (step 1 tool
   call, step 2 tool timeout, step 3 retry, step 4 approval denied), not an interleaving lattice.
   This is still a generated *schedule* and still legitimately *simulation* — it is simply a line,
   not a lattice, which is why it is cheap.

2. **Logical faults, not physical.** The environment Motoko runs against is **the LLM provider and
   the tool/world boundary**, not disk sectors or network transport. Pillar 2 does not disappear;
   it *relocates* to the provider/tool **protocol** surface. The faults worth injecting (pillar 4)
   are the ones that cause real agent bugs and are already typed values, not kernel-level
   simulations:
   - **Provider:** truncated tool call, malformed JSON args, hallucinated tool name, wrong
     `finish_reason`, duplicate `tool_call_id`, 429 / 500 mid-trajectory, stream cut mid-token,
     empty content.
   - **Tool:** a write that fails, a subprocess that hangs past budget, garbage stdout, an MCP
     server dropping mid-call.
   - **Approval:** denial or delay landing between a `tool_use` and its `tool_result`, leaving a
     dangling tool call the next provider turn rejects — a real ledger-integrity bug class.

3. **Physical-fault and multi-actor simulation are OUT OF SCOPE by decision.** Torn writes,
   block-level corruption, partitions, and peer consensus faults test a correctness contract
   Motoko does not have: no replication, no consensus, and no *physical* durability contract
   (no fsync/recovery/replication). The boundary is physical vs. logical, not durability-in-
   general: the ledger's guarantee that a `run_summary` is emitted on *every* termination path —
   success and the abnormal ones (`cost_exhausted`, `dp7_rejected`, `compaction_exhausted`,
   `max_steps`; `src/core/session.ail:826-829`) — is a *logical* completeness invariant that IS in
   scope and assertable over the `LedgerTrace`. This exclusion is revisited only if Motoko grows a
   distributed or crash-recoverable-storage component.

### D2. The seven-pillar checklist is the conformance definition

Motoko is entitled to the unqualified word **"DST" / "simulation"** in code, CI target names, PR
descriptions, and docs only when it meets, at the logical-fault / single-actor level:

- Pillar 1 (hermetic determinism) — **met**.
- Pillar 2-logical (the provider/tool protocol modeled as `ScriptedStep`, incl. fault variants;
  same mechanism as pillar 4) — **required** (D4).
- Pillar 3 (seed generates the trajectory of environment events) — **required**.
- Pillar 4 (seed injects logical faults from the D1.2 catalogue) — **required**.
- Pillar 5 (a stepped virtual clock carried in the script; timeouts reachable) — **required**.
- Pillar 6 (invariants over the resulting `LedgerTrace`) — **required**.
- Pillar 7 (reproduction contract: seed + generator-schema version) — **required**.
- Pillar 2-physical, pillar 3-concurrent — **explicitly not required** (D1.3).

Until pillars 3/4/5 are met, the method is **not** DST regardless of how much machinery exists.

### D3. HEAD is not DST; name it honestly until D2 is met

At HEAD the seeded axis meets pillars 1 and 6 solidly, half of 7 (repro substrate without the
schema-version key), and **none of 2-logical, 3, 4, 5**. The honest label for HEAD is
**"seeded deterministic scenario + parameter-generation testing"** — property-based testing over
agent-loop state. It is *strictly stronger than trace replay* (you cannot replay a trace never
recorded; the inputs here were never observed) and *strictly weaker than DST*.

Rule adopted: **the word "simulation" is not used for the seeded axis in new docs, target names,
or PR descriptions until D2 is met.** The interim honest qualifier, if one is wanted, is
**"logical-fault DST"** once faults land — never **"Soft DST"** (see Rejected Alternatives).
Existing target names (`dst_seeded`) are grandfathered but the as-built doc (Track 3) must state
the distinction explicitly.

### D4. The environment is formally the provider/tool protocol boundary

Motoko's "simulated environment" is defined as the set of typed port responses at the model and
tool boundary. Its concrete representation is the `ScriptedStep` enum consumed by
`Session.run_v2_from_messages(… Scripted(script))` (`src/core/session.ail:684`). Extending that
enum with fault variants (`Malformed | RateLimited | Truncated | ToolTimeout | ApprovalDenied | …`)
is how pillars 2 and 4 are satisfied — a data enum, not a simulator. This is the formal reason the
physical-fault exclusion (D1.3) *reduces* rather than removes the environment model.

## The bar that earns the term (the mot-44 target)

D2 is met by one architectural move, whose substrate is already in the tree:

> A seed produces a **sequence of scripted provider steps** — finish reasons, tool-call shapes,
> telemetry values, a stepped virtual clock, **and injected faults** from the D1.2 catalogue —
> driven through `Session.run_v2_from_messages(… Scripted(script))`, with invariants asserted over
> the resulting `LedgerTrace`.

This single move installs pillar 3 (linear ordering), re-introduces pillar 5 (clock stepped by the
script rather than deleted), opens pillar 4 (fault variants in `ScriptedStep`), and closes the
standing gap that **no generated family asserts over the ledger** — the layer the framework is
built around. `stub_step` already carries `Scripted`/`ScriptedStep`; the ledger already *is* the
trace. That work is the proposed next item (mot-44).

## HEAD scorecard (branch `arniwesth/mot-43-l1-seeded-families`)

| Pillar | Status at HEAD | Evidence |
|--------|----------------|----------|
| 1 Hermetic determinism | **Met, stronger than canon** — effect-enforced, not convention-enforced: the gate runs under a narrow `--caps IO,Env,Rand` and any unmodeled effect fails at perform time | caps-as-conformance |
| 2 Simulated environment (logical) | **Absent** — model port is a fake returning generated scalars, no environment-response model | `phase_c_seeded_dst.ail` draws `content_len`/`n_tail`/`n_systems` |
| 3 Seed-driven schedule | **Absent** — seed draws input params; `checkpoint_pressure`'s 2 steps are a *fixed authored* sequence | no scheduler vocabulary in `.ail` |
| 4 Fault injection | **Absent** — no seed-timed crash/denial/truncation | grep clean |
| 5 Virtual time | **Absent — normalized away, not virtualized** (the inversion of DST) | no clock dimension in seeded path |
| 6 Invariant oracle | **Met** — one-sided properties, `checkpoint_pressure` liveness assertion | property discipline held |
| 7 Search economics + repro | **Half** — RNG canary pins PRNG; but the default `DST_SEEDS=5 DST_BASE_SEED=1` yields 25 fixed cases (5 families — 4 in `phase_c` + 1 in `compaction` — × 5 seeds), identical every run: no shrink, no schema-version key | Open Questions |

**Verdict:** 2 of 7 solid (1, 6), one half (7), none of the three that constitute simulation
(3, 4, 5) — with pillar 5 normalized away rather than virtualized. HEAD is PBT, not DST.

## Consequences

Positive:
- The word "DST" acquires a checkable meaning in this repo (D2), so future PRs can be held to it
  instead of to a vibe.
- The physical-fault exclusion (D1.3) is now a *recorded decision* with a rationale, not an
  apparent gap a future reviewer re-opens.
- The mot-44 target is defined concretely and shown to be a small diff from HEAD.
- The relocation of the environment to the protocol boundary (D4) makes pillars 2+4 cheap, which
  removes the usual excuse for skipping simulation ("a network simulator is too much work").

Negative / costs:
- New docs and target names must drop "simulation" from the seeded axis until D2 is met (D3);
  this is a naming discipline the team must actually keep.
- `ScriptedStep` must grow fault variants, and every consumer match becomes non-exhaustive until
  updated — an ABI-lockstep-style ripple the conformance kit will surface (by design).
- Virtual time re-introduces a controlled clock the seeded path never modeled.

## Rejected Alternatives

### "Soft DST" as the name
Rejected. "Soft" reads as *less rigorous*, and rigor is the axis where Motoko is **stronger** than
the canon — hermeticity is effect-enforced, not convention-enforced. What Motoko gives up is
**scope** (multi-actor concurrency, physical fault layer), not rigor. Naming the rigor reduction
misdescribes the artifact. The scope reduction is named directly: **single-actor, logical-fault**
(D1). If an interim qualifier is wanted, "logical-fault DST" is honest; "Soft DST" is not.

### Calling HEAD "DST" / "simulation" now
Rejected (D3). HEAD meets none of pillars 3/4/5. Using the term now spends the credibility the
term needs when the real capability lands, and misleads anyone reading CI names or PR titles into
thinking event-ordering/fault coverage exists.

### Simulating physical faults (disk/network transport)
Rejected (D1.3). Tests a correctness contract Motoko does not have. Overkill, and it would divert
effort from the logical-fault surface where real agent bugs actually live.

### Multi-actor scheduling (canonical pillar 3)
Rejected for the agent loop (D1.1). The loop is single-actor and sequential; there is nothing to
interleave. The linear-schedule form of pillar 3 is the correct and sufficient target. Revisit
only if concurrent tool execution or multi-agent orchestration becomes a first-class, ledger-
affecting concern.

### A new ADR is unnecessary (per this project's scope note)
`NOTE-dst-consolidation-scope-and-sequence.md` argued "why no new ADR" — correctly, for the three
*consolidation tracks*, which were execution of `../001_DST/ADR-001`'s existing decisions. This
ADR records a *different kind* of decision: the definition, scope boundary, and naming rule for the
term itself, prompted by the trace-replay analysis. It does not reopen or contradict the
consolidation tracks.

## Open Questions

- **Generator-schema versioning (pillar 7 gap).** A stamped generator-schema version alongside
  `family=` closes the "widen a range → historical seeds silently remap → canary stays green"
  hole. Format and where it lives (trace line? make target? both) is unspecified.
- **Search economics.** Should CI rotate `DST_BASE_SEED` nightly (date-derived) and promote failing
  seeds into the fixed suite, converting the machinery from decoration into coverage? Recommended
  in the analysis; not yet a decision.
- **Shrinking.** With 4–5 drawn params per family, counterexamples arrive mid-sized. Is minimization
  worth building at single-actor scale, or deferred until trajectories (mot-44) make cases larger?
- **Fault-variant catalogue authority.** Should the D1.2 fault list be exported from a single source
  (so `ScriptedStep` variants and the provider's real error handling stay in lockstep), mirroring
  the compaction-constant export discipline from `../001_DST/ADR-001` R5?

## Notes for a reviewer

This ADR is grounded but unreviewed. A grounding pass should re-verify at HEAD: the four families
and the scalar-param draws in `scripts/dst/phase_c_seeded_dst.ail`; the `Scripted` reaching
`session.ail:684,696`; and the absence of any scheduler/fault/clock vocabulary in `.ail`.
