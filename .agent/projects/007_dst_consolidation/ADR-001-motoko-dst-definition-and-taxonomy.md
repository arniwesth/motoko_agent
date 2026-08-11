# ADR-001: What Constitutes Motoko's DST — Definition, Taxonomy, and the Term's Scope

Date: 2026-07-24
Status: Proposed — revised after independent review; re-review required
Consolidates: `NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md` (this project) — the running
analysis across PRs #84 → #99 → #100 that this ADR formalizes.
Amends: `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — replaces that
ADR's definition and naming threshold while preserving its decisions to exercise production code,
use explicit fakes, record normalized traces, and assert structural invariants.
Follow-up: `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — owns
the implementation architecture required to meet this ADR's conformance bar.
As-built: `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` describes the current
framework and must be updated when this decision is accepted and again when project 009 lands.

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
`../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`. This revision
followed an independent review whose findings are preserved below; a fresh re-review is required
before acceptance.

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
   This is still a generated *schedule* and still legitimately *simulation* — it is simply a line,
   not a lattice, which is why it is cheap.

2. **Logical faults, not physical.** The environment Motoko runs against is the provider, tool,
   approval, extension-effect, and time-facing logical boundary—not disk sectors or network
   transport. Pillar 2 does not disappear; it *relocates* to that protocol/effect surface. The
   faults worth injecting (pillar 4) are the ones that cause real agent bugs and can be represented
   as typed outcomes, not kernel-level simulations:
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
- Pillar 4 (seed injects logical faults from the D1.2 catalogue) — **required**.
- Pillar 5 (a stepped virtual clock carried in the script; timeouts reachable) — **required**.
- Pillar 6 (invariants over the resulting `LedgerTrace`) — **required**.
- Pillar 7 (reproduction contract: seed + generator/schema versions + exact execution program) —
  **required**.
- Pillar 2-physical, pillar 3-concurrent — **explicitly not required** (D1.3).

All required logical pillars must hold together. In particular, until pillars 3/4/5 are met, the
method is **not** DST regardless of how much other machinery exists.

The gate is enforceable only with automated evidence:

1. A recorded seed produces a typed program containing multiple ordered external instructions
   whose kinds and order were generator choices.
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
axis. New identifiers follow this rule, and the existing as-built document must state the
distinction when this ADR is accepted.

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

## HEAD scorecard (branch `arniwesth/mot-43-l1-seeded-families`)

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
- The terminal trace and replay-program schemas become maintained compatibility surfaces.

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
- **Shrinking.** With 4–5 drawn params per family, counterexamples arrive mid-sized. Is minimization
  worth building now, or explicitly deferred until generated trajectories make cases larger?
- **Fault-catalogue ownership.** Project 009 requires every modeled fault to map to a real production
  outcome and recovery branch; the implementation plan must choose the single source of truth.

## Notes for a reviewer

The independent review below was performed against the pre-revision draft. Its findings are
preserved as the audit record. Because this revision changes the taxonomy language, naming gate,
empirical scorecard, and implementation handoff, a fresh re-review is required before acceptance.

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

### Residual items blocking acceptance

1. ~~**Refresh `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`**~~ (R7, R4, R9) —
   **closed 2026-07-24.** Added a `Naming` header caveat and an "Amendment: what this framework is
   *not*" section; added a "The seeded axis" section (5 families, RNG canary, seed config, the
   two extension rules); added `dst_seeded` to the gate tree, the `*.gen.*` namespaces to the ID
   table, and the nightly 500-seed / PR 25-case CI split; narrowed the caps-as-conformance claim
   per R10; added 007 and 009 to the decision-history table; and replaced the stale "seeded
   generation … not yet built" deferred item with project 009's actual scope.
2. ~~**Add the D1.1 / D1.3 revisit tripwires to this ADR**~~ (reviewer's recommended action 5) —
   **closed 2026-07-24.** Added as the "Revisit tripwires" block under D1, with all four grounding
   anchors independently re-verified at HEAD before citation. The runner-side half remains 009's,
   per `../009_motoko_dst_execution/NOTE-scope-and-sequence.md`.
3. **Preventive hermeticity rule** (R10): a gate or review rule barring new input-bearing `IO`/`Env`
   calls on DST entrypoints. Owned by 009 — it is the concrete form of D2 evidence item 6.
4. **Per-class naming inventory** (R9): folded into item 1; the blanket grandfather removes the
   contradiction, but the inventory itself is unwritten.

Items 1, 2 and 4 are ADR/doc work with no upstream dependency. Item 3 is 009's. None of the four
requires the AILANG recorded-stream API that blocks 009's own acceptance.

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
