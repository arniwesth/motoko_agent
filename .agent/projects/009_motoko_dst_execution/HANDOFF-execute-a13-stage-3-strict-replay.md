# Handoff: execute WI-A13 stage 3 — strict replay

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-A13 stage 3 of five.** Stages 1 (`9c4d724`, types + pure structural validator) and 2
(`8b0d605`, discovery graded in both directions) are landed and green. Stages 4 and 5 are not
started. **Partial completion at a clean stage boundary is the established pattern here — two
clusters have used it; keep it.**

**Read first, in this order:** `NOTE-cluster-8-execution-report-and-plan-corrections.md` (stage 2, and
its closing section is addressed to you), then `NOTE-cluster-7-…` (stage 1), then the plan's
`## Standing rules` — **S1 and S7 are the whole risk of this stage.**

## Mission

Build **strict replay**: consume an exact `ExecutionProgram`, reconstitute the world from it, drive
the real traced driver, and require causal identity and recorded projections to match under the
recorded manifest and profile.

Also yours, per stage 2's closing notes: **`world_state_of`** — reconstituting a world from a
program — under the constraint in `dst_program`'s design note 3.

Not yours: regression replay and D8's generator canary (stage 4); D8's persistence obligations
(stage 5); A14's invariant set and D11 reporting.

## The rule you will break by accident

**Strict replay's own contract is the weakest check in the project, and this stage will be tempted to
make it the only one.**

The contract is *"the exact program reproduces the same interaction log, terminal outcome and
trace."* That is a determinism contract. **Determinism is now 0-for-18 across eight clusters** — it
caught neither cluster 1's frozen cursor, nor cluster 4's dropped record, nor A12's four, nor stage
1's over-strict validator, nor stage 2's three.

The specific way it fails *here*: **strict replay compares recorded against actual, and if both sides
derive from the same defective projection they agree.** Concretely —

- A `world_state_of` that drops a class reconstitutes a world that never serves it; the replay makes
  no requests of that class; the comparison passes.
- A replayed run whose recorder has the same gap as the discovery recorder produces a log that
  matches the program **because both are wrong in the same way**.
- A world missing a queue serves defaults *consistently*, and consistently is all this contract asks.

**Program-versus-log agreement is the recorder grading itself, one level up.** So:

> **Re-run stage 2's independent witnesses against the replayed run, not just the program comparison.**

`dst_discovery.check_discovery(log, witness)` and `discovery_ok` already exist and are already
two-sided. A replayed run is a run: it has a ledger trace written by production code, a clock delta,
and a world. Grade it the same way discovery is graded, and the class of defect above becomes
visible — a replay that drops a class fails the *witness* balance even when it matches the program
perfectly.

Per S1, that grading goes in **before** the replay loop.

## The trap stage 2 measured and left for you

**Your failure-path scenarios need a witness that survives `Err`, and stage 2's message-derived ones
do not.**

Stage 2's approval witness counts the driver's tool-role messages. On the `Err` path the returned
message list is empty, so those witnesses go vacuous — silently, and a vacuous check passes. Stage 2
guarded against this by asserting each of its scenarios reached its terminator, which makes the
vacuity loud *for scenarios that succeed*. **Stage 3 wants failure-path scenarios**, so that guard
stops being sufficient.

What survives `Err`, verified at HEAD: `TracedSessionResult` is
`{ result: Result[[Message], AIError], trace: LedgerTrace, world: WorldState }` — **the trace and the
world are returned on both paths.** The ledger-trace witnesses are the ones to use for failure
scenarios: `ProviderCallPrepared` (`session.ail:1998`, emitted separately from the dispatch call) and
`V2ToolDispatchStart` (`tool_phase.ail`), both written by production driver code rather than by the
world adapter. Two authors, one execution — that is what makes them an oracle.

## `world_state_of`, and the constraint it must satisfy

`dst_program`'s design note 3 is deliberate and stage 3 must not "fix" it: **the program does not
carry the provider script, the approval queue or the tool queue.** They are projections of the
interaction list. The note states why — *"if the program carried both, a program could serve a
response that no interaction records, which is the exact shape of the completeness defect this item
exists to prevent."*

So `world_state_of` derives those queues **from the interactions**, and the invariant that keeps it
honest is that a served response must have a recorded interaction behind it. If you find yourself
adding a queue to `ExecutionProgram` to make replay easier, stop — that is the defect the note
prevents, and it is a plan correction if genuinely required.

`WorldState`'s fields, for reference: `script`, `clock_ms`, `approvals`, `env`, `tools`.

## Inputs, verified at HEAD

**Run `git diff --stat 56e275f..HEAD -- src packages scripts Makefile` first; if non-empty,
re-verify.**

