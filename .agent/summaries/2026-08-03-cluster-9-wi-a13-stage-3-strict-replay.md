# 2026-08-03 Cluster 9: WI-A13 stage 3 — strict replay

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `fe9f2af` → `5c2524f`, **2 commits**, one of them production source. Input was
`HANDOFF-execute-a13-stage-3-strict-replay.md`, executed cold against HEAD. Ninth code session of
project 009, following clusters 1, 4, 6, 3, 2, 5, 7 and 8.

Re-grounding first, as the handoff instructed: `git diff --stat 56e275f..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**Partial completion at a clean stage boundary**, as clusters 7 and 8 were. Nothing half-built
carried across the stop.

| | |
|---|---|
| Stage 1 — types + pure structural validator | landed (cluster 7) |
| Stage 2 — discovery against `driver_only` | landed (cluster 8) |
| Stage 3 — strict replay | **landed, green** |
| Stage 4 — regression replay + generator canary | not started |
| Stage 5 — D8 persistence obligations | not started |

A follow-on session (Fable 5, `9cb61b3`) independently re-verified `make dst`, reproduced correction
1's language trap from its own probe, filed it upstream as `fb_b39697480a4e8bbc`, and extended the
plan propagation — including two stale routed-count residues and an A10-side passage that still
claimed A13 owned the exclusion check. That commit is not mine and is noted here only because it sits
on top of this session's work.

## What landed

| Commit | Item | Gate |
|---|---|---|
| `2d752da` | **stage 3** — strict replay, the reconstitution, the codecs, the acceptance suite | `make strict_replay` |
| `5c2524f` | execution report + three corrections, propagated to the plan | plan |

New files: `src/core/dst_replay.ail` (902), `scripts/dst/strict_replay_dst.ail` (963).
Modified: `src/core/ports.ail` (+338), `src/core/test/stub_step.ail` (+21), `Makefile` (+77).

`make strict_replay` is wired into the `dst` aggregate. **`make dst` exits 0** on the committed tree,
read as an exit status per cluster 7's process amendment — 340 checks, 52 of them new.
`make check_core` exits 0.

## The order the work took

S1 was followed literally, and it is what produced the session's result.

1. **The assertion first.** `dst_replay.ail`'s walk, the two-sided reconstitution balance and the
   typed failures, with 13 inline tests, before `world_state_of` existed and before any replay ran.
2. **The codecs**, because step 3 could not be written without them — see below.
3. **`world_state_of`**, graded by the balance written in step 1.
4. **The acceptance script**, then the Makefile target, then the measurements.

The one deviation from the handoff's expectation: it did not anticipate that the recorded outcome
would have to change at all. That turned out to be the whole finding.

## The finding, and why it was invisible to stage 2

Stage 2's `recording_model_step` wrote `payload: s.prose`. D2 says a provider timed outcome carries
*"a final `StepResult` or `AIError`"*; the prose is neither, and it drops the step's **tool calls** —
which are what cause the next production tool request. A program discovered from a run with tool
calls reconstituted a script that made none, and the replay terminated at step 0.

Measured by reverting the payload at HEAD:

| Gate | Verdict against the defective recorder |
|---|---|
| `make discovery` — 48 checks, 3 scenarios | **exit 0**, green |
| the two-sided class balance | green |
| the wire witness (`provider_call_prepared`, `v2_tool_dispatch_start`) | green |
| stage 1's structural validator over the recorded log | green |
| determinism | green |
| `make strict_replay` | **red** — `replay-refused-provider-outcome-undecodable` at #7 |

Discovery cannot see it because **discovery never reads the payload back**. Every check stage 2 owns
asks how many and which; none asks whether a recorded outcome is sufficient to re-serve the response.
Only a replay asks that.

The silent variant is the sharper one. Recording `encode_provider_outcome({ s | tool_calls: [] })`
makes the payload decode, so the refusal does not fire and **`reconstitution_balance` stays green** —
the script queue length is exactly right. Four other guards fire: the replay comparison (6
mismatches), the non-vacuity control (`tool=0 reads=0 served=0`), and both S7 rows. A count-shaped
check blind to a content-shaped defect, for the second time in this project.

**The fix went into the recorded outcome, not onto the program.** Widening `ExecutionProgram` with a
script field is exactly what `dst_program`'s design note 3 exists to prevent; the note's invariant is
preserved instead by making the recorded interaction complete. The same argument applied a second
time on the tool class: `ToolFailed`'s payload was its *message*, so the failure **code** was lost and
a D3 fault class replayed as an ordinary success.

## The tautology control

Strict replay re-uses `recording_ports` — the recorder that produced the program — so a recorder gap
sits on both sides of the comparison by construction and the comparison passes because both sides are
wrong in the same way. This is the failure mode the handoff named, and it is structural rather than
hypothetical.

Axis H asserts the distinction on real runs. Drop the provider class from the program and from the
replayed log, independently:

- `strict_replay_findings` reports **nothing** — perfect agreement;
- `check_discovery` against the independent witnesses reports `discovery-under-recorded`.

**Demonstrated load-bearing, not asserted:** substituting a log-derived `provider_calls` for the
trace-derived one — the recorder grading itself — makes the shared-defect pair **pass every check in
the suite**. That one substitution is the difference between strict replay and a restatement of
itself.

## Site 19, and it came from the language rather than the specification

`ports.ail` did not import `std/option`. `std/json`'s accessors return `Option`, so

```
match get(obj, key) { None => fallback, Some(j) => ... }
```

does not match constructors there — `None` binds as a **fresh variable**, the first arm is
irrefutable, the second is dead, every field reads back as its fallback, and the module type-checks
clean with no warning.

**Caught by:** the codec round-trip tests, three of four red on their first run. **Not caught by:**
`ailang check`, or any count in the suite — a decoder returning fallbacks is perfectly deterministic.

The generalisation is S7 applied to a record instead of a fixture: *a codec's guard is a round trip
asserted field by field, with every field holding a distinct value.* A14 and A15 encode programs for
D8's persistence and inherit it directly.

## Corrections propagated to the plan

1. **S7 sharpened — assert the fixture's coverage, do not describe it.** Cluster 8's corollary ("a
   fixture's stated justification is itself a claim") recurred within one cluster of being written:
   this session's surviving fixture documented a tool **fault** outcome it never reached, because its
   queue held two entries against one approved dispatch. Prose cannot notice coverage drifting as the
   driver changes. Both halves of S7 are now executable checks in the suite.
2. **`routing_violation_at` reassigned from A13 to C5**, on a structural ground rather than a
   scheduling one: the check discriminates on a `hook_id`, and no D2 interaction carries one — its
   real consumer is the hook dispatch site at `src/core/ext/runtime.ail:279`, production driver code
   with no profile in scope. Both stages 2 and 3 established the profile and neither could give it a
   consumer.
3. **D8's version gate and the actual compatibility boundary disagree.** A pre-fix program is
   undecodable by this build and fails closed with a named refusal — D8 behaving correctly on its
   first real test. But `program_schema_version()` was **not** bumped, because no schema *field*
   changed; what changed is what a payload string contains. Flagged for A14/A15, not decided here.

## Calibration

**Round trips: 3 compiler (all loud), 0 gate, 2 silent** (both found by deliberate probing).

- **Compiler.** `as` is the import-alias keyword and cannot be a match binder — the parse error points
  at the `=>`, not the pattern. A forward reference from inside a *recursive* function is `undefined
  variable`, though one from a non-recursive function resolves fine. And one missing import. All
  noted in-source.
- **Gate: zero.** Notably A5's attribution table did not fire: every `stub_step.ail` insertion went
  below the anchored line 161, and the import list was widened in place rather than by adding a line.
  Cluster 8's five-artifact cascade — including a mandatory `driver_only` re-issue — was avoided for
  the cost of one `sed -n '161p'`. That weakens the case for building a coordinate-independent anchor:
  the cost is borne by authors who do not know the anchor exists, which is a documentation problem
  before it is a tooling one.
- **Silent: 2.** Site 19 and the `None`-as-a-variable binding. Neither found by a gate; both found by
  writing a check for a case the existing suite could not reach.

**Recorded bindings: three** — the recorded outcome must be sufficient to re-serve the response;
`UnusedInteraction` maps onto A9's `ProgramMismatch` rather than adding a variant; and the
Err-surviving approval witness (the tool calls in the script entries the run consumed, from the
fixture's input crossed with the world's `script` cursor).

**Cost against stage 2: roughly 1×, and this is the calibration result.** The binding count predicted
parity and parity is what happened, so **the predictor survives its third data point** — but cluster
8's *explanation* for its own 3× ("the driver wiring is where the time went") does not, because stage
3 is also driver wiring, and it delivered strictly more: a new module, two codecs, a second acceptance
script, and a Makefile target with a wire comparison.

**What actually made it cheap is in no model: stage 2 left an assertion that generalised.**
`RecordingWorld`, `TracedSessionResult.world`, `check_discovery`, `class_balance`'s
one-arithmetic-site discipline and `approvals_served` were reused verbatim — the reconstitution
balance is `class_balance` with different nouns, and grading the replayed run is a function call. The
saving appears as bindings that never had to be made, which a per-stage count cannot see. Recorded as
commentary on S6; **no sixth model and no new term.**

**Judgement ratio, split** (cluster 5's rule): **machinery ~35%**, **content ~90%**. Slightly more
machinery than stage 2's ~30% and slightly less content than its ~95%, in both cases because the
codecs are machinery with no specification behind them at all. The most consequential decision in the
commit is content: the denial placed *between* two approvals in the surviving fixture, without which
`approvals_consumed` and `tool_dispatches` are equal and stage 2's site 18 hiding place is reproduced
exactly. The fixture's five quantities are 5 / 4 / 6 / 3 / 2.

## Tooling notes

- The parallel `ailang check` closure tool runs in **1.741 s** over 14 modules; rebuilt at session
  start, per seven prior clusters.
- `make dst` takes several minutes. Read its **exit status**, and run nothing else concurrently
  (cluster 8's discipline; observed, no corruption this session).
- Probes were written inside the repo and deleted, never from `/tmp`.

## For stage 4

Regression replay is `strict_replay_findings` with its last two rules demoted from failures to
recorded differences. `compare_at`'s coarsest-difference-first ordering was written for exactly that:
kind, origin and identity stay fatal; `ProjectionDiffers` and `OutcomeDiffers` are the two that
become recorded. D2's *"regression replay never weakens tool-call/result correlation or delivers an
outcome to a different logical request"* is already a line in the code — it is the line between
`UnsafeIdentity` and `ProjectionDiffers`.

The tautology control does not survive being copied carelessly: both halves must stay, the
shared-defect pair shown to MATCH and the independent witness shown to REJECT. Deleting either leaves
a check that passes for the wrong reason.
