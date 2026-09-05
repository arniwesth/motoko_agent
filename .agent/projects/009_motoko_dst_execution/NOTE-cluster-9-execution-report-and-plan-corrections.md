# Cluster 9 execution report — WI-A13 stage 3, and three corrections

Ninth calibration run. **Partial completion at a clean stage boundary**, as clusters 7 and 8 were.
Stage 3 of WI-A13's five is landed, green and committed. Stages 4 and 5 are not started and nothing
half-built is carried across the stop.

Commit:

- `2d752da` feat(A13): stage 3 — strict replay, graded by witnesses and not by itself

**`make dst`: exit 0** — read as an exit status, not a scan of output, per cluster 7's process
amendment. 340 green checks, 52 of them new. **`make check_core`: exit 0.**

No source drift at session start (`git diff --stat 56e275f..HEAD -- src packages scripts Makefile`
was empty).

---

## What landed

**`src/core/dst_replay.ail`** — the walk (kind, origin, identity, request projection, outcome, plus
both ends: an exhausted program and an unused interaction), `world_state_of`, the two-sided
reconstitution balance, the refusal type, and the projection onto A9's typed `HarnessFailure`.
Written before the loop that consumes it (S1); 13 inline tests.

**`src/core/ports.ail`** — the recorded-outcome codecs, encoder and decoder adjacent, with round-trip
tests.

**`src/core/test/stub_step.ail`** — the provider recorder writes the whole step rather than the
prose.

**`scripts/dst/strict_replay_dst.ail`** and **`make strict_replay`**, wired into the `dst` aggregate.
Two scenarios × nine axes — refusal, manifest, reconstitution, the replay, seven mutation rows, the
typed failure, witness grading, the tautology control, determinism — 52 checks plus the wire
comparison.

---

## The result the handoff asked for, and it is the central one

The handoff said: *"If your witness grading catches one that program-matching missed, that is this
stage's central result."* **It did, and the measurement is exact.**

### Site 19 — the provider outcome recorded the prose, and discovery is green against it

Stage 2's `recording_model_step` wrote `payload: s.prose`. D2 says a provider timed outcome carries
*"a final `StepResult` or `AIError`"*. The prose is neither: it drops the step's **tool calls**, which
are what cause the next production tool request.

**Measured, by reverting the payload at HEAD:**

| Gate | Verdict against the defective recorder |
|---|---|
| `make discovery` (48 checks, 3 scenarios) | **exit 0** — green |
| the two-sided class balance | green |
| the wire witness (`provider_call_prepared`, `v2_tool_dispatch_start`) | green |
| stage 1's structural validator over the recorded log | green |
| determinism | green |
| `make strict_replay` | **red**, `replay-refused-provider-outcome-undecodable` at interaction #7 |

Discovery cannot see it **because discovery never reads the payload back**. Every check stage 2 has
is about how many and which; none is about whether the recorded outcome is sufficient to re-serve the
response. That question is only asked by a replay.

