# ADR-001: What Constitutes Motoko's DST — Definition, Taxonomy, and the Term's Scope

Date: 2026-07-24
Status: **Accepted 2026-07-26.** Independent review and re-review both complete; `R1`–`R12`
dispositioned and `RR1`–`RR10` applied. No residual item blocked acceptance. Two items remain
*tracked* rather than blocking — the HEAD-facing hermeticity rule and the per-class naming
inventory (see *Residual items*) — and reducing the schema compatibility burden is future work
(see *Open Questions*). From this date D2 and D3 are binding: the naming rule governs new
identifiers, docs, and PR descriptions.
Consolidates: `NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md` (this project) — the running
analysis across PRs #84 → #99 → #100 that this ADR formalizes.
Amends: `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — replaces that
ADR's definition and naming threshold while preserving its decisions to exercise production code,
use explicit fakes, record normalized traces, and assert structural invariants.
Follow-up: `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — owns
the implementation architecture required to meet this ADR's conformance bar.
As-built: `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` describes the current
framework. It was refreshed for this decision on 2026-07-24 and must be updated again when project
009 lands.

## TL;DR

This ADR owns what "DST" is entitled to mean in this repo; it decides no implementation. Motoko's
target is **single-actor, logical-fault DST**: real session logic driven against a deterministic
model of its *logical* environment — provider, tool, approval, extension-effect, and time — with
physical faults (torn writes, partitions, consensus) and multi-actor interleaving excluded by
decision, because Motoko holds no correctness contract they would test. The seven pillars below are
adopted as a **repo-specific conformance profile, not a universal field taxonomy**: the deterministic
environment model (pillar 2) is the definitional center that practitioners agree on, while a
seed-driven schedule, injected faults, and virtual time (pillars 3–5) are required *here* as local
policy, because they are what the agent-loop failure surface needs and what the seeded axis lacks.

At HEAD the seeded axis is **property-based testing, not DST**: it meets pillar 1, exercises
pillar-6-style properties, holds half of 7, and integrates none of 2-logical, 3, 4, or 5. Until the
full D2 bar is met — proven by automated behavioral evidence, not by the presence of types or
constructors — the words "DST" and "simulation" are not used for the seeded axis in new
identifiers, docs, or PR descriptions; the interim name is **"deterministic trajectory testing"**,
existing `dst` identifiers are grandfathered, and **"Soft DST"** is correct at no point. Reaching
the bar is not a small `ScriptedStep` change: `ScriptedStep` is a success-only record, approvals,
native tools, and session time bypass the ports boundary, and the message-returning entrypoint is
not a trace oracle. That work is delegated to
`../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`. This document has
been through an independent review and a re-review; both sets of findings are preserved below as the
audit record.

## Context

`../001_DST/ADR-001` named the method "Deterministic Simulation Testing" and built the layered
scenario-and-invariant system that now exists (L0 policy invariants, L1 loop-state scenarios, L2
harness boundary, L3 event parity, the typed `LedgerTrace` oracle, ABI-lockstep conformance).
PRs #99 and #100 added a seeded axis: a PRNG-seeded generator draws input parameters and drives
production transition code (`scripts/dst/compaction_seeded_dst.ail`,
`scripts/dst/phase_c_seeded_dst.ail`).

The branch name (`mot-43-l1-seeded-families`) and the make target (`dst_seeded`) carry the "DST"
label — whose middle word is *Simulation*. A review of what actually landed at HEAD found the
label is being applied to something that does not yet meet the shared core practitioners agree on
(see *DST in field practice* below) — and, more
importantly, that **DST as the canonical artifact practises it cannot be met by an agent harness
as-written, and should not be the target.** The physical-environment simulation that DST-the-artifact
(FoundationDB, TigerBeetle, Antithesis) is built around is overkill here; but "therefore drop the
simulated environment" is the wrong conclusion. The environment relocates rather than disappears.

Nobody has written down what "DST" is *entitled to mean* in this repo. The result is that HEAD —
which is honest, strong property-based testing — wears a label that promises capabilities it does
not have, and the one architectural move that would earn the label has no formal target. This ADR
fixes the definition, the taxonomy, the scope boundary, and the naming rule.

Grounded at `a7932c68b53ba0aa2ef42739e4dbe69296f37a8a` (branch
`arniwesth/mot-43-l1-seeded-families`):
- `scripts/dst/phase_c_seeded_dst.ail` — four seeded families; seed draws scalar params.
- `Scripted([ScriptedStep])` reaches the real driver: `src/core/session.ail:684,696`,
  `src/core/agent_loop_v2.ail:102-104,120-122`.
- No test scheduler, interleaving controller, injected-fault mechanism, or virtual clock exists in
  the seeded axis. A vocabulary grep does find production comments about scheduling and crashes,
  but no test-injected scheduler/fault/clock implementation. The seeded path has no clock dimension;
  elsewhere the framework normalizes clock-derived fields rather than virtualizing them
  (`../001_DST/ADR-001`).

## DST in field practice and Motoko's conformance profile

DST practice does not have one universally binding seven-item standard. FoundationDB, TigerBeetle,
Antithesis, and Resonate emphasize different system boundaries, but share a core:

> Run real system logic against a controlled deterministic model of its environment; explore
> counterfactual executions; check invariants over the execution; and preserve failures for exact
> replay.

Environment control is the definitional center. Scheduling, fault injection, and virtual time are
the principal ways distributed and fault-tolerant systems make that environment adversarial, but
not every practitioner requires every one before using the term. Motoko deliberately adopts the
following seven pillars as a **repo-specific conformance profile**. Pillars 3, 4, and 5 are required
here because they are the capabilities the existing seeded axis lacks and the agent-loop failure
surface needs—not because they are a universal field taxonomy.

| # | Pillar | What it requires |
|---|--------|------------------|
| 1 | **Hermetic determinism** | All execution-relevant nondeterminism is controlled; touching an unmodeled real-world effect fails or is detected |
| 2 | **Simulated environment** | A *model of the world* the system runs against, including its adversarial behaviors |
| 3 | **Seed-driven schedule** | The seed generates the *ordering of events over time* — the execution, not the input |
| 4 | **Fault injection** | Seed-timed faults the environment can actually produce |
| 5 | **Time as a controlled dimension** | The clock is advanced by the simulator, not merely normalized out of asserted traces — timeout/retry races are reachable |
| 6 | **Invariant oracle** | Safety + liveness checked over the whole history (shared with PBT) |
| 7 | **Search economics + reproduction** | Many seeds, red seed = bug, deterministic replay, ideally shrinking |

“A seed controls an execution rather than only an input value” is Motoko's practical naming test,
not a universal discriminator: state-machine PBT can also generate command sequences. For this
repo, the distinction is whether those generated commands drive a controlled environment—including
fault placement and time—around the real session driver.

- **Trace replay** pins *recorded* outputs and asserts equality — historical inputs, one path,
  change-detector oracle.
- **Property-based testing (PBT)** generates counterfactual values or command sequences and asserts
  invariants. It can explore state machines, but Motoko's current seeded families retain authored
  environment/control flow.
- **DST** generates *executions* — schedules of events, faults, and time — and asserts invariants
  over the resulting history in a deterministic environment model.

## Decision

### D1. Motoko's target method is **single-actor, logical-fault DST**

We adopt a scoped variant of DST as the target, defined by three deliberate boundary choices, not
by omission:

1. **Single-actor.** The agent loop is one sequential logical thread of control. There is no
   concurrency to interleave *between actors*. Pillar 3 therefore takes its **linear** form: the
   seed generates a *temporal sequence of environment responses over one trajectory* (step 1 tool
   call, step 2 tool timeout, step 3 retry, step 4 approval denied), not an interleaving lattice.
   This is still a generated *schedule* and, under this repo's D2 meaning, still legitimately
   *simulation* — it is simply a line, not a lattice. That makes it cheaper than an interleaving
   lattice; it does not make it cheap in absolute terms (see *The bar that earns the term*).

2. **Logical faults, not physical.** The environment Motoko runs against is the provider, tool,
   approval, extension-effect, and time-facing logical boundary—not disk sectors or network
   transport. Pillar 2 does not disappear; it *relocates* to that protocol/effect surface. The
   faults worth injecting (pillar 4) are the ones that cause real agent bugs and can be represented
   as typed outcomes, not kernel-level simulations. The list below is the motivating example set;
   the *required minimum* is fixed by 009 D3, which adds deadline-driven tool and approval classes
   and fences off raw wire-parser faults:
   - **Provider:** truncated tool call, malformed JSON args, hallucinated tool name, wrong
     `finish_reason`, duplicate `tool_call_id`, 429 / 500 mid-trajectory, stream cut mid-token,
     empty content.
   - **Tool:** a write that fails, a subprocess that hangs past budget, garbage stdout, an MCP
     server dropping mid-call.
   - **Approval:** denial or virtual-time delay while a `tool_use` is pending, testing whether the
     eventual `tool_result` remains paired correctly — a real ledger-integrity bug class.

3. **Physical-fault and multi-actor simulation are OUT OF SCOPE by decision.** Torn writes,
   block-level corruption, partitions, and peer consensus faults test a correctness contract
   Motoko does not have: no replication, no consensus, and no *physical* durability contract
   (no fsync/recovery/replication). The boundary is physical vs. logical, not durability-in-
   general. Terminal completeness is a *logical* invariant and remains in scope: every established
   run should return exactly one terminal summary in its `LedgerTrace`. HEAD does not yet provide
   that guarantee on all error paths
   (`src/core/session.ail:1525-1529,1609-1614`) and emitted summaries are not necessarily appended
   to the returned trace (`src/core/session.ail:1538-1557`). Closing that gap belongs to project
   009.

