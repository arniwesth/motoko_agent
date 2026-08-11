# Handoff: execute WI-A13 — discovery, replay, and the execution program

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

This is **cluster 7**, the largest remaining item and the critical path. Six clusters have landed
(1, 2, 3, 4, 5, 6). Every dependency is satisfied: A7's class ids, A9's result types, A10's manifest
and profile, A12's threaded `world_state`.

**Read the plan's `## Standing rules` first. S1 is not advisory here — it is the whole risk of this
item, for the reason below.**

## Mission

Build D2's discovery and replay: the `ExecutionProgram` and `DiscoveryConfig` types, the seeded
generator with declared bounds, the pure structural validator, strict and regression replay, the
interaction log with causal identities and encounter ordinals, and D8's persistence obligations.

**Stage it, and partial completion is a legitimate stop.** Suggested order, each green alone:

1. **Types + the pure structural validator** — no driver, no generator. Rejects malformed schemas,
   negative time, duplicate identities, impossible references, absent required initial values.
2. **Discovery against `driver_only`** — record what the real driver actually requests.
3. **Strict replay** — the reproduction contract.
4. **Regression replay + D8's generator canary.**
5. **D8's persistence obligations** — secret redaction before persistence, and the deterministic
   diffable encoding with its compatibility policy.

If the session runs long, finish the current stage, commit, and report. Do not carry a half-built
stage across a stop.

## The rule you will break by accident — and this item is where it costs most

**D7 asks you to build the weakest check in the project as your primary invariant.**

The discovery contract is *"same manifest/profile/seed twice → identical resolved program,
interaction log, outcome, normalized trace."* It is required, it is correct, and **across six
clusters the determinism axis has caught exactly zero of the fourteen sites where two alternatives
type-check and the wrong one is silent.** Not cluster 1's frozen cursor. Not cluster 4's dropped
trace record. Not one of A12's four — including a clock defect that type-checks clean, is
trace-complete, passes **both** determinism axes, and is wrong.

The reason is structural and it applies with full force here: **a frozen thing is perfectly
reproducible.** Concretely, in this item:

- A generator cursor that does not advance produces **the same program twice** — determinism green.
- A recorder that drops every interaction of some class produces **a consistent log** — green.
- A program recording five interactions when the driver made seven produces **five both times** —
  green, replayable, and silently describing a different execution than the one that ran.

**So the assertion this item needs beside determinism is completeness against what the driver
actually requested** — not "the log reproduces" but "the log accounts for every request the driver
made." That is the discovery-side form of the trace-completeness assertion cluster 4 forced onto
A12, and it is the one thing here that determinism cannot substitute for.

Per S1: **write it before the recorder, not after.**

## Your inputs, verified to exist at HEAD

Signatures checked while writing this table. **Run `git diff --stat 777edbe..HEAD -- src packages
scripts Makefile` first; if non-empty, re-verify.**

| Input | Export | Notes |
|---|---|---|
| A10 | `dst_driver_only.driver_only() -> ProfileDefinition` (`:99`) | the definition |
| A10 | `validate_driver_only(loading_against, discovered, calls, catalogue)` (`:232`) | the whole load gate in one call |
| A10 | `driver_only_manifest(source_revision, toolchain, abi_version, normalized_configuration, classifier_2_set, unrouted_fields, scan_root_commit)` (`:250`) | derived sets are **arguments** — the tool derives them per run |
| A10 | `dst_profile.replay_metadata_of(m: ExecutionManifest) -> ReplayMetadata` (`:1052`) | **use it.** Projecting from the manifest is what stops a result carrying a profile id that disagrees with its own manifest |
| A10 | `dst_profile.routing_violation_at(...) -> Option[DstResult]` (`:1096`) | `None` means proceed. **This item is where its call site lands** — establishing the profile is what makes threading it something other than a dead rider |
| A9 | `dst_result` — `SystemRun` (`:93`), `HarnessFailure` (`:106`), `DstResult` (`:114`), `ReplayMetadata` (`:40`), `HarnessFailureKind` (`:74`) | the result contract; do not restate it |
| A7 | `required_class_ids()` (`dst_fault_catalogue.ail:165`) | stable class ids. Three are PascalCase because they were adopted from a live wire surface — deliberate and documented |
| A12 | `StepProvider.ScriptedWorld(WorldState)` (`stub_step.ail:53`) | **the replay seam.** Added by A12 so an assertion could seed a world; this is what it was for |
| A12 | `WorldState` fields: `script`, `clock_ms`, `approvals`, `env`, `tools` | what a program must be able to reconstitute |

## Definition of done