The *silent* variant is sharper still. Record `encode_provider_outcome({ s | tool_calls: [] })` — the
payload now decodes, so the refusal does not fire, and `reconstitution_balance` is **green**, because
the script queue length is exactly right. Four other guards fire: the replay comparison (6
mismatches), the non-vacuity control (`tool=0 reads=0 served=0`), and both S7 rows. **The count
balance being green while the content is wrong is the whole argument for the outcome comparison and
the witnesses**, and it is the second time in this project a count-shaped check has been shown blind
to a content-shaped defect (stage 2's provider `step` was the first).

### The fix is in the recorded outcome, NOT on the program — and that is design note 3 working

`dst_program`'s design note 3 refuses to put the script, approval queue or tool queue on the program.
The temptation here is exactly the one the handoff warned about: replay needs a script, so put a
script on the program. **Not done.** The note's invariant — a served response must have a recorded
interaction behind it — is preserved by making the *recorded interaction* complete instead. The
payload becomes a structured projection, which is what D2 already calls it (*"arguments and
message/payload digests are recorded projections, not silently discarded"*).

The same argument applies once more, on the tool class: `ToolFailed`'s payload was its **message**
alone, so the failure **code** was lost and a D3 tool fault class replayed as an ordinary success.
Same fix, same place.

### And the tautology control, which is the stage's own guard against itself

Strict replay re-uses `recording_ports` — the recorder that produced the program. A recorder gap is
therefore on **both sides** of the comparison by construction, and the comparison passes because both
sides are wrong in the same way.

Axis H asserts the distinction on real runs: drop the provider class from the program **and** from
the replayed log, independently, and

- `strict_replay_findings` reports **nothing** — perfect agreement;
- `check_discovery` against the independent witnesses reports `discovery-under-recorded`.

**Demonstrated load-bearing, not asserted:** substituting a log-derived `provider_calls` for the
trace-derived one — i.e. the recorder grading itself — makes the shared-defect pair **pass every
check in the suite**. That single substitution is the difference between strict replay and a
restatement of itself.

---

## Correction 1 — a match arm can bind a CONSTRUCTOR NAME as a fresh variable, silently

`ports.ail` did not import `std/option`. `std/json`'s accessors return `Option`, so

```
match get(obj, key) { None => fallback, Some(j) => ... }
```

does not match constructors there — **`None` is a fresh variable binding**, the first arm is
irrefutable, the second is unreachable, every field reads back as its fallback, and the module
**type-checks clean with no warning**. Both readings type-check and the wrong one is silent: the
project's usual shape, arriving from the language rather than from the specification.

**What caught it:** the codec round-trip tests, three of four red on their first run. **What did not:**
`ailang check`, and every count in the suite — a decoder that returns fallbacks is perfectly
deterministic.

**The generalisable rule, and it is cheap:** *a codec's guard is a round trip asserted field by field,
with every field holding a distinct value.* A codec's failure mode is a field the encoder writes and
the decoder ignores; both halves type-check and the loss is silent until a replay serves a different
response while every count still balances. This is S7's "no two quantities equal" applied to a
record rather than to a fixture, and it is worth carrying to A14/A15, which will encode programs for
D8's persistence.

Filed upstream-adjacent but **not** an AILANG bug report: this is documented pattern-matching
semantics. It is noted in-source at the import, because the next reader will hit it.

---

## Correction 2 — a fixture's stated justification is a claim, and this one was false

Cluster 8's corollary, reproduced immediately. The first `rich` fixture documented *"tool outcome
FAULT — the second dispatch, code E_BOOM"*. It never reached it: the queue held two entries against
**one** approved dispatch, so the fault entry was never consumed. The header claimed a shape the run
did not contain.

The fix is not a better comment. **S7's two obligations are now executable checks in the suite**:

- `the surviving fixture carries every shape the specification protects` — chunks, an exhausted
  script, tool ok *and* fault, approval ok *and* missing, env ok *and* missing, a clock advance.
- `no two of the surviving fixture's quantities are equal` — provider 5, script 4, approval reads 6,
  approvals consumed 3, tool dispatches 2.

Both fail loudly if a future edit collapses them, which is what the prose could not do. **Recommend
promoting this to S7 itself:** the rule currently tells an author what the fixture must contain; it
should tell them to *assert* it, because the fixture's coverage drifts silently as the driver changes
and the author is the last person who will notice.

---

## Correction 3 — `routing_violation_at` has no consumer in replay, and this is the answer, not a deferral

The handoff asked: *"Land its call site here if replay gives it a consumer; if not, say so."*
**It does not, and the reason is structural rather than a matter of scheduling.**

- The check's parameters are `(definition, ext_id, hook_id, position, partial_trace, meta)`. D2's
  `ExtensionEffectIdentity(ext_id, class_id, call_id)` carries the extension id and the **fault class
  id** — *not a hook id*. Replay sees interactions, and no interaction carries the value the check
  discriminates on.
- Its real consumer is the **hook dispatch site** — `src/core/ext/runtime.ail:279`,
  `(h.on_tool_policy)(ctx, call)` — which is production driver code with no profile in scope.
  Threading a profile there is a change to the driver and a plan-level call.
- Under `driver_only` it is vacuous regardless: nothing is installed, so no hook dispatch and no
  extension-effect interaction can occur.

So the dead rider stands, and it is now **located**: it is blocked on threading the profile into
production hook dispatch, not on discovery or replay establishing the profile. Both stage 2 and stage
3 have now established the profile and neither made it live. **Recommend the plan move this
obligation off A13 and onto WI-C5**, whose `compose`-bearing profile is the first that can legitimately
exclude a hook — the plan already says C5 "is the first profile that makes it non-vacuous", so the
call site belongs where the non-vacuity does.

---

## D2 findings carried forward

1. **`approval_deadline_exceeded` remains unreachable** by a discovered program (stage 2's finding,
   unchanged): D2 gives `ExpectApproval` a deadline and the driver's approval channel carries none.
2. **`ToolCorrelationMismatch` and `ToolDeadlineExceeded` are replayable but not reached by this
   stage's fixture.** Both travel through the same codec as `ToolFailed` and are covered by
   `ports.ail`'s round-trip rows; reaching them in a scenario needs a third and fourth approved
   dispatch, which the surviving fixture's pairwise-distinct counts would have to give up. Stated,
   not waived — D11's counters should show them as *codec-covered, scenario-unreached*.
3. **A program discovered before this commit is undecodable by this build**, and fails closed with a
   named refusal rather than replaying short. That is D8's compatibility policy behaving correctly on
   its first real test. `program_schema_version()` was **not** bumped, because no *schema* field
   changed — the change is to what a payload string contains. **This is the first case where D8's
   version gate and the actual compatibility boundary disagree, and A14/A15 should decide it**: a
   payload encoding is part of the artifact's meaning even though it is not part of its shape.

---

## Sizing — S6 again, and the third data point CONTRADICTS the binding-count predictor

**S6 (composition), second term dominant for the third consecutive stage.** But the prediction it
made does not hold, and that is this run's calibration result.

**Round trips: 3 compiler, all loud; 0 gate; 2 silent, both found by deliberate probing.**

- **Compiler (3).** `as` is the import-alias keyword and cannot be a match binder — the parse error
  points at the `=>`, not the pattern. A forward reference from inside a **recursive** function is
  `undefined variable`, though a forward reference from a non-recursive one resolves fine (`ports.ail`
  does it at `scripted_env`/`lookup_env`). And one missing import. All loud, all with line numbers,
  all noted in-source.
- **Gate (0).** Nothing fired. **Notably, A5's attribution table did not**: the edits to
  `stub_step.ail` were placed below the anchored site at line 161 and the import list was widened
  in place rather than by adding a line, so `stub_step.ail:161` still reads `now()` and the
  `driver_only` re-issue cascade cluster 8 paid was **avoided entirely, at the cost of one deliberate
  check**. That is worth knowing before A14/A15 decides whether to build a coordinate-independent
  anchor: the cascade is avoidable by an author who knows the anchor exists, which makes the case for
  building the anchor weaker than cluster 8's experience alone suggests.
- **Silent (2).** Sites 19 (the provider payload) and the `None`-as-a-variable binding. Neither was
  found by a gate; both were found by writing a check for a case the existing suite could not reach.

**Recorded bindings: three**, the same count as stage 2.

1. **The recorded outcome must be sufficient to re-serve the response.** Not stated by D2, and the
   alternative — widening `ExecutionProgram` — type-checks and is what design note 3 forbids.
2. **`UnusedInteraction` maps to A9's `ProgramMismatch`.** `HarnessFailureKind` has no variant for a
   surplus and adding one is an A9-owned change that ripples into the event vocabulary and its
   goldens. The distinction is carried by the rule id and the projection text instead.
3. **The Err-surviving approval witness.** The message-derived one is empty on `Err` and the cursor
   delta counts answers *consumed*. The witness used is the tool calls carried by the script entries
   the run consumed — the fixture's own input crossed with the world's `script` cursor, neither of
   which is the recorder.

**Cost against stage 2: roughly 1×, possibly less** — and this is the finding. **The binding count
predicted parity and the cost matched, so the predictor survives its third data point; but the
handoff's framing of why does not.** Cluster 8 attributed its 3× over stage 1 to "the driver wiring is
where the time went". Stage 3 is *also* driver wiring, has the same binding count, and cost about the
same as stage 2 — while doing strictly more (a new module, two codecs, a second acceptance script, a
Makefile target with a wire comparison).

**What actually made stage 3 cheaper than its scope suggests, and it is not in any model:** stage 2
left the seams in the shape stage 3 needed. `RecordingWorld`, `TracedSessionResult.world`,
`check_discovery` already two-sided, `class_balance`'s one-arithmetic-site discipline, and
`approvals_served` were all reused verbatim — the reconstitution balance is `class_balance` with
different nouns, and the witness grading is a function call. **A composition's cost falls sharply when
the previous composition left an assertion that generalises**, and no term in S6 measures that.

**Recommendation: do not add a sixth model, and do not add a term.** Add the observation to S6's
commentary instead: *the binding count predicts cost within a stage; what it cannot see is that a
well-shaped predecessor moves bindings out of the successor entirely.* Stage 2's decision to make
`check_discovery` two-sided — which the report notes "no artifact asked for" — is the single largest
reason stage 3 was cheap, and it was taken a cluster before the saving appeared.

**Judgement ratio, split** (cluster 5's rule):

- **Machinery — the walk, the reconstitution and the codecs: ~35%.** D2 enumerates the four
  HarnessFailure conditions and stage 1 fixed the identity semantics, so most rows were determined.
  Undetermined: the three recorded bindings above, the decision to check the outcome projection at
  all (D2 says "recorded projections", which reads as the *request* projection alone), and the
  one-finding-per-position ordering.
- **Content — the scenarios: ~90%.** Which two scenarios exist is discovered, not specified. The most
  consequential decisions here are content: `rich`'s five pairwise-distinct quantities, and the
  denial placed *between* two approvals, without which `approvals_consumed` and `tool_dispatches`
  are equal and the pair stage 2's site 18 hid behind is reproduced exactly.

Slightly higher machinery than stage 2's ~30% and slightly lower content than its ~95%, in both cases
because the codecs are machinery with no specification behind them at all.

---

## What is unblocked, and what stage 4 should know

**Unblocked.** Stage 4 (regression replay and D8's generator canary) has: a program that round-trips
through a real driver, a comparison that already separates *identity* from *projection* from
*outcome* — which is the exact seam regression replay needs, since it "requires compatible causal
identity, records projection differences, and may continue" — and a refusal path that fails closed.

Four things stage 4 should know:

1. **Regression replay is `strict_replay_findings` with the last three rules demoted to recorded
   differences, not failures.** `compare_at`'s coarsest-difference-first ordering was written for
   that: kind and origin stay fatal, identity stays fatal, and `ProjectionDiffers`/`OutcomeDiffers`
   are the two that become recorded. D2's *"regression replay never weakens tool-call/result
   correlation or delivers an outcome to a different logical request"* is exactly the line between
   `UnsafeIdentity` and `ProjectionDiffers`, and it is already a line in the code.
2. **The tautology control is not optional and does not survive being copied carelessly.** Its two
   halves must stay: the shared-defect pair must be shown to MATCH, and the independent witness must
   be shown to REJECT. Deleting either leaves a check that passes for the wrong reason.
3. **Do not run `make dst` concurrently with another target** (cluster 8's discipline; observed, no
   corruption this session), and **read its exit status**.
4. **`stub_step.ail:161` is an A5 anchor.** Insert below it, and widen import lists in place rather
   than by adding a line. One check with `sed -n '161p'` costs seconds and avoids a five-artifact
   cascade including a mandatory `driver_only` re-issue.