**Revisit tripwires.** Both exclusions are conditional, and a future feature can silently
invalidate them. Per `../009_motoko_dst_execution/NOTE-scope-and-sequence.md` these tripwires
belong both here and beside the execution runner.

*D1.1 (single-actor)* was verified at HEAD rather than assumed: tool entries are dispatched
recursively in list order (`src/core/tool_phase.ail:314-357`), native batches are sequential
(`src/core/tool_runtime.ail:155-160`), and the TUI awaits delegated calls one at a time in a
`for`-loop rather than `Promise.all` (`src/tui/src/runtime-process.ts:628-634`). Provider
streaming, MCP subprocesses, and the compose subagent are separate execution machinery that block
or serialize at the loop boundary; none was found to interleave ledger-mutating actors. **Reopen
before landing any feature that can concurrently mutate or influence a single session ledger**,
including: parallel native or delegated tool execution; ledger-sharing subagents; background
extension callbacks whose result can race the main loop; or streaming callbacks that can
independently advance session state.

*D1.3 (physical faults)* also holds at HEAD: no fsync, WAL, or ledger-recovery path was found, and
`restart` emits `SessionSuspend` then exits without restoring history
(`src/core/session.ail:2209-2216`). **Reopen before adding a crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness contract.**

### D2. The seven-pillar checklist is the conformance definition

Motoko is entitled to the unqualified word **"DST" / "simulation"** in code, CI target names, PR
descriptions, and docs only when it meets, at the logical-fault / single-actor level:

- Pillar 1 (hermetic determinism) — **met**.
- Pillar 2-logical (one deterministic model of provider/tool/approval/extension/time outcomes,
  including the fault catalogue) — **required** (D4).