**The structural validator, green.** Pure, runs before replay, rejects malformed schemas, negative
time, duplicate interaction identities, impossible static references, absent required initial values.
Each rejection has a fixture and names its rule. Carry a **negative control** — a valid program that
must pass — because a validator that only ever rejects passes a suite of only-failing fixtures.

**Discovery, green.** Chooses only at requests the real driver actually makes; never invents a tool,
approval or extension-effect request disconnected from production control flow. Each choice a
deterministic function of generator id/version, seed, generator state, the bounded request
projection, and current world state — **no ambient RNG**. Records every actual request projection and
chosen outcome. Declared bounds on interactions, chunks, payload bytes, resource size and clock
advancement; exceeding one is a generator failure, not an unbounded run.

**Replay, green.** Strict requires causal identity and recorded projections to match under the
recorded manifest/profile. Regression requires compatible causal identity, records projection
differences, may continue. A wrong kind/origin, unsafe identity mismatch, exhausted program, or
**unused interaction** is a `HarnessFailure` — not a simulated fault. Regression never weakens
tool-call/result correlation.

**The invariants, green.** D7's discovery-contract invariant **and the completeness assertion beside
it**, per above. Plus D8's pinned generator canary per stable generator id, failing on a seed remap
without a generator-version bump.

**D8's persistence obligations, green.** A secret-shaped fixture is rejected or redacted **before**
persistence. An old-schema program either decodes or fails closed with a pinned-runner pointer —
never silently reinterpreted. The encoding is deterministic and diffable; its selection is delegated
to this plan by the ADR's Non-goals, so choose it here and say why.

**Every structural guard is mutation-tested, not asserted** (cluster 5, C5). A10 demonstrated all
three of its guards going red under deliberate mutation; a guard that never fires is the defect these
items exist to prevent.

## Out of scope — actively do not do these

- **The D7 invariant *set* and D11 corpus reporting** — A14's. Build the discovery-contract invariant
  and the completeness assertion this item needs; do not build the eleven-family invariant suite.
- **The two corpora and their CI jobs** — A15's.
- **The D4 latency pair** — A14's, though it consumes your generator and replay.
- **Shrinking.** Explicitly deferred past the first name-adoption gate and recorded as such in the
  plan's out-of-scope list. Replay of the *unshrunk* failing program is not optional and is yours.
- **A second profile** — WI-C5, needs Milestone B.

## Stop and report rather than deciding inline

- **If discovery cannot record a request class the driver actually makes**, that is a D2 finding, not
  a gap to work around. `ExpectExtensionEffect` exists precisely because a missing interaction makes
  a class unreplayable.
- **If the completeness assertion cannot be written** — if there is no way to know what the driver
  requested independently of what the recorder recorded — say so loudly. That would mean the
  recorder is its own oracle, which is the shape of every silent defect this project has found.
- If the encoding choice forces a wire-visible or artifact-format commitment beyond D8's stated
  policy, stop; that is a compatibility decision the plan owns.

## Traps

Clear `.ailang/cache` before believing a contradicting type error. **Rebuild the parallel
`ailang check` closure tool before editing** — five clusters have reported it is what keeps
convergence linear, though cluster 3 noted new-artifact work produces less of the convergence wave it
exists for. Never probe from `/tmp`. `make dst` and CI both use `--keep-going`; read exit status.
`scripts/dst/probe_phase_vocab_sealed.ail` fails at baseline (`IMP010`, pre-existing, in no target —
WI-A17 owns it). Pin is v0.26.0, Makefile-guarded. **`ailang iface` cannot parse this repo's package
files** (`fb_6c81854baf59b316`) — use classifier 2's approach if you need parsed interfaces.

## Report back

Seventh calibration run. Five sizing models now exist and this item may need none of them or a sixth:
S4 prices artifact rows by discovered-versus-transcribed, S5 prices detectors by round trips weighted
for loudness, S6 prices compositions by input artifacts plus recorded bindings. **A13 is plausibly
all three at once** — new types, a generator that is partly a detector, and a composition over six
artifacts.

- **Time and the unit that actually predicted it.** If it is a blend, say the blend; if one dominates,
  say which. This is the last large item before the name gate, so the answer decides whether A14/A15
  can be scheduled with confidence.
- **The judgement ratio, split** if the item ships both machinery and content (cluster 5's rule) —
  the generator is machinery, a seed corpus is content.
- **Whether any site admitted two type-checking answers with a silent wrong one, and what caught it.**
  Fourteen across six clusters so far, determinism catching none. **If your completeness assertion
  catches one here, that is the strongest possible vindication of S1** and should be reported as such.
- **Anything the plan or ADR got wrong**, as a correction or amendment.