| Input | Where |
|---|---|
| `ExecutionProgram`, `DiscoveryConfig`, `Interaction`, `CausalIdentity`, `TimedOutcome`, the pure validator | `dst_program.ail`, `dst_interaction.ail` (std-only leaf) |
| `check_discovery(log, w)`, `discovery_ok`, `class_balance`, `DiscoveryWitness`, `driver_env_keys()` | `dst_discovery.ail:348, 366, 270, 195, 164` |
| `RecordingWorld(WorldState)`, `recording_ports` | `stub_step.ail:68, 316` |
| `TracedSessionResult.world` | `session.ail:169` |
| `ScriptedWorld(WorldState)` — the replay seam | `stub_step.ail:68` |
| `driver_only()` **v2**, `validate_driver_only`, `driver_only_manifest`, `replay_metadata_of` | `dst_driver_only.ail:99, 232, 250`; `dst_profile.ail:1052` |
| `routing_violation_at` | `dst_profile.ail:1096` — **still a dead rider**; stage 2 established the profile only as a manifest on the program. Land its call site here if replay gives it a consumer; if not, say so |

## Definition of done

**Strict replay, green.** Consumes an exact program; requires causal identity and recorded
projections to match under the recorded manifest/profile; **a wrong kind/origin, unsafe identity
mismatch, exhausted program, or unused interaction is a typed `HarnessFailure`** — not a simulated
fault, and `unused interaction` is the one most easily forgotten because nothing fails without it.

**Witness-graded, not just program-matched**, per the rule above — with a fixture where the replay
matches the program and **fails the witness balance**, which is the assertion that distinguishes this
stage from a tautology.

**Failure-path scenarios**, graded on `Err`-surviving witnesses, with the vacuity control that made
stage 2's succeed-only guard sufficient extended to cover them.

**Per S7 — and this is not optional, it caught three defects in two stages:** carry a fixture that
must **survive**, containing every shape the specification explicitly protects, **with no two of its
quantities equal.** For this stage that means at minimum a program whose interaction count, request
count and consumed-answer count differ. A fixture whose quantities are all equal cannot distinguish
which quantity a check is reading — that is exactly how stage 2's sites 17 and 18 hid.

**Every structural guard mutation-tested** (C5), and any grep-based Makefile guard you add **anchored
to a syntactic form** (cluster 7's correction 1 — a bare-token guard eventually fires on the artifact
documenting it, which kept `make world_state` red for two clusters).

## Stop and report rather than deciding inline

- **If replay requires the program to carry a queue**, see design note 3 above — report it.
- **If a required interaction class cannot be replayed** because discovery could not record it, that
  is a D2 finding. Stage 2 already recorded one adjacent gap: D3's `approval_deadline_exceeded` is
  currently unreachable by a discovered program, because D2 gives `ExpectApproval` a deadline and the
  driver's approval channel carries none.
- If strict replay's identity comparison forces a change to `CausalIdentity`, stop — stage 1 recorded
  identity-as-a-sum as one of its three decided bindings, and revisiting it is a plan-level call.

## Traps

**Run `make dst` and read `$?`** — not a scan of its output. It was red for two clusters because
`--keep-going` made a failure one line among 233 green ones, and every verification up to cluster 7,
including the plan owner's, ran individual targets instead. **Do not run other `make` targets
concurrently with it** — two runs were corrupted that way in stage 2 before the discipline was
applied.

Clear `.ailang/cache` before believing a contradicting type error. Rebuild the parallel `ailang check`
closure tool before editing (~1.7 s over the 13-module closure). Never probe from `/tmp`. Two pin
quirks stage 2 hit and noted in-source: a record literal after `=>` parses as a block, so
`({…}) :: rest` needs the parens; and a local `let` does **not** shadow an imported name — the error
points at the type, not the shadowing. `probe_phase_vocab_sealed.ail` fails at baseline (`IMP010`,
WI-A17 owns it). Pin is v0.26.0.

**Inserting lines into `session.ail` or `stub_step.ail` above an attributed clock site re-measures
A5's table** and cascades to five artifacts including a mandatory `driver_only` re-issue (stage 2's
correction 4). Every guard fires loudly with an exact expectation, so this is survivable — but budget
it, and note that stage 2 flagged a coordinate-independent anchor as an A14/A15 decision.

## Report back

Ninth calibration run.

- **Time, and the recorded-binding count** — S6's generalised second term (*any fact that cannot be
  read and must be decided*) has now predicted two stages: one binding at stage 1, three at stage 2,
  cost ratio ~3×. **This is the third data point and the one that tests it**, since stage 3 is
  nominally driver-wiring like stage 2.
- **Judgement ratio, split** machinery versus content. Stage 2 was ~30% / ~95%, and the content half
  is where both its silent defects were resolved.
- **Whether any site admitted two type-checking answers with a silent wrong one, what caught it, and
  what did not.** Eighteen across eight clusters; determinism has caught none. **If your witness
  grading catches one that program-matching missed, that is this stage's central result** — report it
  as such.
- Anything the plan or ADR got wrong.