- Pillar 3 (seed generates the trajectory of environment events) — **required**.
- Pillar 4 (seed injects logical faults; the normative minimum catalogue is
  `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D3, which D1.2
  motivates but does not fix) — **required**.
- Pillar 5 (a virtual clock advanced by the world and observed by production time-bearing behavior;
  timeouts reachable) — **required**.
- Pillar 6 (invariants over the resulting `LedgerTrace`) — **required**.
- Pillar 7 (reproduction contract: seed + generator/schema versions + exact execution program) —
  **required**.
- Pillar 2-physical, pillar 3-concurrent — **explicitly not required** (D1.3).

All required logical pillars must hold together. In particular, until pillars 3/4/5 are met, the
method is **not** DST regardless of how much other machinery exists.

The gate is enforceable only with automated evidence:

1. A recorded seed produces a typed program containing multiple ordered external instructions
   whose kinds and order were generator choices, **and those instructions are consumed by the real
   session driver as responses to external requests production code issued** — with a later
   instruction's kind able to depend on an earlier production request. Generating an ordered,
   generator-chosen list is not sufficient on its own: a list consumed by a pure projection
   (`phase_c.gen.stage_records`, `scripts/dst/phase_c_seeded_dst.ail:388-398,465-470`) satisfies the
   first half and fails this criterion.
2. Required provider/tool/approval fault classes reach named production recovery branches.
3. At least one pair of programs differing in virtual-clock advancement produces the expected
   different timeout/retry/deadline behavior.
4. The real traced session driver returns exactly one terminal record for every enumerated terminal
   path and runs invariants over that returned trace.
5. The exact serialized program replays to the same normalized terminal trace without invoking the
   generator.
6. A hermeticity probe proves execution-relevant effects cannot silently bypass the controlled
   world.

Project 009's architecture ADR specifies the required evidence in detail. A future reviewer applies
this test to behavior, not to the presence of types or constructors.

### D3. HEAD is not DST; name it honestly until D2 is met

At HEAD the seeded axis meets pillar 1, exercises pillar-6-style properties, has half of 7 (repro
substrate without the schema-version key), and satisfies **none of 2-logical, 3, 4, 5** despite
partial port/clock scaffolding elsewhere in HEAD. The honest label for the seeded axis is
**"seeded deterministic scenario + parameter-generation testing"** — property-based testing over
agent-loop state. It is *strictly stronger than trace replay* (you cannot replay a trace never
recorded; the inputs here were never observed) and *strictly weaker than DST*.

Rule adopted: **the word "simulation" is not used for the seeded axis in new docs, target names,
or PR descriptions until D2 is met.** The interim honest qualifier, if one is wanted, is
**"deterministic trajectory testing"** while project 009 is under construction. **"Logical-fault
DST"** is available only after the complete D2 bar is met—never merely when fault-shaped variants
land, and never **"Soft DST"** (see Rejected Alternatives).

All existing historical identifiers containing `dst` are grandfathered: make targets (including
`dst` and `dst_seeded`), script/module names, scenario PASS labels, workflow text, and the as-built
document title. The exception prevents churn; it does not confer the new meaning on the seeded
axis. New identifiers follow this rule; the as-built document was updated to state the distinction
on 2026-07-24.

### D4. The environment is formally the logical execution-world boundary

Motoko's simulated environment is the set of execution-relevant observations at the provider,
tool, approval, environment, runtime-randomness, extension-effect, and clock boundaries. Production
and deterministic tests must drive the same session logic through one authoritative boundary. The
environment model contains successful outcomes, logical faults, and monotonic virtual time.

The existing `Ports`, `ScriptedPortsState`, `StepProvider`, and traced session entry point are
partial substrate, not the completed model. Project 009 decides how they become one deterministic
test world. In particular, `ScriptedStep` is currently a successful-result record, native tools,
approval input, and session time can bypass its ports, and the message-only scripted entry point is
not a `LedgerTrace` oracle. This is why the physical-fault exclusion (D1.3) reduces the modeled
world without eliminating it, and why a `ScriptedStep`-only change is insufficient.

## The bar that earns the term (the mot-44 target)

D2 is met by an integrated capability, not one enum extension:

> A seed produces a versioned **execution program** containing ordered provider, tool, approval,
> environment, runtime-randomness, extension-effect, fault, and clock instructions. One
> deterministic test world supplies those outcomes to the real traced session driver. Every
> terminal path is present in the returned `LedgerTrace`; invariants run over that trace; and the
> exact program replays without regeneration.

`../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` owns the design for
that boundary and program. Project 007 does not implement it: the consolidation tracks were
behavior-preserving, whereas this work changes effect routing and the terminal trace contract.
The current seams reduce migration cost, but the work spans the session, tool runtime, approvals,
extensions, clock, trace, generator, and replay layers and must not be estimated as a small
`ScriptedStep` diff.

## HEAD scorecard (at `a7932c68b53ba0aa2ef42739e4dbe69296f37a8a`)

| Pillar | Status at HEAD | Evidence |
|--------|----------------|----------|
| 1 Hermetic determinism | **Met for the current seeded executions** — the gate is reproducible under `--caps IO,Env,Rand`; the capability set alone is not a proof that every permitted IO/Env observation is modeled | gate replay + caps |
| 2 Simulated environment (logical) | **Absent on the seeded axis; partial substrate at HEAD** — `Ports`/`ScriptedPortsState` exist, but generated scalars do not drive an integrated provider/tool/approval/time world | `phase_c_seeded_dst.ail`; `src/core/ports.ail`; `src/core/test/scripted_ports.ail` |
| 3 Seed-driven schedule | **Absent** — seed draws input params; `checkpoint_pressure`'s checkpoint-taking path is a *fixed authored* `decide → apply_checkpoint → decide` sequence. `stage_records` generates a list used by a pure projection, not a session environment schedule | seeded family bodies |
| 4 Fault injection | **Absent** — no seed-timed crash/denial/truncation | no injection mechanism in the seeded families |
| 5 Virtual time | **Absent — normalized away, not virtualized** (the inversion of DST) | no clock dimension in seeded path |
| 6 Invariant oracle | **Met for current PBT, incomplete for D2** — one-sided properties and `checkpoint_pressure` liveness exist, but generated families do not yet assert over a complete returned session trace | property discipline held; project-009 trace gate |
| 7 Search economics + repro | **Half** — RNG canary and base seed reproduce current draws; default `DST_SEEDS=5 DST_BASE_SEED=1` yields 25 cases (5 families × 5 seeds), and scheduled CI rotates 500 seeds, but no exact-program replay, shrink, or schema-version key exists | Makefile; `.github/workflows/verify-extensions.yml` |

**Verdict:** pillar 1 is met for the current seeded executions; pillar 6 is useful but incomplete
against the full D2 trace contract; pillar 7 has seed/search substrate; and 2-logical/3/4/5 are not
integrated on the seeded axis. HEAD is PBT, not DST.

## Consequences

Positive:
- The word "DST" acquires a checkable meaning in this repo (D2), so future PRs can be held to it
  instead of to a vibe.
- The physical-fault exclusion (D1.3) is now a *recorded decision* with a rationale, not an
  apparent gap a future reviewer re-opens.
- The mot-44 outcome is defined concretely while its cross-cutting architecture is delegated to a
  project whose scope permits behavior changes.
- The relocation of the environment to the logical protocol/effect boundary (D4) avoids an
  irrelevant physical network/storage simulator.

Negative / costs:
- New docs and target names must drop "simulation" from the seeded axis until D2 is met (D3);
  this is a naming discipline the team must actually keep.
- The existing `Ports` boundary must become authoritative across session, tools, approvals,
  extensions, and time; this is a broader migration than the existing scripted-provider seam.
- Virtual time re-introduces a controlled clock the seeded path never modeled.
- **The terminal trace and replay-program schemas become maintained compatibility surfaces.** There
  are three of them, with different consumers and different failure modes. This is the cost most
  easily underestimated, because none of it exists yet and all of it accretes once it does:
  - *The ledger event vocabulary and its wire projection.* `LedgerEvent` already carries 34
    variants (`src/core/phase_vocab.ail:597-631`), each mapped to a wire name — but the mapping
    lives in a trailing comment (`-- [prod] run_summary`), not in a type, and the consumer is a
    TypeScript `switch` in a separate process (`src/tui/src/index.ts:428`). D2's trace oracle makes
    that mapping load-bearing in both directions: adding an event becomes a change to an invariant
    surface *and* to a cross-language wire contract, and the two can no longer drift silently. The
    typed termination reasons that replace today's `finish_code: int` helper
    (`src/core/session.ail:835,857`) become a versioned enumeration the TUI depends on — the TUI
    already treats a missing `run_summary` as a crash signal, so terminal-path changes are
    observable outside the harness.
  - *The execution-program schema.* Promoted regression programs are committed artifacts, so the
    corpus grows monotonically and its oldest member sets the compatibility floor. Silently
    reinterpreting an old program is forbidden: a migration must either preserve decoding or pin a
    runner. Payloads addressed by digest need a retention policy, because a digest whose bytes are
    gone is not a replay. Programs also carry environment maps, so secret-shaped values must be
    rejected or redacted *before* persistence.
  - *The profile and manifest.* A profile version denotes semantic scope; a manifest denotes the
    build that realized it. Changing what a profile covers requires a version bump, so a coverage
    claim made in one release stays interpretable in the next.

  Versioning is therefore not one number but four independent axes — program schema, generator
  version, profile version, and execution manifest — and pillar 7 makes carrying all four part of
  the reproduction contract rather than optional metadata. The encoding, migration mechanism, and
  compatibility policy belong to
  `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` (D5, D8, D11).
  What this ADR records is that adopting the name commits the repo to maintaining them
  indefinitely, and that the commitment starts at the first promoted counterexample, not at the
  first schema change. This cost is **accepted here, not minimized** — reducing it is deliberately
  left as later work, tracked in *Open Questions* below.

## Rejected Alternatives

### "Soft DST" as the name
Rejected. "Soft" names a *rigor* reduction, but what Motoko gives up is **scope** (multi-actor
concurrency, physical fault layer), not rigor — its hermeticity is effect-enforced rather than
convention-enforced, subject to the limits the pillar-1 scorecard row records about what the
granted capability set actually proves. Naming a scope reduction as a rigor reduction misdescribes
the artifact. The scope reduction is named directly: **single-actor, logical-fault** (D1). Per D3,
the interim name while project 009 is under construction is **"deterministic trajectory testing"**;
**"logical-fault DST"** becomes available only once the complete D2 bar is met. "Soft DST" is
correct at no point.

### Calling HEAD "DST" / "simulation" now
Rejected (D3). HEAD meets none of pillars 3/4/5. Using the term now spends the credibility the
term needs when the real capability lands, and misleads a reader of *this* repo — who is entitled
to rely on the published D2 meaning — into thinking event-ordering/fault coverage exists behind a
CI name or PR title.

### Simulating physical faults (disk/network transport)
Rejected (D1.3). Tests a correctness contract Motoko does not have. Overkill, and it would divert
effort from the logical-fault surface where real agent bugs actually live.

### Multi-actor scheduling (canonical pillar 3)
Rejected for the agent loop (D1.1). The loop is single-actor and sequential; there is nothing to
interleave. The linear-schedule form of pillar 3 is the correct and sufficient target. Revisit
only if concurrent tool execution or multi-agent orchestration becomes a first-class, ledger-
affecting concern.

### Put the execution architecture inside this ADR

Rejected. This ADR owns the meaning, scope, and naming gate. The environment boundary, effect
routing, program schema, trace completion, and replay contract are a coupled implementation
architecture and are decided in
`../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`.

### No new ADR was needed for project 007's consolidation tracks

`NOTE-dst-consolidation-scope-and-sequence.md` argued "why no new ADR" — correctly, for the three
*consolidation tracks*, which were execution of `../001_DST/ADR-001`'s existing decisions. This
ADR records a *different kind* of decision: the definition, scope boundary, and naming rule for the
term itself, prompted by the trace-replay analysis. Project 009 records another new decision: how
to build the deterministic world. Neither reopens the behavior-preserving consolidation tracks.

## Open Questions

- **Generator and program encoding.** Project 009 requires a schema version, generator version, and
  exact serialized execution program. Its implementation plan selects the encoding and storage
  path.
- **Search economics.** Scheduled CI already rotates a date-derived base across 500 seeds. Project
  009 must decide the promotion/retention policy for failures and the PR-versus-scheduled budget.
- **Shrinking.** With 3–5 scalar params per family — and one variable-length family
  (`stage_records`, 1–8 generated elements) — counterexamples arrive mid-sized today; generated
  trajectories change that. Is minimization worth building now, or explicitly deferred until
  generated trajectories make cases larger?
- **Fault-catalogue ownership.** Project 009 requires every modeled fault to map to a real production
  outcome and recovery branch; the implementation plan must choose the single source of truth.
- **Reducing the compatibility burden** (see the schema cost under *Consequences*). This ADR accepts
  four independent versioned axes — program schema, generator version, profile version, execution
  manifest — plus a wire vocabulary shared with the TUI. It does not decide whether that burden can
  be made smaller, and nothing here should be read as claiming four axes is the right number.
  Candidate directions, none evaluated: derive the event-to-wire-name mapping from the type rather
  than a trailing comment, so drift becomes a compile error instead of a runtime surprise; collapse
  axes where one already implies another; adopt a retention or expiry policy for aged programs so
  the compatibility floor stops rising monotonically; or pin runners for old programs instead of
  migrating them forward. **This is future work, not an acceptance blocker** — the cost is real
  whether or not it is optimized, and the name can be earned while carrying it. It is recorded so a
  later reader does not mistake the burden for a decision that was examined and found minimal.

## Notes for a reviewer

Two reviews are preserved below as the audit record. `## Review Comments` (`R1`–`R12`) was performed
against the pre-revision draft; `## Re-Review Comments` (`RR1`–`RR10`) audited whether the revision
discharged those findings and examined the text the revision added. Both are closed: `R1`–`R12` are
dispositioned in the table above, and `RR1`–`RR10` were applied to the body on 2026-07-26. Neither
section describes outstanding work.

## Review Disposition

_Dispositioned 2026-07-24 by the authoring session, against the revised body. **No finding was
rejected**; R1, R2 and R11 were independently re-verified against source before disposition._

Codes: **Accepted** — absorbed into this ADR. **Delegated** — valid, and owned by project 009.
**Partial** — the ADR-side change landed, but a named residual remains (listed below).

| # | Finding (abbreviated) | Disposition | Landing site / owner |
|---|---|---|---|
| R1 | mot-44 unreachable as a small `ScriptedStep` extension | Accepted + Delegated | D4 and "The bar that earns the term" rewritten (`ScriptedStep` named as a success-only record; ports-bypass and trace-oracle gaps stated); seam design → 009 |
| R2 | `run_summary` completeness premise false | Accepted + Delegated | D1.3 restated as a target invariant with the HEAD gap cited (`session.ail:1525-1529,1609-1614,1538-1557`); contract → 009 Track 1 |
| R3 | Taxonomy overstates repo policy as field definition | Accepted | Section retitled "DST in field practice and Motoko's conformance profile"; pillar 2 made the definitional center; 3/4/5 labelled local policy; restated in TL;DR |
| R4 | The ADR does amend the origin ADR | Partial | `Amends:` metadata added to the header; the as-built-doc half is open (folds into R7) |
| R5 | D3 authorizes the DST name before D2 allows it | Accepted (closed) | D3 revised to require the complete D2 bar; the surviving Rejected-Alternatives echo closed 2026-07-24 |
| R6 | Scorecard conflates "unused by the seeded gate" with "absent from HEAD" | Accepted | Scorecard rows 2–3 and the verdict re-scoped to the seeded axis; `stage_records` and the checkpoint-taking qualification added |
| R7 | Stale on the as-built doc and search economics | Partial | Header, pillar-7 row and the rotation Open Question re-grounded on the current workflow; **the as-built doc refresh is open** |
| R8 | D2 is a checklist, not an enforceable gate | Accepted + Delegated | D2 gained six behavioral evidence criteria and a "behavior, not constructors" rule; detailed acceptance tests → 009 |
| R9 | Naming grandfather incomplete | Partial | D3 now grandfathers all historical `dst` identifiers by class (targets, modules, PASS labels, workflow text, as-built title); the per-class inventory folds into the R7 pass |
| R10 | Caps do not prove the broad hermeticity claim | Partial | Pillar-1 row narrowed to "met for the current seeded executions"; the "stronger than canon" echo closed 2026-07-24; **the preventive rule is open** |
| R11 | The negative vocabulary claim is literally false | Accepted | Grounding bullet replaced with the reproducible narrower result (`config.ail:110` is a production comment; no test scheduler/fault/clock implementation exists) |
| R12 | Residual "deleted" formulation for pillar 5 | Accepted | Removed from the body; the word now survives only inside the quoted findings |

### Residual items

Re-partitioned 2026-07-25 after re-review (RR1, RR8). The previous heading — "Residual items
blocking acceptance" — applied one label to a list that mixed genuine blockers with follow-up work,
and in doing so made this ADR unacceptable in principle: item 3 was assigned to project 009, whose
own acceptance depends on 007's. That cycle was an artifact of the heading, not a real dependency.

**Blocking acceptance: none.**

1. ~~**Refresh `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`**~~ (R7, R4, R9) —
   **closed 2026-07-24**, verified independently 2026-07-25. Added a `Naming` header caveat and an
   "Amendment: what this framework is *not*" section; added a "The seeded axis" section (5 families,
   RNG canary, seed config, the two extension rules); added `dst_seeded` to the gate tree, the
   `*.gen.*` namespaces to the ID table, and the nightly 500-seed / PR 25-case CI split; narrowed
   the caps-as-conformance claim per R10; added 007 and 009 to the decision-history table; and
   replaced the stale "seeded generation … not yet built" deferred item with project 009's actual
   scope.
2. ~~**Add the D1.1 / D1.3 revisit tripwires to this ADR**~~ (reviewer's recommended action 5) —
   **closed 2026-07-24**, verified independently 2026-07-25. Added as the "Revisit tripwires" block
   under D1, with all four grounding anchors re-verified before citation. The runner-side half
   remains 009's, per `../009_motoko_dst_execution/NOTE-scope-and-sequence.md`.
3. ~~**Preventive hermeticity rule — forward-looking half**~~ (R10) — **discharged by 009.** The
   gate for a simulation profile is decided in
   `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D5 (narrowest
   executable capabilities, source/ABI routing audit, poison/negative probes, fail-closed profile
   validation). That is the concrete form of D2 evidence item 6. What remains there is construction,
   which is not a 007 acceptance gate.

**Tracked after acceptance** — neither blocks this decision, and neither has an upstream dependency:

4. **HEAD-facing hermeticity rule** (R10, split from item 3 per RR1). A new input-bearing `IO`/`Env`
   operation reachable from a `dst_seeded` entrypoint requires re-grounding the pillar-1 scorecard
   row. 009's D5 gate does not cover this: it applies to modules inside a simulation profile that
   does not exist yet, whereas this protects the claim the scorecard makes about the scripts running
   *today*. The natural home is the as-built document's "Adding a seeded family" guidance. Tracked
   rather than blocking because the pillar-1 row is **dated evidence about a revision** — a later
   regression falsifies that row, not D1–D4.
5. **Per-class naming inventory** (R9, RR8). D3's lead sentence grandfathers *all* existing
   historical `dst` identifiers, so no class contradicts the rule and there is nothing to resolve —
   only to enumerate. The as-built caveat currently names three classes (`dst*` targets,
   `*_dst.ail` scripts, the document title); at least four more exist (`src/core/test/dst_gen.ail`
   and `dst_harness.ail`, which match neither glob; script PASS labels; the
   `DST AILANG gates` / `DST seeded gate` workflow labels; `src/tui/src/harness-dst.test.ts`; and
   the `scripts/dst/` directory itself). Widen the caveat's glob when convenient.

**Enforcement, stated rather than implied.** Nothing in the repo mechanically enforces D3 or the
pillar-1 premise — no lint, no CI check, no PR template rejects a new `simulation`-bearing
identifier. Both are review rules kept by hand. That is an acceptable state for a definitional ADR,
but it is recorded here so no reader infers from a residual list that something automated will catch
a violation.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-07-24. Grounded against HEAD
`a36ff05832bfd0e453dbb7c4e197a1704bd4f3c1`, the four documents named in the review handoff,
current source and gates, and the primary practitioner sources linked below._

### R1. The mot-44 design is not reachable as the claimed small `ScriptedStep` extension

**Defect:** D4 and the “small diff” consequence rest on a false model of the current seam:
`ScriptedStep` is neither an enum nor a complete provider/tool/approval/time event, so adding the
listed variants cannot by itself deliver pillars 2–5 or a `LedgerTrace`.

**Grounding:** `src/core/test/stub_step.ail:34-41` defines `ScriptedStep` as a six-field record;
`scripted_to_step_result` always constructs a successful `StepResult` (`:49-67`), and
`scripted_ports_from_steps` always returns `Ok(...)` (`:157-167`). The actual environment seam is
the broader `Ports` record (`src/core/ports.ail:17-24`), but the driver reads approval directly
with `readLine()` (`src/core/session.ail:1609-1634`), native tools bypass `Ports.tool_exec` through
`dispatch_tool_entries_with_builtin`/`dispatch_one`
(`src/core/session.ail:1658-1660`; `src/core/tool_phase.ail:302-357`), and session time uses
`now()` directly (`src/core/session.ail:788,839,1990,2089`). `Ports.clock_now` and
`Ports.tool_exec` are only projected into extension ports (`src/core/session.ail:668-677`).
Finally, `Session.run_v2_from_messages` returns `Result[[Message], AIError]`, not a trace
(`src/core/session.ail:2122-2138`); the trace-returning seam is the separately named
`run_v2_session_traced` (`:1999-2015`). The source note called only generated provider steps,
finish reasons, tool-call shapes, and telemetry a “small step”
(`NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md:50-52`); the ADR added provider errors, tool and
approval faults, and virtual time without re-estimating the seam.

**Action:** Specify one state-threaded world-script ADT (or an equivalent custom `Ports`
implementation) whose events include provider `Ok`/`Err`, approval results, tool results, and
clock advances; route the production approval, native-tool, and timeout/retry consumers through
those ports; use the traced session entrypoint; then replace “small diff” with a dependency list
and re-estimate mot-44.

### R2. The `run_summary` completeness premise is false and cannot currently be asserted over `LedgerTrace`

**Defect:** D1.3 treats “`run_summary` on every termination path” as an implemented logical
durability invariant, but there are direct terminal `Err` returns without a summary,
`dp7_rejected` is not a termination reason, and emitted summaries are not appended to the returned
`LedgerTrace`.

**Grounding:** The cited `src/core/session.ail:826-829` is only a comment. Invalid history returns
directly at `:1525-1529`, and the inconsistent pending-approval state returns directly at
`:1609-1614`; neither calls `emit_run_summary`. `dp7_rejected` causes
`InjectUserMessage` and another loop iteration (`src/core/step_machine.ail:112-119`), and the
current `emit_run_summary` call sites contain no finish code `2`
(`src/core/session.ail:1322,1551,1701,1708,1761`). `emit_run_summary` sends a wire event via
`ledger_emit` (`:830-867`), while the success path returns `trace_after_empty_floor` without
appending either `RunSummary` or `DoneEvent` (`:1538-1557`). Thus the physical-durability
exclusion may still be right, but this stated supporting contract is not real.

**Action:** Either funnel every controlled return through one finalizer that both emits and
appends exactly one `RunSummary` (with a reachable finish-code table), or narrow D1.3 to the paths
actually covered and remove `dp7_rejected`; do not call it assertable over `LedgerTrace` until the
trace contains it.

### R3. The seven-pillar taxonomy overstates a repo policy as the field definition

**Defect:** “Pillars 3, 4, 5 are what make simulation simulation” and “execution, not input” as the
single PBT/DST discriminator are not faithful general characterizations of DST.

**Grounding:** FoundationDB and TigerBeetle strongly exemplify controlled scheduling, faults, and
virtual time, but practitioner definitions put the simulated deterministic environment at the
center: [Antithesis defines DST as software in a simulated deterministic
environment](https://antithesis.com/docs/resources/deterministic_simulation_testing/) and says
PBT/fuzzing and fault injection are commonly *paired* with it; [Resonate defines the core move as
substituting the environment with a
simulator](https://journal.resonatehq.io/p/deterministic-simulation-testing) and describes virtual
time as a side effect of environment virtualization. Conversely, property-based testing can
generate executions: [QuickCheck `eqc_statem` generates, runs, and shrinks command
sequences](https://quviq.com/documentation/eqc/eqc_statem.html), including parallel cases.
FoundationDB’s own description supports the importance of the environment model—machines, network,
drives, failures, and stepped time—not merely the fact that a seed chose an ordering
([FoundationDB simulation](https://apple.github.io/foundationdb/testing.html)).

**Action:** Present the seven items as **Motoko’s chosen conformance profile**, make pillar 2 the
definitional center, and replace the single-axis claim with: PBT may generate command sequences,
whereas DST runs the system inside a deterministic, controllable environment/scheduler that
mediates outcome-affecting nondeterminism. Motoko may still require 3/4/5 as its local bar, but
must label that as policy rather than canon.

### R4. This ADR does amend decisions in the origin ADR

**Defect:** The relationship metadata and Rejected Alternatives claim the origin ADR is unchanged
and uncontradicted, but this ADR replaces its explicit definition of DST and reverses its accepted
clock-normalization rule.

**Grounding:** The origin ADR says “DST will mean” the five-part scenario/fake/normalized-trace
system (`../001_DST/ADR-001-deterministic-simulation-testing-architecture.md:31-41`), calls seeded
generation an extension (`:49,123,260-272`), permits time observations to be “normalized or
explicitly controlled” (`:50`), and requires normalization until virtual-clock support is found
(`:56`). D2 here says that system is not entitled to the name until generated trajectories,
faults, and a stepped virtual clock all exist. That is a deliberate definitional amendment, not a
mere reinterpretation of a label.

**Action:** Change the relationship to `Amends`/`Supersedes` for the origin ADR’s definition,
Layer names, and clock-normalization constraint, while explicitly preserving its architecture,
scenario, trace, and invariant decisions; make the same relationship explicit in the as-built
doc.

### R5. D3 authorizes the DST name before D2 allows it

**Defect:** The interim-name sentence internally contradicts the conformance gate by allowing
“logical-fault DST” “once faults land,” even if the required generated trajectory and virtual time
have not landed.

**Grounding:** D2 says pillars 2-logical, 3, 4, 5, 6, and 7 are all required and that the method is
not DST until 3/4/5 are met (`ADR:115-128`); D3 then permits the qualified DST label as soon as
faults land (`ADR:138-140`), which establishes only pillar 4.

**Action:** Change the trigger to “once all of D2 is met”; before that point use a non-DST name
such as “seeded logical-fault scenarios.”

### R6. The HEAD scorecard conflates “not used by the seeded gate” with “absent from HEAD”

**Defect:** The “none of pillar 2-logical” and “seed draws scalar params” evidence is empirically
over-broad: HEAD already contains a partial logical environment model, and one seeded family
generates a list of stage outcomes rather than only scalars.

**Grounding:** `Ports` already models model, approval, clock, env, tool, and hook boundaries
(`src/core/ports.ail:17-24`), while `ScriptedPortsState` contains model steps, approval outcomes,
and clock values (`src/core/test/scripted_ports.ail:20-27,38-66`). The seeded scripts do not use
that environment seam at all, so the scorecard evidence “model port is a fake returning generated
scalars” (`ADR:173`) describes neither the seeded path nor the existing fake. In
`phase_c_seeded_dst`, `generated_stages` randomly chooses every `StageApplied`/`StageRejected`/
`StagePassed` element (`scripts/dst/phase_c_seeded_dst.ail:388-398`), and `run_stage_records`
generates and consumes that list (`:465-470`). This remains generated input to pure record
projection—not an environment-event schedule—so the no-pillar-3 verdict survives. The
checkpoint-taking branch is likewise author-fixed `decide → apply_checkpoint → decide`
(`:254-281`), although seeds that do not take a checkpoint never execute all three operations.

**Action:** Scope the scorecard explicitly to **the seeded axis**, rate pillar 2 as “substrate
present at HEAD, not integrated into this axis,” and say the seed generates scalar parameters plus
a stage-outcome input list, but never the driver’s environment-event ordering. Qualify the
checkpoint statement to checkpoint-taking cases.

### R7. The ADR is stale about Track 3 and search economics

**Defect:** The header, scorecard, and Open Questions describe pre-HEAD state: the as-built doc
exists and CI already rotates a large daily seed window.

**Grounding:** Exact command
`find design_docs/implemented/motoko_agent -maxdepth 2 -type f -print` returns
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`, whose status is “Implemented”
(`:1-5`), contradicting `ADR:9`. `.github/workflows/verify-extensions.yml:26-30` schedules the
workflow nightly, and `:98-104` runs `DST_SEEDS=500 DST_BASE_SEED=$(date +%Y%m%d) make
dst_seeded`; therefore “identical every run” applies only to PR/push defaults, and the question
“Should CI rotate ... nightly?” (`ADR:237-239`) is already answered. The as-built doc is itself
stale: it says seeded generation is not built (`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md:85-89`)
and omits `dst_seeded` from its gate tree (`:119-128`).

**Action:** Re-ground the header and pillar-7 row on the current workflow, close the rotation Open
Question, and make updating the existing as-built doc—both for seeded reality and the new naming
distinction—an adoption action rather than future Track-3 work.

### R8. D2 is a checklist but not yet an enforceable gate

**Defect:** A future reviewer cannot determine mechanically when pillars 2–5 are “met,” because
the ADR supplies no minimum fault coverage, observable schedule criterion, replay assertion, or
production timeout driven by the proposed clock.

**Grounding:** D2 requires a fault catalogue and stepped clock (`ADR:119-125`), but D4 reduces both
to adding illustrative variants (`ADR:146-151`), and mot-44 only says the clock is “carried in the
script” (`ADR:157-163`). Current retry behavior is count/budget based
(`src/core/session.ail:1732-1762`), approval uses blocking `readLine()` (`:1616`), and native/MCP
timeouts are real process/shell time (`src/core/tool_runtime.ail:873-923`;
`packages/motoko-ext-mcp/exec.ail:45-70`); merely carrying a clock value makes no timeout/retry
race reachable.

**Action:** Add acceptance tests to D2: the same `(commit or generator schema, seed)` must produce
an identical typed trace; different seeds must demonstrably change event kinds/order; at least one
provider, tool, and approval fault must traverse the production handler; and advancing only the
scripted clock must cross a real timeout/retry deadline. Define the minimum required catalogue
and schema-version artifact.

### R9. The naming grandfather is incomplete

**Defect:** D2 bans unqualified DST/simulation names at HEAD, but D3 grandfathers only
`dst_seeded`, leaving existing seeded script/module names, output labels, CI labels, and the
umbrella target in conflict with the rule.

**Grounding:** Exact command
`rg -n '(dst_seeded|seeded_dst|DST seeded|Seeded .*DST)' Makefile .github scripts/dst
design_docs/implemented/motoko_agent/m-motoko-dst-framework.md -g '!scripts/dst/.ailang/**'`
finds `scripts/dst/{compaction,phase_c}_seeded_dst.ail` and their module/PASS names, the workflow
label `DST seeded gate` (`.github/workflows/verify-extensions.yml:98`), and `make dst` including
`dst_seeded` (`Makefile:74-80`). The existing as-built doc also names the entire current framework
“Deterministic Simulation Testing” (`m-motoko-dst-framework.md:1-26`).

**Action:** Inventory every existing identifier and explicitly choose either grandfathering or a
rename for each class (target, file/module, output protocol, CI label, umbrella, as-built title);
state whether the origin framework’s fixed scenarios may retain historical “DST” labels after
this ADR.

### R10. Caps support current determinism but do not prove the scorecard’s broad hermeticity claim

**Defect:** Pillar 1 is true for the audited seeded scripts, but “stronger than canon” and “any
unmodeled effect fails at perform time” overstate what `--caps IO,Env,Rand` enforces.

**Grounding:** `Makefile:78-80` does use the stated caps. The only environment reads in the two
entrypoints are `DST_SEEDS` and `DST_BASE_SEED`
(`scripts/dst/compaction_seeded_dst.ail:217-230`;
`scripts/dst/phase_c_seeded_dst.ail:567-580`), and every family calls `rand_seed(seed)` before its
draws, so repeated executions are deterministic for the recorded code/configuration. But the
granted `IO` capability also admits unmodeled input such as `readLine()` and `Env` admits arbitrary
new environment reads; caps reject a new *effect class*, not an unmodeled operation within an
allowed class. The actual command `DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded` passed all five
families (four plus one) and 25 generated cases plus the fixed RNG canary.

**Action:** Keep pillar 1 “Met,” but replace the proof text with the narrower claim that caps
exclude `Clock/FS/Process/Net/AI/...` and a source audit shows the allowed `IO/Env/Rand` operations
are deterministic; add a gate or review rule that prevents new input-bearing `IO`/`Env` calls.

### R11. The negative vocabulary claim is literally false

**Defect:** The citation-audit sentence says no scheduling vocabulary exists anywhere in `.ail`,
but current source contains such a hit.

**Grounding:** Exact command
`rg -ni --glob '*.ail' '(schedul(e|ed|er|ing)|interleav(e|ed|ing)|fault[-_ ]?inject(ion|ed)?|virtual[-_ ]?clock|\bcrash(ed|es|ing)?\b|\bpartition(s|ed|ing)?\b)' src scripts`
returns `src/core/config.ail:110: -- configuration record, which has additional AI scheduling
fields.` It also returns only production/runtime-crash comments for `crash`, and no interleaving,
fault-injection, virtual-clock, or partition hit, so the intended substantive conclusion survives.

**Action:** Replace the absolute vocabulary claim with the reproducible narrower result: no
test-scheduler, injected-fault, or virtual-clock implementation exists; the lone scheduling hit
and all crash hits are production comments.

### R12. Pillar 5 still uses the unsupported “deleted” formulation

**Defect:** The ADR is not internally consistent about time: it correctly says the seeded axis
never modeled a clock and normalized clock-derived fields elsewhere, but later says mot-44
re-introduces a clock “rather than deleted.”

**Grounding:** `ADR:41` and `ADR:176,181` use “normalized away, not virtualized,” while `ADR:163`
uses “rather than deleted.” The seeded scripts have no `Clock` effect
(`scripts/dst/compaction_seeded_dst.ail:217`; `scripts/dst/phase_c_seeded_dst.ail:567`); absence
is not deletion.

**Action:** Replace the residual deletion wording with “adds a controlled clock dimension that the
seeded path did not model”; retain “normalized away, not virtualized” only for the framework paths
where clock-derived trace fields were actually normalized.

### What is accurate

The single-actor ruling holds for one Motoko session: the recursive driver serializes state
transitions, AILANG tool entries are processed recursively in list order
(`src/core/tool_phase.ail:314-357`), native batches are sequential
(`src/core/tool_runtime.ail:155-160`), and the TUI awaits delegated calls one at a time
(`src/tui/src/runtime-process.ts:618-642`). Provider streaming, MCP subprocesses, and the compose
subagent are separate execution machinery but block or serialize at the loop boundary; none was
found to interleave ledger-mutating actors. Put the revisit tripwire beside D1.1 and the
dispatcher if parallel tools or ledger-sharing subagents land. The physical-durability exclusion
also holds: no fsync/WAL/ledger-recovery path was found, and restart emits `session_suspend` then
exits without restoring history (`src/core/session.ail:2209-2216`); only the claimed
`run_summary` guarantee fails. Taxonomically, real logic + a deterministic simulated environment
+ invariant checking + reproducibility is accurate, and HEAD remains better described as
stateful PBT than DST; the seven useful dimensions should not be presented as a universally
accepted conjunctive definition. The five-family arithmetic and the authored ordering of the
checkpoint-taking branch also held.

### Recommended pre-implementation actions

1. Correct the field taxonomy and explicitly amend the origin ADR (R3–R4).
2. Replace the mot-44 sketch with the actual unified event/ports/trace/time design (R1, R8).
3. Decide and implement the real `run_summary`/`LedgerTrace` completeness contract (R2).
4. Re-ground the HEAD scorecard, current CI/as-built state, and naming inventory (R5–R7, R9–R12).
5. Add the D1.1 concurrency tripwire at the tool dispatcher/subagent boundary before parallel
   ledger-affecting execution is introduced.

## Re-Review Comments

_Re-reviewer: Claude Code (model: `claude-opus-5`), 2026-07-25. Grounded against HEAD
`a7932c68b53ba0aa2ef42739e4dbe69296f37a8a` (branch `arniwesth/mot-43-l1-seeded-families`, three
commits ahead of the first review's `a36ff05`). Every source anchor in the revised body, both
tripwire blocks, the scorecard, the six D2 evidence criteria, the R11 grep, and the `dst_seeded`
gate were re-executed against that revision. Scope: whether the revision discharged `R1`–`R12`,
and whether the text added by the revision holds. The first review's findings are treated as
settled._

**Summary.** The disposition largely holds: all twelve findings landed in the body, and the two
residual items marked closed really are closed. The revision is materially better than the draft it
replaced. What survives is (a) an ownership error in the residual list that, taken literally, makes
this ADR unacceptable forever, (b) one of the six new D2 evidence criteria that HEAD already
passes — the same "checklist, not a gate" defect R8 named, surviving in the fix for R8 — and (c)
eight smaller inconsistencies, all in text the revision added or left behind. None requires new
implementation, an upstream API, or project 009.

### RR1. Residual item 3 is mis-owned, and as written it makes both 007 and 009 permanently unacceptable

**Defect:** Item 3 is filed under *Residual items **blocking acceptance*** and assigned to project
009, whose own acceptance is blocked on 007's acceptance and on an unlanded upstream AILANG API —
a cycle with a third-party blocker on it; and the half of R10's residual that is genuinely 007's
(a rule protecting *today's* pillar-1 claim) is discharged in neither ADR nor in the as-built doc.

**Grounding:**
- `ADR:390-391` — item 3, under the heading `### Residual items blocking acceptance` (`ADR:377`):
  "**Owned by 009** — it is the concrete form of D2 evidence item 6."
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md:10-11` —
  "Depends on: … after review disposition **and acceptance**"; same in
  `../009_motoko_dst_execution/NOTE-scope-and-sequence.md:31-33`.
- `009/ADR-001:4-5` — 009's own status: "upstream recorded-stream API and independent review
  required" before acceptance.
- 009 *does* decide the forward-looking gate: `009/ADR-001:490-499` (narrowest capabilities, source/
  ABI routing audit, poison/negative probes, fail-closed profile validation). That is the D2-item-6
  gate, and it is genuinely accepted there — so the *design* half of item 3 is already discharged.
- What is **not** discharged anywhere is R10's actual ask, which was about the seeded scripts that
  run today: "add a gate or review rule that prevents new input-bearing `IO`/`Env` calls"
  (`ADR:608-609`), guarding the scorecard row that reads "Met for the current seeded executions"
  (`ADR:262`). 009's D5 gate applies only to modules inside a simulation profile that does not
  exist yet. The as-built doc's authoring guidance — the one place a repo rule would bite — adds no
  such rule: `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md:252-262` ("Adding a
  seeded family" / "Adding a whole new gate script") requires narrowest caps and invariant-only
  assertions, and says nothing about input-bearing `IO`/`Env`.

**Action:** Split item 3 and re-partition the section into *blocking* and *tracked after
acceptance*. Forward half: mark discharged, citing `009/ADR-001` D5 — it is not a 007 blocker. HEAD
half: restate as a 007-owned **tracked** item (one sentence in D3 or in the as-built doc's "Adding a
seeded family" guidance: a new `IO`/`Env` operation that can carry input into a `dst_seeded`
entrypoint requires re-grounding the pillar-1 scorecard row). Note explicitly that the pillar-1 row
is dated evidence about a revision, so a later regression falsifies the row, not the decision — which
is why it is tracked and not blocking. See the deadlock ruling below.

### RR2. D2 evidence criterion 1 is already satisfied by HEAD's `stage_records` family

**Defect:** Criterion 1 requires "a typed program containing multiple ordered external instructions
whose kinds and order were generator choices" (`ADR:191-192`) but never requires those instructions
to be *delivered to production code at an effect boundary in response to a request production code
made* — so the exact artifact this ADR rules is not DST passes the first criterion of the gate that
is supposed to exclude it.

**Grounding:** `scripts/dst/phase_c_seeded_dst.ail:388-398` — `generated_stages` draws
`rand_int(0, 2)` per element and chooses the *kind* (`StageApplied` / `StageRejected` /
`StagePassed`) and the *order* of a list of `PreStepStage`; `:465-470` — `run_stage_records` seeds
the RNG, draws the length (`rand_int(1, 8)`), and generates that list. `PreStepStage` is a
production type, not a test type: `src/core/session.ail:55-56` imports it and
`src/core/session.ail:300` consumes `[PreStepStage]` in `emit_pre_step_stages`. So "recorded seed →
typed, multiply-ordered, generator-chosen instruction list" is literally true at HEAD. The gate
holds only because criteria 2–6 are conjunctive and HEAD fails all five; criterion 1 alone, applied
mechanically by a future reviewer, returns PASS. Criterion 1 is the criterion that is supposed to
carry pillar 3, and pillar 3 is the pillar the scorecard uses to reject HEAD (`ADR:264`).

**Action:** Add the missing clause to criterion 1 — the ordered instructions must be *consumed by
the real session driver as responses to external requests production code issued*, and a later
instruction's kind must be able to depend on an earlier production request. A one-line negative
example makes it self-checking: "a generated list consumed by a pure projection
(`phase_c.gen.stage_records`) does not satisfy this criterion."

### RR3. D2 pillar 4 points a reviewer at the wrong fault catalogue

**Defect:** D2 makes the D1.2 list normative ("Pillar 4 (seed injects logical faults from the D1.2
catalogue) — required", `ADR:179`), but the required minimum actually lives in 009 and is a
different set, so a reviewer applying D2 literally checks a list that is neither necessary nor
sufficient.

**Grounding:** `ADR:130-137` (D1.2) reads as illustration — "The faults worth injecting … are the
ones that cause real agent bugs" — and lists hallucinated tool name, duplicate `tool_call_id`,
429/500 mid-trajectory, stream cut mid-token, MCP server dropping mid-call.
`009/ADR-001:357-364` states "The minimum catalogue required before adopting the DST name is:" and
requires two classes D1.2 never mentions — tool "completion after its declared deadline" and
approval "no response before a declared approval deadline". It also fences off one D1.2 item:
`009/ADR-001:378-380` rules that a malformed raw HTTP/SSE payload exercises a provider adapter
parser, not the session, unless that adapter is inside the profile — which is what D1.2's "stream
cut mid-token" describes.

**Action:** Change `ADR:179` to name `009/ADR-001` D3 as the normative minimum and relabel D1.2 as
the motivating example set ("illustrative; the required minimum is fixed by 009 D3"). One line each.

### RR4. The Context section still asserts the single canonical definition R3 removed

**Defect:** R3's fix landed in the taxonomy section and the TL;DR but not in Context, which still
speaks of *the* established/canonical definition — contradicting the section the revision wrote to
replace it.

**Grounding:** `ADR:50-54` — "the label is being applied to something that does not yet meet **the
established engineering definition of DST** — and, more importantly, that **the canonical definition
of DST** cannot be met by an agent harness as-written". Against `ADR:75` — "DST practice does not
have one universally binding seven-item standard" — and `ADR:84` — "not every practitioner requires
every one before using the term". The same residue reaches the naming rationale: the Rejected
Alternative at `ADR:306-309` justifies withholding the name partly because using it "misleads anyone
reading CI names or PR titles into thinking event-ordering/fault coverage exists", which is an
external-audience claim the revision just withdrew.

Note this does **not** undercut D2's authority to withhold the name, and I do not read the R3 fix as
an under-claim: D2 governs what the word is entitled to mean *in this repo* (`ADR:172-173`), and
repo policy can bind repo naming without asserting canon. The defect is that two passages still
argue from canon instead of from policy.

**Action:** At `ADR:50-54` replace "the established engineering definition" with "the shared core
practitioners agree on (see below)" and drop "canonical" or scope it to the FoundationDB/TigerBeetle
artifact. At `ADR:306-309` re-ground the rationale on the local footing: a reader of *this* repo is
entitled to rely on this repo's published D2 meaning.

### RR5. D1.1's "which is why it is cheap" contradicts the mot-44 cost re-estimate R1 forced

**Defect:** The single-actor decision closes with an unqualified cost claim that a future reader can
quote to re-estimate mot-44 as small — the exact escalation R1 removed everywhere else.

**Grounding:** `ADR:122-124` — "This is still a generated *schedule* and still legitimately
*simulation* — it is simply a line, not a lattice, which is why it is cheap." Against `ADR:254-256`
— the work "spans the session, tool runtime, approvals, extensions, clock, trace, generator, and
replay layers and must not be estimated as a small `ScriptedStep` diff" — and `ADR:33-35`. The
source note's "small step" framing (`NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md:50-52`) is
otherwise correctly confined to the quoted findings. "Still legitimately *simulation*" also reads as
canon rather than policy (see RR4).

**Action:** Qualify to the comparison actually being made: "cheaper than an interleaving lattice —
not cheap in absolute terms; see *The bar that earns the term*."

### RR6. D2 pillar 5 still specifies the formulation 009 explicitly rejects as insufficient

**Defect:** Pillar 5's D2 bullet describes the bar as a clock "carried in the script" — the phrasing
R8 attacked as making no race reachable — while the downstream ADR that owns the implementation
rules that exact thing out.

**Grounding:** `ADR:180` — "Pillar 5 (a stepped virtual clock **carried in the script**; timeouts
reachable) — **required**." R8's grounding named this phrase (`ADR:559-561`).
`009/ADR-001:424-425` — "If no production behavior observes time, merely carrying unused clock
interactions does not meet the gate." D2 evidence criterion 3 (`ADR:194-195`) does carry the real
force, so this is wording, not a hole — but the bullet is what a reviewer reads first.

**Action:** Replace "carried in the script" with "advanced by the world and observed by production
time-bearing behavior", leaving the "timeouts reachable" clause.

*(Pass-4 note: 007's pillar 5 is consistent with the streaming spike. Pillar 5 requires the
simulator to **advance** the clock (`ADR:95`), never to observe arrival times, so the spike's
finding — the provider chunk callback's closed `{IO}` row rejects `Clock`, `spike/README.md:170-183`
— is not a gap against it. No change needed.)*

### RR7. The header and D3 describe the as-built refresh as pending; residual item 1 records it as done

**Defect:** Two places in the body state a future obligation that the disposition says was
discharged on 2026-07-24, and that I verified is discharged.

**Grounding:** `ADR:12-13` — "must be updated when this decision is accepted and again when project
009 lands"; `ADR:224-225` — "the existing as-built document must state the distinction when this ADR
is accepted". Against `ADR:379-385` (item 1, struck through, closed) and the artifact:
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md:3-8` (the refreshed-status line and the `Naming` caveat), `:36-52`
("Amendment: what this framework is *not*"), `:130-147` ("The seeded axis", five families + canary),
`:202` (`dst_seeded` in the gate tree), `:210-215` (nightly 500 / PR 25 split), `:66-70` (the
narrowed caps-as-conformance claim), `:285-286` (007 and 009 in the decision-history table). The
stale "seeded generation … not yet built" text R7 cited at `:85-89` is gone.

**Action:** Change both to past tense with the date ("refreshed 2026-07-24"), and keep only the
forward obligation ("and again when project 009 lands").

### RR8. Residual item 4 says it "folded into item 1", but item 1's caveat covers three of at least seven identifier classes

**Defect:** Item 1 is closed while item 4 is open and claims to live inside item 1; and the naming
caveat item 1 delivered uses a glob that misses two existing `dst` modules.

**Grounding:** `ADR:392-393` — item 4, "folded into item 1", while item 1 (`ADR:379`) is struck
through as closed. The delivered caveat, `m-motoko-dst-framework.md:5-8`, grandfathers "this
document's title, … every `dst*` make target, and … every `*_dst.ail` script name" — three classes.
D3 itself names five (`ADR:221-223`), and the repo has more:

```
$ ls src/core/test/ | grep dst
dst_gen.ail
dst_harness.ail
```

Neither matches `*_dst.ail`. Also outside the caveat: the PASS/scenario labels emitted by the
scripts (`phase_c_seeded_dst PASS families=…`, `scripts/dst/phase_c_seeded_dst.ail:559`), the
workflow step labels `DST AILANG gates` / `DST seeded gate`
(`.github/workflows/verify-extensions.yml:95,98`), `src/tui/src/harness-dst.test.ts`, the published
copy `.packages/motoko_core/src/core/test/dst_harness.ail`, and the `scripts/dst/` directory itself.

This is **not** a live contradiction with D3: D3's lead sentence is a blanket — "All existing
historical identifiers containing `dst` are grandfathered" (`ADR:221`) — and the list that follows
is illustrative, so every class above is covered. The defect is only the bookkeeping.

**Action:** Either mark item 4 closed by the blanket clause and delete "folded into item 1", or keep
it open as *tracked* with item 1's cross-reference removed. If the as-built caveat is meant to be
the inventory, widen its glob to `dst*.ail` / `*_dst.ail` and add PASS labels, workflow labels, and
the TS harness test.

### RR9. The scorecard and Context are grounded to a moving branch, not a revision

**Defect:** The dated empirical evidence in this ADR is keyed to a branch name, so a later reader
cannot tell which tree it described — and the branch has already moved three commits since the
review.

**Grounding:** `ADR:63` ("Grounded against HEAD (branch `arniwesth/mot-43-l1-seeded-families`)") and
`ADR:258` (scorecard heading, same). The review section pins a commit (`ADR:400-401`, `a36ff05`) and
so does 009 (`009/ADR-001:5`, `7b9b4a4c`); this ADR's own body does not. `git rev-parse HEAD` now
returns `a7932c68b53ba0aa2ef42739e4dbe69296f37a8a`. I re-verified every body anchor at that
revision and all still hold, so nothing is currently wrong — the claim is simply unpinnable.

**Action:** Add the grounding commit to `ADR:63` and to the scorecard heading, as 009 does.

### RR10. "4–5 drawn params per family" is wrong, and it is the premise of the shrinking Open Question

**Defect:** The shrinking question reasons from a draw count that does not match the families, and
misses the one family whose counterexample size is seed-dependent — which is the case that most
affects the answer.

**Grounding:** `ADR:343-344` — "With 4–5 drawn params per family, counterexamples arrive mid-sized."
Actual draws: `compaction.gen.tool_heavy` 3 (`scripts/dst/compaction_seeded_dst.ail:159-161`),
`seal_boundary` 5 (`phase_c_seeded_dst.ail:170-175`), `checkpoint_pressure` 4 (`:292-295`),
`split_prefix` 3 (`:346-348`), `stage_records` 2 + up to 8 (`:467-469` → `generated_stages`,
`:388-398`). Range is 3–10, variable-length in one family.

**Action:** "With 3–5 scalar params per family — and one variable-length family (`stage_records`,
1–8 generated elements) — counterexamples arrive mid-sized today; generated trajectories change
that."

---

## 1. Disposition audit table

Grades are against the **body**, at HEAD `a7932c6`. Every claimed landing site was opened and every
cited anchor re-executed.

| # | Claimed disposition | Grade | Justification |
|---|---|---|---|
| R1 | Accepted + Delegated | **LANDED** | D4 (`ADR:236-239`) names `ScriptedStep` a success-only record and states the approval/native-tool/session-time ports bypass and the message-only-entrypoint gap; the mot-44 section (`ADR:241-256`) ends "must not be estimated as a small `ScriptedStep` diff". 009 accepts the seam design in D1 and rejects the `ScriptedStep`-extension alternative (`009:720-725`). Residue: `ADR:124` "cheap" (RR5). |
| R2 | Accepted + Delegated | **LANDED** | D1.3 restated as a target invariant with the real gap (`ADR:143-148`); all three anchors verified exactly — `session.ail:1525-1529` (`InvalidHistory` direct return), `:1609-1614` (pending-approval direct return), `:1538-1557` (`emit_run_summary` at `:1551` emitted but not appended; returns `trace_after_empty_floor`). `dp7_rejected` and the `run_summary` guarantee are gone from the body. 009 D6 accepts the contract, including derivation of terminal reasons from reachable returns (`009:537-549`). |
| R3 | Accepted | **LANDED** | Section retitled and rewritten (`ADR:73-110`): shared core quoted, pillar 2 named the definitional center, 3/4/5 explicitly "required *here* as local policy", single-axis discriminator demoted to "Motoko's practical naming test, not a universal discriminator" (`ADR:99-102`), restated in TL;DR (`ADR:21-25`). Does **not** under-claim: D2 binds repo usage (`ADR:172-173`), which policy can do. Residue in Context (RR4). |
| R4 | Partial (as-built half open) | **LANDED — residual discharged** | `Amends:` in the header (`ADR:7-9`); the as-built half, folded into residual item 1, is delivered at `m-motoko-dst-framework.md:36-42`. Nuance worth recording: the origin ADR's clock rule was conditional — "must normalize … **until** a local deterministic clock control is identified" (`001_DST/ADR-001:56`) — and `ailang run -virtual-time` exists in the pinned v0.26.0, so 007 satisfies the escape condition rather than reversing the rule. The header's narrower "definition and naming threshold" is therefore the more accurate wording of the two. |
| R5 | Accepted (closed) | **LANDED** | D3 requires the complete bar (`ADR:217-219`: "only after the complete D2 bar is met—never merely when fault-shaped variants land"); the Rejected-Alternatives echo now matches (`ADR:301-304`). No "once faults land" trigger survives. |
| R6 | Accepted | **LANDED** | Row 2 re-scoped to "Absent on the seeded axis; partial substrate at HEAD" (`ADR:263`); row 3 adds the `stage_records` list and the checkpoint-taking qualification (`ADR:264`); verdict re-scoped (`ADR:270-272`). Verified: `Ports` at `src/core/ports.ail:17-24` (six boundaries), `ScriptedPortsState` with `model_steps`/`approvals`/`clock_values` and a `scripted_clock_next` at `src/core/test/scripted_ports.ail:20-24,62-67`; `records_for` is a local pure projection (`phase_c_seeded_dst.ail:400-405`), not the driver. |
| R7 | Partial (as-built refresh open) | **LANDED — residual discharged** | Header no longer claims the doc is missing (`ADR:12-13`); pillar-7 row and the rotation Open Question re-grounded on the workflow (`ADR:268`, `ADR:341-342`); as-built refresh verified in full (see RR7 grounding). Only defect is tense (RR7). |
| R8 | Accepted + Delegated | **LANDED, with a leak** | D2 gained six evidence criteria (`ADR:189-201`) and the "behavior, not … types or constructors" rule (`ADR:203-204`); 009 accepts with a required fault minimum (`009:357-364`), a clock-pair requirement (`009:418-423`), and an eleven-row acceptance test (`009:696-713`). Criterion 1 is satisfiable by HEAD (**RR2**) — the fix works only because the six are conjunctive. |
| R9 | Partial (inventory open) | **LANDED** | D3's blanket clause (`ADR:221-223`) grandfathers *all* existing `dst` identifiers, so no uncovered class contradicts the rule — I enumerated the classes and every one is covered (RR8 grounding). Confirmed no `dst` reaches a user-visible product surface (`rg -in dst src/tui/src/ui.ts` returns nothing) and that `dst_harness.ail`/`dst_gen.ail` export no `dst`-named identifiers. The residual is bookkeeping (RR8). |
| R10 | Partial (preventive rule open) | **LANDED — residual misrouted** | Pillar-1 row correctly narrowed (`ADR:262`) and "stronger than canon" is gone from the body. Re-verified by execution: `DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded` passes 5 families + canary, identical across two runs. The named residual, however, was shipped to 009 where it does not apply (**RR1**). |
| R11 | Accepted | **LANDED** | Grep re-run verbatim; the ADR's replacement text (`ADR:68-71`) is exactly what the command returns. |
| R12 | Accepted | **LANDED** | `rg -n 'deleted' ADR` returns hits only inside the preserved R10/R12 findings and the disposition row. Pillar 5 reads "normalized away, not virtualized" in the scorecard (`ADR:266`); `ADR:291` uses "re-introduces a controlled clock the seeded path never modeled". |

**Delegation count.** The re-review handoff says six findings were delegated to 009. The table marks
three (`R1`, `R2`, `R8`, all "Accepted + Delegated") plus residual items 2 and 3 and four body
delegations (D1.3 gap, D2 evidence detail, D4 world design, and three Open Questions). All of the
substantive ones are accepted by 009: seam → D1 + `009:720-725`; trace contract → D6; evidence →
the acceptance test; fault catalogue → D3; generator/program encoding → D8; search economics → D11;
tripwires → `NOTE-scope-and-sequence.md:82-95`, matching `ADR:150-168` in substance. The only
delegation 009 does not carry is the one it cannot (RR1).

## 2. Deadlock ruling

**Resolution 1: item 3 is not acceptance-blocking for 007, and the section heading over-promises.**
This ADR decides no implementation — it says so in its own first line (`ADR:17`) — so an
implementation-owned gate rule cannot logically gate it; the only 007 claim item 3 protects is a
scorecard row, and a scorecard row is dated evidence about a revision, which a later regression
falsifies without touching D1–D4. The forward-looking half of item 3 is in any case already
*decided* in `009/ADR-001:490-499`; what remains there is construction, which is exactly what
"blocking acceptance" should not mean. Resolution 3 is wrong on the facts — 009's dependency on
*acceptance* is stated twice and deliberately (`009/ADR-001:10-11`,
`009/NOTE-scope-and-sequence.md:31-33`), and it is the right dependency, because 009's naming gate
(`009/ADR-001:656-659`) inherits an authority 007 only has once accepted. Resolution 2 is right
about a *fragment*: R10's HEAD-facing ask belongs to 007 and is discharged nowhere (RR1), but it is
a one-sentence review rule, not an acceptance gate. So: re-partition the residual list into
*blocking* (empty after the RR edits) and *tracked after acceptance* (the HEAD-facing hermeticity
rule, and the naming inventory), accept 007, and let 009 clear its upstream blocker independently.
The cycle dissolves because it was never real — it was a heading applied to a list that mixes
blockers with follow-ups.

## 3. What is accurate

Re-verified by execution or by reading the cited lines, not assumed:

- **Every source anchor in the revised body holds at `a7932c6`**, exactly as cited:
  `tool_phase.ail:314-357` (the `match entries` recursion, list-ordered),
  `tool_runtime.ail:155-160` (`run_native_batch_rec`, sequential),
  `runtime-process.ts:628-634`, `session.ail:2209-2216`, `:1525-1529`, `:1609-1614`, `:1538-1557`,
  `:684,696`, `ports.ail:17-24`, `scripted_ports.ail`, `phase_c_seeded_dst.ail`.
- **The tui anchor narrowed correctly.** `:628-634` is `for (const call of calls) {` through
  `results.push(result)`, with both `await` arms inside the loop body. The narrowing from the first
  review's `:618-642` dropped only the method signature and the trailing progress emit; the
  sequential-await evidence that carries D1.1 is fully retained.
- **The R11 grep reproduces exactly.** Command re-run verbatim over `src scripts`: the only
  scheduling hit is `src/core/config.ail:110` (a comment), all `crash` hits are production/runtime
  comments, and there are zero hits for interleaving, fault injection, virtual clock, or partition.
  The claim that was literally false in the draft is now literally true.
- **The gate passes and is reproducible.** `DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded` → 
  `compaction_seeded_dst PASS families=1` and `phase_c_seeded_dst PASS families=4`, identical on a
  second run, with `compaction.gen.rng_canary seed=fixed ok`. Five families × five seeds = 25 cases,
  so the scorecard arithmetic holds.
- **The `DST_SEEDS` attribution clears the bar.** The handoff flagged it as loose; it is not. The
  scorecard cites the workflow (`ADR:268`), and the workflow really does set the values —
  `.github/workflows/verify-extensions.yml:99-104` sets `DST_SEEDS=500 DST_BASE_SEED=$(date +%Y%m%d)`
  on `schedule` and `DST_SEEDS=5 DST_BASE_SEED=1` otherwise; the script default agrees
  (`phase_c_seeded_dst.ail:568-569`). Both cited artifacts support the row.
- **The cross-ADR anchor divergence is not a conflict.** 007 cites `tool_phase.ail:314-357` and 009
  cites `:302-357` for related claims; `302` is the `export func` line and `313` closes the effect
  row, so 009's range includes the signature its claim needs and 007's isolates the dispatch loop.
  Both are right. Same for `tool_runtime.ail:151-165` (009) vs `:155-160` (007).
- **009 carries its delegations.** The mapping table (`009:684-694`) holds row by row against 007's
  pillars, and the acceptance test (`009:696-713`) is strictly stronger than 007's six criteria —
  notably its first row supplies exactly the clause RR2 says criterion 1 is missing.
- **Pillar 5 is consistent with the streaming spike.** 007 requires the clock to be *advanced by
  the simulator* (`ADR:95`), never to observe chunk arrival; the spike's `{IO}`-row finding
  (`spike/README.md:170-183`) is therefore not a gap against pillar 5, and 009's conclusion is right.
- **Residual items 1 and 2 are genuinely closed**, verified against the artifacts (see RR7 for item
  1's seven anchors; item 2's tripwire block at `ADR:150-168` matches
  `009/NOTE-scope-and-sequence.md:82-95`).
- **The ADR does not overstate the source note.** The note's "small step" claim
  (`NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md:50-52`) is confined to quoted findings; the note's
  honest-name proposal, its seed-alone-is-not-a-repro-key point, and its five-fixed-seeds critique
  are all carried faithfully into D3, pillar 7, and the search Open Question. `ADR:124` is the one
  place a cost echo survives (RR5).

**Residual risk, recorded as the handoff anticipated:** this ADR's authority is a naming discipline
kept by hand. Nothing in the repo enforces D3 — no lint, no CI check, no PR template rejects a new
`simulation`-bearing identifier — and after the RR1 edits, nothing enforces the pillar-1 hermeticity
premise either. Both are review rules. That is an acceptable state for a definitional ADR provided
it is *stated* rather than implied by a residual list that reads as if something will enforce them.

## 4. Accept / revise recommendation

**Accept after 10 edits — RR1 through RR10 — all of them in-document text changes; none requires
new implementation, project 009, or the upstream AILANG API.** RR1 and RR2 are the two that must
land: RR1 because the residual list as written cannot be cleared, RR2 because a gate whose first
criterion HEAD passes is the defect R8 raised.

On acceptance, the open residual items resolve as follows: items 1 and 2 are closed and verified —
strike them from the blocking list entirely; item 3 splits, its forward half discharged by
`009/ADR-001` D5 and its HEAD-facing half becoming a **tracked** 007 review rule (RR1); item 4
becomes **tracked**, not blocking, since D3's blanket clause already removes the contradiction and
only the inventory is outstanding (RR8). The *blocking* list is then empty, and 009's dependency on
007 acceptance is satisfiable immediately, leaving 009 blocked only on its own upstream API — which
is the dependency graph both projects intended.
